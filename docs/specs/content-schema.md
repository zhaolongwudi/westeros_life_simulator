# 内容数据 Schema 规范（content-schema）

> 内容数据的**唯一契约文档**。批量内容生产（人工或 AI）必须严格符合本规范。
> 配套 checklist 见文末，第 1-6 条已由 `scripts/check_content_sync.py` 在 CI 中执行。

---

## 版本与修订说明

| 版本 | 日期 | 变更 |
|---|---|---|
| v1（旧版） | — | 凭空撰写的"设想版"：字段表与真实模型几乎无一条对得上（详见下节） |
| **v2（现行）** | 2026-10-07 | S3-1 以 `lib/models/*.dart` 的 `fromJson` + `assets/data/*.json` 实测值重写；checklist 1-6 挂入 CI |

### 旧版错在哪（留档，避免重蹈）

旧版不是"过时"，是**从未成立**——描述的字段在代码里根本不存在：

| 旧版写法 | 实际 |
|---|---|
| id 形如 `evt_0101` / `fam_0003` / `loc_oldtown` | `event_king_death` / `family_stark` / `location_winterfell`（语义蛇形，无编号） |
| 事件字段 `title` / `text` / `weight` / `conditions` / `once` | `name` / `description` / `triggerConditions` / `tags` / `isOneTime`；**没有 `weight` 字段** |
| 条件表达式 `{"field","op","value"}` 数组 | 扁平 `Map<String,String>`（事件级）与 `Map<String,int>`（选项级），无 op 概念 |
| `Choice.effects` 嵌套 `{gold, attrs:{}, relations:{}}` | 扁平点号键 `{'gold': -50, 'attributes.strength': 1, 'relations.npc_x': 5}` |
| 家族 `allies` / `enemies` 两个数组 | 单个 `relations: Map<家族id, int>`（-100~100 连续值，非布尔敌友） |
| NPC `baseRelation` / `interactable` | 不存在；NPC 有 `relations`（NPC↔NPC）与 `skills` |
| 地点 `specialtyItemIds` | 不存在（旧对账脚本里那条检查恒为空集，形同虚设） |
| 事件 `nextEventId` 链式跳转 | 不存在，无链式事件机制 |
| 数值约定 `|gold| ≤ 200` | 现状极值 500（家族灭亡 -500 / 铁金库还债 -500 / 贸易繁荣 +400） |
| 文本约定"正文 40~300 字" | 现状 4~40 字（事件描述是一句话梗概，叙事交给 AI 展开） |

**为什么能错这么久**：文档写完没人执行。旧版文末那 10 条 checklist
**没有任何一条被代码验证过**。S3-1 把其中可机器判定的 1-6 条挂进了 CI。

---

## 0. 真相源与数据流

```
lib/data/*.dart            ← 运行时真相源（const 常量，直接编译进包）
   │  python3 scripts/dart_content_extract.py
   ▼
assets/data/*.json         ← 单向导出镜像（只读，运行时从不加载）
   │  python3 scripts/check_content_sync.py
   ▼
   CI 对账（id 集合 / 内容 / 引用 / 镜像契约 / checklist 1-6）
```

三条硬规则：

1. **改内容 = 改 `lib/data/*.dart`**，然后**必须**重跑 `python3 scripts/dart_content_extract.py`，
   否则 CI 红（对账脚本会报"内容与 Dart 不一致"）。
2. **不要手改 `assets/data/*.json`**。它是产物，改了会被下次导出覆盖；
   且 `pubspec.yaml` 没有 assets 声明，运行时**根本不读 JSON**，改它对游戏零影响。
3. **docs/\*.md 不参与自动对账**（人工维护）。文档与数据的一致性是 S3-2 的议题。

### 0.1 id 前缀表（强制）

| 域 | 文件 | 前缀 | 现状条数 |
|---|---|---|---|
| 事件 | `events.json` | `event_` | 72 |
| 家族 | `families.json` | `family_` | 27 |
| 地点 | `locations.json` | `location_` | 69 |
| NPC | `npcs.json` | `npc_` | 38 |
| 物品 | `items.json` | `item_` | 33 |
| 系统 | `systems.json` | `system_` | 74 |
| 任务模板 | `tasks.json` | `task_` | 72 |

前缀写错（如 `fam_stark`）会让该实体**被导出器静默丢弃**——id 集合对账照样通过，
只有总条数会变。checklist 1 专门比对"过滤前后条数"来抓这一类。

### 0.2 通用约定

