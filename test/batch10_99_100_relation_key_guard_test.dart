/// Batch 10-99/100 测试：`relations.` 效果键写侧守卫 + 玩家面板关系区中文名。
///
/// 【10-99 取证：五类效果键里最后一个没设防的是 `relations.`】
/// 效果落盘轴（10-89~98）给 `inventory.`/`skills.`/`attributes.`/
/// `flags.` 都补了写侧守卫，**唯独 `relations.` 只在 10-89 改过
/// prompt 示例文案**（`relations.tyrion` → `relations.npc_tyrion`），
/// 写侧**从未校验 npc id 是否真实存在**。取证（一次性脚本，剥注释行
/// 后按正则扫描，坑 52）：
///  - `npc_data` 全量 **38 个 id 全部带 `npc_` 前缀**，无一例外；
///  - `event_data` 的 `relations.` 效果键/门槛键经 10-96 清理后已 **归零**，
///    故本批守卫对内容数据**零回归风险**；
///  - 而 AI 只要写 `relations.tyrion`，好感度就落进一个永不存在的槽位，
///    后果三重：
///    ① `ai_service` 关系段的 `n == null` 兜底把 `tyrion: 15` 原样打进
///       prompt（AI 看着像真的，继续基于幻影叙事）；
///    ② `player_panel_screen` 遍历 `relations.entries` 让玩家面板出现
///       名为 `tyrion` 的条目；
///    ③ 幽灵键按 `|值|` 参与 10-83 关系段预算排序（预算 8），**白占预算位**
///       把真实关系挤出窗口。
///
/// 【修法：查 `allNpcs` 而非静态白名单】
/// `isNpcIdValid` 走 `npc_data.npcById`（本文件唯一真相），与 10-91 的
/// `itemById` 守卫同构。**刻意不写成静态键集**——NPC 有 38 个且随批次
/// 持续扩充（10-54/61 都加过 NPC），静态白名单必须靠测试逐条比对防漂移。
/// 好处：新增 NPC 自动生效，无需改任何白名单。
///
/// 【10-100：玩家面板关系区泄漏英文 id】
/// 关系区此前直接 `_Entry(e.key, ...)`，把 `npc_tyrion` 当标题显示——
/// 与 10-87 背包段、10-93 效果摘要「一律走中文名」的口径相反，是全项目
/// 泄漏英文 id 的最后一处。改为 `_relationName(e)` 查中文名。
/// 【为什么仍要改而非只靠 10-99】旧存档里已积累的幽灵键不会再新增，
/// 但**仍会继续显示**（存档兼容不做破坏性清洗），故未知 id 回退原 id。
///
/// 【两条既有测试被本批改动波及（键改为真实 id，原意保留）】
///  - `batch3_event_service_test`「applyEffects 关系效果」原用 `npc_1`
///    （虚构 id）→ 改 `npc_tyrion`；
///  - `batch9_ai_deep_test`「关系效果键 relations.<npc> 增减好感」原用
///    `tyrion`/`jon`（**正是本批要治的幽灵键**）→ 改 `npc_tyrion`/
///    `npc_jon_snow`。
///
/// 【断言写法提醒】
///  - 中文锚点照抄实际输出的全角标点（坑 51）；
///  - `applyEffects` 是纯函数，返回新 Player **不落盘** provider（坑 53），
///    断言落盘结果必须接返回值。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/event_data.dart';
import 'package:westeros_life_simulator/data/item_data.dart';
import 'package:westeros_life_simulator/data/npc_data.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/models/event.dart';
import 'package:westeros_life_simulator/models/player.dart';
import 'package:westeros_life_simulator/providers/game_state_provider.dart';
import 'package:westeros_life_simulator/screens/player_panel_screen.dart';
import 'package:westeros_life_simulator/services/event_service.dart';

/// 构造一个 AI 选项。
EventChoice _aiChoice(Map<String, int> effects, {String narrative = ''}) {
  return EventChoice(
    id: 'c',
    text: '测试行动',
    requirements: const <String, int>{},
    effects: effects,
    narrative: narrative,
  );
}

/// 挂载玩家面板（沿用 `batch10_19_panel_ai_test` 的注入引擎写法，
/// 避免无参构造新建引擎把传入玩家数据重置，坑 23）。
///
/// 【为什么要设 1080x4000 高视口】面板是 `ListView`（惰性构建），关系区
/// 排在属性/技能/装备之后，**默认测试视口下根本没被 build**，断言
/// `find.text` 必然 0 命中。既有 `batch10_19_panel_ai_test`（1080x4000）
/// 与 `m5_responsive_test`（1200x2000）都显式设高视口，本组沿用同一写法。
Widget _wrap(GameEngine engine) =>
    MaterialApp(home: PlayerPanelScreen(engine: engine));

