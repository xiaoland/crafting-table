use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt, EnvFilter};

use codex_remote_companion::{serve, Config};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::registry()
        .with(EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info")))
        .with(tracing_subscriber::fmt::layer())
        .init();

    let config = Config::from_env()?;
    serve(config).await
}
