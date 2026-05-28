#![cfg(any(
    feature = "codex-remote-control-server",
    feature = "codex-remote-control-client"
))]

use ct_core::codex_remote_control::contract::{
    HealthResponse, HostRuntimeLaunchContext, HostRuntimeState, HostRuntimeStatusResponse,
    TurnPermissionMode, TurnStreamEvent, TurnStreamEventType,
};

#[test]
fn turn_stream_event_decodes_current_wire_shape() {
    let event: TurnStreamEvent = serde_json::from_str(
        r#"{
            "type": "assistant_delta",
            "thread_id": "thread-a",
            "turn_id": "turn-a",
            "sequence": 2,
            "text": "hello",
            "kind": "agentMessage",
            "item_id": "item-agent"
        }"#,
    )
    .expect("event decodes");

    assert_eq!(event.event_type, TurnStreamEventType::AssistantDelta);
    assert_eq!(event.thread_id, "thread-a");
    assert_eq!(event.turn_id, "turn-a");
    assert_eq!(event.sequence, 2);
    assert_eq!(event.text.as_deref(), Some("hello"));
    assert_eq!(event.kind.as_deref(), Some("agentMessage"));
    assert_eq!(event.item_id.as_deref(), Some("item-agent"));
    assert!(!event.is_terminal());

    let encoded = serde_json::to_value(&event).expect("event encodes");
    assert_eq!(encoded["type"], "assistant_delta");
    assert_eq!(encoded["thread_id"], "thread-a");
    assert!(encoded.get("status").is_none());
}

#[test]
fn current_health_and_permission_shapes_decode() {
    let health: HealthResponse = serde_json::from_str(
        r#"{
            "service": "codex-companion",
            "version": "0.1.0",
            "platform": {
                "os": "macos",
                "arch": "arm64"
            },
            "codex": {
                "cli_path": "/opt/homebrew/bin/codex",
                "version": "1.2.3",
                "app_server_available": true,
                "app_server_probe": "ok",
                "codex_home": "/Users/xiaoland/.codex"
            },
            "scouts": {
                "macos": {
                    "configured": true,
                    "probe": "ok"
                },
                "windows": {
                    "configured": false,
                    "probe": "pending"
                }
            }
        }"#,
    )
    .expect("health response decodes");

    assert_eq!(health.codex.app_server_available, true);
    assert_eq!(health.scouts.macos.configured, true);

    let mode: TurnPermissionMode =
        serde_json::from_str(r#""auto_review""#).expect("permission mode decodes");
    assert_eq!(mode, TurnPermissionMode::AutoReview);
    assert_eq!(
        serde_json::to_string(&TurnPermissionMode::FullAccess).expect("mode encodes"),
        r#""full_access""#
    );
}

#[test]
fn host_runtime_status_encodes_server_owned_state() {
    let status = HostRuntimeStatusResponse {
        state: HostRuntimeState::Running,
        pid: 42,
        bind: "127.0.0.1:3765".to_string(),
        codex_home: "/Users/xiaoland/.codex".to_string(),
        launch_context: HostRuntimeLaunchContext::InProcess,
    };

    let encoded = serde_json::to_value(status).expect("status encodes");

    assert_eq!(encoded["state"], "running");
    assert_eq!(encoded["pid"], 42);
    assert_eq!(encoded["launch_context"], "in_process");
}

#[cfg(feature = "codex-remote-control-client")]
mod client_projection_tests {
    use ct_core::codex_remote_control::{
        client::TurnStreamProjection,
        contract::{TurnStreamEvent, TurnStreamEventType},
    };

    #[test]
    fn turn_stream_projection_accumulates_deltas_until_terminal_event() {
        let mut projection = TurnStreamProjection::default();

        for event in [
            event(
                TurnStreamEventType::TurnStarted,
                1,
                None,
                Some("started"),
                None,
                None,
            ),
            event(
                TurnStreamEventType::AssistantDelta,
                2,
                Some("hel"),
                None,
                None,
                None,
            ),
            event(
                TurnStreamEventType::AssistantDelta,
                3,
                Some("lo"),
                None,
                None,
                None,
            ),
            event(
                TurnStreamEventType::TurnCompleted,
                4,
                None,
                Some("completed"),
                None,
                Some(4),
            ),
        ] {
            projection.apply(&event);
        }

        assert_eq!(projection.thread_id.as_deref(), Some("thread-a"));
        assert_eq!(projection.turn_id.as_deref(), Some("turn-a"));
        assert_eq!(projection.assistant_text, "hello");
        assert_eq!(projection.status.as_deref(), Some("completed"));
        assert_eq!(projection.event_count, Some(4));
        assert!(projection.is_terminal);
    }

    #[test]
    fn turn_stream_projection_captures_error_message() {
        let mut projection = TurnStreamProjection::default();
        projection.apply(&event(
            TurnStreamEventType::Error,
            1,
            None,
            None,
            Some("stream failed"),
            None,
        ));

        assert_eq!(projection.error_message.as_deref(), Some("stream failed"));
        assert!(projection.is_terminal);
    }

    fn event(
        event_type: TurnStreamEventType,
        sequence: u64,
        text: Option<&str>,
        status: Option<&str>,
        message: Option<&str>,
        event_count: Option<usize>,
    ) -> TurnStreamEvent {
        TurnStreamEvent {
            event_type,
            thread_id: "thread-a".to_string(),
            turn_id: "turn-a".to_string(),
            sequence,
            text: text.map(ToString::to_string),
            status: status.map(ToString::to_string),
            message: message.map(ToString::to_string),
            kind: None,
            item_id: None,
            event_count,
        }
    }
}
