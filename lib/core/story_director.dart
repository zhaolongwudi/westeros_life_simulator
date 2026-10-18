/// 本地剧情导演：没有可用 AI 时的主剧情来源。
///
/// 与 AI 通道产出同一种东西——「一段剧情 + 2~4 个可点选项」——所以主界面只有
/// 一条剧情回路：主 AI 可用时说书，不可用时由本导演接手，两种情况都不会退化
/// 成「玩家不打字就没有剧情」。
///
/// 纯函数、无 IO、无随机：同一（回合数, 玩家状态, 可用事件）必得同一结果，
/// 回合可复现（随机源一律由调用方持有，见 `GameProviderBase.rng`）。
library;

import '../data/balance_data.dart';
import '../models/event.dart';
import '../models/location.dart';
import '../models/npc.dart';
import '../models/player.dart';
import '../utils/labels.dart';
import 'narrative_momentum.dart';

/// 一次本地剧情产出。
class DirectedScene {
  const DirectedScene({
    required this.narrative,
    required this.choices,
    this.eventId,
    this.isDailyFallback = false,
  });

  /// 叙事正文（多句，供主界面分段渲染）。
  final String narrative;

  /// 2~4 个选项（门槛不满足的已被剔除）。
  final List<EventChoice> choices;

  /// 本回合取材的事件 id；走日常兜底时为 null。
  final String? eventId;

  /// 是否走了「本月无可用事件」的日常兜底。
  final bool isDailyFallback;
}

/// 本地剧情导演（纯逻辑，可直接单测）。
class StoryDirector {
  const StoryDirector._();

  /// 单回合选项数上限（与 AI 通道的 2-4 个对齐）。
  static const int kMaxChoices = 4;

  /// 围绕**指定事件**生成剧情（待决事件回合一类）。
  static DirectedScene narrate({
    required GameEvent event,
    required Player player,
    required int year,
    required int month,
    required String season,
    required int turnCount,
    Location? location,
    String familyName = '',
    List<Npc> onSiteNpcs = const <Npc>[],
    bool Function(EventChoice)? canChoose,
  }) {
    return _compose(
      player: player,
      year: year,
      month: month,
      season: season,
      turnCount: turnCount,
      event: event,
      location: location,
      familyName: familyName,
      onSiteNpcs: onSiteNpcs,
      canChoose: canChoose,
    );
  }

  /// 自动挑一个可用事件生成剧情；一个都没有时走日常兜底。
  static DirectedScene direct({
    required Player player,
    required int year,
    required int month,
    required String season,
    required int turnCount,
    required List<GameEvent> availableEvents,
    Location? location,
    String familyName = '',
    List<Npc> onSiteNpcs = const <Npc>[],
    bool Function(EventChoice)? canChoose,
  }) {
    final phase = NarrativeMomentum.phaseFor(turnCount);
    return _compose(
      player: player,
      year: year,
      month: month,
      season: season,
      turnCount: turnCount,
      event: pickEvent(availableEvents, phase, turnCount),
      location: location,
      familyName: familyName,
      onSiteNpcs: onSiteNpcs,
      canChoose: canChoose,
    );
  }

  /// 按相位挑事件：分高者优先，同分用回合数确定性地取一个。
  ///
  /// 与 `NarrativeMomentum.scoreEvent` 的分工：那边给「事件 × 相位」打分，
  /// 这边负责在最高分集合里选；同分集合先按 id 排序，避免依赖事件表的
  /// 书写顺序（顺序一变结果就变，测试与存档都会漂）。
  static GameEvent? pickEvent(
    List<GameEvent> events,
    NarrativePhase phase,
    int turnCount,
  ) {
    if (events.isEmpty) return null;
    var best = NarrativeMomentum.scoreEvent(events.first, phase);
    for (final e in events) {
      final s = NarrativeMomentum.scoreEvent(e, phase);
      if (s > best) best = s;
    }
    final top = events
        .where((e) => NarrativeMomentum.scoreEvent(e, phase) == best)
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return top[turnCount % top.length];
  }

