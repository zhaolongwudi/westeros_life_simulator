/// 事件面板：浏览世界事件库与玩家可触发事件。
///
/// 复用 EventProvider（Batch 3）与 GameEngine.eventTemplates（Batch 4）。
/// 纯展示 + 可触发状态标记，不做触发执行（避免过度工程）。
library;

import 'package:flutter/material.dart';

import '../game_engine.dart';
import '../models/event.dart';
import '../theme/westeros_theme.dart';
import '../utils/labels.dart';
import '../widgets/theme/ornate.dart';

/// 事件面板。
class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key, this.engine});

  /// 可选：传入共享引擎（默认新建，用于独立浏览）。
  final GameEngine? engine;

  @override
  Widget build(BuildContext context) {
    final e = engine ?? (GameEngine()..startNewGame());
    final allEvents = e.eventTemplates;
    final available = e.eventProvider.getAvailableEvents(
      e.player,
      season: e.progress.season,
    );

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
        body: ParchmentBackground(
          child: TabBarView(
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

    return GildedCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.zero,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: showAvailableBadge
                  ? WesterosColors.gold.withValues(alpha: 0.2)
                  : WesterosColors.barkMid,
              border: Border.all(
                color: showAvailableBadge
                    ? WesterosColors.gold.withValues(alpha: 0.6)
                    : WesterosColors.outlineGold.withValues(alpha: 0.4),
              ),
            ),
            child: Icon(
              Icons.event_note_outlined,
              size: 18,
              color: showAvailableBadge ? WesterosColors.goldBright : WesterosColors.inkDim,
            ),
          ),
          title: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  event.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: showAvailableBadge ? WesterosColors.goldBright : WesterosColors.parchment,
                  ),
                ),
              ),
              if (showAvailableBadge)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: WesterosColors.gold.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: WesterosColors.gold.withValues(alpha: 0.5),
                    ),
                  ),
                  child: const Text(
                    '可触发',
                    style: TextStyle(
                      color: WesterosColors.goldBright,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Text(
            // S13-11 ⑮：此前还拼接了 `event.tags.join('、')`，把 91 个英文
            // 内部标签（political/succession/crisis…）印给玩家。内容规范
            // （`docs/specs/content-schema.md:96`）写明 tags 是「筛选与统计用」
            // 的内部字段，不是给玩家看的分类，故不再展示。
            typeLabel,
            style: const TextStyle(color: WesterosColors.inkDim),
          ),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    event.description,
                    style: const TextStyle(color: WesterosColors.parchment),
                  ),
                  const SizedBox(height: 8),
                  // 触发条件：Batch 10-103 补空态——门槛清空后
                  // `entries.join('，')` 为空串，原实现会渲染出裸的
                  // 「触发条件：」三个字加一个悬空冒号。
                  // S13-11 ⑮：改用 `eventConditionLabel` 输出中文，
                  // 不再把 `locationId=location_white_harbor` 这类内部键印给玩家。
                  Text(
                    event.triggerConditions.isEmpty
                        ? '触发条件：无（任何时候都可能发生）'
                        : '触发条件：${event.triggerConditions.entries.map((e) => eventConditionLabel(e.key, e.value)).join('，')}',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (event.isOneTime)
                    Text('一次性事件', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 8),
                  const Text(
                    '选项：',
                    style: TextStyle(fontWeight: FontWeight.bold, color: WesterosColors.goldBright),
                  ),
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
                                ? WesterosColors.goldBright
                                : WesterosColors.inkDim,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              choice.text,
                              style: TextStyle(
                                fontWeight: choices.contains(choice)
                                    ? FontWeight.normal
                                    : FontWeight.w300,
                                color: choices.contains(choice)
                                    ? WesterosColors.parchment
                                    : WesterosColors.inkDim,
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
      ),
    );
  }
}