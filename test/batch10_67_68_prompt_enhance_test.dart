/// Batch 10-67/68 测试：AI prompt 注入增强（家族特质/秘密 + 关系 NPC 秘密）。
///
/// Batch 10-67 覆盖：
/// 1. 家族注入特质（史塔克家族：坚韧·忠诚·荣誉·战斗）
/// 2. 家族注入秘密（史塔克家族：琼恩·雪诺的真实身份·史塔克家族与龙的关系，取前 2 条）
/// 3. 自由民（无家族）兜底
/// 4. 既有注入（家族名/族语/规模/影响力/对外关系）不回归
///
/// Batch 10-68 覆盖：
/// 1. 关系 NPC 注入秘密（艾德·史塔克：琼恩·雪诺的真实身份）
/// 2. 无秘密 NPC 不输出秘密字段
/// 3. 既有注入（关系 NPC 名字/身份/家族/所在地/好感度）不回归
library;
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/models/event.dart';
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

Future<String> _promptFor(
  Player player, {
  String season = 'winter',
}) async {
  final (dio, captured) = _captureDio();
  final service = AiService(
    apiKey: 'test_key',
    dio: dio,
    baseUrl: 'https://mock.example.com/v1',
  );
  await service.generateNarrative(
    player: player,
    context: '测试',
    availableEvents: const <GameEvent>[],
    season: season,
    maxRetries: 0,
  );
  expect(captured[0], isNotNull);
  return captured[0]!;
}

/// 提取「家族」行内容（「- 家族：」行）。
String _familyLine(String body) {
  final start = body.indexOf('- 家族：');
  expect(start, greaterThanOrEqualTo(0));
  final end = body.indexOf('\n', start);
  expect(end, greaterThan(start));
  return body.substring(start, end);
}

/// 提取「关系」行内容（「- 关系：」行）。
String _relationLine(String body) {
  final start = body.indexOf('- 关系：');
  expect(start, greaterThanOrEqualTo(0));
  final end = body.indexOf('\n', start);
  expect(end, greaterThan(start));
  return body.substring(start, end);
}

void main() {
  group('Batch 10-67：家族特质与秘密注入', () {
    test('史塔克家族注入特质与秘密', () async {
      final player = Player.defaultPlayer();
      final body = await _promptFor(player);
      final line = _familyLine(body);
      expect(line, contains('特质：坚韧、忠诚、荣誉、战斗'));
      expect(line, contains('秘密：琼恩·雪诺的真实身份、史塔克家族与龙的关系'));
    });

    test('自由民（无家族）兜底不注入', () async {
      final player = Player.defaultPlayer().copyWith(familyId: '');
      final body = await _promptFor(player);
      final line = _familyLine(body);
      expect(line, contains('自由民，无家族'));
      expect(line, isNot(contains('特质：')));
      expect(line, isNot(contains('秘密：')));
    });

    test('既有注入（家族名/族语/规模/影响力/对外关系）不回归', () async {
      final player = Player.defaultPlayer();
      final body = await _promptFor(player);
      final line = _familyLine(body);
      expect(line, contains('史塔克家族'));
      expect(line, contains('凛冬将至'));
      expect(line, contains('大家族'));
      expect(line, contains('影响力 70'));
      expect(line, contains('兰尼斯特（敌对 -50）'));
      expect(line, contains('波顿（敌对 -80）'));
      expect(line, contains('徒利（友善 60）'));
    });
  });

  group('Batch 10-68：关系 NPC 秘密注入', () {
    test('关系 NPC 注入秘密（艾德·史塔克：琼恩·雪诺的真实身份）', () async {
      final player = Player.defaultPlayer().copyWith(
        relations: const <String, int>{'npc_nev': 85},
      );
      final body = await _promptFor(player);
      final line = _relationLine(body);
      expect(line, contains('艾德·史塔克'));
      expect(line, contains('秘密：琼恩·雪诺的真实身份'));
    });

    test('无秘密 NPC 不输出秘密字段', () async {
      // 构造一个关系指向无秘密 NPC 的玩家（凯特琳·史塔克 npc_catelyn secrets 为空）。
      final player = Player.defaultPlayer().copyWith(
        relations: const <String, int>{'npc_catelyn': 70},
      );
      final body = await _promptFor(player);
      final line = _relationLine(body);
      expect(line, contains('凯特琳·史塔克'));
      expect(line, isNot(contains('秘密：')));
      expect(line, contains('70'));
    });

    test('既有注入（关系 NPC 名字/身份/家族/所在地/好感度）不回归', () async {
      final player = Player.defaultPlayer().copyWith(
        relations: const <String, int>{'npc_nev': 85},
      );
      final body = await _promptFor(player);
      final line = _relationLine(body);
      expect(line, contains('艾德·史塔克'));
      expect(line, contains('贵族'));
      expect(line, contains('史塔克家族'));
      expect(line, contains('临冬城'));
    });
  });
}
