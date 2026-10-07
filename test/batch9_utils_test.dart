/// Batch 9 测试：utils/ 工具目录。
///
/// 覆盖：身份/季节/事件类型中文标签、时间/数字格式化。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/models/event.dart';
import 'package:westeros_life_simulator/models/player.dart';
import 'package:westeros_life_simulator/utils/labels.dart';
import 'package:westeros_life_simulator/utils/text_formats.dart';

void main() {
  group('Batch 9 中文标签', () {
    test('身份标签', () {
      expect(identityLabel(PlayerIdentity.noble), '贵族');
      expect(identityLabel(PlayerIdentity.commoner), '平民');
      expect(identityLabel(PlayerIdentity.soldier), '士兵');
      expect(identityLabel(PlayerIdentity.merchant), '商人');
      expect(identityLabel(PlayerIdentity.priest), '神职人员');
      expect(identityLabel(PlayerIdentity.scholar), '学者');
      expect(identityLabel(PlayerIdentity.adventurer), '冒险者');
      expect(identityLabel(PlayerIdentity.assassin), '刺客');
      expect(identityLabel(PlayerIdentity.maester), '学士');
      expect(identityLabel(PlayerIdentity.wildling), '野人');
      // 全枚举覆盖
      expect(PlayerIdentity.values.length, 10);
    });

    test('季节标签', () {
      expect(seasonLabel('spring'), '春天');
      expect(seasonLabel('summer'), '夏天');
      expect(seasonLabel('autumn'), '秋天');
      expect(seasonLabel('winter'), '冬天');
      expect(seasonLabel('unknown'), 'unknown');
      // S4-2：`longwinter` 已从引擎清除。升级前的存档可能仍带该值，
      // 必须走 `_ =>` 兜底原样返回（不崩、不返回 null）。
      expect(seasonLabel('longwinter'), 'longwinter');
    });

    test('季节短标签（状态条用）', () {
      expect(seasonShortLabel('spring'), '春');
      expect(seasonShortLabel('summer'), '夏');
      expect(seasonShortLabel('autumn'), '秋');
      expect(seasonShortLabel('winter'), '冬');
      expect(seasonShortLabel('longwinter'), 'longwinter');
    });

    test('事件类型标签', () {
      expect(eventTypeLabel(EventType.political), '政治');
      expect(eventTypeLabel(EventType.family), '家族');
      expect(eventTypeLabel(EventType.war), '战争');
      expect(eventTypeLabel(EventType.religious), '宗教');
      expect(eventTypeLabel(EventType.economic), '经济');
      expect(eventTypeLabel(EventType.magical), '魔法');
      expect(eventTypeLabel(EventType.daily), '日常');
      expect(eventTypeLabel(EventType.adventure), '冒险');
      expect(eventTypeLabel(EventType.supernatural), '超自然');
    });
  });

  group('Batch 9 文本格式化', () {
    test('formatDateTime 正常格式化', () {
      // ISO 带时区（UTC+8 本地化结果）
      final iso = '2026-09-25T12:34:00.000';
      final out = formatDateTime(iso);
      // 至少包含日期与时间数字
      expect(out, contains('2026'));
      expect(out, contains(':'));
    });

    test('formatDateTime 非法输入原样返回', () {
      expect(formatDateTime('not-a-date'), 'not-a-date');
    });

    test('pad2 补零', () {
      expect(pad2(1), '01');
      expect(pad2(9), '09');
      expect(pad2(10), '10');
      expect(pad2(2026), '2026');
    });

    test('clampInt 区间限制', () {
      expect(clampInt(50), 50);
      expect(clampInt(-5), 0);
      expect(clampInt(150), 100);
      expect(clampInt(10, min: -20, max: 20), 10);
      expect(clampInt(-30, min: -20, max: 20), -20);
    });

    test('joinAnd 顿号连接', () {
      expect(joinAnd(<String>['a', 'b', 'c']), 'a、b、c');
      expect(joinAnd(<String>['only']), 'only');
      expect(joinAnd(<String>[]), '');
    });
  });
}