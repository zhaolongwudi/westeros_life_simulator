/// Batch 3 测试：EventProvider。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/event_data.dart';
import 'package:westeros_life_simulator/models/event.dart';
import 'package:westeros_life_simulator/models/player.dart';
import 'package:westeros_life_simulator/providers/event_provider.dart';

void main() {
  group('EventProvider', () {
    test('默认加载所有事件', () {
      final provider = EventProvider();
      expect(provider.allEvents.length, allEvents.length);
      expect(provider.triggeredEvents, isEmpty);
      expect(provider.completedEventIds, isEmpty);
    });

    test('自定义事件列表', () {
      final events = [GameEvent.defaultEvent()];
      final provider = EventProvider(events: events);
      expect(provider.allEvents.length, 1);
    });

    test('canTrigger 无条件事件可触发', () {
      final provider = EventProvider();
      final event = GameEvent(
        id: 'test_no_cond',
        name: '无条件',
        type: EventType.daily,
        description: '测试',
        triggerConditions: const {},
        choices: const [],
        narrative: '测试',
        tags: const [],
        isOneTime: false,
      );
      final player = Player.defaultPlayer();
      expect(provider.canTrigger(event, player), true);
    });

    test('canTrigger 地点条件', () {
      final provider = EventProvider();
      final event = GameEvent(
        id: 'test_location',
        name: '地点测试',
        type: EventType.daily,
        description: '测试',
        triggerConditions: const {'locationId': 'location_winterfell'},
        choices: const [],
        narrative: '测试',
        tags: const [],
        isOneTime: false,
      );
      final player = Player.defaultPlayer();
      expect(provider.canTrigger(event, player), true);

      final otherPlayer = player.copyWith(locationId: 'location_king_s_landing');
      expect(provider.canTrigger(event, otherPlayer), false);
    });

    test('canTrigger 年龄条件', () {
      final provider = EventProvider();
      final event = GameEvent(
        id: 'test_age',
        name: '年龄测试',
        type: EventType.daily,
        description: '测试',
        triggerConditions: const {'minAge': '20'},
        choices: const [],
        narrative: '测试',
        tags: const [],
        isOneTime: false,
      );
      final youngPlayer = Player.defaultPlayer().copyWith(age: 15);
      final oldPlayer = Player.defaultPlayer().copyWith(age: 25);
      expect(provider.canTrigger(event, youngPlayer), false);
      expect(provider.canTrigger(event, oldPlayer), true);
    });

    test('canTrigger 金币条件', () {
      final provider = EventProvider();
      final event = GameEvent(
        id: 'test_gold',
        name: '金币测试',
        type: EventType.daily,
        description: '测试',
        triggerConditions: const {'minGold': '200'},
        choices: const [],
        narrative: '测试',
        tags: const [],
        isOneTime: false,
      );
      final poorPlayer = Player.defaultPlayer().copyWith(gold: 100);
      final richPlayer = Player.defaultPlayer().copyWith(gold: 300);
      expect(provider.canTrigger(event, poorPlayer), false);
      expect(provider.canTrigger(event, richPlayer), true);
    });

    test('canTrigger 技能条件', () {
      final provider = EventProvider();
      final event = GameEvent(
        id: 'test_skill',
        name: '技能测试',
        type: EventType.daily,
        description: '测试',
        triggerConditions: const {'skills.sword': '5'},
        choices: const [],
        narrative: '测试',
        tags: const [],
        isOneTime: false,
      );
      final weakPlayer = Player.defaultPlayer().copyWith(
        skills: {'sword': 3},
      );
      final strongPlayer = Player.defaultPlayer().copyWith(
        skills: {'sword': 5},
      );
      expect(provider.canTrigger(event, weakPlayer), false);
      expect(provider.canTrigger(event, strongPlayer), true);
    });

    test('canTrigger 一次性事件已完成', () {
      final provider = EventProvider();
      final event = GameEvent(
        id: 'test_onetime',
        name: '一次性',
        type: EventType.daily,
        description: '测试',
        triggerConditions: const {},
        choices: const [],
        narrative: '测试',
        tags: const [],
        isOneTime: true,
      );
      final player = Player.defaultPlayer();
      expect(provider.canTrigger(event, player), true);
      provider.markCompleted(event.id);
      expect(provider.canTrigger(event, player), false);
    });

    test('getAvailableEvents 返回可触发事件', () {
      final provider = EventProvider();
      final player = Player.defaultPlayer();
      final available = provider.getAvailableEvents(player);
      expect(available, isNotEmpty);
    });

    test('triggerRandomEvent 触发事件', () {
      final provider = EventProvider();
      final player = Player.defaultPlayer();
      final event = provider.triggerRandomEvent(player);
      expect(event, isNotNull);
      expect(provider.triggeredEvents.length, 1);
    });

    test('markCompleted 标记完成', () {
      final provider = EventProvider();
      provider.markCompleted('event_1');
      provider.markCompleted('event_1'); // 重复
      expect(provider.completedEventIds.length, 1);
    });

    test('canChoose 无条件选项可用', () {
      final provider = EventProvider();
      final choice = EventChoice(
        id: 'c1',
        text: '测试',
        requirements: const {},
        effects: const {},
        narrative: '测试',
      );
      final player = Player.defaultPlayer();
      expect(provider.canChoose(choice, player), true);
    });

    test('canChoose 金币不足', () {
      final provider = EventProvider();
      final choice = EventChoice(
        id: 'c1',
        text: '测试',
        requirements: const {'gold': 200},
        effects: const {},
        narrative: '测试',
      );
      final poorPlayer = Player.defaultPlayer().copyWith(gold: 100);
      expect(provider.canChoose(choice, poorPlayer), false);
    });

    test('getAvailableChoices 返回可用选项', () {
      final provider = EventProvider();
      final event = GameEvent.defaultEvent();
      final player = Player.defaultPlayer();
      final choices = provider.getAvailableChoices(event, player);
      expect(choices, isNotEmpty);
    });

    test('reset 重置状态', () {
      final provider = EventProvider();
      provider.markCompleted('event_1');
      provider.triggerRandomEvent(Player.defaultPlayer());
      provider.reset();
      expect(provider.completedEventIds, isEmpty);
      expect(provider.triggeredEvents, isEmpty);
    });
  });
}