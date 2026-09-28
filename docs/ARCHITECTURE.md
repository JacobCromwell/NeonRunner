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
| `data/tuning/feature_recency.tres` (`FeatureRecency`) | the campaign's recency curve: how a level's pick weights follow how recently the campaign introduced each feature |
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
every attempt at a seed plays out the same way. Setting `is_host` also sets `immune_to_weapons`
(GDD §9.7, decided September 26, 2026): a host is immune to every kind of weapon damage, direct or
splash, the same way a fence generator declares its own immunity (GDD §9.1), so no targeting, no
damage and no health bar; only a stomp, the claws or the dash still kill it, with the host bonus.
Every attack needs a visual **and** audio warning before it can hurt (CLAUDE.md readability rules).
Enemy fire uses the pool's red "enemy_*" looks in every zone. `world.skin.enemy_variant` picks the
zone look: the cyborgs (window cyborgs and hosts too) dress in the zone variant
`CyborgSuit.look_for()` finds for it (see Zone skins for each zone's value, and Characters), and the
other enemies weather by it (`&"scavenger"` weathered, any other value the clean `&"city"` look).

A level uses an enemy only if its `features` list has the type's name (GDD §6: one new thing at a
time), from the feature's start if the level gives it one (The generator). Quick play can add
features: `./play.sh --features=cyborg,drone`. The campaign already lists the enemies still to be
built under the names their tasks must use (`LevelConfig.PLANNED_FEATURES`: `barnacle_turret`,
`buzz_overdrive`, `tithe_collector`, `resonator`, `gilded_sentinel`), so a new enemy's own files are
all it takes to bring it into its levels.

Built so far: cyborg (with its panic variant and hosts), window cyborg, fence generator, hover
truck, Octodog, sewer screech (manholes, and wall vents; `screech_vents` is wall vents only, for zones
whose floor has no manholes),
heli drone, the Cyborg's Bad Dream (released by a killed host, spawned by the director at run
time rather than placed by the generator), and the Resonator (GDD §9.10, the Golden Zone: a golden
broadcast spire hovering far ahead whose red waves roll along the floor across every lane; its model,
`resonator_model.gd`, is built in code, and `resonator_rules.gd` plans each pulse where its wave meets
the player on clear floor). `scripts/enemies/mesh_batch.gd` merges an enemy's low-poly
parts into one mesh per material to keep draw calls down.

**Big attacks take turns through the director** (GDD §9, decided September 26, 2026). The big attacks
of different enemy types never overlap, so the player never has to dodge two at once. The owner may
revert this after playtesting, so it sits behind one switch, `GameRules.big_attacks_take_turns` (on by
default, in the F6 panel); switched off, the game plays exactly as before the rule. The big attacks
(DESIGN-TBD, `docs/questions/r3.md`): the Octodog's charge sequence (its first wind-up until it gives
up), the drone's wind-up and barrage, the hover truck's rev and forward lurch and its cannon's charge
and volley, the Bad Dream's chase, and the Resonator's pulse (its warning until its last wave has
passed the player; DESIGN-TBD, `docs/questions/c3.md`). Small attacks (a cyborg's burst, a window
cyborg's shot, a screech's swipe) and the hover truck's entrance don't take part. An enemy takes part
like this, and the enemies still to come (the Barnacle Turret, Buzz Overdrive, the Gilded Sentinels,
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
  (`OctodogTuning.turn_wait_max`), and keeps every fairness rule it was planned with. Once held it
  keeps asking every frame until its turn comes, whether or not its stretch is clear by then, and if
  the wait made it miss its planned stretch, the window keeps moving on until the stretch ahead is
  clear again (within the same limit), so waiting for its turn never costs it its charges. The
  Resonator's planned pulses do the same: a pulse held for another type's turn, or for clear floor
  where its wave would meet the player, moves the rest of its visit on; after
  `ResonatorTuning.turn_wait_max` spent waiting for other attacks (waiting for clear floor doesn't
  count) it drops its remaining pulses and leaves, never before its first.
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
`feature_active(feature, at)`, `feature_share_at(feature, share)`, `ramp_launch(ramp)`, and for a level
paced in bursts `quiet_at(at)`, `stretch_end(at)`, `burst_index(at)`, `quiet_stretches()`,
`burst_spans(lo, hi)`, `prefers_bursts(feature)`, `burst_spot(rng, lo, hi, feature)` and
`pacing_pools(spots, feature)`, plus
`layout`, `config`, `tuning`, `speed`, `jump_distance` and `zones` (the level's `CeilingZones`).
`pick_weights(patterns, difficulty, at)` gives the weights a pick draws from (the static
`pattern_kind(pattern)` and `enemy_count(pattern, lanes)` say how the recency curve counts a pattern),
and `picks` lists the patterns the last build placed (id, features, spot, length, due or not), for
tests and `tools/measure/level_shape.gd`. Pattern format: `data/patterns/README.md`.

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
nothing clears it afterwards; the Resonator rules after every feature that puts things on the floor or
plans a big attack, so each pulse is planned on the level's final floor and off every Octodog's run).
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
  `guarantee_one_wave` and `guarantee_one`), and a host, an Octodog and a Resonator in a level with
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

