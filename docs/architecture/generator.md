# Architecture: The generator: density, placement, picks, pace, fill pass

One part of the architecture notes; `docs/ARCHITECTURE.md` is the index of every part and topic.

## The generator

`LevelGenerator` (`scripts/world/level_generator.gd`) builds a `LevelLayout` (pure data) from
patterns, a difficulty value and a seed, for any lane count. Passes, each with its own random stream:
patterns (filtered by the level's features) → enemy rules scripts → density/filler placement → credits. Helpers for rules
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

**Progressive danger density** (owner revision, October 3, 2026). `danger_density.gd` overlays the
native layout through enemy and obstacle hooks around the filler pass. The per-level
`LevelConfig.danger_density_increase` dial is calibrated to actual generated enemy and obstacle
counts, not merely interpreted as a spawn-probability multiplier. City uses 0.15; Gangland
0.18/0.20/0.22; Marketplace 0.24/0.26; Casino 0.27/0.27; Corporate 0.28/0.29; Dead Zone 0.37; the Terminal 0.37/0.38
(task O1: none of the usual enemies and no fillers, so the pass adds nothing there yet; `test_danger_density` checks
its levels for fairness only, as The Hush's); the Ice Lab 0.38/0.38/0.38 (task Q1: between Terminal 2's and Golden 1's;
its enemies only cyborgs, Octodogs and heli drones, a mix the bands don't sample, so `test_danger_density` checks its
levels for fairness only too); Golden
0.38/0.39/0.39 (Golden 2 and 3 were 0.38 until the Casino re-spaced the curve, task K2: the final band's
measured increase at 3 lanes had slipped to x1.297; the pass is short of fair room there, so the dial buys
little, `docs/OPEN_QUESTIONS.md` §D, item 521). Merged with the Enforcer Truck's showing windows (task C6e,
whose calm stretches the pass's rows keep off), `test_danger_density`'s sample of the final zones at 3 lanes had
28.8% more obstacles, under its 30% floor, though over 7 seeds (each level's own and 9001-9006) the same levels
have 30.2%. The wall fences' share (`wall_fence_increase_scale`) went from 1.25 to 1.9 (task K5, DESIGN-TBD,
`docs/OPEN_QUESTIONS.md` §D, item 534: the owner finds every level too easy): it adds wall fences only, 447 to 505 over the
campaign's own builds from Marketplace 2 on, and makes no floor room; the sample has 30.6% with it, the 7 seeds
31.9%, and their enemies about 30% either way. `test_danger_density`'s sample then has 13-19% more enemies and 17%
more obstacles in the first levels, 26-28% and 27-28% in the middle ones, and 32-36% and 31-39% in the final ones.
The wall-run gaps (task J2) take room the pass would fill (each keeps about 4 s of run clear in every lane, the
level's spacing either side): the sample's final band at 3 lanes then has about 29% more enemies and 28% more
obstacles (33% and 30% without them; 5 and 6 lanes 31-36%), and `test_danger_density` lets that band land 4% lower
at 3 lanes (`WALL_RUN_GAP_ROOM`; DESIGN-TBD, `docs/questions/j2.md` item 12), and its rise past the middle band fall
short by as much there: since task L6's review the zone doodads stand by the side walls more at 3 lanes and take a
little of the room the wall fences placed after them would have (its obstacles x1.260 against the middle band's
x1.265; item 976 in `docs/OPEN_QUESTIONS*.md`). The Golden Zone's teleporters (task Q6) take more of it: each keeps
its pad stretch and landings clear in every lane, so the band at 3 lanes has about 27% more enemies and 23% more
obstacles, and the suite lets it land 5% lower again there (`TELEPORTER_ROOM`; built without them it keeps the floor
above; DESIGN-TBD, `docs/questions/q6.md` item 11).
Prototype and boss arenas stay at 0, which draws nothing and preserves the old layout exactly.
Numbers and safety margins live in `data/tuning/danger_density.tres`.

Small enemy encounters stay within existing feature introductions and warning rules; later levels
also add fair ceiling turrets where that feature exists. Obstacle rows use spare lane width where
possible, or additional longitudinal opportunities when a row already leaves only one lane open.
The pass checks the reachable route through successive rows, not just a permanently empty lane.
Wall fences retain their placement rules, Resonators keep their whole visit clear, a window cyborg or a
vent's screech it adds keeps off what the rules keep wall enemies off (`LevelGenerator.wall_section_rules`:
the rules scripts that declare `on_wall_section`, a Gilded Sentinel's wall section; task K4, after a build
on one of the curves it tried put one there; `test_gilded_sentinel` pins a build that shows it), and
doodads cannot occupy the only route the new rows require. Added pieces receive no extra risk-credit pay.
Durations and reward tables are unchanged, including City 1's 55 seconds.

`tools/measure/danger_density.gd` reports counts by level, band and danger category, and compares
dial-0 layouts with a saved before-change dump. Representative measurements (native seed plus
9001/9002, 3/5/6 lanes) are:

| Band | Enemy count increase | Obstacle count increase |
|---|---|---|
| Early | 16.7-18.1% | 17.0-17.5% |
| Middle | 26.4-26.7% | 26.4-27.2% |
| Late | 31.6-34.6% | 33.0-37.7% |

The regression suite asserts requirement-based bands of 10-20%, 15-35% and 30-40%, respectively,
for both categories at every supported lane count, plus route safety, determinism, economy and
build-time guards. All 225 saved dial-0 layouts match the pre-change baseline.

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
plans a big attack, so each pulse is planned on the level's final floor and off every Octodog's run,
floor cut and Gilded Sentinel's turn; the Ice Lab's set pieces last of all, the falling gantryways and then the
teleporters, each planned on the level's final rules track: `docs/architecture/gantryways.md`,
`docs/architecture/teleporters.md`). A rules script may also declare `static func after_doodads(gen)`,
which runs after the danger density pass's obstacles and the zone doodads, before the wall fences, in the order
of the features (`LevelGenerator._after_doodad_rules`): what stands in the room the passes before it left, which
they shouldn't make room for (the dash walls past their introduction, task H7a: Dash walls, below).
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
ceiling: never a one-lane one, nor one a ceiling scenario took (task I4: their rules run first and mark it,
`hull["scenario"]`; one new thing at a time); never over a pad's lane (the rider lands there and can ride on past every
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

