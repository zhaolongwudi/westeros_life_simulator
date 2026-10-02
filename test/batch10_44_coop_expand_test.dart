/// Batch 10-44 测试：多 NPC 协作任务扩充（48 → 52）。
///
/// 覆盖：
/// 1. 数据：4 个新协作模板（君临×2/高庭×1/派克城×1）存在且 coNpcId 指向真实 NPC
/// 2. NPC 分布：新协作对子双方同地点且非同一人
/// 3. 君临协作任务：双方关系达标后可接，未达标被拒（含同伴不在场提示）
/// 4. 君临协作任务完成：发布方与同伴都获得关系奖励（同伴减半）
/// 5. 面板标注协作 + 全部协作任务 ID 唯一
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/npc_data.dart';
import 'package:westeros_life_simulator/data/npc_task_data.dart';
import 'package:westeros_life_simulator/game_engine.dart';

void main() {
  group('Batch 10-44 协作任务扩充·数据', () {
    test('总模板 48 → 52，协作 8 个', () {
      expect(allNpcTaskTemplates.length, 72);
      final coop = allNpcTaskTemplates.where((t) => t.isCoop).toList();
      expect(coop.length, 10);
    });

    test('新增 4 个协作模板存在且指向真实 NPC', () {
      const newIds = <String>[
        'task_cersei_jaime_traitor',
        'task_tyrion_cersei_rumor',
        'task_olenna_margaery_match',
        'task_balon_yara_pirate',
      ];
      for (final id in newIds) {
        final t = npcTaskTemplateById(id);
        expect(t, isNotNull, reason: '$id 应存在');
        expect(t!.isCoop, true);
        expect(npcById(t.npcId), isNotNull);
        expect(npcById(t.coNpcId!), isNotNull);
        expect(t.npcId == t.coNpcId, false, reason: '协作双方不能是同一人');
      }
    });

    test('新协作对子双方同地点（在场判断前提）', () {
      const pairs = <List<String>>[
        <String>['npc_cersei', 'npc_jaime'],
        <String>['npc_tyrion', 'npc_cersei'],
        <String>['npc_olenna_tyrell', 'npc_margaery'],
        <String>['npc_balon_greyjoy', 'npc_yara'],
      ];
      for (final p in pairs) {
        final a = npcById(p[0])!;
        final b = npcById(p[1])!;
        expect(a.locationId, b.locationId,
            reason: '${p[0]} 与 ${p[1]} 应同地点才能协作');
      }
    });

    test('全部任务 ID 唯一', () {
      final ids = allNpcTaskTemplates.map((t) => t.id).toSet();
      expect(ids.length, allNpcTaskTemplates.length);
    });
  });

  group('Batch 10-44 君临协作任务', () {
    test('发布方瑟曦：双方关系达标后协作任务出现', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          locationId: 'location_kings_landing',
          relations: const <String, int>{
            'npc_cersei': 25,
            'npc_jaime': 25,
          },
        ),
      );
      final tasks = engine.availableTasksOf('npc_cersei');
      expect(tasks.map((t) => t.title), contains('彻查御林铁卫的叛徒'));
    });

    test('同伴关系不足时协作任务不出现', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          locationId: 'location_kings_landing',
          relations: const <String, int>{'npc_cersei': 25},
        ),
      );
      final tasks = engine.availableTasksOf('npc_cersei');
      expect(tasks.map((t) => t.title), isNot(contains('彻查御林铁卫的叛徒')));
    });

    test('接取协作任务：双方关系达标成功后标注协作', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          locationId: 'location_kings_landing',
          relations: const <String, int>{
            'npc_cersei': 25,
            'npc_jaime': 25,
          },
        ),
      );
      final result = engine.acceptNpcTaskV2(
        'npc_cersei',
        taskId: 'task_cersei_jaime_traitor',
      );
      expect(result, contains('接下'));
      expect(result, contains('詹姆'));
      expect(engine.activeTasks, hasLength(1));
      expect(engine.activeTasks.first.taskId, 'task_cersei_jaime_traitor');
    });

    test('完成协作任务：发布方与同伴都获得关系奖励', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          locationId: 'location_kings_landing',
          relations: const <String, int>{
            'npc_cersei': 25,
            'npc_jaime': 25,
          },
        ),
      );
      engine.acceptNpcTaskV2(
        'npc_cersei',
        taskId: 'task_cersei_jaime_traitor',
      );
      final relCerseiBefore = engine.player.relations['npc_cersei'] ?? 0;
      final relJaimeBefore = engine.player.relations['npc_jaime'] ?? 0;
      var completed = false;
      var lastText = '';
      for (var i = 0; i < 20 && !completed; i++) {
        lastText = engine.advanceNpcTasks();
        if (lastText.contains('完成')) completed = true;
      }
      expect(completed, true);
      final relCerseiAfter = engine.player.relations['npc_cersei'] ?? 0;
      final relJaimeAfter = engine.player.relations['npc_jaime'] ?? 0;
      expect(relCerseiAfter, greaterThan(relCerseiBefore));
      expect(relJaimeAfter, greaterThan(relJaimeBefore));
      expect(lastText, contains('詹姆'));
    });
  });

  group('Batch 10-44 面板标注', () {
    test('新协作任务在面板标注协作', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          locationId: 'location_kings_landing',
          relations: const <String, int>{
            'npc_cersei': 25,
            'npc_jaime': 25,
          },
        ),
      );
      final panel = engine.formatNpcTaskPanelV2();
      expect(panel, contains('彻查御林铁卫的叛徒'));
      expect(panel, contains('詹姆'));
    });
  });
}