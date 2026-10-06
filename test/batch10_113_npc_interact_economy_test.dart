/// Batch 10-113 测试：NPC 交互经济魔法数字收口到 balance_data。
///
/// 背景：M4a（10-30）「调平衡只改一个文件」承诺在 10-111 兑现到日常经济链，
/// 但 mixin_npc_interact 的深度交互/示好/任务结算仍散落 20+ 魔法数字
/// （示好礼金公式、深聊好感公式、护送/合股/刺客委托报酬、任务结算奖励、
/// 各种关系/声望小奖励）。本批全部收口为新常量（数值逐字不变）。
///
/// 零回归依据（一次性脚本取证）：
/// - `batch10_13_npc_interact_test` 对 npcFavor/npcChat 只断言
///   `lessThan(goldBefore)`（扣钱）与 `greaterThan(0)`（加好感），不锁具体数字；
/// - `batch10_15/18/24` 任务类测试断言行为分支与关系增减，不锁奖励数字。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/balance_data.dart';

void main() {
  group('Batch 10-113 NPC 交互经济常量契约', () {
    test('深聊/示好好感公式常量与旧实现一致（基础 3 + speech~/2 + rnd(3)）', () {
      expect(BalanceData.npcChatGainBase, 3);
      expect(BalanceData.npcChatGainVariance, 3);
    });

    test('示好礼金公式常量与旧实现一致（5 + (100-rel)~/20，钳 3~12）', () {
      expect(BalanceData.npcFavorCostBase, 5);
      expect(BalanceData.npcFavorCostDivisor, 20);
      expect(BalanceData.npcFavorCostMin, 3);
      expect(BalanceData.npcFavorCostMax, 12);
      // 边界验证：rel=0 → (5+5).clamp(3,12)=10；rel=100 → 5.clamp(3,12)=5；rel=200 → 0.clamp=3
      int costOf(int rel) => (BalanceData.npcFavorCostBase +
              (100 - rel) ~/ BalanceData.npcFavorCostDivisor)
          .clamp(BalanceData.npcFavorCostMin, BalanceData.npcFavorCostMax);
      expect(costOf(0), 10);
      expect(costOf(100), 5);
      expect(costOf(200), 3);
      expect(costOf(-100), 12); // 关系极差时礼金封顶 12
    });

    test('熟识请求报酬常量与旧实现一致（护送 15+rnd10 / 合股 10+rnd10 / 刺客 20+rnd15）', () {
      expect(BalanceData.escortFeeBase, 15);
      expect(BalanceData.escortFeeVariance, 10);
      expect(BalanceData.merchantShareBase, 10);
      expect(BalanceData.merchantShareVariance, 10);
      expect(BalanceData.assassinFeeBase, 20);
      expect(BalanceData.assassinFeeVariance, 15);
    });

    test('任务结算/接取奖励常量与旧实现一致（结算 20+rel~/2 / 关系 5 / 接取 2）', () {
      expect(BalanceData.taskRewardBase, 20);
      expect(BalanceData.taskRewardRelation, 5);
      expect(BalanceData.taskAcceptRelation, 2);
    });

    test('通用声望/关系小奖励常量与旧实现一致', () {
      expect(BalanceData.reputationSmallGain, 2);
      expect(BalanceData.wildlingGiftGold, 5);
      expect(BalanceData.priestHealHealth, 5);
      expect(BalanceData.secretRelationGain, 3);
      expect(BalanceData.chatRelationGain, 2);
      expect(BalanceData.nobleReferReputation, 4);
      expect(BalanceData.supernaturalReputationGain, 3);
      expect(BalanceData.scholarTeachChance, 0.4);
    });

    test('所有新常量均为正数（防调平衡破坏交互经济）', () {
      expect(BalanceData.npcChatGainBase, greaterThan(0));
      expect(BalanceData.npcChatGainVariance, greaterThan(0));
      expect(BalanceData.npcFavorCostBase, greaterThan(0));
      expect(BalanceData.npcFavorCostDivisor, greaterThan(0));
      expect(BalanceData.npcFavorCostMin, greaterThan(0));
      expect(BalanceData.npcFavorCostMax, greaterThan(BalanceData.npcFavorCostMin));
      expect(BalanceData.escortFeeBase, greaterThan(0));
      expect(BalanceData.escortFeeVariance, greaterThan(0));
      expect(BalanceData.merchantShareBase, greaterThan(0));
      expect(BalanceData.merchantShareVariance, greaterThan(0));
      expect(BalanceData.assassinFeeBase, greaterThan(0));
      expect(BalanceData.assassinFeeVariance, greaterThan(0));
      expect(BalanceData.taskRewardBase, greaterThan(0));
      expect(BalanceData.taskRewardRelation, greaterThan(0));
      expect(BalanceData.taskAcceptRelation, greaterThan(0));
      expect(BalanceData.reputationSmallGain, greaterThan(0));
      expect(BalanceData.wildlingGiftGold, greaterThan(0));
      expect(BalanceData.priestHealHealth, greaterThan(0));
      expect(BalanceData.secretRelationGain, greaterThan(0));
      expect(BalanceData.chatRelationGain, greaterThan(0));
      expect(BalanceData.nobleReferReputation, greaterThan(0));
      expect(BalanceData.supernaturalReputationGain, greaterThan(0));
      expect(BalanceData.scholarTeachChance, greaterThan(0));
      expect(BalanceData.scholarTeachChance, lessThanOrEqualTo(1));
    });
  });
}