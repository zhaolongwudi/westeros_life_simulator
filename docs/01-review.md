# 维斯特洛人生模拟器 · 全景审查报告（01-review）

> 生成日期：2026-09-28 · 基于 docs/PROJECT_MAP.md（HEAD `ef46220`，lib 16080 行 / test 6614 行 / 43 测试文件）
> 角色：首席架构师审查 · 12 维度 · 问题按 P0（阻塞）/ P1（重要）/ P2（优化）分级

---

> ## ⚠️ 本文档是**带日期的历史快照**，不是当前状态
>
> 生成于 2026-09-28（HEAD `ef46220`）。此后经历了 M1~M4 与外部审查整改，
> 下列数字与结论**许多已过时**。**当前状态以 `docs/03-看板.md` 与 `docs/03-审查接力.md` 第 3 节为准**
> （24 条问题的实时状态表 + 已完成卡片的执行记录）。
>
> | 快照里的数字 | 当时 | 当前（S3-4 实测） |
> |---|---|---|
> | lib 行数 | 16080 | 约 20000+ |
> | 测试文件 | 43 | **118** |
> | 测试用例 | 458+ | **1260** 全绿 |
> | 事件 | 72 | **71**（S3-4 删 1 条重复） |
> | 系统 | 74 | **73**（S3-4 删 1 条重复） |
> | 实体总数 | 380+ | **313**（27+69+38+73+33+71+72 任务模板） |
>
> 「当前最致命的 3 个问题」的状态：
>
> | # | 问题 | 状态 |
> |---|---|---|
> | 🥇 | 存档无版本号 + 无迁移机制（P0） | ✅ **已关闭** —— M1 已加 `schemaVersion` 与 `save_migration.dart`，另见 P1-01 |
> | 🥈 | 身份判断中英文不匹配（P1） | ✅ **已关闭** —— M2 已统一为英文 `.name` 匹配 |
> | 🥉 | 内容与代码同构 + docs 双真相（P1） | 🚧 **进行中** —— 即 P1-01；docs 侧已由 S3-1/S3-2/S3-3/S3-4 显著收敛（schema 对账 + 名称对账 + 生成区块三道 CI 闸门），但数据外置（S4-4）未做 |

---

## 1. 架构分层

> **当前状态（S3-4 实测）**：✅ **已改善** —— 11 个 mixin 仍是超级扇入点（`mixin_commands.dart` 依赖其余全部），但已抽出 `core/command_registry.dart` 注册表解耦；`P1-07` 已关闭。


**现状**：`models ← data ← providers ← mixins ← game_engine ← screens` 单向依赖无环；providers 为状态载体，11 个 mixin 承载全部玩法逻辑。

**问题**
- **P0**：`lib/mixins/mixin_commands.dart`（401 行）依赖其余全部 9 个 mixin，是超级扇入点；任何 mixin 加方法都要同步维护指令分发表。
- **P1**：`lib/mixins/mixin_play.dart` 依赖 6 个 mixin，月度循环把六个子系统结算顺序硬编码在一个方法里。
- **P1**：`lib/screens/game_screen.dart`（709 行）直接依赖 `services/ai_config` + `services/ai_service` 并自拼调用流程，UI 层越过 mixin 直达 service。
- **P2**：`lib/screens/letters_screen.dart` 直接 import `mixins/mixin_letter.dart`，破坏 screens→engine 单向约定。

**建议方向**：commands 改注册表（各 mixin 自注册）；月度循环改有序 MonthlyHook 管线；AI 调用收拢进 mixin_ai。

## 2. 状态与存档

> **当前状态（S3-4 实测）**：🚧 **部分改善** —— 入口统一到 `updatePlayer`（P2-02 已收口月度上限口径）；但 mixin 仍可直接改玩家字段，未做强制约束


**现状**：状态集中于 `providers/game_state_provider.dart`（ChangeNotifier + JSON 序列化）；`services/save_service.dart` 统一读写 `/saves/save_{id}.json`，结构 `{metadata, state}`。

