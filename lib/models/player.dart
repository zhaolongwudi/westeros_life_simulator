/// 玩家模型：维斯特洛人生模拟器的核心实体。
///
/// 字段设计参考 docs/02_家族百科.md 与 docs/08_玩法设计.md。
library;

import '../data/balance_data.dart';
import '../utils/json_safe.dart';
import 'marital.dart';
import 'npc_task.dart';

/// 玩家身份类型。
enum PlayerIdentity {
  noble, // 贵族
  commoner, // 平民
  soldier, // 士兵
  merchant, // 商人
  priest, // 神职人员
  scholar, // 学者
  adventurer, // 冒险者
  assassin, // 刺客
  maester, // 学士
  wildling, // 野人
}

/// 玩家模型。
class Player {
  const Player({
    required this.id,
    required this.name,
    required this.identity,
    required this.familyId,
    required this.age,
    required this.gender,
    required this.locationId,
    required this.gold,
    required this.reputation,
    required this.skills,
    required this.attributes,
    required this.inventory,
    required this.relations,
    required this.flags,
    this.health = 100,
    this.energy = 100,
    // S13-13 ⑱：默认值必须是「不会一开局就挨饿」的开局值，与向导
    // `buildSetupPlayer`（`start_screen.dart` 的 `hunger: 60`）一致。
    // 此前为 0，而 `Player.defaultPlayer()` 未显式传 hunger ⇒ 设置页
    // 「新游戏」与各屏幕兜底的 `GameEngine()..startNewGame()` 一开局即
    // 低于 `starvationThreshold`(25)，`applyMonthlyLife` 每月 -8 健康、
    // 恢复 +2（净 -6），玩家在无提示的情况下慢性死亡。
    // S14-1：字面量 60 改为引用 `BalanceData.startingHunger`，
    // 让 balance_data 成为开局数值的唯一真相（此前此处、向导、继承
    // 三处各写一遍，改平衡要动三个地方、漏一处就复现 S13-13 ⑱）。
    this.hunger = BalanceData.startingHunger,
    this.title = '',
    this.house = '',
    this.children = const [],
    this.spouse,
    this.childRearing = const [],
    this.generationRecords = const [],
    this.activeTasks = const [],
  });

  /// 唯一标识。
  final String id;

  /// 玩家姓名。
  final String name;

  /// 身份类型。
  final PlayerIdentity identity;

  /// 所属家族 ID。
  final String familyId;

  /// 年龄（岁）。
  final int age;

  /// 性别。
  final String gender;

  /// 当前所在地点 ID。
  final String locationId;

  /// 金币数。
  final int gold;

  /// 家族声望（0-100）。
  final int reputation;

  /// 技能等级（技能名 -> 等级 0-10）。
  final Map<String, int> skills;

  /// 属性值（力量/敏捷/智力/魅力/意志/感知）。
  final Map<String, int> attributes;

  /// 背包物品 ID 列表。
  final List<String> inventory;

  /// 关系（NPC ID -> 关系值 -100~100）。
  final Map<String, int> relations;

  /// 状态标记（如 isAlive、isMarried 等）。
  final Map<String, bool> flags;

  /// 健康值（0-100，0 死亡）。
  final int health;

  /// 精力值（0-100，进行活动消耗，休息恢复）。
  final int energy;

  /// 饱食度（0-100，越高越不饿；低于阈值会有减益）。
  final int hunger;

  /// 头衔（如 '爵士'、'守夜人总司令'，随声望/事件晋升）。
  final String title;
  /// 家族别名/玩家姓氏（如 '史塔克'、'坦格利安'；自由民可自定义）。
  final String house;
  /// 子女 ID 列表（Batch 10-14 多世代：继承人从子女中产生）。
  final List<String> children;
  /// 配偶详情（Batch 10-17 婚姻系统；null 表示未婚）。
  final SpouseDetail? spouse;
  /// 子女培养档案（Batch 10-17：培养方向/督导/送学）。
  final List<ChildRearing> childRearing;
  /// 世代谱系（Batch 10-17：家族树多代展示）。
  final List<GenerationRecord> generationRecords;
  /// 进行中的 NPC 任务（Batch 10-18：多步骤任务实例）。
  final List<NpcTaskProgress> activeTasks;

  /// 创建默认玩家（用于测试与初始化）。
  factory Player.defaultPlayer() {
    return Player(
      id: 'player_default',
      name: '无名者',
      identity: PlayerIdentity.noble,
      familyId: 'family_stark',
      // S14-1：三项开局值改为引用 BalanceData（此前是写死的字面量，
      // 改 balance_data 里的对应常量不会有任何效果 —— 那正是「摆设常量」）。
      age: BalanceData.defaultAge,
      gender: 'male',
      locationId: 'location_winterfell',
      gold: BalanceData.defaultGold,
      reputation: BalanceData.defaultReputation,
      skills: const {
        'sword': 3,
        'archery': 2,
        'riding': 3,
        'speech': 2,
        'alchemy': 0,
        // S4-3c：magic 必须在初始技能表内，否则 `train()` 拒绝训练
        // （未知技能直接返回「你从未学过」），而事件库有 3 个
        // `skills.magic: 5` 门槛的选项会因此**永久不可选**。
        // 与 alchemy 同先例：初始 0 级、可训练成长。
        'magic': 0,
        // S12-12：`stealth` 同理必须在初始技能表内。取证：
        // `event_data.dart` 的 `event_road_bandits` / `choice_sneak_past`
        // （「绕道潜行」）门槛是 `skills.stealth: 2`，而 `train()` 对
        // `skills` 表里没有的键一律回「你从未学过」，且全库**没有任何
        // 事件或指令会给予 stealth**（`grep stealth lib/` 只命中白名单、
        // 标签表和该门槛本身）⇒ 该选项此前**永久不可选**，纯摆设。
        // 初始 0 级 + 可训练，与 magic/alchemy 完全同构。
        'stealth': 0,
      },
      attributes: const {
        'strength': 5,
        'agility': 5,
        'intelligence': 5,
        'charisma': 5,
        'willpower': 5,
        'perception': 5,
      },
      inventory: const [],
      relations: const {},
      flags: const {
        'isAlive': true,
        'isMarried': false,
        'isExiled': false,
      },
    );
  }

