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

**Done (2026-10-03):** `tools/install_godot_wsl.sh` installs the official Linux build
(`ed1daf0bf`, same commit as the Windows exe) to `~/.local/godot` with `~/.local/bin/godot4` on PATH.
`tools/godot.sh` now prefers PATH over the remembered `.godot-path`, and for windowed commands under
WSL sets `GALLIUM_DRIVER=d3d12` + `--rendering-method gl_compatibility`. Measured after the switch:

| Command (native Linux build, WSL ext4) | Time |
|----------------------------------------|------|
| `godot4 --headless --import` (full re-import) | 6.2 s |
| `godot4 --headless --quit-after 5` (boot to title) | 1.75–2.4 s (was 66 s) |
| `tools/godot.sh smoke` | 9 s incl. import |
| `tools/godot.sh test --suite=movement` | 5.6 s wall (150 checks) |
| `tools/godot.sh play` renderer | OpenGL 4.6 Compatibility on **NVIDIA RTX 2080 via D3D12** |
| Forward+ in WSL | Vulkan on llvmpipe (software) — Ubuntu ships no Dozen ICD |
| Wayland display driver | fails (Zink can't pick a device); X11/XWayland is used |
| Audio | dummy driver until `sudo apt install libpulse0` (not installed yet — needs the owner's password) |

Remaining caveat: pressing Play *inside the editor* uses the project's renderer (Forward+), so it
will be software-rendered in WSL; run the game from the terminal (`./play.sh`) for GPU rendering, or
switch the editor's run instance to Compatibility via Editor > Editor Settings > Run > "Rendering
Method" override if needed.

WSLg feasibility check (before the install): `DISPLAY=:0`, `WAYLAND_DISPLAY=wayland-0`,
`/dev/dxg` and `/usr/lib/wsl/lib/libd3d12.so` all present on Ubuntu 24.04 / kernel 6.18. Machine:
6 CPUs, 7.7 GB RAM.

Notes kept from the feasibility check:
- `tools/godot.sh` already prefers `$GODOT`, then `godot4`/`godot` on `PATH`, before the Windows
  search. (It used to read the cached `.godot-path` *before* PATH; that order is now PATH first.)
- `tests/.suite_times.json` and the `.godot/` cache are portable; a one-time `--import` was needed.
- 7.7 GB RAM is tight for `test --jobs=N` with N > 2; measure before raising the default.
- `.import-stamp` / `find -newer` staleness check in `godot.sh` is local to WSL and fast.
- Audio from a Linux Godot goes through WSLg PulseAudio (`PULSE_SERVER=unix:/mnt/wslg/PulseServer`)
  once `libpulse0` is installed. The Windows binary remains a fallback for desktop play if wanted
  (`GODOT=<exe> ./play.sh`).

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

**Cleanup done (2026-10-03):** removed from `OPEN_QUESTIONS.md` the 30 struck-through "Answered"
bullets in sections A.1–A.3 and A.9 whose answers are recorded in the GDD (keeping their "still open"
residue as plain bullets) and the redundant "Answered (recorded in GDD_CHECKPOINT.md)" tail; the file's
intro now says answered A–C items are removed rather than struck through. Only ~4 KB: the file's bulk
(section D "From build phase 2", 184 KB, 55 task groups × ~6 numbered placeholder items) is **not
removable** — the owner's review says every phase-2 item keeps its `DESIGN-TBD` marker, and ~40 code
comments cite them as "OPEN_QUESTIONS.md §D, item N" (Markdown renumbers ordered lists, so even deleting
single answered items would shift the citations). `ARCHITECTURE.md` holds no resolved-question logs;
its size is dense current reference, so nothing there could be removed with certainty.

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

**Measured with the native Linux build (2026-10-03, `tools/godot.sh test --jobs=3`, 6 CPUs):**
full run **13 min 17 s wall**, ~27 min of CPU across the three processes, 69 suites,
~6.4 M checks. Biggest suites: `test_campaign` 230 s, `test_floating_head_routes` 100 s,
`test_generator` 93 s, `test_wall_fences` 79 s, `test_hostile_takeover_fight` 79 s,
`test_resonator` 69 s, `test_floating_head_faceoff` 66 s, `test_sleep_taker_fight` 63 s,
`test_floating_head_stomps` 50 s, `test_sleep_taker_attacks` 48 s, `test_the_house_attacks` 44 s.
Shape of the distribution: 29 suites under 10 s (≈100 s together), 13 between 10 and 30 s
(≈250 s), 17 over 30 s (≈1,280 s — 78 % of the CPU time). The three level-sweep suites
(`campaign`, `generator`, `city_gaps`) plus the boss-fight simulations are the whole cost.

That run also found **11 deterministic failures** in 5 suites on the committed tree
(`test_frame_times` ×3 "played the same 1 frames", `test_doodads` ×1, `test_resonator` ×1,
`test_sewer_swarm_whole` ×3 and `test_hostile_takeover_fight` ×3 "and finished"). They reproduce
serially, so they are not load flakiness; PR #14 ("user guided updates") added
`level_intro_screen.gd` and changed `level_run.gd`/`app.gd`, which fits runs not advancing past
their first frame. Not fixed in this pass — a separate task.

### Recommendation: three tiers plus change-based selection

The goal is "an agent cannot break the game without a test noticing" at the cost of a minute or
two per change, with the expensive fairness sweeps running where their cost is amortised.

**What actually breaks when agents change code, and what catches it:**

| Failure class | Cheapest reliable detector | Cost (native) |
|---|---|---|
| Parse/compile error anywhere (all 297 classes compile at boot) | boot to title: `godot4 --headless --quit-after 5` | 2 s |
| Runtime error on the common path (title → run → HUD → death → results) | `tools/godot.sh smoke` (40 s of simulated quick play, prints only problems) + `test_app_flow`, `test_main_scene`, `test_screens` | 9 s + ~17 s |
| A subsystem's rules (damage, pickups, movement, economy, skins' budgets, UI kit…) | the 29 suites under 10 s | ~100 s CPU, ~40 s on 3 jobs |
| One enemy or boss regressing | that enemy's/boss's suites (`test_resonator`, `test_the_house*`, …) | 10–100 s each |
| Generator fairness across all levels, lanes and seeds | `test_campaign`, `test_generator`, `test_city_gaps`, `test_wall_fences`, `test_pace` | ~10 min CPU |

**Implemented 2026-10-03** as `tools/godot.sh test --gate | --tier=merge | --tier=full`, with
`tools/test_plan.py` reading `tests/suite_map.json` (explicit `slow`/`medium` lists, ordered
path-glob rules that add suites or raise the tier, and a name-matching fallback on `_` boundaries
for `scripts/` and `data/` paths). Gate measured at 47 s wall (smoke + 37 of 78 suites, 3 jobs).
The per-suite `budget` idea below is not built yet.

**Tier 1 — gate (every agent task, before reporting done; target < 2 min wall):**
boot + smoke + every suite under ~10 s + the suites selected by the files the task changed
(below). Encode as `tools/godot.sh test --gate` → `run_tests.gd --tier=fast` plus `--files=` from
the selector. CLAUDE.md's "run the tests" rule points here.

**Tier 2 — merge (the orchestrator, when a branch merges to main; ~5 min on 3 jobs):**
everything except the three level sweeps and the long boss simulations; i.e. all suites under
30 s plus the full suites for any boss/enemy/skin the branch touched.

**Tier 3 — full (after a batch of merges, nightly, or when a core file changed; 13 min on 3 jobs):**
the current `tools/godot.sh test --jobs=3`. Mandatory when the change touches the core files
CLAUDE.md already lists (`level_generator.gd`, `track_builder.gd`, `damage_rules.gd`,
`run_world.gd`, `player.gd`, or `data/levels|patterns|tuning|zones`).

**Change-based selection** (`tools/godot.sh test --changed[=base]`): `git diff --name-only
base...HEAD` through a small glob→suite table (`tests/suite_map.json`), e.g.
`scripts/bosses/the_house/**` → `test_the_house*`; `scripts/enemies/resonator*` →
`test_resonator`; `scripts/world/skins/golden*` → `test_golden_skin`, `test_doodads`;
`scripts/ui/**` → `test_screens`, `test_ui_kit`, `test_app_flow`; any core file → tier 3. The
suite names already mirror the script names, so the table is short and the default for an
unmapped path is "tier 2".

**Make the slow suites cheaper without losing the guarantee:**
- Give `TestSuite` a `budget` the runner sets from the tier (`fast` / `full`). `test_campaign`'s
  seed sweep is 7 levels × 3 lane counts × 8 seeds (168 generations) on top of every level at
  every lane count (45); with `budget = fast` keep the 45 (the fairness guarantee itself) and
  drop the sweep to 2 seeds. Same lever for `test_generator`, `test_city_gaps`, `test_wall_fences`
  and the boss "routes/stomps/fight" simulations, which loop over seeds and lane counts.
- Keep the "seeded run decides the same every time" checks; determinism is what makes the sweeps
  trustworthy at fewer seeds.
- Re-time with `--jobs=3` on this machine after tiering; `--jobs=4+` is RAM-limited (7.7 GB).

**Why this keeps the confidence:** the boot and smoke steps catch every compile error and the
common-path runtime errors in seconds; the fast tier covers every subsystem's rules; the
change-based selection runs the deep suites for exactly the enemy/boss/skin an agent touched;
and anything that could affect fairness across the campaign (core files, level data) still
triggers the full sweeps. What is given up is only running the *untouched* bosses' and zones'
multi-minute simulations on every small edit — those still run at merge and in the full tier.

Housekeeping while doing this: update the stale "about 400 s / 54 suites" note in
`run_tests.gd` and README's Tests section; `tests/.suite_times.json` is merged by concurrent
`--jobs` processes with lost updates, so the balancing hint is only approximate.

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
| `assets/music/` | 54 MB | 9 owner-supplied MP3s (36 MB) + 7 generated WAVs (18 MB) |
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
| 1 | ✅ **Done** — Linux Godot 4.7.2 installed via `tools/install_godot_wsl.sh`; `godot.sh` prefers it and sets up Compatibility+D3D12 for `play`/`edit`. Pending: `sudo apt install libpulse0` for sound in the window | S | Startup 66 s → ~2 s; test run 5.6 s wall |
| 2 | Delete `.godot/`, re-import; confirm no `f0*.ctex` return (`build/.gdignore` exists) | XS | −37 MB cache; cleaner scans |
| 3 | ✅ **Done (tiers + selection, 2026-10-03)** — `tools/godot.sh test --gate|--tier=merge|--tier=full [--plan] [--paths=]`, `tools/test_plan.py`, `tests/suite_map.json`; CLAUDE.md, README and all six `.claude/agents/*.md` now prescribe the gate per task and merge/full for the reviewer. Measured gate: **47 s wall** (smoke + 37 suites, 3 jobs). Still open: a per-suite `budget` to shrink the sweeps' seed counts in lower tiers, and the 11 failing checks on the committed tree (§3.2) | M | Agent verification loop 13 min → 47 s; full sweeps still run at merge/full |
| 4 | Split `ARCHITECTURE.md` into `docs/architecture/*.md` + index; move `OPEN_QUESTIONS` §D to its own file *together with* a one-off rewrite of the ~40 "§D, item N" code-comment citations; de-dup README; archive `NEXT_STEPS.md`; update CLAUDE.md pointers. (Answered A–C items already removed.) | M | Agents read ~20–40 KB instead of ~680 KB per task |
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
