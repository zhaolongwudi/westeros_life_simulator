/// 主界面 AI 行动模式开关 widget（Batch 10-29 · M3b 从 game_screen 拆出）。
///
/// Batch 10-60 UI 重造：龙火主题开关条。
library;

import 'package:flutter/material.dart';

import '../../theme/westeros_theme.dart';

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
      decoration: BoxDecoration(
        color: aiMode
            ? WesterosColors.bloodRed.withValues(alpha: 0.18)
            : null,
        border: Border(
          bottom: BorderSide(
            color: aiMode
                ? WesterosColors.bloodRed.withValues(alpha: 0.5)
                : WesterosColors.outlineGold.withValues(alpha: 0.35),
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.local_fire_department_outlined,
            size: 18,
            color: aiMode
                ? WesterosColors.bloodRed.withValues(alpha: 0.9)
                : theme.colorScheme.outline,
          ),
          const SizedBox(width: 8),
          Text(
            'AI 行动模式',
            style: theme.textTheme.labelLarge?.copyWith(
              color: aiMode ? WesterosColors.goldBright : null,
              fontWeight: aiMode ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (aiMode) ...[
            const SizedBox(width: 6),
            Text(
              '（描述你的行动）',
              style: theme.textTheme.labelSmall?.copyWith(
                color: WesterosColors.inkDim,
              ),
            ),
          ],
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
