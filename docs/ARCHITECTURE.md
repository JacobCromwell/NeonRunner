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

```
RunWorld (scripts/run/run_world.gd)       one run's gameplay world; everything shares it
  Track      TrackBuilder: floor/hull collision, obstacles (fences, signs), triggers (pads, ramps,
             speed pads), built in 40 m chunks around the player; the zone skin decorates it
  Player     movement on floor, walls and ceiling; protection; receive_hit()
  Boss       BossEncounter, in a boss fight only: the fight and the boss's pattern (its parts are
             enemies, under Enemies)
  Enemies    EnemyDirector: spawns layout enemies as the player approaches, retires them
  Projectiles ProjectilePool: every shot, pooled and swept
  Credits    CreditField: every credit as MultiMesh instances; pickup and magnet
  Pickups    PickupField: armor, shield and grapple pickups a boss offers, placed fairly, pooled
  Effects    RunEffects: particle bursts, glowing lines, camera-shake requests
  Score      ScoreKeeper: level score, credits, kills, bonuses, stats
  Sounds     PlayerSfx: non-positional sounds (RunWorld.play_sfx / play_sfx_at)
  Powerups   PowerupController, created if scripts/powerups/powerup_controller.gd exists
```

`LevelRun` adds the camera (`RunCamera`), the HUD (`RunHud`) and, in debug builds, the debug HUD and
the F6 tuning panel. Quick play (`--quick`, or any of `--god --seed=N --lanes=N --difficulty=X
--features=a,b --full-loadout --nofall --skin=<name>`) restarts on death like the grey box did.
`--level=<step id>` plays a campaign step with the full flow and takes `--lanes`, `--god`, `--nofall`
and `--full-loadout` for reviews; `--boss=<boss id>` plays a boss fight (a zone's boss with the full
flow; any other, such as the test boss, or a zone's boss still being built (`BossDef.preview_scene`),
as quick play) and also takes `--phase=N`. Command-line starts work in debug builds only, so a
release build can't skip progression or farm credits with them.

Physics order each frame: RunWorld (builds chunks, spawns enemies) → Player (moves, checks hazards
and triggers) → the boss's pattern (a boss fight) → enemies → projectiles → credits → pickups →
power-ups.

## Data (tunables live in data, CLAUDE.md principle 7)

| File | What |
|---|---|
| `data/tuning/movement.tres` (`MovementTuning`) | run speed, jump, walls (and the blocked entry's bump), ramps and speed pads (their boosts share one fade), ceiling, piece sizes, camera, touch |
| `data/tuning/game_rules.tres` (`GameRules`) | lanes per device, death share, invulnerability, stomp, whether big attacks take turns, score, economy, stars |
| `data/tuning/powerups.tres` (`PowerupTuning`) | weapon tiers, claws, dash, magnet, slow time |
| `data/tuning/pickups.tres` (`PickupTuning`) | in-run pickups: where they appear, taking them, the charge cap, the look |
| `data/enemies/<type>.tres` (`EnemyTuning` subclasses) | per-enemy numbers, early/late pairs for campaign scaling |
| `data/shop/catalog.json` | shop items, tiers and prices |
| `data/campaign/campaign.tres` → `data/zones/*.tres` → `data/levels/*.tres` | the campaign |
| `data/bosses/*.tres` | bosses (`BossDef`: slot, health, phases, arena, rewards, par times, armor rule), and a boss script's own tuning (`<id>_tuning.tres`) |
| `data/cinematics/*.tres` | cinematic slots |
| `data/patterns/*.json` | generator patterns (every file in the folder is loaded) |
| `data/skins/*.tres` | zone looks |
| `data/audio/*.tres` | sound and music libraries |

Any `@export_range` number or bool on a resource registered with the tuning panel shows up under F6.

## Damage and interactions: one place (CLAUDE.md principle 8)

- **Hazards declare, `DamageRules` decides.** A `Hazard` (`scripts/world/hazard.gd`) is an Area3D on
  the hazard layer with properties: `is_electrical`, `is_enemy_attack`, `is_solid`, `dash_passes`,
  `enemy` (owning enemy or null) and `part` (`&"body"`, `&"top"`, `&"weak_point"`, `&"attack"`).
- The player checks contacts each frame (a swept shape query) and calls `Player.receive_hit(hazard,
  stomping)`, which asks `DamageRules.resolve()` and applies the outcome: `IGNORE`,
  `BLOCKED_ARMOR`, `BLOCKED_SHIELD` (then ~1 s invulnerability), `KILL`, `DEFEAT_ENEMY` (claws or
  dash), `STOMP` (enemy defeated, player bounces). Nothing else hurts the player.
- Falls aren't hazards: the Player handles them (the grapple hook saves one fall).
- Enemy shots go through `ProjectilePool.fire_enemy()`; the pool sweeps each shot against the
  player's hitbox and calls `receive_hit`, so armor, shield, invulnerability and the dash all apply.
- **Blocked moves bump, never hurt.** A lane switch into a solid side (a lane blocker: the hover
  truck's, a boss's block) and a wall entry where the wall is blocked (a sign, or a wall a boss takes
  away; GDD §3) move the player out toward it and back (`Player._start_bump`) with the clank
  (`lane_blocked` / `wall_blocked`). The player stays in their lane and can act meanwhile; collision is
  unchanged. The wall's bump (`wall_bump_distance`, `wall_bump_time`) stops short of any hazard or wall
  blocker in its way, so a sign that reaches down to the player stops it at its face, and the model
  leans away from the wall on the way back.

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
every attempt at a seed plays out the same way. Every attack needs a visual **and** audio warning
before it can hurt (CLAUDE.md readability rules). Enemy fire uses the pool's red "enemy_*" looks in
every zone. `world.skin.enemy_variant` (`&"city"` or `&"scavenger"`) picks the zone look.

A level uses an enemy only if its `features` list has the type's name (GDD §6: one new thing at a
time), from the feature's start if the level gives it one (The generator). Quick play can add
features: `./play.sh --features=cyborg,drone`. The campaign already lists the enemies still to be
built under the names their tasks must use (`LevelConfig.PLANNED_FEATURES`: `barnacle_turret`,
`buzz_overdrive`, `tithe_collector`, `resonator`, `gilded_sentinel`), so a new enemy's own files are
all it takes to bring it into its levels.

