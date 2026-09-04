# PM3 GUI 当前架构路线

本文档描述当前实现基线和后续路线。它不是对全部 Proxmark3 协议建立独立页面的承诺；功能优先级以可维护性、常用工作流和官方客户端兼容性为准。

## 平台与版本边界

- Windows x64 是 1.0 的主平台。
- Linux x64 是 1.0 的正式支持平台。
- Android、iOS、Web 和 macOS 不属于 1.0 的支持范围。
- PM3 GUI 不打包固件或客户端二进制文件。设备通信由用户安装的官方 Proxmark3 client（`pm3` 或 `proxmark3`）负责。
- 当前 Windows 工作站上的验证不等于 Linux 构建验证，也不等于真实 PM3 硬件验证；Linux 构建由 CI 配置覆盖，硬件验收需要相应环境。

## 当前架构

```text
Flutter UI / Feature
        │
        ▼
  Pm3Controller
        │
        ▼
    Pm3Backend
        │
        ▼
DesktopCliBackend
        │
        ▼
Pm3Process（内部进程适配器）
        │
        ▼
官方 Proxmark3 client
```

`Pm3Backend` 是桌面实现与上层状态/UI 之间的契约，`DesktopCliBackend` 负责把官方客户端进程映射为连接、事件和命令结果。`Pm3Process` 只在桌面 CLI 后端内部使用；`dart:io Process` 不向 Widget 或 Feature 泄漏。

### 客户端设置

设置页允许用户配置并持久化以下字段：

- 客户端可执行文件路径；
- 串口或设备端口；
- 客户端启动参数；
- 可选工作目录。

设置以 JSON 保存于应用支持目录中的 `pm3_settings.json`。具体根路径由 `path_provider` 的 `getApplicationSupportDirectory()` 决定，因此随操作系统和用户账户而异，不应写死为项目目录或某个固定绝对路径。

### 本地 Session

每次成功连接创建一个本地 Session 目录：

```text
<应用支持目录>/sessions/YYYY-MM-DD_HHmmss_SSS/
├─ session.json       # 端口、客户端路径、开始/结束时间
├─ terminal.log       # 客户端输出，按行追加
└─ commands.jsonl     # 发出的命令，每行一条 JSON
```

写入通过串行队列完成。断开连接或应用关闭时，后端先完成进程退出，再关闭 Session 并等待尾部写入，从而保留可诊断的本地记录。Session 不上传网络；终端输出可能包含 UID、设备信息或命令参数等敏感内容，用户应按本机安全要求保护应用支持目录。

### 进程生命周期

连接过程会处理客户端早退和启动失败；断开时先请求客户端优雅退出，在有限等待后才强制终止，并清理 stdout/stderr 订阅和进程引用。应用关闭等待后端、Session 写入队列和订阅按顺序释放。

## 功能覆盖策略

GUI 专用页面只覆盖高频、稳定且能从结构化交互中获益的工作流。低频协议、诊断命令和官方客户端新增命令继续通过 Terminal 页面执行，以保留完整命令能力，避免为每个协议维护重复页面和不完整的参数封装。

当前导航按通用功能、高频（HF）、低频（LF）和工具分组；已有页面和命令映射以 `lib/ui/pages/`、`lib/services/pm3_commands.dart` 及 `docs/pm3_commands*.{yaml,csv}` 为准。协议页面数量不是 1.0 的覆盖率指标。

## 下一阶段

下一阶段先建立两个可复用的注册表：

1. **Command Registry**：统一命令元数据、参数定义、能力标记和 UI 可用性。
2. **Parser Registry**：统一输出解析器、结构化结果和版本兼容策略。

注册表稳定后，再按真实使用频率扩展少量专用 GUI 页面；低频或暂未建模的命令继续保留在 Terminal。每项扩展都应保留官方客户端的透传能力，并补充相应测试和文档。

## 验证边界

在 Windows x64 工作站上执行 Dart 格式检查、Flutter 静态分析、完整 Flutter 测试和 Windows debug 构建，是桌面基础层的代码级验证。仓库的 CI 工作流还声明了 Linux x64 构建路径，但本机运行结果不能替代 Linux runner 的实际构建。没有连接真实 PM3 设备时，不报告硬件连接、固件交互或真实卡片操作已验证。
