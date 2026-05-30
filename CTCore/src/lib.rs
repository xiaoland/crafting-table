#[cfg(any(
    feature = "codex-remote-control-server",
    feature = "codex-remote-control-client"
))]
pub mod codex_remote_control;

#[cfg(feature = "inkcre-graph")]
pub mod inkcre_graph;

#[cfg(feature = "local-llm-core")]
pub mod local_llm_core;

#[cfg(feature = "portable-config")]
pub mod portable_config;

#[cfg(feature = "swift-bindings")]
pub mod swift_bindings;

#[cfg(feature = "swift-bindings")]
uniffi::setup_scaffolding!();