**Gilded Sentinels** (C4, GDD §9.11; `gilded_sentinel_rules.gd`). Patterns stand them on a wall; the rules
run after every feature's that puts things on the floor or the walls before them, the Buzz Overdrive's
floor cuts included (`RUN_AFTER`), and the Resonator's, the Barnacle Turret's and the floor cutter's run
after these. Each one's attack, at the level's run speed, is its window
(`GildedSentinelTuning.attack_window`: from where the runner is as its eyes flare to the end of the stretch
it cuts; never later than the floor it uses, `floor_use`: the escape lane is kept clear from
`escape_lead_seconds` (0.7 s) before a swing, which is before the 0.6 s warning, so the window starts
there, and the doodads, fill pass and floor cuts that keep off the window keep off its floor as ever),
and where it may stand is `problem()`:
- the level: its window past the run-up and the feature's start, its stretch before the end-clear stretch,
  and its niche within one of the track's chunks (`in_chunk`, `TrackBuilder.CHUNK_LENGTH`: the skin opens
  it in that chunk's wall);
- its wall: no sign, window cyborg, wall vent's screech, wall fence or other Sentinel on it from
  `approach_seconds` before its stretch (a runner entering early to pass below needs the wall from there)
  to `wall_clear_seconds` past it (GDD §9.11 with §9.1); a ramp on that wall only where the wall run it
  launches (`RampLaunch`, and its longest, with claws and a speed pad's boost) passes the stretch wholly
  above the band, or is over before it, and none in the outer lane by the stretch;
- never when the outer lane is the only safe lane: the lane beside it holds no hole, fence, floor cut,
  anti-grav pad, floor enemy or hover truck's lane from `escape_lead_seconds` before its first swing to
  the end of its stretch, and no hover truck holds the outer lane itself meanwhile (`HoverTruckRules`
  clears its lane of floor enemies, Sentinels included);
- what runs meanwhile: no floor cut's window, Octodog run or ceiling's landing zone reaches its window, and
  its cut (its `params.floor_span`, `floor_use`) keeps off every pad's way (`CeilingZones.enemy_clear`);
  the level's first keeps off every big attack and Bad Dream chase too (`STRICT_ATTACKS`), so it always
  swings; the others may meet a drone wave or a hover truck's stay, whose attacks wait for theirs at run
  time (each claims its turn shortly before its warning) or, begun before, make it let the runner pass
  (Enemies);
- other Sentinels: windows `gap_seconds` apart unless they are a pair (the same spot on both walls).
One that doesn't fit where its pattern put it tries a few spots around it (`MOVE_OFFSETS`), one that swings
twice then once, and one that still doesn't is left out. The level's first (its introduction) swings once,
alone; in a level that gives the feature a start (Golden 2), if none is left within `INTRO_REACH` of it
(earlier rules took it out: a hover truck clears its wall and lane, a drone's pads their stretch), one is
added at the first spot there, calm where it can be. It uses the floor (`uses_floor`, its tuning's reach;
its rules set `params.floor_span` to what its cut uses), so ceilings' pads and landings, the Resonator's
waves and everything that asks the floor keep off it; `keep_out()` (its window) keeps the fill pass and
floor cuts off it, and `doodad_keep_outs()` (its window in every lane, marked `type`) the zone doodads, floor
cuts and the wall fences' drop windows. The Resonator's rules (after these) plan its pulses off every
Sentinel's whole turn, from its claim to its last swing (`resonator_rules.gd`'s `sentinel_turns`,
`GildedSentinelTuning.claim_window`), so a planned pulse is never held for one at run time (one that
was could be pushed on past the level's end). `problems()` re-checks every one for the tests.

**Enforcer Trucks** (C6, GDD §9.13; `enforcer_truck_rules.gd`). No patterns: the rules place every truck,
after every feature's rules (`RUN_AFTER`: the Octodogs' planned charges and the Buzz Overdrives' cuts are
final by then), around the level's baits (`bait_points`): each Octodog's first planned wind-up and each
Buzz Overdrive's charge, with its warning (the wind-up, the rev) and its hold (`hold_seconds()` before the
warning, when the truck stops firing for it). A truck arrives (`at`, the runner's distance) so that a bait's
warning comes at least `bait_after_seconds` (4 s: it has settled behind the runner) after it and its charge
at least `bait_before_seconds` before it would give up (`in_chase`); where it can, the hold comes
`bait_prefer_min/max_seconds` (8-13 s, seeded) after it, so the runner sees a volley or two first (87 of
104 sampled trucks), then the nearest offsets in 0.5 s steps (`_arrival_for`). Never before the run-up or
the feature's start, never while a bait attacks (`arrival_keep_outs`: an Octodog's planned charges, a Buzz
Overdrive's attack window), up to `per_level_max` (2) a level, never two at once (each one's chase and drop
back `spacing_seconds` from the next); in a level paced in bursts it arrives in a burst where it can
(`pacing_pools`). The earliest baits get them first (with its showing windows planned, the ones whose chases have
room for its showing before their bait: Showing windows, below). Its params list the baits in its chase (`baits`).
Corporate 2 introduces it at a start of its own, 5% into the level (before the Tithe Collector's 10%; the
level's only baits at 3 and 6 lanes come within its first 32 s), so its first truck arrives within the
campaign's introduction reach (on other seeds an introduction whose first bait has no room may come later: Showing
windows, below).
It takes no room: `keep_out()` is empty and it uses no floor, and its entries take seeds of their own, so a
level with the feature is the same level plus its trucks and their showing windows (below), but for the danger
density pass, which counts every enemy entry (its target grew by one other enemy in 1 of the 18 builds of its six
levels on their own seeds). A level with no bait its chase can take gets none (quick play without Octodogs or Buzz
Overdrives). `problems()` re-checks every truck for the tests.

