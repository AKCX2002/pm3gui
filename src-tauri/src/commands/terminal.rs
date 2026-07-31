use tauri::State;

use crate::AppState;

#[tauri::command]
pub fn send_command(state: State<'_, AppState>, command: String) -> Result<(), String> {
    state.pm3.send_command(&command)
}
