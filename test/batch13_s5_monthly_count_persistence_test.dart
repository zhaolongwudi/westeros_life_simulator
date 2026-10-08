/// Sprint 13-5 测试：修 P1 ⑫ 月度行动计数不入存档。
///
/// 【本文件是 S13-5 的复现测试】按接力文档第 4 条「先写能复现的失败测试再改实现」。
///
/// 【根因（实测取证，非推测）】6 组「每月次数」计数器全是 mixin 私有内存字段：
///   ① `_dailyCount`/`_dailyDate`（`mixin_play.dart:424-425`）
///   ② `_b1011DailyCount`/`_b1011DailyMonth`（`mixin_life.dart:326-327`）
///   ③ `_spouseDailyCount`/`_spouseDailyMonth`（`mixin_marriage.dart:257-258`）
///   ④ `_b1025ChatCount`/`_b1025ChatMonth`（`mixin_marriage.dart:420-421`）
///   ⑤ `_favorDailyCount`/`_favorDailyMonth`（`mixin_npc_interact.dart:24-25`）
///   ⑥ `_chatDailyCount`/`_chatDailyMonth`（`mixin_npc_interact.dart:311-312`）
/// 而 `GameStateProvider.toJson`/`fromJson` **没有任何对应键**，`startNewGame`/`applyState`
/// 也不重置 ⇒ 读档后当月额度**全部恢复**⇒ 玩家可反复读档无限刷训练/工作/狩猎/
/// 示好/深聊/配偶互动/谈心/巡游/议价/商队（**注意读档本身不消耗额度**，
/// 而每一项都直接换关系、精力、金币、声望或好感）。
///
/// 【为什么不用「跑 N 回合应该能…」】接力文档 §0 第 9 条：本项目已两次因概率等待翻车。
/// 本文件所有断言都是**确定性**的：额度用尽是纯计数、无随机；跨月用
/// `advanceTime()`（只推时钟，不触发任何月度钩子，避免钩子自己改变计数）。
///
/// ⚠️ 本机（Android/DSH）无 dart/flutter，**本文件未在本地执行**，正确性由 CI 验证。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/providers/game_state_provider.dart';
import 'package:westeros_life_simulator/services/save_service.dart';

/// 临冬城在场 NPC（`location_data.dart:36` + `npc_data.dart` 实测 8 位）。
const String kFavorNpc = 'npc_nev';

/// 刷到「本月额度用尽」为止，返回最后一次的拒绝文案（作为额度已尽的证据）。
///
/// 【为什么不写死次数】各上限分散在 `balance_data.dart` 与各 mixin 的常量里，
/// 写死会随数值调整而失效；改为「循环到出现拒绝文案为止」，
/// 上限变了也不用改测试（上限本身有 `batch10_118` 等既有测试锁定）。
String _exhaust(String Function() action) {
  String text = '';
  for (var i = 0; i < 40; i++) {
    text = action();
    if (_looksRefused(text)) return text;
  }
  fail('40 次内没有出现「额度已尽」文案 ⇒ 闸口本身坏了，不是持久化问题：$text');
}

bool _looksRefused(String text) {
  return text.contains('已经练得够多') ||
      text.contains('已经歇得够久') ||
      text.contains('活计已经干完') ||
      text.contains('猎物已经够多') ||
      text.contains('集市已经散') ||
      text.contains('商路已经跑完') ||
      text.contains('议价机会已经用过') ||
      text.contains('没有商队愿意等') ||
      text.contains('示好的次数已经用完') ||
      text.contains('聊得够多') ||
      text.contains('相处够久') ||
      text.contains('很多知心话');
}

/// 精力回满（工作/狩猎/巡游都按精力设闸，先排除「精力不足」这条干扰路径）。
GameEngine _freshEngine({int gold = 5000}) {
  final engine = GameEngine()..startNewGame();
  engine.updatePlayer(
    engine.player.copyWith(gold: gold, energy: 100, health: 100),
  );
  return engine;
}

