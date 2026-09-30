# 维斯特洛人生模拟器 · 项目地图（PROJECT_MAP）

> 生成日期：2026-09-28 · 本地 HEAD `ef46220`（batch10-25 婚姻系统二轮，婚姻/丧偶/谈心/月度事件/婚姻面板）
> 生成方式：通读 `/root/westeros_life_simulator` 全量代码后整理的事实性结论，与 `docs/CODE_MAP.md` 并存（CODE_MAP 偏定位索引，本文件偏全景地图）
> 范围：仅 `lib/` + `test/` + `scripts/` + `docs/` + 根配置文件；不含第三方依赖源码
> 规模：`lib/` 共 16080 行；`test/` 共 6614 行（43 个测试文件）
> 约束：本文档只陈述事实，不含修改建议

## 1. 完整目录树（含行数）

```
/root/westeros_life_simulator/
├── .gitignore                                     git 忽略规则
├── README.md                                      项目说明（推送远端）
├── analysis_options.yaml                          lint/analyzer 配置
├── pubspec.yaml                                   包配置
├── .github/
│   └── workflows/ci.yml                           CI 工作流（analyze + test --coverage）
├── scripts/
│   └── gitdata_push.py                           252 行 git push 替代脚本（Git Git Data API）
├── docs/                                          10 个 .md，7492 行
│   ├── 01_世界百科.md                              341 行
│   ├── 02_家族百科.md                              643 行
│   ├── 03_地点百科.md                              616 行
│   ├── 04_NPC百科.md                               648 行
│   ├── 05_系统百科.md                             1517 行
│   ├── 06_事件库.md                               1115 行
│   ├── 07_AI提示词.md                             1014 行
│   ├── 08_玩法设计.md                              778 行
│   ├── CODE_MAP.md                                264 行
│   └── HANDOVER.md                                556 行（.gitignore 忽略，仅本地，跨对话锚点 v23.0）
├── lib/
│   ├── main.dart                                    6 行
│   ├── app.dart                                    19 行
│   ├── game_engine.dart                            49 行
│   ├── data/                                     （静态数据层，5786 行）
│   │   ├── event_data.dart                       2490 行
│   │   ├── family_data.dart                       462 行
│   │   ├── item_data.dart                         345 行
│   │   ├── location_data.dart                     876 行
│   │   ├── narrative_templates.dart               100 行
│   │   ├── npc_data.dart                          815 行
│   │   ├── npc_task_data.dart                     547 行
│   │   └── system_data.dart                       651 行
│   ├── mixins/                                  （混入逻辑层，3218 行）
│   │   ├── mixin_adventure.dart                   201 行
│   │   ├── mixin_ai.dart                            49 行
│   │   ├── mixin_commands.dart                    401 行
│   │   ├── mixin_generation.dart                  175 行
│   │   ├── mixin_letter.dart                      186 行
│   │   ├── mixin_life.dart                        769 行
│   │   ├── mixin_marriage.dart                    515 行
│   │   ├── mixin_npc_interact.dart                330 行
│   │   ├── mixin_npc_task.dart                    271 行
│   │   ├── mixin_play.dart                        340 行
│   │   └── mixin_systems.dart                     181 行
│   ├── models/                                  （模型层，1520 行）
│   │   ├── event.dart                             186 行
│   │   ├── family.dart                            153 行
│   │   ├── location.dart                          137 行
│   │   ├── marital.dart                           216 行
│   │   ├── npc.dart                               191 行
│   │   ├── npc_task.dart                          187 行
│   │   ├── player.dart                            286 行
│   │   └── system.dart                             81 行
│   ├── providers/                               （状态层，677 行）
│   │   ├── event_provider.dart                    180 行
│   │   ├── game_provider_base.dart                184 行
│   │   └── game_state_provider.dart               313 行
│   ├── screens/                                 （UI 层，3213 行）
│   │   ├── events_screen.dart                     169 行
│   │   ├── family_screen.dart                     162 行
│   │   ├── family_tree_screen.dart                321 行
│   │   ├── game_screen.dart                       709 行
│   │   ├── letters_screen.dart                    154 行
│   │   ├── map_screen.dart                        140 行
│   │   ├── npc_panel_screen.dart                  205 行
│   │   ├── player_panel_screen.dart               320 行
│   │   ├── settings_screen.dart                   382 行
│   │   ├── start_screen.dart                      440 行
│   │   └── systems_screen.dart                    119 行
│   ├── services/                                （服务层，875 行）
│   │   ├── ai_config.dart                          55 行
│   │   ├── ai_service.dart                        372 行
│   │   ├── event_service.dart                     255 行
│   │   └── save_service.dart                      193 行
│   └── utils/                                    （工具层，192 行）
│       ├── labels.dart                            63 行
│       ├── narrative_format.dart                 102 行
│       └── text_formats.dart                      27 行
└── test/                                           43 个文件，6614 行
    ├── batch1_smoke_test.dart   batch2_*（5 个）   batch3_*（6 个）
    ├── batch4_mixin_*（5 个）   batch5_ui_test.dart batch6_start_test.dart
    ├── batch7_events_letters_test.dart  batch8_ai_ui_test.dart
    ├── batch9_ai_deep_test.dart  batch9_utils_test.dart
    └── batch10_*（25 个，覆盖 Batch 10-2 ~ 10-25 各批次） + batch10_life_items_test.dart
```

