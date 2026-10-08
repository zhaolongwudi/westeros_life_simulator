/// Sprint 13-4 测试：修 P0 ⑤ 信件完全不进存档。
///
/// 【本文件是 S13-4 的复现测试】按接力文档第 4 条「先写能复现的失败测试再改实现」。
///
/// 【根因（实测取证，非推测）】`GameLetterMixin` 的三个字段全是内存字段：
///   `_letters`（`mixin_letter.dart:32`）、`_lastSenderId`（`:38`）、`_lastLetterMonth`（`:41`），
/// 而 `GameStateProvider.toJson` / `fromJson` **没有任何信件键**
/// ⇒ ① 读档后信件面板**整屏清空**；② 冷却键归零 ⇒ **读档后同月可再触发一封**，
///   而收信 `adjustRelation(+1)`、回信再 `+2` ⇒ **反复读档可无限刷关系**。
///
/// 【落点为什么是状态层（取证，不是风格选择）】
/// `save_service.dart:184` 与 `:261` 反序列化的静态类型是 **`GameStateProvider`，
/// 不是 `GameEngine`** ⇒ 在 mixin 里覆写 `toJson`/`applyState` 对读档**完全无效**。
/// 故照搬 S8-1 `completedEventIds` 的同构做法：字段落 `GameStateProvider`，
/// 由 `GameProviderBase` 覆写三个方法桥接回运行时侧。
///
/// 【为什么不用「跑 40 次应该能收到信」—— 接力文档 §0 第 9 条】
/// 本项目已两次因「跑 N 回合应该能等到」翻车（S4-6 零命中概率 3.5%，CI 恰好踩中）。
/// 本文件**不使用概率等待**：`maybeTriggerLetter(seed:)` 按 seed 确定性播种，
/// 故改为**枚举固定 seed 序列**找命中的那个（见 [_seedThatDelivers]）——
/// 顺序固定 ⇒ 结果确定，**要么命中要么测试明确失败，不存在 flaky**。
///
/// 【断言只锁信件与关系，不锁金币/精力/饱食】过月与事件结算都随机加减这些值
/// （`rng(seed)` 按 `progress.turnCount` 播种），锁具体数字会 flaky。
///
/// ⚠️ 本机（Android/DSH）无 dart/flutter，**本文件未在本地执行**，正确性由 CI 验证。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/providers/game_state_provider.dart';
import 'package:westeros_life_simulator/services/save_service.dart';

/// 枚举固定 seed 序列，返回第一个能触发主动来信的 seed。
///
/// 【为什么不直接写死一个 seed】写死的 seed 一旦碰上 `npc_data` 改动（候选池变化）
/// 就会静默失效。本函数把「找 seed」这件事变成**确定性枚举**：
/// 顺序固定、无随机、无概率，数据变了顶多换个 seed 命中，不会变成偶发失败。
int _seedThatDelivers() {
  for (var s = 0; s < 500; s++) {
    final e = GameEngine()..startNewGame();
    // 扩大「已结识」候选池：与若干在场 NPC 建立关系记录。
    e.updatePlayer(
      e.player.copyWith(
        relations: <String, int>{
          ...e.player.relations,
          'npc_nev': 30,
          'npc_catelyn': 30,
          'npc_robb': 30,
        },
      ),
    );
    if (e.maybeTriggerLetter(seed: s).isNotEmpty) return s;
  }
  fail(
    '500 个 seed 内没有任何一个能触发主动来信 —— '
    '这说明候选池为空或前置条件变了，本文件需要重新取证（不是概率问题）。',
  );
}

/// 收有一封主动来信的引擎（用确定性 seed 造信，不靠概率等待）。
GameEngine _engineWithLetter() {
  final engine = GameEngine()..startNewGame();
  engine.updatePlayer(
    engine.player.copyWith(
      relations: <String, int>{
        ...engine.player.relations,
        'npc_nev': 30,
        'npc_catelyn': 30,
        'npc_robb': 30,
      },
    ),
  );
  final text = engine.maybeTriggerLetter(seed: _seedThatDelivers());
  expect(text, isNotEmpty, reason: '前提：造信成功');
  expect(engine.letters, isNotEmpty, reason: '前提：letters 非空');
  return engine;
}

