/// 设置与存档界面：查看存档、保存/加载、导出/导入、新游戏。
///
/// 复用 SaveService（Batch 3）与 GameEngine。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game_engine.dart';
import '../providers/game_state_provider.dart';
import '../data/ai_provider_defaults.dart';
import '../services/ai_config.dart';
import '../services/save_service.dart';
import '../theme/westeros_theme.dart';
import '../utils/text_formats.dart';
import '../widgets/theme/ornate.dart';
import 'ai_config_screen.dart';

/// 设置/存档界面。
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.engine, this.saveService});

  /// 可选：传入共享引擎。
  ///
  /// S12-7：**为 null 时不再隐式 new 一局**（首页「设置」即为此路径）。
  /// null 表示「当前没有进行中的游戏」，界面只显示说明卡，不提供存档操作。
  final GameEngine? engine;

  /// 可选：注入存档服务（测试用；默认使用系统目录）。
  final SaveService? saveService;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// S12-7：**不再自己 new 一个 `GameEngine()..startNewGame()`**。
  ///
  /// 【为什么改】此前本文件在 `engine == null`（从首页「设置」进来）时
  /// 会隐式开局一局，然后无条件显示「保存/导出/导入/新游戏」——
  /// 玩家在首页点「设置 → 保存」会把一个**全新空游戏**存成档；
  /// 而 `继续游戏` 取按时间倒序的 `saves.first`（`home_screen.dart:64`），
  /// 于是这个空档会把玩家真进度**顶掉**。改为：没有引擎就不提供存档操作。
  GameEngine? get _engine => widget.engine;

  late final SaveService _saveService =
      widget.saveService ?? SaveService();

  List<SaveMetadata> _saves = <SaveMetadata>[];
  bool _loading = false;

  /// AI 配置（懒加载，仅首次进入时读取）。
  AiConfig? _aiConfig;

  /// 读取 AI 配置失败的原因（非空时卡片如实显示失败，不再假装「未配置」）。
  ///
  /// 【为什么必须区分「没配」和「读不出来」】两者此前都渲染成
  /// 「未配置 API Key」：存储一旦异常，玩家会以为是自己没填 Key，
  /// 反复重填也永远不生效，问题被界面吞掉。
  String _aiConfigError = '';

  @override
  void initState() {
    super.initState();
    _refreshSaves();
    _loadAiConfig();
  }

  /// 异步读取 AI 配置（失败不静默：把原因落到卡片副标题上）。
  Future<void> _loadAiConfig() async {
    try {
      final config = await AiConfig.load();
      if (!mounted) return;
      setState(() {
        _aiConfig = config;
        _aiConfigError = '';
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _aiConfigError = '$error');
    }
  }

  /// 刷新存档列表。
  Future<void> _refreshSaves() async {
    setState(() {
      _loading = true;
    });
    final saves = await _saveService.listSaves();
    if (!mounted) return;
    setState(() {
      _saves = saves;
      _loading = false;
    });
  }

  /// 保存当前游戏。
  Future<void> _saveGame() async {
    final engine = _engine;
    if (engine == null) {
      _showSnack('当前没有进行中的游戏，无法保存');
      return;
    }
    await _saveService.saveGame(engine);
    _showSnack('已保存');
    await _refreshSaves();
  }

  /// 加载指定存档。
  ///
  /// 失败语义（M1 存档契约）：
  /// - 坏档 → service 返回 null，文件已被隔离为 .corrupted，提示「已损坏」。
  /// - 版本过高 → service 抛 [UnsupportedSaveVersionException]，提示「请升级游戏」。
  /// - 无引擎（从首页进设置）→ 提示玩家回游戏内操作，不静默丢弃。
  Future<void> _loadGame(String saveId) async {
    final engine = _engine;
    if (engine == null) {
      _showSnack('请先进入游戏，再从「继续游戏」载入');
      return;
    }
    GameStateProvider? result;
    try {
      result = await _saveService.loadGame(saveId);
    } on UnsupportedSaveVersionException {
      if (mounted) _showSnack('存档来自更新版本，请升级游戏');
      return;
    }
    final state = result;
    if (!mounted) return;
    if (state == null) {
      _showSnack('存档已损坏，已隔离备份');
      await _refreshSaves();
      return;
    }
    // 用加载的 state 重置引擎（保留世界静态数据；默认引擎携带世界数据）
    setState(() {
      engine.applyState(state);
    });
    _showSnack('存档已加载：${state.player.name}');
    await _refreshSaves();
  }

  /// 导出当前存档为 JSON 字符串。
  void _exportSave() {
    final engine = _engine;
    if (engine == null) {
      _showSnack('当前没有进行中的游戏，无法导出');
      return;
    }
    final content = _saveService.exportSave(engine);
    // 复制到剪贴板
    Clipboard.setData(ClipboardData(text: content));
    _showSnack('存档已复制到剪贴板（${content.length} 字符）');
  }

  /// 导入存档 JSON 字符串。
  Future<void> _importSave() async {
    final content = await _promptText('粘贴存档 JSON');
    if (content == null || content.trim().isEmpty) return;
    GameStateProvider? result;
    try {
      result = _saveService.importSave(content.trim());
    } on UnsupportedSaveVersionException {
      if (mounted) _showSnack('存档来自更新版本，请升级游戏');
      return;
    } on Object {
      if (mounted) _showSnack('存档格式无效');
      return;
    }
    final state = result;
    if (!mounted) return;
    if (state == null) {
      _showSnack('存档格式无效');
      return;
    }
    // 用加载的 state 重置引擎（保留世界静态数据；默认引擎携带世界数据）
    setState(() {
      _engine?.applyState(state);
    });
    _showSnack('存档已导入：${state.player.name}');
    await _refreshSaves();
  }

  /// 删除指定存档。
  Future<void> _deleteSave(String saveId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除存档'),
        content: const Text('确定删除该存档吗？此操作不可恢复。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _saveService.deleteSave(saveId);
    _showSnack('已删除');
    await _refreshSaves();
  }

  /// 打开 AI 配置页（S17-1：从弹窗迁出，见 [AiConfigScreen] 的类注释）。
  ///
  /// 【为什么不再自己弹 AlertDialog】旧的窄弹窗在手机上既会被键盘挤压，又会
  /// 被误触关闭（遮罩可点 ⇒ 返回 null ⇒ 整块保存逻辑被跳过且没有任何提示）；
  /// 失败路径也不可见。全屏页把「保存中 / 保存失败原因 / 保存成功」全部显式
  /// 呈现，并且**只有保存成功才返回新配置**。
  Future<void> _editAiConfig() async {
    final config = _aiConfig ?? AiConfig.defaultConfig();
    final saved = await Navigator.of(context).push<AiConfig>(
      MaterialPageRoute<AiConfig>(
        builder: (_) => AiConfigScreen(initial: config),
      ),
    );
    if (saved == null || !mounted) return;
    setState(() {
      _aiConfig = saved;
      _aiConfigError = '';
    });
    _showSnack('AI 配置已保存（${saved.apiKeys.length} 个 Key）');
  }

  /// 新游戏（重置引擎）。
  void _newGame() {
    final engine = _engine;
    if (engine == null) {
      _showSnack('当前没有进行中的游戏');
      return;
    }
    setState(() {
      engine.startNewGame();
    });
    _showSnack('已开始新游戏');
  }

  /// 弹窗输入文本。
  Future<String?> _promptText(String title) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: '在这里粘贴存档 JSON…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('导入'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
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
      appBar: AppBar(title: const Text('设置 / 存档')),
      body: ParchmentBackground(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: <Widget>[
            // 当前玩家信息（S12-7：无引擎=从首页进来，不展示假玩家/存档按钮）
            if (_engine == null)
              GildedCard(
                child: ListTile(
                  leading: const Icon(
                    Icons.info_outline,
                    color: WesterosColors.goldBright,
                  ),
                  title: const Text(
                    '尚未开始游戏',
                    style: TextStyle(
                      color: WesterosColors.parchment,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: const Text(
                    '存档相关的保存、导出与导入操作需在游戏内进行。开始或继续一局后，这里会出现对应按钮。',
                    style: TextStyle(color: WesterosColors.inkDim),
                  ),
                ),
              )
            else ...<Widget>[
              GildedCard(
                child: ListTile(
                  leading: const Icon(
                    Icons.person_outline,
                    color: WesterosColors.goldBright,
                  ),
                  title: Text(
                    _engine!.player.name,
                    style: const TextStyle(
                      color: WesterosColors.parchment,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    '${_engine!.progress.year}年${_engine!.progress.month}月 · '
                    '回合 ${_engine!.progress.turnCount} · '
                    '${_engine!.player.gold} 金币',
                    style: const TextStyle(color: WesterosColors.inkDim),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // 操作按钮
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _GoldButton(
                    icon: Icons.save_outlined,
                    label: '保存',
                    filled: true,
                    onPressed: _saveGame,
                  ),
                  _GoldButton(
                    icon: Icons.upload_file_outlined,
                    label: '导出',
                    onPressed: _exportSave,
                  ),
                  _GoldButton(
                    icon: Icons.download_outlined,
                    label: '导入',
                    onPressed: _importSave,
                  ),
                  _GoldButton(
                    icon: Icons.refresh,
                    label: '新游戏',
                    onPressed: _newGame,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            // AI 配置卡片
            GildedCard(
              child: ListTile(
                leading: Icon(
                  Icons.auto_awesome,
                  color: (_aiConfig?.isConfigured ?? false)
                      ? WesterosColors.goldBright
                      : WesterosColors.inkDim,
                ),
                title: const Text(
                  'AI 配置',
                  style: TextStyle(
                    color: WesterosColors.parchment,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  // 读取失败必须显示失败本身：否则「存储坏了」和「没填 Key」
                  // 长得一模一样，玩家会一直重填一个永远读不出来的输入框。
                  _aiConfigError.isNotEmpty
                      ? '配置读取失败：$_aiConfigError'
                      : (_aiConfig?.isConfigured ?? false)
                          ? '已配置 ${_aiConfig!.apiKeys.length} 个 Key · '
                              '${providerDefaultsOf(_aiConfig!.provider).label} · '
                              '${_aiConfig!.resolvedModel}'
                          : '未配置 API Key（AI 行动模式不可用）',
                  style: const TextStyle(color: WesterosColors.inkDim),
                ),
                trailing: IconButton(
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: WesterosColors.goldBright,
                  ),
                  tooltip: '编辑',
                  onPressed: _editAiConfig,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 存档列表
            const OrnateHeader(
              icon: Icons.archive_outlined,
              title: '存档列表',
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(
                    color: WesterosColors.gold,
                  ),
                ),
              )
            else if (_saves.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    '暂无存档',
                    style: TextStyle(color: WesterosColors.inkDim),
                  ),
                ),
              )
            else
              for (final save in _saves)
                GildedCard(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(
                      Icons.archive_outlined,
                      color: WesterosColors.goldBright,
                    ),
                    title: Text(
                      '${save.playerName} · ${save.year}年${save.month}月',
                      style: const TextStyle(color: WesterosColors.parchment),
                    ),
                    subtitle: Text(
                      '回合 ${save.turnCount} · ${formatDateTime(save.saveTime)}',
                      style: const TextStyle(color: WesterosColors.inkDim),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        IconButton(
                          icon: const Icon(
                            Icons.play_arrow,
                            color: WesterosColors.goldBright,
                          ),
                          tooltip: '加载',
                          onPressed: () => _loadGame(save.saveId),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: WesterosColors.bloodRed,
                          ),
                          tooltip: '删除',
                          onPressed: () => _deleteSave(save.saveId),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// 金色饰边操作按钮（保存/导出/导入/新游戏）。
class _GoldButton extends StatelessWidget {
  const _GoldButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final foreground = filled ? WesterosColors.barkDeep : WesterosColors.goldBright;
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 18, color: foreground),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: foreground,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: filled
              ? const LinearGradient(
                  colors: <Color>[
                    WesterosColors.goldDark,
                    WesterosColors.gold,
                  ],
                )
              : null,
          color: filled ? null : WesterosColors.barkMid.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: filled
                ? WesterosColors.goldBright
                : WesterosColors.outlineGold.withValues(alpha: 0.7),
            width: filled ? 1 : 1.2,
          ),
        ),
        child: child,
      ),
    );
  }
}