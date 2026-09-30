/// NPC 任务链二轮混入（Batch 10-18）。
///
/// 在 [GameNpcInteractMixin]（简单任务列表）之上提供：
/// - 多步骤任务：接任务 → 逐步推进 → 完成结算
/// - 期限系统：逾期失败（月度检查）
/// - 奖励差异化：按难度/类型给不同金币/声望/好感
///
/// 进行中任务存 Player.activeTasks（[NpcTaskProgress]），
/// 避免 flags 只存 bool 的限制（坑 16）。
library;

import '../data/npc_task_data.dart';
import '../models/npc_task.dart';
import '../core/command_registry.dart';
import '../core/monthly_pipeline.dart';
import '../utils/command_alias.dart';
import '../providers/game_provider_base.dart';
import 'mixin_life.dart';
import 'mixin_npc_interact.dart';

/// NPC 任务链混入。挂在 [GameProviderBase] 上，
/// 依赖 [GameLifeMixin]（金币/声望）与 [GameNpcInteractMixin]（关系/在场判断）。
mixin GameNpcTaskMixin
    on GameProviderBase, GameLifeMixin, GameNpcInteractMixin {
  /// 玩家进行中的任务（只读）。
  List<NpcTaskProgress> get activeTasks =>
      List.unmodifiable(player.activeTasks);

  /// 某 NPC 的可接任务模板（未接且未完成的）。
  List<NpcTaskTemplate> availableTasksOf(String npcId) {
    final taken = player.activeTasks
        .where((t) => t.npcId == npcId && t.isActive)
        .map((t) => t.taskId)
        .toSet();
    return npcTaskTemplatesOf(npcId)
        .where((t) => !taken.contains(t.id))
        .toList();
  }

  /// 任务面板：列出在场 NPC 的可接多步骤任务。
  String formatNpcTaskPanelV2() {
    final buf = StringBuffer()..writeln('【可接任务】');
    var any = false;
    for (final n in npcsAtCurrentLocation) {
      final tasks = availableTasksOf(n.id);
      if (tasks.isEmpty) continue;
      any = true;
      buf.writeln('· ${n.name}：');
      for (final t in tasks) {
        buf.writeln('  - ${t.title}（${t.typeLabel}，难度 ${t.difficulty}，'
            '期限 ${t.deadlineMonths} 月，${t.steps.length} 步，奖励 ${t.finalGoldReward} 金）');
      }
    }
    if (!any) return '【可接任务】\n在场的人没有委托给你任务。';
    return buf.toString().trim();
  }

  /// 接受一位在场 NPC 的多步骤任务（关系 ≥ 相识 才肯委托）。
  ///
  /// 返回叙事文本；未达关系/不在场/无任务返回说明。
  String acceptNpcTaskV2(String npcId, {String? taskId}) {
    final npc = npcById(npcId);
    if (npc == null) return '没有叫「$npcId」的人。';
    if (!npc.isAlive) return '${npc.name}已经不在了。';
    if (npc.locationId != player.locationId) return '${npc.name}不在这里。';
    final rel = npcRelation(npc.id);
    if (rel < 20) {
      return '${npc.name}还信不过你：「等你我熟络些，再说这些事吧。」';
    }
    final available = availableTasksOf(npc.id);
    if (available.isEmpty) {
      return '${npc.name}暂时没有新的委托给你。';
    }
    NpcTaskTemplate? template;
    if (taskId == null) {
      template = available.first;
    } else {
      for (final t in available) {
        if (t.id == taskId) {
          template = t;
          break;
        }
      }
    }
    if (template == null) return '没有找到这个任务。';
    // 生成任务实例：期限 = 当前时间 + deadlineMonths
    final deadline = _addMonths(progress.year, progress.month, template.deadlineMonths);
    final taskProgress = NpcTaskProgress(
      taskId: template.id,
      npcId: npc.id,
      title: template.title,
      stepIndex: 0,
      stepProgress: 0,
      deadlineYear: deadline.$1,
      deadlineMonth: deadline.$2,
    );
    final tasks = List<NpcTaskProgress>.from(player.activeTasks)..add(taskProgress);
    updatePlayer(player.copyWith(activeTasks: tasks));
    adjustRelation(npc.id, 2);
    final firstStep = template.steps.first.description;
    return '📜 你接下${npc.name}的委托：「${template.title}」。'
        '第一步：$firstStep。期限 ${deadline.$1}年${deadline.$2}月。关系 +2。';
  }

  /// 推进所有进行中任务（探索/过月时调用）。
  ///
  /// 每步按 turnsRequired 累计推进；完成当前步后进入下一步；
  /// 全部步骤完成则结算奖励。返回追加叙事。
  String advanceNpcTasks() {
    if (player.activeTasks.isEmpty) return '';
    final buf = StringBuffer();
    final updated = <NpcTaskProgress>[];
    for (final task in player.activeTasks) {
      if (!task.isActive) {
        updated.add(task);
        continue;
      }
      final template = npcTaskTemplateById(task.taskId);
      if (template == null) {
        updated.add(task);
        continue;
      }
      // 推进当前步骤
      var next = task;
      final step = template.steps[task.stepIndex];
      final newProgress = task.stepProgress + 1;
      if (newProgress >= step.turnsRequired) {
        // 当前步完成
        if (task.stepIndex + 1 >= template.steps.length) {
          // 全部完成：结算奖励
          next = task.copyWith(
            stepIndex: task.stepIndex + 1,
            stepProgress: 0,
            completed: true,
          );
          final gold = template.finalGoldReward;
          gainGold(gold);
          adjustReputation(template.rewardReputation);
          adjustRelation(task.npcId, template.rewardRelation);
          buf.writeln('✅ 你完成了${npcById(task.npcId)?.name ?? '委托人'}的委托：'
              '「${template.title}」。获得 $gold 金币，'
              '声望 +${template.rewardReputation}，关系 +${template.rewardRelation}。');
        } else {
          // 进入下一步
          next = task.copyWith(
            stepIndex: task.stepIndex + 1,
            stepProgress: 0,
          );
          final nextStep = template.steps[task.stepIndex + 1];
          buf.writeln('➡️ 「${template.title}」进展：${nextStep.description}');
        }
      } else {
        next = task.copyWith(stepProgress: newProgress);
      }
      updated.add(next);
    }
    updatePlayer(player.copyWith(activeTasks: updated));
    return buf.toString().trim();
  }

  /// 月度期限检查：逾期任务标记失败。
  ///
  /// 由 [GamePlayMixin.advanceMonth] 调用；返回追加叙事。
  String checkNpcTaskDeadlines() {
    if (player.activeTasks.isEmpty) return '';
    final buf = StringBuffer();
    final updated = <NpcTaskProgress>[];
    for (final task in player.activeTasks) {
      if (!task.isActive) {
        updated.add(task);
        continue;
      }
      final overdue = _isAfter(
        progress.year,
        progress.month,
        task.deadlineYear,
        task.deadlineMonth,
      );
      if (overdue) {
        updated.add(task.copyWith(failed: true));
        buf.writeln('⏰ 你逾期未完成「${task.title}」，委托失败。'
            '${npcById(task.npcId)?.name ?? '委托人'}对你失望不已。');
      } else {
        updated.add(task);
      }
    }
    // 仅当有任务逾期失败时才落盘（避免无谓 notify）
    if (updated.any((t) => t.failed)) {
      updatePlayer(player.copyWith(activeTasks: updated));
    }
    return buf.toString().trim();
  }

  /// 任务进度面板：列出进行中/已完成/失败任务。
  ///
  /// Batch 10-24 增强：进行中任务附整体进度百分比与剩余月数。
  String formatNpcTaskProgressPanel() {
    if (player.activeTasks.isEmpty) return '【任务进度】\n你目前没有进行中的任务。';
    final buf = StringBuffer()..writeln('【任务进度】');
    for (final t in player.activeTasks) {
      final template = npcTaskTemplateById(t.taskId);
      final status = t.completed
          ? '✅ 已完成'
          : t.failed
              ? '❌ 已失败'
              : '⏳ 进行中（${t.stepIndex}/${template?.steps.length ?? '?'} 步）';
      final deadline = '期限 ${t.deadlineYear}年${t.deadlineMonth}月';
      final left = t.isActive ? npcTaskRemainingMonths(t) : null;
      final leftText = (left == null || left < 0) ? '' : '（剩余 $left 个月）';
      final ratio = t.isActive ? npcTaskOverallRatio(t) : null;
      final ratioText = ratio == null ? '' : '，进度 ${(ratio * 100).round()}%';
      buf.writeln('· ${t.title}：$status｜$deadline$leftText$ratioText');
    }
    return buf.toString().trim();
  }

  // ==================== 进度/期限派生（Batch 10-24） ====================

  /// 任务整体进度（0.0~1.0）：已完成推进次数 / 总推进次数。
  ///
  /// 已完成任务恒为 1.0，失败任务按其失败时推进情况计算（UI 不展示条）。
  double npcTaskOverallRatio(NpcTaskProgress task) {
    final template = npcTaskTemplateById(task.taskId);
    final total = template?.totalTurns ?? 0;
    if (total == 0) return task.completed ? 1.0 : 0.0;
    var done = task.stepProgress;
    final steps = template?.steps ?? const <NpcTaskStep>[];
    for (var i = 0; i < task.stepIndex && i < steps.length; i++) {
      done += steps[i].turnsRequired;
    }
    final ratio = done / total;
    return ratio.clamp(0.0, 1.0).toDouble();
  }

  /// 任务剩余月数（当前时间到下期限；逾期为负数，当月到期为 0）。
  int npcTaskRemainingMonths(
    NpcTaskProgress task, {
    int? year,
    int? month,
  }) {
    final nowYear = year ?? progress.year;
    final nowMonth = month ?? progress.month;
    final due = task.deadlineYear * 12 + task.deadlineMonth;
    final now = nowYear * 12 + nowMonth;
    return due - now;
  }

  /// 任务当前步骤描述（按任务快照的 stepIndex 查模板）。
  String npcTaskCurrentStepDesc(NpcTaskProgress task) {
    final template = npcTaskTemplateById(task.taskId);
    if (template == null || task.stepIndex >= template.steps.length) return '';
    return template.steps[task.stepIndex].description;
  }

  /// 任务总步骤数（用于「第 x/y 步」展示）。
  int npcTaskTotalSteps(NpcTaskProgress task) {
    final template = npcTaskTemplateById(task.taskId);
    return template?.steps.length ?? 0;
  }

  // ==================== 内部工具 ====================

  /// 当前时间加 N 个月，返回 (year, month)。
  (int, int) _addMonths(int year, int month, int months) {
    var total = year * 12 + (month - 1) + months;
    return (total ~/ 12, total % 12 + 1);
  }

  /// 当前时间是否晚于截止时间（逾期）。
  bool _isAfter(int curYear, int curMonth, int dueYear, int dueMonth) {
    final cur = curYear * 12 + curMonth;
    final due = dueYear * 12 + dueMonth;
    return cur > due;
  }

  // ==================== M3 · 指令自注册 ====================

  /// 把本领域指令注册进注册表（order 与历史帮助文本顺序一致）。
  void registerNpcTaskCommands(CommandRegistry registry) {
    registry.register(
      CommandSpec(
        aliases: const ['任务列表', '任务2', 'tasks2'],
        order: 28,
        helpLine: '任务列表 / tasks2    查看多步骤任务（难度/期限/奖励）',
        handler: (args) => CommandResult(text: formatNpcTaskPanelV2()),
      ),
    );
    registry.register(
      CommandSpec(
        aliases: const ['接任务', 'accept'],
        order: 29,
        requiredArgCount: 1,
        missingArgsHint: '接谁的任务？如「接任务 艾德·史塔克」。输入「任务列表」看可接任务。',
        helpLine: '接任务 / accept [名字] 接下多步骤任务（如 接任务 艾德·史塔克）',
        handler: (args) => CommandResult(text: acceptNpcTaskV2(normalizeNpcAlias(this, args))),
      ),
    );
    registry.register(
      CommandSpec(
        aliases: const ['进度', '任务进度', 'progress'],
        order: 30,
        helpLine: '进度 / progress     查看任务进度（进行中/完成/失败）',
        handler: (args) => CommandResult(text: formatNpcTaskProgressPanel()),
      ),
    );
  }
  // ==================== M3 · 月度结算管线自注册 ====================

  /// 把本领域（多步骤任务推进 + 逾期检查）钩子注册进管线。
  void registerNpcTaskMonthlyHooks(MonthlyPipeline pipeline) {
    pipeline.register(
      MonthlyHookSpec(
        id: 'task_advance',
        phase: MonthlyPhase.beforeAdvance,
        order: 8,
        outputOrder: 7,
        hook: () => MonthlyHookResult(
          text: advanceNpcTasks(),
          outputOrder: 7,
        ),
      ),
    );
    pipeline.register(
      MonthlyHookSpec(
        id: 'task_deadline',
        phase: MonthlyPhase.beforeAdvance,
        order: 9,
        outputOrder: 8,
        hook: () => MonthlyHookResult(
          text: checkNpcTaskDeadlines(),
          outputOrder: 8,
        ),
      ),
    );
  }
}
