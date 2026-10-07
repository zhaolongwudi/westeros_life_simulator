/// Batch 10-81 / 10-82 测试：AI prompt 玩家技能/属性中文化 + 人数预算化。
///
/// 覆盖：
/// 10-81 玩家技能与属性中文标签化
///  1. 技能行 → 中文键名（剑术/骑术/口才/炼金），无英文裸键
///  2. 属性行 → 中文键名（力量/敏捷/智识/魅力/意志/感知）
///  3. 技能/属性数值全量保留（技能不设预算、不截断；属性 6 项）
/// 10-82 在场 NPC 与 NPC 网络预算化
///  4. 临冬城 8 位 NPC → 只展开预算内前 5 位 + 「另有 N 位在场未展开」尾注
///  5. 被截断的 NPC（第 6 位起）不出现在在场 NPC 段
///  6. 无在场 NPC 地点 → 「（无）」兜底不回归
///  7. 既有注入不回归（在场 NPC 技能/信仰/性格/目标 + NPC 网络 + 玩家技能属性）
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/balance_data.dart';
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

/// 提取以 [anchor] 开头的那一行内容（到行尾/换行为止）。
String _line(String body, String anchor) {
  final start = body.indexOf(anchor);
  expect(start, greaterThanOrEqualTo(0), reason: '缺少注入段落：$anchor');
  final end = body.indexOf('\n', start);
  expect(end, greaterThan(start));
  return body.substring(start, end);
}

