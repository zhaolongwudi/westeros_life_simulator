/// Batch 10-95/96 效果落盘轴 · 双通道实现漂移治理
///
/// **本批定位**：10-89~94 逐个补「写侧守卫 + 反馈闭环」，但取证发现两套
/// `applyEffects`（`EventService` 事件选项通道 / `GameStateProvider` AI 选项
/// 通道）之间存在**实现漂移**——同一类效果键，两边护栏语义不一致。
/// 本批只做「对齐 + 内容侧清理」，不改效果键契约本身。
///
/// **Batch 10-95（代码对齐，零数据变更）**
/// `event_service.applyEffects` 的 `skills.` / `attributes.` 分支补
/// `max(0, ...)`。Batch 10-90 只在 **provider 侧**加了防负等级护栏，
/// 事件通道一直是裸加法 → 事件可把技能写成负等级，而负等级在 `train`
/// 的门槛判定（`currentLevel < requiredLevel`）与 prompt 展示里都无意义。
/// 零回归依据：`event_data` 的 `skills./attributes.` 效果值**负值 0 处**，
/// `batch3_event_service_test` 对该通道**只测正值**。
///
/// **Batch 10-96（内容侧幽灵键清理）**
/// `event_data.dart` 原有 4 个幽灵 `relations.` 键：`lord`（效果 2 处 +
/// **门槛 2 处**）、`family_head`、`merchant_leader`、`castle_black`，
/// 均非真实 npc id（`npc_data` 全量 38 个 id 全带 `npc_` 前缀）。
/// 后果：① 玩家点了「+10 好感」永远加不到任何人身上；② prompt 关系段的
/// `n == null` 兜底把 `lord: 10` 原样打进 prompt，玩家面板遍历
/// `relations.entries` 会出现名为 `lord` 的条目；③ 两处 `relations.lord`
/// 门槛是**死配置**——`EventService.canChoose` 的 `default` 分支根本不
/// 处理 `relations.`，故恒静默放行。四键均为泛化角色概念（领主/家主/商队
/// 首领/守夜人），无唯一对应 NPC，强行映射会让该 NPC 关系值被无关事件
/// 污染，故按「幽灵键不落盘」删除；每个选项同行的 `reputation` 本就承载
/// 叙事褒奖，删除不改语义。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/balance_data.dart';
import 'package:westeros_life_simulator/data/event_data.dart';
import 'package:westeros_life_simulator/data/item_data.dart';
import 'package:westeros_life_simulator/data/npc_data.dart';
import 'package:westeros_life_simulator/models/event.dart';
import 'package:westeros_life_simulator/models/player.dart';
import 'package:westeros_life_simulator/services/event_service.dart';

