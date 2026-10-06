/// 主界面叙事输出区 widget（Batch 10-29 · M3b 从 game_screen 拆出）。
///
/// 含 AI 选项卡片与面板快捷入口；纯展示，交互一律通过回调上抛。
///
/// Batch 10-60 UI 重造：羊皮纸叙事面板 + 金色选项卡片。
library;

import 'package:flutter/material.dart';

import '../../game_engine.dart';
import '../../models/event.dart';
import '../../theme/westeros_theme.dart';
import '../../utils/narrative_format.dart';
import '../../screens/family_screen.dart';
import '../../screens/map_screen.dart';
import '../../screens/npc_panel_screen.dart';
import '../../screens/player_panel_screen.dart';
import '../../screens/systems_screen.dart';

/// 叙事输出区。
class NarrativeView extends StatelessWidget {
  const NarrativeView({
    required this.lines,
    required this.scrollController,
    required this.engine,
    required this.onOpenPanel,
    required this.aiChoices,
    required this.onChooseAi,
  });

  final List<String> lines;
  final ScrollController scrollController;
  final GameEngine engine;
  final ValueChanged<Widget> onOpenPanel;
  final List<EventChoice> aiChoices;
  final ValueChanged<EventChoice> onChooseAi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 末尾附加项：AI 选项卡片 + 面板快捷入口
    final extraCount = (aiChoices.isNotEmpty ? 1 : 0) + 1;
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: lines.length + extraCount,
      itemBuilder: (context, index) {
        // 末尾：AI 选项（如有）
        if (aiChoices.isNotEmpty && index == lines.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.alt_route,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text('选择你的下一步', style: theme.textTheme.titleSmall),
                  ],
                ),
                const SizedBox(height: 6),
                for (var i = 0; i < aiChoices.length; i++)
                  AiChoiceCard(
                    ordinal: choiceOrdinal(i),
                    choice: aiChoices[i],
                    onTap: () => onChooseAi(aiChoices[i]),
                  ),
              ],
            ),
          );
        }
        // 末尾附：面板快捷入口
        if (index == lines.length + (aiChoices.isNotEmpty ? 1 : 0)) {
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                PanelEntry(
                  icon: Icons.person_outline,
                  label: '玩家详情',
                  color: theme.colorScheme.primary,
                  onTap: () => onOpenPanel(PlayerPanelScreen(engine: engine)),
                ),
                PanelEntry(
                  icon: Icons.family_restroom,
                  label: '家族面板',
                  color: theme.colorScheme.tertiary,
                  onTap: () => onOpenPanel(FamilyScreen(engine: engine)),
                ),
                PanelEntry(
                  icon: Icons.people_alt_outlined,
                  label: 'NPC 关系',
                  color: theme.colorScheme.tertiary,
                  onTap: () => onOpenPanel(NpcPanelScreen(engine: engine)),
                ),
                PanelEntry(
                  icon: Icons.grid_view_outlined,
                  label: '系统面板',
                  color: theme.colorScheme.secondary,
                  onTap: () => onOpenPanel(SystemsScreen(engine: engine)),
                ),
                PanelEntry(
                  icon: Icons.map_outlined,
                  label: '地图',
                  color: theme.colorScheme.primary,
                  onTap: () => onOpenPanel(MapScreen(engine: engine)),
                ),
              ],
            ),
          );
        }

        final line = lines[index];
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
      },
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
            padding: const EdgeInsets.all(12),
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
                            fontFamily: 'serif', letterSpacing: 0.4, height: 1.35,
                            color: WesterosColors.goldBright,
                        ),
                      ),
                      if (choice.narrative.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          choice.narrative,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
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

/// 面板快捷入口按钮。
class PanelEntry extends StatelessWidget {
  const PanelEntry({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: color),
      label: Text(label),
      backgroundColor: WesterosColors.barkMid,
      side: BorderSide(
        color: WesterosColors.outlineGold.withValues(alpha: 0.6),
      ),
      labelStyle: const TextStyle(color: WesterosColors.parchment),
      onPressed: onTap,
    );
  }
}
