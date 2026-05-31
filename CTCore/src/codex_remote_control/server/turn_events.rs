use std::{
    collections::{HashMap, VecDeque},
    sync::Arc,
};

use serde::Serialize;
use tokio::sync::{broadcast, Mutex};

use super::models::TranscriptEntry;

const REPLAY_LIMIT: usize = 200;
const BROADCAST_CAPACITY: usize = 200;

#[derive(Clone, Debug, Serialize, PartialEq)]
pub struct TurnStreamEvent {
    #[serde(rename = "type")]
    pub event_type: String,
    pub thread_id: String,
    pub turn_id: String,
    pub sequence: u64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub text: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub status: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub message: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub kind: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub item_id: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub event_count: Option<usize>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub transcript_entry: Option<TranscriptEntry>,
}

impl TurnStreamEvent {
    pub fn unavailable(thread_id: &str, turn_id: &str) -> Self {
        Self {
            event_type: "error".to_string(),
            thread_id: thread_id.to_string(),
            turn_id: turn_id.to_string(),
            sequence: 0,
            text: None,
            status: None,
            message: Some("turn stream is unavailable".to_string()),
            kind: None,
            item_id: None,
            event_count: None,
            transcript_entry: None,
        }
    }

    pub fn heartbeat(thread_id: &str, turn_id: &str) -> Self {
        Self {
            event_type: "heartbeat".to_string(),
            thread_id: thread_id.to_string(),
            turn_id: turn_id.to_string(),
            sequence: 0,
            text: None,
            status: Some("waiting".to_string()),
            message: None,
            kind: None,
            item_id: None,
            event_count: None,
            transcript_entry: None,
        }
    }

    pub fn is_terminal(&self) -> bool {
        matches!(self.event_type.as_str(), "turn_completed" | "error")
    }
}

#[derive(Clone, Default)]
pub struct TurnEventBroker {
    inner: Arc<Mutex<HashMap<TurnEventKey, ActiveTurnEvents>>>,
}

impl TurnEventBroker {
    pub fn new() -> Self {
        Self::default()
    }

    pub async fn create(&self, thread_id: &str, turn_id: &str) {
        let key = TurnEventKey::new(thread_id, turn_id);
        let mut inner = self.inner.lock().await;
        inner.entry(key).or_insert_with(ActiveTurnEvents::new);
    }

    pub async fn publish_started(&self, thread_id: &str, turn_id: &str) -> Option<TurnStreamEvent> {
        self.publish(TurnEventDraft {
            event_type: "turn_started",
            thread_id,
            turn_id,
            text: None,
            status: Some("started"),
            message: None,
            kind: None,
            item_id: None,
            event_count: None,
            transcript_entry: None,
        })
        .await
    }

    pub async fn publish_assistant_delta(
        &self,
        thread_id: &str,
        turn_id: &str,
        item_id: Option<&str>,
        text: &str,
    ) -> Option<TurnStreamEvent> {
        self.publish(TurnEventDraft {
            event_type: "assistant_delta",
            thread_id,
            turn_id,
            text: Some(text),
            status: None,
            message: None,
            kind: Some("agentMessage"),
            item_id,
            event_count: None,
            transcript_entry: None,
        })
        .await
    }

    pub async fn publish_item_updated(
        &self,
        thread_id: &str,
        turn_id: &str,
        kind: &str,
        item_id: Option<&str>,
        text: Option<&str>,
        status: Option<&str>,
        transcript_entry: Option<TranscriptEntry>,
    ) -> Option<TurnStreamEvent> {
        self.publish(TurnEventDraft {
            event_type: "item_updated",
            thread_id,
            turn_id,
            text,
            status,
            message: None,
            kind: Some(kind),
            item_id,
            event_count: None,
            transcript_entry,
        })
        .await
    }

    pub async fn publish_completed(
        &self,
        thread_id: &str,
        turn_id: &str,
        status: &str,
        event_count: usize,
    ) -> Option<TurnStreamEvent> {
        self.publish(TurnEventDraft {
            event_type: "turn_completed",
            thread_id,
            turn_id,
            text: None,
            status: Some(status),
            message: None,
            kind: None,
            item_id: None,
            event_count: Some(event_count),
            transcript_entry: None,
        })
        .await
    }

    pub async fn publish_error(
        &self,
        thread_id: &str,
        turn_id: &str,
        message: &str,
    ) -> Option<TurnStreamEvent> {
        self.publish(TurnEventDraft {
            event_type: "error",
            thread_id,
            turn_id,
            text: None,
            status: None,
            message: Some(message),
            kind: None,
            item_id: None,
            event_count: None,
            transcript_entry: None,
        })
        .await
    }

    pub async fn subscribe(&self, thread_id: &str, turn_id: &str) -> Option<TurnEventSubscription> {
        let key = TurnEventKey::new(thread_id, turn_id);
        let inner = self.inner.lock().await;
        let active = inner.get(&key)?;

        Some(TurnEventSubscription {
            replay: active.replay.iter().cloned().collect(),
            receiver: active.sender.subscribe(),
        })
    }

