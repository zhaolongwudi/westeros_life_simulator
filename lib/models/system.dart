/// 系统模型：游戏世界规则系统。
///
/// 字段设计参考 docs/05_系统百科.md。
///
/// S4-1（P1-09）：新增 [monthlyEffects] —— 此前 73 个系统的 `rules` /
/// `features` **不参与任何计算**（69 条是「XX规则/XX代价/XX传承」占位），
/// `applyMonthlySystems` 只做家族折金币 + 危险度扣钱 + 冬天减益 + 季度
/// 抽一条文案，等于「73 个系统只有 4 条硬编码规则是真的」。本字段让系统
/// 能挂**月度效果**，键名复用事件/AI 通道同一套效果键体系
/// （见 `game_state_provider.applyEffects`）。
library;

import '../utils/json_safe.dart';

/// 系统模型。
class GameSystem {
  const GameSystem({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.rules,
    required this.features,
    this.monthlyEffects = const <String, int>{},
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

  /// **S4-1（P1-09）**：系统挂载期间每月自动结算的效果（键值同事件 `effects`）。
  ///
  /// 缺省 `{}` 表示「仅作世界观背景，无月度结算」——73 个系统中绝大多数
  /// 属此类，是**诚实标注**而非数据缺失（见 docs/05_系统百科.md §四）。
  ///
  /// 【为什么复用效果键而不是自定义 schema】效果键的合法集合、边界钳制、
  /// 幽灵键守卫已全部实现在 `game_state_provider.applyEffects`，另起一套
  /// 就会重演「两条 applyEffects 漂移」的老问题（batch10-95/10-90）。
  ///
  /// 【数值量级参照现有内容，避免与月度恢复打架】`sleptWellChance 0.7` ×
  /// (`sleepEnergyBase 15` + 均值 `sleepEnergyVariance 7.5`) ≈ **每回合净回
  /// 15 精力**，故 `energy` 月度负担不应超过 10~12，否则等于软性锁死
  /// 守夜人路线；事件里 `energy` 常见档位为 -5/-10/-15。
  final Map<String, int> monthlyEffects;

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
    Map<String, int>? monthlyEffects,
  }) {
    return GameSystem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      description: description ?? this.description,
      rules: rules ?? this.rules,
      features: features ?? this.features,
      monthlyEffects: monthlyEffects ?? this.monthlyEffects,
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
      'monthlyEffects': monthlyEffects,
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
      // S4-1：老存档 / 旧镜像里没有这个键 → `{}`（即「无月度结算」），
      // 不能用 `as Map` 强转，否则历史存档一读就崩。
      monthlyEffects: safeIntMap(json, 'monthlyEffects'),
    );
  }

  /// 是否挂了月度结算（S4-1：供面板与测试区分「背景系统」/「机制化系统」）。
  bool get hasMonthlyEffects => monthlyEffects.isNotEmpty;

  @override
  String toString() => 'GameSystem($id, $name, $category)';
}
