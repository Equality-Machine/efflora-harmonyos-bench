# 模拟器 UI 测试

部分任务（`task.toml` 里 `requires_emulator = true`）要在模拟器上跑 UI 测试来打分。模拟器开在你自己的电脑（宿主机）上，评分时容器会通过宿主机的 hdc 连过去。你只需要：准备好一台模拟器，然后告诉 Harbor 用哪一台。

## 1. 准备模拟器

要求：机型 **Pura 90 Pro**，系统 **HarmonyOS 6.1.1(24)**。

**macOS**：用 DevEco Studio 的设备管理器创建并启动即可。

**Linux**：需要 Ubuntu 18.04 以上、x86_64、支持 KVM，用 Command Line Tools **26.0.0 以上**自带的 Emulator（[华为文档](https://developer.huawei.com/consumer/cn/doc/doccenter-deveco-studio/ide-commandline-emulator)）：

```bash
# 装依赖；当前用户要能读写 /dev/kvm 和 /dev/dri（加入 kvm、video、render 组）
sudo apt install -y libatomic1 libpulse0 libegl1 libgbm1 libgl1 libgl1-mesa-dri libpng16-16 libfontconfig1 \
  libfreetype6 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 libxcb-randr0 libxcb-render-util0 libxcb-shape0 \
  libxcb-xinerama0 libxcb-xkb1 libsm6 libice6 libxkbcommon-x11-0 libxkbcommon0 libglib2.0-0
export PATH=<command-line-tools>/emulator:<command-line-tools>/sdk/default/openharmony/toolchains:$PATH

# 先让 hdc 对外监听，不然容器连不上
hdc kill; nohup hdc -m -s 0.0.0.0:8710 >/dev/null 2>&1 &

# 下载镜像、创建并启动模拟器（名字里不能有 -）
Emulator -license accept
Emulator -install -deviceType phone -osVersion "HarmonyOS 6.1.1(24)"
Emulator -create Pura90Pro -deviceType Phone -osVersion "HarmonyOS 6.1.1(24)" -screenProfile "Pura 90 Pro" \
  -instancePath ~/hemu/instances -imageRoot ~/hemu/sdk
mkdir -p -m 700 /tmp/hemu-xdg
QT_QPA_PLATFORM=offscreen XDG_RUNTIME_DIR=/tmp/hemu-xdg nohup Emulator -start Pura90Pro \
  -instancePath ~/hemu/instances -imageRoot ~/hemu/sdk -noWindow >/dev/null 2>&1 &
```

8710 端口对局域网开放了，记得用防火墙限制。

## 2. 第一次开机后设置一下

每台模拟器只需要做一次：

1. 语言改成**简体中文（中国）**：设置 > 系统 > 语言和地区。如果是英文界面，先 Add language 加上简体中文，再把地区改成中国。
2. 时区是上海（默认就是）。
3. 随便点一个输入框，**同意小艺输入法的协议**。不同意的话弹窗会挡住应用，所有测试都会失败。

Linux 没有窗口，可以用这几条命令操作：

```bash
hdc shell power-shell timeout -o 2147483647                   # 不让屏幕自动熄灭
hdc shell uitest uiInput swipe 628 2300 628 500 1500           # 上滑解锁
hdc shell uitest screenCap -p /data/local/tmp/s.png && hdc file recv /data/local/tmp/s.png .   # 截图看看
hdc shell uitest uiInput click <x> <y>                        # 点一下
```

## 3. 检查一下，然后开跑

```bash
hdc list targets                                  # 看模拟器编号，比如 127.0.0.1:5555
export EFFLORA_DEVICE_SN=127.0.0.1:5555           # 用哪台模拟器（必填）
export EFFLORA_HDC_SERVER=<宿主机 IP>:8710         # 只有 Linux 需要
scripts/check_emulator.sh                         # 检查能不能连上、模拟器对不对，全过了再跑
harbor run -y -p tasks -a <agent> -m <provider/model>
```

- 模拟器重启后编号可能会变，重新看一下 `hdc list targets`。
- 有多台模拟器想同时跑：每台开一个 `harbor run`，各自设置 `EFFLORA_DEVICE_SN`。
- 模拟器连不上、配置不对时，这次运行会记为异常，不会记 0 分。

## 常见问题

| 遇到的情况 | 怎么办 |
| --- | --- |
| 提示缺少 `EFFLORA_DEVICE_SN` | 设置模拟器编号 |
| 检查时说找不到这台设备 | 模拟器没开，或者编号变了，重新 `hdc list targets` |
| Linux 上检查时连不上 hdc | 确认 hdc 是用 `0.0.0.0:8710` 启动的，`EFFLORA_HDC_SERVER` 填的是宿主机 IP |
| 检查时说语言或时区不对 | 按第 2 步改 |
| 测试全部失败，画面上有输入法弹窗 | 第 2 步的输入法协议没同意 |
| 构建时去网上拉 `efflora/harmonyos-base` 失败 | 运行时加上 `BUILDX_BUILDER=default` |
