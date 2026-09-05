# Changelog

本文件记录 PM3 GUI 的重要变更，版本号遵循[语义化版本](https://semver.org/lang/zh-CN/)。

## [Unreleased]

### Fixed

- 子终端持续显示输出，直到切换页面、重新执行命令或销毁页面；不再在 5/8/10 秒后截断，总终端保持原有显示与历史行为。
- 修复功能页面一次点击重复发送命令，以及执行中加载动画遮住实时输出的问题。
- 使用客户端 `rem` 顺序标记判断命令与 Windows 握手完成，避免静默、表格边框和命令回显导致提前返回；拒绝并发发送，显式超时不再返回部分成功结果。
- Windows 客户端的异常 UTF-8 字节不再导致整个会话断开。

### Added

- 从当前客户端 96 个帮助分组同步 1033 个终端命令条目，并提供 `tools/sync_command_catalog.dart` 更新工具；已有中文说明保留。

## [0.0.3] - 2026-09-04

### Added

- 新增桌面客户端设置持久化、连接 Session 日志与可靠关闭流程。
- 新增 Windows 官方 `pm3.bat` 交互入口及 PM3EASY512K 实机连接支持。

### Changed

- 合并 Windows/Linux 构建与标签发布工作流；`v*` 标签自动生成双平台 Release 产物。
- 完善下载、贡献、安全和 GPL-3.0 许可说明。

### Fixed

- Fix: Correctly detect found MIFARE keys in `lib/parsers/output_parser.dart` (was incorrectly checking a numeric flag).
- Fix: Improve `sendCommandAndWait` in `lib/backend/desktop_cli/pm3_process.dart` to wait for table terminators (ensures `hf mf autopwn` full output including final key table is captured).

[Unreleased]: https://github.com/AKCX2002/Promark3-GUI/compare/v0.0.3...HEAD
[0.0.3]: https://github.com/AKCX2002/Promark3-GUI/compare/v0.0.3-alpha...v0.0.3

