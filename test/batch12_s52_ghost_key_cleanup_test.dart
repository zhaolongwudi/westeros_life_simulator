/// S5-2（P1-03 收尾，方案 C）测试：74 处幽灵效果键已彻底清除。
///
/// ## 本批做了什么
///
/// `event_data.dart` 曾有 **74 处引擎不认识的顶层效果键**，分 10 种、涉 39 个事件：
/// `familyRelation 24 / military 12 / political 10 / faith 10 / magic 7 /
/// food 5 / happiness 3 / knowledge 1 / north 1 / allyRelation 1`。
///
/// 采**方案 C（诚实关闭）**：全部删除，并在 `docs/06_事件库.md` 把「事件影响范围」
/// 标注为**未实现的设计稿**。不采接线实现，理由见文件头与 `docs/03-审查接力.md` S5-2 卡片。
///
/// ## 本批最重要的一条认知：**删除是零行为变化**
///
/// 这 74 个键**从未落盘**——两条 `applyEffects` 的兜底分支一律拒收它们。
/// 因此删除前后，玩家的金币/声望/技能/属性/关系/背包**完全一致**，
/// 唯一的差别是结算文本末尾那一行提示消失了：
/// ```
/// 删除前：「…你公开支持合法继承人，赢得贵族尊重。/ 🌟 声望 +5（55）/（其中 1 项效果未生效：political）」
/// 删除后：「…你公开支持合法继承人，赢得贵族尊重。/ 🌟 声望 +5（55）」
/// ```
///
/// **S4-5 把事件选项接入主流程之前**，这些提示行玩家根本看不到（选项不可达）；
/// 之后 **74 / 223 = 33% 的事件选项**都会显示。**本批消除的就是这 33%。**
///
/// ## 与 S5-1 的分工
///
/// S5-1 修的是「**点了完全没反应**的死选项」（`happiness` → `energy`，键名笔误）。
/// S5-2 修的是「**点了有反应、但多一行『未生效』告警**」的混合键。
/// 两者合起来才是 P1-03 的完整形态。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/event_data.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/models/event.dart';
import 'package:westeros_life_simulator/models/player.dart';

/// S5-2 删除的 10 种幽灵键。
const Set<String> kRemovedGhostKeys = <String>{
  'political',
  'faith',
  'military',
  'magic',
  'familyRelation',
  'food',
  'happiness',
  'knowledge',
  'north',
  'allyRelation',
};

/// 引擎真实支持的顶层键与前缀（与两条 applyEffects 的白名单一致）。
const Set<String> kRealTopKeys = <String>{
  'gold',
  'reputation',
  'health',
  'energy',
  'hunger',
  'age',
};

const List<String> kRealPrefixes = <String>[
  'skills.',
  'attributes.',
  'relations.',
  'flags.',
  'inventory.',
];

bool _isReal(String key) =>
    kRealTopKeys.contains(key) || kRealPrefixes.any(key.startsWith);

