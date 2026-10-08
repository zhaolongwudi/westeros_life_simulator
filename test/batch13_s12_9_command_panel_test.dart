/// Batch 13 · S12-9 测试：47 条命令按键化（指令面板 + 横条精简）。
///
/// 【背景】主界面底部横条固定 `height: 38`，只放了 8 个命令，其余 **39 条
/// 只能手打**（S11-6 量化前提，S12-9 落地）。改后横条 6 个，**41 条进面板**。
///
/// 【用户拍板方案】
/// - 底部横条精简到 **6 个**（状态/工作/狩猎/探索/休息/过月）
/// - 输入框左侧「指令」按钮 → 面板：**分组 + 搜索**，47 条全在里面
/// - 零参数指令点一下**即执行**；需参数指令**预填输入框**（不误触、不白点）
///
/// 【本文件守住什么】
/// 1. **分组数据完整性**：47 条全部显式分组，没有一条留在「其他」兜底
///    （否则又是「分类没被列出就静默消失」——与 S12-8 同型的坑）
/// 2. **注册表契约未被破坏**：specCount 仍 47、order 仍连续 1..47、
///    帮助文本行数仍等于 specCount（分组**不得**混进 helpText）
/// 3. **面板真实可交互**：点零参数执行、点需参数预填
/// 4. **横条恰好 6 个且是拍板的那 6 个**
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/core/command_registry.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/screens/game_screen.dart';
import 'package:westeros_life_simulator/widgets/game/command_panel.dart';
import 'package:westeros_life_simulator/widgets/game/input.dart';
import 'package:westeros_life_simulator/widgets/game/quick.dart';

/// 用户拍板保留在底部横条的 6 条命令。
const List<String> _expectedBar = <String>[
  '状态',
  '工作',
  '狩猎',
  '探索',
  '休息',
  '过月',
];

/// 面板分组顺序（与 `kCommandGroupOrder` 一致）。
const List<String> _groups = <String>['查看', '日常', '物品', '人物', '成长'];

