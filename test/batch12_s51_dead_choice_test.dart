/// S5-1（P1-03 收尾）测试：零效果死选项修复 —— `happiness` → `energy`。
///
/// ## 背景
///
/// P1-03 的S2-3 已让幽灵键**可见化+ 防新增**（拒收进 `lastRejectedEffectKeys`，
/// 玩家能看到「叙事写了但状态没变」），但**存量**未清理。
/// 立项时取证（扫 `event_data.dart` 223 个选项）发现真正的「零效果死选项」只有 2 个，
/// 且都是**键名笔误**：narrative 写着「你休息，恢复精力」，作者想写的是引擎真实支持的
/// `energy`，误写成无实现的 `happiness`（全库 grep 零命中）。玩家点了「休息」
/// 完全没反应。本批次修的就是这两处。
///
/// ## 本批次要挡住的四类回归
///
/// 1. **死选项回流**：这是玩家唯一能直接感知到的 P1-03 形态——「点了没反应」。
///    断言全库零效果死选项 = 0，且这两处必须是 `energy`（不是被悄悄删空）。
/// 2. **「转身离开」被好心填效果**：7 个有意设计为零收益的选项
///    （`choice_leave_it` / `choice_walk_away` / ...）**不得**被填入任何效果键。
///    有人认为「总得给点奖励吧」而擅自填金币，正是这条断言要挡的。
/// 3. **数值被悄悄改动**：`energy: 10` / `energy: 5` 是照原`happiness` 数值 1:1 迁移的，
///    没有重新平衡的依据。若日后有人调成 `energy: 50`，此断言即红。
/// 4. **幽灵键存量**：S5-1 时本文件锁的是「`happiness` 恰好剩 3 处、总数 74、
///    种类 10 种」——用意是**锁住边界不被无声扩张**，因为存量清理属独立任务。
///    **S5-2（2026-10-07）采方案 C 删除了全部 74 处**，故下方该 group 的断言
///    已随之收紧为「恰好 0 处 + 10 个键名均不再出现 + 不得清空 effects 伪造通过」。
///    收紧而非放宽。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/event_data.dart';
import 'package:westeros_life_simulator/game_engine.dart';

/// 与 `batch10_121_content_schema_test.dart` / `batch12_s41` 保持同一份幽灵键清单。
const Set<String> kGhostEffectKeys = {
  'political',
  'faith',
  'military',
  'magic',
  'familyRelation',
  'food',
  'happiness',
  'knowledge',
  'north',
  'allyRelation',
};

/// 「转身离开」型选项：有意设计的零收益选项，effects 必须保持为空。
const List<String> kIntendedNoEffectChoiceIds = [
  'choice_leave_it',
  'choice_walk_away',
  'choice_keep_quiet',
  'choice_leave_guild',
  'choice_keep_out',
  'choice_just_look',
  'choice_refuse_task',
];