- 文件 UTF-8、JSON 数组、每实体一个对象、`id` 全局唯一（含跨域）。
- 文本字段简体中文；叙事文风：冷静、成人向、权谋质感，第二人称"你"。
- 数值档位：低 = 1~10，中 = 11~50，高 = 51+。
- **枚举字段在 JSON 里写裸枚举名**（`political`，不是 `EventType.political`）。
  模型的 `fromJson` 用 `byName` / `safeEnum` 按裸名取值，带前缀会导致回落或抛错。

---

## 1. 事件（events.json）

对应模型 `lib/models/event.dart` → `GameEvent`。
`fromJson` 为**防御式**（`safeStr`/`safeEnum`/`safeStringMap`），字段缺失不抛。

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `id` | string | 是 | `event_` 前缀 |
| `name` | string | 是 | 事件名，≤16 字（现状 max 9） |
| `type` | enum | 是 | 见 1.1 |
| `description` | string | 是 | 一句话梗概，4~120 字（现状 4~40） |
| `triggerConditions` | Map\<String,String\> | 否 | 触发门槛，见 §3；缺省 = 无门槛 |
| `choices` | List\<Choice\> | 是 | 2~4 个，见 §2 |
| `narrative` | string | 是 | 进入事件时的场景叙事 |
| `tags` | List\<string\> | 否 | 筛选与统计用（现状 72/72 非空） |
| `isOneTime` | bool | 否 | 默认 false；true = 每局只触发一次（现状 3 个） |

**注意：没有 `weight` 字段。** 事件浮现的筛选与排序在 `EventProvider` / AI 侧完成，
内容数据不参与权重配置。旧版文档里的 `weight ∈ [1,100]` 一条因此**无法校验**，已删除。

### 1.1 EventType（9 值）

`political` `family` `war` `religious` `economic` `magical` `daily` `adventure` `supernatural`

### 1.2 样例（真实数据，`event_road_bandits`）

```json
{
  "id": "event_road_bandits",
  "name": "路遇匪帮",
  "type": "adventure",
  "description": "商路上出现一伙匪帮，正拦路劫掠过往行人。",
  "triggerConditions": { "minGold": "20" },
  "choices": [
    { "id": "choice_fight_bandits", "text": "拔剑迎战",
      "requirements": { "skills.sword": 3 },
      "effects": { "gold": 25, "reputation": 8, "health": -10 },
      "narrative": "你杀出一条血路，匪帮四散而逃，你夺回了他们的赃物。" },
    { "id": "choice_flee_road", "text": "避让绕路",
      "requirements": {},
      "effects": { "energy": -5 },
      "narrative": "你不想生事，远远绕开匪帮的营火，多花了些脚程。" }
  ],
  "narrative": "前方尘土飞扬，几个蒙面大汉拦住了去路，刀锋在日光下泛着寒光。",
  "tags": ["adventure", "danger", "robbery"],
  "isOneTime": false
}
```

---

## 2. 事件选项（EventChoice）

对应 `lib/models/event.dart` → `EventChoice`。

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `id` | string | 是 | `choice_` 前缀（约定，非强制） |
| `text` | string | 是 | ≤24 字（现状 max 7） |
| `requirements` | Map\<String,int\> | 否 | 选项**可用**门槛，见 §3.2；空 = 永远可选 |
| `effects` | Map\<String,int\> | 是 | 扁平点号效果键，见 §4；`{}` 表示无效果 |
| `narrative` | string | 是 | 选中后的结果叙事，≥6 字（现状 min 10） |

**结构约束**（checklist 3，CI 强制）
- 选项数 ∈ [2, 4]；
- **至少一个选项 `requirements` 为空**——否则玩家一旦不满足全部条件就被卡死在事件里。

---

## 3. 门槛键白名单

两条判定通道（`EventProvider.canChoose` 与 `EventService.canChoose`）的键集**相同**；
事件级门槛由 `lib/core/event_trigger_eval.dart` 的 `eventTriggersSatisfied` 判定。
**白名单外的键 = 死门槛**（没有任何代码会读它 ⇒ 门槛恒成立）。

> 2026-10-07 S3-1 清理：原有 26 处死门槛键（`army`×9 / `diplomacy`×9 /
> `military`×5 / `magic`×3）已从数据中移除。这 4 个键在 Player 上没有对应字段，
> 写了等于没写。为"带兵镇压""外交游说""魔法仪式"设计**真实**门槛是设计工作，
> 已立为 S4-3 任务（清单见 `docs/03-审查接力.md`）。

### 3.1 事件级 `triggerConditions`（`Map<String,String>`）

