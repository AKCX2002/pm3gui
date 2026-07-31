use crate::pm3::error::Pm3Error;
use crate::pm3::types::PortInfo;

pub fn list_ports() -> Result<Vec<PortInfo>, Pm3Error> {
    Ok(serialport::available_ports()
        .map_err(|error| Pm3Error::Io {
            detail: format!("枚举串口失败：{error}"),
        })?
        .into_iter()
        .map(|p| PortInfo {
            name: p.port_name,
            description: format!("{:?}", p.port_type),
        })
        .collect())
}
