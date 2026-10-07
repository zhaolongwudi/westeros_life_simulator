// 本机推送工具（见 docs/03 第 0 节接力规则第 6 条）。
// 背景：github.com git 协议在本机硬阻塞，仅 api.github.com 可达；且本机 ref 可能与远端分叉，
// 此时 `wg push` 的 API 兜底会沿 parent 一路回溯到根提交（危险），故不用它。
// 做法：以远端 HEAD 为 parent，用 Git Data API 建单条 commit，内容 = 工作区（默认排除 README）。
//
// 用法：node wgpush_api.js "commit message" [--dry-run] [--exclude <path>] [--add <path>]
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const ROOT = '/storage/emulated/0/Download/dsh/bingyuhuo/westeros_life_simulator';
const TOKEN = fs.readFileSync('/data/user/0/com.dshphone/files/tools/gitjs/.token', 'utf8').trim();
const OWNER = 'zhaolongwudi';
const REPO = 'westeros_life_simulator';
const BRANCH = 'main';
const IDENTITY = JSON.parse(
  fs.readFileSync('/data/user/0/com.dshphone/files/tools/gitjs/.identity.json', 'utf8'));

const argv = process.argv.slice(2);
const DRY = argv.includes('--dry-run');
const EXCLUDE = new Set(['README.md']);   // CI 自动更新 changelog，默认排除
const ADD = [];
const MSG = [];
for (let i = 0; i < argv.length; i++) {
  if (argv[i] === '--exclude') { EXCLUDE.add(argv[i + 1]); i++; }
  else if (argv[i] === '--add') { ADD.push(argv[i + 1]); i++; }
  else if (argv[i] === '--dry-run') { /* flag */ }
  else MSG.push(argv[i]);
}
const message = MSG.join(' ');

const blobSha = (buf) => {
  const h = crypto.createHash('sha1');
  h.update('blob ' + buf.length + '\0');
  h.update(buf);
  return h.digest('hex');
};
const api = async (m, p, payload) => {
  const res = await fetch(`https://api.github.com/repos/${OWNER}/${REPO}/git` + p, {
    method: m,
    headers: {
      Authorization: `token ${TOKEN}`, Accept: 'application/vnd.github+json',
      'User-Agent': 'dsh-wgpush',
      ...(payload !== undefined ? { 'Content-Type': 'application/json' } : {}),
    },
    body: payload !== undefined ? JSON.stringify(payload) : undefined,
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`API ${m} ${p} -> ${res.status}: ${text.slice(0, 300)}`);
  return text ? JSON.parse(text) : null;
};

(async () => {
  if (!message) throw new Error('usage: node wgpush_api.js "message" [--dry-run] [--exclude p] [--add p]');
  const ref = await api('GET', `/refs/heads/${BRANCH}`);
  const remoteHead = ref.object.sha;
  const commit = await api('GET', `/commits/${remoteHead}`);
  const tree = await api('GET', `/trees/${commit.tree.sha}?recursive=1`);
  if (tree.truncated) throw new Error('remote tree truncated, aborting');

  const remoteByPath = new Map(tree.tree.filter((e) => e.type === 'blob').map((e) => [e.path, e.sha]));
  const have = new Set(remoteByPath.values());
  const paths = new Set(remoteByPath.keys());
  for (const f of ADD) {
    if (!fs.existsSync(path.join(ROOT, f))) throw new Error('missing new file: ' + f);
    paths.add(f);
  }

  const entries = [];
  const changed = [];
  for (const p of paths) {
    const lp = path.join(ROOT, p);
    let sha;
    if (!EXCLUDE.has(p) && fs.existsSync(lp)) {
      sha = blobSha(fs.readFileSync(lp));
      if (sha !== remoteByPath.get(p)) changed.push(p);
    } else {
      if (!remoteByPath.has(p)) throw new Error('local missing & not on remote: ' + p);
      sha = remoteByPath.get(p);           // 沿用远端（含被排除的 CI 托管文件）
    }
    entries.push({ path: p, mode: '100644', type: 'blob', sha });
  }
  console.log('remote HEAD =', remoteHead);
  console.log('changed files (' + changed.length + '):');
  for (const p of changed) console.log('   ', p);
  console.log('excluded:', [...EXCLUDE].join(', ') || '(none)');

  if (!changed.length && !ADD.length) { console.log('nothing to commit'); return; }
  if (DRY) { console.log('[DRY RUN] no writes.'); return; }

  for (const p of changed) {
    const buf = fs.readFileSync(path.join(ROOT, p));
    const sha = blobSha(buf);
    if (have.has(sha)) continue;
    const c = await api('POST', '/blobs', { content: buf.toString('base64'), encoding: 'base64' });
    if (c.sha !== sha) throw new Error('blob sha mismatch ' + p);
    have.add(sha);
    console.log('uploaded', p);
  }

  const createdTree = await api('POST', '/trees', { tree: entries });
  const now = new Date().toISOString();
  const created = await api('POST', '/commits', {
    message, tree: createdTree.sha, parents: [remoteHead],
    author: { name: IDENTITY.name, email: IDENTITY.email, date: now },
    committer: { name: IDENTITY.name, email: IDENTITY.email, date: now },
  });
  await api('PATCH', `/refs/heads/${BRANCH}`, { sha: created.sha, force: false });
  fs.mkdirSync(path.join(ROOT, '.refbackup'), { recursive: true });
  fs.writeFileSync(path.join(ROOT, '.refbackup/last-prev-head.txt'), remoteHead + '\n');
  fs.writeFileSync(path.join(ROOT, `.git/refs/heads/${BRANCH}`), created.sha + '\n');
  fs.writeFileSync(path.join(ROOT, `.git/refs/remotes/origin/${BRANCH}`), created.sha + '\n');
  console.log('pushed', created.sha, '| prev head backed up to .refbackup/');
})().catch((e) => { console.error('FAILED:', e.message); process.exit(1); });
