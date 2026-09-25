/// 设置与存档界面：查看存档、保存/加载、导出/导入、新游戏。
///
/// 复用 SaveService（Batch 3）与 GameEngine。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game_engine.dart';
import '../services/save_service.dart';

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
  late final GameEngine _engine = widget.engine ?? GameEngine()..startNewGame();
  late final SaveService _saveService =
      widget.saveService ?? SaveService();

  List<SaveMetadata> _saves = <SaveMetadata>[];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refreshSaves();
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
  Future<void> _loadGame(String saveId) async {
    final state = await _saveService.loadGame(saveId);
    if (!mounted) return;
    if (state == null) {
      _showSnack('存档加载失败');
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
    final state = _saveService.importSave(content.trim());
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
                    '回合 ${save.turnCount} · ${_formatTime(save.saveTime)}',
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

  /// 格式化保存时间。
  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
          '${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}