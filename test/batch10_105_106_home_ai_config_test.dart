/// Batch 10-105/106 测试：开屏首页（主菜单）+ 开局分步向导 + AI 多模型配置 + 连通性测试。
///
/// 覆盖：
/// 1. HomeScreen 主菜单：三按钮渲染、无存档时「继续游戏（暂无存档）」态、点「开始新游戏」进开局向导
/// 2. StartScreen 分步向导：第 0 步显示姓名输入、可逐级「下一步」到确认页、开始游戏从 disabled → enabled
/// 3. AiConfig.customModels 持久化往返 + allModels 去重保序
/// 4. AiService.testConnection（成功 / HTTP 400 / 未配 Key）与 fetchModels（解析 / 空数据 / 未配 Key）
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:westeros_life_simulator/data/ai_provider_defaults.dart';
import 'package:westeros_life_simulator/screens/home_screen.dart';
import 'package:westeros_life_simulator/screens/start_screen.dart';
import 'package:westeros_life_simulator/services/ai_config.dart';
import 'package:westeros_life_simulator/services/ai_service.dart';
import 'package:westeros_life_simulator/services/save_service.dart';

/// 构造一个按给定响应分发请求的 mock Dio。
///
/// [onPost]：chat/completions 的处理（返回 (statusCode, data) 或抛异常）。
/// [onGet]：/models 的处理。
(Dio, List<String>) _captureDio({
  (int, Map<String, dynamic>)? Function()? onPost,
  (int, Map<String, dynamic>)? Function()? onGet,
}) {
  final usedKeys = <String>[];
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final auth = options.headers['Authorization'] as String? ?? '';
        final key = auth.replaceFirst('Bearer ', '');
        usedKeys.add(key);
        if (options.method == 'POST') {
          final r = onPost?.call();
          if (r == null) {
            handler.reject(
              DioException(
                requestOptions: options,
                message: 'Network error',
              ),
            );
            return;
          }
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: r.$1,
              data: r.$2,
            ),
          );
          return;
        }
        // GET /models
        final r = onGet?.call();
        if (r == null) {
          handler.reject(
            DioException(
              requestOptions: options,
              message: 'Network error',
            ),
          );
          return;
        }
        handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            statusCode: r.$1,
            data: r.$2,
          ),
        );
      },
    ),
  );
  return (dio, usedKeys);
}

/// 未配 Key 的 AiService（testConnection / fetchModels 应短路返回）。
AiService _serviceNoKey() {
  return AiService(
    apiKeys: const <String>[],
    baseUrl: 'https://mock.example.com/v1',
  );
}

