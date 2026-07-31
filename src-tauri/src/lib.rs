use std::sync::Arc;

use tauri::{Emitter, Manager};

pub mod commands;
pub mod pm3;
pub mod services;

/// Shared application state managed by Tauri.
pub struct AppState {
    pub pm3: Arc<pm3::session::SessionManager>,
}

impl AppState {
    pub fn new() -> Self {
        Self {
            pm3: Arc::new(pm3::session::SessionManager::new()),
        }
    }
}

impl Default for AppState {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_fs::init())
        .manage(AppState::new())
        .setup(|app| {
            let state = app.state::<AppState>();
            let handle = app.handle().clone();
            let mut output_rx = state.pm3.output_rx();
            tauri::async_runtime::spawn(async move {
                while let Ok(entry) = output_rx.recv().await {
                    let _ = handle.emit("pm3://output", entry);
                }
            });

            let state = app.state::<AppState>();
            let mut state_rx = state.pm3.state_rx();
            let handle = app.handle().clone();
            tauri::async_runtime::spawn(async move {
                loop {
                    if state_rx.changed().await.is_err() {
                        break;
                    }
                    let snapshot = state_rx.borrow().clone();
                    let _ = handle.emit("pm3://state", snapshot);
                }
            });

            let state = app.state::<AppState>();
            let mut operation_rx = state.pm3.operation_rx();
            let handle = app.handle().clone();
            tauri::async_runtime::spawn(async move {
                while let Ok(event) = operation_rx.recv().await {
                    let _ = handle.emit("pm3://operation", event);
                }
            });
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            commands::connection::get_ports,
            commands::connection::connect,
            commands::connection::disconnect,
            commands::connection::get_pm3_state,
            commands::terminal::send_command,
            commands::terminal::get_output_snapshot,
            commands::operations::prepare_operation,
            commands::operations::execute_operation,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
