/// Batch 10-120 测试：探索/遭遇概率带收口 + prompt 技能键口径（S2-4 / P2-04 / P2-08）。
///
/// 1. `mixin_adventure` 的概率带（0.4 / 0.62 / 0.85 / 危险度×0.12 / 0.35 …）
///    原为裸数字，本批收口进 `BalanceData`，照 Batch 10-114 的模式配契约测试。
/// 2. prompt 的技能键清单原只列 5 键，而白名单放行 13 键——AI 永远无法
///    合法使用另外 8 键；现由 `kPlayerSkillKeys` + `skillLabel` 现场生成。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/balance_data.dart';
import 'package:westeros_life_simulator/services/ai_service.dart';
import 'package:westeros_life_simulator/utils/labels.dart';

/// 去掉注释后的源码（用于扫裸数字）。
String _stripComments(String src) {
  final noBlock = src.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
  return noBlock.split('\n').map((l) {
    final i = l.indexOf('//');
    return i < 0 ? l : l.substring(0, i);
  }).join('\n');
}

void main() {
  group('Batch 10-120 概率常量就位', () {
    test('探索分档与遭遇概率值正确', () {
      expect(BalanceData.exploreGoldBand, 0.4);
      expect(BalanceData.exploreItemBand, 0.62);
      expect(BalanceData.exploreEncounterBand, 0.85);
      expect(BalanceData.encounterChancePerDanger, 0.12);
      expect(BalanceData.encounterBanditBand, 0.35);
      expect(BalanceData.encounterBeastBand, 0.7);
      expect(BalanceData.encounterMerchantBand, 0.85);
      expect(BalanceData.banditRepelChance, 0.5);
      expect(BalanceData.beastEscapeChance, 0.6);
      expect(BalanceData.beastInjuryChance, 0.3);
      expect(BalanceData.merchantHaggleChance, 0.4);
      expect(BalanceData.supernaturalEncounterChance, 0.1);
      expect(BalanceData.exploreItemDropGate, 0.6);
    });

    test('分档单调递增且落在 (0,1)', () {
      final bands = <double>[
        BalanceData.exploreGoldBand,
        BalanceData.exploreItemBand,
        BalanceData.exploreEncounterBand,
      ];
      for (var i = 1; i < bands.length; i++) {
        expect(bands[i], greaterThan(bands[i - 1]));
      }
      for (final b in bands) {
        expect(b, inInclusiveRange(0.0, 1.0));
      }
    });

    test('mixin_adventure 不再有裸的概率数字', () {
      final src = _stripComments(
        File('lib/mixins/mixin_adventure.dart').readAsStringSync(),
      );
      final hits = RegExp(r'(?<![\w.])0\.\d+')
          .allMatches(src)
          .map((m) => m.group(0))
          .toList();
      expect(hits, isEmpty,
          reason: '概率应全部取自 BalanceData，残留裸数字：$hits');
    });
  });

  group('Batch 10-120 prompt 技能键口径', () {
    test('prompt 列出全部 13 个合法技能键', () {
      final prompt = AiService.systemPrompt;
      expect(prompt, isNotEmpty);
      expect(prompt, contains('技能±1~3，属性±1~3'),
          reason: 'S2-4：口径统一为 ±1~3，原 systemPrompt 写「属性+1~2」');
      for (final key in BalanceData.kPlayerSkillKeys) {
        expect(skillLabel(key), isNot(key),
            reason: '$key 应有中文标签，否则 prompt 里是无意义裸键');
      }
      expect(BalanceData.kPlayerSkillKeys.length, 13);
    });
  });
}
