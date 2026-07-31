# PM3GUI Windows 稳定客户端实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法跟踪进度。

**目标：** 将现有 PM3GUI Tauri 原型重构为 Windows 10/11 上可稳定连接、操作和安全退出的单会话 PM3 客户端。

**架构：** Rust `Pm3SessionManager` 是进程和状态唯一来源，按会话代次串行管理外部 PM3 Client。Vue 通过类型化 IPC 和全局 store 接收状态与有界输出；原始终端和受控图形操作使用不同接口。

**技术栈：** Rust 2021、Tauri 2、Tokio、Windows Job Object、Vue 3、TypeScript、Pinia、Vitest、xterm.js。

**设计规格：** `docs/superpowers/specs/2026-07-31-pm3gui-stable-windows-client-design.md`

---

## 全局约束

- 仅支持 Windows 10 21H2+ 和 Windows 11。
- 用户选择已有 PM3 Client 目录；不得捆绑或修改其中的文件。
- 仅支持单窗口、单设备、单活动会话。
- 原始终端允许任意 PM3 命令；HF/LF 图形操作必须类型化和校验。
- 写块、恢复、擦除、模拟必须确认；块 0、UID、访问位使用更高风险级别。
- 自动化假进程测试不能替代真实硬件验收。
- 不集成麦田/康拓逆向算法、固件刷写、自动更新、多设备或非 Windows 平台。
- 每个任务通过测试后再进入下一任务。

## 目标文件结构

```text
pm3gui-tauri/
├── docs/
│   ├── compatibility.md
│   ├── diagnostics.md
│   └── release-checklist.md
├── scripts/
│   ├── package-portable.ps1
│   └── smoke-portable.ps1
├── src/
│   ├── api/pm3Client.ts
│   ├── components/terminal/Pm3Terminal.vue
│   ├── components/operations/OperationConfirmDialog.vue
│   ├── stores/session.ts
│   ├── stores/settings.ts
│   ├── types/pm3.ts
│   └── workers/dumpCompare.worker.ts
└── src-tauri/src/
    ├── commands/
    │   ├── operation.rs
    │   ├── session.rs
    │   └── terminal.rs
    └── pm3/
        ├── error.rs
        ├── launcher.rs
        ├── mod.rs
        ├── operation.rs
        ├── output.rs
        ├── session.rs
        ├── types.rs
        ├── validation.rs
        └── windows_job.rs
```

---

### 任务 1：建立可审计的工程基线

**文件：**
- 修改：`.gitignore`
- 修改：`package.json`
- 修改：`src-tauri/Cargo.toml`
- 修改：`src-tauri/.cargo/config.toml`
- 删除：`.cargo/config.toml`
- 修改：`package-portable.bat`
- 创建：`scripts/package-portable.ps1`

- [ ] **步骤 1：记录现状但不改动用户文件**

运行：

```powershell
git status --short
git diff --cached --stat
git diff --stat
```

预期：确认仓库尚无提交，并保存当前 staged、modified、untracked 清单到任务日志；不得使用 `git reset --hard` 或 `git checkout --`。

- [ ] **步骤 2：补充构建产物忽略规则**

在 `.gitignore` 增加：

```gitignore
portable/*.exe
src-tauri/gen/
src-tauri/target/
dist/
coverage/
*.pdb
```

- [ ] **步骤 3：移除机器绑定 linker 配置**

删除项目根 `.cargo/config.toml` 中的绝对 Visual Studio 路径。保留 `src-tauri/.cargo/config.toml`：

```toml
[target.x86_64-pc-windows-msvc]
linker = "rust-lld.exe"
```

- [ ] **步骤 4：增加前端测试命令**

在 `package.json` 增加：

```json
{
  "scripts": {
    "test": "vitest run",
    "test:watch": "vitest",
    "check": "vue-tsc --noEmit && vitest run && vite build"
  },
  "devDependencies": {
    "@vue/test-utils": "^2.4.6",
    "jsdom": "^26.1.0",
    "vitest": "^3.2.4"
  }
}
```

随后运行：

```powershell
npm install
npm run build
```

预期：安装成功，现有生产构建仍通过。

- [ ] **步骤 5：收紧 Rust 依赖**

从 `Cargo.toml` 删除当前未使用的 `regex`；把仅供测试使用的 `serde_json` 放入开发依赖，并把 Tokio 从 `full` 改为实际需要的特性：

```toml
tokio = { version = "1", features = ["process", "io-util", "sync", "time", "rt-multi-thread", "macros"] }
windows = { version = "0.61", features = [
  "Win32_Foundation",
  "Win32_System_JobObjects",
  "Win32_System_Threading"
] }
thiserror = "2"

[dev-dependencies]
serde_json = "1"
tempfile = "3"
```

- [ ] **步骤 6：替换便携打包入口**

`package-portable.bat` 只调用 PowerShell，并正确传递失败码：

```bat
@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\package-portable.ps1"
exit /b %ERRORLEVEL%
```

`scripts/package-portable.ps1` 必须：

- 检查 release EXE 存在；
- 清理旧输出；
- 复制 EXE；
- 生成引号完整的启动脚本；
- 生成 README；
- 任何步骤失败时退出非零。

- [ ] **步骤 7：运行基线质量检查**

```powershell
npm run build
cargo fmt --check --manifest-path src-tauri/Cargo.toml
cargo clippy --manifest-path src-tauri/Cargo.toml --all-targets -- -D warnings
cargo test --manifest-path src-tauri/Cargo.toml
```

预期：前端构建通过；先记录 Clippy 现有失败，随后修复模块文档和 `Default` 告警，使全部命令退出 `0`。

- [ ] **步骤 8：创建基线提交**

先检查：

```powershell
git status --short
git diff --cached --stat
```

确认没有 `portable/PM3GUI.exe`、`target/`、Dump、密钥或外部 PM3 Client 后提交：

```powershell
git add .gitignore README.md package.json package-lock.json index.html vite.config.ts tsconfig.json tsconfig.node.json src src-tauri scripts package-portable.bat docs
git commit -m "chore: establish PM3GUI source baseline"
```

