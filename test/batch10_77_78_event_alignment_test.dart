/// Batch 10-77 / 10-78 测试：AI 注入事件与玩家家族/身份联动 + 事件利害标注。
///
/// 覆盖：
/// 10-77 与你相关的可用事件（- 与你相关的可用事件：行）
///  1. 家族联姻类事件 → 命中玩家家族关键词 → 注入关联说明
///  2. 无关联事件 → 兜底「（本月无直接牵涉你家族/身份的大事）」
///  3. 自由民玩家 → 兜底且不虚构家族关联
///  4. 关联事件取前 3 条防 prompt 膨胀
/// 10-78 事件利害标注（可用事件每行尾部 - 对你而言：xxx）
///  5. 家族类事件 + 玩家为该家族家主 → 标注「家族兴衰系于你一身」
///  6. 战争类事件 + 玩家平民 → 标注偏向自身安危
///  7. 利害标注不回归（事件名/描述仍全量注入）
///  8. 既有注入不回归
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

Future<String> _promptFor(
  Player player, {
  List<GameEvent>? events,
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
    availableEvents: events ?? allEvents,
    season: season,
    currentYear: 283,
    maxRetries: 0,
  );
  expect(captured[0], isNotNull);
  return captured[0]!;
}

/// 提取「可用事件」段落内容（标题之后、叙事引导之前）。
String _eventsSection(String body) {
  final start = body.indexOf('可用事件：');
  expect(start, greaterThanOrEqualTo(0));
  final end = body.indexOf('叙事引导（身份）：', start);
  expect(end, greaterThan(start));
  return body.substring(start, end);
}

/// 提取「与你相关的可用事件」行内容。
String _relevantLine(String body) {
  final start = body.indexOf('- 与你相关的可用事件：');
  expect(start, greaterThanOrEqualTo(0), reason: '缺少 10-77 注入行');
  final end = body.indexOf('\n', start);
  expect(end, greaterThan(start));
  return body.substring(start, end);
}

/// 构造一个可控事件（类型 + 标签 + 描述）。
GameEvent _ev(
  String id,
  String name,
  EventType type,
  String desc, {
  List<String> tags = const <String>[],
}) {
  return GameEvent(
    id: id,
    name: name,
    type: type,
    description: desc,
    triggerConditions: const <String, String>{},
    choices: const <EventChoice>[],
    narrative: '',
    tags: tags,
    isOneTime: false,
  );
}

void main() {
  group('Batch 10-77 事件与玩家家族/身份联动', () {
    test('描述含玩家家族名 → 注入关联说明', () async {
      final body = await _promptFor(
        Player.defaultPlayer(),
        events: <GameEvent>[
          _ev('e1', '史塔克家的喜讯', EventType.family, '史塔克家族迎来新的继承人。'),
          _ev('e2', '北境寒潮', EventType.daily, '北境大雪封路。'),
        ],
      );
      final line = _relevantLine(body);
      expect(line, contains('与你相关的可用事件：'));
      expect(line, contains('史塔克家'));
      expect(line, contains('家族'));
    });

    test('描述含玩家身份关键词 → 注入关联说明', () async {
      final body = await _promptFor(
        Player.defaultPlayer().copyWith(identity: PlayerIdentity.soldier),
        events: <GameEvent>[
          _ev('e1', '边境征兵', EventType.war, '各地士兵被征召入伍。'),
          _ev('e2', '北境寒潮', EventType.daily, '北境大雪封路。'),
        ],
      );
      final line = _relevantLine(body);
      expect(line, isNot(contains('本月无直接牵涉你家族/身份的大事')));
      expect(line, contains('边境征兵'));
      expect(line, contains('身份·士兵'));
    });

    test('无关联事件 → 兜底', () async {
      final body = await _promptFor(
        Player.defaultPlayer(),
        events: <GameEvent>[
          _ev('e1', '远方的消息', EventType.daily, '铁屿的商船遇见了风暴。'),
        ],
      );
      final line = _relevantLine(body);
      expect(line, contains('本月无直接牵涉你家族/身份的大事'));
    });

    test('自由民 → 兜底且不虚构家族关联', () async {
      final body = await _promptFor(
        Player.defaultPlayer().copyWith(familyId: 'family_none'),
        events: <GameEvent>[
          _ev('e1', '史塔克家的纷争', EventType.family, '史塔克家族内部起了争执。'),
        ],
      );
      final line = _relevantLine(body);
      expect(line, contains('本月无直接牵涉你家族/身份的大事'));
    });

    test('关联事件最多取 3 条', () async {
      final body = await _promptFor(
        Player.defaultPlayer(),
        events: <GameEvent>[
          _ev('e1', '甲事', EventType.family, '史塔克家族甲事。'),
          _ev('e2', '乙事', EventType.family, '史塔克家族乙事。'),
          _ev('e3', '丙事', EventType.family, '史塔克家族丙事。'),
          _ev('e4', '丁事', EventType.family, '史塔克家族丁事。'),
          _ev('e5', '戊事', EventType.family, '史塔克家族戊事。'),
        ],
      );
      final line = _relevantLine(body);
      expect(line, contains('甲事'));
      expect(line.contains('丁事') || line.contains('戊事'), isFalse);
    });
  });

  group('Batch 10-78 事件利害标注', () {
    test('家族类事件 → 标注利害', () async {
      final body = await _promptFor(
        Player.defaultPlayer(),
        events: <GameEvent>[
          _ev('e1', '家族内斗', EventType.family, '家臣与亲族争权。'),
        ],
      );
      final section = _eventsSection(body);
      expect(section, contains('对你而言：'));
      expect(section, contains('家族内斗'));
    });

    test('战争类事件 → 标注非家族风险', () async {
      final body = await _promptFor(
        Player.defaultPlayer().copyWith(identity: PlayerIdentity.commoner),
        events: <GameEvent>[
          _ev('e1', '边境战事', EventType.war, '两国交战。'),
        ],
      );
      final section = _eventsSection(body);
      expect(section, contains('对你而言：'));
    });

    test('自由民 + 家族事件 → 仍注入但不称家族兴衰', () async {
      final body = await _promptFor(
        Player.defaultPlayer().copyWith(familyId: 'family_none'),
        events: <GameEvent>[
          _ev('e1', '家族灭亡', EventType.family, '某个家族绝了嗣。'),
        ],
      );
      final section = _eventsSection(body);
      expect(section, contains('对你而言：'));
      expect(section, isNot(contains('系于你一身')));
    });

    test('事件名与描述仍全量注入（不回归）', () async {
      final body = await _promptFor(
        Player.defaultPlayer(),
        events: <GameEvent>[
          _ev('e1', '边贸争端', EventType.economic, '两城商路被截。'),
        ],
      );
      expect(body, contains('- 边贸争端: 两城商路被截。'));
    });

    test('既有注入不回归', () async {
      final body = await _promptFor(Player.defaultPlayer());
      expect(body, contains('本月世界局势：'));
      expect(body, contains('家族继承顺位：'));
      expect(body, contains('当地势力与你的立场：'));
    });
  });
}