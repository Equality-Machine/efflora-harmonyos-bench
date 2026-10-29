#!/usr/bin/env python3
"""校验一份待上传到 HuggingFace 的评测提交（Harbor 原始 job 目录 + metadata.yaml）。

提交目录结构：
    <agent>__<model>/
    ├── metadata.yaml
    └── <job-dir>/            # harbor run 原样输出，可有多个
        ├── config.json
        ├── result.json
        └── <task>__<id>/     # 每次 trial 一个目录
            ├── result.json
            ├── agent/
            └── verifier/

用法：
    python3 scripts/validate_submission.py <submission-dir> [--tasks-root tasks] [--min-trials 3]
"""
import argparse
import json
import sys
from collections import Counter
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
REQUIRED_METADATA = [
    "agent_url",
    "agent_display_name",
    "agent_org_display_name",
    "benchmark_version",
    "benchmark_commit",
    "harbor_version",
    "models",
]
HARBOR_VERSION = "0.24.0"
TASK_ORG = "efflora/"
REQUIRED_MODEL_FIELDS = ["model_name", "model_provider", "model_display_name", "model_org_display_name"]
# 这些配置项必须保持默认值，否则结果不可比
MUST_BE_NULL = {
    "agent": ["override_timeout_sec", "override_setup_timeout_sec", "max_timeout_sec"],
    "environment": ["override_cpus", "override_memory_mb", "override_storage_mb", "override_gpus"],
    "verifier": ["override_timeout_sec", "max_timeout_sec"],
}
MULTIPLIERS = [
    "agent_timeout_multiplier",
    "verifier_timeout_multiplier",
    "agent_setup_timeout_multiplier",
    "environment_build_timeout_multiplier",
]
# HuggingFace 拒收未走 LFS 的 >10MB 文件
HF_LFS_SUFFIXES = {".hap", ".app", ".har", ".hsp", ".log", ".zip", ".gz", ".tgz", ".cast", ".png", ".jpg"}
HF_MAX_PLAIN_BYTES = 10 * 1024 * 1024


def check_metadata(sub: Path, errors: list[str]) -> None:
    path = sub / "metadata.yaml"
    if not path.is_file():
        errors.append("missing metadata.yaml")
        return
    meta = yaml.safe_load(path.read_text()) or {}
    for key in REQUIRED_METADATA:
        if not meta.get(key):
            errors.append(f"metadata.yaml: '{key}' is required")
    if meta.get("harbor_version") and str(meta["harbor_version"]) != HARBOR_VERSION:
        errors.append(f"metadata.yaml: harbor_version must be {HARBOR_VERSION!r}, got {meta['harbor_version']!r}")
    for i, model in enumerate(meta.get("models") or []):
        for key in REQUIRED_MODEL_FIELDS:
            if not model.get(key):
                errors.append(f"metadata.yaml: models[{i}].{key} is required")


def check_job_config(job: Path, config: dict, errors: list[str]) -> None:
    if config.get("timeout_multiplier") != 1.0:
        errors.append(f"{job.name}: timeout_multiplier must be 1.0")
    for key in MULTIPLIERS:
        if config.get(key) not in (None, 1.0):
            errors.append(f"{job.name}: {key} must not be overridden")
    for agent in config.get("agents", []):
        for key in MUST_BE_NULL["agent"]:
            if agent.get(key) is not None:
                errors.append(f"{job.name}: agents[].{key} must not be overridden")
    for section in ("environment", "verifier"):
        for key in MUST_BE_NULL[section]:
            if (config.get(section) or {}).get(key) is not None:
                errors.append(f"{job.name}: {section}.{key} must not be overridden")
    if (config.get("verifier") or {}).get("disable"):
        errors.append(f"{job.name}: verifier must not be disabled")


def check_trial(trial: Path, errors: list[str]) -> str | None:
    result_path = trial / "result.json"
    if not result_path.is_file():
        errors.append(f"{trial.parent.name}/{trial.name}: missing result.json")
        return None
    result = json.loads(result_path.read_text())
    if not (trial / "agent").is_dir():
        errors.append(f"{trial.parent.name}/{trial.name}: missing agent/ (trajectory and logs are required)")
    if result.get("exception_info") is None and not (trial / "verifier").is_dir():
        errors.append(f"{trial.parent.name}/{trial.name}: missing verifier/")
    # Harbor 以 task.toml 的 [task].name（efflora/<task-id>）作为 task_name，去掉前缀后与目录名比对
    task_name = result.get("task_name")
    return task_name.removeprefix(TASK_ORG) if task_name else None


def check_file_sizes(sub: Path, warnings: list[str]) -> None:
    for f in sub.rglob("*"):
        if f.is_file() and f.stat().st_size > HF_MAX_PLAIN_BYTES and f.suffix not in HF_LFS_SUFFIXES:
            warnings.append(f"{f.relative_to(sub)} is >10MB and not a type the HF dataset stores via LFS; trim it")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("submission", type=Path)
    parser.add_argument("--tasks-root", type=Path, default=ROOT / "tasks")
    parser.add_argument("--min-trials", type=int, default=3)
    args = parser.parse_args()

    sub = args.submission.resolve()
    errors: list[str] = []
    warnings: list[str] = []

    if "__" not in sub.name:
        errors.append(f"submission directory must be named '<agent>__<model>', got '{sub.name}'")
    check_metadata(sub, errors)

    trial_counts: Counter[str] = Counter()
    jobs = [p for p in sub.iterdir() if p.is_dir() and (p / "config.json").is_file()]
    if not jobs:
        errors.append("no Harbor job directory (containing config.json) found")
    for job in jobs:
        if not (job / "result.json").is_file():
            errors.append(f"{job.name}: missing result.json (job unfinished?)")
        check_job_config(job, json.loads((job / "config.json").read_text()), errors)
        for trial in sorted(p for p in job.iterdir() if p.is_dir()):
            task_name = check_trial(trial, errors)
            if task_name:
                trial_counts[task_name] += 1

    expected = {p.name for p in args.tasks_root.iterdir() if (p / "task.toml").is_file()}
    missing = sorted(expected - trial_counts.keys())
    if missing:
        errors.append(f"{len(missing)} task(s) not evaluated: {', '.join(missing[:10])}{' …' if len(missing) > 10 else ''}")
    unknown = sorted(trial_counts.keys() - expected)
    if expected and unknown:
        warnings.append(f"trials for tasks not in {args.tasks_root}: {', '.join(unknown[:10])}")
    few = sorted(t for t, n in trial_counts.items() if n < args.min_trials)
    if few:
        errors.append(f"{len(few)} task(s) have fewer than {args.min_trials} trials: {', '.join(few[:10])}")

    check_file_sizes(sub, warnings)

    for w in warnings:
        print(f"warning: {w}")
    for e in errors:
        print(f"error: {e}")
    n_trials = sum(trial_counts.values())
    status = "INVALID" if errors else "OK"
    print(f"\n{status}: {len(jobs)} job(s), {len(trial_counts)} task(s), {n_trials} trial(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
