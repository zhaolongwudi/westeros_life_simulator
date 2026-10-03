/// Batch 10-72 测试：NPC 立场随玩家关系动态化。
///
/// 覆盖：
/// 1. 与 NPC 关系 ≥20 好感 → 立场追加「因与你交好…倾向考虑你的立场」
/// 2. 与 NPC 关系 ≤-20 恶感 → 立场追加「因与你结怨…可能与你对立」
/// 3. 关系平平（|关系| < 20）→ 不追加动态修饰，保留原立场
/// 4. 无事件 → 兜底「各势力按兵不动」不回归
/// 5. 既有注入（10-70 立场段落 + 10-71 家族成员）不回归
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
    season: 'winter',
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

/// 构造一个涉及兰尼斯特家族的局势事件（用于测试立场推导）。
const GameEvent _lannisterCrisis = GameEvent(
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
  group('Batch 10-72 NPC 立场随玩家关系动态化', () {
    test('好感 NPC（关系 80）→ 立场追加「因与你交好…倾向考虑你的立场」', () async {
      final body = await _promptFor(
        Player.defaultPlayer().copyWith(
          relations: const {'npc_nev': 80},
        ),
        availableEvents: const [_lannisterCrisis],
      );
      final section = _stanceSection(body);
      expect(section, contains('艾德·史塔克'));
      expect(section, contains('敌对'));
      expect(section, contains('因与你交好（艾德·史塔克，关系 80），倾向考虑你的立场'));
    });

    test('恶感 NPC（关系 -40）→ 立场追加「因与你结怨…可能与你对立」', () async {
      final body = await _promptFor(
        Player.defaultPlayer().copyWith(
          relations: const {'npc_cersei': -40},
        ),
        availableEvents: const [_lannisterCrisis],
      );
      final section = _stanceSection(body);
      expect(section, contains('因与你结怨（关系 -40），可能与你对立'));
    });

    test('关系平平（关系 10）→ 不追加动态修饰', () async {
      final body = await _promptFor(
        Player.defaultPlayer().copyWith(
          relations: const {'npc_nev': 10},
        ),
        availableEvents: const [_lannisterCrisis],
      );
      final section = _stanceSection(body);
      expect(section, contains('与兰尼斯特家族敌对'));
      expect(section, isNot(contains('因与你交好')));
      expect(section, isNot(contains('因与你结怨')));
    });

    test('无事件 → 兜底「各势力按兵不动」不回归', () async {
      final body = await _promptFor(Player.defaultPlayer());
      final section = _stanceSection(body);
      expect(section, contains('本月暂无重大传闻，各势力按兵不动'));
    });

    test('既有注入（10-70 立场段落 + 10-71 家族成员）不回归', () async {
      final body = await _promptFor(
        Player.defaultPlayer().copyWith(
          relations: const {'npc_nev': 80},
        ),
        availableEvents: const [_lannisterCrisis],
      );
      expect(body, contains('本月世界局势：'));
      expect(body, contains('局势关联 NPC 立场：'));
      expect(body, contains('季节世界动向：'));
      expect(body, contains('- 家族成员：'));
      expect(body, contains('所在地轶事·历史典故：'));
      expect(body, contains('叙事引导（区域）：'));
    });
  });
}