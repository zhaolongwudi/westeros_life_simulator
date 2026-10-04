/// Batch 10-89/90 测试：AI 效果键契约修复 + 数值护栏统一。
///
/// 【10-89 取证：prompt 示例的 NPC id 根本不存在】
/// `_buildPrompt` 尾部的「效果键约定」示例写的是 `relations.tyrion: 10`，
/// 但全库 **38/38 个 NPC 的 id 都带 `npc_` 前缀**（`npc_tyrion`）。
/// 而关系段（10-64 起）只给中文名（「提利昂·兰尼斯特（贵族·兰尼斯特家族·
/// 君临城）」），**从不给 id**——AI 既无 id 可抄，又被示例诱导去猜，
/// 于是写入一个永不会命中的幽灵键 `relations.tyrion`：
///   - 好感度永远加不到提利昂身上（`npcRelation('npc_tyrion')` 恒 0）；
///   - 幽灵键还会**倒灌 10-83 的关系段预算**：它按 |关系值| 参与降序排序，
///     白占一个预算位（最坏 8 个位置里有一个是幽灵）。
/// 本批修复三处：
///   1. 关系行尾部补 `[id=<npcId>]`——AI 只需复制粘贴；
///   2. 效果键约定的示例改真 id `relations.npc_tyrion`；
///   3. 约定头部加「原样复制，不要自行翻译或简写」的硬约束 + 可用键白名单，
///      systemPrompt 同步补一条（AI 侧唯一的格式契约来源）。
///
/// 【10-90 取证：好感度护栏只做了一半】
/// 好感度有两条写入通道，历史上只有一条带护栏：
///   ① `event_service.applyEffects` → `.clamp(-100, 100)`（早就有）
///   ② `GameStateProvider.applyEffects`（**AI 选项走这条**）→ 裸加法，无上界
/// AI 输出 `relations.npc_tyrion: 9999` 就能让关系值无上界累积，连带三处失效：
///   - `npcRelationLabel` 六档阈值（±20/40/60/80）越界后全是「挚友」；
///   - `npcFavor` 示好成本 `(5 + (100 - rel) ~/ 20).clamp(3, 12)` 恒为 3 金；
///   - `ai_service` 敌友判定 ±20 失去区分度。
/// 本批把边界收口成 `BalanceData.kRelationClamp`（单一真相），
/// 两条通道共用；并给 `skills.`/`attributes.` 补 `max(0, ...)` 防负等级
/// （与 gold 的 `max(0, ...)` 同策略；`alchemy` 默认就是 0，说明负值无语义）。
///
/// 【本文件覆盖】
///  1. 10-89：关系行带真实 id / 示例用真 id / 硬约束文案 / systemPrompt 同步
///  2. 10-89 回归：既有关系行形态（10-63/64/67/68/83 依赖）不回归
///  3. 10-90：provider 侧 clamp 生效（上下界双向）+ 与 event_service 边界一致
///  4. 10-90：skills/attributes 防负破底
///  5. 10-90：kRelationClamp == 100 且被两处实现共同引用（源码级扫描）
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/balance_data.dart';
import 'package:westeros_life_simulator/data/npc_data.dart';
import 'package:westeros_life_simulator/models/event.dart';
import 'package:westeros_life_simulator/models/player.dart';
import 'package:westeros_life_simulator/providers/game_state_provider.dart';
import 'package:westeros_life_simulator/services/ai_service.dart';
import 'package:westeros_life_simulator/services/event_service.dart';

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

/// 捕获并返回 user prompt（不解 JSON 转义，直接取 requestBody 足够断言）。
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
  expect(start, greaterThanOrEqualTo(0), reason: '关系行缺失');
  final end = body.indexOf('\n', start);
  return body.substring(start, end > start ? end : body.length);
}

