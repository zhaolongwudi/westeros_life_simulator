/// NPC 任务链模型（Batch 10-18）。
///
/// 在既有 Npc.tasks（简单标题列表）之上提供多步骤任务：
/// - NpcTaskTemplate：静态任务模板（类型/难度/期限/步骤/奖励）
/// - NpcTaskStep：单步任务（描述 + 推进所需回合数）
/// - NpcTaskProgress：玩家进行中的任务实例（当前步骤/期限/完成/失败）
///
/// 玩家进行中任务存 Player.activeTasks（可序列化，坑 16 避免 flags）。
library;

/// 任务类型（决定叙事与部分奖励方向）。
enum NpcTaskType {
  escort, // 护送
  delivery, // 送信/送货
  hunt, // 狩猎/猎杀
  investigate, // 调查
  diplomacy, // 外交/游说
}

/// 任务单步。
class NpcTaskStep {
  const NpcTaskStep({
    required this.description,
    required this.turnsRequired,
  });

  /// 步骤描述（叙事）。
  final String description;

  /// 完成此步所需推进次数（探索/过月各计 1 次）。
  final int turnsRequired;
}

/// 静态任务模板（按 NPC 配置）。
class NpcTaskTemplate {
  const NpcTaskTemplate({
    required this.id,
    required this.npcId,
    required this.title,
    required this.type,
    required this.difficulty,
    required this.deadlineMonths,
    required this.steps,
    required this.rewardGold,
    required this.rewardReputation,
    required this.rewardRelation,
  });

  /// 任务唯一 ID。
  final String id;

  /// 发布 NPC 的 ID。
  final String npcId;

  /// 任务标题。
  final String title;

  /// 任务类型。
  final NpcTaskType type;

  /// 难度（1-5，影响奖励倍率）。
  final int difficulty;

  /// 期限（从接任务起计 N 个月，逾期失败）。
  final int deadlineMonths;

  /// 步骤序列（≥1）。
  final List<NpcTaskStep> steps;

  /// 基础金币奖励（实际 = 基础 × 难度系数）。
  final int rewardGold;

  /// 声望奖励。
  final int rewardReputation;

  /// 好感奖励。
  final int rewardRelation;

  /// 难度系数（1+0.25×(难度-1)，四舍五入取整倍率）。
  int get difficultyMultiplier => 1 + (difficulty - 1);

  /// 实际金币奖励。
  int get finalGoldReward => rewardGold * difficultyMultiplier;

  /// 类型中文标签。
  String get typeLabel => switch (type) {
        NpcTaskType.escort => '护送',
        NpcTaskType.delivery => '送信',
        NpcTaskType.hunt => '猎杀',
        NpcTaskType.investigate => '调查',
        NpcTaskType.diplomacy => '游说',
      };

  /// 全部步骤所需总推进次数（进度条分母，Batch 10-24）。
  int get totalTurns => steps.fold(0, (sum, s) => sum + s.turnsRequired);
}

/// 玩家进行中的任务实例。
class NpcTaskProgress {
  const NpcTaskProgress({
    required this.taskId,
    required this.npcId,
    required this.title,
    required this.stepIndex,
    required this.deadlineYear,
    required this.deadlineMonth,
    this.stepProgress = 0,
    this.completed = false,
    this.failed = false,
  });

  /// 任务模板 ID。
  final String taskId;

  /// 发布 NPC ID。
  final String npcId;

  /// 任务标题。
  final String title;

  /// 当前步骤下标（0 起，完成任务时 = 步骤数）。
  final int stepIndex;

  /// 当前步骤已推进次数。
  final int stepProgress;

  /// 截止年份。
  final int deadlineYear;

  /// 截止月份。
  final int deadlineMonth;

  /// 是否已完成。
  final bool completed;

  /// 是否已失败（逾期）。
  final bool failed;

  NpcTaskProgress copyWith({
    int? stepIndex,
    int? stepProgress,
    bool? completed,
    bool? failed,
  }) {
    return NpcTaskProgress(
      taskId: taskId,
      npcId: npcId,
      title: title,
      stepIndex: stepIndex ?? this.stepIndex,
      stepProgress: stepProgress ?? this.stepProgress,
      deadlineYear: deadlineYear,
      deadlineMonth: deadlineMonth,
      completed: completed ?? this.completed,
      failed: failed ?? this.failed,
    );
  }

  /// 是否进行中（未完成未失败）。
  bool get isActive => !completed && !failed;

  Map<String, dynamic> toJson() {
    return {
      'taskId': taskId,
      'npcId': npcId,
      'title': title,
      'stepIndex': stepIndex,
      'stepProgress': stepProgress,
      'deadlineYear': deadlineYear,
      'deadlineMonth': deadlineMonth,
      'completed': completed,
      'failed': failed,
    };
  }

  factory NpcTaskProgress.fromJson(Map<String, dynamic> json) {
    return NpcTaskProgress(
      taskId: json['taskId'] as String,
      npcId: json['npcId'] as String,
      title: json['title'] as String,
      stepIndex: json['stepIndex'] as int? ?? 0,
      stepProgress: json['stepProgress'] as int? ?? 0,
      deadlineYear: json['deadlineYear'] as int,
      deadlineMonth: json['deadlineMonth'] as int,
      completed: json['completed'] as bool? ?? false,
      failed: json['failed'] as bool? ?? false,
    );
  }
}