    async fn publish(&self, draft: TurnEventDraft<'_>) -> Option<TurnStreamEvent> {
        let key = TurnEventKey::new(draft.thread_id, draft.turn_id);
        let mut inner = self.inner.lock().await;
        let active = inner.get_mut(&key)?;
        let event = active.next_event(draft);
        let _ = active.sender.send(event.clone());
        Some(event)
    }
}

pub struct TurnEventSubscription {
    pub replay: Vec<TurnStreamEvent>,
    pub receiver: broadcast::Receiver<TurnStreamEvent>,
}

#[derive(Clone, Debug, Hash, PartialEq, Eq)]
struct TurnEventKey {
    thread_id: String,
    turn_id: String,
}

impl TurnEventKey {
    fn new(thread_id: &str, turn_id: &str) -> Self {
        Self {
            thread_id: thread_id.to_string(),
            turn_id: turn_id.to_string(),
        }
    }
}

struct ActiveTurnEvents {
    next_sequence: u64,
    replay: VecDeque<TurnStreamEvent>,
    sender: broadcast::Sender<TurnStreamEvent>,
}

impl ActiveTurnEvents {
    fn new() -> Self {
        let (sender, _) = broadcast::channel(BROADCAST_CAPACITY);
        Self {
            next_sequence: 1,
            replay: VecDeque::with_capacity(REPLAY_LIMIT),
            sender,
        }
    }

    fn next_event(&mut self, draft: TurnEventDraft<'_>) -> TurnStreamEvent {
        let event = TurnStreamEvent {
            event_type: draft.event_type.to_string(),
            thread_id: draft.thread_id.to_string(),
            turn_id: draft.turn_id.to_string(),
            sequence: self.next_sequence,
            text: draft.text.map(ToString::to_string),
            status: draft.status.map(ToString::to_string),
            message: draft.message.map(ToString::to_string),
            kind: draft.kind.map(ToString::to_string),
            item_id: draft.item_id.map(ToString::to_string),
            event_count: draft.event_count,
            transcript_entry: draft.transcript_entry,
        };
        self.next_sequence += 1;

        if self.replay.len() >= REPLAY_LIMIT {
            self.replay.pop_front();
        }
        self.replay.push_back(event.clone());

        event
    }
}

struct TurnEventDraft<'a> {
    event_type: &'static str,
    thread_id: &'a str,
    turn_id: &'a str,
    text: Option<&'a str>,
    status: Option<&'a str>,
    message: Option<&'a str>,
    kind: Option<&'a str>,
    item_id: Option<&'a str>,
    event_count: Option<usize>,
    transcript_entry: Option<TranscriptEntry>,
}

#[cfg(test)]
mod tests {
    use super::TurnEventBroker;

    #[tokio::test]
    async fn replays_events_in_sequence() {
        let broker = TurnEventBroker::new();
        broker.create("thread-a", "turn-a").await;

        broker.publish_started("thread-a", "turn-a").await;
        broker
            .publish_assistant_delta("thread-a", "turn-a", Some("item-agent"), "hello")
            .await;
        broker
            .publish_item_updated(
                "thread-a",
                "turn-a",
                "commandExecution",
                Some("item-command"),
                Some("echo ok"),
                Some("running"),
                None,
            )
            .await;
        broker
            .publish_completed("thread-a", "turn-a", "completed", 4)
            .await;

        let subscription = broker
            .subscribe("thread-a", "turn-a")
            .await
            .expect("turn stream should exist");
        let sequences = subscription
            .replay
            .iter()
            .map(|event| event.sequence)
            .collect::<Vec<_>>();
        let event_types = subscription
            .replay
            .iter()
            .map(|event| event.event_type.as_str())
            .collect::<Vec<_>>();

        assert_eq!(sequences, vec![1, 2, 3, 4]);
        assert_eq!(
            event_types,
            vec![
                "turn_started",
                "assistant_delta",
                "item_updated",
                "turn_completed"
            ]
        );
        assert_eq!(subscription.replay[1].kind.as_deref(), Some("agentMessage"));
        assert_eq!(
            subscription.replay[1].item_id.as_deref(),
            Some("item-agent")
        );
        assert_eq!(
            subscription.replay[2].kind.as_deref(),
            Some("commandExecution")
        );
        assert_eq!(
            subscription.replay[2].item_id.as_deref(),
            Some("item-command")
        );
        assert_eq!(subscription.replay[2].text.as_deref(), Some("echo ok"));
        assert_eq!(subscription.replay[2].status.as_deref(), Some("running"));
    }

    #[tokio::test]
    async fn missing_turn_stream_does_not_create_on_publish() {
        let broker = TurnEventBroker::new();

        assert!(broker
            .publish_assistant_delta("thread-a", "turn-a", Some("item-agent"), "hello")
            .await
            .is_none());
        assert!(broker.subscribe("thread-a", "turn-a").await.is_none());
    }

    #[test]
    fn heartbeat_is_non_terminal() {
        let event = super::TurnStreamEvent::heartbeat("thread-a", "turn-a");

        assert_eq!(event.event_type, "heartbeat");
        assert_eq!(event.sequence, 0);
        assert!(!event.is_terminal());
    }
}
