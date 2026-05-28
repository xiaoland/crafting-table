use axum::{
    body::{to_bytes, Body},
    http::{Request, StatusCode},
};
use codex_remote_companion::{build_router, Config};
use ct_core::codex_remote_control::contract::{
    HostRuntimeLaunchContext, HostRuntimeStatusResponse,
};
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

    assert_eq!(
        status.state,
        ct_core::codex_remote_control::contract::HostRuntimeState::Running
    );
    assert_eq!(status.bind, "127.0.0.1:0");
    assert_eq!(status.launch_context, HostRuntimeLaunchContext::InProcess);
}
