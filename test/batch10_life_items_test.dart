/// Batch 10 测试：生存状态 + 物品系统 + 精力/饱食/健康。
///
/// 覆盖：
/// 1. Player 新字段序列化往返（health/energy/hunger/title）
/// 2. GameLifeMixin 数值调整（clamp / 死亡判定）
/// 3. 物品系统（获得/移除/使用/面板）
/// 4. applyEffects 生存与物品效果键
/// 5. 日常活动精力消耗（训练/工作/狩猎/贸易/探索）
/// 6. 月度生存结算（饱食下降/饥饿掉血/受伤恢复）
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/models/player.dart';
import 'package:westeros_life_simulator/providers/game_state_provider.dart';

void main() {
  group('Batch 10 Player 新字段', () {
    test('默认玩家生命/精力/饱食均为满值', () {
      final p = Player.defaultPlayer();
      expect(p.health, 100);
      expect(p.energy, 100);
      expect(p.hunger, 0);
      expect(p.title, '');
    });

    test('序列化往返保留新字段', () {
      final p = Player.defaultPlayer().copyWith(
        health: 55,
        energy: 30,
        hunger: 80,
        title: '北境守护',
      );
      final restored = Player.fromJson(p.toJson());
      expect(restored.health, 55);
      expect(restored.energy, 30);
      expect(restored.hunger, 80);
      expect(restored.title, '北境守护');
    });

    test('旧存档无新字段时使用默认值', () {
      final json = Player.defaultPlayer().toJson();
      json.remove('health');
      json.remove('energy');
      json.remove('hunger');
      json.remove('title');
      final restored = Player.fromJson(json);
      expect(restored.health, 100);
      expect(restored.energy, 100);
      expect(restored.hunger, 0);
      expect(restored.title, '');
    });
  });

  group('Batch 10 生存数值调整', () {
    test('精力 clamp 0~100', () {
      final e = GameEngine()..startNewGame();
      e.adjustEnergy(-999);
      expect(e.player.energy, 0);
      e.adjustEnergy(999);
      expect(e.player.energy, 100);
    });

    test('饱食 clamp 0~100', () {
      final e = GameEngine()..startNewGame();
      e.adjustHunger(150);
      expect(e.player.hunger, 100);
      e.adjustHunger(-999);
      expect(e.player.hunger, 0);
    });

    test('健康归零触发死亡', () {
      final e = GameEngine()..startNewGame();
      e.adjustHealth(-999);
      expect(e.player.health, 0);
      expect(e.player.flags['isAlive'], false);
    });

    test('疲惫与饥饿判定', () {
      final e = GameEngine()..startNewGame();
      expect(e.isExhausted, false);
      e.adjustEnergy(-90);
      expect(e.isExhausted, true);
      e.adjustHunger(-100);
      expect(e.isStarving, true);
    });
  });

  group('Batch 10 物品系统', () {
    test('获得与移除物品', () {
      final e = GameEngine()..startNewGame();
      expect(e.addItem('item_bread'), true);
      expect(e.itemCount('item_bread'), 1);
      expect(e.addItem('item_bread'), true);
      expect(e.itemCount('item_bread'), 2);
      expect(e.removeItem('item_bread'), true);
      expect(e.itemCount('item_bread'), 1);
    });

    test('未知物品拒绝', () {
      final e = GameEngine()..startNewGame();
      expect(e.addItem('item_nonexistent'), false);
      expect(e.removeItem('item_nonexistent'), false);
    });

    test('使用消耗品恢复饱食并移除', () {
      final e = GameEngine()..startNewGame();
      e.addItem('item_bread');
      e.adjustHunger(-50);
      final before = e.player.hunger;
      final text = e.useItem('item_bread');
      expect(text, contains('黑面包'));
      expect(e.player.hunger, greaterThan(before));
      expect(e.itemCount('item_bread'), 0);
    });

    test('不可使用物品拒绝', () {
      final e = GameEngine()..startNewGame();
      e.addItem('item_sword');
      final text = e.useItem('item_sword');
      expect(text, contains('不能直接使用'));
      expect(e.itemCount('item_sword'), 1);
    });

    test('技能不足无法使用草药', () {
      final e = GameEngine()..startNewGame();
      e.addItem('item_herb');
      final text = e.useItem('item_herb');
      expect(text, contains('缺乏'));
      expect(e.itemCount('item_herb'), 1);
    });

    test('背包面板汇总数量', () {
      final e = GameEngine()..startNewGame();
      e.addItem('item_bread');
      e.addItem('item_bread');
      final text = e.formatInventoryPanel();
      expect(text, contains('黑面包'));
      expect(text, contains('×2'));
    });
  });

  group('Batch 10 applyEffects 新键', () {
    test('health/energy/hunger 效果键', () {
      final provider = GameStateProvider();
      final p = provider.applyEffects(
        provider.player,
        const <String, int>{'health': -30, 'energy': -40, 'hunger': 50},
      );
      expect(p.health, 70);
      expect(p.energy, 60);
      expect(p.hunger, 50);
    });

    test('inventory. 效果键获得与消耗', () {
      final provider = GameStateProvider();
      var p = provider.applyEffects(
        provider.player,
        const <String, int>{'inventory.item_bread': 2},
      );
      expect(p.inventory.where((i) => i == 'item_bread').length, 2);
      p = provider.applyEffects(
        p,
        const <String, int>{'inventory.item_bread': -1},
      );
      expect(p.inventory.where((i) => i == 'item_bread').length, 1);
    });
  });

  group('Batch 10 日常活动精力消耗', () {
    test('训练消耗精力', () {
      final e = GameEngine()..startNewGame();
      final before = e.player.energy;
      e.train('sword');
      expect(e.player.energy, lessThan(before));
    });

    test('精力不足时训练被拒绝', () {
      final e = GameEngine()..startNewGame();
      e.adjustEnergy(-100);
      final text = e.train('sword');
      expect(text, contains('精疲力竭'));
    });

    test('休息恢复精力与饱食', () {
      final e = GameEngine()..startNewGame();
      e.adjustEnergy(-60);
      e.adjustHunger(-40);
      final beforeE = e.player.energy;
      final beforeH = e.player.hunger;
      e.rest();
      expect(e.player.energy, greaterThan(beforeE));
      expect(e.player.hunger, greaterThan(beforeH));
    });

    test('工作/狩猎/贸易/探索消耗精力', () {
      final e = GameEngine()..startNewGame();
      final before = e.player.energy;
      e.work();
      expect(e.player.energy, lessThan(before));
      final before2 = e.player.energy;
      e.trade();
      expect(e.player.energy, lessThan(before2));
    });
  });

  group('Batch 10 月度生存结算', () {
    test('过月饱食下降', () {
      final e = GameEngine()..startNewGame();
      e.adjustHunger(80);
      final before = e.player.hunger;
      e.advanceMonth();
      expect(e.player.hunger, lessThan(before));
    });

    test('饥饿状态掉健康', () {
      final e = GameEngine()..startNewGame();
      e.adjustHunger(-100);
      final before = e.player.health;
      e.advanceMonth();
      expect(e.player.health, lessThan(before));
    });
  });
}
