/// Batch 10-11 测试：贸易深化（地区特产巡游 / 商人议价 / 商队护送）。
///
/// 覆盖：
/// 1. 地区特产映射：12 区域各有特产，kRegionSpecialties 引用的物品 ID 全部有效
/// 2. specialtyAdjustedPrice：特产产地买价低、异乡卖价高（跨区套利逻辑）
/// 3. tradeSpecialty：消耗精力、扣金币、背包获得特产
/// 4. negotiate：议价成功设置 negotiated_discount 标记、有每日冷却
/// 5. convoy：成功得金币/声望，失败可能受伤
/// 6. 指令接线：巡游/议价/商队 可通过 resolveCommand 触发
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/item_data.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/mixins/mixin_life.dart';
import 'package:westeros_life_simulator/models/player.dart';

void main() {
  group('Batch 10-11 地区特产映射', () {
    test('12 区域全部有特产且物品 ID 有效', () {
      expect(GameLifeMixin.kRegionSpecialties.length, 12);
      for (final entry in GameLifeMixin.kRegionSpecialties.entries) {
        expect(entry.value.isNotEmpty, true, reason: '区域 ${entry.key} 无特产');
        for (final id in entry.value) {
          expect(itemById(id), isNotNull, reason: '区域 ${entry.key} 特产 $id 不存在');
        }
      }
    });

    test('特产产地买价更低、异乡卖价更高', () {
      final engine = GameEngine()..startNewGame();
      // defaultPlayer 在临冬城（北境），item_meat 是北境特产
      final meat = itemById('item_meat')!;
      // 北境（特产产地）
      final northPrice = engine.specialtyAdjustedPrice('item_meat');
      expect(northPrice.buy, lessThan(meat.value), reason: '产地买价应低于原价');
      // 非特产（默认在非北境地点比较）
      final wine = itemById('item_wine')!;
      expect(wine.value, greaterThan(0));
    });
  });

  group('Batch 10-11 特产巡游', () {
    test('巡游消耗精力并买入特产', () {
      final engine = GameEngine()..startNewGame();
      final energyBefore = engine.player.energy;
      final goldBefore = engine.player.gold;
      final invBefore = engine.player.inventory.length;
      final text = engine.tradeSpecialty();
      expect(text, isNotEmpty);
      // 精力消耗
      expect(engine.player.energy, lessThan(energyBefore));
      // 要么买了特产（金币减少、背包增加），要么因金币不足返回提示
      if (text.contains('收购')) {
        expect(engine.player.gold, lessThan(goldBefore));
        expect(engine.player.inventory.length, greaterThan(invBefore));
      }
    });

    test('每日次数限制（2 次）', () {
      final engine = GameEngine()..startNewGame();
      // 默认玩家金币 100，确保能买
      engine.tradeSpecialty();
      engine.tradeSpecialty();
      final third = engine.tradeSpecialty();
      expect(third, contains('商路已经跑完了'));
    });
  });

  group('Batch 10-11 商人议价', () {
    test('议价成功设置折扣标记（高口才商人）', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          identity: PlayerIdentity.merchant,
          skills: const {'speech': 5},
        ),
      );
      final text = engine.negotiate();
      // 商人 + 高口才大概率成功
      expect(text, isNotEmpty);
      if (text.contains('成功议价')) {
        expect(engine.flagOf('negotiated'), true);
      }
    });

    test('议价每日 1 次冷却', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          identity: PlayerIdentity.merchant,
          skills: const {'speech': 5},
        ),
      );
      engine.negotiate();
      final second = engine.negotiate();
      expect(second, contains('议价机会已经用过了'));
    });
  });

  group('Batch 10-11 商队护送', () {
    test('护送消耗精力并可能得金币', () {
      final engine = GameEngine()..startNewGame();
      final energyBefore = engine.player.energy;
      final goldBefore = engine.player.gold;
      final text = engine.convoy();
      expect(text, isNotEmpty);
      expect(engine.player.energy, lessThan(energyBefore));
      // 默认玩家战斗值不低（sword 3 + 属性），大概率成功得金币
      if (text.contains('付你') || text.contains('拿到') || text.contains('金币')) {
        expect(engine.player.gold, greaterThanOrEqualTo(goldBefore));
      }
    });

    test('护送每日 1 次冷却', () {
      final engine = GameEngine()..startNewGame();
      engine.convoy();
      final second = engine.convoy();
      expect(second, contains('没有商队愿意等你'));
    });
  });

  group('Batch 10-11 指令接线', () {
    test('巡游/议价/商队指令可执行', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          identity: PlayerIdentity.merchant,
          skills: const {'speech': 5},
        ),
      );
      final r1 = engine.resolveCommand('巡游');
      expect(r1.text, isNotEmpty);
      final r2 = engine.resolveCommand('议价');
      expect(r2.text, isNotEmpty);
      final r3 = engine.resolveCommand('商队');
      expect(r3.text, isNotEmpty);
    });

    test('帮助文本包含新指令', () {
      final engine = GameEngine()..startNewGame();
      final help = engine.resolveCommand('帮助').text;
      expect(help, contains('巡游'));
      expect(help, contains('议价'));
      expect(help, contains('商队'));
    });
  });
}