void main() {
  const service = EventService();

  EventChoice choice(Map<String, int> effects) => EventChoice(
        id: 'c1',
        text: '测试',
        requirements: const {},
        effects: effects,
        narrative: '测试',
      );

  // ==================== Batch 10-95 ====================

  group('10-95 event_service skills/attributes 负值护栏', () {
    test('skills 负 delta 不把等级压到 0 以下', () {
      final player = Player.defaultPlayer();
      expect(player.skills['sword']! > 0, isTrue,
          reason: '前提：默认剑术为正，负 delta 才真正跌破 0');
      final r = service.applyEffects(player, choice({'skills.sword': -999}));
      expect(r.newPlayer.skills['sword'], 0);
    });

    test('attributes 负 delta 不把数值压到 0 以下', () {
      final player = Player.defaultPlayer();
      final r =
          service.applyEffects(player, choice({'attributes.strength': -999}));
      expect(r.newPlayer.attributes['strength'], 0);
    });

    test('负 delta 破底时仍算「已应用」（与 provider 侧语义一致）', () {
      final player = Player.defaultPlayer();
      final r = service.applyEffects(player, choice({'skills.sword': -999}));
      expect(r.appliedEffects.containsKey('skills.sword'), isTrue);
      expect(r.failedEffects.containsKey('skills.sword'), isFalse);
    });

    test('正值行为不变（既有契约不回归）', () {
      final player = Player.defaultPlayer();
      final base = player.skills['sword']!;
      final r = service.applyEffects(player, choice({'skills.sword': 2}));
      expect(r.newPlayer.skills['sword'], base + 2);
    });

    test('恰好归零仍照常落盘（边界是「钳到 0」而非「拒绝」）', () {
      final player = Player.defaultPlayer();
      final base = player.skills['sword']!;
      final r = service.applyEffects(player, choice({'skills.sword': -base}));
      expect(r.newPlayer.skills['sword'], 0);
    });

    test('attributes 正值行为不变', () {
      final player = Player.defaultPlayer();
      final base = player.attributes['strength']!;
      final r =
          service.applyEffects(player, choice({'attributes.strength': 1}));
      expect(r.newPlayer.attributes['strength'], base + 1);
    });
  });

  group('10-95 护栏常量单一真相', () {
    test('好感度护栏边界仍是 10-90 的 100', () {
      expect(BalanceData.kRelationClamp, 100);
    });
  });

  // ==================== Batch 10-96 ====================

  group('10-96 内容侧 relations 键零幽灵', () {
    test('全部事件的 relations. 效果键都命中真实 npc id', () {
      final ids = allNpcs.map((n) => n.id).toSet();
      final ghost = <String>[];
      for (final e in allEvents) {
        for (final c in e.choices) {
          for (final k in c.effects.keys) {
            if (!k.startsWith('relations.')) continue;
            if (!ids.contains(k.substring(10))) ghost.add('${e.id}/$k');
          }
        }
      }
      expect(ghost, isEmpty,
          reason: '幽灵关系键让「+10 好感」永远落空，并泄漏原始键名进 prompt/UI');
    });

    test('全部事件的 relations. 门槛键都命中真实 npc id', () {
      final ids = allNpcs.map((n) => n.id).toSet();
      final ghost = <String>[];
      for (final e in allEvents) {
        for (final c in e.choices) {
          for (final k in c.requirements.keys) {
            if (!k.startsWith('relations.')) continue;
            if (!ids.contains(k.substring(10))) ghost.add('${e.id}/$k');
          }
        }
      }
      expect(ghost, isEmpty,
          reason: 'canChoose 的 default 分支不处理 relations.，此类门槛恒静默放行');
    });

    test('4 个幽灵键已从内容库彻底移除', () {
      final all = <String>[];
      for (final e in allEvents) {
        for (final c in e.choices) {
          all
            ..addAll(c.effects.keys)
            ..addAll(c.requirements.keys);
        }
      }
      for (final ghost in const [
        'relations.lord',
        'relations.family_head',
        'relations.merchant_leader',
        'relations.castle_black',
      ]) {
        expect(all.contains(ghost), isFalse, reason: '$ghost 应已删除');
      }
    });

    test('删除效果键后对应选项仍保有叙事褒奖', () {
      final e = allEvents.firstWhere((x) => x.name == '家传之剑');
      final c = e.choices.firstWhere((x) => x.id == 'choice_entrust');
      expect(c.effects['reputation'], 8);
      expect(c.effects.keys.any((k) => k.startsWith('relations.')), isFalse);
    });

    test('删除门槛后选项变为无条件可选', () {
      final e = allEvents.firstWhere((x) => x.name == '比武大会的坐骑');
      final c = e.choices.firstWhere((x) => x.id == 'choice_borrow');
      expect(c.requirements, isEmpty);
      expect(service.canChoose(c, Player.defaultPlayer()), isTrue);
    });

    test('守夜人选项删键后 flags 效果仍在（不误伤同选项其他效果）', () {
      final e = allEvents.firstWhere((x) => x.name == '守夜人的邀请');
      final c = e.choices.firstWhere((x) => x.id == 'choice_join_watch');
      expect(c.effects['flags.sworn_brother'], 1);
      expect(c.effects['reputation'], 10);
    });
  });

  group('10-96 既有全库效果键契约零回归', () {
    test('全量事件 skills. 键都在白名单内', () {
      final ghost = <String>[];
      for (final e in allEvents) {
        for (final c in e.choices) {
          for (final k in c.effects.keys) {
            if (!k.startsWith('skills.')) continue;
            if (!BalanceData.kPlayerSkillKeys.contains(k.substring(7))) {
              ghost.add('${e.id}/$k');
            }
          }
        }
      }
      expect(ghost, isEmpty);
    });

    test('全量事件 attributes. 键都在白名单内', () {
      final ghost = <String>[];
      for (final e in allEvents) {
        for (final c in e.choices) {
          for (final k in c.effects.keys) {
            if (!k.startsWith('attributes.')) continue;
            if (!BalanceData.kPlayerAttributeKeys.contains(k.substring(11))) {
              ghost.add('${e.id}/$k');
            }
          }
        }
      }
      expect(ghost, isEmpty);
    });

    test('全量事件 inventory. 键都命中真实物品 id', () {
      final ghost = <String>[];
      for (final e in allEvents) {
        for (final c in e.choices) {
          for (final k in c.effects.keys) {
            if (!k.startsWith('inventory.')) continue;
            if (itemById(k.substring(10)) == null) ghost.add('${e.id}/$k');
          }
        }
      }
      expect(ghost, isEmpty);
    });

    test('全量事件每条至少一个无条件选项（不因删门槛而卡死）', () {
      final dead = <String>[];
      for (final e in allEvents) {
        if (!e.choices.any((c) => c.requirements.isEmpty)) dead.add(e.id);
      }
      expect(dead, isEmpty);
    });

    test('事件库总量仍是 72（未误删事件）', () {
      expect(allEvents.length, 72);
    });
  });
}