/// Batch 10-20 测试：多代家族树 UI 可视化 + AI 注入世代谱系/头衔晋升。
///
/// 覆盖：
/// 1. family_tree_screen：无谱系时仅当前世代（家主/未婚/无子女空态）
/// 2. family_tree_screen：有谱系时历代家主链 + 当前世代（配偶/子女/继承人）
/// 3. family_screen：家族树入口（查看家族树 + 世代数）
/// 4. AI prompt 注入：世代谱系（先祖链）与头衔晋升进度进入请求体
/// 5. AI prompt 注入：第一代家主/暂无头衔空态
library;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/models/event.dart';
import 'package:westeros_life_simulator/models/marital.dart';
import 'package:westeros_life_simulator/models/player.dart';
import 'package:westeros_life_simulator/screens/family_screen.dart';
import 'package:westeros_life_simulator/screens/family_tree_screen.dart';
import 'package:westeros_life_simulator/services/ai_service.dart';

void main() {
  group('Batch 10-20 家族树 UI：无谱系（第一代）', () {
    testWidgets('未婚无子女显示当前世代与空态', (tester) async {
      tester.view.physicalSize = const Size(1080, 12000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final engine = GameEngine()..startNewGame();
      await tester.pumpWidget(
        MaterialApp(home: FamilyTreeScreen(engine: engine)),
      );
      await tester.pumpAndSettle();
      expect(find.text('家族树'), findsOneWidget);
      expect(find.textContaining('第 1 代'), findsOneWidget);
      expect(find.text('历代家主'), findsNothing);
      expect(find.text('当前世代'), findsOneWidget);
      expect(find.textContaining('家主：'), findsOneWidget);
      expect(find.text('子女：尚无子嗣'), findsOneWidget);
      expect(find.textContaining('继承人：'), findsNothing);
    });
    testWidgets('已婚有子女显示配偶与培养档案', (tester) async {
      tester.view.physicalSize = const Size(1080, 12000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final engine = GameEngine()..startNewGame();
      engine.marry('平民');
      engine.addChild('罗柏');
      engine.rearChild('罗柏', 'sword');
      engine.tutorChild('罗柏');
      await tester.pumpWidget(
        MaterialApp(home: FamilyTreeScreen(engine: engine)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('配偶：'), findsOneWidget);
      expect(find.text('子女：'), findsOneWidget);
      expect(find.textContaining('罗柏：培养：sword'), findsOneWidget);
      // 109 卡片行也含「已督导」，锚定支脉节点完整串（带姓名前缀）保持唯一
      expect(find.textContaining('罗柏：培养：sword / 已督导'), findsOneWidget);
      expect(find.textContaining('继承人：罗柏'), findsOneWidget);
    });
  });

  group('Batch 10-20 家族树 UI：多代谱系', () {
    testWidgets('传承两代后历代家主链 + 继承提示', (tester) async {
      tester.view.physicalSize = const Size(1080, 12000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final engine = GameEngine()..startNewGame();
      // 构造多代：第一代玩家 → 传承 → 第二代（谱系 1 条）→ 再传 → 第三代（谱系 2 条）
      engine.addChild('罗柏');
      final gen2 = engine.advanceGeneration();
      expect(gen2, isNotNull);
      engine.addChild('琼恩');
      final gen3 = engine.advanceGeneration();
      expect(gen3, isNotNull);
      expect(engine.player.generationRecords, hasLength(2));
      await tester.pumpWidget(
        MaterialApp(home: FamilyTreeScreen(engine: engine)),
      );
      await tester.pumpAndSettle();
      expect(find.text('历代家主'), findsOneWidget);
      expect(find.text('第 1 代'), findsOneWidget);
      expect(find.text('第 2 代'), findsOneWidget);
      // 标题含完整文本「史塔克家 · 第 3 代」，用 textContaining
      expect(find.textContaining('第 3 代'), findsOneWidget);
      expect(find.textContaining('家主：琼恩'), findsOneWidget);
      expect(find.textContaining('接过先祖的传承'), findsOneWidget);
    });
  });

  group('Batch 10-20 家族面板入口', () {
    testWidgets('我的家族卡片下显示查看家族树入口', (tester) async {
      tester.view.physicalSize = const Size(1080, 12000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final engine = GameEngine()..startNewGame();
      await tester.pumpWidget(
        MaterialApp(home: FamilyScreen(engine: engine)),
      );
      await tester.pumpAndSettle();
      expect(find.text('我的家族'), findsOneWidget);
      expect(find.text('查看家族树'), findsOneWidget);
      expect(find.textContaining('第 1 代'), findsOneWidget);
    });
  });

  group('Batch 10-20 AI 注入世代谱系与头衔晋升', () {
    test('多代玩家注入先祖链与头衔晋升', () async {
      final captured = <String?>[null];
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            captured[0] = options.data.toString();
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: <String, dynamic>{
                  'choices': <dynamic>[
                    <String, dynamic>{
                      'message': <String, dynamic>{
                        'content': '{"narrative":"测试叙事","choices":[]}',
                      },
                    },
                  ],
                },
              ),
            );
          },
        ),
      );
      final service = AiService(
        apiKey: 'test_key',
        dio: dio,
        baseUrl: 'https://mock.example.com/v1',
      );
      final player = Player.defaultPlayer().copyWith(
        title: '北境守护',
        reputation: 85,
        generationRecords: const [
          GenerationRecord(
            generation: 1,
            name: '艾德',
            reignYears: '30年',
            title: '临冬城公爵',
            achievement: '声望 70',
          ),
          GenerationRecord(
            generation: 2,
            name: '罗柏',
            reignYears: '12年',
            title: '北境之王',
            achievement: '声望 80',
          ),
        ],
      );
      await service.generateNarrative(
        player: player,
        context: '你在临冬城的庭院里。',
        availableEvents: const <GameEvent>[],
        season: 'winter',
        currentYear: 298,
        maxRetries: 0,
      );
      expect(captured[0], isNotNull);
      final body = captured[0]!;
      expect(body, contains('世代谱系'));
      expect(body, contains('第 3 代'));
      expect(body, contains('1代 艾德'));
      expect(body, contains('2代 罗柏'));
      expect(body, contains('临冬城公爵'));
      expect(body, contains('头衔晋升'));
      expect(body, contains('北境守护'));
      expect(body, contains('85/100'));
      expect(body, contains('已登顶本身份头衔巅峰'));
    });
    test('第一代无头衔玩家注入空态', () async {
      final captured = <String?>[null];
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            captured[0] = options.data.toString();
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: <String, dynamic>{
                  'choices': <dynamic>[
                    <String, dynamic>{
                      'message': <String, dynamic>{
                        'content': '{"narrative":"测试叙事","choices":[]}',
                      },
                    },
                  ],
                },
              ),
            );
          },
        ),
      );
      final service = AiService(
        apiKey: 'test_key',
        dio: dio,
        baseUrl: 'https://mock.example.com/v1',
      );
      final player = Player.defaultPlayer().copyWith(
        title: '',
        generationRecords: const <GenerationRecord>[],
      );
      await service.generateNarrative(
        player: player,
        context: '你在君临的市集里。',
        availableEvents: const <GameEvent>[],
        season: 'summer',
        currentYear: 283,
        maxRetries: 0,
      );
      expect(captured[0], isNotNull);
      final body = captured[0]!;
      expect(body, contains('世代谱系'));
      expect(body, contains('第一代家主'));
      expect(body, contains('头衔晋升'));
      expect(body, contains('暂无头衔'));
    });
  });
}
