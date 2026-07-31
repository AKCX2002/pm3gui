use std::path::Path;

use serde::{Deserialize, Serialize};

use super::error::Pm3Error;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Deserialize, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum RiskLevel {
    ReadOnly,
    Dangerous,
    Critical,
}

#[derive(Debug, Clone, Copy, Deserialize, Serialize)]
#[serde(rename_all = "lowercase")]
pub enum KeyType {
    A,
    B,
}

impl KeyType {
    fn flag(self) -> &'static str {
        match self {
            Self::A => "-a",
            Self::B => "-b",
        }
    }
}

#[derive(Debug, Clone, Copy, Deserialize, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum CardSize {
    K1,
    K2,
    K4,
}

impl CardSize {
    fn flag(self) -> &'static str {
        match self {
            Self::K1 => "--1k",
            Self::K2 => "--2k",
            Self::K4 => "--4k",
        }
    }
}

#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum OperationRequest {
    SearchHf,
    SearchLf,
    MifareInfo,
    MifareDump {
        size: CardSize,
    },
    MifareAutopwn {
        size: CardSize,
    },
    ReadMifareBlock {
        block: u16,
        key_type: KeyType,
        key: String,
    },
    WriteMifareBlock {
        block: u16,
        key_type: KeyType,
        key: String,
        data: String,
    },
    RestoreMifare {
        size: CardSize,
        file: String,
    },
    WipeT55xx,
    SimulateHid {
        card_id: String,
    },
}

#[derive(Debug, Clone)]
pub struct PreparedCommand {
    pub command: String,
    pub risk: RiskLevel,
    pub summary: String,
}

fn normalized_hex(field: &str, value: &str, bytes: usize) -> Result<String, Pm3Error> {
    let normalized: String = value
        .chars()
        .filter(|character| !character.is_whitespace())
        .collect();
    if normalized.len() != bytes * 2
        || !normalized
            .chars()
            .all(|character| character.is_ascii_hexdigit())
    {
        return Err(Pm3Error::InvalidOperation {
            field: field.into(),
            detail: format!("必须是 {} 字节十六进制数据", bytes),
        });
    }
    Ok(normalized.to_ascii_uppercase())
}

fn safe_absolute_path(value: &str) -> Result<String, Pm3Error> {
    if value.contains(['\n', '\r', '"']) || !Path::new(value).is_absolute() {
        return Err(Pm3Error::InvalidOperation {
            field: "file".into(),
            detail: "文件必须由文件选择器提供绝对路径".into(),
        });
    }
    Ok(value.into())
}

pub fn prepare_operation(request: OperationRequest) -> Result<PreparedCommand, Pm3Error> {
    let prepared = match request {
        OperationRequest::SearchHf => PreparedCommand {
            command: "hf search".into(),
            risk: RiskLevel::ReadOnly,
            summary: "搜索 HF 卡片".into(),
        },
        OperationRequest::SearchLf => PreparedCommand {
            command: "lf search".into(),
            risk: RiskLevel::ReadOnly,
            summary: "搜索 LF 卡片".into(),
        },
        OperationRequest::MifareInfo => PreparedCommand {
            command: "hf mf info".into(),
            risk: RiskLevel::ReadOnly,
            summary: "读取 MIFARE 信息".into(),
        },
        OperationRequest::MifareDump { size } => PreparedCommand {
            command: format!("hf mf dump {}", size.flag()),
            risk: RiskLevel::ReadOnly,
            summary: "读取 MIFARE Dump".into(),
        },
        OperationRequest::MifareAutopwn { size } => PreparedCommand {
            command: format!("hf mf autopwn {}", size.flag()),
            risk: RiskLevel::ReadOnly,
            summary: "执行 MIFARE AutoPwn".into(),
        },
        OperationRequest::ReadMifareBlock {
            block,
            key_type,
            key,
        } => {
            if block > 255 {
                return Err(Pm3Error::InvalidOperation {
                    field: "block".into(),
                    detail: "块号必须在 0–255".into(),
                });
            }
            let key = normalized_hex("key", &key, 6)?;
            PreparedCommand {
                command: format!("hf mf rdbl --blk {block} {} -k {key}", key_type.flag()),
                risk: RiskLevel::ReadOnly,
                summary: format!("读取 MIFARE 块 {block}"),
            }
        }
        OperationRequest::WriteMifareBlock {
            block,
            key_type,
            key,
            data,
        } => {
            if block > 255 {
                return Err(Pm3Error::InvalidOperation {
                    field: "block".into(),
                    detail: "块号必须在 0–255".into(),
                });
            }
            let key = normalized_hex("key", &key, 6)?;
            let data = normalized_hex("data", &data, 16)?;
            PreparedCommand {
                command: format!(
                    "hf mf wrbl --blk {block} {} -k {key} -d {data}",
                    key_type.flag()
                ),
                risk: if block == 0 || block % 4 == 3 {
                    RiskLevel::Critical
                } else {
                    RiskLevel::Dangerous
                },
                summary: format!("写入 MIFARE 块 {block}"),
            }
        }
        OperationRequest::RestoreMifare { size, file } => {
            let file = safe_absolute_path(&file)?;
            PreparedCommand {
                command: format!("hf mf restore {} -f \"{file}\"", size.flag()),
                risk: RiskLevel::Dangerous,
                summary: format!("从 {} 恢复 MIFARE", Path::new(&file).display()),
            }
        }
        OperationRequest::WipeT55xx => PreparedCommand {
            command: "lf t55xx wipe".into(),
            risk: RiskLevel::Critical,
            summary: "擦除 T55xx 卡片".into(),
        },
        OperationRequest::SimulateHid { card_id } => {
            if card_id.is_empty()
                || !card_id
                    .chars()
                    .all(|character| character.is_ascii_hexdigit())
            {
                return Err(Pm3Error::InvalidOperation {
                    field: "cardId".into(),
                    detail: "卡号必须是十六进制字符".into(),
                });
            }
            PreparedCommand {
                command: format!("lf hid sim -r {}", card_id.to_ascii_uppercase()),
                risk: RiskLevel::Dangerous,
                summary: "模拟 HID 卡片".into(),
            }
        }
    };
    Ok(prepared)
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct PreparedOperation {
    pub operation_id: u64,
    pub risk: RiskLevel,
    pub summary: String,
    pub confirmation_token: Option<String>,
    pub expires_at_ms: u64,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ConfirmedOperation {
    pub operation_id: u64,
    pub confirmation_token: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct OperationEvent {
    pub operation_id: u64,
    pub status: String,
    pub summary: String,
}
