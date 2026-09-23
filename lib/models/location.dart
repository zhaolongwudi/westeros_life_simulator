/// 地点模型：维斯特洛及已知世界的地点。
///
/// 字段设计参考 docs/03_地点百科.md。
library;

/// 地点类型。
enum LocationType {
  castle, // 城堡
  city, // 城市
  village, // 村庄
  fort, // 要塞
  temple, // 神庙
  academy, // 学院
  tavern, // 酒馆
  market, // 市场
  wilderness, // 荒野
  supernatural, // 超自然领域
  unknown, // 未知世界
}

/// 地点模型。
class Location {
  const Location({
    required this.id,
    required this.name,
    required this.type,
    required this.region,
    required this.dangerLevel,
    required this.population,
    required this.features,
    required this.governorId,
    required this.connectedTo,
    required this.description,
  });

  final String id;
  final String name;
  final LocationType type;

  /// 所属区域（如 北境、河间地、维斯特洛、厄索斯、未知世界）。
  final String region;

  /// 危险度（0-10，0 最安全，10 最危险）。
  final int dangerLevel;

  /// 人口。
  final int population;

  /// 特色（如 龙石岛、长城、学城）。
  final List<String> features;

  /// 统治者/管理者 NPC ID。
  final String? governorId;

  /// 可前往的地点 ID 列表。
  final List<String> connectedTo;

  /// 描述。
  final String description;

  /// 创建默认地点（用于测试）。
  factory Location.defaultLocation() {
    return Location(
      id: 'location_winterfell',
      name: '临冬城',
      type: LocationType.castle,
      region: '北境',
      dangerLevel: 3,
      population: 2000,
      features: const ['史塔克家族领地', '临冬城', '旧神祭坛'],
      governorId: 'npc_nev',
      connectedTo: const [
        'location_white_harbor',
        'location_barrowtowns',
      ],
      description: '史塔克家族世代居住的城堡，北境之王。',
    );
  }

  Location copyWith({
    String? id,
    String? name,
    LocationType? type,
    String? region,
    int? dangerLevel,
    int? population,
    List<String>? features,
    String? governorId,
    List<String>? connectedTo,
    String? description,
  }) {
    return Location(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      region: region ?? this.region,
      dangerLevel: dangerLevel ?? this.dangerLevel,
      population: population ?? this.population,
      features: features ?? this.features,
      governorId: governorId ?? this.governorId,
      connectedTo: connectedTo ?? this.connectedTo,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'region': region,
      'dangerLevel': dangerLevel,
      'population': population,
      'features': features,
      'governorId': governorId,
      'connectedTo': connectedTo,
      'description': description,
    };
  }

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      id: json['id'] as String,
      name: json['name'] as String,
      type: LocationType.values.byName(json['type'] as String),
      region: json['region'] as String,
      dangerLevel: json['dangerLevel'] as int,
      population: json['population'] as int,
      features: (json['features'] as List).cast<String>(),
      governorId: json['governorId'] as String?,
      connectedTo: (json['connectedTo'] as List).cast<String>(),
      description: json['description'] as String,
    );
  }

  @override
  String toString() => 'Location($id, $name, ${type.name})';
}