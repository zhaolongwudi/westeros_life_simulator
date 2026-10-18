/// S16 测试：剧情回路——主 AI 说书，不可用时本地导演接手。
///
/// 【本批修的是什么】改造前主界面是「47 条指令 + 过月」，AI 通道要玩家先打字、
/// 且未配置 Key 时直接回一句「请先配置」——玩家不打字就永远没有剧情。本批把
/// 剧情回合变成主流程：进入即开场、选完自动续下一回合，主 AI 不可用时由
/// [StoryDirector] 用事件库 + 当前处境照常产出「剧情 + 2~4 个选项」。
///
/// 【覆盖】
///  1. 本地导演：确定性、叙事有料、选项 2~4 个且来自事件库、相位影响力取材、
///     无可用事件时的日常兜底与效果键白名单
///  2. 引擎回路：未配置 Key / AI 失败 → 本地接手；AI 可用 → 用主 AI 的叙事
///     与选项；待决事件被剧情回合接管；选项落盘并推进一个月
///  3. 主界面：进入即出现选项卡；点选项 → 自动开下一回合
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:westeros_life_simulator/core/narrative_momentum.dart';
import 'package:westeros_life_simulator/core/story_director.dart';
import 'package:westeros_life_simulator/data/event_data.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/models/event.dart';
import 'package:westeros_life_simulator/screens/game_screen.dart';
import 'package:westeros_life_simulator/services/ai_service.dart';
import 'package:westeros_life_simulator/widgets/game/narrative.dart';

/// 新引擎（默认玩家 + 事件库）。
GameEngine _engine() => GameEngine()..startNewGame();

/// 本地导演的产出（用当前引擎的处境与可用事件）。
DirectedScene _scene(GameEngine engine, {int? turnCount}) {
  return StoryDirector.direct(
    player: engine.player,
    year: engine.progress.year,
    month: engine.progress.month,
    season: engine.progress.season,
    turnCount: turnCount ?? engine.progress.turnCount,
    availableEvents: engine.eventProvider.getAvailableEvents(
      engine.player,
      season: engine.progress.season,
    ),
    location: engine.currentLocation,
    familyName: engine.playerFamily?.name ?? '',
    onSiteNpcs: engine.npcsAtCurrentLocation,
  );
}

