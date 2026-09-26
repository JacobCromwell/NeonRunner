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
`LevelRun` (`scripts/run/level_run.gd`), which generates the layout and builds a `RunWorld`:

```
RunWorld (scripts/run/run_world.gd)       one run's gameplay world; everything shares it
  Track      TrackBuilder: floor/hull collision, obstacles (fences, signs), triggers (pads, ramps,
             speed pads), built in 40 m chunks around the player; the zone skin decorates it
  Player     movement on floor, walls and ceiling; protection; receive_hit()
  Enemies    EnemyDirector: spawns layout enemies as the player approaches, retires them
  Projectiles ProjectilePool: every shot, pooled and swept
  Credits    CreditField: every credit as MultiMesh instances; pickup and magnet
  Effects    RunEffects: particle bursts, glowing lines, camera-shake requests
  Score      ScoreKeeper: level score, credits, kills, bonuses, stats
  Sounds     PlayerSfx: non-positional sounds (RunWorld.play_sfx / play_sfx_at)
  Powerups   PowerupController, created if scripts/powerups/powerup_controller.gd exists
```

`LevelRun` adds the camera (`RunCamera`), the HUD (`RunHud`) and, in debug builds, the debug HUD and
the F6 tuning panel. Quick play (`--quick`, or any of `--god --seed=N --lanes=N --difficulty=X
--features=a,b --full-loadout --nofall --skin=<name>`) restarts on death like the grey box did.
`--level=<step id>` plays a campaign step with the full flow and takes `--lanes`, `--god`, `--nofall`
and `--full-loadout` for reviews. Command-line starts work in debug builds only, so a release build
can't skip progression or farm credits with them.

Physics order each frame: RunWorld (builds chunks, spawns enemies) → Player (moves, checks hazards
and triggers) → enemies → projectiles → credits → power-ups.

## Data (tunables live in data, CLAUDE.md principle 7)

| File | What |
|---|---|
| `data/tuning/movement.tres` (`MovementTuning`) | run speed, jump, walls, ceiling, piece sizes, camera, touch |
| `data/tuning/game_rules.tres` (`GameRules`) | lanes per device, death share, invulnerability, stomp, score, economy, stars |
| `data/tuning/powerups.tres` (`PowerupTuning`) | weapon tiers, claws, dash, magnet, slow time |
| `data/enemies/<type>.tres` (`EnemyTuning` subclasses) | per-enemy numbers, early/late pairs for campaign scaling |
| `data/shop/catalog.json` | shop items, tiers and prices |
| `data/campaign/campaign.tres` → `data/zones/*.tres` → `data/levels/*.tres` | the campaign |
| `data/bosses/*.tres`, `data/cinematics/*.tres` | boss and cinematic slots |
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

**Major attacks take turns through the director.** An enemy reports `is_major_attack_active()`
(the Octodog through its charge sequence, the drone through wind-up and barrage, the Bad Dream through
its chase), and before starting one asks `EnemyDirector.major_attack_blocked(self)`, which is true
while another enemy's major attack is on and either of the two is `exclusive_major_attack` (the Bad
Dream is: GDD §9.7). Other types can opt in the same way.

**Floor use.** GDD §3 keeps the floor under a ceiling clear, and that includes enemies. A type's
tuning says whether it uses the floor (`uses_floor`: false for fliers like drones and hover trucks,
and wall-only enemies like window cyborgs) and how much of it around its spot
(`floor_reach_before`/`_after`). Rules that plan a longer run for one enemy store it in
`params.floor_span` (the Octodog's charges). `LevelGenerator.enemy_floor_span(entry)` and
`enemy_uses_floor(entry)` read all of this, and `floor_clear` / `add_hull_with_pad` respect it.

## The generator

`LevelGenerator` (`scripts/world/level_generator.gd`) builds a `LevelLayout` (pure data) from
patterns, a difficulty value and a seed, for any lane count. Passes, each with its own random stream:
patterns (filtered by the level's features) → enemy rules scripts → credits. Helpers for rules
scripts: `rng_for(name)`, `add_enemy(type, at, lane, side, params)`, `add_hull_with_pad(lane, at,
seconds)`, `floor_clear(from, to)`, `enemy_floor_span(entry)`, `enemy_uses_floor(entry)`,
`difficulty_at(progress)`, `feature_start(feature)`, `feature_started(feature, at)`,
`feature_active(feature, at)`, `feature_share_at(feature, share)`, plus `layout`, `config`,
`tuning`, `speed`, `jump_distance`. Pattern format: `data/patterns/README.md`.

Rules scripts run in the order of the level's `features` list, except that a script declaring
`const RUN_AFTER: Array[String]` runs after those features' rules (the host rules after the drone's;
the cyborg rules, and the host rules that start with them, after the hover truck's, so cyborgs keep
their margin from the ramp a truck adds).
When a rule needs room for one of its guarantees, it removes what's in the way rather than moving it
(taking content out never makes a level unfair). Guaranteed pads come from
`scripts/enemies/pad_placement.gd`, shared by the drone and host rules: the drone's pad schedule
(GDD §9.6) owns every pad after its first wave, pattern ceilings give way, and the host rules (which
run after the drone's) cover each Bad Dream chase with pads at most 10 s apart or leave that host out.

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

## Power-ups

`PowerupController` (`scripts/powerups/powerup_controller.gd`) runs one `PowerupModule` per owned,
switched-on permanent item: `WeaponPowerup` (auto-fire, tiers 1–4, enemy health bars), `ClawsPowerup`,
`DashPowerup`, `MagnetPowerup` and `SlowTimePowerup`. Breakables (armor, shield, grapple) are charges
on the Player. The controller's header documents its API: `hud_state()` for the HUD (`charges` -1 for
permanent items), `equipment()` for the player model, and `try_dash()` / `try_slow_time()`.

## Zone skins

A `ZoneSkin` (`scripts/world/skins/zone_skin.gd`) decorates abstract pieces through hooks
(`floor_segment`, `wall_section`, `fence`, `wall_sign`, `hull`, `pad`, `ramp`, `speed_pad`,
`finish_line`, `make_environment`). Skins add visuals only, never collision or gameplay. Hazards keep
one colour and shape language in every zone (pink crackle = electric fence).

Skins so far: `CitySkin` (Zone 1, the Neon City) and `GanglandSkin` (Zone 2). `GreyboxSkin` is the
fallback for zones without their own look yet (the Marketplace, Corporate, the Dead Zone and the
Golden Zone for now). A zone's skin lives at `data/skins/<zone id>_skin.tres` (`--skin=<zone id>` in
quick play) and is set in its `data/zones/<zone id>.tres`; a level's own `skin` wins over its zone's
(the Golden Palace, Golden 3, may get its own). Both real skins build on the mesh kit
(`scripts/world/meshes/`): `MeshKit` has shared builders for hazards, triggers and environments, and
`MeshLayer` batches a chunk's geometry. The shaders in `scripts/world/meshes/shaders/` are
procedural. `HazardStateVisual` swaps a hazard's ON / WARNING / OFF materials. A skin's
`enemy_variant` (`&"city"` or `&"scavenger"`) picks the enemies' look.

