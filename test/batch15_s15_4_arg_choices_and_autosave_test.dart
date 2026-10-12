/// S15-4 测试：指令参数候选按钮（免手打）+ 自动存档不再丢档。
///
/// 【本批修的两件事】
/// ① 参数候选：47 条指令里 16 条需参数（互动/示好/深聊/接任务→NPC，
///    使用/购买/出售/装备/卸下→物品，训练→技能，求婚→身世，
///    督导/送学→子女，放弃→任务）。此前面板只把「指令名 + 空格」
///    预填进输入框，**玩家仍要手打「提利昂」「item_bread」「sword」**。
///    现在 `CommandSpec.argChoices` 声明候选来源，面板就地展开
///    「▾」候选按钮，点一下即带参执行（label 中文 / value 内部键）。
///
/// ② 自动存档：原实现**只在年月变化时**落盘（`_maybeAutoSave` 比
///    `_lastSavedMonth`），于是同一个月内的操作成果（赚钱、练技能、
///    接任务、写信）退出后全丢——玩家感受就是「返回＝重新开始」。
///    现在任何引擎变化都去抖落盘，且 `dispose` 补存最后一笔。
///
/// 【为什么这些断言有效】候选是**纯函数**（读玩家/世界状态），
/// 可在无 UI 环境下逐条断言；存档断言注入临时目录的 `SaveService`，
/// 不碰真实存档。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/core/command_registry.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/screens/game_screen.dart';
import 'package:westeros_life_simulator/services/save_service.dart';
import 'package:westeros_life_simulator/theme/westeros_theme.dart';
import 'package:westeros_life_simulator/widgets/game/command_panel.dart';

/// 按主名取一条指令描述。
CommandSpec _spec(GameEngine e, String alias) =>
    e.commandRegistry.orderedSpecs.firstWhere((s) => s.aliases.first == alias);

