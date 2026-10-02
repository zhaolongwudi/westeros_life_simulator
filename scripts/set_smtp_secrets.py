#!/usr/bin/env python3
"""配置 GitHub 仓库 Actions Secrets（SMTP 凭据）。

用法：
  python3 scripts/set_smtp_secrets.py <SMTP_USER> <SMTP_AUTH_CODE> <SMTP_TO>
    按顺序传入三个值（邮箱地址/授权码/收件人邮箱，收件人可省略默认=发件人）
    使用仓库 public-key 用 libsodium 加密后 PUT 到 Actions secrets

依赖：pip3 install pynacl（已装，1.6.2）
Token：默认从 git remote 提取；也支持环境变量 GITHUB_TOKEN
"""

import base64
import os
import re
import subprocess
import sys
import urllib.request
import urllib.error

REPO = "zhaolongwudi/westeros_life_simulator"
API = "https://api.github.com"
TIMEOUT = 30


def log(msg):
    print(f"[set_smtp_secrets] {msg}", flush=True)


def github_token():
    t = os.environ.get("GITHUB_TOKEN")
    if t:
        return t
    try:
        out = subprocess.check_output(
            ["git", "remote", "get-url", "origin"],
            cwd="/root/westeros_life_simulator",
            stderr=subprocess.DEVNULL, text=True).strip()
        m = re.search(r"https://([^@/]+)@github\.com", out)
        if m:
            return m.group(1)
    except Exception:
        pass
    return None


def api_request(method, url, token, body=None):
    headers = {"Accept": "application/vnd.github+json", "User-Agent": "set_smtp_secrets"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    data = None
    if body is not None:
        data = body if isinstance(body, bytes) else str(body).encode()
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
            raw = resp.read()
            return resp.status, raw
    except urllib.error.HTTPError as e:
        return e.code, e.read()


def main():
    args = sys.argv[1:]
    if len(args) < 2:
        log("用法: python3 scripts/set_smtp_secrets.py <SMTP_USER> <SMTP_AUTH_CODE> [SMTP_TO]")
        sys.exit(1)
    smtp_user = args[0].strip()
    smtp_auth = args[1].strip()
    smtp_to = args[2].strip() if len(args) > 2 else smtp_user

    # 校验邮箱格式
    for name, val in (("SMTP_USER", smtp_user), ("SMTP_TO", smtp_to)):
        if "@" not in val:
            log(f"错误: {name} 不是有效邮箱: {val}")
            sys.exit(1)

    token = github_token()
    if not token:
        log("错误: 无 GitHub Token")
        sys.exit(1)

    import nacl.bindings
    import nacl.encoding
    import nacl.public
    import nacl.utils

    # 1. 取 public-key
    url = f"{API}/repos/{REPO}/actions/secrets/public-key"
    status, raw = api_request("GET", url, token)
    if status != 200:
        log(f"获取 public-key 失败 HTTP {status}: {raw[:300]}")
        sys.exit(1)
    import json
    pk = json.loads(raw)
    key_id = pk["key_id"]
    pub_key_b64 = pk["key"]

    # 2. libsodium 加密（sealed box，tweetsodium 同算法）
    pub_key = nacl.public.PublicKey(pub_key_b64, nacl.encoding.Base64Encoder)
    sealed = nacl.public.SealedBox(pub_key)
    enc = lambda v: base64.b64encode(sealed.encrypt(v.encode())).decode()

    # 3. 逐个 PUT secrets
    secrets = {"SMTP_USER": smtp_user, "SMTP_AUTH_CODE": smtp_auth, "SMTP_TO": smtp_to}
    ok = True
    for name, value in secrets.items():
        payload = json.dumps({"encrypted_value": enc(value), "key_id": key_id}).encode()
        url2 = f"{API}/repos/{REPO}/actions/secrets/{name}"
        status2, raw2 = api_request("PUT", url2, token, body=payload)
        if status2 in (201, 204):
            log(f"✅ 已写入 secret: {name}（{len(value)} 字符）")
        else:
            log(f"❌ 写入 {name} 失败 HTTP {status2}: {raw2[:300]}")
            ok = False

    if ok:
        log("全部 3 个 SMTP secrets 配置完成 ✅")
        log("下次触发 Build APK 时自动发信到: " + smtp_to)
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()