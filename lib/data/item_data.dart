/// 物品数据：维斯特洛世界可获取/使用的物品词典。
///
/// 物品模型 + 全部物品定义 + 中文标签/分类标签。
/// 供背包、贸易、事件、AI 效果共用。
library;

/// 物品分类。
enum ItemCategory {
  consumable, // 消耗品（食物/药剂）
  weapon, // 武器
  armor, // 护甲
  material, // 材料
  treasure, // 珍宝/贵重品
  relic, // 圣物/遗物
  document, // 文书/信件/配方
  mount, // 坐骑
}

/// 物品模型。
class Item {
  const Item({
    required this.id,
    required this.name,
    required this.category,
    required this.value,
    required this.description,
    this.stackable = true,
    this.usable = false,
    this.useEffect = const <String, int>{},
    this.requiresSkill = '',
  });

  /// 唯一标识（如 item_dragonbone）。
  final String id;

  /// 物品名。
  final String name;

  /// 分类。
  final ItemCategory category;

  /// 价值（金币，用于买卖）。
  final int value;

  /// 描述。
  final String description;

  /// 是否可堆叠（否则每个占一格）。
  final bool stackable;

  /// 是否可直接使用（触发 useEffect）。
  final bool usable;

  /// 使用效果（键同效果系统：health/energy/hunger/gold 等）。
  final Map<String, int> useEffect;

  /// 使用所需技能（如 'alchemy'；空串表示无要求）。
  final String requiresSkill;
}

/// 物品分类中文标签。
String itemCategoryLabel(ItemCategory c) {
  return switch (c) {
    ItemCategory.consumable => '消耗品',
    ItemCategory.weapon => '武器',
    ItemCategory.armor => '护甲',
    ItemCategory.material => '材料',
    ItemCategory.treasure => '珍宝',
    ItemCategory.relic => '圣物',
    ItemCategory.document => '文书',
    ItemCategory.mount => '坐骑',
  };
}

