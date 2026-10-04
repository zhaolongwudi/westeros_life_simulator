/// Batch 10-84 测试：AI prompt 硬编码 take() 收口到 balance_data。
///
/// 【背景】`ai_service.dart` 的 prompt 构建里散落 10 处裸数字截断：
///   worldNews take(2) / 家族 secrets take(2) / 家族成员 take(6) /
///   性格 take(2) / 目标 take(2) / NPC skills take(2) + rest=length-2 /
///   邻近地点 take(4) + tail>4 / 相关事件 parts>=3 / 世界立场 take(3)
/// 这些数字没有单一真相，改一处要翻 10 行注释；且 `_skillDesc` 里
/// `take(2)` 与 `length - 2` 两处硬编码必须同步改，容易漏。
///
/// 【本批做法】每个数字提到 `BalanceData.kAiPromptXxxCount` 常量，
/// 取值与原硬编码完全一致（**纯重构，输出逐字不变**），
/// 测试锁死「常量值 == 原数字」+「既有注入断言不回归」。
///
/// 【覆盖】
///  1. 8 个新预算常量值与原硬编码逐项相等（纯重构护栏）
///  2. 各常量下限不低于既有测试断言依赖（技能 2 / 秘密 2 / 性格 2 等）
///  3. ai_service.dart 无残留 `.take(数字)` 硬编码（源码级扫描）
///  4. 既有注入全部不回归（世界局势 / 家族成员 / 性格目标 / 技能尾注 /
///     邻近地点 / 相关事件 / 世界立场 / 家族对外关系）
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/balance_data.dart';
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

