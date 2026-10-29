# 任务基础镜像 efflora/harmonyos-base

所有任务的 `environment/Dockerfile` 都以 `FROM efflora/harmonyos-base:latest` 开头。该镜像包含 HarmonyOS 6.1.1 / API 24 命令行工具链（hvigorw、ohpm、hdc、node），时区为 Asia/Shanghai。

工具链由华为发布，本仓库不分发，也不提供公开镜像。请自行下载后在本地构建；Harbor 构建任务环境时会直接使用本地的同名镜像。

## 构建

1. 登录[华为开发者联盟](https://developer.huawei.com/consumer/cn/download/)，下载 **Command Line Tools for HarmonyOS** 的 Linux 版本（6.1.1，含 API 24 SDK），得到 `commandline-tools-linux-x64-*.zip`。
2. 把压缩包放到本目录（已被 `.gitignore` 忽略），然后执行：

   ```bash
   docker/harmonyos-base/build.sh
   # 或指定压缩包路径
   docker/harmonyos-base/build.sh ~/Downloads/commandline-tools-linux-x64-6.1.1.xxx.zip
   ```

3. 构建结束时会打印工具链版本自检结果。之后即可运行任务：

   ```bash
   harbor run -p tasks -a oracle
   ```

构建时会校验压缩包中包含 `bin/hvigorw`、node、API 24 SDK 与 hdc，缺少任一项即构建失败。

## 镜像内容

| 项 | 位置 |
| --- | --- |
| 系统 | Ubuntu 22.04（linux/amd64） |
| 工具链 | `HARMONY_HOME=/opt/command-line-tools`（所有用户可读），`bin/` 已加入 `PATH`（hvigorw、ohpm） |
| SDK | `DEVECO_SDK_HOME=/opt/harmonyos/sdk` |
| node | `NODE_HOME=/opt/harmonyos/node` |
| hdc | `/opt/harmonyos/toolchains/hdc`（已加入 `PATH`） |
| hvigor 用户目录 | `HVIGOR_USER_HOME=/opt/hvigor-home`，所有用户共用；构建镜像时按 hvigor 的做法预装 pnpm（`wrapper/tools`），运行时构建不需要访问 npm |
| 其他 | git、python3、unzip、curl、libatomic1、libgl1、openjdk-17-jre-headless（hvigor 构建依赖）；`TZ=Asia/Shanghai` |

## 注意事项

- **只有 x86_64 版本**：华为的 Linux 工具链只提供 x64 版本，镜像固定为 `linux/amd64`。在 Apple Silicon 的 Mac 上会以模拟方式运行，hvigor 构建明显变慢；使用 colima 时建议开启 Rosetta（`colima start --vm-type vz --vz-rosetta`）。
- **国内网络**：访问 Ubuntu 官方软件源较慢或不通时，可指定镜像：`EFFLORA_APT_MIRROR=http://mirrors.tuna.tsinghua.edu.cn/ubuntu docker/harmonyos-base/build.sh`。预装 pnpm 需要访问 npm，`registry.npmjs.org` 不通时同时指定 `EFFLORA_NPM_REGISTRY=https://registry.npmmirror.com`。
- **构建任务环境需要联网**：各任务的 Dockerfile 会从 GitHub 拉取上游工程，并执行 `ohpm install` 拉取依赖。
- **团队内共享**：如需在团队内共享镜像，请推送到私有镜像仓库，并按工具链的许可协议使用，不要推送到公开仓库。拉取后打上 `efflora/harmonyos-base:latest` 标签即可。
