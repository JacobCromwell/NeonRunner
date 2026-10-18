# Architecture: Bosses: the framework, building a boss, how the designed bosses fit

One part of the architecture notes; `docs/ARCHITECTURE.md` is the index of every part and topic.

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
| `scripts/campaign/boss_def.gd`, `boss_phase.gd` | a boss's data: its slot, health, weapon cap, phases (share of health, big hits, pace, checkpoint, intro), arena, tuning, music, rewards, the star rule (`star_rule`: par times, or the hits taken) and its par times, the armor rule |
| `scripts/bosses/boss_encounter.gd` | the fight: health and phases, damage, the checkpoint, the armor rule, the light; helpers and hooks for boss scripts |
| `scripts/bosses/boss_part.gd` | a piece of the boss in the world: an Enemy the director runs (claw-immune, the dash passes, weak points, surfaces) |
| `scripts/bosses/boss_arena.gd` | the fight's track: generator laps joined ahead for as long as the fight lasts; `add_pieces()`; track queries |
| `scripts/bosses/boss_props.gd` | what a boss places within sight: fences, blocks, pads, ceilings (over a lane range, or lane by lane), roofs, a wall taken away, floor warnings; all but the wall at a height (a raised floor) |
| `scripts/ui/widgets/boss_bar.gd` | the HUD's boss bar, with a marker at each phase's end and a white segment draining after each hit (held a moment, but not while the health runs down steadily: `BossEncounter.health_runs_down`) |
| `scripts/bosses/test_boss*.gd`, `data/bosses/test_boss*.tres`, `scenes/bosses/test_boss.tscn` | the test boss, outside the campaign (`./play.sh --boss=test_boss`) |
| `scripts/bosses/floating_head/`, `scenes/bosses/floating_head.tscn`, `data/bosses/city_boss*.tres` | the Floating Head, the City's boss (see below; `./play.sh --boss=city_boss` or `--level=city/boss`) |
| `scripts/bosses/sleep_taker/`, `scenes/bosses/sleep_taker.tscn`, `data/bosses/dead_zone_boss*.tres` | the Sleep Taker, the Dead Zone's boss (see below; `./play.sh --boss=dead_zone_boss` or `--level=dead_zone/boss`) |
| `scripts/bosses/the_house/`, `scenes/bosses/the_house.tscn`, `data/bosses/casino_boss*.tres` | The House, the Casino's boss (the Marketplace's until task K2; see below; `./play.sh --boss=casino_boss` or `--level=casino/boss`) |
| `scripts/bosses/hostile_takeover/`, `scenes/bosses/hostile_takeover.tscn`, `data/bosses/corporate_boss*.tres` | Hostile Takeover, the Corporate zone's boss (see below; `./play.sh --level=corporate/boss`) |
| `scripts/bosses/sewer_swarm/`, `scenes/bosses/sewer_swarm.tscn`, `data/bosses/gangland_boss*.tres` | the Sewer Swarm, Gangland's boss (see below; E4a and E4b: the campaign plays it after Gangland 3, `./play.sh --boss=gangland_boss`) |
| `scripts/bosses/golden_convergence/`, `scenes/bosses/golden_convergence.tscn`, `data/bosses/golden_boss*.tres` | The Golden Convergence, the Golden Zone's boss and the final villain (see below; `./play.sh --level=golden/boss` or `--boss=golden_boss`) |
| `scripts/bosses/mecha_guppy/`, `scenes/bosses/mecha_guppy.tscn`, `data/bosses/beach_boss*.tres` | Mecha Guppy and Captain Cogs, the Beach's boss (see below; `./play.sh --level=beach/boss` or `--boss=beach_boss`) |

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
  **At a height** (task E5e-a, for GDD §10's climb): fences, blocks, pads, ceilings and the floor warnings
  take an optional `height`, the floor they stand on (0, the street, as always; a roof's top), and are
  placed as on the street that much higher; a ceiling hangs `ceiling_height` over its floor. `ceiling` takes
  an optional lane range (`Vector2i(first, last)`, every lane by default: `ALL_LANES`), and
  `ceiling_lanes(start, ends, height)` builds a ceiling whose lanes end at their own distances (the lanes
  that lead up run further), one section per run of lanes ending together, each with its far end's band.
  `roof(lanes, start, end, height)` is a raised floor's top over a lane range (a box on the floor layer,
  reaching down to the street unless given a `depth`; no hazard, no lane blocker, no look but an optional
  grey box: the boss adds its look and whatever its sides and front must do). `warned(lane, from, to,
  height)` asked at a height counts only the warnings on that floor (within `WARNED_HEIGHT`). The runner
  rides a ceiling at its own height and lands on a roof at any height (Damage and interactions: Ceilings
  at any height, and Falls); a boss that raises the floor also sets `Player.floor_base` as the runner climbs,
  its grapple hook (`_grapple_save`) and the climbing camera (`RunWorld.camera_climbs`).
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
  `payout_credits`, and gives the stars by the boss's `star_rule` (below); the App records it as the step's record
  (best score, best time, stars) and submits the boss leaderboard, `boss/<boss id>/<tier>` (none in
  the web demo). Its results and level-select tile show the boss's stars and bests like a level's.
- **Stars** (`BossDef.stars_for(won, seconds, hits_taken)`, `star_text()`; task N2, the owner, October 18, 2026: every star
  has to be earnable): none without a win, one for winning, then by the boss's `star_rule`: `TIME` (every boss so far; GDD §10,
  proposed): two and three for a fight under `two_star_seconds` and `three_star_seconds` (`fight_time()`: frozen at the defeat,
  with what a checkpoint carried); or `HITS` (DESIGN-TBD, item 1013; no boss uses it yet, flip it in the def's
  data): three for at most `three_star_max_hits` (0) protection hits taken in the fight, two for at most `two_star_max_hits`
  (2), counting the armor and shield blocks the run's `ScoreKeeper.blocked` holds plus each revive used
  (`RunContext.revives_used`: a revive continues the same fight after a hit nothing blocked, so a revived death can't earn three
  stars; the sum is `RunResult.stats["hits_taken"]`; a death without one restarts the fight, a fresh count). `RunResult.from_boss` passes both; `ResultsScreen.star_text` lists the rule under the
  stars (the par times, or "3 stars: no hits taken · 2 stars: 2 hits or fewer"). A `HITS` boss with a checkpoint (the Golden
  Convergence) would also need the hits so far carried in `RunContext.boss_resume` like the time (`BossEncounter`'s checkpoint
  and resume: not done, no boss needs it). The par times are the clean fights the suites' bots win (`reaction` 0.35 s, no god
  mode) plus a margin; measured by task N2 at the campaign's lane count (5) and speed, with every lane count's slowest:

  | Boss | Three stars / two | Clean fight (5 lanes; 3 and 6) | Margin | What the player controls |
  |---|---|---|---|---|
  | Floating Head | 110 / 150 s | 100.6 s (113.9; 114.0) | 9.4 s | a missed stomp window costs 13-20 s (5 lanes: one 113.9 s, two 133.9 s); the rest scripted (bombing runs, the face-off's attacks) |
  | Sewer Swarm | 115 / 150 s | 104.3-104.7 s at every lane count and speed | 10.5 s | nothing but missed chances: 14.6 s each (one a phase 133.8 s) |
  | Sleep Taker | 150 / 190 s | 139.0 s at both speeds | 11 s | nothing but missed chances: 26.7 s a generator let go |
  | Mecha Guppy | 159 / 182 s | 141.1 s at 23.8 m/s (141.1-144.7) | 17.9 s | baiting: 6-8 s per missed bait (never baiting 192.9-214.6 s); phase 3's 16 bombs run on the script, 56-61 s |
  | The House | 86 / 108 s | 81.7 s at 23 m/s (80.4-81.9) | 4.3 s | the script (9 opening spins, 27 strikes): 80.4-81.9 s across lane counts and speeds; its attacks wait while the runner goes for a button |
  | Hostile Takeover | 74 / 96 s | 68.6 s at every lane count and speed | 5.4 s | nothing but missed chances |
  | Golden Convergence | 238 / 308 s | 220.2 s at 25 m/s (217.6-220.2) | 17.8 s | the script, a little by the runner's distance (229 s at 18 m/s) |

  So no bar is above what a clean fight wins, at the shipped lane count (the Floating Head's 110 s is under 113.9-114.0 s at 3 and 6 lanes, which
  don't ship: item 1014). For a scripted boss the time can't be beaten, only
  matched: three stars means no chance let go by, and the margin only covers what the player controls.
- **Pickups** (see Pickups): `armor_pickup_due(reason)` follows GDD §10's standard armor rule, at the
  start of the final phase (`&"final_phase"`) and `armor_delay_min`–`max` seconds after the player's
  armor takes a hit (`&"armor_hit"`: the Player's `armor_hit` or `armor_break` event, so a hit the
  upgraded armor survives counts as well as its last; `_on_movement_event`), at most
  `armor_pickups_per_phase` per phase, and each time the encounter offers an armor pickup
  (`_on_armor_pickup_due`, which a boss may override to place it its own way). A shield break brings
  none (owner, October 14, 2026; task I9) and leaves the phase's pickup for the armor: `_on_item_used`
  only reports the break (`protection_broken`). With
  `BossDef.armor_when_unprotected` (E1e, DESIGN-TBD; on for every built boss but the test boss) a phase
  that begins with the player's armor down and no shield (the free armor still coming back after a
  break) counts as an armor hit at its start (`&"unprotected"`; `player_protected()`: armor up or a
  shield held, or an armor pickup due, on the track, waiting for a spot or held back by the boss,
  `armor_pickups_waiting()`), so no phase starts unprotected without a pickup on its way; a shield held
  as it begins still counts as protection, though its break brings none (DESIGN-TBD,
  item 825). No boss script answers a hit or a break itself; the rule is the
  framework's alone.
  `offer_pickup(item, at, lane)` offers an armor, shield or grapple pickup of the boss's own (GDD §10:
  a section of floor that spawns one; the test boss offers a shield in its second phase), and
  `phase_started` and `protection_broken` are there to time them. The win clears every pickup, and
  nothing is offered after it.
