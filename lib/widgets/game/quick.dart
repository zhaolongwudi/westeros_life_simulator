/// 主界面快捷指令栏 widget（Batch 10-29 · M3b 从 game_screen 拆出）。
///
/// Batch 10-60 UI 重造：金色描边 chip + 底部金线。
library;

import 'package:flutter/material.dart';

import '../../theme/westeros_theme.dart';

/// 快捷指令按钮配置。
class QuickCommand {
  const QuickCommand(this.label, this.command);

  final String label;
  final String command;
}

/// 快捷指令栏。
class QuickCommandBar extends StatelessWidget {
  const QuickCommandBar({required this.commands, required this.onTap});

  final List<QuickCommand> commands;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: WesterosColors.barkBase,
        border: Border(
          bottom: BorderSide(
            color: WesterosColors.outlineGold.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: commands.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (context, index) {
            final cmd = commands[index];
            return ActionChip(
              label: Text(cmd.label),
              backgroundColor: WesterosColors.barkMid,
              side: BorderSide(
                color: WesterosColors.outlineGold.withValues(alpha: 0.7),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              labelStyle: const TextStyle(
                color: WesterosColors.parchment,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              onPressed: () => onTap(cmd.command),
            );
          },
        ),
      ),
    );
  }
}
