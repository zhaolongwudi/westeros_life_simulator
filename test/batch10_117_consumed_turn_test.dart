/// Batch 10-117 测试：consumedTurn 契约真正被消费（S2-1 / P1-04）。
///
/// 背景：CommandResult.consumedTurn 自 Batch 10-28 引入后**全库无人读取**，
/// 「探索」标注 consumedTurn=true 却零时间成本，可无限刷资源。
/// 本批在 GameScreen._submitCommand 消费该契约，并引入 needsTimeAdvance
/// 区分「消耗了回合」与「需要调度方推进」——「过月」handler 已自推进，
/// 不能再推进一次。
///
/// 覆盖：
/// 1. 契约层：探索/过月/普通指令的 consumedTurn 与 needsTimeAdvance
/// 2. 引擎层：模拟调度方推进后，探索消耗一个月、过月只推进一次
/// 3. UI 层：主界面输入「探索」推进一月；输入「过月」不双推进
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/screens/game_screen.dart';

/// 读出当前「年-月」（格式与状态条一致：progress.year / progress.month）。
String _ym(GameEngine engine) =>
    '${engine.progress.year}-${engine.progress.month}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Batch 10-117 契约层', () {
    late GameEngine engine;

    setUp(() {
      engine = GameEngine()..startNewGame();
    });

    test('探索：消耗回合且需要调度方推进', () {
      final r = engine.resolveCommand('探索');
      expect(r.consumedTurn, isTrue);
      expect(r.needsTimeAdvance, isTrue);
    });

    test('过月：消耗回合但**不需要**调度方推进（handler 已自推进）', () {
      final r = engine.resolveCommand('过月');
      expect(r.consumedTurn, isTrue);
      expect(r.needsTimeAdvance, isFalse, reason: '否则会出现过月推两个月');
    });

    test('普通指令（状态/帮助）：既不消耗回合也不推进', () {
      for (final cmd in const ['状态', '帮助']) {
        final r = engine.resolveCommand(cmd);
        expect(r.consumedTurn, isFalse, reason: '$cmd 不应消耗回合');
        expect(r.needsTimeAdvance, isFalse, reason: '$cmd 不应推进时间');
      }
    });

    test('未注册指令不推进时间', () {
      final r = engine.resolveCommand('这句话不是指令');
      expect(r.needsTimeAdvance, isFalse);
    });
  });

  group('Batch 10-117 引擎层（模拟调度）', () {
    test('探索指令 + 调度推进 = 前进一个月', () {
      final engine = GameEngine()..startNewGame();
      final before = _ym(engine);
      final r = engine.resolveCommand('探索');
      expect(r.text, isNotEmpty);
      if (r.needsTimeAdvance) {
        engine.advanceMonth();
      }
      expect(_ym(engine), isNot(before), reason: '探索应当消耗一个月');
    });

    test('过月指令只推进一个月（不双推进）', () {
      final engine = GameEngine()..startNewGame();
      final y0 = engine.progress.year;
      final m0 = engine.progress.month;
      final r = engine.resolveCommand('过月');
      if (r.needsTimeAdvance) {
        engine.advanceMonth();
      }
      final y1 = engine.progress.year;
      final m1 = engine.progress.month;
      final delta = (y1 - y0) * 12 + (m1 - m0);
      expect(delta, 1, reason: '过月必须恰好推进一个月');
    });
  });

  group('Batch 10-117 主界面', () {
    Future<GameEngine> _pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final engine = GameEngine()..startNewGame();
      await tester.pumpWidget(MaterialApp(home: GameScreen(engine: engine)));
      await tester.pumpAndSettle();
      return engine;
    }

    Future<void> _type(WidgetTester tester, String cmd) async {
      await tester.enterText(find.byType(TextField), cmd);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
    }

    testWidgets('输入「探索」后年月推进一个月', (tester) async {
      final engine = await _pump(tester);
      final before = _ym(engine);
      await _type(tester, '探索');
      expect(_ym(engine), isNot(before));
    });

    testWidgets('输入「过月」后只推进一个月（不双推进）', (tester) async {
      final engine = await _pump(tester);
      final y0 = engine.progress.year;
      final m0 = engine.progress.month;
      await _type(tester, '过月');
      final delta = (engine.progress.year - y0) * 12 +
          (engine.progress.month - m0);
      expect(delta, 1);
    });
  });
}
