use serde::{Deserialize, Serialize};

use super::error::Pm3Error;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum SessionState {
    Disconnected,
    Validating,
    Starting,
    Handshaking,
    Connected,
    Stopping,
    Failed,
}

impl SessionState {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Disconnected => "disconnected",
            Self::Validating => "validating",
            Self::Starting => "starting",
            Self::Handshaking => "handshaking",
            Self::Connected => "connected",
            Self::Stopping => "stopping",
            Self::Failed => "failed",
        }
    }
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SessionSnapshot {
    pub session_id: Option<u64>,
    pub state: SessionState,
    pub client_version: Option<String>,
    pub firmware_version: Option<String>,
    pub last_error: Option<Pm3Error>,
}

impl SessionSnapshot {
    pub fn disconnected() -> Self {
        Self {
            session_id: None,
            state: SessionState::Disconnected,
            client_version: None,
            firmware_version: None,
            last_error: None,
        }
    }
}

impl Default for SessionSnapshot {
    fn default() -> Self {
        Self::disconnected()
    }
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct EventEnvelope<T> {
    pub session_id: Option<u64>,
    pub sequence: u64,
    pub payload: T,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ConnectRequest {
    pub pm3_dir: String,
    pub port: String,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct PortInfo {
    pub name: String,
    pub description: String,
}
