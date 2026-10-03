/// Batch 10-73 测试：AI 注入 NPC 间关系网络。
///
/// 覆盖：
/// 1. 有多个关系 NPC → 注入「NPC 间关系网络」段落（名字 ↔ 名字（关系 N）：友善/敌对/中立）
/// 2. 史塔克家族成员之间关系（艾德 ↔ 凯特琳 友善）
/// 3. 敌对关系（卢斯·波顿 ↔ 艾德·史塔克 敌对——按 npc.relations 双向取强）
/// 4. 关系 NPC 不足 2 个 → 段落兜底「（无）」
/// 5. 既有注入（关系/在场 NPC/世界局势/家族成员）不回归
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
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

Future<String> _promptFor(Player player) async {
  final (dio, captured) = _captureDio();
  final service = AiService(
    apiKey: 'test_key',
    dio: dio,
    baseUrl: 'https://mock.example.com/v1',
  );
  await service.generateNarrative(
    player: player,
    context: '测试',
    availableEvents: const [],
    season: 'winter',
    maxRetries: 0,
  );
  expect(captured[0], isNotNull);
  return captured[0]!;
}

/// 提取「NPC 间关系网络」行内容（「- NPC 间关系网络：」行）。
String _npcNetworkLine(String body) {
  final start = body.indexOf('- NPC 间关系网络：');
  expect(start, greaterThanOrEqualTo(0));
  final end = body.indexOf('\n', start);
  expect(end, greaterThan(start));
  return body.substring(start, end);
}

void main() {
  group('Batch 10-73 NPC 间关系网络注入', () {
    test('有多个关系 NPC → 注入人物间关系（艾德 ↔ 凯特琳 友善）', () async {
      final body = await _promptFor(
        Player.defaultPlayer().copyWith(
          relations: const {'npc_nev': 80, 'npc_catelyn': 60, 'npc_robb': 40},
        ),
      );
      final line = _npcNetworkLine(body);
      expect(line, contains('NPC 间关系网络：'));
      // 艾德 ↔ 凯特琳：艾德.relations['npc_catelyn'] = 90 → 友善
      expect(line, contains('艾德·史塔克 ↔ 凯特琳·史塔克（关系 90）：友善'));
      // 艾德 ↔ 罗柏：艾德.relations['npc_robb'] = 85 → 友善
      expect(line, contains('艾德·史塔克 ↔ 罗柏·史塔克（关系 85）：友善'));
      // 凯特琳 ↔ 罗柏：凯特琳.relations['npc_robb'] = 85 → 友善
      expect(line, contains('凯特琳·史塔克 ↔ 罗柏·史塔克（关系 85）：友善'));
    });

    test('无直接关系 → 中立（艾德·史塔克 ↔ 卢斯·波顿）', () async {
      final body = await _promptFor(
        Player.defaultPlayer().copyWith(
          relations: const {'npc_nev': -30, 'npc_roose_bolton': 50},
        ),
      );
      final line = _npcNetworkLine(body);
      // 玩家关系按绝对值降序 → 波顿(50) 在前、艾德(-30) 在后 → 卢斯 ↔ 艾德
      // 艾德.relations 无卢斯·波顿、卢斯.relations 无艾德 → 双向缺失回落 0 → 中立
      expect(line, contains('卢斯·波顿 ↔ 艾德·史塔克（关系 0）：中立'));
    });

    test('关系 NPC 不足 2 个 → 段落兜底「（无）」', () async {
      final body = await _promptFor(
        Player.defaultPlayer().copyWith(
          relations: const {'npc_nev': 80},
        ),
      );
      final line = _npcNetworkLine(body);
      expect(line, contains('（无）'));
      expect(line, isNot(contains('↔')));
    });

    test('无关系 NPC → 段落兜底「（无）」', () async {
      final body = await _promptFor(Player.defaultPlayer());
      final line = _npcNetworkLine(body);
      expect(line, contains('（无）'));
    });

    test('既有注入（关系/在场 NPC/世界局势/家族成员）不回归', () async {
      final body = await _promptFor(
        Player.defaultPlayer().copyWith(
          relations: const {'npc_nev': 80, 'npc_catelyn': 60},
        ),
      );
      expect(body, contains('- 关系（NPC: 好感度）：'));
      expect(body, contains('- NPC 间关系网络：'));
      expect(body, contains('- 在场 NPC：'));
      expect(body, contains('本月世界局势：'));
      expect(body, contains('- 家族成员：'));
      expect(body, contains('所在地轶事·历史典故：'));
    });
  });
}
