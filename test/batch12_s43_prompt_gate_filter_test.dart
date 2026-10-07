/// S4-3 测试：prompt 事件筛选器真正执行门槛（P1-10 / P2-03 根因修复）。
///
/// 【本批修的是什么】
/// M4c-2 建的 `selectEventsForPrompt` 只做「打分排序 + 取前 12」，**从不过滤门槛**，
/// 于是 AI 被告知玩家当前不可能发生的事件。本批让它先按门槛过滤再排序。
///
/// 【为什么测试要写「不可能注入」而不是「分数正确」】
/// 原bug 的形态是「靠分数把坏事件挤掉恰好没挤掉」，属于**结果偶然正确**。
/// 因此断言必须锁死**契约**：门槛不满足的事件，一条都不许进prompt，
/// 无论它分数多高、无论总共有多少条可用事件。
///
/// 覆盖：
/// 1. 门槛过滤：季节/地点/数值/标记门槛不满足 → 一律不注入（S4-3 核心）
/// 2. 「分数高也不能豁免门槛」——这是本批最关键的边界锁
/// 3. 无条件事件恒可用（41 个），不会因过滤被误杀
/// 4. 预算截断仍生效，且截断在过滤之后
/// 5. 真实事件库契约：夏天玩家不再收到冬天门槛事件
/// 6. 排序稳定性与 `event_frozen_lake` 双命中仍居首
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/core/event_trigger_eval.dart';
import 'package:westeros_life_simulator/data/balance_data.dart';
import 'package:westeros_life_simulator/data/event_data.dart';
import 'package:westeros_life_simulator/models/event.dart';
import 'package:westeros_life_simulator/models/player.dart';
import 'package:westeros_life_simulator/services/event_prompt_filter.dart';

/// 构造一个测试事件。
GameEvent _ev(
  String id,
  int seq, {
  Map<String, String> conditions = const {},
}) {
  return GameEvent(
    id: id,
    name: '事件$seq',
    type: EventType.daily,
    description: '事件$seq 描述',
    triggerConditions: conditions,
    choices: const [
      EventChoice(
        id: 'c1',
        text: '选项一',
        requirements: const {},
        effects: const {'gold': 1},
        narrative: '叙事一',
      ),
    ],
    narrative: '事件$seq 叙事',
    tags: const ['test'],
    isOneTime: false,
  );
}

/// 构造 N 个无条件事件（id: event_gen_i）。
List<GameEvent> _genEvents(int n) {
  return [
    for (var i = 0; i < n; i++) _ev('event_gen_$i', i),
  ];
}

