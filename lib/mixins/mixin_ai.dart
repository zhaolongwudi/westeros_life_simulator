/// AI 回合混入：编排一次 AI 行动 + 应用 AI 生成的选项效果并推进世界。
///
/// 依赖 [GamePlayMixin]（advanceMonth，内含月度管线，信件由管线钩子触发）；
/// 宿主混入 [GamePlayMixin] 后即可调用 [runAiAction] / [applyAiChoice]。
/// S12-10 起不再直接依赖 [GameLetterMixin] 的 `maybeTriggerLetter`。
///
/// Batch 10-29 · M3b：新增 [runAiAction]，把「读配置 → 拼上下文 → 请求 → 装配结果」
/// 这条编排链从 `screens/game_screen.dart` 下沉到本混入层；
/// UI 只负责持 loading 态、把 [AiTurnResult] 渲染成叙事行与选项卡片。
library;

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
