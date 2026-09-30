/// M6b 跨批次回归套件 · 长会话（regression_long_session_test.dart）。
///
/// 目的：真实「玩家一直玩」的长会话语义回归：
/// 1. 经引擎 resolveCommand('过月') 连续推进 200 / 1000 回合，
///    history 由事件选择累积 → 环形截断生效、droppedHistoryCount 记账、
///    存档体积有界（不随回合数线性膨胀）；
/// 2. 每 12 个月（一整年）执行一次事件选择 + 过月，模拟真实游玩节奏；
/// 3. 1000 回合后引擎仍可执行指令（玩家面板/帮助不崩）。
///
/// 与 m2 的区别：
/// - m2 用 GameStateProvider.applyChoice 纯状态层验证环形上限；
/// - 本文件用 GameEngine（混入层 + 事件提供者）真实驱动过月/事件，
///   验证**整条链路**在长会话下不退化。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/models/event.dart';
import 'package:westeros_life_simulator/providers/game_state_provider.dart';

/// 模拟玩家真实游玩 [turns] 回合：
/// 每 3 回合触发一次事件选择，其余纯「过月」推进。
///
/// 为保证长会话测试只验证「状态累积/历史截断/存档体积」而非生存曲线
/// （生存曲线已由 regression_simulation_test 单独覆盖），
/// 每月推进前把生存三维重置到安全值，模拟「玩家一直在正常游玩」。
void _playTurns(GameEngine e, int turns) {
  for (var i = 0; i < turns; i++) {
    // 保持生存三维安全（模拟玩家正常游玩，不饿死不疲惫）
    e.updatePlayer(e.player.copyWith(hunger: 60, health: 60, energy: 60));
    // 每 3 回合触发一次事件选择（模拟事件流），其余纯过月
    if (i % 3 == 0) {
      final available = e.eventProvider.getAvailableEvents(
        e.player,
        season: e.progress.season,
      );
      if (available.isNotEmpty) {
        final GameEvent ev = available.first;
        e.setCurrentEvent(ev);
        final choice = ev.choices.isNotEmpty ? ev.choices.first : null;
        if (choice != null) {
          e.applyChoice(choice);
        }
      }
    }
    if (e.isGameOver) break;
    e.resolveCommand('过月');
  }
}

void main() {
  group('M6b 长会话 · 200 回合', () {
    test('200 回合（约 16.7 年）后 history≤200、可继续游玩', () {
      final e = GameEngine()..startNewGame();
      _playTurns(e, 200);
      expect(e.isGameOver, isFalse, reason: '200 回合不应意外死亡');
      expect(e.history.length,
          lessThanOrEqualTo(GameStateProvider.kHistoryLimit));
      // 时间正确推进：200 回合中约 67 次事件（applyChoice 推进 1 回合）
      // + 200 次过月 → turnCount ≈ 267（允许事件触发次数浮动）
      expect(e.progress.turnCount, greaterThanOrEqualTo(200));
      expect(e.progress.turnCount, lessThan(400));
      // 引擎仍可响应
      expect(e.resolveCommand('帮助').text, contains('帮助 / help'));
      expect(e.resolveCommand('状态').text, contains('【玩家状态】'));
    });

    test('200 回合内若发生循环截断，droppedHistoryCount≥0 且 ≤200', () {
      final e = GameEngine()..startNewGame();
      _playTurns(e, 200);
      expect(e.droppedHistoryCount, greaterThanOrEqualTo(0));
      expect(e.droppedHistoryCount,
          lessThanOrEqualTo(GameStateProvider.kHistoryLimit));
    });
  });

  group('M6b 长会话 · 1000 回合（上限压力）', () {
    test('1000 回合后 history 仍 ≤200、存档体积有界、引擎不崩', () {
      final e = GameEngine()..startNewGame();
      _playTurns(e, 1000);
      expect(e.isGameOver, isFalse, reason: '正常游玩 1000 回合不应死亡');
      expect(e.history.length,
          lessThanOrEqualTo(GameStateProvider.kHistoryLimit),
          reason: '长会话 history 必须被环形截断');
      expect(e.droppedHistoryCount, greaterThan(0),
          reason: '1000 回合必然触发历史截断记账');

      // 序列化体积：history 上限 200，存档体积有界（不随回合数膨胀）
      final json = e.toJson();
      final historyLen = (json['history'] as List<Object?>).length;
      expect(historyLen, lessThanOrEqualTo(GameStateProvider.kHistoryLimit));
      // 关键字段仍在：金币非负、时间合理（1000 回合 ≈ 83 年 → 366 年）
      expect(e.player.gold, greaterThanOrEqualTo(0));
      expect(e.progress.year, lessThan(400));

      // 引擎仍可正常执行存储外的指令
      final help = e.resolveCommand('帮助').text;
      expect(help, contains('帮助 / help'));
    });
  });

  group('M6b 长会话 · 存档往返', () {
    test('1000 回合存档 toJson→fromJson 往返：玩家/进度/历史/计数全保留', () {
      final e = GameEngine()..startNewGame();
      _playTurns(e, 1000);
      final json = e.toJson();
      final restored = GameStateProvider.fromJson(json);
      expect(restored.player.name, e.player.name);
      expect(restored.player.gold, e.player.gold);
      expect(restored.progress.turnCount, e.progress.turnCount);
      expect(restored.progress.year, e.progress.year);
      expect(restored.history.length, e.history.length);
      expect(restored.droppedHistoryCount, e.droppedHistoryCount);
      expect(restored.isGameActive, e.isGameActive);
    });
  });
}