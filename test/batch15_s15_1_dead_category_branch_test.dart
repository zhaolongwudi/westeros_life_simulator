/// S15-1 测试：availableSystems 的 switch 不含「0 系统分类」的死分支。
///
/// 【本批修的是什么】`mixin_systems.dart` 的
/// `'铁民' || '淹神' => isInRegion('铁群岛')` 里 **`'淹神'` 是死分支**：
/// `assets/data/systems.json` 73 个系统的分类全集里没有「淹神」
/// （0 个系统挂该分类），该分支永远匹配不上任何系统——
/// 是 S12-8 之前留下的悬空 case（S14-2 卡片「已知边界」记录在案，
/// 当时明确「属死代码范畴，不在本卡内动」）。本卡收口它。
///
/// 【为什么用源码扫描判别式】死分支**没有任何行为可观察**——没有系统挂着
/// 该分类，`availableSystems()` 的行为测试恒绿无判别力；只有扫源码才抓得住。
/// 源码扫描在本项目有先例（`batch10_91_92_effect_key_whitelist_test.dart:327`
/// 用 `File('lib/...').readAsStringSync()` 做写侧守卫的静态核查）。
///
/// 【提取器怎么避免误伤】switch 表达式里有 `'location_the_wall'`、
/// `'北境'` 这类**带引号的实参串**，逐串提取会把它们误当分类。
/// 正则只取 `=>` **紧前面**的「引号串 + `||` 链」——那是 case 标签的位置；
/// 表达式实参后面跟的是 `,` 或运算符，不会被匹配。
///
/// 覆盖：
/// 1. 死分支判别式：switch 的每个分类串必须在 systems.json 有 ≥1 系统
/// 2. 反向锁：systems.json 的每个分类必须被 switch 显式处理（不得落进 `_`）
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 从 mixin_systems.dart 提取 availableSystems switch 的全部分类标签。
Set<String> _extractSwitchCategories() {
  final src = File('lib/mixins/mixin_systems.dart').readAsStringSync();
  final start = src.indexOf('final keep = switch (cat) {');
  expect(start, greaterThan(0), reason: '前提：availableSystems 的 switch 未被改名/搬走');
  final end = src.indexOf('};', start);
  final body = src.substring(start, end);

  // case 标签 = `=>` 紧前面的「引号串（可含 || 链）」；
  // 表达式里的实参串（地点/区域 id）后面跟的是 `,`/运算符，不匹配。
  final casePattern = RegExp(r"((?:'[^']+'\s*\|\|\s*)*'[^']+')\s*=>");
  final cats = <String>{};
  for (final m in casePattern.allMatches(body)) {
    for (final s in RegExp(r"'([^']+)'").allMatches(m.group(1)!)) {
      cats.add(s.group(1)!);
    }
  }
  expect(cats, isNotEmpty, reason: '前提：提取器应拿到分类标签');
  return cats;
}

/// systems.json 的全部分类。
Set<String> _jsonCategories() {
  final list = jsonDecode(
    File('assets/data/systems.json').readAsStringSync(),
  ) as List<dynamic>;
  return list.map((s) => s['category'] as String).toSet();
}

void main() {
  group('S15-1 switch 分支 ↔ systems.json 分类集 双向完备性', () {
    test('switch 出现的每个分类都必须在 systems.json 有 ≥1 个系统（死分支判别式）', () {
      final switchCats = _extractSwitchCategories();
      final jsonCats = _jsonCategories();
      final dead = switchCats.difference(jsonCats).toList()..sort();
      expect(dead, isEmpty,
          reason: 'switch 出现 systems.json 中不存在的分类（死分支，永远匹配不上'
              '任何系统）：$dead —— 要么分支删掉，要么分类是数据缺失');
    });

    test('systems.json 的每个分类都必须被 switch 显式处理（不得静默落进 _ => false）', () {
      final switchCats = _extractSwitchCategories();
      final jsonCats = _jsonCategories();
      final unhandled = jsonCats.difference(switchCats).toList()..sort();
      expect(unhandled, isEmpty,
          reason: 'systems.json 有分类未被 switch 接线（玩家永远不可见，'
              '与 S12-8「不存在第三种没声明的状态」同型）：$unhandled');
    });
  });
}
