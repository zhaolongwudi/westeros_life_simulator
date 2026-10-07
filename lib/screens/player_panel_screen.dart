/// 玩家详情面板：完整展示玩家状态（属性/技能/关系/标记）。
///
/// 复用 GameEngine.formatPlayerPanel 的文本 + 结构化卡片展示。
library;

import 'package:flutter/material.dart';

import '../data/item_data.dart';
// Batch 10-100：关系区块把裸 npc id 换成中文名，需 `npcById` 查名。
import '../data/npc_data.dart';
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
                      .map((e) => _Entry(attributeLabel(e.key), '${e.value}'))
                      .toList(),
                ),
                const SizedBox(height: 12),
                // 技能
                _SectionCard(
                  title: '技能',
                  icon: Icons.school_outlined,
                  entries: p.skills.entries
                      .map((e) => _Entry(skillLabel(e.key), '${e.value}'))
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
                        .map((e) => _Entry(_relationName(e), '${e.value}'))
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
                        .map((e) => _Entry(_flagName(e.key), '${e.value}'))
                        .toList(),
                  ),
                ],
                // 背包
                if (p.inventory.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: '背包',
                    icon: Icons.inventory_2_outlined,
                    entries: p.inventory
                        .map((e) => _Entry(_itemName(e), ''))
                        .toList(),
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

/// 关系区块的中文名（Batch 10-100）。
///
/// 【为什么改】关系区块此前直接 `_Entry(e.key, ...)`，把 `npc_tyrion`
/// 这类**裸英文 id** 当标题显示——与 10-87 背包段、10-93 效果摘要
/// 「一律走中文名、不泄漏英文 id」的口径相反，玩家面板是全项目
/// 泄漏英文 id 的最后一处。10-99 补写侧守卫后新幽灵键不会再落盘，
/// 但**旧存档里已积累的幽灵键仍会显示**（存档兼容不做破坏性清洗），
/// 故未知 id 一律回退显示原 id，绝不显示空白或抛错。
///
/// 走顶层 `npc_data.npcById` 而非 `GameEngine.npcById`：本屏已 import
/// `npc_data`，顶层函数与实例方法同名不冲突（此处非 mixin 环境，
/// 无坑 50 的「实例方法优先」歧义）。
String _relationName(MapEntry<String, int> e) =>
    npcById(e.key)?.name ?? e.key;

/// 状态标记区块的中文名（Batch 10-102）。
///
/// 【为什么改】与 10-100 关系区块同型：此前直接 `_Entry(e.key, ...)`，
/// 把 `isAlive` / `equipped.item_sword` / `npc_task.npc_tyrion.xxx`
/// 这类**裸英文键**当标题显示。10-97 补写侧分层白名单后新键不会再落盘，
/// 但**旧存档里已积累的键、以及 5 个动态前缀拼出的键仍会显示**。
///
/// 【为什么动态前缀键回退显示原键而不是空白】`equipped.item_sword`
/// 这类键的动态部分是**物品 id**（可翻中文名），但 `npc_task.` /
/// `npc_story.` / `house.childDead.` 的动态部分是 **NPC id 或中文人名**
/// （人名已是中文，再翻会得到空串）。故只对能确定翻出中文名的前缀
/// 做替换，其余一律回退原键——绝不显示空白、绝不抛错。
///
/// 【单一真相】静态键走 `labels.flagLabel`（与 `identityLabel` /
/// `skillLabel` / `attributeLabel` 同一层），不在本屏硬编码映射表，
/// 避免两处标签表漂移。
String _flagName(String key) {
  final label = flagLabel(key);
  if (label != null) return label;
  // 动态前缀：equipped.<物品 id> 可翻物品中文名
  if (key.startsWith('equipped.')) {
    return '装备·${itemName(key.substring(9))}';
  }
  return key;
}

/// 背包区块的中文名（Batch 10-102）。
///
/// 与 10-87 prompt 背包段、10-93 效果摘要同一口径：一律走中文名。
/// 未知 id 回退原 id（与 `itemName` 自身策略一致），保证旧存档里的
/// 幽灵物品键仍可见而不是消失。
String _itemName(String itemId) => itemName(itemId);

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
