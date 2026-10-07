#!/usr/bin/env python3
"""M4c 内容对账脚本：assets/data JSON ↔ lib/data Dart 双向一致性。

设计：
- Dart 数据文件是运行时真相源（623 测试依赖）。
- assets/data/*.json 是内容外置资产（M4c-1 由 dart_content_extract.py 生成）。
- 本脚本在 CI 中跑（挂 analyze-and-test 之后），防止 JSON 落后 Dart / 引用断裂。

⚠️ 本脚本**不校验 docs**（历史 docstring 曾声称「docs ↔ assets ↔ dart 三方对账」，
属虚称，2026-10-07 S1-2 已订正）。docs 与数据的一致性目前靠人工维护，
见 docs/archive/03-审查归档.md 的 S3-2（建议改为脚本生成 + CI 对账）。

校验项：
1. JSON 文件存在且可解析。
2. 每域 JSON 实体 id 集合 == Dart 侧 id 集合（JSON 不落后、不多余、无重复）。
3. **内容比对**：JSON 每个实体与「现场从 Dart 解析出的实体」逐字段 dict 相等
   （只比 id 集合会让「改了 Dart 字段值但没重跑导出」静默溜过）。
4. 跨域引用完整性：npc.familyId -> families；npc.locationId -> locations；
   family.seat -> locations；location.connectedTo -> locations；event.choices[].effects 中
   扁平键 relations.{npcId} -> npcs；tasks.npcId -> npcs；location.specialtyItemIds -> items。
5. 关键字段非空：name/title/description 等必填文本。
6. **镜像字段契约**：npcs.json 的 mood 必须是字符串、tasks 必须是列表；
   locations.json 的 governorId 必须是 JSON null 或 npc_ 开头的 id；
   枚举字段必须是裸枚举名（不能带 `EventType.` 前缀）。
   第 3 项是「同源自证」（JSON 本就由 load_entities 生成），抓不到
   dart_content_extract.py 自身的字段映射缺失——P1-01 的 mood/tasks 漂移就是这么溜过
   去的，故此处单独设卡。
7. **内容规范 checklist 1-6**（docs/specs/content-schema.md 文末）：
   id 前缀/唯一、引用完整性、选项数与无条件选项、数值上下界、门槛键白名单、文本长度。
   2026-10-07 S3-1 挂入，此前这 6 条只写在文档里、没有任何代码执行过——
   结果文档里的字段表与真实模型**几乎没有一条对得上**（见 S3-1 执行记录）。

用法：
  python3 scripts/check_content_sync.py          # 校验，失败退出 1
  python3 scripts/check_content_sync.py --quiet  # 只打印结论行
"""
import json
import os
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSET_DIR = os.path.join(REPO, "assets", "data")
DATA_DIR = os.path.join(REPO, "lib", "data")

# 复用导出器的 Dart 解析（避免双实现）
sys.path.insert(0, os.path.join(REPO, "scripts"))
import dart_content_extract as dce  # noqa: E402
from dart_content_extract import load_entities, JSON_FILES, ID_PREFIX  # noqa: E402


# ============ docs/specs/content-schema.md checklist 1-6 的机器实现 ============
# 【键白名单的唯一真相】两份：EventChoice.requirements 由
# `EventProvider.canChoose` / `EventService.canChoose` 消费（两通道键集相同），
# GameEvent.triggerConditions 由 `lib/core/event_trigger_eval.dart` 消费。
# 白名单外的键 = 死门槛（恒放行）或死标记，写进数据等于骗自己。
REQ_KEYS_EXACT = {
    "gold", "reputation", "health", "energy", "hunger", "flag",
}
REQ_KEY_PREFIXES = ("skills.", "attributes.", "hasItem.")

