#!/usr/bin/env python3
"""Suite time weights for `tools/godot.sh test --jobs=N` and `--shard=K/N` (docs/architecture/tests.md).

    suite_times.py shard K/N SUITE...   print shard K's suites (of N), one per line
    suite_times.py jobs N SUITE...      print N comma-separated groups, one per line
    suite_times.py update [TIMES.json ...]   merge measured times into the committed baseline

A suite's weight is its time in tests/suite_times_baseline.json (committed: measured on a 4-CPU cloud
container, so a fresh checkout balances well), else its file size as a stand-in. `jobs` lets this
machine's own last measurements (tests/.suite_times.json, git-ignored, rewritten by every run) override
the baseline; `shard` reads the baseline only, so every container computes the same split and the
shards together are exactly the whole tier. `update` (default: tests/.suite_times.json) is how the
baseline is refreshed after a full run: on sharded runs, pass every shard's times file.
"""
from __future__ import annotations

import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SUITES_DIR = os.path.join(ROOT, "tests", "suites")
BASELINE = os.path.join(ROOT, "tests", "suite_times_baseline.json")
LOCAL = os.path.join(ROOT, "tests", ".suite_times.json")


def load(path: str) -> dict[str, float]:
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, ValueError):
        return {}
    return {k: float(v) for k, v in data.items() if isinstance(v, (int, float))} if isinstance(data, dict) else {}


def weigher(use_local: bool):
    times = load(BASELINE)
    if use_local:
        times.update(load(LOCAL))

    def weight(suite: str) -> float:
        if suite in times:
            return times[suite]
        try:
            return os.path.getsize(os.path.join(SUITES_DIR, suite)) / 20000.0 + 0.5
        except OSError:
            return 1.0

    return weight


def split(suites: list[str], n: int, use_local: bool) -> list[list[str]]:
    """Longest first onto the least-loaded bin (ties to the lower bin), deterministic for one input."""
    weight = weigher(use_local)
    bins: list[list[str]] = [[] for _ in range(n)]
    loads = [0.0] * n
    for s in sorted(set(suites), key=lambda s: (-weight(s), s)):
        i = min(range(n), key=lambda j: (loads[j], j))
        bins[i].append(s)
        loads[i] += weight(s)
    return bins


def update(paths: list[str]) -> int:
    baseline = load(BASELINE)
    measured: dict[str, float] = {}
    for p in paths:
        got = load(p)
        if not got:
            print(f"no times in {p}", file=sys.stderr)
        measured.update(got)
    existing = {f for f in os.listdir(SUITES_DIR) if f.startswith("test_") and f.endswith(".gd")}
    baseline.update(measured)
    out = {k: round(v, 1) for k, v in sorted(baseline.items()) if k in existing}
    with open(BASELINE, "w", encoding="utf-8") as f:
        json.dump(out, f, indent="\t")
        f.write("\n")
    missing = sorted(existing - set(out))
    print(f"{len(measured)} measured, {len(out)} in the baseline" + (f"; not measured yet: {', '.join(missing)}" if missing else ""))
    return 0


def main(argv: list[str]) -> int:
    if len(argv) >= 2 and argv[0] == "shard":
        k, n = (int(x) for x in argv[1].split("/"))
        print("\n".join(sorted(split(argv[2:], n, use_local=False)[k - 1])))
        return 0
    if len(argv) >= 2 and argv[0] == "jobs":
        for group in split(argv[2:], int(argv[1]), use_local=True):
            print(",".join(group))
        return 0
    if argv and argv[0] == "update":
        return update(argv[1:] or [LOCAL])
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
