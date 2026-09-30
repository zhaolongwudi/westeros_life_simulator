# 内容数据 Schema 规范（content-schema）

> M4 内容外置的契约文档。批量内容生产（无论人工还是 AI）必须严格符合本规范。
> 配套质量 checklist 见文末，验收时逐条过。

---

## 0. 通用约定

- 全部文件 UTF-8、JSON 数组、每实体一个对象、`id` 全局唯一蛇形命名（如 `evt_0101`、`fam_0003`）。
- 所有文本字段为简体中文；叙事文风：冷静、成人向、权谋质感，第二人称"你"，单段不超过 120 字。
- 数值档位约定：低 = 1~10，中 = 11~50，高 = 51+（金币/属性效果共用此约定）。
- 条件表达式统一为对象结构：`{"field": "属性路径", "op": ">=|<=|==|!=", "value": 数值或枚举}`，多条件为数组，关系恒为 AND。

---

## 1. 事件（events.json）

**字段定义**

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| id | string | 是 | evt_ 前缀 + 4 位序号 |
| title | string | 是 | ≤12 字 |
| text | string | 是 | 事件正文，40~300 字 |
| type | enum | 是 | random / location / identity / family / season / chain |
| weight | int | 是 | 1~100，同池内相对概率 |
| conditions | array | 否 | 触发条件，见通用约定；缺省=无门槛 |
| season | enum | 否 | spring/summer/autumn/winter/longwinter |
| locationIds | array<string> | 否 | 限定地点 |
| identityIds | array<string> | 否 | 限定身份枚举（英文枚举名） |
| once | bool | 否 | 默认 false；true=每局只触发一次 |
| choices | array<Choice> | 是 | 2~4 个选项 |

**Choice 子对象**

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| text | string | 是 | ≤20 字 |
| conditions | array | 否 | 选项可用条件 |
| effects | object | 是 | `{gold?:int, health?:int, energy?:int, hunger?:int, attrs?:{力量?:int,...}, relations?:{npcId:int}, flags?:[string]}` |
| nextEventId | string | 否 | 链式事件跳转 |

**约束关系**
- effects 引用的 npcId 必须存在于 npcs.json；flags 自由命名但同一旗标须有消费方事件。
- nextEventId 指向的事件 type 必须为 chain，且不得成环。
- 数值效果单次 |gold| ≤ 200，单项属性 |delta| ≤ 5（防数值爆炸，平衡由 M4 仿真测试兜底）。

**样例（1 条）**
```json
{
  "id": "evt_0101", "title": "旧镇市集", "type": "location", "weight": 30,
  "text": "旧镇的市集人声鼎沸，一个布拉佛斯商人向你兜售一把据称来自瓦雷利亚的短刃，价格低得可疑。",
  "locationIds": ["loc_oldtown"], "season": "summer",
  "choices": [
    {"text": "买下短刃（50金）", "conditions": [{"field":"gold","op":">=","value":50}],
     "effects": {"gold": -50, "flags": ["owns_valyrian_dagger"]}},
    {"text": "转身离开", "effects": {}}
  ]
}
```

---

## 2. 人物 NPC（npcs.json）

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| id | string | 是 | npc_ 前缀 |
| name | string | 是 | 2~8 字 |
| type | enum | 是 | noble / merchant / knight / maester / smallfolk / septon |
| familyId | string | 否 | 须存在于 families.json |
| locationId | string | 是 | 常驻地点 |
| baseRelation | int | 是 | -100~100，对玩家初始好感 |
| traits | array<string> | 否 | 性格标签 ≤3 个 |
| interactable | bool | 是 | 是否可深度交互 |

**约束**：familyId 为空时 type 不得为 noble；baseRelation 与家族敌对关系不应矛盾（敌对家族成员初始好感 ≤ 0）。

## 3. 家族（families.json）

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| id | string | 是 | fam_ 前缀 |
| name | string | 是 | 家族名（不含"家族"二字） |
| seatLocationId | string | 是 | 族堡，须存在于 locations.json |
| scale | enum | 是 | great / major / minor |
| words | string | 否 | 族语 ≤16 字 |
| allies / enemies | array<string> | 否 | 互引 familyId，敌对关系须对称 |

**约束**：allies 与 enemies 不得交集；enemies 必须对称（A 列 B 为敌 ⇒ B 列 A 为敌）。

## 4. 地点（locations.json）

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| id | string | 是 | loc_ 前缀 |
| name | string | 是 | |
| type | enum | 是 | city / castle / town / village / wilderness / port |
| region | enum | 是 | 12 大区域之一（与 narrative_templates 区域键一致） |
| connectedIds | array<string> | 是 | 可达地点，连接须对称 |
| specialtyItemIds | array<string> | 否 | 特产，须存在于 items.json |

## 5. 物品（items.json）

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| id | string | 是 | item_ 前缀 |
| name | string | 是 | |
| category | enum | 是 | weapon / armor / food / goods / luxury / tool |
| basePrice | int | 是 | 1~10000 |
| effect | object | 否 | 使用/装备效果，结构同事件 effects |
| stackable | bool | 是 | |

---

## 内容质量 Checklist（机器+人工抽检用，10 条）

1. id 全局唯一且符合前缀规范，编号连续无跳号（同批次内）。
2. 所有引用完整性：locationIds / familyId / npcId / itemId / nextEventId 指向的实体真实存在。
3. 事件 choices 数量 2~4，且至少一个无条件选项（避免玩家被卡死）。
4. 数值合规：单事件 |gold| ≤ 200、单属性 |delta| ≤ 5、weight ∈ [1,100]。
5. 条件表达式字段路径合法（gold/health/energy/hunger/attrs.*/flags.*），op 为白名单内。
6. 文本字数：事件正文 40~300 字；标题 ≤12 字；选项 ≤20 字。
7. 文风：第二人称、无现代词汇、无网络梗、无超出世界观的专有名词（可对账 docs/01_世界百科.md）。
8. 家族 enemies 对称、地点 connectedIds 对称（双向一致性）。
9. 内容分布：每批产出中 低/中/高 三档数值效果占比均 ≥ 20%，四种 type 至少覆盖三种。
10. 无敏感内容：无露骨性描写、无现实政治映射、无歧视性表述。

**抽检规则**：每批随机抽 10%（至少 10 条）过 checklist；任一批次同一项失败 ≥3 次 → 整批按修正规则返工。