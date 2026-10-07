/// 生存状态混入：健康 / 精力 / 饱食 管理与物品系统。
///
/// 新增维度（Batch 10）：
/// - 精力：进行活动消耗，休息/进食恢复；精力不足时活动受限
/// - 饱食：逐月下降，进食恢复；过低会掉健康
/// - 健康：0 死亡；受伤/疾病/危险事件会降低
/// - 物品：背包增删、使用消耗品（health/energy/hunger 效果）
library;
import '../data/balance_data.dart';
import '../data/item_data.dart';
import '../models/location.dart';
import '../models/player.dart';
import '../core/command_registry.dart';
import '../core/monthly_pipeline.dart';
import '../utils/command_alias.dart';
import '../providers/game_provider_base.dart';
import '../utils/labels.dart';

/// 生存状态混入。挂在 [GameProviderBase] 上。
///
/// 供 [GamePlayMixin] 在月度循环中调用 [applyMonthlyLife]，
/// 因此宿主混入顺序需保证本 mixin 在 GamePlayMixin 之前。
mixin GameLifeMixin on GameProviderBase {
  // 数值统一收口在 lib/data/balance_data.dart（Batch 10-30 · M4a）。
  // 以下常量保留原名并转发，避免调用点与既有测试改动。

  /// 精力不足时活动成功率折扣。
  static const double kLowEnergyPenalty = BalanceData.lowEnergyPenalty;

  /// 饱食每月的自然下降量。
  static const int kHungerDecayPerMonth = BalanceData.hungerDecayPerMonth;

  /// 饱食低于此阈值视为饥饿（每月掉健康）。
  static const int kStarvationThreshold = BalanceData.starvationThreshold;

  /// 精力恢复：休息/进食的恢复量。
  static const int kRestEnergyRecovery = BalanceData.restEnergyRecovery;

  /// 健康自然恢复（非受伤时每月 +2）。
  static const int kHealthRegen = BalanceData.healthRegen;

  /// 精力是否充足（低于 20 视为疲惫）。
  bool get isExhausted => player.energy < BalanceData.exhaustedEnergy;

  /// 饱食是否过低（饥饿）。
  bool get isStarving => player.hunger < kStarvationThreshold;

  /// 是否受伤（flag 由事件/狩猎设置）。
  bool get isInjured => flagOf('isInjured');

  // ==================== 数值调整（统一 clamp） ====================

  /// 调整精力（clamp 0~100），并写入玩家。
  void adjustEnergy(int delta) {
    updatePlayer(
      player.copyWith(energy: (player.energy + delta).clamp(0, BalanceData.fullVital)),
    );
  }

  /// 调整饱食（clamp 0~100，0 表示最饿）。
  void adjustHunger(int delta) {
    updatePlayer(
      player.copyWith(hunger: (player.hunger + delta).clamp(0, BalanceData.fullVital)),
    );
  }

  /// 调整健康（clamp 0~100；0 触发死亡判定）。
  void adjustHealth(int delta) {
    final newHealth = (player.health + delta).clamp(0, BalanceData.fullVital);
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
  /// 议价成功后（Batch 10-11）买价再降 [_negotiatedDiscount]%。
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
    var price = (item.value * factor).round();
    if (_negotiatedDiscount > 0) {
      price = (price * (100 - _negotiatedDiscount) / 100).round();
    }
    return price;
  }

  /// 出售价格：物品价值 × 出售折扣 × 地点系数。
  ///
  /// 珍宝/圣物/武器在城市的收购价更高，乡村/荒野贱卖。
  /// 议价成功后（Batch 10-11）卖价按 [_negotiatedDiscount]% 上浮。
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
    var price = (item.value * factor).round();
    if (_negotiatedDiscount > 0) {
      price = (price * (100 + _negotiatedDiscount) / 100).round();
    }
    return price;
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
    final loc = currentLocation;
    if (loc == null ||
        (loc.type != LocationType.city &&
            loc.type != LocationType.market &&
            loc.type != LocationType.castle &&
            loc.type != LocationType.village &&
            loc.type != LocationType.fort)) {
      return '这里没有收购的人。去城市、集市、城堡或村镇找找看。';
    }
    final have = itemCount(itemId);
    if (have < quantity) {
      return '你只有 $have 件「${item.name}」，卖不了 $quantity 件。';
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

  // ==================== 贸易深化（Batch 10-11） ====================

  /// 本次议价折扣（0-100 的百分比）。议价成功后生效，跨日重置。
  int _negotiatedDiscount = 0;

  /// 新增贸易活动的每月次数上限（自包含，避免依赖 GamePlayMixin 私有状态）。
  static const Map<String, int> kNewDailyLimits = <String, int>{
    'trade_specialty': 2,
    'negotiate': 1,
    'convoy': 1,
  };

  Map<String, int> _b1011DailyCount = <String, int>{};
  String? _b1011DailyMonth;

  String get _b1011Today => '${progress.year}-${progress.month}';

  /// 跨月重置新增活动的每月计数，并清除议价折扣。
  void _b1011RollDaily() {
    if (_b1011DailyMonth != _b1011Today) {
      _b1011DailyMonth = _b1011Today;
      _b1011DailyCount = <String, int>{};
      _negotiatedDiscount = 0;
      if (flagOf('negotiated')) setFlag('negotiated', false);
    }
  }

  bool _b1011CanDo(String activity) {
    _b1011RollDaily();
    return (_b1011DailyCount[activity] ?? 0) < (kNewDailyLimits[activity] ?? 99);
  }

  void _b1011Record(String activity) {
    _b1011RollDaily();
    _b1011DailyCount[activity] = (_b1011DailyCount[activity] ?? 0) + 1;
  }

  /// 地区特产映射：每个区域的代表物品（买价更便宜，卖到其他区域更贵）。
  ///
  /// 用于「地区特产巡游」与跨区套利。
  static const Map<String, List<String>> kRegionSpecialties = <String, List<String>>{
    '北境': <String>['item_meat', 'item_fish', 'item_heart_tree_leaf', 'item_garron'],
    '河间地': <String>['item_bread', 'item_herb', 'item_parchment'],
    '谷地': <String>['item_wine', 'item_fish', 'item_chainmail'],
    '西境': <String>['item_iron_ore', 'item_steel', 'item_gold_chain'],
    '河湾地': <String>['item_bread', 'item_wine', 'item_meat', 'item_horse'],
    '王领': <String>['item_wine', 'item_ruby', 'item_crown'],
    '风暴地': <String>['item_fish', 'item_sword', 'item_leather'],
    '多恩': <String>['item_wine', 'item_sapphire', 'item_herb'],
    '铁群岛': <String>['item_fish', 'item_iron_ore', 'item_steel'],
    '厄索斯': <String>['item_ruby', 'item_sapphire', 'item_dragonbone', 'item_glass_candle'],
    '超自然': <String>['item_dragonbone', 'item_glass_candle', 'item_lightbringer_shard'],
    '未知世界': <String>['item_ruby', 'item_dragonbone', 'item_heart_tree_leaf'],
  };

  /// 地区特产加成：在特产产地购买特产更便宜（×0.8），出售到异乡更贵。
  ///
  /// 返回价格调整后的买卖价（加成前的基础值）。
  ({int buy, int sell}) specialtyAdjustedPrice(String itemId) {
    final item = itemById(itemId);
    if (item == null) return (buy: 0, sell: 0);
    final loc = currentLocation;
    final isLocalSpecialty = loc != null &&
        (kRegionSpecialties[loc.region]?.contains(itemId) ?? false);

    // 基础价（未考虑地点系数，仅考虑特产关系）
    final base = item.value;
    if (isLocalSpecialty) {
      // 产地自产自销：买便宜、卖也便宜（供过于求）
      return (buy: (base * 0.8).round(), sell: (base * 0.4).round());
    }
    // 非特产：正常买卖（卖价略低于买价）
    return (buy: base, sell: (base * 0.6).round());
  }

  /// 地区特产巡游：在当前区域收购特产，带到其他区域高价出售。
  ///
  /// 消耗精力，按「是否在特产产地」与随机波动决定利润。
  String tradeSpecialty() {
    if (!_b1011CanDo('trade_specialty')) {
      return '你本月的商路已经跑完了。';
    }
    if (!canAffordEnergy(BalanceData.tradeSpecialtyEnergyCost)) {
      return '你精疲力竭，无力再跑商路。先去休息吧。';
    }
    final loc = currentLocation;
    if (loc == null) return '你不在任何已知地点。';
    adjustEnergy(-BalanceData.tradeSpecialtyEnergyCost);
    _b1011Record('trade_specialty');

    final specialties = kRegionSpecialties[loc.region] ?? const <String>[];
    if (specialties.isEmpty) {
      return '${loc.region} 似乎没有值得倒腾的特产。去别处看看吧。';
    }
    final rnd = rng();
    final itemId = specialties[rnd.nextInt(specialties.length)];
    final item = itemById(itemId);
    if (item == null) return '这里看似有特产，却无人识货。';
    final isMerchant = isIdentity(PlayerIdentity.merchant);
    // 收购特产（件数收口 BalanceData.tradeSpecialtyQty）
    final qty = BalanceData.tradeSpecialtyQty;
    final buy = buyPriceOf(itemId) * qty;
    if (player.gold < buy) {
      return '你买不起 $qty 件「${item.name}」（需 $buy 金币）。先攒点本钱吧。';
    }
    gainGold(-buy);
    for (var i = 0; i < qty; i++) {
      addItem(itemId);
    }
    // 商人加成 + 口才加成
    final premium = (isMerchant
            ? BalanceData.tradeSpecialtyMerchantPremium
            : BalanceData.tradeSpecialtyCommonerPremium) +
        skillLevel('speech') * BalanceData.tradeSpecialtySpeechGain;
    final sellEstimate = (sellPriceOf(itemId) * qty * (1 + premium)).round();
    final profit = sellEstimate - buy;
    final mood = profit >= 0 ? '这是一笔不错的买卖。' : '本钱压住了，得找更大的市场出手。';
    return '你在${loc.name}（${loc.region}）收购 $qty 件「${item.name}」'
        '（花 $buy 金币）。按异地行情估算可卖 $sellEstimate 金币（利润约 $profit）。$mood';
  }

  /// 商人议价：通过口才与身份，压低买入价 / 抬高卖出价。
  ///
  /// 议价有冷却（每回合一次），成功后本回合买卖价获得折扣/加成。
  String negotiate() {
    if (!_b1011CanDo('negotiate')) {
      return '你本月的议价机会已经用过了。';
    }
    if (!canAffordEnergy(BalanceData.negotiateEnergyCost)) {
      return '你口干舌燥，无力再费口舌。';
    }
    adjustEnergy(-BalanceData.negotiateEnergyCost);
    _b1011Record('negotiate');
    final loc = currentLocation;
    if (loc == null ||
        (loc.type != LocationType.city &&
            loc.type != LocationType.market &&
            loc.type != LocationType.castle &&
            loc.type != LocationType.village)) {
      return '这里没有商贩，无处议价。';
    }
    final rnd = rng();
    final speech = skillLevel('speech');
    final isMerchant = isIdentity(PlayerIdentity.merchant);
    // 议价成功率：口才 * 8% + 商人加成 20% + 随机
    final baseChance = speech * BalanceData.negotiateSpeechChanceMult +
        (isMerchant ? BalanceData.negotiateMerchantBonus : 0) +
        rnd.nextInt(BalanceData.negotiateChanceVariance);
    if (baseChance < BalanceData.negotiateSuccessThreshold) {
      return '你费尽口舌，商贩油盐不进，一分钱都不肯让。';
    }
    // 议价幅度：口才越高让利越多（基础 + 随机浮动 + 口才加成）
    final discount = BalanceData.negotiateDiscountBase +
        rnd.nextInt(BalanceData.negotiateDiscountVariance) +
        speech.clamp(0, 3) * BalanceData.negotiateDiscountPerSpeech;
    setFlag('negotiated', true);
    _negotiatedDiscount = discount;
    notifyListeners();
    return '你成功议价：本日买价再降 $discount%，卖价相应上浮。'
        '（商贩摇头：「你这张嘴，不当商人都可惜了。」）';
  }

  /// 商队护送：接受一份护送委托，按战斗值/骑术判定报酬与风险。
  ///
  /// 消耗精力，成功得金币与声望，失败可能受伤。
  String convoy() {
    if (!_b1011CanDo('convoy')) {
      return '本月没有商队愿意等你。';
    }
    if (!canAffordEnergy(BalanceData.convoyEnergyCost)) {
      return '你太累了，护不了商队。';
    }
    adjustEnergy(-BalanceData.convoyEnergyCost);
    _b1011Record('convoy');
    final loc = currentLocation;
    if (loc == null) return '你不在任何已知地点。';
    final rnd = rng();
    final power = combatPower();
    final isMerchant = isIdentity(PlayerIdentity.merchant);
    // 战斗判定：战斗值 + 骑术加成 + 商人议价（商人更懂行价）
    final score = power * BalanceData.convoyScorePowerMult +
        skillLevel('riding') * BalanceData.convoyScoreRidingMult +
        (isMerchant ? BalanceData.convoyMerchantBonus : 0) +
        rnd.nextInt(BalanceData.convoyScoreVariance);
    final baseFee = BalanceData.convoyBaseFee +
        power * BalanceData.convoyFeePowerMult +
        rnd.nextInt(BalanceData.convoyFeeVariance);
    if (score >= BalanceData.convoySuccessThreshold) {
      gainGold(baseFee);
      adjustReputation(BalanceData.convoyReputationGain);
      return '你一路护送商队穿越${loc.region}，击退两拨匪徒。商队老板付你 $baseFee 金币，还替你扬了名。';
    }
    if (score >= BalanceData.convoyPartialThreshold) {
      gainGold((baseFee * BalanceData.convoyPartialRate).round());
      return '商队遇上几伙小毛贼，你有惊无险地护了过去。拿到 ${(baseFee * BalanceData.convoyPartialRate).round()} 金币。';
    }
    // 失败：受伤但保住货物
    adjustHealth(-BalanceData.convoyInjuryHealth);
    return '商队在路口遭了埋伏，你奋力搏杀才护住货物，自己却挂了彩（健康 -${BalanceData.convoyInjuryHealth}）。商队付你 ${(baseFee * BalanceData.convoyFailRate).round()} 金币聊表谢意。';
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

    // 头衔阶梯统一收口在 BalanceData（Batch 10-30 · M4a），
    // 与 formatTitlePanel 共用同一份数据，杜绝双真相。
    final target = BalanceData.promotedTitle(p.identity.name, rep);
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
    final nextRep = BalanceData.nextTierReputation(p.identity.name, p.reputation);
    if (nextRep > 0) {
      buf.writeln('· 距下次晋升还差 ${nextRep - p.reputation} 点声望（$nextRep）。');
    } else {
      buf.writeln('· 声望已达 ${identityLabel(p.identity)} 的巅峰。');
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
    if (oldHunger >= BalanceData.hungerWarning &&
        player.hunger < BalanceData.hungerWarning) {
      buf.writeln('🍞 你感到腹中空空，该去找点吃的了。');
    }

    // 2. 饥饿减益：持续饥饿掉健康
    if (isStarving) {
      adjustHealth(-BalanceData.starvationHealthPenalty);
      buf.writeln('⚠️ 长期饥饿正在侵蚀你的身体（健康 -8）。');
    }

    // 3. 精力/健康自然恢复（月内休息足够时）
    final sleptWell =
        !isExhausted && rnd.nextDouble() < BalanceData.sleptWellChance;
    if (sleptWell) {
      final energyGain =
          BalanceData.sleepEnergyBase + rnd.nextInt(BalanceData.sleepEnergyVariance);
      adjustEnergy(energyGain);
    } else {
      buf.writeln('💤 你睡眠不佳，精力恢复缓慢。');
    }
    if (!isInjured && player.health < BalanceData.fullVital) {
      adjustHealth(kHealthRegen);
    }

    // 4. 受伤缓慢恢复（每月小概率好转）
    if (isInjured && rnd.nextDouble() < BalanceData.injuryHealChance) {
      setFlag('isInjured', false);
      buf.writeln('🩹 你的伤势渐渐好转，已经不妨碍行动了。');
    }

    // 5. 冬季更冷更饿
    if (progress.season == 'winter') {
      adjustHunger(-BalanceData.winterHungerExtra);
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

  /// 解析「购买 <物品> <数量>」参数并执行（Batch 10-28 从 mixin_commands 迁入）。
  String buyFromArgs(String args) {
    final parts = args.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final namePart = parts.first;
    var quantity = 1;
    if (parts.length > 1) {
      quantity = int.tryParse(parts[1]) ?? 1;
    }
    final itemId = normalizeItemAlias(namePart);
    if (!isKnownItemId(itemId)) {
      return '这里买不到「$namePart」。输入「行情」看看有什么可买。';
    }
    return buyItem(itemId, quantity);
  }

  /// 解析「出售 <物品> <数量>」参数并执行（Batch 10-28 从 mixin_commands 迁入）。
  String sellFromArgs(String args) {
    final parts = args.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final namePart = parts.first;
    var quantity = 1;
    if (parts.length > 1) {
      quantity = int.tryParse(parts[1]) ?? 1;
    }
    final itemId = normalizeItemAlias(namePart);
    if (!isKnownItemId(itemId)) {
      return '你没有「$namePart」这种东西。';
    }
    return sellItem(itemId, quantity);
  }

  // ==================== M3 · 指令自注册 ====================

  /// 把本领域指令注册进注册表（order 与历史帮助文本顺序一致）。
  void registerLifeCommands(CommandRegistry registry) {
    registry.register(
      CommandSpec(
        aliases: const ['背包', 'bag', 'inventory'],
        order: 2,
        helpLine: '背包 / bag          查看背包物品',
        handler: (args) => CommandResult(text: formatInventoryPanel()),
      ),
    );
    registry.register(
      CommandSpec(
        aliases: const ['使用', 'use'],
        order: 3,
        requiredArgCount: 1,
        missingArgsHint: '使用什么？如「使用 黑面包」或「使用 item_meat」。',
        helpLine: '使用 / use [物品]    使用消耗品（如 使用 黑面包）',
        handler: (args) => CommandResult(text: useItem(normalizeItemAlias(args))),
      ),
    );
    registry.register(
      CommandSpec(
        aliases: const ['巡游', '特产', 'specialty'],
        order: 13,
        helpLine: '巡游 / specialty    地区特产巡游：当地收特产，异地高价出售（消耗精力）',
        handler: (args) => CommandResult(text: tradeSpecialty()),
      ),
    );
    registry.register(
      CommandSpec(
        aliases: const ['议价', 'negotiate'],
        order: 14,
        helpLine: '议价 / negotiate    商人议价：口才决定买卖折价（每月 1 次）',
        handler: (args) => CommandResult(text: negotiate()),
      ),
    );
    registry.register(
      CommandSpec(
        aliases: const ['商队', '护送', 'convoy'],
        order: 15,
        helpLine: '商队 / convoy       商队护送：按战斗值判定报酬与风险（每月 1 次）',
        handler: (args) => CommandResult(text: convoy()),
      ),
    );
    registry.register(
      CommandSpec(
        aliases: const ['购买', '买入', 'buy'],
        order: 16,
        requiredArgCount: 1,
        missingArgsHint: '买什么？如「购买 黑面包」或「买入 item_meat」。输入「行情」看价格。',
        helpLine: '购买 / buy [物品]    购买物品（如 购买 黑面包 或 买入 长剑）',
        handler: (args) => CommandResult(text: buyFromArgs(args)),
      ),
    );
    registry.register(
      CommandSpec(
        aliases: const ['出售', '卖出', 'sell'],
        order: 17,
        requiredArgCount: 1,
        missingArgsHint: '卖什么？如「出售 烤肉」或「卖出 item_wine」。',
        helpLine: '出售 / sell [物品]   出售物品（如 出售 烤肉 或 卖出 item_wine）',
        handler: (args) => CommandResult(text: sellFromArgs(args)),
      ),
    );
    registry.register(
      CommandSpec(
        aliases: const ['行情', 'market', '价格'],
        order: 18,
        helpLine: '行情 / market       查看当前地点物价',
        handler: (args) => CommandResult(text: formatMarketPanel()),
      ),
    );
    registry.register(
      CommandSpec(
        aliases: const ['装备', 'equip'],
        order: 19,
        requiredArgCount: 1,
        missingArgsHint: '装备什么？如「装备 长剑」或「装备 锁子甲」。',
        helpLine: '装备 / equip [物品]  装备武器/护甲/坐骑（如 装备 长剑）',
        handler: (args) => CommandResult(text: equip(normalizeItemAlias(args))),
      ),
    );
    registry.register(
      CommandSpec(
        aliases: const ['卸下', 'unequip'],
        order: 20,
        requiredArgCount: 1,
        missingArgsHint: '卸下什么？如「卸下 长剑」。',
        helpLine: '卸下 / unequip [物品] 卸下装备',
        handler: (args) => CommandResult(text: unequip(normalizeItemAlias(args))),
      ),
    );
    registry.register(
      CommandSpec(
        aliases: const ['装备栏', '装备面板', 'equipment'],
        order: 21,
        helpLine: '装备栏 / equipment   查看当前装备与战斗值',
        handler: (args) => CommandResult(text: formatEquipmentPanel()),
      ),
    );
    registry.register(
      CommandSpec(
        aliases: const ['头衔', 'title'],
        order: 22,
        helpLine: '头衔 / title       查看头衔与晋升进度',
        handler: (args) => CommandResult(text: formatTitlePanel()),
      ),
    );
  }
  // ==================== M3 · 月度结算管线自注册 ====================

  /// 把本领域（生存结算 + 头衔晋升）钩子注册进管线。
  ///
  /// 注意：头衔晋升在旧实现里第 3 个执行，但文案排在任务逾期之后，
  /// 故 order 与 outputOrder 不同。
  void registerLifeMonthlyHooks(MonthlyPipeline pipeline) {
    pipeline.register(
      MonthlyHookSpec(
        id: 'life',
        phase: MonthlyPhase.beforeAdvance,
        order: 2,
        outputOrder: 2,
        hook: () => MonthlyHookResult(
          text: applyMonthlyLife(seed: progress.turnCount),
          outputOrder: 2,
        ),
      ),
    );
    pipeline.register(
      MonthlyHookSpec(
        id: 'title',
        phase: MonthlyPhase.beforeAdvance,
        order: 3,
        outputOrder: 9,
        hook: () {
          final t = checkTitlePromotion();
          return MonthlyHookResult(
            text: t.isEmpty ? '' : '🏆 你获得新头衔：$t！',
            outputOrder: 9,
          );
        },
      ),
    );
  }
}