**问题**
- **P0**：状态变更入口不唯一——`game_provider_base.dart` 公共能力允许 mixin 直改玩家字段（HANDOVER 坑 19 已暴露"返回新实例不上报状态"陷阱），"必须走 updatePlayer"仅是口头约定。
- **P1**：`models/player.dart`（286 行）膨胀为婚姻/任务/谱系/生存聚合体，且 player.dart → marital/npc_task，模型层出现交叉依赖。
- **P1**：时间推进分散在 `mixin_play`（月度循环）与 `mixin_ai.applyAiChoice` 两处，无唯一权威入口，存在漂移风险。
- **P2**：`history[]` 无截断策略，无限增长。

**建议方向**：Player 字段变更收口为 update* 方法族；抽唯一 `WorldClock.advanceMonth()`；history 环形上限 + 摘要压缩。

## 3. 事件系统

> **当前状态（S3-4 实测）**：🚧 **部分改善** —— 幽灵键已可见化（S2-3，78 处存量锁定基线）；42/72 空门槛事件仍未补条件（P2-03 / S4-3）
>
> 📌 **S5-1 取证更正（2026-10-07，本行数字已过期）**：「78 处」实为 **76 处**（`faith` 被多算 2 处），波及事件 **39**个（非 40）。S5-1 已把 2 个「零效果死选项」清零，现状为**74 处**（全为混合键，玩家点了有反应）。基线断言 `<=78` 因真实值 76 恒过而形同虚设，已收紧为 `<=74`。详见 `docs/archive/03-审查归档.md` Sprint 5。


**现状**：72 事件 / 218 choice 全部为 `data/event_data.dart`（2490 行）const 字面量；`event_provider.dart` 管触发/随机/可用性；`event_service.dart` 管效果计算。

**问题**
- **P1**：触发条件/权重/分支以代码结构表达，改一条文案需改代码、跑 CI、发版。
- **P1**：权重若埋在 event_provider 判定逻辑里，调平衡必须动逻辑层。
- **P2**：本地事件与 AI 叙事两套并行产出，触发优先级/互斥规则不明。

**建议方向**：事件 schema 外置 JSON asset（pubspec 当前无 assets 声明需补）；触发条件抽象为字段+阈值表达式；明确本地 vs AI 仲裁层。

## 4. 内容数据

> **当前状态（S3-4 实测）**：🚧 **部分改善** —— docs↔data 已加三道 CI 闸门（S3-1 schema 对账、S3-2 名称对账、生成区块 `--check`）；但 313 个实体仍是 Dart const，数据外置未做（P1-01 / S4-4）


**现状**：全部内容为 Dart const 字面量（72 事件 / 27 家族 / 69 地点 / 38 NPC / 74 系统 / 33 物品 / 72 任务模板），data 层 5786 行；docs 下 9 份百科 md 约 6700 行不入运行时。

**问题**
- **P1**：schema 即模型构造函数，新增内容必须会写 Dart 字面量，非技术创作者无法参与。
- **P1**：docs 百科与 lib/data 是双份真相（02_家族百科 vs family_data、06_事件库 vs 72 事件），无任何一致性校验，必然漂移。
- **P2**：narrative_templates 为 10×12×5 稀疏组合，组合缺失时降级行为不明。

**建议方向**：单一真相源 + 生成/对账脚本挂 CI；中期迁 JSON asset + schema 校验。

## 5. 数值平衡

> **当前状态（S3-4 实测）**：🚧 **部分改善** —— 概率带与经济数值已收口 `BalanceData`（S2-4）；仍无离线数值仿真，「玩100 个月期望曲线」缺失


**现状**：硬编码已知点——`start_screen.dart` 初始金币 150/40/120/80、health 100/energy 100/hunger 60；kEras 281/282/283/298；kSeasons 3/6/9/12/12。

**问题**
- **P1**：魔法数值散布 start_screen / event_data / item_data / npc_task_data 多处，无统一 balance 配置。
- **P1**：无离线数值仿真（"玩 100 个月期望曲线"），平衡只能靠手感。
- **P2**：季节→月份映射有歧义（longwinter 与 winter 同为 12），靠注释维护。
  > ✅ **已修复（S4-2，2026-10-07）**：该歧义正是 `longwinter` 不可达的根因（两者映射同一月份）。已采方案 B 清除 `longwinter`，`kSeasons` 收敛为四值，映射不再有歧义。

