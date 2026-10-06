/// Batch 10-121（S3-1）测试：assets/data 镜像**可被模型的 fromJson 反序列化**。
///
/// 【为什么要这个测试】`docs/specs/content-schema.md` 自称是「M4 内容外置的
/// 契约文档」，但 S3-1 逐条比对后发现它写的字段表与真实模型**几乎没有一条
/// 对得上**（id 前缀 `evt_0101` vs 实际 `event_king_death`、事件字段
/// `title/text/weight` vs 实际 `name/description/triggerConditions`、
/// 嵌套 `effects` vs 扁平点号键、家族 `allies/enemies` vs 实际 `relations`）。
/// 文档是虚构的，而**镜像从来没有被任何一段代码真正加载过**——所以没人发现。
///
/// S3-1 顺手把「镜像不可反序列化」这个隐藏前提拆掉了，本测试是它的回归闸门：
///
///   1. **枚举带类名前缀**：导出器原样输出 Dart 源码里的 `EventType.economic`，
///      于是 JSON 里是 `"EventType.economic"`。而 `GameEvent.fromJson` 走
///      `safeEnum(EventType.values, json['type'], ...)`，比对的是裸名 `economic`
///      → 72 个事件**静默全部回落成 `EventType.daily`**；`Family` / `Location` /
///      `Npc` 的 `fromJson` 用的是 `values.byName(...)`，**对未知名直接抛**
///      ArgumentError，连回落都没有。
///   2. **governorId 是字符串 "null"**：Dart 源码写 `governorId: null`，
///      `_clean('null')` 得到 Python 字符串 `'null'` → JSON `"governorId": "null"`。
///      `Location.fromJson` 判空用的是 `== null || isEmpty`，长度 4 的字符串
///      两个都不满足 → 56 个无治主地点全部走进「治主数据缺失」分支。
///   3. **mood 是 int**（S1-3 已修）：`Npc.fromJson` 的 `json['mood'] as String?`
///      对 int 直接抛 TypeError。
///
/// 前两条是本次新发现的，第三条是 P1-01 的同类。共同点是：**运行时不读 JSON，
/// 所以这些问题可以无限期潜伏**；一旦 S4-4 决定把 JSON 变成真数据源，它们
/// 会在同一次发布里全部爆炸。
///
/// 【本文件不覆盖什么】`Item` 与 `NpcTaskTemplate` 两个模型**根本没有 fromJson**
/// （`lib/data/item_data.dart` 里的 `Item` 只有构造函数），所以 items.json /
/// tasks.json 目前无法反序列化——这是 S4-4 的第四个前置条件，本测试只做字段级
/// 校验并在文档里记录，不假装它们可加载。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/event_data.dart';
import 'package:westeros_life_simulator/data/family_data.dart';
import 'package:westeros_life_simulator/data/location_data.dart';
import 'package:westeros_life_simulator/data/npc_data.dart';
import 'package:westeros_life_simulator/data/system_data.dart';
import 'package:westeros_life_simulator/models/event.dart';
import 'package:westeros_life_simulator/models/family.dart';
import 'package:westeros_life_simulator/models/location.dart';
import 'package:westeros_life_simulator/models/npc.dart';
import 'package:westeros_life_simulator/models/system.dart';

List<Object?> _readMirror(String name) {
  final file = File('assets/data/$name');
  if (!file.existsSync()) {
    fail('assets/data/$name 不存在（先跑 python3 scripts/dart_content_extract.py）');
  }
  return jsonDecode(file.readAsStringSync()) as List<Object?>;
}

