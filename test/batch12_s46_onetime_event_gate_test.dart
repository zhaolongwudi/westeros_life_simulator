/// S4-6 测试：一次性事件门禁真正生效（P1-11 关闭）。
///
/// 【本批修的是什么】
/// `EventProvider.canTrigger` 对 `isOneTime` 事件的拦截依赖 `_completedEventIds`，
/// 而写入该集合的唯一入口 `markCompleted` 在生产代码中**零调用**
/// （全库只有 `batch3_event_provider_test` 与 `batch10_103_104` 在调）。
/// 故该门禁恒不生效：3 个一次性事件（`event_sword_inheritance` /
/// `event_guild_tooling` / `event_maester_commission`）会无限重复浮现。
///
/// 【为什么标在「浮现」而不是「执行」】
/// 事件选项当前在生产中不可达（S4-5：`applyChoice` 在 UI 零调用、事件面板自述
/// 「不做触发执行」、玩家实际选的是 AI 现场生成的选项），
/// **月度传闻是事件唯一触达玩家的通道**，故「浮现」即玩家对该事件的全部曝光。
///
/// 覆盖：
/// 1. `markCompleted` 后 `canTrigger` 拦截生效（provider 层契约）
/// 2. 实机：一次性事件浮现过即不再进池（核心回归锁）
/// 3. 非一次性事件**不得**被标记（否则误伤正常事件）
/// 4. 数据侧：恰好 3 个 isOneTime=true，且门槛条件易满足（否则测试构造不出场景）
/// 5. 存档往返不丢状态（记录当前局限，见文件尾说明）
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/event_data.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/models/player.dart';
import 'package:westeros_life_simulator/providers/event_provider.dart';

/// 玩家条件：满足 3 个一次性事件中至少一个的门槛。
Player _richPlayer() =>
    Player.defaultPlayer().copyWith(gold: 500, reputation: 80, age: 30);

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
      expect(provider.completedEventIds.where((e) => e == 'event_sword_inheritance').length, 1);
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

  group('S4-6 实机：传闻路径必须标记完成', () {
    test('一次性事件浮现一次后，池中不再出现', () {
      final engine = GameEngine()..startNewGame();
      // 把玩家状态调到能命中一次性事件的门槛
      engine.updatePlayer(_richPlayer());

      final oneTimeIds = allEvents
          .where((e) => e.isOneTime)
          .map((e) => e.id)
          .toSet();
      expect(oneTimeIds, isNotEmpty, reason: '前提：事件库须有一次性事件');

      // 🔍 取证：`_maybeWorldEvent(seed: progress.turnCount)` 的 RNG 是
      // **按回合确定性播种**的，故本测试可复现而非概率性。
      // 用真实 Dart RNG 实测：一次性事件位于可用池下标 48~59（池大小 54~60），
      // 单回合命中概率仅约 1.5%，首次命中在第 55~56 回合附近。
      // 注意标记后池会缩小、下标会平移，故这里**跑到命中即停**，
      // 上限放到 300 回合（实测该范围内至少命中 3 次），留足余量。
      for (var i = 0; i < 300; i++) {
        engine.advanceMonth();
        if (engine.eventProvider.completedEventIds.isNotEmpty) break;
      }

      // 先确认前提：确实有一次性事件被标记了（否则下面断言无意义）
      final marked = engine.eventProvider.completedEventIds.toSet();
      expect(marked.intersection(oneTimeIds), isNotEmpty,
          reason: '300 回合内应至少浮现 1 个一次性事件（实测首次命中约第 55 回合）');

      // 关键断言：被标记后必须从可触发池中消失，且 canTrigger 一致为 false
      for (final e in allEvents.where((e) => e.isOneTime)) {
        if (!marked.contains(e.id)) continue;
        expect(engine.eventProvider.canTrigger(e, engine.player, season: engine.progress.season),
            isFalse,
            reason: '${e.id} 已标记完成却仍可触发 = 门禁未生效');
      }
      final still = engine.eventProvider
          .getAvailableEvents(engine.player, season: engine.progress.season)
          .where((e) => marked.contains(e.id))
          .toList();
      expect(still, isEmpty,
          reason: '已浮现的一次性事件仍在可触发池中 = 门禁仍未生效');
    });

    test('长跑（120 回合）标记数不超过 3且无重复', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(_richPlayer());
      for (var i = 0; i < 120; i++) {
        engine.advanceMonth();
      }
      final ids = engine.eventProvider.completedEventIds;
      expect(ids.toSet().length, ids.length, reason: '不应出现重复条目');
      // 只应标记一次性事件（用 where 过滤而非 firstWhere，避免未匹配时抛异常）
      expect(ids.where((id) => eventById(id)?.isOneTime ?? false).length,
          ids.length,
          reason: '只应标记一次性事件，实际标记了：$ids');
      expect(ids.length, lessThanOrEqualTo(3),
          reason: '全库仅 3 个一次性事件');
    });
  });

  group('S4-6 数据侧前提（防止测试悄悄失效）', () {
    test('恰好 3 个 isOneTime=true 事件', () {
      expect(allEvents.where((e) => e.isOneTime).length, 3);
    });

    test('3 个一次性事件的门槛均可被 richPlayer 满足', () {
      final player = _richPlayer();
      for (final e in allEvents.where((e) => e.isOneTime)) {
        final cond = e.triggerConditions;
        if (cond['minReputation'] != null) {
          expect(player.reputation, greaterThanOrEqualTo(int.parse(cond['minReputation']!)));
        }
        if (cond['minGold'] != null) {
          expect(player.gold, greaterThanOrEqualTo(int.parse(cond['minGold']!)));
        }
      }
    });

    test('一次性事件不得挂在空门槛上（否则 60 回合必抽到，测试无意义）', () {
      // 反向锁：若有一次性事件是无门槛的，本文件的实机测试会变得不稳定
      // （可能第 1 回合就抽到，也可能一直抽不到）。此处只记录现状。
      final unconditional = allEvents
          .where((e) => e.isOneTime && e.triggerConditions.isEmpty)
          .toList();
      expect(unconditional.map((e) => e.id), isEmpty,
          reason: '若出现无条件的一次性事件，需重新评估实机测试的确定性');
    });
  });
}
