# Performance & Maintainability Audit

Audit of two reported behaviours: (1) Godot takes a very long time to start on this project, and
(2) AI agents take a very long time to make changes. Measured on 2026-10-03 against the working tree
at commit `53d1cb1` (+ uncommitted wall-gap work). **No code was changed for this audit.** This
document is the plan of record for the follow-up improvement work.

---

## 1. Headline findings

| # | Finding | Impact | Evidence |
|---|---------|--------|----------|
| 1 | **Windows Godot.exe opens the project over `\\wsl.localhost\...`** | Startup 66 s vs 4.5 s on a native path (**~15× slower**). Also inflates every test run, import and smoke run by ~60 s. | §2.1 |
| 2 | **Test suite is very long**: `test_campaign.gd` alone measured 690 s; 27 of 74 suites sum to 29 min | Agents must run tests before reporting done (CLAUDE.md); a single full run can exceed 30–45 min, longer over the WSL bridge | §3.2 |
| 3 | **Required reading for agents is ~700 KB**: `ARCHITECTURE.md` 317 KB, `OPEN_QUESTIONS.md` 204 KB, `GDD_CHECKPOINT.md` 67 KB, `README.md` 51 KB, `TASK_PLAN.md` 30 KB | Roughly 150–200K tokens before an agent writes a line. Much of it is log-style history. | §3.1 |
| 4 | **138 K lines of GDScript** (80 K game, 42 K tests, 16 K tools), 36 % of script bytes are comments | Large files (1–2 K lines) and prose-heavy comments make every read expensive | §3.3 |
| 5 | `.godot/imported` holds **325 stale `.ctex` (37 MB, half the cache)** from old `--write-movie` frames | Dead disk; slows any cache scan; trivially fixable | §2.3 |
| 6 | 6 generated zone WAVs (~17 MB) are now only fallbacks behind the supplied MP3s | Repo/export bloat; low priority | §4.2 |

The codebase is **otherwise clean at the file level**: every `class_name`, `.tres` and `.tscn` is
referenced from somewhere; there are no orphan scripts or assets. The size is real scope, not
litter.

---

## 2. Behaviour 1 — slow Godot startup

### 2.1 Root cause: cross-OS filesystem bridge (dominant)

`tools/godot.sh` finds the pinned engine at
`/mnt/c/Users/Jacob/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe`
and converts the project root with `wslpath -w`, producing
`\\wsl.localhost\Ubuntu\home\jacob\wsl-workspace\neon-runner\NeonRunner`. `tools/godot.ps1` /
`play.cmd` do the same from the Windows side (`$Root = Split-Path $PSScriptRoot`).

Every file `stat`, directory listing and read then crosses the WSL2 9P/Plan9 bridge. The editor
scans all ~2,800 project files, verifies ~170 `.import` files and their `.md5` siblings, and parses
all 478 scripts for the global class cache — thousands of round trips.

Measured (`godot --headless --path <X> --quit`, same binary, same project content, `.godot/` cache
present in both):

| Project location | Run 1 | Run 2 |
|------------------|-------|-------|
| `\\wsl.localhost\...` (WSL ext4) | 67.0 s | 65.6 s |
| `C:\Users\...\Temp\neon-runner-bench` (NTFS copy) | 4.5 s | 4.4 s |
| NTFS, after `--import`, `--quit-after 5` (real boot to title) | — | 4.6 s |
| NTFS, `--import` (full re-import) | — | 7.8 s |

**Conclusion: ~93 % of startup time is the filesystem bridge, not the project's content.**

The same tax applies to: `tools/godot.sh test` (each process pays ~60 s before the first suite
runs, and `--jobs=N` pays it N times), `smoke`, `sfx`, `music`, `web`, and the automatic
`run_import` whenever a file changed.

**Owner decision (2026-10-03):** keep the repo in WSL and install a **Linux Godot 4.7.2** inside
WSL, running the editor through WSLg.

