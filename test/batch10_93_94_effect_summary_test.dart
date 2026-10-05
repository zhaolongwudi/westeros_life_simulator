/// Batch 10-93/94 测试：AI 选项效果摘要补齐 + 被拒键可见化。
///
/// 【10-93 取证：`applyAiChoice` 的效果摘要只输出金币/声望两条】
/// `mixin_ai.applyAiChoice` 在 Batch 9 落成时只写了两条 delta：
/// `💰 金币` 与 `🌟 声望`。而 `applyEffects` 支持的键有六类——
/// gold / reputation / skills.<n> / attributes.<n> / relations.<id> /
/// inventory.<id>。后果：AI 写 `skills.sword: 1` 落盘后玩家在回合
/// 文本里**看不到任何反馈**（技能确实涨了，但要自己开面板核对）；
/// AI 写 `inventory.item_bread: 2` 同理。而 10-89~92 又在写侧加了
/// 四道白名单守卫，被拒的键是彻底静默的——于是「叙事里写着提利昂
/// 好感 +10、状态却毫无变化」这类脱节对玩家**零感知**。
///
/// 【本批两处修法】
///  - **10-93 摘要补齐**：按 `before`/`after` 求真实 delta，补
///    skills/attributes/relations/inventory 四类摘要行，标签全部走
///    中文（`skillLabel`/`attributeLabel`/`npcById`/`itemName`）。
///  - **10-94 被拒键可见**：`GameStateProvider.applyEffects` 把被
///    守卫跳过的键登记进 `lastRejectedEffectKeys`，`applyAiChoice`
///    据此输出一行提示。
///
/// 【为什么按 before/after 求差而不是直接读 choice.effects】
/// 真实 delta 才是玩家关心的：`skills.sword: -5` 被 `max(0, ...)`
/// 破底、`relations.*` 被 ±100 钳制、`inventory.item_x: -9` 背包里
/// 只有 2 件——读 effects 会给出与实际落盘不符的数字。且写侧守卫
/// 静默跳过的幽灵键在求差时天然不显示，无需在摘要侧复刻白名单
/// 判定（避免两处规则漂移）。
///
/// 【与 10-87 的口径一致：摘要里不泄漏英文 id】
/// 10-87 已把 prompt 背包段改为「中文名 + 数量」并断言
/// `isNot(contains('item_bread'))`。本批摘要同样只出中文名
/// （`itemName`/`npcById` 的兜底是 id 本身，仅在数据异常时出现），
/// 不补 `[id=...]`。
///
/// 【断言写法：中文锚点照抄实际输出的全角标点（坑 51）】
/// 摘要行的数值后缀是全角括号，如 `⚔️ 剑术 +1（4）`——断言里
/// 必须写全角 `（）`，不能写成半角。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/game_engine.dart';
import 'package:westeros_life_simulator/models/event.dart';
import 'package:westeros_life_simulator/providers/game_state_provider.dart';

/// 造一个 AI 选项（effects 走裸 Map，与 `applyAiChoice` 契约一致）。
EventChoice _aiChoice(Map<String, int> effects, {String narrative = ''}) =>
    EventChoice(
      id: 'ai_choice_93_94',
      text: '测试行动',
      requirements: const <String, int>{},
      effects: effects,
      narrative: narrative,
    );

