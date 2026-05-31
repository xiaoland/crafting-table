use std::{
    net::SocketAddr,
    path::PathBuf,
    sync::{Arc, Mutex},
    time::{SystemTime, UNIX_EPOCH},
};

use ct_core::codex_remote_control::{
    contract::HostRuntimeLaunchContext,
    server::{serve_listener_with_shutdown, Config},
};
use serde::{Deserialize, Serialize};
use tauri::State;
use tokio::sync::oneshot;

const PORT: u16 = 3765;
const MAX_EVENTS: usize = 80;

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
enum RuntimeState {
    Stopped,
    Starting,
    Running,
    Stopping,
    Failed,
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
enum BindMode {
    LocalOnly,
    LocalNetwork,
}

impl BindMode {
    fn bind_address(self) -> String {
        match self {
            Self::LocalOnly => format!("127.0.0.1:{PORT}"),
            Self::LocalNetwork => format!("0.0.0.0:{PORT}"),
        }
    }

    fn endpoint_hint(self) -> String {
        match self {
            Self::LocalOnly => format!("http://127.0.0.1:{PORT}"),
            Self::LocalNetwork => format!("http://<windows-lan-ip>:{PORT}"),
        }
    }
}

#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct RuntimeEvent {
    id: u64,
    kind: RuntimeEventKind,
    message: String,
    timestamp: String,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
enum RuntimeEventKind {
    Status,
    Server,
    Log,
    Error,
}

#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct RuntimeView {
    state: RuntimeState,
    bind_mode: BindMode,
    bind_address: String,
    endpoint_hint: String,
    codex_home: String,
    events: Vec<RuntimeEvent>,
}

#[derive(Clone)]
struct RuntimeStore {
    inner: Arc<Mutex<RuntimeInner>>,
}

struct RuntimeInner {
    state: RuntimeState,
    bind_mode: BindMode,
    codex_home: String,
    shutdown: Option<oneshot::Sender<()>>,
    generation: u64,
    next_event_id: u64,
    events: Vec<RuntimeEvent>,
}

impl Default for RuntimeStore {
    fn default() -> Self {
        let mut inner = RuntimeInner {
            state: RuntimeState::Stopped,
            bind_mode: BindMode::LocalOnly,
            codex_home: default_codex_home(),
            shutdown: None,
            generation: 0,
            next_event_id: 1,
            events: Vec::new(),
        };
        inner.push_event(RuntimeEventKind::Status, "Host Runtime is stopped.");

        Self {
            inner: Arc::new(Mutex::new(inner)),
        }
    }
}

impl RuntimeStore {
    fn view(&self) -> Result<RuntimeView, String> {
        let inner = self.lock()?;
        Ok(inner.view())
    }

    fn lock(&self) -> Result<std::sync::MutexGuard<'_, RuntimeInner>, String> {
        self.inner
            .lock()
            .map_err(|_| "runtime store lock is poisoned".to_string())
    }

    fn update_generation<F>(&self, generation: u64, update: F)
    where
        F: FnOnce(&mut RuntimeInner),
    {
        if let Ok(mut inner) = self.inner.lock() {
            if inner.generation == generation {
                update(&mut inner);
            }
        }
    }
}

impl RuntimeInner {
    fn view(&self) -> RuntimeView {
        RuntimeView {
            state: self.state,
            bind_mode: self.bind_mode,
            bind_address: self.bind_mode.bind_address(),
            endpoint_hint: self.bind_mode.endpoint_hint(),
            codex_home: self.codex_home.clone(),
            events: self.events.clone(),
        }
    }

    fn push_event(&mut self, kind: RuntimeEventKind, message: impl Into<String>) {
        let event = RuntimeEvent {
            id: self.next_event_id,
            kind,
            message: message.into(),
            timestamp: current_time_label(),
        };
        self.next_event_id += 1;
        self.events.insert(0, event);
        if self.events.len() > MAX_EVENTS {
            self.events.truncate(MAX_EVENTS);
        }
    }
}

#[tauri::command]
fn runtime_status(store: State<'_, RuntimeStore>) -> Result<RuntimeView, String> {
    store.view()
}

#[tauri::command]
fn runtime_set_bind_mode(
    store: State<'_, RuntimeStore>,
    mode: BindMode,
) -> Result<RuntimeView, String> {
    let mut inner = store.lock()?;
    if !matches!(inner.state, RuntimeState::Stopped | RuntimeState::Failed) {
        inner.push_event(
            RuntimeEventKind::Status,
            "Stop Host Runtime before changing the bind address.",
        );
        return Ok(inner.view());
    }

    if inner.bind_mode != mode {
        inner.bind_mode = mode;
        let bind = inner.bind_mode.bind_address();
        inner.push_event(RuntimeEventKind::Status, format!("Bind set to {bind}."));
    }

    Ok(inner.view())
}

