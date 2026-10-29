#!/usr/bin/env python3
"""校验任务目录结构与 task.toml 元数据。

用法：
    python3 scripts/validate_tasks.py              # 校验 tasks/ 下所有任务
    python3 scripts/validate_tasks.py <task-dir>…  # 校验指定任务
"""
import re
import sys
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATEGORIES = {"feature", "bugfix", "spec"}
REQUIRED_FILES = [
    "instruction.md",
    "task.toml",
    "environment/Dockerfile",
    "solution/solve.sh",
    "tests/test.sh",
]
REQUIRED_METADATA = ["category", "app", "upstream_license", "api_level"]
TASK_ID_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
# 基准环境约定，见 docs/environment.md
SCHEMA_VERSION = "1.4"  # Harbor 0.24.0
API_LEVEL = 24


def validate(task_dir: Path) -> list[str]:
    errors = []
    task_id = task_dir.name
    # 任务平铺在 tasks/ 下，分类由任务 id 前缀决定
    category = task_id.split("-", 1)[0]

    if not TASK_ID_RE.match(task_id) or category not in CATEGORIES or task_id == category:
        errors.append(f"task id must be kebab-case and start with one of {sorted(f'{c}-' for c in CATEGORIES)}")

    for rel in REQUIRED_FILES:
        if not (task_dir / rel).is_file():
            errors.append(f"missing {rel}")
    if errors:
        return errors

    with open(task_dir / "task.toml", "rb") as f:
        config = tomllib.load(f)

    if config.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"schema_version must be {SCHEMA_VERSION!r} (Harbor 0.24.0), got {config.get('schema_version')!r}")

    name = config.get("task", {}).get("name")
    if name != f"efflora/{task_id}":
        errors.append(f"task.name should be 'efflora/{task_id}', got {name!r}")

    meta = config.get("metadata", {})
    for key in REQUIRED_METADATA:
        if meta.get(key) in (None, ""):
            errors.append(f"metadata.{key} is required")
    if meta.get("category") not in (None, category):
        errors.append(f"metadata.category {meta.get('category')!r} != task id prefix '{category}'")
    if meta.get("api_level") not in (None, "", API_LEVEL):
        errors.append(f"metadata.api_level must be {API_LEVEL}, got {meta['api_level']!r}")

    if "reward" not in (task_dir / "tests/test.sh").read_text():
        errors.append("tests/test.sh does not appear to write a reward file")
    if "<" in (task_dir / "instruction.md").read_text().split("\n", 1)[0]:
        errors.append("instruction.md still contains placeholders in its title")

    return errors


def main() -> int:
    if len(sys.argv) > 1:
        task_dirs = [Path(p).resolve() for p in sys.argv[1:]]
    else:
        task_dirs = sorted(p for p in (ROOT / "tasks").iterdir() if p.is_dir())

    failed = 0
    for task_dir in task_dirs:
        errors = validate(task_dir)
        rel = task_dir.relative_to(ROOT) if task_dir.is_relative_to(ROOT) else task_dir
        if errors:
            failed += 1
            print(f"✗ {rel}")
            for e in errors:
                print(f"    - {e}")
        else:
            print(f"✓ {rel}")

    print(f"\n{len(task_dirs) - failed}/{len(task_dirs)} tasks valid")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
