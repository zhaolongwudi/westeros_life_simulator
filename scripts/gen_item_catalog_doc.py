#!/usr/bin/env python3
"""从 items.json 生成 docs/09_物品百科.md 的「物品总览」分档表。

【为什么补这本百科】`items.json` 有 33 个物品，而 S3-2 做 docs↔JSON 名称
覆盖对账时发现其中 **28 个在任何文档里都查不到**——项目此前根本没有物品百科，
只有 docs/05 的经济/贸易章节里零散提到 5 个（红宝石、龙骨之类）。
物品是背包、贸易、事件效果（`inventory.<itemId>`）、AI 叙事的公共输入，
缺一本可查的表意味着「内容作者没法知道有哪些物品可用」。

与「家族关系网」同一套路：**由数据生成**，避免手写腐烂。

用法：
  python3 scripts/gen_item_catalog_doc.py          # 就地重写标记块
  python3 scripts/gen_item_catalog_doc.py --check  # 只比对，不一致退出 1
"""
import io
import json
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOC = os.path.join(REPO, "docs", "09_物品百科.md")
ITEMS = os.path.join(REPO, "assets", "data", "items.json")

BEGIN = "<!-- GEN:item-catalog -->"
END = "<!-- /GEN:item-catalog -->"

CATEGORY_ZH = {
    "consumable": "消耗品",
    "weapon": "武器",
    "armor": "护甲",
    "material": "材料",
    "treasure": "珍宝",
    "relic": "圣物",
    "document": "文书",
    "mount": "坐骑",
}
# 展示顺序：按玩法认知排，而不是按枚举定义顺序
CATEGORY_ORDER = [
    "weapon", "armor", "mount", "consumable",
    "material", "treasure", "relic", "document",
]

EFFECT_ZH = {
    "hunger": "饱腹",
    "health": "生命",
    "energy": "精力",
    "gold": "金币",
}


def render():
    with io.open(ITEMS, encoding="utf-8") as f:
        items = json.load(f)
    by_cat = {}
    for it in items:
        by_cat.setdefault(it["category"], []).append(it)

    parts = []
    parts.append("## 二、物品总览（按分类）")
    parts.append("")
    parts.append(
        "> 本节由 `python3 scripts/gen_item_catalog_doc.py` 从 `items.json` "
        "**自动生成**，请勿手改。"
    )
    parts.append(
        "> `value` 为金币基准价（`Item.value`）；`usable=true` 的物品可主动使用，"
        "效果见 `useEffect`（键体系与事件效果键一致，见 `docs/specs/content-schema.md` §4）；"
        "`requiresSkill` 非空表示需要对应技能才能使用。"
    )
    parts.append("")
    parts.append("共 **%d** 个物品，分布在 %d 个分类中。" % (len(items), len(by_cat)))
    parts.append("")

    for cat in CATEGORY_ORDER:
        group = sorted(by_cat.get(cat, []), key=lambda x: (-x["value"], x["name"]))
        if not group:
            continue
        parts.append("### %s（%d）" % (CATEGORY_ZH.get(cat, cat), len(group)))
        parts.append("")
        parts.append("| 物品 | id | 基准价 | 可堆叠 | 可用 | 使用效果 | 需要技能 | 说明 |")
        parts.append("|---|---|---|---|---|---|---|---|")
        for it in group:
            eff = it.get("useEffect") or {}
            if eff:
                eff_s = "、".join(
                    "%s %+d" % (EFFECT_ZH.get(k, k), v) for k, v in eff.items())
            else:
                eff_s = "—"
            parts.append("| %s | `%s` | %d | %s | %s | %s | %s | %s |" % (
                it["name"], it["id"], it["value"],
                "是" if it.get("stackable") else "否",
                "是" if it.get("usable") else "否",
                eff_s,
                it.get("requiresSkill") or "—",
                it.get("description") or "—",
            ))
        parts.append("")

    return "\n".join(parts).rstrip()


def main():
    check = "--check" in sys.argv
    if not os.path.exists(DOC):
        print("[FAIL] %s 不存在" % DOC)
        return 1
    src = io.open(DOC, encoding="utf-8").read()
    pat = re.compile(re.escape(BEGIN) + r".*?" + re.escape(END), re.S)
    if not pat.search(src):
        print("[FAIL] %s 中找不到生成标记 %s / %s" % (DOC, BEGIN, END))
        return 1
    gen = render()
    new = pat.sub(BEGIN + "\n" + gen + "\n" + END, src)
    if check:
        if new == src:
            print("[OK] 物品总览与 items.json 一致")
            return 0
        print("[FAIL] 物品总览已过期，请运行：python3 scripts/gen_item_catalog_doc.py")
        return 1
    io.open(DOC, "w", encoding="utf-8").write(new)
    print("[GEN] 已重写 %s 的物品总览块（%d 字符）" % (DOC, len(gen)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