WSLg feasibility check (no install performed): `DISPLAY=:0`, `WAYLAND_DISPLAY=wayland-0`,
`/dev/dxg` and `/usr/lib/wsl/lib/libd3d12.so` all present on Ubuntu 24.04 / kernel 6.18. Machine:
6 CPUs, 7.7 GB RAM.

Risks / notes for the implementation task:
- **Renderer under WSLg.** Vulkan via Mesa "Dozen" (d3d12 translation) is experimental; Forward+ may
  fail or be slow. The project already requires Compatibility-renderer support, so
  `--rendering-method gl_compatibility` (Mesa d3d12 GL) is the safe default for the editor in WSL.
  Headless work (tests, import, smoke, sfx/music generation) needs no renderer and is unaffected.
- `tools/godot.sh` already prefers `$GODOT`, then `godot4`/`godot` on `PATH`, before the Windows
  search — so dropping a Linux binary on `PATH` (or setting `GODOT`) is enough; delete `.godot-path`
  to clear the cached Windows path.
- `tests/.suite_times.json` and the `.godot/` cache are portable; a one-time `--import` is needed.
- 7.7 GB RAM is tight for `test --jobs=N` with N > 2; measure before raising the default.
- `.import-stamp` / `find -newer` staleness check in `godot.sh` is already local to WSL and fast.
- Audio from a Linux Godot goes through WSLg PulseAudio (`/mnt/wslg/PulseServer`); verify it works
  for `play`, otherwise the Windows binary can remain the "play on the desktop" path while the
  Linux binary handles editor/tests.

### 2.2 Secondary: what the remaining ~4.5 s is

On a native filesystem the boot is dominated by GDScript parsing/analysis of 297 `class_name`
scripts (80 K lines of game code; the analyzer must resolve the whole dependency graph before the
`App` autoload can compile) plus the import verification pass. This is inherent to the design (every
visual is code, so there are almost no scenes to load — `scenes/*.tscn` are 6–8 lines each) and is
acceptable. Reducing it meaningfully would require splitting the autoload dependency graph so the
title screen doesn't pull every enemy/boss/skin script; that's a large refactor for small gain and
is **not recommended** right now.

Fragility note: because everything is reached through `class_name`, a stale
`.godot/global_script_class_cache.cfg` (e.g. a new untracked script such as the in-progress
`scripts/world/wall_gap_placement.gd`) makes the *entire* game fail to compile
(`Identifier "WallGapPlacement" not declared` → `app.gd` compile error). `tools/godot.sh` guards
against this with `import_if_stale`; running Godot directly does not. Keep using the wrapper.

### 2.3 Stale import cache

`.godot/imported/` contains 325 `f00000NNN.png-<hash>.ctex` files (37 MB) — frames from
`--write-movie` runs that were imported before `build/.gdignore` existed. They are unreferenced by
any `.import` file. The real project has only 25 image sources. Also present and legitimate:
164 `.sample` (7 MB, SFX WAVs) and 7 `.mp3str` (28 MB).

Fix: delete `.godot/` and re-import once (`tools/godot.sh import`). Zero risk; `.godot/` is
git-ignored and fully regenerable.

---

## 3. Behaviour 2 — slow AI-agent iteration

### 3.1 Documentation volume agents are told to read

CLAUDE.md and `.claude/agents/*.md` point agents at `docs/GDD_CHECKPOINT.md` (design authority),
`docs/TASK_PLAN.md`, `docs/ARCHITECTURE.md`, and `docs/OPEN_QUESTIONS.md`.