  /// 日常兜底选项：本月没有任何可用事件时，也要有事可做。
  ///
  /// 数值全部取自 [BalanceData]（不与 `mixin_play` 各活动的数值分叉），
  /// 效果键均为写侧白名单内的键（gold / energy / hunger / health /
  /// relations.<npcId>），不会制造幽灵键。
  static List<EventChoice> dailyChoices(Player player, List<Npc> onSiteNpcs) {
    final income = BalanceData.workBaseIncome[player.identity.name] ?? 12;
    final list = <EventChoice>[
      const EventChoice(
        id: 'local_rest',
        text: '歇上几日',
        requirements: <String, int>{'gold': BalanceData.restInnCost},
        effects: <String, int>{
          'gold': -BalanceData.restInnCost,
          'energy': BalanceData.restEnergyRecovery,
          'hunger': BalanceData.restHungerGain,
          'health': BalanceData.healthRegen,
        },
        narrative: '你放下手里的事歇了几日，精气神回来了些。',
      ),
      EventChoice(
        id: 'local_work',
        text: '埋头干活',
        requirements: const <String, int>{'energy': BalanceData.workEnergyCost},
        effects: <String, int>{
          'energy': -BalanceData.workEnergyCost,
          'gold': income,
        },
        narrative: '你埋头干了一个月的活，攒下一笔钱。',
      ),
    ];
    final host = onSiteNpcs.isEmpty ? null : onSiteNpcs.first;
    if (host != null) {
      list.add(
        EventChoice(
          id: 'local_rapport',
          text: '打点关系',
          requirements: const <String, int>{'gold': BalanceData.npcFavorCostBase},
          effects: <String, int>{
            'gold': -BalanceData.npcFavorCostBase,
            'relations.${host.id}': 3,
          },
          narrative: '你请${host.name}喝了几回酒，关系近了些。',
        ),
      );
    }
    return list;
  }

  // ==================== 内部实现 ====================

  static DirectedScene _compose({
    required Player player,
    required int year,
    required int month,
    required String season,
    required int turnCount,
    required GameEvent? event,
    required Location? location,
    required String familyName,
    required List<Npc> onSiteNpcs,
    required bool Function(EventChoice)? canChoose,
  }) {
    final phase = NarrativeMomentum.phaseFor(turnCount);
    final buf = StringBuffer()..write('${seasonLabel(season)}，$year年$month月。');
    if (location != null) {
      buf.write(
        '${location.name}，${location.region}的${locationTypeLabel(location.type)}。',
      );
    } else {
      buf.write('你正在路上，前后都不见人烟。');
    }
    buf.write(_phaseLine(phase));
    if (familyName.isNotEmpty) {
      buf.write('你是$familyName家的人。');
    }
    final onSite = _onSiteLine(player, onSiteNpcs);
    if (onSite.isNotEmpty) {
      buf.write(onSite);
    }
    if (event != null) {
      buf.write('${event.name}——${event.description}');
    }
    buf.write(_situationLine(player));

    final fromEvent =
        event == null ? <EventChoice>[] : _usable(event.choices, canChoose);
    final fallback = fromEvent.isEmpty;
    final choices = fallback
        ? _usable(dailyChoices(player, onSiteNpcs), canChoose)
        : fromEvent;
    buf.write(
      choices.isEmpty ? '眼下没有非做不可的事，你可以按自己的节奏过完这个月。' : '你必须做出选择。',
    );
    return DirectedScene(
      narrative: buf.toString(),
      choices: choices,
      // 兜底回合不算「用过」这条事件，否则一次性事件会被白白消耗。
      eventId: fallback ? null : event?.id,
      isDailyFallback: fallback,
    );
  }

  /// 按门槛筛选项并截断到上限。
  static List<EventChoice> _usable(
    List<EventChoice> source,
    bool Function(EventChoice)? canChoose,
  ) {
    final usable =
        canChoose == null ? source.toList() : source.where(canChoose).toList();
    return usable.take(kMaxChoices).toList();
  }

  /// 相位语气句（与 `NarrativeMomentum` 的四相位一一对应）。
  static String _phaseLine(NarrativePhase phase) {
    switch (phase) {
      case NarrativePhase.introduce:
        return '新的风声正传到你耳中，局势还没有露出全貌。';
      case NarrativePhase.escalate:
        return '事情正在变紧，回避已经不再是一个选项。';
      case NarrativePhase.turn:
        return '局面到了转弯处，退路一条条关上了。';
      case NarrativePhase.resolve:
        return '这一段的恩怨，到了该结算的时候。';
    }
  }

  /// 在场人物与好感（最多 3 位）。
  static String _onSiteLine(Player player, List<Npc> onSiteNpcs) {
    if (onSiteNpcs.isEmpty) return '';
    final parts = onSiteNpcs.take(3).map((n) {
      final rel = player.relations[n.id] ?? 0;
      final stance = rel >= 20 ? '交好' : (rel <= -20 ? '交恶' : '泛泛之交');
      return '${n.name}（$stance $rel）';
    }).join('、');
    return '你身边有：$parts。';
  }

  /// 处境句：把金币/声望/生存三值说清楚，选项的代价才有参照。
  static String _situationLine(Player player) {
    return '你身上有 ${player.gold} 枚金龙，声望 ${player.reputation}；'
        '生命 ${player.health}、精力 ${player.energy}、饱食 ${player.hunger}。';
  }
}
