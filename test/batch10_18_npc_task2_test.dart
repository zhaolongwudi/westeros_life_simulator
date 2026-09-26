/// Batch 10-18 测试：NPC 任务链二轮（多步骤/期限/奖励差异化）。
///
/// 覆盖：
/// 1. availableTasksOf：可接任务模板（未接且未完成）
/// 2. formatNpcTaskPanelV2：多步骤任务面板
/// 3. acceptNpcTaskV2：接任务（关系门槛/生成实例/期限）
/// 4. advanceNpcTasks：逐步推进 → 完成结算奖励
/// 5. checkNpcTaskDeadlines：逾期失败
/// 6. formatNpcTaskProgressPanel：进度面板
/// 7. 指令接线：任务列表/接任务/进度
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/models/npc_task.dart';

void main() {
  group('Batch 10-18 availableTasksOf', () {
    test('艾德·史塔克有可接任务', () {
      final engine = GameEngine()..startNewGame();
      final tasks = engine.availableTasksOf('npc_nev');
      expect(tasks, isNotEmpty);
      expect(tasks.first.title, contains('护送'));
    });
    test('未知 NPC 无任务', () {
      final engine = GameEngine()..startNewGame();
      expect(engine.availableTasksOf('npc_unknown'), isEmpty);
    });
  });

  group('Batch 10-18 formatNpcTaskPanelV2', () {
    test('在场有任务 NPC 显示多步骤委托', () {
      final engine = GameEngine()..startNewGame();
      // 默认临冬城：艾德·史塔克在场且有任务
      final panel = engine.formatNpcTaskPanelV2();
      expect(panel, contains('艾德·史塔克'));
      expect(panel, contains('护送北境信使至君临'));
      expect(panel, contains('难度'));
    });
  });

  group('Batch 10-18 acceptNpcTaskV2', () {
    test('陌生关系拒绝委托', () {
      final engine = GameEngine()..startNewGame();
      final result = engine.acceptNpcTaskV2('npc_nev');
      expect(result, contains('信不过'));
    });
    test('相识关系接受委托并生成实例', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{'npc_nev': 25},
        ),
      );
      final result = engine.acceptNpcTaskV2('npc_nev');
      expect(result, contains('接下'));
      expect(engine.activeTasks, hasLength(1));
      expect(engine.activeTasks.first.stepIndex, 0);
      // 期限应在未来：283年3月 + 6 个月 = 283年8月（同年）
      final dl = engine.activeTasks.first;
      expect(dl.deadlineYear, greaterThanOrEqualTo(283));
      if (dl.deadlineYear == 283) {
        expect(dl.deadlineMonth, greaterThan(3));
      }
    });
    test('重复接同一 NPC 任务不再给新任务', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{'npc_nev': 25},
        ),
      );
      engine.acceptNpcTaskV2('npc_nev');
      // 艾德有 2 个任务，接第一个后还剩 1 个
      final second = engine.acceptNpcTaskV2('npc_nev');
      expect(second, contains('接下'));
      // 两个都接了之后没有新任务
      final third = engine.acceptNpcTaskV2('npc_nev');
      expect(third, contains('没有新的委托'));
    });
  });

  group('Batch 10-18 advanceNpcTasks', () {
    test('逐步推进直至完成并结算奖励', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{'npc_nev': 25},
        ),
      );
      engine.acceptNpcTaskV2('npc_nev');
      final goldBefore = engine.player.gold;
      final repBefore = engine.player.reputation;
      // 反复推进直到任务完成（最多 20 次防御）
      var completed = false;
      for (var i = 0; i < 20 && !completed; i++) {
        final text = engine.advanceNpcTasks();
        if (text.contains('完成')) {
          completed = true;
        }
      }
      expect(completed, true);
      expect(engine.activeTasks.first.completed, true);
      expect(engine.player.gold, greaterThan(goldBefore));
      expect(engine.player.reputation, greaterThan(repBefore));
    });
    test('无任务返回空串', () {
      final engine = GameEngine()..startNewGame();
      expect(engine.advanceNpcTasks(), '');
    });
  });

  group('Batch 10-18 checkNpcTaskDeadlines', () {
    test('逾期任务标记失败', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{'npc_nev': 25},
        ),
      );
      engine.acceptNpcTaskV2('npc_nev');
      // 直接把截止时间改到过去（构造一个已逾期的实例）
      final task = engine.activeTasks.first;
      final expired = _expiredTask(task);
      engine.updatePlayer(
        engine.player.copyWith(activeTasks: [expired]),
      );
      final result = engine.checkNpcTaskDeadlines();
      expect(result, contains('逾期'));
      expect(engine.activeTasks.first.failed, true);
    });
    test('未逾期不失败', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{'npc_nev': 25},
        ),
      );
      engine.acceptNpcTaskV2('npc_nev');
      final result = engine.checkNpcTaskDeadlines();
      expect(result, '');
      expect(engine.activeTasks.first.failed, false);
    });
  });

  group('Batch 10-18 formatNpcTaskProgressPanel', () {
    test('无任务显示提示', () {
      final engine = GameEngine()..startNewGame();
      final panel = engine.formatNpcTaskProgressPanel();
      expect(panel, contains('没有进行中的任务'));
    });
    test('有任务显示进度', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{'npc_nev': 25},
        ),
      );
      engine.acceptNpcTaskV2('npc_nev');
      final panel = engine.formatNpcTaskProgressPanel();
      expect(panel, contains('进行中'));
      expect(panel, contains('期限'));
    });
  });

  group('Batch 10-18 指令接线', () {
    test('任务列表指令返回面板', () {
      final engine = GameEngine()..startNewGame();
      final result = engine.resolveCommand('任务列表');
      expect(result.text, contains('可接任务'));
    });
    test('接任务指令执行', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{'npc_nev': 25},
        ),
      );
      final result = engine.resolveCommand('接任务 艾德·史塔克');
      expect(result.text, contains('接下'));
      expect(engine.activeTasks, hasLength(1));
    });
    test('进度指令返回面板', () {
      final engine = GameEngine()..startNewGame();
      final result = engine.resolveCommand('进度');
      expect(result.text, contains('任务进度'));
    });
  });
}

/// 构造一个已逾期的任务实例（截止时间设为过去）。
NpcTaskProgress _expiredTask(NpcTaskProgress task) {
  return NpcTaskProgress(
    taskId: task.taskId,
    npcId: task.npcId,
    title: task.title,
    stepIndex: task.stepIndex,
    stepProgress: task.stepProgress,
    deadlineYear: 200,
    deadlineMonth: 1,
  );
}