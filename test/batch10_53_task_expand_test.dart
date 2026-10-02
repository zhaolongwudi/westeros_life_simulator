/// Batch 10-53 测试：NPC 任务模板扩充（54 → 58，卢斯·波顿/拉姆斯·波顿/席恩/霍斯特各 +1 solo）。
///
/// 覆盖：
/// 1. 模板总量 58，协作仍 8，solo 50
/// 2. 新模板数据校验：存在 / 指向真实 NPC / ID 唯一 / 标题唯一
/// 3. 可接任务列表包含新模板（不在场仅验证模板可见性，同 batch10_47 泰温惯例）
/// 4. 不在场接取提示「不在这里」
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/npc_task_data.dart';
import 'package:westeros_life_simulator/game_engine.dart';

void main() {
  group('Batch 10-53 模板总量', () {
    test('任务模板总数 54 → 58，协作仍 8，solo 50', () {
      expect(allNpcTaskTemplates.length, 72);
      final coop = allNpcTaskTemplates.where((t) => t.isCoop).toList();
      expect(coop.length, 10);
      final solo = allNpcTaskTemplates.where((t) => !t.isCoop).toList();
      expect(solo.length, 62);
    });
    test('新模板存在且指向真实 NPC', () {
      expect(npcTaskTemplateById('task_roose_ledger'), isNotNull);
      expect(npcTaskTemplateById('task_ramsay_escapee'), isNotNull);
      expect(npcTaskTemplateById('task_theon_father'), isNotNull);
      expect(npcTaskTemplateById('task_hoster_message'), isNotNull);
      expect(npcTaskTemplateById('task_roose_ledger')!.npcId, 'npc_roose_bolton');
      expect(npcTaskTemplateById('task_ramsay_escapee')!.npcId, 'npc_ramsay_bolton');
      expect(npcTaskTemplateById('task_theon_father')!.npcId, 'npc_theon');
      expect(npcTaskTemplateById('task_hoster_message')!.npcId, 'npc_hoster_tully');
    });
    test('任务 ID 全局唯一 + 标题不撞既有模板', () {
      final ids = allNpcTaskTemplates.map((t) => t.id).toSet();
      expect(ids.length, allNpcTaskTemplates.length);
      final titles = allNpcTaskTemplates.map((t) => t.title).toSet();
      expect(titles.length, allNpcTaskTemplates.length);
      // 新标题不与既有任何模板重复
      expect(titles, contains('清点黑城堡的军需账册'));
      expect(titles, contains('追捕脱逃的俘虏'));
      expect(titles, contains('试探父亲的联姻意向'));
      expect(titles, contains('护送家书至鹰巢城'));
    });
  });
  group('Batch 10-53 新模板可接性与不在场提示', () {
    test('卢斯·波顿可接列表含新模板，不在场接取提示「不在这里」', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{'npc_roose_bolton': 25},
        ),
      );
      final tasks = engine.availableTasksOf('npc_roose_bolton');
      expect(tasks.map((t) => t.title), contains('清点黑城堡的军需账册'));
      final result = engine.acceptNpcTaskV2('npc_roose_bolton');
      expect(result, contains('不在这里'));
    });
    test('拉姆斯·波顿可接列表含新模板，不在场接取提示「不在这里」', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{'npc_ramsay_bolton': 25},
        ),
      );
      final tasks = engine.availableTasksOf('npc_ramsay_bolton');
      expect(tasks.map((t) => t.title), contains('追捕脱逃的俘虏'));
      final result = engine.acceptNpcTaskV2('npc_ramsay_bolton');
      expect(result, contains('不在这里'));
    });
    test('席恩可接列表含新模板，不在场接取提示「不在这里」', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{'npc_theon': 25},
        ),
      );
      final tasks = engine.availableTasksOf('npc_theon');
      expect(tasks.map((t) => t.title), contains('试探父亲的联姻意向'));
      final result = engine.acceptNpcTaskV2('npc_theon');
      expect(result, contains('不在这里'));
    });
    test('霍斯特·徒利可接列表含新模板，不在场接取提示「不在这里」', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{'npc_hoster_tully': 25},
        ),
      );
      final tasks = engine.availableTasksOf('npc_hoster_tully');
      expect(tasks.map((t) => t.title), contains('护送家书至鹰巢城'));
      final result = engine.acceptNpcTaskV2('npc_hoster_tully');
      expect(result, contains('不在这里'));
    });
  });
}