/// 家族继承与多世代混入（Batch 10-14）。
///
/// 提供：
/// - 子女管理：addChild / childNames / formatFamilyTree
/// - 继承人选定：heirName（长子优先，其次记录顺序）
/// - 世代传承：advanceGeneration（玩家死亡后切换继承人，传承家业）
/// - 传位叙事：maybeSuccessionStory（年长/濒死时提示立嗣）
library;

import '../models/marital.dart';
import '../models/player.dart';
import '../providers/game_provider_base.dart';
import 'mixin_life.dart';

/// 家族继承混入。挂在 [GameProviderBase] 上，依赖 [GameLifeMixin]
/// （使用 adjustHealth/isAlive 等生存能力判断死亡/濒死）。
mixin GameGenerationMixin on GameProviderBase, GameLifeMixin {
  /// 玩家是否已死亡（由生存系统置 isAlive=false）。
  bool get isDead => !(player.flags['isAlive'] ?? true);
  /// 玩家是否年长（≥55 岁，触发立嗣提示）。
  bool get isElder => player.age >= 55;
  /// 玩家是否濒死（健康 < 20，触发立嗣提示）。
  bool get isDying => player.health < 20;

  /// 玩家姓氏（house 或家族名或 '自由民'）。
  String get houseName {
    if (player.house.isNotEmpty) return player.house;
    final fam = playerFamily;
    return fam?.name ?? '自由民';
  }

  /// 添加一名子女（children 直接存名字，避免 flags 只存 bool 的限制）。
  ///
  /// 返回叙事文本；名字为空/重复返回提示。
  String addChild(String childName) {
    final name = childName.trim();
    if (name.isEmpty) return '给子女起个名字吧。';
    if (player.children.contains(name)) {
      return '「$name」已经是你的子女了。';
    }
    final children = List<String>.from(player.children)..add(name);
    updatePlayer(player.copyWith(children: children));
    return '👶 你的家族添了新丁：「$name」（$houseName 家）。';
  }

  /// 子女名字列表（只读，按记录顺序）。
  List<String> get childNames => List<String>.unmodifiable(player.children);

  /// 继承人：长子优先（children 中第一个未死亡/未流放的）。
  ///
  /// 无子女返回 null。
  String? get heirName {
    for (final name in player.children) {
      if (!flagOf('house.childDead.$name') && !flagOf('house.childExiled.$name')) {
        return name;
      }
    }
    return null;
  }

  /// 家谱文本：玩家 + 婚姻 + 子女 + 继承人。
  ///
  /// 用于「家谱」指令与玩家面板家族树区块。
  String formatFamilyTree() {
    final p = player;
    final buf = StringBuffer()
      ..writeln('【家谱】${houseName}家')
      ..writeln('· 家主：${p.name}（${p.identity.name}，${p.age}岁）');
    buf.writeln('· 婚姻：${flagOf('isMarried') ? '已婚' : '未婚'}');
    if (p.children.isEmpty) {
      buf.writeln('· 子女：尚无子嗣');
    } else {
      buf.writeln('· 子女：${p.children.join('、')}');
      final heir = heirName;
      buf.writeln(heir == null ? '· 继承人：暂无（子女皆亡或流放）' : '· 继承人：$heir');
    }
    return buf.toString().trim();
  }

  /// 世代传承：玩家死亡后切换继承人，开启新一代。
  ///
  /// - 有继承人：创建新 Player（继承家族/金币/部分声望/家谱），
  ///   年龄 16 继位，保留进度时间，游戏继续。
  /// - 无继承人：家族血脉断绝，游戏结束（返回 null）。
  ///
  /// 返回新玩家；无继承人返回 null（游戏结束）。
  Player? advanceGeneration() {
    final heir = heirName;
    if (heir == null) return null;
    final p = player;
    // 继承家业：一半金币、声望折半、技能继承 60%
    final inheritedGold = p.gold ~/ 2;
    final inheritedRep = (p.reputation / 2).round();
    final newSkills = <String, int>{};
    for (final entry in p.skills.entries) {
      newSkills[entry.key] = (entry.value * 0.6).round();
    }
    final isNoble = p.identity == PlayerIdentity.noble;
    // 现任家主记入历代谱系（Batch 10-17 多代展示）
    final prevRecords = List<GenerationRecord>.from(p.generationRecords);
    final currentGen = prevRecords.length + 1;
    prevRecords.add(
      GenerationRecord(
        generation: currentGen,
        name: p.name,
        reignYears: '${p.age}岁继位',
        title: p.title.isEmpty ? p.identity.name : p.title,
        achievement: p.reputation >= 70 ? '声望 ${p.reputation}' : '',
      ),
    );
    final newPlayer = Player(
      id: 'player_${houseName}_$heir',
      name: heir,
      identity: isNoble ? PlayerIdentity.noble : p.identity,
      familyId: p.familyId,
      age: 16, // 继承人成年即继位
      gender: p.gender,
      locationId: p.locationId,
      gold: inheritedGold,
      reputation: inheritedRep,
      skills: newSkills,
      attributes: Map<String, int>.from(p.attributes),
      inventory: List<String>.from(p.inventory),
      relations: Map<String, int>.from(p.relations),
      flags: <String, bool>{
        ...p.flags,
        'isAlive': true,
        'isExiled': false,
        'generation': true, // 已传承，标记多世代
        'inherited': true,
      },
      health: 100,
      energy: 100,
      hunger: 60,
      title: '',
      house: houseName,
      children: const [],
      // 谱系透传给新家主（历代记录延续）
      generationRecords: prevRecords,
    );
    // 标记继承人为已继位（从后续继承人候选中移除）
    setFlag('house.childDead.$heir', true);
    // 直接切换为继承者（行动方法风格：调用即生效）
    updatePlayer(newPlayer);
    return newPlayer;
  }

  /// 当前世代数（1 起；世代谱系 N 条即第 N+1 代，更精确表达三代以上）。
  ///
  /// 旧实现 `flagOf('generation') ? 2 : 1` 只能表达 1/2 两档（坑 24：
  /// 三代以上显示错误），现以 generationRecords 长度 + 1 计算。
  int generationNumber() {
    final records = player.generationRecords.length;
    if (records > 0) return records + 1;
    return flagOf('generation') ? 2 : 1;
  }

  /// 传位叙事：年长或濒死时提示立嗣/传承。
  ///
  /// 返回追加到月度叙事的文本；不触发返回空串。
  String maybeSuccessionStory() {
    if (!isGameActive || isGameOver) return '';
    if (isDead) return '';
    if (player.children.isEmpty) return '';
    final heir = heirName;
    if (heir == null) return '';
    final buf = StringBuffer();
    if (isElder) {
      buf.writeln('👑 你年事已高，是时候考虑传承了。继承人「$heir」已成年，可随时继位。');
    }
    if (isDying) {
      buf.writeln('⚰️ 你的身体每况愈下。若你不幸离世，「$heir」将继承你的家业。');
    }
    return buf.toString().trim();
  }
}