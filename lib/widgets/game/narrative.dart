/// 主界面叙事输出区 widget（Batch 10-29 · M3b 从 game_screen 拆出）。
///
/// 含 AI 选项卡片；纯展示，交互一律通过回调上抛。
///
/// Batch 10-60 UI 重造：羊皮纸叙事面板 + 金色选项卡片。
/// S17-1 阅读性重造：**剧情滚动区与选项区分离**。
///
/// 【为什么分离】旧实现把「世界事件选项卡」「AI 选项卡」「面板快捷入口」
/// 三块当作 ListView 的末尾附加项：每回合自动滚到底部时，屏幕上的最新内容
/// 是卡片与入口按钮，剧情正文被顶出视口——用户的原话是「每轮回合都要往上滑
/// 才能看到剧情」。现在剧情单独滚动（滚到底 = 最新剧情），选项固定在下方
/// 独立区（始终可见、超出可自行滚动），互不挤压。
/// 「面板快捷入口」整块删除：AppBar 的导航宫格已有同一批入口，它是纯粹的
/// 底部噪音（每个入口都挤在最新剧情下方）。
library;

import 'package:flutter/material.dart';

import '../../game_engine.dart';
import '../../models/event.dart';
import '../../theme/westeros_theme.dart';
import '../../utils/narrative_format.dart';

/// 叙事输出区。
class NarrativeView extends StatelessWidget {
  const NarrativeView({
    required this.lines,
    required this.scrollController,
    required this.engine,
    required this.aiChoices,
    required this.onChooseAi,
    this.worldEvent,
    this.onChooseWorldEvent,
  });

  final List<String> lines;
  final ScrollController scrollController;
  final GameEngine engine;
  final List<EventChoice> aiChoices;
  final ValueChanged<EventChoice> onChooseAi;

  /// 待决的世界事件（S4-5）：月度传闻浮现后等待玩家抉择；null = 无。
  ///
  /// 【为什么与 aiChoices 分开两块渲染】两者语义不同：AI 选项属于
  /// 「AI 现场生成的下一步」，世界事件选项属于「事件库预写的抉择」。
  /// 混在一起会让玩家分不清哪张卡来自哪里。
  final GameEvent? worldEvent;

  /// 抉择世界事件选项的回调（未传时该区块不渲染）。
  final ValueChanged<EventChoice>? onChooseWorldEvent;

  @override
  Widget build(BuildContext context) {
    final hasWorldEvent = worldEvent != null && onChooseWorldEvent != null;
    final hasAiChoices = aiChoices.isNotEmpty;
    // 两块选项**共用**一个高度上限：各自限高会在「世界事件 + AI 选项同时存在」
    // 时叠加（0.38 + 0.38），把剧情区挤成 0 高——那正是本 widget 要修的病。
    final Widget? choices = (hasWorldEvent || hasAiChoices)
        ? ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.42,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // 待决世界事件：固定在剧情下方，不参与剧情滚动。
                  if (hasWorldEvent)
                    _ChoiceSection(
                      title: Row(
                        children: <Widget>[
                          Icon(
                            Icons.gavel_outlined,
                            size: 16,
                            color: Theme.of(context).colorScheme.tertiary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${worldEvent!.name}·如何应对',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                        ],
                      ),
                      cards: <Widget>[
                        for (var i = 0; i < worldEvent!.choices.length; i++)
                          AiChoiceCard(
                            ordinal: choiceOrdinal(i),
                            choice: worldEvent!.choices[i],
                            onTap: () =>
                                onChooseWorldEvent!(worldEvent!.choices[i]),
                          ),
                      ],
                    ),
                  // AI 选项：固定在剧情下方，不参与剧情滚动。
                  if (hasAiChoices)
                    _ChoiceSection(
                      title: Row(
                        children: <Widget>[
                          Icon(
                            Icons.alt_route,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text('选择你的下一步',
                              style: Theme.of(context).textTheme.titleSmall),
                        ],
                      ),
                      cards: <Widget>[
                        for (var i = 0; i < aiChoices.length; i++)
                          AiChoiceCard(
                            ordinal: choiceOrdinal(i),
                            choice: aiChoices[i],
                            onTap: () => onChooseAi(aiChoices[i]),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          )
        : null;
    return Column(
      children: <Widget>[
        // 剧情（含指令回执）滚动区：最新在底部，滚到底就是最新剧情。
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.all(12),
            itemCount: lines.length,
            itemBuilder: (context, index) => _buildLine(context, lines[index]),
          ),
        ),
        if (choices != null) choices,
      ],
    );
  }

  /// 渲染一行叙事：`> ` 开头的是玩家指令回显（右对齐、金色），其余是叙事。
  Widget _buildLine(BuildContext context, String line) {
    final theme = Theme.of(context);
    final isCommand = line.startsWith('> ');
    // 叙事行：分段渲染（长叙事拆为短段落，逐段展示）
    final segments = isCommand ? <String>[line] : splitNarrative(line);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: isCommand ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: isCommand ? 260 : 640,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isCommand
                ? WesterosColors.goldDark.withValues(alpha: 0.22)
                : WesterosColors.barkHigh,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isCommand
                  ? WesterosColors.gold.withValues(alpha: 0.4)
                  : WesterosColors.outlineGold.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (var i = 0; i < segments.length; i++)
                Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : 4),
                  child: Text(
                    segments[i],
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: isCommand ? null : 'serif',
                      letterSpacing: isCommand ? null : 0.3,
                      height: 1.6,
                      color: isCommand
                          ? WesterosColors.goldBright
                          : WesterosColors.parchment,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 固定在剧情区下方的一块选项区（S17-1）。
///
/// 只负责外观：高度上限与滚动由调用方统一施加（两块选项共用屏高 42% 的额度），
/// 因此**永远不会把剧情正文挤出屏幕**——那正是「必须往上滑才看得到剧情」的成因。
class _ChoiceSection extends StatelessWidget {
  const _ChoiceSection({required this.title, required this.cards});

  /// 区块标题（含图标）。
  final Widget title;

  /// 选项卡片。
  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    // 限高与滚动交给调用方（两块选项共用一个上限），本区块只负责外观。
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: WesterosColors.barkBase,
        border: Border(
          top: BorderSide(
            color: WesterosColors.outlineGold.withValues(alpha: 0.6),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          title,
          const SizedBox(height: 6),
          ...cards,
        ],
      ),
    );
  }
}

/// AI 选项卡片：编号 + 效果预览。
class AiChoiceCard extends StatelessWidget {
  const AiChoiceCard({
    required this.ordinal,
    required this.choice,
    required this.onTap,
  });

  final String ordinal;
  final EventChoice choice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labels = effectLabels(choice.effects);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: WesterosColors.barkHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: WesterosColors.gold.withValues(alpha: 0.55),
            width: 1.2,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // 金色编号徽章
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        WesterosColors.goldDark,
                        WesterosColors.gold,
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: WesterosColors.gold.withValues(alpha: 0.3),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Text(
                    ordinal,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: WesterosColors.barkDeep,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        choice.text,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontFamily: 'serif',
                          letterSpacing: 0.4,
                          height: 1.35,
                          color: WesterosColors.goldBright,
                        ),
                      ),
                      // 后果预览只占一行：它是辅助信息，把高度让给剧情正文。
                      if (choice.narrative.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          choice.narrative,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: <Widget>[
                          for (final label in labels)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: WesterosColors.goldDark
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: WesterosColors.outlineGold
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                              child: Text(
                                label,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: WesterosColors.goldBright,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
