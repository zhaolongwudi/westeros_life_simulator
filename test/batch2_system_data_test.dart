/// Batch 2 测试：系统数据层。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/system_data.dart';

void main() {
  group('系统数据', () {
    test('allSystems 包含 73 个系统（S3-4 删除重复的 system_succession_law）', () {
      expect(allSystems.length, 73);
    });

    test('所有系统 ID 唯一', () {
      final ids = allSystems.map((s) => s.id).toSet();
      expect(ids.length, allSystems.length);
    });

    test('所有系统 ID 格式正确（system_ 前缀）', () {
      for (final s in allSystems) {
        expect(s.id.startsWith('system_'), true,
            reason: '${s.id} 不以 system_ 开头');
      }
    });

    test('所有系统字段非空', () {
      for (final s in allSystems) {
        expect(s.id.isNotEmpty, true);
        expect(s.name.isNotEmpty, true);
        expect(s.category.isNotEmpty, true);
        expect(s.description.isNotEmpty, true);
        expect(s.rules.isNotEmpty, true,
            reason: '${s.name} 规则为空');
        expect(s.features.isNotEmpty, true,
            reason: '${s.name} 特性为空');
      }
    });

    test('systemById 查找成功', () {
      final feudal = systemById('system_feudal');
      expect(feudal, isNotNull);
      expect(feudal!.name, '封建体系');
      expect(feudal.category, '封建');
    });

    test('systemById 查找失败返回 null', () {
      expect(systemById('system_nonexistent'), isNull);
    });

    test('封建体系分类数量正确', () {
      final feudal = systemsByCategory('封建');
      expect(feudal.length, 1);
    });

    test('魔法体系分类数量正确', () {
      final magic = systemsByCategory('魔法');
      expect(magic.length, 7); // 魔法体系 + 绿先知/易形者/血魔法/预言/狼梦/龙梦
    });

    test('战争体系分类数量正确', () {
      final war = systemsByCategory('战争');
      expect(war.length, 5);
    });

    test('经济体系分类数量正确', () {
      final economy = systemsByCategory('经济');
      expect(economy.length, 8);
    });

    test('情报体系分类数量正确', () {
      final intelligence = systemsByCategory('情报');
      expect(intelligence.length, 6);
    });

    test('保护体系分类数量正确', () {
      final protection = systemsByCategory('保护');
      expect(protection.length, 6);
    });

    test('AI 体系分类数量正确', () {
      final ai = systemsByCategory('AI');
      expect(ai.length, 9); // 8 个 AI 系统 + AI 运行身份
    });

    test('所有系统规则数量合理', () {
      for (final s in allSystems) {
        expect(s.rules.length >= 1 && s.rules.length <= 10, true,
            reason: '${s.name} 规则数量 ${s.rules.length} 超出范围');
      }
    });

    test('所有系统特性数量合理', () {
      for (final s in allSystems) {
        expect(s.features.length >= 1 && s.features.length <= 10, true,
            reason: '${s.name} 特性数量 ${s.features.length} 超出范围');
      }
    });
  });
}