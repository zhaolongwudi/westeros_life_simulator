# 维斯特洛人生模拟器 · Westeros Life Simulator

> 凛冬不是惩罚。它只是这个世界的季节之一。

## 项目定位

超高自由度冰与火之歌世界沙盘。玩家不是"被预言的王子"，只是这个世界里出生的一个人。

- **类型**：西方奇幻｜低魔世界｜超高自由度人生｜开放世界｜贵族政治｜家族血仇｜教会体系｜学城体系｜雇佣兵生态｜长城守夜人｜自由贸易城邦｜龙与异鬼｜战争与阴谋｜领地经营｜旧神与七神信仰｜维斯特洛全境｜厄索斯大陆
- **核心体验**：玩家不是预言中的王子。玩家只是这个世界里出生的一个人。
- **参考项目**：hogwarts_life_simulator（同作者，48 batch 迭代）

## 目录结构

```
westeros_life_simulator/
├── README.md                          # 本文件
├── pubspec.yaml                       # Flutter 项目配置
├── analysis_options.yaml              # Dart 分析规则
├── .gitignore                         # Git 忽略规则
├── docs/
│   ├── 01_世界百科.md                 # 地理/历史/纪元/季节/货币（341 行）
│   ├── 02_家族百科.md                 # 26 家族详细设定（643 行）
│   ├── 03_地点百科.md                 # 50+ 地点详细设定（616 行）
│   ├── 04_NPC百科.md                  # 40+ NPC 档案（648 行）
│   ├── 05_系统百科.md                 # 74 系统详细设定（1517 行）
│   ├── 06_事件库.md                   # 45 事件模板（1115 行）
│   ├── 07_AI提示词.md                 # System Prompt（1014 行）
│   └── 08_玩法设计.md                 # 玩家可玩内容清单（778 行）
├── lib/
│   ├── main.dart                      # 入口
│   ├── app.dart                       # 应用根组件
│   ├── game_engine.dart               # 游戏引擎（组合全部 mixin 的宿主）
│   ├── data/                          # 数据层（Batch 2 ✅）
│   ├── models/                        # 模型层（Batch 1 ✅）
│   │   ├── player.dart
│   │   ├── family.dart
│   │   ├── npc.dart
│   │   ├── location.dart
│   │   └── event.dart
│   ├── providers/                     # 状态管理（Batch 3 ✅）
│   │   ├── game_state_provider.dart
│   │   ├── event_provider.dart
│   │   └── game_provider_base.dart    # 混入层宿主 + 公共能力（Batch 4 ✅）
│   ├── mixins/                        # 混入层（Batch 4 ✅）
│   │   ├── mixin_play.dart            # 日常玩法
│   │   ├── mixin_commands.dart        # 指令分发
│   │   ├── mixin_systems.dart         # 74 系统挂载/月度演进
│   │   ├── mixin_letter.dart          # 信件系统
│   │   └── mixin_adventure.dart       # 旅行/探索/遭遇
│   ├── screens/                       # UI 层（Batch 5+6+7 ✅）
│   │   ├── start_screen.dart           # 开局选择界面（Batch 6 ✅）
│   │   ├── game_screen.dart            # 游戏主界面（状态条+指令+叙事+快捷按钮）
│   │   ├── events_screen.dart          # 事件面板（可触发/事件库 Tab，Batch 7 ✅）
│   │   ├── letters_screen.dart         # 信件面板（来信/回信入口，Batch 7 ✅）
│   │   ├── player_panel_screen.dart    # 玩家详情面板
│   │   ├── family_screen.dart          # 家族面板（27 家族）
│   │   ├── map_screen.dart             # 地图（68 地点按区域分组）
│   │   ├── systems_screen.dart         # 系统面板（74 系统）
│   │   └── settings_screen.dart        # 设置/存档（保存/加载/导出/导入/新游戏）
│   ├── services/                      # 服务层（Batch 3 + Batch 8 ✅）
│   │   ├── ai_service.dart            # AiService（AI 叙事/选项生成，Dio）
│   │   ├── ai_config.dart             # AiConfig（API Key/模型/BaseURL 持久化，Batch 8 ✅）
│   │   ├── event_service.dart         # EventService（触发条件/效果/存档）
│   │   └── save_service.dart          # SaveService（序列化/存档/导入导出）
│   └── utils/                         # 工具
└── test/
    ├── batch1_smoke_test.dart         # Batch 1 冒烟测试（17 用例）
    ├── batch4_*_test.dart             # Batch 4 混入层测试（5 文件）
    ├── batch5_ui_test.dart            # Batch 5 UI 测试（6 用例）
    ├── batch6_start_test.dart         # Batch 6 开局测试（6 用例）
    ├── batch7_events_letters_test.dart # Batch 7 事件/信件测试（7 用例）
    └── batch8_ai_ui_test.dart         # Batch 8 AI 配置测试（4 用例）
```

