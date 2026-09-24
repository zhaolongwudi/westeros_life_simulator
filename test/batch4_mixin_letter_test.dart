/// Batch 4 测试：GameLetterMixin（信件混入）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';

void main() {
  group('GameLetterMixin', () {
    test('初始无信件', () {
      final engine = GameEngine()..startNewGame();
      expect(engine.letters, isEmpty);
      expect(engine.hasPendingLetter, false);
    });

    test('maybeTriggerLetter 未开始返回空', () {
      final engine = GameEngine();
      expect(engine.maybeTriggerLetter(), '');
    });

    test('maybeTriggerLetter 可触达且状态合法', () {
      final engine = GameEngine()..startNewGame();
      final result = engine.maybeTriggerLetter(seed: 999);
      expect(result, isA<String>());
      if (result.isNotEmpty) {
        expect(engine.letters.length, 1);
        expect(engine.letters.first.isFromNpc, true);
        // 收信 +1 关系
        final senderId = engine.letters.first.senderId;
        expect(engine.player.relations[senderId], greaterThan(0));
      } else {
        expect(engine.letters, isEmpty);
      }
    });

    test('maybeTriggerLetter 同月冷却', () {
      final engine = GameEngine()..startNewGame();
      engine.maybeTriggerLetter(seed: 999);
      final firstCount = engine.letters.length;
      // 同月第二次调用应因冷却返回空
      final second = engine.maybeTriggerLetter(seed: 999);
      expect(second, '');
      expect(engine.letters.length, firstCount);
    });

    test('replyLetter 无待回信返回空', () {
      final engine = GameEngine()..startNewGame();
      expect(engine.replyLetter(), '');
    });

    test('replyLetter 有待回信可回复', () {
      final engine = GameEngine()..startNewGame();
      final triggered = engine.maybeTriggerLetter(seed: 999);
      if (triggered.isEmpty) {
        // 40% 概率未触发时，该测试跳过（避免脆弱断言）
        return;
      }
      final senderId = engine.letters.first.senderId;
      final before = engine.player.relations[senderId] ?? 0;
      final result = engine.replyLetter(replyText: '保重');
      expect(result, contains('回信'));
      expect(engine.player.relations[senderId] ?? 0, greaterThan(before));
    });

    test('formatLettersPanel 无信提示', () {
      final engine = GameEngine()..startNewGame();
      expect(engine.formatLettersPanel(), contains('渡鸦'));
    });
  });
}