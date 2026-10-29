# 按规格实现书架分组

请阅读 `/workspace/spec/spec.md`，在 `/workspace/app` 的 HarmonyOS 工程中实现其中描述的功能。

- 规格文档是需求的唯一事实来源，请实现其中描述的全部场景。
- 目标 API 版本：24（HarmonyOS 6.1.1）。
- 不要引入新的第三方依赖。
- 只读写 `/workspace/app` 内的文件。环境中没有设备或模拟器，不要尝试安装或运行应用。

完成后工程必须能通过构建：

```bash
cd /workspace/app && hvigorw --mode module -p product=default -p buildMode=debug assembleHap --no-daemon
```
