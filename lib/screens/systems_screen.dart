/// 系统面板：展示玩家已接触的世界系统（74 系统）。
///
/// 复用 GameEngine.availableSystems / formatSystemsPanel（Batch 4）。
library;

import 'package:flutter/material.dart';

import '../game_engine.dart';
import '../models/system.dart';

/// 系统面板。
class SystemsScreen extends StatelessWidget {
  const SystemsScreen({super.key, this.engine});

  /// 可选：传入共享引擎（默认新建，用于独立浏览）。
  final GameEngine? engine;

  @override
  Widget build(BuildContext context) {
    final e = engine ?? GameEngine()..startNewGame();
    final available = e.availableSystems();
    final all = e.systemCount;

    return Scaffold(
      appBar: AppBar(title: const Text('系统面板')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: <Widget>[
                Text(
                  '已接触系统：${available.length}/$all',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: available.isEmpty
                ? const Center(child: Text('你目前还没有接触任何世界系统。'))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: available.length,
                    itemBuilder: (context, index) {
                      final s = available[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.grid_view_outlined),
                          title: Text('${s.name}（${s.category}）'),
                          subtitle: Text(s.description),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${system.name}（${system.category}）',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(system.description),
            if (system.rules.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('规则：'),
              for (final rule in system.rules)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('· $rule'),
                ),
            ],
            if (system.features.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('特性：'),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: system.features
                    .map(
                      (f) => Chip(label: Text(f), visualDensity: VisualDensity.compact),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}