# 整改路线图 M1~M6（02-roadmap）

> 基于 docs/01-review.md · 排序原则：先修地基再盖楼；每个里程碑结束项目可运行；互不依赖的可并行。

---

## M1 · 存档契约（版本号 + 迁移 + 防御式解析）

**目标**：任何旧存档在新版本上要么正常加载、要么明确迁移、要么安全拒绝，绝不静默产出半残状态。

**涉及文件**
- `lib/services/save_service.dart`（改）：metadata 加 `schemaVersion`；读档全链路 try/catch + 坏档改名备份 `.corrupted`
- `lib/models/*.dart` 8 个模型（改）：fromJson 全部防御式
- `lib/services/save_migration.dart`（新建）：迁移函数表 `Map<int, MigrationFn>` 链式升级
- `lib/screens/settings_screen.dart`（改）：导入存档先过 schemaVersion 校验
- `test/m1_save_migration_test.dart`（新建）

**依赖**：无（第一个做）。

**边界**：不做存档压缩/加密/云同步；不为存量坏档写修复工具；不动 state 业务结构（history 截断归 M2）。

**完成态**：存档进入"有契约"时代。可演示：手工删婚姻/谱系字段的旧 JSON 导入后正常开局；损坏 JSON 导入友好提示且不影响其他存档。

---

## M2 · 状态权威与身份正确性

**目标**：状态变更只有一个入口、时间推进只有一条路径；关闭 identity 中英文不匹配隐患。

**涉及文件**
- `lib/models/player.dart`（改）：PlayerIdentity 加 `displayName`；全库 grep mixin_*/event_provider 中文身份串匹配点改枚举比较
- `lib/providers/game_provider_base.dart`（改）：公共状态变更收口 update* 方法族
- `lib/services/world_clock.dart`（新建）：唯一 `advanceMonth()` 权威入口，mixin_play 与 mixin_ai 两处推进合并
- `lib/providers/game_state_provider.dart`（改）：history 环形上限 + 超限摘要行
- `test/m2_identity_branch_test.dart`（新建）：断言每个身份至少命中一次专属分支

**依赖**：M1 之后（history 截断改 state 结构，迁移表须先就位）。

**边界**：不重构 mixin 间依赖（归 M3）；不调任何数值；不做 i18n。

**完成态**：商人开局可触发商人专属分支（此前从未触发）；连过 24 月存档体积不再线性膨胀；AI 结算与本地"过月"走同一推进路径。

---

## M3 · 架构解耦（指令注册表 + 月度结算管线 + UI 收口）

**目标**：拆 mixin_commands 超级扇入与 mixin_play 顺序硬编码；新增玩法从"改 N 处"降为"自注册 1 处"。

**涉及文件**
- `lib/mixins/mixin_commands.dart`（改）：分发表 → 注册表（各 mixin 暴露 `Map<String, CommandHandler> commands`）
- `lib/mixins/mixin_play.dart`（改）：月度结算 → 有序 `List<MonthlyHook>` 管线
- `lib/screens/game_screen.dart`（改）：AI 编排下沉 mixin_ai；拆 widgets/ 子组件（状态条/快捷栏/叙事区/输入栏），瘦身至 ~300 行
- `lib/screens/letters_screen.dart`（改）：移除对 mixin_letter 直接 import
- `test/m3_registry_test.dart`（新建）：注册表完整性（每指令有 handler、无重复注册）

**依赖**：M2 之后（注册表注册的是 M2 收口后的方法族与 world_clock）。

**边界**：不引入 DI 框架；不改任何玩法行为与 UI 视觉（纯结构重构，测试全绿即验收）；不拆 data 层。

**完成态**：现场演示新增"钓鱼"玩法——一个新 mixin 文件 + 一行 with + 自注册指令 + 挂月度 hook，不改 commands/play/engine 内部逻辑即可玩。

---

## M4 · 内容管道与数值配置（schema 外置 + 双真相合并 + balance 集中）

**目标**：内容与数值从代码解放；docs 百科与 lib/data 收敛单一真相源；调平衡不再全库 grep。

