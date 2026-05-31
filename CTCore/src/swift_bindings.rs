use crate::portable_config::{
    CodexRemoteControlEndpoint, ConfigDiagnostic, DiagnosticSeverity, HostConfig, HostEndpoints,
    PortableConfigDocument, SshEndpoint, CURRENT_SCHEMA_VERSION,
};

#[cfg(feature = "codex-remote-control-client")]
use crate::codex_remote_control::{
    client::{
        CodexRemoteClient, CodexRemoteClientStatus, CodexRemoteSnapshot, TurnFollowObserver,
        TurnStreamProjection,
    },
    contract::{
        ActiveTurnSummary, CodexModelSummary, CodexReasoningEffortSummary, HealthResponse,
        ModelListResponse, SemanticThreadDetail, SemanticThreadSummary, ThreadCreateRequest,
        ThreadCreateResponse, ThreadDetailResponse, ThreadListResponse, ThreadSummary,
        ToolCallPayload, TranscriptEntry, TranscriptEntryEnvelope, TurnPermissionMode,
        TurnStreamEvent, TurnStreamEventType, TurnSubmitRequest, TurnSubmitResponse,
        WIRE_CONTRACT_VERSION,
    },
};

#[cfg(feature = "codex-remote-control-client")]
use std::sync::Arc;

#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiPortableConfigDocument {
    pub schema_version: u32,
    pub hosts: Vec<FfiHostConfig>,
}

#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiHostConfig {
    pub id: String,
    pub label: String,
    pub note: Option<String>,
    pub tags: Vec<String>,
    pub endpoints: FfiHostEndpoints,
}

#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiHostEndpoints {
    pub ssh: Option<FfiSshEndpoint>,
    pub codex_remote_control: Option<FfiCodexRemoteControlEndpoint>,
}

#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiSshEndpoint {
    pub address: String,
    pub port: u32,
    pub username: Option<String>,
    pub credential_ref: Option<String>,
}

#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiCodexRemoteControlEndpoint {
    pub base_url: String,
    pub credential_ref: Option<String>,
}

#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiPortableConfigDecodeResult {
    pub document: Option<FfiPortableConfigDocument>,
    pub diagnostics: Vec<FfiConfigDiagnostic>,
    pub error_message: Option<String>,
}

#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiPortableConfigEncodeResult {
    pub json: Option<String>,
    pub error_message: Option<String>,
}

#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiConfigDiagnostic {
    pub severity: FfiDiagnosticSeverity,
    pub code: String,
    pub path: String,
    pub message: String,
}

#[derive(Clone, Debug, uniffi::Enum)]
pub enum FfiDiagnosticSeverity {
    Error,
    Warning,
}

#[cfg(feature = "codex-remote-control-client")]
#[derive(Clone, Debug, Default, uniffi::Record)]
pub struct FfiTurnStreamProjection {
    pub thread_id: Option<String>,
    pub turn_id: Option<String>,
    pub assistant_text: String,
    pub status: Option<String>,
    pub error_message: Option<String>,
    pub event_count: Option<u64>,
    pub is_terminal: bool,
    pub last_sequence: u64,
}

#[cfg(feature = "codex-remote-control-client")]
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiTurnStreamProjectionResult {
    pub projection: Option<FfiTurnStreamProjection>,
    pub error_message: Option<String>,
}

#[cfg(feature = "codex-remote-control-client")]
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiCodexRemoteHealth {
    pub service: String,
    pub version: String,
    pub os: String,
    pub arch: String,
    pub app_server_available: bool,
    pub app_server_probe: String,
    pub codex_home: String,
}

#[cfg(feature = "codex-remote-control-client")]
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiCodexRemoteHealthDecodeResult {
    pub health: Option<FfiCodexRemoteHealth>,
    pub error_message: Option<String>,
}

#[cfg(feature = "codex-remote-control-client")]
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiCodexRemoteThreadSummary {
    pub id: String,
    pub title: String,
    pub updated_at: String,
    pub cwd: Option<String>,
    pub project_key: String,
    pub project_name: String,
    pub status: String,
    pub active_turn: Option<FfiCodexRemoteActiveTurn>,
}

#[cfg(feature = "codex-remote-control-client")]
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiCodexRemoteActiveTurn {
    pub turn_id: String,
    pub status: String,
}

#[cfg(feature = "codex-remote-control-client")]
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiCodexRemoteThreadList {
    pub source: String,
    pub codex_home: String,
    pub skipped_records: u64,
    pub threads: Vec<FfiCodexRemoteThreadSummary>,
}

#[cfg(feature = "codex-remote-control-client")]
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiCodexRemoteThreadListDecodeResult {
    pub threads: Vec<FfiCodexRemoteThreadSummary>,
    pub error_message: Option<String>,
}

#[cfg(feature = "codex-remote-control-client")]
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiCodexRemoteModelList {
    pub source: String,
    pub models: Vec<FfiCodexRemoteModelOption>,
}

#[cfg(feature = "codex-remote-control-client")]
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiCodexRemoteModelOption {
    pub id: String,
    pub model: String,
    pub display_name: String,
    pub description: String,
    pub is_default: bool,
    pub default_reasoning_effort: Option<String>,
    pub supported_reasoning_efforts: Vec<FfiCodexRemoteReasoningEffortOption>,
    pub additional_speed_tiers: Vec<String>,
}

#[cfg(feature = "codex-remote-control-client")]
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiCodexRemoteReasoningEffortOption {
    pub reasoning_effort: String,
    pub description: String,
}

