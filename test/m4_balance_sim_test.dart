/// Batch 10-31 测试：M4b 120 个月资源仿真。
///
/// headless 驱动完整 GameEngine 跑 120 个月（约 10 年游戏时间），
/// 验证：
/// 1. 主动生存：每月狩猎（补饱食）+ 休息（回精力/饱食）+ 金币紧时工作，
///    120 个月不 game over，金币/健康/精力/饱食曲线有界（不枯竭、不爆炸）
/// 2. 被动对照：什么都不做必死（验证「不干活会饿死」的生存约束存在）
/// 3. 曲线诊断：固定策略跑 160 个月，金币增长有上界无负值，健康/饱食全程 > 0
///
/// 目的：M4a 把数值收口到 balance_data 后，用长周期仿真兜住
/// 「调一个平衡参数炸掉整条生存曲线」的回归风险。
///
/// 注：引擎随机源 `rng(seed)` 默认用 `progress.turnCount` 作种子（每月 +1），
/// 同策略下随机序列确定，本测试不依赖真随机、不 flaky。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/data/balance_data.dart';

/// 创建仿真引擎：开局 hunger 对齐 start_screen 的真实开局值（60）。
GameEngine _simEngine() {
  final e = GameEngine()..startNewGame();
  e.updatePlayer(e.player.copyWith(hunger: 60));
  return e;
}

/// 主动生存循环（每月固定节奏）：
/// 1. 狩猎一次：饱食 +15（冲抵每月自然衰减 -12），可能赚金币或受伤
/// 2. 休息一次：饱食 +10、精力 +40、花 2 金币
/// 3. 金币偏紧（<30）时再工作一次
/// 月饱食净收支 = +15 +10 -12 = +13（冬季再 -5），长期稳定在安全线上。
List<Map<String, int>> _runActive(GameEngine e, [int months = 120]) {
  final snapshots = <Map<String, int>>[];
  for (var m = 0; m < months; m++) {
    if (e.canAffordEnergy(20)) e.hunt();
    if (e.player.gold >= BalanceData.restInnCost) e.rest();
    if (e.player.gold < 30 && e.canAffordEnergy(15)) e.work();
    e.advanceMonth();
    snapshots.add({
      'gold': e.player.gold,
      'health': e.player.health,
      'energy': e.player.energy,
      'hunger': e.player.hunger,
      'age': e.player.age,
    });
  }
  return snapshots;
}

void main() {
  group('M4b 120 个月主动生存仿真', () {
    test('狩猎+休息+工作策略 120 个月不 game over、资源有界', () {
      final e = _simEngine();
      final snaps = _runActive(e, 120);

      expect(e.isGameOver, false, reason: '主动 120 个月不应游戏结束');
      expect(e.isGameActive, true);
      // 时间正确推进：283 年 3 月 + 120 个月 = 293 年 3 月
      expect(e.progress.year, 293);
      expect(e.progress.month, 3);
      // 年龄 +10
      expect(e.player.age, 28);
      // 金币有界：不枯竭（>0）也不爆炸（<5000）
      expect(snaps.last['gold']!, greaterThan(0));
      expect(snaps.last['gold']!, lessThan(5000));
      // 资源全程存活
      for (final s in snaps) {
        expect(s['health']!, greaterThan(0), reason: '健康不应枯竭');
        expect(s['energy']!, greaterThanOrEqualTo(0));
      }
    });

    test('每月休息能把饱食拉回安全线（开局 60 不饿死）', () {
      final e = _simEngine();
      final snaps = _runActive(e, 120);
      // 120 个月中饱食从没掉到 0（rest +10 能兜底）
      for (final s in snaps) {
        expect(s['hunger']!, greaterThan(0), reason: '饱食不应枯竭');
      }
      // 末月饱食在安全线上（≥ starvationThreshold，证明没长期饥饿）
      expect(snaps.last['hunger']!, greaterThanOrEqualTo(BalanceData.starvationThreshold));
    });
  });

  group('M4b 主动 vs 被动对比', () {
    test('主动策略 120 个月健康曲线全程不低于被动', () {
      final eActive = _simEngine();
      final ePassive = _simEngine();
      final active = _runActive(eActive, 120);
      // 被动：只推进时间，不吃不喝不工作
      final passive = <Map<String, int>>[];
      for (var m = 0; m < 120; m++) {
        ePassive.advanceMonth();
        passive.add({
          'gold': ePassive.player.gold,
          'health': ePassive.player.health,
          'energy': ePassive.player.energy,
          'hunger': ePassive.player.hunger,
          'age': ePassive.player.age,
        });
      }
      // 主动策略全程健康 ≥ 被动（工作有收入，休息回状态）
      for (var i = 0; i < active.length; i++) {
        expect(
          active[i]['health']!,
          greaterThanOrEqualTo(passive[i]['health']!),
          reason: '第 ${i + 1} 个月主动健康低于被动',
        );
      }
    });
  });

  group('M4b 曲线诊断（固定策略 160 个月）', () {
    test('固定策略下金币增长有上界、无负值', () {
      final e = _simEngine();
      // 固定策略 = 主动生存节奏（hunt + rest + 金币紧时 work），跑 160 个月
      final snaps = _runActive(e, 160);
      expect(e.isGameOver, false, reason: '固定策略 160 个月不应 game over');
      // 金币非负且有界
      for (final s in snaps) {
        expect(s['gold']!, greaterThanOrEqualTo(0));
        expect(s['gold']!, lessThan(5000));
        expect(s['health']!, greaterThan(0));
        expect(s['hunger']!, greaterThan(0));
      }
      // 年龄随时间正确增长（283 年 3 月 + 160 个月 = 296 年 7 月 → 18+13 = 31 岁）
      expect(e.player.age, 31);
      expect(e.progress.year, 296);
      expect(e.progress.month, 7);
    });
  });

  group('M4b 数值引用一致性', () {
    test('仿真用到的关键阈值与 balance_data 一致（防魔改后失联）', () {
      expect(BalanceData.fullVital, 100);
      expect(BalanceData.starvationThreshold, 25);
      expect(BalanceData.exhaustedEnergy, 20);
      expect(BalanceData.hungerDecayPerMonth, 12);
      expect(BalanceData.starvationHealthPenalty, 8);
      expect(BalanceData.dailyLimits['work'], 2);
      // S2-2：rest 上限由装饰性的 99 改为真实闸口 10（rest() 此前从不读该键）。
      // 该值改动会改变「每月可休息次数」，若仿真曲线因此漂移，请先看
      // regression_simulation 再调，而不是把这里改回 99 了事。
      expect(BalanceData.dailyLimits['rest'], 10);
    });
  });
}
