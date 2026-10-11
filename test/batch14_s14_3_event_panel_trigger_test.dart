/// S14-3 测试：事件面板「可触发事件」可点击执行。
///
/// 【本批修的是什么】S4-5 让事件选项接入主流程后，事件面板仍是「纯展示」
/// （`events_screen.dart` 自述「不做触发执行」）——「可触发」徽章与 ✓/○
/// 选项图标看了点不动，玩家只能通过月度传闻抉择事件。
///
/// 【本批怎么修】引擎侧新增 `GameEngine.triggerEventChoice(event, choice)`：
/// 一次性事件标记完成 + `setPendingEvent(event)` + 复用主流程
/// `chooseWorldEventChoice(choice)`——**不新建效果通道**，门槛校验、
/// 效果落盘、摘要、时钟语义全部白拿主流程既有契约。
/// 面板侧把满足门槛（`getAvailableChoices`）的选项包上 `InkWell`，
/// 执行后 SnackBar 显示结算文本并 `setState` 重建。
///
/// 【确定性】沿用 S4-5 的模式：`setPendingEvent` / 直接构造玩家状态，
/// 不赌 30% 掷骰（S4-6 两次翻车教训，见 `batch12_s45` 文件头）。
///
/// 覆盖：
/// 1. 引擎：效果落盘 + 叙事/摘要可见 + 不推进时钟 + 执行后不留待决卡
/// 2. 引擎：既有月度待决事件不被面板执行冲掉；执行待决事件本身不复活死卡
/// 3. 引擎：门槛不满足被拒（复用主流程校验），一次性事件不被误标完成
/// 4. 引擎：一次性事件执行后不再出现在可触发列表
/// 5. Widget：面板中可用选项可点，SnackBar 出现结算文本、金币变化、
///    一次性事件从「可触发」列表消失
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/event_data.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/models/event.dart';
import 'package:westeros_life_simulator/models/player.dart';
import 'package:westeros_life_simulator/screens/events_screen.dart';

/// 满足 `event_sword_inheritance` 门槛（minReputation 30）的玩家。
/// 与 `batch12_s45` 的 `_richPlayer` 同款。
Player _richPlayer() => Player.defaultPlayer().copyWith(
      gold: 100,
      reputation: 80,
      age: 30,
      hunger: 60,
      health: 80,
      energy: 80,
    );

GameEvent get _swordEvent => eventById('event_sword_inheritance')!;

