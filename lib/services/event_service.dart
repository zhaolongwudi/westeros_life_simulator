/// 事件服务：事件触发条件检查、效果计算、存档。
library;

import '../models/event.dart';
import '../models/player.dart';

/// 事件效果应用结果。
class EventEffectResult {
  const EventEffectResult({
    required this.newPlayer,
    required this.appliedEffects,
    required this.failedEffects,
  });

  /// 应用效果后的玩家。
  final Player newPlayer;

  /// 成功应用的效果。
  final Map<String, int> appliedEffects;

  /// 失败的效果（如金币不足）。
  final Map<String, int> failedEffects;
}

/// 事件服务。
class EventService {
  const EventService();

  /// 检查事件触发条件。
  bool checkTriggerConditions(
    GameEvent event,
    Player player,
    Map<String, String> context,
  ) {
    for (final entry in event.triggerConditions.entries) {
      final key = entry.key;
      final value = entry.value;

      // 从上下文检查
      if (context.containsKey(key)) {
        if (context[key] != value) return false;
        continue;
      }

      // 从玩家检查
      switch (key) {
        case 'locationId':
          if (player.locationId != value) return false;
        case 'familyId':
          if (player.familyId != value) return false;
        case 'identity':
          if (player.identity.name != value) return false;
        case 'minAge':
          if (player.age < int.parse(value)) return false;
        case 'maxAge':
          if (player.age > int.parse(value)) return false;
        case 'minGold':
          if (player.gold < int.parse(value)) return false;
        case 'minReputation':
          if (player.reputation < int.parse(value)) return false;
        case 'isAlive':
          if (value == 'true' && !(player.flags['isAlive'] ?? false)) {
            return false;
          }
        default:
          if (key.startsWith('skills.')) {
            final skillName = key.substring(7);
            final requiredLevel = int.parse(value);
            final currentLevel = player.skills[skillName] ?? 0;
            if (currentLevel < requiredLevel) return false;
          } else if (key.startsWith('attributes.')) {
            final attrName = key.substring(11);
            final requiredValue = int.parse(value);
            final currentValue = player.attributes[attrName] ?? 0;
            if (currentValue < requiredValue) return false;
          }
      }
    }
    return true;
  }

  /// 应用事件效果。
  EventEffectResult applyEffects(Player player, EventChoice choice) {
    var newPlayer = player;
    final applied = <String, int>{};
    final failed = <String, int>{};

    for (final entry in choice.effects.entries) {
      final key = entry.key;
      final value = entry.value;

      switch (key) {
        case 'gold':
          if (value < 0 && player.gold < -value) {
            failed[key] = value;
          } else {
            newPlayer = newPlayer.copyWith(gold: newPlayer.gold + value);
            applied[key] = value;
          }
        case 'reputation':
          newPlayer = newPlayer.copyWith(
            reputation: (newPlayer.reputation + value).clamp(0, 100),
          );
          applied[key] = value;
        case 'age':
          newPlayer = newPlayer.copyWith(age: newPlayer.age + value);
          applied[key] = value;
        default:
          if (key.startsWith('skills.')) {
            final skillName = key.substring(7);
            final newSkills = Map<String, int>.from(newPlayer.skills);
            newSkills[skillName] = (newSkills[skillName] ?? 0) + value;
            newPlayer = newPlayer.copyWith(skills: newSkills);
            applied[key] = value;
          } else if (key.startsWith('attributes.')) {
            final attrName = key.substring(11);
            final newAttrs = Map<String, int>.from(newPlayer.attributes);
            newAttrs[attrName] = (newAttrs[attrName] ?? 0) + value;
            newPlayer = newPlayer.copyWith(attributes: newAttrs);
            applied[key] = value;
          } else if (key.startsWith('relations.')) {
            final npcId = key.substring(10);
            final newRelations = Map<String, int>.from(newPlayer.relations);
            newRelations[npcId] =
                ((newRelations[npcId] ?? 0) + value).clamp(-100, 100);
            newPlayer = newPlayer.copyWith(relations: newRelations);
            applied[key] = value;
          } else if (key.startsWith('flags.')) {
            final flagName = key.substring(6);
            final newFlags = Map<String, bool>.from(newPlayer.flags);
            newFlags[flagName] = value != 0;
            newPlayer = newPlayer.copyWith(flags: newFlags);
            applied[key] = value;
          } else {
            failed[key] = value;
          }
      }
    }

    return EventEffectResult(
      newPlayer: newPlayer,
      appliedEffects: applied,
      failedEffects: failed,
    );
  }

  /// 检查选项是否可用。
  bool canChoose(EventChoice choice, Player player) {
    for (final entry in choice.requirements.entries) {
      final key = entry.key;
      final value = entry.value;

      switch (key) {
        case 'gold':
          if (player.gold < value) return false;
        case 'reputation':
          if (player.reputation < value) return false;
        default:
          if (key.startsWith('skills.')) {
            final skillName = key.substring(7);
            final currentLevel = player.skills[skillName] ?? 0;
            if (currentLevel < value) return false;
          } else if (key.startsWith('attributes.')) {
            final attrName = key.substring(11);
            final currentValue = player.attributes[attrName] ?? 0;
            if (currentValue < value) return false;
          }
      }
    }
    return true;
  }

  /// 获取事件标签。
  List<String> getEventTags(GameEvent event) {
    return List.unmodifiable(event.tags);
  }

  /// 按标签筛选事件。
  List<GameEvent> filterByTags(List<GameEvent> events, List<String> tags) {
    return events
        .where((e) => e.tags.any(tags.contains))
        .toList();
  }

  /// 按类型筛选事件。
  List<GameEvent> filterByType(List<GameEvent> events, EventType type) {
    return events.where((e) => e.type == type).toList();
  }
}