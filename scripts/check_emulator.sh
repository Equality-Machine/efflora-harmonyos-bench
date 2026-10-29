#!/usr/bin/env bash
# 运行评测前检查模拟器接入：在任务基础镜像的容器里，用与评分阶段相同的方式（宿主机 hdc server + 设备序列号）
# 连接模拟器，并逐项核对基准环境。全部通过时，任务的 verifier 也能正常使用这台模拟器。
#
# 用法：
#   EFFLORA_DEVICE_SN=127.0.0.1:5557 scripts/check_emulator.sh
# 环境变量（与 task.toml 的 [verifier.env] 一致）：
#   EFFLORA_DEVICE_SN    必填，模拟器在宿主机 hdc server 上的序列号（宿主机执行 hdc list targets 查看）
#   EFFLORA_HDC_SERVER   可选，宿主机 hdc server 地址（容器内视角），默认 host.docker.internal:8710
#   EFFLORA_BASE_IMAGE   可选，用于检查的镜像，默认 efflora/harmonyos-base:latest
# 详见 docs/emulator-ui-tests.md。
set -uo pipefail

SN=${EFFLORA_DEVICE_SN:-}
SERVER=${EFFLORA_HDC_SERVER:-host.docker.internal:8710}
IMAGE=${EFFLORA_BASE_IMAGE:-efflora/harmonyos-base:latest}

if [ -z "$SN" ]; then
  echo "未设置 EFFLORA_DEVICE_SN。先在宿主机执行 hdc list targets 查看模拟器序列号，例如：" >&2
  echo "  EFFLORA_DEVICE_SN=127.0.0.1:5555 $0" >&2
  exit 2
fi
if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "找不到镜像 ${IMAGE}，先按 docker/harmonyos-base/README.md 构建基础镜像。" >&2
  exit 2
fi

echo "== 检查模拟器 ${SN}（hdc server: ${SERVER}，镜像: ${IMAGE}）"
docker run --rm -i --platform linux/amd64 -e HDC_SERVER="$SERVER" -e DEVICE_SN="$SN" "$IMAGE" bash -s <<'EOF'
fail=0
ok()  { printf '  [ok]   %s\n' "$*"; }
bad() { printf '  [FAIL] %s\n' "$1"; [ -n "${2:-}" ] && printf '         → %s\n' "$2"; fail=1; }
finish() { [ $fail = 0 ] && echo "== 全部通过" || echo "== 存在未通过项，评分时会记为验证异常"; exit $fail; }

# 1. hdc server 可达
host=${HDC_SERVER%:*}; port=${HDC_SERVER##*:}
ip=$(python3 -c "import socket,sys; print(socket.gethostbyname(sys.argv[1]))" "$host" 2>/dev/null) \
  || { bad "无法解析 $host" "macOS 上请使用 Docker Desktop 或 OrbStack（提供 host.docker.internal）；Linux 上请把 EFFLORA_HDC_SERVER 设为宿主机 IP:8710"; finish; }
targets=$(hdc -s "$ip:$port" list targets 2>&1 | tr -d '\r')
if echo "$targets" | grep -qiE 'connect server failed|fail|error'; then
  bad "连不上 hdc server ${HDC_SERVER}（$ip:${port}）：$(echo "$targets" | head -1)" \
      "在宿主机执行 hdc -s 127.0.0.1:$port list targets 确认 hdc server 在运行；Linux 上 hdc server 需监听容器可访问的地址（hdc -m -s 0.0.0.0:$port）"
  finish
fi
ok "hdc server $HDC_SERVER 可达"

# 2. 设备在线
if ! echo "$targets" | grep -qxF "$DEVICE_SN"; then
  bad "hdc server 上没有设备 ${DEVICE_SN}，当前在线：$(echo "$targets" | tr '\n' ' ')" \
      "模拟器重启后端口可能变化，用宿主机 hdc list targets 的结果更新 EFFLORA_DEVICE_SN"
  finish
fi
h() { hdc -s "$ip:$port" -t "$DEVICE_SN" "$@" 2>&1 | tr -d '\r'; }
[ "$(h shell echo ready)" = "ready" ] && ok "设备 $DEVICE_SN 在线" \
  || { bad "设备 $DEVICE_SN 无响应" "在 DevEco Studio 设备管理器中重启该模拟器"; finish; }

# 3. 基准环境（docs/environment.md）
check_param() {  # $1 = 系统参数, $2 = 期望值, $3 = 修复提示
  local got; got=$(h shell param get "$1" | head -1 | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
  [ "$got" = "$2" ] && ok "$1 = $got" || bad "$1 = '$got'，应为 '$2'" "$3"
}
check_param const.ohos.apiversion 24 "创建模拟器时选择 HarmonyOS 6.1.1(24) 系统镜像"
check_param const.ohos.fullname OpenHarmony-6.1.1.125 "创建模拟器时选择 HarmonyOS 6.1.1(24) 系统镜像"
check_param persist.global.locale zh-Hans-CN "模拟器「设置 > 系统 > 语言和地区」改为简体中文（中国）"
check_param persist.time.timezone Asia/Shanghai "模拟器「设置 > 系统 > 日期和时间」时区改为上海"
h shell uitest dumpLayout -p /data/local/tmp/efflora-display.json >/dev/null
size=$(h shell "head -c 2000 /data/local/tmp/efflora-display.json; rm -f /data/local/tmp/efflora-display.json" \
  | grep -oE '"bounds":"\[0,0\]\[[0-9]+,[0-9]+\]"' | head -1 | sed -E 's/.*\[([0-9]+),([0-9]+)\]"$/\1x\2/')
[ "$size" = "1256x2760" ] && ok "屏幕分辨率 = $size" \
  || bad "屏幕分辨率 = '${size:-读取失败}'，应为 1256x2760" "创建模拟器时选择 Pura 90 Pro 机型；读取失败时先解锁并点亮模拟器屏幕"

# 4. 文件传输（评分时要把 HAP 传到设备）
head -c 1048576 /dev/urandom > /tmp/efflora-probe.bin
want=$(md5sum /tmp/efflora-probe.bin | cut -d' ' -f1)
h file send /tmp/efflora-probe.bin /data/local/tmp/efflora-probe.bin >/dev/null
got=$(h shell "md5sum /data/local/tmp/efflora-probe.bin; rm -f /data/local/tmp/efflora-probe.bin" | cut -d' ' -f1)
[ "$got" = "$want" ] && ok "容器 → 设备文件传输正常" || bad "容器 → 设备文件传输失败" "确认宿主机 hdc server 与 DevEco Studio 版本一致，并重启 hdc server"

# 5. 设备锁（评分期间同一台模拟器上的 trial 依次执行）
age=$(h shell 'if [ -d /data/local/tmp/harbor-bench.lock ]; then echo $(( $(date +%s) - $(cat /data/local/tmp/harbor-bench.lock/ts 2>/dev/null || echo 0) )); fi')
if [ -z "$age" ]; then ok "设备空闲（无评分锁）"
else echo "  [info] 设备正被其他评分占用（锁已持有 ${age} 秒），新的评分会排队；超过 900 秒未刷新的锁会被自动回收"; fi

echo "  [手动] 新建的模拟器需先点任意输入框、同意系统输入法的使用协议，否则弹窗会遮住应用，UI 测试全部失败"
finish
EOF
