/// M6b 跨批次回归套件 · 指令注册表（regression_registry_test.dart）。
///
/// 目的：M3a 把巨型 switch 拆成注册表后，任何「漏注册 / 别名撞车 / 顺序错位 /
/// 参数校验丢失 / 消费回合丢失」都会直接破坏玩法入口。
/// 本文件用**引擎级端到端**方式把注册表契约兜一遍，与 m3 的纯注册表单测互补。
///
/// 与 m3_registry_test 的区别：
/// - m3 用裸 CommandRegistry 断言 specCount/aliasCount/order 唯一；
/// - 本文件用 GameEngine.resolveCommand 断言「真实可执行 + 消费回合 + 缺参提示」。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';

void main() {
  group('M6b 注册表完整性（引擎级）', () {
    test('46 条指令全部注册且 order 连续 1..46', () {
      final engine = GameEngine()..startNewGame();
      final reg = engine.commandRegistry;
      expect(reg.specCount, 46);
      final orders = reg.orderedSpecs.map((s) => s.order).toList();
      expect(orders, equals(List<int>.generate(46, (i) => i + 1)));
    });

    test('所有别名唯一（无撞车），英文别名与中文主名并存', () {
      final engine = GameEngine()..startNewGame();
      final reg = engine.commandRegistry;
      expect(reg.duplicateAliases, isEmpty);
      // 抽查几个中英别名都可达
      expect(reg.lookup('帮助'), isNotNull);
      expect(reg.lookup('help'), isNotNull);
      expect(reg.lookup('状态'), isNotNull);
      expect(reg.lookup('status'), isNotNull);
      expect(reg.lookup('过月'), isNotNull);
      expect(reg.lookup('advance'), isNotNull);
    });

    test('消费回合的指令只有「过月/探索」等少数（advance/explore 消耗回合）', () {
      final engine = GameEngine()..startNewGame();
      final reg = engine.commandRegistry;
      // 收集所有 spec：主名 → consumedTurn
      final turns = <String, bool>{};
      for (final spec in reg.orderedSpecs) {
        turns[spec.aliases.first] = spec.consumedTurn;
      }
      expect(turns['过月'], isTrue);
      expect(turns['探索'], isTrue);
      expect(turns['状态'], isFalse);
      expect(turns['工作'], isFalse);
      expect(turns['帮助'], isFalse);
    });

    test('缺参指令返回 missingArgsHint（使用/购买/训练等）', () {
      final engine = GameEngine()..startNewGame();
      expect(engine.resolveCommand('使用').text, contains('使用什么'));
      expect(engine.resolveCommand('购买').text, contains('买什么'));
      expect(engine.resolveCommand('训练').text, contains('训练什么'));
      expect(engine.resolveCommand('装备').text, contains('装备什么'));
    });

    test('未知指令返回未知提示 + 帮助文本', () {
      final engine = GameEngine()..startNewGame();
      final result = engine.resolveCommand('飞天扫帚');
      expect(result.text, contains('不是一条你能执行的指令'));
      expect(result.text, contains('帮助 / help'));
    });

    test('核心指令与领域指令在真实引擎中可执行（冒烟）', () {
      final engine = GameEngine()..startNewGame();
      final status = engine.resolveCommand('状态').text;
      expect(status, contains('【玩家状态】'));
      final bag = engine.resolveCommand('背包').text;
      expect(bag, contains('【背包】'));
      final title = engine.resolveCommand('头衔').text;
      expect(title, contains('【头衔】'));
      final help = engine.resolveCommand('帮助').text;
      expect(help, contains('帮助 / help'));
    });
  });

  group('M6b 别名归一化（command_alias）', () {
    test('物品别名：中文名/英文 id 均可解析为同一物品', () {
      final engine = GameEngine()..startNewGame();
      // 使用黑面包：别名「黑面包」→ item_bread
      final byChinese = engine.resolveCommand('使用 黑面包').text;
      final byId = engine.resolveCommand('使用 item_bread').text;
      // 有物品时返回使用成功/失败都一致；开局无面包，两者都应提示「没有」
      expect(byChinese, byId);
    });

    test('技能别名：训练 剑术 与 训练 sword 行为一致', () {
      final engine = GameEngine()..startNewGame();
      final a = engine.resolveCommand('训练 剑术').text;
      final b = engine.resolveCommand('训练 sword').text;
      expect(a, b);
    });
  });
}