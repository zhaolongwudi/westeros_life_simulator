/// 游戏状态管理：管理玩家状态、游戏进度、当前事件。
///
/// 使用 ChangeNotifier + provider 实现响应式状态管理。
library;

import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/event.dart';
import '../models/player.dart';

/// 游戏进度：时间、季节、纪元。
class GameProgress {
  const GameProgress({
    required this.year,
    required this.month,
    required this.season,
    required this.era,
    required this.turnCount,
  });

  /// 当前年份（征服纪元）。
  final int year;

  /// 当前月份（1-12）。
  final int month;

  /// 当前季节。
  final String season;

  /// 当前纪元。
  final String era;

  /// 回合计数。
  final int turnCount;

  /// 创建默认进度（征服纪元 283 年，劳勃统治初期）。
  factory GameProgress.defaultProgress() {
    return GameProgress(
      year: 283,
      month: 3,
      season: 'spring',
      era: '征服纪元',
      turnCount: 0,
    );
  }

  /// 推进一个月。
  GameProgress advanceMonth() {
    final newMonth = month >= 12 ? 1 : month + 1;
    final newYear = newMonth == 1 ? year + 1 : year;
    final newSeason = seasonForMonth(newMonth);
    return GameProgress(
      year: newYear,
      month: newMonth,
      season: newSeason,
      era: era,
      turnCount: turnCount + 1,
    );
  }

  /// 根据月份计算季节。
  static String seasonForMonth(int month) {
    if (month >= 3 && month <= 5) return 'spring';
    if (month >= 6 && month <= 8) return 'summer';
    if (month >= 9 && month <= 11) return 'autumn';
    return 'winter';
  }

  Map<String, dynamic> toJson() {
    return {
      'year': year,
      'month': month,
      'season': season,
      'era': era,
      'turnCount': turnCount,
    };
  }

  factory GameProgress.fromJson(Map<String, dynamic> json) {
    return GameProgress(
      year: json['year'] as int,
      month: json['month'] as int,
      season: json['season'] as String,
      era: json['era'] as String,
      turnCount: json['turnCount'] as int,
    );
  }
}

/// 游戏状态管理。
class GameStateProvider extends ChangeNotifier {
  GameStateProvider({
    Player? player,
    GameProgress? progress,
    List<GameEvent>? history,
    GameEvent? currentEvent,
    bool isGameActive = false,
    bool isGameOver = false,
  })  : _player = player ?? Player.defaultPlayer(),
        _progress = progress ?? GameProgress.defaultProgress(),
        _history = history ?? <GameEvent>[],
        _currentEvent = currentEvent,
        _isGameActive = isGameActive,
        _isGameOver = isGameOver;

  Player _player;
  GameProgress _progress;
  List<GameEvent> _history;
  GameEvent? _currentEvent;
  bool _isGameActive = false;
  bool _isGameOver = false;

  /// 当前玩家。
  Player get player => _player;

  /// 游戏进度。
  GameProgress get progress => _progress;

  /// 事件历史。
  List<GameEvent> get history => List.unmodifiable(_history);

  /// 当前事件。
  GameEvent? get currentEvent => _currentEvent;

  /// 游戏是否进行中。
  bool get isGameActive => _isGameActive;

  /// 游戏是否结束。
  bool get isGameOver => _isGameOver;

  /// 开始新游戏。
  void startNewGame({Player? player}) {
    _player = player ?? Player.defaultPlayer();
    _progress = GameProgress.defaultProgress();
    _history = <GameEvent>[];
    _currentEvent = null;
    _isGameActive = true;
    _isGameOver = false;
    notifyListeners();
  }

  /// 推进时间（一个月）。
  void advanceTime() {
    if (!_isGameActive || _isGameOver) return;
    _progress = _progress.advanceMonth();
    _player = _player.copyWith(age: _player.age + (_progress.month == 1 ? 1 : 0));
    notifyListeners();
  }

  /// 设置当前事件。
  void setCurrentEvent(GameEvent? event) {
    _currentEvent = event;
    notifyListeners();
  }

  /// 应用事件选项效果。
  void applyChoice(EventChoice choice) {
    if (!_isGameActive || _isGameOver) return;

    // 应用效果
    _player = applyEffects(_player, choice.effects);

    // 记录历史
    if (_currentEvent != null) {
      _history.add(_currentEvent!);
    }
    _currentEvent = null;

    // 推进时间
    advanceTime();

    // 检查游戏结束条件
    _checkGameOver();

    notifyListeners();
  }