## 阶段规划

### 阶段 1：设计文档（✅ 完成）
- 填充大纲，完整世界观百科
- 交付：docs/ 下 8 份文档，共 6672 行，140KB

### 阶段 2：AI 提示词（✅ 完成）
- 把设计文档浓缩成 system prompt
- 交付：docs/07_AI提示词.md（1014 行，可直接使用）

### 阶段 3：代码框架（⏳ 进行中）

#### Batch 1：项目骨架 + 模型层（✅ 完成，2026-09-23）
- 项目初始化：git init、.gitignore、analysis_options.yaml、pubspec.yaml
- 入口文件：lib/main.dart、lib/app.dart（占位 UI）
- 目录结构：lib/{data,models,providers,mixins,screens,services,utils}、test/
- 模型层 5 个：
  - lib/models/player.dart（Player + PlayerIdentity，10 身份）
  - lib/models/family.dart（Family + FamilyScale，3 规模）
  - lib/models/npc.dart（Npc + NpcType，11 类型）
  - lib/models/location.dart（Location + LocationType，11 类型）
  - lib/models/event.dart（GameEvent + EventChoice + EventType，9 类型）
- 测试：test/batch1_smoke_test.dart（17 个用例，覆盖 default/copyWith/toJson/fromJson/枚举完整性）
- 验证方式：GitHub Actions CI（run 35841277454，✅ success，2026-09-23）

#### Batch 2：数据层（✅ 完成，2026-09-23）
- lib/data/family_data.dart（27 家族，✅ 完成，CI 通过）
- lib/data/location_data.dart（68 地点，✅ 完成）
- lib/data/npc_data.dart（36 NPC，✅ 完成）
- lib/data/event_data.dart（45 事件模板，✅ 完成）
- lib/data/system_data.dart（74 系统，✅ 完成）
- lib/models/system.dart（GameSystem 模型，✅ 新增）
- 测试：test/batch2_{family,location,npc,event,system}_data_test.dart（55 用例）
- 验证方式：GitHub Actions CI（run 35845290631，✅ success，2026-09-23）

#### Batch 3：状态管理 + 服务层（✅ 完成，2026-09-24）
- lib/providers/game_state_provider.dart（GameStateProvider + GameProgress，状态管理/时间推进/选项效果/序列化）
- lib/providers/event_provider.dart（EventProvider，事件触发/条件检查/选项可用性/重置）
- lib/services/ai_service.dart（AiService，调用 AI 生成叙事与选项，参考 docs/07_AI提示词.md）
- lib/services/event_service.dart（EventService，事件触发条件检查/效果计算/存档）
- lib/services/save_service.dart（SaveService，游戏状态序列化/存档读写/导入导出）
- 测试：test/batch3_{game_state_provider,event_provider,ai_service,event_service,save_service}_test.dart（63 用例）
- 验证方式：GitHub Actions CI（run 36007775720，✅ success，2026-09-24，134 测试全部通过）
- 修复历程：4 个 Analyze error（event_provider 初始化器/GameState nullable 条件/AiService Dio 类型与超时参数）→ 1 个 warning（save_service 非空断言）→ 1 个测试失败（GameStateProvider 序列化往返丢失 isGameActive/isGameOver/currentEvent）