| 键 | 值语义 |
|---|---|
| `season` | `spring` / `summer` / `autumn` / `winter` / `longwinter` / `any` |
| `locationId` / `familyId` / `identity` | 字符串相等 |
| `minAge` `maxAge` `minGold` `minReputation` | 数值门槛（值须可 `int.parse`） |
| `minHealth` `maxHealth` `minEnergy` `maxEnergy` `minHunger` `maxHunger` | 同上 |
| `flag` / `noFlag` | 值 = 旗标名；`noFlag` 为反向 |
| `isAlive` | 值 = `'true'` / `'false'` |
| `hasItem.<itemId>` | 值 = 需要持有的数量 |
| `skills.<技能键>` / `attributes.<属性键>` | 值 = 需要达到的等级 |

- **未知键在运行时放行**（`_matchesCondition` 末尾 `return true`），这是为兼容旧存档里
  已序列化的自定义门槛而刻意保留的。CI 对未知键只发 **WARN**，不阻断。
- **数值键的值必须是可解析的整数**：解析失败时 `_atLeast`/`_atMost` 会放行，
  门槛静默失效——这是 error 级。

### 3.2 选项级 `requirements`（`Map<String,int>`）

合法键：`gold` `reputation` `health` `energy` `hunger` `flag`
+ 前缀 `skills.` `attributes.` `hasItem.`。

语义一律是 **≥**（`player.X < value ⇒ 不可用`）。

> ⚠️ 陷阱：`flag` 的值类型是 `Map<String,int>`，**但消费方写的是
> `player.flags[value] ?? false`**（`Map<String,bool>` 用 int 取值）——类型不匹配，
> 恒为 false。数据里目前没有用到 `flag`，**新增时不要用它**。

---

## 4. 效果键（effects / useEffect）

扁平点号键，`Map<String,int>`。写入通道有两条，必须保持同步：
`GameStateProvider.applyEffects`（AI 选项与 `applyChoice`）与
`EventService.applyEffects`（记录 `failedEffects`）。项目已发生过五次双通道漂移。

| 键族 | 合法键 | 来源 |
|---|---|---|
| 基础数值 | `gold` `reputation` `health` `energy` `hunger` `age` | — |
| 技能 | `skills.<13 键>` | `BalanceData.kPlayerSkillKeys`：sword / leadership / politics / archery / scholarship / stealth / fencing / survival / craft / magic / riding / speech / alchemy |
| 属性 | `attributes.<6 键>` | `kPlayerAttributeKeys`：strength / agility / intelligence / charisma / willpower / perception |
| 好感 | `relations.<npcId>` | 必须存在于 npcs.json |
| 旗标 | `flags.<key>` | 26 个静态键（`kPlayerFlagKeys`）+ 5 个动态前缀（`equipped.` / `house.childDead.` / `npc_task.` / `npc_task_done.` / `npc_story.`） |
| 物品 | `inventory.<itemId>` | 必须存在于 items.json |

**幽灵效果键（写了不生效，但会记入 `failedEffects` 并提示玩家）**：
`political` `faith` `military` `magic` `familyRelation` `food` `happiness`
`knowledge` `north` `allyRelation`——共 10 键、78 处、涉及 40/72 个事件。
现状已在 UI 层做可见化（S2-3），清理与接线属 S4-3。**新增内容不要用这 10 个键。**

**数值上下界**（checklist 4，CI）
- `|gold| ≤ 500` 硬闸；`> 200` 触发 WARN（建议带，超出需在数据旁注明是刻意设计）。
  现状 4 个选项超建议带：`event_iron_bank_crisis/choice_repay`、`event_family_extinction/choice_save`、
  `event_trade_boom/choice_invest`、`event_iron_bank_debt/choice_repay`。
- `|attributes.*|` 与 `|skills.*|` ≤ 5。

---

## 5. 人物 NPC（npcs.json）

对应 `lib/models/npc.dart` → `Npc`。**`fromJson` 不是防御式**（`as String` / `byName`）。

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `id` | string | 是 | `npc_` 前缀 |
| `name` | string | 是 | |
| `type` | enum | 是 | 见 5.1 |
| `age` | int | 是 | |
| `gender` | string | 是 | `male` / `female` |
| `familyId` | string | 否 | 须存在于 families.json；空串 = 无家族 |
| `locationId` | string | 是 | 常驻地点，须存在于 locations.json |
| `personality` `goals` `fears` `secrets` | List\<string\> | 否 | |
| `relations` | Map\<string,int\> | 否 | **NPC ↔ NPC** 好感 -100~100；键须存在且不自指 |
| `skills` | Map\<string,int\> | 否 | 现状键集：leadership / politics / sword |
| `faith` | string | 是 | 如 旧神 / 七神 / 光之王 |
| `isAlive` | bool | 是 | |
| `tasks` | List\<string\> | 否 | 任务**标题**列表（默认 `[]`） |
| `mood` | string | 否 | 当前心情（默认 `''`） |

