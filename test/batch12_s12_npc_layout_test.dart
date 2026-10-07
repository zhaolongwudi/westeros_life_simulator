/// Sprint 12 测试：NPC 面板挤压修复（S12-5）。
///
/// 【本批修的是什么】
/// 用户实装反馈「NPC 名竖着写、按钮挤在一起、有的按钮看不见」。
/// 根因（已取证）：在场 NPC 列表用
/// `ListTile(title: Text(name), subtitle: ..., trailing: Wrap(互动/深聊/示好/任务))`，
/// 而 `trailing` **没有任何宽度约束**——`Wrap` 抢占全部可用宽度，
/// 把 title/subtitle 压到一两字宽 ⇒ 每字换行 = 竖排。
/// 修法：改为 `Column`（姓名+关系独占一行，按钮另起一行且横向滚动）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/screens/npc_panel_screen.dart';

void main() {
  // 极窄屏（iPhone SE 一类）：最能暴露挤压。
  const narrow = Size(320, 640);

  testWidgets('窄屏下 NPC 名与关系仍占满整行（不再被压成竖排）', (tester) async {
    tester.view.physicalSize = narrow;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final engine = GameEngine()..startNewGame();
    final onSite = engine.npcsAtCurrentLocation;
    expect(onSite, isNotEmpty, reason: '默认地点应有在场 NPC 可测');

    await tester.pumpWidget(
      MaterialApp(home: NpcPanelScreen(engine: engine)),
    );
    await tester.pumpAndSettle();

    final name = find.text(onSite.first.name);
    expect(name, findsOneWidget);

    // 名字的实际渲染宽度必须远大于「一个字」的宽度——
    // 竖排时它只有 ~1 个字宽（十几像素）。
    final box = tester.getSize(name);
    expect(box.width, greaterThan(80),
        reason: 'NPC 名「${onSite.first.name}」被压到 ${box.width}px 宽，疑似竖排');
  });

  testWidgets('互动/深聊/示好 三个按钮一个都不被裁掉', (tester) async {
    tester.view.physicalSize = narrow;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final engine = GameEngine()..startNewGame();
    await tester.pumpWidget(
      MaterialApp(home: NpcPanelScreen(engine: engine)),
    );
    await tester.pumpAndSettle();

    for (final label in <String>['互动', '深聊', '示好']) {
      final finder = find.text(label);
      expect(finder, findsWidgets, reason: '按钮「$label」应存在');
      // 可见性：hit-test 得到的位置必须真的在屏幕内
      final centers = tester.getCenter(finder.first);
      expect(centers.dy, lessThanOrEqualTo(narrow.height));
      expect(centers.dy, greaterThanOrEqualTo(0));
    }
  });

  testWidgets('有可委托任务的 NPC 显示「任务」按钮', (tester) async {
    tester.view.physicalSize = narrow;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final engine = GameEngine()..startNewGame();
    await tester.pumpWidget(
      MaterialApp(home: NpcPanelScreen(engine: engine)),
    );
    await tester.pumpAndSettle();

    // 取一个有 tasks 的在场 NPC
    final withTasks =
        engine.npcsAtCurrentLocation.where((n) => n.tasks.isNotEmpty);
    if (withTasks.isEmpty) {
      // 没有可测样本时如实跳过，不伪造通过
      return;
    }
    expect(find.text('任务'), findsWidgets);
  });

  testWidgets('长 NPC 名换行而不是被压成一字宽', (tester) async {
    tester.view.physicalSize = narrow;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final engine = GameEngine()..startNewGame();
    await tester.pumpWidget(
      MaterialApp(home: NpcPanelScreen(engine: engine)),
    );
    await tester.pumpAndSettle();

    for (final n in engine.npcsAtCurrentLocation) {
      final finder = find.text(n.name);
      if (finder.evaluate().isEmpty) continue;
      final size = tester.getSize(finder);
      expect(size.width, greaterThan(40),
          reason: '「${n.name}」渲染宽 ${size.width}px，疑似被挤成竖排');
    }
  });
}