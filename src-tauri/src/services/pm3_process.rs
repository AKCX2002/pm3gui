use std::io::{BufRead, BufReader, Write};
use std::path::{Path, PathBuf};
use std::process::{Child, Command, Stdio};
use std::sync::Mutex;
use tokio::sync::{broadcast, watch};

/// Connection state of the Proxmark3 client process.
#[derive(Debug, Clone, Copy, PartialEq, serde::Serialize)]
pub enum Pm3State {
    Disconnected,
    Connecting,
    Connected,
}

/// Manages a single Proxmark3 client process lifecycle.
///
/// Stdout/stderr are streamed line-by-line through a [`broadcast`] channel so
/// multiple consumers (UI panels, loggers, …) can subscribe independently.
/// Connection state is published through a [`watch`] channel.
pub struct Pm3Service {
    process: Mutex<Option<Child>>,
    stdin: Mutex<Option<std::process::ChildStdin>>,
    output_tx: broadcast::Sender<String>,
    state_tx: watch::Sender<Pm3State>,
}

impl Pm3Service {
    pub fn new() -> Self {
        let (output_tx, _) = broadcast::channel(1024);
        let (state_tx, _) = watch::channel(Pm3State::Disconnected);
        Self {
            process: Mutex::new(None),
            stdin: Mutex::new(None),
            output_tx,
            state_tx,
        }
    }

    /// Spawn the PM3 client process for the given serial port.
    ///
    /// Any previously running process is killed first.
    pub fn connect(&self, pm3_dir: PathBuf, port: &str) -> Result<(), String> {
        // Tear down a previous session if one exists.
        self.disconnect();

        self.state_tx.send(Pm3State::Connecting).ok();

        let (cmd, args, envs) = build_command(&pm3_dir, port);

        let mut command = Command::new(&cmd);
        command.args(&args);
        command.current_dir(&pm3_dir);
        command.stdin(Stdio::piped());
        command.stdout(Stdio::piped());
        command.stderr(Stdio::piped());
        for (k, v) in &envs {
            command.env(k, v);
        }

        let mut child = command
            .spawn()
            .map_err(|e| format!("Failed to start PM3: {e}"))?;

        let stdin = child.stdin.take();
        let stdout = child.stdout.take();
        let stderr = child.stderr.take();

        *self.process.lock().unwrap() = Some(child);
        *self.stdin.lock().unwrap() = stdin;

        // --- stdout reader thread ---
        let output_tx = self.output_tx.clone();
        let state_tx = self.state_tx.clone();
        if let Some(stdout) = stdout {
            std::thread::spawn(move || {
                let reader = BufReader::new(stdout);
                for line in reader.lines() {
                    match line {
                        Ok(text) => {
                            if is_connection_output(&text) {
                                let _ = state_tx.send(Pm3State::Connected);
                            }
                            let _ = output_tx.send(text);
                        }
                        Err(_) => break,
                    }
                }
            });
        }

        // --- stderr reader thread ---
        let output_tx = self.output_tx.clone();
        if let Some(stderr) = stderr {
            std::thread::spawn(move || {
                let reader = BufReader::new(stderr);
                for line in reader.lines() {
                    match line {
                        Ok(text) => {
                            let _ = output_tx.send(format!("[stderr] {text}"));
                        }
                        Err(_) => break,
                    }
                }
            });
        }

        Ok(())
    }

    /// Kill the running PM3 process and reset state to [`Pm3State::Disconnected`].
    pub fn disconnect(&self) {
        let _ = self.state_tx.send(Pm3State::Disconnected);
        *self.stdin.lock().unwrap() = None;
        if let Some(mut child) = self.process.lock().unwrap().take() {
            let _ = child.kill();
            let _ = child.wait();
        }
    }

    /// Write a command to the PM3 client's stdin.
    pub fn send_command(&self, cmd: &str) -> Result<(), String> {
        let mut guard = self.stdin.lock().unwrap();
        if let Some(ref mut stdin) = *guard {
            writeln!(stdin, "{cmd}").map_err(|e| format!("Failed to write: {e}"))?;
            stdin.flush().map_err(|e| format!("Failed to flush: {e}"))?;
            Ok(())
        } else {
            Err("Not connected to PM3".to_string())
        }
    }

    /// Obtain a new receiver for live process output lines.
    pub fn output_rx(&self) -> broadcast::Receiver<String> {
        self.output_tx.subscribe()
    }

    /// Obtain a receiver that tracks [`Pm3State`] changes.
    pub fn state_rx(&self) -> watch::Receiver<Pm3State> {
        self.state_tx.subscribe()
    }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn is_connection_output(line: &str) -> bool {
    let lower = line.to_lowercase();
    line.contains("pm3 -->")
        || line.contains("os:")
        || line.contains("[usb]")
        || line.contains("[bt]")
        || lower.contains("communicating with pm3")
        || lower.contains("connected to")
}

/// Build the platform-specific command, arguments, and environment for
/// launching the PM3 client.
///
/// Returns `(executable, args, env_vars)`.
#[cfg(target_os = "windows")]
fn build_command(pm3_dir: &Path, port: &str) -> (String, Vec<String>, Vec<(String, String)>) {
    let bash = pm3_dir.join("libs").join("shell").join("bash.exe");

    // Prepend PM3 libs dirs to PATH.
    let existing_path = std::env::var("PATH").unwrap_or_default();
    let new_path = format!(
        "{};{};{existing_path}",
        pm3_dir.join("libs").display(),
        pm3_dir.join("libs").join("shell").display(),
    );

    let pm3_dir_str = pm3_dir.display().to_string();
    // Use Windows user profile as HOME (not PM3 dir) to avoid Cygwin path issues
    let home_dir = std::env::var("USERPROFILE").unwrap_or_else(|_| pm3_dir_str.clone());

    // Ensure libs/platforms/ exists for Qt platform plugin (qwindows.dll)
    let platforms_dir = pm3_dir.join("libs").join("platforms");
    if !platforms_dir.exists() {
        let _ = std::fs::create_dir_all(&platforms_dir);
        let qwindows_src = pm3_dir.join("libs").join("qwindows.dll");
        if qwindows_src.exists() {
            let _ = std::fs::copy(&qwindows_src, platforms_dir.join("qwindows.dll"));
        }
    }

    let envs = vec![
        ("HOME".into(), home_dir),
        ("MSYSTEM".into(), "MINGW64".into()),
        ("PATH".into(), new_path),
        (
            "QT_PLUGIN_PATH".into(),
            pm3_dir.join("libs").display().to_string(),
        ),
        (
            "QT_QPA_PLATFORM_PLUGIN_PATH".into(),
            platforms_dir.display().to_string(),
        ),
    ];

    // Use relative path "pm3" with working directory set to pm3_dir.
    // This avoids Cygwin/MSYS2 path translation issues.
    let args = vec![
        "pm3".into(),
        "-p".into(),
        port.into(),
        "-f".into(),
    ];

    (bash.display().to_string(), args, envs)
}

#[cfg(not(target_os = "windows"))]
fn build_command(pm3_dir: &Path, port: &str) -> (String, Vec<String>, Vec<(String, String)>) {
    let pm3 = pm3_dir.join("pm3");
    let args = vec!["-p".into(), port.into(), "-f".into()];
    (pm3.display().to_string(), args, vec![])
}
