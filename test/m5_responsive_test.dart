/// Batch 10-36 测试：M5 体验层收尾——响应式适配。
///
/// 覆盖：
/// 1. AdaptiveFrame：窄屏（<600）原样全宽、宽屏（>=600）限宽居中
/// 2. GameScreen：宽屏叙事区限宽 700 + 窄屏状态条全宽 + 既有契约不回归
/// 3. PlayerPanelScreen / FamilyTreeScreen：宽屏内容限宽 900
///
/// 契约：AppBar 标题、「AI 行动模式」开关、初始叙事等既有断言点不回归。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/screens/family_tree_screen.dart';
import 'package:westeros_life_simulator/screens/game_screen.dart';
import 'package:westeros_life_simulator/screens/player_panel_screen.dart';
import 'package:westeros_life_simulator/widgets/game/responsive.dart';
import 'package:westeros_life_simulator/widgets/game/status.dart';

void main() {
  group('M5 响应式 · AdaptiveFrame', () {
    testWidgets('窄屏（<600）原样全宽，不包裹 Center', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      const childKey = Key('adaptive-child');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdaptiveFrame(
              child: SizedBox(
                key: childKey,
                width: 350,
                height: 100,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 窄屏未限宽：child 保持自身宽度 350
      expect(tester.getSize(find.byKey(childKey)).width, 350);
      // 窄屏直接返回 child，不引入 Center 壳
      expect(find.byType(Center), findsNothing);
    });

    testWidgets('宽屏（>=600）限宽到 maxWidth', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      const childKey = Key('adaptive-child');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdaptiveFrame(
              maxWidth: 900,
              child: SizedBox(
                key: childKey,
                width: 2000,
                height: 100,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 宽屏被 clamp 到 maxWidth 900
      expect(tester.getSize(find.byKey(childKey)).width, 900);

      // 换一个 maxWidth 验证可配置
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdaptiveFrame(
              maxWidth: 700,
              child: SizedBox(
                key: childKey,
                width: 2000,
                height: 100,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(childKey)).width, 700);
    });
  });

  group('M5 响应式 · GameScreen', () {
    testWidgets('宽屏叙事区限宽 700 + 既有契约不回归', (tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final engine = GameEngine()..startNewGame();
      await tester.pumpWidget(
        MaterialApp(home: GameScreen(engine: engine)),
      );
      await tester.pumpAndSettle();

      // 既有契约：初始叙事 + AI 开关 仍在
      expect(find.textContaining('欢迎来到维斯特洛'), findsOneWidget);
      expect(find.text('AI 行动模式'), findsOneWidget);
      // 宽屏限宽：状态条宽度 <= 700
      final statusWidth = tester.getSize(find.byType(StatusBar)).width;
      expect(statusWidth, lessThanOrEqualTo(700));
    });

    testWidgets('窄屏状态条全宽', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final engine = GameEngine()..startNewGame();
      await tester.pumpWidget(
        MaterialApp(home: GameScreen(engine: engine)),
      );
      await tester.pumpAndSettle();

      // 窄屏未限宽：状态条占满 400
      expect(tester.getSize(find.byType(StatusBar)).width, 400);
    });
  });

  group('M5 响应式 · 面板', () {
    testWidgets('PlayerPanelScreen 宽屏内容限宽 900', (tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final engine = GameEngine()..startNewGame();
      await tester.pumpWidget(
        MaterialApp(home: PlayerPanelScreen(engine: engine)),
      );
      await tester.pumpAndSettle();

      expect(find.text('玩家详情'), findsOneWidget);
      expect(tester.getSize(find.byType(ListView)).width, 900);
    });

    testWidgets('FamilyTreeScreen 宽屏内容限宽 900', (tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final engine = GameEngine()..startNewGame();
      await tester.pumpWidget(
        MaterialApp(home: FamilyTreeScreen(engine: engine)),
      );
      await tester.pumpAndSettle();

      expect(find.text('家族树'), findsOneWidget);
      expect(find.textContaining('当前世代'), findsOneWidget);
      expect(tester.getSize(find.byType(ListView)).width, 900);
    });
  });
}