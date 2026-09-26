# Neon Runner (working title)

Right now this is the **R1 core-movement grey box** from `docs/NEXT_STEPS.md`. It's plain boxes
and glow materials with no art, built to answer one question: *do lanes, walls, ceiling, jump and slide feel good?*

Design docs: `docs/GDD_CHECKPOINT.md`, `docs/OPEN_QUESTIONS.md`, `docs/NEXT_STEPS.md`. Agent rules: `CLAUDE.md`.

## Run it

Engine: **Godot 4.7.2-stable** (standard build, not .NET).

1. Open Godot, click **Import**, and pick `project.godot` in this folder.
2. Press **F5** to play.

Launch options (from the command line, after `--`): `--lanes=5`, `--seed=23`, `--difficulty=0.6`, `--god`.

## Controls

| Action | Keyboard | Touch (mouse drag also works) |
|---|---|---|
| Change lane / enter a wall from the outer lane | Left / Right arrows | Swipe left / right |
| Jump (wall jump while on a wall) | Up arrow or Space *(placeholder)* | Swipe up |
| Slide (fast drop in the air) | Down arrow | Swipe down |
| Pause | Esc / P | – |

Debug keys: **R** restart, **F1** lane count 3 → 5 → 6, **F2** next seed, **F3** difficulty,
**F4** god mode (hazards ignored; falls still kill), **F5** show hitboxes, **F6** tuning panel, **M** mute.

## Tuning while you play (F6)

F6 pauses the game and opens a panel with a slider for every movement number (run speed, jump height,
lane switch time, wall-run heights, camera, and so on). Changes apply immediately, and play resumes when
you close the panel. Speed, jump and size changes also reshape the level, so press **Restart level** to rebuild it.
**Save** writes the values back to `data/tuning/movement.tres`, and **Reload file** undoes unsaved changes.

The same numbers are also in the Godot inspector: open `data/tuning/movement.tres`. Level settings and the
generator's fairness rules are in `data/levels/prototype_level.tres`. Generator patterns are in
`data/patterns/prototype_patterns.json` (format: `data/patterns/README.md`). The grey-box colours are in
`data/skins/greybox_skin.tres`.

## What's in the grey box

- Floor lanes (any count), animated lane switches, gaps you fall through
- Jump with coyote time and jump buffering; slide with a smaller hitbox; a blob shadow to read height
- Side-wall runs: free entry past the outer lane, a 2-second slide down, wall jump; signs block entry and hurt
- Ramps: a boosted, higher wall entry
- Anti-grav pads, then the ceiling (hull) with its own lanes, dropping back down when the hull ends;
  some ceilings pass over floor fences, so the pad is an alternative route
- Electric fences: full-height (jump) and gapped (slide), always-on and pulsing. Pulsing fences flicker
  and buzz before switching on, and follow the level clock, so every attempt at a seed has the same timing
- Placeholder sounds synthesized in code (no asset files)
- A seeded, data-driven level generator for any lane count; death restarts the same seed; finishing moves to the next

It has none of the enemies, credits, shop, power-ups, real audio, art or menus. Those come in later milestones.

## Tests

```
godot --headless --fixed-fps 60 -s res://tests/run_tests.gd
```

The suite takes about 4 seconds and exits non-zero on any failure. It covers:

- **Generator fairness** over 360 levels (3/5/6 lanes × 4 difficulties × 30 seeds): same seed gives the same level,
  every gap and all-lane hole is jumpable, pads have a hull above and solid floor before them, hull landings are
  clear, ramps aren't blocked, and nothing spills into the clear stretch before the finish.
- **Movement scenarios on real physics:** gaps, coyote time, jump buffering, fences, slides, pulsing timing,
  no tunnelling at 90 m/s, wall runs, wall jumps, signs, ramps, pads and ceiling, and 6 lanes.
- **Units:** pulsing hazard states, touch gesture classification, placeholder sounds, and the tuning panel.

Headless smoke run: `godot --headless --fixed-fps 60 --quit-after 2400 -- --lanes=5`.
Sounds are skipped in headless runs, because the dummy audio driver never finishes a playback and Godot would
report every played sound as leaked at exit.

## Layout

```
scripts/core/          tuning + level config resources, DamageRules (the single damage/interaction rule set)
scripts/input/         TouchInput autoload (swipes/taps → named input actions)
scripts/player/        Player controller
scripts/world/         LevelLayout (data), LevelGenerator, TrackBuilder (gameplay nodes), Hazard, TrackGeometry
scripts/world/skins/   ZoneSkin (visual hooks per abstract piece), GreyboxSkin, HazardVisual
scripts/audio/         placeholder sounds, player sounds, hazard warning sounds
scripts/game/          grey-box game loop + camera
scripts/ui/            debug HUD, tuning panel
data/                  tuning, level configs, skins, generator patterns
tests/                 headless tests
```

Gameplay and visuals are separate. `TrackBuilder` creates every collision shape from abstract pieces
(floor segments, gaps, fences, signs, hulls, pads, ramps) and asks the level's `ZoneSkin` to decorate them.
A zone skin replaces the look without touching collision.
