/// 事件 prompt 预算筛选器（M4c-2）。
///
/// 把 AI 叙事 prompt 中「可用事件」从全量注入改为**门槛过滤 + 相关度排序 + 预算截断**，
/// 控制单次请求 token 成本（全量 71 → 预算 12，约降 83%）。
///
/// 【S4-3（P1-10/P2-03 真正的根因）原实现只排序、不筛选】
/// M4c-2 建这个筛选器时只做了「打分排序 + 取前 12」，**从不过滤门槛**：
/// 文件里没有任何 `where` / `canTrigger`。于是 AI 会被告知玩家当前**不可能发生**的事件——
/// 实测站在King's Landing 的**夏天**玩家，prompt 里会被塞进 `event_frozen_lake`
/// （门槛 `locationId: location_winterfell` + `season: winter`）与 `event_ghost_road`
/// （门槛 `season: winter`）。AI 会据此编造「冰封的湖面」，而玩家走不到那里。
///
/// 这才是 P2-03「41 个事件无门槛」的**真正后果**：不是数据缺门槛，
/// 而是**有门槛也不生效**。故本批不改数据（不给世界背景事件硬套 `minAge: 60`），
/// 而是让筛选器真正执行门槛。
///
/// 【为什么复用 `eventTriggersSatisfied` 而不是就地写一套】
/// 门槛判定已由 Batch 10-104 收口到 `event_trigger_eval.dart` 单一真相。本项目已发生
/// **五次**「双通道漂移」事故（见该文件头），故此处一律调用它，不复制判定逻辑。
library;

import '../core/event_trigger_eval.dart';
import '../data/balance_data.dart';
import '../models/event.dart';
import '../models/player.dart';

/// 按门槛过滤 + 相关度排序，用于 prompt 预算化（S4-3）。
///
/// 流程（**顺序即语义**）：
/// 1. **先按门槛过滤**（S4-3 修）——用单一真相 [eventTriggersSatisfied] 剔除
///    玩家当前不可能发生的事件。修之前这一步不存在，AI 会被灌入不可能事件。
/// 2. 再按相关度评分**降序**排序（打分只决定「已可用事件之间的优先级」）。
/// 3. 最后截取前 [BalanceData.kAiPromptEventBudget] 个。
///
/// 【为什么门槛过滤放在排序之前，而不是靠分数把不合格事件挤掉】
/// 门槛是**布尔契约**（「这一刻能不能发生」），分数只是**启发式偏好**（「多相关」）。
/// 用分数隐式过滤意味着「门槛不满足但分数高」的事件仍会被注入 —— 那正是原 bug。
///
/// 【无回退兜底，是刻意的】若过滤后为空（理论上不会发生：41 个无条件事件恒可用，
/// 实测各季节/地点组合均有 50+ 条可用，远超预算 12），返回空列表而非回退到全集——
/// 回退等于把 bug 藏起来，AI 会再次收到不可能事件。
///
/// 评分维度（每个命中条件与玩家当前状态匹配即得分）：
/// - 地点条件命中 → [BalanceData.kAiScoreLocation]
/// - 季节条件命中（当前季节或 any）→ [BalanceData.kAiScoreSeason]
/// - 身份条件命中 → [BalanceData.kAiScoreIdentity]（S14-1 补：此前漏了
///   这个维度，而 `eventTriggersSatisfied` 明确支持 `identity` 门槛、
///   事件库也确有该门槛 ⇒ 身份相关事件不参与排序，纯靠下标决定名次）
/// - 数值条件（minGold/minReputation/minEnergy/maxEnergy/minAge）满足 → 每个 +[BalanceData.kAiScoreNumeric]
/// - 标记条件（flag 已有 / noFlag 无）满足 → +[BalanceData.kAiScoreNumeric]
///
/// 排序对同分保持原列表顺序（次级键为原始下标，规避 Dart sort 不稳定）。
List<GameEvent> selectEventsForPrompt(
  List<GameEvent> events, {
  required Player player,
  required String season,
}) {
  // 1. 门槛过滤：剔除玩家当前不可能发生的事件（S4-3）。
  final eligible = <(int, GameEvent)>[
    for (var i = 0; i < events.length; i++)
      if (eventTriggersSatisfied(events[i], player, season: season))
        (i, events[i]),
  ];
  if (eligible.length <= BalanceData.kAiPromptEventBudget) {
    return eligible.map((e) => e.$2).toList();
  }
  // 2. 相关度排序（仅在已通过门槛的事件之间比较优先级）。
  final scored = <(int, int, GameEvent)>[
    for (final entry in eligible)
      (
        entry.$1,
        _eventRelevanceScore(entry.$2, player: player, season: season),
        entry.$2,
      ),
  ]..sort((a, b) {
      final byScore = b.$2.compareTo(a.$2);
      if (byScore != 0) return byScore;
      return a.$1.compareTo(b.$1);
    });
  // S14-1：落实 `kAiPromptEventFloor` 声明的「强相关事件不足时兜底注入的
  // 最少事件数」。此前该常量**从未被任何代码引用**（纯摆设），而文件头
  // 第 39-41 行那句「无回退兜底，是刻意的」针对的是**门槛过滤**（不能把
  // 玩家不可能发生的事件塞回 prompt），与「截断后至少留 N 条」是两回事：
  // 截断到 0 会让 AI 一个可用事件都看不到，叙事退化成凭空编造。
  // 故：先按预算截断，若结果不足下限，从已过门槛的池子里按原顺序补足。
  final truncated = scored.take(BalanceData.kAiPromptEventBudget).toList();
  if (truncated.length >= BalanceData.kAiPromptEventFloor) {
    // 返回类型为 List<GameEvent>，这里解包三元组。
    return truncated.map((s) => s.$3).toList();
  }
  final picked = truncated.map((s) => s.$3).toList();
  for (final entry in eligible) {
    if (picked.length >= BalanceData.kAiPromptEventFloor) break;
    if (picked.contains(entry.$2)) continue;
    picked.add(entry.$2);
  }
  return picked;
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
  // S14-1：身份维度。判定口径与门槛判定（`event_trigger_eval.dart` 的
  // `identity` 分支）保持一致：`player.identity.name == value`。
  // 此处**只影响排序**，不参与放行与否——放行由步骤 1 的门槛过滤决定。
  final identity = cond['identity'];
  if (identity != null && identity == player.identity.name) {
    score += BalanceData.kAiScoreIdentity;
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
