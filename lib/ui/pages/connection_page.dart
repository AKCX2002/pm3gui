/// Connection & Dashboard page — PM3 connection, device info, file browser.
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/services/pm3_process.dart';
import 'package:pm3gui/services/file_collector.dart';
import 'package:pm3gui/ui/theme.dart';

class ConnectionPage extends StatefulWidget {
  const ConnectionPage({super.key});

  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<ConnectionPage> {
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _scanPorts();
    // Initial file scan
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().scanForFiles();
    });
  }

  Future<void> _scanPorts() async {
    setState(() => _scanning = true);
    final appState = context.read<AppState>();

    try {
      final ports = <String>[];

      if (Platform.isLinux) {
        final devDir = Directory('/dev');
        if (devDir.existsSync()) {
          for (final entity in devDir.listSync()) {
            final name = entity.path;
            if (name.contains('ttyACM') || name.contains('ttyUSB')) {
              ports.add(name);
            }
          }
        }
      } else if (Platform.isWindows) {
        for (var i = 1; i <= 20; i++) {
          ports.add('COM$i');
        }
      }

      ports.sort();
      appState.availablePorts = ports;
      if (ports.isNotEmpty && appState.portName.isEmpty) {
        appState.setPort(ports.first);
      }
    } catch (e) {
      // Ignore scan errors
    }

    setState(() => _scanning = false);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    final isConnected = context.select<AppState, bool>(
        (s) => s.connectionState.connectionState == Pm3State.connected);
    final isConnecting = context.select<AppState, bool>(
        (s) => s.connectionState.connectionState == Pm3State.connecting);
    final pm3Path = context.select<AppState, String>((s) => s.pm3Path);
    final availablePorts =
        context.select<AppState, List<String>>((s) => s.availablePorts);
    final portName = context.select<AppState, String>((s) => s.portName);
    final pm3Version = context.select<AppState, String>((s) => s.pm3Version);
    final lastError = context.select<AppState, String>((s) => s.lastError);
    final hwInfoParsed = context.select<AppState, bool>((s) => s.hwInfoParsed);
    final hwModel = context.select<AppState, String>((s) => s.hwModel);
    final hwMcu = context.select<AppState, String>((s) => s.hwMcu);
    final hwFlashSize = context.select<AppState, String>((s) => s.hwFlashSize);
    final hwFirmware = context.select<AppState, String>((s) => s.hwFirmware);
    final hwBootrom = context.select<AppState, String>((s) => s.hwBootrom);
    final hwFpga = context.select<AppState, String>((s) => s.hwFpga);
    final hwSmartcard = context.select<AppState, String>((s) => s.hwSmartcard);
    final hwUniqueId = context.select<AppState, String>((s) => s.hwUniqueId);
    final hwFlashTotal = context.select<AppState, int>((s) => s.hwFlashTotal);
    final commandHistoryLength =
        context.select<AppState, int>((s) => s.commandHistory.length);
    final terminalOutputLength =
        context.select<AppState, int>((s) => s.terminalOutput.length);
    final collectedFilesCount =
        context.select<AppState, int>((s) => s.collectedFiles.length);
    final cardGroupsCount =
        context.select<AppState, int>((s) => s.cardGroups.length);
    final isFileScanning = context.select<AppState, bool>((s) => s.isScanning);
    final hasCollectedFiles =
        context.select<AppState, bool>((s) => s.collectedFiles.isNotEmpty);
    final cardGroups =
        context.select<AppState, List<CardGroup>>((s) => s.cardGroups);
    final theme = Theme.of(context);

    return Row(
      children: [
        // ═══════ 左栏: 连接 & 设备信息 ═══════
        SizedBox(
          width: 360,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 连接状态头 ──
                _buildConnectionHeader(appState, isConnected, theme),
                const SizedBox(height: 16),

                // ── PM3 路径 ──
                _buildSection(
                  icon: Icons.folder_open,
                  title: 'PM3 程序路径',
                  child: TextFormField(
                    initialValue: pm3Path,
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 13),
                    decoration: InputDecoration(
                      hintText: './pm3 或 /usr/bin/proxmark3',
                      prefixIcon: const Icon(Icons.terminal, size: 18),
                      suffixIcon: File(pm3Path).existsSync()
                          ? Icon(Icons.check_circle,
                              size: 18, color: AppTheme.accentBlue)
                          : Icon(Icons.warning,
                              size: 18, color: const Color(0xFFF87171)),
                    ),
                    onChanged: appState.setPm3Path,
                  ),
                ),
                const SizedBox(height: 12),

                // ── 串口选择 ──
                _buildSection(
                  icon: Icons.usb,
                  title: '串口选择',
                  trailing: IconButton(
                    icon: _scanning
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh, size: 18),
                    onPressed: _scanning ? null : _scanPorts,
                    tooltip: '刷新端口',
                    visualDensity: VisualDensity.compact,
                  ),
                  child: availablePorts.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFF87171).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(children: [
                            Icon(Icons.info_outline,
                                size: 16, color: const Color(0xFFF87171)),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text('未找到串口，请连接 PM3 设备',
                                  style: TextStyle(fontSize: 13)),
                            ),
                          ]),
                        )
                      : DropdownButtonFormField<String>(
                          initialValue: availablePorts.contains(portName)
                              ? portName
                              : null,
                          items: availablePorts
                              .map((p) =>
                                  DropdownMenuItem(value: p, child: Text(p)))
                              .toList(),
                          onChanged: isConnected
                              ? null
                              : (v) {
                                  if (v != null) appState.setPort(v);
                                },
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.usb, size: 18),
                          ),
                        ),
                ),
                const SizedBox(height: 16),

                // ── 连接按钮 ──
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: isConnecting
                        ? null
                        : () async {
                            if (isConnected) {
                              await appState.disconnect();
                            } else {
                              await appState.connect();
                            }
                          },
                    icon: isConnecting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Icon(isConnected ? Icons.link_off : Icons.link,
                            size: 18),
                    label: Text(
                      isConnecting
                          ? '连接中...'
                          : isConnected
                              ? '断开连接'
                              : '连接 PM3',
                      style: const TextStyle(fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isConnected ? AppTheme.accentBlue : null,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── 错误信息 ──
                if (!isConnected && lastError.isNotEmpty)
                  _buildErrorCard(lastError),

                // ── 设备信息（已连接时） ──
                if (isConnected) ...[
                  const SizedBox(height: 12),
                  _buildSection(
                    icon: Icons.developer_board,
                    title: '设备信息',
                    trailing: IconButton(
                      icon: const Icon(Icons.refresh, size: 16),
                      tooltip: '刷新硬件信息',
                      onPressed: () => appState.refreshHwInfo(),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _infoRow('端口', portName),
                        _infoRow('版本', pm3Version),
                        _infoRow('状态', '已连接', valueColor: AppTheme.accentBlue),
                        if (hwInfoParsed) ...[
                          const Divider(height: 16),
                          if (hwModel.isNotEmpty) _infoRow('设备型号', hwModel),
                          if (hwMcu.isNotEmpty) _infoRow('MCU', hwMcu),
                          if (hwFlashSize.isNotEmpty)
                            _infoRow('Flash', hwFlashSize),
                          if (hwFirmware.isNotEmpty) _infoRow('固件', hwFirmware),
                          if (hwBootrom.isNotEmpty)
                            _infoRow('Bootrom', hwBootrom),
                          if (hwFpga.isNotEmpty) _infoRow('FPGA', hwFpga),
                          if (hwSmartcard.isNotEmpty)
                            _infoRow('智能卡模块', hwSmartcard),
                          if (hwUniqueId.isNotEmpty)
                            _infoRow('设备 ID', hwUniqueId),
                          if (hwFlashTotal > 0) _buildFlashUsage(appState),
                        ] else ...[
                          const Divider(height: 16),
                          Row(children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 8),
                            Text('正在获取硬件信息...',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[500])),
                          ]),
                        ],
                        const Divider(height: 16),
                        _infoRow('命令历史', '$commandHistoryLength 条'),
                        _infoRow('终端缓冲', '$terminalOutputLength 行'),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  appState.sendCommand('hw version'),
                              icon: const Icon(Icons.info, size: 14),
                              label: const Text('硬件版本',
                                  style: TextStyle(fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => appState.sendCommand('hw tune'),
                              icon: const Icon(Icons.wifi_tethering, size: 14),
                              label: const Text('天线调谐',
                                  style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 6),
                        Row(children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  appState.sendCommand('hw status'),
                              icon: const Icon(Icons.monitor_heart, size: 14),
                              label: const Text('硬件状态',
                                  style: TextStyle(fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  appState.sendCommand('hw dbg -4'),
                              icon: const Icon(Icons.bug_report, size: 14),
                              label: const Text('调试级别',
                                  style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ],

                // ── 平台信息 ──
                const SizedBox(height: 16),
                _buildSection(
                  icon: Icons.computer,
                  title: '环境信息',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoRow('平台', Platform.operatingSystem),
                      _infoRow('架构', _getArch()),
                      _infoRow('Dart', Platform.version.split(' ').first),
                      _infoRow('PM3 路径',
                          File(pm3Path).existsSync() ? '✅ 有效' : '❌ 无效'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        VerticalDivider(width: 1, color: theme.dividerColor),

        // ═══════ 右栏: 文件收集 & 概览 ═══════
        Expanded(
          child: Column(
            children: [
              // 文件收集工具栏
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(children: [
                  Icon(Icons.folder_special,
                      size: 20, color: AppTheme.accentBlue),
                  const SizedBox(width: 8),
                  const Text('PM3 文件收集',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(width: 8),
                  Text(
                    '$collectedFilesCount 个文件, '
                    '$cardGroupsCount 张卡',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  const Spacer(),
                  if (isFileScanning)
                    const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed:
                        isFileScanning ? null : () => appState.scanForFiles(),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('扫描', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: !hasCollectedFiles
                        ? null
                        : () => _showOrganizeDialog(appState),
                    icon: const Icon(Icons.create_new_folder, size: 16),
                    label: const Text('归类整理', style: TextStyle(fontSize: 12)),
                  ),
                ]),
              ),
              const Divider(height: 1),

              // 文件列表（按卡片分组）
              Expanded(
                child: cardGroups.isEmpty
                    ? Center(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.search_off,
                              size: 48,
                              color: Colors.grey.withValues(alpha: 0.3)),
                          const SizedBox(height: 12),
                          Text('未发现 PM3 导出文件',
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 14)),
                          const SizedBox(height: 4),
                          Text('连接设备并执行 dump/autopwn 后自动收集',
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 12)),
                        ]),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: cardGroups.length,
                        itemBuilder: (context, i) =>
                            _buildCardGroupTile(cardGroups[i], theme),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Connection header ──────────────────────────────────────────────────

  Widget _buildConnectionHeader(
      AppState appState, bool isConnected, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isConnected
              ? [
                  AppTheme.accentBlue.withValues(alpha: 0.15),
                  AppTheme.accentBlue.withValues(alpha: 0.08),
                ]
              : [
                  AppTheme.auxiliaryGrey.withValues(alpha: 0.1),
                  Colors.transparent,
                ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConnected
              ? AppTheme.accentBlue.withValues(alpha: 0.3)
              : theme.dividerColor,
        ),
      ),
      child: Row(children: [
        // Status icon
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isConnected
                ? AppTheme.accentBlue.withValues(alpha: 0.2)
                : AppTheme.auxiliaryGrey.withValues(alpha: 0.15),
          ),
          child: Icon(
            isConnected ? Icons.nfc : Icons.usb_off,
            color: isConnected ? AppTheme.accentBlue : Colors.grey,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isConnected ? 'PM3 已连接' : 'PM3 未连接',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 2),
              Text(
                isConnected
                    ? '${appState.portName}  •  ${appState.pm3Version}'
                    : '请选择串口并连接设备',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  // ── Reusable section card ──────────────────────────────────────────────

  Widget _buildSection({
    required IconData icon,
    required String title,
    Widget? trailing,
    required Widget child,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 18, color: AppTheme.accentBlue),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold)),
              if (trailing != null) ...[const Spacer(), trailing],
            ]),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  // ── Error card ─────────────────────────────────────────────────────────

  Widget _buildErrorCard(String error) {
    return Card(
      color: const Color(0xFFF87171).withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: const Color(0xFFF87171), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('连接失败',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFF87171),
                          fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(error,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Card group tile ────────────────────────────────────────────────────

  Widget _buildCardGroupTile(CardGroup group, ThemeData theme) {
    final bandColor =
        group.band == FreqBand.hf ? AppTheme.accentBlue : AppTheme.accentBlue;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ExpansionTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: bandColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            group.band == FreqBand.hf ? Icons.nfc : Icons.radio,
            color: bandColor,
            size: 20,
          ),
        ),
        title: Text(group.label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(
          '${group.dumpCount} 份转储  •  ${group.keyCount} 份密钥  •  '
          '${group.files.length} 个文件',
          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
        ),
        children: [
          for (final f in group.files)
            ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              leading: Icon(
                f.fileType == CardFileType.dump
                    ? Icons.sd_storage
                    : f.fileType == CardFileType.key
                        ? Icons.vpn_key
                        : Icons.insert_drive_file,
                size: 16,
                color: f.fileType == CardFileType.dump
                    ? AppTheme.accentBlue
                    : AppTheme.accentBlue,
              ),
              title: Text(f.fileName,
                  style:
                      const TextStyle(fontFamily: 'monospace', fontSize: 12)),
              subtitle: Text(
                '${_formatBytes(f.sizeBytes)}  •  '
                '${_formatTime(f.modified)}  •  ${f.format}',
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.folder_open, size: 16),
                    tooltip: '在 Dump 查看器中打开',
                    onPressed: () {
                      context.read<AppState>().requestOpenDumpInViewer(f.path);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('已切换到 Dump 查看器: ${f.fileName}')),
                      );
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Organize dialog ────────────────────────────────────────────────────

  void _showOrganizeDialog(AppState appState) {
    final controller = TextEditingController(
      text: appState.collectBaseDir ?? '${Directory.current.path}/pm3_files',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('归类整理 PM3 文件'),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text(
              '将收集到的 PM3 导出文件按卡片 UID 分类整理到子目录中。\n\n'
              '目录结构：\n'
              '  📁 hf-mf/A991A280/\n'
              '    ├── hf-mf-A991A280-dump.bin\n'
              '    ├── hf-mf-A991A280-key.bin\n'
              '    └── ...\n',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: '目标目录',
                prefixIcon: Icon(Icons.folder, size: 18),
              ),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              '共 ${appState.collectedFiles.length} 个文件将被整理',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final count =
                  await appState.organizeCollectedFiles(controller.text);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已整理 $count 个文件')),
                );
              }
            },
            child: const Text('开始整理'),
          ),
        ],
      ),
    );
    // controller will be disposed when dialog closes (TextField is StatefulWidget)
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          ),
          Expanded(
            child: SelectableText(value,
                style: TextStyle(
                    fontFamily: 'monospace', fontSize: 12, color: valueColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildFlashUsage(AppState appState) {
    final free = appState.hwFlashFree;
    final total = appState.hwFlashTotal;
    final used = total - free;
    final usedPct = total > 0 ? used / total : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            SizedBox(
              width: 80,
              child: Text('Flash 用量',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            ),
            Expanded(
              child: Text(
                '${_formatBytes(used)} / ${_formatBytes(total)} '
                '(${(usedPct * 100).toStringAsFixed(1)}%)',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: usedPct,
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
              color: usedPct > 0.9
                  ? const Color(0xFFF87171)
                  : usedPct > 0.7
                      ? const Color(0xFFF87171)
                      : AppTheme.accentBlue,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  static String _formatTime(DateTime dt) {
    return '${dt.month}/${dt.day} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  static String _getArch() {
    try {
      final r = Process.runSync('uname', ['-m']);
      if (r.exitCode == 0) return (r.stdout as String).trim();
    } catch (_) {}
    return 'unknown';
  }
}
