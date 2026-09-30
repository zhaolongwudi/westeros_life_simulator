/// M6b 跨批次回归套件 · 策略仿真（regression_simulation_test.dart）。
///
/// 目的：把 M4b 的 120 个月仿真扩展成**策略对照回归**，兜住「调平衡参数
/// 改变生存曲线」的跨批次风险：
/// 1. 三策略对照：主动（hunt+rest+work）存活 / 半主动（只 rest+work 不觅食）
///    饿死 / 被动纯挂机必死 —— 验证「必须主动觅食」这条生存约束始终存在；
/// 2. 濒危开局救回：饥饿开局 / 疲惫开局，主动策略 12 个月内救回安全线；
/// 3. 冬夏压力对比：同一主动策略下，冬季 3 个月饱食消耗快于夏季；
/// 4. 极长曲线：主动策略 200 个月金币始终非负有界。
///
/// 与 m4_balance_sim_test 的关系：m4 覆盖「主动 vs 被动 + 固定策略 160 月」；
/// 本文件补充「半主动必死」「濒危开局救回」「冬夏对比」三个新角度。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/balance_data.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/models/player.dart';
import 'package:westeros_life_simulator/providers/game_state_provider.dart';

/// 开局对齐 start_screen 真实开局值（hunger 60）。
GameEngine _simEngine() {
  final e = GameEngine()..startNewGame();
  e.updatePlayer(e.player.copyWith(hunger: 60));
  return e;
}

/// 主动策略（每月：能狩猎就狩猎 + 能休息就休息 + 金币紧时工作）。
List<Map<String, int>> _runActive(GameEngine e, [int months = 120]) {
  final snaps = <Map<String, int>>[];
  for (var m = 0; m < months; m++) {
    if (e.canAffordEnergy(20)) e.hunt();
    if (e.player.gold >= BalanceData.restInnCost) e.rest();
    if (e.player.gold < 30 && e.canAffordEnergy(15)) e.work();
    e.advanceMonth();
    snaps.add(_snap(e));
  }
  return snaps;
}

/// 半主动策略（只休息 + 金币紧时工作，不觅食）。
/// rest 补饱食 +10 / 自然衰减 -12 → 月净 -2，长期必然饥饿死亡。
List<Map<String, int>> _runSemiActive(GameEngine e, [int months = 120]) {
  final snaps = <Map<String, int>>[];
  for (var m = 0; m < months; m++) {
    if (e.player.gold >= BalanceData.restInnCost) e.rest();
    if (e.player.gold < 30 && e.canAffordEnergy(15)) e.work();
    e.advanceMonth();
    snaps.add(_snap(e));
  }
  return snaps;
}

Map<String, int> _snap(GameEngine e) => <String, int>{
      'gold': e.player.gold,
      'health': e.player.health,
      'energy': e.player.energy,
      'hunger': e.player.hunger,
      'age': e.player.age,
    };

