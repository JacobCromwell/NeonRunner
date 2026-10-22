# Architecture: falling gantryways

Part of the architecture notes; the index is [`docs/ARCHITECTURE.md`](../ARCHITECTURE.md).

## Falling gantryways (the Ice Lab)

Task Q3; GDD §5, Zone 9 (the owner, October 21, 2026): "a gantryway is an upper walkway over one lane only, looking like a
ceiling section, moderate in length: a little shorter than ceiling sections usually are. Pillars stand in the floor lanes
holding them up. Dashing through a pillar knocks down its long section of gantryway. It takes about a second to fall. When
it lands, it destroys any enemy in its path. A runner under it when it lands is hit: armor and the shield block it, as they
block any hit." The level feature is `gantryway` (all three Ice Lab levels; Frost Foundry introduces it from 0.15 of the
level, `feature_starts`); how many a level hangs is `LevelConfig.gantryways` (3, DESIGN-TBD). Every number is
`GantrywayTuning`'s (`data/tuning/gantryways.tres`, F6 "Gantryways" in a level that has them; the times are seconds of run at
the level's speed, or at the fastest a runner comes through a pillar, so a faster zone keeps every window).

**The files.**
- `scripts/enemies/gantryway_rules.gd`: the generator's rules (a rules script with no patterns, like the dash walls'): where
  each one hangs, what it keeps clear, the cyborg planted under it, and `problems()`, the re-check of a finished layout.
- `scripts/world/gantryway.gd` (`Gantryway`): one on the track, its fall, its warning, its hitbox and its crush test.
- `scripts/world/gantryway_tuning.gd` (`GantrywayTuning`) and `data/tuning/gantryways.tres`.
- `scripts/world/skins/gantryway_kit.gd` (`GantrywayKit`): the default look (a frosted steel catwalk, an icy steel pillar
  and the catwalk crushed flat), `scripts/world/meshes/shaders/gantryway.gdshader` (the kit's lit look, dissolving near the
  camera) and `gantryway_shadow.gdshader` (its shadow on the lane).
- The data: `LevelLayout.gantryways` (`{id, lane, start, end, pillar, side, calm, seed}`, `intro` and `both` on an
  introduction; marked `fallen` and `landed` on an attempt), and its pillar, an ordinary entry of `LevelLayout.doodads` (a
  small doodad) marked `LevelLayout.GANTRY_PILLAR` with its gantryway's `id` (`pillar_of`, `is_gantry_pillar`;
  `append_pieces` renumbers an appended layout's ids and marks past its own, for endless mode's stretches).
- `tools/showcase/gantryway_review.tscn` (Review tools) and `tools/measure/gantryways.gd`.

