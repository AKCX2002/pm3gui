use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Mutex};
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use tokio::io::{AsyncRead, AsyncReadExt, AsyncWriteExt};
use tokio::sync::{broadcast, watch, Mutex as AsyncMutex};

use super::error::Pm3Error;
use super::launcher::{launch, ManagedProcess};
use super::operation::{
    prepare_operation, ConfirmedOperation, OperationEvent, OperationRequest, PreparedCommand,
    PreparedOperation, RiskLevel,
};
use super::output::{OutputDecoder, OutputEntry, OutputRingBuffer, OutputSnapshot, StreamKind};
use super::types::{ConnectRequest, SessionSnapshot, SessionState};
use super::validation::{validate_client_dir, validate_port};
use super::windows_job::WindowsProcessJob;
use crate::services::serial_mgr;

const HANDSHAKE_TIMEOUT: Duration = Duration::from_secs(12);
const CONFIRMATION_TTL: Duration = Duration::from_secs(60);

#[derive(Debug, Clone)]
struct PendingOperation {
    command: PreparedCommand,
    token: Option<String>,
    expires_at_ms: u64,
}

pub struct SessionManager {
    snapshot: Mutex<SessionSnapshot>,
    stdin: AsyncMutex<Option<tokio::process::ChildStdin>>,
    connect_gate: AsyncMutex<()>,
    job: Mutex<Option<Arc<WindowsProcessJob>>>,
    output: Mutex<OutputRingBuffer>,
    pending: Mutex<HashMap<u64, PendingOperation>>,
    next_session: AtomicU64,
    next_sequence: AtomicU64,
    next_operation: AtomicU64,
    output_tx: broadcast::Sender<OutputEntry>,
    state_tx: watch::Sender<SessionSnapshot>,
    operation_tx: broadcast::Sender<OperationEvent>,
}

impl SessionManager {
    pub fn new() -> Self {
        let initial = SessionSnapshot::disconnected();
        let (output_tx, _) = broadcast::channel(2048);
        let (state_tx, _) = watch::channel(initial.clone());
        let (operation_tx, _) = broadcast::channel(128);
        Self {
            snapshot: Mutex::new(initial),
            stdin: AsyncMutex::new(None),
            connect_gate: AsyncMutex::new(()),
            job: Mutex::new(None),
            output: Mutex::new(OutputRingBuffer::new(5_000, 4 * 1024 * 1024)),
            pending: Mutex::new(HashMap::new()),
            next_session: AtomicU64::new(1),
            next_sequence: AtomicU64::new(1),
            next_operation: AtomicU64::new(1),
            output_tx,
            state_tx,
            operation_tx,
        }
    }

    pub fn snapshot(&self) -> SessionSnapshot {
        self.snapshot
            .lock()
            .expect("snapshot mutex poisoned")
            .clone()
    }

    pub fn output_snapshot(&self) -> OutputSnapshot {
        self.output
            .lock()
            .expect("output mutex poisoned")
            .snapshot()
    }

    pub fn output_rx(&self) -> broadcast::Receiver<OutputEntry> {
        self.output_tx.subscribe()
    }

    pub fn state_rx(&self) -> watch::Receiver<SessionSnapshot> {
        self.state_tx.subscribe()
    }

    pub fn operation_rx(&self) -> broadcast::Receiver<OperationEvent> {
        self.operation_tx.subscribe()
    }

