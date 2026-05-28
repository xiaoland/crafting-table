use std::collections::{HashMap, HashSet};

use serde::{Deserialize, Serialize};
use url::Url;

pub const CURRENT_SCHEMA_VERSION: u16 = 1;

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct PortableConfigDocument {
    pub schema_version: u16,
    #[serde(default)]
    pub hosts: Vec<HostConfig>,
}

impl Default for PortableConfigDocument {
    fn default() -> Self {
        Self {
            schema_version: CURRENT_SCHEMA_VERSION,
            hosts: Vec::new(),
        }
    }
}

impl PortableConfigDocument {
    pub fn from_json_str(input: &str) -> Result<Self, serde_json::Error> {
        serde_json::from_str(input)
    }

    pub fn to_pretty_json(&self) -> Result<String, serde_json::Error> {
        serde_json::to_string_pretty(self)
    }

    pub fn validate(&self) -> Vec<ConfigDiagnostic> {
        let mut validator = Validator::default();
        validator.validate_document(self);
        validator.diagnostics
    }

    pub fn is_valid(&self) -> bool {
        self.validate()
            .iter()
            .all(|diagnostic| diagnostic.severity != DiagnosticSeverity::Error)
    }
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct HostConfig {
    pub id: String,
    pub label: String,
    #[serde(default)]
    pub note: Option<String>,
    #[serde(default)]
    pub tags: Vec<String>,
    #[serde(default)]
    pub endpoints: HostEndpoints,
}

#[derive(Clone, Debug, Default, Deserialize, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct HostEndpoints {
    #[serde(default)]
    pub ssh: Option<SshEndpoint>,
    #[serde(default)]
    pub codex_remote_control: Option<CodexRemoteControlEndpoint>,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SshEndpoint {
    pub address: String,
    #[serde(default = "default_ssh_port")]
    pub port: u16,
    #[serde(default)]
    pub username: Option<String>,
    #[serde(default)]
    pub credential_ref: Option<String>,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct CodexRemoteControlEndpoint {
    pub base_url: String,
    #[serde(default)]
    pub credential_ref: Option<String>,
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub enum DiagnosticSeverity {
    Error,
    Warning,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ConfigDiagnostic {
    pub severity: DiagnosticSeverity,
    pub code: String,
    pub path: String,
    pub message: String,
}

impl ConfigDiagnostic {
    fn error(code: impl Into<String>, path: impl Into<String>, message: impl Into<String>) -> Self {
        Self {
            severity: DiagnosticSeverity::Error,
            code: code.into(),
            path: path.into(),
            message: message.into(),
        }
    }

    fn warning(
        code: impl Into<String>,
        path: impl Into<String>,
        message: impl Into<String>,
    ) -> Self {
        Self {
            severity: DiagnosticSeverity::Warning,
            code: code.into(),
            path: path.into(),
            message: message.into(),
        }
    }
}

#[derive(Default)]
struct Validator {
    diagnostics: Vec<ConfigDiagnostic>,
}

impl Validator {
    fn validate_document(&mut self, document: &PortableConfigDocument) {
        if document.schema_version != CURRENT_SCHEMA_VERSION {
            self.diagnostics.push(ConfigDiagnostic::error(
                "unsupported_schema_version",
                "schemaVersion",
                format!(
                    "Expected schema version {}, found {}.",
                    CURRENT_SCHEMA_VERSION, document.schema_version
                ),
            ));
        }

        let mut host_ids = HashSet::new();
        let mut codex_urls: HashMap<String, usize> = HashMap::new();
        let mut ssh_targets: HashMap<String, usize> = HashMap::new();

        for (index, host) in document.hosts.iter().enumerate() {
            let path = format!("hosts[{index}]");
            self.validate_host(host, &path);

            let trimmed_id = host.id.trim();
            if !trimmed_id.is_empty() && !host_ids.insert(trimmed_id.to_string()) {
                self.diagnostics.push(ConfigDiagnostic::error(
                    "duplicate_host_id",
                    format!("{path}.id"),
                    format!("Host id '{trimmed_id}' is duplicated."),
                ));
            }

            if let Some(endpoint) = &host.endpoints.codex_remote_control {
                let trimmed_url = endpoint.base_url.trim();
                if !trimmed_url.is_empty() {
                    if let Some(first_index) = codex_urls.insert(trimmed_url.to_string(), index) {
                        self.diagnostics.push(ConfigDiagnostic::warning(
                            "duplicate_codex_remote_control_endpoint",
                            format!("{path}.endpoints.codexRemoteControl.baseUrl"),
                            format!(
                                "Codex Remote Control endpoint also appears on hosts[{first_index}]."
                            ),
                        ));
                    }
                }
            }

            if let Some(endpoint) = &host.endpoints.ssh {
                let target = format!(
                    "{}:{}:{}",
                    endpoint.username.as_deref().unwrap_or("").trim(),
                    endpoint.address.trim(),
                    endpoint.port
                );
                if let Some(first_index) = ssh_targets.insert(target, index) {
                    self.diagnostics.push(ConfigDiagnostic::warning(
                        "duplicate_ssh_target",
                        format!("{path}.endpoints.ssh"),
                        format!("SSH target also appears on hosts[{first_index}]."),
                    ));
                }
            }
        }
    }

    fn validate_host(&mut self, host: &HostConfig, path: &str) {
        validate_required_identifier(&mut self.diagnostics, &host.id, &format!("{path}.id"));
        validate_required_text(
            &mut self.diagnostics,
            &host.label,
            &format!("{path}.label"),
            "missing_host_label",
            "Host label is required.",
        );

        if host.endpoints.ssh.is_none() && host.endpoints.codex_remote_control.is_none() {
            self.diagnostics.push(ConfigDiagnostic::error(
                "missing_host_endpoint",
                format!("{path}.endpoints"),
                "Host must define at least one endpoint.",
            ));
        }

        if let Some(endpoint) = &host.endpoints.ssh {
            self.validate_ssh_endpoint(endpoint, &format!("{path}.endpoints.ssh"));
        }

        if let Some(endpoint) = &host.endpoints.codex_remote_control {
            self.validate_codex_endpoint(endpoint, &format!("{path}.endpoints.codexRemoteControl"));
        }
    }

    fn validate_ssh_endpoint(&mut self, endpoint: &SshEndpoint, path: &str) {
        validate_required_text(
            &mut self.diagnostics,
            &endpoint.address,
            &format!("{path}.address"),
            "missing_ssh_address",
            "SSH address is required.",
        );

        if endpoint.port == 0 {
            self.diagnostics.push(ConfigDiagnostic::error(
                "invalid_ssh_port",
                format!("{path}.port"),
                "SSH port must be greater than zero.",
            ));
        }

        validate_optional_credential_ref(
            &mut self.diagnostics,
            endpoint.credential_ref.as_deref(),
            &format!("{path}.credentialRef"),
        );
    }

    fn validate_codex_endpoint(&mut self, endpoint: &CodexRemoteControlEndpoint, path: &str) {
        let trimmed_url = endpoint.base_url.trim();
        validate_required_text(
            &mut self.diagnostics,
            trimmed_url,
            &format!("{path}.baseUrl"),
            "missing_codex_remote_control_base_url",
            "Codex Remote Control base URL is required.",
        );

        if !trimmed_url.is_empty() {
            match Url::parse(trimmed_url) {
                Ok(url) if matches!(url.scheme(), "http" | "https") && url.host().is_some() => {}
                Ok(url) => self.diagnostics.push(ConfigDiagnostic::error(
                    "invalid_codex_remote_control_base_url",
                    format!("{path}.baseUrl"),
                    format!(
                        "Codex Remote Control base URL must be http(s) with a host, found '{}'.",
                        url.scheme()
                    ),
                )),
                Err(error) => self.diagnostics.push(ConfigDiagnostic::error(
                    "invalid_codex_remote_control_base_url",
                    format!("{path}.baseUrl"),
                    format!("Codex Remote Control base URL is invalid: {error}."),
                )),
            }
        }

        validate_optional_credential_ref(
            &mut self.diagnostics,
            endpoint.credential_ref.as_deref(),
            &format!("{path}.credentialRef"),
        );
    }
}

fn validate_required_identifier(diagnostics: &mut Vec<ConfigDiagnostic>, value: &str, path: &str) {
    let trimmed = value.trim();
    if trimmed.is_empty() {
        diagnostics.push(ConfigDiagnostic::error(
            "missing_host_id",
            path,
            "Host id is required.",
        ));
        return;
    }

    if trimmed != value {
        diagnostics.push(ConfigDiagnostic::error(
            "invalid_host_id",
            path,
            "Host id must not have surrounding whitespace.",
        ));
    }

    if trimmed.chars().any(|character| {
        !(character.is_ascii_alphanumeric() || matches!(character, '-' | '_' | '.'))
    }) {
        diagnostics.push(ConfigDiagnostic::error(
            "invalid_host_id",
            path,
            "Host id may contain only ASCII letters, digits, '-', '_', or '.'.",
        ));
    }
}

fn validate_required_text(
    diagnostics: &mut Vec<ConfigDiagnostic>,
    value: &str,
    path: &str,
    code: &str,
    message: &str,
) {
    if value.trim().is_empty() {
        diagnostics.push(ConfigDiagnostic::error(code, path, message));
    }
}

fn validate_optional_credential_ref(
    diagnostics: &mut Vec<ConfigDiagnostic>,
    value: Option<&str>,
    path: &str,
) {
    let Some(value) = value else {
        return;
    };

    let trimmed = value.trim();
    if trimmed.is_empty() {
        diagnostics.push(ConfigDiagnostic::error(
            "empty_credential_ref",
            path,
            "Credential reference must be omitted instead of empty.",
        ));
    } else if trimmed != value {
        diagnostics.push(ConfigDiagnostic::error(
            "invalid_credential_ref",
            path,
            "Credential reference must not have surrounding whitespace.",
        ));
    }
}

fn default_ssh_port() -> u16 {
    22
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn valid_document_has_no_diagnostics() {
        let document = PortableConfigDocument {
            schema_version: CURRENT_SCHEMA_VERSION,
            hosts: vec![HostConfig {
                id: "mac-mini".to_string(),
                label: "Mac mini".to_string(),
                note: Some("Desk host".to_string()),
                tags: vec!["desktop".to_string()],
                endpoints: HostEndpoints {
                    ssh: Some(SshEndpoint {
                        address: "mac-mini.local".to_string(),
                        port: 22,
                        username: Some("xiaoland".to_string()),
                        credential_ref: Some("keychain:ssh/mac-mini".to_string()),
                    }),
                    codex_remote_control: Some(CodexRemoteControlEndpoint {
                        base_url: "http://mac-mini.local:3765".to_string(),
                        credential_ref: Some("keychain:codex/mac-mini".to_string()),
                    }),
                },
            }],
        };

        assert!(document.validate().is_empty());
        assert!(document.is_valid());
    }

    #[test]
    fn invalid_document_reports_errors() {
        let document = PortableConfigDocument {
            schema_version: 999,
            hosts: vec![
                HostConfig {
                    id: "bad id".to_string(),
                    label: " ".to_string(),
                    note: None,
                    tags: Vec::new(),
                    endpoints: HostEndpoints::default(),
                },
                HostConfig {
                    id: "bad id".to_string(),
                    label: "Duplicate".to_string(),
                    note: None,
                    tags: Vec::new(),
                    endpoints: HostEndpoints {
                        ssh: None,
                        codex_remote_control: Some(CodexRemoteControlEndpoint {
                            base_url: "ftp://host".to_string(),
                            credential_ref: Some(" ".to_string()),
                        }),
                    },
                },
            ],
        };

        let codes: HashSet<_> = document
            .validate()
            .into_iter()
            .map(|diagnostic| diagnostic.code)
            .collect();

        assert!(codes.contains("unsupported_schema_version"));
        assert!(codes.contains("invalid_host_id"));
        assert!(codes.contains("missing_host_label"));
        assert!(codes.contains("missing_host_endpoint"));
        assert!(codes.contains("duplicate_host_id"));
        assert!(codes.contains("invalid_codex_remote_control_base_url"));
        assert!(codes.contains("empty_credential_ref"));
        assert!(!document.is_valid());
    }
}
