/// 维斯特洛公共装饰组件：华丽视觉的统一工具集。
///
/// UI 重造 Batch 10-60 新增。所有界面共享以下组件：
/// - [WesterosScaffold]：带羊皮纸纹理背景 + 金饰标题栏的 Scaffold 壳
/// - [OrnateHeader]：金线 + 菱形饰章的区块标题
/// - [GildedCard]：金边暖棕卡片（卡片装饰统一收口）
/// - [StatPill]：状态胶囊（健康/精力/饱食/金币等）
/// - [WesterosDivider]：金线分隔符（带中置饰章）
/// - [SectionDivider]：区块间装饰分隔
///
/// 纯展示组件，不依赖业务层（m3b 分层约束）。
library;

import 'package:flutter/material.dart';

import '../../theme/westeros_theme.dart';

/// 羊皮纸纹理背景（纯绘制，不依赖图片资源）。
///
/// 用细网格 + 微噪点模拟古羊皮纸的颗粒感：
/// - 低透明度水平/垂直线：纸张纤维
/// - 随机小点：纸张颗粒（seeded 固定，不闪动）
class ParchmentBackground extends StatelessWidget {
  const ParchmentBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            WesterosColors.barkDeep,
            WesterosColors.barkBase,
            WesterosColors.barkDeep,
          ],
        ),
      ),
      child: CustomPaint(
        painter: _ParchmentPainter(),
        child: child,
      ),
    );
  }
}

/// 羊皮纸纹理画笔。
class _ParchmentPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 顶部与底部微金渐变光
    final topGlow = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0x22D4AF37),
          Color(0x00000000),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Offset.zero & size, topGlow);

    // 纸张纤维细线（水平，随机但固定 seed）
    final fiber = Paint()
      ..color = WesterosColors.parchment.withValues(alpha: 0.03)
      ..strokeWidth = 1;
    for (var i = 0; i < 40; i++) {
      final y = (i * 37 + 13) % size.height.toInt();
      canvas.drawLine(
        Offset(0, y.toDouble()),
        Offset(size.width, y.toDouble()),
        fiber,
      );
    }

    // 纸张颗粒小点（seeded）
    final dot = Paint()..color = WesterosColors.goldBright.withValues(alpha: 0.035);
    var seed = 7;
    for (var i = 0; i < 90; i++) {
      seed = (seed * 31 + 17) % 100003;
      final x = (seed % (size.width.toInt() + 1)).toDouble();
      seed = (seed * 31 + 17) % 100003;
      final y = (seed % (size.height.toInt() + 1)).toDouble();
      canvas.drawCircle(Offset(x, y), 0.8, dot);
    }

    // 底部微暗角
    final bottomShade = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: <Color>[
          Color(0x33000000),
          Color(0x00000000),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Offset.zero & size, bottomShade);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 带羊皮纸背景与标题饰条的 Scaffold 壳。
///
/// - [title]：AppBar 标题
/// - [child]：正文（放 ListView 等）
/// - [actions]：AppBar 右侧操作
/// - [withTexture]：是否带羊皮纸纹理背景（默认 true）
class WesterosScaffold extends StatelessWidget {
  const WesterosScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.withTexture = true,
    this.bottom,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;
  final bool withTexture;
  final PreferredSizeWidget? bottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: actions,
        bottom: bottom,
        flexibleSpace: const _AppBarUnderline(),
      ),
      body: SafeArea(
        child: withTexture ? ParchmentBackground(child: child) : child,
      ),
    );
  }
}

/// AppBar 底部金色细线装饰。
class _AppBarUnderline extends StatelessWidget {
  const _AppBarUnderline();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: <Color>[
              Colors.transparent,
              WesterosColors.goldBright,
              Colors.transparent,
            ],
          ),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}

