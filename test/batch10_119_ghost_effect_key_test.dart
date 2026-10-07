/// Batch 10-119 测试：幽灵效果键「防新增」闸门（S2-3 / P1-03 阶段一）。
///
/// 背景：事件数据里有 **10 个引擎不认识的顶层效果键**（`political` / `faith` /
/// `military` / `magic` / `familyRelation` / `food` / `happiness` /
/// `knowledge` / `north` / `allyRelation`）。它们由 `docs/06` 设计、引擎从未实现，
/// 玩家点了「支持合法继承人」只拿到 reputation，叙事承诺的政治资本变化静默丢弃。
///
/// 本批**不清理存量**（清理会破坏玩法：「转身离开」型选项本就没有收益，是有意设计），
/// 只做两件事：① 存量基线锁死，新增即红；② 拒收必须对玩家可见。
///
/// ## 历史数字更正（S5-1 取证，2026-10-07）
///
/// 本文件原注释称「共 78 处、覆盖 40/72 事件」与「9 个选项会变成零效果死选项」，
/// **两处均与代码不符**，S5-1立项时重新扫描真相源（`event_data.dart` 223 个选项）核实：
///
/// | 项 | 原注释 | 实测 |
/// |---|---|---|
/// | 幽灵键处数 | 78 | **76**（`happiness` 5 处属实，故总数应为 76） |
/// | 零效果死选项 | 9 | **2**（`event_festival` / `event_hunt` 的「休息」） |
/// | 波及事件数 | 40/72 | 39/ 71 |
///
/// 那 2 个死选项已在 S5-1 修复（`happiness` → `energy`，是键名笔误而非设计问题），
/// 故本文件下方的「78 / 40」基线断言实际从未生效于真实值——它们是
/// `lessThanOrEqualTo` 上界断言，76 ≤ 78 恒过，因此**错误的 78 一直没被 CI发现**。
/// 现将上界收紧为实测基线，使后续漂移能被捕获。
///
/// 覆盖：
/// 1. 全量扫描：幽灵键种类/处数/涉及事件 = 基线，新增任何一种或一处都失败
/// 2. 契约：幽灵键确实不落盘，且被登记进 lastRejectedEffectKeys
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
  group('Batch 10-119 存量基线（防新增）', () {
    test('幽灵键种类恰为已知 10 种，不得新增', () {
      final ghosts = _scanGhosts();
      expect(
        ghosts.keys.toSet(),
        <String>{
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
        },
        reason: '出现新种类说明有人写了引擎不支持的效果键 —— 要么接线实现，'
            '要么改用既有键，不要让它静默丢弃。当前明细：$ghosts',
      );
    });

    test('幽灵键处数为 74、涉及事件 39（只减不增）', () {
      final ghosts = _scanGhosts();
      final total = ghosts.values.fold<int>(0, (a, b) => a + b);
      // S5-1：上界由原先错误的 78/40 收紧到实测基线 74/39。
      // 原上界从未真正约束——76 ≤ 78 恒过，所以错误的 78 才一直没被 CI 发现。
      expect(total, lessThanOrEqualTo(74),
          reason: '幽灵键变多了（当前 $total）：$ghosts');
      expect(_ghostEventCount(allEvents), lessThanOrEqualTo(39));
    });

    test('幽灵键不落盘：应用含 political 的选项后玩家状态无对应变化', () {
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
