/// Sprint 13-8 测试：修 P1 ⑥⑦「先扣费后判地点」+「商队失败不给钱」。
///
/// 【本批修的是什么】
/// ① `hunt()`（`mixin_play.dart:133`）：先 `adjustEnergy(-20)` + `_recordDaily`
///    **之后**才判 `loc.type == LocationType.city` ⇒ 在城市里狩猎是**纯亏损**：
///    精力扣了、当月 1/2 额度占了，只换来一句「城市里无猎可狩」。
/// ② `trade()`（`mixin_play.dart:186`）：同型，先扣 15 精力 + 占额度再判地点。
/// ③ `negotiate()`（`mixin_life.dart:455`）：同型，且月额度只有 1，
///    误点一次就耗光整月。
/// ④ `convoy()` 失败分支（`mixin_life.dart:511`）：文案写「商队付你 N 金币聊表谢意」，
///    实现却只 `adjustHealth`、**从不 `gainGold`**（紧邻的部分成功分支有）。
///    `convoyFailRate` 在全库只出现在该文案里（声明处除外）。
///
/// 【为什么断言「精力不变」而不是只看文案】文案在缺陷下也是对的——
/// 缺陷是**副作用已经发生**。故判别式必须落在状态上：精力 / 额度。
/// 【为什么额度判据是「之后还能正常用满」】计数是私有的，无法直读；
/// 但「额度没被吃掉」等价于「后续在合法地点仍能完整用满上限」。
///
/// ⚠️ 本机（Android/DSH）无 dart/flutter，**本文件未在本地执行**，正确性由 CI 验证。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/models/player.dart';

/// 一个「战斗值为 0」的玩家：`convoy` 的 score 恒 < `convoyPartialThreshold`，
/// 从而**确定性**地走失败分支（无需等概率）。
///
/// score = combatPower*2 + riding*2 + (商人?5:0) + rnd(20)；
/// combatPower = sword*2 + archery + strength~/2 + 装备 ⇒ 全 0 时 score ∈ [0,19]。
Player _weakPlayer({int gold = 100}) {
  return Player.defaultPlayer().copyWith(
    gold: gold,
    skills: const <String, int>{'sword': 0, 'archery': 0, 'riding': 0},
    attributes: const <String, int>{
      'strength': 0,
      'agility': 0,
      'intelligence': 0,
      'charisma': 0,
      'willpower': 0,
      'perception': 0,
    },
  );
}

/// 野外地点（可狩猎、无商贩）。
const String kWilderness = 'location_the_neck';

/// 城市地点（可贸易/议价、无猎可狩）。
const String kCity = 'location_white_harbor';

GameEngine _engineAt(String locationId) {
  final e = GameEngine()..startNewGame();
  e.updatePlayer(e.player.copyWith(locationId: locationId, energy: 100, gold: 500));
  return e;
}

void main() {
  group('S13-8 狩猎：地点判定必须在扣费之前', () {
    test('在城市狩猎：不扣精力、不占额度', () {
      final e = _engineAt(kCity);
      final energyBefore = e.player.energy;

      final text = e.hunt();
      expect(text, contains('无猎可狩'));
      expect(e.player.energy, energyBefore,
          reason: '地点不合法就不该扣 20 精力（缺陷下会扣）');

      // 额度判据：回到野外后仍能用满 2 次（上限 hunt=2）
      e.updatePlayer(e.player.copyWith(locationId: kWilderness));
      final first = e.hunt();
      expect(first, isNot(contains('猎物已经够多')),
          reason: '城市那次不该吃掉当月额度');
      e.updatePlayer(e.player.copyWith(energy: 100));
      final second = e.hunt();
      expect(second, isNot(contains('猎物已经够多')),
          reason: 'hunt 上限为 2，两次都该可用');
      e.updatePlayer(e.player.copyWith(energy: 100));
      expect(e.hunt(), contains('猎物已经够多'), reason: '第 3 次才该被上限拦住');
    });

    test('野外狩猎：仍照常扣精力并占额度（未误伤正常路径）', () {
      final e = _engineAt(kWilderness);
      final energyBefore = e.player.energy;
      e.hunt();
      expect(e.player.energy, lessThan(energyBefore), reason: '合法地点应正常扣费');
    });
  });

  group('S13-8 贸易：地点判定必须在扣费之前', () {
    test('在城堡贸易：不扣精力、不占额度', () {
      // 临冬城是 castle，不是 city/market
      final e = _engineAt('location_winterfell');
      final energyBefore = e.player.energy;

      final text = e.trade();
      expect(text, contains('不是做买卖的地方'));
      expect(e.player.energy, energyBefore,
          reason: '地点不合法就不该扣 15 精力（缺陷下会扣）');

      // 额度判据：换到城市后仍能用满 2 次（上限 trade=2）
      e.updatePlayer(e.player.copyWith(locationId: kCity));
      expect(e.trade(), isNot(contains('集市已经散了')), reason: '额度不该被吃掉');
      e.updatePlayer(e.player.copyWith(energy: 100));
      expect(e.trade(), isNot(contains('集市已经散了')));
      e.updatePlayer(e.player.copyWith(energy: 100));
      expect(e.trade(), contains('集市已经散了'), reason: '第 3 次才该被上限拦住');
    });

    test('在城市贸易：仍照常扣精力并占额度（未误伤正常路径）', () {
      final e = _engineAt(kCity);
      final energyBefore = e.player.energy;
      e.trade();
      expect(e.player.energy, lessThan(energyBefore));
    });
  });

  group('S13-8 议价：地点判定必须在扣费之前', () {
    test('在野外议价：不扣精力、不占当月唯一额度', () {
      final e = _engineAt(kWilderness);
      final energyBefore = e.player.energy;

      final text = e.negotiate();
      expect(text, contains('没有商贩'));
      expect(e.player.energy, energyBefore,
          reason: '地点不合法就不该扣精力（缺陷下会扣）');

      // 议价月额度只有 1，被误吃就整月作废
      e.updatePlayer(e.player.copyWith(locationId: kCity));
      expect(e.negotiate(), isNot(contains('议价机会已经用过了')),
          reason: '野外那次不该耗掉当月唯一的议价额度');
    });
  });

  group('S13-8 商队护送失败分支：文案承诺的金币必须真的发放', () {
    test('失败分支（聊表谢意）金币真的增加', () {
      final e = GameEngine()..startNewGame(player: _weakPlayer());
      final goldBefore = e.player.gold;

      final text = e.convoy();
      // 战斗值为 0 ⇒ score ∈ [0,19] < convoyPartialThreshold(25) ⇒ 必走失败分支
      expect(text, contains('聊表谢意'),
          reason: '前置条件：本用例必须命中失败分支（战斗值 0 时确定性成立）');
      expect(e.player.gold, greaterThan(goldBefore),
          reason: '文案写「商队付你 N 金币聊表谢意」，实现必须真的发放（缺陷下不发）');
    });
  });
}
