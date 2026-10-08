/// Sprint 13-11 测试：修 ⑭⑮⑯⑰㉒ 五项（文案 / 展示 / 刷新层）。
///
/// 【本批修的是什么】
/// ⑭ 协作任务接取文案承诺「同伴关系 +2」，实现只给发布方 `adjustRelation`
///    （`mixin_npc_task.dart:139`）——完成结算处有同伴奖励，接取处漏了。
/// ⑮ 事件面板把内部键印给玩家：91 个英文 tags + `locationId=location_white_harbor`
///    这类 `键=值`（`events_screen.dart:157,177`）。内容规范
///    （`docs/specs/content-schema.md:96`）写明 tags 是「筛选与统计用」的内部字段。
/// ⑯ 信件横幅写「最近：A」，而回信实际回给**最早**一封（`mixin_letter.dart:117`
///    取 `target.first`，但 `_letters` 是追加顺序）⇒ 横幅与真实对象不符。
/// ⑰ NPC 面板是 `StatelessWidget`，接取任务后「进行中的任务」卡片不刷新
///    （S13-3 已把按钮改接 V2，数据落盘了，只是界面没重建）。
/// ㉒ `家常` 话题被 `t.contains('家')` 抢先路由成 `家业` ⇒ `家常` 档不可达。
///
/// 【为什么 ⑮ 只断言「不出现英文键」】正确做法是展示中文（`eventConditionLabel`），
/// 但断言「不出现某个具体英文串」比断言「出现某个中文串」更稳：前者直接锁住
/// 「内部键不得泄漏」这一契约，后者会随文案微调而失效。
///
/// ⚠️ 本机（Android/DSH）无 dart/flutter，**本文件未在本地执行**，正确性由 CI 验证。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/screens/events_screen.dart';
import 'package:westeros_life_simulator/screens/letters_screen.dart';
import 'package:westeros_life_simulator/screens/npc_panel_screen.dart';
import 'package:westeros_life_simulator/utils/labels.dart';

/// 协作任务：艾德 × 凯特琳（两人都在临冬城，开局同地）。
const String kCoopTaskId = 'task_nev_cat_winter_store';
const String kPublisherId = 'npc_nev';
const String kCompanionId = 'npc_catelyn';

/// 双方关系都达到协作门槛（`coNpcNotAvailableReason` 要求 ≥ 20）。
GameEngine _coopReadyEngine() {
  final engine = GameEngine()..startNewGame();
  engine.updatePlayer(
    engine.player.copyWith(
      relations: const <String, int>{kPublisherId: 25, kCompanionId: 25},
    ),
  );
  return engine;
}

