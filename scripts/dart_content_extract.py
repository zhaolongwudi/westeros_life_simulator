#!/usr/bin/env python3
"""M4c-1 内容导出器：解析 lib/data/*.dart 常量，生成 assets/data/*.json。

设计原则：
- Dart 数据文件仍是运行时真相源（623 测试不动）。
- 本脚本用正则提取每个实体的构造参数，输出与 content-schema.md 结构对齐的 JSON。
- JSON 作为内容外置资产先行落成，供 docs 对账 / AI 内容生产 / 后续 M4c-2 切换。
- 幂等：可重复运行；产物只增不改既有测试。

用法：
  python3 scripts/dart_content_extract.py            # 生成全部
  python3 scripts/dart_content_extract.py --check    # 只校验 JSON 与 Dart 一致性，不写文件
"""
import json
import os
import re
import sys
import glob

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA_DIR = os.path.join(REPO, "lib", "data")
ASSET_DIR = os.path.join(REPO, "assets", "data")


# ---------- 基础解析工具 ----------

def _clean(s):
    """去引号、去尾逗号。"""
    s = s.strip()
    if s.startswith("'") and s.endswith("'") and len(s) >= 2:
        s = s[1:-1]
    elif s.startswith('"') and s.endswith('"') and len(s) >= 2:
        s = s[1:-1]
    return s.strip()


def _clean_list(s):
    """解析 const ['a','b'] / ['a', 'b'] 为 python list。"""
    s = s.strip()
    if s.startswith('const '):
        s = s[len('const '):].strip()
    if not s.startswith('['):
        return []
    # 去掉外层 [ ]
    inner = s[1:s.rfind(']')]
    parts = _split_top_level(inner)
    return [_clean(p) for p in parts if _clean(p) != '']


def _clean_map(s):
    """解析 const {'a': 1, 'b': 'x'} / const <String,int>{...} 为 python dict。"""
    s = s.strip()
    if s.startswith('const '):
        s = s[len('const '):].strip()
    # 剥掉 <...> 类型参数（如 const <String, int>{...}）
    if s.startswith('<') and '>' in s:
        s = s[s.index('>') + 1:].strip()
    if not s.startswith('{'):
        return {}
    inner = s[1:s.rfind('}')]
    parts = _split_top_level(inner)
    out = {}
    for p in parts:
        p = p.strip()
        if not p:
            continue
        if ':' not in p:
            continue
        k, v = p.split(':', 1)
        k = _clean(k)
        v = _clean(v)
        if v.startswith('{') or v.startswith('['):
            # 嵌套结构（一般不会出现在数值 map）
            out[k] = v
        elif v == 'true':
            out[k] = True
        elif v == 'false':
            out[k] = False
        else:
            try:
                out[k] = int(v)
            except ValueError:
                out[k] = v
    return out


def _split_top_level(s):
    """按逗号切分，忽略 {}  []  ()  <> 泛型 与引号内的逗号。"""
    parts = []
    depth = 0
    cur = []
    in_str = False
    quote = None
    for ch in s:
        if in_str:
            cur.append(ch)
            if ch == quote and len(cur) >= 2 and cur[-2] != '\\':
                in_str = False
            continue
        if ch in ("'", '"'):
            in_str = True
            quote = ch
            cur.append(ch)
        elif ch in '{[(':
            depth += 1
            cur.append(ch)
        elif ch in '}])':
            depth -= 1
            cur.append(ch)
        elif ch == '<':
            # Dart 泛型（const <String, int>{...}），计入深度避免逗号误切
            depth += 1
            cur.append(ch)
        elif ch == '>':
            depth -= 1
            cur.append(ch)
        elif ch == ',' and depth == 0:
            parts.append(''.join(cur))
            cur = []
        else:
            cur.append(ch)
    if ''.join(cur).strip():
        parts.append(''.join(cur))
    return parts


