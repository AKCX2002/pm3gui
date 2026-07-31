# PM3GUI Windows 稳定客户端设计规格

**状态：** 已确认

**目标版本：** 1.0.0

**目标平台：** Windows 10 21H2+、Windows 11

**PM3 Client 来源：** 用户选择已有目录
**会话模型：** 单窗口、单设备、单活动会话

---

## 1. 目标

把现有 Tauri 2 + Vue 3 原型重构为可长期使用的 Windows PM3 客户端。稳定版必须保证：

- 连接状态只有一个权威来源；
- PM3 进程启动、握手、退出和异常恢复可预测；
- 页面切换和高频输出不会导致日志通道永久失效；
- 图形化写卡操作经过类型校验和风险确认；
- 应用退出后不残留 `bash.exe` 或 PM3 子进程；
- 自动化测试与真实硬件测试具有清晰边界；
- 便携包不捆绑用户 PM3 Client、密钥、Dump 或本机配置。

## 2. 稳定版范围

### 2.1 包含

- PM3 Client 目录选择、只读验证和兼容性探测；
- 串口扫描；
- 单设备连接、断开、异常退出和重新连接；
- 原始 PM3 终端；
- HF/LF 结构化常用操作；
- Dump 只读查看与双文件对比；
- 主题、终端字号、默认目录等设置；
- 内存日志和用户主动触发的脱敏诊断导出；
- Windows 便携版构建。

### 2.2 不包含

- macOS、Linux；
- 多设备并发、多窗口会话；
- 固件刷写；
- PM3 Client 或固件自动更新；
- 将第三方 PM3 Client 打入 PM3GUI；
- 麦田品牌算法、康拓变种或其他逆向算法集成；
- Data、Trace、NFC、Script 占位页面；
- Dump 编辑和覆盖保存；
- 云同步、遥测、自动上传日志。

## 3. 核心原则

1. **Rust 是会话状态唯一来源。** Vue 只能显示 Rust 状态的投影，不得自行推断连接成功。
2. **单会话串行化。** connect、send、interrupt、disconnect 不能并发修改进程。
3. **会话代次隔离。** 每次连接生成新的 `SessionId`；旧线程事件不能影响新会话。
4. **按字节读取输出。** 不假设 PM3 提示符以换行结尾。
5. **原始终端和图形操作分离。** 原始终端保留高级能力，图形操作必须类型化。
6. **默认只读和最小权限。** 仅在用户明确操作时读取文件或执行高风险命令。
7. **假进程测试不替代硬件验证。** 自动化只证明软件状态机，不证明真实 PM3/固件组合。

## 4. 总体架构

```text
Vue 页面
  ├─ pm3Client：类型化 Tauri IPC
  ├─ sessionStore：会话、输出、当前操作
  └─ settingsStore：目录、主题、终端配置
          │
          ▼
Tauri Commands
  ├─ session commands
  ├─ raw terminal command
  └─ structured operation command
          │
          ▼
Pm3SessionManager
  ├─ DirectoryValidator
  ├─ ProcessLauncher
  ├─ WindowsProcessJob
  ├─ OutputReader
  ├─ OutputRingBuffer
  ├─ OperationValidator
  └─ SessionMonitor
```

## 5. Rust 组件

### 5.1 `Pm3SessionManager`

唯一会话所有者，负责：

- 串行执行会话动作；
- 保存当前 `SessionSnapshot`；
- 分配 `SessionId` 和事件序号；
- 启动、握手和停止 PM3；
- 拒绝与当前状态不兼容的命令；
- 丢弃旧会话的迟到事件；
- 将状态和输出发送给 Tauri 事件桥。

### 5.2 `DirectoryValidator`

只读验证：

- 目录存在且可规范化；
- Windows 启动器 `libs/shell/bash.exe` 存在；
- `pm3` 脚本存在；
- 必需的客户端资源目录存在；
- 串口名称满足 Windows COM 端口格式并仍在扫描结果中。

