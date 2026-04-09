/// Reusable action-card widget (icon + title + subtitle + tap handler).
///
/// Used across all protocol pages for quick-action lists.
library;

import 'package:flutter/material.dart';

class ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  const ActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon,
            color: enabled ? theme.colorScheme.primary : theme.disabledColor),
        title: Text(title),
        subtitle: Text(subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey[400])),
        trailing: const Icon(Icons.play_arrow),
        onTap: enabled ? onTap : null,
      ),
    );
  }
}
