/// 游戏主界面：玩家状态面板 + 指令输入 + 叙事输出区 + 快捷指令。
///
/// 直接操作 [GameEngine]（Batch 4 混入层宿主），
/// 指令分发复用 GameCommandsMixin.resolveCommand。
///
/// Batch 10-29 · M3b：本文件 709 → ~250 行。
/// - 5 个展示 widget 搬到 `widgets/game/`（status/quick/ai_toggle/narrative/input）
/// - AI 行动编排搬到 `mixins/mixin_ai.dart` 的 `runAiAction`，
///   本文件只持 loading 态 + 渲染 `AiTurnResult`
/// 本文件只做「接线」：所有业务逻辑在引擎侧，所有展示在 widgets/ 侧。
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../core/command_registry.dart';
import '../game_engine.dart';
import '../models/ai_turn.dart';
import '../models/event.dart';
import '../services/save_service.dart';
import '../widgets/game/ai_toggle.dart';
import '../widgets/game/command_panel.dart';
import '../widgets/game/input.dart';
import '../widgets/game/narrative.dart';
import '../widgets/game/nav_grid.dart';
import '../widgets/game/quick.dart';
import '../widgets/game/responsive.dart';
import '../widgets/game/status.dart';
import '../widgets/theme/ornate.dart';
import 'events_screen.dart';
import 'family_screen.dart';
import 'family_tree_screen.dart';
import 'letters_screen.dart';
import 'map_screen.dart';
import 'npc_panel_screen.dart';
import 'player_panel_screen.dart';
import 'settings_screen.dart';
import 'systems_screen.dart';

/// 快捷指令（参考 mixin_commands 帮助）。
///
/// S12-9：横条只留 **6 个最高频**（用户拍板：状态/工作/狩猎/探索/休息/过月）。
/// 其余 41 条全部进「指令」面板（输入框左侧按钮 → `CommandPanel`），
/// 面板按分组列出 47 条并支持搜索；需参数的指令点击后预填输入框。
const List<QuickCommand> _quickCommands = <QuickCommand>[
  QuickCommand('状态', '状态'),
  QuickCommand('工作', '工作'),
  QuickCommand('狩猎', '狩猎'),
  QuickCommand('探索', '探索'),
  QuickCommand('休息', '休息'),
  QuickCommand('过月', '过月'),
];