---

### 任务 2：定义稳定的领域类型和错误协议

**文件：**
- 创建：`src-tauri/src/pm3/mod.rs`
- 创建：`src-tauri/src/pm3/types.rs`
- 创建：`src-tauri/src/pm3/error.rs`
- 修改：`src-tauri/src/lib.rs`

- [ ] **步骤 1：编写状态序列化失败测试**

在 `types.rs` 测试模块添加：

```rust
#[test]
fn session_snapshot_serializes_with_stable_tagged_state() {
    let snapshot = SessionSnapshot::disconnected();
    let value = serde_json::to_value(snapshot).unwrap();
    assert_eq!(value["state"], "disconnected");
    assert!(value["sessionId"].is_null());
}
```

- [ ] **步骤 2：运行测试确认失败**

```powershell
cargo test --manifest-path src-tauri/Cargo.toml session_snapshot_serializes
```

预期：`pm3::types` 或 `SessionSnapshot` 尚不存在而失败。

- [ ] **步骤 3：实现领域类型**

定义：

```rust
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub enum SessionState {
    Disconnected,
    Validating,
    Starting,
    Handshaking,
    Connected,
    Stopping,
    Failed,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SessionSnapshot {
    pub session_id: Option<u64>,
    pub state: SessionState,
    pub client_version: Option<String>,
    pub firmware_version: Option<String>,
    pub last_error: Option<Pm3Error>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct EventEnvelope<T> {
    pub session_id: Option<u64>,
    pub sequence: u64,
    pub payload: T,
}
```

- [ ] **步骤 4：实现稳定错误协议**

```rust
#[derive(Debug, Clone, Serialize, thiserror::Error)]
#[serde(rename_all = "camelCase")]
pub enum Pm3Error {
    #[error("PM3 Client 目录无效")]
    InvalidClientDirectory { detail: String },
    #[error("串口当前不可用")]
    PortUnavailable { port: String },
    #[error("PM3 进程启动失败")]
    LaunchFailed { detail: String },
    #[error("PM3 握手超时")]
    HandshakeTimeout,
    #[error("设备连接已断开")]
    DeviceDisconnected,
    #[error("PM3 进程异常退出")]
    ProcessExited { code: Option<i32> },
    #[error("当前会话正忙")]
    Busy,
    #[error("操作参数无效")]
    InvalidOperation { field: String, detail: String },
    #[error("该操作需要确认")]
    ConfirmationRequired,
    #[error("操作已取消")]
    Cancelled,
    #[error("PM3 输入输出失败")]
    Io { detail: String },
}
```

- [ ] **步骤 5：验证 JSON 契约**

增加错误序列化和 camelCase 字段测试，运行：

```powershell
cargo test --manifest-path src-tauri/Cargo.toml pm3::types
cargo test --manifest-path src-tauri/Cargo.toml pm3::error
```

预期：全部通过。

- [ ] **步骤 6：Commit**

```powershell
git add src-tauri/src/pm3 src-tauri/src/lib.rs src-tauri/Cargo.toml src-tauri/Cargo.lock
git commit -m "feat(core): define PM3 session and error contracts"
```

---

### 任务 3：实现 PM3 Client 目录与串口验证

**文件：**
- 创建：`src-tauri/src/pm3/validation.rs`
- 测试：`src-tauri/src/pm3/validation.rs`
- 修改：`src-tauri/src/services/serial_mgr.rs`

- [ ] **步骤 1：编写目录验证测试**

使用 `tempfile` 开发依赖，覆盖：

```rust
#[test]
fn rejects_directory_without_windows_launcher() {
    let root = tempfile::tempdir().unwrap();
    let error = validate_client_dir(root.path()).unwrap_err();
    assert!(matches!(error, Pm3Error::InvalidClientDirectory { .. }));
}

#[test]
fn accepts_directory_with_required_read_only_layout() {
    let root = tempfile::tempdir().unwrap();
    create_file(root.path().join("pm3"));
    create_file(root.path().join("libs/shell/bash.exe"));
    assert!(validate_client_dir(root.path()).is_ok());
}
```

- [ ] **步骤 2：验证测试失败**

```powershell
cargo test --manifest-path src-tauri/Cargo.toml validation
```

预期：`validate_client_dir` 不存在。

- [ ] **步骤 3：实现只读验证**

返回规范化结构：

```rust
pub struct ValidatedClient {
    pub root: PathBuf,
    pub bash: PathBuf,
    pub script: PathBuf,
}

pub fn validate_client_dir(path: &Path) -> Result<ValidatedClient, Pm3Error>;
pub fn validate_port(requested: &str, available: &[PortInfo]) -> Result<(), Pm3Error>;
```

实现不得调用 `create_dir_all`、`copy` 或修改文件。

- [ ] **步骤 4：补充 COM 端口验证测试**

覆盖：

- `COM3` 存在时通过；
- `COM3` 不在当前扫描结果时返回 `PortUnavailable`；
- 空字符串和非 Windows 端口名被拒绝。

- [ ] **步骤 5：让串口扫描返回错误而不是空数组**

将：

```rust
pub fn list_ports() -> Vec<PortInfo>
```

改为：

```rust
pub fn list_ports() -> Result<Vec<PortInfo>, Pm3Error>
```

禁止继续使用 `unwrap_or_default()` 隐藏扫描失败。

- [ ] **步骤 6：运行测试**

```powershell
cargo test --manifest-path src-tauri/Cargo.toml validation
cargo clippy --manifest-path src-tauri/Cargo.toml --all-targets -- -D warnings
```

预期：通过且验证代码无写目录副作用。

- [ ] **步骤 7：Commit**

```powershell
git add src-tauri/src/pm3/validation.rs src-tauri/src/services/serial_mgr.rs src-tauri/Cargo.toml src-tauri/Cargo.lock
git commit -m "feat(core): validate PM3 client directories and ports"
```

---

### 任务 4：实现字节流输出和有界缓冲

**文件：**
- 创建：`src-tauri/src/pm3/output.rs`
- 测试：`src-tauri/src/pm3/output.rs`

