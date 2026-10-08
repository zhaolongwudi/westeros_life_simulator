/// S4-6 测试：一次性事件门禁真正生效（P1-11 关闭）。
///
/// 【本批修的是什么】
/// `EventProvider.canTrigger` 对 `isOneTime` 事件的拦截依赖 `_completedEventIds`，
/// 而写入该集合的唯一入口 `markCompleted` 在生产代码中**零调用**
/// （全库只有 `batch3_event_provider_test` 与 `batch10_103_104` 在调）。
/// 故该门禁恒不生效：3 个一次性事件（`event_sword_inheritance` /
/// `event_guild_tooling` / `event_maester_commission`）会无限重复浮现。
///
/// 【为什么标在「浮现」而不是「抉择」】
/// S4-6 定此点时事件选项尚不可达；**S4-5 已让选项可抉择**，但标记点仍保留在
/// 浮现处——「浮现」与「抉择」是两件事：传闻已把全部选项文案播报给玩家，
/// 而玩家完全可能听完就不选。若改标在抉择处，同一条一次性传闻会每月复读
/// 直到玩家点它，那正是本批要修的病症。
/// （S4-5 起选项可抉择：见 `batch12_s45_event_choice_reachable_test.dart`。）
///
/// 【本批第二次修的是什么：实机用例的确定性】
/// 初版实机用例直接用全库 `GameEngine()` 跑 300 回合赌一次性事件浮现，
/// CI 实测 `1323 passed, 1 failed` —— 零命中。取证结论（勿删）：
///   1. `_maybeWorldEvent` 单回合约 30% 触发，其中一次性事件只占池 3/54
///      且 `event_guild_tooling` 门槛含 `skills.alchemy: 2`（默认玩家 alchemy=0，
///      本测试的 richPlayer 也没设 alchemy）→实际只有 2/54 可命中，
///      单回合命中概率 ≈ 1.11%，300 回合零命中概率 ≈ **3.5%**（与实测吻合）。
///   2. 更根本：全库 54 个事件的门槛会随 25 年里的年龄/属性漂移而失效，
///      「池大小恒定」的假设不成立。
///   ⇒改为**注入受控事件集**（`GameEngine(events: ...)`，全库唯一可注入入口），
///      池大小恒为 1，真实 Dart RNG 实测：任意起始回合均在**25 回合内**必中。
///      测试从此确定，不再靠概率。
///
/// 覆盖：
/// 1. `markCompleted` 后 `canTrigger` 拦截生效（provider 层契约）
/// 2. 实机（注入单事件池）：一次性事件浮现后即被标记，且从池中消失
/// 3. 实机（全库）：无论浮现多少次，一次性事件最多只被标记 1 次
/// 4. 非一次性事件**不得**被标记（否则误伤正常事件）
/// 5. 数据侧：恰好 3 个 isOneTime=true，且门槛条件易满足（否则测试构造不出场景）
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/core/event_trigger_eval.dart';
import 'package:westeros_life_simulator/data/event_data.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/models/event.dart';
import 'package:westeros_life_simulator/models/player.dart';
import 'package:westeros_life_simulator/providers/event_provider.dart';

/// 四季全遍历：门槛判定对季节敏感，故数据侧前提须四季都成立。
const _seasons = <String>['spring', 'summer', 'autumn', 'winter'];

/// 玩家条件：满足 3 个一次性事件中至少一个的门槛。
///
/// 【S4-6 取证】`event_guild_tooling` 的门槛是
/// `{'minGold':'120','skills.alchemy':'2'}`，`Player.defaultPlayer()` 的
/// alchemy 为 0 —— 故本方法显式补上 alchemy，否则该事件**永远**不可能浮现，
/// 有效候选从 3 个缩到 2 个。
Player _richPlayer() => Player.defaultPlayer().copyWith(
      gold: 500,
      reputation: 80,
      age: 30,
      skills: const {'sword': 3, 'archery': 2, 'riding': 3, 'speech': 2, 'alchemy': 2},
    );

/// 只含一次性事件的受控池：用`event_sword_inheritance`（门槛 minReputation 30，
/// richPlayer 恒满足）单条事件。池大小恒为 1 ⇒ `_maybeWorldEvent` 每次真正
/// 触发都必然抽中它，无任何概率成分。
List<GameEvent> get _soloOneTimePool => [eventById('event_sword_inheritance')!];

