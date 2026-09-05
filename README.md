# PM3 GUI

<div align="center">
  <a href="https://github.com/AKCX2002/Promark3-GUI/actions/workflows/build.yml"><img src="https://github.com/AKCX2002/Promark3-GUI/actions/workflows/build.yml/badge.svg" alt="Build"/></a>
  <a href="https://github.com/AKCX2002/Promark3-GUI/releases"><img src="https://img.shields.io/github/v/release/AKCX2002/Promark3-GUI?display_name=tag" alt="Release"/></a>
  <img src="https://img.shields.io/badge/Platforms-Windows%20x64%20%7C%20Linux%20x64-2ea44f" alt="Platforms"/>
  <a href="./LICENSE"><img src="https://img.shields.io/badge/License-GPL--3.0-blue" alt="License"/></a>
</div>

PM3 GUI 是面向 Proxmark3 的 GPL-3.0 开源桌面图形客户端，提供常用 RFID/NFC 操作、转储文件管理和命令终端。

> ⚠️ **Alpha 说明**：当前版本仍在迭代，页面和行为可能调整。

请仅对自有或已明确授权的设备、卡片和系统执行操作，并遵守所在地适用法律。

## 平台与范围

- Windows x64 是 1.0 主平台。
- Linux x64 是 1.0 正式支持平台。
- Android、iOS、Web 和 macOS 不属于 1.0 范围。
- 本项目不打包 Proxmark3 固件或客户端；设备通信使用用户安装的官方 Proxmark3 client。Windows 优先使用官方发行包根目录的 `pm3.bat`，Linux 使用 `proxmark3`。

CI 工作流包含 Windows 和 Linux x64 桌面路径。当前有限实机证据来自 Windows x64：使用用户提供、对应 RRG commit `da509461` 的发行包和 PM3EASY512K（客户端识别为 `PM3 GENERIC / AT91SAM7S512 / 512K`），已通过根目录 `pm3.bat` 完成客户端连接、只读 `hw version` 和断开。2026-09-05 补充通过 Mifare 页面“检测卡片”到真实客户端与设备的验证：一次点击发送一次命令，页面显示 ATQA/SAK；客户端报告可能类型为 MIFARE Classic 1K。另已验证 6 秒静默命令和超过 10 秒的搜索输出。该结果不能外推为 Linux、其他设备、写卡、擦除或完整固件交互已经验证。

## 下载与发布

