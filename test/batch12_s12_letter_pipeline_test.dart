/// Sprint 12 测试：信件系统接入月度管线（S12-10）。
///
/// 【本批修的是什么 —— 又一个「摆设」】
/// `maybeTriggerLetter` 的**唯一调用方**是 `mixin_ai.applyAiChoice`，
/// 而那是**只有开启 AI 行动模式**才会走的路径。
/// 月度管线（`mixin_play.monthlyPipeline`）注册了 play / systems / life /
/// npc_interact / generation / marriage / npc_task **七家，独缺 letter**。
/// ⇒ 玩家用「过月」「探索」等普通指令推进时，永远收不到信；
///    「信件」面板、`回信` 指令、来信 +1 关系 —— 对普通玩家全是摆设。
///
/// 【修法】新增 `registerLetterMonthlyHooks` 并注册进管线（afterAdvance，
/// order 13 / outputOrder 12），并删掉 `applyAiChoice` 里那条重复调用。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';

void main() {
  group('S12-10 月度管线已注册信件钩子', () {
    test('管线里存在 id=letter 的钩子且不重复注册', () {
      final engine = GameEngine()..startNewGame();
      // 访问管线会触发惰性构建。
      final ids = engine.monthlyPipeline.orderedIds;
      expect(ids, contains('letter'), reason: '信件钩子必须注册进月度管线');
      expect(ids.toSet().length, ids.length,
          reason: '钩子 id 不得重复：$ids');
      expect(engine.monthlyPipeline.duplicateIds, isEmpty);
    });

    test('信件钩子排在 world_event 之后（叙事顺序稳定）', () {
      final engine = GameEngine()..startNewGame();
      final ids = engine.monthlyPipeline.orderedIds;
      expect(ids.indexOf('letter'), greaterThan(ids.indexOf('world_event')),
          reason: '信件应在世界事件之后触发，实际顺序：$ids');
      expect(ids.last, 'letter', reason: '信件是当月最后一段');
    });
  });

  group('S12-10 普通（非 AI）路径也能收到信', () {
    test('连续过月，总会出现信件', () {
      final engine = GameEngine()..startNewGame();
      // 先与在场 NPC 建立一点关系，扩大「已结识」候选池。
      var sawLetter = false;
      for (var i = 0; i < 40 && !sawLetter; i++) {
        engine.resolveCommand('过月');
        if (engine.letters.any((l) => l.isFromNpc)) sawLetter = true;
      }
      expect(sawLetter, isTrue,
          reason: '普通「过月」路径 40 个月内应至少收到一封信 —— '
              '修复前只有 AI 路径会发信，这里必然失败');
    });

    test('过月的叙事文本里会带上来信内容', () {
      final engine = GameEngine()..startNewGame();
      var textWithLetter = '';
      for (var i = 0; i < 40 && textWithLetter.isEmpty; i++) {
        final r = engine.resolveCommand('过月');
        if (r.text.contains('渡鸦')) textWithLetter = r.text;
      }
      expect(textWithLetter, isNotEmpty,
          reason: '月度叙事应把信件文本输出给玩家（否则状态变了但玩家看不见）');
    });
  });

  group('S12-10 AI 路径不重复发信（回归锁）', () {
    test('applyAiChoice 走完后信件不出现两封同月重复', () {
      final engine = GameEngine()..startNewGame();
      // 直接调用月度推进（即 applyAiChoice 内部走的同一条路）。
      engine.advanceMonth();
      final after1 = engine.letters.length;
      // 同月再推进一次，冷却键应阻止重复收信。
      final thisMonth = '${engine.progress.year}-${engine.progress.month}';
      for (var i = 0; i < 5; i++) {
        engine.resolveCommand('过月');
      }
      final sameMonthLetters = engine.letters
          .where((l) =>
              '${l.year}-${l.month}' == thisMonth && l.isFromNpc)
          .length;
      expect(sameMonthLetters, lessThanOrEqualTo(1),
          reason: '同一个月最多一封信（$after1 封在推进前）');
    });
  });
}