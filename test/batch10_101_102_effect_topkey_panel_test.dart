/// Batch 10-101/102 测试：未识别顶层效果键拒收可见化 + 玩家面板 flags/背包中文名。
///
/// 【10-101 取证：五类前缀键全部设防后，漏掉的是「顶层键」这一类】
/// 效果落盘轴（10-89~99）给 `inventory.`/`skills.`/`attributes.`/
/// `relations.`/`flags.` 五类前缀键都补了写侧守卫，`applyEffects`
/// 两条通道的 `if/else` 链**穷举完毕**。但取证（一次性脚本，按花括号
/// 配平切出每个 `effects:` map 后逐键比对）发现两个缺口：
///
///  **缺口 A：`age` 键双通道漂移**——`event_service.applyEffects`
///  有 `case 'age'`，`GameStateProvider.applyEffects`（AI 通道）
///  **完全没有**。AI 选项写 `age: 5` 此前是静默丢弃，叙事里写着
///  「你又老了一岁」而状态纹丝不动。与 10-90 修好感度 ±100 钳制、
///  10-95 修 `max(0, ...)` 完全同型（两处实现不一致）。
///  附带发现：事件通道的 `age` 是**裸加法无下界**，`age: -99999`
///  会让年龄变负数，`isElder`（`age >= 55`）与 `minAge`/`maxAge`
///  门槛、`玩家面板「N 岁」`展示全部失真。
///
///  **缺口 B：未识别顶层键静默丢弃**——`if/else` 链走完所有分支后
///  **没有 else 兜底**，任何未知键直接被丢弃、玩家零反馈。取证发现
///  `event_data` 自带 **10 个纯幽灵顶层效果键**（`political`/
///  `military`/`faith`/`magic`/`familyRelation`/`food`/`happiness`/
///  `knowledge`/`north`/`allyRelation`，共 78 处、覆盖 60+ 事件），
///  两条 `applyEffects` 都不认识它们 → 玩家点了「支持合法继承人」
///  只拿到 `reputation`，叙事承诺的政治资本变化**静默丢失**。
///
/// 【为什么是「拒收可见化」而不是删除键或接线——取证否决了两个替代方案】
/// ① **删除**：会让 **9 个选项变成零效果死选项**（`choice_rest` 休息、
///    `choice_walk_away` 转身离开、`choice_just_look` 只看不买……），
///    而「转身离开本就没有收益」是**有意设计**；还会让 **4 个事件
///    选项组同质化**（`event_family_intrigue`/`event_church_split`
///    三选项坍缩成 rep +5/+5/-5）。删除破坏玩法。
/// ② **接线到 Player 字段**：`Player` 只有 6 个 attributes
///    （strength/agility/intelligence/charisma/willpower/perception）
///    与 5 个 skills，没有政治/军事/信仰维度；写到 `Family.army` 上
///    则会污染静态内容数据（`kFamilies` 是常量、运行时无人写）。
///    接线属**新增玩法维度**，超出契约修复范围。
///  故本批只做契约闭合：**落盘行为不变（仍不生效），但从「不可见」
///  变为「可见」**——复用 10-94 已建成的 `lastRejectedEffectKeys`
///  通道，与五类前缀键守卫完全同构。
///
/// 【10-102 取证：玩家面板还有两处泄漏英文键】
/// 10-100 把关系区改成了中文名，但同屏的「状态标记」区此前直接
/// `_Entry(e.key, ...)`（显示 `isAlive`/`equipped.item_sword`/
/// `npc_task.npc_tyrion.xxx`），背包区直接 `_Entry(e, ...)`
/// （显示 `item_bread`）。与 10-87 背包段、10-93 效果摘要、10-100
/// 关系区「一律走中文名」的口径相反。
/// 【为什么 10-97 加了写侧白名单仍要改】新键不会再落盘，但
/// **旧存档里已积累的键、以及 5 个动态前缀拼出的键仍会显示**
/// （存档兼容不做破坏性清洗）。
///
/// 【flagLabel 为什么返回 null 而非原样返回】
/// `skillLabel`/`attributeLabel` 的兜底是 `_ => key`（原样返回），
/// `flagLabel` **刻意不同**：flags 存在 5 个动态前缀，静态键表天然
/// 覆盖不到。若沿用「原样返回」，调用方无法区分「该翻中文名的静态键」
/// 与「带动态部分、需另行处理的键」，面板就只能显示裸英文键。
///
/// 【断言写法提醒】
///  - 中文锚点照抄实际输出的全角标点（坑 51）；
///  - `applyEffects` 是纯函数，返回新 Player **不落盘** provider
///    （坑 53），断言落盘结果必须接返回值；
///  - `_SectionCard` 把每条 entry 渲染成 `Chip(Text(key + 空格 + value))`
///    ——**合并成一个字符串**，必须用 `find.textContaining`（坑 55）；
///  - 面板是惰性 `ListView`，需撑高视口才会 build 出末段区块。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/balance_data.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/models/event.dart';
import 'package:westeros_life_simulator/models/player.dart';
import 'package:westeros_life_simulator/providers/game_state_provider.dart';
import 'package:westeros_life_simulator/screens/player_panel_screen.dart';
import 'package:westeros_life_simulator/services/event_service.dart';
import 'package:westeros_life_simulator/utils/labels.dart';

