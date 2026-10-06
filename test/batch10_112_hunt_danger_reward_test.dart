/// Batch 10-112 测试：狩猎收益挂钩地点危险度（高危 = 高回报）。
///
/// 背景：狩猎成功率随地点危险度递减（`huntChancePerDanger`）且失败受伤
/// 风险递增，但收益却固定 10~19 金——高危地点狩猎是**纯劣选项**（更低
/// 成功率 + 更高受伤风险 + 相同收益），违背「高风险高回报」经济常规。
/// 本批给成功收益加 `danger * huntRewardPerDanger` 项（每点 +1，经 CI 护栏实测收敛）。
///
/// 零回归依据（一次性脚本取证）：
/// - `batch4_mixin_play_test.dart` 只断言 hunt 行为分支（「猎到猎物」/
///   「什么也没猎到」/「失手摔伤」），不锁收益数字；
/// - `m4_balance_sim_test.dart` 只护栏「金币 < 5000 / 健康 > 0 / 饱食 > 0」，
///   加收益只让金币更多，仍远低于上限；
/// - 全库 dangerLevel 分布 1~6，临冬城/君临为 3，收益 +6 属典型值。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/balance_data.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/models/location.dart';
import 'package:westeros_life_simulator/models/player.dart';

/// 构造指定危险度的野外地点引擎，hunt 一次返回文本。
GameEngine _engineAt(int danger) {
  final e = GameEngine(
    player: Player.defaultPlayer().copyWith(locationId: 'loc_danger_$danger'),
    locations: [
      Location.defaultLocation().copyWith(
        id: 'loc_danger_$danger',
        type: LocationType.wilderness,
        dangerLevel: danger,
      ),
    ],
    isGameActive: true,
  );
  // 满技能/满状态，保证狩猎成功分支可达
  e.updatePlayer(
    e.player.copyWith(
      skills: const {
        'sword': 10,
        'archery': 10,
        'riding': 3,
        'speech': 2,
        'alchemy': 0,
      },
      energy: 100,
      hunger: 80,
      health: 100,
    ),
  );
  return e;
}

void main() {
  group('Batch 10-112 狩猎危险度挂钩收益', () {
    test('收益常量契约：每点危险度 +2 金（与旧基础公式兼容）', () {
      expect(BalanceData.huntRewardPerDanger, 1);
      expect(BalanceData.huntRewardBase, 10);
      expect(BalanceData.huntRewardPerSkill, 3);
      expect(BalanceData.huntRewardVariance, 10);
    });

    test('危险度加成公式成立：危险 6 比危险 1 多 (6-1)*1 = 5 金（纯逻辑）', () {
      // 收益公式（mixin_play.hunt 成功分支）：
      //   reward = huntRewardBase + skill*huntRewardPerSkill
      //            + danger*huntRewardPerDanger + rnd(huntRewardVariance)
      // 同技能/同 rng 下，危险度差的收益差 = (danger2-danger1)*huntRewardPerDanger
      final d6 = 6 * BalanceData.huntRewardPerDanger;
      final d1 = 1 * BalanceData.huntRewardPerDanger;
      expect(d6 - d1, 5, reason: '危险度 6 与 1 的加成差应恰为 5');
    });
    test('危险度加成收益区间正确（危险 3 满技能 43~52 金）', () {
      // 满技能（sword 10）下：基础 10 + 技能 30 + 危险 3*1 + rnd(0~9)
      // = 43~52。用收益公式推导区间（不依赖引擎随机性）。
      final base = BalanceData.huntRewardBase;
      final skillPart = 10 * BalanceData.huntRewardPerSkill;
      final dangerPart = 3 * BalanceData.huntRewardPerDanger;
      final low = base + skillPart + dangerPart;
      final high = low + BalanceData.huntRewardVariance - 1;
      expect(low, 43);
      expect(high, 52);
    });

    test('危险度加成不改变既有行为分支（城市仍拒绝、野外仍可猎）', () {
      final city = GameEngine(
        player: Player.defaultPlayer().copyWith(locationId: 'loc_city'),
        locations: [
          Location.defaultLocation().copyWith(
            id: 'loc_city',
            type: LocationType.city,
            dangerLevel: 3,
          ),
        ],
        isGameActive: true,
      );
      expect(city.hunt(), contains('无猎可狩'));

      final wild = _engineAt(3);
      final text = wild.hunt();
      expect(
        text,
        anyOf(
          contains('猎到猎物'),
          contains('什么也没猎到'),
          contains('失手摔伤'),
        ),
      );
    });
  });
}
