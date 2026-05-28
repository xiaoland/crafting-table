use super::contract::{TurnStreamEvent, TurnStreamEventType};

#[derive(Clone, Debug, Default, Eq, PartialEq)]
pub struct TurnStreamProjection {
    pub thread_id: Option<String>,
    pub turn_id: Option<String>,
    pub assistant_text: String,
    pub status: Option<String>,
    pub error_message: Option<String>,
    pub event_count: Option<usize>,
    pub is_terminal: bool,
}

impl TurnStreamProjection {
    pub fn apply(&mut self, event: &TurnStreamEvent) {
        self.thread_id = Some(event.thread_id.clone());
        self.turn_id = Some(event.turn_id.clone());

        match event.event_type {
            TurnStreamEventType::TurnStarted | TurnStreamEventType::Heartbeat => {
                if let Some(status) = &event.status {
                    self.status = Some(status.clone());
                }
            }
            TurnStreamEventType::AssistantDelta => {
                if let Some(text) = &event.text {
                    self.assistant_text.push_str(text);
                }
            }
            TurnStreamEventType::ItemUpdated => {
                if let Some(status) = &event.status {
                    self.status = Some(status.clone());
                }
            }
            TurnStreamEventType::TurnCompleted => {
                self.status = event.status.clone();
                self.event_count = event.event_count;
                self.is_terminal = true;
            }
            TurnStreamEventType::Error => {
                self.error_message = event.message.clone();
                self.is_terminal = true;
            }
        }
    }
}
