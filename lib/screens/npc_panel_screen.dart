/// NPC 关系面板（Batch 10-15）。
///
/// 展示全部存活 NPC 的关系等级/心情/可接任务，
/// 并提供在场 NPC 的快捷互动入口（互动/深聊/示好/任务）。
library;

import 'package:flutter/material.dart';
import '../game_engine.dart';
import '../theme/westeros_theme.dart';
import '../widgets/theme/ornate.dart';

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
    final onSite = e.npcsAtCurrentLocation;
    return Scaffold(
      appBar: AppBar(title: const Text('NPC 关系')),
      body: ParchmentBackground(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            // 在场 NPC（可互动）
            GildedCard(
              highlight: onSite.isNotEmpty,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  OrnateHeader(
                    icon: Icons.location_on_outlined,
                    title: '在场（${e.currentLocation?.name ?? '未知'}）',
                  ),
                  const SizedBox(height: 8),
                  if (onSite.isEmpty)
                    const Text(
                      '身边没有其他人。',
                      style: TextStyle(color: WesterosColors.inkDim),
                    )
                  else
                    ...onSite.map((n) {
                      final rel = e.npcRelation(n.id);
                      return ListTile(
                        dense: true,
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: <Color>[
                                WesterosColors.goldDark,
                                WesterosColors.gold,
                              ],
                            ),
                          ),
                          child: Center(
                            child: Text(
                              n.name.substring(0, 1),
                              style: const TextStyle(
                                color: WesterosColors.barkDeep,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          n.name,
                          style: const TextStyle(
                            color: WesterosColors.parchment,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${e.npcRelationLabel(rel)}（$rel）'
                          '${n.mood.isEmpty ? '' : ' · ${n.mood}'}'
                          '${n.tasks.isEmpty ? '' : ' · 任务 ${n.tasks.length}'}',
                          style: const TextStyle(color: WesterosColors.inkDim),
                        ),
                        trailing: Wrap(
                          spacing: 4,
                          children: <Widget>[
                            _ActionPill(
                              label: '互动',
                              onTap: () =>
                                  _showResult(context, e.npcInteract(n.id)),
                            ),
                            _ActionPill(
                              label: '深聊',
                              onTap: () => _showResult(context, e.npcChat(n.id)),
                            ),
                            _ActionPill(
                              label: '示好',
                              onTap: () => _showResult(context, e.npcFavor(n.id)),
                            ),
                            if (n.tasks.isNotEmpty)
                              _ActionPill(
                                label: '任务',
                                onTap: () =>
                                    _showResult(context, e.acceptNpcTask(n.id)),
                              ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // 全部 NPC 关系列表
            GildedCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const OrnateHeader(icon: Icons.groups_outlined, title: '全部 NPC'),
                  const SizedBox(height: 8),
                  ...e.npcs.where((n) => n.isAlive).map((n) {
                    final rel = e.npcRelation(n.id);
                    return ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.person_outline,
                        color: WesterosColors.goldBright,
                      ),
                      title: Text(
                        n.name,
                        style: const TextStyle(color: WesterosColors.parchment),
                      ),
                      subtitle: Text(
                        '${e.npcRelationLabel(rel)}（$rel）'
                        '${n.mood.isEmpty ? '' : ' · ${n.mood}'}'
                        '${n.tasks.isEmpty ? '' : ' · 可委托 ${n.tasks.join('/')}'}',
                        style: const TextStyle(color: WesterosColors.inkDim),
                      ),
                      trailing: n.locationId == e.player.locationId
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: WesterosColors.goldDark
                                    .withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: WesterosColors.outlineGold
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                              child: const Text(
                                '在场',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: WesterosColors.goldBright,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // 进行中的任务（Batch 10-19：任务进度面板 UI）
            GildedCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const OrnateHeader(
                    icon: Icons.task_alt_outlined,
                    title: '进行中的任务',
                  ),
                  const SizedBox(height: 8),
                  if (e.activeTasks.isEmpty)
                    const Text(
                      '目前没有进行中的任务。',
                      style: TextStyle(color: WesterosColors.inkDim),
                    )
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
                              style: const TextStyle(
                                color: WesterosColors.parchment,
                                height: 1.4,
                              ),
                            ),
                            if (ratio != null) ...<Widget>[
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: ratio,
                                  minHeight: 8,
                                  backgroundColor:
                                      WesterosColors.barkMid.withValues(alpha: 0.8),
                                  valueColor: const AlwaysStoppedAnimation<Color>(
                                    WesterosColors.gold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '进度 ${(ratio * 100).round()}%'
                                '（第 ${t.stepIndex + 1}/$totalSteps 步）'
                                '${e.npcTaskCurrentStepDesc(t).isEmpty ? '' : ' · ${e.npcTaskCurrentStepDesc(t)}'}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: WesterosColors.inkDim,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
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

/// 金色动作胶囊（互动/深聊/示好/任务）。
class _ActionPill extends StatelessWidget {
  const _ActionPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: <Color>[
              WesterosColors.goldDark,
              WesterosColors.gold,
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: WesterosColors.goldBright.withValues(alpha: 0.5),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: WesterosColors.barkDeep,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}