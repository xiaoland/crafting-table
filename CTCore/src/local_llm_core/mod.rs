use serde::{Deserialize, Serialize};

pub const CURRENT_MANIFEST_SCHEMA_VERSION: u16 = 1;

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct LocalLLMManifest {
    pub schema_version: u16,
    #[serde(default)]
    pub models: Vec<LocalLLMModelRecord>,
    #[serde(rename = "activeModelID")]
    pub active_model_id: Option<String>,
}

impl Default for LocalLLMManifest {
    fn default() -> Self {
        Self {
            schema_version: CURRENT_MANIFEST_SCHEMA_VERSION,
            models: Vec::new(),
            active_model_id: None,
        }
    }
}

impl LocalLLMManifest {
    pub fn active_model(&self) -> Option<&LocalLLMModelRecord> {
        self.active_model_id
            .as_deref()
            .and_then(|model_id| self.models.iter().find(|model| model.id == model_id))
    }

    pub fn generation_model(
        &self,
        requested_model_id: Option<&str>,
    ) -> Result<&LocalLLMModelRecord, LocalLLMGenerationModelError> {
        let model = if let Some(model_id) = requested_model_id {
            self.models
                .iter()
                .find(|model| model.id == model_id)
                .ok_or_else(|| LocalLLMGenerationModelError::ModelNotFound {
                    model_id: model_id.to_string(),
                })?
        } else {
            self.active_model()
                .ok_or(LocalLLMGenerationModelError::NoActiveModel)?
        };

        if model.is_ready_for_inference() {
            Ok(model)
        } else {
            Err(LocalLLMGenerationModelError::ModelUnavailable {
                model_id: model.id.clone(),
                display_name: model.display_name.clone(),
            })
        }
    }

