# 基准环境约定

本基准的所有任务（说明、参考解、测试）与评测结果均以下列环境为准。偏离这些约定的任务不予合入，使用其他 Harbor 版本运行的结果不予收录。

| 项 | 约定值 |
| --- | --- |
| 系统版本 | HarmonyOS 6.1.1(24) |
| 系统 API 版本 | 24 |
| 设备型号 | Pura 90 Pro |
| 分辨率 | 1256 × 2760 |
| 时区 | Asia/Shanghai |
| 语言 | zh-Hans-CN |
| Harbor | 0.24.0 |

## 在任务中的落地方式

### 系统版本 / API 版本

- `task.toml` 中 `metadata.api_level = 24`（`scripts/validate_tasks.py` 会校验）。
- 工程 `build-profile.json5` 的 `compatibleSdkVersion` / `targetSdkVersion` 使用 `"6.1.1(24)"`。
- `instruction.md` 与测试只能依赖 API 24 可用的接口；不得要求 Agent 使用更高版本才有的能力。
- 任务镜像中的鸿蒙命令行工具链固定为 Command Line Tools 6.1.1.418（Linux x86，内置 HarmonyOS 6.1.1 SDK 6.1.1.125，API 24），按 SHA-256 锁定。所有任务的 Dockerfile 都基于 `efflora/harmonyos-base:latest`，该镜像需在本地构建，见 [`../docker/harmonyos-base/README.md`](../docker/harmonyos-base/README.md)。

### 设备型号 / 分辨率

- 涉及布局、尺寸、断点的需求与测试，以 Pura 90 Pro、1256 × 2760 为准；如需折算 vp，在 `instruction.md` 中写明。
- 模拟器 UI 测试统一使用该设备配置，接入方式见 [`emulator-ui-tests.md`](emulator-ui-tests.md)；真机 UI 测试仍在规划中。

### 时区

- 任务镜像设置 `TZ=Asia/Shanghai`，构建与本地单元测试都在该时区下运行。
- 涉及日期、时间的需求与测试按 Asia/Shanghai 计算，不得依赖宿主机时区。

### 语言

- 系统语言为 zh-Hans-CN：资源按 `zh_CN` 限定词目录优先、`base` 兜底解析。
- 涉及文案、日期 / 数字格式的测试按 zh-Hans-CN 断言；系统级弹窗（权限请求等）的按钮文字为中文。

## Harbor 版本

- 固定使用 Harbor **0.24.0**：`uv tool install harbor==0.24.0`（或 `pip install harbor==0.24.0`）。
- 任务的 `task.toml` 使用该版本对应的 `schema_version = "1.4"`，格式见 [`task-format.md`](task-format.md)。
- 提交评测结果时须在 `metadata.yaml` 中填写 `harbor_version: "0.24.0"`（`scripts/validate_submission.py` 会校验）。
