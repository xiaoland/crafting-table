mod app_server;
mod codex;
mod config;
mod desktop_scout;
mod models;
mod routes;
mod thread_store;

use std::sync::Arc;

use anyhow::Context;
use axum::Router;
use tokio::net::TcpListener;
use tracing::info;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt, EnvFilter};

use crate::{config::Config, routes::AppState};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::registry()
        .with(EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info")))
        .with(tracing_subscriber::fmt::layer())
        .init();

    let config = Config::from_env()?;
    let state = Arc::new(AppState::new(config.clone()).await);
    let app: Router = routes::router(state);
    let listener = TcpListener::bind(config.bind)
        .await
        .with_context(|| format!("failed to bind {}", config.bind))?;

    info!(bind = %config.bind, "starting Codex Remote companion");
    axum::serve(listener, app)
        .with_graceful_shutdown(shutdown_signal())
        .await
        .context("server stopped with error")
}

async fn shutdown_signal() {
    let _ = tokio::signal::ctrl_c().await;
}
