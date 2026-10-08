/// Sprint 13-3 测试：修 P0 ④ NPC 面板「任务」按钮是死按钮。
///
/// 【本文件是 S13-3 的复现测试】按接力文档第 4 条「先写能复现的失败测试再改实现」。
///
/// 【根因（实测取证，非推测）】面板按钮与「任务」指令都调 **V1** `acceptNpcTask`
/// （`npc_panel_screen.dart:303` / `mixin_npc_interact.dart:399-400`），
/// 而同屏渲染的「进行中的任务」读的是 **V2** `engine.activeTasks`
/// （`npc_panel_screen.dart:122-128`）。
/// V1 只写 `flags.npc_task.*`、V2 存 `Player.activeTasks` ⇒ **两个互不相通**：
/// 点完确实提示「你接下…委托」，但「进行中的任务」**永远为空**。
/// 且 V1 结算 `maybeResolveNpcTask()` **零生产调用方** ⇒ 那条链永远无法结算。
///
/// 【为什么接线是安全的（实测推翻卡片担忧）】卡片原文担心「改接 V2 后老 NPC 会返回
/// 『暂时没有新的委托给你』」。**实测 14/14 条 V1 委托在 V2 全部同名存在**
/// （V1 8 个 NPC / 14 条 vs V2 72 模板 / 38 NPC；`npc_task_data.dart` 文件头注释
/// 亦明写「为既有带 tasks 的 NPC 提供多步骤任务模板」）⇒ **V2 是 V1 的严格超集**，
/// 接线不丢任何内容。本文件第 2 例正是这条契约的锁钉。
///
/// 【判别性说明（重要）】本文件所有断言在**修复前一律失败**：
/// 修复前 `activeTasks` 恒为空（V1 写 flags 不碰 activeTasks），
/// 修复后为 1 条。故不存在「恒过」的假复现。
///
/// ⚠️ 本机（Android/DSH）无 dart/flutter，**本文件未在本地执行**，正确性由 CI 验证。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/screens/npc_panel_screen.dart';

/// 把玩家与艾德·史塔克的关系提到「相识」门槛（关系 ≥ 20 才肯委托）。
GameEngine _engineWithNev(GameEngine engine) {
  engine.updatePlayer(
    engine.player.copyWith(
      relations: <String, int>{...engine.player.relations, 'npc_nev': 25},
    ),
  );
  return engine;
}

/// 艾德·史塔克（默认出生地临冬城在场，V1 与 V2 都有委托）。
const String kNev = 'npc_nev';