## 2. 每个文件一句话职责

### 入口/根
- `lib/main.dart`：`runApp(const WesterosApp())`，仅 6 行。
- `lib/app.dart`：根组件 `WesterosApp`，`MaterialApp`（深橙 Material3 主题），`home: StartScreen()`。
- `lib/game_engine.dart`：引擎宿主 `GameEngine`，`GameProviderBase` 基类混入 11 个 mixin（含混入顺序）。

### data/（静态数据，const 常量）
- `event_data.dart`：72 个事件模板常量 `allEvents`（含 218 处 EventChoice）。
- `family_data.dart`：26 个贵族家族常量 `allFamilies`。
- `location_data.dart`：68 个地点常量 `allLocations`。
- `npc_data.dart`：36 个 NPC 常量 `allNpcs`。
- `system_data.dart`：74 个世界规则系统常量 `allSystems`。
- `item_data.dart`：物品词典（物品模型 + 全部物品定义 + 中文/分类标签）。
- `narrative_templates.dart`：按身份/区域/季节差异化的 AI 叙事引导模板（10 身份/12 区域/5 季节）。
- `npc_task_data.dart`：NPC 多步骤任务模板（32 个，难度/期限/步骤/奖励）。

### mixins/（玩法逻辑，全部 `on GameProviderBase`）
- `mixin_adventure.dart`：旅行/探索/遭遇（含掉落与随机遭遇判定）。
- `mixin_ai.dart`：应用 AI 生成选项效果并推进世界（`applyAiChoice`）。
- `mixin_commands.dart`：玩家指令解析与分发（`resolveCommand`），含买卖/帮助/指令表。
- `mixin_generation.dart`：家族继承与多世代（立嗣/家谱/死亡传承）。
- `mixin_letter.dart`：NPC 主动来信 + 玩家回信。
- `mixin_life.dart`：健康/精力/饱食生存管理与物品/装备/贸易系统。
- `mixin_marriage.dart`：婚姻/配偶互动/生育/子女培养/世代谱系（Batch 10-17 / 10-25）。
- `mixin_npc_interact.dart`：NPC 深度交互（关系等级/互动/示好/事件链）。
- `mixin_npc_task.dart`：NPC 多步骤任务链二轮（接单/推进/期限/奖励结算）。
- `mixin_play.dart`：日常玩法（训练/工作/休息/狩猎/贸易/月度循环）。
- `mixin_systems.dart`：挂载 74 个系统、月度演进与系统查询。

### models/
- `event.dart`：事件与事件模板模型（GameEvent / EventChoice / EventType）。
- `family.dart`：家族模型（FamilyScale 等）。
- `location.dart`：地点模型（LocationType 等）。
- `marital.dart`：婚姻/子女培养/世代谱系模型（SpouseDetail / ChildRearing / GenerationRecord）。
- `npc.dart`：NPC 模型（NpcType 等）。
- `npc_task.dart`：任务链模型（NpcTaskTemplate / NpcTaskStep / NpcTaskProgress）。
- `player.dart`：玩家核心实体（Player + PlayerIdentity 枚举，含婚姻/任务/谱系全字段）。
- `system.dart`：世界规则系统模型（GameSystem）。

### providers/
- `event_provider.dart`：事件触发条件检查/随机触发/完成标记/选项可用性。
- `game_provider_base.dart`：基类，承载世界静态数据（NPC/地点/家族/系统/事件）+ 身份/金币/关系/标记等公共能力。
- `game_state_provider.dart`：玩家状态/进度/历史/当前事件管理（ChangeNotifier），含 JSON 序列化与效果应用。

