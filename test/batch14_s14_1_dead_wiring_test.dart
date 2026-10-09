/// S14-1 复现测试：「数值收口」设计写了但从未接线（balance_data 的孤儿常量）。
///
/// 【本批修的是什么 —— 又一类「摆设」】
///
/// `lib/data/balance_data.dart` 文件头明写约定：
/// > 「原散落在 mixin 里的魔法数字统一收口到这里，各 mixin 的 `static const`
/// >  保留原名并转发到本文件（const 引用 const 是编译期常量），
/// >  因此**既有测试与调用点零改动**。」
///
/// 但实测（node 全量扫描 `balance_data.dart` 的 172 个 `static const`）：
/// **21 个常量在 `lib/` 除本文件外零引用**。它们不是「历史遗留的重复定义」，
/// 而是**声明了、注释也写了、却没有任何代码读它**——
/// 真实的开局值以字面量形式写在别处，改平衡时改这个常量**不会有任何效果**。
/// 这与 S12-12（`stealth` 只加进 `defaultPlayer` 而生产开局走向导）、
/// S13-13 ⑨ 属**同一类缺陷**：改了一半的接线。
///
/// 【逐条取证（本文件每条断言都对应一处实测）】
///
/// | 常量 | 声明处写的语义 | 真实生效的值在哪 | 症状 |
/// |---|---|---|---|
/// | `defaultGold = 100` | 开局金币 | `player.dart` `gold: 100` 字面量 | 改常量无效 |
/// | `defaultReputation = 50` | 开局声望 | `player.dart` `reputation: 50` 字面量 | 改常量无效 |
/// | `defaultAge = 18` | 开局年龄 | `player.dart` + `start_screen.dart` **两处** `age: 18` | 改常量无效 |
/// | `starvingHunger = 0` | 注释写「饱食初始值」 | 真实开局是 **60** | 注释与语义相反 |
/// | `generationRecordCap = 20` | 谱系记录环形上限（防存档膨胀） | `mixin_generation` **只 add 不裁** | 上限根本没生效 |
/// | `kAiPromptEventFloor = 3` | 强相关事件不足时兜底注入下限 | `event_prompt_filter` **无兜底分支** | 下限根本没生效 |
/// | `kAiScoreIdentity = 2` | 身份命中评分 | `_eventRelevanceScore` **无 identity 分支** | 身份门槛事件不参与排序 |
///
/// 【设计取舍：接线而非删常量】
/// `balance_data.dart` 是本项目**数值唯一真相**（CODE_MAP 明写「调平衡不再全库
/// grep」）。故采**接线**：把真实字面量改为引用常量，让常量**真的成为唯一真相**。
/// - `generationRecordCap`：声明了「环形上限」却没裁 ⇒ 改为真裁剪（保留最近
///   N 条），否则存档随世代线性膨胀，与 `kHistoryLimit` 环形截断的先例一致。
/// - `kAiPromptEventFloor`：`event_prompt_filter.dart:39-41` 那句「无回退兜底，
///   是刻意的」针对的是**门槛过滤**（不能把不可能事件塞回 prompt）；而「预算
///   不足时至少给 N 条」是另一回事 ⇒ 本批补兜底分支。
/// - `kAiScoreIdentity`：`eventTriggersSatisfied` 支持 `identity` 门槛
///   （`event_trigger_eval.dart:72`），且事件库确有该门槛，但评分器漏了
///   这个维度 ⇒ 补分支。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/balance_data.dart';
import 'package:westeros_life_simulator/data/event_data.dart';
import 'package:westeros_life_simulator/models/event.dart';
import 'package:westeros_life_simulator/models/player.dart';
import 'package:westeros_life_simulator/screens/start_screen.dart';
import 'package:westeros_life_simulator/services/event_prompt_filter.dart';

