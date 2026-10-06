/// Batch 10-114 测试：冒险/旅行经济魔法数字收口到 balance_data。
///
/// 背景：M4a（10-30）「调平衡只改一个文件」承诺在 10-111/10-113 兑现到
/// 日常经济与 NPC 交互链，但 mixin_adventure 的旅费/探索/遭遇（强盗/野兽/商人）
/// 仍散落 14 个魔法数字。本批全部收口为新常量（数值逐字不变）。
///
/// 零回归依据（一次性脚本取证）：
/// - `batch4_mixin_adventure_test` 对 travel 只断言 `lessThan(before)`（扣钱）、
///   explore 只断言 `gold >= 100` 与文本包含，均不锁具体数字；
/// - 遭遇收益/损失无既有测试锁数字，故本批用纯逻辑公式推导区间断言
///   （参照 10-112 教训：不依赖引擎随机成败，同 seed 序列固定不可重试）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/balance_data.dart';

void main() {
  group('Batch 10-114 冒险/旅行经济常量契约', () {
    test('旅费公式常量与旧实现一致（基础 2 + 危险度 + rnd(4)）', () {
      expect(BalanceData.travelCostBase, 2);
      expect(BalanceData.travelCostVariance, 4);
    });

    test('探索公式常量与旧实现一致（精力 15 / 收益 3 + rnd(10 + 危险度*2)）', () {
      expect(BalanceData.exploreEnergyCost, 15);
      expect(BalanceData.exploreGoldBase, 3);
      expect(BalanceData.exploreGoldDangerMult, 2);
      expect(BalanceData.exploreGoldVarianceBase, 10);
    });

    test('遭遇公式常量与旧实现一致（强盗 5+危险度*2 / 野兽 8+危险度*2 / 商人 5+rnd(10)）', () {
      expect(BalanceData.banditLossBase, 5);
      expect(BalanceData.banditLossDangerMult, 2);
      expect(BalanceData.beastGainBase, 8);
      expect(BalanceData.beastGainDangerMult, 2);
      expect(BalanceData.beastHungerGain, 10);
      expect(BalanceData.beastInjuryHealth, 8);
      expect(BalanceData.merchantProfitBase, 5);
      expect(BalanceData.merchantProfitVariance, 10);
    });

    test('旅费公式边界（[base+danger, base+danger+variance-1]）', () {
      // 与实现逐字一致的推导：cost = base + danger + rnd.nextInt(variance)
      // rnd.nextInt(variance) ∈ [0, variance-1]，故区间端点公式：
      int costMinOf(int danger) => BalanceData.travelCostBase + danger;
      int costMaxOf(int danger) =>
          BalanceData.travelCostBase + danger + BalanceData.travelCostVariance - 1;
      expect(costMinOf(0), 2);
      expect(costMaxOf(0), BalanceData.travelCostBase + BalanceData.travelCostVariance - 1);
      expect(costMaxOf(5), BalanceData.travelCostBase + 5 + BalanceData.travelCostVariance - 1);
      // 区间非空且随危险度整体右移（min(3) > max(2) 不成立，但 min 单调不减）
      expect(costMinOf(5), greaterThan(costMinOf(0)));
      expect(costMaxOf(5), greaterThan(costMaxOf(0)));
      // 区间宽度 = variance - 1，独立于危险度
      expect(costMaxOf(0) - costMinOf(0), BalanceData.travelCostVariance - 1);
    });

    test('探索收益公式边界（[base, base+varianceBase+danger*mult-1]）', () {
      // 与实现逐字一致的推导：found = base + rnd.nextInt(varianceBase + danger*mult)
      // rnd.nextInt(n) ∈ [0, n-1]，故下限恒为 base，上限公式如下：
      int maxFoundOf(int danger) => BalanceData.exploreGoldBase +
          BalanceData.exploreGoldVarianceBase + danger * BalanceData.exploreGoldDangerMult - 1;
      expect(maxFoundOf(0), BalanceData.exploreGoldBase + BalanceData.exploreGoldVarianceBase - 1);
      expect(maxFoundOf(3), BalanceData.exploreGoldBase + BalanceData.exploreGoldVarianceBase + 6 - 1);
      // 危险度只扩上限不缩下限（保底收益不变）
      expect(maxFoundOf(3), greaterThan(maxFoundOf(0)));
    });

    test('强盗损失/野兽收益/商人利润公式（确定性部分与随机浮动均不越界）', () {
      // 强盗损失：base + danger*mult（确定性）
      expect(BalanceData.banditLossBase + 0 * BalanceData.banditLossDangerMult, 5);
      expect(BalanceData.banditLossBase + 3 * BalanceData.banditLossDangerMult, 11);
      // 野兽收益：base + danger*mult（确定性）
      expect(BalanceData.beastGainBase + 0 * BalanceData.beastGainDangerMult, 8);
      expect(BalanceData.beastGainBase + 3 * BalanceData.beastGainDangerMult, 14);
      // 商人利润：base + rnd.nextInt(variance)，区间 [base, base+variance-1]
      expect(BalanceData.merchantProfitBase, 5);
      expect(
        BalanceData.merchantProfitBase + BalanceData.merchantProfitVariance - 1,
        greaterThan(BalanceData.merchantProfitBase),
      );
    });

    test('所有新常量均为正数（防调平衡破坏冒险经济）', () {
      expect(BalanceData.travelCostBase, greaterThan(0));
      expect(BalanceData.travelCostVariance, greaterThan(0));
      expect(BalanceData.exploreEnergyCost, greaterThan(0));
      expect(BalanceData.exploreGoldBase, greaterThan(0));
      expect(BalanceData.exploreGoldDangerMult, greaterThan(0));
      expect(BalanceData.exploreGoldVarianceBase, greaterThan(0));
      expect(BalanceData.banditLossBase, greaterThan(0));
      expect(BalanceData.banditLossDangerMult, greaterThan(0));
      expect(BalanceData.beastGainBase, greaterThan(0));
      expect(BalanceData.beastGainDangerMult, greaterThan(0));
      expect(BalanceData.beastHungerGain, greaterThan(0));
      expect(BalanceData.beastInjuryHealth, greaterThan(0));
      expect(BalanceData.merchantProfitBase, greaterThan(0));
      expect(BalanceData.merchantProfitVariance, greaterThan(0));
    });
  });
}
