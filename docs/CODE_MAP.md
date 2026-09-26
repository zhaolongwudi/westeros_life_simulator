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
├── data/                          # 【静态数据层】世界常量数据
│   ├── family_data.dart           # 27 家族
│   ├── location_data.dart         # 68 地点
│   ├── npc_data.dart              # 36 NPC（含 Batch 10-15 任务链 tasks/mood）
│   ├── event_data.dart            # 72 事件（60 + 12 复合）
│   ├── system_data.dart           # 74 系统
│   ├── item_data.dart             # 34 物品
│   └── narrative_templates.dart   # 差异化叙事引导（10 身份/12 区域/5 季节）
│
├── models/                        # 【模型层】不可变实体（copyWith + toJson/fromJson）
│   ├── player.dart                # Player（含 health/energy/hunger/title/house/children）
│   ├── family.dart                # Family + FamilyScale
│   ├── npc.dart                   # Npc + NpcType（含 tasks/mood，Batch 10-15）
│   ├── location.dart              # Location + LocationType
│   ├── event.dart                 # GameEvent + EventChoice + EventType
│   └── system.dart                # GameSystem
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
│   ├── mixin_generation.dart      # ⭐ 家族继承与多世代：立嗣/家谱/死亡传承（Batch 10-14）
│   ├── mixin_commands.dart        # ⭐ 指令解析：resolveCommand 分发全部指令
│   └── mixin_ai.dart              # AI 回合混入（applyAiChoice）
│
├── screens/                       # 【UI 层】
│   ├── start_screen.dart          # 开局选择界面
│   ├── game_screen.dart           # 主界面（状态条+快捷指令+叙事+输入+面板入口）
│   ├── player_panel_screen.dart   # 玩家详情（含家谱区块，Batch 10-14）
│   ├── npc_panel_screen.dart      # NPC 关系面板（Batch 10-15 新增）
│   ├── family_screen.dart         # 家族面板
│   ├── map_screen.dart            # 地图
│   ├── events_screen.dart         # 事件面板
│   ├── letters_screen.dart        # 信件面板
│   ├── systems_screen.dart        # 系统面板
│   └── settings_screen.dart       # 设置/存档
│
├── services/                      # 【服务层】外部/IO
│   ├── ai_service.dart            # AiService：AI 叙事/选项生成（Dio，含在场 NPC 注入）
│   ├── ai_config.dart             # AI Key/模型/BaseURL 持久化
│   ├── event_service.dart         # 事件触发/效果/存档（注意：与 provider 双实现）
│   └── save_service.dart          # 存档序列化/导入导出
│
└── utils/                         # 【工具层】纯函数
    ├── labels.dart                # 中文标签（身份/物品分类/技能）
    ├── text_formats.dart          # 文本格式化
    └── narrative_format.dart      # 叙事分段/效果标签/选项编号（Batch 10-12）
```

## 二、关键依赖链（mixin 混入顺序）

```
GameEngine extends GameProviderBase with:
  GameSystemsMixin → GameLifeMixin → GameNpcInteractMixin → GameGenerationMixin
  → GamePlayMixin → GameLetterMixin → GameAdventureMixin → GameCommandsMixin → GameAiMixin
```

**规则**：mixin 的 `on` 子句列出依赖；**被依赖者必须在宿主 with 中排在前面**。
新增 mixin 依赖时同步改 game_engine.dart 的 with 顺序（坑 18）。

| Mixin | on 依赖 | 说明 |
|-------|---------|------|
| GameLifeMixin | GameProviderBase | 生存/物品/贸易/装备/头衔 |
| GameNpcInteractMixin | Base, Life | NPC 交互 |
| GameGenerationMixin | Base, Life | 家族继承（Batch 10-14） |
| GamePlayMixin | Base, Systems, Life, NpcInteract, Generation | 日常玩法+过月 |
| GameAdventureMixin | Base, Life, NpcInteract | 旅行/探索（探索结算 NPC 任务） |
| GameCommandsMixin | 全部 | 指令解析 |
| GameAiMixin | ？ | AI 回合（见 mixin_ai.dart） |

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
| 头衔晋升 | mixin_life.dart（checkTitlePromotion/formatTitlePanel） |
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
| 继承人/世代传承 | mixin_generation.dart（heirName/advanceGeneration） |
| 效果应用（事件/AI 共用） | providers/game_state_provider.dart（applyEffects） |
| 游戏结束/血脉断绝 | providers/game_state_provider.dart（endGame）+ mixin_play.dart（_tryInheritance） |
| AI 叙事生成 | services/ai_service.dart（generateNarrative/_buildPrompt） |
| AI 提示词注入在场 NPC | ai_service.dart（_buildPrompt 内 onSiteNpcDesc） |
| 存档 | services/save_service.dart |
| 事件触发/选项 | providers/event_provider.dart |
| 玩家面板 UI | screens/player_panel_screen.dart |
| NPC 面板 UI | screens/npc_panel_screen.dart（Batch 10-15） |
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
| 在场 | npc/人物 | _npcListText | 否 |
| 互动 | 交谈/interact [名字] | npcInteract | 否 |
| 示好 | 送礼/favor [名字] | npcFavor | 否 |
| 深聊 | 聊天/chat [名字] | npcChat（Batch 10-15） | 否 |
| 任务 | 委托/task [名字] | formatNpcTaskPanel / acceptNpcTask | 否 |
| 关系 | 关系面板/relations | formatNpcRelationPanel（Batch 10-15） | 否 |
| 家谱 | 家族/family | formatFamilyTree（Batch 10-14） | 否 |
| 立嗣 | 添丁/addchild [名字] | addChild（Batch 10-14） | 否 |
| 休息 | rest | rest | 否 |
| 过月 | advance | advanceMonth | 是 |
| 帮助 | help | _helpText | 否 |

## 五、测试文件映射（test/ 35 文件，总 4880+ 行）

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

> 坑：**扩充数据（事件/NPC）时，必须同步更新所有「总量/类型分布」断言**
> （grep `allEvents.length` / `eventsByType(...).length`）。

## 六、已踩坑速查（详细原因见 HANDOVER 第三、四节）

- **测试用 `||` 组合 Matcher** → non_bool_operand，改用 `anyOf`（坑 18）
- **mixin 增 on 依赖** → 必须同步宿主 with 顺序（被依赖在前）+ import（坑 18）
- **setFlag 只存 bool** → 数值/字符串存实例字段或模型字段（坑 16）
- **私有成员跨 mixin 不可见** → 新计数用独立前缀自建（坑 16）
- **toJson/fromJson 字段必须对齐** → 新增字段给默认值 + fromJson `??` 兜底（坑 8/12）
- **Dio mock 捕获** → 用 List 容器而非 record 值拷贝（坑 14）
- **本地无 Flutter** → 靠 GitHub Actions CI 验证；括号用 python 脚本检查
- **gitdata_push 多 commit 极慢** → 必须后台跑 + 轮询日志（坑 10）；网络断了可重跑（幂等）
- **HANDOVER.md 已 gitignore** → 只本地更新；README 正常推送

## 七、文件写入约定（复用 HANDOVER 第二节）

1. 不要用 heredoc 传中文（shell 破坏 UTF-8）→ 用 create_file/edit_file 工具
2. 单文件不要太大（用户偏好，便于维护）；mixin_life 已 769 行，新功能优先拆新文件
3. 每次改完先括号检查（python 脚本），再 commit → push → CI → 绿后更新 HANDOVER + README

---
*文档版本：v1.0（Batch 10-16 新增）· 最后更新：2026-09-26*
