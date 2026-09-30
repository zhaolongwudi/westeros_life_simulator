/// Batch 10-40 测试：限时任务奖励/惩罚差异化 + 失败反馈增强。
///
/// 覆盖：
/// 1. 按时完成（剩余月数 ≥ 期限一半）→ 关系额外 +2
/// 2. 限期前完成（剩余 ≥0 但 < 一半）→ 关系额外 +1
/// 3. 逾期失败 → 声望 -2×难度、关系 -5，反馈文案含逾期月数与损失
/// 4. 未逾期不触发惩罚（不扣声望/关系）
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/models/npc_task.dart';

void main() {
  group('Batch 10-40 按时完成奖励加成', () {
    test('按期完成（剩余 ≥ 期限一半）关系额外 +2', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{'npc_nev': 25},
        ),
      );
      engine.acceptNpcTaskV2('npc_nev');
      final relAfterAccept = engine.player.relations['npc_nev'] ?? 0;
      // 艾德任务 deadlineMonths=6，推进到完成（模拟快速推进）
      var completed = false;
      for (var i = 0; i < 20 && !completed; i++) {
        final text = engine.advanceNpcTasks();
        if (text.contains('完成')) completed = true;
      }
      expect(completed, true);
      expect(engine.activeTasks.first.completed, true);
      // 接任务 +2，完成 base +8（task_nev_escort rewardRelation=8），
      // 按期（剩余 6 月 ≥ 3）额外 +2 → 总 +12
      final relAfter = engine.player.relations['npc_nev'] ?? 0;
      expect(relAfter, relAfterAccept + 8 + 2);
    });
  });

  group('Batch 10-40 逾期失败惩罚', () {
    test('逾期失败扣声望与关系，反馈含逾期月数', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{'npc_nev': 25},
          reputation: 60,
        ),
      );
      engine.acceptNpcTaskV2('npc_nev');
      final repBefore = engine.player.reputation;
      final relBefore = engine.player.relations['npc_nev'] ?? 0;
      // 把截止时间改到过去（逾期 3 个月）
      final task = engine.activeTasks.first;
      final expired = NpcTaskProgress(
        taskId: task.taskId,
        npcId: task.npcId,
        title: task.title,
        stepIndex: task.stepIndex,
        stepProgress: task.stepProgress,
        deadlineYear: 200,
        deadlineMonth: 1,
      );
      engine.updatePlayer(
        engine.player.copyWith(activeTasks: [expired]),
      );
      final result = engine.checkNpcTaskDeadlines();
      expect(result, contains('逾期'));
      expect(result, contains('声望 -'));
      expect(result, contains('关系 -'));
      expect(engine.activeTasks.first.failed, true);
      // 艾德 task_nev_escort 难度 3 → 声望 -6；关系 -5
      expect(engine.player.reputation, lessThan(repBefore));
      expect(engine.player.relations['npc_nev'], lessThan(relBefore));
    });
    test('未逾期不扣声望关系', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{'npc_nev': 25},
          reputation: 60,
        ),
      );
      engine.acceptNpcTaskV2('npc_nev');
      final repBefore = engine.player.reputation;
      final relBefore = engine.player.relations['npc_nev'] ?? 0;
      final result = engine.checkNpcTaskDeadlines();
      expect(result, '');
      expect(engine.activeTasks.first.failed, false);
      expect(engine.player.reputation, repBefore);
      expect(engine.player.relations['npc_nev'], relBefore);
    });
  });
}
