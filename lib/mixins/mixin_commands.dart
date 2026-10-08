/// 指令混入：按注册表分发玩家输入（Batch 10-28 · M3 架构解耦 · 指令注册表）。
///
/// 本混入只负责三件事：拉齐各领域注册 → 按别名分发 → 生成未知指令/帮助文案。
/// 各领域指令由各自 mixin 的 `registerXxxCommands(CommandRegistry)` 自行注册，
/// 不再像 Batch 10-28 之前那样堆在一个 200 行巨型 switch 里
/// （新增玩法原本要改：switch 分支 + 帮助文本 + import + on 依赖四处）。
library;
import 'dart:math';

import '../core/command_registry.dart';
import '../providers/game_provider_base.dart';
import '../utils/command_sanitizer.dart';
import 'mixin_adventure.dart';
import 'mixin_generation.dart';
import 'mixin_letter.dart';
import 'mixin_life.dart';
import 'mixin_marriage.dart';
import 'mixin_npc_interact.dart';
import 'mixin_npc_task.dart';
import 'mixin_play.dart';
import 'mixin_systems.dart';

/// 指令混入。挂在 [GameProviderBase] 上，依赖全部玩法 mixin。
///
/// Dart 的 mixin 不能使用 `with` 组合，改为在 `on` 子句中列出
/// 全部依赖 mixin（宿主类同时混入它们即可满足约束）。
mixin GameCommandsMixin
    on
        GameProviderBase,
        GamePlayMixin,
        GameSystemsMixin,
        GameLetterMixin,
        GameAdventureMixin,
        GameLifeMixin,
        GameNpcInteractMixin,
        GameGenerationMixin,
        GameMarriageMixin,
        GameNpcTaskMixin {
  CommandRegistry? _registry;

  /// 指令注册表（首次访问时构建并缓存）。
  ///
  /// 每新增一个领域，只需在这里追加一行 `registerXxxCommands(registry)`。
  CommandRegistry get commandRegistry {
    final cached = _registry;
    if (cached != null) return cached;
    final registry = CommandRegistry();
    registerPlayCommands(registry);
    registerSystemsCommands(registry);
    registerLetterCommands(registry);
    registerAdventureCommands(registry);
    registerLifeCommands(registry);
    registerNpcInteractCommands(registry);
    registerNpcTaskCommands(registry);
    registerGenerationCommands(registry);
    registerMarriageCommands(registry);
    registerCoreCommands(registry);
    _registry = registry;
    return registry;
  }

  /// 解析并执行一条玩家指令。
  ///
  /// 返回响应文本。未知指令返回帮助提示。
  /// 入口护栏（Batch 10-37 · M6）：超长截断 + 纯符号/空白兜底。
  CommandResult resolveCommand(String raw) {
    // 输入护栏：截断 + 去空白
    final input = sanitizeCommand(raw);
    if (input.isEmpty) {
      return const CommandResult(text: '请输入指令。输入「帮助」查看可用指令。');
    }
    if (isCommandNoise(input)) {
      return const CommandResult(text: '这条指令我看不太懂……输入「帮助」查看可用指令。');
    }
    final registry = commandRegistry;
    final exact = input.split(RegExp(r'\s+')).first;
    final args = input.substring(exact.length).trim();
    return registry.resolve(exact, args) ??
        CommandResult(text: _unknownHelp(exact));
  }

  /// 帮助文本（由注册表逐条生成，文案与旧版逐字一致）。
  String helpText() => commandRegistry.helpText();

  /// 核心指令注册（各领域指令由各自 mixin 注册）。
  void registerCoreCommands(CommandRegistry registry) {
    registry.register(
      CommandSpec(
        aliases: const ['帮助', 'help'],
        order: 46,
        group: '查看',
        helpLine: '帮助 / help         显示本帮助',
        handler: (args) => CommandResult(text: helpText()),
      ),
    );
  }

  /// 未知指令提示。
  String _unknownHelp(String exact) {
    final rnd = Random(exact.hashCode);
    final lines = <String>[
      '「$exact」不是一条你能执行的指令。',
      '维斯特洛不认这个命令。',
      '你张了张嘴，却不知道要做什么。',
    ];
    return '${lines[rnd.nextInt(lines.length)]}\n${helpText()}';
  }
}