/// 数值配置集中（Batch 10-30 · M4a · 内容管道与数值配置）。
///
/// 目标：调平衡不再全库 grep。原散落在 mixin 里的魔法数字统一收口到这里，
/// 各 mixin 的 `static const` 保留原名并转发到本文件（const 引用 const 是编译期常量），
/// 因此**既有测试与调用点零改动**。
///
/// 分组：
/// - 初始数值：开局金币/声望/年龄/生存三维
/// - 生存消耗：饱食衰减/饥饿阈值/恢复量/睡眠与伤势概率
/// - 每月上限：日常活动次数限制（键名仍为 dailyLimits，语义为每月）
/// - 头衔阶梯：按身份的声望晋升档位（消除 checkTitlePromotion 与 formatTitlePanel 的双真相）
/// - 活动经济：训练/狩猎/休息/商队护送的公式系数
/// - 婚姻与世代：感情等级/离婚成本/立嗣与濒死阈值
library;

/// 头衔档位：声望达到 [reputation] 即晋升为 [title]。
class TitleTier {
  const TitleTier(this.reputation, this.title);

  /// 声望门槛（含）。
  final int reputation;

  /// 晋升后的头衔名。
  final String title;
}

/// 全局数值配置（纯静态常量，无实例）。
class BalanceData {
  BalanceData._();

  // ==================== 初始数值 ====================

  /// 开局金币。
  static const int defaultGold = 100;

  /// 开局声望。
  static const int defaultReputation = 50;

  /// 开局年龄。
  static const int defaultAge = 18;

  /// 生命/精力初始值（满值）。
  static const int fullVital = 100;

  /// **S14-1**：开局饱食值（三条开局路径统一取此值）。
  ///
  /// 此前 `this.hunger = 60`（`player.dart` 构造器默认）/ `hunger: 60`
  /// （`start_screen.dart` 向导）/ `hunger: 60`（`mixin_generation` 继承）
  /// **三处各写一遍字面量**，改平衡要动三个地方、漏一处就出现「某条路径
  /// 开局就饿死」的老问题（S13-13 ⑱ 修过一次，正是从 0 改到 60）。
  static const int startingHunger = 60;

  /// 饱食下限（0 = 最饿）。**不是开局值**——见 [startingHunger]。
  ///
  /// 【S14-1 修正】此前本常量的注释写「饱食初始值（0 = 最饿）」，
  /// 而 S13-13 ⑱ 已把开局饱食从 0 改成 60 ⇒ **注释描述的是一个早已不存在的
  /// 开局状态**，任何照注释理解的人都会以为开局就该饿。改为明确的
  /// 「下限」语义，杜绝再次误用。
  static const int starvingHunger = 0;

  // ==================== 生存消耗 ====================

  /// 精力不足时活动成功率折扣。
  static const double lowEnergyPenalty = 0.5;

  /// 精力低于此值视为疲惫。
  static const int exhaustedEnergy = 20;

  /// 饱食每月的自然下降量。
  static const int hungerDecayPerMonth = 12;

  /// 饱食低于此阈值视为饥饿（每月掉健康）。
  static const int starvationThreshold = 25;

  /// 持续饥饿时每月扣健康。
  static const int starvationHealthPenalty = 8;

  /// 饱食跌破此值时给出「该找吃的了」提示。
  static const int hungerWarning = 60;

  /// 精力恢复：休息/进食的恢复量。
  static const int restEnergyRecovery = 40;

  /// 健康自然恢复（非受伤时每月）。
  static const int healthRegen = 2;

  /// 睡得好（精力未透支）的概率。
  static const double sleptWellChance = 0.7;

  /// 睡得好时精力恢复下限。
  static const int sleepEnergyBase = 15;

  /// 睡得好时精力恢复的随机浮动上限。
  static const int sleepEnergyVariance = 15;

  /// 受伤后每月痊愈概率。
  static const double injuryHealChance = 0.4;

  /// 冬季额外饱食消耗。
  static const int winterHungerExtra = 5;

  // ==================== 每月上限（S2-2：原名「每日上限」名不副实） ====================

  /// 活动次数上限（防数值刷子，参考 docs/08 玩法限制）。
  ///
  /// **注意是「每月」不是「每日」**：游戏没有「天」这一时间单位，
  /// 计数重置键是 `${年}-${月}`（见 `GamePlayMixin._rollDaily`）。
  /// 键名 `dailyLimits` 与相关 `*_Daily*` 标识系历史命名，为存档兼容未改，
  /// 但注释与玩家可见文案一律按「每月」表述。
  static const Map<String, int> dailyLimits = {
    'train': 3,
    'hunt': 2,
    'work': 2,
    'trade': 2,
    // S2-2：原为 99（装饰性，rest() 从不读它）。改为真实闸口：
    // 金币已是天然成本，但无上限时「精力管理」维度会失效，故给宽松上限。
    'rest': 10,
  };

  // ==================== 头衔阶梯 ====================

  /// 通用三档门槛（士兵/商人/神职/学者/学士/冒险者/刺客/野人共用）。
  ///
  /// 与旧实现逐字一致：30 / 50 / 70。
  static const int tier1Rep = 30;
  static const int tier2Rep = 50;
  static const int tier3Rep = 70;

  /// 贵族三档门槛（更高：40 / 60 / 80）。
  static const int nobleTier1Rep = 40;
  static const int nobleTier2Rep = 60;
  static const int nobleTier3Rep = 80;

