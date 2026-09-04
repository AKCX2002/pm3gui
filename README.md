# PM3 GUI

<div align="center">
  <img src="https://img.shields.io/badge/Flutter-3.27+-02569B?logo=flutter&logoColor=white" alt="Flutter"/>
  <img src="https://img.shields.io/badge/Dart-3.6+-0175C2?logo=dart&logoColor=white" alt="Dart"/>
  <img src="https://img.shields.io/badge/Platforms-Linux%20%7C%20Windows-2ea44f" alt="Platforms"/>
  <img src="https://img.shields.io/badge/License-GPL--3.0-blue" alt="License"/>
  <img src="https://img.shields.io/badge/Status-Alpha-red" alt="Status"/>
</div>

PM3 GUI 是一个面向 Proxmark3 的跨平台图形化客户端，聚焦 RFID/NFC 读写、转储管理、分析与命令操作。

> ⚠️ **Alpha 说明**：当前版本仍在快速迭代，部分功能/行为可能在后续版本中调整。

---

## Why PM3 GUI

- 为 PM3 CLI 提供更低门槛的可视化操作入口。
- 保留高级用户的命令透传能力，而非替代 CLI。
- 通过结构化文件管理和离线分析降低重复劳动。

## Core Features

- **桌面平台支持**：Linux、Windows。
- **CLI Wrapper 架构**：通过进程管道驱动 `pm3`/`proxmark3`，自动继承上游命令能力。
- **终端模式**：支持完整命令输入、历史回溯与输出展示。
- **Dump/Key 文件管理**：自动扫描、识别、分组与归档。
- **数据处理能力**：支持 dump 查看、编辑、比较、转换与导出。

## Architecture Overview

```text
Flutter Desktop UI / Feature
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
 Pm3Process (internal adapter)
             │
             ▼
 official proxmark3 client
```

Widget 和 Feature 仅通过 `Pm3Controller` 使用结构化命令、结果和事件；
`dart:io Process` 被限制在 Desktop CLI Backend 内部。

## Installation & Quick Start

### Prerequisites

- Flutter 3.27+
- Dart 3.6+
- Proxmark3 CLI (`pm3` 或 `proxmark3`，推荐 RRG/Iceman 分支)

### Run

```bash
git clone https://github.com/AKCX2002/pm3gui.git
cd pm3gui
flutter pub get
flutter run -d linux
```

### Build

```bash
flutter build linux
flutter build windows
```

## Supported File Formats

| Type | Extensions | Read | Export |
|---|---|---:|---:|
| EML dump | `.eml` | ✅ | ✅ |
| Binary dump | `.bin`, `.dump` | ✅ | ✅ |
| JSON dump | `.json` | ✅ | ✅ |
| Key dictionary | `.dic` | ✅ | ✅ |
| Key text | `.keys.txt` | - | ✅ |

## Repository Layout

```text
lib/
├─ core/pm3/         # 后端契约、命令、事件、结果与 Controller
├─ backend/          # Desktop CLI 实现与 Mock Backend
├─ models/           # 现有数据模型（逐步迁移）
├─ parsers/          # 现有 dump/key 解析器（逐步迁移）
├─ services/         # 文件、命令与转换服务
├─ state/            # Provider 状态管理
└─ ui/               # 页面与组件（逐步迁移到 features）

docs/                # 规格说明、开发任务、命令映射
.github/workflows/   # CI/CD 工作流
```

## Engineering Workflow

建议在本地提交前执行：

```bash
flutter pub get
flutter analyze
flutter test
```

CI/CD（GitHub Actions）包含：

- `build.yml`：主分支/PR 的 Windows、Linux 桌面构建与静态检查，也可手动触发。
- `release.yml`：版本标签触发 Windows、Linux 构建并发布 Release 资产。

CI 不构建或发布 Proxmark3 Client/固件。Proxmark3 由上游项目维护，GUI
构建与 PM3 构建保持独立，避免重复消耗 CI 资源和产生来源不明确的二进制文件。

## Contributing

欢迎提交 Issue 与 Pull Request。

1. Fork 仓库并创建特性分支。
2. 变更尽量保持小步提交，并附带验证说明。
3. PR 描述中注明：背景、修改内容、影响范围、测试结果。

## Roadmap (Short-term)

- 完善更多 PM3 子命令页面覆盖。
- 增强 dump 差异分析与异常提示。
- 提升 Windows/Linux 设备连接与进程生命周期稳定性。

## License

本项目使用 **GPL-3.0** 许可证，详见 [LICENSE](./LICENSE)。
