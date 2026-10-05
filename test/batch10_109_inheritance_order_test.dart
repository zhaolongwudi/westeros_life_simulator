/// Batch 10-109 测试：家族树「继承顺位」区块。
///
/// 覆盖：
/// 1. 有子女时显示「继承顺位」区块，按出生顺序列出顺位（第一/第二顺位）
/// 2. 继承人（长子/首个在世）附加「👑 继承人」徽章
/// 3. 培养档案（培养方向/已督导/进修中）随子女行展示
/// 4. 无子女时不显示继承顺位区块（当前世代空态不受影响）
/// 5. 长子已亡时，继承人徽章落在次子（heirName 语义：跳过 childDead）
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/screens/family_tree_screen.dart';

GameEngine _freshEngine() => GameEngine()..startNewGame();

void main() {
  group('Batch 10-109 继承顺位区块', () {
    testWidgets('有子女显示继承顺位：第一/第二顺位 + 继承人徽章', (tester) async {
      tester.view.physicalSize = const Size(1080, 16000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final engine = _freshEngine();
      engine.addChild('罗柏');
      engine.addChild('珊莎');
      await tester.pumpWidget(
        MaterialApp(home: FamilyTreeScreen(engine: engine)),
      );
      await tester.pumpAndSettle();
      expect(find.text('继承顺位'), findsOneWidget);
      expect(find.textContaining('罗柏（第一顺位）'), findsOneWidget);
      expect(find.textContaining('珊莎（第二顺位）'), findsOneWidget);
      // 长子为继承人 → 一枚徽章
      expect(find.text('👑 继承人'), findsOneWidget);
    });

    testWidgets('培养档案随子女行展示（培养/已督导/进修中）', (tester) async {
      tester.view.physicalSize = const Size(1080, 16000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final engine = _freshEngine();
      engine.addChild('罗柏');
      engine.addChild('琼恩');
      engine.rearChild('罗柏', 'sword');
      engine.tutorChild('罗柏');
      engine.sendChildToSchool('琼恩');
      await tester.pumpWidget(
        MaterialApp(home: FamilyTreeScreen(engine: engine)),
      );
      await tester.pumpAndSettle();
      expect(find.text('继承顺位'), findsOneWidget);
      // 罗柏行（卡片 Key 锚定）：培养 + 已督导
      // 支脉节点带姓名前缀（罗柏：…），卡片行不带，故按 Key 隔离断言。
      // Key 挂在 Text 上，直接读 Text.data（descendant 找不到 Text 自身的文本）。
      final robbText =
          tester.widget<Text>(find.byKey(const Key('inherit-rearing-罗柏')));
      expect(robbText.data, contains('培养：sword'));
      expect(robbText.data, contains('已督导'));
      // 琼恩行（卡片 Key 锚定）：进修中
      final jonText =
          tester.widget<Text>(find.byKey(const Key('inherit-rearing-琼恩')));
      expect(jonText.data, contains('进修中'));
      // 罗柏为继承人（长子）
      expect(find.text('👑 继承人'), findsOneWidget);
    });

    testWidgets('长子已亡时继承人徽章落在次子', (tester) async {
      tester.view.physicalSize = const Size(1080, 16000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final engine = _freshEngine();
      engine.addChild('罗柏');
      engine.addChild('琼恩');
      engine.setFlag('house.childDead.罗柏', true);
      expect(engine.heirName, '琼恩');
      await tester.pumpWidget(
        MaterialApp(home: FamilyTreeScreen(engine: engine)),
      );
      await tester.pumpAndSettle();
      expect(find.text('继承顺位'), findsOneWidget);
      // 两行顺位都在，徽章只挂在琼恩（次子）
      expect(find.textContaining('罗柏（第一顺位）'), findsOneWidget);
      expect(find.textContaining('琼恩（第二顺位）'), findsOneWidget);
      expect(find.text('👑 继承人'), findsOneWidget);
    });

    testWidgets('无子女时不显示继承顺位区块', (tester) async {
      tester.view.physicalSize = const Size(1080, 12000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final engine = _freshEngine();
      await tester.pumpWidget(
        MaterialApp(home: FamilyTreeScreen(engine: engine)),
      );
      await tester.pumpAndSettle();
      expect(find.text('继承顺位'), findsNothing);
      // 当前世代空态仍在
      expect(find.text('当前世代'), findsOneWidget);
      expect(find.text('子女：尚无子嗣'), findsOneWidget);
    });
  });
}
