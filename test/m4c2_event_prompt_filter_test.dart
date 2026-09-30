/// M4c-2 测试：事件 prompt 预算筛选器（lib/services/event_prompt_filter.dart）。
///
/// 覆盖：
/// 1. 不超过预算时全量返回（不截断，保持原语义）
/// 2. 超过预算时按相关度截断到预算数
/// 3. 相关度排序：地点 / 季节 / 数值 / 标记命中事件优先
/// 4. 同分稳定性（保持原列表顺序）
/// 5. 不满足条件的事件不加分（与无条件事件同层）
/// 6. 预算常量契约
library;

import 'package:flutter_test/flutter_test.dart';
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
  group('M4c-2 预算截断', () {
    test('不超过预算时全量返回且顺序不变', () {
      final events = _genEvents(5);
      final player = Player.defaultPlayer();
      final result = selectEventsForPrompt(events, player: player, season: 'winter');
      expect(result, hasLength(5));
      expect(result.map((e) => e.id).toList(),
          ['event_gen_0', 'event_gen_1', 'event_gen_2', 'event_gen_3', 'event_gen_4']);
    });

    test('超过预算时截断到预算数', () {
      final events = _genEvents(BalanceData.kAiPromptEventBudget + 8);
      final player = Player.defaultPlayer();
      final result = selectEventsForPrompt(events, player: player, season: 'winter');
      expect(result, hasLength(BalanceData.kAiPromptEventBudget));
    });
  });

  group('M4c-2 相关度排序', () {
    test('地点命中事件排在最前', () {
      final events = <GameEvent>[
        ..._genEvents(10),
        _ev('event_loc', 99, conditions: const {'locationId': 'location_winterfell'}),
        ..._genEvents(10),
      ];
      final player = Player.defaultPlayer(); // 默认在 location_winterfell
      final result = selectEventsForPrompt(events, player: player, season: 'winter');
      expect(result.first.id, 'event_loc');
      expect(result, hasLength(BalanceData.kAiPromptEventBudget));
    });

    test('季节命中事件排前', () {
      final events = <GameEvent>[
        ..._genEvents(BalanceData.kAiPromptEventBudget + 5),
        _ev('event_season', 99, conditions: const {'season': 'winter'}),
      ];
      final player = Player.defaultPlayer();
      final result = selectEventsForPrompt(events, player: player, season: 'winter');
      expect(result.first.id, 'event_season');
    });

    test('数值条件满足时加分', () {
      final events = <GameEvent>[
        ..._genEvents(BalanceData.kAiPromptEventBudget + 5),
        _ev('event_gold', 99, conditions: const {'minGold': '50'}),
      ];
      final player = Player.defaultPlayer().copyWith(gold: 100);
      final result = selectEventsForPrompt(events, player: player, season: 'winter');
      expect(result.first.id, 'event_gold');
    });

    test('标记条件满足时加分', () {
      final events = <GameEvent>[
        ..._genEvents(BalanceData.kAiPromptEventBudget + 5),
        _ev('event_flag', 99, conditions: const {'flag': 'has_sword'}),
      ];
      final player = Player.defaultPlayer().copyWith(
        flags: <String, bool>{...Player.defaultPlayer().flags, 'has_sword': true},
      );
      final result = selectEventsForPrompt(events, player: player, season: 'winter');
      expect(result.first.id, 'event_flag');
    });
  });

  group('M4c-2 真实事件库契约', () {
    test('默认玩家（临冬城·冬）筛选 72 事件：地点/季节强相关必入选', () {
      final player = Player.defaultPlayer();
      final result = selectEventsForPrompt(allEvents, player: player, season: 'winter');
      final ids = result.map((e) => e.id).toSet();
      // 地点命中（location_winterfell）
      expect(ids, contains('event_frozen_lake'));
      // 冬季季节命中
      expect(ids, contains('event_famine'));
      expect(ids, contains('event_winter_sickness'));
      expect(ids, contains('event_stray_direwolf'));
      // 预算截断生效
      expect(result.length, BalanceData.kAiPromptEventBudget);
      // 冰封湖面（地点+季节双命中）应排第一
      expect(result.first.id, 'event_frozen_lake');
    });

    test('夏季玩家：冬季事件让位给夏季事件', () {
      final player = Player.defaultPlayer();
      final result = selectEventsForPrompt(allEvents, player: player, season: 'summer');
      final ids = result.map((e) => e.id).toSet();
      expect(ids, contains('event_frozen_lake')); // 地点命中仍入选
      expect(ids, contains('event_market_surplus')); // 夏季事件入选
      expect(ids, contains('event_trade_fair')); // 夏季事件入选
      expect(result.first.id, 'event_frozen_lake'); // 地点双分仍第一
    });
  });
}