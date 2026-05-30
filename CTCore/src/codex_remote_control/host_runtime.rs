use serde::{Deserialize, Serialize};
use tokio::sync::broadcast;

use super::contract::{HostRuntimeState, HostRuntimeStatusResponse};

pub const DEFAULT_HOST_RUNTIME_EVENT_CAPACITY: usize = 128;

pub type HostRuntimeEventReceiver = broadcast::Receiver<HostRuntimeEvent>;

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct HostRuntimeConfig {
    pub bind: String,
    pub codex_home: String,
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum HostRuntimeLogLevel {
    Debug,
    Info,
    Warning,
    Error,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum HostRuntimeEvent {
    StatusChanged(HostRuntimeStatusResponse),
    ServerBound {
        bind: String,
    },
    ControlClientConnected {
        client_id: String,
    },
    ControlClientDisconnected {
        client_id: String,
    },
    Log {
        level: HostRuntimeLogLevel,
        message: String,
    },
    Error {
        message: String,
    },
}

#[derive(Debug)]
pub struct HostRuntimeEventBus {
    sender: broadcast::Sender<HostRuntimeEvent>,
}

impl Default for HostRuntimeEventBus {
    fn default() -> Self {
        Self::new(DEFAULT_HOST_RUNTIME_EVENT_CAPACITY)
    }
}

impl HostRuntimeEventBus {
    pub fn new(capacity: usize) -> Self {
        let (sender, _) = broadcast::channel(capacity.max(1));
        Self { sender }
    }

    pub fn subscribe(&self) -> HostRuntimeEventReceiver {
        self.sender.subscribe()
    }

    pub fn publish(&self, event: HostRuntimeEvent) {
        let _ = self.sender.send(event);
    }
}

#[derive(Debug)]
pub struct HostRuntimeHandle {
    status: HostRuntimeStatusResponse,
    events: HostRuntimeEventBus,
}

impl HostRuntimeHandle {
    pub fn new(status: HostRuntimeStatusResponse) -> Self {
        Self {
            status,
            events: HostRuntimeEventBus::default(),
        }
    }

    pub fn status(&self) -> &HostRuntimeStatusResponse {
        &self.status
    }

    pub fn state(&self) -> HostRuntimeState {
        self.status.state
    }

    pub fn events(&self) -> HostRuntimeEventReceiver {
        self.events.subscribe()
    }

    pub fn publish_event(&self, event: HostRuntimeEvent) {
        self.events.publish(event);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::codex_remote_control::contract::HostRuntimeLaunchContext;

    #[test]
    fn event_bus_delivers_published_events_to_subscribers() {
        let runtime = tokio::runtime::Builder::new_current_thread()
            .build()
            .expect("tokio runtime builds");

        runtime.block_on(async {
            let bus = HostRuntimeEventBus::default();
            let mut receiver = bus.subscribe();

            bus.publish(HostRuntimeEvent::ServerBound {
                bind: "127.0.0.1:3765".to_string(),
            });

            assert_eq!(
                receiver.recv().await.expect("event is delivered"),
                HostRuntimeEvent::ServerBound {
                    bind: "127.0.0.1:3765".to_string(),
                }
            );
        });
    }

    #[test]
    fn handle_exposes_status_and_async_event_subscription() {
        let runtime = tokio::runtime::Builder::new_current_thread()
            .build()
            .expect("tokio runtime builds");

        runtime.block_on(async {
            let status = HostRuntimeStatusResponse {
                state: HostRuntimeState::Running,
                pid: 42,
                bind: "127.0.0.1:3765".to_string(),
                codex_home: "/tmp/codex".to_string(),
                launch_context: HostRuntimeLaunchContext::InProcess,
            };
            let handle = HostRuntimeHandle::new(status.clone());
            let mut events = handle.events();

            assert_eq!(handle.status(), &status);
            assert_eq!(handle.state(), HostRuntimeState::Running);

            handle.publish_event(HostRuntimeEvent::StatusChanged(status.clone()));

            assert_eq!(
                events.recv().await.expect("status event is delivered"),
                HostRuntimeEvent::StatusChanged(status)
            );
        });
    }
}
