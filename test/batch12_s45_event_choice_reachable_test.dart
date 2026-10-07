/// S4-5 测试：事件选项真正接入主流程（架构级，P1 遗留关闭）。
///
/// 【本批修的是什么】`event_data.dart` 里 71 个事件的 **216 个带 effects 的选项
/// 在生产流程中不可达**——三条独立证据（S4-3 取证）：
///   1. `applyChoice`（事件选项唯一的应用入口）在 `lib/screens/` 与 `lib/widgets/`
///      中**零调用**，全库仅测试在调；
///   2. 事件面板自述「纯展示 + 可触发状态标记，**不做触发执行**」；
///   3. 30% 世界事件只输出一行文本 `'📜 传闻：...'`，不执行任何选项。
/// 玩家实际选的只有 AI 现场生成的选项。故 P1-03 幽灵键、P2-03 门槛、
/// 事件权重**全挂在一条玩家走不到的路上**。
///
/// 【本批怎么修】月度浮现的事件登记为 `pendingEvent`，UI 渲染成可点选项卡片，
/// 玩家抉择经 `chooseWorldEventChoice` 真正落盘效果。这是那些选项的
/// **第一个生产调用方**。
///
/// 【为什么大部分用例是确定性的（S4-6 两次翻车的教训）】`_maybeWorldEvent`
/// 有一道**硬编码的 30% 掷骰**且无法注入替代——故凡涉及「效果是否落盘」的断言，
/// 一律先用 `setPendingEvent(...)` **直接构造待决状态**，让概率成分归零；
/// 只有「浮现」这一条用受控单事件池（沿用 S4-6 已验证的 12 回合窗口）。
/// 本项目已两次因「跑 N 回合应该能等到」翻车，此处不再赌。
///
/// 覆盖：
/// 1. 浮现的事件进入 `pendingEvent`，叙事里列出全部选项
/// 2. 抉择后**效果真正落盘**（金币/声望/技能/标记）
/// 3. 抉择**不再重复推进时间**（事件在 `advanceMonth` 内部浮现，时钟已走过）
/// 4. 抉择后 `pendingEvent` 清空；无待决事件时返回提示而非抛异常
/// 5. 非本事件的选项被拒（防止张冠李戴）
/// 6. 未抉择时保留；游戏结束后不再渲染
/// 7. 摘要与 AI 通道**共用同一份实现**（防止第六次双通道漂移）
/// 8. 状态归属：重新开始清空 / 存档往返保留 / 旧档缺键回落 null
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/event_data.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/models/event.dart';
import 'package:westeros_life_simulator/models/player.dart';
import 'package:westeros_life_simulator/providers/game_state_provider.dart';

/// 满足 `event_sword_inheritance` 门槛（minReputation 30）的玩家。
Player _richPlayer() => Player.defaultPlayer().copyWith(
      gold: 100,
      reputation: 80,
      age: 30,
      hunger: 60,
      health: 80,
      energy: 80,
    );

/// 受控单事件池：池大小恒为 1 ⇒ 一旦真正浮现必是它（无池内选择成分）。
List<GameEvent> get _soloPool => [eventById('event_sword_inheritance')!];

GameEvent get _swordEvent => eventById('event_sword_inheritance')!;

/// 直接构造「该事件正待抉择」的状态——**不经 30% 掷骰**，故完全确定。
GameEngine _engineAwaitingEvent() {
  final engine = GameEngine(events: _soloPool)..startNewGame();
  engine.updatePlayer(_richPlayer());
  engine.setPendingEvent(_swordEvent);
  return engine;
}

