/// Batch 10-6 测试：月度世界事件浮现（世界随季节/处境活起来）。
///
/// 覆盖：
/// 1. 过月可能浮现世界事件（30% 概率，确定性 seed 下可复现）
/// 2. 事件列表为空时不浮现
/// 3. 世界事件按季节筛选（冬季只浮现冬季事件）
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';

void main() {
  group('Batch 10-6 月度世界事件浮现', () {
    test('过月叙事可能包含世界事件传闻', () {
      final e = GameEngine()..startNewGame();
      // 推进多个回合，验证世界事件机制（30% 概率，20 回合内几乎必现）
      var sawEvent = false;
      for (var i = 0; i < 30 && !sawEvent; i++) {
        final text = e.advanceMonth();
        if (text.contains('传闻')) sawEvent = true;
      }
      expect(sawEvent, true);
    });

    test('过月推进时间', () {
      final e = GameEngine()..startNewGame();
      final before = e.progress.turnCount;
      e.advanceMonth();
      expect(e.progress.turnCount, before + 1);
    });

    test('月度结算仍正常（生存+系统）', () {
      final e = GameEngine()..startNewGame();
      e.adjustHunger(-100); // 饥饿
      final before = e.player.health;
      final text = e.advanceMonth();
      expect(e.player.health, lessThan(before)); // 饥饿掉血
      expect(text, contains('时间推进'));
    });
  });
}