**Showing windows** (task C6c; GDD §9.13 "Showing itself", the owner, October 8, 2026: the player should see
what's chasing them). With `EnforcerTruckTuning.show_window_planned`, the rules plan a showing window in every
chase that has room (`ShowPlanner` in `enforcer_truck_rules.gd`), on the layout as the trucks are placed: a calm
stretch where it can pull up beside the runner and stay alongside wherever the runner is, at the level's speed. It
asks what the truck asks in play: no other enemy's big attack (its warning, its shots) and no enemy about near the
runner until it has stayed alongside (`busy`: their keep-outs; a host's possible Bad Dream chase is the player's
choice and doesn't count), no floor cut's attack, hover truck or Gilded Sentinel in the stretch, its bait's turn far
enough off (`hold_for`), and for a runner in every lane a lane beside them where its look fits on screen, its lane
stays clear for the whole stay, the runner keeps a lane to dodge into and it hides no enemy
(`EnforcerTruckRoom.layout_lane`, `fits_for`), also when it begins `show_window_slack_seconds` late. Windows where
no runner is sent off the floor (a pad's ceiling, a ramp's wall run) before it has stayed alongside come first;
its whole stay before a shorter one (`show_min_seconds` at least); as it arrives (any of its arrivals, the
preferred first) before mid-chase, mid-chase before its first bait before after it. Where the level leaves no such
stretch, it takes out what's in the way, only what the showing needs gone: plain holes and fences (never a pulsing
fence or one a fence generator powers), plain cyborgs, window cyborgs and Screeches (never a host, the first of a
kind the level introduces, or the last of its kind or of one of the level's features: the generator would build the
level again for a missing feature). **Which baits get trucks** (task C6d; the owner, October 9, 2026, GDD §9.13
"Room to show itself": it shows itself before the player can bait it, and a chase with no room for that gives its
truck to another bait's chase that has room): of every set of baits whose chases fit together (planned along the
track, each one again around the chases before it), the one with the most windows before their first bait, then the
most windows, then the most chases, then the earliest (`_choose`). A pair is also planned the other way round, the
later chase's window first and the earlier truck arriving earlier around it (`_plan_set`); the planner itself tries
every arrival a bait allows, the earliest too, before it settles for a window after the bait. At an arrival with a
bait under way (a Buzz Overdrive that claimed its turn before the truck arrives, its rev still to come: the rules keep
arrivals off its attack, not its claim) no window counts as before the bait, since its charge comes first
(`ShowPlanner._under_way`); the fallback after the bait starts after that attack. A level that
introduces the truck keeps its first bait's chase where that has room before its bait, and otherwise moves its
introduction only to a chase where it shows itself before its bait (its first-encounter hint is the level intro's,
and the cyborg planted in a charge path that teaches it comes earlier in the campaign, `test_charge_paths`). A later
window whose take-outs would now leave none of a kind after an earlier window's is planned again
(`ShowPlanner.still_fits`; none in the sampled builds). The window goes in the truck's params (`show`: {at, from,
to}); `gen.show_window_result` reports each chase (its bait, its window, its arrival against the preferred one,
what it took out, or why none) and each bait's own chase (`baits`: a window before or after the bait, or none, and
whether it got a truck). Every later pass keeps
off each window, `WINDOW_EDGE` (1 m) wider, as a **calm stretch** (`doodad_keep_outs` entries with `calm: true`):
nothing it adds may stand or attack there, but it's no attack, so nothing keeps a spacing from it and it shapes no
pass's search for room. The danger density pass rejects an enemy (where it stands, `CALM_ROOM` either side, and its
attack window) or a row in one (`Plan.calm`) without changing its rooms, so its draws are as before elsewhere; the
cyborgs planted in charge paths keep off one where they stand (`_cyborg_fits`); a wider gap keeps its row off one
(`row_only`); a zone doodad keeps itself and its push's lead off one, which shapes none of the doodads' stretches
(`doodad_keep_outs`' `calm`); the fill pass (`fill_keep_outs`, no margin) and City 1's extra gaps keep off it. A
Buzz Overdrive given a planted cyborg claims its turn earlier (`ChargePathTuning.claim_seconds`), after the trucks
are planned: the planner assumes that claim for every one (`least_claim`), so each window still holds in the
finished level (`ShowPlanner.problem_of`). With the switch off the level is built exactly as before. The counts
here and in C6d and C6e below were measured on the 15-level curve before the Casino; the Casino's levels and K4's
curve, merged with them in task K5, move them (`test_enforcer_truck` prints each level's windows). On the six
levels' own seeds, 16 of 23 chases get a window (8 as it arrives, 6 only after the first bait); the chases without
one have a hover truck or a Gilded Sentinel over their whole chase (4), or no calm stretch at all (Corporate 2 at 5
lanes: its introduction among an Octodog's charges, a Tithe Collector and a Buzz Overdrive's attack; Dead Zone 1 at 3
lanes: pulsing fences, a ramp's wall run and a Screech; Dead Zone 2 at 6 lanes: rows of fences with a pad in their
gap). Played with a runner keeping to each lane in turn (`tools/measure/enforcer_shows.gd`, Review tools), 57 of 106
chases show it (32 as it arrives), against 15 of 106 before; of the 75 with a window, every one shows it but 18 whose
truck the runner's bait or a wider gap destroyed before an after-bait window, and one whose runner a pad sent onto a
ceiling. The danger density pass's enemy and obstacle counts on its sampled
bands stay as they were; the windows cost the six levels about 2% of their enemies and obstacles (592 to 580 and
3281 to 3226 on their own seeds: what they took out, and what the fill pass and the pass's rows found no room
for). Every level without the truck, and every level with it with the switch off, builds exactly as before. The
planning adds about a quarter to those levels' build time (50-330 ms a build; the longest, Dead Zone 1 at 5 lanes,
1.9 s against 1.7 s). Task C6d (which baits get trucks, above) changes nothing on the levels' own seeds (every
campaign build is byte for byte as before): 9 of the 23 chases have a window before their bait (8 as it arrives,
1 mid-chase), 7 one after it, 7 none, and no other bait with room is left for any of those 14. The level's only
usable bait comes too soon for any showing before it (Golden 1 at 3 and 6 lanes, Golden 2 and 3 at 6: a Buzz
Overdrive revs 6.4 s in, 4 s after the run-up; Corporate 2 at 6 lanes: an Octodog's charges at the start keep the
truck from arriving earlier than 4.5 s before its Buzz Overdrive's turn), its only chase has a hover truck or a
Gilded Sentinel about throughout (Dead Zone 1 at 6 lanes, Golden 2 at 3, Golden 3 at 5), or its other bait with room
already has the level's other truck (Corporate 2 at 5 lanes: its introduction, a Tithe Collector about and then its
bait too near; Dead Zone 1 at 3 lanes; Dead Zone 2 at 5 and 6 lanes), or neither of its two baits has room (Dead Zone
2 at 3 lanes: pulsing fences and no lane beside a runner by the wall before its first; a hover truck over its
second). With 8 other seeds of each (162 builds in all), 9 builds change, all on other seeds: 71 of 226 chases have
a window before their bait against 63 of 227 (27 after it against 32), and a runner keeping to each lane in turn sees
the truck in 434 of 1058 runs against 421 of 1064 (a window before the bait brings its showing in 320 of 331 runs; in
the other 11 the runner is on a ceiling or a wall as it's due, in a lane its window wasn't planned to hold for (6),
its arrival showing begins but gives way before it comes alongside (4, in builds C6d left as they were), or a
Resonator holds its lane (1)); in two builds a level keeps one truck that shows itself
where it had two that didn't, and in one a pair planned the other way round gets back the second truck C6c's order
dropped. A wider gap (task G7) comes before a window only where that window comes after its bait (6 of 27).

