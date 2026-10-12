/// S15-3 测试：指令面板入口按钮化 + 输入框引导文案。
///
/// 【本批修的是什么】用户 7 图反馈「输入框提示都是输入指令，希望把输入的
/// 指令全都做成按钮或 UI 界面」。47 条指令的按钮化 UI 已存在（S12-9 的
/// `CommandPanel`：分组可搜索面板），但入口是输入框左侧**仅图标**按钮
/// （`Icons.terminal_outlined`，无文字），placeholder 只引导打字——
/// 玩家（尤其新装机用户）发现不了面板，以为只能手动输入。
///
/// 【本批怎么修】入口改 `TextButton.icon`（图标 + 「指令」文字，可见性
/// 质变）；placeholder 改为双向引导（直接输入 / 点按钮开面板）。
///
/// 【与既有测试的兼容性】`batch13_s12_9` 4 处 `find.byIcon(Icons.terminal_outlined)`
/// ⇒ 新按钮保留该图标（TextButton.icon 内部仍渲染 Icon）；
/// `batch10_60:69` 断言 placeholder `textContaining('输入指令')` ⇒ 新文案
/// 保留该词。本文件是**加法判别式**：锁「按钮有文字」「点击弹面板」两个新契约。
///
/// 【pump 方式】与 `batch10_60` 主界面冒烟同款：`westerosTheme()` +
/// `GameScreen(engine:...)` + pumpAndSettle（该测试已证明此路径可 settle）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/screens/game_screen.dart';
import 'package:westeros_life_simulator/theme/westeros_theme.dart';

Future<void> _pumpGame(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final engine = GameEngine()..startNewGame();
  await tester.pumpWidget(
    MaterialApp(
      theme: westerosTheme(),
      home: GameScreen(engine: engine),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('S15-3 指令面板入口：从孤图标变为「图标 + 文字」按钮', () {
    testWidgets('输入区可见「指令」文字（孤图标判别式）', (tester) async {
      await _pumpGame(tester);

      // 🔴 判别断言：入口按钮必须带「指令」文字（修复前是孤图标，找不到该 Text）
      expect(find.text('指令'), findsOneWidget,
          reason: '指令面板入口应有可见文字，孤图标发现性差（用户 7 图反馈）');
      // 图标保留（batch13_s12_9 的 4 处 byIcon 断言依赖它）
      expect(find.byIcon(Icons.terminal_outlined), findsOneWidget);
    });

    testWidgets('点「指令」文字按钮弹出 CommandPanel（与图标同效）', (tester) async {
      await _pumpGame(tester);

      await tester.tap(find.text('指令'));
      await tester.pumpAndSettle();

      // 面板打开的标志：搜索框与分组列表出现（S12-9 既有行为）
      expect(find.textContaining('搜索'), findsWidgets,
          reason: '点「指令」文字按钮应弹出指令面板');
    });

    testWidgets('placeholder 双向引导：既提示直接输入，也提示面板入口',
        (tester) async {
      await _pumpGame(tester);

      // 引导词两要素：直接输入 + 面板入口（兼容 batch10_60 的「输入指令」前缀断言）
      expect(find.textContaining('输入指令'), findsOneWidget,
          reason: 'placeholder 仍含「输入指令」（batch10_60 契约）');
      expect(find.textContaining('「指令」'), findsOneWidget,
          reason: 'placeholder 应引导点「指令」按钮开面板');
    });
  });
}
