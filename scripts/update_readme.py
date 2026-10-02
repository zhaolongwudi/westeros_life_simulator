#!/usr/bin/env python3
"""自动更新 README 下载中心与最近更新（westeros_life_simulator）。

两个模式（均由 GitHub Actions 调用，构建/测试成功后自动执行并 push）：
  --download   刷新「下载中心」区块：GitHub 官方运行页链接 + nightly.link 加速外链，
               以当前 run 的 SHA/run_id/时间生成。由 build_apk.yml 构建成功后调用。
  --changelog  刷新「最近更新」区块：从 git log 取最近 3 条非自动更新 commit，
               以「日期 · 标题（SHA）」列表写入。由 ci.yml 测试通过后调用。

区块标记（README.md 内，脚本按标记整体替换，勿手改标记内内容）：
  <!-- DL-CENTER:BEGIN --> ... <!-- DL-CENTER:END -->
  <!-- CHANGELOG:BEGIN --> ... <!-- CHANGELOG:END -->

用法（CI 环境变量）：
  GITHUB_TOKEN / GITHUB_REPOSITORY / GITHUB_RUN_ID / GITHUB_SHA 由 Actions 自动注入。
  python3 scripts/update_readme.py --download
  python3 scripts/update_readme.py --changelog
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
        f"| 🚀 Release 直链 | [releases/latest/download/WesterosLige.apk]({release_latest})（需登录 GitHub；每次构建自动指向最新正式版 `v{version}`） |",
        f"| 🐙 GitHub 官方 | [Releases 页面]({releases_page}) → 最新版 → Assets → `WesterosLige.apk`（保留最近 3 次） |",
        f"| ⚡ GitHub Actions | [Build APK 工作流]({workflow_page}) → 最近成功 run → Artifacts → `WesterosLige-nightly`（zip 保留 90 天） |",
        "",
        "> ℹ️ **本仓库为私有仓库**：GitHub 对未登录访问私有仓库的 release/asset 一律返回 404（隐藏存在性），",
        "> 因此**任何外联加速服务（如 nightly.link）都无法读取**；下载请先登录你的 GitHub 账号，直链即可用。",
        "> 🔄 每次构建自动发布正式版 Release（版本号 0.0.1 → 0.0.2 → 0.0.3…自动递增），仅保留最近 3 次。",
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
    ap.add_argument("--version", default="", help="当前构建版本号（如 0.0.1，显示在下载中心）")
    args = ap.parse_args()
    ok = True
    if args.download:
        ok = do_update("DL-CENTER", lambda: build_download_block(args.version)) and ok
    if args.changelog:
        ok = do_update("CHANGELOG", build_changelog_block) and ok
    if not args.download and not args.changelog:
        ap.print_help()
        sys.exit(1)
    sys.exit(0 if ok else 1)
if __name__ == "__main__":
    main()
