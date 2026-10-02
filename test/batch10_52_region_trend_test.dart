/// Batch 10-52 测试：AI prompt 注入地区风土人情。
///
/// 覆盖：
/// 1. 各区域注入对应地区风土人情段落（北境/西境/王领/多恩等抽查）
/// 2. 未知区域兜底文案
/// 3. 既有注入（本月世界局势 / 季节世界动向 / 区域叙事引导）不回归
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

Future<String> _promptForLocation(String locationId) async {
  final (dio, captured) = _captureDio();
  final service = AiService(
    apiKey: 'test_key',
    dio: dio,
    baseUrl: 'https://mock.example.com/v1',
  );
  await service.generateNarrative(
    player: Player.defaultPlayer().copyWith(locationId: locationId),
    context: '测试',
    availableEvents: const <GameEvent>[],
    season: 'winter',
    maxRetries: 0,
  );
  expect(captured[0], isNotNull);
  return captured[0]!;
}

/// 提取「地区风土人情」段落内容。
String _regionTrendSection(String body) {
  final trendStart = body.indexOf('地区风土人情：');
  expect(trendStart, greaterThanOrEqualTo(0));
  final eventsStart = body.indexOf('可用事件：');
  expect(eventsStart, greaterThan(trendStart));
  return body.substring(trendStart, eventsStart);
}

void main() {
  group('Batch 10-52 地区风土人情注入', () {
    test('默认玩家（北境临冬城）注入北境风土人情', () async {
      final body = await _promptForLocation('location_winterfell');
      expect(body, contains('地区风土人情：'));
      final section = _regionTrendSection(body);
      expect(section, contains('北境辽阔苦寒'));
      expect(section, contains('凛冬将至'));
    });

    test('西境凯岩城注入西境风土人情', () async {
      final body = await _promptForLocation('location_casterly_rock');
      final section = _regionTrendSection(body);
      expect(section, contains('西境群山藏金'));
      expect(section, contains('凯岩城的金矿'));
    });

    test('王领君临注入王领风土人情', () async {
      final body = await _promptForLocation('location_kings_landing');
      final section = _regionTrendSection(body);
      expect(section, contains('王领是七国的中枢'));
      expect(section, contains('铁王座的光芒'));
    });

    test('多恩阳戟城注入多恩风土人情', () async {
      final body = await _promptForLocation('location_sunspear');
      final section = _regionTrendSection(body);
      expect(section, contains('多恩酷热干旱'));
      expect(section, contains('不屈不挠'));
    });

    test('河湾地高庭注入河湾地风土人情', () async {
      final body = await _promptForLocation('location_highgarden');
      final section = _regionTrendSection(body);
      expect(section, contains('河湾地是七国最丰饶的粮仓'));
      expect(section, contains('提利尔家族'));
    });

    test('未知区域兜底文案', () async {
      final body = await _promptForLocation('location_unknown_nowhere');
      expect(body, contains('地区风土人情：'));
      final section = _regionTrendSection(body);
      expect(section, contains('这片土地有自己的脾气'));
    });

    test('既有注入（世界局势/季节动向/区域引导）不回归', () async {
      final body = await _promptForLocation('location_winterfell');
      expect(body, contains('本月世界局势：'));
      expect(body, contains('（本月暂无重大传闻）'));
      expect(body, contains('季节世界动向：'));
      expect(body, contains('叙事引导（区域）：'));
    });
  });
}
