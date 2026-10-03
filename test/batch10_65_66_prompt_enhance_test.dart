/// Batch 10-65/66 测试：AI prompt 注入增强。
///
/// Batch 10-65 覆盖：
/// 1. 在场 NPC 注入性格/目标（艾德·史塔克：正直·严肃 性格 / 维护荣誉·保护家族 目标）
/// 2. 性格/目标为空时不输出对应字段
/// 3. 既有注入（在场 NPC 关系/心情/可委托）不回归
///
/// Batch 10-66 覆盖：
/// 1. 家族对外关系注入（史塔克家族：兰尼斯特敌对 / 波顿敌对 / 徒利友善 / 莫尔蒙友善）
/// 2. 自由民（无家族）兜底
/// 3. 既有注入（家族名/族语/规模/影响力）不回归
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

/// 提取「在场 NPC」行内容。
String _onSiteLine(String body) {
  final start = body.indexOf('在场 NPC：');
  expect(start, greaterThanOrEqualTo(0));
  final end = body.indexOf('\n', start);
  expect(end, greaterThan(start));
  return body.substring(start, end);
}

/// 提取「家族」行内容（「- 家族：」行）。
String _familyLine(String body) {
  final start = body.indexOf('- 家族：');
  expect(start, greaterThanOrEqualTo(0));
  final end = body.indexOf('\n', start);
  expect(end, greaterThan(start));
  return body.substring(start, end);
}

void main() {
  group('Batch 10-65 在场 NPC 性格/目标注入', () {
    test('临冬城艾德·史塔克注入性格与目标', () async {
      final body = await _promptFor(Player.defaultPlayer());
      final line = _onSiteLine(body);
      expect(line, contains('艾德·史塔克'));
      expect(line, contains('性格：正直、严肃'));
      expect(line, contains('目标：维护荣誉、保护家族'));
      expect(line, contains('心情沉稳'));
    });

    test('性格/目标各取前 2 条防膨胀', () async {
      final body = await _promptFor(Player.defaultPlayer());
      final line = _onSiteLine(body);
      // 艾德 personality 有 3 条（正直/严肃/忠诚），只应注入前 2 条。
      expect(line, contains('性格：正直、严肃'));
      expect(line, isNot(contains('性格：正直、严肃、忠诚')));
    });

    test('既有注入（关系/心情/可委托）不回归', () async {
      final body = await _promptFor(Player.defaultPlayer());
      final line = _onSiteLine(body);
      expect(line, contains('关系 '));
      expect(line, contains('可委托：'));
    });
  });

  group('Batch 10-66 家族对外关系注入', () {
    test('史塔克家族注入对外关系（敌对/友善）', () async {
      final body = await _promptFor(Player.defaultPlayer());
      final line = _familyLine(body);
      expect(line, contains('史塔克家族'));
      expect(line, contains('族语「凛冬将至」'));
      expect(line, contains('大家族'));
      expect(line, contains('影响力 70'));
      expect(line, contains('对外关系：'));
      expect(line, contains('兰尼斯特（敌对 -50）'));
      expect(line, contains('波顿（敌对 -80）'));
      expect(line, contains('徒利（友善 60）'));
      expect(line, contains('莫尔蒙（友善 50）'));
    });

    test('自由民（无家族）兜底', () async {
      final body = await _promptFor(
        Player.defaultPlayer().copyWith(familyId: ''),
      );
      final line = _familyLine(body);
      expect(line, contains('（自由民，无家族）'));
      expect(line, isNot(contains('对外关系：')));
    });

    test('既有注入（家族名/族语/规模/影响力）不回归', () async {
      final body = await _promptFor(Player.defaultPlayer());
      final line = _familyLine(body);
      expect(line, contains('史塔克家族'));
      expect(line, contains('凛冬将至'));
      expect(line, contains('大家族'));
      expect(line, contains('70'));
    });
  });
}