  /// 贵族阶梯（声望升序）。
  static const List<TitleTier> nobleLadder = [
    TitleTier(nobleTier1Rep, '爵士'),
    TitleTier(nobleTier2Rep, '伯爵'),
    TitleTier(nobleTier3Rep, '大领主'),
  ];

  /// 士兵阶梯（声望升序）。
  static const List<TitleTier> soldierLadder = [
    TitleTier(tier1Rep, '军士'),
    TitleTier(tier2Rep, '骑士'),
    TitleTier(tier3Rep, '统帅'),
  ];

  /// 商人阶梯（声望升序）。
  static const List<TitleTier> merchantLadder = [
    TitleTier(tier1Rep, '兴业商人'),
    TitleTier(tier2Rep, '富商'),
    TitleTier(tier3Rep, '商会会长'),
  ];

  /// 神职阶梯（声望升序）。
  static const List<TitleTier> priestLadder = [
    TitleTier(tier1Rep, '司祭'),
    TitleTier(tier2Rep, '主教'),
    TitleTier(tier3Rep, '大主教'),
  ];

  /// 学者阶梯（声望升序，学士共用）。
  static const List<TitleTier> scholarLadder = [
    TitleTier(tier1Rep, '讲席学者'),
    TitleTier(tier2Rep, '资深学者'),
    TitleTier(tier3Rep, '大学士'),
  ];

  /// 冒险者阶梯（声望升序）。
  static const List<TitleTier> adventurerLadder = [
    TitleTier(tier1Rep, '资深冒险家'),
    TitleTier(tier2Rep, '知名冒险家'),
    TitleTier(tier3Rep, '传奇冒险家'),
  ];

  /// 刺客阶梯（声望升序）。
  static const List<TitleTier> assassinLadder = [
    TitleTier(tier1Rep, '暗行者'),
    TitleTier(tier2Rep, '血影'),
    TitleTier(tier3Rep, '无面者'),
  ];

  /// 野人阶梯（声望升序）。
  static const List<TitleTier> wildlingLadder = [
    TitleTier(tier1Rep, '猎手'),
    TitleTier(tier2Rep, '战首'),
    TitleTier(tier3Rep, '自由民之王'),
  ];

  /// 平民阶梯（仅一档）。
  static const List<TitleTier> commonerLadder = [
    TitleTier(60, '乡绅'),
  ];

  /// 各身份的头衔阶梯（键为 `PlayerIdentity.name`，统一按**声望升序**存储）。
  ///
  /// 覆盖全部 10 个身份；新增身份时 `test/m4_balance_test.dart` 的覆盖用例会红。
  ///
  /// 晋升判定 = 取满足 `reputation >= 门槛` 的最高一档；
  /// 面板「距下次晋升」= 取第一个 `门槛 > 当前声望` 的档位。
  static const Map<String, List<TitleTier>> titleLadders = {
    'noble': nobleLadder,
    'soldier': soldierLadder,
    'merchant': merchantLadder,
    'priest': priestLadder,
    'scholar': scholarLadder,
    'maester': scholarLadder,
    'adventurer': adventurerLadder,
    'assassin': assassinLadder,
    'wildling': wildlingLadder,
    'commoner': commonerLadder,
  };

  /// 取某身份的头衔阶梯（[identityKey] 取 `PlayerIdentity.name`；未知返回空列表）。
  ///
  /// 用 String 而非枚举，是为了让本文件成为**无 import 的叶子模块**：
  /// `lib/data/*` 普遍 import `lib/models/*`，反向依赖会形成 models ↔ data 循环。
  static List<TitleTier> ladderOf(String identityKey) {
    return titleLadders[identityKey] ?? const <TitleTier>[];
  }

  /// 晋升目标：返回声望应达到的最高一档头衔；无一档达标返回空串。
  static String promotedTitle(String identityKey, int reputation) {
    var result = '';
    for (final tier in ladderOf(identityKey)) {
      if (reputation >= tier.reputation) result = tier.title;
    }
    return result;
  }

  /// 下一档门槛：返回第一个严格大于 [reputation] 的档位门槛；已登顶返回 0。
  static int nextTierReputation(String identityKey, int reputation) {
    for (final tier in ladderOf(identityKey)) {
      if (tier.reputation > reputation) return tier.reputation;
    }
    return 0;
  }

  // ==================== 活动经济 ====================

  /// 技能等级上限（封顶）。
  static const int skillCap = 10;

  /// 属性上限（S13-13 ⑳）。
  ///
  /// prompt 一直向 AI 承诺「数值超出按边界截断」（`ai_service.dart:764`），
  /// 但 `skills.`/`attributes.` 的效果写入路径只有下限 `max(0, ...)`、
  /// 没有上限，`skillCap` 也从未被效果写入读取 ⇒ AI 写
  /// `skills.sword: 20` 会原样落盘，而属性门槛判定（`< required`）
  /// 与 `train()` 的上限提示都基于这两个刻度，写穿即失效。
  ///
  /// 取 10 与 [skillCap] 同刻度：属性初始 5、现有事件效果最大 +1
  /// （`event_data` 全库 `attributes.` 效果仅 2 处，均为 +1；其余
  /// `attributes.` 命中是门槛不是效果），门槛最高 6 ⇒ 封顶对现有内容
  /// 零影响，只是把「AI 可以写任意大」这条无界通道收口。
  static const int attributeCap = 10;

  /// 训练消耗的精力。
  static const int trainEnergyCost = 10;

  /// 训练基础成功率。
  static const double trainBaseChance = 0.8;

  /// 训练每级递减的成功率（越接近上限越难）。
  static const double trainChanceDecayPerLevel = 0.05;