Skins: `CitySkin` (Zone 1, the Neon City), `GanglandSkin` (Zone 2), `MarketplaceSkin`
(Zone 3, the Marketplace), `CorporateSkin` (Zone 4, Corporate), `DeadZoneSkin` (Zone 5, the Dead Zone)
and `GoldenSkin` (Zone 6, the Golden Zone). `GreyboxSkin` is the fallback for a zone without its own
look (every zone has one now). A
zone's skin lives at `data/skins/<zone id>_skin.tres` (`--skin=<zone id>` in quick play) and is set in its
`data/zones/<zone id>.tres`; a level's own `skin` wins over its zone's (the Golden Palace, Golden 3,
may get its own). The real skins build on the mesh kit (`scripts/world/meshes/`): `MeshKit` has
shared builders for hazards, triggers and environments, and `MeshLayer` batches a chunk's geometry.
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
  wall face the skin saw last (`wall_section` runs before a chunk's ceilings). Every underside is flat
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
- *The calm band.* Every building face is flush from the canal to `band_top` (7 m): stone with only the
  gold wall-run height marks, nothing vent- or niche-like (vents are the Screech's lairs, niches the
  Sentinels'), nothing sticking out. The entablature above carries the palaces' statue ledge.
- *The statue kit* (`GoldenStatue`, for the Gilded Sentinels, task C4). Statue space: the pedestal's
  foot at the origin, facing +Z. Poses are dictionaries of joint angles (`shoulder_r/l`, `elbow_r/l`,
  `grip`, `head`, in degrees; missing keys take `REST`); `POSES` names the decorative `guard`, `vigil`,
  `salute` and the swing's `raise` and `strike`, and `blend_poses(a, b, t)` mixes two. For decoration,
  `mesh(pose)` is one cached template to append into a wall mesh (no draw call of its own). For a live
  Sentinel, `rig(parent, pose)` builds it as nodes and returns them by name (`root`, `body`, `pedestal`,
  `head`, `eyes`, `arm_r`, `arm_l`, `elbow_r`, `elbow_l`, `grip`, `halberd`): turn the pivots with
  `apply_pose(nodes, pose)` or directly, and give `eyes` (a MeshInstance3D) a glowing red material of
  its own. `niche(width, height)` is the niche it stands in, proud of any wall. The skin's kit is
  `GoldenSkin.statues()` (its gold and solid material). Decorative statues stand only on the ledge, at
  `statue_min_height` (8.8 m) or higher; `GoldenSkin.statue_spots()` lists them.
- *Ceilings from their lanes (task B3).* `GoldenCeilings` builds a golden bridge (a coffered underside,
  a marble face with the emblem's crest, water off some into gilded troughs), a gallery of golden arches
  (only across every lane) or a hover-yacht from the ceiling's collision box and lane seams; over fewer
  lanes a bridge becomes a suspended gallery. Water stays above the underside. `mesh_for(kind, ...)`
  builds a given kind directly.
- *Ceilings under the walls' decorations.* The walls build without knowing where ceilings are, so
  `GoldenFacades.clearance_profile()` declares what they hold out over the street, as (reach, lowest
  height) tiers: the statue ledge, the statues, the gilded frames, the banners, and `OVER_STREET` beyond.
  `GoldenCeilings.headroom()` turns it into how high a ceiling may rise at a distance from a wall:
  arches are flatter over a narrow street (`arch_rise()`), a bridge's face stays under the ledges and its
  rail stops short of the statues, and a yacht near a wall has a lower cabin and no mast. The suite
  checks both sides on streets of 3 to 6 lanes; a new wall decoration extends the profile.
- *Overhead.* Sky bridges between towers 24 m up or more, only where towers tall enough stand on both
  sides; banners hang no lower than `GoldenFacades.BANNER_BOTTOM` (11 m), clear of every ceiling.

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
  (`scripts/ui/screens/`) extend `ScreenBase`; the HUD is `RunHud`. Orbitron is for titles and Exo 2
  for text and numbers. On the HUD, draw icons from `IconFactory.texture()` (cached, tinted with a
  modulate colour) rather than `IconFactory.draw()`: every polygon or polyline command costs its own
  draw call every frame, and the HUD's icons alone were once 220 of about 370.
- **Audio:** `SfxLibrary` maps sound names to `assets/sfx/*.wav` (volumes in
  `data/audio/sfx_library.tres`); `Music` (`MusicDirector`) plays `assets/music/` (files, levels and
  tempos in `data/audio/music_library.tres`), one looping track at a time with crossfades: the menus'
  track and one per zone, named after the zone's id (`ZoneDef.music`). Both are generated by code in
  `tools/asset_gen/` (`tools/godot.sh sfx` / `music`): a track is composed in `track_<name>.gd` with
  `music_song.gd` (stems on a 16th grid that wrap around the loop, and loop-safe effects) and
  `music_instruments.gd`, and a new one is listed in `music_gen.gd` and the library. Tracks are
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
    another key needs its riff remade to match, or removed.

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
quietly and the menu music carries on). Only the City is in the web demo. Placeholders (all DESIGN-TBD): the curve
runs 0.1 → 0.9 over the 15 levels, with Golden 2 the peak and Golden 3 a little below it; level
lengths run 110–150 s and add up to 35 minutes.

**The schedule** (GDD §5) is each level's `features` list, in the order the campaign introduces them:
a feature once introduced stays in every later level, bar the exceptions the design gives (screeches
come from manholes only in street zones and from wall vents, `screech_vents`, elsewhere, with none in
Marketplace 1; the Tithe Collector skips the Dead Zone). The Buzz Overdrive appears from Corporate 1
through the Dead Zone and the Golden Zone, the Golden Palace included (GDD §9.9, corrected). Each
level introduces its new features at starts of their own (`feature_starts`, see Late starts under The
generator; City 1's cyborgs come late in the level), and its newest features get the most picks
(the campaign's recency curve, under The generator). `test_campaign` holds the schedule table and its
exceptions, checks the features' order, and checks that every level has each of its features at 3, 5
and 6 lanes, on its own seed and over a seed sweep (Every feature appears, under The generator).
Features of enemies and mechanics still to be built (`LevelConfig.PLANNED_FEATURES`, with the wall
fences' `wall_fences` and `wall_fences_partial`) are listed already and do nothing until their code and
patterns exist.

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
bombing run and the reveal; E1b, the face-off with its eye lasers and cyborg drop, and the marked
towers that pin it; E1c, the stomp windows while it's pinned), in `scripts/bosses/floating_head/`:

| File | What |
|---|---|
| `floating_head.gd` (`FloatingHead`) | the encounter: each phase's intro (the first is the entrance, overhead from behind; later ones rise), its bombing run if it has one (`run_seconds(phase)`), then the descent in front of the runner (the first time, the reveal: the face powers on) and the face-off until a tower pins it (`begin_pin`: it brakes under the falling tower and lies still on the track, sunk between the trucks until its weak points' sockets are `pin_top_height` up and rolled toward the tower about its crown, `pinned_transform`; the tower breaks behind the weak points as it lands). Then the phase's stomp window (`route`, from `stomp_route(phase)`): `_open_window` switches the weak points and the crown's deck on and the hull hitbox off, and the way up is built in the arena (`_slam_ramp`: the tower's slab, a `FloatingHeadRamp`, in `ramp_lane`; the wall needs nothing; `_light_pads` and `_update_ceiling`: `props.pad` in every lane and a `props.ceiling` that lowers in once the ship is past its end). `_check_window` closes it (`_miss`) when the runner is still on the trucks within `window_release_gap` of its face or past `pass_line()`; a stomp ends the phase instead. Either way it shakes free (`SHAKE`: it lurches ahead of the runner, its deck under a runner still on it until its face has passed them) and rises: to the next phase's station after a stomp (the phase's intro), back in front for the face-off after a miss (`RELEASE`). The ship's `pose` is kept relative to the runner (sideways, belly height, stern ahead) except while pinned, so nothing depends on how long the fight has lasted. The marked towers are planned with each lap (`_plan_lap`: every `tower_spacing`, sides in turn, the track cleared of holes and fences around each) and brought into sight as the runner nears them (`towers_between`, `tower_node`); a tower whose pin would land on a pickup or a dropped cyborg goes by (`pin_zone_blocker`), and armor pickups wait while a pin is under way (`pin_busy`, `_on_armor_pickup_due`). The fairness helpers its attacks share: `escape_lane`, `floor_clear_lane`/`floor_clear_all`, `pickup_near`, `enemy_in_lane`, `ceiling_between` (the arena's ceilings and its window's own: no bomb locks under one, the face-off waits past it). `sound()` plays and logs every warning |
| `floating_head_body.gd` (`FloatingHeadBody`) | the body part: the model and its moving parts (face screen, jaw, searchlight gimbal, bay doors, weak-point covers that swing open with the red domes pulsing out: `weak_open`), a solid hull hitbox (`set_hull_solid`: off while pinned), a weak point over each lane near the crown's middle (generous stomp boxes, `stomp_width`/`stomp_depth`/`stomp_top`) and the crown's deck (a concave shape exactly over the drawn hull, `FloatingHeadModel.deck_faces`), both off until a window opens (`set_weak_points_enabled`, `set_top_solid`; `top_height`, `weak_point_world`), the face's state (`screen_power`, `anger`, `eye_charge`, `glitch`, `jaw_open`, and `look_point` for the eyes to watch the laser's aim), where its eyes and mouth are (`eye_world`, `mouth_world`), and `exclusive_major_attack` (its lasers and bombs take turns with other big attacks) |
| `floating_head_model.gd` (`FloatingHeadModel`) | the low-poly meshes, built in code from a `Shape` sized to the street and its lanes (MeshKit layers merged into a few surfaces: about 13 surfaces and 11k vertices; the weak points over the lanes within `weak_point_reach` of the middle), the bomb, the crown's deck faces, and `ship_transform` (its pitch and its roll about the crown over the weak points) |
| `floating_head_bombing.gd` (`FloatingHeadBombing`) | the searchlight and the bombs: the lock (the warning: red light, `circle_warning`, lock sound, the bomb falling with its whistle), the fairness rules (`plan`, `fair`, `escape_lane`), and pooled blast hitboxes (enemy attacks) that keep clear of a wall runner |
| `floating_head_faceoff.gd` (`FloatingHeadFaceOff`) | the face-off: the phase's attacks wait in line (`faceoff_pattern`; the first that can start fairly goes next) with a drag timed for each marked tower. Eye lasers: the warning (the eyes' `eye_charge` and whine, thin aiming beams with a sweep's aim lines or a drag's aiming spot, then the drag's `lane_warning`), a sweep's twin beams (low: both low, jump them; high: one at the waist and one above a jump's reach, like a gapped fence, slide under them) or a drag down the runner's lane leaving a burning line (keeps clear of a wall runner), each with enemy-attack hitboxes. The cyborg drop: the jaw opens (with its sound and `circle_warning`s where they land), then normal cyborgs from the director (`spawn_enemy`) fall from the mouth onto clear roof and fight. A tower's drag is a bait when the runner is in the outer lane on its side as the warning ends, or the fallback after `fallback_after` misses; either calls `FloatingHead.begin_pin`. Lasers wait while its cyborgs are ahead and share the cyborgs' airspace (`CyborgGun.AIRSPACE_META`) |
| `floating_head_tower.gd` (`FloatingHeadTower`) | a marked tower at the roadside (flush with the facades, its head jutting out over the street above the ship's highest flight so it shows from far along the street; no hitboxes: scenery until it falls): pale concrete with white painted bands and targets, cracks and cold warning lights; the laser's cut glows red-hot as it's clipped, then it topples forward onto the ship (`fall_onto`, `rest_on`), breaks in two as it lands (`break_at`, `tower_mesh`'s sections with torn ends: the lower section drops away), and the rest crumbles away when the ship shakes free |
| `floating_head_ramp.gd` (`FloatingHeadRamp`) | the first stomp window's way up: the tower's broken slab slammed down in a lane (`ramp_length` long, its top end `ramp_lift` above the crown at the face), its top a floor (a convex slab) and its sides a lane blocker down to the trucks where it stands above a step; green chevrons up it; it sinks away when the ship shakes free |
| `floating_head_face.gdshader`, `floating_head_light.gdshader`, `floating_head_laser.gdshader` | the face screen (unshaded and procedural: the same on every renderer; still with Reduced flashing), the searchlight's beam and spot, and the lasers (the beams, the aim lines and the burning line: additive, lifted on the Compatibility renderer; the burn's embers hold still with Reduced flashing) |
| `floating_head_tuning.gd`, `data/bosses/city_boss_tuning.tres` | its numbers (F6 in its fight) |
| `data/bosses/city_boss_skin.tres` | its arena's City look: the City's skin without the towers' big screens hung out over the street, where the ship flies |
| `tools/showcase/floating_head_showcase.tscn` | close-ups and scripted runs for reviews (`--scenario=model/stern/below/entrance/bombing/reveal/faceoff/fallback/missed/pinned/window/mouth`, `--phase=N` for the phase's stomp window) |
| `tests/helpers/floating_head_bot.gd` (`FloatingHeadBot`) | a runner who plays the fight by its warnings, pressing only named actions: dodges bombs and lasers, baits towers, and takes each stomp window's way up (`routes`; `wrong_route` stays on the trucks) (tests and the showcase) |

**How the designed bosses fit** (GDD §10; each is a later task):
- **Floating Head (E1d):** E1d adds the propaganda voice and slogans and the defeat (the face's
  `glitch`; for now a won fight ends in a burst and the ship is gone at once, `_on_defeated`), and
  moves the scene from `preview_scene` to `scene`. `weapon_share_cap` 0.34 keeps weapons to one stomp.
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
gives its rules script `positions()`. The generator suite also checks the recency curve's pick weights
exactly (`pick_weights()`: each kind's share, the caps) and levels paced in bursts; the campaign suite
checks each kind's share at spots all through every campaign level, The Hush and the darker lighting
on every skin. `test_enemy_director` checks the turn-taking between big attacks
with scripted test enemies (`tests/helpers/turn_dummy.gd`) and over simulated runs of campaign levels,
watched by `tools/measure/attack_watch.gd` (see Review tools). `DummyBoss` (`tests/helpers/dummy_boss.gd`) is a boss
for framework tests, with `make_def()` for a BossDef from a list of phases; `test_bosses` runs fights
in bare worlds and, with the test boss in the City's slot, through the App. `test_pickups` checks
pickup placement against the rules as it writes them itself, over hand-built cases and generated
tracks at 3, 5 and 6 lanes, and the armor rule end to end on the test boss. `test_floating_head`
runs the Floating Head's fight in bare worlds at 3, 5 and 6 lanes with a runner who dodges each lock
(and one who doesn't), and rechecks its bombs' fairness from the arena's layout;
`test_floating_head_faceoff` plays its face-off with `FloatingHeadBot` (every laser warned and
escaped without god mode, the cyborg drop, a baited and a fallback tower pinning it) and rechecks
each attack's fairness from the real arena's layout; `test_floating_head_stomps` has the bot take each
phase's stomp window at 3, 5 and 6 lanes without god mode, checks the ways up are physical, missed
windows repeat without escalation, the damage and weapon cap, the armor pickups, the window's ceiling
rules, and plays the whole fight from its entrance to the last stomp. `test_resonator` plays the
Resonator in full worlds on real physics (the warning always before the wave, a jump clearing it at 3,
5 and 6 lanes with its margin measured, walls and the ceiling safe, armor, shield and dash, turns with a
`TurnDummy`, Reduced flashing), checks its rules over many seeds, and plays the real Golden 1-3 layouts
at 3, 5 and 6 lanes, watched by `attack_watch.gd`: no wave meets the runner on a gap or a fence, and no
big attacks overlap. `test_audio` checks
the music files (seamless loops, lengths, tempos, size budgets), the Music autoload's fades, duck and
death dip on its players' levels and the bus's low-pass (headless runs never start a player), and the
run's music hooks through the App. The runner frees
anything a suite leaves in the tree, gives suites a fresh, unsaved profile, reports a suite that fails
to load, and ends a stuck run after 600 s of real time.

## Review tools

Scenes in `tools/showcase/` show one part of the game up close for visual review (not part of the
game): the avatar (`avatar_showcase`: every pose, power-up and concept-sheet view, front, back and
side; `avatar_run_review`: a scripted run through the game camera on any zone's skin, with any
power-up look), ramps and walls (`ramp_wall_review`: a ramp launch with the credits along its wall
run, and blocked wall entries at a low and a high sign, through the game camera or a close one),
the enemies (`enemy_showcase` for the cyborg family: poses, the faces close up, a turnaround, window
cyborgs, and a far view through the run camera where the expressions must read, in any zone's look
(`--variant=`, or ui_left / ui_right live), and every look side by side (`lineup`, front, back, as
hosts or aiming, and `lineup_far` at gameplay distance); `octodog_screech`,
`drone_truck_showcase`, `bad_dream_showcase`, `resonator_showcase`: its model through its warning
and pulse, or a scripted run where it pulses at a runner who jumps its waves), the Golden Zone's statue
kit (`statue_showcase`: every pose, a turnaround, and a live statue rigged in its niche and swinging, as
task C4 would build it), a boss (`floating_head_showcase`), the UI kit, the screens, a zone skin
(`skin_review`: any skin from fixed spots, including close-ups of the cult's feed screens and emblems a
skin lists, or a scripted run with a ceiling ride and a wall run, in a level's darker lighting with
`--darkness=X`), and comparison
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

`tools/measure/level_shape.gd` measures the campaign's shape: for each level at 3, 5 and 6 lanes, on its
own seed and others, each feature's share of the pattern picks, the enemy, host and obstacle counts, the
features that appear only thanks to the every-feature guarantee, and for a level paced in bursts (The
Hush) its quiet stretches against its bursts, with the recency curve on and off and a level's remix
settings on or off (`godot --headless -s res://tools/measure/level_shape.gd -- --levels=dead_zone/2
--curve=on,off`; the whole campaign both ways takes about a minute and a half).