/// 已婚引擎（配偶两组计数的前置）。
GameEngine _marriedEngine() {
  final engine = _freshEngine();
  final text = engine.marry('平民');
  expect(text, contains('成婚'), reason: '前提：成婚成功');
  expect(engine.isMarried, isTrue, reason: '前提：已婚');
  return engine;
}

void main() {
  late Directory tempDir;
  late SaveService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('batch13_s5_');
    service = SaveService(saveDir: tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// 存 → 读 → 灌进新引擎（与 `settings_screen` 读档同形）。
  Future<GameEngine> _revive(GameEngine engine, String saveId) async {
    final id = await service.saveGame(engine, saveId: saveId);
    final loaded = await service.loadGame(id);
    // ⚠️ 必须用 `loaded!`：`expect(loaded, isNotNull)` 不会让空安全分析器收窄
    // （CI 报 `argument_type_not_assignable`）。S8-1 / S13-4 的同款测试都这么写。
    expect(loaded, isNotNull);
    return GameEngine()..applyState(loaded!);
  }

  group('S13-5 验收1：日常活动额度（mixin_play）随存档往返', () {
    test('训练：刷满 3 次后读档，同月仍不能再练', () async {
      final engine = _freshEngine();
      final refusedBefore = _exhaust(() => engine.train('sword'));
      expect(refusedBefore, contains('已经练得够多'), reason: '前提：训练额度已尽');

      final revived = await _revive(engine, 'train');
      final after = revived.train('sword');
      // 🔴 判别断言：修复前计数不入档 ⇒ here 通过 ⇒ 本例失败
      expect(after, contains('已经练得够多'),
          reason: '读档后训练额度恢复 ⇒ 反复读档可无限刷技能（P1 ⑫）');
    });

    test('工作：刷满 2 次后读档，同月仍不能再干活', () async {
      final engine = _freshEngine();
      _exhaust(engine.work);

      final revived = await _revive(engine, 'work');
      expect(revived.work(), contains('活计已经干完'),
          reason: '读档后工作额度恢复 ⇒ 可反复读档刷金币');
    });

    test('狩猎：刷满 2 次后读档，同月仍不能再狩', () async {
      final engine = _freshEngine();
      _exhaust(engine.hunt);

      final revived = await _revive(engine, 'hunt');
      expect(revived.hunt(), contains('猎物已经够多'),
          reason: '读档后狩猎额度恢复 ⇒ 可反复读档刷金币与饱食');
    });

    test('休息：刷满 10 次后读档，同月仍不能再歇（上限最大的一组）', () async {
      final engine = _freshEngine();
      _exhaust(engine.rest);

      final revived = await _revive(engine, 'rest');
      expect(revived.rest(), contains('已经歇得够久'),
          reason: '读档后休息额度恢复 ⇒ 可反复读档刷精力');
    });

    test('贸易：刷满 2 次后读档，同月不能再做买卖', () async {
      final engine = _freshEngine();
      _exhaust(engine.trade);

      final revived = await _revive(engine, 'trade');
      expect(revived.trade(), contains('集市已经散'),
          reason: '读档后贸易额度恢复 ⇒ 可反复读档刷金币');
    });
  });

  group('S13-5 验收2：新增贸易三项（mixin_life）随存档往返', () {
    test('地区特产巡游：刷满 2 次后读档，同月不能再跑商路', () async {
      final engine = _freshEngine();
      _exhaust(engine.tradeSpecialty);

      final revived = await _revive(engine, 'specialty');
      expect(revived.tradeSpecialty(), contains('商路已经跑完'),
          reason: '读档后巡游额度恢复 ⇒ 可反复读档刷物品与金币');
    });

    test('议价：刷满 1 次后读档，同月不能再议价', () async {
      final engine = _freshEngine();
      engine.updatePlayer(
        engine.player.copyWith(skills: <String, int>{'speech': 5}),
      );
      _exhaust(engine.negotiate);

      final revived = await _revive(engine, 'negotiate');
      expect(revived.negotiate(), contains('议价机会已经用过'),
          reason: '读档后议价额度恢复 ⇒ 可反复读档叠加议价折扣');
    });

    test('商队：刷满 1 次后读档，同月不能再接商队', () async {
      final engine = _freshEngine();
      _exhaust(engine.convoy);

      final revived = await _revive(engine, 'convoy');
      expect(revived.convoy(), contains('没有商队愿意等'),
          reason: '读档后商队额度恢复 ⇒ 可反复读档刷报酬');
    });
  });

  group('S13-5 验收3：配偶两组（mixin_marriage）随存档往返', () {
    test('配偶互动：刷满 1 次后读档，同月不能再相处', () async {
      final engine = _marriedEngine();
      final refused = _exhaust(engine.spouseInteract);
      expect(refused, contains('相处够久'), reason: '前提：配偶互动额度已尽');

      final revived = await _revive(engine, 'spouse_interact');
      expect(revived.isMarried, isTrue, reason: '前提：读档后婚姻关系仍在');
      expect(revived.spouseInteract(), contains('相处够久'),
          reason: '读档后配偶互动额度恢复 ⇒ 可反复读档刷精力恢复');
    });

    test('配偶谈心：刷满 2 次后读档，同月不能再谈心', () async {
      final engine = _marriedEngine();
      final refused = _exhaust(() => engine.spouseChat('家常'));
      expect(refused, contains('很多知心话'), reason: '前提：谈心额度已尽');

      final revived = await _revive(engine, 'spouse_chat');
      expect(revived.spouseChat('家常'), contains('很多知心话'),
          reason: '读档后谈心额度恢复 ⇒ 可反复读档刷夫妻好感');
    });
  });

  group('S13-5 验收4：示好与深聊（mixin_npc_interact）随存档往返', () {
    test('示好：刷满 3 次后读档，同月不能再送礼', () async {
      final engine = _freshEngine();
      _exhaust(() => engine.npcFavor(kFavorNpc));

      final revived = await _revive(engine, 'favor');
      expect(revived.npcFavor(kFavorNpc), contains('示好的次数已经用完'),
          reason: '读档后示好额度恢复 ⇒ 可反复读档刷 NPC 关系');
    });

    test('深聊：刷满 3 次后读档，同月不能再深聊', () async {
      final engine = _freshEngine();
      // 深聊要求关系 ≥ 相识(20)，先把关系抬到门槛之上。
      engine.adjustRelation(kFavorNpc, 30);
      final refused = _exhaust(() => engine.npcChat(kFavorNpc));
      expect(refused, contains('聊得够多'), reason: '前提：深聊额度已尽');

      final revived = await _revive(engine, 'chat');
      expect(revived.npcChat(kFavorNpc), contains('聊得够多'),
          reason: '读档后深聊额度恢复 ⇒ 可反复读档刷 NPC 关系');
    });
  });

  group('S13-5 验收5：跨月后额度必须恢复（持久化不能写成永久锁）', () {
    test('训练：读档后推进到下月，额度重新可用', () async {
      final engine = _freshEngine();
      _exhaust(() => engine.train('sword'));

      final revived = await _revive(engine, 'month_reset_train');
      // ⚠️ 用 `advanceTime()` 而不是 `advanceMonth()`：后者会跑整条月度管线
      // （含议价折扣清零等副作用），会让本例测不到「计数自身是否按月重置」。
      // `advanceTime()` 只推进时钟（game_state_provider.dart:309）。
      revived.advanceTime();
      expect(revived.train('sword'), isNot(contains('已经练得够多')),
          reason: '跨月后训练额度应恢复——若这条红，说明持久化把计数写成了永久锁');
    });

    test('示好：读档后推进到下月，额度重新可用', () async {
      final engine = _freshEngine();
      _exhaust(() => engine.npcFavor(kFavorNpc));

      final revived = await _revive(engine, 'month_reset_favor');
      revived.advanceTime();
      expect(revived.npcFavor(kFavorNpc),
          isNot(contains('示好的次数已经用完')),
          reason: '跨月后示好额度应恢复');
    });

    test('配偶互动：读档后推进到下月，额度重新可用', () async {
      final engine = _marriedEngine();
      _exhaust(engine.spouseInteract);

      final revived = await _revive(engine, 'month_reset_spouse');
      revived.advanceTime();
      expect(revived.spouseInteract(), isNot(contains('相处够久')),
          reason: '跨月后配偶互动额度应恢复');
    });
  });

  group('S13-5 验收6：新局必须清零（settings_screen 复用同一引擎实例）', () {
    test('startNewGame 后各组额度满血', () {
      final engine = _marriedEngine();
      _exhaust(() => engine.train('sword'));
      _exhaust(() => engine.npcFavor(kFavorNpc));
      // `settings_screen._newGame` 在**同一引擎实例**上调 startNewGame
      engine.startNewGame();

      expect(engine.train('sword'), isNot(contains('已经练得够多')),
          reason: '新局里残留上一局的训练计数 ⇒ 重开就白拿额度');
      expect(engine.npcFavor(kFavorNpc), isNot(contains('示好的次数已经用完')),
          reason: '新局里残留上一局的示好计数');
    });

    test('新局后仍是未婚（前置不残留，计数才谈得上归零）', () {
      final engine = _marriedEngine();
      engine.startNewGame();
      expect(engine.isMarried, isFalse, reason: '前提：新局不该继承婚姻');
      expect(engine.spouseInteract(), contains('尚未成婚'));
    });
  });

  group('S13-5 验收7：旧存档（无这些键）安全回落', () {
    test('缺键的旧存档加载不抛、回落「未用额度」', () {
      final state = GameStateProvider.fromJson(<String, dynamic>{
        'player': <String, dynamic>{},
        'progress': <String, dynamic>{},
      });
      final revived = GameEngine()..applyState(state);
      expect(revived.train('sword'), isNot(contains('已经练得够多')),
          reason: '旧存档应回落「额度未用」，而不是「额度已耗尽」');
    });

    test('坏类型（字符串 / null / 非 Map / 元素为 null）不抛', () {
      for (final bad in <Object?>[
        'abc',
        123,
        null,
        <Object?>[null, 'x'],
        <Object?>[1, 2],
      ]) {
        for (final key in <String>[
          'monthlyActivityCounts',
          'monthlyActivityMonth',
          'spouseInteractionCount',
          'spouseChatCount',
        ]) {
          final state = GameStateProvider.fromJson(<String, dynamic>{
            'player': <String, dynamic>{},
            'progress': <String, dynamic>{},
            key: bad,
          });
          // 坏值必须被防御式读取丢弃，而不是抛异常
          final revived = GameEngine()..applyState(state);
          expect(revived.train('sword'), isNot(contains('已经练得够多')),
              reason: '坏值 $bad（键 $key）应被安全丢弃');
        }
      }
    });
  });

  group('S13-5 验收8：导出/导入链路同样保留（导出不是例外路径）', () {
    test('exportSave / importSave 后额度仍然用尽', () {
      final engine = _freshEngine();
      _exhaust(() => engine.train('sword'));

      final imported = service.importSave(service.exportSave(engine));
      expect(imported, isNotNull);
      final revived = GameEngine()..applyState(imported!);
      // 🔴 修复前额度恢复 ⇒ 失败
      expect(revived.train('sword'), contains('已经练得够多'),
          reason: '导出再导入后额度也恢复 ⇒ 走导出路径同样可刷');
    });
  });
}
