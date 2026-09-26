/// NPC 模型：非玩家角色。
///
/// 字段设计参考 docs/04_NPC百科.md。
library;

/// NPC 类型。
enum NpcType {
  noble, // 贵族
  soldier, // 士兵
  merchant, // 商人
  priest, // 神职人员
  scholar, // 学者
  adventurer, // 冒险者
  assassin, // 刺客
  maester, // 学士
  wildling, // 野人
  commoner, // 平民
  supernatural, // 超自然存在
}

/// NPC 模型。
class Npc {
  const Npc({
    required this.id,
    required this.name,
    required this.type,
    required this.age,
    required this.gender,
    required this.familyId,
    required this.locationId,
    required this.personality,
    required this.goals,
    required this.fears,
    required this.secrets,
    required this.relations,
    required this.skills,
    required this.faith,
    required this.isAlive,
    this.tasks = const [],
    this.mood = '',
  });

  final String id;
  final String name;
  final NpcType type;
  final int age;
  final String gender;
  final String familyId;
  final String locationId;

  /// 性格特质（如 勇敢、狡诈、虔诚）。
  final List<String> personality;

  /// 目标列表。
  final List<String> goals;

  /// 恐惧列表。
  final List<String> fears;

  /// 秘密列表。
  final List<String> secrets;

  /// 与其他 NPC 的关系（NPC ID -> 关系值 -100~100）。
  final Map<String, int> relations;

  /// 技能等级。
  final Map<String, int> skills;

  /// 信仰（如 七神、旧神、光之王）。
  final String faith;
  /// 是否存活。
  final bool isAlive;
  /// 任务链（Batch 10-15：NPC 主动委托任务，元素为「任务标题」）。
  final List<String> tasks;
  /// 心情（Batch 10-15：NPC 当前心情，影响互动叙事）。
  final String mood;

  /// 创建默认 NPC（用于测试）。
  factory Npc.defaultNpc() {
    return Npc(
      id: 'npc_nev',
      name: '奈德·史塔克',
      type: NpcType.noble,
      age: 42,
      gender: 'male',
      familyId: 'family_stark',
      locationId: 'location_winterfell',
      personality: const ['正直', '荣誉', '坚韧'],
      goals: const ['守护北境', '保护家人'],
      fears: const ['失去荣誉', '家族覆灭'],
      secrets: const ['私生子的真相'],
      relations: const {
        'npc_catelyn': 80,
        'npc_bran': 90,
      },
      skills: const {
        'sword': 8,
        'leadership': 7,
        'speech': 5,
      },
      faith: '旧神',
      isAlive: true,
    );
  }

  Npc copyWith({
    String? id,
    String? name,
    NpcType? type,
    int? age,
    String? gender,
    String? familyId,
    String? locationId,
    List<String>? personality,
    List<String>? goals,
    List<String>? fears,
    List<String>? secrets,
    Map<String, int>? relations,
    Map<String, int>? skills,
    String? faith,
    bool? isAlive,
    List<String>? tasks,
    String? mood,
  }) {
    return Npc(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      familyId: familyId ?? this.familyId,
      locationId: locationId ?? this.locationId,
      personality: personality ?? this.personality,
      goals: goals ?? this.goals,
      fears: fears ?? this.fears,
      secrets: secrets ?? this.secrets,
      relations: relations ?? this.relations,
      skills: skills ?? this.skills,
      faith: faith ?? this.faith,
      isAlive: isAlive ?? this.isAlive,
      tasks: tasks ?? this.tasks,
      mood: mood ?? this.mood,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'age': age,
      'gender': gender,
      'familyId': familyId,
      'locationId': locationId,
      'personality': personality,
      'goals': goals,
      'fears': fears,
      'secrets': secrets,
      'relations': relations,
      'skills': skills,
      'faith': faith,
      'isAlive': isAlive,
      'tasks': tasks,
      'mood': mood,
    };
  }

  factory Npc.fromJson(Map<String, dynamic> json) {
    return Npc(
      id: json['id'] as String,
      name: json['name'] as String,
      type: NpcType.values.byName(json['type'] as String),
      age: json['age'] as int,
      gender: json['gender'] as String,
      familyId: json['familyId'] as String,
      locationId: json['locationId'] as String,
      personality: (json['personality'] as List).cast<String>(),
      goals: (json['goals'] as List).cast<String>(),
      fears: (json['fears'] as List).cast<String>(),
      secrets: (json['secrets'] as List).cast<String>(),
      relations: (json['relations'] as Map).cast<String, int>(),
      skills: (json['skills'] as Map).cast<String, int>(),
      faith: json['faith'] as String,
      isAlive: json['isAlive'] as bool,
      tasks: (json['tasks'] as List?)?.cast<String>() ?? const [],
      mood: json['mood'] as String? ?? '',
    );
  }

  @override
  String toString() => 'Npc($id, $name, ${type.name})';
}