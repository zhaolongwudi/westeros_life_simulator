/// S15-5 测试：本地剧情推进（事件库驱动，相位机替代 30% 掷骰）。
///
/// 【本批修的是什么】用户 2026-10-12 反馈「本地模式一点剧情都没有，
/// 这个明明是一个剧情游戏」。根因取证：`mixin_play._maybeWorldEvent`
/// 是一道**硬编码 30% 掷骰** ⇒ **七成月份什么都不发生**，玩家点「过月」
/// 只看到数值结算。
///
/// 【本批怎么修】按《剧情推进指令》的四相位节奏，用**已有的、随存档往返的**
/// `progress.turnCount` 确定性推导相位（引入/加压/转折/收束，各 3 回合，
/// 12 回合一章），除章末间歇外**每回合都推进剧情**；相位还决定挑什么事件
/// （转折挑政治/战争，引入挑日常/家族）。
///
/// 【为什么断言可以完全确定】相位是 `turnCount` 的纯函数，不掷骰、不依赖
/// 时钟——本项目两次因「跑 N 回合应该能等到」翻车（§0 第 9 条），
/// 故这里一律断言**确定值**而非概率。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/core/narrative_momentum.dart';
import 'package:westeros_life_simulator/data/event_data.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/models/event.dart';
import 'package:westeros_life_simulator/models/player.dart';

Player _richPlayer() => Player.defaultPlayer().copyWith(
      gold: 100,
      reputation: 80,
      age: 30,
      hunger: 60,
      health: 80,
      energy: 80,
    );

/// 受控事件池：池大小恒为 1 ⇒ 一旦浮现必是它（无池内选择成分）。
List<GameEvent> get _soloPool => <GameEvent>[eventById('event_sword_inheritance')!];

void main() {
  group('S15-5 相位机：turnCount → 相位的确定性映射', () {
    test('四相位各 3 回合、12 回合一章、循环回卷', () {
      expect(NarrativeMomentum.phaseFor(0), NarrativePhase.introduce);
      expect(NarrativeMomentum.phaseFor(2), NarrativePhase.introduce);
      expect(NarrativeMomentum.phaseFor(3), NarrativePhase.escalate);
      expect(NarrativeMomentum.phaseFor(5), NarrativePhase.escalate);
      expect(NarrativeMomentum.phaseFor(6), NarrativePhase.turn);
      expect(NarrativeMomentum.phaseFor(8), NarrativePhase.turn);
      expect(NarrativeMomentum.phaseFor(9), NarrativePhase.resolve);
      expect(NarrativeMomentum.phaseFor(11), NarrativePhase.resolve);
      // 第二章从引入重新开始
      expect(NarrativeMomentum.phaseFor(12), NarrativePhase.introduce);
      expect(NarrativeMomentum.phaseFor(23), NarrativePhase.resolve);
    });

    test('推进率：12 回合里 11 回合推进（只有章末间歇留白）', () {
      final surfacing = <int>[
        for (var t = 0; t < NarrativeMomentum.turnsPerChapter; t++)
          if (NarrativeMomentum.shouldSurface(t)) t,
      ];
      expect(surfacing.length, NarrativeMomentum.turnsPerChapter - 1,
          reason: '改造前 30% 掷骰 ⇒ 12 回合平均只有 3.6 次剧情；'
              '现契约是 11 次（仅章末间歇留白）');
      // 间歇固定在章末最后一回合
      expect(NarrativeMomentum.shouldSurface(11), isFalse);
      expect(NarrativeMomentum.shouldSurface(23), isFalse);
    });

    test('事件挑选按相位偏好：转折挑政治/战争，引入挑日常/家族', () {
      GameEvent probe(EventType t) => GameEvent(
            id: 'probe_${t.name}',
            name: '探针',
            type: t,
            description: '',
            triggerConditions: const <String, String>{},
            choices: const <EventChoice>[],
            narrative: '',
            tags: const <String>[],
            isOneTime: false,
          );

      // 转折相位：政治/战争 > 日常
      expect(
        NarrativeMomentum.scoreEvent(probe(EventType.political), NarrativePhase.turn),
        greaterThan(
          NarrativeMomentum.scoreEvent(probe(EventType.daily), NarrativePhase.turn),
        ),
        reason: '转折相位是章节承重墙，不该被日常事件占位',
      );
      // 引入相位：日常/家族 > 政治
      expect(
        NarrativeMomentum.scoreEvent(probe(EventType.family), NarrativePhase.introduce),
        greaterThan(
          NarrativeMomentum.scoreEvent(probe(EventType.political), NarrativePhase.introduce),
        ),
        reason: '引入相位先建立认知，不该一上来就政治剧变',
      );
    });
  });

  group('S15-5 引擎接入：本地模式每月必有剧情', () {
    test('首月必现剧情（修复前是 30% 掷骰，可能整月无事）', () {
      final engine = GameEngine(events: _soloPool)..startNewGame();
      engine.updatePlayer(_richPlayer());
      expect(engine.pendingEvent, isNull, reason: '前提：开局无待决事件');

      final text = engine.advanceMonth();

      // 🔴 判别断言：相位驱动下这一回合**必须**有剧情
      expect(engine.pendingEvent, isNotNull,
          reason: '本地模式的第一个月就该有事发生（相位驱动，非 30% 掷骰）');
      expect(text, contains('传闻'), reason: '浮现的剧情应写进月度叙事');
    });

    test('章末间歇回合不浮现（留白是刻意的，且有且只有一回合）', () {
      final engine = GameEngine(events: _soloPool)..startNewGame();
      engine.updatePlayer(_richPlayer());

      // 推进到章末回合：开局 turnCount=0，advanceMonth 内部会先 +1。
      // 章末回合 = turnCount 11、23…（逢 turnsPerChapter-1）。
      // 逐回合推进，记录「本回合是否浮现新事件」。
      final surfacedAt = <int>[];
      for (var i = 0; i < 24; i++) {
        final before = engine.pendingEvent;
        engine.advanceMonth();
        final after = engine.pendingEvent;
        if (after != null && !identical(before, after)) {
          surfacedAt.add(engine.progress.turnCount);
        }
        // 抉择掉，避免下一步被「不顶掉未抉择事件」挡住
        if (engine.pendingEvent != null) {
          engine.chooseWorldEventChoice(engine.pendingEvent!.choices.first);
        }
        if (!engine.isGameActive) break;
      }

      expect(surfacedAt, isNotEmpty, reason: '24 回合内必然浮现过剧情');
      // 每次浮现都应发生在 shouldSurface 为真的回合
      for (final t in surfacedAt) {
        expect(NarrativeMomentum.shouldSurface(t), isTrue,
            reason: '第 $t 回合不该浮现（章末间歇）');
      }
    });

    test('不顶掉玩家未抉择的事件（推进 ≠ 催命）', () {
      final engine = GameEngine(events: _soloPool)..startNewGame();
      engine.updatePlayer(_richPlayer());
      engine.setPendingEvent(eventById('event_sword_inheritance')!);
      final before = engine.pendingEvent;

      engine.advanceMonth();

      expect(engine.pendingEvent, isNotNull);
      expect(identical(engine.pendingEvent, before), isTrue,
          reason: '「每月必现」的节奏下若还顶掉旧事件，玩家没点的抉择会凭空消失');
    });
  });
}
