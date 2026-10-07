/// Batch 10-60 测试：UI 重造（铁与火 · 羊皮纸与黄金主题）回归护栏。
///
/// 覆盖（全部为「只换视觉皮、文本逐字保留」契约验证）：
/// 1. 开局界面：7 区块标题 + 开始游戏按钮（batch6 契约）
/// 2. 主界面冒烟：AppBar 标题 + 输入框 hint + 导航 Tooltip（m5/m3b 契约）
/// 3. 各面板可构建（系统/NPC/家族树/设置——本批新金饰化界面）
/// 4. 主题基建：westerosTheme 可构建且主题色正确
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/screens/family_tree_screen.dart';
import 'package:westeros_life_simulator/screens/game_screen.dart';
import 'package:westeros_life_simulator/screens/npc_panel_screen.dart';
import 'package:westeros_life_simulator/screens/settings_screen.dart';
import 'package:westeros_life_simulator/screens/start_screen.dart';
import 'package:westeros_life_simulator/screens/systems_screen.dart';
import 'package:westeros_life_simulator/services/save_service.dart';
import 'package:westeros_life_simulator/theme/westeros_theme.dart';
import 'package:westeros_life_simulator/widgets/theme/ornate.dart';

void main() {
  group('Batch 10-60 开局界面（batch6 契约）', () {
    testWidgets('7 区块标题与开始按钮保留', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: westerosTheme(),
          home: const StartScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('开始新人生'), findsOneWidget);
      expect(find.text('姓名'), findsOneWidget);
      expect(find.text('身份'), findsOneWidget);
      expect(find.text('家族'), findsWidgets);
      expect(find.text('出生地'), findsOneWidget);
      expect(find.text('时代'), findsOneWidget);
      expect(find.text('出生季节'), findsOneWidget);
      expect(find.textContaining('开始游戏'), findsOneWidget);
      // 开篇饰头（新增文案只加不减）
      expect(find.text('维斯特洛人生模拟器'), findsOneWidget);
    });
  });

  group('Batch 10-60 主界面冒烟（m3b/m5 契约）', () {
    testWidgets('主界面可构建且核心元素保留', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final engine = GameEngine()..startNewGame();
      await tester.pumpWidget(
        MaterialApp(
          theme: westerosTheme(),
          home: GameScreen(engine: engine),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('维斯特洛人生模拟器'), findsOneWidget);
      // StatusBar 的 StatPill 是 compact 模式（不显示 label，只图标+数值）
      expect(find.text('AI 行动模式'), findsOneWidget);
      expect(find.textContaining('输入指令'), findsOneWidget);
      expect(find.byTooltip('导航'), findsOneWidget);
      expect(find.byTooltip('事件'), findsOneWidget);
      expect(find.byTooltip('信件'), findsOneWidget);
      // 初始叙事
      expect(find.textContaining('欢迎来到维斯特洛'), findsOneWidget);
    });
  });

  group('Batch 10-60 金饰面板构建（本批重造界面）', () {
    testWidgets('系统面板：标题 + 已接触系统计数', (tester) async {
      final engine = GameEngine()..startNewGame();
      await tester.pumpWidget(
        MaterialApp(
          theme: westerosTheme(),
          home: SystemsScreen(engine: engine),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('系统面板'), findsOneWidget);
      expect(find.textContaining('已接触系统'), findsOneWidget);
    });

    testWidgets('NPC 关系面板：在场/全部/进行中任务', (tester) async {
      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final engine = GameEngine()..startNewGame();
      await tester.pumpWidget(
        MaterialApp(
          theme: westerosTheme(),
          home: NpcPanelScreen(engine: engine),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('NPC 关系'), findsOneWidget);
      expect(find.textContaining('在场'), findsWidgets);
      expect(find.text('全部 NPC'), findsOneWidget);
      expect(find.text('进行中的任务'), findsOneWidget);
    });

    testWidgets('家族树面板：第一代空态', (tester) async {
      final engine = GameEngine()..startNewGame();
      await tester.pumpWidget(
        MaterialApp(
          theme: westerosTheme(),
          home: FamilyTreeScreen(engine: engine),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('家族树'), findsOneWidget);
      expect(find.textContaining('第 1 代'), findsOneWidget);
      expect(find.text('历代家主'), findsNothing);
      expect(find.text('当前世代'), findsOneWidget);
      expect(find.textContaining('家主：'), findsOneWidget);
      expect(find.text('子女：尚无子嗣'), findsOneWidget);
    });

    testWidgets('设置面板：标题 + 保存按钮 + 空存档态', (tester) async {
      // S12-7：设置页在**有引擎**时（游戏内进入）才显示存档按钮；
      // 无引擎（首页进入）不再隐式开局，故此处传引擎以覆盖「游戏内设置」路径。
      await tester.pumpWidget(
        MaterialApp(
          theme: westerosTheme(),
          home: SettingsScreen(
            engine: GameEngine()..startNewGame(),
            saveService: _MemorySaveService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('设置 / 存档'), findsOneWidget);
      expect(find.text('保存'), findsOneWidget);
      expect(find.text('暂无存档'), findsOneWidget);
      expect(find.text('AI 配置'), findsOneWidget);
    });
  });

  group('Batch 10-60 主题基建', () {
    test('westerosTheme 构建含铁与火色板', () {
      final theme = westerosTheme();
      expect(theme.colorScheme.primary, WesterosColors.gold);
      expect(theme.colorScheme.surface, WesterosColors.barkBase);
      expect(theme.textTheme.titleLarge?.fontFamily, 'serif');
    });

    testWidgets('公共装饰组件可渲染', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: westerosTheme(),
          home: Scaffold(
            body: ParchmentBackground(
              child: Column(
                children: <Widget>[
                  const OrnateHeader(icon: Icons.shield, title: '测试标题'),
                  const GildedCard(child: Text('卡片内容')),
                  const StatPill(icon: Icons.favorite, label: '生命', value: '87'),
                  const WesterosDivider(),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('测试标题'), findsOneWidget);
      expect(find.text('卡片内容'), findsOneWidget);
      expect(find.text('生命'), findsOneWidget);
      expect(find.text('87'), findsOneWidget);
    });
  });
}

/// 内存版存档服务（测试用，避免真实文件 IO）。
class _MemorySaveService extends SaveService {
  _MemorySaveService() : super(saveDir: '/tmp/nonexistent_batch10_60_test_dir');

  @override
  Future<List<SaveMetadata>> listSaves() async => <SaveMetadata>[];
}