def _find_blocks(text, prefix, open_ch='(', close_ch=')'):
    """找到所有以 prefix 开头、配平括号的完整块。返回块内部内容。
    prefix 可含可不含 open_ch（自动剥离）。
    """
    if prefix.endswith(open_ch):
        prefix = prefix[:-1]
    blocks = []
    i = 0
    while True:
        idx = text.find(prefix, i)
        if idx < 0:
            break
        # 跳过注释行中的 prefix
        line_start = text.rfind('\n', 0, idx) + 1
        line = text[line_start:idx]
        if '//' in line:
            i = idx + len(prefix)
            continue
        j = idx + len(prefix)
        # 跳过空格
        while j < len(text) and text[j] in ' \t':
            j += 1
        if j >= len(text) or text[j] != open_ch:
            i = idx + len(prefix)
            continue
        start = j + 1
        depth = 1
        j = start
        in_str = False
        quote = None
        while j < len(text) and depth > 0:
            ch = text[j]
            if in_str:
                if ch == quote and (j == 0 or text[j-1] != '\\'):
                    in_str = False
            elif ch in ("'", '"'):
                in_str = True
                quote = ch
            elif ch == open_ch:
                depth += 1
            elif ch == close_ch:
                depth -= 1
            j += 1
        inner = text[start:j-1]
        blocks.append(inner)
        i = j
    return blocks


# ---------- 各域提取器 ----------

def extract_families(text):
    out = []
    for inner in _find_blocks(text, 'Family('):
        args = _parse_named_args(inner)
        fam = {
            'id': _clean(args.get('id', '')),
            'name': _clean(args.get('name', '')),
            'motto': _clean(args.get('motto', '')),
            'seat': _clean(args.get('seat', '')),
            'scale': _clean(args.get('scale', '')),
            'population': _to_int(args.get('population', '0')),
            'army': _to_int(args.get('army', '0')),
            'goldReserve': _to_int(args.get('goldReserve', '0')),
            'influence': _to_int(args.get('influence', '0')),
            'relations': _clean_map(args.get('relations', '{}')),
            'secrets': _clean_list(args.get('secrets', '[]')),
            'traits': _clean_list(args.get('traits', '[]')),
        }
        out.append(fam)
    return out


def extract_locations(text):
    out = []
    for inner in _find_blocks(text, 'Location('):
        args = _parse_named_args(inner)
        loc = {
            'id': _clean(args.get('id', '')),
            'name': _clean(args.get('name', '')),
            'type': _clean(args.get('type', '')),
            'region': _clean(args.get('region', '')),
            'dangerLevel': _to_int(args.get('dangerLevel', '0')),
            'population': _to_int(args.get('population', '0')),
            'features': _clean_list(args.get('features', '[]')),
            'governorId': _clean(args.get('governorId', '')),
            'connectedTo': _clean_list(args.get('connectedTo', '[]')),
            'description': _clean(args.get('description', '')),
        }
        out.append(loc)
    return out


def extract_npcs(text):
    out = []
    for inner in _find_blocks(text, 'Npc('):
        args = _parse_named_args(inner)
        npc = {
            'id': _clean(args.get('id', '')),
            'name': _clean(args.get('name', '')),
            'type': _clean(args.get('type', '')),
            'age': _to_int(args.get('age', '0')),
            'gender': _clean(args.get('gender', '')),
            'familyId': _clean(args.get('familyId', '')),
            'locationId': _clean(args.get('locationId', '')),
            'personality': _clean_list(args.get('personality', '[]')),
            'goals': _clean_list(args.get('goals', '[]')),
            'fears': _clean_list(args.get('fears', '[]')),
            'secrets': _clean_list(args.get('secrets', '[]')),
            'relations': _clean_map(args.get('relations', '{}')),
            'skills': _clean_map(args.get('skills', '{}')),
            'faith': _clean(args.get('faith', '')),
            'isAlive': args.get('isAlive', 'true').strip() == 'true',
            'mood': _to_int(args.get('mood', '0')),
        }
        out.append(npc)
    return out


