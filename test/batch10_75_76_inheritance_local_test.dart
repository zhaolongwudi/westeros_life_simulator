/// Batch 10-75 / 10-76 测试：AI 注入玩家继承顺位 + 玩家势力与当地势力关系。
///
/// 覆盖：
/// 10-75 继承顺位（- 家族继承顺位：行）
///  1. 有子女 → 注入顺位（长子/长女优先 + 继承人姓名 + 年龄）
///  2. 子女培养档案命中 → 附加培养方向
///  3. 无子女 → 兜底「尚无子嗣，继承悬而未决」
///  4. 自由民 → 兜底「无家族，无继承顺位」
/// 10-76 当地势力（- 当地势力与你的立场：行）
///  5. 有治主 NPC → 注入治主名 + 治主家族 + 与玩家家族敌友 + 与玩家关系
///  6. 治主家族 == 玩家家族 → 「自家领地」
///  7. 无治主 → 兜底「无治主，名义上直属领地」类文案
///  8. 自由民 → 兜底
///  9. 既有注入不回归（家族在权力网络中的位置 / 当前地点 / NPC 间关系网络）
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/models/family.dart';
import 'package:westeros_life_simulator/models/marital.dart';
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

/// 提取以 [anchor] 开头的那一行内容。
String _line(String body, String anchor) {
  final start = body.indexOf(anchor);
  expect(start, greaterThanOrEqualTo(0), reason: '缺少注入段落：$anchor');
  final end = body.indexOf('\n', start);
  expect(end, greaterThan(start));
  return body.substring(start, end);
}

void main() {
  group('Batch 10-75 玩家在家族继承顺位中的位置', () {
    test('有子女 → 注入顺位（继承人姓名 + 年龄）', () async {
      final body = await _promptFor(
        Player.defaultPlayer().copyWith(
          children: const <String>['瑞德·史塔克'],
        ),
      );
      final line = _line(body, '- 家族继承顺位：');
      expect(line, contains('家族继承顺位：'));
      expect(line, contains('瑞德·史塔克'));
      expect(line, contains('第一顺位'));
    });

    test('子女培养档案命中 → 附加培养方向', () async {
      final body = await _promptFor(
        Player.defaultPlayer().copyWith(
          children: const <String>['瑞德·史塔克'],
          childRearing: const <ChildRearing>[
            ChildRearing(
              name: '瑞德·史塔克',
              focus: '剑术',
              sentToSchool: true,
            ),
          ],
        ),
      );
      final line = _line(body, '- 家族继承顺位：');
      expect(line, contains('剑术'));
    });

    test('多名子女 → 标注第一顺位与次顺位', () async {
      final body = await _promptFor(
        Player.defaultPlayer().copyWith(
          children: const <String>['瑞德·史塔克', '珊莎·史塔克'],
        ),
      );
      final line = _line(body, '- 家族继承顺位：');
      expect(line, contains('第一顺位'));
      expect(line, contains('珊莎·史塔克'));
    });

    test('无子女 → 兜底「尚无子嗣」', () async {
      final body = await _promptFor(Player.defaultPlayer());
      final line = _line(body, '- 家族继承顺位：');
      expect(line, contains('尚无子嗣'));
    });

    test('自由民 → 兜底「无家族，无继承顺位」', () async {
      final body = await _promptFor(
        Player.defaultPlayer().copyWith(
          familyId: 'family_none',
          children: const <String>['某私生子'],
        ),
      );
      final line = _line(body, '- 家族继承顺位：');
      expect(line, contains('无继承顺位'));
    });
  });

  group('Batch 10-76 当地势力与你的立场', () {
    test('有治主 NPC → 注入治主 + 其家族 + 与玩家关系', () async {
      // 默认玩家在临冬城，治主是艾德·史塔克（family_stark）。
      final body = await _promptFor(Player.defaultPlayer());
      final line = _line(body, '- 当地势力与你的立场：');
      expect(line, contains('当地势力与你的立场：'));
      expect(line, contains('艾德·史塔克'));
      expect(line, contains('史塔克'));
      expect(line, contains('自家领地'));
    });

    test('在敌对势力治下 → 注入敌对判定', () async {
      // 恐怖堡治主是卢斯·波顿（family_bolton），史塔克家族与其关系 -80。
      final body = await _promptFor(
        Player.defaultPlayer().copyWith(locationId: 'location_castle_black'),
      );
      final line = _line(body, '- 当地势力与你的立场：');
      expect(line, contains('当地势力与你的立场：'));
      expect(line, contains('卢斯·波顿'));
      expect(line, contains('敌对'));
      expect(line, contains('你在敌对势力治下'));
    });

    test('无治主地点 → 兜底「无明确治主」', () async {
      // 最后壁炉城 governorId=null。
      final body = await _promptFor(
        Player.defaultPlayer().copyWith(locationId: 'location_last_hearth'),
      );
      final line = _line(body, '- 当地势力与你的立场：');
      expect(line, contains('无明确治主'));
    });

    test('自由民 → 兜底不涉家族对立', () async {
      final body = await _promptFor(
        Player.defaultPlayer().copyWith(familyId: 'family_none'),
      );
      final line = _line(body, '- 当地势力与你的立场：');
      expect(line, contains('当地势力与你的立场：'));
      expect(line.contains('自家领地'), isFalse);
    });

    test('既有注入不回归', () async {
      final body = await _promptFor(Player.defaultPlayer());
      expect(body, contains('家族在权力网络中的位置：'));
      expect(body, contains('NPC 间关系网络：'));
      expect(body, contains('当前地点：'));
    });
  });

  group('10-75/76 纯函数契约', () {
    test('Family 默认实例可读 relations（兜底不抛）', () {
      final f = Family.defaultFamily();
      expect(f.relations, isNotEmpty);
    });
  });
}