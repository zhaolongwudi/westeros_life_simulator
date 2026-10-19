/// S16-8 测试：停滞检测——同一条事件不再连月复读。
///
/// 【背景】用户摘录的《剧情推进指令》§一-1：「连续 2 轮同构即停滞，必须推进」。
/// S15-6 立项时把它拆成两半：① 选项代价补齐（S16-5 已做）；② **停滞检测**。
///
/// 【本批做法】不新增任何存档字段：回看窗口取自**已有**的 `history`
/// （玩家已抉择过的事件会进 history），`StoryDirector.pickEvent` 对最近
/// `kRecentWindow` 回合出现过的事件降权 `kRepeatPenalty`（比相位满分还高）——
/// 于是**只要还有别的可用事件**，就不会再讲同一条；全库都刚讲过时仍能选出
/// 最高分的那条，不会把玩家卡在「无事件」。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:westeros_life_simulator/core/narrative_momentum.dart';
import 'package:westeros_life_simulator/core/story_director.dart';
import 'package:westeros_life_simulator/models/event.dart';
import 'package:westeros_life_simulator/models/player.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/providers/game_state_provider.dart';

/// 造一个只有 2 个选项、无门槛的探针事件。
GameEvent _event(String id, String name, EventType type) => GameEvent(
      id: id,
      name: name,
      type: type,
      description: '$name 的探针描述。',
      triggerConditions: const <String, String>{},
      choices: const <EventChoice>[
        EventChoice(
          id: 'choice_a',
          text: '选项甲',
          requirements: <String, int>{},
          effects: <String, int>{'reputation': 1},
          narrative: '选项甲的叙事。',
        ),
        EventChoice(
          id: 'choice_b',
          text: '选项乙',
          requirements: <String, int>{},
          effects: <String, int>{'gold': -1},
          narrative: '选项乙的叙事。',
        ),
      ],
      narrative: '$name 的叙事。',
      tags: const <String>['probe'],
      isOneTime: false,
    );

GameEngine _engine({
  required List<GameEvent> events,
  required List<GameEvent> history,
}) =>
    GameEngine(
      player: Player.defaultPlayer(),
      progress: GameProgress.defaultProgress(),
      history: history,
      isGameActive: true,
      events: events,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 剧情回路会读 AI 配置（SharedPreferences）：不打桩的话平台通道不返回，
  // 每个用例都要等 3 秒超时才落到本地导演。
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  final a = _event('event_aaa_daily', '探针甲', EventType.daily);
  final b = _event('event_bbb_family', '探针乙', EventType.family);

  group('S16-8 pickEvent 停滞检测', () {
    test('无重复时行为不变：同分按 id 排序 + 回合数取模', () {
      final picked = StoryDirector.pickEvent(
        <GameEvent>[b, a],
        NarrativePhase.introduce,
        0,
      );
      expect(picked!.id, 'event_aaa_daily', reason: '同分应稳定取 id 较小者');
      final next = StoryDirector.pickEvent(
        <GameEvent>[b, a],
        NarrativePhase.introduce,
        1,
      );
      expect(next!.id, 'event_bbb_family', reason: '回合数 +1 应换一个（既有取模行为）');
    });

    test('最近讲过的事件被降权：有替代就换一条', () {
      final picked = StoryDirector.pickEvent(
        <GameEvent>[a, b],
        NarrativePhase.introduce,
        0,
        recentEventIds: <String>['event_aaa_daily'],
      );
      expect(picked!.id, 'event_bbb_family',
          reason: '探针甲刚讲过，应换成探针乙（降权分高于相位满分）');
    });

    test('全都刚讲过时仍能选出（不会无事件可用）', () {
      final picked = StoryDirector.pickEvent(
        <GameEvent>[a, b],
        NarrativePhase.introduce,
        0,
        recentEventIds: <String>['event_aaa_daily', 'event_bbb_family'],
      );
      expect(picked, isNotNull);
    });

    test('回看窗口只取最近 kRecentWindow 条', () {
      final recent = <String>[
        'event_aaa_daily',
        'x1',
        'x2',
        'x3',
        'x4',
      ];
      // 窗口 4 ⇒ 探针甲已被挤出窗口，不该再被降权
      final win = recent.sublist(recent.length - StoryDirector.kRecentWindow);
      expect(win.contains('event_aaa_daily'), false);
      final picked = StoryDirector.pickEvent(
        <GameEvent>[a, b],
        NarrativePhase.introduce,
        0,
        recentEventIds: recent,
      );
      expect(picked!.id, 'event_aaa_daily',
          reason: '超出回看窗口的旧事件不再降权，同分取 id 较小者');
    });
  });

  group('S16-8 引擎回路：剧情不连月复读', () {
    test('history 里刚讲过的事件不会被再讲一次', () async {
      final engine = _engine(events: <GameEvent>[a, b], history: <GameEvent>[a]);
      final result = await engine.runStoryTurn();
      expect(result.isSuccess, true);
      expect(result.lines.single, contains('探针乙'));
      expect(result.lines.single, isNot(contains('探针甲')));
    });

    test('history 为空时按相位正常取材（探针甲）', () async {
      final engine = _engine(events: <GameEvent>[a, b], history: <GameEvent>[]);
      final result = await engine.runStoryTurn();
      expect(result.lines.single, contains('探针甲'));
    });

    test('回看窗口取自 history，不需要新增存档字段', () async {
      final engine = _engine(
        events: <GameEvent>[a, b],
        history: <GameEvent>[a, b, a, b, a],
      );
      final result = await engine.runStoryTurn();
      // 最近 4 条是 b,a,b,a ⇒ 两者都在窗口内 ⇒ 仍能选出一个（不死锁）
      expect(result.isSuccess, true);
      expect(result.choices.length, inInclusiveRange(2, 4));
    });
  });
}