  /// 将效果 Map 应用到玩家身上，返回新玩家。
  ///
  /// 支持键：gold / reputation / skills.<name> / attributes.<name> /
  /// relations.<npcId> / flags.<flagName>（value>0 置真，<=0 清除）。
  /// 供事件选项（[applyChoice]）与 AI 生成选项共用。
  Player applyEffects(Player player, Map<String, int> effects) {
    var newPlayer = player;
    for (final entry in effects.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key == 'gold') {
        newPlayer = newPlayer.copyWith(gold: max(0, newPlayer.gold + value));
      } else if (key == 'reputation') {
        newPlayer = newPlayer.copyWith(
          reputation: (newPlayer.reputation + value).clamp(0, 100),
        );
      } else if (key.startsWith('skills.')) {
        final skillName = key.substring(7);
        final newSkills = Map<String, int>.from(newPlayer.skills);
        newSkills[skillName] = (newSkills[skillName] ?? 0) + value;
        newPlayer = newPlayer.copyWith(skills: newSkills);
      } else if (key.startsWith('attributes.')) {
        final attrName = key.substring(11);
        final newAttrs = Map<String, int>.from(newPlayer.attributes);
        newAttrs[attrName] = (newAttrs[attrName] ?? 0) + value;
        newPlayer = newPlayer.copyWith(attributes: newAttrs);
      } else if (key.startsWith('relations.')) {
        final npcId = key.substring(10);
        final newRels = Map<String, int>.from(newPlayer.relations);
        newRels[npcId] = (newRels[npcId] ?? 0) + value;
        newPlayer = newPlayer.copyWith(relations: newRels);
      } else if (key.startsWith('flags.')) {
        final flagName = key.substring(6);
        final newFlags = Map<String, bool>.from(newPlayer.flags);
        newFlags[flagName] = value > 0;
        newPlayer = newPlayer.copyWith(flags: newFlags);
      } else if (key.startsWith('inventory.')) {
        final itemId = key.substring(10);
        final newInv = List<String>.from(newPlayer.inventory);
        if (value > 0) {
          // 获得物品（数量倍）
          for (var i = 0; i < value; i++) {
            newInv.add(itemId);
          }
        } else {
          // 消耗/丢弃
          var toRemove = -value;
          while (toRemove > 0) {
            final idx = newInv.indexOf(itemId);
            if (idx < 0) break;
            newInv.removeAt(idx);
            toRemove--;
          }
        }
        newPlayer = newPlayer.copyWith(inventory: newInv);
      } else if (key == 'health') {
        newPlayer = newPlayer.copyWith(
          health: (newPlayer.health + value).clamp(0, 100),
        );
      } else if (key == 'energy') {
        newPlayer = newPlayer.copyWith(
          energy: (newPlayer.energy + value).clamp(0, 100),
        );
      } else if (key == 'hunger') {
        newPlayer = newPlayer.copyWith(
          hunger: (newPlayer.hunger + value).clamp(0, 100),
        );
      }
    }
    return newPlayer;
  }

  /// 检查游戏结束条件。
  void _checkGameOver() {
    final isAlive = _player.flags['isAlive'] ?? true;
    if (!isAlive) {
      _isGameOver = true;
      _isGameActive = false;
    }
  }

  /// 更新玩家属性。
  void updatePlayer(Player player) {
    _player = player;
    notifyListeners();
  }

  /// 从另一个状态复制全部字段（用于加载存档/导入）。
  void applyState(GameStateProvider other) {
    _player = other._player;
    _progress = other._progress;
    _history = List<GameEvent>.from(other._history);
    _currentEvent = other._currentEvent;
    _isGameActive = other._isGameActive;
    _isGameOver = other._isGameOver;
    notifyListeners();
  }

  /// 序列化游戏状态。
  Map<String, dynamic> toJson() {
    return {
      'player': _player.toJson(),
      'progress': _progress.toJson(),
      'history': _history.map((e) => e.toJson()).toList(),
      'currentEvent': _currentEvent?.toJson(),
      'isGameActive': _isGameActive,
      'isGameOver': _isGameOver,
    };
  }

  /// 从 JSON 反序列化。
  factory GameStateProvider.fromJson(Map<String, dynamic> json) {
    return GameStateProvider(
      player: Player.fromJson(json['player'] as Map<String, dynamic>),
      progress: GameProgress.fromJson(json['progress'] as Map<String, dynamic>),
      history: (json['history'] as List)
          .map((e) => GameEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
      currentEvent: json['currentEvent'] == null
          ? null
          : GameEvent.fromJson(json['currentEvent'] as Map<String, dynamic>),
      isGameActive: json['isGameActive'] as bool? ?? false,
      isGameOver: json['isGameOver'] as bool? ?? false,
    );
  }
}
