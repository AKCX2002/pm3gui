# PM3GUI 重构计划文档

## 1. 项目现状分析

### 1.1 当前架构

PM3GUI 是一个基于 Flutter 的 Proxmark3 图形界面应用，采用 **CLI Wrapper 模式** —— 通过管道启动原版 `pm3` / `proxmark3` 程序，上游命令更新自动继承，零维护成本。

```
┌──────────────────────────────────────────────────────────┐
│                    Flutter GUI (侧边栏导航)               │
│  ┌─────────────┐  ┌──────────┐  ┌──────────────────────┐ │
│  │ Provider     │  │ Slate    │  │   Dump 解析器        │ │
│  │ 全局状态     │  │ 蓝灰主题 │  │ .eml .bin .json .dic │ │
│  └──────┬──────┘  └──────────┘  └──────────────────────┘ │
│         │                                                │
│  ┌──────▼──────────────────────────────────────────────┐ │
│  │               Pm3Process (dart:io)                  │ │
│  │   stdin/stdout 管道 ⟷ pm3 命令行  ⟷ OutputParser   │ │
│  └─────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
```

### 1.2 当前覆盖率

| 指标 | 数值 |
|:-----|:----:|
| 协议族总数 | 27 |
| 已覆盖协议族 | 7 |
| **协议族覆盖率** | **26%** |
| GUI封装命令数 | 43 |

**已覆盖协议（7个）**：
- HF Mifare Classic
- HF 14443-A
- LF 通用
- LF EM4x
- LF T55xx
- HW 硬件

### 1.3 现有页面结构

```
lib/ui/pages/
├── connection_page.dart    # 连接/仪表盘
├── terminal_page.dart      # 交互终端
├── dump_viewer_page.dart   # Dump查看/编辑
├── dump_compare_page.dart  # Dump对比
├── mifare_page.dart        # Mifare高频操作
├── lf_page.dart            # 低频操作
└── settings_page.dart      # 设置
```

---

## 2. 重构目标

### 2.1 总体目标

将协议族覆盖率从 **26%** 提升到 **100%**，实现对所有27个协议族的完整GUI支持。

### 2.2 具体目标

| 指标 | 当前 | 目标 | 提升 |
|:-----|:----:|:----:|:----:|
| 已覆盖协议族 | 7 | **27** | **+20** |
| 协议族覆盖率 | 26% | **100%** | **+74%** |
| GUI封装命令数 | 43 | **~200** | **+157** |

---

## 3. 新增协议页面规划

### 3.1 完整页面列表（27个协议）

#### 高频页面 (13个)

| 序号 | 文件名 | 协议 | 状态 | 优先级 |
|:----:|:-------|:-----|:----:|:------:|
| 1 | hf_mf_page.dart | Mifare Classic | ✅ 已有 | - |
| 2 | hf_14a_page.dart | 14443-A | ✅ 已有 | - |
| 3 | hf_mfu_page.dart | Mifare Ultralight/NTAG | ✅ 已规划 | P0 |
| 4 | hf_mfdes_page.dart | Mifare DESFire | ✅ 已规划 | P1 |
| 5 | hf_iclass_page.dart | iCLASS/Picopass | ✅ 已规划 | P0 |
| 6 | hf_15_page.dart | ISO15693 | ✅ 已规划 | P1 |
| 7 | hf_14b_page.dart | 14443-B | 📋 待添加 | P1 |
| 8 | hf_felica_page.dart | FeliCa | 📋 待添加 | P2 |
| 9 | hf_legic_page.dart | Legic | 📋 待添加 | P2 |
| 10 | hf_seos_page.dart | SEOS | 📋 待添加 | P3 |
| 11 | hf_emv_page.dart | EMV | 📋 待添加 | P1 |
| 12 | hf_fido_page.dart | FIDO | 📋 待添加 | P3 |
| 13 | hf_sniff_page.dart | 通用嗅探 | 📋 待添加 | P2 |