    pub async fn connect(
        self: &Arc<Self>,
        request: ConnectRequest,
    ) -> Result<SessionSnapshot, Pm3Error> {
        let _connect_guard = self.connect_gate.try_lock().map_err(|_| Pm3Error::Busy)?;
        self.disconnect().await?;
        let session_id = self.next_session.fetch_add(1, Ordering::Relaxed);
        self.set_state(session_id, SessionState::Validating, None);

        let client =
            validate_client_dir(&PathBuf::from(&request.pm3_dir)).inspect_err(|error| {
                self.set_failed(session_id, error.clone());
            })?;
        let ports = serial_mgr::list_ports()?;
        validate_port(&request.port, &ports).inspect_err(|error| {
            self.set_failed(session_id, error.clone());
        })?;

        self.set_state(session_id, SessionState::Starting, None);
        let process = launch(&super::launcher::build_launch_spec(&client, &request.port))
            .inspect_err(|error| self.set_failed(session_id, error.clone()))?;
        self.set_state(session_id, SessionState::Handshaking, None);
        self.attach_process(session_id, process).await;

        let mut state_rx = self.state_rx();
        let wait = async {
            loop {
                let snapshot = state_rx.borrow().clone();
                if snapshot.session_id != Some(session_id) {
                    return Err(Pm3Error::Cancelled);
                }
                match snapshot.state {
                    SessionState::Connected => return Ok(snapshot),
                    SessionState::Failed => {
                        return Err(snapshot.last_error.unwrap_or(Pm3Error::DeviceDisconnected))
                    }
                    _ => {}
                }
                state_rx
                    .changed()
                    .await
                    .map_err(|_| Pm3Error::DeviceDisconnected)?;
            }
        };
        match tokio::time::timeout(HANDSHAKE_TIMEOUT, wait).await {
            Ok(result) => result,
            Err(_) => {
                let error = Pm3Error::HandshakeTimeout;
                self.set_failed(session_id, error.clone());
                let _ = self.disconnect_process().await;
                Err(error)
            }
        }
    }

    async fn attach_process(self: &Arc<Self>, session_id: u64, process: ManagedProcess) {
        let ManagedProcess {
            mut child,
            stdin,
            stdout,
            stderr,
            job,
        } = process;
        *self.stdin.lock().await = Some(stdin);
        *self.job.lock().expect("job mutex poisoned") = Some(job);

        let stdout_owner = Arc::clone(self);
        tokio::spawn(async move {
            stdout_owner
                .read_stream(session_id, StreamKind::Stdout, stdout)
                .await;
        });
        let stderr_owner = Arc::clone(self);
        tokio::spawn(async move {
            stderr_owner
                .read_stream(session_id, StreamKind::Stderr, stderr)
                .await;
        });
        let wait_owner = Arc::clone(self);
        tokio::spawn(async move {
            let status = child.wait().await;
            if wait_owner.is_current(session_id) {
                let error = match status {
                    Ok(status) => Pm3Error::ProcessExited {
                        exit_code: status.code(),
                    },
                    Err(error) => Pm3Error::Io {
                        detail: error.to_string(),
                    },
                };
                wait_owner.set_failed(session_id, error);
                *wait_owner.stdin.lock().await = None;
                wait_owner.job.lock().expect("job mutex poisoned").take();
            }
        });
    }

    async fn read_stream<R>(&self, session_id: u64, stream: StreamKind, mut reader: R)
    where
        R: AsyncRead + Unpin,
    {
        let mut decoder = OutputDecoder::new();
        let mut buffer = [0_u8; 4096];
        loop {
            match reader.read(&mut buffer).await {
                Ok(0) => break,
                Ok(count) => {
                    let decoded = decoder.push(&buffer[..count]);
                    self.publish_output(session_id, stream, decoded.text);
                    if decoded.prompt_seen && self.is_current(session_id) {
                        self.set_state(session_id, SessionState::Connected, None);
                    }
                }
                Err(error) => {
                    self.publish_output(
                        session_id,
                        StreamKind::System,
                        format!("读取输出失败：{error}"),
                    );
                    break;
                }
            }
        }
    }

    fn publish_output(&self, session_id: u64, stream: StreamKind, text: String) {
        if !self.is_current(session_id) {
            return;
        }
        let entry = OutputEntry {
            session_id,
            sequence: self.next_sequence.fetch_add(1, Ordering::Relaxed),
            stream,
            text,
        };
        self.output
            .lock()
            .expect("output mutex poisoned")
            .push(entry.clone());
        let _ = self.output_tx.send(entry);
    }

    pub async fn disconnect(&self) -> Result<SessionSnapshot, Pm3Error> {
        let current = self.snapshot();
        if let Some(session_id) = current.session_id {
            self.set_state(session_id, SessionState::Stopping, None);
        }
        self.disconnect_process().await?;
        self.pending.lock().expect("pending mutex poisoned").clear();
        self.replace_snapshot(SessionSnapshot::disconnected());
        Ok(self.snapshot())
    }