def extract_events(text):
    out = []
    for inner in _find_blocks(text, 'GameEvent('):
        args = _parse_named_args(inner)
        choices = []
        for ch_inner in _find_blocks(args.get('choices', ''), 'EventChoice('):
            ch_args = _parse_named_args(ch_inner)
            choices.append({
                'id': _clean(ch_args.get('id', '')),
                'text': _clean(ch_args.get('text', '')),
                'requirements': _clean_map(ch_args.get('requirements', '{}')),
                'effects': _clean_map(ch_args.get('effects', '{}')),
                'narrative': _clean(ch_args.get('narrative', '')),
            })
        evt = {
            'id': _clean(args.get('id', '')),
            'name': _clean(args.get('name', '')),
            'type': _clean(args.get('type', '')),
            'description': _clean(args.get('description', '')),
            'triggerConditions': _clean_map(args.get('triggerConditions', '{}')),
            'choices': choices,
            'narrative': _clean(args.get('narrative', '')),
            'tags': _clean_list(args.get('tags', '[]')),
            'isOneTime': args.get('isOneTime', 'false').strip() == 'true',
        }
        out.append(evt)
    return out


def extract_systems(text):
    out = []
    for inner in _find_blocks(text, 'GameSystem('):
        args = _parse_named_args(inner)
        out.append({
            'id': _clean(args.get('id', '')),
            'name': _clean(args.get('name', '')),
            'category': _clean(args.get('category', '')),
            'description': _clean(args.get('description', '')),
            'rules': _clean_list(args.get('rules', '[]')),
            'features': _clean_list(args.get('features', '[]')),
        })
    return out


def extract_items(text):
    out = []
    for inner in _find_blocks(text, 'Item('):
        args = _parse_named_args(inner)
        out.append({
            'id': _clean(args.get('id', '')),
            'name': _clean(args.get('name', '')),
            'category': _clean(args.get('category', '')),
            'value': _to_int(args.get('value', '0')),
            'description': _clean(args.get('description', '')),
            'stackable': args.get('stackable', 'true').strip() == 'true',
            'usable': args.get('usable', 'false').strip() == 'true',
            'useEffect': _clean_map(args.get('useEffect', '{}')),
            'requiresSkill': _clean(args.get('requiresSkill', '')),
        })
    return out


def extract_npc_tasks(text):
    out = []
    for inner in _find_blocks(text, 'NpcTaskTemplate('):
        args = _parse_named_args(inner)
        steps = []
        for st_inner in _find_blocks(args.get('steps', ''), 'NpcTaskStep('):
            st_args = _parse_named_args(st_inner)
            steps.append({
                'description': _clean(st_args.get('description', '')),
                'turnsRequired': _to_int(st_args.get('turnsRequired', '1')),
            })
        out.append({
            'id': _clean(args.get('id', '')),
            'npcId': _clean(args.get('npcId', '')),
            'title': _clean(args.get('title', '')),
            'type': _clean(args.get('type', '')),
            'difficulty': _to_int(args.get('difficulty', '1')),
            'deadlineMonths': _to_int(args.get('deadlineMonths', '1')),
            'steps': steps,
            'rewardGold': _to_int(args.get('rewardGold', '0')),
            'rewardReputation': _to_int(args.get('rewardReputation', '0')),
            'rewardRelation': _to_int(args.get('rewardRelation', '0')),
        })
        co = _clean(args.get('coNpcId', ''))
        if co:
            out[-1]['coNpcId'] = co
    return out


# ---------- 通用 ----------

def _parse_named_args(inner):
    """把 'id: "x", name: "y", relations: const {...}' 切成 {name: raw_value}。"""
    args = {}
    for part in _split_top_level(inner):
        part = part.strip()
        if not part or ':' not in part:
            continue
        k, v = part.split(':', 1)
        args[k.strip()] = v.strip()
    return args


def _to_int(s):
    s = s.strip()
    try:
        return int(s)
    except ValueError:
        return 0


# ---------- 主流程 ----------

# 每个域的 id 前缀（用于过滤类构造函数等误匹配的空实体）
ID_PREFIX = {
    'families': 'family_',
    'locations': 'location_',
    'npcs': 'npc_',
    'events': 'event_',
    'systems': 'system_',
    'items': 'item_',
    'tasks': 'task_',
}

