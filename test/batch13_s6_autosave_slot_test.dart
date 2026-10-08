/// Sprint 13 测试：S13-6 修 ⑪「局内读档后自动存档写错槽位」。
///
/// 【本批修的是什么】`GameScreen._saveSlotId` 是 `late final`，
/// 在**首帧**就把 `_engine.player.id` 算死；而设置页与主界面**共用同一 engine**
/// （`game_screen.dart:306` 传 `engine: _engine`），
/// 在设置页里载入另一个存档会 `applyState` → `_player = other._player`
/// （`game_state_provider.dart:598`）⇒ 运行时 `player.id` 已变成被载入档的 id，
/// 但落盘仍用冻结的 `_saveSlotId`（`game_screen.dart:154`）
/// ⇒ **旧档文件被新档内容整体覆盖，旧进度丢失**。
/// 修法就一行：`late final String _saveSlotId` → `String get _saveSlotId => _engine.player.id;`
///
/// 【关键判别式】不能只断言「新槽文件存在」——那在缺陷下也成立
/// （只是多了一个错槽）。必须断言**旧档内容未被改写**，否则测试会假绿。
///
/// ══════════════════════════════════════════════════════════════
/// 🔴🔴 本文件换了**第三次**断言方式，前两种都被 CI 证伪（见下）。
/// ══════════════════════════════════════════════════════════════
/// 【为什么最终改用内存版 SaveService】
/// 前两种都建立在「真 `SaveService(saveDir: tempDir)` + 读文件内容」之上，
/// 连续 10 次 CI 红。最后一次诊断（run `37764745090`）给出了**决定性证据**：
///     轮询 1 次仍读不到 player_old：exists=true size=0
/// `exists=true` 而 `size=0` ⇒ `File.writeAsString` **只创建了文件、内容从未写入**
/// ⇒ 在 `testWidgets` 的 fake-async 域里，那个真实的 `await writeAsString`
/// 根本不会完成。轮询多少次都没用，因为要等的那件事本身不会发生。
/// 而既有 S12-7 测试为什么一直绿？它**只断言 `existsSync()`**——
/// 那个恰好只要求「文件被创建」，正好是 fake-async 下唯一能保证的事。
/// ⇒ 教训：**照抄既有测试的写法不够，还要照抄它断言的内容边界**。
/// 内存版绕开一切 zone 问题：记录「哪个 saveId 被写了什么 player.name」，
/// 判别式直接读这个记录，且用的正是既有测试里 `_MemorySaveService` 的同一套路。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/models/player.dart';
import 'package:westeros_life_simulator/providers/game_state_provider.dart';
import 'package:westeros_life_simulator/screens/game_screen.dart';
import 'package:westeros_life_simulator/services/save_service.dart';

/// 内存版存档服务：**只记「哪个槽被写了、写的角色名是谁」**。
///
/// 【为什么够用】本批要断言的只有一件事——
/// 自动存档用的槽 id 是不是**当前** `player.id`。
/// 记下 `saveId → player.name` 就足以判别，不需要真的序列化到磁盘。
class _RecordingSaveService extends SaveService {
  _RecordingSaveService() : super(saveDir: '/tmp/nonexistent_s13_6_dir');

  /// saveId → 写入时的 player.name。按写入顺序累加（同一 id 会被覆盖）。
  final Map<String, List<String>> writes = <String, List<String>>{};

  @override
  Future<String> saveGame(GameStateProvider state, {String? saveId}) async {
    final id = saveId ?? DateTime.now().millisecondsSinceEpoch.toString();
    (writes[id] ??= <String>[]).add(state.player.name);
    return id;
  }
}

