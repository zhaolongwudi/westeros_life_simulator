/// 日常玩法混入：训练、工作、休息、狩猎、贸易、月度循环。
///
/// 参考 docs/08_玩法设计.md「核心玩法」。
library;

import 'dart:math';
import '../models/location.dart';
import '../models/player.dart';
import '../core/command_registry.dart';
import '../core/monthly_pipeline.dart';
import '../providers/game_provider_base.dart';
import '../utils/command_alias.dart';
import '../utils/labels.dart';
import 'mixin_generation.dart';
import 'mixin_life.dart';
import 'mixin_marriage.dart';
import 'mixin_npc_interact.dart';
import 'mixin_npc_task.dart';
import 'mixin_systems.dart';
/// 日常玩法混入。挂在 [GameProviderBase] 上。
///
/// [advanceMonth] 需要调用 [GameSystemsMixin.applyMonthlySystems]、
/// [GameLifeMixin.applyMonthlyLife] 与 [GameNpcInteractMixin.maybeNpcStoryEvent]、
/// [GameGenerationMixin.maybeSuccessionStory]、[GameMarriageMixin.maybeFamilyEvent]、
/// [GameNpcTaskMixin.advanceNpcTasks/checkNpcTaskDeadlines]，
/// 因此 on 约束中列出六者。
mixin GamePlayMixin
    on
        GameProviderBase,
        GameSystemsMixin,
        GameLifeMixin,
        GameNpcInteractMixin,
        GameGenerationMixin,
        GameMarriageMixin,
        GameNpcTaskMixin {
  /// 每日活动次数上限（防数值刷子，参考 docs/08 玩法限制）。
  static const Map<String, int> kDailyLimits = {
    'train': 3,
    'hunt': 2,
    'work': 2,
    'trade': 2,
    'rest': 99,
  };

  /// 训练：提升一项技能。
  ///
  /// 消耗精力（疲惫时成功率减半）；返回叙事文本；每天最多 [kDailyLimits] 次。
  String train(String skillName) {
    if (!_canDoDaily('train')) {
      return '你今天已经练得够多了。身体的每一块肌肉都在抗议——明天再来吧。';
    }
    if (!player.skills.containsKey(skillName)) {
      return '你从未学过「$skillName」，无从练起。';
    }

    final rnd = rng();
    final current = skillLevel(skillName);
    if (current >= 10) {
      return '「$skillName」已臻化境，寻常训练已无法让你更进一步。';
    }

    // 精力消耗：疲惫时成功率减半
    if (!canAffordEnergy(10)) {
      return '你精疲力竭，连剑都举不起来。先去休息吧。';
    }
    adjustEnergy(-10);

    // 成长：10 级封顶，越接近上限成功率越低（防止无限刷）。
    final chance = (0.8 - (current * 0.05)) * energySuccessMultiplier();
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
  String rest() {
    if (player.gold < 2) {
      return '你太穷了，连一顿像样的饭都吃不起。找个地方蜷缩着睡了一夜。';
    }
    gainGold(-2);
    adjustEnergy(GameLifeMixin.kRestEnergyRecovery);
    adjustHunger(10);
    // 受伤时休息恢复更快
    final healText = isInjured ? ' 伤口似乎也舒缓了一些。' : '';
    return '你在旅店歇了一晚，吃了顿热饭，花去 2 金币。精力恢复 ${GameLifeMixin.kRestEnergyRecovery}。$healText';
  }

  /// 工作：按身份/技能赚取金币（消耗精力）。
  String work() {
    if (!_canDoDaily('work')) {
      return '今天的活计已经干完了。';
    }
    if (!canAffordEnergy(15)) {
      return '你实在太累了，干不动活了。先去休息吧。';
    }
    adjustEnergy(-15);
    _recordDaily('work');
    final rnd = rng();

    // 基础收入按身份浮动（枚举匹配，避免字符串魔法值）
    final base = switch (player.identity) {
      PlayerIdentity.merchant => 20,
      PlayerIdentity.soldier => 15, // 士兵/骑士
      PlayerIdentity.scholar || PlayerIdentity.maester => 10,
      PlayerIdentity.priest => 8,
      PlayerIdentity.commoner => 5,
      _ => 12, // noble / adventurer / assassin / wildling
    };
    // 技能加成
    final speechBonus = skillLevel('speech') ~/ 2;
    final swordBonus = skillLevel('sword') ~/ 2;
    final total = base + speechBonus + swordBonus + rnd.nextInt(5);
    gainGold(total);
    return '你忙碌了一天，挣得 $total 金币。（${identityLabel(player.identity)}，'
        '技能加成 ${speechBonus + swordBonus}）';
  }

  /// 狩猎：按剑术/弓箭技能赚取金币，有失败风险（消耗精力）。
  String hunt() {
    if (!_canDoDaily('hunt')) {
      return '今天的猎物已经够多了。';
    }
    if (!canAffordEnergy(20)) {
      return '你实在太累了，拉不开弓。先去休息吧。';
    }
    adjustEnergy(-20);
    _recordDaily('hunt');
    final rnd = rng();
    final loc = currentLocation;
    if (loc == null) return '你身处荒野之外，无从狩猎。';
    if (loc.type == LocationType.city) return '城市里无猎可狩。你需要去野外。';

    final skill = max(skillLevel('archery'), skillLevel('sword'));
    final danger = loc.dangerLevel;
    // 成功率：技能/战斗值与危险度对抗（疲惫打折；装备加成）
    final power = combatPower();
    final successChance =
        (0.5 + skill * 0.05 + power * 0.02 - danger * 0.03).clamp(0.1, 0.95) *
            energySuccessMultiplier();

    if (rnd.nextDouble() < successChance) {
      final reward = 10 + skill * 3 + rnd.nextInt(10);
      gainGold(reward);
      // 顺便补充食物
      adjustHunger(15);
      return '你在${loc.name}附近的林地猎到猎物，收获 $reward 金币，饱餐一顿。';
    }
    // 失败：危险度高时可能受伤（掉血由 flags 模拟）
    if (rnd.nextDouble() < 0.3) {
      setFlag('isInjured', true);
      adjustHealth(-5);
      return '狩猎时你失手摔伤，空手而归。（受了点轻伤，健康 -5）';
    }
    return '你在${loc.name}附近转了一天，什么也没猎到。';
  }

  /// 贸易：按地点类型/商人身份赚取金币（消耗精力）。
  String trade() {
    if (!_canDoDaily('trade')) {
      return '今天的集市已经散了。';
    }
    if (!canAffordEnergy(10)) {
      return '你精疲力竭，无心讨价还价。先去休息吧。';
    }
    adjustEnergy(-10);
    _recordDaily('trade');
    final loc = currentLocation;
    if (loc == null ||
        (loc.type != LocationType.city && loc.type != LocationType.market)) {
      return '这里不是做买卖的地方。去城市或集市吧。';
    }

    final rnd = rng();
    final isMerchant = isIdentity(PlayerIdentity.merchant);
    // 商人加成大
    final profit = (isMerchant ? 25 : 8) + skillLevel('speech') * 3 + rnd.nextInt(15);
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

  /// 月度世界事件浮现：从可触发事件中随机选一个作叙事提示。
  ///
  /// 仅提示（不强制选择），30% 概率；让世界事件随季节/处境浮现。
  String _maybeWorldEvent({int? seed}) {
    final rnd = rng(seed);
    if (rnd.nextDouble() >= 0.3) return '';
    final available = eventProvider.getAvailableEvents(
      player,
      season: progress.season,
    );
    if (available.isEmpty) return '';
    final event = available[rnd.nextInt(available.length)];
    return '📜 传闻：${event.name}——${event.description}';
  }

  // ==================== 内部工具 ====================

  Map<String, int> _dailyCount = <String, int>{};
  String? _dailyDate;

  /// 今日日期串（用于每日重置）。
  String get _today => '${progress.year}-${progress.month}';

  /// 是否还能进行某活动。
  bool _canDoDaily(String activity) {
    _rollDaily();
    final count = _dailyCount[activity] ?? 0;
    return count < kDailyLimits[activity]!;
  }

  /// 记录一次活动。
  void _recordDaily(String activity) {
    _rollDaily();
    _dailyCount[activity] = (_dailyCount[activity] ?? 0) + 1;
  }

  /// 跨月重置每日计数。
  void _rollDaily() {
    if (_dailyDate != _today) {
      _dailyDate = _today;
      _dailyCount = <String, int>{};
    }
  }

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
      ..writeln('· 属性：${p.attributes.entries.map((e) => '${e.key} ${e.value}').join(' ')}')
      ..writeln('· 技能：${p.skills.entries.map((e) => '${e.key} ${e.value}').join(' ')}');
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
        helpLine: '状态 / status       查看玩家状态（生命/精力/饱食/背包）',
        handler: (args) => CommandResult(text: formatPlayerPanel()),
      ),
    );
    registry.register(
      CommandSpec(
        aliases: const ['训练', 'train'],
        order: 9,
        requiredArgCount: 1,
        missingArgsHint: '训练什么？可用技能：sword（剑术）/ archery（弓术）/ riding（骑术）/ speech（口才）/ alchemy（炼金）。',
        helpLine: '训练 / train [技能]  训练技能（sword/archery/riding/speech/alchemy）',
        handler: (args) => CommandResult(text: train(normalizeSkillAlias(args))),
      ),
    );
    registry.register(
      CommandSpec(
        aliases: const ['工作', 'work'],
        order: 10,
        helpLine: '工作 / work         赚取金币（消耗精力）',
        handler: (args) => CommandResult(text: work()),
      ),
    );
    registry.register(
      CommandSpec(
        aliases: const ['狩猎', 'hunt'],
        order: 11,
        helpLine: '狩猎 / hunt         野外狩猎（消耗精力）',
        handler: (args) => CommandResult(text: hunt()),
      ),
    );
    registry.register(
      CommandSpec(
        aliases: const ['贸易', 'trade'],
        order: 12,
        helpLine: '贸易 / trade        城市贸易（消耗精力）',
        handler: (args) => CommandResult(text: trade()),
      ),
    );
    registry.register(
      CommandSpec(
        aliases: const ['休息', 'rest'],
        order: 44,
        helpLine: '休息 / rest         恢复精力/饱食（花 2 金币）',
        handler: (args) => CommandResult(text: rest()),
      ),
    );
    registry.register(
      CommandSpec(
        aliases: const ['过月', 'advance'],
        order: 45,
        consumedTurn: true,
        helpLine: '过月 / advance      推进一个月',
        handler: (args) => CommandResult(text: advanceMonth(), consumedTurn: true),
      ),
    );
  }

}
