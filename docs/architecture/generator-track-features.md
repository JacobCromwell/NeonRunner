# Architecture: The generator: gaps, doodads, floor cuts, wall fences, wall gaps, wider gaps, dash walls

One part of the architecture notes; `docs/ARCHITECTURE.md` is the index of every part and topic.

## The generator (continued)

**City 1's additive floor gaps** (approved answers in `docs/USER_REQUESTS.md`: 30% more encounters
**and** 30% higher mean missing lanes per encounter, increasing density rather than replacing
fences/signs). Only `city_1.tres` enables `LevelConfig.gap_encounter_increase` and
`gap_lane_increase`, both 0.3; defaults are zero, so other levels and their random streams are
unchanged. `GapDensity.apply()` runs after doodads and wall fences, before credits. It preserves
every original gap, pattern pick, fill, enemy, sign, fence and doodad. It adds separated gap rows in
earliest-fit floor windows, then widens the narrowest eligible rows, using its own seeded lane-choice
stream (`rng_for("gap_density")`). Rows group equal start/end distances; a staggered extension of an
existing hole never counts as an additional encounter.

For a build with **R** original rows and **G** original lane-gaps, the encounter target is
`ceil(R × (1 + gap_encounter_increase))`. The mean-width target is
`(G / R) × (1 + gap_lane_increase)`; after actual row placement, the integer lane-gap target is
`ceil(actual_rows × mean_width_target)`. This independently rounds up both requested dimensions;
increasing the total lane-gaps alone is not success. New gaps use the shortest original row's
length (already jumpable), fit outside the unchanged intro/finish buffers, and keep the existing
hard-spacing time from **every** other gap row. Lane-specific clearance keeps that same margin from
fences; enemy keep-outs, ceilings/pads/landings, ramps, cuts, speed pads, doodad pushes and wall-fence
drop windows are protected. A widening keeps off a zone doodad's window (a lane switch's room before its
push's lead to the level's spacing after it, in every lane: task L6) and, with the margin, the doodad's own lane, which is then
never the lane the row leaves open; not the margin around it in every lane (FIX4). The doodads already
keep that window clear of every row, so with the margin everywhere a doodad decided which rows widened
and City 1's doodads moved its extra gaps (at 5 lanes, a widening went to another row), when doodads
only add to a level (`test_doodads`). New rows and full-width jumps keep the margin from doodads too.
Signs can have a new floor choice below them without being replaced.
New/widened rows leave at least one grounded lane clear through the reaction window, or allow
the existing patterns' full-width jump route only when every lane has a clear run-up and landing
and the row is within `max_gap_jump_fraction`. Existing all-lane rows remain unchanged. Lack of
separated placement room, lane capacity or clearance may limit a target:
`LevelGenerator.gap_density_result` reports baseline, target and
actual counts plus explicit constraint messages (empty when the pass is disabled). It never removes
an obstacle, lengthens the level, relaxes clearance, or claims a constrained mean met the target.

City 1, campaign default tier, seed 101, still **55 seconds** (1,155 m at 21 m/s):

| Lanes | Rows before → after | Lane-gaps before → after | Mean before → after | Rounded targets: rows / lane-gaps |
| --- | --- | --- | --- | --- |
| 3 | 11 → 15 | 11 → 20 | 1.000 → 1.333 | 15 / 20 |
| 5 | 15 → 20 | 24 → 42 | 1.600 → 2.100 | 20 / 42 |
| 6 | 13 → 17 | 25 → 43 | 1.923 → 2.529 | 17 / 43 |

These shipped layouts meet both dimensions without a constraint. `test_city_gaps` builds the
baseline by copying the config and disabling only these tunables, verifies independent targets,
preserved obstacles/picks, determinism, buffers, jumpability, separated encounters, enemy/doodad
fairness and a conservative full-level `FloorRoute`, and exercises seed/tier and constrained cases.
The seed 1–8/default-tier and seed 101/all-tier sweep at 3/5/6 lanes has one conservative-clearance
shortfall: 3 lanes, seed 101, difficulty 0.20 reaches its 11-row target, but only 25 lane-gaps
(mean `25 / 11 = 2.272727…`) versus a mean target of 2.275, which rounds up to **26** lane-gaps.
The remaining lanes cannot be widened while retaining a grounded route or clearing every lane
for an isolated full-width jump with the existing hard-spacing margin. The report explicitly
marks this as constrained, not as a 30% mean increase. An all-lane, no-room fixture also verifies
both shortfalls are reported rather than silently weakening either target.
Credit placement naturally sees the new gaps; no reward, credit, price or duration tuning compensates
for them. The owner approved lower earnings from shortening as intentional and requested economy-test
updates rather than compensation (`docs/USER_REQUESTS.md`). The current measured progression is
documented under the economy below.

**Zone doodads** (G5; GDD §3, owner's playtest September 30, 2026: the owner's other answer to "too
barren": scenery pieces standing in lanes, specific to each zone, that never hurt; running into one
pushes the player into a neighbouring lane, the side with room, a side chosen per doodad when both have
it). `LevelLayout.doodads` holds {lane, start, end, size, side, seed}: a size class
(`LevelLayout.DOODAD_SIZES`, small, medium, large; `MovementTuning.doodad_size()` gives its box, the
skin its look), the side it pushes to and a number to vary its look by (a row's doodads also hold `row`
and `look`: Doodads in rows, below). The list is left out of
`to_dict()` when it's empty, so a level without doodads is the same data as before. `_place_doodads` runs
after the fill pass and before the credits, on its own stream (`rng_for("doodads")`; with
`LevelConfig.doodad_share` 0 it draws nothing and the level is built byte for byte as before), so
doodads only add to a level: they take a lane rather than needing a reaction, and nothing after them can
undo or crowd them (but a dash wall, below, which takes out the ones in its way when a level is short of its
walls).

**What a doodad keeps clear, lane by lane** (task L6; the owner after playtesting task L3, October 17, 2026: "The
doodads are too rare ... Why do the doodads require so much space? Is there a rule around it? To me, they do not add
much extra difficulty, if any at all, so we shouldn't have a rule there for fairness' sake"). Until then a doodad stood
only where nothing went on in any lane from its push to the level's spacing past it, `doodad_gap_seconds` (2.5 s) from
the next, after the fill pass, so it got only the leftovers. Now it keeps what fairness needs, lane by lane, and
`LayoutChecks.check_doodads` holds every generated layout to it at 3, 5 and 6 lanes. For a doodad (a row as one, from
its first front to its last end), with its push's lead (`doodad_lead_for()`, the push's time at run speed) before its
front and `doodad_lane_room()` (a lane switch at run speed and `DOODAD_LANE_MARGIN`, 3 m) around it:
- its own lane (`doodad_lane_busy()`: holes, fences, pads, speed pads, a ramp's outer lane to where its wall run drops
  the runner back, floor cuts' lane windows, the floor its enemies use) holds nothing from that room before its push to
  the level's spacing past its end (`doodad_after()`): what it hides from the chase camera comes no sooner than between
  two patterns (A runner who dashes through a doodad, below), and no other doodad stands there;
- the lanes beside it hold none of that from that room before its push to that room past its end, and the lane it
  pushes into none until `LevelConfig.doodad_reaction_seconds` (0.5 s) past the push (`doodad_landing()`): the push
  lands on clear floor (a front corner caught mid-switch pushes back into the other lane beside it, clear too), a
  runner beside it never has to dodge into its lane, and a runner further out keeps a free lane on their side of it,
  so it never takes away the only way past a row of holes or fences. Lanes further out hold whatever the level put
  there: a hole or a fence two lanes over;
- nothing kept in every lane reaches it from its push's lead to that room past its end (`doodad_keep_outs()`,
  `doodad_reach()`): every enemy's stretch as the fill pass keeps it (its attack as the runner closes in, or what its
  rules keep: a drone wave until its first pad, a hover truck's shortest stay, a Resonator's visit), since the enemies'
  own fairness checks hold an attack back while a doodad stands anywhere along it (below), or a longer one its rules
  keep the doodads alone off (`doodad_enemy_keep_out`: a Resonator's visit and the waits its rules leave it after, to
  where the next visit may begin, `ResonatorRules.doodad_keep_out`: a first pulse a wait moved on is never dropped,
  and a doodad right after the visit left Golden 1's second Resonator at 5 lanes no clear floor before the next one
  sent it away); every floor cut's window (GDD §9.9: nothing else goes on meanwhile); every dash wall's footprint;
  every ceiling from its start to the end of its landing zone and every pad's zone (the chase camera rides below a
  ceiling, lower than a doodad's top); the
  level's quiet stretches (The Hush); each wider gap's zone (`WideGapPlacement.keep_outs`: the only demand from its
  take-off margin to its landing margin); and what the rules keep: a rules script may declare `static func
  doodad_keep_outs(gen) -> Array[Dictionary]` with entries {from, to} (every lane: the host rules' Bad Dream chases, a
  Gilded Sentinel's strike, a wall-run gap's clear stretch, a treasure stash's floor), {lane, from, to} (that lane,
  which no doodad stands in or pushes into: a hover truck's, until it has left; its `keep_out` already keeps every
  lane for its shortest stay; a floor cut's lane window goes there too) or {from, to, calm: true} (a calm stretch in
  every lane: an Enforcer Truck's showing window, task C6c: no doodad nor its push's lead stands in it, but it keeps no
  room around it);
- in an inner lane, pushing into a side with room (seeded when both have it), or, since task L3, in the outermost lane
  by an open side wall, pushing inward (The lane by a side wall, below);
- `doodad_gap_seconds` (0.6 s; 2.5 s before task L6) from one's end to the next one's front, so the next clears the
  last one's push; closer than the level's spacing they stand two lanes apart at least: never in the lane beside, where
  a push from the one would land (no slalom), nor in its lane, which it hides;
- where the danger density pass ran, never in the only lane its pieces leave a player to come to it in
  (`DangerDensity.doodad_ok`).

