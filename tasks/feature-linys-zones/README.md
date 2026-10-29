# feature-linys-zones

功能实现 · HarmonyOS API 24

## 来源

- 上游：[LinysBrowser_NEXT](https://github.com/awaLiny2333/LinysBrowser_NEXT)（冲浪喵浏览器，约 2.8 万行 ArkTS，单模块 `entry`），MIT 许可。
- base 为功能提交的父提交 `524514b9`；参考解基于上游提交 `950d5d9f`「feat: Zones!」（2026-05-29），去掉了与功能无关的改动，并修正了上游的一处缺陷：以工作区打开窗口时，无论「启动至页面」设置为何，都要恢复标签页。
- 环境适配（不改变用户可见行为）：SDK 版本改为 API 24，去掉签名配置，bundle 名改为 `com.harmonybench.linys.browser`；`newWindow()` 改为用调用方 Ability 的信息启动新窗口（上游取运行中 Ability 列表的第一项，在 `aa test` 下可能误启动测试框架的页面）；清除了父提交中预埋的工作区代码（Alt+Z 空处理函数、快捷键与设置条目、`isZone` 等），由 agent 从零接入。

## 需求

> 冲浪喵要支持「工作区」：把一个窗口连同它的标签页保存成工作区，以后随时重新打开。在「更多」面板里可以把当前窗口「设为工作区」，工作区以窗口名称命名，也可以再取消；按 Alt+Z 打开「工作区」面板，列出所有工作区，每个工作区有「打开」和「移除」两个按钮。

## 难点

- 标签页状态存放在每个窗口的工作目录 `filesDir/continues/<windowId>`，窗口关闭或冷启动时会被清理；工作区必须换到按名称寻址、不会被清理的位置，取消时再搬回。
- 「打开」要经 `specified` 多实例的 Want 把工作区身份传给新的 Ability 实例，新实例据此选择工作目录、恢复标签页并以工作区名作为窗口名。
- 要接入既有的快捷键系统（键位数组与设置项按下标持久化）和统一对话框管理器，并与「新窗口默认名称」改名逻辑共存。
- 题面不提的自然正确性也要满足：重启后仍在、重复打开不重复标签页、多个工作区互不串、空白标签页和未加载的标签页不丢失。

## 测试

全部 F-point 与回归检查通过时奖励为 1，否则为 0。每个测试点前重新安装应用（`reinstall_per_fpoint`），除特别说明外「启动至页面」保持默认值。

| 测试点 | 内容 |
| --- | --- |
| `FP1_zone_lifecycle` | 设为工作区 → 面板列出 → 取消 → 再设 A、B 两个工作区；冷启动后打开、关闭再打开、重复打开、移除，检查标签页、窗口名与列表 |
| `FP2_blank_tabs` | 含空白标签页的窗口设为工作区，冷启动后打开，空白标签页不能丢 |
| `FP3_lazy_zone` | 「恢复上次」启动、标签页未加载时直接设为工作区，冷启动后打开，标签页内容完整 |
| `R_window_rename` | 回归：普通窗口改名仍按原逻辑生效，且不出现在工作区面板中 |
| `R_restore_last` | 回归：「恢复上次」仍能恢复普通窗口的标签页 |
| `R_upstream_ability` | 上游 ohosTest 自带用例 |

## 运行环境

- 工程路径：`/workspace/app`。
- 镜像：Agent 阶段与 verifier 阶段都基于 `efflora/harmonyos-base:latest`（Command Line Tools 6.1.1.418，API 24）；Agent 镜像中创建 `agent` 用户。
- verifier：`environment_mode = "separate"`，通过 `artifacts = ["/workspace/app"]` 取得 Agent 修改后的工程，评分逻辑在 `tests/verify.py`。
- 设备：Pura 90 Pro 手机模拟器（1256×2760），HarmonyOS 6.1.1（API 24），zh-Hans-CN，Asia/Shanghai，由 `verify_config.json` 的 `device_expect` 逐项校验；通过宿主机的 `EFFLORA_DEVICE_SN` / `EFFLORA_HDC_SERVER` 指定，见 `docs/emulator-ui-tests.md`。
- 网络：Agent 阶段只放行 `api.anthropic.com`。Agent 超时 3 小时。

## 验证

2026-10-29 迁入本仓库后（Harbor 0.24.0，API 24 / zh-Hans-CN 模拟器）：oracle 1、nop 0（3 个回归通过，功能测试点失败）；Claude Code 实际运行时启动目录为 `/workspace/app`，离线构建成功。模型校准分数需在当前环境下重新测定。
