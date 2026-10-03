/// Batch 10-63/64 测试：AI prompt 注入增强。
///
/// Batch 10-63 覆盖：
/// 1. 当前地点详情注入（地点名/类型/危险度/人口/特色/可前往/描述）
/// 2. 未知地点兜底
/// 3. 既有注入（世界局势/季节动向/地域/农事/集市）不回归
///
/// Batch 10-64 覆盖：
/// 1. 关系 NPC 身份注入（名字（身份·家族·所在地）: 好感度）
/// 2. 未知 NPC ID 回退原格式
/// 3. 关系为空兜底
/// 4. 标签函数契约（locationTypeLabel/npcTypeLabel 关键值）
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/models/event.dart';
import 'package:westeros_life_simulator/models/location.dart';
import 'package:westeros_life_simulator/models/npc.dart';
import 'package:westeros_life_simulator/models/player.dart';
import 'package:westeros_life_simulator/services/ai_service.dart';
import 'package:westeros_life_simulator/utils/labels.dart';

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
    availableEvents: const <GameEvent>[],
    season: season,
    maxRetries: 0,
  );
  expect(captured[0], isNotNull);
  return captured[0]!;
}

/// 提取「当前地点」段落内容（「当前地点：」之后、「- 金币」之前）。
String _locationSection(String body) {
  final start = body.indexOf('当前地点：');
  expect(start, greaterThanOrEqualTo(0));
  final end = body.indexOf('- 金币：', start);
  expect(end, greaterThan(start));
  return body.substring(start, end);
}

/// 提取「关系」行内容（「关系（NPC: 好感度）：」行）。
String _relationLine(String body) {
  final start = body.indexOf('关系（NPC: 好感度）：');
  expect(start, greaterThanOrEqualTo(0));
  final end = body.indexOf('\n', start);
  expect(end, greaterThan(start));
  return body.substring(start, end);
}

void main() {
  group('Batch 10-63 当前地点详情注入', () {
    test('临冬城注入地点名/类型/危险/人口/特色/可前往/描述', () async {
      final body = await _promptFor(Player.defaultPlayer());
      final section = _locationSection(body);
      expect(section, contains('临冬城'));
      expect(section, contains('城堡'));
      expect(section, contains('一般'));
      expect(section, contains('人口约 5000'));
      expect(section, contains('史塔克家族领地'));
      expect(section, contains('鱼梁木'));
      expect(section, contains('白港'));
      expect(section, contains('巴隆镇'));
      expect(section, contains('史塔克家族世代居住的城堡'));
    });

    test('君临城注入城市类型与高人口', () async {
      final body = await _promptFor(
        Player.defaultPlayer().copyWith(locationId: 'location_kings_landing'),
      );
      final section = _locationSection(body);
      expect(section, contains('君临城'));
      expect(section, contains('城市'));
      expect(section, contains('人口约 500000'));
      expect(section, contains('铁王座'));
      expect(section, contains('七国之都'));
    });

    test('高庭低危险度分级为安全', () async {
      final body = await _promptFor(
        Player.defaultPlayer().copyWith(locationId: 'location_highgarden'),
      );
      final section = _locationSection(body);
      expect(section, contains('高庭'));
      expect(section, contains('安全'));
      expect(section, contains('最富庶的领地'));
    });

    test('未知地点兜底文案', () async {
      final body = await _promptFor(
        Player.defaultPlayer().copyWith(locationId: 'location_unknown_nowhere'),
      );
      expect(body, contains('当前地点：'));
      final section = _locationSection(body);
      expect(section, contains('（未知之地）'));
    });

    test('既有注入（世界局势/季节动向/地区风土人情/时节农事/集市）不回归', () async {
      final body = await _promptFor(Player.defaultPlayer());
      expect(body, contains('本月世界局势：'));
      expect(body, contains('季节世界动向：'));
      expect(body, contains('地区风土人情：'));
      expect(body, contains('时节农事：'));
      expect(body, contains('本地集市行情：'));
      expect(body, contains('叙事引导（区域）：'));
    });
  });

  group('Batch 10-64 关系 NPC 身份注入', () {
    test('已知 NPC 注入身份信息（名字（身份·家族·所在地）: 好感度）', () async {
      final body = await _promptFor(
        Player.defaultPlayer().copyWith(
          relations: const {'npc_nev': 85},
        ),
      );
      final line = _relationLine(body);
      expect(line, contains('艾德·史塔克'));
      expect(line, contains('贵族'));
      expect(line, contains('史塔克家族'));
      expect(line, contains('临冬城'));
      expect(line, contains(': 85'));
    });

    test('未知 NPC ID 回退原格式', () async {
      final body = await _promptFor(
        Player.defaultPlayer().copyWith(
          relations: const {'npc_ghost': 30},
        ),
      );
      final line = _relationLine(body);
      expect(line, contains('npc_ghost: 30'));
      expect(line, isNot(contains('（贵族')));
    });

    test('关系为空兜底', () async {
      final body = await _promptFor(Player.defaultPlayer());
      final line = _relationLine(body);
      expect(line, contains('（无）'));
    });

    test('既有注入不回归（当前地点/在场NPC/背包/状态）', () async {
      final body = await _promptFor(Player.defaultPlayer());
      expect(body, contains('当前地点：'));
      expect(body, contains('在场 NPC：'));
      expect(body, contains('背包：'));
      expect(body, contains('状态：'));
    });
  });

  group('Batch 10-63/64 标签函数契约', () {
    test('locationTypeLabel 关键值', () {
      expect(locationTypeLabel(LocationType.castle), '城堡');
      expect(locationTypeLabel(LocationType.city), '城市');
      expect(locationTypeLabel(LocationType.wilderness), '荒野');
      expect(locationTypeLabel(LocationType.supernatural), '超自然领域');
      expect(locationTypeLabel(LocationType.unknown), '未知世界');
    });
    test('npcTypeLabel 关键值', () {
      expect(npcTypeLabel(NpcType.noble), '贵族');
      expect(npcTypeLabel(NpcType.wildling), '野人');
      expect(npcTypeLabel(NpcType.maester), '学士');
      expect(npcTypeLabel(NpcType.commoner), '平民');
      expect(npcTypeLabel(NpcType.supernatural), '超自然存在');
    });
  });
}
