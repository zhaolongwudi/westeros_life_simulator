# 维斯特洛人生模拟器 · 接力交接文档

> **本文档是跨对话续接的唯一锚点**。每次工作完成后必须同步更新。
> 新对话/新 AI 工具接手时，先读本文档，再执行"开始工作前请执行"章节的命令核实状态。

---

## 一、项目状态（截至 2026-09-23）

### 项目位置
- **本地**：`/root/westeros_life_simulator/`（Linux 环境）
- **远端**：`https://github.com/zhaolongwudi/westeros_life_simulator`（private）

### 阶段进度
- ✅ 阶段 1：设计文档（完成，8 份 6672 行）
- ✅ 阶段 2：AI 提示词（完成）
- ⏳ 阶段 3：代码框架（进行中）
  - ✅ Batch 1：项目骨架 + 模型层（CI 通过）
  - ✅ **Batch 2：数据层（完成，2026-09-23）**
  - ⏳ Batch 3：状态管理 + 服务层（待做）
  - ⏳ Batch 4：混入层（待做）
  - ⏳ Batch 5：UI 层（待做）

### 当前 HEAD
- **本地**：`0c72dfe`（docs: 更新 HANDOVER.md 和 README.md）
- **远端**：`7532ce1`（Git Data API 推送，与本地 0c72dfe 内容等价，SHA 不同因走 API 重建）
- **CI**：
  - run `35845625751`（commit 20432ee，HANDOVER.md 初版）
  - run `35845290631` ✅ **success**（commit 69d4abe，Batch 2 数据层）
  - run `35842365630` ✅ success（commit c765e23，README 更新）
  - run `35842155533` ✅ success（commit 0a6258d，家族数量修复）

### 已交付物

**文档（8 份，6672 行，140KB）**
- `docs/01_世界百科.md`（341 行）
- `docs/02_家族百科.md`（643 行，27 家族）
- `docs/03_地点百科.md`（616 行，68 地点）
- `docs/04_NPC百科.md`（648 行，36 NPC）
- `docs/05_系统百科.md`（1517 行，74 系统）
- `docs/06_事件库.md`（1115 行，45 事件）
- `docs/07_AI提示词.md`（1014 行）
- `docs/08_玩法设计.md`（778 行）

**代码（Batch 1 + Batch 2 完成）**
```
lib/
├── main.dart
├── app.dart
├── data/
│   ├── family_data.dart      ✅ 27 家族
│   ├── location_data.dart    ✅ 68 地点
│   ├── npc_data.dart         ✅ 36 NPC
│   ├── event_data.dart       ✅ 45 事件
│   └── system_data.dart      ✅ 74 系统
├── models/
│   ├── player.dart           ✅ Player + PlayerIdentity（10 身份）
│   ├── family.dart           ✅ Family + FamilyScale（3 规模）
│   ├── npc.dart              ✅ Npc + NpcType（11 类型）
│   ├── location.dart         ✅ Location + LocationType（11 类型）
│   ├── event.dart            ✅ GameEvent + EventChoice + EventType（9 类型）
│   └── system.dart           ✅ GameSystem（新增）
├── providers/                ❌ 待做（Batch 3）
├── mixins/                   ❌ 待做（Batch 4）
├── screens/                  ❌ 待做（Batch 5）
├── services/                 ❌ 待做（Batch 3）
└── utils/                    ❌ 待做
test/
├── batch1_smoke_test.dart              ✅ 17 用例
├── batch2_family_data_test.dart        ✅ 11 用例
├── batch2_location_data_test.dart      ✅ 6 用例
├── batch2_npc_data_test.dart           ✅ 8 用例
├── batch2_event_data_test.dart         ✅ 15 用例
└── batch2_system_data_test.dart        ✅ 15 用例
```

**配置**
- `.github/workflows/ci.yml`（analyze + test + coverage）
- `analysis_options.yaml`（strict-casts/inference/raw-types）
- `pubspec.yaml`（Flutter 3.44+，Dart 3.12+）
- `scripts/gitdata_push.py`（绕过 github.com 直连超时的 Git Data API 推送脚本）

---

## 二、关键约束（必须遵守）

### 1. 文件写入方式
- **不要用 heredoc 传中文**（shell 会破坏 UTF-8 编码）。
- 改用 `create_file` 工具或 Python 脚本。