    async fn disconnect_process(&self) -> Result<(), Pm3Error> {
        self.stdin.lock().await.take();
        let job = self.job.lock().expect("job mutex poisoned").take();
        if let Some(job) = job {
            job.terminate(0)?;
        }
        Ok(())
    }

    pub async fn send_command(&self, command: &str) -> Result<(), Pm3Error> {
        let command = command.trim();
        if command.is_empty() || command.contains(['\r', '\n']) {
            return Err(Pm3Error::InvalidOperation {
                field: "command".into(),
                detail: "命令不能为空或包含换行".into(),
            });
        }
        if self.snapshot().state != SessionState::Connected {
            return Err(Pm3Error::DeviceDisconnected);
        }
        let mut guard = self.stdin.lock().await;
        let stdin = guard.as_mut().ok_or(Pm3Error::DeviceDisconnected)?;
        stdin
            .write_all(format!("{command}\n").as_bytes())
            .await
            .map_err(|error| Pm3Error::Io {
                detail: error.to_string(),
            })?;
        stdin.flush().await.map_err(|error| Pm3Error::Io {
            detail: error.to_string(),
        })
    }

    pub fn prepare_operation(
        &self,
        request: OperationRequest,
    ) -> Result<PreparedOperation, Pm3Error> {
        let command = prepare_operation(request)?;
        let operation_id = self.next_operation.fetch_add(1, Ordering::Relaxed);
        let expires_at_ms = now_ms().saturating_add(CONFIRMATION_TTL.as_millis() as u64);
        let token = (command.risk != RiskLevel::ReadOnly).then(|| uuid::Uuid::new_v4().to_string());
        self.pending.lock().expect("pending mutex poisoned").insert(
            operation_id,
            PendingOperation {
                command: command.clone(),
                token: token.clone(),
                expires_at_ms,
            },
        );
        Ok(PreparedOperation {
            operation_id,
            risk: command.risk,
            summary: command.summary,
            confirmation_token: token,
            expires_at_ms,
        })
    }

    pub async fn execute_operation(&self, confirmed: ConfirmedOperation) -> Result<(), Pm3Error> {
        let pending = self
            .pending
            .lock()
            .expect("pending mutex poisoned")
            .remove(&confirmed.operation_id)
            .ok_or(Pm3Error::Cancelled)?;
        if pending.expires_at_ms < now_ms() {
            return Err(Pm3Error::Cancelled);
        }
        if pending.token != confirmed.confirmation_token {
            return Err(Pm3Error::ConfirmationRequired);
        }
        let _ = self.operation_tx.send(OperationEvent {
            operation_id: confirmed.operation_id,
            status: "running".into(),
            summary: pending.command.summary.clone(),
        });
        let result = self.send_command(&pending.command.command).await;
        let _ = self.operation_tx.send(OperationEvent {
            operation_id: confirmed.operation_id,
            status: if result.is_ok() {
                "submitted"
            } else {
                "failed"
            }
            .into(),
            summary: pending.command.summary,
        });
        result
    }

    fn is_current(&self, session_id: u64) -> bool {
        self.snapshot().session_id == Some(session_id)
    }

    fn set_state(&self, session_id: u64, state: SessionState, error: Option<Pm3Error>) {
        if matches!(state, SessionState::Validating) || self.is_current(session_id) {
            self.replace_snapshot(SessionSnapshot {
                session_id: Some(session_id),
                state,
                client_version: None,
                firmware_version: None,
                last_error: error,
            });
        }
    }

    fn set_failed(&self, session_id: u64, error: Pm3Error) {
        self.set_state(session_id, SessionState::Failed, Some(error));
    }

    fn replace_snapshot(&self, snapshot: SessionSnapshot) {
        *self.snapshot.lock().expect("snapshot mutex poisoned") = snapshot.clone();
        let _ = self.state_tx.send(snapshot);
    }
}

impl Default for SessionManager {
    fn default() -> Self {
        Self::new()
    }
}

fn now_ms() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as u64
}
