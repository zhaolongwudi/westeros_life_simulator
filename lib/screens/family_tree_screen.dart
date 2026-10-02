/// 家族树可视化面板（Batch 10-20）。
///
/// 将 mixin_marriage.formatMultiGenTree 的文本树升级为可视化界面：
/// - 世代谱系链：历代家主（世代/姓名/头衔/在位/成就）按时间轴展示
/// - 当前世代：家主 + 配偶 + 子女（培养档案）+ 继承人
/// - 无谱系时仅展示当前世代
library;

import 'package:flutter/material.dart';

import '../game_engine.dart';
import '../models/marital.dart';
import '../utils/labels.dart';
import '../widgets/game/responsive.dart';

/// 家族树面板。
class FamilyTreeScreen extends StatelessWidget {
  const FamilyTreeScreen({super.key, this.engine});

  /// 可选：传入共享引擎（默认新建，用于独立浏览）。
  final GameEngine? engine;

  @override
  Widget build(BuildContext context) {
    // 坑 23：`??` 优先级高于级联 `..`，必须加括号
    final e = engine ?? (GameEngine()..startNewGame());
    final p = e.player;

    return Scaffold(
      appBar: AppBar(title: const Text('家族树')),
      body: SafeArea(
        child: AdaptiveFrame(
          child: ListView(
            padding: const EdgeInsets.all(16),
        children: <Widget>[
          // 标题：家族 + 世代
          Text(
            '${e.houseName}家 · 第 ${e.generationNumber()} 代',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            '血脉绵延，代代相传。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          // Batch 10-51：横版继承关系图（谱系概览）——历代家主迷你卡片横向串联至当代，
          // 整条继承链一眼望尽；与竖排时间轴互补（竖排看详情、横排看全局）。
          if (p.generationRecords.isNotEmpty) ...[
            const _SectionHeader(icon: Icons.timeline, title: '继承谱系'),
            const SizedBox(height: 8),
            _LineageOverview(
              records: p.generationRecords,
              currentName: p.name,
            ),
            const SizedBox(height: 16),
          ],
          // 历代谱系（时间轴样式）
          if (p.generationRecords.isNotEmpty) ...[
            const _SectionHeader(icon: Icons.history, title: '历代家主'),
            const SizedBox(height: 8),
            for (var i = 0; i < p.generationRecords.length; i++) ...[
              _GenerationNode(
                record: p.generationRecords[i],
                isLast: i == p.generationRecords.length - 1,
              ),
              // Batch 10-49：谱系继承连线——每任家主之间画一条传承连线
              // （非末代 → 连接下一任；末代 → 指向当前世代）
              _InheritanceLink(
                isLast: i == p.generationRecords.length - 1,
              ),
            ],
            const SizedBox(height: 16),
          ],
          // Batch 10-57：当代支脉横版图——当代家主 + 配偶 + 子女的血脉快照，
          // 与历代谱系概览衔接：祖先链看传承，当代支脉看「此刻的血亲」。
          if (p.spouse != null || p.children.isNotEmpty) ...[
            const _SectionHeader(icon: Icons.family_restroom, title: '当代支脉'),
            const SizedBox(height: 8),
            _CurrentFamilyOverview(engine: e),
            const SizedBox(height: 16),
          ],
          // 当前世代
          const _SectionHeader(icon: Icons.account_tree_outlined, title: '当前世代'),
          const SizedBox(height: 8),
          _CurrentNode(
            engine: e,
            isAfterInheritance: p.generationRecords.isNotEmpty,
          ),
        ],
          ),
        ),
      ),
    );
  }
}

/// 分节标题。
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

/// 横版继承关系图（谱系概览，Batch 10-51）。
///
/// 历代家主迷你卡片横向串联至当代：每任家主一个世代徽章 + 姓名，
/// 卡片之间用横向箭头连接，末代箭头指向「当代」徽章。
/// 与竖排时间轴互补——竖排看详情、横排看全局。
class _LineageOverview extends StatelessWidget {
  const _LineageOverview({
    required this.records,
    required this.currentName,
  });

