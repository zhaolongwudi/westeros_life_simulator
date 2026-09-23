/// 存档服务：游戏状态序列化、存档读写、存档恢复。
library;

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../providers/game_state_provider.dart';

/// 存档元数据。
class SaveMetadata {
  const SaveMetadata({
    required this.saveId,
    required this.playerName,
    required this.saveTime,
    required this.year,
    required this.month,
    required this.turnCount,
  });

  /// 存档 ID。
  final String saveId;

  /// 玩家姓名。
  final String playerName;

  /// 存档时间（ISO 格式）。
  final String saveTime;

  /// 游戏年份。
  final int year;

  /// 游戏月份。
  final int month;

  /// 回合数。
  final int turnCount;

  Map<String, dynamic> toJson() {
    return {
      'saveId': saveId,
      'playerName': playerName,
      'saveTime': saveTime,
      'year': year,
      'month': month,
      'turnCount': turnCount,
    };
  }

  factory SaveMetadata.fromJson(Map<String, dynamic> json) {
    return SaveMetadata(
      saveId: json['saveId'] as String,
      playerName: json['playerName'] as String,
      saveTime: json['saveTime'] as String,
      year: json['year'] as int,
      month: json['month'] as int,
      turnCount: json['turnCount'] as int,
    );
  }
}

/// 存档服务。
class SaveService {
  SaveService({String? saveDir}) : _saveDir = saveDir;

  final String? _saveDir;

  /// 获取存档目录。
  Future<Directory> _getSaveDirectory() async {
    if (_saveDir != null) {
      final dir = Directory(_saveDir!);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/saves');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 保存游戏状态。
  Future<String> saveGame(GameStateProvider state, {String? saveId}) async {
    final dir = await _getSaveDirectory();
    final id = saveId ?? DateTime.now().millisecondsSinceEpoch.toString();
    final file = File('${dir.path}/save_$id.json');

    final data = {
      'metadata': SaveMetadata(
        saveId: id,
        playerName: state.player.name,
        saveTime: DateTime.now().toIso8601String(),
        year: state.progress.year,
        month: state.progress.month,
        turnCount: state.progress.turnCount,
      ).toJson(),
      'state': state.toJson(),
    };

    await file.writeAsString(jsonEncode(data), flush: true);
    return id;
  }

  /// 加载游戏状态。
  Future<GameStateProvider?> loadGame(String saveId) async {
    final dir = await _getSaveDirectory();
    final file = File('${dir.path}/save_$saveId.json');

    if (!await file.exists()) return null;

    try {
      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      final stateJson = data['state'] as Map<String, dynamic>;
      return GameStateProvider.fromJson(stateJson);
    } catch (_) {
      return null;
    }
  }

  /// 获取所有存档列表。
  Future<List<SaveMetadata>> listSaves() async {
    final dir = await _getSaveDirectory();
    final files = await dir.list().whereType<File>().toList();

    final saves = <SaveMetadata>[];
    for (final file in files) {
      if (!file.path.endsWith('.json')) continue;
      try {
        final content = await file.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;
        final metadata = data['metadata'] as Map<String, dynamic>;
        saves.add(SaveMetadata.fromJson(metadata));
      } catch (_) {
        // 跳过损坏的存档
      }
    }

    // 按存档时间倒序
    saves.sort((a, b) => b.saveTime.compareTo(a.saveTime));
    return saves;
  }

  /// 删除存档。
  Future<bool> deleteSave(String saveId) async {
    final dir = await _getSaveDirectory();
    final file = File('${dir.path}/save_$saveId.json');

    if (!await file.exists()) return false;
    await file.delete();
    return true;
  }

  /// 检查存档是否存在。
  Future<bool> saveExists(String saveId) async {
    final dir = await _getSaveDirectory();
    final file = File('${dir.path}/save_$saveId.json');
    return file.exists();
  }

  /// 导出存档到字符串。
  String exportSave(GameStateProvider state) {
    final data = {
      'metadata': SaveMetadata(
        saveId: DateTime.now().millisecondsSinceEpoch.toString(),
        playerName: state.player.name,
        saveTime: DateTime.now().toIso8601String(),
        year: state.progress.year,
        month: state.progress.month,
        turnCount: state.progress.turnCount,
      ).toJson(),
      'state': state.toJson(),
    };
    return jsonEncode(data);
  }

  /// 从字符串导入存档。
  GameStateProvider? importSave(String content) {
    try {
      final data = jsonDecode(content) as Map<String, dynamic>;
      final stateJson = data['state'] as Map<String, dynamic>;
      return GameStateProvider.fromJson(stateJson);
    } catch (_) {
      return null;
    }
  }
}