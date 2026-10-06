#!/usr/bin/env python3
"""docs ↔ assets/data 名称覆盖对账（S3-2）。

【为什么需要这份检查】`check_content_sync.py` 只管 JSON ↔ Dart，**不管 docs**。
于是 docs 里的百科可以任意注水/漏写而无人知晓，历史上已经发生了两起：

  - **注水**：docs/04 写「NPC 100+」（实际 38）、docs/06 写「事件 100+」（实际 72）；
  - **漏写**：2 个 NPC（约恩·罗伊斯、布蕾妮·塔斯）、4 个地点（白港/巴隆镇/
    兰尼斯港/流亡之地）、28 个事件在文档里完全没有条目；
  - **虚构**：docs/03 里的夷地、阴影之地在 `locations.json` 中根本不存在。

本脚本把「数据里的每个实体名**必须**能在对应百科文档里找到」变成 CI 闸门。

【判定口径】
  - 家族 / 地点 / NPC / 事件 / 系统：**error**（有专属百科，漏写即失败）。
  - 物品：S3-2 新建了 `docs/09_物品百科.md`（此前没有物品百科，33 个物品里
    28 个在任何文档中都查不到），故也升级为 error。
  - 任务模板：不校验（`tasks.json` 面向玩法，无对应百科）。

另外转调 `gen_family_relations_doc.py --check`，保证脚本生成的
「家族关系网」一节与 `families.json` 同步（手改该节会失败）。

用法：
  python3 scripts/check_docs_sync.py          # 校验，失败退出 1（打印逐域进度）
  python3 scripts/check_docs_sync.py --quiet  # CI 用：只打印 FAIL 与结论行
"""
import io
import json
import os
import subprocess
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSET_DIR = os.path.join(REPO, "assets", "data")
DOC_DIR = os.path.join(REPO, "docs")

# 域 -> (JSON 文件, 百科文档, 是否 error 级)
DOMAINS = [
    ("families", "families.json", "02_家族百科.md", True),
    ("locations", "locations.json", "03_地点百科.md", True),
    ("npcs", "npcs.json", "04_NPC百科.md", True),
    ("systems", "systems.json", "05_系统百科.md", True),
    ("events", "events.json", "06_事件库.md", True),
    ("items", "items.json", "09_物品百科.md", True),
]


def _load(name):
    with io.open(os.path.join(ASSET_DIR, name), encoding="utf-8") as f:
        return json.load(f)


def check(quiet=False):
    errors = []
    warns = []

    all_docs = ""
    for fn in sorted(os.listdir(DOC_DIR)):
        if fn.endswith(".md"):
            all_docs += io.open(os.path.join(DOC_DIR, fn), encoding="utf-8").read()

    for domain, json_name, doc_name, is_error in DOMAINS:
        data = _load(json_name)
        if doc_name is None:
            text = all_docs
            scope = "docs/*.md（无专属百科）"
        else:
            text = io.open(os.path.join(DOC_DIR, doc_name), encoding="utf-8").read()
            scope = "docs/" + doc_name
        missing = [e["name"] for e in data if e["name"] not in text]
        if not quiet:
            print("[%d/%d] %-10s %s" % (len(data) - len(missing), len(data), domain, scope))
        if missing:
            msg = ("%s: %d/%d 个实体在 %s 中未被提及：%s"
                   % (json_name, len(missing), len(data), scope, missing[:8]))
            (errors if is_error else warns).append(
                ("[FAIL] " if is_error else "[WARN] ") + msg
                + (" …" if len(missing) > 8 else ""))

    # 脚本生成的区块必须与数据同步
    for gen_name, what in (
        ("gen_family_relations_doc.py", "家族关系网块与 families.json"),
        ("gen_item_catalog_doc.py", "物品总览块与 items.json"),
    ):
        ret = subprocess.run(
            [sys.executable, os.path.join(REPO, "scripts", gen_name), "--check"],
            capture_output=True, text=True)
        if ret.returncode != 0:
            errors.append("[FAIL] %s 不同步（%s）"
                          % (what, ret.stdout.strip().splitlines()[0]))
        elif not quiet:
            print("[OK] %s 同步" % what)

    # --quiet 也照样打印 FAIL 与结论：CI 里「静默通过」不等于「无输出」，
    # 否则失败信息会被吞掉，只剩一个看不懂的退出码。
    for w in warns:
        if not quiet:
            print(w)
    for e in errors:
        print(e)
    if errors or not quiet:
        print("结论: %s" % ("❌ 失败 %d 项" % len(errors) if errors
                            else "✅ 全部通过" + ("（另有 %d 条警告）" % len(warns) if warns else "")))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(check(quiet="--quiet" in sys.argv))