#### 低频页面 (9个)

| 序号 | 文件名 | 协议 | 状态 | 优先级 |
|:----:|:-------|:-----|:----:|:------:|
| 1 | lf_em4x_page.dart | EM4x 系列 | ✅ 已有 | - |
| 2 | lf_t55xx_page.dart | T55xx | ✅ 已有 | - |
| 3 | lf_hid_page.dart | HID Prox | ✅ 已规划 | P1 |
| 4 | lf_awid_page.dart | AWID | 📋 待添加 | P2 |
| 5 | lf_indala_page.dart | Indala | 📋 待添加 | P2 |
| 6 | lf_hitag_page.dart | Hitag | 📋 待添加 | P1 |
| 7 | lf_io_page.dart | IO Prox | 📋 待添加 | P2 |
| 8 | lf_pyramid_page.dart | Pyramid | 📋 待添加 | P3 |
| 9 | lf_keri_page.dart | Keri | 📋 待添加 | P3 |
| 10 | lf_fdxb_page.dart | FDXB | 📋 待添加 | P3 |

#### 工具页面 (5个)

| 序号 | 文件名 | 功能 | 状态 | 优先级 |
|:----:|:-------|:-----|:----:|:------:|
| 1 | hw_page.dart | 硬件信息 | ✅ 已有 | - |
| 2 | data_page.dart | 数据分析 | 📋 待添加 | P2 |
| 3 | trace_page.dart | 跟踪分析 | 📋 待添加 | P2 |
| 4 | nfc_page.dart | NFC解码 | 📋 待添加 | P2 |
| 5 | script_page.dart | 脚本执行 | 📋 待添加 | P3 |

---

## 4. 导航结构重构

### 4.1 当前导航问题

当前侧边栏是扁平结构，仅有7个导航项。随着页面增加到27个，导航将变得拥挤且难以使用。

### 4.2 建议的新导航结构

采用**分组折叠菜单**设计：

```
📁 高频 (HF)
  ├── Mifare Classic
  ├── Mifare Ultralight
  ├── Mifare DESFire
  ├── iCLASS
  ├── ISO15693
  ├── 14443-A
  ├── 14443-B
  ├── FeliCa
  ├── Legic
  ├── SEOS
  ├── EMV
  └── FIDO

📁 低频 (LF)
  ├── EM4x
  ├── T55xx
  ├── HID Prox
  ├── AWID
  ├── Indala
  ├── Hitag
  ├── IO Prox
  ├── Pyramid
  ├── Keri
  └── FDXB

📁 工具
  ├── 连接
  ├── 终端
  ├── Dump查看
  ├── Dump对比
  ├── 数据分析
  ├── 跟踪分析
  ├── NFC解码
  └── 脚本执行

⚙️ 设置
```

### 4.3 home_page.dart 重构要点

