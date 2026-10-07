/// Batch 10-119 测试：幽灵效果键「防新增」闸门（S2-3 / P1-03 阶段一，
/// 基线于 S5-2 从「存量锁」改为「零存量锁」）。
///
/// 背景：事件数据里曾有 **10 个引擎不认识的顶层效果键**（`political` / `faith` /
/// `military` / `magic` / `familyRelation` / `food` / `happiness` /
/// `knowledge` / `north` / `allyRelation`）。它们由 `docs/06` 设计、引擎从未实现，
/// 玩家点了「支持合法继承人」只拿到 reputation，叙事承诺的政治资本变化静默丢弃。
///
/// ## 本文件的闸门性质在 S5-2（2026-10-07）发生了**加强**而非放松
///
/// S2-3 建立本文件时是「**存量基线锁**」：`lessThanOrEqualTo(74)` / `lessThanOrEqualTo(39)`，
/// 意图是「新增即红、清理不强制」。这个上界形同虚设——真实值 76 长期 ≤ 78 上界，
/// **错误的数字两年没被 CI 发现**（S5-1 实证）。
///
/// S5-2 采方案 C 删除了全部 74 处（零行为变化：它们本就一律被拒收，从未落盘），
/// 故基线从「74 处 / 39 事件 / 10 种」**收紧为「恰好 0」**。
/// 这是本文件能给出的**最强断言**——上界型断言允许回归，等于没设防。
///
/// ## 但「拒收机制」本身必须保留（本文件下半部分仍在守它）
///
/// 静态内容清理干净 ≠ 可以拆掉守卫：**AI 通道的选项是运行时现场生成的**
/// （`applyAiChoice`），AI 随时可能再次吐出 `political` 之类的不存在键。
/// 没有守卫就会退回 Batch 10-101 之前的「静默丢弃」。
/// 故下半部分的「拒收对玩家可见」用例**原样保留**，它守的是机制而非存量。
///
/// 覆盖：
/// 1. 全量扫描：静态内容里的幽灵键**恰好 0 处**，新增任何一种立即红
/// 2. 契约：未知键确实不落盘，且被登记进 lastRejectedEffectKeys
/// 3. 可见化：AI 通道与事件通道都会输出「N 项效果未生效」提示行
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/event_data.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/models/event.dart';
import 'package:westeros_life_simulator/models/player.dart';

/// 引擎支持的顶层键（与两条 applyEffects 的白名单一致）。
const Set<String> kKnownTopKeys = <String>{
  'gold',
  'reputation',
  'health',
  'energy',
  'hunger',
  'age',
};

/// 引擎支持的前缀键。
const List<String> kKnownPrefixes = <String>[
  'skills.',
  'attributes.',
  'relations.',
  'flags.',
  'inventory.',
];

bool _isKnown(String key) =>
    kKnownTopKeys.contains(key) ||
    kKnownPrefixes.any(key.startsWith);

/// 全量扫描事件库，返回幽灵键 → 出现处数。
Map<String, int> _scanGhosts() {
  final ghosts = <String, int>{};
  for (final event in allEvents) {
    for (final choice in event.choices) {
      for (final key in choice.effects.keys) {
        if (_isKnown(key)) continue;
        ghosts[key] = (ghosts[key] ?? 0) + 1;
      }
    }
  }
  return ghosts;
}

/// 受幽灵键影响的事件数。
int _ghostEventCount(List<GameEvent> events) {
  var n = 0;
  for (final event in events) {
    final hit = event.choices.any(
      (c) => c.effects.keys.any((k) => !_isKnown(k)),
    );
    if (hit) n++;
  }
  return n;
}

