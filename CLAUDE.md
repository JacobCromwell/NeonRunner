# CLAUDE.md — Project Instructions (Draft)

This file is for Claude Code and all sub-agents working on this project. Read it before doing any work.
**Status:** Draft. The architecture will be finalized after the design phase ends.

## Source of truth
- `docs/GDD_CHECKPOINT.md` (later `docs/GDD.md`) is the authority on game design. **Do not invent design.**
- If a task needs a design decision that isn't in the design document, **do not guess**:
  1. Add the question to `docs/questions/<task-id>.md` (see "Parallel work"). When the task merges, the orchestrator numbers it and files it in `docs/OPEN_QUESTIONS.md` if work waits on it or its placeholder gets costly to change later, otherwise in `docs/OPEN_QUESTIONS_DEFERRED.md` (rules at the top of `docs/OPEN_QUESTIONS.md`).
  2. Implement the smallest reasonable placeholder, clearly marked `# DESIGN-TBD:` in code.
  3. Report it in your task summary.
- Record any decision the owner makes in the design document, not only in code. The design document is edited in design sessions with the owner; build agents don't change its design sections.
- `docs/TASK_PLAN.md` lists the build tasks, their order, and the model and effort level for each.
- `docs/USER_REQUESTS.md` holds the owner's requests still to do (built ones move to `docs/USER_REQUESTS_DONE.md`).

## Reading the docs (keep it cheap)
Every agent pays for what it reads, on every task, and the owner's weekly usage limit is what runs out first.
- **Architecture:** read the index `docs/ARCHITECTURE.md`, then only the part(s) of `docs/architecture/` you need,
  or just the paragraph (`grep -n "<word>" docs/architecture/*.md`, then read around the hit). Never the whole folder.
  A reference such as "`docs/ARCHITECTURE.md`, Zone skins" names a topic in the index.
- **Design:** search `docs/GDD_CHECKPOINT.md` for the section you need (`grep -n "^#\|§9.7"`); don't read it whole.
- **Questions:** `docs/OPEN_QUESTIONS.md` is short; read it when a task touches design. A cited item number lives in
  one of `docs/OPEN_QUESTIONS*.md`: `grep -n "^628\. " docs/OPEN_QUESTIONS*.md`. Never read the `_DEFERRED` or
  `_ANSWERED` files whole. A deferred item's placeholder stands as built.
- `docs/USER_REQUESTS_DONE.md`, `docs/TASK_PLAN.md`'s finished tasks and `git log` are history: search, don't read.

## Tech stack
- **Engine:** Godot 4 (pin the exact version in `project.godot`; do not upgrade without approval).
- **Language:** **GDScript only**, with static typing (`var speed: float`). No C#: it breaks the web export.
- **Targets:** Windows (Steam), Android, iOS, Web (demo).
- **Renderers:** Forward+ or Mobile on PC; the **Compatibility renderer must be supported** for web and low-end Android. Every visual feature must degrade gracefully there.

## Architecture principles
1. **Input goes through named input actions only** (`move_left`, `move_right`, `jump`, `slide`, `dash`, `slow_time`, `pause`). Never read raw keys or touch events in gameplay code. A separate touch layer converts swipes and taps into these actions. This enables key rebinding and later controller support.
2. **Gameplay pieces are abstract; zones are skins.** The generator and gameplay code never reference "truck" or "street." They reference floor segments, gaps, mount points, wall sections, and ceiling sections. Each zone's visuals live in skin resources.
3. **Level generator:**
   - Data-driven patterns plus a difficulty value.
   - **Seeded random numbers** (fixed seeds for the campaign, random in endless mode).
   - **Lane count is a parameter** (3 on mobile, 5–6 on PC). No generator code may assume a specific lane count.
4. **Collision:** damage happens only on actual hitbox contact. Damage hitboxes are slightly smaller than the visuals. Lanes are movement targets, never collision logic.
5. **A platform services layer** wraps everything platform-specific:
   - Ads, in-app purchases, leaderboards, store links, achievements, cloud save
   - One interface, per-platform implementations, and a **stub implementation** for the editor and web.
   - Gameplay code must never call a platform plugin directly.
