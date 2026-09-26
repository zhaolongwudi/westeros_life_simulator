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