#### Batch 4：混入层（✅ 完成，2026-09-25）
- lib/mixins/mixin_play.dart（日常玩法：训练/工作/休息/狩猎/贸易/月度循环）
- lib/mixins/mixin_commands.dart（指令解析：状态/系统/信/旅行/训练/工作/狩猎/贸易/休息/探索/过月/帮助）
- lib/mixins/mixin_systems.dart（74 系统挂载 + 月度演进结算 + 系统面板）
- lib/mixins/mixin_letter.dart（NPC 主动来信 + 回信 + 关系培养）
- lib/mixins/mixin_adventure.dart（旅行/探索/遭遇）
- lib/providers/game_provider_base.dart（混入层宿主：世界静态数据 + 公共能力沉淀）
- lib/game_engine.dart（游戏引擎：组合全部 mixin）
- 测试：test/batch4_{play,commands,systems,letter,adventure}_test.dart（5 文件）
- 重构要点：身份判定改用枚举（PlayerIdentity）避免字符串魔法值；金币/声望/关系/标记变更统一上提到基类，消除 mixin 间重复代码
- 验证方式：GitHub Actions CI（run 36110857045，✅ success，2026-09-25，192 测试全部通过）
- 修复历程：4 类 Analyze 错误（mixin with 子句/GamePlayMixin 跨 mixin 调用/mixin_systems import/测试判空）→ 2 类新问题（GameEngine mixin 混入顺序/测试 `?.` 多余）→ 最终 CI 通过

#### Batch 5：UI 层（✅ 完成，2026-09-25）
- lib/screens/game_screen.dart（游戏主界面：顶部状态条 + 快捷指令栏 + 叙事输出区 + 指令输入框）
- lib/screens/player_panel_screen.dart（玩家详情：身份/家族/地点/财富/属性/技能/关系/标记/背包）
- lib/screens/family_screen.dart（家族面板：玩家家族高亮 + 27 家族可展开详情）
- lib/screens/map_screen.dart（地图：68 地点按区域分组 + 当前所在地标记 + 地点详情弹层）
- lib/screens/systems_screen.dart（系统面板：已接触系统列表 + 详情弹层含规则/特性）
- lib/screens/settings_screen.dart（设置/存档：保存/加载/删除/导出/导入/新游戏，复用 SaveService）
- lib/providers/game_state_provider.dart 新增 applyState()（加载/导入存档时整体恢复引擎状态）
- lib/app.dart 接线：入口直接进入 GameScreen
- 测试：test/batch5_ui_test.dart（6 用例：applyState/玩家详情/家族/地图/系统/设置）
- 验证方式：GitHub Actions CI（run 36113576770，✅ success，2026-09-25，198 测试全部通过）

#### Batch 6：开局选择界面（✅ 完成，2026-09-25）
- lib/screens/start_screen.dart（开局选择：姓名/性别/身份/家族/出生地/时代/季节 + 随机名字）
- 角色生成纯函数：buildSetupPlayer / buildSetupProgress（按身份差异化初始资金/技能/声望）
- 时代选择：篡夺者战争前/期间/后/当前时代（年份 281/282/283/298）
- 季节选择：春/夏/秋/冬/凛冬（月份 3/6/9/12/12）
- 家族选择联动出生地（选家族自动跳到其 seat 城堡）；支持自由民（无家族）
- lib/screens/game_screen.dart 支持注入外部引擎；lib/app.dart 入口改为 StartScreen
- 测试：test/batch6_start_test.dart（6 用例：商人/平民角色生成、进度映射、标签、时代年份、界面构建）
- 验证方式：GitHub Actions CI（run 36116959188，✅ success，2026-09-25，204 测试全部通过）
- 修复历程：开局界面 widget 测试在默认视口下 ListView 懒加载导致"出生地"未构建 → 调大测试视口（tester.view.physicalSize）