- [ ] **步骤 1：编写提示符分片测试**

```rust
#[test]
fn detects_prompt_split_across_chunks_without_newline() {
    let mut decoder = OutputDecoder::new();
    assert!(!decoder.push(StreamKind::Stdout, b"pm3 -").prompt_seen);
    assert!(decoder.push(StreamKind::Stdout, b"-> ").prompt_seen);
}
```

- [ ] **步骤 2：编写缓冲溢出测试**

```rust
#[test]
fn ring_buffer_drops_oldest_and_keeps_accepting_output() {
    let mut ring = OutputRingBuffer::new(2, 128);
    ring.push(entry(1, "one"));
    ring.push(entry(2, "two"));
    ring.push(entry(3, "three"));
    assert_eq!(ring.snapshot().iter().map(|x| x.sequence).collect::<Vec<_>>(), vec![2, 3]);
    assert_eq!(ring.dropped_count(), 1);
}
```

- [ ] **步骤 3：运行测试确认失败**

```powershell
cargo test --manifest-path src-tauri/Cargo.toml output
```

预期：类型尚不存在。

- [ ] **步骤 4：实现输出类型**

```rust
#[derive(Debug, Clone, Copy, Serialize)]
#[serde(rename_all = "camelCase")]
pub enum StreamKind {
    Stdout,
    Stderr,
    System,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct OutputEntry {
    pub session_id: u64,
    pub sequence: u64,
    pub stream: StreamKind,
    pub text: String,
}
```

`OutputDecoder` 使用增量 UTF-8 解码，保留不完整字符；提示符检测跨 chunk 工作。无效字节用替换字符显示并记录诊断，不能终止读取线程。

- [ ] **步骤 5：实现双上限 ring buffer**

```rust
pub struct OutputRingBuffer {
    entries: VecDeque<OutputEntry>,
    bytes: usize,
    max_entries: usize,
    max_bytes: usize,
    dropped_count: u64,
}
```

每次 push 后循环移除最旧条目，直到两个限制均满足。

- [ ] **步骤 6：运行测试**

```powershell
cargo test --manifest-path src-tauri/Cargo.toml output
```

预期：分片提示符、无换行、无效 UTF-8 和溢出测试全部通过。

- [ ] **步骤 7：Commit**

```powershell
git add src-tauri/src/pm3/output.rs src-tauri/src/pm3/mod.rs
git commit -m "feat(core): add chunked PM3 output decoding and bounded history"
```

---

### 任务 5：实现 Windows 进程启动与 Job Object 清理

**文件：**
- 创建：`src-tauri/src/pm3/launcher.rs`
- 创建：`src-tauri/src/pm3/windows_job.rs`
- 测试：`src-tauri/src/pm3/launcher.rs`

- [ ] **步骤 1：编写启动规范测试**

```rust
#[test]
fn launch_spec_uses_argument_vector_not_shell_concatenation() {
    let client = fixture_client(r"C:\PM3 Client");
    let spec = build_launch_spec(&client, "COM3");
    assert_eq!(spec.program, client.bash);
    assert_eq!(spec.args, vec!["pm3", "-p", "COM3", "-f"]);
}
```

- [ ] **步骤 2：验证测试失败**

```powershell
cargo test --manifest-path src-tauri/Cargo.toml launch_spec
```

预期：启动规范尚不存在。

- [ ] **步骤 3：实现无副作用启动规范**

```rust
pub struct LaunchSpec {
    pub program: PathBuf,
    pub args: Vec<OsString>,
    pub current_dir: PathBuf,
    pub env: Vec<(OsString, OsString)>,
}
```

PATH、HOME 和 Qt 环境只写入子进程环境，不修改系统环境。

- [ ] **步骤 4：实现 Windows Job Object**

`WindowsProcessJob` 必须：

- 创建 Job Object；
- 设置 `JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE`；
- 将 Bash 进程句柄加入 Job；
- 提供幂等 `terminate()`；
- Drop 时关闭 Job 句柄。

公开接口：

```rust
pub struct WindowsProcessJob { /* private handles */ }

impl WindowsProcessJob {
    pub fn create() -> Result<Self, Pm3Error>;
    pub fn assign(&self, child: &std::process::Child) -> Result<(), Pm3Error>;
    pub fn terminate(&self, exit_code: u32) -> Result<(), Pm3Error>;
}
```

- [ ] **步骤 5：实现托管进程**

```rust
pub struct ManagedProcess {
    pub child: tokio::process::Child,
    pub stdin: ChildStdin,
    pub stdout: ChildStdout,
    pub stderr: ChildStderr,
    job: WindowsProcessJob,
}
```

启动失败必须返回 `LaunchFailed`，不能遗留 `Starting` 状态。

- [ ] **步骤 6：增加原生 Windows 子进程测试**

使用测试专用 `powershell.exe -NoProfile -Command` 模拟：

- 输出无换行提示符；
- 延迟退出；
- 创建子进程后由 Job 统一终止。

测试必须带超时，失败时主动清理。

- [ ] **步骤 7：运行测试**

```powershell
cargo test --manifest-path src-tauri/Cargo.toml launcher -- --nocapture
cargo test --manifest-path src-tauri/Cargo.toml windows_job -- --nocapture
```

预期：测试进程及其后代全部退出，无残留 PowerShell 子进程。

- [ ] **步骤 8：Commit**

```powershell
git add src-tauri/src/pm3/launcher.rs src-tauri/src/pm3/windows_job.rs src-tauri/src/pm3/mod.rs src-tauri/Cargo.toml src-tauri/Cargo.lock
git commit -m "feat(core): manage PM3 processes with Windows job objects"
```

---

### 任务 6：实现单会话状态机

**文件：**
- 创建：`src-tauri/src/pm3/session.rs`
- 测试：`src-tauri/src/pm3/session.rs`
- 删除：`src-tauri/src/services/pm3_process.rs`
- 修改：`src-tauri/src/services/mod.rs`

- [ ] **步骤 1：编写会话状态测试**

至少覆盖：

