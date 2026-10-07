/// 游戏提供者基类：Batch 4 混入层的宿主。
///
/// 扩展 [GameStateProvider]，额外持有世界的静态数据
/// （NPC、地点、家族、系统、事件模板），并沉淀各 mixin 共用的
/// 公共能力（身份判断、金币/关系/标记变更、随机工具），避免混入层重复代码。
library;

import 'dart:math';

import '../data/event_data.dart';
import '../data/family_data.dart';
import '../data/item_data.dart';
import '../data/location_data.dart';
import '../data/npc_data.dart';
import '../data/system_data.dart';
import '../models/event.dart';
import '../models/family.dart';
import '../models/location.dart';
import '../models/npc.dart';
import '../models/player.dart';
import '../models/system.dart';
import '../core/monthly_pipeline.dart';
import '../utils/labels.dart';
import 'event_provider.dart';
import 'game_state_provider.dart';

/// 游戏提供者基类。mixin 通过 `on GameProviderBase` 挂载。
abstract class GameProviderBase extends GameStateProvider {
  GameProviderBase({
    super.player,
    super.progress,
    super.history,
    super.currentEvent,
    super.pendingEvent,
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

  // ---------------------------------------------------------------------------
  // S12-10：月度管线的**延迟注册点**。
  //
  // 【为什么需要这个口子】各领域的月度钩子本来都写在 `mixin_play` 的
  // `monthlyPipeline` 里逐个调用，但 `GamePlayMixin` 的 `on` 约束**加不进**
  // `GameLetterMixin` —— 它在 `game_engine.dart` 的 `with` 列表里排在
  // `GamePlayMixin` 之后，Dart 会报
  // `mixin_application_not_implemented_interface`（已实测）。
  //
  // 【做法】允许各 mixin 把自己的注册函数追加到这里，由 `monthlyPipeline`
  // 在构建时统一执行。这样注册方与被依赖方不必共享 `on` 约束，
  // 也不必调整 `with` 顺序（那会连带影响其它 mixin 的约束校验）。
  final List<void Function(MonthlyPipeline)> monthlyHookRegistrars =
      <void Function(MonthlyPipeline)>[];

  // ---------------------------------------------------------------------------
  // S8-1：一次性事件的完成集合在**存档的两个边界**上同步。
  //
  // 运行时的唯一持有者是 [eventProvider]；状态层的 `completedEventIds`
  // 只是存档载体（读档链路反序列化的是裸 GameStateProvider，见
  // save_service.dart:184/261）。只改写入侧或只改读取侧都不成立——这是
  // 本项目「双通道漂移」的第六次，故两个方向一起改并由测试锁定。
  // ---------------------------------------------------------------------------

  /// 存档时以 [eventProvider] 为准覆盖该键。
  ///
  /// 用 `..[]` 覆盖而非回写状态字段：序列化是读取动作，不该有副作用。
  @override
  Map<String, dynamic> toJson() {
    return super.toJson()
      ..['completedEventIds'] = eventProvider.completedEventIds;
  }

  /// 读档后把完成集合推回 [eventProvider]。
  @override
  void applyState(GameStateProvider other) {
    super.applyState(other);
    eventProvider.restoreCompleted(completedEventIds);
  }

  /// 新局重置完成集合（[GameStateProvider.startNewGame] 只清状态层）。
  @override
  void startNewGame({Player? player}) {
    super.startNewGame(player: player);
    eventProvider.reset();
  }

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

  /// 基于回合数生成一个确定性随机源（同回合结果可复现）。
  Random rng([int? seed]) => Random(seed ?? progress.turnCount);

  // ==================== 效果摘要（事件通道与 AI 通道共用） ====================

  /// 按 before/after 真实差值生成效果摘要文本（每行一条，无变化返回空串）。
  ///
  /// 【为什么放在基类而不是各自的调用方】本项目已发生**五次**「双通道漂移」
  /// （见 `core/event_trigger_eval.dart` 文件头）。S4-5 让事件选项首次真正
  /// 可玩后，「事件选项落盘后玩家该看到什么」也成了双通道问题——若在事件
  /// 通道再抄一份摘要逻辑，就是第六次。故摘要**只此一份**：
  /// `mixin_ai.applyAiChoice`（AI 选项）与 `mixin_play.chooseWorldEventChoice`
  /// （事件选项）都调本方法。
  ///
  /// 【为什么按 before/after 求差而不是直接读 choice.effects】
  /// ① 真实 delta 才是玩家关心的（`skills.sword: 1` 落在已满级上、
  ///    `skills.sword: -5` 被 `max(0, ...)` 破底、`relations.*` 被 ±100
  ///    钳制时，读 effects 会给出与实际落盘不符的数字）；
  /// ② 写侧守卫（10-91/92）会静默跳过幽灵键，求差自动不显示它们，
  ///    无需在摘要侧再复刻一遍白名单判定（避免两处规则漂移）。
  /// [includeRejected] 为 false 时不输出「N 项效果未生效」行——供
  /// `applyChoice` 那条通道使用：它自身的返回值已含该提示，两条都输出会重复。
  String effectSummary(Player before, {bool includeRejected = true}) {
    final buf = StringBuffer();
    final goldDelta = player.gold - before.gold;
    final repDelta = player.reputation - before.reputation;
    if (goldDelta != 0) {
      buf.writeln('💰 金币 ${goldDelta > 0 ? '+' : ''}$goldDelta（${player.gold}）');
    }
    if (repDelta != 0) {
      buf.writeln('🌟 声望 ${repDelta > 0 ? '+' : ''}$repDelta（${player.reputation}）');
    }
    _writeMapDeltas(buf, before.skills, player.skills, skillLabel, '⚔️');
    _writeMapDeltas(buf, before.attributes, player.attributes, attributeLabel, '🛡️');
    _writeRelationDeltas(buf, before.relations, player.relations);
    _writeInventoryDeltas(buf, before.inventory, player.inventory);
    // Batch 10-94：被写侧守卫拒绝的效果键可见化（详见 provider 侧注释）。
    final rejected = lastRejectedEffectKeys;
    if (includeRejected && rejected.isNotEmpty) {
      buf.writeln('（其中 ${rejected.length} 项效果未生效：${rejected.join('、')}）');
    }
    return buf.toString();
  }

  /// 通用 Map<int> 数值差摘要行（金币之外的技能/属性走这条）。
  ///
  /// [label] 负责把英文键翻成中文（`skillLabel`/`attributeLabel`），
  /// 兜底仍是键本身——与 UI 侧标签函数的既有行为一致。
  void _writeMapDeltas(
    StringBuffer buf,
    Map<String, int> before,
    Map<String, int> after,
    String Function(String key) label,
    String icon,
  ) {
    for (final entry in after.entries) {
      final key = entry.key;
      final delta = entry.value - (before[key] ?? 0);
      if (delta == 0) continue;
      buf.writeln(
        '$icon ${label(key)} ${delta > 0 ? '+' : ''}$delta（${entry.value}）',
      );
    }
  }

  /// 关系差摘要行：`🤝 提利昂·兰尼斯特 +10（30）`。
  ///
  /// NPC 中文名走 [npcById]（未知 id 退回 id 本身，不抛），
  /// 与 `labels` 标签函数的兜底策略一致。
  void _writeRelationDeltas(
    StringBuffer buf,
    Map<String, int> before,
    Map<String, int> after,
  ) {
    for (final entry in after.entries) {
      final key = entry.key;
      final delta = entry.value - (before[key] ?? 0);
      if (delta == 0) continue;
      final name = npcById(key)?.name ?? key;
      buf.writeln('🤝 $name ${delta > 0 ? '+' : ''}$delta（${entry.value}）');
    }
  }

  /// 背包差摘要行：`🎒 黑面包 +2` / `🎒 黑面包 -1（已全部用尽）`。
  ///
  /// 物品中文名走 [itemName]（未知 id 退回 id 本身）——与 10-87 背包段
  /// 「中文名 + 数量」的既定口径一致，**不在此处泄漏英文 id**。
  void _writeInventoryDeltas(
    StringBuffer buf,
    List<String> before,
    List<String> after,
  ) {
    final beforeCount = <String, int>{};
    for (final id in before) {
      beforeCount[id] = (beforeCount[id] ?? 0) + 1;
    }
    final afterCount = <String, int>{};
    for (final id in after) {
      afterCount[id] = (afterCount[id] ?? 0) + 1;
    }
    for (final entry in afterCount.entries) {
      final id = entry.key;
      final delta = entry.value - (beforeCount[id] ?? 0);
      if (delta == 0) continue;
      buf.writeln('🎒 ${itemName(id)} ${delta > 0 ? '+' : ''}$delta');
    }
    // 全部用尽的物品不会出现在 afterCount 里，需单列。
    for (final entry in beforeCount.entries) {
      if (afterCount.containsKey(entry.key)) continue;
      buf.writeln('🎒 ${itemName(entry.key)} ${entry.value}（已全部用尽）');
    }
  }
}
