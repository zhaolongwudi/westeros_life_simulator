/// 指令混入：解析玩家输入，分发到各 mixin。
///
/// 支持：状态/系统/信/旅行/训练/工作/狩猎/贸易/休息/探索/过月/帮助。
library;

import 'dart:math';

import '../providers/game_provider_base.dart';
import 'mixin_adventure.dart';
import 'mixin_letter.dart';
import 'mixin_life.dart';
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
        GameLifeMixin {
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
      case '休息' || 'rest':
        return CommandResult(text: rest());
      case '过月' || 'advance':
        return CommandResult(
          text: advanceMonth(),
          consumedTurn: true,
        );
      default:
        return CommandResult(text: _unknownHelp(exact));
    }
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
休息 / rest         恢复精力/饱食（花 2 金币）
过月 / advance      推进一个月
帮助 / help         显示本帮助

提示：精力与饱食每月结算，饥饿会掉健康，注意休息与进食。
''';
  }
}