void main() {
  // ── 1. HomeScreen 开屏首页 ───────────────────────────
  group('Batch 10-105 开屏首页', () {
    testWidgets('主菜单渲染三按钮（无存档态）', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            saveService: _MemorySaveService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('维斯特洛人生模拟器'), findsOneWidget);
      expect(find.text('开始新游戏'), findsOneWidget);
      expect(find.text('继续游戏（暂无存档）'), findsOneWidget);
      expect(find.text('设置（AI / 存档）'), findsOneWidget);
    });

    testWidgets('无存档时「继续游戏」按钮为禁用态', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            saveService: _MemorySaveService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('继续游戏（暂无存档）'), findsOneWidget);
      // disabled 语义：GestureDetector.onTap 为 null（无存档不可继续）
      final gesture = tester.widget<GestureDetector>(
        find.ancestor(
          of: find.text('继续游戏（暂无存档）'),
          matching: find.byType(GestureDetector),
        ),
      );
      expect(gesture.onTap, isNull);
      // 点击不会产生 SnackBar
      await tester.tap(find.text('继续游戏（暂无存档）'), warnIfMissed: false);
      await tester.pump();
      expect(find.text('暂无存档，先开始一段新人生吧'), findsNothing);
    });

    testWidgets('点「开始新游戏」进入开局分步向导', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            saveService: _MemorySaveService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('开始新游戏'));
      await tester.pumpAndSettle();

      // 进入 StartScreen：AppBar「开始新人生」+ 第 0 步姓名输入
      expect(find.text('开始新人生'), findsOneWidget);
      expect(find.text('输入姓名（留空随机）'), findsOneWidget);
    });
  });

  // ── 2. StartScreen 分步向导 ──────────────────────────
  group('Batch 10-105 开局分步向导', () {
    testWidgets('第 0 步姓名/性别，底部「开始游戏」禁用', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: StartScreen()));
      await tester.pumpAndSettle();

      expect(find.text('姓名'), findsWidgets);
      expect(find.text('男'), findsOneWidget);
      expect(find.text('女'), findsOneWidget);
      // 底部操作栏
      expect(find.text('下一步'), findsOneWidget);
      expect(find.textContaining('开始游戏'), findsOneWidget);
      // 第 0 步「开始游戏」按钮为 disabled
      final button = tester.widget<FilledButton>(
        find.ancestor(
          of: find.textContaining('开始游戏'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('逐级「下一步」可到达确认页，开始游戏变为可用', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: StartScreen()));
      await tester.pumpAndSettle();

      // 从第 0 步一路下一步到第 6 步（确认页）
      for (var i = 0; i < 6; i++) {
        await tester.tap(find.text('下一步'));
        await tester.pumpAndSettle();
      }

      // 确认页汇总文案（Stepper 非当前步 content 仍在树中，
      // 第 0 步 _StartHero 也含「凛冬将至」→ findsWidgets；
      // 「姓名：」「身份：」为确认页独有 → findsOneWidget）
      expect(find.textContaining('凛冬将至'), findsWidgets);
      expect(find.textContaining('姓名：'), findsOneWidget);
      expect(find.textContaining('身份：'), findsOneWidget);

      // 此刻「开始游戏」可用
      final button = tester.widget<FilledButton>(
        find.ancestor(
          of: find.textContaining('开始游戏'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.onPressed, isNotNull);
    });
  });

  // ── 3. AiConfig customModels ─────────────────────────
  group('Batch 10-106 AiConfig 自定义模型', () {
    test('customModels 持久化往返 + allModels 去重保序', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final config = AiConfig(
        apiKeys: const <String>['k1'],
        model: 'custom-x',
        baseUrl: '',
        provider: 'sensenova',
        customModels: const <String>['custom-x', 'deepseek-chat'],
      );
      await config.save();

      final loaded = await AiConfig.load();
      expect(loaded.customModels, <String>['custom-x', 'deepseek-chat']);
      // 提供商候选（sensenova 3 个）∪ 自定义（custom-x、deepseek-chat 都不在候选里）
      final defaults = providerDefaultsOf('sensenova');
      final expected = <String>[
        ...defaults.models,
        'custom-x',
        'deepseek-chat',
      ];
      expect(loaded.allModels, expected);
      expect(loaded.allModels.toSet().length, loaded.allModels.length);
    });

    test('旧单 Key 迁移兼容不受 customModels 影响', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final config = AiConfig(apiKey: 'legacy');
      await config.save();
      final loaded = await AiConfig.load();
      expect(loaded.apiKey, 'legacy');
      expect(loaded.customModels, isEmpty);
      expect(loaded.allModels, providerDefaultsOf('sensenova').models);
    });

    test('clear 同时清掉 customModels', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final config = AiConfig(
        apiKeys: const <String>['k1'],
        customModels: const <String>['m1'],
      );
      await config.save();
      await config.clear();
      final loaded = await AiConfig.load();
      expect(loaded.customModels, isEmpty);
    });
  });

  // ── 4. AiService 连通性测试 + 自动识别模型 ───────────
  group('Batch 10-106 AiService 测试系统', () {
    test('testConnection 成功（200）', () async {
      final (dio, _) = _captureDio(
        onPost: () => (200, <String, dynamic>{
          'choices': <dynamic>[
            <String, dynamic>{
              'message': <String, dynamic>{'content': 'pong'},
            },
          ],
        }),
      );
      final service = AiService(
        apiKeys: const <String>['key_a'],
        dio: dio,
        baseUrl: 'https://mock.example.com/v1',
        model: 'test-model',
      );
      final (ok, msg) = await service.testConnection();
      expect(ok, isTrue);
      expect(msg, contains('连接正常'));
    });

    test('testConnection 失败（HTTP 400）', () async {
      final (dio, _) = _captureDio(
        onPost: () => (400, <String, dynamic>{'error': 'bad request'}),
      );
      final service = AiService(
        apiKeys: const <String>['key_a'],
        dio: dio,
        baseUrl: 'https://mock.example.com/v1',
      );
      final (ok, msg) = await service.testConnection();
      expect(ok, isFalse);
      expect(msg, contains('HTTP 400'));
    });

    test('testConnection 未配 Key 短路', () async {
      final (ok, msg) = await _serviceNoKey().testConnection();
      expect(ok, isFalse);
      expect(msg, '未配置 API Key');
    });

    test('fetchModels 解析 OpenAI 兼容响应', () async {
      final (dio, _) = _captureDio(
        onGet: () => (200, <String, dynamic>{
          'object': 'list',
          'data': <dynamic>[
            <String, dynamic>{'id': 'model-a'},
            <String, dynamic>{'id': 'model-b'},
            <String, dynamic>{'id': ''}, // 空 id 应被跳过
          ],
        }),
      );
      final service = AiService(
        apiKeys: const <String>['key_a'],
        dio: dio,
        baseUrl: 'https://mock.example.com/v1',
      );
      final models = await service.fetchModels();
      expect(models, <String>['model-a', 'model-b']);
    });

    test('fetchModels 空数据返回空列表', () async {
      final (dio, _) = _captureDio(
        onGet: () => (200, <String, dynamic>{
          'object': 'list',
          'data': <dynamic>[],
        }),
      );
      final service = AiService(
        apiKeys: const <String>['key_a'],
        dio: dio,
        baseUrl: 'https://mock.example.com/v1',
      );
      expect(await service.fetchModels(), isEmpty);
    });

    test('fetchModels 未配 Key 短路返回空', () async {
      expect(await _serviceNoKey().fetchModels(), isEmpty);
    });

    test('fetchModels 顶层直接是数组也能解析', () async {
      final (dio, _) = _captureDio(
        onGet: () => (200, <dynamic>[
          <String, dynamic>{'id': 'm1'},
          'm2',
          <String, dynamic>{'id': ''}, // 空 id 跳过
        ]),
      );
      final service = AiService(
        apiKeys: const <String>['key_a'],
        dio: dio,
        baseUrl: 'https://mock.example.com/v1',
      );
      expect(await service.fetchModels(), <String>['m1', 'm2']);
    });

    test('fetchModels 兼容 models 键 + name 字段变体', () async {
      final (dio, _) = _captureDio(
        onGet: () => (200, <String, dynamic>{
          'object': 'list',
          'models': <dynamic>[
            <String, dynamic>{'name': 'model-x'},
            <String, dynamic>{'model': 'model-y'},
            <String, dynamic>{'id': 123}, // 非字符串 id 跳过
          ],
        }),
      );
      final service = AiService(
        apiKeys: const <String>['key_a'],
        dio: dio,
        baseUrl: 'https://mock.example.com/v1',
      );
      expect(await service.fetchModels(), <String>['model-x', 'model-y']);
    });

    test('fetchModels 响应结构未知返回空列表', () async {
      final (dio, _) = _captureDio(
        onGet: () => (200, <String, dynamic>{'foo': 'bar'}),
      );
      final service = AiService(
        apiKeys: const <String>['key_a'],
        dio: dio,
        baseUrl: 'https://mock.example.com/v1',
      );
      expect(await service.fetchModels(), isEmpty);
    });
  });
}

/// 内存版存档服务（测试用，避免 flutter_test FakeAsync 下真实文件 IO 不 resolve）。
class _MemorySaveService extends SaveService {
  _MemorySaveService() : super(saveDir: '/tmp/nonexistent_batch10_105_test_dir');

  @override
  Future<List<SaveMetadata>> listSaves() async => <SaveMetadata>[];
}
