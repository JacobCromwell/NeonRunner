#!/usr/bin/env python3
"""Plans which test suites `tools/godot.sh test --gate|--tier=...` runs (docs/PERFORMANCE_AUDIT.md, 3.2).

    test_plan.py --tier=gate|merge|full [--base=REF] [--paths=a,b] [--root=DIR] [--json]

Reads tests/suite_map.json. The plan is the tier's suites plus the suites the changed files map to;
a changed core file raises the tier. Changed files are the branch's commits since `base`
(default: the merge base with main, or master), the working tree and untracked files; `--paths`
replaces that with an explicit list (to ask "what would run if I changed X?"). Prints the suite
files one per line (the last line is `TIER <tier>`), notes on stderr; `--json` prints everything
as one object instead.
"""
from __future__ import annotations

import fnmatch
import json
import os
import subprocess
import sys

TIERS = ["gate", "merge", "full"]


def run_git(root: str, *args: str) -> list[str]:
    try:
        out = subprocess.run(["git", *args], cwd=root, capture_output=True, text=True, check=False)
    except FileNotFoundError:
        return []
    if out.returncode != 0:
        return []
    return [line.strip() for line in out.stdout.splitlines() if line.strip()]


def changed_paths(root: str, base: str | None) -> tuple[list[str], list[str]]:
    """Paths changed on this branch, in the working tree and untracked, relative to root."""
    notes: list[str] = []
    if not run_git(root, "rev-parse", "--is-inside-work-tree"):
        notes.append("not a git checkout: only the tier's own suites run")
        return [], notes
    paths: set[str] = set()
    if base is None:
        for candidate in ("main", "master", "origin/main"):
            if run_git(root, "rev-parse", "--verify", "--quiet", candidate):
                base = candidate
                break
    if base:
        merge_base = run_git(root, "merge-base", base, "HEAD")
        if merge_base:
            committed = run_git(root, "diff", "--name-only", f"{merge_base[0]}..HEAD")
            paths.update(committed)
            if committed:
                notes.append(f"{len(committed)} file(s) committed since {base}")
        else:
            notes.append(f"no merge base with {base}: only uncommitted changes are considered")
    else:
        notes.append("no main/master branch found: only uncommitted changes are considered")
    working = run_git(root, "diff", "--name-only", "HEAD")
    untracked = run_git(root, "ls-files", "--others", "--exclude-standard")
    paths.update(working)
    paths.update(untracked)
    if working or untracked:
        notes.append(f"{len(set(working) | set(untracked))} uncommitted file(s)")
    # Paths git reports are relative to the repository root, which may be above the project root.
    top = run_git(root, "rev-parse", "--show-toplevel")
    if top:
        rel = os.path.relpath(os.path.abspath(root), top[0])
        if rel != ".":
            prefix = rel.replace(os.sep, "/") + "/"
            paths = {p[len(prefix):] for p in paths if p.startswith(prefix)}
    return sorted(paths), notes


def name_tokens(path: str) -> list[str]:
    """Name parts of a scripts/ or data/ path that may name a suite: the file's stem (with common
    suffixes stripped) and the folders between the area and the file."""
    parts = path.split("/")
    if len(parts) < 3 or parts[0] not in ("scripts", "data"):
        return []
    stem = os.path.splitext(parts[-1])[0]
    if stem.endswith(".gdshader"):
        stem = stem[: -len(".gdshader")]
    tokens = {stem}
    for suffix in ("_tuning", "_model", "_rules", "_skin", "_def", "_boss", "_body", "_part", "_props", "_kit"):
        if stem.endswith(suffix) and len(stem) > len(suffix):
            tokens.add(stem[: -len(suffix)])
    tokens.update(parts[2:-1])
    return sorted(t for t in tokens if t and t not in ("skins", "meshes", "shaders", "screens", "widgets", "theme"))


def token_matches(token: str, suite: str) -> bool:
    return suite == token or suite.startswith(token + "_") or token.startswith(suite + "_")


