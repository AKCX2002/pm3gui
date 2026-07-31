use std::ffi::OsString;
use std::path::PathBuf;
use std::process::Stdio;
use std::sync::Arc;

use tokio::process::{Child, ChildStderr, ChildStdin, ChildStdout, Command};

use super::error::Pm3Error;
use super::validation::ValidatedClient;
use super::windows_job::WindowsProcessJob;

#[derive(Debug, Clone)]
pub struct LaunchSpec {
    pub program: PathBuf,
    pub args: Vec<OsString>,
    pub current_dir: PathBuf,
    pub env: Vec<(OsString, OsString)>,
}

pub fn build_launch_spec(client: &ValidatedClient, port: &str) -> LaunchSpec {
    let existing_path = std::env::var_os("PATH").unwrap_or_default();
    let libs = client.root.join("libs");
    let shell = libs.join("shell");
    let mut path = OsString::from(libs.as_os_str());
    path.push(";");
    path.push(shell.as_os_str());
    path.push(";");
    path.push(existing_path);
    LaunchSpec {
        program: client.bash.clone(),
        args: vec!["pm3".into(), "-p".into(), port.into(), "-f".into()],
        current_dir: client.root.clone(),
        env: vec![
            ("PATH".into(), path),
            ("MSYSTEM".into(), "MINGW64".into()),
            (
                "HOME".into(),
                std::env::var_os("USERPROFILE").unwrap_or_else(|| client.root.as_os_str().into()),
            ),
            (
                "QT_PLUGIN_PATH".into(),
                client.root.join("libs").as_os_str().into(),
            ),
            (
                "QT_QPA_PLATFORM_PLUGIN_PATH".into(),
                client
                    .root
                    .join("libs")
                    .join("platforms")
                    .as_os_str()
                    .into(),
            ),
        ],
    }
}

pub struct ManagedProcess {
    pub child: Child,
    pub stdin: ChildStdin,
    pub stdout: ChildStdout,
    pub stderr: ChildStderr,
    pub job: Arc<WindowsProcessJob>,
}

pub fn launch(spec: &LaunchSpec) -> Result<ManagedProcess, Pm3Error> {
    let mut command = Command::new(&spec.program);
    command
        .args(&spec.args)
        .current_dir(&spec.current_dir)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped());
    for (key, value) in &spec.env {
        command.env(key, value);
    }
    let mut child = command.spawn().map_err(|error| Pm3Error::LaunchFailed {
        detail: error.to_string(),
    })?;
    let pid = child.id().ok_or_else(|| Pm3Error::LaunchFailed {
        detail: "启动后无法取得 PID".into(),
    })?;
    let job = Arc::new(WindowsProcessJob::create()?);
    if let Err(error) = job.assign_pid(pid) {
        let _ = child.start_kill();
        return Err(error);
    }
    let stdin = child.stdin.take().ok_or_else(|| Pm3Error::LaunchFailed {
        detail: "无法取得 stdin".into(),
    })?;
    let stdout = child.stdout.take().ok_or_else(|| Pm3Error::LaunchFailed {
        detail: "无法取得 stdout".into(),
    })?;
    let stderr = child.stderr.take().ok_or_else(|| Pm3Error::LaunchFailed {
        detail: "无法取得 stderr".into(),
    })?;
    Ok(ManagedProcess {
        child,
        stdin,
        stdout,
        stderr,
        job,
    })
}
