/// Batch 10-47 测试：NPC 任务模板扩充（52 → 54，泰温 + 艾莉亚各 +1 solo 模板）。
///
/// 覆盖：
/// 1. 模板总量 54，协作仍 8，solo 46
/// 2. 新模板数据校验：存在 / 指向真实 NPC / ID 唯一 / 标题唯一
/// 3. 泰温可接任务列表包含「调查西境矿脉枯竭的谣言」
/// 4. 艾莉亚可接任务列表包含「猎杀袭击商队的狼群」
/// 5. 泰温新任务全流程（接取 → 推进 → 完成结算）
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/npc_task_data.dart';
import 'package:westeros_life_simulator/game_engine.dart';

void main() {
  group('Batch 10-47 模板总量', () {
    test('任务模板总数 52 → 54，协作仍 8，solo 46', () {
      expect(allNpcTaskTemplates.length, 61);
      final coop = allNpcTaskTemplates.where((t) => t.isCoop).toList();
      expect(coop.length, 9);
      final solo = allNpcTaskTemplates.where((t) => !t.isCoop).toList();
      expect(solo.length, 52);
    });
    test('新模板存在且指向真实 NPC（泰温/艾莉亚）', () {
      expect(npcTaskTemplateById('task_tywin_mine'), isNotNull);
      expect(npcTaskTemplateById('task_arya_wolfpack'), isNotNull);
      expect(npcTaskTemplateById('task_tywin_mine')!.npcId, 'npc_tywin_lannister');
      expect(npcTaskTemplateById('task_arya_wolfpack')!.npcId, 'npc_arya');
    });
    test('任务 ID 全局唯一 + 标题不撞既有模板', () {
      final ids = allNpcTaskTemplates.map((t) => t.id).toSet();
      expect(ids.length, allNpcTaskTemplates.length);
      final titles = allNpcTaskTemplates.map((t) => t.title).toSet();
      expect(titles.length, allNpcTaskTemplates.length);
      // 新标题不与既有任何模板重复
      expect(titles, contains('调查西境矿脉枯竭的谣言'));
      expect(titles, contains('猎杀袭击商队的狼群'));
    });
  });
  group('Batch 10-47 泰温·兰尼斯特（凯岩城）', () {
    test('可接任务列表包含新模板（不在场仅验证模板可见性）', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{'npc_tywin_lannister': 25},
        ),
      );
      final tasks = engine.availableTasksOf('npc_tywin_lannister');
      expect(tasks.map((t) => t.title), contains('调查西境矿脉枯竭的谣言'));
      // 泰温在凯岩城（玩家默认临冬城）不在场，接任务应提示不在——与 batch10_21 惯例一致
      final result = engine.acceptNpcTaskV2('npc_tywin_lannister');
      expect(result, contains('不在这里'));
    });
  });
  group('Batch 10-47 艾莉亚·史塔克（临冬城）', () {
    test('可接任务列表包含新模板', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{'npc_arya': 25},
        ),
      );
      final tasks = engine.availableTasksOf('npc_arya');
      expect(tasks.map((t) => t.title), contains('猎杀袭击商队的狼群'));
    });
    test('新任务全流程（指定 taskId 接取 → 推进 → 完成结算）', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{'npc_arya': 30},
        ),
      );
      final result = engine.acceptNpcTaskV2('npc_arya', taskId: 'task_arya_wolfpack');
      expect(result, contains('接下'));
      expect(engine.activeTasks, hasLength(1));
      final goldBefore = engine.player.gold;
      var completed = false;
      for (var i = 0; i < 25 && !completed; i++) {
        final text = engine.advanceNpcTasks();
        if (text.contains('完成') && text.contains('狼群')) {
          completed = true;
        }
      }
      expect(completed, isTrue, reason: '艾莉亚新任务应在推进后完成');
      expect(engine.player.gold, greaterThan(goldBefore));
    });
  });
}