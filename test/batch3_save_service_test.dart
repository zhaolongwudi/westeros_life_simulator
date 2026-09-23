/// Batch 3 测试：SaveService。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/providers/game_state_provider.dart';
import 'package:westeros_life_simulator/services/save_service.dart';

void main() {
  late Directory tempDir;
  late SaveService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('save_test_');
    service = SaveService(saveDir: tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('SaveMetadata', () {
    test('toJson/fromJson 序列化', () {
      final metadata = SaveMetadata(
        saveId: 'test_123',
        playerName: '琼恩',
        saveTime: '2026-09-23T12:00:00.000',
        year: 283,
        month: 3,
        turnCount: 10,
      );
      final json = metadata.toJson();
      final restored = SaveMetadata.fromJson(json);
      expect(restored.saveId, 'test_123');
      expect(restored.playerName, '琼恩');
      expect(restored.year, 283);
      expect(restored.turnCount, 10);
    });
  });

  group('SaveService', () {
    test('saveGame 保存游戏', () async {
      final state = GameStateProvider();
      state.startNewGame();
      final saveId = await service.saveGame(state);
      expect(saveId, isNotEmpty);
      expect(await service.saveExists(saveId), true);
    });

    test('loadGame 加载游戏', () async {
      final state = GameStateProvider();
      state.startNewGame();
      final saveId = await service.saveGame(state);

      final loaded = await service.loadGame(saveId);
      expect(loaded, isNotNull);
      expect(loaded!.player.name, state.player.name);
      expect(loaded.progress.year, state.progress.year);
    });

    test('loadGame 不存在的存档', () async {
      final loaded = await service.loadGame('nonexistent');
      expect(loaded, isNull);
    });

    test('listSaves 列出存档', () async {
      final state1 = GameStateProvider();
      state1.startNewGame();
      await service.saveGame(state1, saveId: 'save_1');

      final state2 = GameStateProvider();
      state2.startNewGame();
      await service.saveGame(state2, saveId: 'save_2');

      final saves = await service.listSaves();
      expect(saves.length, 2);
    });

    test('deleteSave 删除存档', () async {
      final state = GameStateProvider();
      state.startNewGame();
      final saveId = await service.saveGame(state);

      expect(await service.saveExists(saveId), true);
      await service.deleteSave(saveId);
      expect(await service.saveExists(saveId), false);
    });

    test('deleteSave 不存在的存档', () async {
      final result = await service.deleteSave('nonexistent');
      expect(result, false);
    });

    test('exportSave 导出存档', () {
      final state = GameStateProvider();
      state.startNewGame();
      final exported = service.exportSave(state);
      expect(exported, contains('metadata'));
      expect(exported, contains('state'));
    });

    test('importSave 导入存档', () {
      final state = GameStateProvider();
      state.startNewGame();
      final exported = service.exportSave(state);

      final imported = service.importSave(exported);
      expect(imported, isNotNull);
      expect(imported!.player.name, state.player.name);
    });

    test('importSave 无效内容', () {
      final imported = service.importSave('invalid json');
      expect(imported, isNull);
    });

    test('saveExists 检查存档', () async {
      expect(await service.saveExists('nonexistent'), false);

      final state = GameStateProvider();
      state.startNewGame();
      await service.saveGame(state, saveId: 'test');
      expect(await service.saveExists('test'), true);
    });
  });
}