void main() {
  group('S5-2 · 静态内容零幽灵键', () {
    test('全库 71 个事件 / 223 个选项中，幽灵键恰好 0 处', () {
      final found = <String>[];
      for (final e in allEvents) {
        for (final c in e.choices) {
          for (final k in c.effects.keys) {
            if (!_isReal(k)) found.add('${e.id}/${c.id} → $k');
          }
        }
      }
      expect(found, isEmpty, reason: '幽灵键回潮：\n${found.join('\n')}');
    });

    test('被删的 10 个键名逐个点名，一个都不许再出现', () {
      for (final ghost in kRemovedGhostKeys) {
        final hits = <String>[];
        for (final e in allEvents) {
          for (final c in e.choices) {
            if (c.effects.containsKey(ghost)) hits.add('${e.id}/${c.id}');
          }
        }
        expect(hits, isEmpty, reason: '$ghost 出现在：$hits');
      }
    });

    test('每个非空 effects 都至少含一个引擎真实支持的键', () {
      // 防「清空 effects 伪造通过」：那样幽灵键是没了，但玩家点了没反应，
      // 比原缺陷更糟（S5-1 已为死选项立过同型断言，此处是它的加强版）。
      final bad = <String>[];
      for (final e in allEvents) {
        for (final c in e.choices) {
          if (c.effects.isEmpty) continue;
          if (!c.effects.keys.any(_isReal)) bad.add('${e.id}/${c.id}');
        }
      }
      expect(bad, isEmpty, reason: '这些选项点了完全没反应：$bad');
    });

    test('内容规模未被本批改动（71 事件 / 223 选项 / 39→0 幽灵事件）', () {
      // S5-2 只删效果键条目。若事件数或选项数变了，说明误删了实体。
      expect(allEvents, hasLength(71));
      expect(allEvents.fold<int>(0, (a, e) => a + e.choices.length), 223);
    });
  });

  group('S5-2 · 玩家不再看到「效果未生效」提示行', () {
    /// 满足抽样用到的全部门槛：`event_battle::choice_fight` 要求
    /// `reputation: 55`（S4-3c 把原 `army: 300` 映射而来），
    /// 而 `Player.defaultPlayer()` 的声望只有 **50** ⇒ 直接用默认玩家会被
    /// `canChoose` 拦下、返回「你还不满足…的条件」，断言会假失败。
    /// 此处沿用 S4-5 测试已验证的 `_richPlayer()` 写法。
    Player _richPlayer() => Player.defaultPlayer().copyWith(
          gold: 100,
          reputation: 80,
          age: 30,
          hunger: 60,
          health: 80,
          energy: 80,
        );

    /// 走**完整生产路径**：待决事件 → chooseWorldEventChoice → applyChoice。
    /// 这是 S4-5 之后玩家真实点击的那条链。用 `setPendingEvent` 直接构造
    /// 待决状态，绕开 `_maybeWorldEvent` 的 30% 掷骰（S4-6 两次翻车的教训）。
    String chooseAndSettle(String eventId, String choiceId) {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(_richPlayer());
      final event = allEvents.firstWhere((e) => e.id == eventId);
      final choice = event.choices.firstWhere((c) => c.id == choiceId);
      engine.setPendingEvent(event);
      final text = engine.chooseWorldEventChoice(choice);
      expect(text, isNot(contains('你还不满足')),
          reason: '$eventId/$choiceId 的门槛未被满足，'
              '本用例将测不到「无告警」这个目标。实际返回：$text');
      return text;
    }

    test('event_king_death「支持继承人」不再出现未生效告警', () {
      // 本批修复前的原文（玩家声望 80 → 85）：
      //   「…/ 🌟 声望 +5（85）/（其中 1 项效果未生效：political）」
      final text = chooseAndSettle('event_king_death', 'choice_support_heir');
      expect(text, isNot(contains('未生效')),
          reason: 'political 幽灵键已从数据删除，不该再有告警行。实际输出：\n$text');
      expect(text, isNot(contains('political')),
          reason: '已删除的键名不得泄漏进玩家可见文本：\n$text');
      expect(text, contains('声望'), reason: '真实效果必须照常结算：\n$text');
    });

    test('抽样 6 个曾含幽灵键的选项，全部无告警', () {
      const samples = <List<String>>[
        ['event_king_death', 'choice_support_heir'],
        ['event_family_marriage', 'choice_accept'],
        ['event_battle', 'choice_fight'],
        ['event_heresy', 'choice_purge'],
        ['event_harvest', 'choice_stockpile'],
        ['event_funeral', 'choice_mourn'],
      ];
      for (final s in samples) {
        final text = chooseAndSettle(s[0], s[1]);
        expect(text, isNot(contains('未生效')),
            reason: '${s[0]}/${s[1]} 仍出现告警行：\n$text');
      }
    });

    test('删除是零行为变化：只剩真实键的效果照常落盘', () {
      // 「支持篡位者」删除前是 {reputation:-10, political:15}，
      // political 从未落盘 ⇒ 玩家实际只拿到 reputation -10。
      // 本断言锁住「删除没有顺手改坏真实数值」。
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(_richPlayer());
      final before = engine.player;
      final event = allEvents.firstWhere((e) => e.id == 'event_king_death');
      final choice =
          event.choices.firstWhere((c) => c.id == 'choice_support_usurper');
      expect(choice.effects, {'reputation': -10});

      engine.setPendingEvent(event);
      engine.chooseWorldEventChoice(choice);
      expect(engine.player.reputation, before.reputation - 10);
      expect(engine.lastRejectedEffectKeys, isEmpty);
    });

    test('「保持中立」类选项保留零值真实键（与既有数据风格一致）', () {
      // event_king_death 的「保持中立」删除前是 {reputation:0, political:0}，
      // 现为 {reputation:0}。**刻意不清空**：清空会把 7 个「转身离开」型选项
      // 之外的第 8 个零收益选项塞进另一类语义，而项目既有数据里
      // event_free_cities_war 的「保持中立」本就是 {gold:0, reputation:0}。
      final event =
          allEvents.firstWhere((e) => e.id == 'event_king_death');
      final choice =
          event.choices.firstWhere((c) => c.id == 'choice_neutral');
      expect(choice.effects, {'reputation': 0});
    });
  });

  group('S5-2 · 拒收机制本身必须保留（AI 仍会造键）', () {
    test('AI 通道对未知键仍拒收并可见', () {
      // 静态内容清理干净**不等于**可以拆守卫：AI 选项是运行时现场生成的，
      // 随时可能再次吐出 political 之类的不存在键。没有守卫就会退回
      // Batch 10-101 之前的「静默丢弃」。
      final engine = GameEngine()..startNewGame();
      final text = engine.applyAiChoice(const EventChoice(
        id: 'choice_ai_probe',
        text: '支持继承人',
        requirements: <String, int>{},
        effects: <String, int>{'reputation': 5, 'political': 10},
        narrative: '你公开表态支持继承人。',
      ));
      expect(text, contains('1 项效果未生效'));
      expect(text, contains('political'));
      expect(engine.lastRejectedEffectKeys, contains('political'));
    });

    test('事件通道对未知键同样拒收并可见', () {
      final engine = GameEngine()..startNewGame();
      engine.setCurrentEvent(allEvents.first);
      final text = engine.applyChoice(const EventChoice(
        id: 'choice_event_probe',
        text: '支持继承人',
        requirements: <String, int>{},
        effects: <String, int>{'reputation': 5, 'political': 10},
        narrative: '你公开表态支持继承人。',
      ));
      expect(text, contains('1 项效果未生效'));
    });
  });
}
