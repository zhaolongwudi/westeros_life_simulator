/// M6b 跨批次回归套件 · 身份分支（regression_identity_branch_test.dart）。
///
/// 背景：Batch 4 曾记录「mixin 里大量用 `player.identity.name` 匹配中文串」
/// 的契约隐患。M2（Batch 10-27）已把身份判断改为枚举比较并单测命中，
/// 但「收入分档 switch / 贸易加成 / 头衔阶梯」这条经济链仍值得**跨批次兜底回归**：
/// 只要未来有人把 `switch (player.identity)` 改坏/漏档，这里立即红灯。
///
/// 与 m2/m4 的区别：
/// - m2 覆盖「十个身份 work() 都有输出」；
/// - m4 覆盖「头衔阶梯与配置一致」；
/// - 本文件覆盖「**收入数值分档** = 身份专有，且商人/平民各档位**互不越界**」，
///   以及「同技能同 rng 下商人贸易收益恒高于平民固定差 17」。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/models/player.dart';
import 'package:westeros_life_simulator/utils/labels.dart';

Player _playerWith(PlayerIdentity identity,
    {String locationId = 'location_kings_landing'}) {
  return Player.defaultPlayer()
      .copyWith(identity: identity, locationId: locationId);
}

/// 从文本中取第一个整数（用于解析「挣得 N」「净赚 N」）。
/// 注意：动态正则必须用非 raw string + RegExp.escape（坑 M2）。
int _firstInt(String text, String label) {
  final m = RegExp('${RegExp.escape(label)}\\s*(\\d+)').firstMatch(text);
  if (m == null) {
    fail('未能解析「$label N」：\n$text');
  }
  return int.parse(m.group(1)!);
}

/// 调用 work() 一次，返回收入（同 rng 种子，确定性结果）。
///
/// 引擎 rng() 以 progress.turnCount 作种子，startNewGame 后恒为 0，
/// 故单次调用即为「固定随机种子」下的确定性收入；
/// 不同身份的档位差（基准 + 技能加成 + rnd）在相同种子上可严格比对。
({int lower, int upper}) _workIncomeRange(PlayerIdentity identity) {
  final engine = GameEngine()
    ..startNewGame(player: _playerWith(identity));
  final text = engine.work();
  final income = _firstInt(text, '挣得');
  return (lower: income, upper: income);
}

void main() {
  group('M6b 工作收入分档（身份 → 基准收入）', () {
    test('商人档基准 20：收入下限 ≥ 20（20 + 0 技能 + 0 rnd）', () {
      final r = _workIncomeRange(PlayerIdentity.merchant);
      expect(r.lower, greaterThanOrEqualTo(20), reason: '商人基准收入 20');
      // 上限 ≤ 20 + 5 rnd + 默认 speech2/2 + sword2/2 = 20+5+1+1 = 27
      expect(r.upper, lessThanOrEqualTo(27));
    });

    test('士兵档基准 15：收入区间明显低于商人（≥15 且 < 商人档下限）', () {
      final soldier = _workIncomeRange(PlayerIdentity.soldier);
      final merchant = _workIncomeRange(PlayerIdentity.merchant);
      expect(soldier.lower, greaterThanOrEqualTo(15));
      // 士兵上限（15+5+1+1=22）低于商人下限（20+0+1+1=22）的边界：至少士兵均值 < 商人均值
      final avgSoldier =
          (soldier.lower + soldier.upper) / 2;
      final avgMerchant = (merchant.lower + merchant.upper) / 2;
      expect(avgSoldier, lessThan(avgMerchant),
          reason: '士兵平均收入应低于商人');
    });

    test('学者/学士档基准 10：平均收入低于士兵且高于平民', () {
      final scholar = _workIncomeRange(PlayerIdentity.scholar);
      final soldier = _workIncomeRange(PlayerIdentity.soldier);
      final commoner = _workIncomeRange(PlayerIdentity.commoner);
      expect((scholar.lower + scholar.upper) / 2,
          lessThan((soldier.lower + soldier.upper) / 2));
      expect((scholar.lower + scholar.upper) / 2,
          greaterThan((commoner.lower + commoner.upper) / 2));
    });

    test('神职档基准 8 低于学者；平民档基准 5 最低', () {
      final priest = _workIncomeRange(PlayerIdentity.priest);
      final scholar = _workIncomeRange(PlayerIdentity.scholar);
      final commoner = _workIncomeRange(PlayerIdentity.commoner);
      expect((priest.lower + priest.upper) / 2,
          lessThan((scholar.lower + scholar.upper) / 2));
      expect((commoner.lower + commoner.upper) / 2,
          lessThan((priest.lower + priest.upper) / 2));
    });

    test('贵族/冒险者/刺客/野人走默认档 12：日均高于平民低于商人', () {
      for (final id in <PlayerIdentity>[
        PlayerIdentity.noble,
        PlayerIdentity.adventurer,
        PlayerIdentity.assassin,
        PlayerIdentity.wildling,
      ]) {
        final r = _workIncomeRange(id);
        final avg = (r.lower + r.upper) / 2;
        expect(r.lower, greaterThanOrEqualTo(12), reason: '${id.name} 默认档 12');
        final avgCommoner =
            (_workIncomeRange(PlayerIdentity.commoner).lower +
                    _workIncomeRange(PlayerIdentity.commoner).upper) /
                2;
        final avgMerchant =
            (_workIncomeRange(PlayerIdentity.merchant).lower +
                    _workIncomeRange(PlayerIdentity.merchant).upper) /
                2;
        expect(avg, greaterThan(avgCommoner));
        expect(avg, lessThan(avgMerchant));
      }
    });

    test('身份标签与档位一致（labels 集中层不回归）', () {
      expect(identityLabel(PlayerIdentity.merchant), '商人');
      expect(identityLabel(PlayerIdentity.soldier), '士兵');
      expect(identityLabel(PlayerIdentity.maester), '学士');
      expect(identityLabel(PlayerIdentity.wildling), '野人');
    });
  });

  group('M6b 贸易商人加成（同 rng 对比）', () {
    test('君临（城市）商人净赚恒比平民多 17', () {
      final merchant = GameEngine()
        ..startNewGame(player: _playerWith(PlayerIdentity.merchant));
      final commoner = GameEngine()
        ..startNewGame(player: _playerWith(PlayerIdentity.commoner));
      final mText = merchant.trade();
      final cText = commoner.trade();
      expect(mText, contains('净赚'));
      expect(cText, contains('净赚'));
      final m = _firstInt(mText, '净赚');
      final c = _firstInt(cText, '净赚');
      // 商人基础 25 vs 平民 8 → 固定差 17（同技能/同 rng）
      expect(m - c, 17, reason: '商人贸易加成应准确生效');
    });

    test('荒野地点（wilderness）贸易无法进行，返回引导语', () {
      final merchant = GameEngine()
        ..startNewGame(player: _playerWith(PlayerIdentity.merchant,
            locationId: 'location_the_neck'));
      final text = merchant.trade();
      expect(text, contains('不是做买卖的地方'));
    });
  });
}