# 独立的 verifier 镜像。Harbor 不会把 tests/ 上传到专用的 verifier 镜像里，所以这里要自己 COPY 进 /tests。
# 设备凭据通过 task.toml 的 [verifier].env 注入，不要写死在镜像里。
FROM --platform=linux/amd64 efflora/harmonyos-base:latest
WORKDIR /workspace/app
COPY . /tests/
RUN chmod +x /tests/test.sh
