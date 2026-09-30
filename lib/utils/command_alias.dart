/// 指令参数归一化（Batch 10-28 · M3：从 mixin_commands 抽出为共享工具）。
///
/// 原为 mixin_commands 内的私有方法，注册表化后各领域 mixin 都要用，
/// 因此提升为顶层函数（纯函数 + 显式传入宿主，避免跨 mixin 私有可见性问题）。
library;
import '../data/item_data.dart';
import '../models/npc.dart';
import '../providers/game_provider_base.dart';

/// 物品别名归一化（支持中文名/ID）。
String normalizeItemAlias(String raw) {
  final s = raw.trim();
  return switch (s) {
    '黑面包' || '面包' || 'item_bread' => 'item_bread',
    '烤肉' || '肉' || 'item_meat' => 'item_meat',
    '腌鱼' || '鱼' || 'item_fish' => 'item_fish',
    '葡萄酒' || '红酒' || 'item_wine' => 'item_wine',
    '草药' || 'item_herb' => 'item_herb',
    '药膏' || '金疮药膏' || 'item_poultice' => 'item_poultice',
    '罂粟花蜜酒' || 'item_dreamwine' => 'item_dreamwine',
    '匕首' || 'item_dagger' => 'item_dagger',
    '长剑' || '剑' || 'item_sword' => 'item_sword',
    '杂种剑' || 'item_bastard_sword' => 'item_bastard_sword',
    '长弓' || '弓' || 'item_bow' => 'item_bow',
    '瓦雷利亚钢匕首' || 'item_valyrian_dagger' => 'item_valyrian_dagger',
    '皮甲' || 'item_leather_armor' => 'item_leather_armor',
    '锁子甲' || 'item_chainmail' => 'item_chainmail',
    '板甲' || '全身板甲' || 'item_plate_armor' => 'item_plate_armor',
    '骏马' || '马' || 'item_horse' => 'item_horse',
    '小矮马' || 'item_garron' => 'item_garron',
    '龙骨' || 'item_dragonbone' => 'item_dragonbone',
    '玻璃蜡烛' || 'item_glass_candle' => 'item_glass_candle',
    '金链' || 'item_gold_chain' => 'item_gold_chain',
    '红宝石' || '宝石' || 'item_ruby' => 'item_ruby',
    '蓝宝石' || 'item_sapphire' => 'item_sapphire',
    '王冠' || '青铜王冠' || 'item_crown' => 'item_crown',
    '心树之叶' || 'item_heart_tree_leaf' => 'item_heart_tree_leaf',
    '七芒星徽' || 'item_seven_star' => 'item_seven_star',
    '光之使者残片' || 'item_lightbringer_shard' => 'item_lightbringer_shard',
    '羊皮纸' || 'item_parchment' => 'item_parchment',
    '渡鸦信' || 'item_raven_letter' => 'item_raven_letter',
    '盟约文书' || 'item_treaty' => 'item_treaty',
    '野火配方' || 'item_recipe_dragonfire' => 'item_recipe_dragonfire',
    '铁矿石' || 'item_iron_ore' => 'item_iron_ore',
    '精钢锭' || '钢锭' || 'item_steel' => 'item_steel',
    '皮革' || '鞣制皮革' || 'item_leather' => 'item_leather',
    _ => s,
  };
}

/// 物品 ID 是否存在于物品表。
bool isKnownItemId(String id) => kItems.containsKey(id);

/// 技能别名归一化。
String normalizeSkillAlias(String raw) {
  final s = raw.trim();
  return switch (s) {
    '剑术' || '剑' || 'sword' => 'sword',
    '弓术' || '弓箭' || '射箭' || 'archery' => 'archery',
    '骑术' || '骑马' || 'riding' => 'riding',
    '口才' || '演讲' || 'speech' => 'speech',
    '炼金' || '炼金术' || 'alchemy' => 'alchemy',
    _ => s,
  };
}

/// NPC 名称/别名归一化（支持中文名/ID；在场优先，其次全局）。
String normalizeNpcAlias(GameProviderBase base, String raw) {
  final s = raw.trim();
  final byId = base.npcById(s);
  if (byId != null) return byId.id;
  Npc? hit;
  for (final n in base.npcsAtCurrentLocation) {
    if (n.name == s || n.name.contains(s)) {
      hit = n;
      break;
    }
  }
  if (hit == null) {
    for (final n in base.npcs) {
      if (n.name == s) {
        hit = n;
        break;
      }
    }
  }
  if (hit != null) return hit.id;
  return s;
}