/// 撑高视口，让惰性 ListView 把关系区构建出来。
void _tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  group('Batch 10-99 relations. 键守卫 · 单一真相', () {
    test('isNpcIdValid：真实 id 全部合法', () {
      for (final n in allNpcs) {
        expect(isNpcIdValid(n.id), isTrue, reason: '${n.id} 应合法');
      }
    });

    test('isNpcIdValid：幽灵 id 全部非法', () {
      // 含 10-89 prompt 侧的旧幽灵键、10-96 已删的四个内容侧幽灵键，
      // 以及「漏掉 npc_ 前缀」这一 AI 最常见的自造形态。
      for (final ghost in const [
        'tyrion',
        'jon',
        'npc_1',
        'lord',
        'family_head',
        'merchant_leader',
        'castle_black',
        '',
      ]) {
        expect(isNpcIdValid(ghost), isFalse, reason: '$ghost 应非法');
      }
    });

    test('守卫与 allNpcs 零漂移（每条守卫都恰是「非全集成员」）', () {
      final ids = allNpcs.map((n) => n.id).toSet();
      expect(ids.length, allNpcs.length, reason: 'id 应唯一');
      // 反向：不存在「全集里的 id 被判非法」
      for (final id in ids) {
        expect(isNpcIdValid(id), isTrue);
      }
    });

    test('全量 72 事件的 relations. 效果键零幽灵（守卫漏一个即静默失效）', () {
      final ids = allNpcs.map((n) => n.id).toSet();
      final ghosts = <String>{};
      for (final e in allEvents) {
        for (final c in e.choices) {
          for (final k in c.effects.keys) {
            if (!k.startsWith('relations.')) continue;
            final id = k.substring(10);
            if (!ids.contains(id)) ghosts.add(k);
          }
        }
      }
      expect(ghosts, isEmpty, reason: '内容数据残留幽灵关系键：$ghosts');
    });
  });

  group('Batch 10-99 provider 通道（AI 选项）', () {
    test('真实 id 正常落盘', () {
      final provider = GameStateProvider();
      final out = provider.applyEffects(
        provider.player,
        const <String, int>{'relations.npc_tyrion': 15},
      );
      expect(out.relations['npc_tyrion'], 15);
    });

    test('幽灵 id 被拒且不进 relations map', () {
      final provider = GameStateProvider();
      final out = provider.applyEffects(
        provider.player,
        const <String, int>{'relations.tyrion': 15},
      );
      expect(out.relations.containsKey('tyrion'), isFalse);
    });

    test('幽灵 id 被登记进 lastRejectedEffectKeys（供 10-94 提示行）', () {
      final provider = GameStateProvider();
      provider.applyEffects(
        provider.player,
        const <String, int>{'relations.tyrion': 15},
      );
      expect(provider.lastRejectedEffectKeys, contains('relations.tyrion'));
    });

    test('合法键与幽灵键混合：幽灵被拒、合法照常落盘', () {
      final provider = GameStateProvider();
      final out = provider.applyEffects(
        provider.player,
        const <String, int>{
          'relations.npc_tyrion': 10,
          'relations.tyrion': 99,
        },
      );
      expect(out.relations['npc_tyrion'], 10);
      expect(out.relations.containsKey('tyrion'), isFalse);
      expect(provider.lastRejectedEffectKeys, <String>['relations.tyrion']);
    });

    test('每次调用入口清空拒绝记录（不跨回合残留）', () {
      final provider = GameStateProvider();
      provider.applyEffects(
        provider.player,
        const <String, int>{'relations.tyrion': 15},
      );
      expect(provider.lastRejectedEffectKeys, isNotEmpty);
      provider.applyEffects(
        provider.player,
        const <String, int>{'relations.npc_tyrion': 5},
      );
      expect(provider.lastRejectedEffectKeys, isEmpty);
    });

    test('裸前缀 relations.（无 npcId）被拒', () {
      final provider = GameStateProvider();
      final out = provider.applyEffects(
        provider.player,
        const <String, int>{'relations.': 10},
      );
      expect(out.relations.containsKey(''), isFalse);
      expect(provider.lastRejectedEffectKeys, contains('relations.'));
    });

    test('合法键仍受 ±100 钳制（10-90 护栏未被本批破坏）', () {
      final provider = GameStateProvider();
      final out = provider.applyEffects(
        provider.player,
        const <String, int>{'relations.npc_tyrion': 9999},
      );
      expect(out.relations['npc_tyrion'], 100);
    });
  });

  group('Batch 10-99 event_service 通道（事件选项）', () {
    test('真实 id 进 appliedEffects', () {
      final choice = _aiChoice(const <String, int>{
        'relations.npc_tyrion': 10,
      });
      final res = const EventService()
          .applyEffects(Player.defaultPlayer(), choice);
      expect(res.appliedEffects.containsKey('relations.npc_tyrion'), isTrue);
      expect(res.failedEffects.containsKey('relations.npc_tyrion'), isFalse);
      expect(res.newPlayer.relations['npc_tyrion'], 10);
    });

    test('幽灵 id 进 failedEffects（该通道的可报告语义）', () {
      final choice = _aiChoice(const <String, int>{'relations.tyrion': 10});
      final res = const EventService()
          .applyEffects(Player.defaultPlayer(), choice);
      expect(res.failedEffects.containsKey('relations.tyrion'), isTrue);
      expect(res.appliedEffects.containsKey('relations.tyrion'), isFalse);
      expect(res.newPlayer.relations.containsKey('tyrion'), isFalse);
    });

    test('两条通道对同一幽灵键判定一致（防漂移）', () {
      const ghost = 'relations.lord';
      final provider = GameStateProvider();
      provider.applyEffects(
        provider.player,
        const <String, int>{ghost: 10},
      );
      expect(provider.lastRejectedEffectKeys, contains(ghost));

      final res = const EventService().applyEffects(
        Player.defaultPlayer(),
        _aiChoice(const <String, int>{ghost: 10}),
      );
      expect(res.failedEffects.containsKey(ghost), isTrue);
    });

    test('全量 38 个 NPC id 经事件通道均可落盘（守卫零误伤）', () {
      final effects = <String, int>{
        for (final n in allNpcs) 'relations.${n.id}': 1,
      };
      final choice = _aiChoice(effects);
      final res = const EventService()
          .applyEffects(Player.defaultPlayer(), choice);
      expect(res.failedEffects, isEmpty);
      expect(res.newPlayer.relations.length, allNpcs.length);
    });
  });

  group('Batch 10-99 端到端：applyAiChoice 提示行', () {
    test('AI 写幽灵关系键 → 回合文本提示未生效，且无 🤝 摘要行', () {
      final engine = GameEngine()..startNewGame();
      final result = engine.applyAiChoice(_aiChoice(
        <String, int>{'relations.tyrion': 10},
      ));
      // 10-94 的提示行列出被拒键
      expect(result, contains('未生效'));
      expect(result, contains('relations.tyrion'));
      // 幽灵键不落盘 → 不应产生任何关系 delta 摘要行
      expect(result, isNot(contains('🤝')));
    });

    test('AI 写真实关系键 → 出中文名摘要行且无未生效提示', () {
      final engine = GameEngine()..startNewGame();
      final result = engine.applyAiChoice(_aiChoice(
        <String, int>{'relations.npc_tyrion': 10},
      ));
      expect(result, contains('🤝 提利昂·兰尼斯特 +10（10）'));
      expect(result, isNot(contains('未生效')));
    });

    test('幽灵键不泄漏进关系段（prompt 只留真实关系）', () async {
      // 旧档已积累幽灵键时，prompt 关系段会走 `n == null` 兜底把它原样
      // 打出来。本批守卫只管「新写入」，本条断言锁住「真实关系仍正确注入」，
      // 避免误以为守卫顺带清理了 prompt 侧。
      final engine = GameEngine()..startNewGame();
      engine.applyAiChoice(_aiChoice(
        <String, int>{'relations.npc_tyrion': 20},
      ));
      expect(engine.player.relations.containsKey('tyrion'), isFalse);
    });
  });

  group('Batch 10-100 玩家面板关系区中文名', () {
    testWidgets('真实 NPC id 渲染中文名，不显示裸英文 id', (tester) async {
      _tallView(tester);
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.applyEffects(
          engine.player,
          const <String, int>{'relations.npc_tyrion': 30},
        ),
      );
      await tester.pumpWidget(_wrap(engine));
      await tester.pumpAndSettle();
      expect(find.text('提利昂·兰尼斯特'), findsWidgets);
      expect(find.text('npc_tyrion'), findsNothing);
    });

    testWidgets('旧档幽灵键回退显示原 id（不空白、不抛错）', (tester) async {
      _tallView(tester);
      final engine = GameEngine()..startNewGame();
      // 直接构造玩家绕过写侧守卫，模拟「10-99 之前已积累幽灵键的旧存档」
      engine.updatePlayer(
        engine.player.copyWith(
          relations: <String, int>{'tyrion': 15},
        ),
      );
      await tester.pumpWidget(_wrap(engine));
      await tester.pumpAndSettle();
      expect(find.text('tyrion'), findsWidgets);
    });
  });

  group('Batch 10-99/100 物品守卫未被破坏（10-91 回归抽检）', () {
    test('合法物品 id 落盘', () {
      final provider = GameStateProvider();
      final out = provider.applyEffects(
        provider.player,
        const <String, int>{'inventory.item_bread': 2},
      );
      expect(out.inventory.where((e) => e == 'item_bread').length, 2);
    });

    test('幽灵物品 id 仍被拒', () {
      final provider = GameStateProvider();
      final out = provider.applyEffects(
        provider.player,
        const <String, int>{'inventory.dragon_scale': 3},
      );
      expect(out.inventory.contains('dragon_scale'), isFalse);
      expect(provider.lastRejectedEffectKeys, contains('inventory.dragon_scale'));
    });

    test('全库物品 id 数取证（33 种，10-91 记录值，防数据层意外变动）', () {
      expect(kItems.length, 33);
    });
  });
}