void main() {
  late Directory tempDir;
  late SaveService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('batch13_s4_');
    service = SaveService(saveDir: tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('S13-4 验收1：真实读档链路后信件不丢', () {
    test('存档键取自运行时对象（不是状态层那份空副本）', () {
      // 🔴 本组是**实现陷阱的锁**，不是功能锁：
      // 状态层 `GameStateProvider._letters` 与运行时 `GameLetterMixin._letters`
      // 是**两份数据**，且正常游玩时**只有运行时那份会更新**（状态层那份
      // 仅在 applyState 时被写入）。若哪天有人改成对**裸 GameStateProvider**
      // 调 toJson（而 `save_service.saveGame` 的静态参数类型恰好就是它），
      // 存出来的信件会**静默为空**。
      // 本例确认「传引擎进去」拿到的是运行时的信。
      final engine = _engineWithLetter();
      final json = engine.toJson();
      expect(json['letters'], isA<List<Object?>>());
      expect(json['letters'], hasLength(1),
          reason: '引擎 toJson 的信件必须来自运行时对象');
      expect(json['lastSenderId'], isNotNull);
      expect(json['lastLetterMonth'], isNotNull);

      // 反向锁：状态层那份此刻确实是空的（这正是上面那个陷阱的成因）。
      // 若日后有人把两份合成一份，本例会红，提示同步更新本文件的说明。
      final bare = GameStateProvider.fromJson(<String, dynamic>{
        'player': <String, dynamic>{},
        'progress': <String, dynamic>{},
      });
      expect(bare.letters, isEmpty,
          reason: '前提锁定：状态层在未被 applyState 灌入时是空的');
    });

    test('saveGame → loadGame → applyState 后信件逐条一致', () async {
      final engine = _engineWithLetter();
      final before = engine.letters;
      expect(before, hasLength(1));

      // 真实链路（与 settings_screen / home_screen 同形）
      final saveId = await service.saveGame(engine, saveId: 'letter');
      final loaded = await service.loadGame(saveId);
      expect(loaded, isNotNull);

      // ⚠️ 必须用 `loaded!`：`expect(loaded, isNotNull)` **不会**让 Dart 的
      // 空安全分析器把 `GameStateProvider?` 收窄成非空（CI 报错
      // `argument_type_not_assignable`：GameStateProvider? 不能传给 GameStateProvider）。
      // S8-1 的同款测试也是写 `loaded!.` —— 这是本项目的既有写法，不是权宜。
      final revived = GameEngine()..applyState(loaded!);
      // 🔴 判别断言：修复前 revived.letters 为空 ⇒ 失败
      expect(revived.letters, hasLength(1), reason: '读档后信件被清空（P0 ⑤ 症状①）');
      expect(revived.letters.first.senderId, before.first.senderId);
      expect(revived.letters.first.senderName, before.first.senderName);
      expect(revived.letters.first.content, before.first.content);
      expect(revived.letters.first.year, before.first.year);
      expect(revived.letters.first.month, before.first.month);
      expect(revived.letters.first.isFromNpc, isTrue);
      expect(revived.letters.first.replied, isFalse);
    });

    test('exportSave / importSave 链路同样保留（导出/导入不是例外路径）', () {
      final engine = _engineWithLetter();
      final imported = service.importSave(service.exportSave(engine));
      expect(imported, isNotNull);
      final revived = GameEngine()..applyState(imported!);
      // 🔴 修复前为空 ⇒ 失败
      expect(revived.letters, hasLength(1),
          reason: '导出再导入后信件丢失 ⇒ 玩家会丢掉整箱信件');
    });
  });

  group('S13-4 验收2：回信状态（含 replied）与待回标记一起持久化', () {
    test('已回信的信件读档后仍是「已回信」，不会重复给关系', () async {
      final engine = _engineWithLetter();
      final senderId = engine.letters.first.senderId;
      expect(engine.hasPendingLetter, isTrue, reason: '前提：有待回信');

      final relBefore = engine.npcRelation(senderId);
      final reply = engine.replyLetter();
      expect(reply, isNotEmpty, reason: '前提：回信成功');
      final relAfterReply = engine.npcRelation(senderId);
      expect(relAfterReply, greaterThan(relBefore),
          reason: '前提锁定：回信本身应当 +2 关系（否则本组断言无意义）');
      expect(engine.hasPendingLetter, isFalse, reason: '前提：回完没有待回信了');

      final saveId = await service.saveGame(engine, saveId: 'replied');
      final loaded = await service.loadGame(saveId);
      final revived = GameEngine()..applyState(loaded!);

      // 🔴 修复前 letters 为空 ⇒ 失败
      expect(revived.letters, isNotEmpty, reason: '回信记录读档后丢失');
      expect(revived.hasPendingLetter, isFalse,
          reason: '已回信的信读档后又变回「待回」⇒ 玩家可重复回信重复刷 +2 关系');
      // 🔴 漏洞回归：关系值应一并回到回信后的水平，且**再回一次拿不到关系**
      final relLoaded = revived.npcRelation(senderId);
      expect(relLoaded, relAfterReply, reason: '关系属玩家状态，本就该随存档往返');
      expect(revived.replyLetter(), isEmpty, reason: '没有待回信时不应回出内容');
      expect(revived.npcRelation(senderId), relLoaded,
          reason: '对已回信的信再点回信不应再加关系（否则可反复读档刷关系）');
    });

    test('待回信状态跨存档保留（未回的仍是待回）', () async {
      final engine = _engineWithLetter();
      final saveId = await service.saveGame(engine, saveId: 'pending');
      final loaded = await service.loadGame(saveId);
      final revived = GameEngine()..applyState(loaded!);
      // 🔴 修复前为 false ⇒ 失败
      expect(revived.hasPendingLetter, isTrue,
          reason: '未回信的信读档后不应消失（玩家会丢掉待回的那封）');
    });
  });

  group('S13-4 验收3：同月刷关系漏洞被堵住', () {
    test('读档后同月不再触发第二封主动来信', () async {
      final engine = _engineWithLetter();
      expect(engine.letters, hasLength(1), reason: '前提：只有一封');

      final saveId = await service.saveGame(engine, saveId: 'cooldown');
      final loaded = await service.loadGame(saveId);
      final revived = GameEngine()..applyState(loaded!);

      // 同月再试：应被 `_lastLetterMonth` 冷却拦下。
      // 用「另一个肯定命中的 seed」也没用——月份相同就应被冷却拦掉。
      final again = revived.maybeTriggerLetter(seed: 0);
      expect(again, isEmpty,
          reason: '读档后同月又收到一封 ⇒ 反复读档可无限刷关系（P0 ⑤ 症状②）');
      expect(revived.letters, hasLength(1), reason: '信件数不应增加');
    });

    test('跨月后仍能正常收到新信（冷却不是永久锁死）', () {
      final engine = _engineWithLetter();
      // ⚠️ 用 `advanceTime()` 而**不是** `advanceMonth()`：
      // 后者会跑完整月度管线（含信件钩子），可能自己就发了信 ⇒
      // 下面的 `maybeTriggerLetter` 断言就成了假绿。
      // `advanceTime()` 只推进时钟，不触发任何钩子（game_state_provider.dart:309）。
      engine.advanceTime();
      // 前提锁定：冷却键记的是「上次的年月」，跨月后必须与之不同，
      // 否则下面的收信断言可能只是因为「还在同月」而假绿。
      expect(engine.runtimeLastLetterMonth, isNotNull, reason: '前提：本局已收过信');
      final monthBefore = engine.runtimeLastLetterMonth!.split('-').last;
      expect(engine.progress.month.toString(), isNot(equals(monthBefore)),
          reason: '前提：advanceTime 后月份应已变化（冷却键记的是 $monthBefore）');
      // 枚举一个在**新月份**能命中的 seed
      var got = false;
      for (var s = 0; s < 500 && !got; s++) {
        if (engine.maybeTriggerLetter(seed: s).isNotEmpty) got = true;
      }
      expect(got, isTrue,
          reason: '跨月后应能再收信——若这条红，说明持久化把冷却写成了永久锁');
    });
  });

  group('S13-4 验收4：旧存档（无信件键）安全回落', () {
    test('裸 GameStateProvider.fromJson 缺信件键不抛、回落空', () {
      final state = GameStateProvider.fromJson(<String, dynamic>{
        'player': <String, dynamic>{},
        'progress': <String, dynamic>{},
      });
      expect(state, isNotNull);
      final revived = GameEngine()..applyState(state);
      expect(revived.letters, isEmpty, reason: '旧存档应回落空列表而非崩溃');
      expect(revived.hasPendingLetter, isFalse);
    });

    test('信件键类型错误（字符串 / 元素为 null）不抛且安全回落', () {
      for (final bad in <Object?>['abc', 123, <Object?>[null, 'x'], <Object?>[1, 2]]) {
        final state = GameStateProvider.fromJson(<String, dynamic>{
          'player': <String, dynamic>{},
          'progress': <String, dynamic>{},
          'letters': bad,
        });
        final revived = GameEngine()..applyState(state);
        expect(revived.letters, isEmpty,
            reason: '坏值 $bad 应被 safeObjectList 逐元素丢弃，不得抛出');
      }
    });
  });

  group('S13-4 验收5：新局必须清空信件（settings_screen 复用同一引擎）', () {
    test('startNewGame 后信件归零', () {
      final engine = _engineWithLetter();
      expect(engine.letters, isNotEmpty, reason: '前提：本局有信');
      // `settings_screen._newGame` 在**同一引擎实例**上调 startNewGame
      engine.startNewGame();
      expect(engine.letters, isEmpty,
          reason: '新局里残留上一局的信件 ⇒ 重开就白拿回信与关系');
      expect(engine.hasPendingLetter, isFalse);
    });

    test('新局后同月又能收到信（新局不该继承上一局的冷却）', () {
      final engine = _engineWithLetter();
      engine.startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          relations: <String, int>{
            ...engine.player.relations,
            'npc_nev': 30,
            'npc_catelyn': 30,
            'npc_robb': 30,
          },
        ),
      );
      var got = false;
      for (var s = 0; s < 500 && !got; s++) {
        if (engine.maybeTriggerLetter(seed: s).isNotEmpty) got = true;
      }
      expect(got, isTrue, reason: '新局应恢复收信能力');
    });
  });
}
