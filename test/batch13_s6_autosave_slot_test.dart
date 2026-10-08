/// Sprint 13 测试：S13-6 修 ⑪「局内读档后自动存档写错槽位」。
///
/// 【本批修的是什么】`GameScreen._saveSlotId` 是 `late final`，
/// 在**首帧**就把 `_engine.player.id` 算死；而设置页与主界面**共用同一 engine**
/// （`game_screen.dart:306` 传 `engine: _engine`），
/// 在设置页里载入另一个存档会 `applyState` → `_player = other._player`
/// （`game_state_provider.dart:598`）⇒ 运行时 `player.id` 已变成被载入档的 id，
/// 但落盘仍用冻结的 `_saveSlotId`（`game_screen.dart:146`）
/// ⇒ **旧档文件被新档内容整体覆盖，旧进度丢失**。
///
/// 【关键判别式】不能只断言「新槽文件存在」——那在缺陷下也成立
/// （只是多了一个错槽）。必须断言**旧档文件内容未被改写**，
/// 否则测试会假绿（与 S13-4/S13-5 踩过的「跨月用 advanceTime 而非 advanceMonth」同源）。
///
/// 【既有约定，照抄 batch12_s12_save_autosave_test.dart】
/// - 注入内存版 `SaveService` 只是为了避开设置页 `initState` 的真实文件 IO；
///   本卡断言的是**真实文件**，故一律用真 `SaveService(saveDir: tempDir)`。
/// - 去抖定时器 + 真实 IO 必须走 `runAsync`，只 `pumpAndSettle` 会假红。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/models/player.dart';
import 'package:westeros_life_simulator/screens/game_screen.dart';
import 'package:westeros_life_simulator/services/save_service.dart';

void main() {
  late Directory tempDir;
  late SaveService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('s13_6_slot_');
    service = SaveService(saveDir: tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// 跳过去抖定时器并让**真实文件 IO** 完成（照抄 S12-7 的 `settleIo`）。
  Future<void> settleIo(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    await tester.pumpAndSettle();
  }

  File saveFile(String saveId) => File('${tempDir.path}/save_$saveId.json');

  /// 存档文件里的玩家名（用来判断「这个文件属于哪一档」）。
  String? playerNameInFile(String saveId) {
    final f = saveFile(saveId);
    if (!f.existsSync()) return null;
    final json = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    final state = json['state'] as Map<String, dynamic>;
    final player = state['player'] as Map<String, dynamic>;
    return player['name'] as String?;
  }

  group('S13-6 ⑪ 自动存档槽位跟随当前 player.id', () {
    testWidgets('局内载入另一存档后跨月：写新槽，旧档内容不被改写',
        (tester) async {
      // 旧档：id = player_old，名字「旧档角色」
      final engine = GameEngine()
        ..startNewGame(
          player: Player.defaultPlayer().copyWith(id: 'player_old', name: '旧档角色'),
        );
      // 🔴 【顺序坑】必须先 pumpWidget 再 resolveCommand：自动存档挂在
      // GameScreen 的监听器上，widget 还不存在时 notify 没有任何接收者，
      // 定时器根本不会被安排（S12-7 测试「刚开局不该立即落盘」正是这条语义）。
      // 我第一版把 `过月` 写在 pumpWidget 之前 ⇒ 旧档压根没落盘 ⇒ 前置断言红。
      await tester.pumpWidget(
        MaterialApp(home: GameScreen(engine: engine, saveService: service)),
      );
      await tester.pump();
      expect(saveFile('player_old').existsSync(), isFalse, reason: '刚开局不该立即落盘');
      // 让旧档真的落一次盘，之后才谈「不被覆盖」
      engine.resolveCommand('过月');
      await settleIo(tester);
      expect(saveFile('player_old').existsSync(), isTrue, reason: '前置：旧档应已落盘');
      expect(playerNameInFile('player_old'), '旧档角色');

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

      // 🔴 判别式：旧档文件必须**仍是旧档角色**，不能被写成新档角色
      expect(
        playerNameInFile('player_old'),
        '旧档角色',
        reason: '旧档文件内容被自动存档覆盖了（这正是 ⑪ 号缺陷）',
      );
      // 新档自己的槽应当被写入
      expect(
        playerNameInFile('player_new'),
        '新档角色',
        reason: '自动存档应写进新载入档自己的槽',
      );
    });

    testWidgets('局内「新游戏」后跨月：不写旧 id 槽', (tester) async {
      final engine = GameEngine()
        ..startNewGame(
          player: Player.defaultPlayer()
              .copyWith(id: 'player_old', name: '旧档角色'),
        );
      // 【顺序坑】同第 1 例：先 pumpWidget 再 resolveCommand，否则无人接收 notify
      await tester.pumpWidget(
        MaterialApp(home: GameScreen(engine: engine, saveService: service)),
      );
      await tester.pump();
      // 让旧档真的落盘，否则「旧槽未被覆盖」无从谈起
      engine.resolveCommand('过月');
      await settleIo(tester);
      expect(playerNameInFile('player_old'), '旧档角色', reason: '前置：旧档已落盘');

      // 设置页「新游戏」路径：engine.startNewGame() → id 变 'player_default'
      engine.startNewGame();
      expect(engine.player.id, 'player_default', reason: '前置：新局 id 应为默认');

      engine.resolveCommand('过月');
      await settleIo(tester);

      // 🔴 判别式：旧槽必须**仍属旧档**，不能被写成新局内容
      expect(
        playerNameInFile('player_old'),
        '旧档角色',
        reason: '旧 id 槽被新局内容覆盖了（这正是 ⑪ 号缺陷）',
      );
      expect(
        saveFile('player_default').existsSync(),
        isTrue,
        reason: '新局应写进自己的槽 player_default',
      );
    });

    testWidgets('同月内载入另一存档不触发落盘（守卫语义不变）', (tester) async {
      final engine = GameEngine()
        ..startNewGame(
          player: Player.defaultPlayer().copyWith(id: 'player_old'),
        );
      // 【顺序坑】同第 1 例
      await tester.pumpWidget(
        MaterialApp(home: GameScreen(engine: engine, saveService: service)),
      );
      await tester.pump();
      engine.resolveCommand('过月');
      await settleIo(tester);
      expect(saveFile('player_old').existsSync(), isTrue, reason: '前置：旧档已落盘');

      // 只 applyState，不跨月
      final otherEngine = GameEngine()
        ..startNewGame(
          player: Player.defaultPlayer().copyWith(id: 'player_new'),
        );
      engine.applyState(otherEngine);
      await settleIo(tester);

      expect(saveFile('player_new').existsSync(), isFalse,
          reason: '未跨月不该触发自动存档');
    });

    test('默认开局 player.id 为 player_default（前置契约）', () {
      expect(Player.defaultPlayer().id, 'player_default');
    });
  });
}
