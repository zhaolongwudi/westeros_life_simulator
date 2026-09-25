/// NPC 深度交互混入（Batch 10-13）。
///
/// 在既有 NPC 数据（36 NPC + relations）之上提供：
/// - 关系等级（敌对/陌生/相识/熟识/信任/挚友）
/// - 深度互动：按关系等级解锁 寒暄/倾诉/请求/秘密/结盟
/// - 示好送礼：每日限次，提升好感
/// - 好感度事件链：关系突破阈值触发专属剧情（一次性 flag）
library;

import '../models/npc.dart';
import '../providers/game_provider_base.dart';
import 'mixin_life.dart';

/// NPC 深度交互混入。挂在 [GameProviderBase] 上，依赖 [GameLifeMixin]
/// （使用 addItem/combatPower 等生存与战斗能力）。
mixin GameNpcInteractMixin on GameProviderBase, GameLifeMixin {
  /// 示好每日次数上限。
  static const int kFavorDailyLimit = 3;

  Map<String, int> _favorDailyCount = <String, int>{};
  String? _favorDailyMonth;

  String get _npcToday => '${progress.year}-${progress.month}';

  void _rollFavorDaily() {
    if (_favorDailyMonth != _npcToday) {
      _favorDailyMonth = _npcToday;
      _favorDailyCount = <String, int>{};
    }
  }

  bool _canFavor() {
    _rollFavorDaily();
    final total = _favorDailyCount.values.fold(0, (a, b) => a + b);
    return total < kFavorDailyLimit;
  }

  void _recordFavor() {
    _rollFavorDaily();
    _favorDailyCount['favor'] = (_favorDailyCount['favor'] ?? 0) + 1;
  }

  /// 关系等级中文标签（按关系值 -100~100）。
  String npcRelationLabel(int relation) {
    if (relation <= -20) return '敌对';
    if (relation < 20) return '陌生';
    if (relation < 40) return '相识';
    if (relation < 60) return '熟识';
    if (relation < 80) return '信任';
    return '挚友';
  }

  /// 玩家与某 NPC 的关系值。
  int npcRelation(String npcId) => player.relations[npcId] ?? 0;

  /// 在场 NPC 互动列表（含关系等级）。
  List<String> npcInteractionList() {
    final list = <String>[];
    for (final n in npcsAtCurrentLocation) {
      final rel = npcRelation(n.id);
      list.add('· ${n.name}（${npcRelationLabel(rel)}，关系 $rel）');
    }
    return list;
  }

  /// 与在场 NPC 深度互动（按关系等级解锁内容）。
  ///
  /// 敌对→冷眼；陌生→寒暄；相识→倾诉；熟识→请求；
  /// 信任→秘密；挚友→结盟。返回叙事文本。
  String npcInteract(String npcId) {
    final npc = npcById(npcId);
    if (npc == null) return '没有叫「$npcId」的人。';
    if (!npc.isAlive) return '${npc.name}已经不在人世了。';
    if (npc.locationId != player.locationId) {
      return '${npc.name}不在这里。';
    }
    final rel = npcRelation(npc.id);

    if (rel <= -20) {
      return '${npc.name}看见你便沉下脸，握紧了武器。你们之间横着旧账，不是几句话能揭过去的。';
    }
    if (rel < 20) {
      return '你与${npc.name}寒暄了几句。他/她客气地点点头，保持着礼貌的距离。';
    }
    if (rel < 40) {
      final topic = npc.goals.isNotEmpty ? npc.goals.first : npc.fears.first;
      return '${npc.name}向你倾诉：「最近总想着「$topic」。」你认真听着，他/她的目光柔和了些。';
    }
    if (rel < 60) {
      return _npcRequestAt(npc, rel);
    }
    if (rel < 80) {
      if (npc.secrets.isNotEmpty) {
        adjustRelation(npc.id, 3);
        return '🍂 ${npc.name}压低声音：「我可以信任你——」一个秘密浮出水面：${npc.secrets.first}。关系 +3。';
      }
      adjustRelation(npc.id, 2);
      return '${npc.name}与你共饮，谈起过往与来路，毫不避讳。关系 +2。';
    }
    // 挚友：结盟
    adjustRelation(npc.id, 2);
    adjustReputation(2);
    return '⚔️ ${npc.name}拍着你的肩膀：「只要我活着，就是你的人。」你们结为挚友。声望 +2，关系 +2。';
  }

  /// 熟识（40~59）关系的 NPC 请求：按 NPC 类型给出护送/结盟/合作等。
  String _npcRequestAt(Npc npc, int rel) {
    final rnd = rng();
    switch (npc.type) {
      case NpcType.noble:
        if (rel >= 50 && rnd.nextDouble() < 0.5) {
          adjustReputation(4);
          return '🏛️ ${npc.name}把你引荐给封臣们，谈起你的名字时语气郑重。你感到自己的地位在上升。声望 +4。';
        }
        adjustRelation(npc.id, 2);
        return '🏰 ${npc.name}向你请教对时局的看法。你说得有理有据，他/她频频点头。关系 +2。';
      case NpcType.soldier:
      case NpcType.adventurer:
        final fee = 15 + rel + rnd.nextInt(10);
        gainGold(fee);
        adjustReputation(2);
        return '🛡️ ${npc.name}请你护送一件要事：「事成之后，$fee 金币不会少你的。」你答应了。报酬 $fee 金币，声望 +2。';
      case NpcType.merchant:
        final profit = 10 + rel ~/ 2 + rnd.nextInt(10);
        gainGold(profit);
        adjustRelation(npc.id, 2);
        return '💰 ${npc.name}想与你合股走一趟商路：「本钱我出，你出人脉。」第一笔红利 $profit 金币到手。关系 +2。';
      case NpcType.priest:
        adjustHealth(5);
        adjustRelation(npc.id, 3);
        return '⛪ ${npc.name}为你向七神祈祷，洒下圣水：「愿诸神护佑你的路。」你感到心神安泰。健康 +5，关系 +3。';
      case NpcType.scholar:
      case NpcType.maester:
        if (npc.skills.isNotEmpty && rnd.nextDouble() < 0.4) {
          final skill = npc.skills.keys.first;
          final newSkills = Map<String, int>.from(player.skills);
          newSkills[skill] = (newSkills[skill] ?? 0) + 1;
          updatePlayer(player.copyWith(skills: newSkills));
          return '📜 ${npc.name}递给你一卷羊皮纸：「读读这个。」你学到了一些${skill}心得（$skill +1）。';
        }
        adjustRelation(npc.id, 2);
        return '📖 ${npc.name}与你畅谈历史与学问，你听得津津有味。关系 +2。';
      case NpcType.assassin:
        if (rel >= 50) {
          final fee = 20 + rel + rnd.nextInt(15);
          gainGold(fee);
          return '🗡️ ${npc.name}交给你一个信封：「有笔生意，办成了这 $fee 金币归你。」你接下委托。';
        }
        return '🌑 ${npc.name}在阴影里打量着你：「还不是时候。等你更可信一些，再说。」';
      case NpcType.wildling:
      case NpcType.commoner:
        gainGold(5);
        adjustReputation(2);
        return '🔥 ${npc.name}请你为村落说句话。你出面周旋，村民感激不尽。+5 金币谢礼，声望 +2。';
      case NpcType.supernatural:
        adjustReputation(3);
        return '🌫️ ${npc.name}低语着不属于这个时代的词句。你感到命运之线被轻轻拨动。声望 +3。';
    }
  }

  /// 向在场 NPC 示好（送礼/深谈），提升好感。
  ///
  /// 每日限 [kFavorDailyLimit] 次；随关系升高礼金递减，口才加成好感。
  String npcFavor(String npcId) {
    final npc = npcById(npcId);
    if (npc == null) return '没有叫「$npcId」的人。';
    if (!npc.isAlive) return '${npc.name}已经不在了。';
    if (npc.locationId != player.locationId) {
      return '${npc.name}不在这里。';
    }
    if (!_canFavor()) return '你今天示好的次数已经用完了。';

    final rnd = rng();
    final speech = skillLevel('speech');
    final rel = npcRelation(npc.id);
    // 礼金：基础 5 + (100-关系)/20，随好感递减
    final cost = (5 + (100 - rel) ~/ 20).clamp(3, 12);
    if (player.gold < cost) {
      return '你想备一份薄礼，却囊中羞涩（需 $cost 金币）。';
    }
    _recordFavor();
    gainGold(-cost);
    final gain = 3 + speech ~/ 2 + rnd.nextInt(3);
    adjustRelation(npc.id, gain);
    final level = npcRelationLabel(npcRelation(npc.id));
    return '🎁 你与${npc.name}深谈，并备了一份薄礼（花 $cost 金币）。他/她的态度明显软化。关系 +$gain（${level}）。';
  }

  /// 好感度事件链：在场 NPC 关系突破阈值（相识起）时触发专属剧情。
  ///
  /// 每个 (NPC, 等级) 仅触发一次（flag 记录），由月度循环调用。
  /// 返回追加到叙事的文本；无触发返回空串。
  String maybeNpcStoryEvent({int? seed}) {
    if (!isGameActive || isGameOver) return '';
    final buf = StringBuffer();
    for (final n in npcsAtCurrentLocation) {
      final rel = npcRelation(n.id);
      if (rel < 20) continue; // 陌生以下不触发
      final level = npcRelationLabel(rel);
      final flagKey = 'npc_story.${n.id}.$level';
      if (flagOf(flagKey)) continue;
      setFlag(flagKey, true);
      final text = switch (level) {
        '相识' => '🌱 你与${n.name}的交情渐渐萌芽。他/她开始愿意跟你说两句心里话。',
        '熟识' => '🤝 ${n.name}把你当成可靠的同伴。有事会先找你商量。',
        '信任' => '🔒 ${n.name}将一件信物托付于你：「这个给你，只有你能碰。」信任无言，却比金子重。',
        '挚友' => '⚔️ ${n.name}立誓与你同进退：「刀山火海，一句话的事。」',
        _ => '',
      };
      if (text.isNotEmpty) buf.writeln(text);
    }
    return buf.toString().trim();
  }
}