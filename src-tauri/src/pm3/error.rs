use serde::Serialize;

#[derive(Debug, Clone, Serialize, thiserror::Error)]
#[serde(tag = "code", rename_all = "snake_case")]
pub enum Pm3Error {
    #[error("PM3 Client 目录无效")]
    InvalidClientDirectory { detail: String },
    #[error("串口当前不可用")]
    PortUnavailable { port: String },
    #[error("PM3 进程启动失败")]
    LaunchFailed { detail: String },
    #[error("PM3 握手超时")]
    HandshakeTimeout,
    #[error("设备连接已断开")]
    DeviceDisconnected,
    #[error("PM3 进程异常退出")]
    ProcessExited { exit_code: Option<i32> },
    #[error("当前会话正忙")]
    Busy,
    #[error("操作参数无效")]
    InvalidOperation { field: String, detail: String },
    #[error("该操作需要确认")]
    ConfirmationRequired,
    #[error("操作已取消")]
    Cancelled,
    #[error("PM3 输入输出失败")]
    Io { detail: String },
}

impl Pm3Error {
    pub fn code(&self) -> &'static str {
        match self {
            Self::InvalidClientDirectory { .. } => "invalid_client_directory",
            Self::PortUnavailable { .. } => "port_unavailable",
            Self::LaunchFailed { .. } => "launch_failed",
            Self::HandshakeTimeout => "handshake_timeout",
            Self::DeviceDisconnected => "device_disconnected",
            Self::ProcessExited { .. } => "process_exited",
            Self::Busy => "busy",
            Self::InvalidOperation { .. } => "invalid_operation",
            Self::ConfirmationRequired => "confirmation_required",
            Self::Cancelled => "cancelled",
            Self::Io { .. } => "io",
        }
    }
}
