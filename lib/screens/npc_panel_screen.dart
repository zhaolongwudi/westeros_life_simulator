/// NPC 关系面板（Batch 10-15）。
///
/// 展示全部存活 NPC 的关系等级/心情/可接任务，
/// 并提供在场 NPC 的快捷互动入口（互动/深聊/示好/任务）。
library;

import 'package:flutter/material.dart';
import '../game_engine.dart';

/// NPC 关系面板。
class NpcPanelScreen extends StatelessWidget {
  const NpcPanelScreen({super.key, this.engine});
  /// 可选：传入共享引擎（默认新建，用于独立浏览）。
  final GameEngine? engine;

  @override
  Widget build(BuildContext context) {
    // 注意：`??` 优先级高于级联 `..`，必须加括号，否则传入 engine 时
    // (engine ?? GameEngine())..startNewGame() 会重置传入引擎的玩家数据（坑 23）
    final e = engine ?? (GameEngine()..startNewGame());
    final theme = Theme.of(context);
    final onSite = e.npcsAtCurrentLocation;
    return Scaffold(
      appBar: AppBar(title: const Text('NPC 关系')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          // 在场 NPC（可互动）
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('在场（${e.currentLocation?.name ?? '未知'}）',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (onSite.isEmpty)
                    const Text('身边没有其他人。')
                  else
                    ...onSite.map((n) {
                      final rel = e.npcRelation(n.id);
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          child: Text(n.name.substring(0, 1)),
                        ),
                        title: Text(n.name),
                        subtitle: Text(
                          '${e.npcRelationLabel(rel)}（$rel）'
                          '${n.mood.isEmpty ? '' : ' · ${n.mood}'}'
                          '${n.tasks.isEmpty ? '' : ' · 任务 ${n.tasks.length}'}',
                        ),
                        trailing: Wrap(
                          spacing: 4,
                          children: <Widget>[
                            ActionChip(
                              label: const Text('互动'),
                              onPressed: () => _showResult(
                                context,
                                e.npcInteract(n.id),
                              ),
                            ),
                            ActionChip(
                              label: const Text('深聊'),
                              onPressed: () => _showResult(
                                context,
                                e.npcChat(n.id),
                              ),
                            ),
                            ActionChip(
                              label: const Text('示好'),
                              onPressed: () => _showResult(
                                context,
                                e.npcFavor(n.id),
                              ),
                            ),
                            if (n.tasks.isNotEmpty)
                              ActionChip(
                                label: const Text('任务'),
                                onPressed: () => _showResult(
                                  context,
                                  e.acceptNpcTask(n.id),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 全部 NPC 关系列表
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('全部 NPC', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...e.npcs.where((n) => n.isAlive).map((n) {
                    final rel = e.npcRelation(n.id);
                    return ListTile(
                      dense: true,
                      title: Text(n.name),
                      subtitle: Text(
                        '${e.npcRelationLabel(rel)}（$rel）'
                        '${n.mood.isEmpty ? '' : ' · ${n.mood}'}'
                        '${n.tasks.isEmpty ? '' : ' · 可委托 ${n.tasks.join('/')}'}',
                      ),
                      trailing: Text(
                        n.locationId == e.player.locationId ? '在场' : '',
                        style: theme.textTheme.bodySmall,
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 进行中的任务（Batch 10-19：任务进度面板 UI）
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(Icons.task_alt_outlined, size: 18),
                      const SizedBox(width: 8),
                      Text('进行中的任务', style: theme.textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (e.activeTasks.isEmpty)
                    const Text('目前没有进行中的任务。')
                  else
                    ...e.activeTasks.map((t) {
                      final status = t.completed
                          ? '✅ 已完成'
                          : t.failed
                              ? '❌ 已失败'
                              : '⏳ 进行中';
                      final deadline =
                          '期限 ${t.deadlineYear}年${t.deadlineMonth}月';
                      // Batch 10-24：进度条 + 剩余月数 + 当前步骤
                      final ratio = t.isActive ? e.npcTaskOverallRatio(t) : null;
                      final left = t.isActive ? e.npcTaskRemainingMonths(t) : null;
                      final totalSteps = e.npcTaskTotalSteps(t);
                      final leftText = (left == null || left < 0)
                          ? ''
                          : '剩余 $left 个月';
                      return Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '· ${t.title}：$status｜$deadline'
                              '${leftText.isEmpty ? '' : '｜$leftText'}',
                              style: theme.textTheme.bodyMedium,
                            ),
                            if (ratio != null) ...<Widget>[
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: ratio,
                                  minHeight: 8,
                                  backgroundColor:
                                      theme.colorScheme.surfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '进度 ${(ratio * 100).round()}%'
                                '（第 ${t.stepIndex + 1}/$totalSteps 步）'
                                '${e.npcTaskCurrentStepDesc(t).isEmpty ? '' : ' · ${e.npcTaskCurrentStepDesc(t)}'}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 弹出互动结果。
  void _showResult(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 4)),
    );
  }
}