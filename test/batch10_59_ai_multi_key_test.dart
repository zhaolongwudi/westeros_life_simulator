/// Batch 10-59 测试：AI 多 Key 轮换 + 多模型选择 + 配置兼容。
///
/// 覆盖：
/// 1. 多 key 轮换：首 key 429 → 自动换第二个 key 成功
/// 2. 全部 key 失败 → 返回最后一次错误
/// 3. 单 key 向后兼容（旧 apiKey 入参）
/// 4. provider 预设（sensenova/atria/deepseek 默认模型与 baseUrl）
/// 5. AiConfig 多 key 持久化往返 + 旧单 key 迁移兼容
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:westeros_life_simulator/data/ai_provider_defaults.dart';
import 'package:westeros_life_simulator/models/event.dart';
import 'package:westeros_life_simulator/models/player.dart';
import 'package:westeros_life_simulator/services/ai_config.dart';
import 'package:westeros_life_simulator/services/ai_service.dart';

/// 构造一个拦截请求、按请求头 Authorization 的 key 分发结果的 mock Dio。
///
/// [failKeys]：这些 key 返回 429（触发轮换）；其余返回成功。
(Dio, List<String>) _captureDio(Set<String> failKeys) {
  final usedKeys = <String>[];
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final auth = options.headers['Authorization'] as String? ?? '';
        final key = auth.replaceFirst('Bearer ', '');
        usedKeys.add(key);
        if (failKeys.contains(key)) {
          handler.reject(
            DioException(
              requestOptions: options,
              response: Response<dynamic>(
                requestOptions: options,
                statusCode: 429,
                data: <String, dynamic>{'error': 'rate limited'},
              ),
            ),
          );
          return;
        }
        handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            statusCode: 200,
            data: <String, dynamic>{
              'choices': <dynamic>[
                <String, dynamic>{
                  'message': <String, dynamic>{
                    'content': '{"narrative":"成功叙事","choices":[]}',
                  },
                },
              ],
            },
          ),
        );
      },
    ),
  );
  return (dio, usedKeys);
}

Future<AiResponse> _run(
  Dio dio,
  List<String> keys, {
  int maxRetries = 0,
}) async {
  final service = AiService(
    apiKeys: keys,
    dio: dio,
    baseUrl: 'https://mock.example.com/v1',
  );
  return service.generateNarrative(
    player: Player.defaultPlayer(),
    context: '测试',
    availableEvents: const <GameEvent>[],
    maxRetries: maxRetries,
  );
}

