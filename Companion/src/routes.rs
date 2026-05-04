use std::sync::Arc;

use anyhow::Context;
use axum::{
    extract::{
        ws::{Message as WebSocketMessage, WebSocket, WebSocketUpgrade},
        Path, Query, State,
    },
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
    turn_events::{TurnEventBroker, TurnStreamEvent},
};

#[derive(Clone)]
pub struct AppState {
    pub config: Config,
    pub codex: crate::models::CodexHealth,
    pub turn_events: TurnEventBroker,
}

impl AppState {
    pub async fn new(config: Config) -> Self {
        let codex = codex::probe(&config).await;
        Self {
            config,
            codex,
            turn_events: TurnEventBroker::new(),
        }
    }
}

pub fn router(state: Arc<AppState>) -> Router {
    Router::new()
        .route("/health", get(health))
        .route("/threads", get(list_threads))
        .route("/threads/:thread_id", get(read_thread))
        .route("/threads/:thread_id/resume", post(resume_thread))
        .route("/threads/:thread_id/turns", post(submit_turn))
        .route(
            "/threads/:thread_id/turns/:turn_id/events",
            get(turn_events),
        )
        .route("/models", get(list_models))
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

async fn read_thread(
    State(state): State<Arc<AppState>>,
    Path(thread_id): Path<String>,
) -> impl IntoResponse {
    match app_server::read_thread(&state.config, &thread_id).await {
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
        request.model.as_deref(),
        request.reasoning_effort.as_deref(),
        request.service_tier.as_deref(),
        request.wait_for_completion.unwrap_or(true),
        Some(state.turn_events.clone()),
    )
    .await
    {
        Ok(response) => (StatusCode::OK, Json(response)).into_response(),
        Err(error) => api_error(StatusCode::BAD_GATEWAY, error),
    }
}

async fn list_models(State(state): State<Arc<AppState>>) -> impl IntoResponse {
    match app_server::list_models(&state.config).await {
        Ok(response) => (StatusCode::OK, Json(response)).into_response(),
        Err(error) => api_error(StatusCode::BAD_GATEWAY, error),
    }
}

async fn turn_events(
    State(state): State<Arc<AppState>>,
    Path((thread_id, turn_id)): Path<(String, String)>,
    websocket: WebSocketUpgrade,
) -> impl IntoResponse {
    websocket.on_upgrade(move |socket| {
        stream_turn_events(socket, state.turn_events.clone(), thread_id, turn_id)
    })
}

async fn stream_turn_events(
    mut socket: WebSocket,
    broker: TurnEventBroker,
    thread_id: String,
    turn_id: String,
) {
    let Some(mut subscription) = broker.subscribe(&thread_id, &turn_id).await else {
        let event = TurnStreamEvent::unavailable(&thread_id, &turn_id);
        let _ = send_turn_event(&mut socket, &event).await;
        let _ = socket.send(WebSocketMessage::Close(None)).await;
        return;
    };

    for event in subscription.replay {
        let is_terminal = event.is_terminal();
        if send_turn_event(&mut socket, &event).await.is_err() {
            return;
        }
        if is_terminal {
            let _ = socket.send(WebSocketMessage::Close(None)).await;
            return;
        }
    }

    loop {
        tokio::select! {
            event = subscription.receiver.recv() => {
                match event {
                    Ok(event) => {
                        let is_terminal = event.is_terminal();
                        if send_turn_event(&mut socket, &event).await.is_err() {
                            return;
                        }
                        if is_terminal {
                            let _ = socket.send(WebSocketMessage::Close(None)).await;
                            return;
                        }
                    }
                    Err(tokio::sync::broadcast::error::RecvError::Lagged(_)) => {}
                    Err(tokio::sync::broadcast::error::RecvError::Closed) => return,
                }
            }
            message = socket.recv() => {
                match message {
                    Some(Ok(WebSocketMessage::Close(_))) | None => return,
                    Some(Ok(_)) => {}
                    Some(Err(error)) => {
                        tracing::debug!(error = %error, "turn event websocket receive failed");
                        return;
                    }
                }
            }
        }
    }
}

async fn send_turn_event(socket: &mut WebSocket, event: &TurnStreamEvent) -> anyhow::Result<()> {
    let payload = serde_json::to_string(event).context("failed to encode turn stream event")?;
    socket
        .send(WebSocketMessage::Text(payload))
        .await
        .context("failed to send turn stream event")
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
