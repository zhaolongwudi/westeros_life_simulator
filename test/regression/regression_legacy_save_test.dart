/// M6b 跨批次回归套件 · 旧档加载（regression_legacy_save_test.dart）。
///
/// 目的：把 M1 存档契约的「分块单元测试」串成**端到端回归**：
/// 历史版本存档（无 schemaVersion / 缺字段 / 半残）加载后，
/// 不仅能被迁移解析，还能**真正进引擎继续玩**（执行指令、过月、存档往返）。
///
/// 与 m1_save_migration_test 的区别：
/// - m1 验证「解析不抛 + 字段默认值」；
/// - 本文件验证「加载后引擎可运行、可存档、状态不丢」。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/models/player.dart';
import 'package:westeros_life_simulator/services/save_migration.dart';
import 'package:westeros_life_simulator/services/save_service.dart';

/// 构造一个「Batch 10-19 时代」的旧档（无 schemaVersion、缺 10-17/10-18 新字段）。
Map<String, dynamic> legacySaveV0({String saveId = 'legacy'}) {
  return {
    'metadata': {
      'saveId': saveId,
      'playerName': '琼恩·雪诺',
      'saveTime': '2026-09-26T10:00:00.000',
      'year': 283,
      'month': 7,
      'turnCount': 12,
      // 注意：无 schemaVersion
    },
    'state': {
      'player': {
        'id': 'player_jon',
        'name': '琼恩·雪诺',
        'identity': 'noble',
        'familyId': 'family_stark',
        'age': 20,
        'gender': 'male',
        'locationId': 'location_winterfell',
        'gold': 320,
        'reputation': 55,
        'skills': <String, int>{'sword': 4, 'stealth': 2},
        'attributes': <String, int>{'strength': 5, 'perception': 6},
        'inventory': <String>['item_sword'],
        'relations': <String, int>{'npc_sam': 60},
        'flags': <String, bool>{'isAlive': true, 'isMarried': false},
        'health': 90,
        'energy': 70,
        'hunger': 40,
        'title': '',
        'house': '史塔克',
        // 缺 children / spouse / childRearing / generationRecords / activeTasks
      },
      'progress': {
        'year': 283,
        'month': 7,
        'season': 'summer',
        'era': '征服纪元',
        'turnCount': 12,
      },
      'history': <Map<String, dynamic>>[],
      'currentEvent': null,
      'isGameActive': true,
      'isGameOver': false,
    },
  };
}

