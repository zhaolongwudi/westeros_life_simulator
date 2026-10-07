/// Batch 6 测试：开局选择界面。
///
/// 覆盖：角色生成纯函数（buildSetupPlayer/buildSetupProgress）、
/// 标签函数、开局界面可构建。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/models/player.dart';
import 'package:westeros_life_simulator/screens/start_screen.dart';
import 'package:westeros_life_simulator/utils/labels.dart';

void main() {
  group('Batch 6 开局', () {
    test('buildSetupPlayer 生成商人角色', () {
      final setup = GameSetup(
        name: '测试商人',
        gender: 'male',
        identity: PlayerIdentity.merchant,
        familyId: 'family_lannister',
        locationId: 'location_lannisport',
        era: '篡夺者战争后',
        season: 'spring',
        year: 283,
        month: 3,
      );
      final player = buildSetupPlayer(setup);
      expect(player.name, '测试商人');
      expect(player.identity, PlayerIdentity.merchant);
      expect(player.familyId, 'family_lannister');
      expect(player.gold, 150); // 商人初始资金
      expect(player.skills['speech'], 4); // 商人口才加成
      expect(player.locationId, 'location_lannisport');
      expect(player.flags['isAlive'], true);
    });

    test('buildSetupPlayer 平民身份初始资金低', () {
      final setup = GameSetup(
        name: '贫农',
        gender: 'female',
        identity: PlayerIdentity.commoner,
        familyId: 'none',
        locationId: 'location_duskendale',
        era: '当前时代',
        season: 'winter',
        year: 298,
        month: 12,
      );
      final player = buildSetupPlayer(setup);
      expect(player.identity, PlayerIdentity.commoner);
      expect(player.gold, 40);
      expect(player.reputation, 30);
      expect(player.gender, 'female');
    });

    test('buildSetupProgress 时代/季节映射正确', () {
      final setup = GameSetup(
        name: '测试',
        gender: 'male',
        identity: PlayerIdentity.noble,
        familyId: 'family_stark',
        locationId: 'location_winterfell',
        era: '篡夺者战争期间',
        season: 'autumn',
        year: 282,
        month: 9,
      );
      final progress = buildSetupProgress(setup);
      expect(progress.year, 282);
      expect(progress.month, 9);
      expect(progress.season, 'autumn');
      expect(progress.era, '篡夺者战争期间');
      expect(progress.turnCount, 0);
    });

    test('身份/季节标签函数', () {
      expect(identityLabel(PlayerIdentity.maester), '学士');
      expect(identityLabel(PlayerIdentity.wildling), '野人');
      expect(seasonLabel('summer'), '夏天');
      // S4-2：`longwinter` 已从引擎清除，老存档残留值走 `_ =>` 兜底。
      expect(seasonLabel('longwinter'), 'longwinter');
    });

    test('kEras 时代年份映射', () {
      expect(kEras['篡夺者战争前']!.$1, 281);
      expect(kEras['篡夺者战争后']!.$1, 283);
      expect(kEras['当前时代']!.$1, 298);
    });

    testWidgets('开局界面可构建', (tester) async {
      // 调大测试视口，确保 ListView 全部内容一次性构建
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(home: StartScreen()),
      );
      expect(find.text('开始新人生'), findsOneWidget);
      expect(find.text('姓名'), findsOneWidget);
      expect(find.text('身份'), findsOneWidget);
      expect(find.text('家族'), findsOneWidget);
      expect(find.text('出生地'), findsOneWidget);
      expect(find.text('时代'), findsOneWidget);
      expect(find.text('出生季节'), findsOneWidget);
      expect(find.textContaining('开始游戏'), findsOneWidget);
    });
  });
}