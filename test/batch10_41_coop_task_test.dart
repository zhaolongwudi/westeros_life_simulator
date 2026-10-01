/// Batch 10-41 测试：多 NPC 协作任务。
///
/// 覆盖：
/// 1. 模型：NpcTaskTemplate.coNpcId / isCoop 协作标记
/// 2. 数据：4 个协作模板存在且 coNpcId 指向真实在场 NPC
/// 3. 可接过滤：协作任务需双方都在场且双方关系 ≥ 相识（20），
///    任一方不满足则不出现
/// 4. 接取：协作任务需双方在场 + 双方关系达标，返回文案标注协作
/// 5. 完成结算：发布方与同伴都获得关系奖励（同伴减半）
/// 6. 任务面板标注协作
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/npc_task_data.dart';
import 'package:westeros_life_simulator/game_engine.dart';

void main() {
  group('Batch 10-41 协作任务模型', () {
    test('isCoop 标记协作任务，单人任务为 false', () {
      expect(allNpcTaskTemplates.length, 54);
      final coop = allNpcTaskTemplates.where((t) => t.isCoop).toList();
      expect(coop.length, 8);
      final solo = allNpcTaskTemplates.where((t) => !t.isCoop).toList();
      expect(solo.length, 44);
      for (final t in coop) {
        expect(t.coNpcId, isNotNull);
        expect(t.coNpcId, isNotEmpty);
      }
      // 单人任务 coNpcId 为 null
      expect(npcTaskTemplateById('task_nev_escort')!.isCoop, false);
      expect(npcTaskTemplateById('task_nev_escort')!.coNpcId, isNull);
    });
    test('协作模板指向真实存在的 NPC', () {
      for (final t in allNpcTaskTemplates.where((t) => t.isCoop)) {
        expect(t.npcId, isNotEmpty);
        expect(t.coNpcId, isNotEmpty);
        expect(t.npcId == t.coNpcId, false, reason: '协作双方不能是同一人');
      }
    });
    test('协作任务 ID 全局唯一', () {
      final ids = allNpcTaskTemplates.map((t) => t.id).toSet();
      expect(ids.length, allNpcTaskTemplates.length);
    });
  });

  group('Batch 10-41 协作任务可接过滤', () {
    test('关系不足（<20）时协作任务不出现', () {
      final engine = GameEngine()..startNewGame();
      // 默认临冬城：艾德在场但双方关系 0，协作任务被过滤
      final tasks = engine.availableTasksOf('npc_nev');
      expect(tasks.map((t) => t.title), isNot(contains('筹备冬季粮仓')));
      // 单人任务仍在
      expect(tasks.map((t) => t.title), contains('护送北境信使至君临'));
    });
    test('发布方关系达标但同伴关系不足时不出现', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{'npc_nev': 25},
        ),
      );
      final tasks = engine.availableTasksOf('npc_nev');
      expect(tasks.map((t) => t.title), isNot(contains('筹备冬季粮仓')));
    });
    test('双方关系都达标时协作任务出现', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{'npc_nev': 25, 'npc_catelyn': 25},
        ),
      );
      final tasks = engine.availableTasksOf('npc_nev');
      expect(tasks.map((t) => t.title), contains('筹备冬季粮仓'));
    });
  });

  group('Batch 10-41 接取协作任务', () {
    test('同伴关系不足时接取被拒', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{'npc_nev': 25},
        ),
      );
      final result = engine.acceptNpcTaskV2(
        'npc_nev',
        taskId: 'task_nev_cat_winter_store',
      );
      expect(result, contains('凯特琳'));
      expect(engine.activeTasks, isEmpty);
    });
    test('双方关系达标后接取成功并标注协作', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{'npc_nev': 25, 'npc_catelyn': 25},
        ),
      );
      final result = engine.acceptNpcTaskV2(
        'npc_nev',
        taskId: 'task_nev_cat_winter_store',
      );
      expect(result, contains('接下'));
      expect(result, contains('凯特琳'));
      expect(engine.activeTasks, hasLength(1));
      expect(engine.activeTasks.first.taskId, 'task_nev_cat_winter_store');
    });
    test('未指定 taskId 时优先接单人任务', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{'npc_nev': 25, 'npc_catelyn': 25},
        ),
      );
      final result = engine.acceptNpcTaskV2('npc_nev');
      expect(result, contains('接下'));
      // 艾德单人任务排在协作任务前
      expect(engine.activeTasks.first.title, '护送北境信使至君临');
    });
  });

  group('Batch 10-41 协作任务完成结算', () {
    test('完成后发布方与同伴都获得关系奖励', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{'npc_nev': 25, 'npc_catelyn': 25},
        ),
      );
      engine.acceptNpcTaskV2(
        'npc_nev',
        taskId: 'task_nev_cat_winter_store',
      );
      final relNevBefore = engine.player.relations['npc_nev'] ?? 0;
      final relCatBefore = engine.player.relations['npc_catelyn'] ?? 0;
      var completed = false;
      var lastText = '';
      for (var i = 0; i < 20 && !completed; i++) {
        lastText = engine.advanceNpcTasks();
        if (lastText.contains('完成')) completed = true;
      }
      expect(completed, true);
      final relNevAfter = engine.player.relations['npc_nev'] ?? 0;
      final relCatAfter = engine.player.relations['npc_catelyn'] ?? 0;
      // 发布方艾德：基础 rewardRelation=8 + 接取 +2
      expect(relNevAfter, greaterThan(relNevBefore));
      // 同伴凯特琳：rewardRelation/2 = 4
      expect(relCatAfter, greaterThan(relCatBefore));
      expect(lastText, contains('凯特琳'));
    });
    test('协作任务面板标注协作', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{'npc_nev': 25, 'npc_catelyn': 25},
        ),
      );
      final panel = engine.formatNpcTaskPanelV2();
      expect(panel, contains('筹备冬季粮仓'));
      expect(panel, contains('凯特琳'));
    });
  });
}
