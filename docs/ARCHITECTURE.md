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
  Track      TrackBuilder: floor/hull collision, obstacles (fences, wall fences, signs), triggers (pads,
             ramps, speed pads), zone doodads, floor cuts (FloorCut: a lane's floor that turns into a hole
             during play), built in 40 m chunks around the player; the zone skin decorates it
  Player     movement on floor, walls and ceiling; protection; receive_hit()
  Boss       BossEncounter, in a boss fight only: the fight and the boss's pattern (its parts are
             enemies, under Enemies)
  Enemies    EnemyDirector: spawns layout enemies as the player approaches, retires them
  Projectiles ProjectilePool: every shot, pooled and swept
  Credits    CreditField: every credit as MultiMesh instances; pickup and magnet
  Pickups    PickupField: armor, shield and grapple pickups a boss offers, placed fairly, pooled
  Effects    RunEffects: particle bursts, debris, glowing lines, camera-shake and hit-stop requests,
             and the shared impact spectacle (kills, blocked hits, hard landings, stomps)
  Score      ScoreKeeper: level score, credits, kills, bonuses, stats, and what thieves hold
  Sounds     PlayerSfx: non-positional sounds (RunWorld.play_sfx / play_sfx_at)
  Powerups   PowerupController, created if scripts/powerups/powerup_controller.gd exists
