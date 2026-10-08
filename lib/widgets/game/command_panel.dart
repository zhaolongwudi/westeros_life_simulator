/// 指令面板 widget（S12-9 · 47 条命令按键化）。
///
/// 【背景】主界面底部横条固定 `height: 38`，只放了 8 个最高频命令，
/// 其余 39 条**只能手打**（`S11-6` 量化前提，`S12-9` 落地）。
///
/// 【为什么是面板而不是把 47 个 chip 塞进横条】窄屏必然溢出；且 47 个
/// 平铺没有可扫读的结构。方案（用户已拍板）：
/// - 底部横条精简到 6 个最高频（状态/工作/狩猎/探索/休息/过月）
/// - 输入框旁「指令」按钮 → 本面板：**分组 + 搜索**，47 条全在里面
/// - 零参数命令**点一下即执行**；需参数命令**预填输入框**（不误触、不白点）
///
/// 【分层约束】本 widget 不 import 混入层/引擎，只吃 [CommandSpec] 列表
/// 与两个回调，与 `nav_grid.dart` 同构（M3b 分层约束）。
library;

import 'package:flutter/material.dart';

import '../../core/command_registry.dart';
import '../../theme/westeros_theme.dart';

/// 指令面板（弹出层内容）。
class CommandPanel extends StatefulWidget {
  const CommandPanel({
    super.key,
    required this.specs,
    required this.onRun,
    required this.onPrefill,
  });

  /// 全部指令描述（面板按 `group` 聚合、按 `order` 排序）。
  final List<CommandSpec> specs;

  /// 零参数指令：点一下直接执行。
  final ValueChanged<CommandSpec> onRun;

  /// 需参数指令：把「主名 + 空格」预填进输入框并聚焦，由玩家补参数。
  final ValueChanged<CommandSpec> onPrefill;

  @override
  State<CommandPanel> createState() => _CommandPanelState();
}

class _CommandPanelState extends State<CommandPanel> {
  final TextEditingController _search = TextEditingController();
  String _keyword = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// 关键词过滤：匹配**主名或任一别名或帮助行**，大小写不敏感。
  ///
  /// 别名一起匹配是必要的——玩家可能记得 `sword` 却忘了中文名，
  /// 也可能记得「训练」而想不起参数。
  bool _matches(CommandSpec spec) {
    if (_keyword.isEmpty) return true;
    final k = _keyword.toLowerCase();
    if (spec.aliases.any((a) => a.toLowerCase().contains(k))) return true;
    if (spec.helpLine.toLowerCase().contains(k)) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = widget.specs.where(_matches).toList();

    // 分组顺序沿用 kCommandGroupOrder，未知分组排最后（与注册表一致）。
    final buckets = <String, List<CommandSpec>>{};
    for (final s in visible) {
      buckets.putIfAbsent(s.group, () => <CommandSpec>[]).add(s);
    }
    final known = kCommandGroupOrder.where(buckets.containsKey).toList();
    final extra = buckets.keys
        .where((g) => !kCommandGroupOrder.contains(g))
        .toList()
      ..sort();
    final groups = <String>[...known, ...extra];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.terminal_outlined,
                    size: 20, color: WesterosColors.goldBright),
                const SizedBox(width: 8),
                Text(
                  '指令',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: WesterosColors.goldBright,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${visible.length}/${widget.specs.length}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: WesterosColors.parchmentDim,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _search,
              onChanged: (v) => setState(() => _keyword = v.trim()),
              style: const TextStyle(color: WesterosColors.parchment),
              decoration: InputDecoration(
                isDense: true,
                hintText: '搜索指令（中文名 / 英文别名）',
                hintStyle: TextStyle(
                  color: WesterosColors.parchmentDim.withValues(alpha: 0.7),
                ),
                prefixIcon: const Icon(Icons.search,
                    size: 18, color: WesterosColors.parchmentDim),
                filled: true,
                fillColor: WesterosColors.barkMid,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: WesterosColors.outlineGold.withValues(alpha: 0.5),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: WesterosColors.outlineGold.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // 47 条平铺会超出弹层高度 ⇒ 必须可滚动；shrinkWrap 让短内容不占满。
            Flexible(
              child: visible.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        '没有匹配「$_keyword」的指令。',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: WesterosColors.parchmentDim,
                        ),
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: <Widget>[
                        for (final g in groups) ...<Widget>[
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 6),
                            child: Text(
                              g,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: WesterosColors.gold,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: <Widget>[
                              for (final spec in buckets[g]!)
                                _CommandChip(
                                  spec: spec,
                                  onTap: () => spec.needsArgs
                                      ? widget.onPrefill(spec)
                                      : widget.onRun(spec),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              '点零参数指令直接执行；需参数的会填进输入框，补完再发送。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: WesterosColors.parchmentDim,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 单条指令按钮。
class _CommandChip extends StatelessWidget {
  const _CommandChip({required this.spec, required this.onTap});

  final CommandSpec spec;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 需参数的用「描边 + 参数提示」区分，避免玩家点了以为没反应。
    final needsArgs = spec.needsArgs;
    return ActionChip(
      label: Text(needsArgs ? '${spec.aliases.first} …' : spec.aliases.first),
      avatar: needsArgs
          ? const Icon(Icons.edit_outlined,
              size: 14, color: WesterosColors.parchmentDim)
          : null,
      backgroundColor: WesterosColors.barkMid,
      side: BorderSide(
        color: WesterosColors.outlineGold
            .withValues(alpha: needsArgs ? 0.4 : 0.7),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      labelStyle: TextStyle(
        color: needsArgs ? WesterosColors.parchmentDim : WesterosColors.parchment,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      tooltip: spec.helpLine,
      onPressed: onTap,
    );
  }
}