#[tauri::command]
async fn runtime_start(store: State<'_, RuntimeStore>) -> Result<RuntimeView, String> {
    let store = store.inner().clone();
    let (bind, generation, startup_rx) = {
        let mut inner = store.lock()?;
        if !matches!(inner.state, RuntimeState::Stopped | RuntimeState::Failed) {
            return Ok(inner.view());
        }

        let bind = inner.bind_mode.bind_address();
        let codex_home = inner.codex_home.clone();
        let parsed_bind = bind
            .parse::<SocketAddr>()
            .map_err(|error| format!("invalid bind address {bind}: {error}"))?;
        let (shutdown_tx, shutdown_rx) = oneshot::channel::<()>();
        let (startup_tx, startup_rx) = oneshot::channel::<Result<String, String>>();

        inner.state = RuntimeState::Starting;
        inner.generation += 1;
        inner.shutdown = Some(shutdown_tx);
        inner.push_event(RuntimeEventKind::Status, "Host Runtime is starting.");

        let generation = inner.generation;
        let task_store = store.clone();
        let task_codex_home = codex_home.clone();
        tauri::async_runtime::spawn(async move {
            run_server_task(
                task_store,
                generation,
                parsed_bind,
                task_codex_home,
                shutdown_rx,
                startup_tx,
            )
            .await;
        });

        (bind, generation, startup_rx)
    };

    let startup_result = startup_rx
        .await
        .map_err(|_| format!("server startup dropped before binding {bind}"))?;

    match startup_result {
        Ok(actual_bind) => {
            store.update_generation(generation, |inner| {
                inner.state = RuntimeState::Running;
                inner.push_event(
                    RuntimeEventKind::Server,
                    format!("Listening on {actual_bind}."),
                );
                inner.push_event(RuntimeEventKind::Log, "CTCore in-process server is active.");
            });
            store.view()
        }
        Err(message) => {
            store.update_generation(generation, |inner| {
                inner.state = RuntimeState::Failed;
                inner.shutdown = None;
                inner.push_event(RuntimeEventKind::Error, message.clone());
            });
            Err(message)
        }
    }
}

#[tauri::command]
fn runtime_stop(store: State<'_, RuntimeStore>) -> Result<RuntimeView, String> {
    let mut inner = store.lock()?;
    if inner.state == RuntimeState::Stopped {
        return Ok(inner.view());
    }

    inner.state = RuntimeState::Stopping;
    inner.push_event(RuntimeEventKind::Status, "Host Runtime is stopping.");

    if let Some(shutdown) = inner.shutdown.take() {
        let _ = shutdown.send(());
    }

    Ok(inner.view())
}

async fn run_server_task(
    store: RuntimeStore,
    generation: u64,
    bind: SocketAddr,
    codex_home: String,
    shutdown_rx: oneshot::Receiver<()>,
    startup_tx: oneshot::Sender<Result<String, String>>,
) {
    let listener = match tokio::net::TcpListener::bind(bind).await {
        Ok(listener) => listener,
        Err(error) => {
            let message = format!("failed to bind {bind}: {error}");
            let _ = startup_tx.send(Err(message));
            return;
        }
    };
    let actual_bind = listener
        .local_addr()
        .map(|addr| addr.to_string())
        .unwrap_or_else(|_| bind.to_string());
    let _ = startup_tx.send(Ok(actual_bind));

    let config = Config::new(bind, PathBuf::from(codex_home))
        .with_launch_context(HostRuntimeLaunchContext::InProcess);
    let result = serve_listener_with_shutdown(listener, config, async {
        let _ = shutdown_rx.await;
    })
    .await;

    store.update_generation(generation, |inner| {
        inner.shutdown = None;
        match result {
            Ok(()) => {
                inner.state = RuntimeState::Stopped;
                inner.push_event(RuntimeEventKind::Status, "Host Runtime stopped.");
            }
            Err(error) => {
                inner.state = RuntimeState::Failed;
                inner.push_event(RuntimeEventKind::Error, format!("{error:#}"));
            }
        }
    });
}

fn default_codex_home() -> String {
    std::env::var_os("CODEX_HOME")
        .map(PathBuf::from)
        .or_else(|| std::env::var_os("USERPROFILE").map(|home| PathBuf::from(home).join(".codex")))
        .or_else(|| std::env::var_os("HOME").map(|home| PathBuf::from(home).join(".codex")))
        .unwrap_or_else(|| PathBuf::from(".codex"))
        .to_string_lossy()
        .into_owned()
}

fn current_time_label() -> String {
    let seconds = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|duration| duration.as_secs() % 86_400)
        .unwrap_or(0);
    let hour = seconds / 3_600;
    let minute = (seconds % 3_600) / 60;
    let second = seconds % 60;
    format!("{hour:02}:{minute:02}:{second:02}")
}

fn main() {
    tauri::Builder::default()
        .manage(RuntimeStore::default())
        .invoke_handler(tauri::generate_handler![
            runtime_status,
            runtime_set_bind_mode,
            runtime_start,
            runtime_stop
        ])
        .run(tauri::generate_context!())
        .expect("failed to run Crafting Table Windows client");
}
