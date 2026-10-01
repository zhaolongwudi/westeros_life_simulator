/// Batch 10-48 测试：AI prompt 注入头衔晋升趋势（下一档头衔 + 所需声望量化）。
///
/// 覆盖：
/// 1. 有下一档时注入「距下一档「XX」还差 N 声望」+ 阶梯总览
/// 2. 已登顶时注入「已登顶本身份头衔巅峰」+ 阶梯总览
/// 3. 无头衔兜底（暂无头衔）
/// 4. 与 balance_data 单一真相一致（nextTierReputation 对齐）
library;
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/balance_data.dart';
import 'package:westeros_life_simulator/models/event.dart';
import 'package:westeros_life_simulator/models/player.dart';
import 'package:westeros_life_simulator/services/ai_service.dart';

/// 捕获请求 body 的 Dio（与 batch10_43/10_45 同模式）。
(Dio, List<String?>) _captureDio() {
  final captured = <String?>[];
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        captured.add(options.data.toString());
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

Future<void> _call(
  Dio dio,
  Player player, {
  String context = '你在临冬城。',
}) async {
  await AiService(
    apiKey: 'test_key',
    dio: dio,
    baseUrl: 'https://mock.example.com/v1',
  ).generateNarrative(
    player: player,
    context: context,
    availableEvents: const <GameEvent>[],
    season: 'winter',
    currentYear: 283,
    maxRetries: 0,
  );
}

/// 贵族阶梯（40/60/80 → 爵士/伯爵/大领主）。
const _nobleLadder = BalanceData.nobleLadder;

void main() {
  group('Batch 10-48 头衔晋升趋势注入', () {
    test('有下一档时注入「距下一档还差 N 声望」+ 阶梯总览', () async {
      final (dio, captured) = _captureDio();
      // 默认玩家 noble，声望 55 → 当前爵士（≥40），下一档伯爵（60），差 5
      final player = Player.defaultPlayer().copyWith(
        title: '爵士',
        reputation: 55,
      );
      await _call(dio, player);

      expect(captured[0], isNotNull);
      final body = captured[0]!;
      expect(body, contains('头衔晋升：'));
      expect(body, contains('当前头衔 爵士'));
      expect(body, contains('距下一档「伯爵」还差 5 声望'));
      expect(body, contains('阶梯：爵士(40) → 伯爵(60) → 大领主(80)'));
    });

    test('已登顶时注入「已登顶本身份头衔巅峰」', () async {
      final (dio, captured) = _captureDio();
      // 贵族声望 85 → 大领主（≥80）登顶，nextTierReputation=0
      final player = Player.defaultPlayer().copyWith(
        title: '大领主',
        reputation: 85,
      );
      await _call(dio, player);

      expect(captured[0], isNotNull);
      final body = captured[0]!;
      expect(body, contains('已登顶本身份头衔巅峰'));
      expect(body, contains('阶梯：爵士(40) → 伯爵(60) → 大领主(80)'));
      expect(body, isNot(contains('距下一档')));
    });

    test('无头衔兜底（暂无头衔）', () async {
      final (dio, captured) = _captureDio();
      await _call(dio, Player.defaultPlayer());

      expect(captured[0], isNotNull);
      expect(captured[0], contains('头衔晋升：'));
      expect(captured[0], contains('（暂无头衔）'));
    });

    test('与 balance_data 单一真相一致（阶梯名与门槛逐档对齐）', () {
      // 纯函数侧验证：本测试依赖的阶梯数据与 balance_data 完全一致
      final ladder = BalanceData.ladderOf(PlayerIdentity.noble.name);
      expect(ladder.length, _nobleLadder.length);
      for (var i = 0; i < ladder.length; i++) {
        expect(ladder[i].reputation, _nobleLadder[i].reputation);
        expect(ladder[i].title, _nobleLadder[i].title);
      }
      // 55 → 下一档 60；85 → 登顶 0
      expect(BalanceData.nextTierReputation('noble', 55), 60);
      expect(BalanceData.nextTierReputation('noble', 85), 0);
    });
  });
}
