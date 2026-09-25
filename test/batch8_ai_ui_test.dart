/// Batch 8 测试：AI 配置 + 主界面 AI 行动模式。
///
/// 覆盖：AiConfig 默认值/读写、主界面 AI 开关可构建、设置界面 AI 配置卡片。
/// 不调用真实网络（AI 请求用 mock 或直接不触发）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:westeros_life_simulator/screens/game_screen.dart';
import 'package:westeros_life_simulator/screens/settings_screen.dart';
import 'package:westeros_life_simulator/services/ai_config.dart';
import 'package:westeros_life_simulator/services/save_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // 清空 SharedPreferences 避免测试间污染
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('Batch 8 AI 配置', () {
    test('AiConfig 默认值', () {
      final config = AiConfig.defaultConfig();
      expect(config.apiKey, isEmpty);
      expect(config.model, 'sensenova-6.8-flash-lite');
      expect(config.baseUrl, 'https://token.sensenova.cn/v1');
      expect(config.isConfigured, false);
    });

    test('AiConfig 读写持久化', () async {
      final config = AiConfig(
        apiKey: 'test_key_123',
        model: 'test-model',
        baseUrl: 'https://example.com/v1',
      );
      await config.save();

      final loaded = await AiConfig.load();
      expect(loaded.apiKey, 'test_key_123');
      expect(loaded.model, 'test-model');
      expect(loaded.baseUrl, 'https://example.com/v1');
      expect(loaded.isConfigured, true);
    });

    testWidgets('主界面可构建（含 AI 行动模式开关）', (tester) async {
      tester.view.physicalSize = const Size(1080, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(home: GameScreen()),
      );
      expect(find.text('AI 行动模式'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('设置界面可构建（含 AI 配置卡片）', (tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            saveService: _MemorySaveService(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('AI 配置'), findsOneWidget);
      expect(find.textContaining('未配置 API Key'), findsOneWidget);
    });
  });
}

/// 内存版存档服务（避免真实文件 IO）。
class _MemorySaveService extends SaveService {
  _MemorySaveService() : super(saveDir: '/tmp/nonexistent_batch8_test_dir');

  @override
  Future<List<SaveMetadata>> listSaves() async => <SaveMetadata>[];
}