```rust
#[tokio::test]
async fn launch_failure_transitions_to_failed_and_allows_retry();

#[tokio::test]
async fn natural_process_exit_updates_snapshot();

#[tokio::test]
async fn stale_session_events_do_not_mutate_current_session();

#[tokio::test]
async fn concurrent_connect_is_rejected_as_busy();

#[tokio::test]
async fn disconnect_is_idempotent();
```

- [ ] **步骤 2：运行测试确认失败**

```powershell
cargo test --manifest-path src-tauri/Cargo.toml session
```

预期：`Pm3SessionManager` 不存在。

- [ ] **步骤 3：定义会话动作和事件**

```rust
enum SessionAction {
    Connect(ConnectRequest),
    SendRaw(String),
    Execute(OperationRequest),
    Interrupt,
    Disconnect,
    Shutdown,
}

pub enum SessionEvent {
    State(EventEnvelope<SessionSnapshot>),
    Output(EventEnvelope<OutputEntry>),
    Operation(EventEnvelope<OperationEvent>),
}
```

- [ ] **步骤 4：实现 manager actor**

```rust
pub struct Pm3SessionManager {
    action_tx: mpsc::Sender<SessionAction>,
    snapshot_rx: watch::Receiver<SessionSnapshot>,
    event_tx: broadcast::Sender<SessionEvent>,
}
```

所有可变生命周期状态只存在于单 actor task 中。不得继续使用分离的 `Mutex<Option<Child>>` 和 `Mutex<Option<ChildStdin>>`。

- [ ] **步骤 5：实现连接和握手**

- 进入 `Validating`；
- 验证目录、串口；
- 分配新 `SessionId`；
- 进入 `Starting`；
- 启动进程和读任务；
- 进入 `Handshaking`；
- 在配置超时内等待提示符；
- 发送轻量版本探测；
- 成功后进入 `Connected`。

超时和退出均先记录失败，再执行清理。

- [ ] **步骤 6：实现断开和关闭**

- 拒绝新命令；
- 进入 `Stopping`；
- 尝试发送正常退出命令；
- 等待有限时间；
- 超时终止 Job；
- 回收 stdout/stderr tasks；
- 进入 `Disconnected`。

`Shutdown` 必须复用相同清理逻辑。

- [ ] **步骤 7：替换旧服务**

删除旧 `Pm3Service`，`AppState` 改为：

```rust
pub struct AppState {
    pub pm3: Pm3SessionManager,
}
```

- [ ] **步骤 8：运行状态机测试**

```powershell
cargo test --manifest-path src-tauri/Cargo.toml session -- --nocapture
cargo clippy --manifest-path src-tauri/Cargo.toml --all-targets -- -D warnings
```

预期：所有竞态、失败、退出和幂等测试通过。

- [ ] **步骤 9：Commit**

```powershell
git add src-tauri/src/pm3 src-tauri/src/services src-tauri/src/lib.rs
git commit -m "refactor(core): replace PM3 service with a single-session manager"
```

---

### 任务 7：建立类型化 Tauri 命令和事件桥

**文件：**
- 创建：`src-tauri/src/commands/session.rs`
- 创建：`src-tauri/src/commands/operation.rs`
- 修改：`src-tauri/src/commands/terminal.rs`
- 修改：`src-tauri/src/commands/mod.rs`
- 修改：`src-tauri/src/lib.rs`
- 删除：`src-tauri/src/commands/connection.rs`
- 删除：`src-tauri/src/commands_def.rs`

- [ ] **步骤 1：定义命令签名**

```rust
#[tauri::command]
pub async fn get_session_snapshot(state: State<'_, AppState>)
    -> Result<SessionSnapshot, Pm3Error>;

#[tauri::command]
pub async fn connect_pm3(state: State<'_, AppState>, request: ConnectRequest)
    -> Result<(), Pm3Error>;

#[tauri::command]
pub async fn disconnect_pm3(state: State<'_, AppState>)
    -> Result<(), Pm3Error>;

#[tauri::command]
pub async fn send_raw_command(state: State<'_, AppState>, command: String)
    -> Result<(), Pm3Error>;

#[tauri::command]
pub async fn prepare_operation(state: State<'_, AppState>, request: OperationRequest)
    -> Result<PreparedOperation, Pm3Error>;

#[tauri::command]
pub async fn execute_operation(state: State<'_, AppState>, request: ConfirmedOperation)
    -> Result<OperationId, Pm3Error>;

#[tauri::command]
pub async fn get_recent_output(state: State<'_, AppState>)
    -> Result<OutputSnapshot, Pm3Error>;
```

- [ ] **步骤 2：实现事件桥**

Tauri 事件名固定为：

```text
pm3://state
pm3://output
pm3://operation
```

对 `broadcast::RecvError::Lagged(n)`：

- 发出 system output 说明丢弃数量；
- 继续接收；
- 只有 channel closed 才结束桥接 task。

- [ ] **步骤 3：处理应用退出**

在 Tauri RunEvent/窗口退出路径调用：

```rust
state.pm3.shutdown().await
```

若异步退出回调受限，发送 `Shutdown` 并使用有界等待，最终依赖 Job Object Drop 兜底。

- [ ] **步骤 4：删除双重命令定义**

删除 `commands_def.rs`。命令字符串只能由 `pm3/operation.rs` 构造。

- [ ] **步骤 5：增加 command 层测试**

command 测试必须验证：

- 错误类型原样序列化；
- command 不维护第二份状态；
- raw 和 structured 路径调用不同 manager action。

- [ ] **步骤 6：运行后端检查**

```powershell
cargo fmt --check --manifest-path src-tauri/Cargo.toml
cargo clippy --manifest-path src-tauri/Cargo.toml --all-targets -- -D warnings
cargo test --manifest-path src-tauri/Cargo.toml
```

预期：全部退出 `0`。

- [ ] **步骤 7：Commit**

```powershell
git add src-tauri/src
git commit -m "feat(ipc): expose typed PM3 session commands and events"
```

---

### 任务 8：建立前端 IPC 类型和全局会话 Store