**Where it hangs** (GantrywayRules, its header has the whole list). A gantryway hangs over an inner lane L (never by a side
wall: no wall runner meets its pillar, and a runner under it has a lane on either side), its walkway from just before its
pillar's front F for length_seconds of run, at the ceilings' height. Its pillar stands in L from F and pushes into the lane on
its `side` like any doodad. Its windows, all from the pillar's push lead and a lane switch's room before F (Plan, on a grid of
fronts):
- L holds nothing (no hole, fence, pad's zone, speed pad, ramp's run, floor cut's lane window, doodad, floor enemy) to a lane
  switch's room past the walkway's far end: it lands flat on whole floor, and only its planted cyborg stands under it;
- its **calm stretch**, from F to the fall and escape_after_seconds more at the fastest a runner comes through the pillar
  (`calm_length`): the lane on its side (where a runner who dashed it steps out) holds nothing of that, and nor does the
  other side's for an introduction (`both`, intro_both_sides: "plenty of room to step out"); otherwise the other side holds
  nothing until a caught corner's push has landed, as beside any doodad. Every lane keeps the calm stretch clear of floor
  cuts' windows, dash walls, wider gaps' zones, quiet stretches, what the other rules keep in every lane, and every Octodog's
  planned charge window;
- no ceiling over L or the lanes beside it (to its landing zone's end) from the pillar's lead to OVER_MARGIN past the
  walkway's end: nobody rides a ceiling beside it, nor drops off one into its step out;
- no wall-run gap's stretch (`WallRunGapPlacement.keep_out`: its clear run-in to its landing floor, with its margins)
  anywhere in what it keeps, from the pillar's lead to past the walkway's end or the calm stretch's, in any lane, nor
  within its planted cyborg's obstacle margin: the wall-run gaps are placed first, and their own re-check
  (`WallRunGapPlacement.problem`) counts every rule's keep-outs in every lane, whatever lane they name (the weekly
  challenge's Ice Lab week 28 found a walkway's lane keep reaching a wall-run gap's run-in);
- spacing_seconds between two pillars; between the run-up (or the feature's start) and the end-clear stretch.
Plain holes and fences in those windows are taken out to make room (clear_plain_pieces; never a pulsing fence, one a fence
generator powers, or a wall-run gap's hole), and a spot that needs nothing taken out is preferred. An introduction takes the
best fair spot within intro_window_seconds of the feature's start (within test_campaign's introduction reach), one with a
cyborg under it, making room where none fits by taking out pattern ceilings (with their pads and the credits on them) or
plain enemies (`_make_room`; never a feature's last one, nor another feature's introduction); the rest spread through the
level past it, a part each, at a seeded spot. The rules run after every other feature's (RUN_AFTER), on their own random
stream, so a level without the feature builds byte for byte as before.

**The enemy beneath** (plant_cyborg). Under each gantryway the rules plant a plain cyborg (params `stand`, `hold_fire`,
`gantryway`: its id) where the walkway lands on it before a runner who stays in the lane could reach it
(`plant_range`: crush_margin_seconds past where the fastest runner who stays in the lane is at the landing, and as much before
the walkway's far end), keeping a cyborg's obstacle margin and every ceiling's safe floor, holding its fire from
hold_before_seconds before the pillar until the calm stretch is over (CyborgGun.hold), so the dash and the step out are never
shot at. `LevelGenerator.feature_positions` counts it out of the level's own `cyborg` encounters (GANTRYWAY_PARAM), as it does
a cyborg planted in a charge's path.

**What keeps off it after the rules.** `doodad_keep_outs` (the danger density pass, the wider gaps, the cyborgs planted in
charge paths, the zone doodads): the calm stretch in every lane from the pillar's lead, and L to past the walkway's end;
`fill_keep_outs` (the fill pass): the calm stretch; `after_fill` takes the fill pass's holes and fences out of L under the
walkway. `LevelLayout.doodad_between` counts the calm stretch in L (and in any lane with -1), so every enemy that holds an
attack by a doodad holds it there too (a cyborg's bolts, an Octodog's lunge, a heli drone's barrage), and the credits keep
out of it. The dash walls never take a pillar out to make room for themselves (`DashWallRules._fixed_doodad`, as a treasure
stash's doodads).

**On the track.** TrackBuilder builds a Gantryway in the chunk where its walkway starts (`_build_gantryway`; it keeps the
chunk until the walkway's end is behind the player) and its pillar with it: a DashBreakable of kind `gantry_pillar` with a
small zone doodad's body (`_doodad_body`, shared with `_build_doodad`, which leaves pillars to it): the doodad and lane-blocker
layers and a standable top, its entry as its `doodad` meta, so the Player pushes off it, is blocked by its side and smashes it
with the dash exactly as for any doodad (`gantry_pillar_smash`, which plays the doodad's crunch: RunWorld.EVENT_SOUNDS; its
rubble is RunEffects' doodad rubble). Its look rises from that box to the walkway's underside, but its body stays a doodad's,
so the chase camera rides over it as over any doodad (RunCamera.doodad_floor). The walkway itself has no collision: nobody
walks on it or rides it. Its pillar's `smashed` signal calls `Gantryway.fall()`; TrackBuilder relays its signals
(`gantryway_fell`, `gantryway_swept`, `gantryway_landed`).

**The fall** (`Gantryway`, on its own physics clock, so a walkway that hit the runner still lands though the level clock
stops). From the break, for fall_seconds:
- the warning: the creak (`gantry_creak`, at the pillar), the walkway lurching down by `sag` and shuddering for
  `hold_seconds()` while snow and ice shake loose from it ahead of the runner (a RubbleBurst) and the pillar's column breaks
  up; its shadow on the lane (a soft rectangle, darker as it comes down; lighter on the Compatibility renderer) and the
  lane's red line under its whole length (BossProps' lane warning: the floor warnings' red, widening and pulsing, steady
  with Reduced flashing), from the break until it lands;
- the drop, from rest and faster and faster (`drop_seconds()`), then the landing: the walkway swapped for its wreck (flat on
  the floor, under WRECK_HEIGHT, which the runner runs through), its pieces and snow flung out where the camera is, the crash
  (`gantry_land`, at the walkway's point nearest the camera), and the camera's shake (RunWorld, land_shake_*).
Its hitbox (a Hazard: `is_solid`, `armor_blocks_solid` and `passes_after_block`, so the armor or the shield absorbs it and a
hit pays for the whole of it; the dash passes through it as through every hazard) is OFF while it stands, WARNING while it
shudders (no collision), and live only while it drops and as it lands: each tick it spans what the walkway's box went through
since the last tick, less hitbox_inset across, at its ends and at its underside, so a runner under it is hit when it reaches
them (about 0.9 s after the break for one standing) and only on contact; LANDING_TICKS ticks after it lands it's off for
good. Each of those ticks (`swept`) RunWorld destroys every enemy in its path (`Gantryway.crushes`: its middle within the
footprint and ENEMY_REACH, its body reaching into what the walkway went through; a heli drone low over the lane too) with
`Enemy.defeat(&"gantryway")`, a kill the runner's score counts, every kind but a boss's part.

**Its look.** ZoneSkin's hooks, with GantrywayKit's look by default: `gantryway(body, size, look_seed)` (the walkway's box:
its underside at -size.y / 2, railings up to RAIL_HEIGHT above it and icicles down to ICICLE_MAX below allowed),
`gantry_pillar(body, size, floor_y, side, look_seed)`, `gantryway_wreck(body, size, look_seed)`, their colours
(`gantryway_colors()`, `gantryway_palette` by default; the Ice Lab returns its own steel, frost, snow and ice) and material
(`gantryway_material()`), and the colours their pieces fly in (`gantry_pillar_debris_colors`, `gantryway_debris_colors`,
`gantryway_snow_colors`). Every look is lit and never glows (its warning is the Gantryway's own, the same in every zone), stays
inside its box, and **draws in a material that dissolves near the camera** (gantryway.gdshader: an ordered dither from
NEAR_FADE's far end to its near end, the discard last, after every derivative): the chase camera, which follows the runner's
x at camera_follow_x, passes through a pillar's column when the runner is in the lane beside it (an outer lane at 5 and 6
lanes), and under the walkway's edge as it falls. The shader is kit_solid's lighting with only the patterns the kit uses (plain,
ROOF, HULL), so the zones' own solid material and its cost stay as they were. ShaderWarmup draws every part at the load
(`Gantryway.warm_look`, nothing physical in it), and its bursts share RunEffects' rubble material.

**The other wiring.** The first-encounter hint (`gantryway` in `data/hints/hints.json`, HintDirector's `_first_at`: the first
pillar); `LayoutChecks.check_gantryways` (in `check_layout`) re-checks every finished layout on its own: the step-out lanes
clear through the calm stretch, whole floor under the walkway, no ceiling over it or beside it, zone doodads at the level's
spacing from the pillar, and `GantrywayRules.problems()`; `check_doodads` leaves pillars to it. The campaign's schedule lists it
(`test_campaign`: FIRST_LEVEL Frost Foundry, the Ice Lab's NEW_MECHANICS, Frost Foundry out of NOTHING_NEW, and the Golden Zone
leaving it out, LEFT_OUT, DESIGN-TBD as the Terminal's maze stays in the Terminal).

**Tests.** `test_gantryways` (Tests, features; among it every campaign gantryway on real physics on a cut of its level,
pushed into and dashed through), `test_ice_lab_levels` (every Ice Lab build hangs its count, each fair),
`test_generator`'s `_test_gantryways` (quick play's level with the feature over lane counts, seeds, difficulties and both run
speeds), `test_hints`, `test_audio`, and the weekly challenge's suites (an Ice Lab week hangs Sentinel Row's count:
`gantryways` is one of `WeeklyChallenge.GOLDEN_FIELDS`, as the dash walls' count is). `test_doodads` leaves the campaign's
pillars to `test_gantryways`, and carries a level's gantryways into the cuts its campaign runs play on;
`test_ice_lab_skin` leaves a gantryway's parts out of its whole-level scenery checks, as it leaves the doodads and hazards.
DESIGN-TBD: `docs/questions/q3.md`.

**Measured** (`tools/measure/gantryways.gd`, task Q3): the Ice Lab's three levels at 3, 5 and 6 lanes on their own seeds and
three others (36 builds) hang 108 of 108, 106 with a cyborg under them, with no problems; the introduction lands 0.15 to 0.22
of Frost Foundry in. The rules take about 44 ms of a generator build on average and 100 ms at most (a desktop CPU shared
with other runs).