**建议方向**：建 `lib/data/balance_data.dart` 集中可调数值；headless 仿真测试断言资源曲线；映射改显式表。

## 6. UI/UX

> **当前状态（S3-4 实测）**：🚧 **部分改善** —— `game_screen.dart` 已拆分；叙事区仍未虚拟化，响应式适配仍无痕迹


**现状**：11 个 screen 共 3213 行，Material3；主界面 5 区块；家族树可视化已建；叙事有分段/高亮工具。

**问题**
- **P1**：`game_screen.dart` 709 行承载五块职能，UI 迭代单文件冲突。
- **P2**：无响应式/平板适配痕迹（未见 LayoutBuilder/MediaQuery）。
- **P2**：叙事区未见虚拟化列表，长会话渲染成本随回合线性上升。

**建议方向**：拆 widgets/ 子组件；叙事区改 ListView.builder；补尺寸自适应测试。

## 7. 存档兼容

> **当前状态（S3-4 实测）**：✅ **已关闭** —— M1 已加 `schemaVersion` + `save_migration.dart`；P1-01 仍开放（数据外置时需再评估）


**现状**：metadata 含 saveId/playerName/saveTime/year/month/turnCount；各模型手写 toJson/fromJson。

**问题**
- **P0**：**无 schemaVersion 字段**。Batch 10-13~10-25 每批给 Player 加字段，旧档 fromJson 缺字段行为全靠各模型容错程度，一旦必填缺失即崩或静默产出半残状态。
- **P1**：无迁移机制，字段重命名/类型变更 = 旧档即废。
- **P2**：8+ 个模型手写解析，容错不一致（一处 `as String` 强转即炸）。

**建议方向**：metadata 加 schemaVersion；fromJson 全部防御式；迁移函数表；补"旧档加载"回归测试。

## 8. 性能

> **当前状态（S3-4 实测）**：✅ **已改善** —— 458 → **1260** 用例全绿，测试文件 43 → 118；`history[]` 环形上限已加


**现状**：启动全量加载 5 个 data 常量表（固定成本，OK）；458+ tests 全绿。

**问题**
- **P1**：history 无限增长 → 存档体积线性膨胀 + 每回合全量重写，几百回合后保存延迟可感。
- **P1**：AI 模式每回合 worldSnapshot 全量注入 prompt，token 成本随内容扩充只增不减（hogwarts 项目已实锤此路径）。
- **P2**：多代家族树构建复杂度未评估。

**建议方向**：history 截断+摘要；prompt 注入预算（按相关度筛选）；存档写盘异步+脏标记。

## 9. 可测试性

> **当前状态（S3-4 实测）**：✅ **已改善** —— 1260 用例纯函数 + mixin 可脱离 UI 验证，CI analyze + test 双门禁


**现状**：**项目最强项**——43 文件 / 6614 行 / 458+ tests，核心逻辑纯函数+mixin 可脱离 UI 验证，CI analyze+test 双门禁。

**问题**
- **P2**：测试按批次组织而非功能域，找功能测试需查 CODE_MAP 映射。
- **P2**：缺数值仿真/存档兼容/长会话回归类测试。

**建议方向**：新增 `test/regression/` 跨批次回归目录，批次测试保留不动。

## 10. 工程规范

> **当前状态（S3-4 实测）**：✅ **已改善** —— CI 追加 `check_content_sync.py`（S1-2）与 `check_docs_sync.py`（S3-2）两道内容闸门


**现状**：strict-casts/inference/raw-types 全开，零 TODO/FIXME，纪律优秀；CODE_MAP + PROJECT_MAP 双导航。

