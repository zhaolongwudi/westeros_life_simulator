/// M2 状态权威与身份正确性测试（Batch 10-27）。
///
/// 覆盖：
/// 1. 身份展示全部中文化（不再出现英文枚举名）
/// 2. 身份专属分支逐个命中（isIdentity 用枚举比较，已核实正确）
/// 3. history 环形上限 + droppedHistoryCount 摘要 + 存档往返
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/models/event.dart';
import 'package:westeros_life_simulator/models/marital.dart';
import 'package:westeros_life_simulator/models/player.dart';
import 'package:westeros_life_simulator/providers/game_state_provider.dart';
import 'package:westeros_life_simulator/utils/labels.dart';

/// 全部英文枚举名（任何面向玩家的文本都不应出现这些）。
const List<String> _englishIdentities = <String>[
  'noble',
  'commoner',
  'soldier',
  'merchant',
  'priest',
  'scholar',
  'adventurer',
  'assassin',
  'maester',
  'wildling',
];

/// 全部英文配偶身世名。
const List<String> _englishOrigins = <String>[
  'noble',
  'commoner',
  'merchant',
  'warrior',
];

/// 断言文本中不含任何英文枚举名。
void _expectNoEnglish(String label, String text) {
  for (final word in <String>[..._englishIdentities, ..._englishOrigins]) {
    expect(text.contains(word), isFalse,
        reason: '$label 不应出现英文枚举名 "$word"：\n$text');
  }
}

/// 造一个指定身份的玩家（可选指定地点）。
Player _playerWith(PlayerIdentity identity, {String locationId = 'location_winterfell'}) {
  return Player.defaultPlayer()
      .copyWith(identity: identity, locationId: locationId);
}

/// 从文本中取第一个整数（用于解析收益数字）。
int _firstInt(String text, String label) {
  final m = RegExp(r'$label (\d+)').firstMatch(text);
  if (m == null) {
    fail('未能从文本解析「$label N」：\n$text');
  }
  return int.parse(m.group(1)!);
}