6. **Build flavors:** `full_pc`, `full_mobile`, `web_demo`, selected by export preset/feature tags. The demo flavor ends after the Zone 1 boss and shows store links; it has no ads, purchases, or leaderboards.
7. **Tunable numbers live in data, not code:** damage, health, prices, cooldowns, timings, scaling curves, and credit rates go in resource or config files so balancing never requires code changes.
8. **Shared rules are implemented once:**
   - The rules for armor, shield, invulnerability, and claw contact kills belong in one damage/interaction system.
   - Enemies declare properties (e.g. `is_electrical`, `immune_to_weapons`, `is_host`, `solid_body_safe`) rather than re-implementing rules.

## Readability & fairness rules (apply to every enemy/obstacle)
- Every attack has a visual **and** audio warning before it happens (the player dies in one hit).
- Hazards keep the same color and shape language in every zone.
- Safe things look safe; deadly parts look deadly.
- Introduce one new mechanic at a time.

## Performance budgets (to confirm during prototyping)
- Mobile: target 60 fps on a mid-range Android phone; minimum acceptable 30 fps.
- Use MultiMesh plus shaders for crowds (e.g. swarm boss clusters). Simulate few entities; render many.
- Pool frequently spawned objects (bullets, credits, track segments).

## Assets
- 3D models are generated by code and exported as `.glb`, or built procedurally at runtime. Low-poly, glowing (emissive) materials, and bloom.
- Keep generator scripts in `tools/asset_gen/` so any asset can be regenerated and tweaked.
- Do not commit assets that can't be regenerated unless they come from a source with a clear license (record the license in `assets/LICENSES.md`).

## Workflow rules
- Work on the task you were given; don't expand scope.
- Verify before reporting a task complete, and report what you verified and how. The tests run in tiers
  (`docs/PERFORMANCE_AUDIT.md` §3.2; the full suite takes 13+ minutes, so it is not the default):
  - **Every task:** `tools/godot.sh test --gate` (exit code 0 = pass; about a minute). It runs the smoke run, the
    fast suites, and the suites that cover the files you changed (`tests/suite_map.json` maps paths to suites;
    `--plan` shows the list without running). Also run the specific suite for anything you built or changed if
    the plan didn't pick it (`--suite=<name>`), and add it to `tests/suite_map.json` when you add a suite or a
    new enemy/boss/skin folder whose name doesn't match its suite.
  - **A change to a core file** (`level_generator.gd`, `track_builder.gd`, `damage_rules.gd`, `run_world.gd`,
    `player.gd`, `level_run.gd`, `enemy.gd`, the boss framework, `tests/helpers/`, or any `data/levels`,
    `data/patterns`, `data/tuning`, `data/zones`) makes `--gate` run the full tier automatically. Let it.
  - **Before a merge to `main`:** `tools/godot.sh test --tier=merge` (about 5 minutes), and `--tier=full` after
    a batch of merges or when the merge touched generator or level data. The reviewer checks this, not
    every task.
  - Never report a tier as passed that you didn't run, and never skip a suite the plan selected because it is
    slow: the slow ones it adds are the ones covering what you touched.
- Keep commits small and descriptive. One task per branch or commit series.
- End every task with a short summary: what changed, what was verified, any `DESIGN-TBD` items, and any risks noticed.

## Parallel work
- **One task, one branch,** named after its ID in `docs/TASK_PLAN.md`, started from the latest `main`.
- **Merge one at a time:** merge the latest `main` into the task branch, run the tests and the smoke run, then merge.
- **Questions go in `docs/questions/<task-id>.md`,** never straight into `docs/OPEN_QUESTIONS*.md`, so parallel tasks don't collide on the shared list.
- **Core files change one task at a time:** `scripts/world/level_generator.gd`, `scripts/world/track_builder.gd`, `scripts/core/damage_rules.gd`, `scripts/run/run_world.gd`, `scripts/player/player.gd`, and the campaign, zone and level data. The task plan marks which tasks are core.
- **New enemies stay in their own files** (`docs/architecture/enemies.md`). A shared change an enemy needs belongs to a core task.

