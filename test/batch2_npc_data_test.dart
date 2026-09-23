/// Batch 2 测试：NPC 数据层。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/npc_data.dart';

void main() {
  group('NPC 数据', () {
    test('allNpcs 包含 36 个 NPC', () {
      expect(allNpcs.length, 36);
    });

    test('所有 NPC ID 唯一', () {
      final ids = allNpcs.map((n) => n.id).toSet();
      expect(ids.length, allNpcs.length);
    });

    test('所有 NPC ID 格式正确（npc_ 前缀）', () {
      for (final n in allNpcs) {
        expect(n.id.startsWith('npc_'), true,
            reason: '${n.id} 不以 npc_ 开头');
      }
    });

    test('所有 NPC 字段非空', () {
      for (final n in allNpcs) {
        expect(n.id.isNotEmpty, true);
        expect(n.name.isNotEmpty, true);
        expect(n.gender.isNotEmpty, true);
        expect(n.faith.isNotEmpty, true);
      }
    });

    test('npcById 查找成功', () {
      final nev = npcById('npc_nev');
      expect(nev, isNotNull);
      expect(nev!.name, '艾德·史塔克');
    });

    test('npcById 查找失败返回 null', () {
      expect(npcById('npc_nonexistent'), isNull);
    });

    test('NPC 年龄合理范围', () {
      for (final n in allNpcs) {
        expect(n.age >= 0 && n.age <= 150, true,
            reason: '${n.name} 年龄 ${n.age} 超出范围');
      }
    });

    test('NPC 技能非空', () {
      for (final n in allNpcs) {
        expect(n.skills.isNotEmpty, true,
            reason: '${n.name} 技能为空');
      }
    });
  });
}