> `mood` 与 `tasks` 曾长期导出错误（`mood` 被转成 int、`tasks` 整个缺失），
> 是 P1-01 的成因。现由镜像契约第 1-2 条守住。

### 5.1 NpcType（11 值）

`noble` `soldier` `merchant` `priest` `scholar` `adventurer` `assassin` `maester`
`wildling` `commoner` `supernatural`

---

## 6. 家族（families.json）

对应 `lib/models/family.dart` → `Family`。**`fromJson` 不是防御式**。

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `id` | string | 是 | `family_` 前缀 |
| `name` | string | 是 | 不含"家族"二字 |
| `motto` | string | 是 | 族语 |
| `seat` | string | 是 | 族堡 location id，须存在 |
| `scale` | enum | 是 | `great` / `minor` / `household` |
| `population` `army` `goldReserve` | int | 是 | |
| `influence` | int | 是 | 政治影响力 0-100 |
| `relations` | Map\<string,int\> | 否 | **家族 ↔ 家族** -100~100；键须存在且不自指 |
| `secrets` `traits` | List\<string\> | 否 | |

**没有 `allies` / `enemies`。** 敌友是 `relations` 的连续值，不是布尔关系。

> ⚠️ 现状：`relations` 有 22 处**非对称**（A 对 B 有值，B 对 A 没有或值不同），
> 例如 `family_umber → family_stark: 50` 但反向缺失。消费方只读单向值，
> 所以不崩，但"家族敌友网络"是残缺的。补对称属 S3-2 / S4-1 议题。

---

## 7. 地点（locations.json）

对应 `lib/models/location.dart` → `Location`。**`fromJson` 不是防御式**。

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `id` | string | 是 | `location_` 前缀 |
| `name` | string | 是 | |
| `type` | enum | 是 | 见 7.1 |
| `region` | string | 是 | 中文区域名（北境 / 河间地 / …） |
| `dangerLevel` | int | 是 | 0-10 |
| `population` | int | 是 | |
| `features` | List\<string\> | 否 | 地标特色 |
| `governorId` | string \| **null** | 否 | 治主 NPC id；无治主写 `null`（现状 57/69 为 null） |
| `connectedTo` | List\<string\> | 否 | 可达地点 id，须存在 |
| `description` | string | 是 | |

> `governorId` 写 `"null"`（字符串）是错的：`ai_service` 的判空是
> `== null || isEmpty`，长度 4 的字符串两个都不满足，会走进"治主数据缺失，地方权力真空"分支。

### 7.1 LocationType（11 值）

`castle` `city` `village` `fort` `temple` `academy` `tavern` `market`
`wilderness` `supernatural` `unknown`

> ⚠️ 现状：`connectedTo` 有 30 处**非对称**（A 能到 B，B 到不了 A）→ 单向旅行。
> 修对称属 S4-1 议题。

---

## 8. 物品（items.json）

对应 `lib/data/item_data.dart` → `Item`。
**该模型没有 `fromJson`** —— items.json 目前无法被反序列化，这是 S4-4 的前置条件之一。

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `id` | string | 是 | `item_` 前缀 |
| `name` | string | 是 | |
| `category` | enum | 是 | 见 8.1 |
| `value` | int | 是 | 金币价值（现状 1~800） |
| `description` | string | 是 | |
| `stackable` | bool | 否 | 默认 true |
| `usable` | bool | 否 | 默认 false |
| `useEffect` | Map\<string,int\> | 否 | 键同 §4（如 `{'hunger': 15}`） |
| `requiresSkill` | string | 否 | 使用所需技能；空串 = 无要求 |

### 8.1 ItemCategory（8 值）

`consumable` `weapon` `armor` `material` `treasure` `relic` `document` `mount`

---

## 9. 系统（systems.json）

对应 `lib/models/system.dart` → `GameSystem`。**`fromJson` 不是防御式**。

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `id` | string | 是 | `system_` 前缀 |
| `name` | string | 是 | |
| `category` | string | 是 | **自由中文**，不是枚举（封建 / 经济 / 魔法 / AI / …） |
| `description` | string | 是 | |
| `rules` `features` | List\<string\> | 是 | |

---

## 10. NPC 任务模板（tasks.json）

