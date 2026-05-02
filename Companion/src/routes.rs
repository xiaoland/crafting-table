use std::sync::Arc;

use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    response::IntoResponse,
    routing::{get, post},
    Json, Router,
};

use crate::{
    app_server, codex,
    config::Config,
    desktop_scout,
    models::{
        ApiError, HealthResponse, PlatformInfo, ScoutHealth, ScoutStatus, ThreadListQuery,
        TurnSubmitRequest,
    },
    thread_store,
};

#[derive(Clone)]
pub struct AppState {
    pub config: Config,
    pub codex: crate::models::CodexHealth,
}

impl AppState {
    pub async fn new(config: Config) -> Self {
        let codex = codex::probe(&config).await;
        Self { config, codex }
    }
}

pub fn router(state: Arc<AppState>) -> Router {
    Router::new()
        .route("/health", get(health))
        .route("/threads", get(list_threads))
        .route("/threads/:thread_id/resume", post(resume_thread))
        .route("/threads/:thread_id/turns", post(submit_turn))
        .route("/desktop/snapshot", get(desktop_snapshot))
        .with_state(state)
}

async fn health(State(state): State<Arc<AppState>>) -> Json<HealthResponse> {
    Json(HealthResponse {
        service: "codex-remote-companion",
        version: env!("CARGO_PKG_VERSION"),
        platform: PlatformInfo {
            os: std::env::consts::OS,
            arch: std::env::consts::ARCH,
        },
        codex: state.codex.clone(),
        scouts: ScoutHealth {
            macos: ScoutStatus {
                configured: cfg!(target_os = "macos"),
                probe: "pending".to_string(),
            },
            windows: ScoutStatus {
                configured: cfg!(target_os = "windows"),
                probe: "pending".to_string(),
            },
        },
    })
}

async fn list_threads(
    State(state): State<Arc<AppState>>,
    Query(query): Query<ThreadListQuery>,
) -> impl IntoResponse {
    let limit = query.limit.unwrap_or(20).clamp(1, 100);

    match app_server::list_threads(&state.config, limit).await {
        Ok(response) => return (StatusCode::OK, Json(response)).into_response(),
        Err(error) => tracing::warn!(error = %error, "falling back to session_index thread list"),
    }

    match thread_store::list_threads(&state.config.codex_home, Some(limit)) {
        Ok(response) => (StatusCode::OK, Json(response)).into_response(),
        Err(error) => (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ApiError {
                error: error.to_string(),
            }),
        )
            .into_response(),
    }
}

async fn resume_thread(
    State(state): State<Arc<AppState>>,
    Path(thread_id): Path<String>,
) -> impl IntoResponse {
    match app_server::resume_thread(&state.config, &thread_id).await {
        Ok(response) => (StatusCode::OK, Json(response)).into_response(),
        Err(error) => api_error(StatusCode::BAD_GATEWAY, error),
    }
}

async fn submit_turn(
    State(state): State<Arc<AppState>>,
    Path(thread_id): Path<String>,
    Json(request): Json<TurnSubmitRequest>,
) -> impl IntoResponse {
    if request.input.trim().is_empty() {
        return api_error(
            StatusCode::BAD_REQUEST,
            anyhow::anyhow!("input is required"),
        );
    }

    match app_server::submit_turn(
        &state.config,
        &thread_id,
        &request.input,
        request.cwd.as_deref(),
    )
    .await
    {
        Ok(response) => (StatusCode::OK, Json(response)).into_response(),
        Err(error) => api_error(StatusCode::BAD_GATEWAY, error),
    }
}

async fn desktop_snapshot() -> impl IntoResponse {
    match desktop_scout::snapshot().await {
        Ok(response) => (StatusCode::OK, Json(response)).into_response(),
        Err(error) => api_error(StatusCode::SERVICE_UNAVAILABLE, error),
    }
}

fn api_error(status: StatusCode, error: anyhow::Error) -> axum::response::Response {
    (
        status,
        Json(ApiError {
            error: error.to_string(),
        }),
    )
        .into_response()
}
