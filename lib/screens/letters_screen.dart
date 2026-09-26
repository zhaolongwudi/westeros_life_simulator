/// 信件面板：展示收到的信件与回信。
///
/// 复用 GameEngine.letters（Batch 4 mixin_letter）数据。
/// 纯展示 + 回信入口（调用 replyLetter）。
library;

import 'package:flutter/material.dart';

import '../game_engine.dart';
import '../mixins/mixin_letter.dart';

/// 信件面板。
class LettersScreen extends StatefulWidget {
  const LettersScreen({super.key, this.engine});

  /// 可选：传入共享引擎（默认新建）。
  final GameEngine? engine;

  @override
  State<LettersScreen> createState() => _LettersScreenState();
}

class _LettersScreenState extends State<LettersScreen> {
  late final GameEngine _engine = widget.engine ?? (GameEngine()..startNewGame());
  final TextEditingController _replyController = TextEditingController();

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  /// 回信（回复最新一封待回信）。
  void _reply() {
    final text = _engine.replyLetter(replyText: _replyController.text);
    _replyController.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text.isEmpty ? '没有待回的信。' : text)),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final letters = _engine.letters;
    final pending = letters.where((l) => l.isFromNpc && !l.replied).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('信件')),
      body: Column(
        children: <Widget>[
          // 回信输入区（有待回信时显示）
          if (pending.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '待回信：${pending.length} 封（最近：${pending.first.senderName}）',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: _replyController,
                          decoration: const InputDecoration(
                            hintText: '输入回信内容（留空用默认）',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        icon: const Icon(Icons.send),
                        tooltip: '回信',
                        onPressed: _reply,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          const Divider(height: 1),
          // 信件列表
          Expanded(
            child: letters.isEmpty
                ? const Center(child: Text('你的渡鸦还没有带回任何信件。'))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: letters.length,
                    itemBuilder: (context, index) {
                      // 倒序（最新在上）
                      final letter = letters[letters.length - 1 - index];
                      return _LetterCard(letter: letter);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// 单封信件卡片。
class _LetterCard extends StatelessWidget {
  const _LetterCard({required this.letter});

  final Letter letter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNpc = letter.isFromNpc;
    final tag = !isNpc
        ? '✉️ 回信'
        : (letter.replied ? '📖 已回' : '📩 待回');
    final color = isNpc
        ? (letter.replied
            ? theme.colorScheme.surfaceContainerHigh
            : theme.colorScheme.primaryContainer)
        : theme.colorScheme.secondaryContainer;

    return Card(
      color: color,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${letter.senderName}（${letter.year}年${letter.month}月）',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Text(tag, style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 6),
            Text(letter.content, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}