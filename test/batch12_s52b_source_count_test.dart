/// S5-2 附带：源码注释里的事件计数与真实数据一致性闸门。
///
/// ## 为什么需要这个文件
///
/// `batch2_event_data_test.dart` 已经断言了 `allEvents.length == 71` 与各 `EventType`
/// 的数量——**运行时数据是有护栏的**。但它管不到 `lib/data/event_data.dart` **源码里的
/// 注释**：文件头写「45 个事件模板」（实为 71）、分组标题写「宗教事件（6）」（实为 4）、
/// 「日常生活（5）」（实为 20）。
///
/// 这类数字**没有任何东西守着**，所以能长期漂移。本项目已被同类问题反复咬到：
/// - S1-4：README 的「68 地点 / 36 NPC / 60 事件」长期过期 → 改成脚本自动生成；
/// - S5-1：`batch10_119` 的上界断言 `≤78` 而真实值 76，**错误的数字两年没被 CI 发现**。
///
/// 本文件把「注释里的数字」也纳入 CI 闸门：**读源码、逐段数 `GameEvent(`、
/// 断言与标题里写的数量一致**。这比再写一个生成器便宜得多，也不引入新的构建步骤。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/event_data.dart';

/// 定位数据源源码（测试运行时 CWD = 项目根）。
final File _source = File('lib/data/event_data.dart');

/// 一段分组标题，例如 `  // ==================== 政治事件（10） ====================`。
class _Section {
  _Section(this.title, this.declared, this.startLine);

  /// 标题原文（用于失败信息）。
  final String title;

  /// 标题括号里声明的数量；`null` 表示标题里没有数字。
  final int? declared;

  /// 标题所在行号（1-based）。
  final int startLine;

  /// 该段实际数到的 `GameEvent(` 数量。
  int actual = 0;

  @override
  String toString() => '$title（声明 $declared，实际 $actual）';
}

void main() {
  group('S5-2 附带 · 源码注释计数与真实数据一致', () {
    test('源码文件存在（路径写错会让本文件全部用例假通过）', () {
      expect(_source.existsSync(), isTrue,
          reason: '找不到 ${_source.path}；测试的工作目录应为项目根');
    });

    test('文件头「N 个事件模板」与 allEvents.length 一致', () {
      final head = _source.readAsLinesSync().first;
      final m = RegExp(r'(\d+)\s*个事件模板').firstMatch(head);
      expect(m, isNotNull,
          reason: '文件头应写「事件数据：N 个事件模板」，实际首行：$head');
      final declared = int.parse(m!.group(1)!);
      expect(declared, allEvents.length,
          reason: '文件头写 $declared 个事件模板，'
              '而 allEvents 实为 ${allEvents.length} 个。'
              '两者漂移会让接手的人按注释估算出错误的规模。');
    });

    test('每个分组标题括号里的数量 == 该段实际的 GameEvent 数', () {
      final lines = _source.readAsLinesSync();
      final headerRe = RegExp(r'^\s*// =+ (.+?) =+\s*$');
      final countRe = RegExp(r'（(\d+)）');

      final sections = <_Section>[];
      _Section? current;
      for (var i = 0; i < lines.length; i++) {
        final h = headerRe.firstMatch(lines[i]);
        if (h != null) {
          current = _Section(
            h.group(1)!,
            countRe.firstMatch(h.group(1)!) == null
                ? null
                : int.parse(countRe.firstMatch(h.group(1)!)!.group(1)!),
            i + 1,
          );
          sections.add(current);
          continue;
        }
        if (current != null && lines[i].startsWith('  GameEvent(')) {
          current.actual++;
        }
      }

      expect(sections, isNotEmpty, reason: '未解析到任何分组标题，正则可能失效');

      // 分段计数之和必须等于总数——这是本文件最关键的一条：
      // 若有人把 GameEvent 挪到所有分组之外（列表开头/结尾），加总会不等而变红。
      final summed = sections.fold<int>(0, (a, s) => a + s.actual);
      expect(summed, allEvents.length,
          reason: '各分组声明的事件之和 $summed ≠ allEvents ${allEvents.length}。'
              '说明有事件落在分组之外，或分组标题没覆盖全。');

      for (final s in sections) {
        if (s.declared == null) continue; // 标题没写数字的不强求
        expect(s.declared, s.actual,
            reason: '第 ${s.startLine} 行分组标题「$s.title」声明 ${s.declared}，'
                '实际该段有 ${s.actual} 个 GameEvent');
      }
    });

    test('分组标题声明数之和 == allEvents.length（防止标题数字互相错配）', () {
      // 上一条逐段核对已经覆盖；这里补一条「总数视角」的锁，
      // 使得即便将来某段标题写法变化导致上面某条被跳过，这条仍然有效。
      final lines = _source.readAsLinesSync();
      final headerRe = RegExp(r'^\s*// =+ (.+?) =+\s*$');
      final countRe = RegExp(r'（(\d+)）');
      var total = 0;
      for (final l in lines) {
        final h = headerRe.firstMatch(l);
        if (h == null) continue;
        final c = countRe.firstMatch(h.group(1)!);
        if (c != null) total += int.parse(c.group(1)!);
      }
      expect(total, allEvents.length,
          reason: '分组标题声明数之和 $total ≠ allEvents ${allEvents.length}');
    });
  });
}
