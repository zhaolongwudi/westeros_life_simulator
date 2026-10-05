/// Batch 10-103/104 测试：事件触发门槛契约（内容侧 + 双通道收口）。
///
/// 覆盖本批修掉的三个真缺陷：
///
/// ① **41/72 事件的门槛全是死键**（10-103 内容侧）
///    `event_data` 曾有 36 类门槛键（`kingAge`/`courtTension`/`warStatus`/
///    `familyTension`…）从未被任何通道识别。`canTrigger` 是 16 个 `if`
///    串联、无 `else` 兜底 → 全部落空 → 这 41 个事件恒返回 true，
///    等于永久无条件。10-103 清空（零行为变更，本就是 no-op）。
///    护栏：**全量 72 事件的门槛键零死键**（新增门槛键必须被识别，
///    否则该事件会静默变成无条件）。
///
/// ② **`season: 'any'` 恒 false**（10-103 真 bug，非 no-op）
///    `event_festival`（节日）写 `{'season': 'any'}`，而旧
///    `canTrigger` 是 `season != value` → 任何季节都恒 false → 该事件
///    **永远不出现**；`event_prompt_filter` 却把 `'any'` 当命中 →
///    AI 看得见、玩家看不到。10-103 清空该门槛，10-104 让 `'any'`
///    成为显式支持的取值。
///
/// ③ **双通道门槛漂移**（10-104 代码侧）
///    `EventProvider.canTrigger` 与 `EventService.checkTriggerConditions`
///    各写一份实现。已发生四次同类事故（10-90/95/99/101/102）。
///    本批抽 `core/event_trigger_eval.dart` 单一真相，两通道委托。
///    护栏：**两通道对同一条件集判定必须一致**（防第五次漂移）。
///
/// 【刻意保留的既有语义，勿下轮「顺手改」】
/// - **未知门槛键放行**：不改成拒收。`GameEvent.fromJson` 会把旧存档里的
///   自定义门槛原样恢复，改成拒收会让升级后老存档的事件集体失效。
/// - **season 传 null = 不放行（fail-closed）**：沿用 `canTrigger` 原
///   行为。生产两个调用方都传真实季节；取 fail-open 只会让「忘记传季节」
///   的调用方 bug 静默变成「门槛全放行」，掩盖而非暴露问题。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/core/event_trigger_eval.dart';
import 'package:westeros_life_simulator/data/event_data.dart';
import 'package:westeros_life_simulator/models/event.dart';
import 'package:westeros_life_simulator/models/player.dart';
import 'package:westeros_life_simulator/providers/event_provider.dart';
import 'package:westeros_life_simulator/services/event_service.dart';

/// `canTrigger` / `checkTriggerConditions` 能识别的全部门槛键 + 前缀。
/// 与 `core/event_trigger_eval.dart` 的判定分支一一对应。
const _supportedKeys = <String>{
  'locationId', 'season', 'familyId', 'identity',
  'minAge', 'maxAge', 'minGold', 'minReputation',
  'minHealth', 'maxHealth', 'minEnergy', 'maxEnergy',
  'minHunger', 'maxHunger', 'flag', 'noFlag', 'isAlive',
};
const _supportedPrefixes = <String>['hasItem.', 'skills.', 'attributes.'];

bool _isSupported(String key) {
  if (_supportedKeys.contains(key)) return true;
  return _supportedPrefixes.any((p) => key.startsWith(p));
}

/// 构造测试事件。[oneTime] 为真时事件一次性（供 canTrigger 的 isOneTime 分支）。
GameEvent _ev(String id, Map<String, String> conds, {bool oneTime = false}) {
  return GameEvent(
    id: id,
    name: '测试$id',
    type: EventType.daily,
    description: '测试',
    triggerConditions: conds,
    choices: const [],
    narrative: '测试',
    tags: const ['test'],
    isOneTime: oneTime,
  );
}