#[cfg(feature = "codex-remote-control-client")]
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiCodexRemoteSnapshot {
    pub health: FfiCodexRemoteHealth,
    pub thread_list: FfiCodexRemoteThreadList,
    pub model_list: FfiCodexRemoteModelList,
}

#[cfg(feature = "codex-remote-control-client")]
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiCodexRemoteSnapshotResult {
    pub snapshot: Option<FfiCodexRemoteSnapshot>,
    pub error_message: Option<String>,
}

#[cfg(feature = "codex-remote-control-client")]
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiCodexRemoteTranscriptRow {
    pub id: String,
    pub role: String,
    pub text: String,
    pub status: Option<String>,
}

#[cfg(feature = "codex-remote-control-client")]
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiCodexRemoteThreadDetail {
    pub id: String,
    pub title: String,
    pub preview: String,
    pub status: String,
    pub active_turn: Option<FfiCodexRemoteActiveTurn>,
    pub updated_at: String,
    pub cwd: Option<String>,
    pub source: Option<String>,
    pub model_provider: Option<String>,
    pub turn_count: u64,
    pub transcript: Vec<FfiCodexRemoteTranscriptRow>,
}

#[cfg(feature = "codex-remote-control-client")]
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiCodexRemoteThreadDetailDecodeResult {
    pub thread: Option<FfiCodexRemoteThreadDetail>,
    pub error_message: Option<String>,
}

#[cfg(feature = "codex-remote-control-client")]
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiCodexRemoteThreadDetailResponse {
    pub source: String,
    pub thread: FfiCodexRemoteThreadDetail,
    pub transcript_entries: Vec<FfiCodexRemoteTranscriptEntry>,
}

#[cfg(feature = "codex-remote-control-client")]
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiCodexRemoteThreadDetailResponseResult {
    pub response: Option<FfiCodexRemoteThreadDetailResponse>,
    pub error_message: Option<String>,
}

#[cfg(feature = "codex-remote-control-client")]
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiCodexRemoteSemanticThread {
    pub id: String,
    pub title: String,
    pub preview: String,
    pub cwd: Option<String>,
    pub status: String,
    pub active_turn: Option<FfiCodexRemoteActiveTurn>,
    pub updated_at: String,
    pub source: Option<String>,
}

#[cfg(feature = "codex-remote-control-client")]
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiCodexRemoteThreadCreateResponse {
    pub thread: FfiCodexRemoteSemanticThread,
    pub model: Option<String>,
    pub model_provider: Option<String>,
    pub service_tier: Option<String>,
}

#[cfg(feature = "codex-remote-control-client")]
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiCodexRemoteThreadCreateResponseResult {
    pub response: Option<FfiCodexRemoteThreadCreateResponse>,
    pub error_message: Option<String>,
}

#[cfg(feature = "codex-remote-control-client")]
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiCodexRemoteTurnSubmit {
    pub thread_id: String,
    pub turn_id: String,
    pub status: String,
    pub assistant_text: String,
    pub event_count: u64,
}

#[cfg(feature = "codex-remote-control-client")]
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiCodexRemoteTurnSubmitDecodeResult {
    pub turn: Option<FfiCodexRemoteTurnSubmit>,
    pub error_message: Option<String>,
}

#[cfg(feature = "codex-remote-control-client")]
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiCodexRemoteTranscriptEntry {
    pub entry_type: String,
    pub id: String,
    pub turn_id: String,
    pub status: Option<String>,
    pub phase: Option<String>,
    pub created_at: Option<String>,
    pub kind: String,
    pub role: String,
    pub text: String,
    pub tool_call: Option<FfiCodexRemoteToolCallPayload>,
}

#[cfg(feature = "codex-remote-control-client")]
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiCodexRemoteToolCallPayload {
    pub kind: String,
    pub summary: String,
    pub command: Option<String>,
    pub cwd: Option<String>,
    pub source: Option<String>,
    pub command_actions_json: Vec<String>,
    pub aggregated_output: Option<String>,
    pub exit_code: Option<i64>,
    pub duration_ms: Option<i64>,
    pub changes_json: Vec<String>,
    pub server: Option<String>,
    pub tool: Option<String>,
    pub arguments_json: Option<String>,
    pub mcp_app_resource_uri: Option<String>,
    pub plugin_id: Option<String>,
    pub result_json: Option<String>,
    pub error_json: Option<String>,
    pub namespace: Option<String>,
    pub content_items_json: Option<String>,
    pub success: Option<bool>,
    pub sender_thread_id: Option<String>,
    pub receiver_thread_ids: Vec<String>,
    pub prompt: Option<String>,
    pub model: Option<String>,
    pub reasoning_effort: Option<String>,
    pub agents_states_json: Option<String>,
    pub query: Option<String>,
    pub action_json: Option<String>,
    pub path: Option<String>,
    pub revised_prompt: Option<String>,
    pub saved_path: Option<String>,
    pub image_status: Option<String>,
}

#[cfg(feature = "codex-remote-control-client")]
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiCodexRemoteTurnStreamEvent {
    pub event_type: String,
    pub thread_id: String,
    pub turn_id: String,
    pub sequence: u64,
    pub text: Option<String>,
    pub status: Option<String>,
    pub message: Option<String>,
    pub kind: Option<String>,
    pub item_id: Option<String>,
    pub event_count: Option<u64>,
    pub transcript_entry: Option<FfiCodexRemoteTranscriptEntry>,
}

#[cfg(feature = "codex-remote-control-client")]
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiCodexRemoteStreamStatus {
    pub status: String,
    pub message: Option<String>,
}

#[cfg(feature = "codex-remote-control-client")]
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiCodexRemoteFollowTurnResult {
    pub error_message: Option<String>,
}

