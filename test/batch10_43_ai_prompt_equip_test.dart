/// Batch 10-43 测试：AI prompt 注入装备战力（装备明细 + 战斗值）。
///
/// 覆盖：
/// 1. combatPowerOf 纯函数：默认玩家战力 / 装备加成 / 空装备兜底
/// 2. prompt 注入：已装备明细（名称+分类+价值）与战斗值行
/// 3. 与混入层 combatPower 算法一致（同装备结果相等）
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/models/event.dart';
import 'package:westeros_life_simulator/models/player.dart';
import 'package:westeros_life_simulator/services/ai_service.dart';

/// 构造带装备的玩家（默认技能 sword3/archery2 + 力量5 → 基础战力 10）。
Player _playerWithEquip() {
  return Player.defaultPlayer().copyWith(
    flags: <String, bool>{
      ...Player.defaultPlayer().flags,
      'equipped.item_sword': true, // 长剑 value40 → +2
      'equipped.item_chainmail': true, // 锁子甲 value90 → +3
    },
  );
}

void main() {
  group('Batch 10-43 combatPowerOf 纯函数', () {
    test('默认玩家战力为基础值 10（技能+力量，无装备）', () {
      expect(AiService.combatPowerOf(Player.defaultPlayer()), 10);
    });

    test('装备长剑+锁子甲后战力 15（10 + 2 + 3）', () {
      expect(AiService.combatPowerOf(_playerWithEquip()), 15);
    });

    test('空装备 / 未装备 flag 不影响战力', () {
      final p = Player.defaultPlayer().copyWith(
        flags: <String, bool>{...Player.defaultPlayer().flags, 'equipped.item_bread': true},
      );
      // 消耗品不算装备加成
      expect(AiService.combatPowerOf(p), 10);
    });

    test('与混入层 combatPower 算法一致（引擎同装备结果相等）', () {
      final engine = GameEngine()..startNewGame();
      // 直接设装备 flag（跳过物品持有检查，聚焦算法一致性）
      engine.setFlag('equipped.item_sword', true);
      engine.setFlag('equipped.item_chainmail', true);
      expect(
        AiService.combatPowerOf(engine.player),
        engine.combatPower(),
      );
    });
  });

  group('Batch 10-43 prompt 注入装备战力', () {
    test('prompt 包含装备明细与战斗值行', () async {
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
      await service.generateNarrative(
        player: _playerWithEquip(),
        context: '你在临冬城的庭院。',
        availableEvents: const <GameEvent>[],
        maxRetries: 0,
      );

      expect(capturedBody, isNotNull);
      // 装备明细：名称 + 分类 + 价值
      expect(capturedBody, contains('长剑（武器，价值 40）'));
      expect(capturedBody, contains('锁子甲（护甲，价值 90）'));
      // 战斗值行
      expect(capturedBody, contains('战斗值：15'));
    });

    test('无装备时已装备兜底（无）+ 战斗值基础 10', () async {
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
      await service.generateNarrative(
        player: Player.defaultPlayer(),
        context: '测试',
        availableEvents: const <GameEvent>[],
        maxRetries: 0,
      );

      expect(capturedBody, isNotNull);
      expect(capturedBody, contains('已装备：（无）'));
      expect(capturedBody, contains('战斗值：10'));
    });
  });
}
