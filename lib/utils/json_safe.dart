/// JSON 防御式解析工具（Batch 10-26 · M1-T02）。
///
/// 存档契约的第一道护栏：字段缺失、类型不符、元素损坏一律回落到默认值，
/// 绝不抛异常。Batch 10-13 之后每个批次都在给 Player 加字段，旧存档的
/// fromJson 若用 `as String` / `as int` 强转，缺字段即崩或产出半残状态。
///
/// 设计约束：
/// - 首参一律为 `Map<String, dynamic>?`（可为 null），全库启用
///   `avoid_dynamic_calls` / `strict-casts`，故不使用 dynamic 容器。
/// - 嵌套对象用 [safeObject] / [safeObjectList] 逐元素解析，坏元素跳过。
library;

/// 规整为 `Map<String, dynamic>`；非该类型返回 null。
Map<String, dynamic>? asJsonMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  return null;
}

/// 取整数；兼容 int / double / 数字字符串，失败回落 [fallback]。
int asInt(Object? value, int fallback) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

/// 取布尔；兼容 bool / 数字 / "true"/"false" 字符串，失败回落 [fallback]。
bool asBool(Object? value, bool fallback) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final lower = value.toLowerCase();
    if (lower == 'true') return true;
    if (lower == 'false') return false;
  }
  return fallback;
}

/// 安全读取字符串。
String safeStr(Map<String, dynamic>? json, String key, {String fallback = ''}) {
  if (json == null) return fallback;
  final value = json[key];
  if (value is String) return value;
  if (value == null) return fallback;
  return value.toString();
}

/// 安全读取整数。
int safeInt(Map<String, dynamic>? json, String key, {int fallback = 0}) {
  if (json == null) return fallback;
  return asInt(json[key], fallback);
}

/// 安全读取布尔。
bool safeBool(Map<String, dynamic>? json, String key, {bool fallback = false}) {
  if (json == null) return fallback;
  return asBool(json[key], fallback);
}

/// 安全读取子 Map（缺失或非 Map 返回 null）。
Map<String, dynamic>? safeMap(Map<String, dynamic>? json, String key) {
  if (json == null) return null;
  return asJsonMap(json[key]);
}

/// 安全读取列表（缺失或非 List 返回空列表）。
List<Object?> safeList(Map<String, dynamic>? json, String key) {
  if (json == null) return const <Object?>[];
  final value = json[key];
  if (value is List<Object?>) return value;
  return const <Object?>[];
}

/// 安全读取字符串列表（非字符串元素跳过）。
List<String> safeStrList(Map<String, dynamic>? json, String key) {
  final result = <String>[];
  for (final item in safeList(json, key)) {
    if (item is String) {
      result.add(item);
    }
  }
  return result;
}

/// 安全读取 int 值 Map（非数值项按 0 处理）。
Map<String, int> safeIntMap(Map<String, dynamic>? json, String key) {
  final map = safeMap(json, key);
  if (map == null) return const <String, int>{};
  final result = <String, int>{};
  map.forEach((String k, Object? v) {
    result[k] = asInt(v, 0);
  });
  return result;
}

/// 安全读取 bool 值 Map（非布尔项跳过）。
Map<String, bool> safeBoolMap(Map<String, dynamic>? json, String key) {
  final map = safeMap(json, key);
  if (map == null) return const <String, bool>{};
  final result = <String, bool>{};
  map.forEach((String k, Object? v) {
    if (v is bool) {
      result[k] = v;
    } else if (v != null) {
      result[k] = asBool(v, false);
    }
  });
  return result;
}

/// 安全读取 String 值 Map（非字符串项跳过）。
Map<String, String> safeStringMap(Map<String, dynamic>? json, String key) {
  final map = safeMap(json, key);
  if (map == null) return const <String, String>{};
  final result = <String, String>{};
  map.forEach((String k, Object? v) {
    if (v is String) {
      result[k] = v;
    }
  });
  return result;
}

/// 安全解析单个嵌套对象（缺失或非 Map 或解析抛错均返回 null）。
T? safeObject<T>(Object? value, T Function(Map<String, dynamic>) parse) {
  final map = asJsonMap(value);
  if (map == null) return null;
  try {
    return parse(map);
  } on Object {
    return null;
  }
}

/// 安全解析对象列表：逐元素尝试解析，坏元素跳过不抛。
List<T> safeObjectList<T>(
  Map<String, dynamic>? json,
  String key,
  T Function(Map<String, dynamic>) parse,
) {
  final result = <T>[];
  for (final item in safeList(json, key)) {
    final parsed = safeObject<T>(item, parse);
    if (parsed != null) {
      result.add(parsed);
    }
  }
  return result;
}

/// 按名称安全解析枚举：未知名称或缺失回落 [fallback]。
T safeEnum<T extends Enum>(List<T> values, Object? name, T fallback) {
  if (name is! String) return fallback;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}