/// 金线 + 菱形饰章的区块标题。
///
/// 用法：`OrnateHeader(icon: Icons.shield, title: '我的家族')`。
/// 左侧金色竖线 + 图标，右侧金线贯穿至区块边缘，中间菱形饰章。
class OrnateHeader extends StatelessWidget {
  const OrnateHeader({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
    this.padding = const EdgeInsets.symmetric(vertical: 10),
  });

  final IconData icon;
  final String title;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: <Widget>[
          // 金色竖线
          Container(
            width: 3,
            height: 22,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  WesterosColors.goldDark,
                  WesterosColors.goldBright,
                  WesterosColors.goldDark,
                ],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Icon(icon, size: 20, color: WesterosColors.goldBright),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: WesterosColors.goldBright,
                  fontWeight: FontWeight.bold,
                ),
          ),
          if (trailing != null) ...[
            const Spacer(),
            trailing!,
          ] else ...[
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 1,
                margin: const EdgeInsets.only(top: 3),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      WesterosColors.outlineGold,
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 金边暖棕卡片（卡片装饰统一收口）。
///
/// 提供三种变体：
/// - 默认：金边暖棕
/// - [highlight]：金色描边 + 淡金底（用于当前/重点）
/// - [danger]：血色描边（用于危险/删除）
class GildedCard extends StatelessWidget {
  const GildedCard({
    super.key,
    this.highlight = false,
    this.danger = false,
    this.padding = const EdgeInsets.all(14),
    this.margin,
    this.child,
    this.onTap,
    this.color,
  });

  final bool highlight;
  final bool danger;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final Widget? child;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final borderColor = danger
        ? WesterosColors.bloodRed.withValues(alpha: 0.7)
        : highlight
            ? WesterosColors.gold
            : WesterosColors.outlineGold.withValues(alpha: 0.55);
    final bg = color ??
        (highlight
            ? WesterosColors.goldDark.withValues(alpha: 0.16)
            : WesterosColors.barkHigh);
    final radius = BorderRadius.circular(14);
    final side = BorderSide(
      color: borderColor,
      width: highlight ? 1.4 : 1,
    );
    final content = Padding(padding: padding, child: child);
    // 统一「Card 外层（Material 祖先，天然解决 ListTile ink 断言 + find.byType(Card) 兼容）」：
    final outer = Card(
      margin: margin,
      elevation: 2,
      color: bg,
      shadowColor: Colors.black.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: side,
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              child: content,
            ),
    );
    return outer;
  }
}

/// 状态胶囊（生命/精力/饱食/金币等）。
///
/// 示例：`StatPill(icon: Icons.favorite, label: '生命', value: '87', color: red)`。
/// 图标 + 标签 + 数值，胶囊底 + 金边。
class StatPill extends StatelessWidget {
  const StatPill({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.color = WesterosColors.goldBright,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: WesterosColors.barkMid.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(compact ? 8 : 10),
        border: Border.all(
          color: WesterosColors.outlineGold.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: compact ? 13 : 15, color: color),
          const SizedBox(width: 4),
          if (!compact) ...[
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: WesterosColors.inkDim,
              ),
            ),
            const SizedBox(width: 3),
          ],
          Text(
            value,
            style: theme.textTheme.labelMedium?.copyWith(
              color: WesterosColors.parchment,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// 金线分隔符（带中置饰章）。
class WesterosDivider extends StatelessWidget {
  const WesterosDivider({super.key, this.thickness = 1});

  final double thickness;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Container(
            height: thickness,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[
                  Colors.transparent,
                  WesterosColors.outlineGold,
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Transform.rotate(
            angle: 0.785398, // 45°
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: WesterosColors.gold,
                shape: BoxShape.rectangle,
              ),
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: thickness,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[
                  WesterosColors.outlineGold,
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 区块间装饰分隔（细金线 + 两侧留白）。
class SectionDivider extends StatelessWidget {
  const SectionDivider({super.key, this.height = 12});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: height / 2),
      child: const WesterosDivider(),
    );
  }
}
