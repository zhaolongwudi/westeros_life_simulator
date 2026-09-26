/// 地图界面：按区域浏览维斯特洛及已知世界的地点。
///
/// 数据来自 GameEngine.locations（Batch 2 数据层 68 地点）。
library;

import 'package:flutter/material.dart';

import '../game_engine.dart';
import '../models/location.dart';

/// 地图界面。
class MapScreen extends StatelessWidget {
  const MapScreen({super.key, this.engine});

  /// 可选：传入共享引擎（默认新建，用于独立浏览）。
  final GameEngine? engine;

  @override
  Widget build(BuildContext context) {
    final e = engine ?? (GameEngine()..startNewGame());
    final locations = e.locations;
    final playerLocId = e.player.locationId;

    // 按区域分组
    final byRegion = <String, List<Location>>{};
    for (final loc in locations) {
      byRegion.putIfAbsent(loc.region, () => <Location>[]).add(loc);
    }
    final regions = byRegion.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(title: const Text('地图')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: <Widget>[
          for (final region in regions) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text(
                region,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final loc in byRegion[region]!)
              _LocationTile(
                location: loc,
                isCurrent: loc.id == playerLocId,
              ),
          ],
        ],
      ),
    );
  }
}

/// 地点条目。
class _LocationTile extends StatelessWidget {
  const _LocationTile({required this.location, required this.isCurrent});

  final Location location;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeLabel = switch (location.type) {
      LocationType.castle => '城堡',
      LocationType.city => '城市',
      LocationType.village => '村庄',
      LocationType.fort => '要塞',
      LocationType.temple => '神庙',
      LocationType.academy => '学院',
      LocationType.tavern => '酒馆',
      LocationType.market => '市场',
      LocationType.wilderness => '荒野',
      LocationType.supernatural => '超自然',
      LocationType.unknown => '未知',
    };
    return ListTile(
      leading: Icon(
        isCurrent ? Icons.place : Icons.place_outlined,
        color: isCurrent ? theme.colorScheme.primary : null,
      ),
      title: Text(location.name),
      subtitle: Text(
        '$typeLabel · 危险度 ${location.dangerLevel}'
        '${isCurrent ? ' · 你在这里' : ''}',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        showModalBottomSheet<void>(
          context: context,
          builder: (context) => _LocationDetail(location: location),
        );
      },
    );
  }
}

/// 地点详情底部弹层。
class _LocationDetail extends StatelessWidget {
  const _LocationDetail({required this.location});

  final Location location;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(location.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(location.description),
            const SizedBox(height: 12),
            if (location.features.isNotEmpty) ...[
              const Text('特色：'),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: location.features
                    .map(
                      (f) => Chip(label: Text(f), visualDensity: VisualDensity.compact),
                    )
                    .toList(),
              ),
              const SizedBox(height: 8),
            ],
            Text('人口 ${location.population} · 危险度 ${location.dangerLevel}'),
            const SizedBox(height: 4),
            if (location.connectedTo.isNotEmpty)
              Text('可前往：${location.connectedTo.length} 处'),
          ],
        ),
      ),
    );
  }
}