Built so far: cyborg (with its panic variant and hosts), window cyborg, fence generator, hover
truck, Octodog, sewer screech (manholes, and wall vents; `screech_vents` is wall vents only, for zones
whose floor has no manholes),
heli drone, and the Cyborg's Bad Dream (released by a killed host, spawned by the director at run
time rather than placed by the generator). `scripts/enemies/mesh_batch.gd` merges an enemy's low-poly
parts into one mesh per material to keep draw calls down.

**Big attacks take turns through the director** (GDD §9, decided September 26, 2026). The big attacks
of different enemy types never overlap, so the player never has to dodge two at once. The owner may
revert this after playtesting, so it sits behind one switch, `GameRules.big_attacks_take_turns` (on by
default, in the F6 panel); switched off, the game plays exactly as before the rule. The big attacks
(DESIGN-TBD, `docs/questions/r3.md`): the Octodog's charge sequence (its first wind-up until it gives
up), the drone's wind-up and barrage, the hover truck's rev and forward lurch and its cannon's charge
and volley, and the Bad Dream's chase. Small attacks (a cyborg's burst, a window cyborg's shot, a
screech's swipe) and the hover truck's entrance don't take part. An enemy takes part like this, and
the enemies still to come (the Barnacle Turret, Buzz Overdrive, the Resonator, the Gilded Sentinels,
the Tithe Collector) opt in the same way for whichever of their attacks count as big:
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
  held, and a waiting enemy that stops asking loses its place after a frame. Once a warning has
  started the attack runs its course; nothing stops it for another's turn.
