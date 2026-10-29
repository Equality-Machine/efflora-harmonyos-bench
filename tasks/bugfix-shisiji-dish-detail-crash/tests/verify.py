#!/usr/bin/env python3
"""HarmonyOS Harbor 任务的评分器（verifier）。

流程：还原受保护文件 → 注入隐藏的 ohosTest → 构建 app HAP 和 test HAP
      → 申请设备 → 安装 → 逐个 F-point 执行 `aa test` → 写 reward。

用法：
  python3 -I verify.py run      --app /workspace/app --tests-dir /tests --logs-dir /logs/verifier [--no-device]
  python3 -I verify.py baseline --app <base 工程> --tests-dir <任务的 tests 目录>   # 制作任务时生成 baseline/

退出码：0 = 已正常打分（reward 可能是 0 或 1）；2 = 基础设施错误（不写 reward，这次 trial 作废重跑）。
只依赖 Python 标准库。
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import urllib.request
from contextlib import contextmanager
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Iterator

EXIT_OK = 0
EXIT_INFRA = 2
BASE_TAG = "harbor-base"  # environment/Dockerfile 中给 base 快照打的 tag


class InfraError(Exception):
    """环境问题（设备掉线、test HAP 构建失败、测试框架没启动等），不是 agent 的责任。"""


# ---------------------------------------------------------------- config


@dataclass
class FPoint:
    id: str
    # aa test 的 -s class 参数，例如 "NF_Feature#FP1_entry"。
    # 也可以是多个阶段的列表，例如 ["NF_Feature#FP1_set", "NF_Feature#FP1_check_after_restart"]：
    # 各阶段依次执行，每个阶段开始前都会 aa force-stop（App 冷启动），全部阶段通过才算该 F-point 通过。
    # 测试和 App 同进程，用例内无法冷启动 App，持久化类检查必须这样拆分；状态只能经由 App 自己的持久化在阶段间传递。
    test: str | list[str]
    desc: str = ""

    @property
    def phases(self) -> list[str]:
        return [self.test] if isinstance(self.test, str) else list(self.test)


@dataclass
class Config:
    bundle_name: str
    fpoints: list[FPoint]
    module: str = "entry"       # hvigor 的模块名（module.json5 的 name）
    module_dir: str = ""        # 模块目录（相对工程根目录），默认与 module 相同；多模块工程例如 "products/default"
    product: str = "default"
    test_module_name: str = "entry_test"
    test_runner: str = "/ets/testrunner/OpenHarmonyTestRunner"  # 系统内置，工程里不需要自带 testrunner
    test_timeout_ms: int = 30000
    build_timeout_sec: int = 1200
    install_timeout_sec: int = 300
    fpoint_timeout_sec: int = 300
    # 设备锁：最多等待多久；持有超过多久视为持有者已死（应大于单次评分占用设备的最长时间）
    device_lock_wait_sec: int = 1500
    device_lock_stale_sec: int = 900
    # 隐藏测试注入：tests/ 下的源目录 → /workspace/app 下的目标目录
    inject: dict[str, str] = field(default_factory=lambda: {"ohosTest": "entry/src/ohosTest"})
    # 申请到设备后、安装前执行的 hdc 子命令，例如 [["shell", "param", "set", "persist.global.locale", "zh-Hans-CN"]]
    device_prep: list[list[str]] = field(default_factory=list)
    # 设备必须满足的系统参数（hdc shell param get <key> 的值），不一致判为基础设施错误，
    # 防止在不同版本的模拟器上跑出不可比的分数。例如 {"const.ohos.apiversion": "24"}
    device_expect: dict[str, str] = field(default_factory=dict)
    # 安装前先卸载设备上 bundle 名以这些前缀开头的其他应用，避免上一个任务的 App 影响本任务（任务间隔离）
    cleanup_bundle_prefixes: list[str] = field(default_factory=list)
    # 评分容器里工具链必须满足的版本，目前支持 {"clt": "26.0.0.851"}（读取 $HARMONY_HOME/version.txt）
    toolchain_expect: dict[str, str] = field(default_factory=dict)

    @staticmethod
    def load(path: Path) -> "Config":
        raw = json.loads(path.read_text(encoding="utf-8"))
        raw["fpoints"] = [FPoint(**fp) for fp in raw["fpoints"]]
        cfg = Config(**raw)
        if not cfg.fpoints:
            raise ValueError("verify_config.json: fpoints must not be empty")
        if any(not fp.phases or not all(isinstance(t, str) and t for t in fp.phases) for fp in cfg.fpoints):
            raise ValueError("verify_config.json: fpoint test must be a non-empty string or list of strings")
        cfg.module_dir = cfg.module_dir or cfg.module
        ids = [fp.id for fp in cfg.fpoints]
        if len(ids) != len(set(ids)):
            raise ValueError("verify_config.json: duplicate fpoint ids")
        return cfg


# ---------------------------------------------------------------- command runner


@dataclass
class CmdResult:
    argv: list[str]
    code: int
    out: str
    elapsed: float

    @property
    def ok(self) -> bool:
        return self.code == 0


class Runner:
    def __init__(self, log_path: Path):
        self.log_path = log_path

    def run(self, argv: list[str], cwd: Path | None = None, timeout: float = 600) -> CmdResult:
        start = time.monotonic()
        try:
            p = subprocess.run(argv, cwd=cwd, capture_output=True, text=True, timeout=timeout)
            code, out = p.returncode, (p.stdout or "") + (p.stderr or "")
        except subprocess.TimeoutExpired as e:
            code, out = 124, f"{e.stdout or ''}{e.stderr or ''}\n<timeout after {timeout}s>"
        except FileNotFoundError as e:
            code, out = 127, str(e)
        res = CmdResult(argv, code, out, time.monotonic() - start)
        with self.log_path.open("a", encoding="utf-8") as f:
            f.write(f"\n$ {' '.join(argv)}  (cwd={cwd}, exit={code}, {res.elapsed:.1f}s)\n{out}\n")
        return res


# ---------------------------------------------------------------- file snapshot / protection


def tree_digest(path: Path) -> str | None:
    """文件或目录的内容哈希；路径不存在时返回 None。"""
    if not path.exists():
        return None
    h = hashlib.sha256()
    files = [path] if path.is_file() else sorted(p for p in path.rglob("*") if p.is_file())
    for f in files:
        h.update(str(f.relative_to(path) if path.is_dir() else f.name).encode())
        h.update(f.read_bytes())
    return h.hexdigest()


def read_protected(tests_dir: Path) -> list[str]:
    p = tests_dir / "protected_files.txt"
    if not p.exists():
        return []
    lines = (ln.strip() for ln in p.read_text(encoding="utf-8").splitlines())
    return [ln for ln in lines if ln and not ln.startswith("#")]


def _replace(src: Path | None, dst: Path) -> None:
    if dst.is_dir():
        shutil.rmtree(dst)
    elif dst.exists():
        dst.unlink()
    if src is None:
        return
    dst.parent.mkdir(parents=True, exist_ok=True)
    if src.is_dir():
        shutil.copytree(src, dst)
    else:
        shutil.copy2(src, dst)


def restore_protected(app: Path, tests_dir: Path, rels: list[str]) -> list[str]:
    """把受保护路径还原成 baseline 中的版本，返回被 agent 改过的路径。
    baseline 中不存在的路径表示"base 里本来没有这个文件"，agent 新建的会被删除。"""
    touched = []
    for rel in rels:
        base = tests_dir / "baseline" / rel
        cur = app / rel
        if tree_digest(cur) != tree_digest(base):
            touched.append(rel)
        _replace(base if base.exists() else None, cur)
    return touched


def _ignore_build_outputs(src: str, names: list[str]) -> set[str]:
    """复制工程时跳过构建产物：只跳过工程根目录和模块根目录下的 build/、.hvigor/。"""
    is_project_or_module = any(n in names for n in ("hvigorfile.ts", "build-profile.json5"))
    return {n for n in names if is_project_or_module and n in ("build", ".hvigor")}


def make_workdir(app: Path) -> Path:
    """在 /workspace/app 的副本上评分，不修改 agent 的原始产物，这样多次评分或重新评分的结果一致。"""
    work = Path(tempfile.mkdtemp(prefix="verify-")) / "app"
    shutil.copytree(app, work, symlinks=True, ignore=_ignore_build_outputs)
    return work


def inject_tests(app: Path, tests_dir: Path, inject: dict[str, str]) -> None:
    for src_rel, dst_rel in inject.items():
        src = tests_dir / src_rel
        if not src.exists():
            raise InfraError(f"hidden test source missing: {src}")
        _replace(src, app / dst_rel)


def diff_stat(runner: Runner, app: Path, logs: Path) -> int:
    """返回 1 = 相对 base 快照有改动，0 = 没有改动，-1 = 无法判断（tag 丢失或不是 git 仓库）。"""
    git = ["git", "-c", "safe.directory=*", "-C", str(app)]
    if not runner.run(git + ["rev-parse", "--verify", "-q", BASE_TAG]).ok:
        return -1
    runner.run(git + ["add", "-A", "--intent-to-add"])  # 让未跟踪的新文件也出现在 diff 里
    d = runner.run(git + ["diff", BASE_TAG])
    (logs / "agent.diff").write_text(d.out, encoding="utf-8")
    return 1 if d.out.strip() else 0


# ---------------------------------------------------------------- build


def find_hap(app: Path, module: str, target: str) -> Path | None:
    """在 <module>/build/<product>/outputs/<target>/ 下查找 HAP，优先选择已签名的。
    模拟器可以直接安装 *-unsigned.hap；真机必须使用已签名的包。"""
    cands = sorted((app / module / "build").glob(f"*/outputs/{target}/*.hap"))
    signed = [c for c in cands if "unsigned" not in c.name]
    return (signed or cands or [None])[0]


_CLT_VERSION = re.compile(r"^#\s*Version:\s*(\S+)", re.M)


def check_toolchain(expect: dict[str, str]) -> dict[str, str]:
    """读取 Command Line Tools 版本（写入 details 方便追溯），并校验 toolchain_expect。"""
    info = {}
    home = os.environ.get("HARMONY_HOME")
    vfile = Path(home) / "version.txt" if home else None
    if vfile and vfile.exists():
        m = _CLT_VERSION.search(vfile.read_text(encoding="utf-8", errors="replace"))
        info["clt"] = m.group(1) if m else ""
    for key, want in expect.items():
        if info.get(key) != want:
            raise InfraError(f"toolchain mismatch: {key}={info.get(key)!r} (expected {want!r})")
    return info


def hvigor_build(runner: Runner, app: Path, cfg: Config, target: str) -> CmdResult:
    argv = ["hvigorw", "assembleHap", "--mode", "module",
            "-p", f"module={cfg.module}@{target}", "-p", f"product={cfg.product}", "--no-daemon"]
    res = runner.run(argv, cwd=app, timeout=cfg.build_timeout_sec)
    if res.code == 127:  # 工具链缺失是镜像问题，不能记成 agent 的构建失败
        raise InfraError(f"hvigorw not runnable: {res.out.strip()[:200]}")
    if res.code == 124:  # 构建卡死（同机多路并发构建时偶发），重跑即可，不能记成 agent 的构建失败
        raise InfraError(f"hvigorw timed out after {cfg.build_timeout_sec}s ({target})")
    return res


# ---------------------------------------------------------------- devices


@dataclass
class Device:
    server: str  # 远程 hdc server 的 host:port
    sn: str      # 设备序列号或 connect key


class DeviceProvider:
    @contextmanager
    def lease(self) -> Iterator[Device]:
        raise NotImplementedError


class StaticDeviceProvider(DeviceProvider):
    """P0 阶段使用：直接连接 HDC_SERVER + DEVICE_SN 指定的固定设备，不做并发控制。"""

    def __init__(self, server: str, sn: str):
        self.server, self.sn = server, sn

    @contextmanager
    def lease(self) -> Iterator[Device]:
        yield Device(self.server, self.sn)


class BrokerDeviceProvider(DeviceProvider):
    """设备池 broker 客户端。约定的接口（由 broker 实现）：
      POST   {url}/leases  {"api": <API 级别>, "wait_sec": N}  → {"lease_id", "server", "sn"}
      DELETE {url}/leases/{lease_id}
    broker 负责：加锁分配设备、归还后恢复干净快照。"""

    def __init__(self, url: str, token: str, api: int, wait_sec: int = 600):
        self.url, self.token, self.api, self.wait_sec = url.rstrip("/"), token, api, wait_sec

    def _req(self, method: str, path: str, body: dict | None = None) -> dict:
        req = urllib.request.Request(
            self.url + path, method=method,
            data=json.dumps(body).encode() if body is not None else None,
            headers={"Authorization": f"Bearer {self.token}", "Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=self.wait_sec + 30) as r:
            payload = r.read()
            return json.loads(payload) if payload else {}

    @contextmanager
    def lease(self) -> Iterator[Device]:
        try:
            got = self._req("POST", "/leases", {"api": self.api, "wait_sec": self.wait_sec})
        except Exception as e:  # noqa: BLE001 - 申请设备失败一律视为基础设施错误
            raise InfraError(f"device lease failed: {e}") from e
        try:
            yield Device(got["server"], got["sn"])
        finally:
            try:
                self._req("DELETE", f"/leases/{got['lease_id']}")
            except Exception:  # noqa: BLE001 - 归还失败由 broker 的租约超时兜底
                pass


def resolve_server(server: str) -> str:
    """hdc -s 需要 IP:port；把主机名（例如容器里的 host.docker.internal）解析成 IPv4。"""
    host, _, port = server.rpartition(":")
    try:
        return f"{socket.gethostbyname(host)}:{port}"
    except OSError as e:
        raise InfraError(f"cannot resolve hdc server host {host!r}: {e}") from e


def provider_from_env(cfg: Config) -> DeviceProvider:
    if os.environ.get("DEVICE_BROKER"):
        # 申请的设备 API 级别取自 device_expect，和设备校验保持一致
        api = cfg.device_expect.get("const.ohos.apiversion")
        if not api:
            raise InfraError("DEVICE_BROKER requires device_expect[\"const.ohos.apiversion\"]")
        return BrokerDeviceProvider(os.environ["DEVICE_BROKER"], os.environ.get("DEVICE_BROKER_TOKEN", ""), int(api))
    if os.environ.get("HDC_SERVER") and os.environ.get("DEVICE_SN"):
        return StaticDeviceProvider(resolve_server(os.environ["HDC_SERVER"]), os.environ["DEVICE_SN"])
    raise InfraError("no device configured: set DEVICE_BROKER or HDC_SERVER + DEVICE_SN")


class Hdc:
    def __init__(self, runner: Runner, dev: Device):
        self.runner, self.dev = runner, dev

    def __call__(self, *args: str, timeout: float = 120) -> CmdResult:
        return self._checked(["hdc", "-s", self.dev.server, "-t", self.dev.sn, *args], timeout)

    def online(self) -> bool:
        r = self._checked(["hdc", "-s", self.dev.server, "list", "targets"], 30)
        return r.ok and self.dev.sn in r.out

    def _checked(self, argv: list[str], timeout: float) -> CmdResult:
        r = self.runner.run(argv, timeout=timeout)
        if r.code == 127:
            raise InfraError(f"hdc not runnable: {r.out.strip()[:200]}")
        return r


INSTALL_OK = re.compile(r"install bundle successfully", re.I)

DEVICE_LOCK = "/data/local/tmp/harbor-bench.lock"


@contextmanager
def device_lock(hdc: Hdc, wait_sec: int, stale_sec: int) -> Iterator[None]:
    """设备上的互斥锁：多个 verifier 容器共用同一台设备时，串行执行"卸载 → 安装 → UI 测试"。
    锁放在设备上（mkdir 是原子操作），因此跨容器、跨宿主都有效；
    持有者异常退出时，超过 stale_sec 的锁会被强制回收。"""
    deadline = time.monotonic() + wait_sec
    while True:
        r = hdc("shell", f"mkdir {DEVICE_LOCK} 2>/dev/null && date +%s > {DEVICE_LOCK}/ts && echo LOCK_ACQUIRED")
        if "LOCK_ACQUIRED" in r.out:
            break
        if not hdc.online():
            raise InfraError("device offline while waiting for device lock")
        ts = re.findall(r"\d+", hdc("shell", f"cat {DEVICE_LOCK}/ts 2>/dev/null; echo; date +%s").out)
        if len(ts) == 2 and int(ts[1]) - int(ts[0]) > stale_sec:
            hdc("shell", "rm", "-rf", DEVICE_LOCK)  # 持有者已经死掉，回收
            continue
        if time.monotonic() > deadline:
            raise InfraError(f"timed out after {wait_sec}s waiting for device lock")
        time.sleep(5)
    try:
        yield
    finally:
        hdc("shell", "rm", "-rf", DEVICE_LOCK)


# ---------------------------------------------------------------- aa test parsing

_RESULT = re.compile(
    r"OHOS_REPORT_RESULT:\s*stream=Tests run:\s*(\d+),\s*Failure:\s*(\d+),\s*Error:\s*(\d+),"
    r"\s*Pass:\s*(\d+),\s*Ignore:\s*(\d+)")
_CODE = re.compile(r"OHOS_REPORT_CODE:\s*(-?\d+)")
# 测试代码和被测 App 跑在同一个进程里（ohosTest 是同一个 bundle 下的 entry_test 模块），
# App 崩溃时测试进程会一起退出，aa test 不会输出 OHOS_REPORT_RESULT，只有这一行。
_APP_DIED = re.compile(r"TestFinished-ResultMsg:\s*App died", re.I)


@dataclass
class AaTestResult:
    parsed: bool
    run: int = 0
    failure: int = 0
    error: int = 0
    passed: int = 0
    ignore: int = 0
    code: int | None = None
    app_died: bool = False

    @property
    def ok(self) -> bool:
        return (self.parsed and self.run >= 1 and self.passed == self.run
                and self.failure == 0 and self.error == 0)


def parse_aa_test(out: str) -> AaTestResult:
    m = None
    for m in _RESULT.finditer(out):  # 输出里可能有多段结果，取最后一段汇总
        pass
    code = _CODE.findall(out)
    died = bool(_APP_DIED.search(out))
    if not m:
        return AaTestResult(parsed=False, code=int(code[-1]) if code else None, app_died=died)
    run, fail, err, ok, ign = map(int, m.groups())
    return AaTestResult(True, run, fail, err, ok, ign, int(code[-1]) if code else None, died)


# ---------------------------------------------------------------- main flow


@dataclass
class Details:
    reward: int = 0
    build_ok: int = 0
    install_ok: int = 0
    fpoint_pass_rate: float = 0.0
    fpoints: dict[str, int] = field(default_factory=dict)
    nonempty_diff: int = -1
    protected_files_touched: list[str] = field(default_factory=list)
    new_faultlogs: list[str] = field(default_factory=list)
    crashed_fpoints: list[str] = field(default_factory=list)
    device: dict[str, str] = field(default_factory=dict)
    cleaned_bundles: list[str] = field(default_factory=list)
    toolchain: dict[str, str] = field(default_factory=dict)
    device_skipped: int = 0
    infra_error: int = 0
    infra_reason: str = ""
    durations: dict[str, float] = field(default_factory=dict)


DEVICE_INFO_KEYS = ("const.ohos.apiversion", "const.ohos.fullname", "const.product.model")


def check_device(hdc: Hdc, expect: dict[str, str]) -> dict[str, str]:
    """读取设备版本信息（写入 details 方便追溯），并校验 device_expect。"""
    info = {}
    for key in dict.fromkeys([*DEVICE_INFO_KEYS, *expect]):
        r = hdc("shell", "param", "get", key)
        info[key] = r.out.strip() if r.ok else ""
    bad = {k: (info[k], v) for k, v in expect.items() if info[k] != v}
    if bad:
        raise InfraError("device mismatch: " + ", ".join(f"{k}={got!r} (expected {want!r})"
                                                         for k, (got, want) in bad.items()))
    return info


def list_faultlogs(hdc: Hdc) -> set[str]:
    r = hdc("shell", "ls", "/data/log/faultlog/faultlogger/")  # 崩溃文件名形如 jscrash-<bundle>-<uid>-<ts>.log
    return set(r.out.split()) if r.ok else set()


def run_phase(hdc: Hdc, cfg: Config, fp: FPoint, test: str) -> AaTestResult:
    """冷启动后执行一个 aa test 阶段。断言失败不重试；只有测试框架没有输出结果时重试一次，仍然没有就判为基础设施错误。"""
    for attempt in (1, 2):
        hdc("shell", "aa", "force-stop", cfg.bundle_name)
        r = hdc("shell", "aa", "test", "-b", cfg.bundle_name, "-m", cfg.test_module_name,
                "-s", "unittest", cfg.test_runner, "-s", "class", test,
                "-s", "timeout", str(cfg.test_timeout_ms), timeout=cfg.fpoint_timeout_sec)
        res = parse_aa_test(r.out)
        if res.app_died or (res.parsed and res.run >= 1):
            return res  # App 崩溃是 agent 的问题，不重试（崩溃会确定性复现）
        if not hdc.online():
            raise InfraError(f"device went offline during {fp.id}")
        if attempt == 2:
            # Tests run 为 0 通常说明 test 名写错了（测试配置问题），同样视为基础设施错误，需要人工检查
            raise InfraError(f"aa test produced no result for {fp.id} (test={test})")
    raise AssertionError("unreachable")


def run_fpoint(hdc: Hdc, cfg: Config, fp: FPoint) -> tuple[bool, AaTestResult]:
    """依次执行 F-point 的各个阶段，任一阶段失败即停止并判该 F-point 失败。"""
    res = AaTestResult(parsed=False)
    for test in fp.phases:
        res = run_phase(hdc, cfg, fp, test)
        if not res.ok:
            return False, res
    return True, res


def cleanup_bundles(hdc: Hdc, prefixes: list[str], keep: str) -> list[str]:
    """卸载设备上匹配前缀的其他 bundle，返回被卸载的列表。"""
    if not prefixes:
        return []
    r = hdc("shell", "bm", "dump", "-a")
    names = sorted({n for n in re.findall(r"^\s*([\w.]+)\s*$", r.out, re.M)
                    if n != keep and any(n.startswith(p) for p in prefixes)})
    for n in names:
        hdc("uninstall", n)
    return names


def evaluate(app: Path, tests_dir: Path, logs: Path, cfg: Config, use_device: bool) -> Details:
    if not (app / "build-profile.json5").exists():
        raise InfraError(f"{app} is not a HarmonyOS project (artifacts not transferred?)")
    work = make_workdir(app)
    try:
        return _evaluate_in(work, tests_dir, logs, cfg, use_device)
    finally:
        if not os.environ.get("VERIFY_KEEP_WORKDIR"):
            shutil.rmtree(work.parent, ignore_errors=True)


def _evaluate_in(app: Path, tests_dir: Path, logs: Path, cfg: Config, use_device: bool) -> Details:
    """在工作副本 app 上评分：还原 → 注入 → 构建 → 上设备。"""
    runner = Runner(logs / "verify.log")
    d = Details()
    t0 = time.monotonic()

    d.toolchain = check_toolchain(cfg.toolchain_expect)
    d.nonempty_diff = diff_stat(runner, app, logs)
    d.protected_files_touched = restore_protected(app, tests_dir, read_protected(tests_dir))
    inject_tests(app, tests_dir, cfg.inject)

    t = time.monotonic()
    build = hvigor_build(runner, app, cfg, cfg.product)
    app_hap = find_hap(app, cfg.module_dir, cfg.product) if build.ok else None
    d.build_ok = int(app_hap is not None)
    d.durations["build_app"] = round(time.monotonic() - t, 1)
    d.fpoints = {fp.id: 0 for fp in cfg.fpoints}
    if not d.build_ok:
        return d

    t = time.monotonic()
    tbuild = hvigor_build(runner, app, cfg, "ohosTest")
    test_hap = find_hap(app, cfg.module_dir, "ohosTest") if tbuild.ok else None
    d.durations["build_test"] = round(time.monotonic() - t, 1)
    if test_hap is None:
        # 测试只依赖 TestKit，正常情况下不会构建失败；如果反复出现，需要人工检查 agent 是否破坏了构建配置
        raise InfraError("ohosTest HAP build failed")

    if not use_device:
        d.device_skipped = 1
        return d

    with provider_from_env(cfg).lease() as dev:
        hdc = Hdc(runner, dev)
        if not hdc.online():
            raise InfraError(f"device {dev.sn} not online at {dev.server}")
        d.device = check_device(hdc, cfg.device_expect)
        with device_lock(hdc, cfg.device_lock_wait_sec, cfg.device_lock_stale_sec):
            d.cleaned_bundles = cleanup_bundles(hdc, cfg.cleanup_bundle_prefixes, cfg.bundle_name)
            hdc("uninstall", cfg.bundle_name)  # test HAP 是同一个 bundle 里的 entry_test 模块，一起被卸载
            for cmd in cfg.device_prep:
                if not hdc(*cmd).ok:
                    raise InfraError(f"device prep failed: {cmd}")

            r = hdc("install", "-r", str(app_hap), timeout=cfg.install_timeout_sec)
            if not INSTALL_OK.search(r.out):
                if not hdc.online():
                    raise InfraError("device offline during app install")
                return d  # 设备在线但安装失败：通常是 agent 的配置问题（权限、module.json5），按 0 分计
            d.install_ok = 1
            r = hdc("install", "-r", str(test_hap), timeout=cfg.install_timeout_sec)
            if not INSTALL_OK.search(r.out):
                raise InfraError("test HAP install failed")

            before = list_faultlogs(hdc)
            t = time.monotonic()
            for fp in cfg.fpoints:
                ok, res = run_fpoint(hdc, cfg, fp)
                d.fpoints[fp.id] = int(ok)
                if res.app_died:
                    d.crashed_fpoints.append(fp.id)
            d.durations["fpoints"] = round(time.monotonic() - t, 1)
            d.new_faultlogs = sorted(f for f in list_faultlogs(hdc) - before if cfg.bundle_name in f)

    d.fpoint_pass_rate = round(sum(d.fpoints.values()) / len(d.fpoints), 4)
    d.reward = int(d.build_ok and d.install_ok and all(d.fpoints.values()))
    d.durations["total"] = round(time.monotonic() - t0, 1)
    return d


def write_results(logs: Path, d: Details) -> None:
    (logs / "details.json").write_text(json.dumps(asdict(d), ensure_ascii=False, indent=2), encoding="utf-8")
    if d.infra_error:
        return  # 不写 reward 文件：让 Harbor 把这次 trial 记为异常，而不是 0 分
    (logs / "reward.json").write_text(json.dumps({"reward": d.reward}), encoding="utf-8")
    (logs / "reward.txt").write_text(f"{d.reward}\n", encoding="utf-8")


def cmd_run(args: argparse.Namespace) -> int:
    logs = Path(args.logs_dir)
    logs.mkdir(parents=True, exist_ok=True)
    for stale in ("reward.json", "reward.txt"):  # 不信任评分前已存在的 reward 文件
        (logs / stale).unlink(missing_ok=True)
    tests_dir = Path(args.tests_dir)
    try:
        cfg = Config.load(tests_dir / "verify_config.json")
        d = evaluate(Path(args.app), tests_dir, logs, cfg, use_device=not args.no_device)
    except InfraError as e:
        d = Details(infra_error=1, infra_reason=str(e))
    write_results(logs, d)
    print(json.dumps(asdict(d), ensure_ascii=False, indent=2))
    return EXIT_INFRA if d.infra_error else EXIT_OK


def cmd_baseline(args: argparse.Namespace) -> int:
    """制作任务时使用：从 base 工程中拷贝受保护路径到 tests/baseline/。"""
    app, tests_dir = Path(args.app), Path(args.tests_dir)
    out = tests_dir / "baseline"
    if out.exists():
        shutil.rmtree(out)
    for rel in read_protected(tests_dir):
        src = app / rel
        if src.exists():
            _replace(src, out / rel)
            print(f"baseline: {rel}")
        else:
            print(f"baseline: {rel} (absent in base; agent-created copies will be removed)")
    return EXIT_OK


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    r = sub.add_parser("run")
    r.add_argument("--app", default="/workspace/app")
    r.add_argument("--tests-dir", default="/tests")
    r.add_argument("--logs-dir", default="/logs/verifier")
    r.add_argument("--no-device", action="store_true", help="只构建、不上设备（P0 调试用；不会给出有效的 reward）")
    r.set_defaults(fn=cmd_run)
    b = sub.add_parser("baseline")
    b.add_argument("--app", required=True)
    b.add_argument("--tests-dir", required=True)
    b.set_defaults(fn=cmd_baseline)
    args = ap.parse_args(argv)
    return args.fn(args)


if __name__ == "__main__":
    sys.exit(main())