#### Batch 7：事件面板 + 信件面板（✅ 完成，2026-09-25）
- lib/screens/events_screen.dart（事件面板：可触发/事件库 双 Tab，事件卡片含触发条件/选项可用性标记）
- lib/screens/letters_screen.dart（信件面板：来信/回信列表 + 回信输入入口，复用 mixin_letter）
- lib/providers/game_provider_base.dart 新增 eventProvider 组合字段（注入事件模板供面板浏览）
- lib/screens/game_screen.dart 主界面 AppBar 增加事件/信件入口
- 测试：test/batch7_events_letters_test.dart（7 用例：类型标签/事件库 45/可触发非空/面板构建/空状态/触发与冷却/来信渲染）
- 验证方式：GitHub Actions CI（run 36119114694，✅ success，2026-09-25，211 测试全部通过）

#### Batch 8：AI 行动模式（✅ 完成，2026-09-25）
- lib/services/ai_config.dart（AiConfig：API Key/模型/BaseURL 持久化，SharedPreferences）
- lib/screens/game_screen.dart 新增「AI 行动模式」开关（输入框提交行动描述 → AiService 生成叙事/选项卡片）
- lib/screens/settings_screen.dart 新增 AI 配置卡片（编辑 API Key/模型/BaseURL，配置状态提示）
- 测试：test/batch8_ai_ui_test.dart（4 用例：默认值/读写持久化/主界面开关构建/设置界面配置卡片）
- 验证方式：GitHub Actions CI（run 36121545193，✅ success，2026-09-25，215 测试全部通过）

## 文档统计

| 文档 | 行数 | 大小 |
|------|------|------|
| 01_世界百科.md | 341 | 7.5KB |
| 02_家族百科.md | 643 | 14.9KB |
| 03_地点百科.md | 616 | 10.6KB |
| 04_NPC百科.md | 648 | 15.3KB |
| 05_系统百科.md | 1517 | 17.8KB |
| 06_事件库.md | 1115 | 13.1KB |
| 07_AI提示词.md | 1014 | 34.2KB |
| 08_玩法设计.md | 778 | 11.1KB |
| **合计** | **6672** | **140KB** |

## 版权说明

本项目为个人使用，基于乔治·R·R·马丁《冰与火之歌》系列小说。不公开分享、不商用。

## 版本

- v1.0：设计文档完成（2026-09-23）
- v1.1：AI 提示词完成（2026-09-23）
- v2.0.0：阶段 3 Batch 1 项目骨架 + 模型层完成（2026-09-23）
- v2.1.0：阶段 3 Batch 2 数据层完成（2026-09-23，CI run 35845290631 ✅ success）
- v2.2.0：阶段 3 Batch 3 状态管理 + 服务层完成（2026-09-24，CI run 36007775720 ✅ success，134 测试全部通过）
- v2.3.0：阶段 3 Batch 4 混入层（✅ 完成，2026-09-25，CI run 36110857045 ✅ success，192 测试全部通过）
- v2.4.0：阶段 3 Batch 5 UI 层（✅ 完成，2026-09-25，CI run 36113576770 ✅ success，198 测试全部通过）
- v2.5.0：阶段 3 Batch 6 开局选择界面（✅ 完成，2026-09-25，CI run 36116959188 ✅ success，204 测试全部通过）
- v2.6.0：阶段 3 Batch 7 事件面板 + 信件面板（✅ 完成，2026-09-25，CI run 36119114694 ✅ success，211 测试全部通过）
- v2.7.0：阶段 3 Batch 8 AI 行动模式（✅ 完成，2026-09-25，CI run 36121545193 ✅ success，215 测试全部通过）
