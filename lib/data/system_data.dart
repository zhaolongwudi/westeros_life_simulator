/// 系统数据：74 个游戏世界规则系统。
///
/// 数据来源：docs/05_系统百科.md
library;

import 'package:westeros_life_simulator/models/system.dart';

/// 所有系统数据（按分类分组）。
const List<GameSystem> allSystems = [
  // ==================== 封建体系（1） ====================
  GameSystem(
    id: 'system_feudal',
    name: '封建体系',
    category: '封建',
    description: '维斯特洛的封建等级制度。',
    rules: const ['领主效忠国王', '国王授予领地', '领主提供军队'],
    features: const ['等级制度', '效忠关系', '领地授予'],
  ),

  // ==================== 家族体系（1） ====================
  GameSystem(
    id: 'system_family',
    name: '家族体系',
    category: '家族',
    description: '维斯特洛的家族制度。',
    rules: const ['家族继承', '家族联姻', '家族秘密'],
    features: const ['家族继承', '家族联姻', '家族秘密'],
  ),

  // ==================== 教会体系（1） ====================
  GameSystem(
    id: 'system_church',
    name: '教会体系',
    category: '教会',
    description: '七神教会的组织体系。',
    rules: const ['总主教领导', '红袍祭司', '教会审判'],
    features: const ['总主教', '红袍祭司', '教会审判'],
  ),

  // ==================== 学城体系（1） ====================
  GameSystem(
    id: 'system_citadel',
    name: '学城体系',
    category: '学城',
    description: '学城的大学士体系。',
    rules: const ['大学士领导', '学士网络', '知识传承'],
    features: const ['大学士', '学士网络', '知识传承'],
    // S4-1（P1-09）：学城挂载 → 每月领学士津贴 +5 金，抄录典籍消耗 3 精力。
    // 选+5 而非更高：开局金币 100（player.dart:129），这是一笔稳定但不
    // 足以「不干活」的被动收入；学城线的正反馈本来应该来自委托任务，
    // 那属新增玩法维度，不在本批次内。
    monthlyEffects: const {'gold': 5, 'energy': -3},
  ),

  // ==================== 守夜人体系（1） ====================
  GameSystem(
    id: 'system_nightswatch',
    name: '守夜人体系',
    category: '守夜人',
    description: '长城守夜人的组织体系。',
    rules: const ['总司令领导', '守夜人誓言', '长城防御'],
    features: const ['总司令', '守夜人誓言', '长城防御'],
    // S4-1（P1-09）：守夜人誓约「不领薪酬」，故不给金币，只给体力代价
    // -10 精力。量级依据：`sleptWellChance 0.7` ×（`sleepEnergyBase 15` +
    // 均值 `sleepEnergyVariance 7.5`）≈ 每回合净回 15 精力，扣 10 后仍净
    // +5，不会把守夜人路线锁死。
    monthlyEffects: const {'energy': -10},
  ),

  // ==================== 雇佣兵体系（1） ====================
  GameSystem(
    id: 'system_mercenary',
    name: '雇佣兵体系',
    category: '雇佣兵',
    description: '雇佣兵的组织体系。',
    rules: const ['雇佣兵合同', '雇佣兵纪律', '雇佣兵报酬'],
    features: const ['雇佣兵合同', '雇佣兵纪律', '雇佣兵报酬'],
  ),

  // ==================== 贸易体系（1） ====================
  GameSystem(
    id: 'system_trade',
    name: '贸易体系',
    category: '贸易',
    description: '维斯特洛的贸易体系。',
    rules: const ['贸易路线', '贸易关税', '贸易保护'],
    features: const ['贸易路线', '贸易关税', '贸易保护'],
  ),

  // ==================== 宗教体系（1） ====================
  GameSystem(
    id: 'system_religion',
    name: '宗教体系',
    category: '宗教',
    description: '维斯特洛的宗教体系。',
    rules: const ['七神信仰', '旧神信仰', '异端审判'],
    features: const ['七神信仰', '旧神信仰', '异端审判'],
  ),

  // ==================== 魔法体系（1） ====================
  GameSystem(
    id: 'system_magic',
    name: '魔法体系',
    category: '魔法',
    description: '维斯特洛的魔法体系。',
    rules: const ['魔法稀有', '魔法代价', '魔法传承'],
    features: const ['魔法稀有', '魔法代价', '魔法传承'],
  ),

  // ==================== 绿先知/易形者/血魔法/预言/狼梦/龙梦（6） ====================
  GameSystem(
    id: 'system_green_seer',
    name: '绿先知系统',
    category: '魔法',
    description: '绿先知的预言能力。',
    rules: const ['绿先知预言', '绿先知传承', '绿先知代价'],
    features: const ['绿先知预言', '绿先知传承', '绿先知代价'],
  ),
  GameSystem(
    id: 'system_skinchanger',
    name: '易形者系统',
    category: '魔法',
    description: '易形者的变形能力。',
    rules: const ['易形者变形', '易形者传承', '易形者代价'],
    features: const ['易形者变形', '易形者传承', '易形者代价'],
  ),
  GameSystem(
    id: 'system_blood_magic',
    name: '血魔法系统',
    category: '魔法',
    description: '血魔法的诅咒能力。',
    rules: const ['血魔法诅咒', '血魔法代价', '血魔法传承'],
    features: const ['血魔法诅咒', '血魔法代价', '血魔法传承'],
  ),
  GameSystem(
    id: 'system_prophecy',
    name: '预言系统',
    category: '魔法',
    description: '预言的应验能力。',
    rules: const ['预言应验', '预言代价', '预言传承'],
    features: const ['预言应验', '预言代价', '预言传承'],
  ),
  GameSystem(
    id: 'system_wolf_dream',
    name: '狼梦系统',
    category: '魔法',
    description: '狼梦的梦境能力。',
    rules: const ['狼梦梦境', '狼梦代价', '狼梦传承'],
    features: const ['狼梦梦境', '狼梦代价', '狼梦传承'],
  ),
  GameSystem(
    id: 'system_dragon_dream',
    name: '龙梦系统',
    category: '魔法',
    description: '龙梦的梦境能力。',
    rules: const ['龙梦梦境', '龙梦代价', '龙梦传承'],
    features: const ['龙梦梦境', '龙梦代价', '龙梦传承'],
  ),

  // ==================== 战争/城堡/军队/审判/比武（5） ====================
  GameSystem(
    id: 'system_war',
    name: '战争系统',
    category: '战争',
    description: '维斯特洛的战争体系。',
    rules: const ['战争规则', '战争代价', '战争传承'],
    features: const ['战争规则', '战争代价', '战争传承'],
  ),
  GameSystem(
    id: 'system_siege',
    name: '城堡攻防系统',
    category: '战争',
    description: '城堡攻防的战争体系。',
    rules: const ['城堡防御', '城堡进攻', '城堡代价'],
    features: const ['城堡防御', '城堡进攻', '城堡代价'],
  ),
  GameSystem(
    id: 'system_army',
    name: '军队系统',
    category: '战争',
    description: '军队的组织体系。',
    rules: const ['军队编制', '军队纪律', '军队报酬'],
    features: const ['军队编制', '军队纪律', '军队报酬'],
  ),
  GameSystem(
    id: 'system_trial',
    name: '审判系统',
    category: '战争',
    description: '审判的战争体系。',
    rules: const ['审判规则', '审判代价', '审判传承'],
    features: const ['审判规则', '审判代价', '审判传承'],
  ),
  GameSystem(
    id: 'system_trial_by_combat',
    name: '比武审判系统',
    category: '战争',
    description: '比武审判的战争体系。',
    rules: const ['比武规则', '比武代价', '比武传承'],
    features: const ['比武规则', '比武代价', '比武传承'],
  ),

  // ==================== 婚姻/继承/女性地位（3） ====================
  GameSystem(
    id: 'system_marriage',
    name: '婚姻系统',
    category: '婚姻',
    description: '维斯特洛的婚姻体系。',
    rules: const ['婚姻规则', '婚姻代价', '婚姻传承'],
    features: const ['婚姻规则', '婚姻代价', '婚姻传承'],
  ),
  GameSystem(
    id: 'system_succession',
    name: '继承系统',
    category: '继承',
    description: '维斯特洛的继承体系。',
    rules: const ['继承规则', '继承代价', '继承传承'],
    features: const ['继承规则', '继承代价', '继承传承'],
  ),
  GameSystem(
    id: 'system_women',
    name: '女性地位系统',
    category: '婚姻',
    description: '维斯特洛的女性地位体系。',
    rules: const ['女性地位', '女性代价', '女性传承'],
    features: const ['女性地位', '女性代价', '女性传承'],
  ),

  // ==================== 经济/货币/教育/语言/节日/家庭/领地/城市（8） ====================
  GameSystem(
    id: 'system_economy',
    name: '经济系统',
    category: '经济',
    description: '维斯特洛的经济体系。',
    rules: const ['经济规则', '经济代价', '经济传承'],
    features: const ['经济规则', '经济代价', '经济传承'],
  ),
  GameSystem(
    id: 'system_currency',
    name: '货币系统',
    category: '经济',
    description: '维斯特洛的货币体系。',
    rules: const ['货币规则', '货币代价', '货币传承'],
    features: const ['货币规则', '货币代价', '货币传承'],
  ),
  GameSystem(
    id: 'system_education',
    name: '教育系统',
    category: '经济',
    description: '维斯特洛的教育体系。',
    rules: const ['教育规则', '教育代价', '教育传承'],
    features: const ['教育规则', '教育代价', '教育传承'],
  ),
  GameSystem(
    id: 'system_language',
    name: '语言系统',
    category: '经济',
    description: '维斯特洛的语言体系。',
    rules: const ['语言规则', '语言代价', '语言传承'],
    features: const ['语言规则', '语言代价', '语言传承'],
  ),
  GameSystem(
    id: 'system_festival',
    name: '节日系统',
    category: '经济',
    description: '维斯特洛的节日体系。',
    rules: const ['节日规则', '节日代价', '节日传承'],
    features: const ['节日规则', '节日代价', '节日传承'],
  ),
  GameSystem(
    id: 'system_family_life',
    name: '家庭系统',
    category: '经济',
    description: '维斯特洛的家庭体系。',
    rules: const ['家庭规则', '家庭代价', '家庭传承'],
    features: const ['家庭规则', '家庭代价', '家庭传承'],
  ),
  GameSystem(
    id: 'system_lands',
    name: '领地系统',
    category: '经济',
    description: '维斯特洛的领地体系。',
    rules: const ['领地规则', '领地代价', '领地传承'],
    features: const ['领地规则', '领地代价', '领地传承'],
  ),
  GameSystem(
    id: 'system_cities',
    name: '城市系统',
    category: '经济',
    description: '维斯特洛的城市体系。',
    rules: const ['城市规则', '城市代价', '城市传承'],
    features: const ['城市规则', '城市代价', '城市传承'],
  ),

  // ==================== 情报/旅行/冒险/神器/传奇武器/瓦雷利亚钢（6） ====================
  GameSystem(
    id: 'system_intelligence',
    name: '情报系统',
    category: '情报',
    description: '维斯特洛的情报体系。',
    rules: const ['情报规则', '情报代价', '情报传承'],
    features: const ['情报规则', '情报代价', '情报传承'],
  ),
  GameSystem(
    id: 'system_travel',
    name: '旅行系统',
    category: '情报',
    description: '维斯特洛的旅行体系。',
    rules: const ['旅行规则', '旅行代价', '旅行传承'],
    features: const ['旅行规则', '旅行代价', '旅行传承'],
  ),
  GameSystem(
    id: 'system_adventure',
    name: '冒险系统',
    category: '情报',
    description: '维斯特洛的冒险体系。',
    rules: const ['冒险规则', '冒险代价', '冒险传承'],
    features: const ['冒险规则', '冒险代价', '冒险传承'],
  ),
  GameSystem(
    id: 'system_relic',
    name: '神器系统',
    category: '情报',
    description: '维斯特洛的神器体系。',
    rules: const ['神器规则', '神器代价', '神器传承'],
    features: const ['神器规则', '神器代价', '神器传承'],
  ),
  GameSystem(
    id: 'system_legendary_weapon',
    name: '传奇武器系统',
    category: '情报',
    description: '维斯特洛的传奇武器体系。',
    rules: const ['武器规则', '武器代价', '武器传承'],
    features: const ['武器规则', '武器代价', '武器传承'],
  ),
  GameSystem(
    id: 'system_valyrian_steel',
    name: '瓦雷利亚钢系统',
    category: '情报',
    description: '维斯特洛的瓦雷利亚钢体系。',
    rules: const ['瓦钢规则', '瓦钢代价', '瓦钢传承'],
    features: const ['瓦钢规则', '瓦钢代价', '瓦钢传承'],
  ),

  // ==================== 龙/异鬼/无面者/红袍祭司/铁金库/无垢者/多斯拉克/野人/铁民（9） ====================
  GameSystem(
    id: 'system_dragon',
    name: '龙系统',
    category: '龙',
    description: '维斯特洛的龙体系。',
    rules: const ['龙规则', '龙代价', '龙传承'],
    features: const ['龙规则', '龙代价', '龙传承'],
  ),
  GameSystem(
    id: 'system_white_walker',
    name: '异鬼系统',
    category: '异鬼',
    description: '维斯特洛的异鬼体系。',
    rules: const ['异鬼规则', '异鬼代价', '异鬼传承'],
    features: const ['异鬼规则', '异鬼代价', '异鬼传承'],
  ),
  GameSystem(
    id: 'system_faceless',
    name: '无面者系统',
    category: '无面者',
    description: '维斯特洛的无面者体系。',
    rules: const ['无面者规则', '无面者代价', '无面者传承'],
    features: const ['无面者规则', '无面者代价', '无面者传承'],
  ),
  GameSystem(
    id: 'system_red_priest',
    name: '红袍祭司系统',
    category: '红袍祭司',
    description: '维斯特洛的红袍祭司体系。',
    rules: const ['红袍规则', '红袍代价', '红袍传承'],
    features: const ['红袍规则', '红袍代价', '红袍传承'],
  ),
  GameSystem(
    id: 'system_iron_bank',
    name: '铁金库系统',
    category: '铁金库',
    description: '维斯特洛的铁金库体系。',
    rules: const ['铁金库规则', '铁金库代价', '铁金库传承'],
    features: const ['铁金库规则', '铁金库代价', '铁金库传承'],
    // S4-1（P1-09）**刻意留空**：铁金库语汇是「借贷」，但取证结论是
    // 全库**不存在持久化债务状态**——`event_iron_bank_debt` /
    // `event_iron_bank_crisis` 的 `gold: -500` 只是「选择偿还」这个
    // **动作本身**的即时扣款，没有任何地方记录「玩家欠着 500 金」。
    // 而本系统的挂载条件是 `isAtType(city) || isAtType(market)`
    // （mixin_systems.dart:57），几乎全员命中。若在此挂 `gold: -N`，
    // 效果就是「每个进城的玩家每月凭空被扣钱，且永远还不清」——
    // 这是凭空加惩罚，比留空更糟。
    //
    // 解锁前置：需要先有债务本体（借贷命令 / `flags.debt_ironbank` /
    // 月度计息），属新增玩法维度，留 S4-2 之后的独立批次，不在本批次内硬塞。
    monthlyEffects: const {},
  ),
  GameSystem(
    id: 'system_dothraki',
    name: '无垢者系统',
    category: '无垢者',
    description: '维斯特洛的无垢者体系。',
    rules: const ['无垢者规则', '无垢者代价', '无垢者传承'],
    features: const ['无垢者规则', '无垢者代价', '无垢者传承'],
  ),
  GameSystem(
    id: 'system_dothraki_culture',
    name: '多斯拉克系统',
    category: '多斯拉克',
    description: '维斯特洛的多斯拉克体系。',
    rules: const ['多斯拉克规则', '多斯拉克代价', '多斯拉克传承'],
    features: const ['多斯拉克规则', '多斯拉克代价', '多斯拉克传承'],
  ),
  GameSystem(
    id: 'system_wildling',
    name: '野人系统',
    category: '野人',
    description: '维斯特洛的野人体系。',
    rules: const ['野人规则', '野人代价', '野人传承'],
    features: const ['野人规则', '野人代价', '野人传承'],
  ),
  GameSystem(
    id: 'system_ironborn',
    name: '铁民系统',
    category: '铁民',
    description: '维斯特洛的铁民体系。',
    rules: const ['铁民规则', '铁民代价', '铁民传承'],
    features: const ['铁民规则', '铁民代价', '铁民传承'],
  ),

  // ==================== 法律/身份/私生子/死亡/继承/多世代/历史记忆/世界史书（8） ====================
  GameSystem(
    id: 'system_law',
    name: '法律系统',
    category: '法律',
    description: '维斯特洛的法律体系。',
    rules: const ['法律规则', '法律代价', '法律传承'],
    features: const ['法律规则', '法律代价', '法律传承'],
  ),
  GameSystem(
    id: 'system_identity',
    name: '身份法律',
    category: '法律',
    description: '维斯特洛的身份法律体系。',
    rules: const ['身份规则', '身份代价', '身份传承'],
    features: const ['身份规则', '身份代价', '身份传承'],
  ),
  GameSystem(
    id: 'system_bastard',
    name: '私生子系统',
    category: '法律',
    description: '维斯特洛的私生子体系。',
    rules: const ['私生子规则', '私生子代价', '私生子传承'],
    features: const ['私生子规则', '私生子代价', '私生子传承'],
  ),
  GameSystem(
    id: 'system_death',
    name: '死亡系统',
    category: '死亡',
    description: '维斯特洛的死亡体系。',
    rules: const ['死亡规则', '死亡代价', '死亡传承'],
    features: const ['死亡规则', '死亡代价', '死亡传承'],
  ),
  // S3-4（P2-09 #5）：删除原 `system_succession_law`（name 也是「继承系统」，
  // rules/features/description 与 `system_succession` 仅差一个「法律」二字，
  // 而 74 个系统的 rules/features 全是「XX规则/XX代价/XX传承」占位、无任何逻辑消费，
  // 故这是零信息量的纯重复，删除对行为零影响。系统总数 74 → 73。
  GameSystem(
    id: 'system_multigeneration',
    name: '多世代模式',
    category: '继承',
    description: '维斯特洛的多世代模式体系。',
    rules: const ['多世代规则', '多世代代价', '多世代传承'],
    features: const ['多世代规则', '多世代代价', '多世代传承'],
  ),
  GameSystem(
    id: 'system_history_memory',
    name: '历史记忆',
    category: '继承',
    description: '维斯特洛的历史记忆体系。',
    rules: const ['历史规则', '历史代价', '历史传承'],
    features: const ['历史规则', '历史代价', '历史传承'],
  ),
  GameSystem(
    id: 'system_world_history',
    name: '世界史书',
    category: '继承',
    description: '维斯特洛的世界史书体系。',
    rules: const ['史书规则', '史书代价', '史书传承'],
    features: const ['史书规则', '史书代价', '史书传承'],
  ),

  // ==================== 现实性保护/魔法漏洞保护/神明保护/龙保护/异鬼保护/信息保护（6） ====================
  GameSystem(
    id: 'system_reality_protection',
    name: '现实性保护协议',
    category: '保护',
    description: '维斯特洛的现实性保护体系。',
    rules: const ['现实性规则', '现实性代价', '现实性传承'],
    features: const ['现实性规则', '现实性代价', '现实性传承'],
  ),
  GameSystem(
    id: 'system_magic_protection',
    name: '魔法体系漏洞保护',
    category: '保护',
    description: '维斯特洛的魔法体系漏洞保护体系。',
    rules: const ['魔法保护规则', '魔法保护代价', '魔法保护传承'],
    features: const ['魔法保护规则', '魔法保护代价', '魔法保护传承'],
  ),
  GameSystem(
    id: 'system_god_protection',
    name: '神明力量保护',
    category: '保护',
    description: '维斯特洛的神明力量保护体系。',
    rules: const ['神明保护规则', '神明保护代价', '神明保护传承'],
    features: const ['神明保护规则', '神明保护代价', '神明保护传承'],
  ),
  GameSystem(
    id: 'system_dragon_protection',
    name: '龙力量保护',
    category: '保护',
    description: '维斯特洛的龙力量保护体系。',
    rules: const ['龙保护规则', '龙保护代价', '龙保护传承'],
    features: const ['龙保护规则', '龙保护代价', '龙保护传承'],
  ),
  GameSystem(
    id: 'system_walker_protection',
    name: '异鬼力量保护',
    category: '保护',
    description: '维斯特洛的异鬼力量保护体系。',
    rules: const ['异鬼保护规则', '异鬼保护代价', '异鬼保护传承'],
    features: const ['异鬼保护规则', '异鬼保护代价', '异鬼保护传承'],
  ),
  GameSystem(
    id: 'system_information_protection',
    name: '世界信息保护',
    category: '保护',
    description: '维斯特洛的世界信息保护体系。',
    rules: const ['信息保护规则', '信息保护代价', '信息保护传承'],
    features: const ['信息保护规则', '信息保护代价', '信息保护传承'],
  ),

  // ==================== AI 自由协议/因果系统/机缘系统/冒险意义/过度热闹保护/主角光环保护/数值刷子保护/经济漏洞检测（8） ====================
  GameSystem(
    id: 'system_ai_freedom',
    name: 'AI 绝对自由协议',
    category: 'AI',
    description: '维斯特洛的 AI 绝对自由协议体系。',
    rules: const ['AI 自由规则', 'AI 自由代价', 'AI 自由传承'],
    features: const ['AI 自由规则', 'AI 自由代价', 'AI 自由传承'],
  ),
  GameSystem(
    id: 'system_causality',
    name: '世界因果系统',
    category: 'AI',
    description: '维斯特洛的世界因果体系。',
    rules: const ['因果规则', '因果代价', '因果传承'],
    features: const ['因果规则', '因果代价', '因果传承'],
  ),
  GameSystem(
    id: 'system_opportunity',
    name: '世界不是围绕玩家生成机缘',
    category: 'AI',
    description: '维斯特洛的世界不是围绕玩家生成机缘体系。',
    rules: const ['机缘规则', '机缘代价', '机缘传承'],
    features: const ['机缘规则', '机缘代价', '机缘传承'],
  ),
  GameSystem(
    id: 'system_adventure_meaning',
    name: '冒险的真正意义',
    category: 'AI',
    description: '维斯特洛的冒险的真正意义体系。',
    rules: const ['冒险意义规则', '冒险意义代价', '冒险意义传承'],
    features: const ['冒险意义规则', '冒险意义代价', '冒险意义传承'],
  ),
  GameSystem(
    id: 'system_overcrowding_protection',
    name: '防止世界过度热闹',
    category: 'AI',
    description: '维斯特洛的防止世界过度热闹体系。',
    rules: const ['过度热闹规则', '过度热闹代价', '过度热闹传承'],
    features: const ['过度热闹规则', '过度热闹代价', '过度热闹传承'],
  ),
  GameSystem(
    id: 'system_protagonist_protection',
    name: '防止主角光环',
    category: 'AI',
    description: '维斯特洛的防止主角光环体系。',
    rules: const ['主角光环规则', '主角光环代价', '主角光环传承'],
    features: const ['主角光环规则', '主角光环代价', '主角光环传承'],
  ),
  GameSystem(
    id: 'system_number_protection',
    name: '防止数值刷子',
    category: 'AI',
    description: '维斯特洛的防止数值刷子体系。',
    rules: const ['数值刷子规则', '数值刷子代价', '数值刷子传承'],
    features: const ['数值刷子规则', '数值刷子代价', '数值刷子传承'],
  ),
  GameSystem(
    id: 'system_economy_protection',
    name: '世界经济漏洞检测',
    category: 'AI',
    description: '维斯特洛的世界经济漏洞检测体系。',
    rules: const ['经济漏洞规则', '经济漏洞代价', '经济漏洞传承'],
    features: const ['经济漏洞规则', '经济漏洞代价', '经济漏洞传承'],
  ),

  // ==================== 规则更新/版本补丁/存档/恢复/AI 身份/终极原则（6） ====================
  GameSystem(
    id: 'system_rule_update',
    name: '世界规则更新',
    category: '规则',
    description: '维斯特洛的世界规则更新体系。',
    rules: const ['规则更新规则', '规则更新代价', '规则更新传承'],
    features: const ['规则更新规则', '规则更新代价', '规则更新传承'],
  ),
  GameSystem(
    id: 'system_version_patch',
    name: '版本补丁机制',
    category: '规则',
    description: '维斯特洛的版本补丁机制体系。',
    rules: const ['版本补丁规则', '版本补丁代价', '版本补丁传承'],
    features: const ['版本补丁规则', '版本补丁代价', '版本补丁传承'],
  ),
  GameSystem(
    id: 'system_save',
    name: '存档系统',
    category: '存档',
    description: '维斯特洛的存档体系。',
    rules: const ['存档规则', '存档代价', '存档传承'],
    features: const ['存档规则', '存档代价', '存档传承'],
  ),
  GameSystem(
    id: 'system_restore',
    name: '恢复系统',
    category: '存档',
    description: '维斯特洛的恢复体系。',
    rules: const ['恢复规则', '恢复代价', '恢复传承'],
    features: const ['恢复规则', '恢复代价', '恢复传承'],
  ),
  GameSystem(
    id: 'system_ai_identity',
    name: 'AI 运行身份',
    category: 'AI',
    description: '维斯特洛的 AI 运行身份体系。',
    rules: const ['AI 身份规则', 'AI 身份代价', 'AI 身份传承'],
    features: const ['AI 身份规则', 'AI 身份代价', 'AI 身份传承'],
  ),
  GameSystem(
    id: 'system_ultimate_principle',
    name: '终极原则',
    category: '规则',
    description: '维斯特洛的终极原则体系。',
    rules: const ['终极原则规则', '终极原则代价', '终极原则传承'],
    features: const ['终极原则规则', '终极原则代价', '终极原则传承'],
  ),
];

/// 按 ID 查找系统。
GameSystem? systemById(String id) {
  for (final s in allSystems) {
    if (s.id == id) return s;
  }
  return null;
}

/// 按分类筛选系统。
List<GameSystem> systemsByCategory(String category) {
  return allSystems.where((s) => s.category == category).toList();
}