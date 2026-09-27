# Neon Runner (working title)

A neon 3D runner for PC (Steam), Android, iOS and a web demo. You run lanes, side walls and ceilings
through zones full of enemies, and a single hit ends the run. Built with Godot 4.7.2 and GDScript only.

**Status:** the game is built around everything designed so far:
- the whole campaign structure: six zones and 15 levels, three of the zones still in the grey-box look
- seven enemy types, plus fence generators
- the shop, power-ups and economy
- every screen and the HUD
- three zone looks (the Neon City, Gangland and the Marketplace), generated music and sound effects
- all three build flavors

Boss fights have their framework (they play in the runner, with phases, a health bar, checkpoints,
stars and payouts), but each zone's boss is still a placeholder slot until it's built on it; a test
boss shows the framework at work. The Neon City's Floating Head is being built: its ship and face, its
entrance, its bombing run and the reveal of its face so far (debug builds play it with
`--boss=city_boss`; the campaign keeps its placeholder slot until it's done). The short cinematics
between levels are placeholder slots too.
Every placeholder decision is listed in `docs/OPEN_QUESTIONS.md`.

Docs: `docs/GDD_CHECKPOINT.md` (the design, the authority), `docs/OPEN_QUESTIONS.md` (open decisions and
placeholders), `docs/ARCHITECTURE.md` (how the code fits together), `docs/NEXT_STEPS.md` (risk tests and the
original build plan), `CLAUDE.md` (rules for agents).

## Play it

Engine: **Godot 4.7.2-stable** (standard build, not .NET). You don't need to import the project in Godot.

- **From a terminal (WSL, Linux or macOS):** `./play.sh`
- **From Windows:** double-click `play.cmd`, or run it from a terminal.

Either one plays whatever is in this folder right now and opens on the title screen. The first run finds Godot and
remembers where it is; after that, resources are re-imported automatically whenever a file changed. If Godot is
somewhere unusual, set the `GODOT` environment variable to its executable. Open the editor with
`tools/godot.sh edit` or `play.cmd edit`.

Options for testing (debug builds only, the same with `play.cmd`):

| Option | What it does |
|---|---|
| `--quick` | Quick play: the prototype level, restarting on death, with the debug keys and HUD |
| `--seed=N --lanes=N --difficulty=X` | Quick play with that seed, lane count (3, 5 or 6) or difficulty (0–1) |
| `--features=cyborg,drone` | Quick play with extra level features: `ramps`, `ceilings`, `pulsing`, `speed_pads`, an enemy type (`cyborg`, `window_cyborg`, `host`, `generator`, `hover_truck`, `octodog`, `screech`, `screech_vents`, `drone`). The full list is in `LevelConfig` |
| `--god` | Hits don't kill (falls still do) |
| `--nofall` | The grapple never runs out, so falls never end the run |
| `--full-loadout` | Every power-up |
| `--skin=gangland` | Quick play in another zone's look: `city`, `gangland` or `marketplace` |
| `--pickups` | Quick play with armor, shield and grapple pickups in turn, to review their look (`--pickups=shield,grapple` for some). In the game only boss fights have pickups |
| `--level=city/2` | A campaign level with the full game flow (also takes `--lanes`, `--god`, `--nofall`, `--full-loadout`) |
| `--boss=test_boss` | A boss fight by its id: the test boss (or any boss outside the campaign) as quick play, starting over after a death or a win; a zone's boss (`city_boss`, ...) with the full game flow once it's built, and as quick play while it's being built (`--boss=city_boss`: the Floating Head so far). Takes `--lanes`, `--god`, `--nofall`, `--full-loadout`, `--skin=<zone>` and `--phase=N` (start at phase N, as a checkpoint would) |
| `--flavor=web_demo` | Behave like another build: `full_pc`, `full_mobile` or `web_demo` |

Example: `./play.sh --lanes=6 --features=octodog,ceilings --god`, or the test boss's last phase:
`./play.sh --boss=test_boss --phase=3 --god --nofall`.

## Controls

| Action | Keyboard | Touch (a mouse drag works too) |
|---|---|---|
| Change lane / enter a wall from the outer lane | Left / Right arrows | Swipe left / right |
| Jump (wall jump while on a wall) | Up arrow or Space | Swipe up |
| Slide (fast drop in the air) | Down arrow | Swipe down |
| Juggernaut dash (power-up) | Shift | Tap |
| Slow time (power-up, PC only) | E | – |
| Pause | Esc / P | Pause button |

Every key can be rebound in Settings. PC runs use 5 lanes and mobile runs use 3 (the exact PC count is still
open: 5 or 6).

Debug keys (debug builds): **R** restart, **F1** lane count 3 → 5 → 6, **F2** next seed, **F3** difficulty,
**F4** god mode, **F5** show hitboxes, **F6** tuning panel, **M** mute.

## What's in the game

- **Campaign:** 15 levels in six zones, about 35 minutes of flawless running: the Neon City (the web demo's
  zone) and Gangland with three levels each, the Marketplace, Corporate and the Dead Zone with two, and the
  Golden Zone with three.
  Each zone has a boss slot and cinematic slots; the last three zones use the grey-box look until their skins
  are made. Each level introduces about one new thing (GDD §5), where its data says (`feature_starts`):
  1. City 1 *Rooftop Rush*: gaps, fences, walls and signs, then cyborgs late in the level.
  2. City 2 *Skyway*: ceilings and anti-grav pads.
  3. City 3 *Neon Crossfire*: pulsing fences, window cyborgs and the hover truck.
  4. Gangland 1 *Scrapyard Streets*: sewer screeches and ramps.
  5. Gangland 2 *Dog Run*: Octodogs and speed pads.
  6. Gangland 3 *Rotor Wash*: fence generators and heli drones.
  7. Marketplace 1 *Awning Alley*: the Barnacle Turret.
  8. Marketplace 2 *Shopfront Sparks*: wall fences, and sewer screeches from the shopfronts' wall vents.
  9. Corporate 1 *Maglev Line*: the Buzz Overdrive, then partial wall fences.
  10. Corporate 2 *Checkpoint Plaza*: the Tithe Collector, and a heavier military presence (more drones,
      hover trucks and Buzz Overdrives).
  11. Dead Zone 1 *Ashfall*: hosts and the Cyborg's Bad Dream.
  12. Dead Zone 2 *The Hush*: a quiet, eerie remix with nothing new.
  13. Golden 1 *Gilded Canals*: the Resonator.
  14. Golden 2 *Sentinel Row*: the Gilded Sentinels, and the hardest level.
  15. Golden 3 *The Golden Palace*, then the final boss.

  The Barnacle Turret, wall fences, Buzz Overdrive, Tithe Collector, Resonator and Gilded Sentinels aren't
  built yet: their levels already list them, and they appear once their code exists. Level names are
  placeholders, except the Golden Palace.
- **Movement:** floor lanes, side-wall runs and wall jumps (a sign blocking the wall bumps you back with a
  clank), anti-grav pads onto the ceiling, ramps (higher onto the wall, with a speed boost that fades like
  a speed pad's), speed pads.
- **Obstacles:** gaps, signs, and electric fences (full-height or gapped, always-on or pulsing), some with a
  generator that switches them off.
- **Enemies:**
  - cyborgs, with the panic variant and hosts
  - window cyborgs
  - the hover truck mini-boss
  - the Octodog
  - the sewer screech
  - the heli drone
  - the Cyborg's Bad Dream, released by killing a host cyborg (from Dead Zone 1; in quick play, try
    `--features=cyborg,host,ceilings`)
- **Bosses:** a framework for runner-style boss fights (GDD §10): the fight plays in the normal run on
  an arena track that keeps going for as long as it lasts, with the boss's health bar and phase
  markers on the HUD, weak points to stomp and weapon chip damage, a checkpoint for the final fight,
  no time limit and no escalation, stars from par times, a payout, records and a leaderboard per
  boss, and pickups: armor, shield and grapple pickups on the floor ahead, placed where they're fair
  to take, from the standard armor rule (at the start of the final phase, and a while after the
  player's armor or shield breaks) or offered by the boss itself. The test boss (`--boss=test_boss`),
  a hovering core that blasts the lane it lights up red and drops dazed into the player's lane to be
  stomped, shows it all (it offers a shield in its second phase). The Floating Head, the Neon City's
  boss, is being built on it: a giant ship whose stern is a propaganda face, roaring in overhead, a
  bombing run where a searchlight hunts the runner and bombs fall where it lingers (a red target
  circle, an alarm and a falling whistle), and the reveal of its face (`--boss=city_boss`). The other
  five zone bosses are still to be built.
- **Economy:** credits in four denominations, level score and stars, and a shop. Items are five permanent
  power-ups (weapon line, claws, juggernaut dash, magnet, slow time) and three breakables (armor, shield,
  grapple hook). After a death you're offered a revive (an item, or a rewarded ad on mobile). Net worth
  has its own leaderboard.
- **Modes:** the campaign, endless mode, and harder difficulty tiers after the last level.
- **Look and sound:**
  - Razor Echo, the runner: a dark-blue trench coat with soft copper conduits and a skirt that swings,
    a gold cybernetic arm and a copper ocular implant
  - the City, Gangland and Marketplace zone looks, with the cult's feed on screens and its emblem hidden
    in ads in all three
  - neon UI screens and HUD
  - generated music (menu, City, Gangland) and 65 sound effects
  - first-encounter hints
- **Settings:** volumes, key rebinding, screen shake, reduced flashing, hints.
- **Platforms:** export presets for Windows, Android, iOS and the web demo. Ads, purchases and
  leaderboards go through one platform layer, which is a stub until the real plugins are chosen.

## Tuning while you play (F6)

F6 pauses the game and opens a panel with sections for movement, game rules, power-ups, the runner's animation,
level pacing and each enemy type in the level. Changes apply immediately; pacing, speed, jump and size changes also reshape the level, so press
**Restart level** to rebuild it. **Save** writes the values back to their files in `data/`; **Reload files** undoes
unsaved changes. Every other number is in `data/` too: enemy tunings in `data/enemies/`, prices in
`data/shop/catalog.json`, patterns in `data/patterns/` (format: `data/patterns/README.md`), sound volumes in
`data/audio/sfx_library.tres`, and UI colours and sizes in `data/ui/ui_style.tres`.

## Tools

```
tools/godot.sh play [options]   play (what ./play.sh runs)
tools/godot.sh edit             open the editor
tools/godot.sh test             all tests, under two minutes; exit code 0 = pass (--suite=name runs one)
tools/godot.sh smoke [options]  40 s of the real game, headless; prints only problems
tools/godot.sh sfx [--review]   regenerate the sound effects (assets/sfx/) from tools/asset_gen/
tools/godot.sh music [--review] regenerate the music (assets/music/)
tools/godot.sh import           force a resource import
```

`--review` also writes waveform and spectrogram images to `build/`. Every model, texture, sound and track is
generated by code (`tools/asset_gen/`, and procedural meshes and shaders under `scripts/`). The two fonts are
OFL-licensed; licenses are in `assets/LICENSES.md`.

The scenes in `tools/showcase/` show one part of the game up close for visual review (the runner in every pose
and power-up look, and a scripted run on any zone's skin; ramp launches and blocked wall entries; each enemy
family, the Floating Head, the UI kit, every screen, a zone skin's fixed review track, the cult's feed); each
script's header lists its options.

## Tests

`tools/godot.sh test` runs 32 suites with about 2,800,000 checks:
- **Generator fairness:** hundreds of levels over 3/5/6 lanes, difficulties and seeds, and every campaign level
  (each with every feature it lists, on its own seed and on others). Under every ceiling the floor may be
  dangerous, so each one's pads, landing zone and a floor route that never takes the pad are checked, and
  some of those routes are run on real physics.
- **Movement:** scenarios on real physics, among them a ramp's boost against a speed pad's, a ramp's wall run
  and its credits against the generator's prediction, and the bump of a blocked wall entry.
- **Enemies:** each type's attacks, dodges, kills and generation rules.
- **Damage:** the shared damage rules.
- **Power-ups:** each one's behaviour.
- **Economy and saves:** the economy and save files.
- **Game flow:** the campaign (its zones, steps and level-by-level schedule) and app flow.
- **Bosses:** the boss framework with the test boss: phases, the checkpoint, no escalation, the arena,
  the damage rules on a boss, and the flow around a fight; the Floating Head's fight so far at 3, 5 and 6
  lanes: its build and hitboxes, bombs that fall only after their warning, a runner who keeps moving
  always escaping them, and every attempt playing out the same way.
- **Screens:** every screen at desktop and touch sizes.
- **The runner:** Razor Echo's poses on every surface, the coat's panels (never through the legs or the
  ground), the budgets, the power-up looks, and its copper glow kept clear of every hazard colour.
- **Zone skins:** all three skins, including a check that none adds collision, and the build budget; for
  Gangland and the Marketplace the colour rule (only hazards glow in hazard colours) and ceilings a runner
  can read upside down, for the Marketplace gaps that read as holes, its clear play space and walls and
  shop windows, and for all three where the cult's emblem hides and where its feed plays, never in the
  wall-run band (the feed's shared material has a suite of its own).
- **Sounds and music.**
- **Boot:** the real game scene.

Headless runs skip sounds, because the dummy audio driver never finishes a playback.

## Layout

```
play.sh, play.cmd       play the current version
tools/                  godot.sh (play/edit/test/smoke/sfx/music), asset generators, showcase scenes
scenes/main.tscn        the main scene: world, screens and overlays
scenes/bosses/          boss fight scenes (the test boss and the Floating Head so far)
scripts/app/            App (state and flow), Profile, SaveService, Settings, BuildFlavor
scripts/run/            a run: LevelRun, RunWorld, camera, projectiles, credits, score, effects, hints
scripts/player/         the Player controller and its avatar
scripts/characters/     the procedural humanoid rig
scripts/enemies/        one script (plus tuning and generator rules) per enemy type, EnemyDirector
scripts/powerups/       the permanent power-ups
scripts/world/          level layout, generator, track builder, hazards; zone skins and the mesh kit
scripts/campaign/       campaign, zones, bosses (BossDef, BossPhase) and cinematic slots
scripts/bosses/         the boss framework (BossEncounter, BossPart, BossArena, BossProps), the test boss,
                        and one folder per boss (floating_head/)
scripts/economy/        the shop catalog
scripts/ui/             theme, icons, widgets, screens, HUD, debug tools
scripts/audio/          sound library, music player, hazard warning sounds
scripts/platform/       the platform services layer and its stub
scripts/core/           tunable resources and DamageRules (the single damage/interaction rule set)
scripts/input/          TouchInput (swipes/taps → named input actions)
data/                   every tunable number, level, zone, pattern, skin, catalog and library
assets/                 generated sounds and music, fonts, icon (licenses: assets/LICENSES.md)
tests/                  headless tests
```

Gameplay and visuals are separate: the generator and gameplay code only know abstract pieces (floor segments,
gaps, fences, walls, ceilings), and each zone's skin decorates them without touching collision.
