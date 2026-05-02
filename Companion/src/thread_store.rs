use std::{fs, path::Path};

use serde::Deserialize;

use crate::models::{ThreadListResponse, ThreadSummary};

const DEFAULT_THREAD_LIMIT: usize = 20;
const MAX_THREAD_LIMIT: usize = 100;

#[derive(Debug, Deserialize)]
struct SessionIndexRecord {
    id: String,
    thread_name: String,
    updated_at: String,
}

pub fn list_threads(
    codex_home: &Path,
    requested_limit: Option<usize>,
) -> anyhow::Result<ThreadListResponse> {
    let limit = requested_limit
        .unwrap_or(DEFAULT_THREAD_LIMIT)
        .clamp(1, MAX_THREAD_LIMIT);
    let session_index_path = codex_home.join("session_index.jsonl");

    let contents = match fs::read_to_string(&session_index_path) {
        Ok(contents) => contents,
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => String::new(),
        Err(error) => return Err(error.into()),
    };

    let mut skipped_records = 0;
    let mut records = Vec::new();

    for line in contents.lines().filter(|line| !line.trim().is_empty()) {
        match serde_json::from_str::<SessionIndexRecord>(line) {
            Ok(record) => records.push(record),
            Err(_) => skipped_records += 1,
        }
    }

    let threads = records
        .into_iter()
        .rev()
        .take(limit)
        .map(|record| ThreadSummary {
            id: record.id,
            title: record.thread_name,
            updated_at: record.updated_at,
        })
        .collect();

    Ok(ThreadListResponse {
        source: "session_index",
        codex_home: codex_home.display().to_string(),
        skipped_records,
        threads,
    })
}

#[cfg(test)]
mod tests {
    use std::fs;

    use tempfile::TempDir;

    use super::list_threads;

    #[test]
    fn returns_newest_threads_first() {
        let temp_dir = TempDir::new().unwrap();
        fs::write(
            temp_dir.path().join("session_index.jsonl"),
            [
                r#"{"id":"one","thread_name":"First","updated_at":"2026-05-01T00:00:00Z"}"#,
                r#"{"id":"two","thread_name":"Second","updated_at":"2026-05-02T00:00:00Z"}"#,
            ]
            .join("\n"),
        )
        .unwrap();

        let response = list_threads(temp_dir.path(), Some(1)).unwrap();

        assert_eq!(response.threads.len(), 1);
        assert_eq!(response.threads[0].id, "two");
        assert_eq!(response.skipped_records, 0);
    }

    #[test]
    fn skips_malformed_records() {
        let temp_dir = TempDir::new().unwrap();
        fs::write(
            temp_dir.path().join("session_index.jsonl"),
            [
                "not-json",
                r#"{"id":"one","thread_name":"First","updated_at":"2026-05-01T00:00:00Z"}"#,
            ]
            .join("\n"),
        )
        .unwrap();

        let response = list_threads(temp_dir.path(), None).unwrap();

        assert_eq!(response.threads.len(), 1);
        assert_eq!(response.skipped_records, 1);
    }
}