TRIGGER_KEYS_EXACT = {
    "season", "locationId", "familyId", "identity",
    "minAge", "maxAge", "minGold", "minReputation",
    "minHealth", "maxHealth", "minEnergy", "maxEnergy",
    "minHunger", "maxHunger", "flag", "noFlag", "isAlive",
}
TRIGGER_KEY_PREFIXES = ("hasItem.", "skills.", "attributes.")
TRIGGER_NUMERIC_KEYS = {
    "minAge", "maxAge", "minGold", "minReputation",
    "minHealth", "maxHealth", "minEnergy", "maxEnergy",
    "minHunger", "maxHunger",
}
SEASONS = {"spring", "summer", "autumn", "winter", "longwinter", "any"}

# 数值/文本上下界（取自 2026-10-07 全量数据的真实极值 + 余量，见 S3-1 执行记录）
GOLD_HARD_LIMIT = 500      # 现状极值（家族灭亡 -500 / 铁金库还债 -500 / 贸易繁荣 +400）
GOLD_SOFT_LIMIT = 200      # 建议带；超过需在事件注释里说明是刻意设计
STAT_DELTA_LIMIT = 5       # 属性/技能单次 |delta|
NAME_MAX = 16              # 事件名（现状 max 9）
DESC_MIN, DESC_MAX = 4, 120  # 事件描述（现状 4~40）
CHOICE_TEXT_MAX = 24       # 选项文案（现状 max 7）
NARRATIVE_MIN = 6          # 选项结果叙事（现状 min 10）


