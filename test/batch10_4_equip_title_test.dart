/// Batch 10-4 测试：装备系统（武器/护甲/坐骑装备 + 战斗值）与头衔系统。
///
/// 覆盖：
/// 1. 装备/卸下/同槽位替换
/// 2. 战斗值计算（技能 + 装备加成）
/// 3. 不可装备物品拒绝
/// 4. 头衔晋升（按声望/身份）
/// 5. 月度结算触发晋升
/// 6. 指令接线（装备/卸下/装备栏/头衔）
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/models/player.dart';

void main() {
  group('Batch 10-4 装备系统', () {
    test('装备武器后 armed 标记生效', () {
      final e = GameEngine()..startNewGame();
      e.addItem('item_sword');
      final text = e.equip('item_sword');
      expect(text, contains('装备了'));
      expect(e.flagOf('equipped.item_sword'), true);
      expect(e.equippedItems, contains('item_sword'));
    });

    test('不可装备物品拒绝', () {
      final e = GameEngine()..startNewGame();
      e.addItem('item_bread');
      final text = e.equip('item_bread');
      expect(text, contains('不能装备'));
      expect(e.equippedItems, isEmpty);
    });

    test('未持有无法装备', () {
      final e = GameEngine()..startNewGame();
      final text = e.equip('item_sword');
      expect(text, contains('没有'));
    });

    test('同分类装备替换', () {
      final e = GameEngine()..startNewGame();
      e.addItem('item_sword');
      e.addItem('item_valyrian_dagger');
      e.equip('item_sword');
      e.equip('item_valyrian_dagger');
      expect(e.flagOf('equipped.item_sword'), false);
      expect(e.flagOf('equipped.item_valyrian_dagger'), true);
    });

    test('卸下装备', () {
      final e = GameEngine()..startNewGame();
      e.addItem('item_sword');
      e.equip('item_sword');
      final text = e.unequip('item_sword');
      expect(text, contains('卸下'));
      expect(e.flagOf('equipped.item_sword'), false);
    });

    test('战斗值随装备提升', () {
      final e = GameEngine()..startNewGame();
      final basePower = e.combatPower();
      e.addItem('item_sword');
      e.equip('item_sword');
      expect(e.combatPower(), greaterThan(basePower));
    });

    test('装备面板显示战斗值', () {
      final e = GameEngine()..startNewGame();
      e.addItem('item_sword');
      e.equip('item_sword');
      final panel = e.formatEquipmentPanel();
      expect(panel, contains('长剑'));
      expect(panel, contains('战斗值'));
    });
  });

  group('Batch 10-4 头衔系统', () {
    test('高声望士兵晋升骑士', () {
      final e = GameEngine()..startNewGame();
      // 默认平民身份；改为士兵
      e.updatePlayer(
        Player.defaultPlayer().copyWith(
          identity: PlayerIdentity.soldier,
          reputation: 55,
        ),
      );
      final title = e.checkTitlePromotion();
      expect(title, '骑士');
      expect(e.player.title, '骑士');
    });

    test('贵族高声望晋升大领主', () {
      final e = GameEngine()..startNewGame();
      e.updatePlayer(
        Player.defaultPlayer().copyWith(
          identity: PlayerIdentity.noble,
          reputation: 90,
        ),
      );
      final title = e.checkTitlePromotion();
      expect(title, '大领主');
    });

    test('低声望无头衔', () {
      final e = GameEngine()..startNewGame();
      e.updatePlayer(
        Player.defaultPlayer().copyWith(
          identity: PlayerIdentity.commoner,
          reputation: 10,
        ),
      );
      final title = e.checkTitlePromotion();
      expect(title, '');
      expect(e.player.title, '');
    });

    test('声望不足时不降级', () {
      final e = GameEngine()..startNewGame();
      e.updatePlayer(
        Player.defaultPlayer().copyWith(
          identity: PlayerIdentity.soldier,
          reputation: 60,
        ),
      );
      e.checkTitlePromotion();
      expect(e.player.title, '骑士');
      // 声望下降不收回
      e.updatePlayer(e.player.copyWith(reputation: 20));
      final title = e.checkTitlePromotion();
      expect(title, '');
      expect(e.player.title, '骑士');
    });

    test('月度结算触发晋升', () {
      final e = GameEngine()..startNewGame();
      e.updatePlayer(
        Player.defaultPlayer().copyWith(
          identity: PlayerIdentity.soldier,
          reputation: 55,
        ),
      );
      final text = e.advanceMonth();
      expect(text, contains('头衔'));
      expect(e.player.title, '骑士');
    });

    test('头衔面板显示晋升进度', () {
      final e = GameEngine()..startNewGame();
      e.updatePlayer(
        Player.defaultPlayer().copyWith(
          identity: PlayerIdentity.soldier,
          reputation: 40,
        ),
      );
      final panel = e.formatTitlePanel();
      expect(panel.contains('无名之辈') || panel.contains('当前'), true);
      expect(panel, contains('晋升'));
    });
  });

  group('Batch 10-4 指令接线', () {
    test('装备指令', () {
      final e = GameEngine()..startNewGame();
      e.addItem('item_sword');
      final result = e.resolveCommand('装备 长剑');
      expect(result.text, contains('装备了'));
      expect(e.flagOf('equipped.item_sword'), true);
    });

    test('卸下指令', () {
      final e = GameEngine()..startNewGame();
      e.addItem('item_sword');
      e.equip('item_sword');
      final result = e.resolveCommand('卸下 长剑');
      expect(result.text, contains('卸下'));
      expect(e.flagOf('equipped.item_sword'), false);
    });

    test('装备栏指令', () {
      final e = GameEngine()..startNewGame();
      final result = e.resolveCommand('装备栏');
      expect(result.text, contains('装备'));
    });

    test('头衔指令', () {
      final e = GameEngine()..startNewGame();
      final result = e.resolveCommand('头衔');
      expect(result.text, contains('头衔'));
    });
  });
}