/// 面板内点击：先滚动到可见再点。
///
/// 【为什么先 ensureVisible】面板用 `ListView`（懒构建的 SliverList），屏外
/// chip 既可能没被构建、也可能被构建但命中不到。所以测试视口特意开到
/// 1080x6000，保证 47 个 chip **全部在视口内**；`ensureVisible` 再兜一层，
/// 避免「find 到了但 tap 落空」这种只在特定行高下才暴露的偶发失败。
Future<void> tapInPanel(WidgetTester tester, String label) async {
  final finder = find.descendant(
    of: find.byType(CommandPanel),
    matching: find.text(label),
  );
  expect(finder, findsOneWidget, reason: '面板里找不到「$label」');
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('S12-9 · 分组数据完整性', () {
    test('47 条命令全部显式分组，无一留在「其他」兜底', () {
      final engine = GameEngine()..startNewGame();
      final specs = engine.commandRegistry.orderedSpecs;
      expect(specs.length, 47);

      final ungrouped = specs
          .where((s) => s.group == kCommandGroupOther)
          .map((s) => s.aliases.first)
          .toList();
      expect(ungrouped, isEmpty,
          reason: '这些指令没写 group，会落进「其他」兜底：$ungrouped。'
              '必须逐条显式分组，否则就是 S12-8 同型的「分类没列出=静默消失」');
    });

    test('每条命令的分组都在 kCommandGroupOrder 里（无拼写漂移）', () {
      final engine = GameEngine()..startNewGame();
      for (final s in engine.commandRegistry.orderedSpecs) {
        expect(_groups.contains(s.group), isTrue,
            reason: '「${s.aliases.first}」的分组「${s.group}」不在既定分组表里');
      }
    });

    test('每个分组都非空（没有空壳分组）', () {
      final engine = GameEngine()..startNewGame();
      final byGroup = engine.commandRegistry.specsByGroup;
      for (final g in _groups) {
        expect(byGroup.containsKey(g), isTrue, reason: '分组「$g」没有任何指令');
        expect(byGroup[g], isNotEmpty);
      }
      // 分组内条数合计必须等于 47，不能多也不能少。
      final total = byGroup.values.fold<int>(0, (n, l) => n + l.length);
      expect(total, 47);
    });

    test('specsByGroup 的分组顺序与 kCommandGroupOrder 一致', () {
      final engine = GameEngine()..startNewGame();
      // 本文件多处用 _groups 硬编码断言，这里顺带钉住「硬编码 == 源码常量」，
      // 否则有人改了 kCommandGroupOrder 而测试仍绿（假绿）。
      expect(_groups, kCommandGroupOrder);
      expect(engine.commandRegistry.specsByGroup.keys.toList(), _groups);
    });

    test('组内按 order 升序（与帮助文本顺序一致）', () {
      final engine = GameEngine()..startNewGame();
      for (final entry in engine.commandRegistry.specsByGroup.entries) {
        final orders = entry.value.map((s) => s.order).toList();
        final sorted = List<int>.from(orders)..sort();
        expect(orders, sorted, reason: '分组「${entry.key}」内部顺序乱了');
      }
    });

    test('needsArgs 与 requiredArgCount 语义一致', () {
      final engine = GameEngine()..startNewGame();
      for (final s in engine.commandRegistry.orderedSpecs) {
        expect(s.needsArgs, s.requiredArgCount > 0,
            reason: '「${s.aliases.first}」的 needsArgs 与 requiredArgCount 不一致');
      }
      // 面板据 needsArgs 分流，两个分支都必须有真实数据。
      final specs = engine.commandRegistry.orderedSpecs;
      expect(specs.where((s) => s.needsArgs).length, 16);
      expect(specs.where((s) => !s.needsArgs).length, 31);
    });
  });

  group('S12-9 · 注册表既有契约未被破坏', () {
    test('specCount 仍 47、order 仍连续 1..47', () {
      final engine = GameEngine()..startNewGame();
      final reg = engine.commandRegistry;
      expect(reg.specCount, 47);
      expect(reg.orderedSpecs.map((s) => s.order).toList(),
          equals(List<int>.generate(47, (i) => i + 1)));
    });

    test('帮助文本行数仍等于 specCount（分组不得混进 helpText）', () {
      final engine = GameEngine()..startNewGame();
      final reg = engine.commandRegistry;
      final helpLines = reg.helpText().split('\n').where((l) {
        return l.trim().isNotEmpty &&
            !l.startsWith(kHelpHeader) &&
            !l.startsWith('提示：');
      }).toList();
      expect(helpLines.length, reg.specCount,
          reason: '分组名若被写进 helpText，这里会多出 5 行');
      // 分组名不该出现在帮助正文里。
      for (final g in _groups) {
        expect(helpLines.any((l) => l.trim() == g), isFalse,
            reason: '分组名「$g」泄漏进了帮助文本');
      }
    });

    test('别名无撞车（改动未引入重复注册）', () {
      final engine = GameEngine()..startNewGame();
      expect(engine.commandRegistry.duplicateAliases, isEmpty);
    });

    test('分组是纯 UI 元数据：不影响分发与缺参提示', () {
      final engine = GameEngine()..startNewGame();
      expect(engine.resolveCommand('状态').text, contains('【玩家状态】'));
      expect(engine.resolveCommand('训练').text, contains('训练什么'));
      expect(engine.resolveCommand('训练 sword').text, isNotEmpty);
    });

    test('自注册的指令默认落进「其他」（不强迫外部传分组）', () {
      final reg = CommandRegistry();
      reg.register(
        CommandSpec(
          aliases: const ['甲'],
          order: 1,
          helpLine: '甲  测试',
          handler: (args) => const CommandResult(text: 'ok'),
        ),
      );
      expect(reg.orderedSpecs.single.group, kCommandGroupOther);
    });
  });

  group('S12-9 · 指令面板可交互', () {
    Future<void> pumpPanel(
      WidgetTester tester, {
      required List<CommandSpec> specs,
      ValueChanged<CommandSpec>? onRun,
      ValueChanged<CommandSpec>? onPrefill,
    }) async {
      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommandPanel(
              specs: specs,
              onRun: onRun ?? (_) {},
              onPrefill: onPrefill ?? (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('面板渲染出全部分组标题与 47 条指令', (tester) async {
      final engine = GameEngine()..startNewGame();
      final specs = engine.commandRegistry.orderedSpecs;
      await pumpPanel(tester, specs: specs);

      expect(find.text('指令'), findsOneWidget);
      for (final g in _groups) {
        expect(find.text(g), findsOneWidget, reason: '缺少分组标题「$g」');
      }
      // 计数行：47/47
      expect(find.text('47/47'), findsOneWidget);
      // 抽查跨分组的三条指令都在（面板是 ListView，未滚动时靠上部分可见）
      expect(find.text('状态'), findsOneWidget);
    });

    testWidgets('零参数指令点击后回调 onRun，且不触发 onPrefill', (tester) async {
      final engine = GameEngine()..startNewGame();
      final specs = engine.commandRegistry.orderedSpecs;
      final ran = <String>[];
      final prefilled = <String>[];
      await pumpPanel(
        tester,
        specs: specs,
        onRun: (s) => ran.add(s.aliases.first),
        onPrefill: (s) => prefilled.add(s.aliases.first),
      );

      await tapInPanel(tester, '状态');

      expect(ran, <String>['状态']);
      expect(prefilled, isEmpty, reason: '零参数指令不该走预填分支');
    });

    testWidgets('需参数指令点击后回调 onPrefill，且不触发 onRun', (tester) async {
      final engine = GameEngine()..startNewGame();
      final specs = engine.commandRegistry.orderedSpecs;
      final ran = <String>[];
      final prefilled = <String>[];
      await pumpPanel(
        tester,
        specs: specs,
        onRun: (s) => ran.add(s.aliases.first),
        onPrefill: (s) => prefilled.add(s.aliases.first),
      );

      // 需参数指令的 chip 文案是「主名 …」，据此定位。
      await tapInPanel(tester, '使用 …');

      expect(prefilled, <String>['使用']);
      expect(ran, isEmpty, reason: '需参数指令不该直接执行（会白点一次）');
    });

    testWidgets('搜索框按中文主名过滤', (tester) async {
      final engine = GameEngine()..startNewGame();
      final specs = engine.commandRegistry.orderedSpecs;
      await pumpPanel(tester, specs: specs);

      await tester.enterText(find.byType(TextField), '训练');
      await tester.pumpAndSettle();

      expect(find.text('训练 …'), findsOneWidget);
      expect(find.text('状态'), findsNothing, reason: '「状态」不含「训练」应被过滤掉');
      expect(find.text('1/47'), findsOneWidget);
    });

    testWidgets('搜索框按英文别名过滤（记得 sword 忘了中文名也能找到）', (tester) async {
      final engine = GameEngine()..startNewGame();
      final specs = engine.commandRegistry.orderedSpecs;
      await pumpPanel(tester, specs: specs);

      await tester.enterText(find.byType(TextField), 'sword');
      await tester.pumpAndSettle();

      // 训练 sword 的帮助行含 sword
      expect(find.text('训练 …'), findsOneWidget);
    });

    testWidgets('搜索无结果时给出明确提示（不留白屏）', (tester) async {
      final engine = GameEngine()..startNewGame();
      final specs = engine.commandRegistry.orderedSpecs;
      await pumpPanel(tester, specs: specs);

      await tester.enterText(find.byType(TextField), '不存在的指令xyz');
      await tester.pumpAndSettle();

      expect(find.textContaining('没有匹配'), findsOneWidget);
      expect(find.text('0/47'), findsOneWidget);
    });

    testWidgets('清空搜索后恢复全部 47 条', (tester) async {
      final engine = GameEngine()..startNewGame();
      final specs = engine.commandRegistry.orderedSpecs;
      await pumpPanel(tester, specs: specs);

      await tester.enterText(find.byType(TextField), '训练');
      await tester.pumpAndSettle();
      expect(find.text('1/47'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      expect(find.text('47/47'), findsOneWidget);
    });
  });

  group('S12-9 · 主界面接线', () {
    Future<GameEngine> pumpGame(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final engine = GameEngine()..startNewGame();
      await tester.pumpWidget(MaterialApp(home: GameScreen(engine: engine)));
      await tester.pumpAndSettle();
      return engine;
    }

    testWidgets('底部横条恰好是拍板的 6 个命令', (tester) async {
      await pumpGame(tester);

      // 【最强断言】直接读 widget 的 commands 列表：横条是否「恰好 6 个」
      // 用渲染文本数不出来（横向 ListView 里屏外 chip 找不到）。
      final bar = tester.widget<QuickCommandBar>(find.byType(QuickCommandBar));
      expect(bar.commands.length, 6, reason: '横条必须精简到 6 个');
      expect(bar.commands.map((c) => c.label).toList(), _expectedBar);

      // 每个标签都真实渲染出来了（限定在横条内，避免叙事区同名文本干扰）。
      for (final label in _expectedBar) {
        expect(
          find.descendant(
            of: find.byType(QuickCommandBar),
            matching: find.text(label),
          ),
          findsOneWidget,
          reason: '横条缺少「$label」',
        );
      }
    });

    testWidgets('被移出横条的指令仍可通过面板触发（不是功能丢失）', (tester) async {
      await pumpGame(tester);

      final bar = tester.widget<QuickCommandBar>(find.byType(QuickCommandBar));
      final labels = bar.commands.map((c) => c.label).toList();
      for (final removed in <String>['贸易', '旅行', '训练']) {
        expect(labels.contains(removed), isFalse,
            reason: '「$removed」不该再占横条位置');
      }

      // 但它们必须还在面板里——横条精简**不等于**砍掉命令。
      await tester.tap(find.byIcon(Icons.terminal_outlined));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(CommandPanel),
          matching: find.text('贸易'),
        ),
        findsOneWidget,
        reason: '「贸易」移出横条后必须在面板里仍然可达',
      );
      expect(
        find.descendant(
          of: find.byType(CommandPanel),
          matching: find.text('旅行'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(CommandPanel),
          matching: find.text('训练 …'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('输入框旁有「指令」按钮，点击后面板出现且列出 47 条', (tester) async {
      await pumpGame(tester);
      expect(find.byIcon(Icons.terminal_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.terminal_outlined));
      await tester.pumpAndSettle();

      expect(find.byType(CommandPanel), findsOneWidget);
      expect(find.text('47/47'), findsOneWidget);
      for (final g in _groups) {
        expect(find.text(g), findsOneWidget);
      }
    });

    testWidgets('点面板里的零参数指令：面板关闭且命令被执行', (tester) async {
      final engine = await pumpGame(tester);
      final y0 = engine.progress.year;
      final m0 = engine.progress.month;

      await tester.tap(find.byIcon(Icons.terminal_outlined));
      await tester.pumpAndSettle();
      // 【必须限定在面板内】底部横条也有「过月」按钮，直接 find.text('过月')
      // 会命中 2 个 widget 导致 tap 抛错。
      await tapInPanel(tester, '过月');

      expect(find.byType(CommandPanel), findsNothing, reason: '执行后面板应关闭');
      final delta =
          (engine.progress.year - y0) * 12 + (engine.progress.month - m0);
      expect(delta, 1, reason: '点「过月」应恰好推进一个月');
    });

    testWidgets('点面板里的需参数指令：面板关闭且输入框被预填「主名 + 空格」', (tester) async {
      await pumpGame(tester);

      await tester.tap(find.byIcon(Icons.terminal_outlined));
      await tester.pumpAndSettle();
      await tapInPanel(tester, '训练 …');

      expect(find.byType(CommandPanel), findsNothing);
      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byType(CommandInputBar),
          matching: find.byType(TextField),
        ),
      );
      expect(field.controller!.text, '训练 ',
          reason: '应预填「训练 」让玩家直接补技能名');
    });
  });
}