EXTRACTORS = {
    'families': ('family_data.dart', 'allFamilies', extract_families),
    'locations': ('location_data.dart', 'allLocations', extract_locations),
    'npcs': ('npc_data.dart', 'allNpcs', extract_npcs),
    'events': ('event_data.dart', 'allEvents', extract_events),
    'systems': ('system_data.dart', 'allSystems', extract_systems),
    'items': ('item_data.dart', 'kItems', extract_items),
    'tasks': ('npc_task_data.dart', 'allNpcTaskTemplates', extract_npc_tasks),
}

JSON_FILES = {
    'families': 'families.json',
    'locations': 'locations.json',
    'npcs': 'npcs.json',
    'events': 'events.json',
    'systems': 'systems.json',
    'items': 'items.json',
    'tasks': 'tasks.json',
}


def load_entities(domain):
    fname, const_name, extractor = EXTRACTORS[domain]
    path = os.path.join(DATA_DIR, fname)
    with open(path, encoding='utf-8') as f:
        text = f.read()
    entities = extractor(text)
    # 过滤 id 为空或前缀不符的实体（避开类构造函数等误匹配）
    prefix = ID_PREFIX.get(domain, '')
    if prefix:
        entities = [e for e in entities if e.get('id', '').startswith(prefix)]
    return entities


def check_sync(verbose=True):
    """校验 JSON 与 Dart 一致性，返回 (ok, report_lines)。"""
    lines = []
    all_ok = True
    for domain, (fname, const_name, extractor) in EXTRACTORS.items():
        json_file = os.path.join(ASSET_DIR, JSON_FILES[domain])
        if not os.path.exists(json_file):
            lines.append(f'[FAIL] {JSON_FILES[domain]} 不存在')
            all_ok = False
            continue
        with open(json_file, encoding='utf-8') as f:
            json_data = json.load(f)
        dart_entities = load_entities(domain)
        dart_ids = {e['id'] for e in dart_entities}
        json_ids = {e['id'] for e in json_data}
        missing = sorted(dart_ids - json_ids)
        extra = sorted(json_ids - dart_ids)
        dup_dart = len(dart_ids) != len(dart_entities)
        dup_json = len(json_ids) != len(json_data)
        if missing:
            lines.append(f'[FAIL] {JSON_FILES[domain]}: JSON 缺少 {len(missing)} 个 id（{missing[:5]}...）')
            all_ok = False
        if extra:
            lines.append(f'[WARN] {JSON_FILES[domain]}: JSON 多出 {len(extra)} 个 id（{extra[:5]}...）')
        if dup_dart:
            lines.append(f'[FAIL] {JSON_FILES[domain]}: Dart 侧 id 有重复（{len(dart_entities)} 条 vs {len(dart_ids)} 唯一）')
            all_ok = False
        if dup_json:
            lines.append(f'[FAIL] {JSON_FILES[domain]}: JSON 侧 id 有重复')
            all_ok = False
        if not missing and not extra and not dup_dart and not dup_json:
            lines.append(f'[OK] {JSON_FILES[domain]}: {len(dart_entities)} 条与 Dart 完全一致')
    return all_ok, lines


def generate_all():
    os.makedirs(ASSET_DIR, exist_ok=True)
    for domain, (fname, const_name, extractor) in EXTRACTORS.items():
        entities = load_entities(domain)
        out_path = os.path.join(ASSET_DIR, JSON_FILES[domain])
        with open(out_path, 'w', encoding='utf-8') as f:
            json.dump(entities, f, ensure_ascii=False, indent=2)
        print(f'[GEN] {JSON_FILES[domain]}: {len(entities)} 条 -> {out_path}')


def main():
    if '--check' in sys.argv:
        ok, lines = check_sync()
        for l in lines:
            print(l)
        sys.exit(0 if ok else 1)
    generate_all()
    ok, lines = check_sync()
    for l in lines:
        print(l)
    sys.exit(0 if ok else 1)


if __name__ == '__main__':
    main()