/// 构造一个 AI 选项。
EventChoice _aiChoice(Map<String, int> effects, {String narrative = ''}) {
  return EventChoice(
    id: 'c',
    text: '测试行动',
    requirements: const <String, int>{},
    effects: effects,
    narrative: narrative,
  );
}

/// 挂载玩家面板（沿用 `batch10_99_100` 的注入引擎写法，避免无参构造
/// 新建引擎把传入玩家数据重置，坑 23）。
Widget _wrap(GameEngine engine) =>
    MaterialApp(home: PlayerPanelScreen(engine: engine));

/// 撑高视口，让惰性 ListView 把末段区块（状态标记/背包）构建出来。
void _tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// 取两个引擎实例（provider 通道用）。
GameEngine _engine() => GameEngine()..startNewGame();

void main() {
  group('Batch 10-101 `age` 键双通道对齐', () {
    test('AI 通道：age 落盘（本批新增分支，此前静默丢弃）', () {
      final provider = GameStateProvider();
      final before = provider.player.age;
      // `applyEffects` 是纯函数，必须接返回值（坑 53）。
      final after = provider.applyEffects(
        provider.player,
        const <String, int>{'age': 5},
      );
      expect(after.age, before + 5);
      expect(provider.lastRejectedEffectKeys, isEmpty,
          reason: 'age 是合法键，不得登记为被拒');
    });

    test('AI 通道：age 负值被下界护栏钳到 0（不落负年龄）', () {
      final provider = GameStateProvider();
      final after = provider.applyEffects(
        provider.player,
        const <String, int>{'age': -99999},
      );
      expect(after.age, 0);
    });

    test('事件通道：age 负值同样被钳到 0（两条通道判定一致）', () {
      const service = EventService();
      final res = service.applyEffects(
        Player.defaultPlayer(),
        const EventChoice(
          id: 'c',
          text: '衰老',
          requirements: <String, int>{},
          effects: <String, int>{'age': -99999},
          narrative: '',
        ),
      );
      expect(res.newPlayer.age, 0);
      expect(res.appliedEffects.containsKey('age'), isTrue);
    });

    test('事件通道：age 正值落盘（既有行为不回归）', () {
      const service = EventService();
      final res = service.applyEffects(
        Player.defaultPlayer(),
        const EventChoice(
          id: 'c',
          text: '老去',
          requirements: <String, int>{},
          effects: <String, int>{'age': 3},
          narrative: '',
        ),
      );
      expect(res.newPlayer.age, Player.defaultPlayer().age + 3);
    });
  });

  group('Batch 10-101 未识别顶层键拒收可见化', () {
    test('event_data 里的 10 个幽灵顶层键：AI 通道逐个登记为被拒', () {
      // 取证实证：这 10 个键确实存在于 event_data 的 effects 地图里，
      // 且两条 applyEffects 都不认识它们（逐个喂守卫，不做白名单自查）。
      const ghosts = [
        'political',
        'military',
        'faith',
        'magic',
        'familyRelation',
        'food',
        'happiness',
        'knowledge',
        'north',
        'allyRelation',
      ];
      for (final ghost in ghosts) {
        final provider = GameStateProvider();
        provider.applyEffects(
          provider.player,
          <String, int>{ghost: 10, 'gold': 5},
        );
        expect(provider.lastRejectedEffectKeys, contains(ghost),
            reason: '$ghost 应被登记为未生效');
        expect(provider.lastRejectedEffectKeys, isNot(contains('gold')),
            reason: '合法键不得被误登记');
      }
    });

    test('幽灵顶层键不落盘（AI 通道状态零变化）', () {
      final provider = GameStateProvider();
      final before = provider.player;
      final after = provider.applyEffects(
        before,
        const <String, int>{'military': 20, 'faith': 15},
      );
      // 这些键没有对应 Player 字段，落盘后任何可见字段都不应变化。
      expect(after.gold, before.gold);
      expect(after.reputation, before.reputation);
      expect(after.flags.length, before.flags.length);
      expect(after.skills.length, before.skills.length);
    });

    test('事件通道：幽灵顶层键登记进 failedEffects（两通道语义一致）', () {
      const service = EventService();
      final res = service.applyEffects(
        Player.defaultPlayer(),
        const EventChoice(
          id: 'c',
          text: '支持',
          requirements: <String, int>{},
          effects: <String, int>{'political': 10, 'gold': 5},
          narrative: '',
        ),
      );
      expect(res.failedEffects.containsKey('political'), isTrue);
      expect(res.appliedEffects.containsKey('gold'), isTrue);
    });

    test('合法顶层键（gold/reputation/health/energy/hunger/age）不登记', () {
      final provider = GameStateProvider();
      provider.applyEffects(
        provider.player,
        const <String, int>{
          'gold': 1,
          'reputation': 1,
          'health': 1,
          'energy': 1,
          'hunger': 1,
          'age': 1,
        },
      );
      expect(provider.lastRejectedEffectKeys, isEmpty);
    });

    test('裸前缀（无动态部分）仍被拒——10-97 修复不回归', () {
      // 坑：前缀匹配守卫必须有一条「裸前缀」用例（10-97 自身教训）。
      final provider = GameStateProvider();
      provider.applyEffects(
        provider.player,
        const <String, int>{'flags.equipped.': 1},
      );
      expect(provider.lastRejectedEffectKeys, contains('flags.equipped.'));
    });

    test('端到端：AI 写幽灵顶层键 → 回合文本提示「未生效」', () {
      final engine = _engine();
      final result = engine.applyAiChoice(
        _aiChoice(const <String, int>{'political': 10}),
      );
      expect(result, contains('未生效'));
    });

    test('端到端：AI 写真实键 → 无「未生效」提示', () {
      final engine = _engine();
      final result = engine.applyAiChoice(
        _aiChoice(const <String, int>{'gold': 10}),
      );
      expect(result, isNot(contains('未生效')));
    });
  });

  group('Batch 10-102 flagLabel 单一真相', () {
    test('26 个静态键与 BalanceData.kPlayerFlagKeys 零漂移', () {
      // 白名单加了键而标签表没加 → 该键会在面板裸奔（英文），此用例红。
      for (final key in BalanceData.kPlayerFlagKeys) {
        expect(flagLabel(key), isNotNull, reason: '$key 缺中文标签');
        expect(flagLabel(key), isNot(equals(key)),
            reason: '$key 的标签不应等于英文名');
      }
    });

    test('5 个动态前缀都不命中静态标签表（故 flagLabel 必须返回 null）', () {
      // 这是 flagLabel 与 skillLabel/attributeLabel 兜底策略不同的根据：
      // 动态键不能被「原样返回」伪装成已翻译。
      for (final prefix in BalanceData.kPlayerFlagPrefixes) {
        expect(flagLabel('${prefix}item_sword'), isNull,
            reason: '${prefix}item_sword 是动态键，不该命中静态表');
      }
    });

    test('未知键返回 null（供调用方按前缀兜底）', () {
      expect(flagLabel('totally_unknown_flag'), isNull);
      expect(flagLabel(''), isNull);
    });

    test('抽样核对具体中文名（防映射表写错字）', () {
      expect(flagLabel('isAlive'), '存活');
      expect(flagLabel('isMarried'), '已婚');
      expect(flagLabel('honor_pledge'), '荣誉誓约');
      expect(flagLabel('guild_enemy'), '商会敌对');
    });
  });

  group('Batch 10-102 玩家面板状态标记/背包区中文名', () {
    testWidgets('静态 flag 键显示中文名，不显示裸英文键', (tester) async {
      _tallView(tester);
      final engine = GameEngine()..startNewGame();
      // `startNewGame()` 无 player 参数（既有测试一律如此），注入走
      // `updatePlayer` —— 直接构造 flags 绕过写侧白名单，等价于旧存档。
      engine.updatePlayer(
        engine.player.copyWith(
          flags: const <String, bool>{'isAlive': true, 'isMarried': false},
        ),
      );
      await tester.pumpWidget(_wrap(engine));
      await tester.pumpAndSettle();

      // 坑 55：_SectionCard 把 entry 渲染成 Chip(Text(key + 空格 + value))，
      // 是**合并字符串**，必须用 textContaining，不能用 find.text。
      expect(find.textContaining('存活'), findsWidgets);
      expect(find.textContaining('已婚'), findsWidgets);
      expect(find.textContaining('isAlive'), findsNothing);
      expect(find.textContaining('isMarried'), findsNothing);
    });

    testWidgets('背包区显示物品中文名，不显示裸 item id', (tester) async {
      _tallView(tester);
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          inventory: const <String>['item_bread', 'item_bread'],
        ),
      );
      await tester.pumpWidget(_wrap(engine));
      await tester.pumpAndSettle();

      expect(find.textContaining('黑面包'), findsWidgets);
      expect(find.textContaining('item_bread'), findsNothing);
    });

    testWidgets('装备类动态 flag 键显示「装备·<物品中文名>」', (tester) async {
      _tallView(tester);
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          flags: const <String, bool>{'equipped.item_sword': true},
        ),
      );
      await tester.pumpWidget(_wrap(engine));
      await tester.pumpAndSettle();

      expect(find.textContaining('装备·'), findsWidgets);
      expect(find.textContaining('equipped.item_sword'), findsNothing);
    });

    testWidgets('旧存档残留的未知键回退显示原键（不空白、不抛错）', (
      tester,
    ) async {
      _tallView(tester);
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(
          inventory: const <String>['item_ghost_legacy'],
        ),
      );
      await tester.pumpWidget(_wrap(engine));
      await tester.pumpAndSettle();

      // 未知物品 id 回退 id 本身——存档兼容不做破坏性清洗。
      expect(find.textContaining('item_ghost_legacy'), findsWidgets);
    });
  });
}