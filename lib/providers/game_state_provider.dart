/// 游戏状态管理：管理玩家状态、游戏进度、当前事件。
///
/// 使用 ChangeNotifier + provider 实现响应式状态管理。
library;

import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/balance_data.dart';
// Batch 10-91：`applyEffects` 的 `inventory.<id>` 分支要 `itemById` 校验
// 物品 id 是否真实存在（与 `mixin_life.addItem` 的既有校验对齐）。
import '../data/item_data.dart';
// Batch 10-99：`applyEffects` 的 `relations.<npcId>` 分支要 `isNpcIdValid`
// 校验 NPC id 是否真实存在（与 `npc_data.npcById` 同源，单一真相）。
import '../data/npc_data.dart';
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

  /// Batch 10-94：最近一次 [applyEffects] 被写侧守卫拒绝的效果键（有序）。
  ///
  /// 【为什么做成字段而不是改返回值】`applyEffects` 返回 `Player`
  /// 是三条调用方（`applyChoice` 事件选项、`applyAiChoice` AI 选项、
  /// 以及 10 条既有测试）共同依赖的契约，改成记录类型会连带改全部
  /// 调用方与断言；加字段是纯增量、不破坏任何既有签名。
  ///
  /// 【每次调用入口清空】避免上一回合的残留被下回合误读。
  /// 【只记被守卫拒绝的键】未知顶层键沿用既有「静默忽略」语义不记，
  /// 否则摘要提示会从「AI 写了不存在的技能」退化成「AI 写了未知的键」，
  /// 对玩家无信息量。
  List<String> _lastRejectedEffectKeys = <String>[];

  /// 最近一次 [applyEffects] 被写侧守卫（10-91/92 白名单）拒绝的效果键。
  ///
  /// 供 `mixin_ai.applyAiChoice` 输出提示行——让「叙事里写着提利昂
  /// 好感 +10、状态却毫无变化」这类脱节对玩家可见。
  /// 空列表表示本次没有键被拒（或尚未调用过 [applyEffects]）。
  List<String> get lastRejectedEffectKeys =>
      List<String>.unmodifiable(_lastRejectedEffectKeys);

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
  /// relations.<npcId> / flags.<flagName>（value>0 置真，<=0 清除，
  /// 键名须合法，见 [BalanceData.isPlayerFlagKeyValid]）/
  /// inventory.<itemId>（value>0 获得，<0 消耗）。
  /// 供事件选项（[applyChoice]）与 AI 生成选项共用。
  ///
  /// 【键名白名单，Batch 10-91/92/97】`skills.` / `attributes.` 的键须在
  /// `BalanceData.kPlayerSkillKeys` / `kPlayerAttributeKeys` 内，
  /// `flags.` 的键须通过 [BalanceData.isPlayerFlagKeyValid]（分层：静态
  /// 键集 + 受限动态前缀），`inventory.` 的 id 须能被 `itemById` 解析；
  /// 不合规的键**跳过落盘**，并登记进 [lastRejectedEffectKeys]
  /// （Batch 10-94：供 `applyAiChoice` 提示，让「叙事写了但状态没变」
  /// 的脱节对玩家可见）。与 `event_service.applyEffects` 的同名分支
  /// 判定完全一致，区别仅在失败如何上报（那边登记进 `failedEffects`）。
  Player applyEffects(Player player, Map<String, int> effects) {
    var newPlayer = player;
    // Batch 10-94：每次调用入口清空，避免上一回合的拒绝记录被误读。
    final rejected = <String>[];
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
        // Batch 10-99：NPC id 白名单守卫——`isNpcIdValid(id) == false` 即拒绝。
        // 与 10-91 的物品守卫、10-92 的技能/属性守卫、10-97 的 flags 分层
        // 守卫同构，至此**五类效果键全部有校验**（此前 `relations.` 只在
        // 10-89 改过 prompt 示例文案，写侧一直没设防）。
        // 幽灵 NPC 键后果：① `ai_service` 关系段 `n == null` 兜底把裸 id
        // 打进 prompt；② `player_panel` 出现名为 `tyrion` 的条目；
        // ③ 按 `|值|` 参与 10-83 关系段预算排序、白占预算位。
        // 【Batch 10-94】同上，拒绝时登记键名供 `applyAiChoice` 提示行使用。
        if (!isNpcIdValid(npcId)) {
          rejected.add(key);
          continue;
        }
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
        // Batch 10-92：键名白名单守卫——拒绝写入清单外技能键。
        // 幽灵技能键会让 `labels.skillLabel` 的 `_ => key` 兜底把原始键名
        // 泄漏进技能面板，并让 `train` 的 `skills.containsKey` 判定失真
        // （AI 可以「教会」一个不存在的技能）。本方法无 `failedEffects` 通道，
        // 故不落盘；Batch 10-94 起另登记进 `lastRejectedEffectKeys`，
        // 供 `applyAiChoice` 提示——脱节对玩家可见，不再静默。
        if (!BalanceData.kPlayerSkillKeys.contains(skillName)) {
          rejected.add(key);
          continue;
        }
        final newSkills = Map<String, int>.from(newPlayer.skills);
        // Batch 10-90：防负数破底（与 gold 的 `max(0, ...)` 同策略）——
        // 技能是「等级」，负等级在 `train` 的门槛判定与 prompt 展示里都无意义。
        newSkills[skillName] = max(0, (newSkills[skillName] ?? 0) + value);
        newPlayer = newPlayer.copyWith(skills: newSkills);
      } else if (key.startsWith('attributes.')) {
        final attrName = key.substring(11);
        // Batch 10-92：同上一分支，属性键同样走白名单。
        if (!BalanceData.kPlayerAttributeKeys.contains(attrName)) {
          rejected.add(key);
          continue;
        }
        final newAttrs = Map<String, int>.from(newPlayer.attributes);
        newAttrs[attrName] = max(0, (newAttrs[attrName] ?? 0) + value);
        newPlayer = newPlayer.copyWith(attributes: newAttrs);
      } else if (key.startsWith('flags.')) {
        final flagName = key.substring(6);
        // Batch 10-97：状态标记键分层白名单守卫——静态键集
        // `BalanceData.kPlayerFlagKeys`（26 键）+ 受限动态前缀
        // `kPlayerFlagPrefixes`（5 个），其余拒收。此前本分支
        // **完全不校验键名**，是五类效果键里唯一未设防的一类：
        // AI 每回合都能新增一个永不存在的标记，① 玩家面板「状态标记」
        // 区块直接显示裸键名，② 状态段（10-88，预算 8）白占预算位把
        // 真实状态挤出窗口，③ 存档逐回合序列化整个 map，只增不减。
        // 本方法无 `failedEffects` 通道，故不落盘并登记进
        // [lastRejectedEffectKeys]（10-94 机制），脱节对玩家可见。
        if (!BalanceData.isPlayerFlagKeyValid(flagName)) {
          rejected.add(key);
          continue;
        }
        final newFlags = Map<String, bool>.from(newPlayer.flags);
        newFlags[flagName] = value > 0;
        newPlayer = newPlayer.copyWith(flags: newFlags);
      } else if (key.startsWith('inventory.')) {
        final itemId = key.substring(10);
        // Batch 10-91：物品 id 白名单守卫——`itemById(id) == null` 即拒绝。
        // 与 `mixin_life.addItem` 的既有校验对齐（那边早就有
        // `if (item == null) return false;`），此前只有这一条通道校验、
        // 两条 applyEffects 通道不校验，属实现不一致。幽灵物品键后果：
        // 背包段（10-87）会把未知 id 直接打出来浪费预算位，存档与
        // 物品面板积累永远无法使用/显示的无效条目。
        // 【Batch 10-94】同上，拒绝时登记键名供提示行使用。
        if (itemById(itemId) == null) {
          rejected.add(key);
          continue;
        }
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
      } else if (key == 'age') {
        // Batch 10-101：`age` 键只在事件通道处理，AI 通道一直漏了——
        // 与 10-95 修 `skills./attributes.` 的 `max(0, ...)`、
        // 10-90 修好感度 ±100 钳制同型（两处 applyEffects 漂移）。
        // 事件数据目前零处使用 `age` 键（取证：`event_data` 内
        // `'age'` 命中 0），故本分支对现有内容零影响，属补齐契约
        // 对称性而非修 bug——**但 AI 写 `age: 5` 此前是静默丢弃**，
        // 玩家看不到任何反馈，叙事里却写着「你又老了一岁」。
        newPlayer = newPlayer.copyWith(age: max(0, newPlayer.age + value));
      } else {
        // Batch 10-101：未识别顶层键兜底拒收。
        //
        // 【本批最重要的发现】取证发现 `event_data` 存在 **10 个纯幽灵
        // 顶层效果键**（`political`/`military`/`faith`/`magic`/`familyRelation`
        // 等，共 78 处、覆盖 60+ 事件），两条 `applyEffects` 都不认识它们
        // → 玩家点了「支持合法继承人」只拿到 `reputation`，叙事承诺的
        // 政治资本变化**静默丢弃、无任何反馈**。
        //
        // 【为什么不删这些键而要兜底拒收】取证验证过删除的代价：
        // ① **9 个选项会变成零效果死选项**（`choice_rest` 休息、
        //    `choice_walk_away` 转身离开、`choice_just_look` 只看不买…），
        //    而「转身离开本就没有收益」是**有意设计**，不是数据错误；
        // ② **4 个事件选项组会同质化**（`event_family_intrigue` /
        //    `event_church_split` 三选项坍缩成 rep +5/+5/-5）。故删除
        //    破坏玩法，接线属新增玩法维度，均超出契约修复范围。
        //
        // 【本批只做契约闭合】把「静默丢弃」变成「可见的拒收」——
        // 复用 10-94 已建成的 `lastRejectedEffectKeys` 通道，与
        // 五类前缀键守卫完全同构，玩家看到「（其中 N 项效果未生效：…）」，
        // 叙事与状态的脱节不再隐形。治理本身不新增任何玩法语义。
        rejected.add(key);
      }
    }
    // Batch 10-94：登记本次被守卫拒绝的键（含 0 命中，
    // 保证上一次的结果不会残留到下一次调用）。
    _lastRejectedEffectKeys = rejected;
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
