/// Batch 10-115/116 测试：商队护送 + 巡游/议价经济魔法数字收口到 balance_data。
///
/// 背景：M4a（10-30）「调平衡只改一个文件」承诺在 10-111/113/114 兑现到
/// 日常经济/NPC 交互/冒险链，但 mixin_life 的贸易深化（商队护送 convoy /
/// 地区特产巡游 tradeSpecialty / 商人议价 negotiate）仍散落 27 个魔法数字。
/// 本批全部收口为新常量（数值逐字不变，纯重构护栏）。
///
/// 零回归依据（一次性脚本取证）：
/// - `batch10_11_trade_deep_test` 对 convoy/tradeSpecialty/negotiate 只断言
///   行为分支（精力减少/文本非空/每日冷却/指令接线），不锁具体数值；
/// - `kNewDailyLimits`（2/1/1）无限值测试锁定；
/// - `batch4_mixin_play_test` 只断言行为分支。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/balance_data.dart';

void main() {
  group('Batch 10-115 商队护送经济常量契约', () {
    test('护送消耗/判定/报酬常量与旧实现一致', () {
      expect(BalanceData.convoyEnergyCost, 15);
      expect(BalanceData.convoyScorePowerMult, 2);
      expect(BalanceData.convoyScoreRidingMult, 2);
      expect(BalanceData.convoyMerchantBonus, 5);
      expect(BalanceData.convoyScoreVariance, 20);
      expect(BalanceData.convoyBaseFee, 30);
      expect(BalanceData.convoyFeePowerMult, 2);
      expect(BalanceData.convoyFeeVariance, 20);
      expect(BalanceData.convoySuccessThreshold, 40);
      expect(BalanceData.convoyPartialThreshold, 25);
      expect(BalanceData.convoyPartialRate, 0.6);
      expect(BalanceData.convoyFailRate, 0.3);
      expect(BalanceData.convoyInjuryHealth, 10);
      expect(BalanceData.convoyReputationGain, 3);
    });

    test('护送档位单调：成功阈值 > 部分阈值，比例 部分 > 失败', () {
      expect(BalanceData.convoySuccessThreshold,
          greaterThan(BalanceData.convoyPartialThreshold));
      expect(BalanceData.convoyPartialRate,
          greaterThan(BalanceData.convoyFailRate));
    });

    test('护送判定公式区间纯逻辑推导（score = power*2 + riding*2 + 商人5 + rnd(20)）', () {
      // 与实现逐字一致的推导：score ∈ [power*2 + riding*2 + 商人5, +19]
      int scoreMin(int power, int riding, bool merchant) =>
          power * BalanceData.convoyScorePowerMult +
          riding * BalanceData.convoyScoreRidingMult +
          (merchant ? BalanceData.convoyMerchantBonus : 0);
      int scoreMax(int power, int riding, bool merchant) =>
          scoreMin(power, riding, merchant) + BalanceData.convoyScoreVariance - 1;
      // 默认开局（sword 3 → power≈6 + 属性 +0，riding 0）非商人：下限 12
      expect(scoreMin(6, 0, false), 12);
      expect(scoreMax(6, 0, false), 31);
      // 商人 + 高战斗值：必达全额档
      expect(scoreMin(18, 2, true), 18 * 2 + 2 * 2 + 5);
      expect(scoreMin(18, 2, true), greaterThanOrEqualTo(BalanceData.convoySuccessThreshold));
    });

    test('护送报酬公式区间纯逻辑推导（fee = 30 + power*2 + rnd(20)）', () {
      int feeMin(int power) =>
          BalanceData.convoyBaseFee + power * BalanceData.convoyFeePowerMult;
      int feeMax(int power) => feeMin(power) + BalanceData.convoyFeeVariance - 1;
      expect(feeMin(6), 30 + 12);
      expect(feeMax(6), 30 + 12 + 19);
      // 战斗值越高报酬越高（区间整体右移）
      expect(feeMin(12), greaterThan(feeMin(6)));
      expect(feeMax(12), greaterThan(feeMax(6)));
    });

    test('所有 10-115 常量均为正数（防调平衡破坏护送经济）', () {
      expect(BalanceData.convoyEnergyCost, greaterThan(0));
      expect(BalanceData.convoyScorePowerMult, greaterThan(0));
      expect(BalanceData.convoyScoreRidingMult, greaterThan(0));
      expect(BalanceData.convoyMerchantBonus, greaterThan(0));
      expect(BalanceData.convoyScoreVariance, greaterThan(0));
      expect(BalanceData.convoyBaseFee, greaterThan(0));
      expect(BalanceData.convoyFeePowerMult, greaterThan(0));
      expect(BalanceData.convoyFeeVariance, greaterThan(0));
      expect(BalanceData.convoySuccessThreshold, greaterThan(0));
      expect(BalanceData.convoyPartialThreshold, greaterThan(0));
      expect(BalanceData.convoyInjuryHealth, greaterThan(0));
      expect(BalanceData.convoyReputationGain, greaterThan(0));
      expect(BalanceData.convoyPartialRate, greaterThan(0));
      expect(BalanceData.convoyPartialRate, lessThan(1));
      expect(BalanceData.convoyFailRate, greaterThan(0));
      expect(BalanceData.convoyFailRate, lessThan(1));
    });
  });

  group('Batch 10-116 巡游/议价经济常量契约', () {
    test('巡游消耗/件数/溢价常量与旧实现一致', () {
      expect(BalanceData.tradeSpecialtyEnergyCost, 12);
      expect(BalanceData.tradeSpecialtyQty, 2);
      expect(BalanceData.tradeSpecialtyMerchantPremium, 0.35);
      expect(BalanceData.tradeSpecialtyCommonerPremium, 0.15);
      expect(BalanceData.tradeSpecialtySpeechGain, 0.03);
    });

    test('议价消耗/成功率/折扣常量与旧实现一致', () {
      expect(BalanceData.negotiateEnergyCost, 5);
      expect(BalanceData.negotiateSpeechChanceMult, 8);
      expect(BalanceData.negotiateMerchantBonus, 20);
      expect(BalanceData.negotiateChanceVariance, 20);
      expect(BalanceData.negotiateSuccessThreshold, 40);
      expect(BalanceData.negotiateDiscountBase, 5);
      expect(BalanceData.negotiateDiscountVariance, 15);
      expect(BalanceData.negotiateDiscountPerSpeech, 2);
    });

    test('巡游溢价商人恒高于平民（身份加成差异）', () {
      expect(BalanceData.tradeSpecialtyMerchantPremium,
          greaterThan(BalanceData.tradeSpecialtyCommonerPremium));
    });

    test('议价成功率公式区间纯逻辑推导（chance = speech*8 + 商人20 + rnd(20)）', () {
      int chanceMin(int speech, bool merchant) =>
          speech * BalanceData.negotiateSpeechChanceMult +
          (merchant ? BalanceData.negotiateMerchantBonus : 0);
      int chanceMax(int speech, bool merchant) =>
          chanceMin(speech, merchant) + BalanceData.negotiateChanceVariance - 1;
      // 口才 3 商人：下限 44 ≥ 阈值 40 → 必成功
      expect(chanceMin(3, true), 44);
      expect(chanceMin(3, true), greaterThanOrEqualTo(BalanceData.negotiateSuccessThreshold));
      // 口才 0 平民：下限 0 < 阈值 → 可能失败
      expect(chanceMin(0, false), lessThan(BalanceData.negotiateSuccessThreshold));
      // 商人加成 = 20（与旧实现一致）
      expect(chanceMin(0, true) - chanceMin(0, false), 20);
      // 上限：口才 3 商人 44 + rnd(20) 上限 19
      expect(chanceMax(3, true), 44 + BalanceData.negotiateChanceVariance - 1);
    });

    test('议价折扣公式区间纯逻辑推导（5 + rnd(15) + 口才(clamp 0~3)*2）', () {
      int discountMin(int speech) => BalanceData.negotiateDiscountBase +
          speech.clamp(0, 3) * BalanceData.negotiateDiscountPerSpeech;
      int discountMax(int speech) => discountMin(speech) +
          BalanceData.negotiateDiscountVariance - 1;
      // 口才 0：5~19；口才 5（clamp 到 3）：11~25
      expect(discountMin(0), 5);
      expect(discountMax(0), 19);
      expect(discountMin(5), 5 + 3 * 2);
      expect(discountMax(5), 5 + 3 * 2 + 14);
      // 口才越高折扣越大（clamp 后单调不减）
      expect(discountMin(5), greaterThan(discountMin(0)));
    });

    test('所有 10-116 常量均为正数（防调平衡破坏贸易深化）', () {
      expect(BalanceData.tradeSpecialtyEnergyCost, greaterThan(0));
      expect(BalanceData.tradeSpecialtyQty, greaterThan(0));
      expect(BalanceData.tradeSpecialtySpeechGain, greaterThan(0));
      expect(BalanceData.negotiateEnergyCost, greaterThan(0));
      expect(BalanceData.negotiateSpeechChanceMult, greaterThan(0));
      expect(BalanceData.negotiateMerchantBonus, greaterThan(0));
      expect(BalanceData.negotiateChanceVariance, greaterThan(0));
      expect(BalanceData.negotiateSuccessThreshold, greaterThan(0));
      expect(BalanceData.negotiateDiscountBase, greaterThan(0));
      expect(BalanceData.negotiateDiscountVariance, greaterThan(0));
      expect(BalanceData.negotiateDiscountPerSpeech, greaterThan(0));
      expect(BalanceData.tradeSpecialtyMerchantPremium, greaterThan(0));
      expect(BalanceData.tradeSpecialtyMerchantPremium, lessThan(1));
      expect(BalanceData.tradeSpecialtyCommonerPremium, greaterThan(0));
      expect(BalanceData.tradeSpecialtyCommonerPremium, lessThan(1));
    });
  });
}
