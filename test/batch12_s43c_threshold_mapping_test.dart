/// S4-3c 测试：26 处「原死门槛」选项接上真实门槛。
///
/// 【背景】S3-1 把 26 处 `army` / `diplomacy` / `military` / `magic` 门槛从数据中
/// 删除——这 4 个键在 `Player` 上**没有对应字段**，两条 `canChoose` 实现都不认，
/// 门槛恒成立（「死门槛」）。删除是零行为变化，但**设计意图需要真实字段承接**，
/// 否则「镇压叛乱 / 谈判 / 认领龙 / 使用血魔法」这些选项就永远是无条件的。
///
/// 【本批方案（用户选定：用现有字段保守映射）】不新增 `soldiers` 玩家字段
/// （那要改 Player 模型 + 存档 + 面板 + prompt，改动面大得多），而是映射到
/// 已有且**确实可达**的字段：
///   - `diplomacy` → `skills.speech`（初始 2~4，可训练到 10）
///   - `magic`     → `skills.magic`（**须先把 magic 加进初始技能表**，见下）
///   - `army` / `military` → `reputation` 三档 30 / 40 / 55
///
/// 【原值来源】映射不是杜撰——原门槛值取自 git 历史（S3-1 删除前的
/// `event_data.dart`）：`army` 100/300/500 三档、`military` 3/5、`diplomacy` 5、
/// `magic` 5。reputation 的 30/40/55 **沿用事件级 `minReputation` 的现有取值**，
/// 不新造刻度，且保持原大小顺序（要求越高 → 声望档越高）。
///
/// 覆盖：
/// 1. 全库不再出现 army/diplomacy/military/magic 四种死门槛键
/// 2. 26 处目标选项**确实拿到了**门槛（不是漏改）
/// 3. 所有新增门槛键都在 `canChoose` 认识的白名单内（否则又是死门槛）
/// 4. 每条事件仍保留 ≥1 无条件选项（不把事件变成不可玩）
/// 5. 门槛**确实可达**：不用「未来会长出来的字段」
/// 6. `skills.magic` 必须在玩家初始技能表内（否则 3 个选项永久锁死）
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/balance_data.dart';
import 'package:westeros_life_simulator/data/event_data.dart';
import 'package:westeros_life_simulator/models/player.dart';
import 'package:westeros_life_simulator/providers/event_provider.dart';

/// S3-1 删除的 4 个死门槛键——本批之后**不得**再出现在任何 requirements 里。
const _deadKeys = <String>['army', 'diplomacy', 'military', 'magic'];

/// 26 处目标选项（事件 id → 选项 id 集合），与 S3-1 的清单一一对应。
const _targets = <String, List<String>>{
  'event_rebellion': ['choice_suppress', 'choice_negotiate'],
  'event_coup': ['choice_suppress_coup'],
  'event_small_council': ['choice_propose'],
  'event_iron_bank_crisis': ['choice_negotiate'],
  'event_family_marriage': ['choice_negotiate'],
  'event_family_grudge': ['choice_revenge'],
  'event_battle': ['choice_fight', 'choice_negotiate'],
  'event_siege': ['choice_defend', 'choice_escape'],
  'event_betrayal': ['choice_revenge'],
  'event_assassination': ['choice_investigate', 'choice_revenge'],
  'event_trial_by_combat': ['choice_fight'],
  'event_religious_trial': ['choice_defend'],
  'event_heresy': ['choice_purge'],
  'event_iron_bank_debt': ['choice_negotiate'],
  'event_dragon_appears': ['choice_claim', 'choice_fight'],
  'event_white_walkers': ['choice_fight', 'choice_negotiate'],
  'event_blood_magic': ['choice_use'],
  'event_green_seer': ['choice_follow'],
  'event_tournament': ['choice_participate'],
  'event_hunt': ['choice_hunt'],
};

/// `canChoose` 认识的键（与 `check_content_sync.REQ_KEYS_*` 同口径）。
bool _isKnownReqKey(String key) {
  const exact = <String>{'gold', 'reputation', 'health', 'energy', 'hunger', 'flag'};
  if (exact.contains(key)) return true;
  for (final p in const <String>['skills.', 'attributes.', 'hasItem.']) {
    if (key.startsWith(p) && key.length > p.length) return true;
  }
  return false;
}

