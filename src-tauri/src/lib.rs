use tauri::{Emitter, Manager};

pub mod commands;
pub mod commands_def;
pub mod services;

/// Shared application state managed by Tauri.
pub struct AppState {
    pub pm3: services::pm3_process::Pm3Service,
}

impl AppState {
    pub fn new() -> Self {
        Self {
            pm3: services::pm3_process::Pm3Service::new(),
        }
    }
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_fs::init())
        .manage(AppState::new())
        .setup(|app| {
            // Forward PM3 output lines as Tauri events
            let state = app.state::<AppState>();
            let mut rx = state.pm3.output_rx();
            let handle = app.handle().clone();
            std::thread::spawn(move || {
                while let Ok(line) = rx.blocking_recv() {
                    let _ = handle.emit("pm3-output", line);
                }
            });

            #[cfg(debug_assertions)]
            {
                let window = app.get_webview_window("main").unwrap();
                window.open_devtools();
            }
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            commands::connection::get_ports,
            commands::connection::connect,
            commands::connection::disconnect,
            commands::connection::get_pm3_state,
            commands::terminal::send_command,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
