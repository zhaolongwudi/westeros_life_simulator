/// 游戏主界面：玩家状态面板 + 指令输入 + 叙事输出区 + 快捷指令。
///
/// 直接操作 [GameEngine]（Batch 4 混入层宿主），
/// 指令分发复用 GameCommandsMixin.resolveCommand。
library;

import 'package:flutter/material.dart';

import '../game_engine.dart';
import 'events_screen.dart';
import 'family_screen.dart';
import 'letters_screen.dart';
import 'map_screen.dart';
import 'player_panel_screen.dart';
import 'settings_screen.dart';
import 'systems_screen.dart';

/// 快捷指令按钮配置。
class _QuickCommand {
  const _QuickCommand(this.label, this.command);

  final String label;
  final String command;
}

/// 游戏主界面。
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, this.engine});

  /// 可选：传入已初始化的引擎（开局界面使用）；默认新建。
  final GameEngine? engine;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final GameEngine _engine = widget.engine ?? GameEngine()..startNewGame();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  /// 叙事输出行（最新在底部）。
  final List<String> _lines = <String>[];

  /// 快捷指令（参考 mixin_commands 帮助）。
  static const List<_QuickCommand> _quickCommands = <_QuickCommand>[
    _QuickCommand('状态', '状态'),
    _QuickCommand('工作', '工作'),
    _QuickCommand('训练剑术', '训练 sword'),
    _QuickCommand('狩猎', '狩猎'),
    _QuickCommand('贸易', '贸易'),
    _QuickCommand('探索', '探索'),
    _QuickCommand('旅行', '旅行'),
    _QuickCommand('过月', '过月'),
  ];

  @override
  void initState() {
    super.initState();
    // 监听引擎变化（状态条/叙事随游戏推进刷新）
    _engine.addListener(_onEngineChanged);
    // 初始叙事
    _appendLine('🏰 欢迎来到维斯特洛。');
    _appendLine(_engine.formatPlayerPanel());
    _appendLine('输入「帮助」查看可用指令，或点击下方快捷按钮。');
  }

  @override
  void dispose() {
    _engine.removeListener(_onEngineChanged);
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 引擎变化（金币/时间/地点等）→ 刷新界面。
  void _onEngineChanged() {
    if (mounted) setState(() {});
  }

  /// 追加一行叙事，并滚动到底部。
  void _appendLine(String text) {
    setState(() {
      _lines.add(text);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// 提交并执行指令。
  void _submitCommand(String raw) {
    final input = raw.trim();
    if (input.isEmpty) return;
    _inputController.clear();

    final result = _engine.resolveCommand(input);
    _appendLine('> $input');
    _appendLine(result.text);
  }

  /// 打开子界面。
  void _openScreen(Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('维斯特洛人生模拟器'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.event_note_outlined),
            tooltip: '事件',
            onPressed: () => _openScreen(EventsScreen(engine: _engine)),
          ),
          IconButton(
            icon: const Icon(Icons.mail_outlined),
            tooltip: '信件',
            onPressed: () => _openScreen(LettersScreen(engine: _engine)),
          ),
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: '地图',
            onPressed: () => _openScreen(MapScreen(engine: _engine)),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '设置/存档',
            onPressed: () => _openScreen(SettingsScreen(engine: _engine)),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // 玩家状态摘要条
            _StatusBar(engine: _engine),
            // 快捷指令
            _QuickCommandBar(
              commands: _quickCommands,
              onTap: _submitCommand,
            ),
            // 叙事输出区
            Expanded(
              child: _NarrativeView(
                lines: _lines,
                scrollController: _scrollController,
                engine: _engine,
                onOpenPanel: _openScreen,
              ),
            ),
            // 指令输入区
            _CommandInputBar(
              controller: _inputController,
              onSubmitted: _submitCommand,
            ),
          ],
        ),
      ),
    );
  }
}

/// 顶部状态摘要条。
class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.engine});

  final GameEngine engine;

  @override
  Widget build(BuildContext context) {
    final p = engine.player;
    final loc = engine.currentLocation;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              '${p.name} · ${p.identity.name} · ${p.age}岁'
              '${loc != null ? ' · ${loc.name}' : ''}',
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${engine.progress.year}年${engine.progress.month}月 ${_seasonLabel(engine.progress.season)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  /// 季节英文名转中文。
  static String _seasonLabel(String season) {
    return switch (season) {
      'spring' => '春',
      'summer' => '夏',
      'autumn' => '秋',
      'winter' => '冬',
      _ => season,
    };
  }
}

/// 快捷指令栏。
class _QuickCommandBar extends StatelessWidget {
  const _QuickCommandBar({required this.commands, required this.onTap});

  final List<_QuickCommand> commands;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: commands.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (context, index) {
            final cmd = commands[index];
            return ActionChip(
              label: Text(cmd.label),
              onPressed: () => onTap(cmd.command),
            );
          },
        ),
      ),
    );
  }
}

/// 叙事输出区。
class _NarrativeView extends StatelessWidget {
  const _NarrativeView({
    required this.lines,
    required this.scrollController,
    required this.engine,
    required this.onOpenPanel,
  });

  final List<String> lines;
  final ScrollController scrollController;
  final GameEngine engine;
  final ValueChanged<Widget> onOpenPanel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: lines.length + 1,
      itemBuilder: (context, index) {
        // 末尾附：面板快捷入口
        if (index == lines.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _PanelEntry(
                  icon: Icons.person_outline,
                  label: '玩家详情',
                  color: theme.colorScheme.primary,
                  onTap: () => onOpenPanel(PlayerPanelScreen(engine: engine)),
                ),
                _PanelEntry(
                  icon: Icons.family_restroom,
                  label: '家族面板',
                  color: theme.colorScheme.tertiary,
                  onTap: () => onOpenPanel(FamilyScreen(engine: engine)),
                ),
                _PanelEntry(
                  icon: Icons.grid_view_outlined,
                  label: '系统面板',
                  color: theme.colorScheme.secondary,
                  onTap: () => onOpenPanel(SystemsScreen(engine: engine)),
                ),
                _PanelEntry(
                  icon: Icons.map_outlined,
                  label: '地图',
                  color: theme.colorScheme.primary,
                  onTap: () => onOpenPanel(MapScreen(engine: engine)),
                ),
              ],
            ),
          );
        }

        final line = lines[index];
        final isCommand = line.startsWith('> ');
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Align(
            alignment: isCommand ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isCommand
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                line,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontFamily: isCommand ? null : 'monospace',
                      height: 1.4,
                    ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 面板快捷入口按钮。
class _PanelEntry extends StatelessWidget {
  const _PanelEntry({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: color),
      label: Text(label),
      onPressed: onTap,
    );
  }
}

/// 指令输入栏。
class _CommandInputBar extends StatelessWidget {
  const _CommandInputBar({
    required this.controller,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: '输入指令（如 工作 / 训练 sword / 过月）',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: onSubmitted,
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            icon: const Icon(Icons.send),
            tooltip: '发送',
            onPressed: () => onSubmitted(controller.text),
          ),
        ],
      ),
    );
  }
}