void main() {
  group('S14-3 引擎：triggerEventChoice 复用主流程', () {
    test('典当换钱：金币 +80、声望 -8 落盘，叙事与摘要可见', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(_richPlayer());

      final goldBefore = engine.player.gold;
      final repBefore = engine.player.reputation;
      final sell = _swordEvent.choices.firstWhere((c) => c.id == 'choice_sell');

      final text = engine.triggerEventChoice(_swordEvent, sell);

      expect(engine.player.gold, goldBefore + 80, reason: '金币效果未落盘');
      expect(engine.player.reputation, repBefore - 8, reason: '声望效果未落盘');
      expect(text, contains(sell.narrative), reason: '选项叙事未输出');
      expect(text, contains('金币 +80'), reason: '效果摘要未输出');
    });

    test('不推进时钟（复用 advanceClock: false 的主流程语义）', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(_richPlayer());
      final turnBefore = engine.progress.turnCount;

      engine.triggerEventChoice(
        _swordEvent,
        _swordEvent.choices.first,
      );

      expect(engine.progress.turnCount, turnBefore,
          reason: '面板执行不该推进时间——与月度传闻抉择必须是同一时钟语义');
    });

    test('执行后不留待决事件（主界面不出死卡片）', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(_richPlayer());
      expect(engine.pendingEvent, isNull, reason: '前提：执行前无待决事件');

      engine.triggerEventChoice(
        _swordEvent,
        _swordEvent.choices.first,
      );

      expect(engine.pendingEvent, isNull,
          reason: '面板执行残留 pendingEvent ⇒ 主界面渲染出点了没反应的卡片');
    });

    test('既有月度待决事件不被面板执行冲掉', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(_richPlayer());
      // 先摆一个月度待决事件（家传之剑），再经面板执行另一个事件
      engine.setPendingEvent(_swordEvent);
      final other = GameEvent.defaultEvent();

      engine.triggerEventChoice(other, other.choices.first);

      expect(engine.pendingEvent, isNotNull,
          reason: '面板执行把玩家的月度待决事件冲掉了——传闻卡片凭空消失');
      expect(engine.pendingEvent!.id, 'event_sword_inheritance');
    });

    test('经面板执行待决事件本身：执行完不复活成死卡片', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(_richPlayer());
      engine.setPendingEvent(_swordEvent);

      engine.triggerEventChoice(
        _swordEvent,
        _swordEvent.choices.first,
      );

      expect(engine.pendingEvent, isNull,
          reason: '执行的就是待决事件本身时，恢复先前状态会把已执行事件复活成死卡片');
    });

    test('门槛不满足被拒（复用主流程校验），状态不变且不误标完成', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(Player.defaultPlayer().copyWith(
            gold: 0,
            reputation: 50,
            hunger: 60,
            health: 80,
            energy: 80,
          ));
      final debt = eventById('event_iron_bank_debt')!;
      final repay = debt.choices.firstWhere((c) => c.id == 'choice_repay');
      expect(repay.requirements['gold'], 500, reason: '前提：该选项门槛是 500 金');

      final goldBefore = engine.player.gold;
      final repBefore = engine.player.reputation;
      final text = engine.triggerEventChoice(debt, repay);

      expect(text, contains('不满足'), reason: '应复用主流程的门槛拒绝文案');
      expect(engine.player.gold, goldBefore, reason: '被拒选项不该产生任何效果');
      expect(engine.player.reputation, repBefore);
      expect(engine.pendingEvent, isNull, reason: '被拒也不该残留待决事件');
      expect(engine.eventProvider.completedEventIds, isNot(contains(debt.id)),
          reason: '门槛被拒绝不该把一次性事件标记为完成（否则永远无法再触发）');
    });

    test('一次性事件执行后标记完成，不再出现在可触发列表', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(_richPlayer());
      expect(
        engine.eventProvider
            .getAvailableEvents(engine.player)
            .any((e) => e.id == 'event_sword_inheritance'),
        isTrue,
        reason: '前提：执行前家传之剑在可触发列表里',
      );

      engine.triggerEventChoice(
        _swordEvent,
        _swordEvent.choices.first,
      );

      expect(engine.eventProvider.completedEventIds,
          contains('event_sword_inheritance'),
          reason: '一次性事件不标完成 ⇒ 下月还能浮现/再执行，重复拿效果');
      expect(
        engine.eventProvider
            .getAvailableEvents(engine.player)
            .any((e) => e.id == 'event_sword_inheritance'),
        isFalse,
        reason: '执行后应从可触发列表消失（面板重建的依据）');
    });
  });

  group('S14-3 Widget：事件面板可点击执行', () {
    testWidgets('可触发 Tab：可用选项可点，SnackBar 显示结算文本', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(_richPlayer());
      await tester.pumpWidget(MaterialApp(home: EventsScreen(engine: engine)));
      await tester.pumpAndSettle();

      // 展开家传之剑的卡片（在可触发列表深处，先滚到它）
      await tester.scrollUntilVisible(
        find.text('家传之剑'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('家传之剑'));
      await tester.pumpAndSettle();

      final goldBefore = engine.player.gold;
      await tester.tap(find.text('典当换钱'));
      await tester.pumpAndSettle();

      expect(engine.player.gold, goldBefore + 80,
          reason: '点击面板选项必须真实落盘效果');
      expect(find.textContaining('当铺'), findsOneWidget,
          reason: '结算文本（选项叙事）应经 SnackBar 可见');
      expect(find.text('家传之剑'), findsNothing,
          reason: '一次性事件执行后应从「可触发」列表消失（面板重建）');
    });
  });
}