**Making room** (task C6e; the owner, October 9, 2026, GDD §9.13 "Making room where there is none", answering items
367, 400 and 401). Where no window fits before the first bait as C6c and C6d planned it (`ShowPlanner`'s CLASSIC mode,
unchanged, so a chase that had one keeps it), the planner tries three more ways, in order (each window's params
carry its `mode`: "around", "claim" or "calm"; CLASSIC's none):
- **AROUND: beside a hover truck or a Gilded Sentinel** (they no longer stop a showing, as long as the runner keeps a
  free lane). `EnforcerTruckRoom` reads each hover truck's lane as held over its stay (`held`, `held_lanes`): a wall
  to the runner, never the truck's lane, and never with the truck between the runner and it (`sides`,
  `escape_lane`, `can_dodge`, `shadow_clear` and `layout_lane` take the held lanes; `fits_for` adds the views two
  lanes in from a runner beside it). What can't wait for a turn (`fixed`: a hover truck's entrance, from its banging
  to its emerging, `entrance`; a Sentinel's turn, from its claim to its last swing, `sentinel_turn`) is never on as
  the truck claims its turn for the window or begins, and the showing is back `show_margin_seconds` before the next
  (`hold_for`'s `to_fixed`); their other attacks take turns and wait for it. A window here may leave out one runner
  lane no showing could reach (`EnforcerTruckRoom.unreachable`: every lane beside it held, a floor cut's, or hiding
  the hover truck; its report's `excused`), never two; and it reads what blocks the runner's lane only as far as its
  stay reaches (`layout_lane`'s `clip`, as the truck in play does).
- **CLAIM: its bait's claim during it.** As AROUND, with a Buzz Overdrive's claim on its turn coming during the
  showing (it begins before the claim, which only holds back attacks that get ready later), out of view
  `show_margin_seconds` before the tank's rev (`hold_claimed`; `EnforcerTruckRoom.revs`, an Octodog's turn as before,
  `dog_turns`); skipped where no tank revs near the chase (`_revs_near`: it would plan nothing AROUND didn't).
- **CALM: the calm start.** For the chase of a level's first bait, the truck may arrive inside the run-up, from
  `calm_start_min_seconds` (0.5 s, DESIGN-TBD) into the run and the feature's start, at its follow gap, and show
  itself as it arrives (`_calm_spots`, latest first; `arrival_problem`'s `calm`), its bait where it was; it takes
  nothing out (`calm_start_takes_out` off, DESIGN-TBD), and it fires no volley in the run-up. Nothing in the run-up
  shows on screen but the HUD, which no truck can cover (hints come on the level introduction before PLAY).
- **Both trucks** stay where a level has two but room for one showing (item 401, as built: since task K5 Corporate 2
  at 6 lanes and Dead Zone 2 at 5 and 6 lanes, `test_enforcer_truck`'s `BOTH_TRUCKS`), and wider gaps keep off each
  chase from its arrival to its window's end (Wider gaps, Which).
- **The claim, in every mode** (the H merge, with task H1's 0.6 s Sentinel warning): CLASSIC's `quiet` keeps hover
  trucks and Sentinels off the window alone (from its start and 10 m before it), and H1's shorter Sentinel turn let a
  CLASSIC window fit right behind a Sentinel's swing with the truck's claim beginning during the next Sentinel's turn;
  the claim (a big attack on, `EnforcerTruck.is_major_attack_active`) would then have that Sentinel let the runner pass.
  `ShowPlanner._window` keeps the claim off `fixed` in every mode now (`test_enforcer_truck`'s Sentinel case needs it at
  3, 5 and 6 lanes); on the campaign's builds on K4's curve it changes no window (item 673).

On the six levels' own seeds 12 of the 23 chases get a window before their bait against 9 (Dead Zone 1 at 6 lanes
beside its hover truck, 1767-1962 m; Golden 1 at 3 lanes in the calm start, the truck arriving at 12 m with its
window from the start to 177 m, where it had one after its bait at 293-508 m; Golden 2 at 3 lanes with its Buzz
Overdrive's claim, 138-360 m), and every other build's windows stay where they were. A runner keeping to each lane
in turn (`tools/measure/enforcer_shows.gd`) sees the truck in 73 of 106 runs against 57. The 11 chases still without
one: a hover truck at 3 lanes leaves two of the three runner lanes no free lane (Dead Zone 2's second truck), rows
of fences with a pad in their gap or pulsing fences leave a runner lane no lane beside it (Dead Zone 1 at 3 lanes,
Dead Zone 2 at 3 and 6), the level's other chase leaves a second truck only arrivals too near its bait (Dead Zone 2 at
5 lanes), a Tithe Collector is about over the only stretch its bait leaves (Corporate 2 at 5 lanes, its
introduction, and at 6), the calm start has room only by taking out what's in the first
patterns (Golden 1 and 2 at 6 lanes, Golden 3 at 5: 2, 8 and 2 pieces; `calm_start_takes_out` on would give them
theirs), and Golden 3 at 6 lanes has a fence a generator powers there. Of the 33 runs without a showing, 21 are in
the five chases with no window at all, 9 in chases whose window comes after the bait that destroyed the truck first
(the measuring runner never dodges), and 3 in chases with one before: the runner lane a window leaves out beside a
hover truck (Dead Zone 1 at 6 lanes, lane 5), a pad sending the runner onto a ceiling as it's due (Golden 2 at 3
lanes, lane 0), and an arrival showing given way to a passing attack (Corporate 2 at 5 lanes, lane 0). With 8 other
seeds of each (144 builds), 132 of 204 chases have a window before their bait against 62 of 203, and the truck shows
itself in 637 of 957 runs against 377 of 952; a window before the bait brings its showing in 298 of 307 runs in
CLASSIC, 132 of 177 beside a hover truck or a Sentinel (one of their attacks begun before the truck's claim still on
as it's due, 33), 150 of 175 with a claim and 27 of 28 in the calm start. The windows the new modes plan take out
about 1% more of those levels' obstacles (on their own seeds 580 enemies and 3226 obstacles before, 577 and 3219
after; on the other seeds 4756 and 26686, 4734 and 26399), every build keeps its wider gaps, and every level without
the truck builds exactly as before. The new modes add about two fifths to those levels' build time (the 18 builds on
their own seeds, fastest of three: 13.9 s against 19.6 s; the longest, Dead Zone 1 at 5 lanes, 3.0 s against 2.1 s;
Corporate 2 at 5 lanes 2.5 s against 0.9 s, its introduction's chase searched in every mode).
DESIGN-TBD: item 386
(`docs/OPEN_QUESTIONS.md`), the chases no bait with room is left for (items 402–403), and C6e's placeholders
(items 407–411); items 382–385, 367, 400 and 401 are the owner's answers.

**Late starts.** `LevelConfig.feature_starts` (feature → share of the level) holds a feature back
until its start: patterns that require it aren't picked before, and the first pattern picked from
there must use it (its introduction), so the encounter follows its scheduled start rather than
whenever chance brings it; its first-encounter hint is now on the level introduction. A rules script that adds a feature's enemies or pieces keeps
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
- `feature_positions(layout, feature)` finds a feature's pieces: enemies by type, hosts (and cyborgs that
  aren't hosts, nor planted in a charge's path, task G7), wall-vent
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
  average in the campaign). A level whose wider gaps its first wall-run gap crowded out is built once
  more after the guarantee, that build kept only if it has everything (task J2; generator-track-features,
  Wall-run gaps, Giving way); `attempts` doesn't count it.
- Rules that hold the room for a feature themselves also add one where it fits when a level is left
  without any, which saves a build: a drone wave and a hover truck in any level (their tunings'
  `guarantee_one_wave` and `guarantee_one`), and a host, an Octodog and a Resonator in a level with
  `guarantee_features`.
- A feature with no pattern of its own, which its rules place only around other features' entries, is
  required too when one of those is (`dependent_features()`, from its rules script's `GUARANTEED_BY`): the
  Enforcer Truck, which waits for an Octodog's or a Buzz Overdrive's charge during its chase. A build
  without one forces picks of those features instead (`_guarantee_picks_for`; one more each a build, however
  many missed features ask for it), so their entries move until one leaves the truck room to arrive (task
  K4: a rare seeded build had none, on the earlier curves too). Rules whose data allows none (a static
  `places_any()` false: the truck's `per_level_max` 0) ask for none.
- A feature sprinkled in rather than guaranteed (its rules script's `OCCASIONAL`: the ceiling scenarios, task I4,
  which take a level's own ceilings only where one fits) is never required, and the campaign checks don't ask
  every build for one (`LayoutChecks.occasional`); `test_ceiling_scenarios` counts them over the campaign.

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

**Company for the Buzz Overdrive** (task L2; the owner, October 17, 2026: other enemies and track hazards on the
playfield with it "unless this is done for performance", sparse being fine where an Enforcer Truck is likely on the map
with it; `BuzzCompanyPlacement`, `scripts/world/buzz_company_placement.gd`, its numbers in `BuzzCompanyTuning`,
`data/tuning/buzz_company.tres`, F6 "Buzz Overdrive company"). Why its stretch was empty: its pattern holds its whole
encounter (200 m at the reference speed, about 11 s), and every pass after the rules kept its cut's window (from where
it sets off to the cut's end, about 9 s) clear in every lane: the fill pass, the danger density pass and the doodads
(B4's placeholder, "nothing else goes on during a cut") and the wall fences (B5's, "one thing at a time"). None of it
was for performance (the tank is cheap to run: Enemies, A floor cutter). In a level with `LevelConfig.buzz_company`
(every campaign level with the Buzz Overdrive; off in quick play, the tests' own levels and boss arenas, which build
exactly as before), after the danger density pass's floor pieces and before the doodads, from a stream of its own,
every tank but the level's introduction of it (`on_introduction`) and those an Enforcer Truck's chase comes within
`truck_margin_seconds` of (`truck_near`) gets company in its stretch, from where it sets off to its window's end
(`stretch_of`): in every lane but its own while it rolls in; over its attack (from `attack_margin_seconds` before its
rev, `attack_of`) also out of its escape lane, a neighbour of its lane clear of everything over the attack (the cut's
`company` key; -1, and nothing in the attack, where neither is), so a runner in its lane at the warning leaves into it
and runs on there whatever the rest holds; holes there only where GDD §9.9's whole lanes allow (none on 3 lanes, never
beside the cut). Cyborg encounters (one of the level's plain cyborg patterns, `cyborgs_max`, `cyborg_chance`) by the
danger density pass's own rules for an enemy it adds (`DangerDensity.enemy_fixed_stretches` without this tank's window:
off pads, landing zones, plain ceilings and the rest; a couple of small attacks near at most, a free lane, the cyborg
rules' margin; never before a level's introduction of cyborgs), plain and never the panic variant, holding their fire
from just before the warning to just past the window (`hold_fire`), one met in the attack only beside the escape lane;
rows of holes or fences (the level's one-row fillers, `rows_max`) with the fill pass's spacing from everything, a lane
left free beside each. Each addition re-checks what it could take from the cut (its lane, its whole lanes, its escape:
`cut_escape_clear`); the pieces get no risky credit. Wall fences run by a tank with company, keeping only their drop
rule (Wall fences). The passes before it build every level exactly as without it, and the Enforcer Truck's chases and
the introductions come out as before. No Octodog: its charge sequence and the tank's are big attacks that take turns,
and its 9 to 13 s don't fit the 5.5 s the tank is in view before its claim. Measured (`tools/measure/buzz_company.gd`,
each level's own seed and four others at 3, 5 and 6 lanes, 135 builds): the 33 tanks it gives company to (21 in
Corporate 1, 12 in the next five levels, none in the Golden Zone, where a truck is always about) every one got some;
their visits went from 0.24 threats a second to 0.60 (the rest of a level 0.52 to 0.84), their attacks from 0.03 to
0.44, a cyborg in 67% of them (9% before; 38% on 3 lanes, 83% and 88% on 5 and 6), a row in 61% (42%), and their
longest stretch with no threat from 6.2 s to 2.7 s; the wall fences' share of it is large (Corporate 1's company visits
0.28 a second against 0.12 elsewhere). `LayoutChecks.check_buzz_company` (from `check_layout`) holds every layout to
it; `test_buzz_company` checks it. DESIGN-TBD: items 933-941 in `docs/OPEN_QUESTIONS*.md`.
