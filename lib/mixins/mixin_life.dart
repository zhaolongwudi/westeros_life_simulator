/// 生存状态混入：健康 / 精力 / 饱食 管理与物品系统。
///
/// 新增维度（Batch 10）：
/// - 精力：进行活动消耗，休息/进食恢复；精力不足时活动受限
/// - 饱食：逐月下降，进食恢复；过低会掉健康
/// - 健康：0 死亡；受伤/疾病/危险事件会降低
/// - 物品：背包增删、使用消耗品（health/energy/hunger 效果）
library;
import '../data/item_data.dart';
import '../models/location.dart';
import '../models/player.dart';
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

  // ==================== 贸易系统（Batch 10-3） ====================

  /// 购买价格：物品价值 × 地点系数。
  ///
  /// 城市/集市商品丰富价格平稳；要塞/荒野补给稀缺溢价。
  int buyPriceOf(String itemId) {
    final item = itemById(itemId);
    if (item == null) return 0;
    final loc = currentLocation;
    double factor = 1.0;
    if (loc != null) {
      switch (loc.type) {
        case LocationType.city:
        case LocationType.market:
          factor = 1.1; // 大市场略贵但有货
        case LocationType.castle:
        case LocationType.fort:
          factor = 1.25; // 城堡补给稀缺
        case LocationType.village:
          factor = 0.9; // 乡村便宜但品类少
        case LocationType.wilderness:
        case LocationType.supernatural:
        case LocationType.unknown:
          factor = 1.6; // 荒野无处购买，只能高价求购
        case LocationType.temple:
        case LocationType.academy:
        case LocationType.tavern:
          factor = 1.2;
      }
    }
    return (item.value * factor).round();
  }

  /// 出售价格：物品价值 × 出售折扣 × 地点系数。
  ///
  /// 珍宝/圣物/武器在城市的收购价更高，乡村/荒野贱卖。
  int sellPriceOf(String itemId) {
    final item = itemById(itemId);
    if (item == null) return 0;
    final loc = currentLocation;
    double factor = 0.5; // 基础五折
    if (loc != null) {
      switch (loc.type) {
        case LocationType.city:
        case LocationType.market:
          factor = 0.7; // 大城市收购价高
        case LocationType.castle:
        case LocationType.fort:
          factor = 0.55;
        case LocationType.village:
          factor = 0.4; // 乡下贱卖
        case LocationType.wilderness:
        case LocationType.supernatural:
        case LocationType.unknown:
          factor = 0.3; // 荒野只能以物易物
        case LocationType.temple:
        case LocationType.academy:
        case LocationType.tavern:
          factor = 0.5;
      }
    }
    // 珍宝/圣物在大城市有额外加成
    if (loc != null &&
        (loc.type == LocationType.city || loc.type == LocationType.market)) {
      if (item.category == ItemCategory.treasure ||
          item.category == ItemCategory.relic) {
        factor += 0.1;
      }
    }
    return (item.value * factor).round();
  }

  /// 购买物品：从背包扣金币、入背包。
  ///
  /// 返回叙事文本；金币不足/地点不合适/未知物品返回说明。
  String buyItem(String itemId, [int quantity = 1]) {
    if (quantity < 1) quantity = 1;
    final item = itemById(itemId);
    if (item == null) {
      return '没有「$itemId」这种东西可买。';
    }
    final loc = currentLocation;
    if (loc == null ||
        (loc.type != LocationType.city &&
            loc.type != LocationType.market &&
            loc.type != LocationType.castle &&
            loc.type != LocationType.village &&
            loc.type != LocationType.fort)) {
      return '这里没有商贩。去城市、集市、城堡或村镇找找看。';
    }
    final price = buyPriceOf(itemId) * quantity;
    if (player.gold < price) {
      return '你只有 ${player.gold} 金币，买不起 ${quantity} 件「${item.name}」（需 $price 金币）。';
    }
    gainGold(-price);
    for (var i = 0; i < quantity; i++) {
      addItem(itemId);
    }
    return '你花 $price 金币买下 $quantity 件「${item.name}」。'
        '${loc.type == LocationType.city || loc.type == LocationType.market ? '（市场价公道）' : ''}';
  }

  /// 出售物品：从背包移除、得金币。
  ///
  /// 返回叙事文本；没有该物品/地点不合适返回说明。
  String sellItem(String itemId, [int quantity = 1]) {
    if (quantity < 1) quantity = 1;
    final item = itemById(itemId);
    if (item == null) {
      return '没有「$itemId」这种东西可卖。';
    }
    final have = itemCount(itemId);
    if (have < quantity) {
      return '你只有 $have 件「${item.name}」，卖不了 $quantity 件。';
    }
    final loc = currentLocation;
    if (loc == null ||
        (loc.type != LocationType.city &&
            loc.type != LocationType.market &&
            loc.type != LocationType.castle &&
            loc.type != LocationType.village &&
            loc.type != LocationType.fort)) {
      return '这里没有收购的人。去城市、集市、城堡或村镇找找看。';
    }
    final price = sellPriceOf(itemId) * quantity;
    for (var i = 0; i < quantity; i++) {
      removeItem(itemId);
    }
    gainGold(price);
    return '你卖出 $quantity 件「${item.name}」，得到 $price 金币。';
  }

  /// 市场行情：当前地点可买/可卖的关键物品价格。
  String formatMarketPanel() {
    final loc = currentLocation;
    if (loc == null) {
      return '你不在任何已知地点，没有市场行情。';
    }
    final buf = StringBuffer()..writeln('【${loc.name} · 行情】');
    // 展示常用物品买卖价
    final demo = <String>[
      'item_bread', 'item_meat', 'item_wine', 'item_herb', 'item_poultice',
      'item_sword', 'item_bow', 'item_leather_armor', 'item_chainmail',
      'item_steel', 'item_dragonbone', 'item_gold_chain', 'item_ruby',
      'item_heart_tree_leaf', 'item_horse',
    ];
    for (final id in demo) {
      final item = itemById(id);
      if (item == null) continue;
      buf.writeln('· ${item.name}：买 ${buyPriceOf(id)} / 卖 ${sellPriceOf(id)}');
    }
    return buf.toString().trim();
  }

  // ==================== 装备系统（Batch 10-4） ====================

  /// 已装备的物品 ID 列表（武器优先，从 flags.equipped.<itemId> 推导）。
  List<String> get equippedItems {
    final result = <String>[];
    for (final id in kItems.keys) {
      if (flagOf('equipped.$id')) {
        result.add(id);
      }
    }
    return result;
  }

  /// 装备一件物品（仅武器/护甲/坐骑可装备）。
  ///
  /// 返回叙事文本；不可装备/未持有/已装备返回说明。
  String equip(String itemId) {
    final item = itemById(itemId);
    if (item == null) return '没有「$itemId」这种东西。';
    if (item.category != ItemCategory.weapon &&
        item.category != ItemCategory.armor &&
        item.category != ItemCategory.mount) {
      return '「${item.name}」不能装备。只有武器、护甲或坐骑可以。';
    }
    if (itemCount(itemId) <= 0) {
      return '你没有「${item.name}」。';
    }
    if (flagOf('equipped.$itemId')) {
      return '你已经装备了「${item.name}」。';
    }
    // 同槽位替换：卸下同分类已装备
    for (final eid in equippedItems) {
      final eItem = itemById(eid);
      if (eItem != null && eItem.category == item.category) {
        setFlag('equipped.$eid', false);
      }
    }
    setFlag('equipped.$itemId', true);
    return '你装备了「${item.name}」。${item.category == ItemCategory.mount ? '它能驮着你走更远的路。' : ''}';
  }

  /// 卸下装备。
  String unequip(String itemId) {
    if (!flagOf('equipped.$itemId')) {
      return '你并没有装备「${itemName(itemId)}」。';
    }
    setFlag('equipped.$itemId', false);
    return '你卸下了「${itemName(itemId)}」。';
  }

  /// 战斗值：技能 + 装备 + 属性综合。
  ///
  /// 用于战斗/狩猎判定，数值越高越有利。
  int combatPower() {
    var power = skillLevel('sword') * 2 + skillLevel('archery');
    power += (player.attributes['strength'] ?? 0) ~/ 2;
    // 装备加成：武器/护甲按价值折算
    for (final id in equippedItems) {
      final item = itemById(id);
      if (item == null) continue;
      switch (item.category) {
        case ItemCategory.weapon:
          power += item.value ~/ 20; // 瓦雷利亚匕首 500/20=25
        case ItemCategory.armor:
          power += item.value ~/ 30; // 板甲 220/30≈7
        case ItemCategory.mount:
          power += 2;
        default:
          break;
      }
    }
    return power;
  }

  /// 已装备面板文本。
  String formatEquipmentPanel() {
    if (equippedItems.isEmpty) return '【装备】\n你两手空空，没有装备任何武器或护甲。';
    final buf = StringBuffer()..writeln('【装备】');
    for (final id in equippedItems) {
      final item = itemById(id);
      if (item != null) {
        buf.writeln('· ${item.name}（${itemCategoryLabel(item.category)}）');
      }
    }
    buf.writeln('· 战斗值：${combatPower()}');
    return buf.toString().trim();
  }

  // ==================== 头衔系统（Batch 10-4） ====================

  /// 头衔晋升检查：按声望/身份自动晋升。
  ///
  /// 每次调用返回是否晋升；晋升后写入 player.title。
  /// 由月度结算与关键事件触发。
  String checkTitlePromotion() {
    final p = player;
    if (!(p.flags['isAlive'] ?? true)) return '';
    final rep = p.reputation;
    final current = p.title;
    String target = current;

    // 按身份分级设定头衔（声望门槛）
    switch (p.identity) {
      case PlayerIdentity.noble:
        if (rep >= 80) target = '大领主';
        if (rep >= 60) target = '伯爵';
        if (rep >= 40) target = '爵士';
        break;
      case PlayerIdentity.soldier:
        if (rep >= 70) target = '统帅';
        if (rep >= 50) target = '骑士';
        if (rep >= 30) target = '军士';
        break;
      case PlayerIdentity.merchant:
        if (rep >= 70) target = '商会会长';
        if (rep >= 50) target = '富商';
        if (rep >= 30) target = '兴业商人';
        break;
      case PlayerIdentity.priest:
        if (rep >= 70) target = '大主教';
        if (rep >= 50) target = '主教';
        if (rep >= 30) target = '司祭';
        break;
      case PlayerIdentity.scholar:
      case PlayerIdentity.maester:
        if (rep >= 70) target = '大学士';
        if (rep >= 50) target = '资深学者';
        if (rep >= 30) target = '讲席学者';
        break;
      case PlayerIdentity.adventurer:
        if (rep >= 70) target = '传奇冒险家';
        if (rep >= 50) target = '知名冒险家';
        if (rep >= 30) target = '资深冒险家';
        break;
      case PlayerIdentity.assassin:
        if (rep >= 70) target = '无面者';
        if (rep >= 50) target = '血影';
        if (rep >= 30) target = '暗行者';
        break;
      case PlayerIdentity.wildling:
        if (rep >= 70) target = '自由民之王';
        if (rep >= 50) target = '战首';
        if (rep >= 30) target = '猎手';
        break;
      case PlayerIdentity.commoner:
        if (rep >= 60) target = '乡绅';
        break;
    }

    if (target != current && target.isNotEmpty) {
      updatePlayer(player.copyWith(title: target));
      return target;
    }
    return '';
  }

  /// 头衔面板：当前头衔 + 晋升进度。
  String formatTitlePanel() {
    final p = player;
    final buf = StringBuffer()
      ..writeln('【头衔】')
      ..writeln('· 当前：${p.title.isEmpty ? '无名之辈' : p.title}');
    // 查询下一级门槛
    final thresholds = switch (p.identity) {
      PlayerIdentity.noble => const <int>[40, 60, 80],
      PlayerIdentity.soldier => const <int>[30, 50, 70],
      PlayerIdentity.merchant => const <int>[30, 50, 70],
      PlayerIdentity.priest => const <int>[30, 50, 70],
      PlayerIdentity.scholar || PlayerIdentity.maester => const <int>[30, 50, 70],
      PlayerIdentity.adventurer => const <int>[30, 50, 70],
      PlayerIdentity.assassin => const <int>[30, 50, 70],
      PlayerIdentity.wildling => const <int>[30, 50, 70],
      PlayerIdentity.commoner => const <int>[60],
    };
    final next = thresholds.where((t) => t > p.reputation).toList();
    if (next.isNotEmpty) {
      buf.writeln('· 距下次晋升还差 ${next.first - p.reputation} 点声望（${next.first}）。');
    } else {
      buf.writeln('· 声望已达 ${p.identity.name} 的巅峰。');
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