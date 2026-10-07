/// Sprint 13-1 测试：修两个 P0 崩溃（② 传承后 `isMarried` 残留 / ③ 互动空列表）。
///
/// 【本文件是 S13-1 的复现测试】按接力文档第 4 条「先写能复现的失败测试再改实现」。
/// 修复前这两组断言都会抛 `StateError`：
///
/// ① **传承**：继承人构造时 `flags: {...p.flags}` 把 `isMarried: true` 带过、
///    却**不传 `spouse`**；`isMarried` getter 是 `spouse != null || flagOf('isMarried')`，
///    于是新家主 `isMarried == true` 而 `player.spouse == null`。下个月
///    `family_event` 钩子 `maybeFamilyEvent` 走 `player.spouse!` ⇒ 抛 `StateError`，
///    而 `MonthlyPipeline.runPhase` 无 try/catch ⇒ **整局卡死**。
///    （崩溃在下一个月：死亡当月 `family_event` 排 `beforeAdvance` order 6，
///     传承排 `afterAdvance` order 11，故当月用的是死者自己的配偶。）
///
/// ② **互动**：`npcInteract` 相识分支写 `npc.goals.isNotEmpty ? npc.goals.first
///    : npc.fears.first`，两个列表皆空时 `.first` 抛 `StateError`。实测
///    `npc_rickon` / `npc_lys_arryn` / `npc_tommen` / `npc_myrcella` 共 4 个
///    `goals: []` + `fears: []`，其中瑞肯**就在默认出生地临冬城**。
///
/// ⚠️ 本机（Android/DSH）无 dart/flutter，**本文件未在本地执行**，正确性由 CI 验证。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';

void main() {
  group('S13-1 ② 传承后 isMarried 残留导致月度钩子崩溃', () {
    test('求婚→生子→死亡→传承后新家主未婚，且连过两月不抛', () {
      final engine = GameEngine()..startNewGame();
      engine.marry('平民');
      engine.addChild('罗柏');
      expect(engine.isMarried, isTrue);
      expect(engine.player.spouse, isNotNull);

      // 模拟死亡：健康归零 + isAlive=false（与 batch10_14 同法）
      engine.updatePlayer(
        engine.player.copyWith(
          health: 0,
          flags: <String, bool>{...engine.player.flags, 'isAlive': false},
        ),
      );

      // 死亡当月：传承发生在 afterAdvance，不抛
      final first = engine.advanceMonth();
      expect(first, contains('血脉延续'));
      expect(engine.player.name, '罗柏');

      // 传承后：spouse 不随传承下行，已婚标记必须一并清除
      expect(engine.player.spouse, isNull);
      expect(engine.isMarried, isFalse);
      expect(engine.formatFamilyTree(), contains('未婚'));

      // 关键回归点：下一个月不得抛 StateError（修复前在此崩）
      expect(() => engine.advanceMonth(), returnsNormally);
    });

    test('传承未留已婚标记：新家主 flags 里 isMarried 为假', () {
      final engine = GameEngine()..startNewGame();
      engine.marry('平民');
      engine.addChild('罗柏');
      final newPlayer = engine.advanceGeneration();
      expect(newPlayer, isNotNull);
      expect(newPlayer!.spouse, isNull);
      expect(newPlayer.flags['isMarried'], isFalse);
      expect(engine.isMarried, isFalse);
    });

    // 纵深防御：即便矛盾态从**别的**通道进来（修复前导出的旧存档、
    // AI 通道写 `flags.isMarried`——该键在白名单内），`isMarried` 也必须与
    // `spouse` 一致，不能让 8 处 `player.spouse!` 强解包踩雷。
    test('矛盾态（只有标记没有配偶）被判为未婚，且过月不崩', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          clearSpouse: true,
          flags: <String, bool>{...engine.player.flags, 'isMarried': true},
        ),
      );
      expect(engine.isMarried, isFalse); // 单真相源：有配偶才算已婚
      expect(engine.formatFamilyTree(), contains('未婚'));
      expect(() => engine.advanceMonth(), returnsNormally);
    });
  });

  group('S13-1 ③ 互动对 goals/fears 皆空的 NPC 崩溃', () {
    test('瑞肯（goals/fears 皆空，在默认出生地）相识关系互动不抛', () {
      final engine = GameEngine()..startNewGame();
      final rickon = engine.npcById('npc_rickon');
      expect(rickon, isNotNull);
      expect(rickon!.locationId, engine.player.locationId);
      expect(rickon.goals, isEmpty);
      expect(rickon.fears, isEmpty);

      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{'npc_rickon': 30}, // 相识区间 20~39
        ),
      );
      expect(() => engine.npcInteract('npc_rickon'), returnsNormally);
      final result = engine.npcInteract('npc_rickon');
      expect(result, contains('瑞肯'));
      expect(result, contains('倾诉'));
    });

    test('其余 3 个 goals/fears 皆空的 NPC 同样不抛', () {
      final engine = GameEngine()..startNewGame();
      for (final id in const ['npc_lys_arryn', 'npc_tommen', 'npc_myrcella']) {
        final npc = engine.npcById(id);
        expect(npc, isNotNull, reason: id);
        // 这 3 个不在临冬城，先把玩家移到其所在地再互动
        engine.updatePlayer(
          engine.player.copyWith(
            locationId: npc!.locationId,
            relations: <String, int>{id: 30},
          ),
        );
        expect(() => engine.npcInteract(id), returnsNormally, reason: id);
        expect(engine.npcInteract(id), contains('倾诉'), reason: id);
      }
    });
  });
}
