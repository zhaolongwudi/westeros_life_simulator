/// S13-12 测试：旅行图连通性（对应审查项 ⑧，P1）。
///
/// 【本批修的是什么】
/// `travel()` 只查**当前地点**的 `connectedTo`（`mixin_adventure.dart:33-34`），
/// 因此「A 能去 B，B 不能回 A」的单向边 = 有去无回。实测 `location_data.dart`
/// 的 70 个地点里有 **31 条单向边**，把世界切成 24 个互不连通的块：
/// 从默认出生地临冬城**只能到 3 个地点**（临冬城/白港/巴隆镇），
/// 而 **30/38 个 NPC 住在到不了的地方**（君临 7 人、高庭 3 人、鹰巢城 3 人…）。
/// 数据里明明写了「临冬城 → 恐怖堡」这类邻接，反向却缺失。
///
/// 【为什么是「补反向边」而不是「改枢纽制」】
/// 2026-10-08 由用户定方向：补反向边，让本土连通。理由是单向边在叙事上
/// 站不住脚（`docs/08_玩法设计.md` 把旅行标为 🚧，并点名「30 处 connectedTo
/// 非对称」是待办），且枢纽制要新增传送规则、改动面更大。补边是**数据修正**，
/// 不碰 `travel()` 的判定逻辑，也不改变「未知/超自然地点彼此不连通」的
/// 刻意设计（那 16 个地点本来就无连接，见下方「不该连的别乱连」用例）。
///
/// 【为什么断言全是确定性的】
/// 只读静态数据 + 纯图算法，不依赖任何 RNG（本项目已两次因「跑 N 回合
/// 应该能等到」翻车）。`travel()` 的真实位移另有
/// `batch4_mixin_adventure_test.dart` / `batch12_s9_travel_turn_cost_test.dart`
/// 覆盖，本文件只管**图的形状**。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/location_data.dart';
import 'package:westeros_life_simulator/game_engine.dart';

/// 从某地出发、沿 `connectedTo` 有向可达的全部地点（含起点）。
Set<String> _reachableFrom(String start) {
  final seen = <String>{start};
  final stack = <String>[start];
  while (stack.isNotEmpty) {
    final cur = stack.removeLast();
    for (final next in locationById(cur)?.connectedTo ?? const <String>[]) {
      if (seen.add(next)) stack.add(next);
    }
  }
  return seen;
}

/// 忽略方向的连通块划分（用于证明「补边没有把世界连成一片」）。
List<List<String>> _undirectedComponents() {
  final seen = <String>{};
  final comps = <List<String>>[];
  for (final loc in allLocations) {
    if (!seen.add(loc.id)) continue;
    final comp = <String>[];
    final stack = <String>[loc.id];
    while (stack.isNotEmpty) {
      final cur = stack.removeLast();
      comp.add(cur);
      final undirected = <String>{
        ...?locationById(cur)?.connectedTo,
        for (final other in allLocations)
          if (other.connectedTo.contains(cur)) other.id,
      };
      for (final next in undirected) {
        if (seen.add(next)) stack.add(next);
      }
    }
    comps.add(comp);
  }
  comps.sort((a, b) => b.length.compareTo(a.length));
  return comps;
}

