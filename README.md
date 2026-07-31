# PM3 GUI

面向 Windows 10/11 的 Proxmark3 桌面客户端，使用 Tauri 2、Rust、Vue 3 和 TypeScript。

当前分支是 `0.1.0 RC`：自动化构建已经建立，真实 PM3 设备兼容性矩阵尚未完成，因此不冒充稳定版或 `1.0.0`。

## 功能

- 选择现有 Windows PM3 Client 目录，不捆绑、不修改外部 Client。
- 单设备、单活动会话，Windows Job Object 负责清理进程树。
- 原始终端支持任意 PM3 命令，输出按字节流读取并使用有界历史。
- HF/LF 常用操作由 Rust 统一验证和生成命令。
- 写块、恢复、擦除、模拟需要确认；关键块操作需要输入 `EXECUTE`。
- 只读 Dump 查看、受限文本预览和后台差异统计。
- 本地设置和显式脱敏诊断导出。

## 运行

要求 Windows 10 21H2+ 或 Windows 11 x64、WebView2，以及一个已解压的 Windows PM3 Client。所选目录须包含：

```text
pm3
libs\shell\bash.exe
```

开发命令：

```powershell
npm ci
npm run check
cargo test --manifest-path src-tauri/Cargo.toml
npm run tauri build
```

生成便携包：

```powershell
powershell -NoProfile -File scripts/package-portable.ps1
powershell -NoProfile -File scripts/smoke-portable.ps1
```

## 安全边界

原始终端按设计允许任意 PM3 命令。图形页面只调用类型化操作；请仅用可损耗测试卡执行写入、恢复或擦除。应用不会自动刷写固件、更新 Client，也不会把密钥或命令历史写入诊断文件。

兼容性与发布门禁见 [docs/compatibility.md](docs/compatibility.md) 和 [docs/release-checklist.md](docs/release-checklist.md)。