```

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
    layout, with and without a forced freeze, give the same distance, lane and event log).
  - **Screen shake** (Settings) scales every shake and hit-stop through `RunEffects.shake_scale`
    (`shake()` and `freeze()` both no-op at 0); the field-of-view kick, the lean and the speed lines
    stay on regardless, since none of them snap or strobe.

## Data (tunables live in data, CLAUDE.md principle 7)

| File | What |
|---|---|
| `data/tuning/movement.tres` (`MovementTuning`) | the base run speed (quick play, tests; `REFERENCE_SPEED` and `pace()`, see Pace), jump, walls (and the blocked entry's bump), ramps and speed pads (their boosts share one fade), ceiling, piece sizes, zone doodads' sizes and push, camera, touch |
| `data/tuning/game_rules.tres` (`GameRules`) | lanes per device, death share, invulnerability, the armor (the free armor's hits and wait, the upgrade's per tier, a pickup's extra hit), the window after a theft, stomp, whether big attacks take turns, score, economy, stars |
| `data/tuning/powerups.tres` (`PowerupTuning`) | weapon tiers, claws, dash, magnet, slow time |
| `data/tuning/pickups.tres` (`PickupTuning`) | in-run pickups: where they appear, taking them, the charge cap, the look |
| `data/tuning/feature_recency.tres` (`FeatureRecency`) | the campaign's recency curve: how a level's pick weights follow how recently the campaign introduced each feature |
| `data/tuning/wall_fences.tres` (`WallFenceTuning`) | wall fences (B5): how often, how they pulse, their introduction, and the fairness margins (their sizes are the movement tuning's) |
| `data/enemies/<type>.tres` (`EnemyTuning` subclasses) | per-enemy numbers, early/late pairs for campaign scaling |
| `data/shop/catalog.json` | shop items, tiers and prices (the armor's texts take `{hits}` and `{seconds}`, filled from `GameRules` by `ShopScreen.item_text()`) |
| `data/campaign/campaign.tres` → `data/zones/*.tres` → `data/levels/*.tres` | the campaign; each zone's run speed (`ZoneDef.run_speed`, a level may set its own), each level's pacing, fill pass, zone doodads and credits |
| `data/bosses/*.tres` | bosses (`BossDef`: slot, health, phases, arena, rewards, par times, armor rule), and a boss script's own tuning (`<id>_tuning.tres`) |
| `data/cinematics/*.tres` | cinematic slots (`CinematicDef`: each slot's scene), and the arrival flyover's numbers (`arrival_flyover.tres`, `ArrivalFlyoverTuning`) |
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
    holds plus its jackpot straight into the run's credits (with the `jackpot` sound; what it took off the
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
Enemy fire uses the pool's red "enemy_*" looks in every zone. `world.skin.enemy_variant` picks the
zone look: the cyborgs (window cyborgs and hosts too) dress in the zone variant
`CyborgSuit.look_for()` finds for it (see Zone skins for each zone's value, and Characters), and the
other enemies weather by it (`&"scavenger"` weathered, any other value the clean `&"city"` look).

A level uses an enemy only if its `features` list has the type's name (GDD §6: one new thing at a
time), from the feature's start if the level gives it one (The generator). Quick play can add
features: `./play.sh --features=cyborg,drone`. The campaign already lists the enemies still to be
built under the names their tasks must use (`LevelConfig.PLANNED_FEATURES`: `barnacle_turret`,
`resonator`, `gilded_sentinel`), so a new enemy's own files are all it takes to bring it into its
levels.

Built so far: cyborg (with its panic variant and hosts), window cyborg, fence generator, hover
truck, Octodog, sewer screech (manholes, and wall vents; `screech_vents` is wall vents only, for zones
whose floor has no manholes),
heli drone, the Cyborg's Bad Dream (released by a killed host, spawned by the director at run
time rather than placed by the generator), the Resonator (GDD §9.10, the Golden Zone: a golden
broadcast spire hovering far ahead whose red waves roll along the floor across every lane; its model,
`resonator_model.gd`, is built in code, and `resonator_rules.gd` plans each pulse where its wave meets
the player on clear floor), the Barnacle Turret (GDD §9.8, from Marketplace 1: a ceiling enemy, see
below), the Buzz Overdrive (GDD §9.9, from Corporate 1: a buzzsaw tank that cuts its lane's floor into
a gap, see below), and the Tithe Collector (GDD §9.12, from Corporate 2, skipping the Dead Zone, back in
the Golden Zone: see Thefts above). `scripts/enemies/mesh_batch.gd` merges an enemy's low-poly parts into
one mesh per material to keep draw calls down.

**Big attacks take turns through the director** (GDD §9, decided September 26, 2026). The big attacks
of different enemy types never overlap, so the player never has to dodge two at once. The owner may
revert this after playtesting, so it sits behind one switch, `GameRules.big_attacks_take_turns` (on by
default, in the F6 panel); switched off, the game plays exactly as before the rule. The big attacks
(DESIGN-TBD, `docs/questions/r3.md`): the Octodog's charge sequence (its first wind-up until it gives
up), the drone's wind-up and barrage, the hover truck's rev and forward lurch and its cannon's charge
and volley, the Bad Dream's chase, the Resonator's pulse (its warning until its last wave has passed
the player; DESIGN-TBD, `docs/questions/c3.md`), and the Buzz Overdrive's rev and charge (its warning
until it has passed the player and gone; it never waits, below). Small attacks (a cyborg's burst, a window
cyborg's shot, a Barnacle Turret's burst, a screech's swipe) and the hover truck's entrance don't take
part. An enemy takes part like this, and the enemies still to come (the Gilded Sentinels, the Tithe
Collector) opt in the same way for whichever of their attacks count as big:
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
  count) it drops its remaining pulses and leaves, never before its first.
- **An attack that can't wait** because the player sets it off (the Bad Dream bursts out of a killed
  host) or the generator planned its moment still reports itself: the others wait for it. It can
  overlap an attack that was already on when it came; the Bad Dream holds its slash until that one
  is over. A planned floor cut (B4's stand-in, C2's Buzz Overdrive) reports itself from its warning
  until its charge ends; the generator keeps every other attack off its attack window (Floor cuts,
  under The generator), so only an attack moved on at runtime can meet it, and that one waits.

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
enemy store it in `params.floor_span` (the Octodog's charges). `LevelGenerator.enemy_floor_span(entry)`
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
  that is `upside_down` (Damage and interactions): running into it is deadly unless shielded, clawed or
  dashing, armor doesn't help; claws, the dash, a stomp from the ceiling or weapons kill it. Its health is
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
  hint shows as it spawns). When the player is a charge's distance from it (`FloorCutPlan.lead_at`) it
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
  the rev until it's gone): the generator planned its moment, so it never asks for a turn and the others
  wait for it; while it only rolls ahead it attacks nobody and holds nobody up.
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

## The generator

`LevelGenerator` (`scripts/world/level_generator.gd`) builds a `LevelLayout` (pure data) from
patterns, a difficulty value and a seed, for any lane count. Passes, each with its own random stream:
patterns (filtered by the level's features) → enemy rules scripts → credits. Helpers for rules
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
  Dream chases) or {lane, from, to} (that lane, which no doodad stands in or pushes into: a hover
  truck's, until it has left; its `keep_out` already keeps every lane for its shortest stay);
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
on the arena's track), and add it with its cause through `arena.add_pieces()` (its `cuts` and
`enemies`), its whole stretch past `stream_from()`, so about ten seconds ahead at the stand-in's
numbers (the Buzz Overdrive's own plan: `buzz_overdrive_rules.plan_for`). A track that grows during play (`TrackBuilder.extend_layout`, endless mode's R4 too) takes cuts
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
`same_side_gap_seconds` on either wall) and off for `intro_off_seconds`, with its first-encounter hint just
before it (HintDirector: `wall_fence`, `wall_fence_low`, `wall_fence_high`). Every feature appears: the guarantee
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

For task C4 (the Gilded Sentinels, GDD §9.11: live statues in wall niches at wall-run height, swinging a halberd
across their wall section and the outer lane): a sentinel is one more thing on its wall section, so keep wall
fences and sentinels apart. The sentinels come from patterns or rules, before the wall fences, so the simplest
way is to add the sentinel to `WallFencePlacement.keep_outs` like a window cyborg (its swing's stretch on its
wall, `wall_clear_seconds` either side, and its swing over the outer lane as a big attack's keep-out if it
counts as one); `LayoutChecks.check_wall_fences` then needs the same check. Ask `layout.wall_fence_between`
if a sentinel's rules ever run after the wall fences (they don't today).

For task E5a (The House, GDD §10: phase 2 puts one 7 button on a wall "with wall fences in play"): plan the
phase's wall fences as `WallFencePlan.make` entries at the arena's speed (`arena.tuning`), ask
`arena.wall_fence_problem(entry)` for each (the level's rules on the arena's track; a button on a wall is the
boss's own business: keep the button off a live wall fence's band and timing, and its approach off its drop
window), and add them with `arena.add_pieces()` (their `wall_fences`), past `stream_from()`. A wall fence on
the button's wall should let the player reach the button by timing or by entering high or low (a partial one
over the band the button isn't in). The wall fences pulse on the level clock like any; one the fight must
switch on or off at a moment of its own can be found with `world.track.wall_fence_hazards()` and held with
`Hazard.set_enabled()` (the EMP's way), never by another path, so DamageRules and the looks stay as they are.
Task E5b (Hostile Takeover, phase 1's partial wall fences along the sound barriers) does the same.

## Power-ups

`PowerupController` (`scripts/powerups/powerup_controller.gd`) runs one `PowerupModule` per owned,
switched-on permanent item: `WeaponPowerup` (auto-fire, tiers 1–4, enemy health bars), `ClawsPowerup`,
`DashPowerup`, `MagnetPowerup` and `SlowTimePowerup`. The armor is the damage rules' (`DamageRules.Armor`,
see Damage and interactions); the breakables (shield, grapple) are charges on the Player. The
controller's header documents its API: `hud_state()` for the HUD (`charges` -1 for permanent items; the
armor's hits, with its return as `ready`), `equipment()` for the player model, and `try_dash()` /
`try_slow_time()`.
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
clear of window cyborgs); read-only and visual only, like every other hook.

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
  task C4): "never at wall-run height (the Gilded Sentinels' language)" is true for free (every doodad
  stands on the floor, far below any statue ledge, `GoldenSkin.statue_min_height`), but the doodad statue
  also never reuses that kit or its shape -- a plain draped, faceless figure with its hands clasped and
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
  builds a given kind directly. `GoldenSkin.ceiling_section` hands it the section's wall distance, and a
  yacht's engine halos stop at the underside (`MeshKit.stern_halo`), as every zone's far end must.
- *Ceilings under the walls' decorations.* The walls build without knowing where ceilings are, so
  `GoldenFacades.clearance_profile()` declares what they hold out over the street, as (reach, lowest
  height) tiers: the statue ledge, the statues, the gilded frames, the banners, and `OVER_STREET` beyond.
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
  niche shape a live Gilded Sentinel's uses, `GoldenStatue.niche()`, task C4, `statue_share`, always at
  or above `statue_min_height`), a tapestry (`banner_share`) or a relief (`relief_share`); otherwise
  the flush panel simply carries on. `statue_spots()`, `feed_boards()` and `cult_emblems()` list a
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
  `data/audio/sfx_library.tres`); `Music` (`MusicDirector`) plays `assets/music/` (files, levels and
  tempos in `data/audio/music_library.tres`), one looping track at a time with crossfades: the menus'
  track and one per zone, named after the zone's id (`ZoneDef.music`). Both are generated by code in
  `tools/asset_gen/` (`tools/godot.sh sfx` / `music`): a track is composed in `track_<name>.gd` with
  `music_song.gd` (stems on a 16th grid that wrap around the loop, and loop-safe effects) and
  `music_instruments.gd`, and a new one is listed in `music_gen.gd` and the library. **No new tracks are
  generated** (owner, September 28, 2026): the owner will provide the songs, which replace the generated
  files one by one (same names, re-levelled in the library); until then new places reuse an existing track. Tracks are
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
intro play a placeholder arrival flyover, and the outros are still cards. A boss is built on the boss
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
- **Hints**: `hint_due(key)` asks the run's `HintDirector` for a first-encounter hint of the boss's own
  (trigger `boss:<key>` in `data/hints/hints.json`, once per profile): the Floating Head asks for its
  way up's (`boss:city_boss/ramp`, `/wall`, `/ceiling`) as each pin begins.
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
- **Sewer Swarm (E4):** 4–5 clusters are parts with health of their own and `is_swarm` (MultiMesh
  crowds drawn by the part), moving ahead of and behind the player (parts never retire); baiting one
  into a live fence or a hole is the boss script's check (`arena.live_fence_between`,
  `hole_between`) then `part.defeat(&"fence")`, and `_on_part_defeated` deals `hit_damage()`. The
  swarm on a wall is `props.block_wall`, one side at a time. The Host is the body part with three
  weak points.
- **The House:** its reels are a telegraph; cherry bombs are `circle_warning`s and blast hitboxes,
  the lightning a `props.fence` moved across the lanes, gold blocks `props.block`. The 7 buttons are
  spots the boss script checks against the player's surface, lane and distance (a wall button needs
  wall fences, B5; a ceiling button a pad and ceiling, and Barnacle Turrets through `spawn_enemy`
(`"barnacle_turret"`, with its params `hull_start`, `hull_end`, `first_lane`, `last_lane` naming the
arena's own `props.ceiling`),
  C1). The jackpot's hopper is a weak point switched on after all three buttons; its credit fountain
  needs credits placed during a run, which the credit field can't do yet (shared with the Tithe
  Collector's burst, B6/C5).
- **Hostile Takeover:** the train is the arena: an arena config whose patterns (a boss feature they
  `require`) cut every lane at the carriage gaps, and a train skin on the arena config; couplings are
  weak points on a part placed over each gap. Carriages breaking away behind the player are looks.
  The gunship is a part whose belly is a ceiling (`add_surface(..., true)`); the Buzz Overdrive
  (C2) comes with its planned cut: `FloorCutPlan.make` at the arena's speed, `arena.cut_problem(cut)`,
  then `arena.add_pieces()` with the cut and the saw's entry at its end, its stretch past
  `stream_from()` (The generator, Floor cuts on the track); the gunship's drop is the look before its
  warning.
  The docking clamps are phase 3's three hits.
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
| `cinematic_sequencer.gd` (`CinematicSequencer`) | the player: builds the stage, actors, camera and overlay, runs the clock (`advance`), fires the events, emits `finished`; `skip()`; `log_lines` lists every event fired (tests, the review tool) |
| `cine_timeline.gd` (`CineTimeline`) | one cinematic: `duration`, `letterbox`, `stage`, `camera` keys, `actors`, `events`; helpers to build one in a script (`shot`, `actor`, `sound`, `music`, `card`, `effect`, `cue`); `problems()` checks it; `sort()` |
| `cine_key.gd`, `cine_path.gd` (`CineKey`, `CinePath`) | a key's time and how the path comes into it: `SMOOTH` (a flight through the keys, velocity carrying on through each), `LINEAR` (a straight move eased by Tween's transition and ease types) or `CUT`; `sample_riding` for keys that ride with an actor |
| `cine_camera_key.gd` (`CineCameraKey`) | where the camera is (`position`), what it looks at (`target`), `fov`, `roll`; `follow` / `watch` an actor: the point is then an offset from it |
| `cine_actor.gd`, `cine_actor_key.gd`, `cine_actor_node.gd` | an actor (`RUNNER`: Razor Echo's `PlayerAvatar`; `CYBORG`: a `CyborgBody` in the zone's look or a look of its own, a host or not), its keys (position, pose, heading, a cyborg's face, aim and charge) and its node in play |
| `cine_event.gd` (`CineEvent`) | `SOUND` (a sound effect), `MUSIC` (a track, `@zone`, or none), `TEXT` (a card), `EFFECT` (`fade_in`, `fade_out`, `flash`, `shake`, `letterbox_in`, `letterbox_out`), `CUE` (a script's own moment) |
| `cine_stage_def.gd`, `cine_stage.gd` (`CineStageDef`, `CineStage`) | the set: a stretch of track built by the `TrackBuilder` in the zone's skin, with its sky and fog (`ZoneSkin.level_environment(0)`) and the run's sun; ceilings, gaps and pads; streamed in chunks like a run |
| `cine_overlay.gd` (`CineOverlay`) | the 2D layer: letterbox bars, fades, flashes, text cards (menu fonts, capitals) and the Skip button (showing the pause key), in the safe area |
| `arrival_flyover.gd`, `arrival_flyover_tuning.gd`, `scenes/cinematics/arrival_flyover.tscn`, `data/cinematics/arrival_flyover.tres` | the placeholder arrival flyover (below) |

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
keys. A cyborg (`CyborgBody`) walks or idles by its speed, or takes `aim`, `run_away`, `cower` or `die`;
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
```

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
one. `RunSim` (`tests/helpers/run_sim.gd`) runs a Player over a hand-built layout (`run()`), or a
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
second phase, the retry won with three stars, the shop, the outro). `test_resonator` plays the
Resonator in full worlds on real physics (the warning always before the wave, a jump clearing it at 3,
5 and 6 lanes with its margin measured, walls and the ceiling safe, armor, shield and dash, turns with a
`TurnDummy`, Reduced flashing), checks its rules over many seeds, and plays the real Golden 1-3 layouts
at 3, 5 and 6 lanes, watched by `attack_watch.gd`: no wave meets the runner on a gap or a fence, and no
big attacks overlap. `test_barnacle_turret` covers the Barnacle Turret (C1): its numbers against the
cyborg's and GDD §8's 7 laser tier 1 shots, hitboxes out of reach of anyone off its ceiling, both looks
(no hazard glow but the charging muzzle), placement over every campaign level and narrow-ceiling sweeps
(`LayoutChecks.check_turrets`, which `check_rules` runs on every generated level), a level unchanged
without it, and on real physics: popping out, firing only at a rider on its own ceiling after its
charge-up, dodging, two-lane ceilings at 3, 5 and 6 lanes with one turret and two, contact (armor, shield,
claws, dash, a stomp from the ceiling), 7 laser tier 1 shots, armor and the shield against its bolts,
determinism, and generated levels ridden through with every burst checked. `test_ceilings` covers narrow
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
next step follows, skipping, the web demo). `test_pace` checks the pace and busier levels (G1): the zones' speeds in data and each campaign level at
its zone's speed (and each boss fight, E1f; quick play's at the base), `movement_for`, a pattern's timing in seconds at 18 and 25
m/s, the generator's fairness at 21, 23.4 and 25 m/s at 3, 5 and 6 lanes with every built feature and
the fill pass (`LayoutChecks` checks each level at its own speed: `level_tuning()`), the fill pass's
rules on campaign levels, the Octodog's and Resonator's windows in seconds, a cyborg and a screech on
real physics at 25 m/s (the charge-up, the bolt's flight, the dodge; the shake), floor routes under a
Golden level's ceilings run on physics at 25 m/s, and F6's Save keeping the base run speed.
`test_doodads` checks zone doodads (G5; GDD §3): a level without them is the same data as before and a
share of 0 changes nothing (every piece, enemy, pick and fill stays with a share; only credits inside a
doodad go), placement over 216 levels at 3, 5 and 6 lanes (every difficulty, with and without every
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
while it cuts, none and a line that only widens with Reduced flashing.

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
`test_web_demo` checks the web demo's preset, its export filter against
the data and everything the demo references, and walks the demo from the title to its end screen (see
Platforms and build flavors). The runner frees
anything a suite leaves in the tree, gives suites a fresh, unsaved profile, reports a suite that fails
to load, and ends a stuck run after 2400 s of real time.

## Review tools

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
`--reduced-flashing` as for the floor cuts), the Golden Zone's statue
kit (`statue_showcase`: every pose, a turnaround, and a live statue rigged in its niche and swinging, as
task C4 would build it), the bosses (`floating_head_showcase`, `sleep_taker_showcase`), the UI kit, the screens (`screens_showcase`;
its `--screen=hud_armor [--tier=N]` takes the HUD's armor through its states: up, broken, its ring
filling, back), a zone skin
(`skin_review`: any skin from fixed spots, including close-ups of the cult's feed screens and emblems a
skin lists, or a scripted run with a ceiling ride and a wall run, in a level's darker lighting with
`--darkness=X`; `--narrow` makes three of its ceilings narrow, one lane in the middle, the two leftmost
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
builds measure the same asks alike), and the enemies that never got a big attack in (Octodogs
without a charge, Resonators without a pulse, drones without a barrage, hover trucks without a lurch
or a cannon shot) (`godot --headless --fixed-fps 60 -s res://tools/measure/big_attacks.gd --
--levels=gangland/3 --lanes=3,5,6 --out=build/measure/x.json`; the whole campaign on its own seeds takes
about ten minutes; `--seeds=6` adds six other seeds a level, `--seeds=9007-9020` runs a range, and
`--features=octodog` keeps the levels that use a feature). `attack_watch.gd` watches the attacks from the
enemies' own states and the live shots, never from the turn-taking code (only the waits come from the
director's answers), and hashes each run's event log, so two builds (or the switch off and a build
without the rule) can be compared run by run.

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