The level is walked in spots `LevelConfig.doodad_spot_seconds` (1 s) apart from `doodad_start`; each spot with room
for one gets one with the level's `doodad_share`, its front at a seeded place in the spot, in a size class its weights
allow (`doodad_*_weight`) that fits there. (Before task L6 each free stretch got one with the share and the next spot
in a long stretch the same chance, which would have left a level's long free stretches nearly empty once the room is
counted lane by lane.) Floor credits keep out of them (`DOODAD_CREDIT_MARGIN`). `FloorRoute` keeps out of a doodad's
lane where it stands; built with `pushes` (`check_doodads`, `check_buzz_company`), a runner who comes into the stretch
before its front where its push begins (running, landing, ending a slide, or in the middle of a jump or a slide) is
pushed into the lane on its side, as the Player is, and `check_doodads` asks of every doodad near anything else that
from every lane a floor route found from the clear stretch before it without the zone doodads still goes with them:
no doodad takes away the only way out of anything. City 1's extra gaps (`GapDensity`, after the doodads) keep off each
doodad's window in every lane, from that room before its push to the level's spacing past it. The dash walls after the
doodads keep off its push's lead and that room past it (`DashWallRules.doodad_span`, as the doodads keep off a wall
before them); a level the doodads leave short of its walls takes out the ones in the way of the rest
(`DashWallRules._clear_doodads`: scenery, before any feature gives way; a row goes whole). DESIGN-TBD
(`docs/questions/g5.md`, `docs/questions/l6.md`): each level's share (City 1 brings them in gently: small and medium
ones only, from a fifth of the way in, rows a quarter as often), what a doodad keeps clear, the spots, the gap and the
sizes.

Enemies whose attacks a doodad could make unfair (its side blocks a dodge, its push moves the player)
count them at runtime too, through `LevelLayout.doodad_between()`, for an attack that could come later
than the generator planned it: a drone holds its barrage and a hover truck its cannon while a doodad
stands in the stretch the attack would take (`_doodad_in_reach`; a drone holds it for a fenced ceiling's pick too,
`_pick_in_reach`, task I4), an Octodog charge or a Resonator pulse
moved on by a wait for its turn waits (`Octodog.window_clear`, `Resonator.pulse_clear`), cyborg bolts
never land by one (`CyborgGun.path_clear`), a cyborg's walk and panic run keep their margin from one
(`CyborgRules.obstacle_spans`), and a hover truck only lurches at a player who can leave its lane
(`_escape_ok`). Those checks count a doodad in any lane, so the generator keeps doodads off every enemy's attack in
every lane (task L6 kept that: letting them stand beside an attack in a far lane needs the checks made lane-aware
first, or the attacks would be held back more often; `docs/questions/l6.md` 4). Measured at task G5 with the level
data (`tools/measure/level_pace.gd`, each level's own seed and
four others at 3, 5 and 6 lanes, against the same levels with `--set=doodad_share:0`): every row, enemy
and big attack as before (a credit inside a doodad goes, one or none a level), 3 to 15% more events a
minute (doodads a minute: City 1 2.8, the rest of the City 4.5 to 5.3, Gangland 2.7 to 4.4, the
Marketplace about 4, Corporate about 3, Dead Zone 1 2.3, The Hush 1, the Golden Zone 2.5 to 3), the mean
empty stretch down from 1.2–1.45 s to 1.0–1.3 s. The longest empty stretches stay about as they were:
they lie under ceilings or around enemies, where doodads never stand. Before task L3 a runner who kept to
the middle lane at 3 lanes met every doodad (they all stood there); since then about four in ten of them
(The lane by a side wall, below).

