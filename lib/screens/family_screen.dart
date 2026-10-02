/// 家族面板：展示玩家所属家族与维斯特洛主要家族。
///
/// 数据来自 GameEngine.families（Batch 2 数据层 27 家族）。
library;

import 'package:flutter/material.dart';

import '../game_engine.dart';
import '../models/family.dart';
import '../theme/westeros_theme.dart';
import '../widgets/theme/ornate.dart';
import 'family_tree_screen.dart';

/// 家族面板。
class FamilyScreen extends StatelessWidget {
  const FamilyScreen({super.key, this.engine});

  /// 可选：传入共享引擎（默认新建，用于独立浏览）。
  final GameEngine? engine;

  @override
  Widget build(BuildContext context) {
    final e = engine ?? (GameEngine()..startNewGame());
    final myFamily = e.playerFamily;
    final families = e.families;

    return Scaffold(
      appBar: AppBar(title: const Text('家族')),
      body: ParchmentBackground(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: <Widget>[
            // 玩家所属家族
            if (myFamily != null) ...[
              const OrnateHeader(icon: Icons.shield_outlined, title: '我的家族'),
              const SizedBox(height: 8),
              _FamilyCard(family: myFamily, highlight: true),
              const SizedBox(height: 8),
              // 家族树入口（Batch 10-20：多代家族树可视化）
              GildedCard(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => FamilyTreeScreen(engine: e),
                    ),
                  );
                },
                padding: const EdgeInsets.all(4),
                child: ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: WesterosColors.gold.withValues(alpha: 0.2),
                      border: Border.all(
                        color: WesterosColors.gold.withValues(alpha: 0.6),
                      ),
                    ),
                    child: const Icon(
                      Icons.account_tree_outlined,
                      size: 20,
                      color: WesterosColors.goldBright,
                    ),
                  ),
                  title: const Text(
                    '查看家族树',
                    style: TextStyle(
                      color: WesterosColors.goldBright,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    '${e.houseName}家 · 第 ${e.generationNumber()} 代'
                    '${e.player.generationRecords.isEmpty ? '' : '（${e.player.generationRecords.length} 位先祖）'}',
                    style: const TextStyle(color: WesterosColors.inkDim),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: WesterosColors.goldBright,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            // 全部家族
            OrnateHeader(
              icon: Icons.flag_outlined,
              title: '维斯特洛家族（${families.length}）',
            ),
            const SizedBox(height: 8),
            for (final family in families) ...[
              _FamilyCard(family: family),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

/// 单个家族卡片。
class _FamilyCard extends StatelessWidget {
  const _FamilyCard({required this.family, this.highlight = false});

  final Family family;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scaleLabel = switch (family.scale) {
      FamilyScale.great => '大家族',
      FamilyScale.minor => '小家族',
      FamilyScale.household => '家户',
    };
    return Container(
      decoration: BoxDecoration(
        color: highlight
            ? WesterosColors.goldDark.withValues(alpha: 0.14)
            : WesterosColors.barkHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight
              ? WesterosColors.gold.withValues(alpha: 0.7)
              : WesterosColors.outlineGold.withValues(alpha: 0.45),
          width: highlight ? 1.4 : 1,
        ),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: highlight
                  ? WesterosColors.gold.withValues(alpha: 0.25)
                  : WesterosColors.barkMid,
              border: Border.all(
                color: highlight
                    ? WesterosColors.gold.withValues(alpha: 0.7)
                    : WesterosColors.outlineGold.withValues(alpha: 0.4),
              ),
            ),
            child: Icon(
              Icons.shield_outlined,
              size: 20,
              color: highlight ? WesterosColors.goldBright : WesterosColors.inkDim,
            ),
          ),
          title: Text(
            family.name,
            style: TextStyle(
              fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
              color: highlight ? WesterosColors.goldBright : WesterosColors.parchment,
            ),
          ),
          subtitle: Text(
            '${family.motto} · $scaleLabel',
            style: const TextStyle(color: WesterosColors.inkDim),
          ),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _Row('影响力', '${family.influence}'),
                  _Row('人口', '${family.population}'),
                  _Row('军队', '${family.army}'),
                  _Row('金库', '${family.goldReserve}'),
                  if (family.traits.isNotEmpty)
                    _Row('特质', family.traits.join('、')),
                  if (family.secrets.isNotEmpty)
                    _Row('秘密', family.secrets.take(2).join('、')),
                  if (family.relations.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    const Text(
                      '对外关系：',
                      style: TextStyle(color: WesterosColors.goldBright),
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: family.relations.entries
                          .take(8)
                          .map(
                            (e) => Chip(
                              label: Text(
                                '${e.key} ${e.value}',
                                style: const TextStyle(color: WesterosColors.parchment),
                              ),
                              visualDensity: VisualDensity.compact,
                              backgroundColor: WesterosColors.barkMid,
                              side: BorderSide(
                                color: WesterosColors.outlineGold.withValues(alpha: 0.5),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 键值行。
class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 64,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}