void main() {
  group('Batch 10-84 预算常量值 == 原硬编码（纯重构护栏）', () {
    test('8 个常量取值与收口前逐项相等', () {
      // 收口前的裸数字，见 git show HEAD~2:lib/services/ai_service.dart
      expect(BalanceData.kAiPromptWorldNewsCount, 2); // worldNews take(2)
      expect(BalanceData.kAiPromptFamilySecretCount, 2); // pf.secrets.take(2)
      expect(BalanceData.kAiPromptFamilyMemberCount, 6); // npcsByFamily take(6)
      expect(BalanceData.kAiPromptNpcTraitCount, 2); // personality.take(2)
      expect(BalanceData.kAiPromptNpcGoalCount, 2); // goals.take(2)
      expect(BalanceData.kAiPromptNpcSkillCount, 2); // skills.take(2)
      expect(BalanceData.kAiPromptNearbyLocationCount, 4); // connectedTo.take(4)
      expect(BalanceData.kAiPromptRelevantEventCount, 3); // parts.length >= 3
      expect(BalanceData.kAiPromptStanceNpcCount, 3); // relatedNpcs take(3)
    });

    test('全部常量为正', () {
      const all = <int>[
        BalanceData.kAiPromptWorldNewsCount,
        BalanceData.kAiPromptFamilySecretCount,
        BalanceData.kAiPromptFamilyMemberCount,
        BalanceData.kAiPromptNpcTraitCount,
        BalanceData.kAiPromptNpcGoalCount,
        BalanceData.kAiPromptNpcSkillCount,
        BalanceData.kAiPromptNearbyLocationCount,
        BalanceData.kAiPromptRelevantEventCount,
        BalanceData.kAiPromptStanceNpcCount,
      ];
      for (final v in all) {
        expect(v, greaterThan(0));
      }
    });

    test('技能预算 ≥ 2（既有测试断言「另有 1 项」依赖前 2 项）', () {
      expect(BalanceData.kAiPromptNpcSkillCount, greaterThanOrEqualTo(2));
    });

    test('家族秘密预算 ≥ 2（既有测试断言史塔克 2 条秘密全出）', () {
      expect(BalanceData.kAiPromptFamilySecretCount, greaterThanOrEqualTo(2));
    });

    test('性格/目标预算 ≥ 2（既有测试断言「正直、严肃」「维护荣誉、保护家族」）', () {
      expect(BalanceData.kAiPromptNpcTraitCount, greaterThanOrEqualTo(2));
      expect(BalanceData.kAiPromptNpcGoalCount, greaterThanOrEqualTo(2));
    });

    test('ai_service.dart 无残留 `.take(数字)` 硬编码（源码级扫描）', () {
      final src = File('lib/services/ai_service.dart').readAsStringSync();
      final hardCoded = RegExp(r'\.take\(\s*\d')
          .allMatches(src)
          .map((m) => m.group(0))
          .toList();
      expect(
        hardCoded,
        isEmpty,
        reason: '仍有裸数字截断：$hardCoded（10-84 应全部收口到 balance_data）',
      );
    });
  });

  group('Batch 10-84 既有注入全部不回归（输出逐字不变）', () {
    test('在场 NPC：性格前 2 + 目标前 2（第三条「忠诚」不出现）', () async {
      final body = await _promptFor(Player.defaultPlayer());
      final start = body.indexOf('- 在场 NPC：');
      expect(start, greaterThanOrEqualTo(0));
      final line = body.substring(start, body.indexOf('\n', start));
      expect(line, contains('，性格：正直、严肃'));
      expect(line, isNot(contains('性格：正直、严肃、忠诚')));
      expect(line, contains('，目标：维护荣誉、保护家族'));
    });

    test('在场 NPC：技能前 2 + 「另有 1 项」尾注', () async {
      final body = await _promptFor(Player.defaultPlayer());
      final start = body.indexOf('- 在场 NPC：');
      final line = body.substring(start, body.indexOf('\n', start));
      // 艾德 skills: sword 8 / leadership 9 / politics 7 → 取前 2（统率 9、剑术 8）
      expect(line, contains('skills：统率 9、剑术 8'));
      expect(line, contains('另有 1 项'));
      expect(line, contains('，信仰：'));
    });

    test('家族段：对外关系 4 条 + 特质 + 秘密 2 条全出', () async {
      final body = await _promptFor(Player.defaultPlayer());
      final start = body.indexOf('- 家族：');
      final line = body.substring(start, body.indexOf('\n', start));
      expect(line, contains('史塔克家族'));
      expect(line, contains('族语「凛冬将至」'));
      expect(line, contains('对外关系：'));
      expect(line, contains('兰尼斯特（敌对 -50）'));
      expect(line, contains('波顿（敌对 -80）'));
      expect(line, contains('徒利（友善 60）'));
      expect(line, contains('莫尔蒙（友善 50）'));
      expect(line, contains('；特质：'));
      expect(line, contains('秘密：琼恩·雪诺的真实身份、史塔克家族与龙的关系'));
    });

    test('家族成员段：史塔克在世成员前 6 位展开', () async {
      final body = await _promptFor(Player.defaultPlayer());
      final start = body.indexOf('- 家族成员：');
      final line = body.substring(start, body.indexOf('\n', start));
      expect(line, contains('艾德·史塔克'));
      expect(line, contains('罗柏·史塔克'));
      expect(line, contains('贵族'));
      expect(line, contains('临冬城'));
      expect(line, contains('关系 0'));
    });

    test('邻近地点与路途风险：临冬城 2 个相连地点全展开（未触发截断）', () async {
      final body = await _promptFor(Player.defaultPlayer());
      final start = body.indexOf('- 邻近地点与路途风险：');
      final line = body.substring(start, body.indexOf('\n', start));
      expect(line, contains('自临冬城可往：'));
      expect(line, contains('，治主：'));
      // 临冬城 connectedTo = [location_white_harbor, location_barrowtowns]（2 条）
      expect(line, contains('白港'));
      expect(line, contains('巴隆镇'));
      // 2 条 → 分隔符「；」出现 1 次，且无「另有 N 处未列」尾注
      expect('；'.allMatches(line).length, 1);
      expect(line, isNot(contains('处未列')));
    });

    test('本月世界局势 + 局势关联 NPC 立场段存在', () async {
      final body = await _promptFor(
        Player.defaultPlayer().copyWith(
          relations: const <String, int>{'npc_nev': 80},
        ),
      );
      expect(body, contains('本月世界局势：'));
      expect(body, contains('局势关联 NPC 立场：'));
    });

    test('其他注入段不回归（地点 / NPC 网络 / 在场 NPC / 事件）', () async {
      final body = await _promptFor(Player.defaultPlayer());
      expect(body, contains('当前地点：'));
      expect(body, contains('- 当地势力与你的立场：'));
      expect(body, contains('- NPC 间关系网络：'));
      expect(body, contains('- 在场 NPC：'));
      expect(body, contains('可用事件：'));
      expect(body, contains('与你相关的可用事件：'));
      expect(body, contains('季节世界动向：'));
      expect(body, contains('地区风土人情：'));
      expect(body, contains('时节农事：'));
      expect(body, contains('本地集市行情：'));
      expect(body, contains('所在地轶事·历史典故：'));
      expect(body, contains('叙事引导（身份）：'));
      expect(body, contains('叙事引导（区域）：'));
      expect(body, contains('叙事引导（季节）：'));
    });

    test('输出格式尾部（效果键约定 + JSON 示例）完整保留', () async {
      final body = await _promptFor(Player.defaultPlayer());
      expect(body, contains('请生成一段叙事文本（200-500 字）'));
      expect(body, contains('输出格式（JSON）：'));
      expect(body, contains('"narrative": "叙事文本"'));
      expect(body, contains('"choices"'));
      // 效果键约定 7 条全在
      for (final k in const <String>[
        'gold',
        'reputation',
        'skills.sword',
        'attributes.strength',
        'relations.tyrion',
        'flags.honor_pledge',
        'inventory.item_bread',
      ]) {
        expect(body, contains(k), reason: '效果键约定丢失：$k');
      }
    });
  });
}