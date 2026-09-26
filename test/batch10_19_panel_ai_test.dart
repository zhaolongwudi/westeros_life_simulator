/// Batch 10-19 测试：UI 面板展示婚姻/任务新数据 + AI prompt 注入 + 任务模板扩充。
///
/// 覆盖：
/// 1. player_panel UI：婚姻与子女培养区块（配偶/培养方向/督导/送学/声望）
/// 2. npc_panel UI：进行中任务区块（标题/状态/期限）
/// 3. AI prompt 注入：婚姻/子女/进行中任务信息进入请求体
/// 4. NPC 任务模板扩充：琼恩/瑟曦/奥莲娜 可接任务
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/models/event.dart';
import 'package:westeros_life_simulator/models/marital.dart';
import 'package:westeros_life_simulator/models/npc_task.dart';
import 'package:westeros_life_simulator/models/player.dart';
import 'package:westeros_life_simulator/screens/npc_panel_screen.dart';
import 'package:westeros_life_simulator/screens/player_panel_screen.dart';
import 'package:westeros_life_simulator/services/ai_service.dart';

void main() {
  group('Batch 10-19 player_panel 婚姻与培养区块', () {
    testWidgets('已婚有子女显示配偶与培养档案', (tester) async {
      tester.view.physicalSize = const Size(1080, 12000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final engine = GameEngine()..startNewGame();
      // 走真实成婚路径构造婚姻数据
      final marryResult = engine.marry('平民');
      expect(marryResult, contains('成婚'));
      // 走真实添丁路径构造子女
      engine.addChild('罗柏');
      engine.rearChild('罗柏', 'sword');
      engine.tutorChild('罗柏');

      expect(engine.isMarried, true);
      expect(engine.player.children, isNotEmpty);

      await tester.pumpWidget(
        MaterialApp(home: PlayerPanelScreen(engine: engine)),
      );
      await tester.pumpAndSettle();

      expect(find.text('婚姻与子女培养'), findsOneWidget);
      expect(find.textContaining('配偶：'), findsOneWidget);
      expect(find.textContaining('罗柏'), findsWidgets);
      expect(find.textContaining('培养：sword'), findsOneWidget);
      expect(find.textContaining('已督导'), findsOneWidget);
    });

    testWidgets('未婚无子女不显示培养区块', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final engine = GameEngine()..startNewGame();
      await tester.pumpWidget(
        MaterialApp(home: PlayerPanelScreen(engine: engine)),
      );
      await tester.pumpAndSettle();

      expect(find.text('婚姻与子女培养'), findsNothing);
    });
  });

  group('Batch 10-19 npc_panel 任务进度区块', () {
    testWidgets('进行中任务显示标题与期限', (tester) async {
      tester.view.physicalSize = const Size(1080, 12000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final engine = GameEngine()..startNewGame();
      // 走真实接任务路径构造进行中任务
      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{'npc_nev': 25},
        ),
      );
      final acceptResult = engine.acceptNpcTaskV2('npc_nev');
      expect(acceptResult, contains('接下'));
      expect(engine.activeTasks, hasLength(1));

      await tester.pumpWidget(
        MaterialApp(home: NpcPanelScreen(engine: engine)),
      );
      await tester.pumpAndSettle();

      expect(find.text('进行中的任务'), findsOneWidget);
      // 「护送北境信使至君临」同时出现在在场 NPC 可委托与进行中任务两处
      expect(find.textContaining('护送北境信使至君临'), findsNWidgets(2));
      expect(find.textContaining('⏳ 进行中｜期限'), findsOneWidget);
      expect(find.textContaining('⏳ 进行中'), findsWidgets);
    });

    testWidgets('无任务显示空态', (tester) async {
      tester.view.physicalSize = const Size(1080, 12000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final engine = GameEngine()..startNewGame();
      await tester.pumpWidget(
        MaterialApp(home: NpcPanelScreen(engine: engine)),
      );
      await tester.pumpAndSettle();

      expect(find.text('进行中的任务'), findsOneWidget);
      expect(find.text('目前没有进行中的任务。'), findsOneWidget);
    });
  });

  group('Batch 10-19 AI prompt 注入新数据', () {
    test('婚姻/子女/进行中任务注入请求体', () async {
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
        spouse: const SpouseDetail(
          name: '梅拉',
          origin: SpouseOrigin.commoner,
          marriedYear: 283,
        ),
        children: const ['罗柏'],
        childRearing: const [
          ChildRearing(name: '罗柏', focus: 'sword', tutored: true),
        ],
        activeTasks: const [
          NpcTaskProgress(
            taskId: 'task_nev_escort',
            npcId: 'npc_nev',
            title: '护送北境信使至君临',
            stepIndex: 0,
            stepProgress: 0,
            deadlineYear: 283,
            deadlineMonth: 9,
          ),
        ],
      );
      await service.generateNarrative(
        player: player,
        context: '你在临冬城的庭院里。',
        availableEvents: const <GameEvent>[],
        season: 'summer',
        currentYear: 285,
        maxRetries: 0,
      );

      expect(captured[0], isNotNull);
      final body = captured[0]!;
      expect(body, contains('婚姻'));
      expect(body, contains('梅拉'));
      expect(body, contains('结婚 2 年'));
      expect(body, contains('子女'));
      expect(body, contains('培养 sword'));
      expect(body, contains('进行中任务'));
      expect(body, contains('护送北境信使至君临'));
    });

    test('未婚无任务玩家注入空态提示', () async {
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
                        'content': '{"narrative":"测试","choices":[]}',
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
      await service.generateNarrative(
        player: Player.defaultPlayer(),
        context: '测试',
        availableEvents: const <GameEvent>[],
        maxRetries: 0,
      );

      expect(captured[0], isNotNull);
      expect(captured[0], contains('（未婚）'));
      expect(captured[0], contains('（无子女）'));
      expect(captured[0], contains('（无进行中任务）'));
    });
  });

  group('Batch 10-19 NPC 任务模板扩充', () {
    test('琼恩·雪诺有可接任务', () {
      final engine = GameEngine()..startNewGame();
      final tasks = engine.availableTasksOf('npc_jon_snow');
      expect(tasks, isNotEmpty);
      expect(tasks.map((t) => t.title), contains('长城巡逻与补给'));
      expect(tasks.map((t) => t.title), contains('寻找失踪的冰原狼'));
    });

    test('瑟曦有可接任务', () {
      final engine = GameEngine()..startNewGame();
      final tasks = engine.availableTasksOf('npc_cersei');
      expect(tasks, isNotEmpty);
      expect(tasks.map((t) => t.title), contains('揪出宫中的叛徒'));
      expect(tasks.map((t) => t.title), contains('散布王后的流言'));
    });

    test('奥莲娜·提利尔有可接任务', () {
      final engine = GameEngine()..startNewGame();
      final tasks = engine.availableTasksOf('npc_olenna_tyrell');
      expect(tasks, isNotEmpty);
      expect(tasks.map((t) => t.title), contains('运一批高庭红酒至君临'));
      expect(tasks.map((t) => t.title), contains('为玛格丽物色夫婿'));
    });
  });
}