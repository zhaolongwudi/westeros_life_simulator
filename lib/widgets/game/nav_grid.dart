/// 主界面导航宫格 widget（Batch 10-35 · M5 体验层）。
///
/// 收口 AppBar 的多个图标入口为单个「宫格」按钮；宫格按屏幕宽度自适应列数
/// （<480 三列，>=480 四列），满足「导航 7+ 入口不拥挤」。
/// 纯展示 + 回调上抛，不 import 混入层（M3b 分层约束）。
///
/// Batch 10-60 UI 重造：金色徽章瓦片 + 渐变光晕。
library;

import 'package:flutter/material.dart';

import '../../theme/westeros_theme.dart';

/// 单个宫格入口。
class NavGridEntry {
  const NavGridEntry({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

/// 主界面导航宫格（弹出层内容）。
class NavGrid extends StatelessWidget {
  const NavGrid({super.key, required this.entries});

  final List<NavGridEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(
                  Icons.castle_outlined,
                  size: 20,
                  color: WesterosColors.goldBright,
                ),
                const SizedBox(width: 8),
                Text(
                  '导航',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: WesterosColors.goldBright,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                // 响应式列数：窄屏 3 列，宽屏 4 列
                final crossAxisCount = constraints.maxWidth >= 480 ? 4 : 3;
                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.4,
                  children: <Widget>[
                    for (final entry in entries)
                      _NavGridTile(entry: entry),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 宫格瓦片（图标 + 标签 + 点击）。
class _NavGridTile extends StatelessWidget {
  const _NavGridTile({required this.entry});

  final NavGridEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: WesterosColors.barkHigh,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: entry.onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: WesterosColors.outlineGold.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // 图标徽章（渐变圆底）
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      entry.color.withValues(alpha: 0.5),
                      entry.color.withValues(alpha: 0.25),
                    ],
                  ),
                  border: Border.all(
                    color: entry.color.withValues(alpha: 0.6),
                  ),
                ),
                child: Icon(entry.icon, size: 20, color: entry.color),
              ),
              const SizedBox(height: 8),
              Text(
                entry.label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: WesterosColors.parchment,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