**文件：**
- 创建：`src/types/pm3.ts`
- 创建：`src/api/pm3Client.ts`
- 创建：`src/api/pm3Client.test.ts`
- 创建：`src/stores/session.ts`
- 创建：`src/stores/session.test.ts`
- 修改：`src/App.vue`
- 删除：`src/stores/connection.ts`
- 删除：`src/stores/terminal.ts`

- [ ] **步骤 1：定义与 Rust 一致的 TypeScript 类型**

```typescript
export type SessionState =
  | "disconnected"
  | "validating"
  | "starting"
  | "handshaking"
  | "connected"
  | "stopping"
  | "failed";

export interface EventEnvelope<T> {
  sessionId: number | null;
  sequence: number;
  payload: T;
}

export interface SessionSnapshot {
  sessionId: number | null;
  state: SessionState;
  clientVersion: string | null;
  firmwareVersion: string | null;
  lastError: Pm3Error | null;
}
```

- [ ] **步骤 2：编写 IPC 映射测试**

Mock `@tauri-apps/api/core` 和事件 API，验证：

- `connect()` 调用 `connect_pm3`；
- `sendRaw()` 调用 `send_raw_command`；
- 页面不需要知道字符串 command 名；
- Tauri rejection 转换成 `ClientError`。

- [ ] **步骤 3：实现 `pm3Client`**

公开接口：

```typescript
export interface Pm3Client {
  snapshot(): Promise<SessionSnapshot>;
  recentOutput(): Promise<OutputSnapshot>;
  connect(request: ConnectRequest): Promise<void>;
  disconnect(): Promise<void>;
  sendRaw(command: string): Promise<void>;
  prepare(request: OperationRequest): Promise<PreparedOperation>;
  execute(request: ConfirmedOperation): Promise<number>;
  onState(handler: (event: EventEnvelope<SessionSnapshot>) => void): Promise<UnlistenFn>;
  onOutput(handler: (event: EventEnvelope<OutputEntry>) => void): Promise<UnlistenFn>;
  onOperation(handler: (event: EventEnvelope<OperationEvent>) => void): Promise<UnlistenFn>;
}
```

- [ ] **步骤 4：编写 Store 竞态测试**

覆盖：

```typescript
it("subscribes before fetching the initial snapshot");
it("ignores events from an older session");
it("ignores duplicate or decreasing sequence numbers");
it("retains output while the terminal page is unmounted");
it("releases listeners exactly once");
```

- [ ] **步骤 5：实现全局 Store**

初始化顺序：

1. 注册三个事件监听；
2. 获取 snapshot；
3. 获取 recent output；
4. 合并期间收到的新事件；
5. 标记 initialized。

- [ ] **步骤 6：在 App 生命周期初始化**

`App.vue` 在根组件挂载时调用 `sessionStore.initialize()`，卸载时调用 `dispose()`。具体页面不得重复注册全局 PM3 监听。

- [ ] **步骤 7：运行前端测试**

```powershell
npm run test -- src/api/pm3Client.test.ts src/stores/session.test.ts
npm run build
```

预期：测试和 TypeScript 构建通过。

- [ ] **步骤 8：Commit**

```powershell
git add src
git commit -m "refactor(frontend): centralize PM3 IPC and session state"
```

---

### 任务 9：重构连接页和终端

**文件：**
- 修改：`src/pages/ConnectionPage.vue`
- 创建：`src/pages/ConnectionPage.test.ts`
- 创建：`src/components/terminal/Pm3Terminal.vue`
- 创建：`src/components/terminal/Pm3Terminal.test.ts`
- 修改：`src/pages/TerminalPage.vue`
- 删除：`src/views/TerminalView.vue`
- 删除：`src/views/HomeView.vue`
- 修改：`package.json`

- [ ] **步骤 1：连接页改用后端状态**

按钮状态映射：

```typescript
const canConnect = computed(() => session.state === "disconnected" || session.state === "failed");
const canDisconnect = computed(() => ["starting", "handshaking", "connected"].includes(session.state));
```

页面不再在 `connect()` 前手动设置 `"Connecting"`。

- [ ] **步骤 2：增加连接页测试**

覆盖：

- `validating/starting/handshaking` 显示对应状态；
- `connected` 显示版本信息；
- `failed` 展示错误和重试按钮；
- 串口扫描失败不是空列表；
- 连接中禁止重复连接。

- [ ] **步骤 3：统一 xterm 依赖**

保留：

```json
"@xterm/xterm": "^5.5.0",
"@xterm/addon-fit": "^0.10.0",
"@xterm/addon-web-links": "^0.11.0"
```

删除旧 `xterm` 和 `xterm-addon-fit`。

- [ ] **步骤 4：实现唯一终端组件**

`Pm3Terminal.vue`：

- 从 session store 渲染 output snapshot；
- 记录最后显示序号，避免重复；
- 保存 xterm input disposable；
- 保存并 disconnect `ResizeObserver`；
- 组件销毁时 dispose terminal；
- 原始命令发送失败时显示 system output；
- 未连接时禁止发送。

- [ ] **步骤 5：增加终端测试**

验证：

- 重新挂载后显示 ring snapshot；
- 新事件只追加一次；
- 销毁时清理 observer 和 input disposable；
- 命令历史只在当前会话内；
- 密钥形态命令不会写入 localStorage。

- [ ] **步骤 6：运行检查**

```powershell
npm run test -- src/pages/ConnectionPage.test.ts src/components/terminal/Pm3Terminal.test.ts
npm run build
```

预期：测试通过，生产包中只存在一套 xterm。

- [ ] **步骤 7：Commit**

```powershell
git add package.json package-lock.json src
git commit -m "refactor(ui): rebuild connection and terminal around session state"
```

---

### 任务 10：实现结构化 HF/LF 操作与风险确认

**文件：**
- 创建：`src-tauri/src/pm3/operation.rs`
- 创建：`src-tauri/src/commands/operation.rs`
- 创建：`src/types/operations.ts`
- 创建：`src/components/operations/OperationConfirmDialog.vue`
- 创建：`src/components/operations/OperationConfirmDialog.test.ts`
- 修改：`src/components/ProtocolPanel.vue`
- 修改：`src/config/protocols.ts`
- 修改：`src/pages/HfPage.vue`
- 修改：`src/pages/LfPage.vue`

