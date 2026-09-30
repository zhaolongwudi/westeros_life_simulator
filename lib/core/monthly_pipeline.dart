/// 月度结算管线（Batch 10-28 · M3 架构解耦 · 月度结算管线）。
///
/// 旧实现：[mixin_play.advanceMonth] 用一长串顺序调用把各领域的月度结算
/// 硬编码在一起，新增一个领域（如 Batch 10-25 的配偶月度事件）必须同时
/// 改 mixin_play 的调用段 + 文本拼接段，且 on 子句也要跟着加依赖。
///
/// 新实现：各领域自行注册 [MonthlyHookSpec]，由管线执行。
///
/// **执行顺序与文本顺序必须分开**（拆分时最容易丢的行为）：
/// 1. 执行顺序（phase + order）：各钩子的调用次序；
/// 2. 文本顺序（outputOrder）：本月叙事里各段落的排列次序。
/// 旧实现两者不同——例如头衔晋升在序列第 3 位执行，但文案排在任务逾期之后。
///
/// **为什么分两个阶段**：旧实现中 `advanceTime()` 位于序列中段，而各钩子
/// 都以 `progress.turnCount` 为随机种子，跨过它即换种子，故拆成
/// [MonthlyPhase.beforeAdvance] / [MonthlyPhase.afterAdvance] 两段。
library;

/// 月度结算阶段。
enum MonthlyPhase {
  /// 时间推进之前执行（种子为推进前的 turnCount）。
  beforeAdvance,

  /// 时间推进之后执行（种子为推进后的 turnCount）。
  afterAdvance,
}

/// 单个月度钩子的执行结果。
class MonthlyHookResult {
  const MonthlyHookResult({required this.text, this.outputOrder = 0});

  /// 追加到月度叙事的文本（空串表示本月无事发生）。
  final String text;

  /// 该段文本在本月叙事中的排序（0 表示不输出）。
  final int outputOrder;
}

/// 月度钩子：返回本月叙事结果。
typedef MonthlyHook = MonthlyHookResult Function();

/// 一条月度钩子的注册描述。
class MonthlyHookSpec {
  const MonthlyHookSpec({
    required this.id,
    required this.hook,
    required this.phase,
    required this.order,
    required this.outputOrder,
  });

  /// 钩子标识（测试与调试用，需全库唯一）。
  final String id;

  /// 执行体。
  final MonthlyHook hook;

  /// 执行阶段（决定它在时间推进之前还是之后跑）。
  final MonthlyPhase phase;

  /// 执行顺序（同阶段内升序执行）。
  final int order;

  /// 文本拼接顺序（可与执行顺序不同）。
  final int outputOrder;
}

/// 月度结算管线：分阶段有序执行全部已注册钩子。
class MonthlyPipeline {
  final List<MonthlyHookSpec> _specs = <MonthlyHookSpec>[];

  /// 重复注册的钩子 id（正常应恒为空）。
  final List<String> duplicateIds = <String>[];

  /// 注册一个钩子；同 id 重复注册不覆盖，仅记录到 [duplicateIds]。
  void register(MonthlyHookSpec spec) {
    for (final s in _specs) {
      if (s.id == spec.id) {
        duplicateIds.add(spec.id);
        return;
      }
    }
    _specs.add(spec);
  }

  /// 已注册钩子数。
  int get hookCount => _specs.length;

  /// 已注册钩子 id（执行顺序：阶段 → order）。
  List<String> get orderedIds => _sorted().map((s) => s.id).toList();

  List<MonthlyHookSpec> _sorted() {
    final list = List<MonthlyHookSpec>.from(_specs);
    list.sort((a, b) {
      final c = a.phase.index.compareTo(b.phase.index);
      if (c != 0) return c;
      return a.order.compareTo(b.order);
    });
    return list;
  }

  /// 执行指定阶段的钩子（按执行顺序），返回非空结果。
  List<MonthlyHookResult> runPhase(MonthlyPhase phase) {
    final out = <MonthlyHookResult>[];
    for (final spec in _sorted()) {
      if (spec.phase != phase) continue;
      final result = spec.hook();
      if (result.text.isEmpty) continue;
      out.add(result);
    }
    return out;
  }

  /// 跑完一个完整月：推进前钩子 → 推进时钟 → 推进后钩子 → 按文本顺序拼接。
  ///
  /// [advanceClock] 由调用方注入（引擎的 advanceTime），管线本身不直接
  /// 依赖状态层，因此可独立测试。
  String runMonth({required void Function() advanceClock}) {
    final before = runPhase(MonthlyPhase.beforeAdvance);
    advanceClock();
    final after = runPhase(MonthlyPhase.afterAdvance);
    final merged = <MonthlyHookResult>[...before, ...after];
    merged.sort((a, b) => a.outputOrder.compareTo(b.outputOrder));
    final buf = StringBuffer();
    for (final r in merged) {
      buf.writeln(r.text);
    }
    return buf.toString();
  }
}