/// 主界面指令输入栏 widget（Batch 10-29 · M3b 从 game_screen 拆出）。
///
/// Batch 10-60 UI 重造：羊皮纸输入框 + 金色发送按钮。
library;

import 'package:flutter/material.dart';

import '../../theme/westeros_theme.dart';

/// 指令输入栏。
class CommandInputBar extends StatelessWidget {
  const CommandInputBar({
    required this.controller,
    required this.onSubmitted,
    this.hintText = '输入指令（如 工作 / 训练 sword / 过月）',
    this.onOpenCommands,
    this.focusNode,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final String hintText;

  /// 打开「指令」面板（S12-9）。为 null 时不显示该按钮。
  final VoidCallback? onOpenCommands;

  /// 输入框焦点（S12-9：面板预填命令后自动聚焦）。
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
      decoration: BoxDecoration(
        color: WesterosColors.barkBase,
        border: Border(
          top: BorderSide(
            color: WesterosColors.outlineGold.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          if (onOpenCommands != null) ...<Widget>[
            IconButton(
              icon: const Icon(Icons.terminal_outlined),
              tooltip: '指令（全部 47 条）',
              color: WesterosColors.goldBright,
              onPressed: onOpenCommands,
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                hintText: hintText,
                prefixIcon: const Icon(
                  Icons.edit_note_outlined,
                  size: 18,
                  color: WesterosColors.inkDim,
                ),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: onSubmitted,
              style: const TextStyle(color: WesterosColors.parchment),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            icon: const Icon(Icons.send),
            tooltip: '发送',
            style: IconButton.styleFrom(
              backgroundColor: WesterosColors.gold,
              foregroundColor: WesterosColors.barkDeep,
            ),
            onPressed: () => onSubmitted(controller.text),
          ),
        ],
      ),
    );
  }
}