不得创建 `libs/platforms`、复制 DLL 或修改用户 Client 目录。

### 5.3 `ProcessLauncher`

- 使用参数数组启动进程，不拼接 shell 命令行；
- 设置当前工作目录和必需环境变量；
- 捕获 stdin、stdout、stderr；
- stdout/stderr 均以字节块读取；
- 创建后立即加入 Windows Job Object；
- 返回可等待、可中断、可终止的进程句柄。

### 5.4 `WindowsProcessJob`

- 管理 Bash 及其后代进程；
- 正常断开时先请求 PM3 退出；
- 超时后终止完整 Job；
- Tauri 退出和 Rust Drop 路径执行兜底清理；
- 清理操作必须幂等。

### 5.5 `OutputRingBuffer`

- 同时限制最大条目数和最大字节数；
- 保存 stdout/stderr 来源、会话号、序号和时间戳；
- 溢出时丢弃最旧条目并累计 `droppedCount`；
- 溢出不能关闭输出转发；
- 前端重新挂载时可以请求近期快照。

### 5.6 `OperationValidator`

把类型化操作转换为 PM3 CLI 命令：

- 校验枚举、块号、密钥和数据长度；
- 只接受文件选择器产生的路径；
- 标注 `ReadOnly`、`Dangerous`、`Critical` 风险等级；
- 后端再次验证高风险操作已携带确认令牌；
- 原始终端命令不经过此转换器。

## 6. 会话状态机

```text
Disconnected
    │ connect
    ▼
Validating
    ▼
Starting
    ▼
Handshaking
    ▼
Connected
    │ disconnect / exit
    ▼
Stopping
    ▼
Disconnected
```

任一执行阶段均可进入 `Failed`。失败状态包含错误类别、用户消息、诊断详情和可否重试。清理完成后允许重新连接，但 `lastError` 保留到下次连接或用户清除。

状态定义：

```rust
pub enum SessionState {
    Disconnected,
    Validating,
    Starting,
    Handshaking,
    Connected,
    Stopping,
    Failed,
}
```

事件信封：

```rust
pub struct EventEnvelope<T> {
    pub session_id: Option<u64>,
    pub sequence: u64,
    pub payload: T,
}
```

前端仅接受：

- 无会话的全局事件；
- `sessionId` 等于当前会话的事件；
- `sequence` 大于同类事件最后序号的事件。

## 7. 握手与兼容性

连接流程：

1. 验证目录和串口；
2. 创建新 `SessionId`；
3. 启动进程并接管管道；
4. 在限定时间内检测 PM3 提示符或已知连接文本；
5. 执行轻量版本探测；
6. 保存 Client 和固件版本；
7. 进入 `Connected`。

未识别版本：

- 允许用户进入原始终端；
- 图形操作显示兼容性警告；
- 不把“进程启动成功”等同于“设备已连接”。

## 8. 命令模型

### 8.1 原始终端

- 接受任意 PM3 CLI 文本；
- 明确显示“高级模式”提示；
- 只在当前会话保存历史；
- 不把命令历史写入设置或诊断包；
- 仍受连接状态和单命令队列约束。

### 8.2 图形操作

前端发送结构化请求：

```rust
pub enum OperationRequest {
    SearchHf,
    SearchLf,
    ReadMifareBlock {
        block: u16,
        key_type: KeyType,
        key: HexKey,
    },
    WriteMifareBlock {
        block: u16,
        key_type: KeyType,
        key: HexKey,
        data: HexData,
    },
    RestoreMifare {
        size: CardSize,
        file: SelectedFile,
    },
    WipeT55xx,
    SimulateHid {
        card_id: String,
    },
}
```

风险策略：

- 搜索、读取、查看信息：`ReadOnly`；
- 写块、恢复、擦除、模拟：`Dangerous`；
- 块 0、UID、访问控制位：`Critical`；
- `Dangerous` 和 `Critical` 必须由 UI 展示参数摘要并获取确认；
- 后端使用一次性确认令牌防止绕过 UI。

