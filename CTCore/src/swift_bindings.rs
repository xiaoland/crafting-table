use crate::portable_config::{
    CodexRemoteControlEndpoint, ConfigDiagnostic, DiagnosticSeverity, HostConfig, HostEndpoints,
    PortableConfigDocument, SshEndpoint, CURRENT_SCHEMA_VERSION,
};

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
