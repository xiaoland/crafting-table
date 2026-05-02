use std::sync::Arc;

use axum::{
    extract::{Query, State},
    http::StatusCode,
    response::IntoResponse,
    routing::get,
    Json, Router,
};

use crate::{
    codex,
    config::Config,
    models::{ApiError, HealthResponse, PlatformInfo, ScoutHealth, ScoutStatus, ThreadListQuery},
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
    match thread_store::list_threads(&state.config.codex_home, query.limit) {
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