```dart
// 1. 导入所有新页面
import 'package:pm3gui/ui/pages/hf_mfu_page.dart';
import 'package:pm3gui/ui/pages/hf_mfdes_page.dart';
import 'package:pm3gui/ui/pages/hf_iclass_page.dart';
import 'package:pm3gui/ui/pages/hf_15_page.dart';
import 'package:pm3gui/ui/pages/hf_14b_page.dart';
import 'package:pm3gui/ui/pages/hf_felica_page.dart';
import 'package:pm3gui/ui/pages/hf_legic_page.dart';
import 'package:pm3gui/ui/pages/hf_seos_page.dart';
import 'package:pm3gui/ui/pages/hf_emv_page.dart';
import 'package:pm3gui/ui/pages/hf_fido_page.dart';
import 'package:pm3gui/ui/pages/lf_hid_page.dart';
import 'package:pm3gui/ui/pages/lf_awid_page.dart';
import 'package:pm3gui/ui/pages/lf_indala_page.dart';
import 'package:pm3gui/ui/pages/lf_hitag_page.dart';
import 'package:pm3gui/ui/pages/lf_io_page.dart';
import 'package:pm3gui/ui/pages/lf_pyramid_page.dart';
import 'package:pm3gui/ui/pages/lf_keri_page.dart';
import 'package:pm3gui/ui/pages/lf_fdxb_page.dart';
import 'package:pm3gui/ui/pages/data_page.dart';
import 'package:pm3gui/ui/pages/trace_page.dart';
import 'package:pm3gui/ui/pages/nfc_page.dart';
import 'package:pm3gui/ui/pages/script_page.dart';

// 2. 使用分组导航项结构
class _NavGroup {
  final String title;
  final IconData icon;
  final List<_NavItem> items;
  final bool expanded;
  
  const _NavGroup({
    required this.title,
    required this.icon,
    required this.items,
    this.expanded = false,
  });
}

// 3. 页面列表
final _pages = const [
  // 基础页面
  ConnectionPage(),
  TerminalPage(),
  DumpViewerPage(),
  DumpComparePage(),
  // HF 页面
  MifarePage(),
  HfMfuPage(),
  HfMfdesPage(),
  HfIclassPage(),
  Hf15Page(),
  Hf14bPage(),
  HfFelicaPage(),
  HfLegicPage(),
  HfSeosPage(),
  HfEmvPage(),
  HfFidoPage(),
  // LF 页面
  LfPage(),
  LfHidPage(),
  LfAwidPage(),
  LfIndalaPage(),
  LfHitagPage(),
  LfIoPage(),
  LfPyramidPage(),
  LfKeriPage(),
  LfFdxbPage(),
  // 工具页面
  DataPage(),
  TracePage(),
  NfcPage(),
  ScriptPage(),
  SettingsPage(),
];
```

---

## 5. 组件库提取计划

### 5.1 公共组件列表

为减少代码重复，建议提取以下公共组件：

```
lib/ui/components/
├── action_button.dart          # 通用操作按钮
├── hex_input_field.dart        # 十六进制输入框
├── result_display.dart         # 结果显示区域
├── file_selector.dart          # 文件选择器
├── tab_page_scaffold.dart      # Tab页面脚手架
├── command_executor.dart       # 命令执行器
├── nav_group.dart              # 分组导航组件
├── connection_guard.dart       # 连接状态守卫
├── command_result_panel.dart   # 命令执行结果面板 ⭐新增
└── execution_log.dart          # 执行日志组件 ⭐新增
```

---

## 5.1.1 命令执行结果展示需求

### 需求说明

**所有操作按钮执行完毕后，必须显示PM3返回的命令执行结果**。让用户清楚地看到命令执行后的输出内容。

### 设计原则

1. **即时反馈**：用户执行操作后立即看到结果
2. **完整显示**：显示PM3返回的完整输出内容
3. **可读性**：格式化显示，便于阅读和分析
4. **可交互**：支持复制、清空、滚动查看等操作

### 显示方式

#### 方式一：内联结果面板（简单操作）

```
┌─────────────────────────────────────┐
│  [获取信息]  [转储卡片]               │
├─────────────────────────────────────┤
│ 执行: hf mfu info                   │
│ ─────────────────────────────────── │
│ [=]  类型: NTAG 216                 │
│ [=]  UID: 04:5A:12:3F:8A:1B:90      │
│ [=]  大小: 888 字节                 │
│ ...                                 │
├─────────────────────────────────────┤
│ [复制结果] [清空]                   │
└─────────────────────────────────────┘
```

#### 方式二：独立结果区域（复杂操作）

