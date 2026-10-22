# Architecture: teleporters

Part of the architecture notes; the index is [`docs/ARCHITECTURE.md`](../ARCHITECTURE.md).

## Teleporters (the Ice Lab)

Task Q4; GDD §5, Zone 9 (the owner, October 21, 2026): "a teleporter is a square pad with a look all its own, with a
green, slightly space-age antenna on it. Touching it teleports the runner to an output pad further down the track"; "the
first teleporter is safe, to teach the mechanic; later output pads may sit right in front of a gap or an enemy"; "some
teleporters have a left and a right output pad. A light on the antenna, on its left or its right side, shows which one the
runner lands on"; "some antennas' light stays on one side ... Others blink left and right, and the side lit when the runner
touches the pad decides where they land. Level 2 has fixed antennas; level 3 adds blinking ones." GDD §5's proposals are
built as written (the pad fills a lane and is taken by running onto it, never required, output pads within sight ahead in
the pad's look without the antenna, the runner keeps their speed and arrives running with a flash and a sound, skipping
the track in between and what it holds, no protection after landing but never a landing straight into a hazard, a blink
about once a second). The level features are `teleporter` (Relay Station introduces it from 0.15 of the level, Specimen
Vault keeps it) and `teleporter_blinking` (Specimen Vault, from 0.15); a level's counts are `LevelConfig.teleporters` (3 and 4)
and `blinking_teleporters` (2 of Specimen Vault's), DESIGN-TBD. Every number is `TeleporterTuning`'s
(`data/tuning/teleporters.tres`, F6 "Teleporters" in a level that has them; times are seconds of run at the level's speed,
or at the fastest a runner comes onto a pad: the run speed, the dash's bonus and the most a speed pad's or a ramp's boost
adds, `TeleporterRules.fastest`, so a faster zone keeps every window).

**The files.**
- `scripts/enemies/teleporter_rules.gd`: the generator's rules (no patterns, as the gantryways'): where each one stands,
  what it keeps clear, its kind and light, and `problems()`, the re-check of a finished layout;
  `scripts/enemies/teleporter_blinking_rules.gd` only answers `positions()` for the blinking feature (the every-feature
  check and its introduction's).
- `scripts/world/teleporter.gd` (`Teleporter`): one on the track, its pad's trigger, its output pads' nodes and its
  antenna's lamps, and the light's rules (`lit_side`, `lamp_level`, `output_at`).
- `scripts/world/teleporter_tuning.gd` (`TeleporterTuning`) and `data/tuning/teleporters.tres`.
- `scripts/world/skins/teleporter_kit.gd` (`TeleporterKit`): the default look, built from the mesh kit (works on the
  Compatibility renderer).
- `scripts/run/teleport_flash.gd` (`TeleportFlash`): the flash on arrival.
- The jump itself: `Player._teleport` (signal `teleported`, event `teleport`) and `RunWorld._on_teleported` (signal
  `teleported`).
- The data: `LevelLayout.teleporters`, `{id, lane, at, end, side, outputs: [{lane, at, end}, ...] (the left first), light
  (-1, 0, 1), blink (seconds a side, 0 for a fixed light), phase (0-1 of a cycle), calm: [[lane, from, to], ...], span:
  [from, to], seed}` and `intro` on an introduction. `to_dict` lists them only when there are some (a level without them
  is the same data as before), `copy` deep-copies them, `append_pieces` renumbers them; `teleporter_between`,
  `teleporter_by_id`.
- `tools/showcase/teleporter_review.tscn` (Review tools) and `tools/measure/teleporters.gd`.

**Where it stands** (TeleporterRules; its header has the whole list). A teleporter's pad stands in an inner lane P (never by
a side wall: a wall run that ends there never drops its runner onto it), a square `pad_share` of a lane wide, its front at T;
its output pads at L = T + D, one of `hops()` (hop_seconds_min to hop_seconds_max of run: within sight, and within the track
a runner on the pad has built ahead, TrackBuilder.BUILD_AHEAD). Its windows, on a grid of fronts (Plan: difference arrays
by lane and by hop, counted once per plan):
- **the way around**: P and the lane beside it on its `side` hold nothing (no hole, fence, pad's zone, speed pad, ramp's
  run, floor cut's lane window, doodad, floor enemy, nor a lane another rule keeps) from `approach` before T to a lane
  switch's room past its far end (its pad stretch); no ceiling's landing zone reaches either lane from the approach to the
  far end (a rider dropping off a ceiling never lands on it unawares; a ceiling over the pad is no matter: its rider passes
  over it, and the Player takes a pad only from the floor). So it's never needed: a runner who doesn't want it switches out.
- **each landing**: each output pad's lane holds nothing from LANDING_BACK before L to `landing` past it (landing_seconds at
  the fastest: GDD §5's "at least the usual time to react"), and the lanes beside it no doodad or floor enemy for a lane
  switch's room past L. Past that, what the level holds is there: a later one prefers output pads with a hole, a fence or
  a floor enemy in their lane within prefer_hazard_seconds after the landing (GDD §5: "later output pads may sit right in
  front of a gap or an enemy"). Either output pad may be taken (a blinking one's), so both keep the rules (a fixed light's
  too: the unlit one is in view as well).
- **every lane**, over the pad stretch and over each landing: no floor cut's window, dash wall, debris maze block, wall-run
  gap's stretch with its margins (`WallRunGapPlacement.keep_out`: the wall-run gaps are placed first and their own re-check
  counts every rule's keep-outs in every lane), falling gantryway (its pillar's lead to past its walkway and calm stretch),
  Octodog's planned charge, nor what the other rules keep in every lane: nothing that holds the track around the runner is
  under way as they touch the pad or arrive.