- 已发布版本及 Windows/Linux x64 压缩包见 [GitHub Releases](https://github.com/AKCX2002/Promark3-GUI/releases)。
- `main` 分支提交和 Pull Request 会执行静态分析、测试及双平台 release 构建。
- 推送形如 `v0.0.4` 的标签后，同一工作流会打包两个平台并创建带自动发行说明的 GitHub Release。
- Release 仅包含 PM3 GUI；Proxmark3 client 和固件请从 [RfidResearchGroup/proxmark3](https://github.com/RfidResearchGroup/proxmark3) 获取。

## 核心能力

- 通过 `Pm3Backend` 契约和 `DesktopCliBackend` 驱动官方 Proxmark3 client。
- 终端支持完整命令透传、历史记录和输出查看。
- 专用 GUI 优先覆盖高频工作流；低频、诊断及新增命令保留在 Terminal。
- 功能页子终端持续接收输出，切换页面即停止；再次执行命令时开始新的捕获。执行中仍显示已收到的内容，总终端独立保留输出历史。
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

管道模式使用 RRG 客户端的 `rem` 命令生成顺序完成标记（已验证客户端 `da509461`），不会因短暂停顿或表格分隔线提前结束。默认持续等待，长命令执行期间可从连接页断开会话；切页只停止子终端监听，不终止命令。显式指定超时的调用在超时后断开会话，避免未完成命令与后续输出混合。

终端补全合并现有中文帮助与 `docs/pm3_commands_client.json` 客户端快照。更新客户端后，可在项目根目录执行以下只读帮助同步；Windows 使用发行包根目录入口，原生客户端在路径后增加端口参数：

```powershell
dart run tools/sync_command_catalog.dart 'C:/path/to/pm3.bat'
```

同步完成后重新构建 GUI。快照反映采集时客户端与已连接设备可见的命令，不代表每项功能已有专用页面或完成实卡验证。

## 配置与隐私

连接页负责选择并持久化串口/设备端口；设置页管理客户端入口路径、启动参数和可选工作目录。启动参数按“一行一个参数”编辑，空格、引号和反斜杠均按原字符串保留。Windows 请优先选择官方发行包**根目录**的 `pm3.bat`，不要绕过发行包初始化流程直接选择内部客户端。PM3 GUI 会通过 `cmd.exe /d /c call` 启动该脚本并保留标准输入输出交互；脚本自行完成环境初始化、启动内部客户端并自动检测设备，因此 GUI 保存的端口和额外启动参数不会传给 `.bat`/`.cmd`。原生 `proxmark3.exe` 和 Linux `proxmark3` 仍按所选端口启动。

PM3EASY512K 等已由官方 [RfidResearchGroup/proxmark3](https://github.com/RfidResearchGroup/proxmark3) 客户端支持的设备沿用同一入口，不需要 GUI 维护独立型号驱动或白名单。相关设置使用同目录临时文件原子替换，并在界面显示保存中或失败状态；应用关闭会等待最后一次设置写入。设置文件位于：

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
- 官方 Proxmark3 client：Windows 发行包根目录 `pm3.bat`，或 Linux `proxmark3`

### 运行

```bash
git clone https://github.com/AKCX2002/Promark3-GUI.git
cd Promark3-GUI
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

转储查看器的“命令数据”页可直接编辑命令采集结果，无需先生成 dump 文件。功能页和总终端发送的 MIFARE `chk/fchk/nested/staticnested/autopwn` 结果按实际扇区号收集；`hardnested` 需要命令明确包含 `--tblk` 和 `--ta/--tb`，才会归属其恢复结果。`rdbl/rdsc/cgetblk/cgetsc/egetblk/eview/view` 的块表按实际块号收集。总终端输出保持原样。

换卡前通过“新卡 / 容量”清空草稿并选择容量；识别到不同 UID 时也会清空旧数据。缺失块和密钥保留为未知，普通认证读取的尾块不会把隐藏密钥当成零密钥。“密钥 → 尾块”和“尾块 → 密钥”显式同步两者。草稿 JSON 可保存、重新打开未完成数据；完整数据才能导出 BIN/EML，完整扇区密钥才能导出密钥 BIN，已知密钥可单独导出字典。没有转储时打开密钥 BIN/密钥文本会进入此页，不会生成虚假的全零转储。

文件收集扫描配置的工作目录、Windows 发行包 `client` 目录、客户端 `.proxmark3/preferences.json` 中的保存/转储路径，以及 GUI 默认 `pm3_files` 归类目录。扫描异常在文件收集标题旁显示，其他可访问目录仍会继续扫描。

| 类型 | 扩展名 | 读取 | 导出 |
|---|---|---:|---:|
| EML 转储 | `.eml` | ✅ | ✅ |
| 二进制转储 | `.bin`、`.dump` | ✅ | ✅ |
| JSON 转储 | `.json` | ✅ | ✅ |
| 密钥字典 | `.dic` | ✅ | ✅ |
| 密钥文本 | `.keys.txt` | ✅ | ✅ |
| 命令数据草稿 | `.json`（专用草稿格式） | ✅（命令数据页） | ✅ |

## 仓库结构

```text
lib/core/pm3/       # Pm3Backend 契约、命令、事件、结果和 Session 模型
lib/backend/         # DesktopCliBackend、Pm3Process 和 Mock Backend
lib/services/        # 设置、Session、文件和命令服务
lib/state/           # Provider 状态管理
lib/ui/              # 桌面页面和组件
docs/                # 命令映射、规格和架构路线
.github/workflows/   # Windows/Linux 构建与标签发布
```

## 开发与验证

提交前可运行：

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub --no-fatal-infos
flutter test --no-pub
flutter build windows --debug --no-pub
```

上述命令覆盖 Windows 上的格式、静态分析、Dart/Flutter 测试和 Windows debug 构建；不覆盖 Linux runner 构建，也不替代真实 PM3 硬件验收。CI 的 Linux x64 构建路径以 `.github/workflows/build.yml` 为准。

## 参与贡献与安全

欢迎提交 Issue 和 Pull Request。开始前请阅读 [CONTRIBUTING.md](./CONTRIBUTING.md)；安全漏洞请按 [SECURITY.md](./SECURITY.md) 私下报告，不要在公开 Issue 中披露敏感细节。

## 后续路线

下一阶段将建立 **Command Registry** 和 **Parser Registry**，统一命令元数据、参数及输出解析。专用 GUI 继续优先覆盖高频工作流，低频或新增命令继续通过 Terminal 使用。

## 许可证

本项目使用 **GPL-3.0** 许可证，详见 [LICENSE](./LICENSE)。

Proxmark3 名称及其客户端、固件归对应上游项目及贡献者所有；本仓库不分发或重新授权这些上游组件。
