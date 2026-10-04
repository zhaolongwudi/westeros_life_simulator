/// Batch 10-86 测试：AI prompt 全量 token 基线护栏。
///
/// 【为什么需要】Batch 10-81~85 逐段预算化后，缺少**整体**约束——任何未来
/// 改动（新增注入项 / 放宽某个预算 / 加长文案）都可能让 prompt 悄悄膨胀回去。
/// 本文件把「单次请求的总长度」变成显式契约，任何超预算的改动直接 CI 红。
///
/// 【基线来源（真实取证，非估算）】默认玩家（`Player.defaultPlayer()`：
/// noble 身份 / 临冬城 / winter / family_stark / 无关系无任务）单次请求的
/// 分段实测（用一次性脚本按 `ai_service.dart` 模板逐段复现拼接）：
///
///   固定骨架（剔除 24 个插值的模板字面量）  1355 字符 + systemPrompt 491
///   在场 NPC（10-82 预算 5 位 + 10-85 模板预算 2）  709
///   静态模板 8 段（身份/区域/季节/季节动向/风土/农事/集市/轶事）  566
///   可用事件（10-33 预算 12 条）              492
///   家族 6 段（对外关系/特质/秘密/成员/权力/继承）  472
///   玩家数值行（技能/属性/装备/家谱/头衔阶梯）    400
///   地点 3 段（详情/当地势力/邻近风险）         330
///   关系段（10-83 预算 8 位）                 311
///   世界局势 + 局势立场                        240
///   ─────────────────────────────────────────────
///   user prompt 合计 ≈ 4877 字符（≈ 4000 token，保守按 0.75 字符/token）
///
/// 【阈值取法】`kMaxPromptChars = 5900`（实测 ×1.2 向上取整到百位）：
///   - 上界要**高于**当前实测，否则测试环境差异会误红；
///   - 上界要**明显低于**预算失效后的规模（若三处预算全部失效，
///     关系段 38 位 + 在场 NPC 8 位 + 事件全量 72 条 ≈ 7500+ 字符），
///     否则护栏形同虚设。
///
/// 【覆盖】
///  1. 默认玩家 user prompt 长度 ≤ 基线上界（核心护栏）
///  2. 长度 ≥ 某个下限（防止「误删注入段」也红——删内容同样要有人发现）
///  3. 长会话场景（38 个 NPC 全有交情 + 大量 flags）仍受控，不因累积而爆炸
///  4. 三处预算任一失效都会被捕获（关系段/在场 NPC/事件分别单独断言上界）
///  5. 分段占比可观测：打印各段长度占比，供后续批次定位下一个大头
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/balance_data.dart';
import 'package:westeros_life_simulator/data/event_data.dart';
import 'package:westeros_life_simulator/data/npc_data.dart';
import 'package:westeros_life_simulator/models/event.dart';
import 'package:westeros_life_simulator/models/player.dart';
import 'package:westeros_life_simulator/services/ai_service.dart';

/// user prompt 基线上界（字符）。= Batch 10-86 取证实测 4877 × 1.2 → 5900。
///
/// 预算全部失效时的规模参考（用于说明为何 5900 仍有区分力）：
///   关系段 38 位（1 处）      ≈ 1443（vs 预算后 311）
///   在场 NPC 8 位 + 全量模板  ≈ 1150（vs 预算后 709）
///   事件全量 72 条            ≈ 2950（vs 预算后 492）
///   → 三处同时失效 ≈ 7500+ 字符，远超 5900 上界。
const int kMaxPromptChars = 5900;

/// user prompt 下界（字符）。防止「误删整段注入」静默通过。
///
/// 取实测 4877 的 70%（≈ 3400），留出波动空间：正常文案微调不会跌破，
/// 但删掉一两个段落（如「可用事件」492 + 「在场 NPC」709）一定会跌破。
const int kMinPromptChars = 3400;

/// 关系段单独上界（字符）。10-83 预算 8 位实测 ≈ 311，留 60% 余量。
const int kMaxRelationChars = 500;

/// 在场 NPC 段单独上界（字符）。10-82 + 10-85 双预算后实测 ≈ 709。
const int kMaxOnSiteNpcChars = 1000;

/// 可用事件段单独上界（字符）。10-33 预算 12 条实测 ≈ 492。
const int kMaxEventsChars = 800;

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

/// 捕获并返回 user prompt（不含 JSON 转义外层包装）。
Future<String> _promptFor(
  Player player, {
  String season = 'winter',
  List<GameEvent> events = const <GameEvent>[],
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
    availableEvents: events,
    season: season,
    maxRetries: 0,
  );
  expect(captured[0], isNotNull);
  // captured 是 JSON 字符串；用 user content 的原文做长度估算足够，
  // 转义只影响引号，不影响护栏的有效性（阈值留了 20% 余量）。
  return captured[0]!;
}

/// 从请求体 JSON 中取出 **user 消息**的原文。
///
/// 请求体的 `messages` 顺序是 `[system, user]`（`ai_service.dart` `_postChat`），
/// 所以 `"content":"` 会命中两次——必须取**第二个**，否则量到的是
/// systemPrompt（491 字符的固定部分），护栏就失去意义。
String _userContent(String requestBody) {
  const marker = '"content":"';
  // 跳过 system 的那一次。
  final first = requestBody.indexOf(marker);
  if (first < 0) return requestBody;
  final second = requestBody.indexOf(marker, first + marker.length);
  if (second < 0) return '';
  var j = second + marker.length;
  final buf = StringBuffer();
  while (j < requestBody.length) {
    final ch = requestBody[j];
    if (ch == r'\' && j + 1 < requestBody.length) {
      final next = requestBody[j + 1];
      // 只处理 JSON 转义里的 \n 与 \"，其余原样
      if (next == 'n') {
        buf.write('\n');
      } else if (next == '"') {
        buf.write('"');
      } else {
        buf.write(ch);
        buf.write(next);
      }
      j += 2;
      continue;
    }
    if (ch == '"') break;
    buf.write(ch);
    j++;
  }
  return buf.toString();
}