void main() {
  group('S4-5 浮现：事件进入待决状态', () {
    test('受控池必然浮现，且叙事列出全部选项文案', () {
      final engine = GameEngine(events: _soloPool)..startNewGame();
      engine.updatePlayer(_richPlayer());

      // 唯一一处依赖 RNG 的用例：池大小恒为 1，且沿用 S4-6 已验证的
      // 12 回合窗口（`defaultPlayer` 约第 17 回合饿死 → 时钟冻结）。
      var turns = 0;
      var text = '';
      while (engine.pendingEvent == null && turns < 12) {
        text = engine.advanceMonth();
        turns++;
      }

      expect(engine.pendingEvent, isNotNull,
          reason: '池大小恒为 1，$turns 回合内应已浮现'
              '（超限请检查是否已 endGame 冻结时钟）');
      final ev = engine.pendingEvent!;
      expect(ev.id, 'event_sword_inheritance');
      for (final c in ev.choices) {
        expect(text, contains(c.text),
            reason: '选项「${c.text}」未出现在叙事中，玩家无法据此抉择');
      }
    });

    test('未抉择时待决事件保留（不因「当月没点」而丢失）', () {
      final engine = _engineAwaitingEvent();
      expect(engine.pendingEvent, isNotNull);
      engine.advanceMonth();
      expect(engine.pendingEvent, isNotNull,
          reason: '未抉择的待决事件被清空了——玩家会永久错过已摆在面前的抉择');
      expect(engine.pendingEvent!.id, 'event_sword_inheritance');
    });

    test('游戏结束后不再暴露待决事件（避免渲染点了没反应的卡片）', () {
      final engine = _engineAwaitingEvent();
      expect(engine.pendingEvent, isNotNull);
      engine.endGame();
      expect(engine.pendingEvent, isNull,
          reason: '游戏已结束仍暴露待决事件 → UI 会渲染出点了没反应的卡片');
    });
  });

  group('S4-5 抉择：效果真正落盘', () {
    test('典当换钱：金币 +80、声望 -8 真实落盘，且摘要可见', () {
      final engine = _engineAwaitingEvent();
      final sell = _swordEvent.choices.firstWhere((c) => c.id == 'choice_sell');

      final goldBefore = engine.player.gold;
      final repBefore = engine.player.reputation;

      final text = engine.chooseWorldEventChoice(sell);

      expect(engine.player.gold, goldBefore + 80, reason: '金币效果未落盘');
      expect(engine.player.reputation, repBefore - 8, reason: '声望效果未落盘');
      expect(text, contains(sell.narrative), reason: '选项叙事未输出');
      expect(text, contains('金币 +80'),
          reason: '效果摘要未输出（玩家看不到状态变化）');
      expect(text, contains('声望 -8'));
    });

    test('收下并佩戴：技能与装备标记真实落盘', () {
      final engine = _engineAwaitingEvent();
      final accept = _swordEvent.choices
          .firstWhere((c) => c.id == 'choice_accept_sword');

      final swordBefore = engine.player.skills['sword'] ?? 0;
      engine.chooseWorldEventChoice(accept);

      expect(engine.player.skills['sword'], swordBefore + 1,
          reason: 'skills.sword 未落盘');
      expect(engine.player.flags['equipped.item_sword'], isTrue,
          reason: 'flags.equipped.item_sword 未落盘');
    });

    test('抉择不再重复推进时间（事件在 advanceMonth 内部已推进过）', () {
      final engine = _engineAwaitingEvent();
      final turnBefore = engine.progress.turnCount;

      engine.chooseWorldEventChoice(_swordEvent.choices.first);

      expect(engine.progress.turnCount, turnBefore,
          reason: '抉择又推进了一个月——同一个事件吃掉两个月'
              '（应走 advanceClock: false）');
    });

    test('抉择计入事件历史（currentEvent 被消费）', () {
      final engine = _engineAwaitingEvent();
      final historyBefore = engine.history.length;
      engine.chooseWorldEventChoice(_swordEvent.choices.first);
      expect(engine.history.length, historyBefore + 1,
          reason: '抉择后事件应进 history');
      expect(engine.currentEvent, isNull);
    });
  });

  group('S4-5 边界：清空、拒绝与防漂移', () {
    test('抉择后待决事件清空', () {
      final engine = _engineAwaitingEvent();
      engine.chooseWorldEventChoice(_swordEvent.choices.first);
      expect(engine.pendingEvent, isNull);
    });

    test('无待决事件时抉择返回提示，不抛异常', () {
      final engine = GameEngine(events: _soloPool)..startNewGame();
      engine.updatePlayer(_richPlayer());
      expect(engine.pendingEvent, isNull);
      final text = engine.chooseWorldEventChoice(_swordEvent.choices.first);
      expect(text, contains('没有待抉择的事件'));
    });

    test('传入不属于该事件的选项 → 被拒绝且状态不变', () {
      final engine = _engineAwaitingEvent();
      final foreign = allEvents
          .firstWhere((e) => e.id != 'event_sword_inheritance')
          .choices
          .first;
      final goldBefore = engine.player.gold;
      final text = engine.chooseWorldEventChoice(foreign);

      expect(text, contains('不是'), reason: '应明确拒绝张冠李戴的选项');
      expect(engine.player.gold, goldBefore,
          reason: '被拒绝的选项不该产生任何效果');
      expect(engine.pendingEvent, isNotNull, reason: '被拒绝后待决事件应保留');
    });

    test('摘要实现与 AI 通道共用同一份（防止第六次双通道漂移）', () {
      final engine = _engineAwaitingEvent();
      final sell = _swordEvent.choices.firstWhere((c) => c.id == 'choice_sell');

      final before = engine.player;
      final eventText = engine.chooseWorldEventChoice(sell);
      // 同一组 before/after 直接调基类摘要，应与事件通道输出一致
      final sharedText = engine.effectSummary(before, includeRejected: false);
      final lines = sharedText
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();
      expect(lines, isNotEmpty, reason: '前提：该选项应有可摘要的效果变化');
      for (final line in lines) {
        expect(eventText, contains(line.trim()),
            reason: '事件通道摘要与基类 effectSummary 不一致（双通道漂移）');
      }
    });
  });

  group('S4-5 状态归属：清空 / 复制 / 存档往返', () {
    test('startNewGame 清空待决事件（重新开始不残留上一局）', () {
      final engine = _engineAwaitingEvent();
      expect(engine.pendingEvent, isNotNull);
      engine.startNewGame();
      expect(engine.pendingEvent, isNull,
          reason: '「重新开始」后上一局的待决事件仍会渲染（点了没用）');
    });

    test('toJson/fromJson 往返保留待决事件，且还原后仍可抉择', () {
      // 状态层是 pendingEvent 的归属层。GameEngine 没有 fromJson 工厂，
      // 读档链路是 GameStateProvider.fromJson → 再构造引擎
      // （与 regression_legacy_save_test 同款链路）。
      final engine = _engineAwaitingEvent();
      final json = engine.toJson();
      final restored = GameStateProvider.fromJson(json);
      expect(restored.pendingEvent, isNotNull,
          reason: '待决事件未随存档往返——读档后玩家会丢掉已摆到面前的抉择');
      expect(restored.pendingEvent!.id, 'event_sword_inheritance');

      final revived = GameEngine(
        player: restored.player,
        progress: restored.progress,
        history: restored.history,
        currentEvent: restored.currentEvent,
        pendingEvent: restored.pendingEvent,
        isGameActive: restored.isGameActive,
        isGameOver: restored.isGameOver,
      );
      expect(revived.pendingEvent, isNotNull);
      final sell = _swordEvent.choices.firstWhere((c) => c.id == 'choice_sell');
      final goldBefore = revived.player.gold;
      revived.chooseWorldEventChoice(sell);
      expect(revived.player.gold, goldBefore + 80,
          reason: '还原出的待决事件无法正常抉择');
    });

    test('读档链路（用 loaded.history 构造引擎）抉择世界事件不崩', () {
      // 【CI run 37604763686 回归锁】`history` getter 返回 List.unmodifiable，
      // 而构造函数曾直接存下传入的列表 → 「读档 → 构造引擎 → 抉择事件」时
      // `_appendHistory` 抛 Cannot add to an unmodifiable list。
      // 这条是**真实生产路径**（S4-5 之前 append 分支是死的，故未暴露）。
      final engine = _engineAwaitingEvent();
      final loaded = GameStateProvider.fromJson(engine.toJson());
      final revived = GameEngine(
        player: loaded.player,
        progress: loaded.progress,
        history: loaded.history, // ← 这里是 unmodifiable 视图
        currentEvent: loaded.currentEvent,
        pendingEvent: loaded.pendingEvent,
        isGameActive: loaded.isGameActive,
        isGameOver: loaded.isGameOver,
      );
      final sell = _swordEvent.choices.firstWhere((c) => c.id == 'choice_sell');
      // 不应抛异常
      final text = revived.chooseWorldEventChoice(sell);
      expect(text, isNotEmpty);
      expect(revived.history.length, loaded.history.length + 1,
          reason: '抉择后事件应能追加进 history（而非因不可变列表崩溃）');
    });

    test('旧存档缺 pendingEvent 键 → 回落 null，不崩', () {
      final engine = _engineAwaitingEvent();
      final json = engine.toJson()..remove('pendingEvent');
      final restored = GameStateProvider.fromJson(json);
      expect(restored.pendingEvent, isNull);
      expect(restored.isGameActive, isTrue, reason: '其余字段不应受影响');
    });
  });

  group('S4-5 数据侧前提（防止测试悄悄失效）', () {
    test('受控池事件可被 richPlayer 满足且非空门槛', () {
      final e = _soloPool.single;
      expect(e.choices, isNotEmpty);
      expect(e.triggerConditions, isNotEmpty,
          reason: '若改成无条件事件，本文件的注入场景需重新评估');
      expect(e.choices.any((c) => c.effects.isNotEmpty), isTrue,
          reason: '受控事件至少要有一个带效果的选项，否则测不出「效果落盘」');
    });

    test('全库事件都有选项（否则「可抉择」对它们是空承诺）', () {
      final noChoices = allEvents.where((e) => e.choices.isEmpty).toList();
      expect(noChoices.map((e) => e.id), isEmpty);
    });

    test('断言依赖的数据未被改动（典当 80 金 / -8 声望 / 收下 +1 剑术）', () {
      final sell = _swordEvent.choices.firstWhere((c) => c.id == 'choice_sell');
      expect(sell.effects['gold'], 80);
      expect(sell.effects['reputation'], -8);
      final accept = _swordEvent.choices
          .firstWhere((c) => c.id == 'choice_accept_sword');
      expect(accept.effects['skills.sword'], 1);
    });
  });
}
