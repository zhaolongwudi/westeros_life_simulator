#!/usr/bin/env python3
"""自动更新 README 下载中心与最近更新（westeros_life_simulator）。

两个模式（均由 GitHub Actions 调用，构建/测试成功后自动执行并 push）：
  --download   刷新「下载中心」区块：GitHub 官方运行页链接 + nightly.link 加速外链，
               以当前 run 的 SHA/run_id/时间生成。由 build_apk.yml 构建成功后调用。
  --changelog  刷新「最近更新」区块：从 git log 取最近 3 条非自动更新 commit，
               以「日期 · 标题（SHA）」列表写入。由 ci.yml 测试通过后调用。

  --stats      刷新 README「这个世界有多大」的内容数量（家族/地点/NPC/系统/事件/物品），
               数字直接从 lib/data/*.dart 现场统计，防止 README 数量再次注水（P2-05）。
               由 ci.yml 测试通过后调用，与 --changelog 同一步骤提交。

区块标记（README.md 内，脚本按标记整体替换，勿手改标记内内容）：
  <!-- DL-CENTER:BEGIN --> ... <!-- DL-CENTER:END -->
  <!-- CHANGELOG:BEGIN --> ... <!-- CHANGELOG:END -->

用法（CI 环境变量）：
  GITHUB_TOKEN / GITHUB_REPOSITORY / GITHUB_RUN_ID / GITHUB_SHA 由 Actions 自动注入。
  python3 scripts/update_readme.py --download
  python3 scripts/update_readme.py --changelog
  python3 scripts/update_readme.py --stats
"""

import argparse
import datetime
import os
import re
import subprocess
import sys
from pathlib import Path

ARTIFACT_NAME = "WesterosLige-nightly"
SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_DIR = SCRIPT_DIR.parent
README = PROJECT_DIR / "README.md"


def log(msg):
    print(f"[update_readme] {msg}", flush=True)


def read_readme():
    return README.read_text(encoding="utf-8")


def replace_block(text, marker, new_block):
    begin = f"<!-- {marker}:BEGIN -->"
    end = f"<!-- {marker}:END -->"
    pattern = re.compile(re.escape(begin) + r".*?" + re.escape(end), re.S)
    if not pattern.search(text):
        return None
    return pattern.sub(new_block, text, count=1)


def utc_now_str():
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d %H:%M UTC")


def build_download_block(version=""):
    repo = os.environ.get("GITHUB_REPOSITORY", "zhaolongwudi/westeros_life_simulator")
    run_id = os.environ.get("GITHUB_RUN_ID", "")
    sha = os.environ.get("GITHUB_SHA", "")
    sha8 = sha[:8] if sha else "latest"
    release_latest = f"https://github.com/{repo}/releases/latest/download/WesterosLige.apk"
    releases_page = f"https://github.com/{repo}/releases"
    workflow_page = f"https://github.com/{repo}/actions/workflows/build_apk.yml"
    tag_display = f"v{version}" if version else sha8
    lines = [
        "<!-- DL-CENTER:BEGIN -->",
        "## 📥 下载中心",
        "",
        f"**最新构建**：`WesterosLige {tag_display}` · {utc_now_str()} · ✅ 自动发布正式版",
        "",
        "| 通道 | 地址 |",
        "|---|---|",
        f"| 🚀 Release 直链 | [releases/latest/download/WesterosLige.apk]({release_latest})（免登录，每次构建自动指向最新正式版 `v{version}`） |",
        f"| 🐙 GitHub 官方 | [Releases 页面]({releases_page}) → 最新版 → Assets → `WesterosLige.apk`（保留最近 3 次） |",
        "",
        "> 🔄 每次构建自动发布正式版 Release（版本号 0.0.1 → 0.0.2 → 0.0.3…自动递增），仅保留最近 3 次。",
        # S1-4：说明版本号出处与「已发布 vs 待构建」的差一拍，避免被当成三处版本不一致。
        "> ℹ️ 版本号真相源是 `version.txt`，构建成功后自动递增；因此这里显示的是**最近一次已发布**"
        "的版本，比仓库里 `version.txt` 的待构建版本号小一号，属预期行为。",
        "> 📱 安装要求：Android 6.0+（minSdk 23）。",
        "> ✉️ 构建完成后可自动直发到你的邮箱：仓库 Settings → Secrets and variables → Actions 配置 `SMTP_USER` / `SMTP_AUTH_CODE` / `SMTP_TO`（参考 `scripts/.mail_env.example`）。",
        "<!-- DL-CENTER:END -->",
    ]
    return "\n".join(lines)


