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
│   ├── data/                          # 数据层（Batch 2）
│   ├── models/                        # 模型层（Batch 1 ✅）
│   │   ├── player.dart
│   │   ├── family.dart
│   │   ├── npc.dart
│   │   ├── location.dart
│   │   └── event.dart
│   ├── providers/                     # 状态管理（Batch 3）
│   ├── mixins/                        # 混入层（Batch 4）
│   ├── screens/                       # UI 层（Batch 5）
│   ├── services/                      # 服务层（Batch 3）
│   └── utils/                         # 工具
└── test/
    └── batch1_smoke_test.dart         # Batch 1 冒烟测试（17 用例）
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

#### Batch 3：状态管理 + 服务层（待做）
- lib/providers/game_state_provider.dart、event_provider.dart
- lib/services/ai_service.dart、event_service.dart、save_service.dart

#### Batch 4：混入层（待做）
- lib/mixins/mixin_play.dart、mixin_commands.dart、mixin_systems.dart、mixin_letter.dart、mixin_adventure.dart

#### Batch 5：UI 层（待做）
- lib/screens/settings/、game/、family/、map/

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
- v2.2.0：阶段 3 Batch 3 状态管理 + 服务层（待做）
- v2.3.0：阶段 3 Batch 4 混入层（待做）
- v2.4.0：阶段 3 Batch 5 UI 层（待做）