  /// 狩猎成功率的基础项。
  static const double huntBaseChance = 0.5;

  /// 狩猎成功率：技能每点加成。
  static const double huntChancePerSkill = 0.05;

  /// 狩猎成功率：战斗值每点加成。
  static const double huntChancePerPower = 0.02;

  /// 狩猎成功率：地点危险度每点扣减。
  static const double huntChancePerDanger = 0.03;

  /// 狩猎成功率下限/上限。
  static const double huntChanceMin = 0.1;
  static const double huntChanceMax = 0.95;

  /// 狩猎收益基础金币。
  static const int huntRewardBase = 10;

  /// 狩猎收益：技能每点加成。
  static const int huntRewardPerSkill = 3;

  /// 狩猎收益随机浮动上限。
  static const int huntRewardVariance = 10;
  /// 狩猎收益：地点危险度每点加成（Batch 10-112，高危=高回报）。
  ///
  /// 【为什么需要】狩猎成功率随地点危险度递减（huntChancePerDanger）
  /// 且失败受伤风险递增，但收益却固定 10~19 金——高危地点狩猎是纯劣选项。
  ///
  /// 【为什么取 1 而非 2】CI 实测（run 37400319376）取 2 时 160 个月固定策略
  /// 金币达 5004，撞 m4_balance_sim_test 的 <5000 防爆炸护栏。每点 +1：
  /// 危险 6 的地点收益 +6，仍在基础收益的合理上浮带内，且 160 个月金币
  /// 回落至 ~4520，护栏余量恢复。危险度差异依然可感（6 点危险差 = 6 金币差）。
  static const int huntRewardPerDanger = 1;

  /// 狩猎失败的受伤概率。
  static const double huntInjuryChance = 0.3;

  /// 狩猎受伤的健康损失。
  static const int huntInjuryHealthCost = 5;

  /// 狩猎成功的饱食补充。
  static const int huntHungerGain = 15;

  /// 旅店住宿花费。
  static const int restInnCost = 2;

  // ==================== Batch 10-111 日常活动经济 ====================
  /// 工作消耗的精力（work）。
  static const int workEnergyCost = 15;
  /// 狩猎消耗的精力（hunt）。
  static const int huntEnergyCost = 20;
  /// 贸易消耗的精力（trade）。
  static const int tradeEnergyCost = 10;
  /// 工作基础收入按身份浮动（switch 各分支的基准值，身份排序：商人 > 士兵 > 其他 > 学者 > 神职 > 平民）。
  ///
  /// 数值与旧实现逐字一致（20/15/12/10/8/5），收入排序护栏见 regression_identity_branch_test。
  ///
  /// 键为 `PlayerIdentity.name`（本文件是无 import 叶子模块，用 String 而非枚举）。
  static const Map<String, int> workBaseIncome = <String, int>{
    'merchant': 20,
    'soldier': 15,
    'noble': 12,
    'adventurer': 12,
    'assassin': 12,
    'wildling': 12,
    'scholar': 10,
    'maester': 10,
    'priest': 8,
    'commoner': 5,
  };
  /// 工作收入的随机浮动上限（rnd.nextInt 的上界）。
  static const int workIncomeVariance = 5;
  /// 工作技能加成：口才/剑术每 2 级 +1 金币（`~/ 2` 的系数）。
  static const int workSkillBonusDivisor = 2;
  /// 贸易基础利润：商人 vs 平民（差值恒 17，被 regression_identity_branch_test 锁定）。
  static const int tradeMerchantBase = 25;
  static const int tradeCommonerBase = 8;
  /// 贸易口才加成：每级口才 +3 金币。
  static const int tradeSpeechGain = 3;
  /// 贸易利润随机浮动上限。
  static const int tradeProfitVariance = 15;
  /// 休息的饱食恢复量。
  static const int restHungerGain = 10;
  // ==================== Batch 10-113 NPC 交互经济 ====================
  /// 深聊/示好的好感基础值（speech 每 2 级 +1，随机浮动 [npcFavorGainVariance)）。
  static const int npcChatGainBase = 3;
  /// 深聊/示好好感随机浮动上限。
  static const int npcChatGainVariance = 3;
  /// 示好礼金公式：基础 5 + (100 - 关系)~/20，钳制 [npcFavorCostMin, npcFavorCostMax]。
  static const int npcFavorCostBase = 5;
  static const int npcFavorCostDivisor = 20;
  static const int npcFavorCostMin = 3;
  static const int npcFavorCostMax = 12;
  /// 熟识请求·护送报酬：基础 15 + 关系 + rnd(10)。
  static const int escortFeeBase = 15;
  static const int escortFeeVariance = 10;
  /// 熟识请求·商人合股红利：基础 10 + 关系~/2 + rnd(10)。
  static const int merchantShareBase = 10;
  static const int merchantShareVariance = 10;
  /// 熟识请求·刺客委托报酬：基础 20 + 关系 + rnd(15)。
  static const int assassinFeeBase = 20;
  static const int assassinFeeVariance = 15;
  /// 任务结算奖励：基础 20 + 关系~/2。
  static const int taskRewardBase = 20;
  /// 任务结算/接取的关系奖励。
  static const int taskRewardRelation = 5;
  /// 任务接取时的关系奖励。
  static const int taskAcceptRelation = 2;
  /// 任务/声望类小奖励（声望 +N 通用档）。
  static const int reputationSmallGain = 2;
  /// 熟识请求·野人谢礼金币。
  static const int wildlingGiftGold = 5;
  /// 熟识请求·神职治疗健康恢复。
  static const int priestHealHealth = 5;
  /// 亲密交谈·秘密共享的关系奖励。
  static const int secretRelationGain = 3;
  /// 亲密交谈·普通/挚友的关系奖励。
  static const int chatRelationGain = 2;
  /// 熟识请求·贵族引荐声望奖励。
  static const int nobleReferReputation = 4;
  /// 熟识请求·超自然低语声望奖励。
  static const int supernaturalReputationGain = 3;
  // ==================== Batch 10-114 冒险/旅行经济 ====================
  /// 旅费公式：基础 2 + 目的地危险度 + rnd(4)。
  static const int travelCostBase = 2;
  static const int travelCostVariance = 4;
  /// 探索消耗的精力。
  static const int exploreEnergyCost = 15;
  /// 探索收益公式：基础 3 + rnd(10 + 危险度*2)。
  static const int exploreGoldBase = 3;
  static const int exploreGoldDangerMult = 2;
  static const int exploreGoldVarianceBase = 10;
  /// 遭遇·强盗损失公式：基础 5 + 危险度*2。
  static const int banditLossBase = 5;
  static const int banditLossDangerMult = 2;
  /// 遭遇·野兽收益公式：基础 8 + 危险度*2，附饱食恢复与受伤健康损失。
  static const int beastGainBase = 8;
  static const int beastGainDangerMult = 2;
  static const int beastHungerGain = 10;
  static const int beastInjuryHealth = 8;
  /// 遭遇·商人利润：基础 5 + rnd(10)。
  static const int merchantProfitBase = 5;
  static const int merchantProfitVariance = 10;
  /// 学者教学概率（0.4）。
  static const double scholarTeachChance = 0.4;