/// 假 AiService：不联网，直接返回给定 content（与真实响应同结构）。
AiService _fakeAi(String content) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            statusCode: 200,
            data: <String, dynamic>{
              'choices': <dynamic>[
                <String, dynamic>{
                  'message': <String, dynamic>{'content': content},
                },
              ],
            },
          ),
        );
      },
    ),
  );
  return AiService(
    apiKey: 'test_key',
    dio: dio,
    baseUrl: 'https://mock.example.com/v1',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('S16 本地剧情导演', () {
    test('确定性：同一回合同一处境两次结果完全一致', () {
      final engine = _engine();
      final a = _scene(engine);
      final b = _scene(engine);
      expect(a.narrative, b.narrative);
      expect(a.choices.map((c) => c.id).toList(),
          b.choices.map((c) => c.id).toList());
      expect(a.eventId, b.eventId);
    });

    test('叙事有料：含时间/地点/处境，且明显长于旧的一行传闻', () {
      final engine = _engine();
      final scene = _scene(engine);
      // 旧实现一条传闻约 70 字；本地导演必须给出成段的场景
      expect(scene.narrative.length, greaterThan(80));
      expect(scene.narrative, contains('${engine.progress.year}年'));
      expect(scene.narrative, contains('金龙'));
    });

    test('选项 2~4 个，且全部来自事件库（不是凭空造的）', () {
      final engine = _engine();
      final scene = _scene(engine);
      expect(scene.isDailyFallback, false);
      expect(scene.choices.length, inInclusiveRange(2, 4));
      for (final choice in scene.choices) {
        final known = allEvents
            .any((e) => e.choices.any((c) => c.id == choice.id));
        expect(known, true, reason: '${choice.id} 不在事件库里');
      }
    });

    test('相位影响力取材：引入相位不挑政治/战争，转折相位优先政治/战争', () {
      final engine = _engine();
      final available = engine.eventProvider.getAvailableEvents(
        engine.player,
        season: engine.progress.season,
      );
      // 相位一（回合 0-2）：最高分是日常/家族/经济
      final intro = StoryDirector.pickEvent(
        available,
        NarrativeMomentum.phaseFor(0),
        0,
      );
      expect(intro, isNotNull);
      expect(
        NarrativeMomentum.scoreEvent(intro!, NarrativePhase.introduce),
        greaterThanOrEqualTo(
          NarrativeMomentum.scoreEvent(intro, NarrativePhase.turn),
        ),
      );
      // 相位三（回合 6-8）：最高分是政治/战争/超自然
      final turning = StoryDirector.pickEvent(
        available,
        NarrativeMomentum.phaseFor(6),
        6,
      );
      expect(turning, isNotNull);
      expect(
        NarrativeMomentum.scoreEvent(turning!, NarrativePhase.turn),
        greaterThanOrEqualTo(
          NarrativeMomentum.scoreEvent(turning, NarrativePhase.introduce),
        ),
      );
    });

    test('无可用事件 → 日常兜底，且效果键全部在白名单内', () {
      final engine = _engine();
      final scene = StoryDirector.direct(
        player: engine.player,
        year: engine.progress.year,
        month: engine.progress.month,
        season: engine.progress.season,
        turnCount: 0,
        availableEvents: const <GameEvent>[],
        location: engine.currentLocation,
        onSiteNpcs: engine.npcsAtCurrentLocation,
      );
      expect(scene.isDailyFallback, true);
      expect(scene.eventId, isNull);
      expect(scene.choices.length, greaterThanOrEqualTo(2));
      for (final choice in scene.choices) {
        for (final key in choice.effects.keys) {
          final ok = key == 'gold' ||
              key == 'energy' ||
              key == 'hunger' ||
              key == 'health' ||
              key.startsWith('relations.');
          expect(ok, true, reason: '日常兜底写了一个白名单外的效果键：$key');
        }
      }
    });
  });

  group('S16 剧情回路（引擎）', () {
    test('未配置 AI Key → 本地导演接手，照样有剧情有选项', () async {
      final engine = _engine();
      final result = await engine.runStoryTurn();
      expect(result.isSuccess, true);
      expect(result.isLocal, true);
      expect(result.choices.length, inInclusiveRange(2, 4));
      expect(result.note, contains('未配置 AI Key'));
      expect(result.lines.single.length, greaterThan(80));
    });

    test('主 AI 不可用（无 Key 的注入实例）→ 降级本地并说明原因', () async {
      final engine = _engine();
      final result = await engine.runStoryTurn(service: AiService());
      expect(result.isSuccess, true);
      expect(result.isLocal, true);
      expect(result.note, contains('主 AI 本回合不可用'));
      expect(result.choices.length, inInclusiveRange(2, 4));
    });

    test('主 AI 可用 → 用主 AI 的叙事与选项', () async {
      final engine = _engine();
      final content = '{"narrative":"主 AI 生成的叙事",'
          '"choices":['
          '{"text":"选项甲","effects":{"gold":-5},"narrative":"甲"},'
          '{"text":"选项乙","effects":{"reputation":-3},"narrative":"乙"}]}';
      final result = await engine.runStoryTurn(service: _fakeAi(content));
      expect(result.isSuccess, true);
      expect(result.isLocal, false);
      expect(result.lines.single, '主 AI 生成的叙事');
      expect(result.choices.length, 2);
      expect(result.choices.first.text, '选项甲');
    });

    test('待决事件被剧情回合接管呈现（不留点不动的死卡片）', () async {
      final engine = _engine();
      final pending = allEvents.first;
      engine.setPendingEvent(pending);
      final result = await engine.runStoryTurn();
      expect(engine.pendingEvent, isNull);
      expect(result.lines.single, contains(pending.name));
    });

    test('applyStoryChoice：效果落盘并推进一个月', () async {
      final engine = _engine();
      final beforeTurn = engine.progress.turnCount;
      final text = engine.applyStoryChoice(
        const EventChoice(
          id: 's16_choice',
          text: '测试选项',
          requirements: <String, int>{},
          effects: <String, int>{'gold': 7},
          narrative: '选项叙事',
        ),
      );
      expect(text, contains('选项叙事'));
      expect(engine.progress.turnCount, beforeTurn + 1);
    });
  });

  group('S16 主界面剧情回路', () {
    testWidgets('进入即开场：不用打字就有剧情选项卡', (tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final engine = _engine();
      await tester.pumpWidget(
        MaterialApp(home: GameScreen(engine: engine)),
      );
      await tester.pumpAndSettle();

      expect(find.text('选择你的下一步'), findsOneWidget);
      expect(find.byType(AiChoiceCard), findsWidgets);
    });

    testWidgets('点选项 → 落盘并自动开下一回合', (tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final engine = _engine();
      await tester.pumpWidget(
        MaterialApp(home: GameScreen(engine: engine)),
      );
      await tester.pumpAndSettle();

      final beforeTurn = engine.progress.turnCount;
      await tester.tap(find.byType(AiChoiceCard).first);
      await tester.pumpAndSettle();

      expect(engine.progress.turnCount, beforeTurn + 1);
      // 下一回合的选项已经就位（剧情回路闭环）
      expect(find.byType(AiChoiceCard), findsWidgets);
    });
  });
}