**问题**
- **P1**：**零 i18n 预留**——中文文案全硬编码（labels.dart 是字符串表非 arb/intl），事件文本 2490 行内嵌中文。
- **P1（遗留隐患）**：`Player.identity.name` 返回英文枚举名（'merchant'），mixin 层大量匹配中文串（'商人'/'骑士'），身份判断可能全部静默落空——已发现、已记录、仍未修。
- **P2**：`analysis_options.yaml` 有一行缩进不一致（always_use_package_imports），lint 可能未全生效。
- **P2**：`errors.todo=ignore` 掩盖标记债；配置外置程度低。

**建议方向**：修 lint 缩进；labels 改可替换资源层；立即验证并修 identity 中英文匹配。

## 11. 健壮性

> **当前状态（S3-4 实测）**：✅ **已改善** —— `json_safe.dart` 提供 `safeInt` / `safeStr` 防御式解析；`save_service` 有损坏存档隔离


**现状**：ai_service 指数退避重试 3 次；无 UnimplementedError。

**问题**
- **P1**：`save_service.dart` 读档无 try/catch + 坏档隔离，一个坏 JSON 可能崩掉存档列表/加载流程。
- **P1**：AI 链路重试耗尽后的降级体验未定义（静默失败？卡"AI 思考中"？）；ai_service 头注释自承"单 Key、无 Key 池"。
- **P2**：指令输入对超长/特殊字符无防护；导入存档无格式校验。

**建议方向**：读档全链路 try/catch + 坏档改名备份；AI 失败显式降级本地模式+提示；导入先过 schemaVersion 校验。

## 12. 扩展性

> **当前状态（S3-4 实测）**：🚧 **部分改善** —— schema 已文档化并强制对账（S3-1）；但新增内容仍必须会写 Dart 字面量，非技术创作者无法参与


**现状**：加静态内容 = 改 1 个 data 文件；加系统 = 模型+data+mixin+commands+UI+测试约 6 处；25 个 batch10 批次证明迭代流程成熟。

**问题**
- **P1**：新 mixin 须同步 `game_engine.dart` with 顺序（坑 15）；commands 扇入使每加一个玩法都动 401 行调度器，扩展成本随 mixin 数线性上升，11 个已近上限。
- **P1**：新增事件需同改 event_data + docs/06_事件库 + 测试断言三处（双真相的扩展性体现）。
- **P2**：game_screen AppBar 5 个 IconButton 近饱和，无导航扩展结构。

**建议方向**：注册表改造治本；内容源单一生成把三处改动降为一处；导航改抽屉/宫格。

---

# 当前最致命的 3 个问题（按优先级）

## 🥇 1. 存档无版本号 + 无迁移机制（维度 7，P0）

metadata 无 schemaVersion，而 Batch 10-13~10-25 每批都在给 Player 加字段。**每个新批次都可能让所有旧存档报废或静默产出半残状态，且无任何检测手段**。对以长周期存档为核心体验的人生模拟器，这是直接摧毁用户资产信任的缺陷。修复成本极低（版本字段+防御式 fromJson+迁移表），性价比全项目最高。→ M1 处理。

## 🥈 2. 身份判断中英文不匹配隐患（维度 10，P1 遗留）

`Player.identity` 是枚举，`.name` 返回 'merchant' 等英文，mixin 层却匹配 '商人'/'骑士' 中文串——**所有按身份分支的玩法逻辑可能从未真正触发**，CI 全绿只因没有测试断言运行期分支命中。隐蔽且随婚姻/任务/事件系统加深而债务复利。唯一"已发现、已记录、未修"的正确性级隐患。→ M2 处理。

## 🥉 3. 内容与代码同构 + docs 双真相（维度 4/12，P1）

380+ 实体硬编码为 Dart const（5786 行），同时 docs 下 6700 行同主题百科零校验。内容迭代必须走完整代码-CI 流程；docs 与 data 必然漂移无人察觉；新增内容三处改动。趁 380 实体规模做外置化成本可控，翻倍后难做。这正是 hogwarts"越修越难玩"路径的早期形态。→ M4 处理。

---

**总结**：工程纪律（lint/测试/CI/文档）一流，架构分层合格；真正风险集中于**存档契约（丢用户资产）、身份判断（功能静默落空）、内容管道（长期迭代成本）**。整改路线见 docs/02-roadmap.md。