void main() {
  group('Batch 10-81 玩家技能/属性中文标签化', () {
    test('技能行 → 中文键名（无英文裸键泄漏）', () async {
      final body = await _promptFor(Player.defaultPlayer());
      final line = _line(body, '- 技能：');
      // defaultPlayer skills: sword 3 / archery 2 / riding 3 / speech 2 / alchemy 0
      expect(line, contains('剑术 3'));
      expect(line, contains('弓术 2'));
      expect(line, contains('骑术 3'));
      expect(line, contains('口才 2'));
      expect(line, contains('炼金 0'));
      // 英文裸键不得出现（含 Dart Map 字面量的 {sword: 3} 形态）
      expect(line.contains('sword'), isFalse);
      expect(line.contains('archery'), isFalse);
      expect(line.contains('riding'), isFalse);
      expect(line.contains('speech'), isFalse);
      expect(line.contains('alchemy'), isFalse);
      // 裸字典形态也不应出现
      expect(line.contains('{'), isFalse);
    });

    test('属性行 → 中文键名（无英文裸键泄漏）', () async {
      final body = await _promptFor(Player.defaultPlayer());
      final line = _line(body, '- 属性：');
      // defaultPlayer attributes: strength/agility/intelligence/charisma/willpower/perception 各 5
      expect(line, contains('力量 5'));
      expect(line, contains('敏捷 5'));
      expect(line, contains('智识 5'));
      expect(line, contains('魅力 5'));
      expect(line, contains('意志 5'));
      expect(line, contains('感知 5'));
      for (final k in const <String>[
        'strength',
        'agility',
        'intelligence',
        'charisma',
        'willpower',
        'perception',
      ]) {
        expect(line.contains(k), isFalse, reason: '属性英文键泄漏：$k');
      }
    });

    test('数值全量保留（技能 7 项 + 属性 6 项，不设预算）', () async {
      final body = await _promptFor(Player.defaultPlayer());
      final skill = _line(body, '- 技能：');
      final attr = _line(body, '- 属性：');
      // 10-81 只中文化键名，键数不截断
      // S4-3c：技能表新增 magic（初始 0 级），故 5 → 6。
      // S12-12：再新增 stealth（初始 0 级，为让 `skills.stealth` 门槛可达），
      // 故 6 → 7。契约（「不设预算、不截断」）不变。
      expect('、'.allMatches(skill).length + 1, 7);
      expect('、'.allMatches(attr).length + 1, 6);
      expect(skill.contains('另有'), isFalse);
      expect(attr.contains('另有'), isFalse);
    });
  });

  group('Batch 10-82 在场 NPC 预算化', () {
    test('临冬城 8 位 NPC → 展开预算内前 5 位 + 尾注', () async {
      final body = await _promptFor(Player.defaultPlayer());
      final seg = _line(body, '- 在场 NPC：');
      final budget = BalanceData.kAiPromptOnSiteNpcBudget;
      // 8 位在场景（艾德/凯特琳/罗柏/珊莎/艾莉亚/布兰/瑞肯/琼恩）
      // 截断尾注：8 - 5 = 3 位未展开
      expect(seg, contains('另有 3 位在场未展开'));
      expect(budget, 5);
    });

    test('预算内前 5 位 NPC 全部展开', () async {
      final body = await _promptFor(Player.defaultPlayer());
      final seg = _line(body, '- 在场 NPC：');
      // allNpcs 数据顺序：艾德/凯特琳/罗柏/珊莎/艾莉亚（第 6 位起被截）
      for (final n in const <String>[
        '艾德·史塔克',
        '凯特琳·史塔克',
        '罗柏·史塔克',
        '珊莎·史塔克',
        '艾莉亚·史塔克',
      ]) {
        expect(seg, contains(n), reason: '预算内 NPC 未展开：$n');
      }
    });

    test('被截断的 NPC（第 6 位起）不出现在在场 NPC 段', () async {
      final body = await _promptFor(Player.defaultPlayer());
      final seg = _line(body, '- 在场 NPC：');
      // 布兰（第 6）/瑞肯（第 7）/琼恩（第 8）在预算 5 之外
      expect(seg.contains('布兰·史塔克'), isFalse);
      expect(seg.contains('瑞肯·史塔克'), isFalse);
      expect(seg.contains('琼恩·雪诺'), isFalse);
    });

    test('无在场 NPC 的地点 → 「（无）」兜底不回归', () async {
      // 未知地点 id 不会命中任何 allNpcs 的 locationId，
      // 故 onSiteNpcDesc == ''，走模板的「（无）」兜底分支。
      final body = await _promptFor(
        Player.defaultPlayer().copyWith(locationId: 'location_not_exist'),
      );
      expect(body, contains('- 在场 NPC：（无）'));
    });

    test('既有注入不回归', () async {
      final body = await _promptFor(Player.defaultPlayer());
      final seg = _line(body, '- 在场 NPC：');
      // 10-79 技能/信仰、10-65 性格/目标、10-22 可委托任务模板仍在
      expect(seg, contains('，信仰：'));
      expect(seg, contains('，性格：'));
      expect(seg, contains('，目标：'));
      expect(seg, contains('，可委托：'));
      // 关系值紧跟全角括号：艾德·史塔克（关系 0，心情沉稳…
      expect(seg, contains('（关系 0，'));
      // 10-73 NPC 网络段落仍在
      expect(body, contains('- NPC 间关系网络：'));
      // 10-81 玩家技能属性行仍在
      expect(body, contains('- 技能：剑术'));
      expect(body, contains('- 属性：力量'));
    });
  });

  group('Batch 10-81/82 文案层与预算常量契约', () {
    test('skillLabel 覆盖玩家侧全部键（10-81 补漏）', () {
      // 10-79 初版只覆盖 NPC 侧三键 + 预留键，
      // 漏了玩家侧 riding/speech/alchemy —— 本批补齐。
      expect(skillLabel('riding'), '骑术');
      expect(skillLabel('speech'), '口才');
      expect(skillLabel('alchemy'), '炼金');
      expect(skillLabel('sword'), '剑术');
      // 未知键原样兜底不抛
      expect(skillLabel('unknown_key'), 'unknown_key');
    });

    test('attributeLabel 覆盖玩家属性全部 6 键 + 未知兜底', () {
      expect(attributeLabel('strength'), '力量');
      expect(attributeLabel('agility'), '敏捷');
      expect(attributeLabel('intelligence'), '智识');
      expect(attributeLabel('charisma'), '魅力');
      expect(attributeLabel('willpower'), '意志');
      expect(attributeLabel('perception'), '感知');
      expect(attributeLabel('unknown_key'), 'unknown_key');
    });

    test('预算常量为正且在场预算覆盖既有测试依赖的前 3 位', () {
      expect(BalanceData.kAiPromptOnSiteNpcBudget, greaterThanOrEqualTo(3));
      expect(BalanceData.kAiPromptNpcNetworkBudget, greaterThanOrEqualTo(2));
    });
  });
}