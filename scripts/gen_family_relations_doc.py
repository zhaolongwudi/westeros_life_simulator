#!/usr/bin/env python3
"""从 families.json 生成 docs/02_家族百科.md 的「家族关系网」与「家族实力」两节。

【为什么要脚本生成】这两节此前是手写的，与数据脱节：
  - 「主要联盟」写了 5 对，「主要仇敌」4 对，「主要世仇」3 对，合计 12 对；
    `families.json` 实际有 **48 条**关系，手写版**漏了 36 条**
    （P2-07 提到的"漏写 6 对达阈值关系"只是其中一部分）；
  - 且手写版的定性也和数据对不上，例如「兰尼斯特 ↔ 拜拉席恩：婚姻联盟」
    在数据里只有 **+30**（低于"主要联盟"档），而真正 +50 的
    「佛雷 ↔ 兰尼斯特」「提利尔 ↔ 拜拉席恩」里后者被写成"政治联盟"、
    前者压根没写。

手写的定性会随内容增长持续腐烂，故改为**由数据生成**，文档只保留一句
"以下由脚本生成"的说明。脚本同时提供 `--check`：生成结果与文档不一致即失败，
供 CI 调用（`scripts/check_docs_sync.py` 会转调它）。

用法：
  python3 scripts/gen_family_relations_doc.py          # 就地重写标记块
  python3 scripts/gen_family_relations_doc.py --check  # 只比对，不一致退出 1
"""
import io
import json
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOC = os.path.join(REPO, "docs", "02_家族百科.md")
FAMILIES = os.path.join(REPO, "assets", "data", "families.json")

BEGIN = "<!-- GEN:family-relations -->"
END = "<!-- /GEN:family-relations -->"

# 关系分档阈值（与「主要联盟/仇敌」的旧手写语义对齐后取的可复核值）
ALLY_MIN = 40       # ≥ 视为盟友
RIVAL_MAX = -30     # ≤ 视为仇敌
SCALE_ZH = {"great": "大家族", "minor": "小家族", "household": "家户"}


def _load():
    with io.open(FAMILIES, encoding="utf-8") as f:
        return json.load(f)


def _relation_rows(fams):
    """返回 (a_name, b_name, value) 去重后的无向边列表，按 |值| 降序。"""
    name = {f["id"]: f["name"] for f in fams}
    seen = {}
    for f in fams:
        for other, val in f["relations"].items():
            other_name = name.get(other, other)
            key = tuple(sorted((f["name"], other_name)))
            # 无向边取「绝对值更小」的一侧，保守呈现；两条等值/不等值都记录
            prev = seen.get(key)
            if prev is None or abs(val) < abs(prev):
                seen[key] = val
    rows = [(a, b, v) for (a, b), v in seen.items()]
    return sorted(rows, key=lambda r: (-abs(r[2]), r[0], r[1]))


def _asymmetry(fams):
    """找出单向/不等值的关系（A 对 B 有值，B 对 A 缺失或值不同）。"""
    by_id = {f["id"]: f for f in fams}
    name = {f["id"]: f["name"] for f in fams}
    out = []
    for f in fams:
        for other, val in f["relations"].items():
            back = by_id.get(other)
            back_val = back["relations"].get(f["id"]) if back else None
            if back_val != val:
                out.append((name[f["id"]], name.get(other, other), val, back_val))
    return sorted(out)


