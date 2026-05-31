use std::{thread, time::Duration};

use reqwest::blocking::{Client as HttpClient, Response};
use serde::de::DeserializeOwned;
use tungstenite::Message;
use url::Url;

use super::contract::{
    ApiError, HealthResponse, ModelListResponse, ThreadCreateRequest, ThreadCreateResponse,
    ThreadDetailResponse, ThreadListResponse, TranscriptEntry, TurnStreamEvent,
    TurnStreamEventType, TurnSubmitRequest, TurnSubmitResponse,
};

const THREAD_LIST_LIMIT: usize = 20;
const RECONNECT_DELAYS: [Duration; 3] = [
    Duration::from_secs(0),
    Duration::from_secs(1),
    Duration::from_secs(2),
];
const POLLING_DELAYS: [Duration; 8] = [
    Duration::from_secs(0),
    Duration::from_secs(1),
    Duration::from_secs(2),
    Duration::from_secs(3),
    Duration::from_secs(5),
    Duration::from_secs(8),
    Duration::from_secs(13),
    Duration::from_secs(21),
];

#[derive(Clone, Debug, PartialEq)]
pub struct CodexRemoteSnapshot {
    pub health: HealthResponse,
    pub thread_list: ThreadListResponse,
    pub model_list: ModelListResponse,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct TurnStreamProjection {
    pub thread_id: Option<String>,
    pub turn_id: Option<String>,
    pub assistant_text: String,
    pub status: Option<String>,
    pub error_message: Option<String>,
    pub event_count: Option<usize>,
    pub is_terminal: bool,
    pub last_sequence: u64,
}

impl Default for TurnStreamProjection {
    fn default() -> Self {
        Self {
            thread_id: None,
            turn_id: None,
            assistant_text: String::new(),
            status: None,
            error_message: None,
            event_count: None,
            is_terminal: false,
            last_sequence: 0,
        }
    }
}

impl TurnStreamProjection {
    pub fn apply(&mut self, event: &TurnStreamEvent) {
        if event.sequence > 0 && event.sequence <= self.last_sequence {
            return;
        }

        self.last_sequence = self.last_sequence.max(event.sequence);
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

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct CodexRemoteClientStatus {
    pub status: String,
    pub message: Option<String>,
}

pub trait TurnFollowObserver {
    fn on_status(&self, status: CodexRemoteClientStatus);
    fn on_event(&self, event: TurnStreamEvent);
    fn on_thread_detail(&self, detail: ThreadDetailResponse);
}

#[derive(Clone)]
pub struct CodexRemoteClient {
    http: HttpClient,
}

impl CodexRemoteClient {
    pub fn new() -> Result<Self, CodexRemoteClientError> {
        let http = HttpClient::builder()
            .timeout(Duration::from_secs(30))
            .build()
            .map_err(CodexRemoteClientError::transport)?;

        Ok(Self { http })
    }

    pub fn load_snapshot(
        &self,
        endpoint: &str,
    ) -> Result<CodexRemoteSnapshot, CodexRemoteClientError> {
        let base = normalized_base_url(endpoint)?;
        let health = self.get(health_url(&base)?)?;
        let thread_list = self.get(threads_url(&base)?)?;
        let model_list = self
            .get(models_url(&base)?)
            .unwrap_or_else(|_| ModelListResponse {
                source: "unavailable".to_string(),
                models: Vec::new(),
            });

        Ok(CodexRemoteSnapshot {
            health,
            thread_list,
            model_list,
        })
    }

    pub fn load_thread_detail(
        &self,
        endpoint: &str,
        thread_id: &str,
    ) -> Result<ThreadDetailResponse, CodexRemoteClientError> {
        let base = normalized_base_url(endpoint)?;
        self.get(thread_url(&base, thread_id)?)
    }

    pub fn create_thread(
        &self,
        endpoint: &str,
        request: ThreadCreateRequest,
    ) -> Result<ThreadCreateResponse, CodexRemoteClientError> {
        let base = normalized_base_url(endpoint)?;
        self.post(threads_collection_url(&base)?, &request)
    }

    pub fn submit_turn(
        &self,
        endpoint: &str,
        thread_id: &str,
        request: TurnSubmitRequest,
    ) -> Result<TurnSubmitResponse, CodexRemoteClientError> {
        let base = normalized_base_url(endpoint)?;
        self.post(turn_submit_url(&base, thread_id)?, &request)
    }

    pub fn follow_turn(
        &self,
        endpoint: &str,
        thread_id: &str,
        turn_id: &str,
        observer: &dyn TurnFollowObserver,
    ) -> Result<(), CodexRemoteClientError> {
        let base = normalized_base_url(endpoint)?;
        let mut projection = TurnStreamProjection::default();
        let mut last_error = None;

        for (attempt, reconnect_delay) in RECONNECT_DELAYS.iter().enumerate() {
            if *reconnect_delay > Duration::from_secs(0) {
                observer.on_status(CodexRemoteClientStatus {
                    status: "reconnecting".to_string(),
                    message: Some("Reconnecting turn stream...".to_string()),
                });
                thread::sleep(*reconnect_delay);
            }

            match self.stream_turn_once(&base, thread_id, turn_id, &mut projection, observer) {
                Ok(()) => return Ok(()),
                Err(error) => {
                    last_error = Some(error.to_string());
                    let has_more_attempts = attempt + 1 < RECONNECT_DELAYS.len();
                    observer.on_status(CodexRemoteClientStatus {
                        status: if has_more_attempts {
                            "reconnecting".to_string()
                        } else {
                            "polling".to_string()
                        },
                        message: last_error.clone(),
                    });
                }
            }
        }

        self.poll_turn_until_recovered(&base, thread_id, turn_id, observer, last_error)
    }

    pub fn recover_active_turn(
        &self,
        endpoint: &str,
        thread_id: &str,
        observer: &dyn TurnFollowObserver,
    ) -> Result<(), CodexRemoteClientError> {
        let detail = self.load_thread_detail(endpoint, thread_id)?;
        let active_turn = detail.thread.active_turn.clone();
        observer.on_thread_detail(detail);

        let Some(active_turn) = active_turn else {
            return Ok(());
        };

        if active_turn.status != "inProgress" {
            return Ok(());
        }

        self.follow_turn(endpoint, thread_id, &active_turn.turn_id, observer)
    }

    fn stream_turn_once(
        &self,
        base: &Url,
        thread_id: &str,
        turn_id: &str,
        projection: &mut TurnStreamProjection,
        observer: &dyn TurnFollowObserver,
    ) -> Result<(), CodexRemoteClientError> {
        let events_url = turn_events_url(base, thread_id, turn_id)?;
        let (mut socket, _) =
            tungstenite::connect(events_url.as_str()).map_err(CodexRemoteClientError::transport)?;

        loop {
            let message = socket.read().map_err(CodexRemoteClientError::transport)?;
            let Some(event) = decode_stream_message(message)? else {
                continue;
            };

            if event.sequence == 0 || event.sequence > projection.last_sequence {
                projection.apply(&event);
                observer.on_event(event.clone());
            }

            if event.is_terminal() {
                return Ok(());
            }
        }
    }

    fn poll_turn_until_recovered(
        &self,
        base: &Url,
        thread_id: &str,
        turn_id: &str,
        observer: &dyn TurnFollowObserver,
        last_error: Option<String>,
    ) -> Result<(), CodexRemoteClientError> {
        for polling_delay in POLLING_DELAYS {
            if polling_delay > Duration::from_secs(0) {
                thread::sleep(polling_delay);
            }

            observer.on_status(CodexRemoteClientStatus {
                status: "polling".to_string(),
                message: last_error.clone(),
            });

            let detail: ThreadDetailResponse = self.get(thread_url(base, thread_id)?)?;
            let is_turn_active = detail
                .thread
                .active_turn
                .as_ref()
                .map(|active_turn| active_turn.turn_id == turn_id)
                .unwrap_or(false);
            let terminal_status = persisted_turn_status(turn_id, &detail);

            observer.on_thread_detail(detail);

            if is_turn_active == false || terminal_status.is_some() {
                observer.on_status(CodexRemoteClientStatus {
                    status: terminal_status.unwrap_or_else(|| "completed".to_string()),
                    message: None,
                });
                return Ok(());
            }
        }

        Err(CodexRemoteClientError::RecoverTimeout)
    }

    fn get<Response>(&self, url: Url) -> Result<Response, CodexRemoteClientError>
    where
        Response: DeserializeOwned,
    {
        let response = self
            .http
            .get(url)
            .send()
            .map_err(CodexRemoteClientError::transport)?;
        decode_response(response)
    }

    fn post<Body, Response>(
        &self,
        url: Url,
        body: &Body,
    ) -> Result<Response, CodexRemoteClientError>
    where
        Body: serde::Serialize,
        Response: DeserializeOwned,
    {
        let response = self
            .http
            .post(url)
            .json(body)
            .send()
            .map_err(CodexRemoteClientError::transport)?;
        decode_response(response)
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum CodexRemoteClientError {
    InvalidEndpoint,
    BadStatus(u16, Option<String>),
    RecoverTimeout,
    Transport(String),
    Decode(String),
}

impl CodexRemoteClientError {
    fn transport(error: impl std::fmt::Display) -> Self {
        Self::Transport(error.to_string())
    }

    fn decode(error: impl std::fmt::Display) -> Self {
        Self::Decode(error.to_string())
    }
}

impl std::fmt::Display for CodexRemoteClientError {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::InvalidEndpoint => {
                write!(formatter, "Enter a valid Codex Remote Server endpoint.")
            }
            Self::BadStatus(status, Some(message)) => {
                write!(
                    formatter,
                    "Codex Remote Server returned HTTP {status}: {message}"
                )
            }
            Self::BadStatus(status, None) => {
                write!(formatter, "Codex Remote Server returned HTTP {status}.")
            }
            Self::RecoverTimeout => write!(
                formatter,
                "Turn stream recovery timed out. Refresh to check the latest state."
            ),
            Self::Transport(message) | Self::Decode(message) => formatter.write_str(message),
        }
    }
}

impl std::error::Error for CodexRemoteClientError {}

fn decode_response<T>(response: Response) -> Result<T, CodexRemoteClientError>
where
    T: DeserializeOwned,
{
    let status = response.status();
    let body = response.text().map_err(CodexRemoteClientError::transport)?;

    if status.is_success() == false {
        let message = serde_json::from_str::<ApiError>(&body)
            .ok()
            .map(|error| error.error);
        return Err(CodexRemoteClientError::BadStatus(status.as_u16(), message));
    }

    serde_json::from_str(&body).map_err(CodexRemoteClientError::decode)
}

fn normalized_base_url(endpoint: &str) -> Result<Url, CodexRemoteClientError> {
    let url = Url::parse(endpoint.trim()).map_err(|_| CodexRemoteClientError::InvalidEndpoint)?;

    match url.scheme() {
        "http" | "https" if url.host_str().is_some() => Ok(url),
        _ => Err(CodexRemoteClientError::InvalidEndpoint),
    }
}

fn health_url(base: &Url) -> Result<Url, CodexRemoteClientError> {
    api_url(base, &["health"])
}

fn models_url(base: &Url) -> Result<Url, CodexRemoteClientError> {
    api_url(base, &["models"])
}

fn threads_collection_url(base: &Url) -> Result<Url, CodexRemoteClientError> {
    api_url(base, &["threads"])
}

fn threads_url(base: &Url) -> Result<Url, CodexRemoteClientError> {
    let mut url = threads_collection_url(base)?;
    url.query_pairs_mut()
        .append_pair("limit", &THREAD_LIST_LIMIT.to_string());
    Ok(url)
}

fn thread_url(base: &Url, thread_id: &str) -> Result<Url, CodexRemoteClientError> {
    api_url(base, &["threads", thread_id])
}

fn turn_submit_url(base: &Url, thread_id: &str) -> Result<Url, CodexRemoteClientError> {
    api_url(base, &["threads", thread_id, "turns"])
}

fn turn_events_url(
    base: &Url,
    thread_id: &str,
    turn_id: &str,
) -> Result<Url, CodexRemoteClientError> {
    let mut url = api_url(base, &["threads", thread_id, "turns", turn_id, "events"])?;

    let scheme = match url.scheme() {
        "http" => "ws",
        "https" => "wss",
        _ => return Err(CodexRemoteClientError::InvalidEndpoint),
    };
    url.set_scheme(scheme)
        .map_err(|_| CodexRemoteClientError::InvalidEndpoint)?;

    Ok(url)
}

fn api_url(base: &Url, path_segments: &[&str]) -> Result<Url, CodexRemoteClientError> {
    let mut url = base.clone();
    url.set_query(None);
    url.set_fragment(None);

    url.path_segments_mut()
        .map_err(|_| CodexRemoteClientError::InvalidEndpoint)?
        .pop_if_empty()
        .extend(path_segments.iter().copied());

    Ok(url)
}

fn decode_stream_message(
    message: Message,
) -> Result<Option<TurnStreamEvent>, CodexRemoteClientError> {
    match message {
        Message::Text(text) => serde_json::from_str(&text)
            .map(Some)
            .map_err(CodexRemoteClientError::decode),
        Message::Binary(data) => serde_json::from_slice(&data)
            .map(Some)
            .map_err(CodexRemoteClientError::decode),
        Message::Ping(_) | Message::Pong(_) | Message::Frame(_) => Ok(None),
        Message::Close(_) => Err(CodexRemoteClientError::Transport(
            "Codex Remote Server closed the turn stream.".to_string(),
        )),
    }
}

fn persisted_turn_status(turn_id: &str, detail: &ThreadDetailResponse) -> Option<String> {
    detail
        .transcript_entries
        .iter()
        .rev()
        .filter_map(|entry| match entry {
            TranscriptEntry::UserMessage { envelope, .. }
            | TranscriptEntry::AssistantMessage { envelope, .. }
            | TranscriptEntry::ToolCallMessage { envelope, .. }
            | TranscriptEntry::GenericEventMessage { envelope, .. } => {
                if envelope.turn_id == turn_id {
                    envelope.status.clone()
                } else {
                    None
                }
            }
        })
        .find(|status| is_terminal_turn_status(status))
}

fn is_terminal_turn_status(status: &str) -> bool {
    matches!(
        status.to_ascii_lowercase().as_str(),
        "completed" | "failed" | "interrupted" | "cancelled" | "canceled"
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn api_url_preserves_base_path_and_encodes_segments() {
        let base = normalized_base_url("https://example.test/api/").unwrap();
        let url = thread_url(&base, "thread/with space").unwrap();

        assert_eq!(
            url.as_str(),
            "https://example.test/api/threads/thread%2Fwith%20space"
        );
    }

    #[test]
    fn turn_events_url_uses_websocket_scheme() {
        let base = normalized_base_url("http://127.0.0.1:8787").unwrap();
        let url = turn_events_url(&base, "thread-1", "turn-1").unwrap();

        assert_eq!(
            url.as_str(),
            "ws://127.0.0.1:8787/threads/thread-1/turns/turn-1/events"
        );
    }

    #[test]
    fn stream_projection_ignores_replayed_sequence() {
        let mut projection = TurnStreamProjection::default();
        let event = TurnStreamEvent {
            event_type: TurnStreamEventType::AssistantDelta,
            thread_id: "thread-1".to_string(),
            turn_id: "turn-1".to_string(),
            sequence: 1,
            text: Some("hello".to_string()),
            status: None,
            message: None,
            kind: None,
            item_id: None,
            event_count: None,
            transcript_entry: None,
        };

        projection.apply(&event);
        projection.apply(&event);

        assert_eq!(projection.assistant_text, "hello");
        assert_eq!(projection.last_sequence, 1);
    }
}
