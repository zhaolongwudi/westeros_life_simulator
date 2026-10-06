# 维斯特洛人生模拟器 · 代码地图（CODE_MAP）
> **本文件是代码结构导航索引**（v5.30 · Batch 10-113/114 同步）：下个对话/工具接手时，先读 HANDOVER.md 了解进度，
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
├── app.dart                       # 根组件：HomeScreen → StartScreen → GameScreen（Batch 10-105 起 home 改 HomeScreen 主菜单）
├── game_engine.dart               # ⭐ 引擎宿主：组合全部 mixin（含混入顺序）
│
├── core/                           # 【框架层】纯 Dart，无状态层依赖（Batch 10-28 · M3a 新增）
│   ├── command_registry.dart      # ⭐ CommandSpec/CommandRegistry：指令注册表（别名分发/帮助生成/重复别名记录），132 行
│   ├── monthly_pipeline.dart      # ⭐ MonthlyPhase/MonthlyHookSpec/MonthlyPipeline：月度结算管线（phase × order × outputOrder 三轴，runMonth 注入 advanceClock），129 行
│   └── event_trigger_eval.dart    # ⭐ 事件触发门槛判定单一真相（Batch 10-104）：`eventTriggersSatisfied` 纯函数承载全部 17 类门槛键 + 3 前缀判定；`seasonMatches` 支持 'any'（10-103 修复 season:any 恒 false）；未知键放行 / season null 不放行（fail-closed）/ 数值 tryParse 防脏存档崩溃；`EventProvider.canTrigger` 与 `EventService.checkTriggerConditions` 均委托本文件（10-104 双通道收口，防第五次漂移），130 行
│
├── data/                          # 【静态数据层】世界常量数据
│   ├── family_data.dart           # 27 家族
│   ├── location_data.dart         # 68 地点
│   ├── npc_data.dart              # 38 NPC（含 Batch 10-15 任务链 tasks/mood；Batch 10-54 新增约恩·罗伊斯/布蕾妮·塔斯）
│   ├── event_data.dart            # 72 事件（60 + 12 复合）
│   ├── system_data.dart           # 74 系统
│   ├── item_data.dart             # 34 物品
│   ├── narrative_templates.dart   # 差异化叙事引导（10 身份/12 区域/5 季节；seasonWorldTrend 季节世界动向 Batch 10-50；regionWorldTrend 地区风土人情 Batch 10-52；seasonFarmTrend 时节农事 Batch 10-56；localMarketTrend 本地集市行情 Batch 10-58；locationLore 所在地名人轶事·历史典故 Batch 10-69）
│   ├── balance_data.dart           # ⭐ 数值配置集中（初始值/生存消耗/每日上限/头衔阶梯/活动经济/婚姻与世代阈值，Batch 10-30 · M4a；**好感度护栏 kRelationClamp=100**，Batch 10-90；**技能/属性键白名单 kPlayerSkillKeys(13)/kPlayerAttributeKeys(6)**，Batch 10-92，键集与 `labels` 标签表同源；**日常经济收口 17 常量：workEnergyCost/huntEnergyCost/tradeEnergyCost/workBaseIncome(10 身份)/workSkillBonusDivisor/tradeMerchantBase/tradeCommonerBase/tradeSpeechGain/tradeProfitVariance/restHungerGain/huntRewardPerDanger**，Batch 10-111/112；**NPC 交互经济收口 24 常量：npcChatGainBase/Variance、npcFavorCostBase/Divisor/Min/Max、escortFeeBase/Variance、merchantShareBase/Variance、assassinFeeBase/Variance、taskRewardBase/taskRewardRelation/taskAcceptRelation、reputationSmallGain、wildlingGiftGold、priestHealHealth、secretRelationGain、chatRelationGain、nobleReferReputation、supernaturalReputationGain、scholarTeachChance**，Batch 10-113；**冒险/旅行经济收口 14 常量：travelCostBase/Variance、exploreEnergyCost、exploreGoldBase/DangerMult/VarianceBase、banditLossBase/DangerMult、beastGainBase/DangerMult、beastHungerGain、beastInjuryHealth、merchantProfitBase/Variance**，Batch 10-114；AI prompt 各段预算常量亦收口于此 Batch 10-82~88；无 import 依赖的叶子模块）
│   └── npc_task_data.dart         # NPC 多步骤任务模板（72 个：艾德/提利昂/丹妮莉丝/琼恩/瑟曦/奥莲娜/凯特琳/罗柏/玛格丽/泰温/珊莎/艾莉亚/布兰/詹姆/劳勃/史坦尼斯/奥柏伦/巴隆/雅拉/瑞肯/洛拉斯/卓戈/卢斯·波顿/拉姆斯·波顿/席恩/霍斯特/约恩·罗伊斯/布蕾妮·塔斯/杰奥·莫尔蒙/艾德慕·徒利/瓦德·佛雷/莱莎·艾林/乔佛瑞/托曼/琼恩·艾林/弥赛拉/雷加/韦赛里斯，Batch 10-18 起逐步扩充，10-39 扩至 44，10-41 协作任务扩至 48，10-44 协作任务扩至 52（君临×2/高庭/派克城），10-47 扩至 54（泰温+艾莉亚各 +1 solo），10-53 扩至 58（卢斯·波顿/拉姆斯·波顿/席恩/霍斯特各 +1 solo），10-54 扩至 61（约恩·罗伊斯/布蕾妮·塔斯各 +1 solo + 约恩×琼恩·艾林协作），10-55 扩至 67（杰奥/艾德慕/瓦德/莱莎/乔佛瑞/托曼各 +1 solo），10-61 扩至 71（琼恩·艾林/弥赛拉/雷加/韦赛里斯各 +1 solo），10-62 扩至 72（琼恩·艾林×莱莎·艾林谷地协作）；协作任务含 coNpcId）
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
│   ├── mixin_npc_task.dart        # ⭐ NPC 任务链二轮：多步骤任务/期限系统/奖励差异化（Batch 10-18，221 行）+ 进度 UI 化（10-24）+ 限时奖惩（10-40）+ 多 NPC 协作任务 coNpcId（10-41）+ 任务放弃与失败反馈（10-42）
│   ├── mixin_commands.dart        # ⭐ 指令分发器（Batch 10-28 · M3a：401→100 行，只「拉齐 10 个领域自注册 + 按别名分发 + 帮助/未知指令」；**新增指令请去对应领域 mixin 的 registerXxxCommands**，不要再改这里）
│   └── mixin_ai.dart              # AI 回合混入（applyAiChoice）
│
│   （Batch 10-28 · M3a 自注册约定：9 个领域 mixin 各有 `registerXxxCommands(CommandRegistry)`；6 个领域各有 `registerXxxMonthlyHooks(MonthlyPipeline)`；共 12 个月度钩子 id）
│
├── screens/                       # 【UI 层】全部为「壳」：只接线 + 布局，不含业务编排（Batch 10-29 · M3b）
│   ├── home_screen.dart           # ⭐ 开屏首页/主菜单（Batch 10-105 新增）：开始新游戏/继续游戏（读最近存档）/设置（AI/存档）三按钮 + 铁王座饰头；`MaterialApp.home` 指向此处，每次冷启动先进主菜单
│   ├── start_screen.dart          # 开局选择界面（Batch 10-105 重写为 7 步 Stepper 分步向导：姓名/身份/家族/出生地/时代/出生季节/确认；底部固定操作栏；Stepper 只渲染当前步 content 防 overflow）
│   ├── game_screen.dart           # ⭐ 主界面 245 行（Batch 10-29 · M3b 从 709 行瘦身；只做接线：引擎调用 + widgets 组合 + AI loading 态）
│   ├── player_panel_screen.dart   # 玩家详情（含家谱区块，Batch 10-14）
│   ├── npc_panel_screen.dart      # NPC 关系面板（Batch 10-15 新增）
│   ├── family_screen.dart         # 家族面板
│   ├── family_tree_screen.dart    # 家族树可视化（Batch 10-20 新增；历代家主详情弹层 Batch 10-46；谱系继承连线 Batch 10-49；横版继承关系图 Batch 10-51；当代支脉横版图 Batch 10-57；继承顺位卡片 Batch 10-109；当代支脉子女培养档案 Batch 10-110）
│   ├── map_screen.dart            # 地图
│   ├── events_screen.dart         # 事件面板
│   ├── letters_screen.dart        # 信件面板（Batch 10-29 · M3b 起只 import models/letter.dart，不再 import mixin_letter）
│   ├── systems_screen.dart        # 系统面板
│   └── settings_screen.dart       # 设置/存档
│
├── widgets/                       # 【UI 组件层】Batch 10-29 · M3b 新增（从 game_screen 逐字拆出）
│   ├── theme/
│   │   └── ornate.dart            # ⭐ 公共装饰组件库 452 行（Batch 10-60 新增）：ParchmentBackground（纯绘制羊皮纸纹理）/ GildedCard（金边卡片，Card 实现，兼容 find.byType(Card)）/ OrnateHeader（金线+菱形饰章标题）/ StatPill（状态胶囊）/ WesterosDivider / WesterosScaffold / SectionDivider
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
├── theme/                         # 【主题基建】Batch 10-60 新增（UI 重造）
│   └── westeros_theme.dart        # ⭐ 「铁与火 · 羊皮纸与黄金」主题：bark* 五层深棕 + 兰尼斯特金 gold* + 史塔克钢 + 坦格利安血红 + 羊皮纸米色，serif 标题字体族；金边卡片/AppBar 底部金线/金色进度条等 17 类 ThemeData 覆盖；色板常量可被测试断言
│
├── services/                      # 【服务层】外部/IO
│   ├── ai_service.dart            # AiService：AI 叙事/选项生成（Dio，含在场 NPC 多步骤任务模板/家族信息注入，Batch 10-22；事件注入走 event_prompt_filter 预算化，Batch 10-33；时节农事注入 Batch 10-56；本地集市行情注入 Batch 10-58；**多 Key 轮换重试 Batch 10-59**；**连通性测试 testConnection + 自动识别模型 fetchModels Batch 10-106**；**fetchModels 多形态响应兼容 Batch 10-107**）
│   ├── event_prompt_filter.dart   # ⭐ 事件 prompt 预算筛选器（Batch 10-33 · M4c-2）：selectEventsForPrompt 按相关度评分（地点+3/季节+2/数值/标记+1）截取预算 12，全量 72→12 token 约降 83%；预算常量在 balance_data.dart
│   ├── ai_config.dart             # AI 配置：多 Key 池（JSON 数组 `ai_api_keys`）/模型/BaseURL/提供商（Batch 10-59 重写；双向同步旧单 key 键 `ai_api_key`；resolvedModel/resolvedBaseUrl 空值回落 provider 默认；**customModels 自定义模型列表持久化 `ai_custom_models` + allModels 去重保序 getter Batch 10-106**）
│   ├── ai_provider_defaults.dart  # ⭐ AI 提供商预设（Batch 10-59 新增）：sensenova/atria/deepseek 3 家，含默认模型/模型候选/baseUrl（chatBaseUrl 自动拼 /v1）；providerDefaultsOf 单一真相对齐
│   ├── event_service.dart         # 事件触发/效果/存档（注意：与 provider 双实现）
│   ├── save_service.dart          # ⭐ 存档序列化/导入导出（Batch 10-26 · M1：写入 schemaVersion / 读档先 migrateSave / 坏档隔离 .corrupted）
│   └── save_migration.dart        # ⭐ 存档迁移机制（Batch 10-26 · M1）：kSaveSchemaVersion=1 / kSaveMigrations 迁移表 / migrateSave / readSchemaVersion / UnsupportedSaveVersionException
│
└── utils/                         # 【工具层】纯函数
    ├── labels.dart                # 中文标签（身份/物品分类/技能/配偶身世 spouseOriginLabel，Batch 10-27；M6 契约：全项目文案唯一集中层）
    ├── command_sanitizer.dart     # ⭐ 指令输入防护（Batch 10-37 · M6a）：kMaxCommandLength=80 超长截断 + isCommandNoise 纯符号/空白噪声判定；resolveCommand 入口接入，AI 模式描述性输入不走防护
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
| 指令入口（所有指令分发） | mixins/mixin_commands.dart（resolveCommand，入口护栏：超长截断+纯符号/空白兜底，Batch 10-37 · M6a） |
| 指令输入防护 | utils/command_sanitizer.dart（sanitizeCommand 截断 / isCommandNoise 噪声判定，Batch 10-37 · M6a） |
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
| **历代家主详情弹层** | screens/family_tree_screen.dart（`_GenerationNode` 点击 InkWell → `_showAncestorDetail` 底部弹层：世代徽章/姓名/头衔/在位/成就/传承寄语 + 关闭按钮，Batch 10-46） |
| **谱系继承连线** | screens/family_tree_screen.dart（`_InheritanceLink`：历代家主节点间继承箭头连线——非末代「继承」/末代「传至当代」，Batch 10-49） |
| **金饰化主题基建 / 公共装饰组件** | theme/westeros_theme.dart（「铁与火 · 羊皮纸与黄金」17 类主题，Batch 10-60）· widgets/theme/ornate.dart（ParchmentBackground/GildedCard/OrnateHeader/StatPill/WesterosDivider/WesterosScaffold/SectionDivider，Batch 10-60） |
| **横版继承关系图（谱系概览）** | screens/family_tree_screen.dart（`_LineageOverview`/`_LineageNode`/`_LineageArrow`：「继承谱系」历代家主迷你卡片横向串联至当代徽章，Batch 10-51） |
| **当代支脉横版图** | screens/family_tree_screen.dart（`_CurrentFamilyOverview`：当代家主 + 配偶（偶徽章）+ 子女（子徽章）横向血脉快照，箭头指示亲缘方向；有配偶或子女时显示；`_LineageNode` 增 `badge` 参数，Batch 10-57） |
| **继承顺位卡片** | screens/family_tree_screen.dart（`_InheritanceOrderCard`：按出生顺序列出子女顺位（第一/第二顺位）+ `_rearingBrief` 培养档案短述 + 继承人「👑 继承人」徽章（heirName：长子在世→长子，childDead 跳过），Batch 10-109） |
| **当代支脉子女培养档案** | screens/family_tree_screen.dart（`_CurrentFamilyOverview` 子女 `_LineageNode` 增 `subtitle: _rearingBrief`；`_rearingBrief` 顶层函数与 `_childRearingText` 同源，去姓名前缀，Batch 10-110） |
| NPC 多步骤任务列表 | mixin_npc_task.dart（availableTasksOf/formatNpcTaskPanelV2，Batch 10-18） |
| NPC 接任务 | mixin_npc_task.dart（acceptNpcTaskV2，Batch 10-18） |
| NPC 任务推进/期限 | mixin_npc_task.dart（advanceNpcTasks/checkNpcTaskDeadlines，探索+过月挂载，Batch 10-18；按时完成关系加成 + 逾期扣声望关系惩罚，Batch 10-40） |
| **多 NPC 协作任务** | mixin_npc_task.dart（availableTasksOf 协作过滤/coNpcNotAvailableReason 拒绝原因/acceptNpcTaskV2 双关系接取/advanceNpcTasks 双关系结算，Batch 10-41；**Batch 10-44 扩充至 8 个协作模板**：新增君临×2（瑟曦×詹姆彻查御林铁卫的叛徒/提利昂×瑟曦追查王后身边的奸细）+ 高庭（奥莲娜×玛格丽为玛格丽操办玫瑰舞会）+ 派克城（巴隆×雅拉清剿铁群岛海盗）） |
| **放弃任务** | mixin_npc_task.dart（abandonNpcTask 按标题匹配置 abandoned/发布方关系 -2 协作同伴也 -2 无声望惩罚；指令「放弃/quit」order 47，Batch 10-42） |
| **逾期失败增强** | mixin_npc_task.dart（checkNpcTaskDeadlines 协作逾期同伴 -3 + _deadlineFailHint 五类任务类型差异化失败描述，Batch 10-42） |
| NPC 任务整体进度/剩余月数 | mixin_npc_task.dart（npcTaskOverallRatio/npcTaskRemainingMonths/npcTaskCurrentStepDesc，Batch 10-24） |
| NPC 任务进度面板 | mixin_npc_task.dart（formatNpcTaskProgressPanel，Batch 10-18） |
| 效果应用（事件/AI 共用） | providers/game_state_provider.dart（applyEffects） |
| 游戏结束/血脉断绝 | providers/game_state_provider.dart（endGame）+ mixin_play.dart（_tryInheritance） |
| AI 叙事生成 | services/ai_service.dart（generateNarrative/_buildPrompt） |
| **AI 注入装备战力** | services/ai_service.dart（`combatPowerOf` 纯函数 + `已装备` 明细 + `战斗值` 行，Batch 10-43） |
| **AI 事件预算筛选** | services/event_prompt_filter.dart（selectEventsForPrompt，Batch 10-33 · M4c-2：地点/季节/数值/标记相关度评分，72→12 token 约降 83%） |
| **AI 注入本月世界局势** | services/ai_service.dart（`_buildPrompt` 内 `worldNewsDesc`：从预算筛选后事件取 top2 作「本月世界局势」段落 + 空态兜底「（本月暂无重大传闻）」，Batch 10-45） |
| **AI 注入头衔晋升趋势** | services/ai_service.dart（`_buildPrompt` 内 `titleProgressDesc`：balance_data 单一真相量化「距下一档「伯爵」还差 5 声望」+ 阶梯总览「爵士(40) → 伯爵(60) → 大领主(80)」/ 已登顶兜底，Batch 10-48） |
| **AI 注入季节世界动向** | services/ai_service.dart（`_buildPrompt` 内 `seasonTrendDesc`：五季世界宏观动向段落，与玩家视角季节引导互补，Batch 10-50） |
| **AI 注入地区风土人情** | services/ai_service.dart（`_buildPrompt` 内 `regionTrendDesc`：regionWorldTrend 区域宏观风土人情段落——季节世界动向之后、可用事件之前，与季节世界动向形成「时节 × 地域」双轴，Batch 10-52） |
| **AI 注入时节农事** | services/ai_service.dart（`_buildPrompt` 内 `farmTrendDesc`：seasonFarmTrend(season, region) 按「季节 × 区域」返回生计实事段落——地区风土人情之后、可用事件之前，与季节世界动向/地区风土人情形成「时节 × 地域 × 生计」三轴，Batch 10-56） |
| **AI 注入本地集市行情** | services/ai_service.dart（`_buildPrompt` 内 `marketTrendDesc`：localMarketTrend(season, region) 按「季节 × 区域」返回集市行情风向段落——时节农事之后、可用事件之前，与季节世界动向/地区风土人情/时节农事形成「时节 × 地域 × 生计 × 集市」四轴，Batch 10-58） |
| **AI 注入所在地名人轶事** | services/ai_service.dart（`_buildPrompt` 内 `loreDesc`：locationLore(region, locationId) 按知名地点/区域返回历史典故段落——本地集市行情之后、可用事件之前，与地区风土人情等形成「地理 × 生计 × 集市 × 历史」四轴，Batch 10-69） |
| **AI 注入局势关联 NPC 立场** | services/ai_service.dart（`_buildPrompt` 内 `stanceDesc`：`_worldStanceDesc`/`_npcStanceFor`——按 top2 世界事件 × 玩家关系 NPC（前 3 个）经家族对外关系网络（family.relations 敌友阈值 ±20）推导「谁站在哪边」，本月世界局势之后、季节世界动向之前，Batch 10-70 + 10-72 动态化：玩家与 NPC 关系绝对值 ≥20 时追加「因与你交好…倾向考虑你的立场 / 因与你结怨…可能与你对立」，关系平平省略） |
| **AI 注入家族谱系成员** | services/ai_service.dart（`_buildPrompt` 内 `familyMembersDesc`：按玩家家族取在世同族 NPC（名字/身份/所在地/与玩家的关系，最多 6 个防膨胀）作「- 家族成员：」行，自由民兜底「自由民，无家族可依附」/ 无在世同族兜底，Batch 10-71） |
| **AI 注入 NPC 间关系网络** | services/ai_service.dart（`_buildPrompt` 内 `npcNetworkDesc` + `_npcNetworkDesc` 纯函数：取玩家关系 NPC（前 3 个，按关系值绝对值降序）的 `npc.relations` 映射，输出「A ↔ B（关系 N）：敌对/友善/中立」清单（双向取强、阈值 ±20）——让 AI 知道玩家社交圈内部的人际张力，Batch 10-73） |
| **AI 注入家族在权力网络中的位置** | services/ai_service.dart（`_buildPrompt` 内 `familyPowerDesc` + `_familyPowerDesc` 纯函数：玩家家族名 + 玩家在家角色（姓氏与家族同名=家主，否则成员）+ 家族对外格局（family.relations 阈值 ±20 分宿敌/盟友/中立）；自由民兜底「自由民，无家族，不受任何家族约束」，Batch 10-74） |
| **AI 注入玩家家族继承顺位** | services/ai_service.dart（`_buildPrompt` 内 `inheritanceDesc` + `_inheritanceDesc` 纯函数：按 `player.children` 出生顺序标注第一~第五顺位，命中 `player.childRearing` 的子女附加培养方向/进修中/已督导标记，最多列 4 人 + 「另有 N 名子女不列顺位」尾注；无子嗣兜底「尚无子嗣，继承悬而未决，旁支虎视眈眈」/ 自由民兜底「无继承顺位」；紧跟「家族在权力网络中的位置」之后，Batch 10-75） |
| **AI 注入当地势力与玩家立场** | services/ai_service.dart（`_buildPrompt` 内 `localPowerDesc` + `_localPowerDesc` 纯函数：读 `location.governorId`（69 处地点数据赋值）解析治主 NPC → 输出「{地点}由{治主}（{身份}·{家族}家族）治下：{自家领地/盟友/敌对/关系平平/无明确恩怨}；你与治主{交好/交恶/关系平常/尚无直接交集}」；无治主地点兜底「无明确治主（名义上直属领地，地方豪强代管）」/ 自由民兜底「不受任何家族旗号庇护」；紧随「当前地点」段落之后，Batch 10-76） |
| **AI 注入与你相关的可用事件** | services/ai_service.dart（`_buildPrompt` 内 `relevantEventsDesc` + `_relevantEventsDesc` 纯函数 + 顶层常量 `_identityEventKeywords`（10 身份 × 中文命中词）：从预算内 `selectedEvents` 再筛一遍——事件名/描述/tags 命中玩家家族名或 family id → 关联「家族·X」；命中玩家身份关键词（贵族/骑士/商人/学士…）→ 关联「身份·X」；输出「· {事件名}（关联：家族·史塔克）」清单最多 3 条，无命中兜底「（本月无直接牵涉你家族/身份的大事）」；作「- 与你相关的可用事件：」行紧跟可用事件清单，Batch 10-77。注意：`playerFamily` 解析已上移到 `_buildPrompt` 开头供本行与 10-78 共用） |
| **AI 注入事件利害标注** | services/ai_service.dart（`_buildPrompt` 内 `eventsDesc` 构造逐条追加「（对你而言：xxx）」+ `_eventStanceDesc` 纯函数：按 `EventType`（family/war/economic/religious/political/magical/supernatural/adventure/daily）× 玩家身份/家族给出利害倾向——家族类+有家族→「本家族兴衰系于你一身」/战争→「战火燎原」/经济+商人→「商人身家随市况起落」/宗教+神职学士→「你的立场将被教门审视」/政治+有家族→「你的家族表态将影响结果」等，简短短语不展开；自由民走「旁人的家事，与你无涉」分支，Batch 10-78） |
| **AI 注入当前地点详情** | services/ai_service.dart（`_buildPrompt` 内 `locationDesc`：当前地点名/类型/危险度分级（安全/一般/危险/极度危险）/人口/特色/相连地点名/描述——玩家状态从「地点：location_winterfell（北境）」升级为完整地理实境，Batch 10-63） |
| **AI 注入关系 NPC 身份** | services/ai_service.dart（`_buildPrompt` 内 `relationDesc`：关系列表从「NPC ID: 好感度」升级为「名字（身份·家族·所在地）: 好感度」，未知 NPC 回退原格式，Batch 10-64） |
| **AI 注入在场 NPC 性格/目标** | services/ai_service.dart（`_buildPrompt` 内 `onSiteNpcDesc`：在场 NPC 附加「性格」（personality 前 2 条）与「目标」（goals 前 2 条）——AI 之前只知道名字/关系/心情，人物叙事缺乏深度，Batch 10-65） |
| **AI 注入 NPC 技能与信仰** | services/ai_service.dart（`_buildPrompt` 内 `_onSiteNpcDesc` 输出 `，skills：…，信仰：…` + `_skillDesc` 静态纯函数（按值降序取前 2 项，超出附「另有 N 项」）+ `utils/labels.dart` 的 `skillLabel` 文案层（sword→剑术/leadership→统率/politics→权谋 等键位 + 未知键原样兜底）——`npc.skills`/`npc.faith` 全库 38 NPC 全有值却从未进入 prompt，Batch 10-79；10-81 补齐玩家侧键 riding/speech/alchemy） |
| **AI 注入玩家技能/属性（中文标签化）** | services/ai_service.dart（`_buildPrompt` 内 `skillDesc`/`attributeDesc` 走 `_kvDesc` 静态纯函数（`Map<String,int>` + 标签函数参数 → 「剑术 3、弓术 2、骑术 3、口才 2、炼金 0」）+ `utils/labels.dart` 的 `attributeLabel`（strength→力量/agility→敏捷/intelligence→智识/charisma→魅力/willpower→意志/perception→感知）——原两行直接插裸字典 `{sword: 3, ...}`，AI 看到英文键名 + Dart Map 字面量；键数数值全量保留，仅键名中文化，Batch 10-81） |
| **AI 在场 NPC 人数预算** | services/ai_service.dart（`_onSiteNpcDesc` 按 `BalanceData.kAiPromptOnSiteNpcBudget`（=5）`take()` 截断，超出附「另有 N 位在场未展开」尾注——实测临冬城 8 位 NPC 同场（艾德/凯特琳/罗柏/珊莎/艾莉亚/布兰/瑞肯/琼恩），每位带关系+心情+性格+目标+技能+信仰+任务清单，全量单行 700+ 字；截断值 5 覆盖全部既有测试依赖的前 3 位）+ `BalanceData.kAiPromptNpcNetworkBudget`（=3）收口 `_npcNetworkDesc` 的硬编码 `take(3)`，Batch 10-82（预算常量与 M4c-2 `kAiPromptEventBudget` 同处 `balance_data.dart`） |
| **AI 注入邻近地点与路途风险** | services/ai_service.dart（`_buildPrompt` 内新增「- 邻近地点与路途风险：」行 + `_nearbyRiskDesc` 静态纯函数（`family`,`location` 两参）：逐个相邻地点输出「地点名（危险度分级，沿用 10-63 阈值 ≤2 安全/≤5 一般/≤8 危险/其余 极度危险，治主：governorId→NPC 名或「无明确治主」，与玩家家族敌友：自家领地/盟友领地/敌对领地/关系平平，复用 10-76 阈值 ±20）」，最多 4 条防膨胀 + 超出尾注「另有 N 处未列」；`connectedTo`（69 处）此前仅以「可前往：白港、巴隆镇」地名形式进入 prompt（10-63），AI 不知道这条路通往敌国，Batch 10-80） |
| **AI 注入家族对外关系** | services/ai_service.dart（`_buildPrompt` 内 `familyDesc`：家族附加「对外关系」网络——family.relations 映射家族名 + 敌对/中立/友善立场（阈值 ±20），AI 政治叙事有立场支撑，Batch 10-66） |
| **AI 玩家关系段人数预算** | services/ai_service.dart（`_buildPrompt` 内 `relationDesc`：按 `\|关系值\|` 降序取前 `BalanceData.kAiPromptRelationBudget`（=8）位，同值以 NPC id 作次级键（Dart `List.sort` 不稳定，与 10-33 事件筛选同因），超出附「另有 N 人有交情」尾注；输出为 `relationDesc + relationTail` 拼成的 `relationFullDesc`——`player.relations` 是长会话里唯一**无上限累积**的 map（NPC 交互/任务完成/选项 effects 的 `relations.<npcId>` 都写入，全库 38 NPC → 最坏 38 键），实测单条关系行约 37 字符、38 条全量 ≈ 1443 字符，是 prompt 里唯一随回合数无界增长的大段；预算 8 > 既有测试依赖的最大关系数（batch10_73 的 3 条）且 ≥ 在场 NPC 预算 5（在场的必然已展开），最坏 38→8 省约 79%，Batch 10-83） |
| **AI 在场 NPC 单人任务模板预算** | services/ai_service.dart（`_onSiteNpcDesc` 内每位在场 NPC 只展开前 `BalanceData.kAiPromptOnSiteNpcTaskBudget`（=2）个任务模板，超出附「（另有 N 个可委托）」尾注——取证实测单模板 ≈ 29 字符、单 NPC 最多 3 个（艾德/提利昂/瑟曦/奥蕾娜/罗柏/泰温/珊莎/艾莉亚/布兰/巴隆 共 10 人）、平均 1.89；10-82 人数预算内 5 位共 14 个模板 ≈ 406 字符，是「在场 NPC」段（CI 实测 676 字符、占单次请求 13%）的主要来源；3→2 省 4 个模板 ≈ 116 字符。预算下限 2 的依据：`batch10_22_ai_prompt_inject_test` 断言艾德同时出现「护送北境信使至君临/难度 3/期限 6 月」与「调查野人踪迹/难度 2」两条模板信息。隐藏数用常量算而非 `split('、').length` 反推（任务标题本身可能含「、」），Batch 10-85） |
| **AI 注入家族特质/秘密** | services/ai_service.dart（`_buildPrompt` 内 `familyDesc`：家族附加「特质」（traits 全量）与「秘密」（secrets 前 2 条，空则省略）——AI 知道家族文化气质与隐藏秘密（如史塔克家族的琼恩·雪诺身世），Batch 10-67） |
| **AI 注入关系 NPC 秘密** | services/ai_service.dart（`_buildPrompt` 内 `relationDesc`：关系 NPC 附加「秘密」（secrets 前 1 条，空则省略）——AI 能围绕人物隐藏秘密展开更深剧情（如琼恩·雪诺的真实身份），Batch 10-68） |
| **AI 背包段条目预算 + 聚合去重** | services/ai_service.dart（`_buildPrompt` 内 `inventoryDesc` 改走 `_inventoryDesc` 纯函数：原直插 `player.inventory.join(、)` 输出**裸英文物品 id 且逐件重复**（12 个黑面包写 12 遍 `item_bread`），现按物品聚合计数 + `itemName` 中文名（未知 id 回退原 id）输出「黑面包 ×3、长剑 ×1」，最多 `BalanceData.kAiPromptInventoryEntryCount`（=8）种，超出附「（另有 N 种物品未列）」尾注——背包**无上限**（`mixin_life.addItem` 注释明写「背包无上限，恒成功」，且 `applyEffects` 的 `inventory.<id>` **不校验 id**，AI 选项可写入任意未知 id），是剩余两处无界累积段之一；CI 实测 12 件黑面包从 132 字符降至 12，12 种物品 96 字符，Batch 10-87） |
| **AI 状态段条目预算** | services/ai_service.dart（`_buildPrompt` 内 `flagDesc` 改走 `_flagDesc` 纯函数：原把 flags 里所有 true 的键无上限拼成一行，两条无界写入通道—① `event_service.applyEffects` 的 `flags.〈名〉` **不校验键名**（AI 选项每回合都可新增键）、② `mixin_generation.advanceGeneration` 每代写 `house.childDead.〈继承人名〉` 只增不删；现按 map 插入序取前 `BalanceData.kAiPromptFlagBudget`（=8）项，超出附「（另有 N 项未列）」尾注；CI 实测 14 项状态段 = 38 字符；`equipped.*` 键走独立的「已装备」段不受影响（物品类型硬上限 33），Batch 10-88） |
| **AI 效果键 id 契约（幽灵键修复）** | services/ai_service.dart（`_buildPrompt` 内 `relationDesc` 每条尾部追加 `[id=<npcId>]`；效果键约定段的示例由 `relations.tyrion` 改为真实 id `relations.npc_tyrion` + 头部加「原样复制，不要自行翻译或简写」硬约束 + 技能/属性可用键白名单；`systemPrompt` 同步补 id 原样使用约束。**根因**：prompt 示例写的 NPC id 全库不存在（38/38 真实 id 都是 `npc_` 前缀），而关系段只给中文名从不给 id → AI 只能照抄幽灵键，好感度永远加不到该 NPC 身上，且幽灵键按 \|值\| 参与 10-83 关系段预算排序、白占预算位。取证：最坏 8 条关系行 321~380 字符，仍 < 10-86 的 500 上界，Batch 10-89） |
| **好感度/技能数值护栏（两条写入通道统一）** | providers/game_state_provider.dart（`applyEffects`：`relations.<id>` 分支由裸加法改为 `.clamp(-BalanceData.kRelationClamp, kRelationClamp)`，与 `event_service.applyEffects` 早已存在的同名护栏对齐——**AI 选项走的是这条，此前完全没有上界**；`skills.`/`attributes.` 补 `max(0, ...)` 防负等级，与 gold 的 `max(0, ...)` 同策略）+ services/event_service.dart（硬编码的 `clamp(-100, 100)` 收口到 `BalanceData.kRelationClamp`）+ data/balance_data.dart（新增 `kRelationClamp=100` 单一真相，与 `npcRelationLabel` 的「挚友/敌对」档位饱和值对齐）。越界的连带失效：`npcRelationLabel` 六档阈值、`npcFavor` 示好成本公式、ai_service 敌友判定阈值，Batch 10-90） |
| **效果键白名单守卫（幽灵物品/技能/属性键）** | providers/game_state_provider.dart（`applyEffects`：`inventory.<id>` 分支补 `itemById(itemId) == null` 即 `continue`；`skills.`/`attributes.` 补 `BalanceData.kPlayerSkillKeys`/`kPlayerAttributeKeys` 白名单 `contains` 检查。**此前全库只有 `mixin_life.addItem` 校验物品 id**，两条 applyEffects 通道都不校验，AI 写 `inventory.dragon_scale` 就会往背包塞永不存在的物品）+ services/event_service.dart（同三处守卫，但不合规键登记进 `failedEffects`——该通道本就有此语义，金币不足即走这条路）+ data/balance_data.dart（新增 `kPlayerSkillKeys` 13 键 / `kPlayerAttributeKeys` 6 键，**键集取自 `labels.skillLabel`/`attributeLabel` 的标签分支，单一真相**）。幽灵技能键后果：`labels` 未知键兜底 `_ => key` 会把英文/中文原始键名泄漏进技能面板，且 `mixin_play.train` 的 `skills.containsKey` 判定失真（AI 能「教会」不存在的技能）。白名单取 13 而非玩家侧 5 键：内容事件写 alchemy/speech/stealth/riding/archery，`mixin_npc_interact` 学者分支把 NPC 的 leadership/politics/sword 灌进玩家技能表，Batch 10-91/92） |
| **效果摘要补齐 + 被拒效果键可见化** | mixins/mixin_ai.dart（`applyAiChoice` 效果摘要从「只有金币/声望两条」补到六类——新增 `_writeMapDeltas`（技能 ⚔️/属性 🛡️，走 `skillLabel`/`attributeLabel`）、`_writeRelationDeltas`（关系 🤝，走 `GameProviderBase.npcById` 取中文名）、`_writeInventoryDeltas`（背包 🎒，走 `itemName`）。**按 before/after 求真实 delta 而非直接读 `choice.effects`**——破底 `max(0,...)`、钳制 ±100、背包不足消耗都会让 effects 的数字与实际落盘不符；且求差天然不显示被守卫跳过的幽灵键，摘要侧无需复刻白名单判定。同文件读 `GameStateProvider.lastRejectedEffectKeys` 输出一行「（其中 N 项效果未生效：…）」，让「叙事写了、状态没变」不再静默）+ providers/game_state_provider.dart（新增只读字段 `lastRejectedEffectKeys`，**每次 `applyEffects` 入口清空、出口重填**，含 0 命中杜绝跨回合残留；被 `kPlayerSkillKeys`/`kPlayerAttributeKeys`/`itemById` 三道守卫跳过的键登记进去。**加字段而不改返回值**——`applyEffects` 返回 `Player` 是 `applyChoice`/`applyAiChoice`/10 条既有测试共同依赖的契约。Batch 10-93/94） |
| **`flags.` 效果键分层白名单（效果落盘轴收官）** | data/balance_data.dart（新增 `kPlayerFlagKeys` **26 个静态键** = 内容事件字面量键 17 + 引擎系统键 9（`isAlive`/`isInjured`/`negotiated`/`isMarried`/`divorceYear`/`widowed`/`isExiled`/`generation`/`inherited`），`kPlayerFlagPrefixes` **5 个受限动态前缀**（`equipped.`/`house.childDead.`/`npc_task.`/`npc_task_done.`/`npc_story.`），判定单一真相 `isPlayerFlagKeyValid(flagName)`——静态集命中或以某前缀开头**且后缀非空**）+ providers/game_state_provider.dart（`applyEffects` 的 `flags.` 分支补守卫，不合规键 `continue` 并登记进 `lastRejectedEffectKeys`）+ services/event_service.dart（同守卫，不合规键登记进 `failedEffects`）。**为什么分层而非纯白名单**：`flags.` 存在 5 个引擎运行时拼出的合法动态键（装备槽位写物品 id、已故子女写继承人中文名、任务/人物故事写「npcId.任务标题」），纯白名单会把它们全部拒收。**修正 10-95/96 的旧盘点**：旧盘点只记了 3 个前缀，**漏了 `npc_task.`（`mixin_npc_interact:250` 接任务）与 `npc_story.`（`:203` 人物故事）**——按旧盘点实现会静默拒收这两条内容数据；旧盘点还把 21 个 event 键当成全量静态键，实际其中 4 个是 `equipped.<物品 id>` 动态键，且**完全漏掉了引擎自己写的 9 个系统键**（只按事件键建白名单会让 `flags.isMarried` 被拒 → `formatFamilyTree` 婚姻显示恒为「未婚」）。**刻意不开 `house.childExiled.`**：全库只有读取（`mixin_generation:58`）没有写入，放行等于让 AI 有能力把家谱继承人从候选中剔除。Batch 10-97） |
| **`relations.` 效果键守卫（五类键收官）** | data/npc_data.dart（新增 `isNpcIdValid(npcId)` —— **查 `allNpcs` 而非静态键集**，与 10-91 的 `itemById` 同构；**刻意不写白名单**是因 NPC 有 38 个且随批次持续扩充（10-54/61 都加过），静态集需靠测试逐条比对防漂移，而查表让「新增 NPC 自动生效」） + providers/game_state_provider.dart（`applyEffects` 的 `relations.` 分支补守卫，不合规键 `continue` 并登记进 `lastRejectedEffectKeys`） + services/event_service.dart（同守卫，不合规键登记进 `failedEffects`）。**这是五类效果键里最后一个没设防的**——10-89 只改了 prompt 示例文案，**写侧从未校验 npc id**。幽灵键（`relations.tyrion` 不带 `npc_` 前缀）三重后果：① `ai_service` 关系段 `n == null` 兜底把它原样打进 prompt（AI 看着像真的，继续基于幻影叙事）；② `player_panel` 出现名为 `tyrion` 的条目；③ 按 `\|值\|` 参与 10-83 关系段预算排序、白占 8 个预算位把真实关系挤出窗口。**取证**：`event_data` 的 `relations.` 效果/门槛键经 10-96 清理后已归零，故守卫对内容数据零回归。Batch 10-99） |
| **AI 多 Key 轮换** | services/ai_service.dart（`generateNarrative`：**多 Key 每次请求自动轮换下一个 Key**（round-robin 起始偏移 + 每次 +1），失败 429/网络/5xx 也直接换下一个不重试同一 Key（避免触发 TPM/RPM 限流）；单 Key 保留指数退避重试；空池返回「未配置 API Key」，Batch 10-59 + fix1） |
| **AI 连通性测试（测试系统）** | services/ai_service.dart（`testConnection({String? model})`：POST `$baseUrl/chat/completions` 最小 payload（ping/max_tokens:8/temperature:0/stream:false），返回 `(bool, String)`——成功「连接正常（{model}）」/ 失败从响应体提取 `error.message` 附到状态码后 `HTTP 401（Authorization Not Found）`（`_extractErrorMessage` 静态纯函数，兼容 OpenAI 风格 `{"error":{"message":...}}` 与字符串 `{"error":"..."}` 两种形态，response 与 DioException 双分支覆盖，无 message 回落纯状态码）/ 未配 Key 短路「未配置 API Key」；走主 Key 不触发轮换，Batch 10-106 + 10-108） |
| **AI 自动识别厂商模型（多形态兼容）** | services/ai_service.dart（`fetchModels()`：GET `$baseUrl/models`，`get<dynamic>` + 静态纯函数 `_extractModelIds` 解析——兼容 4 种厂商形态：OpenAI 标准 `{"object":"list","data":[{"id":...}]}` / 顶层直接数组 `[{"id":"m1"},"m2"]` / 列表键变体 `{"models":[...]}` / 条目 id 字段变体 `id`/`name`/`model`；空 id/非字符串跳过；失败返回空列表；走主 Key 不触发轮换；**刻意不去重**——设置页并入自定义列表已有去重逻辑，Batch 10-106 + 10-107） |
| **AI 自定义模型列表 + 全模型下拉** | services/ai_config.dart（`customModels` 持久化 `ai_custom_models` JSON 数组 + `allModels` getter = 提供商候选 ∪ 自定义 ∪ 激活模型 去重保序；`clear()` 同步清空，Batch 10-106）+ screens/settings_screen.dart（`_editAiConfig` 弹窗：模型下拉用 allModels + 三按钮「自动识别模型/添加模型/测试连接」+ 结果回显 + 自定义模型逐项可移除；BaseURL 留空回落 `providerDefaultsOf(provider)`，Batch 10-106） |
| **开屏首页（主菜单）** | screens/home_screen.dart（`HomeScreen`：开始新游戏/继续游戏（读最近存档 pushReplacement GameScreen）/设置（AI/存档）三按钮 + 铁王座饰头；`app.dart` 的 `MaterialApp.home` 指向此处——每次冷启动先进主菜单；`saveService` 可注入测试，Batch 10-105） |
| **开局分步向导** | screens/start_screen.dart（7 步 Stepper：姓名/性别→身份→家族→出生地→时代→出生季节→确认；底部固定「上一步/下一步/开始游戏」；**Stepper 只渲染当前步 content（其余 SizedBox.shrink 占位、标题常显）防 RenderFlex overflow**；开始游戏按钮恒 styleFrom + textStyle `inherit:false` 防 disabled→enabled lerp 崩溃；保留 buildSetupPlayer/buildSetupProgress 纯函数与文本契约，Batch 10-105） |
| **AI 提供商预设** | data/ai_provider_defaults.dart（sensenova/atria/deepseek 3 家：默认模型/模型候选/baseUrl，`providerDefaultsOf` 单一真相对齐，Batch 10-59）+ services/ai_config.dart（`resolvedModel`/`resolvedBaseUrl` 空值回落 provider 默认） |
| **AI 配置存储（多 Key + 提供商）** | services/ai_config.dart（`apiKeys` JSON 数组持久化 `ai_api_keys` + `provider` 字段 + 双向同步旧单 key 键 `ai_api_key` + 兼容旧构造参数 `apiKey:`，Batch 10-59） |
| **AI 回合编排（读配置→拼上下文→请求→装配）** | **mixins/mixin_ai.dart（runAiAction，Batch 10-29 · M3b；返回 `AiTurnResult`）** |
| AI 回合结果对象 | models/ai_turn.dart（AiTurnResult：lines/choices/isSuccess + notConfiguredLine/notStartedLine/**degradedLine**（AI 失败降级提示，Batch 10-34 · M5a）） |
| AI 选项效果落盘 + 推进 | mixin_ai.dart（applyAiChoice） |
| 主界面状态条/快捷条/AI开关/叙事区/输入栏 | widgets/game/status.dart · quick.dart · ai_toggle.dart · narrative.dart · input.dart（Batch 10-29 · M3b；Batch 10-60 金饰化） |
| **导航宫格（9 入口 + 窄屏/宽屏自适应）** | widgets/game/nav_grid.dart（NavGrid/NavGridEntry，Batch 10-35 · M5b）+ game_screen.dart（_openNavGrid 弹出） |
| **响应式断点 / 宽屏限宽帧** | widgets/game/responsive.dart（Breakpoints kTablet=600/kDesktop=900 / AdaptiveFrame，Batch 10-36 · M5c）；game_screen 限宽 700、player_panel/family_tree 限宽 900 |
| 信件数据模型 | models/letter.dart（Letter，Batch 10-29 · M3b 从 mixin_letter 迁出） |
| AI 提示词注入在场 NPC | ai_service.dart（_buildPrompt 内 onSiteNpcDesc，Batch 10-22 升级为多步骤任务模板：标题/难度/期限） |
| AI 提示词注入家族信息 | ai_service.dart（_buildPrompt 内 familyDesc：族语/规模/影响力，Batch 10-22） |
| 存档 | services/save_service.dart（Batch 10-26 · M1：metadata 写 schemaVersion / 读档先 migrateSave / 坏档改 .corrupted） |
| **玩家面板关系区中文化** | screens/player_panel_screen.dart（关系区块 `_Entry(e.key, ...)` → `_Entry(_relationName(e), ...)`，新增顶层纯函数走 `npc_data.npcById` 查中文名，未知 id 回退原 id）。**这是全项目泄漏英文 id 的最后一处**——与 10-87 背包段、10-93 效果摘要「一律走中文名」的口径相反。**为什么 10-99 之后仍要改**：守卫只拦「新写入」，旧存档里已积累的幽灵键仍会继续显示（存档兼容不做破坏性清洗）。Batch 10-100 |
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

## 五、测试文件映射（test/ 105 文件 + regression/ 5 文件 = 110 文件）

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
| batch10_39_task_templates_test | 任务模板扩充 32→44：奥柏伦/巴隆/雅拉/瑞肯/洛拉斯/卓戈（10-39，瑞肯在场全流程） |
| batch10_40_task_penalty_test | 限时任务奖励/惩罚差异化：按时完成关系加成 / 逾期扣声望关系 / 反馈逾期月数（10-40） |
| batch10_41_coop_task_test | 多 NPC 协作任务：协作标记/可接过滤（双方在场+关系达标）/接取拒绝/完成双关系奖励/面板标注（10-41，11 用例） |
| batch10_42_task_abandon_test | 任务放弃与失败反馈：abandoned 序列化往返/旧档缺字段防御/放弃单人 -2/协作双 -2/面板已放弃/协作逾期双扣/单人逾期类型描述/指令注册（10-42，9 用例） |
| batch10_43_ai_prompt_equip_test | **AI prompt 注入装备战力**（10-43，6 用例）：combatPowerOf 纯函数（默认 10/装备 15/消耗品不计/与引擎算法一致）+ prompt 注入（装备明细名称分类价值/战斗值行/无装备兜底） |
| batch10_44_coop_expand_test | **多 NPC 协作任务扩充**（10-44，9 用例）：4 新协作模板数据校验（存在/指向真实 NPC/同地点/非同一人）+ 君临协作可接过滤（双方关系达标出现/同伴不足隐藏）+ 接取标注协作 + 完成双关系奖励 + 面板标注 + ID 唯一 |
| batch10_45_ai_world_event_test | **AI 注入本月世界局势**（10-45，4 用例）：top2 注入（名称+描述，第 3 条不出现在世界局势段落）/ 空态兜底 / 相关度最高事件排第一（冰封湖面双命中）/ 既有注入不回归 |
| batch10_46_family_tree_detail_test | **历代家主详情弹层**（10-46，4 用例）：点击谱系节点弹出详情（世代徽章/头衔/在位/成就/传承寄语）/ 成就为空「暂无显著功绩」/ 关闭按钮收起/ 无谱系无入口 |
| batch10_111_daily_economy_constants_test | **日常活动经济常量契约**（10-111，7 用例）：能量消耗 15/20/10 与旧实现一致 / workBaseIncome 覆盖 10 身份且与旧 switch 逐字一致 / 排序护栏（商人>士兵>学者>神职>平民）/ 工作浮动 5 + 技能除 2 / 贸易 25/8 差 17（regression 锁定）+ 口才 3 + 浮动 15 / 休息饱食 10 / 全部新常量正值 |
| batch10_112_hunt_danger_reward_test | **狩猎收益挂钩地点危险度**（10-112，4 用例）：每点危险度 +1 金常量契约 / 危险 6 比危险 1 多 5 金纯逻辑 / 危险 3 满技能收益区间 43~52 / 行为分支不回归（城市拒·野外可猎）。**CI 实测收敛**：取 2 撞 sim <5000 金币护栏（5004），改 1 回落 ~4520 |
| batch10_113_npc_interact_economy_test | **NPC 交互经济常量契约**（10-113，6 用例）：深聊/示好好感公式（3 + speech~/2 + rnd(3)）/ 示好礼金四边界（costOf(0)=10/100=5/200=3/-100=12）/ 熟识四类报酬（护送 15+rnd10 / 合股 10+rnd10 / 刺客 20+rnd15）/ 任务结算 20+rel~/2 + 关系 5 + 接取 2 / 通用小奖励（声望 2/野人 5/神职 5/秘密 3/挚友 2/引荐 4/超自然 3/学者 0.4）/ 全部新常量正值 |
| batch10_114_adventure_economy_test | **冒险/旅行经济常量契约**（10-114，7 用例）：旅费公式常量（2 + 危险度 + rnd(4)）/ 探索公式（精力 15 / 收益 3 + rnd(10 + 危险度*2)）/ 遭遇公式（强盗 5+危险度*2 / 野兽 8+危险度*2 / 商人 5+rnd(10)）/ 旅费区间 [base+danger, base+danger+variance-1] 纯逻辑推导 / 探索收益区间上限随危险度右移 / 强盗/野兽/商人确定性部分与浮动均不越界 / 全部新常量正值 |
| batch10_109_inheritance_order_test | **继承顺位卡片**（10-109，3 用例）：有子女显示顺位+👑继承人徽章 / 培养档案随子女行展示（Key 锚定 Text.data 断言）/ 长子已亡徽章落次子 |
| batch10_47_task_expand_test | **NPC 任务模板扩充**（10-47，5 用例）：总量 54 / 协作 8 / solo 46 / 新模板存在且指向真实 NPC（泰温·凯岩城·调查西境矿脉 / 艾莉亚·临冬城·猎杀袭击商队的狼群）/ ID·标题唯一 / 泰温不在场仅模板可见性（断言「不在这里」）/ 艾莉亚指定 taskId 全流程完成结算 |
| batch10_53_task_expand_test | **NPC 任务模板扩充**（10-53，7 用例）：总量 58 / 协作仍 8 / solo 50 / 4 新模板存在且指向真实 NPC（卢斯·波顿·黑城堡 / 拉姆斯·波顿·黑城堡 / 席恩·派克城 / 霍斯特·奔流城）/ ID·标题唯一 / 4 位 NPC 可接列表含新模板 + 不在场接取提示「不在这里」 |
| batch10_54_npc_royce_tarth_test | **新增 NPC 实体 + 任务模板扩充**（10-54，8 用例）：2 新 NPC 实体字段完整（约恩·罗伊斯·谷地·鹰巢城 / 布蕾妮·塔斯·风暴地·塔斯岛）/ 3 新模板指向真实 NPC（solo ×2 + 约恩×琼恩·艾林协作）/ 协作对同地点 / 约恩协作可接过滤 + 接取标注 / 布蕾妮不在场提示 |
| batch10_55_uncovered_npc_tasks_test | **未覆盖 NPC solo 扩充**（10-55，9 用例）：6 新 solo 模板存在且指向真实 NPC（杰奥·莫尔蒙/艾德慕·徒利/瓦德·佛雷/莱莎·艾林/乔佛瑞/托曼）/ 均 non-coop / ID·标题唯一 / 6 位 NPC 可接列表含新模板 + 不在场提示 |
| batch10_61_62_task_expand_test | **剩余 NPC 任务补齐 + 谷地协作**（10-61/62，8 用例）：模板总量 67→72 / solo 62 / 协作 10 / 4 新 solo（琼恩·艾林/弥赛拉/雷加/韦赛里斯）存在且指向真实 NPC / 新协作（琼恩·艾林×莱莎·艾林）双方同地点（鹰巢城）/ ID·标题唯一 / 4 位 NPC 可接列表含新模板 + 不在场提示 |
| batch10_48_ai_title_trend_test | **AI 注入头衔晋升趋势**（10-48，4 用例）：有下一档注入「距下一档「伯爵」还差 5 声望」+ 阶梯总览 / 已登顶「已登顶本身份头衔巅峰」/ 无头衔兜底 / 与 balance_data 单一真相对齐（nextTierReputation） |
| batch10_49_family_link_test | **谱系继承连线画布**（10-49，3 用例）：单任历史 1 传至当代 / 两任历史 1 继承 + 1 传至当代 / 无谱系无连线 |
| batch10_50_ai_season_trend_test | **AI 注入季节世界动向**（10-50，7 用例）：五季（spring/summer/autumn/winter/longwinter）各注入对应世界动向段落 / 未知季节兜底 / 既有注入（世界局势/可用事件/季节引导）不回归 |
| batch10_51_family_overview_test | **横版继承关系图（谱系概览）**（10-51，3 用例）：单任历史 1 箭头指向当代 / 两任历史 2 箭头（共 3 节点）/ 无谱系无概览 |
| batch10_52_region_trend_test | **AI 注入地区风土人情**（10-52，7 用例）：区域注入抽查（北境/西境/王领/多恩/河湾地）/ 未知区域兜底 / 既有注入（世界局势/季节动向/区域引导）不回归 |
| batch10_56_farm_trend_test | **AI 注入时节农事**（10-56，8 用例）：季节×区域注入抽查（北境冬/西境夏/王领秋/河湾地春/多恩永冬）/ 未知区域兜底 / 已知区域未知季节兜底 / 既有注入（世界局势/季节动向/地区风土人情/区域引导）不回归 |
| batch10_58_market_trend_test | **AI 注入本地集市行情**（10-58，8 用例）：季节×区域注入抽查（北境冬/西境夏/王领秋/河湾地春/多恩永冬）/ 未知区域兜底 / 已知区域未知季节兜底 / 既有注入（世界局势/季节动向/地区风土人情/时节农事/区域引导）不回归 |
| batch10_67_68_prompt_enhance_test | **AI 注入家族特质/秘密 + 关系 NPC 秘密**（10-67/68，6 用例）：史塔克家族特质（坚韧·忠诚·荣誉·战斗）/ 家族秘密（琼恩·雪诺的真实身份·史塔克家族与龙的关系，取前 2 条）/ 自由民兜底 / 关系 NPC 秘密（艾德·史塔克：琼恩·雪诺的真实身份）/ 无秘密 NPC 不输出 / 既有注入不回归 |
| batch10_63_64_prompt_enhance_test | **AI prompt 注入增强**（10-63/64，12 用例）：当前地点详情注入（临冬城/君临/高庭/未知兜底/既有注入不回归）/ 关系 NPC 身份注入（已知 NPC 身份信息/未知 NPC 回退/关系为空/既有注入不回归）/ 标签函数契约（locationTypeLabel/npcTypeLabel 关键值） |
| batch10_69_location_lore_test | **AI 注入所在地名人轶事**（10-69，9 用例）：知名地点典故注入（临冬城/君临/凯岩城/长城/高庭/龙石岛）/ 未知地点回退区域级历史底色 / 未知区域兜底文案 / 既有注入（世界局势/季节动向/地区/农事/集市）不回归 |
| batch10_70_world_stance_test | **AI 注入当前局势关联 NPC 立场**（10-70，5 用例）：有关系 NPC + 涉及兰尼斯特事件 → 史塔克 NPC 立场敌对 / 有事件无关系 NPC 兜底 / 无事件兜底 / 未知 NPC ID 立场不明 / 既有注入（世界局势/季节/地区/农事/集市/轶事）不回归 |
| batch10_71_family_members_test | **AI 注入家族谱系成员**（10-71，4 用例）：有家族玩家 → 注入同族成员（史塔克家族/身份/所在地/关系）/ 与同族私交关系值体现 / 自由民兜底「自由民，无家族可依附」/ 既有注入（世代谱系/家族/对外关系/特质/秘密/成员）不回归 |
| batch10_73_npc_network_test | **AI 注入 NPC 间关系网络**（10-73，5 用例）：多关系 NPC → 注入「A ↔ B（关系 N）：友善」（艾德↔凯特琳 90 友善）/ 无直接关系 → 中立（卢斯·波顿 ↔ 艾德·史塔克 0 中立）/ 关系 NPC 不足 2 个 → 兜底「（无）」/ 无关系 NPC → 兜底 / 既有注入不回归 |
| batch10_74_family_power_test | **AI 注入家族在权力网络中的位置**（10-74，4 用例）：有家族玩家 → 注入家族名 + 玩家角色 + 对外格局（兰尼斯特宿敌/徒利盟友）/ 姓氏与家族同名 → 角色「家主」/ 自由民兜底「自由民，无家族，不受任何家族约束」/ 既有注入不回归 |
| batch10_75_76_inheritance_local_test | **AI 注入家族继承顺位 + 当地势力与玩家立场**（10-75/76，11 用例）：① 10-75 继承顺位——有子女 → 注入顺位名单（第一顺位/第二顺位 + 培养方向 + 进修中/已督导标记，最多列 4 人 + 「另有 N 名子女不列顺位」尾注）/ 无子女 → 兜底「尚无子嗣，继承悬而未决」/ 自由民 → 兜底「无继承顺位」；② 10-76 当地势力——自家领地（临冬城·艾德·史塔克→史塔克家族治下）/ 敌对势力治下（恐怖堡·卢斯·波顿→史塔克 -80 敌对「你在敌对势力治下」）/ 无治主地点 → 兜底「无明确治主」/ 自由民 → 不涉家族对立；③ 既有注入不回归（家族权力网络 / NPC 间关系网络 / 当前地点） |
| batch10_77_78_event_alignment_test | **AI 注入与你相关的可用事件 + 事件利害标注**（10-77/78，10 用例）：① 10-77——描述含家族名 → 注入「关联：家族·史塔克」/ 身份关键词命中（士兵+边境征兵）→ 注入「关联：身份·士兵」/ 无关联 → 兜底「本月无直接牵涉你家族/身份的大事」/ 自由民 → 兜底不虚构家族关联/ 5 条全关联事件 → 只取前 3 条；② 10-78——家族类事件 → 行尾含「（对你而言：…系于你一身）」/ 战争类 → 含「对你而言」/ 自由民 + 家族事件 → 仍注入但不含「系于你一身」/ 事件名与描述仍全量注入（`- 边贸争端: 两城商路被截。` 不回归）/ 既有注入不回归（本月世界局势 / 家族继承顺位 / 当地势力与你的立场） |
| batch10_84_prompt_budget_constants_test | **AI prompt 硬编码 take() 收口到 balance_data**（10-84，16 用例）：① 9 个常量取值与收口前裸数字逐项相等（worldNews 2 / 家族 secrets 2 / 家族成员 6 / 性格 2 / 目标 2 / 技能 2 / 邻近地点 4 / 相关事件 3 / 世界立场 3，纯重构护栏）/ 全部常量为正 / 各常量下限不低于既有测试断言依赖（技能 ≥2「另有 1 项」、秘密 ≥2 史塔克两条全出、性格目标 ≥2）/ **源码级扫描断言 `ai_service.dart` 无残留 `.take(数字)`**；② 既有注入输出逐字不变——性格前 2「正直、严肃」且第三条「忠诚」不出现 / 目标前 2「维护荣誉、保护家族」/ 技能前 2「统率 9、剑术 8」+「另有 1 项」/ 家族段对外关系 4 条 + 「；特质：」+ 秘密 2 条全出 / 家族成员史塔克前 6 位（含艾德·罗柏）/ 临冬城 2 个相邻地点（白港·巴隆镇）全展开且无截断尾注 / 世界局势 + 局势立场段存在 / 13 个注入段落锚点全在 / 尾部「效果键约定」7 键 + JSON 示例完整保留 |
| batch10_86_prompt_token_budget_test | **AI prompt 全量 token 基线护栏**（10-86，8 用例）：默认玩家 user prompt ≤ 上界 5900（核心护栏）/ ≥ 下界 2500（防误删整段注入静默通过）/ 关系段 ≤ 500、在场 NPC ≤ 1000、可用事件块 ≤ 800 各自受控 / **长会话护栏：38 个 NPC 全有交情时关系段仍 ≤ 500 且带「有交情」尾注** / **事件条数护栏：72 条事件全量输入时块内恰为 12 条（= 预算值）** / 分段占比打印（固定骨架 1846 / 在场 NPC 676 / 可用事件 615 / 关系 263 / 家族成员 134 / 家族 133 / 家族权力 104 / 邻近风险 75 / 当地势力 62；12 关系 + 72 事件场景共 5137 字符，默认玩家单请求 3664 字符）/ 常量自身为正且下界 < 上界。**坑：请求体 `messages` 顺序是 `[system, user]`，取 user 内容必须跳过第一个 `"content":"`，否则量到的是 491 字符的 systemPrompt；多行块须用 `_block` 不能用 `_line` （首版用 `_line` 只量到首行 5 字符，断言形同虚设）** |
| batch10_85_onsite_task_budget_test | **AI prompt 在场 NPC 单人任务模板预算化**（10-85，11 用例）：凯特琳（模板数 = 预算 2）全量展开无任务尾注 / 艾德（模板数 3 > 预算）→ 前 2 + 「另有 1 个可委托」/ 被截断的第 3 个模板标题不泄漏 / 前 2 个模板四要素（标题·类型·难度·期限）完整保留 / 人数预算 10-82 不回归（仍 5 位 + 「另有 3 位在场未展开」，布兰/瑞肯/琼恩·雪诺不出现）/ 无在场 NPC → 「（无）」兜底 / 既有注入不回归（性格·目标·技能「另有 1 项」·信仰·「（关系 0，」）/ 真实规模护栏（预算内 5 位共 14 模板，尾注数合计 = 4）/ 预算常量契约（≥2、≤ 全库单 NPC 最大模板数 3、为正）。**坑：断言截断要用专属完整文案「个可委托」，不能用「另有」——段内「另有 1 项」是 10-79 技能尾注，与任务模板尾注无关（CI run 37204284559 因此红过）** |
| batch10_87_88_prompt_budget_test | **AI prompt 背包段 + 状态段预算化**（10-87/88，11 用例）：背包空→「（空）」兜底 / 3 个黑面包 + 长剑→聚合「黑面包 ×3、长剑 ×1」且英文 id 不泄漏 / 12 件同物聚合为 1 条（CI 实测 12 字符，旧行 132 字符）/ 12 种物品→ 截断到 8 种 + 「另有 4 种物品未列」（段内第 8 种出现、第 9 种不出现）/ 未知 id 回退原 id / 状态默认单项无尾注 / 全 false→「（无特殊状态）」兜底 / 14 项→ 截断到 8 项 + 「另有 6 项未列」（第 9 项 f8 不出现，CI 实测 38 字符）/ `equipped.*` 走装备段不受状态段预算影响（承接 batch10_43 的「长剑（武器，价值 40）」契约）/ 两个预算常量为正且≥ 在场 NPC 预算 5 / 三个段前缀均存在。**零回归依据：断言依赖的是全库首次发现的内容——旧版全库无任何测试断言「背包：」行内容或「- 状态：」行内容（仅 `batch10_63_64` 断言 `contains(「背包：」)` 前缀，形态不变）** |
| batch10_83_relation_budget_test | **AI prompt 玩家关系段人数预算**（10-83，12 用例）：≤ 预算全量展开无尾注 / 12 条 → 只展开前 8 + 「另有 4 人有交情」/ 按 \|关系值\| 降序（极端关系 100/-100/90/-90 者必在预算内，平淡者被截断）/ 同值时按 id 字典序且被截断 NPC 名字不泄漏 / **真实规模护栏：38 个 NPC 全有关系 → 「另有 30 人有交情」且关系段只出现 8 个名字** / 关系为空→「（无）」兜底 / 既有格式不回归（名字（身份·家族·所在地，秘密：xxx）: N）/ 未知 NPC ID 回退原格式 / 单条关系（既有测试最大依赖形态）/ 其他注入段不回归 / 预算常量契约（≥3 既有测试依赖 / ≤38 全库 NPC / ≥ 在场 NPC 预算 5） |
| batch10_81_82_prompt_budget_test | **AI prompt 玩家技能/属性中文化 + 人数预算化**（10-81/82，10 用例）：① 10-81——技能行注入「剑术 3、弓术 2、骑术 3、口才 2、炼金 0」且无英文裸键（含裸字典 `{` 形态）/ 属性行注入 6 个中文键且无 strength 等英文泄漏 / 键数不截断（技能 5 项 + 属性 6 项，无「另有」尾注）/ `skillLabel` 覆盖玩家侧 riding→骑术·speech→口才·alchemy→炼金（10-79 漏键）+ 未知键兜底 / `attributeLabel` 覆盖 6 键 + 未知兜底；② 10-82——临冬城 8 位 NPC → 只展开前 5 位 + 「另有 3 位在场未展开」尾注 / 预算内前 5 位（艾德/凯特琳/罗柏/珊莎/艾莉亚）全部展开 / 第 6 位起（布兰/瑞肯/琼恩·雪诺）不出现 / 未知地点→「（无）」兜底 / 既有注入不回归（信仰·性格·目标·可委托·关系 0 + NPC 网络 + 玩家技能属性行）/ 预算常量下限契约 |
| batch10_79_80_skill_nearby_test | **AI 注入 NPC 技能与信仰 + 邻近地点路途风险**（10-79/80，8 用例）：① 10-79——在场 NPC 注入技能（艾德→统率/剑术）与信仰/ 技能键名不得泄漏英文裸键（无 sword/leadership/politics）/ 超 2 项附「另有 1 项」尾注；② 10-80——临冬城列出白港（dangerLevel 2→安全）+ 巴隆镇（3→一般）+ 两者 governorId null→「无明确治主」/ 玩家处恐怖堡→相邻临冬城标「自家领地」且当地势力行标「敌对」/ 未知地点 id→「未知之地」兜底 / 自由民→不出现「自家领地」「盟友领地」/ 既有注入不回归（当地势力·当前地点·在场 NPC·所在地轶事） |
| batch10_72_world_stance_dynamic_test | **AI 注入 NPC 立场随玩家关系动态化**（10-72，5 用例）：好感 NPC（关系 80）→ 追加「因与你交好…倾向考虑你的立场」/ 恶感 NPC（关系 -40）→ 追加「因与你结怨…可能与你对立」/ 关系平平（10）不追加动态修饰 / 无事件兜底不回归 / 既有注入（10-70 立场段落 + 10-71 家族成员）不回归 |
| batch10_89_90_effect_key_contract_test | **AI 效果键 id 契约修复 + 好感度/技能数值护栏**（10-89/90，14 用例）：① 10-89——关系行每条带真实 id `[id=npc_nev]` 且中文名/关系值形态不变 / 38 NPC 全有交情时 prompt 里出现的每个 `[id=...]` 都能被 `npcById` 解析（无杜撰 id）且恰为预算 8 个 / 效果键约定示例改真实 id `relations.npc_tyrion` 且旧幽灵键 `relations.tyrion` 在整个 prompt 中消失 / 「原样复制」硬约束 + 11 个技能/属性可用键白名单 + 「累计不超过 ±100」/ systemPrompt 同步 / 既有关系行形态回归（未知 id 回退原格式·关系为空「（无）」·秘密字段）；② 10-90——好感度上界 9999→100 / 下界 -9999→-100 / 边内 15 后 -5 照常得 10 / provider 与 event_service 两条通道边界一致 / 技能·属性防负破底（-999→0）与正常增减不受影响（+2/+1）/ `kRelationClamp==100` / 源码级扫描两文件都引用常量且无硬编码 `clamp(-100, 100)`（**扫描前须剥注释行**，首版被注释里的说明文字误判）。**踩坑记录：首轮 CI 1018 passed / 2 failed——① 只改了「效果键约定」段的示例，漏改 JSON 输出模板里的 `"relations.tyrion": 10`（那才是 AI 真正会照抄的位置）；② 源码扫描正则命中了自己写的注释** |
| batch10_91_92_effect_key_whitelist_test | **效果键白名单守卫（幽灵物品/技能/属性键）**（10-91/92，20 用例）：① 10-91——provider 侧未知物品 id 不落盘 / 真实 id 数量正确 / 合法键与幽灵键混合时幽灵键被单独丢弃 / 未知物品「消耗」无副作用（不误删真实物品）/ event_service 侧未知 id 进 `failedEffects` 且不落盘 / 真实 id 登记 `applied` / 两条通道判定一致；② 10-92——未知技能键与未知属性键不落盘 / **NPC 侧键位 `leadership` 合法**（`mixin_npc_interact` 学者分支的真实写入通道，白名单必须收）/ **中文翻译键 `skills.剑术` 不落盘**（否则 `labels` 的 `_ => key` 让中文键名进技能面板）/ 合法增减不受影响 / event_service 侧进 `failedEffects`；③ 两条最重要的护栏——**全量 72 个事件的所有 `inventory.`/`skills.`/`attributes.` 键零回归断言**（白名单漏一个真实键，该事件效果会静默失效）+ `defaultPlayer` 全部键在白名单内 + **白名单与 `labels` 标签表双向同步断言**（杜绝「加了标签忘了加白名单」）/ 源码级扫描两条通道都引用三个常量（**扫描前须剥注释行**，坑 52）。**设计决策：刻意不改 prompt 侧**——10-87 已断言背包段 `isNot(contains('item_bread'))`（英文 id 不再泄漏），补 `[id=...]` 会与「减 token」方向相反且需改 3 条既有断言，故撤回 |
| batch10_93_94_effect_summary_test | **AI 选项效果摘要补齐 + 被拒效果键可见化**（10-93/94，17 用例）：① 10-93——技能 delta 出中文标签行 `⚔️ 剑术 +1（4）` / 属性 `🛡️ 力量 +2` / 关系出 NPC 中文名 `🤝 提利昂·兰尼斯特 +10（10）` / 物品出中文名 `🎒 黑面包 +2` / 负向 delta 带负号 / **按真实 delta 求值**（`skills.alchemy: -5` 被 `max(0,...)` 破底后摘要不得显示「炼金 -5」）/ 幽灵键不产生 delta 摘要行（被 10-91/92 守卫拦下即无变化反馈）/ **摘要不出英文 id**（断言 `isNot(contains('item_bread'))` 与 `isNot(contains('npc_tyrion'))`，与 10-87 口径一致）/ 无变化时不输出空摘要行；② 10-94——三道守卫拒绝的键按顺序登记进 `lastRejectedEffectKeys` / 合法键不登记 / **拒绝记录不跨回合残留**（下一次调用清空）/ 未知顶层键不登记（沿用静默忽略语义）/ 合法键与被拒键混合时只登记被拒的那个（且合法键照常落盘）/ `applyAiChoice` 输出 `（其中 N 项效果未生效：skills.hacking）` / 无被拒键时不输出提示行 / 合法效果与提示行共存（金币摘要 + 被拒提示）。**踩坑记录（坑 53，首轮 CI 37247768820 2 红，产品代码零改动）**：① 10-93 断言 `isNot(contains('hacking'))` 与 10-94「有意把被拒键名打进提示行」互斥——同批两个特性在同一段输出上断言层相反，改为按特性切开；② 10-94 断言 `provider.player.skills['sword']` 但 `applyEffects` 是**纯函数**（返回新 `Player`，不改 provider 自身的 `_player`，落盘由 `updatePlayer`/`applyChoice` 负责），首版漏接返回值故读到原值 3。 |
| batch10_97_effect_flag_whitelist_test | **`flags.` 效果键分层白名单**（10-97，33 用例）：静态键集恰 26（拆账断言 17 内容 + 9 系统 = 26）/ 17 内容键逐个在集内 / 9 系统键逐个在集内 / 前缀恰 5 个且齐备（含旧盘点遗漏的 `npc_story.`/`npc_task.`）/ `house.childExiled.` 刻意不开 / 前缀判定覆盖真实运行时键形态（`equipped.item_sword`/`house.childDead.罗柏`/`npc_task.npc_edd.护送北境信使至君临` 等）/ 幽灵键拒收（`hacking`/`剑术`/`hasDragon`）/ **裸前缀与空串拒收**（`equipped.` 无物品 id 不是合法键——首版守卫只判 `startsWith` 会放行，已修）/ 静态键与前缀无交集 / **全量 72 事件的 `flags.` 效果键与门槛键分别零幽灵断言** / 守夜人 `flags.sworn_brother` 与装备类 `flags.equipped.<id>` 事件仍落盘 / 两条通道对同一幽灵键与同一合法键判定一致（防漂移）/ provider 侧拒收记录入口清空不跨回合残留 / 清除语义不变（合法键传 0 置假）/ `flags.isMarried` 与 `flags.isAlive: 0` 既有测试键不回归 / 全部物品 id 拼出的 `equipped.<id>` 都合法。**踩坑记录（坑 54，首轮 CI 37270034492）**：测试里写了 `allItems` 但 `item_data.dart` 的真实符号是 **`kItems`（`Map<String, Item>`）**，analyze 报 `undefined_identifier` 直接红。 |
| batch10_98_flag_prompt_contract_test | **`flags.` 契约 prompt 侧同步**（10-98，9 用例）：约定行仍在（`flags.标记名`/`flags.honor_pledge` 不回归）/ 约定行指向「状态」段取键 / 5 个动态前缀全部显式点名 + **前缀表与 `BalanceData` 零漂移**（增删前缀须同步文案）/ `childExiled` 不出现在 prompt / 明说「不要自创」/ 状态段确实注入真实标记键（指路成立的前提）/ prompt 点名的前缀全部能通过 10-97 判定（闭环）/ **正则扫出 prompt 里所有 `flags.<键>` 示例逐个喂守卫，零幽灵**（实证断言，非白名单自查）。**设计决策：撤回「罗列 26 个键」的首版实现**——那会给 prompt 固定骨架加约 700 字符，与 10-81 起的「减 token」方向相反（10-86 实测固定骨架已占 36%）；改为「指向状态段 + 点名 5 个前缀」，净增约 150 字符。Batch 10-98 ||
| batch10_99_100_relation_key_guard_test | **`relations.` 效果键守卫 + 玩家面板关系区中文名**（10-99/100，23 用例）：① 10-99——`isNpcIdValid` 对 38 个真实 id 全合法 / 8 个幽灵 id 全非法（含 `tyrion`/`jon`/`npc_1`/10-96 已删四键/空串）/ 守卫与 `allNpcs` 零漂移 / **全量 72 事件的 `relations.` 效果键零幽灵**（守卫漏一个真实键，该事件效果会静默失效）/ provider 侧真实键落盘、幽灵键拒收且不进 map、登记进 `lastRejectedEffectKeys`、合法与幽灵混合时只拒幽灵、**入口清空不跨回合残留**、**裸前缀 `relations.` 拒收**、合法键仍受 ±100 钳制（10-90 护栏未破坏）/ event_service 侧真实键进 `applied`、幽灵键进 `failed`、**两通道对同一幽灵键判定一致（防漂移）**、38 个 NPC id 批量落盘零误伤 / 端到端 `applyAiChoice`：幽灵键出「未生效」提示行且无关系摘要行、真实键出中文名摘要行无提示行 / 10-91 物品守卫回归抽检（合法落盘 / 幽灵仍拒 / `kItems.length==33`）；② 10-100——真实 id 渲染中文名且 `textContaining(npc_tyrion)` 零命中 / 旧档幽灵键回退显示原 id（不空白不抛错）。**踩坑记录（坑 55，连挂两轮 CI）**：`_SectionCard` 把每条 entry 渲染成 `Chip(label: Text(key + 空格 + value))` —— **合并成一个字符串**，不是裸 key。故 `find.text(中文名)` 永远不匹配（实际文本是「中文名 30」），必须用 `find.textContaining`。**我第一轮的「高视口」假设是错的**：先归因于惰性 `ListView` 未构建、加了 `_tallView`（1080x4000），第二轮 CI 同样 2 红才读到真实根因。教训：widget 断言 0 命中时，先读渲染代码确认实际文本形态，别先猜布局。 |
| batch10_95_96_effect_drift_test | **双通道实现漂移治理**（10-95/96，18 用例）：① 10-95——`event_service` 的 `skills.`/`attributes.` 负 delta 钳到 0（`max(0,...)`，与 10-90 的 provider 侧对齐；此前事件通道是裸加法可写出负等级）/ 破底时**仍算已应用**（与 provider 侧 `rejected` 语义区分：钳制 ≠ 拒绝）/ 恰好归零照常落盘 / 正值行为不变 / 护栏常量 `kRelationClamp=100` 单一真相；② 10-96——**全量 72 事件 relations. 效果键与门槛键零幽灵断言**（键集 vs `allNpcs` 全集，两条独立用例：效果键 + 门槛键）/ 4 个幽灵键（`lord`/`family_head`/`merchant_leader`/`castle_black`）已彻底移除 / 删效果键后选项仍有 `reputation` 承载叙事褒奖 / **删门槛后 `canChoose` 恒 true**（含守夜人选项的 `flags.sworn_brother` 不被误伤）/ skills/attributes/inventory 全库键零回归 + 每条事件仍有无条件选项 + 事件总量仍是 72。**关键取证（一次性脚本，脚本已删）**：`event_data` 的 `skills./attributes.` 效果值**负值 0 处**、`batch3_event_service_test` 对该通道**只测正值** → 10-95 零回归；`relations.` 幽灵键 4 个（效果 2 + 门槛 2）均非真实 npc id，`ai_service.dart:299` 的 `n == null` 兜底 + `player_panel_screen.dart:294` 的 `relations.entries` 遍历是两条泄漏面；`canChoose` 的 `default` 分支只处理 skills/attributes/hasItem/flag，故 `relations.` 门槛恒静默放行。**撤回一条候选**：`flags.` 布尔化语义差异（event_service 用 `value != 0`、provider 用 `value > 0`）经取证收益为零（`event_data` 全部 flags 值都是 1，测试只测 0/1，两通道结果完全一致）→ 不改。**决策记录**：四键均为泛化角色概念（领主/家主/商队首领/守夜人）无唯一对应 NPC，强行映射会让该 NPC 关系值被无关事件污染，故删除而非映射 |
| batch10_65_66_prompt_enhance_test | **AI prompt 注入增强**（10-65/66，6 用例）：在场 NPC 性格/目标注入（艾德·史塔克性格·目标/前 2 条防膨胀/关系·心情·可委托不回归）/ 家族对外关系注入（史塔克敌对·友善/自由民兜底/家族名·族语·规模·影响力不回归） |
| batch10_57_family_branches_test | **当代支脉横版图**（10-57，4 用例）：已婚有子女（偶→当→子徽章）/ 未婚有子女（无偶徽章）/ 已婚无子女（无子徽章）/ 未婚无子女（不显示区块） |
| batch10_59_ai_multi_key_test | **AI 多 Key 轮换 + 多模型选择**（10-59 + fix1，12 用例）：首 key 429 自动换第二个成功 / 全部 key 失败返回最后错误 / 单 key 向后兼容（apiKey 入参进入池）/ round-robin 连续两次起始不同 / **多 key 每次请求自动轮换（成功也不重复打同一 key）** / **多 key 失败直接换下一个不重试同一 key** / 3 提供商预设（默认模型+chatBaseUrl）/ 未知提供商回落第一 / resolved 按提供商回落 + 显式优先 / 多 key 持久化往返 / 旧单 key（ai_api_key）迁移 / 保存时旧键同步写入 |
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
| **m6_robustness_test** | **M6 输入防护**（10-37，10 用例）：sanitizeCommand 正常/超长截断/恰好 80 不截断 / isCommandNoise 噪声判定 8 值 / resolveCommand 空·纯符号·超长·正常 / labels 文案集中层关键值 7 项 |
| **batch10_101_102_effect_topkey_panel_test** | **10-101/102 顶层效果键 + 面板中文名**（21 用例）：`age` 键双通道对齐（AI 通道落盘/负值钳 0/事件通道同钳）+ 未识别顶层键拒收可见化（10 个幽灵键逐个登记 / 不落盘 / 事件通道 failedEffects 两通道一致 / 合法顶层键不误登记 / 裸前缀 `flags.equipped.` 仍拒——10-97 不回归 / 端到端「未生效」提示）+ `flagLabel` 单一真相（26 静态键零漂移 / 5 动态前缀不命中静态表 / 未知键返 null / 抽样核对中文名）+ 面板 widget（静态 flag 中文名 / 背包中文名 / 装备动态键「装备·长剑」/ 旧存档未知键回退原键） |
| **batch10_103_104_trigger_contract_test** | **10-103/104 门槛契约**（14 用例）：全量 72 事件门槛键零死键（新增门槛键必须被引擎识别）+ 全量 72 事件 × 四季 × 3 玩家样本双通道判定一致（防第五次漂移）+ 节日四季可触发回归（season:any 曾恒 false）+ 季节性事件未误伤 + `season:any` 在 context 覆盖层下仍恒真（通配优先级）+ 非数字门槛值不抛异常（tryParse）+ `canTrigger` 只保留 provider 私有 isOneTime 校验 |
| **batch10_105_106_home_ai_config_test** | **开屏首页 + 开局分步向导 + AI 多模型配置/测试系统**（10-105/106 + 10-107 fetchModels 兼容，12 用例）：① HomeScreen 主菜单——三按钮渲染（开始新游戏/继续游戏（暂无存档）/设置（AI/存档））/ 无存档「继续游戏」禁用态（GestureDetector.onTap null）/ 点「开始新游戏」push 到 StartScreen（AppBar「开始新人生」+ 姓名输入）；② 开局分步向导——第 0 步姓名/性别 + 底部「下一步」+「开始游戏」disabled / 逐级「下一步」6 次到确认页（「凛冬将至」findsWidgets + 「姓名：」「身份：」确认页独有）+「开始游戏」变可用；③ AiConfig——customModels 持久化往返 + allModels 去重保序（候选 ∪ 自定义 ∪ 激活）/ 旧单 Key 迁移兼容不受影响 / clear 清空 customModels；④ AiService——testConnection 成功（200）/ HTTP 400 / 未配 Key 短路「未配置 API Key」/ fetchModels 解析 OpenAI 兼容响应（空 id 跳过）/ 空数据空列表 / 未配 Key 短路 / **10-107 新增：顶层直接数组 `[{"id":"m1"},"m2"]` / `models` 键 + `name`/`model` 字段变体 / 未知结构返回空列表**。**测试要点（踩坑记录）**：flutter_test FakeAsync 下真实 `Directory` IO 不 resolve → 必须 override `listSaves` 的内存版 `_MemorySaveService`（参照 batch5，首轮 CI 因此 2 红）；Stepper 测试用高视口（`tester.view.physicalSize = Size(1080, 4000)`，参照 batch10_60）——Stepper 全量 content 布局会溢出（已由产品侧「懒加载 content」根治）；「凛冬将至」在第 0 步饰头与确认页都有 → findsWidgets |
| **regression/（5 文件）** | **M6 跨批次回归**（10-38 · M6b，32 用例）：regression_legacy_save_test（旧档加载→引擎续玩→存档往返）/ regression_identity_branch_test（6 档工作收入互不越界 + 贸易商人差 17）/ regression_registry_test（46 指令引擎级可执行/消费回合/缺参/中英别名）/ regression_simulation_test（三策略对照/濒危救回/冬夏对比/200 月有界）/ regression_long_session_test（200/1000 回合 history 环形≤200/存档体积有界） |

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
*文档版本：v5.30（Batch 10-113/114 NPC 交互 + 冒险/旅行经济收口）· 最后更新：2026-10-06*
## 八、构建 APK 与直发邮箱（临时任务脚本，2026-10-02 新增）

用户临时需求：构建出的 APK 直接发到邮箱（附件优先，失败降级 nightly.link 链接发邮箱）。

- **触发方式**：GitHub Actions 手动触发 workflow `Build APK`（`.github/workflows/build_apk.yml`）
- **流程**：`flutter create --platforms=android` 现场生成 android/ 平台目录（仓库无 android/）→ minSdk 修正到 23（flutter_secure_storage 9.x 要求）→ pub get → analyze → test → build apk release → 重命名 `WesterosLige-nightly-<sha8>.apk` → upload-artifact（名 `WesterosLige-nightly`，保留 90 天，nightly.link 可用）→ SMTP 发邮箱 → 自动刷新 README 下载中心
- **本地一键脚本**：`scripts/build_and_mail_apk.py`
  - 触发构建 → 轮询 CI → 成功下载 APK → SMTP 附件直发邮箱 → 失败降级 nightly.link 链接发邮箱
  - 配置：`scripts/.mail_env`（复制 `.mail_env.example` 填 SMTP_HOST/PORT/USER/PASS/MAIL_TO 等，已 gitignore）
  - **SMTP Secrets 模式（对齐 wpk-update-notifier 仓库）**：CI 里走 GitHub 仓库级 Secrets（Settings → Secrets and variables → Actions 配置 `SMTP_USER` / `SMTP_AUTH_CODE` / `SMTP_TO`，SMTP_HOST=smtp.qq.com、SMTP_PORT=465 为代码默认值），build_apk.yml 的 `Send APK to email` 步骤以 env 注入；未配置 Secrets 时脚本自动跳过发信（exit 0）。脚本 `load_env()` 支持 `SMTP_AUTH_CODE` 别名映射到 `SMTP_PASS`、`MAIL_TO` 缺省回退 `SMTP_USER`；`--send --apk <path> --run-id <id>` 独立发信模式（CI 用）
  - 用法：`python3 scripts/build_and_mail_apk.py`（完整流程）/ `--check` 校验配置 / `--trigger` 只触发 / `--mail-latest` 取最近一次成功 run 的 APK 发邮箱 / `--send` 独立发信
  - **nightly.link 已废弃（2026-10-02 二次实锤，仓库已转 public 仍 404）**：实测对 public 仓库全部 run 均 404（artifact 真实存在、API 可读 25MB，但 nightly.link 服务无法访问），外联加速通道不可用；下载走 **Release 直链**（`releases/latest/download/WesterosLige.apk`，**免登录**，实测未登录 302→200），详情见第九节

## 九、README 首页自动更新（2026-10-02 新增）
用户需求：首页做「下载中心」小分块（GitHub 官方 + nightly.link 双通道下载地址）；每次构建/推送自动刷新下载区块与最近更新（只保留 3 条）；排版生动美观配图标。
- **自动更新脚本**：`scripts/update_readme.py`
  - `--download` 刷新「下载中心」区块（`<!-- DL-CENTER:BEGIN/END -->`）：以当前 run 的 SHA/run_id/时间生成 GitHub 官方运行页链接 + nightly.link 外链，由 build_apk.yml 构建成功后调用
  - `--changelog` 刷新「最近更新」区块（`<!-- CHANGELOG:BEGIN/END -->`）：从 `git log -15` 取最近 3 条**非维护类** commit（跳过 docs(/chore/Merge/auto-update，只展示功能与修复），由 ci.yml 测试通过后调用
  - 标记区块整体替换，幂等（内容无变化跳过写入）；无标记时报错提示先写标记
  - 用法（CI 环境变量 GITHUB_REPOSITORY/GITHUB_RUN_ID/GITHUB_SHA 由 Actions 注入）：`python3 scripts/update_readme.py --download` / `--changelog`
- **workflow 接入**：
  - `build_apk.yml`：构建成功 → `Publish Release`（tag `apk-<sha8>` + 固定名 asset `WesterosLige.apk`，**GitHub /releases/latest 原生指向最新，无 apk-latest 别名**）→ `Cleanup old releases`（保留最近 3 个 `apk-` 前缀）→ `Send APK to email` → `Auto-update README download center`（`git checkout main` 解决 detached HEAD → `git pull --rebase origin main || true` → 跑 `--download` → 有变化则 commit `docs(readme): auto-update download center (run <id>) [skip ci]` → `git push origin main || true` 容错）
  - `ci.yml`：analyze/test 全绿 → `Auto-update README changelog`（同样 `git checkout main` → `--changelog` → commit `docs(readme): auto-update changelog [skip ci]` → push）
  - **防递归**：自动 commit 均带 `[skip ci]`，不会再次触发 CI；两个 workflow 均开 `permissions: contents: write` 且 checkout `fetch-depth: 0`
- **下载链接现状（2026-10-02 二次实锤，仓库已转 public）**：
  - **仓库已 public**：匿名 API `private: False`、匿名 release 直链最终 200——旧「需登录 GitHub/私有仓库 404」表述已作废；README 下载中心改「免登录」直链
  - **nightly.link 仍不可用**：实测对 public 仓库全部 run（CI/Build success/Build failure）均 404（artifact 真实存在、API 可读 25MB，但 nightly.link 服务无法访问）——不恢复该通道，README/脚本删除 nightly.link 行
  - **Release 直链为主**：`https://github.com/zhaolongwudi/westeros_life_simulator/releases/latest/download/WesterosLige.apk`（**免登录可下载**，实测未登录 302→200；每次构建自动指向最新正式版 v0.0.x）
  - **只保留最近 3 次**：Cleanup 步骤按 created_at 倒序删多余 `v0.0.x` release（v 版本序列，旧 apk-<sha8> 一并清理）
- **已知验证**：run `36958877137` ✅（手动触发 CI 验证 changelog 链路，analyze/test 全绿 + auto-update 幂等跳过）；run `37007321396` ✅（release-publish 全步骤 success）；run `37004310167` ❌（auto-update push 非快进被拒 → 已加 pull --rebase 容错）；run `37048376650` ✅（head fcbd46f，fix readme 收尾闭环，analyze-test 全绿）
---
*文档版本：v5.30（Batch 10-113/114 NPC 交互 + 冒险/旅行经济收口）· 最后更新：2026-10-06*
