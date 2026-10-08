/// 冒险混入：旅行、探索、遭遇。
///
/// 参考 docs/08_玩法设计.md「旅行系统」「冒险系统」。
library;

import 'dart:math';
import '../data/balance_data.dart';
import '../data/item_data.dart';
import '../models/location.dart';
import '../core/command_registry.dart';
import '../providers/game_provider_base.dart';
import '../utils/command_alias.dart';
import 'mixin_life.dart';
import 'mixin_npc_interact.dart';
import 'mixin_npc_task.dart';
/// 冒险混入。挂在 [GameProviderBase] 上。
mixin GameAdventureMixin
    on
        GameProviderBase,
        GameLifeMixin,
        GameNpcInteractMixin,
        GameNpcTaskMixin {
  /// 旅行：前往一个相连的地点。
  ///
  /// 返回旅行叙事文本；目标不在地点相连列表中则拒绝。
  String travel(String locationId) {
    if (!isGameActive || isGameOver) return '游戏尚未开始。';
    final target = locationById(locationId);
    if (target == null) return '没有叫「$locationId」的地方。';
    if (target.id == player.locationId) return '你已经在这里了。';

    final current = currentLocation;
    final connected = current?.connectedTo ?? <String>[];
    if (!connected.contains(target.id)) {
      final names = connected
          .map((id) => locationById(id)?.name ?? id)
          .join('、');
      return '从这里无法直接前往 ${target.name}。可前往：${names.isEmpty ? '无' : names}。';
    }

    final rnd = rng();
    // 旅行消耗金币（路程越远/危险度越高越贵）
    final cost = BalanceData.travelCostBase + target.dangerLevel + rnd.nextInt(BalanceData.travelCostVariance);
    if (player.gold < cost) {
      return '你付不起前往 ${target.name} 的旅费（需 $cost 金币）。';
    }

    updatePlayer(
      player.copyWith(locationId: target.id, gold: player.gold - cost),
    );
    notifyListeners();

    // 高风险地点可能触发遭遇
    final encounter = _maybeEncounter(target, rnd);
    final buf = StringBuffer()
      ..writeln('🧭 你从 ${current?.name ?? '某地'} 出发，抵达 ${target.name}（${target.region}）。')
      ..writeln('旅费 $cost 金币。');
    if (encounter != null) {
      buf.writeln(encounter);
    }
    return buf.toString().trim();
  }

  /// 探索：在当前位置搜索，可能发现金币/物品/遭遇（消耗精力）。
  String explore() {
    if (!isGameActive || isGameOver) return '游戏尚未开始。';
    final loc = currentLocation;
    if (loc == null) return '你在一片虚无中，无从探索。';
    if (!canAffordEnergy(BalanceData.exploreEnergyCost)) {
      return '你精疲力竭，连脚步都迈不动。先去休息吧。';
    }
    adjustEnergy(-BalanceData.exploreEnergyCost);

    final rnd = rng();
    final danger = loc.dangerLevel;

    // 城市/村庄探索收益低但安全；荒野/超自然收益高但危险
    final roll = rnd.nextDouble();
    final buf = StringBuffer()..writeln('🔍 你在${loc.name}四处探索……');

    if (roll < BalanceData.exploreGoldBand) {
      final found = BalanceData.exploreGoldBase + rnd.nextInt(BalanceData.exploreGoldVarianceBase + danger * BalanceData.exploreGoldDangerMult);
      gainGold(found);
      buf.writeln('你找到了一些有用的东西，价值 $found 金币。');
    } else if (roll < BalanceData.exploreItemBand) {
      // 物品掉落：按地点类型
      final item = _findItemFor(loc, rnd);
      if (item != null) {
        addItem(item);
        buf.writeln('🎒 你发现了一件物品：${itemName(item)}。');
      } else {
        buf.writeln('你找到了一些散落的零钱，聊胜于无。');
      }
    } else if (roll < BalanceData.exploreEncounterBand) {
      final encounter = _maybeEncounter(loc, rnd, force: true);
      if (encounter != null) {
        buf.writeln(encounter);
      } else {
        buf.writeln('你发现了一条捷径，省下不少脚程。');
      }
    } else {
      buf.writeln('一无所获。${danger >= 5 ? '这地方不宜久留。' : '也许下次会有收获。'}');
    }

    // 【S13-2】任务推进**不在这里**做，统一交给月度管线的 `task_advance` 钩子。
    // 本指令 `consumedTurn: true` ⇒ 调度方（`game_screen.dart:184`）会在本方法
    // 返回后再调 `advanceMonth()`，管线的 `beforeAdvance` 钩子
    // （`mixin_npc_task.dart:451-463`）已经会推 1 步。此处原先还有一次
    // `advanceNpcTasks()`（Batch 10-18 引入），与管线那次叠加成**一次探索推进 2 步**，
    // 导致 `NpcTaskStep.turnsRequired`（注释明写「探索/过月各计 1 次」）整体折半，
    // 72 个任务模板的 `totalTurns` 全部失真（如 `task_nev_escort` 5→3）。
    //
    // 注意：**不要**反过来删管线钩子——它同时服务「过月」路径（`needsTimeAdvance`
    // 为 false 的指令不触发 `advanceMonth()`），删了「过月」就不推进任务了。

    // 探索推进时间（半天=0.5 月，用 turnCount 模拟）
    notifyListeners();
    return buf.toString().trim();
  }

  /// 按地点类型返回可发现的物品 ID（随机）。
  String? _findItemFor(Location loc, Random rnd) {
    const poolByType = <LocationType, List<String>>{
      LocationType.wilderness: ['item_leather', 'item_iron_ore', 'item_herb'],
      LocationType.castle: ['item_parchment', 'item_raven_letter', 'item_gold_chain'],
      LocationType.city: ['item_wine', 'item_dagger', 'item_poultice'],
      LocationType.market: ['item_wine', 'item_bread', 'item_fish'],
      LocationType.tavern: ['item_wine', 'item_bread', 'item_meat'],
      LocationType.temple: ['item_seven_star', 'item_heart_tree_leaf', 'item_parchment'],
      LocationType.academy: ['item_parchment', 'item_recipe_dragonfire', 'item_glass_candle'],
      LocationType.supernatural: ['item_dragonbone', 'item_valyrian_dagger', 'item_lightbringer_shard'],
      LocationType.village: ['item_bread', 'item_fish', 'item_herb'],
      LocationType.fort: ['item_iron_ore', 'item_steel', 'item_dagger'],
      LocationType.unknown: ['item_crown', 'item_lightbringer_shard', 'item_dragonbone'],
    };
    final pool = poolByType[loc.type];
    if (pool == null || pool.isEmpty) return null;
    if (rnd.nextDouble() < BalanceData.exploreItemDropGate) {
      return null; // 60% 不出物品
    }
    return pool[rnd.nextInt(pool.length)];
  }

  /// 可能触发一次遭遇（危险度越高概率越大）。
  String? _maybeEncounter(Location loc, Random rnd, {bool force = false}) {
    final danger = loc.dangerLevel;
    if (!force &&
        rnd.nextDouble() > danger * BalanceData.encounterChancePerDanger) {
      return null;
    }

    final roll = rnd.nextDouble();
    // 遭遇类型：强盗/野兽/商人/神秘事件
    if (roll < BalanceData.encounterBanditBand) {
      // 强盗：损失金币或战斗
      final sword = skillLevel('sword');
      if (sword >= 4 || rnd.nextDouble() < BalanceData.banditRepelChance) {
        adjustReputation(2);
        return '⚔️ 你遭遇了一伙强盗，凭借身手击退了他们。声望 +2。';
      }
      final loss = BalanceData.banditLossBase + danger * BalanceData.banditLossDangerMult;
      gainGold(-loss);
      return '🥷 你遭遇了一伙强盗，被抢走了 $loss 金币。';
    } else if (roll < BalanceData.encounterBeastBand) {
      // 野兽：猎获或受伤
      if (skillLevel('archery') >= 3 || rnd.nextDouble() < BalanceData.beastEscapeChance) {
        final gain = BalanceData.beastGainBase + danger * BalanceData.beastGainDangerMult;
        gainGold(gain);
        adjustHunger(BalanceData.beastHungerGain);
        // 小概率获得皮革
        if (rnd.nextDouble() < BalanceData.beastInjuryChance) {
          addItem('item_leather');
          return '🐗 你猎到一头野兽，获得 $gain 金币和一张皮革。';
        }
        return '🐗 你猎到一头野兽，获得 $gain 金币。';
      }
      setFlag('isInjured', true);
      adjustHealth(-BalanceData.beastInjuryHealth);
      return '🐺 你被野兽抓伤，狼狈逃回。（受伤，健康 -8）';
    } else if (roll < BalanceData.encounterMerchantBand) {
      // 商人
      final profit = BalanceData.merchantProfitBase + rnd.nextInt(BalanceData.merchantProfitVariance);
      gainGold(profit);
      // 商人偶售补给
      if (rnd.nextDouble() < BalanceData.merchantHaggleChance) {
        addItem('item_bread');
        return '🛒 你遇到一位行商，做成了一笔小买卖，+$profit 金币，还得了些干粮。';
      }
      return '🛒 你遇到一位行商，做成了一笔小买卖，+$profit 金币。';
    } else {
      // 神秘事件（超自然地点概率更高）
      if (loc.type == LocationType.supernatural ||
          rnd.nextDouble() < BalanceData.supernaturalEncounterChance) {
        adjustReputation(3);
        return '🌫️ 迷雾中你仿佛看到了不属于这个时代的东西。说不清是福是祸，但你的名字开始被人提起。声望 +3。';
      }
      return '🌙 你遇到了一位旅人，听了一段关于远方战争的传闻。';
    }
  }

  /// 可前往地点列表（面板用）。
  String formatTravelPanel() {
    final loc = currentLocation;
    if (loc == null) return '你不知身在何处。';
    final connected = loc.connectedTo;
    if (connected.isEmpty) return '从这里没有可以前往的地方。';
    final buf = StringBuffer()..writeln('【可前往】从${loc.name}：');
    for (final id in connected) {
      final target = locationById(id);
      if (target != null) {
        buf.writeln('· ${target.name}（${target.region}，危险度 ${target.dangerLevel}）');
      }
    }
    return buf.toString().trim();
  }

  // ==================== M3 · 指令自注册 ====================

  /// 把本领域指令注册进注册表（order 与历史帮助文本顺序一致）。
  void registerAdventureCommands(CommandRegistry registry) {
    registry.register(
      CommandSpec(
        aliases: const ['旅行', 'travel', '去'],
        order: 7,
        group: '日常',
        helpLine: '旅行 / travel [地点] 查看可去地点或前往',
        // 【S9-1（遗留 L3）跨地点移动消耗一个月】与「探索」同构：此前 `travel`
        // 是唯一不消耗回合的位移指令，一个月内可走遍全图，而 `explore` 要一个月。
        //
        // 【为什么只有「真的移动了」才消耗】空参数只是列出可去地点（面板），
        // 目标不合法 / 未连接 / 旅费不足同样没有发生位移——没移动就不该罚掉
        // 一个月。判定用**位移**（`player.locationId` 是否变化）而非文案是否
        // 含「抵达」：后者是字符串耦合，文案一改就失效。
        //
        // 【为什么 spec 级 `consumedTurn` 保持缺省 false】它是**声明性**字段
        // （供帮助文本/契约检查读取），而本指令是**条件消耗**；标 true 会与
        // 「声明消耗了但没推进」的不一致同型（见 command_registry.dart:63-64
        // 的警告）。真正的推进动作以本处返回的 `needsTimeAdvance` 为准。
        handler: (args) {
          if (args.isEmpty) {
            return CommandResult(text: formatTravelPanel());
          }
          // 【S12-3】玩家照着面板上的中文名输（「旅行 白港」），不能只认 id。
          final from = player.locationId;
          final text = travel(normalizeLocationAlias(args));
          final moved = player.locationId != from;
          return CommandResult(text: text, consumedTurn: moved);
        },
      ),
    );
    registry.register(
      CommandSpec(
        aliases: const ['探索', 'explore'],
        order: 8,
        group: '日常',
        consumedTurn: true,
        helpLine: '探索 / explore      探索当前地点',
        handler: (args) => CommandResult(text: explore(), consumedTurn: true),
      ),
    );
  }
}
