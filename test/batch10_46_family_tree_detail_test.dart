/// Batch 10-46 测试：历代家主详情弹层。
///
/// 覆盖：
/// 1. 点击历代家主节点弹出详情底部弹层（世代徽章/姓名/第 N 代家主/头衔/在位/成就）
/// 2. 成就为空时详情显示「暂无显著功绩」+ 传承寄语
/// 3. 弹层关闭按钮可关闭，列表仍完整
/// 4. 第一代（无谱系）不受影响：仍仅当前世代
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/screens/family_tree_screen.dart';

void main() {
  group('Batch 10-46 历代家主详情弹层', () {
    testWidgets('点击历代节点弹出详情：头衔/在位/成就/寄语', (tester) async {
      tester.view.physicalSize = const Size(1080, 12000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final engine = GameEngine()..startNewGame();
      // 构造多代谱系：第一代 → 传承 → 第二代
      engine.addChild('罗柏');
      final gen2 = engine.advanceGeneration();
      expect(gen2, isNotNull);
      // 第二代继续传承 → 第三代（谱系 2 条）
      engine.addChild('琼恩');
      final gen3 = engine.advanceGeneration();
      expect(gen3, isNotNull);
      expect(engine.player.generationRecords, hasLength(2));

      await tester.pumpWidget(
        MaterialApp(home: FamilyTreeScreen(engine: engine)),
      );
      await tester.pumpAndSettle();

      // 列表区：两代节点 + 查看详情提示
      expect(find.text('第 1 代'), findsOneWidget);
      expect(find.text('第 2 代'), findsOneWidget);
      expect(find.text('查看详情'), findsNWidgets(2));

      // 点击第二代节点（谱系最后一条，列表靠后），用 find.text('第 2 代') 所在卡片
      await tester.tap(find.text('第 2 代'));
      await tester.pumpAndSettle();

      // 弹层内容
      expect(find.text('第 2 代家主'), findsOneWidget);
      expect(find.text('头衔'), findsOneWidget);
      expect(find.text('在位'), findsOneWidget);
      expect(find.text('成就'), findsOneWidget);
      expect(find.text('关闭'), findsOneWidget);
      // 传承寄语（含姓名）
      expect(find.textContaining('名字已刻入家族史册'), findsOneWidget);
    });

    testWidgets('成就为空时详情显示暂无显著功绩', (tester) async {
      tester.view.physicalSize = const Size(1080, 12000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final engine = GameEngine()..startNewGame();
      engine.addChild('罗柏');
      final gen2 = engine.advanceGeneration();
      expect(gen2, isNotNull);
      // 第二代声望低 → 成就为空（advanceGeneration 只在 reputation>=70 记成就）
      // 默认声望 50 → 成就为空
      final gen2Record = engine.player.generationRecords.first;
      expect(gen2Record.achievement, isEmpty);

      await tester.pumpWidget(
        MaterialApp(home: FamilyTreeScreen(engine: engine)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('第 1 代'));
      await tester.pumpAndSettle();

      expect(find.text('暂无显著功绩'), findsOneWidget);
      expect(find.textContaining('名字已刻入家族史册'), findsOneWidget);
    });

    testWidgets('点击关闭按钮可关闭弹层', (tester) async {
      tester.view.physicalSize = const Size(1080, 12000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final engine = GameEngine()..startNewGame();
      engine.addChild('罗柏');
      final gen2 = engine.advanceGeneration();
      expect(gen2, isNotNull);

      await tester.pumpWidget(
        MaterialApp(home: FamilyTreeScreen(engine: engine)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('第 1 代'));
      await tester.pumpAndSettle();
      expect(find.text('关闭'), findsOneWidget);

      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      // 弹层关闭，列表仍在
      expect(find.text('历代家主'), findsOneWidget);
      expect(find.text('第 1 代'), findsOneWidget);
    });

    testWidgets('无谱系时无详情入口（第一代玩家）', (tester) async {
      tester.view.physicalSize = const Size(1080, 12000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final engine = GameEngine()..startNewGame();

      await tester.pumpWidget(
        MaterialApp(home: FamilyTreeScreen(engine: engine)),
      );
      await tester.pumpAndSettle();

      expect(find.text('历代家主'), findsNothing);
      expect(find.text('查看详情'), findsNothing);
      expect(find.text('当前世代'), findsOneWidget);
    });
  });
}
