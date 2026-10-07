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
import '../services/ai_service.dart';
import '../services/save_service.dart';
import '../theme/westeros_theme.dart';
import '../utils/text_formats.dart';
import '../widgets/theme/ornate.dart';

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

  /// 编辑 AI 配置（Batch 10-59 提供商/多 Key；Batch 10-106 多模型 + 自动识别 + 连通性测试）。
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
    // 自定义模型（自动识别 / 手动添加后并入）。
    var customModels = <String>[...config.customModels];
    // 连通性测试 / 自动识别的状态与结果。
    var testing = false;
    var fetching = false;
    var testResult = '';
    var fetchResult = '';

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final defaults = providerDefaultsOf(selectedProvider);
          // 全部可选模型：提供商候选 + 自定义（去重）。
          final allModels = <String>[];
          final seen = <String>{};
          for (final m in providerDefaultsOf(selectedProvider).models) {
            if (seen.add(m)) allModels.add(m);
          }
          for (final m in customModels) {
            if (seen.add(m)) allModels.add(m);
          }
          if (selectedModel.isNotEmpty && seen.add(selectedModel)) {
            allModels.add(selectedModel);
          }
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
                    items: allModels
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
                  const SizedBox(height: 8),
                  // 自动识别模型 + 手动添加 + 连通性测试
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      TextButton.icon(
                        onPressed: fetching
                            ? null
                            : () => _fetchModels(
                                  setDialogState,
                                  baseUrlController,
                                  keysController,
                                  selectedProvider,
                                  () => customModels,
                                  (m) {
                                    customModels = m;
                                    if (selectedModel.isEmpty &&
                                        m.isNotEmpty) {
                                      selectedModel = m.first;
                                      modelController.text = m.first;
                                    }
                                  },
                                  (r) => fetchResult = r,
                                  (f) => fetching = f,
                                ),
                        icon: fetching
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.settings_input_antenna, size: 16),
                        label: Text(fetching ? '识别中…' : '自动识别模型'),
                      ),
                      TextButton.icon(
                        onPressed: () => _addCustomModel(
                          setDialogState,
                          modelController,
                          () => customModels,
                          (m) {
                            customModels = m;
                            selectedModel = m.last;
                            modelController.text = m.last;
                          },
                        ),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('添加模型'),
                      ),
                      TextButton.icon(
                        onPressed: testing
                            ? null
                            : () => _testConnection(
                                  setDialogState,
                                  baseUrlController,
                                  keysController,
                                  selectedProvider,
                                  selectedModel.isEmpty
                                      ? defaults.model
                                      : selectedModel,
                                  (r) => testResult = r,
                                  (t) => testing = t,
                                ),
                        icon: testing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.wifi_tethering, size: 16),
                        label: Text(testing ? '测试中…' : '测试连接'),
                      ),
                    ],
                  ),
                  if (fetchResult.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      fetchResult,
                      style: TextStyle(
                        color: fetchResult.startsWith('识别到')
                            ? WesterosColors.goldBright
                            : WesterosColors.bloodRed,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (testResult.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      testResult,
                      style: TextStyle(
                        color: testResult.contains('连接正常')
                            ? WesterosColors.goldBright
                            : WesterosColors.bloodRed,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (customModels.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('自定义模型', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    for (final m in customModels)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(m, style: const TextStyle(fontSize: 13)),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          tooltip: '移除',
                          onPressed: () => setDialogState(() {
                            customModels = customModels
                                .where((x) => x != m)
                                .toList();
                            if (selectedModel == m) {
                              selectedModel = '';
                              modelController.text = '';
                            }
                          }),
                        ),
                      ),
                  ],
                  const SizedBox(height: 8),
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
        customModels: customModels,
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

  /// 自动识别厂商模型：GET {baseUrl}/models，把识别结果并入自定义模型列表。
  void _fetchModels(
    StateSetter setDialogState,
    TextEditingController baseUrlController,
    TextEditingController keysController,
    String provider,
    List<String> Function() getCustom,
    void Function(List<String>) setCustom,
    void Function(String) setResult,
    void Function(bool) setFetching,
  ) async {
    setDialogState(() => setFetching(true));
    final keys = keysController.text
        .split('\n')
        .map((k) => k.trim())
        .where((k) => k.isNotEmpty)
        .toList();
    if (keys.isEmpty) {
      setDialogState(() {
        setFetching(false);
        setResult('请先填入至少一个 API Key');
      });
      return;
    }
    final baseUrl = baseUrlController.text.trim().isEmpty
        ? providerDefaultsOf(provider).baseUrl
        : baseUrlController.text.trim();
    final service = AiService(
      apiKeys: keys,
      baseUrl: normalizeOpenAiBaseUrl(baseUrl),
      model: 'ping',
    );
    final models = await service.fetchModels();
    if (!mounted) return;
    setDialogState(() {
      setFetching(false);
      if (models.isEmpty) {
        setResult('未能识别模型（接口无数据或不可用）');
      } else {
        // 并入自定义列表（去重保序），不覆盖用户已加的。
        final merged = <String>[...getCustom()];
        for (final m in models) {
          if (!merged.contains(m)) merged.add(m);
        }
        setCustom(merged);
        setResult('识别到 ${models.length} 个模型');
      }
    });
  }

  /// 手动添加模型（文本输入，加入自定义列表并激活）。
  void _addCustomModel(
    StateSetter setDialogState,
    TextEditingController modelController,
    List<String> Function() getCustom,
    void Function(List<String>) setCustom,
  ) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加模型'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '模型名称，如 deepseek-chat',
            border: OutlineInputBorder(),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('添加'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    if (!mounted) return;
    setDialogState(() {
      final merged = <String>[...getCustom()];
      if (!merged.contains(name)) merged.add(name);
      setCustom(merged);
      modelController.text = name;
    });
  }

  /// 连通性测试：用当前 Key/BaseURL/模型发最小请求，把结果显示在弹窗内。
  void _testConnection(
    StateSetter setDialogState,
    TextEditingController baseUrlController,
    TextEditingController keysController,
    String provider,
    String model,
    void Function(String) setResult,
    void Function(bool) setTesting,
  ) async {
    setDialogState(() => setTesting(true));
    final keys = keysController.text
        .split('\n')
        .map((k) => k.trim())
        .where((k) => k.isNotEmpty)
        .toList();
    if (keys.isEmpty) {
      setDialogState(() {
        setTesting(false);
        setResult('请先填入至少一个 API Key');
      });
      return;
    }
    final baseUrl = baseUrlController.text.trim().isEmpty
        ? providerDefaultsOf(provider).baseUrl
        : baseUrlController.text.trim();
    final service = AiService(
      apiKeys: keys,
      baseUrl: normalizeOpenAiBaseUrl(baseUrl),
      model: model,
    );
    final (ok, msg) = await service.testConnection(model: model);
    if (!mounted) return;
    setDialogState(() {
      setTesting(false);
      setResult(ok ? msg : '连接失败：$msg');
    });
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
                  (_aiConfig?.isConfigured ?? false)
                      ? '已配置 ${_aiConfig!.apiKeys.length} 个 Key · ${providerDefaultsOf(_aiConfig!.provider).label} · ${_aiConfig!.resolvedModel}'
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