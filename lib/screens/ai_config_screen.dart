/// AI 配置页（S17-1）：从设置页的窄弹窗迁出为独立全屏页面。
///
/// 【为什么要迁出】原实现是 `AlertDialog`，存在两条「配置看起来保存不了」的路径：
/// 1. **可误触关闭**：`showDialog` 的 `barrierDismissible` 默认为 true。手机上
///    键盘把对话框挤上去之后，玩家点「保存」时手指一旦落在对话框外的遮罩上，
///    弹窗会直接关闭并返回 `null`；设置页那段 `if (saved == true) { ... }`
///    整块被跳过 —— 配置不落盘，**而且一句提示都没有**。
/// 2. **失败不可见**：`await config.save()` 没有 try/catch，平台通道一旦抛异常，
///    同一个 `if` 块从中间断掉，`_showSnack('已保存')` 永远不执行，玩家看到的
///    仍然只是「弹窗关了、什么都没发生」。
///
/// 本页对症处理：没有可误触的遮罩；保存按钮固定在底部（随键盘上移，始终可点）；
/// 保存走「写入 → 回读校验 → 成败提示」，**失败一定看得见**。
library;

import 'package:flutter/material.dart';

import '../data/ai_provider_defaults.dart';
import '../services/ai_config.dart';
import '../services/ai_service.dart';
import '../theme/westeros_theme.dart';
import '../widgets/theme/ornate.dart';

/// AI 配置页。
///
/// 保存成功时以 `Navigator.pop(context, config)` 返回新配置，调用方据此刷新卡片。
class AiConfigScreen extends StatefulWidget {
  const AiConfigScreen({super.key, required this.initial});

  /// 进入页面时的当前配置（由调用方传入，避免进页面再读一次导致初始值分歧）。
  final AiConfig initial;

  @override
  State<AiConfigScreen> createState() => _AiConfigScreenState();
}

class _AiConfigScreenState extends State<AiConfigScreen> {
  late final TextEditingController _keysController =
      TextEditingController(text: widget.initial.apiKeys.join('\n'));
  late final TextEditingController _baseUrlController =
      TextEditingController(text: widget.initial.baseUrl);
  late String _provider = widget.initial.provider;
  late String _model = widget.initial.model;
  late List<String> _customModels = <String>[...widget.initial.customModels];

  /// 保存中（防连点；按钮同时置灰）。
  bool _saving = false;

  /// 连通性测试 / 自动识别的进行态与结果。
  bool _testing = false;
  bool _fetching = false;
  String _testResult = '';
  String _fetchResult = '';

  @override
  void dispose() {
    _keysController.dispose();
    _baseUrlController.dispose();
    super.dispose();
  }

  /// 当前输入的全部 Key（每行一个，去空行）。
  List<String> get _keys => _keysController.text
      .split('\n')
      .map((k) => k.trim())
      .where((k) => k.isNotEmpty)
      .toList();

  /// 全部可选模型：提供商候选 ∪ 自定义 ∪ 当前激活（去重保序）。
  List<String> get _allModels {
    final seen = <String>{};
    final result = <String>[];
    for (final m in providerDefaultsOf(_provider).models) {
      if (seen.add(m)) result.add(m);
    }
    for (final m in _customModels) {
      if (seen.add(m)) result.add(m);
    }
    if (_model.isNotEmpty && seen.add(_model)) result.add(_model);
    return result;
  }

  /// 当前生效的 BaseURL（留空回落提供商默认）。
  String get _effectiveBaseUrl => _baseUrlController.text.trim().isEmpty
      ? providerDefaultsOf(_provider).baseUrl
      : _baseUrlController.text.trim();