void main() {
  group('M2 身份标签中文化', () {
    test('identityLabel 覆盖全部 10 个身份且无英文', () {
      for (final identity in PlayerIdentity.values) {
        final label = identityLabel(identity);
        expect(label, isNotEmpty);
        expect(label.contains(identity.name), isFalse,
            reason: '身份 ${identity.name} 的中文标签不应等于英文名');
      }
      expect(identityLabel(PlayerIdentity.merchant), '商人');
      expect(identityLabel(PlayerIdentity.maester), '学士');
    });

    test('spouseOriginLabel 覆盖全部 4 个身世', () {
      for (final origin in SpouseOrigin.values) {
        final label = spouseOriginLabel(origin);
        expect(label, isNotEmpty);
        expect(label.contains(origin.name), isFalse);
      }
      expect(spouseOriginLabel(SpouseOrigin.warrior), '战士');
    });

    test('formatPlayerPanel 展示中文身份', () {
      final engine = GameEngine()
        ..startNewGame(player: _playerWith(PlayerIdentity.merchant));
      final panel = engine.formatPlayerPanel();
      expect(panel.contains('商人'), isTrue);
      _expectNoEnglish('formatPlayerPanel', panel);
    });

    test('工作叙事展示中文身份', () {
      final engine = GameEngine()
        ..startNewGame(player: _playerWith(PlayerIdentity.maester));
      final text = engine.work();
      expect(text.contains('学士'), isTrue);
      _expectNoEnglish('work()', text);
    });

    test('家谱/家族树展示中文身份', () {
      final engine = GameEngine()
        ..startNewGame(player: _playerWith(PlayerIdentity.maester));
      _expectNoEnglish('家谱', engine.formatFamilyTree());
    });

    test('婚姻叙事与面板展示中文身世', () {
      final engine = GameEngine()
        ..startNewGame(player: _playerWith(PlayerIdentity.noble));
      // 直接注入已婚状态（避免依赖求婚流程的在场条件）
      engine.updatePlayer(engine.player.copyWith(
        spouse: const SpouseDetail(
          name: '珊莎',
          origin: SpouseOrigin.warrior,
          marriedYear: 283,
        ),
        flags: <String, bool>{...engine.player.flags, 'isMarried': true},
      ));
      final panel = engine.formatMarriagePanel();
      expect(panel.contains('战士'), isTrue);
      _expectNoEnglish('婚姻面板', panel);
      _expectNoEnglish('家族树', engine.formatFamilyTree());
    });

    test('头衔系统在满声望时文案不含英文身份名', () {
      final engine = GameEngine()
        ..startNewGame(player: _playerWith(PlayerIdentity.maester));
      // 拉满声望，进入「已达巅峰」分支
      engine.updatePlayer(engine.player.copyWith(reputation: 100));
      final text = engine.formatTitlePanel();
      _expectNoEnglish('头衔面板', text);
    });
  });

  group('M2 身份专属分支命中', () {
    test('isIdentity 对每个身份只命中自己', () {
      for (final identity in PlayerIdentity.values) {
        final engine = GameEngine()
          ..startNewGame(player: _playerWith(identity));
        expect(engine.isIdentity(identity), isTrue,
            reason: '${identity.name} 应命中自身');
        int hits = 0;
        for (final other in PlayerIdentity.values) {
          if (engine.isIdentity(other)) hits++;
        }
        expect(hits, 1, reason: '${identity.name} 只应命中 1 个身份');
      }
    });

    test('商人身份的贸易加成确实生效（分支真的在跑）', () {
      // 必须在城市/集市才能 trade（北境临冬城是城堡，会提前返回）
      final merchant = GameEngine()
        ..startNewGame(player: _playerWith(
          PlayerIdentity.merchant,
          locationId: 'location_kings_landing',
        ));
      final noble = GameEngine()
        ..startNewGame(player: _playerWith(
          PlayerIdentity.noble,
          locationId: 'location_kings_landing',
        ));
      // 同一回合序号、同一地点、同一 rng，商人收益应显著高于非商人
      final merchantText = merchant.trade();
      final nobleText = noble.trade();
      expect(merchantText.contains('净赚'), isTrue,
          reason: '商人应在君临做成一笔买卖：\n$merchantText');
      final m = _firstInt(merchantText, '净赚');
      final n = _firstInt(nobleText, '净赚');
      // 商人基础 25 + speech*3 + rnd(0..14)；贵族 8 + 同上 → 差值恒为 17
      expect(m - n, 17);
      expect(merchantText.contains('商人的眼光'), isTrue);
    });

    test('十个身份的工作收入各自可算出（switch 全覆盖）', () {
      for (final identity in PlayerIdentity.values) {
        final engine = GameEngine()
          ..startNewGame(player: _playerWith(identity));
        final text = engine.work();
        expect(RegExp(r'挣得 (\d+) 金币').hasMatch(text), isTrue,
            reason: '${identity.name} 工作应产出收入');
      }
    });
  });

  group('M2 history 环形上限', () {
    test('常量与默认状态正确', () {
      expect(GameStateProvider.kHistoryLimit, 200);
      final state = GameStateProvider()..startNewGame();
      expect(state.droppedHistoryCount, 0);
      expect(state.historySummaryLine(), isEmpty);
    });

    test('applyChoice 追加事件', () {
      final state = GameStateProvider()..startNewGame();
      final event = GameEvent.defaultEvent();
      state.setCurrentEvent(event);
      state.applyChoice(event.choices.first);
      expect(state.history.length, 1);
      expect(state.history.first.id, 'event_winter_comes');
    });

    test('超过上限后保留最新 kHistoryLimit 条并累加丢弃计数', () {
      final state = GameStateProvider()..startNewGame();
      final event = GameEvent.defaultEvent();
      final total = GameStateProvider.kHistoryLimit + 37;
      for (var i = 0; i < total; i++) {
        state.setCurrentEvent(event);
        state.applyChoice(event.choices.first);
      }
      expect(state.history.length, GameStateProvider.kHistoryLimit);
      expect(state.droppedHistoryCount, 37);
      final summary = state.historySummaryLine();
      expect(summary.contains('37'), isTrue);
      expect(summary.contains('归档'), isTrue);
    });

    test('丢弃的是最早的条目（保留最近）', () {
      final state = GameStateProvider()..startNewGame();
      // 造 kHistoryLimit + 5 条不同 id 的事件
      final extra = 5;
      for (var i = 0; i < GameStateProvider.kHistoryLimit + extra; i++) {
        final e = GameEvent.defaultEvent().copyWith(id: 'event_$i');
        state.setCurrentEvent(e);
        state.applyChoice(e.choices.first);
      }
      final ids = state.history.map((e) => e.id).toList();
      expect(ids.first, 'event_$extra');
      expect(ids.last, 'event_${GameStateProvider.kHistoryLimit + extra - 1}');
    });

    test('startNewGame 重置丢弃计数', () {
      final state = GameStateProvider()..startNewGame();
      final event = GameEvent.defaultEvent();
      for (var i = 0; i < GameStateProvider.kHistoryLimit + 3; i++) {
        state.setCurrentEvent(event);
        state.applyChoice(event.choices.first);
      }
      expect(state.droppedHistoryCount, greaterThan(0));
      state.startNewGame();
      expect(state.droppedHistoryCount, 0);
      expect(state.history, isEmpty);
      expect(state.historySummaryLine(), isEmpty);
    });

    test('toJson/fromJson 往返保留 droppedHistoryCount', () {
      final state = GameStateProvider()..startNewGame();
      final event = GameEvent.defaultEvent();
      for (var i = 0; i < GameStateProvider.kHistoryLimit + 9; i++) {
        state.setCurrentEvent(event);
        state.applyChoice(event.choices.first);
      }
      final json = state.toJson();
      expect(json['droppedHistoryCount'], 9);
      final restored = GameStateProvider.fromJson(json);
      expect(restored.droppedHistoryCount, 9);
      expect(restored.history.length, GameStateProvider.kHistoryLimit);
      expect(restored.progress.turnCount, state.progress.turnCount);
    });

    test('超长外部存档在 fromJson 时被截断并记账', () {
      final event = GameEvent.defaultEvent().toJson();
      final over = GameStateProvider.kHistoryLimit + 12;
      final state = GameStateProvider.fromJson(<String, dynamic>{
        'player': Player.defaultPlayer().toJson(),
        'progress': GameProgress.defaultProgress().toJson(),
        'history': List<Map<String, dynamic>>.filled(over, event),
        'currentEvent': null,
        'isGameActive': true,
        'isGameOver': false,
      });
      expect(state.history.length, GameStateProvider.kHistoryLimit);
      expect(state.droppedHistoryCount, 12);
    });

    test('旧存档（无 droppedHistoryCount 字段）加载正常', () {
      final state = GameStateProvider.fromJson(<String, dynamic>{
        'player': Player.defaultPlayer().toJson(),
        'progress': GameProgress.defaultProgress().toJson(),
        'history': <Map<String, dynamic>>[],
        'currentEvent': null,
        'isGameActive': true,
        'isGameOver': false,
      });
      expect(state.droppedHistoryCount, 0);
      expect(state.historySummaryLine(), isEmpty);
    });

    test('存档体积不再随回合数线性膨胀', () {
      final state = GameStateProvider()..startNewGame();
      final event = GameEvent.defaultEvent();
      for (var i = 0; i < GameStateProvider.kHistoryLimit * 2; i++) {
        state.setCurrentEvent(event);
        state.applyChoice(event.choices.first);
      }
      final json = state.toJson();
      // 上限 200 条，序列化后 history 长度不会超过上限
      expect((json['history'] as List<Object?>).length,
          GameStateProvider.kHistoryLimit);
      expect(state.droppedHistoryCount, GameStateProvider.kHistoryLimit);
    });
  });
}