#[cfg(feature = "codex-remote-control-client")]
#[uniffi::export(with_foreign)]
pub trait FfiCodexRemoteTurnObserver: Send + Sync {
    fn on_status(&self, status: FfiCodexRemoteStreamStatus);
    fn on_event(&self, event: FfiCodexRemoteTurnStreamEvent);
    fn on_thread_detail(&self, response: FfiCodexRemoteThreadDetailResponse);
}

#[uniffi::export]
pub fn portable_config_empty_document() -> FfiPortableConfigDocument {
    PortableConfigDocument::default().into()
}

#[uniffi::export]
pub fn portable_config_decode_json(input: String) -> FfiPortableConfigDecodeResult {
    match PortableConfigDocument::from_json_str(&input) {
        Ok(document) => {
            let diagnostics = document
                .validate()
                .into_iter()
                .map(FfiConfigDiagnostic::from)
                .collect();
            FfiPortableConfigDecodeResult {
                document: Some(document.into()),
                diagnostics,
                error_message: None,
            }
        }
        Err(error) => FfiPortableConfigDecodeResult {
            document: None,
            diagnostics: Vec::new(),
            error_message: Some(error.to_string()),
        },
    }
}

#[uniffi::export]
pub fn portable_config_encode_json(
    document: FfiPortableConfigDocument,
) -> FfiPortableConfigEncodeResult {
    match PortableConfigDocument::from(document).to_pretty_json() {
        Ok(json) => FfiPortableConfigEncodeResult {
            json: Some(json),
            error_message: None,
        },
        Err(error) => FfiPortableConfigEncodeResult {
            json: None,
            error_message: Some(error.to_string()),
        },
    }
}

#[uniffi::export]
pub fn portable_config_validate(document: FfiPortableConfigDocument) -> Vec<FfiConfigDiagnostic> {
    PortableConfigDocument::from(document)
        .validate()
        .into_iter()
        .map(FfiConfigDiagnostic::from)
        .collect()
}

#[cfg(feature = "codex-remote-control-client")]
#[uniffi::export]
pub fn codex_remote_wire_contract_version() -> u32 {
    u32::from(WIRE_CONTRACT_VERSION)
}

#[cfg(feature = "codex-remote-control-client")]
#[uniffi::export]
pub fn codex_remote_turn_stream_empty_projection() -> FfiTurnStreamProjection {
    TurnStreamProjection::default().into()
}

#[cfg(feature = "codex-remote-control-client")]
#[uniffi::export]
pub fn codex_remote_turn_stream_apply_event_json(
    projection: FfiTurnStreamProjection,
    event_json: String,
) -> FfiTurnStreamProjectionResult {
    let event = match serde_json::from_str::<TurnStreamEvent>(&event_json) {
        Ok(event) => event,
        Err(error) => {
            return FfiTurnStreamProjectionResult {
                projection: None,
                error_message: Some(error.to_string()),
            }
        }
    };

    let mut projection = TurnStreamProjection::from(projection);
    projection.apply(&event);

    FfiTurnStreamProjectionResult {
        projection: Some(projection.into()),
        error_message: None,
    }
}

#[cfg(feature = "codex-remote-control-client")]
#[uniffi::export]
pub fn codex_remote_decode_health_json(input: String) -> FfiCodexRemoteHealthDecodeResult {
    match serde_json::from_str::<HealthResponse>(&input) {
        Ok(health) => FfiCodexRemoteHealthDecodeResult {
            health: Some(health.into()),
            error_message: None,
        },
        Err(error) => FfiCodexRemoteHealthDecodeResult {
            health: None,
            error_message: Some(error.to_string()),
        },
    }
}

#[cfg(feature = "codex-remote-control-client")]
#[uniffi::export]
pub fn codex_remote_decode_thread_list_json(input: String) -> FfiCodexRemoteThreadListDecodeResult {
    match serde_json::from_str::<ThreadListResponse>(&input) {
        Ok(response) => FfiCodexRemoteThreadListDecodeResult {
            threads: response
                .threads
                .into_iter()
                .map(FfiCodexRemoteThreadSummary::from)
                .collect(),
            error_message: None,
        },
        Err(error) => FfiCodexRemoteThreadListDecodeResult {
            threads: Vec::new(),
            error_message: Some(error.to_string()),
        },
    }
}

#[cfg(feature = "codex-remote-control-client")]
#[uniffi::export]
pub fn codex_remote_decode_thread_detail_json(
    input: String,
) -> FfiCodexRemoteThreadDetailDecodeResult {
    match serde_json::from_str::<ThreadDetailResponse>(&input) {
        Ok(response) => FfiCodexRemoteThreadDetailDecodeResult {
            thread: Some(FfiCodexRemoteThreadDetail::from(response)),
            error_message: None,
        },
        Err(error) => FfiCodexRemoteThreadDetailDecodeResult {
            thread: None,
            error_message: Some(error.to_string()),
        },
    }
}

#[cfg(feature = "codex-remote-control-client")]
#[uniffi::export]
pub fn codex_remote_decode_turn_submit_json(input: String) -> FfiCodexRemoteTurnSubmitDecodeResult {
    match serde_json::from_str::<TurnSubmitResponse>(&input) {
        Ok(turn) => FfiCodexRemoteTurnSubmitDecodeResult {
            turn: Some(turn.into()),
            error_message: None,
        },
        Err(error) => FfiCodexRemoteTurnSubmitDecodeResult {
            turn: None,
            error_message: Some(error.to_string()),
        },
    }
}

#[cfg(feature = "codex-remote-control-client")]
#[derive(uniffi::Object)]
pub struct FfiCodexRemoteClient {
    inner: CodexRemoteClient,
}

