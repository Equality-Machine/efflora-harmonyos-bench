# 独立的 verifier 镜像。Harbor 不会把 tests/ 上传到专用的 verifier 镜像里，所以这里要自己 COPY 进 /tests。
# Agent 的 /workspace/app 由 task.toml 的 artifacts 传入；设备凭据通过 [verifier.env] 注入，不要写死在镜像里。
FROM --platform=linux/amd64 efflora/harmonyos-base:latest
ENV TZ=Asia/Shanghai
WORKDIR /workspace/app
COPY . /tests/
RUN chmod +x /tests/test.sh
