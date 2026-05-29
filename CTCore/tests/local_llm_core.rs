#![cfg(feature = "local-llm-core")]

use ct_core::local_llm_core::{
    LocalLLMActivationState, LocalLLMDownloadState, LocalLLMGenerationModelError,
    LocalLLMGenerationResult, LocalLLMManifest, LocalLLMModelRecord, LocalLLMModelSource,
    LocalLLMRuntimeCompatibility, LocalLLMServicePhase, LocalLLMServiceState,
    LocalLLMVerificationState, OpenAIModelsListResponse, OpenAIResponseCreateRequest,
    OpenAIResponseObject,
};

#[test]
fn manifest_decodes_current_swift_shape_and_checks_readiness() {
    let manifest: LocalLLMManifest = serde_json::from_str(
        r#"{
            "schemaVersion": 1,
            "activeModelID": "hf:owner/repo:main:model.gguf",
            "models": [
                {
                    "id": "hf:owner/repo:main:model.gguf",
                    "displayName": "Model",
                    "source": "huggingFace",
                    "repositoryID": "owner/repo",
                    "revision": "main",
                    "filename": "model.gguf",
                    "downloadURL": "https://huggingface.co/owner/repo/resolve/main/model.gguf",
                    "license": "apache-2.0",
                    "fileSize": 42,
                    "sha256": null,
                    "localPath": "/models/model.gguf",
                    "downloadState": "downloaded",
                    "verificationState": "verified",
                    "activationState": "active",
                    "runtimeCompatibility": "unknown",
                    "createdAt": "2026-05-28T00:00:00Z",
                    "updatedAt": "2026-05-28T00:00:00Z"
                },
                {
                    "id": "custom:not-ready",
                    "displayName": "Not Ready",
                    "source": "customURL",
                    "repositoryID": null,
                    "revision": null,
                    "filename": "not-ready.gguf",
                    "downloadURL": "https://example.com/not-ready.gguf",
                    "license": null,
                    "fileSize": null,
                    "sha256": null,
                    "localPath": null,
                    "downloadState": "downloaded",
                    "verificationState": "verified",
                    "activationState": "inactive",
                    "runtimeCompatibility": "unknown",
                    "createdAt": "2026-05-28T00:00:00Z",
                    "updatedAt": "2026-05-28T00:00:00Z"
                }
            ]
        }"#,
    )
    .expect("manifest decodes");

    assert_eq!(manifest.schema_version, 1);
    assert_eq!(manifest.models[0].source, LocalLLMModelSource::HuggingFace);
    assert_eq!(manifest.models[1].source, LocalLLMModelSource::CustomUrl);
    assert!(manifest.models[0].is_ready_for_inference());
    assert!(!manifest.models[1].is_ready_for_inference());
    assert_eq!(
        manifest.generation_model(None).expect("active model").id,
        "hf:owner/repo:main:model.gguf"
    );
}

#[test]
fn generation_model_reports_missing_and_unavailable_models() {
    let manifest = LocalLLMManifest {
        schema_version: 1,
        models: vec![model_record("not-ready", None)],
        active_model_id: Some("not-ready".to_string()),
    };

    assert_eq!(
        manifest.generation_model(Some("missing")),
        Err(LocalLLMGenerationModelError::ModelNotFound {
            model_id: "missing".to_string()
        })
    );
    assert_eq!(
        manifest.generation_model(None),
        Err(LocalLLMGenerationModelError::ModelUnavailable {
            model_id: "not-ready".to_string(),
            display_name: "not-ready".to_string()
        })
    );
}

#[test]
fn service_state_distinguishes_foreground_background_and_interrupted() {
    let foreground = LocalLLMServiceState::foreground_listening("http://0.0.0.0:8787");
    let background =
        LocalLLMServiceState::continued_background("http://0.0.0.0:8787", "continued task");
    let interrupted = LocalLLMServiceState::interrupted("suspended by system");

    assert_eq!(foreground.phase, LocalLLMServicePhase::ForegroundListening);
    assert!(foreground.can_accept_requests());
    assert_eq!(background.phase, LocalLLMServicePhase::ContinuedBackground);
    assert!(background.can_accept_requests());
    assert_eq!(interrupted.phase, LocalLLMServicePhase::Interrupted);
    assert!(!interrupted.can_accept_requests());
}

#[test]
fn openai_response_request_flattens_message_input() {
    let request: OpenAIResponseCreateRequest = serde_json::from_str(
        r#"{
            "model": "ready",
            "instructions": "Be terse.",
            "input": [
                {
                    "role": "user",
                    "content": [
                        {"type": "input_text", "text": "hello"},
                        {"type": "input_text", "text": "world"}
                    ]
                }
            ],
            "max_output_tokens": 128,
            "temperature": 0.7,
            "top_p": 0.9
        }"#,
    )
    .expect("request decodes");

    let generation_request = request.generation_request();
    assert_eq!(generation_request.model_id.as_deref(), Some("ready"));
    assert_eq!(generation_request.input, "user: hello\nworld");
    assert_eq!(generation_request.max_output_tokens, Some(128));
}

#[test]
fn openai_models_list_exposes_only_ready_models() {
    let manifest = LocalLLMManifest {
        schema_version: 1,
        models: vec![
            model_record("ready", Some("/models/ready.gguf")),
            model_record("not-ready", None),
        ],
        active_model_id: Some("ready".to_string()),
    };

    let response = OpenAIModelsListResponse::from_ready_models(manifest.ready_models());
    let encoded = serde_json::to_value(response).expect("models response encodes");

    assert_eq!(encoded["object"], "list");
    assert_eq!(encoded["data"].as_array().expect("models array").len(), 1);
    assert_eq!(encoded["data"][0]["id"], "ready");
    assert_eq!(encoded["data"][0]["owned_by"], "Hugging Face");
}

#[test]
fn openai_response_object_maps_generation_result() {
    let result = LocalLLMGenerationResult {
        model_id: "ready".to_string(),
        output_text: "Done.".to_string(),
        input_tokens: Some(2),
        output_tokens: Some(3),
    };

    let response = OpenAIResponseObject::completed(&result, "resp_test", "msg_test", 1_770_000_000);
    let encoded = serde_json::to_value(response).expect("response encodes");

    assert_eq!(encoded["id"], "resp_test");
    assert_eq!(encoded["created_at"], 1_770_000_000);
    assert_eq!(encoded["output_text"], "Done.");
    assert_eq!(encoded["usage"]["total_tokens"], 5);
    assert_eq!(encoded["output"][0]["content"][0]["type"], "output_text");
}

fn model_record(id: &str, local_path: Option<&str>) -> LocalLLMModelRecord {
    LocalLLMModelRecord {
        id: id.to_string(),
        display_name: id.to_string(),
        source: LocalLLMModelSource::HuggingFace,
        repository_id: Some("owner/repo".to_string()),
        revision: Some("main".to_string()),
        filename: format!("{id}.gguf"),
        download_url: format!("https://example.com/{id}.gguf"),
        license: None,
        file_size: None,
        sha256: None,
        local_path: local_path.map(ToString::to_string),
        download_state: LocalLLMDownloadState::Downloaded,
        verification_state: LocalLLMVerificationState::Verified,
        activation_state: LocalLLMActivationState::Inactive,
        runtime_compatibility: LocalLLMRuntimeCompatibility::Unknown,
        created_at: "2026-05-28T00:00:00Z".to_string(),
        updated_at: "2026-05-28T00:00:00Z".to_string(),
    }
}
