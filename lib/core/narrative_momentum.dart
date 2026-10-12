/// 剧情智能推进（S15-5）：把「本地模式没有剧情」变成「每月都有事发生」。
///
/// 【用户反馈（2026-10-12）】「本地模式一点剧情都没有，这个明明是一个剧情
/// 游戏」；并附《剧情推进指令》文档，其核心禁令是：
/// > 选项不是剧情的替代品。你的职责是让故事向前走，
/// > 而不是把推进的责任反复踢回给玩家。
///
/// 【根因取证】改造前 `mixin_play._maybeWorldEvent` 是一道**硬编码 30% 掷骰**：
/// ```dart
/// if (rnd.nextDouble() >= 0.3) return '';
/// ```
/// ⇒ **七成的月份什么都不发生**。玩家点「过月」只看得到「时间推进到 X 月」
/// 加几条数值结算，没有任何剧情。这正是「一点剧情都没有」的直接来源。
///
/// 【本模块怎么修】按《剧情推进指令》的章节节奏，把「概率」换成**节奏**：
/// 用**已有的、随存档往返的** `progress.turnCount` 确定性推导四相位
/// （引入 → 加压 → 转折 → 收束），每个相位 3 个回合，12 回合一个章节；
/// 除章末间歇外**每回合都推进剧情**。相位还决定**挑什么事件**
/// （引入挑日常/家族，转折挑政治/战争/超自然），让事件库按叙事节奏出场。
///
/// 【为什么用 turnCount 推导而不是新增状态字段】三个好处，都不是小事：
/// 1. **零新增存档字段**：`turnCount` 本来就在存档里，不必动
///    `GameStateProvider` 的 toJson/fromJson/applyState 四件套；
/// 2. **不碰 `flags` 白名单**：flags 是 S12-12 收口治理过的
///    「静态 26 键 + 5 前缀」，塞 `narrative.*` 会破坏那个契约；
/// 3. **完全确定**：同一回合数必得同一相位 ⇒ 测试不需要掷骰、也不需要
///    注入时钟（本项目两次因「跑 N 回合应该能等到」翻车，见 §0 第 9 条）。
///
/// 【为什么不直接照抄文档的全部规则】文档是给**自由对话式** AI 主持人的
/// 规范（停滞检测、张力衰减、选项代价……），而本项目是**回合制单机**，
/// 每回合的状态变化由引擎结算（金币/精力/技能都在动）。故本模块只落地
/// 其中**可机械判定**的部分：章节四相位 + 每回合必推进 + 按相位挑选事件。
library;

import '../models/event.dart' show EventType, GameEvent;

/// 剧情相位（《剧情推进指令》§五 章节节奏模板的四相位）。
enum NarrativePhase {
  /// 相位一 · 引入：新信息、新场景、新冲突进入，玩家建立认知。
  introduce,

  /// 相位二 · 加压：冲突升级，选项开始出现真实代价。
  escalate,

  /// 相位三 · 转折：一次不可逆的事件发生（章节承重墙，不得缺席）。
  turn,

  /// 相位四 · 收束：本章伏笔与选择得到结算，同时打开通往下一章的通道。
  resolve,
}

/// 剧情推进器（纯逻辑，无副作用，可直接单测）。
class NarrativeMomentum {
  const NarrativeMomentum._();

  /// 每个相位持续的回合数。
  static const int turnsPerPhase = 3;

  /// 一个完整章节的回合数（四相位 × 3）。
  static const int turnsPerChapter = turnsPerPhase * 4;

  /// 由回合数确定性推导当前相位。
  ///
  /// `turnCount` 从 0 起：0-2 引入、3-5 加压、6-8 转折、9-11 收束、12 起下一章。
  static NarrativePhase phaseFor(int turnCount) {
    final cycle = turnCount % turnsPerChapter;
    final index = (cycle ~/ turnsPerPhase).clamp(0, 3);
    return NarrativePhase.values[index];
  }

  /// 本章内的第几回合（0 起）。
  static int turnInChapter(int turnCount) => turnCount % turnsPerChapter;

  /// 本回合是否应推进剧情（浮现事件）。
  ///
  /// 【除了一处，其余全部推进】唯一的留白是**章末收束的最后一个回合**
  /// ——刚结算完一章（`resolve` 相位末尾），给玩家一个喘息的间歇，
  /// 同时也让「章」在体感上真的分得开。留白率 1/12 ≈ 8%，
  /// 与改造前「70% 月份无剧情」是两个量级。
  static bool shouldSurface(int turnCount) =>
      turnInChapter(turnCount) != turnsPerChapter - 1;

  /// 按相位给事件打分（分高者优先出场）。
  ///
  /// 【为什么要挑，而不是随机】文档要求章节有节奏：引入阶段就抛出
  /// 「国王死亡」这种转折事件，后面无处可去；收束阶段还在铺垫日常，
  /// 一章就散了。打分让**事件库按相位出场**，把 71 个事件用出结构感。
  /// 【平手怎么办】调用方在最高分集合里用既有确定性 rng 抽一个，
  /// 保证同回合可复现（§0 第 9 条）。
  static int scoreEvent(GameEvent event, NarrativePhase phase) {
    final t = event.type;
    switch (phase) {
      case NarrativePhase.introduce:
        // 建立认知：日常见闻、家族事务，经济次之，政治/战争压后。
        if (t == EventType.daily || t == EventType.family) return 4;
        if (t == EventType.economic) return 3;
        if (t == EventType.political || t == EventType.war) return 1;
        return 2;
      case NarrativePhase.escalate:
        // 冲突升级：经济压力、宗教/超自然阴影、旅途凶险。
        if (t == EventType.economic) return 4;
        if (t == EventType.religious || t == EventType.adventure) return 3;
        if (t == EventType.daily) return 2;
        return 2;
      case NarrativePhase.turn:
        // 章节承重墙：政治剧变、战争、超自然，必须够份量。
        if (t == EventType.political || t == EventType.war) return 4;
        if (t == EventType.supernatural || t == EventType.religious) return 3;
        return 1;
      case NarrativePhase.resolve:
        // 结算与收束：家族/日常的余波，经济清算。
        if (t == EventType.family || t == EventType.daily) return 4;
        if (t == EventType.economic) return 3;
        if (t == EventType.war || t == EventType.political) return 2;
        return 2;
    }
  }

  /// 相位的中文名（面板/叙事里可读）。
  static String phaseLabel(NarrativePhase phase) {
    switch (phase) {
      case NarrativePhase.introduce:
        return '铺垫';
      case NarrativePhase.escalate:
        return '加压';
      case NarrativePhase.turn:
        return '转折';
      case NarrativePhase.resolve:
        return '收束';
    }
  }
}
