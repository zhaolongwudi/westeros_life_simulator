/// Batch 10-54 测试：新增 NPC 实体（约恩·罗伊斯/布蕾妮·塔斯）+ 任务模板扩充（58 → 61）。
///
/// 覆盖：
/// 1. 数据：2 个新 NPC 实体存在且字段完整（家族/地点/技能/性格）
/// 2. 模板：新 solo ×2、新协作 ×1 存在且指向真实 NPC，协作对双方同地点
/// 3. 约恩协作任务（task_royce_arryn_border）：发布方在鹰巢城且同伴关系达标后出现
/// 4. 布蕾妮 solo 可接性 + 不在场提示「不在这里」
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/npc_data.dart';
import 'package:westeros_life_simulator/data/npc_task_data.dart';
import 'package:westeros_life_simulator/game_engine.dart';

void main() {
  group('Batch 10-54 数据层', () {
    test('新增 2 个 NPC 实体存在且字段完整', () {
      final royce = npcById('npc_royce');
      final brienne = npcById('npc_brienne_tarth');
      expect(royce, isNotNull);
      expect(brienne, isNotNull);
      expect(royce!.name, '约恩·罗伊斯');
      expect(brienne!.name, '布蕾妮·塔斯');
      expect(royce.familyId, 'family_royce');
      expect(brienne.familyId, 'family_tarbeck');
      expect(royce.locationId, 'location_the_eyrie');
      expect(brienne.locationId, 'location_tarbeck');
      expect(royce.skills.isNotEmpty, true);
      expect(brienne.skills.isNotEmpty, true);
    });

    test('新增 3 个任务模板存在且指向真实 NPC', () {
      final solo1 = npcTaskTemplateById('task_royce_clan');
      final coop = npcTaskTemplateById('task_royce_arryn_border');
      final solo2 = npcTaskTemplateById('task_brienne_escort');
      expect(solo1, isNotNull);
      expect(solo2, isNotNull);
      expect(coop, isNotNull);

      expect(solo1!.npcId, 'npc_royce');
      expect(solo1.isCoop, false);
      expect(coop!.npcId, 'npc_royce');
      expect(coop.coNpcId, 'npc_jon_arryn');
      expect(coop.isCoop, true);
      expect(npcById(coop.coNpcId!), isNotNull);
      expect(solo2!.npcId, 'npc_brienne_tarth');
      expect(solo2.isCoop, false);
    });

    test('新协作对子双方同地点（在场判断前提）', () {
      final a = npcById('npc_royce')!;
      final b = npcById('npc_jon_arryn')!;
      expect(a.locationId, b.locationId,
          reason: '约恩与琼恩·艾林应同地点才能协作');
      expect(a.locationId, 'location_the_eyrie');
    });

    test('任务 ID 全局唯一（含新增 3 个）', () {
      final ids = allNpcTaskTemplates.map((t) => t.id).toSet();
      expect(ids.length, allNpcTaskTemplates.length);
    });
  });

  group('Batch 10-54 约恩协作任务', () {
    test('发布方约恩在鹰巢城且同伴关系达标后协作任务出现', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          locationId: 'location_the_eyrie',
          relations: const <String, int>{
            'npc_royce': 25,
            'npc_jon_arryn': 25,
          },
        ),
      );
      final tasks = engine.availableTasksOf('npc_royce');
      expect(tasks.map((t) => t.title), contains('排查谷地边境的部族异动'));
    });

    test('同伴关系不足时协作任务不出现', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          locationId: 'location_the_eyrie',
          relations: const <String, int>{'npc_royce': 25},
        ),
      );
      final tasks = engine.availableTasksOf('npc_royce');
      expect(tasks.map((t) => t.title), isNot(contains('排查谷地边境的部族异动')));
    });

    test('接取协作任务成功后标注协作（琼恩·艾林）', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          locationId: 'location_the_eyrie',
          relations: const <String, int>{
            'npc_royce': 25,
            'npc_jon_arryn': 25,
          },
        ),
      );
      final result = engine.acceptNpcTaskV2(
        'npc_royce',
        taskId: 'task_royce_arryn_border',
      );
      expect(result, contains('接下'));
      expect(result, contains('琼恩·艾林'));
      expect(engine.activeTasks, hasLength(1));
      expect(engine.activeTasks.first.taskId, 'task_royce_arryn_border');
    });
  });

  group('Batch 10-54 布蕾妮 solo', () {
    test('不在场时接取提示「不在这里」', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{'npc_brienne_tarth': 25},
        ),
      );
      final result = engine.acceptNpcTaskV2('npc_brienne_tarth');
      expect(result, contains('不在这里'));
    });
  });
}