  final List<GenerationRecord> records;
  final String currentName;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < records.length; i++) {
      final r = records[i];
      final isLast = i == records.length - 1;
      children.add(
        _LineageNode(
          record: r,
          label: '第${r.generation}代',
          name: r.name,
        ),
      );
      if (isLast) {
        children.add(const _LineageArrow(icon: Icons.arrow_forward, label: '当代'));
      } else {
        children.add(const _LineageArrow(icon: Icons.arrow_forward, label: ''));
      }
    }
    children.add(
      _LineageNode(
        label: '当代',
        name: currentName,
        isCurrent: true,
      ),
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: children,
      ),
    );
  }
}

/// 横版谱系节点：世代徽章 + 姓名（末位为「当代」徽章）。
class _LineageNode extends StatelessWidget {
  const _LineageNode({
    this.record,
    required this.label,
    required this.name,
    this.isCurrent = false,
    this.badge,
  });

  final GenerationRecord? record;
  final String label;
  final String name;
  final bool isCurrent;

  /// 徽章覆盖文字（如「偶」「子」）；为空时按既有规则取世代数字 /「当」。
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final bg = isCurrent ? theme.colorScheme.primaryContainer : null;
    final fg = isCurrent ? theme.colorScheme.onPrimaryContainer : null;
    return Container(
      width: 72,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent ? primary : theme.colorScheme.outlineVariant,
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CircleAvatar(
            radius: 14,
            backgroundColor: isCurrent ? primary : primary.withValues(alpha: 0.12),
            foregroundColor: isCurrent
                ? theme.colorScheme.onPrimary
                : primary,
            child: Text(
              badge ??
                  (isCurrent
                      ? '当'
                      : label.replaceAll('第', '').replaceAll('代', '')),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium?.copyWith(
              color: fg,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

/// 横版谱系箭头。
class _LineageArrow extends StatelessWidget {
  const _LineageArrow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 18, color: primary),
          if (label.isNotEmpty)
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(color: primary),
            ),
        ],
      ),
    );
  }
}

/// 当代支脉横版图（Batch 10-57）：当代家主 + 配偶 + 子女的血脉快照。
///
/// 与历代谱系概览衔接：继承链看「谁传给了谁」，此处看「此刻的家人」——
/// 当代家主居中，配偶与子女分列两侧，箭头向外指示亲缘方向。
/// 纯 UI 增强，不改模型/引擎。
class _CurrentFamilyOverview extends StatelessWidget {
  const _CurrentFamilyOverview({required this.engine});

  final GameEngine engine;

  @override
  Widget build(BuildContext context) {
    final p = engine.player;
    // 配偶节点（无则跳过）
    final spouseNode = p.spouse == null
        ? null
        : _LineageNode(label: '配偶', name: p.spouse!.name, badge: '偶');
    // 当代家主（始终位于中心）
    final currentNode = _LineageNode(
      label: '当代',
      name: p.name,
      isCurrent: true,
    );
    // 子女节点（每名子女一个节点，徽章「子」）
    final childNodes = p.children
        .map((c) => _LineageNode(label: '子女', name: c, badge: '子'))
        .toList();

    final children = <Widget>[];
    if (spouseNode != null) {
      children
        ..add(spouseNode)
        ..add(const _LineageArrow(icon: Icons.arrow_forward, label: ''));
    }
    children.add(currentNode);
    for (final c in childNodes) {
      children
        ..add(const _LineageArrow(icon: Icons.arrow_forward, label: ''))
        ..add(c);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: children,
      ),
    );
  }
}

/// 历代家主节点（时间轴条目，可点击查看详情，Batch 10-46）。
class _GenerationNode extends StatelessWidget {
  const _GenerationNode({required this.record, required this.isLast});

