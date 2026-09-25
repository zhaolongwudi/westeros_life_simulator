/// Batch 2 测试：事件数据层。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/event_data.dart';
import 'package:westeros_life_simulator/models/event.dart';

void main() {
  group('事件数据', () {
    test('allEvents 包含 60 个事件', () {
      expect(allEvents.length, 60);
    });

    test('所有事件 ID 唯一', () {
      final ids = allEvents.map((e) => e.id).toSet();
      expect(ids.length, allEvents.length);
    });

    test('所有事件 ID 格式正确（event_ 前缀）', () {
      for (final e in allEvents) {
        expect(e.id.startsWith('event_'), true,
            reason: '${e.id} 不以 event_ 开头');
      }
    });

    test('所有事件字段非空', () {
      for (final e in allEvents) {
        expect(e.id.isNotEmpty, true);
        expect(e.name.isNotEmpty, true);
        expect(e.description.isNotEmpty, true);
        expect(e.narrative.isNotEmpty, true);
        expect(e.choices.length >= 2, true,
            reason: '${e.name} 选项少于 2 个');
        expect(e.choices.length <= 5, true,
            reason: '${e.name} 选项多于 5 个');
      }
    });

    test('eventById 查找成功', () {
      final kingDeath = eventById('event_king_death');
      expect(kingDeath, isNotNull);
      expect(kingDeath!.name, '国王死亡');
      expect(kingDeath.type, EventType.political);
    });

    test('eventById 查找失败返回 null', () {
      expect(eventById('event_nonexistent'), isNull);
    });

    test('政治事件数量正确', () {
      final political = eventsByType(EventType.political);
      expect(political.length, 10);
    });

    test('家族事件数量正确', () {
      final family = eventsByType(EventType.family);
      expect(family.length, 10);
    });

    test('战争事件数量正确', () {
      final war = eventsByType(EventType.war);
      expect(war.length, 5);
    });

    test('宗教事件数量正确', () {
      final religious = eventsByType(EventType.religious);
      expect(religious.length, 5);
    });

    test('经济事件数量正确', () {
      final economic = eventsByType(EventType.economic);
      expect(economic.length, 8);
    });

    test('魔法事件数量正确', () {
      final magical = eventsByType(EventType.magical);
      expect(magical.length, 6);
    });

    test('日常生活事件数量正确', () {
      final daily = eventsByType(EventType.daily);
      expect(daily.length, 6);
    });

    test('冒险事件数量正确', () {
      final adventure = eventsByType(EventType.adventure);
      expect(adventure.length, 5);
    });

    test('超自然事件数量正确', () {
      final supernatural = eventsByType(EventType.supernatural);
      expect(supernatural.length, 5);
    });

    test('所有事件选项 ID 唯一', () {
      for (final e in allEvents) {
        final choiceIds = e.choices.map((c) => c.id).toSet();
        expect(choiceIds.length, e.choices.length,
            reason: '${e.name} 选项 ID 重复');
      }
    });

    test('所有事件选项字段非空', () {
      for (final e in allEvents) {
        for (final c in e.choices) {
          expect(c.id.isNotEmpty, true);
          expect(c.text.isNotEmpty, true);
          expect(c.narrative.isNotEmpty, true);
        }
      }
    });
  });
}