- [ ] **步骤 1：编写 Rust 参数拒绝测试**

至少覆盖：

```rust
#[test]
fn rejects_mifare_key_with_wrong_length();

#[test]
fn rejects_write_data_with_wrong_length();

#[test]
fn classifies_block_zero_write_as_critical();

#[test]
fn rejects_dangerous_operation_without_confirmation();

#[test]
fn confirmation_token_is_single_use_and_bound_to_operation();
```

- [ ] **步骤 2：定义结构化操作**

实现设计规格中的 `OperationRequest`、`RiskLevel`、`OperationId`、`PreparedOperation` 和 `ConfirmedOperation`。`HexKey` 和 `HexData` 构造时完成规范化和长度验证。

准备流程固定为：

```rust
pub struct PreparedOperation {
    pub operation_id: OperationId,
    pub risk: RiskLevel,
    pub summary: OperationSummary,
    pub confirmation_token: Option<String>,
    pub expires_at_ms: u64,
}

pub struct ConfirmedOperation {
    pub operation_id: OperationId,
    pub confirmation_token: Option<String>,
}
```

`prepare_operation` 校验并缓存不可变操作；Dangerous/Critical 返回与操作 ID 绑定的短期一次性 token。`execute_operation` 只能执行已准备且未过期的操作，执行后立即销毁缓存和 token。ReadOnly 操作的 token 为 `None`。

- [ ] **步骤 3：实现唯一命令构造器**

接口：

```rust
pub fn validate_operation(request: OperationRequest) -> Result<ValidatedOperation, Pm3Error>;
pub fn render_command(operation: &ValidatedOperation) -> String;
```

`render_command` 只接受已经验证的类型，不接受任意 `Record<string, string>`。

- [ ] **步骤 4：移除前端命令字符串**

`protocols.ts` 只保留表单描述和操作类型：

```typescript
export interface OperationDefinition {
  id: string;
  label: string;
  kind: OperationKind;
  risk: RiskLevel;
  params: ParamDefinition[];
}
```

不得再包含：

```typescript
cmd: string | ((params) => string)
```

- [ ] **步骤 5：实现风险确认对话框**

对话框必须显示：

- 操作名称；
- 目标协议；
- 块号或文件名；
- 风险说明；
- Critical 操作要求输入明确确认文本。

取消时不请求后端确认令牌。

- [ ] **步骤 6：增加前端测试**

覆盖：

- ReadOnly 操作直接执行；
- Dangerous 操作必须确认；
- Critical 操作确认文本不匹配时禁用按钮；
- 参数校验失败时不调用 IPC；
- 双击只产生一个 operation。

- [ ] **步骤 7：运行完整操作测试**

```powershell
cargo test --manifest-path src-tauri/Cargo.toml operation
npm run test -- src/components/operations/OperationConfirmDialog.test.ts
npm run build
```

预期：全部通过。

- [ ] **步骤 8：Commit**

```powershell
git add src-tauri/src src
git commit -m "feat(operations): add validated and confirmed HF/LF actions"
```

---

### 任务 11：接通设置并优化 Dump

**文件：**
- 创建：`src/stores/settings.ts`
- 创建：`src/stores/settings.test.ts`
- 创建：`src/workers/dumpCompare.worker.ts`
- 创建：`src/workers/dumpCompare.worker.test.ts`
- 修改：`src/pages/SettingsPage.vue`
- 修改：`src/pages/ConnectionPage.vue`
- 修改：`src/components/terminal/Pm3Terminal.vue`
- 修改：`src/pages/DumpPage.vue`

- [ ] **步骤 1：定义版本化设置**

```typescript
export interface SettingsV1 {
  version: 1;
  darkMode: boolean;
  pm3ClientDir: string;
  terminalFontSize: number;
  outputMaxEntries: number;
  autoScanPorts: boolean;
}
```

解析函数必须验证类型和范围，不能直接信任 `JSON.parse` 结果。

- [ ] **步骤 2：编写设置测试**

覆盖：

- 缺失设置使用默认值；
- 无效 JSON 回退并返回警告；
- 字号限制在 10–24；
- 保存后连接页和终端读取同一 store；
- 旧未知版本不会静默覆盖。

- [ ] **步骤 3：接通现有设置 UI**

删除 `SettingsPage.vue` 内部独立 refs。保存操作更新 `settingsStore`，默认目录立即反映到连接页，字号立即更新 xterm options。

- [ ] **步骤 4：修复 Dump 视图模式**

- `hex` 显示虚拟化十六进制行；
- `raw` 显示受控文本预览，不渲染无限内容；
- 显示文件大小和格式；
- 文件读取错误有 UI 提示。

- [ ] **步骤 5：把对比移入 Worker**

Worker 返回：

```typescript
export interface DumpDiffSummary {
  leftSize: number;
  rightSize: number;
  differingBytes: number;
  ranges: Array<{ start: number; end: number }>;
}
```

不得把两个完整 hex 字符串同时保存在 DOM。

- [ ] **步骤 6：增加大文件测试**

使用合成 4 MiB 数据验证：

- diff 结果正确；
- 主线程不生成逐字节 Vue 节点；
- 原始预览有长度上限；
- 文件保持只读。

- [ ] **步骤 7：运行前端测试**

```powershell
npm run test -- src/stores/settings.test.ts src/workers/dumpCompare.worker.test.ts
npm run build
```

预期：全部通过。

- [ ] **步骤 8：Commit**

```powershell
git add src
git commit -m "feat(ui): connect settings and optimize read-only dump tools"
```

---

### 任务 12：收敛导航、CSP 和 Tauri 权限

**文件：**
- 修改：`src/components/AppSidebar.vue`
- 修改：`src/router/index.ts`
- 删除：`src/pages/DataPage.vue`
- 删除：`src/pages/TracePage.vue`
- 删除：`src/pages/NfcPage.vue`
- 删除：`src/pages/ScriptPage.vue`
- 修改：`src-tauri/tauri.conf.json`
- 修改：`src-tauri/capabilities/default.json`
- 修改：`src-tauri/src/lib.rs`
- 修改：`src-tauri/Cargo.toml`
- 修改：`package.json`

