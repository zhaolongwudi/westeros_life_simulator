/// NPC 深度交互混入（Batch 10-13）。
///
/// 在既有 NPC 数据（36 NPC + relations）之上提供：
/// - 关系等级（敌对/陌生/相识/熟识/信任/挚友）
/// - 深度互动：按关系等级解锁 寒暄/倾诉/请求/秘密/结盟
/// - 示好送礼：每月限次，提升好感
/// - 好感度事件链：关系突破阈值触发专属剧情（一次性 flag）
library;

import '../data/balance_data.dart';
import '../models/monthly_counter.dart';
import '../models/npc.dart';
import '../core/command_registry.dart';
import '../core/monthly_pipeline.dart';
import '../utils/command_alias.dart';
import '../providers/game_provider_base.dart';
import 'mixin_life.dart';

/// NPC 深度交互混入。挂在 [GameProviderBase] 上，依赖 [GameLifeMixin]
/// （使用 addItem/combatPower 等生存与战斗能力）。
mixin GameNpcInteractMixin on GameProviderBase, GameLifeMixin {
  /// 示好每日次数上限。
  static const int kFavorDailyLimit = 3;

  /// S13-5：示好组的计数器（状态层 `GameStateProvider.monthlyCounters`）。
  /// 原 `_favorDailyCount`/`_favorDailyMonth` 正是「计数 + 月份键」这一对，
  /// 被 `MonthlyCounter` 整体取代，不留双份活状态。
  MonthlyCounter get _favorCounter => monthlyCounters.favor;

  String get _npcToday => '${progress.year}-${progress.month}';

  void _rollFavorDaily() => _favorCounter.rollIfNewMonth(_npcToday);

  bool _canFavor() {
    _rollFavorDaily();
    return _favorCounter.totalUsed < kFavorDailyLimit;
  }

  void _recordFavor() {
    _rollFavorDaily();
    _favorCounter.record('favor');
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
      // S13-1③：`goals` 与 `fears` **可能同时为空**（实测 4 个：`npc_rickon`
      // 就在默认出生地临冬城，另有 `npc_lys_arryn`/`npc_tommen`/`npc_myrcella`），
      // 此时原先的 `npc.fears.first` 会抛 `StateError`——本分支此前漏了空守卫，
      // 而紧邻的信任分支（下一条 `secrets.isNotEmpty`）是有守卫的。
      // 兜底值取「往事」，与 [npcChat] 的同型兜底保持一致。
      final topic = npc.goals.isNotEmpty
          ? npc.goals.first
          : (npc.fears.isNotEmpty ? npc.fears.first : '往事');
      return '${npc.name}向你倾诉：「最近总想着「$topic」。」你认真听着，他/她的目光柔和了些。';
    }
    if (rel < 60) {
      return _npcRequestAt(npc, rel);
    }
    if (rel < 80) {
      if (npc.secrets.isNotEmpty) {
        adjustRelation(npc.id, BalanceData.secretRelationGain);
        return '🍂 ${npc.name}压低声音：「我可以信任你——」一个秘密浮出水面：${npc.secrets.first}。关系 +3。';
      }
      adjustRelation(npc.id, BalanceData.chatRelationGain);
      return '${npc.name}与你共饮，谈起过往与来路，毫不避讳。关系 +2。';
    }
    // 挚友：结盟
    adjustRelation(npc.id, BalanceData.chatRelationGain);
    adjustReputation(BalanceData.reputationSmallGain);
    return '⚔️ ${npc.name}拍着你的肩膀：「只要我活着，就是你的人。」你们结为挚友。声望 +2，关系 +2。';
  }

  /// 熟识（40~59）关系的 NPC 请求：按 NPC 类型给出护送/结盟/合作等。
  String _npcRequestAt(Npc npc, int rel) {
    final rnd = rng();
    switch (npc.type) {
      case NpcType.noble:
        if (rel >= 50 && rnd.nextDouble() < 0.5) {
          adjustReputation(BalanceData.nobleReferReputation);
          return '🏛️ ${npc.name}把你引荐给封臣们，谈起你的名字时语气郑重。你感到自己的地位在上升。声望 +4。';
        }
        adjustRelation(npc.id, BalanceData.chatRelationGain);
        return '🏰 ${npc.name}向你请教对时局的看法。你说得有理有据，他/她频频点头。关系 +2。';
      case NpcType.soldier:
      case NpcType.adventurer:
        final fee = BalanceData.escortFeeBase + rel + rnd.nextInt(BalanceData.escortFeeVariance);
        gainGold(fee);
        adjustReputation(BalanceData.reputationSmallGain);
        return '🛡️ ${npc.name}请你护送一件要事：「事成之后，$fee 金币不会少你的。」你答应了。报酬 $fee 金币，声望 +2。';
      case NpcType.merchant:
        final profit = BalanceData.merchantShareBase + rel ~/ 2 + rnd.nextInt(BalanceData.merchantShareVariance);
        gainGold(profit);
        adjustRelation(npc.id, BalanceData.chatRelationGain);
        return '💰 ${npc.name}想与你合股走一趟商路：「本钱我出，你出人脉。」第一笔红利 $profit 金币到手。关系 +2。';
      case NpcType.priest:
        adjustHealth(BalanceData.priestHealHealth);
        adjustRelation(npc.id, BalanceData.secretRelationGain);
        return '⛪ ${npc.name}为你向七神祈祷，洒下圣水：「愿诸神护佑你的路。」你感到心神安泰。健康 +5，关系 +3。';
      case NpcType.scholar:
      case NpcType.maester:
        if (npc.skills.isNotEmpty && rnd.nextDouble() < BalanceData.scholarTeachChance) {
          final skill = npc.skills.keys.first;
          final newSkills = Map<String, int>.from(player.skills);
          newSkills[skill] = (newSkills[skill] ?? 0) + 1;
          updatePlayer(player.copyWith(skills: newSkills));
          return '📜 ${npc.name}递给你一卷羊皮纸：「读读这个。」你学到了一些${skill}心得（$skill +1）。';
        }
        adjustRelation(npc.id, BalanceData.chatRelationGain);
        return '📖 ${npc.name}与你畅谈历史与学问，你听得津津有味。关系 +2。';
      case NpcType.assassin:
        if (rel >= 50) {
          final fee = BalanceData.assassinFeeBase + rel + rnd.nextInt(BalanceData.assassinFeeVariance);
          gainGold(fee);
          return '🗡️ ${npc.name}交给你一个信封：「有笔生意，办成了这 $fee 金币归你。」你接下委托。';
        }
        return '🌑 ${npc.name}在阴影里打量着你：「还不是时候。等你更可信一些，再说。」';
      case NpcType.wildling:
      case NpcType.commoner:
        gainGold(BalanceData.wildlingGiftGold);
        adjustReputation(BalanceData.reputationSmallGain);
        return '🔥 ${npc.name}请你为村落说句话。你出面周旋，村民感激不尽。+5 金币谢礼，声望 +2。';
      case NpcType.supernatural:
        adjustReputation(BalanceData.supernaturalReputationGain);
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
    if (!_canFavor()) return '你本月示好的次数已经用完了。';

    final rnd = rng();
    final speech = skillLevel('speech');
    final rel = npcRelation(npc.id);
    // 礼金：基础 5 + (100-关系)/20，随好感递减
    final cost = (BalanceData.npcFavorCostBase + (100 - rel) ~/ BalanceData.npcFavorCostDivisor).clamp(BalanceData.npcFavorCostMin, BalanceData.npcFavorCostMax);
    if (player.gold < cost) {
      return '你想备一份薄礼，却囊中羞涩（需 $cost 金币）。';
    }
    _recordFavor();
    gainGold(-cost);
    final gain = BalanceData.npcChatGainBase + speech ~/ 2 + rnd.nextInt(BalanceData.npcChatGainVariance);
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
  // ==================== Batch 10-15：NPC 任务链 / 深聊 / 关系面板 ====================
  /// 某 NPC 的任务列表（无则空列表）。
  List<String> npcTasks(String npcId) {
    final npc = npcById(npcId);
    return npc == null ? const <String>[] : npc.tasks;
  }
  /// 任务面板：列出在场 NPC 的可接任务。
  String formatNpcTaskPanel() {
    final buf = StringBuffer()..writeln('【可接任务】');
    var any = false;
    for (final n in npcsAtCurrentLocation) {
      if (n.tasks.isEmpty) continue;
      any = true;
      buf.writeln('· ${n.name}：${n.tasks.join(' / ')}');
    }
    if (!any) return '【可接任务】\n在场的人没有委托给你任务。';
    return buf.toString().trim();
  }
  /// 接受一位在场 NPC 的任务（关系 ≥ 相识 才肯委托）。
  ///
  /// 返回叙事文本；未达关系/不在场返回说明。
  String acceptNpcTask(String npcId) {
    final npc = npcById(npcId);
    if (npc == null) return '没有叫「$npcId」的人。';
    if (!npc.isAlive) return '${npc.name}已经不在了。';
    if (npc.locationId != player.locationId) return '${npc.name}不在这里。';
    if (npc.tasks.isEmpty) return '${npc.name}没有委托给你的任务。';
    final rel = npcRelation(npc.id);
    if (rel < 20) {
      return '${npc.name}还信不过你：「等你我熟络些，再说这些事吧。」';
    }
    // 接受任务：记录任务标记（一次性）
    final task = npc.tasks.first;
    final flagKey = 'npc_task.${npc.id}.$task';
    if (flagOf(flagKey)) {
      return '你已经接下「$task」，${npc.name}在等你带回消息。';
    }
    setFlag(flagKey, true);
    adjustRelation(npc.id, BalanceData.taskAcceptRelation);
    return '📜 你接下${npc.name}的委托：「$task」。他/她郑重道：「事成之后，不会亏待你。」关系 +2。';
  }
  /// 任务进度检查：已接任务在探索/过月后结算。
  ///
  /// 当前简化：探索时 40% 概率完成一项已接任务（获得金币+声望+关系）。
  String maybeResolveNpcTask() {
    final buf = StringBuffer();
    for (final n in npcsAtCurrentLocation) {
      for (final task in n.tasks) {
        final flagKey = 'npc_task.${n.id}.$task';
        if (!flagOf(flagKey)) continue;
        if (flagOf('npc_task_done.${n.id}.$task')) continue;
        // 模拟结算：直接完成（探索时调用，概率在外层控制）
        setFlag('npc_task_done.${n.id}.$task', true);
        setFlag(flagKey, false);
        final reward = BalanceData.taskRewardBase + npcRelation(n.id) ~/ 2;
        gainGold(reward);
        adjustRelation(n.id, BalanceData.taskRewardRelation);
        adjustReputation(BalanceData.reputationSmallGain);
        buf.writeln('✅ 你完成了${n.name}的委托：「$task」。获得 $reward 金币，关系 +5，声望 +2。');
      }
    }
    return buf.toString().trim();
  }
  /// 与 NPC 深聊（每日限次，比示好更深入，需相识以上）。
  ///
  /// 按心情与关系产出叙事；提升好感。
  String npcChat(String npcId) {
    if (!_canChat()) return '你本月已经聊得够多了。';
    final npc = npcById(npcId);
    if (npc == null) return '没有叫「$npcId」的人。';
    if (!npc.isAlive) return '${npc.name}已经不在了。';
    if (npc.locationId != player.locationId) return '${npc.name}不在这里。';
    final rel = npcRelation(npc.id);
    if (rel < 20) return '${npc.name}与你还不熟，聊不到深处。';
    _recordChat();
    final moodText = npc.mood.isEmpty ? '' : '（${npc.mood}）';
    final topic = npc.goals.isNotEmpty ? npc.goals.first : '往事';
    final rnd = rng();
    final gain = BalanceData.npcChatGainBase + skillLevel('speech') ~/ 2 + rnd.nextInt(BalanceData.npcChatGainVariance);
    adjustRelation(npc.id, gain);
    final level = npcRelationLabel(npcRelation(npc.id));
    return '🍻 你与${npc.name}$moodText 深聊起「$topic」。'
        '他/她吐露了更多心声，你们之间多了一份默契。关系 +$gain（$level）。';
  }
  /// 深聊每日次数（独立于示好）。
  static const int kChatDailyLimit = 3;

  /// S13-5：深聊组的计数器（状态层 `GameStateProvider.monthlyCounters`）。
  /// 原 `_chatDailyCount`/`_chatDailyMonth` 同上，被 `MonthlyCounter` 整体取代。
  MonthlyCounter get _chatCounter => monthlyCounters.chat;

  bool _canChat() {
    _rollChatDaily();
    return _chatCounter.totalUsed < kChatDailyLimit;
  }
  void _recordChat() {
    _rollChatDaily();
    _chatCounter.record('chat');
  }
  void _rollChatDaily() => _chatCounter.rollIfNewMonth(_npcToday);
  /// NPC 关系面板文本（全部 NPC 的关系等级/心情/任务数）。
  String formatNpcRelationPanel() {
    final buf = StringBuffer()..writeln('【NPC 关系】');
    for (final n in npcs) {
      if (!n.isAlive) continue;
      final rel = npcRelation(n.id);
      final level = npcRelationLabel(rel);
      final mood = n.mood.isEmpty ? '' : '·${n.mood}';
      final tasks = n.tasks.isEmpty ? '' : '·任务 ${n.tasks.length}';
      buf.writeln('· ${n.name}（$level，$rel$mood$tasks）');
    }
    return buf.toString().trim();
  }

  /// 在场 NPC 列表文本（Batch 10-28 从 mixin_commands 迁入）。
  String npcListText() {
    final list = npcInteractionList();
    if (list.isEmpty) return '【在场人物】\n你身边没有其他人在场。';
    return '【在场人物】\n${list.join('\n')}';
  }

  // ==================== M3 · 指令自注册 ====================

  /// 把本领域指令注册进注册表（order 与历史帮助文本顺序一致）。
  void registerNpcInteractCommands(CommandRegistry registry) {
    registry.register(
      CommandSpec(
        aliases: const ['在场', 'npc', '人物'],
        order: 23,
        helpLine: '在场 / npc         查看当前在场的 NPC 与关系',
        handler: (args) => CommandResult(text: npcListText()),
      ),
    );
    registry.register(
      CommandSpec(
        aliases: const ['互动', '交谈', 'interact'],
        order: 24,
        requiredArgCount: 1,
        missingArgsHint: '和谁互动？如「互动 提利昂」或「互动 npc_tyrion」。输入「在场」看谁在这里。',
        helpLine: '互动 / interact [名字]  与在场 NPC 深度互动（好感越高内容越深）',
        handler: (args) => CommandResult(text: npcInteract(normalizeNpcAlias(this, args))),
      ),
    );
    registry.register(
      CommandSpec(
        aliases: const ['示好', '送礼', 'favor'],
        order: 25,
        requiredArgCount: 1,
        missingArgsHint: '向谁示好？如「示好 提利昂」或「送礼 npc_tyrion」。',
        helpLine: '示好 / favor [名字]   向在场 NPC 示好送礼（每月 3 次）',
        handler: (args) => CommandResult(text: npcFavor(normalizeNpcAlias(this, args))),
      ),
    );
    registry.register(
      CommandSpec(
        aliases: const ['深聊', '聊天', 'chat'],
        order: 26,
        requiredArgCount: 1,
        missingArgsHint: '和谁深聊？如「深聊 提利昂」。输入「在场」看谁在这里。',
        helpLine: '深聊 / chat [名字]    与 NPC 深聊（相识以上，每月 3 次，更深入）',
        handler: (args) => CommandResult(text: npcChat(normalizeNpcAlias(this, args))),
      ),
    );
    // S13-3 ④：「任务 / 委托 / task」这条 spec 已**迁到 mixin_npc_task.dart**
    // 的 `registerNpcTaskCommands`（连同实现一起改为 V2）。
    // 迁走的原因不是整理代码，而是**依赖方向不允许**：
    // `GameNpcInteractMixin on GameProviderBase, GameLifeMixin`（:20）看不到
    // `GameNpcTaskMixin` 的 `acceptNpcTaskV2` / `formatNpcTaskPanelV2`
    // （依赖是单向的 NpcTask → NpcInteract），就地改会 analyze 报 Undefined name。
    // 别名与 order(27) 一并保留 ⇒ 帮助文本顺序、alias 集合均不变。
    registry.register(
      CommandSpec(
        aliases: const ['关系', '关系面板', 'relations'],
        order: 31,
        helpLine: '关系 / relations     查看全部 NPC 关系/心情/任务数',
        handler: (args) => CommandResult(text: formatNpcRelationPanel()),
      ),
    );
  }
  // ==================== M3 · 月度结算管线自注册 ====================

  /// 把本领域（NPC 好感度事件链）钩子注册进管线。
  void registerNpcInteractMonthlyHooks(MonthlyPipeline pipeline) {
    pipeline.register(
      MonthlyHookSpec(
        id: 'npc_story',
        phase: MonthlyPhase.beforeAdvance,
        order: 4,
        outputOrder: 3,
        hook: () => MonthlyHookResult(
          text: maybeNpcStoryEvent(seed: progress.turnCount),
          outputOrder: 3,
        ),
      ),
    );
  }
}
