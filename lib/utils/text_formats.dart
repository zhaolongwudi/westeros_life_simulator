/// 文本格式化工具：时间/数字通用格式化。
///
/// 从 settings_screen._formatTime 迁移，供存档列表/叙事文本共用。
library;

/// 格式化 ISO 时间为本地可读串（yyyy-MM-dd HH:mm）。
String formatDateTime(String iso) {
  try {
    final dt = DateTime.parse(iso).toLocal();
    return '${dt.year}-${pad2(dt.month)}-${pad2(dt.day)} '
        '${pad2(dt.hour)}:${pad2(dt.minute)}';
  } catch (_) {
    return iso;
  }
}

/// 整数补零到两位（用于日期/时间显示）。
String pad2(int value) => value.toString().padLeft(2, '0');

/// 将值限制在 [min, max] 区间。
int clampInt(int value, {int min = 0, int max = 100}) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

/// 用顿号连接字符串列表（空列表返回空串）。
String joinAnd(List<String> items) => items.join('、');