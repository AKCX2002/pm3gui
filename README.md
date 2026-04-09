# PM3 GUI

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.27-02569B?logo=flutter&logoColor=white" alt="Flutter"/>
  <img src="https://img.shields.io/badge/Dart-3.6-0175C2?logo=dart&logoColor=white" alt="Dart"/>
  <img src="https://img.shields.io/badge/平台-Android%20%7C%20Linux%20%7C%20Windows-brightgreen" alt="平台"/>
  <img src="https://img.shields.io/badge/协议-GPL--3.0-blue" alt="License"/>
  <img src="https://img.shields.io/badge/状态-BETA-orange" alt="Status"/>
</p>

<p align="center">
  <b>Proxmark3 跨平台图形界面 </b>
</p>

> ⚠️ <b>BETA 声明</b>：本项目目前处于 BETA 测试阶段，可能存在未发现的 bug 和功能限制。
> 
> ⚠️ <b>未完整测试声明</b>：部分功能可能尚未在所有平台和硬件组合上进行充分测试。使用时请谨慎操作，建议在测试环境中验证后再用于生产场景。

---

## ✨ 功能概览

| 模块 | 说明 |
|:----:|------|
| 🔌 **连接 / 仪表盘** | 自动检测串口、连接状态总览、环境信息、PM3 文件自动收集与归类 |
| 💻 **终端** | 完整的 PM3 交互式终端，支持 ANSI 彩色输出、命令历史和快捷命令按钮 |
| 📁 **Dump 查看 / 编辑** | 扇区视图 · 密钥编辑 · 深度分析 · CUID 回写/清空 · 智能文件合并 |
| 🔀 **Dump 对比** | 两份转储并排对比，字节级差异高亮，差异统计面板 |
| 🔐 **Mifare 高频** | 检测 / Autopwn / 转储 / 恢复 / Nested / Hardnested / Darkside / 魔术卡 |
| 📡 **低频 (LF)** | EM410x 读取与克隆、T55xx 检测 / 转储 / 块读写、天线调谐 |
| ⚙️ **设置** | PM3 路径配置、莫兰迪色系主题切换、硬件版本和调谐快捷操作 |

## 🏗 架构设计

```
┌──────────────────────────────────────────────────────────┐
│                    Flutter GUI (侧边栏导航)               │
│  ┌─────────────┐  ┌──────────┐  ┌──────────────────────┐ │
│  │ Provider     │  │ 莫兰迪   │  │   Dump 解析器        │ │
│  │ 全局状态     │  │ M3 主题  │  │ .eml .bin .json .dic │ │
│  └──────┬──────┘  └──────────┘  └──────────────────────┘ │
│         │                                                │
│  ┌──────▼──────────────────────────────────────────────┐ │
│  │               Pm3Process (dart:io)                  │ │
│  │   stdin/stdout 管道 ⟷ pm3 命令行  ⟷ OutputParser   │ │
│  └─────────────────────────────────────────────────────┘ │
│         │                                                │
│  ┌──────▼──────────────────────────────────────────────┐ │
│  │         FileCollector — 文件自动收集 & 归类          │ │
│  │   扫描 PM3 工作目录 → 按 UID 分组 → 移动到归类目录  │ │
│  └─────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
         │  启动子进程
         ▼
┌────────────────────┐
│  proxmark3 命令行  │  ← Iceman 分支 (RRG)
│  （原始程序不变）  │
└────────────────────┘
```

> **CLI Wrapper 模式** — 界面通过管道启动原版 `pm3` / `proxmark3` 程序。
> 上游命令更新自动继承，零维护成本。

---

## 📖 各页面功能详解

### 1. 🔌 连接 / 仪表盘（connection_page）

进入应用后的首页，采用**左右分栏**布局：

**左栏 — 连接控制**

