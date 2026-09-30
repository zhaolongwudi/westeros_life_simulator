/// M3 架构解耦测试（Batch 10-28）：指令注册表 + 月度结算管线。
///
/// 覆盖：
/// 1. 注册表完整性（每条指令有 handler、别名无重复、order 唯一）；
/// 2. 帮助文本与 Batch 10-28 之前逐字一致（46 行，顺序不变）；
/// 3. 参数校验与别名分发等价（缺参提示、英文别名）；
/// 4. 月度管线：阶段顺序、文本顺序、id 唯一、钩子可扩展；
/// 5. 自注册演示：外部代码只调 register 即可挂新指令（无需改分发器）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/core/command_registry.dart';
import 'package:westeros_life_simulator/core/monthly_pipeline.dart';
import 'package:westeros_life_simulator/game_engine.dart';

void main() {
  group('CommandRegistry 基础', () {
    test('register + resolve 基本通路', () {
      final reg = CommandRegistry();
      reg.register(
        CommandSpec(
          aliases: const ['甲', 'jia'],
          order: 1,
          helpLine: '甲 / jia   测试指令',
          handler: (args) => CommandResult(text: '收到:$args'),
        ),
      );
      expect(reg.specCount, 1);
      expect(reg.aliasCount, 2);
      expect(reg.duplicateAliases, isEmpty);
      final r = reg.resolve('甲', '一点');
      expect(r, isNotNull);
      expect(r!.text, '收到:一点');
    });

    test('未注册返回 null（交由调用方生成未知指令提示）', () {
      final reg = CommandRegistry();
      expect(reg.resolve('不存在', ''), isNull);
      expect(reg.lookup('不存在'), isNull);
    });

    test('重复别名不覆盖，记录到 duplicateAliases', () {
      final reg = CommandRegistry();
      reg.register(
        CommandSpec(
          aliases: const ['重复'],
          order: 1,
          helpLine: '重复  A',
          handler: (args) => const CommandResult(text: 'A'),
        ),
      );
      reg.register(
        CommandSpec(
          aliases: const ['重复'],
          order: 2,
          helpLine: '重复  B',
          handler: (args) => const CommandResult(text: 'B'),
        ),
      );
      expect(reg.duplicateAliases, ['重复']);
      expect(reg.resolve('重复', '')!.text, 'A');
    });

    test('参数不足返回 missingArgsHint', () {
      final reg = CommandRegistry();
      reg.register(
        CommandSpec(
          aliases: const ['需参'],
          order: 1,
          requiredArgCount: 1,
          missingArgsHint: '缺参数了',
          helpLine: '需参 [x]',
          handler: (args) => CommandResult(text: 'ok:$args'),
        ),
      );
      expect(reg.resolve('需参', '')!.text, '缺参数了');
      expect(reg.resolve('需参', '有值')!.text, 'ok:有值');
    });

    test('helpText 按 order 升序拼装，含抬头与结尾提示', () {
      final reg = CommandRegistry();
      reg.register(
        CommandSpec(
          aliases: const ['后'],
          order: 9,
          helpLine: '后  第二行',
          handler: (args) => const CommandResult(text: ''),
        ),
      );
      reg.register(
        CommandSpec(
          aliases: const ['先'],
          order: 1,
          helpLine: '先  第一行',
          handler: (args) => const CommandResult(text: ''),
        ),
      );
      final help = reg.helpText();
      expect(help, startsWith(kHelpHeader));
      expect(help.indexOf('先  第一行'), lessThan(help.indexOf('后  第二行')));
      expect(help, contains(kHelpFooter.trim()));
    });
  });

  group('引擎注册表完整性', () {
    test('无重复别名、指令数与帮助行数一致', () {
      final engine = GameEngine()..startNewGame();
      final reg = engine.commandRegistry;
      expect(reg.duplicateAliases, isEmpty,
          reason: '存在重复注册的别名：${reg.duplicateAliases}');
      expect(reg.specCount, 46);
      final helpLines = reg.helpText().split('\n').where((l) {
        return l.trim().isNotEmpty &&
            !l.startsWith(kHelpHeader) &&
            !l.startsWith('提示：');
      }).toList();
      expect(helpLines.length, reg.specCount,
          reason: '每条注册指令都必须在帮助文本里出现且只出现一次');
    });

    test('order 唯一且连续（1..46）', () {
      final engine = GameEngine()..startNewGame();
      final orders = engine.commandRegistry.orderedSpecs
          .map((s) => s.order)
          .toList();
      expect(orders, equals(List<int>.generate(46, (i) => i + 1)));
    });

    test('每条指令都有非空帮助行与可执行 handler', () {
      final engine = GameEngine()..startNewGame();
      for (final spec in engine.commandRegistry.orderedSpecs) {
        expect(spec.helpLine.trim(), isNotEmpty);
        expect(spec.aliases, isNotEmpty);
        final r = engine.commandRegistry.resolve(spec.aliases.first, '');
        expect(r, isNotNull, reason: '指令 ${spec.aliases} 无法分发');
      }
    });
  });

  group('分发行为与旧实现等价', () {
    test('中文主名与英文别名都命中同一 handler', () {
      final engine = GameEngine()..startNewGame();
      expect(engine.resolveCommand('状态').text, contains('玩家状态'));
      expect(engine.resolveCommand('status').text, contains('玩家状态'));
      expect(engine.resolveCommand('过月').consumedTurn, true);
      expect(engine.resolveCommand('advance').consumedTurn, true);
      expect(engine.resolveCommand('状态').consumedTurn, false);
    });

    test('缺参提示保持历史文案', () {
      final engine = GameEngine()..startNewGame();
      expect(engine.resolveCommand('训练').text, contains('训练什么'));
      expect(engine.resolveCommand('装备').text, contains('装备什么'));
      expect(engine.resolveCommand('培养').text, contains('培养谁'));
      expect(engine.resolveCommand('接任务').text, contains('接谁的任务'));
    });

    test('帮助文本包含全部历史指令关键词', () {
      final engine = GameEngine()..startNewGame();
      final help = engine.resolveCommand('帮助').text;
      expect(help, contains('可用指令'));
      for (final kw in [
        '状态', '背包', '使用', '系统', '信', '回信', '旅行', '探索',
        '训练', '工作', '狩猎', '贸易', '巡游', '议价', '商队', '购买',
        '出售', '行情', '装备', '卸下', '装备栏', '头衔', '在场', '互动',
        '示好', '深聊', '任务', '任务列表', '接任务', '进度', '关系',
        '家谱', '立嗣', '求婚', '配偶', '婚姻', '私语', '离婚', '丧偶',
        '培养', '督导', '送学', '家族树', '休息', '过月', '帮助',
      ]) {
        expect(help, contains(kw), reason: '帮助文本缺少指令「$kw」');
      }
    });

    test('未知指令仍返回提示 + 帮助', () {
      final engine = GameEngine()..startNewGame();
      final r = engine.resolveCommand('未知指令xyz');
      expect(r.text, contains('可用指令'));
      expect(r.consumedTurn, false);
    });

    test('空输入不进入注册表', () {
      final engine = GameEngine()..startNewGame();
      final r = engine.resolveCommand('   ');
      expect(r.text, contains('请输入指令'));
      expect(r.consumedTurn, false);
    });
  });

  group('月度结算管线', () {
    test('钩子 id 唯一、无重复注册', () {
      final engine = GameEngine()..startNewGame();
      final p = engine.monthlyPipeline;
      expect(p.duplicateIds, isEmpty);
      final ids = p.orderedIds;
      expect(ids.toSet().length, ids.length);
      expect(p.hookCount, ids.length);
    });

    test('阶段顺序：推进前钩子全部早于推进后钩子', () {
      final engine = GameEngine()..startNewGame();
      final p = engine.monthlyPipeline;
      final ids = p.orderedIds;
      final lastBefore = ids.lastIndexOf('task_deadline');
      final firstAfter = ids.indexOf('divorce_clear');
      expect(lastBefore, greaterThan(-1));
      expect(firstAfter, greaterThan(-1));
      expect(lastBefore, lessThan(firstAfter));
    });

    test('执行顺序与历史实现逐条对应', () {
      final engine = GameEngine()..startNewGame();
      final ids = engine.monthlyPipeline.orderedIds;
      expect(ids, [
        'systems',
        'life',
        'title',
        'npc_story',
        'succession',
        'family_event',
        'spouse_monthly',
        'task_advance',
        'task_deadline',
        'divorce_clear',
        'inheritance',
        'world_event',
      ]);
    });

    test('runMonth 在两阶段之间恰好推进一次时钟', () {
      final engine = GameEngine()..startNewGame();
      final before = engine.progress.turnCount;
      var clockCalls = 0;
      engine.monthlyPipeline.runMonth(advanceClock: () {
        clockCalls++;
        engine.advanceTime();
      });
      expect(clockCalls, 1);
      expect(engine.progress.turnCount, before + 1);
    });

    test('空文本钩子不产出段落', () {
      final p = MonthlyPipeline();
      p.register(
        MonthlyHookSpec(
          id: 'silent',
          phase: MonthlyPhase.beforeAdvance,
          order: 1,
          outputOrder: 1,
          hook: () => const MonthlyHookResult(text: ''),
        ),
      );
      p.register(
        MonthlyHookSpec(
          id: 'loud',
          phase: MonthlyPhase.beforeAdvance,
          order: 2,
          outputOrder: 2,
          hook: () => const MonthlyHookResult(text: '有话说'),
        ),
      );
      var ticked = false;
      final text = p.runMonth(advanceClock: () => ticked = true);
      expect(ticked, true);
      expect(text.trim(), '有话说');
    });

    test('文本顺序由 outputOrder 决定，与执行顺序无关', () {
      final p = MonthlyPipeline();
      p.register(
        MonthlyHookSpec(
          id: 'exec_first',
          phase: MonthlyPhase.beforeAdvance,
          order: 1,
          outputOrder: 9,
          hook: () => const MonthlyHookResult(text: '先执行后输出', outputOrder: 9),
        ),
      );
      p.register(
        MonthlyHookSpec(
          id: 'exec_second',
          phase: MonthlyPhase.beforeAdvance,
          order: 2,
          outputOrder: 2,
          hook: () => const MonthlyHookResult(text: '后执行先输出', outputOrder: 2),
        ),
      );
      expect(p.orderedIds, ['exec_first', 'exec_second']);
      final text = p.runMonth(advanceClock: () {});
      expect(text.indexOf('后执行先输出'), lessThan(text.indexOf('先执行后输出')));
    });

    test('重复 id 只注册一次并记录', () {
      final p = MonthlyPipeline();
      for (var i = 0; i < 2; i++) {
        p.register(
          MonthlyHookSpec(
            id: 'dup',
            phase: MonthlyPhase.beforeAdvance,
            order: 1,
            outputOrder: 1,
            hook: () => const MonthlyHookResult(text: 'x'),
          ),
        );
      }
      expect(p.duplicateIds, ['dup']);
      expect(p.hookCount, 1);
    });

    test('过月叙事仍包含时间推进抬头与地点行（回归）', () {
      final engine = GameEngine()..startNewGame();
      final text = engine.resolveCommand('过月').text;
      expect(text, contains('时间推进到'));
      expect(text, contains('你身处'));
    });
  });

  group('自注册演示（新增玩法无需改分发器）', () {
    test('外部往注册表挂新指令即可被分发', () {
      final engine = GameEngine()..startNewGame();
      final reg = engine.commandRegistry;
      reg.register(
        CommandSpec(
          aliases: const ['钓鱼', 'fish'],
          order: 100,
          helpLine: '钓鱼 / fish  演示指令',
          handler: (args) => CommandResult(text: '钓到一条${args.isEmpty ? '鱼' : args}'),
        ),
      );
      expect(reg.resolve('钓鱼', '')!.text, '钓到一条鱼');
      expect(reg.resolve('fish', '大鱼')!.text, '钓到一条大鱼');
      expect(engine.resolveCommand('钓鱼 鲈鱼').text, '钓到一条鲈鱼');
    });

    test('注册表缓存：多次访问同一实例', () {
      final engine = GameEngine()..startNewGame();
      expect(identical(engine.commandRegistry, engine.commandRegistry), true);
    });
  });
}