void main() {
  group('Batch 10-59 多 Key 轮换', () {
    test('首 key 429 自动换第二个 key 成功', () async {
      final (dio, usedKeys) = _captureDio(<String>{'key_a'});
      final response = await _run(dio, <String>['key_a', 'key_b']);
      expect(response.isSuccess, isTrue);
      expect(response.narrative, contains('成功叙事'));
      // key_a 被尝试（429）→ key_b 成功
      expect(usedKeys, <String>['key_a', 'key_b']);
    });

    test('全部 key 失败返回最后一次错误', () async {
      final (dio, usedKeys) = _captureDio(<String>{'key_a', 'key_b'});
      final response = await _run(dio, <String>['key_a', 'key_b']);
      expect(response.isSuccess, isFalse);
      // 两个 key 都被尝试
      expect(usedKeys.length, 2);
      expect(response.errorMessage, contains('429'));
    });

    test('单 key 向后兼容（apiKey 入参进入池）', () async {
      final (dio, usedKeys) = _captureDio(<String>{});
      final service = AiService(
        apiKey: 'legacy_key',
        dio: dio,
        baseUrl: 'https://mock.example.com/v1',
      );
      expect(service.apiKeys, <String>['legacy_key']);
      final response = await service.generateNarrative(
        player: Player.defaultPlayer(),
        context: '测试',
        availableEvents: const <GameEvent>[],
        maxRetries: 0,
      );
      expect(response.isSuccess, isTrue);
      expect(usedKeys, <String>['legacy_key']);
    });

    test('round-robin：连续两次调用从不同 key 开始', () async {
      final firstKeys = <String>[];
      final dio2 = Dio();
      dio2.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            firstKeys.add(
              (options.headers['Authorization'] as String? ?? '')
                  .replaceFirst('Bearer ', ''),
            );
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: <String, dynamic>{
                  'choices': <dynamic>[
                    <String, dynamic>{
                      'message': <String, dynamic>{
                        'content': '{"narrative":"n","choices":[]}',
                      },
                    },
                  ],
                },
              ),
            );
          },
        ),
      );
      final s2 = AiService(
        apiKeys: <String>['k1', 'k2'],
        dio: dio2,
        baseUrl: 'https://mock.example.com/v1',
      );
      await s2.generateNarrative(
        player: Player.defaultPlayer(),
        context: '测试',
        availableEvents: const <GameEvent>[],
        maxRetries: 0,
      );
      await s2.generateNarrative(
        player: Player.defaultPlayer(),
        context: '测试',
        availableEvents: const <GameEvent>[],
        maxRetries: 0,
      );
      expect(firstKeys.length, 2);
      // 两次起始 key 不同（静态 round-robin 跨实例滚动）
      expect(firstKeys[0], isNot(firstKeys[1]));
    });
  });

  group('Batch 10-59 提供商预设', () {
    test('三个提供商各有默认模型与 baseUrl', () {
      expect(kAiProviderDefaults.length, 3);
      final sensenova = providerDefaultsOf('sensenova');
      expect(sensenova.label, contains('SenseNova'));
      expect(sensenova.model, 'sensenova-6.8-flash-lite');
      expect(sensenova.chatBaseUrl, 'https://token.sensenova.cn/v1');
      expect(sensenova.models, contains('sensenova-6.8-flash-lite'));

      final atria = providerDefaultsOf('atria');
      expect(atria.model, 'Atria-Dawn-Preview');
      expect(atria.chatBaseUrl, 'https://api.atria-asi.ai/v1');

      final deepseek = providerDefaultsOf('deepseek');
      expect(deepseek.model, 'deepseek-chat');
      expect(deepseek.chatBaseUrl, 'https://api.deepseek.com/v1');
    });

    test('未知提供商回落到第一个', () {
      final d = providerDefaultsOf('nonexistent');
      expect(d.name, 'sensenova');
    });

    test('AiConfig.resolved 按提供商回落默认', () {
      const cfg = AiConfig(provider: 'atria');
      expect(cfg.resolvedModel, 'Atria-Dawn-Preview');
      expect(cfg.resolvedBaseUrl, 'https://api.atria-asi.ai/v1');

      // 显式 model/baseUrl 优先
      const cfg2 = AiConfig(
        provider: 'atria',
        model: 'custom-model',
        baseUrl: 'https://custom.example.com',
      );
      expect(cfg2.resolvedModel, 'custom-model');
      expect(cfg2.resolvedBaseUrl, 'https://custom.example.com/v1');
    });
  });

  group('Batch 10-59 配置持久化', () {
    test('多 key 保存往返', () async {
      SharedPreferences.setMockInitialValues(<String, dynamic>{});
      const cfg = AiConfig(
        apiKeys: <String>['key1', 'key2', 'key3'],
        model: 'model-x',
        provider: 'deepseek',
      );
      await cfg.save();
      final loaded = await AiConfig.load();
      expect(loaded.apiKeys, <String>['key1', 'key2', 'key3']);
      expect(loaded.model, 'model-x');
      expect(loaded.provider, 'deepseek');
      expect(loaded.isConfigured, isTrue);
      expect(loaded.apiKey, 'key1');
    });

    test('旧版单 key（ai_api_key）迁移兼容', () async {
      SharedPreferences.setMockInitialValues(<String, dynamic>{
        'ai_api_key': 'legacy',
        'ai_model': 'old-model',
        'ai_base_url': '',
      });
      final loaded = await AiConfig.load();
      expect(loaded.apiKeys, <String>['legacy']);
      expect(loaded.apiKey, 'legacy');
      expect(loaded.isConfigured, isTrue);
      expect(loaded.model, 'old-model');
    });

    test('保存时旧单 key 键同步写入', () async {
      SharedPreferences.setMockInitialValues(<String, dynamic>{});
      const cfg = AiConfig(apiKeys: <String>['k1']);
      await cfg.save();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ai_api_key'), 'k1');
      expect(prefs.getString('ai_api_keys'), contains('k1'));
    });
  });
}