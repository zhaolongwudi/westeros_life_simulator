/// 日常玩法混入：训练、工作、休息、狩猎、贸易、月度循环。
///
/// 参考 docs/08_玩法设计.md「核心玩法」。
library;

import 'dart:math';

import '../models/location.dart';
import '../models/player.dart';
import '../providers/game_provider_base.dart';
import 'mixin_systems.dart';

/// 日常玩法混入。挂在 [GameProviderBase] 上。
///
/// [advanceMonth] 需要调用 [GameSystemsMixin.applyMonthlySystems]，
/// 因此 on 约束中列出 GameSystemsMixin。
mixin GamePlayMixin on GameProviderBase, GameSystemsMixin {
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
  /// 返回叙事文本；每天最多 [kDailyLimits] 次，防刷。
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

    // 成长：10 级封顶，越接近上限成功率越低（防止无限刷）。
    final chance = 0.8 - (current * 0.05);
    _recordDaily('train');

    if (rnd.nextDouble() < chance) {
      final newSkills = Map<String, int>.from(player.skills);
      newSkills[skillName] = current + 1;
      updatePlayer(player.copyWith(skills: newSkills));
      return '你苦练「$skillName」，技艺精进！（$current → ${current + 1}）';
    }
    return '你练了一整天「$skillName」，但收效甚微。（$current 级，下次再试）';
  }

  /// 休息：恢复精力（目前以金币小额消耗 + 叙事呈现）。
  String rest() {
    if (player.gold < 2) {
      return '你太穷了，连一顿像样的饭都吃不起。找个地方蜷缩着睡了一夜。';
    }
    gainGold(-2);
    return '你在旅店歇了一晚，吃了顿热饭，花去 2 金币。明日再战。';
  }

  /// 工作：按身份/技能赚取金币。
  String work() {
    if (!_canDoDaily('work')) {
      return '今天的活计已经干完了。';
    }
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
    return '你忙碌了一天，挣得 $total 金币。（${player.identity.name}，'
        '技能加成 ${speechBonus + swordBonus}）';
  }

  /// 狩猎：按剑术/弓箭技能赚取金币，有失败风险。
  String hunt() {
    if (!_canDoDaily('hunt')) {
      return '今天的猎物已经够多了。';
    }
    _recordDaily('hunt');
    final rnd = rng();
    final loc = currentLocation;
    if (loc == null) return '你身处荒野之外，无从狩猎。';
    if (loc.type == LocationType.city) return '城市里无猎可狩。你需要去野外。';

    final skill = max(skillLevel('archery'), skillLevel('sword'));
    final danger = loc.dangerLevel;
    // 成功率：技能与危险度对抗
    final successChance = (0.5 + skill * 0.05 - danger * 0.03).clamp(0.1, 0.95);

    if (rnd.nextDouble() < successChance) {
      final reward = 10 + skill * 3 + rnd.nextInt(10);
      gainGold(reward);
      return '你在${loc.name}附近的林地猎到猎物，收获 $reward 金币。';
    }
    // 失败：危险度高时可能受伤（掉血由 flags 模拟）
    if (rnd.nextDouble() < 0.3) {
      setFlag('isInjured', true);
      return '狩猎时你失手摔伤，空手而归。（受了点轻伤）';
    }
    return '你在${loc.name}附近转了一天，什么也没猎到。';
  }

  /// 贸易：按地点类型/商人身份赚取金币。
  String trade() {
    if (!_canDoDaily('trade')) {
      return '今天的集市已经散了。';
    }
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

  /// 月度循环：推进一个月，结算系统演进。
  ///
  /// 返回本月的完整叙事（含系统结算），供 UI/AI 展示。
  String advanceMonth() {
    if (!isGameActive || isGameOver) return '游戏尚未开始。';
    final monthText = applyMonthlySystems(seed: progress.turnCount);
    advanceTime();
    final buf = StringBuffer()
      ..writeln('⏳ 时间推进到 ${progress.year}年${progress.month}月（${progress.season}）');
    if (monthText.isNotEmpty) {
      buf.writeln(monthText);
    }
    final loc = currentLocation;
    if (loc != null) {
      buf.writeln('你身处 ${loc.name}（${loc.region}）。');
    }
    return buf.toString().trim();
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
      ..writeln('· ${p.name}（${p.identity.name}），${p.age}岁，${p.gender == 'male' ? '男' : '女'}')
      ..writeln('· 家族：${fam?.name ?? '无'}（${fam?.motto ?? ''}）')
      ..writeln('· 地点：${loc?.name ?? p.locationId}（${loc?.region ?? ''}）')
      ..writeln('· 金币：${p.gold}｜声望：${p.reputation}')
      ..writeln('· 属性：${p.attributes.entries.map((e) => '${e.key} ${e.value}').join(' ')}')
      ..writeln('· 技能：${p.skills.entries.map((e) => '${e.key} ${e.value}').join(' ')}');
    return buf.toString().trim();
  }
}