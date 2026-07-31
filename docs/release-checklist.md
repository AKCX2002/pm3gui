# 发布验收清单

## 自动化门禁

- [ ] `npm ci`
- [ ] `npm run check`
- [ ] `cargo fmt --check --manifest-path src-tauri/Cargo.toml`
- [ ] `cargo clippy --manifest-path src-tauri/Cargo.toml --all-targets -- -D warnings`
- [ ] `cargo test --manifest-path src-tauri/Cargo.toml`
- [ ] `npm run tauri build`
- [ ] 便携包静态与启动冒烟
- [ ] `git diff --check`

## 真实硬件门禁

- [ ] Windows 10 21H2+ 实机
- [ ] Windows 11 实机
- [ ] 普通、空格和中文 Client 路径
- [ ] 100 次连接/断开循环无残留进程
- [ ] 握手和命令期间拔出设备后可恢复
- [ ] 应用退出后 Bash/PM3 子进程全部退出
- [ ] HF/LF 只读命令
- [ ] 使用可损耗测试卡验证写块、恢复、擦除和风险确认
- [ ] 记录 Client、固件和设备型号到兼容性表

真实硬件门禁全部完成前，不创建 `v1.0.0` 标签，不宣称稳定版。
