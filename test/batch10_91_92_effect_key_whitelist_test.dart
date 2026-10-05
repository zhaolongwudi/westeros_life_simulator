/// Batch 10-91/92 测试：效果落盘轴的键名白名单守卫。
///
/// 【10-91 取证：`inventory.<id>` 是三条写入通道里唯一不校验的一条】
/// 物品 id 校验历史上只有 `mixin_life.addItem` 做了
/// （`if (item == null) return false;`），而**两条 applyEffects 通道
/// （`event_service` 事件选项 + `GameStateProvider` AI 选项）都不校验**：
/// AI 写 `inventory.dragon_scale: 3` 就会往背包塞三条永不存在的物品。
/// 后果：
///   1. 背包段（10-87）把未知 id 直接打出来，**白占 8 个预算位**；
///   2. 存档与物品面板积累永远无法使用/显示的无效条目；
///   3. 玩家消耗它时 `useItem` 走 `itemById == null` 返回
///      「没有「xxx」这种东西。」——叙事与状态彻底脱节。
///
/// 【10-92 取证：`skills.`/`attributes.` 同样不校验键名】
/// 与 10-89 的幽灵关系键同构：`labels.skillLabel` / `attributeLabel`
/// 的未知键兜底是 `_ => key`（原样返回），于是 AI 自造的键名
/// （`skills.leadership` NPC 侧键位、或 `skills.剑术` 中文翻译）
/// 会**原样泄漏进技能/属性面板 UI**；且 `mixin_play.train` 的
/// 「你从未学过 X」判定以 `skills.containsKey` 为准，幽灵键让 AI
/// 能「教会」玩家一个本不存在的技能。
///
/// 【本批修法】
///  - 纯写侧守卫：`inventory.<id>` 走 `itemById(id) == null` 即拒绝
///    （与 `mixin_life.addItem` 的既有校验对齐）；`skills.`/`attributes.`
///    走 `BalanceData.kPlayerSkillKeys` / `kPlayerAttributeKeys` 白名单。
///  - 键集来源：技能/属性白名单直接取 `labels` 的标签表分支
///    （单一真相），因此本批附带源码级护栏断言两张表与白名单
///    **永远同步**，杜绝「加了标签忘了加白名单」。
///
/// 【刻意不改 prompt 侧——与 10-87 的既定决策保持一致】
/// 10-87 已明确把背包段从「裸英文 id」改为「中文名 + 数量」并断言
/// `isNot(contains('item_bread'))`（英文 id 不再泄漏进 prompt）。本批
/// 一度想仿 10-89 给背包段补 `[id=...]`，**自查后撤回**：那会给一个
/// 已被显式优化过的段加回英文 id，与「减 token」方向相反，且要改 3 条
/// 既有断言。故 10-91 只做写侧守卫。代价是 AI 拿不到真实物品 id 时
/// 仍可能写出幽灵键——但那些键现在会被写侧拒绝并（event_service 通道）
/// 登记进 `failedEffects`，不再污染存档/UI，这正是本批的目标。
///
/// 【两条通道的失败语义不同，是刻意的】
///  - `GameStateProvider.applyEffects`：不落盘，Batch 10-94 起登记进
///    `lastRejectedEffectKeys` 供 UI 侧提示（本通道无返回值可承载报告，
///    加字段是纯增量、不破坏既有签名）；
///  - `event_service.applyEffects`：登记进 `failed`——它本来就有这个
///    通道（金币不足就走这条路），调用方可据此排查。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/balance_data.dart';
import 'package:westeros_life_simulator/data/event_data.dart';
import 'package:westeros_life_simulator/data/item_data.dart';
import 'package:westeros_life_simulator/models/event.dart';
import 'package:westeros_life_simulator/models/player.dart';
import 'package:westeros_life_simulator/providers/game_state_provider.dart';
import 'package:westeros_life_simulator/services/event_service.dart';
import 'package:westeros_life_simulator/utils/labels.dart';

/// 造一个只含单个效果键的选项（provider 侧用裸 Map，service 侧用 EventChoice）。
EventChoice _choice(String key, int value) => EventChoice(
      id: 'choice_test',
      text: '测试选项',
      requirements: const <String, int>{},
      effects: <String, int>{key: value},
      narrative: '',
    );

/// 剥掉整行注释（源码级护栏用，避免命中自己写的说明文字——坑 52）。
String _stripLineComments(String source) => source
    .split('\n')
    .where((l) => !RegExp(r'^\s*//').hasMatch(l))
    .join('\n');

