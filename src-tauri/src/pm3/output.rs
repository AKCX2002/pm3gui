use std::collections::VecDeque;

use serde::Serialize;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum StreamKind {
    Stdout,
    Stderr,
    System,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct OutputEntry {
    pub session_id: u64,
    pub sequence: u64,
    pub stream: StreamKind,
    pub text: String,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct OutputSnapshot {
    pub entries: Vec<OutputEntry>,
    pub dropped_count: u64,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DecodeResult {
    pub text: String,
    pub prompt_seen: bool,
}

#[derive(Debug, Default)]
pub struct OutputDecoder {
    tail: String,
    pending_utf8: Vec<u8>,
}

impl OutputDecoder {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn push(&mut self, bytes: &[u8]) -> DecodeResult {
        let mut input = std::mem::take(&mut self.pending_utf8);
        input.extend_from_slice(bytes);
        let mut text = String::new();
        let mut offset = 0;
        while offset < input.len() {
            match std::str::from_utf8(&input[offset..]) {
                Ok(valid) => {
                    text.push_str(valid);
                    break;
                }
                Err(error) => {
                    let valid_end = offset + error.valid_up_to();
                    if valid_end > offset {
                        text.push_str(
                            std::str::from_utf8(&input[offset..valid_end])
                                .expect("valid_up_to must delimit valid UTF-8"),
                        );
                    }
                    match error.error_len() {
                        Some(length) => {
                            text.push('\u{FFFD}');
                            offset = valid_end + length;
                        }
                        None => {
                            self.pending_utf8.extend_from_slice(&input[valid_end..]);
                            break;
                        }
                    }
                }
            }
        }
        let combined = format!("{}{}", self.tail, text);
        let lower = combined.to_ascii_lowercase();
        let prompt_seen = lower.contains("pm3 -->")
            || lower.contains("communicating with pm3")
            || lower.contains("connected to");
        self.tail = combined
            .chars()
            .rev()
            .take(128)
            .collect::<String>()
            .chars()
            .rev()
            .collect();
        DecodeResult { text, prompt_seen }
    }
}

#[derive(Debug)]
pub struct OutputRingBuffer {
    entries: VecDeque<OutputEntry>,
    bytes: usize,
    max_entries: usize,
    max_bytes: usize,
    dropped_count: u64,
}

impl OutputRingBuffer {
    pub fn new(max_entries: usize, max_bytes: usize) -> Self {
        Self {
            entries: VecDeque::new(),
            bytes: 0,
            max_entries: max_entries.max(1),
            max_bytes: max_bytes.max(1),
            dropped_count: 0,
        }
    }

    pub fn push(&mut self, entry: OutputEntry) {
        self.bytes = self.bytes.saturating_add(entry.text.len());
        self.entries.push_back(entry);
        while self.entries.len() > self.max_entries || self.bytes > self.max_bytes {
            if let Some(removed) = self.entries.pop_front() {
                self.bytes = self.bytes.saturating_sub(removed.text.len());
                self.dropped_count = self.dropped_count.saturating_add(1);
            } else {
                break;
            }
        }
    }

    pub fn snapshot(&self) -> OutputSnapshot {
        OutputSnapshot {
            entries: self.entries.iter().cloned().collect(),
            dropped_count: self.dropped_count,
        }
    }
}
