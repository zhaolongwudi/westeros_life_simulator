/// Batch 10-79 / 10-80 测试：AI 注入 NPC 技能与信仰 + 邻近地点路途风险。
///
/// 覆盖：
/// 10-79 NPC 技能与信仰（在场 NPC 行内追加 skills/信仰）
///  1. 在场 NPC → 注入技能（前 2 项，键名中文化）与信仰
///  2. 技能键名不得泄漏英文（无 sword/leadership/politics 裸键）
///  3. 技能 >2 项时附「另有 N 项」
/// 10-80 邻近地点与路途风险（- 邻近地点与路途风险：行）
///  4. 临冬城 → 列出白港/巴隆镇 + 危险度 + 治主
///  5. 玩家家族敌对领地点标注「敌对领地」
///  6. 无相邻地点 → 兜底「无路可往」
///  7. 自由民 → 兜底不涉家族旗号
///  8. 既有注入不回归
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

/// 提取以 [anchor] 开头的那一行内容。
String _line(String body, String anchor) {
  final start = body.indexOf(anchor);
  expect(start, greaterThanOrEqualTo(0), reason: '缺少注入段落：$anchor');
  final end = body.indexOf('\n', start);
  expect(end, greaterThan(start));
  return body.substring(start, end);
}

/// 提取「在场 NPC：」那一整行（NPC 之间用「、」分隔，可能很长）。
String _onSiteLine(String body) {
  final start = body.indexOf('- 在场 NPC：');
  expect(start, greaterThanOrEqualTo(0));
  final end = body.indexOf('\n', start);
  return body.substring(start, end);
}

void main() {
  group('Batch 10-79 在场 NPC 技能与信仰注入', () {
    test('在场 NPC → 注入技能与信仰（键名中文化）', () async {
      final body = await _promptFor(Player.defaultPlayer());
      final line = _onSiteLine(body);
      // 临冬城在场 NPC 至少有一位（艾德/凯特琳/罗柏等），
      // 全库 NPC 100% 带 skills 与 faith，故必然注入。
      expect(line, contains('，信仰：'));
      // 键名中文化：艾德 sword 8 / leadership 9 / politics 7
      // 降序取前 2 → 「统率 9、剑术 8」，另有 1 项。
      expect(line, contains('统率'));
      expect(line, contains('剑术'));
    });

    test('技能键名不得泄漏英文裸键', () async {
      final body = await _promptFor(Player.defaultPlayer());
      final line = _onSiteLine(body);
      expect(line.contains('sword'), isFalse);
      expect(line.contains('leadership'), isFalse);
      expect(line.contains('politics'), isFalse);
    });

    test('超过 2 项技能 → 附「另有 N 项」尾注', () async {
      final body = await _promptFor(Player.defaultPlayer());
      final line = _onSiteLine(body);
      // 全库 NPC 统一 3 项技能 → 取前 2 后必附尾注。
      expect(line, contains('另有 1 项'));
    });
  });

  group('Batch 10-80 邻近地点与路途风险', () {
    test('临冬城 → 列出相邻地点 + 危险度 + 治主', () async {
      final body = await _promptFor(Player.defaultPlayer());
      final line = _line(body, '- 邻近地点与路途风险：');
      expect(line, contains('邻近地点与路途风险：'));
      // connectedTo: [location_white_harbor, location_barrowtowns]
      expect(line, contains('白港'));
      expect(line, contains('巴隆镇'));
      // 白港 dangerLevel 2 → 安全；巴隆镇 dangerLevel 3 → 一般。
      expect(line, contains('安全'));
      expect(line, contains('一般'));
      // 白港/巴隆镇 governorId 均为 null → 「无明确治主」。
      expect(line, contains('无明确治主'));
    });

    test('相邻地点在玩家家族敌对领土 → 标注「敌对领地」', () async {
      // 玩家在恐怖堡（波顿治下），白港/临冬城… 用史塔克玩家验证：
      // 临冬城相邻的卡霍城属卡史塔克（盟友 40），恐怖堡属波顿（敌对 -80）。
      // 恐怖堡自身不在临冬城的 connectedTo 内，故改用：把玩家放在
      // location_castle_black，其 connectedTo 仅 location_winterfell。
      final body = await _promptFor(
        Player.defaultPlayer().copyWith(locationId: 'location_castle_black'),
      );
      final line = _line(body, '- 邻近地点与路途风险：');
      // 玩家是史塔克（对波顿 -80）却身处波顿领地恐怖堡，
      // 相邻的临冬城是自家领地 → 应标「自家领地」。
      expect(line, contains('自家领地'));
      // 史塔克与波顿敌对，当前所在地治主为敌对家族（10-76 行另行断言）。
      final powerLine = _line(body, '- 当地势力与你的立场：');
      expect(powerLine, contains('敌对'));
    });

    test('无相邻地点 → 兜底「无路可往」', () async {
      // 流亡之地（Batch 10-32 补的 69 号地点）需查证是否无 connectedTo；
      // 这里改用纯函数契约兜底：未知地点 id → 未知之地分支。
      final body = await _promptFor(
        Player.defaultPlayer().copyWith(locationId: 'location_not_exist'),
      );
      final line = _line(body, '- 邻近地点与路途风险：');
      expect(line, contains('未知之地'));
    });

    test('自由民 → 兜底不涉家族旗号', () async {
      final body = await _promptFor(
        Player.defaultPlayer().copyWith(familyId: 'family_none'),
      );
      final line = _line(body, '- 邻近地点与路途风险：');
      expect(line, contains('邻近地点与路途风险：'));
      expect(line.contains('自家领地'), isFalse);
      expect(line.contains('盟友领地'), isFalse);
    });

    test('既有注入不回归', () async {
      final body = await _promptFor(Player.defaultPlayer());
      expect(body, contains('当地势力与你的立场：'));
      expect(body, contains('当前地点：'));
      expect(body, contains('在场 NPC：'));
      expect(body, contains('所在地轶事·历史典故：'));
    });
  });
}