```
┌─────────────────────────────────────────────────────────────┐
│ Tab 1 - 信息操作                              Tab 2 - 读写 │
├─────────────────────────────────────────────────────────────┤
│ ┌──────────────────────┐  ┌──────────────────────────────┐ │
│ │ [获取信息]            │  │ 执行: hf mfu info            │ │
│ │ [转储卡片]            │  │ ──────────────────────────── │ │
│ │ [擦除卡片]            │  │ [=] 类型: NTAG 216           │ │
│ │                      │  │ [=] UID: 04:5A:12:3F:8A:1B:90│ │
│ │                      │  │ ...                          │ │
│ │                      │  │                              │ │
│ │                      │  │ [复制] [在终端打开] [清空]   │ │
│ └──────────────────────┘  └──────────────────────────────┘ │
│        操作区                      结果展示区               │
└─────────────────────────────────────────────────────────────┘
```

### 结果展示内容

1. **执行的命令**：显示实际执行的PM3命令
2. **执行状态**：成功/失败/超时
3. **返回结果**：PM3的完整输出内容
4. **执行时间**：命令执行耗时

### 实现要求

1. **自动滚动**：新内容自动滚动到底部
2. **语法高亮**：关键信息（UID、密钥等）高亮显示
3. **可复制**：支持复制全部或部分结果
4. **清空功能**：支持清空当前结果
5. **历史记录**：可选保存最近几次执行结果
6. **终端风格**：使用等宽字体，保持与PM3终端一致的风格

### 组件设计

```dart
/// 命令执行结果面板
class CommandResultPanel extends StatelessWidget {
  final String command;        // 执行的命令
  final String result;         // 返回结果
  final bool isLoading;        // 是否正在执行
  final Duration? duration;    // 执行耗时
  final VoidCallback? onCopy;  // 复制回调
  final VoidCallback? onClear; // 清空回调
  
  const CommandResultPanel({
    super.key,
    required this.command,
    required this.result,
    this.isLoading = false,
    this.duration,
    this.onCopy,
    this.onClear,
  });
}
```

### 5.2 组件详细设计

#### 5.2.1 TabPageScaffold

```dart
/// 统一的Tab页面脚手架
class TabPageScaffold extends StatefulWidget {
  final String title;
  final List<Tab> tabs;
  final List<Widget> tabViews;
  final List<Widget>? actions;
  
  const TabPageScaffold({
    super.key,
    required this.title,
    required this.tabs,
    required this.tabViews,
    this.actions,
  });
}
```

#### 5.2.2 CommandExecutor

```dart
/// 命令执行器，处理连接检查和执行状态
class CommandExecutor {
  static Future<void> execute(
    BuildContext context,
    String command, {
    VoidCallback? onSuccess,
    VoidCallback? onError,
  }) async {
    final appState = context.read<AppState>();
    if (!appState.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未连接 PM3')),
      );
      return;
    }
    // ... 执行命令
  }
}
```

#### 5.2.3 ResultDisplay（命令执行结果展示）

```dart
/// 命令执行结果展示组件
/// 显示PM3命令执行后的返回结果
class ResultDisplay extends StatelessWidget {
  final String command;        // 执行的命令
  final String result;         // 返回结果
  final bool isLoading;        // 是否正在执行
  final Duration? duration;    // 执行耗时
  final VoidCallback? onCopy;  // 复制回调
  final VoidCallback? onClear; // 清空回调
  
  const ResultDisplay({
    super.key,
    required this.command,
    required this.result,
    this.isLoading = false,
    this.duration,
    this.onCopy,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 命令头
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(Icons.terminal, size: 16, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '执行: $command',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (duration != null)
                  Text(
                    '${duration!.inMilliseconds}ms',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          
          // 结果内容
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: Text(
                        result.isEmpty ? '执行命令查看结果' : result,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ),
            ),
          ),
          
          // 操作按钮
          if (result.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: onCopy,
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('复制'),
                  ),
                  if (onClear != null)
                    TextButton.icon(
                      onPressed: onClear,
                      icon: const Icon(Icons.clear, size: 16),
                      label: const Text('清空'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
```

#### 5.2.4 CommandResultPanel（新增）

