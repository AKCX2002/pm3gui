/// Reusable command-result display panel.
///
/// Shows the executed PM3 command, its output, elapsed time,
/// and copy / clear actions.  Uses monospace font to match
/// the native PM3 terminal style.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ResultDisplay extends StatelessWidget {
  final String command;
  final String result;
  final bool isLoading;
  final Duration? duration;
  final VoidCallback? onCopy;
  final VoidCallback? onClear;

  const ResultDisplay({
    super.key,
    this.command = '',
    this.result = '',
    this.isLoading = false,
    this.duration,
    this.onCopy,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Command header ──
          if (command.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Icon(Icons.terminal,
                      size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '执行: $command',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (duration != null)
                    Text(
                      '${duration!.inMilliseconds}ms',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),

          // ── Result body ──
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SelectionArea(
                      child: SingleChildScrollView(
                        child: Text(
                          result.isEmpty ? '执行命令查看结果' : result,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            height: 1.5,
                            color: result.isEmpty
                                ? Colors.grey[600]
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
            ),
          ),

          // ── Action buttons ──
          if (result.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: onCopy ??
                        () {
                          Clipboard.setData(ClipboardData(text: result));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已复制到剪贴板')),
                          );
                        },
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
