/// Batch 10-87/88 测试：AI prompt 背包段与状态段 token 预算化。
///
/// 【为什么需要】10-81~86 已把注入轴逐段预算化，但取证发现**背包段与状态段
/// 是剩余的两处无界累积段**（一次性脚本实证，非印象估计）：
///
/// 1. **背包段**（10-87）：`_buildPrompt` 原先直接插
///    `player.inventory.join('、')`，输出**裸英文物品 id 且逐件重复**
///    —— 持有 12 个黑面包就写 12 遍 `item_bread`。而背包**没有上限**：
///    `mixin_life.addItem` 注释明写「背包无上限，恒成功」，且
///    `event_service.applyEffects` 的 `inventory.<id>` 分支**不校验 id**，
///    AI 选项可写入任意未知 id → 随回合数无界增长。
/// 2. **状态段**（10-88）：原先把 flags 里所有 true 的键无上限拼成一行。
///    同样两条无界通道：`applyEffects` 的 `flags.<名>` 不校验键名、
///    `advanceGeneration` 每代写 `house.childDead.<继承人名>` 只增不删。
///
/// 【改动】
/// - 10-87：背包段抽为 `_inventoryDesc` 纯函数——按物品聚合计数、
///   走 `itemName` 取中文名（未知 id 回退原 id），输出「黑面包 ×3、长剑 ×1」；
///   最多 `BalanceData.kAiPromptInventoryEntryCount`（8）种，
///   超出附「（另有 N 种物品未列）」尾注。
/// - 10-88：状态段抽为 `_flagDesc` 纯函数——按 map 插入序取前
///   `BalanceData.kAiPromptFlagBudget`（8）项，超出附「（另有 N 项未列）」尾注。
///
/// 【零回归依据】grep 实证：全库**无任何测试**断言「背包：」行内容
/// （仅 `batch10_63_64` 断言 `contains('背包：')` 前缀存在，形态不变）
/// 或「- 状态：」行内容；`- 已装备：` 行的既有断言
/// （`batch10_43` 断言「长剑（武器，价值 40）」）不受本批影响——装备段独立。
library;

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

/// 捕获并返回完整请求体 JSON 字符串。
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

/// 提取以 [anchor] 开头的单行内容（这两段都是单行）。
String _line(String body, String anchor) {
  final start = body.indexOf(anchor);
  expect(start, greaterThanOrEqualTo(0), reason: '未找到锚点 $anchor');
  final end = body.indexOf('\n', start);
  return end > start ? body.substring(start, end) : body.substring(start);
}

