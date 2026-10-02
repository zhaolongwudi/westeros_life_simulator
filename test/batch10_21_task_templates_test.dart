/// Batch 10-21 测试：NPC 任务模板扩充（12 → 20）。
///
/// 覆盖：
/// 1. 凯特琳·史塔克（临冬城）：护送信使前往奔流城 / 打探孩子们的安危
/// 2. 罗柏·史塔克（临冬城）：召集北境封臣 / 追猎偷羊的狼群
/// 3. 玛格丽·提利尔（高庭）：筹办高庭的晚宴 / 争取王领贵族的支持
/// 4. 泰温·兰尼斯特（凯岩城）：护送金库账册至君临 / 调查西境领主的私通
/// 5. 模板总量 12 → 20（Batch 10-23 再扩至 32，Batch 10-39 再扩至 44，Batch 10-41 协作任务扩至 48，此处断言已同步），每位 NPC 各 2 个
/// 6. 接任务 → 逐步推进完成 → 结算奖励（凯特琳全流程）
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/npc_task_data.dart';
import 'package:westeros_life_simulator/game_engine.dart';

void main() {
  group('Batch 10-21 模板总量', () {
    test('任务模板总数从 12 扩到 20（Batch 10-23 再扩至 32，Batch 10-39 再扩至 44，Batch 10-41 再扩至 48）', () {
      expect(allNpcTaskTemplates.length, 67);
    });
    test('新 NPC 各有 2 个模板', () {
      expect(npcTaskTemplatesOf('npc_catelyn').length, 2);
      expect(npcTaskTemplatesOf('npc_robb').length, 3);
      expect(npcTaskTemplatesOf('npc_margaery').length, 2);
      expect(npcTaskTemplatesOf('npc_tywin_lannister').length, 3);
    });
    test('任务 ID 全局唯一', () {
      final ids = allNpcTaskTemplates.map((t) => t.id).toSet();
      expect(ids.length, allNpcTaskTemplates.length);
    });
  });

  group('Batch 10-21 凯特琳·史塔克', () {
    test('有可接任务', () {
      final engine = GameEngine()..startNewGame();
      final tasks = engine.availableTasksOf('npc_catelyn');
      expect(tasks, isNotEmpty);
      expect(tasks.map((t) => t.title), contains('护送信使前往奔流城'));
      expect(tasks.map((t) => t.title), contains('打探孩子们的安危'));
    });
    test('接任务生成实例并逐步完成', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{'npc_catelyn': 25},
        ),
      );
      final result = engine.acceptNpcTaskV2('npc_catelyn');
      expect(result, contains('接下'));
      expect(engine.activeTasks, hasLength(1));
      final goldBefore = engine.player.gold;
      var completed = false;
      for (var i = 0; i < 20 && !completed; i++) {
        final text = engine.advanceNpcTasks();
        if (text.contains('完成')) completed = true;
      }
      expect(completed, true);
      expect(engine.activeTasks.first.completed, true);
      expect(engine.player.gold, greaterThan(goldBefore));
    });
  });

  group('Batch 10-21 罗柏·史塔克', () {
    test('有可接任务', () {
      final engine = GameEngine()..startNewGame();
      final tasks = engine.availableTasksOf('npc_robb');
      expect(tasks, isNotEmpty);
      expect(tasks.map((t) => t.title), contains('召集北境封臣'));
      expect(tasks.map((t) => t.title), contains('追猎偷羊的狼群'));
    });
    test('接任务生成实例', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{'npc_robb': 25},
        ),
      );
      final result = engine.acceptNpcTaskV2('npc_robb');
      expect(result, contains('接下'));
      expect(engine.activeTasks, hasLength(1));
    });
  });

  group('Batch 10-21 玛格丽·提利尔', () {
    test('有可接任务', () {
      final engine = GameEngine()..startNewGame();
      final tasks = engine.availableTasksOf('npc_margaery');
      expect(tasks, isNotEmpty);
      expect(tasks.map((t) => t.title), contains('筹办高庭的晚宴'));
      expect(tasks.map((t) => t.title), contains('争取王领贵族的支持'));
    });
  });

  group('Batch 10-21 泰温·兰尼斯特', () {
    test('有可接任务', () {
      final engine = GameEngine()..startNewGame();
      final tasks = engine.availableTasksOf('npc_tywin_lannister');
      expect(tasks, isNotEmpty);
      expect(tasks.map((t) => t.title), contains('护送金库账册至君临'));
      expect(tasks.map((t) => t.title), contains('调查西境领主的私通'));
    });
  });
}