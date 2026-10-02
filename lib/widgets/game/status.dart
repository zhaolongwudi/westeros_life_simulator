/// 主界面顶部状态摘要条 widget（Batch 10-29 · M3b 从 game_screen 拆出）。
///
/// Batch 10-60 UI 重造：改为金色徽章风格状态条——
/// 姓名身份行 + 生命/精力/饱食胶囊 + 年月季节 + 金币。
library;

import 'package:flutter/material.dart';

import '../../game_engine.dart';
import '../../theme/westeros_theme.dart';
import '../../utils/labels.dart';
import '../theme/ornate.dart';

/// 顶部状态摘要条。
class StatusBar extends StatelessWidget {
  const StatusBar({required this.engine});

  final GameEngine engine;

  @override
  Widget build(BuildContext context) {
    final p = engine.player;
    final loc = engine.currentLocation;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: WesterosColors.barkMid,
        border: Border(
          bottom: BorderSide(
            color: WesterosColors.outlineGold.withValues(alpha: 0.6),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 第一行：姓名 · 身份 · 年龄 · 地点
          Row(
            children: <Widget>[
              // 家族徽章图标
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: <Color>[
                      WesterosColors.goldDark,
                      WesterosColors.gold,
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  size: 14,
                  color: WesterosColors.barkDeep,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${p.name} · ${identityLabel(p.identity)} · ${p.age}岁'
                  '${loc != null ? ' · ${loc.name}' : ''}',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: WesterosColors.goldBright,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 第二行：状态胶囊 + 时间
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              StatPill(
                icon: Icons.favorite,
                label: '生命',
                value: '${p.health}',
                color: WesterosColors.bloodRed.withValues(alpha: 0.9),
                compact: true,
              ),
              StatPill(
                icon: Icons.bolt,
                label: '精力',
                value: '${p.energy}',
                color: WesterosColors.goldBright,
                compact: true,
              ),
              StatPill(
                icon: Icons.restaurant,
                label: '饱食',
                value: '${p.hunger}',
                color: const Color(0xFF8BC34A),
                compact: true,
              ),
              StatPill(
                icon: Icons.monetization_on_outlined,
                label: '金币',
                value: '${p.gold}',
                color: WesterosColors.goldBright,
                compact: true,
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: WesterosColors.barkDeep.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: WesterosColors.outlineGold.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  '${engine.progress.year}年${engine.progress.month}月 · ${seasonShortLabel(engine.progress.season)}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: WesterosColors.parchment,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
