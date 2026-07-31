use tauri::State;

use crate::pm3::error::Pm3Error;
use crate::pm3::types::{ConnectRequest, PortInfo, SessionSnapshot};
use crate::services::serial_mgr;
use crate::AppState;

#[tauri::command]
pub fn get_ports() -> Result<Vec<PortInfo>, Pm3Error> {
    serial_mgr::list_ports()
}

#[tauri::command]
pub async fn connect(
    state: State<'_, AppState>,
    request: ConnectRequest,
) -> Result<SessionSnapshot, Pm3Error> {
    state.pm3.connect(request).await
}

#[tauri::command]
pub async fn disconnect(state: State<'_, AppState>) -> Result<SessionSnapshot, Pm3Error> {
    state.pm3.disconnect().await
}

#[tauri::command]
pub fn get_pm3_state(state: State<'_, AppState>) -> SessionSnapshot {
    state.pm3.snapshot()
}