def plan(root: str, tier: str, paths: list[str], suites: list[str], spec: dict) -> dict:
    slow = set(spec.get("slow", []))
    medium = set(spec.get("medium", []))
    rules = spec.get("rules", [])
    reasons: dict[str, set[str]] = {}
    escalations: list[str] = []
    extra: set[str] = set()

    def add(suite_glob: str, why: str) -> None:
        for s in fnmatch.filter(suites, suite_glob):
            extra.add(s)
            reasons.setdefault(s, set()).add(why)

    effective = tier
    for path in paths:
        matched = False
        names = True
        for rule in rules:
            if fnmatch.fnmatch(path, rule["match"]):
                matched = True
                names = rule.get("names", True)
                for suite_glob in rule.get("suites", []):
                    add(suite_glob, path)
                raise_to = rule.get("tier")
                if raise_to and TIERS.index(raise_to) > TIERS.index(effective):
                    effective = raise_to
                    escalations.append(f"{path} raises the tier to {raise_to}")
                break
        if path.startswith("tests/suites/test_") and path.endswith(".gd"):
            add(os.path.basename(path)[len("test_"):-len(".gd")], path)
            matched = True
        if names:
            hits = [s for s in suites for t in name_tokens(path) if token_matches(t, s)]
            for s in hits:
                add(s, path)
            if hits:
                matched = True
        if not matched and path.startswith("scripts/") and path.endswith(".gd"):
            if TIERS.index("merge") > TIERS.index(effective):
                effective = "merge"
                escalations.append(f"{path} matches no rule or suite name: tier raised to merge")

    if effective == "full":
        chosen = set(suites)
    elif effective == "merge":
        chosen = {s for s in suites if s not in slow}
    else:
        chosen = {s for s in suites if s not in slow and s not in medium}
    chosen |= extra
    unknown = sorted((slow | medium) - set(suites))
    return {
        "tier": effective,
        "requested_tier": tier,
        "suites": sorted(chosen),
        "mapped": {s: sorted(reasons[s]) for s in sorted(extra)},
        "escalations": escalations,
        "changed": paths,
        "unknown_in_map": unknown,
    }


def main(argv: list[str]) -> int:
    tier = "gate"
    base: str | None = None
    explicit: list[str] | None = None
    root = os.getcwd()
    as_json = False
    for arg in argv:
        if arg.startswith("--tier="):
            tier = arg.split("=", 1)[1]
        elif arg.startswith("--base="):
            base = arg.split("=", 1)[1]
        elif arg.startswith("--paths="):
            explicit = [p for p in arg.split("=", 1)[1].split(",") if p]
        elif arg.startswith("--root="):
            root = arg.split("=", 1)[1]
        elif arg == "--json":
            as_json = True
        else:
            print(f"unknown option {arg}", file=sys.stderr)
            return 2
    if tier not in TIERS:
        print(f"unknown tier {tier}; use {', '.join(TIERS)}", file=sys.stderr)
        return 2
    with open(os.path.join(root, "tests", "suite_map.json"), encoding="utf-8") as f:
        spec = json.load(f)
    suites = sorted(
        name[len("test_"):-len(".gd")]
        for name in os.listdir(os.path.join(root, "tests", "suites"))
        if name.startswith("test_") and name.endswith(".gd")
    )
    notes: list[str] = []
    if explicit is not None:
        paths = explicit
    elif tier == "full":
        paths = []
    else:
        paths, notes = changed_paths(root, base)
    result = plan(root, tier, paths, suites, spec)
    result["notes"] = notes
    if as_json:
        print(json.dumps(result, indent=2))
        return 0
    for note in notes:
        print(f"note: {note}", file=sys.stderr)
    for line in result["escalations"]:
        print(f"note: {line}", file=sys.stderr)
    if result["unknown_in_map"]:
        print(f"note: tests/suite_map.json names suites that don't exist: {', '.join(result['unknown_in_map'])}", file=sys.stderr)
    if result["mapped"]:
        print("suites added for the changed files: " + ", ".join(result["mapped"]), file=sys.stderr)
    for s in result["suites"]:
        print(f"test_{s}.gd")
    print(f"TIER {result['tier']}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