  // ==================== S2-4 探索/遭遇概率带（原为裸数字） ====================
  /// 探索结果分档（`roll < x`）：金币 → 物品 → 遭遇 → 一无所获。
  static const double exploreGoldBand = 0.4;
  static const double exploreItemBand = 0.62;
  static const double exploreEncounterBand = 0.85;
  /// 遭遇触发概率 = 地点危险度 × 本系数。
  static const double encounterChancePerDanger = 0.12;
  /// 遭遇类型分档（`roll < x`）：强盗 → 野兽 → 商人 → 神秘事件。
  static const double encounterBanditBand = 0.35;
  static const double encounterBeastBand = 0.7;
  static const double encounterMerchantBand = 0.85;
  /// 遭遇·强盗：剑术不足时的击退概率。
  static const double banditRepelChance = 0.5;
  /// 遭遇·野兽：逃脱概率 / 逃脱失败的受伤概率。
  static const double beastEscapeChance = 0.6;
  static const double beastInjuryChance = 0.3;
  /// 遭遇·商人：议价成功的额外利润概率。
  static const double merchantHaggleChance = 0.4;
  /// 遭遇·神秘：非超自然地点触发神秘事件的概率。
  static const double supernaturalEncounterChance = 0.1;
  /// 探索掉落物品的概率闸门（1 - 本值 = 掉落率）。
  static const double exploreItemDropGate = 0.6;
  // ==================== Batch 10-115 商队护送经济 ====================
  /// 商队护送消耗的精力。
  static const int convoyEnergyCost = 15;
  /// 护送判定分数：战斗值/骑术每点加成。
  static const int convoyScorePowerMult = 2;
  static const int convoyScoreRidingMult = 2;
  /// 护送判定：商人身份的额外加成。
  static const int convoyMerchantBonus = 5;
  /// 护送判定随机浮动上限。
  static const int convoyScoreVariance = 20;
  /// 护送报酬基础值。
  static const int convoyBaseFee = 30;
  /// 护送报酬：战斗值每点加成。
  static const int convoyFeePowerMult = 2;
  /// 护送报酬随机浮动上限。
  static const int convoyFeeVariance = 20;
  /// 护送判定档位阈值（全额 / 部分）。
  static const int convoySuccessThreshold = 40;
  static const int convoyPartialThreshold = 25;
  /// 护送部分成功/失败的报酬比例。
  static const double convoyPartialRate = 0.6;
  static const double convoyFailRate = 0.3;
  /// 护送失败的健康损失。
  static const int convoyInjuryHealth = 10;
  /// 护送全额成功的声望奖励。
  static const int convoyReputationGain = 3;
  // ==================== Batch 10-116 巡游/议价经济 ====================
  /// 地区特产巡游消耗的精力。
  static const int tradeSpecialtyEnergyCost = 12;
  /// 地区特产巡游每次收购件数。
  static const int tradeSpecialtyQty = 2;
  /// 特产异地溢价：商人/平民基础加成。
  static const double tradeSpecialtyMerchantPremium = 0.35;
  static const double tradeSpecialtyCommonerPremium = 0.15;
  /// 特产异地溢价：每级口才加成。
  static const double tradeSpecialtySpeechGain = 0.03;
  /// 商人议价消耗的精力。
  static const int negotiateEnergyCost = 5;
  /// 议价成功率：每级口才的百分数加成。
  static const int negotiateSpeechChanceMult = 8;
  /// 议价成功率：商人身份的额外加成。
  static const int negotiateMerchantBonus = 20;
  /// 议价成功率随机浮动上限。
  static const int negotiateChanceVariance = 20;
  /// 议价成功阈值。
  static const int negotiateSuccessThreshold = 40;
  /// 议价折扣：基础 5% + rnd(15) + 口才(clamp 0~3)*2。
  static const int negotiateDiscountBase = 5;
  static const int negotiateDiscountVariance = 15;
  static const int negotiateDiscountPerSpeech = 2;

