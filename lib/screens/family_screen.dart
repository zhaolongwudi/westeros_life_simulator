/// 家族面板：展示玩家所属家族与维斯特洛主要家族。
///
/// 数据来自 GameEngine.families（Batch 2 数据层 27 家族）。
library;

import 'package:flutter/material.dart';

import '../game_engine.dart';
import '../models/family.dart';

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
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: <Widget>[
          // 玩家所属家族
          if (myFamily != null) ...[
            Text('我的家族', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _FamilyCard(family: myFamily, highlight: true),
            const SizedBox(height: 16),
          ],
          // 全部家族
          Text('维斯特洛家族（${families.length}）',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final family in families) ...[
            _FamilyCard(family: family),
            const SizedBox(height: 8),
          ],
        ],
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
    return Card(
      color: highlight ? theme.colorScheme.primaryContainer : null,
      child: ExpansionTile(
        leading: Icon(
          Icons.shield_outlined,
          color: highlight ? theme.colorScheme.primary : null,
        ),
        title: Text(
          family.name,
          style: TextStyle(
            fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Text('${family.motto} · $scaleLabel'),
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
                  const Text('对外关系：'),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: family.relations.entries
                        .take(8)
                        .map(
                          (e) => Chip(
                            label: Text('${e.key} ${e.value}'),
                            visualDensity: VisualDensity.compact,
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