对应 `lib/models/npc_task.dart` → `NpcTaskTemplate`。**该模型没有 `fromJson`**。

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `id` | string | 是 | `task_` 前缀 |
| `npcId` | string | 是 | 发布者，须存在于 npcs.json |
| `title` | string | 是 | 与 `Npc.tasks` 里的标题呼应 |
| `type` | enum | 是 | `escort` `delivery` `hunt` `investigate` `diplomacy` |
| `difficulty` | int | 是 | 1-5（现状 1-4） |
| `deadlineMonths` | int | 是 | 逾期失败 |
| `steps` | List\<Step\> | 是 | ≥1 步；`{description, turnsRequired}`（现状 2-3 步、1-3 回合） |
| `rewardGold` `rewardReputation` `rewardRelation` | int | 是 | |
| `coNpcId` | string | 否 | 协作 NPC；非空 = 多 NPC 任务，不得与 `npcId` 相同 |

实际金币奖励 = `rewardGold × difficultyMultiplier`（`1 + (difficulty - 1)`）。

---

## 11. 镜像字段契约（CI 第 6 项）

`assets/data/*.json` 是导出产物，但**它必须能被模型的 `fromJson` 反序列化**——
否则"内容外置"（S4-4）一落地就会全线崩。以下 6 条由 `check_content_sync.py` 强制：

| # | 契约 | 违反后果 |
|---|---|---|
| 1 | `npcs.json` 的 `mood` 必须是字符串 | `Npc.fromJson` 对 int 抛 TypeError |
| 2 | `npcs.json` 的 `tasks` 必须是列表 | 任务链数据丢失 |
| 3 | `locations.json` 的 `governorId` 必须是 JSON `null` 或 `npc_` 开头的 id | 56 个无治主地点被判为"治主数据缺失" |
| 4 | 枚举字段必须是裸名（不含 `.`） | `Family`/`Location`/`Npc` 的 `byName` 抛错；`GameEvent` 静默回落 `daily` |
| 5 | `events.json` 的 `triggerConditions` 值必须是字符串 | `safeStringMap` 跳过非字符串 → 15 个数值门槛整条消失 |
| 6 | 各域 id 前缀与唯一性（checklist 1） | 前缀错 → 实体被静默丢弃 |

前 5 条都是 2026-10-07 S3-1 实测发现并修复的；共同点是**运行时不读 JSON，
所以可以无限期潜伏**。回归闸门是 `test/batch10_121_content_schema_test.dart`
（把镜像喂给真实 `fromJson`，用 `toJson()` 做全字段往返比对）。

---

## 内容质量 Checklist（10 条）

**状态列**：🟢 = 已由 `scripts/check_content_sync.py` 在 CI 强制执行；
🟡 = 脚本只发 WARN；🔵 = 人工抽检。

| # | 条目 | 状态 | 说明 |
|---|---|---|---|
| 1 | id 唯一且前缀符合域规范（含"未被导出器静默丢弃"） | 🟢 | 比对过滤前后条数 |
| 2 | 引用完整性：`seat` / `locationId` / `familyId` / `governorId` / `connectedTo` / `relations.*` / `hasItem.*` / `inventory.*` / `npcId` / `coNpcId` | 🟢 | JSON 侧 + Dart 侧双查 |
| 3 | 选项数 2~4，且至少一个无条件选项 | 🟢 | 防玩家被卡死 |
| 4 | 数值：`|gold| ≤ 500`、属性/技能 `|delta| ≤ 5` | 🟢 | `|gold| > 200` 转 🟡 WARN |
| 5 | 门槛键在白名单内；数值门槛值可 `int.parse`；`season` 取值合法 | 🟢 / 🟡 | 未知**触发**键只 WARN（运行时刻意放行） |
| 6 | 文本长度：事件名 ≤16、描述 4~120、选项 ≤24、结果叙事 ≥6 | 🟢 | 界值取自现状分布 + 余量 |
| 7 | 文风：第二人称、无现代词汇、无网络梗、不超出世界观 | 🔵 | 对账 `docs/01_世界百科.md` |
| 8 | 对称性：`connectedTo` 双向、`relations` 双向等值 | 🔵 | 现状 30 + 22 处不对称，见 §6 / §7 |
| 9 | 内容分布：数值三档占比、事件 type 覆盖 | 🔵 | |
| 10 | 无敏感内容：无露骨性描写、无现实政治映射、无歧视性表述 | 🔵 | |

**抽检规则**：每批随机抽 10%（至少 10 条）过 checklist；
任一批次同一项失败 ≥3 次 → 整批返工。
