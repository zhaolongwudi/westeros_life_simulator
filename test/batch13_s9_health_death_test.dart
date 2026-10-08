/// Sprint 13-9 测试：修 P1 ⑩「`health` 效果永远杀不死玩家」。
///
/// 【本批修的是什么】`applyEffects` 的 `health` 分支只做 `.clamp(0, 100)`，
/// **从不置 `isAlive=false`**；而 `_checkGameOver()`（`game_state_provider.dart:574`）
/// 只读 `flags['isAlive']`。于是：
///   · 狩猎/饥饿走 `adjustHealth`（会判死，`mixin_life.dart:71-73`）；
///   · 但**所有事件选项 / AI 选项 / 系统结算**都走 `applyEffects`
///     ⇒ 事件库 11 处负 health（-3 ~ -20）能把玩家打到 0 血却继续游戏。
///
/// 【为什么这是真缺陷而不是「健康到 0 只是濒死」】项目已有明确的死亡契约：
/// `adjustHealth` 在 `newHealth <= 0` 时置 `isAlive=false`，且
/// `regression_simulation_test` 断言「纯挂机必死（isGameOver==true）」。
/// 两条通道对同一件事（健康归零）给出不同结论，属实现漂移。
///
/// 【为什么必须断言 isAlive 而不只是 health】`clamp(0,100)` 在缺陷下也把
/// health 变成 0——只看 health 会假绿。判别式必须落在**判死标记**上。
///
/// ⚠️ 本机（Android/DSH）无 dart/flutter，**本文件未在本地执行**，正确性由 CI 验证。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/models/event.dart';

EventChoice _choice(Map<String, int> effects) {
  return EventChoice(
    id: 'choice_s13_9',
    text: '测试选项',
    requirements: const <String, int>{},
    effects: effects,
    narrative: '',
  );
}

void main() {
  group('S13-9 applyEffects 的 health 分支必须判死', () {
    test('health 打到 0：isAlive 置假（与 adjustHealth 对齐）', () {
      final e = GameEngine()..startNewGame();
      expect(e.player.flags['isAlive'], isTrue, reason: '前置：开局存活');

      e.updatePlayer(e.applyEffects(e.player, const <String, int>{'health': -100}));

      expect(e.player.health, 0);
      expect(e.player.flags['isAlive'], isFalse,
          reason: '健康归零必须判死——缺陷下这里仍是 true，玩家 0 血继续玩');
    });

    test('health 恰好打到 0（边界）同样判死', () {
      final e = GameEngine()..startNewGame();
      e.updatePlayer(e.player.copyWith(health: 20));
      e.updatePlayer(e.applyEffects(e.player, const <String, int>{'health': -20}));
      expect(e.player.health, 0);
      expect(e.player.flags['isAlive'], isFalse, reason: '边界 <=0 也要判死');
    });

    test('未打到 0 时不误判死亡', () {
      final e = GameEngine()..startNewGame();
      e.updatePlayer(e.player.copyWith(health: 30));
      e.updatePlayer(e.applyEffects(e.player, const <String, int>{'health': -10}));
      expect(e.player.health, 20);
      expect(e.player.flags['isAlive'], isTrue, reason: '还有 20 血不该判死');
    });

    test('health 为正值（回血）不误判', () {
      final e = GameEngine()..startNewGame();
      e.updatePlayer(e.player.copyWith(health: 10));
      e.updatePlayer(e.applyEffects(e.player, const <String, int>{'health': 20}));
      expect(e.player.health, 30);
      expect(e.player.flags['isAlive'], isTrue);
    });
  });

  group('S13-9 事件选项通道：0 血必须真的 game over', () {
    test('事件选项 health -100 打到 0 后 isGameOver 为真', () {
      final e = GameEngine()..startNewGame();
      expect(e.isGameOver, isFalse);

      e.applyChoice(_choice(const <String, int>{'health': -100}));

      expect(e.player.health, 0);
      expect(e.isGameOver, isTrue,
          reason: '`_checkGameOver` 只读 flags.isAlive ⇒ 不置位就永远结束不了游戏');
      expect(e.isGameActive, isFalse);
    });

    test('未致命的事件选项不会误结束游戏', () {
      final e = GameEngine()..startNewGame();
      e.updatePlayer(e.player.copyWith(health: 100));
      e.applyChoice(_choice(const <String, int>{'health': -5}));
      expect(e.player.health, 95);
      expect(e.isGameOver, isFalse);
    });
  });
}
