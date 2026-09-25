/// Batch 10-2 测试：生存导向事件库 + 事件系统生存轴扩展。
///
/// 覆盖：
/// 1. 新事件触发条件（season/flag/noFlag/minGold/maxEnergy/hasItem）
/// 2. 事件选项要求（health/energy/hunger/hasItem/flag）
/// 3. 生存轴效果键经 EventService 正确落盘（health/hunger/inventory./flags.）
/// 4. season 触发键（EventProvider 新支持）
/// 5. 事件总数与类型分布
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/event_data.dart';
import 'package:westeros_life_simulator/models/event.dart';
import 'package:westeros_life_simulator/models/player.dart';
import 'package:westeros_life_simulator/providers/event_provider.dart';
import 'package:westeros_life_simulator/services/event_service.dart';

void main() {
  group('Batch 10-2 事件库扩充', () {
    test('事件总数 72 且类型分布正确', () {
      expect(allEvents.length, 72);
      expect(eventsByType(EventType.political).length, 11);
      expect(eventsByType(EventType.family).length, 11);
      expect(eventsByType(EventType.economic).length, 13);
      expect(eventsByType(EventType.magical).length, 6);
      expect(eventsByType(EventType.daily).length, 6);
      expect(eventsByType(EventType.war).length, 8);
      expect(eventsByType(EventType.religious).length, 7);
      expect(eventsByType(EventType.adventure).length, 5);
      expect(eventsByType(EventType.supernatural).length, 5);
    });

    test('新生存事件存在且选项有效', () {
      for (final id in <String>[
        'event_wound_fester',
        'event_food_shortage',
        'event_winter_sickness',
        'event_road_bandits',
        'event_wild_beasts',
        'event_stray_direwolf',
        'event_trade_opportunity',
        'event_ship_wreck',
        'event_ghost_road',
        'event_dream_omen',
        'event_red_comet',
        'event_glass_candle',
        'event_white_walker_sighting',
        'event_frozen_lake',
        'event_market_surplus',
      ]) {
        final e = eventById(id);
        expect(e, isNotNull, reason: '$id 不存在');
        expect(e!.choices.length, greaterThanOrEqualTo(2));
        for (final c in e.choices) {
          expect(c.text.isNotEmpty, true);
          expect(c.narrative.isNotEmpty, true);
        }
      }
    });

    test('新事件引用的物品 ID 均有效', () {
      // 从 item_data 拿到全部有效物品 ID
      final valid = <String>{
        'item_bread', 'item_meat', 'item_fish', 'item_wine', 'item_herb',
        'item_poultice', 'item_dreamwine', 'item_dagger', 'item_sword',
        'item_bastard_sword', 'item_bow', 'item_valyrian_dagger',
        'item_leather_armor', 'item_chainmail', 'item_plate_armor',
        'item_iron_ore', 'item_steel', 'item_leather', 'item_dragonbone',
        'item_glass_candle', 'item_gold_chain', 'item_ruby', 'item_sapphire',
        'item_crown', 'item_heart_tree_leaf', 'item_seven_star',
        'item_lightbringer_shard', 'item_parchment', 'item_raven_letter',
        'item_treaty', 'item_recipe_dragonfire', 'item_horse', 'item_garron',
      };
      for (final e in allEvents) {
        for (final c in e.choices) {
          for (final key in c.requirements.keys) {
            if (key.startsWith('hasItem.')) {
              final itemId = key.substring(8);
              expect(valid.contains(itemId), true,
                  reason: '${e.id} 要求未知物品 $itemId');
            }
          }
          for (final key in c.effects.keys) {
            if (key.startsWith('inventory.')) {
              final itemId = key.substring(10);
              expect(valid.contains(itemId), true,
                  reason: '${e.id} 效果引用未知物品 $itemId');
            }
          }
        }
      }
    });
  });

  group('Batch 10-2 EventProvider 生存轴触发条件', () {
    test('season 触发：冬季事件仅在冬季可触发', () {
      final provider = EventProvider(events: allEvents);
      final p = Player.defaultPlayer();
      final winterEvent = eventById('event_winter_sickness')!;
      final summerEvent = eventById('event_market_surplus')!;

      expect(provider.canTrigger(winterEvent, p, season: 'winter'), true);
      expect(provider.canTrigger(winterEvent, p, season: 'summer'), false);
      expect(provider.canTrigger(summerEvent, p, season: 'summer'), true);
      expect(provider.canTrigger(summerEvent, p, season: 'winter'), false);
    });

    test('flag 触发：受伤事件仅在 isInjured 时触发', () {
      final provider = EventProvider(events: allEvents);
      final p = Player.defaultPlayer();
      final e = eventById('event_wound_fester')!;
      expect(provider.canTrigger(e, p), false);
      final injured = p.copyWith(
        flags: <String, bool>{...p.flags, 'isInjured': true},
      );
      expect(provider.canTrigger(e, injured), true);
    });

    test('noFlag 触发：野兽袭营要求无庇护所', () {
      final provider = EventProvider(events: allEvents);
      final p = Player.defaultPlayer();
      final e = eventById('event_wild_beasts')!;
      expect(provider.canTrigger(e, p, season: 'autumn'), true);
      final sheltered = p.copyWith(
        flags: <String, bool>{...p.flags, 'hasShelter': true},
      );
      expect(provider.canTrigger(e, sheltered, season: 'autumn'), false);
    });

    test('minGold/maxEnergy 触发', () {
      final provider = EventProvider(events: allEvents);
      final e = eventById('event_road_bandits')!;
      final poor = Player.defaultPlayer().copyWith(gold: 5);
      expect(provider.canTrigger(e, poor), false);
      final rich = Player.defaultPlayer().copyWith(gold: 50);
      expect(provider.canTrigger(e, rich), true);

      final ghost = eventById('event_ghost_road')!;
      final energetic = Player.defaultPlayer();
      expect(provider.canTrigger(ghost, energetic, season: 'winter'), false);
      final tired = Player.defaultPlayer().copyWith(energy: 10);
      expect(provider.canTrigger(ghost, tired, season: 'winter'), true);
    });

    test('hasItem 触发：玻璃蜡烛事件需持有蜡烛', () {
      final provider = EventProvider(events: allEvents);
      final p = Player.defaultPlayer();
      final e = eventById('event_glass_candle')!;
      expect(provider.canTrigger(e, p), false);
      final holder = p.copyWith(inventory: <String>['item_glass_candle']);
      expect(provider.canTrigger(e, holder), true);
    });
  });

  group('Batch 10-2 事件选项生存轴要求', () {
    test('选项要求物品：煎服草药需持有草药', () {
      final provider = EventProvider(events: allEvents);
      final winterEvent = eventById('event_winter_sickness')!;
      final herbChoice = winterEvent.choices
          .firstWhere((c) => c.id == 'choice_herbal_remedy');
      final p = Player.defaultPlayer();
      expect(provider.canChoose(herbChoice, p), false);
      final herbalist = p.copyWith(inventory: <String>['item_herb']);
      expect(provider.canChoose(herbChoice, herbalist), true);
    });

    test('选项要求精力：打捞货物需精力 15', () {
      final provider = EventProvider(events: allEvents);
      final wreck = eventById('event_ship_wreck')!;
      final salvage = wreck.choices
          .firstWhere((c) => c.id == 'choice_salvage');
      final tired = Player.defaultPlayer().copyWith(energy: 10);
      expect(provider.canChoose(salvage, tired), false);
      final rested = Player.defaultPlayer().copyWith(energy: 50);
      expect(provider.canChoose(salvage, rested), true);
    });
  });

  group('Batch 10-2 EventService 生存轴效果落盘', () {
    test('health/hunger/inventory./flags. 效果正确应用', () {
      const service = EventService();
      final p = Player.defaultPlayer();
      final choice = EventChoice(
        id: 'test_choice',
        text: '测试',
        requirements: const {},
        effects: const <String, int>{
          'health': -20,
          'hunger': 30,
          'inventory.item_bread': 1,
          'flags.hasBlessing': 1,
        },
        narrative: '测试叙事',
      );
      final result = service.applyEffects(p, choice);
      expect(result.newPlayer.health, 80);
      expect(result.newPlayer.hunger, 30);
      expect(
        result.newPlayer.inventory.where((i) => i == 'item_bread').length,
        1,
      );
      expect(result.newPlayer.flags['hasBlessing'], true);
      expect(result.appliedEffects.containsKey('health'), true);
    });

    test('选项要求物品经 EventService 校验', () {
      const service = EventService();
      final winterEvent = eventById('event_winter_sickness')!;
      final herbChoice = winterEvent.choices
          .firstWhere((c) => c.id == 'choice_herbal_remedy');
      final p = Player.defaultPlayer();
      expect(service.canChoose(herbChoice, p), false);
      final herbalist = p.copyWith(inventory: <String>['item_herb']);
      expect(service.canChoose(herbChoice, herbalist), true);
    });

    test('season 触发经 EventService 校验', () {
      const service = EventService();
      final winterEvent = eventById('event_winter_sickness')!;
      final p = Player.defaultPlayer();
      expect(
        service.checkTriggerConditions(
          winterEvent,
          p,
          const <String, String>{'season': 'winter'},
        ),
        true,
      );
      expect(
        service.checkTriggerConditions(
          winterEvent,
          p,
          const <String, String>{'season': 'summer'},
        ),
        false,
      );
    });
  });
}
