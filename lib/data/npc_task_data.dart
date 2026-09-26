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