- [ ] **步骤 1：移除稳定版占位路由**

删除 Data、Trace、NFC、Script 菜单和路由。保留连接、终端、HF、LF、Dump、设置。

- [ ] **步骤 2：删除未使用 Shell 插件**

删除 Rust 和 npm 的 Tauri Shell plugin 依赖，并从 `lib.rs` 删除初始化。

- [ ] **步骤 3：收紧能力**

`src-tauri/capabilities/default.json` 的权限列表固定为：

```json
[
  "core:default",
  "dialog:allow-open",
  "dialog:allow-save",
  "fs:allow-read-file",
  "fs:allow-write-file"
]
```

读写命令仍受文件选择器动态 scope 限制；不得配置 `$HOME/**`、`C:\\**` 等全盘 scope。

移除通用 `fs:allow-write`、`fs:allow-mkdir` 和未使用的 ask/confirm 权限。

- [ ] **步骤 4：启用 CSP**

在 `tauri.conf.json` 配置：

```json
"csp": "default-src 'self' customprotocol: asset:; connect-src ipc: http://ipc.localhost; img-src 'self' asset: http://asset.localhost data:; style-src 'self' 'unsafe-inline'; font-src 'self' data:;",
"devCsp": "default-src 'self' http://localhost:1420; connect-src ipc: http://ipc.localhost http://localhost:1420 ws://localhost:1420; img-src 'self' asset: http://asset.localhost data:; style-src 'self' 'unsafe-inline'; font-src 'self' data:;"
```

不得保留 `"csp": null`，不得增加远程脚本来源或 `script-src 'unsafe-eval'`。

- [ ] **步骤 5：验证权限不破坏功能**

手工检查：

- 选择 PM3 Client 目录；
- 打开 Dump；
- 导出诊断；
- 前端不能调用任意 shell command；
- 未选择路径不能读取文件。

- [ ] **步骤 6：运行构建**

```powershell
npm run check
cargo clippy --manifest-path src-tauri/Cargo.toml --all-targets -- -D warnings
cargo test --manifest-path src-tauri/Cargo.toml
npm run tauri build
```

预期：全部通过。

- [ ] **步骤 7：Commit**

```powershell
git add src src-tauri package.json package-lock.json
git commit -m "security: reduce PM3GUI navigation and Tauri capabilities"
```

---

### 任务 13：实现脱敏诊断和兼容性记录

**文件：**
- 创建：`src-tauri/src/diagnostics.rs`
- 创建：`src-tauri/src/commands/diagnostics.rs`
- 创建：`src-tauri/tests/diagnostics.rs`
- 创建：`docs/compatibility.md`
- 创建：`docs/diagnostics.md`
- 修改：`src/pages/SettingsPage.vue`

- [ ] **步骤 1：定义诊断结构**

诊断包只包含：

```rust
pub struct DiagnosticReport {
    pub gui_version: String,
    pub windows_version: String,
    pub client_version: Option<String>,
    pub firmware_version: Option<String>,
    pub state_transitions: Vec<RedactedStateEvent>,
    pub recent_system_errors: Vec<RedactedError>,
    pub output_dropped_count: u64,
}
```

不包含 raw command history、Dump 内容、密钥、完整环境变量或完整用户目录。

- [ ] **步骤 2：编写脱敏测试**

输入含：

- `C:\Users\Alice\...`；
- 12 位十六进制密钥；
- COM 端口；
- PM3 原始命令。

断言导出结果：

- 用户名路径被替换；
- 密钥形态被替换；
- 原始命令不存在；
- 串口按设计保留或哈希，不暴露额外标识。

- [ ] **步骤 3：实现显式导出**

只有用户点击“导出诊断”并选择目标文件后写入 JSON。默认运行期间只保存在内存。

- [ ] **步骤 4：创建兼容性文档**

表格字段固定为：

```text
GUI 版本 | Windows | PM3 Client 版本 | 固件版本 | 设备 | 结果 | 日期
```

未实际验证的组合不得标记为支持。

- [ ] **步骤 5：运行测试**

```powershell
cargo test --manifest-path src-tauri/Cargo.toml diagnostics
npm run build
```

预期：脱敏测试和构建通过。

- [ ] **步骤 6：Commit**

```powershell
git add src-tauri/src src/pages/SettingsPage.vue docs
git commit -m "feat(diagnostics): add explicit redacted support reports"
```

---

### 任务 14：自动化 Windows 便携包冒烟测试

**文件：**
- 修改：`scripts/package-portable.ps1`
- 创建：`scripts/smoke-portable.ps1`
- 修改：`portable/README.txt`
- 修改：`README.md`

- [ ] **步骤 1：让打包过程可重复**

脚本必须：

- 从干净 `portable/` 目录开始；
- 验证 EXE 哈希和非零大小；
- 生成正确启动脚本；
- 不复制外部 PM3 Client；
- 不复制本地设置、日志或 Dump；
- 输出清单和 SHA-256。

- [ ] **步骤 2：编写静态冒烟检查**

`smoke-portable.ps1` 检查：

```powershell
$required = @("PM3GUI.exe", "启动PM3GUI.bat", "README.txt")
$forbidden = @("proxmark3.exe", "settings.json", "*.dump", "*.key")
```

任何缺失或禁用文件命中时退出非零。

- [ ] **步骤 3：增加进程退出检查**

测试启动应用、关闭应用，并确认本次测试启动的进程树已经退出。不得按名称杀死用户已有的无关 PM3 进程；必须按 PID/Job 归属检查。

- [ ] **步骤 4：更新使用说明**

README 包含：

- Windows 支持范围；
- 外部 Client 目录要求；
- 连接步骤；
- 高风险操作说明；
- 兼容性链接；
- 诊断导出；
- 卸载和便携数据位置。

- [ ] **步骤 5：运行打包检查**

```powershell
npm run tauri build
powershell -NoProfile -File scripts/package-portable.ps1
powershell -NoProfile -File scripts/smoke-portable.ps1
```