void main() {
  late Directory tempDir;
  late SaveService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('m6b_legacy_');
    service = SaveService(saveDir: tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('M6b 旧档加载 → 引擎续玩', () {
    test('v0 旧档加载后：直接进引擎，状态/工作/过月指令可执行', () async {
      // 写入旧档 → loadGame → 迁移 → 用 GameStateProvider 恢复引擎
      final raw = legacySaveV0();
      final file = File('${tempDir.path}/save_legacy.json');
      await file.writeAsString(jsonEncode(raw));

      final loaded = await service.loadGame('legacy');
      expect(loaded, isNotNull, reason: '旧档应能加载');

      // 引擎续玩：用加载的状态启动
      final engine = GameEngine(
        player: loaded!.player,
        progress: loaded.progress,
        history: loaded.history,
        currentEvent: loaded.currentEvent,
        isGameActive: loaded.isGameActive,
        isGameOver: loaded.isGameOver,
      );

      // 旧档字段回落默认值（10-17 之后新增字段为空）
      expect(engine.player.children, isEmpty);
      expect(engine.player.spouse, isNull);

      // 状态指令可执行且保留旧档数据
      final status = engine.resolveCommand('状态');
      expect(status.text, contains('琼恩·雪诺'));
      expect(status.text, contains('320'));

      // 工作指令可执行（消耗精力、赚金币），不崩
      final work = engine.resolveCommand('工作');
      expect(work.text, contains('挣得'));

      // 过月推进：时间前进一个月
      final beforeYear = engine.progress.year;
      final beforeMonth = engine.progress.month;
      final adv = engine.resolveCommand('过月');
      expect(adv.consumedTurn, isTrue);
      if (beforeMonth < 12) {
        expect(engine.progress.month, beforeMonth + 1);
      } else {
        expect(engine.progress.year, beforeYear + 1);
        expect(engine.progress.month, 1);
      }
    });

    test('v0 旧档加载后：存档往返保留加载到的数据', () async {
      final raw = legacySaveV0();
      final file = File('${tempDir.path}/save_legacy2.json');
      await file.writeAsString(jsonEncode(raw));

      final loaded = await service.loadGame('legacy2');
      expect(loaded, isNotNull);
      final engine = GameEngine(
        player: loaded!.player,
        progress: loaded.progress,
        history: loaded.history,
        currentEvent: loaded.currentEvent,
        isGameActive: loaded.isGameActive,
        isGameOver: loaded.isGameOver,
      );

      // 玩两步：工作 + 过月
      engine.resolveCommand('工作');
      engine.resolveCommand('过月');

      // 用 SaveService 保存当前引擎状态
      final saveId = await service.saveGame(engine, saveId: 'roundtrip');
      final restored = await service.loadGame(saveId);
      expect(restored, isNotNull);
      expect(restored!.player.name, '琼恩·雪诺');
      expect(restored.player.gold, engine.player.gold);
      expect(restored.progress.turnCount, engine.progress.turnCount);
      expect(restored.isGameActive, isTrue);
    });

    test('无 health/energy/hunger 字段的更老档（Batch 10-1 前）加载后默认值完整', () async {
      // 模拟 Batch 10-1 之前的存档：根本没有生存三维字段
      final raw = legacySaveV0(saveId: 'oldest');
      (raw['state'] as Map<String, dynamic>)['player'] =
          <String, dynamic>{
            'id': 'player_old',
            'name': '艾德',
            'identity': 'soldier',
            'familyId': 'family_stark',
            'age': 35,
            'gender': 'male',
            'locationId': 'location_winterfell',
            'gold': 50,
            'reputation': 30,
            'skills': <String, int>{'sword': 5},
            'attributes': <String, int>{},
            'inventory': <String>[],
            'relations': <String, int>{},
            'flags': <String, bool>{'isAlive': true},
          };
      final file = File('${tempDir.path}/save_oldest.json');
      await file.writeAsString(jsonEncode(raw));

      final loaded = await service.loadGame('oldest');
      expect(loaded, isNotNull);
      final player = loaded!.player;
      // 生存三维回落默认值（Player 构造器默认 health=100/energy=100/hunger=0）
      expect(player.health, 100);
      expect(player.energy, 100);
      expect(player.hunger, 0);
      expect(player.identity, PlayerIdentity.soldier);
      // 引擎可运行
      final engine = GameEngine(
        player: player,
        progress: loaded.progress,
        history: loaded.history,
        currentEvent: loaded.currentEvent,
        isGameActive: loaded.isGameActive,
        isGameOver: loaded.isGameOver,
      );
      final status = engine.resolveCommand('状态');
      expect(status.text, contains('艾德'));
    });

    test('半残档（state 缺 player/progress）加载不崩，引擎回退默认开局', () async {
      final raw = <String, dynamic>{
        'metadata': <String, dynamic>{
          'saveId': 'half',
          'playerName': '无名者',
          'saveTime': '2026-09-26T10:00:00.000',
          'year': 283,
          'month': 3,
          'turnCount': 0,
          'schemaVersion': kSaveSchemaVersion,
        },
        'state': <String, dynamic>{'history': <Map<String, dynamic>>[]},
      };
      final file = File('${tempDir.path}/save_half.json');
      await file.writeAsString(jsonEncode(raw));

      final loaded = await service.loadGame('half');
      expect(loaded, isNotNull, reason: '半残档应退化为默认开局而非崩');
      expect(loaded!.player.name, isNotEmpty);
      expect(loaded.progress.year, 283);
      final engine = GameEngine(
        player: loaded.player,
        progress: loaded.progress,
        history: loaded.history,
        currentEvent: loaded.currentEvent,
        isGameActive: loaded.isGameActive,
        isGameOver: loaded.isGameOver,
      );
      expect(engine.resolveCommand('状态').text, contains('岁'));
    });
  });
}