### screens/
- `events_screen.dart`：事件面板（浏览模板 + 可触发状态标记）。
- `family_screen.dart`：家族面板 + 家族树入口。
- `family_tree_screen.dart`：家族树可视化（世代谱系链/当前世代，Batch 10-20）。
- `game_screen.dart`：游戏主界面（状态条/快捷指令/AI 开关/叙事区/AI 选项卡/输入栏 + 5 个子界面入口）。
- `letters_screen.dart`：信件面板 + 回信入口。
- `map_screen.dart`：地点/地图面板。
- `npc_panel_screen.dart`：NPC 关系/心情/任务总览 + 在场 NPC 快捷互动。
- `player_panel_screen.dart`：玩家状态结构化卡片。
- `settings_screen.dart`：设置与存档（存档列表/保存/加载/导出导入/新游戏/AI 配置）。
- `start_screen.dart`：开局选择界面（身份/家族/出生地/时代/季节），含角色生成纯函数。
- `systems_screen.dart`：世界系统面板。

### services/
- `ai_config.dart`：AI 配置（API Key/模型/BaseURL）的 SharedPreferences 读写。
- `ai_service.dart`：AI 叙事与选项生成（Dio 调 chat/completions，指数退避重试，JSON 解析）。
- `event_service.dart`：事件效果计算与存档（EventEffectResult）。
- `save_service.dart`：存档序列化/读写/列表/删除/导出导入（JSON 文件）。

### utils/
- `labels.dart`：身份/季节/事件类型中文文案统一映射。
- `narrative_format.dart`：叙事分段/效果中文标签/选项序号工具（Batch 10-12）。
- `text_formats.dart`：ISO 时间格式化。

## 3. 模块依赖关系（谁 import 谁）

`A → B` 表示 A 引用了 B。

```
main.dart → app.dart
app.dart → screens/start_screen.dart

game_engine.dart → game_provider_base.dart
                 → mixins/* （11 个全部：adventure ai commands generation letter
                              life marriage npc_interact npc_task play systems）

providers/
  game_state_provider.dart → models/event.dart, models/player.dart
  event_provider.dart      → models/event.dart, models/player.dart
  game_provider_base.dart  → data/*（event family location npc system 5 个）
                           → models/*（event family location npc player system 6 个）
                           → event_provider.dart, game_state_provider.dart

data/* → models/*（event_data→event；family_data→family；location_data→location；
        npc_data→npc；npc_task_data→npc_task；system_data→system；
        narrative_templates→player）

models/player.dart → marital.dart, npc_task.dart（其余模型无内部依赖）

mixins/*（全部 11 个）→ providers/game_provider_base.dart
mixin 间交叉依赖：
  mixin_adventure   → mixin_life, mixin_npc_interact, mixin_npc_task, data/item_data, models/location
  mixin_ai          → mixin_life, mixin_letter, mixin_play, mixin_systems, models/event
  mixin_commands    → 其余全部 9 个 mixin + data/item_data + models/npc
  mixin_generation  → mixin_life, models/marital, models/player
  mixin_letter      →（无 mixin 依赖）models/npc
  mixin_life        →（无 mixin 依赖）data/item_data, models/location, models/player
  mixin_marriage    → mixin_generation, mixin_life, models/marital
  mixin_npc_interact→ mixin_life, models/npc
  mixin_npc_task    → mixin_life, mixin_npc_interact, data/npc_task_data, models/npc_task
  mixin_play        → mixin_generation, mixin_life, mixin_marriage,
                      mixin_npc_interact, mixin_npc_task, mixin_systems,
                      models/location, models/player
  mixin_systems     →（无 mixin 依赖）models/family, location, player, system

screens/*
  start_screen        → game_engine, data/family, data/location, models/location, models/player,
                        providers/game_state_provider, utils/labels, screens/game_screen
  game_screen         → game_engine, models/event, services/ai_config, services/ai_service,
                        utils/labels, utils/narrative_format,
                        screens/events, family, letters, map, npc_panel, player_panel, settings, systems
  family_screen       → game_engine, models/family, screens/family_tree_screen
  family_tree_screen  → game_engine, models/marital
  events/letters/map/npc_panel/player_panel/settings/systems_screen
                      → game_engine（+ 各自的 models/services/utils）
  （letters_screen 额外 → mixins/mixin_letter；settings_screen → services/ai_config, save_service, utils/text_formats）

services/
  ai_config.dart    → shared_preferences
  ai_service.dart   → dio；data/npc, npc_task, family, location, narrative_templates；
                      models/event, family, player；utils/labels
  event_service.dart → models/event, models/player
  save_service.dart  → path_provider；providers/game_state_provider

utils/
  labels.dart          → models/event, models/player
  narrative_format.dart →（无本地 import，纯顶层函数）
  text_formats.dart    →（无本地 import）
```

