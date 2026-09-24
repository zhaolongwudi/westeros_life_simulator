/// 指令混入：解析玩家输入，分发到各 mixin。
///
/// 支持：状态/系统/信/旅行/训练/工作/狩猎/贸易/休息/探索/过月/帮助。
library;

import 'dart:math';

import '../providers/game_provider_base.dart';
import 'mixin_adventure.dart';
import 'mixin_letter.dart';
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
mixin GameCommandsMixin on GameProviderBase
    with GamePlayMixin, GameSystemsMixin, GameLetterMixin, GameAdventureMixin {
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
状态 / status       查看玩家状态
系统 / systems      查看已接触系统
信 / letter         查看信件
回信 / reply [内容]  回复待回的信
旅行 / travel [地点] 查看可去地点或前往
探索 / explore      探索当前地点
训练 / train [技能]  训练技能（sword/archery/riding/speech/alchemy）
工作 / work         赚取金币
狩猎 / hunt         野外狩猎
贸易 / trade        城市贸易
休息 / rest         恢复体力
过月 / advance      推进一个月
帮助 / help         显示本帮助
''';
  }
}