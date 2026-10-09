/// 家族继承与多世代混入（Batch 10-14）。
///
/// 提供：
/// - 子女管理：addChild / childNames / formatFamilyTree
/// - 继承人选定：heirName（长子优先，其次记录顺序）
/// - 世代传承：advanceGeneration（玩家死亡后切换继承人，传承家业）
/// - 传位叙事：maybeSuccessionStory（年长/濒死时提示立嗣）
library;

import '../data/balance_data.dart';
import '../models/marital.dart';
import '../models/player.dart';
import '../core/command_registry.dart';
import '../core/monthly_pipeline.dart';
import '../providers/game_provider_base.dart';
import '../utils/labels.dart';
import 'mixin_life.dart';

/// 家族继承混入。挂在 [GameProviderBase] 上，依赖 [GameLifeMixin]
/// （使用 adjustHealth/isAlive 等生存能力判断死亡/濒死）。
mixin GameGenerationMixin on GameProviderBase, GameLifeMixin {
  /// 玩家是否已死亡（由生存系统置 isAlive=false）。
  bool get isDead => !(player.flags['isAlive'] ?? true);
  /// 玩家是否年长（≥55 岁，触发立嗣提示）。
  bool get isElder => player.age >= BalanceData.elderAge;
  /// 玩家是否濒死（健康 < 20，触发立嗣提示）。
  bool get isDying => player.health < BalanceData.dyingHealth;

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
      ..writeln('· 家主：${p.name}（${identityLabel(p.identity)}，${p.age}岁）');
    // S13-1②：与 `GameMarriageMixin.isMarried` 的**单真相源**对齐（该 getter
    // 已收敛为 `player.spouse != null`）。本 mixin 的 `on` 约束不含 marriage、
    // 取不到该 getter，故直接读同一真相源，避免「已婚但无配偶」的矛盾态
    // 在家谱上仍被显示成「已婚」。
    buf.writeln('· 婚姻：${p.spouse != null ? '已婚' : '未婚'}');
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
    // S14-1：世代号取「最后一条记录的代数 + 1」，**不再用列表长度 + 1**。
    // 原因：下方按 `generationRecordCap` 裁剪后，列表长度与真实代数脱钩
    // （裁到只剩最近 20 条时，第 35 代玩家的 length 仍是 20 ⇒ 用 length
    // 会显示「第 21 代」）。`generation` 是 `GenerationRecord` 自带的字段，
    // 本就是权威代数来源。此前该上限常量声明了却从未被引用（纯摆设），
    // 存档随传承次数线性膨胀。
    final currentGen = prevRecords.isEmpty ? 1 : prevRecords.last.generation + 1;
    prevRecords.add(
      GenerationRecord(
        generation: currentGen,
        name: p.name,
        reignYears: '${p.age}岁继位',
        title: p.title.isEmpty ? identityLabel(p.identity) : p.title,
        achievement: p.reputation >= 70 ? '声望 ${p.reputation}' : '',
      ),
    );
    // S14-1：落实 `generationRecordCap` 声明的「环形上限（防存档线性膨胀）」。
    // 保留**最近 N 条**（最新的代数在尾部），早期记录不再进入存档。
    if (prevRecords.length > BalanceData.generationRecordCap) {
      prevRecords.removeRange(
        0,
        prevRecords.length - BalanceData.generationRecordCap,
      );
    }
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
        // S13-1②：配偶（[Player.spouse]）**不随传承下行**——上面既没传
        // `spouse`，这里就必须把 `isMarried` 一并清掉。`isMarried` getter 是
        // `spouse != null || flagOf('isMarried')` 的**双真相源**，只带 flags 不带
        // spouse 会让新家主处于「已婚但无配偶」的矛盾态；次月
        // `maybeFamilyEvent` 的 `player.spouse!` 即抛 `StateError`，而
        // `MonthlyPipeline.runPhase` 无 try/catch ⇒ **整局卡死**。
        'isMarried': false,
        'generation': true, // 已传承，标记多世代
        'inherited': true,
      },
      health: 100,
      energy: 100,
      // S14-1：字面量改为引用 BalanceData（三条开局/传承路径统一）。
      hunger: BalanceData.startingHunger,
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

  /// 当前世代数（1 起）。
  ///
  /// 旧实现 `flagOf('generation') ? 2 : 1` 只能表达 1/2 两档（坑 24：
  /// 三代以上显示错误），后改为「generationRecords 长度 + 1」。
  /// S14-1 再次改为取 `records.last.generation`：谱系记录现在会按
  /// `generationRecordCap` 裁剪，**列表长度不再等于代数**（第 35 代
  /// 裁到 20 条后 length = 20，用 length 会误报「第 21 代」）。
  int generationNumber() {
    final records = player.generationRecords;
    if (records.isNotEmpty) return records.last.generation + 1;
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

  // ==================== M3 · 指令自注册 ====================

  /// 把本领域指令注册进注册表（order 与历史帮助文本顺序一致）。
  void registerGenerationCommands(CommandRegistry registry) {
    registry.register(
      CommandSpec(
        aliases: const ['家谱', '家族', 'family'],
        order: 32,
        group: '查看',
        helpLine: '家谱 / family       查看家谱与继承人',
        handler: (args) => CommandResult(text: formatFamilyTree()),
      ),
    );
    registry.register(
      CommandSpec(
        aliases: const ['立嗣', '添丁', 'addchild'],
        order: 33,
        group: '人物',
        requiredArgCount: 1,
        missingArgsHint: '给子女起个名字吧。如「立嗣 罗柏」。',
        helpLine: '立嗣 / addchild [名字] 为家族添丁（如 立嗣 罗柏）',
        handler: (args) => CommandResult(text: addChild(args)),
      ),
    );
  }
  // ==================== M3 · 月度结算管线自注册 ====================

  /// 把本领域（家族传承提示）钩子注册进管线。
  void registerGenerationMonthlyHooks(MonthlyPipeline pipeline) {
    pipeline.register(
      MonthlyHookSpec(
        id: 'succession',
        phase: MonthlyPhase.beforeAdvance,
        order: 5,
        outputOrder: 4,
        hook: () => MonthlyHookResult(
          text: maybeSuccessionStory(),
          outputOrder: 4,
        ),
      ),
    );
  }
}
