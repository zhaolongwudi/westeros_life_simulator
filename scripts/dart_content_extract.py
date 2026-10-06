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


def _clean_nullable(s):
    """可空字符串字段：Dart 侧写 `null` 时导出 JSON null，而不是字符串 "null"。

    【为什么单开一个函数】`_clean('null')` 会得到 Python 字符串 `'null'`，
    写进 JSON 就是 `"governorId": "null"`。运行时不读 JSON 所以没人发现，
    但 `Location.fromJson`（`json['governorId'] as String?`）会拿到长度 4 的
    字符串，两个消费点 `ai_service:1190 / :1239` 判的是
    `== null || isEmpty`——一旦 S4-4 把 JSON 变成真数据源，56 个无治主地点
    会全部走进「治主数据缺失（null），地方权力真空」分支。
    S3-1 把它列为镜像字段契约第 3 条（前两条是 S1-2 的 mood / tasks）。
    """
    s = s.strip()
    if s in ("null", "''", '""', ""):
        return None
    return _clean(s)


def _clean_enum(s):
    """枚举字段：剥掉 `EventType.` 这类类名前缀，只留裸枚举名。

    【为什么必须剥】Dart 源码里写的是 `EventType.economic`，直接导出会变成
    JSON 里的 `"EventType.economic"`。而模型的反序列化全部按**裸名**取值：

      - `GameEvent.fromJson` → `safeEnum(EventType.values, json['type'], ...)`
        比对的是 `value.name`（= `economic`），前缀形式匹配不上 →
        **72 个事件全部静默回落成 `EventType.daily`**；
      - `Family.fromJson` → `FamilyScale.values.byName(json['scale'])`，
        `Location.fromJson` / `Npc.fromJson` 同理用 `byName`——
        **`byName` 对未知名直接抛 ArgumentError**，不是回落！

    也就是说：带前缀的镜像**根本无法被任何模型的 fromJson 反序列化**。
    运行时不读 JSON 所以一直没人发现（S1-2 之前的 mood/tasks 漂移同理）。
    S3-1 把它列为镜像字段契约第 4 条，是 S4-4「JSON 是否外置」的前置条件。
    """
    s = _clean(s)
    if "." in s:
        s = s.rsplit(".", 1)[-1]
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


def _clean_string_map(s):
    """解析 `Map<String, String>` 型 map：带引号的值**保持字符串**，不转 int。

    【为什么单开一个】`GameEvent.triggerConditions` 是 `Map<String, String>`，
    事件里写的全是 `{'minGold': '20', 'season': 'winter'}` 这种**数字字符串**。
    `_clean_map` 会把它转成 int → JSON 里变成 `"minGold": 20`（数字），
    而 `GameEvent.fromJson` 用的是 `safeStringMap`，**非字符串元素直接跳过**
    → 15 个数值门槛在反序列化后**整条消失**，事件变成无门槛。

    这是「镜像不可反序列化」的第 5 个实例，同样由 batch10_121 的全字段
    往返比对逼出来（S3-1）。
    """
    s = s.strip()
    if s.startswith("const "):
        s = s[len("const "):].strip()
    if s.startswith("<") and ">" in s:
        s = s[s.index(">") + 1:].strip()
    if not s.startswith("{"):
        return {}
    inner = s[1:s.rfind("}")]
    out = {}
    for p in _split_top_level(inner):
        p = p.strip()
        if ":" not in p:
            continue
        k, v = p.split(":", 1)
        k = _clean(k)
        raw = v.strip()
        # 带引号 → 原样保留字符串语义（哪怕内容是数字）
        if (raw.startswith("'") and raw.endswith("'")) or (
            raw.startswith('"') and raw.endswith('"')
        ):
            out[k] = _clean(raw)
        else:
            out[k] = _clean(raw)
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