```dart
/// 命令执行结果面板
/// 独立的结果展示区域，用于复杂操作页面
class CommandResultPanel extends StatefulWidget {
  final List<CommandHistory> history;  // 执行历史
  final bool showHistory;              // 是否显示历史
  
  const CommandResultPanel({
    super.key,
    this.history = const [],
    this.showHistory = false,
  });

  @override
  State<CommandResultPanel> createState() => _CommandResultPanelState();
}

class _CommandResultPanelState extends State<CommandResultPanel> {
  int? _selectedHistoryIndex;
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 历史选择器（可选）
        if (widget.showHistory && widget.history.isNotEmpty)
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.history.length,
              itemBuilder: (context, index) {
                final item = widget.history[index];
                final isSelected = _selectedHistoryIndex == index;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(item.command.split(' ').last),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedHistoryIndex = selected ? index : null;
                      });
                    },
                  ),
                );
              },
            ),
          ),
        
        // 结果展示
        Expanded(
          child: ResultDisplay(
            command: _selectedCommand,
            result: _selectedResult,
            isLoading: _isLoading,
            duration: _duration,
            onCopy: () => _copyToClipboard(_selectedResult),
            onClear: () => setState(() => _clearResult()),
          ),
        ),
      ],
    );
  }
}

/// 命令执行历史记录
class CommandHistory {
  final String command;
  final String result;
  final DateTime timestamp;
  final Duration? duration;
  final bool success;
  
  CommandHistory({
    required this.command,
    required this.result,
    required this.timestamp,
    this.duration,
    this.success = true,
  });
}
```

---

## 6. 实施计划

### 6.1 分批实施策略

建议按优先级分三批实施：

#### 第一批 (P0-P1) - 核心功能
**目标**：覆盖最常用的协议，满足80%用户需求

| 页面 | 协议 | 预计工时 |
|:-----|:-----|:--------:|
| hf_mfu_page.dart | Mifare Ultralight/NTAG | 6.5h |
| hf_iclass_page.dart | iCLASS/Picopass | 5.5h |
| hf_15_page.dart | ISO15693 | 4h |
| hf_mfdes_page.dart | Mifare DESFire | 5.5h |
| hf_14b_page.dart | 14443-B | 4h |
| hf_emv_page.dart | EMV | 5h |
| lf_hid_page.dart | HID Prox | 4h |
| lf_hitag_page.dart | Hitag | 4h |
| data_page.dart | 数据分析 | 5h |
| trace_page.dart | 跟踪分析 | 4h |
| **小计** | | **47.5h** |

#### 第二批 (P2) - 常用功能
**目标**：覆盖常用但专业性较强的协议

| 页面 | 协议 | 预计工时 |
|:-----|:-----|:--------:|
| hf_felica_page.dart | FeliCa | 4h |
| hf_legic_page.dart | Legic | 4h |
| hf_sniff_page.dart | 通用嗅探 | 3h |
| lf_awid_page.dart | AWID | 3h |
| lf_indala_page.dart | Indala | 3h |
| lf_io_page.dart | IO Prox | 3h |
| lf_em4x05_page.dart | EM4x05/4x50/4x70 | 5h |
| nfc_page.dart | NFC解码 | 4h |
| **小计** | | **29h** |

#### 第三批 (P3) - 特殊功能
**目标**：覆盖特殊场景和小众协议

| 页面 | 协议 | 预计工时 |
|:-----|:-----|:--------:|
| hf_seos_page.dart | SEOS | 3h |
| hf_fido_page.dart | FIDO | 3h |
| lf_pyramid_page.dart | Pyramid | 2h |
| lf_keri_page.dart | Keri | 2h |
| lf_fdxb_page.dart | FDXB | 2h |
| script_page.dart | 脚本执行 | 4h |
| **小计** | | **16h** |

### 6.2 时间估算汇总

