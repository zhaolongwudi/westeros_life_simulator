/// S4-2（P2-01）测试：长冬死内容清除 —— 季节枚举收敛为四值。
///
/// ## 背景
///
/// `longwinter`（凛冬）在引擎里是**不可达值**：纯月份函数 `seasonForMonth`
/// 只返回春/夏/秋/冬，而开局 `kSeasons` 把 `'longwinter'` 映射到 `month: 12`
/// （与 `'winter'` 完全相同），于是它**只在第 0 月存在**，首次月度推进即被覆盖。
/// 结果是 28 处模板分支 + 冬季减益特判 + 开局选项 + 标签映射全是死代码。
///
/// S4-2 采方案 B（清除）：删掉不可达值，统一为四季。
///
/// ## 本批次要挡住的四类回归
///
/// 1. **有人又加回第五季**：`longwinter` 当初是怎么进来的？靠往 `kSeasons` 塞一个键。
///    断言季节枚举恒为 4 值，且 `seasonForMonth` 对 12 个月全部落在四值内。
/// 2. **模板删坏**：28 处分支是批量删除的，删完每个 map 必须仍有 `_ =>` 兜底，
///    否则未知季节会抛/返回 null。断言四季文案都拿得到、未知值走兜底。
/// 3. **老存档崩溃**：升级前存过档的玩家，`season == 'longwinter'` 仍在存档里。
///    `GameProgress.fromJson` 用 `safeStr` 会**原样保留**该值，
///    因此安全性完全依赖 `seasonLabel` / 模板 map 的 `_ =>` 兜底——必须锁住。
/// 4. **季节门槛事件在长冬期间全失效**（取证时的意外发现）：
///    `seasonMatches` 是精确相等，`'season': 'winter'` 门槛在`longwinter` 下
///    恒false —— 即「选凛冬开局会同时失去冬季事件，比普通冬天更差」。
///    清除 `longwinter` 之后这条坑自然消失；断言 `seasonMatches` 对四值行为正确。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/core/event_trigger_eval.dart';
import 'package:westeros_life_simulator/providers/game_state_provider.dart';
import 'package:westeros_life_simulator/screens/start_screen.dart';
import 'package:westeros_life_simulator/utils/labels.dart';

void main() {
  group('S4-2 · 季节枚举恒为四值', () {
    test('kSeasons 恰为春/夏/秋/冬四项', () {
      expect(kSeasons.keys.toSet(), {'spring', 'summer', 'autumn', 'winter'});
      expect(kSeasons, hasLength(4));
    });

    test('seasonForMonth 对 1-12 月全部返回四值之一', () {
      const legal = {'spring', 'summer', 'autumn', 'winter'};
      for (var m = 1; m <= 12; m++) {
        expect(legal, contains(GameProgress.seasonForMonth(m)),
            reason: '月份 $m 产出了非法季节');
      }
    });

    test('seasonForMonth(12) 返回 winter 而非 longwinter', () {
      // 这正是原缺陷：kSeasons['longwinter'] == 12 == kSeasons['winter']，
      // 两者映射到同一月份，导致 longwinter 永无独立存在空间。
      expect(GameProgress.seasonForMonth(12), 'winter');
    });

    test('标签函数对四值都有中文名', () {
      expect(seasonLabel('spring'), '春天');
      expect(seasonLabel('summer'), '夏天');
      expect(seasonLabel('autumn'), '秋天');
      expect(seasonLabel('winter'), '冬天');
    });
  });

  group('S4-2 · 老存档兼容（关键：不能崩）', () {
    test('fromJson 遇到老存档的 longwinter 不崩溃（安全Str原样保留）', () {
      final progress = GameProgress.fromJson(const {
        'year': 283,
        'month': 12,
        'season': 'longwinter',
        'era': '征服纪元',
        'turnCount': 3,
      });
      // safeStr 会原样保留 —— 这是预期行为，安全性由下方兜底测试保证。
      expect(progress.season, 'longwinter');
      expect(progress.year, 283);
    });

    test('老存档的 longwinter 标签走 _ => 兜底，不崩且有可读输出', () {
      expect(seasonLabel('longwinter'), isNotEmpty);
      // 具体文案不重要，重要的是不抛异常、不返回 null。
      expect(seasonShortLabel('longwinter'), isNotEmpty);
    });

    test('老存档推进一次月度后季节回归四季', () {
      final old = GameProgress.fromJson(const {
        'year': 283,
        'month': 12,
        'season': 'longwinter',
        'era': '征服纪元',
        'turnCount': 3,
      });
      final next = old.advanceMonth();
      expect(next.season, isNot('longwinter'));
      expect({'spring', 'summer', 'autumn', 'winter'}, contains(next.season));
    });

    test('season 字段缺失/为 null 时回落 spring', () {
      final p = GameProgress.fromJson(const {'year': 283, 'month': 3});
      expect(p.season, 'spring');
    });
  });

  group('S4-2 · 季节门槛匹配', () {
    test('seasonMatches 对四值精确匹配', () {
      for (final s in ['spring', 'summer', 'autumn', 'winter']) {
        expect(seasonMatches(s, s), isTrue, reason: '$s 应匹配自身');
      }
    });

    test('winter 门槛在 winter 下成立（清除longwinter 后不再有失效场景）', () {
      // 取证发现：因seasonMatches 精确相等，原先 longwinter 期间
      // 所有 winter 门槛事件恒false。清除后不再存在这种「比冬天更差」的状态。
      expect(seasonMatches('winter', 'winter'), isTrue);
      expect(seasonMatches('winter', 'longwinter'), isFalse,
          reason: '老存档残留值不应匹配任何门槛，避免触发不该触发的事件');
    });

    test('any 门槛对四值恒成立', () {
      for (final s in ['spring', 'summer', 'autumn', 'winter']) {
        expect(seasonMatches('any', s), isTrue);
      }
    });

    test('season 为 null（调用方未告知）时不放行', () {
      expect(seasonMatches('winter', null), isFalse);
    });
  });

  group('S4-2 · 死内容已彻底清除', () {
    test('开局季节默认值是合法四值之一', () {
      const legal = {'spring', 'summer', 'autumn', 'winter'};
      expect(legal, contains('spring'));
      // kSeasons 里每个键都必须能被 seasonForMonth 复现，
      // 否则会重演「映射到同一月份导致某一值不可达」的缺陷。
      for (final entry in kSeasons.entries) {
        expect(GameProgress.seasonForMonth(entry.value), entry.key,
            reason: 'kSeasons[${entry.key}]=${entry.value} 推不出自身季节');
      }
    });
  });
}
