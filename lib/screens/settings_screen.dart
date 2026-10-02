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
import '../utils/text_formats.dart';

/// 设置/存档界面。
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.engine, this.saveService});

  /// 可选：传入共享引擎（默认新建）。
  final GameEngine? engine;

  /// 可选：注入存档服务（测试用；默认使用系统目录）。
  final SaveService? saveService;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final GameEngine _engine = widget.engine ?? (GameEngine()..startNewGame());
  late final SaveService _saveService =
      widget.saveService ?? SaveService();

  List<SaveMetadata> _saves = <SaveMetadata>[];
  bool _loading = false;

  /// AI 配置（懒加载，仅首次进入时读取）。
  AiConfig? _aiConfig;

  @override
  void initState() {
    super.initState();
    _refreshSaves();
    _loadAiConfig();
  }

  /// 异步读取 AI 配置。
  Future<void> _loadAiConfig() async {
    final config = await AiConfig.load();
    if (!mounted) return;
    setState(() => _aiConfig = config);
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
    await _saveService.saveGame(_engine);
    _showSnack('已保存');
    await _refreshSaves();
  }

  /// 加载指定存档。
  ///
  /// 失败语义（M1 存档契约）：
  /// - 坏档 → service 返回 null，文件已被隔离为 .corrupted，提示「已损坏」。
  /// - 版本过高 → service 抛 [UnsupportedSaveVersionException]，提示「请升级游戏」。
  Future<void> _loadGame(String saveId) async {
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
      _engine.applyState(state);
    });
    _showSnack('存档已加载：${state.player.name}');
    await _refreshSaves();
  }

  /// 导出当前存档为 JSON 字符串。
  void _exportSave() {
    final content = _saveService.exportSave(_engine);
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
      _engine.applyState(state);
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

  /// 编辑 AI 配置（Batch 10-59：提供商预设 + 多 Key + 模型下拉）。
  Future<void> _editAiConfig() async {
    final config = _aiConfig ?? AiConfig.defaultConfig();
    // 多 key：换行分隔展示，便于粘贴多个。
    final keysController = TextEditingController(
      text: config.apiKeys.join('\n'),
    );
    final modelController = TextEditingController(text: config.model);
    final baseUrlController = TextEditingController(text: config.baseUrl);
    var selectedProvider = config.provider;
    var selectedModel = config.model;
    // 候选模型随 provider 变化。
    var candidateModels = providerDefaultsOf(selectedProvider).models;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final defaults = providerDefaultsOf(selectedProvider);
          return AlertDialog(
            title: const Text('AI 配置'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('提供商', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: selectedProvider,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: kAiProviderDefaults
                        .map((d) => DropdownMenuItem<String>(
                              value: d.name,
                              child: Text(d.label),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setDialogState(() {
                        selectedProvider = v;
                        // 切换提供商时模型跟随默认，baseUrl 清空（回落默认）。
                        candidateModels = providerDefaultsOf(v).models;
                        selectedModel = '';
                        modelController.text = '';
                        baseUrlController.text = '';
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text('API Key（每行一个，自动轮换）',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: keysController,
                    maxLines: 5,
                    minLines: 3,
                    decoration: const InputDecoration(
                      hintText: '粘贴 API Key，每行一个\n多个 Key 会自动轮换，单个 Key 限流时自动切换',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('模型', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    // provider 切换时强制重建下拉（initialValue 只在首次 build 生效）。
                    key: ValueKey<String>('model_$selectedProvider'),
                    initialValue: selectedModel.isEmpty
                        ? defaults.model
                        : selectedModel,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: candidateModels
                        .map((m) => DropdownMenuItem<String>(
                              value: m,
                              child: Text(m),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setDialogState(() {
                        selectedModel = v;
                        modelController.text = v;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text('Base URL（留空用默认）',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: baseUrlController,
                    decoration: InputDecoration(
                      hintText: defaults.baseUrl,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '默认：${defaults.baseUrl} · ${defaults.model}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );

    if (saved == true) {
      final keys = keysController.text
          .split('\n')
          .map((k) => k.trim())
          .where((k) => k.isNotEmpty)
          .toList();
      final newConfig = AiConfig(
        apiKeys: keys,
        model: selectedModel,
        baseUrl: baseUrlController.text.trim(),
        provider: selectedProvider,
      );
      await newConfig.save();
      if (!mounted) return;
      setState(() => _aiConfig = newConfig);
      _showSnack('AI 配置已保存（${keys.length} 个 Key）');
    }
    keysController.dispose();
    modelController.dispose();
    baseUrlController.dispose();
  }

  /// 新游戏（重置引擎）。
  void _newGame() {
    setState(() {
      _engine.startNewGame();
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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('设置 / 存档')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: <Widget>[
          // 当前玩家信息
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(_engine.player.name),
              subtitle: Text(
                '${_engine.progress.year}年${_engine.progress.month}月 · '
                '回合 ${_engine.progress.turnCount} · '
                '${_engine.player.gold} 金币',
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 操作按钮
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.icon(
                icon: const Icon(Icons.save_outlined),
                label: const Text('保存'),
                onPressed: _saveGame,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('导出'),
                onPressed: _exportSave,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.download_outlined),
                label: const Text('导入'),
                onPressed: _importSave,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('新游戏'),
                onPressed: _newGame,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // AI 配置卡片
          Card(
            child: ListTile(
              leading: Icon(
                Icons.auto_awesome,
                color: (_aiConfig?.isConfigured ?? false)
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
              title: const Text('AI 配置'),
              subtitle: Text(
                (_aiConfig?.isConfigured ?? false)
                    ? '已配置 ${_aiConfig!.apiKeys.length} 个 Key · ${providerDefaultsOf(_aiConfig!.provider).label} · ${_aiConfig!.resolvedModel}'
                    : '未配置 API Key（AI 行动模式不可用）',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: '编辑',
                onPressed: _editAiConfig,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 存档列表
          Text('存档列表（${_saves.length}）', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_loading)
            const Center(child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ))
          else if (_saves.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Text('暂无存档')),
            )
          else
            for (final save in _saves)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.archive_outlined),
                  title: Text(
                    '${save.playerName} · ${save.year}年${save.month}月',
                  ),
                  subtitle: Text(
                    '回合 ${save.turnCount} · ${formatDateTime(save.saveTime)}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      IconButton(
                        icon: const Icon(Icons.play_arrow),
                        tooltip: '加载',
                        onPressed: () => _loadGame(save.saveId),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: '删除',
                        onPressed: () => _deleteSave(save.saveId),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}