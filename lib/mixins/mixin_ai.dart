/// AI 回合混入：编排一次 AI 行动 + 应用 AI 生成的选项效果并推进世界。
///
/// S16 起本混入还承载**剧情回路**（[runStoryTurn]）：每回合自己开局，主 AI
/// 不可用时由本地剧情导演接手，玩家不必打字也有剧情与选项。
///
/// 依赖 [GamePlayMixin]（advanceMonth，内含月度管线，信件由管线钩子触发）；
/// 宿主混入 [GamePlayMixin] 后即可调用 [runAiAction] / [applyAiChoice]。
/// S12-10 起不再直接依赖 [GameLetterMixin] 的 `maybeTriggerLetter`。
///
/// Batch 10-29 · M3b：新增 [runAiAction]，把「读配置 → 拼上下文 → 请求 → 装配结果」
/// 这条编排链从 `screens/game_screen.dart` 下沉到本混入层；
/// UI 只负责持 loading 态、把 [AiTurnResult] 渲染成叙事行与选项卡片。
library;

import '../core/story_director.dart';
import '../models/ai_turn.dart';
import '../models/event.dart';
import '../providers/game_provider_base.dart';
import '../services/ai_config.dart';
import '../services/ai_service.dart';
import 'mixin_letter.dart';
import 'mixin_life.dart';
import 'mixin_play.dart';
import 'mixin_systems.dart';

