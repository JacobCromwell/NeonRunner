# Architecture: A run: the run, speed effects, smooth frames, retries

One part of the architecture notes; `docs/ARCHITECTURE.md` is the index of every part and topic.

## A run

`App` builds a `RunContext` (level config ready to generate, tuning, loadout, attempt) and starts a
`LevelRun` (`scripts/run/level_run.gd`), which generates the layout and builds a `RunWorld`. A boss
fight is a run too: its context carries the boss, and LevelRun builds the world on the boss's arena
and hosts its `BossEncounter` (see Bosses). A level that plays a mini-game (the Beach's volleyball match) builds
the world on the track its `MiniGame` plans, and the game joins it (see Mini-games).

Campaign, retries/replays, endless and campaign debug starts (`--level`/`--boss`) first prepare
the world in `LevelRun.State.READY`, with processing/HUD/touch input held, then show
`LevelIntroScreen`. Prepared collision objects stay registered while processing is disabled
(`DISABLE_MODE_KEEP_ACTIVE`, restored on PLAY), so the first frame cannot lose the boss's floor.
PLAY calls `App.begin_run()` / `LevelRun.begin()` on that same world; Back
discards it without a run result or consuming hints. Quick play still starts immediately without hints.
`HintDirector.setup()` collects unseen catalog hints as `intro_hints` (`Array[Dictionary]`, each
`{id: String, text: String}`), using actual layout triggers, boss-id routes and actual boss pickups
(standard armor). No unrelated shield/grapple hints
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
             the shared impact spectacle (kills, blocked hits, hard landings, stomps), and the one
             pooled fireball every explosion uses (`fireball`, FireballPool)
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
and `--full-loadout` for reviews (task D10b's fallback for a zone outside the campaign went with D10c, which put
the Beach in it); `--boss=<boss id>` plays a boss fight (a zone's boss with the full
flow, such as `--boss=city_boss`; any other, such as the test boss, or a zone's boss still being built
(`BossDef.preview_scene`), as quick play) and also takes `--phase=N`. Command-line starts work in debug
builds only, so a release build can't skip progression or farm credits with them.

Physics order each frame: RunWorld (builds chunks, spawns enemies) → Player (moves, checks hazards
and triggers) → the boss's pattern (a boss fight) or the mini-game (a mini-game level) → enemies → projectiles →
credits → pickups → power-ups.

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
  - a zone doodad the dash smashes (`Player.smashed`, task H5) flings its pieces (`RunEffects.rubble`, two
    pooled `RubbleBurst`s, `scripts/run/rubble_burst.gd`: one MultiMesh of the kit's lit box, 10 to 28
    pieces by the doodad's size, in its look's own colours, carried on along the runner's way and out to the
    sides, tumbling, skidding off the floor and shrinking away within `rubble_life`) with a light shake
    (`smash_shake_*`) and no sparks or hit-stop: something solid breaking, not an explosion or a hit. Nothing
    in it glows or flickers (the kit's solid material, its colours' glow 0), so Reduced flashing leaves it
    as it is; its pool is made with its material on, so ShaderWarmup draws it at the load. Numbers in
    "Doodad smashes";
  - a dash wall breaking (task H7a; `Player.smashed` with a wall, whatever broke it: the dash, a crash or a
    pass on a side wall, or a hover truck bursting through one) **crumbles** (`RunEffects.crumble`): a bigger
    `RubbleBurst` of its own (made with `RubbleBurst.new(wall_rubble_pieces)`, up to 64 pieces, larger ones,
    flung out of the lanes and up in the wall's look's colours), a one-shot cloud of see-through dust out of
    the wall's lower face (a `CPUParticles3D` on the fireball's puff material, fading as the camera nears it,
    so the camera coming through a moment later keeps sight of the street), and a heavier shake
    (`wall_shake_*`), with the crash's sound (`dash_wall_smash.wav`). It emits `crumbled(breakable)` for tests
    and tools. Made in `setup()` for a level with dash walls (hidden, so ShaderWarmup draws both at the load),
    one of each: walls stand at least the dash's longest cooldown apart, so one crumbles at a time. Nothing in
    it glows or flickers; Screen shake scales its shake. Numbers in "Dash walls";
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
- **Explosions** (task H6, the owner, October 8, 2026, GDD §11: "a yellow and red fireball"). Every explosion in
  the game is one call, `RunEffects.fireball(pos, size, smoke, pace, spread, carrier)`, a pooled `FireballPool`
  (`scripts/run/fireball_pool.gd`, built by `RunEffects.setup`). `size` is the fireball's radius in metres
  (`SpeedFxTuning.fireball_scale` multiplies all of them); the pool does the rest, scaled by it: a yellow core
  that blooms into orange and red, rolling outward and up, embers thrown out of it and dark smoke after
  (`smoke` off for a quick one; `pace` plays it faster; `spread` holds its fire in nearer its centre; a bigger
  one plays slower, `fireball_big_size`, so a boss's takes its time: 1.0 s of fire at 3 m, 1.7 s at 9 m or more).
  A fireball burns where it was set off unless it has a `carrier`, a node kept in the runner's frame (the
  Enforcer Truck's wreck, which blows up where the chase camera sees it and falls back slowly): its slot's
  emitters then draw in their own space and the pool moves them with the carrier each frame
  (`FireballPool._carry`), so the fire and everything it threw go along, until the carrier leaves the tree.
  It is **four `CPUParticles3D` a slot** (core flash, fire, smoke, embers), billboards of one soft, lumpy blob
  texture drawn once by the CPU, in unshaded `StandardMaterial3D`s (additive for fire and embers, see-through
  for smoke; `vertex_color_is_srgb`, so the ramps' colours are the inspector colours the Compatibility
  renderer shows and Forward+ converts): no GPU particles, no custom shader, no lights, nothing that differs by
  renderer. **Pooled and fixed**: a slot per simultaneous fireball (`fireball_pool`, 8; one more cuts the
  oldest short; on a low-end device, `DeviceProfile.is_low_end`, half as many slots and `fireball_low_end_share`
  of the particles), particle counts, ramps, curves, textures and materials fixed when the level loads (so an
  explosion allocates nothing: a test counts the nodes), and `ShaderWarmup` draws the three materials during
  the load (`_sample_fireballs`). A fireball is a look: no collision, no light, no hazard colours left behind
  (the smoke is dark, and each one is gone in a second or two; a quick one in a fraction of that).
  **It never whites out the view** (the H6 review): the camera rides behind the runner and runs into what has
  just blown up, so each live fireball's strength follows the camera's distance from its centre
  (`FireballPool._fade`, each frame: none of it within its size of the camera, all of it from 2.5 times its
  size, in between by the distance, by the emitters' colour alpha, and an emitter showing nothing is hidden,
  which also saves its fill rate); the materials also fade each puff out within 1.5 m (fire) or 2.5 m (smoke) of
  the camera, fully drawn from 5 m or 8 m. The Enforcer wrecked right behind the runner is almost gone as the
  camera passes through its fireball, and an explosion ahead fades as the camera closes on it.
  `tools/measure/screen_luminance.py` measures it on rendered frames (the scene's mean luminance, the frames
  above twice it, the share of the screen above 0.35).
  **Reduced flashing** (`Settings.flashing_reduced`, read as each one starts): a fireball lasts exactly as long
  and at the same pace, but is lit up from nothing over the first 28% of its life instead of at once, has no
  pale-yellow start (orange, then the normal ramps' own cooling at the same points of its life), and is
  `fireball_reduced_brightness` (0.45) of the normal strength: at no moment brighter than the normal fireball
  (`test_fireballs` samples the real life: never brighter after 0.15 s, a peak at most 0.45 of the normal peak, in
  the fire, the core and the embers). It asks for no shake and no sound: each caller's own `shake` (under the
  Screen shake setting) and sound stay. A blast on the street is lifted out of the floor (`size * 0.45` up).
  `fireball_played(pos, size)` announces each one (tests, tools). Who calls it, at what size: the drone's hit
  (1.0) and crash (2.4); the hover truck's explosion (3.8, set out from the wall it skids into) and its burst
  through the wall (2.6, quick); the Buzz Overdrive (3.0), the Enforcer truck (its blast's radius: 1.3, 0.85 in the
  runner's lane; carried along with its wreck, held in, no smoke, its fire as long as `blast_seconds`; task C6b's
  wreck, merged October 9, 2026) and a fence generator (1.2,
  held in, quick and smokeless since the runner stands on it; inside the EMP's cyan ring: `RunWorld.emp` is unchanged); the plain missile's hit (0.9, quick) and the heavy
  missile's blast (2.2, inside the cyan ring that shows its splash: `WeaponFx.missile_pop`, `blast`); Hostile
  Takeover's defeat (`HostileTakeoverLobby.blast`, five fireballs rolling on, 10.8 m down to 5.4 m); the Floating
  Head's crash (9, 6.75 and 5.4 at the wreck and its ends, no smoke: the wreck has its own) and its tower's
  landing on the ship (3.2); The House's collapse (7 and 4.9); each bomb blast of the Floating Head (its salvos'
  too, task E1g) and The House (the blast's radius, held in to 0.45 of the free spread, quick, no smoke: what looks
  like a hit is a hit, and the fireball is gone about when the hitbox is; their timing, warnings and hitboxes are
  untouched); the City outro's roadblock blast (2.0, from a one-slot pool of the outro's own); and the Golden
  Convergence's (task E5d, drawn through the run's pool since the H merge, which retired E5d's own blended blast):
  the Refill Ship's chain reaction, planned within the pool's 8 slots (its squadron's crashes 2.4 without smoke, a
  quick 2.2 for every five rack missiles of the ripple, the ship's five from 7 m down to 3.8 m with their smoke, a
  quick 3.0 every 0.2 s up the feed line and 4.5 at his shoulder), its barrage's landings (2.0, quick, held in,
  smokeless) and the transition's burst of the suit (6.0, with smoke). The Sleep Taker's wisps and chunks, the Sewer
  Swarm, the Golden Convergence's dust, glass and sparks, and plain deaths are not explosions and keep their looks.
  `tools/showcase/fireball_showcase.tscn` plays each of them through the real code
  (`--scenario=sizes|drone|drone_pad|truck|truck_burst|buzz|enforcer|enforcer_close|generator|missile|bomb|bomb_straddle`,
  `--reduced`, `--cam=close`).

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
  effects; not the hitbox view's debug boxes, `GreyboxMaterials.is_debug_overlay`, which only a debug build
  shows), the effects' glow and the fireball's three looks (`FireballPool.materials`), one look of each enemy kind (`EnemyDirector.warm_looks()`, every part shown) and
  each track piece the zone skin dresses (fences in each state, wall fences, a sign, pads, ramps, speed pads,
  ceilings, doodads, a dash wall in a level that has them, gap edges, the finish line). It keeps the samples' materials until the next level's
  stage, so their shaders stay built for a look first met later. After it no shader on Gangland 3 is first
  drawn mid-run. The track pieces are dressed on hazards and trigger areas made once a process and never
  freed while the game runs (out of the tree; their looks move onto plain nodes in the stage): **a warm-up
  never frees a physics object**, since the next one made takes its place in the physics server's tables,
  which can change the order of contacts in a frame (two throwaway hazards made and freed at a boss fight's
  load moved one kill in Hostile Takeover's seeded event log by a frame; made and kept, they changed
  nothing). On the web each program compiles while the game waits (seconds each on Windows, where browsers
  translate WebGL to Direct3D; `node tools/web/shader_programs.js` counts them), and the renderer compiles a
  shader once per Shader, not once per code: **one Shader per shader code** (the credits' denominations share
  theirs, `CreditField.material_for`; a test checks every look the warm-up draws). Two standard materials
  that differ only in draw state (blend mode, depth draw or depth test) also get a shader each with the same
  code; the fireball's additive fire and see-through smoke still do (5 programs of City 1's load).
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

