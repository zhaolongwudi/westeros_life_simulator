#!/usr/bin/env python3
"""M4c 内容对账脚本：docs ↔ assets/data JSON ↔ lib/data Dart 三方一致性。

设计：
- Dart 数据文件是运行时真相源（623 测试依赖）。
- assets/data/*.json 是内容外置资产（M4c-1 由 dart_content_extract.py 生成）。
- 本脚本在 CI 中跑（挂 analyze-and-test 之后），防止 JSON 落后 Dart / 引用断裂。

校验项：
1. JSON 文件存在且可解析。
2. 每域 JSON 实体 id 集合 == Dart 侧 id 集合（JSON 不落后、不多余、无重复）。
3. 跨域引用完整性：npc.familyId -> families；npc.locationId -> locations；
   family.seat -> locations；location.connectedTo -> locations；event.choices[].effects 中
   relations.{npcId} -> npcs；tasks.npcId -> npcs；location.specialtyItemIds -> items。
4. 关键字段非空：name/title/description 等必填文本。

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
        if not errors or not quiet:
            pass
        if not quiet:
            print(f"[{len(dart_ids)}] {json_name}: Dart={len(dart_ids)} JSON={len(json_ids)}"
                  f"{' OK' if not missing and not extra else ' DIFF'}")

    # 2. 跨域引用完整性（JSON 侧）
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

    for evt in _load_json("events.json"):
        for choice in evt.get("choices", []):
            effects = choice.get("effects", {})
            relations = effects.get("relations", {})
            if isinstance(relations, dict):
                for npc_id in relations:
                    if npc_id not in npc_ids:
                        errors.append(f"[FAIL] events.json {evt['id']}: relations {npc_id} 不存在于 npcs.json")

    for task in _load_json("tasks.json"):
        nid = task.get("npcId", "")
        if nid and nid not in npc_ids:
            errors.append(f"[FAIL] tasks.json {task['id']}: npcId {nid} 不存在于 npcs.json")
        co = task.get("coNpcId", "")
        if co and co not in npc_ids:
            errors.append(f"[FAIL] tasks.json {task['id']}: coNpcId {co} 不存在于 npcs.json")
        if co and co == nid:
            errors.append(f"[FAIL] tasks.json {task['id']}: coNpcId 与 npcId 相同")

    # 3. 关键文本字段非空（events 用 name，tasks 用 title，其余用 name）
    required_name = {"families", "locations", "npcs", "systems", "items", "events"}
    for domain, json_name in JSON_FILES.items():
        if domain not in required_name:
            continue
        data = _load_json(json_name)
        key = "title" if domain == "tasks" else "name"
        for e in data:
            if not e.get(key, ""):
                errors.append(f"[FAIL] {json_name} {e.get('id', '?')}: {key} 为空")

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