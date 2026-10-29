# bugfix-shisiji-nav-blank

缺陷修复 · HarmonyOS API 24

## 来源

- 上游：`harmony-practice-center/HarmonyOS-METASERVICE-multi-server`（华为官方实践模板，元服务「四时集」），子目录 `harmony_app`，MIT 许可。
- 缺陷版本 `23b7c52b`；上游修复 `58856873`「根治冷启动导航白屏——ModuleHub 单枢纽 + MAIN_STACK 单例栈」。参考解即上游修复（12 个文件，约 140 行）。
- 环境适配（不改业务代码）：SDK 版本改为 API 24，加入 `@ohos/hypium` 依赖与 `ohosTest` 测试目标，bundle 名改为 `com.harmonybench.bf.shisijinav`。

## 缺陷

- **现象**：启动后首次进入「宠物领养」「书单书架」时页面空白，没有标题、筛选标签和列表，也不闪退；「餐厅点餐」正常。
- **根因**：Navigation 首次 push 时，`navDestination` builder（PageMap）中非首个分支会建出空的 NavDestination；另有通过 `@Provide/@Consume` 传递 `NavPathStack` 在冷启动首帧的时序问题。

## 难点

没有任何报错可循：不崩溃、无 JS 错误，只读代码时路由名和 PageMap 分支看起来都对。需要理解 Navigation 首次 push 与 `navDestination` builder 的运行时行为，换一种导航组织方式（单一首推目标、单例栈等）。

## 测试

一个测试点 `FP1_first_entry_shows_module`，分三个冷启动阶段，全部通过奖励为 1，否则为 0：

1. 首次进入「宠物领养」，出现标题「暖爪之家」、筛选标签「猫咪」和列表项「小黄」；
2. 首次进入「书单书架」，出现「拾光书局」「历史」「三体」；
3. 回归：进入「餐厅点餐」仍显示「过桥米线」。

①②分成两个冷启动阶段，只把某一个模块挪到 PageMap 首个分支的改法只能通过其中一个。上游修复版本中「酒店房型」打开会闪退（上游下一个提交修复的另一个缺陷），题面和测试都不涉及酒店。

## 运行环境

- 工程路径：`/workspace/app`。
- 镜像：Agent 阶段与 verifier 阶段都基于 `efflora/harmonyos-base:latest`（Command Line Tools 6.1.1.418，API 24）；Agent 镜像中创建 `agent` 用户。
- verifier：`environment_mode = "separate"`，通过 `artifacts = ["/workspace/app"]` 取得 Agent 修改后的工程，评分逻辑在 `tests/verify.py`。
- 设备：Pura 90 Pro 手机模拟器（1256×2760），HarmonyOS 6.1.1（API 24），zh-Hans-CN，Asia/Shanghai，由 `verify_config.json` 的 `device_expect` 逐项校验；通过宿主机的 `EFFLORA_DEVICE_SN` / `EFFLORA_HDC_SERVER` 指定，见 `docs/emulator-ui-tests.md`。
- 网络：Agent 阶段只放行 `api.anthropic.com`。Agent 超时 3 小时。

## 验证

Harbor 0.24.0，API 24 / zh-Hans-CN 模拟器：oracle 1、nop 0（①宠物阶段空白）；Agent 阶段在 allowlist 网络下可离线构建。
