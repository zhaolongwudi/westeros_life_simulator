/// 事件触发门槛判定（Batch 10-104 单一真相）。
///
/// 【为什么抽这个文件】`EventProvider.canTrigger`（生产通道，事件面板 +
/// 月度世界事件浮现）与 `EventService.checkTriggerConditions`（Batch 3 建
/// 立的第二通道）各自写了一份门槛判定。项目已发生四次同类「双通道漂移」
/// 事故（10-90 好感度钳制、10-95 event_service 负值护栏、10-99 relations
/// 守卫、10-101 顶层键拒收），本批把门槛判定也收口，避免第五次。
///
/// 【10-103 取证结论：漂移本身是 no-op，但数据侧有真 bug】
/// 两通道的判定差异全部落在「`EventService` 独有的 `context` 通道」上——
/// `context` 能覆盖任何键（含 `minGold`），生产调用方不传它，故线上行为
/// 与 `canTrigger` 一致。真正被本文件消灭的是 `canTrigger` 对
/// `season: 'any'` 的误判（见 [seasonMatches]）。
///
/// 【不认识的键一律放行】`event_data` 曾有 36 类门槛键从未被任何通道识别
/// （`kingAge`/`courtTension`/`warStatus`…共 41 个事件），10-103 已把它们
/// 清空。此处保留「未知键放行」而非改成拒收，是为了**旧存档里已序列化的
/// 自定义门槛**（`GameEvent.fromJson` 原样恢复）不会在升级后突然全部失效。
library;

import '../models/event.dart';
import '../models/player.dart';

/// 门槛 `'any'`：事件在任意季节都应可触发。
///
/// 【10-103 修的真 bug】`canTrigger` 原实现是 `if (key == 'season' &&
/// season != value) return false;`，而 `event_festival`（节日）写的是
/// `{'season': 'any'}` → 任何季节都 `'winter' != 'any'` → **恒 false**，
/// 该事件永远不出现。`event_prompt_filter` 侧却明确把 `'any'` 当命中
/// （第 63 行 `s == season || s == 'any'`），于是 AI 看得见、玩家看不到。
/// 本函数把「任意季节」从隐式约定提升为显式支持的取值。
///
/// 【season 传 null 时为「不放行」，而非「季节不限」】这是刻意保留
/// `canTrigger` 的原语义：原实现 `season != value` 在 season 为 null 时
/// 恒成立 → 季节门槛事件被判为不可触发（fail-closed）。`EventService`
/// 旧实现走 `default` 分支 → 同一情形放行（fail-open）——**这就是两通道
/// 仅有的实质漂移**（`context` 之外的唯一一处）。本批取 fail-closed：
/// 生产通道（事件面板 / 月度事件浮现）两个调用方都传了真实季节，取
/// fail-open 只会让「调用方忘记传季节」的错误静默变成「门槛全放行」，
/// 掩盖 bug 而不是暴露它。
bool seasonMatches(String? condition, String? season) {
  if (condition == 'any') return true;
  // season 为 null = 调用方未告知季节，无法确认门槛是否满足 → 不放行。
  if (season == null) return false;
  return condition == season;
}

/// 判定单个门槛键是否满足。未知键返回 `true`（放行，见文件头说明）。
bool _matchesCondition(
  String key,
  String value,
  Player player, {
  required String? season,
  required Map<String, String> context,
}) {
  // `'any'` 是通配语义，先于 context 覆盖层判定：无论调用方告知什么季节，
  // 「任意季节」都成立。若放到 context 之后，`context['season']='winter'`
  // 会与 value `'any'` 直接比较 → 恒 false → 重新引入 10-103 修的那个 bug。
  if (key == 'season' && value == 'any') return true;

  // 上下文优先：调用方显式给出的值覆盖一切（含玩家字段），
  // 这是 `EventService` 既有的 `context` 语义，两通道统一保留。
  final ctx = context[key];
  if (ctx != null) return ctx == value;

  // ---- 季节（10-103 起支持 'any'）----
  if (key == 'season') return seasonMatches(value, season);

  // ---- 地点 / 家族 / 身份（字符串相等）----
  if (key == 'locationId') return player.locationId == value;
  if (key == 'familyId') return player.familyId == value;
  if (key == 'identity') return player.identity.name == value;

  // ---- 数值门槛（10-103 取证：event_data 全部可 int.parse，
  //      但旧存档可能塞进非数字，故用 tryParse 并按「无法解析即放行」处理，
  //      避免存档脏数据把玩家锁死在「事件永不触发」）----
  if (key == 'minAge') return _atLeast(player.age, value);
  if (key == 'maxAge') return _atMost(player.age, value);
  if (key == 'minGold') return _atLeast(player.gold, value);
  if (key == 'minReputation') return _atLeast(player.reputation, value);
  if (key == 'minHealth') return _atLeast(player.health, value);
  if (key == 'maxHealth') return _atMost(player.health, value);
  if (key == 'minEnergy') return _atLeast(player.energy, value);
  if (key == 'maxEnergy') return _atMost(player.energy, value);
  if (key == 'minHunger') return _atLeast(player.hunger, value);
  if (key == 'maxHunger') return _atMost(player.hunger, value);

  // ---- 前缀门槛 ----
  if (key.startsWith('hasItem.')) {
    final itemId = key.substring(8);
    final need = int.tryParse(value) ?? 0;
    return player.inventory.where((i) => i == itemId).length >= need;
  }
  if (key.startsWith('skills.')) {
    final skillName = key.substring(7);
    final need = int.tryParse(value) ?? 0;
    return (player.skills[skillName] ?? 0) >= need;
  }
  if (key.startsWith('attributes.')) {
    final attrName = key.substring(11);
    final need = int.tryParse(value) ?? 0;
    return (player.attributes[attrName] ?? 0) >= need;
  }

  // ---- 标记门槛 ----
  if (key == 'flag') return player.flags[value] ?? false;
  if (key == 'noFlag') return !(player.flags[value] ?? false);
  if (key == 'isAlive') {
    return value != 'true' || (player.flags['isAlive'] ?? false);
  }

  // 未知键放行（见文件头）。
  return true;
}

bool _atLeast(int actual, String raw) {
  final need = int.tryParse(raw);
  return need == null || actual >= need;
}

bool _atMost(int actual, String raw) {
  final need = int.tryParse(raw);
  return need == null || actual <= need;
}

/// 判定事件的全部触发门槛是否满足。
///
/// [season] 为 null 时不施加季节限制（与 `canTrigger` 既有行为一致：
/// 未传季节则 `season` 类门槛一律放行）。
/// [context] 供 `EventService` 传入的上下文覆盖层；生产调用方不传。
bool eventTriggersSatisfied(
  GameEvent event,
  Player player, {
  String? season,
  Map<String, String> context = const <String, String>{},
}) {
  for (final entry in event.triggerConditions.entries) {
    if (!_matchesCondition(entry.key, entry.value, player,
        season: season, context: context)) {
      return false;
    }
  }
  return true;
}