/// 主界面导航宫格 widget（Batch 10-35 · M5 体验层）。
///
/// 收口 AppBar 的多个图标入口为单个「宫格」按钮；宫格按屏幕宽度自适应列数
/// （<480 三列，>=480 四列），满足「导航 7+ 入口不拥挤」。
/// 纯展示 + 回调上抛，不 import 混入层（M3b 分层约束）。
library;

import 'package:flutter/material.dart';

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
            Text('导航', style: theme.textTheme.titleMedium),
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
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: entry.onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(entry.icon, size: 26, color: entry.color),
            const SizedBox(height: 6),
            Text(
              entry.label,
              style: theme.textTheme.labelMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
