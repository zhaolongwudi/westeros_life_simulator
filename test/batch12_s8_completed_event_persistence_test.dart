/// S8-1 测试：一次性事件的完成集合进存档（第 0 节 L1 / S4-6 遗留①）。
///
/// 【本批修的是什么】
/// `EventProvider._completedEventIds` 是 `isOneTime` 门禁的唯一依据
/// （`canTrigger` 靠它拦截），但它原先**只活在内存里**——`GameProgress.toJson` /
/// `GameStateProvider.toJson` 都没有这个字段。两个症状同一根因（完成集合不属于状态层）：
///   1. **读档后 3 个一次性事件重新可触发** ⇒ S4-6（P1-11）的修复在读档路径上失效；
///   2. **开新局后上一局已完成的一次性事件在新局里永不出现**——`settings_screen._newGame()`
///      在**同一引擎实例**上调 `startNewGame()`，而 `EventProvider.reset()` 全库零调用点。
///
/// 【修法与归属】完成集合的字段落在 `GameStateProvider`，但**运行时的唯一持有者仍是
/// `EventProvider`**；状态层只在**存档的两个边界**（写入 `toJson` / 读取 `applyState`）
/// 做镜像，避免出现两份「都像真的」活状态而互相漂移。
///
/// 【为什么全是确定性断言】本项目已两次因「跑 N 回合应该能等到」翻车（S4-6：零命中概率
/// 3.5%，CI 恰好踩中）。本文件**完全不经 RNG**——完成集合的写入直接调生产入口
/// `eventProvider.markCompleted`，读档走**真实链路** `saveGame → loadGame → applyState`。
///
/// 覆盖（对应卡片 5 条验收标准）：
/// 1. 存档往返后已完成的一次性事件**不再**可触发（真实 saveGame→loadGame→applyState 链路）
/// 2. 引擎 `toJson` 含该键；裸 `GameStateProvider` 序列化/反序列化无损
/// 3. 旧存档（缺键）与错误类型（`"abc"` / `[1,null]`）均不抛且回落合理
/// 4. `startNewGame()` 后一次性事件**恢复可触发**（取证④的新局残留）
/// 5. 另有两条反向锁：完成集合**只由 `eventProvider` 说了算**（防状态层成为第二份活状态）、
///    以及「读档是整体替换不是合并」
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/core/event_trigger_eval.dart';
import 'package:westeros_life_simulator/data/event_data.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/models/event.dart';
import 'package:westeros_life_simulator/models/player.dart';
import 'package:westeros_life_simulator/providers/event_provider.dart';
import 'package:westeros_life_simulator/providers/game_state_provider.dart';
import 'package:westeros_life_simulator/services/save_service.dart';

/// 一次性事件里门槛最简单的一条（`minReputation: 30`），四季皆可触发。
const _oneTimeId = 'event_sword_inheritance';

/// 满足 `minReputation: 30` 的玩家。
///
/// 【为什么要显式设 reputation】断言「不可触发」时必须先保证**门槛已满足**——
/// 否则 `canTrigger` 返回 false 的原因可能是门槛没过，而不是完成门禁生效，
/// 断言就成了假绿。
Player _richPlayer() => Player.defaultPlayer().copyWith(
      gold: 500,
      reputation: 80,
      age: 30,
      hunger: 60,
      health: 80,
      energy: 80,
    );

/// 只含那一条一次性事件的受控池（沿用 S4-6 已验证的注入手法）。
List<GameEvent> get _soloOneTimePool => [eventById(_oneTimeId)!];

/// 已完成 `_oneTimeId` 的引擎——写入走**生产入口** `markCompleted`
/// （`_maybeWorldEvent` 浮现时调的正是它），不经 RNG、不经待决事件渲染。
GameEngine _engineWithOneTimeCompleted() {
  final engine = GameEngine(events: _soloOneTimePool)..startNewGame();
  engine.updatePlayer(_richPlayer());
  engine.eventProvider.markCompleted(_oneTimeId);
  return engine;
}