| 功能 | 说明 |
|------|------|
| 连接状态头 | 圆形指示灯 + 端口/版本一行显示 |
| PM3 程序路径 | 输入框 + 文件有效性实时验证（✅/❌） |
| 串口选择 | 下拉菜单 + 刷新按钮；自动扫描 `/dev/ttyACM*` / `ttyUSB*`（Linux）或 `COM1-20`（Windows） |
| 连接/断开 | 带加载动画的主按钮 |
| 设备信息 | 连接后显示端口、版本、命令历史数、终端缓冲行数；快捷按钮「硬件版本」「天线调谐」 |
| 环境信息 | 平台 / CPU 架构 / Dart 版本 / PM3 路径有效性 |
| 错误信息 | 连接失败时显示莫兰迪色错误卡片 |

**右栏 — PM3 文件收集**

| 功能 | 说明 |
|------|------|
| 自动扫描 | 自动扫描 PM3 工作目录（`pm3` 所在目录 + `$HOME` + 当前目录），检测 dump/key 文件 |
| 按卡片分组 | 按 UID 自动分组展示，显示各组的转储数/密钥数/文件总数 |
| 文件详情 | 展开卡片组可看到每个文件的名称、大小、修改时间、格式 |
| 归类整理 | 点击「归类整理」将散落的文件移动到结构化目录中 |

**📂 归类整理存放位置：**

默认目标目录为 `<当前工作目录>/pm3_files/`，可在对话框中自行修改。整理后的目录结构：

```
pm3_files/
├── hf-mf/
│   ├── A991A280/
│   │   ├── hf-mf-A991A280-dump.bin
│   │   ├── hf-mf-A991A280-dump-001.bin
│   │   ├── hf-mf-A991A280-key.bin
│   │   └── hf-mf-A991A280-dump.json
│   └── 3BA66BB9/
│       ├── hf-mf-3BA66BB9-dump.bin
│       └── hf-mf-3BA66BB9-key.bin
└── lf-em/
    └── 12345678/
        └── lf-em-12345678-dump.bin
```

> **规则**：按 `<频段>-<卡类型>/<UID>/` 二级目录结构存放。已存在于目标位置的同名文件不会被覆盖。整理完成后自动重新扫描。

**自动触发时机**：

- 应用启动时首次扫描
- 连接 PM3 成功时
- PM3 输出中检测到 `saved` 关键字时（延迟 1 秒后自动刷新）

---

### 2. 💻 终端（terminal_page）

全功能 PM3 交互式终端，直接透传 stdin/stdout。

| 功能 | 说明 |
|------|------|
| 命令输入 | 底部输入框，回车发送 |
| 输出显示 | 带滚动的终端输出区域，自动 ANSI 色彩剥离 |
| 命令历史 | 方向键 ↑ 回溯上一条命令 |
| 快捷命令 | 按钮组：高频搜索 · 低频搜索 · 14A 信息 · 硬件版本 · 天线调谐 · 低频读取 · 自动破解 |

---

### 3. 📁 Dump 查看 / 编辑（dump_viewer_page）

核心离线功能，**无需连接硬件**即可使用。包含 **4 个选项卡**（无论是否已加载文件均可见）：

#### 选项卡 ①：扇区视图

| 功能 | 说明 |
|------|------|
| 扇区列表 | 左侧扇区编号列表（Sec 0 ~ Sec N），点击切换 |
| 块数据 Hex | 每个块 16 字节 32 位十六进制显示 |
| 高亮规则 | 制造商块（Block 0）→ 特殊标记；尾块（Trailer）→ 密钥分段高亮 |
| 密钥分段 | Key A（前 6 字节）· 访问控制位（3+1 字节）· Key B（后 6 字节） |
| 访问控制解码 | 中文说明各块的读/写/递增/递减权限 |

#### 选项卡 ②：密钥 / 编辑

| 功能 | 说明 |
|------|------|
| 密钥表格 | 按扇区列出 Key A / Key B，带 `TextEditingController` 可直接编辑 |
| 块数据编辑 | 选择扇区后逐块编辑 hex 数据 |
| 复制密钥 | 支持仅复制 Key A / Key B / 全部密钥到剪贴板 |
| 应用编辑 | 将编辑器中的修改写回内存中的 `MifareCard` 模型 |

#### 选项卡 ③：深度分析

