/// Batch 10-42 测试：任务放弃与失败反馈增强。
///
/// 覆盖：
/// 1. 模型：NpcTaskProgress.abandoned 字段（序列化往返）
/// 2. 放弃指令：按标题匹配、关系 -2、无声望惩罚、协作任务双 NPC 关系 -2
/// 3. 放弃状态展示：进度面板「🗑️ 已放弃」
/// 4. 逾期失败增强：协作任务逾期双方关系都扣（-5 / -3）+ 类型差异化失败描述
/// 5. 指令注册：放弃/quit 可执行、帮助文本含放弃行
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/models/npc_task.dart';

void main() {
  group('Batch 10-42 放弃任务模型', () {
    test('abandoned 字段默认 false 且序列化往返', () {
      final p = NpcTaskProgress(
        taskId: 'task_nev_escort',
        npcId: 'npc_nev',
        title: '护送北境信使至君临',
        stepIndex: 1,
        stepProgress: 1,
        deadlineYear: 283,
        deadlineMonth: 8,
      );
      expect(p.abandoned, false);
      expect(p.isActive, true);
      final restored = NpcTaskProgress.fromJson(p.toJson());
      expect(restored.abandoned, false);
      expect(restored.isActive, true);
      final abandoned = p.copyWith(abandoned: true);
      expect(abandoned.abandoned, true);
      expect(abandoned.isActive, false);
      final restored2 = NpcTaskProgress.fromJson(abandoned.toJson());
      expect(restored2.abandoned, true);
      expect(restored2.isActive, false);
    });
    test('旧存档无 abandoned 字段时防御式读取为 false', () {
      final json = {
        'taskId': 'task_nev_escort',
        'npcId': 'npc_nev',
        'title': '旧任务',
        'stepIndex': 0,
        'stepProgress': 0,
        'deadlineYear': 283,
        'deadlineMonth': 8,
        'completed': false,
        'failed': false,
      };
      final p = NpcTaskProgress.fromJson(json);
      expect(p.abandoned, false);
      expect(p.isActive, true);
    });
  });

  group('Batch 10-42 放弃任务指令', () {
    test('放弃进行中任务：关系 -2、无声望惩罚、标记 abandoned', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{'npc_nev': 25},
        ),
      );
      engine.acceptNpcTaskV2('npc_nev');
      final relBefore = engine.player.relations['npc_nev'] ?? 0;
      final repBefore = engine.player.reputation;
      final result = engine.abandonNpcTask('护送');
      expect(result, contains('放弃'));
      expect(result, contains('护送北境信使至君临'));
      expect(engine.player.relations['npc_nev'] ?? 0, relBefore - 2);
      expect(engine.player.reputation, repBefore);
      expect(engine.activeTasks.first.abandoned, true);
      expect(engine.activeTasks.first.isActive, false);
    });
    test('放弃协作任务：发布方与同伴都扣关系', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{
            'npc_nev': 25,
            'npc_catelyn': 25,
          },
        ),
      );
      engine.acceptNpcTaskV2(
        'npc_nev',
        taskId: 'task_nev_cat_winter_store',
      );
      final relNevBefore = engine.player.relations['npc_nev'] ?? 0;
      final relCatBefore = engine.player.relations['npc_catelyn'] ?? 0;
      final result = engine.abandonNpcTask('粮仓');
      expect(result, contains('凯特琳'));
      expect(engine.player.relations['npc_nev'] ?? 0, relNevBefore - 2);
      expect(engine.player.relations['npc_catelyn'] ?? 0, relCatBefore - 2);
      expect(engine.activeTasks.first.abandoned, true);
    });
    test('无进行中任务时返回说明', () {
      final engine = GameEngine()..startNewGame();
      final result = engine.abandonNpcTask('护送');
      expect(result, contains('没有进行中的任务'));
    });
    test('进度面板显示已放弃状态', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{'npc_nev': 25},
        ),
      );
      engine.acceptNpcTaskV2('npc_nev');
      engine.abandonNpcTask('护送');
      final panel = engine.formatNpcTaskProgressPanel();
      expect(panel, contains('已放弃'));
      expect(panel, contains('护送北境信使至君临'));
    });
  });

  group('Batch 10-42 逾期失败反馈增强', () {
    test('协作任务逾期失败：发布方 -5、同伴 -3、文案含双方', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{
            'npc_nev': 30,
            'npc_catelyn': 30,
          },
        ),
      );
      engine.acceptNpcTaskV2(
        'npc_nev',
        taskId: 'task_nev_cat_winter_store',
      );
      // 直接把期限拨到过去触发逾期
      final task = engine.activeTasks.first;
      engine.updatePlayer(
        engine.player.copyWith(
          activeTasks: [
            task.copyWith(
              deadlineYear: 282,
              deadlineMonth: 1,
            ),
          ],
        ),
      );
      final relNevBefore = engine.player.relations['npc_nev'] ?? 0;
      final relCatBefore = engine.player.relations['npc_catelyn'] ?? 0;
      final text = engine.checkNpcTaskDeadlines();
      expect(text, contains('委托失败'));
      expect(text, contains('凯特琳'));
      expect(engine.player.relations['npc_nev'] ?? 0, relNevBefore - 5);
      expect(engine.player.relations['npc_catelyn'] ?? 0, relCatBefore - 3);
      expect(engine.activeTasks.first.failed, true);
    });
    test('单人任务逾期失败：文案含类型差异化描述', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{'npc_nev': 25},
        ),
      );
      engine.acceptNpcTaskV2('npc_nev'); // 护送任务（escort）
      final task = engine.activeTasks.first;
      engine.updatePlayer(
        engine.player.copyWith(
          activeTasks: [
            task.copyWith(
              deadlineYear: 282,
              deadlineMonth: 1,
            ),
          ],
        ),
      );
      final text = engine.checkNpcTaskDeadlines();
      expect(text, contains('失信于人'));
      expect(text, isNot(contains('凯特琳')));
      expect(engine.activeTasks.first.failed, true);
    });
  });

  group('Batch 10-42 指令注册', () {
    test('放弃指令可执行且帮助文本含放弃行', () {
      final engine = GameEngine()..startNewGame();
      final reg = engine.commandRegistry;
      final help = reg.helpText();
      expect(help, contains('放弃 / quit'));
      expect(reg.specCount, 47);
      // 通过指令入口执行：未接任务时返回说明
      final result = engine.resolveCommand('放弃 不存在的任务').text;
      expect(result, contains('没有进行中的任务'));
    });
  });
}