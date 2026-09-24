/// Batch 4 测试：GameAdventureMixin（冒险混入）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/models/location.dart';
import 'package:westeros_life_simulator/models/player.dart';

void main() {
  group('GameAdventureMixin', () {
    test('travel 未开始拒绝', () {
      final engine = GameEngine();
      expect(engine.travel('location_white_harbor'), contains('尚未开始'));
    });

    test('travel 未知地点拒绝', () {
      final engine = GameEngine()..startNewGame();
      expect(engine.travel('nowhere'), contains('没有叫'));
    });

    test('travel 已在原地提示', () {
      final engine = GameEngine()..startNewGame();
      expect(engine.travel('location_winterfell'), contains('已经在这里'));
    });

    test('travel 未连接地点拒绝', () {
      final engine = GameEngine()..startNewGame();
      // 临冬城不直接连接君临
      final result = engine.travel('location_kings_landing');
      expect(result, contains('无法直接前往'));
      expect(result, contains('可前往'));
    });

    test('travel 前往相连地点成功', () {
      final engine = GameEngine()..startNewGame();
      // 临冬城 → 白港（connectedTo 包含）
      final before = engine.player.gold;
      final result = engine.travel('location_white_harbor');
      expect(result, contains('抵达'));
      expect(engine.player.locationId, 'location_white_harbor');
      expect(engine.player.gold, lessThan(before));
    });

    test('travel 金币不足拒绝', () {
      final engine = GameEngine(
        player: Player.defaultPlayer().copyWith(gold: 0),
        isGameActive: true,
      );
      expect(engine.travel('location_white_harbor'), contains('付不起'));
    });

    test('explore 未开始拒绝', () {
      final engine = GameEngine();
      expect(engine.explore(), contains('尚未开始'));
    });

    test('explore 正常执行（结果合法）', () {
      final engine = GameEngine()..startNewGame();
      final result = engine.explore();
      expect(result, contains('探索'));
      expect(engine.player.gold, greaterThanOrEqualTo(100));
    });

    test('explore 城市安全探索', () {
      final engine = GameEngine(
        player: Player.defaultPlayer().copyWith(locationId: 'location_kings_landing'),
        isGameActive: true,
      );
      final result = engine.explore();
      expect(result, contains('探索'));
    });

    test('formatTravelPanel 显示可前往地点', () {
      final engine = GameEngine()..startNewGame();
      final panel = engine.formatTravelPanel();
      expect(panel, contains('可前往'));
      expect(panel, contains('白港'));
    });

    test('formatTravelPanel 无连接地点', () {
      final engine = GameEngine(
        player: Player.defaultPlayer().copyWith(locationId: 'location_old_gods'),
        locations: [
          Location.defaultLocation().copyWith(
            id: 'location_old_gods',
            connectedTo: const [],
          ),
        ],
        isGameActive: true,
      );
      expect(engine.formatTravelPanel(), contains('没有可以前往'));
    });
  });
}