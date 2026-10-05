/// AI 回合混入：编排一次 AI 行动 + 应用 AI 生成的选项效果并推进世界。
///
/// 依赖 [GamePlayMixin]（advanceMonth）与 [GameLetterMixin]（maybeTriggerLetter），
/// 宿主混入这两个 mixin 后即可调用 [runAiAction] / [applyAiChoice]。
///
/// Batch 10-29 · M3b：新增 [runAiAction]，把「读配置 → 拼上下文 → 请求 → 装配结果」
/// 这条编排链从 `screens/game_screen.dart` 下沉到本混入层；
/// UI 只负责持 loading 态、把 [AiTurnResult] 渲染成叙事行与选项卡片。
library;

import '../data/item_data.dart';
import '../models/ai_turn.dart';
import '../models/event.dart';
import '../providers/game_provider_base.dart';
import '../services/ai_config.dart';
import '../services/ai_service.dart';
import '../utils/labels.dart';
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
    // 【为什么按 before/after 求差而不是直接读 choice.effects】
    // ① 真实 delta 才是玩家关心的（`skills.sword: 1` 落在已满级上、
    //    `skills.sword: -5` 被 `max(0, ...)` 破底、`relations.*` 被
    //    ±100 钳制时，读 effects 会给出与实际落盘不符的数字）；
    // ② 写侧守卫（10-91/92）会静默跳过幽灵键，求差自动不显示它们，
    //    无需在摘要侧再复刻一遍白名单判定（避免两处规则漂移）。
    final goldDelta = player.gold - before.gold;
    final repDelta = player.reputation - before.reputation;
    if (goldDelta != 0) {
      buf.writeln('💰 金币 ${goldDelta > 0 ? '+' : ''}$goldDelta（${player.gold}）');
    }
    if (repDelta != 0) {
      buf.writeln('🌟 声望 ${repDelta > 0 ? '+' : ''}$repDelta（${player.reputation}）');
    }
    _writeMapDeltas(buf, before.skills, player.skills, skillLabel, '⚔️');
    _writeMapDeltas(buf, before.attributes, player.attributes, attributeLabel, '🛡️');
    _writeRelationDeltas(buf, before.relations, player.relations);
    _writeInventoryDeltas(buf, before.inventory, player.inventory);
    // Batch 10-94：被写侧守卫拒绝的效果键可见化（详见 provider 侧注释）。
    final rejected = lastRejectedEffectKeys;
    if (rejected.isNotEmpty) {
      buf.writeln('（其中 ${rejected.length} 项效果未生效：${rejected.join('、')}）');
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

  /// 通用 Map<int> 数值差摘要行（金币之外的技能/属性走这条）。
  ///
  /// [label] 负责把英文键翻成中文（`skillLabel`/`attributeLabel`），
  /// 兜底仍是键本身——与 UI 侧标签函数的既有行为一致。
  void _writeMapDeltas(
    StringBuffer buf,
    Map<String, int> before,
    Map<String, int> after,
    String Function(String key) label,
    String icon,
  ) {
    for (final entry in after.entries) {
      final key = entry.key;
      final delta = entry.value - (before[key] ?? 0);
      if (delta == 0) continue;
      buf.writeln(
        '$icon ${label(key)} ${delta > 0 ? '+' : ''}$delta（${entry.value}）',
      );
    }
  }

  /// 关系差摘要行：`🤝 提利昂·兰尼斯特 +10（30）`。
  ///
  /// NPC 中文名走宿主继承的 [npcById]（`GameProviderBase` 的实例方法，
  /// 查的是注入的 NPC 列表——测试可注入假 NPC），未知 id 退回 id 本身
  /// （不抛），与 `labels` 标签函数的兜底策略一致。
  void _writeRelationDeltas(
    StringBuffer buf,
    Map<String, int> before,
    Map<String, int> after,
  ) {
    for (final entry in after.entries) {
      final key = entry.key;
      final delta = entry.value - (before[key] ?? 0);
      if (delta == 0) continue;
      final name = npcById(key)?.name ?? key;
      buf.writeln('🤝 $name ${delta > 0 ? '+' : ''}$delta（${entry.value}）');
    }
  }

  /// 背包差摘要行：`🎒 黑面包 +2` / `🎒 黑面包 -1（已全部用尽）`。
  ///
  /// 物品中文名走 [itemName]（未知 id 退回 id 本身）——与 10-87 背包段
  /// 「中文名 + 数量」的既定口径一致，**不在此处泄漏英文 id**。
  void _writeInventoryDeltas(
    StringBuffer buf,
    List<String> before,
    List<String> after,
  ) {
    final beforeCount = <String, int>{};
    for (final id in before) {
      beforeCount[id] = (beforeCount[id] ?? 0) + 1;
    }
    final afterCount = <String, int>{};
    for (final id in after) {
      afterCount[id] = (afterCount[id] ?? 0) + 1;
    }
    for (final entry in afterCount.entries) {
      final id = entry.key;
      final delta = entry.value - (beforeCount[id] ?? 0);
      if (delta == 0) continue;
      buf.writeln('🎒 ${itemName(id)} ${delta > 0 ? '+' : ''}$delta');
    }
    // 全部用尽的物品不会出现在 afterCount 里，需单列。
    for (final entry in beforeCount.entries) {
      if (afterCount.containsKey(entry.key)) continue;
      buf.writeln('🎒 ${itemName(entry.key)} ${entry.value}（已全部用尽）');
    }
  }
}