| File | Size | Lines | Nature |
|------|------|-------|--------|
| `docs/ARCHITECTURE.md` | 317 KB | 3,053 | Reference, but with embedded history, owner decisions, per-task notes; Tests (2,650–2,941) and Review tools (2,942–3,053) sections are operational appendices; bosses/cinematics split across three overlapping sections (2,039–2,576) |
| `docs/OPEN_QUESTIONS.md` | 204 KB | 2,174 | Section D "Raised during build" (lines 106–2,174) is a log; resolved items kept inline with strikethrough; ~490 numbered entries, inconsistent status markers |
| `docs/GDD_CHECKPOINT.md` | 67 KB | 654 | Current design authority; reasonable |
| `README.md` | 51 KB | 594 | Duplicates CLI flags, test instructions and layout that also live in ARCHITECTURE.md / CLAUDE.md |
| `docs/TASK_PLAN.md` | 30 KB | 441 | 65 tasks, only A1 marked done; status is in prose |
| `docs/NEXT_STEPS.md` | 6.6 KB | 90 | Explicitly historical ("original build plan") |

Total ≈ 680 KB ≈ 170K+ tokens of prose. An agent that follows the instructions literally spends most
of its context window before touching code, and any doc update it makes lands in a 300 KB file.

Recommended restructuring (for the improvement phase):
1. Split `ARCHITECTURE.md` into per-subsystem files (`docs/architecture/generator.md`,
   `skins.md`, `enemies.md`, `bosses.md`, `tests.md`, `tools.md`, …) with a ~2-page index. Agents
   then read only the subsystem they touch.
2. Move `OPEN_QUESTIONS.md` section D's *answered* entries into a `docs/decisions/` archive (or fold
   into the GDD) and keep only genuinely open items in the live file. Add a uniform status marker.
3. De-duplicate README vs ARCHITECTURE vs CLAUDE.md: README keeps "how to run"; ARCHITECTURE keeps
   "how it works"; CLAUDE.md keeps rules and points at both.
4. Mark `NEXT_STEPS.md` as archived or delete it.
5. Update `TASK_PLAN.md` statuses so agents don't re-derive what's done.

### 3.2 Test suite cost

- 74 suites in `tests/suites/`, 42 K lines of test code, "~6,000,000 checks" per README.
- Measured per-suite times (`tests/.suite_times.json`, 27 suites measured):
  `test_campaign` **690 s**, `test_generator` 194 s, `test_wall_fences` 189 s, `test_city_gaps`
  185 s, `test_pace` 84 s, `test_floating_head_routes` 79 s, `test_sleep_taker_fight` 54 s … sum
  **1,748 s** for those 27. `run_tests.gd` still documents "about 400 s on a quiet machine" for 54
  suites — that figure is stale; the watchdog is 2,400 s.
- `test_campaign._test_levels_generate` builds every campaign level at 3/5/6 lanes **plus** a
  sweep of 7 levels × 3 lane counts × 8 seeds ≈ 213 full level generations, each 55–150 s of
  track, on top of the recency/hush/lighting tests in the same file.
- Every Godot process (each `--jobs` worker) pays the full engine startup first (§2.1: ~60 s today
  over the bridge).
- CLAUDE.md says: "Run the project headless and any tests before reporting a task complete." Agents
  comply, so the whole suite runs after small changes.

Recommended:
1. Fix §2.1 first — it removes ~60 s per process and speeds every file access inside the suites.
2. Tier the suites: a **fast tier** (unit-level, < 60 s total) that agents must run, and a **slow
   tier** (`test_campaign`, `test_generator`, `test_wall_fences`, `test_city_gaps`, `test_pace`,
   boss fight suites) run before merge / by the orchestrator. Encode in `run_tests.gd`
   (e.g. `--tier=fast`) and CLAUDE.md.
3. Shrink the campaign seed sweep (or move it to the slow tier / a nightly job) — e.g. 3 seeds
   instead of 8, or only the level with the most features per zone.
4. Update the stale timing figures in `run_tests.gd` and README.
5. Re-measure `--jobs=2/3` on this 6-core / 7.7 GB machine once Godot runs natively in WSL.

### 3.3 Code volume and shape