**涉及文件**
- `assets/data/`（新建）：events/families/locations/npcs/systems/items/tasks 迁 JSON（schema 含 weight/condition 字段）；schema 规范见 `docs/specs/content-schema.md`
- `pubspec.yaml`（改）：补 assets 声明
- `scripts/check_content_sync.py`（新建）：docs 百科 ↔ JSON 对账，挂入 `.github/workflows/ci.yml`
- `lib/data/*.dart`（改）：从手写 const 改为 asset 加载解析，保留 allEvents 等对外 API 签名，mixins 零改动
- `lib/data/balance_data.dart`（新建）：初始金币/六维/生存消耗/事件效果区间全集中
- `lib/services/ai_service.dart`（改）：prompt 注入预算——按在场/活跃相关度筛选，替代全量快照
- `test/m4_balance_sim_test.dart`（新建）：headless 跑 120 个月断言资源曲线不爆炸不枯竭

**依赖**：M1 之后（事件 schema 变化影响存档 currentEvent，迁移表须能处理）；M3 之后（data 加载方式变化落在收口后架构里最干净）。**与 M5 可并行**（交集仅 ai_service，约定 M4 先合入）。

**边界**：不做可视化内容编辑器；不做 AI 多 Key 池；docs 文学性内容不删只对账数据字段；i18n 仍不做（JSON 化已天然留位）。

**完成态**：只改 `assets/data/events.json` 加新事件（含权重与触发条件），不改一行 Dart，热重启即可触发；仿真测试输出 120 个月资源曲线报告。

---

## M5 · 体验层（UI 适配 + 长会话 + AI 失败降级）

**目标**：从"功能正确"推到"长时间游玩体验合格"。

**涉及文件**
- `lib/screens/widgets/_NarrativeView`（改）：ListView.builder 懒加载，渲染成本与回合数脱钩
- `lib/screens/*`（改）：game_screen / player_panel / family_tree 补 MediaQuery 断点适配
- `lib/services/ai_service.dart` + `lib/mixins/mixin_ai.dart`（改）：重试耗尽自动回本地模式 + 明确提示，不留"AI 思考中"死状态
- `lib/screens/game_screen.dart`（改）：AppBar 入口改导航抽屉/宫格
- golden test（小屏/宽屏）+ 200 条叙事长会话 widget test（新建）

**依赖**：M3 之后（落在拆分后的组件上做）。**与 M4 可并行**。

**边界**：不做美术/动画/音效；不做横屏专属布局；不加新玩法。

**完成态**：200 回合叙事流畅滚动；AI 断网连续操作有降级提示且可本地续玩；导航扩展至 7+ 入口不拥挤。

---

## M6 · 健壮性收官与工程规范

**目标**：收口剩余 P2，把隐性约定变显式护栏。

**涉及文件**
- `analysis_options.yaml`（改）：修 always_use_package_imports 缩进，确认 11 条规则全生效
- `mixin_commands` 注册表（改）：输入防护——超长截断、空白/符号输入统一兜底
- `lib/utils/labels.dart`（改）：文案集中层改可替换资源接口（仍中文，仅隔离）
- `test/regression/`（新建）：跨批次回归套件（旧档加载/身份分支/注册表完整性/仿真曲线/长会话）
- `docs/CODE_MAP.md` + `docs/PROJECT_MAP.md`（同步）；`docs/HANDOVER.md`（记录新坑）

**依赖**：M1~M5 全部之后。

**边界**：不实际做 i18n 翻译；不扩张 lint 规则数；不重构批次测试组织。

**完成态**：CI regression 独立成 job；lint 零警告；垃圾输入全部友好兜底；审查报告 P0/P1 全部关闭。

---

# 依赖关系图

```
M1 存档契约
 │
 ▼
M2 状态权威与身份正确性
 │
 ▼
M3 架构解耦 ──────────┐
 │                    │
 ├──────► M4 内容管道与数值配置
 │                    │（M4 与 M5 可并行，
 ▼                    │  仅 ai_service 一处交集，
M5 体验层 ◄───────────┘  约定 M4 先合入）
 │
 ▼
M6 健壮性收官（依赖全部前置）
```

**关键路径**：M1 → M2 → M3 → (M4 ∥ M5) → M6。M1/M2/M3/M6 必须串行，M4/M5 是唯一并行窗口。

**独立可运行保障**：M1/M2 以现有测试+新增回归全绿验收；M3 纯行为保持重构；M4 保留 data 层 API 签名；M5 只动表现层；M6 只加护栏。任何一轮中断，项目停在完整可用状态。

**体量参考**：M1 最小（约 1 批次）；M3 最重（约 2 批次）；M4 次之；M2/M5/M6 各约 1 批次。M3 前后各留一个缓冲批次吸收回归。