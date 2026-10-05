/// Batch 10-97 效果落盘轴收官 · `flags.` 状态标记键分层白名单
///
/// **本批定位**：10-89 治了 `relations.`（id 契约），10-91/92 治了
/// `inventory.`/`skills.`/`attributes.`，到本批为止 **`flags.` 是五类
/// 效果键里唯一完全不校验键名的一类** —— AI 选项与事件效果都可以
/// 新增任意标记，且只增不减。
///
/// **为什么纯白名单不可行（取证结论，与旧盘点不同）**
/// `flags.` 与其他四类的本质差异：存在**引擎运行时拼出的合法动态键**，
/// 键名含 NPC id / 物品 id / 中文人名，无法静态枚举。一次性脚本
/// （`scripts/_probe_flags.py` 系列）全量盘点后的真实分层是：
///  - **静态白名单 26 个** = 内容事件字面量键 17 个（`event_data.dart`
///    的 21 个 `flags.` 键里有 4 个是 `equipped.<物品 id>` 动态键，
///    已归入下方前缀集）+ 引擎系统键 9 个（`isAlive`/`isInjured`/
///    `negotiated`/`isMarried`/`divorceYear`/`widowed`/`isExiled`/
///    `generation`/`inherited`）；
///  - **受限动态前缀 5 个** = `equipped.`（装备槽位）/
///    `house.childDead.`（已故子女）/ `npc_task.`（已接任务）/
///    `npc_task_done.`（已完成任务）/ `npc_story.`（已触发人物故事）。
///    **注意 `npc_story.` 与 `npc_task.` 是本轮新发现的**——10-95/96 的
///    旧盘点只记了 3 个前缀，漏了 `mixin_npc_interact:203`（人物故事）
///    与 `:250`（接任务）两处，若按旧盘点实现会把这两条内容数据拒收。
///  - **刻意不开 `house.childExiled.`**：该前缀全库只有读取
///    （`mixin_generation:58`）没有写入，放行等于让 AI 有能力把家谱
///    继承人从候选中剔除，而这条语义从未接线。
///
/// **零回归依据（脚本实证，非凭印象）**
/// ① 全量 72 个事件的 `flags.` 效果键与门槛键全部通过分层校验；
/// ② 既有测试依赖的 `flags.isMarried`（`batch3_event_service_test`）、
///    `flags.isAlive: 0`（`batch9_ai_deep_test`）、`flags.honor_pledge`
///    （`batch9_ai_deep_test` / `batch10_12_narrative_ui_test`）、
///    `flags.sworn_brother`（`batch10_95_96`）、
///    `flags.hasBlessing`（`batch10_2_survival_events_test`）全部仍在
///    合法集内 —— 这几条是本批最容易踩的回归点（系统键与事件键混在一起，
///    只按「事件 17 键」建白名单会让 `flags.isMarried` 被拒、
///    `formatFamilyTree` 的婚姻显示恒为「未婚」）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/balance_data.dart';
import 'package:westeros_life_simulator/data/event_data.dart';
import 'package:westeros_life_simulator/data/item_data.dart';
import 'package:westeros_life_simulator/models/event.dart';
import 'package:westeros_life_simulator/models/player.dart';
import 'package:westeros_life_simulator/providers/game_state_provider.dart';
import 'package:westeros_life_simulator/services/event_service.dart';

