/// 中文标签工具：身份/季节/事件类型的中文文案统一映射。
///
/// 从 start_screen / events_screen / game_screen 迁移而来，
/// 全项目统一引用，避免重复 switch。
library;

import '../models/event.dart';
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
    'longwinter' => '凛冬',
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
    'longwinter' => '凛',
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