void main() {
  group('S5-1 · 零效果死选项已清零', () {
    test('全库不存在「effects 非空且全部为幽灵键」的选项', () {
      final dead = <String>[];
      for (final e in allEvents) {
        for (final c in e.choices) {
          final keys = c.effects.keys.toList();
          if (keys.isEmpty) continue;
          if (keys.every(kGhostEffectKeys.contains)) {
            dead.add('${e.id}/${c.id} 「${c.text}」 $keys');
          }
        }
      }
      expect(
        dead,
        isEmpty,
        reason: '这些选项玩家点了完全没反应（叙事承诺永不落盘）：\n'
            '${dead.join('\n')}',
      );
    });

    test('event_festival「休息」恢复 10 点精力', () {
      final choice = allEvents
          .firstWhere((e) => e.id == 'event_festival')
          .choices
          .firstWhere((c) => c.id == 'choice_rest');
      expect(choice.effects, {'energy': 10});
      expect(choice.narrative, contains('恢复精力'),
          reason: 'narrative 声明的意图就是本断言的依据');
    });

    test('event_hunt「休息」恢复 5 点精力', () {
      final choice = allEvents
          .firstWhere((e) => e.id == 'event_hunt')
          .choices
          .firstWhere((c) => c.id == 'choice_rest');
      expect(choice.effects, {'energy': 5});
      expect(choice.narrative, contains('恢复精力'));
    });

    test('两处修复不得被改成「删掉 effects」来伪造通过', () {
      // 防止有人用「清空效果」代替「修正键名」——那样死选项没了，但玩家依然没反应。
      for (final eventId in ['event_festival', 'event_hunt']) {
        final choice = allEvents
            .firstWhere((e) => e.id == eventId)
            .choices
            .firstWhere((c) => c.id == 'choice_rest');
        expect(choice.effects, isNotEmpty,
            reason: '$eventId 的「休息」不能被清空成零效果');
      }
    });
  });

  group('S5-1 · 效果真实落盘（applyEffects 实机）', () {
    test('event_festival「休息」经applyEffects 后精力真实上涨', () {
      final engine = GameEngine()..startNewGame();
      final choice = allEvents
          .firstWhere((e) => e.id == 'event_festival')
          .choices
          .firstWhere((c) => c.id == 'choice_rest');
      final after = engine.applyEffects(
        engine.player.copyWith(energy: 50),
        choice.effects,
      );
      expect(after.energy, 60);
      expect(engine.lastRejectedEffectKeys, isEmpty,
          reason: 'energy 是引擎真实支持的键，不该被拒收');
    });

    test('精力受0~100 边界钳制，不因休息溢出', () {
      final engine = GameEngine()..startNewGame();
      final choice = allEvents
          .firstWhere((e) => e.id == 'event_festival')
          .choices
          .firstWhere((c) => c.id == 'choice_rest');
      final after = engine.applyEffects(
        engine.player.copyWith(energy: 95),
        choice.effects,
      );
      expect(after.energy, 100);
    });

    test('event_hunt「休息」经 applyEffects 后精力真实上涨', () {
      final engine = GameEngine()..startNewGame();
      final choice = allEvents
          .firstWhere((e) => e.id == 'event_hunt')
          .choices
          .firstWhere((c) => c.id == 'choice_rest');
      final after = engine.applyEffects(
        engine.player.copyWith(energy: 20),
        choice.effects,
      );
      expect(after.energy, 25);
    });
  });

  group('S5-1 ·「转身离开」型选项必须保持零收益', () {
    test('7 个有意设计为零收益的选项 effects 仍为空', () {
      for (final id in kIntendedNoEffectChoiceIds) {
        final matches = allEvents
            .where((e) => e.choices.any((c) => c.id == id))
            .expand((e) => e.choices)
            .where((c) => c.id == id);
        expect(matches, isNotEmpty, reason: '$id 未找到，选项 id 可能被重命名');
        for (final c in matches) {
          expect(c.effects, isEmpty,
              reason: '$id「${c.text}」是有意设计的「转身离开」型选项，'
                  '不应有任何效果');
        }
      }
    });
  });

  group('S5-1 · 存量边界 → S5-2 · 存量已清零', () {
    test('S5-2 后全库幽灵键为 0（含 happiness 原 3 处）', () {
      // S5-1 时这里是「恰好剩 3 处混合键 + 总数 74 + 种类 10 种」，
      // 用意是**锁边界不被无声扩张**。S5-2 采方案 C 删除了全部 74 处，
      // 边界随之移到 0——断言同步收紧，不是为了让 CI 过而放宽。
      final ghosts = <String, String>{};
      for (final e in allEvents) {
        for (final c in e.choices) {
          for (final k in c.effects.keys) {
            if (kGhostEffectKeys.contains(k)) {
              ghosts['${e.id}/${c.id}'] = k;
            }
          }
        }
      }
      expect(ghosts, isEmpty,
          reason: '幽灵键应已由 S5-2 全部清除；重新出现即为回潮：$ghosts');
    });

    test('被删的 10 个键名一个都不再出现（不只数个数）', () {
      // 只断言「总数为 0」可被「换个新幽灵键名」绕过；钉住键名才防得住。
      final kinds = <String>{};
      for (final e in allEvents) {
        for (final c in e.choices) {
          kinds.addAll(c.effects.keys.where(kGhostEffectKeys.contains));
        }
      }
      expect(kinds, isEmpty, reason: '回潮的幽灵键：$kinds');
    });

    test('事件/选项总数未因 S5-2 变化（71 / 223）', () {
      // S5-2 只删效果键条目，不增删事件或选项。总数变了说明改过头了。
      expect(allEvents, hasLength(71));
      expect(allEvents.fold<int>(0, (a, e) => a + e.choices.length), 223);
    });
  });
}
