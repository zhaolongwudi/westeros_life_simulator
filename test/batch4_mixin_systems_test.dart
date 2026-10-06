/// Batch 4 测试：GameSystemsMixin（系统混入）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/models/player.dart';

void main() {
  group('GameSystemsMixin', () {
    test('系统总数 73（S3-4 删除重复的 system_succession_law）', () {
      final engine = GameEngine()..startNewGame();
      expect(engine.systemCount, 73);
    });

    test('systemsByCategory 按分类查询', () {
      final engine = GameEngine()..startNewGame();
      final war = engine.systemsByCategory('战争');
      expect(war, isNotEmpty);
      expect(war.every((s) => s.category == '战争'), true);
    });

    test('默认玩家（史塔克贵族）可接触家族系统', () {
      final engine = GameEngine()..startNewGame();
      final avail = engine.availableSystems();
      expect(avail.any((s) => s.category == '家族' || s.category == '封建'), true);
    });

    test('无面者身份可接触无面者系统', () {
      final engine = GameEngine(
        player: Player.defaultPlayer().copyWith(
          identity: PlayerIdentity.assassin,
        ),
        isGameActive: true,
      );
      final avail = engine.availableSystems();
      expect(avail.any((s) => s.category == '无面者'), true);
    });

    test('君临城居民可接触贸易/经济系统', () {
      final engine = GameEngine(
        player: Player.defaultPlayer().copyWith(locationId: 'location_kings_landing'),
        isGameActive: true,
      );
      final avail = engine.availableSystems();
      expect(avail.any((s) => s.category == '贸易' || s.category == '经济'), true);
    });

    test('长城守夜人可接触守夜人系统', () {
      final engine = GameEngine(
        player: Player.defaultPlayer().copyWith(locationId: 'location_the_wall'),
        isGameActive: true,
      );
      final avail = engine.availableSystems();
      expect(avail.any((s) => s.category == '守夜人'), true);
    });

    test('铁群岛居民可接触铁民/淹神系统', () {
      final engine = GameEngine(
        player: Player.defaultPlayer().copyWith(locationId: 'location_pike'),
        isGameActive: true,
      );
      final avail = engine.availableSystems();
      expect(avail.any((s) => s.category == '铁民' || s.category == '淹神'), true);
    });

    test('坦格利安可接触龙系统', () {
      final engine = GameEngine(
        player: Player.defaultPlayer().copyWith(familyId: 'family_targaryen'),
        isGameActive: true,
      );
      final avail = engine.availableSystems();
      expect(avail.any((s) => s.category == '龙'), true);
    });

    test('formatSystemsPanel 输出面板', () {
      final engine = GameEngine()..startNewGame();
      final panel = engine.formatSystemsPanel();
      expect(panel, contains('系统面板'));
      expect(panel, contains('已接触系统'));
    });

    test('applyMonthlySystems 家族收益', () {
      final engine = GameEngine()..startNewGame();
      final before = engine.player.gold;
      final text = engine.applyMonthlySystems(seed: 1);
      expect(engine.player.gold, greaterThan(before)); // 史塔克影响力>0
      expect(text, isNotEmpty);
    });

    test('applyMonthlySystems 未开始返回空', () {
      final engine = GameEngine();
      expect(engine.applyMonthlySystems(), '');
    });

    test('applyMonthlySystems 返回字符串且不崩溃', () {
      final engine = GameEngine(
        player: Player.defaultPlayer().copyWith(gold: 200),
        isGameActive: true,
      );
      expect(engine.applyMonthlySystems(seed: 1), isA<String>());
      expect(engine.player.gold, greaterThanOrEqualTo(200));
    });
  });
}