/// Batch 10-25 测试：婚姻系统二轮。
///
/// 覆盖：
/// 1. SpouseDetail.affection：序列化往返默认值 50（旧存档兼容）
/// 2. 配偶谈心 spouseChat：身世话题回应 + 感情增长 + 每日限次
/// 3. 离婚 divorce：满一年可离/补偿金币/声望损失/当年不可再婚/不足一年拒绝/金币不足拒绝
/// 4. 丧偶 spousePassesAway：解除婚姻/贵族声望损失/未婚提示
/// 5. 婚后月度事件 maybeSpouseMonthlyEvent：按身世触发/恩爱加成/未婚空串
/// 6. 婚姻面板 formatMarriagePanel：配偶/感情/子女培养展示
/// 7. 指令接线：婚姻/私语/离婚/丧偶
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/models/marital.dart';

void main() {
  group('Batch 10-25 SpouseDetail.affection 序列化', () {
    test('默认感情 50（旧存档兼容）', () {
      final s = SpouseDetail(name: '梅拉', origin: SpouseOrigin.commoner, marriedYear: 283);
      expect(s.affection, 50);
      final restored = SpouseDetail.fromJson(s.toJson());
      expect(restored.affection, 50);
    });
    test('自定义感情往返一致', () {
      final s = SpouseDetail(
        name: '梅拉',
        origin: SpouseOrigin.commoner,
        marriedYear: 283,
        affection: 80,
      );
      final restored = SpouseDetail.fromJson(s.toJson());
      expect(restored.affection, 80);
    });
  });

  group('Batch 10-25 spouseChat 配偶谈心', () {
    test('未婚提示先成婚', () {
      final engine = GameEngine()..startNewGame();
      final result = engine.spouseChat('家常');
      expect(result, contains('尚未成婚'));
    });
    test('谈心按话题回应并提升感情', () {
      final engine = GameEngine()..startNewGame();
      engine.marry('平民');
      final before = engine.player.spouse!.affection;
      final result = engine.spouseChat('家常');
      expect(result, contains('感情'));
      expect(engine.player.spouse!.affection, greaterThan(before));
    });
    test('贵族谈朝局有专属回应', () {
      final engine = GameEngine()..startNewGame();
      engine.marry('贵族');
      final result = engine.spouseChat('朝局');
      // 坑 18：测试断言不能用 || 组合 Matcher，改用 anyOf
      expect(result, anyOf(contains('朝局'), contains('铁王座'), contains('家徽')));
    });
    test('每日限 2 次', () {
      final engine = GameEngine()..startNewGame();
      engine.marry('平民');
      engine.spouseChat('家常');
      engine.spouseChat('家常');
      final third = engine.spouseChat('家常');
      expect(third, contains('知心话'));
    });
  });

  group('Batch 10-25 divorce 离婚', () {
    test('不足一年拒绝离婚', () {
      final engine = GameEngine()..startNewGame();
      engine.marry('平民');
      // 默认 283 年成婚，同年即不足一年
      final result = engine.divorce();
      expect(result, contains('不足一年'));
      expect(engine.isMarried, true);
    });
    test('满一年可离婚并清空配偶', () {
      final engine = GameEngine()..startNewGame();
      engine.marry('平民');
      // 推进一年（283年3月 -> 284年3月 需过 12 个月；直接改进度年份验证逻辑）
      engine.updatePlayer(engine.player.copyWith(gold: engine.player.gold + 100));
      // 直接推进 12 个月
      for (var i = 0; i < 12; i++) {
        engine.advanceMonth();
      }
      // 现在应为 284 年，结婚满一年
      expect(engine.progress.year, 284);
      final goldBefore = engine.player.gold;
      final result = engine.divorce();
      expect(result, contains('和离'));
      expect(engine.isMarried, false);
      expect(engine.player.spouse, isNull);
      expect(engine.player.gold, lessThan(goldBefore));
    });
    test('离婚后当年不可再婚', () {
      final engine = GameEngine()..startNewGame();
      engine.marry('平民');
      // 推进一年
      for (var i = 0; i < 12; i++) {
        engine.advanceMonth();
      }
      engine.divorce();
      final remarried = engine.marry('平民');
      expect(remarried, contains('名声未复'));
      expect(engine.isMarried, false);
    });
    test('离婚满一年后可以再婚', () {
      final engine = GameEngine()..startNewGame();
      engine.marry('平民');
      // 推进一年后离婚
      for (var i = 0; i < 12; i++) {
        engine.advanceMonth();
      }
      engine.divorce();
      expect(engine.flagOf('divorceYear'), true);
      // 再推进一年（跨年时 maybeClearDivorceFlag 清除标记）
      for (var i = 0; i < 12; i++) {
        engine.advanceMonth();
      }
      expect(engine.flagOf('divorceYear'), false);
      final remarried = engine.marry('平民');
      expect(remarried, contains('成婚'));
      expect(engine.isMarried, true);
    });
    test('金币不足拒绝离婚', () {
      final engine = GameEngine()..startNewGame();
      engine.marry('平民');
      // 推进一年
      for (var i = 0; i < 12; i++) {
        engine.advanceMonth();
      }
      engine.updatePlayer(engine.player.copyWith(gold: 5));
      final result = engine.divorce();
      expect(result, contains('囊中羞涩'));
      expect(engine.isMarried, true);
    });
    test('未婚离婚提示', () {
      final engine = GameEngine()..startNewGame();
      final result = engine.divorce();
      expect(result, contains('尚未成婚'));
    });
  });

  group('Batch 10-25 spousePassesAway 丧偶', () {
    test('丧偶解除婚姻', () {
      final engine = GameEngine()..startNewGame();
      engine.marry('平民');
      final result = engine.spousePassesAway();
      expect(result, contains('长逝'));
      expect(engine.isMarried, false);
      expect(engine.player.spouse, isNull);
      expect(engine.flagOf('widowed'), true);
    });
    test('贵族丧偶声望损失', () {
      final engine = GameEngine()..startNewGame();
      engine.marry('贵族');
      final repBefore = engine.player.reputation;
      engine.spousePassesAway();
      expect(engine.player.reputation, lessThan(repBefore));
    });
    test('未婚丧偶提示', () {
      final engine = GameEngine()..startNewGame();
      final result = engine.spousePassesAway();
      expect(result, contains('并无配偶'));
    });
  });

  group('Batch 10-25 maybeSpouseMonthlyEvent 婚后月度事件', () {
    test('未婚返回空串', () {
      final engine = GameEngine()..startNewGame();
      expect(engine.maybeSpouseMonthlyEvent(seed: 1), '');
    });
    test('已婚按身世触发（商人得金币）', () {
      final engine = GameEngine()..startNewGame();
      engine.marry('商人');
      // 扫 seed 找到必触发者（避免概率断言不稳定）
      String? hit;
      for (var seed = 0; seed < 50; seed++) {
        final e = GameEngine()..startNewGame();
        e.marry('商人');
        final r = e.maybeSpouseMonthlyEvent(seed: seed);
        if (r.isNotEmpty) {
          hit = r;
          expect(e.player.gold, greaterThan(100)); // 商人事件给金币（基础 100 + 15/25）
          break;
        }
      }
      expect(hit, isNotNull);
    });
    test('贵族事件提升声望', () {
      final engine = GameEngine()..startNewGame();
      engine.marry('贵族');
      final repBefore = engine.player.reputation;
      String? hit;
      for (var seed = 0; seed < 50; seed++) {
        final e = GameEngine()..startNewGame();
        e.marry('贵族');
        final r = e.maybeSpouseMonthlyEvent(seed: seed);
        if (r.isNotEmpty) {
          hit = r;
          expect(e.player.reputation, greaterThan(repBefore));
          break;
        }
      }
      expect(hit, isNotNull);
    });
  });

  group('Batch 10-25 formatMarriagePanel 婚姻面板', () {
    test('未婚显示未婚提示', () {
      final engine = GameEngine()..startNewGame();
      final text = engine.formatMarriagePanel();
      expect(text, contains('未婚'));
    });
    test('已婚显示配偶与感情', () {
      final engine = GameEngine()..startNewGame();
      engine.marry('平民');
      final text = engine.formatMarriagePanel();
      expect(text, contains('配偶'));
      expect(text, contains('感情'));
      expect(text, contains('50/100'));
    });
    test('有子女显示培养档案', () {
      final engine = GameEngine()..startNewGame();
      engine.marry('平民');
      engine.addChild('罗柏');
      engine.rearChild('罗柏', 'sword');
      final text = engine.formatMarriagePanel();
      expect(text, contains('罗柏'));
      // S12-12：回显已中文化（原断言锁的是英文键回显这一缺陷本身）。
      expect(text, contains('剑术'));
    });
  });

  group('Batch 10-25 指令接线', () {
    test('婚姻指令', () {
      final engine = GameEngine()..startNewGame();
      final result = engine.resolveCommand('婚姻');
      expect(result.text, contains('未婚'));
    });
    test('私语指令', () {
      final engine = GameEngine()..startNewGame();
      engine.marry('平民');
      final result = engine.resolveCommand('私语 家常');
      expect(result.text, contains('感情'));
    });
    test('离婚指令', () {
      final engine = GameEngine()..startNewGame();
      engine.marry('平民');
      // 推进一年
      for (var i = 0; i < 12; i++) {
        engine.advanceMonth();
      }
      final result = engine.resolveCommand('离婚');
      expect(result.text, contains('和离'));
      expect(engine.isMarried, false);
    });
    test('丧偶指令', () {
      final engine = GameEngine()..startNewGame();
      engine.marry('平民');
      final result = engine.resolveCommand('丧偶');
      expect(result.text, contains('长逝'));
      expect(engine.isMarried, false);
    });
  });
}