void main() {
  group('M6b 三策略对照（120 个月）', () {
    test('主动（hunt+rest+work）存活：不 game over、资源有界', () {
      final e = _simEngine();
      final snaps = _runActive(e, 120);
      expect(e.isGameOver, false, reason: '主动策略 120 个月不应死亡');
      expect(snaps.last['gold']!, greaterThan(0));
      expect(snaps.last['gold']!, lessThan(5000));
      for (final s in snaps) {
        expect(s['health']!, greaterThan(0), reason: '健康不应枯竭');
        expect(s['hunger']!, greaterThan(0), reason: '饱食不应枯竭');
        expect(s['gold']!, greaterThanOrEqualTo(0));
      }
    });

    test('半主动（只 rest+work 不 hunt）饿死：120 个月内 game over', () {
      final e = _simEngine();
      final snaps = _runSemiActive(e, 120);
      expect(e.isGameOver, true,
          reason: '只休息不觅食，饱食月净 -2，长期必然饿死');
      // 死亡前健康确实一路下滑（验证真的掉到 0 触发死亡）
      final healths = snaps.map((s) => s['health']!).toList();
      expect(healths.last, lessThanOrEqualTo(0));
    });

    test('被动纯挂机必死：健康迅速枯竭', () {
      final e = _simEngine();
      for (var m = 0; m < 120; m++) {
        e.advanceMonth();
      }
      expect(e.isGameOver, true);
      expect(e.player.health, lessThanOrEqualTo(0));
    });

    test('主动策略健康曲线末值显著高于半主动', () {
      final active = _runActive(_simEngine(), 120);
      final semi = _runSemiActive(_simEngine(), 120);
      expect(active.last['health']!, greaterThan(semi.last['health']!),
          reason: '主动觅食保住健康，半主动饿死');
    });
  });

  group('M6b 濒危开局救回（12 个月内）', () {
    test('饥饿开局（hunger 30）主动策略 12 个月后饱食回安全线', () {
      final e = _simEngine();
      e.updatePlayer(e.player.copyWith(hunger: 30));
      _runActive(e, 12);
      expect(e.isGameOver, false);
      expect(e.player.hunger,
          greaterThanOrEqualTo(BalanceData.starvationThreshold),
          reason: 'hunt(+15)+rest(+10) 每月净增收应把饱食拉回 25 以上');
    });

    test('疲惫开局（energy 5）主动策略先休息后活动，12 个月后精力充足', () {
      final e = _simEngine();
      // 开局精力极低：活动成功率减半，先休息恢复
      e.updatePlayer(e.player.copyWith(energy: 5));
      // 主动策略：休息回精力，hunt 需精力 20（不足时跳过），不崩即可
      _runActive(e, 12);
      expect(e.isGameOver, false);
      expect(e.player.energy,
          greaterThanOrEqualTo(BalanceData.exhaustedEnergy),
          reason: '12 个月后精力应恢复超过疲惫线 20');
    });
  });

  group('M6b 冬夏资源压力', () {
    test('同策略下：冬季 3 个月饱食消耗快于夏季（冬季末饱食更低）', () {
      // 直接用 GameProgress 构造夏季/冬季开局，不经过「推进到对应月份」，
      // 消除路径长度不一致带来的额外饱食差；rest-only 确定性无随机。
      //
      // 夏季开局：6 月（summer），rest +10 / 衰减 -12 → 月净 -2。
      final summer = GameEngine(
        progress: const GameProgress(
            year: 283, month: 6, season: 'summer', era: '征服纪元', turnCount: 0),
        player: Player.defaultPlayer().copyWith(hunger: 80),
        isGameActive: true,
      );
      var summerHunger = 0;
      for (var m = 0; m < 3; m++) {
        summer.rest();
        summer.advanceMonth();
        summerHunger = summer.player.hunger;
      }

      // 冬季开局：12 月（winter），额外 winterHungerExtra(-5)/月。
      final winter = GameEngine(
        progress: const GameProgress(
            year: 283, month: 12, season: 'winter', era: '征服纪元', turnCount: 0),
        player: Player.defaultPlayer().copyWith(hunger: 80),
        isGameActive: true,
      );
      var winterHunger = 0;
      for (var m = 0; m < 3; m++) {
        winter.rest();
        winter.advanceMonth();
        winterHunger = winter.player.hunger;
      }

      // 夏季末 ≈ 80 - 3×2 = 74；冬季末 ≈ 80 - 3×2 - 3×5 = 59。
      expect(winterHunger, lessThan(summerHunger),
          reason: '冬季末饱食应低于夏季末（winterHungerExtra 生效）');
      expect(summerHunger - winterHunger, lessThanOrEqualTo(15),
          reason: '3 个月冬季额外消耗最多 3 × winterHungerExtra = 15');
    });
  });

  group('M6b 极长曲线（200 个月）', () {
    test('主动策略 200 个月：金币始终非负有界，健康/饱食不枯竭', () {
      final e = _simEngine();
      final snaps = _runActive(e, 200);
      expect(e.isGameOver, false, reason: '主动策略 200 个月仍应存活');
      for (final s in snaps) {
        expect(s['gold']!, greaterThanOrEqualTo(0));
        expect(s['gold']!, lessThan(10000));
        expect(s['health']!, greaterThan(0));
        expect(s['hunger']!, greaterThan(0));
      }
      // 时间正确推进：283 年 3 月 + 200 月 = 299 年 11 月，年龄 18+16=34
      expect(e.progress.year, 299);
      expect(e.progress.month, 11);
      expect(e.player.age, 34);
    });
  });
}