/// Batch 10-74 测试：AI 注入家族在权力网络中的位置。
///
/// 覆盖：
/// 1. 有家族玩家 → 注入「家族在权力网络中的位置」段落（家族名 + 玩家角色 + 对外格局）
/// 2. 家族对外关系 → 盟友/宿敌/中立按阈值 ±20 分类（史塔克：兰尼斯特宿敌、徒利盟友）
/// 3. 玩家姓氏与家族同名 → 角色「家主」
/// 4. 自由民玩家 → 兜底「自由民，无家族，不受任何家族约束」
/// 5. 既有注入（家族/家族成员/NPC 间关系网络/世界局势）不回归
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

/// 提取「家族在权力网络中的位置」行内容。
String _familyPowerLine(String body) {
  final start = body.indexOf('- 家族在权力网络中的位置：');
  expect(start, greaterThanOrEqualTo(0));
  final end = body.indexOf('\n', start);
  expect(end, greaterThan(start));
  return body.substring(start, end);
}

void main() {
  group('Batch 10-74 家族在权力网络中的位置注入', () {
    test('有家族玩家 → 注入家族名 + 玩家角色 + 对外格局', () async {
      final body = await _promptFor(Player.defaultPlayer());
      final line = _familyPowerLine(body);
      expect(line, contains('家族在权力网络中的位置：'));
      // 默认玩家 familyId=family_stark，house='' → 角色「成员」
      expect(line, contains('史塔克家族'));
      expect(line, contains('玩家为成员'));
      // 对外格局：兰尼斯特 -50 宿敌、徒利 60 盟友
      expect(line, contains('对外格局：'));
      expect(line, contains('兰尼斯特（宿敌，关系 -50）'));
      expect(line, contains('徒利（盟友，关系 60）'));
    });

    test('玩家姓氏与家族同名 → 角色「家主」', () async {
      final body = await _promptFor(
        Player.defaultPlayer().copyWith(
          house: '史塔克',
        ),
      );
      final line = _familyPowerLine(body);
      expect(line, contains('玩家为家主'));
    });

    test('自由民玩家 → 兜底「自由民，无家族，不受任何家族约束」', () async {
      final body = await _promptFor(
        Player.defaultPlayer().copyWith(
          familyId: '',
        ),
      );
      final line = _familyPowerLine(body);
      expect(line, contains('自由民，无家族，不受任何家族约束'));
    });

    test('既有注入（家族/家族成员/NPC 间关系网络/世界局势）不回归', () async {
      final body = await _promptFor(
        Player.defaultPlayer().copyWith(
          relations: const {'npc_nev': 80, 'npc_catelyn': 60},
        ),
      );
      expect(body, contains('- 家族：'));
      expect(body, contains('- 家族成员：'));
      expect(body, contains('- 家族在权力网络中的位置：'));
      expect(body, contains('- NPC 间关系网络：'));
      expect(body, contains('本月世界局势：'));
      expect(body, contains('- 关系（NPC: 好感度）：'));
    });
  });
}