/// Batch 10-51 测试：横版继承关系图（谱系概览）。
///
/// 覆盖：
/// 1. 单任历史：1 个先祖节点 + 箭头指向「当代」节点（共 2 节点 / 1 箭头）
/// 2. 两任历史：2 个先祖节点 + 1 中间箭头 + 1 末代箭头 → 共 3 节点 / 2 箭头
/// 3. 无谱系时不显示「继承谱系」横版概览
/// 4. 当代节点高亮（显示「当」徽章与当代姓名）
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/screens/family_tree_screen.dart';

void main() {
  group('Batch 10-51 横版继承关系图', () {
    testWidgets('单任历史：1 先祖 + 1 箭头指向当代（共 2 节点）', (tester) async {
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

      // 横版概览标题 + 节点/箭头
      expect(find.text('继承谱系'), findsOneWidget);
      // 先祖「罗柏」在概览中（第1代徽章 '1' 在 CircleAvatar 内）
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
      // 当代节点徽章「当」
      expect(find.text('当'), findsOneWidget);
      // 两任历史姓名（罗柏 + 当代玩家名）各出现一次（竖排时间轴也有罗柏，用 findsWidgets 宽松）
      expect(find.text('罗柏'), findsWidgets);
    });

    testWidgets('两任历史：2 先祖 + 2 箭头指向当代（共 3 节点）', (tester) async {
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

      expect(find.text('继承谱系'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsNWidgets(2));
      expect(find.text('当'), findsOneWidget);
      expect(find.text('罗柏'), findsWidgets);
      expect(find.text('琼恩'), findsWidgets);
    });

    testWidgets('无谱系时不显示横版概览', (tester) async {
      tester.view.physicalSize = const Size(1080, 12000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final engine = GameEngine()..startNewGame();

      await tester.pumpWidget(
        MaterialApp(home: FamilyTreeScreen(engine: engine)),
      );
      await tester.pumpAndSettle();

      expect(find.text('继承谱系'), findsNothing);
      expect(find.byIcon(Icons.arrow_forward), findsNothing);
      expect(find.text('当'), findsNothing);
    });
  });
}