use std::{
    net::SocketAddr,
    path::PathBuf,
    sync::{mpsc, Arc, Mutex},
    thread::{self, JoinHandle},
    time::{Duration, SystemTime, UNIX_EPOCH},
};

use ct_core::codex_remote_control::{
    contract::HostRuntimeLaunchContext,
    server::{serve_listener_with_shutdown, Config},
};
use tokio::sync::oneshot;

const PORT: u16 = 3765;
const MAX_EVENTS: usize = 80;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum RuntimeState {
    Stopped,
    Starting,
    Running,
    Stopping,
    Failed,
}

impl RuntimeState {
    pub fn label(self) -> &'static str {
        match self {
            Self::Stopped => "Stopped",
            Self::Starting => "Starting",
            Self::Running => "Running",
            Self::Stopping => "Stopping",
            Self::Failed => "Failed",
        }
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum BindMode {
    LocalOnly,
    LocalNetwork,
}

impl BindMode {
    pub fn label(self) -> &'static str {
        match self {
            Self::LocalOnly => "This PC",
            Self::LocalNetwork => "Local Network",
        }
    }

    pub fn bind_address(self) -> String {
        match self {
            Self::LocalOnly => format!("127.0.0.1:{PORT}"),
            Self::LocalNetwork => format!("0.0.0.0:{PORT}"),
        }
    }

    pub fn endpoint_hint(self) -> String {
        match self {
            Self::LocalOnly => format!("http://127.0.0.1:{PORT}"),
            Self::LocalNetwork => format!("http://<windows-lan-ip>:{PORT}"),
        }
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum RuntimeEventKind {
    Status,
    Server,
    Log,
    Error,
}

impl RuntimeEventKind {
    pub fn label(self) -> &'static str {
        match self {
            Self::Status => "status",
            Self::Server => "server",
            Self::Log => "log",
            Self::Error => "error",
        }
    }
}

#[derive(Clone, Debug)]
pub struct RuntimeEvent {
    pub id: u64,
    pub kind: RuntimeEventKind,
    pub message: String,
    pub timestamp: String,
}

#[derive(Clone, Debug)]
pub struct RuntimeView {
    pub state: RuntimeState,
    pub bind_mode: BindMode,
    pub bind_address: String,
    pub endpoint_hint: String,
    pub codex_home: String,
    pub events: Vec<RuntimeEvent>,
}

#[derive(Clone)]
pub struct HostRuntimeService {
    inner: Arc<Mutex<RuntimeInner>>,
}

struct RuntimeInner {
    state: RuntimeState,
    bind_mode: BindMode,
    codex_home: String,
    shutdown: Option<oneshot::Sender<()>>,
    thread: Option<JoinHandle<()>>,
    generation: u64,
    next_event_id: u64,
    events: Vec<RuntimeEvent>,
}

impl Default for HostRuntimeService {
    fn default() -> Self {
        let mut inner = RuntimeInner {
            state: RuntimeState::Stopped,
            bind_mode: BindMode::LocalOnly,
            codex_home: default_codex_home(),
            shutdown: None,
            thread: None,
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

impl HostRuntimeService {
    pub fn view(&self) -> Result<RuntimeView, String> {
        let inner = self.lock()?;
        Ok(inner.view())
    }

    pub fn set_bind_mode(&self, mode: BindMode) -> Result<RuntimeView, String> {
        let mut inner = self.lock()?;
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

    pub fn start(&self) -> Result<RuntimeView, String> {
        let (bind, startup_rx) = {
            let mut inner = self.lock()?;
            if !matches!(inner.state, RuntimeState::Stopped | RuntimeState::Failed) {
                return Ok(inner.view());
            }

            let bind = inner.bind_mode.bind_address();
            let codex_home = inner.codex_home.clone();
            let parsed_bind = bind
                .parse::<SocketAddr>()
                .map_err(|error| format!("invalid bind address {bind}: {error}"))?;
            let (shutdown_tx, shutdown_rx) = oneshot::channel::<()>();
            let (startup_tx, startup_rx) = mpsc::channel::<Result<String, String>>();

            inner.state = RuntimeState::Starting;
            inner.generation += 1;
            inner.shutdown = Some(shutdown_tx);
            inner.push_event(RuntimeEventKind::Status, "Host Runtime is starting.");

            let generation = inner.generation;
            let task_store = self.clone();
            let task_codex_home = codex_home.clone();
            let thread = thread::spawn(move || {
                run_server_task(
                    task_store,
                    generation,
                    parsed_bind,
                    task_codex_home,
                    shutdown_rx,
                    startup_tx,
                );
            });
            inner.thread = Some(thread);

            (bind, startup_rx)
        };

        match startup_rx.recv_timeout(Duration::from_secs(5)) {
            Ok(Ok(actual_bind)) => {
                self.update_current(|inner| {
                    inner.state = RuntimeState::Running;
                    inner.push_event(
                        RuntimeEventKind::Server,
                        format!("Listening on {actual_bind}."),
                    );
                    inner.push_event(RuntimeEventKind::Log, "CTCore in-process server is active.");
                });
                self.view()
            }
            Ok(Err(message)) => {
                self.update_current(|inner| {
                    inner.state = RuntimeState::Failed;
                    inner.shutdown = None;
                    inner.thread = None;
                    inner.push_event(RuntimeEventKind::Error, message.clone());
                });
                Err(message)
            }
            Err(error) => {
                self.update_current(|inner| {
                    inner.state = RuntimeState::Failed;
                    inner.shutdown = None;
                    inner.thread = None;
                    inner.push_event(
                        RuntimeEventKind::Error,
                        format!("server startup timed out for {bind}: {error}"),
                    );
                });
                Err(format!("server startup timed out for {bind}: {error}"))
            }
        }
    }

    pub fn stop(&self) -> Result<RuntimeView, String> {
        let thread = {
            let mut inner = self.lock()?;
            if inner.state == RuntimeState::Stopped {
                return Ok(inner.view());
            }

            inner.state = RuntimeState::Stopping;
            inner.push_event(RuntimeEventKind::Status, "Host Runtime is stopping.");

            if let Some(shutdown) = inner.shutdown.take() {
                let _ = shutdown.send(());
            }

            inner.thread.take()
        };

        if let Some(thread) = thread {
            let _ = thread.join();
        }

        self.view()
    }

    fn lock(&self) -> Result<std::sync::MutexGuard<'_, RuntimeInner>, String> {
        self.inner
            .lock()
            .map_err(|_| "runtime store lock is poisoned".to_string())
    }

    fn update_current<F>(&self, update: F)
    where
        F: FnOnce(&mut RuntimeInner),
    {
        if let Ok(mut inner) = self.inner.lock() {
            update(&mut inner);
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

fn run_server_task(
    store: HostRuntimeService,
    generation: u64,
    bind: SocketAddr,
    codex_home: String,
    shutdown_rx: oneshot::Receiver<()>,
    startup_tx: mpsc::Sender<Result<String, String>>,
) {
    let runtime = match tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()
    {
        Ok(runtime) => runtime,
        Err(error) => {
            let _ = startup_tx.send(Err(format!("failed to create runtime: {error}")));
            return;
        }
    };

    runtime.block_on(async move {
        let listener = match tokio::net::TcpListener::bind(bind).await {
            Ok(listener) => listener,
            Err(error) => {
                let _ = startup_tx.send(Err(format!("failed to bind {bind}: {error}")));
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

        store.update_current(|inner| {
            if inner.generation != generation {
                return;
            }
            inner.shutdown = None;
            inner.thread = None;
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