### 2. 工具使用
- `super_admin:terminal`：执行 shell 命令（Ubuntu 环境）
- `read_file` / `list_files`：读取文件（`environment="linux"`）
- `create_file` / `edit_file`：创建/编辑文件（`environment="linux"`）

### 3. 工作流规则
1. 每批修复前先重新核实该问题确实存在
2. 每修复一批立即 commit 并 push
3. 等待 CI 构建测试（约 90 秒）
4. 有错误先修复，成功后进入下一批
5. **每批同步更新本文档（docs/HANDOVER.md）和 README.md 的处理台账**

### 4. 网络问题
- github.com 直连 DNS 常失效，但 2026-09-23 实测已恢复（git push 成功）
- 若 push 报 `Failed to connect to github.com port 443`，先测 `curl -sI https://api.github.com`
- 修法：把可用 IP（如 140.82.112.3）写进 `/etc/hosts`
- **备用方案**：`python3 scripts/gitdata_push.py HEAD heads/main`（走 Git Data API，已验证可用）
- **注意**：Git Data API 推送后远端 SHA 与本地不同（因重建 tree），但内容等价

### 5. GitHub Token
```
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
```
（已嵌入 git remote URL，无需额外配置）

### 6. 查 CI 状态
```bash
TOKEN='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'
curl -s --max-time 15 -H "Authorization: Bearer $TOKEN" \
  'https://api.github.com/repos/zhaolongwudi/westeros_life_simulator/actions/runs?per_page=3' \
  | python3 -c "import json,sys; d=json.load(sys.stdin); [print(r['id'], r['head_sha'][:7], r['status'], r['conclusion']) for r in d.get('workflow_runs',[])]"
```

### 7. 下载 CI 日志
```bash
curl -sL -H "Authorization: Bearer $TOKEN" \
  'https://api.github.com/repos/zhaolongwudi/westeros_life_simulator/actions/runs/<RUN_ID>/logs' \
  -o /tmp/ci_logs.zip
unzip -o /tmp/ci_logs.zip -d /tmp/ci_logs/
cat /tmp/ci_logs/analyze-and-test/6_Test.txt | tail -60
```

---

## 三、已踩过的坑

### 1. 家族数量
- `docs/02_家族百科.md` 表格实际 **27 行**（不是 26），测试期望值要写 27。

### 2. NPC 数量
- `docs/04_NPC百科.md` 实际 **36 个 NPC**（不是 35），测试期望值要写 36。

### 3. Dart 语法
- `factory` 不能放在 `extension` 里，必须放在 `class` 内部
- `const` 列表/Map 必须所有元素都是 `const`
- 未使用的 import 会导致 CI 报 `unused_import` warning
- 测试里不要用 `isA<List>().having(length, ...)`，先 cast 再断言

### 4. GitHub API
- 空仓库（size=0）无法用 Git Data API 创建 blob（返回 409）
- 解法：创建仓库时 `auto_init=true`，或先用 Contents API 创建初始 commit
- `git push` 报 `non-fast-forward` 时用 `--force`

### 5. 本机无 Flutter
- 无法本地运行 `flutter analyze` 或 `flutter test`
- 只能靠 GitHub Actions CI 验证
- 可用 Python 脚本检查括号平衡和 import（`/tmp/check_dart_brackets.py`）

### 6. git push 超时
- `git push origin main` 经常卡住（github.com 直连不稳定）
- **优先用 `python3 scripts/gitdata_push.py HEAD heads/main`**（已验证可用）
- 推送后远端 SHA 与本地不同（因重建 tree），但内容等价

---

## 四、下一步：Batch 3 状态管理 + 服务层

### 待做文件

1. **`lib/providers/game_state_provider.dart`**（游戏状态管理）
   - 使用 ChangeNotifier 或 Riverpod
   - 管理玩家状态、当前事件、游戏进度
   - 提供状态更新方法

2. **`lib/providers/event_provider.dart`**（事件管理）
   - 事件触发逻辑
   - 事件选项处理
   - 事件效果应用

3. **`lib/services/ai_service.dart`**（AI 服务）
   - 调用 AI 生成叙事
   - 调用 AI 生成选项
   - 参考 `docs/07_AI提示词.md`

