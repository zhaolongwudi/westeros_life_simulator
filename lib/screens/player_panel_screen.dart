/// 玩家详情面板：完整展示玩家状态（属性/技能/关系/标记）。
///
/// 复用 GameEngine.formatPlayerPanel 的文本 + 结构化卡片展示。
library;

import 'package:flutter/material.dart';

import '../data/item_data.dart';
import '../game_engine.dart';

/// 玩家详情面板。
class PlayerPanelScreen extends StatelessWidget {
  const PlayerPanelScreen({super.key, this.engine});

  /// 可选：传入共享引擎（默认新建，用于独立浏览）。
  final GameEngine? engine;

  @override
  Widget build(BuildContext context) {
    final e = engine ?? GameEngine()..startNewGame();
    final p = e.player;
    final fam = e.playerFamily;
    final loc = e.currentLocation;

    return Scaffold(
      appBar: AppBar(title: const Text('玩家详情')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          // 身份卡片
          Card(
            child: ListTile(
              leading: CircleAvatar(
                child: Text(p.name.isEmpty ? '?' : p.name.substring(0, 1)),
              ),
              title: Text(p.name, style: Theme.of(context).textTheme.titleLarge),
              subtitle: Text(
                '${p.identity.name} · ${p.age}岁 · ${p.gender == 'male' ? '男' : '女'}',
              ),
            ),
          ),
          // 家族与地点
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.family_restroom),
                  title: const Text('家族'),
                  subtitle: Text(
                    '${fam?.name ?? '无'}（${fam?.motto ?? ''}）\n'
                    '影响力 ${fam?.influence ?? '?'} · 军队 ${fam?.army ?? '?'}',
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.place_outlined),
                  title: const Text('所在地'),
                  subtitle: Text(
                    '${loc?.name ?? p.locationId}（${loc?.region ?? ''}）\n'
                    '危险度 ${loc?.dangerLevel ?? '?'} · 人口 ${loc?.population ?? '?'}',
                  ),
                ),
              ],
            ),
          ),
          // 财富与声望
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.paid_outlined),
                  title: const Text('金币'),
                  trailing: Text('${p.gold}', style: Theme.of(context).textTheme.titleMedium),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.star_outline),
                  title: const Text('声望'),
                  trailing: Text('${p.reputation}', style: Theme.of(context).textTheme.titleMedium),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.favorite_outline),
                  title: const Text('生命 / 精力 / 饱食'),
                  trailing: Text(
                    '${p.health} / ${p.energy} / ${p.hunger}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (p.title.isNotEmpty) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.workspace_premium_outlined),
                    title: const Text('头衔'),
                    trailing: Text(
                      p.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // 属性
          _SectionCard(
            title: '属性',
            icon: Icons.accessibility_new,
            entries: p.attributes.entries
                .map((e) => _Entry(e.key, '${e.value}'))
                .toList(),
          ),
          // 技能
          _SectionCard(
            title: '技能',
            icon: Icons.school_outlined,
            entries: p.skills.entries
                .map((e) => _Entry(e.key, '${e.value}'))
                .toList(),
          ),
          // 装备（Batch 10-4：武器/护甲/坐骑 + 战斗值）
          if (e.equippedItems.isNotEmpty)
            _SectionCard(
              title: '装备（战斗值 ${e.combatPower()}）',
              icon: Icons.shield_outlined,
              entries: e.equippedItems
                  .map((id) {
                    final item = itemById(id);
                    return _Entry(item?.name ?? id, '');
                  })
                  .toList(),
            ),
          // 关系
          if (p.relations.isNotEmpty)
            _SectionCard(
              title: '关系',
              icon: Icons.people_outline,
              entries: p.relations.entries
                  .map((e) => _Entry(e.key, '${e.value}'))
                  .toList(),
            ),
          // 状态标记
          if (p.flags.isNotEmpty)
            _SectionCard(
              title: '状态标记',
              icon: Icons.flag_outlined,
              entries: p.flags.entries
                  .map((e) => _Entry(e.key, '${e.value}'))
                  .toList(),
            ),
          // 背包
          if (p.inventory.isNotEmpty)
            _SectionCard(
              title: '背包',
              icon: Icons.inventory_2_outlined,
              entries: p.inventory.map((e) => _Entry(e, '')).toList(),
            ),
        ],
      ),
    );
  }
}

/// 分节卡片。
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.entries,
  });

  final String title;
  final IconData icon;
  final List<_Entry> entries;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: entries
                  .map(
                    (e) => Chip(
                      label: Text(
                        e.value.isEmpty ? e.key : '${e.key} ${e.value}',
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

/// 键值对条目。
class _Entry {
  const _Entry(this.key, this.value);

  final String key;
  final String value;
}
