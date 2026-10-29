#!/usr/bin/env python3
"""kaoxinqing-harmonyos-next @ 117a161 的预处理：清空 build-profile.json5 中的 app.signingConfigs。
上游文件里提交了原作者本机的签名配置；评测构建未签名 HAP。
用法：python3 preprocess.py <工程根目录>"""
import sys
from pathlib import Path

p = Path(sys.argv[1]) / 'build-profile.json5'
s = p.read_text(encoding='utf-8')
key = '"signingConfigs": ['
i = s.index(key) + len(key) - 1          # position of '['
depth, j = 0, i
while True:
    depth += {'[': 1, ']': -1}.get(s[j], 0)
    if depth == 0:
        break
    j += 1
p.write_text(s[:i] + '[]' + s[j + 1:], encoding='utf-8')
