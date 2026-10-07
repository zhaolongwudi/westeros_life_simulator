/// Batch 4 测试：GamePlayMixin（日常玩法）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/models/location.dart';
import 'package:westeros_life_simulator/models/player.dart';

void main() {
  group('GamePlayMixin', () {
    test('train 训练技能（成功或失败都在合法范围）', () {
      final engine = GameEngine()..startNewGame();
      final before = engine.player.skills['sword']!;
      final result = engine.train('sword');
      expect(result, contains('sword'));
      expect(engine.player.skills['sword']!, inInclusiveRange(before, before + 1));
    });

    test('train 未知技能拒绝', () {
      final engine = GameEngine()..startNewGame();
      // 【S4-3c 换例子的原因】本用例原先拿 `magic` 当「未知技能」的样本，
      // 但 S4-3c 为让 3 个 `skills.magic` 门槛选项可达，已把 `'magic': 0`
      // 加进玩家初始技能表（与 `'alchemy': 0` 同先例）。契约不变——「玩家
      // 技能表里没有的技能仍必须被拒」——只是样本得换成真正未知的键。
      // 这也正是本批刻意**不删测试**的地方：要锁的是意图，不是旧字面量。
      expect(engine.player.skills.containsKey('magic'), isTrue,
          reason: '前提：magic 已在初始技能表内（S4-3c），不能再当未知技能样本');
      expect(engine.train('necromancy'), contains('从未学过'));
      // 白名单内但玩家未学的键同样拒绝——门槛「可达」不等于「人人可学」
      expect(engine.train('leadership'), contains('从未学过'));
    });

    test('train 10 级封顶', () {
      final engine = GameEngine(player: Player.defaultPlayer().copyWith(
        skills: {'sword': 10},
      ), isGameActive: true);
      expect(engine.train('sword'), contains('已臻化境'));
    });

    test('train 每日上限 3 次', () {
      final engine = GameEngine()..startNewGame();
      engine.train('sword');
      engine.train('sword');
      engine.train('sword');
      final result = engine.train('sword');
      expect(result, contains('练得够多'));
    });

    test('work 默认身份赚金币', () {
      final engine = GameEngine()..startNewGame();
      final before = engine.player.gold;
      final result = engine.work();
      expect(result, contains('忙碌了一天'));
      expect(engine.player.gold, greaterThan(before));
    });

    test('work 商人身份收入更高', () {
      final engine = GameEngine(player: Player.defaultPlayer().copyWith(
        identity: PlayerIdentity.merchant,
      ), isGameActive: true);
      final result = engine.work();
      expect(result, contains('忙碌了一天'));
      expect(engine.player.gold, greaterThan(100));
    });

    test('rest 扣 2 金币', () {
      final engine = GameEngine()..startNewGame();
      final before = engine.player.gold;
      final result = engine.rest();
      expect(result, contains('歇了一晚'));
      expect(engine.player.gold, before - 2);
    });

    test('rest 太穷提示', () {
      final engine = GameEngine(player: Player.defaultPlayer().copyWith(gold: 0),
          isGameActive: true);
      expect(engine.rest(), contains('太穷'));
    });

    test('hunt 城市不可狩猎', () {
      final engine = GameEngine(
        player: Player.defaultPlayer().copyWith(locationId: 'location_kings_landing'),
        locations: [
          Location.defaultLocation().copyWith(
            id: 'location_kings_landing',
            type: LocationType.city,
          ),
        ],
        isGameActive: true,
      );
      expect(engine.hunt(), contains('无猎可狩'));
    });

    test('hunt 野外可狩猎', () {
      final engine = GameEngine()..startNewGame();
      final result = engine.hunt();
      expect(
        result,
        anyOf(
          contains('猎到猎物'),
          contains('什么也没猎到'),
          contains('失手摔伤'),
        ),
      );
    });

    test('trade 非市场地点拒绝', () {
      final engine = GameEngine()..startNewGame(); // 临冬城是城堡
      expect(engine.trade(), contains('不是做买卖的地方'));
    });

    test('trade 城市商人可交易', () {
      final engine = GameEngine(
        player: Player.defaultPlayer().copyWith(
          identity: PlayerIdentity.merchant,
          locationId: 'location_kings_landing',
        ),
        locations: [
          Location.defaultLocation().copyWith(
            id: 'location_kings_landing',
            type: LocationType.city,
          ),
        ],
        isGameActive: true,
      );
      final before = engine.player.gold;
      final result = engine.trade();
      expect(result, contains('做成一笔买卖'));
      expect(engine.player.gold, greaterThan(before));
    });

    test('advanceMonth 推进时间并结算', () {
      final engine = GameEngine()..startNewGame();
      final beforeMonth = engine.progress.month;
      final result = engine.advanceMonth();
      expect(result, contains('时间推进到'));
      expect(engine.progress.month, beforeMonth == 12 ? 1 : beforeMonth + 1);
      expect(engine.player.gold, greaterThanOrEqualTo(100));
    });

    test('advanceMonth 未开始时拒绝', () {
      final engine = GameEngine();
      expect(engine.advanceMonth(), contains('尚未开始'));
    });
  });
}