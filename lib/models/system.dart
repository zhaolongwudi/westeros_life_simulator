/// 系统模型：游戏世界规则系统。
///
/// 字段设计参考 docs/05_系统百科.md。
library;

/// 系统模型。
class GameSystem {
  const GameSystem({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.rules,
    required this.features,
  });

  final String id;
  final String name;
  /// 分类：封建/家族/教会/学城/守夜人/雇佣兵/贸易/宗教/魔法/战争/经济/法律/死亡/继承/存档/AI 等。
  final String category;
  final String description;
  /// 系统规则列表。
  final List<String> rules;
  /// 系统特性列表。
  final List<String> features;

  /// 创建默认系统（用于测试）。
  factory GameSystem.defaultSystem() {
    return GameSystem(
      id: 'system_feudal',
      name: '封建体系',
      category: '封建',
      description: '维斯特洛的封建等级制度。',
      rules: const ['领主效忠国王', '国王授予领地', '领主提供军队'],
      features: const ['等级制度', '效忠关系', '领地授予'],
    );
  }

  GameSystem copyWith({
    String? id,
    String? name,
    String? category,
    String? description,
    List<String>? rules,
    List<String>? features,
  }) {
    return GameSystem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      description: description ?? this.description,
      rules: rules ?? this.rules,
      features: features ?? this.features,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'description': description,
      'rules': rules,
      'features': features,
    };
  }

  factory GameSystem.fromJson(Map<String, dynamic> json) {
    return GameSystem(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      description: json['description'] as String,
      rules: (json['rules'] as List).cast<String>(),
      features: (json['features'] as List).cast<String>(),
    );
  }

  @override
  String toString() => 'GameSystem($id, $name, $category)';
}