void main() {
  group('S13-11 ⑭ 协作任务接取：同伴关系必须真的 +2', () {
    test('接取后同伴关系比接取前多 2（缺陷下只加发布方）', () {
      final engine = _coopReadyEngine();
      final publisherBefore = engine.npcRelation(kPublisherId);
      final companionBefore = engine.npcRelation(kCompanionId);

      final result = engine.acceptNpcTaskV2(
        kPublisherId,
        taskId: kCoopTaskId,
      );
      expect(result, contains('接下'), reason: '前提：协作任务接取成功');
      expect(result, contains('关系 +2'), reason: '前提：文案确实承诺了 +2');

      expect(engine.npcRelation(kPublisherId), publisherBefore + 2,
          reason: '发布方 +2（既有行为，锁住别改坏）');
      // 🔴 判别断言：修复前同伴关系纹丝不动
      expect(engine.npcRelation(kCompanionId), companionBefore + 2,
          reason: '文案写了「同伴关系 +2」，实现必须真的加（⑭）');
    });

    test('单人任务不受影响：接取后只有发布方 +2', () {
      final engine = GameEngine()..startNewGame();
      // 单人任务同样要求关系 ≥ 20（`acceptNpcTaskV2` 的门槛对两类任务一致）
      engine.updatePlayer(
        engine.player.copyWith(relations: const <String, int>{kPublisherId: 25}),
      );
      final before = engine.npcRelation(kPublisherId);
      final result = engine.acceptNpcTaskV2(kPublisherId);
      expect(result, contains('接下'));
      expect(engine.npcRelation(kPublisherId), before + 2);
      // 单人任务没有同伴，别把无关 NPC 也加上
      expect(engine.npcRelation(kCompanionId), 0,
          reason: '单人任务不该顺手给凯特琳加关系');
    });
  });

  group('S13-11 ⑮ 事件面板：不得把内部键印给玩家', () {
    testWidgets('事件库不显示英文 tags', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: EventsScreen()));
      await tester.pumpAndSettle();

      // 切到「事件库」页（默认在「可触发」）
      await tester.tap(find.text('事件库'));
      await tester.pumpAndSettle();

      // 91 个 tags 里最常见的几个，修复前会出现在 subtitle 里
      for (final tag in <String>['political', 'economic', 'supernatural']) {
        expect(find.textContaining(tag), findsNothing,
            reason: '内容规范写明 tags 是内部字段，不该印给玩家（⑮）：$tag');
      }
    });

    testWidgets('触发条件渲染为中文，不出现 locationId= / skills. 原文',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: EventsScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('事件库'));
      await tester.pumpAndSettle();

      // 【为什么专门挑「沉船遗宝」】事件库里**首个**事件（国王死亡）的
      // `triggerConditions` 是空的，展开它只会渲染「无（任何时候都可能发生）」，
      // 断言会恒真、没有判别力。`沉船遗宝` 实测带
      // `locationId: location_white_harbor`（`event_data.dart`），
      // 修复前会渲染成「触发条件：locationId=location_white_harbor」。
      await tester.scrollUntilVisible(
        find.text('沉船遗宝'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.ancestor(
        of: find.text('沉船遗宝'),
        matching: find.byType(ExpansionTile),
      ));
      await tester.pumpAndSettle();

      for (final raw in <String>[
        'locationId=',
        'skills.',
        'attributes.',
        'hasItem.',
        'minGold=',
        'minReputation=',
      ]) {
        expect(find.textContaining(raw), findsNothing,
            reason: '门槛键应经 eventConditionLabel 中文化，不得泄漏原文（⑮）：$raw');
      }
      expect(find.textContaining('白港'), findsWidgets,
          reason: 'locationId 应翻成地点中文名');
    });

    test('eventConditionLabel 覆盖数据里全部 12 种门槛键', () {
      // 键集取自 assets/data/events.json 实测（triggerConditions 12 种）
      const samples = <String, String>{
        'minGold': '50',
        'season': 'winter',
        'locationId': 'location_winterfell',
        'minReputation': '30',
        'flag': 'isInjured',
        'noFlag': 'hasShelter',
        'maxEnergy': '30',
        'minAge': '15',
        'minEnergy': '30',
        'hasItem.item_glass_candle': '1',
        'skills.riding': '3',
        'skills.alchemy': '2',
      };
      for (final e in samples.entries) {
        final label = eventConditionLabel(e.key, e.value);
        expect(label, isNot(contains('=')),
            reason: '已识别的门槛键不该退化成「键=值」原文：${e.key}');
        expect(label, isNot(contains('_')),
            reason: '不该残留内部 id/键名（下划线）：${e.key} → $label');
      }
    });

    test('未知门槛键退化为原文而非抛异常（未来加键不崩）', () {
      expect(eventConditionLabel('someFutureKey', '7'), 'someFutureKey=7');
    });

    test('门槛里的地点/物品/家族 id 翻成中文名', () {
      expect(eventConditionLabel('locationId', 'location_winterfell'),
          contains('临冬城'));
      expect(eventConditionLabel('hasItem.item_glass_candle', '1'),
          contains('玻璃蜡烛'));
      expect(eventConditionLabel('skills.riding', '3'), contains('骑术'));
    });
  });

  group('S13-11 ⑯ 信件：横幅标的「最近」必须就是要回的那封', () {
    /// 造一封待回信，返回寄信人姓名。
    ///
    /// 【为什么用 seed 循环而不是直接塞 `letters`】`_letters` 是
    /// `GameLetterMixin` 的**私有字段**（`mixin_letter.dart:34`），测试无法注入，
    /// 只能走真实的 `maybeTriggerLetter`。该函数有 40% 概率不发信，
    /// 故循环若干 seed 直到发出来——这是**确定性**的（结果必达），
    /// 不是概率等待（接力文档 §0 第 9 条）。与 S13-5 的 `_exhaust` 同型。
    String _triggerOne(GameEngine engine) {
      for (var seed = 0; seed < 500; seed++) {
        if (engine.maybeTriggerLetter(seed: seed).isNotEmpty) {
          return engine.letters.last.senderName;
        }
      }
      fail('500 个 seed 都没发出信 ⇒ 收信闸口本身坏了');
    }

    test('回信对象是最新一封（不是最早那封）', () {
      final engine = GameEngine()..startNewGame();
      final first = _triggerOne(engine);
      // 推进一个月，绕开「本月已收过」的冷却，再收一封
      engine.advanceTime();
      final second = _triggerOne(engine);

      expect(engine.letters, hasLength(2), reason: '前提：两封待回信');
      expect(second, isNot(first), reason: '前提：两封来自不同寄信人（冷却会换人）');

      final text = engine.replyLetter(replyText: '保重');
      expect(text, contains(second),
          reason: '横幅写「最近」、列表顶部也是最新 ⇒ 回信对象必须是最新那封（⑯）');
      expect(text, isNot(contains(first)), reason: '不该回给最早那封');
    });

    testWidgets('横幅显示的寄信人 == 回信实际回给的寄信人', (tester) async {
      final engine = GameEngine()..startNewGame();
      final first = _triggerOne(engine);
      engine.advanceTime();
      final second = _triggerOne(engine);

      await tester.pumpWidget(MaterialApp(home: LettersScreen(engine: engine)));
      await tester.pumpAndSettle();

      expect(find.textContaining('最近：$second'), findsOneWidget,
          reason: '横幅标的「最近」必须是真正最新那封（⑯）');

      // 点回信，返回的叙事必须是横幅上那个寄信人
      await tester.tap(find.byTooltip('回信'));
      await tester.pumpAndSettle();
      expect(find.textContaining('写了一封回信'), findsOneWidget,
          reason: '回信成功应有 SnackBar');
      expect(find.textContaining('你提笔给 $second 写了一封回信'), findsOneWidget,
          reason: '横幅与回信对象必须一致（⑯）');
      // 剩下最早的成为唯一待回信
      expect(engine.letters.where((l) => l.isFromNpc && !l.replied).length, 1);
      expect(engine.letters.first.senderName, first);
    });
  });

  group('S13-11 ⑰ NPC 面板：接取任务后「进行中的任务」必须刷新', () {
    testWidgets('点「任务」后卡片从「没有进行中的任务」变为列出该任务',
        (tester) async {
      final engine = _coopReadyEngine();
      // 先确认接取前确实没有进行中任务（前提，否则断言无判别力）
      expect(engine.activeTasks, isEmpty);

      // 【为什么要放大视口】本屏是一个长 `ListView`，「进行中的任务」卡片
      // 在默认视口之外 ⇒ 根本不会被构建，`find.text` 找不到它。
      // 既有 `batch10_24_task_progress_ui_test.dart:193-204` 用同一手法。
      tester.view.physicalSize = const Size(1080, 12000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(home: NpcPanelScreen(engine: engine)),
      );
      await tester.pumpAndSettle();

      expect(find.text('目前没有进行中的任务。'), findsOneWidget,
          reason: '前提：接取前卡片显示空态');

      // 点第一个「任务」按钮（在场 NPC 行）
      final taskBtn = find.text('任务');
      expect(taskBtn, findsWidgets, reason: '前提：在场 NPC 应有「任务」按钮');
      await tester.tap(taskBtn.first);
      await tester.pumpAndSettle();

      // 🔴 判别断言：修复前是 StatelessWidget，不重建 ⇒ 仍显示空态
      expect(engine.activeTasks, isNotEmpty, reason: '前提：任务确实接下了');
      expect(find.text('目前没有进行中的任务。'), findsNothing,
          reason: '接取后卡片必须刷新（⑰）');
      expect(find.textContaining(engine.activeTasks.first.title), findsWidgets,
          reason: '刚接的任务标题应出现在「进行中的任务」里');
    });
  });

  group('S13-11 ㉒ 配偶谈心：家常话题必须走家常档', () {
    test('平民配偶谈「家常」得到家常回应，而非家业回应', () {
      final engine = GameEngine()..startNewGame();
      engine.marry('平民');
      final text = engine.spouseChat('家常');
      // `_commonerChat` 的「家常」档是「邻家趣事…鸡毛蒜皮」，
      // 「家业」档是「缝着衣裳笑道：等你回来，饭总是热的」。
      expect(text, contains('邻家趣事'),
          reason: '「家常」被 contains(\'家\') 抢成「家业」⇒ 该档不可达（㉒）');
      expect(text, isNot(contains('饭总是热的')),
          reason: '不该落到「家业」档');
    });

    test('贵族配偶谈「家常」得到家常回应，而非家业回应', () {
      final engine = GameEngine()..startNewGame();
      engine.marry('贵族');
      final text = engine.spouseChat('家常');
      expect(text, contains('旧史'), reason: '贵族「家常」档是共读旧史（㉒）');
    });

    test('「家业」仍走家业档（修 ㉒ 不得误伤同前缀话题）', () {
      final engine = GameEngine()..startNewGame();
      engine.marry('平民');
      final text = engine.spouseChat('家业');
      expect(text, contains('饭总是热的'), reason: '「家业」不该被改坏');
    });

    test('「朝局」「江湖」路由不受影响', () {
      final noble = GameEngine()..startNewGame();
      noble.marry('贵族');
      expect(noble.spouseChat('朝局'), contains('铁王座'));

      final warrior = GameEngine()..startNewGame();
      // 身世别名见 `_originOf`：'战士' || 'warrior' || '骑士'（没有「武士」）
      warrior.marry('战士');
      expect(warrior.spouseChat('江湖'), contains('下次闯荡'));
    });
  });
}
