/// 存档服务：游戏状态序列化、存档读写、存档恢复。
///
/// Batch 10-26 · M1 存档契约：
/// - 写入时 metadata 带 `schemaVersion`（定义见 save_migration.dart）。
/// - 读取时先 migrateSave 再防御式解析。
/// - 坏档（JSON 乱码 / 结构损坏）改名 `.corrupted` 并从列表剔除，
///   不影响其他存档；版本过高的档抛 [UnsupportedSaveVersionException] 交 UI 提示。
library;

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../providers/game_state_provider.dart';
import '../utils/json_safe.dart';
import 'save_migration.dart';

export 'save_migration.dart' show UnsupportedSaveVersionException, kSaveSchemaVersion;

/// 存档元数据。
class SaveMetadata {
  const SaveMetadata({
    required this.saveId,
    required this.playerName,
    required this.saveTime,
    required this.year,
    required this.month,
    required this.turnCount,
    this.schemaVersion = kSaveSchemaVersion,
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

  /// 存档结构版本号（Batch 10-26 起写入）。
  final int schemaVersion;

  Map<String, dynamic> toJson() {
    return {
      'saveId': saveId,
      'playerName': playerName,
      'saveTime': saveTime,
      'year': year,
      'month': month,
      'turnCount': turnCount,
      'schemaVersion': schemaVersion,
    };
  }

  /// 防御式反序列化（字段缺失/类型错不抛）。
  factory SaveMetadata.fromJson(Map<String, dynamic> json) {
    return SaveMetadata(
      saveId: safeStr(json, 'saveId', fallback: 'unknown'),
      playerName: safeStr(json, 'playerName', fallback: '无名者'),
      saveTime: safeStr(json, 'saveTime'),
      year: safeInt(json, 'year', fallback: 283),
      month: safeInt(json, 'month', fallback: 3),
      turnCount: safeInt(json, 'turnCount'),
      schemaVersion:
          safeInt(json, 'schemaVersion', fallback: kSaveSchemaVersion),
    );
  }
}

/// 存档服务。
class SaveService {
  SaveService({String? saveDir}) : _saveDir = saveDir;

  final String? _saveDir;

  /// 坏档改名后缀。
  static const String corruptedSuffix = '.corrupted';

  /// 获取存档目录。
  Future<Directory> _getSaveDirectory() async {
    if (_saveDir != null) {
      final dir = Directory(_saveDir);
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

  /// 构造存档数据 Map（保存与导出共用，保证格式一致）。
  Map<String, dynamic> _buildSaveData(GameStateProvider state, String saveId) {
    return {
      'metadata': SaveMetadata(
        saveId: saveId,
        playerName: state.player.name,
        saveTime: DateTime.now().toIso8601String(),
        year: state.progress.year,
        month: state.progress.month,
        turnCount: state.progress.turnCount,
      ).toJson(),
      'state': state.toJson(),
    };
  }

  /// 保存游戏状态。
  Future<String> saveGame(GameStateProvider state, {String? saveId}) async {
    final dir = await _getSaveDirectory();
    final id = saveId ?? DateTime.now().millisecondsSinceEpoch.toString();
    final file = File('${dir.path}/save_$id.json');

    final data = _buildSaveData(state, id);
    await file.writeAsString(jsonEncode(data), flush: true);
    return id;
  }

  /// 将坏档改名为 `.corrupted` 备份（已存在则覆盖）。
  Future<void> _quarantine(File file) async {
    try {
      final backup = File('${file.path}$corruptedSuffix');
      if (await backup.exists()) {
        await backup.delete();
      }
      await file.rename(backup.path);
    } on FileSystemException {
      // 改名失败（例如权限/跨设备）不阻断主流程，坏档仅从列表剔除。
    }
  }

  /// 读取并迁移存档 JSON（含 schemaVersion 迁移，不含 state 解析）。
  ///
  /// 返回 null 表示文件坏（已改名隔离）；版本过高抛异常且不隔离。
  Future<Map<String, dynamic>?> _readSaveMap(File file) async {
    try {
      final content = await file.readAsString();
      final data = asJsonMap(jsonDecode(content));
      if (data == null) {
        await _quarantine(file);
        return null;
      }
      return migrateSave(data);
    } on UnsupportedSaveVersionException {
      // 版本过高的档不隔离：玩家升级游戏后仍可加载，交由 UI 提示。
      rethrow;
    } on Object {
      await _quarantine(file);
      return null;
    }
  }

  /// 加载游戏状态。
  ///
  /// 返回 null 表示坏档（已隔离为 .corrupted）；版本过高抛
  /// [UnsupportedSaveVersionException] 由 UI 提示升级游戏。
  Future<GameStateProvider?> loadGame(String saveId) async {
    final dir = await _getSaveDirectory();
    final file = File('${dir.path}/save_$saveId.json');
    if (!await file.exists()) return null;

    final data = await _readSaveMap(file);
    if (data == null) return null;

    final stateJson = asJsonMap(data['state']);
    if (stateJson == null) {
      await _quarantine(file);
      return null;
    }
    return GameStateProvider.fromJson(stateJson);
  }

  /// 获取所有存档列表（坏档自动隔离并跳过，不影响其他存档）。
  Future<List<SaveMetadata>> listSaves() async {
    final dir = await _getSaveDirectory();
    final files = <File>[];
    try {
      await for (final entity in dir.list()) {
        if (entity is File) files.add(entity);
      }
    } on FileSystemException {
      return const <SaveMetadata>[];
    }

    final saves = <SaveMetadata>[];
    for (final file in files) {
      if (!file.path.endsWith('.json')) continue;
      try {
        final content = await file.readAsString();
        final data = asJsonMap(jsonDecode(content));
        final metadata = asJsonMap(data?['metadata']);
        if (metadata == null) {
          await _quarantine(file);
          continue;
        }
        saves.add(SaveMetadata.fromJson(metadata));
      } on Object {
        // 损坏的存档改名隔离，不影响其他存档。
        await _quarantine(file);
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
    final data =
        _buildSaveData(state, DateTime.now().millisecondsSinceEpoch.toString());
    return jsonEncode(data);
  }

  /// 从字符串导入存档。
  ///
  /// 坏内容（非法 JSON / 非 Map / 缺 state）返回 null；版本过高抛
  /// [UnsupportedSaveVersionException] 交 UI 提示升级游戏。
  GameStateProvider? importSave(String content) {
    Map<String, dynamic>? data;
    try {
      data = asJsonMap(jsonDecode(content));
    } on FormatException {
      return null;
    }
    if (data == null) return null;
    final migrated = migrateSave(data);
    final stateJson = asJsonMap(migrated['state']);
    if (stateJson == null) return null;
    return GameStateProvider.fromJson(stateJson);
  }
}