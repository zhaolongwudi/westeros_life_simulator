/// 主界面快捷指令栏 widget（Batch 10-29 · M3b 从 game_screen 拆出）。
library;

import 'package:flutter/material.dart';

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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: commands.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (context, index) {
            final cmd = commands[index];
            return ActionChip(
              label: Text(cmd.label),
              onPressed: () => onTap(cmd.command),
            );
          },
        ),
      ),
    );
  }
}
