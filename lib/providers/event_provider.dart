/// 事件管理：事件触发逻辑、选项处理、效果应用。
library;

import 'package:flutter/foundation.dart';

import '../models/event.dart';
import '../models/player.dart';

/// 事件管理。
class EventProvider extends ChangeNotifier {
  EventProvider({List<GameEvent>? events})
      : _allEvents = events ?? const <GameEvent>[];

  List<GameEvent> _allEvents;
  List<GameEvent> _triggeredEvents = <GameEvent>[];
  List<String> _completedEventIds = <String>[];

  /// 所有事件。
  List<GameEvent> get allEvents => List.unmodifiable(_allEvents);

  /// 已触发事件。
  List<GameEvent> get triggeredEvents => List.unmodifiable(_triggeredEvents);

  /// 已完成事件 ID。
  List<String> get completedEventIds => List.unmodifiable(_completedEventIds);

  /// 检查事件是否可触发。
  bool canTrigger(GameEvent event, Player player) {
    // 检查一次性事件是否已完成
    if (event.isOneTime && _completedEventIds.contains(event.id)) {
      return false;
    }

    // 检查触发条件
    for (final entry in event.triggerConditions.entries) {
      final key = entry.key;
      final value = entry.value;

      if (key == 'locationId' && player.locationId != value) {
        return false;
      }
      if (key == 'familyId' && player.familyId != value) {
        return false;
      }
      if (key == 'identity' && player.identity.name != value) {
        return false;
      }
      if (key == 'minAge' && player.age < int.parse(value)) {
        return false;
      }
      if (key == 'maxAge' && player.age > int.parse(value)) {
        return false;
      }
      if (key == 'minGold' && player.gold < int.parse(value)) {
        return false;
      }
      if (key == 'minReputation' && player.reputation < int.parse(value)) {
        return false;
      }
      if (key.startsWith('skills.')) {
        final skillName = key.substring(7);
        final requiredLevel = int.parse(value);
        final currentLevel = player.skills[skillName] ?? 0;
        if (currentLevel < requiredLevel) return false;
      }
      if (key.startsWith('attributes.')) {
        final attrName = key.substring(11);
        final requiredValue = int.parse(value);
        final currentValue = player.attributes[attrName] ?? 0;
        if (currentValue < requiredValue) return false;
      }
      if (key == 'isAlive' && value == 'true' && !(player.flags['isAlive'] ?? false)) {
        return false;
      }
    }

    return true;
  }

  /// 获取可触发事件列表。
  List<GameEvent> getAvailableEvents(Player player) {
    return _allEvents.where((e) => canTrigger(e, player)).toList();
  }

  /// 随机触发一个事件。
  GameEvent? triggerRandomEvent(Player player) {
    final available = getAvailableEvents(player);
    if (available.isEmpty) return null;
    final random = available[available.length % 7]; // 简单随机
    _triggeredEvents.add(random);
    notifyListeners();
    return random;
  }

  /// 标记事件完成。
  void markCompleted(String eventId) {
    if (!_completedEventIds.contains(eventId)) {
      _completedEventIds.add(eventId);
      notifyListeners();
    }
  }

  /// 检查选项是否可用。
  bool canChoose(EventChoice choice, Player player) {
    for (final entry in choice.requirements.entries) {
      final key = entry.key;
      final value = entry.value;

      if (key == 'gold' && player.gold < value) return false;
      if (key == 'reputation' && player.reputation < value) return false;
      if (key.startsWith('skills.')) {
        final skillName = key.substring(7);
        final currentLevel = player.skills[skillName] ?? 0;
        if (currentLevel < value) return false;
      }
      if (key.startsWith('attributes.')) {
        final attrName = key.substring(11);
        final currentValue = player.attributes[attrName] ?? 0;
        if (currentValue < value) return false;
      }
    }
    return true;
  }

  /// 获取可用选项列表。
  List<EventChoice> getAvailableChoices(GameEvent event, Player player) {
    return event.choices.where((c) => canChoose(c, player)).toList();
  }

  /// 重置事件状态。
  void reset() {
    _triggeredEvents = <GameEvent>[];
    _completedEventIds = <String>[];
    notifyListeners();
  }
}