/// Batch 10-86 测试：AI prompt 全量 token 基线护栏。
///
/// 【为什么需要】Batch 10-81~85 逐段预算化后，缺少**整体**约束——任何未来
/// 改动（新增注入项 / 放宽某个预算 / 加长文案）都可能让 prompt 悄悄膨胀回去。
/// 本文件把「单次请求的总长度」变成显式契约，任何超预算的改动直接 CI 红。
///
/// 【基线来源（真实取证，非估算）】默认玩家（`Player.defaultPlayer()`：
/// noble 身份 / 临冬城 / winter / family_stark / 无关系无任务）单次请求的
/// 分段实测。取证实测分两轮：
///
///   第一轮（一次性 Python 脚本按 `ai_service.dart` 模板逐段复现拼接）估算
///   4877 字符，其中固定骨架 1355 + systemPrompt 491 占大头。
///
///   第二轮（CI 实测，见 run `37205470965` 的 `[10-86]` 打印）校正为：
///     user prompt 总长            3664 字符
///     在场 NPC 段（10-82+10-85 双预算）  671
///     关系段（10-83 预算 8 位，38 人场景） 265
///     可用事件块（10-33 预算 12 条）      ≈ 500
///
///   两轮差异来自脚本对静态模板分支长度的高估（真实命中分支比脚本解析的短）。
///   **护栏阈值以 CI 实测为准**，脚本估算仅用于定位大头的相对排序。
///
/// 【阈值取法】上界 5900 / 下界 2500：
///   - 上界要**高于** CI 实测（3664），留 60% 余量容纳文案正常增长；
///   - 上界要**明显低于**预算失效后的规模（实测基线 3664 基础上，关系段
///     从 8 位放回 38 位 +1178、在场 NPC 从 5 位放回 8 位且模板全量 +479、
///     事件从 12 条放回 72 条 +2000，合计 ≈ 7300），否则护栏形同虚设；
///   - 下界防「误删整段注入」静默通过（删「可用事件」或「在场 NPC」必跌破）。
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

/// user prompt 基线上界（字符）。
///
/// = CI 实测 3664 留约 60% 余量。预算全部失效时的规模参考（说明本上界
/// 仍有区分力）：关系段 38 位（1 处）+1178、在场 NPC 8 位且模板全量 +479、
/// 事件全量 72 条 +2000 → 合计 ≈ 7300 字符，远超 5900。
/// S2-4：技能键清单由 5 键扩到 13 键（prompt 里白名单放行的键要列全，
/// 否则 AI 永远用不到另外 8 个键），prompt 实测 3664 → 约 3725，
/// 上界同步 5900 → 6000（仍远低于预算失效后的 ≈7300，护栏区分力不变）。
const int kMaxPromptChars = 6000;

/// user prompt 下界（字符）。防止「误删整段注入」静默通过。
///
/// 取 CI 实测 3664 的 70%（≈ 2500），留足波动空间：正常文案微调或
/// 小段重构不会跌破，但删掉一两个段落（如「可用事件」或「在场 NPC」）
/// 一定会跌破。
const int kMinPromptChars = 2500;

/// 关系段单独上界（字符）。10-83 预算 8 位实测 ≈ 265，留 88% 余量。
const int kMaxRelationChars = 500;

/// 在场 NPC 段单独上界（字符）。10-82 + 10-85 双预算后实测 ≈ 671。
const int kMaxOnSiteNpcChars = 1000;

/// 可用事件段单独上界（字符）。10-33 预算 12 条实测 ≈ 500。
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
///
/// 只适用于**单行**段落（如 `- 在场 NPC：…`）。多行块（如 `可用事件：`
/// 后面跟着 12 行事件）必须用 [_block]——用本函数量多行块会只量到首行，
/// 断言形同虚设（10-86 首版就踩了这个坑，实测「可用事件段 = 5 字符」）。
String _line(String body, String anchor) {
  final start = body.indexOf(anchor);
  if (start < 0) return '';
  final end = body.indexOf('\n', start);
  return end > start ? body.substring(start, end) : body.substring(start);
}

/// 提取从 [anchor] 到下一个 [nextAnchor] 之前的整块内容（多行段落用）。
///
/// 若 [nextAnchor] 不存在，取到字符串末尾。
String _block(String body, String anchor, String nextAnchor) {
  final start = body.indexOf(anchor);
  if (start < 0) return '';
  final end = body.indexOf(nextAnchor, start + anchor.length);
  if (end < 0) return body.substring(start);
  return body.substring(start, end);
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
      // 事件段是多行块（12 行事件 + 「- 与你相关的可用事件」行），
      // 必须用 _block 量整块，不能用 _line（只量到首行 = 5 字符）。
      final eventsSeg = _block(user, '可用事件：', '叙事引导（身份）：');
      // ignore: avoid_print
      print('[10-86] 可用事件块 = ${eventsSeg.length} 字符（上界 $kMaxEventsChars）');
      expect(eventsSeg.length, lessThanOrEqualTo(kMaxEventsChars));
      // 事件行以 '- ' 开头，条数即行数；断言恰为预算值
      final eventLines = eventsSeg
          .split('\n')
          .where((l) => l.startsWith('- ') && l.contains('（对你而言：'))
          .length;
      // ignore: avoid_print
      print('[10-86] 事件条数 = $eventLines（预算 ${BalanceData.kAiPromptEventBudget}）');
      expect(eventLines, BalanceData.kAiPromptEventBudget);
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
        '可用事件': _block(user, '可用事件：', '叙事引导（身份）：').length,
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