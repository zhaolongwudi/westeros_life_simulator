/// Batch 10-3 测试：贸易系统（买卖定价 / 地点系数 / 指令接线）。
///
/// 覆盖：
/// 1. buyPriceOf/sellPriceOf 定价（地点系数、珍宝城市加成）
/// 2. buyItem/sellItem 买卖逻辑（金币/背包/数量）
/// 3. 地点限制（荒野不可买卖）
/// 4. 指令接线（购买/出售/行情）
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/models/location.dart';

void main() {
  group('Batch 10-3 定价', () {
    test('面包基础价值 2，城市买入价 2.2 取整', () {
      final e = GameEngine()..startNewGame();
      // 默认在临冬城（castle，系数 1.25）
      expect(e.buyPriceOf('item_bread'), (2 * 1.25).round());
      expect(e.sellPriceOf('item_bread'), (2 * 0.55).round());
    });

    test('城市珍宝收购价高于乡村', () {
      final e = GameEngine()..startNewGame();
      // 移动到城市
      e.updatePlayer(
        e.player.copyWith(locationId: 'location_kings_landing'),
      );
      final cityRubySell = e.sellPriceOf('item_ruby');
      // 移动到乡村
      e.updatePlayer(
        e.player.copyWith(locationId: 'location_barrowtowns'),
      );
      final villageRubySell = e.sellPriceOf('item_ruby');
      expect(cityRubySell, greaterThan(villageRubySell));
      // 城市红宝石卖价 = 200*0.8=160
      expect(cityRubySell, 160);
    });

    test('未知物品定价为 0', () {
      final e = GameEngine()..startNewGame();
      expect(e.buyPriceOf('item_nonexistent'), 0);
      expect(e.sellPriceOf('item_nonexistent'), 0);
    });
  });

  group('Batch 10-3 买卖', () {
    test('购买物品扣金币入背包', () {
      final e = GameEngine()..startNewGame();
      final goldBefore = e.player.gold;
      final price = e.buyPriceOf('item_bread');
      final text = e.buyItem('item_bread');
      expect(e.player.gold, goldBefore - price);
      expect(e.itemCount('item_bread'), 1);
      expect(text, contains('黑面包'));
    });

    test('金币不足无法购买', () {
      final e = GameEngine()..startNewGame();
      e.updatePlayer(e.player.copyWith(gold: 1));
      final text = e.buyItem('item_sword');
      expect(text, contains('买不起'));
      expect(e.itemCount('item_sword'), 0);
    });

    test('出售物品得金币移除背包', () {
      final e = GameEngine()..startNewGame();
      e.addItem('item_meat');
      final goldBefore = e.player.gold;
      final price = e.sellPriceOf('item_meat');
      final text = e.sellItem('item_meat');
      expect(e.player.gold, goldBefore + price);
      expect(e.itemCount('item_meat'), 0);
      expect(text, contains('烤肉'));
    });

    test('数量参数购买多件', () {
      final e = GameEngine()..startNewGame();
      final goldBefore = e.player.gold;
      final price = e.buyPriceOf('item_bread') * 3;
      e.buyItem('item_bread', 3);
      expect(e.player.gold, goldBefore - price);
      expect(e.itemCount('item_bread'), 3);
    });

    test('数量超过持有无法出售', () {
      final e = GameEngine()..startNewGame();
      e.addItem('item_meat');
      final text = e.sellItem('item_meat', 2);
      expect(text, contains('卖不了'));
      expect(e.itemCount('item_meat'), 1);
    });

    test('荒野无法买卖', () {
      // 用超自然类型地点模拟不可交易区
      final supLoc = Location(
        id: 'test_sup',
        name: '测试超自然',
        type: LocationType.supernatural,
        region: '未知',
        dangerLevel: 10,
        population: 0,
        features: const [],
        governorId: null,
        connectedTo: const [],
        description: '测试',
      );
      final locEngine = GameEngine(locations: [supLoc])..startNewGame();
      locEngine.updatePlayer(locEngine.player.copyWith(locationId: 'test_sup'));
      final buyText = locEngine.buyItem('item_bread');
      expect(buyText, contains('没有商贩'));
      final sellText = locEngine.sellItem('item_bread');
      expect(sellText, contains('没有收购'));
    });
  });

  group('Batch 10-3 行情面板与指令接线', () {
    test('行情面板显示价格', () {
      final e = GameEngine()..startNewGame();
      final panel = e.formatMarketPanel();
      expect(panel, contains('临冬城'));
      expect(panel, contains('黑面包'));
      expect(panel, contains('买 '));
      expect(panel, contains('卖 '));
    });

    test('购买指令接线', () {
      final e = GameEngine()..startNewGame();
      final result = e.resolveCommand('购买 黑面包');
      expect(result.text, contains('黑面包'));
      expect(e.itemCount('item_bread'), 1);
    });

    test('出售指令接线', () {
      final e = GameEngine()..startNewGame();
      e.addItem('item_wine');
      final result = e.resolveCommand('出售 葡萄酒');
      expect(result.text, contains('葡萄酒'));
      expect(e.itemCount('item_wine'), 0);
    });

    test('行情指令接线', () {
      final e = GameEngine()..startNewGame();
      final result = e.resolveCommand('行情');
      expect(result.text, contains('临冬城'));
    });

    test('未知物品购买提示', () {
      final e = GameEngine()..startNewGame();
      final result = e.resolveCommand('购买 龙蛋');
      expect(result.text, contains('买不到'));
    });
  });
}