### The hover truck's cost on a phone (task I5, the owner's report, October 14, 2026)

"The Hover Truck causes a big performance drop on a playtester's phone." Measured on the Compatibility renderer
(a phone's, the web demo's; `tools/measure/truck_cost.gd`: a quick-play run, trucks spawned at set times, each
phase of their visit framed apart, software GL under xvfb with the driver's shader cache off; Vulkan isn't
available in the dev container, so Forward+ and Mobile weren't run), the cost was one thing and two small ones:

- **Its `OmniLight3D`, the only real light in a run** (the rev's "light thrown ahead", energy 0 the rest of the
  time). The first omni light a Compatibility scene shows, even at energy 0, makes the renderer build a second
  version of every lit shader within its 7 m range (a probe scene of five lit materials and a sun: 270 to 400 ms).
  At the truck's burst, when its model, light included, was first shown, that was one frame of 6.0 s on the City
  and 8.9 s on Gangland in software (on the main of October 15; 5.7 and 5.9 s on the main of C6's merge), and
  another 0.2 to 0.3 s when a later truck on the other wall first lurched back (other shaders in reach); after it,
  every lit pixel in range paid for the light, for the truck's whole stay (the steady cost can't be resolved on a
  shared machine: a llvmpipe frame varies by 10% by itself). The Mobile renderer
  specialises its pipelines by the lights a draw has (`RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION`), so
  it likely pays the same in pipelines. Now the light is two plain glow discs, one on the floor past the nose and
  one on the wall beside it (`HoverTruck._glow_mesh()`: a fan fading from solid to nothing by vertex alpha, added
  light, unlit, two shared materials, dim and bright; `GLOW_*`), shown exactly through the rev and the forward
  lurch, flashing with the spikes and steady with Reduced flashing, as the light was (side by side frames of the
  rev, in the close-up scene and in a Gangland run, read the same). **A run has no real light** (`OmniLight3D`,
  `SpotLight3D`; its one `DirectionalLight3D` is the sun): a warm glow is a mesh, and `test_hover_truck` fails on
  any light in a run with a truck. (Two cinematics still have one each, the Dead Zone's crater and the sports
  car's cabin; the first time either shows it builds its lit shaders' second versions the same way.)
- **Its first spawn built its model** (4 to 5 ms on the dev machine, 30 to 70 ms in PERF1's count, in the spawn's
  frame, and its first draw's shaders then: 0.3 to 0.6 s in software): it had no `warm_up` hook like the other
  enemies. It has one now: its model, the glows its parts swap in, the wall effects and the warning glow, readied
  with the level and drawn by `ShaderWarmup` (its fireballs are `RunEffects.fireball`'s, pooled and warmed with
  the run).
- **Per-frame work while hidden** (its first seconds, from the spawn lead until it bangs): the animation ran on a
  hidden model, setting about ten properties a frame, five of them material overrides (each makes the renderer
  look the part over again, even to the same material). It now does nothing until it bangs and sets a part's
  material only when it changes (a hidden tick is 2.5 to 0.8 µs, a pacing one the same 12 to 25 µs).

On the current main, trucks of both sides in the same seeded run (5 lanes, 640×360, 9 s stays), the worst frames
of the visits were 8.9 s (the burst), 0.6 s (the spawn), 0.3 and 0.2 s (the other wall's lurch back) and 0.17 s
(the wreck) on Gangland, and 6.0, 0.35, 0.33, 0.28 and 0.22 s on the City; with the glow and the warm-up the
worst frame of a visit is 85 ms in both, within 1.5 to 2.5 times the median, rev, lurch and wreck included. It
reads the same: a seeded run's event log is unchanged (corporate/1, gangland/2 and city/3, `frame_times.gd
--log`) and its headless frame times are (corporate/1 median 0.86 to 0.84 ms, 99th percentile 2.57 to 2.42 ms).

Not the cause: draw calls and triangles (its model is 25 surfaces and 1,250 to 1,860 triangles: 19 draw calls,
27 with two gunners, against a frame's 170 to 250, and the facade's panel and cracks while it bangs and the rubble
for 1.3 s after), particles and rubble (pooled and pre-built), physics (two roofs, a blocker, three hitboxes) and
the wall (nothing rebuilds it: the hole is a quad over the facade). `RunEffects.burst()` sets each particle
system's `amount` on every call, which reallocates its buffers whether it changed or not (a truck's burst starts
a few); skipping an unchanged amount is a small win for every effect, left to a task on `RunEffects`.

### Retries reuse the built level (task PERF2, the owner's approval, October 9, 2026)

Generating its level was the slow part of starting a run, and every attempt did it again, though a campaign
level comes out the same on every attempt (GDD §6: a fixed seed). `LevelCache` (`scripts/run/level_cache.gd`)
keeps the last level a run built: `LevelRun._build` takes a level's layout from `LevelCache.layout_for(context)`,
which builds it the first time and hands every later run of the same level a copy of that build: the results
screen's retry (`App.retry`, a new LevelRun) and the restart in place (`LevelRun.restart`: quick play's after a
death, R, F6's Restart level) alike. A boss fight's arena never comes here: its plan takes 6 to 25 ms
(`BossEncounter.plan_arena`), and a boss's `_plan_lap` may keep state of its own on the encounter.

- **The key** (`LevelCache.key_for`): a build is reused only while everything the generator reads is the same:
  the level config's stored values (seed, lane count, difficulty, features and their starts, pacing, run speed,
  the campaign's recency curve and ages; its `skin` aside, which the generator never reads), the movement
  tuning it is built at (`LevelConfig.movement_for`), the patterns as read from their files now
  (`LevelGenerator.load_for`), every tuning resource in `data/tuning` and `data/enemies` by value (the
  placement passes', the power-ups', every enemy type's: the F6 panel edits them in place, so an edit there
  builds again), and the build flavor. Dictionaries go in as ordered pairs. **A tunable the generator reads
  from anywhere else must join the key** (`LevelCache.TUNING_DIRS`, `key_for`), or a run after a change to it
  could play the level built before. A new seed, lane count, level or setting builds again (quick play's debug
  keys, `--features`, a difficulty tier), and only the last level is kept. Endless mode builds on every run (a
  random seed each) and keeps nothing.
- **Every run plays a copy.** The kept build is never played: each run, the first too, gets a
  `LevelLayout.copy()` of its own, since a run changes its layout as it goes (an EMP marks fences `disabled`
  in it, the track numbers its fences, the dash smashes a zone doodad and a dash wall breaks in it, their
  entries marked `smashed` (and a wall's `broken_by`) and never built again that attempt (tasks H5 and H7a,
  `DashBreakable`), a boss arena's next lap or endless mode's next stretch joins it, and an enemy's entry is
  its own one level deep only). So a retry's world, built anew (`RunWorld.build`) from a fresh copy, has every
  doodad and wall standing whole: an attempt that smashed or broke them marked only its own copy (the H merge;
  `test_level_cache`'s `_test_smashed_stand_again` dashes through a doodad and a wall at Golden 1, dies, and
  checks both retries: the build's layout exactly, both built whole with the same node, place, layers, shapes and
  look, and an attempt without the dash playing exactly as on a fresh build; `_test_nothing_leaks` smashes and
  marks every one). A generated layout holds plain data only, no Object and no
  list or dictionary in two places (a copy would make two of it): `test_level_cache` checks two levels, and a
  probe found neither in any campaign level at 3, 5 and 6 lanes. So **`LevelLayout.copy()` must copy every
  field a layout has**: a list added to LevelLayout must join `copy()`, or every run would play without it
  (`test_level_cache` checks every field). The build's generator warnings come with each copy; LevelRun prints
  them on every run, as before.

Measured with `tools/measure/level_builds.gd` (Review tools), headless on the build machine (4 CPUs shared with
other agents, measured while quiet; a phone is several times slower). The time from pressing retry to the run
starting, three retries each at 5 lanes (the call / to the next frame, when the run is built and its
introduction is up):

| Level, 5 lanes | Results screen's retry (`App.retry`), before | after | Restart in place (`LevelRun.restart`), before | after |
|---|---|---|---|---|
| Corporate 2 | 3194 to 3877 / 3280 to 3964 ms | 216 to 251 / 296 to 318 ms | 2642 to 3204 / 2652 to 3216 ms | 47 to 63 / 57 to 74 ms |
| Dead Zone 1 | 4133 to 4639 / 4203 to 4722 ms | 245 to 278 / 361 to 394 ms | 3392 to 4382 / 3406 to 4394 ms | 59 to 66 / 68 to 75 ms |

What is left of a retry: the key (about 15 ms), the copy (1 to 2 ms), the world's build (`RunWorld.build`), and
through `App.retry` a whole new LevelRun (HUD, camera and, in a debug build, the debug HUD and the F6 panel). A
level's first build pays the key and a copy on top of the generator (15 to 30 ms).

Each campaign level's first build (`generate()`, the fastest of three, in ms; in brackets the builds its
every-feature guarantee made, when more than one):

| Level | 3 lanes | 5 lanes | 6 lanes |
|---|---|---|---|
| city/1 | 57 | 71 | 52 |
| city/2 | 40 | 36 | 41 |
| city/3 | 47 | 50 | 53 |
| gangland/1 | 64 | 66 | 125 (2) |
| gangland/2 | 58 | 90 | 76 |
| gangland/3 | 107 | 152 | 270 (2) |
| marketplace/1 | 138 | 95 | 203 |
| marketplace/2 | 429 (3) | 498 (3) | 280 (2) |
| corporate/1 | 173 (2) | 688 (4) | 386 (4) |
| corporate/2 | 579 (3) | 2434 (4) | 386 (2) |
| dead_zone/1 | 935 (3) | 2891 (4) | 1400 (3) |
| dead_zone/2 | 1900 (5) | 1146 (3) | 1608 (2) |
| golden/1 | 371 (2) | 945 (3) | 575 (2) |
| golden/2 | 1393 (4) | 569 (2) | 592 (2) |
| golden/3 | 316 | 406 (2) | 1158 (4) |

The slowest are Dead Zone 1 at 5 lanes (2.9 s), Corporate 2 at 5 lanes (2.4 s) and Dead Zone 2 at 3 lanes (1.9
s); the 45 builds take 23.9 s in all. Two things multiply (`level_builds.gd --passes`): the guarantee's rebuilds
(a level missing a feature is built again whole: 2 to 5 builds in every slow one), and within a build the Enforcer
Truck's rules (the showing planner of tasks C6c to C6e): 415 of Corporate 2's 544 ms first build at 5 lanes
(76%), 1035 of Dead Zone 1's 1686 ms (61%, and the Buzz Overdrive's rules 371 ms, 22%); every other pass takes
under 80 ms. Dead Zone 2 at 3 lanes is mostly its five builds (269 ms each, the truck's rules 62 ms of it).
Making the truck's planner cheaper and sparing guarantee rebuilds is left to a task on the generator. A boss
arena's plan takes 6 to 14 ms (the fastest of three; 6 to 25 ms in single runs).
