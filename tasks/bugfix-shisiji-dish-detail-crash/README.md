# bugfix-shisiji-dish-detail-crash

缺陷修复 · HarmonyOS API 24

## 来源

- 上游：`harmony-practice-center/HarmonyOS-METASERVICE-multi-server`（华为官方实践模板，元服务「四时集」），子目录 `harmony_app`，MIT 许可。
- 缺陷版本 `a900553d`；上游修复 `23b7c52b`「修复详情弹层二次渲染闪退 + 各模块补返回按钮」。参考解即上游修复（6 个文件，+190/−120）。
- 环境适配（不改业务代码）：SDK 版本改为 API 24，加入 `@ohos/hypium` 依赖与 `ohosTest` 测试目标，bundle 名改为 `com.harmonybench.bf.shisijisheet`。

## 缺陷

- **现象**：进入「餐厅点餐」点击菜品打开详情即闪退（jscrash：`dishTotal is not callable` @ `DiningList.ets:374`，经 `DetailSheet.ets:51`）。
- **根因**：通用壳组件 `DetailSheet` 通过 `@BuilderParam` 接收页面传入的 `@Builder`（价格行、正文）。这些 builder 在壳组件中执行时 `this` 不再指向页面，调用页面方法 `dishTotal()` 失败。

## 难点

崩溃没有可用的堆栈，现象在菜品点击处，根因在跨组件的 builder 传递方式，需要了解 `@BuilderParam` 的 `this` 绑定规则（箭头函数包装，或由页面自己渲染弹层内容）。修复不能扩大范围：餐厅页「今日特惠」条同样把 `this.dealStripContent` 传给 `@BuilderParam`，当前不会崩溃；若也改为绑定 `this`，特惠条会按分钟重新渲染，触发上游另一个缺陷而闪退。

## 测试

一个测试点 `FP1_open_dish_detail_twice`，通过奖励为 1，否则为 0：在餐厅点餐中先后打开「过桥米线」「汽锅鸡」的详情弹层，断言营业信息行、菜名、价格（与列表一致）和第一组规格选项（过桥米线「吃法 / 配好端出」、汽锅鸡「辣度 / 原汤原味」）出现。应用崩溃时 `aa test` 报 App died，判为失败。

上游代码中「酒店房型」「宠物领养」「书单书架」冷启动首跳为空白页（另一个缺陷，见 `bugfix-shisiji-nav-blank`），保持原样，测试不进入这些模块。

## 运行环境

- 工程路径：`/workspace/app`。
- 镜像：Agent 阶段与 verifier 阶段都基于 `efflora/harmonyos-base:latest`（Command Line Tools 6.1.1.418，API 24）；Agent 镜像中创建 `agent` 用户。
- verifier：`environment_mode = "separate"`，通过 `artifacts = ["/workspace/app"]` 取得 Agent 修改后的工程，评分逻辑在 `tests/verify.py`。
- 设备：Pura 90 Pro 手机模拟器（1256×2760），HarmonyOS 6.1.1（API 24），zh-Hans-CN，Asia/Shanghai，由 `verify_config.json` 的 `device_expect` 逐项校验；通过宿主机的 `EFFLORA_DEVICE_SN` / `EFFLORA_HDC_SERVER` 指定，见 `docs/emulator-ui-tests.md`。
- 网络：Agent 阶段开放互联网，题面末尾声明不得查找本任务的线上解答；上游修复提交公开可见，审查轨迹时发现访问上游仓库或该提交，该次 trial 记 0 分。Agent 超时 1 小时。

## 验证

Harbor 0.24.0，API 24 / zh-Hans-CN 模拟器：oracle 1、nop 0（App died）。
