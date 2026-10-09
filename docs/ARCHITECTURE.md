# Architecture

How the game is put together, for anyone (human or agent) adding to it. The rules behind it are in
`CLAUDE.md`; the design is in `docs/GDD_CHECKPOINT.md`.

## The big picture

```
scenes/main.tscn (scripts/app/main.gd)
  World (Node3D)        runs, bosses and cinematics live here
  Screens (CanvasLayer) the current full screen (title, level select, shop, results, ...)
  Overlays (CanvasLayer) pause menu, revive offer, settings from pause

Autoloads: TouchInput (swipes/taps → input actions), Platform (ads, purchases, leaderboards,
store links, cloud save), Music (music playback), App (state and flow)
```

`App` (`scripts/app/app.gd`) holds the data and moves the player between screens and runs:
title → level select → campaign step (cinematic / level / boss) → results → shop → next step.
After a death: revive offer (item, or rewarded ad on mobile) → run summary → shop → retry (GDD §4).
Screens only call `App` methods; they never change state themselves.

## A run

`App` builds a `RunContext` (level config ready to generate, tuning, loadout, attempt) and starts a
`LevelRun` (`scripts/run/level_run.gd`), which generates the layout and builds a `RunWorld`. A boss
fight is a run too: its context carries the boss, and LevelRun builds the world on the boss's arena
and hosts its `BossEncounter` (see Bosses).

Campaign, retries/replays, endless and campaign debug starts (`--level`/`--boss`) first prepare
the world in `LevelRun.State.READY`, with processing/HUD/touch input held, then show
`LevelIntroScreen`. Prepared collision objects stay registered while processing is disabled
(`DISABLE_MODE_KEEP_ACTIVE`, restored on PLAY), so the first frame cannot lose the boss's floor.
PLAY calls `App.begin_run()` / `LevelRun.begin()` on that same world; Back
discards it without a run result or consuming hints. Quick play still starts immediately without hints.
`HintDirector.setup()` collects unseen catalog hints as `intro_hints` (`Array[Dictionary]`, each
`{id: String, text: String}`), using actual layout triggers, boss-id routes and actual boss pickups
(standard armor; the test boss also has its configured bonus). No unrelated shield/grapple hints
are added to campaign bosses. Campaign `feature_ages` puts this level's introduced mechanics/enemies
first (bosses lead with their own boss/route hints), preserving catalog order within each group.
Older unseen encounters in this layout follow:
they remain new to the player after skipped pages, replays or disabled hints. The lane-control
primer belongs to the first campaign level, not every later level/boss; absent features (including
removed Golden octodogs) never qualify.
It never listens to runtime spawn/route events or emits mid-run hints. Action tokens still use
rebound keys or touch gestures; Settings > Hints still hides them. The intro displays one hint per
page with a counter and PREVIOUS/NEXT buttons (click/touch and Tab/SELECT accessible). Left/right
(`move_left`/`move_right`, including rebindings) page without wrapping; boundaries disable the
corresponding button. Paging is consumed before GUI focus/PLAY and gameplay, including releases
and key repeats (repeats do not page). Other menu navigation retains its usual behavior.
`hints_presented(entries)` on PLAY includes only pages visible for a frame, deduplicated;
`acknowledge(entries)` accepts only selected entries and then records `hint/<id>`
once per profile and App saves immediately. Preparing or backing out does not mark hints seen.
Unvisited pages remain available on retry/replay. The screen's `hints`/`hint_list` and presentation
signal remain the presentation contract. HUD checkpoint notices remain run feedback.

```
RunWorld (scripts/run/run_world.gd)       one run's gameplay world; everything shares it
  Track      TrackBuilder: floor/hull collision, obstacles (fences, wall fences, signs), triggers (pads,
             ramps, speed pads), zone doodads, floor cuts (FloorCut: a lane's floor that turns into a hole
             during play), built in 40 m chunks around the player; the zone skin decorates it
  Player     movement on floor, walls and ceiling; protection; receive_hit()
  Boss       BossEncounter, in a boss fight only: the fight and the boss's pattern (its parts are
             enemies, under Enemies)
  Enemies    EnemyDirector: spawns layout enemies as the player approaches, retires them
  Projectiles ProjectilePool: every shot, pooled and swept
  Credits    CreditField: every credit as MultiMesh instances; pickup and magnet; place() adds credits
             during a run (The House's jackpot fountain), pooled: a slot collected or passed is reused
  Pickups    PickupField: armor, shield and grapple pickups a boss offers, placed fairly, pooled
  Effects    RunEffects: particle bursts, debris, glowing lines, camera-shake and hit-stop requests,
             and the shared impact spectacle (kills, blocked hits, hard landings, stomps)
  Score      ScoreKeeper: level score, credits, kills, bonuses, stats, and what thieves hold
  Sounds     PlayerSfx: non-positional sounds (RunWorld.play_sfx / play_sfx_at)
  Powerups   PowerupController, created if scripts/powerups/powerup_controller.gd exists
```

The highest world-credit denomination is **100** (`LevelGenerator.DENOMINATIONS` and
`CreditField.LOOKS`): a taller, flat-crowned ice-white cut gem with ice-blue facets, dark navy
edge contrast and a steady dark girdle. Its opaque unshaded material stays readable without bloom
in Compatibility and against bright as well as dark skins; it does not pulse or flash. The 1/5/25
looks, values, placement, pickup reach and magnet rules are unchanged. All 100-credit instances
still share one mesh surface/material, including credits placed during a run.
`tools/showcase/credit_review.tscn` reviews the real field at gameplay-camera distances with
`--skin=<skin id> --reduced --shot=res://build/credits/<name>.png`; `--baseline` shows the previous
100-credit look. `--all --reduced` captures both looks in all nine skin resources in one run
(create `build/credits/` first). The scene disables bloom and includes floor, wall and ceiling credits.

`LevelRun` adds the camera (`RunCamera`), the speed lines (`SpeedLines`), the HUD (`RunHud`) and, in
debug builds, the debug HUD and the F6 tuning panel. Quick play (`--quick`, or any of `--god
--seed=N --lanes=N --difficulty=X --features=a,b --full-loadout --nofall --skin=<name> --speed=N
--thief`) restarts on death like the grey box did.
A campaign level runs at its zone's speed (Pace, under The generator): `App` gives the run the level's
movement tuning (`LevelConfig.movement_for`), and `RunWorld.build` and the generator ask the same, so a
level is always built and played at one speed; a campaign boss fight runs at its zone's speed the same way
(E1f: `Campaign.configure_boss`, Bosses); quick play (a boss's too) and the tests run at the base
`MovementTuning.run_speed` (`--speed=N` sets quick play's). F6's Movement section changes the run's copy
live, and its Save leaves the base run speed alone when the run's comes from its level (the section's
`keep` list, `TuningPanel`).
`--level=<step id>` plays a campaign step with the full flow and takes `--lanes`, `--god`, `--nofall`
and `--full-loadout` for reviews; `--boss=<boss id>` plays a boss fight (a zone's boss with the full
flow, such as `--boss=city_boss`; any other, such as the test boss, or a zone's boss still being built
(`BossDef.preview_scene`), as quick play) and also takes `--phase=N`. Command-line starts work in debug
builds only, so a release build can't skip progression or farm credits with them.

Physics order each frame: RunWorld (builds chunks, spawns enemies) → Player (moves, checks hazards
and triggers) → the boss's pattern (a boss fight) → enemies → projectiles → credits → pickups →
power-ups.

### Speed effects and spectacle (G2, the owner's playtest, September 30, 2026)

"The runner felt slow even though the levels were hard" (GDD §3): G1 raises the run's actual speed;
these effects make speed and impact *feel* fast and heavy, without changing what the game decides.
Every number is `SpeedFxTuning` (`scripts/run/speed_fx_tuning.gd`, `data/tuning/speed_fx.tres`, F6
"Speed effects").

- **The camera's field-of-view kick** (`RunCamera._fov_kick`) widens with `Player.speed` above
  `fov_reference_speed` - the zone's base (G1) and any ramp, speed-pad or dash boost, since Player
  already folds them all into `speed` - eased in with `fov_attack_rate` and out with the slower
  `fov_release_rate`, so a boost's end reads as a settle rather than a snap.
- **The lane-switch lean** (`RunCamera._lane_lean`) banks the camera a few degrees toward
  `Player._switch_dir` while a lane switch is under way, through `look_at`'s `up` vector (a rolled
  camera, not a rotated one, so it never fights `ceiling_limit`).
- **Speed lines** (`SpeedLines`, a CanvasLayer next to the camera and the HUD): a fixed, angle-free
  comb of pale vertical streaks on a canvas_item shader, masked clear within `lines_safe_width` of
  screen centre so a lane's centre - where a hazard's telegraph is read - is never touched, and
  eased in strength between `lines_min_speed` and `lines_full_speed`. The streak pattern is a
  stable per-column hash, never re-randomised, so there is nothing in it to flicker: it honours
  Reduced flashing by construction, and stays cheap enough for the Compatibility renderer (one
  fullscreen shader pass, no particles).
- **Impact**: `RunEffects.setup()` (called once by `RunWorld.build`) wires the shared spectacle to
  the run's own signals, so no enemy or power-up file needs its own copy:
  - a **shake** on a hard landing (`Player.movement_event` `land`, only past
    `land_shake_fall_height` of fall - RunEffects tracks the player's own peak air height itself,
    since `land` fires after `Player.vh` is already reset), a **stomp** (`stomp`, plus hit-stop), and
    every **kill**, whatever the cause (`EnemyDirector.enemy_defeated`: a small, consistent shake and
    hit-stop, so a bigger cause-specific shake an enemy or a power-up already plays - a dash kill, a
    boss hit - is never drowned out, since `shake()` and `freeze()` both keep the stronger of two
    overlapping requests, never their sum);
  - a **spark burst** (`RunEffects.burst`) and now also **debris** (`RunEffects.debris`, fewer,
    heavier, tumbling chunks) on every kill, and a spark burst in the item's own colour
    (`PlayerSuit.GLOW` / `PlayerSuit.SHIELD`, never a hazard colour) when the armor or the shield
    blocks a hit (`armor_hit`, `armor_break`, `shield_break`); `WeaponFx.kill_flash` adds a brighter,
    weapon-tinted flourish on top of a weapon kill specifically (`WeaponPowerup._on_enemy_hit`);
  - **hit-stop** (`RunEffects.freeze`, a few hundredths of a second on a kill or a stomp): while
    `RunEffects.freeze_left` counts down, `RunCamera._process` skips `_update` entirely, holding the
    camera's exact transform and fov while the player, the enemies and the generator keep moving at
    their own, real delta underneath. It **never touches `Engine.time_scale`** (`SlowTimePowerup`
    owns that for its own, very different, deliberate slow-down) or pauses anything, so a seeded run
    plays out identically whether or not it fires (`test_speed_fx`: the same actions on the same
    layout, with and without a forced freeze, give the same distance, lane and event log). Freezes
    never stack or chain (task PERF1): requests in the frame a freeze begins keep the longer one, and
    one asked for less than `SpeedFxTuning.freeze_gap` (0.3 s) after the last one began is left out,
    so a run of kills never holds the camera again and again (Smooth frames, below).
  - **Screen shake** (Settings) scales every shake and hit-stop through `RunEffects.shake_scale`
    (`shake()` and `freeze()` both no-op at 0); the field-of-view kick, the lean and the speed lines
    stay on regardless, since none of them snap or strobe.

### Smooth frames (task PERF1, the owner's report, October 2, 2026)

"The overall performance of the game is getting worse. Lag spikes are more common." Measured, the spikes had
five sources; every fix leaves what the game decides alone (a seeded run's event log is the same before and
after, run by run: `frame_times.gd --log`, and `test_perf`).

- **An enemy type's first spawn** (the largest frames on the CPU, already there before the playtest work): it
  loaded and compiled the type's scripts and built the look its kind shares in that frame, 120 to 290 ms for a
  cyborg or a window cyborg on the dev machine (the Golden look the most), 30 to 70 ms for a hover truck, a
  Barnacle Turret, a screech or a drone. The director readies every type the level brings during the load
  (Enemies, Readied with the level).
- **Shaders first drawn mid-run** (the GPU side; there are more of them since the playtest work: doodads,
  wall fences, the Resonator, the Barnacle Turret, the weapon's effects): 4 to 16 shaders a level were first
  drawn after the load (`frame_times.gd --shaders`), each a long frame on a real renderer while it compiles
  them (Compatibility, the web demo) or builds their pipelines (Forward+: 48 surface and 35 specialization
  pipelines during 25 s of Gangland 3; under xvfb's software renderers a first screech, generator, missile or
  window cyborg took 0.3 to 3 s). `ShaderWarmup` (`scripts/run/shader_warmup.gd`; LevelRun adds it whenever the
  game renders) draws one copy of each look the level may show later, too small to see in front of the camera,
  for the level's first two drawn frames: every material on the run's hidden nodes (pools, the weapon's
  effects), the effects' glow, one look of each enemy kind (`EnemyDirector.warm_looks()`, every part shown) and
  each track piece the zone skin dresses (fences in each state, wall fences, a sign, pads, ramps, speed pads,
  ceilings, doodads, gap edges, the finish line). It keeps the samples' materials until the next level's
  stage, so their shaders stay built for a look first met later. After it no shader on Gangland 3 is first
  drawn mid-run. The track pieces are dressed on hazards and trigger areas made once a process and never
  freed while the game runs (out of the tree; their looks move onto plain nodes in the stage): **a warm-up
  never frees a physics object**, since the next one made takes its place in the physics server's tables,
  which can change the order of contacts in a frame (two throwaway hazards made and freed at a boss fight's
  load moved one kill in Hostile Takeover's seeded event log by a frame; made and kept, they changed
  nothing).
- **Hit-stops** (G2's brief freeze on every kill and stomp): none in the build before the playtest work, now 4
  to 24 a level (about 6 a minute with a full loadout). Each holds the camera still for three frames while the run
  goes on, so the view jumps 1.0 to 1.25 m when it lets go: on screen, exactly what a dropped frame looks like.
  They never stack or chain now (`freeze_gap`, Speed effects above); whether every kill should keep one is the
  owner's call (`docs/questions/perf1.md`). The frame graph marks the frames a hit-stop holds.
- **Chunk builds**: a chunk's build is almost all the zone skin's dressing (1.4 to 3.7 ms a chunk on the dev
  machine, `wall_section` the most; the collision, hazards, triggers, doodads' bodies, wall fences and cuts 0.1
  to 0.3 ms), all in one frame every 1.6 to 1.9 s, and up 5 to 15% since `a5e691b` in the Marketplace and
  Corporate (the Marketplace's citizens are about 0.7 ms of its 3.8 ms a chunk, `Settings.citizens_enabled`
  off). `TrackBuilder.dress_budget_usec` (LevelRun sets it from
  `PerformanceTuning.chunk_dress_budget_ms`, 1 ms, F6 "Performance") builds a chunk's gameplay nodes in its
  frame as before and queues the skin's calls, which `update()` makes in order, about the budget a frame (at
  least one call), finishing a chunk's whatever the time once the player is `DRESS_BY` (120 m) from it.
- **Boss props**: every target circle built a torus mesh and a boss's first row of fences built the kit's
  fence look in its frame (3.8 ms for The House's first lightning row); `BossProps` shares rings by radius, and
  when the game renders the shader warm-up's fence samples build the skin kit's fence look during the
  fight's load (headless runs, the measuring tool's, still show that first row; a later fence costs about
  0.2 ms, a Barnacle Turret's later spawn 0.2 to 0.3 ms: neither shows among the slow frames). The House
  also re-plans a strike waiting for fair lanes every frame (a route search per candidate lane set,
  `TheHouseAttacks._try_strike`) for up to `strike_wait`: 5 to 10 ms frames for about 0.3 s on the dev
  machine in the preview fight's runs (none in the finished fight's 240 s run). Re-planning less often
  would change when strikes come, so it's left to a task on The House.

Ruled out by measuring: physics bodies (a chunk's are 0.1 to 0.3 ms in all), effects (bursts, debris, lines,
coin streams and shots are pooled; the speed lines are one canvas pass), and the per-frame checks (on a
quiet machine the median frame is about 1 ms headless, up 2 to 13% since `a5e691b` with the faster, busier
levels; the 99th percentile up 10 to 35%).

**Measuring.** `FrameMonitor` (`scripts/run/frame_monitor.gd`) times every frame (its whole time; the game's
work before the renderer draws; its physics steps) and tags it from the run's own signals and a look at its
state once a frame (chunks built and freed, spawns, kills, hit-stops and the frames they hold, bursts, credits,
pickups, sounds, big changes in the tree, objects made, pipelines compiled), so nothing in the game reports to
it. In debug builds LevelRun keeps one, and `FrameGraph` (`scripts/ui/frame_graph.gd`, F7 or `--frame-graph`)
draws its last 300 frames: each frame's time and the game's part, spikes (over 1.6 times the median and 8 ms)
in their own colour, the frames a hit-stop holds, and the latest of both listed with their tags.
`tools/measure/frame_times.gd` plays every level and boss fight headless and reports per run (Review tools);
under xvfb it counts draw calls, primitives and pipelines. `test_frame_times` holds three levels to budgets.

The numbers (`frame_times.gd`, 5 lanes, full loadout, headless on the dev machine, two passes each in a fresh
process, each frame's faster time; CPU times in ms; `a5e691b` (the build before the playtest work, at 18 m/s,
without the Sleep Taker, The House and Hostile Takeover) / today's main (`958169e`) / with PERF1, measured
back to back on a busy machine (other agents' runs: medians about 1.2 ms, about 0.9 ms on a quiet one); The
House is its finished fight, 240 s without a bot, and Hostile Takeover E5b-a's preview, 150 s at 18 m/s; a
seeded run's event log is the same on main and with PERF1 in every run, 19 of 19):

| Run | Median ms | 99th pct ms | Worst ms | Frames > 16 ms | Frames > 8 ms | Load ms | Hit-stops |
|---|---|---|---|---|---|---|---|
| city/1 | 1.13 / 1.19 / 1.20 | 1.92 / 2.67 / 2.57 | 248.9 / 231.4 / 6.2 | 1 / 1 / 0 | 2 / 2 / 0 | 536 / 582 / 824 | 0 / 4 / 4 |
| city/2 | 1.15 / 1.24 / 1.23 | 2.05 / 3.09 / 2.68 | 5.2 / 8.7 / 5.4 | 0 / 0 / 0 | 0 / 1 / 0 | 525 / 644 / 839 | 0 / 8 / 8 |
| city/3 | 1.15 / 1.26 / 1.29 | 2.02 / 3.01 / 2.91 | 270.2 / 231.8 / 7.0 | 3 / 2 / 0 | 3 / 3 / 0 | 665 / 684 / 1033 | 0 / 13 / 13 |
| gangland/1 | 1.17 / 1.25 / 1.24 | 2.27 / 3.23 / 2.99 | 242.4 / 228.0 / 7.0 | 4 / 3 / 0 | 4 / 5 / 0 | 745 / 808 / 1175 | 0 / 14 / 14 |
| gangland/2 | 1.20 / 1.23 / 1.28 | 2.51 / 3.04 / 3.07 | 224.3 / 267.2 / 6.6 | 4 / 3 / 0 | 5 / 4 / 0 | 953 / 934 / 1494 | 0 / 15 / 15 |
| gangland/3 | 1.20 / 1.24 / 1.29 | 2.80 / 3.39 / 3.11 | 225.7 / 205.3 / 6.6 | 5 / 3 / 0 | 7 / 4 / 0 | 1005 / 1170 / 1525 | 0 / 16 / 16 |
| marketplace/1 | 1.20 / 1.29 / 1.34 | 2.60 / 3.58 / 3.73 | 230.2 / 200.3 / 8.5 | 4 / 3 / 0 | 6 / 8 / 1 | 978 / 1202 / 1496 | 0 / 19 / 19 |
| marketplace/2 | 1.18 / 1.27 / 1.28 | 2.26 / 3.62 / 3.65 | 229.6 / 212.7 / 5.7 | 5 / 4 / 0 | 5 / 8 / 0 | 1120 / 1313 / 1966 | 0 / 18 / 18 |
| corporate/1 | 1.18 / 1.21 / 1.25 | 2.65 / 4.03 / 2.97 | 236.7 / 220.4 / 7.4 | 5 / 4 / 0 | 6 / 5 / 0 | 908 / 1680 / 2325 | 0 / 16 / 16 |
| corporate/2 | 1.14 / 1.26 / 1.27 | 2.44 / 3.44 / 3.01 | 280.7 / 242.4 / 7.2 | 4 / 6 / 0 | 5 / 7 / 0 | 1063 / 1354 / 2094 | 0 / 24 / 24 |
| dead_zone/1 | 1.12 / 1.23 / 1.24 | 2.44 / 3.92 / 3.10 | 221.7 / 213.1 / 6.4 | 5 / 4 / 0 | 6 / 6 / 0 | 1046 / 2732 / 3172 | 0 / 14 / 14 |
| dead_zone/2 | 1.15 / 1.23 / 1.22 | 2.47 / 3.77 / 2.93 | 252.0 / 275.2 / 8.2 | 6 / 5 / 0 | 8 / 8 / 1 | 1123 / 1395 / 2077 | 0 / 13 / 13 |
| golden/1 | 1.23 / 1.30 / 1.29 | 2.87 / 3.85 / 3.08 | 74.2 / 63.2 / 7.5 | 5 / 6 / 0 | 8 / 9 / 0 | 1215 / 1683 / 2597 | 0 / 23 / 21 |
| golden/2 | 1.17 / 1.25 / 1.25 | 2.55 / 3.72 / 3.06 | 402.3 / 341.0 / 5.3 | 5 / 6 / 0 | 7 / 11 / 0 | 1352 / 1712 / 2500 | 0 / 19 / 19 |
| golden/3 | 1.19 / 1.28 / 1.28 | 2.83 / 3.82 / 3.05 | 379.6 / 382.7 / 5.4 | 7 / 6 / 0 | 10 / 10 / 0 | 1548 / 2370 / 3111 | 0 / 26 / 26 |
| boss city_boss | 1.32 / 1.40 / 1.39 | 2.83 / 3.29 / 2.85 | 25.8 / 26.7 / 7.6 | 1 / 1 / 0 | 1 / 1 / 0 | 1214 / 1135 / 1081 | 0 / 4 / 4 |
| boss marketplace_boss | - / 1.34 / 1.33 | - / 4.83 / 3.78 | - / 11.5 / 8.2 | - / 0 / 0 | - / 9 / 1 | - / 895 / 1001 | - / 0 / 0 |
| boss dead_zone_boss | - / 1.34 / 1.32 | - / 3.78 / 3.01 | - / 6.9 / 6.6 | - / 0 / 0 | - / 0 / 0 | - / 831 / 833 | - / 3 / 3 |
| boss corporate_boss | - / 1.87 / 1.95 | - / 3.99 / 4.16 | - / 244.6 / 8.6 | - / 2 / 0 | - / 3 / 2 | - / 636 / 873 | - / 59 / 58 |
| all | | | | 64 / 59 / 0 | 83 / 104 / 5 | | 0 / 308 / 305 |

The first spawns' and first looks' costs now come during the load (a fresh process pays them once: a
session's later levels find them built), so a level's first frame takes 0.2 to 0.9 s longer on the dev
machine; whether a level should open behind a loading card is an open question (`docs/questions/perf1.md`).
The median frame is up by about 0.03 ms in debug builds (the frame monitor itself; release builds have none).
Under xvfb (25 s of a level; software rendering, so the counts mean something and the times only show the
shape), 12, 8 and 9 shaders were first drawn after the load on Gangland 3, Marketplace 2 and Golden 2 before
(Forward+ built 35 to 48 surface and specialization pipelines mid-run; the worst mid-run frames were 3.1, 2.9
and 2.1 s on Forward+ and 0.75, 0.36 and 0.59 s on Compatibility) and none after (0.11 to 0.38 s); the median
draw calls (248 to 279 a frame), primitives (44,000 to 49,000) and objects (336 to 404) are the same, the
most in a frame higher by the warm-up's samples in the level's first two frames.

## Data (tunables live in data, CLAUDE.md principle 7)

| File | What |
|---|---|
| `data/tuning/movement.tres` (`MovementTuning`) | the base run speed (quick play, tests; `REFERENCE_SPEED` and `pace()`, see Pace), jump, walls (and the blocked entry's bump), ramps and speed pads (their boosts share one fade), ceiling, piece sizes, zone doodads' sizes and push, camera, touch |
| `data/tuning/game_rules.tres` (`GameRules`) | lanes per device, death share, invulnerability, the armor (the free armor's hits and wait, the upgrade's per tier, a pickup's extra hit), the window after a theft, stomp, whether big attacks take turns, score, economy, stars |
| `data/tuning/powerups.tres` (`PowerupTuning`) | weapon tiers, claws, dash, magnet, slow time |
| `data/tuning/pickups.tres` (`PickupTuning`) | in-run pickups: where they appear, taking them, the charge cap, the look |
| `data/tuning/feature_recency.tres` (`FeatureRecency`) | the campaign's recency curve: how a level's pick weights follow how recently the campaign introduced each feature |
| `data/tuning/wall_fences.tres` (`WallFenceTuning`) | wall fences (B5): how often, how they pulse, their introduction, and the fairness margins (their sizes are the movement tuning's) |
| `data/tuning/wall_gaps.tres` (`WallGapTuning`) | side wall gaps (Zone 2 on): spacing (easy/hard), jitter, length, the share on both walls, and the keep-out margins, all in seconds at the level's run speed |
| `data/tuning/performance.tres` (`PerformanceTuning`) | smooth frames (PERF1): how long a frame may spend dressing built chunks, and `test_frame_times`' frame-time budgets |
| `data/enemies/<type>.tres` (`EnemyTuning` subclasses) | per-enemy numbers, early/late pairs for campaign scaling |
| `data/shop/catalog.json` | shop items, tiers and prices (the armor's texts take `{hits}` and `{seconds}`, filled from `GameRules` by `ShopScreen.item_text()`) |
| `data/campaign/campaign.tres` → `data/zones/*.tres` → `data/levels/*.tres` | the campaign; each zone's run speed (`ZoneDef.run_speed`, a level may set its own), each level's pacing, fill pass, zone doodads and credits |
| `data/bosses/*.tres` | bosses (`BossDef`: slot, health, phases, arena, rewards, par times, armor rule), and a boss script's own tuning (`<id>_tuning.tres`) |
| `data/cinematics/*.tres` | cinematic slots (`CinematicDef`: each slot's scene), the arrival flyover's numbers (`arrival_flyover.tres`, `ArrivalFlyoverTuning`) and the City outro's (`city_outro_tuning.tres`, `CityOutroTuning`) |
| `data/patterns/*.json` | generator patterns (every file in the folder is loaded) |
| `data/skins/*.tres` | zone looks |
| `data/audio/*.tres` | sound and music libraries |

Any `@export_range` number or bool on a resource registered with the tuning panel shows up under F6.

## Damage and interactions: one place (CLAUDE.md principle 8)

- **Hazards declare, `DamageRules` decides.** A `Hazard` (`scripts/world/hazard.gd`) is an Area3D on
  the hazard layer with properties: `is_electrical`, `is_enemy_attack`, `is_solid`, `dash_passes`,
  `steals_share` (a thief's touch, below), `enemy` (owning enemy or null) and `part` (`&"body"`,
  `&"top"`, `&"weak_point"`, `&"attack"`).
- The player checks contacts each frame (a swept shape query) and calls `Player.receive_hit(hazard,
  stomping)`, which asks `DamageRules.resolve()` and applies the outcome: `IGNORE`,
  `BLOCKED_ARMOR`, `BLOCKED_SHIELD` (then ~1 s invulnerability), `KILL`, `DEFEAT_ENEMY` (claws or
  dash), `STOMP` (enemy defeated, player bounces), `ROBBED` (a thief's touch, below). Nothing else
  hurts the player.
- **Thefts: the robbed hit** (GDD §9.12, the Tithe Collector; task B6 built the mechanism, task C5 the
  collector). The game's first non-lethal hit:
  - *The rule.* A hazard with `steals_share` > 0 resolves to `ROBBED` instead of hurting: after the
    dash, a stomp and the claws (which catch the thief: `DEFEAT_ENEMY`, `STOMP`), before everything
    that protects from harm. It's no hit, so armor, the shield, the invulnerability window and god mode
    don't stop it and nothing is used up; only the moment after a theft does (`Defense.theft_immune`:
    `Player.theft_immune_left`, `GameRules.theft_grace`), so one touch robs once. The player emits
    `robbed(hazard)` and the `robbed` event (its sound). DESIGN-TBD (`docs/questions/b6.md` 1, 2).
  - *The books* (`ScoreKeeper`). `rob(thief, share)` takes the share of the run's credits as they stand
    (collected, less what thieves hold), rounded down, and the thief holds it (`held_by`); a second
    theft takes a share of what's left. The level score never drops (GDD §7: never spent), so a theft
    never costs a star or a leaderboard place. `hold(thief, value)` is for credits a thief takes off the
    track before the player gets them (C5's collector sucks them up): it holds them, and the stars' best
    score (`max_credit_score`) leaves them out while it does. Any defeat of a thief is a catch: the
    director's `enemy_defeated` calls `pay_out(thief, enemy.jackpot_credits)`, which pays everything it
    holds plus its jackpot straight into the run's credits for a player-attributed defeat (with the
    `jackpot` sound; what it took off the
    track and the jackpot count as collected, score and best score). A thief must be spawned through the
    director. One that leaves uncaught keeps it: `stolen_kept()`, which `RunResult` takes out of the pay
    (`credits_stolen`; completion pays what's left plus the bonus, a death or a quit 20% of what's left)
    and the results screen shows as "Stolen". Signals `stolen(amount, thief)` and
    `recovered(amount, jackpot, thief)`; stats `thefts`, `credits_stolen`, `credits_recovered`,
    `jackpots`, `stolen_kept`. DESIGN-TBD (`docs/questions/b6.md` 3, 4).
  - *The feedback.* The HUD's credits count down in the loss colour, dipped (`CreditCounter.drop_on_loss`,
    the theme's `font_loss_color`: the violet accent, no hazard colour and not the warning red), with a
    "Robbed −N" pop-up; a payout pops "Recovered +N" and "Jackpot +N". Never the centre message, where a
    death shows. `RunEffects.coin_stream` flies coins in the credit look from the runner to the thief,
    and out of a caught thief into the runner (numbers in `SpeedFxTuning`, "Thefts"); no shake, no
    hit-stop, nothing flashes, and the loss look is a single fade, softer with Reduced flashing. Sounds
    `robbed` (coins tumbling away) and `jackpot` (a slot machine's payout), in `sfx_bank_ui.gd`.
  - *A thief declares* `Hazard.steals_share` on its hitboxes and `Enemy.jackpot_credits`, from a
    `ThiefTuning` (`scripts/enemies/thief_tuning.gd`: `steals_share` 0.25, GDD §9.12; `jackpot_credits`).
    The stand-in thief (`scripts/enemies/stand_in_thief.gd`, `data/enemies/stand_in_thief.tres`; never in
    the campaign) is a plain gold block that crosses the lanes ahead of the runner, planned to be over the
    lane it aims at when the runner arrives; one hitbox, its stomp part, so from above it's a stomp and
    any other touch robs; after a theft it makes off ahead and up (`Hazard.contacted`). Quick play's
    `--thief` sends one after another (`StandInThief.start_review`, loaded by path from `LevelRun`), its
    numbers in F6, and starts the runner with a purse (`review_purse`, 400) so the first theft has
    something to take.
  - **The Tithe Collector** (GDD §9.12, task C5, from Corporate 2, skipping the Dead Zone, back in the
    Golden Zone): `scripts/enemies/tithe_collector.gd`, `tithe_collector_tuning.gd` (extends
    `ThiefTuning`), `data/enemies/tithe_collector.tres`, one pattern
    (`data/patterns/tithe_collector.json`, `"requires": ["tithe_collector"]`, placed many times across
    a level like the drone's, each its own approach); it's out of `LevelConfig.PLANNED_FEATURES`. A
    small, fast gold drone with a collection plate (plain metal, never glowing, unlike a heli drone: no
    rotors, and anti-grav pads don't affect it, since it never connects to `Player.movement_event`).
    *Approach*: like the stand-in thief (task B6), it appears `start_ahead` ahead of the player and
    closes in at `approach_speed`, slower than the runner, low to the floor the whole way in, so an
    ordinary run brings it into stomp and dash reach without a boost; a player who leaves its lane
    before it arrives is never touched. It sets `steals_share` on its one hitbox and `jackpot_credits`
    on itself from its tuning, and flees ahead and up on a theft (`Hazard.contacted` with `ROBBED`),
    exactly like the stand-in thief. *Weaving* ("the most dangerous lanes"): every `weave_interval` it
    counts gaps, fences, floor cuts and other floor enemies in each lane over `weave_lookahead` ahead of
    its own track position and eases toward the lane with the most (ties keep its current lane; with
    nothing dangerous ahead it settles over the player's own lane) — not the player's lane outright, so
    catching it means following it into the risk; it's a body to touch, not a hazard, so this can never
    make a lane unfair, it only ever changes where the 25% risk or the catch's reward sits. *The
    vacuum*: `CreditField.take_near(lane, at, reach)` is the small hook (hide an idle floor credit in
    `lane` within `reach` of `at` and return its value and position, or `{}`); every `vacuum_interval`
    the collector calls it for its own lane and position, `world.score.hold(self, value)`s what it
    gets, and flies it in with `RunEffects.coin_stream` for the visible stream GDD §9.12 asks for. *The
    approach cue*: not a hazard warning (touching it isn't an attack), but still noticeable: a smug
    chuckle plays for everyone to hear (`world.play_sfx`, like the Resonator's chime) as soon as it
    exists. It reports no big attack (`is_major_attack_active` stays false): it isn't an attack, so it
    never takes a turn.
- **A stomp on the ceiling** (C1): a hitbox that hangs from a ceiling (`Hazard.upside_down`, the
  Barnacle Turret's crown) has its top facing down, toward a rider on the ceiling, who stomps it by
  dropping back onto it after a jump (`Player._is_stomping`: on the ceiling, falling back toward it with
  the feet within `GameRules.stomp_tolerance` of the hazard's `bottom_y()`). Only such hitboxes can be
  stomped from the ceiling; on the floor nothing changed.
- Falls aren't hazards: the Player handles them (the grapple hook saves one fall).
- **The armor** (GDD §4 and §8, owner's playtest, September 30, 2026) is a state with rules of its own,
  `DamageRules.Armor`: up with its hits left, or broken and coming back. Every run the profile starts
  (levels, boss fights, retries, quick play, endless, the web demo) carries it free (`Loadout.armor`),
  and the shop's armor is an upgrade to it (its tier, `tiers[&"armor"]`; the equip toggle switches only
  the upgrade off). RunWorld makes the run's armor (`Armor.create(rules, tier, carried)`) from
  `GameRules`' Armor group: the free armor's hits (1) and wait (30 s), and each tier's (placeholders
  2/30 s, 2/25 s, 3/25 s, 3/20 s: the tiers alternate one more hit and a shorter wait). The Player holds
  it (`armor_state`; `armor` is its hits left, and setting it, for tests and tools, puts that many hits
  up) and applies what resolve() says: a blocked hit takes one (`block()`) with the usual
  invulnerability (event `armor_hit`), the last one breaks it (`item_used(&"armor")`, `armor_break`),
  and from the Player's physics step its wait runs (`tick()`: the run's clock, so a pause or a death
  stops it, the same at any frame rate) until it's back whole (`armor_back`). A revive brings it back
  whole (`restore()`); an armor pickup (`take_pickup()`) does too, at once, and on whole armor adds a
  hit, up to `armor_pickup_extra_hits` over its count. `armor_changed` tells the HUD and the player
  model; `ScoreKeeper` counts every blocked hit. A bare `Loadout` (tests, tools) has no armor until a
  pickup gives it. DESIGN-TBD (`docs/questions/g3.md`): worn armor gets nothing back until it breaks;
  the pickup's extra hit; the revive; that the free armor can't be switched off.
- Enemy shots go through `ProjectilePool.fire_enemy()`; the pool sweeps each shot against the
  player's hitbox and calls `receive_hit`, so armor, shield, invulnerability and the dash all apply.
- **Blocked moves bump, never hurt.** A lane switch into a solid side (a lane blocker: the hover
  truck's, a boss's block) and a wall entry where the wall is blocked (a sign, or a wall a boss takes
  away; GDD §3) move the player out toward it and back (`Player._start_bump`) with the clank
  (`lane_blocked` / `wall_blocked`). The player stays in their lane and can act meanwhile; collision is
  unchanged. The wall's bump (`wall_bump_distance`, `wall_bump_time`) stops short of any hazard or wall
  blocker in its way, so a sign that reaches down to the player stops it at its face, and the model
  leans away from the wall on the way back. On a ceiling over fewer lanes (a narrow ceiling, GDD §3) a
  move toward a lane it doesn't cover is blocked the same way (`ceiling_blocked`, the same clank;
  `Player._bump_ceiling_edge`, a bump that stops short of the ceiling's edge). The player asks the
  ceilings themselves: a ray on the hull layer over the middle of each lane (`_ceiling_over`), so the
  track's ceilings and a boss's (`BossProps.ceiling`) hold the player in alike, and a pad lands the
  player in its own lane even if a switch was under way (`_hold_to_pad_lane`).
- **Wall fences are fences** (task B5; GDD §9.1: "the same rules as floor fences"). A wall fence's field is
  an electrical Hazard like a floor fence's (TrackBuilder._build_wall_fence), so DamageRules lets armor, the
  shield and the dash through and never claws, and weapons never see it (it's no enemy). It's on the
  hazard layer only, never a wall blocker: the wall is open to enter, and a live field just hurts. Its
  field reaches out from the facade over the wall runner's body (on a wall the hurtbox lies along the wall
  and reaches out by its height, Player.hurtbox_aabb) and stops short of a floor runner in the middle of
  the outer lane (WallFencePlan.reach), so a wall runner within its band is hit while it's on, a floor
  runner beside it never is, stepping onto the wall into a live one is a hit, and a blocked entry's bump
  never reaches into one (Player._bump_room). The Player needed no change.
- **Zone doodads push, never hurt** (GDD §3, owner's playtest September 30, 2026; task G5). A doodad is
  no hazard: the track builds it as a body on a layer of its own (`TrackBuilder.LAYER_DOODAD`) that is
  also a lane blocker, with a standable top on the floor layer (`_build_doodad`). On the floor, the
  player meets its front with the visual body (sliding, its slide height; from just above the feet)
  swept ahead by the moment a shove needs to clear its side (`Player._check_doodads`,
  `_push_clear_seconds`), so the body never sinks into it, and is pushed into the neighbouring lane over
  `doodad_push_time` (`_start_push`: the lane switch machinery with a sharper ease, `_push_x`), with the
  `doodad_push` event: the thud (`doodad_push.wav`), a small shake (`SpeedFxTuning.push_shake_*`) and
  the runner leaning into it. Head-on the push goes to the doodad's side (seeded by the generator, the
  same on every attempt); a front corner caught mid-switch pushes back the way the player came (never
  through the doodad); a side with no room (the track's edge, a lane blocker there) gives way to the
  other. A jump or a slide into one is pushed the same way (doodads are too tall to jump), a switch into
  its side is a blocked move (above: the clank and the bump), and a player who comes down on its top
  lands on it and runs along it. It costs nothing: DamageRules never sees it, the run's speed stays,
  and shots and weapons pass through it. Wall runners and ceiling riders never meet one (the generator
  keeps them out of the outermost lanes and from under ceilings).

## Enemies

An enemy type needs only files of its own; nothing shared is edited:

| File | Purpose |
|---|---|
| `scripts/enemies/<type>.gd` | the `Enemy` subclass (found by name) |
| `scripts/enemies/<type>_tuning.gd` | its tuning class, extending `EnemyTuning` |
| `data/enemies/<type>.tres` | its tuning values (spawn lead, score, health early/late, floor use, and its own numbers) |
| `data/patterns/<type>.json` | patterns that place it, each with `"requires": ["<type>"]` |
| `scripts/enemies/<type>_rules.gd` | optional generator rules: `static func apply(gen: LevelGenerator)` |
| `tests/suites/test_<type>.gd` | its tests |

`Enemy` (`scripts/enemies/enemy.gd`) declares properties (`immune_to_weapons`, `is_host`,
`claw_immune`, `stompable`, `dash_kills`, `is_boss`, `is_obstacle`, `is_swarm`, `max_health`,
`score_value`) and provides `add_hitbox(part, size, offset, attack)`, `add_lane_blocker(size, offset)`,
`take_damage()`, `defeat(cause)`, `retire()`. Subclasses override `_build()` (visuals, hitboxes,
properties), `_tick(delta)` (behaviour), and optionally `_on_defeated`, `should_retire`, `aim_point`,
`hit_radius`. A layout entry is `{type, at, lane, side, seed, params}`; `rng` is seeded from it, so
every attempt at a seed plays out the same way. Setting `is_host` also sets `immune_to_weapons`
(GDD §9.7, decided September 26, 2026): a host is immune to every kind of weapon damage, direct or
splash, the same way a fence generator declares its own immunity (GDD §9.1), so no targeting, no
damage and no health bar; only a stomp, the claws or the dash still kill it, with the host bonus.
Every attack needs a visual **and** audio warning before it can hurt (CLAUDE.md readability rules).
**Enemy charge contacts** (owner revision, October 3, 2026): Octodog and Buzz Overdrive active charges
use one shared swept-box contact helper on `Enemy`, against live physical enemy hitboxes rather than
lane labels or detached attack effects. Each victim is hit at most once per charge through
`take_damage(..., &"enemy_charge")`; bosses and weapon-immune enemies retain their immunity.
`EnemyDirector.enemy_defeated` still drives lifecycle/effects, but `ScoreKeeper` ignores that cause:
no player kill count, bonus or thief jackpot/recovery is awarded for an NPC collision. The one exception
is an enemy that declares `charge_bait` (task C6, the Enforcer Truck, GDD §9.13): weapon-immune, it is
still hurt by a charge's contact (`take_damage` lets `&"enemy_charge"` through, `_hurt_charge_contacts`
keeps it as a victim), and `ScoreKeeper` counts that defeat as the player's kill (a bait), with its score.
Hosts and fence generators don't declare it, so charges pass them by as before.
**Readied with the level** (task PERF1): `EnemyDirector.warm_up()` (from `setup()`, during the load) loads
the script and tuning of every type the layout names, and for a type whose script has a static
`warm_up(world: RunWorld, entry: Dictionary) -> Node` builds one look of each kind (type, skin, host:
`warm_key()`; a zone's skin counts by its resource, since the Golden Zone and the Golden Palace share a zone
look but not their statue kits) and frees it, once a process: what a type's first spawn used to do in its
own frame (compiling its scripts and building the meshes, materials and shaders its kind shares; up to
290 ms for a cyborg). It keeps the look's materials for the process (`ShaderWarmup.materials_of()`): the
engine frees a standard material's shader with the last material using it and generates and compiles it
again for the next, so a kind that makes its own material at each spawn (a Gilded Sentinel's eyes) paid
about 1 ms (and a compile on a real renderer) at every spawn with none of its kind left. The hook builds
the visual model only (never a physics object: see Smooth frames), as `entry`'s would be, outside the tree,
with every part the enemy may show later
(a muzzle's charge, a lunge line, a wave), since `ShaderWarmup` draws the same looks once during the load
(`warm_looks()`, A run). A type whose enemies bring others into play names them with a static
`brings(entry: Dictionary) -> Array[Dictionary]` (a host cyborg's Bad Dream). The cyborg, window cyborg,
screech, Octodog, Resonator, Barnacle Turret, Bad Dream, fence generator, Buzz Overdrive, Gilded Sentinel
(its statue's frames for both walls, its eyes, its cut marks' shader) and Enforcer Truck (its model with
every rider, its light bar's and floor lights' states, its warning line) have hooks, and a boss fight names the
enemies it brings itself with `BossEncounter.warm_enemies()` (the Floating Head's dropped cyborgs, the Sleep
Taker's generators); a new enemy whose first spawn builds anything costly adds one, and a kit keeps the
shaders it loads (a static cache, as the kits do) rather than loading them per spawn (`test_perf` checks
every hooked kind is readied and nothing of it stays).
Enemy fire uses the pool's red "enemy_*" looks in every zone. `world.skin.enemy_variant` picks the
zone look: the cyborgs (window cyborgs and hosts too) dress in the zone variant
`CyborgSuit.look_for()` finds for it (see Zone skins for each zone's value, and Characters), and the
other enemies weather by it (`&"scavenger"` weathered, any other value the clean `&"city"` look).

A level uses an enemy only if its `features` list has the type's name (GDD §6: one new thing at a
time), from the feature's start if the level gives it one (The generator). Quick play can add
features: `./play.sh --features=cyborg,drone`. The campaign already lists the enemies still to be
built under the names their tasks must use (`LevelConfig.PLANNED_FEATURES`: `barnacle_turret`,
`resonator`), so a new enemy's own files are all it takes to bring it into its levels.

Built so far: cyborg (with its panic variant and hosts), window cyborg, fence generator, hover
truck, Octodog, sewer screech (manholes, and wall vents; `screech_vents` is wall vents only, for zones
whose floor has no manholes; its body, `ScreechModel`, also comes at a lower detail for crowds,
`crowd_mesh()`, the same parts and colours in about a third of the triangles: the Sewer Swarm's),
heli drone, the Cyborg's Bad Dream (released by a killed host, spawned by the director at run
time rather than placed by the generator), the Resonator (GDD §9.10, the Golden Zone: a golden
broadcast spire hovering far ahead whose red waves roll along the floor across every lane; its model,
`resonator_model.gd`, is built in code, and `resonator_rules.gd` plans each pulse where its wave meets
the player on clear floor), the Barnacle Turret (GDD §9.8, from Marketplace 1: a ceiling enemy, see
below), the Buzz Overdrive (GDD §9.9, from Corporate 1: a buzzsaw tank that cuts its lane's floor into
a gap, see below), the Tithe Collector (GDD §9.12, from Corporate 2, skipping the Dead Zone, back in
the Golden Zone: see Thefts above), the Gilded Sentinels (GDD §9.11, from Golden 2: live statues in
wall niches whose halberd cuts their wall section and the outer lane, see below), and the Enforcer Truck
(GDD §9.13, from Corporate 2: an armoured truck chasing the runner from behind that only other enemies'
charges, a floor cut or a too-wide gap destroy, see below).
`scripts/enemies/mesh_batch.gd` merges an enemy's low-poly parts into one mesh per material to keep draw
calls down.

**Big attacks take turns through the director** (GDD §9, decided September 26, 2026). The big attacks
of different enemy types never overlap, so the player never has to dodge two at once. The owner may
revert this after playtesting, so it sits behind one switch, `GameRules.big_attacks_take_turns` (on by
default, in the F6 panel); switched off, the game plays exactly as before the rule. The big attacks
(DESIGN-TBD, `docs/questions/r3.md`): the Octodog's charge sequence (its first wind-up until it gives
up), the drone's wind-up and barrage, the hover truck's rev and forward lurch and its cannon's charge
and volley, the Bad Dream's chase, the Resonator's pulse (its warning until its last wave has passed
the player; DESIGN-TBD, `docs/questions/c3.md`), the Buzz Overdrive's rev and charge (its warning
until it has passed the player and gone; it never waits, so it claims its turn a moment before and lets
the runner pass if another's is still on, below; DESIGN-TBD, `docs/questions/fix2.md`), a Gilded Sentinel's attack (its
eyes' flare until its last swing is over; it can't wait either, so it claims its turn a moment before
and lets the runner pass if another's is still on, below; DESIGN-TBD, `docs/questions/c4.md`), and an
Enforcer Truck's volley (its warning until its last bolt has passed the runner; GDD §9.13, proposed) and its showing
(from the moment it pulls up beside the runner until it has dropped back out of view; task C6b). Small attacks (a cyborg's burst, a window
cyborg's shot, a Barnacle Turret's burst, a screech's swipe) and the hover truck's entrance don't take
part. An enemy takes part like this, opting in for whichever of its attacks count as big:
- **Report it.** `is_major_attack_active()` is true from the start of the attack's warning until its
  last hazard is over (the lunge has passed, the lurch has ended). Each shot fired in it goes to
  `world.director.note_attack_shot(self, shot)` (the Projectile `fire_enemy()` returned): the attack's
  turn lasts until the shot is behind the player (`EnemyDirector.SHOT_PASS_MARGIN`) or gone. The
  director watches where the shot really is, so a change in the player's speed (a dash ending) can't
  cut the turn short.
- **Ask before the warning, never after it.** Just before the warning would start, once everything
  else about the attack is ready (its own spacing, its target, a clear stretch), the enemy asks
  `world.director.major_attack_blocked(self)`, and while the answer is true it doesn't start, asks
  again next frame, and goes on as it was: the drone keeps following, the truck holds back or keeps
  pacing, the Octodog paces in position. Asking only when ready matters: the director queues those
  held. Once a warning has started the attack runs its course; nothing stops it for another's turn.
- **Keep asking to keep your place; give up out loud.** A waiting enemy keeps its place in the queue
  until its attack starts, as long as it keeps asking: through its turn too (told it may go, one that
  isn't quite ready and asks again still goes before those that waited less), and through a gap in
  its asks (its stretch not clear for a moment, its planned point not reached yet) of up to
  `GameRules.turn_place_grace` (1 s; DESIGN-TBD, `docs/questions/r3b.md`); meanwhile those behind
  it wait. After a longer gap it loses its place, so the others don't wait long for an enemy that
  isn't ready (a Resonator waiting for clear floor): an enemy that means to wait longer keeps asking
  (the Octodog, below). An enemy that gives up the attack it waited for calls
  `world.director.give_up_turn(self)` and leaves the queue at once: the Octodog runs off, the hover
  truck changes state (it asks only while pacing, for its cannon, or holding back, for its lurch), the
  Resonator leaves, the Bad Dream dissolves. One that leaves play loses its place at once.
- **An attack that may only come within a window** (the Octodog's planned charges) moves the window
  on while `held_for_turn(self)` says it's waiting for another type, up to a limit of its own
  (`OctodogTuning.turn_wait_max`), and keeps every fairness rule it was planned with. Once held it
  keeps asking every frame until its turn comes, whether or not its stretch is clear by then, and if
  the wait made it miss its planned stretch, the window keeps moving on until the stretch ahead is
  clear again (within the same limit), so waiting for its turn never costs it its charges. After
  that it still asks every frame while its `charge_slack` lasts, so all along it keeps its place: another
  type ready again waits for it rather than go first again, until it charges or runs off. The
  Resonator's planned pulses do the same: a pulse held for another type's turn, or for clear floor
  where its wave would meet the player, moves the rest of its visit on; after
  `ResonatorTuning.turn_wait_max` spent waiting for other attacks (waiting for clear floor doesn't
  count) it drops its remaining pulses and leaves, never before its first. A first pulse overdue by
  `turn_wait_max` (waiting for either) keeps its place from then on: it also asks while it waits for
  clear floor (`Resonator._first_overdue`), so another type ready again waits for it and it pulses at
  the next clear floor (FIX4: before, it lost its place at every floor wait; on Golden 2 at 6 lanes a
  long Bad Dream chase over a visit's planned pulses, then a drone that stays, took every turn the
  dense floor left it for 55 s, until the next Resonator's arrival sent it away without a pulse).
- **An attack that can't wait** because the player sets it off (the Bad Dream bursts out of a killed
  host) or the generator planned its moment still reports itself: the others wait for it. It can
  overlap an attack that was already on when it came; the Bad Dream holds its slash until that one
  is over. A planned floor cut (B4's stand-in, C2's Buzz Overdrive) reports itself from its warning
  until its charge ends; the generator keeps every other enemy's planned stretch off its attack window
  (Floor cuts, under The generator), but not the attacks enemies time themselves at run time (a drone's
  barrage, a hover truck's lurch or cannon shot, a pulse or a charge moved on): one that asked a moment
  before the cut's warning, when nothing was on yet, went, and the warning then started on top of it.
  So an attack that can't wait claims its turn a moment before its warning and lets the runner pass if
  one begun before its claim is still on then: the Gilded Sentinel (C4) and the Buzz Overdrive (task
  FIX2, below; the stand-in cut, a review tool, doesn't).

The director holds a big attack while another type's is on or its shots are still on their way; an
enemy whose own attack is on carries on (the Bad Dream's next slash in its chase); and the enemies of
different types waiting go in the order their waits began (then the one spawned first), whether or not
they're asking at that moment, so none is kept from its turn by others that keep asking: one that
began waiting later never goes first. An attack that is on never waits for another (the Bad Dream
holds a slash within its chase only for an attack that was already on when the chase began, and that
one doesn't wait), and in the queue a waiting enemy is only ever held by those ahead of it, so two
enemies can't wait on each other; the one at the head starts, gives up, or loses its place a grace
after it stops asking (asking while it isn't ready holds the others back: only the Octodog does that,
and only until it charges or runs off, `turn_wait_max` plus its `charge_slack` at most), so nothing
waits for ever.
Types space their own attacks themselves (one drone barrage at a time; one Octodog, one hover truck at
a time). GDD §9.7's rule holds with the switch off as well: an `exclusive_major_attack` (the Bad
Dream's chase) and the attacks of the types in its `exclusive_of` (Octodogs', drones') never overlap. `is_waiting()` and `turn_wait()` say whether and
how long an enemy has been waiting (from its first held ask until its attack starts or it loses its
place). `tools/measure/big_attacks.gd` measures the overlaps, the delays and the enemies that never got
a big attack in over the campaign (Review tools); `tests/helpers/turn_dummy.gd` is a scripted big
attack for tests (with pauses in its asks and stalls when it may go).

**Pace** (GDD §3, owner's playtest September 30, 2026: the runner rises from about 21 m/s in the
Neon City to about 25 m/s in the Golden Zone, and enemies and their attacks speed up to match, never
with shorter warnings). An enemy that stands or moves in the world's frame gives its distances along
the track and its speeds at `MovementTuning.REFERENCE_SPEED` (18 m/s) and stretches them by the level's
pace (`world.tuning.pace()`; its rules by `LevelGenerator.pace`): in a faster zone it moves, lunges and
fires faster from further out, and every wind-up, flight and dodge takes the seconds it took at 18 m/s.
So far: the cyborgs' gun (engage distance, bolt speed, the clear path around an impact, `CyborgGun.pace`)
and their walk, flight and margin; the Octodog (its tuning's helpers take the pace: the lunge's start
and speed, the sprint, the run's margins, `charge_slack`, `appear_distance`); the Resonator (its
easing in and its margins; it hovers `hover_ahead` ahead at every pace, within laser tier 1's reach, so
the runner closes in on its waves as fast as at 18 m/s instead: they roll slower along the floor and take
as long to arrive, `ResonatorTuning.wave_speed_at`); the screech's dash; and every floor enemy's reach
(`LevelGenerator.enemy_floor_span` takes the pace; `CeilingZones.pace`). Warnings, charge-ups and wind-ups are seconds and stay what they
were. Enemies that move with the player (the drone, the hover truck once it's out, the Bad Dream) fire in
the player's frame, so nothing of theirs depends on the run speed. Boss fights run at their zone's speed
too (E1f), so the enemies a boss brings in follow its pace like a level's. What made the enemies livelier is data: less idle time between attacks (reloads, follow and
pacing times, cannon intervals, rests; DESIGN-TBD, `docs/questions/g1.md`). A new enemy whose distances
set a warning or a dodge window follows the pace the same way.

**Floor use.** The floor under a ceiling may hold enemies (GDD §3, changed September 26, 2026), but
a ceiling's landing zone and the spot of each of its pads keep off the floor enemies use (see
Ceilings under The generator). A type's tuning says whether it uses the floor (`uses_floor`: false
for fliers like drones and hover trucks, wall-only enemies like window cyborgs, and the Barnacle Turret,
which hangs from a ceiling) and how much of
it around its spot (`floor_reach_before`/`_after`: where it stands, moves and attacks a player in its
lane; the screech's 30 m before covers where it springs out). Rules that plan a longer run for one
enemy store it in `params.floor_span` (the Octodog's charges). An enemy that only ever drives behind the
runner (`behind_runner`: the Enforcer Truck) uses no floor ahead, and its entry's `at` is where it
arrives, not a spot it takes: `Octodog.charge_clear` leaves such entries out when a wait has moved a
dog's charges on. `LevelGenerator.enemy_floor_span(entry)`
and `enemy_uses_floor(entry)` read all of this; `CeilingZones`, `floor_clear` and `add_hull_with_pad`
respect it. An enemy that can't reach the ceiling stays consistent with it at run time: cyborgs, window
cyborgs and hover trucks hold fire at a player riding a ceiling, the drone and the Bad Dream wait
below, the Octodog never winds up and a screech stays in its manhole.

**A ceiling enemy: the Barnacle Turret** (C1, GDD §9.8). `barnacle_turret.gd` (`BarnacleTurret`), its
tuning (`BarnacleTurretTuning`, `data/enemies/barnacle_turret.tres`), its model
(`barnacle_turret_model.gd`) and its rules (`barnacle_turret_rules.gd`, The generator):
- **Where.** Its node sits at its mount point on a ceiling's underside (`tuning.ceiling_height`, over
  its lane); it hangs toward -y and faces +z, the player. Its params carry its ceiling (`hull_start`,
  `hull_end`, `first_lane`, `last_lane`); without them it takes the layout's ceiling over its spot. It
  stays in its hatch (hitboxes off, never targeted) until the player is `emerge_seconds` away at their
  speed, then pops out (`barnacle_emerge`; a floor runner sees it too) and stays put.
- **Its gun is the cyborgs'.** `CyborgGun` takes any `GunModel` (`scripts/enemies/gun_model.gd`: the
  three calls it makes on a model, `set_charge`, `aim_at`, `clear_aim`; `CyborgBody` extends it), a
  shooter's own sounds and bolt name (`charge_sound`, `shot_sound`, `shot_name`), and a `path_rule` that
  replaces the floor's check (`path_clear`: fences and gaps) for a target that isn't on the floor. The
  turret's `may_attack`: a rider on its own ceiling (on the ceiling, within its span), ahead, within
  `engage_distance`; never the floor. Its path rule (`_path_fair`): the rider is still on the ceiling past
  each bolt's clear stretch (`end_margin`), and a lane beside the rider's, within the ceiling, has no
  turret body from where the rider is to past the stretch (`body_reach`): there's always a lane to dodge
  into, on a two-lane ceiling (where it's the turret's own) the bolts come well before it, and a second
  turret never fires while the first stands in that lane between the rider and its bolts. One burst at
  a time with the cyborgs (their airspace, `CyborgGun.AIRSPACE_META`; GDD §9.8, proposed). Its burst is
  a small attack: it doesn't take turns with the big ones. Slightly more accurate than the cyborg
  (`aim_error`, `shot_jitter`), with faster bolts (so they can meet a rider closing in at run speed well
  before the turret); the dodge window is `min_warning_time` either way.
- **Body.** A solid `body` hitbox from the underside to the stomp line and its crown below it, a `top`
  that is `upside_down` (Damage and interactions). Both declare enemy attacks, so armor absorbs one
  contact hit using the shared armor/grace rules; unprotected contact is still deadly. Shield, claws
  and dash retain their rules; claws, the dash, a stomp from the ceiling or weapons kill it. Its health is
  in plain laser tier 1 shots rounded to whole shots at the level's `enemy_scaling`
  (`whole_health_at`): 5 (7 at laser tier 1, with `PowerupTuning.tier1_extra_shots`) through the Corporate
  zone, 6 (8) in the Dead Zone and the Golden Zone. Nothing of it reaches more than `REACH_BELOW` (0.8 m)
  under the underside: above a jump from a hover truck's roof and the top of a wall run.
- **Looks.** `BarnacleTurretModel` builds both looks from the same dome, chest cannon and size: mechanical
  (armour plates, a riveted band, a dim cold-white sensor), or a furry creature (low-poly tufts, googly
  eyes, floppy ears) on `&"scavenger"` and `&"casino"` (Gangland, the Marketplace; `is_creature`), with a
  palette per zone variant. Only its muzzle ever glows a hazard colour: enemy-fire red, swelling over the
  charge-up and the burst (a steady swell, nothing strobes). A hit's flash is softer with Reduced flashing.

**A floor cutter: the Buzz Overdrive** (C2, GDD §9.9; from Corporate 1 through the Dead Zone and the
Golden Zone). `buzz_overdrive.gd`, its tuning (`BuzzOverdriveTuning`, `data/enemies/buzz_overdrive.tres`),
its model (`buzz_overdrive_model.gd`), its rules (`buzz_overdrive_rules.gd`, The generator, Floor cuts),
its pattern (`data/patterns/buzz_overdrive.json`) and its sounds (`tools/asset_gen/
sfx_bank_buzz_overdrive.gd`: `buzz_rev`, `buzz_charge`; its death is the hover truck's `truck_explode`).
It is the visible cause of a floor cut the generator planned (B4's `FloorCutPlan`, `FloorCut`), keyed to
the player's distance like the cut, so it does the same on every attempt and at every frame rate:
- **Its encounter.** Its entry stands at its cut's end, in its lane (`cut_of`). It shows parked in its lane
  `appear_distance` ahead (the director spawns it far ahead, `spawn_lead` 300 m, hidden until then; its
  hint is now presented on the level introduction). When the player is a charge's distance from it (`FloorCutPlan.lead_at`) it
  rolls ahead of them at that distance for `roll_seconds`, revs for its rev (`rev_at`: its warning, the
  level's enemy scaling from 2.93 s in Corporate 1 to 2.5 s in the Golden Palace, the only thing that
  scales; its health stays 20) while it keeps rolling, then charges back at the player (`charge_seconds`
  to meet them, at `charge_speed` stretched by the pace), cutting the floor behind it (`advance_to`), and
  runs on `run_past` metres past them, off the screen, gone (retired only then: its cut runs to its
  start). Its distances follow the pace (the charge's from `charge_distance()`), its seconds don't.
- **Its warning.** The rev: the spin-up (`buzz_rev`), its eyes flaring and a red line over the lane it's
  about to cut, from just behind the player to its blade (then, as it charges, the stretch it still has
  to cut; the Octodog's lunge-line red, widening over the rev and pulsing, only widening with Reduced
  flashing). Sparks fly from the blade as it cuts (none with Reduced flashing). Its rev and charge play
  on its own voice, which moves with it (the world's voices stay where a sound starts), at full volume
  from a charge's distance (`sound_full_volume_distance`); the 2.45 s spin-up (under the library's 2.5 s
  a sound) is stretched over the rev by pitch (`rev_pitch`), so it always ends as the charge starts.
- **Contact and kills.** Its blade is an `attack` hitbox, narrow and centred on its lane (0.7 m wide, 2.4 m
  tall: a jump doesn't clear it), so wall and ceiling riders are never touched; no other part hurts. The
  armor and the shield block it, and then `FloorCut.hold_under` holds the floor under the player for
  `GameRules.cut_hold_seconds`: its cut runs on 1.5 s ahead of where it meets the player (0.6 s at 2.5
  times the run speed), so a player who stays falls once the hold is over. Claw-immune, not stompable (no
  `top`); the dash smashes it (`dash_kills`), into the cut lane, where only the grapple hook saves the
  runner. Weapons: health 20, so 22 laser tier 1 shots (G4's rule) and 15, 10 and 7 at tiers 2-4; a kill
  before its charge saves the floor, mid-charge `stop()` ends the cut where it dies. It rolls in 50-60 m
  ahead: beyond laser tier 1's 42 m and within the other tiers' 70 m, so on a plain track tier 1 never
  stops it before it has passed the runner and tiers 2-4 kill it during its rev at the zones' speeds
  (23.4-25 m/s); at the harder tiers' 28-30 m/s tier 3 (and tier 4 at 30) stop it mid-charge
  (`test_buzz_overdrive`; DESIGN-TBD, `docs/questions/c2.md`).
- **A big attack that never waits.** Its rev and charge are one big attack (`is_major_attack_active` from
  the rev until it's gone): the generator planned its moment, so it never waits and the others wait for
  it. **It claims its turn** (task FIX2). Reporting itself only from its rev, it let another type's attack
  that asked a moment before (when only its roll was on) start and run on into its rev: over the seven
  levels that have it, at 3, 5 and 6 lanes on 13 seeds each (273 runs of `big_attacks.gd`), 73 of 380
  tanks revved into a drone's barrage, a hover truck's lurch or cannon shot or a Resonator's pulse, 87 s
  of two big attacks at once (FIX1's 0.62 s in Dead Zone 1 at 5 lanes: a truck's lurch asked for 0.85 s
  before its rev). So, like a Gilded Sentinel, a tank that rolls in (`takes_turns()`: its cut has a roll,
  `lead`, and big attacks take turns) claims its turn `claim_seconds` (2.5 s) before its rev
  (`claiming()`: it reports itself from then on, so another type's big attack that gets ready meanwhile
  waits) and asks `major_attack_blocked` as its rev would start: with one begun before its claim still on
  (or its shots on their way, or one that can't wait begun meanwhile: a Bad Dream bursting out of a host
  killed then), it gives up its turn and lets the runner pass (`PASS`, last of its states
  so the measure tools' event logs keep the others' numbers): no rev, no line, no cut (`FloorCut.stop`, its
  lane stays whole), it speeds off ahead (`_passing_front`, keyed to the runner's distance) and is out of
  view and gone `pass_seconds` (3 s) later. Over the same runs: no overlap; 378 tanks revved and 2 let the
  runner pass (both behind a Resonator's pulse), none revved into another attack; the others lost 57 of
  2,163 drone barrages, 14 of 632 cannon shots and 7 of 527 lurches (no Octodog charge, Bad Dream slash or
  Resonator pulse, and no enemy went without its attack); event logs stayed identical in 199 runs, and the
  other 74 first differ within a tank's turn (its claim until it's gone). A boss's tank (its cut planned
  without a roll: Hostile Takeover's drop, whose boss keeps its own attacks off it) and every tank with the
  switch off rev as planned, as before (DESIGN-TBD, `docs/questions/fix2.md`).
- **Looks.** `BuzzOverdriveModel`: a tracked hull with skirt armour, a sloped glacis, a low turret with a
  slanted red eye slit under a dark brow on each side, exhaust stacks, and a giant vertical saw on braced
  arms whose teeth glow hot orange-red (the deadly part); matte military gunmetal and olive, scorched and
  rusted where enemies weather (`&"burned"`, `&"scavenger"`). Four draw calls, about 1,300 triangles: the
  hull is one surface in vertex colours under one matte material (`HullBatch`), then the eyes, the blade's
  disc and its teeth; the meshes are built once per look (about 1 ms, at the first one's spawn) and shared.
- **Cheap to run.** Its sparks come from its own emitter (one `CPUParticles3D`, `sparks_per_second`, only
  while it cuts), never the shared bursts; its sounds from its own voice; it looks up its cut's track piece
  only from its rev on; everything else a frame is a few transforms.
- **The Resonator** keeps its pulses off every cut (its rules run after these: `busy_stretches` holds each
  cut's whole window, and `Resonator.pulse_clear` counts a cut's stretch as a gap).

**A wall enemy in a niche: the Gilded Sentinels** (C4, GDD §9.11; Golden 2 brings them in, the Golden
Palace keeps them). `gilded_sentinel.gd` (`GildedSentinel`), its tuning (`GildedSentinelTuning`,
`data/enemies/gilded_sentinel.tres`, F6 "Enemy: Gilded Sentinel"), its rules (`gilded_sentinel_rules.gd`,
The generator), its patterns (`data/patterns/gilded_sentinel.json`: one, one that swings twice, a pair
across the street), its cut's shader (`gilded_sentinel_cut.gdshader`), its sounds
(`tools/asset_gen/sfx_bank_sentinel.gd`: `gilded_sentinel_grind`, `_swing`, `_break`) and its hint
(`enemy:gilded_sentinel`). DESIGN-TBD throughout (`docs/questions/c4.md`):
- **In its niche.** A wall enemy (`side`), standing in a niche set into the wall at wall-run height: a
  2.6 m statue standing out from the wall would block a wall run at all of its heights, so the statue (the
  Golden Zone's kit, `GoldenStatue`, at `statue_scale`) stands in the recess with its front
  `statue_inset` behind the face. Nothing of it reaches over the wall-run path (a wall runner's body lies
  along the face); only its swing does. The Golden Zone's skins open the niche (Zone skins: the statue
  kit's `recess()`, `GoldenSkin.note_wall_enemies`); in any other skin (quick play) it stands in front of
  the wall in the kit's `niche()` as a review stand-in, its hitboxes the same. At rest it holds its
  halberd upright at its side, the blade turned along the wall, so it fits the niche whole.
- **The attack**, once, as the runner comes: when they're `warning_seconds` (and `strike_lead_seconds`) at
  their speed from the stretch it guards, it asks the director (below), then warns: its eyes flare (their
  own material, and their red light filling the niche, what a runner sees from far down the street where
  the wall is seen edge-on), stone grinds, it draws its halberd back, and the red marks of its cut light
  up, filling toward the runner (the band on its wall, on the face; the outer lane's floor). Then it
  swings as the runner reaches the stretch (`section_length`, around its niche; a slower runner: it holds,
  raised, up to `hold_max_seconds`; a faster one may get past, since the warning always runs its whole
  length): for `strike_seconds` its cut is live, two `attack` boxes over the stretch, the band on its wall
  (`band()`: the heights around the free wall-entry height, from the face out over a wall runner's whole
  body, `wall_reach`) and the outer lane (from `wall_reach` out to `lane_margin` short of its inner edge,
  from the floor up to the band's top, above any jump), with a red slash through both. One that swings
  twice (`params.swings` 2) cuts the stretch before its niche, then swings back across the stretch past
  it, each as the runner reaches it. So: on the wall, stepping on right before it is hit, a jump onto the
  wall (or a ramp) runs above the band and an early entry slides below it; on the floor, anywhere but the
  outer lane is safe.
- **Protection.** Its cut is an enemy attack: armor and the shield block it; the dash passes through
  unharmed and leaves it standing (`dash_kills` off, as for the Resonator's wave). Its body is a solid
  `body` box in the niche, behind the face, where nothing in play reaches.
- **Killing it.** Weapons (health 15: 17 laser tier 1 shots with G4's rule; auto-fire picks it out in its
  niche), or a kick: a wall jump made right by its head on its wall (`can_kick`: the runner's height from
  `kick_below` under its helmet's base to `kick_above` over its crest, within `kick_along` of it along the
  track) stomps its `top` through DamageRules (`Player.receive_hit(top, true)`: it's defeated, the runner
  bounces). A wall jump leaps out to the outer lane and never comes down on a statue in the wall, so the
  push-off is the stomp; it hears the wall jump as `Player.movement_event`, never by checking each frame.
  Down, its eyes go dark and it slumps in its niche until the runner is far past.
- **Big attacks.** Its attack counts as one, from its eyes' flare until its last swing's cut is over
  (`is_major_attack_active`), so the others wait for it. A statue can't wait (the runner is gone by then),
  so it claims its turn `claim_seconds` before its warning (`claiming()`: it reports itself from then on,
  and another type's attack that gets ready meanwhile waits), then asks `major_attack_blocked` as its
  warning would start: with another type's attack begun before its claim still on, it gives up its turn
  and lets the runner pass, with no warning and no swing (`history` "pass"). So its cut never overlaps
  another big attack. The generator keeps floor cuts, Octodog runs and ceilings' landings off it, and
  every big attack off a level's first, so that one always swings. In simulated runs of Golden 2 and the
  Palace (god mode, the middle lane, at 3, 5 and 6 lanes) 32 of 36 Sentinels swung with the claim (the
  rest met a long attack begun before it), 21 without; the other types' big attacks went from 148 to 135
  (the Resonator's pulses also keep off the Sentinels' turns, so a busy level may get one visit fewer).
- **Cheap.** The statue is one mesh of two surfaces (the gold on the skin's solid material, the eyes on
  each Sentinel's own), its frames baked once from the kit (`frames_for`: rest to wind-up, the swing, the
  recovery, the husk; mirrored on the left wall so it swings toward the runner on both) and shared by
  every Sentinel, so animating it is a mesh swap when the frame changes; the marks and slashes are a few
  quads on one small shader; its bursts are the shared ones. Reduced flashing: the eyes rise steadily
  (no throb) and a swing's flash is a single, softer fade.

**Behind the runner: the Enforcer Truck** (C6, GDD §9.13; from Corporate 2, then every later level with an
Octodog or a Buzz Overdrive). `enforcer_truck.gd` (`EnforcerTruck`), its tuning (`EnforcerTruckTuning`,
`data/enemies/enforcer_truck.tres`, F6 "Enemy: Enforcer Truck"), its model (`enforcer_truck_model.gd`), its
marker (`enforcer_truck_marker.gd`), its rules (`enforcer_truck_rules.gd`, The generator; it has no
patterns), where and how it shows itself (`enforcer_truck_room.gd`, `enforcer_truck_view.gd`; task C6b), its
blast (`enforcer_truck_blast.gd`; C6b), its sounds (`tools/asset_gen/sfx_bank_enforcer.gd`: `enforcer_siren`,
`_whine`, `_laser`, `_pickup`, `_crash` as it's hit; every wreck's blast is the hover truck's `truck_explode`)
and its hint (`enemy:enforcer_truck`). DESIGN-TBD numbers throughout (`docs/questions/c6.md`, `c6b.md`):
- **The chase.** Where its entry's `at` says (the runner's distance), its siren whoops and it drives in from
  `arrive_gap` (45 m) behind to `follow_gap` (8.5 m: behind the camera's 7.5 m), keeping its place relative
  to the runner's distance, never closer than `MIN_GAP`. It takes each of the runner's lane changes
  `lane_delay_seconds` (0.8 s, GDD §9.13) later (a log of their lane changes on the level clock), over
  `switch_seconds`, so a late dodge leaves it in the lane just left. It holds still while the runner is
  down. After `chase_seconds` (25 s) it gives up, never mid-volley or with a bait on, and drops back at
  `leave_speed` until it's out of play.
- **Seen from behind.** Behind the camera, it shows by its headlights' beams and its light bar's red and
  blue washes on the floor of its lane (`EnforcerTruckModel.floor_lights()`: three flat, unshaded,
  additive vertex-coloured strips, soft-edged; the bar's halves take turns at `flash_hz`, both lit and
  steady with Reduced flashing) and a marker at the screen's bottom edge under its lane (a CanvasLayer
  under the HUD; the lane's point unprojected with the current camera; a red and blue chevron with a pip
  for each rider, sized with `UiTheme.px`).
- **Its volleys** (GDD §9.13: lasers at the runner's lane). Each is warned by a red line on the floor of the
  runner's lane, from just behind them to `line_ahead` ahead (widening and pulsing, only widening with
  Reduced flashing), and a rising whine on its own voice stretched by pitch over `warning_seconds` (1 s).
  Then `shots_per_volley` shots `shot_gap_seconds` apart, each a column of bolts (`bolt_heights`: over a
  slide and a whole jump, so only leaving the lane dodges it) fired from its front through
  `ProjectilePool.fire_enemy` (red enemy bolts, `LASER_NAME`), reaching the runner `bolt_flight_seconds`
  later. The line stays until the last bolt has passed. A volley starts only when it chases at its follow
  gap and its interval is over (`first_volley_seconds` after it arrives, then `volley_interval(riders)`
  from the last one's end), with the runner on the floor and a lane beside clear to step into until the
  volley is over (`escape_clear`/`lane_open`: no hole, fence, floor cut, doodad, floor enemy or hover
  truck's lane, from `escape_reaction_seconds` after the warning), and never from `hold_seconds()` (2.7 s)
  before one of its baits attacks (an Octodog's wind-up, a Buzz Overdrive's rev: so a volley is over before
  it closes up, and before a tank claims its turn) until the attack is over; then it also gives up any place
  it held in the director's queue. A volley is a big attack (`is_major_attack_active`): it asks
  `major_attack_blocked` before its warning, and the others wait for it.
- **Its baits.** It declares `charge_bait` (Enemy charge contacts above) and is immune to weapons (never
  targeted, no health bar), stomps, the claws and the dash (`claw_immune`, not `stompable`, no `dash_kills`;
  it never touches the runner anyway). Its body hitbox (`hitbox_size`, a little smaller than its look) is
  what a charge must touch: an Octodog's lunge or a Buzz Overdrive's charge that crosses it destroys it, as
  the player's kill (then its blast, below). While an Octodog attacks (`close_lead_seconds` before its wind-up until it gives up)
  it closes right up to `close_gap_for(dog, pace)` (2.4 m, inside where the lunge ends,
  `lunge_overshoot` behind the runner), its model low enough to stay under the camera's line of sight to
  the runner's feet. A dodge as the lunge begins leaves it in the lunge's lane; one at the wind-up's start
  takes it out in time (`test_enforcer_truck_runs`).
- **Holes.** It hops every ordinary gap in its lane (a bounce keyed to its own distance, until its rear has
  cleared it); a gap wider than `max_hop_jump_fraction` of a jump at the level's speed, or a begun floor
  cut not solid under its front or middle (`FloorCut.solid_at`), wrecks it (`&"gap"`, `&"cut"`: the
  player's kill, `enforcer_crash`, then its blast, below). None of a level's own gaps is that wide (0.6 of a jump; the levels' are
  0.35-0.6), but each campaign level's couple of wider gaps are (0.7; task G7, Wider gaps below), one in its
  chase where one fits.
- **Riders.** Cyborgs the runner passes alive (`Cyborg.Mode.PASSED`) are recorded with their lane and spot;
  when its front reaches one in its lane it climbs aboard (a crouching gunner on its roof, `set_riders`, a
  pip on the marker, `enforcer_pickup`), up to `max_riders` (3), and a cyborg node still in play leaves
  it. Each rider makes the next volley come sooner (`rider_rate_bonus`), and destroying it pays
  `rider_bonus` for each (`&"enforcer_riders"`). Window cyborgs (another type) never board, and hosts don't
  (`picks_up_hosts`, DESIGN-TBD).
- **Looks.** `EnforcerTruckModel`: a wheeled riot truck (a push bar, a sloped armoured nose, a slatted slit
  windscreen, a long armoured box with slit windows, the light bar on the roof, its riders' hatches and a
  gun ring), its body one mesh in vertex colours under one matte material, in three looks by the zone's
  variant (`look_of`: clean police paint on `&"city"` and `&"vr_runner"`, weathered on `&"burned"` and
  `&"scavenger"`, gilded on `&"golden"` and `&"casino"`); only its headlights, its light bar (red, and a
  blue well off the safe cyan) and its riders' screen faces glow. Its riders are crouching cyborg gunners
  sharing two meshes. Four draw calls and two per rider shown, about 1,500 triangles with three riders;
  meshes and materials are built once per look and shared (`warm_up` builds them with the level), so a
  truck spawned in play makes none.
- **Showing itself** (C6b; GDD §9.13 "Showing itself", the owner, October 8, 2026). Now and then it speeds up
  beside the runner in a lane next to theirs, its front `show_ahead` (4 m) ahead of them so its body is level
  with them and the chase camera shows all of it (its riders and light bar too), stays `show_seconds` (3 s)
  and drops back: as it arrives (`show_on_arrival`, pulling up from its arrival gap) and once more mid-chase
  (`show_count` 2), `show_spacing_seconds` (6 s) apart; its first volley waits up to `show_wait_seconds` for
  the first. `show_phase` goes NONE, PULL_UP (`show_close_speed`), ALONGSIDE, DROP_BACK (`show_drop_speed`,
  `show_yield_speed` when it gives way), back to NONE and the runner's lane; `show_lane_now()` gives the lane
  it may take now or why not (`show_problem()`), and `history` notes `show`, `alongside`, `drop_back`,
  `give_way` and `shown`. Its rules:
  - **A turn.** A showing is a big attack's turn (`is_major_attack_active` from its start until it's dropped
    back `EnforcerTruckRoom.OUT_OF_VIEW` behind the runner): it asks `major_attack_blocked` before it starts,
    so it never meets a volley's, a bait's or another type's warning or attack, and it never fires while
    beside the runner. It's back behind them `show_margin_seconds` + `close_lead_seconds` before a bait's
    turn (an Octodog's planned wind-up, a Buzz Overdrive's claim on its turn, from the layout and the dogs and
    tanks in play): it shortens its stay for one (`hold_for`, never under `show_min_seconds`) or doesn't show.
    Never with a hover truck or a Gilded Sentinel in play or coming (`NO_SHOW_TYPES`: they can't wait).
  - **Solid, safe sides.** While beside the runner, a lane blocker along its body to `blocker_ahead` past its
    front (`TrackBuilder.add_lane_blocker`, `LAYER_LANE_BLOCKER`) bumps a lane change into it back (Player's
    `lane_blocked`, never a hit: its 2 m body hitbox in a 2.4 m lane leaves the bump clear of it). As the
    runner moves toward its lane (a lane change or a bump that way, `movement_event`), leaves the floor, or
    anything below stops holding, it gives way.
  - **Never the only free lane** (`EnforcerTruckRoom`, the layout read once by lane at load; the truck adds
    what's in play). Its stay must leave the runner a lane to dodge into for everything blocking their lane
    (`can_dodge`: holes, fences, doodads, floor enemies, a floor cut's lane window; with `DODGE_ROOM_SECONDS`
    to step around each) at 3, 5 and 6 lanes; to a runner by a wall (an outer lane) it shows itself two lanes
    in, leaving them the lane between (`sides`, `escape_lane`; task C6c, the owner's answer of October 9, 2026,
    GDD §9.13 "Room to show itself": beside them it would take their only lane to dodge into, and at 5 and 6 lanes
    it would hide up to 25 m of their lane from the camera, which sits inward of them), held to the same rule both ways (the lane between open where theirs is blocked,
    theirs open where the lane between is); never to a runner off the floor; and its own lane must be clear
    where the camera sees it there (`lane_clear`: no fence, doodad, floor enemy, pad, speed pad or ramp, nor a
    hole too wide to hop until it's rejoined the runner's lane; it hops the others), so it's never beside a
    lane the runner needs.
  - **Never hides anything.** `EnforcerTruckView` (the run camera's resting view) checks at load, for its
    look and lane count (`fits_for`, with `EnforcerTruckModel.profile`), that every corner of it is on
    screen and nothing of the runner or the floor of their lane and the far side is behind it; enemies its
    body would hide from the camera keep it from showing (`shadow_clear`), so a hazard's warning stays in view.
  - **Seen and heard.** Its siren swells as it pulls alongside (`siren_swell_db` up to full); its marker fades
    while it's in view; its light bar and floor lights carry on as before.
  - **Its planned window** (task C6c; The generator, Enforcer Trucks). Where the generator planned a window in
    its chase (params `show`: `show_window()`, `show_at()`), it claims its turn among the big attacks
    `show_claim_seconds` (2 s) before the runner reaches where the showing is due, until it begins or the runner
    is `show_window_slack_seconds` past (`claiming()`, part of `is_major_attack_active`): another type's big
    attack that gets ready meanwhile waits for it, one already on ends first; and it starts no volley that would
    still be on there (`_holds_for_showing`). It still shows itself wherever play allows before; once it has,
    the window has done its work. A showing beside the runner tries a lane clear for its whole stay first, else
    one clear for its shortest.
- **Its blast** (C6b; the owner, October 8, 2026: a visible explosion however it's destroyed). Every wreck (an
  Octodog's lunge, a Buzz Overdrive's charge or cut, a gap too wide to hop) lurches on into the chase camera's
  view over `wreck_surge_seconds` (its front to `wreck_gap` behind the runner; in a hole, until its nose meets
  the far edge; spinning out from a charge, nose-diving on its rear into a hole so nothing of it rises into the
  camera it passes under), trailing sparks, then blows up (`_explode`): its model and riders gone in an
  `EnforcerTruckBlast` (a few swelling unshaded puffs, a white-hot core, dark smoke and an additive floor glow;
  `blast_radius`, smaller and flatter in the runner's lane, `blast_radius_in_lane`, so it never stands between
  the camera and the runner), the shared `RunEffects` fire, smoke and debris (a chunk for each rider), a shake
  and `truck_explode`. It burns `blast_seconds` in the runner's frame, falling back at `blast_drift`, and the
  truck is freed after it. Reduced flashing: no core, its fire and floor glow coming up over a moment. Ten draw
  calls for about a second; drawn with the level's warm-up (`EnforcerTruckBlast.warm_look`). A blast fades its
  own copies of its materials built the same way: `Resource.duplicate()` drops an unshaded
  `StandardMaterial3D`'s emission, so a duplicate would build a shader the warm-up never drew.
- **Cheap.** A few transforms a frame, its hole checks walking each lane's gaps with a cursor; its bolts
  are the projectile pool's. A showing's checks read the stretches `EnforcerTruckRoom` indexed at load.

## The generator

`LevelGenerator` (`scripts/world/level_generator.gd`) builds a `LevelLayout` (pure data) from
patterns, a difficulty value and a seed, for any lane count. Passes, each with its own random stream:
patterns (filtered by the level's features) → enemy rules scripts → density/filler placement → credits. Helpers for rules
scripts: `rng_for(name)`, `add_enemy(type, at, lane, side, params)`, `add_hull_with_pad(lane, at,
seconds, lanes)`, `ceiling_lanes(pads, at, one_lane_ok)`, `one_lane_seconds(lanes, seconds)`,
`floor_clear(from, to)`, `enemy_floor_span(entry)`, `enemy_uses_floor(entry)`,
`difficulty_at(progress)`, `feature_start(feature)`, `feature_started(feature, at)`,
`feature_active(feature, at)`, `feature_share_at(feature, share)`, `ramp_launch(ramp)`, and for a level
paced in bursts `quiet_at(at)`, `stretch_end(at)`, `burst_index(at)`, `quiet_stretches()`,
`burst_spans(lo, hi)`, `prefers_bursts(feature)`, `burst_spot(rng, lo, hi, feature)` and
`pacing_pools(spots, feature)`, plus
`layout`, `config`, `tuning` (the level's own, `LevelConfig.movement_for`), `speed`, `jump_distance`,
`pace` and `metres(m)` (Pace, below) and `zones` (the level's `CeilingZones`).
`pick_weights(patterns, difficulty, at)` gives the weights a pick draws from (the static
`pattern_kind(pattern)` and `enemy_count(pattern, lanes)` say how the recency curve counts a pattern),
and `picks` lists the patterns the last build placed (id, features, spot, length, due or not), for
tests and `tools/measure/level_shape.gd`. Pattern format: `data/patterns/README.md`.

**Progressive danger density** (owner revision, October 3, 2026). `danger_density.gd` overlays the
native layout through enemy and obstacle hooks around the filler pass. The per-level
`LevelConfig.danger_density_increase` dial is calibrated to actual generated enemy and obstacle
counts, not merely interpreted as a spawn-probability multiplier. City uses 0.15; Gangland
0.18/0.20/0.22; Marketplace 0.24/0.26; Corporate 0.28/0.29; Dead Zone 0.37; Golden 0.38.
Prototype and boss arenas stay at 0, which draws nothing and preserves the old layout exactly.
Numbers and safety margins live in `data/tuning/danger_density.tres`.

Small enemy encounters stay within existing feature introductions and warning rules; later levels
also add fair ceiling turrets where that feature exists. Obstacle rows use spare lane width where
possible, or additional longitudinal opportunities when a row already leaves only one lane open.
The pass checks the reachable route through successive rows, not just a permanently empty lane.
Wall fences retain their placement rules, Resonators keep their whole visit clear, and doodads cannot
occupy the only route the new rows require. Added pieces receive no extra risk-credit pay.
Durations and reward tables are unchanged, including City 1's 55 seconds.

`tools/measure/danger_density.gd` reports counts by level, band and danger category, and compares
dial-0 layouts with a saved before-change dump. Representative measurements (native seed plus
9001/9002, 3/5/6 lanes) are:

| Band | Enemy count increase | Obstacle count increase |
|---|---|---|
| Early | 16.7-18.1% | 17.0-17.5% |
| Middle | 26.4-26.7% | 26.4-27.2% |
| Late | 31.6-34.6% | 33.0-37.7% |

The regression suite asserts requirement-based bands of 10-20%, 15-35% and 30-40%, respectively,
for both categories at every supported lane count, plus route safety, determinism, economy and
build-time guards. All 225 saved dial-0 layouts match the pre-change baseline.

**Ramps** (GDD §3) launch the player onto the wall higher than a free entry and add a speed boost
that fades away the same way a speed pad's does (both share `boost_decay_per_second`;
`MovementTuning.boost_left` and `boost_distance`), so a ramp's wall run goes further than a free
one. `RampLaunch` (`scripts/world/ramp_launch.gd`; `gen.ramp_launch(ramp)`) predicts it the way the
Player moves: where the player is on the wall and when (`distance_at`, `time_at`), how high
(`height_at`, `body_at`: the heights the body spans) and how fast (`speed_at`), from the launch
(`start`) to the drop back into the ramp's lane (`end()`). Every rule that predicts a ramp's wall run
uses it: the credits along it (`LevelGenerator.wall_run_credits`), and the wall fences (B5), which keep
off the longest wall run a ramp can launch along their wall (Wall fences, below). `test_movement` holds it
to the real Player at 3, 5 and 6 lanes, and `test_interactions` rides the credits on real physics.

Rules scripts run in the order of the level's `features` list, except that a script declaring
`const RUN_AFTER: Array[String]` runs after those features' rules (the host rules after the drone's;
the cyborg rules, and the host rules that start with them, after the hover truck's, so cyborgs keep
their margin from the ramp a truck adds; the Octodog rules after the drone's, the host's and the
hover truck's, so each dog is planned around the level's final ceilings, chases and truck lanes and
nothing clears it afterwards; the Resonator rules after every feature that puts things on the floor or
plans a big attack, so each pulse is planned on the level's final floor and off every Octodog's run,
floor cut and Gilded Sentinel's turn).
When a rule needs room for one of its guarantees, it removes what's
in the way rather than moving it (taking content out never makes a level unfair). Guaranteed pads
come from `scripts/enemies/pad_placement.gd`, shared by the drone and host rules: the drone's pad
schedule (GDD §9.6) owns every pad after its first wave, pattern ceilings give way, and the host rules
(which run after the drone's) cover each Bad Dream chase with pads at most 10 s apart or leave that
host out. The Octodog rules keep each dog's charges off every stretch a chase can cover (GDD §9.7).

**Ceilings over a dangerous floor** (GDD §3, changed September 26, 2026). The floor beneath a
ceiling may hold gaps, hazards and enemies: the ceiling is the way to escape them, and it's never
required. `CeilingZones` (`scripts/world/ceiling_zones.gd`, `gen.zones`) holds the two stretches every
ceiling keeps safe, and the checks and clearing for them:
- **The landing zone**: from a section's end, `hull_landing_seconds` at run speed (21.6 m at 18 m/s), no lane
  the section covers holds a gap or a fence (a narrow ceiling's rider drops only from its lanes) and no
  floor enemy's stretch reaches in, in any lane, so the player always lands safely.
- **Each pad's spot**: its lane holds no gap, fence or ramp from a full jump before the pad (a
  player who cleared the lane's last obstacle lands before it) until the lift has carried them up to
  the hull (`rise`), so the pad is never on or at the edge of a gap, never in a fence, and reachable;
  and no floor enemy's stretch, in any lane, reaches where it lies.

A pattern may put floor pieces and enemies under its own ceiling (a gauntlet; `_place_pattern` keeps
them), and `_secure_ceilings` drops what a pattern puts in its ceiling's landing zone or pad spot, with
a warning. A ceiling a rule adds lies over whatever the floor holds (`add_hull_with_pad` refuses one
whose pad or landing isn't clear; `PadPlacement` clears only those two stretches first, picking a pad
lane that needs no clearing when it can, and drops a fence generator left powering nothing). So the
floor under any ceiling holds what patterns put there, with their usual fairness and spacing, and a
floor runner can always pass the pad by. Rules that add floor enemies keep off both stretches: the
cyborg rules' `obstacle_spans` include every landing zone, and the Octodog's charges and runs keep
off pads and landings (`Octodog.pad_or_landing_between`), not off the floor under a ceiling.
Floor cuts planned in advance (B4, which never cut a landing zone or a pad's lane) ask `CeilingZones`
too. The tests check every generated ceiling with `LayoutChecks.check_ceilings`, including a floor
route under it that never takes the pad (`FloorRoute`, a conservative model of the floor moves; some
routes are replayed on real physics).

**Narrow ceilings** (B3; GDD §3, decided September 26, 2026: ceilings don't have to cover every lane,
and on one the player switches lanes only within its width). A hull in the layout covers a contiguous
range of lanes: `{start, end}` covers every lane, and a narrow one adds `first_lane` and `last_lane`
(`LevelLayout.make_hull`, `hull_lanes`, `hull_width`, `hull_covers`, `hull_at(d, lane)`,
`under_hull(d, lane)`; the keys are left out for every lane, so a level without narrow ceilings is the
same data as before). Every ceiling, a pattern's or a rule's, gets its lanes from
`ceiling_lanes(pads, at, one_lane_ok)`: every lane unless the level's `narrow_ceiling_share`
(`LevelConfig`, group "Narrow ceilings", from `narrow_ceiling_start`) makes it narrow; then one lane
(`one_lane_ceiling_share` of them) or two lanes up to `narrow_ceiling_max_lanes` (all but one by
default), anywhere that holds its pads. The draws come from a stream of their own (`_ceiling_rng`), so
with a share of 0 every level generates byte for byte as before, and ceilings narrowed to two lanes or
more leave the pattern pass as it was (the same patterns in the same spots; a one-lane ceiling is
shorter, so what follows it comes a little earlier). A one-lane ceiling
lasts `one_lane_ceiling_seconds` at most (`one_lane_seconds`) and comes only from a pattern that puts
nothing but its ceiling on the track (`plain_ceiling`) or from a rule (PadPlacement), never from a
gauntlet. What follows the lanes:
- the landing zone is kept (`_secure_ceilings`, `PadPlacement`) and checked (`CeilingZones.landing_clear`,
  `clear_landing`, both taking the lanes) only over the ceiling's lanes; floor enemies keep off it in
  every lane, as before, which is safe for any range;
- a pad is always under its ceiling, in its range (`add_hull_with_pad` refuses one outside it);
- the credits: the line on the ceiling runs along the pad's lane and the rich one sits in the ceiling's
  far lane (none on a one-lane ceiling); floor trails skip only the covered lanes;
- a pad hurls every drone on screen into the ceiling's lanes (`Drone.hurl_x`: it veers in as it rises);
- the player can't leave the ceiling sideways (Damage and interactions, blocked moves).

`LayoutChecks.check_ceilings` checks each range (pads over their lane, a one-lane ceiling short, the
landing zone per lane, the floor route, credits within the lanes), and `test_generator` sweeps widths
at 3, 5 and 6 lanes. Enemies that use ceilings respect the range: the Barnacle Turret (C1, GDD §9.8)
never goes on a one-lane ceiling (`layout.hull_width(h) == 1`: no room to dodge) and at most two go on
one ceiling, mounted over lanes the ceiling covers (`hull_covers`); anything aimed at a ceiling rider can
only expect them to move within `hull_lanes(h)` (the turret's path rule, Enemies).

**Barnacle Turrets** (C1, GDD §9.8; `barnacle_turret_rules.gd`). The turret has no patterns: its rules
hang turrets from the level's own ceilings, after every rule that adds or takes away ceilings
(`RUN_AFTER`), with seeds of their own (not `add_enemy`'s running count) and no floor use, so the pattern
pass, the recency curve, the guarantee's forced picks and every other rule see the same level with or
without the feature: a level differs only by its turrets (and, below, an introduction's ceiling). On each
ceiling: never a one-lane one; never over a pad's lane (the rider lands there and can ride on past every
turret; the line of ceiling credits runs along it); off the ceiling's credits in its lane, the rich one
the credit pass adds later included (`credit_near`); at least `after_pad_seconds` past the last pad, or
`tight_after_pad_seconds` in the only lane beside a pad's lane (`tight_lane`: a two-lane ceiling, or
next to a pad at an edge, where its bolts must come well before it), and `before_end_seconds` before the
end. The first ceiling past the feature's start where one fits always gets one, alone; later ones get
turrets at `ceiling_share`, and a second one (`spacing_seconds` apart) at `pair_share` from
`pair_min_scaling` on and only where two lanes are free of pads. In a level that gives the feature a
start (Marketplace 1) the first comes within `intro_seconds`; where no ceiling it fits on lies there (or
a level has none at all), the rules add a plain full-width one (`intro_ceiling_seconds`, or shorter where
that doesn't fit, but long enough to hold a turret) at the first spot where `add_hull_with_pad` fits it
without clearing anything and off every Octodog's planned run (the Octodog's own checks), its pad before
the level's first drone (whose rules own every pad from its wave on; the pad may come before the
feature's start, the turret never does) and off hover trucks' lanes (`PadPlacement.pad_lane`). The fill
pass (G1) keeps nothing for a turret (`keep_out`: it never uses the floor), so it fills a level the same
with or without turrets; it keeps off an introduction's ceiling like any other.
`LayoutChecks.check_turrets` (from `check_rules`) checks every turret in every generated level.

**Gilded Sentinels** (C4, GDD §9.11; `gilded_sentinel_rules.gd`). Patterns stand them on a wall; the rules
run after every feature's that puts things on the floor or the walls before them, the Buzz Overdrive's
floor cuts included (`RUN_AFTER`), and the Resonator's, the Barnacle Turret's and the floor cutter's run
after these. Each one's attack, at the level's run speed, is its window
(`GildedSentinelTuning.attack_window`: from where the runner is as its eyes flare to the end of the stretch
it cuts), and where it may stand is `problem()`:
- the level: its window past the run-up and the feature's start, its stretch before the end-clear stretch,
  and its niche within one of the track's chunks (`in_chunk`, `TrackBuilder.CHUNK_LENGTH`: the skin opens
  it in that chunk's wall);
- its wall: no sign, window cyborg, wall vent's screech, wall fence or other Sentinel on it from
  `approach_seconds` before its stretch (a runner entering early to pass below needs the wall from there)
  to `wall_clear_seconds` past it (GDD §9.11 with §9.1); a ramp on that wall only where the wall run it
  launches (`RampLaunch`, and its longest, with claws and a speed pad's boost) passes the stretch wholly
  above the band, or is over before it, and none in the outer lane by the stretch;
- never when the outer lane is the only safe lane: the lane beside it holds no hole, fence, floor cut,
  anti-grav pad, floor enemy or hover truck's lane from `escape_lead_seconds` before its first swing to
  the end of its stretch, and no hover truck holds the outer lane itself meanwhile (`HoverTruckRules`
  clears its lane of floor enemies, Sentinels included);
- what runs meanwhile: no floor cut's window, Octodog run or ceiling's landing zone reaches its window, and
  its cut (its `params.floor_span`, `floor_use`) keeps off every pad's way (`CeilingZones.enemy_clear`);
  the level's first keeps off every big attack and Bad Dream chase too (`STRICT_ATTACKS`), so it always
  swings; the others may meet a drone wave or a hover truck's stay, whose attacks wait for theirs at run
  time (each claims its turn shortly before its warning) or, begun before, make it let the runner pass
  (Enemies);
- other Sentinels: windows `gap_seconds` apart unless they are a pair (the same spot on both walls).
One that doesn't fit where its pattern put it tries a few spots around it (`MOVE_OFFSETS`), one that swings
twice then once, and one that still doesn't is left out. The level's first (its introduction) swings once,
alone; in a level that gives the feature a start (Golden 2), if none is left within `INTRO_REACH` of it
(earlier rules took it out: a hover truck clears its wall and lane, a drone's pads their stretch), one is
added at the first spot there, calm where it can be. It uses the floor (`uses_floor`, its tuning's reach;
its rules set `params.floor_span` to what its cut uses), so ceilings' pads and landings, the Resonator's
waves and everything that asks the floor keep off it; `keep_out()` (its window) keeps the fill pass and
floor cuts off it, and `doodad_keep_outs()` (its window in every lane, marked `type`) the zone doodads, floor
cuts and the wall fences' drop windows. The Resonator's rules (after these) plan its pulses off every
Sentinel's whole turn, from its claim to its last swing (`resonator_rules.gd`'s `sentinel_turns`,
`GildedSentinelTuning.claim_window`), so a planned pulse is never held for one at run time (one that
was could be pushed on past the level's end). `problems()` re-checks every one for the tests.

**Enforcer Trucks** (C6, GDD §9.13; `enforcer_truck_rules.gd`). No patterns: the rules place every truck,
after every feature's rules (`RUN_AFTER`: the Octodogs' planned charges and the Buzz Overdrives' cuts are
final by then), around the level's baits (`bait_points`): each Octodog's first planned wind-up and each
Buzz Overdrive's charge, with its warning (the wind-up, the rev) and its hold (`hold_seconds()` before the
warning, when the truck stops firing for it). A truck arrives (`at`, the runner's distance) so that a bait's
warning comes at least `bait_after_seconds` (4 s: it has settled behind the runner) after it and its charge
at least `bait_before_seconds` before it would give up (`in_chase`); where it can, the hold comes
`bait_prefer_min/max_seconds` (8-13 s, seeded) after it, so the runner sees a volley or two first (87 of
104 sampled trucks), then the nearest offsets in 0.5 s steps (`_arrival_for`). Never before the run-up or
the feature's start, never while a bait attacks (`arrival_keep_outs`: an Octodog's planned charges, a Buzz
Overdrive's attack window), up to `per_level_max` (2) a level, never two at once (each one's chase and drop
back `spacing_seconds` from the next); in a level paced in bursts it arrives in a burst where it can
(`pacing_pools`). The earliest baits get them first (with its showing windows planned, the ones whose chases have
room for its showing before their bait: Showing windows, below). Its params list the baits in its chase (`baits`).
Corporate 2 introduces it at a start of its own, 5% into the level (before the Tithe Collector's 10%; the
level's only baits at 3 and 6 lanes come within its first 32 s), so its first truck arrives within the
campaign's introduction reach (on other seeds an introduction whose first bait has no room may come later: Showing
windows, below).
It takes no room: `keep_out()` is empty and it uses no floor, and its entries take seeds of their own, so a
level with the feature is the same level plus its trucks and their showing windows (below), but for the danger
density pass, which counts every enemy entry (its target grew by one other enemy in 1 of the 18 builds of its six
levels on their own seeds). A level with no bait its chase can take gets none (quick play without Octodogs or Buzz
Overdrives). `problems()` re-checks every truck for the tests.

**Showing windows** (task C6c; GDD §9.13 "Showing itself", the owner, October 8, 2026: the player should see
what's chasing them). With `EnforcerTruckTuning.show_window_planned`, the rules plan a showing window in every
chase that has room (`ShowPlanner` in `enforcer_truck_rules.gd`), on the layout as the trucks are placed: a calm
stretch where it can pull up beside the runner and stay alongside wherever the runner is, at the level's speed. It
asks what the truck asks in play: no other enemy's big attack (its warning, its shots) and no enemy about near the
runner until it has stayed alongside (`busy`: their keep-outs; a host's possible Bad Dream chase is the player's
choice and doesn't count), no floor cut's attack, hover truck or Gilded Sentinel in the stretch, its bait's turn far
enough off (`hold_for`), and for a runner in every lane a lane beside them where its look fits on screen, its lane
stays clear for the whole stay, the runner keeps a lane to dodge into and it hides no enemy
(`EnforcerTruckRoom.layout_lane`, `fits_for`), also when it begins `show_window_slack_seconds` late. Windows where
no runner is sent off the floor (a pad's ceiling, a ramp's wall run) before it has stayed alongside come first;
its whole stay before a shorter one (`show_min_seconds` at least); as it arrives (any of its arrivals, the
preferred first) before mid-chase, mid-chase before its first bait before after it. Where the level leaves no such
stretch, it takes out what's in the way, only what the showing needs gone: plain holes and fences (never a pulsing
fence or one a fence generator powers), plain cyborgs, window cyborgs and Screeches (never a host, the first of a
kind the level introduces, or the last of its kind or of one of the level's features: the generator would build the
level again for a missing feature). **Which baits get trucks** (task C6d; the owner, October 9, 2026, GDD §9.13
"Room to show itself": it shows itself before the player can bait it, and a chase with no room for that gives its
truck to another bait's chase that has room): of every set of baits whose chases fit together (planned along the
track, each one again around the chases before it), the one with the most windows before their first bait, then the
most windows, then the most chases, then the earliest (`_choose`). A pair is also planned the other way round, the
later chase's window first and the earlier truck arriving earlier around it (`_plan_set`); the planner itself tries
every arrival a bait allows, the earliest too, before it settles for a window after the bait. A level that
introduces the truck keeps its first bait's chase where that has room before its bait, and otherwise moves its
introduction only to a chase where it shows itself before its bait (its first-encounter hint is the level intro's,
and the cyborg planted in a charge path that teaches it comes earlier in the campaign, `test_charge_paths`). A later
window whose take-outs would now leave none of a kind after an earlier window's is planned again
(`ShowPlanner.still_fits`; none in the sampled builds). The window goes in the truck's params (`show`: {at, from,
to}); `gen.show_window_result` reports each chase (its bait, its window, its arrival against the preferred one,
what it took out, or why none) and each bait's own chase (`baits`: a window before or after the bait, or none, and
whether it got a truck). Every later pass keeps
off each window, `WINDOW_EDGE` (1 m) wider, as a **calm stretch** (`doodad_keep_outs` entries with `calm: true`):
nothing it adds may stand or attack there, but it's no attack, so nothing keeps a spacing from it and it shapes no
pass's search for room. The danger density pass rejects an enemy (where it stands, `CALM_ROOM` either side, and its
attack window) or a row in one (`Plan.calm`) without changing its rooms, so its draws are as before elsewhere; the
cyborgs planted in charge paths keep off one where they stand (`_cyborg_fits`); a wider gap keeps its row off one
(`row_only`); a zone doodad keeps itself and its push's lead off one, which shapes none of the doodads' stretches
(`doodad_keep_outs`' `calm`); the fill pass (`fill_keep_outs`, no margin) and City 1's extra gaps keep off it. A
Buzz Overdrive given a planted cyborg claims its turn earlier (`ChargePathTuning.claim_seconds`), after the trucks
are planned: the planner assumes that claim for every one (`least_claim`), so each window still holds in the
finished level (`ShowPlanner.problem_of`). With the switch off the level is built exactly as before. On the six
levels' own seeds, 16 of 23 chases get a window (8 as it arrives, 6 only after the first bait); the chases without
one have a hover truck or a Gilded Sentinel over their whole chase (4), or no calm stretch at all (Corporate 2 at 5
lanes: its introduction among an Octodog's charges, a Tithe Collector and a Buzz Overdrive's attack; Dead Zone 1 at 3
lanes: pulsing fences, a ramp's wall run and a Screech; Dead Zone 2 at 6 lanes: rows of fences with a pad in their
gap). Played with a runner keeping to each lane in turn (`tools/measure/enforcer_shows.gd`, Review tools), 57 of 106
chases show it (32 as it arrives), against 15 of 106 before; of the 75 with a window, every one shows it but 18 whose
truck the runner's bait or a wider gap destroyed before an after-bait window, and one whose runner a pad sent onto a
ceiling. The danger density pass's enemy and obstacle counts on its sampled
bands stay as they were; the windows cost the six levels about 2% of their enemies and obstacles (592 to 580 and
3281 to 3226 on their own seeds: what they took out, and what the fill pass and the pass's rows found no room
for). Every level without the truck, and every level with it with the switch off, builds exactly as before. The
planning adds about a quarter to those levels' build time (50-330 ms a build; the longest, Dead Zone 1 at 5 lanes,
1.9 s against 1.7 s). Task C6d (which baits get trucks, above) changes nothing on the levels' own seeds (every
campaign build is byte for byte as before): 9 of the 23 chases have a window before their bait (8 as it arrives,
1 mid-chase), 7 one after it, 7 none, and no other bait with room is left for any of those 14. The level's only
usable bait comes too soon for any showing before it (Golden 1 at 3 and 6 lanes, Golden 2 and 3 at 6: a Buzz
Overdrive revs 6.4 s in, 4 s after the run-up; Corporate 2 at 6 lanes: an Octodog's charges at the start keep the
truck from arriving earlier than 4.5 s before its Buzz Overdrive's turn), its only chase has a hover truck or a
Gilded Sentinel about throughout (Dead Zone 1 at 6 lanes, Golden 2 at 3, Golden 3 at 5), or its other bait with room
already has the level's other truck (Corporate 2 at 5 lanes: its introduction, a Tithe Collector about and then its
bait too near; Dead Zone 1 at 3 lanes; Dead Zone 2 at 5 and 6 lanes), or neither of its two baits has room (Dead Zone
2 at 3 lanes: pulsing fences and no lane beside a runner by the wall before its first; a hover truck over its
second). On 8 other seeds each (144 builds), 9 builds change: 71 of 226 chases have a window before their bait
against 63 of 227 (27 after it against 32); in two a level keeps one truck that shows itself where it had two that
didn't, and in one a pair planned the other way round gets back the second truck C6c's order dropped. A wider gap
(task G7) comes before a window only where that window comes after its bait (6 of 27). DESIGN-TBD: items 386
(`docs/OPEN_QUESTIONS.md`) and the chases no bait with room is left for (`docs/questions/c6d.md`); items 382–385
are the owner's answers.

**Late starts.** `LevelConfig.feature_starts` (feature → share of the level) holds a feature back
until its start: patterns that require it aren't picked before, and the first pattern picked from
there must use it (its introduction), so the encounter follows its scheduled start rather than
whenever chance brings it; its first-encounter hint is now on the level introduction. A rules script that adds a feature's enemies or pieces keeps
to that feature's start (`feature_active`, `feature_started`), including pieces that belong to
another feature: the drone rules place drones after the `drone` start and their pads after the
`ceilings` start, the hover truck rules place its route ramp after the `ramps` start, and the host
rules drop a host whose chase would need pads before the ceilings start. `add_hull_with_pad` and
`PadPlacement.place` refuse a pad before the ceilings start. Guaranteed spots given as a share of the
level (the drone's first wave, the guaranteed hover truck) are shares of the stretch where the feature
may appear (`feature_share_at`). A new rules script that adds things must do the same. Endless mode
drops the starts. An introduced enemy can still be cleared by a later fairness rule (a hover truck
keeps its lane free), and the feature then first shows a little later.

**Feature weights.** `LevelConfig.feature_weights` (feature → factor) scales the pick weight of the
patterns that require a feature (0 leaves them out). Corporate 2's heavier military presence and The
Hush's hosts use it.

**A level's newest things get the most picks** (GDD §5, owner's review P2 13). `Campaign.configure`
gives each campaign level's copy the campaign's recency curve (`LevelConfig.feature_recency`,
`FeatureRecency` in `data/tuning/feature_recency.tres`, F6 "Feature picks (campaign)") and each of its
features' age, the levels since the campaign introduced it (`LevelConfig.feature_ages`: 0 in the level
that introduces it). A pattern's pick weight is then multiplied by the curve's factor for its newest
feature (DESIGN-TBD: 4 where it's introduced, 2.5, 1.75 and 1.25 over the next three levels, 1 from
then on), but no more than a capped feature's cap (`max_factor`; DESIGN-TBD: 1, never boosted, for the
host, the hover truck, the drone, the Octodog and the Resonator, whose rules keep only so many of their
enemies, and for the rare vent screech), so the curve never spends picks on enemies the rules would drop and leave
their stretch empty. With `keep_feature_share` the features' patterns, capped ones apart, are then
scaled back to weigh together what they did without the curve, and with `keep_share_by_kind` kind by
kind (`LevelGenerator.pattern_kind`): patterns with enemies keep the number of enemies they place
(`enemy_count`), obstacle-only ones and safe ones (a plain ceiling, a ramp, a speed pad) their share,
and plain gaps, fences and signs keep their weight. So the curve only moves picks between features of
the same kind (a new enemy takes them from older enemies, a new mechanic from older mechanics) and no
level gets easier: measured over the campaign, no level has fewer enemies or obstacle rows than
without the curve beyond measuring noise (`docs/questions/r5.md`). A level's own `feature_weights`
still apply on top. Quick play, tests, boss arenas and endless mode have no ages, and the curve's
`enabled` switch turns it off: those levels generate exactly as before. It works with the guarantee
rather than instead of it: every feature still appears in every campaign level.

**Quiet stretches and bursts** (GDD §5, The Hush: "long silent stretches broken by sudden threats").
A level with `LevelConfig.quiet_seconds` above 0 alternates, from its first pattern, a quiet stretch of
that many seconds at run speed with a burst of `burst_seconds`, quiet first. Its pattern pass then:
- in a quiet stretch, picks patterns `quiet_spacing_seconds` apart, only those without enemies (sparse
  obstacles, and safe mechanics such as a plain ceiling, a ramp or a speed pad) and those of its
  `quiet_features` whose enemies stand inside the stretch (The Hush's hosts, which belong to the quiet
  stretches); the spacing never carries the cursor past the next burst's start;
- in a burst, picks threats only (a pattern with a hole, a fence, a sign or an enemy, whose enemies
  stand inside the burst), `burst_spacing_seconds` apart;
- gives a burst at most one introduction (`feature_starts`): a second one waits for the next burst, so
  a burst never stacks two new things. A due pick (an introduction, or the guarantee's) of an enemy
  a quiet stretch leaves out waits for a burst.

The rules scripts then run as always, so every fairness rule and the guarantee hold. The drone, hover
truck, Octodog and host rules put an enemy they guarantee in a burst when one lies in reach, and the
host rules put a quiet feature's host in a quiet stretch (`burst_spot`, `pacing_pools`). Threats that
last (a hover truck's stay, a drone until its pad, a Bad Dream's chase) may run on into the next quiet
stretch, and an Octodog, whose charges need a clear floor, often finds its spot in one.
`quiet_seconds` 0 (every other level) turns all of it off.

**Every feature appears.** In a level with `LevelConfig.guarantee_features` (every campaign level),
each feature a pattern can place there is in the finished level, at any lane count and on any seed
(GDD §5: an introduced feature keeps appearing). Rules drop or clear what doesn't fit fairly, so
`generate()` checks the finished layout and builds the level again until nothing is missing:
- `feature_positions(layout, feature)` finds a feature's pieces: enemies by type, hosts (and cyborgs that
  aren't hosts, nor planted in a charge's path, task G7), wall-vent
  screeches, the mechanics by their ramps, pads, speed pads or pulsing fences, and the wall fences by
  theirs (full-height ones `wall_fences`, partial ones `wall_fences_partial`). A rules script that
  declares `static func positions(layout: LevelLayout) -> Array[float]` answers for its own feature (a
  new kind of piece).
- Only the features some pattern can place in the level are required (`placeable_features()`: in its
  lane count and difficulty, with pick weight), so a planned feature isn't, and a new enemy's
  patterns bring it under the guarantee.
- Each new build forces picks of every missing feature at a new share of the stretch where it's
  active (`GUARANTEE_SHARES`): one more pick for each build that missed it, up to
  `GUARANTEE_MAX_PICKS`. Features that appeared keep their spots. A forced pick is a due pick, like
  an introduction: the first pattern picked once the cursor reaches its spot must use the feature.
- Every build runs every pass and rule unchanged, so the guarantee never bends a fairness rule. After
  `GUARANTEE_ATTEMPTS` builds the level keeps the build that missed the fewest, with a warning (the
  campaign tests fail on any warning). `attempts` says how many builds a level took (about two on
  average in the campaign).
- Rules that hold the room for a feature themselves also add one where it fits when a level is left
  without any, which saves a build: a drone wave and a hover truck in any level (their tunings'
  `guarantee_one_wave` and `guarantee_one`), and a host, an Octodog and a Resonator in a level with
  `guarantee_features`.

**Pace** (GDD §3, owner's playtest September 30, 2026: about 21 m/s in the Neon City rising zone by
zone to about 25 m/s in the Golden Zone). A level's run speed is its own `LevelConfig.run_speed`, which
`Campaign.configure` fills in from its zone (`ZoneDef.run_speed`; DESIGN-TBD, a straight rise from 21 to
25 m/s) times a harder tier's speed multiplier; 0 is the movement tuning's base speed (quick play, the
tests). A campaign boss arena gets its zone's speed the same way (`Campaign.configure_boss`, E1f; see
Bosses). The level keeps its duration in seconds and gets longer in metres. Everything the
patterns and rules measure in metres was written for `MovementTuning.REFERENCE_SPEED` (18 m/s), so the
generator stretches it by the level's pace (`pace = run speed / 18`, `metres()`): a pattern's `length`
and its elements' `at`, a sign's length, credit spacing (the patterns' and the trails'), and the rules'
margins (the cyborg's obstacle margin, `CyborgRules.obstacle_margin_at`; the Octodog's; a hover truck's
`clear_before`; a pad's keep-out around a truck; the Resonator's). Seconds (`at_seconds`, spacing, a
ceiling's `length_seconds`, the landing zone) and jumps (a hole's `jump_frac`, a pad's run-up) follow
the run speed already, and physical sizes (pieces, lanes, a hull's lead-in, the physical margins of a
few metres around a piece) don't change. So every reaction window keeps its seconds at every zone's
speed and at any lane count: a faster zone is never secretly tighter. At the reference speed the pace
is exactly 1 and every level is built byte for byte as before (`tools/measure/level_pace.gd --old-data`
proves it against main's data). A harder tier's faster speed stretches the patterns too, so it's harder
by its difficulty bonus, not by tighter timing (a question, `docs/questions/g1.md`). The Hush's quiet
stretches end exactly where `stretch_end()` says (`quiet_at` uses its sums).

**Busier levels: the fill pass** (GDD §3: "more gaps, obstacles and enemies than the first build had
(to an extent), so there is always something going on"). Campaign levels space their patterns closer
at low difficulty (`spacing_seconds_easy` 1.1 s against the default 1.8; the hard spacing, 0.9 s, stays
the floor that lets a player switch across six lanes between two patterns), and after the rules a fill
pass (`LevelConfig.fill_empty_seconds`, 2 s in campaign levels, 0 = off and exactly as before)
puts more of the level's own plain obstacle patterns (`is_filler`: holes and fences, no feature, no
sign, no enemy) into every stretch where nothing goes on for longer than that. `fill_keep_outs()` says
what's going on and what's kept, each with how far a filler keeps from it (the level's spacing there
plus a pattern's tail, `FILL_TAIL_SECONDS`): every piece, each ramp's wall run to where it drops the
player back (`RampLaunch`), each pad's zone and ceiling's landing zone, the floor under a ceiling
(but where the level already picks gauntlets over two lanes or more: there fillers may go under it,
timed like a gauntlet's pieces, `FILL_CEILING_AFTER_PAD_SECONDS` after its pad to
`FILL_CEILING_BEFORE_END_SECONDS` before its end), every enemy from `FILL_ENEMY_LEAD_SECONDS` before it to
the end of the floor it uses, and the quiet stretches. A rules script may say what its enemy keeps
(`static func keep_out(gen, entry) -> Vector2`: the cyborg's lead and margin, a hover truck while it's
surely there, a Resonator's planned visit, a drone wave until its first pad) and keep fillers out of
what it keeps only partly (`static func after_fill(gen)`: a hover truck's lane until it has left).
Fillers are picked like the pattern pass's picks, from a stream of their own (`rng_for("fill")`), and
recorded in `fills`; the pattern pass, the rules and the guarantee are untouched. Credits: fillers take the clear stretches they
stand in from the credit trails, and a stretch too short for a full trail gets a shorter one
(`credit_trail_min`, 5 in campaign levels, 0 = as before), with a lower trail chance, so each level's
credits stay about where they were (task R7 owns the economy). `tools/measure/level_pace.gd` measures
each level's pace and density (Review tools).

**City 1's additive floor gaps** (approved answers in `docs/USER_REQUESTS.md`: 30% more encounters
**and** 30% higher mean missing lanes per encounter, increasing density rather than replacing
fences/signs). Only `city_1.tres` enables `LevelConfig.gap_encounter_increase` and
`gap_lane_increase`, both 0.3; defaults are zero, so other levels and their random streams are
unchanged. `GapDensity.apply()` runs after doodads and wall fences, before credits. It preserves
every original gap, pattern pick, fill, enemy, sign, fence and doodad. It adds separated gap rows in
earliest-fit floor windows, then widens the narrowest eligible rows, using its own seeded lane-choice
stream (`rng_for("gap_density")`). Rows group equal start/end distances; a staggered extension of an
existing hole never counts as an additional encounter.

For a build with **R** original rows and **G** original lane-gaps, the encounter target is
`ceil(R × (1 + gap_encounter_increase))`. The mean-width target is
`(G / R) × (1 + gap_lane_increase)`; after actual row placement, the integer lane-gap target is
`ceil(actual_rows × mean_width_target)`. This independently rounds up both requested dimensions;
increasing the total lane-gaps alone is not success. New gaps use the shortest original row's
length (already jumpable), fit outside the unchanged intro/finish buffers, and keep the existing
hard-spacing time from **every** other gap row. Lane-specific clearance keeps that same margin from
fences; enemy keep-outs, ceilings/pads/landings, ramps, cuts, speed pads, doodad pushes and wall-fence
drop windows are protected. A widening keeps off a zone doodad's window (its push's lead before it to
the level's spacing after it, in every lane) and, with the margin, the doodad's own lane, which is then
never the lane the row leaves open; not the margin around it in every lane (FIX4). The doodads already
keep that window clear of every row, so with the margin everywhere a doodad decided which rows widened
and City 1's doodads moved its extra gaps (at 5 lanes, a widening went to another row), when doodads
only add to a level (`test_doodads`). New rows and full-width jumps keep the margin from doodads too.
Signs can have a new floor choice below them without being replaced.
New/widened rows leave at least one grounded lane clear through the reaction window, or allow
the existing patterns' full-width jump route only when every lane has a clear run-up and landing
and the row is within `max_gap_jump_fraction`. Existing all-lane rows remain unchanged. Lack of
separated placement room, lane capacity or clearance may limit a target:
`LevelGenerator.gap_density_result` reports baseline, target and
actual counts plus explicit constraint messages (empty when the pass is disabled). It never removes
an obstacle, lengthens the level, relaxes clearance, or claims a constrained mean met the target.

City 1, campaign default tier, seed 101, still **55 seconds** (1,155 m at 21 m/s):

| Lanes | Rows before → after | Lane-gaps before → after | Mean before → after | Rounded targets: rows / lane-gaps |
| --- | --- | --- | --- | --- |
| 3 | 11 → 15 | 11 → 20 | 1.000 → 1.333 | 15 / 20 |
| 5 | 15 → 20 | 24 → 42 | 1.600 → 2.100 | 20 / 42 |
| 6 | 13 → 17 | 25 → 43 | 1.923 → 2.529 | 17 / 43 |

These shipped layouts meet both dimensions without a constraint. `test_city_gaps` builds the
baseline by copying the config and disabling only these tunables, verifies independent targets,
preserved obstacles/picks, determinism, buffers, jumpability, separated encounters, enemy/doodad
fairness and a conservative full-level `FloorRoute`, and exercises seed/tier and constrained cases.
The seed 1–8/default-tier and seed 101/all-tier sweep at 3/5/6 lanes has one conservative-clearance
shortfall: 3 lanes, seed 101, difficulty 0.20 reaches its 11-row target, but only 25 lane-gaps
(mean `25 / 11 = 2.272727…`) versus a mean target of 2.275, which rounds up to **26** lane-gaps.
The remaining lanes cannot be widened while retaining a grounded route or clearing every lane
for an isolated full-width jump with the existing hard-spacing margin. The report explicitly
marks this as constrained, not as a 30% mean increase. An all-lane, no-room fixture also verifies
both shortfalls are reported rather than silently weakening either target.
Credit placement naturally sees the new gaps; no reward, credit, price or duration tuning compensates
for them. The owner approved lower earnings from shortening as intentional and requested economy-test
updates rather than compensation (`docs/USER_REQUESTS.md`). The current measured progression is
documented under the economy below.

**Zone doodads** (G5; GDD §3, owner's playtest September 30, 2026: the owner's other answer to "too
barren": scenery pieces standing in lanes, specific to each zone, that never hurt; running into one
pushes the player into a neighbouring lane, the side with room, a side chosen per doodad when both have
it). `LevelLayout.doodads` holds {lane, start, end, size, side, seed}: a size class
(`LevelLayout.DOODAD_SIZES`, small, medium, large; `MovementTuning.doodad_size()` gives its box, the
skin its look), the side it pushes to and a number to vary its look by. The list is left out of
`to_dict()` when it's empty, so a level without doodads is the same data as before. `_place_doodads` runs
after the fill pass and before the credits, on its own stream (`rng_for("doodads")`; with
`LevelConfig.doodad_share` 0 it draws nothing and the level is built byte for byte as before), so
doodads only add to a level: they take a lane rather than needing a reaction, and nothing after them can
undo or crowd them. It puts them only where they're fair (`LayoutChecks.check_doodads` holds every
generated layout to this, at 3, 5 and 6 lanes):
- in an inner lane, never the outermost one (a wall runner's body reaches into the outer lane, and the
  wall-runner collision stays as it is), pushing into a neighbouring lane with room (no lane a rule
  keeps), a seeded side when both have it;
- where nothing else goes on in any lane from `doodad_lead_for()` before its front (the push's time at
  run speed: the push lands on clear floor) to the level's spacing after its end (`doodad_after()`: the
  player can cross its lane again before what comes next, as between two patterns). What's kept is
  `doodad_keep_outs()`: the fill pass's keep-outs as they stand (every piece, the fillers too, each ramp's
  wall run, each pad's zone, every enemy's stretch or what its rules keep, the quiet stretches), every
  ceiling whole from its start to the end of its landing zone (the chase camera rides below a ceiling,
  lower than a doodad's top), and what the rules keep: a rules script may declare `static func
  doodad_keep_outs(gen) -> Array[Dictionary]` with entries {from, to} (every lane: the host rules' Bad
  Dream chases), {lane, from, to} (that lane, which no doodad stands in or pushes into: a hover
  truck's, until it has left; its `keep_out` already keeps every lane for its shortest stay) or {from, to,
  calm: true} (a calm stretch in every lane: an Enforcer Truck's showing window, task C6c: no doodad nor
  its push's lead stands in it, but it shapes no stretch, so the doodads draw as without it elsewhere; the
  other later passes keep their additions off it without spacing from it);
- one at a time, `doodad_gap_seconds` from one's end to the next one's front, so a few in a row never
  make a slalom.
Each stretch with room gets one with the level's `doodad_share` (a seeded spot in it; the next spot in a
long stretch the same chance), in a size class its weights allow (`doodad_*_weight`), from
`doodad_start`. Floor credits keep out of them (`DOODAD_CREDIT_MARGIN`); nothing else moves or goes for
them. `FloorRoute` keeps out of a doodad's lane where it stands. DESIGN-TBD (`docs/questions/g5.md`):
each level's share (City 1 brings them in gently: small and medium ones only, from a fifth of the way
in), the sizes and the push.

Enemies whose attacks a doodad could make unfair (its side blocks a dodge, its push moves the player)
count them at runtime too, through `LevelLayout.doodad_between()`, for an attack that could come later
than the generator planned it: a drone holds its barrage and a hover truck its cannon while a doodad
stands in the stretch the attack would take (`_doodad_in_reach`), an Octodog charge or a Resonator pulse
moved on by a wait for its turn waits (`Octodog.window_clear`, `Resonator.pulse_clear`), cyborg bolts
never land by one (`CyborgGun.path_clear`), a cyborg's walk and panic run keep their margin from one
(`CyborgRules.obstacle_spans`), and a hover truck only lurches at a player who can leave its lane
(`_escape_ok`). Measured with the level data (`tools/measure/level_pace.gd`, each level's own seed and
four others at 3, 5 and 6 lanes, against the same levels with `--set=doodad_share:0`): every row, enemy
and big attack as before (a credit inside a doodad goes, one or none a level), 3 to 15% more events a
minute (doodads a minute: City 1 2.8, the rest of the City 4.5 to 5.3, Gangland 2.7 to 4.4, the
Marketplace about 4, Corporate about 3, Dead Zone 1 2.3, The Hush 1, the Golden Zone 2.5 to 3), the mean
empty stretch down from 1.2–1.45 s to 1.0–1.3 s. The longest empty stretches stay about as they were:
they lie under ceilings or around enemies, where doodads never stand. A runner who keeps to the middle
lane at 3 lanes meets every doodad (they all stand there); at 5 and 6 lanes about a third of them.

**Floor cuts** (B4; GDD §9.9, the Buzz Overdrive's: "the generator plans each cut in advance (lane,
start and end), so levels stay fair and identical on every attempt; the saw is just the visible cause").
`LevelLayout.cuts` holds {lane, start, end, warn, charge, keep, speed}; `FloorCutPlan`
(`scripts/world/floor_cut_plan.gd`) has the geometry: the cause waits at `end`, its warning starts when
the player is `warn` metres before it (`warn_at`), the cut starts running at `charge_at` and runs back
along its lane toward and past the player, keyed to the player's distance (at distance p its front is at
`end - (p - charge_at) * speed / run_speed`, `front_at`), meets them at `meet()` and ends at `start`
(`done_at`). Its lane window (`lane_window`: the warning to `keep` metres past `end`) is what its lane
keeps clear, its window (`window`: the warning to the end of the cut) what the level keeps calm. The
list is left out of `to_dict()` when it's empty, so a level without cuts is the same data as before (B4
checked 1,269 layouts byte for byte against the build before it: every campaign level at 3, 5 and 6
lanes on ten seeds, quick play with and without every built feature, busy levels with the fill pass and
doodads, the generator suite's sweep and the boss arenas). A rules script plans a cut with
`FloorCutPlan.make()` (metres through the pace), makes room with `CutPlacement.place(gen, cut)`
(`scripts/enemies/cut_placement.gd`: on a copy it clears the cut lane's holes, fences and speed pads
over its lane window and the holes beside it beyond what may stay, the nearest lanes first, and asks
`cut_problem`; only a cut that then fits changes the level), and adds the cut's cause as an enemy entry
at `end`, in its lane. `LevelGenerator.add_cut()` takes a cut only if `cut_problem()` finds nothing
against it:
- one at a time: no other cut's window reaches its window;
- never a lane holding a ramp (or the wall run it launches, until it drops the player back), a pad's
  zone or the safe landing zone after a ceiling (`CeilingZones.cut_clear`; a narrow ceiling's covers
  only its own lanes, B3), and nothing else in its lane over its lane window: no hole, fence, speed pad,
  zone doodad or other cut;
- the other lanes whole along its stretch: on 3 lanes no hole in either (GDD §9.9: two lanes always stay
  whole); on 5 and 6 lanes holes in at most `LevelConfig.cut_holes_beside` of them (1: 3 of 5 and 4 of 6
  lanes stay whole, `whole_lanes_for_cut()`);
- nothing else going on meanwhile: no enemy's keep-out (`_enemy_keep_out`, the fill pass's) and nothing
  the rules keep doodads off (`rules_doodad_keep_outs()`: a Bad Dream's chase, a hover truck's stay in
  its lane) reaches its window, bar its own cause;
- a way out: from `LevelConfig.cut_reaction_seconds` (0.5 s) after its warning starts until the cut is
  `CUT_CONTACT_METRES` from a player still in its lane, a neighbouring lane has room to switch into
  (`cut_escape_clear()`).
Wall runners and ceiling riders need no rule: a cut only takes floor away, in its own lane, and its
cause's hitbox stays in its lane. What comes after the rules keeps off cuts too: the fill pass keeps off
a cut's whole window in every lane (`fill_keep_outs`), doodads off its lane window, never pushing into
it (`doodad_keep_outs`' lane keeps), floor credits skip it, and `floor_clear()` counts it as a hole.
`LayoutChecks.check_cuts` holds every generated layout to all of it at 3, 5 and 6 lanes, with a
`FloorRoute` out of the cut's lane from the reaction time on (`FloorRoute` keeps out of a cut's lane
from where it would reach a player in it). The stand-in cause (`floor_cutter`, a debug-only quick-play
feature, never in the campaign; `floor_cutter_rules.gd`, after every other feature's rules) plans cuts
through a level in seeded lanes. DESIGN-TBD (`docs/questions/b4.md`): the limit at 5 and 6 lanes,
keeping everything else off a cut's window, and cuts in the outer lanes.

**Floor cuts on the track.** `TrackBuilder` builds each cut as a piece of its own (`FloorCut`,
`scripts/world/floor_cut.gd`) in the chunk where its stretch starts, and leaves the lane's floor out of
the chunks there as it does a gap's, without edges: it draws that floor in `CUT_SLICE` (4 m) slices with
the skin's own `floor_segment`, each chunk's as it's built, and hands them to the cut (`add_slice`); the
cut asks the skin's `floor_cut()` for the hole (Zone skins, Floor cuts' looks). Its collision is one
static body on the floor layer whose two convex shapes (the floor not yet cut, and the floor held after
a block) change their points at once, so the player falls through a cut floor by the same physics as a
normal gap, the same frame. As the cut runs, slices behind its front hide, the one it's in shrinks to it
and the hole's parts move along: a handful of transforms a frame and no chunk rebuild (a chunk with a
cut costs at most about 1.5 ms more to build, measured per skin by `test_floor_cuts`), on any renderer.
`track.floor_cut(lane, end)` finds a built cut, `track.floor_cuts()` lists them. The cut's cause drives
it:
- `advance_to(d)`: the cause is at track distance d; the front follows it toward `start`, never back.
  The stand-in moves with `FloorCutPlan.front_at`; a cause that moves its own way (C2's saw) passes its
  own position, and the floor ahead of it stays whole.
- `stop()`: the cause died (GDD §9.9: "killing it mid-charge stops the cut where it dies"): the floor
  from `start` to the front stays whole for good.
- `hold_under(player, GameRules.cut_hold_seconds)`: the shield or the armor blocked the cause (its
  hitbox's `contacted` with `BLOCKED_ARMOR`/`BLOCKED_SHIELD`): the floor from just behind the player to
  as far as they run meanwhile holds for about a second (1 s, game rules), then goes at once
  (DESIGN-TBD: the held floor's look).
The Buzz Overdrive (C2, under Enemies) is the cause the campaign uses, and the stand-in stays for
reviews. A cause that sets off before its warning (the Buzz Overdrive rolls ahead of the player) gives its
cut a `lead`: its lane window and its window start there (`FloorCutPlan.lead_at`: its lane is clear
wherever it drives, and no other cut's encounter overlaps it), while its attack window
(`attack_window`, when nothing else may go on) and its warned lane (`warned_lane`, which no ceiling's
landing zone may reach) start at its warning. For a boss fight (E5b's Hostile Takeover):
plan the cut at the arena's speed (`arena.tuning`), ask `arena.cut_problem(cut)` (the generator's rules
on the arena's track), and add it through `arena.add_pieces()`, its whole stretch past `stream_from()`, so
about ten seconds ahead (the Buzz Overdrive's own plan: `buzz_overdrive_rules.plan_for`), with its cause
in its `enemies`, or, as Hostile Takeover's drop does, the cut alone and its cause brought into play with
`spawn_enemy` at the cut's end when it arrives (the tank finds its cut by its lane and end, `cut_of`). A
cut whose cause never comes stays whole: only its cause runs it. A track that grows during play (`TrackBuilder.extend_layout`, endless mode's R4 too) takes cuts
the same way.

**Wall fences** (B5; GDD §9.1: "electric fences that span a side wall and turn off and on from time to time,
to make the walls less safe"; full-height ones from Marketplace 2, passed by timing; from the Corporate zone
partial ones over the low or the high part of the wall, passed by entering the wall high or low).
`LevelLayout.wall_fences` holds {side, at, band, pulse_on, pulse_off, phase} (left out of `to_dict()` when
empty, so a level without them is the same data as before); `WallFencePlan` (`scripts/world/wall_fence_plan.gd`)
has the geometry and timing: a band's heights (`band_heights`: the whole wall-run path from the floor to
`MovementTuning.wall_fence_top`, or the low band up to `wall_fence_low_top`, or the high band from
`wall_fence_high_bottom`; a free entry's body runs between the two), the field's reach out from the facade
(`reach`: over a wall runner's body, never as far as a floor runner in the middle of the outer lane), its
hitbox, and its state at any level time (`state_at`, `next_on`: exactly what its Hazard shows). They have no
patterns: the generator adds them after the zone doodads and before the credits (`_place_wall_fences`,
`WallFencePlacement` in `scripts/world/wall_fence_placement.gd`), from a stream of their own
(`rng_for("wall_fences")`), for a level with `wall_fences` or `wall_fences_partial`. So they only add to the
walls: the pattern picks, the rules, the fillers, the doodads and the credits come out exactly as without
them (`test_wall_fences` compares every campaign level with and without the features; a level without them
draws nothing; `tools/measure/level_pace.gd --dump` of 570 layouts, every campaign level on its own seed and
nine others at 3, 5 and 6 lanes and quick play, against main's: the 330 of levels without them byte for byte
the same, the 240 of levels with them the same but for their wall fences). Where they may stand is one list
of keep-outs per wall (`WallFencePlacement.keep_outs`, times from `WallFenceTuning`,
`data/tuning/wall_fences.tres`, seconds at the level's run speed, so they keep their seconds at every zone's
pace):
- its wall: no sign or window cyborg within `wall_clear_seconds` of it on its wall (GDD §9.1: never on the
  same wall section), no wall vent's screech from `vent_before_seconds` before it to `vent_after_seconds` after,
  and never where a ramp launches the player along its wall (GDD §9.1), from just before the ramp to past the
  end of the longest wall run it can launch: `RampLaunch` with R1's fading boost, claws' longer wall runs and
  a speed pad's boost carried onto it (`ramp_run_end`), plus `ramp_after_seconds`;
- the floor beside it: a player already on the wall sees it on, or its warning, in time to drop off or time it
  (the brief). Its warning is the floor fence's (the same flicker and crackle, `fence_pulse_warning`), and a
  drop-off is a wall jump into the outer lane on its side, landing about 0.5 to 0.7 s later, so that lane holds
  no hole, fence, floor cut, anti-grav pad or floor enemy over its drop window (`drop_before_seconds` before it
  to `drop_after_seconds` after: where a drop-off from as late as its warning lands), and no hover truck keeps
  that lane meanwhile;
- what runs meanwhile: no floor cut's window (B4: nothing else goes on during a cut) and no big attack (the
  keep-out of a drone wave, a hover truck, an Octodog or a floor cut's cause, `LevelGenerator.enemy_keep_out`;
  each of a Resonator's pulses, from its warning until its wave has passed the player, `resonator_pulses`,
  since between its pulses nothing asks for the wall; and every Bad Dream chase) reaches its drop window (the
  wall is one of their escapes; the fill pass keeps its extra obstacles off them the same way);
- the level: its drop window between the run-up and the end-clear stretch; other wall fences
  `same_side_gap_seconds` apart on one wall (a wall run meets one at a time) and `gap_seconds` on either.
Zone doodads need no rule: they stand in inner lanes and push only into neighbouring lanes, never onto a wall,
and a wall fence never reaches a floor runner, so the two never meet (G5's keep-outs stand as they were).
How many: from the feature's start a spot every `spacing_seconds_easy` to `_hard` of run (by the difficulty
there, `spacing_jitter` either way), on a random wall (the other if it has no fair spot within
`search_seconds`), at the first fair spot from there; past `wall_fences_partial`'s start `partial_share` of them
cover the low or the high band. Each pulses with on and off times from easy to hard and a random phase. A level
that gives a feature a start introduces it gently (Marketplace 2's full-height ones at 10%, Corporate 1's partial
ones at 50%, `feature_starts`): its first one is the introduction, at the earliest fair spot on either wall within
`intro_seconds` of the start where no enemy is about (else the earliest fair one there, and only if none comes in
time, a later one; a long big attack can hold it back, which stays rare), alone (no other wall fence within
`same_side_gap_seconds` on either wall) and off for `intro_off_seconds`, with its first-encounter hint on
the level introduction (HintDirector: `wall_fence`, `wall_fence_low`, `wall_fence_high`). Every feature appears: the guarantee
(`placeable_features`) counts only features with patterns, so the placement keeps its own: a level left without a
full-height one (or a partial one, with that feature) gets one at the first fair spot past its start, and one
with no fair spot at all a warning (the campaign tests fail on any). `feature_positions` finds full-height ones
for `wall_fences` and partial ones for `wall_fences_partial`. Measured on each level's own seed and nine others
at 3, 5 and 6 lanes: about 10 to 14 a level, 4 to 6 a minute (Marketplace 2 about 12, the Corporate zone about
14, the Dead Zone about 12, the Golden Zone about 10 to 12, where big attacks leave less room), half of them
partial past `wall_fences_partial`'s start (a third of Corporate 1's, which brings them in halfway).
`LevelGenerator.wall_fence_problem(entry)` (`WallFencePlacement.problem`) says why one can't stand somewhere,
and `cut_problem` refuses a floor cut whose window reaches a wall fence's drop window (a boss arena's; a
level's wall fences come after its cuts). `LayoutChecks.check_wall_fences` (from `check_layout`) holds every
generated layout to all of it independently, at 3, 5 and 6 lanes. DESIGN-TBD (`docs/questions/b5.md`): every
number in `WallFenceTuning`, the bands and the reach, partial ones pulsing too, and keeping off big attacks.

**Wall fences on the track.** `TrackBuilder._build_wall_fence` builds each as a Hazard in the chunk where it
stands: its hitbox `WallFencePlan.hitbox` (from the wall face out by the reach, over its band, a fence deep),
electrical, on the hazard layer only (Damage and interactions), pulsing on the level clock like a pulsing floor
fence (`Hazard.setup_pulsing` with its on and off times and the floor fence's warning, and the floor fence's
crackle from `HazardTelegraph`), switched off for good by an EMP (`disable_fences_near` also reaches wall fences
within its radius, measured from their wall face, built or not yet built), and dressed by the skin
(`ZoneSkin.wall_fence`, Zone skins). `track.wall_fence_hazards()` lists the built ones. A track that grows during
play (`extend_layout`) takes wall fences too, and a boss arena carries them (`BossArena.shifted`, `add_pieces`,
`wall_fence_problem`).

The Gilded Sentinels (task C4) come before the wall fences: `WallFencePlacement.keep_outs` keeps a wall fence
off a Sentinel's wall section (`sentinel_wall_section`: its wall-run approach to past what it cuts), and its
whole attack is in the rules' keep-outs in every lane (`gilded_sentinel_rules.gd`'s `doodad_keep_outs`), which
every drop window keeps off like a Bad Dream's chase; `LayoutChecks.check_wall_fences` checks both. A
Sentinel's own rules also refuse a wall fence on its wall section, for a track where one came first.

For task E5a (The House, GDD §10: phase 2 puts one 7 button on a wall "with wall fences in play"): plan the
phase's wall fences as `WallFencePlan.make` entries at the arena's speed (`arena.tuning`), ask
`arena.wall_fence_problem(entry)` for each (the level's rules on the arena's track; a button on a wall is the
boss's own business: keep the button off a live wall fence's band and timing, and its approach off its drop
window), and add them with `arena.add_pieces()` (their `wall_fences`), past `stream_from()`. A wall fence on
the button's wall should let the player reach the button by timing or by entering high or low (a partial one
over the band the button isn't in). The wall fences pulse on the level clock like any; one the fight must
switch on or off at a moment of its own can be found with `world.track.wall_fence_hazards()` and held with
`Hazard.set_enabled()` (the EMP's way), never by another path, so DamageRules and the looks stay as they are.
Task E5b-a does the same for Hostile Takeover's partial wall fences along the sound barriers (`HostileTakeoverBoard`). E5a-b does
it in `TheHouseWalls` (see The House under Bosses): full-height wall fences, the wall run over the button
timed through their off windows, and the machine's strikes kept off their drop windows.

**Side wall gaps** (the `wall_gaps` feature, every level from Gangland 1 on; owner's answers in
`docs/USER_REQUESTS.md`). `LevelLayout.wall_gaps` holds {side, start, end} (left out of `to_dict()` when empty):
a stretch [start, end) where that wall has no wall-running surface. The interval queries are
`wall_supported(side, d)` (static `wall_supported_in` for a bare list), `wall_gap_between`, `wall_solid_pieces`,
`wall_gap_pieces` and `wall_gap_spans`. The generator places them after the wall fences and before
GapDensity and the credits (`WallGapPlacement` in `scripts/world/wall_gap_placement.gd`), from a stream of
their own (`rng_for("wall_gaps")`), so a level is otherwise exactly the same without them, apart from the
wall credits a gap takes (`_drop_unsafe_credits`). They are rare: one about every `spacing_seconds_easy` to
`_hard` seconds, `length_seconds_min` to `_max` long, a `bilateral_share` of them over the same stretch of
both walls (`data/tuning/wall_gaps.tres`, seconds at the level's run speed). Each wall keeps clear of the
run-up, the end-clear stretch, signs, wall fences, wall enemies (a Gilded Sentinel's whole wall section),
ceilings over the outer lane, and a ramp's launch and longest wall run (`WallGapPlacement.keep_outs`, each
widened by `clear_seconds`). The outer lane beside a gap is deliberately not kept clear: the owner wants
players to read gaps coming. A level with the feature always gets at least one gap. Boss arenas never get
any: `BossArena.base_config` strips the feature and `WallGapPlacement.is_boss_arena` refuses an `_arena` config.

On the track, `TrackBuilder._build_chunk` asks the skin for `wall_section` over the solid pieces only and
`ZoneSkin.wall_gap(parent, side, face_x, start, end, gap)` over each gap's part in the chunk (with the whole
gap, so its ends are drawn once). The default look (`standard_wall_gap`) is an orange lip along the floor
edge, dark caps where the wall is cut, and orange stripes up the cut edges, the leading one brighter. Zone
skins add their floor-level dressing under the left wall (street, walkways, stalls) and leave out
overhead pieces. `ZoneSkin.note_wall_gaps` lets a skin that draws an element whole by its centre leave out
one that would reach into a gap (the Marketplace's shop windows).

The player (`Player.wall_gaps`, the layout's own list, set by `RunWorld`) checks `wall_supported` each
frame on the wall: in a gap it leaves the wall into the outer lane with no extra velocity (`wall_gap_drop`;
ScoreKeeper ends the wall run). A wall entry (move or ramp) inside a gap is refused with `wall_missing` and no
bump. Past the gap, the usual move input steps back onto the wall. `HintDirector` introduces them through the
`wall_gap` hint. `test_wall_gaps` covers all of this.

**Wider gaps** (task G7; the owner's answer to open question 352, October 7, 2026, GDD §9.13 "Holes": "every
level has a couple of wider gaps. They're uncommon, still jumpable by the player, and wide enough that an
Enforcer following the player into one is wrecked"). `WideGapPlacement` (`scripts/world/wide_gap_placement.gd`;
numbers in `WideGapTuning`, `data/tuning/wide_gaps.tres`, F6 "Wider gaps") makes `LevelConfig.wide_gaps` rows of
holes (a row: the holes sharing a start and an end, `GapDensity.rows`) longer along the run than the rest:
`jump_fraction` (0.7) of a full jump at the level's speed (`length_for`), more than an Enforcer Truck hops
(`max_hop_jump_fraction`, 0.6) and within what a level may ask a runner to jump (`max_gap_jump_fraction`,
0.8); the levels' own rows are 0.4 to 0.55 of a jump. A normal jump clears one from a take-off window about
0.3 s wide (with coyote time). Every campaign level asks for 2; quick play, the prototype level and boss arenas
(`WallGapPlacement.is_boss_arena`, even asked) for none, and then the pass draws nothing.
- **When.** After the enemy rules, the danger density pass's enemies and the cyborgs planted in charge paths
  (below), before the fill pass, from a stream of its own (`rng_for("wide_gaps")`). The level's own rows it
  makes longer it makes longer only once the fill pass has run (`widen_deferred`): a filler keeps the level's
  spacing and `FILL_TAIL_SECONDS` more from every piece, more than a row's landing margin once it's longer (it
  grows by 0.2 s of run at most), so the fill pass is built as without them, and a filler the longer row would
  come nearer than that goes, so every filler keeps its spacing from the level as built (none in the levels' own
  builds; 2 of 135 builds on other seeds); the new rows and the rows it clears room for come before it, and the
  fill pass keeps off those. The report is `LevelGenerator.wide_gap_result` (target, rows, how many were
  widened, added or cleared and how many pieces went, what blocked the level's own rows, constraints, the
  widenings deferred), reset at every build of the guarantee.
- **Never stacked with another demand** (`fits`, `blocker`). Its zone (`zone_of`: from `clear_before_seconds`
  before the take-off to `clear_after_seconds` after the landing, 0.9 s each, never less than the level's
  spacing between two patterns at its difficulty, or its burst spacing in The Hush) holds, in any lane (a piece
  that only touches its end is out of its way), no other hole, fence, ramp or the point
  where its wall run drops the runner back, pad's zone, speed pad, ceiling's landing zone, floor cut's window,
  enemy's attack (the fill pass's keep-out with its floor; a floor cyborg's obstacle margin; a planned
  Resonator's pulses one by one, `DangerDensity.resonator_pulse_windows`: between them it only hovers and every
  pulse waits for clear floor) or the rules' doodad keep-outs (a Gilded Sentinel's strike; not a host's Bad
  Dream chase, which the danger density pass exempts too, `keep_out_exempt_features`). No ceiling, no
  ramp's wall run and no calm stretch (an Enforcer Truck's showing window, task C6c) lies over the jump itself
  (`row_only` keeps). A keep of one lane only (a hover truck's lane
  for its whole stay, beyond the stretch it's surely there, which every lane keeps) keeps that lane: the row
  leaves it open. Window cyborgs and Barnacle Turrets (their bolts never land near a hole), thieves and the
  Enforcer Truck (`NO_KEEP_TYPES`) don't count. Wider gaps keep `spacing_seconds` (15 s) apart.
- **Where from**, in this order until the level has its count: the level's own rows made longer (at the far
  edge, the take-off where the pattern put it, else the near edge, else both); with `add_rows`, new rows in
  every lane but one (the lane a hover truck keeps there, else a seeded one), slid along each free stretch
  until one fits (`_add_one`); the level's own rows that only other holes and plain fences keep from fitting,
  with those taken out (`_clearing`: never a pulsing fence or one a fence generator powers; `GeneratorRules.
  keep_powered` after: taking content out never makes a level unfair).
- **Which.** With `prefer_enforcer_chases`, one first in each Enforcer Truck's chase (from `bait_after_seconds`
  after it arrives to `CHASE_END_SECONDS` before it gives up), from the first source with one there, so the
  runner can lead it in; then the rest spread through the level, each source used up before the next, rows
  across most of the lanes (a jump) before single holes.
- **After it.** The fill pass keeps its usual margin from the wider rows as from any piece; the danger density
  pass's floor pieces keep off each zone as it stands (`DangerDensity._index_obstacles`: its margins are the
  level's spacing already), City 1's extra gaps keep it narrowed by their own margin (`GapDensity._protected`,
  `keep_outs(gen, within)`), a zone doodad whose window would reach a landing margin is left out
  (`LevelGenerator._add_doodad`, `doodad_keep_outs`: before a piece a doodad keeps the level's spacing anyway), so
  the doodads stand where they would without the wider gaps' margins, and side wall gaps keep
  `wall_gap_clear_seconds` off each on both walls (`wall_keep_outs`). City 1's extra gaps come after the doodads,
  and FIX4 lets a doodad send one of them elsewhere (a full-width widening or a new row keeps its margin from a
  doodad, `docs/questions/fix4.md`); the wider gaps re-rolled City 1 at 3 lanes into that case, so
  `test_doodads` holds City 1 to its own gaps unchanged and as many extra ones there.
- **What it gives.** Every campaign level at 3, 5 and 6 lanes gets its 2 on its own seed (`test_wide_gaps`);
  over `test_campaign`'s seed sweep 2 of 189 builds of the busiest levels fit only one (the layout check allows
  one fewer on a seed not the level's own, never none). An Enforcer chase holds one in 11 of the 18
  level and lane builds that have trucks, Corporate 2 at every lane count, where the truck following the runner
  over it is wrecked in play. Rows and holes change a little: the City levels keep theirs (one hole fewer in
  City 2 at 5 lanes), and elsewhere the fill pass and the danger density pass re-roll around new rows and the
  zones (every level at 3, 5 and 6 lanes: 1,093 rows and 2,510 holes before, 1,089 and 2,533 after; Corporate 2
  at 5 lanes 33 and 49 before, 35 and 54 after; Dead Zone 1 at 3 lanes 24 and 32, then 21 and 27). With
  `wide_gaps` and `charge_path_cyborgs` at 0 every campaign level, quick play and the prototype level build
  exactly as before (compared build by build with main's).

**Cyborgs in charge paths** (task G7; the owner's answer to open question 353, October 7, 2026, GDD §9.13
"Teaching": "occasionally a cyborg stands in the path of an Octodog's lunge or a Buzz Overdrive's charge, so the
player sees a charge flatten another enemy. At least one comes before the Enforcer's first appearance in
Corporate 2"). `ChargePathPlacement` (`scripts/world/charge_path_placement.gd`; numbers in `ChargePathTuning`,
`data/tuning/charge_paths.tres`, F6 "Charge paths") plants a plain floor cyborg in the path of up to
`LevelConfig.charge_path_cyborgs` of a level's Octodog first lunges and Buzz Overdrive charges (1 in every level
with either, Gangland 2 on; 0 elsewhere), which the charge flattens (`Enemy._hurt_charge_contacts`,
`&"enemy_charge"`, never the player's kill). It runs after the danger density pass's enemies, before the wider
gaps and the fill pass (every dog's charges and every cut are final then), from `rng_for("charge_paths")`; its
report is `LevelGenerator.charge_path_result` (target, planted, options, rejected: why each other encounter was
turned down, constraints). `plant()` writes one encounter, and the tests plant through it.
- **The cyborg.** `{type: "cyborg", side: 0, params: {panic: false, host: false, stand: true, hold_fire,
  charge_path}}`: never a host, the panic variant or a window cyborg; it stands where it's placed
  (`Cyborg.stand`: no walk), and holds its fire while the runner is in its `hold_fire` stretch, from
  `hold_before_seconds` (1 s) before the charge's warning until `hold_after_seconds` after it has passed them,
  with no bolt of its landing there (`Cyborg._may_attack`, `CyborgGun.hold`). It keeps a cyborg's obstacle
  margin and every ceiling's safe floor, stands `CALM_ROOM` or more off every calm stretch (an Enforcer Truck's
  showing window, task C6c: the encounter's span itself may reach one, `attack_near` leaves them out), and it
  never counts as the level's cyborg (`feature_positions`).
- **An Octodog's planted lunge.** Only its first, made from where it stands. The cyborg stands
  `dog_cyborg_ahead` (2.5 m, or a little more, stretched by the pace) in front of it in the lane beside, and the
  dog's params (`through_lane`, `through_at`) send its lunge along a line through it, two lanes across: it
  flattens the cyborg about halfway and reaches the far lane where it would meet a runner there
  (`Octodog.planted()`, `_lunge_vx`); its red line shows that path, so it's dodged as any lunge. The dog's
  later charges go at the runner's lane as always. A dog without two lanes beside it on a side may stand in
  another lane at its spot (`_dog_lanes`); never a gap bait; the line's path keeps off every hole
  (`path_clear`); the cyborg is reached with the runner still `in_view_seconds` (0.4 s) behind it (`dog_in_view`).
- **A Buzz Overdrive's parked charge.** Its cut gets `park`: the tank waits at its cut's end (`BuzzOverdrive.
  parked()`) instead of rolling ahead of the runner (it would drive through a cyborg in its lane), revs and
  charges where it always would, and the cyborg stands `tank_cyborg_seconds` (0.35 s of run, or a little less)
  in front of its blade, in its lane, past where the cut meets the runner, reached in view (`tank_in_view`).
  The cut keeps its own escape (`LevelGenerator.cut_escape_clear`).
- **The charge comes as planned.** The encounter claims its turn among the big attacks `claim_seconds` (4 s)
  before its warning: a planted dog from its params' `claim_at` (`Octodog.claiming()`, part of
  `is_major_attack_active` while it stands), a parked tank from its cut's `claim_seconds`. A drone's barrage or a
  hover truck's lurch or cannon shot that gets ready meanwhile waits. What can't wait or claims a turn of its
  own (a Bad Dream's chase, a Resonator's pulse, a Gilded Sentinel's strike, another Octodog's run or Buzz
  Overdrive's attack, a hover truck keeping one of the encounter's lanes) keeps `attack_margin_seconds` (2 s)
  from it (`attack_near`). Never the encounter that introduces the charging enemy (`skip_introductions`). The
  danger density pass counts the level's enemies before it (its tests leave planted cyborgs out of both counts).
- **What it gives.** At 3, 5 and 6 lanes, 7, 6 and 8 of the 11 levels that ask get one (the others: near a
  Resonator's pulse or a Gilded Sentinel, no room for the cyborg, or only the introduction); at every lane count
  one comes before Corporate 2's first Enforcer (Marketplace 1 at 3 and 5 lanes, Gangland 2 at 6). DESIGN-TBD
  (`docs/questions/g7.md`): the line, the parked tank, the numbers and the counts.

## Power-ups

`PowerupController` (`scripts/powerups/powerup_controller.gd`) runs one `PowerupModule` per owned,
switched-on permanent item: `WeaponPowerup` (auto-fire, tiers 1–4, enemy health bars), `ClawsPowerup`,
`DashPowerup`, `MagnetPowerup` and `SlowTimePowerup`. The armor is the damage rules' (`DamageRules.Armor`,
see Damage and interactions); the breakables (shield, grapple) are charges on the Player. The
controller's header documents its API: `hud_state()` for the HUD (`charges` -1 for permanent items; the
armor's hits, with its return as `ready`), `equipment()` for the player model, and `try_dash()` /
`try_slow_time()`.
Dash has four permanent tiers: prices 1,800 / 800 / 1,000 / 1,200 credits in the shop catalog, with
cooldowns 8 / 6 / 4 / 3 seconds in the powerup tuning resource. Its module selects the owned tier
for both runtime readiness and the HUD. Existing tier-1 ownership and equip state need no save migration;
the generic shop advances sequentially and marks tier 4 maxed.
The player model shows what the run carries (`PlayerAvatar.set_equipment`, looks in `PlayerSuit`): the
weapon sits over the gold arm's (left) shoulder, so shots leave from there (`Player.weapon_muzzle()`),
and armor that breaks in play shatters. Effects tied to the runner's own glow (the dash's shell and
lines, the invulnerability tint) use its copper, thinned toward white; the shots keep their colours.

## Pickups

GDD §10 puts armor, shield and grapple pickups in boss fights (the standard armor rule, and fights
that offer their own), never in levels, so no pattern places one. `PickupField`
(`scripts/run/pickup_field.gd`, in every `RunWorld`) runs them; its numbers are in
`data/tuning/pickups.tres` (`PickupTuning`, F6).

- **Offers:** `offer(item, at, lane)` (a boss calls `BossEncounter.offer_pickup`) queues a pickup,
  which appears at the first fair spot, now or as soon as there is one: at least `lead_distance`
  ahead (within `search_window` beyond, on the built track), at most `reach_lanes` from the player's
  lane (nearer lanes first), with `clear_before` of floor before it and `clear_after` after it free of
  gaps, fences of any kind, pads, ramps, speed pads, ceilings overhead and enemies (planned on the
  track near the lane, or in play: any hitbox, fence, block or lane blocker up to `clear_height`), and
  no boss floor warning over it (`BossProps.warned`). `at` and `lane` are requests the rules still
  apply to. `find_spot()` and the static `layout_fair()` answer placement questions for tests.
- **Taking:** the player's hitbox (swept over the frame) reaching its `take_box()` takes it:
  `Player.gain_item(item, max_charges)` adds a shield or grapple charge unless the player holds all they
  may, the `Loadout` counts it in `picked_up` (the App asks `Loadout.costs_stock()` when an item breaks,
  so a picked-up charge, like a granted one, never costs stock), and `collected(pickup, gained)` fires.
  An armor pickup brings the armor back whole at once (`DamageRules.Armor.take_pickup`: on whole armor it
  adds a hit, up to `GameRules.armor_pickup_extra_hits`), and isn't counted: the armor is no stock. The
  HUD shows the item in its place among the protections and flashes it; the power-up controller lists
  it in `hud_state()` and the player model shows armor and shields. A pickup the player runs past is
  `missed` and gone. `clear()` removes everything (a boss beaten: none after the fight).
- **Look:** `Pickup` (`scripts/run/pickup.gd`, `pickup.gdshader`) is the HUD's round badge for the
  item standing upright at chest height: the item's icon white-hot on a dark disc in a white ring,
  with a halo and a floor glow, bobbing but never spinning, the same in every zone. Neutral whites keep
  it clear of every hazard colour; its size and icon keep it apart from credits. Sounds `pickup_appear`
  and `pickup`; a first-encounter hint per item (`pickup:<item>` in `data/hints/hints.json`). Pickups
  are pooled.
- **Review:** quick play's `--pickups[=armor,shield,grapple]` offers them in turn (debug builds).

## Zone skins

A `ZoneSkin` (`scripts/world/skins/zone_skin.gd`) decorates abstract pieces through hooks
(`floor_segment`, `floor_cut`, `wall_section`, `fence`, `wall_fence`, `wall_sign`, `ceiling_section` (by
default `hull`), `pad`, `ramp`, `speed_pad`, `doodad`, `finish_line`, `make_environment`). Skins add visuals
only, never collision or gameplay. Hazards keep one colour and shape language in every zone (pink
crackle = electric fence).
`TrackBuilder` also calls `note_wall_enemies(side, start, end, enemies)` just before `wall_section()`
for each side (a no-op default): the chunk's wall enemy layout entries (type, at, side, ...), for a
skin whose own scenery would otherwise double up with one (the Marketplace's citizens, task D3, kept
clear of window cyborgs) or make room for one (the Golden Zone's skins open a Gilded Sentinel's niche,
task C4); read-only and visual only, like every other hook.
In a run, a chunk's hooks come over the few frames after its gameplay nodes are built, in order, each
side's `note_wall_enemies` and `wall_section` in one go (`TrackBuilder.dress_budget_usec`, task PERF1;
A run, Smooth frames): a hook never counts on the frame it's called in, and a hazard's look shows the
hazard's state when it binds (`HazardStateVisual.bind`). Tests and review tools dress each chunk at once.

**Zone doodads' looks** (task G5 built the mechanism and a plain default; task G6 gives each zone its
own, except the grey box, which keeps the plain default. `GoldenPalaceSkin` (D6b) extends `GoldenSkin`
and doesn't override `doodad()`, so the Golden Palace inherits the Golden Zone's gilded planters,
fountains and statues for free, unless a follow-up gives it its own interior ones.) What a look gets
and keeps to:
- *The hook*: `doodad(body, size, size_class, side, look_seed)`. `body` is the doodad's node, centred on
  its collision box `size` (width, height, length): the floor is at -size.y / 2 and its front, where the
  player meets it, at +size.z / 2; add meshes as its children. `size_class` is `&"small"`, `&"medium"` or
  `&"large"` (`LevelLayout.DOODAD_SIZES`), whose boxes come from `MovementTuning.doodad_size()`: by
  default 1.3 × 1.4 m, 1.9 × 3.6 m and 2.0 × 6.5 m (width × length), all 2.6 m tall (DESIGN-TBD). Map
  each class to the zone's pieces of that size. `side` is the side it pushes to (-1 left, +1 right) and
  `look_seed` a number to vary the look by (which model, a tint, its props), hashed with `MeshKit.hash_i`
  like everything else in a skin: never a random number generator, so a doodad looks the same wherever
  and whenever it is built.
- *Inside the box, filling most of it*: what looks like contact is contact (GDD §3), and it must read
  as too tall to jump (it is) and as wide as it blocks. A burned-out car is lower than 2.6 m: stack it,
  tip it on its side or pile its wreck high. Nothing outside the box (an awning, a branch, a sign arm):
  the player would pass through it. Placing a piece by a formula that fits its own size against the
  box's remaining room (`x = (hash01 - 0.5) * (size.x - piece_w)`, and the same for z and for a stack's
  height) keeps every seed inside the box by construction; a piece built with any rotation needs a wider
  margin budgeted in by hand (the Dead Zone's leaning masonry works out its own tilted bounds this way)
  since `MeshInstance3D.get_aabb()` is exact and every skin suite's `doodads_ok` (below) will catch a
  margin that was cut too fine.
- *Solid and safe* (CLAUDE.md readability rules): the zone's non-hazard colours, nothing glowing in a
  hazard colour (pink, yellow and black, red, orange, green, cyan), nothing that reads as a sign (no
  striped frames), a fence (nothing strung between posts), a barrier or an enemy (no eyes, no faces on
  screens; the cult's feed is the walls' business). Warm-white or zone-coloured lamps are fine if small.
- *Its push side may show* (the default's front slants back toward it); nothing more is needed.
- *Cheap, and on the shared material alone*: one mesh per doodad from cached templates (the kit's
  `MeshBatch`, one layer, so a doodad is always one draw call however many of the kit's surface patterns
  it mixes), fine on the Compatibility renderer. Every doodad's `MeshInstance3D.material_override` is the
  plain `MeshKit.solid()` (no params), never a zone's own tuned `solid_material()`: `test_doodads`'
  `_test_skins` and each skin suite's `doodads_ok` (`tests/helpers/skin_suite.gd`) hold every skin to
  this, so a doodad never glows and always renders through the one shared material instance (cheaper:
  one less state change) across every zone. It still dims with a level's darker lighting like the
  scenery (The Hush): `scenery_light` is a *global* shader uniform, so even the bare material reads it.
- *The default* (`default_doodad_mesh`): a low-poly block in the skin's `doodad_palette` (body, top,
  base), still used by the grey box and by any new zone before its own task gives it a doodad() of its
  own: a base plinth, an inset body and a top, its front slanting back toward its push side.
- *Each zone's own look* (task G6; `scripts/world/skins/<zone>/<zone>_doodads.gd`, called from the
  skin's `doodad()`): the Neon City (`CityDoodads`) maps the three classes straight to the GDD's three
  ideas, smallest first: a pillar, a tiny market stall (a counter, corner poles and a flat canopy) and a
  small storefront (a facade slab with a window row and a signboard lip). Gangland (`GanglandDoodads`)
  gives the small and medium classes a burned-out car each (one wreck, then two nose to tail), both
  crushed low with scavenged salvage piled on top up to the box's top (GDD §3's "stack it... or pile its
  wreck high"), and the large class a broken-down shop (boarded shopfront, a pulled shutter, a sagging
  roof lip, rubble at its foot). The Marketplace (`MarketDoodads`) gives the owner's "plenty of nice
  plants, casino machines": a tall potted plant (small), a bank of two casino cabinets along the box's
  length with a dim screen face and a marquee hump, never as bright as a hazard sign (medium), and a
  planted hedge row of three stems of varying height (large). Corporate (`CorporateDoodads`) covers the
  owner's list directly: a steel planter (small); a security barrier (a wide olive block and a watch
  mast) or a glass kiosk, picked per doodad by `look_seed` (medium); a sculpture plinth, an abstract
  steel form built from offset slabs with a brand-paint accent (large). The Dead Zone (`DeadDoodads`)
  takes the GDD's three ideas directly, smallest first: a crushed, ash-dusted wreck with rubble piled on
  it (small), a rubble heap of stacked, irregular concrete chunks (medium) and a slab of fallen masonry
  leaning across the lane at a shallow angle from vertical, with a crumbled edge and rebar (large). The
  Golden Zone (`GoldenDoodads`) takes the owner's "gilded planters, fountains, statues on plinths": a
  gilded planter with stylized gold reed fronds (small), a fountain with a still marble basin and a thin
  falling jet of water (`MeshKit.PAT_WATER`, scenery only, GDD §5; medium) and a robed statue on a
  plinth (large) -- deliberately not the Gilded Sentinels' armoured guard with a halberd (`GoldenStatue`,
  task C4). The decorative wall guards now also stand at the wall base, but this lane doodad
  never reuses their kit or its shape -- a plain draped, faceless figure with its hands clasped and
  nothing raised -- so it can never be mistaken for the live enemy even up close. `test_golden_skin`
  guards against the doodad script ever building itself from `GoldenStatue`.
  None of the six needed a new mesh-kit pattern or shader include: the kit's existing patterns (e.g.
  `PAT_GOLD`, `PAT_MARBLE`, `PAT_DZ_CONCRETE`, `PAT_CORP_PLATE`, `PAT_TECH`) already cover every zone's
  materials, each skin picking its own colours for them through its "Doodads" export group.
- *Tested*: `test_doodads`' `_test_skins` builds every skin's doodads in every class (seed 7 alone) and
  checks the box, that nothing glows and that `doodad_palette` is muted. `SkinSuite.doodads_ok(skin,
  name)` (`tests/helpers/skin_suite.gd`), which every zone's own suite calls, extends this over several
  seeds and both push sides: dressed, inside the box, on the shared `MeshKit.solid()` alone, never
  glowing, and the identical (cached) mesh every time the same size, side and seed are drawn again.

**Floor cuts' looks** (B4; GDD §9.9: the floor a cut takes "becomes a gap ... The cut edges glow the
usual gap-edge orange"). The track draws a cut lane's floor itself, in slices of the skin's own
`floor_segment` it hides and shortens as the cut runs (The generator, Floor cuts on the track), so the
hook `floor_cut(parent, cut)` draws only the hole, from a `FloorCutSection`
(`scripts/world/floor_cut_section.gd`: the lane, its floor's edges, the stretch, the wall faces) in four
kinds of part the cut then moves: `add_static` (the inside over the whole stretch, below the floor,
never moved), `add_span` (the orange lips along the neighbouring lanes' edges, built over the whole
stretch and scaled to what's cut), `add_front` (the lip on the whole floor's far edge, moved with the
front) and `add_far` (the far side: the lip on the floor beyond, a strip along its face, a halo). It
must read as a hole at a glance like any gap: orange edges right on the collision edge, a dark inside,
nothing else glowing, nothing flickering. `ZoneSkin.standard_floor_cut(parent, cut, solid, glow, style)`
builds all of it from a style (the edge and inside colours, the inside's darkening pattern, depth, lip
sizes and glows, a dark line beside the lips, the inside's walls and ribs); the default hook uses it
with the skin's `gap_edge_color` and `gap_inside_color`. The zones where the Buzz Overdrive appears draw
their own floor's cut: Corporate's maglev a carriage roof sliced open down to its frame
(`CorporateTrains.cut`), its plaza the deck split over the lower level (`CorporatePlaza.cut`), the Dead
Zone's street split with broken plates hanging into the void (`DeadStreet.cut`), the Golden Zone's
walkway cut over the canal (`GoldenWalkways.cut`) and the Golden Palace's marble floor broken into the
well (`GoldenPalaceFloor.cut`). `test_floor_cuts` builds every skin in `data/skins/` (and the grey box
and the plain `ZoneSkin`) at 3 and 5 lanes, in an outer and a middle lane, and checks the orange edges
on the collision edge, a dark inside, nothing else glowing, and the build cost against the same chunks
without a cut; review a new look with `floor_cut_review` (Review tools) on both renderers.

**Wall fences' looks** (B5; GDD §9.1: "the same pink crackle, strung across the wall-run path between emitters
on the facade, the way a floor fence crosses a lane"). The hook `wall_fence(hazard, size, side, band, floor_y)`
draws one in hazard-local space, centred on its hitbox `size` (x from the wall face on `side` out toward the
lanes, y up its band, z along the track), and `band` (&"full", &"low", &"high") says which part of the wall it
covers. It must read as the floor fence turned onto the wall, in every zone: the same pink field (the zone's
`fence_field_materials()`), an emitter at each end of its band on the facade whose glowing strip marks the
band's edge (the line a partial one is passed above or below), nothing else glowing, the look within the
field's reach of the facade (never out over the outer lane's runner), following the hazard's state (ON,
WARNING with the flicker, OFF with no field: `HazardStateVisual`, steady with Reduced flashing as the fence
shaders are). The default (`standard_wall_fence`) works for every zone, the grey box included:
`MeshKit.dress_wall_fence` with `wall_field_mesh` (three cards through the field's depth, UV.x up the band so the
energy field shader's arcs run from one emitter to the other, its bright edges along the facade and along the
field's outer edge) and `wall_fence_mounts` (a plate on the facade and an arm out over the field at each end of
the band, a sill at the foot of the wall for a band that starts at the floor, in `wall_fence_mount_color`, an
export on ZoneSkin, with the zone's `fence_part_materials()` for the glowing strips and caps and its
`solid_material()` for the housings; `wall_fence_look()` falls back to the kit's own materials and pink for a
skin without them). A zone may override `wall_fence()` to draw its own emitters around the same field.
`test_wall_fences` builds every skin in `data/skins/` (and the grey box) at 3 and 5 lanes on both walls in every
band; review a look with `wall_fence_review` (Review tools) on both renderers.

**Ceilings from their lanes** (B3). `TrackBuilder` (and `BossProps.ceiling`) describe each ceiling as a
`CeilingSection` (`scripts/world/ceiling_section.gd`): its span along the track, the lanes it covers
(`first_lane`, `last_lane`, `full()`), its collision box (`center`, `size`), the lane seams inside it
(`lane_edges_x`), the wall faces' distance (`wall_x`) and whether each side reaches the street's edge
(`reaches_wall(side)`), and hand it to `ceiling_section(parent, section)`. A skin builds the ceiling from
those, never from the track's width, so a narrow ceiling is simply a narrower one: the City's is a smaller
craft (`CityShip`, `small`), Gangland's a slab broken off a building, the Dead Zone's a slab broken off
the tower it reaches or a fallen span, and the Marketplace's, Corporate zone's and Golden Zone's kinds
build narrower (a structure that needs both walls, the Marketplace's building bridge, the Corporate
tower across the street, the Golden arches, becomes another kind over fewer lanes). The default hook
calls the older `hull(center, size, lane_edges_x)`, which the grey box still uses. Every ceiling's underside covers its footprint and stops at a free side's edge, nothing hangs
below it, and the orange end band (`MeshKit.ceiling_end`) spans its width.

**Nothing below the underside past a far end.** When the player drops off a ceiling's far end, the chase
camera follows them down and passes just below the underside there: `RunCamera.ceiling_limit` keeps it
`camera_ceiling_clearance` (1 m) under any ceiling over it, beside it (a narrow one), just ahead or just
behind (the review tools' camera copies use it too). Whatever a skin draws below the underside past the
far end fills the screen for a frame as the camera passes (task B3 found the end band's glow card doing
it in every zone: an orange wash and a glare), so past a far end glows and faces stay above the
underside: use `MeshKit.ceiling_end` for the band, `MeshKit.stern_halo` for an engine's halo (cut at the
underside), and `MeshKit.near_fade(metres)` as a glow card's `param` for any other glow the camera
passes close to (kit_glow reads a negative UV2.y as "fade out within this many metres of the camera").
`test_ceilings` builds every skin in `data/skins/` (and the City boss arena's) over full and narrow
ranges at 3, 5 and 6 lanes and checks all of this, so every zone's skin is held to it, and a new skin
(a level's own, such as the Golden Palace's) as soon as its file exists: build ceilings through
`ceiling_section` (or `hull`) from the section, keep the band and every glow past the far end above the
underside, and check the drop on both renderers (`skin_review --narrow`, Review tools).

Skins: `CitySkin` (Zone 1, the Neon City), `GanglandSkin` (Zone 2), `MarketplaceSkin`
(Zone 3, the Marketplace), `CorporateSkin` (Zone 4, Corporate), `DeadZoneSkin` (Zone 5, the Dead Zone)
and `GoldenSkin` (Zone 6, the Golden Zone). `GreyboxSkin` is the fallback for a zone without its own
look (every zone has one now). A
zone's skin lives at `data/skins/<zone id>_skin.tres` (`--skin=<zone id>` in quick play) and is set in its
`data/zones/<zone id>.tres`; a level's own `skin` wins over its zone's (the Golden Palace, Golden 3,
task D6b, has one: `GoldenPalaceSkin`, below). The real skins build on the mesh kit
(`scripts/world/meshes/`): `MeshKit` has shared builders for hazards, triggers and environments, and
`MeshLayer` batches a chunk's geometry.
The shaders in `scripts/world/meshes/shaders/` are procedural. `HazardStateVisual` swaps a hazard's
ON / WARNING / OFF materials. A skin's `enemy_variant` picks the enemies' look: the cyborgs' zone
variant (GDD §9.2, through `CyborgSuit.look_for()`) and the other enemies' weathering (drones, hover
trucks, Octodogs and screeches weather on `&"scavenger"` and stay clean on anything else). Each zone's
value, the one thing a new zone's skin sets for its enemies:

| Zone | `enemy_variant` | Cyborgs | Other enemies |
|---|---|---|---|
| Neon City | `&"city"` | the base (Static TV Head) | clean |
| Gangland | `&"scavenger"` | the Broadcast Brute | weathered |
| Marketplace | `&"casino"` | the Casino Mob Enforcer | clean |
| Corporate (D4) | `&"vr_runner"` | the Wide-Aspect VR Runner | clean |
| Dead Zone (D5) | `&"burned"` | the base, burned out | clean |
| Golden Zone (D6a) | `&"golden"` | the ceremonial enforcer | clean |

The Barnacle Turret wears its furry creature look on `&"scavenger"` and `&"casino"` (Gangland, the
Marketplace) and its mechanical look on every other value (`BarnacleTurretModel.is_creature`), with its
colours from the zone variant (`BarnacleTurretModel.PALETTES`; a new zone's variant gets the default
gunmetal until it has its own).

The City and Gangland keep their older names because they also pick the other enemies' weathering
(`CyborgSuit.VARIANT_LOOKS` maps them); every other zone sets its cyborg look's own name. A zone that
also wants the weathered enemies (the Dead Zone might) needs those enemies to treat its name like
`&"scavenger"` (a line in each one's look code). A zone on the grey box wears the base; `--variant=` in
the enemy showcase shows any look now.

**A level's darker lighting** (`LevelConfig.darkness`, 0–1; GDD §5, The Hush) reaches every skin for
free: the run takes its environment from `ZoneSkin.level_environment(darkness)`, whose
`apply_darkness()` dims only the scenery. The sky and the distance fog lose energy, and the global
shader uniform `scenery_light` (project.godot; 1 = the zone's own light, never below
`MIN_SCENERY_LIGHT`, 0.3) dims what the scenery's shaders draw: `kit_solid`'s lit surfaces (never its
glowing ones), `facade`, `shopfront`, `road`, `drift`, the Corporate skin's `corp_facade`, the Golden
Zone's `golden_facade`, the Dead Zone's `dead_smoke`, and the grey box's floor, walls and ceilings (`GreyboxMaterials.scenery()`). Glows, the ambient light and the
sun stay, so hazards, triggers, credits, enemies and the runner (lit or glowing by their own
materials) read as well as anywhere. The
factor is given for linear space; `light_factor()` in `kit_common.gdshaderinc` (and
`ZoneSkin.energy_factor()` for the environment) converts it for the Compatibility renderer's sRGB
space, so both renderers dim alike. A new skin gets it by drawing its scenery with the kit, or by
reading `scenery_light` (through `light_factor`) in a shader of its own, or by overriding
`apply_darkness()` (calling it first). Only the run that set the light last resets it when it ends
(`LevelRun`). `skin_review` takes `--darkness=X` to look at it.

**A level's own sky** (`LevelConfig.sky`, a `LevelSky` in `data/skies/`; owner, October 8, 2026). Most
levels keep their zone's sky; a zone's last level may show the time of day or the weather turning, for a
sense of progression: City 3 a dawn (`city_dawn`: the sun about to rise, pinks and purples on the
undersides of clouds), Gangland 3 a cloudy blood-red sky (`gangland_blood_red`), Marketplace 2, the
zone's last level, a sunset (`marketplace_sunset`: deep blue overhead, pink at the bottom of the sky).
`ZoneSkin.level_environment(darkness, sky)` builds the zone's environment, then `LevelSky.apply()` sets
the sky's `night_sky.gdshader` uniforms over the zone's (by name; its colours go as sRGB `Vector3`s, as the
Dead Zone's do, so both renderers draw them alike) and the distance fog's colour (so far scenery fades
into that sky); the darkness comes after, as for any level. Nothing else changes: the ambient light, the
sun, every glow and the fog's reach stay the zone's, so hazards read as in the zone's other levels, and a
sky stays under the glow threshold, so it never blooms (`test_level_sky`). The zone's own environment is
never touched (each `make_environment()` builds its own sky material). The sky shader's looks for a level
sky all default to off, so no zone's own sky changes: `horizon_falloff` (0.55: how far down the zenith's
colour reaches), a glow low over the horizon at a bearing (`sun_glow_*`, where the sun is about to rise
or has just set), and a cloud layer (`cloud_*`: value-noise cloud on a plane overhead, receding to a thin
band at the horizon and stretched across the street; its undersides catch `cloud_lit_color`, the more so
toward `sun_glow_direction` by `cloud_lit_focus` (0: lit from all around, as by Gangland's fires), on the
lower clouds, on their thin edges and on each cloud's side facing the light). The clouds cost six octaves
of value noise per visible sky pixel, only where a level has them; no `TIME`, so the sky's radiance still
never updates. Endless mode, which copies its zone's last level, keeps the zone's own sky
(`App.start_endless`), as do boss fights (`Campaign.configure_boss` builds the arena's own config) and
cinematics (`CineStage`: `level_environment(0.0)`). `skin_review` takes `--sky=name` to look at one.

The kit's solid shader (`kit_solid.gdshader`) draws surface patterns chosen per vertex (`MeshKit.PAT_*`):
panels, glass, glyphs and chevrons for the City; worn asphalt (with sand drifts and scorch around holes),
road strata, salvaged plating, posters (with corporate ads), cast concrete and stencilled crates and
container doors for Gangland; canvas, tin and whole rows of stall roofs, stall faces, tiles, shop
signs, ads, casino bulbs and stucco for the Marketplace; train roofs, the shade below them, paving,
armour plate, corporate ads, the brand's mark on panels, banners and lit glass for Corporate; the
rubble street, the shade below it, gutted towers, charred concrete, scorched steel, dead boards and the
scorched emblem for the Dead Zone; reflective gold, golden walkways, marble, the shade under the walkways, the canal, falling water, the
cult's emblem in relief, gilded coffers, red cloth and boutique boards for the Golden Zone. Features
a zone opts into are uniforms that default to off, so one zone's additions never change another's
look. Painted marks shared between shaders live in includes: `kit_marks.gdshaderinc` (graffiti pieces
and tags, stencil codes) and `kit_logo.gdshaderinc` (`corp_logo()`, the Corporate brand's mark, which
Gangland's corporate crates, containers and ads carry too). Two shader rules: take derivatives
(`fwidth`, implicit texture LODs) outside any branch that can differ between neighbouring pixels and
pass them in, and use `filtered_pulse()` only for ranges within 0–1 (`band()` for any other). Breaking
either can put a NaN in a pixel, and the glow pass blows it up into a white disc.

**Colours in a skin's own uniforms.** A `Color` set on a `vec3` shader uniform reaches the shader
already converted to linear on Forward+ and Mobile, but unconverted on the Compatibility renderer, so a
shader that converts it once more (`to_linear()`, as the kit's do for vertex colours) draws it darker and
more saturated on Forward+ than on the web. The Golden Zone passes its uniform colours as sRGB `Vector3`s
(`GoldenSkin.srgb()`), which arrive unconverted on both renderers and are converted once, like a vertex
colour; the Dead Zone does the same (`DeadZoneSkin.srgb()`, its `dz_*` uniforms and its sky). Likewise
a light factor multiplied in after `to_linear()` scales sRGB values on the
Compatibility renderer; `golden_facade.gdshader` passes every one of its light factors through
`light_factor()` (kit_common), which raises it to the 1/2.2 power there, so its walls are as bright on
both renderers. (The older skins' uniform colours, and the kit's own `shade` factor, still differ a little
between the renderers.)

**Pattern ids.** Ids up to 19 are the City's and Gangland's, in `kit_solid.gdshader` itself; ids 20-29
are the Marketplace's (all in use), in `kit_market.gdshaderinc`, and ids 30-39 the Corporate zone's
(30-37 in use), in `kit_corporate.gdshaderinc`, ids 40-49 the Dead Zone's (40-46 in use), in
`kit_dead_zone.gdshaderinc`, and ids 50-59 the Golden Zone's (all in use), in
`kit_golden.gdshaderinc` (each: one include and one dispatch line in `kit_solid`; the Golden Zone's
and the Dead Zone's includes follow `cult_mark()`, which their emblems use).
A new zone takes the next free block of ten in its own include, so zones built in parallel never
collide on an id. Ids 60-69 are the cult's, shared by every zone, in
`kit_cult.gdshaderinc` (its include follows `cult_mark()` in `kit_solid`, and its dispatch runs after
the zones' own): `PAT_CULT_MARK` (60) draws the cult's emblem from the material's `cult_emblem`
texture as a mark on a dark panel. Ids 70-79 are the Golden Palace's (task D6b, a level's own skin,
not a zone's), in `kit_golden_palace.gdshaderinc`, after `kit_golden.gdshaderinc`'s `golden_metal()`
and `golden_marble()`, which it calls directly.

**Gangland's ceilings** (`GanglandCeiling`) take their width from the lanes they cover (the collision
box), never from the track, and draw each side as anchored (running into the building face) or free
(an edge face). A ceiling across the street is an overpass or a bombed-out building (`kind_of`, by
hashing its start); a narrow one (B3) is always a slab broken off a building (`Kind.SLAB`, the owner's
review P2 18): broken edges with rebar, rubble, column stubs and a piece of wall on it, lodged in the
building face on a side that reaches the street's edge, or hung from its building's torn steel frame
running up to both building faces when it reaches neither (`GanglandSkin.ceiling_section` passes which
sides reach a wall, and the walls' distance). Whatever the structure, the running surface is a flat
slab with lamps on every lane seam, nothing hangs below it, and its far end carries the orange band
(`MeshKit.ceiling_end`, as in every zone).

**The Marketplace** (`scripts/world/skins/marketplace/`): `MarketStalls` (the floor), `MarketFacades`
(the walls, and the pennants and festoon lights across the street), `MarketCeilings` and `MarketProps`
(fences and signs); its building faces use their own shader, `shopfront.gdshader`.
- *The stall floor is laid out on the GPU.* A lane piece's roofs are one quad with `PAT_STALLS`: the
  shader finds each point's stall from its track position (slots along the lane, runs of 1-3 slots)
  and draws its roof, hem and frame pole. `kit_hash_u()` in the include is `MeshKit.hash_i` bit for
  bit, so `MarketStalls.stall_at()` and `roof_of()` reproduce the shader's choices. Anything that
  must match the shader's layout goes through those two.
- *Gaps read as holes.* Everything under the roofs (stall faces, building faces, the market floor)
  is drawn with `PAT_UNDER` in the skin's `gap_inside_color`, a deep shade that only darkens with
  depth, and nothing under the roofs is lit or glows but the orange edge strip. The suite pins it
  (far darker than any roof, no roof in the edge colour).
- *Shop windows for the citizens (task D3).* Every shopfront has a row of real window openings with
  lit displays at the low part of the wall (0.85-2.8 m above the floor, above the wall vents' zone).
  `MarketplaceSkin.shop_windows(side, face_x, start, end)` lists the windows whose centres lie
  between two track distances (position on the glass, width, bottom, top, depth into the building,
  kind), computed from track positions alone, so it can be asked before or after a chunk exists.
  Citizens stand inside, between the glass plane and `face_x + side * depth`.
- *The Marketplace citizens (task D3, GDD §5 "Citizens"; scenery only, never real 3D characters).*
  `tools/asset_gen/citizen_sheet_gen.gd` bakes a few archetypes (`CitizenRig`, on the same shared
  `HumanoidRig` the player and cyborgs use, GDD §9.2) into flipbook sprite sheets
  (`CitizenSheet`: a fixed grid, one row per clip: idle, startled, cheer) at
  `assets/sprites/citizens/*.png` (`tools/godot.sh citizens` regenerates them). `MarketCitizens`
  (`scripts/world/skins/marketplace/`), called from `wall_section()`, seeds which eligible
  `shop_windows()` get one (never a feed window, `screen`) from the window's own track position, so
  a chunk builds the same citizens every time. `MarketCitizen` plays the baked sheet back as one
  cheap unlit, double-sided quad (a `StandardMaterial3D.duplicate()` per card, its `uv1_offset` the
  only thing that changes, driven in GDScript, not a shader) and reacts (startled or cheering) once
  the player's own track distance comes within range of its window, easing back to idle on its own;
  every live one joins the `"market_citizens"` group with a public `react(kind)`, the hook for The
  House (E5a, GDD §10: "the citizens in the shop windows cheer and duck throughout") to use later.
  Kept apart from window cyborgs (GDD §9.2; `docs/questions/d3.md`): citizens never glow and their
  windows stay lit, and `ZoneSkin.note_wall_enemies(side, start, end, enemies)` (a small, generic
  hook `TrackBuilder` calls just before `wall_section()`, a no-op for every other skin) tells
  `MarketplaceSkin` which window cyborgs the chunk is about to place, so `MarketCitizens` keeps
  `CYBORG_MARGIN` clear of each one's track position (`MarketplaceSkin.reserved_near()`). Switched
  off by `Settings.citizens_enabled` (`DeviceProfile.is_low_end()`, DESIGN-TBD: nothing decides
  "low-end" project-wide yet) and `Settings.DEFAULTS["citizens"]`, kept current by `apply_visuals()`
  like `flashing_reduced`, so the skin never needs a `Profile`. `test_marketplace_citizens` and
  `test_marketplace_skin`'s existing budgets (`SkinSuite`) cover it; with `CITIZEN_SHARE` at 0.16 it
  adds about 2 surfaces and under 10 vertices per 5-lane chunk on top of the Marketplace's own ~21.
- *Ceilings from their lanes (task B3).* `MarketCeilings` builds every kind (a building bridging the
  street, an overpass, a merchant ship, a floating ad) from the ceiling's collision box and lane
  seams, so a ceiling over fewer lanes just builds narrower; only a full-width ceiling becomes a
  building bridging the street. `mesh_for(kind, ...)` builds a given kind directly. A ship's engine halos
  stop at the underside (`MeshKit.stern_halo`).
- *Decorative signs* (neon, painted blade signs, ad boards, casino bulbs) never sit below
  `decor_min_height` (8 m) and never wear the striped frame, which is reserved for hazard signs.
- *Futuristic and worn* (GDD §5): `shopfront.gdshader` draws cladding, rounded smart-glass windows,
  roller shutters and grime; `MarketFacades` adds air-conditioning units, drone racks, cable trays,
  glass balconies, rooftop dishes and masts, and cables across the street (the machinery's faces
  use `PAT_TECH`), all above the wall-run band, which the suite checks stays flush. Dust on roofs,
  awnings and ledges comes from `kit_market.gdshaderinc` (`market_dust`, scaled by the skin's
  `wear`).

**The Corporate zone** (`scripts/world/skins/corporate/`): `CorporateTrains` (the floor: the roofs of
maglev trains, and the guideway trench below), `CorporatePlaza` (the paved deck of the plaza variant,
`floor_style` PLAZA, `data/skins/corporate_plaza_skin.tres`), `CorporateTowers` (the walls, and the
skybridges and hovering gunships over the street), `CorporateCeilings`, `CorporateShips` (the gunship
template) and `CorporateProps` (fences and signs); its building faces use their own shader,
`corp_facade.gdshader`.
- *The brand.* One harsh colour, `brand_color` (an electric ultramarine between the UI's azure and
  violet, clear of every hazard hue), and one mark, `corp_logo()` in `kit_logo.gdshaderinc`, which
  Gangland's corporate crates, containers and ads share. Glowing decoration keeps to cold white and the
  brand's blue; the military olive is always lit, never glowing.
- *Carriages on a grid.* Each lane's carriages sit on a grid (`carriage_length`, offset per lane:
  `carriage_unit()`, `carriage_offset()`), so they line up across chunk cuts, and a carriage's kind
  (runs of express or olive freight cars) comes from hashing its grid cell (`carriage()`).
  `carriage_plan()` lays out a floor piece's roofs and joints: no joint within `GAP_MARGIN` of a gap's
  edge, and a thin seam instead of a gangway where one would cross a chunk cut.
- *Gaps read as holes.* Everything below the running surface (the carriages' sides and ends, the
  guideways, the trench, the plaza deck's edges) is drawn with `PAT_CORP_UNDER` in `gap_inside_color`, a
  deep shade that only darkens with depth, with the guideways and the trench floor deeper than a fall
  that ends the run; nothing below is lit or glows but the orange strip. The suite pins it over a whole
  level, for the trains and the plaza.
- *The calm band.* Every wall is flush through `band_top` (7.2 m): nothing glows, lights up or sticks
  out there (partial wall fences, B5, sit in it); decorative signs and screens start at
  `decor_min_height` (8 m). What hangs out over the street (banners, big screens, skybridges) stays
  above `CorporateTowers.OVER_STREET_MIN`, and nothing of a ceiling rises more than
  `CorporateCeilings.TOP_LIMIT` above its underside, so the two never meet.
- *Ceilings from their lanes (task B3).* `CorporateCeilings` builds every kind (a glass skyway, a tower
  bridging the street, a viaduct with a military checkpoint, a gunship flying low) from the ceiling's
  collision box and lane seams; only a full-width ceiling becomes a tower bridging the street.
  `mesh_for(kind, ...)` builds a given kind directly.
- *A boss over the street.* Hostile Takeover's gunship paces the train overhead (GDD §10): an arena skin
  with `street_screen_share`, `banner_share`, `skybridge_share` and `hover_ship_share` at 0 builds
  nothing over the lanes above the ceilings (the suite checks it). Searchlights never point at the
  lanes (a light locking onto them is the Floating Head's warning).
- *The military presence* is data: `compound_share`, `hover_ship_share`, `ship_weight` and
  `military_car_share`; the plaza variant raises them for Corporate 2's heavier presence.

**The Dead Zone** (`scripts/world/skins/dead_zone/`): `DeadStreet` (the floor: a rubble street, and the
void below it), `DeadTowers` (the walls: the Neon City's towers burnt out, and the broken skybridges and
smoke over the street), `DeadCeilings` and `DeadProps` (fences and signs). Everything is drawn with the
kit's solid shader (`kit_dead_zone.gdshaderinc`), the drift shader and one shader of its own,
`dead_smoke.gdshader` (columns of smoke: one billboarded column per six vertices, lit by
`scenery_light`). Dark black, dark grey and ash grey at night (GDD §5); the ash-grey street is its
lightest surface.
- *Gaps read as holes.* The street (`PAT_DZ_STREET`, laid out from world position) is broken plates under
  pale ash with rubble drawn flat, never built, so nothing on the running surface stands up like an
  obstacle, and nothing round lies on it (a manhole is a screech's lair). Everything below it (the cut,
  the sides along lane edges, the void floor `void_depth` down) is `PAT_DZ_UNDER` in `gap_inside_color`,
  which only darkens with depth; a gap's edge is the lip, strip and far halo of every zone. The suite
  pins it over whole levels at 3 and 5 lanes (the hole far darker than the street's darkest shade).
- *The calm band.* `PAT_DZ_TOWER` draws the City's four window styles gutted (burnt rooms, shards,
  torn holes, soot) above `band_top` (7.2 m) and, below it, flush ash-dusted cladding with soot tongues
  climbing from the street: nothing opens, glows, sticks out or looks like a window (a window cyborg's)
  or a vent there; the 2 m and 4 m wall-run marks are unlit paint. Decoration (dead neon banners, dead
  roof boards, screens) starts at `decor_min_height` (8 m); what hangs over the street (screens, broken
  skybridges) stays above `DeadTowers.OVER_STREET_MIN` (14 m), and nothing of a ceiling rises more than
  `DeadCeilings.TOP_LIMIT` above its underside.
- *Fires kept minimal* (GDD §5). The only glows besides hazards, triggers, ceiling ends and the feed are
  embers: a few windows of some towers, `ember_min_height` (16 m) up or more, a dull orange below the
  bloom threshold and under a third of a gap edge's glow (the faces' vertex alpha, breathing slowly,
  steady with Reduced flashing); smoke columns rise only from ruins 20 m tall or more
  (`DeadTowers.PLUME_MIN_TOP`). The suite checks both over whole levels.
- *Motion on a still street.* Ash flakes, faint puffs of smoke and speed streaks drift toward the runner
  (`MeshKit.drift_particles(..., smoke)`: the drift shader's fourth kind, `DRIFT_SMOKE`, a big soft puff
  that fades three times as far from the camera as the others; a skin passing no smoke count is
  unchanged).
- *Ceilings from their lanes (task B3).* `DeadCeilings` builds a charred bridge or a dead building
  across every lane (weights `bridge_weight`, `building_weight`), and over fewer lanes a slab broken off
  the tower it reaches (one wall) or a collapsed span hanging from its gantry (neither wall), from the
  collision box and lane seams; `reaches_wall()` decides which sides run into a building face, from the
  section's wall distance (`DeadZoneSkin.ceiling_section`; `hull()` alone uses the wall face the skin saw
  last, as `wall_section` runs before a chunk's ceilings). Every underside is flat
  charred concrete with a steel strip and a pale line on each lane seam, and the orange far-end band.
  `mesh_for(kind, ...)` builds a given kind directly.

**The Golden Zone** (`scripts/world/skins/golden/`): `GoldenWalkways` (the floor: golden walkways over
the canal), `GoldenFacades` (the walls, and the sky bridges over the street), `GoldenCeilings`,
`GoldenProps` (fences and signs) and `GoldenStatue` (the statue kit); its building faces use their own
shader, `golden_facade.gdshader`. White and cream with red and gold accents (GDD §5), at the blue hour.
- *The gold is metal, never neon.* `golden_metal()` (kit_golden) lights gold as a fake reflection of the
  dusk: bright where it reflects the afterglow, a greyed bronze where it reflects the street (dark golds
  that keep their hue go orange in the tonemapper), champagne at its brightest. Nothing gold, red, marble,
  cloth or water ever glows; the only decorative glows are warm-white lamps and lit windows. The zone's
  gold is `CultEmblem.GOLD_COLOR`, half saturated so it never passes for sign yellow or gap-edge orange.
- *Walkways over water.* Each lane is its own walkway (`PAT_WALKWAY`, laid out from world position, so
  plates continue across chunk cuts): plates between rails, a dark joint to a neighbouring walkway, a
  marble kerb on the outer lanes. The canal (`PAT_CANAL`) is `canal_depth` below; everything under the
  decks (`PAT_UNDERDECK`, the facades' DEEP style) is deep shade in `gap_inside_color`. A gap's edge is the
  lip, dark line and strip of every zone, with a soft halo on the far edge. Medallions of the emblem are
  inlaid in some walkways, one lane square, one slot per lane per chunk, clear of gap edges
  (`GoldenWalkways.medallions()`). The suite pins that gaps read as holes at 3 and 5 lanes.
- *The calm band.* Every building face is flush from the canal to `band_top` (7 m), with gold wall-run
  height marks and recessed openings for decorative wall-base guards and live Sentinels; nothing
  projects into the wall-run path. The entablature above retains its architectural ledge.
- *The statue kit* (`GoldenStatue`, for the Gilded Sentinels, task C4). Statue space: the pedestal's
  foot at the origin, facing +Z. Poses are dictionaries of joint angles (`shoulder_r/l`, `elbow_r/l`,
  `grip`, `head`, in degrees; missing keys take `REST`); `POSES` names the decorative `guard`, `vigil`,
  `salute` and the swing's `raise` and `strike`, and `blend_poses(a, b, t)` mixes two. For decoration,
  `mesh(pose)` is one cached template to append into a wall mesh (no draw call of its own). For a live
  Sentinel, `rig(parent, pose)` builds it as nodes and returns them by name (`root`, `body`, `pedestal`,
  `head`, `eyes`, `arm_r`, `arm_l`, `elbow_r`, `elbow_l`, `grip`, `halberd`): turn the pivots with
  `apply_pose(nodes, pose)` or directly, and give `eyes` (a MeshInstance3D) a glowing red material of
  its own. `niche(width, height)` is a niche proud of any wall; `recess(width, height, depth)` the one a
  live Sentinel stands in, set into the wall (task C4): the skin learns where one stands
  (`note_wall_enemies`, `GildedSentinel.niche_rect`), leaves its opening out of the plinth and the calm
  band (`open_rects`: the face's pieces around it, sharing their edges exactly) and appends the recess
  there (`add_niches`: a dark back and sides, a marble floor, a flush gold frame whose spandrels round it
  into an arch); the Golden Palace's walls do the same with their panel. The skin's kit is
  `GoldenSkin.statues()` (its gold and solid material). Decorative statues in both Golden skins stand
  at `statue_base_height` (0.10 m). The shared mount helper uses each rotated pose's outward projection
  plus `statue_base_inset` (0.10 m safety margin), rather than unnecessarily burying the body using
  a rotation-independent radius. The recess back clears the wallward projection by 0.05 m, and the
  decorative opening is 2.0 m wide. A decorative-mesh-only gold albedo lift, without emissive glow,
  keeps guards discernible from the runner camera. Pedestals and recess sills stay at or above the
  floor, and every pose stays behind the wall face. `GoldenSkin.statue_spots()` lists them. Their meshes are scenery only;
  live Sentinel niche positions and hitboxes are unchanged.
- *Ceilings from their lanes (task B3).* `GoldenCeilings` builds a golden bridge (a coffered underside,
  a marble face with the emblem's crest, water off some into gilded troughs), a gallery of golden arches
  (only across every lane) or a hover-yacht from the ceiling's collision box and lane seams; over fewer
  lanes a bridge becomes a suspended gallery. Water stays above the underside. `mesh_for(kind, ...)`
  builds a given kind directly. `GoldenSkin.ceiling_section` hands it the section's wall distance, and a
  yacht's engine halos stop at the underside (`MeshKit.stern_halo`), as every zone's far end must.
- *Ceilings under the walls' decorations.* The walls build without knowing where ceilings are, so
  `GoldenFacades.clearance_profile()` declares what they hold out over the street, as (reach, lowest
  height) tiers for upper architectural decorations: the ledge, gilded frames, banners, and
  `OVER_STREET` beyond. Wall-base guards are recessed rather than street overhangs.
  `GoldenCeilings.headroom()` turns it into how high a ceiling may rise at a distance from a wall:
  arches are flatter over a narrow street (`arch_rise()`), a bridge's face stays under the ledges and its
  rail stops short of the statues, and a yacht near a wall has a lower cabin and no mast. The suite
  checks both sides on streets of 3 to 6 lanes; a new wall decoration extends the profile.
- *Overhead.* Sky bridges between towers 24 m up or more, only where towers tall enough stand on both
  sides; banners hang no lower than `GoldenFacades.BANNER_BOTTOM` (11 m), clear of every ceiling.

**The Golden Palace** (Golden 3, task D6b, GDD §5 "Final level: the Golden Palace"): a level's own
skin (`data/levels/golden_3.tres`'s `skin`, over the Golden Zone's), since the player runs *inside*
the palace rather than its streets. `GoldenPalaceSkin` (`scripts/world/skins/golden_palace_skin.gd`)
extends `GoldenSkin` outright, the only skin that does: GDScript can't redeclare an exported property
in a subclass (CLAUDE.md principle 7), so `data/skins/golden_palace_skin.tres` sets fresh values for
the few exports its colonnade and ceilings reuse for a new purpose (`lot_length` as the colonnade's
bay spacing, `gallery_share`/`statue_share`/`banner_share`/`relief_share` as a bay's content,
`banner_width`/`banner_length` as a tapestry's size, `bridge_weight`/`archway_weight`/`yacht_weight`
as the ceiling pieces' weights, a chandelier taking the yacht's role), while its Gold and red,
Statues, Hazards, Pads/ramps/finish and Environment groups, its statue kit (`GoldenStatue`), its cult
emblem and feed (`CultEmblem`, `CultFeed`) and `make_environment()` (the stars turned off, the one
field it doesn't expose as an export) all carry over unchanged; `test_campaign`'s `_test_skins()`
counts a subclass of a zone's skin script as "its own variant" too, alongside Corporate 2's plaza (the
same script, different values). Only `floor_segment()`, `wall_section()` and `ceiling_section()`/
`hull()` are overridden (`scripts/world/skins/golden_palace/`):
- *The floor* (`GoldenPalaceFloor`): a palace floor's lane, flush marble (`MeshKit.PAT_PALACE_FLOOR`,
  laid out from world position) with a gold inlay runner down its centre (`runner_half_width`), no
  raised kerb or rails (solid stone, not over water, unlike `GoldenWalkways`). Gaps are breaks in the
  floor (GDD §5: "a collapsed floor, an open stairwell, a light well"): the usual orange edge, and
  below it deep shade (`MeshKit.PAT_PALACE_WELL`) darkening with depth, so a gap reads as a hole at a
  glance (pinned by `test_golden_palace_skin`, as every zone's floor is). Dust motes, floor-polish
  glints and speed streaks drift over it (the Golden Zone's `mist_count`/`leaf_count`/`streak_count`
  reused, the still floor's motion cue).
- *The walls* (`GoldenPalaceWalls`): a colonnade. A flush marble panel (`MeshKit.PAT_PALACE_PANEL`,
  with the gold wall-run height marks inlaid in it) runs from the floor to `frieze_top`, exactly as
  calm as every zone's band; gilded pilasters stand above it, every `lot_length` metres, up to
  `pilaster_height`. Between two pilasters, a bay (GDD §5) holds a gallery (a gold-framed opening
  showing the cult's feed or its emblem, `gallery_share`), an alcove (a decorative statue in the same
  niche shape of the statue kit, `GoldenStatue.niche()` (a live Gilded Sentinel's is set into the wall,
  `recess()`, task C4), `statue_share`, mounted at the wall base using the shared recessed mount),
  a tapestry (`banner_share`) or a relief (`relief_share`); otherwise
  the flush panel simply carries on. Through the existing `note_wall_gaps()` hook, low alcoves
  (their statues, recesses and frames) and pilasters are omitted when their footprints cross a physical
  wall gap, including at chunk boundaries. `statue_spots()`, `feed_boards()` and `cult_emblems()` list a
  bay's content the same way the Golden Zone's `GoldenFacades` lists its ledges, frames and banners.
- *The ceilings* (`GoldenPalaceCeilings`, task B3's narrow-ceiling rule): a bridge between galleries or
  an archway (both need every lane; over fewer lanes both fold into the narrower BALCONY) or a hanging
  chandelier (the yacht's weight, reused: it hangs over any width). Every underside reuses
  `GoldenCeilings`' recipe (a flat surface, a darker seam and flush lamps on each lane seam, the
  orange band at the far end); a chandelier's gilded rosette and ring of lamps stay flush with it too,
  so nothing of it ever hangs below the running surface, the rule every ceiling keeps. Structures keep
  `hall_clear_height` above their underside (a flat budget, not a wall-decoration profile: the
  colonnade stands well clear, to the sides, so there is nothing to duck under, unlike the Golden
  Zone's walls).
- *Shader patterns* (ids 70-79, `kit_golden_palace.gdshaderinc`, after `kit_golden.gdshaderinc`'s
  `golden_metal()`/`golden_marble()`, which it calls directly rather than inventing new ones):
  `PAT_PALACE_FLOOR` (70), `PAT_PALACE_WELL` (71) and `PAT_PALACE_PANEL` (72).

**The cult emblem** (D7, GDD §5 "The cult"): `CultEmblem` (`scripts/world/meshes/cult_emblem.gd`)
builds each option's 2D vector geometry as a flat mesh (mesh kit conventions: emissive for a neon
ad, lit for paint or the Golden Zone's gold) or a rasterised texture, at any size. The owner chose
option B, the Convergent Triad (GDD §5); the choice lives in `data/world/cult_emblem_choice.tres`
(`CultEmblemChoice`). A skin reads `choice.option` and `CultEmblem.default_scheme(option)` rather
than hardcoding an option: hidden in logos and ads in every zone, shown openly in the Golden Zone
(GDD §5, proposed). `tools/showcase/cult_emblem_sheet.tscn` is the comparison sheet. Gangland hides it
through the kit shader: the skin sets the `cult_emblem` texture (the option rasterised in its unlit
colours, `GanglandSkin.cult_emblem_texture()`), `cult_emblem_share` puts it on some corporate ads, and
`MeshKit.stencil_param(..., emblem)` on some crates, container doors and notice boards. The shader picks
its mip level itself and fades it out before it spans fewer than about 24 pixels, where the three-fold
mark could read like a radiation trefoil. The Marketplace uses geometry instead: it turns the emblem
into a mesh-kit template once (`MarketplaceSkin.cult_emblem()`), then appends it where it hides: a
small warm-white badge on some ads, an unlit bronze mark on some shop signs, never smaller than
`emblem_min_size` (0.9 m, for the same reason). The Neon City (D9) draws it with `MeshKit.PAT_CULT_MARK`:
its solid material carries the chosen emblem's coverage (`CultFeed.emblem_texture()`), and one
rectangle per mark, in UV emblem space (the mark's square spans -1 to 1, a wider range leaves a clear
margin), paints it in the vertex colour on the panel's dark background, glowing at the vertex alpha;
`cult_mark()` fades it out on screen as in Gangland, and the City keeps it at least `emblem_min_size`
across too. It sits as a sponsor's badge where a roof billboard's glyphs end and at the foot of some
towers' neon banners (the glyphs leave its square clear, so nothing overlaps); `CitySkin.cult_emblems()`
lists them. The Corporate zone (D4) draws it the same way: a warm-white badge in a lower corner of some
ads on the street screens and roof boards (never more than `CorporateTowers.SCREEN_EMBLEM_MAX` of a
screen's height), unlit bronze at the foot of some banners; `CorporateSkin.cult_emblems()` lists them.
The Dead Zone (D5) keeps it scorched and half-gone (`MeshKit.PAT_DZ_MARK`, kit_dead_zone: the chosen
emblem from the solid material's `cult_emblem` texture, in its unlit metal, with a ragged burn front
eating part of it away and soot over the rest, never glowing) in a corner of some dead roof boards and
at the foot of some dead neon banners, at least `emblem_min_size` across; `DeadZoneSkin.cult_emblems()`
lists them.
The Golden Zone (D6a) shows it openly, large, in polished gold meeting at its red stone
(`MeshKit.PAT_EMBLEM`, kit_golden: the material's `cult_emblem` texture is the choice drawn in
`CultEmblem.GOLD_COLOR` and `GOLD_ACCENT_COLOR`, `GoldenSkin.cult_emblem_texture()`, embossed and lit as
gold on red cloth or marble): on banners, reliefs on towers, gallery frames, sky bridges
(`GoldenSkin.cult_emblems()` lists them), on the bridges' crests and archways' keystones, and on the
walkways' medallions. The listed ones
are 2 m across or more (so they still read from afar before `cult_mark()` fades them), and every one
stands off its backing far enough never to flicker (`GoldenFacades.RELIEF_STANDOFF`, `EMBLEM_STANDOFF`).

**The cult's feed** (GDD §5, "Cyborg Viewing Devices"): the same wordless broadcast plays on screens
in every zone, in sync, alongside the ordinary ads. It is one shared piece, `CultFeed`
(`scripts/world/meshes/cult_feed.gd`): a glowing, shader-driven material (`cult_feed.gdshader`, the
picture in `cult_feed.gdshaderinc`) that works on the Compatibility renderer, and a helper that adds
a screen to a mesh layer:

```gdscript
var feed: MeshLayer = batch.layer(CultFeed.material())    # shared; one mesh surface per chunk
CultFeed.screen(feed, lower_left, right, up, brightness)  # a rectangle facing right × up, as seen
CultFeed.wall_screen(feed, side, x, d0, length, y0, height, brightness)  # on a wall, facing the street
```

`right` and `up` span the screen as its viewer sees it (the picture is never mirrored, so don't put a
screen in a template that gets mirrored); `brightness` (0-1) dims small or low screens. The material
draws only the picture: give each screen a bezel, frame or TV set of its own. What it shows is a
placeholder (DESIGN-TBD, `docs/questions/d2.md`): a CRT picture in cold white, like the cyborgs' screen
heads, with scanlines, soft static and a slow rolling bar, looping through the cyborgs' calm face
(`cyborg_kit.gd`'s Face.NEUTRAL drawn smooth, in the same cold white: keep the two the same face), the
chosen emblem (`CultEmblem`, faded out below about 24 pixels) and rings converging on a point, one at a
time. Rules for every skin: keep it the same broadcast (vary only how many screens
play it and where), keep other glows off it, and never tint it (only cold white and the emblem's
warm white; purple glitching belongs to hosts). It honours Reduced flashing (the static and the
rolling bar hold still). The Marketplace plays it on some billboards, casino signs and floating ads
(`feed_share`) and on old TVs in some shop windows (`feed_window_share`; `shop_windows()` marks
them with `screen`). The Neon City (D9) plays it on some low buildings' roof billboards instead of
their ad and on big screens hung out over the street from some flush towers, 12 m up or more and
facing the oncoming traffic (anything flat on the City's facades is seen almost edge-on from the game
camera); `CitySkin.feed_boards()` lists both. Gangland plays it on salvaged screens among the posters
of some overpasses' sign gantries, and on a TV glowing in an upper window of some ruins, above the
boarded-up band (`GanglandSkin.feed_windows()` lists those; `GanglandRuins.WINDOW_RECTS` mirrors the
facade shader's window rectangles so the TV's room covers a window exactly). The Corporate zone (D4)
plays it on some low buildings' roof boards and on some of the big screens flush towers hang out over
the street, 14 m up or more; `CorporateSkin.feed_boards()` lists both. The Dead Zone (D5) plays it,
sparse and dim, on the few surviving screens: some low buildings' roof boards and a big screen hung out
over the street from a few flush towers, `feed_screen_bottom` (15 m) up or more;
`DeadZoneSkin.feed_boards()` lists both. The Golden Zone (D6a) plays it in
some galleries' gilded frames and on big screens hung out over the street from some towers, sized to the
street (`feed_hung_reach`), 10 m up or more; `feed_hung_share` at 0 clears the hung ones for a boss
arena, and `GoldenSkin.feed_boards()` lists both. None of them puts a screen in
the wall-run band. `tools/showcase/cult_feed_showcase.tscn` shows a whole loop on three screens.

**Reduced flashing** (Settings): `Settings.apply_visuals()` sets the global shader uniform
`reduced_flashing` (declared in `project.godot`) and `Settings.flashing_reduced`. Hazard shaders
include `kit_flash.gdshaderinc` and use `warning_flicker()`, so a warning becomes a steady glow
instead of a strobe. Anything new that flickers or flashes must honour it too.

## Characters, UI and audio

- **Characters:** `HumanoidRig` (`scripts/characters/`) is the procedural rig and pose set behind the
  player model (`PlayerAvatar`: Razor Echo, look in `PlayerSuit`) and the cyborgs (`CyborgBody` with
  `CyborgSuit`: one skeleton, a part set per zone look, one material per cyborg). A look is a
  `HumanoidParts`: `HumanoidPiece` shapes per segment (BOX, PRISM, LATHE, BAND, TORUS, and SHELL, a
  closed sheet cut to an arc), named attachment sets (equipment, zone variants), and optional
  `HumanoidPanel`s. A piece's `glow` and `shine` (polish) ride in the mesh (UV.x, the vertex colour's
  alpha) so a whole segment is one draw call.
  - **Panels** are stiff flaps hinged at the waist (Razor Echo's coat skirt; looks without them are
    untouched). All of a rig's panels are one mesh on the pelvis joint; `update_panels()` (called by
    `animate()`; a user that poses the rig itself with `apply_pose()` calls it after) swings each by a
    pitch and a roll through a damped spring: it hangs toward the feet (on the ceiling too; on a wall it
    sags toward real gravity), follows its thigh, trails in the wind of the run and flares when falling,
    then the leg on its side and the surface push it clear (a hem pushed by the surface trails while
    the runner moves, otherwise folds the way it leans). `humanoid_panels.gdshaderinc` turns each
    panel's vertices by the rig's `panel_rot` / `panel_hinge` arrays, so the material must be the rig's
    own. The numbers are `HumanoidAnimTuning`'s Coat panels group (F6, "Runner animation").
  - **The player's shader** (`humanoid_body.gdshader`) also has a rim light and `glow_albedo` (soft
    trim that shines by its own light).
  - **Colour spaces:** the builder stores vertex colours in linear space; on the Compatibility
    renderer, which works in sRGB space, the rig's shaders (`humanoid_body`, `cyborg_body` and the
    cyborg kit's part shader) convert them back with `humanoid_color.gdshaderinc` (as
    `kit_common.gdshaderinc` does for the mesh kit). The same include's `humanoid_glow()` scales a
    colour uniform into a bright glow in linear light on every renderer, so a glow keeps its hue on the
    web (scaled in sRGB, the cyborgs' red charge-up turned cream). Sums of light (the screen head's
    LEDs averaged far away) are taken in linear light too (`humanoid_to_linear`); dim picture parts
    are brightness as seen, turned into light with `to_linear()`.
  - **Colour rule:** the player's only glow on the base model is its soft copper (`PlayerSuit.GLOW`);
    `test_avatar` keeps it and the effects built from it at least 0.3 from every skin's hazard colours
    and enemy fire on the hue and saturation wheel, and power-up looks never use it.
  - **The cyborgs** (GDD §9.2; tasks P2 and P3): `CyborgSuit` builds one `HumanoidParts` whose
    attachment sets are the looks (`LOOKS`) and their hosts' veins. The looks are the ragged "Static TV
    Head" base (P2, in `cyborg_suit.gd`) and its zone variants (P3), one file each in
    `scripts/enemies/cyborg_looks/`: `brute.gd` (Gangland's Broadcast Brute), `casino.gd` (the
    Marketplace's Casino Mob Enforcer), `vr_runner.gd` (Corporate's Wide-Aspect VR Runner), `burned.gd`
    (the Dead Zone's base, burned out) and `golden.gd` (the Golden Zone's ceremonial enforcer, built
    by `casino.gd`'s `build()` with its own palette). They are the same unit: one skeleton, the same
    poses and hitboxes, the same face expressions, and only the boot soles and the weapon's emitter
    ring and charge orb shared by every look (the soles ground the rig; the charge-up must look the
    same in every zone), so every weapon (the arm cannon, the Brute's pipe gun, the enforcers' drum
    gun, the VR Runner's chrome cannon) ends at the same muzzle (`MUZZLE`). No look is bigger than the
    base. `look_for(variant)` maps a skin's `enemy_variant` to a look: a look's own name picks it,
    `VARIANT_LOOKS` maps the City's and Gangland's older names, anything else wears the base (Zone
    skins lists each zone's value). A look file gives `pieces()` (its set), `veins()` (its hosts' set,
    `host_set(look)`; the burned base's hosts wear the base's `&"host"` set) and `material_params()`
    (its changes to the shader's uniforms over the base's, `look_params()`: the screen's rectangle, wear
    and LED shape, how metallic its polish is, its marked surfaces). The helpers at the end of
    `cyborg_suit.gd` build the pieces: `add`, `pipe`, `bar`, `cable`, `vein`, and `patch` (a flat
    decal, one quad: scorch, trim, engraving, a torn strip) with `facing` to turn it onto a surface.
    A cyborg is 11 draw calls in every look (a window cyborg's upper body 7): hands and feet ride on
    the forearms and shins, and the neck, backpack and cables on the chest. The cables and the shoulder
    hose belong to the chest and end inside the head and the shoulder cap near their joints
    (`HEAD_CABLES`, `ARM_HOSE`), so they stay plugged in however the head and arm turn.
    `cyborg_body.gdshader` draws marked pieces (glow values `SCREEN`, `RING`, `ORB`, `VEIN`, `GLASS`,
    `EMBLEM`, `STRIPES`): the pixel faces of `cyborg_kit.gd` as LED dots (round, or diamonds on the
    enforcers) in the cult feed's cold white on the look's screen (the VR visor has its own face grid,
    `VISOR_FACES`), averaged through mipmaps far away so a face a few pixels across keeps its shape; a
    host's purple static; the switch-off after a defeated cyborg's ERR; the burned screen's flicker and
    crack; the Brute's dim side screens; the Golden Zone's medallion with the cult's emblem (faded out
    below about 24 pixels, as the skins do); and pinstripes. `CyborgPoses` gives every look its
    posture (hunched, a shambling limp, twitches and a tremor added after the blend).
    `test_cyborg_body` runs every check over every look: the hitboxes, budgets and size, the weapons,
    and the colour rules: nothing on a cyborg glows but the cold white face and screens, the red
    charge-up and a host's purple; nothing is copper, purple only on hosts, no hazard or "safe" colour
    anywhere; gold and chrome only as unlit, polished ornament, the grimy looks dull.
- **UI:** a theme built in code (`scripts/ui/theme/`: `UiStyle` in `data/ui/ui_style.tres`,
  `UiTheme`), code-drawn icons (`scripts/ui/icons/`) and a widget kit (`scripts/ui/widgets/`). Screens
  (`scripts/ui/screens/`) extend `ScreenBase`; the HUD is `RunHud`: its protections show the armor's
  hits and, while it's broken, the cooldown ring filling in the kit's calm accent until it's back, when
  the icon flashes and the player's `armor_back` plays (a latch and a low chime; a hit the armor survives
  plays `armor_hit`). Orbitron is for titles and Exo 2
  for text and numbers. On the HUD, draw icons from `IconFactory.texture()` (cached, tinted with a
  modulate colour) rather than `IconFactory.draw()`: every polygon or polyline command costs its own
  draw call every frame, and the HUD's icons alone were once 220 of about 370.
- **Audio:** `SfxLibrary` maps sound names to `assets/sfx/*.wav` (volumes in
  `data/audio/sfx_library.tres`). The cyborg firing effect alone is -3.2 dB instead of -5.5 dB:
  about 1.303 times its former amplitude, matching the owner's approximately 30% increase;
  charge warnings and the player's laser are unchanged. `Music` (`MusicDirector`) plays `assets/music/` (files, levels and
  tempos in `data/audio/music_library.tres`), one looping track at a time with crossfades: the menus'
  default track and one default per zone, named after the zone's id (`ZoneDef.music`). Defaults are generated by code in
  `tools/asset_gen/` (`tools/godot.sh sfx` / `music`): a track is composed in `track_<name>.gd` with
  `music_song.gd` (stems on a 16th grid that wrap around the loop, and loop-safe effects) and
  `music_instruments.gd`, and a new one is listed in `music_gen.gd` and the library. **No new tracks are
  generated** (owner, September 28, 2026). Owner-supplied MP3s now replace gameplay in all six zones
  and the Floating Head fight. `MusicLibrary.zone_tracks` maps a zone's default to its supplied song,
  and `boss_tracks` maps a boss id to its supplied song. `App._start_run` resolves these for campaign,
  quick play, endless and retries; cinematics and menus bypass the overrides, and unmatched bosses
  keep their defaults. All levels within a zone share its song. MP3s loop in full; regeneration
  leaves them untouched. The web demo keeps the Zone 1 and Boss 1 MP3s plus menu/cinematic defaults.
  Generated tracks are
  levelled so their K-weighted loudness (400 ms windows: the median, and the energy mean) sits at
  about -26.8 dB, some 10 dB under the attack warnings.
  - **Dips:** `set_ducked()` lowers the music under the pause menu, and `set_dipped()` is the death dip
    (GDD §11): `LevelRun` dips it as the player dies, it holds under the death screen, and a revive or a
    restart lifts it; playing another track (leaving to the menus) or `stop()` ends it, the dipped
    track fading out as it was. The dipped track sinks by `dip_db` while a low-pass on the Music bus
    closes to `dip_lowpass_hz` (switched off whenever it's open). With both, the deeper applies, never
    the sum. The numbers are `MusicLibrary`'s, in F6's "Music" section.
  - **The level-complete riff** plays in the key of the music playing (GDD §11):
    `MusicDirector.level_complete_sound(track)` gives `level_complete_<track>` when the sound library
    has one, otherwise the E riff `level_complete` (the City's), and `LevelRun` plays it when a level
    ends or a boss is beaten. The riffs are in `tools/asset_gen/sfx_bank_riffs.gd`, each over within
    `LevelRun.COMPLETE_PAUSE`, when the run and its sounds are freed. A track replaced by a file in
    another key needs its riff remade to match, or removed. For now `MusicLibrary.riff_tracks` maps
    supplied songs back to their original zone's riff, preserving the existing completion sounds;
    their keys have not been retuned to the supplied songs.

## Campaign, bosses and cinematics

`Campaign` lists `ZoneDef`s; each built zone contributes steps: optional intro cinematic, its
levels, optional boss-intro cinematic, the boss, optional outro cinematic. Step ids (`city/1`,
`city/boss`, ...) key the save file, so they never change. Difficulty comes from a campaign-wide curve
plus each level's `difficulty_bias`; `enemy_scaling` runs 0 → 1 across the campaign.

The campaign (GDD §5) has six zones, with ids other tasks rely on: `city`, `gangland`,
`marketplace`, `corporate`, `dead_zone` and `golden`, with 3, 3, 2, 2, 2 and 3 levels in
`data/levels/<zone id>_<n>.tres` (Golden 3 is the Golden Palace). Every zone has intro and outro
cinematic slots (the City also a boss intro) and a boss slot from GDD §10's roster. A zone's music
track is named after its id, and every zone has one (a track the music library doesn't list is skipped
quietly and the menu music carries on). Only the City is in the web demo. The curve runs 0.1 → 0.9
over the 15 levels (FB 4, FB 5); which level is the peak (proposed: Golden 2, with Golden 3 a little
below it) and the remaining level lengths (DESIGN-TBD, run 120–150 s) stay open.
Zone & Levels 1 shortens only City 1 (Rooftop Rush) from 110 to 55 seconds via
`data/levels/city_1.tres`'s `duration_seconds`; all other level durations stay unchanged.
At the City's 21 m/s this moves its finish line from 2310 to 1155 metres. The existing generator
and distance-based completion use that value without changing speed, difficulty, clear distances,
or the fractional starts of cyborgs and doodads. These are running times without speed-changing
power-ups or pauses, excluding cinematics and the completion delay. The levels now total 34.1 minutes.

**The schedule** (GDD §5) is each level's `features` list, in the order the campaign introduces them:
a feature once introduced stays in every later level, bar the exceptions the design gives (screeches
come from manholes only in street zones and from wall vents, `screech_vents`, elsewhere, with none in
Marketplace 1; the Tithe Collector skips the Dead Zone; Zone & Levels 2 excludes Octodogs from
Golden 1–3, including the Golden Palace). Octodogs remain enabled from Gangland 2 through the
Dead Zone. Removing only `octodog` from the three Golden resources excludes both dog patterns and
their generator rules, including the guaranteed-dog fallback; the director therefore has no dogs
to warm or spawn there. Speed pads and all other Golden features remain enabled. The Buzz Overdrive appears from Corporate 1
through the Dead Zone and the Golden Zone, the Golden Palace included (GDD §9.9, corrected). Each
level introduces its new features at starts of their own (`feature_starts`, see Late starts under The
generator; City 1's cyborgs come late in the level), and its newest features get the most picks
(the campaign's recency curve, under The generator). `test_campaign` holds the schedule table and its
exceptions, checks the features' order, and checks that every level has each of its features at 3, 5
and 6 lanes, on its own seed and over a seed sweep (Every feature appears, under The generator).
Features of enemies and mechanics still to be built (`LevelConfig.PLANNED_FEATURES`) are listed already
and do nothing until their code and patterns exist. The wall fences' `wall_fences` and
`wall_fences_partial` are built (B5; The generator, Wall fences).

**The Hush** (Dead Zone 2; GDD §5: "a quiet, eerie remix: fewer enemies but more hosts and Bad Dream
chases, darker lighting, and long silent stretches broken by sudden threats") brings nothing new; its
remix is its own data, which no other level uses: quiet stretches and bursts (`quiet_seconds` and the
rest, with its hosts as its quiet feature), hosts picked more often (`feature_weights`), and its
`darkness`. A Bad Dream chase starts only when the player kills a host (GDD §9.7), so more chases come
from more hosts, standing alone in the quiet stretches where one is easy to reach; the host rules
still fit one chase at a time. All DESIGN-TBD (`docs/questions/r5.md`). Endless mode, which copies the
furthest zone's last level, leaves the remix out (`App.start_endless`: no quiet stretches, no quiet
features or their weights, no darkness), so endless in the Dead Zone plays as it did before.

A `BossDef` or `CinematicDef` with an empty `scene` shows a placeholder card, which the player
continues past. A cinematic is a scene whose root extends `Cinematic` (emit `finished`, support
`skip()`), built with the cinematic toolkit (Cinematics, below): every zone's intro and the City's boss
intro play a placeholder arrival flyover, the City's outro plays its own scene (`CityOutro`, task F2a), and
the other outros are still cards. A boss is built on the boss
framework (Bosses, below). The City's Floating Head is built
(its step plays the fight); the other boss slots are still placeholders, holding the phases GDD §10
gives each designed boss and its armor-rule delay. A fight still being built names its scene in the
slot's `preview_scene` instead of `scene`: the campaign keeps the card, and debug builds play the
fight with `--boss=<boss id>` as quick play (`BossDef.preview()`), so nothing is recorded.

## Bosses

A boss fight (GDD §10) is a run like a level's, so it plays like the runner: the same controls,
camera, movement, HUD, power-ups, damage rules, pause, hints, death flow (revive offer → summary →
shop → retry) and debug tools. `App.start_boss()` builds its `RunContext`: `boss` set, `config` the
boss's arena (`Campaign.configure_boss`: the arena config with the lane count, the tier's difficulty
bonus, its run speed, the zone's enemy scaling and skin), a tuning at that speed that never speeds up
(`LevelConfig.movement_for`, as for a level), and the loadout plus `BossDef.granted_items`
(`Loadout.grant`: granted charges never cost stock). LevelRun then:

```
BossEncounter.create(def)            the boss's scene (BossDef.scene; its root extends BossEncounter)
  .plan_arena(context) → BossArena   the fight's track (+ the boss's _plan_lap on each lap)
RunWorld.build(arena.layout)
encounter.setup(world, context, arena)   joins the world between the player and the enemies
```

| File | What |
|---|---|
| `scripts/campaign/boss_def.gd`, `boss_phase.gd` | a boss's data: its slot, health, weapon cap, phases (share of health, big hits, pace, checkpoint, intro), arena, tuning, music, rewards, par times, the armor rule |
| `scripts/bosses/boss_encounter.gd` | the fight: health and phases, damage, the checkpoint, the armor rule, the light; helpers and hooks for boss scripts |
| `scripts/bosses/boss_part.gd` | a piece of the boss in the world: an Enemy the director runs (claw-immune, the dash passes, weak points, surfaces) |
| `scripts/bosses/boss_arena.gd` | the fight's track: generator laps joined ahead for as long as the fight lasts; `add_pieces()`; track queries |
| `scripts/bosses/boss_props.gd` | what a boss places within sight: fences, blocks, pads, ceilings, a wall taken away, floor warnings |
| `scripts/ui/widgets/boss_bar.gd` | the HUD's boss bar, with a marker at each phase's end |
| `scripts/bosses/test_boss*.gd`, `data/bosses/test_boss*.tres`, `scenes/bosses/test_boss.tscn` | the test boss, outside the campaign (`./play.sh --boss=test_boss`) |
| `scripts/bosses/floating_head/`, `scenes/bosses/floating_head.tscn`, `data/bosses/city_boss*.tres` | the Floating Head, the City's boss (see below; `./play.sh --boss=city_boss` or `--level=city/boss`) |
| `scripts/bosses/sleep_taker/`, `scenes/bosses/sleep_taker.tscn`, `data/bosses/dead_zone_boss*.tres` | the Sleep Taker, the Dead Zone's boss (see below; `./play.sh --boss=dead_zone_boss` or `--level=dead_zone/boss`) |
| `scripts/bosses/the_house/`, `scenes/bosses/the_house.tscn`, `data/bosses/marketplace_boss*.tres` | The House, the Marketplace's boss (see below; `./play.sh --boss=marketplace_boss` or `--level=marketplace/boss`) |
| `scripts/bosses/hostile_takeover/`, `scenes/bosses/hostile_takeover.tscn`, `data/bosses/corporate_boss*.tres` | Hostile Takeover, the Corporate zone's boss (see below; `./play.sh --level=corporate/boss`) |
| `scripts/bosses/sewer_swarm/`, `scenes/bosses/sewer_swarm.tscn`, `data/bosses/gangland_boss*.tres` | the Sewer Swarm, Gangland's boss (see below; E4a and E4b: the campaign plays it after Gangland 3, `./play.sh --boss=gangland_boss`) |

- **The arena** (`BossArena`): the generator plans `BossDef.arena_laps` laps from the boss's arena
  config (one lap's seed, features, difficulty, pacing and skin; `duration_seconds` is the lap's
  length), each from its own seed, and the boss script may shape each one (`_plan_lap`: set pieces,
  a train's carriage gaps). The fight cycles through them, and the next lap joins the track a whole
  lap ahead through `TrackBuilder.extend_layout()`, so the track keeps going for as long as the fight
  lasts and is the same on every attempt. Nothing in it ramps up, and it carries no credits
  (DESIGN-TBD). During the fight, `arena.add_pieces()` adds track pieces (holes, fences, pads with
  ceilings, ramps, signs, floor cuts, enemies) past `stream_from()`, the end of the built track; they're
  built and brought in like the rest. A floor cut (B4) goes in only after `arena.cut_problem(cut)` says
  it fits (the generator's rules for cuts, on the arena's track; The generator, Floor cuts), with its
  cause among the enemies. `floor_clear`, `hole_between` (a cut's stretch counts as a hole),
  `live_fence_between`, `ceiling_between` and `pieces_between` answer questions about the track.
- **Pace** (GDD §3, owner's playtest September 30, 2026; task E1f): a campaign boss fight runs at its
  zone's speed, like the zone's levels (21 m/s in the Neon City; `Campaign.configure_boss` gives the
  arena config its zone's `run_speed` times the tier's multiplier through `run_speed_for`, and
  `App.start_boss` takes the run's tuning from it with `LevelConfig.movement_for`); quick play
  (`--boss=<id>` for a boss outside the campaign, such as the test boss) and the tests keep the base
  18 m/s. The arena is planned at its config's speed (`BossArena.plan`: `arena.tuning`), so its patterns
  keep their seconds as a level's do, and a lap's clear start and end (the entrance) are stretched by the
  pace too. **A boss's own numbers in metres must follow the pace** (the note for every boss still to
  come, the Sleep Taker included): a distance along the track that stands for a time (where an attack
  lands ahead of the runner, a fairness margin, a way up, the spacing of set pieces) is metres at
  `MovementTuning.REFERENCE_SPEED` in its tuning and is stretched by the run's pace
  (`world.tuning.pace()`, or `arena.tuning.pace()` in `_plan_lap` before the world is built), so the fight
  plays the same in seconds at every zone's speed; warnings, wind-ups and every timing in seconds stay as
  they are. Things that keep pace with the runner (where the boss flies relative to them), sideways
  speeds and sizes, heights and the sizes of things don't change. Not to be confused with
  `BossEncounter.pace()`, a phase's speed-up. The Floating Head shows how (`run_pace`, `metres`,
  `before_face`, below); `tools/measure/stomp_routes.gd --speed=N` measures its ways up at any speed.
- **Props** (`encounter.props`): things placed within sight, with the track's collision layers and the
  zone's looks, freed once passed: `fence` (normal fence rules; it can flicker in first, and a boss
  may move it), `block` (solid; the player can't switch into it), `pad` and `ceiling`, `block_wall`
  (takes a stretch of wall away), and the red floor warnings `lane_warning` and `circle_warning`
  (steady with Reduced flashing; `warned(lane, from, to)` says where they are, and pickups keep off
  them); `floor_warning(node, lane, from, to)` counts a boss's own warning drawn its own way (the
  Sleep Taker's mist, its slash's lanes) in `warned()` the same way.
- **Parts** (`BossPart`, made with `add_part()` through the director): a boss's body shares the fight's
  health (weapon hits go to `BossEncounter.damage`, nothing else defeats it) and has weak points
  (`add_weak_point`: a stomp from above is a big hit; `set_weak_points_enabled` for weak points that
  are only live at times) and surfaces (`add_surface`: a top to land on, or a belly to ride as a
  ceiling). A part with health of its own (`shares_health` off: a swarm cluster) falls like any
  enemy, and the boss script hears of it (`_on_part_defeated`); an EMP reaching any part calls
  `_on_part_emp`. Normal enemies come in through `spawn_enemy()`.
- **Health and phases**: phases end at shares of the health; a big hit (a weak-point stomp, or
  `damage(hit_damage(), cause)` for an EMP, a cluster shocked by a fence, ...) takes a phase's share
  over its `hits`. Weapons chip up to `BossDef.weapon_share_cap` of the health over the whole fight;
  splash never counts. With `BossDef.weapons_can_end_phase` on (every boss's default: GDD §10's Floating
  Head rule, the best weapon saves at most one stomp) weapons may end a phase; off (Hostile Takeover's
  data, DESIGN-TBD), they chip a phase only down to just above its end (`weapon_floor()`, and
  `weapons_can_hurt()` then turns auto-fire away), so only its big hits end it, the last phase's too, and
  its big hits are counted (`phase_hits`, task E5b-c): each deals an equal part of what's left of the
  phase for each still to land (`hit_damage()`), and only the phase's last one ends it, exactly at its
  end, so nothing weapons chipped carries into the next phase and a phase of three hits always takes
  three, however far weapons chipped it (DESIGN-TBD, `docs/questions/e5b.md`). A
  hit never takes the boss past the end of the next phase, so every phase gets played. Each phase begins with its intro (`intro_seconds`: the boss can't be hurt and doesn't
  attack), then its pattern.
- **No escalation** (GDD §10): the run speed never rises in a fight, the arena doesn't ramp, and a
  boss script times its pattern only from its phase (`pace()`), so a pattern the player can't beat
  keeps cycling the same way; `test_bosses` checks it on the test boss.
- **The checkpoint**: a phase marked `checkpoint` stores where a retry resumes
  (`RunContext.boss_resume`: the phase, and the fight time, score and weapon damage so far);
  `RunContext.retry()` keeps it, starting the step afresh doesn't. `--phase=N` starts there in reviews.
- **The win**: the time bonus and the defeat score go to the ScoreKeeper, the parts are defeated, and
  LevelRun ends the run once the defeat has played out (`victory_over()`: at once by default; a
  defeat that plays out on the track, such as the Floating Head's crash and the run through its wreck,
  holds the results until it's over, at most `LevelRun.BOSS_VICTORY_MAX` seconds) and a short pause
  (`COMPLETE_PAUSE`); the runner keeps running meanwhile, safe (god mode). The win plays the victory
  riff unless the boss's `victory_riff()` says no (the Sleep Taker's defeat ends in silence). `RunResult.from_boss` pays the collected credits plus
  `payout_credits`, and gives the stars from the par times; the App records it as the step's record
  (best score, best time, stars) and submits the boss leaderboard, `boss/<boss id>/<tier>` (none in
  the web demo). Its results and level-select tile show the boss's stars and bests like a level's.
- **Pickups** (see Pickups): `armor_pickup_due(reason)` follows GDD §10's standard armor rule, at the
  start of the final phase and `armor_delay_min`–`max` seconds after the player's armor or shield
  breaks, at most `armor_pickups_per_phase` per phase, and each time the encounter offers an armor
  pickup (`_on_armor_pickup_due`, which a boss may override to place it its own way). With
  `BossDef.armor_when_unprotected` (E1e, DESIGN-TBD; on for the Floating Head) a phase that begins with
  the player's armor down and no shield (the free armor still coming back after a break) counts as a
  break at its start (`player_protected()`: armor up or a shield held, or an armor pickup due, on the
  track, waiting for a spot or held back by the boss, `armor_pickups_waiting()`), so no phase starts
  unprotected without a pickup on its way.
  `offer_pickup(item, at, lane)` offers an armor, shield or grapple pickup of the boss's own (GDD §10:
  a section of floor that spawns one; the test boss offers a shield in its second phase), and
  `phase_started` and `protection_broken` are there to time them. The win clears every pickup, and
  nothing is offered after it.
- **Hints**: boss-specific catalog triggers (`boss:<boss id>/<key>` in `data/hints/hints.json`)
  are collected for the level introduction, once per profile, including the Floating Head's
  `/ramp`, `/wall` and `/ceiling` routes. `hint_due(key)` remains a legacy encounter cue, but
  the hint presenter no longer listens to it during the fight.
- **The light**: `set_light_level(level, seconds)` fades the environment's ambient and sky light, its
  fog's light and the sun, never below `MIN_LIGHT_LEVEL`, and the scenery's own light with them (the
  `scenery_light` uniform a level's darkness sets: the skins' scenery shaders are unshaded, so dimming
  the lights alone leaves the street and the walls as they were; task E5c-a), never below
  `ZoneSkin.MIN_SCENERY_LIGHT`; glowing things keep their colours, and the light returns with the
  fight (the scenery's only if no newer run has set its own). `set_scenery_light(light)` sets the
  scenery's light directly, beyond that range, for a lighting moment of the boss's own (the Sleep
  Taker's grey dawn), and it's put back the same way (task E5c-b).

**To build a boss:** a script extending `BossEncounter` as the root of a scene in `scenes/bosses/`,
parts extending `BossPart`, a tuning resource of its own in `data/bosses/<id>_tuning.tres`, and the
slot's `BossDef` filled in (scene, phases, arena, numbers). Override the hooks it needs:
`_plan_lap`, `_build_boss`, `_on_phase_started` / `_intro_tick`, `_on_pattern_started` /
`_pattern_tick`, `_on_weak_point_hit`, `_on_part_defeated`, `_on_part_emp`, `_on_phase_ended`,
`_on_defeated` / `_defeated_tick` / `victory_over` / `victory_riff`, `_on_armor_pickup_due`. Every attack needs its visual and audio
warning (a floor warning from `props` also keeps pickups away), random choices come from `rng`, and
time from the physics step. The test boss (`TestBoss`) is a small example.

**The Floating Head** (GDD §10, task E1: E1a, the ship and face, the entrance, the bombing run and
the reveal; E1b, the face-off with its eye lasers and cyborg drop, and the marked towers that pin it;
E1c, the stomp windows while it's pinned; E1d, its propaganda and its defeat, and the City's boss step
plays it; E1e, the owner's playtest fixes; E1f, the fight at the City's speed), in
`scripts/bosses/floating_head/`:

| File | What |
|---|---|
| `floating_head.gd` (`FloatingHead`) | the encounter: each phase's intro (the first is the entrance, overhead from behind; later ones rise), its bombing run if it has one (`run_seconds(phase)`), then the descent in front of the runner (the first time, the reveal: the face powers on) and the face-off until a tower pins it (`begin_pin`: it brakes under the falling tower and lies still on the track, sunk between the trucks until its weak points' sockets are `pin_top_height` up and rolled toward the tower about its crown, `pinned_transform`; the tower breaks behind the weak points as it lands). Then the phase's stomp window (`route`, from `stomp_route(phase)`): `_open_window` switches the weak points and the crown's deck on and the hull hitbox off, and the way up is built in the arena (`_slam_ramp`: the tower's slab, a `FloatingHeadRamp`, in `ramp_lane`; `_light_wall_marks`: the wall route's cue, a `FloatingHeadWallMarks` on both walls, lit as the tower falls with `wall_marks_light` and cleared when the window closes; `_light_pads` and `_update_ceiling`: `props.pad` in every lane and a `props.ceiling` that lowers in once the ship is past its end), and the way's first-time hint is asked for (`hint_due`). `_check_window` closes it (`_miss`) when the runner is still on the trucks within `release_gap()` of its face (`window_release_gap`, or on the ramp route the end of its lead-in, where a lane switch stops boarding it) or past `pass_line()`; a stomp ends the phase instead (`_on_weak_point_hit` logs the dome's lane and the runner's). Either way it shakes free (`SHAKE`: it lurches ahead of the runner, its deck under a runner still on it until its face has passed them) and rises: to the next phase's station after a stomp (the phase's intro), back in front for the face-off after a miss (`RELEASE`). The ship's `pose` is kept relative to the runner (sideways, belly height, stern ahead) except while pinned, so nothing depends on how long the fight has lasted. Its distances along the track that stand for a time follow the run's pace (E1f; `run_pace()`, `metres()`, and `before_face()` for the ways up's distances before the pinned face, stretched about its weak points; which ones: `FloatingHeadTuning`'s header), so at the City's 21 m/s (or a harder tier's speed) it plays as it did at 18 m/s in seconds. The marked towers are planned with each lap (`_plan_lap`: every `tower_spacing`, sides in turn, the track cleared of holes and fences around each) and brought into sight as the runner nears them (`towers_between`, `tower_node`); a tower whose pin would land on a pickup or a dropped cyborg goes by (`pin_zone_blocker`), and armor pickups wait while a pin is under way (`pin_busy`, `_on_armor_pickup_due`). The fairness helpers its attacks share: `escape_lane`, `floor_clear_lane`/`floor_clear_all`, `pickup_near`, `enemy_in_lane`, `ceiling_between` (the arena's ceilings and its window's own: no bomb locks under one, the face-off waits past it). `sound()` plays and logs every warning; `warning_active()` says when one of its attacks warns or strikes, a cue still sounds, a cyborg it dropped is about or a pulsing fence is near (the propaganda gives way). The defeat (`_on_defeated`, then `_defeated_tick`'s steps): the propaganda cuts out (`voice.cut()`), pinned it shakes free (`SHAKE`), then `DYING` (it lurches up to `dying_pose()` in front of the runner, its face glitching: `_defeat_glitch`, steady with Reduced flashing), `FALLING` (it loses power and plunges to `crash_site()`: the first stretch ahead where the floor is clear around its wreck; it limps on until there is one) and `WRECKED` (`_crash`: the dust, its face falls flat before the wreck, `fallen_face()`, and its stern half lies sunk to `wreck_belly()`, a tunnel the lanes run through; `victory_over()` once the runner reaches its face; `wreck_passed()`) |
| `floating_head_body.gd` (`FloatingHeadBody`) | the body part: the model and its moving parts (face screen, jaw, searchlight gimbal, bay doors, weak-point covers that swing open with the red domes pulsing out: `weak_open`), a solid hull hitbox (`set_hull_solid`: off while pinned), a weak point over each lane near the crown's middle (generous stomp boxes, `stomp_width`/`stomp_depth`/`stomp_top`, as deep as the run's pace makes them, `stomp_depth()`; at 5 and 6 lanes the outermost ones also reach over the outer lanes out to the walls at their own height, `stomp_outer_reach`, where a wall jump or a drop off the ceiling lands: `stomp_covers_outer_lanes`, E1e) and the crown's deck (a concave shape exactly over the drawn hull, `FloatingHeadModel.deck_faces`), both off until a window opens (`set_weak_points_enabled`, `set_top_solid`; `top_height`, `weak_point_world`), the face's state (`screen_power`, `anger`, `eye_charge`, `glitch`, `jaw_open`, and `look_point` for the eyes to watch the laser's aim), where its eyes and mouth are (`eye_world`, `mouth_world`), and `exclusive_major_attack` (its lasers and bombs take turns with other big attacks). The slogan's caption band (`show_slogan`, `caption`: a Label3D in the face's cold white over a dark band the face shader draws across the screen's lower part, under the eyes; Label3D translates its text like the UI's labels). Beaten, it stays and keeps drawing itself: `power` fades its lights (per-instance copies of its kit materials' `state_glow`), `wreck(face_rest)` swaps in the wreck and lays its torn-off face in the street (cracked, framed), `crash_dust` and `start_smoke` (soft grey puffs from a radial `GradientTexture2D`) |
| `floating_head_model.gd` (`FloatingHeadModel`) | the low-poly meshes, built in code from a `Shape` sized to the street and its lanes (MeshKit layers merged into a few surfaces: about 13 surfaces and 11k vertices; the weak points over the lanes within `weak_point_reach` of the middle), the bomb, the crown's deck faces, and `ship_transform` (its pitch and its roll about the crown over the weak points). The wreck (`_wreck`): its stern half (`WRECK_LENGTH`), torn open at both ends (the cut plating and flaps peeled outward), plated inside, dark; `wreck_inner_half` is its inside's half width at a height (the runner's room in it, tested at every lane count) |
| `floating_head_voice.gd` (`FloatingHeadVoice`) | the propaganda: from the reveal on, a phrase every so often (`head_voice_1-4`, a seeded order and pauses of its own) from a positional player at the face, each with the next slogan (`FloatingHeadTuning.slogans`); it ducks `voice_duck_db` at once under `FloatingHead.warning_active()`, the slogan fades, and no phrase starts until the warnings have been over a moment; `cut()` stops it mid-shout for the defeat (`head_voice_cut`) |
| `floating_head_bombing.gd` (`FloatingHeadBombing`) | the searchlight and the bombs: the lock (the warning: red light, `circle_warning`, lock sound, the bomb falling with its whistle), the fairness rules (`plan`, `fair`, `escape_lane`), and pooled blast hitboxes (enemy attacks) that keep clear of a wall runner |
| `floating_head_faceoff.gd` (`FloatingHeadFaceOff`) | the face-off: the phase's attacks wait in line (`faceoff_pattern`; the first that can start fairly goes next) with a drag timed for each marked tower. Eye lasers: the warning (the eyes' `eye_charge` and whine, thin aiming beams with a sweep's aim lines or a drag's aiming spot, then the drag's `lane_warning`), a sweep's twin beams (low: both low, jump them; high: one at the waist and one above a jump's reach, like a gapped fence, slide under them) or a drag down the runner's lane leaving a burning line (keeps clear of a wall runner), each with enemy-attack hitboxes. The cyborg drop: the jaw opens (with its sound and `circle_warning`s where they land), then normal cyborgs from the director (`spawn_enemy`) fall from the mouth onto clear roof and fight. A tower's drag is a bait when the runner is in the outer lane on its side as the warning ends, or the fallback after `fallback_after` misses; either calls `FloatingHead.begin_pin`. Lasers wait while its cyborgs are ahead and share the cyborgs' airspace (`CyborgGun.AIRSPACE_META`) |
| `floating_head_tower.gd` (`FloatingHeadTower`) | a marked tower at the roadside (flush with the facades, its head jutting out over the street above the ship's highest flight so it shows from far along the street; no hitboxes: scenery until it falls): pale concrete with white painted bands and targets, cracks and cold warning lights; the laser's cut glows red-hot as it's clipped, then it topples forward onto the ship (`fall_onto`, `rest_on`), breaks in two as it lands (`break_at`, `tower_mesh`'s sections with torn ends: the lower section drops away), and the rest crumbles away when the ship shakes free |
| `floating_head_ramp.gd` (`FloatingHeadRamp`) | the first stomp window's way up: the tower's broken slab slammed down in a lane (`ramp_length` long, its top end `ramp_lift` above the crown at the face) in two pieces (E1e): a low lead-in over `ramp_board_share` of it, rising to its knee (`knee_height`: `ramp_board_height`, never above `side_step_limit`, what a lane switch steps up), with bevelled sides a lane switch steps up anywhere along it (`board_until`); then the steeper slab onto the crown, whose sides are a lane blocker down to the trucks. Both tops are floors (convex shapes, where they're drawn); green chevrons up both, the lead-in's edges in the ramp colour; it sinks away when the ship shakes free |
| `floating_head_wall_marks.gd` (`FloatingHeadWallMarks`) | the second stomp window's cue (E1e): on both walls, a strip of green chevrons at running height from `wall_entry_before` its pinned face (get onto the wall there) to a tall jump mark `wall_jump_before` it (jump off there); scenery, steady (the chevrons only scroll), never a hazard colour |
| `floating_head_face.gdshader`, `floating_head_light.gdshader`, `floating_head_laser.gdshader` | the face screen (unshaded and procedural: the same on every renderer; still with Reduced flashing; its `glitch`, the `caption` band, and `broken`: the dead screen in the street, cracked, the face burnt in faintly), the searchlight's beam and spot, and the lasers (the beams, the aim lines and the burning line: additive, lifted on the Compatibility renderer; the burn's embers hold still with Reduced flashing) |
| `floating_head_tuning.gd`, `data/bosses/city_boss_tuning.tres` | its numbers (F6 in its fight): metres at 18 m/s, stretched by the run's pace where they stand for a time (its header's Pace; `before_face_at`) |
| `data/bosses/city_boss_skin.tres` | its arena's City look: the City's skin without the towers' big screens hung out over the street, where the ship flies |
| `tools/showcase/floating_head_showcase.tscn` | close-ups and scripted runs for reviews (`--scenario=model/stern/below/entrance/bombing/reveal/faceoff/fallback/missed/pinned/window/mouth/slogans/defeat/wreck`, `--phase=N` for the phase's stomp window, `--board-late` to board the ramp from its side, `--e1c` for E1c's ramp and stomp boxes, `--speed=N`: the City boss step's 21 m/s by default) |
| `tests/helpers/floating_head_bot.gd` (`FloatingHeadBot`) | a runner who plays the fight by its warnings, pressing only named actions: dodges bombs and lasers, baits towers, and takes each stomp window's way up (`routes`: the wall by its marks; `ramp_board_at` boards the ramp from its side, `ceiling_moves` off rides straight ahead, `second_move` off never moves inward in the air; `wrong_route` stays on the trucks); it also runs the arena (`reads_track`: jumps holes and full fences, slides under gapped ones, sidesteps bolts), so it plays the whole fight without god mode (tests and the showcase). Its distances are metres at 18 m/s at the run's pace, and it takes the wall route by the marks where they are; `campaign_tuning()` is the City boss step's tuning (21 m/s), which the Floating Head's suites fight at |

**How the designed bosses fit** (GDD §10; each is a later task):
- **Floating Head (E1, built):** the City's boss step plays it; `weapon_share_cap` 0.34 keeps
  weapons to one stomp, and its defeat plays out on the track before the results (`victory_over`).
- **Sewer Swarm (E4, built, see below):** its clusters are parts with health of their own and
  `is_swarm`, each drawn as a MultiMesh crowd (`SwarmCrowd`); a cluster charging into a live fence or a
  hole is the surge's own check (`SewerSwarm.bait_between`, `bait_ahead` from behind, on the arena's track)
  then `part.defeat(&"fence")` or `&"hole"`, and `_on_part_defeated` deals `hit_damage()`. Phase 2 pairs
  front and rear surges in distinct lanes. Visible wall crowds damage and repel contact; phase 3 clears
  only the local weak-point route. The Host is the body part (`shares_health`) with one
  weak point over its implants, stomped through the framework (`stomp_weak_point`), and its lunge into a
  fence deals `damage(hit_damage(), &"fence")`.
- **The House (E5a, see below):** its reels are its spin's telegraph; cherry bombs are
  `circle_warning`s and blast hitboxes, the lightning one `props.fence` a lane rolled out by a spool,
  gold blocks of `props.block`'s kind (pooled in its own script) under `lane_warning`s. The 7 buttons
  are spots the boss script checks against the player's surface, lane and distance: phase 1's on the
  floor; phase 2's special one on a wall, with wall fences in play (B5's way: `WallFencePlan.make`,
  `arena.wall_fence_problem`, `arena.add_pieces`, built and pulsed by the track on the level clock;
  the wall run planned through their off windows); phase 3's under a ceiling of its own (a pooled
  billboard on the hull layer like `props.ceiling`'s) reached by a `props.pad`, with Barnacle Turrets
  through `spawn_enemy` (`"barnacle_turret"`, its params `hull_start`, `hull_end`, `first_lane`,
  `last_lane` naming that ceiling, within C1's limits). The machine stands taller than a ceiling's
  6 m, so it squats on its treads under the billboard while one is over the street. The jackpot's
  hopper is a weak point switched on once the machine has sunk; its credit fountain lands as real
  credits (`CreditField.place`).
- **Hostile Takeover (E5b, built, see below):** the train is the arena: `_plan_lap` replaces each
  lap with the train's carriage gaps across every lane (`HostileTakeoverTrain`: corporate carriages and
  long flatcars in a repeating consist), drawn by an arena skin of its own; the couplings are weak points
  on a part laid over each gap (E5b-a). Carriages breaking away behind the player are looks (the train's
  material). Phase 2 (E5b-b): the gunship's belly is a ceiling (`add_surface(..., true)`) ridden from a
  runway of pooled pads over an armored carriage, its drop bay a weak point stomped from the ceiling; the
  Buzz Overdrive (C2) is dropped onto a flatcar with its planned cut (`FloorCutPlan.make` at the arena's
  speed, `arena.cut_problem(cut)`, then `arena.add_pieces()` with the cut alone, past `stream_from()`;
  the tank comes into play through `spawn_enemy` at the cut's end as it lands, and finds its cut there,
  `buzz_overdrive_rules.cut_of`; the skin's `floor_cut` draws the roof cut); the strafes are a part's
  pooled attack hitboxes after BossProps' lane warnings. Phase 3 (E5b-c): the gunship docks onto the
  locomotive (the encounter flies one part with the other), its three docking clamps weak points under its
  belly stomped from the ceiling on passes (the drop bay's way), three counted hits; the defeat plays out
  on the track (`victory_over`: the gunship explodes, the locomotive ploughs into a tower's lobby).
- **Sleep Taker (E5c, built, see below):** the Dead Zone's boss step plays it; its generators come
  through `spawn_enemy("generator", ...)`, a destroyed one's EMP reaches the part (`_on_part_emp`:
  `damage(hit_damage(), &"emp")` while it's lured in), and its defeat ends in silence and a grey dawn
  (`victory_riff`, `set_scenery_light`).
- **The final villain:** two stages, the second a `checkpoint` phase, so a death there restarts at the
  second stage.

**The Sleep Taker** (GDD §10, task E5c: E5c-a, the nightmare, its arena, its entrance and its three
attacks, weapons having no effect; E5c-b, hurting it by the generators' EMP, the three phases, the
defeat and its campaign slot). The Dead Zone's boss step plays it (`scene` in its slot), at the Dead
Zone's speed (24.2 m/s, Bosses: Pace); debug builds also play it with `--boss=dead_zone_boss` (18 m/s
unless given `--speed`). Its tuning's distances that stand for a time (`refuge_first`, `refuge_spacing`,
the hands' and the generators' clear stretches, `escape_clear_after`, `generator_sight`, `emp_reach`,
`lure_release`) are written at 18 m/s and multiplied by the run's pace (`SleepTaker.run_pace()`), as the
Floating Head's are, so the fight keeps its seconds at any speed. In `scripts/bosses/sleep_taker/`:

| File | What |
|---|---|
| `sleep_taker.gd` (`SleepTaker`) | the encounter: its arena's refuges (`_plan_lap`: every `refuge_spacing` metres a ceiling across every lane, the Dead Zone's charred bridge, with pads in `pad_lanes()`, the middle lane or lanes, and the track clear of holes and fences over `refuge_clear_span()` and the riders' landing), the entrance (it rises out of the street `enter_ahead` ahead, materializing, and drifts in to `hover_ahead`), its place (`pose`, kept relative to the runner; the slash's and the lure's `pull()` bring it in), and the pattern (`_schedule`): one attack at a time, `attack_gap` apart; a refuge's slash when the runner reaches its warning point (`next_refuge`, `refuge_warn_at`: it strikes `strike_after_pad` after the pads; a moment missed is logged `refuge_missed`), otherwise the phase's list in order (`attack_patterns`: hands, lights_out), the first that can start fairly and be over before the next refuge's slash or the next lure going next; a generator `generator_delay` into each phase's pattern, or `generator_again` after a miss (`_update_generator`), nothing attacking while it's lured. `_on_part_emp`: an EMP while it's lured and within reach (`SleepTakerLure.reaches`) is the phase's hit (`damage(hit_damage(), &"emp")`): it tears a chunk away (`body.tear`, with its howl) and recoils into the next phase, hungrier (each phase's `pace` and list); any other EMP does nothing to it. The last one beats it (`_on_defeated`: `SleepTakerDefeat`; `victory_over` once the dawn has broken; `victory_riff` false: silence). Fairness helpers: `escape_lane`, `floor_clear_lane`, `ceiling_between`, `pickup_near`; `sound()` plays and logs each warning; first-time hints `boss:dead_zone_boss/refuge`, `/hands`, `/lights_out`, `/generator` (`hint_due`) |
| `sleep_taker_lure.gd` (`SleepTakerLure`), `sleep_taker_beacon.gdshader` | the way to hurt it: a generator (`FenceGenerator`, through `spawn_enemy`) placed in sight (`find_spot`: `generator_sight` ahead, in the runner's lane or the nearest whose floor is clear around it, no pad or ramp there, the lure's stretch clear of ceilings and of every refuge's slash; `place_at`), glowing: a tall beacon of its pink drawn over everything (it shows through the nightmare, which looms between the runner and it) and a halo on the street; the lure (`lure_seconds` before the runner reaches it the nightmare lunges in with its roar and holds its claws `lure_gap` in front of them, `pull()`, until they're `lure_release` past it), the arcs while it's in reach (`in_reach()`: lured and within `emp_reach`, at the run's pace; pink, crackling, still with Reduced flashing), and the miss (it pulls back over `lure_back_seconds`) |
| `sleep_taker_defeat.gd` (`SleepTakerDefeat`) | the defeat: `wisp_count` wisps burst out of it as it dissolves, each a faint face or figure from an atlas drawn in code (`atlas()`), rising and fading over `wisp_seconds`; the music fades out (`silence_fade`); `dawn_delay` later, over `dawn_seconds`, the sky turns to a grey dawn (its zenith, horizon and haze colours, the moon and the smoke fading, the fog lighter) and the light rises to `dawn_light` times the zone's own (the ambient light, the sun, the sky, and the scenery through `set_scenery_light`); the run's environment is its own, and the framework puts the lights back when the fight ends |
| `sleep_taker_body.gd` (`SleepTakerBody`) | the body part: `immune_to_weapons` (no targeting, no shot or splash hurts it; the BossDef's `weapon_share_cap` is 0 besides), no weak points, its touch an enemy attack inside its body and out of reach; the model scaled uniformly to the street (`scale_for`), what it's doing (`shriek`, `raise`, `slash`, `attack`, `lunge`, `inhale`, `swallowed`, eased), its torn chunks (`tear`, `torn`) and `draw_stats()` |
| `sleep_taker_model.gd` (`SleepTakerModel`), `sleep_taker_liquid.gdshader`, `sleep_taker_vapor.gdshader` | the nightmare, built once in code at its reference size: one liquid mesh (its fused heads, chest and waist, 28 maws facing the runner with the great one in its belly, two long arms and four tendrils of clawed fingers, drips) and one translucent vapour mesh (shroud, skirt, pool), each animated by its shader (maws breathing, gaping as it inhales, the great one opening with its teeth pulling back on a red throat, arms raising and sweeping, the lunge, the dissolve, and its chunks, `CHUNK_HEADS`, ripping away cell by cell with a burst of wisps), plus its drips and the inhale's streaming light: four draws and about 11k vertices. Black with the Bad Dream's purple; only an attack heats to enemy-attack red; no flicker with Reduced flashing. On the Compatibility renderer (no tonemapping) its shaders, the hand's and the mist's scale an over-bright colour down whole rather than let it clip channel by channel, which would turn its purple toward the fences' pink and its red toward salmon |
| `sleep_taker_slash.gd` (`SleepTakerSlash`) | the giant slash: the warning (`slash_telegraph` then the lunge: the great maw's shriek, its three lanes `band_for()` locked and lit red with the Bad Dream's lane marks, counted as floor warnings), the strike (`box_for()`: the lanes less margins, clear of the walls, below `slash_height`: above a jump, far below a ceiling rider) and the recovery; its timings don't follow the phase's pace |
| `sleep_taker_hands.gd` (`SleepTakerHands`), `sleep_taker_hand.gdshader`, `sleep_taker_mist.gdshader` | the grasping hands: `plan()` (the runner's lane, its floor clear around the hand, no ceiling or pickup there, a lane `max_escape_lanes` away clear), the mist (purple, unshaded, a floor warning) with its whispering, the hand bursting up as the runner nears and grasping, then sinking; pooled rigs |
| `sleep_taker_lights_out.gd` (`SleepTakerLightsOut`) | lights out: the inhale (its warning), `set_light_level(dark_level)` for `dark_seconds` while the other attacks go on, the exhale and the light back; `clear()` brings the light back at once (a phase change, the defeat) |
| `sleep_taker_tuning.gd`, `data/bosses/dead_zone_boss_tuning.tres` | its numbers (F6 in its fight; all DESIGN-TBD, `docs/questions/e5c.md`) |
| `data/bosses/dead_zone_boss.tres` | its slot: three phases (paces 1, 1.15, 1.3; one EMP each), weapons capped at nothing, the standard armor rule with `armor_when_unprotected`, the Dead Zone's music, par times |
| `data/bosses/dead_zone_boss_skin.tres` | its arena's look: the Dead Zone's, with nothing hung over the street (no skybridges, no hung screens), where it looms |
| `tools/showcase/sleep_taker_showcase.tscn` | close-ups and scripted runs for reviews (`--scenario=model/front/entrance/slash/hands/lights_out/lure/fight/measure`, `--phase=2` with `lure` for the defeat, `--dark` for a lure in the dark of lights out, `--events` for the frames; `measure` prints the warnings', hazards', the generator's and the street's colours on screen in the arena's light and at the darkest point) |
| `tests/helpers/sleep_taker_bot.gd` (`SleepTakerBot`) | a runner who plays the fight by its warnings, `reaction` seconds late: to a refuge's pad or out of the slash's lanes (`slash_escape`), out of a hand's lane, to each generator's lane and onto its top (`stomp_lead()`; or the dash, `dashes`; or out of its way, `smashes` off), and through the arena's holes and fences |

**The House** (GDD §10, task E5a: E5a-a, the machine, its arena, the spin with its three attacks and their
bigger versions, the 7 buttons on the floor, the jackpot with its credit fountain and the hopper stomped,
weapons chipping it; E5a-b, phases 2 and 3, the defeat, par times and its slot). The campaign plays it
after Marketplace 2 at the Marketplace's 22.6 m/s (`--boss=marketplace_boss` or `--level=marketplace/boss`
in debug builds): its tuning's distances that stand for a time (the buttons' and the stomp box's depth,
the margins) are written at 18 m/s and multiplied by the run's pace (`TheHouse.run_pace()`), and where an
attack, a button, a ceiling or its jackpot stop lands is a time at the run speed, so the fight keeps its
seconds. The October 3 difficulty revision uses three opening attack-only spins per phase instead of
two, attack/spin gaps of 0.85/1.0 s instead of 0.95/1.25 s, cherry coverage of 2/3/4 lanes and lightning
coverage of 2/3/4 lanes across phases, constrained by the existing fair-route planner.
Pars are 86 s for three stars and 108 s for two. Clean unprotected wins measure 80.4-82.4 s across
3, 5 and 6 lanes at 18 and 22.6 m/s, with all 27 strikes from the nine opening spins retained.
Every strike, every set of buttons and the jackpot's approach is planned only where a
route exists (`TheHouseRoute`) for a runner who reads the warnings and moves a reaction time after them,
through everything else still on the track, at any lane count: that's how every attack has an escape and
every button is reachable while dodging. Phase 1's buttons are all on the floor; each later phase puts its
special reel's button (`special_buttons`, `special_reel`) on a wall (phase 2, with wall fences along both
walls) or under a floating billboard reached by an anti-grav pad and guarded by Barnacle Turrets (phase 3);
that button comes last in its set, and the set is offered only with a way over the floor buttons from the
first one's showing and, from where that way has the runner a reaction time after the special one shows
(a wall button once it's out from behind the machine, a ceiling's pad as the billboard comes down), on over
it: a hold of the outer lane over the wall run, or of the pad's lane over the pad, then the ceiling's own
route past the turrets. While the runner goes for one, its attacks wait (`attacks_held`). The machine is
taller than a ceiling: it squats on its treads under `duck_top` while a billboard is over it. In
`scripts/bosses/the_house/`:

| File | What |
|---|---|
| `the_house.gd` (`TheHouse`) | the encounter: its arena kept plain (`_plan_lap`: no holes, fences, wall fences, signs, ceilings, pads, ramps, doodads, cuts or enemies of its own); where it stands (`front_at`, its face's track distance: `stand_distance()` ahead of the runner, keeping pace, or further at a speed where its longest warning would land near it), squatting under a ceiling (`_duck`, `duck_sag()`); the entrance (it rolls in from `enter_ahead` and brakes, with its jingle); the spin (`_spin_tick`: the lever's pull, the reels spinning and stopping on the phase's next symbols from `spin_patterns`, each with its ding; the phase's first `opening_spins` spins offer no buttons, every later one a button for each reel still unlocked, `_try_pull` waiting for a fair set, a ceiling's set starting its billboard); the result (three 7s start the jackpot, otherwise `TheHouseAttacks.queue_spin`); a stomp is the phase's hit (`_on_weak_point_hit`); a missed jackpot clears the locks and it spins again. The defeat (`_on_defeated`, `_defeated_tick`, `Defeat`): it lurches out and rises as after any stomp, its reels spin wildly (`WILD_SPIN`, `tilt_spin_seconds`) and jam between symbols, TILT shows over its reels (`tilt_seconds`; flashing, steady with Reduced flashing), and it collapses into the street ahead of the runner (`collapse_seconds`), tipping, shaking, its power dying, `collapse_coins` coins bursting out (the fountain's pool, for show), the citizens cheering; `victory_over()` once it's down. Fairness: `route_through()` (from the runner's lane now, through everything of its attacks still ahead, over any buttons), `route_from()` (from where the runner will be), `attacks_held()` and `segment_end()` (the street the runner's again past a wall run or a ceiling). `react_citizens()` calls D3's `react` on the `"market_citizens"` group (cheer at a jackpot, a stomp and its defeat, duck at a big attack); `sound()` plays and logs every warning; first-time hints `enemy:marketplace_boss`, `boss:marketplace_boss/buttons`, `/wall_button`, `/ceiling_button` and `/jackpot` |
| `the_house_route.gd` (`TheHouseRoute`) | the lane routes: the track ahead as SOLID stretches (blocks, blasts, turrets' bodies), FENCE (jumped, settled in its lane, nothing solid where the jump takes off or lands) and GAPPED (slid under) in each lane; a lane switch takes `switch_m` (the real one times `switch_margin`, plus a margin) with the runner in both lanes meanwhile; a body reaching `body` either side; waypoints (buttons) held in their lane as the runner passes, and holds (`{lane, at, to}`: a lane kept over a stretch, a wall run from its outer lane or a pad). `find()` keeps the fewest switches, each as early as it can (no zigzag), and returns the moves; it runs within a frame as attacks are revealed and buttons planned (flat arrays, each switch's span checked at once: about 1 ms for 100 m at 6 lanes). The bot follows the same routes |
| `the_house_attacks.gd` (`TheHouseAttacks`) | the three attacks (`Kind`: CHERRY, LIGHTNING, BAR), grouped by kind in reel order (`attacks_for`: a kind's count is its size; a 7 brings none), each revealing its strikes in turn (`strikes_in`: cherry volleys and BAR rows by size; three lightnings, two rows across every lane, full then gapped), each strike planned as it shows (`plan_strike`: the first lane set of a seeded order, the runner's lane first, with a route, off the wall fences' drop windows), waiting up to `strike_wait` for a fair moment, else left out (`strike_skipped`); a new attack waits while `TheHouse.attacks_held()`. Cherry: `circle_warning`s, bombs lobbed from the coin chute, the whistle, blasts (pooled enemy-attack boxes) as the runner would arrive. BAR: `lane_warning`s and gold blocks falling from high above, slammed down `bar_slam_lead` before the runner arrives as solid hazards of `props.block`'s kind with a lane blocker (gold with red-hot seams: deadly, never a doodad). Lightning: `props.fence`s flickering with their crackle while a pink-capped spool rolls across, on `fence_on_lead` before the runner arrives. `obstacles()` and `hazards_end()` describe what's still on the track; `strikes` lists them for tests and the bot. Everything an attack shows is pooled and made before the fight (`prewarm()`: bombs, blast boxes, fireballs, blocks with their hazards, spools; `pool_stats()`), as are the buttons' looks, the billboard and the fountain's coins, so a fight makes nothing of its own mid-fight; the warnings, fences and pads are BossProps' (made per strike), the turrets the director's |
| `the_house_buttons.gd` (`TheHouseButtons`), `the_house_button.gdshader` | the 7 buttons: `plan()` (a lane for each floor button, at most `button_max_shift` from the one before and never the same; a wall button by either outer lane, a ceiling's pad off the edges; the first set of a seeded order with its routes, `MAX_TRIES` a frame), each lighting up `button_lead` before the runner reaches it (a wall button `wall_lead`, reached `wall_extra` later; a ceiling button once its billboard is down) with its chime (`house_button`), `pressed` or `missed` as the runner passes (on the floor, low, their middle within the button's width; on its wall, at any height; on the ceiling in its lane); the look: an ivory disc with chasing bulbs and the reels' blue 7 (flat on the floor, upright on the facade at wall-run height and as tall as the wall-run path, facing down on a ceiling), and the 7 floating near it, shrinking away as the runner nears it; pooled |
| `the_house_walls.gd` (`TheHouseWalls`) | phase 2's wall fences (`wall_fence_phases`): full-height ones along both walls, one every `wall_fence_every` seconds on alternating walls, pulsing `wall_fence_on`/`wall_fence_off` on the level clock, planned a batch past the built track (`wall_fence_ahead`) as B5's track pieces (`WallFencePlan.make`, `arena.wall_fence_problem`, `arena.add_pieces`), so they're built, pulse, warn and hurt like a level's; `passage_off()` (a wall run passes a stretch only while every one in it is off, `fence_pass_margin` either side), `drop_windows()` and `in_drop_window()` (B5's: the machine's strikes keep off the outer lane a wall runner drops into) |
| `the_house_ceiling.gd` (`TheHouseCeiling`) | phase 3's ceiling: `plan()` (the pad where the runner reaches it, off the edges; the button `ceiling_button_after` past it in its lane; one or two Barnacle Turrets in the lane on one side of the pad's, with C1's limits: never over the pad's lane, `after_pad_seconds` past the pad, `spacing_seconds` apart, `before_end_seconds` before the end; its end `ceiling_end_after` past the last), `route()` (along it past the turrets' bodies over the button), `start()` (its turrets spawned a frame apart through `spawn_enemy`, in their hatches until the runner nears; once the machine has squatted, the billboard comes down from the sky over `billboard_drop_seconds` with its pad, `props.pad`, and its sound); the billboard: a StaticBody on the hull layer over every lane like `BossProps.ceiling`'s (the player rides it like any ceiling and drops back down at its end), its own look (a purple slab trimmed in gold, white bulbs, the reels' 7 on its sign, a plated underside with flush lamps and the orange end band every ceiling has: one merged mesh per size), pooled and its mesh made before the fight with the turret's script, numbers and look; `active()`, `landing_end()`, `over()` |
| `the_house_jackpot.gd` (`TheHouseJackpot`) | the jackpot: SAG (sirens, lights flashing, the citizens cheer; it rolls on, braking, to where the runner reaches it `jackpot_approach` later with its approach clear of the attacks and past a wall run's or a ceiling's end, `approach_clear`; the hopper bursts open with the fountain, `fountain_count` credits flung out and landing ahead of the runner, off the attacks' hazards, as `CreditField.place` credits; it sinks, on from a squat, so its top is a deck `deck_height` up: `set_sunk`), OPEN (the hopper is its weak point; passed without a stomp, a miss), LURCH (it shoots ahead out from under the runner) and RECOVER (it rises and rolls back to where it paces; `finished(stomped)`); `burst_coins()` (the defeat's coins for show) |
| `the_house_body.gd` (`TheHouseBody`) | the body part: its cabinet a solid body hitbox while it stands; the hopper's weak point (across the street wall to wall, `stomp_depth` at the run's pace: `hopper_length`); its top deck a floor while it's sunk (`set_sunk`, the cabinet's hitbox off); `aim_point()` (its reels, its hopper once sunk); what it's doing (`sag`, `lever`, `lights`, `jackpot`, `hopper`, `power`, `track_speed`, and its defeat's `tilt`, `collapse`, `shake`) eased onto the model; its reels (`TheHouseReels`) |
| `the_house_model.gd` (`TheHouseModel`), `the_house_reels.gdshader`, `the_house_symbols.gdshaderinc`, `the_house_lights.gdshader`, `the_house_hopper.gdshader`, `the_house_treads.gdshader`, `the_house_tilt.gdshader` | the machine, built in code from a `Shape` sized to the street (`shape_for`: the street less `street_margin`, `height` under the cables across the street, as deep as the stomp box needs): the cabinet and its trim (one kit mesh: purple paint, chrome, unlit gold; nothing on it glows), the cult's emblem in brushed bronze at the heart of its marquee's sunburst, the three reels standing out of its face (one draw: drums whose symbols are drawn as distances, each in its attack's colour: a red cherry, a gold BAR plate, a pink bolt, and the buttons' royal blue 7; smeared while spinning, a lock glowing), its bulbs and sirens (one draw: warm and cold whites, chasing and strobing, steady with Reduced flashing), its rolling treads, its lever on the face's edge, the hopper's two lids and its red-hot inside: 9 draws, under 3k vertices; the TILT sign over the reels' window (its defeat: warm-white letters ringed in gold, flashing, steady with Reduced flashing; hidden until then) and the collapse (tipping forward and over, shaking). On the Compatibility renderer its shaders scale an over-bright colour down whole (the 7's blue never clips toward the pads' cyan) |
| `the_house_reels.gd` (`TheHouseReels`) | the reels' symbols and drums: `spin` (`wild` for the defeat's), `stop` (the symbol known at once; the drum eases onto it with a bounce), `jam` (between two symbols, no bounce), locks on 7 (`unlock`) |
| `the_house_tuning.gd`, `data/bosses/marketplace_boss_tuning.tres` | its numbers (F6 in its fight; all DESIGN-TBD: OPEN_QUESTIONS items 299-303, `docs/questions/e5a.md`) |
| `data/bosses/marketplace_boss.tres` | its slot: `scene`, three phases (one stomp each), weapons capped at 0.34 of its health, the standard armor rule with `armor_when_unprotected`, the Marketplace's music, par times (72 s and 92 s), its arena (two plain laps) |
| `data/bosses/marketplace_boss_skin.tres` | its arena's look: the Marketplace's, its pennants strung high above the street where it rolls |
| `tools/asset_gen/sfx_bank_the_house.gd` | its sounds (`house_*`: the entrance, the lever, the reels, the ding and the lock, a button, each attack's warning, the slam, the jackpot, the coins, the sag, the stomp, the billboard coming down, the TILT jam and the collapse); its bombs fall and blow with the Floating Head's `bomb_whistle` and `bomb_blast` |
| `tools/showcase/the_house_showcase.tscn` | close-ups and scripted runs for reviews (`--scenario=model/front/entrance/spin/buttons/jackpot/wall/ceiling/defeat/fight`, `--symbols=a,b,c` for the spin's symbols, `--lanes`, `--speed`, `--phase`, `--events`) |
| `tests/helpers/the_house_bot.gd` (`TheHouseBot`) | a runner who plays the fight by what it shows, `reaction` seconds late: a route (TheHouseRoute) through every warning on the track and over the lit buttons (`takes_buttons`, `avoids_buttons`, `skip_reels`), a wall button's wall run (onto the wall `wall_entry_before` it, a wall jump back past it, or off at once before a wall fence that would be on), a ceiling's pad and its route along the ceiling (dodging the turrets' bolts into the free lane beside the pad's, `dodges`), fences jumped or slid under, and a jump timed to come down on the hopper (`stomp_lead()`; `stomps` off lets it pass) |

**Hostile Takeover** (GDD §10, task E5b: E5b-a, the train arena, the gunship and the locomotive, and phase 1,
The Board, with the carriage couplings; E5b-b, phase 2, The Contract; E5b-c, phase 3, The Merger, the
defeat, the par times and its campaign slot). The campaign plays it after Corporate 2 at the zone's
23.4 m/s (`--level=corporate/boss` or `--boss=corporate_boss` in debug builds; the showcase and the measure
tool also play it at quick play's 18 m/s). Its tuning's distances that stand for a time (a carriage's
length, the stomp box's reach past a gap, the clear corridors around a coupling, the guards' spacing, the
tithe trail's spacing, a strafe's line, the runway of pads, the ride's landing) are written at 18 m/s and
multiplied by the run's pace (`HostileTakeover.run_pace()`), a gap is a share of a jump at the run speed,
like a level's, and a pass rides the belly at `pass_speed` whatever the run speed, so the fight keeps its
seconds at the zone's 23.4 m/s: a clean fight takes 68.6 s at 3, 5 and 6 lanes and both speeds (phase 1's
stomp at 19.6 s, phase 2's 24.8 s later, phase 3's last clamp 24.2 s after that; par 74 s for three stars,
96 s for two). Where the gunship and the locomotive fly and stand is framing, in metres. Its data turns
`BossDef.weapons_can_end_phase` off (DESIGN-TBD): weapons chip it, but only its stomps end a phase, each
phase's counted (phase 3 always takes its three clamps).
- **The train is the arena** (GDD §10: "carriage roofs are the floor and the gaps between carriages are the
  gaps, so it plays like a level"): `_plan_lap` clears each lap the generator made and puts in the train's
  gaps, one across every lane at the end of each carriage (`HostileTakeoverTrain`: `gap_jump_fraction` of
  a jump at the run speed; the carriages in the tuning's `consist`, corporate carriages `carriage_length`
  long and military flatcars `flatcar_length` long, for phase 2's drop, at the pace, stretched a little so a
  lap holds whole consists and the laps join without a seam). Gap `k` ends carriage `k` (`gap_start`,
  `roof`, `kind`, `next_flatcar`), the same over the whole fight.
- **The couplings** (`HostileTakeoverCouplings`): one over every gap, laid by the encounter from just
  behind the runner to the built track's end, each in a lane of its own (`HostileTakeoverBoard.lanes`:
  never the last one's lane, at most `coupling_max_shift` from it). From a phase's pattern on, past its
  `opening_gaps` dark gaps, they glow red (lit at least `lit_sight` before the runner reaches them) with
  green chevrons on the roof in their lane where a jump takes off to come down on them. Its weak point (its
  stomp box) spans its lane over the whole gap and `stomp_before`/`stomp_after` past its edges, up to
  `stomp_top` over the roofs: a jump that comes down over the gap in its lane, or moves into it in the air,
  stomps it, and the stomp's bounce carries the runner on (`HostileTakeoverTrain.bounce_clears`); running
  off the edge never reaches its top less the stomp tolerance, so a fall isn't a stomp. The stomp is the
  phase's hit (`stomp_weak_point`); the coupling breaks open and the carriages behind break away and tumble
  off the track (looks only: `HostileTakeoverSkin.set_breakaway` on the train's material; the collision
  stays the track's). A coupling passed is missed, harmlessly: the next gap's glows the same way.
- **The Board** (`HostileTakeoverBoard`), carriage by carriage as the built track nears it: guards (the
  zone's cyborgs, as VR runners) placed where nothing they do reaches a coupling's run-up (`approach_clear`)
  or its bounce's landing (`landing_clear`) in its lane, outside the cyborgs' own margin from a gap
  (`CyborgRules`), `guard_spacing` apart and fewer than the lanes, so a way through is always open; a partial
  wall fence (low and high in turn) on `wall_fence_share` of the carriages where `arena.wall_fence_problem`
  allows one (B5's rules), pulsing as the zone's do; and on each flatcar from `tithe_first` on a Tithe
  Collector and nothing else (no guards, no wall fence: it weaves toward the lanes with the most hazards
  ahead, and with none keeps to the runner's), brought into play in the runner's lane as they reach it
  (`spawn_enemy`), at most `tithe_visits_per_phase` a phase (OPEN_QUESTIONS item 321: a runner who lets the
  couplings go by can't farm their jackpots), with a trail of credits laid on the roof ahead of it for it to
  skim (`lay_tithe`, `CreditField.place`; a boss's track has no credits of its own). Every choice is seeded
  per carriage, so every attempt plays the same. The Board plans only while a phase plays it
  (`tick(active)`); as phase 2 begins the encounter stands it down: its guards still to come are retired as
  they come into play (each guard's entry names its `board_phase`) and its wall fences ahead are switched
  off the EMP's way (`TrackBuilder.disable_fences_near`).
- **The Contract** (`HostileTakeoverContract`, phase 2, planned from the phase's start so its first
  flatcar's cut still finds the track ahead unbuilt), one cycle after another:
  - the drop, onto the next flatcar: a level's Buzz Overdrive cut (`FloorCutPlan` with the C2 tank's own
    rev, charge and run past, no roll), in a seeded lane `arena.cut_problem` allows, added to the track;
    the gunship flies out over its spot (a red target on the roof marks it), lets the tank it carries fall
    (`drop_fall`) to land `drop_before` its rev, and the real tank comes into play there (`spawn_enemy`:
    its rev and line, its charge, the block-then-hold rule, all its own);
  - the ride, over the second carriage past it, armored (`HostileTakeoverArmored`: `armored_height` tall,
    its front in the solid obstacles' yellow and black, no dash through it), placed `ARMORED_SIGHT` ahead
    with a runway of pads in every lane before it (`pad_strip` long: no jump clears it, a dash in the air
    included, `HostileTakeoverContract.strip_clears`); the gunship comes down over the runner to the
    ceiling's height and flies on slower than them (`belly_front`), so they ride its belly from the runway
    until `landing_after` past the armored carriage's far gap; its drop bay, open and glowing red with
    green chevrons before it, is the phase's weak point (DESIGN-TBD), stomped by a jump on the belly that
    comes back up onto it (`bay_lead`); a bay let go by is missed and the next flatcar's cycle comes;
  - strafes in between, when nothing else is going on (`strafe_fits`: no drop or ride near, no phase-1
    guard about): red lines along the runner's lane and the one beside it (`struck_lanes`: never all of
    them) with the rising whine for `strafe_warning`, then the guns rake each line from its far end back
    past the runner (`HostileTakeoverStrafes`: an attack hitbox over a jump's reach in each lane; the
    walls are safe).
  Pickups keep off a ride (`_pickup_at`: an armor pickup due there goes past it, where the runner lands).
- **The Merger** (phase 3, GDD §10: "the locomotive comes back and the gunship docks onto it with huge
  clamps, forming one monstrous war engine, and 'MERGER COMPLETE' flashes on every screen ... its attacks
  combine both"): once phase 2's ride is over (a ride under way flies through), the docking
  (`Step.DOCK`, `dock_seconds`): the locomotive comes back from `loco_ahead` to `merger_ahead` while the
  gunship settles onto its rear (`DOCK_OFFSET`, its belly `dock_height` over the roofs), its arms gripping
  the locomotive's flanks and its three clamps unfolding under its belly as they lock (`set_docked`,
  `takeover_clamps`); then MERGER COMPLETE (`Step.MERGED`, `takeover_merger`, the hint
  `boss:corporate_boss/merger`) on the locomotive's rear window turned screen and two ad screens on pylons
  rising beyond the barriers ahead (`HostileTakeoverScreens`: the Chairman's face as a broadcast, the words
  flashing for `merger_flash_seconds`, steady with Reduced flashing). The war engine then leads the train,
  the locomotive moving with the gunship (`docked_pose`), and the contract plays on in its merger mode
  (`start(true, not_before)`, or `merge()` keeping phase 2's planned drops that come after the docking): the
  drops as phase 2's (the war engine moving along the line, never out over the roof), the strafes (docked,
  the first `merger_hold` after MERGER COMPLETE), and after each drop a pass instead of a ride
  (`plan_pass`): a runway of pads on the carriage after the flatcar, placed so the runner drops back onto a
  roof as far from a gap as it can be; the war engine comes back and down over them (`pass_descend_seconds`)
  so they ride its belly forward at `pass_speed` (`pass_u`) under its three clamps (`clamp_at`, one under
  each third of the belly, `clamp_side`), each glowing red with the ways up's green chevrons on the belly
  behind it (`clamp_cue`: a jump from anywhere on it comes back up onto the clamp, `clamp_lead`), live while
  they ride under it until it's torn loose (`tear_clamp`, `takeover_clamp`); at `pass_release` it pulls
  away (`pull_speed`) and they drop back onto the roof. Clamps left in a pass stay for the next; a pass let
  go by is missed and the next flatcar's cycle comes (no time limit, no escalation). The Board comes back
  on the consist's `merger_board_slots` (guards from `merger_guards`, wall fences, no Tithe Collector; never
  on a pass's runway or landing carriage). Phase 3's parts are built with the fight, hidden until needed
  (the shader warm-up draws them during the load).
- **The defeat** (GDD §10: "the gunship spins away and explodes; the locomotive derails and ploughs through
  the lobby of a corporate tower, bringing down a giant, soulless logo sculpture"): the last clamp torn
  loose, the contract halts and a corporate tower's lobby with its plaza's logo sculpture is set beside the
  line ahead (`HostileTakeoverLobby.place`, on `derail_side`; the city's towers keep clear of it,
  `HostileTakeoverSkin.set_clearing`); the gunship pulls free, climbs away beside the line spinning and
  explodes `explode_at` seconds later (`takeover_explode`); the locomotive surges on, veers off the
  guideway and ploughs into the lobby `crash_at` seconds in (`takeover_derail`), its wreck wholly beyond the
  barrier, the sculpture toppling back into the lobby; each blast a fireball big enough to read far ahead
  (`HostileTakeoverLobby.blast`: swelling and cooling, dimmer and never white-hot with Reduced flashing);
  the screens glitch and go dark (their tearing only dims with Reduced flashing). The parts no longer tick
  once the boss is beaten, so the encounter runs the screens' and the blasts' clocks (`step`). The runner
  runs on (god mode from the win on, as every boss's), and the results come `defeat_seconds` after the
  stomp.

In `scripts/bosses/hostile_takeover/`:

| File | What |
|---|---|
| `hostile_takeover.gd` (`HostileTakeover`) | the encounter: the arena (`_plan_lap`), its parts, the phases (phase 1's intro is the entrance: the gunship sweeps in from behind and above the runner with its roar; a later phase's begins with it lurching) and their patterns (`pattern_of`: The Board, The Contract, The Merger), a Board pattern lighting the couplings from `opening_for(phase)` gaps on (`couplings_from`); every frame it lays the couplings over the gaps in sight (`RIG_BEHIND` to `RIG_AHEAD`), lights the live ones (`coupling_lit`; the first brings the `takeover_couplings` cue and the hint `boss:corporate_boss/couplings`) and notes the missed ones; a stomp (`_on_weak_point_hit`: the coupling breaks open, `takeover_decouple` and `takeover_breakaway`, the breakaway's clock; or the drop bay bursts, `_bay_stomped`; or a docking clamp is torn loose, `_clamp_stomped`); phase 2's stand-down (`_stand_down`, `_on_enemy_spawned`), its ride's start and end (`ride_begins`: the bay opens, `takeover_bay`, the hint `boss:corporate_boss/ride`; `ride_ends`), pickups kept off a ride (`_pickup_at`); phase 3's docking (`_update_merger`: `docking`, `clamps_locked`, `merger_complete`; `docked`, `docked_pose`, `_docking_done_at`) and its passes' start and end (`pass_begins`: the hint `boss:corporate_boss/clamps`; `pass_ends`: `pass_landed`/`pass_missed`); the gunship's flight relative to the runner (`station_pose`: `gunship_ahead`, `gunship_height`, swaying and bobbing on the fight's clock; docked, the war engine's; the contract's `pose` over it), the locomotive `loco_ahead` ahead (docked, with the gunship); the defeat (`_on_defeated`, `_defeated_tick`, `_place_defeat`: `defeat`, `gunship_exploded`, `locomotive_crashed`; `victory_over` after `defeat_seconds`). `coupling_live`, `next_live_coupling`, `run_pace`, `sound()` (plays and logs), `warm_enemies()` (the guards, the Collector and the Buzz Overdrive); first-time hints `enemy:corporate_boss`, `boss:corporate_boss/couplings`, `/strafe`, `/ride`, `/merger` and `/clamps` |
| `hostile_takeover_train.gd` (`HostileTakeoverTrain`) | the train's plan: `plan()` (the consist), `gap_start`, `gap_end`, `next_gap`, `gap_at`, `roof`, `kind`, `carriage_at`, `next_flatcar`, `lap_gaps()` (a lap's gap entries), `ends_behind()` (for the breakaway), `bounce_clears()` |
| `hostile_takeover_board.gd` (`HostileTakeoverBoard`) | phase 1's plan (`tick(active)`, `plan`, `pause`): the couplings' lanes (every phase), the guards (`guard_fits`, `guard_reach`; none on a flatcar), the Tithe Collectors (`tithe_spot`, `tithes_due`, `lay_tithe`; `visits` a phase, capped) and the wall fences (B5's `WallFencePlan.make`, `arena.wall_fence_problem`, `arena.add_pieces`, at the arena's difficulty; none on a flatcar); in phase 3 (`merger`) only on the consist's `merger_board_slots`, no Collector; a `carriage_planned` event each |
| `hostile_takeover_contract.gd` (`HostileTakeoverContract`) | phase 2's and phase 3's plan and course (`start`, `merge`, `stop`, `halt`, `tick`; `merger`, `not_before`): the drops (`plan_drop`, `saw_now`), the rides (`plan_ride`, `ride_now`, `next_ride`, `ride_stretch`, `belly_front`, `bay_lead`, `relative_speed`, `longest_leap`, `strip_clears`), phase 3's passes (`plan_pass`, `pass_u`, `clamp_lead`, `up_time_for`), the strafes (`strafe_fits`, `struck_now`) and the gunship's flight for them (`pose`, `riding`); events `contract`, `drop_planned`/`drop_refused`, `drop_marked`, `saw_released`, `saw_landed`, `ride_planned`, `ride_placed`, `ride_begins`, `ride_boarded`, `ride_landed`/`ride_missed`, `pass_planned`, `pass_placed`, `pass_boarded`, `strafe_warned`, `strafe_rake`, `strafe_done` |
| `hostile_takeover_armored.gd` (`HostileTakeoverArmored`) | the armored carriage part, pooled: its body (a solid hitbox a little inside its look, no dash through it) and its runway (a pad trigger the lane's full width in every lane, its tiles one MultiMesh of the skin's lift pad); `place` (a pass's runway without the body), `release`, `body_span`, `strip_length` |
| `hostile_takeover_strafes.gd` (`HostileTakeoverStrafes`) | the strafes' rakes, pooled (`RIGS`): per struck lane an attack hitbox over a jump's reach, the burning streak of its impacts and the tracer from the gunship's guns (a flicker, steady with Reduced flashing); `start`, `set_front`, `stop` |
| `hostile_takeover_couplings.gd` (`HostileTakeoverCouplings`) | the couplings part: a pool of `POOL` rigs moved from gap to gap (`place`, `release_before`; the coupling's halves, its dome dark or glowing red and pulsing, steady with Reduced flashing, a red halo while live, the take-off chevrons, its weak point), `set_live`, `arm`, `break_open` (its rear half drops away), `box_span`, `takeoff` (where a jump that lands on it leaves from) and `descent_lead()`; immune to weapons, no kill of its own |
| `hostile_takeover_gunship.gd` (`HostileTakeoverGunship`) | the boss's body: it shares the fight's health (weapons chip it, up to the cap); its belly a ceiling (`belly`, the hull layer), its drop bay's weak point (`bay_point`, upside down) with its glow and the green chevrons before it (`set_bay`; the bay's pulse steady with Reduced flashing), the Buzz Overdrive it carries and lets fall (`set_saw`, `saw_world`, `set_fall`, `end_fall`: the C2 tank's own model), its chin gun's muzzle flash (`set_firing`, `gun_point`); phase 3's docking (`set_docked`: the arms gripping the locomotive, the clamps unfolded) and its three docking clamps (`clamps`: each a weak point upside down under a third of the belly, its lock glowing red and pulsing, steady with Reduced flashing, the green chevrons behind it, `clamp_cue`, `clamp_lead`; `tear_clamp`, `clamps_left`, `clamp_of`, `clamp_span`, `clamp_world`); `set_pose`, `bay_span`, `aim_point`, `hit_radius` |
| `hostile_takeover_locomotive.gd` (`HostileTakeoverLocomotive`) | the locomotive leading the train, the Chairman at its rear window (`set_front`, `set_pose` for the docked war engine and the derailment, `set_chairman_shown`, `chairman_head`); never a target |
| `hostile_takeover_screens.gd` (`HostileTakeoverScreens`), `hostile_takeover_screen.gdshader` | phase 3's screens: the locomotive's rear window turned screen and two ad screens on pylons beyond the barriers pacing the train ahead (`pace`), each the Chairman's face as a corporate broadcast (the shader: drawn as distances so it stays crisp, faint scanlines and a cold-white frame, the defeat's glitch tearing it in bands, only dimming with Reduced flashing; on the Compatibility renderer an over-bright colour is scaled down whole) under the words (`merger_text`, one TextMesh in the UI's display face for all three, translated), dark until the docking (`set_on`), the words flashing for `merger_flash_seconds` (steady with Reduced flashing, `words_shown`), glitching and going dark in the defeat (`set_glitch`; `step` runs their clock) |
| `hostile_takeover_lobby.gd` (`HostileTakeoverLobby`) | the defeat's set: a corporate tower whose sky lobby faces the line and its plaza's logo sculpture (`place`, `span`, `topple`, `lobby_world`), and its blasts (`blast`, `step`: pooled fireballs of a few glowing spheres), built with the fight and hidden until the defeat; looks only |
| `hostile_takeover_model.gd` (`HostileTakeoverModel`) | the meshes, built once in code, one draw per material: the gunship (about 2,000 vertices; olive and gunmetal, its belly flush and as wide as the train, its closed bay doors, the three docking clamps folded under it, cold-white lights and blue engines), its open drop bay (`bay_open`) and the chevrons before it (`belly_cue`), the armored carriage (`armored`), the locomotive with the Chairman's lit suite (about 560) and the Chairman (about 640), the coupling's parts and the take-off chevrons; phase 3's clamps (folded, unfolded, their red locks: `clamp_folded`, `clamp_body`, `clamp_core`), the docking arms (`dock_arm`), the screens' pylons (`screen_pylon`), and the defeat's tower (`lobby_tower`, about 500) and logo sculpture (`logo_sculpture`, about 190). Plain colours on everything that moves (the kit's world-space patterns would slide); nothing glows in a hazard colour but the weak points' red |
| `hostile_takeover_skin.gd` (`HostileTakeoverSkin`), `hostile_takeover_train.gdshader`, `hostile_takeover_towers.gdshader` | the arena's look, the Corporate zone's (`CorporateSkin`): the floor as one wide train (the express's roof across every lane, the usual orange edge at each gap, a floor cut sliced down its lane) in a material of its own whose vertex shader plays the breakaway, each carriage tumbling about its own rear end (`set_breakaway`, `clear_breakaway`); the runway's pad tile (`pad_tile`); the walls as the track's sound barriers (gunmetal panels between posts, the wall-run marks, nothing lit below the band's top); beyond them the city's towers rushing back at the train's speed (`towers_for`: one mesh per side per chunk, moved by its shader, so nothing is made while the train runs; `set_clearing` keeps a stretch on one side clear of them, the defeat's lobby) and far below the street streaming past (the City's road shader in the zone's colours) under the guideway's beam; nothing hangs over the street |
| `hostile_takeover_tuning.gd`, `data/bosses/corporate_boss_tuning.tres` | its numbers (F6 in its fight; all DESIGN-TBD, `docs/questions/e5b.md`) |
| `data/bosses/corporate_boss.tres` | its slot: `scene`, three phases (one stomp, one stomp, the three clamps), weapons capped at 0.34 of its health and never ending a phase (`weapons_can_end_phase` off, DESIGN-TBD), the standard armor rule with `armor_when_unprotected`, the Corporate zone's music, par times (74 s and 96 s), its arena (one lap of the train) |
| `data/bosses/corporate_boss_skin.tres` | its arena's look: the VR runners on the roofs, a thinner fog so the locomotive shows at the end of the view, nothing over the street |
| `tools/asset_gen/sfx_bank_hostile_takeover.gd` | its sounds (`takeover_*`: the gunship's entrance, the couplings going live, a coupling stomped, the carriages breaking away; the strafe's rising whine and its rake, the tank's drop, the drop bay opening; the docking clamps locking, MERGER COMPLETE's sting, a clamp torn loose, the gunship exploding, the locomotive derailing into the lobby) |
| `tools/showcase/hostile_takeover_showcase.tscn` | scripted runs and close-ups for reviews (`--scenario=run/train/gunship/locomotive/coupling/contract/merger/defeat`, `--lanes`, `--speed`, `--phase`, `--cam=back/run/side/ride/dock/belly/clamp/chase`, `--defeat-after`, `--still`, `--events`) |
| `tests/helpers/hostile_takeover_bot.gd` (`HostileTakeoverBot`) | a runner who plays it by what it shows, `reaction` seconds late: every gap jumped, each live coupling's lane reached a lane at a time (never across a guard) and a jump timed to come down on it (`stomp_lead()`; from the lane beside it with `side_lane`, the other side if a guard stands there; let go by with `misses`, from its own lane with `skip_in_lane`; `drops` runs off the edge), out of the guards' lanes and their bolts' line; in phase 2 out of a strafe's lanes and a landed tank's (`ignores_strafes`, `meets_saw` for tests of a hit), over the runway and on the belly a jump onto the drop bay (`bay_lead`; `bay_misses` lets some go by); in phase 3 on a pass the lane under the next clamp still locked ahead and a jump onto it (`clamp_lead`, `clamp_lane`; `pass_misses`, `clamps_per_pass`) |
| `tools/measure/hostile_takeover.gd` | the fight through quick play at every lane count and speed: a death in phase 3 once docked, the retry won whole with its defeat played out, whether every attempt played the same (options in its header: misses of each kind, clamps a pass) |

**The Sewer Swarm** (GDD §10, task E4: E4a, the clusters, the arena and phase 1, the Rising; E4b, phase 2
Surrounded, phase 3 The Host, the defeat, par times and its slot). Its slot's `scene` plays it after
Gangland 3 at Gangland's 21.8 m/s (debug builds: `./play.sh --boss=gangland_boss`, quick play's 18 m/s).
Its tuning's distances that stand for a time (where a surge meets the runner, how far it charges, the baits'
spacing, the fairness margins) are written at 18 m/s and multiplied by the run's pace
(`SewerSwarm.run_pace()`), so at Gangland's 21.8 m/s it plays the same in seconds. Before the October 3
difficulty revision, a clean fight took 86.1 s
at both speeds (the Rising ends at 19.7 s, Surrounded at 53.6 s), one that lets a chance go by in each phase
108.3 s; the October 3 pars were 92 s for three stars and 125 s for two. The revision raises cluster health
36 to 48, reduces bait spacing 200 to 185 reference metres and Host offsets 88 to 74, tightens surge
warnings/locks without reducing the time to reach bait, shortens wall-climb gaps 2.5 to 1.75 s, and
changes Host fling windup/flight/splat durations from 0.7/1.1/0.8 to 0.6/0.9/1.0 s.
Measured clean wins take 84.5 s (phase ends 18.8/50.2 s), and a missed chance in each phase takes
109.5 s, within those pars. The October 4 follow-up pairs front and rear phase-2 surges in two distinct
lanes, leaving X-2 safe lanes. Front/rear warnings are now 1.55/1.70 s, with unchanged 0.9/1.0 s locked
dodge windows and 0.65/0.70 s to choose bait before locking. Every visible wall crowd remains naturally
colored but damages and repels contact through the normal protection rules. Wall pressure continues
into phase 3, receding only around the ramp approach, boosted wall run, jump and landing route.
The Host now requires six hits instead of three; each of its three implants goes dark after two hits.
Phase-3 climb coverage extends beyond the longest local route by `route_cover_ahead` (12 reference
metres), with extra creatures allocated at setup to preserve density. Phase 2 retains its original
50-metre forward extent and 220 visible creatures; no crowds are allocated mid-fight.
Clean wins take 104.3-104.7 s across 3/5/6 lanes and both speeds; one missed chance per phase takes
133.8 s. Updated pars are 115/150 s, retaining three stars for clean wins and two for one miss per phase.
Phase 3 has no clusters left (GDD §10's
"flings the remaining clusters": DESIGN-TBD, docs/questions/e4.md): the Host flings balls of screeches
scooped from the horde, from the clusters' crowd pool. The boss brings no normal enemies (`warm_enemies()`
is empty): every crowd, the Host, the pipe and the jump marks are made with the fight and drawn hidden at the
load, so its look compiles nothing mid-fight (`frame_times.gd --bosses=gangland_boss --shaders` under xvfb, on
both renderers: 23 shaders at the load, and only the framework's armor pickup, first offered at the final
phase's start, first drawn later: `ShaderWarmup` doesn't sample a pickup's look). In
`scripts/bosses/sewer_swarm/`:

| File | What |
|---|---|
| `sewer_swarm.gd` (`SewerSwarm`) | the encounter: its arena (`_plan_lap`: Gangland's generated holes and fences with nothing else on the track, and every `bait_spacing` from `bait_first` a bait spot, a live full-height fence or a hole in one lane in turn, the lane seeded and at most `bait_max_shift` from the last, the street around it, `bait_clear_span()`, clear of every other hole and fence in every lane), its spots' geometry (`spots_between`, `next_spot`: one whose warning point passed unused is logged `bait_missed`; `warn_at`, `strike_at`, `entry_at`, `surge_reach`, `charge_speed`), `bait_between()` (the first live full fence or hole a cluster charging down a lane meets), its clusters (`clusters`, `queue`: waiting at the roadside ahead, sides alternating, the next to surge nearest at `surge_reach()` and the others `station_spacing` behind it, keeping pace and easing up as the line moves; `next_cluster(side)` takes the first on the bait's side; `requeue` sends one that missed to the back, re-forming), its crowds' pool (`crowd_pool_size`, `take_crowd`, `release_crowd`: every cluster's crowd and a flung ball's made before the fight), its horde, the Rising's intro (the clusters rise one after another, `swarm_rise`), `_on_part_defeated` (a cluster destroyed: its sound and burst, `bait_score` for a bait, then the phase's `hit_damage()`, as weapon damage if weapons destroyed it: within `weapon_share_cap`; `_ensure_clusters` keeps a phase's clusters up to the hits it still needs). E4b: each lap's host spots after its bait spots (`_plan_host_spots`, `host_spots_between`: a ramp in an outer lane, sides in turn, the street clear around it, `host_clear_span`), phase 2's sides (`surge_from_behind`: `surge_sides` in turn, `note_surge`), a strike from behind's reach and bait (`behind_reach`, `bait_ahead`), `fence_between` (the Host's lunge), phase 3 (`HOST_PHASE`: the clusters sink away, `SwarmHostAttacks` takes over), the climb ticked in phase 2, `_on_weak_point_hit` (a stomp on the implants), the defeat (the Host freed, the horde draining; `victory_over` after `freed_seconds`). Helpers: `player_lane` (a wall runner's outer lane), `sound` (plays and logs), `sound_point`, `hint` (`boss:gangland_boss/bait`, `/behind`, `/host`), `warning_active`, `low_end` (`DeviceProfile.is_low_end()`: the smaller crowds) |
| `swarm_surges.gd` (`SwarmSurges`) | independent front/rear surge states and pooled aim lines. Rising uses a front surge; Surrounded pairs front and rear in distinct lanes at each bait opportunity, synchronizing their strikes while retaining independent warning/lock windows. Front: WARN, POUR, CHARGE; rear: WARN, locked WAVE, CRASH then run-on. Each claims a different cluster, checks its lane's fence/hole, and requeues on a miss. Attacks, locks, crashes, hits and cleanup are logged; cluster defeat and phase changes clear the appropriate state. The Host retains access to the reusable aim line |
| `swarm_cluster.gd` (`SwarmCluster`) | a boss part with independent `cluster_health`, `is_swarm` (heavy-missile bonus), and weapon targeting only during a surge. Its charging lane hitbox is an enemy attack; its visible wall mound also damages and repels wall contact, with damage applied before repulsion. Stages FORMING, WAITING, GATHER, POUR, CHARGE, SHOCKED, FALLING, SCATTER and WAVE drive the pooled crowd; wall creatures retain natural colors. Destroyed clusters play their death and return the crowd to the pool |
| `swarm_crowd.gd` (`SwarmCrowd`), `swarm_crowd.gdshader` | one crowd: ONE MultiMesh of the screech's crowd mesh (`ScreechModel.crowd_mesh()`, about 100 triangles) with ONE material, drawn in one call; per creature only its instance custom data (three random numbers placing it, and its rank); the shader places and animates every creature (a cluster's mound against a wall's foot, rearing; the pour into a lane in rank order; the lane-wide mass charging, heaped in the middle; shocked on a fence (flung back, burning pink, crackling, steady with Reduced flashing), falling into a hole over its far edge, scattering; thinned by its `alive` share, its highest ranks first, and drawn only up to it, `show_up_to`; a band's horde in a gutter, gathered in drifting heaps; a lair's spill; E4b: a strike from behind's wave, rising and curling over the lane before it crashes (`set_wave`, `set_wave_shape`), a climb covering a wall (`set_climb`), the Host's bulk (`set_host`: standing, rearing, charging, crouched, shocked, knocked off a share at each hit, scattering when it's freed; its heat only while it attacks), a flung ball (`set_ball`)) with the screech's legs, spines and tail, from a few uniforms set only when they change (`set_param`). The screech's look in linear light on every renderer, its skin lifted toward a sickly pale (`skin_lift`: dark olive vanishes on Gangland's asphalt), and an attack's heat (`bristle`) burning its spines, eyes and silhouette enemy-attack red; on the Compatibility renderer an over-bright glow is scaled down whole. Every instance carries a white colour, never read: the Compatibility renderer multiplies a MultiMesh's vertex colours by its instance colour, zero in one without colours (the lairs' MultiMeshes too). `made` counts crowds made (tests: none mid-fight) |
| `swarm_horde.gd` (`SwarmHorde`), `swarm_lairs.gd` (`SwarmLairs`), `swarm_lair.gdshader` | the scenery at the roadsides, never in the lanes and never hurting: a band in each gutter (`horde_*`: from `horde_behind` to `horde_ahead`, following the runner, drifting back, heaped every `horde_heap_spacing`; filling up over `horde_fill_seconds`, draining away at the defeat); the lairs, a manhole at the street's edge or a vent at a wall's foot every `lair_spacing` along both sides, alternating, none over a hole or by a fence (two MultiMeshes, their instances reused as the runner passes: rattling from `rattle_ahead`, the slots glowing steadily brighter, bursting at `burst_ahead`: a cover flips and lands askew over its hole, a grille flies off; every lair in sight bursts at the fight's start and during the Rising, `lair_burst_share` of them after); the spill, `spill_creatures` pouring out of each lair as it bursts. Visual only: it runs from `_process` |
| `swarm_climb.gd` (`SwarmClimb`) | alternating, naturally colored wall crowds in phases 2 and 3. Visible occupancy supplies enemy-attack contact damage before repulsion, with wall-entry blockers matching the drawn extent; armor/shield/grace remain standard. It waits rather than beginning on the runner's occupied wall. Host routes create local shader recession and matching collision gaps through ramp approach, wall run, jump and landing, leaving the rest dangerous. Crowds and hitboxes are pooled; cleanup disables all occupancy |
| `swarm_host.gd` (`SwarmHost`), `swarm_host_person.gd` (`SwarmHostPerson`) | the Host body (`shares_health`), hidden until phase 3: its pooled crowd, humanoid rig and three red implants. Six successful hits free it, with each implant darkening after two. Poses STAND, LUNGE (attack hitbox), STUNNED (solid), CROUCH (solid sides, back surface and settled weak point), and FREED reuse their hitboxes; `knock` removes a share of the crowd after each hit. Flung splats are enemy attacks |
| `swarm_host_attacks.gd` (`SwarmHostAttacks`) | phase 3, The Host, timed from the runner's distance at the arena's spots: ENTRANCE (the pipe `pipe_ahead` ahead; at `host_burst_at` it tears open, `host_burst`, and the Host drops out and leaps to its station), PACE (`host_ahead` ahead, mid-street), FLING (at a hole spot: a ball of screeches from the crowd pool, a `circle_warning` where it lands in the runner's lane from the wind-up on, `host_fling`; it splats there as the runner would reach it, `splat_seconds`), LUNGE (at a fence spot, a surge's timing: the roar, `host_roar`, and the aim line; at the lock it charges down the runner's lane, `fence_between`: shocked by the fence, a hit, `damage(hit_damage(), &"fence")`, down for `stun_seconds`), CROUCH (at a host spot: `crouch_settle` before the ramp it leaps into the ramp's lane and crouches past it, `host_crouch`, with the jump marks on the ramp's wall; stomped, it shorts an implant; passed, it rises and leaps back), FREED (the defeat). A spot whose moment passed goes by (`host_missed`); every attack and contact logged (`host_*`) |
| `swarm_pipe.gd` (`SwarmPipe`), `swarm_jump_marks.gd` (`SwarmJumpMarks`) | scenery, made with the fight and drawn hidden from its start: the big pipe across the street the Host bursts out of (pale steel ringed with rust, small warm lamps on its brackets; torn open at the burst), and the green chevrons on a ramp's wall from the ramp to `jump_mark_until` past it, ending in a tall jump mark (never flickering) |
| `sewer_swarm_tuning.gd`, `data/bosses/gangland_boss_tuning.tres` | its numbers (F6 in its fight): every crowd size (`cluster_creatures`, `horde_creatures`, `climb_creatures`, `host_creatures`, `spill_creatures`, each with a smaller `_low_end` one: the phone test, E3, sets them; the fight never reads them), the clusters, the surges, the baits and host spots, the Rising, Surrounded (strikes from behind, the wave, the climb), The Host (the pipe, its station and size, flings, lunges, crouches, the defeat); all DESIGN-TBD (`docs/OPEN_QUESTIONS.md` 324-328, `docs/questions/e4.md`) |
| `data/bosses/gangland_boss.tres`, `data/bosses/gangland_boss_skin.tres` | its slot: `scene`, three phases (Rising: two clusters; Surrounded: three; The Host: three hits, `intro_seconds` 4 for its entrance), weapons capped at 0.34 of its health, par times (92 s and 125 s), the standard armor rule with `armor_when_unprotected`, Gangland's music; its arena (three laps of Gangland's street, no features) in a skin of its own (Gangland's, its gutters darker where the horde runs) |
| `tools/asset_gen/sfx_bank_sewer_swarm.gd` | its sounds (`swarm_rise`, `swarm_chitter`: the surge's rising warning, as long as it, `swarm_surge`, `swarm_shock`, `swarm_fall`, `swarm_scatter`; E4b: `swarm_wave`, a strike from behind's warning, `swarm_climb`, `host_burst`, `host_roar`, the lunge's warning, `host_fling`, `host_crouch`, `host_short`); the lairs are the screech's (`ScreechLair`'s look) |
| `tools/showcase/sewer_swarm_showcase.tscn` | the fight for reviews through the run camera (`--scenario=rising/surge/fence/hole/fight/model/behind/host/stomp/defeat/hostmodel`, `--phase=N`, `--lanes`, `--speed`, `--crowd=N`, `--low-end`, `--stay`, `--reduced-flashing`, `--events`) |
| `tools/showcase/swarm_stress.tscn` | the rendering stress test for the phone test (task E3): N clusters of C screeches (`--clusters`, `--crowd`, `--horde`, `--spill`, `--low-end`, `--lanes`, sliders live) drawn exactly as the fight draws them, cycling through what a cluster does, with a readout (fps, frame time and its worst, the crowds' CPU time a frame, draw calls, primitives, objects); `--seconds=S` prints a summary line and quits |
| `tests/helpers/sewer_swarm_bot.gd` (`SewerSwarmBot`) | a runner who plays the fight by what it shows, `reaction` seconds late: to the bait's lane when a surge warns (`baits`; or out of it, `avoids_surge_baits`), out of the locked lane after the lock (`bait_escape` &"switch", or &"jump" over the bait; `dodges` off stands in it), out of a fling's lane, a lunge baited like a surge, a crouch's ramp and wall jump (`stomps`, `jump_after`), the first `skips` chances of each phase let go by, and the arena's holes and fences read like any runner (`reads_track`), with a `home_lane`; `tools/measure/frame_times.gd` plays the fight with it |

- **The crowds' cost** (measured with `swarm_stress --seconds=8`, software rendering under a virtual display
  on a shared 4-CPU machine, so counts, not timings, for the GPU side): one draw call a crowd whatever its
  size, on both renderers (the fight's five clusters, two bands, the spill and two kinds of lair: ten for the
  whole swarm), and 102 triangles a screech. The stress scene's eight crowds at the low-end sizes (524
  screeches), the defaults (1,324) and twice the defaults (2,648): 8 draw calls at every size (30 in all with
  the street and the readout's 22) and 55,000, 136,000 and 271,000 triangles, on Forward+ and on
  Compatibility alike; the CPU sets a few uniforms a crowd a frame, 0.16-0.19 ms for all eight in GDScript
  at every size (it never touches a creature). Software frame times grow with the triangles (llvmpipe);
  the phone test (E3) measures the real GPU cost and sets the crowd sizes.
- **Fairness, proven** (`test_sewer_swarm`, `test_sewer_swarm_fight`): every spot's surge window is clear but
  for its bait; its bait is in reach from any lane before the lock (a reaction and a switch a lane across
  the street at 6 lanes fit its 1.3 s); every lane has a way out (a clear neighbouring lane, or the wall
  beside an outer one: the arena has no signs); a baited cluster meets its bait ahead of the runner; every
  strike from behind is warned `behind_warning_seconds` before it crashes and has a way out from every lane;
  the climb leaves one wall free; the Host's crouch is reached by a ramp and a wall jump at both speeds; the
  bot wins each phase and the whole fight at 3, 5 and 6 lanes at 18 and 21.8 m/s, after a death and a retry,
  and through the campaign (`test_sewer_swarm_*`).

## Cinematics

GDD §1 tells the story mostly through the zones themselves, plus 5–15 second cinematics between levels and
zones (their story beats come from the owner later; task F2). The cinematic toolkit (`scripts/cinematics/`,
task F1) is code-driven: a cinematic is a timeline of camera keys, actors on the humanoid rig and timed
events, played on a stretch of the slot's zone.

**The flow.** A slot's `CinematicDef.scene` is a scene whose root extends `Cinematic`
(`scripts/campaign/cinematic.gd`). The App instances it under the world root and calls `play(def, step)`;
the cinematic knows its `step`, `zone` and `slot` (`&"intro"`, `&"boss_intro"`, `&"outro"`; played on its
own, it finds the campaign step whose slot holds its def). At its end it emits `finished` once, and the App
marks the step done and seen and moves on (`advance_from`), so the next step's first frame follows at once.
**Skipping:** the pause action (Esc / P) or the cinematic's Skip button emits `skip_requested`, the App
answers with `skip_cinematic()` → `skip()`, and the cinematic ends within the call. `App.playing_cinematic()`
is the one playing. A cinematic holds while the game is in the background (focus lost, app paused), so it
never ends, and a level never starts, unattended.

| File | What |
|---|---|
| `cinematic_sequencer.gd` (`CinematicSequencer`) | the player: builds the stage, actors, camera and overlay, runs the clock (`advance`), fires the events, emits `finished`; `skip()`; `log_lines` lists every event fired (tests, the review tool); a script's hooks: `_on_cue()`, `_on_advance()` (its own props on the clock), `switch_stage()` (a cut to another stretch, even another zone's) |
| `cine_timeline.gd` (`CineTimeline`) | one cinematic: `duration`, `letterbox`, `stage`, `camera` keys, `actors`, `events`; helpers to build one in a script (`shot`, `actor`, `sound`, `music`, `card`, `effect`, `cue`); `problems()` checks it; `sort()` |
| `cine_key.gd`, `cine_path.gd` (`CineKey`, `CinePath`) | a key's time and how the path comes into it: `SMOOTH` (a flight through the keys, velocity carrying on through each), `LINEAR` (a straight move eased by Tween's transition and ease types) or `CUT`; `sample_riding` for keys that ride with an actor |
| `cine_camera_key.gd` (`CineCameraKey`) | where the camera is (`position`), what it looks at (`target`), `fov`, `roll`; `follow` / `watch` an actor: the point is then an offset from it |
| `cine_actor.gd`, `cine_actor_key.gd`, `cine_actor_node.gd` | an actor (`RUNNER`: Razor Echo's `PlayerAvatar`; `CYBORG`: a `CyborgBody` in the zone's look or a look of its own, a host or not), its keys (position, pose, heading, the runner's head turn `look`, a cyborg's face, aim and charge) and its node in play |
| `cine_event.gd` (`CineEvent`) | `SOUND` (a sound effect), `MUSIC` (a track, `@zone`, or none), `TEXT` (a card), `EFFECT` (`fade_in`, `fade_out`, `flash`, `shake`, `letterbox_in`, `letterbox_out`), `CUE` (a script's own moment) |
| `cine_stage_def.gd`, `cine_stage.gd` (`CineStageDef`, `CineStage`) | the set: a stretch of track built by the `TrackBuilder` in the zone's skin, with its sky and fog (`ZoneSkin.level_environment(0)`) and the run's sun; ceilings, gaps, pads and openings in the side walls (`wall_gaps`, dressed by the skin as in a level); streamed in chunks like a run |
| `cine_overlay.gd` (`CineOverlay`) | the 2D layer: letterbox bars, fades, flashes, text cards (menu fonts, capitals) and the Skip button (showing the pause key), in the safe area |
| `arrival_flyover.gd`, `arrival_flyover_tuning.gd`, `scenes/cinematics/arrival_flyover.tscn`, `data/cinematics/arrival_flyover.tres` | the placeholder arrival flyover (below) |
| `city_outro.gd`, `city_outro_set.gd`, `city_outro_tuning.gd`, `scenes/cinematics/city_outro.tscn`, `data/cinematics/city_outro_tuning.tres` | the Neon City's outro (below) and its props |

**Track space.** Every point is `(x, y, z)`: x metres right of the start lane's centre (the lane a level's
runner starts in, `lane_count / 2`), y metres up from the floor, z metres along the track. So a point
at x = 0 is on a lane's centre at 3, 5 and 6 lanes alike; `CineStage.point()` / `to_track()` convert,
and `lane_x()`, `wall_x()` and `lane_from_start()` give the street's geometry for scripts. Stage lanes are
counted from the start lane too (a lane past the street's edge is left out).

**The stage picks up the slot's look from the zone's data.** A stage def without a skin of its own takes
the slot's (`CineStage.skin_for`): the zone's skin (`ZoneDef.skin`), and before a boss the fight's arena's
(`BossDef.arena.skin`) if it has one. Its lanes default to the device's (`App.lane_count()`), so the street
matches the level that follows. A `@zone` music cue plays the slot's track (`ZoneDef.music`, or before a
boss `BossDef.music` if set); a track the music library doesn't list yet is skipped quietly and the music
playing carries on, so a song the owner adds later under that name just plays (no music is generated for
cinematics, GDD §11). Text on cards may name `{zone}`, `{zone_number}`, `{boss}` and `{title}`
(translated, then filled in). So a later change of a zone's skin, music or name reaches its cinematics.

**Cameras.** Keys are sampled with `CinePath`: `SMOOTH` keys make a Hermite spline timed by the keys (a
Catmull-Rom whose tangents come from the neighbouring keys), with no jolt at any key; `LINEAR` keys ease
with Tween's curves (`TRANS_SINE` + `EASE_IN_OUT` starts and ends at rest); a `CUT` holds, then jumps. A key
that follows (or watches) an actor gives an offset from it: between two keys riding with the same actor
the camera rides along, its offset moving through the keys; between a fixed key and a riding one it flies
through where each key will be at its own time; the velocity carries on through every key either way.
Straight up or down, the camera's up is the track's direction. `shake` follows the Screen shake setting.
A camera flying over a street must keep out of what hangs over it: nothing does below about 10 m in any
zone except ceilings (6 m up, their structure up to about 13 m), so keep under 9.5 m over open street and,
over a ceiling or within a few metres of one, at least `camera_ceiling_clearance` (1 m) under its underside,
as the run camera does (closer, the ceiling's end glow fills the screen); the tests check the flyovers so.

**Actors.** The runner is the real player model (`PlayerAvatar`), driven with the same movement state as
in play: its stride keeps pace with the ground it covers, it is in the air above the floor (with its jump
poses), leans into sideways moves like a lane switch, and takes `slide`, `dash`, `stomp` and `dead` from its
keys; it is in the air below the floor too (falling past its edge), and a key's `look` turns its head (shared
by its chest, neck and head, turning smoothly between keys). A cyborg (`CyborgBody`) walks or idles by its
speed, or takes `aim`, `run_away`, `cower` or `die`;
its keys set its face, its aim (at another actor) and its charge glow (the red glow is its attack's
warning in play, so show it only where an attack follows). An actor faces the way it moves, or a heading
of its keys; it's in the scene from `enter` to `leave`. Actors are visual only: no collision, no gameplay.

**Reduced flashing and comfort.** `flash` becomes a slow, faint glow with Reduced flashing
(`CineOverlay.SOFT_FLASH_ALPHA`, `SOFT_FLASH_MIN_TIME`); nothing in the overlay blinks; the skins honour it
as in play; `shake` is scaled by Screen shake (0 when it's off).

**Writing a cinematic.** In data: a scene whose root is `CinematicSequencer` with `timeline` set to a
`CineTimeline` resource (`tools/showcase/cinematic_sampler.tres` shows every kind of key and event). Or in
a short script, which can use the stage's geometry:

```gdscript
extends CinematicSequencer   # the root of scenes/cinematics/<name>.tscn; the slot's CinematicDef.scene

func _stage_def() -> CineStageDef:          # the set; no skin: the zone's (from its data)
	var d := CineStageDef.new()
	d.ceilings = PackedVector2Array([Vector2(120.0, 170.0)])
	return d

func _make_timeline() -> CineTimeline:      # `stage` is built by now
	var t := CineTimeline.new()
	t.duration = 8.0
	var runner: CineActor = t.actor(&"runner")
	runner.at(0.0, Vector3(0.0, 0.0, 0.0), &"run")
	runner.at(8.0, Vector3(0.0, 0.0, tuning.run_speed * 8.0))  # LINEAR keys: a steady run
	t.shot(0.0, Vector3(stage.wall_x(1) - 2.0, 3.0, 10.0), Vector3(0.0, 1.0, 0.0))
	var ride: CineCameraKey = t.shot(8.0, Vector3(0.0, 4.2, -7.5), Vector3(0.0, 1.0, 14.0))
	ride.follow = &"runner"                 # the run camera's view of the runner
	ride.watch = &"runner"
	t.music(0.0, CineEvent.ZONE_MUSIC, 1.5)
	t.card(1.0, "{zone}", "ZONE {zone_number}", 3.0)
	t.effect(0.0, CineEvent.FADE_IN, 0.8)
	t.effect(7.6, CineEvent.FADE_OUT, 0.4)
	return t

func _on_cue(cue_name: StringName) -> void:  # a CUE event's moment (the `cue` signal fires too)
	pass

func _on_advance(delta: float) -> void:      # every step of the clock: move the script's own props by `time`
	pass
```

A script's props (models of its own that aren't actors) are plain nodes it adds in `_make_timeline()` and
moves in `_on_advance()` from `time`, so they keep time when a test steps the clock. `switch_stage(def, skin)`
cuts to another stretch on the same lanes (track space stays put; cut under black, since building one takes a
few frames).

Then set the slot's `CinematicDef.scene` to the scene. End on the run camera's view of the runner
(`MovementTuning`'s camera numbers) or on black, since the next step opens on its own view at once.
`tools/showcase/cinematic_review.tscn` plays any slot's cinematic on its own for renders (`--slot=<step
id>`, `--sampler`, `--lanes=N`, `--reduced-flashing`, `--once`), printing each event with its frame.

**The arrival flyover** (DESIGN-TBD, `docs/questions/f1.md`; `ArrivalFlyover`, a short script with its
numbers in `data/cinematics/arrival_flyover.tres`): every zone's intro slot and the City's boss intro play
it until the owner describes the story beats. It opens low in the street looking up at the zone's skyline
and tilts down as the runner runs in beneath it, glides over the street behind the runner, and settles into
the run camera's view as they run under one of the zone's ceilings; a card names the zone ("ZONE 1", "NEON
CITY"; before a boss, the boss, as the level select does), the slot's music comes in, and it fades to black
after 9.5 s, as the level (or the fight) opens on the same view. Gaps beside the runner's lane show the
zone's floor pieces. It sets up in about 15-40 ms and costs about 0.3 ms a frame (headless), so it stays
cheap on the web, where the demo plays the City's two.

**The City outro** (`CityOutro`, task F2a; the owner's beats, GDD §6 Cinematics; its staging is DESIGN-TBD,
`docs/OPEN_QUESTIONS.md` §D, items 369–381; numbers in `data/cinematics/city_outro_tuning.tres`): 15 s. From the run camera's view
the dying Floating Head plunges into the street ahead and becomes the fight's wreck. The camera comes down to
the runner's level as they stop. They look left, and the camera pans over their shoulder to a roadblock at the
mouth of a side street opening off the left wall. The roadblock is Barnacle Turrets standing on the floor like
cannons, five cyborgs (actors), an Enforcer Truck behind them with its light bar going, and a heli drone over
it. The camera pans back to the runner, who hops back startled and sprints to an opening in the right wall.
They leap out over the drop as the roadblock's red volley blows up the roof behind them, seen from out over
the drop. Under black it cuts (`switch_stage`) to the next zone's street (the campaign's next `ZoneDef.skin`,
Gangland), where they drop in, land and run off; Gangland's intro follows.

`CityOutroSet` holds the props, all visual only and built from the game's own models: the ship from
`FloatingHeadModel` (hull, face screen with the fight's shader, jaw, wreck), `BarnacleTurretModel` turned
over, `EnforcerTruckModel`, the drone's model (`drone.gd`'s static `add_model`, which the enemy uses too),
`EnforcerTruckBlast`, and a code-built barricade. The side street's floor and both openings' building fronts
come from the stage's skin (`ZoneSkin.floor_segment`, `wall_section`), so they follow the zone's look.
Reduced flashing holds the dying face's glitch and the light bar steady, and the blast has no white-hot core.
Music: the zone's track, fading as the runner leaps; the web demo, which ends after this, never loads
Gangland's. Cost (headless, `test_city_outro`): about 25 ms to set up (about 220 ms the first time, with cold
mesh caches), about 10 ms for the cut (under black), at most about 3 ms a step, and its props add about 65
draw calls. It adds no asset files.

## Economy and saving

`Profile` (`scripts/app/profile.gd`) keeps earned and purchased credits apart (net worth = earned,
unspent), item tiers and stock, equip toggles, records per difficulty tier, settings and stats.
`SaveService` writes it to `user://profile.json` (with a backup). `Loadout` is what one run carries:
owned, switched-on items; one charge of each breakable per attempt; and the free armor every run
starts with (GDD §4), whatever the profile, settings or flavor. The shop (`ShopScreen`, the catalog's
items) sells the permanent items tier by tier, among them the armor upgrade (GDD §8: four tiers; hits
and waits in `GameRules`; prices in the catalog, laid against the campaign's economy by R7 and still
DESIGN-TBD pending the owner, `docs/questions/r7.md`), and the breakables (shield, grapple, revive) as
stock. `tools/measure/economy.gd` reads a campaign's credits, payouts and the shop's prices together
(task R7): per level and zone, the credits available, a good run's share of them, the finish payout and
what a death or quit pays, the running wallet of a single clean playthrough, and the first level each
catalog price is in reach of it.

**Approved early-economy revision (October 3, 2026; pre-density earnings snapshot).** The owner's answers in
`docs/USER_REQUESTS.md` supersede the historical R7 early-affordability assumption: City 1 stays
55 seconds, its lower earnings are intentional, and tests change instead of rewards or prices.
After the approved additive 30% floor-gap changes and Zone 2+ playable wall gaps, measured with
`--lanes=5 --seeds=0 --share=0.7` (native campaign seeds, default difficulty, no purchases or boss
payouts), City 1 has **389** available credits, **272** collected and a **372** wallet including
its unchanged 100-credit finish bonus. City 2's wallet is **833**, City 3's **1,495**: Armor I
at 350 still fits City 1; Laser I at 900 first fits City 3, not City 2. Only that affordability
deadline changes; claws still fit Gangland 2, dash and slow time still fit by Gangland 3, and every
catalog price remains attainable within one clean playthrough (**11,877** total).
The isolated duration comparison disables additive floor gaps on in-memory copies only: 110 seconds
earns 556 available credits / 489 wallet, versus 55 seconds' 341 / 339. This historical controlled
comparison is not the current post-gap wallet. Economy tests retain the other affordability,
death-versus-finish and whole-playthrough guards, plus a shortening-driven earnings regression.
The subsequent danger-density overlay can move collectibles around new hazards, so the figures above
are historical rather than freshly measured totals. It changes neither duration nor reward tables,
and its added hazards earn no extra risk-credit pay.

The save has a version (`Profile.VERSION`, now 2). `Profile.from_dict()` brings an older save up to
date as it loads (`_migrate`): version 1's armor stock (armor was a breakable then) is paid back in
earned credits at the 150 each it cost (`V1_ARMOR_PRICE`, the only price it ever had), the purchases
leave `lifetime_spent`, and its old equip toggle goes, so an upgrade bought later starts switched on.
A change to the save's format bumps the version and adds its step there, with a test.

## Platforms and build flavors

`BuildFlavor` (`full_pc`, `full_mobile`, `web_demo`) comes from export feature tags (or
`--flavor=` for testing). `Platform` (autoload) is the only way to reach ads, purchases,
leaderboards, achievements, store links and cloud save; `StubBackend` serves the editor, tests and
the web demo until the real plugins are chosen (risk test R3). The store links are data
(`data/platform/store_links.json`) and open through `Platform.open_store()`, which hands the URL to the
backend's `open_url()`: a portal that restricts outbound links gets a backend of its own, and the stub
records what it opened (`opened_urls`; tests switch `open_links` off so nothing leaves the game).

**The web demo** (GDD §2; task E2) is the "Web (demo)" export preset: the `web_demo` feature tag, the
Compatibility renderer (the web's only one), no thread support (so it needs no cross-origin isolation
headers, as itch.io and the portals serve it), no GDExtension support, and a canvas that follows the
window or a portal's frame (`html/canvas_resize_policy` adaptive). `tools/godot.sh web` exports it
(README, The web demo).
- *What it plays:* the zones marked `in_demo` (the Neon City and its boss); a step past them leads to the
  "get the full game" screen (`App.in_demo_scope()`). No endless mode, and no ads, purchases or
  leaderboards: the platform offers none, and no screen shows any.
- *What it leaves out* (`tools/web/demo_filter.gd`, worked out from the data): the tests, the tools, the
  test boss, and the music it never plays: every audio file in the music library's folders that no track
  the demo plays uses, the files of the tracks it never plays wherever they are, and those tracks'
  level-complete riffs. The tracks it plays are the menus' (`menu`), the City's (`city`, quick play's too)
  and each demo zone's and its boss's (`DemoFilter.demo_tracks()`). `tools/web/update_filter.gd` writes
  the preset's exclude filter from that, `tools/godot.sh web` runs it before every export, and
  `test_web_demo` fails while the preset doesn't match the data. So when a track is replaced (the owner's
  songs, GDD §11: the same file name, or a new file named in `data/audio/music_library.tres`), the filter
  follows the library: a demo track's new file ships, the old file left in its folder doesn't, and another
  zone's new file stays out.
- *A build without some sounds:* `SfxLibrary.has_file()`; `PlayerSfx` readies only the sounds the build
  has, and `MusicDirector.level_complete_sound()` falls back to the E riff when a zone's riff isn't in
  the build. A sound asked for by name whose file is missing still warns.
- *Checks:* `test_web_demo` (the preset, the filter from the data and with replaced tracks, everything the
  demo's scenes, scripts and data reference kept by the filter and loading, the walk from the title to the
  end screen with the sound library as the export has it, no ads, purchases or leaderboards on any screen,
  the store links). `tools/web/check_pack.gd` checks an exported pack from the inside, run by the desktop
  Godot from the pack's folder so `res://` is the pack alone: the demo's music and sounds load, no other
  music is in it, and `tools/web/demo_walk.gd` walks it from the title to the end screen (the City's three
  levels and the Floating Head, with the results and the shop between them, in god mode) with no error or
  warning logged. `tools/web/browser_check.js` drives the release and debug exports in Chromium through
  Playwright (README).
- *In the browser:* `user://` is the page's storage (IndexedDB, under `/userfs/godot/app_userdata/Neon
  Runner/`), written through after each save, so progress survives a reload. Browsers hold sound back until
  the first click, tap or key: Godot creates its AudioContext at start (Chrome notes it's suspended) and
  resumes it on the first input. A phone's browser is a mobile device (`DeviceProfile.is_mobile()`, from the
  engine's `web_android` and `web_ios` tags): 3 lanes, the touch layout and hints. Held upright, the page
  covers the game with "turn your phone sideways" (a style in the preset's `html/head_include`) and
  `App._on_window_resized()` pauses a running level (both DESIGN-TBD, `docs/questions/e2.md`).
- *Touch words:* `DeviceProfile.has_touch()` means a phone, a tablet or a real touch screen. The project lets
  the mouse stand in for touch (`input_devices/pointing/emulate_touch_from_mouse`), which makes
  `DisplayServer.is_touchscreen_available()` true on every desktop and in every desktop browser, so the
  hints go by `has_touch()` and name the keys there.

## Tests

`tools/godot.sh test` runs every `tests/suites/test_*.gd` (a `TestSuite`); `--suite=<name>` runs
one; `--jobs=N` (T-SPEED) splits them across N Godot processes instead, balanced by each suite's
last measured time (`tests/.suite_times.json`, refreshed by every run and git-ignored), each with its
own `user://` folder so their saves never collide; use it on a machine with CPUs to spare, since the
default (one process) is unchanged. `LayoutCache` (`tests/helpers/layout_cache.gd`, T-SPEED) shares
one real build of a level across every suite in a run: `LevelGenerator.generate()` is a pure function
of (config, tuning, patterns), so the many suites that independently build the same level -- often a
campaign step's own default build (3/5/6 lanes, its own seed), which several suites generate just to
run their own checks on it -- ask the cache instead of the generator. `generate()` always hands back a
fresh `LevelLayout.copy()`, and `generator()` a `LevelGenerator.for_layout` stand-in with the real
build's `attempts`/`warnings`/`picks`/`fills` restored, for a caller that reads those or calls one of
the generator's pure, read-only queries (`feature_start`, `quiet_at`, `difficulty_at`,
`placeable_features`, ...) -- never a method that places something, or `pick_weights` (it needs
generation-only state, such as `_due`/`_intro_burst`, the stand-in never had set up); its own doc
comment lists exactly which. A suite's own "does regenerating give the same layout" check keeps its
second, independent build real and uncached, so the cache can never make such a check trivially pass;
`test_layout_cache.gd` checks the cache itself (identity with a fresh build, sharing across separately
`duplicate()`d configs with the same content, never conflating a real difference, independent copies,
the `generator()` stand-in's queries), and `--no-layout-cache` (read by `tests/run_tests.gd`) turns it
off for a suite that must prove its checks still pass without it. `RunSim` (`tests/helpers/run_sim.gd`) runs a Player over a hand-built layout (`run()`), or a
full RunWorld (`build_world()` + `step_world()`); with `trace` on it records the player after every
physics frame (position, height, speed, surface, lane, lean). `SkinSuite` (`tests/helpers/skin_suite.gd`) holds
the checks every zone skin must pass, and helpers to inspect what a skin builds over a whole level
(`visit_level()`, `rects_of()`, `under_hazard()`). Its chunk build-time budgets (`whole_level()`,
`BUILD_BUDGET_MEAN_MS`/`BUILD_BUDGET_MAX_MS`) time the dressed build over `build_all()`'s
`timing_passes` (`BUILD_TIMING_PASSES`, 3) fresh builds and keep, per build step, the fastest seen:
OS preemption on a loaded machine only ever adds wall-clock time to one pass, never removes it, so
the minimum stays a faithful reading of the skin's real cost even when a single pass gets paused
mid-build. That alone doesn't help when *every* pass is slow -- several agents' test runs and
renders sharing the CPUs at once (T-BUDGET2) -- so each timed pass also drives a reference
`TrackBuilder`, in `GreyboxSkin` over a plain `REFERENCE_LANES`-lane layout as long as the one under
test, one chunk-step at a time right alongside the skin's own (same process, same moment, the whole
build through, not a snapshot at its edges). `load_factor()` reads that reference's own inflation
over its quiet-machine baseline (`REFERENCE_IDLE_MS`) and scales the budget by it, each direction
with its own safety margin and cap on how far a single pathological moment may widen it
(`MEAN_SAFETY_MARGIN`/`MEAN_FACTOR_CAP` for the mean budget, `MAX_SAFETY_MARGIN`/`MAX_FACTOR_CAP`,
wider, for the max budget, which a single loaded chunk can spike well past the mean's own inflation);
at load factor 1.0 (an unloaded machine) neither margin nor cap changes anything, so a real
regression still fails exactly as before. `test_skin_budget` (with the test-only `SlowTestSkin`,
`tests/helpers/slow_test_skin.gd`, which busy-waits a few real milliseconds per lane, a cost that
grows with load more slowly than a real skin's own) checks that check still fails a skin that really
is expensive, at whatever load this run measures, including the heaviest load the mean cap still lets
through. `LayoutChecks` (`tests/helpers/layout_checks.gd`) holds the
fairness checks for generated layouts (the generator suite runs them over many seeds, the campaign
suite over every campaign level at 3, 5 and 6 lanes, the enemy suites over their own levels), among
them `check_ceilings` (GDD §3: pads that can be stepped on and under their ceiling, safe landing zones
over each ceiling's lanes, a one-lane ceiling short, and a floor route under every ceiling without its
pad, found by `FloorRoute`, `tests/helpers/floor_route.gd`, which keeps out of a zone doodad's lane where
it stands) and `check_doodads` (G5: every doodad in an inner lane, one at a time, with nothing else in
any lane from its push to the spacing after it and off every lane-bound attack), and finds a
feature's pieces in a layout with the generator's own `LevelGenerator.feature_positions()`; a task
that adds a new kind of piece extends it (and `FloorRoute`'s cells, if the piece is on the floor), or
gives its rules script `positions()`. The generator suite also checks the recency curve's pick weights
exactly (`pick_weights()`: each kind's share, the caps) and levels paced in bursts; the campaign suite
checks each kind's share at spots all through every campaign level, The Hush and the darker lighting
on every skin. `test_enemy_director` checks the turn-taking between big attacks
with scripted test enemies (`tests/helpers/turn_dummy.gd`: the queue's order, a place kept through a gap
in the asks and through the turn, give-ups and the grace), a real Octodog that another type's repeated
attacks used to keep from its turn, and simulated runs of campaign levels,
watched by `tools/measure/attack_watch.gd` (see Review tools). `DummyBoss` (`tests/helpers/dummy_boss.gd`) is a boss
for framework tests, with `make_def()` for a BossDef from a list of phases; `test_bosses` runs fights
in bare worlds and, with the test boss in the City's slot, through the App (at the City's speed there,
in quick play at the base speed; and an arena planned at 25 m/s keeps its laps' seconds). `test_pickups` checks
pickup placement against the rules as it writes them itself, over hand-built cases and generated
tracks at 3, 5 and 6 lanes, and the armor rule end to end on the test boss. `test_armor` covers the
free armor and its upgrade (G3): the state's rules, its wait at any frame rate and not while paused,
each tier's numbers alternating as GDD §8 says, a run's block, revive and pickups, the HUD, the shop
line and texts, the save migration, and every kind of run through the App (the web demo's too).
`test_theft` covers the robbed hit (B6; GDD §9.12): a thief's touch resolving to `ROBBED` over every
combination of protections (never hurt, nothing used up; caught by the dash, a stomp, the claws), every
other hazard resolving exactly as before (a copy of the rules before B6, over every hazard kind, enemy
part and flag), the player's theft window, the books (25% of what the run holds, rounded down, held;
a second thief; the payout with the jackpot; credits held off the track and the best score), the pay
(a death after a theft, completion, a boss fight), stars equal to a clean run's, the results' "Stolen",
the HUD (the count down in the loss colour, its fade, the pop-ups, never the death message), the coin
streams, the sounds, Reduced flashing, and the stand-in on real physics at 3, 5 and 6 lanes (robbing a
runner who keeps to its lane once, missing one who moves aside, caught by a stomp, the dash, the claws
and a weapon, the same every attempt) and quick play's `--thief`.
The Floating Head's suites fight at the City's speed, 21 m/s, as the campaign plays it (E1f:
`FloatingHeadBot.campaign_tuning`), and recheck its fairness with its margins at that pace.
`test_floating_head`
runs the Floating Head's fight in bare worlds at 3, 5 and 6 lanes with a runner who dodges each lock
(and one who doesn't), rechecks its bombs' fairness from the arena's layout, and checks the campaign's
fight runs at the City's speed (a harder tier's faster);
`test_floating_head_faceoff` plays its face-off with `FloatingHeadBot` (every laser warned and
escaped without god mode, the cyborg drop, a baited and a fallback tower pinning it) and rechecks
each attack's fairness from the real arena's layout; `test_floating_head_stomps` has the bot take each
phase's stomp window at 3, 5 and 6 lanes without god mode, checks the ways up are physical, missed
windows repeat without escalation, the damage and weapon cap, the armor pickups, the window's ceiling
rules, and plays the whole fight from its entrance to the last stomp; `test_floating_head_routes` (E1e,
the owner's playtest) sweeps lane switches alongside the ramp (each boards it or bumps, never into it),
boards it late in the fight, checks the wall marks and a single wall jump off them from either wall
(at 5 and 6 lanes too), the ceiling from a pad in any lane, the ways' first-time hints and armor for a
runner who brings none, and plays the campaign's boss step end to end at 3, 5 and 6 lanes with a death
and a retry; `test_floating_head_defeat`
checks its defeat (after the last stomp at 3, 5 and 6 lanes and by weapons in the air: the
propaganda cut, the glitch, the fall, the wreck with room for a runner in every lane, the run through
it without god mode, Reduced flashing, the same every attempt) and plays the whole fight through the
campaign at 3, 5 and 6 lanes with the bot and no god mode (City 3, the boss intro's slot, the fight,
its results and stars, the shop, the outro's slot, and the web demo's end screen), checking along the
way that its propaganda never masks a warning, then that a death restarts the fight. `test_sleep_taker`
builds the Sleep Taker at 3, 5 and 6 lanes (its slot, immune to weapons, its hitboxes, its draw budget
and colours, its arena's refuges, the entrance, shots and missiles passing through it, lights out
darkening the scenery and the light always coming back); `test_sleep_taker_attacks` plays its slash and
hands with `SleepTakerBot` at 18 and 24.2 m/s (struck only after the warning and only in the warned
lanes, every escape from every lane without god mode, the ceiling safe, the same every attempt) and its
whole pattern on the real arena at 3, 5 and 6 lanes for a runner who lets every generator go by;
`test_sleep_taker_fight` plays the whole fight with the bot at 3, 5 and 6 lanes and both speeds (three
EMPs in 60-120 s, every lure on time with the arcs showing it's in reach well before the stomp, nothing
attacking while lured, the chunks torn, the same every attempt), a missed generator followed by another
with nothing escalating, EMPs out of reach, the defeat (the wisps, the silence, the dawn, the lights back
after), and the campaign's flow at every lane count (the Dead Zone's last level, a death in the fight's
second phase, the retry won with three stars, the shop, the outro). `test_the_house` builds The House at
3, 5 and 6 lanes (its slot, built, with its data and par times, its plain arena, its size under the
street's cables, its squat under a ceiling and its draw budget, a cabinet that doesn't glow, its reels and
their defeat's wild spin and jam, TILT steady with Reduced flashing, how symbols become attacks, the
phases' special buttons, the route solver's rows, walls, fences, slaloms, buttons and holds, and phase 3's
ceiling within C1's limits for every pad lane); `test_the_house_attacks` plays every attack at every size with
`TheHouseBot` at 3, 5 and 6 lanes and 18 and 22.6 m/s (each strike's warning on the track where it then
hits and nothing hitting anywhere else, the bigger versions, the 3-lane mix of bombs and blocks always
leaving a way, the citizens ducking, every phase's spins survived over a few seeds without god mode);
`test_the_house_fight` plays its buttons and jackpot at every lane count and both speeds (buttons in
plain view and in lanes of their own, locking their reels; the sirens, the fountain's real credits, the
hopper open well ahead of the runner as the machine sinks; the stomp's big hit and its recovery), a
missed button, a missed set and a missed hopper (it just spins again, nothing escalating), weapons up to
their cap, the same fight every attempt, and phase 1 won in quick play at every lane count and both
speeds, then a death and the retry won through all three phases (floor, wall and ceiling buttons pressed,
inside its three-star par); `test_the_house_phases` plays phase 2 (wall fences pulsing along both walls,
the wall button lit in plain view and run over along the wall with every wall fence passed off, the
attacks waiting, strikes off the drop windows) and phase 3 (the billboard over every lane with its pad,
the machine squatting under it, one or two turrets firing, the ceiling button run over, the bolts
dodged, the rider dropping back onto clear floor) and the defeat (the wild spin, the jam, TILT, the
collapse in coins ahead of the runner, the citizens cheering) at 3, 5 and 6 lanes and both speeds, and
the campaign's flow at 22.6 m/s at every lane count (Marketplace 2, a death in the fight's second phase,
the retry won with three stars, the shop, the outro). `test_hostile_takeover` builds Hostile Takeover's
train (E5b) at 3, 5 and 6 lanes and 18 and 23.4 m/s (its slot in the campaign after Corporate 2, par times,
sounds and hints; the laps holding the train
alone, every gap across every lane, a share of a jump, the carriages in their consist, routed and jumped
from every lane with the real jump; the couplings' stomp box and take-off window at the run's pace, a fall
never high enough to stomp; the Board's coupling lanes, guards clear of the gaps, of each coupling's run-up
and landing and of each other, a way through everywhere, Tithe Collectors alone on the flatcars and capped
a phase, partial wall fences keeping a level's rules; phase 2's plan: each drop's cut the C2 tank's own and
keeping a level's rules for cuts, checked independently, the runway longer than any leap in every lane, the
armored carriage out of a jump's reach both ways, the belly over the runner to past it, the strafes' free
lane; phase 3's plan: no drop before the docking is over, each drop's cut a level's, each pass's runway on
the carriage after the flatcar, the belly over the runner until its stern passes them, the same seconds at
every speed, the landing clear of the gaps, the three clamps one under each third with a lane under each,
a jump from anywhere on a clamp's cue landing on it, time after boarding and after each stomp's bounce for a
reaction and two lane moves, the Board back only on its slots; its models' budgets and colours, the
breakaway on the train's material, phase 3's parts built with the fight and hidden, MERGER COMPLETE and the
clamps' pulse steady with Reduced flashing, nothing made while the city streams past or from the docking to
the defeat); `test_hostile_takeover_fight` plays the whole fight with `HostileTakeoverBot` and no god mode
at every lane count and both speeds (the entrance, the dark opening gaps, each coupling lit in plain view in
a lane of its own with its cue and hint, the stomp's big hit and the carriages breaking away; phase 1
standing down, each strafe warned and raking only its warned lanes after the warning, the drop and its
tank's rev before its charge, the armored carriage in sight, the ride and the drop bay stomped; the
docking, MERGER COMPLETE with its sounds and hint, phase 3's strafes and drops warned, the pass and the three
clamps stomped from lanes under them, each live only while ridden under; the defeat: the lobby ahead, the
gunship climbing away spinning and exploding, the locomotive ploughing into the lobby, the sculpture down,
the screens dark, each on time with its sound), a stomp from the lane beside the coupling's, a coupling
sailed over from its own lane and two let go by (each harmless, the next one coming), a run off the edge (a
fall, no stomp), the Tithe Collector skimming its trail, a runner hit in a strafe's lane only once its
warning is over, the dropped tank's rules with the armor (its blade blocked, the floor held), the armored
carriage impassable without its runway, a drop bay let go by and the next cycle's stomped, a pass let go by
and clamps left in a pass coming around in the next, weapons poured on never ending a phase and never
saving a clamp, the armor rule (a break, no armor, the final phase), the whole fight the same on every
attempt, quick play at two setups (phases 1 and 2 won, a death once docked, the retry won whole, and quick
play starting over after the defeat), and the campaign at 23.4 m/s at every lane count (Corporate 2, a
death in the fight's last phase, the retry won with three stars, the shop, the outro);
`tools/measure/hostile_takeover.gd` plays every lane count and speed.
`test_sewer_swarm` builds the Sewer Swarm (E4) at 3, 5
and 6 lanes and 18 and 21.8 m/s: its slot (built, the campaign's step plays it; phase 1 two clusters, phase 2
the rest, phase 3 three hits; its par times; weapons within its cap; its new sounds and hints), its
crowd sizes in data and smaller on a low-end device, the screech's crowd mesh, its clusters (simulated
entities with one hitbox each, their crowds one MultiMesh each with no collision and no node per creature, all
made before the fight and none after a whole phase of surges), the horde and its lairs, its draw count, its
MultiMeshes' white instance colours (the Compatibility renderer), its arena's every bait spot (a live full fence or a hole in one lane, the street around it clear, in reach from any
lane before the lock, a way out of every lane, met by a baited cluster ahead of the runner) and the stress scene;
`test_sewer_swarm_fight` plays phase 1 with `SewerSwarmBot` without god mode or armor: won by baiting at every
lane count and both speeds, the same every attempt, every surge warned (line and chitter) warning_seconds before
its hit and its hitbox live only from the lock, a fence and a hole baited by a runner who switches out and by
one who jumps (the line locked from the bait, never on toward the runner), a hit only through the hitbox (an
enemy attack armor blocks, once) and never beside it, a way out of every surge from every lane, no bait: no end
and no escalation, weapons thinning only a surging cluster with the heavy missile's swarm bonus (and a cluster
thinned to nothing counting), the armor rule with and without armor, the same fight at 30 and 400 screeches a
cluster, and a death then a retry won at 21.8 m/s (6 lanes) and through quick play's own restart (3 lanes).
`test_sewer_swarm_surrounded` plays phase 2 from its start: won by baiting at every lane count and both
speeds (from behind and from ahead), every strike from behind warned (the wave risen over the locked lane,
its chitter, the line) `behind_warning_seconds` before its crash and its hitbox live only from it, a way out
of it from every lane at both speeds, strikes from behind baited into a fence and a hole ahead, the climb
(one wall at a time, alternating, timed, the climbed wall refusing entry and the other taking the runner,
never the runner's wall), simultaneous damaging front/rear surges in distinct lanes, and no bait: no end.
`test_sewer_swarm_walls` checks natural colors, visible wall contact damage and repulsion with armor,
shield and grace, phase-3 local route clearance, and death/retry behavior.
`test_sewer_swarm_host` plays phase 3: its entrance, six
stomps from the ramp and a wall jump at every lane count and both speeds, its lunge baited into a fence, its
crouch solid, its defeat, and weapons within the cap. `test_sewer_swarm_whole` plays the whole fight: won at
every lane count and both speeds with no crowd made mid-fight, the same every attempt, its par times (a clean
win three stars, one with a chance let go by in each phase two), a death in Surrounded and the retry won,
and the campaign at every lane count (Gangland 3, a death, the retry, the win, stars, shop and the outro).
`test_resonator` plays the
Resonator in full worlds on real physics (the warning always before the wave, a jump clearing it at 3,
5 and 6 lanes with its margin measured, walls and the ceiling safe, armor, shield and dash, turns with a
`TurnDummy`, a first pulse that waiting for clear floor never starves (FIX4), Reduced flashing), checks
its rules over many seeds, and plays the real Golden 1-3 layouts
at 3, 5 and 6 lanes, watched by `attack_watch.gd`: no wave meets the runner on a gap or a fence, and no
big attacks overlap. `test_barnacle_turret` covers the Barnacle Turret (C1): its numbers against the
cyborg's and GDD §8's 7 laser tier 1 shots, hitboxes out of reach of anyone off its ceiling, both looks
(no hazard glow but the charging muzzle), placement over every campaign level and narrow-ceiling sweeps
(`LayoutChecks.check_turrets`, which `check_rules` runs on every generated level), a level unchanged
without it, and on real physics: popping out, firing only at a rider on its own ceiling after its
charge-up, dodging, two-lane ceilings at 3, 5 and 6 lanes with one turret and two, contact (armor, shield,
claws, dash, a stomp from the ceiling), 7 laser tier 1 shots, armor and the shield against its bolts,
determinism, and generated levels ridden through with every burst checked. `test_gilded_sentinel` plays
the Gilded Sentinels (C4) in full worlds on real physics at 18 and 25 m/s: the warning always first, for
its whole time; wall runners stepping on right before it (cut), jumping on (above) and stepping on early
(below) on both walls; floor runners in and out of the outer lane at 3, 5 and 6 lanes, jumping and
sliding; armor, the shield and the dash; its solid body back in its niche; 17 laser tier 1 shots through
the real weapon; the kick; twice and pairs; turns with a `TurnDummy` (its claim holds another back, and it
lets the runner pass when one begun before is on); Reduced flashing; the same every attempt. It also checks its look (one shared mesh, the eyes' own
material, the statue inside its niche), the Golden skins opening the niche, decorative statues on
recessed wall-base mounts, its placement rules on hand-built layouts at 3, 5 and 6 lanes, the wall fences keeping off
it, and Golden 2 and the Palace's real layouts (its rules, `LayoutChecks.check_layout`, the introduction,
the same build twice). `test_ceilings` covers narrow
ceilings (B3) from the layout to the screen: the
sections and collision boxes the track builds for each range at 3, 5 and 6 lanes, moves on a ceiling
(within it, and blocked at its edges with the bump and the clank's event, on real physics), a pad
holding the player to its lane, a one-lane ceiling ridden and dropped from, the camera kept under a
ceiling and past its end, and every skin's ceilings (see Zone skins). `test_audio` checks
the music files (seamless loops, lengths, tempos, size budgets), the Music autoload's fades, duck and
death dip on its players' levels and the bus's low-pass (headless runs never start a player), and the
run's music hooks through the App. `test_cinematics` checks the cinematic toolkit: its paths (smooth,
eased and cut moves, cameras riding with an actor), a timeline's `problems()`, a cinematic played to its end
(events in order, `finished` once, actors on their paths, the camera riding along), `skip()` and the pause
action and the Skip button, Reduced flashing, holding in the background, the sampler (a cinematic described
in data), every zone's arrival flyover and the City's boss intro at 3, 5 and 6 lanes (the zone's skin from
its data, the level's lanes, a camera that never flies into a ceiling or out of the street, a runner that
never runs over a hole, ending in the run camera's view), and the App's flow through a built slot (the
next step follows, skipping, the web demo). `test_city_outro` checks the City outro (F2a): at 3, 5 and 6
lanes its beats in order (the crash into the wreck, the camera at the runner's level, the look left, the pan
onto the roadblock, the startle, the leap out of the right wall's opening with the blast behind, the cut to
the next zone and the landing), a camera that only leaves the street through an opening, only the City's
music, its setup, cut and step costs and its props' draw calls; Reduced flashing; `skip()` at any moment;
the landing following the next zone's skin; and the App's flow (Gangland's intro follows; the web demo plays
it, then its end screen). `test_pace` checks the pace and busier levels (G1): the zones' speeds in data and each campaign level at
its zone's speed (and each boss fight, E1f; quick play's at the base), `movement_for`, a pattern's timing in seconds at 18 and 25
m/s, the generator's fairness at 21, 23.4 and 25 m/s at 3, 5 and 6 lanes with every built feature and
the fill pass (`LayoutChecks` checks each level at its own speed: `level_tuning()`), the fill pass's
rules on campaign levels, the Octodog's and Resonator's windows in seconds, a cyborg and a screech on
real physics at 25 m/s (the charge-up, the bolt's flight, the dodge; the shake), floor routes under a
Golden level's ceilings run on physics at 25 m/s, and F6's Save keeping the base run speed.
`test_doodads` checks zone doodads (G5; GDD §3): a level without them is the same data as before and a
share of 0 changes nothing (every piece, enemy, pick and fill stays with a share; only credits inside a
doodad go; City 1's extra gaps, which FIX4 may send elsewhere around a doodad, keep its own gaps and their
count, task G7), placement over 216 levels at 3, 5 and 6 lanes (every difficulty, with and without every
built feature, at the highest share: `check_doodads`, `check_layout` and `check_rules`, deterministic),
every campaign level's doodads and City 1's gentle start, the rules' keep-outs (a Bad Dream's chase, a
hover truck's lane) and the enemies' own checks, the track's bodies (never a hazard, a standable top,
the skin's hook) and every skin's default look (inside its box, never glowing, muted colours); then the
push on real physics at 3, 5 and 6 lanes (head-on into the lane on its side in every inner lane, both
ways, quick, with the lean, costing nothing, the body never sinking in; a jump and a slide into one; a
corner caught mid-switch pushing back the way the player came; a blocked side entry with the clank and
the bump; landing on its top; a ceiling rider passing over it even mid-jump; a shot passing through it),
a few of every campaign level's doodads run into at the level's speed and onto safe floor, and a drone
and a hover truck holding their fire while a doodad is in reach. The simulated runs of
`test_enemy_director` and `tools/measure/big_attacks.gd` keep their runner in the middle lane: it steps
back after a doodad's push (`AttackWatch.keep_lane`).
`test_floor_cuts` checks floor cuts (B4; GDD §9.9) with the grey-box stand-in: the plan's geometry and
the layout data; the track's piece (its slices, its collision, a hold and a stop); on real
physics at 3, 5 and 6 lanes, the floor gone exactly behind the cause and whole ahead of it, a runner in
the lane falling frame for frame as into a normal gap, one who reacts to the warning leaving in time
from middle and outer lanes, one who stays hit by the cause, a wall runner and a ceiling rider
untouched; the floor holding for `cut_hold_seconds` after an armor or shield block (staying falls once
it's over, switching lanes or jumping inside it is safe); a kill stopping the cut where it dies (mid-
charge, during the warning, by the dash); the same cut at 30 and 60 physics frames a second, through
pauses and uneven steps; a cut added during a boss fight (`arena.cut_problem`, `add_pieces`) and on a
track extended during play; every skin's look and build cost (Zone skins, Floor cuts' looks); the
stand-in's warning (a red line from the warning point, never before, and a sound; the line steady with
Reduced flashing); and that the stand-in stays out of the campaign. `test_generator` sweeps the stand-in's cuts over seeds,
difficulties and lane counts, under narrow ceilings and in busy levels with every built feature
(`LayoutChecks.check_cuts`), checks each of GDD §9.9's limits by hand and `CutPlacement`'s clearing, and
shows a level whose rules plan no cut is the same data as one without them.
`test_buzz_overdrive` checks the Buzz Overdrive (C2; GDD §9.9): its numbers (health 20 everywhere, a rev
a little shorter level by level, its warning and charge in seconds at every zone's speed), its look
(every variant within an enemy's budget, only hazard colours glowing), its plan, every campaign level
that lists it at 3, 5 and 6 lanes (each tank with its cut, the same every build, Corporate 1's
introduction soon after its start; it prints the counts) and quick play with every built feature;
then on real physics at 3, 5 and 6 lanes and every zone's speed: the warning (line and sound) before
the charge and only its own lane cut, a runner who leaves at the warning never touched, one who stays
hit, wall and ceiling riders beside it safe, a block holding the floor for about a second (staying falls,
a lane switch escapes), kills while it rolls, revs and charges (the floor saved, the cut stopped), the
shots each weapon tier needs and when it stops it (laser tier 1 never before it meets the runner, the
missile tiers before it charges), the claws doing nothing, the dash smashing it, no stomp, the same
encounter on every attempt and at 30 and 60 Hz, and its rev and charge as a big attack; its sparks only
while it cuts, none and a line that only widens with Reduced flashing. Its turns (task FIX2): its claim
before its rev (another type's attack that gets ready then waits until it's gone, and it revs), its pass
(with one begun before its claim still on: no rev, no line, its lane whole, out of view ahead), none of
it with the switch off or for a boss's tank (no roll), and Dead Zone 1's original overlap rebuilt with a
real hover truck ready to lurch 0.85 s before its rev (0.62 s for a tank that takes no turns; now the
truck waits and nothing overlaps). `test_enemy_director`'s campaign runs hold Dead Zone 1 at 5 lanes to
no overlap at all.
`test_enforcer_truck` checks the Enforcer Truck (C6; GDD §9.13) off the road: its numbers (the owner's 0.8 s,
25 s, 3 riders, 2 a level; its close gap inside an Octodog's lunge at every zone's pace; its follow gap behind
the camera; a shot's bolts over a slide and a whole jump; each rider quickening it), its look in every zone's
variant (within budget, only its lights and its riders' faces glowing, the blue no safe cyan, flat additive
floor lights) and, at its close gap at every zone's pace, every vertex of it under the camera's line of sight
to the runner's feet; the core hooks (a charge's contact destroys it as the player's kill with the riders'
bonus; weapons, splash, targeting and health bars never touch it; DamageRules never lets a stomp, the claws or
the dash defeat it; hosts and generators still pass charges by and a charge's other victims earn nothing; an
Octodog's moved-on charges ignore its entry); showing itself (C6b: its numbers; beside the runner at 3, 5 and 6
lanes in every look, all of it on screen in the run camera's view and nothing of the runner or their side behind
it, two lanes in from a runner by a wall (C6c); `EnforcerTruckRoom.can_dodge` never leaving the only free lane,
both ways two lanes in); its showing windows (C6c: on every level that lists it at 3, 5 and 6 lanes, own seed and
another, each planned window lies in its chase and holds in the finished level, `ShowPlanner.problem_of`, with no
zone doodad, filler, wider gap, danger density row or enemy, or planted cyborg in it; Corporate 2 at 3 lanes plans
its first truck's arrival showing; the windows each level gets are printed); the chases with room (C6d: on a plain
track with two Octodogs, one truck a level goes to the bait whose chase has room for its showing before it, the
introduction too, and stays at the first where that has room, and two a level take both; on every level that lists
it at 3, 5 and 6 lanes, own seed and two others, every truck, moved or arriving earlier, keeps its placement rules,
and a truck without a window before its bait has no free bait with one that its level could give it beside its other
truck, nor a level with fewer trucks than it may have; Corporate 2 always introduces it; the chases' windows before
and after the bait are printed); its blast (seen wherever it goes off, never
in front of the runner, no core and a softer fire with Reduced flashing, its fading materials the warmed ones'
shaders); every campaign level that lists it at 3, 5 and 6 lanes (own seed
and others: the placement rules, baits in every chase, Corporate 2 always with one, the same every build; it
prints the counts), the same level without it but for its trucks (its windows not planned), quick play without a
bait having none; its
marker, light bar and Reduced flashing; its warm-up look (its blast's too); and its data. `test_enforcer_truck_runs` plays it on
real physics at 3, 5 and 6 lanes and at 18 and 23.4 m/s, with a scripted runner (no armor) that steps aside
a reaction after each warning: its lane delay to the frame and its gap; a runner who stays hit by its laser,
never before the warning and a bolt's flight; a whole chase escaped, the line exactly while a volley is on,
the interval, giving up after 25 s and leaving play; turns with a scripted big attack both ways; an Octodog's
lunge and a Buzz Overdrive's charge dodged late destroying it (the player's kill and the riders' bonus) and
dodged early missing it, no volley during either though one was due, big attacks taking turns or not; a too-
wide gap and a cut (the tank shot down mid-charge) wrecking it, an ordinary gap hopped; riders from passed
cyborgs in its lane only (not another lane, a killed one, a window cyborg or a host), at most 3, quickening its
volleys; the same run twice; each way it's destroyed ending in its blast a lurch later, with its sound, seen by the
run camera and never in front of the runner, its wreck never rising into the camera it passes under (C6b); its showings (C6b; the other runs play without them): on
arrival and mid-chase for `show_seconds`, its whole look on screen, back to its follow gap and the runner's lane,
never firing meanwhile, its siren swelling, a lane change into it bumped back unhurt and it giving way, never the
only free lane (zone doodads at 3, 5 and 6 lanes), two lanes in from a runner by a wall (C6c), turns both ways, a
bait close behind its arrival keeping it back and a later one shortening its stay, its baits still destroying it, a
planned window bringing its showing (C6c: its claim holding another type's attack back, no volley meanwhile), the
same every attempt; and Corporate 2 at 3, 5 and 6 lanes played to its end by a runner that baits each
truck (god mode, grapples): each destroyed by a charge it dodged or in a wider gap (task G7), no overlap with
its volleys, never firing while it shows itself, each truck whose window comes before its first bait coming
alongside (the showings it makes are printed).

`test_wide_gaps` checks the wider gaps (task G7; The generator, Wider gaps): every campaign level at 3, 5 and 6
lanes with its 2 (LayoutChecks.check_wide_gaps: the length, the spacing, nothing in any lane from the take-off
margin to the landing margin, no zone doodad or its push's lead there, no side wall gap beside) and a floor
route across each (FloorRoute from the clear floor before it), printing each level's rows, holes and where its
wider gaps came from; none in a boss arena even asked, nor in quick play or the prototype level; Corporate 2 the
same on every attempt; every filler at the fill pass's spacing from every wider gap (three builds on other seeds
where a filler had to go for a longer row); on real physics at quick play's speed and every campaign level's, at 3, 5 and 6 lanes, a
jump early, midway and late in the take-off window clears one and running on falls in; an Enforcer Truck
following a runner who jumps one wrecked in it (the player's kill) and hopping a 0.5-of-a-jump row, at 3, 5 and
6 lanes, at 18 and 23.4 m/s; and Corporate 2's own build at 3, 5 and 6 lanes played from its start (god mode,
grapples) until the runner leads its first truck over the wider gap in its chase, where it's wrecked.
`test_charge_paths` checks the cyborgs in charge paths (task G7; The generator, Cyborgs in charge paths): every
campaign level's count and LayoutChecks.check_charge_paths at 3, 5 and 6 lanes (a plain floor cyborg, never a
host; its charger's planned path through it, in view, holding its fire, nothing around it), one before
Corporate 2's first Enforcer at each lane count, printing what each level got; nothing planted in quick play,
the prototype level or a boss arena (even asked); Golden 2 the same on every attempt; hand-built encounters
planned by the placement itself on real physics at 3, 5 and 6 lanes, at quick play's speed and Corporate 2's (an
Octodog in an outer lane and the middle one, a parked Buzz Overdrive in an outer lane and the middle one): the
cyborg flattened by the charge (never the player's kill) with the runner in_view_seconds behind it, no burst
charged and no bolt landing in its hold_fire stretch, a runner who leaves the far lane (the cut's lane) after
the warning untouched and one who stays hit; and in the campaign's own builds, played from the start, the first
planted Octodog encounter and the earliest Buzz Overdrive one at each lane count flattening their cyborgs.

`test_wall_fences` checks wall fences (B5; GDD §9.1): the layout data (left out of a level without them) and
`WallFencePlan`'s bands, reach (a floor runner in the middle of the outer lane never touches one, a wall runner
in its band does, at 3, 5 and 6 lanes) and state on the level clock (never off to on without the warning); the
track's hazard (WallFencePlan's hitbox, electrical, never a wall blocker, the crackle, following `state_at`
frame by frame, and picking up the level clock when built late); on real physics at 3, 5 and 6 lanes, a wall
runner hit while one is on and safe while it's off, a floor runner beside a live one never touched, stepping
onto the wall into a live one a hit, jumping off before one passing it, a low one passed by jumping onto the
wall and a high one by stepping on (and each hit the other way), a runner who jumps off 0.2 s after the warning
starts never hit wherever they are then (one who stays is hit at some phases), armor, the shield and the dash
through and claws not, the weapon finding nothing to shoot at, and an EMP switching them off, built or not;
every campaign level with them (own seed and others, 3, 5 and 6 lanes) placing them fairly
(`LayoutChecks.check_wall_fences`), keeping both kinds, the same on every attempt; Marketplace 2's and Corporate
1's introductions (first of their kind, alone, off long, within `intro_seconds` on the levels' own seeds and on
most others, mostly where no enemy is about); Marketplace 2 at 18 and 25 m/s (the margins in seconds); every
campaign level exactly the same without the features but for its wall fences (pattern picks, fillers and
guarantee builds too), and the levels without them having none; quick play with them among every rule's pieces
(`LayoutChecks.check_layout`); `wall_fence_problem` naming each rule; the hints; every skin's look; and a boss
arena carrying them.
`test_perf` checks what keeps frames smooth (task PERF1; A run, Smooth frames) and that none of it changes the
game: a chunk's dressing spread over frames (the same gameplay nodes in each chunk's frame, the same look once
dressed, every chunk dressed before the player is `DRESS_BY` from it, a chunk freed undressed skipped without
errors, and a seeded run on Gangland 2 with its enemies giving the same trace, events and enemy log at budgets of
0, 1 µs and 1 ms), enemy types readied with the level (every hooked kind and a host's Bad Dream, scripts loaded,
nothing left in the tree or heard, once a process, `warm_looks()`), hit-stops that never stack or chain, BossProps'
shared rings, the shader warm-up stage (the cyborgs' looks, fences in every state, particles as particles, the
run's hidden looks, nothing colliding, lit or top-level), the frame monitor's tags (chunks, a spawn, a kill and
its hit-stop, the held frames) and summaries, and the frame graph's spikes and holds. `test_frame_times` plays
City 3, Marketplace 2 and Golden 2 for 40 s each as the game does (`frame_times.gd --child`, two passes, each in
a fresh process, each frame's faster time) and holds their 99th percentile and worst frame to
`PerformanceTuning`'s test budgets, scaled by load the way the skin suites' chunk budgets are: each pass times
`SkinSuite`'s reference build every 60 frames alongside the run (`--reference`, far off to one side, left out of
the frames), and `SkinSuite.load_factor()` widens the budgets by how slow the machine is right then. Unlike the
skin suites, it pools the passes' reference readings instead of folding them to their per-index minimum (FIX3):
the reference only samples ~40 times in the 40 s a frame-time pass plays (against the frames' own 2400), so
folding two such sparse passes needed both slow at the same one-in-forty moment to register, which a busy
machine's bursty load cleared far less often than it cleared the frames' own tail statistic (p99 needs only 1%
of 2400 chances) -- read as load factor 1.00x on a machine other agents' test runs kept busy, while the level's
own p99 and worst frame were plainly slower, failing under real `--jobs` load that a true reading would have
covered.
`test_web_demo` checks the web demo's preset, its export filter against
the data and everything the demo references, and walks the demo from the title to its end screen (see
Platforms and build flavors). The runner frees
anything a suite leaves in the tree, gives suites a fresh, unsaved profile, reports a suite that fails
to load, and ends a stuck run after 2400 s of real time.

## Review tools

`tools/godot.sh smoke --level=<zone>/<n>` (or `--boss=<id>`) runs the real main scene through
`tools/smoke/smoke_play.gd` (a SceneTree script), not the plain game: a campaign run waits at its level
introduction until PLAY is pressed (`App.begin_run`), and the script presses it after two frames, as
`tools/measure/frame_times.gd` does, then lets the level play for 2400 frames. It prints only problems
(a run that never started, never left the introduction, or whose runner never moved; plus Godot's own
script errors) and exits 1 on any. `--smoke-report` also prints what the run did, `--smoke-frames=N` shortens
it, `--smoke-hold` withholds PLAY (the check's own test, `test_smoke_play`). Quick play (`smoke` with no
arguments) is unchanged. The script cannot name `LevelRun` (compiling it before the autoloads exist fails),
so it finds the run's `State.READY` through the script's constant map.

Scenes in `tools/showcase/` show one part of the game up close for visual review (not part of the
game): the avatar (`avatar_showcase`: every pose, power-up and concept-sheet view, front, back and
side; `avatar_run_review`: a scripted run through the game camera on any zone's skin, with any
power-up look), ramps and walls (`ramp_wall_review`: a ramp launch with the credits along its wall
run, and blocked wall entries at a low and a high sign, through the game camera or a close one),
zone doodads (`doodad_review`: the runner pushed by a small, a medium and a large one, both ways, and a
switch into one's side blocked, with others standing in the other inner lanes at five lanes or more, in
any zone's look, through the game camera or a close one, `--hitboxes` for their bodies), floor cuts
(`floor_cut_review`: the stand-in's warning, charge and the gap it leaves beside a runner who switched
out, in any zone's look at any lane count and speed, through the game camera or a high one; `--stay`
for an armor block and the floor's hold, `--kill=D` for a cut stopped where its cause dies,
`--reduced-flashing`), wall fences (`wall_fence_review`: full-height ones held off, in their warning and on,
then low and high ones on both walls, in any zone's look at any lane count, through the game camera with a
runner beside them or along the wall (`--wall`), or a fixed one beside the track (`--camera=side --at=D`);
`--cycle` lets them pulse on the level clock, `--reduced-flashing`),
the enemies (`enemy_showcase` for the cyborg family: poses, the faces close up, a turnaround, window
cyborgs, and a far view through the run camera where the expressions must read, in any zone's look
(`--variant=`, or ui_left / ui_right live), and every look side by side (`lineup`, front, back, as
hosts or aiming, and `lineup_far` at gameplay distance); `octodog_screech`,
`drone_truck_showcase`, `bad_dream_showcase`, `resonator_showcase`: its model through its warning
and pulse, or a scripted run where it pulses at a runner who jumps its waves; `barnacle_turret_showcase`:
both looks at rest and charging, and a scripted run under a ceiling with turrets or riding it past one,
through the run camera or a close one, on any zone's skin; `buzz_overdrive_showcase`: its model turning
and revving, or a scripted run through one encounter on any zone's skin, lane count and speed, through
the run camera, a high one or a low one beside its lane, with `--stay`, `--kill=D` and
`--reduced-flashing` as for the floor cuts, and `--pass`: another type's big attack still on as its rev
would start, so it speeds off ahead instead, task FIX2); `gilded_sentinel_showcase`: a Golden street with Sentinels in
their niches and a runner taking a route past each (`--route=lane|floor|high|low`, `--kick`), through the
run camera or a camera across the street, straight at a niche or along its wall (`--view=play|close|front|
wall`), with `--double`, `--pair`, `--skin=golden_palace`, `--speed=N`, `--reduced`), `enforcer_truck_showcase`: the Enforcer Truck arriving, picking up a rider and firing
a volley the runner dodges, showing itself beside the runner (twice, a lane change into it bumped back the
second time, `--bump=N`), closing up for an Octodog whose late-dodged lunge flattens it (`--early`: dodged
at once, it follows out unharmed), a Buzz Overdrive's charge left late or its cut (the tank shot down), a
too-wide gap (each ending in its blast), or its model on a plinth
(`--scenario=chase|show|octodog|buzz|cut|gap|model`; showings only in `show` unless `--shows`), on any zone's
skin, lane count, speed and rider count, through the game camera or one behind or beside it
(`--camera=game|behind|side`, `--reduced-flashing`), the Golden Zone's statue
kit (`statue_showcase`: every pose, a turnaround, and a statue rigged in the kit's niche and swinging), the bosses (`floating_head_showcase`, `sleep_taker_showcase`, `the_house_showcase`, `sewer_swarm_showcase`),
the swarm's rendering stress test for the phone test (`swarm_stress`: N clusters of C screeches with a frame-time
and draw-call readout, sliders, `--seconds=S` for a summary line), the UI kit, the screens (`screens_showcase`;
its `--screen=hud_armor [--tier=N]` takes the HUD's armor through its states: up, broken, its ring
filling, back), a zone skin
(`skin_review`: any skin from fixed spots, including close-ups of the cult's feed screens and emblems a
skin lists, or a scripted run with a ceiling ride and a wall run, in a level's darker lighting with
`--darkness=X` and under a level's own sky with `--sky=name`; `--narrow` makes three of its ceilings narrow, one lane in the middle, the two leftmost
lanes and the rightmost lane, with shots riding each, of its far end from below and from beside it, and
a run that tries moves past their edges; `--from=D` starts the run further on, `--reduced-flashing`
turns Reduced flashing on), a cinematic (`cinematic_review`: any campaign slot's cinematic on its own, as
the App plays it, or the toolkit's sampler), and comparison
sheets for an open design choice (`cult_emblem_sheet`, D7). Each script's header lists its options. Render
frames on the Compatibility renderer (the web and low-end Android path) with `--write-movie`, as in
`CLAUDE.md`.

`tools/measure/big_attacks.gd` measures the big attacks (GDD §9, "Big attacks take turns") over
simulated runs of the campaign's levels at 3, 5 and 6 lanes, with `GameRules.big_attacks_take_turns` on
and off: a god-mode runner in the middle lane, stomping every host it passes, while the enemies play as
in the game. It reports the time big attacks of different types overlap, how many of each kind came,
how long attacks waited for their turn (from the first frame the director holds an enemy for another
type's turn until its attack, through gaps of up to 3 s, and an Octodog's until it charges, however
long it moves its charges on; the director answers each ask the same whatever its queue keeps, so two
builds measure the same asks alike), the enemies that never got a big attack in (Octodogs
without a charge, Resonators without a pulse, drones without a barrage, hover trucks without a lurch
or a cannon shot), and what each Buzz Overdrive did once it set off (`AttackWatch.buzz_tanks`: revved,
revved into another type's open attack, let the runner pass, or was shot down first; task FIX2), and each Enforcer Truck that arrived (`AttackWatch.enforcers`: its
volleys, riders and what destroyed it; its volleys count as `enforcer_volley` attacks; task C6)
(`godot --headless --fixed-fps 60 -s res://tools/measure/big_attacks.gd --
--levels=gangland/3 --lanes=3,5,6 --out=build/measure/x.json`; the whole campaign on its own seeds takes
about ten minutes; `--seeds=6` adds six other seeds a level, `--seeds=9007-9020` runs a range, and
`--features=octodog` keeps the levels that use a feature). `attack_watch.gd` watches the attacks from the
enemies' own states and the live shots, never from the turn-taking code (only the waits come from the
director's answers), and hashes each run's event log, so two builds (or the switch off and a build
without the rule) can be compared run by run.

`tools/measure/frame_times.gd` measures frame times (task PERF1; A run, Smooth frames): it plays campaign
levels and boss fights (built ones, and ones still being built through their preview scene) through the App
as the game does, without App.boot (a stand-in for the main scene), with a scripted runner (god mode, no
falls, the zone's speed; the level's seed picks a lane switch, a jump or a slide every 0.5 to 1.25 s; a boss's
test bot where there is one), and times every frame with a `FrameMonitor`. Each pass runs in a fresh Godot
process (`--child`), so it pays what a session starting there pays, and each frame keeps its fastest time over
the passes (`--passes=N`, 2), since another process taking the CPU shows in one pass only; `--session` plays
everything in one process instead. Per run: the median, 95th and 99th percentile and worst frame, frames over
8 and 16 ms, the load, kills and hit-stops (begun, frames held, the longest hold, holds that ran into the
next), and the causes of the frames over 4 ms by time over the median; `--log` hashes an event log (AttackWatch's,
every kill, the runner's place each second), `--shaders` lists the shaders first drawn after the load (always on
under xvfb, where it also counts draw calls, primitives, objects and compiled pipelines by source), and
`--reference` times SkinSuite's reference build alongside (`test_frame_times`). The headless run is the CPU
only (the dummy renderer); xvfb's software renderers give valid counts, not times
(`godot --headless --fixed-fps 60 -s res://tools/measure/frame_times.gd -- [--levels=city/1] [--bosses=]
[--frames] [--out=build/measure/x.json]`; the whole campaign and its bosses take about fifteen minutes). It
runs on older builds too (it reads them by property names): copy it and `scripts/run/frame_monitor.gd` into
a `git archive` of the build.

`tools/measure/stomp_routes.gd` measures how forgiving the Floating Head's ways onto its head are, in its
fight on a plain street at the City boss step's speed (21 m/s; `--speed=N` for another, 18 for the
reference speed): the ramp's boarding window (the latest lane switch from beside it that still
stomps, from each side), the stretch of jump points a single wall jump stomps from (swept about the jump
mark at the run's pace; `--fine` finds each end of it by bisection), getting onto the wall at the marks'
start or just before the release line, and the ceiling from a pad in each lane, in metres and in seconds
of running (what stays the same at every speed)
(`godot --headless --fixed-fps 60 -s res://tools/measure/stomp_routes.gd -- --lanes=3,5,6
--routes=ramp,wall,ceiling`; `--e1c` measures E1c's numbers, `--second-move` adds the in-air move; the
default run takes a few minutes).

`tools/measure/enforcer_shows.gd` counts the Enforcer Truck's showings chase by chase (tasks C6b, C6c, C6d) over
simulated runs of the campaign's levels with the truck, a god-mode runner keeping to each lane in turn (AttackWatch's,
jumping the holes in its lane, baiting nothing): each truck's arrival, its showings (`+` for the arrival showing),
its planned window, whether that comes before its chase's first bait (`gen.show_window_result`) and whether a showing
began in it, and for a chase without one why not (`show_problem()`'s shares, or what destroyed it before its window
was due); the totals by lane count, of the chases (each once: with a window before their bait, after it, none) and
of the runs (`godot --headless --fixed-fps 60 -s res://tools/measure/enforcer_shows.gd -- [--levels=corporate/2]
[--lanes=3,5,6] [--runner=all|middle|N] [--seeds=N] [--out=build/measure/x.json]`; all six levels at 3, 5 and 6
lanes, every lane, take about three minutes on their own seeds).

`tools/measure/level_shape.gd` measures the campaign's shape: for each level at 3, 5 and 6 lanes, on its
own seed and others, each feature's share of the pattern picks, the enemy, host and obstacle counts, the
features that appear only thanks to the every-feature guarantee, and for a level paced in bursts (The
Hush) its quiet stretches against its bursts, with the recency curve on and off and a level's remix
settings on or off (`godot --headless -s res://tools/measure/level_shape.gd -- --levels=dead_zone/2
--curve=on,off`; the whole campaign both ways takes about a minute and a half).

`tools/measure/level_pace.gd` measures each campaign level's pace and density (G1; GDD §3): its run
speed and length, and per minute its obstacle rows (and rows of holes), enemies, big attacks (Octodog
charges and Resonator pulses as planned, drone waves, hover trucks), mechanics, zone doodads (G5) and the
pushes a runner who keeps to a lane and ignores them takes (averaged over the lanes, and in the middle
one), and all events, doodads among them; its
empty stretches in seconds (the longest and the mean; what counts as going on is in its header); and
its credits. `--old-data=DIR` builds the levels with another version's data (the .tres files of
`data/tuning`, `enemies`, `levels`, `zones`, `campaign` and the patterns, e.g. main's exported with
`git archive`), `--dump=FILE` writes every layout as JSON, so the new code with the old data can be
compared byte for byte with the old build's dump, and `--set=key:value` tries level values before they go
in the files (`godot --headless -s res://tools/measure/level_pace.gd -- --seeds=4`; about half a minute).
