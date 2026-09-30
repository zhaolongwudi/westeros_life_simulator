# 维斯特洛人生模拟器 · 代码地图（CODE_MAP）

> **本文件是代码结构导航索引**：下个对话/工具接手时，先读 HANDOVER.md 了解进度，
> 再读本文件快速定位「哪个功能在哪个文件、哪个方法」。避免盲目翻代码。
>
> 定位三步法：
> 1. 找功能归属层（数据/模型/逻辑/UI/服务）→ 看下方目录
> 2. 打开对应文件，用「功能速查」定位类/方法
> 3. 改代码前先看对应 batch 测试（test/batch*_test.dart）了解既有契约

---

## 一、代码总览（lib/ 结构）

```
lib/
├── main.dart                      # 入口（runApp）
├── app.dart                       # 根组件：StartScreen → GameScreen
├── game_engine.dart               # ⭐ 引擎宿主：组合全部 mixin（含混入顺序）
│
├── core/                           # 【框架层】纯 Dart，无状态层依赖（Batch 10-28 · M3a 新增）
│   ├── command_registry.dart      # ⭐ CommandSpec/CommandRegistry：指令注册表（别名分发/帮助生成/重复别名记录），132 行
│   └── monthly_pipeline.dart      # ⭐ MonthlyPhase/MonthlyHookSpec/MonthlyPipeline：月度结算管线（phase × order × outputOrder 三轴，runMonth 注入 advanceClock），129 行
│
├── data/                          # 【静态数据层】世界常量数据
│   ├── family_data.dart           # 27 家族
│   ├── location_data.dart         # 68 地点
│   ├── npc_data.dart              # 36 NPC（含 Batch 10-15 任务链 tasks/mood）
│   ├── event_data.dart            # 72 事件（60 + 12 复合）
│   ├── system_data.dart           # 74 系统
│   ├── item_data.dart             # 34 物品
│   ├── narrative_templates.dart   # 差异化叙事引导（10 身份/12 区域/5 季节）
│   ├── balance_data.dart           # ⭐ 数值配置集中（初始值/生存消耗/每日上限/头衔阶梯/活动经济/婚姻与世代阈值，Batch 10-30 · M4a；无 import 依赖的叶子模块）
│   └── npc_task_data.dart         # NPC 多步骤任务模板（32 个：艾德/提利昂/丹妮莉丝/琼恩/瑟曦/奥莲娜/凯特琳/罗柏/玛格丽/泰温/珊莎/艾莉亚/布兰/詹姆/劳勃/史坦尼斯，Batch 10-18 起逐步扩充，10-23 扩至 32）
│
├── models/                        # 【模型层】不可变实体（copyWith + toJson/fromJson）
│   ├── player.dart                # Player（含 health/energy/hunger/title/house/children/spouse/childRearing/generationRecords/activeTasks）
│   ├── family.dart                # Family + FamilyScale
│   ├── npc.dart                   # Npc + NpcType（含 tasks/mood，Batch 10-15）
│   ├── location.dart              # Location + LocationType
│   ├── event.dart                 # GameEvent + EventChoice + EventType
│   ├── system.dart                # GameSystem
│   ├── marital.dart               # SpouseDetail/ChildRearing/GenerationRecord（婚姻/培养/谱系状态对象，Batch 10-17）
│   ├── letter.dart                # ⭐ Letter（信件数据，Batch 10-29 · M3b 从 mixin_letter 迁到模型层，UI 才不用 import 混入层）
│   ├── ai_turn.dart               # ⭐ AiTurnResult（AI 回合结果：lines/choices/isSuccess + 两条提示常量，Batch 10-29 · M3b）
│   └── npc_task.dart              # NpcTaskType/NpcTaskStep/NpcTaskTemplate/NpcTaskProgress（任务模板+实例，Batch 10-18）
│
├── providers/                     # 【状态层】ChangeNotifier
│   ├── game_state_provider.dart   # GameStateProvider：玩家/进度/事件历史 + applyEffects + endGame
│   ├── event_provider.dart        # EventProvider：事件触发/选项/重置
│   └── game_provider_base.dart    # ⭐ 基类：世界静态数据 + 公共能力（身份/金币/关系/标记/rng）
│
├── mixins/                        # 【逻辑层】玩法能力（按领域拆分）
│   ├── mixin_life.dart            # 生存状态 + 物品 + 贸易 + 装备 + 头衔 + 月度结算（769 行，最大）
│   ├── mixin_play.dart            # 日常玩法：训练/工作/休息/狩猎/贸易/过月 + 死亡传承
│   ├── mixin_systems.dart         # 74 系统挂载 + 月度演进 + 系统面板
│   ├── mixin_adventure.dart       # 旅行/探索/遭遇（探索含 NPC 任务结算）
│   ├── mixin_letter.dart          # NPC 来信/回信/关系培养
│   ├── mixin_npc_interact.dart    # NPC 深度交互：关系等级/互动/示好/事件链 + 任务链/深聊/关系面板
│   ├── mixin_generation.dart      # ⭐ 家族继承与多世代：立嗣/家谱/死亡传承（Batch 10-14；advanceGeneration 写谱系记录，Batch 10-17）
│   ├── mixin_marriage.dart        # ⭐ 婚姻系统：求婚/配偶互动/婚后每月事件/子女培养/督导送学/多代家族树（Batch 10-17，245 行）
│   ├── mixin_npc_task.dart        # ⭐ NPC 任务链二轮：多步骤任务/期限系统/奖励差异化（Batch 10-18，221 行）
│   ├── mixin_commands.dart        # ⭐ 指令分发器（Batch 10-28 · M3a：401→100 行，只「拉齐 10 个领域自注册 + 按别名分发 + 帮助/未知指令」；**新增指令请去对应领域 mixin 的 registerXxxCommands**，不要再改这里）
│   └── mixin_ai.dart              # AI 回合混入（applyAiChoice）
│
│   （Batch 10-28 · M3a 自注册约定：9 个领域 mixin 各有 `registerXxxCommands(CommandRegistry)`；6 个领域各有 `registerXxxMonthlyHooks(MonthlyPipeline)`；共 12 个月度钩子 id）
│
├── screens/                       # 【UI 层】全部为「壳」：只接线 + 布局，不含业务编排（Batch 10-29 · M3b）
│   ├── start_screen.dart          # 开局选择界面
│   ├── game_screen.dart           # ⭐ 主界面 245 行（Batch 10-29 · M3b 从 709 行瘦身；只做接线：引擎调用 + widgets 组合 + AI loading 态）
│   ├── player_panel_screen.dart   # 玩家详情（含家谱区块，Batch 10-14）
│   ├── npc_panel_screen.dart      # NPC 关系面板（Batch 10-15 新增）
│   ├── family_screen.dart         # 家族面板
│   ├── family_tree_screen.dart    # 家族树可视化（Batch 10-20 新增）
│   ├── map_screen.dart            # 地图
│   ├── events_screen.dart         # 事件面板
│   ├── letters_screen.dart        # 信件面板（Batch 10-29 · M3b 起只 import models/letter.dart，不再 import mixin_letter）
│   ├── systems_screen.dart        # 系统面板
│   └── settings_screen.dart       # 设置/存档
│
├── widgets/                       # 【UI 组件层】Batch 10-29 · M3b 新增（从 game_screen 逐字拆出）
│   └── game/
│       ├── status.dart            # ⭐ StatusBar（顶部状态条：姓名/身份/年龄/地点/生命精力饱食/年月季节）
│       ├── quick.dart             # ⭐ QuickCommand + QuickCommandBar（快捷指令 chip 条）
│       ├── ai_toggle.dart         # ⭐ AiModeToggle（AI 行动模式开关 + loading 转圈）
│       ├── narrative.dart         # ⭐ NarrativeView + AiChoiceCard + PanelEntry（叙事区/AI 选项卡片/面板入口，286 行）
│       ├── nav_grid.dart          # ⭐ NavGrid + NavGridEntry（导航宫格：GridView.count 窄屏 3 列/宽屏 4 列自适应，Batch 10-35 · M5b，99 行）
│       ├── responsive.dart        # ⭐ 响应式工具（Batch 10-36 · M5c，60 行）：Breakpoints 断点（kTablet=600/kDesktop=900）+ AdaptiveFrame 宽屏限宽居中帧（窄屏原样全宽/宽屏 >=600 限宽）
│       └── input.dart             # ⭐ CommandInputBar（指令输入栏 + 发送按钮）
│
│   （改主界面 UI 的正确姿势：**改 widgets/game/ 下的组件**，不要把展示逻辑塞回 game_screen）
│
├── services/                      # 【服务层】外部/IO
│   ├── ai_service.dart            # AiService：AI 叙事/选项生成（Dio，含在场 NPC 多步骤任务模板/家族信息注入，Batch 10-22；事件注入走 event_prompt_filter 预算化，Batch 10-33）
│   ├── event_prompt_filter.dart   # ⭐ 事件 prompt 预算筛选器（Batch 10-33 · M4c-2）：selectEventsForPrompt 按相关度评分（地点+3/季节+2/数值/标记+1）截取预算 12，全量 72→12 token 约降 83%；预算常量在 balance_data.dart
│   ├── ai_config.dart             # AI Key/模型/BaseURL 持久化
│   ├── event_service.dart         # 事件触发/效果/存档（注意：与 provider 双实现）
│   ├── save_service.dart          # ⭐ 存档序列化/导入导出（Batch 10-26 · M1：写入 schemaVersion / 读档先 migrateSave / 坏档隔离 .corrupted）
│   └── save_migration.dart        # ⭐ 存档迁移机制（Batch 10-26 · M1）：kSaveSchemaVersion=1 / kSaveMigrations 迁移表 / migrateSave / readSchemaVersion / UnsupportedSaveVersionException
│
└── utils/                         # 【工具层】纯函数
    ├── labels.dart                # 中文标签（身份/物品分类/技能/配偶身世 spouseOriginLabel，Batch 10-27）
    ├── json_safe.dart             # ⭐ JSON 防御式解析（Batch 10-26 · M1）：safeStr/safeInt/safeBool/safeMap/safeList/safeStrList/safeIntMap/safeBoolMap/safeStringMap/safeObject/safeObjectList/safeEnum/asJsonMap/asInt/asBool
    ├── text_formats.dart          # 文本格式化
    ├── command_alias.dart         # ⭐ 指令别名归一化（物品/技能/NPC 别名，Batch 10-28 · M3a：新增别名写这里，别在 switch 分支写 if-else 链）
    └── narrative_format.dart      # 叙事分段/效果标签/选项编号（Batch 10-12）
```

