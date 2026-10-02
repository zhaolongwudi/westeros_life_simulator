/// Batch 10-57 测试：家族树四次深化——当代支脉横版图。
///
/// 覆盖：
/// 1. 已婚有子女：显示「当代支脉」区块，配偶（偶徽章）→ 当代（当徽章）→ 子女（子徽章）
/// 2. 未婚有子女：只有当代 + 子女（配偶节点缺席）
/// 3. 已婚无子女：只有配偶 + 当代（无子徽章）
/// 4. 未婚无子女：不显示「当代支脉」区块（当前世代详情仍渲染）
/// 5. 当代节点高亮 + 徽章文字正确
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/screens/family_tree_screen.dart';

/// 构造一个开局引擎（默认无名者，便于断言）。
GameEngine _freshEngine() => GameEngine()..startNewGame();

void main() {
  group('Batch 10-57 当代支脉横版图', () {
    testWidgets('已婚有子女：配偶(偶)→当代(当)→子女(子) 支脉快照', (tester) async {
      tester.view.physicalSize = const Size(1080, 16000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final engine = _freshEngine();
      engine.marry('平民'); // 有配偶
      engine.addChild('罗柏'); // 有子女
      engine.addChild('艾莉亚');
      await tester.pumpWidget(
        MaterialApp(home: FamilyTreeScreen(engine: engine)),
      );
      await tester.pumpAndSettle();
      // 区块标题
      expect(find.text('当代支脉'), findsOneWidget);
      // 徽章：偶 / 当 / 子×2
      expect(find.text('偶'), findsOneWidget);
      expect(find.text('当'), findsOneWidget);
      expect(find.text('子'), findsNWidgets(2));
      // 当代家主 + 配偶 + 子女姓名（配偶与子女在详情卡片也可能出现，用 findsWidgets 宽松）
      expect(find.text('无名者'), findsWidgets);
      // 配偶名
      expect(engine.player.spouse, isNotNull);
      expect(find.text(engine.player.spouse!.name), findsWidgets);
      // 箭头
      expect(find.byIcon(Icons.arrow_forward), findsWidgets);
    });

    testWidgets('未婚有子女：无偶徽章，当代(当)→子女(子)', (tester) async {
      tester.view.physicalSize = const Size(1080, 16000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final engine = _freshEngine();
      engine.addChild('琼恩');
      await tester.pumpWidget(
        MaterialApp(home: FamilyTreeScreen(engine: engine)),
      );
      await tester.pumpAndSettle();
      expect(find.text('当代支脉'), findsOneWidget);
      expect(find.text('当'), findsOneWidget);
      expect(find.text('子'), findsOneWidget);
      expect(find.text('偶'), findsNothing);
    });

    testWidgets('已婚无子女：偶→当，无子徽章', (tester) async {
      tester.view.physicalSize = const Size(1080, 16000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final engine = _freshEngine();
      engine.marry('贵族');
      await tester.pumpWidget(
        MaterialApp(home: FamilyTreeScreen(engine: engine)),
      );
      await tester.pumpAndSettle();
      expect(find.text('当代支脉'), findsOneWidget);
      expect(find.text('偶'), findsOneWidget);
      expect(find.text('当'), findsOneWidget);
      expect(find.text('子'), findsNothing);
    });

    testWidgets('未婚无子女：不显示当代支脉区块', (tester) async {
      tester.view.physicalSize = const Size(1080, 12000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final engine = _freshEngine();
      await tester.pumpWidget(
        MaterialApp(home: FamilyTreeScreen(engine: engine)),
      );
      await tester.pumpAndSettle();
      expect(find.text('当代支脉'), findsNothing);
      // 当前世代详情仍渲染
      expect(find.text('当前世代'), findsOneWidget);
    });
  });
}