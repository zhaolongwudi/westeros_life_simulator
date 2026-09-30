/// Batch 10-39 测试：NPC 任务模板扩充（32 → 44）。
///
/// 覆盖：
/// 1. 奥柏伦·马泰尔（多恩）：追查毒药的来路 / 寻觅可疑的剑术高手
/// 2. 巴隆·葛雷乔伊（铁群岛）：重建铁岛的长船队 / 侦察西境海岸的守备
/// 3. 雅拉·葛雷乔伊（铁群岛）：夺回被扣的战利船 / 猎捕一艘商船
/// 4. 瑞肯·史塔克（临冬城）：陪瑞肯玩捉迷藏 / 找回走失的毛毛狗
/// 5. 洛拉斯·提利尔（高庭）：筹备高庭的比武大会 / 送出玫瑰信物
/// 6. 卓戈·多斯拉克（多斯拉克海）：驯服一匹野马驹 / 参加多斯拉克掠袭
/// 7. 模板总量 32 → 44，每位 NPC 各 2 个
/// 8. 接任务 → 逐步推进完成 → 结算奖励（瑞肯全流程；不在场的奥柏伦/巴隆/雅拉/
///    洛拉斯/卓戈仅验证模板可见性，与 batch10_21/23 一致）
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/npc_task_data.dart';
import 'package:westeros_life_simulator/game_engine.dart';

void main() {
  group('Batch 10-39 模板总量', () {
    test('任务模板总数从 32 扩到 44', () {
      expect(allNpcTaskTemplates.length, 44);
    });
    test('新 NPC 各有 2 个模板', () {
      expect(npcTaskTemplatesOf('npc_oberon_martell').length, 2);
      expect(npcTaskTemplatesOf('npc_balon_greyjoy').length, 2);
      expect(npcTaskTemplatesOf('npc_yara').length, 2);
      expect(npcTaskTemplatesOf('npc_rickon').length, 2);
      expect(npcTaskTemplatesOf('npc_loras').length, 2);
      expect(npcTaskTemplatesOf('npc_drogo').length, 2);
    });
    test('任务 ID 全局唯一', () {
      final ids = allNpcTaskTemplates.map((t) => t.id).toSet();
      expect(ids.length, allNpcTaskTemplates.length);
    });
  });

  group('Batch 10-39 瑞肯·史塔克（临冬城）', () {
    test('有可接任务', () {
      final engine = GameEngine()..startNewGame();
      final tasks = engine.availableTasksOf('npc_rickon');
      expect(tasks, isNotEmpty);
      expect(tasks.map((t) => t.title), contains('陪瑞肯玩捉迷藏'));
      expect(tasks.map((t) => t.title), contains('找回走失的毛毛狗'));
    });
    test('接任务生成实例并逐步完成', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{'npc_rickon': 25},
        ),
      );
      final result = engine.acceptNpcTaskV2('npc_rickon');
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

  group('Batch 10-39 奥柏伦·马泰尔', () {
    test('有可接任务', () {
      final engine = GameEngine()..startNewGame();
      final tasks = engine.availableTasksOf('npc_oberon_martell');
      expect(tasks, isNotEmpty);
      expect(tasks.map((t) => t.title), contains('追查毒药的来路'));
      expect(tasks.map((t) => t.title), contains('寻觅可疑的剑术高手'));
    });
  });

  group('Batch 10-39 巴隆·葛雷乔伊', () {
    test('有可接任务', () {
      final engine = GameEngine()..startNewGame();
      final tasks = engine.availableTasksOf('npc_balon_greyjoy');
      expect(tasks, isNotEmpty);
      expect(tasks.map((t) => t.title), contains('重建铁岛的长船队'));
      expect(tasks.map((t) => t.title), contains('侦察西境海岸的守备'));
    });
  });

  group('Batch 10-39 雅拉·葛雷乔伊', () {
    test('有可接任务', () {
      final engine = GameEngine()..startNewGame();
      final tasks = engine.availableTasksOf('npc_yara');
      expect(tasks, isNotEmpty);
      expect(tasks.map((t) => t.title), contains('夺回被扣的战利船'));
      expect(tasks.map((t) => t.title), contains('猎捕一艘商船'));
    });
  });

  group('Batch 10-39 洛拉斯·提利尔', () {
    test('有可接任务', () {
      final engine = GameEngine()..startNewGame();
      final tasks = engine.availableTasksOf('npc_loras');
      expect(tasks, isNotEmpty);
      expect(tasks.map((t) => t.title), contains('筹备高庭的比武大会'));
      expect(tasks.map((t) => t.title), contains('送出玫瑰信物'));
    });
  });

  group('Batch 10-39 卓戈·多斯拉克', () {
    test('有可接任务', () {
      final engine = GameEngine()..startNewGame();
      final tasks = engine.availableTasksOf('npc_drogo');
      expect(tasks, isNotEmpty);
      expect(tasks.map((t) => t.title), contains('驯服一匹野马驹'));
      expect(tasks.map((t) => t.title), contains('参加多斯拉克掠袭'));
    });
  });
}
