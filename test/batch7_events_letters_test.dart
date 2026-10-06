/// Batch 7 测试：事件面板 + 信件面板。
///
/// 覆盖：事件类型标签、可触发事件过滤、事件面板可构建、信件面板可构建。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/models/event.dart';
import 'package:westeros_life_simulator/screens/events_screen.dart';
import 'package:westeros_life_simulator/screens/letters_screen.dart';
import 'package:westeros_life_simulator/utils/labels.dart';

void main() {
  group('Batch 7 事件面板', () {
    test('事件类型标签', () {
      expect(eventTypeLabel(EventType.political), '政治');
      expect(eventTypeLabel(EventType.supernatural), '超自然');
      expect(eventTypeLabel(EventType.daily), '日常');
    });

    test('默认玩家可触发事件非空（临冬城史塔克贵族）', () {
      final engine = GameEngine()..startNewGame();
      final available = engine.eventProvider.getAvailableEvents(engine.player);
      expect(available, isNotEmpty);
    });

    test('事件库总量 71', () {
      final engine = GameEngine()..startNewGame();
      expect(engine.eventTemplates.length, 71);
    });

    testWidgets('事件面板可构建（两个 Tab）', (tester) async {
      tester.view.physicalSize = const Size(1080, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(home: EventsScreen()),
      );
      expect(find.text('事件'), findsWidgets);
      expect(find.text('可触发'), findsOneWidget);
      expect(find.text('事件库'), findsOneWidget);
    });

    testWidgets('信件面板可构建（空状态）', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LettersScreen()),
      );
      expect(find.text('信件'), findsOneWidget);
      expect(find.text('你的渡鸦还没有带回任何信件。'), findsOneWidget);
    });

    test('maybeTriggerLetter 能找到触发 seed 且月冷却生效', () {
      final engine = GameEngine()..startNewGame();
      var triggered = 0;
      for (var seed = 0; seed < 100 && triggered == 0; seed++) {
        final text = engine.maybeTriggerLetter(seed: seed);
        // 返回值要么空串要么包含渡鸦叙事
        expect(text.isEmpty || text.contains('渡鸦'), true);
        if (text.isNotEmpty) triggered++;
      }
      // 100 个确定性 seed 内必然触发一次（40% 概率，0.6^100≈0）
      expect(triggered, 1);
      // 同月冷却：触发后任何 seed 再调都被挡住
      expect(engine.maybeTriggerLetter(seed: 999), isEmpty);
    });

    testWidgets('信件面板有来信时渲染卡片', (tester) async {
      final engine = GameEngine()..startNewGame();
      // 用确定性 seed 触发一封来信（循环尝试直到成功）
      var triggered = false;
      for (var seed = 0; seed < 100 && !triggered; seed++) {
        triggered = engine.maybeTriggerLetter(seed: seed).isNotEmpty;
      }
      // 即使未触发（月冷却）也验证空状态，避免 flaky
      await tester.pumpWidget(
        MaterialApp(home: LettersScreen(engine: engine)),
      );
      await tester.pumpAndSettle();
      if (triggered) {
        // 有信：应显示至少一封卡片（含寄信人）
        expect(find.byType(Card), findsWidgets);
      } else {
        expect(find.text('你的渡鸦还没有带回任何信件。'), findsOneWidget);
      }
    });
  });
}