- **Hints**: boss-specific catalog triggers (`boss:<boss id>/<key>` in `data/hints/hints.json`)
  are collected for the level introduction, once per profile, including the Floating Head's
  `/ramp`, `/wall` and `/ceiling` routes. `hint_due(key)` remains a legacy encounter cue, but
  the hint presenter no longer listens to it during the fight.
- **The light**: `set_light_level(level, seconds)` fades the environment's ambient and sky light, its
  fog's light and the sun, never below `light_floor()`, and the scenery's own light with them (the
  `scenery_light` uniform a level's darkness sets: the skins' scenery shaders are unshaded, so dimming
  the lights alone leaves the street and the walls as they were; task E5c-a), never below
  `scenery_floor()`; glowing things keep their colours, and the light returns with the
  fight (the scenery's only if no newer run has set its own). The floors are `MIN_LIGHT_LEVEL` and
  `ZoneSkin.MIN_SCENERY_LIGHT` (0.3) for every boss; a boss may override `light_floor()` and
  `scenery_floor()` from its own data (only the Sleep Taker does: its lights out goes half as dark again,
  task H9). `set_scenery_light(light)` sets the
  scenery's light directly, beyond that range, for a lighting moment of the boss's own (the Sleep
  Taker's grey dawn), and it's put back the same way (task E5c-b).

**To build a boss:** a script extending `BossEncounter` as the root of a scene in `scenes/bosses/`,
parts extending `BossPart`, a tuning resource of its own in `data/bosses/<id>_tuning.tres`, and the
slot's `BossDef` filled in (scene, phases, arena, numbers). Override the hooks it needs:
`_plan_lap`, `_build_boss`, `_on_phase_started` / `_intro_tick`, `_on_pattern_started` /
`_pattern_tick`, `_on_weak_point_hit`, `_on_part_defeated`, `_on_part_emp`, `_on_phase_ended`,
`_on_defeated` / `_defeated_tick` / `victory_over` / `victory_riff`, `health_runs_down` (a timed phase's steady
run-down: the boss bar follows it without the white segment's hold), `_on_armor_pickup_due`, `_grapple_save` (where
the grapple's save and a revive after a fall take the runner; the default leaves them as they are). Every attack needs its visual and audio
warning (a floor warning from `props` also keeps pickups away), random choices come from `rng`, and
time from the physics step. The test boss (`TestBoss`) is a small example. `rng`, the armor pickups' and
the parts' and brought enemies' seeds hash `BossDef.rng_key()`: the boss's id, or its `seed_id`, the id it
had before a move, so a renamed boss makes the same random choices (The House, `casino_boss`, keeps
`marketplace_boss`'s; task K2: it now runs at 23 m/s with enemy scaling 0.5625).

## Bosses (continued)

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
- **The Golden Convergence (E5d, built, see below):** the Golden Zone's boss step plays it; two stages in six phases, stage 2's first a
  `checkpoint` phase, so a death in stage 2 restarts there. Stage 1's golden suit floats out of reach (the
  body part, chipped by weapons up to `weapon_share_cap`), its attacks each a class of its own played one
  at a time from a beat script in its tuning (E5d-a the Helidrone Strafe with its Flying Buttresses; E5d-b
  the Fist Slam, smashing a buttress into a toppled tower's wall through `court.open_wall`, and the Missile
  Barrage; E5d-c the Refill Ship, its caged pad hurling the squadron into the ship, the hit that damages the
  suit; E5d-d The Magnate's chase and the defeat; E5d-e the owner's playtest of stage 2: the Claw Slash, the
  Screen Storm, the arena darker, the stomp's chevrons).
- **Mecha Guppy and Captain Cogs (E5e, see below):** the arena is the boss's own climb: `_plan_lap`
  eats the street in every lane and opens both walls over every lap, and the climb's roofs, pads and huts are
  props built within sight (`BossProps.roof`, `ceiling_lanes`, at a height) on E5e-a's core: the floor base
  (`Player.floor_base`), ceilings at any height, the grapple hook (`_grapple_save`) and the climbing camera
  (`RunWorld.camera_climbs`). Its hits are counted (`weapons_can_end_phase` off, `weapon_share_cap` 0:
  weapons do nothing), each `register_hit()` (a bomb of Captain Cogs' falling into Mecha Guppy's jaws: a bait the
  runner led into a roof's notch, or the fallback's miss into the chasm); the armor rule's pickup goes on the roof
  ahead at its height (`_on_armor_pickup_due`, `PickupField.place`). Phase 3's 16 hits come on the top (task E5e-g: every
  bomb Captain Cogs fires across the deck that gets past the runner flies on into Mecha Guppy), and `victory_over` holds the
  results while Mecha Guppy leaps, eats Captain Cogs and swims away (`victory_riff` off: the leap plays the riff after
  the gulp).