void main() {
  group('Batch 10-103 内容侧：门槛键零死键', () {
    test('全量 72 事件的触发门槛键全部被引擎识别', () {
      final dead = <String>[];
      for (final e in allEvents) {
        for (final k in e.triggerConditions.keys) {
          if (!_isSupported(k)) dead.add('${e.id}: $k');
        }
      }
      expect(
        dead,
        isEmpty,
        reason: '以下门槛键从未被 canTrigger/checkTriggerConditions 识别，'
            '会让事件恒为无条件（或恒不可触发）：\n${dead.join('\n')}',
      );
    });

    test('全量 72 事件不再含 season: any（10-103 已清空）', () {
      // 保留护栏：'any' 现在被引擎显式支持（10-104），但内容数据不再使用它
      // ——门槛清空与「支持 any」等价，而空门槛不会让事件面板显示误导性文案。
      for (final e in allEvents) {
        expect(
          e.triggerConditions['season'],
          isNot('any'),
          reason: '事件 ${e.id} 仍用 season:any，清空为 {} 语义更明确',
        );
      }
    });

    test('事件总量未变（72），且 ID 唯一', () {
      expect(allEvents.length, 72);
      expect(allEvents.map((e) => e.id).toSet().length, 72);
    });

    test('清空门槛的 41 个事件仍保留选项与叙事', () {
      // 删门槛不能顺手删内容——这些事件仍是玩法内容。
      // 清单 = 10-103 取证的 41 个纯死键事件（逐个实证，非凭印象）。
      const clearedIds = <String>[
        'event_king_death', 'event_rebellion', 'event_coup',
        'event_small_council', 'event_hand_change', 'event_high_septon_change',
        'event_maester_change', 'event_castle_black_change',
        'event_iron_bank_crisis', 'event_free_cities_war',
        'event_family_marriage', 'event_family_succession',
        'event_family_intrigue', 'event_family_secret', 'event_family_curse',
        'event_family_prophecy', 'event_family_relic', 'event_family_bloodline',
        'event_family_grudge', 'event_family_extinction', 'event_battle',
        'event_siege', 'event_betrayal', 'event_assassination',
        'event_trial_by_combat', 'event_religious_trial', 'event_miracle',
        'event_heresy', 'event_church_split',
        'event_high_septon_change_religious',
        'event_trade_boom', 'event_trade_crisis', 'event_iron_bank_debt',
        'event_dragon_appears', 'event_white_walkers', 'event_prophecy',
        'event_blood_magic', 'event_green_seer', 'event_wedding',
        'event_funeral', 'event_tournament',
      ];
      expect(clearedIds.length, 41);
      expect(clearedIds.toSet().length, 41, reason: '清单内不得有重复 id');
      for (final id in clearedIds) {
        final e = eventById(id);
        expect(e, isNotNull, reason: '事件 $id 不应被删掉');
        expect(e!.triggerConditions, isEmpty, reason: '$id 门槛应已清空');
        expect(e.choices, isNotEmpty, reason: '$id 不得变成零选项事件');
        expect(e.narrative.isNotEmpty, true, reason: '$id 叙事不得为空');
      }
    });
  });

  group('Batch 10-103/104 节日回归（season:any 曾恒不可触发）', () {
    test('event_festival 门槛已清空', () {
      expect(eventById('event_festival')!.triggerConditions, isEmpty);
    });

    test('节日在四季全部可触发（修复前恒 false）', () {
      final provider = EventProvider(events: allEvents);
      final e = eventById('event_festival')!;
      for (final s in <String>['spring', 'summer', 'autumn', 'winter']) {
        expect(
          provider.canTrigger(e, Player.defaultPlayer(), season: s),
          true,
          reason: '节日应在 $s 可触发（修复前 season:any 恒判 false）',
        );
      }
    });

    test('季节日仍在对应季节可触发（未误伤真门槛）', () {
      final provider = EventProvider(events: allEvents);
      final e = eventById('event_winter_sickness')!;
      expect(provider.canTrigger(e, Player.defaultPlayer(), season: 'winter'), true);
      expect(provider.canTrigger(e, Player.defaultPlayer(), season: 'summer'), false);
    });

    test('seasonMatches: any 恒真、null 季节不放行', () {
      expect(seasonMatches('any', 'winter'), true);
      expect(seasonMatches('any', null), true);
      expect(seasonMatches('winter', 'winter'), true);
      expect(seasonMatches('winter', 'summer'), false);
      // 调用方未告知季节 → 无法确认 → 不放行（fail-closed）
      expect(seasonMatches('winter', null), false);
    });
  });

  group('Batch 10-104 双通道判定一致', () {
    final provider = EventProvider(events: allEvents);
    const service = EventService();
    final player = Player.defaultPlayer();

    /// 两个玩家样本，扩大条件命中面。
    final rich = player.copyWith(gold: 999, energy: 99, health: 99, age: 70);
    final poor = player.copyWith(gold: 1, energy: 5, health: 5, age: 12);

    test('两通道对全量 72 事件（四季 × 两玩家）判定一致', () {
      final mismatches = <String>[];
      for (final e in allEvents) {
        for (final s in <String>['spring', 'summer', 'autumn', 'winter']) {
          for (final p in <Player>[player, rich, poor]) {
            final a = provider.canTrigger(e, p, season: s);
            // EventService 的 context 通道就是把 season 传进去的正规途径
            final b = service.checkTriggerConditions(
              e,
              p,
              <String, String>{'season': s},
            );
            if (a != b) {
              mismatches.add('${e.id} season=$s canTrigger=$a service=$b');
            }
          }
        }
      }
      expect(
        mismatches,
        isEmpty,
        reason: '两通道门槛判定必须一致（防 10-90/95/99/101/102 型漂移）：\n'
            '${mismatches.join('\n')}',
      );
    });

    test('两通道对人工构造的各类门槛判定一致', () {
      final cases = <Map<String, String>>[
        <String, String>{},
        <String, String>{'season': 'winter'},
        <String, String>{'minGold': '100'},
        <String, String>{'minGold': '999999'},
        <String, String>{'minAge': '50'},
        <String, String>{'maxAge': '10'},
        <String, String>{'minHealth': '50'},
        <String, String>{'minEnergy': '50'},
        <String, String>{'flag': 'isInjured'},
        <String, String>{'noFlag': 'isInjured'},
        <String, String>{'isAlive': 'true'},
        <String, String>{'skills.sword': '3'},
        <String, String>{'attributes.strength': '3'},
        <String, String>{'hasItem.item_bread': '1'},
        <String, String>{'hasItem.item_bread': '99'},
        <String, String>{'locationId': 'location_winterfell'},
        // 未知门槛键：两通道都必须放行（10-104 刻意语义）
        <String, String>{'someFutureKey': 'whatever'},
      ];
      final mismatches = <String>[];
      for (final c in cases) {
        final e = _ev('probe', c);
        for (final s in <String>['spring', 'winter']) {
          for (final p in <Player>[player, rich, poor]) {
            final a = provider.canTrigger(e, p, season: s);
            final b = service.checkTriggerConditions(
              e,
              p,
              <String, String>{'season': s},
            );
            if (a != b) {
              mismatches.add('$c season=$s canTrigger=$a service=$b');
            }
          }
        }
      }
      expect(mismatches, isEmpty, reason: mismatches.join('\n'));
    });

    test('season: any 在 context 覆盖层下仍恒真（通配语义优先级）', () {
      // 这是本模块自己的一个潜在 bug：若 `'any'` 的判定排在 context 之后，
      // `context['season']='winter'` 会与 value `'any'` 直接比较 → 恒 false，
      // 等于把 10-103 修掉的「节日永不触发」bug 换个入口引回来。
      final e = _ev('anyprobe', <String, String>{'season': 'any'});
      for (final ctx in <Map<String, String>>[
        <String, String>{},
        <String, String>{'season': 'winter'},
        <String, String>{'season': 'summer'},
      ]) {
        expect(
          service.checkTriggerConditions(e, player, ctx),
          true,
          reason: 'season:any 不应被 context 季节覆盖：$ctx',
        );
      }
      // canTrigger 侧同样恒真
      final provider2 = EventProvider(events: <GameEvent>[e]);
      for (final s in <String?>['spring', 'summer', 'autumn', 'winter', null]) {
        expect(
          provider2.canTrigger(e, player, season: s),
          true,
          reason: 'season:any 在 season=$s 下应放行',
        );
      }
    });

    test('非数字门槛值不再抛异常（int.parse → tryParse）', () {
      // 旧实现 int.parse('abc') 直接抛 FormatException；脏存档会崩游戏。
      final e = _ev('dirty', <String, String>{'minGold': 'abc'});
      expect(provider.canTrigger(e, player, season: 'winter'), true);
      expect(
        service.checkTriggerConditions(e, player, <String, String>{'season': 'winter'}),
        true,
      );
    });

    test('EventService 的 context 覆盖层仍生效（Batch 3 既有契约）', () {
      final e = _ev('ctx', <String, String>{'season': 'winter'});
      expect(
        service.checkTriggerConditions(e, player, <String, String>{'season': 'summer'}),
        false,
      );
      expect(
        service.checkTriggerConditions(e, player, const <String, String>{}),
        false,
        reason: 'context 无 season 时季节门槛不放行（fail-closed，与 10-104 一致）',
      );
    });
  });

  group('Batch 10-104 单一真相不变量', () {
    test('canTrigger 只保留 provider 私有的 isOneTime 校验', () {
      // 一次性事件完成后不可再触发——这是 provider 私有状态，
      // 不能被抽进单一真相（纯函数拿不到 _completedEventIds）。
      final provider = EventProvider(events: allEvents);
      final e = _ev('once', const <String, String>{}, oneTime: true);
      expect(provider.canTrigger(e, Player.defaultPlayer()), true);
      provider.markCompleted(e.id);
      expect(provider.canTrigger(e, Player.defaultPlayer()), false);
    });

    test('全库不再存在第二份门槛判定实现', () {
      // 若有人再往 canTrigger / checkTriggerConditions 里写分支判定，
      // 这条会红（event_provider 与 event_service 只应委托 core）。
      final core = _readLib('core/event_trigger_eval.dart');
      final providerSrc = _readLib('providers/event_provider.dart');
      final serviceSrc = _readLib('services/event_service.dart');
      expect(core.contains('bool eventTriggersSatisfied'), true);
      expect(providerSrc.contains('eventTriggersSatisfied('), true);
      expect(serviceSrc.contains('eventTriggersSatisfied('), true);
      // 委托后 provider 里不应再有逐键 if 判定
      expect(providerSrc.contains("key.startsWith('hasItem.')"), false,
          reason: 'canTrigger 已委托，逐键判定应只存在于 core');
      expect(serviceSrc.contains("key.startsWith('hasItem.')"), false,
          reason: 'checkTriggerConditions 已委托，逐键判定应只存在于 core');
    });
  });
}

/// 读 lib 下源码（仅用于源码级不变量断言）。
String _readLib(String rel) {
  // dart:io 在 flutter_test 环境可用。
  return File('lib/$rel').readAsStringSync();
}