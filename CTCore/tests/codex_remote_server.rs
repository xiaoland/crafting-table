#![cfg(feature = "codex-remote-control-server")]

use std::{
    ffi::{CStr, CString},
    io::{Read, Write},
    net::{IpAddr, SocketAddr, TcpListener as StdTcpListener, TcpStream},
    os::raw::c_char,
    ptr,
    time::Duration,
};

use axum::{
    body::{to_bytes, Body},
    http::{Request, StatusCode},
};
use ct_core::codex_remote_control::{
    contract::{HostRuntimeLaunchContext, HostRuntimeState, HostRuntimeStatusResponse},
    server::{
        build_router,
        ffi::{
            ct_codex_remote_server_start, ct_codex_remote_server_stop,
            ct_codex_remote_server_string_free,
        },
        serve_listener_with_shutdown, Config,
    },
};
use tokio::{net::TcpListener, sync::oneshot};
use tower::ServiceExt;

#[tokio::test]
async fn embedded_router_exposes_host_runtime_status() {
    let codex_home = tempfile::tempdir().expect("temp codex home");
    let config = Config::new(
        "127.0.0.1:0".parse().expect("bind address"),
        codex_home.path().into(),
    )
    .with_launch_context(HostRuntimeLaunchContext::InProcess);
    let app = build_router(config).await;

    let response = app
        .oneshot(
            Request::builder()
                .uri("/host/runtime")
                .body(Body::empty())
                .expect("request"),
        )
        .await
        .expect("response");

    assert_eq!(response.status(), StatusCode::OK);

    let body = to_bytes(response.into_body(), usize::MAX)
        .await
        .expect("body bytes");
    let status: HostRuntimeStatusResponse =
        serde_json::from_slice(&body).expect("runtime status response");

    assert_eq!(status.state, HostRuntimeState::Running);
    assert_eq!(status.bind, "127.0.0.1:0");
    assert_eq!(status.launch_context, HostRuntimeLaunchContext::InProcess);
}

#[tokio::test]
async fn server_binds_local_network_addr_and_serves_runtime_status() {
    let codex_home = tempfile::tempdir().expect("temp codex home");
    let listener = TcpListener::bind("0.0.0.0:0").await.expect("listener");
    let bound_addr = listener.local_addr().expect("bound address");
    assert!(bound_addr.ip().is_unspecified());

    let config = Config::new(bound_addr, codex_home.path().into())
        .with_launch_context(HostRuntimeLaunchContext::InProcess);
    let (shutdown_tx, shutdown_rx) = oneshot::channel::<()>();

    let server = tokio::spawn(async move {
        serve_listener_with_shutdown(listener, config, async {
            let _ = shutdown_rx.await;
        })
        .await
    });

    let response = get_http(SocketAddr::new(
        IpAddr::from([127, 0, 0, 1]),
        bound_addr.port(),
    ))
    .await
    .expect("runtime response");
    shutdown_tx.send(()).expect("shutdown server");
    server.await.expect("server task").expect("server result");

    assert!(
        response.starts_with("HTTP/1.1 200 OK"),
        "unexpected response: {response}"
    );

    let body = response.split("\r\n\r\n").nth(1).expect("response body");
    let status: HostRuntimeStatusResponse =
        serde_json::from_str(body).expect("runtime status response");

    assert_eq!(status.bind, bound_addr.to_string());
    assert_eq!(status.launch_context, HostRuntimeLaunchContext::InProcess);
}

#[test]
fn c_abi_starts_and_stops_in_process_server() {
    let codex_home = tempfile::tempdir().expect("temp codex home");
    let port = reserve_local_port();
    let bind = CString::new(format!("127.0.0.1:{port}")).expect("bind c string");
    let codex_home =
        CString::new(codex_home.path().to_string_lossy().as_bytes()).expect("codex home c string");
    let mut error: *mut c_char = ptr::null_mut();

    let handle = ct_codex_remote_server_start(bind.as_ptr(), codex_home.as_ptr(), &mut error);
    assert!(
        !handle.is_null(),
        "server failed to start: {}",
        take_error(error)
    );

    let response = std::thread::spawn(move || {
        let runtime = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .expect("tokio runtime");
        runtime.block_on(get_http(SocketAddr::new(
            IpAddr::from([127, 0, 0, 1]),
            port,
        )))
    })
    .join()
    .expect("http thread")
    .expect("runtime response");

    ct_codex_remote_server_stop(handle);

    assert!(
        response.starts_with("HTTP/1.1 200 OK"),
        "unexpected response: {response}"
    );
}

async fn get_http(addr: SocketAddr) -> std::io::Result<String> {
    tokio::task::spawn_blocking(move || {
        let mut last_error = None;

        for _ in 0..50 {
            match TcpStream::connect_timeout(&addr, Duration::from_millis(100)) {
                Ok(mut stream) => {
                    stream.set_read_timeout(Some(Duration::from_secs(2)))?;
                    stream.write_all(
                        b"GET /host/runtime HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n",
                    )?;

                    let mut response = String::new();
                    stream.read_to_string(&mut response)?;
                    return Ok(response);
                }
                Err(error) => {
                    last_error = Some(error);
                    std::thread::sleep(Duration::from_millis(20));
                }
            }
        }

        Err(last_error.unwrap_or_else(|| {
            std::io::Error::new(std::io::ErrorKind::TimedOut, "server did not accept connection")
        }))
    })
    .await
    .expect("blocking http request")
}

fn reserve_local_port() -> u16 {
    let listener = StdTcpListener::bind("127.0.0.1:0").expect("reserve local port");
    listener.local_addr().expect("local address").port()
}

fn take_error(error: *mut c_char) -> String {
    if error.is_null() {
        return "no error".to_string();
    }

    let message = unsafe { CStr::from_ptr(error) }
        .to_string_lossy()
        .into_owned();
    ct_codex_remote_server_string_free(error);
    message
}
