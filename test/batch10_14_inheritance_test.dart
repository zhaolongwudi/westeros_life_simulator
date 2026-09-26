/// Batch 10-14 测试：家族继承与多世代。
///
/// 覆盖：
/// 1. addChild：添加子女（家谱/子女列表）
/// 2. heirName：继承人选定（长子优先/死亡流放跳过）
/// 3. formatFamilyTree：家谱文本
/// 4. advanceGeneration：世代传承（金币/声望/技能继承 + 新玩家）
/// 5. advanceMonth：年长/濒死立嗣提示 + 死亡传承闭环
/// 6. 指令接线：家谱/立嗣 命令
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';

void main() {
  group('Batch 10-14 addChild', () {
    test('添加子女成功', () {
      final engine = GameEngine()..startNewGame();
      final result = engine.addChild('罗柏');
      expect(result, contains('罗柏'));
      expect(engine.player.children, contains('罗柏'));
      expect(engine.childNames, contains('罗柏'));
    });
    test('空名字返回提示', () {
      final engine = GameEngine()..startNewGame();
      expect(engine.addChild(''), contains('起个名字'));
    });
    test('重复子女返回提示', () {
      final engine = GameEngine()..startNewGame();
      engine.addChild('罗柏');
      expect(engine.addChild('罗柏'), contains('已经是'));
    });
    test('多子女按顺序', () {
      final engine = GameEngine()..startNewGame();
      engine.addChild('罗柏');
      engine.addChild('艾莉亚');
      expect(engine.childNames, ['罗柏', '艾莉亚']);
    });
  });

  group('Batch 10-14 heirName', () {
    test('长子优先', () {
      final engine = GameEngine()..startNewGame();
      engine.addChild('罗柏');
      engine.addChild('琼恩');
      expect(engine.heirName, '罗柏');
    });
    test('长子死亡则次子继承', () {
      final engine = GameEngine()..startNewGame();
      engine.addChild('罗柏');
      engine.addChild('琼恩');
      engine.setFlag('house.childDead.罗柏', true);
      expect(engine.heirName, '琼恩');
    });
    test('无子女返回 null', () {
      final engine = GameEngine()..startNewGame();
      expect(engine.heirName, isNull);
    });
  });

  group('Batch 10-14 formatFamilyTree', () {
    test('无子女显示尚无子嗣', () {
      final engine = GameEngine()..startNewGame();
      final text = engine.formatFamilyTree();
      expect(text, contains('尚无子嗣'));
      expect(text, contains('家主'));
    });
    test('有子女显示继承人与子女', () {
      final engine = GameEngine()..startNewGame();
      engine.addChild('罗柏');
      engine.addChild('艾莉亚');
      final text = engine.formatFamilyTree();
      expect(text, contains('罗柏'));
      expect(text, contains('艾莉亚'));
      expect(text, contains('继承人：罗柏'));
    });
  });

  group('Batch 10-14 advanceGeneration', () {
    test('有继承人切换新玩家并继承家业', () {
      final engine = GameEngine()..startNewGame();
      engine.addChild('罗柏');
      // 设定一些家业
      final rich = engine.player.copyWith(gold: 1000, reputation: 80);
      engine.updatePlayer(rich);
      final newPlayer = engine.advanceGeneration();
      expect(newPlayer, isNotNull);
      expect(newPlayer!.name, '罗柏');
      expect(newPlayer.age, 16);
      expect(newPlayer.gold, 500); // 一半
      expect(newPlayer.reputation, 40); // 折半
      expect(newPlayer.flags['inherited'], true);
      expect(newPlayer.flags['generation'], true);
      expect(engine.generationNumber(), 2);
    });
    test('无继承人返回 null', () {
      final engine = GameEngine()..startNewGame();
      expect(engine.advanceGeneration(), isNull);
    });
    test('技能继承 60%', () {
      final engine = GameEngine()..startNewGame();
      engine.addChild('罗柏');
      final skilled = engine.player.copyWith(
        skills: const <String, int>{'sword': 8, 'speech': 5},
      );
      engine.updatePlayer(skilled);
      final newPlayer = engine.advanceGeneration()!;
      expect(newPlayer.skills['sword'], 5); // 8*0.6=4.8→5
      expect(newPlayer.skills['speech'], 3); // 5*0.6=3
    });
  });

  group('Batch 10-14 advanceMonth 死亡传承', () {
    test('年长有继承人时提示立嗣', () {
      final engine = GameEngine()..startNewGame();
      engine.addChild('罗柏');
      final elder = engine.player.copyWith(age: 60);
      engine.updatePlayer(elder);
      final result = engine.advanceMonth();
      expect(result, contains('传承'));
    });
    test('濒死有继承人时提示', () {
      final engine = GameEngine()..startNewGame();
      engine.addChild('罗柏');
      final dying = engine.player.copyWith(health: 10);
      engine.updatePlayer(dying);
      final result = engine.advanceMonth();
      expect(result, contains('每况愈下'));
    });
    test('死亡有继承人则传承继续', () {
      final engine = GameEngine()..startNewGame();
      engine.addChild('罗柏');
      // 模拟死亡：健康归零
      final dying = engine.player.copyWith(
        health: 0,
        flags: <String, bool>{...engine.player.flags, 'isAlive': false},
      );
      engine.updatePlayer(dying);
      final result = engine.advanceMonth();
      expect(result, contains('血脉延续'));
      expect(engine.player.name, '罗柏');
      expect(engine.isGameOver, false);
      expect(engine.isGameActive, true);
    });
    test('死亡无继承人则血脉断绝', () {
      final engine = GameEngine()..startNewGame();
      final dying = engine.player.copyWith(
        health: 0,
        flags: <String, bool>{...engine.player.flags, 'isAlive': false},
      );
      engine.updatePlayer(dying);
      final result = engine.advanceMonth();
      expect(result, contains('血脉随你一同断绝'));
      expect(engine.isGameOver, true);
    });
  });

  group('Batch 10-14 指令接线', () {
    test('家谱指令返回家谱', () {
      final engine = GameEngine()..startNewGame();
      engine.addChild('罗柏');
      final result = engine.resolveCommand('家谱');
      expect(result.text, contains('家谱'));
      expect(result.text, contains('罗柏'));
    });
    test('立嗣指令无参提示', () {
      final engine = GameEngine()..startNewGame();
      final result = engine.resolveCommand('立嗣');
      expect(result.text, contains('起个名字'));
    });
    test('立嗣指令带名字执行', () {
      final engine = GameEngine()..startNewGame();
      final result = engine.resolveCommand('立嗣 罗柏');
      expect(result.text, contains('罗柏'));
      expect(engine.player.children, contains('罗柏'));
    });
  });
}