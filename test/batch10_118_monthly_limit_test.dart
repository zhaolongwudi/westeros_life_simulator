/// Batch 10-118 测试：活动次数上限的「每月」口径（S2-2 / P2-02 / P3-02）。
///
/// 背景：`BalanceData.dailyLimits` 名曰「每日」，实际重置键是 `${年}-${月}`
/// （`GamePlayMixin._rollDaily`），游戏里根本没有「天」这个时间单位，
/// 玩家看到的却是「你今天已经练得够多了」这类文案。
/// 另：`dailyLimits['rest']` 原为 99 且 `rest()` 从不读取，是装饰性死值。
///
/// 覆盖：
/// 1. rest 闸口真的生效（上限 10），且跨月重置
/// 2. 各闸口文案一律「本月」口径，不含「今天」
/// 3. 帮助文本里的频次说明也是「每月」
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';

void main() {
  group('Batch 10-118 rest 每月闸口', () {
    test('每月最多休息 10 次，第 11 次被拒', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(engine.player.copyWith(gold: 1000));
      var ok = 0;
      for (var i = 0; i < 12; i++) {
        final text = engine.rest();
        if (!text.contains('已经歇得够久了')) ok++;
      }
      expect(ok, 10, reason: 'rest 上限为 10，此前该键是永不生效的 99');
    });

    test('跨月后 rest 计数重置', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(engine.player.copyWith(gold: 1000));
      for (var i = 0; i < 10; i++) {
        engine.rest();
      }
      expect(engine.rest(), contains('已经歇得够久了'));
      engine.advanceMonth();
      engine.updatePlayer(engine.player.copyWith(gold: 1000));
      expect(engine.rest(), isNot(contains('已经歇得够久了')),
          reason: '新的一月应重新获得休息次数');
    });
  });

  group('Batch 10-118 文案口径', () {
    test('闸口文案一律「本月」，不含「今天」', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(engine.player.copyWith(gold: 1000));

      // 把各活动刷到上限，收集拒绝文案
      final refused = <String>[];
      void run(String Function() fn, int times) {
        for (var i = 0; i < times; i++) {
          final t = fn();
          if (t.contains('本月') || t.contains('今天')) refused.add(t);
        }
      }

      run(() => engine.train('剑术'), 6); // train 上限 3
      run(engine.work, 5);                // work 上限 2
      run(engine.hunt, 5);                // hunt 上限 2
      run(engine.rest, 12);               // rest 上限 10

      expect(refused, isNotEmpty);
      for (final t in refused) {
        expect(t, contains('本月'), reason: '文案应为月度口径：$t');
        expect(t.contains('今天'), isFalse, reason: '不应再出现「今天」：$t');
      }
    });

    test('帮助文本的频次说明为「每月」', () {
      final engine = GameEngine()..startNewGame();
      final help = engine.helpText();
      expect(help, isNot(contains('每日')), reason: '游戏没有「天」，频次应按月');
      expect(help, contains('每月'));
    });
  });
}