void main() {
  group('Batch 10-87 背包段聚合去重 + 中文名 + 条目预算', () {
    test('空背包 → 兜底「（空）」', () async {
      final line = _line(await _promptFor(Player.defaultPlayer()), '- 背包：');
      expect(line, contains('背包：（空）'));
    });

    test('持有 3 个黑面包 + 长剑 → 聚合计数 + 中文名（不逐件重复）', () async {
      final line = _line(
        await _promptFor(
          Player.defaultPlayer().copyWith(
            inventory: const ['item_bread', 'item_bread', 'item_bread', 'item_sword'],
          ),
        ),
        '- 背包：',
      );
      // 中文名 + 数量聚合，英文 id 不再泄漏
      expect(line, contains('黑面包 ×3'));
      expect(line, contains('长剑 ×1'));
      expect(line, isNot(contains('item_bread')));
      expect(line, isNot(contains('item_sword')));
    });

    test('同种物品不再逐件重复（3 件 = 1 条而非 3 条）', () async {
      final line = _line(
        await _promptFor(
          Player.defaultPlayer().copyWith(
            inventory: List<String>.filled(12, 'item_bread'),
          ),
        ),
        '- 背包：',
      );
      // 聚合后只有 1 个条目
      expect('黑面包'.allMatches(line).length, 1);
      expect(line, contains('黑面包 ×12'));
      // 12 次逐件罗列约 132 字符，聚合后 8 字符
      // ignore: avoid_print
      print('[10-87] 12 件黑面包背包段 = ${line.length} 字符');
    });

    test('超过预算种数 → 截断到 8 种 + 「另有 N 种物品未列」尾注', () async {
      // 12 种不同物品（均取自内容管道 33 种真实 id 前缀命名以外的
      // 未知 id 亦可——未知 id 回退原 id 正是本批的兜底策略）
      final inv = <String>[
        'item_a', 'item_b', 'item_c', 'item_d',
        'item_e', 'item_f', 'item_g', 'item_h',
        'item_i', 'item_j', 'item_k', 'item_l',
      ];
      final line = _line(
        await _promptFor(Player.defaultPlayer().copyWith(inventory: inv)),
        '- 背包：',
      );
      // 截断尾注存在，且隐藏数 = 12 - 8 = 4
      expect(line, contains('另有 4 种物品未列'));
      // 第 8 种（item_h，仍在预算内）出现，第 9 种（item_i）不出现
      expect(line, contains('item_h'));
      expect(line, isNot(contains('item_i')));
      // ignore: avoid_print
      print('[10-87] 12 种物品背包段 = ${line.length} 字符（预算 ${BalanceData.kAiPromptInventoryEntryCount} 种）');
      expect(line.length, lessThan(200));
    });

    test('未知物品 id 回退原 id（不抛异常、不泄漏空串）', () async {
      final line = _line(
        await _promptFor(
          Player.defaultPlayer().copyWith(inventory: const ['unknown_thing']),
        ),
        '- 背包：',
      );
      expect(line, contains('unknown_thing ×1'));
    });
  });

  group('Batch 10-88 状态段条目预算', () {
    test('默认玩家 → isAlive 单项，无尾注', () async {
      final line = _line(await _promptFor(Player.defaultPlayer()), '- 状态：');
      expect(line, contains('状态：isAlive'));
      expect(line, isNot(contains('未列')));
    });

    test('全 false → 兜底「（无特殊状态）」', () async {
      final line = _line(
        await _promptFor(
          Player.defaultPlayer().copyWith(flags: const {'a': false, 'b': false}),
        ),
        '- 状态：',
      );
      expect(line, contains('状态：（无特殊状态）'));
    });

    test('超过预算项数 → 截断到 8 项 + 「另有 N 项未列」尾注', () async {
      final flags = <String, bool>{
        for (var i = 0; i < 14; i++) 'f$i': true,
      };
      final line = _line(
        await _promptFor(Player.defaultPlayer().copyWith(flags: flags)),
        '- 状态：',
      );
      // 隐藏数 = 14 - 8 = 6
      expect(line, contains('另有 6 项未列'));
      // 前 8 项按插入序出现
      expect(line, contains('f0、f1'));
      // 第 9 项（f8）不出现
      expect(line, isNot(contains('f8')));
      // ignore: avoid_print
      print('[10-88] 14 项状态段 = ${line.length} 字符（预算 ${BalanceData.kAiPromptFlagBudget} 项）');
      expect(line.length, lessThan(160));
    });

    test('装备 flags（equipped.*）走装备段不受状态段预算影响', () async {
      final line = _line(
        await _promptFor(
          Player.defaultPlayer().copyWith(
            flags: <String, bool>{
              ...Player.defaultPlayer().flags,
              'equipped.item_sword': true,
              'equipped.item_chainmail': true,
            },
          ),
        ),
        '- 已装备：',
      );
      // 装备段既有契约（batch10_43）保持不变
      expect(line, contains('长剑（武器，价值 40）'));
      expect(line, contains('锁子甲（护甲，价值 90）'));
    });

    test('两个预算常量自身为正且在合理量级', () {
      expect(BalanceData.kAiPromptInventoryEntryCount, greaterThan(0));
      expect(BalanceData.kAiPromptFlagBudget, greaterThan(0));
      // 与在场 NPC 预算（5）同量级，不应小到失去意义
      expect(BalanceData.kAiPromptInventoryEntryCount,
          greaterThanOrEqualTo(BalanceData.kAiPromptOnSiteNpcBudget));
      expect(BalanceData.kAiPromptFlagBudget,
          greaterThanOrEqualTo(BalanceData.kAiPromptOnSiteNpcBudget));
    });

    test('既有注入不回归（背包/状态/装备前缀均存在）', () async {
      final body = await _promptFor(Player.defaultPlayer());
      expect(body, contains('- 背包：'));
      expect(body, contains('- 状态：'));
      expect(body, contains('- 已装备：'));
    });
  });
}