Measured at task L6 (`tools/measure/level_pace.gd --doodads`, each level's own seed and four others at 3, 5 and 6
lanes, 405 layouts, before the task and after it): doodads a minute (a treasure stash's left out) and rows a level:

| Zone | 3 lanes | 5 lanes | 6 lanes | Rows a level at 3 / 5 / 6 lanes |
| --- | --- | --- | --- | --- |
| City | 5.2 → 5.9 | 4.3 → 9.7 | 4.0 → 9.9 | 0.1 / 0.1 / 0 → 1.7 / 2.9 / 3.3 |
| Gangland | 3.8 → 5.8 | 4.0 → 8.1 | 3.8 → 8.7 | 0.3 / 0.3 / 0.3 → 2.7 / 3.5 / 3.9 |
| Marketplace | 2.9 → 6.0 | 3.6 → 7.0 | 3.7 → 7.2 | 0.3 / 0.3 / 0.4 → 2.6 / 2.6 / 2.7 |
| Casino | 2.4 → 4.4 | 2.6 → 6.3 | 2.4 → 5.1 | 0.3 / 0.2 / 0.4 → 2.2 / 2.8 / 2.0 |
| Corporate | 2.6 → 4.0 | 2.2 → 5.5 | 1.9 → 5.6 | 0.7 / 0.5 / 0.1 → 1.8 / 2.4 / 2.7 |
| Beach | 2.0 → 4.9 | 1.9 → 5.3 | 1.6 → 5.4 | 0.4 / 0.4 / 0.3 → 3.0 / 2.7 / 2.7 |
| Dead Zone | 0.8 → 1.7 | 0.9 → 1.9 | 1.1 → 2.6 | 0.2 / 0.4 / 0.3 → 1.1 / 1.0 / 1.6 |
| Golden Zone | 1.7 → 3.4 | 1.4 → 2.9 | 1.6 → 3.6 | 0.4 / 0.1 / 0.5 → 1.9 / 1.6 / 2.2 |

City 1 went from 2.8 to 4.9 a minute over its lane counts (its share 0.15 and rows a quarter as often keep it the
gentlest), City 2 and 3 from about 4.8 to 9 (their shares as they were: the room lane by lane is what grew). The Dead
Zone stays the sparest: what every lane keeps (its enemies' attacks, its ceilings, The Hush's quiet stretches) covers
most of its levels (`docs/questions/l6.md` 4). Every row of holes or fences, enemy, big attack and mechanic is as
before (but where a dash wall, placed after the doodads, now stands elsewhere and takes out other plain pieces: 0.1 a
minute more or fewer rows in four levels); events a minute up by 0.3 to 4.6 (the doodads), the mean empty stretch down
by 0.01 to 0.1 s, the longest about as it was; a runner who ignores them takes 0.8 to 2.0 pushes a minute (0.6 to 1.2
before; The Hush 0.3 both times). Rows come 1.6 to 3.9 a level from Gangland on (1 to 1.6 in the Dead Zone),
nearly nine levels in ten with one at least (335 rows of two, 200 of three and 160 of four over the 405 layouts, 305
of them spaced), holding 43 to 68% of the doodads by zone and lane count (2 to 67% before); half the doodads are small
ones (29% medium, 21% large; about nine in ten small before: the free stretches held little more), and 32 to 81% stand
by a side wall (29 to 73%), but on the Beach, whose open walls come first: 18 to 59% there (`doodad_wall_lane_share`
0.15, The lane by a side wall, below).
What they cost (the owner asked whether more doodads hurt performance; `tools/measure/doodad_cost.gd`: every campaign
level's own build at 3, 5 and 6 lanes with its zone's skin, chunk by chunk as a run builds it, the minimum of three
passes, before the task and after it; `tools/measure/frame_times.gd` headless on City 2, Gangland 3 and Golden 2, the
levels with the most doodads and the busiest late one, at 5 and 3 lanes; and its renderer counts under xvfb): over the
57 builds a level holds 12.1 doodads where it held 5.7, and a chunk's build takes 1.80 ms on average where it took 1.85
(2.86 ms at the most where 2.90: the runs' noise), with 17.7 mesh surfaces (each a draw call when on screen) and 7.4
collision objects where it had 17.6 and 7.2: a doodad is one surface and two static bodies (its box and its lane
blocker). The track a run keeps built (from behind the runner to what it builds ahead) holds at the most 6.3 doodads at
once where it held 4.7 (a treasure stash's among them), 70.6 collision objects where 69.7 and 172.4 surfaces where
172.3; the most any build's doodads add over the same build without them is 10 doodads, 15 collision objects and 8
surfaces. The frames are as they were: medians 1.0 to 1.2 ms before and after on every level and lane count, 99th
percentiles 2.2 to 3.0 ms within about 0.1 ms of each other, the worst frames an Enforcer Truck's spawn as before (measured
before the Beach's wall lane share and the Resonator's waits, which only take doodads away). City 2's first 20 s at 5
lanes draws 249 calls a frame (the median) where it drew 246 on Forward+, 261 where 258 on Compatibility, and 305 and
321 at the most both times. On a phone or in the web demo it doesn't matter: a few more static boxes on the track,
built with their chunk, are a few more draw calls among about 170 to 300 and a few more static bodies among about 70.

**Doodads in rows** (task L3; the owner, October 17, 2026: "occasionally ... rows of similar doodads: three plant
doodads one right after the other, or three market stalls, one followed by a space, followed by another stall";
items 942-947 in `docs/OPEN_QUESTIONS*.md` 1 and 4). A doodad `_place_doodads` draws is, with `LevelConfig.doodad_row_chance` (0.5), the
first of a row (`_row_shape`, from a stream of its own, `rng_for("doodad_rows")`): `doodad_row_min` to
`doodad_row_max` (2 to 4 since task L6, the owner: "could it be two in a row so it doesn't take up as much room?";
3 to 4 before, the owner's examples being three long) of its size class, in its lane,
pushing to its side, either one right after the other (`DOODAD_ROW_TOUCH`, 5 cm apart: their boxes' faces, and the
pictures on them, never lie in one plane) or with a doodad's length between each two, by size class
(`LevelConfig.doodad_row_spaced`: `doodad_row_spaced_small` 0, `_medium` and `_large` 1, so small ones touch like the
owner's plants and medium and large ones stand apart like the stalls), as many as fit in the stretch's room (with a
sliver to spare, so a row never meets what's either side to the centimetre), down to `doodad_row_min`, else one
doodad. Every rule above holds
for the row as one doodad from its first front to its last end: its lane and push side fit along all of it, the
danger density pass's route check (`DangerDensity.doodad_ok`) takes its whole stretch, and the next doodad comes
`doodad_gap_seconds` after its last. Each of its doodads is an entry of its own with `row` (its stretch, [start,
end]) and `look` (its first one's seed: the track builder dresses each with it, so a row is one kind, three palms,
never a palm, a bush and a palm; each keeps a `seed` of its own, which its pieces fly by when the dash smashes it).
`LevelLayout.doodad_extent()` gives a doodad's row's stretch, and every check that counts doodads counts a row whole,
the spaces between them too (no runner goes in there, between a side that blocks the switch and a front that pushes):
`doodad_between()` (every enemy's runtime check, the floor credits), `CyborgRules.obstacle_spans`, `EnforcerTruckRoom`,
`FloorRoute`, the wall fences and the side wall gaps; `BossArena.shifted` moves a row's stretch with it, and a dash
wall that takes out the zone doodads in its way (`DashWallRules._clear_doodads`, task L6, and its last resort,
`_take_out`) takes a row out whole. A row is
never a slalom or a wall of doodads (one lane, a lane always free beside it), and the dash smashes along it as far as
it lasts, the next one pushing as usual (`test_doodads`). At task L3 most doodads were small ones (a level's stretches
left room for little more, about nine in ten before that task too), so nearly every row was three or four small ones
touching: a spaced row of three takes five doodads' lengths, 18 m of medium ones and 32.5 m of large ones, which the
levels' free stretches seldom held (2 of the 41 rows over every campaign level's own seed and two others at 3, 5 and 6
lanes; 68 rows, 31 of them spaced, before the review set three and the spacing by size class); the City's levels,
whose free stretches held one small doodad at a time, had almost none. Since task L6 (rows from two, the room kept
lane by lane) a level has a few, nearly half of them spaced, in every size class (Zone doodads, measured at task L6,
above).

**The lane by a side wall** (task L3; the owner, October 9, 2026, held until the dash smash (H5) and the generator
work (I4) were done: "doodads prefer the lane next to the side wall when it's open, without costing gameplay: not where
the generator already has something on that part of the wall or needs it open"; items 942-947 in `docs/OPEN_QUESTIONS*.md` 2, 3, 5 and
6). A doodad (or a row) takes the outermost lane by an open wall with `doodad_wall_lane_share` (0.6; either wall,
seeded, when both are; the only choice where no inner lane fits), pushing inward (`_add_doodads`, the stream of the
rows). The Beach's levels take it less often (0.15, task L6: their open walls, task D10b, come first, and a doodad by a
wall keeps the wall gaps off it; with L6's doodads at 0.6 the median wall stood on 55.0% of a Beach level, past
`test_beach_levels`' 45-55%, and at 0.15 on about 54%; `docs/questions/l6.md` 7). Open is `wall_lane_keep_outs(side)`: nothing on that wall within `doodad_wall_clear_seconds` (1 s) of it (a
sign, a wall enemy as the fill pass keeps for it or a window cyborg's window, a Gilded Sentinel's wall section, a ramp
from its foot to the end of the longest wall run it launches, `WallFencePlacement.ramp_run_end`, a wall-run gap's lit
wall); no dash wall's wall route (in its footprint, which every doodad keeps from), no wall fence's drop window and no
side wall gap beside it or starting within `doodad_wall_drop()` before it (the fall from the highest wall run and the
push's lead: a wall runner dropped off comes down in front of it); on neither wall where the level brings in wall
fences, from their feature's start to `intro_seconds` past it with the drop windows there (the introduction comes on
either wall within that, `test_wall_fences`, and a doodad by a wall there would push it late); and its own lane and
the lane beside it clear around it, as for every doodad (task L6; every lane until then), so no wall run is launched by
it or needed there, and free entry from its lane only waits until it's past. The wall fences and side wall gaps come
after the doodads and keep off them in turn (`WallFencePlacement.keep_outs`' drop windows,
`WallGapPlacement.keep_outs`), and no wall credit lies within
`DOODAD_WALL_CREDIT_MARGIN` (3 m) of one (`_drop_unsafe_credits`; the wall-hop credits to come, GDD §7, keep off them
the same way). A wall runner's body reaches into that lane, and a free entry or the slide down leaves every runner
low on the wall, so placement alone can't keep them apart (the wall hop keeps a runner on a wall as long as they
like): one low enough to meet it breaks it as they reach it, as the dash smashes one, and runs on
(`Player._check_wall_doodads`; Damage and interactions), while one high enough (a ramp's launch) passes over it
standing; and one who has just left the wall (its end, a wall jump, a move back toward the lanes) breaks one by it
in their way too, rather than being pushed back through it (`Player._off_wall`). `LayoutChecks.check_wall_lane_doodad`
holds every doodad by a wall to all of this, and `check_wall_fences` keeps the drop windows off them.

Measured (`tools/measure/level_pace.gd --doodads`, each level's own seed and four others at 3, 5 and 6 lanes, against
`--set=doodad_row_chance:0;doodad_wall_lane_share:0`, which builds all 405 layouts, quick play's too, byte for byte as
before the task; measured again after task L3's review and the L2 merge): every row of holes or fences, enemy, big
attack and mechanic as before; doodads a minute up (rows add doodads, and the wall lane gives a spot where no inner
lane fitted): the City 4.0–4.7 to 4.0–5.2, Gangland 3.0–3.5 to 3.8–4.0, the Marketplace 2.6–3.1 to 2.9–3.7, the
Casino 1.8–2.5 to 2.4–2.6, Corporate 1.6–1.9 to 1.9–2.6, the Beach 1.3–1.5 to 1.6–2.0, the Dead Zone 0.5–0.8 to
0.8–1.1, the Golden Zone 1.1–1.3 to 1.4–1.7; rows a level 0 to 0.1–0.7 outside the City (0 to 0.07 there), 48 of
three and 35 of four in the 405 builds, holding 9 to 41% of the doodads (67 and 52% at the Dead Zone's 5 lanes and
the Golden Zone's 6, whose few doodads make a few rows a large share; 17% over all); 29 to 73% of the doodads by a
side wall (55% over all); events a minute up by 0 to 0.8 (1–2%); wall fences a level as before (at most 0.3 fewer);
open side wall as before but on the Beach, whose open walls stand 1 to 4% more around its doodads by them. A runner
who keeps to the middle lane takes about half the pushes it took (the tool's middle-lane pushes, over 3, 5 and 6
lanes: the City 1.4–2.6 a minute to 0.5–1.1, the Marketplace 1.3–1.5 to 0.7, the Golden Zone 0.7–1.2 to 0.5–0.9).

**A runner who dashes through a doodad** (task H5; the dash smashes one: Damage and interactions, "The
dash smashes a zone doodad"): a doodad is 2.6 m tall and hides its own lane right behind it from the
chase camera, which a runner it pushes never reaches in that lane; a dash shows it only at the smash, and
goes on at the dash's speed (+8 m/s).
The placement keeps the level's spacing after every doodad clear in its own lane (`doodad_after()`, at least
`spacing_seconds_hard`, 0.9 s at run speed; in every lane until task L6), so it needed no rule of its own: what a
doodad hides is in its own lane, and the lanes beside it stay clear a lane switch's room past its end. Measured at task
L6 over every campaign level at 3, 5 and 6 lanes (`test_doodads`' `_test_dash_fairness`, each level's own build, a row
as one: 108, 179 and 152 doodads and rows), the first thing after a doodad in its lane (a hole, a wider gap, a fence, a
pad, a speed pad, a floor cut's lane window, an enemy standing in it, another doodad) comes at least 0.77, 0.75 and
0.75 s after its front at 3, 5 and 6 lanes at the dash's speed (medians 1.7 to 2 s), and 0.72, 0.70 and 0.70 s after
its end (a runner who dashed into its side near its end sees it there at the latest; medians about 1.5 to 1.7 s),
against the 0.49 s a reaction (0.35 s, the suites' bots) and a lane switch take. The suite holds every campaign doodad
to both. What every lane keeps (an enemy's attack, a ceiling, a floor cut's window, a Bad Dream's chase) comes at least
0.20 s after a doodad's end at the dash's speed (medians 0.7 to 0.9 s): in full view in the other lanes, each with its
own warning (before task L6 the first thing in any lane came at least 0.72 s after a doodad's front, medians about 0.8 s).

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
it (`doodad_keep_outs`' lane keeps), floor credits skip it, and `floor_clear()` counts it as a hole. The
one pass that comes into a cut's window is a Buzz Overdrive's company (task L2; The generator, Company for the
Buzz Overdrive): it keeps every rule above (its lane, its whole lanes, its escape) and a lane beside it clear
over its attack, and its cyborgs are the other exception to "nothing else going on" (`cut_problem` and
`check_cuts` leave them to `check_buzz_company`, as they leave a parked tank's planted cyborg to
`check_charge_paths`).
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
on the arena's track), and add it through `arena.add_pieces()`, its whole stretch past `stream_from()`, so
about ten seconds ahead (the Buzz Overdrive's own plan: `buzz_overdrive_rules.plan_for`), with its cause
in its `enemies`, or, as Hostile Takeover's drop does, the cut alone and its cause brought into play with
`spawn_enemy` at the cut's end when it arrives (the tank finds its cut by its lane and end, `cut_of`). A
cut whose cause never comes stays whole: only its cause runs it. A track that grows during play (`TrackBuilder.extend_layout`, endless mode's R4 too) takes cuts
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
  wall is one of their escapes; the fill pass keeps its extra obstacles off them the same way). A Buzz Overdrive
  with company (task L2, the owner's "laser fences" with it; its cut carries `BuzzCompanyPlacement.CUT_KEY`) is the
  exception: its runner escapes along the floor into the lane beside its cut and a wall runner is safe from it, so
  its cut and its rev keep only the drop rule above (its lane window in the outer lane beside a fence);
- the level: its drop window between the run-up and the end-clear stretch; other wall fences
  `same_side_gap_seconds` apart on one wall (a wall run meets one at a time) and `gap_seconds` on either.
Zone doodads in inner lanes need no rule: they push only into neighbouring lanes, never onto a wall, and a wall
fence never reaches a floor runner, so the two never meet (G5's keep-outs stand as they were). One by a side wall
(task L3) is the floor beside it: a wall fence's drop window keeps off its whole row, as off a hole in that lane.
How many: from the feature's start a spot every `spacing_seconds_easy` to `_hard` of run (by the difficulty
there, `spacing_jitter` either way), on a random wall (the other if it has no fair spot within
`search_seconds`), at the first fair spot from there; past `wall_fences_partial`'s start `partial_share` of them
cover the low or the high band. Each pulses with on and off times from easy to hard and a random phase. A level
that gives a feature a start introduces it gently (Marketplace 2's full-height ones at 10%, Corporate 1's partial
ones at 50%, `feature_starts`): its first one is the introduction, at the earliest fair spot on either wall within
`intro_seconds` of the start where no enemy is about (else the earliest fair one there, and only if none comes in
time, a later one; a long big attack can hold it back, which stays rare), alone (no other wall fence within
`same_side_gap_seconds` on either wall, and off every floor cut's window, a Buzz Overdrive's with company too: task L2's
review, where 6 of 63 builds of Corporate 1 had put it in one's attack) and off for `intro_off_seconds`, with its
first-encounter hint on
the level introduction (HintDirector: `wall_fence`, `wall_fence_low`, `wall_fence_high`). Every feature appears: the guarantee
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
number in `WallFenceTuning`, the bands and the reach, partial ones pulsing too, and keeping off big attacks
(items 933-941 in `docs/OPEN_QUESTIONS*.md`: running by a Buzz Overdrive with company, where they come about 2.3 times as often as
elsewhere in Corporate 1, the danger density pass's wall half filling the room that opened).

**Wall fences on the track.** `TrackBuilder._build_wall_fence` builds each as a Hazard in the chunk where it
stands: its hitbox `WallFencePlan.hitbox` (from the wall face out by the reach, over its band, a fence deep),
electrical, on the hazard layer only (Damage and interactions), pulsing on the level clock like a pulsing floor
fence (`Hazard.setup_pulsing` with its on and off times and the floor fence's warning, and the floor fence's
crackle from `HazardTelegraph`), switched off for good by an EMP (`disable_fences_near` also reaches wall fences
within its radius, measured from their wall face, built or not yet built), and dressed by the skin
(`ZoneSkin.wall_fence`, Zone skins). `track.wall_fence_hazards()` lists the built ones. A track that grows during
play (`extend_layout`) takes wall fences too, and a boss arena carries them (`BossArena.shifted`, `add_pieces`,
`wall_fence_problem`).

The Gilded Sentinels (task C4) come before the wall fences: `WallFencePlacement.keep_outs` keeps a wall fence
off a Sentinel's wall section (`sentinel_wall_section`: its wall-run approach to past what it cuts), and its
whole attack is in the rules' keep-outs in every lane (`gilded_sentinel_rules.gd`'s `doodad_keep_outs`), which
every drop window keeps off like a Bad Dream's chase; `LayoutChecks.check_wall_fences` checks both. A
Sentinel's own rules also refuse a wall fence on its wall section, for a track where one came first.

For task E5a (The House, GDD §10: phase 2 puts one 7 button on a wall "with wall fences in play"): plan the
phase's wall fences as `WallFencePlan.make` entries at the arena's speed (`arena.tuning`), ask
`arena.wall_fence_problem(entry)` for each (the level's rules on the arena's track; a button on a wall is the
boss's own business: keep the button off a live wall fence's band and timing, and its approach off its drop
window), and add them with `arena.add_pieces()` (their `wall_fences`), past `stream_from()`. A wall fence on
the button's wall should let the player reach the button by timing or by entering high or low (a partial one
over the band the button isn't in). The wall fences pulse on the level clock like any; one the fight must
switch on or off at a moment of its own can be found with `world.track.wall_fence_hazards()` and held with
`Hazard.set_enabled()` (the EMP's way), never by another path, so DamageRules and the looks stay as they are.
Task E5b-a does the same for Hostile Takeover's partial wall fences along the sound barriers (`HostileTakeoverBoard`). E5a-b does
it in `TheHouseWalls` (see The House under Bosses): full-height wall fences, the wall run over the button
timed through their off windows, and the machine's strikes kept off their drop windows.

**Side wall gaps** (the `wall_gaps` feature, every level from Gangland 1 on; owner's answers in
`docs/USER_REQUESTS.md`). `LevelLayout.wall_gaps` holds {side, start, end} (left out of `to_dict()` when empty):
a stretch [start, end) where that wall has no wall-running surface. The interval queries are
`wall_supported(side, d)` (static `wall_supported_in` for a bare list), `wall_gap_between`, `wall_solid_pieces`,
`wall_gap_pieces` and `wall_gap_spans`. The generator places them after the wall fences and before
GapDensity and the credits (`WallGapPlacement` in `scripts/world/wall_gap_placement.gd`), from a stream of
their own (`rng_for("wall_gaps")`), so a level is otherwise exactly the same without them, apart from the
wall credits a gap takes (`_drop_unsafe_credits`). They are rare: one about every `spacing_seconds_easy` to
`_hard` seconds, `length_seconds_min` to `_max` long, a `bilateral_share` of them over the same stretch of
both walls (`data/tuning/wall_gaps.tres`, seconds at the level's run speed). Each wall keeps clear of the
run-up, the end-clear stretch, signs, wall fences, wall enemies (a Gilded Sentinel's whole wall section),
ceilings over the outer lane, and a ramp's launch and longest wall run (`WallGapPlacement.keep_outs`, each
widened by `clear_seconds`). The outer lane beside a gap is deliberately not kept clear: the owner wants
players to read gaps coming. The one exception (task L3) is a zone doodad by that wall: the wall stands beside
it and from `LevelGenerator.doodad_wall_drop()` before it (the fall from the highest wall run and the push's
lead), so a runner dropped off never comes down on one. A level with the feature always gets at least one gap. Boss arenas get none
(`BossArena.base_config` strips the feature and `WallGapPlacement.is_boss_arena` refuses an `_arena` config)
unless an arena opts in: its config lists the feature and carries numbers of its own,
`LevelConfig.wall_gap_tuning` (`WallGapPlacement.tuning_for(config)` reads them; null for every level, which
uses `data/tuning/wall_gaps.tres`). Only the Sleep Taker's arena does (task H9, owner, October 8, 2026: "the
walls aren't safe"; task H11, October 10, 2026: more again; `data/bosses/dead_zone_boss_wall_gaps.tres`, about
33 gaps a minute), and
`BossArena.shifted` carries a lap's gaps as the fight joins it to the track again and again.

On the track, `TrackBuilder._build_chunk` asks the skin for `wall_section` over the solid pieces only and
`ZoneSkin.wall_gap(parent, side, face_x, start, end, gap)` over each gap's part in the chunk (with the whole
gap, so its ends are drawn once). The default look (`standard_wall_gap`) is an orange lip along the floor
edge and orange stripes up the cut edges, the leading one brighter, and behind it each skin closes the opening with
a recess, an alley between the two cut buildings (`ZoneSkin.wall_gap_recess`, task L4: the cut ends' faces, the face
across and the ground, `docs/architecture/skins.md`, What a side wall gap shows behind it). Zone
skins add their floor-level dressing under the left wall (street, walkways, stalls) and leave out
overhead pieces. `ZoneSkin.note_wall_gaps` lets a skin that draws an element whole by its centre leave out
one that would reach into a gap (the Marketplace's shop windows).

The player (`Player.wall_gaps`, the layout's own list, set by `RunWorld`) checks `wall_supported` each
frame on the wall: in a gap it leaves the wall into the outer lane with no extra velocity (`wall_gap_drop`;
ScoreKeeper ends the wall run). A wall entry (move or ramp) inside a gap is refused with `wall_missing` and no
bump. Past the gap, the usual move input steps back onto the wall. `HintDirector` introduces them through the
`wall_gap` hint. `test_wall_gaps` covers all of this.

**A level's own wall gaps, and the Beach's open walls** (task D10b; the owner, October 9, 2026: the Beach should
"feel more open ... much longer sections where there aren't sidewalls", its walls appearing "about 50% of the
time that they are now currently appearing"; GDD §5, Zone 6: the Beach). `LevelConfig.wall_gap_tuning` gives a level
its own `WallGapTuning`; null (every campaign level but the Beach's) is the shared file. `WallGapPlacement.tuning_for(config)` is
what the placement, the F6 panel's "Wall gaps" group and the tests read. The tuning's Open walls group
(`coverage_target` above 0: `data/tuning/beach_wall_gaps.tres`, the Beach's levels only) turns the rare short gaps
into long open stretches (`WallGapPlacement._open_walls`, from the same random stream):
- each wall opens every stretch its keep-outs leave free (`open_stretches`, 1 cm clear of them), at least
  `open_seconds_min` (2 s) long, so the walls never flicker;
- a wall with more open than `coverage_target` (0.52) of the level's length stands again down to it, the wall with
  more to close first: first where the other wall is open too (the shortest such stretches first), then its own
  shortest stretches; each closing takes a whole stretch, or what it needs (at least `solid_seconds_min`, 2 s)
  from an end that meets standing wall already (`_close_down`). So the second wall keeps more of what both had
  open;
- while both walls are open at once over more than `both_open_max` (0.3) of the level, the wall with more open
  stands again over the shortest such stretch;
- a wall standing between two open stretches stands at least `solid_seconds_min` (2 s), so the walls never
  flicker: one held up only by a lone keep-out (a wall fence's or a sign's, about 17 m) stands longer around it,
  into the open stretches either side as evenly as they allow while each keeps `open_seconds_min`, or the shorter
  of the two stands whole (`_no_short_stands`, from the start and again after the closings; task D10c review).
Every keep-out above holds, so a wall whose keep-outs (mostly ceilings reaching it, ramps' wall runs and wall
enemies) leave it less free stands more. The Beach's clearance around signs, wall fences, wall enemies and
ceilings is narrower (`clear_seconds` 0.35 s against 0.5, about 8 m of wall either side at its 23.8 m/s); the
margins that time a wall run, before a ramp and past its longest run and either side of a wall enemy, never narrow
with it: `keep_outs` widens those by the shared file's `clear_seconds` (or the level's own, where wider), so they
are the shared ones (task D10c review). Placed last as before, the open walls change nothing else in a level: built with the shared tuning,
the Beach's levels are the same levels but for their gaps (the same signs, wall fences, ramps, window cyborgs
and wall vents, and no wall credit fell in a gap, since those lie along ramps' wall runs: all 54 builds below).
Over both Beach levels at 3, 5 and 6 lanes as the campaign configures them (task D10c), on their own seeds and
eight others: each wall stands on 48-60% of its level on the levels' own seeds, 107 of 108 walls in 40-60% over
all (median 49%; 97-100% with the shared tuning), the other on 64%, where its keep-outs leave it no more free;
both walls are open at once on 18-30% of a level (median 29%); the open stretches run from 48 m (2 s) to 957 m
(median 124 m), with 85% of the open length in stretches of 100 m and more (`test_beach_levels` checks its own
seeds and two others). With
the Open walls group off, the shared tuning places exactly what it did before: every
layout of `tools/measure/level_pace.gd --dump` (every campaign level at 3, 5 and 6 lanes on its own seed and four
others, and quick play) is byte-identical. DESIGN-TBD (`docs/OPEN_QUESTIONS.md` items 560–564): the target, the share open on
both walls, the shortest stretches and the narrower clearance.

**Wider gaps** (task G7; the owner's answer to open question 352, October 7, 2026, GDD §9.13 "Holes": "every
level has a couple of wider gaps. They're uncommon, still jumpable by the player, and wide enough that an
Enforcer following the player into one is wrecked"). `WideGapPlacement` (`scripts/world/wide_gap_placement.gd`;
numbers in `WideGapTuning`, `data/tuning/wide_gaps.tres`, F6 "Wider gaps") makes `LevelConfig.wide_gaps` rows of
holes (a row: the holes sharing a start and an end, `GapDensity.rows`) longer along the run than the rest:
`jump_fraction` (0.7) of a full jump at the level's speed (`length_for`), more than an Enforcer Truck hops
(`max_hop_jump_fraction`, 0.6) and within what a level may ask a runner to jump (`max_gap_jump_fraction`,
0.8); the levels' own rows are 0.4 to 0.55 of a jump. A normal jump clears one from a take-off window about
0.3 s wide (with coyote time). Every campaign level asks for 2; quick play, the prototype level and boss arenas
(`WallGapPlacement.is_boss_arena`, even asked) for none, and then the pass draws nothing.
- **When.** After the enemy rules, the danger density pass's enemies and the cyborgs planted in charge paths
  (below), before the fill pass, from a stream of its own (`rng_for("wide_gaps")`). The level's own rows it
  makes longer it makes longer only once the fill pass has run (`widen_deferred`): a filler keeps the level's
  spacing and `FILL_TAIL_SECONDS` more from every piece, more than a row's landing margin once it's longer (it
  grows by 0.2 s of run at most), so the fill pass is built as without them, and a filler the longer row would
  come nearer than that goes, so every filler keeps its spacing from the level as built (none in the levels' own
  builds; 2 of 135 builds on other seeds); the new rows and the rows it clears room for come before it, and the
  fill pass keeps off those. The report is `LevelGenerator.wide_gap_result` (target, rows, how many were
  widened, added or cleared and how many pieces went, what blocked the level's own rows, constraints, the
  widenings deferred), reset at every build of the guarantee.
- **Never stacked with another demand** (`fits`, `blocker`). Its zone (`zone_of`: from `clear_before_seconds`
  before the take-off to `clear_after_seconds` after the landing, 0.9 s each, never less than the level's
  spacing between two patterns at its difficulty, or its burst spacing in The Hush) holds, in any lane (a piece
  that only touches its end is out of its way), no other hole, fence, ramp or the point
  where its wall run drops the runner back, pad's zone, speed pad, ceiling's landing zone, floor cut's window,
  enemy's attack (the fill pass's keep-out with its floor; a floor cyborg's obstacle margin; a planned
  Resonator's pulses one by one, `DangerDensity.resonator_pulse_windows`: between them it only hovers and every
  pulse waits for clear floor) or the rules' doodad keep-outs (a Gilded Sentinel's strike; not a host's Bad
  Dream chase, which the danger density pass exempts too, `keep_out_exempt_features`). No ceiling, no
  ramp's wall run and no calm stretch (an Enforcer Truck's showing window, task C6c) lies over the jump itself
  (`row_only` keeps). A keep of one lane only (a hover truck's lane
  for its whole stay, beyond the stretch it's surely there, which every lane keeps) keeps that lane: the row
  leaves it open. Window cyborgs and Barnacle Turrets (their bolts never land near a hole), thieves and the
  Enforcer Truck (`NO_KEEP_TYPES`) don't count. Wider gaps keep `spacing_seconds` (15 s) apart.
- **Where from**, in this order until the level has its count: the level's own rows made longer (at the far
  edge, the take-off where the pattern put it, else the near edge, else both); with `add_rows`, new rows in
  every lane but one (the lane a hover truck keeps there, else a seeded one), slid along each free stretch
  until one fits (`_add_one`); the level's own rows that only other holes and plain fences keep from fitting,
  with those taken out (`_clearing`: never a pulsing fence or one a fence generator powers; `GeneratorRules.
  keep_powered` after: taking content out never makes a level unfair). Last, only for a level none of those gave
  one (one fewer where nothing else fits, never none: GDD §9.13's couple), a new row where only holes and plain
  fences are in its way, those taken out (`_add_clearing`, task K5: on 306 builds of the Enforcer's levels a Dead
  Zone 1 seed whose only room was a truck's chase before its showing, and a Golden Palace seed with none at all).
- **Which.** With `prefer_enforcer_chases`, one first in each Enforcer Truck's chase (from `bait_after_seconds`
  after it arrives, or from its showing window's end where that's later, to `CHASE_END_SECONDS` before it gives
  up), from the first source with one there, so the runner can lead it in; then the rest spread through the level,
  each source used up before the next, rows across most of the lanes (a jump) before single holes. None comes in a
  chase before its showing, from the truck's arrival to its window's end (task C6e, approved with C6d's follow-up;
  `EnforcerRules.wide_gap_keep_outs`, a `row_only` keep in `keeps_of`): it would wreck the truck before it has
  shown itself.
- **After it.** The fill pass keeps its usual margin from the wider rows as from any piece; the danger density
  pass's floor pieces keep off each zone as it stands (`DangerDensity._index_obstacles`: its margins are the
  level's spacing already), City 1's extra gaps keep it narrowed by their own margin (`GapDensity._protected`,
  `keep_outs(gen, within)`), a zone doodad whose window would reach a landing margin is left out
  (`LevelGenerator._add_doodad`, `doodad_keep_outs`: before a piece a doodad keeps the level's spacing anyway), so
  the doodads stand where they would without the wider gaps' margins, and side wall gaps keep
  `wall_gap_clear_seconds` off each on both walls (`wall_keep_outs`). City 1's extra gaps come after the doodads,
  and FIX4 lets a doodad send one of them elsewhere (a full-width widening or a new row keeps its margin from a
  doodad, `docs/questions/fix4.md`); the wider gaps re-rolled City 1 at 3 lanes into that case, so
  `test_doodads` holds City 1 to its own gaps unchanged and as many extra ones there.
- **What it gives.** Every campaign level at 3, 5 and 6 lanes gets its 2 on its own seed (`test_wide_gaps`);
  over `test_campaign`'s seed sweep 2 of 189 builds of the busiest levels fit only one (the layout check allows
  one fewer on a seed not the level's own, never none: the last way above sees to that). With the Casino's levels
  and K4's curve (merged with task C6e in task K5), the first Enforcer chase holds one past its showing window in 4
  of the 18 level and lane builds that have trucks (6 on the 15-level curve C6e was measured on, 8 before C6e kept
  them off the chase before a showing), Corporate 2 at 3 lanes among them, where the truck following the runner
  over it is wrecked in play (at 5 lanes its chase past its window is full, at 6 its window comes after its bait,
  at its chase's end); none comes before a window, and every build keeps its count. Rows and holes change a
  little: the City levels keep theirs (one hole fewer in City 2 at 5 lanes), and elsewhere the fill pass and the
  danger density pass re-roll around new rows and the zones (every level at 3, 5 and 6 lanes: 1,093 rows and 2,510
  holes before, 1,089 and 2,533 after; Corporate 2 at 5 lanes 33 and 49 before, 35 and 54 after; Dead Zone 1 at 3
  lanes 24 and 32, then 21 and 27). With `wide_gaps` and `charge_path_cyborgs` at 0 every campaign level, quick
  play and the prototype level build exactly as before (compared build by build with main's).

**Cyborgs in charge paths** (task G7; the owner's answer to open question 353, October 7, 2026, GDD §9.13
"Teaching": "occasionally a cyborg stands in the path of an Octodog's lunge or a Buzz Overdrive's charge, so the
player sees a charge flatten another enemy. At least one comes before the Enforcer's first appearance in
Corporate 2"). `ChargePathPlacement` (`scripts/world/charge_path_placement.gd`; numbers in `ChargePathTuning`,
`data/tuning/charge_paths.tres`, F6 "Charge paths") plants a plain floor cyborg in the path of up to
`LevelConfig.charge_path_cyborgs` of a level's Octodog first lunges and Buzz Overdrive charges (1 in every level
with either, Gangland 2 on; 0 elsewhere), which the charge flattens (`Enemy._hurt_charge_contacts`,
`&"enemy_charge"`, never the player's kill). It runs after the danger density pass's enemies, before the wider
gaps and the fill pass (every dog's charges and every cut are final then), from `rng_for("charge_paths")`; its
report is `LevelGenerator.charge_path_result` (target, planted, options, rejected: why each other encounter was
turned down, constraints). `plant()` writes one encounter, and the tests plant through it.
- **The cyborg.** `{type: "cyborg", side: 0, params: {panic: false, host: false, stand: true, hold_fire,
  charge_path}}`: never a host, the panic variant or a window cyborg; it stands where it's placed
  (`Cyborg.stand`: no walk), and holds its fire while the runner is in its `hold_fire` stretch, from
  `hold_before_seconds` (1 s) before the charge's warning until `hold_after_seconds` after it has passed them,
  with no bolt of its landing there (`Cyborg._may_attack`, `CyborgGun.hold`). It keeps a cyborg's obstacle
  margin and every ceiling's safe floor, stands `CALM_ROOM` or more off every calm stretch (an Enforcer Truck's
  showing window, task C6c: the encounter's span itself may reach one, `attack_near` leaves them out), and it
  never counts as the level's cyborg (`feature_positions`).
- **An Octodog's planted lunge.** Only its first, made from where it stands. The cyborg stands
  `dog_cyborg_ahead` (2.5 m, or a little more, stretched by the pace) in front of it in the lane beside, and the
  dog's params (`through_lane`, `through_at`) send its lunge along a line through it, two lanes across: it
  flattens the cyborg about halfway and reaches the far lane where it would meet a runner there
  (`Octodog.planted()`, `_lunge_vx`); its red line shows that path, so it's dodged as any lunge. The dog's
  later charges go at the runner's lane as always. A dog without two lanes beside it on a side may stand in
  another lane at its spot (`_dog_lanes`); never a gap bait; the line's path keeps off every hole
  (`path_clear`); the cyborg is reached with the runner still `in_view_seconds` (0.4 s) behind it (`dog_in_view`).
- **A Buzz Overdrive's parked charge.** Its cut gets `park`: the tank waits at its cut's end (`BuzzOverdrive.
  parked()`) instead of rolling ahead of the runner (it would drive through a cyborg in its lane), revs and
  charges where it always would, and the cyborg stands `tank_cyborg_seconds` (0.35 s of run, or a little less)
  in front of its blade, in its lane, past where the cut meets the runner, reached in view (`tank_in_view`).
  The cut keeps its own escape (`LevelGenerator.cut_escape_clear`).
- **The charge comes as planned.** The encounter claims its turn among the big attacks `claim_seconds` (4 s)
  before its warning: a planted dog from its params' `claim_at` (`Octodog.claiming()`, part of
  `is_major_attack_active` while it stands), a parked tank from its cut's `claim_seconds`. A drone's barrage or a
  hover truck's lurch or cannon shot that gets ready meanwhile waits. What can't wait or claims a turn of its
  own (a Bad Dream's chase, a Resonator's pulse, a Gilded Sentinel's strike, another Octodog's run or Buzz
  Overdrive's attack, a hover truck keeping one of the encounter's lanes) keeps `attack_margin_seconds` (2 s)
  from it (`attack_near`). Never the encounter that introduces the charging enemy (`skip_introductions`). The
  danger density pass counts the level's enemies before it (its tests leave planted cyborgs out of both counts).
- **What it gives.** At 3, 5 and 6 lanes, 7, 6 and 8 of the 11 levels that ask get one (the others: near a
  Resonator's pulse or a Gilded Sentinel, no room for the cyborg, or only the introduction); at every lane count
  one comes before Corporate 2's first Enforcer (Marketplace 1 at 3 and 5 lanes, Gangland 2 at 6). DESIGN-TBD
  (`docs/questions/g7.md`): the line, the parked tank, the numbers and the counts.

**Dash walls** (task H7a; GDD §9.14, owner, October 8, 2026: a building standing across every floor lane, which
the runner dashes through; introduced in Corporate 1 after the Buzz Overdrive, and in every level after it but the
Beach's, whose side walls stand open on about half of a level: none there for now, `docs/OPEN_QUESTIONS.md` item 680).
`LevelLayout.dash_walls` holds `{start (its face), end (its back), seed}` (marked `smashed` and `broken_by` once
broken in an attempt), left out of `to_dict()` while empty, so a level without them is the same data as before.
`dash_wall_rules.gd` (`scripts/enemies/`) places them, numbers in `DashWallTuning` (`data/tuning/dash_walls.tres`,
F6 "Dash walls"), how many in `LevelConfig.dash_walls` (1 to 3 by level, DESIGN-TBD), the wall's size in
`MovementTuning` ("Dash walls"). The feature has no patterns, and its walls stand in two stages:
- **The introduction** (a level that gives the feature a start: Corporate 1) with the rules: `apply()` runs after
  every other feature's (its `RUN_AFTER` lists them all), so it plans on the level's final enemies, ceilings, pads,
  ramps and cuts, and every pass after the rules keeps off it.
- **The rest** after the danger density pass's obstacles and the zone doodads, before the wall fences:
  `after_doodads()`, through the generator's rules hook for that moment (`LevelGenerator._after_doodad_rules`,
  the rules scripts' `static func after_doodads(gen)`), in the room the passes before left. The fill pass, the
  danger density pass and the doodads then fill the level as they would without them: a wall standing earlier
  took the stretches those passes add enemies and rows in, and the late levels on 3 lanes fell below the share of
  danger the owner asked for (`test_danger_density`), and a crowded level's few doodad stretches. A wall there
  takes out the plain pieces in its way (the fill pass's and the danger density pass's too), and keeps off every
  wider gap's zone (`WideGapPlacement.keep_outs`), every planted cyborg's encounter
  (`ChargePathPlacement.encounter_span`) and every doodad with its push's lead before it and a lane switch's room
  past it (`doodad_span`; the level's spacing until task L6: a wall stands across every lane, taller than any jump, so
  a doodad never hides it), as each keeps off a wall placed before it; and a level's quiet stretches (The Hush's,
  `LevelGenerator.quiet_stretches`; `plan_for`'s `quiet`), as the fill and danger density passes keep them, unless
  that leaves the level with none (then one stands in a quiet stretch). Where the doodads leave a level short of its
  count (task L6: they stand in far more of its room than they did), the zone doodads in the way of the rest go
  (`_clear_doodads`: the face that fits with them out of the way, the fewest of them in its way; scenery, never a
  feature, nor a treasure stash's walls; a row goes whole; DESIGN-TBD, `docs/questions/l6.md` 6), before the
  wall-run gaps give way (task J2). A level left with no wall at all even then makes room for one as an
  introduction does (`_make_room` over the whole level; never a planted cyborg or its charger, nor a Buzz Overdrive
  an Enforcer Truck counts among its baits; the spacing of every bait it can't take out stays), and where even that
  leaves none, the last resort takes the enemies and the zone doodads in the way out together (`doodads_go`;
  Corporate 2 at 3 lanes on seed 7056 since task L6, a Buzz Overdrive and a doodad, `test_dash_walls`'
  `LAST_RESORT_CASE`; Golden 1 at 3 lanes on seed 7294 without its wall-run gaps, task I4's case, where only doodads
  stood in the way, no longer needs it; DESIGN-TBD, `docs/OPEN_QUESTIONS.md` item 677).
Both draw from `rng_for("dash_wall")`, so the passes before them place exactly what they did, and a level with a
count of 0 (or without the feature) is built byte for byte as before. Its header holds every rule; in short (`Plan`):
- **A footprint in every lane**, from `approach_seconds` before the face to `after_seconds` past the back, at the
  dash's speed (the run's plus `PowerupTuning.dash_speed_bonus`): no hole or floor cut's window, fence, doodad,
  speed pad, pad's zone, ramp or the wall run it launches, no ceiling from its start to the end of its landing
  zone ("no ceiling overlaps a dash wall"), and no enemy's attack: what the fill pass keeps for an enemy and its
  floor (`enemy_spans`, as a wider gap keeps them: a floor cyborg's obstacle margin only, whose bolts never land
  near a wall; a planned Resonator's pulses only; a Tithe Collector's whole stay; a hover truck's entrance only,
  since it gives way; nothing for the heli drone and the Enforcer Truck, `NO_KEEP_TYPES`) and what the rules keep
  doodads off in every lane (a Bad Dream's chase, a Gilded Sentinel's turn; a rule's keep-out of one lane, the
  hover truck's, doesn't count). Plain holes and fences there (never a pulsing fence or one a fence generator
  powers) are taken out to make room (`clear_plain_pieces`); a spot needing nothing taken out is preferred.
- **Spacing**: faces at least `spacing_for()` apart (the dash's longest cooldown, 8 s at tier 1, and
  `cooldown_margin_seconds` of run, plus the ground a dash adds), and with `keep_dash_baits` nothing else that
  invites a dash within that spacing before a face (`bait_of`: a Buzz Overdrive's charge meeting the runner, a fence
  generator, the end of a Tithe Collector's stay, whose hint sends the dash at it; a zone doodad never needs the
  dash, so it keeps off the footprint only). The spacing guarantees the dash only when it was last used at the
  previous wall (about 1 s of slack): `docs/OPEN_QUESTIONS.md` item 647.
- **The wall route**: from `wall_route_seconds` before the face to the back, at least one side wall holds no sign
  (where both do, those of the side with fewer go), and the side wall gaps and wall fences keep off both walls
  there (`wall_keep_outs`, `WallGapPlacement.keep_outs`; the wall fences' drop windows keep off the footprint).
- **How many, and where**: up to the level's count, spread through the level past an introduction (a part each, a
  seeded spot aimed for, the best fair spot in the part), then the best of the rest; where that leaves a crowded
  level short, the most that fit, as far apart as they can be (`_most_apart`). Corporate 1 (`feature_starts`, 0.42)
  introduces them first, at the first fair spot from the start; where none comes within `intro_window_seconds` the
  introduction makes room (`_make_room`): the face there the fewest enemies of `MAKE_ROOM_TYPES` block (a Buzz
  Overdrive with its cut, but never one with company, task L2, which would leave its company behind; a fence
  generator, a cyborg, a window cyborg, a screech; anything else blocking rules a face out) loses them, unless that leaves a feature with nothing or moves any feature's first (each feature's
  introduction stays where it was). Where even that leaves the window no fair spot, the introduction stands at the
  first spot past it where one fits: Corporate 1 at 5 lanes on K4's curve, where the feature guarantee's forced picks
  (a fence generator, a vent screech, each the only one of its feature) fill the window (1897 m, from its start at
  1425 m; `test_dash_walls`' `LATE_INTRODUCTION_LANES`, item 676). A level with the feature and no fair spot at all
  gets a warning (every feature appears). On K4's denser curve Corporate 1 asks one wall and Golden 2 two (item 675:
  a level asks no more than its track holds on its most crowded lane count).
What comes after a wall keeps off it: after the introduction the fill pass (`fill_keep_outs`, every footprint in
every lane), the danger density pass, the wider gaps, the planted cyborgs and the zone doodads
(`doodad_keep_outs()`, through `rules_doodad_keep_outs`); after the rest the wall fences' drop windows (the same),
the side wall gaps and wall fences beside them (`wall_keep_outs`), and the credits (none inside a wall:
`LevelLayout.doodad_between` counts a wall in every lane, so a dropped credit or a floor cut's lane never lands in
one either). `problems(gen)` re-checks a finished layout (the tests, `LayoutChecks.check_dash_walls`). Every
campaign level gets its full count on its own seed at 3, 5 and 6 lanes (Corporate 2 and The Hush ask for 1, Golden 1
and Golden 3 for 2, and Dead Zone 1 for 2 since its ceiling scenarios, task I4: their tracks have room for no more on
some lane counts).

**Dash walls on the track.** `TrackBuilder._build_dash_wall` builds each in the chunk where it stands (Damage and
interactions: the box on `LAYER_DASH_WALL`, the forgiving hitbox), sized by `TrackBuilder.dash_wall_size()` (as
wide as the floor less `dash_wall_wall_room` beside each side wall, `dash_wall_height` tall, its stretch deep) and
`dash_wall_hitbox()`, and has the zone skin dress it (`ZoneSkin.dash_wall`, Zone skins) and name its pieces'
colours (`dash_wall_debris_colors`). `dash_wall_for(entry)` finds a built one; one broken in this attempt is never
built again.

**Ceiling scenarios** (task I4; GDD §3, "Ceiling scenarios", owner, October 14, 2026: never in zones 1–2, sprinkled
into later zones). Two features with no patterns whose rules turn a few of a level's own ceilings into a scenario:
`treasure_stash` (`treasure_stash_rules.gd`, from Casino 1) and `fenced_ceiling` (`fenced_ceiling_rules.gd`, from
Casino 2; the several-pad version from Corporate 1). Both build on `CeilingScenarios` (`scripts/world/`: the shared
placement helpers, and the Player's physics they're timed by: a pad's flip and rise, a drop off the ceiling, a jump),
with their numbers in `CeilingScenarioTuning` (`data/tuning/ceiling_scenarios.tres`, F6 "Ceiling scenarios") and how
many a level gets in its own data (`LevelConfig.treasure_stashes`, `fenced_ceilings`, `fenced_ceiling_pads`).
DESIGN-TBD throughout (items 836–845 in `docs/OPEN_QUESTIONS*.md`).
- **When**: after every rule that places ceilings, pads, ramps or floor enemies or plans charges and cuts (their
  `RUN_AFTER`), the stash first; the Barnacle Turrets, the Resonator, the Enforcer Truck and the dash walls run after
  and plan around them. So every rule before them plans as it would without them. A scenario takes one of the
  level's ceilings (`candidates`: one with a pad, none another scenario took, none with a turret) and marks it
  (`hull["scenario"]`): no turret hangs from it (`BarnacleTurretRules.mount_lanes`, which the danger density pass's
  turrets go through too). A level that gives the feature a start gets it on the first ceiling that fits from there
  (its introduction); the rest are seeded picks (`rng_for(feature)`), `min_gap_seconds` from every other scenario
  (`choose`). Endless mode gets them once its difficulty reaches `stash_min_difficulty` / `fenced_min_difficulty`.
  They're sprinkled, never guaranteed (`OCCASIONAL` in their rules; `LayoutChecks.occasional`): the campaign's checks
  don't ask every build for one.
- **What they keep off**: what they add on the floor (a stash's floor, an added pad's zone, a ceiling run on further:
  `can_extend`) keeps off `busy_spans` (every enemy's fill keep-out, floor cut windows, dash wall footprints, the
  rules' keep-outs in every lane and their fill keep-outs, quiet stretches); an added pad also keeps off every drone
  wave's window (`drone_windows`) and a lane a rule keeps (`lane_keeps`). Where a ceiling runs on, the plain holes
  and fences on its new landing zone go (`extend`, `clear_floor`, which keeps every fence generator powering a fence).
- **A treasure stash** (`LevelLayout.stashes`, its record; `return_pads`; its doodads and credits are ordinary
  `doodads` and `credits` entries marked `stash`): in an inner lane with inner lanes either side (`lanes_for`: none on
  3 or 4 lanes). Its return pad hangs in that lane `see_seconds` after the ceiling's rider arrives, as late as the
  ceiling allows, and the ceiling runs on `ceiling_after_seconds` past the stash. `stash_offsets` lays it out from the
  return pad by the drop's physics: a doodad across its lane whose end the dropping rider clears, walls back to back
  in both neighbouring lanes from `wall_overlap` before that one's end to past the last credit, pushing outward, and
  2–3 credits of the highest denomination past where the rider lands and past the top magnet's reach from the floor
  (`magnet_reach`: `CreditField.MAGNET_AHEAD` of the largest `PowerupTuning.magnet_radius`, from the walls' start,
  as a floor runner the magnet reaches across from is short of them). Its floor (from the front doodad's push to the
  level's spacing past its open end) holds nothing else in any lane; its holes and fences go. Its doodads join
  `layout.doodads` at once, so the rules after it see them; the zone doodads' look seeds count only zone doodads.
  Its credits count in a run's credits and score, never in the stars' best score (`LevelLayout.star_credit_value`,
  `ScoreKeeper.max_credit_score`; DESIGN-TBD item 9).
- **A fenced ceiling** (`LevelLayout.ceiling_fences`; its pads marked `fenced`, `unsafe` or `safe`, and `added` on the
  ones the rules add): two lanes wide or more, with `fenced_ceiling_pads` pads but fewer than the lanes (`pad_count`:
  a floor runner always has a lane without one; on 3 lanes the simple version). Its own pads are unsafe (the later
  version adds more, each in a new lane); rows of fences cross every lane it covers from just past where the last
  unsafe pad's rider (at the run speed plus `rider_boost`) comes within `MovementTuning.ceiling_fence_depth` of the
  underside, spaced by
  `CeilingScenarios.row_plan` so no jump rhythm clears them all (a rider jumping is near the underside for
  `jump_low_seconds` of every jump); the safe pads follow `safe_gap` past the last row, and the ceiling runs on
  `safe_ride_seconds` past their riders' arrival. The pick plays out alone: no Bad Dream chase, Gilded Sentinel strike,
  floor cut, drone wave's arrival or quiet stretch from its first pad's run-up to its last safe pad (`event_spans`),
  and no ramp's wall run or hover truck within a jump of its rows under an outer lane it covers (`wall_jump_near`: a
  jump off a high wall run reaches a ceiling fence). Its ceiling records that stretch (`hull["pick"]`,
  `LevelLayout.fenced_pick_between`): a heli drone that outlived its pads starts no barrage that would play out there
  (`Drone._pick_in_reach`). After a level's first drone wave every pad is the drone schedule's, so the trap stands
  where a scheduled pad would; the pick's safe pad hurls the drones as any pad does, and as the pick is calm, a missed
  pad costs no more than the schedule's 8–10 s of barrages (`LayoutChecks.check_fenced`; DESIGN-TBD item 10). The
  added pads don't count in the drones' pad schedule (`LayoutChecks.check_rules`).
- **After the rules**: every later pass keeps off a stash's floor (`doodad_keep_outs`, `fill_keep_outs`); the credit
  pass keeps every other floor credit out of a stash and its walls' lanes (`LevelGenerator._in_stash`) and every
  ceiling credit `CEILING_FENCE_CREDIT_MARGIN` off a ceiling fence. `LayoutChecks.check_scenarios` checks every rule
  on a finished layout (part of `check_layout`); `check_doodads` leaves the stash's doodads to it.

**Ceiling scenarios on the track.** `TrackBuilder._build_ceiling_fence` builds a ceiling fence as an electrical
Hazard ("ceiling fence"), always on, hanging `ceiling_fence_depth` (0.85 m) below the underside, a fence deep and a
lane wide less 0.2 m: above the chase camera's highest under a ceiling, a floor runner's jump (from the floor or a
hover truck's roof) and a wall runner's body. An EMP switches it off like any fence (`disable_fences_near`;
`ceiling_fence_hazards()` lists the built ones). `_build_return_pad` builds a return pad as a trigger (`kind`
`return_pad`) on the underside, turned upside down. The skin dresses both (`ZoneSkin.ceiling_fence`, `return_pad`;
Zone skins). On the ceiling the Player's trigger check runs too, its sensor reaching from the feet toward the
underside, and only a return pad counts there: it drops the rider as a ceiling's end does (`_drop_from_ceiling`: the
floor's gravity from the underside, the lane kept, the `hull_end` event; `return_drops` counts them). A stash's
doodads are ordinary zone doodads (`DashBreakable`: the push, the blocking sides, the dash smashes them). The chase
camera of a ceiling rider rides lower than a doodad's top (`camera_ceiling_height`), and a stash's doodads stand under
a ceiling: `RunCamera.doodad_floor` keeps it `camera_doodad_clearance` above any doodad it's level with, rising toward
one ahead.

**Wall-run gaps** (task J2; the owner, October 15, 2026, `docs/USER_REQUESTS.md`: "sections, especially in later zones
and levels, where there is a gap over the ENTIRE floor (every lane), and the only way to cross is a wall run ...
consider a wall an acceptable/safe path"). **A wall run is an accepted safe path here**: the one place a level asks
for the wall, and every rule below keeps that path whole, clear and long enough. The `wall_run_gaps` feature, from
halfway into Marketplace 1 (`feature_starts` 0.5) on, in every later level, never in the City or Gangland, a boss
arena or quick play; it has no patterns. `LevelLayout.wall_run_gaps` holds `{side, start, end, entry, approach,
landing, wall_to}` (left out of `to_dict()` while empty); its holes are ordinary `gaps` entries marked
`LevelLayout.WALL_RUN_HOLE`, which the jump checks (`LayoutChecks`), `GapDensity.rows` (so the wider gaps never take
one for a row) and the credits' risky gap credit leave out. `WallRunGapPlacement` (`scripts/world/`) holds every rule
and the shape, numbers in `WallRunGapTuning` (`data/tuning/wall_run_gaps.tres`, F6 "Wall-run gaps"); DESIGN-TBD
throughout (`docs/questions/j2.md`).
- **Its shape** (`shape_for`, seconds of run at the level's speed, from the standard wall run,
  `MovementTuning.wall_entry_time + wall_slide_time`, 2.16 s: no claws, no wall hop): a clear run-in
  (`approach_seconds`, 0.8 s) and the lit stretch (`entry_window_seconds`, 0.5 s), together time to cross a 6-lane
  track to the wall; the gap, a standard wall run less the lit stretch and `exit_margin_seconds` (1.41 s: 31.9 m at
  the Marketplace's 22.6 m/s, 35.2 m at the Golden Zone's 25), so a step onto the wall anywhere on the lit stretch
  carries the runner across, the earliest leaving the wall past the far edge, the latest (at the edge, with the jump
  grace) dropping back onto the landing floor (`landing_seconds`, never shorter than that drop plus
  `landing_slack_seconds`). No jump crosses it: a full jump with its grace and the dash all the way reach about 1 s
  of run, 1.2 s with a speed pad's or a ramp's whole boost. A step onto the wall before the lit stretch drops the
  runner in (a wall hop is never asked for; claws, the dash and a wall hop only carry them further).
- **When and where**: its rules (`wall_run_gaps_rules.gd`) run last of the rules (`RUN_AFTER` every feature whose rules
  plan something), before the danger density pass, the planted cyborgs, the wider gaps, the fill pass, the doodads,
  the dash walls after them, the wall fences, the side wall gaps and the credits, from `rng_for("wall_run_gaps")`.
  About one per `spacing_seconds_easy` to `_hard` (70 to 40 s, by the difficulty halfway through the stretch),
  each due at a seeded spot of its share and placed within `search_seconds` (40 s) of it at the spot that takes the
  least out of its way, the nearest of those; the level that brings them in places its first as soon as one fits
  past the start (each unit taken out weighs a second later, `INTRO_COST_SECONDS`); one at least, anywhere past the
  start, as a last resort with one big encounter that leaves nothing behind taken out of the level (`_make_room`,
  `MAKE_ROOM_TYPES`: a Resonator's visit, a Gilded Sentinel or a hover truck, never the level's first of its kind; the
  report's constraints name it), and where that leaves no room either, with the signs on its lit wall's stretch taken
  off (`_signs_go`: a sign blocks the step onto the wall and hurts a wall runner; Marketplace 1 at 5 lanes on seed
  7301, one sign), else a warning (Marketplace 1 on seeds 9003 at 3 lanes and 9004 at 5, whose hover truck in the way
  is the level's first; and at 3 lanes The Hush without its remix on seed 9206 and Dead Zone 1 on seed 9208, in
  `test_campaign`'s sweep, whose drone pad schedule, its ceilings every 8 to 10 s, and its only hover truck and
  Octodog leave no 4-second stretch: `test_campaign`'s `WALL_RUN_GAP_CROWDED`; no campaign build has one).
  `min_spacing_seconds` between one's landing floor and the next one's run-in.
- **What it keeps off** (`floor_keep_outs`, `keep_outs_by_part`, `wall_keep_outs`): from its run-in to the end of its
  landing floor nothing in any lane: no other hole, fence, doodad, pad and its lift, ramp and the longest wall run it
  launches, speed pad, floor cut's window, wider gap's zone, and no enemy's attack or the floor it uses (everything a
  wider gap's zone keeps: `WideGapPlacement.keeps_of`, the rules' keep-outs, each planned Resonator pulse; but a heli
  drone's wave until its first pad, whose barrages hold off at run time, below), nor a standard wall run past a dash
  wall (`past_dash_wall`, from its face: a standard wall run as if the runner stepped on at its back, the drop and the
  dash's extra; a runner without the dash passes one on a side wall, GDD §9.14, and one still on a wall when the lit
  stretch comes has no fresh wall run for the gap; claws add less than the run-in and the lit stretch last, so a clawed
  runner still comes down before the gap); no ceiling and no ceiling's landing zone overlaps it, and no pad's run-up
  reaches its gap. Its lit wall stays whole
  and clear from `wall_clear_seconds` before the lit stretch to past
  the longest wall run over the gap (`wall_to`: claws, the dash, a save onto the wall at the far edge): no sign, wall
  enemy (`WallGapTuning.wall_enemy_seconds` either side), wall fence or side wall gap; the other wall keeps no side
  wall gap beside the gap (`other_wall_clear_seconds`).
- **Making room** (`_removable`): plain pieces in its way go (holes, fences but pulsing ones or ones a fence generator
  powers, zone doodads but a treasure stash's), and small enemies (`_small_enemies`: a plain floor cyborg, a manhole
  screech; never a host, a planted cyborg, a vent screech, nor the level's first of its kind), each weighing
  `ENEMY_WEIGHT` plain pieces. It runs before the danger density pass counts the level's enemies, so that pass's
  count and share are the level's as it stands.
- **After it**: every later pass keeps off its clear stretch (`doodad_keep_outs`, `fill_keep_outs`, with `KEEP_MARGIN`);
  a cyborg's walk and panic run stop short of it (`CyborgRules.obstacle_spans`), a wall enemy the danger density pass
  adds keeps off its lit wall (`on_wall_section`), a dash wall placed after it keeps its face a wall run past it
  (`past_dash_wall`) before the clear stretch (`DashWallRules.plan_for`, `problems`), and the wall fences and side wall
  gaps keep off it (`WallFencePlacement.keep_outs`, `WallGapPlacement.keep_outs`). `problem(gen, w)` re-checks a finished layout
  (`LayoutChecks.check_wall_run_gaps`, part of `check_layout`).
- **Giving way**: a later pass short of its own count lets the level's wall-run gaps but its first make way
  (`set_aside`, `put_back`): the wider gaps (`WideGapPlacement.place`, before its last way) and the dash walls
  (`DashWallRules.after_doodads`, before the quiet stretches and making room) look again with them out of the way,
  and each comes back where that pass left its way as it was (`problem` finds nothing, and no wider gap planned there:
  the level's own rows are made longer only after the fill pass); the report counts the rest (`gave_way`,
  constraints). The first never gives way, so the level keeps one. Where a finished build's wider gaps still fall
  short and it has wall-run gaps, the generator builds it once more with the first one's clear stretch kept for them
  (`LevelGenerator._make_wide_gap_room`, `wall_run_gap_reserve`, `WallRunGapPlacement.wide_gap_reserve`; never in the
  level that brings the feature in), so it goes elsewhere, its own last resort making room as ever (Golden 2 at 3
  lanes on its own seed: a Gilded Sentinel that isn't the level's first). That build stands only with every wider gap,
  a wall-run gap, every feature and no warning, else the level is built as before; it isn't a build of the guarantee
  (`attempts`). DESIGN-TBD (`docs/questions/j2.md`): which gives way when a level has room for only one.
- **At run time**: the attacks a runner can't dodge on the way to the wall or over the gap hold off while a crossing
  (`approach` to `end`, `LevelLayout.wall_run_between`) lies in their reach: a heli drone's barrage
  (`Drone._wall_run_in_reach`), a Bad Dream's slash (`BadDream._wall_run_in_reach`; a host's chase only comes if the
  player kills it, so the generator can't plan around it) and an Enforcer Truck's volley, from its warning to its last
  bolt (`EnforcerTruck._wall_run_in_reach`: it chases from behind as long as it lives); and an Octodog whose charges a
  wait for its turn moved on waits ahead while one lies in its charge's stretch, its moved charges moving on
  (`Octodog._wall_run_in_reach`; its planned charges keep off the crossing already). A cyborg's bolts never land near a
  hole (`CyborgGun`), a Resonator's pulse waits for clear floor (`Resonator.pulse_clear`). The grapple's save and a
  revive after a fall into one (within `save_margin` of its holes) put the runner on its lit wall
  (`WallRunGapPlacement.grapple_save`, set by `RunWorld.build`; `Player._pull_up`'s `{"wall": side, "until": d}`), whose
  run carries them across and leaves the wall by `until`, in time to come down onto the landing floor (a save at the
  far edge has its run cut short; an ordinary wall run is unchanged): the pull's leap would drop them back in. Its
  first-encounter hint is `wall_run_gap` (`data/hints/hints.json`).
- **How many** (`tools/measure/wall_run_gaps.gd`, campaign levels on their own and two more seeds at 3, 5 and 6
  lanes, 117 builds): a build has on average 1.9 in the Marketplace (one in Marketplace 1, from halfway), 2.6 in the
  Casino, 2.3 in Corporate, 2.1 on the Beach, 2.0 in the Dead Zone and 1.5 in the Golden Zone, whose levels are the
  most crowded (their Resonators, Gilded Sentinels and hover trucks leave few 4-second stretches free); 15 of the 117
  had one give way to the wider gaps or the dash walls. Every build measured has one, the last resort making room in 4
  of the 117, all Golden builds at 3 lanes (one of them Golden 2's own, through the wider gaps' rebuild); of
  `test_campaign`'s seed sweep, two Dead Zone builds at 3 lanes have none (`WALL_RUN_GAP_CROWDED`, above). Measured
  again with the dash wall rule (`past_dash_wall`): the same means, 117 builds.

**Wall-run gaps on the track.** Their holes are built like any (`TrackBuilder._floor_pieces`, the zone's floor edges).
`TrackBuilder._build_chunk` asks the skin to light each one's wall where it runs through the chunk
(`LevelLayout.wall_run_guides`, `ZoneSkin.wall_run_guide`, Zone skins), and **only the Marketplace's skin does** (task L5;
the owner, October 17, 2026: the green ramp is fine where the mechanic is introduced, too easy after it, "making the
player use their brain a little bit more"). Every later zone's skin (`data/skins/`: Casino, Corporate and its plaza
floor, the Beach, the Dead Zone, the Golden Zone and its palace) sets `show_wall_run_guide = false`, so `wall_run_guide`
draws nothing there and the cue is the hole itself: the street's edge coming, with the step onto the wall in the last
`entry_window_seconds` before it (a step up to `exit_margin_seconds` earlier still also crosses, and one up to the jump
grace, `coyote_time`, past the edge). The gap's wall stays whole and clear whether it is lit or not, but the other wall may carry a sign, a wall
fence or a wall enemy there, so the runner reads both walls; the grey box and the earlier zones' skins (which never
have a wall-run gap in the campaign) keep the default `true`, so quick play (`--features=wall_run_gaps`, with
`--skin=<zone>` for another zone's look) and the review tools show it unless the skin says otherwise
(`wall_run_gap_review --guide=on|off` forces either). **No gap needs a speed boost**, so no zone keeps the guide for
one: the gap is a standard wall run (`shape_for`) at the zone's own run speed (a faster zone's gap is longer by the
same ratio, `test_numbers`), no speed pad, ramp or other boost is in its clear stretch (`floor_keep_outs`), and the
suite checks that no jump crosses it even with every boost and the dash. The first-encounter hint has two texts
(`wall_run_gap` in `data/hints/hints.json`; `HintDirector._text_of`): `text` points at the green arrows, and
`text_no_guide` says to step onto the wall just before the street ends, said where the level's skin leaves the guide out
(a reminder for a profile that never saw it in the Marketplace). DESIGN-TBD (items 929-932 in `docs/OPEN_QUESTIONS*.md`): whether the 0.5 s
stretch is readable without the guide. Where the guide is shown it is by default the ramps' green chevrons
(`ramp_color`, as the Floating Head's wall marks show a wall run), a tall, bright, framed panel over the lit stretch
(where to step on) and a strip at running height over the gap, streaming ahead, never in a hazard colour, never
flickering (Reduced flashing leaves it as it is). Visual only, no collision.