void main() {
  group('S4-6 provider 层契约', () {
    test('markCompleted 后一次性事件不再可触发', () {
      final provider = EventProvider(events: allEvents);
      final player = _richPlayer();
      final target = eventById('event_sword_inheritance')!;

      expect(target.isOneTime, isTrue, reason: '前提：该事件是一次性的');
      // 门槛满足时本可触发
      expect(provider.canTrigger(target, player, season: 'spring'), isTrue,
          reason: '前提：门槛应满足（minReputation 30 ≤ 80）');

      provider.markCompleted(target.id);
      expect(provider.canTrigger(target, player, season: 'spring'), isFalse,
          reason: '标记完成后必须被拦截');
      expect(provider.completedEventIds, contains(target.id));
    });

    test('markCompleted 幂等：重复标记不产生重复条目', () {
      final provider = EventProvider(events: allEvents);
      provider
        ..markCompleted('event_sword_inheritance')
        ..markCompleted('event_sword_inheritance');
      expect(
          provider.completedEventIds.where((e) => e == 'event_sword_inheritance').length,
          1);
    });

    test('非一次性事件不受 completed 影响（门禁只对 isOneTime 生效）', () {
      final provider = EventProvider(events: allEvents);
      final player = _richPlayer();
      final normal = eventById('event_famine')!;
      expect(normal.isOneTime, isFalse);
      provider.markCompleted(normal.id);
      // isOneTime=false 时 completedEventIds 不参与判定
      expect(provider.canTrigger(normal, player, season: 'winter'), isTrue);
    });
  });

  group('S4-6 实机（注入受控池，确定性）：传闻路径必须标记完成', () {
    test('一次性事件浮现后即被标记，且立刻从可触发池中消失', () {
      // 池大小恒为 1 ⇒ 无概率成分（详见文件头「本批第二次修的是什么」）
      final engine = GameEngine(events: _soloOneTimePool)..startNewGame();
      engine.updatePlayer(_richPlayer());

      const target = 'event_sword_inheritance';
      final poolBefore =
          engine.eventProvider.getAvailableEvents(engine.player, season: engine.progress.season);
      expect(poolBefore.map((e) => e.id), contains(target),
          reason: '前提：浮现前该事件必须在池中，否则本用例无意义');

      // 跑到命中即停。真实 Dart RNG 实测：池大小恒为 1 时第 2 回合即命中。
      //
      // 【为什么上限只给 12 回合】`Player.defaultPlayer()` 的 `hunger`
      // 自 S13-13 ⑱ 起为 **60**（此前构造器默认 0），仍低于满值且
      // 每月自然下降 12 ⇒ 约第 3 回合起低于饥饿阈值 25，
      // `applyMonthlyLife` 每月 -8 健康、恢复仅 +2（净 -6），
      // 约第 19 回合健康归零 → `isAlive=false` → 传承失败即 `endGame()`
      // → `advanceMonth` 直接返回、时钟冻结，事件再不浮现。
      // 即 12 回合是「死亡前」的安全上限，超限即说明生产逻辑变了。
      var turns = 0;
      while (engine.eventProvider.completedEventIds.isEmpty && turns < 12) {
        engine.advanceMonth();
        turns++;
      }
      expect(engine.eventProvider.completedEventIds, contains(target),
          reason: '传闻路径必须标记一次性事件（跑了 $turns 回合仍未浮现；'
              '若 turns 达12，请检查玩家是否已 endGame 冻结时钟）');

      // 核心断言：被标记后 canTrigger 为false 且不在池中 = 门禁真的生效了
      final e = eventById(target)!;
      expect(engine.eventProvider.canTrigger(e, engine.player, season: engine.progress.season),
          isFalse,
          reason: '$target 已标记完成却仍可触发 = 门禁未生效');
      final still = engine.eventProvider
          .getAvailableEvents(engine.player, season: engine.progress.season)
          .where((e) => e.id == target)
          .toList();
      expect(still, isEmpty, reason: '已浮现的一次性事件仍在可触发池中 = 门禁仍未生效');
    });

    test('继续跑：同一条传闻不会二次标记（无重复条目）', () {
      final engine = GameEngine(events: _soloOneTimePool)..startNewGame();
      engine.updatePlayer(_richPlayer());
      // 上限 12 回合：与上条同理，须停在 endGame 冻结时钟之前
      for (var i = 0; i < 12; i++) {
        engine.advanceMonth();
      }
      final ids = engine.eventProvider.completedEventIds;
      expect(ids, contains('event_sword_inheritance'));
      expect(ids.where((id) => id == 'event_sword_inheritance').length, 1,
          reason: '同一条一次性传闻被标记了多次');
    });
  });

group('S4-6 实机（全库）：不变量而非概率', () {
      test('长跑 120 回合：只标记一次性事件、无重复、不超总数', () {
        // 【为什么不再断言「至少浮现 1 个」】全库口径下单回合命中概率仅约
        // 1.1%，300 回合零命中概率 ≈3.5%（CI 实测已踩中，见文件头）。
        // 本组改为断言**不变量**——无论浮现与否都必须成立，故确定且不脆弱。
        final engine = GameEngine()..startNewGame();
        engine.updatePlayer(_richPlayer());
        for (var i = 0; i < 120; i++) {
          engine.advanceMonth();
        }
        final ids = engine.eventProvider.completedEventIds;
        expect(ids.toSet().length, ids.length, reason: '不应出现重复条目');
        // 只应标记一次性事件（用 where 过滤而非 firstWhere，避免未匹配时抛异常）
        expect(ids.where((id) => eventById(id)?.isOneTime ?? false).length, ids.length,
            reason: '只应标记一次性事件，实际标记了：$ids');
        expect(ids.length, lessThanOrEqualTo(3), reason: '全库仅 3 个一次性事件');
        // 已标记的一次性事件必须立刻被 canTrigger 拦截（无论浮现过几次）
        for (final id in ids) {
          final e = eventById(id)!;
          expect(engine.eventProvider.canTrigger(e, engine.player, season: engine.progress.season),
              isFalse,
              reason: '$id 已标记完成却仍可触发 = 门禁未生效');
        }
      });

      test('真实全库 + 真实 RNG：12 回合内出现一次性传闻则必被标记并拦截', () {
        // 上一条可能整轮 0 标记（概率 ≈3.5%），等于空跑。本条用**真实全库**
        // 跑一个短窗口并做「有则有」的强断言：
        //   · 命中 → 立刻验证标记 + 从池中消失（真回归锁）
        //   · 未命中 → 只验证「没标记任何非一次性事件」，不硬要求命中
        // 这样无论 RNG 走向如何，用例都有实际断言力，且永不稳定。
        final engine = GameEngine()..startNewGame();
        engine.updatePlayer(_richPlayer());
        for (var i = 0; i < 12; i++) {
          engine.advanceMonth();
        }
        final provider = engine.eventProvider;
        final ids = provider.completedEventIds;
        expect(ids.where((id) => eventById(id)?.isOneTime ?? false).length, ids.length,
            reason: '绝不该标记非一次性事件，实际：$ids');
        for (final id in ids) {
          expect(
              provider.canTrigger(eventById(id)!, engine.player,
                  season: engine.progress.season),
              isFalse,
              reason: '$id 已标记却仍可触发');
          expect(
              provider
                  .getAvailableEvents(engine.player, season: engine.progress.season)
                  .where((e) => e.id == id),
              isEmpty,
              reason: '$id 仍在可触发池中');
        }
      });
    });

  group('S4-6 数据侧前提（防止测试悄悄失效）', () {
    test('恰好 3 个 isOneTime=true 事件', () {
      expect(allEvents.where((e) => e.isOneTime).length, 3);
    });

    test('3 个一次性事件的门槛均可被 richPlayer 满足（四季皆成立）', () {
      // 反向锁：若某个一次性事件的门槛 richPlayer 满足不了，它永远不可能
      // 浮现，本文件的实机覆盖面就会静默缩小（这正是初版翻车的直接原因）。
      final player = _richPlayer();
      for (final e in allEvents.where((e) => e.isOneTime)) {
        for (final season in _seasons) {
          expect(eventTriggersSatisfied(e, player, season: season), isTrue,
              reason: '${e.id} 在 $season 无法被 richPlayer 满足：${e.triggerConditions}');
        }
      }
    });

    test('一次性事件不得挂在空门槛上', () {
      // 反向锁：若有一次性事件是无门槛的，注入池场景会第 1 回合就抽到，
      // 测试覆盖不到「标记后从池中消失」这一步。
      final unconditional =
          allEvents.where((e) => e.isOneTime && e.triggerConditions.isEmpty).toList();
      expect(unconditional.map((e) => e.id), isEmpty,
          reason: '若出现无条件的一次性事件，需重新评估实机测试的确定性');
    });

    test('受控池只含 1 条事件且满足门槛（注入场景的前提）', () {
      final pool = _soloOneTimePool;
      expect(pool.length, 1);
      expect(pool.single.isOneTime, isTrue);
      for (final season in _seasons) {
        expect(eventTriggersSatisfied(pool.single, _richPlayer(), season: season), isTrue,
            reason: '受控池事件在 $season 不可触发，注入场景失效');
      }
    });
  });
}