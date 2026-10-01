/// Batch 10-23 测试：NPC 任务模板扩充（20 → 32）。
///
/// 覆盖：
/// 1. 珊莎·史塔克（临冬城）：为珊莎采买上等丝绸 / 打探君临宫廷的礼数
/// 2. 艾莉亚·史塔克（临冬城）：陪艾莉亚练剑 / 掩护艾莉亚溜出城
/// 3. 布兰·史塔克（临冬城）：带布兰登高看鹰巢 / 为布兰收集古堡传说
/// 4. 詹姆·兰尼斯特（君临）：与詹姆切磋剑术 / 为詹姆送一封密信
/// 5. 劳勃·拜拉席恩（君临）：陪劳勃国王狩猎 / 为国王搜罗佳酿
/// 6. 史坦尼斯·拜拉席恩（龙石岛）：修缮龙石岛的舰队 / 摸清诸侯的忠诚
/// 7. 模板总量 20 → 32（Batch 10-39 再扩至 44，Batch 10-41 协作任务扩至 48），每位 NPC 各 2 个
/// 8. 接任务 → 逐步推进完成 → 结算奖励（珊莎全流程；不在场的詹姆/劳勃/史坦尼斯
///    仅验证模板可见性，与 batch10_21 的玛格丽/泰温一致）
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/npc_task_data.dart';
import 'package:westeros_life_simulator/game_engine.dart';

void main() {
  group('Batch 10-23 模板总量', () {
    test('任务模板总数从 20 扩到 32（Batch 10-39 再扩至 44，Batch 10-41 再扩至 48）', () {
      expect(allNpcTaskTemplates.length, 48);
    });
    test('新 NPC 各有 2 个模板', () {
      expect(npcTaskTemplatesOf('npc_sansa').length, 3);
      expect(npcTaskTemplatesOf('npc_arya').length, 2);
      expect(npcTaskTemplatesOf('npc_bran').length, 3);
      expect(npcTaskTemplatesOf('npc_jaime').length, 2);
      expect(npcTaskTemplatesOf('npc_robert_baratheon').length, 2);
      expect(npcTaskTemplatesOf('npc_stannis_baratheon').length, 2);
    });
    test('任务 ID 全局唯一', () {
      final ids = allNpcTaskTemplates.map((t) => t.id).toSet();
      expect(ids.length, allNpcTaskTemplates.length);
    });
  });

  group('Batch 10-23 珊莎·史塔克', () {
    test('有可接任务', () {
      final engine = GameEngine()..startNewGame();
      final tasks = engine.availableTasksOf('npc_sansa');
      expect(tasks, isNotEmpty);
      expect(tasks.map((t) => t.title), contains('为珊莎采买上等丝绸'));
      expect(tasks.map((t) => t.title), contains('打探君临宫廷的礼数'));
    });
    test('接任务生成实例并逐步完成', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{'npc_sansa': 25},
        ),
      );
      final result = engine.acceptNpcTaskV2('npc_sansa');
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

  group('Batch 10-23 艾莉亚·史塔克', () {
    test('有可接任务', () {
      final engine = GameEngine()..startNewGame();
      final tasks = engine.availableTasksOf('npc_arya');
      expect(tasks, isNotEmpty);
      expect(tasks.map((t) => t.title), contains('陪艾莉亚练剑'));
      expect(tasks.map((t) => t.title), contains('掩护艾莉亚溜出城'));
    });
  });

  group('Batch 10-23 布兰·史塔克', () {
    test('有可接任务', () {
      final engine = GameEngine()..startNewGame();
      final tasks = engine.availableTasksOf('npc_bran');
      expect(tasks, isNotEmpty);
      expect(tasks.map((t) => t.title), contains('带布兰登高看鹰巢'));
      expect(tasks.map((t) => t.title), contains('为布兰收集古堡传说'));
    });
  });

  group('Batch 10-23 詹姆·兰尼斯特', () {
    test('有可接任务', () {
      final engine = GameEngine()..startNewGame();
      final tasks = engine.availableTasksOf('npc_jaime');
      expect(tasks, isNotEmpty);
      expect(tasks.map((t) => t.title), contains('与詹姆切磋剑术'));
      expect(tasks.map((t) => t.title), contains('为詹姆送一封密信'));
    });
  });

  group('Batch 10-23 劳勃·拜拉席恩', () {
    test('有可接任务', () {
      final engine = GameEngine()..startNewGame();
      final tasks = engine.availableTasksOf('npc_robert_baratheon');
      expect(tasks, isNotEmpty);
      expect(tasks.map((t) => t.title), contains('陪劳勃国王狩猎'));
      expect(tasks.map((t) => t.title), contains('为国王搜罗佳酿'));
    });
  });

  group('Batch 10-23 史坦尼斯·拜拉席恩', () {
    // 史坦尼斯在风息堡（不在玩家默认出生地临冬城），
    // 与 batch10_21 的玛格丽/泰温一致：只验证模板可见性，不做接任务全流程。
    test('有可接任务', () {
      final engine = GameEngine()..startNewGame();
      final tasks = engine.availableTasksOf('npc_stannis_baratheon');
      expect(tasks, isNotEmpty);
      expect(tasks.map((t) => t.title), contains('修缮龙石岛的舰队'));
      expect(tasks.map((t) => t.title), contains('摸清诸侯的忠诚'));
    });
  });
}
