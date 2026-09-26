/// 婚姻与家族培养模型（Batch 10-17）。
///
/// 将配偶详情、子女培养、世代谱系封装为独立可序列化模型，
/// 避免塞进 Player.flags（坑 16：flags 只存 bool）。
library;

/// 配偶身世类型（影响婚礼开销与联姻声望）。
enum SpouseOrigin {
  noble, // 贵族联姻（声望 +10，聘礼重）
  commoner, // 平民（开销低）
  merchant, // 商人（带来金币嫁妆）
  warrior, // 战士（婚后家宅安宁）
}

/// 配偶详情。
class SpouseDetail {
  const SpouseDetail({
    required this.name,
    required this.origin,
    required this.marriedYear,
    this.familyId = '',
  });

  /// 配偶姓名。
  final String name;

  /// 身世类型。
  final SpouseOrigin origin;

  /// 结婚年份（用于「结婚 N 年」叙事）。
  final int marriedYear;

  /// 配偶家族 ID（贵族联姻有值）。
  final String familyId;

  /// 生育子女数标记（结婚后随月度增长，最多 4 个）。
  int get childLimit {
    return switch (origin) {
      SpouseOrigin.noble => 4,
      SpouseOrigin.commoner => 3,
      SpouseOrigin.merchant => 3,
      SpouseOrigin.warrior => 2,
    };
  }

  /// 婚礼开销（金币）。
  int get weddingCost {
    return switch (origin) {
      SpouseOrigin.noble => 80,
      SpouseOrigin.commoner => 20,
      SpouseOrigin.merchant => 40,
      SpouseOrigin.warrior => 30,
    };
  }

  /// 婚后声望加值。
  int get reputationBonus {
    return switch (origin) {
      SpouseOrigin.noble => 10,
      SpouseOrigin.commoner => 0,
      SpouseOrigin.merchant => 3,
      SpouseOrigin.warrior => 2,
    };
  }

  /// 商人配偶带来的嫁妆。
  int get dowry {
    return origin == SpouseOrigin.merchant ? 60 : 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'origin': origin.name,
      'marriedYear': marriedYear,
      'familyId': familyId,
    };
  }

  factory SpouseDetail.fromJson(Map<String, dynamic> json) {
    return SpouseDetail(
      name: json['name'] as String,
      origin: SpouseOrigin.values.byName(json['origin'] as String),
      marriedYear: json['marriedYear'] as int,
      familyId: json['familyId'] as String? ?? '',
    );
  }
}

/// 子女培养档案（记录培养路线与进度）。
class ChildRearing {
  const ChildRearing({
    required this.name,
    this.focus = '',
    this.tutored = false,
    this.sentToSchool = false,
    this.reputationGain = 0,
  });

  /// 子女姓名（与 player.children 对应）。
  final String name;

  /// 培养方向（如 'sword' / 'politics' / 'speech'）。
  final String focus;

  /// 是否已亲自督导（一次性提升师长声望）。
  final bool tutored;

  /// 是否已送往学城/骑士团培养（长期增益）。
  final bool sentToSchool;

  /// 培养带来的声望积累。
  final int reputationGain;

  ChildRearing copyWith({
    String? name,
    String? focus,
    bool? tutored,
    bool? sentToSchool,
    int? reputationGain,
  }) {
    return ChildRearing(
      name: name ?? this.name,
      focus: focus ?? this.focus,
      tutored: tutored ?? this.tutored,
      sentToSchool: sentToSchool ?? this.sentToSchool,
      reputationGain: reputationGain ?? this.reputationGain,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'focus': focus,
      'tutored': tutored,
      'sentToSchool': sentToSchool,
      'reputationGain': reputationGain,
    };
  }

  factory ChildRearing.fromJson(Map<String, dynamic> json) {
    return ChildRearing(
      name: json['name'] as String,
      focus: json['focus'] as String? ?? '',
      tutored: json['tutored'] as bool? ?? false,
      sentToSchool: json['sentToSchool'] as bool? ?? false,
      reputationGain: json['reputationGain'] as int? ?? 0,
    );
  }
}

/// 世代谱系条目（家族树多代展示）。
class GenerationRecord {
  const GenerationRecord({
    required this.generation,
    required this.name,
    required this.reignYears,
    required this.title,
    this.achievement = '',
  });

  /// 第几代（1 起）。
  final int generation;

  /// 家主姓名。
  final String name;

  /// 在位年份（从-到，字符串展示）。
  final String reignYears;

  /// 在位头衔/身份。
  final String title;

  /// 在位成就（简短）。
  final String achievement;

  Map<String, dynamic> toJson() {
    return {
      'generation': generation,
      'name': name,
      'reignYears': reignYears,
      'title': title,
      'achievement': achievement,
    };
  }

  factory GenerationRecord.fromJson(Map<String, dynamic> json) {
    return GenerationRecord(
      generation: json['generation'] as int,
      name: json['name'] as String,
      reignYears: json['reignYears'] as String,
      title: json['title'] as String,
      achievement: json['achievement'] as String? ?? '',
    );
  }
}