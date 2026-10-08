/// S13-13 测试：⑱⑲⑳㉑ 四项小缺陷收口。
///
/// 每项都先给出「修好前的可观测错误」作为复现，再锁「修好后的契约」。
///
/// - ⑱ 两条新游戏路径开局状态不一致：向导 `buildSetupPlayer` 给
///   `hunger: 60`，而设置页「新游戏」/各屏幕兜底的
///   `GameEngine()..startNewGame()` 走 `Player.defaultPlayer()` 的构造器
///   默认值。此前为 `hunger: 0` ⇒ 该路径开局即低于
///   `BalanceData.starvationThreshold`(25)，`applyMonthlyLife` 自第 1 回合
///   起每月扣 8 健康、恢复仅 +2，净 -6/月，玩家在毫无提示的情况下慢性死亡。
/// - ⑲ 两条 `applyEffects` 对 flags 负值语义相反：provider 用 `value > 0`，
///   `EventService` 用 `value != 0` ⇒ 同一个 `flags.x: -1` 在一处「置真」、
///   在另一处「清除」。prompt（`ai_service.dart:761`）写的是「正值设置标记…
///   0 或负值清除标记」，即 `> 0` 才是契约。
/// - ⑳ prompt 向 AI 承诺「数值超出按边界截断」（`ai_service.dart:764`），
///   但 `skills.`/`attributes.` 只有下限 `max(0, ...)`，没有上限 ⇒
///   AI 写 `skills.sword: 20` 会原样落盘，而 `BalanceData.skillCap`(10)
///   在效果写入路径上从未被读取。
/// - ㉑ `useItem` 只消费 health/energy/hunger 三个键，`item_wine` 声明的
///   `reputation: 1`（`item_data.dart:112`）被静默丢弃，而返回值仍告诉玩家
///   「你使用了多恩红葡萄酒」——效果与叙事脱节。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/balance_data.dart';
import 'package:westeros_life_simulator/data/event_data.dart';
import 'package:westeros_life_simulator/data/item_data.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/models/event.dart';
import 'package:westeros_life_simulator/models/player.dart';
import 'package:westeros_life_simulator/providers/game_state_provider.dart';
import 'package:westeros_life_simulator/screens/start_screen.dart';
import 'package:westeros_life_simulator/services/event_service.dart';

