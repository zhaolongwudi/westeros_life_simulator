/// Batch 3 测试：GameStateProvider。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/models/event.dart';
import 'package:westeros_life_simulator/models/player.dart';
import 'package:westeros_life_simulator/providers/game_state_provider.dart';

void main() {
  group('GameProgress', () {
    test('defaultProgress 创建默认进度', () {
      final progress = GameProgress.defaultProgress();
      expect(progress.year, 283);
      expect(progress.month, 3);
      expect(progress.season, 'spring');
      expect(progress.era, '征服纪元');
      expect(progress.turnCount, 0);
    });

    test('advanceMonth 推进月份', () {
      final progress = GameProgress.defaultProgress();
      final next = progress.advanceMonth();
      expect(next.month, 4);
      expect(next.turnCount, 1);
    });

    test('advanceMonth 跨年', () {
      final progress = GameProgress(
        year: 283,
        month: 12,
        season: 'winter',
        era: '征服纪元',
        turnCount: 10,
      );
      final next = progress.advanceMonth();
      expect(next.year, 284);
      expect(next.month, 1);
      expect(next.season, 'winter');
      expect(next.turnCount, 11);
    });

    test('季节计算正确', () {
      expect(GameProgress.seasonForMonth(3), 'spring');
      expect(GameProgress.seasonForMonth(6), 'summer');
      expect(GameProgress.seasonForMonth(9), 'autumn');
      expect(GameProgress.seasonForMonth(12), 'winter');
    });

    test('toJson/fromJson 序列化', () {
      final progress = GameProgress.defaultProgress();
      final json = progress.toJson();
      final restored = GameProgress.fromJson(json);
      expect(restored.year, progress.year);
      expect(restored.month, progress.month);
      expect(restored.season, progress.season);
      expect(restored.turnCount, progress.turnCount);
    });
  });

  group('GameStateProvider', () {
    test('默认状态', () {
      final provider = GameStateProvider();
      expect(provider.player.name, '无名者');
      expect(provider.progress.year, 283);
      expect(provider.isGameActive, false);
      expect(provider.isGameOver, false);
      expect(provider.currentEvent, isNull);
      expect(provider.history, isEmpty);
    });

    test('startNewGame 开始新游戏', () {
      final provider = GameStateProvider();
      provider.startNewGame();
      expect(provider.isGameActive, true);
      expect(provider.isGameOver, false);
    });

    test('startNewGame 自定义玩家', () {
      final player = Player.defaultPlayer().copyWith(name: '琼恩');
      final provider = GameStateProvider();
      provider.startNewGame(player: player);
      expect(provider.player.name, '琼恩');
    });

    test('advanceTime 推进时间', () {
      final provider = GameStateProvider();
      provider.startNewGame();
      final initialMonth = provider.progress.month;
      provider.advanceTime();
      expect(provider.progress.month, initialMonth + 1);
      expect(provider.progress.turnCount, 1);
    });

    test('advanceTime 游戏未开始不推进', () {
      final provider = GameStateProvider();
      final initialMonth = provider.progress.month;
      provider.advanceTime();
      expect(provider.progress.month, initialMonth);
    });

    test('setCurrentEvent 设置当前事件', () {
      final provider = GameStateProvider();
      final event = GameEvent.defaultEvent();
      provider.setCurrentEvent(event);
      expect(provider.currentEvent, event);
      provider.setCurrentEvent(null);
      expect(provider.currentEvent, isNull);
    });

    test('applyChoice 应用效果', () {
      final provider = GameStateProvider();
      provider.startNewGame();
      final event = GameEvent.defaultEvent();
      provider.setCurrentEvent(event);

      final choice = event.choices[0]; // 囤积粮食：gold-50, reputation+5
      final initialGold = provider.player.gold;
      final initialRep = provider.player.reputation;

      provider.applyChoice(choice);

      expect(provider.player.gold, initialGold - 50);
      expect(provider.player.reputation, initialRep + 5);
      expect(provider.currentEvent, isNull);
      expect(provider.history.length, 1);
    });

    test('applyChoice 技能效果', () {
      final provider = GameStateProvider();
      provider.startNewGame();
      final event = GameEvent(
        id: 'test_skill',
        name: '测试技能',
        type: EventType.daily,
        description: '测试',
        triggerConditions: const {},
        choices: const [
          EventChoice(
            id: 'c1',
            text: '训练',
            requirements: const {},
            effects: const {'skills.sword': 2},
            narrative: '你训练了剑术。',
          ),
        ],
        narrative: '测试事件',
        tags: const [],
        isOneTime: false,
      );
      provider.setCurrentEvent(event);

      final initialSkill = provider.player.skills['sword'] ?? 0;
      provider.applyChoice(event.choices[0]);
      expect(provider.player.skills['sword'], initialSkill + 2);
    });

    test('applyChoice 属性效果', () {
      final provider = GameStateProvider();
      provider.startNewGame();
      final event = GameEvent(
        id: 'test_attr',
        name: '测试属性',
        type: EventType.daily,
        description: '测试',
        triggerConditions: const {},
        choices: const [
          EventChoice(
            id: 'c1',
            text: '锻炼',
            requirements: const {},
            effects: const {'attributes.strength': 1},
            narrative: '你锻炼了力量。',
          ),
        ],
        narrative: '测试事件',
        tags: const [],
        isOneTime: false,
      );
      provider.setCurrentEvent(event);

      final initialAttr = provider.player.attributes['strength'] ?? 0;
      provider.applyChoice(event.choices[0]);
      expect(provider.player.attributes['strength'], initialAttr + 1);
    });

    test('updatePlayer 更新玩家', () {
      final provider = GameStateProvider();
      provider.startNewGame();
      final newPlayer = provider.player.copyWith(name: '新名字');
      provider.updatePlayer(newPlayer);
      expect(provider.player.name, '新名字');
    });

    test('toJson/fromJson 序列化', () {
      final provider = GameStateProvider();
      provider.startNewGame();
      final json = provider.toJson();
      final restored = GameStateProvider.fromJson(json);
      expect(restored.player.name, provider.player.name);
      expect(restored.progress.year, provider.progress.year);
      expect(restored.isGameActive, provider.isGameActive);
    });

    test('游戏结束检测', () {
      final provider = GameStateProvider();
      provider.startNewGame();
      // 设置玩家死亡
      final deadPlayer = provider.player.copyWith(
        flags: {'isAlive': false},
      );
      provider.updatePlayer(deadPlayer);
      // 应用一个空效果事件触发检查
      final event = GameEvent(
        id: 'test_dead',
        name: '测试',
        type: EventType.daily,
        description: '测试',
        triggerConditions: const {},
        choices: const [
          EventChoice(
            id: 'c1',
            text: '选项',
            requirements: const {},
            effects: const {},
            narrative: '叙事',
          ),
        ],
        narrative: '叙事',
        tags: const [],
        isOneTime: false,
      );
      provider.setCurrentEvent(event);
      provider.applyChoice(event.choices[0]);
      expect(provider.isGameOver, true);
      expect(provider.isGameActive, false);
    });
  });
}