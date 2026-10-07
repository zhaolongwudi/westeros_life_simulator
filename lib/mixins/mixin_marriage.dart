/// 婚姻与家族培养混入（Batch 10-17）。
///
/// 在 [GameGenerationMixin]（立嗣/家谱/传承）之上深化：
/// - 婚姻系统：成婚（按身世类型）、配偶互动、婚后生育
/// - 子女培养：培养方向、亲自督导、送学城/骑士团
/// - 多代展示：世代谱系记录 + 家族树多代文本
///
/// 数据落在 Player.spouse / childRearing / generationRecords（模型字段），
/// 避免 flags 只存 bool 的限制（坑 16）。
library;

import '../data/balance_data.dart';
import '../models/marital.dart';
import '../core/command_registry.dart';
import '../core/monthly_pipeline.dart';
import '../providers/game_provider_base.dart';
import '../utils/command_alias.dart';
import '../utils/labels.dart';
import 'mixin_generation.dart';
import 'mixin_life.dart';

/// 婚姻与家族培养混入。挂在 [GameProviderBase] 上，
/// 依赖 [GameLifeMixin]（金币/声望/精力）与 [GameGenerationMixin]（addChild）。
mixin GameMarriageMixin
    on GameProviderBase, GameLifeMixin, GameGenerationMixin {
  /// 配偶身世中文名 → 枚举。
  SpouseOrigin? _originOf(String raw) {
    return switch (raw.trim()) {
      '平民' || 'commoner' => SpouseOrigin.commoner,
      '商人' || 'merchant' => SpouseOrigin.merchant,
      '战士' || 'warrior' || '骑士' => SpouseOrigin.warrior,
      '贵族' || 'noble' => SpouseOrigin.noble,
      _ => null,
    };
  }

  /// 配偶名池（按身世）。
  static const Map<SpouseOrigin, List<String>> kSpouseNamePool = {
    SpouseOrigin.noble: ['莱安娜', '亚莲恩', '玛格丽', '韦曼'],
    SpouseOrigin.commoner: ['梅拉', '珍妮', '贝丝', '哈拉'],
    SpouseOrigin.merchant: ['芙蕾雅', '玛拉', '伊莲', '赛拉'],
    SpouseOrigin.warrior: ['布蕾妮', '阿莎', '瓦莉', '多恩'],
  };

  /// 是否已婚。
  bool get isMarried => player.spouse != null || flagOf('isMarried');

  /// 配偶详情（可空）。
  SpouseDetail? get spouseDetail => player.spouse;

  /// 成婚：按身世类型娶/嫁一位配偶。
  ///
  /// 贵族联姻需声望 ≥40；婚礼开销与声望随身世变化（见 [SpouseDetail]）。
  /// 同一玩家只能成婚一次。返回叙事文本。
  String marry(String originStr) {
    if (isMarried) return '你已有家室，不可再娶/再嫁。';
    if (divorcedThisYear) {
      return '你今年方和离，名声未复。待来年风声过去，再谈婚嫁不迟。';
    }
    final origin = _originOf(originStr);
    if (origin == null) {
      return '你想与什么样的人成婚？可选：平民 / 商人 / 战士 / 贵族。';
    }
    if (origin == SpouseOrigin.noble && player.reputation < 40) {
      return '贵族联姻需要你拥有不低于 40 的声望。你此刻声名未显。';
    }
    final cost = origin.weddingCost;
    if (player.gold < cost) {
      return '婚礼需要 $cost 金币。你囊中羞涩，还不宜谈婚论嫁。';
    }
    final rnd = rng();
    final pool = kSpouseNamePool[origin]!;
    final spouseName = pool[rnd.nextInt(pool.length)];
    final spouse = SpouseDetail(
      name: spouseName,
      origin: origin,
      marriedYear: progress.year,
      familyId: origin == SpouseOrigin.noble ? player.familyId : '',
    );
    updatePlayer(
      player.copyWith(
        spouse: spouse,
        gold: player.gold - cost + origin.dowry,
        reputation: (player.reputation + origin.reputationBonus).clamp(0, 100),
        flags: {...player.flags, 'isMarried': true},
      ),
    );
    final dowryText = origin.dowry > 0 ? '，嫁妆 $origin.dowry 金币' : '';
    return '💒 你与「$spouseName」成婚（${spouseOriginLabel(origin)}），婚礼花去 $cost 金币$dowryText。'
        '声望 ${origin.reputationBonus > 0 ? '+' : ''}${origin.reputationBonus}。从此不再孤身一人。';
  }

  /// 配偶互动（每月 1 次，计数按「年-月」重置）：按身世与结婚年数产出叙事，恢复精力/心情。
  String spouseInteract() {
    if (!isMarried) return '你尚未成婚，何谈与配偶共处？先「求婚 平民」吧。';
    if (!_canSpouseDaily()) return '你本月已经与配偶相处够久了。';
    _recordSpouseDaily();
    final spouse = player.spouse!;
    final years = progress.year - spouse.marriedYear;
    final rnd = rng();
    final energyGain = 5 + rnd.nextInt(6);
    adjustEnergy(energyGain);
    final text = switch (spouse.origin) {
      SpouseOrigin.noble => '🏰 你与${spouse.name}共饮晚宴，聊起领地与朝局。他/她为你分忧，你也更安心了些。',
      SpouseOrigin.commoner => '🔥 炉火旁，${spouse.name}为你热了一壶酒。平凡日子里的安稳，最是暖人心。',
      SpouseOrigin.merchant => '💰 ${spouse.name}拿出账簿，与你盘算下一笔生意。家有一位精明的账房，何愁不富。',
      SpouseOrigin.warrior => '🛡️ ${spouse.name}陪你练了一回剑。有你并肩，谁敢欺你半分。',
    };
    return '$text 精力 +$energyGain。' '（结婚 ${years <= 0 ? '元年' : '$years 年'}）';
  }

  /// 婚后生育（月度钩子）：已婚且子女数低于上限时有概率添丁。
  ///
  /// 由 [GamePlayMixin.advanceMonth] 调用；返回追加叙事，未触发返回空串。
  String maybeFamilyEvent({int? seed}) {
    if (!isGameActive || isGameOver) return '';
    if (!isMarried) return '';
    final spouse = player.spouse!;
    final limit = spouse.origin.childLimit;
    if (player.children.length >= limit) return '';
    final rnd = rng(seed);
    if (rnd.nextDouble() > 0.25) return '';
    // 添丁：名字由配偶身世生成
    final pool = kSpouseNamePool[spouse.origin]!;
    final babyName = pool[rnd.nextInt(pool.length)] + '二世';
    addChild(babyName);
    // 送学子女的月度增益：声望稳步积累
    final schooled = player.childRearing.where((c) => c.sentToSchool).toList();
    if (schooled.isNotEmpty) {
      adjustReputation(1);
      return '👶 家中添丁：「$babyName」。${schooled.length} 位在学城/骑士团进修的子女学有所成，家族声望 +1。';
    }
    return '👶 家中添丁：「$babyName」。$houseName 家人丁兴旺。';
  }

  /// 为一名子女指定培养方向。
  ///
  /// 必须在子女列表中；方向限 sword/politics/speech/riding。
  ///
  /// 【S12-12】此前**只认英文键**、且把英文键回显给玩家：
  /// 玩家在技能面板看到的是「权谋」，照着输「培养 罗柏 权谋」却被拒
  /// （`valid.contains('权谋')` 恒 false），报错还写
  /// 「培养方向可选：sword / politics / speech / riding」。
  /// 与「旅行 白港」「训练 魔法」「使用 多恩红葡萄酒」同型。
  /// 现：入参走 [normalizeSkillAlias]（中英皆可），出参一律 [skillLabel]。
  String rearChild(String childName, String focus) {
    if (!player.children.contains(childName)) {
      return '「$childName」不是你的子女。';
    }
    const valid = {'sword', 'politics', 'speech', 'riding'};
    final picked = normalizeSkillAlias(focus);
    if (!valid.contains(picked)) {
      final names = valid.map(skillLabel).join(' / ');
      return '培养方向可选：$names。';
    }
    final index = player.childRearing.indexWhere((c) => c.name == childName);
    final records = List<ChildRearing>.from(player.childRearing);
    final cur = index >= 0 ? records[index] : ChildRearing(name: childName);
    if (index >= 0) {
      records[index] = cur.copyWith(focus: picked);
    } else {
      records.add(cur.copyWith(focus: picked));
    }
    updatePlayer(player.copyWith(childRearing: records));
    return '🎓 你为「$childName」定下培养方向：${skillLabel(picked)}。日后必成大器。';
  }

  /// 亲自督导一名子女（一次性，声望 +3，关系叙事）。
  String tutorChild(String childName) {
    if (!player.children.contains(childName)) {
      return '「$childName」不是你的子女。';
    }
    final index = player.childRearing.indexWhere((c) => c.name == childName);
    final records = List<ChildRearing>.from(player.childRearing);
    final cur = index >= 0 ? records[index] : ChildRearing(name: childName);
    if (cur.tutored) return '你已经亲自教导过「$childName」了。';
    if (index >= 0) {
      records[index] = cur.copyWith(tutored: true, reputationGain: cur.reputationGain + 3);
    } else {
      records.add(cur.copyWith(tutored: true, reputationGain: 3));
    }
    adjustReputation(3);
    updatePlayer(player.copyWith(childRearing: records));
    return '📜 你亲自督导「$childName」，言传身教。孩子受益匪浅，你的家风也为人称道。声望 +3。';
  }

  /// 送子女去学城/骑士团培养（一次性，声望 +5，此后每月 +1）。
  String sendChildToSchool(String childName) {
    if (!player.children.contains(childName)) {
      return '「$childName」不是你的子女。';
    }
    final index = player.childRearing.indexWhere((c) => c.name == childName);
    final records = List<ChildRearing>.from(player.childRearing);
    final cur = index >= 0 ? records[index] : ChildRearing(name: childName);
    if (cur.sentToSchool) return '「$childName」已在学城/骑士团进修。';
    if (index >= 0) {
      records[index] = cur.copyWith(
        sentToSchool: true,
        reputationGain: cur.reputationGain + 5,
      );
    } else {
      records.add(cur.copyWith(sentToSchool: true, reputationGain: 5));
    }
    adjustReputation(5);
    updatePlayer(player.copyWith(childRearing: records));
    return '🏫 你送「$childName」前往学城/骑士团进修。家族门楣添光，声望 +5。';
  }

  /// 家族树多代展示：当前家主 + 配偶 + 世代谱系 + 子女培养。
  String formatMultiGenTree() {
    final p = player;
    final buf = StringBuffer()
      ..writeln('【家族树 · $houseName】\n『当前』')
      ..writeln('· 家主：${p.name}（${identityLabel(p.identity)}，${p.age}岁）');
    if (isMarried) {
      final s = p.spouse!;
      buf.writeln('· 配偶：${s.name}（${spouseOriginLabel(s.origin)}，结缡 ${progress.year - s.marriedYear} 年）');
    }
    if (p.children.isNotEmpty) {
      buf.writeln('· 子女：');
      for (final c in p.children) {
        final rearing = p.childRearing.where((r) => r.name == c).toList();
        final focus = rearing.isNotEmpty && rearing.first.focus.isNotEmpty
            ? '·方向 ${skillLabel(rearing.first.focus)}'
            : '';
        final school = rearing.isNotEmpty && rearing.first.sentToSchool ? '·进修' : '';
        buf.writeln('  - $c$focus$school');
      }
      final heir = heirName;
      if (heir != null) buf.writeln('· 继承人：$heir');
    } else {
      buf.writeln('· 子女：尚无子嗣');
    }
    if (p.generationRecords.isNotEmpty) {
      buf.writeln('『历代』');
      for (final g in p.generationRecords) {
        buf.writeln(
            '· 第${g.generation}代 ${g.name}（${g.title}，${g.reignYears}）${g.achievement.isNotEmpty ? '：${g.achievement}' : ''}');
      }
    }
    return buf.toString().trim();
  }

  // ==================== 每月配偶互动计数（独立于其它 mixin，坑 16） ====================
  static const int kSpouseDailyLimit = BalanceData.spouseDailyLimit;
  int _spouseDailyCount = 0;
  String? _spouseDailyMonth;
  bool _canSpouseDaily() {
    _rollSpouseDaily();
    return _spouseDailyCount < kSpouseDailyLimit;
  }
  void _recordSpouseDaily() {
    _rollSpouseDaily();
    _spouseDailyCount++;
  }
  void _rollSpouseDaily() {
    final today = '${progress.year}-${progress.month}';
    if (_spouseDailyMonth != today) {
      _spouseDailyMonth = today;
      _spouseDailyCount = 0;
    }
  }

  // ==================== Batch 10-25：婚姻系统二轮 ====================
  // 离婚/丧偶、配偶谈心（好感度）、婚后月度事件、婚姻面板。

  /// 离婚补偿金（防无限再婚刷声望：每次离婚耗金币且当年不可再婚）。
  static const int kDivorceCost = BalanceData.divorceCost;

  /// 配偶谈心每月次数上限。
  static const int kSpouseChatDailyLimit = BalanceData.spouseChatDailyLimit;

  /// 夫妻感情等级标签。
  String affectionLabel(int affection) => BalanceData.affectionLabel(affection);

  /// 调整夫妻感情（clamp 0~100）。
  void adjustSpouseAffection(int delta) {
    final s = player.spouse;
    if (s == null) return;
    final newAff = (s.affection + delta).clamp(0, 100);
    updatePlayer(player.copyWith(
      spouse: s.copyWith(affection: newAff),
    ));
  }

  /// 感情是否疏离（<30）：互动/事件效果减半。
  bool get spouseAlienated {
    final s = spouseDetail;
    return s != null && s.affection < BalanceData.spouseHarmoniousAffection;
  }

  /// 感情是否恩爱（>=70）：事件触发率与效果加成。
  bool get spouseDevoted {
    final s = spouseDetail;
    return s != null && s.affection >= BalanceData.spouseDevotedAffection;
  }

  /// 离婚：解除婚姻，补偿配偶，声望受损，当年不可再婚。
  ///
  /// 返回叙事文本；未婚/不足一年/金币不足返回提示。
  String divorce() {
    if (!isMarried) return '你尚未成婚，何谈离婚？';
    final s = player.spouse!;
    if (progress.year - s.marriedYear < 1) {
      return '你们成婚不足一年，就这样离散，名声有损。再等等吧。';
    }
    if (player.gold < kDivorceCost) {
      return '离婚需要 $kDivorceCost 金币作为补偿。你囊中羞涩。';
    }
    gainGold(-kDivorceCost);
    adjustReputation(-10);
    updatePlayer(player.copyWith(
      clearSpouse: true,
      flags: {...player.flags, 'isMarried': false, 'divorceYear': true},
    ));
    return '💔 你与「${s.name}」和离。补偿 $kDivorceCost 金币，付之一炬的还有昔年情分（声望 -10）。'
        '一别两宽，各生欢喜。';
  }

  /// 是否当年已离婚（再婚冷却一年）。
  bool get divorcedThisYear => flagOf('divorceYear');

  /// 丧偶：配偶离世，婚姻解除；贵族联姻的世家纽带断裂（声望损失）。
  ///
  /// 返回叙事文本；未婚返回提示。已婚玩家在月度结算中被触发。
  String spousePassesAway() {
    if (!isMarried) return '你并无配偶，何来丧偶。';
    final s = player.spouse!;
    final repDelta = s.origin == SpouseOrigin.noble ? -5 : 0;
    updatePlayer(player.copyWith(
      clearSpouse: true,
      flags: {...player.flags, 'isMarried': false, 'widowed': true},
    ));
    if (repDelta != 0) adjustReputation(repDelta);
    return '🕯️ 你的配偶「${s.name}」溘然长逝，你为其守灵七日，泣不成声。'
        '${repDelta != 0 ? '世家联姻的纽带也随之中断（声望 -5）。' : ''}愿你安息。';
  }

  /// 配偶谈心：按身世 × 话题给出回应，增进夫妻感情。
  ///
  /// 话题可选：'朝局' / '家业' / '江湖' / '家常'（缺省随机）。
  /// 每月限 [kSpouseChatDailyLimit] 次。恩爱加成（好感 +5，否则 +3）。
  String spouseChat([String? topic]) {
    if (!isMarried) return '你尚未成婚。先去「求婚 平民」找个知心人吧。';
    if (!_canSpouseChat()) return '你们本月已经说了很多知心话。下月再聊吧。';
    _recordSpouseChat();
    final s = player.spouse!;
    final t = topic?.trim();
    final normalized = (t == null || t.isEmpty)
        ? _randomChatTopic()
        : (t.contains('朝') || t.contains('政') ? '朝局'
            : t.contains('家') || t.contains('业') ? '家业'
            : t.contains('江湖') || t.contains('冒险') || t.contains('闯荡') ? '江湖'
            : '家常');
    final text = switch (s.origin) {
      SpouseOrigin.noble => _nobleChat(normalized, s.name),
      SpouseOrigin.commoner => _commonerChat(normalized, s.name),
      SpouseOrigin.merchant => _merchantChat(normalized, s.name),
      SpouseOrigin.warrior => _warriorChat(normalized, s.name),
    };
    final gain = spouseDevoted ? 5 : 3;
    adjustSpouseAffection(gain);
    return '$text\n（与「${s.name}」的感情 +$gain，当前 ${affectionLabel(s.affection + gain > 100 ? 100 : s.affection + gain)}）';
  }

  String _randomChatTopic() {
    const topics = ['朝局', '家业', '江湖', '家常'];
    return topics[rng().nextInt(topics.length)];
  }

  String _nobleChat(String topic, String name) {
    return switch (topic) {
      '朝局' => '🏰 $name 抚着家徽低声道：「铁王座上的风暴从未平息。你我需步步为营。」',
      '家业' => '👑 $name 与你讨论封地收成与税赋：「领民安，则家族安。」',
      '江湖' => '⚔️ $name 听你讲游历见闻，眼中闪烁：「等局势安定，我也想去看看你说的山川。」',
      _ => '🕯️ 炉火旁，$name 与你共读一卷旧史，家族的荣光在纸页间流淌。',
    };
  }

  String _commonerChat(String topic, String name) {
    return switch (topic) {
      '朝局' => '🍞 $name 摆摆手：「老爷们的事我们管不着，日子过踏实就好。」',
      '家业' => '🔥 $name 缝着衣裳笑道：「等你回来，饭总是热的。」',
      '江湖' => '🌾 $name 摇摇头：「外面凶险，你却总爱往外跑。平安回来就好。」',
      _ => '🐔 $name 说起邻家趣事，鸡毛蒜皮里都是烟火气。',
    };
  }

  String _merchantChat(String topic, String name) {
    return switch (topic) {
      '朝局' => '💰 $name 拨着算盘：「仗一打，粮价就涨。咱们得囤些货。」',
      '家业' => '📜 $name 摊开账本：「这条商路若打通，够家里宽裕十年。」',
      '江湖' => '🐎 $name 笑道：「你那趟买卖若带我同去，准能多赚三成。」',
      _ => '🍷 $name 为你斟酒：「生意场上见惯冷暖，只有你，是真心待我。」',
    };
  }

  String _warriorChat(String topic, String name) {
    return switch (topic) {
      '朝局' => '🛡️ $name 握紧剑柄：「乱世将至，护好这个家，比什么都强。」',
      '家业' => '🗡️ $name 擦拭兵刃：「孩子们该学武了。这世道，拳头才靠得住。」',
      '江湖' => '⚡ $name 眼睛一亮：「下次闯荡，带上我。我还没见过你说的战场。」',
      _ => '🔥 $name 替你按了按肩膀：「受了伤别硬撑。有我在。」',
    };
  }

  // ==================== 谈心每月计数（独立前缀 _b1025，坑 16） ====================

  int _b1025ChatCount = 0;
  String? _b1025ChatMonth;

  bool _canSpouseChat() {
    _b1025RollChat();
    return _b1025ChatCount < kSpouseChatDailyLimit;
  }

  void _recordSpouseChat() {
    _b1025RollChat();
    _b1025ChatCount++;
  }

  void _b1025RollChat() {
    final today = '${progress.year}-${progress.month}';
    if (_b1025ChatMonth != today) {
      _b1025ChatMonth = today;
      _b1025ChatCount = 0;
    }
  }

  /// 跨年清除离婚标记（再婚冷却一年，满一年后允许再婚）。
  ///
  /// 由 [GamePlayMixin.advanceMonth] 在 `advanceTime()` 之后调用。
  /// 判断条件：当前月份为 1（即刚跨年）且 `divorceYear` flag 为 true。
  void maybeClearDivorceFlag() {
    if (flagOf('divorceYear') && progress.month == 1) {
      final newFlags = Map<String, bool>.from(player.flags);
      newFlags.remove('divorceYear');
      updatePlayer(player.copyWith(flags: newFlags));
    }
  }

  // ==================== 婚后月度事件（Batch 10-25） ====================

  /// 婚后月度事件：按身世触发专属家宅事件（恢复/增益），感情恩爱时效果更强。
  ///
  /// 由 [GamePlayMixin.advanceMonth] 调用；未触发返回空串。
  /// 25% 概率触发；恩爱（感情>=70）时概率提升至 35%。
  String maybeSpouseMonthlyEvent({int? seed}) {
    if (!isGameActive || isGameOver) return '';
    if (!isMarried) return '';
    final s = player.spouse!;
    final rnd = rng(seed);
    final chance = spouseDevoted ? 0.35 : 0.25;
    if (rnd.nextDouble() > chance) return '';
    final text = switch (s.origin) {
      SpouseOrigin.noble => _nobleMonthly(s.name),
      SpouseOrigin.commoner => _commonerMonthly(s.name),
      SpouseOrigin.merchant => _merchantMonthly(s.name),
      SpouseOrigin.warrior => _warriorMonthly(s.name),
    };
    adjustSpouseAffection(spouseDevoted ? 4 : 2);
    return text;
  }

  String _nobleMonthly(String name) {
    final repGain = spouseDevoted ? 4 : 2;
    adjustReputation(repGain);
    return '🏯 $name 打理封地井井有条，又在朝中为你周旋。家族声望 +$repGain。';
  }

  String _commonerMonthly(String name) {
    final gain = spouseDevoted ? 18 : 10;
    adjustEnergy(gain);
    return '🍲 $name 起早贪黑打理家务，为你备好热饭暖汤。精力恢复 $gain。';
  }

  String _merchantMonthly(String name) {
    final goldGain = spouseDevoted ? 25 : 15;
    gainGold(goldGain);
    return '💰 $name 的商队捎回一笔红利，账上多了 $goldGain 金币。';
  }

  String _warriorMonthly(String name) {
    final gain = spouseDevoted ? 20 : 10;
    adjustEnergy(gain);
    adjustHealth(spouseDevoted ? 3 : 1);
    return '🛡️ $name 夜里替你巡守，又拉你晨练。精力恢复 $gain，身体也硬朗了些。';
  }

  /// 婚姻面板：配偶 / 感情 / 子女培养完整展示。
  String formatMarriagePanel() {
    final p = player;
    final buf = StringBuffer()..writeln('【婚姻】');
    if (!isMarried || p.spouse == null) {
      buf.writeln('· 状态：未婚');
      buf.writeln('· 可尝试「求婚 平民/商人/战士/贵族」。');
      return buf.toString().trim();
    }
    final s = p.spouse!;
    final years = progress.year - s.marriedYear;
    buf.writeln('· 配偶：${s.name}（${spouseOriginLabel(s.origin)}，结缡 ${years <= 0 ? '元年' : '$years 年'}）');
    buf.writeln('· 感情：${s.affection}/100（${affectionLabel(s.affection)}）');
    if (s.familyId.isNotEmpty) {
      final fam = familyById(s.familyId);
      if (fam != null) buf.writeln('· 联姻家族：${fam.name}');
    }
    if (p.children.isEmpty) {
      buf.writeln('· 子女：尚无子嗣');
    } else {
      buf.writeln('· 子女：${p.children.join('、')}');
      final rearing = p.childRearing;
      if (rearing.isNotEmpty) {
        buf.writeln('· 培养档案：');
        for (final r in rearing) {
          final bits = <String>[];
          if (r.focus.isNotEmpty) bits.add('方向 ${skillLabel(r.focus)}');
          if (r.tutored) bits.add('已督导');
          if (r.sentToSchool) bits.add('在学城/骑士团进修');
          buf.writeln('  - ${r.name}${bits.isEmpty ? '' : '（${bits.join('、')}）'}');
        }
      }
    }
    return buf.toString().trim();
  }

  // ==================== M3 · 指令自注册 ====================

  /// 把本领域指令注册进注册表（order 与历史帮助文本顺序一致）。
  void registerMarriageCommands(CommandRegistry registry) {
    registry.register(
      CommandSpec(
        aliases: const ['求婚', '成婚', 'marry'],
        order: 34,
        requiredArgCount: 1,
        missingArgsHint: '想与什么样的人成婚？如「求婚 平民」或「成婚 贵族」。',
        helpLine: '求婚 / marry [身世]   成婚（平民/商人/战士/贵族，如 求婚 平民）',
        handler: (args) => CommandResult(text: marry(args)),
      ),
    );
    registry.register(
      CommandSpec(
        aliases: const ['配偶', '共处', 'spouse'],
        order: 35,
        helpLine: '配偶 / spouse       与配偶共处（每月 1 次，恢复精力）',
        handler: (args) => CommandResult(text: spouseInteract()),
      ),
    );
    registry.register(
      CommandSpec(
        aliases: const ['婚姻', '婚姻面板', 'marriage'],
        order: 36,
        helpLine: '婚姻 / marriage     查看婚姻面板（配偶/感情/子女培养）',
        handler: (args) => CommandResult(text: formatMarriagePanel()),
      ),
    );
    registry.register(
      CommandSpec(
        aliases: const ['私语', '谈心', 'chatspouse'],
        order: 37,
        helpLine: '私语 / chatspouse [话题]  与配偶谈心（每月 2 次，增进感情）',
        handler: (args) => CommandResult(text: spouseChat(args.isEmpty ? null : args)),
      ),
    );
    registry.register(
      CommandSpec(
        aliases: const ['离婚', 'divorce'],
        order: 38,
        helpLine: '离婚 / divorce      解除婚姻（需结婚满一年，耗 30 金币、声望 -10）',
        handler: (args) => CommandResult(text: divorce()),
      ),
    );
    registry.register(
      CommandSpec(
        aliases: const ['丧偶', 'widow'],
        order: 39,
        helpLine: '丧偶 / widow        配偶离世（解除婚姻，贵族联姻声望 -5）',
        handler: (args) => CommandResult(text: spousePassesAway()),
      ),
    );
    registry.register(
      CommandSpec(
        aliases: const ['培养', 'rear'],
        order: 40,
        requiredArgCount: 2,
        missingArgsHint: '培养谁、往哪个方向？如「培养 罗柏 剑术」。方向：剑术 / 权谋 / 口才 / 骑术。',
        helpLine: '培养 / rear [子女] [方向] 为子女定培养方向（剑术/权谋/口才/骑术）',
        handler: (args) {
          final parts = args.split(RegExp(r'\s+'));
          return CommandResult(text: rearChild(parts.first, parts[1]));
        },
      ),
    );
    registry.register(
      CommandSpec(
        aliases: const ['督导', 'tutor'],
        order: 41,
        requiredArgCount: 1,
        missingArgsHint: '亲自督导哪个子女？如「督导 罗柏」。',
        helpLine: '督导 / tutor [子女]  亲自督导子女（声望 +3）',
        handler: (args) => CommandResult(text: tutorChild(args)),
      ),
    );
    registry.register(
      CommandSpec(
        aliases: const ['送学', 'school'],
        order: 42,
        requiredArgCount: 1,
        missingArgsHint: '送哪个子女去学城/骑士团？如「送学 罗柏」。',
        helpLine: '送学 / school [子女] 送子女去学城/骑士团进修（声望 +5）',
        handler: (args) => CommandResult(text: sendChildToSchool(args)),
      ),
    );
    registry.register(
      CommandSpec(
        aliases: const ['家族树', '谱系', 'tree'],
        order: 43,
        helpLine: '家族树 / tree       查看家族树多代谱系',
        handler: (args) => CommandResult(text: formatMultiGenTree()),
      ),
    );
  }
  // ==================== M3 · 月度结算管线自注册 ====================

  /// 把本领域（婚后生育 + 家宅月度事件）钩子注册进管线。
  void registerMarriageMonthlyHooks(MonthlyPipeline pipeline) {
    pipeline.register(
      MonthlyHookSpec(
        id: 'family_event',
        phase: MonthlyPhase.beforeAdvance,
        order: 6,
        outputOrder: 5,
        hook: () => MonthlyHookResult(
          text: maybeFamilyEvent(seed: progress.turnCount),
          outputOrder: 5,
        ),
      ),
    );
    pipeline.register(
      MonthlyHookSpec(
        id: 'spouse_monthly',
        phase: MonthlyPhase.beforeAdvance,
        order: 7,
        outputOrder: 6,
        hook: () => MonthlyHookResult(
          text: maybeSpouseMonthlyEvent(seed: progress.turnCount),
          outputOrder: 6,
        ),
      ),
    );
  }
}