/// AI 回合混入。挂在 [GameProviderBase] 上。
mixin GameAiMixin
    on GameProviderBase, GameSystemsMixin, GameLifeMixin, GamePlayMixin, GameLetterMixin {
  /// 编排一次 AI 行动：读取本地 AI 配置 → 拼世界上下文 → 请求叙事与选项。
  ///
  /// 返回 [AiTurnResult]（叙事行 + 可点选选项），UI 只需渲染。
  /// 三类失败均以 [AiTurnResult.isSuccess] 为 false 返回，不抛异常：
  /// - 游戏未开始 → `游戏尚未开始。`
  /// - 未配置 API Key → 引擎常量 [AiTurnResult.notConfiguredLine]
  /// - 请求失败 / 叙事为空 → `⚠️ AI 生成失败：<原因>`
  ///
  /// [service] 仅供测试注入 mock，生产路径为 null（内部按 [AiConfig] 新建）。
  Future<AiTurnResult> runAiAction(String action, {AiService? service}) async {
    if (!isGameActive || isGameOver) {
      return const AiTurnResult(
        lines: <String>[AiTurnResult.notStartedLine],
        choices: <EventChoice>[],
      );
    }

    final config = await AiConfig.load();
    if (!config.isConfigured) {
      return const AiTurnResult(
        lines: <String>[AiTurnResult.notConfiguredLine],
        choices: <EventChoice>[],
      );
    }

    final ai = service ??
        AiService(
          apiKeys: config.apiKeys,
          model: config.resolvedModel,
          baseUrl: config.resolvedBaseUrl,
        );
    final context = worldSnapshot() +
        '\n\n玩家行动：$action\n\n请根据当前世界状态生成叙事与选项。';

    final response = await ai.generateNarrative(
      player: player,
      context: context,
      availableEvents: eventTemplates,
      season: progress.season,
      currentYear: progress.year,
    );

    if (!response.isSuccess || response.narrative.isEmpty) {
      return AiTurnResult(
        lines: <String>[
          '⚠️ AI 生成失败：${response.errorMessage ?? '未知错误'}',
          AiTurnResult.degradedLine,
        ],
        choices: const <EventChoice>[],
      );
    }

    final lines = <String>[response.narrative];
    if (response.choices.isNotEmpty) {
      lines.add('（选择你的下一步）');
    }
    return AiTurnResult(
      lines: lines,
      choices: response.choices,
      isSuccess: true,
    );
  }

  /// 剧情模式：推进一回合——主 AI 说书，不可用时本地导演接手（S16）。
  ///
  /// 与 [runAiAction] 的分工：那条通道要玩家**先打字**再说，且未配置 Key 时
  /// 直接返回「请先配置」——玩家不打字就永远没有剧情。本方法让剧情回合
  /// **自己开局**：AI 可用时把局势交给主 AI 生成叙事与 2-4 个选项；未配置
  /// Key 或请求失败时由 [StoryDirector] 用事件库 + 当前处境产出同样结构的
  /// 「剧情 + 选项」。两条路的返回结构一致，UI 不需要分叉。
  ///
  /// [intent] 可选：玩家本回合的自由行动（自然语言），会并入 AI 上下文。
  Future<AiTurnResult> runStoryTurn({String? intent, AiService? service}) async {
    if (!isGameActive || isGameOver) {
      return const AiTurnResult(
        lines: <String>[AiTurnResult.notStartedLine],
        choices: <EventChoice>[],
      );
    }
    // 待决事件由本回合接管呈现（见 `_localStoryTurn` 与调用方）：先记下来，
    // 免得推进过程中被后续状态覆盖。
    final pending = pendingEvent;
    // 显式注入的 service 优先于本地配置（测试与备用后端用）；生产路径为 null，
    // 此时按配置判断主 AI 是否可用。
    final injected = service;
    final config =
        injected == null ? await _loadAiConfig() : AiConfig.defaultConfig();

    if (injected != null || config.isConfigured) {
      final ai = injected ??
          AiService(
            apiKeys: config.apiKeys,
            model: config.resolvedModel,
            baseUrl: config.resolvedBaseUrl,
          );
      final response = await ai.generateNarrative(
        player: player,
        context: _storyContext(intent, pending: pending),
        availableEvents: eventTemplates,
        season: progress.season,
        currentYear: progress.year,
      );
      if (response.isSuccess &&
          response.narrative.isNotEmpty &&
          response.choices.isNotEmpty) {
        if (pending != null) setPendingEvent(null);
        return AiTurnResult(
          lines: <String>[response.narrative],
          choices: response.choices,
          isSuccess: true,
        );
      }
      return _localStoryTurn(
        pending: pending,
        note: '⚠️ 主 AI 本回合不可用（${response.errorMessage ?? '未知错误'}），'
            '已由本地剧情导演接手。',
      );
    }

    return _localStoryTurn(
      pending: pending,
      note: 'ℹ️ 未配置 AI Key，本回合由本地剧情导演推进；'
          '到「设置 / 存档」→ AI 配置填入 Key 后由主 AI 接管叙事。',
    );
  }

  /// 应用剧情回合的选项：效果落盘 + 效果摘要 + 推进一个月。
  ///
  /// 剧情回路的唯一落盘入口。刻意复用 [applyAiChoice] 而不是另写一条：
  /// 本项目已经发生过五次「双通道漂移」，选项落盘只能有一份实现。
  String applyStoryChoice(EventChoice choice) => applyAiChoice(choice);

  /// 读取 AI 配置；读失败（插件缺失 / 存储损坏）按「未配置」处理。
  ///
  /// 剧情回路**每回合**都要读配置，而配置是外部依赖：让一个读盘异常把整条
  /// 剧情打断，等于把主流程的可用性押在插件健康度上。
  Future<AiConfig> _loadAiConfig() async {
    try {
      return await AiConfig.load();
    } on Object {
      return AiConfig.defaultConfig();
    }
  }

  /// 本地剧情导演通道：产出「剧情 + 选项」，返回结构与 AI 通道一致。
  AiTurnResult _localStoryTurn({GameEvent? pending, String note = ''}) {
    final bool Function(EventChoice) canChoose =
        (EventChoice c) => eventProvider.canChoose(c, player);
    final scene = pending != null
        ? StoryDirector.narrate(
            event: pending,
            player: player,
            year: progress.year,
            month: progress.month,
            season: progress.season,
            turnCount: progress.turnCount,
            location: currentLocation,
            familyName: playerFamily?.name ?? '',
            onSiteNpcs: npcsAtCurrentLocation,
            canChoose: canChoose,
          )
        : StoryDirector.direct(
            player: player,
            year: progress.year,
            month: progress.month,
            season: progress.season,
            turnCount: progress.turnCount,
            availableEvents: eventProvider.getAvailableEvents(
              player,
              season: progress.season,
            ),
            location: currentLocation,
            familyName: playerFamily?.name ?? '',
            onSiteNpcs: npcsAtCurrentLocation,
            canChoose: canChoose,
          );
    // 一次性事件在「讲述」时即标记完成：否则同一条一次性传闻会被反复讲
    // （与 `mixin_play._maybeWorldEvent` 的标记点一致）。
    final sceneEventId = scene.eventId;
    if (sceneEventId != null) {
      for (final e in eventProvider.allEvents) {
        if (e.id == sceneEventId && e.isOneTime) {
          eventProvider.markCompleted(sceneEventId);
          break;
        }
      }
    }
    if (pending != null) setPendingEvent(null);
    return AiTurnResult(
      lines: <String>[scene.narrative],
      choices: scene.choices,
      isSuccess: true,
      isLocal: true,
      note: note,
    );
  }

  /// 剧情模式的上下文：在既有世界快照之上加「说书人」指令与输出要求。
  String _storyContext(String? intent, {GameEvent? pending}) {
    final buf = StringBuffer()
      ..writeln(worldSnapshot())
      ..writeln()
      ..writeln('【剧情模式】你是这段人生的说书人：主动让故事向前走，'
          '不要等玩家提问，也不要让这个月什么都不发生。');
    final action = intent?.trim() ?? '';
    if (action.isEmpty) {
      buf.writeln('玩家本回合没有指定行动，请让世界自己推进。');
    } else {
      buf.writeln('玩家本回合的自由行动：$action');
    }
    if (pending != null) {
      buf.writeln('本回合已浮现的待决事件：${pending.name}——${pending.description}'
          '（请在叙事中围绕它展开）。');
    }
    buf.writeln('请输出本月叙事（200-500 字）与 2-4 个选项；'
        '每个选项都必须写明代价（至少含一项负向效果或门槛），'
        '禁止给出三个效果相同或纯收益的选项。');
    return buf.toString();
  }

  /// 应用 AI 生成的选项效果，并推进一个月（含月度系统结算 + 信件触发）。
  ///
  /// 返回完整的回合叙事文本（供 AI 行动模式展示）。
  /// AI 选项效果支持 gold / reputation / skills.<name> / attributes.<name>。
  ///
  /// 【Batch 10-93】效果摘要覆盖 gold/reputation/skills/attributes/
  /// relations/inventory 六类，全部按 before/after 求真实 delta、
  /// 标签一律走中文（`skillLabel`/`attributeLabel`/`npcById`/`itemName`）。
  /// 【Batch 10-94】被写侧守卫拒绝的效果键输出一行提示（见
  /// [lastRejectedEffectKeys]），不再让「叙事写了、状态没变」静默发生。
  String applyAiChoice(EventChoice choice) {
    if (!isGameActive || isGameOver) {
      return '游戏尚未开始。';
    }
    // 1. 效果落盘
    final before = player;
    updatePlayer(applyEffects(player, choice.effects));
    final buf = StringBuffer();
    if (choice.narrative.isNotEmpty) {
      buf.writeln(choice.narrative);
    }
    // 2. 效果摘要（仅当有变化时）
    //
    // Batch 10-93：补齐 skills/attributes/relations/inventory 四类摘要。
    // 此前只输出金币/声望两条，AI 写 `skills.sword: 1` 落盘后玩家在
    // 回合文本里看不到任何反馈——状态变了但叙事无痕，与「幽灵键被
    // 静默丢弃」叠加时更是彻底看不出发生了什么。
    //
    // 【S4-5 起摘要实现上提到基类】`effectSummary` 在 `GameProviderBase`，
    // 与事件通道（`mixin_play.chooseWorldEventChoice`）**共用同一份**——
    // 本项目已发生五次双通道漂移，不能再抄第六份。
    buf.write(effectSummary(before));
    // 3. 月度推进（系统结算 + 时间 + **NPC 来信**）
    //
    // S12-10：信件已改为挂在月度管线上（`registerLetterMonthlyHooks`），
    // 而 [advanceMonth] 就会跑完管线 —— 故这里**不再**单独调
    // `maybeTriggerLetter`。此前那条单独调用是「AI 路径才有信」的成因；
    // 保留它会与管线钩子重复调用同一函数（靠 `_lastLetterMonth` 冷却
    // 侥幸不双触发，但那是隐式契约、极易再次踩坑）。
    buf.writeln(advanceMonth());
    return buf.toString().trim();
  }
}
