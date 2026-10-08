/// 事件服务：事件触发条件检查、效果计算、存档。
library;

import 'dart:math' show max;

import '../data/balance_data.dart';
// Batch 10-91：`applyEffects` 的 `inventory.<id>` 分支要 `itemById` 校验
// 物品 id 是否真实存在（与 `mixin_life.addItem` 的既有校验对齐）。
import '../data/item_data.dart';
// Batch 10-99：`relations.<npcId>` 分支要 `isNpcIdValid` 校验 NPC id。
import '../data/npc_data.dart';
// Batch 10-104：`checkTriggerConditions` 已委托给单一真相判定实现。
import '../core/event_trigger_eval.dart';
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
  ///
  /// 【Batch 10-104】委托给 `core/event_trigger_eval.dart` 单一真相，
  /// 与 `EventProvider.canTrigger` 判定完全一致。本方法此前是 Batch 3
  /// 独立写的第二份实现，与生产通道存在逐分支漂移（season 门槛恒静默
  /// 放行 = fail-open，而生产通道是 fail-closed）。
  /// 现在只有一份实现。
  ///
  /// [context] 是本方法独有的上下文覆盖层（生产无调用方，仅测试用）：
  /// 键命中 `context` 时以 `context` 为准，否则走玩家状态判定。
  /// 季节亦优先取自 `context['season']`（EventService 既有约定：
  /// context 承载外部世界状态，如「当前是冬天」）。
  bool checkTriggerConditions(
    GameEvent event,
    Player player,
    Map<String, String> context,
  ) {
    return eventTriggersSatisfied(
      event,
      player,
      season: context['season'],
      context: context,
    );
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
          // Batch 10-101：补年龄下界护栏，与 `GameStateProvider.applyEffects`
          // 同名分支对齐（那边同批新增 `age` 分支时也带此护栏）。
          // 此前本通道是裸加法，AI/事件写 `age: -99999` 会让年龄变负数：
          // `isElder`（`age >= 55`）与 `minAge`/`maxAge` 门槛、
          // 以及玩家面板「N 岁」展示会全部失真。与 10-95 给
          // `skills./attributes.` 补 `max(0, ...)`、10-90 给好感度
          // 补 `.clamp(-100, 100)` 同型——三处都是「裸加法无边界」。
          newPlayer = newPlayer.copyWith(age: max(0, newPlayer.age + value));
          applied[key] = value;
        default:
          if (key.startsWith('skills.')) {
            final skillName = key.substring(7);
            // Batch 10-92：键名白名单守卫——与 `GameStateProvider.applyEffects`
            // 的同名分支对齐（那边静默跳过，本通道有 `failedEffects`
            // 可报告，故按「失败」语义登记，便于调用方排查）。
            if (!BalanceData.kPlayerSkillKeys.contains(skillName)) {
              failed[key] = value;
            } else {
              final newSkills = Map<String, int>.from(newPlayer.skills);
              // Batch 10-95：`max(0, ...)` 防负等级——与
              // `GameStateProvider.applyEffects` 的同名分支对齐（那边
              // 10-90 已加，本通道一直漏了）。技能是「等级」，负等级在
              // `train` 的门槛判定（`currentLevel < requiredLevel`）与
              // prompt 展示里都无意义，且会让负值继续累积。
              newSkills[skillName] = max(0, (newSkills[skillName] ?? 0) + value);
              newPlayer = newPlayer.copyWith(skills: newSkills);
              applied[key] = value;
            }
          } else if (key.startsWith('attributes.')) {
            final attrName = key.substring(11);
            // Batch 10-92：属性键白名单守卫，同上。
            if (!BalanceData.kPlayerAttributeKeys.contains(attrName)) {
              failed[key] = value;
            } else {
              final newAttrs = Map<String, int>.from(newPlayer.attributes);
              // Batch 10-95：同上，属性键也走 `max(0, ...)`。
              newAttrs[attrName] = max(0, (newAttrs[attrName] ?? 0) + value);
              newPlayer = newPlayer.copyWith(attributes: newAttrs);
              applied[key] = value;
            }
          } else if (key.startsWith('relations.')) {
            final npcId = key.substring(10);
            // Batch 10-99：NPC id 白名单守卫，与
            // `GameStateProvider.applyEffects` 的同名分支对齐（那边先做，
            // 本通道一直漏了——与 10-95/97 修 `max(0, ...)`/flags 同型）。
            // 本通道有 `failedEffects` 语义（金币不足即走这条路），
            // 故不合规键登记进 `failed` 而非静默丢弃。
            if (!isNpcIdValid(npcId)) {
              failed[key] = value;
            } else {
              final newRelations = Map<String, int>.from(newPlayer.relations);
              // Batch 10-90：硬编码的 100 收口 BalanceData.kRelationClamp，
              // 与 GameStateProvider.applyEffects 的同名分支共享同一真相。
              newRelations[npcId] = ((newRelations[npcId] ?? 0) + value).clamp(
                -BalanceData.kRelationClamp,
                BalanceData.kRelationClamp,
              );
              newPlayer = newPlayer.copyWith(relations: newRelations);
              applied[key] = value;
            }
          } else if (key.startsWith('flags.')) {
            final flagName = key.substring(6);
            // Batch 10-97：状态标记键分层白名单守卫，与
            // `GameStateProvider.applyEffects` 的同名分支对齐（那边已加，
            // 本通道一直漏了——与 10-95 修 `max(0, ...)` 同型）。
            // 静态键集 26 个 + 5 个受限动态前缀（装备槽位/已故子女/
            // 已接·已完成任务/已触发人物故事），其余拒收。
            // 本通道有 `failedEffects` 语义（金币不足即走这条路），
            // 故不合规键登记进 `failed` 而非静默丢弃。
            if (!BalanceData.isPlayerFlagKeyValid(flagName)) {
              failed[key] = value;
            } else {
              final newFlags = Map<String, bool>.from(newPlayer.flags);
              newFlags[flagName] = value != 0;
              newPlayer = newPlayer.copyWith(flags: newFlags);
              applied[key] = value;
            }
          } else if (key.startsWith('inventory.')) {
            final itemId = key.substring(10);
            // Batch 10-91：物品 id 白名单守卫——`itemById(id) == null` 即拒绝。
            // 与 `mixin_life.addItem` 的既有校验、以及
            // `GameStateProvider.applyEffects` 的同名分支三方对齐。
            // 幽灵物品键会让背包段（10-87）白占预算位，存档与物品面板
            // 积累永远无法使用的无效条目。
            if (itemById(itemId) == null) {
              failed[key] = value;
            } else {
              final newInv = List<String>.from(newPlayer.inventory);
              if (value > 0) {
                for (var i = 0; i < value; i++) {
                  newInv.add(itemId);
                }
              } else {
                var toRemove = -value;
                while (toRemove > 0) {
                  final idx = newInv.indexOf(itemId);
                  if (idx < 0) break;
                  newInv.removeAt(idx);
                  toRemove--;
                }
              }
              newPlayer = newPlayer.copyWith(inventory: newInv);
              applied[key] = value;
            }
          } else if (key == 'health') {
            // S13-9：与 `GameStateProvider.applyEffects` 的同名分支对齐——
            // 健康归零即判死（`mixin_life.adjustHealth` 一直是这个语义，
            // 而 `_checkGameOver` 只读 `flags['isAlive']`）。
            final newHealth = (newPlayer.health + value).clamp(0, 100);
            newPlayer = newPlayer.copyWith(health: newHealth);
            if (newHealth <= 0 && (newPlayer.flags['isAlive'] ?? true)) {
              newPlayer = newPlayer.copyWith(
                flags: <String, bool>{...newPlayer.flags, 'isAlive': false},
              );
            }
            applied[key] = value;
          } else if (key == 'energy') {
            newPlayer = newPlayer.copyWith(
              energy: (newPlayer.energy + value).clamp(0, 100),
            );
            applied[key] = value;
          } else if (key == 'hunger') {
            newPlayer = newPlayer.copyWith(
              hunger: (newPlayer.hunger + value).clamp(0, 100),
            );
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
        case 'health':
          if (player.health < value) return false;
        case 'energy':
          if (player.energy < value) return false;
        case 'hunger':
          if (player.hunger < value) return false;
        default:
          if (key.startsWith('skills.')) {
            final skillName = key.substring(7);
            final currentLevel = player.skills[skillName] ?? 0;
            if (currentLevel < value) return false;
          } else if (key.startsWith('attributes.')) {
            final attrName = key.substring(11);
            final currentValue = player.attributes[attrName] ?? 0;
            if (currentValue < value) return false;
          } else if (key.startsWith('hasItem.')) {
            final itemId = key.substring(8);
            final haveCount = player.inventory.where((i) => i == itemId).length;
            if (haveCount < value) return false;
          } else if (key == 'flag') {
            if (!(player.flags[value] ?? false)) return false;
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