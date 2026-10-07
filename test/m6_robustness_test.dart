/// Batch 10-37 测试：M6 健壮性收官——输入防护 + 护栏契约。
///
/// 覆盖：
/// 1. command_sanitizer：超长截断 / 空与纯符号噪声判定
/// 2. resolveCommand 入口护栏：空输入 / 纯符号 / 超长不崩
/// 3. labels 文案集中层契约：四个标签函数关键值不回归（防绕层）
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/models/event.dart';
import 'package:westeros_life_simulator/models/marital.dart';
import 'package:westeros_life_simulator/models/player.dart';
import 'package:westeros_life_simulator/utils/command_sanitizer.dart';
import 'package:westeros_life_simulator/utils/labels.dart';

void main() {
  group('M6 · sanitizeCommand 超长截断', () {
    test('正常指令原样返回（trim 后）', () {
      expect(sanitizeCommand('  工作  '), '工作');
      expect(sanitizeCommand('帮助'), '帮助');
      expect(sanitizeCommand('训练 sword'), '训练 sword');
    });

    test('超长输入截断到 80 字符', () {
      final long = '工作' + 'x' * 100;
      expect(long.length, 102);
      final out = sanitizeCommand(long);
      expect(out.length, kMaxCommandLength);
      expect(out.substring(0, 2), '工作');
      // 截断后仍含可执行前缀（不破坏首词语义）
      expect(out.startsWith('工作'), true);
    });

    test('恰好 80 字符不截断', () {
      final exact = '训练 ' + 's' * 76; // 3 + 76 = 79？补到 80
      final s = '训练 ' + 's' * 77; // 3 + 77 = 80
      expect(s.length, 80);
      expect(sanitizeCommand(s), s);
      expect(exact.length, 79);
    });
  });

  group('M6 · isCommandNoise 噪声判定', () {
    test('纯噪声返回 true', () {
      expect(isCommandNoise(''), true);
      expect(isCommandNoise('   '), true);
      expect(isCommandNoise('！！！'), true);
      expect(isCommandNoise('***'), true);
      expect(isCommandNoise('---'), true);
      expect(isCommandNoise('...'), true);
      expect(isCommandNoise('😀😀😀'), true);
      expect(isCommandNoise('～～～'), true);
    });

    test('含字母/数字/中文返回 false', () {
      expect(isCommandNoise('工作'), false);
      expect(isCommandNoise('训练 sword'), false);
      expect(isCommandNoise('123'), false);
      expect(isCommandNoise('a'), false);
      expect(isCommandNoise('帮助！'), false);
    });
  });

  group('M6 · resolveCommand 入口护栏', () {
    test('空输入友好提示', () {
      final e = GameEngine()..startNewGame();
      expect(e.resolveCommand('').text, contains('请输入指令'));
      expect(e.resolveCommand('   ').text, contains('请输入指令'));
    });

    test('纯符号输入兜底提示', () {
      final e = GameEngine()..startNewGame();
      final r = e.resolveCommand('！！！');
      expect(r.text, contains('这条指令我看不太懂'));
      expect(r.text, isNot(contains('不是一条你能执行')));
    });

    test('超长输入不崩溃（截断后按正常流程走）', () {
      final e = GameEngine()..startNewGame();
      // 超长且 trim 后仍超长：首词「训练」合法 + 大量尾缀 → 截断到 80 后仍可分发
      final longCmd = '训练 sword ' + 'x' * 100;
      final r = e.resolveCommand(longCmd);
      // 截断后首词是「训练」，应走训练指令（不崩溃）
      expect(r.text, isNotEmpty);
    });

    test('正常指令不受护栏影响', () {
      final e = GameEngine()..startNewGame();
      expect(e.resolveCommand('帮助').text, contains('【可用指令】'));
      expect(e.resolveCommand('状态').text, contains('岁'));
    });
  });

  group('M6 · labels 文案集中层契约', () {
    test('身份/季节/事件/身世关键值不回归', () {
      expect(identityLabel(PlayerIdentity.noble), '贵族');
      expect(identityLabel(PlayerIdentity.wildling), '野人');
      expect(seasonLabel('winter'), '冬天');
      // S4-2：`longwinter` 已清除，老存档残留值走 `_ =>` 兜底不崩。
      expect(seasonShortLabel('longwinter'), 'longwinter');
      expect(eventTypeLabel(EventType.political), '政治');
      expect(spouseOriginLabel(SpouseOrigin.noble), '贵族');
      expect(spouseOriginLabel(SpouseOrigin.warrior), '战士');
    });
  });
}