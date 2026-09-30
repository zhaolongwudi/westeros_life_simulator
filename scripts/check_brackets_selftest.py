#!/usr/bin/env python3
"""check_brackets.py 自检：合成用例必须被正确判定。

覆盖：普通嵌套 / 注释 / 嵌套块注释 / 行内字符串 / 三引号 / raw string / 转义 /
      插值含嵌套引号与花括号。
"""
import os
import subprocess
import sys
import tempfile

CASES = [
    ('ok_basic', "void main() {\n  f(1);\n}\n", 'OK'),
    ('ok_nested', "void main() {\n  if (a) { b(c); }\n}\n", 'OK'),
    ('ok_comment', "void main() {\n  // }\n  /* ( */\n  a();\n}\n", 'OK'),
    # Dart 支持嵌套块注释：外层 /* 内层 /* } */ 继续 */ 才闭合
    ('ok_comment_nested', "void main() {\n  /* /* } */ */ a();\n}\n", 'OK'),
    ('ok_str_brace', "var s = 'a } b';\nvar t = \"c ) d\";\n", 'OK'),
    ('ok_triple', "var s = '''\n  a } b (\n''';\n", 'OK'),
    ('ok_raw', "var r = r'\\d{2,3}';\nvar t = r\"[a-z]+\";\n", 'OK'),
    ('ok_escape', "var s = 'it\\'s }';\n", 'OK'),
    ('ok_interp_nested', "var s = 'x ${ m[\"k}\"] } y';\n", 'OK'),
    ('ok_interp_nested2', 'var s = "a ${ f(\'{\') } b";\n', 'OK'),
    ('ok_interp_brace', "var s = 'a ${ m() } b';\n", 'OK'),
    ('ok_trailing', "void main() {}\n// tail )\n", 'OK'),
    # 真实项目里出现过的形态：文案里的英文括号（三引号内）
    ('ok_triple_cn', "var s = '''\n（已完成） 甲（乙）\n''';\n", 'OK'),
    ('bad_unclosed', "void main() {\n  a();\n", 'UNCLOSED'),
    ('bad_extra', "void main() {\n  a();\n}}\n", 'MISMATCH'),
    ('bad_mismatch', "void main() {\n  a();\n  ]\n}\n", 'MISMATCH'),
    # 嵌套块注释未闭合是真实错误（Dart 语义：首个 */ 只闭合内层）
    ('bad_comment_unclosed', "void main() {\n  /* /* } */ a();\n}\n", 'UNCLOSED'),
]

fails = 0
for name, src, expect in CASES:
    with tempfile.NamedTemporaryFile('w', suffix='.dart', delete=False,
                                     encoding='utf-8') as f:
        f.write(src)
        path = f.name
    proc = subprocess.run([sys.executable, 'scripts/check_brackets.py', path],
                          capture_output=True, text=True)
    os.unlink(path)
    out = proc.stdout.strip()
    if expect == 'OK':
        ok = proc.returncode == 0 and 'bad=0' in out
    else:
        ok = proc.returncode == 1 and expect in out
    if not ok:
        fails += 1
    print('%-4s %-22s expect=%-9s rc=%d %s' %
          ('OK' if ok else 'FAIL', name, expect, proc.returncode,
           out.replace('\n', ' | ')))
print('selftest fails=%d' % fails)
sys.exit(1 if fails else 0)