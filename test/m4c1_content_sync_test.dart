/// M4c-1 测试：内容 JSON 外置资产与 Dart 常量真相源一致。
///
/// 覆盖：
/// 1. assets/data/*.json 全部存在且可解析（jsonDecode 不抛）
/// 2. 每域 JSON 实体 id 集合 == Dart 常量 id 集合（不落后、不多余、无重复）
/// 3. 关键文本字段非空（events 用 name，tasks 用 title）
/// 4. 跨域引用完整性：npc.familyId -> families；task.npcId -> npcs
///
/// 说明：JSON 由 scripts/dart_content_extract.py 从 Dart 常量生成，
/// 本测试在 CI 上防「改 Dart 数据后忘记重新生成 JSON」导致对账失效。
library;
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/event_data.dart';
import 'package:westeros_life_simulator/data/family_data.dart';
import 'package:westeros_life_simulator/data/item_data.dart';
import 'package:westeros_life_simulator/data/location_data.dart';
import 'package:westeros_life_simulator/data/npc_data.dart';
import 'package:westeros_life_simulator/data/npc_task_data.dart';
import 'package:westeros_life_simulator/data/system_data.dart';

/// 读取 assets/data 下 JSON 并解码为 List<Map<String, dynamic>>。
List<Map<String, dynamic>> _loadJson(String name) {
  final file = File('assets/data/$name');
  expect(file.existsSync(), isTrue, reason: '缺少资产文件 assets/data/$name');
  final decoded = jsonDecode(file.readAsStringSync());
  expect(decoded, isA<List<dynamic>>(), reason: '$name 应为 JSON 数组');
  return (decoded as List<dynamic>).cast<Map<String, dynamic>>();
}

/// 提取实体 id 集合。
Set<String> _ids(List<Map<String, dynamic>> list) =>
    list.map((e) => e['id'] as String).toSet();