4. **`lib/services/event_service.dart`**（事件服务）
   - 事件触发条件检查
   - 事件效果计算
   - 事件存档

5. **`lib/services/save_service.dart`**（存档服务）
   - 游戏状态序列化
   - 存档读写
   - 存档恢复

6. **测试文件**
   - `test/batch3_game_state_provider_test.dart`
   - `test/batch3_event_provider_test.dart`
   - `test/batch3_ai_service_test.dart`
   - `test/batch3_event_service_test.dart`
   - `test/batch3_save_service_test.dart`

### 提交
```bash
cd /root/westeros_life_simulator
git add -A
git commit -m 'feat(batch3): 状态管理 + 服务层完成'
python3 scripts/gitdata_push.py HEAD heads/main
```

### 等待 CI（约 90 秒）
```bash
sleep 90
TOKEN='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'
curl -s --max-time 15 -H "Authorization: Bearer $TOKEN" \
  'https://api.github.com/repos/zhaolongwudi/westeros_life_simulator/actions/runs?per_page=3'
```

### 更新文档
- 更新本文档（docs/HANDOVER.md）
- 更新 README.md 的处理台账

---

## 五、文件位置速查

- `README.md` - 项目总览 + 阶段规划 + 处理台账
- `docs/HANDOVER.md` - **本文档，跨对话续接锚点**
- `docs/01_世界百科.md` - 世界百科
- `docs/02_家族百科.md` - 家族百科（27 家族）
- `docs/03_地点百科.md` - 地点百科（68 地点）
- `docs/04_NPC百科.md` - NPC 百科（36 NPC）
- `docs/05_系统百科.md` - 系统百科（74 系统）
- `docs/06_事件库.md` - 事件库（45 事件）
- `docs/07_AI提示词.md` - AI 提示词（可直接使用）
- `docs/08_玩法设计.md` - 玩法设计
- `lib/models/` - 模型层（6 个文件，已完成）
- `lib/data/` - 数据层（5 个文件，已完成）
- `test/` - 测试（6 个文件，72 用例）
- `scripts/gitdata_push.py` - Git Data API 推送脚本

---

## 六、开始工作前请执行

```bash
cd /root/westeros_life_simulator
git status --short
git log --oneline -5
ls lib/data/
ls lib/models/
ls test/
```

**预期输出**：
- `git status` 显示工作区干净（无未提交文件）
- `git log` 显示 HEAD 为 `ab12625`（本地）或 `69d4abe`（远端）
- `lib/data/` 有 5 个文件（family/location/npc/event/system）
- `lib/models/` 有 6 个文件（player/family/npc/location/event/system）
- `test/` 有 6 个文件（batch1_smoke + batch2_family/location/npc/event/system）

---

## 七、交接信息

- **交接时间**：2026-09-23
- **交接人**：当前对话
- **接收人**：下一个对话/AI 工具
- **当前状态**：Batch 2 完成，Batch 3 待做
- **下一步**：创建 Batch 3 状态管理 + 服务层

---

## 八、快速开始

如果想先用 AI 提示词测试玩法，直接复制 `docs/07_AI提示词.md` 中的 System Prompt 到 AI 的 system 字段，然后输入【开始】即可。

如果想继续做代码框架，按上述"下一步"执行。

---

## 九、文档版本

- **版本**：v3.1
- **最后更新**：2026-09-23
- **更新人**：当前对话
- **更新内容**：Batch 2 CI 通过（run 35845290631 ✅ success），新增 Batch 3 规划

---

## 十、更新日志

| 日期 | 版本 | 更新内容 | 更新人 |
|------|------|----------|--------|
| 2026-09-23 | v3.1 | Batch 2 CI 通过，记录 CI run ID | 当前对话 |
| 2026-09-23 | v3.0 | Batch 2 完成，新增 Batch 3 规划 | 当前对话 |
| 2026-09-23 | v2.0 | Batch 2 进行中（2/5 完成） | 上一个对话 |
| 2026-09-23 | v1.0 | 初始交接文档 | 第一个对话 |

---

**重要提醒**：
1. 每次工作完成后必须同步更新本文档
2. 每次工作完成后必须同步更新 README.md 的处理台账
3. 每次工作完成后必须 commit 并 push
4. 每次工作完成后必须等待 CI 通过
5. 每次工作完成后必须记录 CI run ID 和结果