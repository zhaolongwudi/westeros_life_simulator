/// 事件面板：浏览世界事件库与玩家可触发事件。
///
/// 复用 EventProvider（Batch 3）与 GameEngine.eventTemplates（Batch 4）。
/// 纯展示 + 可触发状态标记，不做触发执行（避免过度工程）。
library;

import 'package:flutter/material.dart';

import '../game_engine.dart';
import '../models/event.dart';

/// 事件类型中文标签。
String eventTypeLabel(EventType type) {
  return switch (type) {
    EventType.political => '政治',
    EventType.family => '家族',
    EventType.war => '战争',
    EventType.religious => '宗教',
    EventType.economic => '经济',
    EventType.magical => '魔法',
    EventType.daily => '日常',
    EventType.adventure => '冒险',
    EventType.supernatural => '超自然',
  };
}

/// 事件面板。
class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key, this.engine});

  /// 可选：传入共享引擎（默认新建，用于独立浏览）。
  final GameEngine? engine;

  @override
  Widget build(BuildContext context) {
    final e = engine ?? GameEngine()..startNewGame();
    final allEvents = e.eventTemplates;
    final available = e.eventProvider.getAvailableEvents(e.player);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('事件'),
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(text: '可触发'),
              Tab(text: '事件库'),
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            // 可触发事件
            available.isEmpty
                ? const Center(child: Text('当前没有可触发的事件。'))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: available.length,
                    itemBuilder: (context, index) {
                      final ev = available[index];
                      return _EventCard(event: ev, playerEngine: e);
                    },
                  ),
            // 全部事件库
            ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: allEvents.length,
              itemBuilder: (context, index) {
                final ev = allEvents[index];
                final isAvailable = available.contains(ev);
                return _EventCard(
                  event: ev,
                  playerEngine: e,
                  showAvailableBadge: isAvailable,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 单个事件卡片。
class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.playerEngine,
    this.showAvailableBadge = false,
  });

  final GameEvent event;
  final GameEngine playerEngine;
  final bool showAvailableBadge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeLabel = eventTypeLabel(event.type);
    final choices = playerEngine.eventProvider
        .getAvailableChoices(event, playerEngine.player);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Icon(
          Icons.event_note_outlined,
          color: showAvailableBadge ? theme.colorScheme.primary : null,
        ),
        title: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                event.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (showAvailableBadge)
              Chip(
                label: const Text('可触发'),
                visualDensity: VisualDensity.compact,
                backgroundColor: theme.colorScheme.primaryContainer,
              ),
          ],
        ),
        subtitle: Text('$typeLabel · ${event.tags.join('、')}'),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(event.description),
                const SizedBox(height: 8),
                Text(
                  '触发条件：${event.triggerConditions.entries.map((e) => '${e.key}=${e.value}').join('，')}',
                  style: theme.textTheme.bodySmall,
                ),
                if (event.isOneTime)
                  Text('一次性事件', style: theme.textTheme.bodySmall),
                const SizedBox(height: 8),
                const Text('选项：', style: TextStyle(fontWeight: FontWeight.bold)),
                for (final choice in event.choices)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(
                          choices.contains(choice)
                              ? Icons.check_circle_outline
                              : Icons.circle_outlined,
                          size: 16,
                          color: choices.contains(choice)
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            choice.text,
                            style: TextStyle(
                              fontWeight: choices.contains(choice)
                                  ? FontWeight.normal
                                  : FontWeight.w300,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}