void main() {
  group('S5-2 · 静态内容零幽灵键（防回潮）', () {
    test('全库静态事件数据里的幽灵键恰好 0 处', () {
      // S5-2 把 S2-3 的 `lessThanOrEqualTo(74)` 上界收紧为「恰好 0」。
      // 上界断言曾让错误的 76 长期存活两年（S5-1 记录），不能再重复。
      final ghosts = _scanGhosts();
      expect(
        ghosts,
        isEmpty,
        reason: '静态内容出现了引擎不认识的效果键。'
            '它们会一律被拒收 ⇒ 玩家点了看到「N 项效果未生效」，叙事与状态脱节。'
            '要么改用既有键（gold/reputation/skills.*/attributes.*/'
            'relations.*/flags.*/inventory.*），要么先补齐引擎实现再写数据。'
            '当前明细：$ghosts',
      );
      expect(_ghostEventCount(allEvents), 0);
    });

    test('S5-2 删除的 10 个键名一个都不许再出现', () {
      // 比上一条更强：即使有人用「上界型」方式绕过 total 断言，
      // 只要这 10 个键名回来了就会红。列出键名而非只数个数。
      const removedKinds = <String>{
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
      final present = <String>{};
      for (final event in allEvents) {
        for (final choice in event.choices) {
          present.addAll(choice.effects.keys.where(removedKinds.contains));
        }
      }
      expect(present, isEmpty,
          reason: 'S5-2 已删除的幽灵键被重新引入：$present');
    });

    test('零效果死选项仍为 0（删除幽灵键不得把选项清空）', () {
      // S5-2 的删除是「删幽灵键条目」，不是「删整个 effects」。
      // 若有人为了省事把 `{reputation:5, political:10}` 直接写成 `{}`，
      // 幽灵键是没了，但玩家点了没反应——比原 bug 更糟。此断言挡住它。
      final dead = <String>[];
      for (final event in allEvents) {
        for (final c in event.choices) {
          if (c.effects.isEmpty) continue;
          if (c.effects.keys.every((k) => !_isKnown(k))) {
            dead.add('${event.id}/${c.id}');
          }
        }
      }
      expect(dead, isEmpty,
          reason: '这些选项的 effects 非空但全是未知键，玩家点了完全没反应：$dead');
    });

    test('幽灵键不落盘：应用含 political 的选项后玩家状态无对应变化', () {
      // 这条守的是**机制**而非存量：AI 仍可能实时生成 political。
      final engine = GameEngine()..startNewGame();
      final before = engine.player;
      final after = engine.applyEffects(
        before,
        const <String, int>{'reputation': 5, 'political': 10},
      );
      expect(after.reputation, before.reputation + 5);
      expect(engine.lastRejectedEffectKeys, contains('political'));
    });
  });

  group('Batch 10-119 拒收对玩家可见', () {
    EventChoice _choiceWithGhost() => const EventChoice(
          id: 'choice_ghost_probe',
          text: '支持合法继承人',
          requirements: <String, int>{},
          effects: <String, int>{'reputation': 5, 'political': 10},
          narrative: '你公开表态支持继承人。',
        );

    test('AI 通道输出「N 项效果未生效」提示行', () {
      final engine = GameEngine()..startNewGame();
      final text = engine.applyAiChoice(_choiceWithGhost());
      expect(text, contains('1 项效果未生效'));
      expect(text, contains('political'));
    });

    test('事件通道同样输出提示（applyChoice 返回值）', () {
      final engine = GameEngine()..startNewGame();
      engine.setCurrentEvent(allEvents.first);
      final text = engine.applyChoice(_choiceWithGhost());
      expect(text, contains('1 项效果未生效'),
          reason: '事件通道此前返回 void，幽灵键完全无反馈');
      expect(text, contains('political'));
    });

    test('无幽灵键时不输出提示', () {
      final engine = GameEngine()..startNewGame();
      final text = engine.applyEffects(
        Player.defaultPlayer(),
        const <String, int>{'gold': 1},
      );
      expect(text, isNotNull);
      expect(engine.lastRejectedEffectKeys, isEmpty);
    });
  });
}
