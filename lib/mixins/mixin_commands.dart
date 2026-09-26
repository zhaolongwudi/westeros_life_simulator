/// 指令混入：解析玩家输入，分发到各 mixin。
///
/// 支持：状态/系统/信/旅行/训练/工作/狩猎/贸易/休息/探索/过月/帮助。
library;
import 'dart:math';
import '../data/item_data.dart';
import '../models/npc.dart';
import '../providers/game_provider_base.dart';
import 'mixin_adventure.dart';
import 'mixin_generation.dart';
import 'mixin_letter.dart';
import 'mixin_life.dart';
import 'mixin_npc_interact.dart';
import 'mixin_play.dart';
import 'mixin_systems.dart';

/// 指令执行结果。
class CommandResult {
  const CommandResult({
    required this.text,
    this.consumedTurn = false,
  });

  /// 响应文本。
  final String text;

  /// 是否消耗了一个回合（时间推进）。
  final bool consumedTurn;
}

/// 指令混入。挂在 [GameProviderBase] 上，依赖四个玩法 mixin。
///
/// Dart 的 mixin 不能使用 `with` 组合，改为在 `on` 子句中列出
/// 全部依赖 mixin（宿主类同时混入它们即可满足约束）。
mixin GameCommandsMixin
    on
        GameProviderBase,
        GamePlayMixin,
        GameSystemsMixin,
        GameLetterMixin,
        GameAdventureMixin,
        GameLifeMixin,
        GameNpcInteractMixin,
        GameGenerationMixin {
  /// 解析并执行一条玩家指令。
  ///
  /// 返回响应文本。未知指令返回帮助提示。
  CommandResult resolveCommand(String raw) {
    final input = raw.trim();
    if (input.isEmpty) {
      return const CommandResult(text: '请输入指令。输入「帮助」查看可用指令。');
    }

    // 精确指令
    final exact = input.split(RegExp(r'\s+')).first;
    final args = input.substring(exact.length).trim();

    switch (exact) {
      case '帮助' || 'help':
        return CommandResult(text: _helpText());
      case '状态' || 'status':
        return CommandResult(text: formatPlayerPanel());
      case '系统' || 'systems':
        return CommandResult(text: formatSystemsPanel());
      case '背包' || 'bag' || 'inventory':
        return CommandResult(text: formatInventoryPanel());
      case '使用' || 'use':
        if (args.isEmpty) {
          return const CommandResult(text: '使用什么？如「使用 黑面包」或「使用 item_meat」。');
        }
        return CommandResult(text: useItem(_normalizeItem(args)));
      case '信' || 'letter':
        return CommandResult(text: formatLettersPanel());
      case '回信' || 'reply':
        final reply = replyLetter(replyText: args.isEmpty ? null : args);
        return CommandResult(
          text: reply.isEmpty ? '没有待回的信。' : reply,
        );
      case '旅行' || 'travel' || '去':
        if (args.isEmpty) {
          return CommandResult(text: formatTravelPanel());
        }
        return CommandResult(text: travel(args));
      case '探索' || 'explore':
        return CommandResult(text: explore(), consumedTurn: true);
      case '训练' || 'train':
        if (args.isEmpty) {
          return const CommandResult(
            text: '训练什么？可用技能：'
                'sword（剑术）/ archery（弓术）/ riding（骑术）/ speech（口才）/ alchemy（炼金）。',
          );
        }
        return CommandResult(text: train(_normalizeSkill(args)));
      case '工作' || 'work':
        return CommandResult(text: work());
      case '狩猎' || 'hunt':
        return CommandResult(text: hunt());
      case '贸易' || 'trade':
        return CommandResult(text: trade());
      case '巡游' || '特产' || 'specialty':
        return CommandResult(text: tradeSpecialty());
      case '议价' || 'negotiate':
        return CommandResult(text: negotiate());
      case '商队' || '护送' || 'convoy':
        return CommandResult(text: convoy());
      case '购买' || '买入' || 'buy':
        if (args.isEmpty) {
          return const CommandResult(text: '买什么？如「购买 黑面包」或「买入 item_meat」。输入「行情」看价格。');
        }
        return CommandResult(text: _buyFromArgs(args));
      case '出售' || '卖出' || 'sell':
        if (args.isEmpty) {
          return const CommandResult(text: '卖什么？如「出售 烤肉」或「卖出 item_wine」。');
        }
        return CommandResult(text: _sellFromArgs(args));
      case '行情' || 'market' || '价格':
        return CommandResult(text: formatMarketPanel());
      case '装备' || 'equip':
        if (args.isEmpty) {
          return const CommandResult(text: '装备什么？如「装备 长剑」或「装备 锁子甲」。');
        }
        return CommandResult(text: equip(_normalizeItem(args)));
      case '卸下' || 'unequip':
        if (args.isEmpty) {
          return const CommandResult(text: '卸下什么？如「卸下 长剑」。');
        }
        return CommandResult(text: unequip(_normalizeItem(args)));
      case '装备栏' || '装备面板' || 'equipment':
        return CommandResult(text: formatEquipmentPanel());
      case '头衔' || 'title':
        return CommandResult(text: formatTitlePanel());
      case '在场' || 'npc' || '人物':
        return CommandResult(text: _npcListText());
      case '互动' || '交谈' || 'interact':
        if (args.isEmpty) {
          return const CommandResult(text: '和谁互动？如「互动 提利昂」或「互动 npc_tyrion」。输入「在场」看谁在这里。');
        }
        return CommandResult(text: npcInteract(_normalizeNpc(args)));
      case '示好' || '送礼' || 'favor':
        if (args.isEmpty) {
          return const CommandResult(text: '向谁示好？如「示好 提利昂」或「送礼 npc_tyrion」。');
        }
        return CommandResult(text: npcFavor(_normalizeNpc(args)));
      case '深聊' || '聊天' || 'chat':
        if (args.isEmpty) {
          return const CommandResult(text: '和谁深聊？如「深聊 提利昂」。输入「在场」看谁在这里。');
        }
        return CommandResult(text: npcChat(_normalizeNpc(args)));
      case '任务' || '委托' || 'task':
        if (args.isEmpty) {
          return CommandResult(text: formatNpcTaskPanel());
        }
        return CommandResult(text: acceptNpcTask(_normalizeNpc(args)));
      case '关系' || '关系面板' || 'relations':
        return CommandResult(text: formatNpcRelationPanel());
      case '休息' || 'rest':
        return CommandResult(text: rest());
      case '家谱' || '家族' || 'family':
        return CommandResult(text: formatFamilyTree());
      case '立嗣' || '添丁' || 'addchild':
        if (args.isEmpty) {
          return const CommandResult(text: '给子女起个名字吧。如「立嗣 罗柏」。');
        }
        return CommandResult(text: addChild(args));
      case '过月' || 'advance':
        return CommandResult(
          text: advanceMonth(),
          consumedTurn: true,
        );
      default:
        return CommandResult(text: _unknownHelp(exact));
    }
  }

  /// 解析「购买 <物品> <数量>」参数并执行。
  String _buyFromArgs(String args) {
    final parts = args.split(RegExp(r'\s+'));
    final namePart = parts.first;
    var quantity = 1;
    if (parts.length > 1) {
      quantity = int.tryParse(parts[1]) ?? 1;
    }
    final itemId = _normalizeItem(namePart);
    if (!kItems.containsKey(itemId)) {
      return '这里买不到「$namePart」。输入「行情」看看有什么可买。';
    }
    return buyItem(itemId, quantity);
  }

  /// 解析「出售 <物品> <数量>」参数并执行。
  String _sellFromArgs(String args) {
    final parts = args.split(RegExp(r'\s+'));
    final namePart = parts.first;
    var quantity = 1;
    if (parts.length > 1) {
      quantity = int.tryParse(parts[1]) ?? 1;
    }
    final itemId = _normalizeItem(namePart);
    if (!kItems.containsKey(itemId)) {
      return '你没有「$namePart」这种东西。';
    }
    return sellItem(itemId, quantity);
  }

  /// 在场 NPC 列表文本。
  String _npcListText() {
    final list = npcInteractionList();
    if (list.isEmpty) return '【在场人物】\n你身边没有其他人在场。';
    return '【在场人物】\n${list.join('\n')}';
  }

  /// NPC 名称/别名归一化（支持中文名/ID）。
  String _normalizeNpc(String raw) {
    final s = raw.trim();
    // 直接按 ID 匹配
    final byId = npcById(s);
    if (byId != null) return byId.id;
    // 按中文名模糊匹配（在场优先，其次全局）
    Npc? hit;
    for (final n in npcsAtCurrentLocation) {
      if (n.name == s || n.name.contains(s)) {
        hit = n;
        break;
      }
    }
    if (hit == null) {
      for (final n in npcs) {
        if (n.name == s) {
          hit = n;
          break;
        }
      }
    }
    if (hit != null) return hit.id;
    return s;
  }

  /// 物品别名归一化（支持中文名/ID）。
  String _normalizeItem(String raw) {
    final s = raw.trim();
    return switch (s) {
      '黑面包' || '面包' || 'item_bread' => 'item_bread',
      '烤肉' || '肉' || 'item_meat' => 'item_meat',
      '腌鱼' || '鱼' || 'item_fish' => 'item_fish',
      '葡萄酒' || '红酒' || 'item_wine' => 'item_wine',
      '草药' || 'item_herb' => 'item_herb',
      '药膏' || '金疮药膏' || 'item_poultice' => 'item_poultice',
      '罂粟花蜜酒' || 'item_dreamwine' => 'item_dreamwine',
      '匕首' || 'item_dagger' => 'item_dagger',
      '长剑' || '剑' || 'item_sword' => 'item_sword',
      '杂种剑' || 'item_bastard_sword' => 'item_bastard_sword',
      '长弓' || '弓' || 'item_bow' => 'item_bow',
      '瓦雷利亚钢匕首' || 'item_valyrian_dagger' => 'item_valyrian_dagger',
      '皮甲' || 'item_leather_armor' => 'item_leather_armor',
      '锁子甲' || 'item_chainmail' => 'item_chainmail',
      '板甲' || '全身板甲' || 'item_plate_armor' => 'item_plate_armor',
      '骏马' || '马' || 'item_horse' => 'item_horse',
      '小矮马' || 'item_garron' => 'item_garron',
      '龙骨' || 'item_dragonbone' => 'item_dragonbone',
      '玻璃蜡烛' || 'item_glass_candle' => 'item_glass_candle',
      '金链' || 'item_gold_chain' => 'item_gold_chain',
      '红宝石' || '宝石' || 'item_ruby' => 'item_ruby',
      '蓝宝石' || 'item_sapphire' => 'item_sapphire',
      '王冠' || '青铜王冠' || 'item_crown' => 'item_crown',
      '心树之叶' || 'item_heart_tree_leaf' => 'item_heart_tree_leaf',
      '七芒星徽' || 'item_seven_star' => 'item_seven_star',
      '光之使者残片' || 'item_lightbringer_shard' => 'item_lightbringer_shard',
      '羊皮纸' || 'item_parchment' => 'item_parchment',
      '渡鸦信' || 'item_raven_letter' => 'item_raven_letter',
      '盟约文书' || 'item_treaty' => 'item_treaty',
      '野火配方' || 'item_recipe_dragonfire' => 'item_recipe_dragonfire',
      '铁矿石' || 'item_iron_ore' => 'item_iron_ore',
      '精钢锭' || '钢锭' || 'item_steel' => 'item_steel',
      '皮革' || '鞣制皮革' || 'item_leather' => 'item_leather',
      _ => s,
    };
  }

  /// 技能别名归一化。
  String _normalizeSkill(String raw) {
    final s = raw.trim();
    return switch (s) {
      '剑术' || '剑' || 'sword' => 'sword',
      '弓术' || '弓箭' || '射箭' || 'archery' => 'archery',
      '骑术' || '骑马' || 'riding' => 'riding',
      '口才' || '演讲' || 'speech' => 'speech',
      '炼金' || '炼金术' || 'alchemy' => 'alchemy',
      _ => s,
    };
  }

  /// 未知指令提示。
  String _unknownHelp(String exact) {
    final rnd = Random(exact.hashCode);
    final lines = <String>[
      '「$exact」不是一条你能执行的指令。',
      '维斯特洛不认这个命令。',
      '你张了张嘴，却不知道要做什么。',
    ];
    return '${lines[rnd.nextInt(lines.length)]}\n${_helpText()}';
  }

  /// 帮助文本。
  String _helpText() {
    return '''
【可用指令】
状态 / status       查看玩家状态（生命/精力/饱食/背包）
背包 / bag          查看背包物品
使用 / use [物品]    使用消耗品（如 使用 黑面包）
系统 / systems      查看已接触系统
信 / letter         查看信件
回信 / reply [内容]  回复待回的信
旅行 / travel [地点] 查看可去地点或前往
探索 / explore      探索当前地点
训练 / train [技能]  训练技能（sword/archery/riding/speech/alchemy）
工作 / work         赚取金币（消耗精力）
狩猎 / hunt         野外狩猎（消耗精力）
贸易 / trade        城市贸易（消耗精力）
巡游 / specialty    地区特产巡游：当地收特产，异地高价出售（消耗精力）
议价 / negotiate    商人议价：口才决定买卖折价（每日 1 次）
商队 / convoy       商队护送：按战斗值判定报酬与风险（每日 1 次）
购买 / buy [物品]    购买物品（如 购买 黑面包 或 买入 长剑）
出售 / sell [物品]   出售物品（如 出售 烤肉 或 卖出 item_wine）
行情 / market       查看当前地点物价
装备 / equip [物品]  装备武器/护甲/坐骑（如 装备 长剑）
卸下 / unequip [物品] 卸下装备
装备栏 / equipment   查看当前装备与战斗值
头衔 / title       查看头衔与晋升进度
在场 / npc         查看当前在场的 NPC 与关系
互动 / interact [名字]  与在场 NPC 深度互动（好感越高内容越深）
示好 / favor [名字]   向在场 NPC 示好送礼（每日 3 次）
深聊 / chat [名字]    与 NPC 深聊（相识以上，每日 3 次，更深入）
任务 / task [名字]    查看可接任务；带名字则接下委托
关系 / relations     查看全部 NPC 关系/心情/任务数
家谱 / family       查看家谱与继承人
立嗣 / addchild [名字] 为家族添丁（如 立嗣 罗柏）
休息 / rest         恢复精力/饱食（花 2 金币）
过月 / advance      推进一个月
帮助 / help         显示本帮助
提示：精力与饱食每月结算，饥饿会掉健康，注意休息与进食。
''';
  }
}