void main() {
  late _RecordingSaveService service;

  setUp(() {
    service = _RecordingSaveService();
  });

  /// 跳过去抖定时器（2 秒）并让异步落盘完成。
  ///
  /// 📌 与 `batch12_s12_save_autosave_test.dart:68` 的 `settleIo` 同构
  /// （`pump(3s)` → `runAsync` 等 80ms → `pumpAndSettle`），只是这里不需要
  /// 再等真实文件 IO——内存版写入不碰磁盘。
  Future<void> settleIo(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    await tester.pumpAndSettle();
  }

  /// 某槽被写入过的角色名（没写过则空列表）。
  List<String> namesIn(String saveId) => service.writes[saveId] ?? <String>[];

  group('S13-6 ⑪ 自动存档槽位跟随当前 player.id', () {
    testWidgets('局内载入另一存档后跨月：写新槽，旧档不被改写', (tester) async {
      // 旧档：id = player_old，名字「旧档角色」
      final engine = GameEngine()
        ..startNewGame(
          player: Player.defaultPlayer().copyWith(id: 'player_old', name: '旧档角色'),
        );
      // 🔴 【顺序坑】必须先 pumpWidget 再 resolveCommand：自动存档挂在
      // GameScreen 的监听器上，widget 还不存在时 notify 没有任何接收者，
      // 定时器根本不会被安排（S12-7「刚开局不该立即落盘」正是这条语义）。
      // 我第一版把 `过月` 写在 pumpWidget 之前 ⇒ 旧档压根没落盘 ⇒ 前置断言红。
      await tester.pumpWidget(
        MaterialApp(home: GameScreen(engine: engine, saveService: service)),
      );
      await tester.pump();
      expect(service.writes, isEmpty, reason: '刚开局不该立即落盘');

      // 让旧档真的落一次盘，之后才谈「不被覆盖」
      engine.resolveCommand('过月');
      await settleIo(tester);
      expect(namesIn('player_old'), ['旧档角色'], reason: '前置：旧档应已落盘');

      // ---- 模拟设置页「载入另一个存档」：同一个 engine 上 applyState ----
      // 【与 settings_screen.dart:122 完全同形】那边是 engine.applyState(state)，
      // state 来自 loadGame（裸 GameStateProvider）；这里直接用另一个 GameEngine
      // （GameStateProvider 子类）代替，语义一致且不必绕 fromJson。
      final otherEngine = GameEngine()
        ..startNewGame(
          player: Player.defaultPlayer().copyWith(id: 'player_new', name: '新档角色'),
        );
      otherEngine.resolveCommand('过月');
      engine.applyState(otherEngine);
      expect(engine.player.id, 'player_new', reason: '前置：applyState 后 id 已换');

      // 跨月 → 触发自动存档
      engine.resolveCommand('过月');
      await settleIo(tester);

      // 🔴 判别式：旧槽**最后一次**写入的内容必须仍是旧档角色。
      // 缺陷下这里会是 ['旧档角色', '新档角色'] —— 旧档被新档覆盖。
      expect(namesIn('player_old'), ['旧档角色'],
          reason: '旧档槽被新档内容覆盖了（这正是 ⑪ 号缺陷）');
      // 新档自己的槽应当被写入
      expect(namesIn('player_new'), ['新档角色'],
          reason: '自动存档应写进新载入档自己的槽');
    });

    testWidgets('局内「新游戏」后跨月：不写旧 id 槽', (tester) async {
      final engine = GameEngine()
        ..startNewGame(
          player: Player.defaultPlayer().copyWith(id: 'player_old', name: '旧档角色'),
        );
      // 【顺序坑】同第 1 例：先 pumpWidget 再 resolveCommand，否则无人接收 notify
      await tester.pumpWidget(
        MaterialApp(home: GameScreen(engine: engine, saveService: service)),
      );
      await tester.pump();
      engine.resolveCommand('过月');
      await settleIo(tester);
      expect(namesIn('player_old'), ['旧档角色'], reason: '前置：旧档应已落盘');

      // 设置页「新游戏」路径：engine.startNewGame() → id 变 'player_default'
      engine.startNewGame();
      expect(engine.player.id, 'player_default', reason: '前置：新局 id 应为默认');

      engine.resolveCommand('过月');
      await settleIo(tester);

      // 🔴 判别式：旧槽必须**仍只有旧档那一次写入**
      expect(namesIn('player_old'), ['旧档角色'],
          reason: '旧 id 槽被新局内容覆盖了（这正是 ⑪ 号缺陷）');
      expect(namesIn('player_default'), isNotEmpty,
          reason: '新局应写进自己的槽 player_default');
    });

    // 📌 刻意**不写**「同月内重复通知不重复落盘」这条：守卫 `_lastSavedMonth`
    // 是 S12-7 已有语义（既有 batch12_s12 已覆盖 7 例），不是 ⑪ 的核心；
    // 且 `状态` 命令（`mixin_play.dart:484`）handler 只调 `formatPlayerPanel()`，
    // 既不改状态也不 notify ⇒ 写出来也是空转，测不到东西。

    test('默认开局 player.id 为 player_default（前置契约）', () {
      expect(Player.defaultPlayer().id, 'player_default');
    });
  });
}