void main() {
  late Directory tempDir;
  late SaveService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('batch12_s8_');
    service = SaveService(saveDir: tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('S8-1 验收1：真实读档链路后一次性事件不再可触发', () {
    test('saveGame → loadGame → applyState 后 canTrigger 为 false', () async {
      final engine = _engineWithOneTimeCompleted();
      // 前提：写入侧确实标记了，且标记前可触发
      expect(engine.eventProvider.completedEventIds, contains(_oneTimeId));
      expect(
        eventTriggersSatisfied(eventById(_oneTimeId)!, engine.player,
            season: 'spring'),
        isTrue,
        reason: '前提：门槛（minReputation 30 ≤ 80）应满足——'
            '否则本用例后面的 canTrigger=false 可能来自门槛而非完成门禁（假绿）',
      );

      // 真实链路：落盘 → 读盘 → 灌回**另一个**引擎实例
      // （`settings_screen._loadSave` 与 `home_screen` 走的都是 applyState，
      //  而 `SaveService.loadGame` 返回的是**裸 GameStateProvider** 不是引擎。）
      final saveId = await service.saveGame(engine, saveId: 'onetime');
      final loaded = await service.loadGame(saveId);
      expect(loaded, isNotNull);
      expect(loaded!.completedEventIds, contains(_oneTimeId),
          reason: '裸 GameStateProvider 应已从 JSON 读回完成集合');

      final revived = GameEngine(events: _soloOneTimePool)..applyState(loaded);
      expect(revived.eventProvider.completedEventIds, contains(_oneTimeId),
          reason: 'applyState 未把完成集合推回 eventProvider');
      expect(
        revived.eventProvider
            .canTrigger(eventById(_oneTimeId)!, revived.player, season: 'spring'),
        isFalse,
        reason: '读档后一次性事件重新可触发 ⇒ P1-11 的修复在读档路径上失效（L1 未修）',
      );
      // 池中也必须消失（不止 canTrigger）
      expect(
        revived.eventProvider
            .getAvailableEvents(revived.player, season: 'spring')
            .where((e) => e.id == _oneTimeId),
        isEmpty,
        reason: '已读档完成的一次性事件仍留在可触发池中',
      );
    });

    test('exportSave / importSave 链路同样保留（导出/导入不是例外路径）', () {
      final engine = _engineWithOneTimeCompleted();
      final imported = service.importSave(service.exportSave(engine));
      expect(imported, isNotNull);
      expect(imported!.completedEventIds, contains(_oneTimeId),
          reason: '导出再导入后完成集合丢失 ⇒ 玩家会重看一次性事件');
    });
  });

  group('S8-1 验收2：字段序列化契约', () {
    test('引擎 toJson 含 completedEventIds，且值取自 eventProvider', () {
      final engine = _engineWithOneTimeCompleted();
      final json = engine.toJson();
      expect(json.containsKey('completedEventIds'), isTrue);
      expect(json['completedEventIds'], contains(_oneTimeId));
    });

    test('toJson 不产生副作用：连续两次调用结果一致且集合不变', () {
      // 【为什么要这条】`GameProviderBase.toJson` 用 `..[]` **覆盖**该键而非回写
      // 状态字段——序列化是读取动作，不该有副作用。若日后有人改成「顺手回写状态」，
      // 这条会红。
      final engine = _engineWithOneTimeCompleted();
      final first = engine.toJson();
      final second = engine.toJson();
      expect(second['completedEventIds'], first['completedEventIds']);
      expect(engine.eventProvider.completedEventIds, [_oneTimeId]);
    });

    test('裸 GameStateProvider 序列化/反序列化该字段无损', () {
      final state = GameStateProvider(completedEventIds: const ['event_a', 'event_b']);
      final restored = GameStateProvider.fromJson(state.toJson());
      expect(restored.completedEventIds, ['event_a', 'event_b']);
    });

    test('applyState 拷贝而非共享列表（改动互不影响）', () {
      // 与 `_history` 同款契约：`applyState` 之后改来源 state 不应影响目标。
      final source = GameStateProvider(completedEventIds: const ['event_a']);
      final target = GameStateProvider()..applyState(source);
      expect(target.completedEventIds, ['event_a']);
      final revived = GameEngine()..applyState(source);
      expect(revived.eventProvider.completedEventIds, ['event_a']);
    });
  });

  group('S8-1 验收3：旧存档与坏数据一律不抛', () {
    test('旧存档缺 completedEventIds 键 → 回落空列表', () {
      final json = _engineWithOneTimeCompleted().toJson()..remove('completedEventIds');
      final restored = GameStateProvider.fromJson(json);
      expect(restored.completedEventIds, isEmpty);
      expect(restored.isGameActive, isTrue, reason: '其余字段不应受影响');
    });

    test('类型错误（字符串而非列表）→ 回落空列表，不抛', () {
      final json = _engineWithOneTimeCompleted().toJson()
        ..['completedEventIds'] = 'event_sword_inheritance';
      final restored = GameStateProvider.fromJson(json);
      expect(restored.completedEventIds, isEmpty);
    });

    test('列表内含非字符串项 → 逐个跳过，字符串项保留', () {
      final json = _engineWithOneTimeCompleted().toJson()
        ..['completedEventIds'] = <Object?>[1, null, _oneTimeId, <String>[], true];
      final restored = GameStateProvider.fromJson(json);
      expect(restored.completedEventIds, [_oneTimeId]);
    });

    test('值为 null → 回落空列表，不抛', () {
      final json = _engineWithOneTimeCompleted().toJson()
        ..['completedEventIds'] = null;
      final restored = GameStateProvider.fromJson(json);
      expect(restored.completedEventIds, isEmpty);
    });
  });

  group('S8-1 验收4：startNewGame 必须重置（取证④的新局残留）', () {
    test('新局后一次性事件恢复可触发，且不在任何存档残留里', () {
      final engine = _engineWithOneTimeCompleted();
      expect(
        engine.eventProvider
            .canTrigger(eventById(_oneTimeId)!, engine.player, season: 'spring'),
        isFalse,
        reason: '前提：本局已完成，应不可触发',
      );

      engine.startNewGame();

      expect(engine.eventProvider.completedEventIds, isEmpty,
          reason: 'EventProvider.reset() 未被调用 ⇒ 新局里上一局完成的事件永不出现');
      expect(engine.completedEventIds, isEmpty, reason: '状态层同样应被清空');
      engine.updatePlayer(_richPlayer());
      expect(
        engine.eventProvider
            .canTrigger(eventById(_oneTimeId)!, engine.player, season: 'spring'),
        isTrue,
        reason: '新局后一次性事件应恢复可触发',
      );
      expect(engine.toJson()['completedEventIds'], isEmpty);
    });

    test('同一引擎实例连续开新局：状态层与 eventProvider 不残留上上局', () {
      // `settings_screen` 复用同一引擎实例（`_newGame` 就地 `startNewGame`），
      // 故这一条才是生产路径。
      final engine = _engineWithOneTimeCompleted();
      engine.startNewGame();
      engine.eventProvider.markCompleted(_oneTimeId);
      engine.startNewGame();
      expect(engine.eventProvider.completedEventIds, isEmpty);
      expect(engine.completedEventIds, isEmpty);
      expect(engine.toJson()['completedEventIds'], isEmpty);
    });
  });

  group('S8-1 防漂移：运行时的唯一持有者是 EventProvider', () {
    test('引擎的存档值以 eventProvider 为准，不取状态层字段', () {
      // 【为什么锁这条】状态层也有一份 `_completedEventIds`（读档时被填）。
      // 若有人日后误把 `toJson` 写成读状态层字段，一旦某条路径只更新了 eventProvider
      // （如 `markCompleted`），存档就会静默丢失完成记录 —— 即本批要修的病症复发。
      final engine = _engineWithOneTimeCompleted();
      engine.eventProvider.restoreCompleted(const [_oneTimeId, 'event_extra']);
      expect(engine.toJson()['completedEventIds'], [_oneTimeId, 'event_extra'],
          reason: '存档值必须跟随 eventProvider（运行时的唯一持有者）');
    });

    test('状态层被单独改动时，以 applyState 的同步为准（存档边界单向）', () {
      final engine = _engineWithOneTimeCompleted();
      // 绕过 eventProvider 只改状态层 —— 不应泄漏进存档（那里不是真相源）。
      final tampered = GameStateProvider.fromJson(engine.toJson())
        ..applyState(GameStateProvider(completedEventIds: const ['event_ghost']));
      expect(tampered.completedEventIds, ['event_ghost']);
      // 但一旦走 applyState 边界（真实读档路径），它就会被推给 eventProvider。
      final engine2 = GameEngine(events: _soloOneTimePool)..applyState(tampered);
      expect(engine2.eventProvider.completedEventIds, ['event_ghost'],
          reason: '读档边界是整体替换：来源说什么就是什么');
    });

    test('restoreCompleted 是整体替换而非合并（读档是全量覆盖语义）', () {
      // 合并会让「读档失败」退化成「读到一半」——卡片设计取舍第 4 条。
      final provider = EventProvider(events: allEvents)
        ..markCompleted('event_stale')
        ..restoreCompleted(const ['event_fresh']);
      expect(provider.completedEventIds, ['event_fresh']);
    });

    test('restoreCompleted 拷贝入参列表（不留外部可变引用）', () {
      final src = <String>['event_a'];
      final provider = EventProvider(events: allEvents)..restoreCompleted(src);
      src.add('event_b');
      expect(provider.completedEventIds, ['event_a'],
          reason: '外部改动不得渗入完成集合');
    });
  });

  group('S8-1 数据侧前提（防止测试悄悄失效）', () {
    test('受控池事件确为一次性且门槛可满足', () {
      final e = eventById(_oneTimeId)!;
      expect(e.isOneTime, isTrue);
      expect(_richPlayer().reputation,
          greaterThanOrEqualTo(30), reason: '门槛 minReputation 30 需被满足');
    });

    test('仍恰好 3 个 isOneTime=true 事件（完成集合的取值空间）', () {
      expect(allEvents.where((e) => e.isOneTime).length, 3);
    });
  });
}
