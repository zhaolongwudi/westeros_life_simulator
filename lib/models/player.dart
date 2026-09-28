/// 玩家模型：维斯特洛人生模拟器的核心实体。
///
/// 字段设计参考 docs/02_家族百科.md 与 docs/08_玩法设计.md。
library;

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
    this.hunger = 0,
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
      age: 18,
      gender: 'male',
      locationId: 'location_winterfell',
      gold: 100,
      reputation: 50,
      skills: const {
        'sword': 3,
        'archery': 2,
        'riding': 3,
        'speech': 2,
        'alchemy': 0,
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

  /// 从 JSON Map 反序列化。
  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'] as String,
      name: json['name'] as String,
      identity: PlayerIdentity.values.byName(json['identity'] as String),
      familyId: json['familyId'] as String,
      age: json['age'] as int,
      gender: json['gender'] as String,
      locationId: json['locationId'] as String,
      gold: json['gold'] as int,
      reputation: json['reputation'] as int,
      skills: (json['skills'] as Map).cast<String, int>(),
      attributes: (json['attributes'] as Map).cast<String, int>(),
      inventory: (json['inventory'] as List).cast<String>(),
      relations: (json['relations'] as Map).cast<String, int>(),
      flags: (json['flags'] as Map).cast<String, bool>(),
      health: json['health'] as int? ?? 100,
      energy: json['energy'] as int? ?? 100,
      hunger: json['hunger'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      house: json['house'] as String? ?? '',
      children: (json['children'] as List?)?.cast<String>() ?? const [],
      spouse: json['spouse'] == null
          ? null
          : SpouseDetail.fromJson(json['spouse'] as Map<String, dynamic>),
      childRearing: (json['childRearing'] as List?)
              ?.map((e) => ChildRearing.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      generationRecords: (json['generationRecords'] as List?)
              ?.map((e) => GenerationRecord.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      activeTasks: (json['activeTasks'] as List?)
              ?.map((e) => NpcTaskProgress.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  @override
  String toString() =>
      'Player($id, $name, ${identity.name}, family=$familyId, age=$age)';
}