| 阶段 | 页面数 | 预估工时 |
|:-----|:------:|:--------:|
| Phase 1: 核心功能 | 11 | 47.5h |
| Phase 2: 常用功能 | 8 | 29h |
| Phase 3: 特殊功能 | 6 | 16h |
| Phase 4: 导航重构 | 1 | 8h |
| Phase 5: 组件提取 | 1 | 10h |
| Phase 6: 测试优化 | 1 | 15h |
| **总计** | **27** | **125.5h** |

### 6.3 依赖关系图

```
Phase 1: 组件提取
    │
    ├───> Phase 2: 核心页面 (并行开发)
    │         ├── hf_mfu_page.dart
    │         ├── hf_iclass_page.dart
    │         ├── hf_mfdes_page.dart
    │         ├── hf_15_page.dart
    │         ├── hf_14b_page.dart
    │         ├── hf_emv_page.dart
    │         ├── lf_hid_page.dart
    │         ├── lf_hitag_page.dart
    │         ├── data_page.dart
    │         └── trace_page.dart
    │
    ├───> Phase 3: 常用页面 (并行开发)
    │         ├── hf_felica_page.dart
    │         ├── hf_legic_page.dart
    │         ├── hf_sniff_page.dart
    │         ├── lf_awid_page.dart
    │         ├── lf_indala_page.dart
    │         ├── lf_io_page.dart
    │         ├── lf_em4x05_page.dart
    │         └── nfc_page.dart
    │
    ├───> Phase 4: 特殊页面 (并行开发)
    │         ├── hf_seos_page.dart
    │         ├── hf_fido_page.dart
    │         ├── lf_pyramid_page.dart
    │         ├── lf_keri_page.dart
    │         ├── lf_fdxb_page.dart
    │         └── script_page.dart
    │
    ├───> Phase 5: 导航重构
    │         └── home_page.dart 分组导航
    │
    └───> Phase 6: 测试优化
              ├── 单元测试
              ├── 集成测试
              └── 代码优化
```

---

## 7. 代码规范

### 7.1 统一页面模板

所有新页面遵循统一的代码结构：

```dart
/// [Protocol] 操作页面
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/services/pm3_commands.dart';
import 'package:pm3gui/ui/theme.dart';

class [Protocol]Page extends StatefulWidget {
  const [Protocol]Page({super.key});

  @override
  State<[Protocol]Page> createState() => _[Protocol]PageState();
}

class _[Protocol]PageState extends State<[Protocol]Page>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // 状态变量
  String _result = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: N, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _execute(String cmd) {
    final appState = context.read<AppState>();
    if (!appState.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未连接 PM3')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
      _result = '';
    });
    
    appState.sendCommand(cmd).then((_) {
      setState(() {
        _isLoading = false;
        _result = appState.terminalOutput.last;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '标签1'),
            Tab(text: '标签2'),
            // ...
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildTab1(),
              _buildTab2(),
              // ...
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultDisplay() {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: Text(
                    _result.isEmpty ? '执行命令查看结果' : _result,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
```

### 7.2 UI/UX 设计规范

采用 Enterprise CRM Slate 蓝灰色系：

| 色彩 | 色值 | 用途 |
|:----:|:----:|------|
| 深蓝黑 | `#0F172A` | 深色背景、主标题 |
| 亮蓝色 | `#3B82F6` | 主色调、选中状态、按钮、链接 |
| 石板灰 | `#64748B` | 次要文字、边框、图标 |
| 浅灰蓝 | `#E2E8F0` | 浅色背景、分隔线、卡片背景 |
| 纯白 | `#FFFFFF` | 白色背景、深色背景上的文字 |

**语义化颜色映射：**

| 用途 | 深色模式 | 浅色模式 |
|:-----|:--------:|:--------:|
| 主色调 | `#3B82F6` | `#3B82F6` |
| 背景色 | `#0F172A` | `#FFFFFF` |
| 卡片/表面 | `#1E293B` | `#F1F5F9` |
| 主要文字 | `#FFFFFF` | `#0F172A` |
| 次要文字 | `#94A3B8` | `#64748B` |
| 边框/分隔 | `#334155` | `#E2E8F0` |
| 成功状态 | `#10B981` | `#059669` |
| 警告状态 | `#F59E0B` | `#D97706` |
| 错误状态 | `#EF4444` | `#DC2626` |
| HF 标识 | `#3B82F6` | `#3B82F6` |
| LF 标识 | `#8B5CF6` | `#7C3AED` |

