/// Batch 10-56 测试：AI prompt 注入时节农事。
///
/// 覆盖：
/// 1. 各季节 × 区域注入对应时节农事段落（北境冬/西境夏/王领秋/河湾地春/多恩冬抽查）
/// 2. 未知区域 + 未知季节兜底文案
/// 3. 既有注入（世界局势 / 季节动向 / 地区风土人情 / 区域引导）不回归
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

/// 提取「时节农事」段落内容（地区风土人情之后、可用事件之前）。
String _farmTrendSection(String body) {
  final trendStart = body.indexOf('时节农事：');
  expect(trendStart, greaterThanOrEqualTo(0));
  final eventsStart = body.indexOf('可用事件：');
  expect(eventsStart, greaterThan(trendStart));
  return body.substring(trendStart, eventsStart);
}

void main() {
  group('Batch 10-56 时节农事注入', () {
    test('北境·严冬注入北境冬季农事', () async {
      final body = await _promptFor('location_winterfell', 'winter');
      expect(body, contains('时节农事：'));
      final section = _farmTrendSection(body);
      expect(section, contains('北境严冬封门'));
      expect(section, contains('粮仓配额'));
    });

    test('西境·盛夏注入西境夏季农事', () async {
      final body = await _promptFor('location_casterly_rock', 'summer');
      final section = _farmTrendSection(body);
      expect(section, contains('西境盛夏淘金'));
      expect(section, contains('凯岩城忙着清点税赋'));
    });

    test('王领·秋日注入王领秋季农事', () async {
      final body = await _promptFor('location_kings_landing', 'autumn');
      final section = _farmTrendSection(body);
      expect(section, contains('王领秋市鼎盛'));
      expect(section, contains('跳蚤窝的物价随人流一起升温'));
    });

    test('河湾地·春日注入河湾地春季农事', () async {
      final body = await _promptFor('location_highgarden', 'spring');
      final section = _farmTrendSection(body);
      expect(section, contains('河湾地春耕盛大'));
      expect(section, contains('高庭的玫瑰园开成花海'));
    });

    test('S4-2：多恩·longwinter 已清除，走区域兜底文案', () async {
      final body = await _promptFor('location_sunspear', 'longwinter');
      final section = _farmTrendSection(body);
      // 凛冬专属农事段落已随S4-2 删除，应落到 `_ =>` 兜底。
      expect(section, isNot(contains('多恩永冬反常')));
      expect(section, contains('多恩靠太阳与绿洲为生'));
    });

    test('未知区域兜底文案', () async {
      final body = await _promptFor('location_unknown_nowhere', 'summer');
      expect(body, contains('时节农事：'));
      final section = _farmTrendSection(body);
      expect(section, contains('盛夏农忙'));
    });

    test('已知区域未知季节兜底文案', () async {
      final body = await _promptFor('location_winterfell', 'midsummer');
      final section = _farmTrendSection(body);
      expect(section, contains('北境农事随季而转'));
    });

    test('既有注入（世界局势/季节动向/地区风土人情/区域引导）不回归', () async {
      final body = await _promptFor('location_winterfell', 'winter');
      expect(body, contains('本月世界局势：'));
      expect(body, contains('（本月暂无重大传闻）'));
      expect(body, contains('季节世界动向：'));
      expect(body, contains('地区风土人情：'));
      expect(body, contains('叙事引导（区域）：'));
    });
  });
}