def build_changelog_block():
    try:
        out = subprocess.check_output(
            ["git", "log", "-15", "--pretty=format:%h|%ad|%s", "--date=short"],
            cwd=str(PROJECT_DIR), text=True, stderr=subprocess.DEVNULL)
    except Exception as e:
        log(f"git log 失败: {e}")
        return None
    # 跳过维护类 commit（docs/chore/Merge/自动更新），只展示功能与修复
    skip_prefixes = ("docs(", "chore", "Merge ", "auto-update", "README auto")
    commits = []
    for line in out.splitlines():
        if "|" not in line:
            continue
        sha, date, subject = line.split("|", 2)
        subject = subject.strip()
        if "[skip ci]" in subject or subject.startswith(skip_prefixes):
            continue
        commits.append((sha, date, subject))
        if len(commits) == 3:
            break
    if not commits:
        log("没有可用的更新条目")
        return None
    lines = [
        "<!-- CHANGELOG:BEGIN -->",
        "## 🚀 最近更新",
        "",
    ]
    for sha, date, subject in commits:
        lines.append(f"**{date} · {subject}**（`{sha}`）")
        lines.append("")
    lines += [
        "> 🔄 每次推送后自动刷新，仅保留最近 3 条。完整记录见 docs/HANDOVER.md。",
        "<!-- CHANGELOG:END -->",
    ]
    return "\n".join(lines)


# 「这个世界有多大」段落里的数量口径：README 措辞 -> dart_content_extract 域名。
# 数量一律以 lib/data/*.dart 现场统计为准，禁止在 README 里手写。
# 后缀按 README 里的**字面文本**写（含结尾的两个星号），正则侧再 escape，
# 避免同一份字符串既当模式又当替换串时被反斜杠转义吃星号。
STATS_PATTERNS = [
    ("families", "个家族**"),
    ("locations", "个地点**"),
    ("npcs", "位 NPC**"),
    ("systems", "个世界系统**"),
    ("events", "个事件**"),
    ("items", "个物品**"),
]


def update_stats():
    """把 README 的内容数量刷成 Dart 真相源的实时值。"""
    sys.path.insert(0, str(SCRIPT_DIR))
    from dart_content_extract import load_entities

    text = read_readme()
    changed = 0
    for domain, suffix in STATS_PATTERNS:
        try:
            actual = len(load_entities(domain))
        except Exception as e:  # 解析失败不拖垮 CI，交由 check_content_sync 报错
            log(f"[stats] {domain} 解析失败，跳过：{e}")
            continue
        pattern = re.compile(r"\*\*(\d+) " + re.escape(suffix))

        def _sub(m, n=actual):
            # suffix 形如「个家族**」，前面补回被正则吃掉的 ** 与数字
            return f"**{n} " + suffix

        new_text, cnt = pattern.subn(_sub, text)
        if not cnt:
            log(f"[stats] README 未找到「N {suffix[:-2]}」表述，跳过 {domain}")
            continue
        old = pattern.search(text).group(1)
        if str(actual) != old:
            log(f"[stats] {domain}: README {old} -> {actual}")
            changed += 1
        text = new_text
    if changed:
        README.write_text(text, encoding="utf-8")
        log(f"[stats] 已更新 {changed} 处数量")
    else:
        log("[stats] 数量无变化，跳过写入")
    return True


def do_update(marker, builder):
    text = read_readme()
    new_block = builder()
    if new_block is None:
        return False
    updated = replace_block(text, marker, new_block)
    if updated is None:
        log(f"README 中未找到标记 <!-- {marker}:BEGIN/END -->，请先写入标记区块")
        return False
    if updated == text:
        log(f"{marker} 区块内容无变化，跳过写入")
        return True
    README.write_text(updated, encoding="utf-8")
    log(f"{marker} 区块已更新")
    return True


def main():
    ap = argparse.ArgumentParser(description="自动更新 README 下载中心与最近更新")
    ap.add_argument("--download", action="store_true", help="刷新下载中心区块")
    ap.add_argument("--changelog", action="store_true", help="刷新最近更新区块")
    ap.add_argument("--stats", action="store_true", help="刷新内容数量（家族/地点/NPC/系统/事件/物品）")
    ap.add_argument("--version", default="", help="当前构建版本号（如 0.0.1，显示在下载中心）")
    args = ap.parse_args()
    ok = True
    if args.download:
        ok = do_update("DL-CENTER", lambda: build_download_block(args.version)) and ok
    if args.changelog:
        ok = do_update("CHANGELOG", build_changelog_block) and ok
    if args.stats:
        ok = update_stats() and ok
    if not (args.download or args.changelog or args.stats):
        ap.print_help()
        sys.exit(1)
    sys.exit(0 if ok else 1)
if __name__ == "__main__":
    main()
