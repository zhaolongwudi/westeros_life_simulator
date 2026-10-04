/// Batch 10-83 测试：AI prompt 玩家关系段人数预算。
///
/// 【背景】`player.relations` 是长会话里唯一无上限累积的 map：与 NPC 交互、
/// 任务完成、选项 effects 里的 `relations.<npcId>` 都会写入键，全库 38 个 NPC
/// 意味着最坏情况累积 38 键。实测单条关系行约 37 字符，38 条全量注入
/// ≈ 1443 字符，是 prompt 里唯一随回合数无界增长的大段。
///
/// 【本批做法】按 |关系值| 降序取前 `kAiPromptRelationBudget`（8）位，
/// 超出部分只给「另有 N 人有交情」尾注。
///
/// 【覆盖】
///  1. 关系条数 ≤ 预算 → 全量展开，无尾注
///  2. 关系条数 > 预算 → 只展开前 8 位 + 「另有 N 人有交情」尾注
///  3. 按 |关系值| 降序：最恨/最爱的人在预算内，关系平淡者被截断
///  4. 截断后的 NPC 不出现在关系段
///  5. 关系为空 → 「（无）」兜底不回归
///  6. 既有格式不回归（名字（身份·家族·所在地，秘密：xxx）: N）
///  7. 预算常量契约：高于既有测试依赖的最大关系数（batch10_73 的 3 条）
///  8. 全部 38 个 NPC 都有关系时，关系段仍受预算约束（真实数据规模护栏）
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/balance_data.dart';
import 'package:westeros_life_simulator/data/npc_data.dart';
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

/// 提取「- 关系（NPC: 好感度）：」那一行的内容。
String _relationLine(String body) {
  final start = body.indexOf('- 关系（NPC: 好感度）：');
  expect(start, greaterThanOrEqualTo(0), reason: '缺少关系段');
  final end = body.indexOf('\n', start);
  expect(end, greaterThan(start));
  return body.substring(start, end);
}

/// 构造 n 条关系：第 i 条的关系值取 `values[i]`。
Player _playerWith(List<int> values) {
  final rels = <String, int>{};
  for (var i = 0; i < values.length; i++) {
    // allNpcs 的前 n 个 id，保证都是真实 NPC（走中文格式分支）。
    rels[allNpcs[i].id] = values[i];
  }
  return Player.defaultPlayer().copyWith(relations: rels);
}