def render():
    fams = _load()
    rows = _relation_rows(fams)
    allies = [r for r in rows if r[2] >= ALLY_MIN]
    rivals = [r for r in rows if r[2] <= RIVAL_MAX]
    neutral = [r for r in rows if RIVAL_MAX < r[2] < ALLY_MIN]
    asym = _asymmetry(fams)

    def line(r):
        return "- %s ↔ %s：**%+d**" % (r[0], r[1], r[2])

    parts = []
    parts.append("## 十一、家族关系网")
    parts.append("")
    parts.append(
        "> 本节由 `python3 scripts/gen_family_relations_doc.py` 从 `families.json` "
        "**自动生成**，请勿手改（改了会被 CI 判为不一致）。"
    )
    parts.append(
        "> 关系值域 -100~100，存于 `Family.relations`（`Map<家族id, int>`）。"
        "下表为**无向边**：同一对家族只出现一次，取两侧绝对值较小的一侧。"
    )
    parts.append("")
    parts.append("**规模**：共 %d 个家族、%d 条有向关系 → 去重后 %d 对无向关系"
                 % (len(fams), sum(len(f["relations"]) for f in fams), len(rows)))
    parts.append("")
    parts.append("### 盟友（≥ +%d）" % ALLY_MIN)
    parts.append("")
    if allies:
        parts.extend(line(r) for r in allies)
    else:
        parts.append("（无）")
    parts.append("")
    parts.append("### 仇敌（≤ %d）" % RIVAL_MAX)
    parts.append("")
    parts.extend(line(r) for r in rivals) if rivals else parts.append("（无）")
    parts.append("")
    parts.append("### 中间地带（%d ~ +%d）" % (RIVAL_MAX + 1, ALLY_MIN - 1))
    parts.append("")
    parts.extend(line(r) for r in neutral) if neutral else parts.append("（无）")
    parts.append("")
    parts.append("### 家族实力（按影响力降序）")
    parts.append("")
    parts.append(
        "`scale` 三档：`great` 大家族 / `minor` 小家族 / `household` 家户。"
        "`influence` 是政治影响力 0-100（`Family.influence`），"
        "`army` 为可动员兵力，`goldReserve` 为金库储备。"
        "这三个字段此前在文档中**完全没有说明**（P2-07）。"
    )
    parts.append("")
    parts.append("| 家族 | 规模 | 影响力 | 人口 | 兵力 | 金库 |")
    parts.append("|---|---|---|---|---|---|")
    for f in sorted(fams, key=lambda x: (-x["influence"], x["name"])):
        parts.append("| %s | %s | %d | %d | %d | %d |" % (
            f["name"], SCALE_ZH.get(f["scale"], f["scale"]),
            f["influence"], f["population"], f["army"], f["goldReserve"]))
    parts.append("")
    if asym:
        parts.append("### ⚠️ 非对称关系（%d 条）" % len(asym))
        parts.append("")
        parts.append(
            "A 对 B 有值，但 B 对 A **缺失或值不同**。消费方目前只读单向值，"
            "所以不会崩，但「家族敌友网络」是残缺的——例如 A 视 B 为死敌、"
            "B 却对 A 毫无态度。修复方向是补对称（属 S3-2 后续 / S4-1）。"
        )
        parts.append("")
        parts.append("| 家族 A | 家族 B | A→B | B→A |")
        parts.append("|---|---|---|---|")
        for a, b, v, back in asym[:40]:
            parts.append("| %s | %s | %+d | %s |" % (
                a, b, v, "缺失" if back is None else "%+d" % back))
        if len(asym) > 40:
            parts.append("")
            parts.append("（仅列前 40 条，共 %d 条）" % len(asym))
    return "\n".join(parts)


def main():
    check = "--check" in sys.argv
    src = io.open(DOC, encoding="utf-8").read()
    pat = re.compile(re.escape(BEGIN) + r".*?" + re.escape(END), re.S)
    if not pat.search(src):
        print("[FAIL] %s 中找不到生成标记 %s / %s" % (DOC, BEGIN, END))
        return 1
    gen = render()
    new = pat.sub(BEGIN + "\n" + gen + "\n" + END, src)
    if check:
        if new == src:
            print("[OK] 家族关系网与 families.json 一致")
            return 0
        print("[FAIL] 家族关系网已过期，请运行：python3 scripts/gen_family_relations_doc.py")
        return 1
    io.open(DOC, "w", encoding="utf-8").write(new)
    print("[GEN] 已重写 %s 的家族关系网块（%d 字符）" % (DOC, len(gen)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
