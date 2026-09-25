/// 游戏提供者基类：Batch 4 混入层的宿主。
///
/// 扩展 [GameStateProvider]，额外持有世界的静态数据
/// （NPC、地点、家族、系统、事件模板），并沉淀各 mixin 共用的
/// 公共能力（身份判断、金币/关系/标记变更、随机工具），避免混入层重复代码。
library;

import 'dart:math';

import '../data/event_data.dart';
import '../data/family_data.dart';
import '../data/location_data.dart';
import '../data/npc_data.dart';
import '../data/system_data.dart';
import '../models/event.dart';
import '../models/family.dart';
import '../models/location.dart';
import '../models/npc.dart';
import '../models/player.dart';
import '../models/system.dart';
import 'event_provider.dart';
import 'game_state_provider.dart';

/// 游戏提供者基类。mixin 通过 `on GameProviderBase` 挂载。
abstract class GameProviderBase extends GameStateProvider {
  GameProviderBase({
    super.player,
    super.progress,
    super.history,
    super.currentEvent,
    super.isGameActive,
    super.isGameOver,
    List<Npc>? npcs,
    List<Location>? locations,
    List<Family>? families,
    List<GameSystem>? systems,
    List<GameEvent>? events,
  })  : _npcs = npcs ?? allNpcs,
        _locations = locations ?? allLocations,
        _families = families ?? allFamilies,
        _systems = systems ?? allSystems,
        _events = events ?? allEvents,
        eventProvider = EventProvider(events: events ?? allEvents);

  List<Npc> _npcs;
  List<Location> _locations;
  List<Family> _families;
  List<GameSystem> _systems;
  List<GameEvent> _events;

  /// 事件提供者（组合复用，供事件面板浏览/触发）。
  final EventProvider eventProvider;

  /// 世界全部 NPC。
  List<Npc> get npcs => List.unmodifiable(_npcs);

  /// 世界全部地点。
  List<Location> get locations => List.unmodifiable(_locations);

  /// 世界全部家族。
  List<Family> get families => List.unmodifiable(_families);

  /// 世界全部系统。
  List<GameSystem> get systems => List.unmodifiable(_systems);

  /// 世界全部事件模板。
  List<GameEvent> get eventTemplates => List.unmodifiable(_events);

  /// 按 ID 查找 NPC。
  Npc? npcById(String id) {
    for (final n in _npcs) {
      if (n.id == id) return n;
    }
    return null;
  }

  /// 按 ID 查找地点。
  Location? locationById(String id) {
    for (final l in _locations) {
      if (l.id == id) return l;
    }
    return null;
  }

  /// 按 ID 查找家族。
  Family? familyById(String id) {
    for (final f in _families) {
      if (f.id == id) return f;
    }
    return null;
  }