  // ==================== 婚姻与世代 ====================

  /// 夫妻感情「恩爱」门槛。
  static const int spouseDevotedAffection = 70;

  /// 夫妻感情「和睦」门槛（低于此为疏离）。
  static const int spouseHarmoniousAffection = 30;

  /// 离婚补偿金（防无限再婚刷声望）。
  static const int divorceCost = 30;

  /// 配偶互动每月次数上限。
  static const int spouseDailyLimit = 1;

  /// 配偶谈心每月次数上限。
  static const int spouseChatDailyLimit = 2;

  /// 立嗣提示的年龄门槛。
  static const int elderAge = 55;

  /// 濒死提示的健康门槛。
  static const int dyingHealth = 20;

  /// 谱系记录环形上限（防存档线性膨胀）。
  static const int generationRecordCap = 20;
  // ==================== M4c-2 AI Prompt 预算 ====================
  /// AI 叙事 prompt 单次最多注入的事件数（全量 72 → 预算 12，token 成本约降 83%）。
  static const int kAiPromptEventBudget = 12;
  /// 强相关事件不足时，兜底注入的最少事件数（保证 AI 有事件可参考）。
  static const int kAiPromptEventFloor = 3;
  /// 硬相关评分：地点命中。
  static const int kAiScoreLocation = 3;
  /// 硬相关评分：季节命中。
  static const int kAiScoreSeason = 2;
  /// 硬相关评分：身份命中。
  static const int kAiScoreIdentity = 2;
  /// 数值条件匹配评分（minGold/minEnergy/maxEnergy/minAge 等命中一次）。
  static const int kAiScoreNumeric = 1;
  // ==================== Batch 10-82 AI Prompt 人数预算 ====================
  /// AI 叙事 prompt 单次最多注入的在场 NPC 数。
  ///
  /// 实测临冬城有 8 位 NPC 同场（艾德/凯特琳/罗柏/珊莎/艾莉亚/布兰/瑞肯/琼恩），
  /// 每位带「关系+心情+性格+目标+技能+信仰+可委托任务清单」，全量注入单行可达
  /// 700+ 字、token 占比过高。取前 5 位（覆盖全部既有测试依赖的艾德/凯特琳/罗柏
  /// 并留 2 位余量），超出部分附「另有 N 位在场」尾注。
  static const int kAiPromptOnSiteNpcBudget = 5;
  /// AI 叙事 prompt 单次最多列出的「NPC 间关系网络」边数。
  ///
  /// `_npcNetworkDesc` 取玩家关系 NPC 前 3 个并做**两两组合**（i<j），
  /// 最多 C(3,2)=3 条边，且双方无直接关系时回落 0（中立）。
  /// 取预算 3 = 当前实际上限，设此常量是为了给未来放宽「前 N 个 NPC」
  /// 留出显式上限，避免组合数 O(N²) 膨胀挤占预算。
  static const int kAiPromptNpcNetworkBudget = 3;
  // ==================== Batch 10-83 玩家关系段人数预算 ====================
  /// AI 叙事 prompt 单次最多展开的玩家→NPC 关系条数。
  ///
  /// 【为什么需要预算】`player.relations` 是长会话里唯一**无上限累积**的 map：
  /// 与 NPC 交互、任务完成、选项 effects 里的 `relations.<npcId>` 都会写入键，
  /// 全库 38 个 NPC 意味着最坏情况累积 38 键。实测单条关系行形如
  /// 「艾德·史塔克（贵族·史塔克家族·临冬城，秘密：琼恩·雪诺的真实身份）: 85」
  /// 约 37 字符，38 条全量注入 ≈ 1443 字符（中文约 1 字 1 token），
  /// 是整个 prompt 里唯一随回合数无界增长的大段。
  ///
  /// 【为什么取 8】按 |关系值| 降序截取，绝对值越大的人物越可能进入本回合叙事；
  /// 8 位覆盖了既有测试依赖的最大关系数（batch10_73 的 3 条）并留出余量，
  /// 也与在场 NPC 预算（5）同量级——在场的必然已展开，在场外的多为远亲。
  /// 最坏情况 38 → 8 可省约 79%。
  static const int kAiPromptRelationBudget = 8;
  // ==================== Batch 10-84 硬编码 take() 收口 ====================
  /// 「本月世界局势」注入的事件条数（相关度排序后的 top-N）。
  ///
  /// 复用 10-33 事件预算筛选器的相关度排序结果，取前 N 条作为本月大事。
  /// 现状 2 = 取前 2；设此常量是为了让「几件大事算本月局势」成为可调数值。
  static const int kAiPromptWorldNewsCount = 2;
  /// 「家族成员」段最多列出的同族在世 NPC 数。
  ///
  /// 史塔克家族实测有 8 位在世 NPC；取前 6 位覆盖既有测试依赖的
  /// 艾德/罗柏并留余量。现状 6 = 当前上限。
  static const int kAiPromptFamilyMemberCount = 6;
  /// 在场 NPC 行的「性格」最多注入几条。
  ///
  /// 全库 NPC personality 平均 2.9 条；取前 2 条覆盖既有测试断言
  /// 「性格：正直、严肃」（batch10_65/66 明确断言第三条「忠诚」不出现）。
  static const int kAiPromptNpcTraitCount = 2;
  /// 在场 NPC 行的「目标」最多注入几条。
  ///
  /// 全库 NPC goals 平均 0.9 条；取前 2 条覆盖既有测试断言
  /// 「目标：维护荣誉、保护家族」（艾德恰好 2 条）。
  static const int kAiPromptNpcGoalCount = 2;
  /// 在场 NPC 行的「技能」最多注入几项（其余给「另有 N 项」尾注）。
  ///
  /// 既有测试断言「另有 1 项」（艾德 3 键 skills，取前 2），故预算不能低于 2。
  static const int kAiPromptNpcSkillCount = 2;
  /// 「邻近地点与路途风险」最多逐条展开几个相邻地点（其余给「另有 N 处未列」）。
  ///
  /// 全库 70 个地点平均 4~5 条 connectedTo；取前 4 个覆盖既有测试的临冬城场景。
  static const int kAiPromptNearbyLocationCount = 4;
  /// 「与你相关的可用事件」最多列出几条。
  ///
  /// 从已按预算筛选过的事件里再筛家族/身份命中，取前 3 条。
  /// 现状 3 = 当前上限。
  static const int kAiPromptRelevantEventCount = 3;
  /// 「局势关联 NPC 立场」对每个世界事件最多取几个玩家关系 NPC 推导立场。
  ///
  /// 现实 2 个世界事件 × 3 个 NPC = 6 行，是「局势关联 NPC 立场」段的全部体量。
  /// 现状 3 = 当前上限。
  static const int kAiPromptStanceNpcCount = 3;
  /// 家族「秘密」最多注入几条（familyDesc 内）。
  ///
  /// 既有测试断言「秘密：琼恩·雪诺的真实身份、史塔克家族与龙的关系」（史塔克 2 条全出），
  /// 故预算不能低于 2。全库家族 secrets 平均 0.4 条、最多 2 条。
  static const int kAiPromptFamilySecretCount = 2;
  // ==================== Batch 10-85 在场 NPC 任务模板预算 ====================
  /// 「在场 NPC」行内单个人物最多展开几个任务模板（超出给尾注）。
  ///
  /// 【为什么需要预算】`_onSiteNpcDesc` 对每位在场 NPC 都输出
  /// 「，可委托：「标题」（类型，难度 N，期限 M 月）」全量清单。取证实测：
  /// 单模板 ≈ 29 字符，单 NPC 最多 3 个模板（艾德/罗柏/珊莎/艾莉亚等 10 人），
  /// 10-82 预算内 5 位共 14 个模板 ≈ 406 字符——这是「在场 NPC」段
  /// （实测 635 字符、占单次请求 12% 的最大头）的主要来源。
  ///
  /// 【为什么取 2】既有测试 `batch10_22_ai_prompt_inject_test` 断言艾德
  /// （`npc_nev`，模板数最多的 10 人之一）同时出现「难度 3」「期限 6 月」
  /// 与「难度 2」两条模板信息，故预算不能低于 2。3 → 2 省 4 个模板
  /// ≈ 116 字符（在场 NPC 段降约 18%）；余下模板用尾注告知 AI「另有 N 个可委托」
  /// 而不逐条展开，保留「这位人物手上还有活」的语义。
  static const int kAiPromptOnSiteNpcTaskBudget = 2;