void main() {
  group('Batch 10-91 inventory.<id> 白名单守卫', () {
    test('provider 侧：未知物品 id 不落盘（幽灵物品被拒）', () {
      final provider = GameStateProvider();
      final player = provider.applyEffects(
        provider.player,
        const <String, int>{'inventory.item_dragon_scale': 3},
      );
      expect(player.inventory, isEmpty);
    });

    test('provider 侧：真实物品 id 正常落盘（数量正确）', () {
      final provider = GameStateProvider();
      final player = provider.applyEffects(
        provider.player,
        const <String, int>{'inventory.item_bread': 2},
      );
      expect(player.inventory.where((i) => i == 'item_bread').length, 2);
    });

    test('provider 侧：合法键与幽灵键混合时，幽灵键被单独丢弃', () {
      final provider = GameStateProvider();
      final player = provider.applyEffects(
        provider.player,
        const <String, int>{
          'inventory.item_bread': 1,
          'inventory.fake_thing': 5,
        },
      );
      expect(player.inventory, <String>['item_bread']);
    });

    test('provider 侧：未知物品的「消耗」也无副作用（不误删真实物品）', () {
      final provider = GameStateProvider();
      final seeded = provider.player.copyWith(inventory: const ['item_bread']);
      final player = provider.applyEffects(
        seeded,
        const <String, int>{'inventory.fake_thing': -2},
      );
      expect(player.inventory, <String>['item_bread']);
    });

    test('event_service 侧：未知物品 id 进 failedEffects 且不落盘', () {
      final res = const EventService().applyEffects(
        Player.defaultPlayer(),
        _choice('inventory.item_dragon_scale', 3),
      );
      expect(res.newPlayer.inventory, isEmpty);
      expect(res.failedEffects['inventory.item_dragon_scale'], 3);
      expect(res.appliedEffects.containsKey('inventory.item_dragon_scale'), isFalse);
    });

    test('event_service 侧：真实物品 id 正常落盘且登记 applied', () {
      final res = const EventService().applyEffects(
        Player.defaultPlayer(),
        _choice('inventory.item_bread', 2),
      );
      expect(res.newPlayer.inventory.where((i) => i == 'item_bread').length, 2);
      expect(res.appliedEffects['inventory.item_bread'], 2);
      expect(res.failedEffects, isEmpty);
    });

    test('两条通道对未知物品 id 的判定一致（都不落盘）', () {
      final provider = GameStateProvider();
      final provPlayer = provider.applyEffects(
        provider.player,
        const <String, int>{'inventory.item_dragon_scale': 1},
      );
      final res = const EventService().applyEffects(
        Player.defaultPlayer(),
        _choice('inventory.item_dragon_scale', 1),
      );
      expect(provPlayer.inventory.length, res.newPlayer.inventory.length);
    });

    test('全量内容事件零回归：所有 inventory.<id> 键都是真实物品 id', () {
      // 这是本批最重要的护栏——白名单一旦漏掉某个真实物品，
      // 该事件的效果就会静默失效（玩家点选项什么也没发生）。
      for (final event in allEvents) {
        for (final choice in event.choices) {
          for (final key in choice.effects.keys) {
            if (!key.startsWith('inventory.')) continue;
            final itemId = key.substring(10);
            expect(
              itemById(itemId),
              isNotNull,
              reason: '事件「${event.name}」的选项引用了不存在的物品 $itemId',
            );
          }
        }
      }
    });
  });

  group('Batch 10-92 skills./attributes. 键名白名单守卫', () {
    test('provider 侧：未知技能键不落盘', () {
      final provider = GameStateProvider();
      final player = provider.applyEffects(
        provider.player,
        const <String, int>{'skills.hacking': 5},
      );
      expect(player.skills.containsKey('hacking'), isFalse);
    });

    test('provider 侧：NPC 侧键位 leadership 合法（学者分支的写入通道）', () {
      // `mixin_npc_interact` 的学者分支会把 NPC 的 skills 键
      // （leadership/politics/sword）直接灌进玩家技能表，
      // 所以白名单必须收 NPC 侧键，否则该通道会被本批误伤。
      final provider = GameStateProvider();
      final player = provider.applyEffects(
        provider.player,
        const <String, int>{'skills.leadership': 1},
      );
      expect(player.skills['leadership'], 1);
    });

    test('provider 侧：未知属性键不落盘', () {
      final provider = GameStateProvider();
      final player = provider.applyEffects(
        provider.player,
        const <String, int>{'attributes.luck': 5},
      );
      expect(player.attributes.containsKey('luck'), isFalse);
    });

    test('provider 侧：中文翻译键（skills.剑术）不落盘', () {
      // AI 常把技能名中文化后直接当键——这正是要拦的那类幽灵键，
      // 否则 `labels.skillLabel` 的 `_ => key` 会让「剑术」进面板。
      final provider = GameStateProvider();
      final player = provider.applyEffects(
        provider.player,
        const <String, int>{'skills.剑术': 3},
      );
      expect(player.skills.containsKey('剑术'), isFalse);
      // 真实键仍然生效。
      final p2 = provider.applyEffects(
        player,
        const <String, int>{'skills.sword': 3},
      );
      expect(p2.skills['sword'], 6); // 默认 3 + 3
    });

    test('provider 侧：合法技能/属性增减不受影响', () {
      final provider = GameStateProvider();
      final player = provider.applyEffects(
        provider.player,
        const <String, int>{'skills.alchemy': 1, 'attributes.willpower': 2},
      );
      expect(player.skills['alchemy'], 1); // 默认 0 + 1
      expect(player.attributes['willpower'], 7); // 默认 5 + 2
    });

    test('event_service 侧：未知技能/属性键进 failedEffects', () {
      final res = const EventService().applyEffects(
        Player.defaultPlayer(),
        _choice('skills.hacking', 2),
      );
      expect(res.failedEffects['skills.hacking'], 2);
      expect(res.newPlayer.skills.containsKey('hacking'), isFalse);

      final res2 = const EventService().applyEffects(
        Player.defaultPlayer(),
        _choice('attributes.luck', 2),
      );
      expect(res2.failedEffects['attributes.luck'], 2);
      expect(res2.newPlayer.attributes.containsKey('luck'), isFalse);
    });

    test('event_service 侧：合法技能键照常 applied', () {
      final res = const EventService().applyEffects(
        Player.defaultPlayer(),
        _choice('skills.sword', 1),
      );
      expect(res.appliedEffects['skills.sword'], 1);
      expect(res.failedEffects, isEmpty);
      expect(res.newPlayer.skills['sword'], 4); // 默认 3 + 1
    });

    test('全量内容事件零回归：所有 skills./attributes. 键都在白名单内', () {
      for (final event in allEvents) {
        for (final choice in event.choices) {
          for (final key in choice.effects.keys) {
            if (key.startsWith('skills.')) {
              expect(
                BalanceData.kPlayerSkillKeys.contains(key.substring(7)),
                isTrue,
                reason: '事件「${event.name}」的技能键 $key 不在白名单内',
              );
            } else if (key.startsWith('attributes.')) {
              expect(
                BalanceData.kPlayerAttributeKeys.contains(key.substring(11)),
                isTrue,
                reason: '事件「${event.name}」的属性键 $key 不在白名单内',
              );
            }
          }
        }
      }
    });

    test('玩家默认 skills/attributes 的全部键都在白名单内', () {
      // defaultPlayer 的键全部合法——否则一开局 AI 的技能/属性写入就失效。
      final p = Player.defaultPlayer();
      for (final key in p.skills.keys) {
        expect(BalanceData.kPlayerSkillKeys.contains(key), isTrue,
            reason: 'defaultPlayer 技能键 $key 不在白名单内');
      }
      for (final key in p.attributes.keys) {
        expect(BalanceData.kPlayerAttributeKeys.contains(key), isTrue,
            reason: 'defaultPlayer 属性键 $key 不在白名单内');
      }
    });
  });

  group('Batch 10-91/92 白名单与标签表同步（单一真相护栏）', () {
    test('kPlayerSkillKeys 与 labels.skillLabel 的键集完全一致', () {
      // 标签表是单一真相：新增技能若只加标签不加白名单（或反之），
      // 这里就会红——避免出现「面板无标签的幽灵技能」或
      // 「有标签但写不进去的死技能」。
      for (final key in BalanceData.kPlayerSkillKeys) {
        expect(
          skillLabel(key),
          isNot(equals(key)),
          reason: '技能键 $key 在 labels.skillLabel 里没有中文标签',
        );
      }
      // 反向：labels 里能中文化的键都应在白名单内（穷举 13 个已知标签键）。
      const labelled = <String>{
        'sword', 'leadership', 'politics', 'archery', 'scholarship',
        'stealth', 'fencing', 'survival', 'craft', 'magic',
        'riding', 'speech', 'alchemy',
      };
      expect(BalanceData.kPlayerSkillKeys, labelled);
    });

    test('kPlayerAttributeKeys 与 labels.attributeLabel 的键集完全一致', () {
      for (final key in BalanceData.kPlayerAttributeKeys) {
        expect(
          attributeLabel(key),
          isNot(equals(key)),
          reason: '属性键 $key 在 labels.attributeLabel 里没有中文标签',
        );
      }
      const labelled = <String>{
        'strength', 'agility', 'intelligence',
        'charisma', 'willpower', 'perception',
      };
      expect(BalanceData.kPlayerAttributeKeys, labelled);
    });

    test('源码级护栏：两条 applyEffects 通道都带白名单守卫', () {
      // 剥注释后再扫，否则会命中本批注释里为说明历史而引用的字样（坑 52）。
      final providerSrc =
          _stripLineComments(File('lib/providers/game_state_provider.dart').readAsStringSync());
      final eventSrc =
          _stripLineComments(File('lib/services/event_service.dart').readAsStringSync());
      for (final entry in <String, String>{
        'game_state_provider.dart': providerSrc,
        'event_service.dart': eventSrc,
      }.entries) {
        expect(
          entry.value.contains('BalanceData.kPlayerSkillKeys'),
          isTrue,
          reason: '${entry.key} 未引用 kPlayerSkillKeys 白名单',
        );
        expect(
          entry.value.contains('BalanceData.kPlayerAttributeKeys'),
          isTrue,
          reason: '${entry.key} 未引用 kPlayerAttributeKeys 白名单',
        );
        expect(
          entry.value.contains('itemById'),
          isTrue,
          reason: '${entry.key} 未引用 itemById 校验物品 id',
        );
      }
    });
  });
}