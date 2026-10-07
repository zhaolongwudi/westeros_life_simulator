/// Sprint 12 测试：存档体系收口（S12-7）。
///
/// 【本批修的是什么】三个互相叠加的 P0：
/// ① **零自动存档** —— `saveGame` 唯一调用方是设置页按钮，玩到一半退出全丢；
/// ② **每存一次新建一个槽** —— `saveGame` 的 saveId 默认取毫秒时间戳，
///    连按 N 次保存 = N 个槽；而自动存档若沿用该默认，会每次刷一个新槽；
/// ③ **首页进设置会误存空档并顶掉「继续游戏」** —— 设置页在 `engine == null`
///    时隐式 `new GameEngine()..startNewGame()`，且保存按钮无条件显示；
///    `listSaves` 按时间倒序、首页「继续游戏」取 `saves.first`
///    ⇒ 玩家真进度被一个空档顶掉。
///
/// 【修法】自动存档以 `player.id` 为槽 id（同 id 覆盖、不增殖），
/// 只在「年·月」变化时落盘；设置页无引擎时不 new 局、不给存档按钮。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/models/player.dart';
import 'package:westeros_life_simulator/screens/game_screen.dart';
import 'package:westeros_life_simulator/screens/settings_screen.dart';
import 'package:westeros_life_simulator/services/save_service.dart';

/// 内存版存档服务（**仅用于 widget 测试**）。
///
/// 【为什么设置页的 widget 测试不能用真实 SaveService】
/// `_SettingsScreenState.initState` 会 `await _saveService.listSaves()`——
/// 那是**真实文件 IO**，跑在 fake-async 之外，`pumpAndSettle` 永远等不到它
/// 结束 ⇒ `pumpAndSettle timed out`。既有测试（batch5/batch8/batch10_60）
/// 一律注入内存版，本文件必须照此约定（顺带也让断言不依赖磁盘）。
class _MemorySaveService extends SaveService {
  _MemorySaveService() : super(saveDir: '/tmp/nonexistent_s12_widget_dir');

  @override
  Future<List<SaveMetadata>> listSaves() async => <SaveMetadata>[];
}

void main() {
  late Directory tempDir;
  late SaveService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('s12_save_');
    service = SaveService(saveDir: tempDir.path);
    // 设置页 initState 会读 SharedPreferences（AI 配置），测试须 mock。
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// 存档目录里的 `save_*.json` 个数（不含 .corrupted）。
  Future<int> saveFileCount() async {
    final files = tempDir.listSync().whereType<File>();
    return files.where((f) => f.path.endsWith('.json')).length;
  }

  /// 跳过去抖定时器并让**真实文件 IO** 完成。
  ///
  /// 【为什么要 runAsync】`_doAutoSave` 里的 `File.writeAsString` 是真实异步 IO，
  /// 跑在 fake-async 之外；只 `pumpAndSettle` 可能断言时文件还没落盘 ⇒ 假红。
  Future<void> settleIo(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    await tester.pumpAndSettle();
  }

  group('S12-7 自动存档', () {
    testWidgets('推进一个月后自动落盘到 player.id 槽', (tester) async {
      final engine = GameEngine()..startNewGame();
      await tester.pumpWidget(
        MaterialApp(home: GameScreen(engine: engine, saveService: service)),
      );
      await tester.pump();
      expect(await saveFileCount(), 0, reason: '刚开局不该立即落盘');

      // 推进一个月（消耗回合的指令）→ 触发 notify → 安排自动存档
      engine.resolveCommand('过月');
      await settleIo(tester);

      expect(await saveFileCount(), 1, reason: '跨月应自动存档一次');
      final id = engine.player.id;
      final file = File('${tempDir.path}/save_$id.json');
      expect(file.existsSync(), isTrue, reason: '槽 id 应为 player.id = $id');
    });

    testWidgets('同月内多次改动不增殖存档槽（②号缺陷）', (tester) async {
      final engine = GameEngine()..startNewGame();
      await tester.pumpWidget(
        MaterialApp(home: GameScreen(engine: engine, saveService: service)),
      );
      await tester.pump();

      for (var i = 0; i < 3; i++) {
        engine.resolveCommand('过月');
        await settleIo(tester);
      }
      // 3 次跨月，但始终是**同一个槽**被覆盖 ⇒ 只有 1 个文件
      expect(await saveFileCount(), 1,
          reason: '自动存档必须覆盖同一槽，而不是每次新建');
    });

    testWidgets('同月内的非时间改动不触发落盘', (tester) async {
      final engine = GameEngine()..startNewGame();
      await tester.pumpWidget(
        MaterialApp(home: GameScreen(engine: engine, saveService: service)),
      );
      await tester.pump();
      // 「状态」不消耗回合，不该触发存档
      engine.resolveCommand('状态');
      await settleIo(tester);
      expect(await saveFileCount(), 0, reason: '未跨月不该落盘');
    });
  });

  group('S12-7 设置页不再误存空档（③号缺陷）', () {
    testWidgets('engine == null 时不显示保存/导出/导入/新游戏', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: SettingsScreen(saveService: _MemorySaveService())),
      );
      await tester.pumpAndSettle();

      expect(find.text('尚未开始游戏'), findsOneWidget,
          reason: '应明确告知尚未开始游戏');
      expect(find.text('保存'), findsNothing);
      expect(find.text('导出'), findsNothing);
      expect(find.text('导入'), findsNothing);
      expect(find.text('新游戏'), findsNothing);
    });

    testWidgets('engine == null 时点开也不产生存档', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: SettingsScreen(saveService: _MemorySaveService())),
      );
      await tester.pumpAndSettle();
      // 无存档按钮 ⇒ 无从触发保存；目录应保持空
      expect(await saveFileCount(), 0);
    });

    testWidgets('有引擎时存档按钮照常出现', (tester) async {
      final engine = GameEngine()..startNewGame();
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(engine: engine, saveService: _MemorySaveService()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('尚未开始游戏'), findsNothing);
      expect(find.text('保存'), findsOneWidget);
      expect(find.text('导出'), findsOneWidget);
      expect(find.text('导入'), findsOneWidget);
    });
  });

  group('S12-7 存档槽 id 与 player.id 一致', () {
    test('自动存档用的槽就是玩家 id（读档后不换槽）', () async {
      final player = Player.defaultPlayer().copyWith(id: 'player_fixed_123');
      // 【坑】必须走 startNewGame(player:) —— 构造函数的 player 参数会被
      // 无参 startNewGame() 里的 `_player = player ?? Player.defaultPlayer()`
      // 覆盖掉（game_state_provider.dart:250），结果又变回 player_default。
      final engine = GameEngine()..startNewGame(player: player);
      expect(engine.player.id, 'player_fixed_123');
      final id = await service.saveGame(engine, saveId: engine.player.id);
      expect(id, 'player_fixed_123');

      // 读回来再存，仍是同一个槽
      final loaded = await service.loadGame('player_fixed_123');
      expect(loaded, isNotNull);
      final id2 = await service.saveGame(loaded!, saveId: loaded.player.id);
      expect(id2, 'player_fixed_123', reason: '读档后 player.id 不变 ⇒ 不换槽');
      expect(await saveFileCount(), 1);
    });
  });
}