| Area | Files | Lines | Notes |
|------|-------|-------|-------|
| `scripts/world/` | 74 | 21,228 | Generator (2,096), track builder, 6 zone skins × (skin + towers/facades + ceilings + doodads + props + street) ≈ 2–3 K lines per zone |
| `scripts/bosses/` | 53 | 19,316 | 6 bosses, each 2–4 K lines across model/attacks/phases files |
| `scripts/enemies/` | 68 | 17,712 | ~20 enemy types |
| `scripts/ui/` | 32 | 6,672 | |
| `scripts/run/` | 19 | 4,184 | |
| other `scripts/` | 66 | 10,700 | player, app, core, campaign, audio, cinematics, powerups, platform |
| `tests/` | 95 | 42,172 | |
| `tools/` | 71 | 16,177 | asset_gen (SFX/music synth, mesh kits), measure, showcase, web |
| **Total** | **478** | **138,162** | 6.1 MB |

- Comment ratio: 19 % of lines but **36 % of bytes** in `scripts/` (comment lines average 83 chars
  vs 43 for code). Doc comments are paragraph-length on nearly every constant and function, with
  cross-references to GDD sections. This is a deliberate style and helps correctness, but it roughly
  doubles the tokens an agent spends per file. Not recommended to strip wholesale; consider trimming
  only where a comment restates the code or duplicates ARCHITECTURE.md.
- The largest files (`level_generator.gd` 2,096, `floating_head.gd` 1,334, `player.gd` 1,149,
  `floating_head_faceoff.gd` 1,147, `hover_truck.gd` 1,087) are the "core, one task at a time"
  files per CLAUDE.md — they serialise parallel agent work. Splitting `level_generator.gd` by
  placement concern (it already has helper classes such as `WallGapPlacement`, `WallFencePlacement`,
  `GapDensity`, `CeilingZones` being extracted — the uncommitted work is doing exactly this) is the
  right direction.
- There is **no dead code at file granularity**: all 297 `class_name`s, all 96 `.tres`, and all 38
  `.tscn` are referenced. `WindowCyborg` is the only class referenced solely by string/type name
  rather than class, which is fine.

### 3.4 Architecture impressions

Strengths:
- Principles in CLAUDE.md are actually followed: input via actions, abstract track pieces + skin
  resources, seeded generator with lane count as a parameter, centralised damage rules, tunables in
  `data/tuning/*.tres`, platform services behind a stub, build flavors via export filters.
- "Assets are code" works: 58 MB of assets is entirely audio/fonts; all geometry is procedural via
  `MeshKit`/`MeshBatch` (one surface per material, batched per chunk), with regeneration tools in
  `tools/asset_gen/`. Music and SFX are loaded lazily by name (`MusicDirector.play`,
  `SfxLibrary.stream`), so no audio is loaded at boot.
- Scenes are tiny; the whole game is code → fast scene loading, trivially diffable, but the editor is
  nearly useless for visual authoring and *every* visual change is a code read for an agent.
- Runtime budgets already exist (chunk dress budget 1 ms, F7 frame graph, `tools/measure/`).

Weaknesses / costs of the approach:
- **Everything funnels through `class_name` and autoloads**, so the GDScript analyzer resolves the
  entire 80 K-line graph on every start and a single parse error anywhere kills boot (§2.2).
- **Per-zone and per-boss code is large and parallel in structure** (six `*_skin.gd` + facades +
  ceilings + doodads + props each). It isn't copy-paste duplication — each zone is bespoke — but it
  means ~18 K lines of hand-written geometry that only tests and screenshots can verify. Any shared
  change to the skin contract touches 6 zones.
- **Documentation is the real scale problem** for agents, more than code (§3.1).
- **Tests are integration-heavy** (they boot the real game and generate full levels); excellent
  for fairness guarantees, expensive to run on every edit (§3.2).

---

## 4. Asset inventory

