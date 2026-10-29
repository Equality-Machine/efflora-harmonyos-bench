# 任务格式约定

本基准遵循 **Harbor 0.24.0** 的[任务格式](https://docs.harborframework.com/tasks/overview)（`task.toml` 的 `schema_version = "1.4"`），并在其基础上增加了一些约定。运行环境约定（系统版本、API、设备、时区、语言）见 [`environment.md`](environment.md)。

## 目录结构

```text
tasks/<task-id>/          # 所有任务平铺；<task-id> = <category>-<app>-<short-desc>
├── instruction.md        # 必需：给 Agent 的任务说明
├── task.toml             # 必需：配置与元数据
├── environment/
│   ├── Dockerfile        # 必需：包含 API 24 鸿蒙工具链的镜像
│   └── ...               # 构建上下文：工程源码 / 缺陷补丁 / spec 文档等
├── solution/
│   └── solve.sh          # 必需：参考解
└── tests/
    ├── test.sh           # 必需：验证入口，写入 /logs/verifier/reward.txt
    └── ...               # 隐藏测试用例（ArkTS 测试文件、Python 校验脚本等）
```

新任务可用 Harbor 生成骨架后再按本文约定修改：

```bash
harbor task init efflora/<task-id> -p tasks --no-pytest
```

## task.toml

完整字段可用 `harbor task schema` 查看。本基准要求的最小配置：

```toml
schema_version = "1.4"

[task]
name = "efflora/bugfix-notepad-crash-on-empty-title"
version = "1.0.0"
description = "Fix crash when saving a note with an empty title"
keywords = ["harmonyos", "arkts", "bugfix"]

[[task.authors]]
name = "Your Name"
email = "you@example.com"

[metadata]
category = "bugfix"                 # feature | bugfix | spec
expert_time_estimate_min = 45      # 熟练工程师估计用时；难度分级方案待定
app = "notepad"
upstream_repo = "https://gitee.com/xxx/notepad"
upstream_commit = "<sha>"
upstream_license = "Apache-2.0"
api_level = 24                      # 固定为 24，见 environment.md
tags = ["state-management"]

[verifier]
timeout_sec = 1200
environment_mode = "shared"         # 测试需要在 Agent 修改后的同一环境中构建

[agent]
timeout_sec = 3600

[environment]
build_timeout_sec = 1800
cpus = 4
memory_mb = 8192
storage_mb = 20480
```

> 注意：鸿蒙任务需在 Agent 修改后的工程上直接构建和运行测试，本基准统一显式写 `verifier.environment_mode = "shared"`，且不得配置 `[verifier.environment]`（Harbor 0.24.0 中一旦配置该段即隐式切换为 `"separate"`，与 `"shared"` 同时出现会报错）。

## 奖励

- 二值任务：`test.sh` 写入 `1` 或 `0` 到 `/logs/verifier/reward.txt`。
- 部分得分（如 spec 多条验收标准）：写入 `/logs/verifier/reward.json`，例如：

```json
{"reward": 0.75, "build": 1, "ac_1": 1, "ac_2": 1, "ac_3": 1, "ac_4": 0}
```

## 验证分层

`tests/test.sh` 推荐按以下顺序执行，任一必需层失败即记 0 分：

1. **还原测试资产**：将 `/tests` 中的隐藏测试文件复制进工程（覆盖 Agent 可能修改的同名文件）。
2. **构建**：`hvigorw assembleHap --no-daemon`。
3. **单元测试**：运行本地单元测试（Hypium / LocalUnit）。
4. **静态检查（可选）**：`codelinter` 等。
5. **UI / 设备测试**：基于模拟器的 ArkUI 交互测试（Hypium），接入方式与奖励规则见 [`emulator-ui-tests.md`](emulator-ui-tests.md)；真机测试仍在规划中。

## 验证产物

`test.sh` 需把以下文件写入 `/logs/verifier/`，Harbor 会将其收集到 trial 的 `verifier/` 目录，并随提交上传到 HuggingFace（见 [`evaluation.md`](evaluation.md)）：

| 文件 | 内容 |
| --- | --- |
| `model.patch` | Agent 对工程的改动；须在复制隐藏测试**之前**导出 |
| `build.txt` / `build.log` | 构建是否通过（1/0）/ 构建日志 |
| `test.log` | 测试日志 |
| `*.hap` | 构建产物 |

任务的 `environment/Dockerfile` 需在 `/workspace/app` 建立 git baseline commit，`model.patch` 即相对该 baseline 的 diff。

## 防作弊

- 测试文件只放在 `tests/`，验证阶段才复制进工程，并覆盖同名文件。
- 不在 `environment/` 中放置参考实现或测试期望值。
- 测试应校验行为而非字符串匹配实现代码。
