/// 游戏状态管理：管理玩家状态、游戏进度、当前事件。
///
/// 使用 ChangeNotifier + provider 实现响应式状态管理。
library;

import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/balance_data.dart';
import '../models/event.dart';
import '../models/player.dart';
import '../utils/json_safe.dart';

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
      year: safeInt(json, 'year', fallback: 283),
      month: safeInt(json, 'month', fallback: 3),
      season: safeStr(json, 'season', fallback: 'spring'),
      era: safeStr(json, 'era', fallback: '征服纪元'),
      turnCount: safeInt(json, 'turnCount'),
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
    int droppedHistoryCount = 0,
  })  : _player = player ?? Player.defaultPlayer(),
        _progress = progress ?? GameProgress.defaultProgress(),
        _history = history ?? <GameEvent>[],
        _currentEvent = currentEvent,
        _isGameActive = isGameActive,
        _isGameOver = isGameOver,
        _droppedHistoryCount = droppedHistoryCount < 0 ? 0 : droppedHistoryCount;

  Player _player;
  GameProgress _progress;
  List<GameEvent> _history;
  GameEvent? _currentEvent;
  bool _isGameActive = false;
  bool _isGameOver = false;

  /// 事件历史上限（Batch 10-27 · M2）。
  ///
  /// 旧实现无上限：history 只在 [applyChoice] 里无限追加，每回合又全量
  /// 序列化进存档，几百回合后存档体积与写盘延迟线性膨胀。截断为最近
  /// [kHistoryLimit] 条；被挤出的条数记在 [droppedHistoryCount]，
  /// 由 [historySummaryLine] 生成一行摘要（不丢"发生过什么类型的事"）。
  static const int kHistoryLimit = 200;

  /// 已被截断丢弃的事件条数（可跨存档持久化，见 toJson/fromJson）。
  int _droppedHistoryCount = 0;

  /// 累计被截断丢弃的事件条数。
  int get droppedHistoryCount => _droppedHistoryCount;

  /// 截断提示行（无丢弃时返回空串）。
  ///
  /// 供 UI/AI 在历史开头展示，避免玩家以为"这些事没发生过"。
  String historySummaryLine() {
    if (_droppedHistoryCount == 0) return '';
    return '📜 早期记录已归档（$kHistoryLimit 条上限），'
        '此前 $droppedHistoryCount 条事件不再逐条留存。';
  }

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

  /// 追加一条事件到历史并执行环形截断（Batch 10-27 · M2）。
  ///
  /// 保留最近 [kHistoryLimit] 条，超出部分从头部丢弃并累加计数。
  /// 唯一写 `_history` 的入口，保证任何路径（含 fromJson 回填）都不越界。
  void _appendHistory(GameEvent event) {
    _history.add(event);
    while (_history.length > kHistoryLimit) {
      _history.removeAt(0);
      _droppedHistoryCount++;
    }
  }

  /// 开始新游戏。
  void startNewGame({Player? player}) {
    _player = player ?? Player.defaultPlayer();
    _progress = GameProgress.defaultProgress();
    _history = <GameEvent>[];
    _droppedHistoryCount = 0;
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

    // 记录历史（经 _appendHistory 执行环形截断）
    final pending = _currentEvent;
    if (pending != null) {
      _appendHistory(pending);
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
      } else if (key.startsWith('relations.')) {
        final npcId = key.substring(10);
        final newRels = Map<String, int>.from(newPlayer.relations);
        // Batch 10-90：好感度钳制 ±100，与 `event_service.applyEffects`
        // 的同名分支对齐（那边早有 `.clamp(-100, 100)`，这边一直漏了——
        // 两处实现不一致，AI 选项走本路径写 `relations.npc_tyrion: 9999`
        // 会让关系值无上界累积：① `npcRelationLabel` 的六档阈值（±20/40/
        // 60/80）在越界后完全失效；② `mixin_npc_interact` 的示好成本公式
        // `(5 + (100 - rel) ~/ 20).clamp(3, 12)` 在 rel > 100 时已无意义；
        // ③ `ai_service` 的 ±20 敌友判定同样失去区分度。
        // 边界值 ±100 与 `npcRelationLabel` 的「挚友 / 敌对」档位、
        // 以及 10-83 关系段预算的取值域天然对齐。
        newRels[npcId] =
            ((newRels[npcId] ?? 0) + value).clamp(-BalanceData.kRelationClamp,
                BalanceData.kRelationClamp);
        newPlayer = newPlayer.copyWith(relations: newRels);
      } else if (key.startsWith('skills.')) {
        final skillName = key.substring(7);
        final newSkills = Map<String, int>.from(newPlayer.skills);
        // Batch 10-90：防负数破底（与 gold 的 `max(0, ...)` 同策略）——
        // 技能是「等级」，负等级在 `train` 的门槛判定与 prompt 展示里都无意义。
        newSkills[skillName] = max(0, (newSkills[skillName] ?? 0) + value);
        newPlayer = newPlayer.copyWith(skills: newSkills);
      } else if (key.startsWith('attributes.')) {
        final attrName = key.substring(11);
        final newAttrs = Map<String, int>.from(newPlayer.attributes);
        newAttrs[attrName] = max(0, (newAttrs[attrName] ?? 0) + value);
        newPlayer = newPlayer.copyWith(attributes: newAttrs);
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
  /// 结束游戏（置 isGameOver，停止时间推进）。
  ///
  /// 供家族血脉断绝等全局终结场景调用。
  void endGame() {
    _isGameOver = true;
    _isGameActive = false;
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
    _droppedHistoryCount = other._droppedHistoryCount;
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
      'droppedHistoryCount': _droppedHistoryCount,
    };
  }

  /// 从 JSON 反序列化（防御式：字段缺失/类型错一律回落默认值，绝不抛）。
  ///
  /// Batch 10-26 · M1-T02。player/progress 整块缺失时退化为默认玩家与
  /// 默认进度，保证半残存档仍能进游戏而不是崩在加载页。
  factory GameStateProvider.fromJson(Map<String, dynamic> json) {
    final parsed = safeObjectList(json, 'history', GameEvent.fromJson);
    // 旧存档/外部存档可能带超长 history：同样按上限截断，
    // 被挤出的条数累加到 droppedHistoryCount，避免读档即越界。
    final overflow =
        parsed.length > kHistoryLimit ? parsed.length - kHistoryLimit : 0;
    return GameStateProvider(
      player: safeObject(json['player'], Player.fromJson) ?? Player.defaultPlayer(),
      progress: safeObject(json['progress'], GameProgress.fromJson) ??
          GameProgress.defaultProgress(),
      history: overflow > 0 ? parsed.sublist(overflow) : parsed,
      currentEvent: safeObject(json['currentEvent'], GameEvent.fromJson),
      isGameActive: safeBool(json, 'isGameActive'),
      isGameOver: safeBool(json, 'isGameOver'),
      droppedHistoryCount:
          safeInt(json, 'droppedHistoryCount') + overflow,
    );
  }
}
