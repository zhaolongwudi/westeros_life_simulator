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

import '../models/marital.dart';
import '../providers/game_provider_base.dart';
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
    return '💒 你与「$spouseName」成婚（${origin.name}），婚礼花去 $cost 金币$dowryText。'
        '声望 ${origin.reputationBonus > 0 ? '+' : ''}${origin.reputationBonus}。从此不再孤身一人。';
  }

  /// 配偶互动（每日 1 次）：按身世与结婚年数产出叙事，恢复精力/心情。
  String spouseInteract() {
    if (!isMarried) return '你尚未成婚，何谈与配偶共处？先「求婚 平民」吧。';
    if (!_canSpouseDaily()) return '你今天已经与配偶相处够久了。';
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
    final limit = spouse.childLimit;
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
  String rearChild(String childName, String focus) {
    if (!player.children.contains(childName)) {
      return '「$childName」不是你的子女。';
    }
    const valid = {'sword', 'politics', 'speech', 'riding'};
    if (!valid.contains(focus)) {
      return '培养方向可选：sword / politics / speech / riding。';
    }
    final index = player.childRearing.indexWhere((c) => c.name == childName);
    final records = List<ChildRearing>.from(player.childRearing);
    final cur = index >= 0 ? records[index] : ChildRearing(name: childName);
    if (index >= 0) {
      records[index] = cur.copyWith(focus: focus);
    } else {
      records.add(cur.copyWith(focus: focus));
    }
    updatePlayer(player.copyWith(childRearing: records));
    return '🎓 你为「$childName」定下培养方向：$focus。日后必成大器。';
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
      ..writeln('· 家主：${p.name}（${p.identity.name}，${p.age}岁）');
    if (isMarried) {
      final s = p.spouse!;
      buf.writeln('· 配偶：${s.name}（${s.origin.name}，结缡 ${progress.year - s.marriedYear} 年）');
    }
    if (p.children.isNotEmpty) {
      buf.writeln('· 子女：');
      for (final c in p.children) {
        final rearing = p.childRearing.where((r) => r.name == c).toList();
        final focus = rearing.isNotEmpty && rearing.first.focus.isNotEmpty
            ? '·方向 ${rearing.first.focus}'
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

  // ==================== 每日配偶互动计数（独立于其它 mixin，坑 16） ====================
  static const int kSpouseDailyLimit = 1;
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
}