  // ==================== Batch 10-87 背包段预算 ====================
  /// 「背包」段最多逐条列出几种物品（超出给「另有 N 种物品未列」尾注）。
  ///
  /// 【为什么需要预算】`_buildPrompt` 的背包段原先直接
  /// `player.inventory.join('、')`，输出的是**裸英文物品 ID 且逐件重复**：
  /// 持有 12 个黑面包就写 12 遍 `item_bread`（≈120 字符）。而背包**没有上限**——
  /// `mixin_life.addItem` 注释明写「背包无上限，恒成功」，且
  /// `event_service.applyEffects` 的 `inventory.<id>` 分支**不校验 id 是否存在**，
  /// AI 选项可写入任意未知 id，因此该段是随回合数无界增长的一段。
  ///
  /// 【10-91 更新】写侧已补 `itemById` 守卫（两条 applyEffects 通道），
  /// 「AI 每回合写入新未知 id」这条无界通道已关闭；但本段长度上界
  /// 仍由物品种类数决定（全库 33 种 > 预算 8），故预算保留不变。
  ///
  /// 【为什么取 8】现有内容管道共 33 种物品，真实玩家常驻 3~8 种；
  /// 取 8 覆盖绝大多数存档，其余用尾注告知 AI「车上还有别的货」，
  /// 而不逐条罗列（保留「持有物不止这些」的语义）。
  static const int kAiPromptInventoryEntryCount = 8;