预期：全部退出 `0`，输出文件清单和 SHA-256。

- [ ] **步骤 6：Commit**

```powershell
git add scripts package-portable.bat portable/README.txt README.md
git commit -m "build: add reproducible portable packaging and smoke checks"
```

---

### 任务 15：执行真实 Windows 与 PM3 硬件验收

**文件：**
- 创建：`docs/release-checklist.md`
- 修改：`docs/compatibility.md`
- 创建：`docs/test-results/1.0.0-rc1.md`

- [ ] **步骤 1：运行全套自动化门禁**

```powershell
npm ci
npm run check
cargo fmt --check --manifest-path src-tauri/Cargo.toml
cargo clippy --manifest-path src-tauri/Cargo.toml --all-targets -- -D warnings
cargo test --manifest-path src-tauri/Cargo.toml
npm run tauri build
powershell -NoProfile -File scripts/package-portable.ps1
powershell -NoProfile -File scripts/smoke-portable.ps1
git diff --check
```

预期：全部退出 `0`。

- [ ] **步骤 2：Windows 10 冒烟**

记录：

- OS build；
- GUI build/hash；
- Client/固件版本；
- 普通、空格、中文目录；
- 启动、连接、只读命令、断开、退出；
- 残留进程检查。

- [ ] **步骤 3：Windows 11 冒烟**

重复完全相同矩阵，不得用 Windows 10 结果替代。

- [ ] **步骤 4：执行 100 次连接循环**

每次循环记录：

- 状态是否按顺序变化；
- 是否出现超时；
- 是否残留进程；
- 是否出现旧会话输出；
- 是否可以继续下一次连接。

任何一次失败都阻止稳定版发布。

- [ ] **步骤 5：执行设备异常测试**

覆盖：

- 握手中拔出；
- 已连接时拔出；
- 命令中拔出；
- 重新插入和重新连接；
- 应用在握手、连接、命令运行时退出。

- [ ] **步骤 6：执行真实操作**

先执行：

- `hw version`；
- HF search；
- LF search；
- 其他只读信息命令。

随后只使用专用可损耗测试卡执行：

- 写普通数据块；
- 恢复；
- 擦除；
- Critical 操作确认。

不得使用生产卡或唯一数据样本。

- [ ] **步骤 7：记录兼容性**

只把完成真实验证的组合写入 `docs/compatibility.md`。失败组合记录失败症状和限制，不标为支持。

- [ ] **步骤 8：创建 RC 验收提交**

```powershell
git add docs/release-checklist.md docs/compatibility.md docs/test-results/1.0.0-rc1.md
git commit -m "test: record PM3GUI 1.0.0 release candidate validation"
```

---

### 任务 16：发布 1.0.0

**文件：**
- 修改：`package.json`
- 修改：`package-lock.json`
- 修改：`src-tauri/Cargo.toml`
- 修改：`src-tauri/Cargo.lock`
- 修改：`src-tauri/tauri.conf.json`
- 修改：`README.md`
- 创建：`CHANGELOG.md`

- [ ] **步骤 1：统一版本号**

将 npm、Cargo 和 Tauri 版本统一为 `1.0.0`。运行：

```powershell
rg -n '"version": "0\.1\.0"|version = "0\.1\.0"' package.json package-lock.json src-tauri/Cargo.toml src-tauri/Cargo.lock src-tauri/tauri.conf.json
```

预期：升级后不再有应用自身的 `0.1.0`。

- [ ] **步骤 2：编写 Changelog**

`CHANGELOG.md` 必须列出：

- Windows 单会话核心；
- 外部 Client 模型；
- 连接和进程清理；
- 原始终端；
- 类型化 HF/LF 操作；
- Dump 和设置；
- 已知限制；
- 已验证兼容性组合。

- [ ] **步骤 3：最终门禁**

重新执行任务 15 步骤 1 的全部命令。

预期：全部退出 `0`，工作区仅包含预期版本和文档修改。

- [ ] **步骤 4：生成最终便携包**

```powershell
powershell -NoProfile -File scripts/package-portable.ps1
Get-FileHash portable/PM3GUI.exe -Algorithm SHA256
```

将 SHA-256 和兼容性矩阵写入发布说明。

- [ ] **步骤 5：提交版本**

```powershell
git add package.json package-lock.json src-tauri/Cargo.toml src-tauri/Cargo.lock src-tauri/tauri.conf.json README.md CHANGELOG.md
git commit -m "release: PM3GUI 1.0.0"
```

- [ ] **步骤 6：创建标签**

仅在最终 commit 和产物哈希均确认后：

```powershell
git tag -a v1.0.0 -m "PM3GUI 1.0.0"
```

---

## 规格覆盖自检

- Windows 10/11：任务 5、14、15。
- 外部 PM3 Client：任务 3、5、14。
- 单会话：任务 6。
- 状态唯一来源：任务 6、7、8、9。
- 无换行和高频输出：任务 4、6、15。
- 完整进程树清理：任务 5、6、14、15。
- 原始终端：任务 7、9。
- 结构化 HF/LF：任务 10。
- 风险确认：任务 10、15。
- 设置和 Dump：任务 11。
- 占位功能移除：任务 12。
- 权限和 CSP：任务 12。
- 诊断脱敏：任务 13。
- 便携包：任务 14。
- 真实硬件门禁：任务 15。
- 1.0.0 发布：任务 16。

## 类型一致性自检

- Rust 和 TypeScript 均使用 `SessionState`、`SessionSnapshot`、`EventEnvelope`。
- 会话事件统一携带 `sessionId` 和 `sequence`。
- 原始命令只经过 `send_raw_command`。
- 图形操作只经过 `execute_operation` 和 `OperationRequest`。
- `OutputEntry` 同时记录 session、sequence 和 stream。
- 风险等级统一为 `ReadOnly`、`Dangerous`、`Critical`。

## 执行交接

计划已完整拆分为 16 个可验证任务。执行时应从任务 1 开始，按顺序推进；在任务 6 的会话核心通过全部状态机测试前，不增加新的协议功能。
