/// 游戏引擎：组合 Batch 4 全部 mixin 的宿主类。
///
/// 用法：
/// ```dart
/// final engine = GameEngine();
/// engine.startNewGame();
/// final result = engine.resolveCommand('状态');
/// ```
library;

import 'mixins/mixin_adventure.dart';
import 'mixins/mixin_ai.dart';
import 'mixins/mixin_commands.dart';
import 'mixins/mixin_letter.dart';
import 'mixins/mixin_life.dart';
import 'mixins/mixin_play.dart';
import 'mixins/mixin_systems.dart';
import 'providers/game_provider_base.dart';

/// 游戏引擎宿主。
class GameEngine extends GameProviderBase
    with
        GameSystemsMixin,
        GameLifeMixin,
        GamePlayMixin,
        GameLetterMixin,
        GameAdventureMixin,
        GameCommandsMixin,
        GameAiMixin {
  GameEngine({
    super.player,
    super.progress,
    super.history,
    super.currentEvent,
    super.isGameActive,
    super.isGameOver,
    super.npcs,
    super.locations,
    super.families,
    super.systems,
    super.events,
  });
}