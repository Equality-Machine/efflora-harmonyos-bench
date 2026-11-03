#!/usr/bin/env bash
# Harbor verifier 入口：只负责调用 verify.py，所有逻辑都在 verify.py 里。
# 退出码 2 = 基础设施错误（这种情况不写 reward 文件，trial 应作废并重跑）。
set -uo pipefail
mkdir -p /logs/verifier
python3 -I /tests/verify.py run --app /workspace/app --tests-dir /tests --logs-dir /logs/verifier