void main() {
  const service = EventService();

  EventChoice choice(Map<String, int> effects) => EventChoice(
        id: 'c1',
        text: '测试',
        requirements: const {},
        effects: effects,
        narrative: '测试',
      );

  // ==================== 10-97 A. 白名单本身 ====================
  group('10-97 flags 分层白名单 · 静态键集', () {
    test('静态键集恰为 26 个', () {
      expect(BalanceData.kPlayerFlagKeys.length, 26);
    });

    test('内容事件的 17 个字面量键全部在集内', () {
      for (final k in const [
        'honor_pledge',
        'hasShelter',
        'hasDirewolf',
        'hasBlessing',
        'hasVision',
        'hasCandleVision',
        'hasCometRecord',
        'hasWarned',
        'hasFrozenVision',
        'guild_ally',
        'guild_secret',
        'guild_enemy',
        'sworn_brother',
        'watch_friend',
        'market_hero',
        'market_intel',
        'lord_favor',
      ]) {
        expect(BalanceData.kPlayerFlagKeys.contains(k), isTrue,
            reason: '内容事件键 $k 缺失会让该事件效果静默失效');
      }
    });

    test('引擎系统键 9 个全部在集内（漏一个就静默失真）', () {
      for (final k in const [
        'isAlive',
        'isInjured',
        'negotiated',
        'isMarried',
        'divorceYear',
        'widowed',
        'isExiled',
        'generation',
        'inherited',
      ]) {
        expect(BalanceData.kPlayerFlagKeys.contains(k), isTrue,
            reason: '系统键 $k 缺失会让死亡判定/世代数/婚姻显示静默失真');
      }
    });

    test('两类键数之和等于总键数（17 内容 + 9 系统 = 26）', () {
      // 拆账护栏：文档/注释里「17 内容 + 9 系统」的计数必须与白名单
      // 实际内容一致，否则后人加键时会漏同步 length 断言。
      const contentKeys = {
        'honor_pledge',
        'hasShelter',
        'hasDirewolf',
        'hasBlessing',
        'hasVision',
        'hasCandleVision',
        'hasCometRecord',
        'hasWarned',
        'hasFrozenVision',
        'guild_ally',
        'guild_secret',
        'guild_enemy',
        'sworn_brother',
        'watch_friend',
        'market_hero',
        'market_intel',
        'lord_favor',
      };
      expect(contentKeys.length, 17);
      expect(BalanceData.kPlayerFlagKeys.length - contentKeys.length, 9,
          reason: '系统键应为 9 个（isAlive/isInjured/negotiated/isMarried/'
              'divorceYear/widowed/isExiled/generation/inherited）');
      for (final k in contentKeys) {
        expect(BalanceData.kPlayerFlagKeys.contains(k), isTrue);
      }
    });
  });

  group('10-97 flags 分层白名单 · 动态前缀', () {
    test('动态前缀恰为 5 个', () {
      expect(BalanceData.kPlayerFlagPrefixes.length, 5);
    });

    test('5 个前缀齐备（含 10-95/96 旧盘点遗漏的 npc_story./npc_task.）', () {
      for (final p in const [
        'equipped.',
        'house.childDead.',
        'npc_task.',
        'npc_task_done.',
        'npc_story.',
      ]) {
        expect(BalanceData.kPlayerFlagPrefixes.contains(p), isTrue,
            reason: '前缀 $p 缺失会拒收合法内容数据');
      }
    });

    test('house.childExiled. 刻意不开（只有读取没有写入的预留键）', () {
      expect(BalanceData.kPlayerFlagPrefixes.contains('house.childExiled.'),
          isFalse,
          reason: '放行等于让 AI 有能力把家谱继承人从候选中剔除');
    });

    test('前缀判定覆盖真实运行时键形态', () {
      const valid = [
        'equipped.item_sword',
        'house.childDead.罗柏',
        'npc_task.npc_edd.护送北境信使至君临',
        'npc_task_done.npc_edd.护送北境信使至君临',
        'npc_story.npc_catelyn.信任',
      ];
      for (final k in valid) {
        expect(BalanceData.isPlayerFlagKeyValid(k), isTrue,
            reason: '$k 是引擎真实写入的键，不该被拒');
      }
    });
  });

  group('10-97 flags 分层白名单 · 判定函数', () {
    test('静态键命中', () {
      expect(BalanceData.isPlayerFlagKeyValid('honor_pledge'), isTrue);
      expect(BalanceData.isPlayerFlagKeyValid('isAlive'), isTrue);
    });

    test('幽灵键拒收（AI 自造的三类典型）', () {
      for (final k in const ['hacking', '剑术', 'hasDragon', 'sworn_brothers']) {
        expect(BalanceData.isPlayerFlagKeyValid(k), isFalse,
            reason: '幽灵键 $k 会泄漏进玩家面板「状态标记」区块');
      }
    });

    test('空串与纯前缀拒收（`equipped.` 无物品 id 不是合法键）', () {
      expect(BalanceData.isPlayerFlagKeyValid(''), isFalse);
      expect(BalanceData.isPlayerFlagKeyValid('equipped.'), isFalse);
    });

    test('前缀与静态集互不污染（equipped.item_sword 不在静态集里）', () {
      expect(BalanceData.kPlayerFlagKeys.contains('equipped.item_sword'), isFalse);
      expect(BalanceData.isPlayerFlagKeyValid('equipped.item_sword'), isTrue);
    });

    test('静态键与前缀无交集（避免同一键两处维护）', () {
      for (final k in BalanceData.kPlayerFlagKeys) {
        for (final p in BalanceData.kPlayerFlagPrefixes) {
          expect(k.startsWith(p), isFalse,
              reason: '$k 同时命中静态集与前缀 $p');
        }
      }
    });
  });

  // ==================== 10-97 B. 内容零回归 ====================
  group('10-97 全量事件 flags 键零回归', () {
    test('全部事件的 flags. 效果键都通过分层校验', () {
      final bad = <String>[];
      for (final e in allEvents) {
        for (final c in e.choices) {
          for (final k in c.effects.keys) {
            if (!k.startsWith('flags.')) continue;
            if (!BalanceData.isPlayerFlagKeyValid(k.substring(6))) {
              bad.add('${e.id}/$k');
            }
          }
        }
      }
      expect(bad, isEmpty,
          reason: '白名单漏一个真实键，该事件选项点了什么也不会发生：$bad');
    });

    test('全部事件的 flags. 门槛键都通过分层校验', () {
      final bad = <String>[];
      for (final e in allEvents) {
        for (final c in e.choices) {
          for (final k in c.requirements.keys) {
            if (!k.startsWith('flags.')) continue;
            if (!BalanceData.isPlayerFlagKeyValid(k.substring(6))) {
              bad.add('${e.id}/$k');
            }
          }
        }
      }
      expect(bad, isEmpty,
          reason: '门槛键被拒会让事件恒不可选或恒可选：$bad');
    });

    test('守夜人事件的 flags.sworn_brother 效果仍落盘', () {
      final e = allEvents.firstWhere((x) => x.name == '守夜人的邀请');
      final c = e.choices.firstWhere((x) => x.id == 'choice_join_watch');
      final r = service.applyEffects(Player.defaultPlayer(), choice(c.effects));
      expect(r.newPlayer.flags['sworn_brother'], isTrue);
      expect(r.failedEffects.containsKey('flags.sworn_brother'), isFalse);
    });

    test('装备类事件（flags.equipped.<物品 id>）仍落盘', () {
      final e = allEvents.firstWhere((x) =>
          x.choices.any((c) => c.effects.containsKey('flags.equipped.item_sword')));
      final c = e.choices.firstWhere(
          (x) => x.effects.containsKey('flags.equipped.item_sword'));
      final r = service.applyEffects(Player.defaultPlayer(), choice(c.effects));
      expect(r.newPlayer.flags['equipped.item_sword'], isTrue);
      expect(r.failedEffects.containsKey('flags.equipped.item_sword'), isFalse);
    });
  });

  // ==================== 10-97 C. 两条通道行为 ====================
  group('10-97 event_service 通道（拒收进 failedEffects）', () {
    test('合法静态键落盘', () {
      final r = service.applyEffects(
          Player.defaultPlayer(), choice({'flags.honor_pledge': 1}));
      expect(r.newPlayer.flags['honor_pledge'], isTrue);
      expect(r.appliedEffects.containsKey('flags.honor_pledge'), isTrue);
    });

    test('合法动态键（已接任务）落盘', () {
      final r = service.applyEffects(
          Player.defaultPlayer(), choice({'flags.npc_task.npc_edd.X': 1}));
      expect(r.newPlayer.flags['npc_task.npc_edd.X'], isTrue);
    });

    test('幽灵键不落盘且登记进 failedEffects', () {
      final r = service
          .applyEffects(Player.defaultPlayer(), choice({'flags.hacking': 1}));
      expect(r.newPlayer.flags.containsKey('hacking'), isFalse);
      expect(r.failedEffects.containsKey('flags.hacking'), isTrue);
      expect(r.appliedEffects.containsKey('flags.hacking'), isFalse);
    });

    test('同选项内合法键与幽灵键互不影响', () {
      final r = service.applyEffects(Player.defaultPlayer(), choice({
        'flags.honor_pledge': 1,
        'flags.hacking': 1,
        'gold': 10,
      }));
      expect(r.newPlayer.flags['honor_pledge'], isTrue);
      expect(r.newPlayer.flags.containsKey('hacking'), isFalse);
      expect(r.newPlayer.gold, Player.defaultPlayer().gold + 10);
      expect(r.failedEffects.keys, ['flags.hacking']);
    });

    test('清除语义不变：合法键传 0 置假', () {
      final p = Player.defaultPlayer().copyWith(
        flags: <String, bool>{
          ...Player.defaultPlayer().flags,
          'honor_pledge': true
        },
      );
      final r = service.applyEffects(p, choice({'flags.honor_pledge': 0}));
      expect(r.newPlayer.flags['honor_pledge'], isFalse);
    });

    test('isMarried 系统键不回归（batch3 既有用例的键）', () {
      final r = service.applyEffects(
          Player.defaultPlayer(), choice({'flags.isMarried': 1}));
      expect(r.newPlayer.flags['isMarried'], isTrue);
      expect(r.failedEffects.containsKey('flags.isMarried'), isFalse);
    });

    test('isAlive 传 0 清除不回归（batch9 既有用例的键）', () {
      final p = Player.defaultPlayer().copyWith(
        flags: <String, bool>{
          ...Player.defaultPlayer().flags,
          'isAlive': true
        },
      );
      final r = service.applyEffects(p, choice({'flags.isAlive': 0}));
      expect(r.newPlayer.flags['isAlive'], isFalse);
      expect(r.failedEffects.containsKey('flags.isAlive'), isFalse);
    });
  });

  group('10-97 GameStateProvider 通道（拒收进 lastRejectedEffectKeys）', () {
    test('合法静态键落盘', () {
      final provider = GameStateProvider();
      final p = provider.applyEffects(
          provider.player, const <String, int>{'flags.honor_pledge': 1});
      expect(p.flags['honor_pledge'], isTrue);
      expect(provider.lastRejectedEffectKeys, isEmpty);
    });

    test('合法动态键落盘', () {
      final provider = GameStateProvider();
      final p = provider.applyEffects(provider.player,
          const <String, int>{'flags.equipped.item_sword': 1});
      expect(p.flags['equipped.item_sword'], isTrue);
    });

    test('幽灵键不落盘且登记进 lastRejectedEffectKeys', () {
      final provider = GameStateProvider();
      final p = provider.applyEffects(
          provider.player, const <String, int>{'flags.hacking': 1});
      expect(p.flags.containsKey('hacking'), isFalse);
      expect(provider.lastRejectedEffectKeys, ['flags.hacking']);
    });

    test('拒收记录每次调用入口清空（不跨回合残留）', () {
      final provider = GameStateProvider();
      provider.applyEffects(
          provider.player, const <String, int>{'flags.hacking': 1});
      expect(provider.lastRejectedEffectKeys, isNotEmpty);
      provider.applyEffects(
          provider.player, const <String, int>{'flags.honor_pledge': 1});
      expect(provider.lastRejectedEffectKeys, isEmpty);
    });

    test('同选项内合法键与幽灵键互不影响', () {
      final provider = GameStateProvider();
      final p = provider.applyEffects(provider.player, const <String, int>{
        'flags.honor_pledge': 1,
        'flags.剑术': 1,
      });
      expect(p.flags['honor_pledge'], isTrue);
      expect(p.flags.containsKey('剑术'), isFalse);
      expect(provider.lastRejectedEffectKeys, ['flags.剑术']);
    });

    test('两条通道对同一幽灵键的判定一致（防漂移）', () {
      const ghost = 'flags.dragon_slayer';
      final r1 = service.applyEffects(Player.defaultPlayer(), choice({ghost: 1}));
      final provider = GameStateProvider();
      final p1 = provider.applyEffects(provider.player, const <String, int>{ghost: 1});
      expect(r1.newPlayer.flags.containsKey('dragon_slayer'), isFalse);
      expect(p1.flags.containsKey('dragon_slayer'), isFalse);
      expect(r1.failedEffects.containsKey(ghost), isTrue);
      expect(provider.lastRejectedEffectKeys, [ghost]);
    });

    test('两条通道对同一合法键的落盘结果一致（防漂移）', () {
      const ok = 'flags.market_intel';
      final r1 = service.applyEffects(Player.defaultPlayer(), choice({ok: 1}));
      final provider = GameStateProvider();
      final p1 = provider.applyEffects(provider.player, const <String, int>{ok: 1});
      expect(r1.newPlayer.flags['market_intel'], isTrue);
      expect(p1.flags['market_intel'], isTrue);
      expect(r1.failedEffects.containsKey(ok), isFalse);
      expect(provider.lastRejectedEffectKeys, isEmpty);
    });
  });

  // ==================== 10-97 D. equipped.* 与物品 id 的口径 ====================
  group('10-97 equipped.* 前缀与物品 id 的口径', () {
    test('全部物品 id 拼出的 equipped.<id> 都是合法键', () {
      final bad = <String>[];
      for (final item in allItems) {
        final key = 'equipped.${item.id}';
        if (!BalanceData.isPlayerFlagKeyValid(key)) bad.add(key);
      }
      expect(bad, isEmpty,
          reason: '装备槽位键被拒会让穿脱装备后战斗值与 AI 装备段全部失真：$bad');
    });

    test('equipped.<不存在的物品 id> 仍判合法（刻意口径声明）', () {
      // 这一条是**刻意的口径**，不是漏洞：装备槽位键由 mixin_life 在
      // 穿脱时写入，写入方已保证 id 真实；AI 选项写
      // `flags.equipped.item_not_exist` 会留下一条无用槽位，但它不污染
      // 任何读取逻辑（ai_service 与 combatPower 都走 itemById 解析 +
      // 未知回退）。收紧到「还要过 itemById」会与 inventory. 的守卫
      // 重复，且 mixin_life.unequip 的 `setFlag('equipped.$eid', false)`
      // 清理路径会因 id 不在背包而失效。
      expect(BalanceData.isPlayerFlagKeyValid('equipped.item_not_exist'), isTrue);
    });
  });
}