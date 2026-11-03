# feature-cogit-prediction

功能实现 · HarmonyOS API 24

## 来源

- 上游：[cogit-lucid-workbench](https://gitee.com/theangelnextdoor/cogit-lucid-workbench)（Cogit Lucid 元认知外化工作台，单模块 `entry`），AGPL-3.0 许可（`environment/app/LICENSE` 原样保留）。
- base 为上游提交 `c6d85eaa`「fix(prediction): count settled without hit as miss」；参考解由功能提交 `c6d85ea..86c374b`（共 6 个提交，2026-10-27）组成，并入后续两个真实修复：`9f1355e`「fix(prediction): refresh settled rows in detail」（详情页信息行改为带 `@Param` 的子组件）和 `86c6b08`「fix(home): refresh dashboard after record changes」中 `HomeRefreshBus` 的最小部分。参考解没有出题人自己写的修正。
- 环境适配（不改变用户可见行为）：`targetSdkVersion` 改为 `6.1.1(24)`，去掉签名配置，bundle 名改为 `com.harmonybench.cogit.nf8`，补上 `ohosTest` 骨架和 `@ohos/hypium` 依赖；`modelVersion` 由 `26.0.0` 改为 `6.1.1`（Command Line Tools 6.1.1.418 的 hvigor 最高只支持 6.1.1）；删除两处直接描述目标功能的占位文案（详情页「结算功能将在预测日志阶段接入」、列表页空状态「预测创建入口稍后开放」）。

## 需求

> 「预测日志」目前只能查看已有预测，无法新增和结算。请在「预测日志」页右上角加一个「＋」入口，打开「新建预测」页，填写预测对象、判断、置信度、理由和结算日后保存；在待结算预测的「预测详情」页提供「结算这条预测」，用户填写实际结果并选择命中或未命中后完成结算。

## 难点

- 详情页的「状态 / 命中 / 实际结果」三行是多参数 `@Builder infoRow(label, value)`，参数按值传递。结算后在详情页里给 `detail` 重新赋值，只有顶部标签会变，三行仍显示「待结算 / 未结算 / —」。上游 `86c374b` 有这个问题，`9f1355e` 修复。
- 首页靠 `pushPathByName(..., onPop)` 刷新，而 `onPop` 只在 `pop(result)` 时触发，系统返回和 `pop(true)` 都不会触发，所以新建或结算后回到首页，待结算数、命中率和待结算卡片都不更新。上游 `86c374b` 有这个问题，`86c6b08` 修复。
- 预测日志的 `.menus` 只接受一个 builder，加「＋」时不能把原有的「统计」入口挤掉。
- 题面没提但功能自然要求的行为也要满足：列表计数与「已结算 / 待结算」筛选、统计页、命中率的分母计入未命中、冷启动后数据仍在、必填项为空时不能保存。

## 测试

全部 F-point 与回归检查通过时奖励为 1，否则为 0。每个测试点前重新安装应用（`reinstall_per_fpoint`），各阶段之间冷启动。

| 测试点 | 内容 |
| --- | --- |
| `FP1_create` | 预测日志右上角有「＋」且「统计」仍在 → 空表单不能保存 → 保存后列表出现、待结算 +1 → 系统返回首页，待结算数与待结算卡片更新 → 冷启动后仍在 |
| `FP2_settle_detail` | 在「预测详情」结算（命中 / 未命中）后不离开详情页，状态 / 命中 / 实际结果三行显示新值，结算入口消失；冷启动后保持 |
| `FP3_settle_effects` | 结算后列表计数与筛选、系统返回首页后的待结算数 / 命中率 / 待结算卡片、未命中计入命中率分母、统计页，冷启动后保持 |
| `R_note` | 回归：首页「＋ 速记」记一条并保存，冷启动后「最近速记」里有它 |
| `R_upstream_ability` | 上游 ohosTest 自带用例 |

## 运行环境

- 工程路径：`/workspace/app`。
- 镜像：Agent 阶段与 verifier 阶段都基于 `efflora/harmonyos-base:latest`（Command Line Tools 6.1.1.418，API 24）；Agent 镜像中创建 `agent` 用户。
- verifier：`environment_mode = "separate"`，通过 `artifacts = ["/workspace/app"]` 取得 Agent 修改后的工程，评分逻辑在 `tests/verify.py`。
- 设备：Pura 90 Pro 手机模拟器（1256×2760），HarmonyOS 6.1.1（API 24），zh-Hans-CN，Asia/Shanghai，`verify_config.json` 的 `device_expect` 会逐项校验；具体用哪台通过宿主机的 `EFFLORA_DEVICE_SN` / `EFFLORA_HDC_SERVER` 指定，见 `docs/emulator-ui-tests.md`。
- 网络：Agent 阶段只放行 `api.anthropic.com`。Agent 超时 3 小时。

## 验证

迁入本仓库前（Command Line Tools 26.0.0.851，API 24 / zh-Hans-CN 模拟器）：oracle 两次均为 1，nop 为 0；Opus 5.5 四次中通过 2 次，失败都出在详情页信息行不刷新。迁入后在 `efflora/harmonyos-base:latest` 中验证过：base 工程和参考解都能离线构建，隐藏测试 HAP 也能编译，工具链校验通过（`verify.py run --no-device`）。2026-10-31 在本仓库中运行（Harbor 0.24.0，API 24 / zh-Hans-CN 模拟器）：oracle 为 1（5 个测试点全部通过，F-point 阶段共 521 秒），nop 为 0（2 个回归检查通过，3 个功能测试点失败）。模型校准分数需在当前环境下重新测定。
