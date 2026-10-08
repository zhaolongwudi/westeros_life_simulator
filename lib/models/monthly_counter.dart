/// 月度行动计数（存档往返字段，S13-5）。
///
/// 【为什么独立成类而不把 6 组计数摊成 6 对字段】
/// P1 ⑫ 的 6 组计数器分散在 4 个 mixin 里（`mixin_play` / `mixin_life` /
/// `mixin_marriage`(2 组) / `mixin_npc_interact`(2 组)），每组都是
/// 「一个计数 + 一个它所属的月份键」的对子。若摊成 12 个字段：
/// ① 每个 mixin 都要各自覆写 `toJson`/`applyState`/`startNewGame` 做桥接
/// （S13-4 已实证父类看不到 mixin 成员，只能由 mixin 自己覆写）；
/// ② 存档 JSON 会多出 6 个几乎同构的键，日后加第 7 组又是同样一轮。
/// 收成**一个值对象**后：运行时仍是 mixin 私有的活状态（不改变既有行为），
/// 但存档侧只需序列化**这一个对象**，四个 mixin 各自覆写三方法即可。
///
/// 【命名说明】游戏里没有「天」这一时间单位，重置键是 `${年}-${月}`
/// （见 `BalanceData.dailyLimits` 的注释）。mixin 侧的字段名沿用历史
/// `*_daily_*` 命名，为存档兼容未改；**本类对外一律用 `monthly`**。
library;

import '../utils/json_safe.dart';

/// 一组「每月次数」计数：计数本体 + 它所属的月份键。
///
/// 【月份键必须与计数成对入档】重置判据是「月份键 ≠ 当前年月」，
/// 只存计数不存月份键，读档后要么把计数误清（额度白送）、要么误留
/// （额度变永久锁）。两者必须一起往返。
class MonthlyCounter {
  MonthlyCounter({Map<String, int>? counts, this.month})
      : _counts = Map<String, int>.from(counts ?? const <String, int>{});

  /// 计数本体（键为活动 id）。
  final Map<String, int> _counts;

  /// 这些计数所属的月份键（`${年}-${月}`）；null = 从未记录过。
  ///
  /// 🔴 **不能是 final**：`rollIfNewMonth` / `reset` / `copyFrom` 三处都要写它
  /// （S13-5 首次 CI run `37747228801` analyze 报 3 个 error 级
  /// `assignment_to_final` 就是这里声明成了 final）。
  String? month;

  /// 当前计数（只读视图）。
  Map<String, int> get counts => Map<String, int>.unmodifiable(_counts);

  /// 某活动的已用次数。
  int used(String key) => _counts[key] ?? 0;

  /// 全部活动的已用次数之和（示好/深聊是「总额闸口」而非「每活动闸口」）。
  int get totalUsed =>
      _counts.values.fold(0, (a, b) => a + b);

  /// 跨月重置：月份键变化时清空计数。
  ///
  /// 返回 true 表示发生了重置（便于测试观察，不影响调用方语义）。
  bool rollIfNewMonth(String currentMonth) {
    if (month == currentMonth) return false;
    _counts.clear();
    month = currentMonth;
    return true;
  }

  /// 记录一次活动。
  void record(String key) {
    _counts[key] = used(key) + 1;
  }

  /// 置为一个标量计数（配偶互动/谈心是 int 而非 Map）。
  void setScalar(String key, int value) {
    _counts[key] = value;
  }

  /// 清空（`startNewGame` 用）。
  void reset() {
    _counts.clear();
    month = null;
  }

  /// 从另一实例整体拷贝（`applyState` 用）。
  void copyFrom(MonthlyCounter other) {
    _counts
      ..clear()
      ..addAll(other._counts);
    month = other.month;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'month': month,
      'counts': Map<String, int>.from(_counts),
    };
  }

  /// 防御式反序列化：键缺失 / 类型不对一律回落空计数。
  factory MonthlyCounter.fromJson(Object? value) {
    final map = asJsonMap(value);
    if (map == null) return MonthlyCounter();
    final month = map['month'];
    return MonthlyCounter(
      counts: safeIntMap(map, 'counts'),
      month: month is String ? month : null,
    );
  }
}

