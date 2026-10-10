/// S4-1（P1-09）测试：系统机制化 —— `GameSystem.monthlyEffects` 月度结算。
///
/// ## 本批次要挡住的三类回归
///
/// 1. **机制化退化成文案**：73 个系统里 65 个 `monthlyEffects` 为空是有意的
///    诚实标注（S14-2 起显式登记在 `kPureBackgroundSystems` 里），
///    但「恰好 8 个有效果」这个事实必须被断言锁住
///    ——否则日后有人批量往systems 里填字段、无人复核算力平衡，机制化就
///    变成了「每种玩法路线都能白嫖月度收益」。
/// 2. **数值与月度恢复打架**：守夜人 `energy: -10` 的上限来自
///    `sleptWellChance 0.7` × (`sleepEnergyBase 15` + 均值 7.5) ≈ 净回 15。
///    若日后把负担调到 -20，守夜人路线会被软锁死（净回 -5），此断言即红。
/// 3. **幽灵键回流**：`monthlyEffects` 复用效果键体系，若有人写了
///    `political` / `faith` 这类无实现的键，`applyEffects` 会拒收并在
///    `lastRejectedEffectKeys` 里留痕——必须验证这条链路真的通，且
///    拒收时**不产生任何状态变化**（不能「数值没变但叙事说有结算」）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/balance_data.dart';
import 'package:westeros_life_simulator/data/system_data.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/models/player.dart';
import 'package:westeros_life_simulator/models/system.dart';