### 7.3 命名规范

- **文件名**: `hf_[protocol]_page.dart` / `lf_[protocol]_page.dart`
- **类名**: `Hf[Protocol]Page` / `Lf[Protocol]Page`
- **命令类**: `Hf[Protocol]Cmd` / `Lf[Protocol]Cmd`

---

## 8. 测试策略

### 8.1 单元测试

- 每个页面独立测试
- 测试所有按钮触发正确的命令
- 测试输入验证（hex格式、长度检查）
- 测试结果显示和复制功能
- 测试未连接设备时的提示

### 8.2 集成测试

- 页面间导航和状态共享
- 侧边栏导航正确切换页面
- 主题切换正常
- 与现有页面无冲突
- 应用启动和运行性能

### 8.3 命令测试

- 验证所有命令正确发送
- 验证命令参数格式正确
- 验证命令响应解析正确

---

## 9. 风险与缓解

| 风险 | 可能性 | 影响 | 缓解措施 |
|:-----|:------:|:----:|:---------|
| 命令参数不匹配 | 中 | 高 | 参考pm3_commands.yaml和实际CLI测试 |
| 页面过多导致导航拥挤 | 高 | 中 | 采用分组折叠菜单设计 |
| 状态管理复杂化 | 低 | 中 | 保持每个页面独立状态，不增加全局状态 |
| 编译问题 | 低 | 高 | 每次修改后及时运行flutter analyze |
| 代码重复 | 高 | 中 | 提取公共组件库 |

---

## 10. 文档清单

### 10.1 已生成文档

- ✅ `complete_coverage_plan.md` - 完整覆盖率提升计划
- ✅ `spec_new_features.md` - 新功能规格说明
- ✅ `tasks_new_features.md` - 新功能任务分解
- ✅ `refactoring_plan.md` - 重构计划（本文档）

### 10.2 待生成文档

- 📋 `component_library.md` - 组件库文档
- 📋 `testing_guide.md` - 测试指南
- 📋 `page_development_guide.md` - 页面开发指南

---

## 11. 下一步行动

1. **立即行动**
   - [ ] 评审本重构计划
   - [ ] 确认优先级和实施顺序
   - [ ] 创建开发分支

2. **第一阶段（组件提取）**
   - [ ] 创建 `lib/ui/components/` 目录
   - [ ] 提取 `TabPageScaffold` 组件
   - [ ] 提取 `CommandExecutor` 组件
   - [ ] 提取 `ResultDisplay` 组件

3. **第二阶段（核心页面）**
   - [ ] 实现 Mifare Ultralight/NTAG 页面
   - [ ] 实现 iCLASS/Picopass 页面
   - [ ] 实现 ISO15693 页面
   - [ ] 实现 Mifare DESFire 页面

4. **第三阶段（导航重构）**
   - [ ] 设计分组导航组件
   - [ ] 重构 home_page.dart
   - [ ] 添加页面展开/折叠功能

5. **第四阶段（测试优化）**
   - [ ] 编写单元测试
   - [ ] 编写集成测试
   - [ ] 性能优化

---

## 12. 总结

通过本重构计划的实施，PM3GUI将实现：

- **100% 协议覆盖** - 所有27个协议族都有GUI支持
- **统一用户体验** - 所有页面遵循相同的设计模式
- **零维护成本** - 命令兼容性自动继承自PM3客户端
- **可扩展架构** - 易于添加新的协议支持
- **代码复用** - 通过组件库减少重复代码

预计总工时：**125.5小时**（约16个工作日）