def _load_json(name):
    path = os.path.join(ASSET_DIR, name)
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def check(quiet=False):
    errors = []
    warns = []

    # 1. 逐域：JSON 与 Dart id 集合一致性
    for domain, json_name in JSON_FILES.items():
        jpath = os.path.join(ASSET_DIR, json_name)
        if not os.path.exists(jpath):
            errors.append(f"[FAIL] {json_name} 不存在（先跑 python3 scripts/dart_content_extract.py）")
            continue
        try:
            json_data = _load_json(json_name)
        except Exception as e:
            errors.append(f"[FAIL] {json_name} 解析失败: {e}")
            continue
        dart_entities = load_entities(domain)
        dart_ids = {e["id"] for e in dart_entities}
        json_ids = {e["id"] for e in json_data}
        if len(dart_ids) != len(dart_entities):
            errors.append(f"[FAIL] {json_name}: Dart 侧 id 重复（{len(dart_entities)} 条 vs {len(dart_ids)} 唯一）")
        if len(json_ids) != len(json_data):
            errors.append(f"[FAIL] {json_name}: JSON 侧 id 重复")
        missing = sorted(dart_ids - json_ids)
        extra = sorted(json_ids - dart_ids)
        if missing:
            errors.append(f"[FAIL] {json_name}: JSON 缺少 {len(missing)} 个 id: {missing[:8]}")
        if extra:
            warns.append(f"[WARN] {json_name}: JSON 多出 {len(extra)} 个 id: {extra[:8]}")
        # 2. 内容比对：JSON 实体 == 现场解析出的 Dart 实体
        dart_map = {e["id"]: e for e in dart_entities}
        drifted = []
        for ent in json_data:
            src = dart_map.get(ent.get("id"))
            if src is None or ent == src:
                continue
            keys = sorted({k for k in set(ent) | set(src) if ent.get(k) != src.get(k)})
            drifted.append(f"{ent.get('id')}: 字段 {keys[:6]}"
                           f"（JSON={ {k: ent.get(k) for k in keys[:3]} }"
                           f" Dart={ {k: src.get(k) for k in keys[:3]} }）")
        if drifted:
            errors.append(
                f"[FAIL] {json_name}: {len(drifted)} 条内容与 Dart 不一致"
                f"（改了 lib/data/*.dart 未重跑 dart_content_extract.py？）：\n  "
                + "\n  ".join(drifted[:10])
            )
        if not quiet:
            print(f"[{len(dart_ids)}] {json_name}: Dart={len(dart_ids)} JSON={len(json_ids)}"
                  f"{' OK' if not missing and not extra and not drifted else ' DIFF'}")

    # 3. 跨域引用完整性（JSON 侧）
    fam_ids = {e["id"] for e in _load_json("families.json")}
    loc_ids = {e["id"] for e in _load_json("locations.json")}
    npc_ids = {e["id"] for e in _load_json("npcs.json")}
    item_ids = {e["id"] for e in _load_json("items.json")}

    for npc in _load_json("npcs.json"):
        fid = npc.get("familyId", "")
        if fid and fid not in fam_ids:
            errors.append(f"[FAIL] npcs.json {npc['id']}: familyId {fid} 不存在于 families.json")
        lid = npc.get("locationId", "")
        if lid and lid not in loc_ids:
            errors.append(f"[FAIL] npcs.json {npc['id']}: locationId {lid} 不存在于 locations.json")
        # S3-1 checklist 2 补全：NPC 之间的关系网
        for other in npc.get("relations", {}):
            if other not in npc_ids:
                errors.append(f"[FAIL] npcs.json {npc['id']}: relations 键 {other} 不存在于 npcs.json")
            elif other == npc["id"]:
                errors.append(f"[FAIL] npcs.json {npc['id']}: relations 自指")

    for fam in _load_json("families.json"):
        seat = fam.get("seat", "")
        if seat and seat not in loc_ids:
            errors.append(f"[FAIL] families.json {fam['id']}: seat {seat} 不存在于 locations.json")
        # S3-1 checklist 2 补全：家族关系网（家族敌友是「政治」类事件的核心输入）
        for other in fam.get("relations", {}):
            if other not in fam_ids:
                errors.append(f"[FAIL] families.json {fam['id']}: relations 键 {other} 不存在于 families.json")
            elif other == fam["id"]:
                errors.append(f"[FAIL] families.json {fam['id']}: relations 自指")

    for loc in _load_json("locations.json"):
        for c in loc.get("connectedTo", []):
            if c not in loc_ids:
                errors.append(f"[FAIL] locations.json {loc['id']}: connectedTo {c} 不存在于 locations.json")
        for s in loc.get("specialtyItemIds", []):
            if s not in item_ids:
                errors.append(f"[FAIL] locations.json {loc['id']}: specialtyItemIds {s} 不存在于 items.json")
        # S3-1 checklist 2 补全：governorId 允许为 null（56 个地点无治主）
        gov = loc.get("governorId")
        if gov is not None and gov not in npc_ids:
            errors.append(
                f"[FAIL] locations.json {loc['id']}: governorId {gov!r} 既不是 null "
                f"也不存在于 npcs.json"
            )

    # effects 是**扁平点号键**（relations.npc_xxx），不是嵌套 dict。
    # 旧版按 effects["relations"] 取值永远拿到空 dict，检查形同虚设（P3-01）。
    for evt in _load_json("events.json"):
        for choice in evt.get("choices", []):
            effects = choice.get("effects", {}) or {}
            for k in effects:
                if not k.startswith("relations."):
                    continue
                npc_id = k.split(".", 1)[1]
                if npc_id not in npc_ids:
                    errors.append(
                        f"[FAIL] events.json {evt['id']}/{choice.get('id', '?')}: "
                        f"效果键 {k} 指向不存在的 NPC"
                    )

    for task in _load_json("tasks.json"):
        nid = task.get("npcId", "")
        if nid and nid not in npc_ids:
            errors.append(f"[FAIL] tasks.json {task['id']}: npcId {nid} 不存在于 npcs.json")
        co = task.get("coNpcId", "")
        if co and co not in npc_ids:
            errors.append(f"[FAIL] tasks.json {task['id']}: coNpcId {co} 不存在于 npcs.json")
        if co and co == nid:
            errors.append(f"[FAIL] tasks.json {task['id']}: coNpcId 与 npcId 相同")

    # 4. 关键文本字段非空（events 用 name，tasks 用 title，其余用 name）
    required_name = {"families", "locations", "npcs", "systems", "items", "events"}
    for domain, json_name in JSON_FILES.items():
        if domain not in required_name:
            continue
        data = _load_json(json_name)
        key = "title" if domain == "tasks" else "name"
        for e in data:
            if not e.get(key, ""):
                errors.append(f"[FAIL] {json_name} {e.get('id', '?')}: {key} 为空")

    # 5. 镜像字段契约：抓 dart_content_extract.py 的字段映射缺失/类型错配
    #    （第 2 项内容比对是同源自证，抓不到这一类）
    bad_mood = [n["id"] for n in _load_json("npcs.json") if not isinstance(n.get("mood"), str)]
    if bad_mood:
        errors.append(
            f"[FAIL] npcs.json: {len(bad_mood)} 条 mood 不是字符串（Npc.mood 是 String，"
            f"Npc.fromJson 对 int 会抛 TypeError）：{bad_mood[:8]}"
        )
    no_tasks = [
        n["id"] for n in _load_json("npcs.json")
        if not isinstance(n.get("tasks"), list)
    ]
    if no_tasks:
        errors.append(
            f"[FAIL] npcs.json: {len(no_tasks)} 条缺 tasks 字段或类型非列表"
            f"（Dart 侧 Npc.tasks 存在，导出器未映射）：{no_tasks[:8]}"
        )
    # 契约 3（S3-1）：governorId 必须是 JSON null，而不是字符串 "null"。
    # 否则 `Location.fromJson` 拿到长度 4 的字符串，ai_service 两处
    # 「无治主」判定（== null || isEmpty）全部失效。
    bad_gov = [
        l["id"] for l in _load_json("locations.json")
        if l.get("governorId") is not None and not str(l["governorId"]).startswith("npc_")
    ]
    if bad_gov:
        errors.append(
            f"[FAIL] locations.json: {len(bad_gov)} 条 governorId 既不是 null 也不是 npc_ id"
            f"（Dart 侧 `governorId: null` 被导出成了字符串？）：{bad_gov[:8]}"
        )
    # 契约 4（S3-1）：枚举字段必须是**裸枚举名**。带 `EventType.` 前缀时
    # `GameEvent.fromJson` 会静默回落 daily，`Family/Location/Npc.fromJson`
    # 的 `byName` 直接抛 —— 镜像根本不可反序列化。
    for json_name, field in (
        ("events.json", "type"),
        ("families.json", "scale"),
        ("locations.json", "type"),
        ("npcs.json", "type"),
        ("items.json", "category"),
        ("tasks.json", "type"),
    ):
        bad_enum = [
            e["id"] for e in _load_json(json_name)
            if "." in str(e.get(field, ""))
        ]
        if bad_enum:
            errors.append(
                f"[FAIL] {json_name}: {len(bad_enum)} 条 {field} 带类名前缀"
                f"（模型的 fromJson 按裸枚举名取值，前缀会导致回落或抛错）：{bad_enum[:8]}"
            )

    # 6. docs/specs/content-schema.md 的 checklist 1-6（S3-1 挂入）
    c_err, c_warn = _check_content_rules()
    errors.extend(c_err)
    warns.extend(c_warn)

    if not quiet:
        for w in warns:
            print(w)
        if errors:
            print("\n".join(errors))
        print(f"\n结论: {'❌ 失败 ' + str(len(errors)) + ' 项' if errors else '✅ 全部通过'}"
              f"{'' if not warns else f'（另有 {len(warns)} 条警告）'}")
    return 0 if not errors else 1


