/// 指令输入防护（Batch 10-37 · M6 健壮性收官）。
///
/// 玩家指令输入侧的护栏：
/// - 超长截断（防超长字符串拖垮解析）
/// - 纯符号/空白输入统一兜底（防垃圾输入）
///
/// 注意：AI 行动模式的描述性输入不走本模块（那是给 AI 的自由文本，
/// 不应被截断）；本防护只作用于经典指令模式（resolveCommand 入口）。
library;

/// 玩家指令最大长度（超过则截断，防止超长输入拖垮解析/存储）。
const int kMaxCommandLength = 80;

/// 清理玩家指令：去首尾空白 + 超长截断。
///
/// 返回的字符串一定满足 [isCommandNoise] 可判定的规范形式。
String sanitizeCommand(String raw) {
  final trimmed = raw.trim();
  if (trimmed.length <= kMaxCommandLength) {
    return trimmed;
  }
  return trimmed.substring(0, kMaxCommandLength);
}

/// 指令是否为「空白 / 纯符号」垃圾输入（无可执行内容）。
///
/// 判定：不含任何字母、数字或 CJK 汉字即视为噪声。
/// 覆盖：空串、纯空白（trim 后）、`！！！`、`***`、`---`、emoji 串等。
bool isCommandNoise(String input) {
  if (input.isEmpty) return true;
  return !input.contains(
    RegExp(r'[a-zA-Z0-9\u4e00-\u9fff]'),
  );
}