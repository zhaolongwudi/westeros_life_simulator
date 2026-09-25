/// Batch 10-12 测试：UI 叙事体验打磨。
///
/// 覆盖：
/// 1. narrative_format.splitNarrative：按换行/句号分段、兜底硬切、空文本
/// 2. narrative_format.effectLabels：从效果 Map 推导中文标签
/// 3. narrative_format.choiceOrdinal：选项编号
/// 4. 主界面可构建且保留既有契约（标题/状态条），叙事长文不崩溃
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/screens/game_screen.dart';
import 'package:westeros_life_simulator/utils/narrative_format.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Batch 10-12 splitNarrative', () {
    test('按换行拆分为多段', () {
      final parts = splitNarrative('第一段。\n第二段。\n第三段。');
      expect(parts.length, greaterThanOrEqualTo(2));
    });

    test('按句号拆分长句', () {
      final text = '守夜人的火炬在风中摇晃。墙外的狼嚎断断续续。你握紧剑柄。';
      final parts = splitNarrative(text);
      expect(parts.length, 3);
      expect(parts.first, contains('火炬'));
    });

    test('空文本返回单元素', () {
      final parts = splitNarrative('   ');
      expect(parts.length, 1);
    });

    test('无标点长文本按长度硬切不崩溃', () {
      final long = 'a' * 200;
      final parts = splitNarrative(long, maxLength: 60);
      expect(parts.isNotEmpty, true);
      expect(parts.join().length, 200);
    });
  });

  group('Batch 10-12 effectLabels', () {
    test('金币与声望标签', () {
      final labels = effectLabels(const <String, int>{'gold': 10, 'reputation': -5});
      expect(labels, contains('金币+10'));
      expect(labels, contains('声望-5'));
    });

    test('生存状态标签', () {
      final labels = effectLabels(
        const <String, int>{'health': 15, 'energy': -10, 'hunger': 20},
      );
      expect(labels, contains('生命+15'));
      expect(labels, contains('精力-10'));
      expect(labels, contains('饱食+20'));
    });

    test('技能/物品/标记标签（取前 2 个扩展）', () {
      final labels = effectLabels(
        const <String, int>{
          'skills.sword': 1,
          'attributes.strength': 2,
          'inventory.item_bread': 1,
          'flags.honor_pledge': 1,
        },
      );
      expect(labels, contains('sword+1'));
      expect(labels, contains('strength+2'));
    });

    test('空效果返回默认', () {
      expect(effectLabels(const <String, int>{}), contains('无显著影响'));
    });
  });

  group('Batch 10-12 choiceOrdinal', () {
    test('前 6 个使用罗马数字', () {
      expect(choiceOrdinal(0), 'Ⅰ');
      expect(choiceOrdinal(2), 'Ⅲ');
      expect(choiceOrdinal(5), 'Ⅵ');
    });

    test('超出使用数字', () {
      expect(choiceOrdinal(6), '7');
    });
  });

  group('Batch 10-12 主界面', () {
    testWidgets('主界面保留既有契约（标题/状态条）且叙事长文不崩溃', (tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final engine = GameEngine()..startNewGame();
      await tester.pumpWidget(
        MaterialApp(home: GameScreen(engine: engine)),
      );
      await tester.pumpAndSettle();

      // 既有契约：标题 + 状态条
      expect(find.text('维斯特洛人生模拟器'), findsOneWidget);
      expect(find.textContaining('岁'), findsWidgets);

      // 触发一条长叙事（模拟引擎输出），界面不应崩溃
      engine.resolveCommand('过月');
      await tester.pumpAndSettle();
      expect(find.byType(GameScreen), findsOneWidget);
    });
  });
}