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
    // S15-3：placeholder 双向引导——直接输入 / 点左侧「指令」按钮开面板。
    // 保留「输入指令」前缀（batch10_60:69 textContaining 断言依赖）。
    this.hintText = '输入指令，或点左侧「指令」浏览全部 47 条面板',
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
            // S15-3：入口从孤图标改为「图标 + 文字」按钮——用户反馈「把指令
            // 做成按钮」，孤图标发现性差（面板上线后仍有人以为只能打字）。
            // 图标保留 Icons.terminal_outlined：batch13_s12_9 的 4 处
            // byIcon 断言依赖它，文字只是叠加，不改交互。
            TextButton.icon(
              onPressed: onOpenCommands,
              icon: const Icon(
                Icons.terminal_outlined,
                color: WesterosColors.goldBright,
              ),
              label: const Text(
                '指令',
                style: TextStyle(color: WesterosColors.goldBright),
              ),
              // 文字本身已自解释，不需要 Tooltip（TextButton 也无此参数，
              // S15-3 首推 CI 红 1 例即此处编译错误：undefined_named_parameter）。
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
