/// Batch 10-50 测试：AI prompt 注入季节世界动向。
///
/// 覆盖：
/// 1. 五季（spring/summer/autumn/winter/longwinter）各注入对应季节世界动向段落
/// 2. 未知季节兜底文案
/// 3. 既有注入（本月世界局势 / 可用事件 / 季节叙事引导）不回归
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

Future<String> _promptForSeason(String season) async {
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
    season: season,
    maxRetries: 0,
  );
  expect(captured[0], isNotNull);
  return captured[0]!;
}

/// 提取「季节世界动向」段落内容。
String _seasonTrendSection(String body) {
  final trendStart = body.indexOf('季节世界动向：');
  expect(trendStart, greaterThanOrEqualTo(0));
  final eventsStart = body.indexOf('可用事件：');
  expect(eventsStart, greaterThan(trendStart));
  return body.substring(trendStart, eventsStart);
}

void main() {
  group('Batch 10-50 季节世界动向注入', () {
    test('spring 注入春潮涌动动向', () async {
      final body = await _promptForSeason('spring');
      expect(body, contains('季节世界动向：'));
      final section = _seasonTrendSection(body);
      expect(section, contains('春潮涌动'));
      expect(section, contains('积雪化尽，道路重新贯通'));
    });

    test('summer 注入盛夏正酣动向', () async {
      final body = await _promptForSeason('summer');
      expect(body, contains('季节世界动向：'));
      final section = _seasonTrendSection(body);
      expect(section, contains('盛夏正酣'));
      expect(section, contains('粮仓渐满'));
    });

    test('autumn 注入秋色渐浓动向', () async {
      final body = await _promptForSeason('autumn');
      expect(body, contains('季节世界动向：'));
      final section = _seasonTrendSection(body);
      expect(section, contains('秋色渐浓'));
      expect(section, contains('囤积过冬的物资'));
    });

    test('winter 注入严冬笼罩动向', () async {
      final body = await _promptForSeason('winter');
      expect(body, contains('季节世界动向：'));
      final section = _seasonTrendSection(body);
      expect(section, contains('严冬笼罩'));
      expect(section, contains('大雪封住隘口'));
    });

    test('longwinter 注入凛冬无期动向', () async {
      final body = await _promptForSeason('longwinter');
      expect(body, contains('季节世界动向：'));
      final section = _seasonTrendSection(body);
      expect(section, contains('凛冬无期'));
      expect(section, contains('异鬼传说'));
    });

    test('未知季节兜底文案', () async {
      final body = await _promptForSeason('typhoon');
      expect(body, contains('季节世界动向：'));
      final section = _seasonTrendSection(body);
      expect(section, contains('季节轮转如常'));
    });

    test('既有注入（世界局势/可用事件/季节引导）不回归', () async {
      final body = await _promptForSeason('winter');
      expect(body, contains('本月世界局势：'));
      expect(body, contains('（本月暂无重大传闻）'));
      expect(body, contains('可用事件：'));
      expect(body, contains('叙事引导（季节）：'));
    });
  });
}