| 功能 | 说明 |
|------|------|
| 制造商块解码 | UID / SAK / ATQA / 制造商识别 |
| 默认密钥检测 | 对照 20+ 已知密钥（NXP / MAD / NDEF / VIGIK / HID 等）标记 |
| 密钥模式分析 | 统计各扇区密钥使用模式，识别全 FF / 全 0 / 自定义 |
| MAD 解析 | 解析 MAD（Mifare Application Directory）扇区，显示 AID 描述 |
| 值块检测 | 识别符合 Mifare 值块格式的数据块，显示解码值 |
| 数据 ASCII | 非零数据块的可打印 ASCII 预览 |

#### 选项卡 ④：回写 / 清空（CUID）

| 功能 | 说明 |
|------|------|
| 整卡回写 | 将内存中的 dump 数据逐块写入 CUID 兼容卡 |
| 扇区回写 | 选择单个扇区写入 |
| 整卡清空 | 将所有数据块清零（0x00），带确认对话框 |
| 认证密钥选择 | `Key A` / `Key B` 切换写入认证密钥 |
| 跳过 Block 0 | 可选跳过制造商块（Block 0） |
| 写入尾块 | 可选是否写入 Trailer 块（密钥+访问控制位） |
| 进度显示 | 逐块写入进度条，支持取消操作 |

#### 🔑 智能文件合并策略

打开文件时的行为因文件类型不同而异：

| 打开的文件类型 | 行为 |
|:---:|------|
| **Key 文件**（.dic / 文件名含 `-key` / .bin 大小匹配密钥布局） | **仅合并密钥**到当前卡片的 `sectorKeys`，块数据完全不动 |
| **Dump 文件**（当前已有密钥时） | 弹出对话框：**保留当前密钥** 或 **用转储文件覆盖** |
| **Dump 文件**（首次加载） | 正常加载全部数据（块 + 密钥） |

> 这解决了常见工作流问题：先用 `hf mf autopwn` 获取密钥文件，再加载 dump 查看数据但不想丢失已破解的密钥。

**Key 文件检测规则**（三重判定）：

1. 扩展名为 `.dic` → 字典文件
2. 文件名包含 `-key` → PM3 标准密钥文件名
3. `.bin` 文件大小为 60 / 192 / 384 / 480 字节 → 对应 MINI / 1K / 2K / 4K 密钥布局

**PM3 二进制密钥文件格式**：

```
[KeyA_sec0][KeyA_sec1]...[KeyA_secN][KeyB_sec0][KeyB_sec1]...[KeyB_secN]
 ← sectorCount × 6 字节 →           ← sectorCount × 6 字节 →
```

> ⚠️ 注意：PM3 密钥文件采用**顺序布局**（先全部 Key A，再全部 Key B），不是交错布局。

#### 导出格式

| 格式 | 扩展名 | 说明 |
|------|--------|------|
| EML | `.eml` | 文本模拟器格式（每行一个块，32 hex chars） |
| 二进制转储 | `.bin` | 原始 1:1 二进制转储 |
| JSON | `.json` | PM3 Jansson 格式（含 UID/ATQA/SAK 元数据） |
| 二进制密钥 | `.key.bin` | PM3 标准密钥二进制格式 |
| 密钥字典 | `.dic` | 一行一个密钥，带注释头 |
| 密钥文本 | `.keys.txt` | 按扇区列出 Key A / Key B |

---

### 4. 🔀 Dump 对比（dump_compare_page）

| 功能 | 说明 |
|------|------|
| 双栏加载 | 分别选择文件 A 和文件 B |
| 并排显示 | 按块对齐显示两份转储数据 |
| 字节级高亮 | 不同的字节标红，相同的保持原色 |
| 差异统计 | 显示不同块数 / 不同字节数 / 总块数 |
| 仅显示差异 | 过滤开关，可只展示有差异的块 |

---

### 5. 🔐 Mifare 高频操作（mifare_page）

需连接 PM3 硬件。包含 **4 个选项卡**：

| 选项卡 | 功能 |
|:------:|------|
| **快捷操作** | 检测卡片 · 卡片信息 · Autopwn 自动破解 · 转储 · 恢复 · 嗅探 |
| **密钥攻击** | 检查默认密钥 · Nested 攻击 · Static Nested · Hardnested · Darkside 攻击 |
| **读写块** | 单块读取 · 数据写入（选择扇区/块/密钥类型/密钥值/数据） |
| **魔术卡** | Block 0 读取 · 整卡擦除（带确认） · 模拟器加载 · 支持 Gen1A / Gen2(CUID) / Gen3 |

