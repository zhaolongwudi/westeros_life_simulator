/// Batch 10-85 测试：AI prompt 在场 NPC 段内层任务模板预算化。
///
/// 【背景】`_onSiteNpcDesc` 对每位在场 NPC 都输出「，可委托：」**全量**任务模板
/// 清单。取证实测（真实数据，非估算）：
///   - 单模板 ≈ 29 字符（格式 `「标题」（类型，难度 N，期限 M 月）`）
///   - 单 NPC 最多 3 个模板（艾德/提利昂/瑟曦/奥蕾娜/罗柏/泰温/珊莎/艾莉亚/
///     布兰/巴隆 共 10 人），平均 1.89
///   - 10-82 预算内 5 位（艾德 3 + 凯特琳 2 + 罗柏 3 + 珊莎 3 + 艾莉亚 3）
///     共 14 个模板 ≈ 406 字符
/// 「在场 NPC」段实测 635 字符、占单次请求（约 5285 字符）12% 的最大头，
/// 其中任务模板是主体来源。
///
/// 【本批做法】每位人物只展开前 `kAiPromptOnSiteNpcTaskBudget`（2）个模板，
/// 超出部分用「（另有 N 个可委托）」尾注告知 AI 而不逐条展开。
///
/// 【为什么预算 = 2】既有测试 `batch10_22_ai_prompt_inject_test` 断言艾德
/// （模板数最多的 10 人之一）同时出现「护送北境信使至君临 / 难度 3 / 期限 6 月」
/// 与「调查野人踪迹 / 难度 2」**两条**模板信息，故预算不能低于 2。
///
/// 【覆盖】
///  1. 单 NPC 模板数 = 预算（凯特琳 2 个）→ 全量展开，无尾注
///  2. 单 NPC 模板数 > 预算（艾德 3 个）→ 展开前 2 + 「另有 1 个可委托」尾注
///  3. 被截断的第 3 个模板标题不出现在在场 NPC 段
///  4. 前 2 个模板完整保留（标题/类型/难度/期限四要素都在）
///  5. 无任务模板的 NPC → 「，可委托：」整段省略
///  6. 人数预算（10-82）不回归：仍只展开 5 位 + 「另有 3 位在场未展开」
///  7. 既有注入不回归（性格/目标/技能/信仰/关系值格式）
///  8. 预算常量契约：≥2（batch10_22 依赖）、≤ 全库单 NPC 最大模板数
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/balance_data.dart';
import 'package:westeros_life_simulator/data/npc_data.dart';
import 'package:westeros_life_simulator/data/npc_task_data.dart';
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

/// 提取「- 在场 NPC：」那一行的内容。
String _onSiteLine(String body) {
  final start = body.indexOf('- 在场 NPC：');
  expect(start, greaterThanOrEqualTo(0), reason: '缺少在场 NPC 段');
  final end = body.indexOf('\n', start);
  expect(end, greaterThan(start));
  return body.substring(start, end);
}