void main() {
  group('M4c-1 内容 JSON 资产与 Dart 真相源一致', () {
    test('families.json 与 allFamilies 对齐', () {
      final json = _loadJson('families.json');
      final dartIds = allFamilies.map((f) => f.id).toSet();
      final jsonIds = _ids(json);
      expect(jsonIds, dartIds, reason: 'families JSON 与 Dart id 集合不一致');
      expect(jsonIds.length, allFamilies.length, reason: 'families id 重复');
      for (final f in json) {
        expect((f['name'] as String?)?.isNotEmpty, isTrue, reason: '${f['id']} name 为空');
        expect(f['seat'], isNotEmpty, reason: '${f['id']} seat 为空');
      }
    });

    test('locations.json 与 allLocations 对齐', () {
      final json = _loadJson('locations.json');
      final dartIds = allLocations.map((l) => l.id).toSet();
      final jsonIds = _ids(json);
      expect(jsonIds, dartIds, reason: 'locations JSON 与 Dart id 集合不一致');
      expect(jsonIds.length, allLocations.length, reason: 'locations id 重复');
      for (final l in json) {
        expect((l['name'] as String?)?.isNotEmpty, isTrue, reason: '${l['id']} name 为空');
      }
    });

    test('npcs.json 与 allNpcs 对齐', () {
      final json = _loadJson('npcs.json');
      final dartIds = allNpcs.map((n) => n.id).toSet();
      final jsonIds = _ids(json);
      expect(jsonIds, dartIds, reason: 'npcs JSON 与 Dart id 集合不一致');
      expect(jsonIds.length, allNpcs.length, reason: 'npcs id 重复');
      for (final n in json) {
        expect((n['name'] as String?)?.isNotEmpty, isTrue, reason: '${n['id']} name 为空');
        expect(n['locationId'], isNotEmpty, reason: '${n['id']} locationId 为空');
      }
    });

    test('events.json 与 allEvents 对齐', () {
      final json = _loadJson('events.json');
      final dartIds = allEvents.map((e) => e.id).toSet();
      final jsonIds = _ids(json);
      expect(jsonIds, dartIds, reason: 'events JSON 与 Dart id 集合不一致');
      expect(jsonIds.length, allEvents.length, reason: 'events id 重复');
      for (final e in json) {
        expect((e['name'] as String?)?.isNotEmpty, isTrue, reason: '${e['id']} name 为空');
        // 每条事件至少 2 个选项且至少一个无条件
        final choices = (e['choices'] as List<dynamic>?) ?? [];
        expect(choices.length, greaterThanOrEqualTo(2), reason: '${e['id']} 选项不足 2 个');
        final hasFree = choices.any((c) {
          final req = (c as Map<String, dynamic>)['requirements'] as Map<String, dynamic>?;
          return req == null || req.isEmpty;
        });
        expect(hasFree, isTrue, reason: '${e['id']} 无无条件选项');
      }
    });

    test('systems.json 与 allSystems 对齐', () {
      final json = _loadJson('systems.json');
      final dartIds = allSystems.map((s) => s.id).toSet();
      final jsonIds = _ids(json);
      expect(jsonIds, dartIds, reason: 'systems JSON 与 Dart id 集合不一致');
      expect(jsonIds.length, allSystems.length, reason: 'systems id 重复');
    });

    test('items.json 与 kItems 对齐', () {
      final json = _loadJson('items.json');
      final dartIds = kItems.keys.toSet();
      final jsonIds = _ids(json);
      expect(jsonIds, dartIds, reason: 'items JSON 与 Dart id 集合不一致');
      expect(jsonIds.length, kItems.length, reason: 'items id 重复');
      for (final i in json) {
        expect((i['name'] as String?)?.isNotEmpty, isTrue, reason: '${i['id']} name 为空');
      }
    });

    test('tasks.json 与 allNpcTaskTemplates 对齐', () {
      final json = _loadJson('tasks.json');
      final dartIds = allNpcTaskTemplates.map((t) => t.id).toSet();
      final jsonIds = _ids(json);
      expect(jsonIds, dartIds, reason: 'tasks JSON 与 Dart id 集合不一致');
      expect(jsonIds.length, allNpcTaskTemplates.length, reason: 'tasks id 重复');
      for (final t in json) {
        expect((t['title'] as String?)?.isNotEmpty, isTrue, reason: '${t['id']} title 为空');
      }
      // 协作任务 coNpcId 与 Dart 对齐
      final coopDart = allNpcTaskTemplates
          .where((t) => t.isCoop)
          .map((t) => t.id)
          .toSet();
      for (final t in json) {
        final co = t['coNpcId'] as String?;
        if (coopDart.contains(t['id'])) {
          expect(co, isNotNull, reason: '${t['id']} 协作任务 JSON 缺 coNpcId');
        }
      }
    });

    test('跨域引用完整：npc.familyId -> families / task.npcId -> npcs', () {
      final famIds = _ids(_loadJson('families.json'));
      final npcIds = _ids(_loadJson('npcs.json'));
      for (final n in _loadJson('npcs.json')) {
        final fid = n['familyId'] as String?;
        if (fid != null && fid.isNotEmpty) {
          expect(famIds.contains(fid), isTrue, reason: '${n['id']} familyId $fid 不存在');
        }
      }
      for (final t in _loadJson('tasks.json')) {
        final nid = t['npcId'] as String?;
        if (nid != null && nid.isNotEmpty) {
          expect(npcIds.contains(nid), isTrue, reason: '${t['id']} npcId $nid 不存在');
        }
        final co = t['coNpcId'] as String?;
        if (co != null && co.isNotEmpty) {
          expect(npcIds.contains(co), isTrue, reason: '${t['id']} coNpcId $co 不存在');
          expect(co == nid, isFalse, reason: '${t['id']} coNpcId 与 npcId 相同');
        }
      }
    });
  });
}