/// Batch 10-98 `flags.` 效果键契约 · prompt 侧同步
///
/// **本批定位**：10-97 给 `flags.` 加了分层白名单守卫，但**只治写侧**。
/// 若不同步 prompt 侧，AI 拿不到合法键清单 → 只能自创 →
/// 10-97 把它们全部拒收 → 回合文本末尾弹「（其中 N 项效果未生效）」
/// → **治理本身变成新的体验故障**（与 10-91 首次加守卫时的同一类问题）。
///
/// **为什么用「规则 + 指路」而不是罗列 26 个键**
/// 首版实现把 26 个静态键逐个写进 prompt（约 700 字符固定开销），
/// **自查时撤回**：项目方向自 10-81 起是「减 token」（见 HANDOVER 第七节），
/// 而 prompt 固定骨架已是单次请求最大头（10-86 实测 1846 字符 / 36%）。
/// 为契约说明再加 700 字符固定开销是净负收益。
/// 改用两条规则代替罗列：
///  1. **可用键仅限上文「状态」段已列出的键名** —— 该段由
///     `_flagDesc`（10-88）从 `player.flags` 真实值生成，AI 直接照抄，
///     零额外 token（本来就注入的那段），且天然与玩家真实状态同步；
///  2. **5 个动态前缀显式点名** —— 这几个是内容数据里的真实键形态
///     （`equipped.item_sword` / `house.childDead.罗柏` 等），
///     状态段里通常**看不到**（玩家还没触发过），必须显式告知。
/// 净增约 150 字符，落在原句内联，不新增段落。
///
/// **同步契约的双向性**：白名单加键 / 加前缀时，本测试会红，
/// 强制同时更新 prompt 文案，避免「守卫认但 prompt 不教」的两套真相。
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/balance_data.dart';
import 'package:westeros_life_simulator/models/player.dart';
import 'package:westeros_life_simulator/services/ai_service.dart';

/// 抓取 `_buildPrompt` 产出的 user prompt 正文。
///
/// 用 200 假响应而非 reject（沿用 `batch10_5_ai_prompt_test` 的既有模板），
/// 避免撞上 `generateNarrative` 的重试/降级分支影响断言稳定性。
Future<String> _promptFor(Player player) async {
  var captured = '';
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final messages = options.data['messages'] as List<dynamic>;
        final userMsg = messages.last as Map<String, dynamic>;
        captured = userMsg['content'] as String;
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
  final service = AiService(
    apiKey: 'k',
    dio: dio,
    baseUrl: 'https://mock.example.com/v1',
  );
  await service.generateNarrative(
    player: player,
    context: '测试',
    availableEvents: const [],
    maxRetries: 0,
  );
  return captured;
}

void main() {
  // 两个 group 共用同一份 prompt 正文，只抓一次。
  late String body;
  setUpAll(() async {
    body = await _promptFor(Player.defaultPlayer().copyWith(
      flags: <String, bool>{
        ...Player.defaultPlayer().flags,
        'honor_pledge': true,
      },
    ));
  });

  group('10-98 prompt 告知 flags 键契约', () {
    test('flags 效果键约定行仍在（既有契约不回归）', () {
      expect(body, contains('flags.标记名'));
      expect(body, contains('flags.honor_pledge'));
    });

    test('约定行指向「状态」段取键（不另列 26 个键）', () {
      expect(body, contains('上文「状态」段已列出的键名'),
          reason: 'AI 必须知道合法键从哪来，否则会自创');
    });

    test('动态前缀表与 BalanceData 零漂移（增删前缀须同步文案）', () {
      // 白名单加了第 6 个前缀而没改 prompt，AI 写该前缀就会被 10-97 拒收。
      // 这里锁住「prompt 点名的前缀数 == 白名单前缀数」。
      for (final p in BalanceData.kPlayerFlagPrefixes) {
        expect(body, contains(p));
      }
      // 反向：文案里硬编码的 5 个前缀名不得多于白名单
      const known = [
        'equipped.',
        'house.childDead.',
        'npc_task.',
        'npc_task_done.',
        'npc_story.',
      ];
      expect(known.length, BalanceData.kPlayerFlagPrefixes.length);
    });

    test('house.childExiled. 不出现在 prompt（刻意不开的预留前缀）', () {
      expect(body, isNot(contains('childExiled')),
          reason: '放行等于让 AI 有能力把家谱继承人从候选中剔除');
    });

    test('明说「不要自创」，避免 AI 造出必被拒的键', () {
      expect(body, contains('不要自创'));
    });

    test('状态段确实注入了真实标记键（指路成立的前提）', () {
      expect(body, contains('honor_pledge'),
          reason: '约定行让 AI 去「状态」段找键，那段必须有内容');
    });
  });

  group('10-98 与 10-97 守卫的一致性', () {
    test('prompt 点名的前缀全部能通过 10-97 判定（闭环）', () {
      for (final p in BalanceData.kPlayerFlagPrefixes) {
        expect(BalanceData.isPlayerFlagKeyValid('${p}X'), isTrue,
            reason: 'prompt 教了 $p 但守卫会拒 → AI 写了必被丢');
      }
    });

    test('prompt 里出现的每个 flags.<键> 示例都能通过守卫', () {
      // 正则扫出正文里所有 `flags.` 后的键名（跳过 `flags.标记名` 这类
      // 中文占位符——它不是真实键而是格式说明），逐个喂给守卫。
      // 这是「prompt 不教幽灵键」的**实证**断言，而非白名单自查。
      final taught = RegExp(r'flags\.([A-Za-z_][A-Za-z0-9_]*)')
          .allMatches(body)
          .map((m) => m.group(1)!)
          .toSet();
      expect(taught, isNotEmpty, reason: '前提：prompt 至少含一个 flags 示例键');
      final ghost = taught
          .where((k) => !BalanceData.isPlayerFlagKeyValid(k))
          .toList();
      expect(ghost, isEmpty,
          reason: 'prompt 教了会被 10-97 拒收的键 $ghost —— AI 照抄必被丢');
    });

    test('prompt 举的示例键 honor_pledge 能通过 10-97 判定', () {
      expect(BalanceData.isPlayerFlagKeyValid('honor_pledge'), isTrue);
      expect(body, contains('flags.honor_pledge'));
    });
  });
}