void main() {
  group('batch10_121 · 镜像可被模型反序列化', () {
    test('events.json → GameEvent.fromJson：条数一致且 type 不回落', () {
      final raw = _readMirror('events.json');
      expect(raw.length, allEvents.length);
      final parsed = raw.map((e) => GameEvent.fromJson(e as Map<String, dynamic>)).toList();

      // 枚举前缀 bug 的特征：byName/safeEnum 匹配不上 → 全部变 daily
      final dailyCount = parsed.where((e) => e.type == EventType.daily).length;
      final dartDaily = allEvents.where((e) => e.type == EventType.daily).length;
      expect(dailyCount, dartDaily,
          reason: '镜像里的事件 type 若带 EventType. 前缀，fromJson 会静默回落到 '
              'EventType.daily，daily 数量会暴涨');

      for (var i = 0; i < allEvents.length; i++) {
        // 全字段往返：toJson 序列化后逐字符比对。只比几个字段的话，
        // 「注释被当成键名」这类提取损坏（见文件头第 4 条）会静默溜过。
        expect(jsonEncode(parsed[i].toJson()), jsonEncode(allEvents[i].toJson()),
            reason: '${allEvents[i].id} 经镜像往返后字段有损');
      }
    });

    test('families.json → Family.fromJson：scale 不抛且往返一致', () {
      final raw = _readMirror('families.json');
      expect(raw.length, allFamilies.length);
      final parsed = raw.map((e) => Family.fromJson(e as Map<String, dynamic>)).toList();
      for (var i = 0; i < allFamilies.length; i++) {
        expect(parsed[i].scale, allFamilies[i].scale,
            reason: 'FamilyScale.values.byName 对 "FamilyScale.great" 会直接抛');
        expect(jsonEncode(parsed[i].toJson()), jsonEncode(allFamilies[i].toJson()),
            reason: '${allFamilies[i].id} 经镜像往返后字段有损');
      }
    });

    test('locations.json → Location.fromJson：governorId 的 null 语义不丢', () {
      final raw = _readMirror('locations.json');
      expect(raw.length, allLocations.length);
      final parsed = raw.map((e) => Location.fromJson(e as Map<String, dynamic>)).toList();
      final dartNull = allLocations.where((l) => l.governorId == null).length;
      final jsonNull = parsed.where((l) => l.governorId == null).length;
      expect(jsonNull, dartNull,
          reason: '镜像若把 null 写成字符串 "null"，fromJson 拿到的是长度 4 的字符串，'
              'ai_service 的「无治主」判定（== null || isEmpty）会全部失效');
      for (var i = 0; i < allLocations.length; i++) {
        expect(jsonEncode(parsed[i].toJson()), jsonEncode(allLocations[i].toJson()),
            reason: '${allLocations[i].id} 经镜像往返后字段有损');
      }
    });

    test('npcs.json → Npc.fromJson：mood 是 String、tasks 是列表', () {
      final raw = _readMirror('npcs.json');
      expect(raw.length, allNpcs.length);
      final parsed = raw.map((e) => Npc.fromJson(e as Map<String, dynamic>)).toList();
      final withMood = parsed.where((n) => n.mood.isNotEmpty).length;
      final withTasks = parsed.where((n) => n.tasks.isNotEmpty).length;
      // S1-3 之前 mood 被导出成 int（fromJson 直接抛）、tasks 字段整个缺失
      expect(withMood, greaterThan(0), reason: 'mood 全空说明导出器又把它丢了');
      expect(withTasks, greaterThan(0), reason: 'tasks 全空说明导出器又把它丢了');
      for (var i = 0; i < allNpcs.length; i++) {
        expect(jsonEncode(parsed[i].toJson()), jsonEncode(allNpcs[i].toJson()),
            reason: '${allNpcs[i].id} 经镜像往返后字段有损');
      }
    });

    test('systems.json → GameSystem.fromJson：条数一致', () {
      final raw = _readMirror('systems.json');
      expect(raw.length, allSystems.length);
      final parsed = raw.map((e) => GameSystem.fromJson(e as Map<String, dynamic>)).toList();
      for (var i = 0; i < allSystems.length; i++) {
        expect(jsonEncode(parsed[i].toJson()), jsonEncode(allSystems[i].toJson()),
            reason: '${allSystems[i].id} 经镜像往返后字段有损');
      }
    });
  });

  group('batch10_121 · 无 fromJson 的两域做字段级校验', () {
    test('items.json：category 是裸枚举名（Item 没有 fromJson，只能查形态）', () {
      final raw = _readMirror('items.json').cast<Map<String, dynamic>>();
      expect(raw.length, 33);
      for (final item in raw) {
        expect(item['category'], isA<String>());
        expect(item['category'] as String, isNot(contains('.')),
            reason: '${item['id']} 的 category 带类名前缀，'
                '将来给 Item 补 fromJson 时 byName 会抛');
      }
    });

    test('tasks.json：type 是裸枚举名且 steps 非空', () {
      final raw = _readMirror('tasks.json').cast<Map<String, dynamic>>();
      expect(raw.length, 72);
      for (final task in raw) {
        expect(task['type'] as String, isNot(contains('.')));
        expect((task['steps'] as List<Object?>).isNotEmpty, isTrue);
      }
    });
  });
}