#[cfg(feature = "codex-remote-control-client")]
#[uniffi::export]
impl FfiCodexRemoteClient {
    #[uniffi::constructor]
    pub fn new() -> Arc<Self> {
        let inner = CodexRemoteClient::new().expect("Codex Remote HTTP client should initialize");
        Arc::new(Self { inner })
    }

    pub fn load_snapshot(&self, endpoint: String) -> FfiCodexRemoteSnapshotResult {
        match self.inner.load_snapshot(&endpoint) {
            Ok(snapshot) => FfiCodexRemoteSnapshotResult {
                snapshot: Some(snapshot.into()),
                error_message: None,
            },
            Err(error) => FfiCodexRemoteSnapshotResult {
                snapshot: None,
                error_message: Some(error.to_string()),
            },
        }
    }

    pub fn load_thread_detail(
        &self,
        endpoint: String,
        thread_id: String,
    ) -> FfiCodexRemoteThreadDetailResponseResult {
        match self.inner.load_thread_detail(&endpoint, &thread_id) {
            Ok(response) => FfiCodexRemoteThreadDetailResponseResult {
                response: Some(response.into()),
                error_message: None,
            },
            Err(error) => FfiCodexRemoteThreadDetailResponseResult {
                response: None,
                error_message: Some(error.to_string()),
            },
        }
    }

    pub fn create_thread(
        &self,
        endpoint: String,
        cwd: String,
        model: Option<String>,
        service_tier: Option<String>,
    ) -> FfiCodexRemoteThreadCreateResponseResult {
        let request = ThreadCreateRequest {
            cwd,
            model,
            service_tier,
        };

        match self.inner.create_thread(&endpoint, request) {
            Ok(response) => FfiCodexRemoteThreadCreateResponseResult {
                response: Some(response.into()),
                error_message: None,
            },
            Err(error) => FfiCodexRemoteThreadCreateResponseResult {
                response: None,
                error_message: Some(error.to_string()),
            },
        }
    }

    pub fn submit_turn(
        &self,
        endpoint: String,
        thread_id: String,
        input: String,
        cwd: Option<String>,
        model: Option<String>,
        reasoning_effort: Option<String>,
        service_tier: Option<String>,
        permission_mode: Option<String>,
        wait_for_completion: bool,
    ) -> FfiCodexRemoteTurnSubmitDecodeResult {
        let request = TurnSubmitRequest {
            input,
            cwd,
            model,
            reasoning_effort,
            service_tier,
            permission_mode: permission_mode.and_then(|mode| match mode.as_str() {
                "sandbox" => Some(TurnPermissionMode::Sandbox),
                "auto_review" => Some(TurnPermissionMode::AutoReview),
                "full_access" => Some(TurnPermissionMode::FullAccess),
                _ => None,
            }),
            wait_for_completion: Some(wait_for_completion),
        };

        match self.inner.submit_turn(&endpoint, &thread_id, request) {
            Ok(turn) => FfiCodexRemoteTurnSubmitDecodeResult {
                turn: Some(turn.into()),
                error_message: None,
            },
            Err(error) => FfiCodexRemoteTurnSubmitDecodeResult {
                turn: None,
                error_message: Some(error.to_string()),
            },
        }
    }

    pub fn follow_turn(
        &self,
        endpoint: String,
        thread_id: String,
        turn_id: String,
        observer: Arc<dyn FfiCodexRemoteTurnObserver>,
    ) -> FfiCodexRemoteFollowTurnResult {
        let observer = FfiTurnObserverAdapter { observer };

        match self
            .inner
            .follow_turn(&endpoint, &thread_id, &turn_id, &observer)
        {
            Ok(()) => FfiCodexRemoteFollowTurnResult {
                error_message: None,
            },
            Err(error) => FfiCodexRemoteFollowTurnResult {
                error_message: Some(error.to_string()),
            },
        }
    }

    pub fn recover_active_turn(
        &self,
        endpoint: String,
        thread_id: String,
        observer: Arc<dyn FfiCodexRemoteTurnObserver>,
    ) -> FfiCodexRemoteFollowTurnResult {
        let observer = FfiTurnObserverAdapter { observer };

        match self
            .inner
            .recover_active_turn(&endpoint, &thread_id, &observer)
        {
            Ok(()) => FfiCodexRemoteFollowTurnResult {
                error_message: None,
            },
            Err(error) => FfiCodexRemoteFollowTurnResult {
                error_message: Some(error.to_string()),
            },
        }
    }
}

#[cfg(feature = "codex-remote-control-client")]
struct FfiTurnObserverAdapter {
    observer: Arc<dyn FfiCodexRemoteTurnObserver>,
}

#[cfg(feature = "codex-remote-control-client")]
impl TurnFollowObserver for FfiTurnObserverAdapter {
    fn on_status(&self, status: CodexRemoteClientStatus) {
        self.observer.on_status(status.into());
    }

    fn on_event(&self, event: TurnStreamEvent) {
        self.observer.on_event(event.into());
    }

    fn on_thread_detail(&self, detail: ThreadDetailResponse) {
        self.observer.on_thread_detail(detail.into());
    }
}

impl From<PortableConfigDocument> for FfiPortableConfigDocument {
    fn from(document: PortableConfigDocument) -> Self {
        Self {
            schema_version: u32::from(document.schema_version),
            hosts: document
                .hosts
                .into_iter()
                .map(FfiHostConfig::from)
                .collect(),
        }
    }
}

impl From<FfiPortableConfigDocument> for PortableConfigDocument {
    fn from(document: FfiPortableConfigDocument) -> Self {
        Self {
            schema_version: u16::try_from(document.schema_version)
                .unwrap_or(CURRENT_SCHEMA_VERSION),
            hosts: document.hosts.into_iter().map(HostConfig::from).collect(),
        }
    }
}

