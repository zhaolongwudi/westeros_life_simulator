/// 系统面板：展示玩家已接触的世界系统（74 系统）。
///
/// 复用 GameEngine.availableSystems / formatSystemsPanel（Batch 4）。
library;

import 'package:flutter/material.dart';

import '../game_engine.dart';
import '../models/system.dart';
import '../theme/westeros_theme.dart';
import '../widgets/theme/ornate.dart';

/// 系统面板。
class SystemsScreen extends StatelessWidget {
  const SystemsScreen({super.key, this.engine});

  /// 可选：传入共享引擎（默认新建，用于独立浏览）。
  final GameEngine? engine;

  @override
  Widget build(BuildContext context) {
    final e = engine ?? (GameEngine()..startNewGame());
    final available = e.availableSystems();
    final all = e.systemCount;

    return Scaffold(
      appBar: AppBar(title: const Text('系统面板')),
      body: ParchmentBackground(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: <Color>[
                          WesterosColors.goldDark,
                          WesterosColors.gold,
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.grid_view_outlined,
                      size: 16,
                      color: WesterosColors.barkDeep,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '已接触系统：${available.length}/$all',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: WesterosColors.goldBright,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
            const WesterosDivider(thickness: 1),
            Expanded(
              child: available.isEmpty
                  ? const Center(child: Text('你目前还没有接触任何世界系统。'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: available.length,
                      itemBuilder: (context, index) {
                        final s = available[index];
                        return GildedCard(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: EdgeInsets.zero,
                          child: ListTile(
                            leading: Icon(
                              Icons.grid_view_outlined,
                              color: WesterosColors.goldBright,
                            ),
                            title: Text(
                              '${s.name}（${s.category}）',
                              style: const TextStyle(
                                color: WesterosColors.parchment,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              s.description,
                              style: const TextStyle(color: WesterosColors.inkDim),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: WesterosColors.goldBright,
                            ),
                            isThreeLine: s.description.length > 40,
                            onTap: () {
                              showModalBottomSheet<void>(
                                context: context,
                                builder: (context) => _SystemDetail(system: s),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 系统详情底部弹层。
class _SystemDetail extends StatelessWidget {
  const _SystemDetail({required this.system});

  final GameSystem system;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ParchmentBackground(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // 标题行：金饰 + 系统名
              Row(
                children: <Widget>[
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: <Color>[
                          WesterosColors.goldDark,
                          WesterosColors.gold,
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.grid_view_outlined,
                      size: 17,
                      color: WesterosColors.barkDeep,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${system.name}（${system.category}）',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: WesterosColors.goldBright,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: WesterosColors.inkDim,
                    ),
                    tooltip: '关闭',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const WesterosDivider(thickness: 1),
              const SizedBox(height: 8),
              // 描述：羊皮纸色文字
              Text(
                system.description,
                style: const TextStyle(
                  color: WesterosColors.parchment,
                  height: 1.5,
                ),
              ),
              if (system.rules.isNotEmpty) ...[
                const SizedBox(height: 12),
                const OrnateHeader(icon: Icons.menu_book_outlined, title: '规则'),
                for (final rule in system.rules)
                  Padding(
                    padding: const EdgeInsets.only(top: 3, left: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Icon(
                            Icons.circle,
                            size: 6,
                            color: WesterosColors.gold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            rule,
                            style: const TextStyle(
                              color: WesterosColors.parchment,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              if (system.features.isNotEmpty) ...[
                const SizedBox(height: 12),
                const OrnateHeader(icon: Icons.auto_awesome_outlined, title: '特性'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: system.features
                      .map(
                        (f) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: WesterosColors.barkMid.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: WesterosColors.outlineGold.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            f,
                            style: const TextStyle(
                              fontSize: 12,
                              color: WesterosColors.goldBright,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}