/// 全部物品（词典常量，供背包/贸易/AI 引用）。
const Map<String, Item> kItems = <String, Item>{
  // ==================== 消耗品 ====================
  'item_bread': Item(
    id: 'item_bread',
    name: '黑面包',
    category: ItemCategory.consumable,
    value: 2,
    description: '粗粝的黑面包，底层人的主食。',
    usable: true,
    useEffect: const <String, int>{'hunger': 15},
  ),
  'item_meat': Item(
    id: 'item_meat',
    name: '烤肉',
    category: ItemCategory.consumable,
    value: 6,
    description: '滋滋作响的烤肉，饱腹又美味。',
    usable: true,
    useEffect: const <String, int>{'hunger': 35},
  ),
  'item_fish': Item(
    id: 'item_fish',
    name: '腌鱼',
    category: ItemCategory.consumable,
    value: 4,
    description: '盐腌的鱼干，可以存放很久。',
    usable: true,
    useEffect: const <String, int>{'hunger': 25},
  ),
  'item_wine': Item(
    id: 'item_wine',
    name: '多恩红葡萄酒',
    category: ItemCategory.consumable,
    value: 15,
    description: '浓烈的红色酒液，贵族宴会的常客。',
    usable: true,
    useEffect: const <String, int>{'energy': 15, 'reputation': 1},
  ),
  'item_herb': Item(
    id: 'item_herb',
    name: '草药',
    category: ItemCategory.consumable,
    value: 8,
    description: '学士们常用的伤药原料，可缓解伤痛。',
    usable: true,
    useEffect: const <String, int>{'health': 20},
    requiresSkill: 'alchemy',
  ),
  'item_poultice': Item(
    id: 'item_poultice',
    name: '金疮药膏',
    category: ItemCategory.consumable,
    value: 25,
    description: '敷在伤口上的药膏，能止血生肌。',
    usable: true,
    useEffect: const <String, int>{'health': 40},
  ),
  'item_dreamwine': Item(
    id: 'item_dreamwine',
    name: '罂粟花蜜酒',
    category: ItemCategory.consumable,
    value: 30,
    description: '学士的安眠药酒，痛时饮下能安睡一夜。',
    usable: true,
    useEffect: const <String, int>{'health': 30, 'energy': 20},
  ),
  // ==================== 武器 ====================
  'item_dagger': Item(
    id: 'item_dagger',
    name: '匕首',
    category: ItemCategory.weapon,
    value: 10,
    description: '藏在腰间的短刃，贴身防身的好帮手。',
  ),
  'item_sword': Item(
    id: 'item_sword',
    name: '长剑',
    category: ItemCategory.weapon,
    value: 40,
    description: '铁匠锻打的寻常长剑，骑士的标配。',
  ),
  'item_bastard_sword': Item(
    id: 'item_bastard_sword',
    name: '杂种剑',
    category: ItemCategory.weapon,
    value: 80,
    description: '介于长剑与巨剑之间，双手可握的利器。',
  ),
  'item_bow': Item(
    id: 'item_bow',
    name: '紫杉长弓',
    category: ItemCategory.weapon,
    value: 30,
    description: '长城以北的野人擅长使的强弓。',
  ),
  'item_valyrian_dagger': Item(
    id: 'item_valyrian_dagger',
    name: '瓦雷利亚钢匕首',
    category: ItemCategory.weapon,
    value: 500,
    description: '瓦雷利亚钢打造的匕首，轻若无物却削铁如泥。',
  ),
  // ==================== 护甲 ====================
  'item_leather_armor': Item(
    id: 'item_leather_armor',
    name: '皮甲',
    category: ItemCategory.armor,
    value: 25,
    description: '鞣制皮革缝制的轻甲，灵活且便宜。',
  ),
  'item_chainmail': Item(
    id: 'item_chainmail',
    name: '锁子甲',
    category: ItemCategory.armor,
    value: 90,
    description: '万千铁环扣成的链甲，寻常盗匪难伤分毫。',
  ),
  'item_plate_armor': Item(
    id: 'item_plate_armor',
    name: '全身板甲',
    category: ItemCategory.armor,
    value: 220,
    description: '精锻钢板覆盖全身的重甲，只有富裕骑士才穿得起。',
  ),
  // ==================== 材料 ====================
  'item_iron_ore': Item(
    id: 'item_iron_ore',
    name: '铁矿石',
    category: ItemCategory.material,
    value: 3,
    description: '未经熔炼的铁矿石，铁匠铺的原材料。',
  ),
  'item_steel': Item(
    id: 'item_steel',
    name: '精钢锭',
    category: ItemCategory.material,
    value: 12,
    description: '反复锻打提纯的钢锭，可打造上等兵刃。',
  ),
  'item_leather': Item(
    id: 'item_leather',
    name: '鞣制皮革',
    category: ItemCategory.material,
    value: 5,
    description: '硝制过的皮革，缝甲制靴都少不了。',
  ),
  'item_dragonbone': Item(
    id: 'item_dragonbone',
    name: '龙骨',
    category: ItemCategory.material,
    value: 150,
    description: '古老巨龙的遗骨，弓匠们梦寐以求的材料。',
  ),
  'item_glass_candle': Item(
    id: 'item_glass_candle',
    name: '玻璃蜡烛',
    category: ItemCategory.material,
    value: 400,
    description: '学城奇物，点燃后不需燃烧也能发光——无人知其原理。',
  ),
  // ==================== 珍宝 ====================
  'item_gold_chain': Item(
    id: 'item_gold_chain',
    name: '金链',
    category: ItemCategory.treasure,
    value: 100,
    description: '沉甸甸的金链，可以直接换成金币。',
  ),
  'item_ruby': Item(
    id: 'item_ruby',
    name: '红宝石',
    category: ItemCategory.treasure,
    value: 200,
    description: '鸽血红宝石，君临城珠宝商的珍爱。',
  ),
  'item_sapphire': Item(
    id: 'item_sapphire',
    name: '蓝宝石',
    category: ItemCategory.treasure,
    value: 180,
    description: '产自西境的深蓝宝石，兰尼斯特的最爱。',
  ),
  'item_crown': Item(
    id: 'item_crown',
    name: '青铜王冠',
    category: ItemCategory.treasure,
    value: 800,
    description: '旧王朝的遗物，戴过它的王早已成白骨。',
  ),
  // ==================== 圣物 ====================
  'item_heart_tree_leaf': Item(
    id: 'item_heart_tree_leaf',
    name: '心树之叶',
    category: ItemCategory.relic,
    value: 120,
    description: '鱼梁木上采下的叶子，旧神信徒视为神圣。',
  ),
  'item_seven_star': Item(
    id: 'item_seven_star',
    name: '七芒星徽',
    category: ItemCategory.relic,
    value: 100,
    description: '七神教会的银徽，大主教亲赐的祝福。',
  ),
  'item_lightbringer_shard': Item(
    id: 'item_lightbringer_shard',
    name: '光之使者残片',
    category: ItemCategory.relic,
    value: 600,
    description: '传说中英雄之剑的碎片，摸上去微微发烫。',
  ),
  // ==================== 文书 ====================
  'item_parchment': Item(
    id: 'item_parchment',
    name: '羊皮纸',
    category: ItemCategory.document,
    value: 1,
    description: '学士写信常用的羊皮纸，也可以用来记账。',
  ),
  'item_raven_letter': Item(
    id: 'item_raven_letter',
    name: '渡鸦信',
    category: ItemCategory.document,
    value: 5,
    description: '密封的渡鸦信，可能藏着重要的情报。',
  ),
  'item_treaty': Item(
    id: 'item_treaty',
    name: '盟约文书',
    category: ItemCategory.document,
    value: 300,
    description: '盖着两家蜡印的盟约文书，见证过誓约与背叛。',
  ),
  'item_recipe_dragonfire': Item(
    id: 'item_recipe_dragonfire',
    name: '野火配方',
    category: ItemCategory.document,
    value: 450,
    description: '学城禁书中的配方，记载着绿色烈焰的调制秘法。',
  ),
  // ==================== 坐骑 ====================
  'item_horse': Item(
    id: 'item_horse',
    name: '骏马',
    category: ItemCategory.mount,
    value: 120,
    description: '一匹结实的北方战马，长途跋涉的忠实伙伴。',
    stackable: false,
  ),
  'item_garron': Item(
    id: 'item_garron',
    name: '小矮马',
    category: ItemCategory.mount,
    value: 60,
    description: '耐寒的小矮马，野人部落的心头好。',
    stackable: false,
  ),
};

/// 按 ID 取物品（未知返回 null）。
Item? itemById(String id) => kItems[id];

/// 物品名（未知返回 ID 本身）。
String itemName(String id) => kItems[id]?.name ?? id;

/// 分类中文标签（未知返回「其他」）。
String itemCategoryLabelById(String id) {
  final item = kItems[id];
  return item == null ? '其他' : itemCategoryLabel(item.category);
}
