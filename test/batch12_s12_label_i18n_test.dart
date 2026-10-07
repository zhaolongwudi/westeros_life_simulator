/// Sprint 12 测试：面向玩家的属性/技能/家族关系**不得泄漏英文键**（S12-1 / S12-2）。
///
/// 【本批修的是什么】
/// 用户实装后报「属性/技能显示英文」，S11 卡片把它定位到 `player_panel_screen`。
/// 本轮亲自取证发现**范围比卡片记的更大**：除了面板两处，
/// `mixin_play.formatPlayerPanel`（主界面开局第一屏 + 「状态」指令的正文）也直接塞 `e.key`。
/// 另一处是 `family_screen` 的对外关系直接显示 `family_lannister` 这类家族 id。
///
/// 【为什么这些曾经能过 CI】
/// `m2_identity_history_test.dart` 的 `_expectNoEnglish` **只检查 10 个身份枚举名**
/// （noble/commoner/…），**不检查 strength/sword/magic**。
/// 测试名叫「formatPlayerPanel 展示中文身份」，就只管身份——名实相符，
/// 但它让人误以为面板整体已中文化。本文件补的是**键名维度**的闸门。
///
/// 【为什么不改 labels.dart 的兜底】
/// `skillLabel`/`attributeLabel` 的 `_ => key` 是**对的**：旧存档里的动态键必须可见，
/// 改成返回空串会把玩家的历史数据变成空白（硬约束见简报 S11 硬约束第 3 条）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/balance_data.dart';
import 'package:westeros_life_simulator/data/family_data.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/screens/family_screen.dart';
import 'package:westeros_life_simulator/screens/player_panel_screen.dart';
import 'package:westeros_life_simulator/utils/labels.dart';

/// 玩家属性/技能的全部合法键（取自白名单，与标签表同源）。
const List<String> _allAttributeKeys = <String>[
  'strength',
  'agility',
  'intelligence',
  'charisma',
  'willpower',
  'perception',
];

const List<String> _allSkillKeys = <String>[
  'sword',
  'leadership',
  'politics',
  'archery',
  'scholarship',
  'stealth',
  'fencing',
  'survival',
  'craft',
  'magic',
  'riding',
  'speech',
  'alchemy',
];

/// 新引擎（带默认玩家）。
GameEngine _engine() => GameEngine()..startNewGame();

void main() {
  group('S12-1 属性/技能中文化', () {
    test('formatPlayerPanel 不含任何英文属性键', () {
      final panel = _engine().formatPlayerPanel();
      for (final key in _allAttributeKeys) {
        expect(panel.contains('$key '), isFalse,
            reason: '玩家面板不应出现英文属性键 "$key"：\n$panel');
      }
    });

    test('formatPlayerPanel 不含任何英文技能键', () {
      final panel = _engine().formatPlayerPanel();
      for (final key in _allSkillKeys) {
        expect(panel.contains('$key '), isFalse,
            reason: '玩家面板不应出现英文技能键 "$key"：\n$panel');
      }
    });

    test('formatPlayerPanel 展示中文属性与技能名', () {
      final panel = _engine().formatPlayerPanel();
      expect(panel.contains(attributeLabel('strength')), isTrue,
          reason: '应展示「力量」：\n$panel');
      expect(panel.contains(skillLabel('sword')), isTrue,
          reason: '应展示「剑术」：\n$panel');
    });

    test('白名单与标签表完全对齐（新增键必须同步两处）', () {
      // 若日后给 kPlayerAttributeKeys / kPlayerSkillKeys 加了键却没加标签，
      // 面板就会重新漏出英文键。此处锁死「两表同源」。
      for (final key in BalanceData.kPlayerAttributeKeys) {
        expect(attributeLabel(key), isNot(key),
            reason: '属性键 "$key" 缺少中文标签');
      }
      for (final key in BalanceData.kPlayerSkillKeys) {
        expect(skillLabel(key), isNot(key),
            reason: '技能键 "$key" 缺少中文标签');
      }
    });
  });

  group('S12-2 家族对外关系中文化', () {
    test('对外关系显示家族中文名而非原始 id', () {
      final e = _engine();
      // 史塔克家族在数据里对兰尼斯特是负值关系（既有测试 batch2_family_data 已锁定）。
      final stark = familyById('family_stark')!;
      final lannisterId = stark.relations.keys.firstWhere(
        (k) => k == 'family_lannister',
        orElse: () => stark.relations.keys.first,
      );
      final other = familyById(lannisterId);
      expect(other, isNotNull, reason: '关系键应能查到家族');
      // 面板源码用 familyById(e.key)?.name ?? e.key 渲染——
      // 这里断言渲染逻辑要用的名字确实存在且不是 id。
      expect(other!.name, isNot(lannisterId));
      expect(e.playerFamily?.relations.containsKey(lannisterId), isTrue,
          reason: '默认玩家属史塔克，应含该对外关系');
    });

    test('未知家族 id 的兜底是原值而非崩溃', () {
      expect(familyById('family_not_exist'), isNull);
      // 面板里对应表达式 familyById(x)?.name ?? x 在 null 时返回原值。
      const unknown = 'family_not_exist';
      expect(familyById(unknown)?.name ?? unknown, unknown);
    });
  });

  group('S12-1/2 UI 渲染层（widget）', () {
    /// 滚到页面底部，确保 `ListView` 的懒构建把目标区块真正 build 出来。
    ///
    /// 【坑】`ListView` 只构建可视区的子节点。属性/技能/家族关系都在首屏之下，
    /// 不滚动时 `find.textContaining(...)` 一律 findsNothing —— 那是
    /// **测试没滚**，不是 UI 没渲染（第一次写这个测试就踩了）。
    Future<void> scrollToBottom(WidgetTester tester) async {
      final list = find.byType(ListView).first;
      for (var i = 0; i < 8; i++) {
        await tester.drag(list, const Offset(0, -600));
        await tester.pumpAndSettle();
      }
    }

    testWidgets('玩家面板渲染中文属性/技能，不出现英文键', (tester) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(home: PlayerPanelScreen(engine: _engine())),
      );
      await tester.pumpAndSettle();
      await scrollToBottom(tester);

      final text = find.textContaining(attributeLabel('strength'));
      expect(text, findsWidgets, reason: '面板应显示「力量」');
      final skill = find.textContaining(skillLabel('sword'));
      expect(skill, findsWidgets, reason: '面板应显示「剑术」');
      for (final key in <String>[..._allAttributeKeys, ..._allSkillKeys]) {
        expect(find.text(key), findsNothing,
            reason: '面板不应把英文键 "$key" 当独立文本渲染');
      }
    });

    testWidgets('家族面板对外关系显示家族中文名而非 id', (tester) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(home: FamilyScreen(engine: _engine())),
      );
      await tester.pumpAndSettle();
      await scrollToBottom(tester);

      // 史塔克的对外关系里含兰尼斯特（既有数据：负值敌对）。
      final lannister = familyById('family_lannister')!;
      expect(find.textContaining(lannister.name), findsWidgets,
          reason: '应显示家族中文名「${lannister.name}」');
      expect(find.textContaining('family_lannister'), findsNothing,
          reason: '不应显示原始家族 id');
    });
  });
}