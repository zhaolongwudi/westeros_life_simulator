/// 信件混入：NPC 主动来信 + 玩家回信。
///
/// Letter 纯数据类已迁至 `models/letter.dart`（Batch 10-29 · M3b），本文件只留行为。
///
/// 世界那边的人在离线时也会惦记你：已结识的 NPC（同地点或有关系记录）
/// 会偶尔寄来一封信，玩家可以回信增进关系（-100~100）。
library;

import 'dart:math';

import '../core/command_registry.dart';
import '../core/monthly_pipeline.dart';
import '../models/letter.dart';
import '../models/npc.dart';
import '../models/player.dart';
import '../providers/game_provider_base.dart';
import '../providers/game_state_provider.dart';

/// 信件混入。挂在 [GameProviderBase] 上。
mixin GameLetterMixin on GameProviderBase {
  /// S12-10：本领域的月度钩子注册函数，由 `mixin_play.monthlyPipeline` 调用。
  ///
  /// 【踩坑记录，两个都实测过】
  /// ① `GamePlayMixin` 的 `on` 约束加进 `GameLetterMixin` 后报
  ///    `mixin_application_not_implemented_interface` —— 因为 letter 在
  ///    `game_engine.dart` 的 `with` 列表里排在 play **之后**；
  ///    已把 letter 调整到 play **之前**（被依赖者须先就位）。
  /// ② 想「让 letter 自注册」而给 mixin 加构造器 ⇒
  ///    Dart 禁止 mixin 声明构造器（`mixin_declares_constructor`）。
  ///    故不存在自注册路径，只能由 play 显式调用。
  ///

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

    // S13-11 ⑯：取 `last` 而非 `first`。
    // `_letters` 是**追加**顺序（`_letters.add`），故 `first` 是最早的一封；
    // 而本方法 doc 写的是「回复最新一封」、信件列表倒序渲染后**顶部就是最新**、
    // 横幅也写着「最近：…」。三处指向最新，只有实现指向最早 ⇒ 玩家看到的
    // 「最近」与真正回掉的那封不是同一封。
    final letter = target.last;
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
        group: '查看',
        helpLine: '信 / letter         查看信件',
        handler: (args) => CommandResult(text: formatLettersPanel()),
      ),
    );
    registry.register(
      CommandSpec(
        aliases: const ['回信', 'reply'],
        order: 6,
        group: '查看',
        helpLine: '回信 / reply [内容]  回复待回的信',
        handler: (args) {
          final reply = replyLetter(replyText: args.isEmpty ? null : args);
          return CommandResult(text: reply.isEmpty ? '没有待回的信。' : reply);
        },
      ),
    );
  }

  // ==================== M3 · 月度结算管线自注册 ====================

  /// 把「NPC 主动来信」注册进月度管线（S12-10）。
  ///
  /// 【为什么以前收不到信】[maybeTriggerLetter] 的唯一调用方是
  /// `mixin_ai.applyAiChoice` —— 那是**只在 AI 行动模式下**走的路径。
  /// 玩家用「过月」「探索」等普通指令推进时，月度管线里**没有任何信件钩子**
  /// （`mixin_play.monthlyPipeline` 注册了 play/systems/life/npc_interact/
  /// generation/marriage/npc_task 七家，独缺 letter），于是：
  /// **信件面板、回信、+关系 这些功能对普通玩家等同于摆设。**
  ///
  /// 【为什么用 afterAdvance / order 13】信件内容要按推进后的年月记录，
  /// 且冷却键取推进后的 turnCount，与 [mixin_ai] 旧路径一致；
  /// order 排在 `world_event`(12) 之后、outputOrder 12 接在世界事件(11)之后，
  /// 保持既有叙事顺序不被打乱。
  void registerLetterMonthlyHooks(MonthlyPipeline pipeline) {
    pipeline.register(
      MonthlyHookSpec(
        id: 'letter',
        phase: MonthlyPhase.afterAdvance,
        order: 13,
        outputOrder: 12,
        hook: () {
          final text = maybeTriggerLetter(seed: progress.turnCount);
          return MonthlyHookResult(
            text: text,
            outputOrder: text.isEmpty ? 0 : 12,
          );
        },
      ),
    );
  }
  // ==================== S13-4 · 信件进存档 ====================

  /// S13-4：存档时把信件三字段并入 JSON。
  ///
  /// 【为什么由**本 mixin** 覆写、而不在 `GameProviderBase` 里桥接】
  /// `GameProviderBase extends GameStateProvider`，而本 mixin 是
  /// `on GameProviderBase`——**父类看不到 mixin 的成员**，在 base 里写桥接必然
  /// analyze 报 Undefined name（与 S13-3 撞的是同一个方向问题）。
  /// mixin 在 `GameEngine` 的 `with` 列表里排在 base 之后，覆写生效，
  /// `super.toJson()` 链到 base/state 层。
  ///
  /// 【方向说明】写入以**运行时**为准（运行时才是活状态）；读取以**状态层**为准
  /// ——读档链路反序列化的静态类型是裸 `GameStateProvider`
  /// （save_service.dart:184/261），只有状态层有数据。与 S8-1 的
  /// `completedEventIds` 方向完全一致。
  @override
  Map<String, dynamic> toJson() {
    return super.toJson()
      ..['letters'] = _letters.map((l) => l.toJson()).toList()
      ..['lastSenderId'] = _lastSenderId
      ..['lastLetterMonth'] = _lastLetterMonth;
  }

  /// S13-4：读档后把状态层的信件三字段推回运行时。
  @override
  void applyState(GameStateProvider other) {
    super.applyState(other);
    // 🔴 **必须从 `other.` 显式读取，不能写 `letters`**：
    // mixin 自己也定义了 `letters` getter，在 `GameEngine` 上它**遮蔽**了
    // 状态层的同名 getter —— 裸写 `letters` 读到的是**运行时旧值**，
    // 读档会静默失效（表现为「读档后信件还是旧的」）。
    // `other` 的静态类型是 `GameStateProvider`，故 `other.letters` 拿到的是
    // 状态层数据，正是本方法要的。
    _letters
      ..clear()
      ..addAll(other.letters);
    _lastSenderId = other.lastSenderId;
    _lastLetterMonth = other.lastLetterMonth;
  }

  /// S13-4：新局重置信件三字段（`settings_screen` 复用同一引擎实例）。
  @override
  void startNewGame({Player? player}) {
    super.startNewGame(player: player);
    _letters.clear();
    _lastSenderId = null;
    _lastLetterMonth = null;
  }

  /// S13-4：**运行时**的收信冷却键（只读，供测试与调试观察）。
  ///
  /// 【为什么状态层已有 `lastLetterMonth` 却还要这个】状态层那份只在
  /// `applyState` 时被写入，正常游玩期间**不会**跟着运行时更新
  /// （运行时才是活状态）⇒ 游玩中两者会不一致。
  /// 加 `Runtime` 前缀以示区分，避免误用状态层那份读出陈旧值。
  String? get runtimeLastLetterMonth => _lastLetterMonth;
}
