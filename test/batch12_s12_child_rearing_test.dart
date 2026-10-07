/// Sprint 12 测试：子女培养方向的归一化与中文化 + stealth 门槛可达性（S12-12）。
///
/// 【本批修的两个真 bug（同属「UI 显示中文，指令只认英文」这一族）】
///
/// ① `rearChild`（「培养」指令）**只认英文键**、还把英文键回显给玩家：
///    玩家在技能面板看到「权谋」，照输「培养 罗柏 权谋」被拒
///    （`valid.contains('权谋')` 恒 false），报错文案还写
///    「培养方向可选：sword / politics / speech / riding」。
///    与「旅行 白港」「训练 魔法」「使用 多恩红葡萄酒」同型。
///
/// ② `event_road_bandits` / `choice_sneak_past`（「绕道潜行」）门槛
///    `skills.stealth: 2` **永久不可达**：`stealth` 不在玩家初始技能表里，
///    而 `train()` 对表里没有的键一律回「你从未学过」，且全库没有任何
///    事件/指令会给予 stealth ⇒ 该选项纯摆设。
///    修法与 S4-3c（为 `skills.magic` 门槛把 `'magic': 0` 加进初始表）同构。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/balance_data.dart';
import 'package:westeros_life_simulator/data/event_data.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/models/player.dart';
import 'package:westeros_life_simulator/utils/labels.dart';

/// 造一个「有一个叫罗柏的子女」的引擎（培养指令要求子女在列表里）。
GameEngine _engineWithChild(String child) {
  final p = Player.defaultPlayer().copyWith(
    children: <String>[child],
  );
  return GameEngine()..startNewGame(player: p);
}

void main() {
  group('S12-12 培养方向接受中文', () {
    test('「培养 罗柏 权谋」成功，且回显中文', () {
      final e = _engineWithChild('罗柏');
      final text = e.rearChild('罗柏', '权谋');
      expect(text, contains('权谋'), reason: '应回显中文方向名');
      expect(text, isNot(contains('politics')), reason: '不该回显英文键');
      expect(e.player.childRearing.first.focus, 'politics',
          reason: '落盘仍用英文键（数据层不变）');
    });

    for (final pair in <List<String>>[
      <String>['剑术', 'sword'],
      <String>['口才', 'speech'],
      <String>['骑术', 'riding'],
    ]) {
      test('「培养 罗柏 ${pair[0]}」→ ${pair[1]}', () {
        final e = _engineWithChild('罗柏');
        e.rearChild('罗柏', pair[0]);
        expect(e.player.childRearing.first.focus, pair[1]);
      });
    }

    test('英文键仍然可用（不回归）', () {
      final e = _engineWithChild('罗柏');
      e.rearChild('罗柏', 'politics');
      expect(e.player.childRearing.first.focus, 'politics');
    });

    test('非法方向被拒，且提示里给的是中文名', () {
      final e = _engineWithChild('罗柏');
      final text = e.rearChild('罗柏', '魔法');
      expect(text, contains('培养方向可选'));
      expect(text, contains('权谋'), reason: '提示应给中文名');
      expect(text, isNot(contains('politics')), reason: '提示不该有英文键');
    });

    test('非子女被拒', () {
      final e = _engineWithChild('罗柏');
      expect(e.rearChild('琼恩', '权谋'), contains('不是你的子女'));
    });

    test('族谱文本不回显英文键', () {
      final e = _engineWithChild('罗柏');
      e.rearChild('罗柏', '权谋');
      // formatMultiGenTree 的子女行会带「·方向 X」。
      final tree = e.formatMultiGenTree();
      expect(tree, contains('方向 权谋'), reason: '应显示中文方向名');
      expect(tree, isNot(contains('方向 politics')), reason: '不该回显英文键');
    });
  });

  group('S12-12 stealth 门槛可达', () {
    test('stealth 在玩家初始技能表里（与 magic 同先例）', () {
      final p = Player.defaultPlayer();
      expect(p.skills.containsKey('stealth'), isTrue,
          reason: '不在初始表 ⇒ train 拒绝 ⇒ 门槛永久不可达');
      expect(p.skills['stealth'], 0, reason: '初始 0 级，可训练成长');
      expect(p.skills.containsKey('magic'), isTrue, reason: 'S4-3c 先例仍在');
    });

    test('「训练 潜行」能真的提升 stealth（须走指令层，归一化才生效）', () {
      final e = GameEngine()..startNewGame();
      // 【坑】`train()` 收到的是**已归一化**的键，归一化在指令层完成
      // （`mixin_play` 的 `train(normalizeSkillAlias(args))`）。
      // 直接调 `e.train('潜行')` 会跳过归一化 —— 第一版测试就踩了这个。
      final r = e.resolveCommand('训练 潜行');
      expect(r.text, isNot(contains('从未学过')),
          reason: '中文名归一化 + 初始表含 stealth ⇒ 应该能练');
      expect(e.player.skills.containsKey('stealth'), isTrue);
    });

    test('英文键 stealth 同样可训练', () {
      final e = GameEngine()..startNewGame();
      expect(e.train('stealth'), isNot(contains('从未学过')));
    });

    test('全库每个 skills.* 门槛键都能被玩家获得（防再出现永久不可达选项）', () {
      final p = Player.defaultPlayer();
      final required = <String>{};
      for (final ev in allEvents) {
        for (final c in ev.choices) {
          for (final k in c.requirements.keys) {
            if (k.startsWith('skills.')) required.add(k.substring(7));
          }
        }
      }
      expect(required, isNotEmpty, reason: '样本前提：事件库确实有 skills 门槛');
      for (final skill in required) {
        expect(p.skills.containsKey(skill), isTrue,
            reason: '门槛 skills.$skill 无法通过任何途径获得 ⇒ 该选项永久不可选');
        expect(BalanceData.kPlayerSkillKeys.contains(skill), isTrue,
            reason: '$skill 必须在技能白名单内，否则训练写侧会被守卫拒绝');
      }
    });
  });

  group('S12-12 标签表覆盖', () {
    test('培养方向的四个键都有中文标签（且不是退回原键）', () {
      for (final k in <String>['sword', 'politics', 'speech', 'riding']) {
        expect(skillLabel(k), isNot(k), reason: '$k 缺中文标签');
      }
    });
  });
}