## 9. Vue 组件

### 9.1 `pm3Client`

- 封装所有 Tauri `invoke` 和 `listen`；
- 提供明确的 TypeScript 参数和返回类型；
- 页面不得直接使用字符串 command 名称；
- 将 Tauri 异常转换为统一 `ClientError`。

### 9.2 `sessionStore`

- 应用启动时初始化一次；
- 首先订阅事件，再获取快照，避免订阅窗口丢事件；
- 保存当前状态、版本、输出 ring、丢弃数和当前操作；
- 页面销毁不停止全局监听；
- 应用退出时释放监听。

### 9.3 `settingsStore`

- 保存主题、终端字号、默认目录、缓冲上限和自动扫描设置；
- 使用带版本号的 schema；
- 解析失败时回退默认值并显示非阻塞警告；
- 设置必须实际驱动连接页和终端。

### 9.4 页面

- 连接页：只提交配置并显示后端状态；
- 终端页：使用共享输出和原始命令接口；
- HF/LF 页：提交类型化操作；
- Dump 页：只读、虚拟滚动、Worker 对比；
- Settings 页：编辑统一设置；
- Data、Trace、NFC、Script 从稳定版导航移除。

## 10. 错误模型

```rust
pub enum ErrorKind {
    InvalidClientDirectory,
    PortUnavailable,
    LaunchFailed,
    HandshakeTimeout,
    DeviceDisconnected,
    ProcessExited,
    Io,
    InvalidOperation,
    ConfirmationRequired,
    Busy,
    Cancelled,
}
```

错误包含：

- 稳定错误码；
- 面向用户的简短中文消息；
- 不含秘密的诊断详情；
- 可否重试；
- 可选退出码。

环境变量、完整用户目录、密钥和原始历史命令不能进入默认日志。

## 11. Tauri 权限

- 启用 CSP；
- 移除未使用的前端 Shell 插件；
- 默认移除文件写入和建目录权限；
- 文件读取限制为用户通过对话框选择的路径；
- 诊断导出单独请求保存权限；
- Rust 后端继续负责 PM3 进程，不把任意进程执行能力暴露给 WebView。

## 12. 测试策略

### 12.1 自动化

- Rust 单元测试：状态、验证器、操作构造、缓冲区；
- Rust 集成测试：假进程输出、超时、退出、积压和重连；
- Vue 测试：IPC、store、确认对话框、终端重挂载；
- 构建测试：TypeScript、Clippy、Cargo test、便携脚本。

### 12.2 Windows 冒烟

- Windows 10、Windows 11；
- 普通、空格、中文路径；
- 连接、断开、重连；
- 握手中和命令中关闭应用；
- 退出后无残留进程。

### 12.3 真实硬件

- 连续连接/断开 100 次；
- 设备拔出和重新连接；
- `hw version`、HF/LF 搜索等只读命令；
- 高频和长时间输出；
- 使用专用测试卡验证一次写块、恢复和擦除。

## 13. 稳定版发布门禁

- `npm run build`、前端测试、Rust 测试、Fmt、Clippy 全部通过；
- Windows 10/11 冒烟通过；
- 真实硬件测试有记录；
- 100 次连接循环无状态错误或残留进程；
- 输出积压后仍可继续接收；
- 高风险操作无法绕过确认；
- 便携包不含 PM3 Client、密钥、Dump、历史或本机绝对路径；
- README 明确支持范围、兼容性、风险和排错流程。

## 14. 交付顺序

1. 工程与发布基线；
2. Rust 领域类型和状态机；
3. 输出读取和有界缓冲；
4. Windows 进程生命周期；
5. Tauri 事件和类型化 IPC；
6. Vue 全局会话 store；
7. 终端；
8. HF/LF 安全操作；
9. 设置、Dump 和权限；
10. Windows/硬件验收；
11. 1.0.0 发布。
