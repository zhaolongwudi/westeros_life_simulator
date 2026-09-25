/// Batch 10-13 测试：NPC 深度交互。
///
/// 覆盖：
/// 1. npcRelationLabel：关系等级标签
/// 2. npcInteractionList：在场 NPC 列表（含关系等级）
/// 3. npcInteract：按关系等级解锁互动（敌对/陌生/相识/熟识/信任/挚友）
/// 4. npcFavor：示好送礼提升好感（每日限次）
/// 5. maybeNpcStoryEvent：好感度事件链（一次性 flag）
/// 6. 指令接线：在场/互动/示好 命令
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';

void main() {
  group('Batch 10-13 npcRelationLabel', () {
    test('关系等级映射正确', () {
      final engine = GameEngine()..startNewGame();
      expect(engine.npcRelationLabel(-50), '敌对');
      expect(engine.npcRelationLabel(-20), '敌对');
      expect(engine.npcRelationLabel(0), '陌生');
      expect(engine.npcRelationLabel(19), '陌生');
      expect(engine.npcRelationLabel(20), '相识');
      expect(engine.npcRelationLabel(39), '相识');
      expect(engine.npcRelationLabel(40), '熟识');
      expect(engine.npcRelationLabel(59), '熟识');
      expect(engine.npcRelationLabel(60), '信任');
      expect(engine.npcRelationLabel(79), '信任');
      expect(engine.npcRelationLabel(80), '挚友');
      expect(engine.npcRelationLabel(100), '挚友');
    });
  });

  group('Batch 10-13 npcInteractionList', () {
    test('初始无关系在场 NPC 显示陌生', () {
      final engine = GameEngine()..startNewGame();
      // 默认出生地临冬城，应有多名 NPC 在场
      final list = engine.npcInteractionList();
      expect(list, isNotEmpty);
      expect(list.first, contains('关系'));
    });

    test('有关系的 NPC 显示等级', () {
      final engine = GameEngine()..startNewGame();
      // 手动建立关系
      final p = engine.player.copyWith(
        relations: const <String, int>{'npc_nev': 85},
      );
      engine.updatePlayer(p);
      final list = engine.npcInteractionList();
      final stark = list.where((s) => s.contains('艾德·史塔克')).toList();
      // 艾德·史塔克在临冬城，关系 85 显示挚友
      expect(stark, isNotEmpty);
      expect(stark.first, contains('挚友'));
    });
  });

  group('Batch 10-13 npcInteract', () {
    test('未知 NPC 返回提示', () {
      final engine = GameEngine()..startNewGame();
      expect(engine.npcInteract('npc_unknown'), contains('没有'));
    });

    test('敌对关系冷眼', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{'npc_nev': -50},
        ),
      );
      final result = engine.npcInteract('npc_nev');
      expect(result, contains('沉下脸'));
      expect(result, contains('旧账'));
    });

    test('陌生关系寒暄', () {
      final engine = GameEngine()..startNewGame();
      // 艾德·史塔克默认关系 0（陌生）
      final result = engine.npcInteract('npc_nev');
      expect(result, contains('寒暄'));
    });

    test('相识关系倾诉（用目标/恐惧）', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{'npc_nev': 30},
        ),
      );
      final result = engine.npcInteract('npc_nev');
      expect(result, contains('倾诉'));
    });

    test('熟识关系触发请求（贵族引荐/请教）', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{'npc_nev': 45},
        ),
      );
      final result = engine.npcInteract('npc_nev');
      // 熟识分支：引荐或请教，均提升声望或关系
      expect(result, anyOf(contains('引荐'), contains('请教')));
    });

    test('信任关系吐露秘密（关系 +3）', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{'npc_nev': 65},
        ),
      );
      final before = engine.player.relations['npc_nev'] ?? 0;
      final result = engine.npcInteract('npc_nev');
      expect(result, contains('秘密'));
      expect(engine.player.relations['npc_nev'] ?? 0, greaterThan(before));
    });

    test('挚友关系结盟（声望 +2 关系 +2）', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{'npc_nev': 90},
        ),
      );
      final repBefore = engine.player.reputation;
      final relBefore = engine.player.relations['npc_nev'] ?? 0;
      final result = engine.npcInteract('npc_nev');
      expect(result, contains('结为挚友'));
      expect(engine.player.reputation, greaterThan(repBefore));
      expect(engine.player.relations['npc_nev'] ?? 0, greaterThan(relBefore));
    });

    test('不在场的 NPC 返回提示', () {
      final engine = GameEngine()..startNewGame();
      // 找一个不在临冬城的 NPC（如 提利昂在君临）
      final tyrion = engine.npcById('npc_tyrion');
      expect(tyrion, isNotNull);
      if (tyrion!.locationId != engine.player.locationId) {
        final result = engine.npcInteract('npc_tyrion');
        expect(result, contains('不在这里'));
      }
    });
  });

  group('Batch 10-13 npcFavor', () {
    test('示好提升关系且扣金币', () {
      final engine = GameEngine()..startNewGame();
      final goldBefore = engine.player.gold;
      final result = engine.npcFavor('npc_nev');
      expect(result, anyOf(contains('示好'), contains('薄礼')));
      expect(engine.player.gold, lessThan(goldBefore));
      expect(engine.player.relations['npc_nev'], greaterThan(0));
    });

    test('每日示好限次', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(gold: 1000),
      );
      var limited = false;
      for (var i = 0; i < 5; i++) {
        final result = engine.npcFavor('npc_nev');
        if (result.contains('次数已经用完')) {
          limited = true;
          break;
        }
      }
      expect(limited, true);
    });

    test('不在场的 NPC 返回提示', () {
      final engine = GameEngine()..startNewGame();
      final tyrion = engine.npcById('npc_tyrion');
      if (tyrion != null && tyrion.locationId != engine.player.locationId) {
        expect(engine.npcFavor('npc_tyrion'), contains('不在这里'));
      }
    });
  });

  group('Batch 10-13 maybeNpcStoryEvent', () {
    test('陌生关系不触发剧情', () {
      final engine = GameEngine()..startNewGame();
      final result = engine.maybeNpcStoryEvent();
      expect(result, '');
    });

    test('相识关系触发萌芽剧情且仅一次', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{'npc_nev': 25},
        ),
      );
      final first = engine.maybeNpcStoryEvent();
      expect(first, contains('萌芽'));
      final second = engine.maybeNpcStoryEvent();
      expect(second, '');
    });

    test('挚友关系触发立誓剧情', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: const <String, int>{'npc_nev': 85},
        ),
      );
      final result = engine.maybeNpcStoryEvent();
      expect(result, contains('立誓'));
    });
  });

  group('Batch 10-13 指令接线', () {
    test('在场指令返回 NPC 列表', () {
      final engine = GameEngine()..startNewGame();
      final result = engine.resolveCommand('在场');
      expect(result.text, contains('在场人物'));
    });

    test('互动指令无参提示', () {
      final engine = GameEngine()..startNewGame();
      final result = engine.resolveCommand('互动');
      expect(result.text, contains('和谁互动'));
    });

    test('互动指令带名字执行', () {
      final engine = GameEngine()..startNewGame();
      final result = engine.resolveCommand('互动 艾德·史塔克');
      expect(result.text, isNotEmpty);
      expect(result.text, contains('艾德'));
    });

    test('示好指令带名字执行', () {
      final engine = GameEngine()..startNewGame();
      final result = engine.resolveCommand('示好 艾德·史塔克');
      expect(result.text, anyOf(contains('艾德'), contains('深谈')));
    });
  });
}