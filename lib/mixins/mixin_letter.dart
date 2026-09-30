/// 信件混入：NPC 主动来信 + 玩家回信。
///
/// Letter 纯数据类已迁至 `models/letter.dart`（Batch 10-29 · M3b），本文件只留行为。
///
/// 世界那边的人在离线时也会惦记你：已结识的 NPC（同地点或有关系记录）
/// 会偶尔寄来一封信，玩家可以回信增进关系（-100~100）。
library;

import 'dart:math';

import '../core/command_registry.dart';
import '../models/letter.dart';
import '../models/npc.dart';
import '../providers/game_provider_base.dart';

/// 信件混入。挂在 [GameProviderBase] 上。
mixin GameLetterMixin on GameProviderBase {
  /// 收到的信件（最多 30 封）。
  final List<Letter> _letters = <Letter>[];

  /// 收到的信件列表。
  List<Letter> get letters => List.unmodifiable(_letters);

  /// 上一位寄信人 NPC ID（避免连续同一人刷屏）。
  String? _lastSenderId;

  /// 最近一次收到来信的月份（冷却：每自然月最多 1 封主动来信）。
  String? _lastLetterMonth;

  /// 是否有待回的信。
  bool get hasPendingLetter => _letters.any((l) => l.isFromNpc && !l.replied);

  /// 检查 NPC 是否为"已结识"（有关系记录或同地点）。
  bool _isAcquainted(Npc npc) {
    return player.relations.containsKey(npc.id) ||
        npc.locationId == player.locationId;
  }

  /// 触发一封主动来信（每月可由月度循环调用）。
  ///
  /// 返回信件叙事文本；无可寄信人/冷却中返回空串。
  String maybeTriggerLetter({int? seed}) {
    if (!isGameActive || isGameOver) return '';
    final rnd = rng(seed);
    final monthKey = '${progress.year}-${progress.month}';
    if (_lastLetterMonth == monthKey) return ''; // 本月已收过
    if (rnd.nextDouble() > 0.4) return ''; // 40% 概率

    // 候选：已结识且存活的 NPC
    final candidates = npcs.where((n) {
      return n.isAlive && _isAcquainted(n) && n.id != _lastSenderId;
    }).toList();
    if (candidates.isEmpty) return '';

    final sender = candidates[rnd.nextInt(candidates.length)];
    _lastSenderId = sender.id;
    _lastLetterMonth = monthKey;
    _letters.add(
      Letter(
        senderId: sender.id,
        senderName: sender.name,
        content: _letterContentFor(sender, rnd),
        year: progress.year,
        month: progress.month,
        isFromNpc: true,
      ),
    );
    // 收信小幅提升关系（+1，封顶 100）
    adjustRelation(sender.id, 1);
    notifyListeners();
    return '🦅 一只渡鸦落在你肩上，衔来 ${sender.name} 的信。\n'
        '「${_letterContentFor(sender, rnd)}」';
  }

  /// 为某 NPC 生成一封信件内容（按性格特质池）。
  String _letterContentFor(Npc npc, Random rnd) {
    final personality = npc.personality;
    final pool = <String>[
      '近来可好？我在${npc.locationId}一切如常。维斯特洛的风越来越冷了，记得添衣。',
      '听闻你最近有些动静。这个世道，谨慎些总没错。',
      '如果你路过我这，务必来喝一杯。有些话，信里说不清。',
      '家族的旗帜还在风中飘着。只要它还在，我们就在。',
      '最近梦到了旧神的心树。也许你该找个机会，去听一听树下的低语。',
    ];
    if (personality.contains('狡诈') || personality.contains('阴谋')) {
      pool.add('有些消息只适合当面说。你知道在哪里能找到我。');
    }
    if (personality.contains('荣誉')) {
      pool.add('荣誉不是挂在墙上的剑，是每天都要践行的路。愿你的路笔直。');
    }
    return pool[rnd.nextInt(pool.length)];
  }

  /// 回信：回复最新一封未回的信，增加与寄信人的关系。
  ///
  /// 返回回信叙事文本；无待回信时返回空串。
  String replyLetter({String? replyText}) {
    final target = _letters.where((l) => l.isFromNpc && !l.replied).toList();
    if (target.isEmpty) return '';

    // 回最早的一封未回信
    final letter = target.first;
    final index = _letters.indexOf(letter);
    _letters[index] = letter.copyWith(replied: true);

    // 回信内容：玩家回应或默认
    final text = (replyText == null || replyText.trim().isEmpty)
        ? '你的信我已收到。愿七神/旧神护佑你。'
        : replyText.trim();

    // 回信提升关系（+2，封顶 100）
    adjustRelation(letter.senderId, 2);
    _letters.add(
      Letter(
        senderId: letter.senderId,
        senderName: player.name,
        content: '（你给 ${letter.senderName} 的回信）$text',
        year: progress.year,
        month: progress.month,
        isFromNpc: false,
      ),
    );
    // 信件容量上限
    if (_letters.length > 30) {
      _letters.removeRange(0, _letters.length - 30);
    }
    notifyListeners();
    return '你提笔给 ${letter.senderName} 写了一封回信：「$text」';
  }

  /// 信件面板文本。
  String formatLettersPanel() {
    if (_letters.isEmpty) return '【信件】\n你的渡鸦还没有带回任何信件。';
    final buf = StringBuffer()
      ..writeln('【信件】${_letters.length} 封')
      ..writeln();
    for (final l in _letters.reversed.take(10)) {
      final tag = l.isFromNpc ? (l.replied ? '📖已回' : '📩待回') : '✉️回信';
      buf
        ..writeln('[$tag] ${l.senderName}（${l.year}年${l.month}月）')
        ..writeln('  ${l.content}');
    }
    return buf.toString().trim();
  }

  // ==================== M3 · 指令自注册 ====================

  /// 把本领域指令注册进注册表（order 与历史帮助文本顺序一致）。
  void registerLetterCommands(CommandRegistry registry) {
    registry.register(
      CommandSpec(
        aliases: const ['信', 'letter'],
        order: 5,
        helpLine: '信 / letter         查看信件',
        handler: (args) => CommandResult(text: formatLettersPanel()),
      ),
    );
    registry.register(
      CommandSpec(
        aliases: const ['回信', 'reply'],
        order: 6,
        helpLine: '回信 / reply [内容]  回复待回的信',
        handler: (args) {
          final reply = replyLetter(replyText: args.isEmpty ? null : args);
          return CommandResult(text: reply.isEmpty ? '没有待回的信。' : reply);
        },
      ),
    );
  }
}
