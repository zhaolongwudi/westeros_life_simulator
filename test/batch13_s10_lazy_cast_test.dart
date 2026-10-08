/// Sprint 13-10 测试：修 P1 ⑬「AI 解析 `.cast<String,int>()` 惰性 ⇒ 异常逃出 try/catch」。
///
/// 【本批修的是什么】`_parseResponse`（`ai_service.dart:1348`）在 try 块里写
/// `(c['effects'] as Map? ?? {}).cast<String, int>()`——`Map.cast` 返回的是
/// **惰性视图**，构造时不校验元素类型，只有**读取时**才抛 `TypeError`。
/// 于是：模型输出浮点/字符串效果值（prompt 只给整数示例，未约束）时，
/// `_parseResponse` 正常返回 `isSuccess: true`，毒化的 `EventChoice` 流到
/// `effectLabels` 迭代 `.entries`（`narrative.dart:240`）或 `applyEffects`
/// 才炸——**异常逃出了 try/catch**，玩家看到的是崩溃而非降级。
///
/// 【修法】改为 `Map<String, int>.from(...)` 的即时转换：元素非法时
/// 在 try 块内立刻抛 ⇒ 落回既有 catch ⇒ 返回 `choices` 为空的降级结果。
///
/// 【判别式】必须断言「不抛 + 降级」，只断言「不抛」会假绿
/// （缺陷下构造期也不抛，是**后续读取**才抛）。
///
/// ⚠️ 本机（Android/DSH）无 dart/flutter，**本文件未在本地执行**，正确性由 CI 验证。
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/models/event.dart';
import 'package:westeros_life_simulator/models/player.dart';
import 'package:westeros_life_simulator/services/ai_service.dart';
import 'package:westeros_life_simulator/utils/narrative_format.dart';

/// 用 Dio 拦截器把 `chat/completions` 固定应答为 [content]。
///
/// 照抄 `batch9_ai_deep_test.dart:169-207` 的既有套路（本仓库无 mockito）。
AiService _serviceReturning(String content) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            statusCode: 200,
            data: <String, dynamic>{
              'choices': <dynamic>[
                <String, dynamic>{
                  'message': <String, dynamic>{'content': content},
                },
              ],
            },
          ),
        );
      },
    ),
  );
  return AiService(
    apiKey: 'test_key',
    dio: dio,
    baseUrl: 'https://mock.example.com/v1',
  );
}

Future<AiResponse> _parse(String content) {
  return _serviceReturning(content).generateNarrative(
    player: Player.defaultPlayer(),
    context: '测试',
    availableEvents: const <GameEvent>[],
    maxRetries: 0,
  );
}

void main() {
  group('S13-10 非法效果值必须落回 catch（而非毒化对象）', () {
    test('浮点效果值：不抛，且降级为无选项', () async {
      final r = await _parse(
        '{"narrative":"商队来了","choices":[{"text":"交易",'
        '"effects":{"gold":10.0},"narrative":"成交"}]}',
      );
      expect(r.isSuccess, isTrue, reason: '叙事仍可用，属降级而非失败');
      expect(r.choices, isEmpty,
          reason: '非法效果值必须在 try 内被拦下 ⇒ 返回空选项（缺陷下返回毒化选项）');
      expect(r.narrative, isNotEmpty, reason: '叙事内容应保留给玩家');
    });

    test('字符串效果值：同样降级', () async {
      final r = await _parse(
        '{"narrative":"风声","choices":[{"text":"听",'
        '"effects":{"gold":"很多"},"narrative":"听到了"}]}',
      );
      expect(r.choices, isEmpty);
    });

    test('整数值正常解析（未误伤合法路径）', () async {
      final r = await _parse(
        '{"narrative":"商队来了","choices":[{"text":"交易",'
        '"effects":{"gold":10,"reputation":-2},"narrative":"成交"}]}',
      );
      expect(r.choices, hasLength(1));
      expect(r.choices.first.effects['gold'], 10);
      expect(r.choices.first.effects['reputation'], -2);
    });

    test('毒化选项不得流到 effectLabels（消费方不再可能踩雷）', () async {
      final r = await _parse(
        '{"narrative":"x","choices":[{"text":"y",'
        '"effects":{"gold":1.5},"narrative":"z"}]}',
      );
      // 缺陷下 choices 非空且 effects 是惰性视图，这一行会抛 TypeError
      for (final c in r.choices) {
        expect(() => effectLabels(c.effects), returnsNormally);
      }
    });
  });
}
