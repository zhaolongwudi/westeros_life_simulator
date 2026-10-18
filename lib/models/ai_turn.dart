/// AI 回合结果对象（Batch 10-29 · M3b）。
///
/// M3b 之前，AI 一次行动的编排（读配置 → 拼上下文 → 请求 → 拆行渲染）整条写在
/// `screens/game_screen.dart` 里，UI 既当 View 又当 Controller。
/// 现在编排下沉到 `mixins/mixin_ai.dart`，UI 只拿到本对象做展示。
library;

import 'event.dart';

/// 一次 AI 行动的结果。
class AiTurnResult {
  const AiTurnResult({
    required this.lines,
    required this.choices,
    this.isSuccess = false,
    this.isLocal = false,
    this.note = '',
  });

  /// 未配置 API Key 的提示文案（引擎常量，UI 直接复用）。
  static const String notConfiguredLine =
      '⚠️ 尚未配置 AI API Key。请到「设置 / 存档」→ AI 配置 填写。';

  /// 尚未开始游戏时的提示文案。
  static const String notStartedLine = '游戏尚未开始。';

  /// AI 请求失败后的降级提示（附在失败行之后，引导用户切回本地指令模式）。
  static const String degradedLine =
      '🔁 AI 暂时不可用，可继续使用本地指令（帮助/训练/工作/旅行…）游玩。';

  /// 待展示的叙事行（按顺序；失败时为 1 行错误提示）。
  final List<String> lines;

  /// AI 生成的可点选选项（成功且有选项时非空）。
  final List<EventChoice> choices;

  /// 是否成功（未配置 / 请求失败 / 无叙事均为 false）。
  final bool isSuccess;

  /// 本回合是否由**本地剧情导演**产出（主 AI 不可用时的兜底）。
  ///
  /// 与 [isSuccess] 正交：本地兜底也是成功的一回合（有剧情、有选项），
  /// 只是叙事来源不同——UI 可据此提示玩家"这是本地导演，不是主 AI"。
  final bool isLocal;

  /// 来源提示（未配置 Key / AI 失败降级的原因）。
  ///
  /// 单独一个字段而不是塞进 [lines]：UI 可以选择只在**来源变化时**提示一次，
  /// 而不是每回合都把同一句话刷进叙事。
  final String note;
}