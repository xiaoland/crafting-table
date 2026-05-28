#![cfg(feature = "portable-config")]

use std::collections::HashSet;

use ct_core::portable_config::PortableConfigDocument;

#[test]
fn fixture_round_trips_without_validation_errors() {
    let fixture = include_str!("fixtures/portable-config.valid.json");
    let document = PortableConfigDocument::from_json_str(fixture).expect("fixture decodes");

    assert_eq!(document.schema_version, 1);
    assert!(document.is_valid(), "{:#?}", document.validate());

    let encoded = document.to_pretty_json().expect("document encodes");
    let decoded = PortableConfigDocument::from_json_str(&encoded).expect("encoded JSON decodes");

    assert_eq!(document, decoded);
}

#[test]
fn invalid_fixture_reports_stable_diagnostic_codes() {
    let fixture = include_str!("fixtures/portable-config.invalid.json");
    let document = PortableConfigDocument::from_json_str(fixture).expect("fixture decodes");
    let codes: HashSet<_> = document
        .validate()
        .into_iter()
        .map(|diagnostic| diagnostic.code)
        .collect();

    assert!(codes.contains("duplicate_host_id"));
    assert!(codes.contains("invalid_codex_remote_control_base_url"));
    assert!(codes.contains("missing_ssh_address"));
    assert!(codes.contains("invalid_ssh_port"));
}
