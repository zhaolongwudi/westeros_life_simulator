/// Batch 2 测试：家族数据层。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/family_data.dart';
import 'package:westeros_life_simulator/models/family.dart';

void main() {
  group('家族数据', () {
    test('allFamilies 包含 27 个家族', () {
      expect(allFamilies.length, 27);
    });

    test('所有家族 ID 唯一', () {
      final ids = allFamilies.map((f) => f.id).toSet();
      expect(ids.length, allFamilies.length);
    });

    test('所有家族 ID 格式正确（family_ 前缀）', () {
      for (final f in allFamilies) {
        expect(f.id.startsWith('family_'), true,
            reason: '${f.id} 不以 family_ 开头');
      }
    });

    test('所有家族字段非空', () {
      for (final f in allFamilies) {
        expect(f.id.isNotEmpty, true);
        expect(f.name.isNotEmpty, true);
        expect(f.motto.isNotEmpty, true);
        expect(f.seat.isNotEmpty, true);
        expect(f.population > 0, true, reason: '${f.name} 人口为 0');
        expect(f.influence >= 0 && f.influence <= 100, true,
            reason: '${f.name} 影响力超出范围');
      }
    });

    test('familyById 查找成功', () {
      final stark = familyById('family_stark');
      expect(stark, isNotNull);
      expect(stark!.name, '史塔克');
      expect(stark.motto, '凛冬将至');
    });

    test('familyById 查找失败返回 null', () {
      expect(familyById('family_nonexistent'), isNull);
    });

    test('大家族数量正确', () {
      final great = allFamilies.where((f) => f.scale == FamilyScale.great).length;
      expect(great, greaterThan(5));
    });

    test('小家族数量正确', () {
      final minor = allFamilies.where((f) => f.scale == FamilyScale.minor).length;
      expect(minor, greaterThan(5));
    });

    test('家族关系对称性检查（部分）', () {
      final stark = familyById('family_stark')!;
      final lannister = familyById('family_lannister')!;
      // 史塔克对兰尼斯特是负关系
      expect(stark.relations['family_lannister'], isNegative);
      // 兰尼斯特对史塔克也是负关系
      expect(lannister.relations['family_stark'], isNegative);
    });

    test('家族秘密非空（主要家族）', () {
      final stark = familyById('family_stark')!;
      expect(stark.secrets.length, greaterThan(0));
      final lannister = familyById('family_lannister')!;
      expect(lannister.secrets.length, greaterThan(0));
    });

    test('家族特质非空', () {
      for (final f in allFamilies) {
        expect(f.traits.length, greaterThan(0),
            reason: '${f.name} 特质为空');
      }
    });
  });
}