## Commands
`tools/godot.sh` finds the pinned Godot (via `$GODOT`, then `godot4`/`godot` on PATH, then the Windows user
folders under WSL) and re-imports resources automatically when files changed. Use it rather than calling Godot
directly. Under WSL, use the **native Linux build** (`tools/install_godot_wsl.sh` installs it to `~/.local`): a
Windows `.exe` reading the project over `\\wsl.localhost` takes ~66 s to start instead of ~2 s, and that tax is
paid by every test, smoke and import run (`docs/PERFORMANCE_AUDIT.md`). Windowed commands (`play`, `edit`) in
WSLg use the Compatibility renderer on the GPU through Mesa's D3D12 driver; headless commands are unaffected.
- Tests: `tools/godot.sh test --gate` (the per-task tier, see Workflow rules), `--tier=merge`, `--tier=full`;
  `--plan` prints the chosen suites, `--paths=a,b` plans for those files instead of the branch's changes.
  Plain `tools/godot.sh test [--suite=name] [--jobs=N]` runs every suite or the ones whose file name contains
  `name` (exit code 0 = pass). All of these boot the real game scene. `--jobs=N` splits the suites across N
  Godot processes, balanced by each suite's last measured time (`tests/.suite_times.json`); the tiers default
  to half the CPUs (at most 3), plain `test` to 1.
- **Long tiers: shard them over containers.** A tier that takes more than about 10 minutes on one container (the
  full tier is 50+ minutes on 4 CPUs) can hit the "stuck" timer (2400 s) or lose its work to a container restart.
  `tools/godot.sh test --tier=full --shard=K/N` runs only share K of N of the suites (the same balanced split on every
  container, so the shards together are the whole tier). Spread it over 5 or 6 containers (cloud sessions started
  with `create_session`, one per shard, all on the same commit that is already pushed) and require **every** shard
  to exit 0; a tier counts as passed only when all N shards did. A suite that fails only a frame-time or build-time
  budget while several runs share a machine is rerun alone (`--suite=<name>`) before it is called a failure.
  Push before a long run, run it in the background with its log in the scratchpad, and poll the log.
- Smoke run: `tools/godot.sh smoke [game args]` (prints only problems; exit code 1 if any). Without args it runs quick play.
- Play: `./play.sh` opens the title screen in a game window on the user's desktop. Quick play and review options
  (debug builds only): `--quick --lanes=6 --seed=4 --difficulty=0.6 --god --nofall --full-loadout
  --features=cyborg,drone --skin=gangland`, a campaign level with `--level=city/2` (takes `--lanes --god --nofall
  --full-loadout`), another build flavor with `--flavor=web_demo`. The full list is in `README.md`.
- Sound effects and music: `tools/godot.sh sfx [--only=a,b] [--review]` regenerates `assets/sfx/*.wav`, and
  `tools/godot.sh music [--review]` `assets/music/*.wav` (review images go to `build/sfx_review/`, `build/music_review/`).
- Rendered frames for a visual check: `godot --resolution 960x540 --fixed-fps 10 --write-movie build/f.png --quit-after 120 -- --god`
  (add `--rendering-method gl_compatibility` to check the web/low-end renderer, and a scene path such as
  `res://tools/showcase/enemy_showcase.tscn` before `--` for a close-up). `build/` is git-ignored and ignored by Godot.
- Web demo: export the "Web (demo)" preset to `exports/web/` (git-ignored) with `godot --headless --export-release`.
- Live tuning: F6 in-game. Tunables need an `@export_range` hint to appear in the panel.
- Anything that flickers or flashes must honour Settings > Reduced flashing (see `docs/ARCHITECTURE.md`, Zone skins).
