/// 事件模型：游戏事件与事件模板。
///
/// 字段设计参考 docs/06_事件库.md。
library;

/// 事件类型。
enum EventType {
  political, // 政治
  family, // 家族
  war, // 战争
  religious, // 宗教
  economic, // 经济
  magical, // 魔法
  daily, // 日常
  adventure, // 冒险
  supernatural, // 超自然
}

/// 事件选项。
class EventChoice {
  const EventChoice({
    required this.id,
    required this.text,
    required this.requirements,
    required this.effects,
    required this.narrative,
  });

  final String id;
  final String text;

  /// 触发条件（如 需要技能 sword>=5）。
  final Map<String, int> requirements;

  /// 效果（如 gold+100, reputation-5）。
  final Map<String, int> effects;

  /// 选择后的叙事文本。
  final String narrative;

  /// 从 JSON Map 反序列化。
  factory EventChoice.fromJson(Map<String, dynamic> json) {
    return EventChoice(
      id: json['id'] as String,
      text: json['text'] as String,
      requirements: (json['requirements'] as Map).cast<String, int>(),
      effects: (json['effects'] as Map).cast<String, int>(),
      narrative: json['narrative'] as String,
    );
  }
}

/// 事件模型。
class GameEvent {
  const GameEvent({
    required this.id,
    required this.name,
    required this.type,
    required this.description,
    required this.triggerConditions,
    required this.choices,
    required this.narrative,
    required this.tags,
    required this.isOneTime,
  });

  final String id;
  final String name;
  final EventType type;
  final String description;

  /// 触发条件（如 locationId=xxx, season=winter）。
  final Map<String, String> triggerConditions;

  /// 选项列表。
  final List<EventChoice> choices;

  /// 事件叙事文本。
  final String narrative;

  /// 标签（用于筛选与统计）。
  final List<String> tags;

  /// 是否一次性事件。
  final bool isOneTime;

  /// 创建默认事件（用于测试）。
  factory GameEvent.defaultEvent() {
    return GameEvent(
      id: 'event_winter_comes',
      name: '凛冬将至',
      type: EventType.daily,
      description: '北境的冬天提前到来，食物开始短缺。',
      triggerConditions: const {
        'season': 'winter',
        'region': '北境',
      },
      choices: const [
        EventChoice(
          id: 'choice_stockpile',
          text: '囤积粮食',
          requirements: const {'gold': 50},
          effects: const {'gold': -50, 'reputation': 5},
          narrative: '你下令囤积粮食，家族度过了寒冬。',
        ),
        EventChoice(
          id: 'choice_hunt',
          text: '外出狩猎',
          requirements: const {'skills.sword': 3},
          effects: const {'gold': 20, 'reputation': 2},
          narrative: '你率队狩猎，带回大量猎物。',
        ),
      ],
      narrative: '凛冬将至，北境人民开始准备过冬。',
      tags: const ['winter', 'north', 'survival'],
      isOneTime: false,
    );
  }

  GameEvent copyWith({
    String? id,
    String? name,
    EventType? type,
    String? description,
    Map<String, String>? triggerConditions,
    List<EventChoice>? choices,
    String? narrative,
    List<String>? tags,
    bool? isOneTime,
  }) {
    return GameEvent(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      description: description ?? this.description,
      triggerConditions: triggerConditions ?? this.triggerConditions,
      choices: choices ?? this.choices,
      narrative: narrative ?? this.narrative,
      tags: tags ?? this.tags,
      isOneTime: isOneTime ?? this.isOneTime,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'description': description,
      'triggerConditions': triggerConditions,
      'choices': choices.map((c) => c.toJson()).toList(),
      'narrative': narrative,
      'tags': tags,
      'isOneTime': isOneTime,
    };
  }

  factory GameEvent.fromJson(Map<String, dynamic> json) {
    return GameEvent(
      id: json['id'] as String,
      name: json['name'] as String,
      type: EventType.values.byName(json['type'] as String),
      description: json['description'] as String,
      triggerConditions: (json['triggerConditions'] as Map).cast<String, String>(),
      choices: (json['choices'] as List)
          .map((c) => EventChoice.fromJson(c as Map<String, dynamic>))
          .toList(),
      narrative: json['narrative'] as String,
      tags: (json['tags'] as List).cast<String>(),
      isOneTime: json['isOneTime'] as bool,
    );
  }

  @override
  String toString() => 'GameEvent($id, $name, ${type.name})';
}

extension EventChoiceJson on EventChoice {
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'requirements': requirements,
      'effects': effects,
      'narrative': narrative,
    };
  }
}