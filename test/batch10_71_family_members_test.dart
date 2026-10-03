/// Batch 10-71 测试：AI 注入家族谱系成员关系。
///
/// 覆盖：
/// 1. 有家族玩家 → 注入同族成员清单（名字/身份/所在地/与玩家的关系）
/// 2. 自由民玩家 → 兜底「自由民，无家族可依附」
/// 3. 在世同族为空 → 兜底「暂无在世同族」
/// 4. 既有注入（世代谱系/家族/对外关系/特质/秘密）不回归
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/models/player.dart';
import 'package:westeros_life_simulator/services/ai_service.dart';

/// 构造捕获请求体的 mock Dio。
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

Future<String> _promptFor(Player player) async {
  final (dio, captured) = _captureDio();
  final service = AiService(
    apiKey: 'test_key',
    dio: dio,
    baseUrl: 'https://mock.example.com/v1',
  );
  await service.generateNarrative(
    player: player,
    context: '测试',
    availableEvents: const [],
    season: 'winter',
    maxRetries: 0,
  );
  expect(captured[0], isNotNull);
  return captured[0]!;
}

/// 提取「家族成员」行内容（「- 家族成员：」行）。
String _familyMembersLine(String body) {
  final start = body.indexOf('- 家族成员：');
  expect(start, greaterThanOrEqualTo(0));
  final end = body.indexOf('\n', start);
  expect(end, greaterThan(start));
  return body.substring(start, end);
}

void main() {
  group('Batch 10-71 家族谱系成员注入', () {
    test('有家族玩家 → 注入同族成员（史塔克家族在世成员）', () async {
      final body = await _promptFor(Player.defaultPlayer());
      final line = _familyMembersLine(body);
      expect(line, contains('家族成员：'));
      // 史塔克家族在世成员应至少出现若干知名 NPC
      expect(line, contains('艾德·史塔克'));
      expect(line, contains('罗柏·史塔克'));
      // 成员条目含身份与所在地与关系
      expect(line, contains('贵族'));
      expect(line, contains('临冬城'));
      expect(line, contains('关系 0'));
    });

    test('玩家与同族成员有私交 → 关系值体现', () async {
      final body = await _promptFor(
        Player.defaultPlayer().copyWith(
          relations: const {'npc_nev': 60},
        ),
      );
      final line = _familyMembersLine(body);
      expect(line, contains('关系 60'));
    });

    test('自由民玩家 → 兜底「自由民，无家族可依附」', () async {
      final body = await _promptFor(
        Player.defaultPlayer().copyWith(
          familyId: '',
        ),
      );
      final line = _familyMembersLine(body);
      expect(line, contains('自由民，无家族可依附'));
    });

    test('既有注入（世代谱系/家族/对外关系/特质/秘密/成员）不回归', () async {
      final body = await _promptFor(Player.defaultPlayer());
      expect(body, contains('- 世代谱系：'));
      expect(body, contains('- 家族：'));
      expect(body, contains('- 家族成员：'));
      expect(body, contains('族语「凛冬将至」'));
      expect(body, contains('对外关系：'));
      expect(body, contains('特质：'));
      expect(body, contains('秘密：'));
      expect(body, contains('本月世界局势：'));
    });
  });
}