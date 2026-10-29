# 任务：修复缺陷 —— 首次进入宠物、书单模块时页面空白

## 问题描述
启动应用后，在首页点击「宠物领养」或「书单书架」，进入的页面一片空白：没有标题、筛选标签和列表，也没有闪退。「餐厅点餐」能正常进入。

期望：进入「宠物领养」后能看到页面标题「暖爪之家」、筛选标签「猫咪」和列表中的「小黄」；进入「书单书架」后能看到页面标题「拾光书局」、筛选标签「历史」和列表中的「三体」。

## 环境与交付
- 工程位于 `/workspace/app`，是一个 HarmonyOS 应用（ArkTS / ArkUI，Stage 模型），目标版本为 HarmonyOS 6.1.1（API 24）。
- 构建命令：`cd /workspace/app && hvigorw assembleHap --mode module -p product=default --no-daemon`。依赖已经预装；环境不能访问外网；环境中没有设备或模拟器。
- 交付标准：工程能成功构建；在 HarmonyOS 6.1.1（API 24）手机模拟器、简体中文环境下，按上面的步骤操作时问题不再出现、行为符合期望（由自动化 UI 测试验证）。
- 修复问题的根本原因，不要通过删除功能、跳过逻辑或吞掉异常来消除现象。
- 不要修改 `build-profile.json5`、`oh-package.json5`、`hvigorfile.ts`、`hvigor/` 目录、`entry/hvigorfile.ts`、`entry/build-profile.json5` 和 `entry/src/ohosTest/`。不需要提交 git commit。
