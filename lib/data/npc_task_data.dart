/// NPC 任务模板数据（Batch 10-18）。
///
/// 为既有带 tasks 的 NPC 提供多步骤任务模板。
/// 玩家接任务后生成 [NpcTaskProgress] 实例存 Player.activeTasks。
library;

import '../models/npc_task.dart';

/// 全部任务模板。
const List<NpcTaskTemplate> allNpcTaskTemplates = [
  // ==================== 艾德·史塔克（临冬城） ====================
  NpcTaskTemplate(
    id: 'task_nev_escort',
    npcId: 'npc_nev',
    title: '护送北境信使至君临',
    type: NpcTaskType.escort,
    difficulty: 3,
    deadlineMonths: 6,
    steps: [
      NpcTaskStep(description: '在临冬城集结护卫，备好行装', turnsRequired: 1),
      NpcTaskStep(description: '穿越颈泽，避开沼泽匪徒', turnsRequired: 2),
      NpcTaskStep(description: '抵达君临，将信函交予劳勃国王', turnsRequired: 2),
    ],
    rewardGold: 60,
    rewardReputation: 6,
    rewardRelation: 8,
  ),
  NpcTaskTemplate(
    id: 'task_nev_wildling',
    npcId: 'npc_nev',
    title: '调查野人踪迹',
    type: NpcTaskType.investigate,
    difficulty: 2,
    deadlineMonths: 4,
    steps: [
      NpcTaskStep(description: '沿长城巡逻，寻找野人营地', turnsRequired: 1),
      NpcTaskStep(description: '审问一名被俘野人，套出情报', turnsRequired: 1),
    ],
    rewardGold: 30,
    rewardReputation: 4,
    rewardRelation: 5,
  ),

  // ==================== 提利昂·兰尼斯特（君临） ====================
  NpcTaskTemplate(
    id: 'task_tyrion_gossip',
    npcId: 'npc_tyrion',
    title: '收集君临流言',
    type: NpcTaskType.investigate,
    difficulty: 2,
    deadlineMonths: 3,
    steps: [
      NpcTaskStep(description: '在酒馆与市集打听朝堂秘闻', turnsRequired: 1),
      NpcTaskStep(description: '整理流言，挑出有价值的呈给提利昂', turnsRequired: 1),
    ],
    rewardGold: 40,
    rewardReputation: 3,
    rewardRelation: 6,
  ),
  NpcTaskTemplate(
    id: 'task_tyrion_ledger',
    npcId: 'npc_tyrion',
    title: '寻找失窃的账册',
    type: NpcTaskType.investigate,
    difficulty: 4,
    deadlineMonths: 5,
    steps: [
      NpcTaskStep(description: '追查账册失窃当晚的守卫', turnsRequired: 1),
      NpcTaskStep(description: '顺藤摸瓜找到销赃的商人', turnsRequired: 2),
      NpcTaskStep(description: '夺回账册，交还提利昂', turnsRequired: 1),
    ],
    rewardGold: 80,
    rewardReputation: 5,
    rewardRelation: 8,
  ),

  // ==================== 丹妮莉丝·坦格利安（厄索斯） ====================
  NpcTaskTemplate(
    id: 'task_dany_dragon',
    npcId: 'npc_daenerys',
    title: '寻找龙蛋的线索',
    type: NpcTaskType.hunt,
    difficulty: 4,
    deadlineMonths: 6,
    steps: [
      NpcTaskStep(description: '深入多斯拉克海，寻找古龙传说', turnsRequired: 2),
      NpcTaskStep(description: '从游牧部落手中购得龙蛋线索', turnsRequired: 1),
      NpcTaskStep(description: '护送线索与丹妮莉丝汇合', turnsRequired: 1),
    ],
    rewardGold: 70,
    rewardReputation: 8,
    rewardRelation: 10,
  ),
  NpcTaskTemplate(
    id: 'task_dany_support',
    npcId: 'npc_daenerys',
    title: '召集支持者',
    type: NpcTaskType.diplomacy,
    difficulty: 3,
    deadlineMonths: 5,
    steps: [
      NpcTaskStep(description: '游说自由城邦的商人资助', turnsRequired: 2),
      NpcTaskStep(description: '说服一支佣兵团效忠', turnsRequired: 1),
    ],
    rewardGold: 50,
    rewardReputation: 6,
    rewardRelation: 7,
  ),

  // ==================== 琼恩·雪诺（临冬城/长城） ====================
  NpcTaskTemplate(
    id: 'task_jon_watch',
    npcId: 'npc_jon_snow',
    title: '长城巡逻与补给',
    type: NpcTaskType.escort,
    difficulty: 2,
    deadlineMonths: 4,
    steps: [
      NpcTaskStep(description: '清点守夜人的冬储物资', turnsRequired: 1),
      NpcTaskStep(description: '沿长城巡逻，确认没有野人越墙', turnsRequired: 2),
    ],
    rewardGold: 35,
    rewardReputation: 4,
    rewardRelation: 6,
  ),
  NpcTaskTemplate(
    id: 'task_jon_ghost',
    npcId: 'npc_jon_snow',
    title: '寻找失踪的冰原狼',
    type: NpcTaskType.hunt,
    difficulty: 3,
    deadlineMonths: 4,
    steps: [
      NpcTaskStep(description: '循着雪地里的足迹深入狼林', turnsRequired: 2),
      NpcTaskStep(description: '从陷阱中救出白灵', turnsRequired: 1),
    ],
    rewardGold: 45,
    rewardReputation: 5,
    rewardRelation: 8,
  ),

  // ==================== 瑟曦·兰尼斯特（君临） ====================
  NpcTaskTemplate(
    id: 'task_cersei_spy',
    npcId: 'npc_cersei',
    title: '揪出宫中的叛徒',
    type: NpcTaskType.investigate,
    difficulty: 3,
    deadlineMonths: 5,
    steps: [
      NpcTaskStep(description: '盘问御林铁卫，找出泄密者', turnsRequired: 1),
      NpcTaskStep(description: '设局引蛇出洞', turnsRequired: 2),
    ],
    rewardGold: 55,
    rewardReputation: 4,
    rewardRelation: 6,
  ),
  NpcTaskTemplate(
    id: 'task_cersei_rumor',
    npcId: 'npc_cersei',
    title: '散布王后的流言',
    type: NpcTaskType.diplomacy,
    difficulty: 4,
    deadlineMonths: 6,
    steps: [
      NpcTaskStep(description: '在君临的酒馆间传播消息', turnsRequired: 1),
      NpcTaskStep(description: '买通说书人，让流言传遍红堡', turnsRequired: 2),
      NpcTaskStep(description: '观察朝臣反应，回报瑟曦', turnsRequired: 1),
    ],
    rewardGold: 70,
    rewardReputation: 3,
    rewardRelation: 7,
  ),

  // ==================== 奥莲娜·提利尔（高庭） ====================
  NpcTaskTemplate(
    id: 'task_olenna_wine',
    npcId: 'npc_olenna_tyrell',
    title: '运一批高庭红酒至君临',
    type: NpcTaskType.delivery,
    difficulty: 2,
    deadlineMonths: 3,
    steps: [
      NpcTaskStep(description: '在酒窖挑出上等红酒装车', turnsRequired: 1),
      NpcTaskStep(description: '沿玫瑰大道护送至君临', turnsRequired: 1),
    ],
    rewardGold: 40,
    rewardReputation: 4,
    rewardRelation: 5,
  ),
  NpcTaskTemplate(
    id: 'task_olenna_marriage',
    npcId: 'npc_olenna_tyrell',
    title: '为玛格丽物色夫婿',
    type: NpcTaskType.diplomacy,
    difficulty: 3,
    deadlineMonths: 6,
    steps: [
      NpcTaskStep(description: '收集各大家族适婚贵族的资料', turnsRequired: 1),
      NpcTaskStep(description: '游说其中一位登门提亲', turnsRequired: 2),
    ],
    rewardGold: 60,
    rewardReputation: 5,
    rewardRelation: 7,
  ),

  // ==================== 凯特琳·史塔克（临冬城） ====================
  NpcTaskTemplate(
    id: 'task_catelyn_escort',
    npcId: 'npc_catelyn',
    title: '护送信使前往奔流城',
    type: NpcTaskType.escort,
    difficulty: 3,
    deadlineMonths: 5,
    steps: [
      NpcTaskStep(description: '在临冬城备好马匹与干粮', turnsRequired: 1),
      NpcTaskStep(description: '沿国王大道南下，穿过颈泽', turnsRequired: 2),
      NpcTaskStep(description: '将家书交予奔流城的徒利家族', turnsRequired: 1),
    ],
    rewardGold: 55,
    rewardReputation: 5,
    rewardRelation: 7,
  ),
  NpcTaskTemplate(
    id: 'task_catelyn_children',
    npcId: 'npc_catelyn',
    title: '打探孩子们的安危',
    type: NpcTaskType.investigate,
    difficulty: 4,
    deadlineMonths: 6,
    steps: [
      NpcTaskStep(description: '在临冬城与集市间打听各家消息', turnsRequired: 1),
      NpcTaskStep(description: '循着线索南下，探明孩子们的处境', turnsRequired: 2),
      NpcTaskStep(description: '把打探到的消息回报凯特琳', turnsRequired: 1),
    ],
    rewardGold: 65,
    rewardReputation: 4,
    rewardRelation: 9,
  ),

  // ==================== 罗柏·史塔克（临冬城） ====================
  NpcTaskTemplate(
    id: 'task_robb_recruit',
    npcId: 'npc_robb',
    title: '召集北境封臣',
    type: NpcTaskType.diplomacy,
    difficulty: 3,
    deadlineMonths: 5,
    steps: [
      NpcTaskStep(description: '起草一封封臣召集令', turnsRequired: 1),
      NpcTaskStep(description: '分派渡鸦送往北境各堡', turnsRequired: 1),
      NpcTaskStep(description: '在临冬城接待响应召集的领主', turnsRequired: 1),
    ],
    rewardGold: 50,
    rewardReputation: 6,
    rewardRelation: 7,
  ),
  NpcTaskTemplate(
    id: 'task_robb_wolf',
    npcId: 'npc_robb',
    title: '追猎偷羊的狼群',
    type: NpcTaskType.hunt,
    difficulty: 2,
    deadlineMonths: 3,
    steps: [
      NpcTaskStep(description: '沿狼群留下的爪印深入林间', turnsRequired: 1),
      NpcTaskStep(description: '设下陷阱，猎杀头狼', turnsRequired: 1),
    ],
    rewardGold: 35,
    rewardReputation: 4,
    rewardRelation: 6,
  ),

  // ==================== 玛格丽·提利尔（高庭） ====================
  NpcTaskTemplate(
    id: 'task_margaery_supper',
    npcId: 'npc_margaery',
    title: '筹办高庭的晚宴',
    type: NpcTaskType.delivery,
    difficulty: 2,
    deadlineMonths: 3,
    steps: [
      NpcTaskStep(description: '向高庭周边的庄园采买新鲜蔬果', turnsRequired: 1),
      NpcTaskStep(description: '监督仆役布置宴会厅', turnsRequired: 1),
    ],
    rewardGold: 40,
    rewardReputation: 4,
    rewardRelation: 6,
  ),
  NpcTaskTemplate(
    id: 'task_margaery_support',
    npcId: 'npc_margaery',
    title: '争取王领贵族的支持',
    type: NpcTaskType.diplomacy,
    difficulty: 4,
    deadlineMonths: 6,
    steps: [
      NpcTaskStep(description: '整理各大家族在王领的态度', turnsRequired: 1),
      NpcTaskStep(description: '拜访两位摇摆不定的领主', turnsRequired: 2),
      NpcTaskStep(description: '将他们的承诺回报玛格丽', turnsRequired: 1),
    ],
    rewardGold: 75,
    rewardReputation: 6,
    rewardRelation: 8,
  ),

  // ==================== 泰温·兰尼斯特（凯岩城） ====================
  NpcTaskTemplate(
    id: 'task_tywin_escort',
    npcId: 'npc_tywin_lannister',
    title: '护送金库账册至君临',
    type: NpcTaskType.escort,
    difficulty: 3,
    deadlineMonths: 5,
    steps: [
      NpcTaskStep(description: '在凯岩城金库清点账册封存', turnsRequired: 1),
      NpcTaskStep(description: '走黄金大道，提防山匪', turnsRequired: 2),
      NpcTaskStep(description: '将账册交予御前财政大臣', turnsRequired: 1),
    ],
    rewardGold: 60,
    rewardReputation: 5,
    rewardRelation: 7,
  ),
  NpcTaskTemplate(
    id: 'task_tywin_house',
    npcId: 'npc_tywin_lannister',
    title: '调查西境领主的私通',
    type: NpcTaskType.investigate,
    difficulty: 4,
    deadlineMonths: 6,
    steps: [
      NpcTaskStep(description: '在各家封臣的领地搜集往来信件', turnsRequired: 2),
      NpcTaskStep(description: '从账目出入中找出私通的证据', turnsRequired: 2),
      NpcTaskStep(description: '把证据带回凯岩城呈给泰温', turnsRequired: 1),
    ],
    rewardGold: 90,
    rewardReputation: 5,
    rewardRelation: 8,
  ),

  // ==================== 珊莎·史塔克（临冬城） ====================
  NpcTaskTemplate(
    id: 'task_sansa_needlework',
    npcId: 'npc_sansa',
    title: '为珊莎采买上等丝绸',
    type: NpcTaskType.delivery,
    difficulty: 1,
    deadlineMonths: 3,
    steps: [
      NpcTaskStep(description: '到白港的织坊挑选上好丝绸', turnsRequired: 1),
      NpcTaskStep(description: '将丝绸带回临冬城交给珊莎', turnsRequired: 1),
    ],
    rewardGold: 30,
    rewardReputation: 3,
    rewardRelation: 6,
  ),
  NpcTaskTemplate(
    id: 'task_sansa_court',
    npcId: 'npc_sansa',
    title: '打探君临宫廷的礼数',
    type: NpcTaskType.investigate,
    difficulty: 3,
    deadlineMonths: 5,
    steps: [
      NpcTaskStep(description: '向到访临冬城的贵族打听宫中礼数', turnsRequired: 1),
      NpcTaskStep(description: '整理成礼数手册送给珊莎', turnsRequired: 1),
    ],
    rewardGold: 45,
    rewardReputation: 4,
    rewardRelation: 7,
  ),

  // ==================== 艾莉亚·史塔克（临冬城） ====================
  NpcTaskTemplate(
    id: 'task_arya_sword',
    npcId: 'npc_arya',
    title: '陪艾莉亚练剑',
    type: NpcTaskType.hunt,
    difficulty: 2,
    deadlineMonths: 3,
    steps: [
      NpcTaskStep(description: '在临冬城校场陪艾莉亚对练', turnsRequired: 1),
      NpcTaskStep(description: '教她几招实用剑术', turnsRequired: 1),
    ],
    rewardGold: 25,
    rewardReputation: 3,
    rewardRelation: 7,
  ),
  NpcTaskTemplate(
    id: 'task_arya_sneak',
    npcId: 'npc_arya',
    title: '掩护艾莉亚溜出城',
    type: NpcTaskType.investigate,
    difficulty: 3,
    deadlineMonths: 4,
    steps: [
      NpcTaskStep(description: '摸清守卫换岗的时辰', turnsRequired: 1),
      NpcTaskStep(description: '引开城门守卫，掩护艾莉亚出城', turnsRequired: 1),
      NpcTaskStep(description: '天亮前接应她安全返回', turnsRequired: 1),
    ],
    rewardGold: 50,
    rewardReputation: 3,
    rewardRelation: 8,
  ),

  // ==================== 布兰·史塔克（临冬城） ====================
  NpcTaskTemplate(
    id: 'task_bran_climb',
    npcId: 'npc_bran',
    title: '带布兰登高看鹰巢',
    type: NpcTaskType.escort,
    difficulty: 1,
    deadlineMonths: 2,
    steps: [
      NpcTaskStep(description: '护送布兰登上临冬城最高的瞭望塔', turnsRequired: 1),
      NpcTaskStep(description: '陪他瞭望原野，讲远方故事', turnsRequired: 1),
    ],
    rewardGold: 20,
    rewardReputation: 2,
    rewardRelation: 6,
  ),
  NpcTaskTemplate(
    id: 'task_bran_stories',
    npcId: 'npc_bran',
    title: '为布兰收集古堡传说',
    type: NpcTaskType.investigate,
    difficulty: 2,
    deadlineMonths: 4,
    steps: [
      NpcTaskStep(description: '拜访临冬城的老人与学士搜集传说', turnsRequired: 1),
      NpcTaskStep(description: '整理成册交给布兰', turnsRequired: 1),
    ],
    rewardGold: 35,
    rewardReputation: 3,
    rewardRelation: 6,
  ),

  // ==================== 詹姆·兰尼斯特（君临） ====================
  NpcTaskTemplate(
    id: 'task_jaime_sword',
    npcId: 'npc_jaime',
    title: '与詹姆切磋剑术',
    type: NpcTaskType.hunt,
    difficulty: 4,
    deadlineMonths: 4,
    steps: [
      NpcTaskStep(description: '在君临校场与詹姆对练', turnsRequired: 1),
      NpcTaskStep(description: '承受他的连环攻势并坚持到最后', turnsRequired: 1),
      NpcTaskStep(description: '与詹姆复盘切磋心得', turnsRequired: 1),
    ],
    rewardGold: 60,
    rewardReputation: 5,
    rewardRelation: 8,
  ),
  NpcTaskTemplate(
    id: 'task_jaime_letter',
    npcId: 'npc_jaime',
    title: '为詹姆送一封密信',
    type: NpcTaskType.delivery,
    difficulty: 2,
    deadlineMonths: 3,
    steps: [
      NpcTaskStep(description: '将密信藏入行囊，避开城中耳目', turnsRequired: 1),
      NpcTaskStep(description: '把信送到城外指定的人手中', turnsRequired: 1),
    ],
    rewardGold: 40,
    rewardReputation: 3,
    rewardRelation: 6,
  ),

  // ==================== 劳勃·拜拉席恩（君临） ====================
  NpcTaskTemplate(
    id: 'task_robert_hunt',
    npcId: 'npc_robert_baratheon',
    title: '陪劳勃国王狩猎',
    type: NpcTaskType.hunt,
    difficulty: 3,
    deadlineMonths: 3,
    steps: [
      NpcTaskStep(description: '备好猎犬与长矛，随国王出猎', turnsRequired: 1),
      NpcTaskStep(description: '在御林深处驱赶野猪', turnsRequired: 1),
    ],
    rewardGold: 55,
    rewardReputation: 6,
    rewardRelation: 7,
  ),
  NpcTaskTemplate(
    id: 'task_robert_mead',
    npcId: 'npc_robert_baratheon',
    title: '为国王搜罗佳酿',
    type: NpcTaskType.delivery,
    difficulty: 2,
    deadlineMonths: 3,
    steps: [
      NpcTaskStep(description: '到君临的酒窖与市集挑选名酒', turnsRequired: 1),
      NpcTaskStep(description: '把酒送回红堡献给国王', turnsRequired: 1),
    ],
    rewardGold: 35,
    rewardReputation: 4,
    rewardRelation: 5,
  ),

  // ==================== 史坦尼斯·拜拉席恩（龙石岛） ====================
  NpcTaskTemplate(
    id: 'task_stannis_ship',
    npcId: 'npc_stannis_baratheon',
    title: '修缮龙石岛的舰队',
    type: NpcTaskType.escort,
    difficulty: 3,
    deadlineMonths: 5,
    steps: [
      NpcTaskStep(description: '清点龙石岛港内的破损船只', turnsRequired: 1),
      NpcTaskStep(description: '采购木材与沥青，监督工匠修缮', turnsRequired: 2),
    ],
    rewardGold: 50,
    rewardReputation: 5,
    rewardRelation: 7,
  ),
  NpcTaskTemplate(
    id: 'task_stannis_loyalty',
    npcId: 'npc_stannis_baratheon',
    title: '摸清诸侯的忠诚',
    type: NpcTaskType.investigate,
    difficulty: 4,
    deadlineMonths: 6,
    steps: [
      NpcTaskStep(description: '在龙石岛的领主间打探态度', turnsRequired: 2),
      NpcTaskStep(description: '从信件往来中找出摇摆者', turnsRequired: 2),
      NpcTaskStep(description: '把名单呈给史坦尼斯', turnsRequired: 1),
    ],
    rewardGold: 85,
    rewardReputation: 5,
    rewardRelation: 8,
  ),
];

/// 按 ID 查找任务模板。
NpcTaskTemplate? npcTaskTemplateById(String id) {
  for (final t in allNpcTaskTemplates) {
    if (t.id == id) return t;
  }
  return null;
}

/// 某 NPC 的全部任务模板。
List<NpcTaskTemplate> npcTaskTemplatesOf(String npcId) {
  return allNpcTaskTemplates.where((t) => t.npcId == npcId).toList();
}