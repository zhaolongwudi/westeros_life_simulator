/// 家族模型：维斯特洛 26 大贵族家族。
///
/// 字段设计参考 docs/02_家族百科.md。
library;

/// 家族规模等级。
enum FamilyScale {
  great, // 大家族（史塔克、兰尼斯特等）
  minor, // 小家族
  household, // 家户
}

/// 家族模型。
class Family {
  const Family({
    required this.id,
    required this.name,
    required this.motto,
    required this.seat,
    required this.scale,
    required this.population,
    required this.army,
    required this.goldReserve,
    required this.influence,
    required this.relations,
    required this.secrets,
    required this.traits,
  });

  /// 唯一标识（如 family_stark）。
  final String id;

  /// 家族名（如 史塔克）。
  final String name;

  /// 族语（如 凛冬将至）。
  final String motto;

  /// 家族领地/城堡 ID。
  final String seat;

  /// 家族规模。
  final FamilyScale scale;

  /// 家族人口。
  final int population;

  /// 军队规模。
  final int army;

  /// 金库储备。
  final int goldReserve;

  /// 政治影响力（0-100）。
  final int influence;

  /// 与其他家族的关系（家族 ID -> 关系值 -100~100）。
  final Map<String, int> relations;

  /// 家族秘密列表。
  final List<String> secrets;

  /// 家族特质（如 坚韧、狡诈、虔诚）。
  final List<String> traits;

  /// 创建默认家族（用于测试）。
  factory Family.defaultFamily() {
    return Family(
      id: 'family_stark',
      name: '史塔克',
      motto: '凛冬将至',
      seat: 'location_winterfell',
      scale: FamilyScale.great,
      population: 5000,
      army: 1000,
      goldReserve: 50000,
      influence: 70,
      relations: const {
        'family_lannister': -30,
        'family_baratheon': 20,
        'family_tully': 40,
      },
      secrets: const ['史塔克家族的血脉秘密'],
      traits: const ['坚韧', '忠诚', '荣誉'],
    );
  }

  Family copyWith({
    String? id,
    String? name,
    String? motto,
    String? seat,
    FamilyScale? scale,
    int? population,
    int? army,
    int? goldReserve,
    int? influence,
    Map<String, int>? relations,
    List<String>? secrets,
    List<String>? traits,
  }) {
    return Family(
      id: id ?? this.id,
      name: name ?? this.name,
      motto: motto ?? this.motto,
      seat: seat ?? this.seat,
      scale: scale ?? this.scale,
      population: population ?? this.population,
      army: army ?? this.army,
      goldReserve: goldReserve ?? this.goldReserve,
      influence: influence ?? this.influence,
      relations: relations ?? this.relations,
      secrets: secrets ?? this.secrets,
      traits: traits ?? this.traits,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'motto': motto,
      'seat': seat,
      'scale': scale.name,
      'population': population,
      'army': army,
      'goldReserve': goldReserve,
      'influence': influence,
      'relations': relations,
      'secrets': secrets,
      'traits': traits,
    };
  }

  factory Family.fromJson(Map<String, dynamic> json) {
    return Family(
      id: json['id'] as String,
      name: json['name'] as String,
      motto: json['motto'] as String,
      seat: json['seat'] as String,
      scale: FamilyScale.values.byName(json['scale'] as String),
      population: json['population'] as int,
      army: json['army'] as int,
      goldReserve: json['goldReserve'] as int,
      influence: json['influence'] as int,
      relations: (json['relations'] as Map).cast<String, int>(),
      secrets: (json['secrets'] as List).cast<String>(),
      traits: (json['traits'] as List).cast<String>(),
    );
  }

  @override
  String toString() => 'Family($id, $name, ${scale.name})';
}