/// 事件 prompt 预算筛选器（M4c-2）。
///
/// 把 AI 叙事 prompt 中「可用事件」从全量注入改为按相关度筛选 + 预算截断，
/// 控制单次请求 token 成本（全量 72 → 预算 12，约降 83%）。
library;

import '../data/balance_data.dart';
import '../models/event.dart';
import '../models/player.dart';

/// 按相关度筛选事件，用于 prompt 预算化（M4c-2）。
///
/// 预算规则：
/// - 事件总数 ≤ [BalanceData.kAiPromptEventBudget] 时全量返回（不截断，保持原语义）；
/// - 超过预算时按相关度评分降序，截取前 [BalanceData.kAiPromptEventBudget] 个。
///
/// 评分维度（每个命中条件与玩家当前状态匹配即得分）：
/// - 地点条件命中 → [BalanceData.kAiScoreLocation]
/// - 季节条件命中（当前季节或 any）→ [BalanceData.kAiScoreSeason]
/// - 数值条件（minGold/minReputation/minEnergy/maxEnergy/minAge）满足 → 每个 +[BalanceData.kAiScoreNumeric]
/// - 标记条件（flag 已有 / noFlag 无）满足 → +[BalanceData.kAiScoreNumeric]
///
/// 排序对同分保持原列表顺序（次级键为原始下标，规避 Dart sort 不稳定）。
List<GameEvent> selectEventsForPrompt(
  List<GameEvent> events, {
  required Player player,
  required String season,
}) {
  if (events.length <= BalanceData.kAiPromptEventBudget) {
    return events;
  }
  final scored = <(int, int, GameEvent)>[
    for (var i = 0; i < events.length; i++)
      (
        i,
        _eventRelevanceScore(events[i], player: player, season: season),
        events[i],
      ),
  ]..sort((a, b) {
      final byScore = b.$2.compareTo(a.$2);
      if (byScore != 0) return byScore;
      return a.$1.compareTo(b.$1);
    });
  return scored
      .take(BalanceData.kAiPromptEventBudget)
      .map((s) => s.$3)
      .toList();
}

/// 计算单个事件与玩家当前状态的相关度评分（用于 prompt 预算筛选）。
int _eventRelevanceScore(
  GameEvent event, {
  required Player player,
  required String season,
}) {
  var score = 0;
  final cond = event.triggerConditions;
  final loc = cond['locationId'];
  if (loc != null && loc == player.locationId) {
    score += BalanceData.kAiScoreLocation;
  }
  final s = cond['season'];
  if (s != null && (s == season || s == 'any')) {
    score += BalanceData.kAiScoreSeason;
  }
  // 数值条件
  final minGold = cond['minGold'];
  if (minGold != null) {
    final v = int.tryParse(minGold);
    if (v != null && player.gold >= v) {
      score += BalanceData.kAiScoreNumeric;
    }
  }
  final minRep = cond['minReputation'];
  if (minRep != null) {
    final v = int.tryParse(minRep);
    if (v != null && player.reputation >= v) {
      score += BalanceData.kAiScoreNumeric;
    }
  }
  final minEnergy = cond['minEnergy'];
  if (minEnergy != null) {
    final v = int.tryParse(minEnergy);
    if (v != null && player.energy >= v) {
      score += BalanceData.kAiScoreNumeric;
    }
  }
  final maxEnergy = cond['maxEnergy'];
  if (maxEnergy != null) {
    final v = int.tryParse(maxEnergy);
    if (v != null && player.energy <= v) {
      score += BalanceData.kAiScoreNumeric;
    }
  }
  final minAge = cond['minAge'];
  if (minAge != null) {
    final v = int.tryParse(minAge);
    if (v != null && player.age >= v) {
      score += BalanceData.kAiScoreNumeric;
    }
  }
  // 标记条件
  final flag = cond['flag'];
  if (flag != null && (player.flags[flag] ?? false)) {
    score += BalanceData.kAiScoreNumeric;
  }
  final noFlag = cond['noFlag'];
  if (noFlag != null && !(player.flags[noFlag] ?? false)) {
    score += BalanceData.kAiScoreNumeric;
  }
  return score;
}
