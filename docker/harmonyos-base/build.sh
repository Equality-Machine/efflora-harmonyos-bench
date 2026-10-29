#!/usr/bin/env bash
# 构建任务基础镜像 efflora/harmonyos-base:latest。
# 用法：docker/harmonyos-base/build.sh [工具链 zip 路径]
#   不传路径时使用本目录下的 commandline-tools-linux-*.zip
#   EFFLORA_BASE_TAG    镜像标签，默认 efflora/harmonyos-base:latest（任务 Dockerfile 的 FROM）
#   EFFLORA_APT_MIRROR  可选，Ubuntu 软件源镜像，如 http://mirrors.tuna.tsinghua.edu.cn/ubuntu
#   EFFLORA_NPM_REGISTRY 可选，npm 源（预装 pnpm 用），如 https://registry.npmmirror.com
set -euo pipefail
cd "$(dirname "$0")"

ZIP=${1:-$(ls commandline-tools-linux-*.zip 2>/dev/null | head -1 || true)}
if [ -z "$ZIP" ] || [ ! -f "$ZIP" ]; then
  echo "找不到工具链压缩包。请从华为开发者联盟下载 Command Line Tools for HarmonyOS（Linux，6.1.1 / API 24），" >&2
  echo "放到 $(pwd)/ 下，或把路径作为参数传入。" >&2
  exit 1
fi
# 工具链按 SHA-256 锁定：Command Line Tools 6.1.1.418（Linux x86，内置 SDK 6.1.1.125 / API 24）
TOOLS_SHA256=39f1368dfcc6a8441f780cda44165e1f873f088680f250c382aa3324e95d9777
actual=$( (shasum -a 256 "$ZIP" 2>/dev/null || sha256sum "$ZIP") | cut -d' ' -f1)
if [ "$actual" != "$TOOLS_SHA256" ]; then
  echo "工具链压缩包 SHA-256 不符：$actual" >&2
  echo "需要 commandline-tools-linux-x64-6.1.1.418.zip（下载页「Command Line Tools 6.1.1 Release」那一行）。" >&2
  exit 1
fi
# docker build 只能读取构建上下文内的文件
if [ "$(cd "$(dirname "$ZIP")" && pwd)" != "$(pwd)" ]; then
  cp "$ZIP" .
  ZIP=$(basename "$ZIP")
fi

TAG=${EFFLORA_BASE_TAG:-efflora/harmonyos-base:latest}
docker build --platform linux/amd64 --build-arg TOOLS_ZIP="$(basename "$ZIP")" \
  --build-arg APT_MIRROR="${EFFLORA_APT_MIRROR:-}" --build-arg NPM_REGISTRY="${EFFLORA_NPM_REGISTRY:-}" -t "$TAG" .

echo "== 工具链自检"
docker run --rm --platform linux/amd64 "$TAG" bash -c \
  'echo "node $(node -v)"; echo "ohpm $(ohpm -v)"; hdc -v; command -v hvigorw; echo "DEVECO_SDK_HOME=$DEVECO_SDK_HOME"; date'
echo "已构建 $TAG"