  /// 保存：写入 → 回读校验 → 成功返回，失败留在本页并给出原因。
  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _testResult = '';
      _fetchResult = '';
    });
    final config = AiConfig(
      apiKeys: _keys,
      model: _model,
      baseUrl: _baseUrlController.text.trim(),
      provider: _provider,
      customModels: _customModels,
    );
    try {
      await config.save();
      // 回读校验：写盘「成功」但读不回来（存储异常 / 键名漂移）必须当场暴露，
      // 否则玩家看到「已保存」却每回合都被告知「未配置 AI Key」。
      final reloaded = await AiConfig.load();
      if (reloaded.apiKeys.length != config.apiKeys.length) {
        throw StateError(
          '回读校验失败：写入 ${config.apiKeys.length} 个 Key，'
          '读回 ${reloaded.apiKeys.length} 个',
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(config);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showSnack('保存失败：$error', isError: true);
    }
  }

  /// 自动识别厂商模型：GET {baseUrl}/models，结果并入自定义模型列表。
  Future<void> _fetchModels() async {
    final keys = _keys;
    if (keys.isEmpty) {
      setState(() => _fetchResult = '请先填入至少一个 API Key');
      return;
    }
    setState(() {
      _fetching = true;
      _fetchResult = '';
    });
    final service = AiService(
      apiKeys: keys,
      baseUrl: normalizeOpenAiBaseUrl(_effectiveBaseUrl),
      model: 'ping',
    );
    final models = await service.fetchModels();
    if (!mounted) return;
    setState(() {
      _fetching = false;
      if (models.isEmpty) {
        _fetchResult = '未能识别模型（接口无数据或不可用）';
      } else {
        // 并入自定义列表（去重保序），不覆盖用户已加的。
        final merged = <String>[..._customModels];
        for (final m in models) {
          if (!merged.contains(m)) merged.add(m);
        }
        _customModels = merged;
        if (_model.isEmpty) _model = models.first;
        _fetchResult = '识别到 ${models.length} 个模型';
      }
    });
  }

  /// 手动添加模型（加入自定义列表并激活）。
  Future<void> _addCustomModel() async {
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
    if (name == null || name.isEmpty || !mounted) return;
    setState(() {
      if (!_customModels.contains(name)) {
        _customModels = <String>[..._customModels, name];
      }
      _model = name;
    });
  }

  /// 连通性测试：用当前 Key/BaseURL/模型发最小请求，结果显示在页面内。
  Future<void> _testConnection() async {
    final keys = _keys;
    if (keys.isEmpty) {
      setState(() => _testResult = '请先填入至少一个 API Key');
      return;
    }
    setState(() {
      _testing = true;
      _testResult = '';
    });
    final service = AiService(
      apiKeys: keys,
      baseUrl: normalizeOpenAiBaseUrl(_effectiveBaseUrl),
      model: _model,
    );
    final (ok, msg) = await service.testConnection(model: _model);
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testResult = ok ? msg : '连接失败：$msg';
    });
  }

  /// 页面内提示。
  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? WesterosColors.bloodRed : null,
        duration: Duration(seconds: isError ? 6 : 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaults = providerDefaultsOf(_provider);
    return Scaffold(
      appBar: AppBar(title: const Text('AI 配置')),
      body: ParchmentBackground(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            const OrnateHeader(icon: Icons.auto_awesome, title: '提供商与模型'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _provider,
              decoration: const InputDecoration(
                labelText: '提供商',
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
                setState(() {
                  _provider = v;
                  // 切换提供商时模型跟随默认、baseUrl 清空（回落默认）。
                  _model = '';
                  _baseUrlController.text = '';
                  _testResult = '';
                  _fetchResult = '';
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              // provider 变化时强制重建下拉（initialValue 只在首次 build 生效）。
              key: ValueKey<String>('model_$_provider'),
              initialValue: _model.isEmpty ? defaults.model : _model,
              decoration: const InputDecoration(
                labelText: '模型',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: _allModels
                  .map((m) => DropdownMenuItem<String>(
                        value: m,
                        child: Text(m),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _model = v);
              },
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                TextButton.icon(
                  onPressed: _fetching ? null : _fetchModels,
                  icon: _fetching
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.settings_input_antenna, size: 16),
                  label: Text(_fetching ? '识别中…' : '自动识别模型'),
                ),
                TextButton.icon(
                  onPressed: _addCustomModel,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('添加模型'),
                ),
                TextButton.icon(
                  onPressed: _testing ? null : _testConnection,
                  icon: _testing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_tethering, size: 16),
                  label: Text(_testing ? '测试中…' : '测试连接'),
                ),
              ],
            ),
            if (_fetchResult.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                _fetchResult,
                style: TextStyle(
                  color: _fetchResult.startsWith('识别到')
                      ? WesterosColors.goldBright
                      : WesterosColors.bloodRed,
                  fontSize: 12,
                ),
              ),
            ],
            if (_testResult.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                _testResult,
                style: TextStyle(
                  color: _testResult.contains('连接正常')
                      ? WesterosColors.goldBright
                      : WesterosColors.bloodRed,
                  fontSize: 12,
                ),
              ),
            ],
            if (_customModels.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text('自定义模型', style: theme.textTheme.titleSmall),
              for (final m in _customModels)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(m, style: const TextStyle(fontSize: 13)),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    tooltip: '移除',
                    onPressed: () => setState(() {
                      _customModels =
                          _customModels.where((x) => x != m).toList();
                      if (_model == m) _model = '';
                    }),
                  ),
                ),
            ],
            const SizedBox(height: 16),
            const OrnateHeader(icon: Icons.vpn_key_outlined, title: 'API Key'),
            const SizedBox(height: 8),
            TextField(
              controller: _keysController,
              maxLines: 5,
              minLines: 3,
              decoration: const InputDecoration(
                hintText: '粘贴 API Key，每行一个\n多个 Key 会自动轮换，单个 Key 限流时自动切换',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _baseUrlController,
              decoration: InputDecoration(
                labelText: 'Base URL（留空用默认）',
                hintText: defaults.baseUrl,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '默认：${defaults.baseUrl} · ${defaults.model}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      // 保存按钮固定在底部：键盘弹出时随之上移，不会像弹窗那样被挤走或误触。
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? '保存中…' : '保存 AI 配置'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
