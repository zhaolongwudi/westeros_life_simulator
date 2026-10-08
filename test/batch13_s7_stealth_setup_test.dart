/// Sprint 13-7 测试：修 P1 ⑨「S12-12 只修一半：`stealth` 未进向导技能表」。
///
/// 【本批修的是什么】S12-12 为让 `event_road_bandits` / `choice_sneak_past`
/// （「绕道潜行」，门槛 `skills.stealth: 2`）可达，把 `'stealth': 0` 加进了
/// `Player.defaultPlayer()`——但**生产开局走的是向导** `buildSetupPlayer()`
/// （`start_screen.dart:199`），它的技能表里没有 stealth，而 `train()` 对
/// 不在技能表里的键一律回「你从未学过」⇒ 该选项在真实游玩路径里
/// **依旧永久不可选**。S12-12 的测试只锁了 `defaultPlayer`，故漏网。
///
/// 【为什么两条路径必须一致】同一个「初始技能表」概念被两个构造点各写一份，
/// 任何只改一处的修复都会立刻漂移——这正是 S13-7 卡片要求
/// 「两条开局路径技能表键集一致」的原因（防同类问题第三次复发）。
///
/// ⚠️ 本机（Android/DSH）无 dart/flutter，**本文件未在本地执行**，正确性由 CI 验证。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/models/player.dart';
import 'package:westeros_life_simulator/screens/start_screen.dart';

/// 造一个向导开局配置（字段取值不影响技能表，故只需一份固定值）。
GameSetup _setup({PlayerIdentity identity = PlayerIdentity.noble}) {
  return GameSetup(
    name: '测试者',
    gender: 'male',
    identity: identity,
    familyId: 'family_stark',
    locationId: 'location_winterfell',
    era: '当前时代',
    season: 'summer',
    year: 298,
    month: 6,
  );
}

void main() {
  group('S13-7 向导开局的技能表', () {
    test('buildSetupPlayer 的技能表含 stealth（初始 0 级）', () {
      final p = buildSetupPlayer(_setup());
      expect(p.skills.containsKey('stealth'), isTrue,
          reason: '不在技能表 ⇒ train 拒绝 ⇒ 「绕道潜行」门槛永久不可达');
      expect(p.skills['stealth'], 0, reason: '初始 0 级，可训练成长');
    });

    test('向导开局后「训练 潜行」不再被拒（生产路径真的可达）', () {
      final p = buildSetupPlayer(_setup());
      final e = GameEngine()..startNewGame(player: p);
      // 【坑】`train()` 收到的是**已归一化**的键，归一化在指令层完成
      // （`mixin_play` 的 `train(normalizeSkillAlias(args))`）。
      // 直接调 `e.train('潜行')` 会跳过归一化——S12-12 的测试注释已记过。
      final r = e.resolveCommand('训练 潜行');
      expect(r.text, isNot(contains('从未学过')),
          reason: '向导开局是生产路径，它必须与 defaultPlayer 行为一致');
      expect(e.player.skills.containsKey('stealth'), isTrue);
    });

    test('两条开局路径的技能键集完全一致', () {
      final fromDefault = Player.defaultPlayer().skills.keys.toSet();
      final fromSetup = buildSetupPlayer(_setup()).skills.keys.toSet();
      expect(fromSetup, fromDefault,
          reason: '同一「初始技能表」概念有两个构造点，键集漂移就是下一个 ⑨');
    });

    test('全部身份的技能键集都一致（switch 各分支不得各写一份）', () {
      final fromDefault = Player.defaultPlayer().skills.keys.toSet();
      for (final identity in PlayerIdentity.values) {
        final fromSetup =
            buildSetupPlayer(_setup(identity: identity)).skills.keys.toSet();
        expect(fromSetup, fromDefault, reason: '身份 $identity 的技能表漂移了');
      }
    });
  });
}