- **An attack that may only come within a window** (the Octodog's planned charges) moves the window
  on while `held_for_turn(self)` says it's waiting for another type, up to a limit of its own
  (`OctodogTuning.turn_wait_max`), and keeps every fairness rule it was planned with.
- **An attack that can't wait** because the player sets it off (the Bad Dream bursts out of a killed
  host) or the generator planned its moment still reports itself: the others wait for it. It can
  overlap an attack that was already on when it came; the Bad Dream holds its slash until that one
  is over. (A planned one, like the Buzz Overdrive's cut, would need the others held off before its
  warning, which the director can't do yet.)

The director holds a big attack while another type's is on or its shots are still on their way; an
enemy whose own attack is on carries on (the Bad Dream's next slash in its chase); and of the enemies
of different types waiting, the one that has waited longest goes next (then the one spawned first),
so none is kept from its turn by others that keep asking. An attack that is on never waits for another
(the Bad Dream holds a slash within its chase only for an attack that was already on when the chase
began, and that one doesn't wait), so two enemies can't wait on each other. Types space their own attacks themselves
(one drone barrage at a time; one Octodog, one hover truck at a time). GDD §9.7's rule holds with the
switch off as well: an `exclusive_major_attack` (the Bad Dream's chase) and the attacks of the types in
its `exclusive_of` (Octodogs', drones') never overlap. `is_waiting()` and `turn_wait()` say whether and
how long an enemy has been waiting. `tools/measure/big_attacks.gd` measures the overlaps and the delays
over the campaign (Review tools); `tests/helpers/turn_dummy.gd` is a scripted big attack for tests.

**Floor use.** The floor under a ceiling may hold enemies (GDD §3, changed September 26, 2026), but
a ceiling's landing zone and the spot of each of its pads keep off the floor enemies use (see
Ceilings under The generator). A type's tuning says whether it uses the floor (`uses_floor`: false
for fliers like drones and hover trucks, and wall-only enemies like window cyborgs) and how much of
it around its spot (`floor_reach_before`/`_after`: where it stands, moves and attacks a player in its
lane; the screech's 30 m before covers where it springs out). Rules that plan a longer run for one
enemy store it in `params.floor_span` (the Octodog's charges). `LevelGenerator.enemy_floor_span(entry)`
and `enemy_uses_floor(entry)` read all of this; `CeilingZones`, `floor_clear` and `add_hull_with_pad`
respect it. An enemy that can't reach the ceiling stays consistent with it at run time: cyborgs, window
cyborgs and hover trucks hold fire at a player riding a ceiling, the drone and the Bad Dream wait
below, the Octodog never winds up and a screech stays in its manhole.

## The generator

`LevelGenerator` (`scripts/world/level_generator.gd`) builds a `LevelLayout` (pure data) from
patterns, a difficulty value and a seed, for any lane count. Passes, each with its own random stream:
patterns (filtered by the level's features) → enemy rules scripts → credits. Helpers for rules
scripts: `rng_for(name)`, `add_enemy(type, at, lane, side, params)`, `add_hull_with_pad(lane, at,
seconds)`, `floor_clear(from, to)`, `enemy_floor_span(entry)`, `enemy_uses_floor(entry)`,
`difficulty_at(progress)`, `feature_start(feature)`, `feature_started(feature, at)`,
`feature_active(feature, at)`, `feature_share_at(feature, share)`, `ramp_launch(ramp)`, plus
`layout`, `config`, `tuning`, `speed`, `jump_distance` and `zones` (the level's `CeilingZones`).
Pattern format: `data/patterns/README.md`.

**Ramps** (GDD §3) launch the player onto the wall higher than a free entry and add a speed boost
that fades away the same way a speed pad's does (both share `boost_decay_per_second`;
`MovementTuning.boost_left` and `boost_distance`), so a ramp's wall run goes further than a free
one. `RampLaunch` (`scripts/world/ramp_launch.gd`; `gen.ramp_launch(ramp)`) predicts it the way the
Player moves: where the player is on the wall and when (`distance_at`, `time_at`), how high
(`height_at`, `body_at`: the heights the body spans) and how fast (`speed_at`), from the launch
(`start`) to the drop back into the ramp's lane (`end()`). Every rule that predicts a ramp's wall run
uses it: the credits along it (`LevelGenerator.wall_run_credits`), and task B5's wall fences, which
must never put a live wall fence where a ramp launches the player into it. `test_movement` holds it
to the real Player at 3, 5 and 6 lanes, and `test_interactions` rides the credits on real physics.

Rules scripts run in the order of the level's `features` list, except that a script declaring
`const RUN_AFTER: Array[String]` runs after those features' rules (the host rules after the drone's;
the cyborg rules, and the host rules that start with them, after the hover truck's, so cyborgs keep
their margin from the ramp a truck adds; the Octodog rules after the drone's, the host's and the
hover truck's, so each dog is planned around the level's final ceilings, chases and truck lanes and
nothing clears it afterwards). When a rule needs room for one of its guarantees, it removes what's
in the way rather than moving it (taking content out never makes a level unfair). Guaranteed pads
come from `scripts/enemies/pad_placement.gd`, shared by the drone and host rules: the drone's pad
schedule (GDD §9.6) owns every pad after its first wave, pattern ceilings give way, and the host rules
(which run after the drone's) cover each Bad Dream chase with pads at most 10 s apart or leave that
host out. The Octodog rules keep each dog's charges off every stretch a chase can cover (GDD §9.7).

**Ceilings over a dangerous floor** (GDD §3, changed September 26, 2026). The floor beneath a
ceiling may hold gaps, hazards and enemies: the ceiling is the way to escape them, and it's never
required. `CeilingZones` (`scripts/world/ceiling_zones.gd`, `gen.zones`) holds the two stretches every
ceiling keeps safe, and the checks and clearing for them:
- **The landing zone**: from a section's end, `hull_landing_seconds` at run speed (21.6 m), no lane
  holds a gap or a fence and no floor enemy's stretch reaches in, so the player always lands safely.
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
Narrow ceilings (B3) and floor cuts planned in advance (B4, which never cut a landing zone or a
pad's lane) ask `CeilingZones` too. The tests check every generated ceiling with
`LayoutChecks.check_ceilings`, including a floor route under it that never takes the pad (`FloorRoute`,
a conservative model of the floor moves; some routes are replayed on real physics).

**Late starts.** `LevelConfig.feature_starts` (feature → share of the level) holds a feature back
until its start: patterns that require it aren't picked before, and the first pattern picked from
there must use it (its introduction), so the player meets it right after its first-encounter hint
rather than whenever chance brings it. A rules script that adds a feature's enemies or pieces keeps
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
patterns that require a feature (0 leaves them out). Corporate 2's heavier military presence uses it.

**Every feature appears.** In a level with `LevelConfig.guarantee_features` (every campaign level),
each feature a pattern can place there is in the finished level, at any lane count and on any seed
(GDD §5: an introduced feature keeps appearing). Rules drop or clear what doesn't fit fairly, so
`generate()` checks the finished layout and builds the level again until nothing is missing:
- `feature_positions(layout, feature)` finds a feature's pieces: enemies by type, hosts, wall-vent
  screeches, and the mechanics by their ramps, pads, speed pads or pulsing fences. A rules script
  that declares `static func positions(layout: LevelLayout) -> Array[float]` answers for its own
  feature (a new kind of piece, such as wall fences).
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
  `guarantee_one_wave` and `guarantee_one`), and a host and an Octodog in a level with
  `guarantee_features`.

## Power-ups

`PowerupController` (`scripts/powerups/powerup_controller.gd`) runs one `PowerupModule` per owned,
switched-on permanent item: `WeaponPowerup` (auto-fire, tiers 1–4, enemy health bars), `ClawsPowerup`,
`DashPowerup`, `MagnetPowerup` and `SlowTimePowerup`. Breakables (armor, shield, grapple) are charges
on the Player. The controller's header documents its API: `hud_state()` for the HUD (`charges` -1 for
permanent items), `equipment()` for the player model, and `try_dash()` / `try_slow_time()`.
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
  `Player.gain_item(item, max_charges)` adds a charge unless the player holds all they may, the
  `Loadout` counts it in `picked_up` (the App asks `Loadout.costs_stock()` when an item breaks, so a
  picked-up charge, like a granted one, never costs stock), and `collected(pickup, gained)` fires. The
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
(`floor_segment`, `wall_section`, `fence`, `wall_sign`, `hull`, `pad`, `ramp`, `speed_pad`,
`finish_line`, `make_environment`). Skins add visuals only, never collision or gameplay. Hazards keep
one colour and shape language in every zone (pink crackle = electric fence).

Skins so far: `CitySkin` (Zone 1, the Neon City), `GanglandSkin` (Zone 2) and `MarketplaceSkin`
(Zone 3, the Marketplace). `GreyboxSkin` is the fallback for zones without their own look yet
(Corporate, the Dead Zone and the Golden Zone for now). A zone's skin lives at
`data/skins/<zone id>_skin.tres` (`--skin=<zone id>` in quick play) and is set in its
`data/zones/<zone id>.tres`; a level's own `skin` wins over its zone's (the Golden Palace, Golden 3,
may get its own). The real skins build on the mesh kit (`scripts/world/meshes/`): `MeshKit` has
shared builders for hazards, triggers and environments, and `MeshLayer` batches a chunk's geometry.
The shaders in `scripts/world/meshes/shaders/` are procedural. `HazardStateVisual` swaps a hazard's
ON / WARNING / OFF materials. A skin's `enemy_variant` (`&"city"` or `&"scavenger"`) picks the
enemies' look.

The kit's solid shader (`kit_solid.gdshader`) draws surface patterns chosen per vertex (`MeshKit.PAT_*`):
panels, glass, glyphs and chevrons for the City; worn asphalt (with sand drifts and scorch around holes),
road strata, salvaged plating, posters (with corporate ads), cast concrete and stencilled crates and
container doors for Gangland; canvas, tin and whole rows of stall roofs, stall faces, tiles, shop
signs, ads, casino bulbs and stucco for the Marketplace. Features a zone opts into are uniforms that
default to off, so one zone's additions never change another's look. Painted marks shared between
shaders live in includes: `kit_marks.gdshaderinc` (graffiti pieces and tags, stencil codes) and
`kit_logo.gdshaderinc` (the corporations' placeholder logo). Two shader rules: take derivatives
(`fwidth`, implicit texture LODs) outside any branch that can differ between neighbouring pixels and
pass them in, and use `filtered_pulse()` only for ranges within 0–1 (`band()` for any other). Breaking
either can put a NaN in a pixel, and the glow pass blows it up into a white disc.

**Pattern ids.** Ids up to 19 are the City's and Gangland's, in `kit_solid.gdshader` itself; ids 20-29
are the Marketplace's (all in use), in `kit_market.gdshaderinc` (one include and one dispatch line in
`kit_solid`). A new zone takes the next free block of ten (30-39 next) in its own include, so zones
built in parallel never collide on an id. Ids 60-69 are the cult's, shared by every zone, in
`kit_cult.gdshaderinc` (its include follows `cult_mark()` in `kit_solid`, and its dispatch runs after
the zones' own): `PAT_CULT_MARK` (60) draws the cult's emblem from the material's `cult_emblem`
texture as a mark on a dark panel.

**Gangland's ceilings** (`GanglandCeiling`) take their width from the lanes they cover (the collision
box), never from the track, and draw each side as anchored (running into the building face) or free
(an edge face), so narrow ceilings (B3) only need to tell the builder which sides reach a wall. Whatever
the structure above (an overpass or a bombed-out building), the running surface is a flat slab with lamps
on every lane seam, nothing hangs below it, and its far end carries the orange band
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
- *Ceilings from their lanes (task B3).* `MarketCeilings` builds every kind (a building bridging the
  street, an overpass, a merchant ship, a floating ad) from the ceiling's collision box and lane
  seams, so a ceiling over fewer lanes just builds narrower; only a full-width ceiling becomes a
  building bridging the street. `mesh_for(kind, ...)` builds a given kind directly.
- *Decorative signs* (neon, painted blade signs, ad boards, casino bulbs) never sit below
  `decor_min_height` (8 m) and never wear the striped frame, which is reserved for hazard signs.
- *Futuristic and worn* (GDD §5): `shopfront.gdshader` draws cladding, rounded smart-glass windows,
  roller shutters and grime; `MarketFacades` adds air-conditioning units, drone racks, cable trays,
  glass balconies, rooftop dishes and masts, and cables across the street (the machinery's faces
  use `PAT_TECH`), all above the wall-run band, which the suite checks stays flush. Dust on roofs,
  awnings and ledges comes from `kit_market.gdshaderinc` (`market_dust`, scaled by the skin's
  `wear`).

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
lists them.

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
heads (task P2), with scanlines, soft static and a slow rolling bar, looping through a screen-head
face, the chosen emblem (`CultEmblem`, faded out below about 24 pixels) and rings converging on a
point, one at a time. Rules for every skin: keep it the same broadcast (vary only how many screens
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
facade shader's window rectangles so the TV's room covers a window exactly). Neither puts a screen in
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
    trim that shines by its own light). The builder stores vertex colours in linear space; on the
    Compatibility renderer, which works in sRGB space, the shader converts them back (as
    `kit_common.gdshaderinc` does for the mesh kit). `cyborg_body.gdshader` doesn't yet, so the
    cyborgs show darker and more saturated on the web than on Forward+ (left for P2, which rebuilds
    them).
  - **Colour rule:** the player's only glow on the base model is its soft copper (`PlayerSuit.GLOW`);
    `test_avatar` keeps it and the effects built from it at least 0.3 from every skin's hazard colours
    and enemy fire on the hue and saturation wheel, and power-up looks never use it.
- **UI:** a theme built in code (`scripts/ui/theme/`: `UiStyle` in `data/ui/ui_style.tres`,
  `UiTheme`), code-drawn icons (`scripts/ui/icons/`) and a widget kit (`scripts/ui/widgets/`). Screens
  (`scripts/ui/screens/`) extend `ScreenBase`; the HUD is `RunHud`. Orbitron is for titles and Exo 2
  for text and numbers. On the HUD, draw icons from `IconFactory.texture()` (cached, tinted with a
  modulate colour) rather than `IconFactory.draw()`: every polygon or polyline command costs its own
  draw call every frame, and the HUD's icons alone were once 220 of about 370.
- **Audio:** `SfxLibrary` maps sound names to `assets/sfx/*.wav` (volumes in
  `data/audio/sfx_library.tres`); `Music` plays `assets/music/`. Both are generated by code in
  `tools/asset_gen/` (`tools/godot.sh sfx` / `music`).

## Campaign, bosses and cinematics

`Campaign` lists `ZoneDef`s; each built zone contributes steps: optional intro cinematic, its
levels, optional boss-intro cinematic, the boss, optional outro cinematic. Step ids (`city/1`,
`city/boss`, ...) key the save file, so they never change. Difficulty comes from a campaign-wide curve
plus each level's `difficulty_bias`; `enemy_scaling` runs 0 → 1 across the campaign.

The campaign (GDD §5) has six zones, with ids other tasks rely on: `city`, `gangland`,
`marketplace`, `corporate`, `dead_zone` and `golden`, with 3, 3, 2, 2, 2 and 3 levels in
`data/levels/<zone id>_<n>.tres` (Golden 3 is the Golden Palace). Every zone has intro and outro
cinematic slots (the City also a boss intro) and a boss slot from GDD §10's roster. A zone's music
track is named after its id; a track the music library doesn't have yet is skipped quietly and the
menu music carries on. Only the City is in the web demo. Placeholders (all DESIGN-TBD): the curve
runs 0.1 → 0.9 over the 15 levels, with Golden 2 the peak and Golden 3 a little below it; level
lengths run 110–150 s and add up to 35 minutes.

**The schedule** (GDD §5) is each level's `features` list, in the order the campaign introduces them:
a feature once introduced stays in every later level, bar the exceptions the design gives (screeches
come from manholes only in street zones and from wall vents, `screech_vents`, elsewhere, with none in
Marketplace 1; the Buzz Overdrive appears in Corporate and the Dead Zone only; the Tithe Collector
skips the Dead Zone). Each level introduces its new features at starts of their own
(`feature_starts`, see Late starts under The generator; City 1's cyborgs come late in the level).
`test_campaign` holds the schedule table and its exceptions, and checks that every level has each
of its features at 3, 5 and 6 lanes, on its own seed and over a seed sweep (Every feature appears,
under The generator). Features of enemies and mechanics still
to be built (`LevelConfig.PLANNED_FEATURES`, with the wall fences' `wall_fences` and
`wall_fences_partial`) are listed already and do nothing until their code and patterns exist.

A `BossDef` or `CinematicDef` with an empty `scene` shows a placeholder card, which the player
continues past. A cinematic is a scene whose root extends `Cinematic` (emit `finished`, support
`skip()`); a boss is built on the boss framework (Bosses, below). Every boss slot is still a
placeholder; the slots hold the phases GDD §10 gives each designed boss and its armor-rule delay. A
fight still being built names its scene in the slot's `preview_scene` instead of `scene`: the
campaign keeps the card, and debug builds play the fight with `--boss=<boss id>` as quick play
(`BossDef.preview()`), so nothing is recorded. The City's Floating Head is one until its last step
(E1d) moves it to `scene`.

## Bosses

A boss fight (GDD §10) is a run like a level's, so it plays like the runner: the same controls,
camera, movement, HUD, power-ups, damage rules, pause, hints, death flow (revive offer → summary →
shop → retry) and debug tools. `App.start_boss()` builds its `RunContext`: `boss` set, `config` the
boss's arena (`Campaign.configure_boss`: the arena config with the lane count, the tier's difficulty
bonus, the zone's enemy scaling and skin), a tuning that never speeds up, and the loadout plus
`BossDef.granted_items` (`Loadout.grant`: granted charges never cost stock). LevelRun then:

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
| `scripts/bosses/floating_head/`, `scenes/bosses/floating_head.tscn`, `data/bosses/city_boss*.tres` | the Floating Head, the City's boss (see below; `./play.sh --boss=city_boss` while it's a preview) |

- **The arena** (`BossArena`): the generator plans `BossDef.arena_laps` laps from the boss's arena
  config (one lap's seed, features, difficulty, pacing and skin; `duration_seconds` is the lap's
  length), each from its own seed, and the boss script may shape each one (`_plan_lap`: set pieces,
  a train's carriage gaps). The fight cycles through them, and the next lap joins the track a whole
  lap ahead through `TrackBuilder.extend_layout()`, so the track keeps going for as long as the fight
  lasts and is the same on every attempt. Nothing in it ramps up, and it carries no credits
  (DESIGN-TBD). During the fight, `arena.add_pieces()` adds track pieces (holes, fences, pads with
  ceilings, ramps, signs, enemies) past `stream_from()`, the end of the built track; they're built and
  brought in like the rest. `floor_clear`, `hole_between`, `live_fence_between`, `ceiling_between` and
  `pieces_between` answer questions about the track.
- **Props** (`encounter.props`): things placed within sight, with the track's collision layers and the
  zone's looks, freed once passed: `fence` (normal fence rules; it can flicker in first, and a boss
  may move it), `block` (solid; the player can't switch into it), `pad` and `ceiling`, `block_wall`
  (takes a stretch of wall away), and the red floor warnings `lane_warning` and `circle_warning`
  (steady with Reduced flashing; `warned(lane, from, to)` says where they are, and pickups keep off
  them).
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
  splash never counts. A hit never takes the boss past the end of the next phase, so every phase gets
  played. Each phase begins with its intro (`intro_seconds`: the boss can't be hurt and doesn't
  attack), then its pattern.
- **No escalation** (GDD §10): the run speed never rises in a fight, the arena doesn't ramp, and a
  boss script times its pattern only from its phase (`pace()`), so a pattern the player can't beat
  keeps cycling the same way; `test_bosses` checks it on the test boss.
- **The checkpoint**: a phase marked `checkpoint` stores where a retry resumes
  (`RunContext.boss_resume`: the phase, and the fight time, score and weapon damage so far);
  `RunContext.retry()` keeps it, starting the step afresh doesn't. `--phase=N` starts there in reviews.
- **The win**: the time bonus and the defeat score go to the ScoreKeeper, the parts are defeated, and
  LevelRun ends the run after a short outro. `RunResult.from_boss` pays the collected credits plus
  `payout_credits`, and gives the stars from the par times; the App records it as the step's record
  (best score, best time, stars) and submits the boss leaderboard, `boss/<boss id>/<tier>` (none in
  the web demo). Its results and level-select tile show the boss's stars and bests like a level's.
- **Pickups** (see Pickups): `armor_pickup_due(reason)` follows GDD §10's standard armor rule, at the
  start of the final phase and `armor_delay_min`–`max` seconds after the player's armor or shield
  breaks, at most `armor_pickups_per_phase` per phase, and each time the encounter offers an armor
  pickup (`_on_armor_pickup_due`, which a boss may override to place it its own way).
  `offer_pickup(item, at, lane)` offers an armor, shield or grapple pickup of the boss's own (GDD §10:
  a section of floor that spawns one; the test boss offers a shield in its second phase), and
  `phase_started` and `protection_broken` are there to time them. The win clears every pickup, and
  nothing is offered after it.
- **The light**: `set_light_level(level, seconds)` fades the environment's ambient and sky light and
  the sun, never below `MIN_LIGHT_LEVEL`; glowing things keep their colours, and the light returns
  with the fight.

**To build a boss:** a script extending `BossEncounter` as the root of a scene in `scenes/bosses/`,
parts extending `BossPart`, a tuning resource of its own in `data/bosses/<id>_tuning.tres`, and the
slot's `BossDef` filled in (scene, phases, arena, numbers). Override the hooks it needs:
`_plan_lap`, `_build_boss`, `_on_phase_started` / `_intro_tick`, `_on_pattern_started` /
`_pattern_tick`, `_on_weak_point_hit`, `_on_part_defeated`, `_on_part_emp`, `_on_phase_ended`,
`_on_defeated` / `_defeated_tick`, `_on_armor_pickup_due`. Every attack needs its visual and audio
warning (a floor warning from `props` also keeps pickups away), random choices come from `rng`, and
time from the physics step. The test boss (`TestBoss`) is a small example.

**The Floating Head** (GDD §10, task E1; built so far: E1a, the ship and face, the entrance, the
bombing run and the reveal), in `scripts/bosses/floating_head/`:

| File | What |
|---|---|
| `floating_head.gd` (`FloatingHead`) | the encounter: each phase's intro (the first is the entrance, overhead from behind; later ones rise), its bombing run if it has one (`run_seconds(phase)`), then the descent in front of the runner (the first time, the reveal: the face powers on) and the face-off (a placeholder hover until E1b). The ship's `pose` is kept relative to the runner (sideways, belly height, stern ahead), so nothing depends on how long the fight has lasted. `sound()` plays and logs every warning |
| `floating_head_body.gd` (`FloatingHeadBody`) | the body part: the model and its moving parts (face screen, jaw, searchlight gimbal, bay doors, weak-point covers), a solid hull hitbox, three weak points on the crown and the crown's top surface (both off until it's pinned, E1c: `set_weak_points_enabled`, `set_top_solid`), and the face's state (`screen_power`, `anger`, `eye_charge`, `glitch`) |
| `floating_head_model.gd` (`FloatingHeadModel`) | the low-poly meshes, built in code from a `Shape` sized to the street (MeshKit layers merged into a few surfaces: about 13 surfaces and 11k vertices), and the bomb |
| `floating_head_bombing.gd` (`FloatingHeadBombing`) | the searchlight and the bombs: the lock (the warning: red light, `circle_warning`, lock sound, the bomb falling with its whistle), the fairness rules (`plan`, `fair`, `escape_lane`), and pooled blast hitboxes (enemy attacks) that keep clear of a wall runner |
| `floating_head_face.gdshader`, `floating_head_light.gdshader` | the face screen (unshaded and procedural: the same on every renderer; still with Reduced flashing) and the searchlight's beam and spot |
| `floating_head_tuning.gd`, `data/bosses/city_boss_tuning.tres` | its numbers (F6 in its fight) |
| `data/bosses/city_boss_skin.tres` | its arena's City look: the City's skin without the towers' big screens hung out over the street, where the ship flies |
| `tools/showcase/floating_head_showcase.tscn` | close-ups and scripted runs for reviews (`--scenario=model/stern/below/entrance/bombing/reveal`) |

**How the designed bosses fit** (GDD §10; each is a later task):
- **Floating Head (E1b–E1d):** eye-laser sweeps are attack hitboxes on the part, their warning the
  face's `eye_charge`; the cyborg drop is `spawn_enemy("cyborg", ...)` from the jaw. The marked towers
  are laid out on each lap (`_plan_lap`), and the fallen tower is a surface (`add_surface`) or a ramp.
  The weak points and the crown's top are live only while it's pinned; phase 3's pad and the ship's
  underside are `arena.add_pieces()` (or `props.pad` and `props.ceiling` within sight);
  `weapon_share_cap` 0.34 keeps weapons to one stomp. E1d adds the propaganda voice and slogans and
  the defeat (the face's `glitch`), and moves the scene from `preview_scene` to `scene`.
- **Sewer Swarm (E4):** 4–5 clusters are parts with health of their own and `is_swarm` (MultiMesh
  crowds drawn by the part), moving ahead of and behind the player (parts never retire); baiting one
  into a live fence or a hole is the boss script's check (`arena.live_fence_between`,
  `hole_between`) then `part.defeat(&"fence")`, and `_on_part_defeated` deals `hit_damage()`. The
  swarm on a wall is `props.block_wall`, one side at a time. The Host is the body part with three
  weak points.
- **The House:** its reels are a telegraph; cherry bombs are `circle_warning`s and blast hitboxes,
  the lightning a `props.fence` moved across the lanes, gold blocks `props.block`. The 7 buttons are
  spots the boss script checks against the player's surface, lane and distance (a wall button needs
  wall fences, B5; a ceiling button a pad and ceiling, and Barnacle Turrets through `spawn_enemy`,
  C1). The jackpot's hopper is a weak point switched on after all three buttons; its credit fountain
  needs credits placed during a run, which the credit field can't do yet (shared with the Tithe
  Collector's burst, B6/C5).
- **Hostile Takeover:** the train is the arena: an arena config whose patterns (a boss feature they
  `require`) cut every lane at the carriage gaps, and a train skin on the arena config; couplings are
  weak points on a part placed over each gap. Carriages breaking away behind the player are looks.
  The gunship is a part whose belly is a ceiling (`add_surface(..., true)`); the Buzz Overdrive
  (C2) is `spawn_enemy` with its planned cut, which needs B4's floors turning into gaps during play.
  The docking clamps are phase 3's three hits.
- **Sleep Taker:** a body part `immune_to_weapons`; fence generators come from the arena (the
  `generator` feature) or `spawn_enemy("generator", ...)`; a destroyed one's EMP reaches the part
  (`_on_part_emp`: `damage(hit_damage(), &"emp")`). Lights out is `set_light_level`; ceilings (pads)
  are the refuge from the big slashes, which can't reach them.
- **The final villain:** two stages, the second a `checkpoint` phase, so a death there restarts at the
  second stage.

## Economy and saving

`Profile` (`scripts/app/profile.gd`) keeps earned and purchased credits apart (net worth = earned,
unspent), item tiers and stock, equip toggles, records per difficulty tier, settings and stats.
`SaveService` writes it to `user://profile.json` (with a backup). `Loadout` is what one run carries:
owned, switched-on items; one charge of each breakable per attempt.

## Platforms and build flavors

`BuildFlavor` (`full_pc`, `full_mobile`, `web_demo`) comes from export feature tags (or
`--flavor=` for testing). `Platform` (autoload) is the only way to reach ads, purchases,
leaderboards, achievements, store links and cloud save; `StubBackend` serves the editor, tests and
the web demo until the real plugins are chosen (risk test R3).

## Tests

`tools/godot.sh test` runs every `tests/suites/test_*.gd` (a `TestSuite`); `--suite=<name>` runs
one. `RunSim` (`tests/helpers/run_sim.gd`) runs a Player over a hand-built layout (`run()`), or a
full RunWorld (`build_world()` + `step_world()`); with `trace` on it records the player after every
physics frame (position, height, speed, surface, lane, lean). `SkinSuite` (`tests/helpers/skin_suite.gd`) holds
the checks every zone skin must pass, and helpers to inspect what a skin builds over a whole level
(`visit_level()`, `rects_of()`, `under_hazard()`). `LayoutChecks` (`tests/helpers/layout_checks.gd`) holds the
fairness checks for generated layouts (the generator suite runs them over many seeds, the campaign
suite over every campaign level at 3, 5 and 6 lanes, the enemy suites over their own levels), among
them `check_ceilings` (GDD §3: pads that can be stepped on, safe landing zones, and a floor route under
every ceiling without its pad, found by `FloorRoute`, `tests/helpers/floor_route.gd`), and finds a
feature's pieces in a layout with the generator's own `LevelGenerator.feature_positions()`; a task
that adds a new kind of piece extends it (and `FloorRoute`'s cells, if the piece is on the floor), or
gives its rules script `positions()`. `test_enemy_director` checks the turn-taking between big attacks
with scripted test enemies (`tests/helpers/turn_dummy.gd`) and over simulated runs of campaign levels,
watched by `tools/measure/attack_watch.gd` (see Review tools). `DummyBoss` (`tests/helpers/dummy_boss.gd`) is a boss
for framework tests, with `make_def()` for a BossDef from a list of phases; `test_bosses` runs fights
in bare worlds and, with the test boss in the City's slot, through the App. `test_pickups` checks
pickup placement against the rules as it writes them itself, over hand-built cases and generated
tracks at 3, 5 and 6 lanes, and the armor rule end to end on the test boss. `test_floating_head`
runs the Floating Head's fight in bare worlds at 3, 5 and 6 lanes with a runner who dodges each lock
(and one who doesn't), and rechecks its bombs' fairness from the arena's layout. The runner frees
anything a suite leaves in the tree, gives suites a fresh, unsaved profile, reports a suite that fails
to load, and ends a stuck run after 600 s of real time.

## Review tools

Scenes in `tools/showcase/` show one part of the game up close for visual review (not part of the
game): the avatar (`avatar_showcase`: every pose, power-up and concept-sheet view, front, back and
side; `avatar_run_review`: a scripted run through the game camera on any zone's skin, with any
power-up look), ramps and walls (`ramp_wall_review`: a ramp launch with the credits along its wall
run, and blocked wall entries at a low and a high sign, through the game camera or a close one),
the enemies (`enemy_showcase` for the cyborg family, `octodog_screech`,
`drone_truck_showcase`, `bad_dream_showcase`), a boss (`floating_head_showcase`), the UI kit, the
screens, a zone skin (`skin_review`: any skin from fixed spots, including close-ups of the cult's feed
screens and emblems a skin lists, or a scripted run with a ceiling ride and a wall run), and comparison
sheets for an open design choice (`cult_emblem_sheet`, D7). Each script's header lists its options. Render
frames on the Compatibility renderer (the web and low-end Android path) with `--write-movie`, as in
`CLAUDE.md`.

`tools/measure/big_attacks.gd` measures the big attacks (GDD §9, "Big attacks take turns") over
simulated runs of the campaign's levels at 3, 5 and 6 lanes, with `GameRules.big_attacks_take_turns` on
and off: a god-mode runner in the middle lane, stomping every host it passes, while the enemies play as
in the game. It reports the time big attacks of different types overlap, how many of each kind came, and
how long attacks waited for their turn (`godot --headless --fixed-fps 60 -s
res://tools/measure/big_attacks.gd -- --levels=gangland/3 --lanes=3,5,6 --out=build/measure/x.json`; the
whole campaign takes about ten minutes). `attack_watch.gd` does the watching from the enemies' own states
and the live shots, never from the turn-taking code, and hashes each run's event log, so two builds (or
the switch off and a build without the rule) can be compared run by run.