支持卡类型切换：MINI / 1K / 2K / 4K

---

### 6. 📡 低频操作（lf_page）

需连接 PM3 硬件。包含 **3 个选项卡**：

| 选项卡 | 功能 |
|:------:|------|
| **通用** | 低频搜索 · 读取 · 嗅探 · 天线调谐 |
| **EM4x05** | 读取 EM410x ID · 克隆到 T55xx（含 hex 格式验证） |
| **T55xx** | 检测 · 信息 · 转储 · 块 0-7 逐块读写 |

---

### 7. ⚙️ 设置（settings_page）

| 功能 | 说明 |
|------|------|
| 主题切换 | 深色 莫兰迪 / 浅色 莫兰迪 |
| PM3 路径 | 独立的路径配置入口 |
| 关于信息 | 平台 / 架构 / 支持格式列表 |
| 维护操作 | 清除终端 · 查询硬件版本 · 天线调谐 |

---

## 📂 项目结构

```
pm3gui/
├── lib/
│   ├── main.dart                  # 入口，Provider 注入，主题切换
│   ├── models/
│   │   ├── mifare_card.dart       # MifareCard / CardType / SectorKey 数据模型
│   │   ├── access_bits.dart       # 访问控制位 编码/解码
│   │   └── dump_analysis.dart     # 深度分析引擎（MAD/值块/默认密钥/模式）
│   ├── parsers/
│   │   ├── dump_parser.dart       # 统一解析入口（自动识别格式）
│   │   ├── eml_parser.dart        # .eml 文本格式
│   │   ├── bin_parser.dart        # .bin / .dump 二进制格式 + 密钥文件检测
│   │   ├── json_dump_parser.dart  # PM3 Jansson JSON 格式
│   │   ├── key_parser.dart        # 密钥文件解析 / 导出（.bin / .dic / .txt）
│   │   └── output_parser.dart     # PM3 stdout 正则解析器（UID/密钥/块等）
│   ├── services/
│   │   ├── pm3_process.dart       # 进程管理（连接/发送/流读取）
│   │   ├── pm3_commands.dart      # 命令模板（HF/LF/HW/魔术卡/CUID）
│   │   ├── file_collector.dart    # PM3 文件自动收集 / 归类服务
│   │   ├── dump_converter.dart    # 转储格式转换
│   │   └── file_dialog_service.dart # 跨平台文件选择对话框
│   ├── state/
│   │   └── app_state.dart         # 全局状态（连接/终端/卡片/文件收集/写入进度）
│   └── ui/
│       ├── theme.dart             # 莫兰迪色系 Material 3 深色/浅色主题
│       ├── home_page.dart         # 侧边栏导航（7 页 + IndexedStack 状态保持）
│       └── pages/
│           ├── connection_page.dart   # 连接 / 仪表盘（双栏布局）
│           ├── terminal_page.dart     # 交互终端
│           ├── dump_viewer_page.dart  # Dump 查看 / 编辑 / 分析 / 回写
│           ├── dump_compare_page.dart # Dump 对比（双栏差异高亮）
│           ├── mifare_page.dart       # Mifare 操作页
│           ├── lf_page.dart           # 低频操作页
│           └── settings_page.dart     # 设置页
├── docs/
│   └── pm3_commands.yaml          # PM3 命令覆盖率映射（43 项 GUI 封装）
├── android/                       # 已配置 USB OTG 权限
├── linux/
├── windows/
├── test/
└── pubspec.yaml
```

## 🎨 莫兰迪色系

界面采用低饱和度莫兰迪色彩体系，长时间使用不易视觉疲劳：

| 色彩 | 色值 | 用途 |
|:----:|:----:|------|
| 莫兰迪蓝 | `#7E9AAB` | 主色调、选中状态、链接 |
| 莫兰迪绿 | `#8FA9A0` | 成功、连接状态、HF 标识 |
| 莫兰迪玫瑰 | `#BFA2A2` | 断开、删除、警告操作 |
| 莫兰迪暖灰 | `#A89F91` | 次要信息 |
| 莫兰迪薰衣草 | `#9B96B4` | 密钥文件、装饰色 |
| 柔和红 | `#C47D7D` | 错误信息 |
| 柔和绿 | `#8EAD8E` | 成功状态 |
| 柔和黄 | `#C9B07F` | 警告提示 |

