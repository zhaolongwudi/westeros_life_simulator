/// Batch 1 冒烟测试：验证模型层基础功能。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/models/event.dart';
import 'package:westeros_life_simulator/models/family.dart';
import 'package:westeros_life_simulator/models/location.dart';
import 'package:westeros_life_simulator/models/npc.dart';
import 'package:westeros_life_simulator/models/player.dart';

void main() {
  group('Player 模型', () {
    test('defaultPlayer 创建成功', () {
      final player = Player.defaultPlayer();
      expect(player.id, 'player_default');
      expect(player.name, '无名者');
      expect(player.identity, PlayerIdentity.noble);
      expect(player.familyId, 'family_stark');
      expect(player.age, 18);
      expect(player.gold, 100);
      expect(player.reputation, 50);
      expect(player.flags['isAlive'], true);
    });

    test('copyWith 更新字段', () {
      final player = Player.defaultPlayer();
      final updated = player.copyWith(gold: 200, age: 19);
      expect(updated.gold, 200);
      expect(updated.age, 19);
      expect(updated.name, player.name); // 未变字段保持
    });

    test('toJson/fromJson 往返一致', () {
      final player = Player.defaultPlayer();
      final json = player.toJson();
      final restored = Player.fromJson(json);
      expect(restored.id, player.id);
      expect(restored.name, player.name);
      expect(restored.identity, player.identity);
      expect(restored.gold, player.gold);
      expect(restored.skills, player.skills);
      expect(restored.attributes, player.attributes);
    });
  });

  group('Family 模型', () {
    test('defaultFamily 创建成功', () {
      final family = Family.defaultFamily();
      expect(family.id, 'family_stark');
      expect(family.name, '史塔克');
      expect(family.motto, '凛冬将至');
      expect(family.scale, FamilyScale.great);
      expect(family.population, 5000);
      expect(family.army, 1000);
      expect(family.influence, 70);
    });

    test('toJson/fromJson 往返一致', () {
      final family = Family.defaultFamily();
      final json = family.toJson();
      final restored = Family.fromJson(json);
      expect(restored.id, family.id);
      expect(restored.name, family.name);
      expect(restored.scale, family.scale);
      expect(restored.relations, family.relations);
      expect(restored.traits, family.traits);
    });
  });

  group('Npc 模型', () {
    test('defaultNpc 创建成功', () {
      final npc = Npc.defaultNpc();
      expect(npc.id, 'npc_nev');
      expect(npc.name, '奈德·史塔克');
      expect(npc.type, NpcType.noble);
      expect(npc.age, 42);
      expect(npc.faith, '旧神');
      expect(npc.isAlive, true);
    });

    test('copyWith 更新 isAlive', () {
      final npc = Npc.defaultNpc();
      final dead = npc.copyWith(isAlive: false);
      expect(dead.isAlive, false);
      expect(dead.name, npc.name);
    });

    test('toJson/fromJson 往返一致', () {
      final npc = Npc.defaultNpc();
      final json = npc.toJson();
      final restored = Npc.fromJson(json);
      expect(restored.id, npc.id);
      expect(restored.type, npc.type);
      expect(restored.personality, npc.personality);
      expect(restored.skills, npc.skills);
    });
  });

  group('Location 模型', () {
    test('defaultLocation 创建成功', () {
      final location = Location.defaultLocation();
      expect(location.id, 'location_winterfell');
      expect(location.name, '临冬城');
      expect(location.type, LocationType.castle);
      expect(location.region, '北境');
      expect(location.dangerLevel, 3);
      expect(location.population, 2000);
    });

    test('toJson/fromJson 往返一致', () {
      final location = Location.defaultLocation();
      final json = location.toJson();
      final restored = Location.fromJson(json);
      expect(restored.id, location.id);
      expect(restored.type, location.type);
      expect(restored.features, location.features);
      expect(restored.connectedTo, location.connectedTo);
    });
  });

  group('GameEvent 模型', () {
    test('defaultEvent 创建成功', () {
      final event = GameEvent.defaultEvent();
      expect(event.id, 'event_winter_comes');
      expect(event.name, '凛冬将至');
      expect(event.type, EventType.daily);
      expect(event.choices.length, 2);
      expect(event.isOneTime, false);
    });

    test('EventChoice toJson/fromJson 往返一致', () {
      final event = GameEvent.defaultEvent();
      final choice = event.choices.first;
      final json = choice.toJson();
      final restored = EventChoice.fromJson(json);
      expect(restored.id, choice.id);
      expect(restored.text, choice.text);
      expect(restored.requirements, choice.requirements);
      expect(restored.effects, choice.effects);
    });

    test('GameEvent toJson/fromJson 往返一致', () {
      final event = GameEvent.defaultEvent();
      final json = event.toJson();
      final restored = GameEvent.fromJson(json);
      expect(restored.id, event.id);
      expect(restored.type, event.type);
      expect(restored.choices.length, event.choices.length);
      expect(restored.tags, event.tags);
    });
  });

  group('枚举完整性', () {
    test('PlayerIdentity 包含所有身份', () {
      expect(PlayerIdentity.values.length, 10);
      expect(PlayerIdentity.values, contains(PlayerIdentity.noble));
      expect(PlayerIdentity.values, contains(PlayerIdentity.assassin));
      expect(PlayerIdentity.values, contains(PlayerIdentity.wildling));
    });

    test('EventType 包含所有事件类型', () {
      expect(EventType.values.length, 9);
      expect(EventType.values, contains(EventType.political));
      expect(EventType.values, contains(EventType.supernatural));
    });

    test('LocationType 包含所有地点类型', () {
      expect(LocationType.values.length, 11);
      expect(LocationType.values, contains(LocationType.castle));
      expect(LocationType.values, contains(LocationType.supernatural));
    });
  });
}