    pub fn ready_models(&self) -> Vec<&LocalLLMModelRecord> {
        self.models
            .iter()
            .filter(|model| model.is_ready_for_inference())
            .collect()
    }
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct LocalLLMModelRecord {
    pub id: String,
    pub display_name: String,
    pub source: LocalLLMModelSource,
    #[serde(rename = "repositoryID")]
    pub repository_id: Option<String>,
    pub revision: Option<String>,
    pub filename: String,
    #[serde(rename = "downloadURL")]
    pub download_url: String,
    pub license: Option<String>,
    pub file_size: Option<i64>,
    pub sha256: Option<String>,
    pub local_path: Option<String>,
    pub download_state: LocalLLMDownloadState,
    pub verification_state: LocalLLMVerificationState,
    pub activation_state: LocalLLMActivationState,
    pub runtime_compatibility: LocalLLMRuntimeCompatibility,
    pub created_at: String,
    pub updated_at: String,
}

impl LocalLLMModelRecord {
    pub fn is_ready_for_inference(&self) -> bool {
        self.download_state == LocalLLMDownloadState::Downloaded
            && self.verification_state == LocalLLMVerificationState::Verified
            && self
                .local_path
                .as_deref()
                .is_some_and(|path| !path.trim().is_empty())
    }
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub enum LocalLLMModelSource {
    #[serde(rename = "huggingFace")]
    HuggingFace,
    #[serde(rename = "customURL")]
    CustomUrl,
    #[serde(rename = "githubRelease")]
    GitHubRelease,
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub enum LocalLLMDownloadState {
    NotDownloaded,
    Downloading,
    Downloaded,
    Failed,
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub enum LocalLLMVerificationState {
    Unverified,
    Verifying,
    Verified,
    Failed,
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub enum LocalLLMActivationState {
    Inactive,
    Activating,
    Active,
    Failed,
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub enum LocalLLMRuntimeCompatibility {
    Unknown,
    Compatible,
    Incompatible,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum LocalLLMGenerationModelError {
    NoActiveModel,
    ModelNotFound {
        model_id: String,
    },
    ModelUnavailable {
        model_id: String,
        display_name: String,
    },
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum LocalLLMServicePhase {
    Stopped,
    Starting,
    ForegroundListening,
    ForegroundGenerating,
    ContinuedBackground,
    Interrupted,
    Failed,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct LocalLLMServiceState {
    pub phase: LocalLLMServicePhase,
    pub url: Option<String>,
    pub message: Option<String>,
}

impl LocalLLMServiceState {
    pub fn stopped() -> Self {
        Self {
            phase: LocalLLMServicePhase::Stopped,
            url: None,
            message: None,
        }
    }

    pub fn foreground_listening(url: impl Into<String>) -> Self {
        Self {
            phase: LocalLLMServicePhase::ForegroundListening,
            url: Some(url.into()),
            message: None,
        }
    }

    pub fn foreground_generating(url: impl Into<String>) -> Self {
        Self {
            phase: LocalLLMServicePhase::ForegroundGenerating,
            url: Some(url.into()),
            message: None,
        }
    }

    pub fn continued_background(url: impl Into<String>, message: impl Into<String>) -> Self {
        Self {
            phase: LocalLLMServicePhase::ContinuedBackground,
            url: Some(url.into()),
            message: Some(message.into()),
        }
    }

    pub fn interrupted(message: impl Into<String>) -> Self {
        Self {
            phase: LocalLLMServicePhase::Interrupted,
            url: None,
            message: Some(message.into()),
        }
    }

    pub fn failed(message: impl Into<String>) -> Self {
        Self {
            phase: LocalLLMServicePhase::Failed,
            url: None,
            message: Some(message.into()),
        }
    }

    pub fn can_accept_requests(&self) -> bool {
        matches!(
            self.phase,
            LocalLLMServicePhase::ForegroundListening
                | LocalLLMServicePhase::ForegroundGenerating
                | LocalLLMServicePhase::ContinuedBackground
        )
    }
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct LocalLLMGenerationRequest {
    pub model_id: Option<String>,
    pub input: String,
    pub instructions: Option<String>,
    pub max_output_tokens: Option<u32>,
    pub temperature: Option<f64>,
    pub top_p: Option<f64>,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct LocalLLMGenerationResult {
    pub model_id: String,
    pub output_text: String,
    pub input_tokens: Option<u32>,
    pub output_tokens: Option<u32>,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct OpenAIResponseCreateRequest {
    pub model: Option<String>,
    pub input: OpenAIResponseInput,
    pub instructions: Option<String>,
    pub max_output_tokens: Option<u32>,
    pub temperature: Option<f64>,
    pub top_p: Option<f64>,
}

impl OpenAIResponseCreateRequest {
    pub fn generation_request(&self) -> LocalLLMGenerationRequest {
        LocalLLMGenerationRequest {
            model_id: self.model.clone(),
            input: self.input.plain_text(),
            instructions: self.instructions.clone(),
            max_output_tokens: self.max_output_tokens,
            temperature: self.temperature,
            top_p: self.top_p,
        }
    }
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
#[serde(untagged)]
pub enum OpenAIResponseInput {
    Text(String),
    Messages(Vec<OpenAIResponseMessage>),
}

impl OpenAIResponseInput {
    pub fn plain_text(&self) -> String {
        match self {
            OpenAIResponseInput::Text(text) => text.clone(),
            OpenAIResponseInput::Messages(messages) => messages
                .iter()
                .map(|message| {
                    let content = message.content.plain_text();
                    if content.is_empty() {
                        message.role.clone()
                    } else {
                        format!("{}: {}", message.role, content)
                    }
                })
                .collect::<Vec<_>>()
                .join("\n"),
        }
    }
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct OpenAIResponseMessage {
    pub role: String,
    pub content: OpenAIResponseMessageContent,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
#[serde(untagged)]
pub enum OpenAIResponseMessageContent {
    Text(String),
    Parts(Vec<OpenAIResponseContentPart>),
}

impl OpenAIResponseMessageContent {
    pub fn plain_text(&self) -> String {
        match self {
            OpenAIResponseMessageContent::Text(text) => text.clone(),
            OpenAIResponseMessageContent::Parts(parts) => parts
                .iter()
                .filter_map(|part| part.text.as_deref())
                .collect::<Vec<_>>()
                .join("\n"),
        }
    }
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct OpenAIResponseContentPart {
    pub r#type: Option<String>,
    pub text: Option<String>,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct OpenAIModelsListResponse {
    pub object: String,
    pub data: Vec<OpenAIModelObject>,
}

impl OpenAIModelsListResponse {
    pub fn from_ready_models<'a>(
        models: impl IntoIterator<Item = &'a LocalLLMModelRecord>,
    ) -> Self {
        Self {
            object: "list".to_string(),
            data: models
                .into_iter()
                .map(|model| OpenAIModelObject {
                    id: model.id.clone(),
                    object: "model".to_string(),
                    created: parse_unix_seconds(&model.created_at).unwrap_or(0),
                    owned_by: model.source.owner_label().to_string(),
                })
                .collect(),
        }
    }
}

impl LocalLLMModelSource {
    pub fn owner_label(self) -> &'static str {
        match self {
            LocalLLMModelSource::HuggingFace => "Hugging Face",
            LocalLLMModelSource::CustomUrl => "Custom URL",
            LocalLLMModelSource::GitHubRelease => "GitHub Release",
        }
    }
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct OpenAIModelObject {
    pub id: String,
    pub object: String,
    pub created: i64,
    pub owned_by: String,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct OpenAIResponseObject {
    pub id: String,
    pub object: String,
    pub created_at: i64,
    pub status: String,
    pub model: String,
    pub output: Vec<OpenAIResponseOutputItem>,
    pub output_text: String,
    pub usage: Option<OpenAIResponseUsage>,
}

impl OpenAIResponseObject {
    pub fn completed(
        result: &LocalLLMGenerationResult,
        response_id: impl Into<String>,
        message_id: impl Into<String>,
        created_at: i64,
    ) -> Self {
        Self {
            id: response_id.into(),
            object: "response".to_string(),
            created_at,
            status: "completed".to_string(),
            model: result.model_id.clone(),
            output: vec![OpenAIResponseOutputItem {
                id: message_id.into(),
                r#type: "message".to_string(),
                role: "assistant".to_string(),
                content: vec![OpenAIResponseOutputContent {
                    r#type: "output_text".to_string(),
                    text: result.output_text.clone(),
                }],
            }],
            output_text: result.output_text.clone(),
            usage: Some(OpenAIResponseUsage::from_tokens(
                result.input_tokens,
                result.output_tokens,
            )),
        }
    }
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct OpenAIResponseOutputItem {
    pub id: String,
    pub r#type: String,
    pub role: String,
    pub content: Vec<OpenAIResponseOutputContent>,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct OpenAIResponseOutputContent {
    pub r#type: String,
    pub text: String,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct OpenAIResponseUsage {
    pub input_tokens: Option<u32>,
    pub output_tokens: Option<u32>,
    pub total_tokens: Option<u32>,
}

impl OpenAIResponseUsage {
    pub fn from_tokens(input_tokens: Option<u32>, output_tokens: Option<u32>) -> Self {
        let total_tokens = if input_tokens.is_some() || output_tokens.is_some() {
            Some(input_tokens.unwrap_or(0) + output_tokens.unwrap_or(0))
        } else {
            None
        };

        Self {
            input_tokens,
            output_tokens,
            total_tokens,
        }
    }
}

fn parse_unix_seconds(value: &str) -> Option<i64> {
    let digits = value
        .chars()
        .take_while(|character| character.is_ascii_digit())
        .collect::<String>();
    digits.parse().ok()
}
