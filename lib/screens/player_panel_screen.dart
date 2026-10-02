/// 玩家详情面板：完整展示玩家状态（属性/技能/关系/标记）。
///
/// 复用 GameEngine.formatPlayerPanel 的文本 + 结构化卡片展示。
library;

import 'package:flutter/material.dart';

import '../data/item_data.dart';
import '../game_engine.dart';
import '../theme/westeros_theme.dart';
import '../utils/labels.dart';
import '../widgets/game/responsive.dart';
import '../widgets/theme/ornate.dart';

/// 玩家详情面板。
class PlayerPanelScreen extends StatelessWidget {
  const PlayerPanelScreen({super.key, this.engine});

  /// 可选：传入共享引擎（默认新建，用于独立浏览）。
  final GameEngine? engine;

  @override
  Widget build(BuildContext context) {
    // 注意：`??` 优先级高于级联 `..`，必须加括号，否则传入 engine 时
    // (engine ?? GameEngine())..startNewGame() 会重置传入引擎的玩家数据（坑 23）
    final e = engine ?? (GameEngine()..startNewGame());
    final p = e.player;
    final fam = e.playerFamily;
    final loc = e.currentLocation;

    return Scaffold(
      appBar: AppBar(title: const Text('玩家详情')),
      body: SafeArea(
        child: ParchmentBackground(
          child: AdaptiveFrame(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                // 身份卡片
                GildedCard(
                  highlight: true,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: <Widget>[
                      // 金色头像徽章
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: <Color>[
                              WesterosColors.goldDark,
                              WesterosColors.gold,
                            ],
                          ),
                          border: Border.all(
                            color: WesterosColors.goldBright,
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            p.name.isEmpty ? '?' : p.name.substring(0, 1),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: WesterosColors.barkDeep,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              p.name,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: WesterosColors.goldBright,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${identityLabel(p.identity)} · ${p.age}岁 · ${p.gender == 'male' ? '男' : '女'}',
                              style: const TextStyle(color: WesterosColors.inkDim),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // 家族与地点
                GildedCard(
                  child: Column(
                    children: <Widget>[
                      ListTile(
                        leading: const Icon(Icons.family_restroom, color: WesterosColors.goldBright),
                        title: const Text('家族', style: TextStyle(color: WesterosColors.parchment)),
                        subtitle: Text(
                          '${fam?.name ?? '无'}（${fam?.motto ?? ''}）\n'
                          '影响力 ${fam?.influence ?? '?'} · 军队 ${fam?.army ?? '?'}',
                          style: const TextStyle(color: WesterosColors.inkDim),
                        ),
                      ),
                      const Divider(height: 1, indent: 56),
                      ListTile(
                        leading: const Icon(Icons.place_outlined, color: WesterosColors.goldBright),
                        title: const Text('所在地', style: TextStyle(color: WesterosColors.parchment)),
                        subtitle: Text(
                          '${loc?.name ?? p.locationId}（${loc?.region ?? ''}）\n'
                          '危险度 ${loc?.dangerLevel ?? '?'} · 人口 ${loc?.population ?? '?'}',
                          style: const TextStyle(color: WesterosColors.inkDim),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // 财富与声望
                GildedCard(
                  child: Column(
                    children: <Widget>[
                      ListTile(
                        leading: const Icon(Icons.paid_outlined, color: WesterosColors.goldBright),
                        title: const Text('金币', style: TextStyle(color: WesterosColors.parchment)),
                        trailing: Text('${p.gold}',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: WesterosColors.goldBright,
                                  fontWeight: FontWeight.bold,
                                )),
                      ),
                      const Divider(height: 1, indent: 56),
                      ListTile(
                        leading: const Icon(Icons.star_outline, color: WesterosColors.goldBright),
                        title: const Text('声望', style: TextStyle(color: WesterosColors.parchment)),
                        trailing: Text('${p.reputation}',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: WesterosColors.goldBright,
                                  fontWeight: FontWeight.bold,
                                )),
                      ),
                      const Divider(height: 1, indent: 56),
                      ListTile(
                        leading: const Icon(Icons.favorite_outline, color: WesterosColors.bloodRed),
                        title: const Text('生命 / 精力 / 饱食', style: TextStyle(color: WesterosColors.parchment)),
                        trailing: Text(
                          '${p.health} / ${p.energy} / ${p.hunger}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: WesterosColors.parchment,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      if (p.title.isNotEmpty) ...[
                        const Divider(height: 1, indent: 56),
                        ListTile(
                          leading: const Icon(Icons.workspace_premium_outlined, color: WesterosColors.goldBright),
                          title: const Text('头衔', style: TextStyle(color: WesterosColors.parchment)),
                          trailing: Text(
                            p.title,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: WesterosColors.goldBright,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // 属性
                _SectionCard(
                  title: '属性',
                  icon: Icons.accessibility_new,
                  entries: p.attributes.entries
                      .map((e) => _Entry(e.key, '${e.value}'))
                      .toList(),
                ),
                const SizedBox(height: 12),
                // 技能
                _SectionCard(
                  title: '技能',
                  icon: Icons.school_outlined,
                  entries: p.skills.entries
                      .map((e) => _Entry(e.key, '${e.value}'))
                      .toList(),
                ),
                // 装备（Batch 10-4：武器/护甲/坐骑 + 战斗值）
                if (e.equippedItems.isNotEmpty) ...[
                  const SizedBox(height: 12),
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
                ],
                // 家谱（Batch 10-14：家族继承与多世代）
                const SizedBox(height: 12),
                GildedCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const OrnateHeader(icon: Icons.account_tree_outlined, title: '家谱 · 家族'),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '${e.houseName}家（第 ${e.generationNumber()} 代）',
                              style: const TextStyle(color: WesterosColors.goldBright, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text('家主：${p.name}（${p.age}岁）', style: const TextStyle(color: WesterosColors.parchment)),
                            Text('婚姻：${e.isMarried ? '已婚' : '未婚'}', style: const TextStyle(color: WesterosColors.parchment)),
                            Text(
                              p.children.isEmpty
                                  ? '子女：尚无子嗣'
                                  : '子女：${p.children.join('、')}',
                              style: const TextStyle(color: WesterosColors.parchment),
                            ),
                            if (e.heirName != null)
                              Text('继承人：${e.heirName}',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: WesterosColors.goldBright,
                                      )),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // 婚姻与子女培养（Batch 10-19：UI 面板展示婚姻/培养新数据）
                if (e.isMarried || p.children.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  GildedCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const OrnateHeader(icon: Icons.favorite_outline, title: '婚姻与子女培养'),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              if (e.isMarried && p.spouse != null) ...[
                                Text(
                                  '配偶：${p.spouse!.name}'
                                  '（${spouseOriginLabel(p.spouse!.origin)}，'
                                  '结缡 ${e.progress.year - p.spouse!.marriedYear} 年）',
                                  style: const TextStyle(color: WesterosColors.parchment),
                                ),
                                Text(
                                  '感情：${p.spouse!.affection}/100'
                                  '（${e.affectionLabel(p.spouse!.affection)}）',
                                  style: const TextStyle(color: WesterosColors.parchment),
                                ),
                                const SizedBox(height: 4),
                              ],
                              if (p.children.isNotEmpty) ...[
                                Text('子女培养档案：', style: const TextStyle(color: WesterosColors.goldBright)),
                                for (final c in p.children)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 12, top: 2),
                                    child: _buildChildRearingLine(e, c),
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // 关系
                if (p.relations.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: '关系',
                    icon: Icons.people_outline,
                    entries: p.relations.entries
                        .map((e) => _Entry(e.key, '${e.value}'))
                        .toList(),
                  ),
                ],
                // 状态标记
                if (p.flags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: '状态标记',
                    icon: Icons.flag_outlined,
                    entries: p.flags.entries
                        .map((e) => _Entry(e.key, '${e.value}'))
                        .toList(),
                  ),
                ],
                // 背包
                if (p.inventory.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: '背包',
                    icon: Icons.inventory_2_outlined,
                    entries: p.inventory.map((e) => _Entry(e, '')).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
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
    final theme = Theme.of(context);
    return GildedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 18, color: WesterosColors.goldBright),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: WesterosColors.goldBright,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
                      style: const TextStyle(color: WesterosColors.parchment),
                    ),
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

/// 渲染单个子女的培养档案行。
Widget _buildChildRearingLine(GameEngine e, String childName) {
  final text = _childRearingText(e, childName);
  return Text(text, style: const TextStyle(fontSize: 13));
}

/// 生成子女培养档案文本（Batch 10-19）。
String _childRearingText(GameEngine e, String childName) {
  final p = e.player;
  final records = p.childRearing.where((r) => r.name == childName).toList();
  final parts = <String>[];
  if (records.isNotEmpty) {
    final r = records.first;
    if (r.focus.isNotEmpty) parts.add('培养：${r.focus}');
    if (r.tutored) parts.add('已督导');
    if (r.sentToSchool) parts.add('进修中');
    if (r.reputationGain > 0) parts.add('声望 +${r.reputationGain}');
  } else {
    parts.add('尚未培养');
  }
  return '· $childName：${parts.isEmpty ? '无记录' : parts.join(' / ')}';
}
