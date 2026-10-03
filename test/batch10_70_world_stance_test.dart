/// Batch 10-70 测试：AI 注入当前局势关联 NPC 立场。
///
/// 覆盖：
/// 1. 有世界事件 + 有关系 NPC → 注入 NPC 立场描述（按家族对外关系网络推导）
/// 2. 有事件但无关系 NPC → 兜底「无深交」
/// 3. 无事件 → 兜底「各势力按兵不动」
/// 4. 既有注入（世界局势/季节动向/地区/农事/集市/轶事）不回归
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
  List<GameEvent> availableEvents = const <GameEvent>[],
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
    availableEvents: availableEvents,
    season: season,
    maxRetries: 0,
  );
  expect(captured[0], isNotNull);
  return captured[0]!;
}

/// 提取「局势关联 NPC 立场」段落内容（段落标题之后、季节世界动向之前）。
String _stanceSection(String body) {
  final start = body.indexOf('局势关联 NPC 立场：');
  expect(start, greaterThanOrEqualTo(0));
  final end = body.indexOf('季节世界动向：', start);
  expect(end, greaterThan(start));
  return body.substring(start, end);
}

/// 构造一个涉及兰尼斯特家族的局势事件（用于测试史塔克 NPC 的立场推导）。
final GameEvent _lannisterCrisis = GameEvent(
  id: 'event_test_lannister_crisis',
  name: '兰尼斯特继承危机',
  type: EventType.political,
  description: '凯岩城的兰尼斯特家族陷入继承纷争，七国贵族被迫选边站。',
  triggerConditions: const <String, String>{},
  choices: const <EventChoice>[],
  narrative: '',
  tags: const <String>['political'],
  isOneTime: false,
);

void main() {
  group('Batch 10-70 局势关联 NPC 立场注入', () {
    test('有关系 NPC + 涉及兰尼斯特事件 → 史塔克 NPC 立场敌对', () async {
      final body = await _promptFor(
        Player.defaultPlayer().copyWith(
          relations: const {'npc_nev': 80},
        ),
        availableEvents: const [_lannisterCrisis],
      );
      final section = _stanceSection(body);
      expect(section, contains('局势关联 NPC 立场：'));
      expect(section, contains('兰尼斯特继承危机'));
      expect(section, contains('艾德·史塔克'));
      expect(section, contains('史塔克家族'));
      expect(section, contains('与你关系 80'));
      expect(section, contains('敌对'));
    });

    test('有事件但无关系 NPC → 兜底「无深交」', () async {
      final body = await _promptFor(
        Player.defaultPlayer(),
        availableEvents: const [_lannisterCrisis],
      );
      final section = _stanceSection(body);
      expect(section, contains('你与任何势力都无深交'));
    });

    test('无事件 → 兜底「各势力按兵不动」', () async {
      final body = await _promptFor(Player.defaultPlayer());
      final section = _stanceSection(body);
      expect(section, contains('本月暂无重大传闻，各势力按兵不动'));
    });

    test('未知 NPC ID → 立场不明兜底', () async {
      final body = await _promptFor(
        Player.defaultPlayer().copyWith(
          relations: const {'npc_ghost': 30},
        ),
        availableEvents: const [_lannisterCrisis],
      );
      final section = _stanceSection(body);
      expect(section, contains('npc_ghost'));
      expect(section, contains('立场不明'));
    });

    test('既有注入（世界局势/季节/地区/农事/集市/轶事）不回归', () async {
      final body = await _promptFor(
        Player.defaultPlayer().copyWith(
          relations: const {'npc_nev': 80},
        ),
        availableEvents: const [_lannisterCrisis],
      );
      expect(body, contains('本月世界局势：'));
      expect(body, contains('局势关联 NPC 立场：'));
      expect(body, contains('季节世界动向：'));
      expect(body, contains('地区风土人情：'));
      expect(body, contains('时节农事：'));
      expect(body, contains('本地集市行情：'));
      expect(body, contains('所在地轶事·历史典故：'));
      expect(body, contains('叙事引导（区域）：'));
    });
  });
}