The kit's solid shader (`kit_solid.gdshader`) draws surface patterns chosen per vertex (`MeshKit.PAT_*`):
panels, glass, glyphs and chevrons for the City; worn asphalt (with sand drifts and scorch around holes),
road strata, salvaged plating, posters (with corporate ads), cast concrete and stencilled crates and
container doors for Gangland. Features a zone opts into are uniforms that default to off, so one zone's
additions never change another's look. Painted marks shared between shaders live in includes:
`kit_marks.gdshaderinc` (graffiti pieces and tags, stencil codes) and `kit_logo.gdshaderinc` (the
corporations' placeholder logo). Two shader rules: take derivatives (`fwidth`, implicit texture LODs)
outside any branch that can differ between neighbouring pixels and pass them in, and use
`filtered_pulse()` only for ranges within 0–1 (`band()` for any other). Breaking either can put a NaN in a
pixel, and the glow pass blows it up into a white disc.

**Gangland's ceilings** (`GanglandCeiling`) take their width from the lanes they cover (the collision
box), never from the track, and draw each side as anchored (running into the building face) or free
(an edge face), so narrow ceilings (B3) only need to tell the builder which sides reach a wall. Whatever
the structure above (an overpass or a bombed-out building), the running surface is a flat slab with lamps
on every lane seam, nothing hangs below it, and its far end carries the orange band
(`MeshKit.ceiling_end`, as in every zone).

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
mark could read like a radiation trefoil.

**Reduced flashing** (Settings): `Settings.apply_visuals()` sets the global shader uniform
`reduced_flashing` (declared in `project.godot`) and `Settings.flashing_reduced`. Hazard shaders
include `kit_flash.gdshaderinc` and use `warning_flicker()`, so a warning becomes a steady glow
instead of a strobe. Anything new that flickers or flashes must honour it too.

## Characters, UI and audio

- **Characters:** `HumanoidRig` (`scripts/characters/`) is the procedural rig and pose set behind the
  player model (`PlayerAvatar`, a human in a cyber suit) and the cyborgs (`CyborgBody` with
  `CyborgSuit`: one skeleton, a part set per zone look, one material per cyborg).
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
`test_campaign` holds the schedule table and its exceptions. Features of enemies and mechanics still
to be built (`LevelConfig.PLANNED_FEATURES`, with the wall fences' `wall_fences` and
`wall_fences_partial`) are listed already and do nothing until their code and patterns exist.

Bosses and cinematics are slots for now (owner decision): a `BossDef` or `CinematicDef` with an
empty `scene` shows a placeholder card. To build one, make a scene whose root extends
`BossEncounter` (emit `finished(won, score, credits)`) or `Cinematic` (emit `finished`, support
`skip()`), and set its path in the def.

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
full RunWorld (`build_world()` + `step_world()`). `SkinSuite` (`tests/helpers/skin_suite.gd`) holds
the checks every zone skin must pass. `LayoutChecks` (`tests/helpers/layout_checks.gd`) holds the
fairness checks for generated layouts (the generator suite runs them over many seeds, the campaign
suite over every campaign level at 3, 5 and 6 lanes) and finds a feature's pieces in a layout; a task
that adds a new kind of piece extends `feature_positions()`. The runner frees anything a suite leaves
in the tree, gives suites a fresh, unsaved profile, reports a suite that fails to load, and ends a
stuck run after 600 s of real time.

## Review tools

Scenes in `tools/showcase/` show one part of the game up close for visual review (not part of the
game): the avatar, the enemies (`enemy_showcase` for the cyborg family, `octodog_screech`,
`drone_truck_showcase`, `bad_dream_showcase`), the UI kit, the screens, and comparison sheets for an
open design choice (`cult_emblem_sheet`, D7). Each script's header lists its options. Render
frames on the Compatibility renderer (the web and low-end Android path) with `--write-movie`, as in
`CLAUDE.md`.
