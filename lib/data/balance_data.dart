/// 数值配置集中（Batch 10-30 · M4a · 内容管道与数值配置）。
///
/// 目标：调平衡不再全库 grep。原散落在 mixin 里的魔法数字统一收口到这里，
/// 各 mixin 的 `static const` 保留原名并转发到本文件（const 引用 const 是编译期常量），
/// 因此**既有测试与调用点零改动**。
///
/// 分组：
/// - 初始数值：开局金币/声望/年龄/生存三维
/// - 生存消耗：饱食衰减/饥饿阈值/恢复量/睡眠与伤势概率
/// - 每日上限：日常活动次数限制
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

  /// 饱食初始值（0 = 最饿）。
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

  /// 冬季（winter/longwinter）额外饱食消耗。
  static const int winterHungerExtra = 5;

  // ==================== 每日上限 ====================

  /// 每日活动次数上限（防数值刷子，参考 docs/08 玩法限制）。
  static const Map<String, int> dailyLimits = {
    'train': 3,
    'hunt': 2,
    'work': 2,
    'trade': 2,
    'rest': 99,
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

  /// 狩猎失败的受伤概率。
  static const double huntInjuryChance = 0.3;

  /// 狩猎受伤的健康损失。
  static const int huntInjuryHealthCost = 5;

  /// 狩猎成功的饱食补充。
  static const int huntHungerGain = 15;

  /// 旅店住宿花费。
  static const int restInnCost = 2;

  // ==================== 婚姻与世代 ====================

  /// 夫妻感情「恩爱」门槛。
  static const int spouseDevotedAffection = 70;

  /// 夫妻感情「和睦」门槛（低于此为疏离）。
  static const int spouseHarmoniousAffection = 30;

  /// 离婚补偿金（防无限再婚刷声望）。
  static const int divorceCost = 30;

  /// 配偶互动每日次数上限。
  static const int spouseDailyLimit = 1;

  /// 配偶谈心每日次数上限。
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
  /// 全库 69 个地点平均 4~5 条 connectedTo；取前 4 个覆盖既有测试的临冬城场景。
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
  // ==================== 便捷派生 ====================

  /// 夫妻感情等级标签。
  static String affectionLabel(int affection) {
    if (affection >= spouseDevotedAffection) return '恩爱';
    if (affection >= spouseHarmoniousAffection) return '和睦';
    return '疏离';
  }
}