  /// 不可变更新：返回新实例。
  Player copyWith({
    String? id,
    String? name,
    PlayerIdentity? identity,
    String? familyId,
    int? age,
    String? gender,
    String? locationId,
    int? gold,
    int? reputation,
    Map<String, int>? skills,
    Map<String, int>? attributes,
    List<String>? inventory,
    Map<String, int>? relations,
    Map<String, bool>? flags,
    int? health,
    int? energy,
    int? hunger,
    String? title,
    String? house,
    List<String>? children,
    SpouseDetail? spouse,
    bool clearSpouse = false,
    List<ChildRearing>? childRearing,
    List<GenerationRecord>? generationRecords,
    List<NpcTaskProgress>? activeTasks,
  }) {
    // 显式清空配偶（离婚/丧偶）：clearSpouse=true 时置 null
    final spouseValue = clearSpouse ? null : (spouse ?? this.spouse);
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      identity: identity ?? this.identity,
      familyId: familyId ?? this.familyId,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      locationId: locationId ?? this.locationId,
      gold: gold ?? this.gold,
      reputation: reputation ?? this.reputation,
      skills: skills ?? this.skills,
      attributes: attributes ?? this.attributes,
      inventory: inventory ?? this.inventory,
      relations: relations ?? this.relations,
      flags: flags ?? this.flags,
      health: health ?? this.health,
      energy: energy ?? this.energy,
      hunger: hunger ?? this.hunger,
      title: title ?? this.title,
      house: house ?? this.house,
      children: children ?? this.children,
      spouse: spouseValue,
      childRearing: childRearing ?? this.childRearing,
      generationRecords: generationRecords ?? this.generationRecords,
      activeTasks: activeTasks ?? this.activeTasks,
    );
  }

  /// 序列化为 JSON Map（用于存档）。
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'identity': identity.name,
      'familyId': familyId,
      'age': age,
      'gender': gender,
      'locationId': locationId,
      'gold': gold,
      'reputation': reputation,
      'skills': skills,
      'attributes': attributes,
      'inventory': inventory,
      'relations': relations,
      'flags': flags,
      'health': health,
      'energy': energy,
      'hunger': hunger,
      'title': title,
      'house': house,
      'children': children,
      'spouse': spouse?.toJson(),
      'childRearing': childRearing.map((e) => e.toJson()).toList(),
      'generationRecords': generationRecords.map((e) => e.toJson()).toList(),
      'activeTasks': activeTasks.map((e) => e.toJson()).toList(),
    };
  }

  /// 从 JSON Map 反序列化（防御式：字段缺失/类型错一律回落默认值，绝不抛）。
  ///
  /// Batch 10-26 · M1-T02。旧存档缺 marriage/generation/tasks 等后加字段时
  /// 正常加载，新字段取默认值；`gold` 给成字符串等错误类型亦不抛。
  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: safeStr(json, 'id', fallback: 'player_unknown'),
      name: safeStr(json, 'name', fallback: '无名者'),
      identity: safeEnum(PlayerIdentity.values, json['identity'], PlayerIdentity.noble),
      familyId: safeStr(json, 'familyId'),
      age: safeInt(json, 'age', fallback: 18),
      gender: safeStr(json, 'gender', fallback: 'male'),
      locationId: safeStr(json, 'locationId'),
      gold: safeInt(json, 'gold'),
      reputation: safeInt(json, 'reputation', fallback: 50),
      skills: safeIntMap(json, 'skills'),
      attributes: safeIntMap(json, 'attributes'),
      inventory: safeStrList(json, 'inventory'),
      relations: safeIntMap(json, 'relations'),
      flags: safeBoolMap(json, 'flags'),
      health: safeInt(json, 'health', fallback: 100),
      energy: safeInt(json, 'energy', fallback: 100),
      // S13-13 ⑱：与构造器默认值同源。health/energy 都回落满值，
      // hunger 若回落 0 会让旧档「读档即挨饿」（0 < 25）。
      hunger: safeInt(json, 'hunger', fallback: 60),
      title: safeStr(json, 'title'),
      house: safeStr(json, 'house'),
      children: safeStrList(json, 'children'),
      spouse: safeObject(json['spouse'], SpouseDetail.fromJson),
      childRearing: safeObjectList(json, 'childRearing', ChildRearing.fromJson),
      generationRecords:
          safeObjectList(json, 'generationRecords', GenerationRecord.fromJson),
      activeTasks: safeObjectList(json, 'activeTasks', NpcTaskProgress.fromJson),
    );
  }

  @override
  String toString() =>
      'Player($id, $name, ${identity.name}, family=$familyId, age=$age)';
}