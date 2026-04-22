# PM3 GUI

<div align="center">
  <img src="https://img.shields.io/badge/Flutter-3.27+-02569B?logo=flutter&logoColor=white" alt="Flutter"/>
  <img src="https://img.shields.io/badge/Dart-3.6+-0175C2?logo=dart&logoColor=white" alt="Dart"/>
  <img src="https://img.shields.io/badge/Platforms-Android%20%7C%20Linux%20%7C%20Windows-2ea44f" alt="Platforms"/>
  <img src="https://img.shields.io/badge/License-GPL--3.0-blue" alt="License"/>
  <img src="https://img.shields.io/badge/Status-Alpha-red" alt="Status"/>
</div>

跨平台 Proxmark3 图形界面，面向 RFID/NFC 读写、分析与数据管理场景。

> ⚠️ 当前为 Alpha 阶段，接口和行为可能在后续版本中调整。

---

## Features

- **跨平台 GUI**：Android / Linux / Windows 统一交互体验。
- **CLI Wrapper 架构**：直接驱动原生 `pm3`/`proxmark3` 客户端，持续跟随上游命令能力。
- **文件自动归集**：扫描并按卡片标识归档 dump/key 文件。
- **离线数据能力**：支持 dump 查看、编辑、比较与格式转换。
- **终端模式**：完整 PM3 命令透传，保留高级用户的 CLI 使用路径。

## Architecture

```text
Flutter UI (Provider state)
   ├─ Connection / Terminal / Data Pages
   ├─ Parsers (.eml/.bin/.json/.dic)
   └─ Services (Pm3Process, FileCollector, DumpConverter)
            │
            └─ stdin/stdout pipe
                    │
               proxmark3 CLI
```

## Getting Started

### Prerequisites

- Flutter 3.27+
- Dart 3.6+
- Proxmark3 CLI (`pm3` 或 `proxmark3`，推荐 RRG/Iceman 分支)

### Run locally

```bash
git clone https://github.com/AKCX2002/pm3gui.git
cd pm3gui
flutter pub get
flutter run -d linux
```

### Build artifacts

```bash
flutter build linux
flutter build windows
flutter build apk --split-per-abi
```

## Supported Data Formats

| Type | Extensions | Read | Export |
|---|---|---:|---:|
| EML dump | `.eml` | ✅ | ✅ |
| Binary dump | `.bin`, `.dump` | ✅ | ✅ |
| JSON dump | `.json` | ✅ | ✅ |
| Key dictionary | `.dic` | ✅ | ✅ |
| Key text | `.keys.txt` | - | ✅ |

## Project Layout

```text
lib/
├─ models/           # 数据模型
├─ parsers/          # dump/key 解析器
├─ services/         # PM3 进程、文件与命令服务
├─ state/            # Provider 状态管理
└─ ui/               # 页面与组件

docs/                # 设计文档、命令映射与开发计划
.github/workflows/   # CI/CD 工作流
```

## Development Workflow

建议本地在提交前执行：

```bash
flutter pub get
flutter analyze
flutter test
```

仓库已提供以下 GitHub Actions：

- **build.yml**：主干与 PR 的多平台构建校验。
- **release.yml**：标签发布时构建并上传 Release 资产。
- **sync-pm3.yml**：同步并构建上游 Proxmark3 客户端与固件。

## Contributing

欢迎通过 Issue / Pull Request 参与贡献。

1. Fork 仓库并创建特性分支。
2. 保持提交小而清晰，附带必要测试。
3. 提交 PR，并说明变更背景、影响范围与验证方式。

## License

本项目遵循 **GPL-3.0** 开源许可证。详见 [LICENSE](./LICENSE)。