void main() {
  // ==================== ⑱ 新游戏开局饱食度 ====================

  group('S13-13 ⑱ 新游戏开局不挨饿', () {
    test('Player 构造器默认饱食度 = 60（与向导同源）', () {
      // 此前默认 0：构造器未显式传 hunger 时即低于饥饿阈值 25。
      final p = Player.defaultPlayer();
      expect(p.hunger, 60,
          reason: '默认开局饱食度必须与向导 buildSetupPlayer 一致，'
              '否则设置页「新游戏」开局就在饿死');
    });

    test('两条开局路径的饱食度一致', () {
      final setup = GameSetup(
        name: '测试者',
        gender: 'male',
        identity: PlayerIdentity.noble,
        familyId: 'family_stark',
        locationId: 'location_winterfell',
        era: '篡夺者战争后',
        season: 'spring',
        year: 283,
        month: 3,
      );
      final viaWizard = buildSetupPlayer(setup);
      final viaSettings = Player.defaultPlayer();
      expect(viaSettings.hunger, viaWizard.hunger,
          reason: '向导 $viaWizard.hunger vs 设置页 ${viaSettings.hunger}：'
              '同一款游戏的两条新游戏入口不能给不同开局状态');
    });

    test('默认开局不处于饥饿状态', () {
      final e = GameEngine()..startNewGame();
      expect(e.isStarving, isFalse,
          reason: '开局即 isStarving=true 会让 applyMonthlyLife 从第 1 回合'
              '起每月 -8 健康');
    });

    test('默认开局连跑 12 个月不会因饥饿掉血至死', () {
      final e = GameEngine()..startNewGame();
      final healthBefore = e.player.health;
      for (var i = 0; i < 12; i++) {
        e.advanceMonth();
      }
      expect(e.player.flags['isAlive'], isNot(false),
          reason: '默认开局 12 个月内不应死亡');
      expect(e.player.health, lessThanOrEqualTo(healthBefore),
          reason: '12 个月无补给后健康只会持平或下降（饱食 60 撑不满一年）');
    });

    test('旧存档缺 hunger 字段时回落 60（与 health/energy 同口径）', () {
      final json = Player.defaultPlayer().toJson();
      json.remove('health');
      json.remove('energy');
      json.remove('hunger');
      final restored = Player.fromJson(json);
      expect(restored.health, 100);
      expect(restored.energy, 100);
      expect(restored.hunger, 60,
          reason: 'health/energy 都回落满值，hunger 回落 0 会让读档即挨饿');
    });

    test('显式写入的 hunger 仍原样保留（不被默认值覆盖）', () {
      final p = Player.defaultPlayer().copyWith(hunger: 7);
      final restored = Player.fromJson(p.toJson());
      expect(restored.hunger, 7);
    });
  });

  // ==================== ⑲ flags 负值语义 ====================

  group('S13-13 ⑲ 两条 applyEffects 的 flags 负值语义一致', () {
    EventChoice choice(Map<String, int> effects) => EventChoice(
          id: 'c1',
          text: '测试',
          requirements: const {},
          effects: effects,
          narrative: '测试',
        );

    test('负值清除标记（EventService 与 provider 同语义）', () {
      const service = EventService();
      final p = Player.defaultPlayer().copyWith(
        flags: <String, bool>{'isAlive': true, 'honor_pledge': true},
      );
      final r = service.applyEffects(p, choice({'flags.honor_pledge': -1}));
      expect(r.newPlayer.flags['honor_pledge'], false,
          reason: 'prompt 承诺「0 或负值清除标记」；'
              '此前 EventService 用 value != 0，-1 反而置真');
    });

    test('0 清除标记', () {
      const service = EventService();
      final p = Player.defaultPlayer().copyWith(
        flags: <String, bool>{'isAlive': true, 'honor_pledge': true},
      );
      final r = service.applyEffects(p, choice({'flags.honor_pledge': 0}));
      expect(r.newPlayer.flags['honor_pledge'], false);
    });

    test('正值设置标记', () {
      const service = EventService();
      final p = Player.defaultPlayer();
      final r = service.applyEffects(p, choice({'flags.honor_pledge': 1}));
      expect(r.newPlayer.flags['honor_pledge'], true);
    });

    test('两通道对同一个 -1 给出同一结果', () {
      const service = EventService();
      final provider = GameStateProvider();
      final base = Player.defaultPlayer().copyWith(
        flags: <String, bool>{'isAlive': true, 'honor_pledge': true},
      );
      final viaService =
          service.applyEffects(base, choice({'flags.honor_pledge': -1}));
      final viaProvider = provider.applyEffects(
        base,
        const <String, int>{'flags.honor_pledge': -1},
      );
      expect(viaService.newPlayer.flags['honor_pledge'],
          viaProvider.flags['honor_pledge'],
          reason: '同一效果键在两条通道必须同语义');
    });
  });

  // ==================== ⑳ 技能/属性上限 ====================

  group('S13-13 ⑳ skills/attributes 效果封顶', () {
    EventChoice choice(Map<String, int> effects) => EventChoice(
          id: 'c1',
          text: '测试',
          requirements: const {},
          effects: effects,
          narrative: '测试',
        );

    test('provider：技能超过上限被截断到 skillCap', () {
      final provider = GameStateProvider();
      final p = provider.applyEffects(
        Player.defaultPlayer(),
        const <String, int>{'skills.sword': 999},
      );
      expect(p.skills['sword'], BalanceData.skillCap,
          reason: 'prompt 承诺「超出按边界截断」，'
              '此前 skills.sword: 999 会原样落盘');
    });

    test('provider：属性超过上限被截断', () {
      final provider = GameStateProvider();
      final p = provider.applyEffects(
        Player.defaultPlayer(),
        const <String, int>{'attributes.strength': 999},
      );
      expect(p.attributes['strength'], BalanceData.attributeCap);
    });

    test('EventService：技能/属性同样封顶', () {
      const service = EventService();
      final r = service.applyEffects(
        Player.defaultPlayer(),
        choice({'skills.sword': 999, 'attributes.strength': 999}),
      );
      expect(r.newPlayer.skills['sword'], BalanceData.skillCap);
      expect(r.newPlayer.attributes['strength'], BalanceData.attributeCap);
    });

    test('未超上限时行为不变（既有内容零回归）', () {
      final provider = GameStateProvider();
      final base = Player.defaultPlayer();
      final p = provider.applyEffects(
        base,
        const <String, int>{'skills.sword': 2, 'attributes.strength': 1},
      );
      expect(p.skills['sword'], base.skills['sword']! + 2);
      expect(p.attributes['strength'], base.attributes['strength']! + 1);
    });

    test('负值仍钳到 0（下限不回归）', () {
      final provider = GameStateProvider();
      final p = provider.applyEffects(
        Player.defaultPlayer(),
        const <String, int>{'skills.sword': -999, 'attributes.strength': -999},
      );
      expect(p.skills['sword'], 0);
      expect(p.attributes['strength'], 0);
    });

    test('恰好等于上限时不再增长', () {
      final provider = GameStateProvider();
      final capped = Player.defaultPlayer().copyWith(
        skills: const {'sword': BalanceData.skillCap},
        attributes: const {'strength': BalanceData.attributeCap},
      );
      final p = provider.applyEffects(
        capped,
        const <String, int>{'skills.sword': 3, 'attributes.strength': 3},
      );
      expect(p.skills['sword'], BalanceData.skillCap);
      expect(p.attributes['strength'], BalanceData.attributeCap);
    });

    test('上限常量自洽（属性上限与技能上限同刻度）', () {
      expect(BalanceData.skillCap, 10);
      expect(BalanceData.attributeCap, greaterThanOrEqualTo(BalanceData.skillCap),
          reason: '属性初始 5、门槛最高 6，上限不得低于技能上限');
    });

    test('现有全部事件效果值都在上限内（内容零回归）', () {
      for (final e in allEvents) {
        for (final c in e.choices) {
          for (final entry in c.effects.entries) {
            final k = entry.key;
            if (k.startsWith('skills.')) {
              expect(entry.value.abs(), lessThanOrEqualTo(BalanceData.skillCap),
                  reason: '$k=${entry.value} 超出技能上限');
            } else if (k.startsWith('attributes.')) {
              expect(entry.value.abs(),
                  lessThanOrEqualTo(BalanceData.attributeCap),
                  reason: '$k=${entry.value} 超出属性上限');
            }
          }
        }
      }
    });
  });

  // ==================== ㉑ 物品非生存效果 ====================

  group('S13-13 ㉑ useItem 应用全部效果键', () {
    test('多恩红葡萄酒同时给精力与声望', () {
      final e = GameEngine()..startNewGame();
      e.addItem('item_wine');
      e.adjustEnergy(-50);
      final energyBefore = e.player.energy;
      final repBefore = e.player.reputation;

      final text = e.useItem('item_wine');

      expect(text, contains('多恩红葡萄酒'));
      expect(e.player.energy, energyBefore + 15, reason: '精力效果应生效');
      expect(e.player.reputation, repBefore + 1,
          reason: 'item_wine 声明了 reputation: 1，此前被静默丢弃');
      expect(e.itemCount('item_wine'), 0, reason: '使用后应消耗');
    });

    test('物品的生存三维效果仍走 adjustX（保留死亡判定）', () {
      final e = GameEngine()..startNewGame();
      e.addItem('item_bread');
      e.adjustHunger(-50);
      final before = e.player.hunger;
      e.useItem('item_bread');
      expect(e.player.hunger, greaterThan(before));
    });

    test('纯生存物品不受影响（bread 只加饱食）', () {
      final e = GameEngine()..startNewGame();
      e.addItem('item_bread');
      final repBefore = e.player.reputation;
      final goldBefore = e.player.gold;
      e.useItem('item_bread');
      expect(e.player.reputation, repBefore);
      expect(e.player.gold, goldBefore);
    });

    test('全库可用物品的效果键都能被 useItem 消费（无静默丢弃）', () {
      final dropped = <String>[];
      for (final item in kItems.values) {
        if (!item.usable || item.useEffect.isEmpty) continue;
        for (final key in item.useEffect.keys) {
          const consumed = {'health', 'energy', 'hunger'};
          final forwarded = key.startsWith('gold') ||
              key == 'reputation' ||
              key.startsWith('skills.') ||
              key.startsWith('attributes.') ||
              key.startsWith('relations.') ||
              key.startsWith('flags.') ||
              key.startsWith('inventory.');
          if (!consumed.contains(key) && !forwarded) {
            dropped.add('${item.id}/$key');
          }
        }
      }
      expect(dropped, isEmpty,
          reason: '这些键既不被 useItem 消费、也不会转交 applyEffects：$dropped');
    });
  });
}
