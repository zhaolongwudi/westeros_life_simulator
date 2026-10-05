/// 开屏首页（主菜单）：开始新游戏 / 继续游戏（读档）/ 设置（含 AI 配置）。
///
/// Batch 10-105：App 每次打开先进主菜单，不再直接进开局向导；
/// 「继续游戏」读最近存档直接进主界面，「设置」可开局前配 AI。
library;

import 'package:flutter/material.dart';

import '../game_engine.dart';
import '../providers/game_state_provider.dart';
import '../services/save_service.dart';
import '../theme/westeros_theme.dart';
import '../widgets/theme/ornate.dart';
import 'game_screen.dart';
import 'settings_screen.dart';
import 'start_screen.dart';

/// 开屏首页。
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.saveService});

  /// 可选：注入存档服务（测试用；默认使用系统目录）。
  final SaveService? saveService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final SaveService _saveService = widget.saveService ?? SaveService();

  List<SaveMetadata> _saves = <SaveMetadata>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refreshSaves();
  }

  /// 刷新存档列表。
  Future<void> _refreshSaves() async {
    final saves = await _saveService.listSaves();
    if (!mounted) return;
    setState(() {
      _saves = saves;
      _loading = false;
    });
  }

  /// 开始新游戏 → 开局分步向导。
  void _startNewGame() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const StartScreen()),
    );
  }

  /// 继续游戏：加载最近存档进入主界面。
  Future<void> _continueGame() async {
    if (_saves.isEmpty) {
      _showSnack('暂无存档，先开始一段新人生吧');
      return;
    }
    final save = _saves.first;
    GameStateProvider? state;
    try {
      state = await _saveService.loadGame(save.saveId);
    } on UnsupportedSaveVersionException {
      if (mounted) _showSnack('存档来自更新版本，请升级游戏');
      return;
    }
    if (!mounted) return;
    if (state == null) {
      _showSnack('存档已损坏，已隔离备份');
      await _refreshSaves();
      return;
    }
    final engine = GameEngine()..applyState(state);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => GameScreen(engine: engine)),
    );
  }

  /// 打开设置（AI 配置 / 存档管理）。
  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(saveService: _saveService),
      ),
    );
  }

  /// 底部提示。
  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ParchmentBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const _HomeHero(),
                    const SizedBox(height: 36),
                    _HomeButton(
                      icon: Icons.play_arrow,
                      label: '开始新游戏',
                      filled: true,
                      onPressed: _startNewGame,
                    ),
                    const SizedBox(height: 12),
                    _HomeButton(
                      icon: Icons.history,
                      label: _continueLabel(),
                      filled: false,
                      enabled: !_loading && _saves.isNotEmpty,
                      onPressed: _continueGame,
                    ),
                    const SizedBox(height: 12),
                    _HomeButton(
                      icon: Icons.settings_outlined,
                      label: '设置（AI / 存档）',
                      filled: false,
                      onPressed: _openSettings,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '❖ 铁与火 · 冰与土之歌 ❖',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: WesterosColors.inkDim,
                        fontSize: 12,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 继续游戏按钮文案（有存档时显示最近存档名）。
  String _continueLabel() {
    if (_loading) return '继续游戏';
    if (_saves.isEmpty) return '继续游戏（暂无存档）';
    final s = _saves.first;
    return '继续游戏（${s.playerName} · ${s.year}年${s.month}月）';
  }
}

/// 首页头图：铁王座 + 标题 + 副标题。
class _HomeHero extends StatelessWidget {
  const _HomeHero();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.flag_outlined, size: 26, color: WesterosColors.steel),
            SizedBox(width: 18),
            Icon(
              Icons.workspace_premium_outlined,
              size: 46,
              color: WesterosColors.goldBright,
            ),
            SizedBox(width: 18),
            Icon(
              Icons.local_fire_department_outlined,
              size: 26,
              color: WesterosColors.bloodRed,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          '维斯特洛人生模拟器',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontFamily: 'serif',
                color: WesterosColors.goldBright,
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 10),
        const WesterosDivider(),
        const SizedBox(height: 12),
        const Text(
          '凛冬将至，写下你的人生篇章',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: WesterosColors.inkDim,
            fontSize: 14,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

/// 首页主菜单按钮。
class _HomeButton extends StatelessWidget {
  const _HomeButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.filled,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool filled;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final foreground =
        filled ? WesterosColors.barkDeep : WesterosColors.goldBright;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: GestureDetector(
        onTap: enabled ? onPressed : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            gradient: filled
                ? const LinearGradient(
                    colors: <Color>[
                      WesterosColors.goldDark,
                      WesterosColors.gold,
                    ],
                  )
                : null,
            color: filled ? null : WesterosColors.barkMid.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: filled
                  ? WesterosColors.goldBright
                  : WesterosColors.outlineGold.withValues(alpha: 0.7),
              width: filled ? 1 : 1.2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 22, color: foreground),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}