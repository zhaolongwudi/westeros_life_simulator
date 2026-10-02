/// Batch 10-58 测试：AI prompt 注入本地集市行情。
///
/// 覆盖：
/// 1. 各季节 × 区域注入对应集市行情段落（北境冬/西境夏/王领秋/河湾地春/多恩永冬抽查）
/// 2. 未知区域 + 未知季节兜底文案
/// 3. 既有注入（世界局势 / 季节动向 / 地区风土人情 / 时节农事 / 区域引导）不回归
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

Future<String> _promptFor(String locationId, String season) async {
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
    season: season,
    maxRetries: 0,
  );
  expect(captured[0], isNotNull);
  return captured[0]!;
}

/// 提取「本地集市行情」段落内容（时节农事之后、可用事件之前）。
String _marketTrendSection(String body) {
  final trendStart = body.indexOf('本地集市行情：');
  expect(trendStart, greaterThanOrEqualTo(0));
  final eventsStart = body.indexOf('可用事件：');
  expect(eventsStart, greaterThan(trendStart));
  return body.substring(trendStart, eventsStart);
}

void main() {
  group('Batch 10-58 本地集市行情注入', () {
    test('北境·严冬注入北境冬季集市行情', () async {
      final body = await _promptFor('location_winterfell', 'winter');
      expect(body, contains('本地集市行情：'));
      final section = _marketTrendSection(body);
      expect(section, contains('北境冬市冷清'));
      expect(section, contains('盐价贵得离谱'));
    });

    test('西境·盛夏注入西境夏季集市行情', () async {
      final body = await _promptFor('location_casterly_rock', 'summer');
      final section = _marketTrendSection(body);
      expect(section, contains('西境夏市钱多'));
      expect(section, contains('凯岩城的税吏与金匠比谁都忙'));
    });

    test('王领·秋日注入王领秋季集市行情', () async {
      final body = await _promptFor('location_kings_landing', 'autumn');
      final section = _marketTrendSection(body);
      expect(section, contains('王领秋市囤权'));
      expect(section, contains('粮价与谣言一起上涨'));
    });

    test('河湾地·春日注入河湾地春季集市行情', () async {
      final body = await _promptFor('location_highgarden', 'spring');
      final section = _marketTrendSection(body);
      expect(section, contains('河湾地春市花多'));
      expect(section, contains('种子、农具与婚约是开市谈资'));
    });

    test('多恩·永冬注入多恩永冬集市行情', () async {
      final body = await _promptFor('location_sunspear', 'longwinter');
      final section = _marketTrendSection(body);
      expect(section, contains('多恩永冬反常'));
      expect(section, contains('集市里水比酒贵'));
    });

    test('未知区域兜底文案', () async {
      final body = await _promptFor('location_unknown_nowhere', 'summer');
      expect(body, contains('本地集市行情：'));
      final section = _marketTrendSection(body);
      expect(section, contains('盛夏市喧'));
    });

    test('已知区域未知季节兜底文案', () async {
      final body = await _promptFor('location_winterfell', 'midsummer');
      final section = _marketTrendSection(body);
      expect(section, contains('北境集市随季而变'));
    });

    test('既有注入（世界局势/季节动向/地区风土人情/时节农事/区域引导）不回归', () async {
      final body = await _promptFor('location_winterfell', 'winter');
      expect(body, contains('本月世界局势：'));
      expect(body, contains('（本月暂无重大传闻）'));
      expect(body, contains('季节世界动向：'));
      expect(body, contains('地区风土人情：'));
      expect(body, contains('时节农事：'));
      expect(body, contains('叙事引导（区域）：'));
    });
  });
}
