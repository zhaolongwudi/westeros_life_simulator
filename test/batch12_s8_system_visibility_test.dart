/// Batch 12 · S12-8 测试：系统可见性分层。
///
/// 【背景】此前 `availableSystems()` 的 `_ => false` 兜底把 **39/73**
/// 个系统静默吞掉（另有异鬼/死亡 2 个是显式 `false`，修复前永不可见共 41）。
/// 取证后发现其中 **21 个是可玩内容**（魔法/战争/情报/存档/红袍祭司），
/// 只有 **18 个是开发规范**（AI 9 / 规则 3 / 保护 6）。
///
/// 【用户已拍板】「只改展示层」：
/// - 可玩类 21 个 ⇒ 接入展示（给出与身份/地点挂钩的可见条件）
/// - 开发规范类 18 个 ⇒ 永久隐藏，但**由本测试锁定集合**，
///   防止未来新增分类又被 `_ => false` 静默吞掉
/// - 占位文案（61/73 个系统的「X规则/X代价/X传承」三段模板）⇒ **本轮不动**
///
/// 【为什么用「跨身份/地点扫描」而不是逐个硬编码】逐个写 21 条断言只能
/// 证明「我想到的那些可见」，证明不了「没有别的被吞掉」。扫描全部身份 ×
/// **全部地点** × 三种家族后取**永不可见集**，才能锁死「恰好 20 个」。
/// （不能只取「每类型/每区域首个」：该取样会漏掉 `location_astapor`
/// 这类由具体 id 决定的挂载点，把无垢者/多斯拉克/野人误判为不可见。）
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/location_data.dart';
import 'package:westeros_life_simulator/data/system_data.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/models/player.dart';

/// 开发规范类：写给开发者看的世界运行规范，不是玩家可接触的事物。
const Set<String> _devSpecCategories = <String>{'AI', '规则', '保护'};

/// 被动类：不主动列出（保持既有语义）。
const Set<String> _passiveCategories = <String>{'异鬼', '死亡'};

/// 全部身份（用于扫描）。
const List<PlayerIdentity> _allIdentities = PlayerIdentity.values;

/// 在「全部身份 × 全部地点 × 三种家族」下扫描，返回**从未出现过**的系统。
///
/// 【为什么复用单个 engine 而不是每次 new】矩阵是 10×70×3 = **2100 个组合**，
/// 每次 `GameEngine()` 都要重建 73 系统/70 地点/38 NPC/72 事件，代价过大。
/// 用 `updatePlayer` 就地换玩家即可——`availableSystems()` 只读 `player`
/// 与 `currentLocation`（由 `player.locationId` 推出），无其它状态依赖。
///
/// 【结果缓存】四个用例都要用同一份扫描结果，故缓存一次。
Set<String>? _neverVisibleCache;

Set<String> _neverVisibleSystemIds() {
  final cached = _neverVisibleCache;
  if (cached != null) return cached;

  final engine = GameEngine(
    player: Player.defaultPlayer(),
    isGameActive: true,
  );
  final everVisible = <String>{};
  const families = <String>['', 'family_stark', 'family_targaryen'];

  for (final identity in _allIdentities) {
    for (final l in allLocations) {
      for (final fam in families) {
        engine.updatePlayer(Player.defaultPlayer().copyWith(
          identity: identity,
          locationId: l.id,
          familyId: fam,
        ));
        for (final s in engine.availableSystems()) {
          everVisible.add(s.id);
        }
      }
    }
  }
  final never = allSystems
      .map((s) => s.id)
      .where((id) => !everVisible.contains(id))
      .toSet();
  _neverVisibleCache = never;
  return never;
}