impl From<HostConfig> for FfiHostConfig {
    fn from(host: HostConfig) -> Self {
        Self {
            id: host.id,
            label: host.label,
            note: host.note,
            tags: host.tags,
            endpoints: host.endpoints.into(),
        }
    }
}

impl From<FfiHostConfig> for HostConfig {
    fn from(host: FfiHostConfig) -> Self {
        Self {
            id: host.id,
            label: host.label,
            note: host.note,
            tags: host.tags,
            endpoints: host.endpoints.into(),
        }
    }
}

impl From<HostEndpoints> for FfiHostEndpoints {
    fn from(endpoints: HostEndpoints) -> Self {
        Self {
            ssh: endpoints.ssh.map(FfiSshEndpoint::from),
            codex_remote_control: endpoints
                .codex_remote_control
                .map(FfiCodexRemoteControlEndpoint::from),
        }
    }
}

impl From<FfiHostEndpoints> for HostEndpoints {
    fn from(endpoints: FfiHostEndpoints) -> Self {
        Self {
            ssh: endpoints.ssh.map(SshEndpoint::from),
            codex_remote_control: endpoints
                .codex_remote_control
                .map(CodexRemoteControlEndpoint::from),
        }
    }
}

impl From<SshEndpoint> for FfiSshEndpoint {
    fn from(endpoint: SshEndpoint) -> Self {
        Self {
            address: endpoint.address,
            port: u32::from(endpoint.port),
            username: endpoint.username,
            credential_ref: endpoint.credential_ref,
        }
    }
}

impl From<FfiSshEndpoint> for SshEndpoint {
    fn from(endpoint: FfiSshEndpoint) -> Self {
        Self {
            address: endpoint.address,
            port: u16::try_from(endpoint.port).unwrap_or(u16::MAX),
            username: endpoint.username,
            credential_ref: endpoint.credential_ref,
        }
    }
}

impl From<CodexRemoteControlEndpoint> for FfiCodexRemoteControlEndpoint {
    fn from(endpoint: CodexRemoteControlEndpoint) -> Self {
        Self {
            base_url: endpoint.base_url,
            credential_ref: endpoint.credential_ref,
        }
    }
}

impl From<FfiCodexRemoteControlEndpoint> for CodexRemoteControlEndpoint {
    fn from(endpoint: FfiCodexRemoteControlEndpoint) -> Self {
        Self {
            base_url: endpoint.base_url,
            credential_ref: endpoint.credential_ref,
        }
    }
}

impl From<ConfigDiagnostic> for FfiConfigDiagnostic {
    fn from(diagnostic: ConfigDiagnostic) -> Self {
        Self {
            severity: diagnostic.severity.into(),
            code: diagnostic.code,
            path: diagnostic.path,
            message: diagnostic.message,
        }
    }
}

impl From<DiagnosticSeverity> for FfiDiagnosticSeverity {
    fn from(severity: DiagnosticSeverity) -> Self {
        match severity {
            DiagnosticSeverity::Error => Self::Error,
            DiagnosticSeverity::Warning => Self::Warning,
        }
    }
}

#[cfg(feature = "codex-remote-control-client")]
impl From<TurnStreamProjection> for FfiTurnStreamProjection {
    fn from(projection: TurnStreamProjection) -> Self {
        Self {
            thread_id: projection.thread_id,
            turn_id: projection.turn_id,
            assistant_text: projection.assistant_text,
            status: projection.status,
            error_message: projection.error_message,
            event_count: projection.event_count.map(|count| count as u64),
            is_terminal: projection.is_terminal,
            last_sequence: projection.last_sequence,
        }
    }
}

#[cfg(feature = "codex-remote-control-client")]
impl From<FfiTurnStreamProjection> for TurnStreamProjection {
    fn from(projection: FfiTurnStreamProjection) -> Self {
        Self {
            thread_id: projection.thread_id,
            turn_id: projection.turn_id,
            assistant_text: projection.assistant_text,
            status: projection.status,
            error_message: projection.error_message,
            event_count: projection
                .event_count
                .and_then(|count| usize::try_from(count).ok()),
            is_terminal: projection.is_terminal,
            last_sequence: projection.last_sequence,
        }
    }
}

#[cfg(feature = "codex-remote-control-client")]
impl From<CodexRemoteSnapshot> for FfiCodexRemoteSnapshot {
    fn from(snapshot: CodexRemoteSnapshot) -> Self {
        Self {
            health: snapshot.health.into(),
            thread_list: snapshot.thread_list.into(),
            model_list: snapshot.model_list.into(),
        }
    }
}

#[cfg(feature = "codex-remote-control-client")]
impl From<HealthResponse> for FfiCodexRemoteHealth {
    fn from(response: HealthResponse) -> Self {
        Self {
            service: response.service,
            version: response.version,
            os: response.platform.os,
            arch: response.platform.arch,
            app_server_available: response.codex.app_server_available,
            app_server_probe: response.codex.app_server_probe,
            codex_home: response.codex.codex_home,
        }
    }
}

#[cfg(feature = "codex-remote-control-client")]
impl From<ThreadSummary> for FfiCodexRemoteThreadSummary {
    fn from(thread: ThreadSummary) -> Self {
        Self {
            id: thread.id,
            title: thread.title,
            updated_at: thread.updated_at,
            cwd: thread.cwd,
            project_key: thread.project_key,
            project_name: thread.project_name,
            status: thread.status,
            active_turn: thread.active_turn.map(FfiCodexRemoteActiveTurn::from),
        }
    }
}

