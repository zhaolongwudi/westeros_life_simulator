/// 中文标签工具：身份/季节/事件类型的中文文案统一映射。
///
/// 从 start_screen / events_screen / game_screen 迁移而来，
/// 全项目统一引用，避免重复 switch。
///
/// M6（Batch 10-37）契约：本文件是**全项目文案的唯一集中层**
/// （可替换资源接口的雏形）。规则：
/// - 新增任何面向玩家的中文文案（身份/季节/事件/身世等）必须在此定义函数，
///   禁止在 mixin / screen / service 里直接写中文标签字面量（坑 17 同类）。
/// - 将来若做 i18n，只改本文件函数体即可，调用点零改动。
library;

import '../models/event.dart';
import '../models/location.dart';
import '../models/marital.dart';
import '../models/npc.dart';
import '../models/player.dart';

/// 身份中文标签。
String identityLabel(PlayerIdentity identity) {
  return switch (identity) {
    PlayerIdentity.noble => '贵族',
    PlayerIdentity.commoner => '平民',
    PlayerIdentity.soldier => '士兵',
    PlayerIdentity.merchant => '商人',
    PlayerIdentity.priest => '神职人员',
    PlayerIdentity.scholar => '学者',
    PlayerIdentity.adventurer => '冒险者',
    PlayerIdentity.assassin => '刺客',
    PlayerIdentity.maester => '学士',
    PlayerIdentity.wildling => '野人',
  };
}

/// 季节中文标签（含凛冬）。
String seasonLabel(String season) {
  return switch (season) {
    'spring' => '春天',
    'summer' => '夏天',
    'autumn' => '秋天',
    'winter' => '冬天',
    _ => season,
  };
}

/// 季节短标签（状态条用，单字）。
String seasonShortLabel(String season) {
  return switch (season) {
    'spring' => '春',
    'summer' => '夏',
    'autumn' => '秋',
    'winter' => '冬',
    _ => season,
  };
}

/// 事件类型中文标签。
String eventTypeLabel(EventType type) {
  return switch (type) {
    EventType.political => '政治',
    EventType.family => '家族',
    EventType.war => '战争',
    EventType.religious => '宗教',
    EventType.economic => '经济',
    EventType.magical => '魔法',
    EventType.daily => '日常',
    EventType.adventure => '冒险',
    EventType.supernatural => '超自然',
  };
}

/// 配偶身世中文标签（Batch 10-27）。
///
/// 此前 mixin_marriage / ai_service / 两个 screen 直接用 `origin.name`
/// 输出英文枚举名（noble/commoner/merchant/warrior），中文叙事里突兀。
String spouseOriginLabel(SpouseOrigin origin) {
  return switch (origin) {
    SpouseOrigin.noble => '贵族',
    SpouseOrigin.commoner => '平民',
    SpouseOrigin.merchant => '商人',
    SpouseOrigin.warrior => '战士',
  };
}
/// 地点类型中文标签（Batch 10-63）。
///
/// 覆盖 LocationType 全部枚举（含当前数据未用但定义存在的
/// temple/tavern/market），避免未来扩充地点时出现英文枚举名泄漏。
String locationTypeLabel(LocationType type) {
  return switch (type) {
    LocationType.castle => '城堡',
    LocationType.city => '城市',
    LocationType.village => '村庄',
    LocationType.fort => '要塞',
    LocationType.temple => '神庙',
    LocationType.academy => '学院',
    LocationType.tavern => '酒馆',
    LocationType.market => '市场',
    LocationType.wilderness => '荒野',
    LocationType.supernatural => '超自然领域',
    LocationType.unknown => '未知世界',
  };
}
/// NPC 类型中文标签（Batch 10-64）。
///
/// 覆盖 NpcType 全部枚举（含当前数据未用但定义存在的
/// soldier/merchant/priest/scholar/adventurer/assassin/maester/commoner/supernatural），
/// 避免未来扩充 NPC 时出现英文枚举名泄漏。
String npcTypeLabel(NpcType type) {
  return switch (type) {
    NpcType.noble => '贵族',
    NpcType.soldier => '士兵',
    NpcType.merchant => '商人',
    NpcType.priest => '神职人员',
    NpcType.scholar => '学者',
    NpcType.adventurer => '冒险者',
    NpcType.assassin => '刺客',
    NpcType.maester => '学士',
    NpcType.wildling => '野人',
    NpcType.commoner => '平民',
    NpcType.supernatural => '超自然存在',
  };
}

