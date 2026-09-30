/// 存档迁移机制（Batch 10-26 · M1-T03）。
///
/// 契约：任何旧存档在新版本上要么正常加载、要么明确迁移、要么安全拒绝，
/// 绝不静默产出半残状态。
///
/// 版本语义：
/// - `schemaVersion` 缺失视为 0（Batch 10-26 之前所有存档均无此字段）。
/// - 迁移表按版本链式升级：v0 → v1 → … → kSaveSchemaVersion。
/// - 存档版本**高于**当前程序支持的版本时抛 [UnsupportedSaveVersionException]，
///   由 UI 层提示玩家升级游戏，绝不猜测解析。
///
/// v0 → v1 是空操作（仅补版本号）：v1 与 v0 的字段差异全部由各模型
/// fromJson 的防御式解析吸收（见 lib/utils/json_safe.dart），因此后续
/// 只要新增字段就无需写迁移函数，版本号仅在「结构性不兼容」时才 +1。
library;

/// 存档 schema 版本号（与 save_service.dart 的 kSaveSchemaVersion 保持一致）。
///
/// 约定：
/// - 纯新增可选字段 → 不升版本（靠防御式 fromJson 兼容）。
/// - 字段重命名 / 类型变更 / 结构删改 → 升版本并补一条迁移函数。
const int kSaveSchemaVersion = 1;

/// 存档版本高于程序支持版本时抛出。
class UnsupportedSaveVersionException implements Exception {
  const UnsupportedSaveVersionException({
    required this.found,
    required this.expected,
  });

  /// 存档自带的版本号。
  final int found;

  /// 当前程序支持的版本号。
  final int expected;

  @override
  String toString() =>
      'UnsupportedSaveVersionException: 存档版本 $found 高于当前支持的 $expected';
}

/// 单个版本的迁移函数：接收旧结构，返回新结构（原地修改亦可）。
typedef MigrationFn = Map<String, dynamic> Function(Map<String, dynamic> raw);

/// v0 → v1：空操作，仅补 schemaVersion 字段。
///
/// 理由：v1 未改变任何字段名与类型，差异由防御式 fromJson 吸收。
Map<String, dynamic> _v0ToV1(Map<String, dynamic> raw) {
  return raw;
}

/// 迁移表：key 为「迁移前版本号」，value 为升到下一版的迁移函数。
const Map<int, MigrationFn> kSaveMigrations = <int, MigrationFn>{
  0: _v0ToV1,
};

/// 读取存档自带版本号（metadata.schemaVersion 缺失或非法视为 0）。
int readSchemaVersion(Map<String, dynamic> raw) {
  final metadata = raw['metadata'];
  if (metadata is! Map) return 0;
  final version = metadata['schemaVersion'];
  if (version is int) return version;
  if (version is double) return version.toInt();
  if (version is String) return int.tryParse(version) ?? 0;
  return 0;
}

/// 将任意版本的存档 Map 迁移到 [kSaveSchemaVersion]。
///
/// 返回值是**新的** Map：顶层逐项拷贝，且 `metadata` 子 Map 单独复制，
/// 因此打版本戳不会污染调用方传入的原对象。版本高于当前支持时抛
/// [UnsupportedSaveVersionException]；迁移链断裂（缺关键版本迁移函数）时抛
/// [StateError]。
Map<String, dynamic> migrateSave(Map<String, dynamic> raw) {
  var current = readSchemaVersion(raw);
  if (current > kSaveSchemaVersion) {
    throw UnsupportedSaveVersionException(
      found: current,
      expected: kSaveSchemaVersion,
    );
  }

  var migrated = Map<String, dynamic>.from(raw);
  // 关键：metadata 是嵌套 Map，浅拷贝顶层仍与入参共享同一对象。
  // 单独复制一层，保证 [migrateSave] 对入参无副作用（Batch 10-26 CI 修复）。
  final rawMetadata = raw['metadata'];
  if (rawMetadata is Map) {
    migrated['metadata'] = Map<String, dynamic>.from(rawMetadata);
  }
  var guard = 0;
  while (current < kSaveSchemaVersion) {
    final step = kSaveMigrations[current];
    if (step == null) {
      throw StateError('缺少 v$current → v${current + 1} 的迁移函数');
    }
    migrated = step(migrated);
    final next = readSchemaVersion(migrated);
    // 迁移函数若未推进版本号，则手动补上，避免死循环。
    if (next <= current) {
      _stampVersion(migrated, current + 1);
      current = current + 1;
    } else {
      current = next;
    }
    guard++;
    if (guard > kSaveSchemaVersion + 1) {
      throw StateError('存档迁移链异常：版本未收敛（可能存在环）');
    }
  }

  // 兜底：确保 metadata.schemaVersion 存在且为当前版本。
  _stampVersion(migrated, current);
  return migrated;
}

/// 在 metadata 上打版本戳（metadata 缺失时补一个空 Map）。
void _stampVersion(Map<String, dynamic> raw, int version) {
  var metadata = raw['metadata'];
  if (metadata is! Map) {
    metadata = <String, dynamic>{};
    raw['metadata'] = metadata;
  }
  final map = metadata;
  map['schemaVersion'] = version;
  raw['metadata'] = map;
}