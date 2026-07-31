PM3 GUI - Proxmark3 图形界面 v0.1.0
=======================================
便携式版本，无需安装。

使用方法：
  1. 直接运行 PM3GUI.exe
  2. 在"连接"页面选择 PM3 client 目录（包含 proxmark3.exe 和 pm3 脚本的目录）
  3. 点击"刷新"扫描串口
  4. 选择串口（Windows 通常为 COM3）
  5. 点击"连接"

系统要求：
  - Windows 10 21H2+ 或 Windows 11（需要内置 WebView2）

PM3 客户端目录结构：
  pm3-client/
  ├── proxmark3.exe          # Windows 可执行文件
  ├── pm3                    # bash 脚本
  ├── libs/shell/bash.exe    # MSYS2 bash
  ├── dictionaries/          # 密钥字典
  └── resources/             # AID 列表等

功能：
  - 终端：直接输入 PM3 命令
  - HF 高频：MIFARE/DESFire/iCLASS 等 12 种协议
  - LF 低频：HID/Hitag/AWID 等 9 种协议
  - Dump：十六进制查看和双文件对比
  - 设置：暗色模式、默认目录配置
