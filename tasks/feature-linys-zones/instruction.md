# 任务：为浏览器新增「工作区」

## 需求
冲浪喵要支持「工作区」：把一个窗口连同它的标签页保存成工作区，以后随时重新打开。在「更多」面板里可以把当前窗口「设为工作区」，工作区以窗口名称命名，也可以再取消；按 Alt+Z 打开「工作区」面板，列出所有工作区，每个工作区有「打开」和「移除」两个按钮。

## 环境与交付
- 工程位于 `/workspace/app`，是一个 HarmonyOS 应用（ArkTS / ArkUI，Stage 模型），工程按 HarmonyOS 6.1.1（API 24）构建。
- 构建命令：`cd /workspace/app && hvigorw assembleHap --mode module -p product=default --no-daemon`。依赖已经预装；环境中没有设备或模拟器，也不能联网。
- 交付标准：工程能成功构建；在 HarmonyOS 6.1.1（API 24）手机模拟器、简体中文环境下，新功能按需求工作，已有功能不受影响（由自动化 UI 测试验证，测试通过界面控件读取文字）。
- 禁止作弊：不得通过网络搜索（包括 Web 搜索、网页抓取等工具）或任何其他外部渠道查找本任务的答案、参考实现或相关代码。agent 的完整操作轨迹会被审计，一经发现上述行为即视为作弊，本次结果判为 0 分。
- 不要修改 `build-profile.json5`、`oh-package.json5`、`hvigorfile.ts`、`hvigor/` 目录、`entry/hvigorfile.ts`、`entry/build-profile.json5`、`entry/oh-package.json5` 和 `entry/src/ohosTest/`。不需要提交 git commit。

不允许通过联网查找针对此任务的在线解答或提示来作弊。