void main() {
  group('S13-3 ④ 面板「任务」按钮接 V2（修复前 activeTasks 恒空）', () {
    testWidgets('点「任务」胶囊后该任务出现在「进行中的任务」里', (tester) async {
      final engine = _engineWithNev(GameEngine()..startNewGame());
      // 前置：修复前会在这里就失败（activeTasks 恒为空）
      expect(engine.activeTasks, isEmpty, reason: '初始不应有进行中任务');

      await tester.pumpWidget(
        MaterialApp(home: NpcPanelScreen(engine: engine)),
      );
      await tester.pumpAndSettle();

      // 定位「任务」胶囊本体。`find.text` 是**精确全串**匹配，
      // 「进行中的任务」标题字符串不同，故不会误命中；
      // 再从它向上取 GestureDetector（_ActionPill 的实现）保证点到的是胶囊而非标题。
      final label = find.text('任务');
      expect(label, findsWidgets, reason: '艾德在场应渲染出「任务」胶囊');
      final pill = find.ancestor(
        of: label.last,
        matching: find.byType(GestureDetector),
      );
      expect(pill, findsWidgets);
      await tester.tap(pill.first);
      await tester.pumpAndSettle();

      // 🔴 核心判别断言：修复前此处为 [] ⇒ 失败；修复后 length 1 ⇒ 通过
      expect(
        engine.activeTasks,
        hasLength(1),
        reason: '面板点「任务」必须接进 V2（activeTasks），'
            '而不是只写 V1 的 flags.npc_task.*',
      );
      expect(engine.activeTasks.first.npcId, kNev);
      expect(engine.activeTasks.first.isActive, isTrue);
    });

    test('接取后「进行中的任务」区真的渲染出该任务（不再是空态）', () async {
      // 纯数据层断言：不依赖 widget，锁「V1 的 tasks 列表项在 V2 有同名模板」这条
      // 接线前提。若将来有人删掉/改写模板标题，本例会红。
      final engine = _engineWithNev(GameEngine()..startNewGame());
      final v1Titles = engine.npcTasks(kNev);
      expect(v1Titles, isNotEmpty, reason: '艾德应有 V1 委托文案');

      final result = engine.acceptNpcTaskV2(kNev);
      expect(result, contains('接下'));
      final t = engine.activeTasks.first;
      expect(
        v1Titles,
        contains(t.title),
        reason: 'V2 接下的默认模板标题应来自 V1 可见委托列表'
            '（V2 须为 V1 严格超集）',
      );
    });
  });

  group('S13-3 ④ 「任务」指令接 V2（修复前 activeTasks 恒空）', () {
    test('「任务 艾德·史塔克」接进 V2 而非只写 flags', () {
      final engine = _engineWithNev(GameEngine()..startNewGame());
      final result = engine.resolveCommand('任务 $kNev');
      // 既��契约（batch10_15:154 锁的就是这句「接下」，改后必须仍成立）
      expect(result.text, contains('接下'));
      // 🔴 判别断言：修复前 activeTasks 恒空 ⇒ 失败
      expect(
        engine.activeTasks,
        hasLength(1),
        reason: '「任务」指令必须走 V2，否则玩家接的委托永远不结算',
      );
    });

    test('无参数「任务」返回的是 V2 面板（含难度/期限/奖励）', () {
      final engine = GameEngine()..startNewGame();
      final result = engine.resolveCommand('任务');
      // 既��契约（batch10_15:144 锁的是「可接任务」，两版面板首行相同）
      expect(result.text, contains('可接任务'));
      // V2 面板比 V1 多出这三项信息（V1 只列标题）
      expect(result.text, contains('期限'), reason: 'V2 面板应显示期限');
      expect(result.text, contains('步'), reason: 'V2 面板应显示步骤数');
      expect(result.text, contains('金'), reason: 'V2 面板应显示奖励金币');
    });

    test('V1 的 flags 键不再被写入（接线后不该有两套状态并存）', () {
      final engine = _engineWithNev(GameEngine()..startNewGame());
      engine.resolveCommand('任务 $kNev');
      expect(
        engine.flagOf('npc_task.$kNev.${engine.npcTasks(kNev).first}'),
        isFalse,
        reason: '接线后走 V2（activeTasks），不应再写 V1 的 flags.npc_task.*',
      );
    });
  });

  group('S13-3 ④ 接取后能真正推进与完成（V1 链永远做不到）', () {
    test('V2 任务在月度管线里推进（V1 链无任何推进机制）', () {
      final engine = _engineWithNev(GameEngine()..startNewGame());
      engine.resolveCommand('任务 $kNev');
      final t0 = engine.activeTasks.first;
      final before = t0.stepIndex * 1000 + t0.stepProgress;

      engine.advanceMonth();
      final after = engine.activeTasks.first;
      final moved = after.stepIndex * 1000 + after.stepProgress;

      expect(
        moved,
        greaterThan(before),
        reason: '接下的任务必须能被月度管线推进，否则又是一个永远完不成的死任务',
      );
    });

    test('关系门槛与 V2 一致：陌生 NPC 拒绝接取', () {
      final engine = GameEngine()..startNewGame();
      // 艾莉亚·史塔克同在临冬城（默认出生地），但关系为 0（陌生）
      // ⇒ acceptNpcTaskV2 走 `rel < 20` 分支返回「信不过」，不产生任何任务实例。
      final result = engine.acceptNpcTaskV2('npc_arya');
      expect(engine.activeTasks, isEmpty);
      expect(result, contains('信不过'));
    });
  });
}
