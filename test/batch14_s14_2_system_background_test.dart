/// Batch 14 · S14-2 测试：纯背景系统显式标注 + 窄挂载系统真实月度效果。
///
/// ## 本卡要挡住的回归
///
/// 1. **归类退化**：S14-2 之前 `monthlyEffects == {}` 同时表示「刻意留空的
///    世界观背景」与「还没接线」，无人能分辨；且新增系统**默认就是背景**，
///    不需要任何人做决定。本卡要求每个系统**必须显式归类**——
///
///    - 机制化：`monthlyEffects` 非空（8 个）
///    - 纯背景：在 [kPureBackgroundSystems] 里且 `monthlyEffects` 为空（65 个）
///
///    两个集合必须**无交集、并集恰为全部 73 个**。日后新增系统若不声明归属，
///    「并集 == 全集」这条立即变红——这正是"显式标注"三个字的全部含义。
/// 2. **标注与生效脱节**：标了「纯背景」却又偷偷挂月度效果 = 玩家在面板上
///    被告知「仅供查阅」，实际每月扣钱。本卡锁死两者不可同时成立。
/// 3. **给永不可见系统挂效果**：`异鬼` / `死亡` 被 `availableSystems` 显式
///    `false`，挂了也永远不结算 = 新的摆设（用户「不要里面有摆设的东西」）。
/// 4. **量级失控**：精力月净回 ≈ 15（`sleptWellChance 0.7` ×（`sleepEnergyBase
///    15` + 均值 7.5）），任一系统 `energy` 负担超过它就软锁死该路线。
///    与 `batch12_s41` 对守夜人的锁同型，本卡扩到全部机制化系统。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/balance_data.dart';
import 'package:westeros_life_simulator/data/system_data.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/models/player.dart';

/// 机制化系统全集（S4-1 的 2 个 + S14-2 的 6 个）。
const Set<String> _expectedMechanized = <String>{
  'system_citadel',
  'system_nightswatch',
  'system_dothraki',
  'system_dothraki_culture',
  'system_wildling',
  'system_ironborn',
  'system_faceless',
  'system_magic',
};

