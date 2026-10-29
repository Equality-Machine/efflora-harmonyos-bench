# 任务：修复缺陷 —— 点开菜品详情时应用闪退

## 问题描述
在首页进入「餐厅点餐」，点击菜品列表中的任意一道菜（例如「过桥米线」）查看详情，应用立即闪退。

期望：点击菜品后从底部弹出该菜品的详情弹层（显示菜名、价格、门店营业信息和规格选项）；关闭弹层后再点开其他菜品（例如「汽锅鸡」）也能正常显示，应用不闪退。

## 环境与交付
- 工程位于 `/workspace/app`，是一个 HarmonyOS 应用（ArkTS / ArkUI，Stage 模型），在 API 24 上运行。
- 构建命令：`cd /workspace/app && hvigorw assembleHap --mode module -p product=default --no-daemon`。依赖已经预装；环境可以访问外网；环境中没有设备或模拟器。
- 交付标准：工程能成功构建；在 API 24 手机模拟器、简体中文环境下，按上面的步骤操作时问题不再出现、行为符合期望（由自动化 UI 测试验证）。
- 修复问题的根本原因，不要通过删除功能、跳过逻辑或吞掉异常来消除现象。
- 不要修改 `build-profile.json5`、`oh-package.json5`、`hvigorfile.ts`、`hvigor/` 目录、`entry/hvigorfile.ts`、`entry/build-profile.json5` 和 `entry/src/ohosTest/`。不需要提交 git commit。

不允许通过联网查找针对此任务的在线解答或提示来作弊。
