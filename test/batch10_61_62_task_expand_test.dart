/// Batch 10-61/62 测试：剩余 NPC 任务模板补齐 + 谷地协作任务。
///
/// Batch 10-61：4 个无任务 NPC（琼恩·艾林/弥赛拉/雷加/韦赛里斯）各 +1 solo
///             → 67 → 71（solo 58 → 62，协作 9 不变）。
/// Batch 10-62：琼恩·艾林 × 莱莎·艾林（鹰巢城）协作任务
///             → 71 → 72（协作 9 → 10）。
///
/// 覆盖：
/// 1. 模板总量 67 → 72，solo 62，协作 10
/// 2. 新 solo ×4 存在且指向真实 NPC，均为非协作
/// 3. 新协作存在，双方同地点（鹰巢城）
/// 4. ID/标题唯一
/// 5. 4 位 NPC 可接列表含新 solo + 不在场提示
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/npc_data.dart';
import 'package:westeros_life_simulator/data/npc_task_data.dart';
import 'package:westeros_life_simulator/game_engine.dart';

void main() {
  group('Batch 10-61/62 模板总量', () {
    test('任务模板总数 67 → 72，solo 62，协作 10', () {
      expect(allNpcTaskTemplates.length, 72);
      final coop = allNpcTaskTemplates.where((t) => t.isCoop).toList();
      expect(coop.length, 10);
      final solo = allNpcTaskTemplates.where((t) => !t.isCoop).toList();
      expect(solo.length, 62);
    });

    test('新 solo 模板存在且指向真实 NPC（均为 solo）', () {
      const newTasks = <String, String>{
        'task_jon_arryn_border': 'npc_jon_arryn',
        'task_myrcella_doll': 'npc_myrcella',
        'task_rhaegar_music': 'npc_rhaegar',
        'task_viserys_treaty': 'npc_viserys',
      };
      newTasks.forEach((taskId, npcId) {
        final t = npcTaskTemplateById(taskId);
        expect(t, isNotNull, reason: '$taskId 应存在');
        expect(t!.npcId, npcId, reason: '$taskId 应属于 $npcId');
        expect(t.isCoop, false, reason: '$taskId 应为 solo');
        expect(npcById(npcId), isNotNull, reason: '$npcId 应为真实 NPC');
      });
    });

    test('新协作模板存在，双方同地点（鹰巢城）', () {
      final coop = npcTaskTemplateById('task_jon_arryn_lys_coop');
      expect(coop, isNotNull);
      expect(coop!.isCoop, true);
      expect(coop.npcId, 'npc_jon_arryn');
      expect(coop.coNpcId, 'npc_lys_arryn');
      final a = npcById(coop.npcId)!;
      final b = npcById(coop.coNpcId!)!;
      expect(a.locationId, b.locationId,
          reason: '琼恩·艾林与莱莎·艾林应同地点才能协作');
      expect(a.locationId, 'location_the_eyrie');
    });

    test('任务 ID 与标题全局唯一', () {
      final ids = allNpcTaskTemplates.map((t) => t.id).toSet();
      expect(ids.length, allNpcTaskTemplates.length);
      final titles = allNpcTaskTemplates.map((t) => t.title).toSet();
      expect(titles.length, allNpcTaskTemplates.length,
          reason: '标题不撞既有模板');
    });
  });

  group('Batch 10-61 可接性', () {
    void checkSolo(String npcId, String taskId) {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: <String, int>{npcId: 25},
        ),
      );
      final tasks = engine.availableTasksOf(npcId);
      expect(tasks.map((t) => t.title), contains(
          npcTaskTemplateById(taskId)!.title),
          reason: '$npcId 可接列表应含 $taskId');
      final result = engine.acceptNpcTaskV2(npcId);
      expect(result, contains('不在这里'),
          reason: '$npcId 不在场应提示「不在这里」');
    }

    test('琼恩·艾林（鹰巢城）可接 + 不在场提示', () {
      checkSolo('npc_jon_arryn', 'task_jon_arryn_border');
    });
    test('弥赛拉（君临）可接 + 不在场提示', () {
      checkSolo('npc_myrcella', 'task_myrcella_doll');
    });
    test('雷加·坦格利安（流亡之地）可接 + 不在场提示', () {
      checkSolo('npc_rhaegar', 'task_rhaegar_music');
    });
    test('韦赛里斯（流亡之地）可接 + 不在场提示', () {
      checkSolo('npc_viserys', 'task_viserys_treaty');
    });
  });
}
