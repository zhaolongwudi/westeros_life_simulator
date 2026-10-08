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

  // 📌 必须用单引号插值：Dart 的反引号是 **raw string** 定界符（不支持插值），
  // 用反引号写插值会被解析成 raw string、内部 $ 不生效 ⇒ analyzer 报 7 个 error
  // （run `37760612365` 实测，错误全指向这一行；同文件既有 S12-7 测试用的也是单引号）。
  File saveFile(String saveId) => File('${tempDir.path}/save_$saveId.json');

  /// 同步读存档里的玩家名（读不出来就返回 null，绝不抛）。
  ///
  /// 【为什么要容错】`File.writeAsString` 是「先建文件、后写内容」，
  /// 理论上可能读到空文件或半个 JSON。判别式只需要「这个文件属于哪一档」，
  /// 读不出来时返回 null，让断言给出清晰失败信息而不是抛 FormatException。
  ///
  /// 📌 **必须定义在 `settleAndReadName` 之前**：局部函数不能前向引用
  /// （run `37762037029` 实测 1 个 analyze error：
  /// Local variable 'readNameSync' can't be referenced before it is declared）。
  String? readNameSync(String saveId) {
    final f = saveFile(saveId);
    if (!f.existsSync()) return null;
    try {
      final json = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      final state = json['state'] as Map<String, dynamic>;
      final player = state['player'] as Map<String, dynamic>;
      return player['name'] as String?;
    } on Object {
      return null;
    }
  }

  /// 跳过去抖定时器、等真实 IO 落盘，**并**读回某存档里的玩家名。
  ///
  /// 📌 **照抄 S12-7 的 `settleIo` 结构，一个字都没改**（它已被既有测试验证可用）：
  /// `pump(3s)` → `runAsync` 里等 80ms → `pumpAndSettle()`。
  ///
  /// 🔴 【踩坑记录：为什么读档用同步 readAsStringSync 而不是 loadGame】
  /// 我先后试过三种写法，**全部失败**（每次 3 例全红，既有 1526 例从未受影响）：
  /// ① 裸 `await Future.delayed` 轮询 → 3 例全 10 分钟 `TimeoutException`
  ///    （run `37755398940`）：fake-async 里 delay 永不推进。
  /// ② 轮询包进 `runAsync` → 3 例全 `Actual: <null>`（run `37759316690`）。
  /// ③ `runAsync` 内 `await service.loadGame(...)` → 仍然 3 例全
  ///    `Actual: <null>`（run `37761190596`）。
  /// ③ 说明 **`loadGame` 这条带内部 `await` 的调用在本测试的 `runAsync` 里返回不了**
  /// （具体机制未确认；只确认「放进 runAsync 就读不到」这一现象，不作进一步推断）。
  ///
  /// ✅ 结论：**只用同步 IO**（`existsSync` / `readAsStringSync`）读文件——
  /// 它不需要 zone、不需要 await，绕开整个 fake-async 陷阱；
  /// 「等写盘完成」交给既有的 `settleIo`（pump 3s 已让 2 秒去抖到期）。
  /// 代价是要自己解析 JSON，但存档结构固定（`{'metadata':…, 'state':…}`），
  /// 比和 fake-async 搏斗可靠得多。
  Future<String?> settleAndReadName(WidgetTester tester, String saveId) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    await tester.pumpAndSettle();
    return readNameSync(saveId);
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
      // 📌 用 settleAndReadName 而不是 existsSync：后者不等写盘完成，
      // 在 CI 上会读到「文件已建、内容未写」的空档而假红。
      expect(
        await settleAndReadName(tester, 'player_default'),
        isNotNull,
        reason: '新局应写进自己的槽 player_default',
      );
    });

    // 📌 刻意**不写**「同月内重复通知不重复落盘」这条：守卫 `_lastSavedMonth`
    // 是 S12-7 已有语义（既有 batch12_s12 已覆盖），不是 ⑪ 的核心；
    // 且 `状态` 命令（`mixin_play.dart:484`）handler 只调 `formatPlayerPanel()`，
    // 既不改状态也不 notify ⇒ 写了也是空转，测不到东西。

    test('默认开局 player.id 为 player_default（前置契约）', () {
      expect(Player.defaultPlayer().id, 'player_default');
    });
  });
}
