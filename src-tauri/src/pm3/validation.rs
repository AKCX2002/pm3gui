use std::path::{Path, PathBuf};

use super::error::Pm3Error;
use super::types::PortInfo;

#[derive(Debug, Clone)]
pub struct ValidatedClient {
    pub root: PathBuf,
    pub bash: PathBuf,
    pub script: PathBuf,
}

pub fn validate_client_dir(path: &Path) -> Result<ValidatedClient, Pm3Error> {
    if !path.is_dir() {
        return Err(Pm3Error::InvalidClientDirectory {
            detail: "所选路径不是目录".into(),
        });
    }
    let root = path
        .canonicalize()
        .map_err(|error| Pm3Error::InvalidClientDirectory {
            detail: format!("无法规范化目录：{error}"),
        })?;
    let bash = root.join("libs").join("shell").join("bash.exe");
    let script = root.join("pm3");
    if !bash.is_file() {
        return Err(Pm3Error::InvalidClientDirectory {
            detail: format!("缺少启动器：{}", bash.display()),
        });
    }
    if !script.is_file() {
        return Err(Pm3Error::InvalidClientDirectory {
            detail: format!("缺少 PM3 脚本：{}", script.display()),
        });
    }
    Ok(ValidatedClient { root, bash, script })
}

pub fn validate_port(requested: &str, ports: &[PortInfo]) -> Result<(), Pm3Error> {
    let valid_shape = requested.len() > 3
        && requested[..3].eq_ignore_ascii_case("COM")
        && requested[3..]
            .chars()
            .all(|character| character.is_ascii_digit());
    if valid_shape
        && ports
            .iter()
            .any(|port| port.name.eq_ignore_ascii_case(requested))
    {
        Ok(())
    } else {
        Err(Pm3Error::PortUnavailable {
            port: requested.to_string(),
        })
    }
}