## 二、关键依赖链（mixin 混入顺序）

```
GameEngine extends GameProviderBase with:
  GameSystemsMixin → GameLifeMixin → GameNpcInteractMixin → GameNpcTaskMixin
  → GameGenerationMixin → GameMarriageMixin → GamePlayMixin → GameLetterMixin
  → GameAdventureMixin → GameCommandsMixin → GameAiMixin
```

**规则**：mixin 的 `on` 子句列出依赖；**被依赖者必须在宿主 with 中排在前面**。
新增 mixin 依赖时同步改 game_engine.dart 的 with 顺序（坑 18）。

| Mixin | on 依赖 | 说明 |
|-------|---------|------|
| GameLifeMixin | GameProviderBase | 生存/物品/贸易/装备/头衔 |
| GameNpcInteractMixin | Base, Life | NPC 交互 |
| GameNpcTaskMixin | Base, Life, NpcInteract | 多步骤任务/期限（Batch 10-18） |
| GameGenerationMixin | Base, Life | 家族继承（Batch 10-14） |
| GameMarriageMixin | Base, Life, Generation | 婚姻/培养/家族树（Batch 10-17） |
| GamePlayMixin | Base, Systems, Life, NpcInteract, Generation | 日常玩法+过月 |
| GameAdventureMixin | Base, Life, NpcInteract, NpcTask | 旅行/探索（探索推进任务，Batch 10-18） |
| GameCommandsMixin | 全部 | 指令解析 |
| GameAiMixin | Base, Systems, Life, Play, Letter | AI 回合：runAiAction（编排，Batch 10-29 · M3b）/ applyAiChoice |

