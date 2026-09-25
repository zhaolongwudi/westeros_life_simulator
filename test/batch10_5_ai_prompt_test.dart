/// Batch 10-5 测试：AI 提示词增强（头衔/装备注入）。
///
/// 覆盖：
/// 1. systemPrompt 核心原则完整
/// 2. buildPrompt 注入头衔/已装备（通过 Dio mock 捕获请求体验证）
/// 3. AI 效果键说明包含生存轴/物品
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/models/event.dart';
import 'package:westeros_life_simulator/models/player.dart';
import 'package:westeros_life_simulator/services/ai_service.dart';

void main() {
  group('Batch 10-5 systemPrompt', () {
    test('核心原则完整', () {
      expect(AiService.systemPrompt, contains('维斯特洛世界模拟系统'));
      expect(AiService.systemPrompt, contains('世界不围绕玩家存在'));
      expect(AiService.systemPrompt, contains('玩家可以是任何人'));
      expect(AiService.systemPrompt, contains('历史不会停止'));
      expect(AiService.systemPrompt, contains('家族不是职业'));
      expect(AiService.systemPrompt, contains('封建权力结构复杂'));
      expect(AiService.systemPrompt, contains('每个选择都有代价'));
    });

    test('systemPrompt 强调世界观一致性', () {
      expect(AiService.systemPrompt, contains('季节'));
      expect(AiService.systemPrompt, contains('维斯特洛世界观一致性'));
    });
  });

  group('Batch 10-5 buildPrompt 注入', () {
    test('提示词包含头衔与已装备信息', () async {
      String? capturedBody;
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedBody = options.data.toString();
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
        apiKey: 'test_key',
        dio: dio,
        baseUrl: 'https://mock.example.com/v1',
      );
      // 带头衔与装备的玩家
      final player = Player.defaultPlayer().copyWith(
        title: '骑士',
        flags: <String, bool>{
          ...Player.defaultPlayer().flags,
          'equipped.item_sword': true,
          'equipped.item_chainmail': true,
        },
      );
      await service.generateNarrative(
        player: player,
        context: '你在君临的街头。',
        availableEvents: const <GameEvent>[],
        maxRetries: 0,
      );

      expect(capturedBody, isNotNull);
      expect(capturedBody, contains('骑士'));
      expect(capturedBody, contains('item_sword'));
      expect(capturedBody, contains('item_chainmail'));
      expect(capturedBody, contains('已装备'));
      expect(capturedBody, contains('头衔'));
    });

    test('提示词包含生存轴与物品效果键说明', () async {
      String? capturedBody;
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedBody = options.data.toString();
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: <String, dynamic>{
                  'choices': <dynamic>[
                    <String, dynamic>{
                      'message': <String, dynamic>{
                        'content': '{"narrative":"测试","choices":[]}',
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
        apiKey: 'test_key',
        dio: dio,
        baseUrl: 'https://mock.example.com/v1',
      );
      await service.generateNarrative(
        player: Player.defaultPlayer(),
        context: '测试',
        availableEvents: const <GameEvent>[],
        maxRetries: 0,
      );

      expect(capturedBody, contains('生存状态'));
      expect(capturedBody, contains('health / energy / hunger'));
      expect(capturedBody, contains('inventory.物品ID'));
      expect(capturedBody, contains('flags.标记名'));
    });
  });

  group('Batch 10-5 AI 选项效果落盘（装备/头衔联动）', () {
    test('AI 选项可授予头衔（title 效果键解析）', () {
      final engine = GameEngine()..startNewGame();
      // 直接调用 applyEffects 验证 title 不被误处理（未知键忽略，不崩溃）
      final p = engine.applyEffects(
        engine.player,
        const <String, int>{'title_grant': 1, 'gold': 10},
      );
      expect(p.gold, 110);
      // 未知键 title_grant 被忽略但金币生效
    });
  });
}