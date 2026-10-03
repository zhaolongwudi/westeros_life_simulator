/// Batch 10-69 测试：AI 注入所在地名人轶事·历史典故。
///
/// 覆盖：
/// 1. 知名地点典故注入（临冬城/君临/凯岩城/高庭/长城/龙石岛）
/// 2. 区域级典故兜底（未知地点回退区域历史底色）
/// 3. 未知区域兜底文案
/// 4. 既有注入（世界局势/季节动向/地区风土人情/时节农事/集市）不回归
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/narrative_templates.dart';
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

/// 提取「所在地轶事·历史典故」段落内容（段落标题之后、可用事件之前）。
String _loreSection(String body) {
  final start = body.indexOf('所在地轶事·历史典故：');
  expect(start, greaterThanOrEqualTo(0));
  final end = body.indexOf('可用事件：', start);
  expect(end, greaterThan(start));
  return body.substring(start, end);
}

void main() {
  group('Batch 10-69 所在地名人轶事注入', () {
    test('临冬城注入鱼梁木/先民/史塔克典故', () async {
      final body = await _promptFor(Player.defaultPlayer());
      final section = _loreSection(body);
      expect(section, contains('临冬城'));
      expect(section, contains('鱼梁木'));
      expect(section, contains('先民'));
      expect(section, contains('凛冬将至'));
      expect(section, contains('神木林'));
    });

    test('君临城注入铁王座/征服者典故', () async {
      final body = await _promptFor(
        Player.defaultPlayer().copyWith(locationId: 'location_kings_landing'),
      );
      final section = _loreSection(body);
      expect(section, contains('君临'));
      expect(section, contains('铁王座'));
      expect(section, contains('伊耿'));
      expect(section, contains('七国统一'));
    });

    test('凯岩城注入金矿/兰尼斯特典故', () async {
      final body = await _promptFor(
        Player.defaultPlayer().copyWith(locationId: 'location_casterly_rock'),
      );
      final section = _loreSection(body);
      expect(section, contains('凯岩城'));
      expect(section, contains('金矿'));
      expect(section, contains('兰尼斯特'));
      expect(section, contains('听我怒吼'));
    });

    test('长城注入守夜人/长夜将至誓言典故', () async {
      final body = await _promptFor(
        Player.defaultPlayer().copyWith(locationId: 'location_the_wall'),
      );
      final section = _loreSection(body);
      expect(section, contains('长城'));
      expect(section, contains('守夜人'));
      expect(section, contains('长夜将至'));
      expect(section, contains('八千年前'));
    });

    test('高庭注入玫瑰/提利尔典故', () async {
      final body = await _promptFor(
        Player.defaultPlayer().copyWith(locationId: 'location_highgarden'),
      );
      final section = _loreSection(body);
      expect(section, contains('高庭'));
      expect(section, contains('玫瑰'));
      expect(section, contains('提利尔'));
      expect(section, contains('生生不息'));
    });

    test('龙石岛注入坦格利安/征服起点典故', () async {
      final body = await _promptFor(
        Player.defaultPlayer().copyWith(locationId: 'location_dragonstone'),
      );
      final section = _loreSection(body);
      expect(section, contains('龙石岛'));
      expect(section, contains('坦格利安'));
      expect(section, contains('伊耿'));
      expect(section, contains('瓦雷利亚'));
    });

    test('未知地点回退区域级历史底色（北境）', () async {
      final body = await _promptFor(
        Player.defaultPlayer().copyWith(locationId: 'location_barrowtowns'),
      );
      final section = _loreSection(body);
      expect(section, contains('北境'));
      expect(section, contains('先民'));
      expect(section, contains('神木林'));
    });

    test('未知区域兜底文案', () async {
      // 直接测纯函数：未知区域 + 未知地点应返回通用兜底。
      final lore = locationLore('无名之地', 'location_nowhere');
      expect(lore, contains('历史底蕴'));
      expect(lore, contains('传说'));
    });

    test('既有注入（世界局势/季节动向/地区/农事/集市）不回归', () async {
      final body = await _promptFor(Player.defaultPlayer());
      expect(body, contains('本月世界局势：'));
      expect(body, contains('季节世界动向：'));
      expect(body, contains('地区风土人情：'));
      expect(body, contains('时节农事：'));
      expect(body, contains('本地集市行情：'));
      expect(body, contains('所在地轶事·历史典故：'));
      expect(body, contains('叙事引导（区域）：'));
    });
  });
}