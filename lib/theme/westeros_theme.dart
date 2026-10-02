/// 维斯特洛主题：铁与火 · 羊皮纸与黄金。
///
/// 设计语言（UI 重造 Batch 10-60）：
/// - 底色：深色树皮棕（北境夜临）→ 史诗沉浸
/// - 主色：黄金（兰尼斯特金）→ 王权 / 财富 / 荣耀
/// - 辅色：钢铁银灰（史塔克钢）→ 忠诚 / 战力 / 实用
/// - 强调：血红（坦格利安红）→ 血与火 / 危险 / 激情
/// - 文字：羊皮纸米色 → 古卷质感
///
/// 用法：`MaterialApp(theme: westerosTheme())`。
library;

import 'package:flutter/material.dart';

/// 维斯特洛色板（铁与火 · 羊皮纸）。
abstract final class WesterosColors {
  // ── 黄金（兰尼斯特）──
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldBright = Color(0xFFF0D060);
  static const Color goldDark = Color(0xFF9C7C1C);

  // ── 血红（坦格利安）──
  static const Color bloodRed = Color(0xFFA61B29);

  // ── 钢铁（史塔克）──
  static const Color steel = Color(0xFF9AA5B1);

  // ── 羊皮纸 ──
  static const Color parchment = Color(0xFFF2E6CE);
  static const Color parchmentDim = Color(0xFFC9B896);

  // ── 树皮背景层级 ──
  static const Color barkDeep = Color(0xFF130C08);
  static const Color barkBase = Color(0xFF1A110C);
  static const Color barkMid = Color(0xFF20160F);
  static const Color barkHigh = Color(0xFF2A1B12);
  static const Color barkHighest = Color(0xFF33221A);

  // ── 墨（文字）──
  static const Color ink = Color(0xFFF2E6CE);
  static const Color inkDim = Color(0xFFB8A88C);

  // ── 边框 ──
  static const Color outlineGold = Color(0xFF6B5A22);
  static const Color outlineDark = Color(0xFF3A2C1E);
}

