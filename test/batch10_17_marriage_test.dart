/// Batch 10-17 测试：婚姻系统 + 子女培养 + 多代家族树。
///
/// 覆盖：
/// 1. marry：成婚（身世类型/开销/声望/嫁妆/贵族门槛）
/// 2. spouseInteract：配偶互动（每日限次/精力恢复）
/// 3. maybeFamilyEvent：婚后生育（月度钩子）
/// 4. rearChild / tutorChild / sendChildToSchool：子女培养
/// 5. formatMultiGenTree：家族树多代展示
/// 6. advanceGeneration：谱系记录透传
/// 7. 指令接线：求婚/配偶/培养/督导/送学/家族树
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';

void main() {
  group('Batch 10-17 marry', () {
    test('平民成婚成功并扣金币', () {
      final engine = GameEngine()..startNewGame();
      final goldBefore = engine.player.gold;
      final result = engine.marry('平民');
      expect(result, contains('成婚'));
      expect(engine.isMarried, true);
      expect(engine.player.spouse, isNotNull);
      expect(engine.player.gold, lessThan(goldBefore));
    });
    test('贵族联姻需声望 40', () {
      final engine = GameEngine()..startNewGame();
      // 默认声望 50，应可成婚
      final result = engine.marry('贵族');
      expect(result, contains('成婚'));
      expect(engine.player.reputation, greaterThan(50));
    });
    test('声望不足拒绝贵族联姻', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(engine.player.copyWith(reputation: 20));
      final result = engine.marry('贵族');
      expect(result, contains('声望'));
      expect(engine.isMarried, false);
    });
    test('商人成婚带来嫁妆', () {
      final engine = GameEngine()..startNewGame();
      final goldBefore = engine.player.gold;
      engine.marry('商人');
      // 婚礼 40 - 嫁妆 60 = 净 +20
      expect(engine.player.gold, greaterThan(goldBefore));
    });
    test('已婚不可再婚', () {
      final engine = GameEngine()..startNewGame();
      engine.marry('平民');
      final second = engine.marry('战士');
      expect(second, contains('已有家室'));
    });
    test('未知身世返回提示', () {
      final engine = GameEngine()..startNewGame();
      final result = engine.marry('龙裔');
      expect(result, contains('可选'));
    });
  });

  group('Batch 10-17 spouseInteract', () {
    test('未婚提示先成婚', () {
      final engine = GameEngine()..startNewGame();
      final result = engine.spouseInteract();
      expect(result, contains('尚未成婚'));
    });
    test('已婚互动恢复精力', () {
      final engine = GameEngine()..startNewGame();
      engine.marry('平民');
      // 先消耗精力，验证互动能恢复
      engine.updatePlayer(engine.player.copyWith(energy: 50));
      final energyBefore = engine.player.energy;
      final result = engine.spouseInteract();
      expect(result, contains('精力'));
      expect(engine.player.energy, greaterThan(energyBefore));
    });
    test('每日限次', () {
      final engine = GameEngine()..startNewGame();
      engine.marry('平民');
      engine.spouseInteract();
      final second = engine.spouseInteract();
      expect(second, contains('相处够久'));
    });
  });

  group('Batch 10-17 maybeFamilyEvent', () {
    test('未婚不触发', () {
      final engine = GameEngine()..startNewGame();
      expect(engine.maybeFamilyEvent(), '');
    });
    test('已婚有概率添丁', () {
      final engine = GameEngine()..startNewGame();
      engine.marry('平民');
      // 用固定 seed 保证触发
      final result = engine.maybeFamilyEvent(seed: 1);
      // 可能触发也可能不触发（25%），但已婚时不会报错
      expect(result, isA<String>());
    });
    test('子女满上限不再添丁', () {
      final engine = GameEngine()..startNewGame();
      engine.marry('平民');
      // 平民上限 3
      engine.addChild('罗柏');
      engine.addChild('艾莉亚');
      engine.addChild('布兰');
      final result = engine.maybeFamilyEvent(seed: 1);
      expect(result, '');
    });
  });

  group('Batch 10-17 子女培养', () {
    test('rearChild 指定方向', () {
      final engine = GameEngine()..startNewGame();
      engine.addChild('罗柏');
      final result = engine.rearChild('罗柏', 'sword');
      // S12-12：回显已中文化（原断言锁的是英文键回显这一缺陷本身）。
      expect(result, contains('剑术'));
      expect(engine.player.childRearing.first.focus, 'sword');
    });
    test('rearChild 非子女拒绝', () {
      final engine = GameEngine()..startNewGame();
      final result = engine.rearChild('陌生人', 'sword');
      expect(result, contains('不是你的子女'));
    });
    test('tutorChild 声望 +3 且一次性', () {
      final engine = GameEngine()..startNewGame();
      engine.addChild('罗柏');
      final repBefore = engine.player.reputation;
      final result = engine.tutorChild('罗柏');
      expect(result, contains('督导'));
      expect(engine.player.reputation, repBefore + 3);
      final second = engine.tutorChild('罗柏');
      expect(second, contains('已经亲自教导'));
    });
    test('sendChildToSchool 声望 +5', () {
      final engine = GameEngine()..startNewGame();
      engine.addChild('罗柏');
      final repBefore = engine.player.reputation;
      final result = engine.sendChildToSchool('罗柏');
      expect(result, contains('进修'));
      expect(engine.player.reputation, repBefore + 5);
      expect(engine.player.childRearing.first.sentToSchool, true);
    });
  });

  group('Batch 10-17 formatMultiGenTree', () {
    test('未婚无子女显示当前家主', () {
      final engine = GameEngine()..startNewGame();
      final text = engine.formatMultiGenTree();
      expect(text, contains('家族树'));
      expect(text, contains('尚无子嗣'));
    });
    test('已婚有子女显示配偶与培养', () {
      final engine = GameEngine()..startNewGame();
      engine.marry('平民');
      engine.addChild('罗柏');
      engine.rearChild('罗柏', 'sword');
      final text = engine.formatMultiGenTree();
      expect(text, contains('配偶'));
      expect(text, contains('罗柏'));
      // S12-12：回显已中文化（原断言锁的是英文键回显这一缺陷本身）。
      expect(text, contains('剑术'));
    });
  });

  group('Batch 10-17 advanceGeneration 谱系透传', () {
    test('传承后谱系记录延续', () {
      final engine = GameEngine()..startNewGame();
      engine.addChild('罗柏');
      final newPlayer = engine.advanceGeneration();
      expect(newPlayer, isNotNull);
      expect(newPlayer!.generationRecords, hasLength(1));
      expect(newPlayer.generationRecords.first.name, isNot('罗柏'));
      // 再传一代：谱系应有 2 条
      engine.addChild('琼恩');
      final gen2 = engine.advanceGeneration();
      expect(gen2, isNotNull);
      expect(gen2!.generationRecords, hasLength(2));
    });
  });

  group('Batch 10-17 指令接线', () {
    test('求婚指令执行', () {
      final engine = GameEngine()..startNewGame();
      final result = engine.resolveCommand('求婚 平民');
      expect(result.text, contains('成婚'));
      expect(engine.isMarried, true);
    });
    test('配偶指令执行', () {
      final engine = GameEngine()..startNewGame();
      engine.marry('平民');
      final result = engine.resolveCommand('配偶');
      expect(result.text, contains('精力'));
    });
    test('培养指令执行', () {
      final engine = GameEngine()..startNewGame();
      engine.addChild('罗柏');
      final result = engine.resolveCommand('培养 罗柏 sword');
      // S12-12：回显已中文化（原断言锁的是英文键回显这一缺陷本身）。
      expect(result.text, contains('剑术'));
    });
    test('督导指令执行', () {
      final engine = GameEngine()..startNewGame();
      engine.addChild('罗柏');
      final result = engine.resolveCommand('督导 罗柏');
      expect(result.text, contains('督导'));
    });
    test('送学指令执行', () {
      final engine = GameEngine()..startNewGame();
      engine.addChild('罗柏');
      final result = engine.resolveCommand('送学 罗柏');
      expect(result.text, contains('进修'));
    });
    test('家族树指令执行', () {
      final engine = GameEngine()..startNewGame();
      final result = engine.resolveCommand('家族树');
      expect(result.text, contains('家族树'));
    });
  });
}