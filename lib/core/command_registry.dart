/// 指令注册表（Batch 10-28 · M3 架构解耦 · 指令注册表）。
///
/// 旧实现：[mixin_commands] 用一个巨型 `switch` 硬编码全部指令，
/// 新增一条玩法要改「switch 分支 + 帮助文本 + import + on 依赖」四处，
/// 且 mixin_commands 成为所有领域的超级扇入点。
///
/// 新实现：每个领域 mixin 自行注册自己的指令（`registerXxxCommands`），
/// mixin_commands 只做「按固定顺序拉齐注册 + 按别名分发」两件事。
/// 新增玩法的成本降为：在自己的 mixin 里加一条注册 + 宿主 with 一行。
library;

/// 指令处理函数：接收参数串（不含指令名），返回执行结果。
typedef CommandHandler = CommandResult Function(String args);

/// 指令执行结果。
class CommandResult {
  const CommandResult({
    required this.text,
    this.consumedTurn = false,
    bool? needsTimeAdvance,
  }) : needsTimeAdvance = needsTimeAdvance ?? consumedTurn;

  /// 响应文本。
  final String text;

  /// 是否消耗了一个回合（**语义：时间是否推进了**）。
  ///
  /// 注意这只是「事实陈述」，不代表调度方要替它推进时间——
  /// 推进动作看 [needsTimeAdvance]。
  final bool consumedTurn;

  /// 调度方（如 `GameScreen._submitCommand`）是否需要在指令返回后调用 `advanceMonth()`。
  ///
  /// 默认等于 [consumedTurn]。自行推进时间的指令（如「过月」，handler 内部已调用
  /// `advanceMonth()`）必须显式传 `false`，否则会出现「过月推进两次」。
  /// Batch 10-117（S2-1）之前 `consumedTurn` 全库无人消费，「探索」因此零时间成本。
  final bool needsTimeAdvance;
}

/// 一条指令的注册描述。
class CommandSpec {
  const CommandSpec({
    required this.aliases,
    required this.handler,
    required this.helpLine,
    required this.order,
    this.group = kCommandGroupOther,
    this.consumedTurn = false,
    this.missingArgsHint,
    this.requiredArgCount = 0,
  });

  /// 该指令的全部触发词（第一个为主名，其余为别名）。
  final List<String> aliases;

  /// 处理函数。
  final CommandHandler handler;

  /// 帮助文本中的一行（逐字保留，供 UI 展示与测试断言）。
  final String helpLine;

  /// 帮助文本与注册顺序（跨领域分组时靠 order 复原历史顺序）。
  final int order;

  /// 指令面板中的分组名（S12-9）。
  ///
  /// **只用于 UI 分组，不进 `helpText()`**——`m3_registry_test.dart` 断言
  /// 「帮助文本行数 == specCount」，往帮助里插分组标题会直接打红它。
  ///
  /// 默认 [kCommandGroupOther]：测试与外部自注册（`m3_registry_test.dart`
  /// 的「自注册演示」）不必显式传分组；引擎自带的 47 条则**全部显式声明**，
  /// 由 `batch13_s12_9_command_panel_test.dart` 守住「没有指令留在『其他』」。
  final String group;

  /// 执行后是否消耗一个回合（**声明性**：供帮助文本/测试/契约检查读取）。
  ///
  /// 真正的推进动作以 handler 返回的 `CommandResult.needsTimeAdvance` 为准——
  /// 两条通道必须一致，否则「声明消耗了但没推进」这类 bug 又会静默溜走。
  final bool consumedTurn;

  /// 参数不足时的提示文案（null 表示不校验参数）。
  final String? missingArgsHint;

  /// 最少参数个数（按空白切分计数）。
  final int requiredArgCount;

  /// 是否需要玩家补充参数（面板据此决定「直接执行」还是「预填输入框」）。
  bool get needsArgs => requiredArgCount > 0;
}

/// 未显式分组的指令归入此组（正常应恒为空，由测试守住）。
const String kCommandGroupOther = '其他';

