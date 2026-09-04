# PM3 GUI

<div align="center">
  <img src="https://img.shields.io/badge/Flutter-3.27+-02569B?logo=flutter&logoColor=white" alt="Flutter"/>
  <img src="https://img.shields.io/badge/Dart-3.6+-0175C2?logo=dart&logoColor=white" alt="Dart"/>
  <img src="https://img.shields.io/badge/Platforms-Windows%20x64%20%7C%20Linux%20x64-2ea44f" alt="Platforms"/>
  <img src="https://img.shields.io/badge/License-GPL--3.0-blue" alt="License"/>
  <img src="https://img.shields.io/badge/Status-Alpha-red" alt="Status"/>
</div>

PM3 GUI 是面向 Proxmark3 的桌面图形客户端，提供常用 RFID/NFC 操作、转储文件管理和命令终端。

> ⚠️ **Alpha 说明**：当前版本仍在迭代，页面和行为可能调整。

## 平台与范围

- Windows x64 是 1.0 主平台。
- Linux x64 是 1.0 正式支持平台。
- Android、iOS、Web 和 macOS 不属于 1.0 范围。
- 本项目不打包 Proxmark3 固件或客户端；设备通信使用用户安装的官方 Proxmark3 client（`pm3` 或 `proxmark3`）。

CI 工作流包含 Windows 和 Linux x64 桌面路径。当前开发验证在 Windows 上进行，因此不能据此宣称 Linux 构建或真实 PM3 硬件已经验证。

## 核心能力

- 通过 `Pm3Backend` 契约和 `DesktopCliBackend` 驱动官方 Proxmark3 client。
- 终端支持完整命令透传、历史记录和输出查看。
- 专用 GUI 优先覆盖高频工作流；低频、诊断及新增命令保留在 Terminal。
- 支持 EML、BIN/DUMP、JSON 和密钥文件的查看、分析与导出。
- 连接、命令输出和进程退出具备可诊断的本地生命周期管理。

```text
Flutter UI / Feature
        │
        ▼
  Pm3Controller → Pm3Backend → DesktopCliBackend
                                      │
                                      ▼
                                  Pm3Process
                                      │
                                      ▼
                         official proxmark3 client
```

`Pm3Process` 是 `DesktopCliBackend` 的内部适配器，Widget 和 Feature 不直接使用 `dart:io Process`。

## 配置与隐私

连接页负责选择并持久化串口/设备端口；设置页管理客户端可执行文件路径、启动参数和可选工作目录。相关设置会自动保存到：

```text
<应用支持目录>/pm3_settings.json
```

应用支持目录由 `path_provider` 的 `getApplicationSupportDirectory()` 按当前操作系统和用户账户决定。它不是项目目录，实际绝对路径请以系统配置为准。

每次成功连接会在同一应用支持目录下创建本地 Session：

```text
<应用支持目录>/sessions/YYYY-MM-DD_HHmmss_SSS/
├─ session.json       # 端口、客户端路径、开始/结束时间
├─ terminal.log       # 客户端输出
└─ commands.jsonl     # 发出的命令（每行一条 JSON）
```

这些文件仅写入本机，不会由 PM3 GUI 上传。终端输出和命令参数可能包含 UID、设备信息或其他敏感数据，请保护应用支持目录，并在共享日志前自行检查内容。

## 安装与运行

### 环境要求

- Flutter 3.27+
- Dart 3.6+
- 官方 Proxmark3 client：`pm3` 或 `proxmark3`

### 运行

```bash
git clone https://github.com/AKCX2002/pm3gui.git
cd pm3gui
flutter pub get
flutter run -d windows
```

Linux x64 可使用 `flutter run -d linux`。请先按 Flutter 官方文档安装对应桌面工具链。

### 构建

```bash
flutter build windows
flutter build linux
```

## 文件格式

| 类型 | 扩展名 | 读取 | 导出 |
|---|---|---:|---:|
| EML 转储 | `.eml` | ✅ | ✅ |
| 二进制转储 | `.bin`、`.dump` | ✅ | ✅ |
| JSON 转储 | `.json` | ✅ | ✅ |
| 密钥字典 | `.dic` | ✅ | ✅ |
| 密钥文本 | `.keys.txt` | - | ✅ |

## 仓库结构

```text
lib/core/pm3/       # Pm3Backend 契约、命令、事件、结果和 Session 模型
lib/backend/         # DesktopCliBackend、Pm3Process 和 Mock Backend
lib/services/        # 设置、Session、文件和命令服务
lib/state/           # Provider 状态管理
lib/ui/              # 桌面页面和组件
docs/                # 命令映射、规格和架构路线
.github/workflows/   # Windows/Linux CI 与发布路径
```

## 开发与验证

提交前可运行：

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub
flutter build windows --debug --no-pub
```

上述命令覆盖 Windows 上的格式、静态分析、Dart/Flutter 测试和 Windows debug 构建；不覆盖 Linux runner 构建，也不替代真实 PM3 硬件验收。CI 的 Linux x64 构建路径以 `.github/workflows/build.yml` 为准。

## 后续路线

下一阶段将建立 **Command Registry** 和 **Parser Registry**，统一命令元数据、参数及输出解析。专用 GUI 继续优先覆盖高频工作流，低频或新增命令继续通过 Terminal 使用。

## 许可证

本项目使用 **GPL-3.0** 许可证，详见 [LICENSE](./LICENSE)。