def _is_known_key(key, exact, prefixes):
    return key in exact or key.startswith(prefixes)


def _check_content_rules():
    """docs/specs/content-schema.md 文末 checklist 第 1-6 条的机器实现。

    只校验 **Dart 侧解析出的实体**（`load_entities`），即运行时真相源——
    镜像 JSON 与 Dart 的一致性已由前面的第 2/3 项保证。
    """
    errors = []
    warns = []

    # ---- checklist 1：id 唯一 + 前缀规范 ----
    # 【为什么还要看未过滤的原始条数】`load_entities` 会按 id 前缀过滤实体，
    # 于是「id 写成 fam_stark」会让该家族**被静默丢弃**——id 集合对账、
    # 引用完整性全部照样通过，只有实体总数会变。这里比对过滤前后条数，
    # 把「前缀写错」从静默丢弃变成显式报错。
    for domain, (fname, _const, extractor) in dce.EXTRACTORS.items():
        with open(os.path.join(DATA_DIR, fname), encoding="utf-8") as f:
            raw = extractor(f.read())
        kept = load_entities(domain)
        dropped = len(raw) - len(kept)
        if dropped > 0:
            bad = [e.get("id") for e in raw
                   if not e.get("id", "").startswith(ID_PREFIX.get(domain, ""))]
            errors.append(
                f"[FAIL] checklist1 {fname}: {dropped} 个实体 id 前缀不是 "
                f"'{ID_PREFIX.get(domain, '')}'，被 load_entities 静默丢弃：{bad[:8]}"
            )
        seen = {}
        for e in kept:
            seen[e["id"]] = seen.get(e["id"], 0) + 1
        dup = sorted(k for k, v in seen.items() if v > 1)
        if dup:
            errors.append(f"[FAIL] checklist1 {domain}: id 重复 {dup[:8]}")

    # ---- checklist 2：引用完整性（Dart 侧） ----
    fam_ids = {e["id"] for e in load_entities("families")}
    loc_ids = {e["id"] for e in load_entities("locations")}
    npc_ids = {e["id"] for e in load_entities("npcs")}
    item_ids = {e["id"] for e in load_entities("items")}

    for fam in load_entities("families"):
        for other in fam.get("relations", {}):
            if other not in fam_ids:
                errors.append(f"[FAIL] checklist2 families {fam['id']}: relations 键 {other} 不存在")
        if fam.get("seat") and fam["seat"] not in loc_ids:
            errors.append(f"[FAIL] checklist2 families {fam['id']}: seat {fam['seat']} 不存在")

    for loc in load_entities("locations"):
        gov = loc.get("governorId")
        if gov is not None and gov and gov not in npc_ids:
            errors.append(f"[FAIL] checklist2 locations {loc['id']}: governorId {gov} 不存在")

    for evt in load_entities("events"):
        for choice in evt.get("choices", []):
            for key in choice.get("requirements", {}):
                if key.startswith("hasItem.") and key[8:] not in item_ids:
                    errors.append(
                        f"[FAIL] checklist2 events {evt['id']}/{choice.get('id', '?')}: "
                        f"门槛键 {key} 指向不存在的物品"
                    )
            for key in choice.get("effects", {}):
                if key.startswith("inventory.") and key[10:] not in item_ids:
                    errors.append(
                        f"[FAIL] checklist2 events {evt['id']}/{choice.get('id', '?')}: "
                        f"效果键 {key} 指向不存在的物品"
                    )

    # ---- checklist 3/4/5/6：逐事件 ----
    gold_over_soft = []
    for evt in load_entities("events"):
        eid = evt.get("id", "?")
        choices = evt.get("choices", [])

        # 3. 选项数 2~4，且至少一个无条件选项
        if not 2 <= len(choices) <= 4:
            errors.append(f"[FAIL] checklist3 events {eid}: 选项数 {len(choices)} 不在 2~4")
        if choices and not any(not c.get("requirements") for c in choices):
            errors.append(
                f"[FAIL] checklist3 events {eid}: 没有任何无条件选项——"
                f"玩家一旦不满足全部门槛就会被卡死在事件里"
            )
        for c in choices:
            cid = c.get("id", "?")

            # 4. 数值合规
            gold = c.get("effects", {}).get("gold", 0)
            if abs(gold) > GOLD_HARD_LIMIT:
                errors.append(
                    f"[FAIL] checklist4 events {eid}/{cid}: |gold|={abs(gold)} "
                    f"超过硬上限 {GOLD_HARD_LIMIT}"
                )
            elif abs(gold) > GOLD_SOFT_LIMIT:
                gold_over_soft.append(f"{eid}/{cid}={gold}")
            for key, val in c.get("effects", {}).items():
                if key.startswith(("attributes.", "skills.")) and abs(val) > STAT_DELTA_LIMIT:
                    errors.append(
                        f"[FAIL] checklist4 events {eid}/{cid}: {key} 的 |delta|={abs(val)} "
                        f"超过 {STAT_DELTA_LIMIT}"
                    )

            # 5. 门槛键白名单（白名单外 = 死门槛，恒放行）
            for key in c.get("requirements", {}):
                if not _is_known_key(key, REQ_KEYS_EXACT, REQ_KEY_PREFIXES):
                    errors.append(
                        f"[FAIL] checklist5 events {eid}/{cid}: 门槛键 '{key}' 不被任何 "
                        f"canChoose 实现识别（EventProvider / EventService 两通道都不认），"
                        f"写了等于没写——门槛恒成立"
                    )
            # 6. 文本长度
            if len(c.get("text", "")) > CHOICE_TEXT_MAX:
                errors.append(
                    f"[FAIL] checklist6 events {eid}/{cid}: 选项文案 "
                    f"{len(c.get('text', ''))} 字 > {CHOICE_TEXT_MAX}"
                )
            if len(c.get("narrative", "")) < NARRATIVE_MIN:
                errors.append(
                    f"[FAIL] checklist6 events {eid}/{cid}: 结果叙事 "
                    f"{len(c.get('narrative', ''))} 字 < {NARRATIVE_MIN}"
                )

        # 5（续）：事件级触发门槛键白名单
        for key, val in evt.get("triggerConditions", {}).items():
            if not _is_known_key(key, TRIGGER_KEYS_EXACT, TRIGGER_KEY_PREFIXES):
                # 运行时对未知触发键是「放行」（为兼容旧存档），故只警告
                warns.append(
                    f"[WARN] checklist5 events {eid}: 触发门槛键 '{key}' 不被 "
                    f"event_trigger_eval 识别，运行时恒放行（等于没有门槛）"
                )
            if key in TRIGGER_NUMERIC_KEYS:
                try:
                    int(str(val))
                except (TypeError, ValueError):
                    errors.append(
                        f"[FAIL] checklist5 events {eid}: 门槛 {key}='{val}' 无法解析为整数——"
                        f"运行时 int.tryParse 失败会「放行」，门槛静默失效"
                    )
            if key == "season" and str(val) not in SEASONS:
                warns.append(
                    f"[WARN] checklist5 events {eid}: season='{val}' 不在 {sorted(SEASONS)}"
                )

        # 6（续）：事件级文本长度
        if len(evt.get("name", "")) > NAME_MAX:
            errors.append(f"[FAIL] checklist6 events {eid}: 事件名 {len(evt['name'])} 字 > {NAME_MAX}")
        desc_len = len(evt.get("description", ""))
        if not DESC_MIN <= desc_len <= DESC_MAX:
            errors.append(
                f"[FAIL] checklist6 events {eid}: 事件描述 {desc_len} 字 "
                f"不在 {DESC_MIN}~{DESC_MAX}"
            )

    if gold_over_soft:
        warns.append(
            f"[WARN] checklist4: {len(gold_over_soft)} 个选项的 |gold| 超过建议带 "
            f"{GOLD_SOFT_LIMIT}（硬上限 {GOLD_HARD_LIMIT}）：{gold_over_soft[:6]}"
            f"{' …' if len(gold_over_soft) > 6 else ''}"
        )
    return errors, warns


if __name__ == "__main__":
    quiet = "--quiet" in sys.argv
    sys.exit(check(quiet=quiet))