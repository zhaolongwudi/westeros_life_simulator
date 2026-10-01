/// Batch 10-49 测试：谱系继承连线画布。
///
/// 覆盖：
/// 1. 两代谱系：每任家主间显示「继承」连线，末代显示「传至当代」
/// 2. 三代谱系：2 条继承 + 1 条传至当代（无谱系时无连线）
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/screens/family_tree_screen.dart';

void main() {
  group('Batch 10-49 谱系继承连线', () {
    testWidgets('两代谱系：1 继承 + 1 传至当代', (tester) async {
      tester.view.physicalSize = const Size(1080, 12000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final engine = GameEngine()..startNewGame();
      engine.addChild('罗柏');
      final gen2 = engine.advanceGeneration();
      expect(gen2, isNotNull);
      expect(engine.player.generationRecords, hasLength(1));

      await tester.pumpWidget(
        MaterialApp(home: FamilyTreeScreen(engine: engine)),
      );
      await tester.pumpAndSettle();

      // 一任历史：非末代（指向下一任）→ 无「继承」；末代 → 「传至当代」
      expect(find.text('第 1 代'), findsOneWidget);
      expect(find.text('继承'), findsNothing);
      expect(find.text('传至当代'), findsOneWidget);
      expect(find.byIcon(Icons.south), findsOneWidget);
    });

    testWidgets('两任历史谱系：1 继承 + 1 传至当代', (tester) async {
      tester.view.physicalSize = const Size(1080, 12000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final engine = GameEngine()..startNewGame();
      engine.addChild('罗柏');
      final gen2 = engine.advanceGeneration();
      expect(gen2, isNotNull);
      engine.addChild('琼恩');
      final gen3 = engine.advanceGeneration();
      expect(gen3, isNotNull);
      expect(engine.player.generationRecords, hasLength(2));

      await tester.pumpWidget(
        MaterialApp(home: FamilyTreeScreen(engine: engine)),
      );
      await tester.pumpAndSettle();

      // 两任历史：第 1 代（继承）+ 第 2 代（末代→传至当代）
      expect(find.text('第 1 代'), findsOneWidget);
      expect(find.text('第 2 代'), findsOneWidget);
      expect(find.text('继承'), findsOneWidget);
      expect(find.text('传至当代'), findsOneWidget);
      expect(find.byIcon(Icons.south), findsNWidgets(2));
    });

    testWidgets('无谱系时无连线（第一代玩家）', (tester) async {
      tester.view.physicalSize = const Size(1080, 12000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final engine = GameEngine()..startNewGame();

      await tester.pumpWidget(
        MaterialApp(home: FamilyTreeScreen(engine: engine)),
      );
      await tester.pumpAndSettle();

      expect(find.text('历代家主'), findsNothing);
      expect(find.text('继承'), findsNothing);
      expect(find.text('传至当代'), findsNothing);
      expect(find.byIcon(Icons.south), findsNothing);
    });
  });
}
