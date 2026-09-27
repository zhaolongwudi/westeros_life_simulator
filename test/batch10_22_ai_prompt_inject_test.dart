/// Batch 10-22 测试：AI prompt 注入增强。
///
/// 覆盖：
/// 1. 在场 NPC 注入多步骤任务模板（标题/难度/期限，替代旧 tasks.first）
/// 2. 家族信息注入（家族名/族语/规模/影响力）
/// 3. 自由民无家族空态提示
/// 4. 既有注入（世代谱系/头衔晋升）不回归
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/models/event.dart';
import 'package:westeros_life_simulator/models/player.dart';
import 'package:westeros_life_simulator/services/ai_service.dart';

/// 构造一个捕获请求体并返回 mock 响应的 Dio。
(Dio, List<String?>) _captureDio() {
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
  return (dio, captured);
}

void main() {
  group('Batch 10-22 在场 NPC 多步骤任务注入', () {
    test('在场 NPC 可委托注入标题/难度/期限', () async {
      final (dio, captured) = _captureDio();
      final service = AiService(
        apiKey: 'test_key',
        dio: dio,
        baseUrl: 'https://mock.example.com/v1',
      );
      // 默认玩家在临冬城，艾德·史塔克在场且有 2 个多步骤任务模板
      await service.generateNarrative(
        player: Player.defaultPlayer(),
        context: '你在临冬城的庭院里。',
        availableEvents: const <GameEvent>[],
        maxRetries: 0,
      );

      expect(captured[0], isNotNull);
      final body = captured[0]!;
      expect(body, contains('在场 NPC'));
      expect(body, contains('艾德·史塔克'));
      expect(body, contains('可委托'));
      expect(body, contains('护送北境信使至君临'));
      expect(body, contains('难度 3'));
      expect(body, contains('期限 6 月'));
      expect(body, contains('调查野人踪迹'));
      expect(body, contains('难度 2'));
    });
  });

  group('Batch 10-22 家族信息注入', () {
    test('家族名/族语/规模/影响力进入请求体', () async {
      final (dio, captured) = _captureDio();
      final service = AiService(
        apiKey: 'test_key',
        dio: dio,
        baseUrl: 'https://mock.example.com/v1',
      );
      await service.generateNarrative(
        player: Player.defaultPlayer(), // family_stark
        context: '测试',
        availableEvents: const <GameEvent>[],
        maxRetries: 0,
      );

      expect(captured[0], isNotNull);
      final body = captured[0]!;
      expect(body, contains('家族'));
      expect(body, contains('史塔克家族'));
      expect(body, contains('凛冬将至'));
      expect(body, contains('大家族'));
      expect(body, contains('影响力 70'));
    });

    test('自由民无家族注入空态', () async {
      final (dio, captured) = _captureDio();
      final service = AiService(
        apiKey: 'test_key',
        dio: dio,
        baseUrl: 'https://mock.example.com/v1',
      );
      final player = Player.defaultPlayer().copyWith(familyId: 'family_none');
      await service.generateNarrative(
        player: player,
        context: '测试',
        availableEvents: const <GameEvent>[],
        maxRetries: 0,
      );

      expect(captured[0], isNotNull);
      expect(captured[0], contains('（自由民，无家族）'));
    });
  });

  group('Batch 10-22 既有注入不回归', () {
    test('世代谱系与头衔晋升仍注入', () async {
      final (dio, captured) = _captureDio();
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
      final body = captured[0]!;
      expect(body, contains('世代谱系'));
      expect(body, contains('头衔晋升'));
      expect(body, contains('第一代家主'));
    });
  });
}