  /// 按 ID 查找系统。
  GameSystem? systemById(String id) {
    for (final s in _systems) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// 玩家当前所在地点。
  Location? get currentLocation => locationById(player.locationId);

  /// 玩家所属家族。
  Family? get playerFamily => familyById(player.familyId);

  /// 当前地点在场的存活 NPC（按地点筛选）。
  List<Npc> get npcsAtCurrentLocation {
    return _npcs
        .where((n) => n.isAlive && n.locationId == player.locationId)
        .toList();
  }

  /// 世界快照：供 AI 提示词/存档摘要使用。
  String worldSnapshot() {
    final loc = currentLocation;
    final fam = playerFamily;
    final buf = StringBuffer()
      ..writeln('【世界快照】')
      ..writeln('· 时间：${progress.year}年${progress.month}月（${progress.season}）')
      ..writeln('· 地点：${loc?.name ?? player.locationId}'
          '（危险度 ${loc?.dangerLevel ?? '?'}）')
      ..writeln('· 家族：${fam?.name ?? player.familyId}'
          '（影响力 ${fam?.influence ?? '?'}）')
      ..writeln('· 在场 NPC：'
          '${npcsAtCurrentLocation.take(5).map((n) => n.name).join('、')}'
          '${npcsAtCurrentLocation.length > 5 ? '等' : ''}');
    return buf.toString().trim();
  }

  // ==================== 公共能力（供各 mixin 复用） ====================

  /// 玩家身份是否匹配指定枚举（如 [PlayerIdentity.merchant]）。
  bool isIdentity(PlayerIdentity identity) => player.identity == identity;

  /// 玩家是否属于指定家族（按家族 ID，如 family_targaryen）。
  bool isFamily(String familyId) => player.familyId == familyId;

  /// 玩家是否在指定地点（按地点 ID）。
  bool isAt(String locationId) => player.locationId == locationId;

  /// 玩家是否位于指定区域（如 '北境'、'铁群岛'、'厄索斯'、'长城'）。
  bool isInRegion(String region) => currentLocation?.region == region;

  /// 玩家所在地是否为指定类型（如城市/荒野/超自然）。
  bool isAtType(LocationType type) => currentLocation?.type == type;

  /// 玩家技能等级。
  int skillLevel(String skill) => player.skills[skill] ?? 0;

  /// 增加金币（负数即扣除，防负数破底）。
  void gainGold(int delta) {
    final newGold = max(0, player.gold + delta);
    updatePlayer(player.copyWith(gold: newGold));
  }

  /// 调整声望（clamp 0~100）。
  void adjustReputation(int delta) {
    updatePlayer(
      player.copyWith(reputation: (player.reputation + delta).clamp(0, 100)),
    );
  }

  /// 调整与 NPC 的关系值（clamp -100~100），写入 player.relations。
  void adjustRelation(String npcId, int delta) {
    final cur = player.relations[npcId] ?? 0;
    final newRelations = Map<String, int>.from(player.relations);
    newRelations[npcId] = (cur + delta).clamp(-100, 100);
    updatePlayer(player.copyWith(relations: newRelations));
  }

  /// 设置一个布尔状态标记（如 isInjured）。
  void setFlag(String key, bool value) {
    final newFlags = Map<String, bool>.from(player.flags);
    newFlags[key] = value;
    updatePlayer(player.copyWith(flags: newFlags));
  }

  /// 读取布尔状态标记。
  bool flagOf(String key) => player.flags[key] ?? false;

  /// 应用 AI 生成的选项效果，并推进一个月（含月度系统结算 + 信件触发）。
  ///
  /// 返回完整的回合叙事文本（供 AI 行动模式展示）。
  /// AI 选项效果支持 gold / reputation / skills.<name> / attributes.<name>。
  String applyAiChoice(EventChoice choice) {
    if (!isGameActive || isGameOver) {
      return '游戏尚未开始。';
    }
    // 1. 效果落盘
    final before = player;
    updatePlayer(applyEffects(player, choice.effects));
    final buf = StringBuffer();
    if (choice.narrative.isNotEmpty) {
      buf.writeln(choice.narrative);
    }
    // 2. 效果摘要（仅当有变化时）
    final goldDelta = player.gold - before.gold;
    final repDelta = player.reputation - before.reputation;
    if (goldDelta != 0) {
      buf.writeln('💰 金币 ${goldDelta > 0 ? '+' : ''}$goldDelta（${player.gold}）');
    }
    if (repDelta != 0) {
      buf.writeln('🌟 声望 ${repDelta > 0 ? '+' : ''}$repDelta（${player.reputation}）');
    }
    // 3. 月度推进（系统结算 + 信件 + 时间）
    buf.writeln(advanceMonth());
    // 4. NPC 主动来信（月度触发）
    final letter = maybeTriggerLetter(seed: progress.turnCount);
    if (letter.isNotEmpty) {
      buf.writeln(letter);
    }
    return buf.toString().trim();
  }

  /// 基于回合数生成一个确定性随机源（同回合结果可复现）。
  Random rng([int? seed]) => Random(seed ?? progress.turnCount);
}
