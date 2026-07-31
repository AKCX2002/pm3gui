use tauri::State;

use crate::pm3::error::Pm3Error;
use crate::pm3::operation::{ConfirmedOperation, OperationRequest, PreparedOperation};
use crate::AppState;

#[tauri::command]
pub fn prepare_operation(
    state: State<'_, AppState>,
    request: OperationRequest,
) -> Result<PreparedOperation, Pm3Error> {
    state.pm3.prepare_operation(request)
}

#[tauri::command]
pub async fn execute_operation(
    state: State<'_, AppState>,
    confirmed: ConfirmedOperation,
) -> Result<(), Pm3Error> {
    state.pm3.execute_operation(confirmed).await
}
