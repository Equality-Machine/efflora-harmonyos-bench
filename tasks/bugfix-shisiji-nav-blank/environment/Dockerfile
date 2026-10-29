# Agent 沙箱：基础镜像 + base 工程。
# environment/app/ 中只放 base 工程本身，不能带上游仓库的 .git 历史（bug-fix 题尤其重要）。
FROM --platform=linux/amd64 efflora/harmonyos-base:latest

# agent 用户（task.toml 的 [agent].user = "agent"）。工具链与 $HVIGOR_USER_HOME 在基础镜像中已对所有用户可用
RUN useradd -m -u 1000 -s /bin/bash agent \
 && mkdir -p /workspace/app && chown agent:agent /workspace/app

COPY --chown=agent:agent app/ /workspace/app/
USER agent
WORKDIR /workspace/app

# 依赖在构建镜像时预装好，agent 运行时访问不了外网包仓库 🔧
RUN ohpm install --all

# 中性化的 base 快照，verify.py 用 tag harbor-base 计算 agent 的 diff
RUN git init -q \
 && git add -A \
 && GIT_AUTHOR_DATE="2026-01-01T00:00:00Z" GIT_COMMITTER_DATE="2026-01-01T00:00:00Z" \
    git -c user.name=harbor -c user.email=harbor@localhost commit -qm "base" \
 && git tag harbor-base
