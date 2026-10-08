/// 系统混入：挂载世界 73 个系统，执行月度演进与系统查询。
///
/// 参考 docs/05_系统百科.md 与 docs/08_玩法设计.md「月度循环」。
///
/// S4-1（P1-09）：系统不再只是文案——`GameSystem.monthlyEffects` 挂载
/// 后由 [applyMonthlySystems] 第5 步按月结算。
library;

import '../models/family.dart';
import '../models/location.dart';
import '../models/player.dart';
import '../models/system.dart';
import '../core/command_registry.dart';
import '../core/monthly_pipeline.dart';
import '../providers/game_provider_base.dart';

/// 系统混入。挂在 [GameProviderBase] 上。
mixin GameSystemsMixin on GameProviderBase {
  /// 按分类查询系统。
  List<GameSystem> systemsByCategory(String category) {
    return systems.where((s) => s.category == category).toList();
  }

  /// 系统总数（世界百科核对用）。
  int get systemCount => systems.length;

  /// 玩家当前可接触的系统（按身份/地点/家族筛选）。
  ///
  /// 规则：
  /// - 家族系统：有家族即接触
  /// - 守夜人：地点在长城沿线或身份为守夜人
  /// - 学城：地点在学城/旧镇或身份为学士
  /// - 教会：地点有圣堂或身份为神职人员
  /// - 铁民/淹神：铁群岛
  /// - 雇佣兵/贸易/经济：城市
  ///
  /// **S12-8：可见性分层**。此前 `_ => false` 兜底把 **39/73** 个系统静默
  /// 吞掉（另有异鬼/死亡 2 个是显式 `false`，故修复前永不可见共 41 个），
  /// 玩家从头到尾看不到它们——其中 21 个其实是可玩内容。现按「玩家能不能
  /// 真的玩到」显式分三层：
  ///
  /// - **可玩类**（魔法/战争/情报/存档/红袍祭司，共 21 个）：给出与
  ///   身份/地点挂钩的可见条件，见下方 `S12-8` 段。
  /// - **开发规范类**（AI/规则/保护，共 18 个）：这些系统的 `rules` /
  ///   `features` 描述的是「AI 该怎么运行」「世界该怎么防漏洞」，是
  ///   **写给开发者的规范**，不是玩家在世界里能接触的事物 ⇒ 显式
  ///   `false`，永久不进玩家面板（用户已拍板「只改展示层」）。
  /// - **被动类**（异鬼/死亡）：不主动列出，保持原语义。
  ///
  /// ⚠️ 兜底 `_ => false` 保留为**防御**，但「究竟哪些分类被隐藏」由
  /// `batch12_s8_system_visibility_test.dart` 精确锁定：跨身份/地点扫描后
  /// 「永不可见集」必须**恰为 20 个**（18 开发规范 + 2 被动），
  /// 防止未来新增分类又被静默吞掉。实测修复前永不可见 39 个，修复后 20 个。
  List<GameSystem> availableSystems() {
    final identity = player.identity;

    final result = <GameSystem>[];
    for (final s in systems) {
      final cat = s.category;
      final keep = switch (cat) {
        '家族' || '封建' || '继承' || '婚姻' || '法律' => true,
        '守夜人' =>
          isInRegion('北境') &&
              (isAt('location_the_wall') ||
                  isAt('location_castle_black') ||
                  isAt('location_castle_black_nightswatch') ||
                  isAt('location_eastwatch') ||
                  isAt('location_shadow_tower')) ||
              identity == PlayerIdentity.soldier,
        '学城' =>
          identity == PlayerIdentity.maester ||
              isAt('location_citadel') ||
              isAt('location_old_town'),
        '教会' || '宗教' =>
          identity == PlayerIdentity.priest || identity == PlayerIdentity.scholar,
        '铁民' || '淹神' => isInRegion('铁群岛'),
        '雇佣兵' =>
          identity == PlayerIdentity.soldier || identity == PlayerIdentity.adventurer,
        '贸易' || '经济' || '铁金库' =>
          isAtType(LocationType.city) || isAtType(LocationType.market),
        '龙' =>
          isFamily('family_targaryen') || identity == PlayerIdentity.noble,
        '无面者' =>
          identity == PlayerIdentity.assassin || isAt('location_braavos'),
        '无垢者' => isAt('location_astapor'),
        '多斯拉克' =>
          isInRegion('厄索斯') && isAtType(LocationType.wilderness),
        '野人' =>
          isInRegion('北境') && isAtType(LocationType.wilderness),
        // ==================== S12-8：可玩类接入展示 ====================
        // 以下 5 个分类此前全部落进 `_ => false`，玩家永远看不到。
        // 它们描述的是玩家真能接触的事物（法术、战事、情报网、存档、
        // 光之王信仰），故给出可见条件。条件全部复用既有判定辅助
        // （`isAt` / `isAtType` / `isInRegion` / `isIdentity` / `isFamily`），
        // 不引入新的世界状态。
        //
        // 魔法：超自然领域（绿先知/龙梦等 9 地）或身份本身与法术相关。
        // 门槛刻意偏严——魔法在原著里是稀有之物，进城就能看到「魔法体系」
        // 会与世界观冲突。
        '魔法' =>
          isAtType(LocationType.supernatural) ||
              isIdentity(PlayerIdentity.maester) ||
              isIdentity(PlayerIdentity.priest) ||
              isIdentity(PlayerIdentity.wildling),
        // 战争：参战身份，或身处城堡/要塞（战争总是围着据点打）。
        '战争' =>
          isIdentity(PlayerIdentity.soldier) ||
              isIdentity(PlayerIdentity.adventurer) ||
              isAtType(LocationType.castle) ||
              isAtType(LocationType.fort),
        // 情报：情报网在城市里最密；冒险者/刺客/商人以此为生。
        '情报' =>
          isIdentity(PlayerIdentity.adventurer) ||
              isIdentity(PlayerIdentity.assassin) ||
              isIdentity(PlayerIdentity.merchant) ||
              isAtType(LocationType.city),
        // 存档：这是**玩家功能**（存/读档），与地点身份无关 ⇒ 恒可见。
        // 此前不可见纯属分类没被列出，属实现遗漏而非设计。
        '存档' => true,
        // 红袍祭司：光之王信仰，厄索斯是其主要势力范围。
        '红袍祭司' =>
          isIdentity(PlayerIdentity.priest) || isInRegion('厄索斯'),
        // ==================== S12-8：开发规范类（显式隐藏） ====================
        // AI / 规则 / 保护 三类共 18 个系统，其 rules/features 是**开发
        // 规范**（「AI 该怎么运行」「世界该怎么防数值漏洞」），不是玩家在
        // 世界内可接触的对象。此前它们不可见是 `_ => false` 的副作用，
        // 现在是**有意为之**，并由测试锁定「永不可见集 = 这 18 个 + 异鬼/死亡 2 个」。
        // 这几条虽与下面的 `_ => false` 等价，但显式写出才能让「隐藏是
        // 决定而非遗漏」在代码里可读、可被后人 review。
        'AI' || '规则' || '保护' => false,
        '异鬼' || '死亡' => false, // 被动系统，不主动列出
        _ => false,
      };
      if (keep) result.add(s);
    }
    return result;
  }

  /// 生成系统面板文本。
  String formatSystemsPanel() {
    final avail = availableSystems();
    final buf = StringBuffer()
      ..writeln('【系统面板】')
      ..writeln('已接触系统：${avail.length}/${systemCount}');
    if (avail.isEmpty) {
      buf.writeln('你目前还没有接触任何世界系统。');
      return buf.toString().trim();
    }
    for (final s in avail.take(12)) {
      buf
        ..writeln()
        ..writeln('· ${s.name}（${s.category}）')
        ..writeln('  ${s.description}');
      if (s.features.isNotEmpty) {
        buf.writeln('  特性：${s.features.take(3).join('、')}');
      }
      // S4-1（P1-09）：只有挂了 monthlyEffects 的系统才真的每月改变状态，
      // 不标出来玩家只能靠猜哪个系统「真的有用」。
      if (s.hasMonthlyEffects) {
        buf.writeln('  月度结算：${_formatMonthlyEffects(s.monthlyEffects)}');
      }
    }
    if (avail.length > 12) {
      buf.writeln('… 等共 ${avail.length} 个系统');
    }
    return buf.toString().trim();
  }

  /// 月度演进：按世界状态结算月度收益/事件/通知。
  ///
  /// 返回追加到叙事的月度结算文本（空串表示无特殊结算）。
  String applyMonthlySystems({int? seed}) {
    if (!isGameActive || isGameOver) return '';
    final rnd = rng(seed);
    final buf = StringBuffer();

    // 1. 家族月度收益（影响力折算金币）
    final fam = playerFamily;
    if (fam != null && fam.influence > 0) {
      final income = (fam.influence ~/ 10) + (fam.scale == FamilyScale.great ? 5 : 2);
      gainGold(income);
      buf.writeln('🏰 ${fam.name}家族本月收益 +$income 金币（影响力 ${fam.influence}）');
    }

    // 2. 地点风险判定（危险度越高越容易触发损失/事件）
    final loc = currentLocation;
    if (loc != null && loc.dangerLevel >= 5) {
      if (rnd.nextDouble() < 0.3) {
        final loss = (loc.dangerLevel - 3) * 5;
        gainGold(-loss);
        buf.writeln('⚠️ ${loc.name}的威胁：本月损失 $loss 金币（危险度 ${loc.dangerLevel}）');
      }
    }

    // 3. 季节影响（冬天减益）
    if (progress.season == 'winter') {
      gainGold(-5);
      buf.writeln('❄️ 凛冬已至：生活成本上升，本月 -5 金币');
    }

    // 4. 系统演进：每季度生成一条世界动态
    if (progress.month % 3 == 0) {
      final available = availableSystems();
      if (available.isNotEmpty) {
        final s = available[rnd.nextInt(available.length)];
        final dynamics = _systemDynamicsFor(s.category);
        if (dynamics.isNotEmpty) {
          buf.writeln('🌍 【${s.name}动态】${dynamics[rnd.nextInt(dynamics.length)]}');
        }
      }
    }

    // 5. S4-1（P1-09）：系统月度效果结算。
    //
    // 【为什么放最后】前4 步都是「世界层面的既定事实」（家族收成、危险、
    // 季节），本步是「玩家身上某个系统生效」—— 放最后可以让输出读起来
    // 符合叙事顺序：先讲世界，再讲你的组织对你做了什么。
    //
    // 【为什么复用 applyEffects 而不是手写 setter】效果键的合法集合、边界
    // 钳制（gold 下限 0 / 生存值 0~100 / 好感度 ±100）、五类幽灵键守卫
    // 全都在 `game_state_provider.applyEffects` 里实装过了。手写一套等于
    // 再开一条会漂移的通道（batch10-90 / 10-95 的老教训）。
    final monthlyLines = _settleMonthlySystemEffects();
    for (final line in monthlyLines) {
      buf.writeln(line);
    }

    final text = buf.toString().trim();
    if (text.isNotEmpty) {
      notifyListeners();
    }
    return text;
  }

  /// S4-1（P1-09）：结算所有已挂载系统的 `monthlyEffects`，返回可读文本。
  ///
  /// 复用 `applyEffects`（`GameProviderBase` 继承 `GameStateProvider`，
  /// 故本 mixin 可直接调用），因此效果键校验与钳制行为与事件/AI 通道
  /// **完全一致**——这也意味着无效键会被拒收并落进
  /// `lastRejectedEffectKeys`，不会静默生效。
  List<String> _settleMonthlySystemEffects() {
    final lines = <String>[];
    for (final s in availableSystems()) {
      final effects = s.monthlyEffects;
      if (effects.isEmpty) continue;
      // 效果键校验：拒收不该在这里发生（数据侧保证），但真发生了也不能
      // 让applyEffects 的空转被当成「结算成功」写进叙事，故前后比对状态。
      final before = player;
      updatePlayer(applyEffects(before, effects));
      final after = player;

      final deltas = <String>[];
      if (after.gold != before.gold) {
        final d = after.gold - before.gold;
        deltas.add('${d > 0 ? '+' : ''}$d 金币');
      }
      for (final v in const ['health', 'energy', 'hunger']) {
        final b = _vitalOf(before, v);
        final a = _vitalOf(after, v);
        if (a != b) {
          final d = a - b;
          deltas.add('${_vitalLabel(v)} ${d > 0 ? '+' : ''}$d');
        }
      }
      if (after.reputation != before.reputation) {
        final d = after.reputation - before.reputation;
        deltas.add('声望 ${d > 0 ? '+' : ''}$d');
      }
      if (deltas.isEmpty) {
        // 键全部被拒收，或效果被边界钳制吃掉（如已满 100 再 +5）。
        // 前者是真 bug 信号（数据侧写了无效键），后者属正常边界——
        // 两种都不该对玩家宣称「结算了」。
        final rejected = lastRejectedEffectKeys;
        if (rejected.isNotEmpty) {
          lines.add('⚠️ ${s.name}月度结算含无效效果键：${rejected.join('、')}（已忽略）');
        }
        continue;
      }
      lines.add('📜 ${s.name}·本月：${deltas.join('，')}');
    }
    return lines;
  }

  /// 取生存类字段值（health / energy / hunger 三者同为 0~100）。
  int _vitalOf(Player p, String field) {
    return switch (field) {
      'health' => p.health,
      'energy' => p.energy,
      _ => p.hunger,
    };
  }

  /// 生存类字段的展示名。
  String _vitalLabel(String field) {
    return switch (field) {
      'health' => '健康',
      'energy' => '精力',
      _ => '饱食',
    };
  }

  /// S4-1（P1-09）：把月度效果 map 格式化成面板可读文本。
  String _formatMonthlyEffects(Map<String, int> effects) {
    final parts = effects.entries.map((e) {
      final d = e.value;
      return '${e.key} ${d > 0 ? '+' : ''}$d';
    }).toList();
    return parts.join('，');
  }

  /// 各系统分类的世界动态文案池。
  List<String> _systemDynamicsFor(String category) {
    return switch (category) {
      '家族' || '封建' => [
          '领主之间的联姻正在酝酿。',
          '有封臣在暗中积聚力量。',
          '一场领地争端即将爆发。',
        ],
      '战争' => [
          '边境哨站传来军队集结的传闻。',
          '雇佣骑士们开始聚集在路口。',
        ],
      '贸易' || '经济' => [
          '商队带来了远方市场的消息。',
          '集市上的物价出现波动。',
          '一条新的商路正在兴起。',
        ],
      '教会' || '宗教' => [
          '修士们在城镇里布道。',
          '圣堂的钟声敲响了。',
        ],
      '守夜人' => [
          '长城以北的巡逻队发现野人踪迹。',
          '守夜人誓言再次被念诵。',
        ],
      '学城' => [
          '学士们送出了一批新的渡鸦信。',
          '学城正在编纂新的历史卷册。',
        ],
      _ => ['世界悄然运转，暗流涌动。'],
    };
  }

  // ==================== M3 · 指令自注册 ====================

  /// 把本领域指令注册进注册表（order 与历史帮助文本顺序一致）。
  void registerSystemsCommands(CommandRegistry registry) {
    registry.register(
      CommandSpec(
        aliases: const ['系统', 'systems'],
        order: 4,
        group: '查看',
        helpLine: '系统 / systems      查看已接触系统',
        handler: (args) => CommandResult(text: formatSystemsPanel()),
      ),
    );
  }
  // ==================== M3 · 月度结算管线自注册 ====================

  /// 把本领域（月度系统演进）钩子注册进管线。
  void registerSystemsMonthlyHooks(MonthlyPipeline pipeline) {
    pipeline.register(
      MonthlyHookSpec(
        id: 'systems',
        phase: MonthlyPhase.beforeAdvance,
        order: 1,
        outputOrder: 1,
        hook: () => MonthlyHookResult(
          text: applyMonthlySystems(seed: progress.turnCount),
          outputOrder: 1,
        ),
      ),
    );
  }
}