#[cfg(feature = "codex-remote-control-client")]
impl From<ActiveTurnSummary> for FfiCodexRemoteActiveTurn {
    fn from(active_turn: ActiveTurnSummary) -> Self {
        Self {
            turn_id: active_turn.turn_id,
            status: active_turn.status,
        }
    }
}

#[cfg(feature = "codex-remote-control-client")]
impl From<ThreadListResponse> for FfiCodexRemoteThreadList {
    fn from(response: ThreadListResponse) -> Self {
        Self {
            source: response.source,
            codex_home: response.codex_home,
            skipped_records: response.skipped_records as u64,
            threads: response
                .threads
                .into_iter()
                .map(FfiCodexRemoteThreadSummary::from)
                .collect(),
        }
    }
}

#[cfg(feature = "codex-remote-control-client")]
impl From<ModelListResponse> for FfiCodexRemoteModelList {
    fn from(response: ModelListResponse) -> Self {
        Self {
            source: response.source,
            models: response
                .models
                .into_iter()
                .map(FfiCodexRemoteModelOption::from)
                .collect(),
        }
    }
}

#[cfg(feature = "codex-remote-control-client")]
impl From<CodexModelSummary> for FfiCodexRemoteModelOption {
    fn from(model: CodexModelSummary) -> Self {
        Self {
            id: model.id,
            model: model.model,
            display_name: model.display_name,
            description: model.description,
            is_default: model.is_default,
            default_reasoning_effort: model.default_reasoning_effort,
            supported_reasoning_efforts: model
                .supported_reasoning_efforts
                .into_iter()
                .map(FfiCodexRemoteReasoningEffortOption::from)
                .collect(),
            additional_speed_tiers: model.additional_speed_tiers,
        }
    }
}

#[cfg(feature = "codex-remote-control-client")]
impl From<CodexReasoningEffortSummary> for FfiCodexRemoteReasoningEffortOption {
    fn from(effort: CodexReasoningEffortSummary) -> Self {
        Self {
            reasoning_effort: effort.reasoning_effort,
            description: effort.description,
        }
    }
}

#[cfg(feature = "codex-remote-control-client")]
impl From<ThreadDetailResponse> for FfiCodexRemoteThreadDetailResponse {
    fn from(response: ThreadDetailResponse) -> Self {
        let detail = response.thread.clone();
        Self {
            source: response.source,
            thread: detail.into(),
            transcript_entries: response
                .transcript_entries
                .into_iter()
                .map(FfiCodexRemoteTranscriptEntry::from)
                .collect(),
        }
    }
}

#[cfg(feature = "codex-remote-control-client")]
impl From<ThreadDetailResponse> for FfiCodexRemoteThreadDetail {
    fn from(response: ThreadDetailResponse) -> Self {
        let transcript = response
            .transcript_entries
            .into_iter()
            .map(FfiCodexRemoteTranscriptRow::from)
            .collect();
        let mut detail = FfiCodexRemoteThreadDetail::from(response.thread);
        detail.transcript = transcript;
        detail
    }
}

#[cfg(feature = "codex-remote-control-client")]
impl From<SemanticThreadDetail> for FfiCodexRemoteThreadDetail {
    fn from(detail: SemanticThreadDetail) -> Self {
        Self {
            id: detail.id,
            title: detail.title,
            preview: detail.preview,
            status: detail.status,
            active_turn: detail.active_turn.map(FfiCodexRemoteActiveTurn::from),
            updated_at: detail.updated_at,
            cwd: detail.cwd,
            source: detail.source,
            model_provider: detail.model_provider,
            turn_count: detail.turn_count as u64,
            transcript: Vec::new(),
        }
    }
}

#[cfg(feature = "codex-remote-control-client")]
impl From<SemanticThreadSummary> for FfiCodexRemoteSemanticThread {
    fn from(thread: SemanticThreadSummary) -> Self {
        Self {
            id: thread.id,
            title: thread.title,
            preview: thread.preview,
            cwd: thread.cwd,
            status: thread.status,
            active_turn: thread.active_turn.map(FfiCodexRemoteActiveTurn::from),
            updated_at: thread.updated_at,
            source: thread.source,
        }
    }
}

#[cfg(feature = "codex-remote-control-client")]
impl From<ThreadCreateResponse> for FfiCodexRemoteThreadCreateResponse {
    fn from(response: ThreadCreateResponse) -> Self {
        Self {
            thread: response.thread.into(),
            model: response.model,
            model_provider: response.model_provider,
            service_tier: response.service_tier,
        }
    }
}

#[cfg(feature = "codex-remote-control-client")]
impl From<TurnSubmitResponse> for FfiCodexRemoteTurnSubmit {
    fn from(response: TurnSubmitResponse) -> Self {
        Self {
            thread_id: response.thread_id,
            turn_id: response.turn_id,
            status: response.status,
            assistant_text: response.assistant_text,
            event_count: response.event_count as u64,
        }
    }
}

#[cfg(feature = "codex-remote-control-client")]
impl From<TranscriptEntry> for FfiCodexRemoteTranscriptEntry {
    fn from(entry: TranscriptEntry) -> Self {
        match entry {
            TranscriptEntry::UserMessage { envelope, text } => {
                transcript_entry_record("user_message", "userMessage", "user", text, envelope, None)
            }
            TranscriptEntry::AssistantMessage { envelope, text } => transcript_entry_record(
                "assistant_message",
                "agentMessage",
                "assistant",
                text,
                envelope,
                None,
            ),
            TranscriptEntry::ToolCallMessage { envelope, payload } => {
                let text = tool_payload_summary(payload.clone());
                let kind = tool_payload_kind(&payload).to_string();
                transcript_entry_record(
                    "tool_call_message",
                    &kind,
                    "tool",
                    text,
                    envelope,
                    Some(payload.into()),
                )
            }
            TranscriptEntry::GenericEventMessage {
                envelope,
                kind,
                text,
                ..
            } => transcript_entry_record(
                "generic_event_message",
                &kind,
                "event",
                text,
                envelope,
                None,
            ),
        }
    }
}

