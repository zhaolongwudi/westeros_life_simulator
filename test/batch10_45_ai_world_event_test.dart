/// Batch 10-45 测试：AI prompt 注入本月世界局势（月度世界事件 AI 化）。
///
/// 覆盖：
/// 1. 有可用事件时注入前 2 条世界局势（名称 + 描述）
/// 2. 无可用事件时兜底「（本月暂无重大传闻）」
/// 3. 与事件预算筛选联动：相关度最高的事件排第一（世界局势取 top2）
/// 4. 既有注入（可用事件/装备战力）不回归
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/event_data.dart';
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

/// 构造一个简单的测试事件。
GameEvent _event(String id, String name, String desc) {
  return GameEvent(
    id: id,
    name: name,
    type: EventType.political,
    description: desc,
    triggerConditions: const <String, String>{},
    choices: const <EventChoice>[],
    narrative: '',
    tags: const <String>[],
    isOneTime: false,
  );
}

void main() {
  group('Batch 10-45 世界局势注入', () {
    test('有可用事件时注入前 2 条（名称+描述）', () async {
      final (dio, captured) = _captureDio();
      final service = AiService(
        apiKey: 'test_key',
        dio: dio,
        baseUrl: 'https://mock.example.com/v1',
      );
      final events = <GameEvent>[
        _event('ev_war', '北境烽烟', '北境边境战事再起，各方领主秣马厉兵。'),
        _event('ev_famine', '饥荒蔓延', '河湾地歉收，粮价飞涨。'),
        _event('ev_dragon', '龙影重现', '东方天际出现龙的影子，人心浮动。'),
      ];
      await service.generateNarrative(
        player: Player.defaultPlayer(),
        context: '你在临冬城。',
        availableEvents: events,
        season: 'winter',
        currentYear: 283,
        maxRetries: 0,
      );

      expect(captured[0], isNotNull);
      final body = captured[0]!;
      // 世界局势段落注入前 2 条
      expect(body, contains('本月世界局势：'));
      expect(body, contains('· 北境烽烟——北境边境战事再起，各方领主秣马厉兵。'));
      expect(body, contains('· 饥荒蔓延——河湾地歉收，粮价飞涨。'));
      // 第 3 条只出现在「可用事件」（全量注入），不在「世界局势」（取前 2）
      final newsStart = body.indexOf('本月世界局势：');
      final eventsStart = body.indexOf('可用事件：');
      final newsSection = body.substring(newsStart, eventsStart);
      expect(newsSection, isNot(contains('龙影重现')));
      // 可用事件仍全量注入
      expect(body, contains('- 北境烽烟: 北境边境战事再起，各方领主秣马厉兵。'));
      expect(body, contains('- 龙影重现: 东方天际出现龙的影子，人心浮动。'));
    });

    test('无可用事件时兜底（本月暂无重大传闻）', () async {
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
      expect(captured[0], contains('本月世界局势：'));
      expect(captured[0], contains('（本月暂无重大传闻）'));
    });

    test('世界局势取相关度最高的前 2 条（复用预算筛选排序）', () async {
      final (dio, captured) = _captureDio();
      final service = AiService(
        apiKey: 'test_key',
        dio: dio,
        baseUrl: 'https://mock.example.com/v1',
      );
      // 传真实事件库 + 默认玩家（临冬城·冬）：event_frozen_lake 双命中排第一
      await service.generateNarrative(
        player: Player.defaultPlayer(),
        context: '你在临冬城。',
        availableEvents: allEvents,
        season: 'winter',
        currentYear: 283,
        maxRetries: 0,
      );

      expect(captured[0], isNotNull);
      final body = captured[0]!;
      final newsStart = body.indexOf('本月世界局势：');
      final eventsStart = body.indexOf('可用事件：');
      expect(newsStart, greaterThanOrEqualTo(0));
      expect(eventsStart, greaterThan(newsStart));
      final newsSection = body.substring(newsStart, eventsStart);
      // 相关度最高的冰封湖面（地点+季节双命中）应排在第一位
      expect(newsSection, contains('冰封湖面'));
      final firstNewsLine = newsSection.split('\n').firstWhere(
            (line) => line.startsWith('· '),
            orElse: () => '',
          );
      expect(firstNewsLine, contains('冰封湖面'));
    });

    test('既有注入（可用事件/战斗值）不回归', () async {
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
      expect(captured[0], contains('战斗值：10'));
      expect(captured[0], contains('可用事件：'));
    });
  });
}