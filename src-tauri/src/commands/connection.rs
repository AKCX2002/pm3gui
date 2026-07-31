use std::path::PathBuf;
use tauri::State;

use crate::services::pm3_process::Pm3State;
use crate::services::serial_mgr::{self, PortInfo};
use crate::AppState;

#[derive(serde::Serialize)]
pub struct ConnectResult {
    pub success: bool,
    pub error: Option<String>,
}

#[tauri::command]
pub fn get_ports() -> Vec<PortInfo> {
    serial_mgr::list_ports()
}

#[tauri::command]
pub fn connect(state: State<'_, AppState>, pm3_dir: String, port: String) -> ConnectResult {
    match state.pm3.connect(PathBuf::from(pm3_dir), &port) {
        Ok(()) => ConnectResult {
            success: true,
            error: None,
        },
        Err(e) => ConnectResult {
            success: false,
            error: Some(e),
        },
    }
}

#[tauri::command]
pub fn disconnect(state: State<'_, AppState>) {
    state.pm3.disconnect();
}

#[tauri::command]
pub fn get_pm3_state(state: State<'_, AppState>) -> Pm3State {
    *state.pm3.state_rx().borrow()
}