/// 构造一个只用于探针的最小事件（全部必填字段给安全默认值）。
GameEvent _probeEvent(String id, String name, Map<String, String> cond) {
  return GameEvent(
    id: id,
    name: name,
    type: EventType.daily,
    description: '探针事件',
    triggerConditions: cond,
    choices: const <EventChoice>[],
    narrative: '探针',
    tags: const <String>[],
    isOneTime: false,
  );
}

void main() {
  group('S14-1 开局数值收口（defaultGold / defaultReputation / defaultAge）', () {
    test('Player.defaultPlayer 的三项开局值等于 balance_data 常量', () {
      final p = Player.defaultPlayer();
      expect(p.gold, BalanceData.defaultGold);
      expect(p.reputation, BalanceData.defaultReputation);
      expect(p.age, BalanceData.defaultAge);
    });

    test('向导开局 buildSetupPlayer 的年龄等于 balance_data 常量', () {
      // 生产开局走的是向导（`start_screen.dart`），不是 `defaultPlayer`。
      final p = buildSetupPlayer(
        const GameSetup(
          name: '测试',
          gender: 'male',
          identity: PlayerIdentity.commoner,
          familyId: 'family_stark',
          locationId: 'location_winterfell',
          era: '篡夺者战争后',
          season: 'spring',
          year: 1,
          month: 1,
        ),
      );
      expect(p.age, BalanceData.defaultAge);
    });

    test('玩家源码引用常量而非裸字面量（接线判别式）', () {
      // 判别式：**改常量必须有效果**。修复前 `player.dart` 与
      // `start_screen.dart` 各写死字面量，改 BalanceData 不会有任何变化。
      final playerSrc = File('lib/models/player.dart').readAsStringSync();
      expect(
        playerSrc.contains('BalanceData.defaultGold'),
        isTrue,
        reason: 'player.dart 仍写死 gold 字面量，改 BalanceData.defaultGold 无效',
      );
      expect(
        playerSrc.contains('BalanceData.defaultReputation'),
        isTrue,
        reason: 'player.dart 仍写死 reputation 字面量',
      );
      expect(
        playerSrc.contains('BalanceData.defaultAge'),
        isTrue,
        reason: 'player.dart 仍写死 age 字面量',
      );

      final setupSrc = File('lib/screens/start_screen.dart').readAsStringSync();
      expect(
        setupSrc.contains('BalanceData.defaultAge'),
        isTrue,
        reason: 'start_screen.dart 的 age: 18 仍写死字面量',
      );
    });
  });

  group('S14-1 starvingHunger 注释与语义相反', () {
    test('开局饱食为 60，且不等于 starvingHunger', () {
      // 修复前：`starvingHunger = 0` 且注释写「饱食初始值（0 = 最饿）」，
      // 而真实开局值是 60（S13-13 ⑱ 刚把构造器默认从 0 改成 60）⇒
      // **常量名与注释都在描述一个已不存在的开局状态**。
      final p = Player.defaultPlayer();
      expect(p.hunger, 60);
      expect(p.hunger, isNot(BalanceData.starvingHunger),
          reason: '若开局饱食仍等于 starvingHunger，说明默认值回退了');
    });
  });

  group('S14-1 generationRecordCap 声明了上限却没裁剪', () {
    test('源码中存在按上限裁剪谱系记录的逻辑（接线判别式）', () {
      // 修复前 `mixin_generation` 只 `prevRecords.add(...)`，
      // **没有任何截断** ⇒ 传承 N 次就存 N 条，存档线性膨胀。
      final src = File('lib/mixins/mixin_generation.dart').readAsStringSync();
      expect(
        src.contains('BalanceData.generationRecordCap'),
        isTrue,
        reason: 'mixin_generation 未引用 generationRecordCap，谱系记录无上限',
      );
      expect(
        src.contains('sublist') || src.contains('removeRange') || src.contains('skip('),
        isTrue,
        reason: 'mixin_generation 有 add 但无任何截断调用',
      );
    });

    test('裁剪语义：超过上限时只保留最近 N 条', () {
      expect(BalanceData.generationRecordCap, greaterThan(0));
      // 纯集合运算复现「应有」的行为，不依赖引擎随机性。
      var records = <String>[];
      for (var i = 0; i < 30; i++) {
        records = <String>[...records, '第${i + 1}代'];
        if (records.length > BalanceData.generationRecordCap) {
          records =
              records.sublist(records.length - BalanceData.generationRecordCap);
        }
      }
      expect(records.length, BalanceData.generationRecordCap);
      expect(records.first, '第11代');
      expect(records.last, '第30代');
    });
  });

  group('S14-1 kAiScoreIdentity：identity 门槛未参与 prompt 排序', () {
    test('前提：事件库确有 identity 门槛事件', () {
      final withIdentity =
          allEvents.where((e) => e.triggerConditions.containsKey('identity')).toList();
      expect(withIdentity, isNotEmpty,
          reason: '前提失效：若已无 identity 门槛事件，本项无需接线');
    });

    test('判别式：identity 命中事件因评分被排到前面', () {
      // 修复前 `_eventRelevanceScore` 无 identity 分支，identity 命中与否
      // 不影响排序。构造 13 个事件（**必须超过预算 12 才进入打分+截断路径**；
      // 否则 `selectEventsForPrompt` 提前返回原序，评分器根本不会执行）：
      // 12 个「无任何门槛条件」的事件（identity 维度得 0 分）+ 1 个
      // identity 命中的事件放在**末尾下标**。若评分器忽略 identity，
      // 所有事件同分（0），排序只由下标决定 ⇒ 命中事件留在末尾。
      final player = Player.defaultPlayer(); // identity = noble
      final list = <GameEvent>[
        for (var i = 0; i < BalanceData.kAiPromptEventBudget; i++)
          _probeEvent('probe_empty_$i', '探针-无门槛-$i',
              const <String, String>{}),
        _probeEvent('probe_noble', '探针-identity-noble',
            const <String, String>{'identity': 'noble'}),
      ];
      expect(list.length, greaterThan(BalanceData.kAiPromptEventBudget),
          reason: '前提失效：事件数未超过预算，selectEventsForPrompt 不进入排序路径');
      final selected = selectEventsForPrompt(
        list,
        player: player,
        season: 'spring',
      );
      expect(selected.first.name, '探针-identity-noble',
          reason: 'identity 命中的事件必须因 kAiScoreIdentity 被排到最前');
      expect(selected, contains('探针-无门槛-0'),
          reason: '身份不相关事件仍在结果里（identity 维度只影响排序，不过滤）');
    });

    test('评分器源码引用 kAiScoreIdentity（接线判别式）', () {
      final src = File('lib/services/event_prompt_filter.dart').readAsStringSync();
      expect(src.contains('BalanceData.kAiScoreIdentity'), isTrue,
          reason: 'event_prompt_filter 未引用 kAiScoreIdentity，身份维度未参与排序');
      expect(src.contains("cond['identity']"), isTrue,
          reason: '评分器从未读取 identity 门槛键');
    });
  });

  group('S14-1 kAiPromptEventFloor：预算截断无下限兜底', () {
    test('源码中存在下限兜底分支（接线判别式）', () {
      final src = File('lib/services/event_prompt_filter.dart').readAsStringSync();
      expect(src.contains('BalanceData.kAiPromptEventFloor'), isTrue,
          reason: 'event_prompt_filter 未引用 kAiPromptEventFloor，兜底下限未实现');
    });

    test('兜底下限不超过预算上限（前提自洽）', () {
      expect(BalanceData.kAiPromptEventFloor,
          lessThanOrEqualTo(BalanceData.kAiPromptEventBudget));
      expect(BalanceData.kAiPromptEventBudget, greaterThan(0));
      expect(BalanceData.kAiPromptEventFloor, greaterThan(0));
    });
  });
}