/// AI 回合混入：编排一次 AI 行动 + 应用 AI 生成的选项效果并推进世界。
///
/// 依赖 [GamePlayMixin]（advanceMonth）与 [GameLetterMixin]（maybeTriggerLetter），
/// 宿主混入这两个 mixin 后即可调用 [runAiAction] / [applyAiChoice]。
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
          apiKey: config.apiKey,
          model: config.model,
          baseUrl: config.baseUrl,
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
    final goldDelta = player.gold - before.gold;
    final repDelta = player.reputation - before.reputation;
    if (goldDelta != 0) {
      buf.writeln('💰 金币 ${goldDelta > 0 ? '+' : ''}$goldDelta（${player.gold}）');
    }
    if (repDelta != 0) {
      buf.writeln('🌟 声望 ${repDelta > 0 ? '+' : ''}$repDelta（${player.reputation}）');
    }
    // 3. 月度推进（系统结算 + 时间）
    buf.writeln(advanceMonth());
    // 4. NPC 主动来信（月度触发）
    final letter = maybeTriggerLetter(seed: progress.turnCount);
    if (letter.isNotEmpty) {
      buf.writeln(letter);
    }
    return buf.toString().trim();
  }
}