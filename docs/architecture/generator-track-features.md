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
drop windows are protected. A widening keeps off a zone doodad's window (its push's lead before it to
the level's spacing after it, in every lane) and, with the margin, the doodad's own lane, which is then
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
  Dream chases), {lane, from, to} (that lane, which no doodad stands in or pushes into: a hover
  truck's, until it has left; its `keep_out` already keeps every lane for its shortest stay) or {from, to,
  calm: true} (a calm stretch in every lane: an Enforcer Truck's showing window, task C6c: no doodad nor
  its push's lead stands in it, but it shapes no stretch, so the doodads draw as without it elsewhere; the
  other later passes keep their additions off it without spacing from it);
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
stands in the stretch the attack would take (`_doodad_in_reach`; a drone holds it for a fenced ceiling's pick too,
`_pick_in_reach`, task I4), an Octodog charge or a Resonator pulse
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

**A runner who dashes through a doodad** (task H5; the dash smashes one: Damage and interactions, "The
dash smashes a zone doodad"): a doodad is 2.6 m tall and hides its own lane right behind it from the
chase camera, which a runner it pushes never reaches in that lane; a dash shows it only at the smash, and
goes on at the dash's speed (+8 m/s).
The placement already keeps the level's spacing after every doodad clear in every lane (`doodad_after()`,
at least `spacing_seconds_hard`, 0.9 s at run speed), so it needed no rule of its own. Measured over every
campaign level at 3, 5 and 6 lanes (`test_doodads`' `_test_dash_fairness`, each level's own build, 270
doodads), the first thing after a doodad, in its lane (a hole, a wider gap, a fence, a pad, a speed pad, a
floor cut's lane window, an enemy standing in it) or in any lane (everything the fill pass counts as going
on: every piece, each enemy's stretch as its rules keep it, a cut's window; a ceiling to the end of its
landing zone; a Bad Dream's chase), comes at least 0.75, 0.73 and 0.72 s after its front at 3, 5 and 6 lanes
at the dash's speed (medians about 0.8 s), and 0.70, 0.68 and 0.68 s after its end (a runner who dashed into
its side near its end sees it there at the latest), against the 0.49 s a reaction (0.35 s, the suites' bots)
and a lane switch take. The suite holds every campaign doodad to both.

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
`same_side_gap_seconds` on either wall) and off for `intro_off_seconds`, with its first-encounter hint on
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
players to read gaps coming. A level with the feature always gets at least one gap. Boss arenas get none
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
edge, dark caps where the wall is cut, and orange stripes up the cut edges, the leading one brighter. Zone
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
  (`ChargePathPlacement.encounter_span`) and every doodad with its push's lead before it and the level's spacing
  past it (`doodad_span`), as each keeps off a wall placed before it; and a level's quiet stretches (The Hush's,
  `LevelGenerator.quiet_stretches`; `plan_for`'s `quiet`), as the fill and danger density passes keep them, unless
  that leaves the level with none (then one stands in a quiet stretch). A level left with no wall at all makes
  room for one as an introduction does (`_make_room` over the whole level; never a planted cyborg or its charger,
  nor a Buzz Overdrive an Enforcer Truck counts among its baits; the spacing of every bait it can't take out
  stays), and where even that leaves none, the last resort takes the zone doodads in the way out too (`doodads_go`:
  scenery, never a feature, nor a treasure stash's walls; Corporate 2 at 3 lanes on seed 7101 on K4's curve, Golden 1
  at 3 lanes on seed 7294 since task I4, `test_dash_walls`' `LAST_RESORT_CASE`; DESIGN-TBD, `docs/OPEN_QUESTIONS.md`
  item 677).
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
  Overdrive with its cut, a fence generator, a cyborg, a window cyborg, a screech; anything else blocking rules a
  face out) loses them, unless that leaves a feature with nothing or moves any feature's first (each feature's
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
