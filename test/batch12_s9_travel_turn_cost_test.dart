/// S9-1 测试：「旅行」实际移动时消耗一个月（第 0 节 L3 / S2-1 遗留⑤）。
///
/// 【本批修的是什么】
/// `consumedTurn` 契约在 S2-1（P1-04）被 `GameScreen._submitCommand` 真正消费后，
/// 「探索」有了时间成本，但**同一文件里的「旅行」是唯一漏网的位移指令**——
/// 它的 `CommandSpec` 没标 `consumedTurn`，于是跨地点移动零时间成本：
/// 一个月内可以从临冬城走到君临再走回来，而「探索」一次就要一个月。
///
/// 【为什么是「条件消耗」而不是无脑标 true】
/// `travel` 这一条指令承担两件事：空参数 = 列出可去地点（面板），
/// 有参数 = 真的移动。后者才该花时间。同理，未知地点 / 已在原地 /
/// 未连接 / 旅费不足**都没有发生位移**，不该罚掉一个月——「输错地名掉一个月」
/// 比「移动不花时间」更糟。故判定用**位移**（`player.locationId` 是否变化），
/// 而不是文案是否含「抵达」（后者是字符串耦合，文案一改就失效）。
///
/// 【为什么断言全是确定性的】
/// 本项目已两次因「跑 N 回合应该能等到」翻车（S4-6：零命中概率 3.5%，CI 恰好踩中）。
/// 本文件**不依赖任何 RNG 结果**：位移只取决于 `connectedTo` 静态数据与金币，
/// 时间推进只取决于 `needsTimeAdvance` 这一个布尔量。
///
/// 覆盖（对应卡片 6 条验收标准）：
/// 1. 空参数只开面板：文案含「可前往」且**不消耗回合**、年月不变
/// 2. 实际移动：消耗回合，经调度方推进后年月 +1
/// 3. 四条失败路径（未知地点 / 已在原地 / 未连接 / 旅费不足）**都不消耗**
/// 4. 游戏未开始：不消耗
/// 5. UI 层：真实 `GameScreen` 输入「旅行 <地点>」推进一月
/// 6. 一条反向锁：`spec.consumedTurn` 保持 false 是**有意的**（条件消耗），
///    不是漏标——防止日后有人「顺手补上 true」却让「声明消耗了但没推进」复活
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/models/player.dart';
import 'package:westeros_life_simulator/screens/game_screen.dart';

/// 临冬城（`location_winterfell`）的相连地点——既有测试已证实可直接抵达。
const _connected = 'location_white_harbor';

/// 临冬城**不**相连的地点——既有测试已证实会被拒绝。
const _unconnected = 'location_kings_landing';

/// 当前年月（与状态条口径一致）。
String _ym(GameEngine engine) => '${engine.progress.year}-${engine.progress.month}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('S9-1 契约层', () {
    test('空参数「旅行」只开面板，不消耗回合', () {
      final engine = GameEngine()..startNewGame();
      final before = _ym(engine);
      final r = engine.resolveCommand('旅行');
      expect(r.text, contains('可前往'));
      expect(r.consumedTurn, isFalse, reason: '查看可去地点不应花掉一个月');
      expect(r.needsTimeAdvance, isFalse);
      // 调度方按 needsTimeAdvance 决定是否推进；为 false 时不该动时间。
      expect(_ym(engine), before);
    });

    test('实际移动到相连地点：消耗回合', () {
      final engine = GameEngine()..startNewGame();
      final r = engine.resolveCommand('旅行 $_connected');
      expect(r.text, contains('抵达'));
      expect(engine.player.locationId, _connected);
      expect(r.consumedTurn, isTrue, reason: '跨地点移动必须与探索同构，花一个月');
      expect(r.needsTimeAdvance, isTrue);
    });

    test('实际移动后经调度方推进恰好一个月（不双推进）', () {
      final engine = GameEngine()..startNewGame();
      final y0 = engine.progress.year;
      final m0 = engine.progress.month;
      final r = engine.resolveCommand('旅行 $_connected');
      if (r.needsTimeAdvance) {
        engine.advanceMonth();
      }
      final delta = (engine.progress.year - y0) * 12 +
          (engine.progress.month - m0);
      expect(delta, 1, reason: 'travel 不自推进，只能由调度方推进一次');
    });

    test('未知地点不消耗回合（未移动不罚时间）', () {
      final engine = GameEngine()..startNewGame();
      final r = engine.resolveCommand('旅行 nowhere');
      expect(r.text, contains('没有叫'));
      expect(r.consumedTurn, isFalse);
    });

    test('已在原地不消耗回合', () {
      final engine = GameEngine()..startNewGame();
      final r = engine.resolveCommand('旅行 location_winterfell');
      expect(r.text, contains('已经在这里'));
      expect(r.consumedTurn, isFalse);
    });

    test('未连接地点不消耗回合', () {
      final engine = GameEngine()..startNewGame();
      final r = engine.resolveCommand('旅行 $_unconnected');
      expect(r.text, contains('无法直接前往'));
      expect(r.consumedTurn, isFalse);
    });

    test('旅费不足不消耗回合', () {
      final engine = GameEngine(
        player: Player.defaultPlayer().copyWith(gold: 0),
        isGameActive: true,
      );
      final r = engine.resolveCommand('旅行 $_connected');
      expect(r.text, contains('付不起'));
      expect(r.consumedTurn, isFalse, reason: '没走成就不该扣掉一个月');
    });

    test('游戏未开始不消耗回合', () {
      final engine = GameEngine();
      final r = engine.resolveCommand('旅行 $_connected');
      expect(r.text, contains('尚未开始'));
      expect(r.consumedTurn, isFalse);
    });
  });

  group('S9-1 反向锁', () {
    test('spec 级 consumedTurn 保持 false 是有意的（条件消耗）', () {
      final engine = GameEngine()..startNewGame();
      final spec = engine.commandRegistry.lookup('旅行');
      expect(spec, isNotNull);
      // 声明性字段是「这条指令**恒**消耗回合吗」——旅行不是：
      // 空参数开面板不消耗。故此处刻意留 false，真正的推进动作
      // 以 handler 返回的 needsTimeAdvance 为准。
      expect(
        spec!.consumedTurn,
        isFalse,
        reason: '旅行是条件消耗；标 true 会让「声明消耗了但没推进」的不一致复活'
            '（见 command_registry.dart 对两条通道必须一致的警告）',
      );
      // 同一张表里「探索」是恒消耗，仍然为 true——本批没有顺手改它。
      expect(engine.commandRegistry.lookup('探索')!.consumedTurn, isTrue);
    });
  });

  group('S9-1 主界面', () {
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

    testWidgets('输入「旅行 <地点>」后年月推进一个月', (tester) async {
      final engine = await _pump(tester);
      final y0 = engine.progress.year;
      final m0 = engine.progress.month;
      await _type(tester, '旅行 $_connected');
      final delta = (engine.progress.year - y0) * 12 +
          (engine.progress.month - m0);
      expect(delta, 1, reason: '移动一次应恰好推进一个月');
      expect(engine.player.locationId, _connected);
    });

    testWidgets('输入「旅行」（无参数）后年月不变', (tester) async {
      final engine = await _pump(tester);
      final before = _ym(engine);
      await _type(tester, '旅行');
      expect(_ym(engine), before, reason: '只看可去地点不该掉一个月');
      expect(engine.player.locationId, isNot(_connected));
    });
  });
}