#[cfg(feature = "codex-remote-control-client")]
impl From<TranscriptEntry> for FfiCodexRemoteTranscriptRow {
    fn from(entry: TranscriptEntry) -> Self {
        let entry = FfiCodexRemoteTranscriptEntry::from(entry);
        Self {
            id: entry.id,
            role: entry.role,
            text: entry.text,
            status: entry.status,
        }
    }
}

#[cfg(feature = "codex-remote-control-client")]
impl From<ToolCallPayload> for FfiCodexRemoteToolCallPayload {
    fn from(payload: ToolCallPayload) -> Self {
        match payload {
            ToolCallPayload::CommandExecution {
                summary,
                command,
                cwd,
                source,
                command_actions,
                aggregated_output,
                exit_code,
                duration_ms,
            } => Self {
                kind: "commandExecution".to_string(),
                summary,
                command: Some(command),
                cwd,
                source,
                command_actions_json: json_values(command_actions),
                aggregated_output,
                exit_code,
                duration_ms,
                ..Self::empty()
            },
            ToolCallPayload::FileChange { summary, changes } => Self {
                kind: "fileChange".to_string(),
                summary,
                changes_json: json_values(changes),
                ..Self::empty()
            },
            ToolCallPayload::McpToolCall {
                summary,
                server,
                tool,
                arguments,
                mcp_app_resource_uri,
                plugin_id,
                result,
                error,
                duration_ms,
            } => Self {
                kind: "mcpToolCall".to_string(),
                summary,
                server,
                tool: Some(tool),
                arguments_json: arguments.and_then(json_value),
                mcp_app_resource_uri,
                plugin_id,
                result_json: result.and_then(json_value),
                error_json: error.and_then(json_value),
                duration_ms,
                ..Self::empty()
            },
            ToolCallPayload::DynamicToolCall {
                summary,
                namespace,
                tool,
                arguments,
                content_items,
                success,
                duration_ms,
            } => Self {
                kind: "dynamicToolCall".to_string(),
                summary,
                namespace,
                tool: Some(tool),
                arguments_json: arguments.and_then(json_value),
                content_items_json: content_items.and_then(json_value),
                success,
                duration_ms,
                ..Self::empty()
            },
            ToolCallPayload::CollabAgentToolCall {
                summary,
                tool,
                sender_thread_id,
                receiver_thread_ids,
                prompt,
                model,
                reasoning_effort,
                agents_states,
            } => Self {
                kind: "collabAgentToolCall".to_string(),
                summary,
                tool: Some(tool),
                sender_thread_id,
                receiver_thread_ids,
                prompt,
                model,
                reasoning_effort,
                agents_states_json: agents_states.and_then(json_value),
                ..Self::empty()
            },
            ToolCallPayload::WebSearch {
                summary,
                query,
                action,
            } => Self {
                kind: "webSearch".to_string(),
                summary,
                query: Some(query),
                action_json: action.and_then(json_value),
                ..Self::empty()
            },
            ToolCallPayload::ImageView { summary, path } => Self {
                kind: "imageView".to_string(),
                summary,
                path,
                ..Self::empty()
            },
            ToolCallPayload::ImageGeneration {
                summary,
                status,
                revised_prompt,
                result,
                saved_path,
            } => Self {
                kind: "imageGeneration".to_string(),
                summary,
                image_status: status,
                revised_prompt,
                result_json: result.map(|value| json_string_value(&value)),
                saved_path,
                ..Self::empty()
            },
        }
    }
}

#[cfg(feature = "codex-remote-control-client")]
impl FfiCodexRemoteToolCallPayload {
    fn empty() -> Self {
        Self {
            kind: String::new(),
            summary: String::new(),
            command: None,
            cwd: None,
            source: None,
            command_actions_json: Vec::new(),
            aggregated_output: None,
            exit_code: None,
            duration_ms: None,
            changes_json: Vec::new(),
            server: None,
            tool: None,
            arguments_json: None,
            mcp_app_resource_uri: None,
            plugin_id: None,
            result_json: None,
            error_json: None,
            namespace: None,
            content_items_json: None,
            success: None,
            sender_thread_id: None,
            receiver_thread_ids: Vec::new(),
            prompt: None,
            model: None,
            reasoning_effort: None,
            agents_states_json: None,
            query: None,
            action_json: None,
            path: None,
            revised_prompt: None,
            saved_path: None,
            image_status: None,
        }
    }
}

#[cfg(feature = "codex-remote-control-client")]
impl From<TurnStreamEvent> for FfiCodexRemoteTurnStreamEvent {
    fn from(event: TurnStreamEvent) -> Self {
        Self {
            event_type: turn_event_type(&event.event_type).to_string(),
            thread_id: event.thread_id,
            turn_id: event.turn_id,
            sequence: event.sequence,
            text: event.text,
            status: event.status,
            message: event.message,
            kind: event.kind,
            item_id: event.item_id,
            event_count: event.event_count.map(|count| count as u64),
            transcript_entry: event
                .transcript_entry
                .map(FfiCodexRemoteTranscriptEntry::from),
        }
    }
}

