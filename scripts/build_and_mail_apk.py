#!/usr/bin/env python3
"""构建 APK 并直发邮箱（westeros_life_simulator）。

流程：
  1. 触发 GitHub Actions workflow `build_apk.yml`（workflow_dispatch → build release APK → 上传 artifact）
  2. 轮询该 run 直至 completed
  3. 成功 → 下载 APK artifact → SMTP 附件直发邮箱
  4. 失败 → 降级：生成 nightly.link 下载链接 → SMTP 发链接（GitHub 下载太慢/经常失败，用户明确不喜）

配置（/root/westeros_life_simulator/scripts/.mail_env 或同级 .env，格式 key=value）：
  SMTP_HOST=smtp.qq.com
  SMTP_PORT=465
  SMTP_SSL=true            # true=SSL(465) / false=STARTTLS(587)
  SMTP_USER=xxx@qq.com
  SMTP_PASS=授权码或密码
  MAIL_FROM=xxx@qq.com
  MAIL_TO=收件人邮箱（可多个，逗号分隔）
  REPO=zhaolongwudi/westeros_life_simulator   # 可省略，默认此值
  GITHUB_TOKEN=            # 可省略：默认从 git remote 提取

用法：
  python3 scripts/build_and_mail_apk.py            # 完整流程
  python3 scripts/build_and_mail_apk.py --check    # 只校验配置与依赖
  python3 scripts/build_and_mail_apk.py --trigger  # 只触发构建（随后可 --mail-latest）
  python3 scripts/build_and_mail_apk.py --mail-latest  # 取最近一次成功 run 的 artifact 发邮箱
"""

import argparse
import io
import os
import re
import subprocess
import sys
import time
import urllib.request
import urllib.error
import zipfile
from email.mime.application import MIMEApplication
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.utils import formatdate
from pathlib import Path
from urllib.parse import urlparse

REPO = "zhaolongwudi/westeros_life_simulator"
WORKFLOW = "build_apk.yml"
ARTIFACT_NAME = "WesterosLige-nightly"
SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_DIR = SCRIPT_DIR.parent
ENV_FILE = SCRIPT_DIR / ".mail_env"
API = "https://api.github.com"
TIMEOUT = 30


def log(msg):
    print(f"[build_and_mail] {msg}", flush=True)


def load_env():
    env = {}
    candidates = [ENV_FILE, PROJECT_DIR / ".mail_env", PROJECT_DIR / ".env"]
    for p in candidates:
        if p.exists():
            for line in p.read_text(encoding="utf-8").splitlines():
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                k, _, v = line.partition("=")
                env[k.strip()] = v.strip().strip('"').strip("'")
            break
    for k in ("SMTP_HOST", "SMTP_PORT", "SMTP_SSL", "SMTP_USER", "SMTP_PASS",
              "MAIL_FROM", "MAIL_TO", "REPO", "GITHUB_TOKEN"):
        if k in os.environ and os.environ[k]:
            env[k] = os.environ[k]
    return env


def github_token(env):
    if env.get("GITHUB_TOKEN"):
        return env["GITHUB_TOKEN"]
    try:
        out = subprocess.check_output(
            ["git", "remote", "get-url", "origin"],
            cwd=str(PROJECT_DIR), stderr=subprocess.DEVNULL, text=True).strip()
        m = re.search(r"https://([^@/]+)@github\.com", out)
        if m:
            return m.group(1)
    except Exception:
        pass
    return None


