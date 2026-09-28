/// Batch 10-24 测试：NPC 任务进度 UI 化（进度条 + 期限倒计时）。
///
/// 覆盖：
/// 1. NpcTaskTemplate.totalTurns：模板总推进次数
/// 2. 接任务后生成实例的派生进度（npcTaskOverallRatio/npcTaskRemainingMonths）
/// 3. advanceNpcTasks 推进后进度百分比递增
/// 4. npc_panel UI：进行中任务显示进度条/剩余月数/当前步骤
/// 5. 既有契约回归：formatNpcTaskProgressPanel 含「任务进度/期限」
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/npc_task_data.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/screens/npc_panel_screen.dart';

void main() {
  group('Batch 10-24 NpcTaskTemplate.totalTurns', () {
    test('护送任务总推进次数为各步之和', () {
      final template = npcTaskTemplateById('task_nev_escort');
      expect(template, isNotNull);
      // 步骤 turnsRequired 1+2+2=5
      expect(template!.totalTurns, 5);
      expect(template.steps.length, 3);
    });

    test('两步任务 totalTurns 正确', () {
      final template = npcTaskTemplateById('task_nev_wildling');
      expect(template, isNotNull);
      expect(template!.totalTurns, 2);
    });
  });

  group('Batch 10-24 任务派生进度', () {
    test('接任务初始进度为 0 且剩余月数=期限月数', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{'npc_nev': 25},
        ),
      );
      final result = engine.acceptNpcTaskV2('npc_nev');
      expect(result, contains('接下'));
      final task = engine.activeTasks.first;
      // 艾德护送任务 totalTurns=5，初始 stepProgress=0
      expect(engine.npcTaskOverallRatio(task), 0.0);
      // 默认 283 年 3 月接，期限 283 年 8 月 → 剩余 5 个月
      expect(engine.npcTaskRemainingMonths(task), 5);
      // 当前步骤描述
      expect(
        engine.npcTaskCurrentStepDesc(task),
        contains('集结护卫'),
      );
      expect(engine.npcTaskTotalSteps(task), 3);
    });

    test('推进后整体进度按推进次数递增', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{'npc_nev': 25},
        ),
      );
      engine.acceptNpcTaskV2('npc_nev');
      final task = engine.activeTasks.first;
      expect(engine.npcTaskOverallRatio(task), 0.0);

      // 推进 1 次：第一步 turnsRequired=1 完成 → 进度 1/5=0.2
      engine.advanceNpcTasks();
      final t1 = engine.activeTasks.first;
      expect(engine.npcTaskOverallRatio(t1), closeTo(0.2, 0.001));
      expect(t1.stepIndex, 1);

      // 再推进 1 次：第二步 turnsRequired=2 中段 → 进度 2/5=0.4
      engine.advanceNpcTasks();
      final t2 = engine.activeTasks.first;
      expect(engine.npcTaskOverallRatio(t2), closeTo(0.4, 0.001));
      expect(t2.stepIndex, 1);
      expect(t2.stepProgress, 1);
    });

    test('完成全部步骤进度为 1.0', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{'npc_nev': 25},
        ),
      );
      engine.acceptNpcTaskV2('npc_nev');
      // 艾德护送任务 5 次推进全部完成
      for (var i = 0; i < 5; i++) {
        engine.advanceNpcTasks();
      }
      final task = engine.activeTasks.first;
      expect(task.completed, true);
      expect(engine.npcTaskOverallRatio(task), 1.0);
    });

    test('剩余月数随过月递减', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{'npc_nev': 25},
        ),
      );
      engine.acceptNpcTaskV2('npc_nev');
      expect(engine.npcTaskRemainingMonths(engine.activeTasks.first), 5);
      // 过 1 个月 → 剩余 4
      engine.advanceMonth();
      expect(engine.npcTaskRemainingMonths(engine.activeTasks.first), 4);
    });
  });

  group('Batch 10-24 formatNpcTaskProgressPanel 增强', () {
    test('进行中任务显示剩余月数与进度百分比', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{'npc_nev': 25},
        ),
      );
      engine.acceptNpcTaskV2('npc_nev');
      final panel = engine.formatNpcTaskProgressPanel();
      expect(panel, contains('任务进度'));
      expect(panel, contains('期限'));
      expect(panel, contains('剩余 5 个月'));
      expect(panel, contains('进度 0%'));
      // 推进一次后
      engine.advanceNpcTasks();
      final panel2 = engine.formatNpcTaskProgressPanel();
      expect(panel2, contains('进度 20%'));
      expect(panel2, contains('剩余 5 个月'));
    });
  });

  group('Batch 10-24 npc_panel 进度条 UI', () {
    testWidgets('进行中任务显示进度条/剩余月数/当前步骤', (tester) async {
      tester.view.physicalSize = const Size(1080, 12000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{'npc_nev': 25},
        ),
      );
      final acceptResult = engine.acceptNpcTaskV2('npc_nev');
      expect(acceptResult, contains('接下'));

      await tester.pumpWidget(
        MaterialApp(home: NpcPanelScreen(engine: engine)),
      );
      await tester.pumpAndSettle();

      // 区块标题与既有契约
      expect(find.text('进行中的任务'), findsOneWidget);
      // 既有断言兼容：标题 + 状态｜期限
      expect(find.textContaining('⏳ 进行中｜期限'), findsOneWidget);
      expect(find.textContaining('⏳ 进行中'), findsWidgets);
      // 新增：进度条渲染
      expect(find.byType(LinearProgressIndicator), findsWidgets);
      // 剩余月数 + 进度 + 当前步骤
      expect(find.textContaining('剩余 5 个月'), findsOneWidget);
      expect(find.textContaining('进度 0%'), findsOneWidget);
      expect(find.textContaining('第 1/3 步'), findsOneWidget);
    });

    testWidgets('任务推进后 UI 进度条值更新', (tester) async {
      tester.view.physicalSize = const Size(1080, 12000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{'npc_nev': 25},
        ),
      );
      engine.acceptNpcTaskV2('npc_nev');
      engine.advanceNpcTasks();

      await tester.pumpWidget(
        MaterialApp(home: NpcPanelScreen(engine: engine)),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('进度 20%'), findsOneWidget);
      expect(find.textContaining('第 2/3 步'), findsOneWidget);
    });

    testWidgets('无任务空态仍显示', (tester) async {
      tester.view.physicalSize = const Size(1080, 12000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final engine = GameEngine()..startNewGame();
      await tester.pumpWidget(
        MaterialApp(home: NpcPanelScreen(engine: engine)),
      );
      await tester.pumpAndSettle();

      expect(find.text('进行中的任务'), findsOneWidget);
      expect(find.text('目前没有进行中的任务。'), findsOneWidget);
      // 无任务不应有进度条
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });
  });
}