## 🚀 快速上手

### 前置条件

- [Flutter 3.24+](https://flutter.dev/docs/get-started/install)
- Proxmark3 命令行客户端 (`pm3`) — [Iceman 分支](https://github.com/RfidResearchGroup/proxmark3)

### 编译与运行

```bash
# 克隆仓库
git clone https://github.com/AKCX2002/pm3gui.git
cd pm3gui

# 安装依赖
flutter pub get

# Linux 桌面运行
flutter run -d linux

# 编译发布版
flutter build linux          # → build/linux/x64/release/bundle/
flutter build apk            # → build/app/outputs/flutter-apk/
flutter build windows        # → build/windows/x64/runner/Release/
```

### Android（USB OTG）

应用已预配置 USB 主机权限和 PM3 设备过滤器。
通过 USB OTG 线缆连接 Proxmark3，应用会自动检测设备。

> ⚠️ Android 运行需要为 ARM 架构交叉编译 PM3 原生程序，这属于单独的编译步骤。

## 📋 支持的卡片协议

### 命令覆盖率

PM3 GUI 封装了 **43 个一级命令模板**（`Pm3Commands` 类），覆盖以下协议族：

| 协议 | GUI 命令数 | 原始 CLI 命令数 | 覆盖内容 |
|------|:---------:|:--------------:|----------|
| HF 14443-A | 2 | 9 | 搜索、信息 |
| HF Mifare Classic | 25 | 57 | 全链路：检测→攻击→读写→模拟器→Gen1A/Gen2(CUID)/Gen3 |
| LF 通用 | 4 | 6 | 搜索、读取、嗅探、调谐 |
| LF EM4x | 2 | 15 | EM410x 读取/克隆 |
| LF T55xx | 5 | 12 | 检测/信息/转储/块读写 |
| HW 硬件 | 3 | 14 | 版本/状态/调谐 |

> 完整命令映射参见 [`docs/pm3_commands.yaml`](docs/pm3_commands.yaml)。
> 未覆盖的命令仍可通过「终端」页面直接输入执行。

### 支持的 Dump/Key 格式

| 格式 | 扩展名 | 读取 | 导出 | 说明 |
|------|--------|:----:|:----:|------|
| EML | `.eml` | ✅ | ✅ | 文本模拟器格式 |
| 二进制转储 | `.bin` `.dump` | ✅ | ✅ | 原始 1:1 二进制 |
| JSON | `.json` | ✅ | ✅ | PM3 Jansson 格式 |
| 二进制密钥 | `.bin`（按大小检测） | ✅ | ✅ | PM3 标准密钥格式 |
| 密钥字典 | `.dic` | ✅ | ✅ | 一行一个密钥 |
| 密钥文本 | `.keys.txt` | — | ✅ | 按扇区列出 |

## 🔧 配置项

| 设置 | 默认值 | 说明 |
|------|--------|------|
| PM3 路径 | `./pm3` | proxmark3 客户端程序路径 |
| 主题 | 深色（莫兰迪） | 可在设置页或侧边栏切换 |
| 文件收集目录 | PM3 目录 + `$HOME` + CWD | 自动扫描的搜索范围 |
| 归类整理目录 | `<CWD>/pm3_files/` | 「归类整理」的默认目标（可自定义） |

## 📝 开源协议

本项目采用 [GPL-3.0](LICENSE) 协议开源，与 Proxmark3 项目保持一致。

## 🙏 致谢

- [RfidResearchGroup/proxmark3](https://github.com/RfidResearchGroup/proxmark3) — Iceman 分支
- [wh201906/Proxmark3GUI](https://github.com/wh201906/Proxmark3GUI) — 设计参考（Qt C++，LGPL-2.1）
- 使用 [Flutter](https://flutter.dev) 和 [Material 3](https://m3.material.io) 构建
