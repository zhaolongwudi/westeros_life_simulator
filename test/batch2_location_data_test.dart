/// Batch 2 测试：地点数据层。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/location_data.dart';

void main() {
  group('地点数据', () {
    test('allLocations 包含 70 个地点', () {
      // S1-1 遗留补齐：新增守夜人黑城堡 location_castle_black_nightswatch，69 → 70。
      expect(allLocations.length, 70);
    });

    test('守夜人黑城堡是独立条目，且不改动被占用的 location_castle_black', () {
      // 背景：`location_castle_black` 的 id 意为黑城堡，实际内容却是恐怖堡
      // （波顿领地）。为不破坏旧存档的 locationId，新增独立 id 承接黑城堡。
      final castleBlack = locationById('location_castle_black_nightswatch');
      expect(castleBlack, isNotNull);
      expect(castleBlack!.name, '黑城堡');
      expect(castleBlack.region, '北境');

      final occupied = locationById('location_castle_black');
      expect(occupied, isNotNull);
      expect(occupied!.name, '恐怖堡',
          reason: 'location_castle_black 的语义已锁定为恐怖堡（S1-1）');
    });

    test('长城沿线四据点齐全', () {
      const wallLine = <String>[
        'location_the_wall',
        'location_castle_black_nightswatch',
        'location_eastwatch',
        'location_shadow_tower',
      ];
      for (final id in wallLine) {
        expect(locationById(id), isNotNull, reason: '$id 应存在');
      }
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