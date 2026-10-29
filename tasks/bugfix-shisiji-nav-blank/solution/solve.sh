#!/usr/bin/env bash
# 参考解：把 solution.patch 应用到 /workspace/app，然后构建自检。
set -euo pipefail
cd /workspace/app
git -c safe.directory='*' apply --whitespace=nowarn "$(dirname "$0")/solution.patch"
hvigorw assembleHap --mode module -p product=default --no-daemon
