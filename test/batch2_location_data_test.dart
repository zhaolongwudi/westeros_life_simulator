/// Batch 2 测试：地点数据层。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/location_data.dart';

void main() {
  group('地点数据', () {
    test('allLocations 包含 69 个地点', () {
      expect(allLocations.length, 69);
    });

    test('所有地点 ID 唯一', () {
      final ids = allLocations.map((l) => l.id).toSet();
      expect(ids.length, allLocations.length);
    });

    test('所有地点 ID 格式正确（location_ 前缀）', () {
      for (final l in allLocations) {
        expect(l.id.startsWith('location_'), true,
            reason: '${l.id} 不以 location_ 开头');
      }
    });

    test('所有地点字段非空', () {
      for (final l in allLocations) {
        expect(l.id.isNotEmpty, true);
        expect(l.name.isNotEmpty, true);
        expect(l.region.isNotEmpty, true);
      }
    });

    test('locationById 查找成功', () {
      final winterfell = locationById('location_winterfell');
      expect(winterfell, isNotNull);
      expect(winterfell!.name, '临冬城');
    });

    test('locationById 查找失败返回 null', () {
      expect(locationById('location_nonexistent'), isNull);
    });
  });
}