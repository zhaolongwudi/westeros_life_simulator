/// AI 回合混入：应用 AI 生成的选项效果并推进世界。
///
/// 依赖 [GamePlayMixin]（advanceMonth）与 [GameLetterMixin]（maybeTriggerLetter），
/// 宿主混入这两个 mixin 后即可调用 [applyAiChoice]。
library;

import '../models/event.dart';
import '../providers/game_provider_base.dart';
import 'mixin_letter.dart';
import 'mixin_play.dart';
import 'mixin_systems.dart';

/// AI 回合混入。挂在 [GameProviderBase] 上。
mixin GameAiMixin
    on GameProviderBase, GameSystemsMixin, GamePlayMixin, GameLetterMixin {
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