void main() {
  group('Batch 10-93 applyAiChoice 效果摘要补齐', () {
    test('技能 delta 出中文标签行（⚔️ 剑术 +1（4））', () {
      final engine = GameEngine()..startNewGame();
      final before = engine.player.skills['sword'] ?? 0;
      final result = engine.applyAiChoice(_aiChoice(<String, int>{
        'skills.sword': 1,
      }));
      expect(result, contains('⚔️ 剑术 +1（${before + 1}）'));
    });

    test('属性 delta 出中文标签行（🛡️ 力量 +2）', () {
      final engine = GameEngine()..startNewGame();
      final before = engine.player.attributes['strength'] ?? 0;
      final result = engine.applyAiChoice(_aiChoice(<String, int>{
        'attributes.strength': 2,
      }));
      expect(result, contains('🛡️ 力量 +2（${before + 2}）'));
    });

    test('关系 delta 出 NPC 中文名（🤝 提利昂·兰尼斯特 +10）', () {
      final engine = GameEngine()..startNewGame();
      final result = engine.applyAiChoice(_aiChoice(<String, int>{
        'relations.npc_tyrion': 10,
      }));
      expect(result, contains('🤝 提利昂·兰尼斯特 +10（10）'));
    });

    test('物品 delta 出中文名（🎒 黑面包 +2）', () {
      final engine = GameEngine()..startNewGame();
      final result = engine.applyAiChoice(_aiChoice(<String, int>{
        'inventory.item_bread': 2,
      }));
      expect(result, contains('🎒 黑面包 +2'));
    });

    test('负向 delta 带负号（🤝 提利昂·兰尼斯特 -5）', () {
      final engine = GameEngine()..startNewGame();
      engine.applyAiChoice(_aiChoice(<String, int>{
        'relations.npc_tyrion': 20,
      }));
      final result = engine.applyAiChoice(_aiChoice(<String, int>{
        'relations.npc_tyrion': -5,
      }));
      expect(result, contains('🤝 提利昂·兰尼斯特 -5（15）'));
    });

    test('按真实 delta 求值：破底/钳制后摘要与落盘一致', () {
      final engine = GameEngine()..startNewGame();
      // 技能为 0 时 -5 被 max(0, ...) 破底，摘要不应显示 -5。
      final result = engine.applyAiChoice(_aiChoice(<String, int>{
        'skills.alchemy': -5,
      }));
      expect(engine.player.skills['alchemy'], 0);
      expect(result, isNot(contains('炼金 -5')));
    });

    test('幽灵键不产生摘要行（被 10-91/92 守卫拦下即无反馈）', () {
      final engine = GameEngine()..startNewGame();
      final result = engine.applyAiChoice(_aiChoice(<String, int>{
        'skills.hacking': 5,
        'attributes.luck': 5,
        'inventory.item_dragon_scale': 3,
      }));
      expect(result, isNot(contains('hacking')));
      expect(result, isNot(contains('luck')));
      expect(result, isNot(contains('龙鳞')));
    });

    test('摘要不出英文 id（与 10-87 口径一致）', () {
      final engine = GameEngine()..startNewGame();
      final result = engine.applyAiChoice(_aiChoice(<String, int>{
        'inventory.item_bread': 2,
        'relations.npc_tyrion': 10,
      }));
      expect(result, isNot(contains('item_bread')));
      expect(result, isNot(contains('npc_tyrion')));
    });

    test('无变化时不输出空摘要行（只有月度推进文本）', () {
      final engine = GameEngine()..startNewGame();
      final result = engine.applyAiChoice(_aiChoice(const <String, int>{}));
      expect(result, isNot(contains('⚔️')));
      expect(result, isNot(contains('🛡️')));
      expect(result, isNot(contains('🤝')));
      expect(result, isNot(contains('🎒')));
      expect(result, contains('时间推进'));
    });
  });

  group('Batch 10-94 被拒效果键可见化', () {
    test('applyEffects 把守卫拒绝的键登记进 lastRejectedEffectKeys', () {
      final provider = GameStateProvider();
      provider.applyEffects(
        provider.player,
        const <String, int>{
          'skills.hacking': 3,
          'inventory.item_dragon_scale': 2,
          'attributes.luck': 1,
        },
      );
      expect(
        provider.lastRejectedEffectKeys,
        <String>[
          'skills.hacking',
          'inventory.item_dragon_scale',
          'attributes.luck',
        ],
      );
    });

    test('合法键不登记（lastRejectedEffectKeys 为空）', () {
      final provider = GameStateProvider();
      provider.applyEffects(
        provider.player,
        const <String, int>{
          'skills.sword': 1,
          'attributes.strength': 1,
          'inventory.item_bread': 1,
        },
      );
      expect(provider.lastRejectedEffectKeys, isEmpty);
    });

    test('拒绝记录不跨回合残留（下一次调用清空）', () {
      final provider = GameStateProvider();
      provider.applyEffects(
        provider.player,
        const <String, int>{'skills.hacking': 3},
      );
      expect(provider.lastRejectedEffectKeys, isNotEmpty);
      provider.applyEffects(
        provider.player,
        const <String, int>{'skills.sword': 1},
      );
      expect(provider.lastRejectedEffectKeys, isEmpty);
    });

    test('未知顶层键不登记（沿用静默忽略语义）', () {
      final provider = GameStateProvider();
      provider.applyEffects(
        provider.player,
        const <String, int>{'title_grant': 1},
      );
      expect(provider.lastRejectedEffectKeys, isEmpty);
    });

    test('合法键与被拒键混合时，只登记被拒的那个', () {
      final provider = GameStateProvider();
      provider.applyEffects(
        provider.player,
        const <String, int>{
          'skills.sword': 1,
          'skills.hacking': 3,
        },
      );
      expect(provider.lastRejectedEffectKeys, <String>['skills.hacking']);
      expect(provider.player.skills['sword'], 4);
    });

    test('applyAiChoice 把被拒键输出成提示行', () {
      final engine = GameEngine()..startNewGame();
      final result = engine.applyAiChoice(_aiChoice(<String, int>{
        'skills.hacking': 3,
      }));
      expect(result, contains('1 项效果未生效：skills.hacking'));
    });

    test('无被拒键时不输出提示行', () {
      final engine = GameEngine()..startNewGame();
      final result = engine.applyAiChoice(_aiChoice(<String, int>{
        'skills.sword': 1,
      }));
      expect(result, isNot(contains('未生效')));
    });

    test('合法效果与提示行共存（金币摘要 + 被拒提示）', () {
      final engine = GameEngine()..startNewGame();
      final result = engine.applyAiChoice(_aiChoice(<String, int>{
        'gold': 50,
        'skills.hacking': 2,
      }));
      expect(result, contains('金币 +50'));
      expect(result, contains('1 项效果未生效：skills.hacking'));
    });
  });
}