**依赖方向汇总（自底向上）**

```
models ← data ← providers ← mixins ← game_engine ← screens
              ↑
   utils ← screens / services ← screens
   services/ai_service → data + models + utils
   services/save_service → providers/game_state_provider
```

## 4. 入口文件与启动流程

```
lib/main.dart: main()
  └─ runApp(const WesterosApp())

lib/app.dart: WesterosApp.build
  └─ MaterialApp(title: 'WesterosLige',
                 theme: ColorScheme.fromSeed(deepOrange, useMaterial3: true),
                 home: StartScreen())          ← 首屏

lib/screens/start_screen.dart（开局选择界面，StatefulWidget）
  ├─ 状态字段：name/gender/identity/familyId/locationId/era/season/year/month
  ├─ 常量：kEras（4 时代 → 年份 281/282/283/298）、kSeasons（5 季节 → 月份 3/6/9/12/12）
  ├─ 用户点「开始游戏」→ _startGame()
  │    ├─ buildSetupPlayer(setup)  纯函数 → Player（按身份定初始金币 150/40/120/80、
  │   │                                       技能、六维属性、health 100/energy 100/hunger 60）
  │    ├─ buildSetupProgress(setup) 纯函数 → GameProgress（年/月/季/纪元）
  │    └─ GameEngine(player:…, progress:…, isGameActive: true)
  │          └─ GameEngine 构造 → GameProviderBase 构造：
  │               加载 allNpcs / allLocations / allFamilies / allSystems / allEvents
  │               （5 个 data/*.dart 全量常量）+ 创建 EventProvider
  └─ Navigator.pushReplacement → GameScreen(engine: engine)

lib/screens/game_screen.dart（游戏主界面，StatefulWidget）
  ├─ initState：engine.addListener(_onEngineChanged)；追加欢迎语 + formatPlayerPanel()（mixin_play）
  ├─ build：Scaffold
  │    ├─ AppBar ⨯ 5 个入口 IconButton → push：EventsScreen / LettersScreen /
  │   │                                 NpcPanelScreen / MapScreen / SettingsScreen
  │    ├─ _StatusBar（姓名·身份·年龄·地点 ❤️⚡🍖 年月季）
  │    ├─ _QuickCommandBar（状态/工作/训练剑术/狩猎/贸易/探索/旅行/过月 8 键）
  │    ├─ _AiModeToggle（本地/AI 模式开关）
  │    ├─ _NarrativeView（叙事输出 + _AiChoiceCard AI 选项卡）
  │    └─ _CommandInputBar（指令输入）
  ├─ 本地模式：_submitCommand → _engine.resolveCommand(input)   （mixin_commands）
  ├─ AI 模式：_runAiAction → AiConfig.load()（SharedPreferences 读取 key/model/baseUrl）
  │    └─ AiService.generateNarrative(player, worldSnapshot+行动, eventTemplates, season, year)
  │          └─ _postChat → POST {baseUrl}/chat/completions（Bearer 鉴权，systemPrompt + prompt）
  │          └─ _parseResponse → AiResponse（提取 JSON 的 narrative + choices）
  └─ 点选 AI 选项：_chooseAiOption → _engine.applyAiChoice(choice)（mixin_ai：
       效果写回玩家 + 月度推进 + 系统结算 + 信件触发）
```

**首屏渲染结论**：`main` → `WesterosApp(MaterialApp)` → `StartScreen`（开局选择）→ 用户确认后 `pushReplacement(GameScreen)` → `GameScreen` 首帧渲染 5 区块（AppBar/状态条/快捷指令/AI 开关/叙事+输入）。

## 5. TODO / FIXME / 未实现 / 占位符清单

