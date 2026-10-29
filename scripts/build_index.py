#!/usr/bin/env python3
"""从各任务的 task.toml 生成 tasks/index.jsonl（每行一个任务，供排行榜和外部工具读取）
以及 README 中的任务分布图 assets/task-distribution*.svg。

用法：
    python3 scripts/build_index.py          # 重新生成索引和分布图
    python3 scripts/build_index.py --check  # 只检查索引和分布图是否与 task.toml 一致（CI 用）
"""
import json
import sys
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TASKS = ROOT / "tasks"
INDEX = TASKS / "index.jsonl"
# 从 [metadata] 原样带出的字段，缺失时写 null；出题过程字段（difficulty_explanation、calibration 等）不进索引
METADATA_FIELDS = [
    "app",
    "upstream_repo",
    "upstream_commit",
    "upstream_license",
    "api_level",
    "fpoints",
    "requires_emulator",
    "expert_time_estimate_min",
    "kits",
    "tags",
]


def entry(task_dir: Path) -> dict:
    with open(task_dir / "task.toml", "rb") as f:
        config = tomllib.load(f)
    task = config.get("task", {})
    meta = config.get("metadata", {})
    return {
        "id": task_dir.name,
        "name": task.get("name"),
        "version": task.get("version"),
        # 分类以任务 id 前缀为准，与 validate_tasks.py 一致
        "category": task_dir.name.split("-", 1)[0],
        "description": task.get("description"),
        "keywords": task.get("keywords", []),
        "path": task_dir.relative_to(ROOT).as_posix(),
        **{key: meta.get(key) for key in METADATA_FIELDS},
        "agent_timeout_sec": config.get("agent", {}).get("timeout_sec"),
        "verifier_timeout_sec": config.get("verifier", {}).get("timeout_sec"),
        "verifier_environment_mode": config.get("verifier", {}).get("environment_mode"),
    }


def render(entries: list[dict]) -> str:
    return "".join(json.dumps(e, ensure_ascii=False) + "\n" for e in entries)


# README 中的任务分布图：(分类, 颜色, 中文名, 英文名)，顺序与 README 分类表一致
CHART_CATEGORIES = [
    ("feature", "#4C7BF4", "Feature 功能实现", "Feature"),
    ("bugfix", "#F2994A", "Bugfix 缺陷修复", "Bugfix"),
    ("spec", "#2EA977", "Spec 规格驱动开发", "Spec"),
]
CHARTS = {"zh": ROOT / "assets/task-distribution.svg", "en": ROOT / "assets/task-distribution.en.svg"}


def render_chart(entries: list[dict], lang: str) -> str:
    width, bar_y, bar_h, gap = 720, 8, 12, 3
    counts = {c: sum(e["category"] == c for e in entries) for c, *_ in CHART_CATEGORIES}
    total = sum(counts.values()) or 1
    unit = "个任务" if lang == "zh" else "tasks"

    # 横条：按比例分段，段间留缝，两端圆角由 clipPath 统一裁出
    segments, x = [], 0.0
    shown = [(c, color) for c, color, *_ in CHART_CATEGORIES if counts[c]]
    usable = width - gap * (len(shown) - 1)
    for c, color in shown:
        w = usable * counts[c] / total
        segments.append(f'<rect x="{x:.1f}" y="{bar_y}" width="{w:.1f}" height="{bar_h}" fill="{color}"/>')
        x += w + gap

    legend, col = [], width / len(CHART_CATEGORIES)
    for i, (c, color, zh, en) in enumerate(CHART_CATEGORIES):
        lx = i * col
        pct = round(100 * counts[c] / total)
        legend.append(
            f'<circle cx="{lx + 5}" cy="{bar_y + 38}" r="5" fill="{color}"/>'
            f'<text x="{lx + 16}" y="{bar_y + 43}" class="name">{zh if lang == "zh" else en}</text>'
            f'<text x="{lx}" y="{bar_y + 78}"><tspan class="num">{counts[c]}</tspan>'
            f'<tspan class="meta" dx="6">{unit} · {pct}%</tspan></text>'
        )

    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{bar_y + 90}" viewBox="0 0 {width} {bar_y + 90}">
<style>
text {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "PingFang SC", "Microsoft YaHei", "Noto Sans CJK SC", sans-serif; fill: #1F2328; }}
.name {{ font-size: 14px; fill: #59636E; }}
.num {{ font-size: 28px; font-weight: 600; }}
.meta {{ font-size: 13px; fill: #59636E; }}
@media (prefers-color-scheme: dark) {{
  text {{ fill: #E6EDF3; }}
  .name, .meta {{ fill: #9198A1; }}
}}
</style>
<clipPath id="bar"><rect x="0" y="{bar_y}" width="{width}" height="{bar_h}" rx="{bar_h / 2}"/></clipPath>
<g clip-path="url(#bar)">{"".join(segments)}</g>
{"".join(legend)}
</svg>
"""


def outputs() -> dict[Path, str]:
    task_dirs = sorted(p for p in TASKS.iterdir() if (p / "task.toml").is_file())
    entries = [entry(p) for p in task_dirs]
    return {INDEX: render(entries), **{path: render_chart(entries, lang) for lang, path in CHARTS.items()}}


def main() -> int:
    files = outputs()
    if "--check" in sys.argv[1:]:
        stale = [p for p, content in files.items() if not p.is_file() or p.read_text() != content]
        for p in stale:
            print(f"✗ {p.relative_to(ROOT)} is out of date, run: python3 scripts/build_index.py")
        if not stale:
            print("✓ index and charts are up to date")
        return 1 if stale else 0
    for p, content in files.items():
        p.parent.mkdir(exist_ok=True)
        p.write_text(content)
        print(f"wrote {p.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