#[cfg(feature = "codex-remote-control-client")]
impl From<CodexRemoteClientStatus> for FfiCodexRemoteStreamStatus {
    fn from(status: CodexRemoteClientStatus) -> Self {
        Self {
            status: status.status,
            message: status.message,
        }
    }
}

#[cfg(feature = "codex-remote-control-client")]
fn transcript_entry_record(
    entry_type: &str,
    kind: &str,
    role: &str,
    text: String,
    envelope: TranscriptEntryEnvelope,
    tool_call: Option<FfiCodexRemoteToolCallPayload>,
) -> FfiCodexRemoteTranscriptEntry {
    FfiCodexRemoteTranscriptEntry {
        entry_type: entry_type.to_string(),
        id: envelope.id,
        turn_id: envelope.turn_id,
        status: envelope.status,
        phase: envelope.phase,
        created_at: envelope.created_at,
        kind: kind.to_string(),
        role: role.to_string(),
        text,
        tool_call,
    }
}

#[cfg(feature = "codex-remote-control-client")]
fn tool_payload_summary(payload: ToolCallPayload) -> String {
    match payload {
        ToolCallPayload::CommandExecution {
            summary, command, ..
        } => summary_or_fallback(summary, command),
        ToolCallPayload::FileChange { summary, .. } => summary,
        ToolCallPayload::McpToolCall { summary, tool, .. } => summary_or_fallback(summary, tool),
        ToolCallPayload::DynamicToolCall { summary, tool, .. } => {
            summary_or_fallback(summary, tool)
        }
        ToolCallPayload::CollabAgentToolCall { summary, tool, .. } => {
            summary_or_fallback(summary, tool)
        }
        ToolCallPayload::WebSearch { summary, query, .. } => summary_or_fallback(summary, query),
        ToolCallPayload::ImageView { summary, path } => {
            summary_or_fallback(summary, path.unwrap_or_else(|| "Image view".to_string()))
        }
        ToolCallPayload::ImageGeneration { summary, .. } => summary,
    }
}

#[cfg(feature = "codex-remote-control-client")]
fn tool_payload_kind(payload: &ToolCallPayload) -> &'static str {
    match payload {
        ToolCallPayload::CommandExecution { .. } => "commandExecution",
        ToolCallPayload::FileChange { .. } => "fileChange",
        ToolCallPayload::McpToolCall { .. } => "mcpToolCall",
        ToolCallPayload::DynamicToolCall { .. } => "dynamicToolCall",
        ToolCallPayload::CollabAgentToolCall { .. } => "collabAgentToolCall",
        ToolCallPayload::WebSearch { .. } => "webSearch",
        ToolCallPayload::ImageView { .. } => "imageView",
        ToolCallPayload::ImageGeneration { .. } => "imageGeneration",
    }
}

#[cfg(feature = "codex-remote-control-client")]
fn turn_event_type(event_type: &TurnStreamEventType) -> &'static str {
    match event_type {
        TurnStreamEventType::TurnStarted => "turn_started",
        TurnStreamEventType::AssistantDelta => "assistant_delta",
        TurnStreamEventType::ItemUpdated => "item_updated",
        TurnStreamEventType::TurnCompleted => "turn_completed",
        TurnStreamEventType::Error => "error",
        TurnStreamEventType::Heartbeat => "heartbeat",
    }
}

#[cfg(feature = "codex-remote-control-client")]
fn json_values(values: Vec<serde_json::Value>) -> Vec<String> {
    values.into_iter().filter_map(json_value).collect()
}

#[cfg(feature = "codex-remote-control-client")]
fn json_value(value: serde_json::Value) -> Option<String> {
    serde_json::to_string_pretty(&value).ok()
}

#[cfg(feature = "codex-remote-control-client")]
fn json_string_value(value: &str) -> String {
    serde_json::to_string(value).unwrap_or_else(|_| format!("\"{value}\""))
}

#[cfg(feature = "codex-remote-control-client")]
fn summary_or_fallback(summary: String, fallback: String) -> String {
    if summary.trim().is_empty() {
        fallback
    } else {
        summary
    }
}

#[cfg(all(test, feature = "codex-remote-control-client"))]
mod tests {
    use super::{
        codex_remote_decode_health_json, codex_remote_turn_stream_apply_event_json,
        codex_remote_turn_stream_empty_projection,
    };

    #[test]
    fn ffi_turn_stream_projection_applies_wire_json() {
        let projection = codex_remote_turn_stream_empty_projection();
        let result = codex_remote_turn_stream_apply_event_json(
            projection,
            r#"{
                "type": "assistant_delta",
                "thread_id": "thread-a",
                "turn_id": "turn-a",
                "sequence": 1,
                "text": "hello"
            }"#
            .to_string(),
        );

        let projection = result.projection.expect("projection");
        assert_eq!(projection.assistant_text, "hello");
        assert_eq!(projection.thread_id.as_deref(), Some("thread-a"));
        assert!(result.error_message.is_none());
    }

    #[test]
    fn ffi_health_decoder_projects_server_contract() {
        let result = codex_remote_decode_health_json(
            r#"{
                "service": "ct-codex-remote-server",
                "version": "0.1.0",
                "platform": {
                    "os": "macos",
                    "arch": "arm64"
                },
                "codex": {
                    "cli_path": null,
                    "version": null,
                    "app_server_available": true,
                    "app_server_probe": "ok",
                    "codex_home": "/tmp/codex"
                }
            }"#
            .to_string(),
        );

        let health = result.health.expect("health");
        assert_eq!(health.service, "ct-codex-remote-server");
        assert_eq!(health.os, "macos");
        assert!(health.app_server_available);
        assert!(result.error_message.is_none());
    }
}
