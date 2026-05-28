use std::{future::Future, sync::Arc};

use anyhow::Context;
use axum::Router;
use tokio::net::TcpListener;
use tracing::info;

use crate::{config::Config, routes};

pub async fn build_router(config: Config) -> Router {
    let state = Arc::new(routes::AppState::new(config).await);
    routes::router(state)
}

pub async fn serve(config: Config) -> anyhow::Result<()> {
    serve_with_shutdown(config, shutdown_signal()).await
}

pub async fn serve_with_shutdown<Shutdown>(config: Config, shutdown: Shutdown) -> anyhow::Result<()>
where
    Shutdown: Future<Output = ()> + Send + 'static,
{
    let bind = config.bind;
    let app = build_router(config).await;
    let listener = TcpListener::bind(bind)
        .await
        .with_context(|| format!("failed to bind {bind}"))?;

    info!(bind = %bind, "starting Codex Remote host runtime");
    axum::serve(listener, app)
        .with_graceful_shutdown(shutdown)
        .await
        .context("server stopped with error")
}

pub async fn shutdown_signal() {
    let _ = tokio::signal::ctrl_c().await;
}