void main() {
  group('Batch 10-89 效果键 id 契约（prompt 不再诱导幽灵键）', () {
    test('关系行每条都带真实 id（AI 可直接复制粘贴）', () async {
      final body = await _promptFor(
        Player.defaultPlayer().copyWith(
          relations: const <String, int>{
            'npc_nev': 40,
            'npc_catelyn': 90,
          },
        ),
      );
      final line = _relationLine(body);
      expect(line, contains('[id=npc_nev]'));
      expect(line, contains('[id=npc_catelyn]'));
      // 中文名与关系值形态不变（10-64 契约）
      expect(line, contains('艾德·史塔克'));
      expect(line, contains('凯特琳·史塔克'));
      expect(line, contains(': 40'));
      expect(line, contains(': 90'));
    });

    test('关系行里的 id 与全库真实 NPC id 逐一对应（无杜撰 id）', () async {
      // 取全部 38 个 NPC 建关系，确保预算内至少覆盖前若干位，
      // 逐条验证 prompt 里出现的 [id=...] 都能被 npcById 解析。
      final rels = <String, int>{};
      for (var i = 0; i < allNpcs.length; i++) {
        rels[allNpcs[i].id] = 50 - i;
      }
      final body = await _promptFor(
        Player.defaultPlayer().copyWith(relations: rels),
      );
      final line = _relationLine(body);
      final ids = RegExp(r'\[id=([a-zA-Z0-9_]+)\]')
          .allMatches(line)
          .map((m) => m.group(1)!)
          .toList();
      expect(ids, isNotEmpty, reason: '关系行未标注任何 id');
      for (final id in ids) {
        expect(npcById(id), isNotNull, reason: 'prompt 出现不存在的 NPC id：$id');
      }
      // 预算 8 位 → 恰好 8 个 id 标注
      expect(ids.length, BalanceData.kAiPromptRelationBudget);
    });

    test('效果键约定的关系示例改为真实 id', () async {
      final body = await _promptFor(Player.defaultPlayer());
      expect(body, contains('relations.npc_tyrion'));
      // 旧示例（幽灵键）必须彻底消失
      expect(body, isNot(contains('relations.tyrion')));
    });

    test('效果键约定含「原样复制」硬约束 + 可用键白名单', () async {
      final body = await _promptFor(Player.defaultPlayer());
      expect(body, contains('原样复制，不要自行翻译或简写'));
      // 技能/属性可用键白名单（AI 常凭直觉写错英文键）
      for (final k in const <String>[
        'sword 剑术',
        'archery 弓术',
        'riding 骑术',
        'speech 口才',
        'alchemy 炼金',
        'strength 力量',
        'agility 敏捷',
        'intelligence 智识',
        'charisma 魅力',
        'willpower 意志',
        'perception 感知',
      ]) {
        expect(body, contains(k), reason: '可用键白名单缺：$k');
      }
      // 数值范围约束（与 10-90 的 clamp 对齐）
      expect(body, contains('累计不超过 ±100'));
    });

    test('systemPrompt 同步 id 原样使用约束', () {
      expect(AiService.systemPrompt, contains('原样使用提示词中列出的 id'));
      expect(AiService.systemPrompt, contains('relations.npc_tyrion'));
      expect(AiService.systemPrompt, contains('累计不超过±100'));
    });

    test('回归：既有关系行形态不回归（10-63/64/67/68 契约）', () async {
      // ① 未知 NPC id 回退原格式（不加 [id=] 标注）
      final ghost = await _promptFor(
        Player.defaultPlayer().copyWith(
          relations: const <String, int>{'npc_ghost': 30},
        ),
      );
      final ghostLine = _relationLine(ghost);
      expect(ghostLine, contains('npc_ghost: 30'));
      expect(ghostLine, isNot(contains('（贵族')));

      // ② 关系为空兜底
      final empty = await _promptFor(Player.defaultPlayer());
      expect(_relationLine(empty), contains('（无）'));

      // ③ 秘密字段形态（10-68）
      final withSecret = await _promptFor(
        Player.defaultPlayer().copyWith(
          relations: const <String, int>{'npc_nev': 85},
        ),
      );
      expect(_relationLine(withSecret), contains('秘密：琼恩·雪诺的真实身份'));
    });
  });

  group('Batch 10-90 好感度/技能护栏（provider 侧对齐 event_service）', () {
    test('好感度上界钳制 100', () {
      final provider = GameStateProvider();
      final player = provider.applyEffects(
        provider.player,
        const <String, int>{'relations.npc_tyrion': 9999},
      );
      expect(player.relations['npc_tyrion'], BalanceData.kRelationClamp);
    });

    test('好感度下界钳制 -100', () {
      final provider = GameStateProvider();
      final player = provider.applyEffects(
        provider.player,
        const <String, int>{'relations.npc_tyrion': -9999},
      );
      expect(player.relations['npc_tyrion'], -BalanceData.kRelationClamp);
    });

    test('边内取值不受影响（15 / -5 照常累加）', () {
      final provider = GameStateProvider();
      var player = provider.applyEffects(
        provider.player,
        const <String, int>{'relations.npc_tyrion': 15},
      );
      player = provider.applyEffects(
        player,
        const <String, int>{'relations.npc_tyrion': -5},
      );
      expect(player.relations['npc_tyrion'], 10);
    });

    test('两条通道边界一致（provider 与 event_service 同为 ±100）', () {
      final service = EventService();
      final evRes = service.applyEffects(
        Player.defaultPlayer(),
        const EventChoice(
          id: 'choice_test',
          text: '测试选项',
          requirements: <String, int>{},
          effects: <String, int>{'relations.npc_tyrion': 9999},
          narrative: '',
        ),
      );
      final provider = GameStateProvider();
      final provRes = provider.applyEffects(
        provider.player,
        const <String, int>{'relations.npc_tyrion': 9999},
      );
      expect(
        evRes.newPlayer.relations['npc_tyrion'],
        provRes.relations['npc_tyrion'],
        reason: '两条写入通道的好感度边界不一致',
      );
      expect(evRes.newPlayer.relations['npc_tyrion'], BalanceData.kRelationClamp);
    });

    test('技能/属性防负破底', () {
      final provider = GameStateProvider();
      final player = provider.applyEffects(
        provider.player,
        const <String, int>{'skills.sword': -999, 'attributes.strength': -999},
      );
      expect(player.skills['sword'], 0);
      expect(player.attributes['strength'], 0);
    });

    test('技能/属性正常增减不受影响', () {
      final provider = GameStateProvider();
      final player = provider.applyEffects(
        provider.player,
        const <String, int>{'skills.sword': 2, 'attributes.strength': 1},
      );
      expect(player.skills['sword'], 5); // 默认 3 + 2
      expect(player.attributes['strength'], 6); // 默认 5 + 1
    });

    test('kRelationClamp == 100（与 npcRelationLabel 档位饱和值对齐）', () {
      expect(BalanceData.kRelationClamp, 100);
    });

    test('源码级护栏：两处实现都引用 kRelationClamp（无硬编码 100）', () {
      final providerSrc =
          File('lib/providers/game_state_provider.dart').readAsStringSync();
      final eventSrc =
          File('lib/services/event_service.dart').readAsStringSync();
      // 先剥掉注释再扫：否则会命中 10-90 注释里为了说明历史而引用的
      // 「`.clamp(-100, 100)`」字样（首轮 CI 就被这个自造的假阳性坑红过一次）。
      final codeOnly = RegExp(r'^\s*(//.*)?$').pattern;
      for (final entry in <String, String>{
        'game_state_provider.dart': providerSrc,
        'event_service.dart': eventSrc,
      }.entries) {
        final lines = entry.value.split('\n')
            .where((l) => !RegExp(codeOnly).hasMatch(l))
            .join('\n');
        expect(
          lines.contains('BalanceData.kRelationClamp'),
          isTrue,
          reason: '${entry.key} 未引用 kRelationClamp',
        );
        expect(
          RegExp(r'clamp\(\s*-100,\s*100\s*\)').hasMatch(lines),
          isFalse,
          reason: '${entry.key} 仍有硬编码 clamp(-100, 100)',
        );
      }
    });
  });
}