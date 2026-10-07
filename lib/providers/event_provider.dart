/// 事件管理：事件触发逻辑、选项处理、效果应用。
library;

import 'package:flutter/foundation.dart';

import '../core/event_trigger_eval.dart';
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
  /// [season] 可选：当前季节（如 'winter'），用于支持季节触发条件。
  ///
  /// 【Batch 10-104】门槛判定已抽到 `core/event_trigger_eval.dart`
  /// 单一真相，本方法只保留「一次性事件是否已完成」这一条 provider
  /// 私有状态校验。与 `EventService.checkTriggerConditions` 共用同一
  /// 判定实现，杜绝第五次双通道漂移（见该文件头的前四次事故记录）。
  bool canTrigger(GameEvent event, Player player, {String? season}) {
    // 检查一次性事件是否已完成
    if (event.isOneTime && _completedEventIds.contains(event.id)) {
      return false;
    }
    return eventTriggersSatisfied(event, player, season: season);
  }

  /// 获取可触发事件列表。[season] 可选，用于季节触发条件。
  List<GameEvent> getAvailableEvents(Player player, {String? season}) {
    return _allEvents.where((e) => canTrigger(e, player, season: season)).toList();
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

  /// S8-1：整体替换完成集合（读档时由 `GameProviderBase.applyState` 调用）。
  ///
  /// 【为什么是替换而不是合并】读档是全量覆盖语义；合并会让"读档失败"
  /// 退化成"读到一半"。【为什么这里不 `notifyListeners`】它在读档路径上被
  /// 调用，而 `applyState` 紧接着就会通知一次；本 provider 无 UI 监听者。
  void restoreCompleted(List<String> eventIds) {
    _completedEventIds = List<String>.from(eventIds);
  }

  /// 检查选项是否可用。
  bool canChoose(EventChoice choice, Player player) {
    for (final entry in choice.requirements.entries) {
      final key = entry.key;
      final value = entry.value;

      if (key == 'gold' && player.gold < value) return false;
      if (key == 'reputation' && player.reputation < value) return false;
      if (key == 'health' && player.health < value) return false;
      if (key == 'energy' && player.energy < value) return false;
      if (key == 'hunger' && player.hunger < value) return false;
      if (key.startsWith('hasItem.')) {
        final itemId = key.substring(8);
        final haveCount = player.inventory.where((i) => i == itemId).length;
        if (haveCount < value) return false;
      }
      if (key == 'flag' && !(player.flags[value] ?? false)) {
        return false;
      }
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