/// M5 体验层测试（Batch 10-34 · AI 失败降级 + 长会话叙事）。
///
/// 覆盖：
/// 1. AI 请求失败 → 装配失败行 + 降级提示行（本地指令可续玩），不抛异常不留死状态
/// 2. AI 失败后本地指令照常可用（状态/帮助），游戏可继续
/// 3. 200 条叙事行长会话：ListView.builder 懒加载渲染首尾行不崩，滚动契约成立
/// 4. 降级提示常量文案唯一且非空
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/models/ai_turn.dart';
import 'package:westeros_life_simulator/models/event.dart';
import 'package:westeros_life_simulator/screens/game_screen.dart';
import 'package:westeros_life_simulator/services/ai_config.dart';
import 'package:westeros_life_simulator/services/ai_service.dart';
import 'package:westeros_life_simulator/widgets/game/narrative.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('M5 · AI 失败降级', () {
    test('请求失败 → 失败行 + 降级提示行，isSuccess=false', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await _configureAiKey();
      final engine = GameEngine()..startNewGame();
      final result = await engine.runAiAction(
        '巡视城墙',
        service: _mockService(_MockKind.badRequest),
      );
      expect(result.isSuccess, false);
      expect(result.lines.length, 2);
      expect(result.lines.first, contains('⚠️ AI 生成失败'));
      expect(result.lines.last, AiTurnResult.degradedLine);
      expect(result.lines.last, contains('本地指令'));
      expect(result.choices, isEmpty);
    });

    test('AI 失败后本地指令照常可用（状态/帮助不抛异常）', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await _configureAiKey();
      final engine = GameEngine()..startNewGame();
      // 先触发一次失败，确认不污染引擎状态
      final result = await engine.runAiAction(
        '巡视城墙',
        service: _mockService(_MockKind.badRequest),
      );
      expect(result.isSuccess, false);
      // 本地指令继续游玩
      final status = engine.resolveCommand('状态');
      expect(status.text, isNotEmpty);
      expect(status.text, contains('岁'));
      final help = engine.resolveCommand('帮助');
      expect(help.text, contains('帮助'));
      // 世界状态未被 AI 失败破坏
      expect(engine.player.gold, greaterThanOrEqualTo(0));
      expect(engine.progress.turnCount, 0);
    });

    test('降级提示常量：唯一、非空、与配置提示不同', () {
      expect(AiTurnResult.degradedLine, isNotEmpty);
      expect(AiTurnResult.degradedLine, isNot(AiTurnResult.notConfiguredLine));
      expect(AiTurnResult.degradedLine, isNot(AiTurnResult.notStartedLine));
    });
  });

  group('M5 · 200 条叙事长会话', () {
    testWidgets('NarrativeView 直接渲染 200 条：首行可见 + 懒加载正常', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final lines = List<String>.generate(
        200,
        (i) => '叙事行 $i',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NarrativeView(
              lines: lines,
              scrollController: ScrollController(),
              engine: GameEngine()..startNewGame(),
              onOpenPanel: (_) {},
              aiChoices: <EventChoice>[],
              onChooseAi: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 首行可见（ListView.builder 保序渲染）
      expect(find.text('叙事行 0'), findsOneWidget);
    });

    testWidgets('200 条叙事流畅滚动到底：末行可见', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final lines = List<String>.generate(
        200,
        (i) => '叙事行 $i',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NarrativeView(
              lines: lines,
              scrollController: ScrollController(),
              engine: GameEngine()..startNewGame(),
              onOpenPanel: (_) {},
              aiChoices: <EventChoice>[],
              onChooseAi: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 滚动到底：末行出现（懒加载 + 流畅滚动契约）
      await tester.scrollUntilVisible(
        find.text('叙事行 199'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('叙事行 199'), findsOneWidget);
    });

    testWidgets('1000 条叙事不崩（更长会话上限）', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final lines = List<String>.generate(
        1000,
        (i) => '叙事行 $i',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NarrativeView(
              lines: lines,
              scrollController: ScrollController(),
              engine: GameEngine()..startNewGame(),
              onOpenPanel: (_) {},
              aiChoices: <EventChoice>[],
              onChooseAi: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('叙事行 0'), findsOneWidget);
    });

    testWidgets('GameScreen 冒烟：构建 + 初始叙事契约不回归', (tester) async {
      tester.view.physicalSize = const Size(1080, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final engine = GameEngine()..startNewGame();
      await tester.pumpWidget(
        MaterialApp(home: GameScreen(engine: engine)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('欢迎来到维斯特洛'), findsOneWidget);
      expect(find.text('AI 行动模式'), findsOneWidget);
    });
  });
}

/// 配置一个测试用 AI Key（跳过「未配置」短路）。
Future<void> _configureAiKey() async {
  final config = AiConfig(
    apiKey: 'test_key_m5',
    model: 'test-model',
    baseUrl: 'https://mock.example.com/v1',
  );
  await config.save();
}

/// mock 种类。
enum _MockKind { badRequest, narrativeOnly }

/// 构造一个不触网的 [AiService]（Dio 拦截器直接返回预设响应）。
AiService _mockService(_MockKind kind) {
  final dio = Dio(
    BaseOptions(baseUrl: 'https://mock.example.com/v1'),
  );
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (kind == _MockKind.badRequest) {
          handler.reject(
            DioException(
              requestOptions: options,
              response: Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 400,
                data: <String, dynamic>{'error': 'bad request'},
              ),
              message: 'HTTP 400',
              type: DioExceptionType.badResponse,
            ),
          );
          return;
        }
        handler.resolve(
          Response<Map<String, dynamic>>(
            requestOptions: options,
            statusCode: 200,
            data: <String, dynamic>{
              'choices': [
                <String, dynamic>{
                  'message': <String, dynamic>{
                    'content': '守夜人在城墙上点起火炬。',
                  },
                },
              ],
            },
          ),
        );
      },
    ),
  );
  return AiService(
    apiKey: 'test_key_m5',
    model: 'test-model',
    baseUrl: 'https://mock.example.com/v1',
    dio: dio,
  );
}