  // ==================== Batch 10-88 状态段预算 ====================
  /// 「状态」段最多列出几个为 true 的 flags 键（超出给「另有 N 项未列」尾注）。
  ///
  /// 【为什么需要预算】状态段原先把 `player.flags` 里所有 true 的键
  /// 无上限拼成一行。两条无界写入通道：
  /// ① `event_service.applyEffects` 的 `flags.<名>` 分支**不校验键名**，
  ///    AI 选项每回合都可能新增一个键；
  /// ② `mixin_generation.advanceGeneration` 每次换代写
  ///    `house.childDead.<继承人名>`，只增不删。
  /// 另有 `equipped.<物品 id>` 最多 33 键（物品种类硬上限）。
  /// 真实存档常见 2~6 项，但理论无上界，故设显式预算。
  ///
  /// 【为什么取 8】与背包段预算同量级；按 map 插入序截断
  /// （Dart map 字面量是 LinkedHashMap，顺序确定），保留最早获得的状态。
  static const int kAiPromptFlagBudget = 8;
  // ==================== Batch 10-90 好感度护栏 ====================
  /// 好感度绝对值上限（关系效果的钳制边界）。
  ///
  /// 【为什么需要】好感度有**两条**写入通道，历史上只有一条带护栏：
  /// ① `event_service.applyEffects` 的 `relations.<id>` 分支硬编码了
  ///    `.clamp(-100, 100)`；
  /// ② `GameStateProvider.applyEffects`（**AI 选项走这条**）却是裸加法，
  ///    AI 输出 `relations.npc_tyrion: 9999` 就让关系值无上界累积。
  /// 越界的连带后果有三处：
  ///  - `mixin_npc_interact.npcRelationLabel` 的六档阈值（±20/40/60/80）
  ///    在越界后完全失效（>80 一律「挚友」）；
  ///  - `npcFavor` 的示好成本公式 `(5 + (100 - rel) ~/ 20).clamp(3, 12)`
  ///    在 rel > 100 时算出负数再被 clamp，成本恒为 3 金；
  ///  - `ai_service` 的敌友判定阈值 ±20 同样失去区分度。
  ///
  /// 【为什么取 100】与 `npcRelationLabel` 的「挚友 / 敌对」两档饱和值
  /// 天然对齐（越界无新增语义）；同时是 `ai_service` 敌友阈值 ±20 的
  /// 5 倍裕度，不会让 AI 侧的立场推导提前饱和。
  static const int kRelationClamp = 100;
  // ==================== Batch 10-91/92 效果键白名单 ====================
  /// 玩家技能键白名单（`skills.<key>` 的合法键集）。
  ///
  /// 【为什么需要】`skills.`/`attributes.` 分支历史上**不校验键名**，
  /// AI 选项可写入任意字符串（如 `skills.leadership` 这类 NPC 侧键位，
  /// 或 `skills.剑术` 这类中文翻译），后果与 10-89 的幽灵关系键同构：
  ///  1. `labels.skillLabel` 的未知键兜底是 `_ => key`（原样返回），
  ///     于是**英文/中文原始键名直接泄漏进技能面板 UI**；
  ///  2. `mixin_play.train` 的「你从未学过 X」判定以 `skills.containsKey`
  ///     为准，幽灵键会让 AI「教会」玩家一个本不存在的技能，
  ///     而面板上它是一个没有中文标签的裸键；
  ///  3. 技能是 10-79/10-81 注入 prompt 的键，无标签键在 prompt 里也无意义。
  ///
  /// 【键集来源】`labels.skillLabel` 的 13 个分支——它同时是 UI 标签表与
  /// 契约表，新增技能必须同步该表，故以此为单一真相。
  ///
  /// 【为什么是 13 而非只留玩家侧 5 键】玩家侧 `Player.defaultPlayer`
  /// 只初始化 sword/archery/riding/speech/alchemy 五键，但内容事件里
  /// `alchemy`/`speech`/`stealth`/`riding`/`archery` 都在写入，且
  /// `mixin_npc_interact` 的学者分支会直接把 NPC 的 skills 键
  /// （leadership/politics/sword）灌进玩家技能表。取全集 13 键，
  /// 这三条真实写入通道全部合法，不误伤既有内容。
  static const Set<String> kPlayerSkillKeys = <String>{
    'sword', // 剑术
    'leadership', // 统率
    'politics', // 权谋
    'archery', // 弓术
    'scholarship', // 学问
    'stealth', // 潜行
    'fencing', // 刺击
    'survival', // 野外求生
    'craft', // 手工技艺
    'magic', // 魔法
    'riding', // 骑术（玩家侧）
    'speech', // 口才（玩家侧）
    'alchemy', // 炼金（玩家侧）
  };
  /// 玩家属性键白名单（`attributes.<key>` 的合法键集）。
  ///
  /// 来源同为 `labels.attributeLabel` 的 6 个分支（单一真相）。
  /// 未知属性键同样会以 `_ => key` 兜底泄漏原文进属性面板，
  /// 且无任何内容事件/指令会写入清单外的键。
  static const Set<String> kPlayerAttributeKeys = <String>{
    'strength', // 力量
    'agility', // 敏捷
    'intelligence', // 智识
    'charisma', // 魅力
    'willpower', // 意志
    'perception', // 感知
  };
  // ==================== Batch 10-97 效果键分层白名单（flags.） ====================
  /// 玩家状态标记的**静态**合法键集（`flags.<key>` 中不含点号的部分）。
  ///
  /// 【为什么需要】`flags.` 分支历史上**完全不校验键名**，是
  /// `inventory.`/`skills.`/`attributes.`/`relations.` 四类键全部治理完之后
  /// **唯一未设防的一类**。幽灵标记键的后果与 10-92 的幽灵技能键同构：
  ///  1. `player_panel_screen` 的「状态标记」区块遍历 `flags.entries`
  ///     直接把键名显示给玩家，AI 自造的键会以裸英文/中文键名出现在面板上；
  ///  2. `ai_service._flagDesc`（10-88）只按插入序取前 8 项输出到 prompt，
  ///     幽灵键会**白占预算位**并把真实状态挤出窗口；
  ///  3. 存档（`Player.toJson`）逐回合序列化整个 `flags` map，
  ///     幽灵键只增不减 → 存档体积与状态段 token 同步无界增长。
  ///
  /// 【键集来源】两条真实写入通道的全量**静态**键 = 26 个，拆两处：
  ///  - 内容事件字面量键 17 个（注意 `event_data` 的 `flags.` 键共 21 个，
  ///    其中 4 个是 `equipped.<物品 id>` 动态键，已归入下方前缀集）；
  ///  - 引擎系统键 9 个：`isAlive` / `isInjured` / `negotiated` / `isMarried` /
  ///    `divorceYear` / `widowed` / `isExiled` / `generation` / `inherited`。
  /// 取全集而非仅事件键：系统键一旦被守卫拒收，`mixin_life` 的死亡判定与
  /// `mixin_generation` 的世代数会**静默失真**——比幽灵键泄漏更严重；
  /// 且既有测试已在走这条路（`batch3_event_service_test` 写 `flags.isMarried`、
  /// `batch9_ai_deep_test` 写 `flags.isAlive: 0`）。
  static const Set<String> kPlayerFlagKeys = <String>{
    // —— 内容事件 17 键（event_data.dart 的字面量键）——
    'honor_pledge', // 荣誉誓约
    'hasShelter', // 寻得庇护
    'hasDirewolf', // 驯服恐狼
    'hasBlessing', // 神明庇佑
    'hasVision', // 幻视
    'hasCandleVision', // 烛中幻象
    'hasCometRecord', // 彗星异象
    'hasWarned', // 已示警
    'hasFrozenVision', // 冰境幻视
    'guild_ally', // 商会盟友
    'guild_secret', // 商会秘闻
    'guild_enemy', // 商会敌对
    'sworn_brother', // 义兄弟
    'watch_friend', // 守夜人友人
    'market_hero', // 集市传奇
    'market_intel', // 集市情报
    'lord_favor', // 领主赏识
    // —— 引擎系统键 9 个（mixin 层）——
    'isAlive', // 存活（死亡判定唯一真相）
    'isInjured', // 负伤（GameLifeMixin.isInjured 唯一真相）
    'negotiated', // 今日已议价（议价冷却）
    'isMarried', // 已婚（家族树第 73 行读）
    'divorceYear', // 离婚当年（次年清除）
    'widowed', // 丧偶
    'isExiled', // 流放中（传承时重置）
    'generation', // 已传承（currentGeneration 唯一真相）
    'inherited', // 已继承家主之位
  };