/// 构建维斯特洛主题。
ThemeData westerosTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: WesterosColors.gold,
    brightness: Brightness.dark,
  ).copyWith(
    primary: WesterosColors.gold,
    onPrimary: WesterosColors.barkDeep,
    primaryContainer: const Color(0xFF3A2A18),
    onPrimaryContainer: WesterosColors.goldBright,
    secondary: WesterosColors.steel,
    onSecondary: WesterosColors.barkDeep,
    secondaryContainer: const Color(0xFF2E3438),
    onSecondaryContainer: const Color(0xFFC8D0D8),
    tertiary: WesterosColors.bloodRed,
    onTertiary: const Color(0xFFF5E6E6),
    tertiaryContainer: const Color(0xFF4A1E24),
    onTertiaryContainer: const Color(0xFFF0B4B8),
    surface: WesterosColors.barkBase,
    onSurface: WesterosColors.ink,
    surfaceContainerLowest: WesterosColors.barkDeep,
    surfaceContainerLow: WesterosColors.barkBase,
    surfaceContainer: WesterosColors.barkMid,
    surfaceContainerHigh: WesterosColors.barkHigh,
    surfaceContainerHighest: WesterosColors.barkHighest,
    onSurfaceVariant: WesterosColors.inkDim,
    outline: const Color(0xFF6B5A44),
    outlineVariant: WesterosColors.outlineDark,
    surfaceTint: WesterosColors.gold,
    shadow: Colors.black,
  );

  final base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
  );

  // serif 家族标题：模拟中世纪羊皮纸卷轴标题
  TextStyle serifTitle(TextStyle? t) => (t ?? const TextStyle()).copyWith(
        fontFamily: 'serif',
        fontWeight: FontWeight.bold,
        letterSpacing: 0.6,
      );

  return base.copyWith(
    scaffoldBackgroundColor: WesterosColors.barkDeep,
    // 全局细金分隔线
    dividerTheme: DividerThemeData(
      color: WesterosColors.outlineGold.withValues(alpha: 0.45),
      thickness: 1,
      space: 1,
    ),
    // 卡片：暖棕 + 金边 + 圆角 + 微投影
    cardTheme: CardThemeData(
      color: WesterosColors.barkHigh,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: WesterosColors.outlineGold.withValues(alpha: 0.55),
        ),
      ),
      margin: EdgeInsets.zero,
    ),
    // AppBar：深棕 + 金色标题 + 微金影
    appBarTheme: AppBarTheme(
      backgroundColor: WesterosColors.barkMid,
      foregroundColor: WesterosColors.ink,
      elevation: 4,
      shadowColor: WesterosColors.goldDark.withValues(alpha: 0.5),
      centerTitle: true,
      titleTextStyle: const TextStyle(
        fontFamily: 'serif',
        fontSize: 19,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        color: WesterosColors.goldBright,
      ),
      iconTheme: const IconThemeData(color: WesterosColors.goldBright),
    ),
    // 输入框：羊皮纸暗底 + 金边
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: WesterosColors.barkHigh.withValues(alpha: 0.8),
      hintStyle: TextStyle(color: WesterosColors.inkDim.withValues(alpha: 0.8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: WesterosColors.outlineGold.withValues(alpha: 0.5),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: WesterosColors.gold,
          width: 1.6,
        ),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: WesterosColors.outlineGold.withValues(alpha: 0.4),
        ),
      ),
      isDense: true,
    ),
    // Chip：金边羊皮纸感
    chipTheme: ChipThemeData(
      backgroundColor: WesterosColors.barkMid,
      selectedColor: WesterosColors.goldDark.withValues(alpha: 0.35),
      side: BorderSide(color: WesterosColors.outlineGold.withValues(alpha: 0.5)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      labelStyle: const TextStyle(color: WesterosColors.ink, fontSize: 13),
      secondaryLabelStyle: const TextStyle(color: WesterosColors.goldBright),
    ),
    // SnackBar：金边提示
    snackBarTheme: SnackBarThemeData(
      backgroundColor: WesterosColors.barkHighest,
      contentTextStyle: const TextStyle(color: WesterosColors.parchment),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: WesterosColors.outlineGold.withValues(alpha: 0.7)),
      ),
      behavior: SnackBarBehavior.floating,
    ),
    // 弹层：金边
    dialogTheme: DialogThemeData(
      backgroundColor: WesterosColors.barkHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: WesterosColors.outlineGold.withValues(alpha: 0.7)),
      ),
      titleTextStyle: const TextStyle(
        fontFamily: 'serif',
        fontSize: 19,
        fontWeight: FontWeight.bold,
        color: WesterosColors.goldBright,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: WesterosColors.barkHigh,
      modalBackgroundColor: WesterosColors.barkHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: WesterosColors.outlineGold),
      ),
      showDragHandle: true,
      dragHandleColor: WesterosColors.goldDark,
    ),
    // 文字：标题 serif 粗体
    textTheme: base.textTheme.copyWith(
      displayLarge: serifTitle(base.textTheme.displayLarge),
      displayMedium: serifTitle(base.textTheme.displayMedium),
      displaySmall: serifTitle(base.textTheme.displaySmall),
      headlineLarge: serifTitle(base.textTheme.headlineLarge),
      headlineMedium: serifTitle(base.textTheme.headlineMedium),
      headlineSmall: serifTitle(base.textTheme.headlineSmall),
      titleLarge: serifTitle(base.textTheme.titleLarge).copyWith(fontSize: 20),
      titleMedium: serifTitle(base.textTheme.titleMedium),
      titleSmall: serifTitle(base.textTheme.titleSmall).copyWith(
        letterSpacing: 0.4,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(
        color: WesterosColors.parchment,
        height: 1.5,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        color: WesterosColors.parchment,
        height: 1.5,
      ),
      bodySmall: base.textTheme.bodySmall?.copyWith(
        color: WesterosColors.inkDim,
        height: 1.4,
      ),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ),
    ),
    // 按钮：金色主按钮
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: WesterosColors.gold,
        foregroundColor: WesterosColors.barkDeep,
        textStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          letterSpacing: 0.6,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: WesterosColors.goldBright,
        side: BorderSide(color: WesterosColors.outlineGold),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: WesterosColors.goldBright,
      ),
    ),
    // TabBar：金色下划线
    tabBarTheme: TabBarThemeData(
      labelColor: WesterosColors.goldBright,
      unselectedLabelColor: WesterosColors.inkDim,
      indicatorColor: WesterosColors.gold,
      indicatorSize: TabBarIndicatorSize.label,
      labelStyle: const TextStyle(
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    ),
    // 进度条：金色
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: WesterosColors.gold,
      linearTrackColor: WesterosColors.barkHighest,
    ),
    // 开关：金色激活
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? WesterosColors.goldBright
            : WesterosColors.inkDim,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? WesterosColors.goldDark.withValues(alpha: 0.5)
            : WesterosColors.barkHighest,
      ),
    ),
    // 弹出菜单
    popupMenuTheme: PopupMenuThemeData(
      color: WesterosColors.barkHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: WesterosColors.outlineGold.withValues(alpha: 0.7)),
      ),
      textStyle: const TextStyle(color: WesterosColors.ink),
    ),
    // 列表分隔
    listTileTheme: const ListTileThemeData(
      iconColor: WesterosColors.goldBright,
      textColor: WesterosColors.parchment,
    ),
    // 扩展瓦片箭头颜色
    expansionTileTheme: ExpansionTileThemeData(
      backgroundColor: Colors.transparent,
      collapsedBackgroundColor: Colors.transparent,
      iconColor: WesterosColors.goldBright,
      collapsedIconColor: WesterosColors.inkDim,
      textColor: WesterosColors.goldBright,
      collapsedTextColor: WesterosColors.parchment,
      childrenPadding: const EdgeInsets.only(bottom: 8),
    ),
    // 单选列表
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? WesterosColors.goldBright
            : WesterosColors.inkDim,
      ),
    ),
    // 勾选
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? WesterosColors.goldDark
            : Colors.transparent,
      ),
      checkColor: WidgetStateProperty.all(WesterosColors.barkDeep),
      side: BorderSide(color: WesterosColors.outlineGold),
    ),
  );
}
