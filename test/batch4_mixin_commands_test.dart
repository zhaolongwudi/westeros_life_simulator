/// Batch 4 测试：GameCommandsMixin（指令分发）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';

void main() {
  group('GameCommandsMixin', () {
    test('空指令返回提示', () {
      final engine = GameEngine()..startNewGame();
      final result = engine.resolveCommand('  ');
      expect(result.text, contains('请输入指令'));
      expect(result.consumedTurn, false);
    });

    test('帮助指令', () {
      final engine = GameEngine()..startNewGame();
      final result = engine.resolveCommand('帮助');
      expect(result.text, contains('可用指令'));
    });

    test('状态指令', () {
      final engine = GameEngine()..startNewGame();
      final result = engine.resolveCommand('状态');
      expect(result.text, contains('玩家状态'));
      expect(result.text, contains('无名者'));
    });

    test('status 英文别名', () {
      final engine = GameEngine()..startNewGame();
      final result = engine.resolveCommand('status');
      expect(result.text, contains('玩家状态'));
    });

    test('系统指令', () {
      final engine = GameEngine()..startNewGame();
      final result = engine.resolveCommand('系统');
      expect(result.text, contains('系统面板'));
    });

    test('信件指令（无信时）', () {
      final engine = GameEngine()..startNewGame();
      final result = engine.resolveCommand('信');
      expect(result.text, contains('渡鸦'));
    });

    test('旅行无参数返回可前往列表', () {
      final engine = GameEngine()..startNewGame();
      final result = engine.resolveCommand('旅行');
      expect(result.text, contains('可前往'));
    });

    test('训练无参数提示技能', () {
      final engine = GameEngine()..startNewGame();
      final result = engine.resolveCommand('训练');
      expect(result.text, contains('训练什么'));
    });

    test('训练 sword 正常执行', () {
      final engine = GameEngine()..startNewGame();
      final result = engine.resolveCommand('训练 sword');
      expect(result.text, isNot(contains('训练什么')));
    });

    test('工作指令', () {
      final engine = GameEngine()..startNewGame();
      final before = engine.player.gold;
      final result = engine.resolveCommand('工作');
      expect(result.text, contains('忙碌了一天'));
      expect(engine.player.gold, greaterThan(before));
    });

    test('休息指令', () {
      final engine = GameEngine()..startNewGame();
      final result = engine.resolveCommand('休息');
      expect(result.text, contains('歇了一晚'));
    });

    test('过月指令消耗回合', () {
      final engine = GameEngine()..startNewGame();
      final result = engine.resolveCommand('过月');
      expect(result.text, contains('时间推进到'));
      expect(result.consumedTurn, true);
    });

    test('探索指令消耗回合', () {
      final engine = GameEngine()..startNewGame();
      final result = engine.resolveCommand('探索');
      expect(result.text, isNotEmpty);
      expect(result.consumedTurn, true);
    });

    test('未知指令返回帮助', () {
      final engine = GameEngine()..startNewGame();
      final result = engine.resolveCommand('未知指令xyz');
      expect(result.text, contains('可用指令'));
    });
  });
}