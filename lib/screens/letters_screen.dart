/// 信件面板：展示收到的信件与回信。
///
/// 复用 GameEngine.letters（Batch 4 mixin_letter）数据。
/// 纯展示 + 回信入口（调用 replyLetter）。
///
/// Batch 10-29 · M3b：Letter 数据类已迁至 models/letter.dart，
/// 本文件不再 import mixin_letter（UI 层不依赖混入层）。
library;

import 'package:flutter/material.dart';

import '../game_engine.dart';
import '../models/letter.dart';
import '../theme/westeros_theme.dart';
import '../widgets/theme/ornate.dart';

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
      body: ParchmentBackground(
        child: Column(
          children: <Widget>[
            // 回信输入区（有待回信时显示）
            if (pending.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: WesterosColors.barkMid,
                  border: Border(
                    bottom: BorderSide(
                      color: WesterosColors.outlineGold.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Icon(
                          Icons.mail_outlined,
                          size: 18,
                          color: WesterosColors.goldBright,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          // S13-11 ⑯：`pending` 取自 `letters`（追加顺序），
                          // `pending.last` 才是「最近」的那封——与
                          // `replyLetter` 现在回复的对象、以及下方倒序列表
                          // 顶部的信件三者一致。
                          '待回信：${pending.length} 封（最近：${pending.last.senderName}）',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: WesterosColors.goldBright,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: _replyController,
                            decoration: const InputDecoration(
                              hintText: '输入回信内容（留空用默认）',
                              prefixIcon: Icon(Icons.edit_note_outlined, size: 18),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          icon: const Icon(Icons.send),
                          tooltip: '回信',
                          style: IconButton.styleFrom(
                            backgroundColor: WesterosColors.gold,
                            foregroundColor: WesterosColors.barkDeep,
                          ),
                          onPressed: _reply,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const WesterosDivider(thickness: 1),
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
    final isPending = isNpc && !letter.replied;
    final bg = isPending
        ? WesterosColors.goldDark.withValues(alpha: 0.14)
        : WesterosColors.barkHigh;
    final borderColor = isPending
        ? WesterosColors.gold.withValues(alpha: 0.5)
        : WesterosColors.outlineGold.withValues(alpha: 0.4);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      color: bg,
      shadowColor: Colors.black.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
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
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: isPending ? WesterosColors.goldBright : WesterosColors.parchment,
                    fontWeight: isPending ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: WesterosColors.barkMid.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: WesterosColors.outlineGold.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  tag,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isPending ? WesterosColors.goldBright : WesterosColors.inkDim,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            letter.content,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: WesterosColors.parchment,
              height: 1.55,
            ),
          ),
        ],
      ),
      ),
    );
  }
}