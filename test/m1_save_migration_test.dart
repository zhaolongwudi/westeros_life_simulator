/// M1 存档契约回归测试（Batch 10-26）。
///
/// 覆盖 docs/milestones/M1-存档契约.md 的全部契约：
/// 1. 无 schemaVersion 的 Batch 10-19 风格旧档可加载，新字段取默认值
/// 2. schemaVersion 过高 → UnsupportedSaveVersionException
/// 3. 乱码文件 → listSaves 跳过 + 改名 .corrupted
/// 4. 保存→加载往返关键字段全等
/// 5. 错误类型字段不抛 + 取默认值
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/models/event.dart';
import 'package:westeros_life_simulator/models/marital.dart';
import 'package:westeros_life_simulator/models/player.dart';
import 'package:westeros_life_simulator/providers/game_state_provider.dart';
import 'package:westeros_life_simulator/services/save_migration.dart';
import 'package:westeros_life_simulator/services/save_service.dart';

void main() {
  late Directory tempDir;
  late SaveService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('m1_save_');
    service = SaveService(saveDir: tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// 构造 Batch 10-19 风格旧档（无 schemaVersion，Player 缺 10-17/10-18 新字段）。
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
          // 注意：缺 children / spouse / childRearing /
          // generationRecords / activeTasks（均为 10-14 之后新增）
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

  /// 把一张 Map 存成磁盘文件（模拟真实存档文件）。
  Future<void> writeSaveFile(String saveId, Map<String, dynamic> data) async {
    final file = File('${tempDir.path}/save_$saveId.json');
    await file.writeAsString(jsonEncode(data));
  }

  group('M1-T01 schemaVersion 写入', () {
    test('新保存的存档 metadata 含 schemaVersion', () async {
      final state = GameStateProvider();
      state.startNewGame();
      await service.saveGame(state, saveId: 'v1');

      final file = File('${tempDir.path}/save_v1.json');
      final data =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final metadata = data['metadata'] as Map<String, dynamic>;
      expect(metadata['schemaVersion'], kSaveSchemaVersion);
      expect(metadata['schemaVersion'], 1);
    });

    test('导出的存档字符串含 schemaVersion', () {
      final state = GameStateProvider();
      state.startNewGame();
      final exported = service.exportSave(state);
      final data = jsonDecode(exported) as Map<String, dynamic>;
      final metadata = data['metadata'] as Map<String, dynamic>;
      expect(metadata['schemaVersion'], kSaveSchemaVersion);
    });

    test('SaveMetadata 默认 schemaVersion 为当前版本', () {
      const metadata = SaveMetadata(
        saveId: 'x',
        playerName: 'n',
        saveTime: 't',
        year: 283,
        month: 1,
        turnCount: 0,
      );
      expect(metadata.schemaVersion, kSaveSchemaVersion);
      expect(metadata.toJson()['schemaVersion'], kSaveSchemaVersion);
    });
  });

  group('M1-T03 迁移机制', () {
    test('无 schemaVersion 视为 v0 并升级到当前版本', () {
      final migrated = migrateSave(legacySaveV0());
      final metadata = migrated['metadata'] as Map<String, dynamic>;
      expect(metadata['schemaVersion'], kSaveSchemaVersion);
    });

    test('migrateSave 不修改入参', () {
      final raw = legacySaveV0();
      migrateSave(raw);
      final metadata = raw['metadata'] as Map<String, dynamic>;
      expect(metadata.containsKey('schemaVersion'), isFalse);
    });

    test('版本高于支持版本抛 UnsupportedSaveVersionException', () {
      final raw = legacySaveV0();
      (raw['metadata'] as Map<String, dynamic>)['schemaVersion'] = 999;
      expect(
        () => migrateSave(raw),
        throwsA(isA<UnsupportedSaveVersionException>()
            .having((e) => e.found, 'found', 999)
            .having((e) => e.expected, 'expected', kSaveSchemaVersion)),
      );
    });

    test('readSchemaVersion 兼容字符串版本号', () {
      final raw = <String, dynamic>{
        'metadata': <String, dynamic>{'schemaVersion': '1'},
      };
      expect(readSchemaVersion(raw), 1);
    });

    test('metadata 缺失时视为 v0 并补出', () {
      final migrated = migrateSave(<String, dynamic>{'state': <String, dynamic>{}});
      final metadata = migrated['metadata'] as Map<String, dynamic>;
      expect(metadata['schemaVersion'], kSaveSchemaVersion);
    });
  });

  group('M1-T02 防御式解析', () {
    test('Player.fromJson({}) 不抛且返回可用默认实例', () {
      final player = Player.fromJson(<String, dynamic>{});
      expect(player.name, isNotEmpty);
      expect(player.identity, PlayerIdentity.noble);
      expect(player.age, 18);
      expect(player.health, 100);
      expect(player.spouse, isNull);
      expect(player.children, isEmpty);
      expect(player.activeTasks, isEmpty);
    });

    test('错误类型字段不抛且取默认值', () {
      final player = Player.fromJson(<String, dynamic>{
        'name': 123,
        'gold': 'abc',
        'age': 'x',
        'identity': 'not_a_real_identity',
        'health': null,
        'skills': 'not_a_map',
        'inventory': <Object?>[1, 'ok', null],
        'flags': <String, Object?>{'isAlive': 'true', 'bad': <int>[1]},
      });
      expect(player.gold, 0);
      expect(player.age, 18);
      expect(player.identity, PlayerIdentity.noble);
      expect(player.health, 100);
      expect(player.skills, isEmpty);
      expect(player.inventory, <String>['ok']);
      expect(player.flags['isAlive'], isTrue);
      expect(player.flags['bad'], isFalse);
    });

    test('嵌套对象列表：坏元素跳过不抛', () {
      final player = Player.fromJson(<String, dynamic>{
        'childRearing': <Object?>[
          <String, dynamic>{'name': '罗柏', 'focus': 'sword'},
          'garbage',
          null,
          <String, dynamic>{'name': '珊莎', 'focus': 'politics'},
        ],
        'generationRecords': <Object?>['bad', <String, dynamic>{'generation': 2}],
        'activeTasks': <Object?>[<String, dynamic>{'taskId': 't1'}],
      });
      expect(player.childRearing.length, 2);
      expect(player.childRearing.first.name, '罗柏');
      expect(player.childRearing[1].name, '珊莎');
      expect(player.generationRecords.length, 1);
      expect(player.generationRecords.first.generation, 2);
      expect(player.activeTasks.length, 1);
      expect(player.activeTasks.first.taskId, 't1');
    });

    test('GameEvent.fromJson 坏 choices 跳过', () {
      final event = GameEvent.fromJson(<String, dynamic>{
        'id': 'e1',
        'choices': <Object?>['bad', <String, dynamic>{'id': 'c1'}],
        'tags': <Object?>[1, 'winter'],
        'type': 'unknown_type',
        'triggerConditions': <String, Object?>{'season': 'winter', 'bad': 5},
      });
      expect(event.choices.length, 1);
      expect(event.choices.first.id, 'c1');
      expect(event.tags, <String>['winter']);
      expect(event.type, EventType.daily);
      expect(event.triggerConditions, <String, String>{'season': 'winter'});
    });

    test('GameStateProvider.fromJson 半残 state 退化为默认进度', () {
      final state = GameStateProvider.fromJson(<String, dynamic>{});
      expect(state.progress.year, 283);
      expect(state.player.name, isNotEmpty);
      expect(state.history, isEmpty);
    });

    test('marital/npc_task 模型防御式解析', () {
      final spouse = SpouseDetail.fromJson(<String, dynamic>{
        'name': '珊莎',
        'origin': 'unknown',
      });
      expect(spouse.name, '珊莎');
      expect(spouse.origin, SpouseOrigin.commoner);
      expect(spouse.affection, 50);
      expect(spouse.marriedYear, 0);
    });
  });

  group('M1-T04 坏档隔离', () {
    test('listSaves 跳过乱码档并改名 .corrupted', () async {
      await service.saveGame(GameStateProvider()..startNewGame(),
          saveId: 'good1');
      await service.saveGame(GameStateProvider()..startNewGame(),
          saveId: 'good2');
      // 注入一份乱码档
      final bad = File('${tempDir.path}/save_bad.json');
      await bad.writeAsString('this is not json @@@ {{{');

      final saves = await service.listSaves();
      expect(saves.length, 2);
      expect(bad.existsSync(), isFalse);
      expect(
        File('${tempDir.path}/save_bad.json.corrupted').existsSync(),
        isTrue,
      );
    });

    test('loadGame 坏档返回 null 且文件被隔离', () async {
      final bad = File('${tempDir.path}/save_broken.json');
      await bad.writeAsString('{"metadata": ');

      final loaded = await service.loadGame('broken');
      expect(loaded, isNull);
      expect(File('${tempDir.path}/save_broken.json.corrupted').existsSync(),
          isTrue);
    });

    test('loadGame 版本过高的档抛异常且不隔离文件', () async {
      final raw = legacySaveV0(saveId: 'future');
      (raw['metadata'] as Map<String, dynamic>)['schemaVersion'] = 999;
      await writeSaveFile('future', raw);

      await expectLater(
        service.loadGame('future'),
        throwsA(isA<UnsupportedSaveVersionException>()),
      );
      // 文件未被隔离：玩家升级游戏后仍可加载
      expect(File('${tempDir.path}/save_future.json').existsSync(), isTrue);
    });

    test('loadGame state 缺失的档按坏档隔离', () async {
      await writeSaveFile('nostate', <String, dynamic>{
        'metadata': <String, dynamic>{'saveId': 'nostate'},
      });
      final loaded = await service.loadGame('nostate');
      expect(loaded, isNull);
      expect(File('${tempDir.path}/save_nostate.json.corrupted').existsSync(),
          isTrue);
    });

    test('已存在 .corrupted 时不抛异常（覆盖式隔离）', () async {
      final bad = File('${tempDir.path}/save_dup.json');
      await bad.writeAsString('bad');
      await File('${tempDir.path}/save_dup.json.corrupted').writeAsString('old');
      final loaded = await service.loadGame('dup');
      expect(loaded, isNull);
      expect(File('${tempDir.path}/save_dup.json.corrupted').existsSync(),
          isTrue);
    });
  });

  group('M1 端到端', () {
    test('无版本号的 Batch 10-19 旧档可正常加载，新字段为默认值', () async {
      await writeSaveFile('legacy', legacySaveV0());

      final loaded = await service.loadGame('legacy');
      expect(loaded, isNotNull);
      final player = loaded!.player;
      expect(player.name, '琼恩·雪诺');
      expect(player.gold, 320);
      expect(player.identity, PlayerIdentity.noble);
      expect(player.house, '史塔克');
      expect(player.skills['sword'], 4);
      expect(player.relations['npc_sam'], 60);
      // 10-14 之后新增字段回落默认值
      expect(player.children, isEmpty);
      expect(player.spouse, isNull);
      expect(player.childRearing, isEmpty);
      expect(player.generationRecords, isEmpty);
      expect(player.activeTasks, isEmpty);
      // 进度正常
      expect(loaded.progress.year, 283);
      expect(loaded.progress.month, 7);
      expect(loaded.progress.turnCount, 12);
      expect(loaded.isGameActive, isTrue);
    });

    test('保存→加载往返关键字段全等', () async {
      final state = GameStateProvider();
      state.startNewGame(player: Player.defaultPlayer().copyWith(
        name: '艾莉亚',
        gold: 777,
        spouse: const SpouseDetail(
          name: '罗柏',
          origin: SpouseOrigin.warrior,
          marriedYear: 284,
          affection: 66,
        ),
        childRearing: const [
          ChildRearing(name: '珊莎', focus: 'politics', sentToSchool: true),
        ],
        generationRecords: const [
          GenerationRecord(
            generation: 2,
            name: '艾莉亚',
            reignYears: '284-290',
            title: '夫人',
          ),
        ],
      ));
      state.setCurrentEvent(GameEvent.defaultEvent());

      final saveId = await service.saveGame(state, saveId: 'round');
      final loaded = await service.loadGame(saveId);

      expect(loaded, isNotNull);
      final p = loaded!.player;
      expect(p.name, '艾莉亚');
      expect(p.gold, 777);
      expect(p.spouse, isNotNull);
      expect(p.spouse!.name, '罗柏');
      expect(p.spouse!.origin, SpouseOrigin.warrior);
      expect(p.spouse!.marriedYear, 284);
      expect(p.spouse!.affection, 66);
      expect(p.childRearing.length, 1);
      expect(p.childRearing.first.sentToSchool, isTrue);
      expect(p.generationRecords.length, 1);
      expect(p.generationRecords.first.generation, 2);
      expect(p.generationRecords.first.reignYears, '284-290');
      expect(loaded.progress.year, state.progress.year);
      expect(loaded.currentEvent, isNotNull);
      expect(loaded.currentEvent!.id, 'event_winter_comes');
    });

    test('导入：无版本号旧档可导入，坏内容返回 null，高版本抛异常', () {
      final legacy = jsonEncode(legacySaveV0());
      final imported = service.importSave(legacy);
      expect(imported, isNotNull);
      expect(imported!.player.name, '琼恩·雪诺');

      expect(service.importSave('invalid json'), isNull);

      final future = legacySaveV0();
      (future['metadata'] as Map<String, dynamic>)['schemaVersion'] = 999;
      expect(
        () => service.importSave(jsonEncode(future)),
        throwsA(isA<UnsupportedSaveVersionException>()),
      );
    });

    test('存档列表按时间倒序且含正常档', () async {
      await service.saveGame(GameStateProvider()..startNewGame(),
          saveId: 's1');
      await service.saveGame(GameStateProvider()..startNewGame(),
          saveId: 's2');
      final saves = await service.listSaves();
      expect(saves.map((s) => s.saveId).toSet(), <String>{'s1', 's2'});
      for (final save in saves) {
        expect(save.schemaVersion, kSaveSchemaVersion);
      }
    });
  });
}