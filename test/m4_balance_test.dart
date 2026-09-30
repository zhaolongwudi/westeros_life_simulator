/// Batch 10-30 测试：M4a 数值配置集中（lib/data/balance_data.dart）。
///
/// 覆盖：
/// 1. 头衔阶梯：10 个身份全档位 + 边界（门槛-1 / 门槛 / 门槛+1 / 登顶）
/// 2. 晋升判定与「距下次晋升」互不矛盾（消除 checkTitlePromotion / formatTitlePanel 双真相）
/// 3. 阶梯表结构契约：升序、无重复、覆盖全部身份
/// 4. 数值转发一致性：mixin 的 static const == BalanceData 对应项
/// 5. 月度生存结算按配置生效
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/balance_data.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/models/player.dart';
import 'package:westeros_life_simulator/mixins/mixin_life.dart';
import 'package:westeros_life_simulator/mixins/mixin_marriage.dart';
import 'package:westeros_life_simulator/mixins/mixin_play.dart';

void main() {
  group('M4a 头衔阶梯配置', () {
    test('10 个身份全部有阶梯配置', () {
      expect(BalanceData.titleLadders.length, PlayerIdentity.values.length);
      for (final id in PlayerIdentity.values) {
        expect(
          BalanceData.ladderOf(id.name),
          isNotEmpty,
          reason: '身份 ${id.name} 未配置头衔阶梯',
        );
      }
    });

    test('每条阶梯按声望严格升序且门槛不重复', () {
      for (final entry in BalanceData.titleLadders.entries) {
        final reps = entry.value.map((t) => t.reputation).toList();
        for (var i = 1; i < reps.length; i++) {
          expect(
            reps[i] > reps[i - 1],
            true,
            reason: '${entry.key} 第 $i 档门槛未升序：$reps',
          );
        }
      }
    });

    test('全档位逐条断言（阶梯数据 + 晋升判定一致）', () {
      for (final entry in BalanceData.titleLadders.entries) {
        for (final tier in entry.value) {
          // 刚好达标 → 晋升为该档
          expect(
            BalanceData.promotedTitle(entry.key, tier.reputation),
            tier.title,
            reason: '${entry.key} 在声望 ${tier.reputation} 应晋升为「${tier.title}」',
          );
          // 差 1 点 → 停在前一档（最低档时为空串）
          final lower = BalanceData.ladderOf(entry.key)
              .where((t) => t.reputation < tier.reputation)
              .toList();
          final expected = lower.isEmpty ? '' : lower.last.title;
          expect(
            BalanceData.promotedTitle(entry.key, tier.reputation - 1),
            expected,
            reason: '${entry.key} 差 1 点（${tier.reputation - 1}）应仍为「$expected」',
          );
          // 下一档门槛 = 严格大于当前声望的第一个门槛
          final next = BalanceData.nextTierReputation(entry.key, tier.reputation);
          final expectNext = entry.value
              .where((t) => t.reputation > tier.reputation)
              .toList();
          expect(
            next,
            expectNext.isEmpty ? 0 : expectNext.first.reputation,
            reason: '${entry.key} 升到「${tier.title}」后的下一档门槛不对',
          );
        }
      }
    });

    test('登顶后无下一档（返回 0），面板显示巅峰', () {
      for (final entry in BalanceData.titleLadders.entries) {
        expect(BalanceData.nextTierReputation(entry.key, 100), 0);
        expect(
          BalanceData.promotedTitle(entry.key, 100),
          entry.value.last.title,
        );
      }
    });

    test('未知身份返回空阶梯（不抛异常）', () {
      expect(BalanceData.ladderOf('nobody'), isEmpty);
      expect(BalanceData.promotedTitle('nobody', 100), '');
      expect(BalanceData.nextTierReputation('nobody', 100), 0);
    });
  });

  group('M4a 引擎侧头衔走同一份阶梯', () {
    test('10 个身份逐个：引擎晋升结果 == 配置判定', () {
      for (final id in PlayerIdentity.values) {
        final ladder = BalanceData.ladderOf(id.name);
        for (final tier in ladder) {
          final e = GameEngine()..startNewGame();
          e.updatePlayer(
            Player.defaultPlayer().copyWith(
              identity: id,
              reputation: tier.reputation,
              title: '',
            ),
          );
          expect(
            e.checkTitlePromotion(),
            tier.title,
            reason: '${id.name} 声望 ${tier.reputation} 晋升结果与配置不符',
          );
          expect(e.player.title, tier.title);
        }
      }
    });

    test('面板「距下次晋升」与配置门槛一致（身份 × 声望）', () {
      for (final id in PlayerIdentity.values) {
        for (final rep in [0, 29, 30, 39, 40, 49, 50, 55, 70, 80, 100]) {
          final e = GameEngine()..startNewGame();
          e.updatePlayer(
            Player.defaultPlayer().copyWith(identity: id, reputation: rep),
          );
          final panel = e.formatTitlePanel();
          final nextRep = BalanceData.nextTierReputation(id.name, rep);
          if (nextRep > 0) {
            expect(
              panel,
              contains('${nextRep - rep} 点声望（$nextRep）'),
              reason: '${id.name} 声望 $rep 的面板门槛与配置不符',
            );
          } else {
            expect(panel, contains('巅峰'), reason: '${id.name} 声望 $rep 应已登顶');
          }
        }
      }
    });

    test('声望不足不降级（老行为保留）', () {
      final e = GameEngine()..startNewGame();
      e.updatePlayer(
        Player.defaultPlayer().copyWith(
          identity: PlayerIdentity.soldier,
          reputation: 60,
        ),
      );
      expect(e.checkTitlePromotion(), '骑士');
      e.updatePlayer(e.player.copyWith(reputation: 20));
      expect(e.checkTitlePromotion(), '');
      expect(e.player.title, '骑士');
    });
  });

  group('M4a 数值转发一致性', () {
    test('mixin 常量 == BalanceData 对应项', () {
      expect(GameLifeMixin.kLowEnergyPenalty, BalanceData.lowEnergyPenalty);
      expect(
        GameLifeMixin.kHungerDecayPerMonth,
        BalanceData.hungerDecayPerMonth,
      );
      expect(
        GameLifeMixin.kStarvationThreshold,
        BalanceData.starvationThreshold,
      );
      expect(
        GameLifeMixin.kRestEnergyRecovery,
        BalanceData.restEnergyRecovery,
      );
      expect(GameLifeMixin.kHealthRegen, BalanceData.healthRegen);
      expect(GamePlayMixin.kDailyLimits, BalanceData.dailyLimits);
      expect(GameMarriageMixin.kDivorceCost, BalanceData.divorceCost);
      expect(
        GameMarriageMixin.kSpouseChatDailyLimit,
        BalanceData.spouseChatDailyLimit,
      );
      expect(GameMarriageMixin.kSpouseDailyLimit, BalanceData.spouseDailyLimit);
    });

    test('感情等级标签按配置判定', () {
      final e = GameEngine()..startNewGame();
      for (final pair in <int, String>{
        0: '疏离',
        BalanceData.spouseHarmoniousAffection - 1: '疏离',
        BalanceData.spouseHarmoniousAffection: '和睦',
        BalanceData.spouseDevotedAffection: '恩爱',
        100: '恩爱',
      }.entries) {
        expect(e.affectionLabel(pair.key), pair.value);
      }
    });
  });

  group('M4a 月度生存结算按配置生效', () {
    test('饱食按配置衰减量下降', () {
      final e = GameEngine()..startNewGame();
      e.updatePlayer(e.player.copyWith(hunger: 90, energy: 100, health: 100));
      final before = e.player.hunger;
      e.applyMonthlyLife(seed: 7);
      // 非冬季：只掉 hungerDecayPerMonth（睡眠恢复只加精力，不动饱食）
      expect(before - e.player.hunger, BalanceData.hungerDecayPerMonth);
    });

    test('饥饿状态按配置持续掉健康', () {
      final e = GameEngine()..startNewGame();
      e.updatePlayer(
        e.player.copyWith(
          hunger: BalanceData.starvationThreshold - 1,
          energy: 100,
          health: 100,
        ),
      );
      final text = e.applyMonthlyLife(seed: 11);
      expect(text, contains('长期饥饿'));
      // -8 饥饿 + sleepEnergyBase 可能补回 15~29，但健康净变化不为正
      expect(e.player.health, lessThan(100));
    });

    test('疲惫阈值按配置判定', () {
      final e = GameEngine()..startNewGame();
      e.updatePlayer(
        e.player.copyWith(energy: BalanceData.exhaustedEnergy - 1),
      );
      expect(e.isExhausted, true);
      e.updatePlayer(e.player.copyWith(energy: BalanceData.exhaustedEnergy));
      expect(e.isExhausted, false);
    });

    test('休息按配置扣费与回精力', () {
      final e = GameEngine()..startNewGame();
      e.updatePlayer(
        e.player.copyWith(
          gold: BalanceData.restInnCost + 10,
          energy: 30,
          hunger: 50,
        ),
      );
      final goldBefore = e.player.gold;
      final text = e.rest();
      expect(goldBefore - e.player.gold, BalanceData.restInnCost);
      expect(
        e.player.energy,
        30 + BalanceData.restEnergyRecovery,
      );
      expect(text, contains('${BalanceData.restInnCost} 金币'));
      expect(text, contains('${BalanceData.restEnergyRecovery}'));
    });

    test('金币不足无法休息（按配置阈值）', () {
      final e = GameEngine()..startNewGame();
      e.updatePlayer(e.player.copyWith(gold: BalanceData.restInnCost - 1));
      expect(e.rest(), contains('太穷了'));
    });
  });
}
