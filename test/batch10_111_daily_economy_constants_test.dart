/// Batch 10-111 测试：日常活动经济魔法数字收口到 balance_data。
///
/// 背景：M4a（Batch 10-30）把数值集中到 `balance_data.dart`，但 mixin_play
/// 的 work/hunt/trade/rest 仍有大量散落魔法数字（能量消耗 15/20/10、身份
/// 收入 20/15/10/8/5/12、贸易 25/8、技能加成 ~/2、随机浮动 5/15、饱食恢复 10）。
/// 本批把它们收口为新常量（数值逐字不变，纯重构护栏）——「调平衡只改一个
/// 文件」的承诺兑现到日常经济链。
///
/// 零回归依据（一次性脚本取证）：
/// - `regression_identity_branch_test.dart` 锁定「商人贸易净赚恒比平民多 17」
///   （25 vs 8）与身份收入排序（商人 > 士兵 > 学者 > 平民）——数值不变即不红；
/// - `m4_balance_sim_test.dart` 的主动循环硬编码 `canAffordEnergy(20)`（hunt）、
///   `canAffordEnergy(15)`（work）、rest 花 2 金币——能量消耗值不变即不红；
/// - `batch4_mixin_play_test.dart` 只断言行为分支（「猎到猎物」「做成一笔买卖」
///   「歇了一晚」），不锁数值。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/balance_data.dart';
import 'package:westeros_life_simulator/models/player.dart';

void main() {
  group('Batch 10-111 日常活动经济常量契约', () {
    test('能量消耗常量与旧实现逐字一致（work 15 / hunt 20 / trade 10）', () {
      expect(BalanceData.workEnergyCost, 15);
      expect(BalanceData.huntEnergyCost, 20);
      expect(BalanceData.tradeEnergyCost, 10);
      // 与训练（10）拉开梯度：训练 < 工作 < 狩猎，消耗递增才符合设定
      expect(BalanceData.workEnergyCost,
          greaterThan(BalanceData.trainEnergyCost));
      expect(BalanceData.huntEnergyCost, greaterThan(BalanceData.workEnergyCost));
    });

    test('workBaseIncome 覆盖全部 10 个身份且数值与旧 switch 逐字一致', () {
      const expected = <String, int>{
        'merchant': 20,
        'soldier': 15,
        'noble': 12,
        'adventurer': 12,
        'assassin': 12,
        'wildling': 12,
        'scholar': 10,
        'maester': 10,
        'priest': 8,
        'commoner': 5,
      };
      expect(BalanceData.workBaseIncome, expected);
      // 全部身份都有档位（新增身份未配档位会立即红）
      expect(BalanceData.workBaseIncome.length,
          PlayerIdentity.values.length);
      for (final id in PlayerIdentity.values) {
        expect(BalanceData.workBaseIncome.containsKey(id.name), isTrue,
            reason: '身份 ${id.name} 缺失工作基础收入档位');
      }
    });

    test('workBaseIncome 排序护栏：商人 > 士兵 > 学者 > 神职 > 平民', () {
      int incomeOf(String id) => BalanceData.workBaseIncome[id]!;
      expect(incomeOf('merchant'), greaterThan(incomeOf('soldier')));
      expect(incomeOf('soldier'), greaterThan(incomeOf('scholar')));
      expect(incomeOf('scholar'), greaterThan(incomeOf('priest')));
      expect(incomeOf('priest'), greaterThan(incomeOf('commoner')));
      // 其他三类（noble/adventurer/assassin/wildling）与默认档 12 一致
      for (final id in ['noble', 'adventurer', 'assassin', 'wildling']) {
        expect(incomeOf(id), 12);
      }
    });

    test('工作浮动/技能加成系数与旧实现一致（浮动 5、除 2）', () {
      expect(BalanceData.workIncomeVariance, 5);
      expect(BalanceData.workSkillBonusDivisor, 2);
    });

    test('贸易利润常量与旧实现一致（商人 25 / 平民 8 / 口才 3 / 浮动 15）', () {
      expect(BalanceData.tradeMerchantBase, 25);
      expect(BalanceData.tradeCommonerBase, 8);
      // 商人 - 平民 恒 17（regression_identity_branch_test 锁定）
      expect(BalanceData.tradeMerchantBase - BalanceData.tradeCommonerBase, 17);
      expect(BalanceData.tradeSpeechGain, 3);
      expect(BalanceData.tradeProfitVariance, 15);
    });

    test('休息饱食恢复常量与旧实现一致（10）', () {
      expect(BalanceData.restHungerGain, 10);
    });

    test('所有新常量均为正值（防调平衡改成 0/负值破坏生存链）', () {
      expect(BalanceData.workEnergyCost, greaterThan(0));
      expect(BalanceData.huntEnergyCost, greaterThan(0));
      expect(BalanceData.tradeEnergyCost, greaterThan(0));
      expect(BalanceData.workIncomeVariance, greaterThan(0));
      expect(BalanceData.workSkillBonusDivisor, greaterThan(0));
      expect(BalanceData.tradeMerchantBase, greaterThan(0));
      expect(BalanceData.tradeCommonerBase, greaterThan(0));
      expect(BalanceData.tradeSpeechGain, greaterThan(0));
      expect(BalanceData.tradeProfitVariance, greaterThan(0));
      expect(BalanceData.restHungerGain, greaterThan(0));
      for (final v in BalanceData.workBaseIncome.values) {
        expect(v, greaterThan(0));
      }
    });
  });
}
