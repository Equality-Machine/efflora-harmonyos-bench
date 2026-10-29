# 任务基础镜像 efflora/harmonyos-base：HarmonyOS 6.1.1 / API 24 命令行工具链
#
# 工具链（Command Line Tools 6.1.1.418，Linux x86，内置 API 24 SDK）须自行从华为开发者联盟下载，放到本目录后用 build.sh 构建，
# 见 README.md。本仓库不分发该工具链。
FROM --platform=linux/amd64 ubuntu:22.04

ARG TOOLS_ZIP
# 可选：Ubuntu 软件源镜像，如 http://mirrors.tuna.tsinghua.edu.cn/ubuntu（build.sh 通过 EFFLORA_APT_MIRROR 传入）
ARG APT_MIRROR=
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Shanghai \
    LANG=C.UTF-8

RUN if [ -n "$APT_MIRROR" ]; then \
      sed -i "s|http://archive.ubuntu.com/ubuntu|$APT_MIRROR|g; s|http://security.ubuntu.com/ubuntu|$APT_MIRROR|g" /etc/apt/sources.list; \
    fi \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
       ca-certificates curl git python3 unzip tzdata libatomic1 \
       # hvigor 构建依赖：CompileResource 加载的图片转码库需要 libGL，PackageHap 需要 java
       libgl1 openjdk-17-jre-headless \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone \
    && rm -rf /var/lib/apt/lists/*

# 解压工具链到 /opt/command-line-tools，并把 SDK / node / hdc 的实际位置固定为 /opt/harmonyos 下的软链接
# 压缩包通过 bind mount 临时挂载，不留在镜像层里（约 2 GB）
RUN --mount=type=bind,source=${TOOLS_ZIP},target=/tmp/tools.zip \
    set -eu; \
    mkdir -p /tmp/clt && unzip -q /tmp/tools.zip -d /tmp/clt; \
    root=$(dirname "$(dirname "$(find /tmp/clt -path '*/bin/hvigorw' -type f | head -1)")"); \
    [ -d "$root" ] || { echo "工具链压缩包中没有 bin/hvigorw" >&2; exit 1; }; \
    mv "$root" /opt/command-line-tools && rm -rf /tmp/clt; \
    mkdir -p /opt/harmonyos; \
    sdk=$(dirname "$(find /opt/command-line-tools -type d -path '*/default/openharmony' | head -1)"); \
    [ -d "$sdk/openharmony/toolchains" ] || { echo "工具链压缩包中没有 SDK（default/openharmony）" >&2; exit 1; }; \
    ln -s "$(dirname "$sdk")" /opt/harmonyos/sdk; \
    ln -s "$sdk/openharmony/toolchains" /opt/harmonyos/toolchains; \
    node=$(dirname "$(dirname "$(find /opt/command-line-tools -path '*/bin/node' -type f | head -1)")"); \
    [ -f "$node/bin/node" ] && chmod +x "$node/bin/node" || { echo "工具链压缩包中没有 node" >&2; exit 1; }; \
    ln -s "$node" /opt/harmonyos/node; \
    grep -rqsE '"apiVersion" *: *"?24"?' "$sdk/sdk-pkg.json" "$sdk/openharmony/ets/oh-uni-package.json" \
      || { echo "工具链中的 SDK 不是 API 24" >&2; exit 1; }; \
    chmod +x /opt/command-line-tools/bin/* /opt/harmonyos/toolchains/hdc; \
    # 压缩包内的目录权限是 700，非 root 用户（如任务的 agent 用户）无法使用工具链
    chmod -R a+rX /opt/command-line-tools

# HARMONY_HOME 指向工具链根目录（含 version.txt），评分脚本据此读取工具链版本
ENV HARMONY_HOME=/opt/command-line-tools \
    DEVECO_SDK_HOME=/opt/harmonyos/sdk \
    NODE_HOME=/opt/harmonyos/node \
    LD_LIBRARY_PATH=/opt/harmonyos/toolchains \
    PATH=/opt/command-line-tools/bin:/opt/harmonyos/node/bin:/opt/harmonyos/toolchains:$PATH

RUN node -v && ohpm -v && hdc -v

# hvigor 首次构建会执行 npm install pnpm 到 $HVIGOR_USER_HOME/wrapper/tools。这里固定为所有用户共用的目录，
# 并按 hvigor 的做法预装同一个 pnpm：Agent 与评分阶段的构建都不再需要访问 npm。
# pnpm 版本由 hvigor 决定（CLT 6.1.1.418 / hvigor 6.24.5 安装的是 pnpm@10.28.2），升级工具链时需要核对。
# 可选：npm 源，如 https://registry.npmmirror.com（build.sh 通过 EFFLORA_NPM_REGISTRY 传入）
ARG NPM_REGISTRY=
ENV HVIGOR_USER_HOME=/opt/hvigor-home
RUN set -eu; \
    mkdir -p "$HVIGOR_USER_HOME/wrapper/tools" && cd "$HVIGOR_USER_HOME/wrapper/tools"; \
    npm install --no-audit --no-fund ${NPM_REGISTRY:+--registry=$NPM_REGISTRY} pnpm@10.28.2; \
    [ "$(node_modules/.bin/pnpm --version)" = "10.28.2" ]; \
    rm -rf /root/.npm; \
    chmod -R a+rwX "$HVIGOR_USER_HOME"

WORKDIR /workspace