void main() {
  group('S4-3 门槛过滤（核心）', () {
    test('季节门槛不满足 → 不进 prompt（修前会被注入）', () {
      // 20 条高分无条件事件把预算占满，冬季门槛事件即使分数最高也该被剔除。
      final events = <GameEvent>[
        _ev('event_winter_only', 99, conditions: const {'season': 'winter'}),
        ..._genEvents(BalanceData.kAiPromptEventBudget + 8),
      ];
      final result = selectEventsForPrompt(
        events,
        player: Player.defaultPlayer(),
        season: 'summer',
      );
      expect(
        result.map((e) => e.id),
        isNot(contains('event_winter_only')),
        reason: 'summer 玩家绝不该被告知winter 门槛事件',
      );
    });

    test('地点门槛不满足 → 不进 prompt', () {
      final events = <GameEvent>[
        _ev('event_here_only', 99,
            conditions: const {'locationId': 'location_kingslanding'}),
        ..._genEvents(BalanceData.kAiPromptEventBudget + 8),
      ];
      final result = selectEventsForPrompt(
        events,
        player: Player.defaultPlayer(), // 默认在 location_winterfell
        season: 'winter',
      );
      expect(result.map((e) => e.id), isNot(contains('event_here_only')));
    });

    test('数值门槛不满足 → 不进 prompt', () {
      final events = <GameEvent>[
        _ev('event_rich_only', 99, conditions: const {'minGold': '9999'}),
        ..._genEvents(BalanceData.kAiPromptEventBudget + 8),
      ];
      final result = selectEventsForPrompt(
        events,
        player: Player.defaultPlayer(), // gold=100
        season: 'winter',
      );
      expect(result.map((e) => e.id), isNot(contains('event_rich_only')));
    });

    test('标记门槛不满足 → 不进 prompt', () {
      final events = <GameEvent>[
        _ev('event_flag_only', 99, conditions: const {'flag': 'has_sword'}),
        ..._genEvents(BalanceData.kAiPromptEventBudget + 8),
      ];
      final result = selectEventsForPrompt(
        events,
        player: Player.defaultPlayer(), // 无 has_sword
        season: 'winter',
      );
      expect(result.map((e) => e.id), isNot(contains('event_flag_only')));
    });

    test('技能门槛不满足 → 不进 prompt', () {
      final events = <GameEvent>[
        _ev('event_master_alchemy', 99,
            conditions: const {'skills.alchemy': '10'}), // 默认 alchemy=0
        ..._genEvents(BalanceData.kAiPromptEventBudget + 8),
      ];
      final result = selectEventsForPrompt(
        events,
        player: Player.defaultPlayer(),
        season: 'winter',
      );
      expect(result.map((e) => e.id), isNot(contains('event_master_alchemy')));
    });
  });

  group('S4-3 边界锁：分数不能豁免门槛', () {
    test('地点+季节双命中（理论最高分）在门槛不满足时仍被剔除', () {
      // 这是本批最关键的一条：event_frozen_lake 正是「location+season」双命中，
      // 修之前它会稳居第一并被注入夏天的 prompt。分数再高也不能豁免门槛。
      final events = <GameEvent>[
        _ev('event_double_miss', 99, conditions: const {
          'locationId': 'location_winterfell',
          'season': 'winter',
        }),
        ..._genEvents(BalanceData.kAiPromptEventBudget + 8),
      ];
      final result = selectEventsForPrompt(
        events,
        player: Player.defaultPlayer(),
        season: 'summer', // 地点命中、季节不命中 → 门槛整体不满足
      );
      expect(result.map((e) => e.id), isNot(contains('event_double_miss')));
    });

    test('注入的每一条事件都必须真的通过门槛（全集校验）', () {
      // 不只盯某几个 id，而是对整批注入结果做全量校验——
      // 防止将来新增门槛键时又出现「注入了不该出现的事件」。
      final player = Player.defaultPlayer();
      for (final season in const ['spring', 'summer', 'autumn', 'winter']) {
        final result =
            selectEventsForPrompt(allEvents, player: player, season: season);
        for (final e in result) {
          expect(
            eventTriggersSatisfied(e, player, season: season),
            isTrue,
            reason: '$season 季节下 ${e.id} 门槛不满足却被注入 prompt',
          );
        }
      }
    });

    test('门槛满足时正常注入（防止把过滤做过头）', () {
      final events = <GameEvent>[
        _ev('event_winter_ok', 99, conditions: const {'season': 'winter'}),
        ..._genEvents(5),
      ];
      final result = selectEventsForPrompt(
        events,
        player: Player.defaultPlayer(),
        season: 'winter',
      );
      expect(result.map((e) => e.id), contains('event_winter_ok'));
    });

    test("season: 'any' 仍视为任意季节可用（10-103 契约不得回归）", () {
      final events = <GameEvent>[
        _ev('event_any_season', 99, conditions: const {'season': 'any'}),
        ..._genEvents(5),
      ];
      for (final season in const ['spring', 'summer', 'autumn', 'winter']) {
        final result =
            selectEventsForPrompt(events, player: Player.defaultPlayer(), season: season);
        expect(result.map((e) => e.id), contains('event_any_season'),
            reason: "season:'any' 在 $season 应仍然可用");
      }
    });
  });

  group('S4-3 无条件事件与预算', () {
    test('41 个无条件事件恒可用，不被过滤误杀', () {
      final unconditional = allEvents
          .where((e) => e.triggerConditions.isEmpty)
          .toList();
      // 文档口径：71 个事件里 41 个无门槛。
      expect(unconditional, hasLength(41));
      final result = selectEventsForPrompt(
        allEvents,
        player: Player.defaultPlayer(),
        season: 'summer',
      );
      final ids = result.map((e) => e.id).toSet();
      // 无条件事件恒满足门槛，故凡进入结果集的都必须来自这 41 个——
      // 换个角度：结果里不该出现「有门槛且不满足」的任何事件。
      for (final id in ids) {
        final e = allEvents.firstWhere((x) => x.id == id);
        expect(e.triggerConditions.isEmpty ||
            eventTriggersSatisfied(e, Player.defaultPlayer(), season: 'summer'),
            isTrue);
      }
    });

    test('过滤发生在截断之前：可用数 ≤ 预算时全返回、> 预算时截到预算', () {
      final player = Player.defaultPlayer();
      // 71 → 过滤后 50+ → 超预算 → 截到 12。
      final result =
          selectEventsForPrompt(allEvents, player: player, season: 'winter');
      expect(result, hasLength(BalanceData.kAiPromptEventBudget));

      // 小列表：过滤后不足预算 → 全返回，不截断也不补齐。
      final small = _genEvents(5);
      final smallResult =
          selectEventsForPrompt(small, player: player, season: 'winter');
      expect(smallResult, hasLength(5));
    });

    test('同分保持原列表顺序（排序稳定性未被过滤破坏）', () {
      final events = _genEvents(BalanceData.kAiPromptEventBudget + 3);
      final result = selectEventsForPrompt(
        events,
        player: Player.defaultPlayer(),
        season: 'winter',
      );
      expect(result.map((e) => e.id).toList(), [
        'event_gen_0',
        'event_gen_1',
        'event_gen_2',
        'event_gen_3',
        'event_gen_4',
        'event_gen_5',
        'event_gen_6',
        'event_gen_7',
        'event_gen_8',
        'event_gen_9',
        'event_gen_10',
        'event_gen_11',
      ]);
    });

    test('地点命中的事件仍排最前（在已通过门槛的事件之间）', () {
      final events = <GameEvent>[
        ..._genEvents(BalanceData.kAiPromptEventBudget + 8),
        _ev('event_loc', 99,
            conditions: const {'locationId': 'location_winterfell'}),
      ];
      final result = selectEventsForPrompt(
        events,
        player: Player.defaultPlayer(),
        season: 'winter',
      );
      expect(result.first.id, 'event_loc');
    });
  });

  group('S4-3 真实事件库契约', () {
    test('默认玩家（临冬城·冬）：地点/季节强相关必入选', () {
      final player = Player.defaultPlayer();
      final result =
          selectEventsForPrompt(allEvents, player: player, season: 'winter');
      final ids = result.map((e) => e.id).toSet();
      // 地点命中（location_winterfell）+ 冬季
      expect(ids, contains('event_frozen_lake'));
      expect(ids, contains('event_famine'));
      expect(ids, contains('event_winter_sickness'));
      expect(ids, contains('event_stray_direwolf'));
      expect(result, hasLength(BalanceData.kAiPromptEventBudget));
      expect(result.first.id, 'event_frozen_lake');
    });

    test('夏季玩家：不再收到任何 winter 门槛事件（S4-3 修复的直接效果）', () {
      // 修之前这条会挂：event_frozen_lake（winterfell + winter）在夏天的
      // prompt 里排第一。S4-3 要求它彻底消失。
      final player = Player.defaultPlayer();
      final result =
          selectEventsForPrompt(allEvents, player: player, season: 'summer');
      final ids = result.map((e) => e.id).toSet();
      expect(ids, isNot(contains('event_frozen_lake')),
          reason: 'event_frozen_lake 有winter 门槛，夏天不该出现');
      expect(ids, isNot(contains('event_ghost_road')),
          reason: 'event_ghost_road 有winter 门槛，夏天不该出现');
      // 而夏季事件应当照常入选
      expect(ids, contains('event_market_surplus'));
      expect(ids, contains('event_trade_fair'));
    });

    test('各季节注入的事件都不含该季节不可能的门槛', () {
      final player = Player.defaultPlayer();
      final winterOnly = <String>{
        'event_frozen_lake',
        'event_ghost_road',
        'event_famine',
        'event_winter_sickness',
        'event_stray_direwolf',
        'event_knight_night_watch',
      };
      final summerResult =
          selectEventsForPrompt(allEvents, player: player, season: 'summer');
      expect(
        summerResult.map((e) => e.id).toSet().intersection(winterOnly),
        isEmpty,
        reason: 'summer prompt 不得含任何 winter 门槛事件',
      );
    });
  });
}