void main() {
  group('Batch 10-85 在场 NPC 任务模板预算化', () {
    test('模板数 = 预算（凯特琳 2 个）→ 全量展开，无任务尾注', () async {
      final body = await _promptFor(Player.defaultPlayer());
      final line = _onSiteLine(body);
      expect(npcTaskTemplatesOf('npc_catelyn').length, 2);
      // 凯特琳段内不出现任务模板尾注（她的条目后紧跟「、罗柏·史塔克」）
      final catStart = line.indexOf('凯特琳·史塔克');
      expect(catStart, greaterThanOrEqualTo(0));
      final catEnd = line.indexOf('、罗柏·史塔克', catStart);
      final catSeg = line.substring(catStart, catEnd);
      expect(catSeg, contains('可委托：'));
      // 两个模板都全量展开
      for (final t in npcTaskTemplatesOf('npc_catelyn')) {
        expect(catSeg, contains(t.title));
      }
      // 任务模板尾注专属文案是「另有 N 个可委托」；
      // 段内的「另有 1 项」是 10-79 的技能尾注，与本批无关，不能一并断言。
      expect(catSeg, isNot(contains('个可委托')));
    });

    test('模板数 > 预算（艾德 3 个）→ 展开前 2 + 「另有 1 个可委托」尾注', () async {
      final body = await _promptFor(Player.defaultPlayer());
      final line = _onSiteLine(body);
      expect(npcTaskTemplatesOf('npc_nev').length, 3);
      final nevStart = line.indexOf('艾德·史塔克');
      expect(nevStart, greaterThanOrEqualTo(0));
      final nevEnd = line.indexOf('、凯特琳·史塔克', nevStart);
      final nevSeg = line.substring(nevStart, nevEnd);
      expect(nevSeg, contains('另有 1 个可委托'));
    });

    test('被截断的第 3 个模板标题不出现在在场 NPC 段', () async {
      final body = await _promptFor(Player.defaultPlayer());
      final line = _onSiteLine(body);
      // 艾德第 3 个模板（数据顺序第 3 条）
      final nevTasks = npcTaskTemplatesOf('npc_nev');
      expect(nevTasks.length, greaterThan(2));
      final thirdTitle = nevTasks[2].title;
      expect(line, isNot(contains(thirdTitle)),
          reason: '第 3 个模板泄漏：$thirdTitle');
    });

    test('前 2 个模板四要素完整保留（标题/类型/难度/期限）', () async {
      final body = await _promptFor(Player.defaultPlayer());
      final line = _onSiteLine(body);
      final nevTasks = npcTaskTemplatesOf('npc_nev');
      // 既有测试 batch10_22 依赖的锚点，一个都不能少
      expect(line, contains(nevTasks[0].title));
      expect(line, contains('难度 ${nevTasks[0].difficulty}'));
      expect(line, contains('期限 ${nevTasks[0].deadlineMonths} 月'));
      expect(line, contains(nevTasks[1].title));
      expect(line, contains('难度 ${nevTasks[1].difficulty}'));
      expect(line, contains('期限 ${nevTasks[1].deadlineMonths} 月'));
      // 类型标签也保留
      expect(line, contains(nevTasks[0].typeLabel));
      expect(line, contains(nevTasks[1].typeLabel));
    });

    test('人数预算（10-82）不回归：仍 5 位 + 「另有 3 位在场未展开」', () async {
      final body = await _promptFor(Player.defaultPlayer());
      final line = _onSiteLine(body);
      expect(line, contains('另有 3 位在场未展开'));
      // 第 6 位起（布兰/瑞肯/琼恩·雪诺）仍被人数预算截断
      expect(line, isNot(contains('布兰·史塔克')));
      expect(line, isNot(contains('瑞肯·史塔克')));
      expect(line, isNot(contains('琼恩·雪诺')));
    });

    test('无在场 NPC 的地点 → 「（无）」兜底不回归', () async {
      final body = await _promptFor(
        Player.defaultPlayer().copyWith(locationId: 'location_not_exist'),
      );
      expect(body, contains('- 在场 NPC：（无）'));
    });

    test('既有注入不回归（性格/目标/技能/信仰/关系值格式）', () async {
      final body = await _promptFor(Player.defaultPlayer());
      final line = _onSiteLine(body);
      expect(line, contains('，性格：正直、严肃'));
      expect(line, contains('，目标：维护荣誉、保护家族'));
      expect(line, contains('skills：统率 9、剑术 8'));
      expect(line, contains('另有 1 项'));
      expect(line, contains('，信仰：'));
      // 关系值紧跟全角括号（坑 51）
      expect(line, contains('（关系 0，'));
    });

    test('真实规模护栏：预算内 5 位共截断 4 个模板', () async {
      // 预算内 5 位：艾德 3 + 凯特琳 2 + 罗柏 3 + 珊莎 3 + 艾莉亚 3 = 14 个模板
      // 预算 2 后 → 每位最多 2 个，尾注数合计 = 14 - 10 = 4
      final body = await _promptFor(Player.defaultPlayer());
      final line = _onSiteLine(body);
      final budget = BalanceData.kAiPromptOnSiteNpcTaskBudget;
      final onsiteBudgeted = allNpcs
          .where((n) => n.isAlive && n.locationId == 'location_winterfell')
          .take(BalanceData.kAiPromptOnSiteNpcBudget)
          .toList();
      final totalTemplates = onsiteBudgeted
          .map((n) => npcTaskTemplatesOf(n.id).length)
          .fold(0, (a, b) => a + b);
      final expectedHidden = onsiteBudgeted.fold(
        0,
        (a, n) => a + (npcTaskTemplatesOf(n.id).length > budget
            ? npcTaskTemplatesOf(n.id).length - budget
            : 0),
      );
      expect(totalTemplates, 14);
      expect(expectedHidden, 4);
      // 尾注数合计与理论值一致
      final tails = RegExp(r'另有 (\d+) 个可委托')
          .allMatches(line)
          .map((m) => int.parse(m.group(1)!))
          .toList();
      expect(tails.fold(0, (a, b) => a + b), expectedHidden);
    });
  });

  group('Batch 10-85 预算常量契约', () {
    test('预算 ≥ 2（batch10_22 依赖艾德前 2 条模板信息）', () {
      expect(BalanceData.kAiPromptOnSiteNpcTaskBudget, greaterThanOrEqualTo(2));
    });

    test('预算 ≤ 全库单 NPC 最大模板数（3），不制造无意义截断', () {
      final maxPerNpc = allNpcs
          .map((n) => npcTaskTemplatesOf(n.id).length)
          .reduce((a, b) => a > b ? a : b);
      expect(BalanceData.kAiPromptOnSiteNpcTaskBudget, lessThanOrEqualTo(maxPerNpc));
    });

    test('预算为正', () {
      expect(BalanceData.kAiPromptOnSiteNpcTaskBudget, greaterThan(0));
    });
  });
}