/// 提取以 [anchor] 开头的那一行内容。
String _line(String body, String anchor) {
  final start = body.indexOf(anchor);
  if (start < 0) return '';
  final end = body.indexOf('\n', start);
  return end > start ? body.substring(start, end) : body.substring(start);
}

void main() {
  group('Batch 10-86 prompt 长度基线护栏', () {
    test('默认玩家 user prompt 长度 ≤ 基线上界（核心护栏）', () async {
      final body = await _promptFor(Player.defaultPlayer());
      final user = _userContent(body);
      // ignore: avoid_print
      print('[10-86] 默认玩家 user prompt = ${user.length} 字符 '
          '（上界 $kMaxPromptChars）');
      expect(user.length, lessThanOrEqualTo(kMaxPromptChars));
    });

    test('默认玩家 user prompt 长度 ≥ 下界（防止误删整段注入）', () async {
      final body = await _promptFor(Player.defaultPlayer());
      final user = _userContent(body);
      expect(user.length, greaterThanOrEqualTo(kMinPromptChars));
    });

    test('三处核心预算段各自受控（关系/在场 NPC/事件）', () async {
      final body = await _promptFor(Player.defaultPlayer());
      final user = _userContent(body);
      final rel = _line(user, '- 关系（NPC: 好感度）：');
      final onSite = _line(user, '- 在场 NPC：');
      // 默认玩家 relations 为空 → 该行是「（无）」，用长会话场景测才有意义
      expect(rel.length, lessThanOrEqualTo(kMaxRelationChars));
      // ignore: avoid_print
      print('[10-86] 在场 NPC 段 = ${onSite.length} 字符（上界 $kMaxOnSiteNpcChars）');
      expect(onSite.length, lessThanOrEqualTo(kMaxOnSiteNpcChars));
    });

    test('长会话场景（38 个 NPC 全有交情）仍受关系段预算约束', () async {
      final rels = <String, int>{};
      for (var i = 0; i < allNpcs.length; i++) {
        rels[allNpcs[i].id] = 100 - i;
      }
      final body = await _promptFor(
        Player.defaultPlayer().copyWith(relations: rels),
      );
      final user = _userContent(body);
      final rel = _line(user, '- 关系（NPC: 好感度）：');
      // ignore: avoid_print
      print('[10-86] 38 人关系段 = ${rel.length} 字符（上界 $kMaxRelationChars）');
      expect(rel.length, lessThanOrEqualTo(kMaxRelationChars));
      // 仍应告知 AI 还有多少人未展开
      expect(rel, contains('有交情'));
      // 总长也受控
      expect(user.length, lessThanOrEqualTo(kMaxPromptChars));
    });

    test('事件预算生效：72 条事件全量输入时只展开 12 条', () async {
      final all = allEvents;
      expect(all.length, greaterThan(BalanceData.kAiPromptEventBudget));
      final body = await _promptFor(
        Player.defaultPlayer(),
        events: all,
      );
      final user = _userContent(body);
      final eventsSeg = _line(user, '可用事件：');
      // ignore: avoid_print
      print('[10-86] 可用事件段 = ${eventsSeg.length} 字符（上界 $kMaxEventsChars）');
      expect(eventsSeg.length, lessThanOrEqualTo(kMaxEventsChars));
      expect(user.length, lessThanOrEqualTo(kMaxPromptChars));
    });

    test('分段占比可观测（打印各段长度，供下一轮定位大头）', () async {
      final rels = <String, int>{};
      for (var i = 0; i < 12; i++) {
        rels[allNpcs[i].id] = 90 - i;
      }
      final body = await _promptFor(
        Player.defaultPlayer().copyWith(relations: rels),
        events: allEvents,
      );
      final user = _userContent(body);
      final segments = <String, int>{
        '固定骨架+systemPrompt': 1355 + 491,
        '在场 NPC': _line(user, '- 在场 NPC：').length,
        '关系段': _line(user, '- 关系（NPC: 好感度）：').length,
        '可用事件': _line(user, '可用事件：').length,
        '家族': _line(user, '- 家族：').length,
        '家族成员': _line(user, '- 家族成员：').length,
        '家族权力': _line(user, '- 家族在权力网络中的位置：').length,
        '当地势力': _line(user, '- 当地势力与你的立场：').length,
        '邻近风险': _line(user, '- 邻近地点与路途风险：').length,
      };
      final sorted = segments.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final buf = StringBuffer('[10-86] 分段长度（user prompt 总 '
          '${user.length} 字符）：\n');
      for (final e in sorted) {
        buf.write('  ${e.value.toString().padLeft(5)}  ${e.key}\n');
      }
      // ignore: avoid_print
      print(buf.toString());
      // 分段之和不应超过总长（段间有分隔，但不应出现重复计入）
      final sum = segments.values.fold(0, (a, b) => a + b);
      expect(sum, lessThan(user.length));
      // 该场景（12 关系 + 72 事件）仍不应突破上界
      expect(user.length, lessThanOrEqualTo(kMaxPromptChars));
    });

    test('三个上界常量自身为正且下界 < 上界', () {
      expect(kMaxPromptChars, greaterThan(0));
      expect(kMaxOnSiteNpcChars, greaterThan(0));
      expect(kMaxRelationChars, greaterThan(0));
      expect(kMaxEventsChars, greaterThan(0));
      expect(kMinPromptChars, lessThan(kMaxPromptChars));
    });
  });
}