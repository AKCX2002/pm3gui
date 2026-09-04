# Changelog

本文件记录 PM3 GUI 的重要变更，版本号遵循[语义化版本](https://semver.org/lang/zh-CN/)。

## [Unreleased]

### Added

- 新增桌面客户端设置持久化、连接 Session 日志与可靠关闭流程。
- 新增 Windows 官方 `pm3.bat` 交互入口及 PM3EASY512K 实机连接支持。

### Changed

- 合并 Windows/Linux 构建与标签发布工作流；`v*` 标签自动生成双平台 Release 产物。
- 完善下载、贡献、安全和 GPL-3.0 许可说明。

## [0.0.3] - Fixes

- Fix: Correctly detect found MIFARE keys in `lib/parsers/output_parser.dart` (was incorrectly checking a numeric flag).
- Fix: Improve `sendCommandAndWait` in `lib/backend/desktop_cli/pm3_process.dart` to wait for table terminators (ensures `hf mf autopwn` full output including final key table is captured).

[Unreleased]: https://github.com/AKCX2002/Promark3-GUI/compare/v0.0.3-alpha...HEAD
[0.0.3]: https://github.com/AKCX2002/Promark3-GUI/releases/tag/v0.0.3-alpha