void main() {
  group('S12-8 · 永不可见集恰为 18 个开发规范 + 2 个被动系统', () {
    test('扫描后「永不可见」的系统恰好等于 AI/规则/保护 + 异鬼/死亡', () {
      final never = _neverVisibleSystemIds();
      final expected = allSystems
          .where((s) =>
              _devSpecCategories.contains(s.category) ||
              _passiveCategories.contains(s.category))
          .map((s) => s.id)
          .toSet();

      expect(
          allSystems
              .where((s) => _devSpecCategories.contains(s.category))
              .length,
          18,
          reason: '前提校验：开发规范类应为 9(AI)+3(规则)+6(保护)=18 个');
      expect(expected.length, 20, reason: '18 开发规范 + 2 被动 = 20');
      expect(never, equals(expected),
          reason: '永不可见集必须恰好是这 20 个。'
              '多出来 = 又有可玩系统被静默吞掉；'
              '少掉 = 开发规范类泄漏进了玩家面板。');
    });

    test('可玩类 21 个系统在某个身份/地点组合下可见', () {
      final never = _neverVisibleSystemIds();
      final playable = allSystems
          .where((s) =>
              !_devSpecCategories.contains(s.category) &&
              !_passiveCategories.contains(s.category))
          .toList();

      expect(playable.length, 21,
          reason: '前提校验：可玩类应为 5(战争)+7(魔法)+6(情报)+2(存档)+1(红袍祭司)=21 个');

      final stuck = playable.where((s) => never.contains(s.id)).toList();
      expect(stuck, isEmpty,
          reason: '这些可玩系统在任何身份/地点下都看不到：'
              '${stuck.map((s) => '${s.name}(${s.category})').join('、')}');
    });

    test('被动类（异鬼/死亡）仍不主动列出', () {
      final never = _neverVisibleSystemIds();
      for (final s in allSystems.where(
          (s) => _passiveCategories.contains(s.category))) {
        expect(never.contains(s.id), isTrue,
            reason: '${s.name} 属被动系统，应保持不可见');
      }
    });

    test('可见 + 永不可见 = 全部 73，无遗漏无重复', () {
      final never = _neverVisibleSystemIds();
      final visible = allSystems.length - never.length;
      expect(visible, 53, reason: '73 - 20 = 53 个系统至少有一种方式可见');
      expect(never.length + visible, allSystems.length);
    });
  });

  group('S12-8 · 各可玩分类的可见条件逐条验收', () {
    test('存档系统恒可见（它是玩家功能，与地点身份无关）', () {
      // 故意用一个「最不可能」的组合：平民 + 超自然领域 + 无家族。
      final engine = GameEngine(
        player: Player.defaultPlayer().copyWith(
          identity: PlayerIdentity.commoner,
          locationId: 'location_white_walker',
          familyId: '',
        ),
        isGameActive: true,
      );
      final avail = engine.availableSystems();
      expect(avail.any((s) => s.category == '存档'), isTrue,
          reason: '存档是玩家功能，任何身份地点都该能看到');
    });

    test('战争系统：士兵身份可见，城堡/要塞地点可见', () {
      final byIdentity = GameEngine(
        player: Player.defaultPlayer().copyWith(
          identity: PlayerIdentity.soldier,
          locationId: 'location_winterfell',
          familyId: '',
        ),
        isGameActive: true,
      );
      expect(byIdentity.availableSystems().any((s) => s.category == '战争'),
          isTrue, reason: '士兵应能看到战争系统');

      final byLocation = GameEngine(
        player: Player.defaultPlayer().copyWith(
          identity: PlayerIdentity.commoner,
          locationId: 'location_winterfell', // 城堡
          familyId: '',
        ),
        isGameActive: true,
      );
      expect(byLocation.availableSystems().any((s) => s.category == '战争'),
          isTrue, reason: '身处城堡应能看到战争系统');
    });

    test('战争系统：平民在荒野看不到', () {
      final engine = GameEngine(
        player: Player.defaultPlayer().copyWith(
          identity: PlayerIdentity.commoner,
          locationId: 'location_whispering_wood', // 北境·荒野
          familyId: '',
        ),
        isGameActive: true,
      );
      expect(engine.availableSystems().any((s) => s.category == '战争'), isFalse,
          reason: '平民在荒野不该看到战争系统（无参战身份、非据点）');
    });

    test('魔法系统：超自然领域可见，普通城镇不可见', () {
      final supernatural = GameEngine(
        player: Player.defaultPlayer().copyWith(
          identity: PlayerIdentity.commoner,
          locationId: 'location_green_seer', // 超自然
          familyId: '',
        ),
        isGameActive: true,
      );
      expect(
          supernatural.availableSystems().any((s) => s.category == '魔法'), isTrue,
          reason: '身处超自然领域应能看到魔法系统');

      final town = GameEngine(
        player: Player.defaultPlayer().copyWith(
          identity: PlayerIdentity.commoner,
          locationId: 'location_kings_landing', // 城市
          familyId: '',
        ),
        isGameActive: true,
      );
      expect(town.availableSystems().any((s) => s.category == '魔法'), isFalse,
          reason: '平民在君临看不到魔法系统（魔法稀有，不该满街都是）');
    });

    test('情报系统：城市可见，荒野不可见', () {
      final city = GameEngine(
        player: Player.defaultPlayer().copyWith(
          identity: PlayerIdentity.commoner,
          locationId: 'location_kings_landing',
          familyId: '',
        ),
        isGameActive: true,
      );
      expect(city.availableSystems().any((s) => s.category == '情报'), isTrue,
          reason: '城市是情报网最密处');

      final wild = GameEngine(
        player: Player.defaultPlayer().copyWith(
          identity: PlayerIdentity.commoner,
          locationId: 'location_whispering_wood',
          familyId: '',
        ),
        isGameActive: true,
      );
      expect(wild.availableSystems().any((s) => s.category == '情报'), isFalse,
          reason: '平民在荒野看不到情报系统');
    });

    test('红袍祭司：厄索斯可见，北境不可见', () {
      final essos = GameEngine(
        player: Player.defaultPlayer().copyWith(
          identity: PlayerIdentity.commoner,
          locationId: 'location_dothraki_sea', // 厄索斯
          familyId: '',
        ),
        isGameActive: true,
      );
      expect(essos.availableSystems().any((s) => s.category == '红袍祭司'), isTrue,
          reason: '厄索斯是光之王信仰的主要势力范围');

      final north = GameEngine(
        player: Player.defaultPlayer().copyWith(
          identity: PlayerIdentity.commoner,
          locationId: 'location_winterfell', // 北境
          familyId: '',
        ),
        isGameActive: true,
      );
      expect(north.availableSystems().any((s) => s.category == '红袍祭司'), isFalse,
          reason: '北境平民不该看到红袍祭司系统');
    });

    test('神职人员身份可跨地点看到魔法与红袍祭司', () {
      final engine = GameEngine(
        player: Player.defaultPlayer().copyWith(
          identity: PlayerIdentity.priest,
          locationId: 'location_winterfell',
          familyId: '',
        ),
        isGameActive: true,
      );
      final avail = engine.availableSystems();
      expect(avail.any((s) => s.category == '魔法'), isTrue,
          reason: '神职人员应能接触魔法系统');
      expect(avail.any((s) => s.category == '红袍祭司'), isTrue,
          reason: '神职人员应能接触红袍祭司系统');
    });
  });

  group('S12-8 · 既有行为不回归', () {
    test('系统总数仍是 73（本批只改可见性，不动数据）', () {
      final engine = GameEngine()..startNewGame();
      expect(engine.systemCount, 73);
    });

    test('默认玩家（史塔克贵族在临冬城）可见数比修复前显著增加', () {
      final engine = GameEngine()..startNewGame();
      final avail = engine.availableSystems();
      // 修复前：默认玩家只能看到家族/封建/继承/婚姻/法律 + 城堡触发的战争，
      // 实测远少于 20。这里用「至少 15」作下界，不锁精确值以免脆化。
      expect(avail.length, greaterThanOrEqualTo(15),
          reason: '修复前默认玩家可见数很少（39 个系统被吞）；'
              '现在至少应能看到家族/封建/继承/婚姻/法律 + 战争 + 情报 + 存档');
      // 关键：默认玩家在临冬城（城堡）应能看到战争，且存档恒可见。
      expect(avail.any((s) => s.category == '战争'), isTrue);
      expect(avail.any((s) => s.category == '存档'), isTrue);
    });

    test('开发规范类在任何组合下都不出现（含贵族在君临）', () {
      final engine = GameEngine(
        player: Player.defaultPlayer().copyWith(
          identity: PlayerIdentity.noble,
          locationId: 'location_kings_landing',
          familyId: 'family_stark',
        ),
        isGameActive: true,
      );
      final avail = engine.availableSystems();
      for (final cat in _devSpecCategories) {
        expect(avail.any((s) => s.category == cat), isFalse,
            reason: '开发规范类「$cat」不该出现在玩家面板');
      }
    });

    test('面板文本仍可生成且含计数行', () {
      final engine = GameEngine()..startNewGame();
      final panel = engine.formatSystemsPanel();
      expect(panel, contains('系统面板'));
      expect(panel, contains('已接触系统'));
    });

    test('月度结算不受影响：守夜人仍扣 10 精力', () {
      final engine = GameEngine(
        player: Player.defaultPlayer().copyWith(
          locationId: 'location_the_wall',
          energy: 80,
          familyId: '',
        ),
        isGameActive: true,
      );
      expect(
          engine.availableSystems().any((s) => s.id == 'system_nightswatch'), isTrue);
      final before = engine.player.energy;
      final text = engine.applyMonthlySystems(seed: 1);
      expect(engine.player.energy, before - 10);
      expect(text, contains('守夜人'));
    });

    test('无面者/龙/铁民/学城等既有分类条件未被本批改动', () {
      final assassin = GameEngine(
        player: Player.defaultPlayer().copyWith(
          identity: PlayerIdentity.assassin,
        ),
        isGameActive: true,
      );
      expect(assassin.availableSystems().any((s) => s.category == '无面者'),
          isTrue);

      final targ = GameEngine(
        player: Player.defaultPlayer().copyWith(familyId: 'family_targaryen'),
        isGameActive: true,
      );
      expect(targ.availableSystems().any((s) => s.category == '龙'), isTrue);

      final ironborn = GameEngine(
        player: Player.defaultPlayer().copyWith(locationId: 'location_pike'),
        isGameActive: true,
      );
      expect(
          ironborn.availableSystems()
              .any((s) => s.category == '铁民' || s.category == '淹神'),
          isTrue);

      final maester = GameEngine(
        player: Player.defaultPlayer().copyWith(
          identity: PlayerIdentity.maester,
          locationId: 'location_citadel',
        ),
        isGameActive: true,
      );
      expect(maester.availableSystems().any((s) => s.category == '学城'), isTrue);
    });
  });
}
