/// 响应式工具（Batch 10-36 · M5 体验层收尾）。
///
/// 提供统一断点与「宽屏限宽居中」帧：
/// - 窄屏（<600）原样全宽，贴合手机
/// - 宽屏（>=600）内容限宽居中，避免长文本行拉满超宽屏（平板/桌面难读）
///
/// 纯展示 + 无状态层依赖（M3b 分层约束）。
library;

import 'package:flutter/material.dart';

/// 全局断点。
abstract final class Breakpoints {
  /// 平板/桌面断点：宽度 >= 此值视为宽屏。
  static const double kTablet = 600;

  /// 桌面断点：宽度 >= 此值视为桌面级。
  static const double kDesktop = 900;

  /// 当前是否宽屏（>= [kTablet]）。
  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= kTablet;

  /// 当前是否桌面级（>= [kDesktop]）。
  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= kDesktop;
}

/// 宽屏限宽居中的内容帧。
///
/// - 窄屏：原样返回 [child]（全宽）
/// - 宽屏：`Center > ConstrainedBox(maxWidth: [maxWidth])` 包裹 [child]
///
/// 用法：`SafeArea(child: AdaptiveFrame(maxWidth: 900, child: ListView(...)))`
class AdaptiveFrame extends StatelessWidget {
  const AdaptiveFrame({
    super.key,
    this.maxWidth = kDefaultMaxWidth,
    required this.child,
  });

  /// 宽屏内容最大宽度。
  static const double kDefaultMaxWidth = 900;

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!Breakpoints.isWide(context)) {
      return child;
    }
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}