  final GenerationRecord record;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // 时间轴线
          SizedBox(
            width: 24,
            child: Column(
              children: <Widget>[
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(top: 14),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: theme.colorScheme.outlineVariant),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 节点卡片（点击弹出详情）
          Expanded(
            child: Card(
              margin: const EdgeInsets.only(bottom: 12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _showAncestorDetail(context, record),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Text(
                            '第 ${record.generation} 代',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          if (record.achievement.isNotEmpty)
                            Chip(
                              label: Text(
                                record.achievement,
                                style: const TextStyle(fontSize: 11),
                              ),
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        record.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${record.title}${record.reignYears.isEmpty ? '' : ' · ${record.reignYears}'}',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          Icon(
                            Icons.touch_app_outlined,
                            size: 14,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '查看详情',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 谱系继承连线（Batch 10-49）。
///
/// 相邻两任家主之间的传承箭头：非末代显示「继承」（指向下一任），
/// 末代显示「传至当代」（指向当前世代），让「谁传位给谁」一目了然。
class _InheritanceLink extends StatelessWidget {
  const _InheritanceLink({required this.isLast});

  /// 是否为谱系最后一条（末代）。
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 4),
      child: Row(
        children: <Widget>[
          Icon(Icons.south, size: 18, color: primary),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isLast ? '传至当代' : '继承',
              style: theme.textTheme.labelSmall?.copyWith(
                color: primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 弹出历代家主详情（底部弹层，Batch 10-46）。
///
/// 展示：世代/姓名/头衔/在位/成就（无则提示）/传承寄语。
void _showAncestorDetail(BuildContext context, GenerationRecord record) {
  final theme = Theme.of(context);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: theme.colorScheme.surface,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // 标题行：世代徽章 + 姓名
            Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 22,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    '${record.generation}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        record.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '第 ${record.generation} 代家主',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            // 头衔
            _DetailLine(
              icon: Icons.workspace_premium_outlined,
              label: '头衔',
              value: record.title.isEmpty ? '无名之辈' : record.title,
            ),
            // 在位
            _DetailLine(
              icon: Icons.schedule_outlined,
              label: '在位',
              value: record.reignYears.isEmpty ? '未记载' : record.reignYears,
            ),
            // 成就
            _DetailLine(
              icon: Icons.emoji_events_outlined,
              label: '成就',
              value: record.achievement.isEmpty
                  ? '暂无显著功绩'
                  : record.achievement,
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${record.name} 的名字已刻入家族史册。愿后人不负先人。',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: const Text('关闭'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// 详情行（图标 + 标签 + 值）。
class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          SizedBox(
            width: 44,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

/// 当前世代节点：家主 + 配偶 + 子女 + 继承人。
class _CurrentNode extends StatelessWidget {
  const _CurrentNode({required this.engine, required this.isAfterInheritance});

  final GameEngine engine;
  final bool isAfterInheritance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = engine.player;
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // 家主
            Row(
              children: <Widget>[
                CircleAvatar(
                  child: Text(p.name.isEmpty ? '?' : p.name.substring(0, 1)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '家主：${p.name}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${identityLabel(p.identity)} · ${p.age}岁'
                        '${p.title.isEmpty ? '' : ' · ${p.title}'}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            // 配偶
            if (engine.isMarried && p.spouse != null)
              _InfoLine(
                icon: Icons.favorite_outline,
                text: '配偶：${p.spouse!.name}'
                    '（${spouseOriginLabel(p.spouse!.origin)}，'
                    '结缡 ${engine.progress.year - p.spouse!.marriedYear} 年）',
              ),
            // 子女
            if (p.children.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('子女：', style: theme.textTheme.labelLarge),
              for (final c in p.children)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 2),
                  child: _InfoLine(
                    icon: Icons.child_care_outlined,
                    text: _childRearingText(engine, c),
                    small: true,
                  ),
                ),
            ] else
              const _InfoLine(
                icon: Icons.child_care_outlined,
                text: '子女：尚无子嗣',
                small: true,
              ),
            // 继承人
            if (engine.heirName != null) ...[
              const SizedBox(height: 6),
              _InfoLine(
                icon: Icons.workspace_premium_outlined,
                text: '继承人：${engine.heirName}',
              ),
            ],
            // 多世代传承提示
            if (isAfterInheritance) ...[
              const SizedBox(height: 6),
              Text(
                '👑 你已接过先祖的传承，肩负起 ${engine.houseName} 家的未来。',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 信息行。
class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.text,
    this.small = false,
  });

  final IconData icon;
  final String text;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: small ? 16 : 18, color: Colors.grey),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: small ? 13 : 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// 生成子女培养档案文本（与 player_panel_screen 同源逻辑，Batch 10-19）。
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
  return '$childName：${parts.isEmpty ? '无记录' : parts.join(' / ')}';
}