- **the introduction** (where the level gives the feature a start: Relay Station; GDD §5: "the first teleporter is safe"):
  one output pad straight ahead in P, its landing intro_landing_seconds long at the run speed, no enemy using the floor in
  any lane over it, and its calm stretch over every lane; the first blinking one where the level gives `teleporter_blinking`
  a start (Specimen Vault) keeps both its landings that safe. Each at the best fair spot within intro_window_seconds of its
  start (test_campaign's introduction reach), else the first one past that.
- spacing_seconds between two pads; the approach past the run-up and the feature's start, the last landing before the
  end-clear stretch.
Plain holes and fences in those windows are taken out to make room (clear_plain_pieces; never a pulsing fence, one a fence
generator powers, or a wall-run gap's hole), and a spot that needs nothing taken out is preferred. The rest spread through
the level past the introductions, a part each at a seeded spot (the best fair spot nearest it, the grid searched outward with
an early stop), then the best of the rest; of the fixed ones past an introduction, one is given two output pads (so a level
that brings in fixed antennas shows one's light; it stands with one where two find no room), each other one two_output_share.
Its light: a seeded side; a blinking one
`blink_seconds` a side from a seeded `phase`. The rules run after every other feature's (RUN_AFTER, the gantryways' among
them), on their own random stream: a level without the feature builds byte for byte as before. About 40 ms of a build.

**What keeps off it after the rules.** `doodad_keep_outs` (the danger density pass, the wider gaps, the cyborgs planted in
charge paths, the zone doodads) and `fill_keep_outs` (the fill pass): its windows, every lane and lane by lane, each widened
by `edge` (half a fence's depth and TOUCH: a pass that keeps a fence's `at` out of a keep-out may stand it right at its end).
`LevelLayout.doodad_between` counts its **calm stretches** (`calm`: the approach in P, each landing in its output pad's lane,
an introduction's landing in every lane): every enemy that holds an attack by a doodad holds it there too (a cyborg's bolts,
an Octodog's lunge, a heli drone's barrage, the hover truck's cannon), on every attempt, and no credit lies there.

**On the track.** TrackBuilder builds a Teleporter in the chunk where its pad stands (`_build_teleporter`; it keeps that
chunk until its output pads are behind the runner): its pad's trigger (an Area3D on LAYER_TRIGGER over the square, kind
`teleporter`, its entry as `Teleporter.META`) and its output pads' nodes, no other collision; the skin dresses them
(`teleporter_pad`, `teleporter_antenna`, `teleporter_output`). Its antenna's lamps are lit on the level clock
(`light_teleporters`, from `update()` and again from `RunWorld._process` after the runner's step, so a frame shows the side
a touch at that moment decides by): a fixed light's side; a blinking one's fading over `blink_fade_seconds` centred on each
change (`reduced_blink_fade_seconds` with Reduced flashing), so the brighter lamp is always the side a touch takes; a
one-output teleporter's beacon.

**The touch** (`Player._check_triggers`, `_teleport`). The feet's sensor, swept back over the frame's run, on the floor and
grounded: a jump over the pad never takes it, a landing on it does, a ceiling rider passes over it. The runner is put on
`Teleporter.output_at(entry, elapsed)` (its only output pad, or the lit side's), as far past its front as they were past
the pad's, in its lane, at once: the same speed (a boost and the dash go on), a slide, the protection and the
invulnerability window as they were (GDD §5, proposed: "no protection after landing"), a lane switch, a bump or a push
stopped in the new lane, a buffered jump and the claims of what they were passing let go. `teleported`, then the `teleport`
event (its sound, `teleport`, generated by `tools/asset_gen/sfx_bank_teleporter.gd`).

**What a teleport skips** (`RunWorld._on_teleported`, in order): `EnemyDirector.runner_teleported` (entries still to come
behind the landing never spawn; enemies in play behind it leave play, but a boss's part and one that keeps its place by the
runner, `Enemy.follows_runner`: a heli drone comes along; every enemy left hears `Enemy.runner_teleported`: a cyborg's
charge-up and a heli drone's wind-up or barrage are called off, so the next one warns from the start, and a heli drone
still waiting to swoop in where the runner skipped past never comes); every shot in the air goes
(`ProjectilePool.clear_shots`); the credits between are passed for good and the stars' best score leaves them out
(`CreditField.skip`, `ScoreKeeper.skip_credits`: taking a teleporter never costs a star nor earns one; the ones the magnet
was pulling are collected); the track is built ahead of the landing at once (`TrackBuilder.update`); the output pad gives
off a sparkle; then `RunWorld.teleported`: the camera cuts across to the runner's new lane (`RunCamera._on_teleported`; along
the track it's level with the runner already) and the flash shows (TeleportFlash: flash_alpha fading over flash_seconds; with
Reduced flashing a soft tint easing in and out, reduced_flash_alpha at most; real time, one ColorRect). Distance, progress
and the HUD follow the runner's distance; the level clock runs on.

**Its look.** ZoneSkin's hooks, TeleporterKit's look by default in `teleporter_colors()` (`teleporter_palette`; the Ice Lab
gives its plate and rim the hall's steel): `teleporter_pad` (a steel plate flush with the floor, a raised rim, an inset green
frame, a four-by-four grid around a hexagonal emitter, corner lights and a floor halo), `teleporter_antenna` (on the pad's
far half, so the runner never reaches it: a slim dark mast ringed with green bands, a green halo ring, a crossbar with a lamp
housing at each end, a green tip; returns its lamps' lit looks, {-1: left, 1: right, 0: the beacon}, hidden until lit) and
`teleporter_output` (the pad, and a marker floating over it at the lamps' height, the hexagon standing up as a glowing ring
with its halo, so an output pad reads 50 to 80 m off, where a flat pad is a sliver). Everything glows green or green-white
(GDD §5: its green is the owner's choice), never a hazard's colour nor the anti-grav pads' cyan; never a column of light (the
anti-grav pads') nor anything across a lane (a fence's). ShaderWarmup draws every part at the load (`Teleporter.warm_look`).

**The other wiring.** The first-encounter hints (`teleporter` and `teleporter_blinking` in `data/hints/hints.json`,
HintDirector's `_first_at`: the first pad, the first blinking one's); `LayoutChecks.check_teleporters` (in `check_layout`)
re-checks every finished layout on its own (the way around and every landing clear, the calm stretches, the landing built
while the runner is on the pad, then `TeleporterRules.problems()`); the weekly challenge (`teleporters` and
`blinking_teleporters` are `WeeklyChallenge.GOLDEN_FIELDS`, so an Ice Lab week stands Sentinel Row's counts, 3 and 1);
endless mode (the zone's last level's counts over its 20 minutes, no introduction: endless gives no feature a start). The
campaign's schedule lists both (`test_campaign`: FIRST_LEVEL, the Ice Lab's NEW_MECHANICS, LEFT_OUT for the Golden Zone,
DESIGN-TBD); quick play takes `--features=teleporter[,teleporter_blinking]`.

**Tests.** `test_teleporters` (Tests, features: the layout, the generator over Relay Station and Specimen Vault, wall-run gaps,
endless mode, the track, the light, real physics from every inner lane at 3, 5 and 6 lanes, what a teleport skips, the flash,
every campaign teleporter on real physics on a cut of its level, the skins, the numbers), `test_ice_lab_levels` (every Ice
Lab build stands its counts, each fair), `test_generator`'s `_test_teleporters` (quick play's level with the feature over
lane counts, seeds, difficulties and both run speeds), `test_campaign`, `test_hints`, `test_audio`, the weekly suites;
`test_ice_lab_skin` leaves a teleporter's parts out of its whole-level scenery checks. DESIGN-TBD: `docs/questions/q4.md`.

**Measured** (`tools/measure/teleporters.gd`, task Q4): Relay Station and Specimen Vault at 3, 5 and 6 lanes on their own
seeds and six others (42 builds) stand 147 of 147, 42 of 42 blinking, with no problems; on their own seeds the introductions
land 0.15 to 0.21 of the level in (on other seeds a 3-lane Specimen Vault's blinking one may find no quiet spot in its
window and come later, 0.35 to 0.61: endless and weekly levels give no feature a start). The rules take about 37 ms of a
build on average and 47 ms at most, and about 0.1 s of an endless-mode Ice Lab build.