/// 游戏主界面。
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, this.engine, this.saveService});

  /// 可选：传入已初始化的引擎（开局界面使用）；默认新建。
  final GameEngine? engine;

  /// 可选：注入存档服务（S12-7 自动存档用；测试可注入假实现）。
  final SaveService? saveService;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final GameEngine _engine = widget.engine ?? (GameEngine()..startNewGame());
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  /// 输入框焦点（S12-9：指令面板预填后自动聚焦，玩家可直接补参数）。
  final FocusNode _inputFocusNode = FocusNode();

  /// 叙事输出行（最新在底部）。
  final List<String> _lines = <String>[];

  /// 是否自由行动模式（true 时输入框的一整句话会作为本回合的行动意图）。
  bool _aiMode = false;

  /// 当前 AI 生成中的选项（供用户点选）。
  List<EventChoice> _aiChoices = <EventChoice>[];

  /// 剧情回合是否正在生成（S16 主线，含自由行动通道）。
  bool _aiLoading = false;

  /// 来源提示（未配置 Key / AI 降级）是否已经提示过，避免每回合刷同一句。
  bool _sourceNoteShown = false;

  // ============ S12-7 自动存档 ============
  //
  // 【为什么需要】此前**全项目零自动存档**：`saveGame` 的唯一调用方是设置页的
  // 「保存」按钮 ⇒ 玩到一半退出/崩溃 = 全部进度丢失，且玩家很可能根本不知道
  // 要去设置页点一下。这是「功能形同虚设」的典型。
  //
  // 【存档槽 id 用 player.id】`start_screen` 给新玩家分配
  // `player_<millisecondsSinceEpoch>`，且 `player.id` 经 `toJson`/`applyState`
  // 原样往返 ⇒ 同一局人生读档后仍是同一个 id ⇒ 自动存档**覆盖同一槽**，
  // 不会像手动保存那样每次新建一个槽（那正是 ② 号缺陷）。
  //
  // 【S13-6】这里原本是 `late final String _saveSlotId = _engine.player.id;`，
  // 即**在首帧算死一次**。但设置页与本界面**共用同一 engine**
  // （`SettingsScreen(engine: _engine)`），玩家在设置里载入另一个存档时，
  // `applyState` 会把 `_player` 整个换成那一档（连 `player.id` 一起换），
  // 而此处若仍用冻结值落盘，就会**把新档内容写进旧档文件** ⇒ 旧进度被覆盖丢失。
  // 「设置 → 新游戏」是同一条路径（`startNewGame()` 换成 `player_default`）。
  // 改为**每次落盘时读取当前 id**：不需要任何状态同步，也不会漏掉换档。
  String get _saveSlotId => _engine.player.id;
  // 【必须 late】非 late 的实例字段初始化器不能引用 `widget`（编译错误）。
  late final SaveService _saveService = widget.saveService ?? SaveService();
  Timer? _autoSaveTimer;

  @override
  void initState() {
    super.initState();
    // 监听引擎变化（状态条/叙事随游戏推进刷新）
    _engine.addListener(_onEngineChanged);
    // 初始叙事
    _appendLine('🏰 欢迎来到维斯特洛。');
    _appendLine(_engine.formatPlayerPanel());
    _appendLine('输入「帮助」查看可用指令，或点击下方快捷按钮。');
    // S16：进入即开场——剧情回合是主流程，不等玩家打字（见 _startStoryTurn）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_startStoryTurn());
    });
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    // S15-4：返回/退出时立即补一次落盘——去抖窗口内的最后一步操作
    // （指令、事件抉择、AI 行动）否则会丢，玩家重进发现「进度倒退」。
    // fire-and-forget：dispose 不能 await，存盘失败也不该阻断退出。
    _doAutoSave();
    _engine.removeListener(_onEngineChanged);
    _inputController.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 引擎变化 → 刷新界面；并安排一次去抖自动存档。
  void _onEngineChanged() {
    if (!mounted) return;
    setState(() {});
    _maybeAutoSave();
  }

  /// 任何状态变化都安排一次去抖自动存档（2 秒）。
  ///
  /// 【为什么挂在 notifyListeners 而不是逐条指令后】
  /// 月度推进、事件抉择、AI 抉择、系统结算……都会 notify，
  /// 挂在这里能覆盖**所有**改动路径，漏一条就丢一次进度。
  ///
  /// 【S15-4 为什么不再「只看跨月」】原实现只在年月变化时落盘，
  /// 于是同一个月内的指令成果（赚钱、练技能、接任务、写信）在退出后
  /// **全部丢失**，玩家感受就是「返回等于重新开始」。现在改为任何
  /// 变化都去抖落盘：连续操作只在**停手 2 秒后**存一次，IO 频率不变，
  /// 但退出前的那一步不再丢。
  void _maybeAutoSave() {
    if (!_engine.isGameActive) return;
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), _doAutoSave);
  }

  /// 真正落盘（失败静默：自动存档不该用弹窗打断玩家）。
  ///
  /// 【为什么不再判 `mounted`】dispose 路径要补存最后一笔，
  /// 那时 `mounted` 已 false——判它等于永远不存「退出前那一步」。
  Future<void> _doAutoSave() async {
    try {
      await _saveService.saveGame(_engine, saveId: _saveSlotId);
    } on Object {
      // 存档失败（如磁盘满/权限）不阻断游戏；手动保存仍可走设置页。
    }
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

  /// 提交输入：指令模式走指令表，自由行动模式走剧情回合。
  void _submitCommand(String raw) {
    final input = raw.trim();
    if (input.isEmpty) return;
    _inputController.clear();

    if (_aiMode) {
      // S16-3：自由行动也走剧情回路——**没有 API Key 也能用**（由本地导演
      // 接手叙事）。此前这里直连 `runAiAction`，未配置 Key 时只回一句
      // 「请先配置」，玩家写了半天的话被吞掉。
      _appendLine('✨ 行动：$input');
      unawaited(_startStoryTurn(intent: input));
      return;
    }

    final result = _engine.resolveCommand(input);
    _appendLine('> $input');
    _appendLine(result.text);
    // S2-1（P1-04）：consumedTurn 契约在此消费——消耗回合的指令推进一个月。
    // 「过月」handler 已自推进（needsTimeAdvance=false），不会双推进。
    if (result.needsTimeAdvance) {
      _appendLine(_engine.advanceMonth());
    }
    // S16：指令推进的月份若浮现了待决事件，交给剧情回合呈现（剧情回路是
    // 事件的唯一呈现通道），免得玩家只看到一行传闻却点不到选项。
    if (_engine.pendingEvent != null) {
      unawaited(_startStoryTurn());
    }
  }

  /// 开一个剧情回合（S16 主线）：主 AI 说书，不可用时本地导演接手。
  ///
  /// 【为什么不等玩家打字】用户要的是「以主 AI 反馈剧情和选项为主」——
  /// 每回合由引擎主动开局并给出可点选项；输入框是辅助的自由行动通道。
  Future<void> _startStoryTurn({String? intent}) async {
    if (_aiLoading || !mounted) return;
    const placeholder = '（剧情推进中…）';
    setState(() {
      _aiLoading = true;
      _aiChoices = <EventChoice>[];
    });
    _appendLine(placeholder);
    final AiTurnResult result = await _engine.runStoryTurn(intent: intent);
    if (!mounted) return;
    _aiLoading = false;
    _lines.removeWhere((l) => l == placeholder);
    // 来源提示只提示一次：主 AI 恢复后再次降级时重新提示。
    if (result.note.isNotEmpty && !_sourceNoteShown) {
      _sourceNoteShown = true;
      _appendLine(result.note);
    }
    if (!result.isLocal && result.isSuccess) {
      _sourceNoteShown = false;
    }
    for (final line in result.lines) {
      _appendLine(line);
    }
    setState(() {
      _aiChoices = result.choices;
    });
  }

  /// 应用剧情回合的选项：效果落盘 + 推进一个月（含系统结算/信件），
  /// 随后自动开下一个剧情回合——这一步是「剧情回路」的闭环（S16）。
  void _chooseAiOption(EventChoice choice) {
    setState(() {
      _aiChoices = <EventChoice>[];
    });
    _appendLine('➡️ ${choice.text}');
    // 引擎级应用：效果写回玩家 + 月度推进 + 系统结算 + 信件触发
    final result = _engine.applyStoryChoice(choice);
    if (result.isNotEmpty) {
      _appendLine(result);
    }
    // 引擎 notify 会触发 _onEngineChanged 刷新状态条
    unawaited(_startStoryTurn());
  }

  /// 抉择待决的世界事件选项（S4-5）：效果落盘 + 追加结算叙事。
  ///
  /// 【为什么不推进时间】该事件在 `advanceMonth()` 内部浮现，时钟已推进过；
  /// 引擎侧走 `applyChoice(advanceClock: false)` 抑制重复推进。
  void _chooseWorldEvent(EventChoice choice) {
    final text = _engine.chooseWorldEventChoice(choice);
    _appendLine('➡️ ${choice.text}');
    if (text.isNotEmpty) {
      _appendLine(text);
    }
  }

  /// 打开子界面。
  void _openScreen(Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  /// 打开「指令」面板（S12-9）：47 条命令按分组列出 + 搜索。
  ///
  /// 零参数指令点一下即执行；有候选的展开按钮；其余预填输入框。
  void _openCommandPanel() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => CommandPanel(
        specs: _engine.commandRegistry.orderedSpecs,
        onRun: (spec) {
          Navigator.of(sheetContext).pop();
          _submitCommand(spec.aliases.first);
        },
        onPrefill: (spec) {
          Navigator.of(sheetContext).pop();
          _prefillCommand(spec);
        },
        // S15-4：点选候选参数后直接执行，不再让玩家手打名字/物品/技能。
        onRunWithArg: (spec, value) {
          Navigator.of(sheetContext).pop();
          _runCommandWithArg(spec, value);
        },
      ),
    );
  }

  /// 把「主名 + 空格」填进输入框并聚焦，由玩家补参数后发送。
  ///
  /// 【为什么不直接执行】需参数的指令直接执行只会返回缺参提示，
  /// 玩家还得自己重打一遍命令——预填把这一步省掉。
  void _prefillCommand(CommandSpec spec) {
    final text = '${spec.aliases.first} ';
    _inputController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _inputFocusNode.requestFocus();
  }

  /// 候选参数被选中：拼成完整指令直接执行（S15-4）。
  ///
  /// 【为什么不预填】玩家已经点选过参数了，再让他按一次发送是多余步骤；
  /// 面板里点「互动 ▾ → 提利昂」就应当立刻发生互动。
  void _runCommandWithArg(CommandSpec spec, String value) {
    _submitCommand('${spec.aliases.first} $value');
  }

  /// 打开导航宫格（AppBar 单入口 → 全部面板）。
  void _openNavGrid() {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => NavGrid(
        entries: <NavGridEntry>[
          NavGridEntry(
            icon: Icons.person_outline,
            label: '玩家详情',
            color: theme.colorScheme.primary,
            onTap: () => _openPanelFromSheet(sheetContext, PlayerPanelScreen(engine: _engine)),
          ),
          NavGridEntry(
            icon: Icons.family_restroom,
            label: '家族面板',
            color: theme.colorScheme.tertiary,
            onTap: () => _openPanelFromSheet(sheetContext, FamilyScreen(engine: _engine)),
          ),
          NavGridEntry(
            icon: Icons.account_tree_outlined,
            label: '家族树',
            color: theme.colorScheme.tertiary,
            onTap: () => _openPanelFromSheet(sheetContext, FamilyTreeScreen(engine: _engine)),
          ),
          NavGridEntry(
            icon: Icons.people_alt_outlined,
            label: 'NPC 关系',
            color: theme.colorScheme.tertiary,
            onTap: () => _openPanelFromSheet(sheetContext, NpcPanelScreen(engine: _engine)),
          ),
          NavGridEntry(
            icon: Icons.event_note_outlined,
            label: '事件',
            color: theme.colorScheme.primary,
            onTap: () => _openPanelFromSheet(sheetContext, EventsScreen(engine: _engine)),
          ),
          NavGridEntry(
            icon: Icons.mail_outlined,
            label: '信件',
            color: theme.colorScheme.primary,
            onTap: () => _openPanelFromSheet(sheetContext, LettersScreen(engine: _engine)),
          ),
          NavGridEntry(
            icon: Icons.grid_view_outlined,
            label: '系统面板',
            color: theme.colorScheme.secondary,
            onTap: () => _openPanelFromSheet(sheetContext, SystemsScreen(engine: _engine)),
          ),
          NavGridEntry(
            icon: Icons.map_outlined,
            label: '地图',
            color: theme.colorScheme.primary,
            onTap: () => _openPanelFromSheet(sheetContext, MapScreen(engine: _engine)),
          ),
          NavGridEntry(
            icon: Icons.settings_outlined,
            label: '设置/存档',
            color: theme.colorScheme.secondary,
            onTap: () => _openPanelFromSheet(sheetContext, SettingsScreen(engine: _engine)),
          ),
        ],
      ),
    );
  }

  /// 关闭宫格弹层后打开目标界面。
  void _openPanelFromSheet(BuildContext sheetContext, Widget screen) {
    Navigator.of(sheetContext).pop();
    _openScreen(screen);
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
            icon: const Icon(Icons.grid_view_outlined),
            tooltip: '导航',
            onPressed: _openNavGrid,
          ),
        ],
      ),
      body: SafeArea(
        child: ParchmentBackground(
          child: AdaptiveFrame(
            maxWidth: 700,
            child: Column(
              children: <Widget>[
                // 玩家状态摘要条
                StatusBar(engine: _engine),
                // 快捷指令
                QuickCommandBar(
                  commands: _quickCommands,
                  onTap: _submitCommand,
                ),
                // AI 模式开关
                AiModeToggle(
                  aiMode: _aiMode,
                  aiLoading: _aiLoading,
                  onToggle: (v) => setState(() {
                    _aiMode = v;
                    _aiChoices = <EventChoice>[];
                  }),
                ),
                // 叙事输出区
                Expanded(
                  child: NarrativeView(
                    lines: _lines,
                    scrollController: _scrollController,
                    engine: _engine,
                    onOpenPanel: _openScreen,
                    aiChoices: _aiChoices,
                    onChooseAi: _chooseAiOption,
                    worldEvent: _engine.pendingEvent,
                    onChooseWorldEvent: _chooseWorldEvent,
                  ),
                ),
                // 指令输入区
                CommandInputBar(
                  controller: _inputController,
                  focusNode: _inputFocusNode,
                  onSubmitted: _submitCommand,
                  onOpenCommands: _openCommandPanel,
                  // S15-3：双向引导（用户反馈「提示都是输入指令」）——
                  // 普通模式指向左侧「指令」面板；自由行动模式指向自然语言描述。
                  // S16-3：自由行动不再要求配置 Key（本地导演会接手）。
                  hintText: _aiMode
                      ? '自由行动：用一句话描述你要做的事…'
                      : '输入指令，或点左侧「指令」浏览全部 47 条面板',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}