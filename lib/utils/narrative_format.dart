/// 叙事格式化工具（Batch 10-12）。
///
/// 提供：
/// 1. [splitNarrative]：把一段长篇叙事按空行/句号拆分为短段落，便于 UI 分段渲染
/// 2. [effectLabels]：从事件选项的效果 Map 推导中文标签（金币/声望/生命/精力/饱食/技能/属性/物品/关系/标记）
/// 3. [choiceOrdinal]：选项的短编号标签（Ⅰ/Ⅱ/Ⅲ…）
library;

/// 将一段叙事文本拆分为短段落。
///
/// 分段规则：
/// - 优先按换行拆分（保留原段落）
/// - 无换行时，按中文句号/叹号/问号切分为句子，超过 [maxLength] 的再硬切
/// 返回至少包含一个元素的列表。
List<String> splitNarrative(String text, {int maxLength = 60}) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return <String>[''];

  // 1) 按换行拆
  final byNewline = trimmed
      .split(RegExp(r'\n+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  if (byNewline.length > 1) return byNewline;

  // 2) 按句末标点拆
  final parts = <String>[];
  final buffer = StringBuffer();
  for (final ch in trimmed.split('')) {
    buffer.write(ch);
    if (ch == '。' || ch == '！' || ch == '？') {
      final seg = buffer.toString().trim();
      if (seg.isNotEmpty) parts.add(seg);
      buffer.clear();
    }
  }
  if (buffer.isNotEmpty) {
    final seg = buffer.toString().trim();
    if (seg.isNotEmpty) parts.add(seg);
  }
  if (parts.isNotEmpty) return parts;

  // 3) 兜底：按长度硬切
  final hard = <String>[];
  for (var i = 0; i < trimmed.length; i += maxLength) {
    final end = (i + maxLength).clamp(0, trimmed.length);
    hard.add(trimmed.substring(i, end));
  }
  return hard.isEmpty ? <String>[trimmed] : hard;
}

/// 从效果 Map 推导中文标签（用于 AI 选项卡片预览）。
///
/// 返回形如「金币+10 · 声望-5」的短串；空效果返回 ['无显著影响']。
List<String> effectLabels(Map<String, int> effects) {
  if (effects.isEmpty) return <String>['无显著影响'];
  final labels = <String>[];
  String sign(int v) => v > 0 ? '+$v' : '$v';

  final gold = effects['gold'];
  if (gold != null) labels.add('金币${sign(gold)}');

  final rep = effects['reputation'];
  if (rep != null) labels.add('声望${sign(rep)}');

  final health = effects['health'];
  if (health != null) labels.add('生命${sign(health)}');

  final energy = effects['energy'];
  if (energy != null) labels.add('精力${sign(energy)}');

  final hunger = effects['hunger'];
  if (hunger != null) labels.add('饱食${sign(hunger)}');

  // 技能 / 属性 / 关系 / 物品 / 标记：取前 2 个展示
  final extras = <String>[];
  for (final entry in effects.entries) {
    final key = entry.key;
    final v = entry.value;
    if (key.startsWith('skills.')) {
      extras.add('${key.substring(7)}${sign(v)}');
    } else if (key.startsWith('attributes.')) {
      extras.add('${key.substring(11)}${sign(v)}');
    } else if (key.startsWith('relations.')) {
      extras.add('${key.substring(10)}${sign(v)}');
    } else if (key.startsWith('inventory.')) {
      extras.add('物品${sign(v)}');
    } else if (key.startsWith('flags.')) {
      extras.add('状态${v > 0 ? '开启' : '清除'}');
    }
  }
  labels.addAll(extras.take(2));
  return labels;
}

/// 选项短编号标签（用于卡片前缀）。
String choiceOrdinal(int index) {
  const ordinals = <String>['Ⅰ', 'Ⅱ', 'Ⅲ', 'Ⅳ', 'Ⅴ', 'Ⅵ'];
  if (index < 0) return '?';
  if (index < ordinals.length) return ordinals[index];
  return '${index + 1}';
}