void main() {
  group('S13-12 ⑧ 旅行图：不得存在单向边', () {
    test('全图 0 条单向边（A→B 必有 B→A）', () {
      final oneWay = <String>[];
      for (final loc in allLocations) {
        for (final target in loc.connectedTo) {
          final back = locationById(target)?.connectedTo ?? const <String>[];
          if (!back.contains(loc.id)) {
            oneWay.add('${loc.id} → $target');
          }
        }
      }
      expect(oneWay, isEmpty,
          reason: '单向边即「有去无回」（travel 只查当前地点的 connectedTo）。'
              '实测缺陷下有 31 条：${oneWay.take(5).join('、')}…');
    });

    test('所有 connectedTo 目标都是真实存在的地点', () {
      final ghosts = <String>[];
      for (final loc in allLocations) {
        for (final target in loc.connectedTo) {
          if (locationById(target) == null) ghosts.add('${loc.id} → $target');
        }
      }
      expect(ghosts, isEmpty, reason: '引用不存在的地点会渲染成裸 id：$ghosts');
    });

    test('不存在自环（地点不连接自己）', () {
      final selfLoops = allLocations
          .where((l) => l.connectedTo.contains(l.id))
          .map((l) => l.id)
          .toList();
      expect(selfLoops, isEmpty);
    });
  });

  group('S13-12 ⑧ 本土可达性：出生地必须能走遍北境连通块', () {
    test('临冬城有向可达数 == 其无向连通块大小（修复前只有 3）', () {
      final comp = _undirectedComponents()
          .firstWhere((c) => c.contains('location_winterfell'));
      final reachable = _reachableFrom('location_winterfell');
      expect(reachable.length, comp.length,
          reason: '临冬城应能走遍所在连通块（无向 ${comp.length} 个地点），'
              '实际只到 ${reachable.length} 个：${reachable.join('、')}');
    });

    test('临冬城可达地点数 ≥ 19（修复前 3）', () {
      final reachable = _reachableFrom('location_winterfell');
      expect(reachable.length, greaterThanOrEqualTo(19),
          reason: '补反向边后北境块应整体可达，实际 ${reachable.length}');
      // 抽查几个此前到不了、但数据里本就写了邻接的地点
      for (final id in <String>[
        'location_castle_black', // 恐怖堡 → 临冬城（反向此前缺失）
        'location_the_wall', // 长城
        'location_riverrun', // 奔流城
        'location_white_harbor', // 白港（原本就可直达）
      ]) {
        expect(reachable, contains(id), reason: '$id 应可达');
      }
    });

    test('同块内任意两点互达（双向连通，不是单向漏斗）', () {
      final comp = _undirectedComponents()
          .firstWhere((c) => c.contains('location_winterfell'));
      final broken = <String>[];
      for (final a in comp) {
        final reach = _reachableFrom(a);
        for (final b in comp) {
          if (!reach.contains(b)) broken.add('$a ⇢ $b');
        }
      }
      expect(broken, isEmpty,
          reason: '连通块内必须任意两点互达，否则仍是漏斗：${broken.take(5).join('、')}');
    });

    test('NPC 可达性：38 个 NPC 所在地不应因单向边而无法抵达', () {
      final reachable = _reachableFrom('location_winterfell');
      // 统计住在临冬城所在连通块内的 NPC 有多少可达
      final comp = _undirectedComponents()
          .firstWhere((c) => c.contains('location_winterfell'))
          .toSet();
      final sameBlock = <String>[];
      for (final loc in allLocations) {
        if (comp.contains(loc.id)) sameBlock.add(loc.id);
      }
      // 同块地点必须全部可达（与上一条同源，但以 NPC 住所为视角再锁一次）
      final unreachable =
          sameBlock.where((id) => !reachable.contains(id)).toList();
      expect(unreachable, isEmpty,
          reason: '同块内这些 NPC 住所走不到：$unreachable');
    });
  });

  group('S13-12 ⑧ 反向锁：不该连的别乱连', () {
    test('未知世界/超自然地点保持孤立（无连接的仍是 16 个）', () {
      final isolated =
          allLocations.where((l) => l.connectedTo.isEmpty).map((l) => l.id).toList();
      expect(isolated.length, 16,
          reason: '补边只修「有去无回」，不该给刻意孤立的地点凭空造出路。'
              '实际孤立 ${isolated.length} 个：${isolated.join('、')}');
      // 抽查超自然地点确实仍然孤立
      for (final id in <String>[
        'location_old_gods',
        'location_white_walker',
        'location_many_faced_god',
      ]) {
        expect(locationById(id)!.connectedTo, isEmpty, reason: '$id 应保持孤立');
      }
    });

    test('本土连通块数量不变（补边不制造跨块捷径）', () {
      final comps = _undirectedComponents();
      // 补边前实测 8 个非孤立块（19/11/10/4/3/3/2/2）+ 16 个孤立单点 = 24
      expect(comps.length, 24,
          reason: '补边只补反向边，不应把本土与厄索斯/超自然连起来；'
              '块数变化说明改了不该改的边。各块大小：'
              '${comps.map((c) => c.length).join(',')}');
      expect(comps.first.length, 19, reason: '最大块（北境+河间地）应为 19');
    });
  });

  group('S13-12 ⑧ 端到端：travel 真的能走到此前到不了的地方', () {
    test('临冬城 → 恐怖堡（反向边此前缺失，现在应能直接前往）', () {
      final engine = GameEngine()..startNewGame();
      expect(engine.player.locationId, 'location_winterfell');
      final text = engine.travel('location_castle_black');
      expect(text, contains('抵达'), reason: '补边后应可直接前往：$text');
      expect(engine.player.locationId, 'location_castle_black');
    });

    test('恐怖堡 → 临冬城（反向，原本就可直达，锁住不回归）', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(locationId: 'location_castle_black'),
      );
      final text = engine.travel('location_winterfell');
      expect(text, contains('抵达'), reason: text);
      expect(engine.player.locationId, 'location_winterfell');
    });

    test('长城 ↔ 东海望 双向可达（墙上城堡此前单向）', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(locationId: 'location_the_wall', gold: 9999),
      );
      expect(engine.travel('location_eastwatch'), contains('抵达'));
      expect(engine.player.locationId, 'location_eastwatch');
      // 回程
      engine.updatePlayer(engine.player.copyWith(gold: 9999));
      expect(engine.travel('location_the_wall'), contains('抵达'));
      expect(engine.player.locationId, 'location_the_wall');
    });

    test('厄索斯仍与本土地理隔离（潘托斯到不了临冬城）', () {
      final engine = GameEngine()..startNewGame();
      engine.updatePlayer(
        engine.player.copyWith(locationId: 'location_pentos', gold: 9999),
      );
      final text = engine.travel('location_winterfell');
      expect(text, contains('无法直接前往'),
          reason: '跨海通路不在本批范围，不该凭空连通：$text');
    });
  });

  group('S13-12 ⑧ 数据一致性：补边脚本不得误删条目', () {
    test('地点总数仍是 70，且 id 唯一', () {
      expect(allLocations.length, 70,
          reason: '补边是机械改写 connectedTo，若总数变化说明脚本伤了结构');
      final ids = allLocations.map((l) => l.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'id 必须唯一');
    });
  });
}
