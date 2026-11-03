# 任务：为 Cogit Lucid 增加「新建预测与结算」

## 需求
「预测日志」目前只能查看已有预测，无法新增和结算。请在「预测日志」页右上角加一个「＋」入口，打开「新建预测」页，填写预测对象、判断、置信度、理由和结算日后保存；在待结算预测的「预测详情」页提供「结算这条预测」，用户填写实际结果并选择命中或未命中后完成结算。

## 环境与交付
- 工程位于 `/workspace/app`，是一个 HarmonyOS 应用（ArkTS / ArkUI，Stage 模型），工程按 HarmonyOS 6.1.1（API 24）构建。
- 构建命令：`cd /workspace/app && hvigorw assembleHap --mode module -p product=default --no-daemon`。依赖已经预装；环境中没有设备或模拟器，也不能联网。
- 交付标准：工程能成功构建；在 HarmonyOS 6.1.1（API 24）手机模拟器、简体中文环境下，新功能按需求工作，已有功能不受影响（由自动化 UI 测试验证，测试通过界面控件读取文字）。
- 禁止作弊：不得通过网络搜索（包括 Web 搜索、网页抓取等工具）或任何其他外部渠道查找本任务的答案、参考实现或相关代码。agent 的完整操作轨迹会被审计，一经发现上述行为即视为作弊，本次结果判为 0 分。
- 不要修改 `build-profile.json5`、`oh-package.json5`、`hvigorfile.ts`、`hvigor/` 目录、`entry/hvigorfile.ts`、`entry/build-profile.json5`、`entry/oh-package.json5` 和 `entry/src/ohosTest/`。不需要提交 git commit。

不允许通过联网查找针对此任务的在线解答或提示来作弊。
