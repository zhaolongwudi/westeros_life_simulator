/// Sprint 13-2 测试：修 P0 ①「探索」一次推进两步任务。
///
/// 【本文件是 S13-2 的复现测试】按接力文档第 4 条「先写能复现的失败测试再改实现」。
///
/// 【根因（实测取证，非推测）】一次「探索」把任务推了 **2 步**：
/// 1. `explore()` 内部自己调了一次 `advanceNpcTasks()`（`mixin_adventure.dart:106`）；
/// 2. 「探索」指令声明 `consumedTurn: true`（`mixin_adventure.dart:249-251`），
///    调度方（`game_screen.dart:184`）据此**再调** `advanceMonth()`；
/// 3. `advanceMonth()` 跑月度管线，管线 `task_advance` 钩子
///    （`mixin_npc_task.dart:451-463`，`beforeAdvance` order 8）**又调一次**。
/// ⇒ 合计 2 步。`NpcTaskStep.turnsRequired` 的注释明写「探索/过月各计 1 次」
/// （`models/npc_task.dart:34`），故 **1 次探索必须恰好 = 1 步**。
///
/// 后果：`task_nev_escort` 3 步需 1+2+2=**5** 次推进，修复前 3 次就完成；
/// 72 个任务模板的 `totalTurns` **全部折半**。
///
/// 【断言只锁任务进度，不锁金币/精力】`explore()` 与月度结算都会随机加减金币、
/// 精力、饱食（`rng(seed)` 按 `progress.turnCount` 播种），锁具体金币数会 flaky；
/// 本文件只断言**任务推进次数**这一契约。
///
/// ⚠️ 本机（Android/DSH）无 dart/flutter，**本文件未在本地执行**，正确性由 CI 验证。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/npc_task_data.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/models/npc_task.dart';

/// 接下艾德·史塔克的第一个委托（临冬城默认出生点，关系 25 已达相识门槛）。
NpcTaskProgress _acceptNevTask(GameEngine engine) {
  engine.updatePlayer(
    engine.player.copyWith(
      relations: const <String, int>{'npc_nev': 25},
    ),
  );
  expect(engine.acceptNpcTaskV2('npc_nev'), contains('接下'));
  expect(engine.activeTasks, hasLength(1));
  return engine.activeTasks.first;
}

/// 复刻 `game_screen.dart:179-186` 的真实调度：跑指令，消耗回合则过月。
void _exploreAndAdvanceMonth(GameEngine engine) {
  final result = engine.resolveCommand('探索');
  expect(result.needsTimeAdvance, isTrue);
  engine.advanceMonth();
}

void main() {
  group('S13-2 ① 单次「探索」只推进 1 步', () {
    test('explore() 自身不再推进任务（直接调用入口）', () {
      final engine = GameEngine()..startNewGame();
      _acceptNevTask(engine);
      engine.explore();
      // explore() 只管探索收益；任务推进统一交给月度管线
      expect(engine.activeTasks.first.stepIndex, 0);
      expect(engine.activeTasks.first.stepProgress, 0);
    });

    test('完整调度链（探索 + 调度方过月）合计只推 1 步', () {
      final engine = GameEngine()..startNewGame();
      _acceptNevTask(engine);

      _exploreAndAdvanceMonth(engine);

      // 第 1 步 turnsRequired=1 ⇒ 1 次推进后应恰好进入第 2 步、进度归零
      // 修复前是 explore 推 1 步 + 管线再推 1 步 ⇒ 停在第 2 步且 stepProgress=1
      final after = engine.activeTasks.first;
      expect(after.stepIndex, 1);
      expect(after.stepProgress, 0);
    });

    test('第 2 步需 2 次：两次完整调度走完第 2 步并进入第 3 步', () {
      final engine = GameEngine()..startNewGame();
      _acceptNevTask(engine);

      // 第 1 步（1 次）→ 进入第 2 步（turnsRequired=2）
      _exploreAndAdvanceMonth(engine);
      expect(engine.activeTasks.first.stepIndex, 1);
      expect(engine.activeTasks.first.stepProgress, 0);

      // 第 2 步第 1 次推进
      _exploreAndAdvanceMonth(engine);
      expect(engine.activeTasks.first.stepIndex, 1);
      expect(engine.activeTasks.first.stepProgress, 1);

      // 第 2 步第 2 次推进 ⇒ 进入第 3 步
      _exploreAndAdvanceMonth(engine);
      expect(engine.activeTasks.first.stepIndex, 2);
      expect(engine.activeTasks.first.stepProgress, 0);
    });

    test('3 次探索后任务仍未完成（修复前 3 次即完成 = 折半的直接证据）', () {
      final engine = GameEngine()..startNewGame();
      final task = _acceptNevTask(engine);
      final template = npcTaskTemplateById(task.taskId);
      expect(template!.totalTurns, 5); // 1+2+2

      // 5 步的任务走 3 次只该推进到第 3 步开头，绝不该完成。
      // 修复前每次探索推 2 步 ⇒ 第 3 次探索时步进已越过全部步骤并结算完成。
      for (var i = 0; i < 3; i++) {
        _exploreAndAdvanceMonth(engine);
      }

      final after = engine.activeTasks.first;
      expect(after.completed, isFalse, reason: '3 次推进不可能走完 5 步');
      expect(after.stepIndex, 2);
      expect(after.stepProgress, 0);
    });

    test('恰好 5 次探索走完全部 5 步（totalTurns 恢复为模板值）', () {
      final engine = GameEngine()..startNewGame();
      final task = _acceptNevTask(engine);
      final template = npcTaskTemplateById(task.taskId);
      final totalTurns = template!.totalTurns; // 5

      for (var i = 0; i < totalTurns; i++) {
        _exploreAndAdvanceMonth(engine);
      }

      final after = engine.activeTasks.first;
      expect(after.completed, isTrue);
      expect(after.stepIndex, template.steps.length);
    });

    test('第 6 次探索不会把已完成任务再往前推（已完结实例保持 completed）', () {
      final engine = GameEngine()..startNewGame();
      final task = _acceptNevTask(engine);
      final template = npcTaskTemplateById(task.taskId);
      final totalTurns = template!.totalTurns;

      for (var i = 0; i < totalTurns; i++) {
        _exploreAndAdvanceMonth(engine);
      }
      expect(engine.activeTasks.first.completed, isTrue);

      // 再多按 1 次：已完结任务不应再推进（advanceNpcTasks 遇 !isActive 直接跳过）
      _exploreAndAdvanceMonth(engine);
      final after = engine.activeTasks.first;
      expect(after.completed, isTrue);
      expect(after.stepIndex, template.steps.length); // 停在最后一步，不再 +1
    });
  });
}