def api_request(env, method, url, token=None, body=None):
    headers = {"Accept": "application/vnd.github+json", "User-Agent": "build_and_mail"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    data = None
    if body is not None:
        data = json_dumps(body).encode()
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
            raw = resp.read()
            return resp.status, raw
    except urllib.error.HTTPError as e:
        return e.code, e.read()


def json_dumps(obj):
    import json
    return json.dumps(obj)


def json_loads(raw):
    import json
    return json.loads(raw)


def trigger_build(env, token):
    repo = env.get("REPO", REPO)
    url = f"{API}/repos/{repo}/actions/workflows/{WORKFLOW}/dispatches"
    status, raw = api_request(env, "POST", url, token, {"ref": "main"})
    if status in (204, 200, 201):
        log(f"已触发 {WORKFLOW}（ref=main）")
        return True
    log(f"触发失败 HTTP {status}: {raw[:300]}")
    return False


def latest_run(env, token):
    repo = env.get("REPO", REPO)
    url = f"{API}/repos/{repo}/actions/workflows/{WORKFLOW}/runs?per_page=5"
    status, raw = api_request(env, "GET", url, token)
    if status != 200:
        log(f"查询 run 失败 HTTP {status}: {raw[:300]}")
        return None
    runs = json_loads(raw).get("workflow_runs", [])
    return runs[0] if runs else None


def wait_run(env, token, poll_minutes=40):
    repo = env.get("REPO", REPO)
    log("等待 CI run 完成……")
    deadline = time.time() + poll_minutes * 60
    last = None
    while time.time() < deadline:
        run = latest_run(env, token)
        if run and run["id"] != last:
            last = run["id"]
            log(f"run {run['id']} head={run['head_sha'][:7]} status={run['status']}")
        if run and run["status"] == "completed":
            concl = run.get("conclusion")
            log(f"run {run['id']} conclusion={concl}")
            return run, concl == "success"
        time.sleep(30)
    log("等待超时（40 分钟）")
    return None, False


def download_artifact(env, token, run_id):
    repo = env.get("REPO", REPO)
    url = f"{API}/repos/{repo}/actions/runs/{run_id}/artifacts"
    status, raw = api_request(env, "GET", url, token)
    if status != 200:
        log(f"查询 artifact 失败 HTTP {status}: {raw[:300]}")
        return None
    arts = json_loads(raw).get("artifacts", [])
    art = next((a for a in arts if a["name"] == ARTIFACT_NAME), None)
    if not art:
        log(f"未找到 artifact {ARTIFACT_NAME}")
        return None
    dl = f"{API}/repos/{repo}/actions/artifacts/{art['id']}/zip"
    headers = {"Accept": "application/vnd.github+json", "User-Agent": "build_and_mail"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(dl, headers=headers, method="GET")
    with urllib.request.urlopen(req, timeout=120) as resp:
        data = resp.read()
    zf = zipfile.ZipFile(io.BytesIO(data))
    apk_name = next((n for n in zf.namelist() if n.endswith(".apk")), None)
    if not apk_name:
        log("artifact zip 内无 APK")
        return None
    out_dir = PROJECT_DIR / "build" / "mail"
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / Path(apk_name).name
    out_path.write_bytes(zf.read(apk_name))
    log(f"APK 已下载: {out_path} ({out_path.stat().st_size / 1024 / 1024:.1f} MB)")
    return out_path


def nightly_link(run_id):
    return f"https://nightly.link/{REPO}/actions/runs/{run_id}/{ARTIFACT_NAME}.zip"


def send_mail(env, subject, body, attach=None):
    import smtplib
    host = env["SMTP_HOST"]
    port = int(env.get("SMTP_PORT", "465"))
    ssl_ = env.get("SMTP_SSL", "true").strip().lower() in ("1", "true", "yes")
    user = env["SMTP_USER"]
    pwd = env["SMTP_PASS"]
    from_addr = env.get("MAIL_FROM", user)
    to_list = [x.strip() for x in env["MAIL_TO"].split(",") if x.strip()]

    msg = MIMEMultipart()
    msg["From"] = from_addr
    msg["To"] = ", ".join(to_list)
    msg["Subject"] = subject
    msg["Date"] = formatdate(localtime=True)
    msg.attach(MIMEText(body, "plain", "utf-8"))
    if attach and attach.exists():
        part = MIMEApplication(attach.read_bytes(), _subtype="octet-stream")
        part.add_header("Content-Disposition", "attachment", filename=attach.name)
        msg.attach(part)

    smtp = smtplib.SMTP_SSL(host, port) if ssl_ else smtplib.SMTP(host, port)
    if not ssl_:
        smtp.starttls()
    try:
        smtp.login(user, pwd)
        smtp.sendmail(from_addr, to_list, msg.as_string())
        log(f"邮件已发送: {to_list}")
        return True
    finally:
        smtp.quit()


def do_mail(env, apk_path=None, run_id=None, build_ok=None, version=""):
    parts = [f"维斯特洛人生模拟器 APK 构建{'完成' if build_ok else '失败（附降级链接）'}",
             "", f"仓库: {env.get('REPO', REPO)}", f"版本: {version or '见内'}"]
    if apk_path:
        parts += ["", f"APK 已以附件形式发送（{apk_path.name}，"
                      f"{apk_path.stat().st_size / 1024 / 1024:.1f} MB）。",
                  "", "若附件无法下载（GitHub 直连慢/失败），可用 nightly.link 加速通道："]
    if run_id:
        parts += ["", f"nightly.link 下载（走 Cloudflare 缓存，比 GitHub 直连快）："]
        parts += [nightly_link(run_id)]
        parts += ["", "注意：nightly.link 需要「最近一次成功 build 的 artifact」存在，"
                      "若 404 请重跑构建。"]
    subject = f"Westeros Lige APK {'构建成功' if build_ok else '构建结果'} {version}".strip()
    return send_mail(env, subject, "\n".join(parts))


def check_env(env):
    missing = [k for k in ("SMTP_HOST", "SMTP_PORT", "SMTP_USER", "SMTP_PASS", "MAIL_TO")
               if not env.get(k)]
    if missing:
        log(f"缺少配置: {', '.join(missing)}")
        log(f"请编辑 {ENV_FILE}（参考脚本头注释）")
        return False
    token = github_token(env)
    if not token:
        log("警告: 未找到 GitHub Token（将无法触发/查询构建）")
    log("配置检查通过")
    return True


def main():
    ap = argparse.ArgumentParser(description="构建 APK 并直发邮箱")
    ap.add_argument("--check", action="store_true", help="只校验配置")
    ap.add_argument("--trigger", action="store_true", help="只触发构建")
    ap.add_argument("--mail-latest", action="store_true", help="取最近一次成功 run 的 APK 发邮箱")
    args = ap.parse_args()

    env = load_env()
    if args.check:
        sys.exit(0 if check_env(env) else 1)

    token = github_token(env)
    if not token:
        log("错误: 无 GitHub Token")
        sys.exit(1)

    if args.trigger:
        sys.exit(0 if trigger_build(env, token) else 1)

    if args.mail_latest:
        run, ok = latest_run(env, token), None
        if not run:
            log("没有 run")
            sys.exit(1)
        run_id = run["id"]
        apk = download_artifact(env, token, run_id)
        if apk:
            do_mail(env, apk_path=apk, run_id=run_id, build_ok=True,
                    version=run.get("head_sha", "")[:7])
        else:
            do_mail(env, run_id=run_id, build_ok=False,
                    version=run.get("head_sha", "")[:7])
        sys.exit(0)

    # 完整流程
    if not check_env(env):
        sys.exit(1)
    if not trigger_build(env, token):
        sys.exit(1)
    run, ok = wait_run(env, token)
    if not run:
        sys.exit(1)
    run_id = run["id"]
    sha = run.get("head_sha", "")[:7]
    if ok:
        apk = download_artifact(env, token, run_id)
        if apk:
            sys.exit(0 if do_mail(env, apk_path=apk, run_id=run_id, build_ok=True, version=sha) else 1)
        # 构建成功但下载失败 → 降级链接
        sys.exit(0 if do_mail(env, run_id=run_id, build_ok=False, version=sha) else 1)
    # 构建失败 → 降级链接（但仍发邮件告知）
    sys.exit(0 if do_mail(env, run_id=run_id, build_ok=False, version=sha) else 1)


if __name__ == "__main__":
    main()