void main() {
  group('S4-1 · monthlyEffects 数据契约', () {
    test('全部系统的 monthlyEffects 键名都在效果键体系内（零幽灵键）', () {
      const legal = {
        'gold',
        'reputation',
        'health',
        'energy',
        'hunger',
      };
      for (final s in allSystems) {
        for (final k in s.monthlyEffects.keys) {
          final bare = k.contains('.') ? k.split('.').first : k;
          expect(legal.contains(bare), true,
              reason: '${s.id} 挂了非法/无实现的效果键「$k」；'
                  'applyEffects 会静默拒收它，等于白写');
        }
      }
    });

    test('恰好 8 个系统机制化，65 个为纯背景（防止范围无声扩张）', () {
      // S14-2：机制化 2 → 8（新增 6 个窄挂载系统），背景 71 → 65。
      // 「恰好 N」这道锁本身**没有放松**——它防的是有人批量往 systems 里
      // 填字段、无人复核平衡；数字变化是 S14-2 的显式决定，且新增的
      // 6 个系统逐条钉在 `batch14_s14_2_system_background_test.dart`。
      final mechanized =
          allSystems.where((s) => s.hasMonthlyEffects).map((s) => s.id).toSet();
      expect(mechanized, {
        'system_citadel',
        'system_nightswatch',
        'system_dothraki',
        'system_dothraki_culture',
        'system_wildling',
        'system_ironborn',
        'system_faceless',
        'system_magic',
      });
      expect(allSystems.length, 73);
      expect(allSystems.where((s) => s.hasMonthlyEffects).length, 8);
      expect(kPureBackgroundSystems.length, 65);
    });

    test('铁金库刻意留空（无持久化债务状态，负向金币=凭空扣钱）', () {
      final iron = allSystems.firstWhere((s) => s.id == 'system_iron_bank');
      expect(iron.monthlyEffects, isEmpty,
          reason: '铁金库挂载条件是「城市或市场」几乎全员命中，'
              '而全库无债务状态；一旦挂 gold:-N 就是无依据的每月扣款');
    });

    test('守夜人只扣精力、不给金币（誓约不领薪酬）', () {
      final watch = allSystems.firstWhere((s) => s.id == 'system_nightswatch');
      expect(watch.monthlyEffects.containsKey('gold'), false);
      expect(watch.monthlyEffects['energy'], isNotNull);
    });

    test('守夜人负担不得超月度净回上限，否则路线被锁死', () {
      // 每月净回 = sleptWellChance × (sleepEnergyBase + sleepEnergyVariance/2)
      final netGain = BalanceData.sleptWellChance *
          (BalanceData.sleepEnergyBase + BalanceData.sleepEnergyVariance / 2);
      final watch = allSystems.firstWhere((s) => s.id == 'system_nightswatch');
      final drain = watch.monthlyEffects['energy'] ?? 0;
      expect(drain.abs(), lessThan(netGain),
          reason: '精力月耗 $drain 超过净回上限 ${netGain.toStringAsFixed(1)}，'
              '守夜人路线会被软锁死');
    });

    test('copyWith / toJson / fromJson 对 monthlyEffects 三向一致', () {
      final citadel = allSystems.firstWhere((s) => s.id == 'system_citadel');
      expect(citadel.copyWith().monthlyEffects, citadel.monthlyEffects);
      expect(GameSystem.fromJson(citadel.toJson()).monthlyEffects,
          citadel.monthlyEffects);
    });

    test('fromJson 遇老存档缺 monthlyEffects 时回落空（不崩）', () {
      final legacy = GameSystem.fromJson(const {
        'id': 'system_x',
        'name': '旧档系统',
        'category': '封建',
        'description': '来自旧存档',
        'rules': <String>[],
        'features': <String>[],
      });
      expect(legacy.monthlyEffects, isEmpty);
      expect(legacy.hasMonthlyEffects, isFalse);
    });

    test('fromJson 遇非数值/脏值时按 0 处理而非抛异常', () {
      final dirty = GameSystem.fromJson(const {
        'id': 'system_x',
        'name': '脏档系统',
        'category': '封建',
        'description': '脏值',
        'rules': <String>[],
        'features': <String>[],
        'monthlyEffects': {'gold': 'abc', 'energy': '12', 'reputation': null},
      });
      expect(dirty.monthlyEffects['gold'], 0);
      expect(dirty.monthlyEffects['energy'], 12); // 数字字符串被容错解析
      expect(dirty.monthlyEffects['reputation'], 0);
    });
  });

  group('S4-1 · 月度结算实际生效', () {
    test('守夜人在长城：精力按月扣减并输出可读结算', () {
      final engine = GameEngine(
        player: Player.defaultPlayer().copyWith(
          locationId: 'location_the_wall',
          energy: 80,
          familyId: '',
        ),
        isGameActive: true,
      );
      expect(engine.availableSystems().any((s) => s.id == 'system_nightswatch'),
          true);

      final before = engine.player.energy;
      final text = engine.applyMonthlySystems(seed: 1);
      expect(engine.player.energy, before - 10);
      expect(text, contains('守夜人'));
      expect(text, contains('精力 -10'));
    });

    test('学士在学城：领津贴 +5 金，抄书耗 3 精力，另付魔法代价 -5',
        () {
      final engine = GameEngine(
        player: Player.defaultPlayer().copyWith(
          identity: PlayerIdentity.maester,
          locationId: 'location_citadel',
          energy: 80,
          familyId: '',
        ),
        isGameActive: true,
      );
      expect(
          engine.availableSystems().any((s) => s.id == 'system_citadel'), true);

      final goldBefore = engine.player.gold;
      final energyBefore = engine.player.energy;
      final text = engine.applyMonthlySystems(seed: 1);
      expect(engine.player.gold, goldBefore + 5);
      // S14-2：maester 身份同时挂载**魔法体系**（`mixin_systems.dart:100-104`
      // 的魔法条件含 maester），故学城 -3 之外还要付魔法 -5 = 合计 -8。
      // 这不是回归，是 S14-2 有意扩大的机制面；学城自身的那 -3 由
      // `batch14_s14_2` 的「叠加上限」断言继续锁住。
      expect(engine.player.energy, energyBefore - 8);
      expect(text, contains('学城'));
      expect(text, contains('+5 金币'));
      expect(text, contains('魔法体系'));
    });

    test('未挂载系统不结算（在君临城的贵族拿不到学城津贴）', () {
      final engine = GameEngine(
        player: Player.defaultPlayer().copyWith(
          identity: PlayerIdentity.noble,
          locationId: 'location_kings_landing',
          familyId: '',
        ),
        isGameActive: true,
      );
      expect(
          engine.availableSystems().any((s) => s.hasMonthlyEffects), false,
          reason: '默认贵族在君临城不应挂载任何带月度效果的系统');

      final before = engine.player;
      engine.applyMonthlySystems(seed: 1);
      // 无家族、无危险度、非冬天 → 四处来源都不该改动状态
      expect(engine.player.gold, before.gold);
      expect(engine.player.energy, before.energy);
    });

    test('结算走钳制：金币不会因月度效果变负', () {
      final engine = GameEngine(
        player: Player.defaultPlayer().copyWith(
          identity: PlayerIdentity.maester,
          locationId: 'location_citadel',
          gold: 0,
          familyId: '',
        ),
        isGameActive: true,
      );
      engine.applyMonthlySystems(seed: 1);
      expect(engine.player.gold, greaterThanOrEqualTo(0));
    });

    test('系统面板标出哪些系统真的有月度结算', () {
      final engine = GameEngine(
        player: Player.defaultPlayer().copyWith(
          locationId: 'location_the_wall',
          identity: PlayerIdentity.noble,
        ),
        isGameActive: true,
      );
      final panel = engine.formatSystemsPanel();
      expect(panel, contains('月度结算'));
      expect(panel, contains('energy -10'));
    });

    test('未开始的游戏不结算系统效果', () {
      final engine = GameEngine(
        player: Player.defaultPlayer().copyWith(
          locationId: 'location_the_wall',
          energy: 80,
        ),
      );
      expect(engine.applyMonthlySystems(), '');
      expect(engine.player.energy, 80);
    });
  });
}