/// 主界面 AI 行动模式开关 widget（Batch 10-29 · M3b 从 game_screen 拆出）。
library;

import 'package:flutter/material.dart';

/// AI 模式开关条。
class AiModeToggle extends StatelessWidget {
  const AiModeToggle({
    required this.aiMode,
    required this.aiLoading,
    required this.onToggle,
  });

  final bool aiMode;
  final bool aiLoading;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      color: aiMode
          ? theme.colorScheme.primaryContainer.withAlpha(120)
          : null,
      child: Row(
        children: <Widget>[
          Icon(
            Icons.auto_awesome,
            size: 16,
            color: aiMode ? theme.colorScheme.primary : theme.colorScheme.outline,
          ),
          const SizedBox(width: 8),
          const Text('AI 行动模式'),
          const Spacer(),
          if (aiLoading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Switch(
              value: aiMode,
              onChanged: onToggle,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
        ],
      ),
    );
  }
}
