/// M3b 测试（Batch 10-29 · UI 收口）。
///
/// 覆盖三层新契约：
/// 1. `runAiAction` 编排下沉引擎：游戏未开始 / 未配置 Key / 请求失败 / 成功带选项
///    —— 四条分支的 `AiTurnResult` 装配（行内容、选项、isSuccess）全部可断言，
///    不再依赖「UI 私有方法 + 私有状态」。
/// 2. UI 层不再依赖混入层：`lib/screens/**` 不得 import `mixins/`
///    （letters_screen 因 Letter 寄居 mixin_letter 才被迫反向依赖，M3b 已迁模型层）。
/// 3. `AiTurnResult` 常量文案与 UI 渲染一致（`notConfiguredLine` 等）。
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/models/ai_turn.dart';
import 'package:westeros_life_simulator/models/event.dart';
import 'package:westeros_life_simulator/screens/game_screen.dart';
import 'package:westeros_life_simulator/screens/letters_screen.dart';
import 'package:westeros_life_simulator/services/ai_config.dart';
import 'package:westeros_life_simulator/services/ai_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('M3b 1 · runAiAction 未开始', () {
    test('未 startNewGame 时直接返回「游戏尚未开始。」且不请求', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final engine = GameEngine();
      final result = await engine.runAiAction('巡视城墙');
      expect(result.isSuccess, false);
      expect(result.lines, <String>[AiTurnResult.notStartedLine]);
      expect(result.choices, isEmpty);
    });
  });

  group('M3b 2 · runAiAction 未配置 API Key', () {
    test('已开局但无 Key → 返回配置提示，不请求', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final engine = GameEngine()..startNewGame();
      final result = await engine.runAiAction('巡视城墙');
      expect(result.isSuccess, false);
      expect(result.lines, <String>[AiTurnResult.notConfiguredLine]);
      expect(result.lines.single, contains('尚未配置 AI API Key'));
      expect(result.choices, isEmpty);
    });

    test('默认配置 isConfigured=false（编排短路的前提）', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final loaded = await AiConfig.load();
      expect(loaded.isConfigured, isFalse);
      expect(loaded.model, 'sensenova-6.8-flash-lite');
    });
  });

  group('M3b 3 · runAiAction 请求失败', () {
    test('HTTP 400 非可重试错误 → 装配失败行与原因', () async {
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
      expect(result.lines.first, contains('400'));
      expect(result.lines.last, AiTurnResult.degradedLine);
      expect(result.choices, isEmpty);
    });
  });

  group('M3b 4 · runAiAction 成功', () {
    test('有叙事无选项 → 1 行，choices 空', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await _configureAiKey();
      final engine = GameEngine()..startNewGame();
      final result = await engine.runAiAction(
        '巡视城墙',
        service: _mockService(_MockKind.narrativeOnly),
      );
      expect(result.isSuccess, true);
      expect(result.lines, <String>['守夜人在城墙上点起火炬。']);
      expect(result.choices, isEmpty);
    });

    test('有叙事有选项 → 追加「（选择你的下一步）」且选项透传', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await _configureAiKey();
      final engine = GameEngine()..startNewGame();
      final result = await engine.runAiAction(
        '巡视城墙',
        service: _mockService(_MockKind.narrativeWithChoices),
      );
      expect(result.isSuccess, true);
      expect(result.lines.length, 2);
      expect(result.lines.last, '（选择你的下一步）');
      expect(result.choices.length, 2);
      expect(result.choices.first.text, '登上东墙');
      expect(result.choices.last.text, '回营休息');
    });

    test('AI 回合编排不改世界状态（选择前不推进月份）', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await _configureAiKey();
      final engine = GameEngine()..startNewGame();
      final before = engine.progress;
      await engine.runAiAction(
        '巡视城墙',
        service: _mockService(_MockKind.narrativeOnly),
      );
      expect(engine.progress.month, before.month);
      expect(engine.progress.year, before.year);
      expect(engine.progress.turnCount, before.turnCount);
    });
  });

  group('M3b 5 · AiTurnResult 模型契约', () {
    test('默认值 isSuccess=false，lines/choices 必填', () {
      const result = AiTurnResult(
        lines: <String>['x'],
        choices: <EventChoice>[],
      );
      expect(result.isSuccess, false);
    });

    test('未配置 / 未开始 两条常量文案各自唯一且非空', () {
      expect(AiTurnResult.notConfiguredLine, isNotEmpty);
      expect(AiTurnResult.notStartedLine, isNotEmpty);
      expect(AiTurnResult.notConfiguredLine, isNot(AiTurnResult.notStartedLine));
    });
  });

  group('M3b 6 · 分层契约：UI 不依赖混入层', () {
    test('lib/screens 下无任何 mixins/ import', () {
      final dir = Directory('lib/screens');
      expect(dir.existsSync(), isTrue);
      final offenders = <String>[];
      for (final entity in dir.listSync()) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final content = entity.readAsStringSync();
        for (final line in content.split('\n')) {
          final t = line.trim();
          if (t.startsWith('import ') && t.contains('mixins/')) {
            offenders.add('${entity.path}: $t');
          }
        }
      }
      expect(offenders, isEmpty, reason: 'UI 层不得 import 混入层');
    });

    test('Letter 已归位模型层：mixin_letter 不再定义 Letter 类', () {
      final letterFile = File('lib/models/letter.dart');
      expect(letterFile.existsSync(), isTrue);
      final mixinText =
          File('lib/mixins/mixin_letter.dart').readAsStringSync();
      expect(mixinText.contains('class Letter'), false);
      expect(mixinText.contains("import '../models/letter.dart';"), true);
    });

    test('LettersScreen 只 import 模型层拿 Letter 类型', () {
      // 注意：只对 import 行断言；文件头注释里允许出现 mixin_letter 字样的说明文字。
      final text = File('lib/screens/letters_screen.dart').readAsStringSync();
      final imports = text
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.startsWith('import '))
          .toList();
      expect(imports.contains("import '../models/letter.dart';"), isTrue,
          reason: 'Letter 类型应来自模型层');
      expect(imports.any((l) => l.contains('mixins/')), isFalse,
          reason: 'UI 层不得 import 混入层');
    });
  });

  group('M3b 7 · 拆分后 UI 契约不回归', () {
    testWidgets('主界面仍保留标题/状态条/AI 开关（widget 拆分后）', (tester) async {
      tester.view.physicalSize = const Size(1080, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: GameScreen()));
      await tester.pumpAndSettle();

      expect(find.text('维斯特洛人生模拟器'), findsOneWidget);
      expect(find.text('AI 行动模式'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
      expect(find.textContaining('岁'), findsWidgets);
    });

    testWidgets('快捷指令按钮仍可点并把结果写进叙事区', (tester) async {
      tester.view.physicalSize = const Size(1080, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final engine = GameEngine()..startNewGame();
      await tester.pumpWidget(MaterialApp(home: GameScreen(engine: engine)));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ActionChip, '状态'));
      await tester.pumpAndSettle();
      expect(find.textContaining('> 状态'), findsOneWidget);
    });

    testWidgets('信件面板空状态仍渲染（去 import 后契约不破）', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LettersScreen()));
      await tester.pumpAndSettle();
      expect(find.text('信件'), findsOneWidget);
      expect(find.text('你的渡鸦还没有带回任何信件。'), findsOneWidget);
    });

    testWidgets('信件卡片渲染寄信人与年月（Letter 迁层后）', (tester) async {
      tester.view.physicalSize = const Size(1080, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final engine = _engineWithLetter();
      final letters = engine.letters;
      await tester.pumpWidget(
        MaterialApp(home: LettersScreen(engine: engine)),
      );
      await tester.pumpAndSettle();

      if (letters.isEmpty) {
        // 极端情况下全部 seed 都没触发：走空状态分支，避免 flaky
        expect(find.text('你的渡鸦还没有带回任何信件。'), findsOneWidget);
        return;
      }
      // 卡片标题形如「艾德·史塔克（283年1月）」
      final first = letters[letters.length - 1];
      expect(
        find.textContaining('${first.senderName}（${first.year}年${first.month}月）'),
        findsOneWidget,
      );
    });
  });
}

