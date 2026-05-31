use std::{
    ffi::{CStr, CString},
    net::SocketAddr,
    os::raw::c_char,
    path::PathBuf,
    ptr,
    sync::{mpsc, Mutex},
    thread::{self, JoinHandle},
    time::Duration,
};

use tokio::sync::oneshot;

use crate::codex_remote_control::{
    contract::HostRuntimeLaunchContext,
    server::{serve_listener_with_shutdown, Config},
};

pub struct CtCodexRemoteServerHandle {
    shutdown: Mutex<Option<oneshot::Sender<()>>>,
    thread: Mutex<Option<JoinHandle<()>>>,
}

#[no_mangle]
pub extern "C" fn ct_codex_remote_server_start(
    bind: *const c_char,
    codex_home: *const c_char,
    error_out: *mut *mut c_char,
) -> *mut CtCodexRemoteServerHandle {
    clear_error(error_out);

    let bind = match read_c_string(bind, "bind") {
        Ok(value) => value,
        Err(message) => {
            set_error(error_out, message);
            return ptr::null_mut();
        }
    };
    let codex_home = match read_c_string(codex_home, "codex_home") {
        Ok(value) => value,
        Err(message) => {
            set_error(error_out, message);
            return ptr::null_mut();
        }
    };
    let bind: SocketAddr = match bind.parse() {
        Ok(value) => value,
        Err(error) => {
            set_error(error_out, format!("invalid bind address: {error}"));
            return ptr::null_mut();
        }
    };

    let (shutdown_tx, shutdown_rx) = oneshot::channel::<()>();
    let (startup_tx, startup_rx) = mpsc::channel::<Result<String, String>>();
    let config = Config::new(bind, PathBuf::from(codex_home))
        .with_launch_context(HostRuntimeLaunchContext::InProcess);

    let thread = thread::spawn(move || {
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

            if let Err(error) = serve_listener_with_shutdown(listener, config, async {
                let _ = shutdown_rx.await;
            })
            .await
            {
                eprintln!("CTCore Codex Remote Server stopped with error: {error:#}");
            }
        });
    });

    match startup_rx.recv_timeout(Duration::from_secs(5)) {
        Ok(Ok(_actual_bind)) => Box::into_raw(Box::new(CtCodexRemoteServerHandle {
            shutdown: Mutex::new(Some(shutdown_tx)),
            thread: Mutex::new(Some(thread)),
        })),
        Ok(Err(message)) => {
            let _ = thread.join();
            set_error(error_out, message);
            ptr::null_mut()
        }
        Err(error) => {
            let _ = shutdown_tx.send(());
            let _ = thread.join();
            set_error(error_out, format!("server startup timed out: {error}"));
            ptr::null_mut()
        }
    }
}

#[no_mangle]
pub extern "C" fn ct_codex_remote_server_stop(handle: *mut CtCodexRemoteServerHandle) {
    if handle.is_null() {
        return;
    }

    let handle = unsafe { Box::from_raw(handle) };
    if let Ok(mut shutdown) = handle.shutdown.lock() {
        if let Some(sender) = shutdown.take() {
            let _ = sender.send(());
        }
    }
    if let Ok(mut thread) = handle.thread.lock() {
        if let Some(thread) = thread.take() {
            let _ = thread.join();
        }
    };
}

#[no_mangle]
pub extern "C" fn ct_codex_remote_server_string_free(value: *mut c_char) {
    if value.is_null() {
        return;
    }

    unsafe {
        let _ = CString::from_raw(value);
    }
}

fn read_c_string(value: *const c_char, label: &str) -> Result<String, String> {
    if value.is_null() {
        return Err(format!("{label} is required"));
    }

    unsafe { CStr::from_ptr(value) }
        .to_str()
        .map(str::to_owned)
        .map_err(|error| format!("{label} must be valid UTF-8: {error}"))
}

fn clear_error(error_out: *mut *mut c_char) {
    if error_out.is_null() {
        return;
    }

    unsafe {
        *error_out = ptr::null_mut();
    }
}

fn set_error(error_out: *mut *mut c_char, message: String) {
    if error_out.is_null() {
        return;
    }

    let sanitized = message.replace('\0', " ");
    let c_string = CString::new(sanitized).expect("nul bytes were removed");
    unsafe {
        *error_out = c_string.into_raw();
    }
}