void main() {
  group('Batch 10-83 玩家关系段预算化', () {
    test('关系条数 ≤ 预算 → 全量展开，无尾注', () async {
      final body = await _promptFor(_playerWith(<int>[80, 60, 40, 20]));
      final line = _relationLine(body);
      expect(line, contains('艾德·史塔克'));
      expect(line, contains('凯特琳·史塔克'));
      expect(line, contains('罗柏·史塔克'));
      expect(line, contains('珊莎·史塔克'));
      expect(line, isNot(contains('有交情')));
    });

    test('关系条数 > 预算 → 只展开前 8 位 + 「另有 N 人有交情」尾注', () async {
      final body = await _promptFor(_playerWith(List<int>.generate(12, (i) => 50)));
      final line = _relationLine(body);
      final budget = BalanceData.kAiPromptRelationBudget;
      expect(budget, 8);
      // 12 - 8 = 4 位未展开
      expect(line, contains('另有 4 人有交情'));
      expect(line, isNot(contains('另有 5 人有交情')));
    });

    test('按 |关系值| 降序：最恨/最爱的人在预算内，平淡者被截断', () async {
      // 前 8 条关系值平淡（1~8），后 4 条极端（100 / -100 / 90 / -90）。
      // allNpcs 真实顺序：[8]=卢斯·波顿 [9]=拉姆斯·波顿 [10]=杰奥·莫尔蒙 [11]=霍斯特·徒利
      final body = await _promptFor(_playerWith(
        <int>[1, 2, 3, 4, 5, 6, 7, 8, 100, -100, 90, -90],
      ));
      final line = _relationLine(body);
      // 极端关系者（|值| ≥ 90）必在预算内
      expect(line, contains('卢斯·波顿'));
      expect(line, contains('拉姆斯·波顿'));
      expect(line, contains('杰奥·莫尔蒙'));
      expect(line, contains('霍斯特·徒利'));
      // 平淡关系的头两位被截断（allNpcs[0]=艾德、[1]=凯特琳）
      expect(line, isNot(contains('艾德·史塔克')));
      expect(line, isNot(contains('凯特琳·史塔克')));
      expect(line, contains('另有 4 人有交情'));
    });

    test('被截断的 NPC 不出现在关系段', () async {
      final rels = <String, int>{};
      for (var i = 0; i < 12; i++) {
        rels[allNpcs[i].id] = 10;
      }
      final body = await _promptFor(Player.defaultPlayer().copyWith(relations: rels));
      final line = _relationLine(body);
      // 同值 10 时按 id 字典序取前 8，断言末两位 NPC 被截断
      final shown = allNpcs
          .where((n) => rels.containsKey(n.id))
          .map((n) => n.id)
          .toList()
        ..sort();
      final truncatedIds = shown.skip(BalanceData.kAiPromptRelationBudget).toList();
      expect(truncatedIds, isNotEmpty);
      for (final id in truncatedIds) {
        final n = allNpcs.firstWhere((x) => x.id == id);
        expect(line, isNot(contains(n.name)), reason: '被截断的 NPC 泄漏：${n.name}');
      }
    });

    test('真实数据规模护栏：38 个 NPC 全有关系 → 关系段仍受预算约束', () async {
      final rels = <String, int>{};
      for (var i = 0; i < allNpcs.length; i++) {
        rels[allNpcs[i].id] = 100 - i;
      }
      final body = await _promptFor(Player.defaultPlayer().copyWith(relations: rels));
      final line = _relationLine(body);
      // 38 - 8 = 30 位未展开
      expect(line, contains('另有 30 人有交情'));
      // 关系段不应出现全部 38 个名字（截断生效）
      final names = allNpcs.map((n) => n.name).where((x) => line.contains(x)).length;
      expect(names, BalanceData.kAiPromptRelationBudget);
    });
  });

  group('Batch 10-83 既有契约不回归', () {
    test('关系为空 → 「（无）」兜底', () async {
      final body = await _promptFor(Player.defaultPlayer());
      expect(body, contains('- 关系（NPC: 好感度）：（无）'));
    });

    test('既有格式不回归（名字（身份·家族·所在地，秘密：xxx）: N）', () async {
      final body = await _promptFor(
        Player.defaultPlayer().copyWith(
          relations: const <String, int>{'npc_nev': 85},
        ),
      );
      final line = _relationLine(body);
      expect(line, contains('艾德·史塔克'));
      expect(line, contains('贵族'));
      expect(line, contains('史塔克家族'));
      expect(line, contains('临冬城'));
      expect(line, contains('秘密：琼恩·雪诺的真实身份'));
      expect(line, contains(': 85'));
    });

    test('未知 NPC ID 回退原格式不回归', () async {
      final body = await _promptFor(
        Player.defaultPlayer().copyWith(
          relations: const <String, int>{'npc_ghost': 30},
        ),
      );
      final line = _relationLine(body);
      expect(line, contains('npc_ghost: 30'));
      expect(line, isNot(contains('（贵族')));
    });

    test('单条关系（既有测试最大依赖形态）不回归', () async {
      // batch10_63/64/70/71/72 全部用单条或 1~3 条关系，
      // 预算 8 远高于此，输出应与旧版逐字一致。
      final body = await _promptFor(
        Player.defaultPlayer().copyWith(
          relations: const <String, int>{'npc_nev': 60},
        ),
      );
      final line = _relationLine(body);
      expect(line, contains('艾德·史塔克'));
      expect(line, contains(': 60'));
      expect(line, isNot(contains('有交情')));
    });

    test('其他注入段不回归（在场 NPC / NPC 网络 / 家族 / 世界局势）', () async {
      final body = await _promptFor(
        Player.defaultPlayer().copyWith(
          relations: const <String, int>{
            'npc_nev': 80,
            'npc_catelyn': 60,
            'npc_robb': 40,
          },
        ),
      );
      expect(body, contains('- 在场 NPC：'));
      expect(body, contains('- NPC 间关系网络：'));
      expect(body, contains('- 家族：'));
      expect(body, contains('- 家族成员：'));
      expect(body, contains('- 家族在权力网络中的位置：'));
      expect(body, contains('本月世界局势：'));
      expect(body, contains('局势关联 NPC 立场：'));
    });
  });

  group('Batch 10-83 预算常量契约', () {
    test('预算高于既有测试依赖的最大关系数（batch10_73 的 3 条）', () {
      expect(BalanceData.kAiPromptRelationBudget, greaterThanOrEqualTo(3));
    });

    test('预算为正且不超过全库 NPC 总数', () {
      expect(BalanceData.kAiPromptRelationBudget, greaterThan(0));
      expect(
        BalanceData.kAiPromptRelationBudget,
        lessThanOrEqualTo(allNpcs.length),
      );
    });

    test('预算与在场 NPC 预算同量级（在场的必然已展开）', () {
      // 在场 NPC 预算 5 ≤ 关系预算 8：玩家在同一地点遇见的人必然出现在关系段里。
      expect(
        BalanceData.kAiPromptRelationBudget,
        greaterThanOrEqualTo(BalanceData.kAiPromptOnSiteNpcBudget),
      );
    });
  });
}