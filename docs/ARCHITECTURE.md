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
time). Quick play can add features: `./play.sh --features=cyborg,drone`.

Built so far: cyborg (with its panic variant and hosts), window cyborg, fence generator, hover
truck, Octodog, sewer screech (manholes, and wall vents with the `screech_vents` feature in the City)
and heli drone. `scripts/enemies/mesh_batch.gd` merges an enemy's low-poly parts into one mesh per
material to keep draw calls down.

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
`difficulty_at(progress)`, plus `layout`, `config`, `tuning`, `speed`, `jump_distance`. Pattern
format: `data/patterns/README.md`.

Rules scripts run in the order of the level's `features` list. When a rule needs room for one of its
guarantees, it removes what's in the way rather than moving it (taking content out never makes a
level unfair). The drone's pad schedule (GDD §9.6) owns every pad after its first wave: it clears the
floor under each pad's ceiling, and pattern ceilings give way.

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
fallback for undesigned zones. Both real skins build on the mesh kit (`scripts/world/meshes/`):
`MeshKit` has shared builders for hazards, triggers and environments, and `MeshLayer` batches a chunk's
geometry. The shaders in `scripts/world/meshes/shaders/` are procedural. `HazardStateVisual` swaps a
hazard's ON / WARNING / OFF materials. A skin's `enemy_variant` (`&"city"` or `&"scavenger"`) picks
the enemies' look.

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
`city/boss`, ...) key the save file. Difficulty comes from a campaign-wide curve plus each level's
`difficulty_bias`; `enemy_scaling` runs 0 → 1 across the campaign.

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
the checks every zone skin must pass. The runner frees anything a suite leaves in the tree, gives
suites a fresh, unsaved profile, reports a suite that fails to load, and ends a stuck run after
600 s of real time.

## Review tools

Scenes in `tools/showcase/` show one part of the game up close for visual review (not part of the
game): the avatar, the enemies (`enemy_showcase` for the cyborg family, `octodog_screech`,
`drone_truck_showcase`), the UI kit and the screens. Each script's header lists its options. Render
frames on the Compatibility renderer (the web and low-end Android path) with `--write-movie`, as in
`CLAUDE.md`.
