use tauri::State;

use crate::pm3::error::Pm3Error;
use crate::pm3::output::OutputSnapshot;
use crate::AppState;

#[tauri::command]
pub async fn send_command(state: State<'_, AppState>, command: String) -> Result<(), Pm3Error> {
    state.pm3.send_command(&command).await
}

#[tauri::command]
pub fn get_output_snapshot(state: State<'_, AppState>) -> OutputSnapshot {
    state.pm3.output_snapshot()
}
