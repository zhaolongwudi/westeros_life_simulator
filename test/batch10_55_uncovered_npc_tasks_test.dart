/// Batch 10-55 测试：未覆盖 NPC solo 任务模板扩充（61 → 67）。
///
/// 覆盖：
/// 1. 数据：6 个新 solo 模板存在且指向真实 NPC（杰奥/艾德慕/瓦德/莱莎/乔佛瑞/托曼）
/// 2. 全部为 solo（非协作），ID 唯一
/// 3. 6 位 NPC 可接列表含新模板
/// 4. 不在场接取提示「不在这里」
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/npc_data.dart';
import 'package:westeros_life_simulator/data/npc_task_data.dart';
import 'package:westeros_life_simulator/game_engine.dart';

void main() {
  group('Batch 10-55 模板总量', () {
    test('任务模板总数 61 → 67，solo 58，协作 9 不变', () {
      expect(allNpcTaskTemplates.length, 67);
      final coop = allNpcTaskTemplates.where((t) => t.isCoop).toList();
      expect(coop.length, 9);
      final solo = allNpcTaskTemplates.where((t) => !t.isCoop).toList();
      expect(solo.length, 58);
    });

    test('新模板存在且指向真实 NPC（均为 solo）', () {
      const newTasks = <String, String>{
        'task_geor_wildling_scout': 'npc_geor_mormont',
        'task_edmure_levy': 'npc_edmure_tully',
        'task_walder_toll': 'npc_walder_frey',
        'task_lys_hawk': 'npc_lys_arryn',
        'task_joffrey_tourney': 'npc_joffrey',
        'task_tommen_books': 'npc_tommen',
      };
      newTasks.forEach((taskId, npcId) {
        final t = npcTaskTemplateById(taskId);
        expect(t, isNotNull, reason: '$taskId 应存在');
        expect(t!.npcId, npcId, reason: '$taskId 应属于 $npcId');
        expect(t.isCoop, false, reason: '$taskId 应为 solo');
        expect(npcById(npcId), isNotNull, reason: '$npcId 应为真实 NPC');
      });
    });

    test('任务 ID 全局唯一', () {
      final ids = allNpcTaskTemplates.map((t) => t.id).toSet();
      expect(ids.length, allNpcTaskTemplates.length);
      final titles = allNpcTaskTemplates.map((t) => t.title).toSet();
      expect(titles.length, allNpcTaskTemplates.length,
          reason: '标题不撞既有模板');
    });
  });

  group('Batch 10-55 可接性', () {
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

    test('杰奥·莫尔蒙（黑城堡）可接 + 不在场提示', () {
      checkSolo('npc_geor_mormont', 'task_geor_wildling_scout');
    });
    test('艾德慕·徒利（奔流城）可接 + 不在场提示', () {
      checkSolo('npc_edmure_tully', 'task_edmure_levy');
    });
    test('瓦德·佛雷（孪河城）可接 + 不在场提示', () {
      checkSolo('npc_walder_frey', 'task_walder_toll');
    });
    test('莱莎·艾林（鹰巢城）可接 + 不在场提示', () {
      checkSolo('npc_lys_arryn', 'task_lys_hawk');
    });
    test('乔佛瑞（君临）可接 + 不在场提示', () {
      checkSolo('npc_joffrey', 'task_joffrey_tourney');
    });
    test('托曼（君临）可接 + 不在场提示', () {
      checkSolo('npc_tommen', 'task_tommen_books');
    });
  });
}