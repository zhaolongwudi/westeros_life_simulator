/// Batch 10-10 测试：事件库二轮扩充（60 → 72）。
///
/// 覆盖：
/// 1. 数据完整性：12 个新复合事件全部存在，ID 唯一，字段非空
/// 2. 触发条件：装备/头衔/贸易联动的 triggerConditions 键受支持且逻辑正确
/// 3. 效果键：全部使用受支持键（gold/reputation/skills./attributes./relations./flags./inventory./health/energy/hunger）
/// 4. 联动验证：flags.equipped 装备键、relations. 关系键、inventory. 物品键可被 EventService 解析
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/event_data.dart';
import 'package:westeros_life_simulator/models/player.dart';
import 'package:westeros_life_simulator/providers/event_provider.dart';

void main() {
  const newEventIds = <String>[
    'event_armor_merchant',
    'event_sword_inheritance',
    'event_tournament_mount',
    'event_septon_armor',
    'event_guild_tooling',
    'event_lord_levies_gear',
    'event_trade_convoy',
    'event_market_cartel',
    'event_trade_fair',
    'event_title_ceremony',
    'event_knight_night_watch',
    'event_maester_commission',
  ];

  group('Batch 10-10 数据完整性', () {
    test('事件库总量为 71（S3-4 删除重复事件）', () {
      expect(allEvents.length, 71);
    });

    test('12 个新复合事件全部存在', () {
      for (final id in newEventIds) {
        final e = eventById(id);
        expect(e, isNotNull, reason: '缺少新事件 $id');
        expect(e!.name.isNotEmpty, true);
        expect(e.description.isNotEmpty, true);
        expect(e.narrative.isNotEmpty, true);
        expect(e.choices.length, greaterThanOrEqualTo(2));
        expect(e.tags.isNotEmpty, true);
      }
    });

    test('新事件 ID 与既有事件不冲突', () {
      final allIds = allEvents.map((e) => e.id).toSet();
      expect(allIds.length, allEvents.length);
    });

    test('新事件效果键全部为受支持键', () {
      const supportedPrefixes = <String>[
        'gold', 'reputation', 'health', 'energy', 'hunger',
        'skills.', 'attributes.', 'relations.', 'flags.', 'inventory.',
      ];
      for (final id in newEventIds) {
        final e = eventById(id)!;
        for (final c in e.choices) {
          for (final key in c.effects.keys) {
            final ok = supportedPrefixes.any((p) => key == p || key.startsWith(p));
            expect(ok, true, reason: '事件 $id 选项 ${c.id} 使用了不支持效果键: $key');
          }
        }
      }
    });

    test('新事件触发条件全部为受支持键', () {
      const supportedKeys = <String>[
        'locationId', 'season', 'familyId', 'identity',
        'minAge', 'maxAge', 'minGold', 'minReputation',
        'minHealth', 'maxHealth', 'minEnergy', 'maxEnergy',
        'minHunger', 'maxHunger', 'flag', 'noFlag', 'isAlive',
      ];
      for (final id in newEventIds) {
        final e = eventById(id)!;
        for (final key in e.triggerConditions.keys) {
          final ok = supportedKeys.contains(key) ||
              key.startsWith('hasItem.') ||
              key.startsWith('skills.') ||
              key.startsWith('attributes.');
          expect(ok, true, reason: '事件 $id 使用了不支持触发键: $key');
        }
      }
    });
  });

  group('Batch 10-10 触发条件逻辑', () {
    test('家传之剑需声望 30', () {
      final provider = EventProvider(events: allEvents);
      final e = eventById('event_sword_inheritance')!;
      final lowRep = Player.defaultPlayer().copyWith(reputation: 20);
      expect(provider.canTrigger(e, lowRep), false);
      final highRep = Player.defaultPlayer().copyWith(reputation: 40);
      expect(provider.canTrigger(e, highRep), true);
    });

    test('比武大会坐骑需骑术 3 + 金币 70', () {
      final provider = EventProvider(events: allEvents);
      final e = eventById('event_tournament_mount')!;
      final noRiding = Player.defaultPlayer().copyWith(gold: 100, skills: const {'riding': 2});
      expect(provider.canTrigger(e, noRiding), false);
      final ready = Player.defaultPlayer().copyWith(gold: 100, skills: const {'riding': 3});
      expect(provider.canTrigger(e, ready), true);
    });

    test('圣武士请求需夏天 + 金币 40', () {
      final provider = EventProvider(events: allEvents);
      final e = eventById('event_septon_armor')!;
      final winter = Player.defaultPlayer().copyWith(gold: 100);
      expect(provider.canTrigger(e, winter, season: 'winter'), false);
      expect(provider.canTrigger(e, winter, season: 'summer'), true);
      final poor = Player.defaultPlayer().copyWith(gold: 20);
      expect(provider.canTrigger(e, poor, season: 'summer'), false);
    });

    test('市场垄断需秋天 + 金币 100', () {
      final provider = EventProvider(events: allEvents);
      final e = eventById('event_market_cartel')!;
      final rich = Player.defaultPlayer().copyWith(gold: 150);
      expect(provider.canTrigger(e, rich, season: 'summer'), false);
      expect(provider.canTrigger(e, rich, season: 'autumn'), true);
    });

    test('守夜人邀请仅冬天可触发', () {
      final provider = EventProvider(events: allEvents);
      final e = eventById('event_knight_night_watch')!;
      expect(provider.canTrigger(e, Player.defaultPlayer(), season: 'summer'), false);
      expect(provider.canTrigger(e, Player.defaultPlayer(), season: 'winter'), true);
    });

    test('装备/关系/物品类选项 requirement 生效', () {
      final provider = EventProvider(events: allEvents);
      final e = eventById('event_septon_armor')!;
      final donate = e.choices.firstWhere((c) => c.id == 'choice_donate_armor');
      final withArmor = Player.defaultPlayer().copyWith(inventory: const ['item_leather_armor']);
      expect(provider.canChoose(donate, withArmor), true);
      final withoutArmor = Player.defaultPlayer();
      expect(provider.canChoose(donate, withoutArmor), false);

      final borrow = eventById('event_tournament_mount')!
          .choices
          .firstWhere((c) => c.id == 'choice_borrow');
      final withFavor = Player.defaultPlayer().copyWith(relations: const {'lord': 25});
      expect(provider.canChoose(borrow, withFavor), true);
    });
  });
}
