# 贡献指南

感谢你为 PM3 GUI 提交改进。项目使用 GPL-3.0 许可证；提交贡献即表示你有权提交相关内容，并同意按该许可证发布。

## 开始之前

- Bug 报告请包含操作系统、Flutter 版本、Proxmark3 client 来源、复现步骤和去敏后的日志。
- 新功能或较大行为变更建议先创建 Issue，说明使用场景和预期交互。
- 安全问题请遵循 [SECURITY.md](./SECURITY.md)，不要公开漏洞细节、凭据、卡片 UID 或设备隐私信息。

## 本地开发

```bash
flutter pub get
flutter run -d windows
```

Linux 开发可将设备目标改为 `linux`。Windows 与官方 Proxmark3 发行包集成时，请选择发行包根目录的 `pm3.bat`。

提交前至少运行与改动相关的检查：

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub --no-fatal-infos
flutter test --no-pub
```

涉及桌面打包或平台代码时，再执行对应平台的 `flutter build`。涉及真实硬件行为时，请说明设备型号、只读/写入范围和实际验证结果；不要把模拟测试写成实机通过。

## Pull Request

- 保持改动聚焦，并说明问题、解决方式和验证结果。
- 保留现有兼容行为；新增依赖或平台差异时说明必要性。
- 更新受影响的 README、CHANGELOG 或架构文档。
- 不提交构建目录、Proxmark3 发行包、固件、凭据或未脱敏 Session 日志。
