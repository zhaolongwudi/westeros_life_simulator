/// Sprint 12 测试：指令参数归一化覆盖率（S12-3）。
///
/// 【本批修的是什么】
/// `command_alias.dart` 缺 `normalizeLocationAlias`（旅行只认 id），
/// `normalizeSkillAlias` 只覆盖 5/13 技能键（「训练 魔法」失败）。
/// 本文件**锁死覆盖率**，防止日后再加参数命令时又漏接归一化。
///
/// 【为什么不用 `requiredArgCount >= 1` 过滤命令】
/// 「旅行」的 `requiredArgCount` 是 0（空参数 = 开可去地点面板），
/// 它正是因此长期漏在扫描之外。此处**显式遍历全部注册指令**，
/// 对「需要参数」的指令验证其参数能归一化，且**单独立一组把「旅行」列出来**。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/balance_data.dart';
import 'package:westeros_life_simulator/data/item_data.dart';
import 'package:westeros_life_simulator/data/location_data.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/utils/command_alias.dart';
import 'package:westeros_life_simulator/utils/labels.dart';

void main() {
  group('S12-3 地点归一化 normalizeLocationAlias', () {
    test('中文名映射到 id（旅行 白港 → location_white_harbor）', () {
      expect(normalizeLocationAlias('白港'), 'location_white_harbor');
      expect(normalizeLocationAlias('巴隆镇'), 'location_barrowtowns');
    });

    test('id 原样返回（不破坏既有 id 输入）', () {
      expect(normalizeLocationAlias('location_white_harbor'), 'location_white_harbor');
    });

    test('名称包含匹配（容错）', () {
      // 「白港」包含于「白港」，前缀/后缀都应命中
      expect(normalizeLocationAlias('白港的码头'), 'location_white_harbor');
    });

    test('未知输入原样返回（交给 travel 报错，不吞错）', () {
      expect(normalizeLocationAlias('不存在的城'), '不存在的城');
      expect(normalizeLocationAlias(''), '');
    });

    test('全库地点：每个地点都能被自己的中文名归一化回去（无重名歧义）', () {
      for (final loc in allLocations) {
        expect(normalizeLocationAlias(loc.name), loc.id,
            reason: '地点「${loc.name}」应能被中文名解析回 ${loc.id}');
      }
    });
  });

  group('S12-3 技能归一化覆盖率（13/13）', () {
    test('每个技能键都有中文标签，且标签能被归一化回该键', () {
      for (final key in BalanceData.kPlayerSkillKeys) {
        final label = skillLabel(key);
        expect(normalizeSkillAlias(label), key,
            reason: '技能「$label」（$key）应能归一化回 $key');
      }
    });

    test('id 输入原样返回', () {
      for (final key in BalanceData.kPlayerSkillKeys) {
        expect(normalizeSkillAlias(key), key);
      }
    });

    test('原先漏掉的 8 个键现在都能被中文名命中', () {
      // 这 8 个就是 S12-3 前 normalizeSkillAlias 未覆盖、导致「训练 X」失败的键。
      expect(normalizeSkillAlias('统率'), 'leadership');
      expect(normalizeSkillAlias('权谋'), 'politics');
      expect(normalizeSkillAlias('学问'), 'scholarship');
      expect(normalizeSkillAlias('潜行'), 'stealth');
      expect(normalizeSkillAlias('刺击'), 'fencing');
      expect(normalizeSkillAlias('野外求生'), 'survival');
      expect(normalizeSkillAlias('手工技艺'), 'craft');
      expect(normalizeSkillAlias('魔法'), 'magic');
    });

    test('「训练 魔法」不再被拒（此条锁 S11-7 用户实测现象）', () {
      final e = GameEngine()..startNewGame();
      // defaultPlayer 技能表含 magic:0，可训练；S11-7 前「魔法」会原样返回导致失败。
      final res = e.resolveCommand('训练 魔法');
      expect(res.text, isNot(contains('从未学过')),
          reason: '「训练 魔法」不应报「你从未学过」：${res.text}');
    });
  });

  group('S12-3 端到端：按中文名旅行', () {
    test('resolveCommand「旅行 白港」真的移动（而非「没有叫白港的地方」）', () {
      final e = GameEngine()..startNewGame();
      final from = e.player.locationId;
      final res = e.resolveCommand('旅行 白港');
      expect(res.text, isNot(contains('没有叫')),
          reason: '按中文名应命中白港：${res.text}');
      expect(e.player.locationId, isNot(from), reason: '应已位移到白港');
      expect(e.player.locationId, 'location_white_harbor');
    });

    test('「旅行 location_white_harbor」（id）同样可位移（不回归）', () {
      final e = GameEngine()..startNewGame();
      final res = e.resolveCommand('旅行 location_white_harbor');
      expect(res.text, isNot(contains('没有叫')));
      expect(e.player.locationId, 'location_white_harbor');
    });

    test('「旅行」空参数仍开面板且不位移（不回归）', () {
      final e = GameEngine()..startNewGame();
      final from = e.player.locationId;
      final res = e.resolveCommand('旅行');
      expect(res.text, contains('可前往'));
      expect(e.player.locationId, from);
    });
  });

  group('S12-3 物品归一化未被破坏（不回归）', () {
    test('每个物品都能被自己的中文名归一化回 id', () {
      for (final item in kItems.values) {
        // 用 Strict 版：switch 别名表是手工维护的，历史上漏过
        // 「多恩红葡萄酒」「紫杉长弓」两件（UI 显示全名，命令却不认）。
        expect(normalizeItemAliasStrict(item.name), item.id,
            reason: '物品「${item.name}」应归一化回 ${item.id}');
      }
    });

    test('已知失配的两件物品：显示名与短别名都能用', () {
      // 这两条是回归锁：曾经 UI 写「多恩红葡萄酒」而命令只认「葡萄酒」。
      expect(normalizeItemAliasStrict('多恩红葡萄酒'), 'item_wine');
      expect(normalizeItemAliasStrict('紫杉长弓'), 'item_bow');
      // 短别名仍然有效（玩家也可能输简写）。
      expect(normalizeItemAliasStrict('葡萄酒'), 'item_wine');
      expect(normalizeItemAliasStrict('长弓'), 'item_bow');
      // id 直接可用。
      expect(normalizeItemAliasStrict('item_wine'), 'item_wine');
    });
  });
}