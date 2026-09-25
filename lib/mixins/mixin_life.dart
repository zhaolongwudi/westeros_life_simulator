/// 生存状态混入：健康 / 精力 / 饱食 管理与物品系统。
///
/// 新增维度（Batch 10）：
/// - 精力：进行活动消耗，休息/进食恢复；精力不足时活动受限
/// - 饱食：逐月下降，进食恢复；过低会掉健康
/// - 健康：0 死亡；受伤/疾病/危险事件会降低
/// - 物品：背包增删、使用消耗品（health/energy/hunger 效果）
library;

import 'dart:math';

import '../data/item_data.dart';
import '../providers/game_provider_base.dart';

/// 生存状态混入。挂在 [GameProviderBase] 上。
///
/// 供 [GamePlayMixin] 在月度循环中调用 [applyMonthlyLife]，
/// 因此宿主混入顺序需保证本 mixin 在 GamePlayMixin 之前。
mixin GameLifeMixin on GameProviderBase {
  /// 精力不足时活动成功率折扣。
  static const double kLowEnergyPenalty = 0.5;

  /// 饱食每月的自然下降量。
  static const int kHungerDecayPerMonth = 12;

  /// 饱食低于此阈值视为饥饿（每月掉健康）。
  static const int kStarvationThreshold = 25;

  /// 精力恢复：休息/进食的恢复量。
  static const int kRestEnergyRecovery = 40;

  /// 健康自然恢复（非受伤时每月 +2）。
  static const int kHealthRegen = 2;

  /// 精力是否充足（低于 20 视为疲惫）。
  bool get isExhausted => player.energy < 20;

  /// 饱食是否过低（饥饿）。
  bool get isStarving => player.hunger < kStarvationThreshold;

  /// 是否受伤（flag 由事件/狩猎设置）。
  bool get isInjured => flagOf('isInjured');

  // ==================== 数值调整（统一 clamp） ====================

  /// 调整精力（clamp 0~100），并写入玩家。
  void adjustEnergy(int delta) {
    updatePlayer(
      player.copyWith(energy: (player.energy + delta).clamp(0, 100)),
    );
  }

  /// 调整饱食（clamp 0~100，0 表示最饿）。
  void adjustHunger(int delta) {
    updatePlayer(
      player.copyWith(hunger: (player.hunger + delta).clamp(0, 100)),
    );
  }

  /// 调整健康（clamp 0~100；0 触发死亡判定）。
  void adjustHealth(int delta) {
    final newHealth = (player.health + delta).clamp(0, 100);
    updatePlayer(player.copyWith(health: newHealth));
    if (newHealth <= 0 && (player.flags['isAlive'] ?? true)) {
      setFlag('isAlive', false);
    }
  }

  // ==================== 物品系统 ====================

  /// 背包中某物品的数量。
  int itemCount(String itemId) {
    return player.inventory.where((i) => i == itemId).length;
  }

  /// 获得一件物品（可堆叠物品重复加入列表，简单列表模型）。
  ///
  /// 返回是否成功（背包无上限，恒成功）。
  bool addItem(String itemId) {
    final item = itemById(itemId);
    if (item == null) return false;
    final newInv = List<String>.from(player.inventory)..add(itemId);
    updatePlayer(player.copyWith(inventory: newInv));
    return true;
  }

  /// 移除一件物品（有则移除并返回 true）。
  bool removeItem(String itemId) {
    final idx = player.inventory.indexOf(itemId);
    if (idx < 0) return false;
    final newInv = List<String>.from(player.inventory)..removeAt(idx);
    updatePlayer(player.copyWith(inventory: newInv));
    return true;
  }

  /// 使用一件物品：应用效果并移除。
  ///
  /// 返回叙事文本；不可用/不可使用/技能不足返回说明。
  String useItem(String itemId) {
    final item = itemById(itemId);
    if (item == null) return '没有「$itemId」这种东西。';
    if (!item.usable) return '「${item.name}」不能直接使用。';
    if (itemCount(itemId) <= 0) return '你身上没有「${item.name}」。';
    if (item.requiresSkill.isNotEmpty &&
        skillLevel(item.requiresSkill) <= 0) {
      return '你缺乏${item.requiresSkill}知识，无法使用「${item.name}」。';
    }

    // 应用效果：health/energy/hunger 由本混入处理；gold/reputation 等转交效果系统
    var text = '你使用了「${item.name}」。';
    final effects = item.useEffect;
    final healthDelta = effects['health'] ?? 0;
    final energyDelta = effects['energy'] ?? 0;
    final hungerDelta = effects['hunger'] ?? 0;
    if (healthDelta != 0) adjustHealth(healthDelta);
    if (energyDelta != 0) adjustEnergy(energyDelta);
    if (hungerDelta != 0) adjustHunger(hungerDelta);

    removeItem(itemId);
    notifyListeners();
    return text;
  }

  /// 物品面板文本。
  String formatInventoryPanel() {
    if (player.inventory.isEmpty) return '【背包】\n你两手空空。';
    // 汇总数量
    final counts = <String, int>{};
    for (final id in player.inventory) {
      counts[id] = (counts[id] ?? 0) + 1;
    }
    final buf = StringBuffer()..writeln('【背包】');
    for (final entry in counts.entries) {
      final item = itemById(entry.key);
      final name = item?.name ?? entry.key;
      final cat = item == null ? '' : '（${itemCategoryLabel(item.category)}）';
      final value = item == null ? '' : '，价值 ${item.value}';
      buf.writeln('· $name$cat ×${entry.value}$value');
    }
    return buf.toString().trim();
  }

  // ==================== 月度生存结算 ====================

  /// 月度生存结算：饱食下降、饥饿减益、精力/健康自然恢复、受伤恢复。
  ///
  /// 返回追加到月度叙事的文本（空串表示无特殊结算）。
  String applyMonthlyLife({int? seed}) {
    if (!isGameActive || isGameOver) return '';
    final rnd = rng(seed);
    final buf = StringBuffer();

    // 1. 饱食自然下降
    final oldHunger = player.hunger;
    adjustHunger(-kHungerDecayPerMonth);
    if (oldHunger >= 60 && player.hunger < 60) {
      buf.writeln('🍞 你感到腹中空空，该去找点吃的了。');
    }

    // 2. 饥饿减益：持续饥饿掉健康
    if (isStarving) {
      adjustHealth(-8);
      buf.writeln('⚠️ 长期饥饿正在侵蚀你的身体（健康 -8）。');
    }

    // 3. 精力/健康自然恢复（月内休息足够时）
    final sleptWell = !isExhausted && rnd.nextDouble() < 0.7;
    if (sleptWell) {
      final energyGain = 15 + rnd.nextInt(15);
      adjustEnergy(energyGain);
    } else {
      buf.writeln('💤 你睡眠不佳，精力恢复缓慢。');
    }
    if (!isInjured && player.health < 100) {
      adjustHealth(kHealthRegen);
    }

    // 4. 受伤缓慢恢复（每月小概率好转）
    if (isInjured && rnd.nextDouble() < 0.4) {
      setFlag('isInjured', false);
      buf.writeln('🩹 你的伤势渐渐好转，已经不妨碍行动了。');
    }

    // 5. 冬季更冷更饿
    if (progress.season == 'winter' || progress.season == 'longwinter') {
      adjustHunger(-5);
      if (player.hunger < kStarvationThreshold) {
        buf.writeln('❄️ 凛冬的严寒让你消耗更快。');
      }
    }

    final text = buf.toString().trim();
    if (text.isNotEmpty) notifyListeners();
    return text;
  }

  /// 精力是否足够执行一次消耗精力的活动。
  bool canAffordEnergy(int cost) => player.energy >= cost;

  /// 精力消耗后的成功率乘数（疲惫打折）。
  double energySuccessMultiplier() => isExhausted ? kLowEnergyPenalty : 1.0;
}