/// Batch 3 测试：AiService。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/models/event.dart';
import 'package:westeros_life_simulator/services/ai_service.dart';

void main() {
  group('AiResponse', () {
    test('成功响应', () {
      final response = AiResponse(
        narrative: '测试叙事',
        choices: const [
          EventChoice(
            id: 'c1',
            text: '选项 1',
            requirements: const {},
            effects: const {},
            narrative: '叙事 1',
          ),
        ],
        isSuccess: true,
      );
      expect(response.isSuccess, true);
      expect(response.narrative, '测试叙事');
      expect(response.choices.length, 1);
      expect(response.errorMessage, isNull);
    });

    test('失败响应', () {
      final response = AiResponse(
        narrative: '',
        choices: const [],
        isSuccess: false,
        errorMessage: 'HTTP 429',
      );
      expect(response.isSuccess, false);
      expect(response.errorMessage, 'HTTP 429');
    });
  });

  group('AiService', () {
    test('初始化', () {
      final service = AiService(apiKey: 'test_key');
      expect(service.apiKey, 'test_key');
      expect(service.baseUrl, 'https://token.sensenova.cn/v1');
      expect(service.model, 'sensenova-6.8-flash-lite');
    });

    test('自定义配置', () {
      final service = AiService(
        apiKey: 'test_key',
        baseUrl: 'https://api.example.com/v1',
        model: 'test-model',
      );
      expect(service.baseUrl, 'https://api.example.com/v1');
      expect(service.model, 'test-model');
    });

    test('System Prompt 包含核心原则', () {
      expect(AiService.systemPrompt, contains('维斯特洛世界模拟系统'));
      expect(AiService.systemPrompt, contains('世界不围绕玩家存在'));
      expect(AiService.systemPrompt, contains('玩家可以是任何人'));
    });
  });
}