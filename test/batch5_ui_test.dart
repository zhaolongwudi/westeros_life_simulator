/// Batch 5 测试：UI 层。
///
/// 覆盖：GameEngine 状态恢复（applyState）、
/// 各界面可构建（玩家详情/家族/地图/系统/设置）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/providers/game_state_provider.dart';
import 'package:westeros_life_simulator/screens/family_screen.dart';
import 'package:westeros_life_simulator/screens/map_screen.dart';
import 'package:westeros_life_simulator/screens/player_panel_screen.dart';
import 'package:westeros_life_simulator/screens/settings_screen.dart';
import 'package:westeros_life_simulator/screens/systems_screen.dart';
import 'package:westeros_life_simulator/services/save_service.dart';

void main() {
  group('Batch 5 UI', () {
    test('applyState 恢复玩家状态', () {
      final engine = GameEngine()..startNewGame();
      engine.gainGold(50);
      final beforeGold = engine.player.gold;

      final state = GameStateProvider.fromJson(engine.toJson());
      engine.applyState(state);
      expect(engine.player.gold, beforeGold);
      expect(engine.isGameActive, true);
    });

    testWidgets('玩家详情面板可构建', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: PlayerPanelScreen()),
      );
      expect(find.text('玩家详情'), findsOneWidget);
      expect(find.text('无名者'), findsWidgets);
      expect(find.text('金币'), findsOneWidget);
    });

    testWidgets('家族面板可构建并展示家族', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: FamilyScreen()),
      );
      expect(find.text('家族'), findsWidgets);
      expect(find.textContaining('维斯特洛家族'), findsOneWidget);
    });

    testWidgets('地图面板可构建并展示地点', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: MapScreen()),
      );
      expect(find.text('地图'), findsOneWidget);
      // 玩家出生地在临冬城，应至少显示一个地点
      expect(find.textContaining('危险度'), findsWidgets);
    });

    testWidgets('系统面板可构建', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: SystemsScreen()),
      );
      expect(find.text('系统面板'), findsOneWidget);
      expect(find.textContaining('已接触系统'), findsOneWidget);
    });

    testWidgets('设置面板可构建', (tester) async {
      // S12-7：设置页在**有引擎**时（游戏内进入）才显示存档按钮。
      await tester.pumpWidget(
        MaterialApp(
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
    });
  });
}

/// 内存版存档服务（测试用，避免真实文件 IO）。
class _MemorySaveService extends SaveService {
  _MemorySaveService() : super(saveDir: '/tmp/nonexistent_batch5_test_dir');

  @override
  Future<List<SaveMetadata>> listSaves() async => <SaveMetadata>[];
}