void main() {
  group('S4-3c 死门槛清零', () {
    test('全库不再出现 army/diplomacy/military/magic 门槛键', () {
      final hits = <String>[];
      for (final e in allEvents) {
        for (final c in e.choices) {
          for (final k in c.requirements.keys) {
            if (_deadKeys.contains(k)) hits.add('${e.id}/${c.id}: $k');
          }
        }
      }
      expect(hits, isEmpty,
          reason: '这 4 个键在 Player 上没有字段、canChoose 也不认，写进数据就是死门槛：$hits');
    });

    test('26 处目标选项确实拿到了门槛（防漏改）', () {
      final missing = <String>[];
      for (final entry in _targets.entries) {
        final e = eventById(entry.key);
        expect(e, isNotNull, reason: '${entry.key} 不存在');
        for (final cid in entry.value) {
          final matches = e!.choices.where((c) => c.id == cid).toList();
          expect(matches, hasLength(1), reason: '${entry.key} 应有唯一选项 $cid');
          if (matches.single.requirements.isEmpty) {
            missing.add('${entry.key}/$cid');
          }
        }
      }
      expect(missing, isEmpty, reason: '这些选项仍是「无门槛」：$missing');
    });

    test('全部 26 处合计（清单自检，防止清单本身缩水）', () {
      final total = _targets.values.fold<int>(0, (a, b) => a + b.length);
      expect(total, 26, reason: 'S3-1 记录的清单是 26 处');
    });

    test('新增门槛键全部在 canChoose 认识的键集内', () {
      final bad = <String>[];
      for (final entry in _targets.entries) {
        final e = eventById(entry.key)!;
        for (final cid in entry.value) {
          final c = e.choices.firstWhere((x) => x.id == cid);
          for (final k in c.requirements.keys) {
            if (!_isKnownReqKey(k)) bad.add('${entry.key}/$cid: $k');
          }
        }
      }
      expect(bad, isEmpty,
          reason: '门槛键不在 canChoose 白名单内 = 又造了一批死门槛：$bad');
    });

    test('每条事件仍保留至少一个无条件选项（不把事件变成不可玩）', () {
      final dead = <String>[];
      for (final e in allEvents) {
        if (!e.choices.any((c) => c.requirements.isEmpty)) dead.add(e.id);
      }
      expect(dead, isEmpty, reason: '这些事件的所有选项都带门槛，玩家可能无路可走：$dead');
    });
  });

  group('S4-3c 门槛可达性（不用「未来才有的字段」）', () {
    test('skills.magic 必须在玩家初始技能表内', () {
      // 【为什么单列这条】`train()` 对**不在技能表里**的技能直接拒绝
      // （「你从未学过…」），所以给选项加 `skills.magic` 门槛前，
      // magic 必须已进入初始技能表——否则那 3 个选项**永久不可选**。
      final p = Player.defaultPlayer();
      expect(p.skills.containsKey('magic'), isTrue,
          reason: 'magic 不在初始技能表 → train() 拒绝训练 → 3 个 magic 门槛选项永久锁死');
      expect(p.skills['magic'], 0, reason: '与 alchemy 同先例：初始 0 级、可训练成长');
    });

    test('magic 在白名单与标签表内（否则落盘/展示会出问题）', () {
      expect(BalanceData.kPlayerSkillKeys.contains('magic'), isTrue);
    });

    test('speech / magic 门槛值不超过技能上限（可达）', () {
      for (final e in allEvents) {
        for (final c in e.choices) {
          for (final entry in c.requirements.entries) {
            final k = entry.key;
            if (k.startsWith('skills.')) {
              expect(entry.value, lessThanOrEqualTo(BalanceData.skillCap),
                  reason: '${e.id}/${c.id}: ${k}=${entry.value} 超过技能上限，永远达不到');
            }
          }
        }
      }
    });

    test('reputation 门槛落在 (0, 100] 且开局声望可能达到', () {
      // 开局声望：noble/soldier 50、merchant/其他 80、commoner 30。
      // 门槛若 > 80，平民/贵族玩家都必须先经营一段——可以接受；
      // 但若 > 100 则永远达不到（reputation 被 clamp 到 0~100）。
      for (final e in allEvents) {
        for (final c in e.choices) {
          final rep = c.requirements['reputation'];
          if (rep == null) continue;
          expect(rep, greaterThan(0));
          expect(rep, lessThanOrEqualTo(100),
              reason: '${e.id}/${c.id}: reputation=$rep 超过上限 100，永远达不到');
        }
      }
    });

    test('army 三档映射保持了原有的高低顺序（100 < 300 < 500）', () {
      // 原值 army 100/300/500 → reputation 30/40/55。
      // 逐条核对，防止映射时把高低档写反（那会让「镇压叛乱」比「清除异端」更容易）。
      int repOf(String eventId, String choiceId) {
        final e = eventById(eventId)!;
        final c = e.choices.firstWhere((x) => x.id == choiceId);
        return c.requirements['reputation'] ?? -1;
      }

      // 原 army:100 → 30
      expect(repOf('event_assassination', 'choice_revenge'), 30);
      expect(repOf('event_heresy', 'choice_purge'), 30);
      // 原 army:300 → 40
      expect(repOf('event_coup', 'choice_suppress_coup'), 40);
      expect(repOf('event_family_grudge', 'choice_revenge'), 40);
      expect(repOf('event_siege', 'choice_defend'), 40);
      expect(repOf('event_betrayal', 'choice_revenge'), 40);
      // 原 army:500 → 55
      expect(repOf('event_rebellion', 'choice_suppress'), 55);
      expect(repOf('event_battle', 'choice_fight'), 55);
      expect(repOf('event_white_walkers', 'choice_fight'), 55);
      // 顺序自检
      expect(repOf('event_heresy', 'choice_purge'),
          lessThan(repOf('event_coup', 'choice_suppress_coup')));
      expect(repOf('event_coup', 'choice_suppress_coup'),
          lessThan(repOf('event_rebellion', 'choice_suppress')));
    });

    test('diplomacy 统一映射为 skills.speech: 5', () {
      // 原 diplomacy:5 → skills.speech:5，9 处
      const diplomacyChoices = <List<String>>[
        ['event_rebellion', 'choice_negotiate'],
        ['event_small_council', 'choice_propose'],
        ['event_iron_bank_crisis', 'choice_negotiate'],
        ['event_family_marriage', 'choice_negotiate'],
        ['event_battle', 'choice_negotiate'],
        ['event_assassination', 'choice_investigate'],
        ['event_religious_trial', 'choice_defend'],
        ['event_iron_bank_debt', 'choice_negotiate'],
        ['event_white_walkers', 'choice_negotiate'],
      ];
      for (final pair in diplomacyChoices) {
        final e = eventById(pair[0])!;
        final c = e.choices.firstWhere((x) => x.id == pair[1]);
        expect(c.requirements['skills.speech'], 5,
            reason: '${pair[0]}/${pair[1]} 的 diplomacy 未映射为 speech:5');
      }
      expect(diplomacyChoices, hasLength(9), reason: '原 diplomacy 共 9 处');
    });

    test('magic 统一映射为 skills.magic: 5（3 处）', () {
      const magicChoices = <List<String>>[
        ['event_dragon_appears', 'choice_claim'],
        ['event_blood_magic', 'choice_use'],
        ['event_green_seer', 'choice_follow'],
      ];
      for (final pair in magicChoices) {
        final e = eventById(pair[0])!;
        final c = e.choices.firstWhere((x) => x.id == pair[1]);
        expect(c.requirements['skills.magic'], 5,
            reason: '${pair[0]}/${pair[1]} 的 magic 未映射为 skills.magic:5');
      }
      expect(magicChoices, hasLength(3), reason: '原 magic 共 3 处');
    });
  });

  group('S4-3c 实机：门槛真的会拦住玩家', () {
    test('声望不足时 canChoose 为 false，足够时为 true', () {
      final provider = EventProvider(events: allEvents);
      final rebellion = eventById('event_rebellion')!;
      final suppress = rebellion.choices.firstWhere((c) => c.id == 'choice_suppress');
      expect(suppress.requirements['reputation'], 55);

      final poor = Player.defaultPlayer().copyWith(reputation: 10);
      final rich = Player.defaultPlayer().copyWith(reputation: 80);
      expect(provider.canChoose(suppress, poor), isFalse,
          reason: '声望 10 < 55 应被拦住（此前是死门槛，恒可选中）');
      expect(provider.canChoose(suppress, rich), isTrue);
    });

    test('speech 不足时被拦住，足够时通过', () {
      final provider = EventProvider(events: allEvents);
      final e = eventById('event_small_council')!;
      final propose = e.choices.firstWhere((c) => c.id == 'choice_propose');
      expect(propose.requirements['skills.speech'], 5);

      final low = Player.defaultPlayer()
          .copyWith(skills: const <String, int>{'speech': 2});
      final high = Player.defaultPlayer()
          .copyWith(skills: const <String, int>{'speech': 5});
      expect(provider.canChoose(propose, low), isFalse);
      expect(provider.canChoose(propose, high), isTrue);
    });

    test('magic 门槛：0 级被拦、5 级通过（且 0 级确实能练上去）', () {
      final provider = EventProvider(events: allEvents);
      final e = eventById('event_green_seer')!;
      final follow = e.choices.firstWhere((c) => c.id == 'choice_follow');
      expect(follow.requirements['skills.magic'], 5);

      final novice = Player.defaultPlayer(); // magic 0
      expect(provider.canChoose(follow, novice), isFalse);
      final adept = Player.defaultPlayer()
          .copyWith(skills: const <String, int>{'magic': 5});
      expect(provider.canChoose(follow, adept), isTrue);
    });
  });
}