void main() {
  group('S14-2 · 归类契约（背景 vs 机制化）', () {
    test('73 个系统恰好分为「机制化 8」+「纯背景 65」，无交集无遗漏', () {
      final mechanized =
          allSystems.where((s) => s.hasMonthlyEffects).map((s) => s.id).toSet();
      final background = kPureBackgroundSystems;
      final allIds = allSystems.map((s) => s.id).toSet();

      expect(allSystems.length, 73);
      expect(mechanized.intersection(background), isEmpty,
          reason: '同一个系统不能既是纯背景又是机制化');
      expect(mechanized.union(background), allIds,
          reason: '有系统没声明归属：'
              '${allIds.difference(mechanized.union(background)).toList()}');
      expect(background.length, 65);
    });

    test('机制化集合恰为 8 个（含本卡新增的 6 个窄挂载系统）', () {
      final mechanized =
          allSystems.where((s) => s.hasMonthlyEffects).map((s) => s.id).toSet();
      expect(mechanized, _expectedMechanized);
    });

    test('纯背景系统的 monthlyEffects 必须全为空（标注与生效不得脱节）', () {
      for (final s in allSystems) {
        if (!kPureBackgroundSystems.contains(s.id)) continue;
        expect(s.monthlyEffects, isEmpty,
            reason: '${s.id} 被标为纯背景，却又挂了 '
                '${s.monthlyEffects} —— 面板会告诉玩家「仅供查阅」');
      }
    });

    test('永不可见系统不得挂月度效果（挂了也永远不结算 = 新摆设）', () {
      // 异鬼 / 死亡 在 availableSystems 里显式 false（mixin_systems.dart:131）。
      const neverVisible = <String>{'system_white_walker', 'system_death'};
      for (final s in allSystems) {
        if (!neverVisible.contains(s.id)) continue;
        expect(s.hasMonthlyEffects, isFalse,
            reason: '${s.id} 永不可见，挂了月度效果也只是摆设');
      }
    });

    test('机制化系统的效果键零幽灵键（applyEffects 会静默拒收）', () {
      const legal = {'gold', 'reputation', 'health', 'energy', 'hunger'};
      for (final s in allSystems) {
        for (final k in s.monthlyEffects.keys) {
          expect(legal.contains(k), true,
              reason: '${s.id} 挂了无实现的效果键「$k」，等于白写');
        }
      }
    });
  });

  group('S14-2 · 月度效果数值契约', () {
    test('6 个新系统的效果逐条钉死（数值改动必须有意识地发生）', () {
      expect(_effectsOf('system_dothraki'), {'energy': -5, 'health': 2});
      expect(_effectsOf('system_dothraki_culture'), {'gold': 3, 'energy': -3});
      expect(_effectsOf('system_wildling'), {'hunger': 5, 'energy': -3});
      expect(_effectsOf('system_ironborn'), {'energy': -5});
      expect(_effectsOf('system_faceless'), {'energy': -5});
      expect(_effectsOf('system_magic'), {'energy': -5});
    });

    test('任一机制化系统的精力负担都不得超过月净回上限', () {
      // 每月净回 = sleptWellChance × (sleepEnergyBase + sleepEnergyVariance/2)
      final netGain = BalanceData.sleptWellChance *
          (BalanceData.sleepEnergyBase + BalanceData.sleepEnergyVariance / 2);
      for (final s in allSystems.where((s) => s.hasMonthlyEffects)) {
        final drain = (s.monthlyEffects['energy'] ?? 0).abs();
        expect(drain, lessThan(netGain),
            reason: '${s.id} 精力月耗 $drain ≥ 净回上限 '
                '${netGain.toStringAsFixed(1)}，该路线会被软锁死');
      }
    });

    test('铁金库仍刻意留空（无持久化债务状态，负向金币=凭空扣钱）', () {
      expect(_effectsOf('system_iron_bank'), isEmpty);
      expect(kPureBackgroundSystems.contains('system_iron_bank'), isTrue,
          reason: '留空是**刻意**的，必须显式归入纯背景而不是靠"碰巧为空"');
    });
  });

  group('S14-2 · 结算真的发生（行为判别式）', () {
    test('野人在鬼影森林：采集果腹 +5 饱食，跋涉 -3 精力', () {
      final engine = _engineAt('location_whispering_wood');
      final b = engine.player;
      final text = engine.applyMonthlySystems(seed: 1);
      expect(engine.availableSystems().map((s) => s.id), contains('system_wildling'));
      expect(engine.player.hunger, b.hunger + 5);
      expect(engine.player.energy, b.energy - 3);
      expect(text, contains('野人系统'));
      expect(text, contains('饱食 +5'));
    });

    test('铁民在派克城：航海风浪 -5 精力，无稳定收入', () {
      final engine = _engineAt('location_pike');
      final gold = engine.player.gold;
      final energy = engine.player.energy;
      final text = engine.applyMonthlySystems(seed: 1);
      expect(engine.availableSystems().map((s) => s.id), contains('system_ironborn'));
      expect(engine.player.energy, energy - 5);
      expect(engine.player.gold, gold, reason: '铁民不给金币（不耕种、只掠夺）');
      expect(text, contains('铁民系统'));
      expect(text, contains('精力 -5'));
    });

    test('无垢者在阿斯塔波：每日训练 -5 精力 +2 健康', () {
      final engine = _engineAt('location_astapor');
      final b = engine.player;
      final text = engine.applyMonthlySystems(seed: 1);
      expect(engine.player.energy, b.energy - 5);
      expect(engine.player.health, b.health + 2);
      expect(text, contains('无垢者系统'));
      expect(text, contains('精力 -5'));
    });

    test('多斯拉克在多斯拉克海：劫掠 +3 金币 -3 精力', () {
      final engine = _engineAt('location_dothraki_sea');
      final energy = engine.player.energy;
      final text = engine.applyMonthlySystems(seed: 1);
      expect(engine.player.energy, energy - 3);
      // 金币不做精确断言：多斯拉克海 dangerLevel=5，`applyMonthlySystems`
      // 第 2 步会按 30% 概率额外扣钱。但第 5 步的 delta 是**自己前后对比**，
      // 因此结算文本里的「金币 +3」是确定的。
      expect(text, contains('多斯拉克系统'));
      expect(text, contains('金币 +3'));
    });

    test('无面者在布拉佛斯：维系易容 -5 精力', () {
      final engine = _engineAt('location_braavos');
      final energy = engine.player.energy;
      final text = engine.applyMonthlySystems(seed: 1);
      expect(engine.player.energy, energy - 5);
      expect(text, contains('无面者系统'));
    });

    test('身处超自然地点：研习异术 -5 精力（与身份无关）', () {
      final engine = _engineAt('location_old_gods');
      final energy = engine.player.energy;
      final text = engine.applyMonthlySystems(seed: 1);
      expect(engine.availableSystems().map((s) => s.id), contains('system_magic'));
      expect(engine.player.energy, energy - 5);
      expect(text, contains('魔法体系'));
    });

    test('学士在学城：学城 -3 与魔法 -5 叠加为 -8，仍低于月净回上限', () {
      final engine = GameEngine(
        player: Player.defaultPlayer().copyWith(
          identity: PlayerIdentity.maester,
          locationId: 'location_citadel',
          energy: 80,
          familyId: '',
        ),
        isGameActive: true,
      );
      final energy = engine.player.energy;
      engine.applyMonthlySystems(seed: 1);
      expect(engine.player.energy, energy - 8);

      final netGain = BalanceData.sleptWellChance *
          (BalanceData.sleepEnergyBase + BalanceData.sleepEnergyVariance / 2);
      expect(8, lessThan(netGain));
    });
  });

  group('S14-2 · 负向锁（不在挂载点绝不结算）', () {
    test('贵族在君临城：拿不到任何一个窄挂载系统的月度效果', () {
      final engine = GameEngine(
        player: Player.defaultPlayer().copyWith(
          identity: PlayerIdentity.noble,
          locationId: 'location_kings_landing',
          familyId: '',
        ),
        isGameActive: true,
      );
      expect(engine.availableSystems().where((s) => s.hasMonthlyEffects), isEmpty,
          reason: 'S14-2 的 6 个系统全部是窄挂载（荒野/铁群岛/阿斯塔波/'
              '布拉佛斯/超自然地点），不得外溢到城市');
      final before = engine.player;
      engine.applyMonthlySystems(seed: 1);
      expect(engine.player.gold, before.gold);
      expect(engine.player.energy, before.energy);
      expect(engine.player.hunger, before.hunger);
      expect(engine.player.health, before.health);
    });

    test('平民在君临城同样不结算（挂载只看地点/身份，不看出身）', () {
      final engine = _engineAt('location_kings_landing');
      expect(engine.availableSystems().where((s) => s.hasMonthlyEffects), isEmpty);
    });
  });

  group('S14-2 · 面板标注', () {
    test('纯背景系统显式标出「仅供查阅」，不再让玩家靠猜', () {
      final engine = _engineAt('location_whispering_wood');
      final panel = engine.formatSystemsPanel();
      expect(panel, contains('世界观背景'));
      // 同一面板里，机制化系统仍走 S4-1 那行「月度结算」。
      expect(panel, contains('月度结算：hunger +5，energy -3'));
    });

    test('纯背景系统的 monthlyEffects 不进面板的月度结算行', () {
      final engine = _engineAt('location_whispering_wood');
      final panel = engine.formatSystemsPanel();
      expect(panel, isNot(contains('月度结算：{}')));
      expect(panel, isNot(contains('月度结算：gold: 0')));
    });
  });
}

/// 构造一个「平民、无家族、生存值居中、处于指定地点」的在局引擎。
///
/// 【为什么固定 familyId: ''】`applyMonthlySystems` 第 1 步会给家族发金币
/// （影响力折算），不掐掉会让精确数值断言随默认玩家的家族而漂移。
/// 【为什么固定生存值】`applyEffects` 会把生存值钳到 0~100，从 100 起步
/// 再 +2 会被吃掉，delta 就不是数据里写的那个数。
GameEngine _engineAt(String locationId) {
  return GameEngine(
    player: Player.defaultPlayer().copyWith(
      identity: PlayerIdentity.commoner,
      locationId: locationId,
      health: 60,
      energy: 60,
      hunger: 60,
      familyId: '',
    ),
    isGameActive: true,
  );
}

Map<String, int> _effectsOf(String systemId) =>
    allSystems.firstWhere((s) => s.id == systemId).monthlyEffects;