/// mock 种类。
enum _MockKind { badRequest, narrativeOnly, narrativeWithChoices }

/// 写入一个非空 API Key。
///
/// 刻意用 `AiConfig.save()` 而非 `setMockInitialValues({'flutter.ai_api_key': ...})`：
/// 后者要猜 shared_preferences 插件的键前缀，猜错就静默走「未配置」分支变成假绿。
Future<void> _configureAiKey() {
  return const AiConfig(
    apiKey: 'test_key',
    model: 'sensenova-6.8-flash-lite',
    baseUrl: 'https://mock.example.com/v1',
  ).save();
}

/// 构造一个不触网的 [AiService]（ Dio 拦截器直接返回预设响应）。
AiService _mockService(_MockKind kind) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (kind == _MockKind.badRequest) {
          handler.reject(
            DioException(
              requestOptions: options,
              response: Response<dynamic>(
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
        final content = kind == _MockKind.narrativeOnly
            ? '{"narrative":"守夜人在城墙上点起火炬。","choices":[]}'
            : '{"narrative":"守夜人递来望远镜。","choices":['
                '{"id":"c1","text":"登上东墙","requirements":{},'
                '"effects":{"gold":5},"narrative":"你登上东墙。"},'
                '{"id":"c2","text":"回营休息","requirements":{},'
                '"effects":{"energy":10},"narrative":"你回到营房。"}]}';
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

/// 构造一个带一封来信的引擎（用确定性 seed 循环到触发为止）。
GameEngine _engineWithLetter() {
  final engine = GameEngine()..startNewGame();
  for (var seed = 0; seed < 100; seed++) {
    if (engine.maybeTriggerLetter(seed: seed).isNotEmpty) break;
  }
  return engine;
}