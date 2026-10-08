/// 日常玩法混入：训练、工作、休息、狩猎、贸易、月度循环。
///
/// 参考 docs/08_玩法设计.md「核心玩法」。
library;

import 'dart:math';
import '../data/balance_data.dart';
import '../models/event.dart';
import '../models/location.dart';
import '../models/player.dart';
import '../core/command_registry.dart';
import '../core/monthly_pipeline.dart';
import '../models/monthly_counter.dart';
import '../providers/game_provider_base.dart';
import '../utils/command_alias.dart';
import '../utils/labels.dart';
import 'mixin_generation.dart';
import 'mixin_life.dart';
import 'mixin_letter.dart';
import 'mixin_marriage.dart';
import 'mixin_npc_interact.dart';
import 'mixin_npc_task.dart';
import 'mixin_systems.dart';
/// 日常玩法混入。挂在 [GameProviderBase] 上。
///
/// [advanceMonth] 需要调用 [GameSystemsMixin.applyMonthlySystems]、
/// [GameLifeMixin.applyMonthlyLife] 与 [GameNpcInteractMixin.maybeNpcStoryEvent]、
/// [GameGenerationMixin.maybeSuccessionStory]、[GameMarriageMixin.maybeFamilyEvent]、
/// [GameNpcTaskMixin.advanceNpcTasks/checkNpcTaskDeadlines]、
/// [GameLetterMixin.registerLetterMonthlyHooks]，
/// 因此 on 约束中列出七者。
///
/// S12-10：信件钩子在此注册。`game_engine.dart` 的 `with` 列表已把
/// `GameLetterMixin` 排到 `GamePlayMixin` **之前**——混入顺序必须让
/// on 约束里的被依赖者先就位，否则报
/// `mixin_application_not_implemented_interface`（实测）。
mixin GamePlayMixin
    on
        GameProviderBase,
        GameSystemsMixin,
        GameLifeMixin,
        GameNpcInteractMixin,
        GameGenerationMixin,
        GameMarriageMixin,
        GameNpcTaskMixin,
        GameLetterMixin {
  // 数值统一收口在 lib/data/balance_data.dart（Batch 10-30 · M4a）。
  /// 每日活动次数上限（防数值刷子，参考 docs/08 玩法限制）。
  static const Map<String, int> kDailyLimits = BalanceData.dailyLimits;

  /// 训练：提升一项技能。
  ///
  /// 消耗精力（疲惫时成功率减半）；返回叙事文本；每天最多 [kDailyLimits] 次。
  String train(String skillName) {
    if (!_canDoDaily('train')) {
      return '你本月已经练得够多了。身体的每一块肌肉都在抗议——下月再来吧。';
    }
    if (!player.skills.containsKey(skillName)) {
      return '你从未学过「$skillName」，无从练起。';
    }

    final rnd = rng();
    final current = skillLevel(skillName);
    if (current >= BalanceData.skillCap) {
      return '「$skillName」已臻化境，寻常训练已无法让你更进一步。';
    }

    // 精力消耗：疲惫时成功率减半
    if (!canAffordEnergy(BalanceData.trainEnergyCost)) {
      return '你精疲力竭，连剑都举不起来。先去休息吧。';
    }
    adjustEnergy(-BalanceData.trainEnergyCost);

    // 成长：10 级封顶，越接近上限成功率越低（防止无限刷）。
    final chance = (BalanceData.trainBaseChance -
            current * BalanceData.trainChanceDecayPerLevel) *
        energySuccessMultiplier();
    _recordDaily('train');

    if (rnd.nextDouble() < chance) {
      final newSkills = Map<String, int>.from(player.skills);
      newSkills[skillName] = current + 1;
      updatePlayer(player.copyWith(skills: newSkills));
      return '你苦练「$skillName」，技艺精进！（$current → ${current + 1}）';
    }
    return '你练了一整天「$skillName」，但收效甚微。（$current 级，下次再试）';
  }

  /// 休息：恢复精力与少量健康，消耗少量金币。
  ///
  /// S2-2：接入每月闸口（[BalanceData.dailyLimits]['rest']）——此前该键为 99 且
  /// `rest()` 从不读取，等于「每月上限」表里有一个永不生效的装饰值。
  String rest() {
    if (!_canDoDaily('rest')) {
      return '你本月已经歇得够久了。再躺下去，旅店老板都要赶人了。';
    }
    if (player.gold < BalanceData.restInnCost) {
      return '你太穷了，连一顿像样的饭都吃不起。找个地方蜷缩着睡了一夜。';
    }
    gainGold(-BalanceData.restInnCost);
    adjustEnergy(GameLifeMixin.kRestEnergyRecovery);
    adjustHunger(BalanceData.restHungerGain);
    _recordDaily('rest');
    // 受伤时休息恢复更快
    final healText = isInjured ? ' 伤口似乎也舒缓了一些。' : '';
    return '你在旅店歇了一晚，吃了顿热饭，花去 ${BalanceData.restInnCost} 金币。精力恢复 ${GameLifeMixin.kRestEnergyRecovery}。$healText';
  }

  /// 工作：按身份/技能赚取金币（消耗精力）。
  String work() {
    if (!_canDoDaily('work')) {
      return '本月的活计已经干完了。';
    }
    if (!canAffordEnergy(BalanceData.workEnergyCost)) {
      return '你实在太累了，干不动活了。先去休息吧。';
    }
    adjustEnergy(-BalanceData.workEnergyCost);
    _recordDaily('work');
    final rnd = rng();

    // 基础收入按身份浮动（数值集中在 BalanceData.workBaseIncome，单一真相）
    final base = BalanceData.workBaseIncome[player.identity.name] ?? 12;
    // 技能加成
    final speechBonus = skillLevel('speech') ~/ BalanceData.workSkillBonusDivisor;
    final swordBonus = skillLevel('sword') ~/ BalanceData.workSkillBonusDivisor;
    final total = base + speechBonus + swordBonus + rnd.nextInt(BalanceData.workIncomeVariance);
    gainGold(total);
    return '你忙碌了一天，挣得 $total 金币。（${identityLabel(player.identity)}，'
        '技能加成 ${speechBonus + swordBonus}）';
  }

  /// 狩猎：按剑术/弓箭技能赚取金币，有失败风险（消耗精力）。
  String hunt() {
    if (!_canDoDaily('hunt')) {
      return '本月的猎物已经够多了。';
    }
    // S13-8：地点判定必须在扣费之前——否则「在城市狩猎」是**纯亏损**：
    // 20 精力照扣、当月 1/2 额度照占，只换来一句「城市里无猎可狩」。
    // 开局默认地点临冬城是 castle（不是 city），故本路径实际很易触发。
    final loc = currentLocation;
    if (loc == null) return '你身处荒野之外，无从狩猎。';
    if (loc.type == LocationType.city) return '城市里无猎可狩。你需要去野外。';
    if (!canAffordEnergy(BalanceData.huntEnergyCost)) {
      return '你实在太累了，拉不开弓。先去休息吧。';
    }
    adjustEnergy(-BalanceData.huntEnergyCost);
    _recordDaily('hunt');
    final rnd = rng();

    final skill = max(skillLevel('archery'), skillLevel('sword'));
    final danger = loc.dangerLevel;
    // 成功率：技能/战斗值与危险度对抗（疲惫打折；装备加成）
    final power = combatPower();
    final successChance =
        (BalanceData.huntBaseChance +
                skill * BalanceData.huntChancePerSkill +
                power * BalanceData.huntChancePerPower -
                danger * BalanceData.huntChancePerDanger)
            .clamp(BalanceData.huntChanceMin, BalanceData.huntChanceMax) *
            energySuccessMultiplier();

    if (rnd.nextDouble() < successChance) {
      final reward = BalanceData.huntRewardBase +
          skill * BalanceData.huntRewardPerSkill +
          danger * BalanceData.huntRewardPerDanger +
          rnd.nextInt(BalanceData.huntRewardVariance);
      gainGold(reward);
      // 顺便补充食物
      adjustHunger(BalanceData.huntHungerGain);
      return '你在${loc.name}附近的林地猎到猎物，收获 $reward 金币，饱餐一顿。';
    }
    // 失败：危险度高时可能受伤（掉血由 flags 模拟）
    if (rnd.nextDouble() < BalanceData.huntInjuryChance) {
      setFlag('isInjured', true);
      adjustHealth(-BalanceData.huntInjuryHealthCost);
      return '狩猎时你失手摔伤，空手而归。（受了点轻伤，健康 -5）';
    }
    return '你在${loc.name}附近转了一天，什么也没猎到。';
  }

  /// 贸易：按地点类型/商人身份赚取金币（消耗精力）。
  String trade() {
    if (!_canDoDaily('trade')) {
      return '本月的集市已经散了。';
    }
    // S13-8：同 hunt()——地点判定前移，否则在城堡「贸易」白扣 15 精力 + 占额度。
    final loc = currentLocation;
    if (loc == null ||
        (loc.type != LocationType.city && loc.type != LocationType.market)) {
      return '这里不是做买卖的地方。去城市或集市吧。';
    }
    if (!canAffordEnergy(BalanceData.tradeEnergyCost)) {
      return '你精疲力竭，无心讨价还价。先去休息吧。';
    }
    adjustEnergy(-BalanceData.tradeEnergyCost);
    _recordDaily('trade');

    final rnd = rng();
    final isMerchant = isIdentity(PlayerIdentity.merchant);
    // 商人加成大
    final profit = (isMerchant ? BalanceData.tradeMerchantBase : BalanceData.tradeCommonerBase) +
        skillLevel('speech') * BalanceData.tradeSpeechGain +
        rnd.nextInt(BalanceData.tradeProfitVariance);
    gainGold(profit);
    return '你在${loc.name}做成一笔买卖，净赚 $profit 金币。'
        '${isMerchant ? '（商人的眼光果然毒辣）' : ''}';
  }

  /// 月度循环：推进一个月，结算系统演进 + 生存状态。
  ///
  /// 返回本月的完整叙事（含系统结算与生存结算），供 UI/AI 展示。
  String advanceMonth() {
    if (!isGameActive || isGameOver) return '游戏尚未开始。';
    // 月度结算管线（Batch 10-28 · M3）：各领域钩子按注册顺序执行，
    // 时钟推进由管线在 before/after 两阶段之间调用。
    final hookText = monthlyPipeline.runMonth(advanceClock: advanceTime);
    final buf = StringBuffer()..writeln(
      '⏳ 时间推进到 ${progress.year}年${progress.month}月（${progress.season}）',
    );
    if (hookText.isNotEmpty) buf.write(hookText);
    final loc = currentLocation;
    if (loc != null) {
      buf.writeln('你身处 ${loc.name}（${loc.region}）。');
    }
    return buf.toString().trim();
  }

  // ==================== M3 · 月度结算管线 ====================

  MonthlyPipeline? _monthly;

  /// 月度结算管线（首次访问时构建并缓存）。
  ///
  /// 钩子的 phase/order/outputOrder 与 Batch 10-28 之前 [advanceMonth]
  /// 里的调用顺序、文本顺序逐一对应，保证月度叙事逐字一致。
  MonthlyPipeline get monthlyPipeline {
    final cached = _monthly;
    if (cached != null) return cached;
    final pipeline = MonthlyPipeline();
    registerPlayMonthlyHooks(pipeline);
    registerSystemsMonthlyHooks(pipeline);
    registerLifeMonthlyHooks(pipeline);
    registerNpcInteractMonthlyHooks(pipeline);
    registerGenerationMonthlyHooks(pipeline);
    registerMarriageMonthlyHooks(pipeline);
    registerNpcTaskMonthlyHooks(pipeline);
    // S12-10：信件此前只挂在 AI 路径（mixin_ai.applyAiChoice），
    // 普通玩家用「过月」推进时**永远收不到信** ⇒ 信件面板/回信形同摆设。
    registerLetterMonthlyHooks(pipeline);
    _monthly = pipeline;
    return pipeline;
  }

  /// 把本领域的月度钩子注册进管线（推进时钟之后的阶段）。
  ///
  /// 执行顺序与旧实现逐条对应：跨年清理离婚标记 → 死亡传承 → 世界事件。
  /// 传承必须排在世界事件之前：当月死亡换嗣时，旧实现里随后的世界事件
  /// 是用「新家主」掷的，顺序调换会改变结果。
  void registerPlayMonthlyHooks(MonthlyPipeline pipeline) {
    pipeline.register(
      MonthlyHookSpec(
        id: 'divorce_clear',
        phase: MonthlyPhase.afterAdvance,
        order: 10,
        outputOrder: 0,
        hook: () {
          maybeClearDivorceFlag();
          return const MonthlyHookResult(text: '');
        },
      ),
    );
    pipeline.register(
      MonthlyHookSpec(
        id: 'inheritance',
        phase: MonthlyPhase.afterAdvance,
        order: 11,
        outputOrder: 10,
        hook: () => MonthlyHookResult(
          text: _tryInheritance() ?? '',
          outputOrder: 10,
        ),
      ),
    );
    pipeline.register(
      MonthlyHookSpec(
        id: 'world_event',
        phase: MonthlyPhase.afterAdvance,
        order: 12,
        outputOrder: 11,
        hook: () => MonthlyHookResult(
          text: _maybeWorldEvent(seed: progress.turnCount),
          outputOrder: 11,
        ),
      ),
    );
  }

  /// 玩家死亡后的世代传承尝试。
  ///
  /// - 有继承人：切换为继承人（新玩家），返回传承叙事，游戏继续。
  /// - 无继承人：家族血脉断绝，游戏结束（isGameOver），返回落幕叙事。
  ///
  /// 返回追加到叙事的文本；玩家存活返回 null。
  String? _tryInheritance() {
    if (!(player.flags['isAlive'] ?? true)) {
      final heir = heirName;
      if (heir != null) {
        final newPlayer = advanceGeneration();
        if (newPlayer != null) {
          return '⚜️ 你溘然长逝。血脉延续——「$heir」继承家业，成为新的家主。'
              '（第 ${generationNumber()} 代，金币 ${newPlayer.gold}，声望 ${newPlayer.reputation}）';
        }
      }
      // 无继承人：血脉断绝
      endGame();
      return '🕯️ 你没有留下子嗣。家族血脉随你一同断绝，传奇落幕。';
    }
    return null;
  }

  /// 月度世界事件浮现：从可触发事件中随机选一个，登记为**待决事件**并输出选项菜单。
  ///
  /// 30% 概率；让世界事件随季节/处境浮现。
  ///
  /// 【S4-5 起不再是「纯提示」】浮现后事件进入 [pendingEvent]，玩家可经
  /// [chooseWorldEventChoice] 真正抉择并落盘效果——此前它只输出一行文本，
  /// 事件库预写的选项效果在生产中永不生效。
  ///
  /// 【待决事件何时消失】被抉择（[chooseWorldEventChoice]）时清空，或被
  /// 下一条浮现的传闻**替换**。刻意不在未抉择时按月清空：玩家不该因为
  /// 「当月没点」而永久错过一个已经摆到面前的抉择。
  String _maybeWorldEvent({int? seed}) {
    final rnd = rng(seed);
    if (rnd.nextDouble() >= 0.3) return '';
    final available = eventProvider.getAvailableEvents(
      player,
      season: progress.season,
    );
    if (available.isEmpty) return '';
    final event = available[rnd.nextInt(available.length)];
    // 【S4-6（P1-11）一次性事件必须在此标记完成】
    // `EventProvider.canTrigger` 对 `isOneTime` 事件的拦截依赖
    // `_completedEventIds`，而写入该集合的唯一入口 `markCompleted`
    // 在生产代码中**零调用**（全库只有测试调）——故该门禁恒不生效，
    // 3 个一次性事件（`event_sword_inheritance` / `event_guild_tooling` /
    // `event_maester_commission`）会无限重复浮现。
    //
    // 【为什么标在「浮现」而不是「抉择」】S4-6 定此点时事件选项尚不可达；
    // S4-5 让选项可抉择后，**标记点仍保留在浮现处**，理由是「浮现」与
    // 「抉择」是两件事：传闻已经完整播报给玩家（含全部选项文案），而玩家
    // 完全可能听完就不选。若改标在抉择处，同一条一次性传闻会每月复读一次
    // 直到玩家点它——那正是 S4-6 要修的病症。不标记的后果亦然。
    //
    // 【S4-5（架构级）：把「浮现」变成「可抉择」】
    // 此前本函数只输出一行文本，事件库预写的选项效果在生产中**永不落盘**。
    // 现在把它登记为**待决事件**，由 UI 渲染成可点选项卡片，玩家抉择后
    // 经 [chooseWorldEventChoice] 真正应用效果。
    //
    // 【一次性事件的标记点仍在「浮现」】这是 S4-6 的既有决策：本函数是
    // 事件触达玩家的通道。S4-5 让选项可达后，「浮现」与「抉择」仍然分离
    // （玩家可能听完传闻不选），故标记点保持在曝光时刻，见 S4-6 遗留项。
    if (event.isOneTime) {
      eventProvider.markCompleted(event.id);
    }
    setPendingEvent(event);
    final choices = event.choices.map((c) => '  · ${c.text}').join('\n');
    return '📜 传闻：${event.name}——${event.description}\n你可以：\n$choices';
  }

  // 待决事件状态由状态层持有（`GameStateProvider.pendingEvent`）——
  // 这样「重新开始」能清空、读档能整体复制、且随存档往返。

  /// 抉择当前待决世界事件的一个选项：效果真正落盘 + 记录历史。
  ///
  /// 【S4-5 的核心修复】`event_data.dart` 里 71 个事件的 216 个带 effects 的
  /// 选项此前**在生产流程中不可达**（`applyChoice` 在 screens/widgets 零调用，
  /// 事件面板自述「不做触发执行」，月度传闻只输出一行文本）。本方法是这些
  /// 选项的第一个生产调用方。
  ///
  /// 【为什么不调 advanceTime】本事件是在 `advanceMonth()` 内部浮现的，
  /// 那时时钟已经推进过了——故走 `applyChoice(advanceClock: false)`，
  /// 否则同一个事件会吃掉两个月（详见该方法的 doc）。
  ///
  /// 返回结算叙事（选项叙事 + 真实效果摘要）；无待决事件时返回提示文本。
  String chooseWorldEventChoice(EventChoice choice) {
    final event = pendingEvent;
    if (event == null) return '当前没有待抉择的事件。';
    // 【按 id 匹配，不用 `choices.contains`】`EventChoice` 没有重写 `==`，
    // `contains` 走身份相等：UI 路径下玩家点的就是 `pendingEvent.choices[i]`
    // 故身份一致，但**存档往返**后 fromJson 会构造新实例，同一选项会被
    // 误判为「不是本事件的可选项」——读档后待决事件成了点不动的死卡片。
    // 按 id 匹配对两条路径都成立，并顺带锁死「只能选本事件声明的选项」。
    final matched = event.choices.where((c) => c.id == choice.id).toList();
    if (matched.isEmpty) {
      return '「${choice.text}」不是「${event.name}」的可选项。';
    }
    // 用事件自身的选项对象落盘，避免调用方传入的等价副本带来分歧
    final picked = matched.first;
    // 【S4-5 必须校验 requirements】223 个选项里 68 个声明了门槛
    // （gold/skills/attributes/hasItem/energy/reputation/hunger）。此前它们
    // 只被事件面板用于展示，`applyChoice` 从不校验；S4-5 之前选项不可达，
    // 那只是死契约，**现在则是有利可图的漏洞**——例如「偿还债务」要求
    // `{gold: 500}`、效果 `gold: -500, reputation: +10`，而金币效果被
    // `max(0, ...)` 破底，0 金玩家也能选，等于不花钱白拿声望。
    // 复用 `EventProvider.canChoose`（既有单一真相），不另写一份判定。
    if (!eventProvider.canChoose(picked, player)) {
      return '你还不满足「${picked.text}」的条件。';
    }
    // 供 applyChoice 记录历史用（它读 currentEvent）
    setCurrentEvent(event);
    final before = player;
    final rejectedText = applyChoice(picked, advanceClock: false);
    setPendingEvent(null);
    final buf = StringBuffer();
    if (picked.narrative.isNotEmpty) {
      buf.writeln(picked.narrative);
    }
    // 摘要与 AI 通道共用同一份实现（见 GameProviderBase.effectSummary）
    buf.write(effectSummary(before, includeRejected: false));
    // applyChoice 已返回「N 项效果未生效」提示，此处接上，避免重复
    if (rejectedText.isNotEmpty) {
      buf.writeln(rejectedText.trim());
    }
    return buf.toString().trim();
  }

  // ==================== 内部工具 ====================

  /// S13-5：本组的计数器（状态层 `GameStateProvider.monthlyCounters`）。
  ///
  /// 【为什么原来的 `_dailyCount`/`_dailyDate` 被删掉而不是「保留 + 镜像」】
  /// 它们本来就是「计数 + 月份键」这一对，而 `MonthlyCounter` 恰好就是
  /// 这个形状 ⇒ 保留旧字段就等于造出两份各自像真的活状态，
  /// 正是 S13-4 花大力气记录下来的漂移陷阱。删掉旧字段后本组只剩一个真相源。
  MonthlyCounter get _activityCounter => monthlyCounters.activity;

  /// 今日日期串（用于每日重置）。
  String get _today => '${progress.year}-${progress.month}';

  /// 是否还能进行某活动。
  ///
  /// 上限表里查不到时用 1 兜底（S2-2：原为 `kDailyLimits[activity]!` 强制解包，
  /// 新增一种活动却忘了配上限就会运行时崩溃）。
  bool _canDoDaily(String activity) {
    _rollDaily();
    final count = _activityCounter.used(activity);
    return count < (kDailyLimits[activity] ?? 1);
  }

  /// 记录一次活动。
  void _recordDaily(String activity) {
    _rollDaily();
    _activityCounter.record(activity);
  }

  /// 跨月重置每日计数。
  void _rollDaily() => _activityCounter.rollIfNewMonth(_today);

  /// 玩家信息面板。
  String formatPlayerPanel() {
    final p = player;
    final fam = playerFamily;
    final loc = currentLocation;
    final buf = StringBuffer()
      ..writeln('【玩家状态】')
      ..writeln('· ${p.name}（${identityLabel(p.identity)}），${p.age}岁，${p.gender == 'male' ? '男' : '女'}')
      ..writeln('· 家族：${fam?.name ?? '无'}（${fam?.motto ?? ''}）')
      ..writeln('· 地点：${loc?.name ?? p.locationId}（${loc?.region ?? ''}）')
      ..writeln('· 金币：${p.gold}｜声望：${p.reputation}')
      ..writeln('· 生命：${p.health}/100｜精力：${p.energy}/100｜饱食：${p.hunger}/100')
      ..writeln('· 属性：${p.attributes.entries.map((e) => '${attributeLabel(e.key)} ${e.value}').join(' ')}')
      ..writeln('· 技能：${p.skills.entries.map((e) => '${skillLabel(e.key)} ${e.value}').join(' ')}');
    if (p.title.isNotEmpty) {
      buf.writeln('· 头衔：${p.title}');
    }
    if (p.inventory.isNotEmpty) {
      buf.writeln('· 背包：${formatInventoryPanel().replaceFirst('【背包】\n', '')}');
    }
    return buf.toString().trim();
  }

  // ==================== M3 · 指令自注册 ====================

  /// 把本领域（日常玩法）指令注册进注册表（order 与历史帮助文本顺序一致）。
  void registerPlayCommands(CommandRegistry registry) {
    registry.register(
      CommandSpec(
        aliases: const ['状态', 'status'],
        order: 1,
        group: '查看',
        helpLine: '状态 / status       查看玩家状态（生命/精力/饱食/背包）',
        handler: (args) => CommandResult(text: formatPlayerPanel()),
      ),
    );
    registry.register(
      CommandSpec(
        aliases: const ['训练', 'train'],
        order: 9,
        group: '成长',
        requiredArgCount: 1,
        missingArgsHint: '训练什么？可用技能：sword（剑术）/ archery（弓术）/ riding（骑术）/ speech（口才）/ alchemy（炼金）/ magic（魔法）。',
        helpLine: '训练 / train [技能]  训练技能（sword/archery/riding/speech/alchemy/magic）',
        handler: (args) => CommandResult(text: train(normalizeSkillAlias(args))),
      ),
    );
    registry.register(
      CommandSpec(
        aliases: const ['工作', 'work'],
        order: 10,
        group: '日常',
        helpLine: '工作 / work         赚取金币（消耗精力）',
        handler: (args) => CommandResult(text: work()),
      ),
    );
    registry.register(
      CommandSpec(
        aliases: const ['狩猎', 'hunt'],
        order: 11,
        group: '日常',
        helpLine: '狩猎 / hunt         野外狩猎（消耗精力）',
        handler: (args) => CommandResult(text: hunt()),
      ),
    );
    registry.register(
      CommandSpec(
        aliases: const ['贸易', 'trade'],
        order: 12,
        group: '日常',
        helpLine: '贸易 / trade        城市贸易（消耗精力）',
        handler: (args) => CommandResult(text: trade()),
      ),
    );
    registry.register(
      CommandSpec(
        aliases: const ['休息', 'rest'],
        order: 44,
        group: '日常',
        helpLine: '休息 / rest         恢复精力/饱食（花 2 金币）',
        handler: (args) => CommandResult(text: rest()),
      ),
    );
    registry.register(
      CommandSpec(
        aliases: const ['过月', 'advance'],
        order: 45,
        group: '日常',
        consumedTurn: true,
        helpLine: '过月 / advance      推进一个月',
        // handler 内部已自行 advanceMonth()，故 needsTimeAdvance=false：
        // 调度方若再推进一次就会「过月推两个月」。
        handler: (args) => CommandResult(
              text: advanceMonth(),
              consumedTurn: true,
              needsTimeAdvance: false,
            ),
      ),
    );
  }
}
