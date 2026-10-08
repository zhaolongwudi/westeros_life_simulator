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

  File saveFile(String saveId) => File(`${tempDir.path}/save_$saveId.json`);

  /// 跳过去抖定时器、等真实 IO 落盘，**并**读回某存档里的玩家名。
  ///
  /// 【为什么等待与读回必须同处一个 runAsync】`testWidgets` 跑在 fake-async：
  /// 真实文件 IO 与真实计时只在 `tester.runAsync` 这一个「真实域」里有效。
  /// 我第二版把「等 IO」放进 settleIo 的 runAsync、又另起一次 runAsync 去轮询，
  /// 结果 3 例全 `Actual: <null>`（run `37759316690`）——第二次 runAsync
  /// 并不可靠。合成一次就没有这个变量了。
  ///
  /// 【为什么用 loadGame 而不是自己 jsonDecode】`File.writeAsString` 是
  /// 「先建文件、后写内容」，`existsSync()` 为 true 时内容可能还是空的
  /// ⇒ 手写解析会抛 `FormatException: Unexpected end of input`
  /// （run `37754733172` 实测）。`loadGame` 内部 `await file.exists()` +
  /// `_readSaveMap` 在真实异步域，且自带「坏档 ⇒ 返回 null」的容错。
  Future<String?> settleAndReadName(WidgetTester tester, String saveId) async {
    await tester.pump(const Duration(seconds: 3));
    String? name;
    await tester.runAsync(() async {
      // 去抖定时器 2s + 写盘余量，给足避免读到半个文件。
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final state = await service.loadGame(saveId);
      name = state?.player.name;
    });
    await tester.pumpAndSettle();
    return name;
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
      expect(await settleAndReadName(tester, 'player_old'), '旧档角色', reason: '前置：旧档已落盘');

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

      // 🔴 判别式：旧档文件必须**仍是旧档角色**，不能被写成新档角色
      expect(
        await settleAndReadName(tester, 'player_old'),
        '旧档角色',
        reason: '旧档文件内容被自动存档覆盖了（这正是 ⑪ 号缺陷）',
      );
      // 新档自己的槽应当被写入
      expect(
        await settleAndReadName(tester, 'player_new'),
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
      expect(await settleAndReadName(tester, 'player_old'), '旧档角色', reason: '前置：旧档已落盘');

      // 设置页「新游戏」路径：engine.startNewGame() → id 变 'player_default'
      engine.startNewGame();
      expect(engine.player.id, 'player_default', reason: '前置：新局 id 应为默认');

      engine.resolveCommand('过月');

      // 🔴 判别式：旧槽必须**仍属旧档**，不能被写成新局内容
      expect(
        await settleAndReadName(tester, 'player_old'),
        '旧档角色',
        reason: '旧 id 槽被新局内容覆盖了（这正是 ⑪ 号缺陷）',
      );
      expect(
        saveFile('player_default').existsSync(),
        isTrue,
        reason: '新局应写进自己的槽 player_default',
      );
    });

    testWidgets('同月内的重复通知不重复落盘（守卫语义不变）', (tester) async {
      final engine = GameEngine()
        ..startNewGame(
          player: Player.defaultPlayer()
              .copyWith(id: 'player_old', name: '旧档角色'),
        );
      // 【顺序坑】同第 1 例
      await tester.pumpWidget(
        MaterialApp(home: GameScreen(engine: engine, saveService: service)),
      );
      await tester.pump();
      engine.resolveCommand('过月');
      expect(await settleAndReadName(tester, 'player_old'), '旧档角色', reason: '前置：旧档已落盘');

      // 同月内多次 notify（「状态」不消耗回合）⇒ `_lastSavedMonth` 相同 ⇒ 不落盘。
      // 🔴 【原前提写错】我第一版写的是「同月内载入另一存档不触发落盘」，
      // 但 `applyState` 换掉的是**整个 progress**（年月一起换），并不是同月，
      // 所以那次会真的排程落盘。守卫真正挡的是「同月内的重复通知」。
      // 📌 循环里**只 pump，不做 settleAndReadName**：后者每次 `pump(3s)`，
      // 会推进 fake 时钟 3 秒，足以让 2 秒去抖定时器到期 ⇒ 反而自己触发了落盘，
      // 断言自相矛盾。改为循环结束后统一读回一次。
      // 📌 判据比对**整个 toJson**而非只看名字：守卫若失效，重写的是完整状态，
      // 只比名字会漏判。
      final snapshotBefore = saveFile('player_old').readAsStringSync();
      for (var i = 0; i < 3; i++) {
        engine.resolveCommand('状态');
        await tester.pump();
      }
      expect(saveFile('player_old').readAsStringSync(), snapshotBefore,
          reason: '同月内的重复通知不该重写存档');
    });

    test('默认开局 player.id 为 player_default（前置契约）', () {
      expect(Player.defaultPlayer().id, 'player_default');
    });
  });
}