void main() {
  group('S15-4 参数候选：声明与内容', () {
    test('需参数指令的候选是 (中文 label, 内部键 value) 对', () {
      final engine = GameEngine()..startNewGame();

      // 训练：显示中文技能名，传内部键（玩家不该看到 sword/archery）
      final train = _spec(engine, '训练');
      final skills = train.argChoices!();
      expect(skills, isNotEmpty, reason: '训练应有技能候选');
      expect(skills.map((c) => c.label), contains('剑术'),
          reason: '候选按钮应显示中文技能名');
      expect(skills.map((c) => c.value), contains('sword'),
          reason: '传给引擎的应是内部键 sword');
      // 判别式：label 与 value 分离（中文不泄漏进引擎，英文不泄漏给玩家）
      final sword = skills.firstWhere((c) => c.value == 'sword');
      expect(sword.label, '剑术');
      expect(sword.label, isNot(sword.value),
          reason: 'label 与 value 必须分离，否则总有一边泄漏');
    });

    test('互动候选来自「在场 NPC」，且值与名字分离（id 更稳）', () {
      final engine = GameEngine()..startNewGame();
      final onsite = engine.npcsAtCurrentLocation;
      expect(onsite, isNotEmpty, reason: '前提：开局临冬城应有在场 NPC');

      final choices = _spec(engine, '互动').argChoices!();
      expect(choices.length, onsite.length);
      for (final c in choices) {
        expect(onsite.any((n) => n.name == c.label), isTrue,
            reason: '候选 ${c.label} 不在在场 NPC 里');
        expect(onsite.any((n) => n.id == c.value), isTrue,
            reason: '候选值 ${c.value} 不是真实 NPC id');
      }
    });

    test('物品候选来自背包（空背包 = 空候选，面板回落预填）', () {
      final engine = GameEngine()..startNewGame();
      final spec = _spec(engine, '使用');
      expect(spec.argChoices, isNotNull, reason: '使用应有候选来源');
      // 初始背包可能有物品也可能没有；断言的是「候选 ⊆ 背包」
      final bag = engine.player.inventory.toSet();
      for (final c in spec.argChoices!()) {
        expect(bag, contains(c.value),
            reason: '候选 ${c.value} 不在背包里 ⇒ 点了会「没有该物品」');
      }
    });

    test('求婚候选：给出四种身世（值可直接喂给 marry）', () {
      final engine = GameEngine()..startNewGame();
      final choices = _spec(engine, '求婚').argChoices!();
      expect(choices.map((c) => c.value).toList(),
          containsAll(<String>['平民', '贵族']));
    });

    test('无候选的指令保持 argChoices == null（如「立嗣」需要玩家起名）', () {
      final engine = GameEngine()..startNewGame();
      final adopt = _spec(engine, '立嗣');
      expect(adopt.needsArgs, isTrue);
      expect(adopt.argChoices, isNull,
          reason: '起名类指令没有候选概念，必须是 null（面板才回落预填）');
    });

    test('「培养」是双参数：本轮不提供候选（不得只给一半参数）', () {
      final engine = GameEngine()..startNewGame();
      final rear = _spec(engine, '培养');
      expect(rear.requiredArgCount, 2);
      expect(rear.argChoices, isNull,
          reason: '两个参数只给第一个候选 ⇒ 拼出的命令仍缺参，属半成品');
    });
  });

  group('S15-4 参数候选：面板交互', () {
    Future<void> pumpPanel(
      WidgetTester tester, {
      required GameEngine engine,
      void Function(CommandSpec, String)? onRunWithArg,
    }) async {
      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: westerosTheme(),
          home: Scaffold(
            body: CommandPanel(
              specs: engine.commandRegistry.orderedSpecs,
              onRun: (_) {},
              onPrefill: (_) {},
              onRunWithArg: onRunWithArg,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('点「训练 ▾」展开中英分离的技能候选，点选回调带内部键',
        (tester) async {
      final engine = GameEngine()..startNewGame();
      final calls = <String>[];
      await pumpPanel(
        tester,
        engine: engine,
        onRunWithArg: (spec, value) => calls.add('${spec.aliases.first}:$value'),
      );

      // 有候选的指令带「▾」标记（判别式：修复前是「训练 …」）
      expect(find.text('训练 ▾'), findsOneWidget,
          reason: '有关联候选的指令应显示 ▾ 标记');
      await tester.tap(find.text('训练 ▾'));
      await tester.pumpAndSettle();

      // 候选按钮出现且是中文
      expect(find.text('选择要用的：'), findsOneWidget);
      expect(find.text('剑术'), findsWidgets, reason: '候选按钮应显示中文技能名');
      await tester.tap(find.text('剑术').last);
      await tester.pumpAndSettle();

      expect(calls, contains('训练:sword'),
          reason: '点中文「剑术」应带内部键 sword 执行');
    });

    testWidgets('无 onRunWithArg 时保持旧行为（点击回落预填）', (tester) async {
      final engine = GameEngine()..startNewGame();
      final prefilled = <String>[];
      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: westerosTheme(),
          home: Scaffold(
            body: CommandPanel(
              specs: engine.commandRegistry.orderedSpecs,
              onRun: (_) {},
              onPrefill: (s) => prefilled.add(s.aliases.first),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 没有 onRunWithArg ⇒ 不显示 ▾，仍是「…」并走预填
      expect(find.text('训练 ▾'), findsNothing);
      await tester.tap(find.text('训练 …'));
      await tester.pumpAndSettle();
      expect(prefilled, contains('训练'));
    });
  });

  group('S15-4 自动存档：不再丢档', () {
    testWidgets('同月内的一条指令也会被自动存档（判别式）', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final dir = Directory.systemTemp.createTempSync('s15_4_save_');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });

      final engine = GameEngine()..startNewGame();
      final service = SaveService(saveDir: dir.path);
      await tester.pumpWidget(
        MaterialApp(
          theme: westerosTheme(),
          home: GameScreen(engine: engine, saveService: service),
        ),
      );
      await tester.pumpAndSettle();

      // 执行一条同月内、不跨月的指令（状态会变化但年月不变）
      await tester.enterText(find.byType(TextField).last, '工作');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();

      // 跳过 2 秒去抖并让**真实文件 IO** 完成（fake-async 之外）
      await tester.pump(const Duration(seconds: 3));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      await tester.pumpAndSettle();

      final saves = await service.listSaves();
      // 🔴 判别断言：修复前这里为空（只在跨月时写盘），同月操作全丢
      expect(saves, isNotEmpty,
          reason: '同月内的操作也必须自动落盘，否则退出即丢档（用户反馈「返回＝重开」）');

      // 且存的是**操作后**的状态（金币已变）
      final loaded = await service.loadGame(saves.first.saveId);
      expect(loaded, isNotNull);
      // 工作可能因精力/次数限制未改变金币，故只断言「存档中的金币 == 当前金币」
      expect(loaded!.player.gold, engine.player.gold,
          reason: '自动存档应反映操作后的最新状态，而非进入时的旧状态');
    });

    testWidgets('退出界面时补存最后一笔（dispose flush）', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final dir = Directory.systemTemp.createTempSync('s15_4_flush_');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });

      final engine = GameEngine()..startNewGame();
      final service = SaveService(saveDir: dir.path);
      await tester.pumpWidget(
        MaterialApp(
          theme: westerosTheme(),
          home: GameScreen(engine: engine, saveService: service),
        ),
      );
      await tester.pumpAndSettle();

      // 改状态但**不**等去抖窗口，直接换掉整棵树（触发 dispose）
      engine.gainGold(7);
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 120));
      });
      await tester.pumpAndSettle();

      final saves = await service.listSaves();
      // 🔴 判别断言：修复前 dispose 不补存 ⇒ 退出瞬间的操作丢失
      expect(saves, isNotEmpty,
          reason: 'dispose 应补存最后一笔，否则「操作后立刻返回」会丢档');
    });
  });
}