  /// 玩家状态标记的**受限动态前缀**集（`flags.<前缀><动态部分>`）。
  ///
  /// 【为什么纯白名单不可行】`flags.` 与其他四类键的本质差异在于
  /// **存在 5 个由引擎在运行时拼出的合法动态键前缀**——它们的键名
  /// 含 NPC id / 物品 id / 中文人名，无法静态枚举（详见各条注释）。
  /// 纯白名单会把这些内容数据全部拒收（每代传承丢一个 `house.childDead.*`，
  /// 家谱筛选立刻失真）。
  ///
  /// 【为什么不做「自由键开关」】HANDOVER 遗留候选里提过的兜底方案是把未知
  /// 键直接放行，那等于放弃本次治理。分层是唯一既治幽灵键又不破内容
  /// 数据的形态：静态 26 键 + 5 前缀，其余拒收。
  static const List<String> kPlayerFlagPrefixes = <String>[
    'equipped.', // 装备槽位：mixin_life.equip/unequip 穿脱时写（33 个物品 id）
    'house.childDead.', // 已故子女：mixin_generation:146 每代传承写入继承人名
    'npc_task.', // 已接任务：mixin_npc_interact:250 接任务时写「npcId.任务标题」
    'npc_task_done.', // 已完成任务：mixin_npc_interact:267 完成时写
    'npc_story.', // 已触发人物故事：mixin_npc_interact:203 写「npcId.关系档位」
  ];

  // **刻意不收的前缀**：`house.childExiled.`（`mixin_generation:58` 读取）。
  // 该前缀全库**只有读取、没有写入**，属预留语义键。不开前缀反而是对的：
  // 一旦放行，AI 写 `flags.house.childExiled.罗柏` 就会让家谱第 58 行把
  // 罗柏判为「已逐出」、从继承人候选中剔除——一个从未接线的键不该
  // 拥有改变家谱的能力。
  /// `flags.<key>` 键名合法性判定（10-97 分层白名单的单一真相）。
  ///
  /// 合法 = 静态白名单 [kPlayerFlagKeys] 命中，或以 [kPlayerFlagPrefixes]
  /// 任一前缀开头。两条 `applyEffects` 通道（事件/AI）共用本方法，
  /// 与 `kPlayerSkillKeys`/`kPlayerAttributeKeys` 的 `contains` 判定同风格。
  static bool isPlayerFlagKeyValid(String flagName) {
    if (kPlayerFlagKeys.contains(flagName)) return true;
    for (final prefix in kPlayerFlagPrefixes) {
      // 要求前缀后有**非空**后缀：`flags.equipped.`（没有物品 id）
      // 不是合法键——它会写出一条 equip/unequip 永远命中不了、只会在
      // 玩家面板「状态标记」区块占一行、并在存档里常驻的空槽位。
      // （此处若只判 `startsWith`，裸前缀会被误判为合法。）
      if (flagName.length > prefix.length && flagName.startsWith(prefix)) {
        return true;
      }
    }
    return false;
  }
  // ==================== 便捷派生 ====================

  /// 夫妻感情等级标签。
  static String affectionLabel(int affection) {
    if (affection >= spouseDevotedAffection) return '恩爱';
    if (affection >= spouseHarmoniousAffection) return '和睦';
    return '疏离';
  }
}