| 位置 | 内容 | 性质 |
|---|---|---|
| `analysis_options.yaml` | `errors: todo: ignore` | 分析器配置将 todo 级忽略，代码无 TODO 告警 |
| `lib/screens/game_screen.dart:164` | 注释 `// 移除占位行` | 运行时代码：移除「（AI 思考中…）」文本行，非未实现占位 |
| `lib/services/ai_service.dart` 头注释 | 「简化版：单 Key、无重试、无多 Key 轮换。后续 Batch 可扩展为多 Key 池 + 429 退避」 | 已声明的能力缺口：多 Key 池、429 退避轮换当前未实现（该文件当前重试为指数退避 3 次，无 Key 池） |
| `docs/07_AI提示词.md:689-704` | `【时间】XXX 年·XXX 月`、`XXXX` 等 16 处占位符 | 文档内 AI 提示词模板示例占位，非代码 |

- 代码内 **无** `TODO` / `FIXME` / `XXX` / `HACK` 标记。
- 代码内 **无** `UnimplementedError` / `not implemented` / 空函数体（grep 全 lib+test+scripts+docs 无命中）。

## 6. 配置文件与数据文件

### 配置文件（格式：YAML / 文本 / git 规则）
| 文件 | 格式 | 内容 |
|---|---|---|
| `pubspec.yaml` | YAML | 包名 westeros_life_simulator、版本 0.1.0+1、SDK ≥3.12.0 / Flutter ≥3.44.0；运行时依赖 8 个（dio/provider/shared_preferences/uuid/path_provider/flutter_secure_storage/package_info_plus/cupertino_icons）；dev 依赖 flutter_lints；**无 assets、无 shaders 声明** |
| `analysis_options.yaml` | YAML | include flutter_lints；strict-casts / strict-inference / strict-raw-types；errors.todo=ignore；11 条 linter 规则（注：`- always_use_package_imports` 一行的缩进与其他规则条目不一致，属文件原样状态） |
| `.gitignore` | git 规则 | 忽略 .dart_tool/build/pubspec.lock/.env/*.key/*.pem/**docs/HANDOVER.md** 等 |
| `.github/workflows/ci.yml` | YAML（GitHub Actions） | main 分支 push/PR + workflow_dispatch；job：checkout → flutter-action(stable) → pub get → `flutter analyze --no-fatal-infos` → `flutter test --coverage` → 上传 coverage/lcov.info |
| `scripts/gitdata_push.py` | Python | 252 行：git push 替代脚本（走 GitHub Git Data API） |

### 运行时配置存储（非文件，SharedPreferences 键值）
- `lib/services/ai_config.dart`：3 个键 `ai_api_key` / `ai_model` / `ai_base_url`；默认 `sensenova-6.8-flash-lite`、`https://token.sensenova.cn/v1`、key 为空；`isConfigured` = key 非空。

### 数据文件（均为 Dart 源码 const 字面量，位于 `lib/data/`，非独立 JSON/文本）
| 文件 | 内容规模 | 格式 |
|---|---|---|
| `event_data.dart` | 72 个事件、218 处 EventChoice | `const List<GameEvent> allEvents = [...]`（模型构造字面量） |
| `family_data.dart` | 26 家族 | `const List<Family> allFamilies` |
| `location_data.dart` | 68 地点 | `const List<Location> allLocations` |
| `npc_data.dart` | 36 NPC | `const List<Npc> allNpcs` |
| `system_data.dart` | 74 系统 | `const List<GameSystem> allSystems` |
| `item_data.dart` | 物品词典（34 物品） | const 物品定义 + 标签映射 |
| `narrative_templates.dart` | 10 身份/12 区域/5 季节引导 | const 模板表 |
| `npc_task_data.dart` | 32 个任务模板 | const 模板列表 |

### 存档格式（JSON 文件）
- `lib/services/save_service.dart`：目录 = 应用文档目录 `/saves/`，文件名 `save_{id}.json`；
- 结构 = `{ "metadata": {saveId, playerName, saveTime(ISO), year, month, turnCount},
             "state":    {player, progress, history[], currentEvent?, isGameActive, isGameOver} }`；
- 各模型实现 `toJson()` / `fromJson()`（Player/GameProgress/GameEvent/EventChoice/SpouseDetail/ChildRearing/GenerationRecord/NpcTaskProgress 等）。

### 文档型数据（docs/*.md，wiki 性质，非运行时加载）
- 9 份百科/设计 + CODE_MAP + HANDOVER：01 世界、02 家族、03 地点、04 NPC、05 系统、06 事件、07 AI 提示词、08 玩法设计；CODE_MAP.md 为代码导航索引（v1.3）；HANDOVER.md 为跨对话接力锚点（v23.0，不入 git）。
