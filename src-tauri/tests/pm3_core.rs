use pm3gui_lib::pm3::operation::{
    prepare_operation, CardSize, KeyType, OperationRequest, RiskLevel,
};
use pm3gui_lib::pm3::output::{OutputDecoder, OutputEntry, OutputRingBuffer, StreamKind};
use pm3gui_lib::pm3::types::{SessionSnapshot, SessionState};
use pm3gui_lib::pm3::validation::validate_client_dir;

#[test]
fn session_snapshot_uses_stable_camel_case_contract() {
    let value = serde_json::to_value(SessionSnapshot::disconnected()).unwrap();
    assert_eq!(value["state"], "disconnected");
    assert!(value["sessionId"].is_null());
    assert_eq!(SessionState::Disconnected.as_str(), "disconnected");
}

#[test]
fn detects_prompt_split_across_chunks_without_newline() {
    let mut decoder = OutputDecoder::new();
    assert!(!decoder.push(b"pm3 -").prompt_seen);
    assert!(decoder.push(b"-> ").prompt_seen);
}

#[test]
fn preserves_utf8_characters_split_across_chunks() {
    let mut decoder = OutputDecoder::new();
    let bytes = "设备".as_bytes();
    assert_eq!(decoder.push(&bytes[..2]).text, "");
    assert_eq!(decoder.push(&bytes[2..]).text, "设备");
}

#[test]
fn ring_buffer_drops_oldest_and_keeps_accepting_output() {
    let mut ring = OutputRingBuffer::new(2, 128);
    for (sequence, text) in [(1, "one"), (2, "two"), (3, "three")] {
        ring.push(OutputEntry {
            session_id: 1,
            sequence,
            stream: StreamKind::Stdout,
            text: text.into(),
        });
    }
    let sequences: Vec<u64> = ring
        .snapshot()
        .entries
        .iter()
        .map(|entry| entry.sequence)
        .collect();
    assert_eq!(sequences, vec![2, 3]);
    assert_eq!(ring.snapshot().dropped_count, 1);
}

#[test]
fn client_validation_is_read_only_and_requires_launcher() {
    let root = tempfile::tempdir().unwrap();
    let error = validate_client_dir(root.path()).unwrap_err();
    assert_eq!(error.code(), "invalid_client_directory");
    assert!(!root.path().join("libs").exists());
}

#[test]
fn validates_mifare_write_and_classifies_block_zero_as_critical() {
    let prepared = prepare_operation(OperationRequest::WriteMifareBlock {
        block: 0,
        key_type: KeyType::A,
        key: "FFFFFFFFFFFF".into(),
        data: "00112233445566778899AABBCCDDEEFF".into(),
    })
    .unwrap();
    assert_eq!(prepared.risk, RiskLevel::Critical);
    assert!(prepared.command.contains("--blk 0"));
}

#[test]
fn rejects_invalid_hex_key_before_rendering_command() {
    let error = prepare_operation(OperationRequest::ReadMifareBlock {
        block: 4,
        key_type: KeyType::A,
        key: "FFFF".into(),
    })
    .unwrap_err();
    assert_eq!(error.code(), "invalid_operation");
}

#[test]
fn restore_rejects_unselected_relative_file() {
    let error = prepare_operation(OperationRequest::RestoreMifare {
        size: CardSize::K1,
        file: "relative.dump".into(),
    })
    .unwrap_err();
    assert_eq!(error.code(), "invalid_operation");
}