/// 指令面板的分组顺序（S12-9）。
///
/// 只影响面板里的显示次序，与 `order`（帮助文本顺序）互不干涉。
const List<String> kCommandGroupOrder = <String>[
  '查看',
  '日常',
  '物品',
  '人物',
  '成长',
];

/// 指令注册表：别名 → 指令描述。
class CommandRegistry {
  final Map<String, CommandSpec> _byAlias = <String, CommandSpec>{};
  final List<CommandSpec> _specs = <CommandSpec>[];

  /// 被重复注册的别名（正常应恒为空；测试用它守住唯一性）。
  final List<String> duplicateAliases = <String>[];

  /// 注册一条指令。重复别名不覆盖后者，仅记录到 [duplicateAliases]。
  void register(CommandSpec spec) {
    _specs.add(spec);
    for (final alias in spec.aliases) {
      if (_byAlias.containsKey(alias)) {
        duplicateAliases.add(alias);
        continue;
      }
      _byAlias[alias] = spec;
    }
  }

  /// 按触发词查找指令描述。
  CommandSpec? lookup(String exact) => _byAlias[exact];

  /// 已注册指令数（按描述去重）。
  int get specCount => _specs.length;

  /// 已注册触发词总数（去重后）。
  int get aliasCount => _byAlias.length;

  /// 全部触发词。
  List<String> get aliases => List.unmodifiable(_byAlias.keys);

  /// 按 [CommandSpec.order] 升序排列的指令描述（帮助文本用）。
  List<CommandSpec> get orderedSpecs {
    final list = List<CommandSpec>.from(_specs);
    list.sort((a, b) {
      final c = a.order.compareTo(b.order);
      return c == 0 ? 0 : c;
    });
    return List.unmodifiable(list);
  }

  /// 按分组聚合的指令（S12-9 指令面板用）。
  ///
  /// - 分组顺序取自 [kCommandGroupOrder]，未列入的分组（如 [kCommandGroupOther]）
  ///   排在最后并按名称排序，保证输出**稳定可测**（不依赖 Map 迭代顺序）。
  /// - 组内按 [CommandSpec.order] 升序，与帮助文本一致。
  Map<String, List<CommandSpec>> get specsByGroup {
    final buckets = <String, List<CommandSpec>>{};
    for (final spec in orderedSpecs) {
      buckets.putIfAbsent(spec.group, () => <CommandSpec>[]).add(spec);
    }
    final known = kCommandGroupOrder.where(buckets.containsKey).toList();
    final extra = buckets.keys
        .where((g) => !kCommandGroupOrder.contains(g))
        .toList()
      ..sort();
    final ordered = <String, List<CommandSpec>>{};
    for (final g in <String>[...known, ...extra]) {
      ordered[g] = List<CommandSpec>.unmodifiable(buckets[g]!);
    }
    return Map<String, List<CommandSpec>>.unmodifiable(ordered);
  }

  /// 分发一条指令；未注册返回 null（由调用方生成未知指令提示）。
  CommandResult? resolve(String exact, String args) {
    final spec = _byAlias[exact];
    if (spec == null) return null;
    final parts = args.isEmpty
        ? const <String>[]
        : args.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length < spec.requiredArgCount) {
      return CommandResult(
        text: spec.missingArgsHint ?? '缺少参数，请补充后重试。',
      );
    }
    return spec.handler(args);
  }

  /// 由注册内容生成帮助文本。
  String helpText() {
    final buf = StringBuffer()..writeln(kHelpHeader);
    for (final spec in orderedSpecs) {
      buf.writeln(spec.helpLine);
    }
    buf.write(kHelpFooter);
    return buf.toString();
  }
}

/// 帮助文本抬头。
const String kHelpHeader = '【可用指令】';

/// 帮助文本结尾提示。
const String kHelpFooter =
    '提示：精力与饱食每月结算，饥饿会掉健康，注意休息与进食。\n';