def _find_blocks(text, prefix, open_ch='(', close_ch=')', skip_constructors=True):
    """找到所有以 prefix 开头、配平括号的完整块。返回块内部内容。
    prefix 可含可不含 open_ch（自动剥离）。

    [skip_constructors]（S3-1）：跳过**构造函数声明**——`const Item({` 里的
    形参列表（`this.id`、`required this.name`…）同样以 `Item(` 开头，会被当成
    一条 id 为空的实体。过去靠 `load_entities` 的 id 前缀过滤兜住，于是
    「构造函数」只是被静默丢弃；S3-1 的 checklist 1 会比对过滤前后条数，
    这才把它暴露出来。判据是块内含 `this.`（只有构造函数/初始化形参会写）。
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
        if skip_constructors and "this." in inner:
            i = j
            continue
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
            'scale': _clean_enum(args.get('scale', '')),
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
            'type': _clean_enum(args.get('type', '')),
            'region': _clean(args.get('region', '')),
            'dangerLevel': _to_int(args.get('dangerLevel', '0')),
            'population': _to_int(args.get('population', '0')),
            'features': _clean_list(args.get('features', '[]')),
            'governorId': _clean_nullable(args.get('governorId', 'null')),
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
            'type': _clean_enum(args.get('type', '')),
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
            # S1-3：mood 是 String（Npc.mood / fromJson 的 json['mood'] as String?），
            # 旧实现走 _to_int 把「沉稳」解析成 0，镜像与模型类型不符。
            'mood': _clean(args.get('mood', '')),
            # S1-3：补上此前完全未映射的 tasks 字段。
            'tasks': _clean_list(args.get('tasks', '[]')),
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
            'type': _clean_enum(args.get('type', '')),
            'description': _clean(args.get('description', '')),
            'triggerConditions': _clean_string_map(args.get('triggerConditions', '{}')),
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
            # S4-1（P1-09）：系统月度效果字段。
            # 绝大多数系统写作 `monthlyEffects: const {}`，`_clean_map` 会
            # 返回 {} —— 这是**有意的诚实标注**（无月度结算），不能因为
            # 「空」就省掉键：省掉后 `GameSystem.fromJson` 读到的 json
            # 缺该键，`toJson()` 仍会写出 `{}`，往返比对即失配。
            'monthlyEffects': _clean_map(args.get('monthlyEffects', '{}')),
        })
    return out


def extract_items(text):
    out = []
    for inner in _find_blocks(text, 'Item('):
        args = _parse_named_args(inner)
        out.append({
            'id': _clean(args.get('id', '')),
            'name': _clean(args.get('name', '')),
            'category': _clean_enum(args.get('category', '')),
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
            'type': _clean_enum(args.get('type', '')),
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

def _strip_line_comments(s):
    """剥掉行注释（`//` 到行尾），但不动字符串字面量里的 `//`。

    【为什么必须剥】数据块里的注释会被 `_split_top_level` + `split(':', 1)`
    当成**键名的一部分**——例如：

        features: const ['守夜人军团'],
        // S3-1：原为 'npc_jeor_mormont'（全库无此 id）
        governorId: 'npc_geor_mormont',

    切片后第二个 part 是 `"// S3-1：...\n    governorId"`，于是字典里的键变成
    那整串注释，`governorId` 这个键**消失**，导出时回落默认值（null/''）。
    更糟的是这种损坏**不会触发任何告警**：check_content_sync 的第 3 项比对的是
    「JSON vs 现场解析的 Dart」，两边走同一个解析器，一起错、一起对得上。
    S3-1 靠「镜像可被模型 fromJson 反序列化」的 Dart 测试（batch10_121）
    才把它逼出来。

    【为什么不整文件剥】只剥进到块内部的内容即可；`_find_blocks` 的配平扫描
    本身能容忍注释（注释里的括号也会被计入深度，但本文件注释不含括号）。
    """
    out = []
    i = 0
    n = len(s)
    in_str = False
    quote = None
    while i < n:
        ch = s[i]
        if in_str:
            out.append(ch)
            if ch == quote and (i == 0 or s[i - 1] != "\\"):
                in_str = False
            i += 1
            continue
        if ch in ("'", '"'):
            in_str = True
            quote = ch
            out.append(ch)
            i += 1
            continue
        if ch == "/" and i + 1 < n and s[i + 1] == "/":
            # 跳到行尾
            j = s.find("\n", i)
            if j == -1:
                break
            i = j  # 保留换行，避免把下一行粘上来
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def _parse_named_args(inner):
    """把 'id: "x", name: "y", relations: const {...}' 切成 {name: raw_value}。"""
    inner = _strip_line_comments(inner)
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