## 三、功能速查表（找「功能」→ 定位「文件:方法」）

| 功能 | 位置 |
|------|------|
| 开局选择/角色生成 | screens/start_screen.dart（buildSetupPlayer/buildSetupProgress） |
| 指令入口（所有指令分发） | mixins/mixin_commands.dart（resolveCommand） |
| 帮助文本 | mixin_commands.dart（_helpText） |
| 状态面板（属性/技能/背包） | mixin_play.dart（formatPlayerPanel） |
| 生存结算（饱食/饥饿/健康） | mixin_life.dart（applyMonthlyLife） |
| 物品使用/背包 | mixin_life.dart（useItem/formatInventoryPanel） |
| 贸易买卖/定价 | mixin_life.dart（buyPriceOf/sellPriceOf/buyItem/sellItem） |
| 地区特产/议价/商队 | mixin_life.dart（tradeSpecialty/negotiate/convoy） |
| 装备系统/战斗值 | mixin_life.dart（equip/unequip/combatPower） |
| 头衔晋升 | mixin_life.dart（checkTitlePromotion/formatTitlePanel）→ 阶梯数据 data/balance_data.dart（titleLadders，Batch 10-30 · M4a 单一真相） |
| **全部数值（生存/活动/头衔/婚姻/世代）** | **data/balance_data.dart（BalanceData，Batch 10-30 · M4a 集中；调平衡只改这一个文件）** |
| 训练/工作/休息/狩猎/贸易 | mixin_play.dart（train/work/rest/hunt/trade） |
| 月度循环 | mixin_play.dart（advanceMonth，含死亡传承 _tryInheritance） |
| 旅行/探索 | mixin_adventure.dart（travel/explore） |
| 信件 | mixin_letter.dart（replyLetter/formatLettersPanel） |
| NPC 关系等级 | mixin_npc_interact.dart（npcRelationLabel/npcRelation） |
| NPC 深度互动 | mixin_npc_interact.dart（npcInteract/npcFavor/maybeNpcStoryEvent） |
| NPC 任务链 | mixin_npc_interact.dart（npcTasks/acceptNpcTask/maybeResolveNpcTask） |
| NPC 深聊 | mixin_npc_interact.dart（npcChat） |
| NPC 关系面板 | mixin_npc_interact.dart（formatNpcRelationPanel） |
| 家谱/立嗣 | mixin_generation.dart（addChild/formatFamilyTree） |
| 继承人/世代传承 | mixin_generation.dart（heirName/advanceGeneration，Batch 10-17 写谱系记录） |
| 求婚/成婚 | mixin_marriage.dart（marry，Batch 10-17） |
| 配偶互动 | mixin_marriage.dart（spouseInteract，恢复精力，Batch 10-17） |
| 婚后每月事件 | mixin_marriage.dart（maybeFamilyEvent，挂 advanceMonth，Batch 10-17） |
| 子女培养 | mixin_marriage.dart（rearChild/tutorChild/sendChildToSchool，Batch 10-17） |
| 多代家族树 | mixin_marriage.dart（formatMultiGenTree，Batch 10-17） |
| NPC 多步骤任务列表 | mixin_npc_task.dart（availableTasksOf/formatNpcTaskPanelV2，Batch 10-18） |
| NPC 接任务 | mixin_npc_task.dart（acceptNpcTaskV2，Batch 10-18） |
| NPC 任务推进/期限 | mixin_npc_task.dart（advanceNpcTasks/checkNpcTaskDeadlines，探索+过月挂载，Batch 10-18） |
| NPC 任务整体进度/剩余月数 | mixin_npc_task.dart（npcTaskOverallRatio/npcTaskRemainingMonths/npcTaskCurrentStepDesc，Batch 10-24） |
| NPC 任务进度面板 | mixin_npc_task.dart（formatNpcTaskProgressPanel，Batch 10-18） |
| 效果应用（事件/AI 共用） | providers/game_state_provider.dart（applyEffects） |
| 游戏结束/血脉断绝 | providers/game_state_provider.dart（endGame）+ mixin_play.dart（_tryInheritance） |
| AI 叙事生成 | services/ai_service.dart（generateNarrative/_buildPrompt） |
| **AI 事件预算筛选** | services/event_prompt_filter.dart（selectEventsForPrompt，Batch 10-33 · M4c-2：地点/季节/数值/标记相关度评分，72→12 token 约降 83%） |
| **AI 回合编排（读配置→拼上下文→请求→装配）** | **mixins/mixin_ai.dart（runAiAction，Batch 10-29 · M3b；返回 `AiTurnResult`）** |
| AI 回合结果对象 | models/ai_turn.dart（AiTurnResult：lines/choices/isSuccess + notConfiguredLine/notStartedLine/**degradedLine**（AI 失败降级提示，Batch 10-34 · M5a）） |
| AI 选项效果落盘 + 推进 | mixin_ai.dart（applyAiChoice） |
| 主界面状态条/快捷条/AI开关/叙事区/输入栏 | widgets/game/status.dart · quick.dart · ai_toggle.dart · narrative.dart · input.dart（Batch 10-29 · M3b） |
| **导航宫格（9 入口 + 窄屏/宽屏自适应）** | widgets/game/nav_grid.dart（NavGrid/NavGridEntry，Batch 10-35 · M5b）+ game_screen.dart（_openNavGrid 弹出） |
| **响应式断点 / 宽屏限宽帧** | widgets/game/responsive.dart（Breakpoints kTablet=600/kDesktop=900 / AdaptiveFrame，Batch 10-36 · M5c）；game_screen 限宽 700、player_panel/family_tree 限宽 900 |
| 信件数据模型 | models/letter.dart（Letter，Batch 10-29 · M3b 从 mixin_letter 迁出） |
| AI 提示词注入在场 NPC | ai_service.dart（_buildPrompt 内 onSiteNpcDesc，Batch 10-22 升级为多步骤任务模板：标题/难度/期限） |
| AI 提示词注入家族信息 | ai_service.dart（_buildPrompt 内 familyDesc：族语/规模/影响力，Batch 10-22） |
| 存档 | services/save_service.dart（Batch 10-26 · M1：metadata 写 schemaVersion / 读档先 migrateSave / 坏档改 .corrupted） |
| 存档迁移/版本校验 | services/save_migration.dart（migrateSave / readSchemaVersion / kSaveSchemaVersion，Batch 10-26 · M1） |
| JSON 防御式解析 | utils/json_safe.dart（safeStr/safeInt/safeObject/safeObjectList/safeEnum 等，Batch 10-26 · M1） |
| 身份/身世中文标签 | utils/labels.dart（identityLabel / spouseOriginLabel，Batch 10-27） |
| 事件历史上限 | providers/game_state_provider.dart（kHistoryLimit / droppedHistoryCount / historySummaryLine，Batch 10-27 · M2） |
| 事件触发/选项 | providers/event_provider.dart |
| 玩家面板 UI | screens/player_panel_screen.dart |
| NPC 面板 UI | screens/npc_panel_screen.dart（Batch 10-15；进行中任务区块进度条/剩余月数/当前步骤，Batch 10-24） |
| 叙事分段渲染 | utils/narrative_format.dart（splitNarrative） |

---

## 四、指令速查表（玩家可输入指令 → 分发方法）

| 指令 | 别名 | 分发到 | 消耗回合 |
|------|------|--------|---------|
| 状态 | status | formatPlayerPanel | 否 |
| 背包 | bag/inventory | formatInventoryPanel | 否 |
| 使用 | use [物品] | useItem | 否 |
| 系统 | systems | formatSystemsPanel | 否 |
| 信 | letter | formatLettersPanel | 否 |
| 回信 | reply [内容] | replyLetter | 否 |
| 旅行 | travel/去 [地点] | travel | 否 |
| 探索 | explore | explore | 是 |
| 训练 | train [技能] | train | 否 |
| 工作 | work | work | 否 |
| 狩猎 | hunt | hunt | 否 |
| 贸易 | trade | trade | 否 |
| 巡游 | 特产/specialty | tradeSpecialty | 否 |
| 议价 | negotiate | negotiate | 否 |
| 商队 | 护送/convoy | convoy | 否 |
| 购买 | 买入/buy [物品] | buyItem | 否 |
| 出售 | 卖出/sell [物品] | sellItem | 否 |
| 行情 | market/价格 | formatMarketPanel | 否 |
| 装备 | equip [物品] | equip | 否 |
| 卸下 | unequip [物品] | unequip | 否 |
| 装备栏 | 装备面板/equipment | formatEquipmentPanel | 否 |
| 头衔 | title | formatTitlePanel | 否 |
| 在场 | npc/人物 | npcListText（mixin_npc_interact，Batch 10-28 起不再是 `_` 私有） | 否 |
| 互动 | 交谈/interact [名字] | npcInteract | 否 |
| 示好 | 送礼/favor [名字] | npcFavor | 否 |
| 深聊 | 聊天/chat [名字] | npcChat（Batch 10-15） | 否 |
| 任务 | 委托/task [名字] | formatNpcTaskPanel / acceptNpcTask | 否 |
| 任务列表 | 任务2/tasks2 | formatNpcTaskPanelV2（Batch 10-18） | 否 |
| 接任务 | accept | acceptNpcTaskV2（Batch 10-18） | 否 |
| 进度 | 任务进度/progress | formatNpcTaskProgressPanel（Batch 10-18） | 否 |
| 关系 | 关系面板/relations | formatNpcRelationPanel（Batch 10-15） | 否 |
| 家谱 | 家族/family | formatFamilyTree（Batch 10-14） | 否 |
| 立嗣 | 添丁/addchild [名字] | addChild（Batch 10-14） | 否 |
| 求婚 | 成婚/marry [名字] | marry（Batch 10-17） | 否 |
| 配偶 | 共处/spouse | spouseInteract（Batch 10-17） | 否 |
| 培养 | rear [孩子] [方向] | rearChild（Batch 10-17） | 否 |
| 督导 | tutor [孩子] | tutorChild（Batch 10-17） | 否 |
| 送学 | school [孩子] | sendChildToSchool（Batch 10-17） | 否 |
| 家族树 | 谱系/tree | formatMultiGenTree（Batch 10-17） | 否 |
| 休息 | rest | rest | 否 |
| 过月 | advance | advanceMonth | 是 |
| 帮助 | help | _helpText | 否 |

## 五、测试文件映射（test/ 52 文件）

| 测试文件 | 覆盖 |
|----------|------|
| batch1_smoke_test | 引擎冒烟（开始新游戏/指令） |
| batch2_*_data_test（5） | 家族/地点/NPC/事件/系统数据 |
| batch3_*_test（5） | 状态/事件/服务/存档/AI |
| batch4_mixin_*_test（5） | 五个基础混入（play/commands/systems/letter/adventure） |
| batch5_ui_test | 6 个界面构建 |
| batch6_start_test | 开局选择 |
| batch7_events_letters_test | 事件/信件面板 |
| batch8_ai_ui_test | AI 模式 UI |
| batch9_utils_test / batch9_ai_deep_test | utils + AI 效果落盘/重试 |
| batch10_life_items_test | 生存/物品（10-1） |
| batch10_2_survival_events_test | 生存轴事件 |
| batch10_3_trade_test / batch10_11_trade_deep_test | 贸易 |
| batch10_4_equip_title_test | 装备/头衔 |
| batch10_5_ai_prompt_test | AI 提示词注入 |
| batch10_6_world_event_test | 月度世界事件 |
| batch10_9_narrative_template_test | 叙事引导模板 |
| batch10_10_compound_events_test | 复合事件 |
| batch10_12_narrative_ui_test | 叙事 UI |
| batch10_13_npc_interact_test | NPC 深度交互（10-13） |
| batch10_14_inheritance_test | 家族继承/多世代（10-14） |
| batch10_15_npc_tasks_test | NPC 任务链/深聊/关系面板（10-15） |
| batch10_17_marriage_test | 婚姻/培养/家族树（10-17，25 用例） |
| batch10_18_npc_task2_test | 多步骤任务/期限/奖励差异化（10-18，15 用例） |
| batch10_19_panel_ai_test | UI 婚姻/任务区块 + AI 注入 + 任务模板扩充（10-19） |
| batch10_20_family_tree_ai_test | 家族树 UI 可视化 + AI 注入世代谱系/头衔晋升（10-20） |
| batch10_21_task_templates_test | 任务模板扩充 12→20（10-21） |
| batch10_22_ai_prompt_inject_test | AI prompt 注入：在场 NPC 任务模板/家族信息/自由民空态（10-22） |
| batch10_23_task_templates_test | 任务模板扩充 20→32：珊莎/艾莉亚/布兰/詹姆/劳勃/史坦尼斯（10-23） |
| batch10_24_task_progress_ui_test | NPC 任务进度 UI 化：totalTurns/整体进度/剩余月数/进度条渲染/契约回归（10-24，10 用例） |
| batch10_25_marriage2_test | 婚姻二轮：离婚/丧偶/配偶谈心/月度事件/婚姻面板（10-25） |
| m1_save_migration_test | **M1 存档契约**（10-26，22 用例）：schemaVersion 写入 / v0→v1 迁移 / 高版本抛异常 / 防御式 fromJson（坏类型/坏列表元素/空 Map）/ 坏档隔离 .corrupted / 旧档加载 / 保存往返 |
| m2_identity_history_test | **M2 状态权威与身份正确性**（10-27，16 用例）：身份/身世中文化 / isIdentity 逐身份命中 / 商人贸易加成实证 / history 环形上限 200 + 丢弃计数 + 存档往返 |
| m3_registry_test | **M3a 架构解耦**（10-28，24 用例）：46 条指令注册完整性 / order 唯一连续 1..46 / 帮助文本与旧版逐字一致 / 重复别名与重复 id 记录 / 12 个管线 id 的 phase×order×outputOrder 映射 / 时钟恰好推进一次 / 执行序与文本序分离 / **自注册演示（新增「钓鱼」指令不改分发器即可分发）** |
| m3b_ui_decoupling_test | **M3b UI 收口**（10-29，14 用例）：runAiAction 四条分支（未开局 / 未配置 Key / HTTP 400 失败 / 成功无选项 / 成功带选项）/ 编排不改世界状态 / AiTurnResult 常量与默认值 / **分层约束（遍历 lib/screens 断言无 `mixins/` import + mixin_letter 不再含 `class Letter`）** / 拆分后主界面（标题·状态条·AI 开关·快捷 chip 可点）与信件面板（空态 + 卡片标题）契约不回归 |
| m4_balance_test | **M4a 数值配置集中**（10-30，15 用例）：10 身份阶梯全覆盖 / 每条阶梯升序无重复 / 全档位边界（门槛 / 门槛-1 / 下一档门槛）/ 登顶返回 0 / 未知身份空阶梯 / 引擎 checkTitlePromotion 与配置逐档一致 / 面板门槛与配置一致（10 身份 × 11 档声望）/ 不降级 / mixin 常量转发一致 / 月度生存结算按配置生效 |
| m4_balance_sim_test | **M4b 资源仿真**（10-31，5 用例）：headless 驱动完整 GameEngine 跑 120 个月——hunt+rest+work 主动生存不 game over、金币有界（>0 且 <5000）、健康/精力/饱食不枯竭 / 主动 vs 被动对比（被动必死验证生存约束）/ 固定策略 160 个月曲线（金币非负有界 + 时间年龄正确推进）/ 数值引用与 balance_data 一致（开局 hunger 对齐真实开局 60） |
| m4c1_content_sync_test | **M4c-1 内容 JSON 资产对账**（10-32，8 用例）：7 域 JSON 资产存在且可解析 / 每域 JSON id 集合 == Dart 常量 id 集合 / 关键文本非空 / 跨域引用（npc.familyId→families、task.npcId→npcs）/ 每条事件 ≥2 选项且至少一个无条件 |
| **m4c2_event_prompt_filter_test** | **M4c-2 事件 prompt 预算筛选**（10-33，8 用例）：预算截断（≤12 全量 / >12 截断）/ 相关度排序（地点/季节/数值/标记命中排前）/ 真实事件库契约（临冬城·冬 event_frozen_lake 双命中第一 / 夏季让位） |
| **m5_experience_test** | **M5 体验层**（10-34/35，10 用例）：AI 失败降级（失败行+降级提示行 / 本地指令续玩 / 降级常量唯一）/ 长会话叙事（200 条渲染 / 200 条滚动到底 / 1000 条不崩 / GameScreen 冒烟）/ 导航宫格（窄屏 3 列 / 宽屏 4 列 / AppBar 宫格按钮弹出 9 入口） |
| **m5_responsive_test** | **M5 响应式适配**（10-36，6 用例）：AdaptiveFrame 窄屏原样全宽不包 Center / 宽屏限宽可配置 / GameScreen 宽屏状态条≤700 + 契约不回归 / 窄屏状态条全宽 / PlayerPanelScreen·FamilyTreeScreen 宽屏 ListView 宽 900 |

> 坑：**扩充数据（事件/NPC）时，必须同步更新所有「总量/类型分布」断言**
> （grep `allEvents.length` / `eventsByType(...).length`）。
> **坑（M4c-1）：改 lib/data/*.dart 数据后必须重跑 `python3 scripts/dart_content_extract.py` 再提交，
> 否则 CI 的 Content sync check 步骤直接红。**

## 六、已踩坑速查（详细原因见 HANDOVER 第三、四节）

- **测试用 `||` 组合 Matcher** → non_bool_operand，改用 `anyOf`（坑 18）
- **mixin 增 on 依赖** → 必须同步宿主 with 顺序（被依赖在前）+ import（坑 18）
- **setFlag 只存 bool** → 数值/字符串存实例字段或模型字段（坑 16）
- **私有成员跨 mixin 不可见** → 新计数用独立前缀自建（坑 16）
- **toJson/fromJson 字段必须对齐** → 新增字段给默认值 + fromJson `??` 兜底（坑 8/12）
- **Dio mock 捕获** → 用 List 容器而非 record 值拷贝（坑 14）
- **枚举带方法体** → 最后一个枚举成员必须 `;` 结尾（坑 20）
- **行为 getter 放枚举不放数据类** → SpouseOrigin 承载开销/声望/嫁妆/子女上限（坑 20）
- **测试避免对满值做增量断言** → 先构造可增长初始值（坑 20）
- **局部变量勿与基类 getter 重名** → progress 遮蔽，改名 taskProgress（坑 21）
- **期限断言注意跨年边界** → 用 _addMonths 推算，勿臆测 +1 年（坑 21）
- **本地无 Flutter** → 靠 GitHub Actions CI 验证；括号用 python 脚本检查（**当前 proot 下 SDK 完全不可执行**，坑 29）
- **gitdata_push 多 commit 极慢** → 必须后台跑 + 轮询日志（坑 10）；网络断了可重跑（幂等）；单 commit 也要 8-10 分钟（坑 29）
- **Map.from 浅拷贝** → 嵌套 Map 仍与入参共享，"不改入参"的纯函数须逐层拷贝（坑 29）
- **try/catch 后不类型提升** → 用 final 局部变量承接，别在 catch 里 return 后用 `!`（坑 29）
- **审查报告先验证再执行** → 时间推进/身份匹配两条为误判，见坑 30
- **状态载体加字段** → 6 处清单：构造器初始化列表/字段声明/startNewGame/applyState/toJson/fromJson（坑 30）
- **列表截断收口唯一入口** → `_appendHistory` 内部截断，fromJson 预截断并记账（坑 30）
- **月度钩子顺序是「两序一种子」** → `MonthlyPhase`（advanceTime 前/后）× `order`（执行序）× `outputOrder`（文本序）三轴解耦，照抄旧顺序会改随机结果（坑 32）
- **搬迁长文案/巨型 switch 必须「生成器 + 逐字比对」** → git 取旧值 → 脚本写入 → 脚本断言一致，禁止手打（坑 32）
- **`git checkout <file>` 会丢同文件手工改动** → 整块用生成脚本重建（坑 32）
- **ai_service.dart 括号不平衡是预存误报** → git HEAD 上同样报同一数字，别再排查（坑 32）
- **新增玩法只加 1 mixin + 1 行 with + 自注册指令 + 月度 hook** → 不得改 mixin_commands/mixin_play/game_engine 内部逻辑（坑 33）
- **搬迁长文案/巨型组件必须「生成器 + 逐字比对」** → git 取旧值 → 脚本切块搬迁 → 脚本断言去私有化后逐字相等，禁止手打（坑 32 的组件版，本轮 M3b 实测有效）
- **改共享行为不要只改调用方** → 本轮 3 个缺陷：未用 import（CI 红）、shared_preferences mock 键前缀靠猜（静默假绿）、UI 断言文本写错（假绿）——**共享层要同时给注入点（`runAiAction(service:)`）与可断言常量**
- **校验脚本本身要有回归** → `scripts/check_brackets_selftest.py` 17 条合成用例（raw string / 三引号 / 嵌套插值 / 嵌套块注释 / 转义），改脚本先跑自检
- **SharedPreferences mock 别猜键名** → 用 `AiConfig().save()` 写入，键前缀猜错会静默走「未配置」分支变成假绿（坑 34）
- **HANDOVER.md 已 gitignore** → 只本地更新；README 正常推送

## 七、文件写入约定（复用 HANDOVER 第二节）

1. 不要用 heredoc 传中文（shell 破坏 UTF-8）→ 用 create_file/edit_file 工具
2. 单文件不要太大（用户偏好，便于维护）；mixin_life 已 769 行，新功能优先拆新文件
   （Batch 10-17/10-18 新功能全部拆独立文件：mixin_marriage 245 行 / mixin_npc_task 221 行）
3. 每次改完先括号检查（python 脚本），再 commit → push → CI → 绿后更新 HANDOVER + README
4. **上下文预算 7 条硬规则**（分段写 / 先 wc -l 再读 / 短命令+脚本 / grep 重定向 / 不贴 PAT / CI 单次长 sleep / 回显黑名单）见 HANDOVER 第二节「工具使用」，本节不重复

---
*文档版本：v2.2（新增 responsive.dart 组件 + m5_responsive_test 映射 + M5c 响应式速查）· 最后更新：2026-10-01*