/// 技能键中文标签（Batch 10-79，10-81 补玩家侧键）。
///
/// NPC 侧（npc_data.dart）用 sword/leadership/politics 三键；
/// 玩家侧（player.dart defaultPlayer）用 sword/archery/riding/speech/alchemy，
/// 两套键位不同——10-81 补齐玩家侧的 riding/speech/alchemy，
/// 避免玩家技能行中文化时漏键退回英文。未知键原样返回（兜底，不抛）。
String skillLabel(String key) {
  return switch (key) {
    'sword' => '剑术',
    'leadership' => '统率',
    'politics' => '权谋',
    'archery' => '弓术',
    'scholarship' => '学问',
    'stealth' => '潜行',
    'fencing' => '刺击',
    'survival' => '野外求生',
    'craft' => '手工技艺',
    'magic' => '魔法',
    // 玩家侧键（player.dart）
    'riding' => '骑术',
    'speech' => '口才',
    'alchemy' => '炼金',
    _ => key,
  };
}

/// 属性键中文标签（Batch 10-81）。
///
/// 玩家 `attributes` 六个键：strength/agility/intelligence/charisma/
/// willpower/perception。未知键原样返回（兜底，不抛）。
String attributeLabel(String key) {
  return switch (key) {
    'strength' => '力量',
    'agility' => '敏捷',
    'intelligence' => '智识',
    'charisma' => '魅力',
    'willpower' => '意志',
    'perception' => '感知',
    _ => key,
  };
}

/// 状态标记键中文标签（Batch 10-102）。
///
/// 玩家 `flags` 的 26 个静态键（`BalanceData.kPlayerFlagKeys`：17 个内容
/// 事件键 + 9 个引擎系统键）。未知键返回 **null 而非原样返回**——与
/// `skillLabel` / `attributeLabel` 的兜底策略刻意不同：
///
/// 【为什么这里要 null 而不是原样返回】`flags` 与 `skills.`/`attributes.`
/// 的关键差别是**动态前缀**。`flags.equipped.item_sword` /
/// `flags.npc_task.npc_tyrion.某任务` 这类键由引擎在运行时拼出，
/// 静态键表天然覆盖不到。若沿用「未知键原样返回」，调用方就无法区分
/// 「这是个该翻中文名的静态键」与「这是个带动态部分的键、需另行处理」，
/// 于是玩家面板只能显示裸英文键。返回 null 让调用方拿到「未命中静态表」
/// 的信号，再按前缀规则兜底。
///
/// 键集与 `BalanceData.kPlayerFlagKeys` 一一对应（有测试断言零漂移）。
String? flagLabel(String key) {
  return switch (key) {
    // —— 内容事件 17 键（event_data.dart 的字面量键）——
    'honor_pledge' => '荣誉誓约',
    'hasShelter' => '寻得庇护',
    'hasDirewolf' => '驯服恐狼',
    'hasBlessing' => '神明庇佑',
    'hasVision' => '幻视',
    'hasCandleVision' => '烛中幻象',
    'hasCometRecord' => '彗星异象',
    'hasWarned' => '已示警',
    'hasFrozenVision' => '冰境幻视',
    'guild_ally' => '商会盟友',
    'guild_secret' => '商会秘闻',
    'guild_enemy' => '商会敌对',
    'sworn_brother' => '义兄弟',
    'watch_friend' => '守夜人友人',
    'market_hero' => '集市传奇',
    'market_intel' => '集市情报',
    'lord_favor' => '领主赏识',
    // —— 引擎系统键 9 个（mixin 层）——
    'isAlive' => '存活',
    'isInjured' => '负伤',
    'negotiated' => '今日已议价',
    'isMarried' => '已婚',
    'divorceYear' => '离婚当年',
    'widowed' => '丧偶',
    'isExiled' => '流放中',
    'generation' => '已传承',
    'inherited' => '已继承家主之位',
    _ => null,
  };
}
