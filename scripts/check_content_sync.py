#!/usr/bin/env python3
"""M4c 内容对账脚本：assets/data JSON ↔ lib/data Dart 双向一致性。

设计：
- Dart 数据文件是运行时真相源（623 测试依赖）。
- assets/data/*.json 是内容外置资产（M4c-1 由 dart_content_extract.py 生成）。
- 本脚本在 CI 中跑（挂 analyze-and-test 之后），防止 JSON 落后 Dart / 引用断裂。

⚠️ 本脚本**不校验 docs**（历史 docstring 曾声称「docs ↔ assets ↔ dart 三方对账」，
属虚称，2026-10-07 S1-2 已订正）。docs 与数据的一致性目前靠人工维护，
见 docs/03-审查接力.md 的 S3-2（建议改为脚本生成 + CI 对账）。

校验项：
1. JSON 文件存在且可解析。
2. 每域 JSON 实体 id 集合 == Dart 侧 id 集合（JSON 不落后、不多余、无重复）。
3. **内容比对**：JSON 每个实体与「现场从 Dart 解析出的实体」逐字段 dict 相等
   （只比 id 集合会让「改了 Dart 字段值但没重跑导出」静默溜过）。
4. 跨域引用完整性：npc.familyId -> families；npc.locationId -> locations；
   family.seat -> locations；location.connectedTo -> locations；event.choices[].effects 中
   扁平键 relations.{npcId} -> npcs；tasks.npcId -> npcs；location.specialtyItemIds -> items。
5. 关键字段非空：name/title/description 等必填文本。
6. **镜像字段契约**：npcs.json 的 mood 必须是字符串、tasks 必须是列表。
   第 3 项是「同源自证」（JSON 本就由 load_entities 生成），抓不到
   dart_content_extract.py 自身的字段映射缺失——P1-01 的 mood/tasks 漂移就是这么溜过
   去的，故此处单独设卡。

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
from dart_content_extract import load_entities, JSON_FILES  # noqa: E402


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

    for fam in _load_json("families.json"):
        seat = fam.get("seat", "")
        if seat and seat not in loc_ids:
            errors.append(f"[FAIL] families.json {fam['id']}: seat {seat} 不存在于 locations.json")

    for loc in _load_json("locations.json"):
        for c in loc.get("connectedTo", []):
            if c not in loc_ids:
                errors.append(f"[FAIL] locations.json {loc['id']}: connectedTo {c} 不存在于 locations.json")
        for s in loc.get("specialtyItemIds", []):
            if s not in item_ids:
                errors.append(f"[FAIL] locations.json {loc['id']}: specialtyItemIds {s} 不存在于 items.json")

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

    if not quiet:
        for w in warns:
            print(w)
        if errors:
            print("\n".join(errors))
        print(f"\n结论: {'❌ 失败 ' + str(len(errors)) + ' 项' if errors else '✅ 全部通过'}")
    return 0 if not errors else 1


if __name__ == "__main__":
    quiet = "--quiet" in sys.argv
    sys.exit(check(quiet=quiet))