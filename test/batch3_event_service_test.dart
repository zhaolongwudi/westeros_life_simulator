/// Batch 3 测试：EventService。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/models/event.dart';
import 'package:westeros_life_simulator/models/player.dart';
import 'package:westeros_life_simulator/services/event_service.dart';

void main() {
  group('EventService', () {
    final service = const EventService();

    test('checkTriggerConditions 无条件', () {
      final event = GameEvent(
        id: 'test',
        name: '测试',
        type: EventType.daily,
        description: '测试',
        triggerConditions: const {},
        choices: const [],
        narrative: '测试',
        tags: const [],
        isOneTime: false,
      );
      final player = Player.defaultPlayer();
      expect(service.checkTriggerConditions(event, player, const {}), true);
    });

    test('checkTriggerConditions 上下文匹配', () {
      final event = GameEvent(
        id: 'test',
        name: '测试',
        type: EventType.daily,
        description: '测试',
        triggerConditions: const {'season': 'winter'},
        choices: const [],
        narrative: '测试',
        tags: const [],
        isOneTime: false,
      );
      final player = Player.defaultPlayer();
      expect(
        service.checkTriggerConditions(event, player, {'season': 'winter'}),
        true,
      );
      expect(
        service.checkTriggerConditions(event, player, {'season': 'summer'}),
        false,
      );
    });

    test('checkTriggerConditions 玩家条件', () {
      final event = GameEvent(
        id: 'test',
        name: '测试',
        type: EventType.daily,
        description: '测试',
        triggerConditions: const {'locationId': 'location_winterfell'},
        choices: const [],
        narrative: '测试',
        tags: const [],
        isOneTime: false,
      );
      final player = Player.defaultPlayer();
      expect(service.checkTriggerConditions(event, player, const {}), true);
    });

    test('applyEffects 金币效果', () {
      final player = Player.defaultPlayer();
      final choice = EventChoice(
        id: 'c1',
        text: '测试',
        requirements: const {},
        effects: const {'gold': 50},
        narrative: '测试',
      );
      final result = service.applyEffects(player, choice);
      expect(result.newPlayer.gold, player.gold + 50);
      expect(result.appliedEffects['gold'], 50);
      expect(result.failedEffects, isEmpty);
    });

    test('applyEffects 金币不足', () {
      final player = Player.defaultPlayer().copyWith(gold: 10);
      final choice = EventChoice(
        id: 'c1',
        text: '测试',
        requirements: const {},
        effects: const {'gold': -50},
        narrative: '测试',
      );
      final result = service.applyEffects(player, choice);
      expect(result.newPlayer.gold, 10);
      expect(result.failedEffects['gold'], -50);
    });

    test('applyEffects 声望效果', () {
      final player = Player.defaultPlayer();
      final choice = EventChoice(
        id: 'c1',
        text: '测试',
        requirements: const {},
        effects: const {'reputation': 10},
        narrative: '测试',
      );
      final result = service.applyEffects(player, choice);
      expect(result.newPlayer.reputation, player.reputation + 10);
    });

    test('applyEffects 声望上限', () {
      final player = Player.defaultPlayer().copyWith(reputation: 95);
      final choice = EventChoice(
        id: 'c1',
        text: '测试',
        requirements: const {},
        effects: const {'reputation': 20},
        narrative: '测试',
      );
      final result = service.applyEffects(player, choice);
      expect(result.newPlayer.reputation, 100);
    });

    test('applyEffects 技能效果', () {
      final player = Player.defaultPlayer();
      final choice = EventChoice(
        id: 'c1',
        text: '测试',
        requirements: const {},
        effects: const {'skills.sword': 2},
        narrative: '测试',
      );
      final result = service.applyEffects(player, choice);
      expect(result.newPlayer.skills['sword'], player.skills['sword']! + 2);
    });

    test('applyEffects 属性效果', () {
      final player = Player.defaultPlayer();
      final choice = EventChoice(
        id: 'c1',
        text: '测试',
        requirements: const {},
        effects: const {'attributes.strength': 1},
        narrative: '测试',
      );
      final result = service.applyEffects(player, choice);
      expect(
        result.newPlayer.attributes['strength'],
        player.attributes['strength']! + 1,
      );
    });

    test('applyEffects 关系效果', () {
      final player = Player.defaultPlayer();
      final choice = EventChoice(
        id: 'c1',
        text: '测试',
        requirements: const {},
        effects: const {'relations.npc_1': 10},
        narrative: '测试',
      );
      final result = service.applyEffects(player, choice);
      expect(result.newPlayer.relations['npc_1'], 10);
    });

    test('applyEffects 标记效果', () {
      final player = Player.defaultPlayer();
      final choice = EventChoice(
        id: 'c1',
        text: '测试',
        requirements: const {},
        effects: const {'flags.isMarried': 1},
        narrative: '测试',
      );
      final result = service.applyEffects(player, choice);
      expect(result.newPlayer.flags['isMarried'], true);
    });

    test('canChoose 无条件', () {
      final choice = EventChoice(
        id: 'c1',
        text: '测试',
        requirements: const {},
        effects: const {},
        narrative: '测试',
      );
      final player = Player.defaultPlayer();
      expect(service.canChoose(choice, player), true);
    });

    test('canChoose 金币不足', () {
      final choice = EventChoice(
        id: 'c1',
        text: '测试',
        requirements: const {'gold': 200},
        effects: const {},
        narrative: '测试',
      );
      final player = Player.defaultPlayer().copyWith(gold: 100);
      expect(service.canChoose(choice, player), false);
    });

    test('filterByTags 筛选', () {
      final events = [
        GameEvent(
          id: 'e1',
          name: '事件 1',
          type: EventType.daily,
          description: '测试',
          triggerConditions: const {},
          choices: const [],
          narrative: '测试',
          tags: const ['winter', 'north'],
          isOneTime: false,
        ),
        GameEvent(
          id: 'e2',
          name: '事件 2',
          type: EventType.daily,
          description: '测试',
          triggerConditions: const {},
          choices: const [],
          narrative: '测试',
          tags: const ['summer', 'south'],
          isOneTime: false,
        ),
      ];
      final result = service.filterByTags(events, ['winter']);
      expect(result.length, 1);
      expect(result[0].id, 'e1');
    });

    test('filterByType 筛选', () {
      final events = [
        GameEvent(
          id: 'e1',
          name: '事件 1',
          type: EventType.political,
          description: '测试',
          triggerConditions: const {},
          choices: const [],
          narrative: '测试',
          tags: const [],
          isOneTime: false,
        ),
        GameEvent(
          id: 'e2',
          name: '事件 2',
          type: EventType.daily,
          description: '测试',
          triggerConditions: const {},
          choices: const [],
          narrative: '测试',
          tags: const [],
          isOneTime: false,
        ),
      ];
      final result = service.filterByType(events, EventType.political);
      expect(result.length, 1);
      expect(result[0].id, 'e1');
    });
  });
}