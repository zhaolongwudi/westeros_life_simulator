#!/usr/bin/env python3
"""Dart 括号平衡检查（剥离注释与字符串，支持 raw string / 三引号 / 嵌套插值）。

用法：
    python3 scripts/check_brackets.py lib/screens/game_screen.dart lib/widgets/game/*.dart
    python3 scripts/check_brackets.py --all        # 检查 lib/ + test/ 全部 .dart

退出码 0 = 全部平衡，1 = 存在不平衡。
注意：Dart raw string（r'...'）内部不插值，括号按字面处理，仍计入平衡；
     若某文件存在「英文括号文案」等预存误报，请在 HANDOVER 记基线值后再判定。
"""
import glob
import re
import sys


def strip_code(content):
    """剥离注释与字符串字面量，保留结构字符。"""
    out = []
    i = 0
    n = len(content)
    while i < n:
        ch = content[i]
        nxt = content[i + 1] if i + 1 < n else ''
        # 行注释
        if ch == '/' and nxt == '/':
            while i < n and content[i] != '\n':
                i += 1
            continue
        # 块注释（支持嵌套）
        if ch == '/' and nxt == '*':
            depth = 1
            i += 2
            while i < n and depth:
                if content[i] == '/' and i + 1 < n and content[i + 1] == '*':
                    depth += 1
                    i += 2
                elif content[i] == '*' and i + 1 < n and content[i + 1] == '/':
                    depth -= 1
                    i += 2
                else:
                    if content[i] == '\n':
                        out.append('\n')
                    i += 1
            continue
        # 字符串（含 raw 前缀与三引号）
        if ch in '\'"' or (ch == 'r' and nxt in '\'"'):
            raw = False
            if ch == 'r':
                raw = True
                i += 1
            q = content[i]
            triple = content[i:i + 3] in ("'''", '"""')
            term = content[i:i + 3] if triple else q
            i += len(term)
            while i < n:
                if not raw and content[i] == '\\':
                    i += 2
                    continue
                # 插值 ${...}：内部可能有嵌套字符串与花括号，整段跳过
                if not raw and not triple and content[i] == '$' and content[i + 1:i + 2] == '{':
                    depth = 1
                    i += 2
                    while i < n and depth:
                        c = content[i]
                        if c in '\'"':
                            inner = content[i:i + 3] in ("'''", '"""')
                            iterm = content[i:i + 3] if inner else c
                            i += len(iterm)
                            while i < n and content[i:i + len(iterm)] != iterm:
                                if content[i] == '\\':
                                    i += 1
                                i += 1
                            i += len(iterm)
                            continue
                        if c == '{':
                            depth += 1
                        elif c == '}':
                            depth -= 1
                        i += 1
                    continue
                if content[i:i + len(term)] == term:
                    i += len(term)
                    break
                if content[i] == '\n':
                    out.append('\n')
                i += 1
            out.append(' ')
            continue
        out.append(ch)
        i += 1
    return ''.join(out)


def check(path):
    with open(path, encoding='utf-8') as fp:
        code = strip_code(fp.read())
    pairs = {'(': ')', '[': ']', '{': '}'}
    closers = {v: k for k, v in pairs.items()}
    stack = []
    for ch in code:
        if ch in pairs:
            stack.append(ch)
        elif ch in closers:
            if not stack or stack[-1] != closers[ch]:
                return 'MISMATCH at close %r' % ch
            stack.pop()
    if stack:
        return 'UNCLOSED %s' % ''.join(stack)
    return 'OK'


def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        return 2
    if args[0] == '--all':
        files = sorted(glob.glob('lib/**/*.dart', recursive=True) +
                       glob.glob('test/**/*.dart', recursive=True))
    else:
        files = []
        for a in args:
            files.extend(sorted(glob.glob(a)) or [a])
    bad = 0
    for f in files:
        try:
            res = check(f)
        except OSError as exc:
            res = 'ERROR %s' % exc
        if res != 'OK':
            bad += 1
            print('FAIL %s: %s' % (f, res))
    print('checked=%d bad=%d' % (len(files), bad))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())