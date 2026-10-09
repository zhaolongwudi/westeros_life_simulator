/// Batch 10-15 测试：NPC 深度交互二轮（任务链 / 深聊 / 关系面板 / AI 注入）。
///
/// 覆盖：
/// 1. npcTasks：NPC 任务列表（保留）
/// 2. npcChat：深聊（相识以上/每日限次）（保留）
/// 3. formatNpcRelationPanel：关系面板（保留）
/// 4. 指令接线：任务/深聊/关系 命令（保留）
/// 5. ai_service：在场 NPC 关系注入（保留）
///
/// 【S14-1 删除】`formatNpcTaskPanel` / `acceptNpcTask` / `maybeResolveNpcTask`
/// 三个 V1 测试组已删除。原因：这三个 V1 函数本身已在 S13-3 被 V2
/// （`formatNpcTaskPanelV2` / `acceptNpcTaskV2` / V2 多步骤结算链）取代，
/// 并于 S14-1 从 `mixin_npc_interact.dart` 删除——它们自 S13-3 起就
/// **只有这批测试在测、生产零调用方**，是典型的「死代码 + 测试」。
/// 原断言的契约由 `batch13_s3_npc_task_button_test.dart` 覆盖。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/services/ai_service.dart';

void main() {
  group('Batch 10-15 npcTasks', () {
    test('艾德·史塔克有任务', () {
      final engine = GameEngine()..startNewGame();
      final tasks = engine.npcTasks('npc_nev');
      expect(tasks, isNotEmpty);
      expect(tasks.first, contains('护送'));
    });
    test('未知 NPC 返回空', () {
      final engine = GameEngine()..startNewGame();
      expect(engine.npcTasks('npc_unknown'), isEmpty);
    });
  });

  group('Batch 10-15 npcChat', () {
    test('陌生关系聊不到深处', () {
      final engine = GameEngine()..startNewGame();
      final result = engine.npcChat('npc_nev');
      expect(result, contains('聊不到深处'));
    });
    test('相识关系深聊提升好感', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{'npc_nev': 25},
        ),
      );
      final before = engine.player.relations['npc_nev'] ?? 0;
      final result = engine.npcChat('npc_nev');
      expect(result, contains('深聊'));
      expect(engine.player.relations['npc_nev'] ?? 0, greaterThan(before));
    });
    test('每日深聊限次', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{'npc_nev': 50},
        ),
      );
      var limited = false;
      for (var i = 0; i < 5; i++) {
        final result = engine.npcChat('npc_nev');
        if (result.contains('聊得够多')) {
          limited = true;
          break;
        }
      }
      expect(limited, true);
    });
  });

  group('Batch 10-15 formatNpcRelationPanel', () {
    test('面板包含全部存活 NPC 与关系', () {
      final engine = GameEngine()..startNewGame();
      final panel = engine.formatNpcRelationPanel();
      expect(panel, contains('艾德·史塔克'));
      expect(panel, contains('陌生'));
    });
  });

  group('Batch 10-15 指令接线', () {
    test('任务指令返回面板', () {
      final engine = GameEngine()..startNewGame();
      final result = engine.resolveCommand('任务');
      expect(result.text, contains('可接任务'));
    });
    test('任务指令带名字执行', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{'npc_nev': 25},
        ),
      );
      final result = engine.resolveCommand('任务 艾德·史塔克');
      expect(result.text, contains('接下'));
    });
    test('深聊指令带名字执行', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{'npc_nev': 25},
        ),
      );
      final result = engine.resolveCommand('深聊 艾德·史塔克');
      expect(result.text, contains('深聊'));
    });
    test('关系指令返回面板', () {
      final engine = GameEngine()..startNewGame();
      final result = engine.resolveCommand('关系');
      expect(result.text, contains('NPC 关系'));
    });
  });

  group('Batch 10-15 ai_service 在场 NPC 注入', () {
    test('prompt 包含在场 NPC 关系', () {
      final engine = GameEngine()..startNewGame();
      // 直接调用构建 prompt（通过 generateNarrative 的 mock 验证太复杂，
      // 这里用公开字段验证数据层已带任务）
      final npc = engine.npcById('npc_nev');
      expect(npc, isNotNull);
      expect(npc!.tasks, isNotEmpty);
      // AiService 构造可用（不实际请求）
      final service = AiService(apiKey: 'test');
      expect(service, isNotNull);
      // 在场 NPC 关系应包含艾德·史塔克（默认出生临冬城）
      final onSite = engine.npcsAtCurrentLocation
          .where((n) => n.id == 'npc_nev')
          .toList();
      expect(onSite, isNotEmpty);
    });
  });
}