# 评测说明

## 数据存放原则

| 位置 | 内容 |
| --- | --- |
| **GitHub**（本仓库） | 任务包（`tasks/`） |
| **HuggingFace** [`efflora/harmonyos-bench-runs`](https://huggingface.co/datasets/efflora/harmonyos-bench-runs) | 完整运行产物与轨迹，格式为 Harbor 导出的原始 job 目录 |

运行产物（日志、轨迹、`.hap`、补丁）体积大，**不进入 GitHub 仓库**（`jobs/` 已在 `.gitignore` 中）。原始结果保持 Harbor 格式不做转换，方便用 Harbor 工具查看与重新评分。该做法参考了 Terminal-Bench 2.0 的 [`harborframework/terminal-bench-2-leaderboard`](https://huggingface.co/datasets/harborframework/terminal-bench-2-leaderboard)。

## 运行

必须使用 Harbor **0.24.0**（`uv tool install harbor==0.24.0`），运行环境约定见 [`environment.md`](environment.md)。

```bash
# 一次运行全部任务；每个任务至少 3 次 trial
harbor run -p tasks -a <agent> -m <provider/model> -k 3
```

不得修改超时、资源、verifier 配置（不使用 `--timeout-multiplier`、`override_*` 等），否则提交校验不通过。

## 每次 trial 的产物

Harbor 为每次 trial 生成一个目录 `<job>/<task>__<id>/`：

| 路径 | 内容 |
| --- | --- |
| `result.json` | 奖励、各阶段耗时、token、费用、异常信息 |
| `agent/` | Agent 日志；支持 [ATIF](https://docs.harborframework.com/agents/atif) 的 Agent 会输出 `trajectory.json` |
| `artifacts/` | `task.toml` 中声明的产物 + `manifest.json` |
| `verifier/reward.txt` / `reward.json` | 奖励 / 细分结果（如各 F-point） |
| `verifier/test-stdout.txt` | `test.sh` 标准输出 |
| `verifier/model.patch` | Agent 对工程的改动（相对任务 baseline） |
| `verifier/build.txt` / `build.log` | 构建是否通过 / 构建日志 |
| `verifier/test.log` | 测试日志 |
| `verifier/*.hap` | 构建产物 |

其中 `verifier/` 下的鸿蒙相关产物由各任务的 `tests/test.sh` 写入 `/logs/verifier/`（见 [`task-format.md`](task-format.md#验证产物)）。

## 指标

| 指标 | 定义 |
| --- | --- |
| **Mean Reward**（主指标） | 所有 trial 奖励的均值，即 pass@1 的期望 |
| **Resolved Rate** | 奖励为 1 的 trial 占比 |
| **Build Rate** | 构建通过的 trial 占比（诊断用） |
| **Error Rate** | Agent/环境异常（超时等）的 trial 占比 |
| **Per-category** | 上述指标在 feature / bugfix / spec 上分别统计（按任务名前缀归类） |

## 提交结果

### 1. 整理提交目录

```text
<agent>__<model>/
├── metadata.yaml        # 见下方示例
└── <job-dir>/ ...       # 把 jobs/ 下本次评测的 job 目录原样拷入
```

`metadata.yaml`：

```yaml
agent_url: "https://..."              # Agent 项目或文档链接
agent_display_name: "My Agent"
agent_org_display_name: "My Org"
agent_version: ""

models:                               # Agent 使用的所有模型
  - model_name: "claude-opus-5-5"
    model_provider: "anthropic"
    model_display_name: "Claude Opus 5.5"
    model_org_display_name: "Anthropic"

benchmark_version: "v0.1"             # GitHub 仓库的 release tag
benchmark_commit: ""                  # 运行时任务仓库的 commit sha
harbor_version: "0.24.0"              # 固定版本，其他版本的结果不予收录

submitter: ""                         # 提交人 / 联系方式
notes: ""                             # 其他说明
```

### 2. 本地校验

```bash
pip install -r scripts/requirements.txt
python3 scripts/validate_submission.py <agent>__<model>
```

校验内容：`metadata.yaml` 必填字段（含 `harbor_version` 须为 `0.24.0`）；job 配置未覆盖超时/资源/verifier；每个 trial 有 `result.json`、`agent/`、`verifier/`；覆盖当前版本全部任务且每个任务 ≥ 3 次 trial；大文件可走 LFS。

### 3. 向 HuggingFace 数据集发起 PR

```bash
hf auth login
hf upload efflora/harmonyos-bench-runs ./<agent>__<model> \
  submissions/<benchmark-version>/<agent>__<model> \
  --repo-type dataset --create-pr
```

> 若设置了 `HF_ENDPOINT=https://hf-mirror.com` 等镜像，镜像只读，上传前需临时改回官方地址：`HF_ENDPOINT=https://huggingface.co hf upload ...`。

### 4. 维护者审核

维护者审核轨迹（抽查是否存在访问测试、篡改验证等作弊行为）后合并 HF PR。

> 初期仅收录维护者运行的结果；社区提交在审核流程稳定后开放。