### 4.1 Sizes

| Path | Size | Contents |
|------|------|----------|
| `assets/music/` | 46 MB | 7 owner-supplied MP3s (29 MB) + 7 generated WAVs (17 MB) |
| `assets/sfx/` | 12 MB | 152 generated WAVs (all listed in `data/audio/sfx_library.tres`) |
| `assets/fonts/` | 376 KB | Exo2, Orbitron (OFL) |
| `assets/icon/`, `assets/sprites/` | 260 KB | icon + Marketplace citizen flipbooks |
| `docs/art/reference/` | 1.4 MB | 3 reference JPGs (gdignored — correct) |
| `.git/` | 78 MB | history incl. regenerated WAVs |
| `.godot/` | 76 MB | 37 MB stale (§2.3) |

### 4.2 Possibly unneeded assets

- Generated zone WAVs `gangland.wav`, `marketplace.wav`, `corporate.wav`, `dead_zone.wav`,
  `golden.wav` (~13.6 MB) are shadowed by `zone_tracks` overrides to the MP3s in
  `music_library.tres`; README says they "remain available for cinematics". `city.wav` and
  `menu.wav` are still used directly. The Web (demo) preset already excludes five of them. **Ask
  the owner** whether the fallbacks must stay; if not, remove them and their `riff_tracks` keys,
  and drop them from `tools/asset_gen/music_gen.gd`'s default set.
- `README.md` mentions `Horizon_Of_Glass.mp3` as "intentionally unused" — it is not in the repo,
  so nothing to remove; just a stale sentence.
- Nothing else is unreferenced.

---

## 5. Recommended order of work

| Step | Task | Effort | Expected gain |
|------|------|--------|---------------|
| 1 | Install Linux Godot 4.7.2 in WSL; set `GODOT`/`PATH`; delete `.godot-path`; re-import; verify `tools/godot.sh test --suite=movement`, `smoke`, and `edit` (Compatibility renderer under WSLg) | S | Startup 66 s → ~5 s; every test/import/smoke run ~60 s faster per process |
| 2 | Delete `.godot/`, re-import; confirm no `f0*.ctex` return (`build/.gdignore` exists) | XS | −37 MB cache; cleaner scans |
| 3 | Tier the tests (`--tier=fast`/`slow`), shrink the campaign seed sweep, update stale timing text, update CLAUDE.md "run tests" rule to the fast tier | M | Agent verification loop from 30+ min to a few minutes |
| 4 | Split `ARCHITECTURE.md` into `docs/architecture/*.md` + index; archive answered `OPEN_QUESTIONS` entries; de-dup README; archive `NEXT_STEPS.md`; update CLAUDE.md pointers | M | Agents read ~20–40 KB instead of ~680 KB per task |
| 5 | Decide on the fallback zone WAVs (§4.2) | XS | −13 MB if removed |
| 6 | (Later, optional) continue extracting placement helpers out of `level_generator.gd`; consider trimming comments that restate code | L | Less serialisation of agent work on core files |

Steps 1–2 fix behaviour 1 almost entirely. Steps 1, 3 and 4 together address behaviour 2.

---

## 6. Measurement commands (for re-checking after changes)

```bash
# Startup (headless; add --quit-after 5 to reach the title screen)
GODOT=<binary>; time $GODOT --headless --path <project> --quit
# Full import
time $GODOT --headless --path <project> --import
# Stale import cache check
ls .godot/imported/f0*.ctex | wc -l
# Suite times after a full run
python3 -c "import json;d=json.load(open('tests/.suite_times.json'));print(sum(d.values()));print(sorted(d.items(),key=lambda x:-x[1])[:10])"
# Doc sizes
wc -c README.md CLAUDE.md docs/*.md
# Code volume
for d in scripts tests tools; do echo $d $(find $d -name '*.gd' | wc -l) $(cat $(find $d -name '*.gd') | wc -l); done
```
