/// 信件模型（Batch 10-29 · M3b 从 mixin_letter 迁到模型层）。
///
/// M3b 之前 Letter 寄居在 `mixins/mixin_letter.dart`，导致 UI 层
/// （letters_screen）为读一个纯数据类而 import 混入层。
/// 迁到 models/ 后：混入层 import 模型层，UI 层 import 模型层，层次单向。
library;

/// 一封信件（含来信 / 回信）。
class Letter {
  const Letter({
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.year,
    required this.month,
    required this.isFromNpc,
    this.replied = false,
  });

  /// 寄信人 NPC ID。
  final String senderId;

  /// 寄信人姓名。
  final String senderName;

  /// 信件内容。
  final String content;

  /// 信件年份。
  final int year;

  /// 信件月份。
  final int month;

  /// 是否来自 NPC（true=来信，false=玩家回信）。
  final bool isFromNpc;

  /// 是否已回信。
  final bool replied;

  /// 复制并覆盖指定字段。
  Letter copyWith({bool? replied}) {
    return Letter(
      senderId: senderId,
      senderName: senderName,
      content: content,
      year: year,
      month: month,
      isFromNpc: isFromNpc,
      replied: replied ?? this.replied,
    );
  }
}