/// S13-5 的 6 组计数器集合（存档往返字段）。
///
/// 【运行时唯一持有者】与 S13-4 的信件不同——本对象的**运行时持有者就是它自己**：
/// 四个 mixin 直接读写同一实例，不做镜像，因此**不存在 S13-4 记录的
/// 「两份数据各自漂移」风险**。mixin 侧只需在存档往返的三个边界
/// （`toJson` / `applyState` / `startNewGame`）把它带上。
class MonthlyCounters {
  MonthlyCounters({
    MonthlyCounter? activity,
    MonthlyCounter? trade,
    MonthlyCounter? favor,
    MonthlyCounter? chat,
    MonthlyCounter? spouseInteract,
    MonthlyCounter? spouseChat,
    this.negotiatedDiscount = 0,
  })  : activity = activity ?? MonthlyCounter(),
        trade = trade ?? MonthlyCounter(),
        favor = favor ?? MonthlyCounter(),
        chat = chat ?? MonthlyCounter(),
        spouseInteract = spouseInteract ?? MonthlyCounter(),
        spouseChat = spouseChat ?? MonthlyCounter();

  /// 议价折扣百分比（0-100），随议价组的计数器一起跨月清零。
  ///
  /// 【为什么它也进存档】它是**当月权益**且直接换金币：议价成功后
  /// 买价下调、卖价上浮。原先只活在 `mixin_life._negotiatedDiscount`，
  /// 读档即归零 ⇒ 读档后当月又可再议一次（额度虽已由 `trade` 组挡住，
  /// 但玩家已经拿到的折扣会凭空消失，读档前后价格不一致）。
  int negotiatedDiscount;

  /// ① 日常活动（训练/休息/工作/狩猎/贸易，`kDailyLimits`）。
  final MonthlyCounter activity;

  /// ② 新增贸易三项（巡游/议价/商队，`kNewDailyLimits`）。
  final MonthlyCounter trade;

  /// ⑤ NPC 示好。
  final MonthlyCounter favor;

  /// ⑥ NPC 深聊。
  final MonthlyCounter chat;

  /// ③ 配偶互动。
  final MonthlyCounter spouseInteract;

  /// ④ 配偶谈心。
  final MonthlyCounter spouseChat;

  /// 清空全部（新局）。
  void reset() {
    activity.reset();
    trade.reset();
    favor.reset();
    chat.reset();
    spouseInteract.reset();
    spouseChat.reset();
    negotiatedDiscount = 0;
  }

  /// 从另一实例整体拷贝（读档）。
  void copyFrom(MonthlyCounters other) {
    activity.copyFrom(other.activity);
    trade.copyFrom(other.trade);
    favor.copyFrom(other.favor);
    chat.copyFrom(other.chat);
    spouseInteract.copyFrom(other.spouseInteract);
    spouseChat.copyFrom(other.spouseChat);
    negotiatedDiscount = other.negotiatedDiscount;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'activity': activity.toJson(),
      'trade': trade.toJson(),
      'favor': favor.toJson(),
      'chat': chat.toJson(),
      'spouseInteract': spouseInteract.toJson(),
      'spouseChat': spouseChat.toJson(),
      'negotiatedDiscount': negotiatedDiscount,
    };
  }

  /// 防御式反序列化（逐组独立回落，一组坏不影响其余五组）。
  factory MonthlyCounters.fromJson(Object? value) {
    final map = asJsonMap(value);
    if (map == null) return MonthlyCounters();
    return MonthlyCounters(
      activity: MonthlyCounter.fromJson(map['activity']),
      trade: MonthlyCounter.fromJson(map['trade']),
      favor: MonthlyCounter.fromJson(map['favor']),
      chat: MonthlyCounter.fromJson(map['chat']),
      spouseInteract: MonthlyCounter.fromJson(map['spouseInteract']),
      spouseChat: MonthlyCounter.fromJson(map['spouseChat']),
      negotiatedDiscount: safeInt(map, 'negotiatedDiscount'),
    );
  }
}
