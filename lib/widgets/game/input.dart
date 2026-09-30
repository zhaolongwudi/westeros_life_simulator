/// 主界面指令输入栏 widget（Batch 10-29 · M3b 从 game_screen 拆出）。
library;

import 'package:flutter/material.dart';

/// 指令输入栏。
class CommandInputBar extends StatelessWidget {
  const CommandInputBar({
    required this.controller,
    required this.onSubmitted,
    this.hintText = '输入指令（如 工作 / 训练 sword / 过月）',
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: hintText,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: onSubmitted,
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            icon: const Icon(Icons.send),
            tooltip: '发送',
            onPressed: () => onSubmitted(controller.text),
          ),
        ],
      ),
    );
  }
}
