/// 主界面顶部状态摘要条 widget（Batch 10-29 · M3b 从 game_screen 拆出）。
library;

import 'package:flutter/material.dart';

import '../../game_engine.dart';
import '../../utils/labels.dart';

/// 顶部状态摘要条。
class StatusBar extends StatelessWidget {
  const StatusBar({required this.engine});

  final GameEngine engine;

  @override
  Widget build(BuildContext context) {
    final p = engine.player;
    final loc = engine.currentLocation;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              '${p.name} · ${identityLabel(p.identity)} · ${p.age}岁'
              '${loc != null ? ' · ${loc.name}' : ''}',
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '❤️${p.health} ⚡${p.energy} 🍖${p.hunger}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(width: 8),
          Text(
            '${engine.progress.year}年${engine.progress.month}月 ${seasonShortLabel(engine.progress.season)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
