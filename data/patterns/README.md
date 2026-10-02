# Generator patterns

The level generator (`scripts/world/level_generator.gd`) picks patterns from **every `.json` file in
this folder**: the level's main file (`prototype_patterns.json`) first, then the others in name order.
Every pattern uses abstract gameplay pieces only, and no pattern assumes a lane count.

A level only picks patterns whose `requires` entries are all in its `features` list
(`LevelConfig.features`), so a pattern file for a new enemy type changes nothing until a level turns
that enemy on (GDD §6: introduce one new mechanic at a time). The campaign's levels already list the
enemies and mechanics still to be built, under the names their patterns must require (see
`LevelConfig.PLANNED_FEATURES`).

A level can start a feature partway in (`LevelConfig.feature_starts`: feature → share of the level).
Patterns that require it aren't picked before its start, and the first pattern picked from there is one
that requires it, so the level introduces it right there. Give each feature at least one pattern that
fits low difficulties, or its introduction waits until one fits. `LevelConfig.feature_weights` (feature
→ factor) scales the pick weight of every pattern that requires the feature.

A boss fight's arena (`BossArena`, `docs/ARCHITECTURE.md` Bosses) plans its laps from these files too,
with the features of the boss's arena config (`BossDef.arena`), no ramp within a lap and no credits.
Patterns meant only for one boss's arena (a train's carriage gaps, say) require a feature of its own
that only that arena config lists, so no level ever picks them (the tests accept a feature a boss's
arena lists as a known one).

Every feature a level lists appears in it (`LevelConfig.guarantee_features`, set on every campaign
level; GDD §5: an introduced feature keeps appearing), at any lane count and on any seed. Features
appear through their patterns, and the enemy rules drop or clear what doesn't fit fairly, so the
generator checks the finished level and builds it again with picks of any missing feature forced at
new spots, changing no rule (`docs/ARCHITECTURE.md`, Every feature appears). What that means for
patterns:
- A feature is required only where one of its patterns can be picked: in the level's lane count
  (`min_lanes`) and difficulty range, with every feature it `requires` in the level. So a planned
  feature isn't required until its patterns exist, and then every level that lists it gets it.
- Give each feature patterns across the difficulty range of the levels that list it: a forced pick
  (like an introduction) waits until one of the feature's patterns fits the difficulty there.
- The check finds a feature by its pieces (`LevelGenerator.feature_positions`): an enemy type by its
  enemies, `ramps`, `ceilings`, `speed_pads` and `pulsing` by their ramps, pads, speed pads and
  pulsing fences, and the wall fences by theirs (full-height ones for `wall_fences`, partial ones for
  `wall_fences_partial`). A feature with a new kind of piece needs its rules script to declare
  `static func positions(layout: LevelLayout) -> Array[float]` (the track distances of its pieces), or
  an entry in `feature_positions`.

Beyond that guarantee, a campaign level's newest things get the most picks (GDD §5; the campaign's
recency curve, `data/tuning/feature_recency.tres`): a pattern's `weight` is multiplied by the curve's
factor for its newest required feature, by how many levels ago the campaign introduced it (4 in the
level that introduces it, then 2.5, 1.75 and 1.25, then 1; never more than a capped feature's cap, 1
for the host, the hover truck, the drone, the Octodog, the Resonator and the vent screech), and the features'
patterns are scaled back kind by kind to weigh together what they did: patterns with an `enemy`
element by the enemies they place, those with only a `gap`, `fence` or `sign`, and the safe ones (a
`hull`, a `ramp`, a `speed_pad`), so plain obstacles keep their share and a level places as many
enemies and obstacles as before. So a pattern's `weight` says how often it comes against the other
patterns of its kind, feature and age; a pattern that combines an old feature with a new one follows
the new one, and adding an `enemy` element to a pattern moves it to the enemies' kind. Quick play
and tests have no curve. See `docs/ARCHITECTURE.md`, The generator.

**Metres are at the reference speed.** Every distance a pattern gives in metres (a pattern's
`length`, an element's `at`, a sign's `length`, credits' `spacing`) is written for 18 m/s
(`MovementTuning.REFERENCE_SPEED`), and a level at another speed stretches it by its pace (its run
speed over 18: 21 m/s in the Neon City to 25 m/s in the Golden Zone, GDD §3), so every pattern keeps
its timing in seconds at every zone's speed (`docs/ARCHITECTURE.md`, Pace). Write a pattern as it should
play at 18 m/s. `at_seconds`, `length_seconds` and `jump_frac` follow the run speed on their own.

**Fillers.** Campaign levels are busier (GDD §3): after the patterns and the rules, the generator's fill
pass puts more of the level's plain obstacle patterns into its long empty stretches
(`LevelConfig.fill_empty_seconds`). A filler is any pattern that `requires` nothing and has only `gap`
and `fence` elements (`LevelGenerator.is_filler`); it's picked by its difficulty range and `weight` like
any pick, and spaced from everything around it as the pattern pass spaces patterns. So a new plain
obstacle pattern can also come as a filler; one that needs a feature, a sign, a ceiling or an enemy
never does.

**Zone doodads** aren't patterns: after the fill pass the generator stands them (scenery that pushes the
player into the next lane, never hurts; GDD §3) in whatever stretches nothing else uses, with the
level's spacing after them (`LevelConfig.doodad_share`, `docs/ARCHITECTURE.md`, The generator). A pattern
needs nothing for them, and a doodad never comes near a pattern's pieces or enemies.

A level may be paced in quiet stretches and bursts (`LevelConfig.quiet_seconds`; The Hush): a quiet
stretch picks only patterns without enemies (sparse obstacles, and safe mechanics such as a plain
ceiling, a ramp or a speed pad) and those of the level's `quiet_features`, which belong there (their
enemies stand inside the stretch); a burst
picks only threats, patterns with a `gap`, a `fence`, a `sign` or an `enemy` element, and only those
whose enemies stand inside the burst (an enemy's `at` counts, not the pattern's `length`, so a long
pattern like the Octodog's fits when its dog does). Patterns need nothing special for it.

## Pattern fields

| Field | Meaning |
|---|---|
| `id` | Name shown in logs and tests |
| `min_difficulty` / `max_difficulty` | The pattern can be picked only while the current difficulty (0–1) is in this range |
| `weight` | Relative pick chance among the patterns that qualify |
| `min_lanes` | Optional. Skip on devices with fewer lanes |
| `requires` | Optional. Features the level must have: `ramps`, `ceilings`, `pulsing`, `speed_pads`, an enemy type (`cyborg`, `window_cyborg`, `host`, `hover_truck`, `octodog`, `screech`, `drone`, `generator`, `resonator`, `tithe_collector`, `gilded_sentinel`), `screech_vents` (wall-vent screeches only, rare, for zones whose floor has no manholes, GDD §9.5), or a planned one: `buzz_overdrive`. (The wall fences, `wall_fences` and `wall_fences_partial`, and the Barnacle Turret have no patterns: see below) |
| `length` | Metres of track the pattern takes (the generator extends it for long gaps and hulls) |
| `elements` | The pieces to place (see below) |

## Element kinds

`at` is the offset in metres (at the reference speed, stretched by the level's pace) from the pattern's
start. `at_seconds` adds an offset in seconds at run speed, so pieces keep their timing against a hull
when run speed changes.

| Kind | Fields |
|---|---|
| `gap` | `lanes`, `jump_frac` (gap length as a fraction of a full jump's distance, capped by the level's `max_gap_jump_fraction`) |
| `fence` | `lanes`, `variant` (`full` = jump or switch lanes; `gapped` = slide under), `pulse_chance`, `pulse_on`, `pulse_off` (seconds) |
| `sign` | `side` (`left`/`right`/`random`/`both`/`same`), `length`, `bottom`, `top` (height band on the wall, in metres) |
| `ramp` | `side`. The ramp sits in the outermost lane on that side and launches the player onto the wall, higher than a free entry and with a speed boost that fades like a speed pad's (GDD §3): its wall run covers about 43 m at 18 m/s, against 39 m for a free entry. A wall piece after it meets a faster, higher runner; `RampLaunch` says where the runner is and how high (see Ramps in `docs/ARCHITECTURE.md`) |
| `hull` | `lanes` (where the anti-grav pad goes), `length_seconds` (how long the ceiling lasts at run speed). The pattern's other elements may lie under it (see Ceilings below); its landing zone and its pad's spot stay clear, and the generator drops (with a warning) what the pattern puts there. The ceiling covers every lane, or in a level with narrow ceilings a range of lanes holding its pads (see Narrow ceilings below) |
| `speed_pad` | `lanes`. A speed pad in each lane (GDD §6 only names speed pads; FB 21, FB 49) |
| `enemy` | `type` (the enemy type name), `lanes` (floor enemies; one per lane) **or** `side` (wall enemies, e.g. window cyborgs: `left`/`right`/`random`/`same`), `params` (passed to the enemy as `spawn.params`). An enemy may stand under a ceiling; one whose type uses the floor (its tuning's `uses_floor` and reach, wall vents included) keeps off a ceiling's landing zone and its pads' spots |
| `credits` | `surface` (`floor`/`ceiling`/`wall`), `lanes` or `side`, `count`, `spacing` (m), `value` (1, 5, 25 or 100), `height` (m from the surface, or the height on the wall) |

Credits are also placed automatically after the patterns (trails in clear stretches; rich credits at gap
edges, by fences, along each ramp's wall run on the path the boosted runner takes, and on ceilings),
tuned in the level's Credits group.

## Ceilings over a dangerous floor

GDD §3 (changed September 26, 2026): the floor beneath a ceiling may hold gaps, hazards and enemies,
and the ceiling is the way to escape them, so it's the easier route; it's never required. A pattern
with a `hull` may put its own pieces and enemies under the ceiling: a gauntlet. Every ceiling keeps two
stretches safe all the same (`CeilingZones`, `docs/ARCHITECTURE.md`):
- **Its landing zone:** from the ceiling's end, `hull_landing_seconds` (1.2 s) at run speed, no gap or
  fence in any lane the ceiling covers and no floor enemy's reach in any lane, so the player always
  lands safely. A pattern's `used` length includes it, so the next pattern starts past it.
- **Its pad's spot:** in the pad's lane, no gap, fence or ramp from a full jump (about 12 m at 18 m/s)
  before the pad until its lift reaches the hull (about 8 m after it), and no floor enemy's reach (any
  lane) where the pad lies.

What a pattern puts in those stretches is dropped, with a warning. Writing a gauntlet:
- Time its pieces with `at_seconds` against the hull, from about 1 s after the pad to the ceiling's
  end, and space them like patterns (about 1 s apart): the floor runner meets them one after another.
- Leave a way through every row (`all_but`, a jumpable hole, a gapped fence to slide under), as every
  pattern does. The tests look for a floor route under every ceiling that never takes the pad
  (`FloorRoute`) and run some of them on real physics.
- Keep enemies' margins: cyborgs stand 10 m clear of pads, fences, holes and landing zones (their
  rules drop them otherwise), a screech's reach runs 30 m before its manhole, a generator powers the
  fences ahead of it.
- Give it a `min_difficulty` above the ceilings' introduction (City 2 introduces ceilings at about
  0.18), so the player meets a plain ceiling first (GDD §6: one new thing at a time). The gauntlets so
  far: `ceiling_over_fences` (0.3), `ceiling_over_holes` (0.35), `ceiling_over_gauntlet` (0.5), and
  with enemies `ceiling_over_cyborgs` (0.35), `ceiling_over_manholes` (0.3), `ceiling_over_generator`
  (0.4). DESIGN-TBD: their mix and weights (`docs/questions/b2.md`).

Ceilings that rules add (the drone's pad schedule, a Bad Dream chase's pads) lie over whatever the
floor holds there: only their landing zone and their pad's spot are cleared.

## Narrow ceilings

GDD §3 (decided September 26, 2026): ceilings don't have to cover every lane, and on one the player
switches lanes only within its width. A pattern doesn't choose: in a level with a `narrow_ceiling_share`
(the level's Narrow ceilings group; DESIGN-TBD, `docs/questions/b3.md`) that share of its ceilings, the
patterns' and the rules' alike, cover a range of lanes holding their pads, from the level's
`narrow_ceiling_start` on. A pattern with several pads under one hull keeps them all under it. A
one-lane ceiling (`one_lane_ceiling_share` of the narrow ones) comes only from a pattern that puts
nothing but its hull (and credits) on the track, and is cut to `one_lane_ceiling_seconds` (1.6 s) from
its pad, whatever the pattern's `length_seconds`; a gauntlet's ceiling always covers at least two lanes.
What a gauntlet puts in the lanes beside a narrow ceiling is floor like any other: the floor route
under the ceiling and the landing zone in its lanes are checked as always.

## Lane selectors

`{"mode": ...}`, with `count` (a number of lanes) or `frac` (a fraction of the lane count, rounded, at least 1):

- `all`: every lane
- `all_but`: every lane except `count`/`frac` random lanes, which stay free
- `random`: `count`/`frac` random lanes
- `edge`: one outermost lane, picked at random
- `center`: the middle lane
- `same`: the lanes the previous element used
- `others`: every lane the previous element didn't use

## Enemy rules

Rules that patterns can't express (e.g. "an anti-grav pad at least 10 s after a drone appears, then every
8–10 s", GDD §9.6) go in `scripts/enemies/<type>_rules.gd` as `static func apply(gen: LevelGenerator)`.
They run after the patterns, in the order of the level's `features` list; a script that declares
`const RUN_AFTER: Array[String] = [...]` runs after those features' rules whatever the order (the host
rules plan the Bad Dream's pads around the drones' pad schedule, and the Octodog rules plan each dog
around both). A ceiling a rule adds (`add_hull_with_pad`) lies over whatever the floor holds, but keeps
its landing zone and its pad's spot off the floor that enemies use (`LevelGenerator.enemy_floor_span`);
a pad a rule guarantees at a spot, clearing only those two stretches, comes from
`scripts/enemies/pad_placement.gd`.
Anything a rule adds keeps to its feature's start (`LevelGenerator.feature_active`). A rule that drops
its feature's enemies where they don't fit may also add one where it does when a level that guarantees
its features (`gen.config.guarantee_features`) is left without any (the host, Octodog and Resonator
rules do), which saves the generator another build. In a level paced in bursts, a rule that picks such a spot
itself puts the enemy in a burst when it can, or in a quiet stretch if its feature is one of the
level's quiet features (`gen.burst_spot(...)`, `gen.pacing_pools(spots, feature)`, `gen.quiet_at(at)`).
See `docs/ARCHITECTURE.md`.

The Resonator's pattern (`resonator.json`) places one Resonator over the middle lane and nothing else,
and its `length` (135 m) keeps the floor clear where its first two pulses' waves meet the player (it's a
flier: its own spot needs no floor). Its rules (`resonator_rules.gd`, after every rule that puts things
on the floor or plans a big attack) then plan each pulse where the wave meets the player on floor that
is clear in every lane (no gap, fence, floor enemy, pad or ceiling landing, and off every Octodog's
run), move a Resonator whose visit doesn't fit a little earlier or later, keep one visit at a time, and
drop what still doesn't fit. Other patterns need nothing for it: the Resonator only uses floor that's
clear already.

The Tithe Collector's pattern (`tithe_collector.json`, GDD §9.12, task C5) places one Tithe Collector
over the middle lane, the same shape as the drone's: a short `length` (10 m), picked many times across
a level, each its own approach (it's a flier, `uses_floor` false, that appears ahead of the player and
closes in on its own, like the stand-in thief's). It needs no rules script: it decides which lane to
weave toward live, from the layout already around it (gaps, fences, floor cuts, other floor enemies),
so other patterns need nothing for it either, and it can never make a lane unfair (touching it is never
a hit, CLAUDE.md principle 4).

The Barnacle Turret (`barnacle_turret`) has no patterns, and no pattern should require it: its rules
(`barnacle_turret_rules.gd`, after every rule that adds or takes away ceilings) hang turrets from the
ceilings the level already has (never a one-lane one, at most 2, off the pads' lanes and the ceiling's
credits), so the pattern pass, the recency curve and the guarantee's forced picks never count it, and a
level is the same with or without it bar its turrets. Its introduction (Marketplace 1) comes soon after the
feature's start: where no ceiling it fits on lies there, the rules add a plain one, only where one fits
without clearing anything. For patterns this means only that their ceilings may get turrets: a ceiling's
landing zone, pads and floor stay exactly as the pattern made them.

Wall fences (task B5; GDD §9.1: electric fences across the wall-run path that switch off and on; full-height
ones, `wall_fences`, from Marketplace 2, and from the Corporate zone partial ones over the low or the high part
of the wall, `wall_fences_partial`) have no patterns either, and no pattern should require them: the generator
adds them after the zone doodads, from a random stream of their own (`scripts/world/wall_fence_placement.gd`),
only where they're fair (never on a wall section with a sign or a window cyborg, never where a wall vent's
screech swipes up the wall, never where a ramp launches the player along their wall, the outer lane beside
them clear of holes, fences, floor cuts, anti-grav pads and floor enemies to drop into, no floor cut or big
attack meanwhile). So a level is built exactly as without them but for its wall fences, and patterns need
nothing for them: a pattern's signs, window cyborgs, wall vents, ramps and outer-lane pieces simply leave
less of the wall to them. See `docs/ARCHITECTURE.md`, The generator, Wall fences.

Floor cuts (task B4; GDD §9.9, the Buzz Overdrive's: a lane's floor that turns into a hole during play)
have no patterns either: a rules script plans them after the patterns and every other rule
(`floor_cutter_rules.gd`, the debug-only stand-in; task C2's Buzz Overdrive will do the same). It plans a
cut with `FloorCutPlan.make()`, makes room with `scripts/enemies/cut_placement.gd` (only holes, fences
and speed pads in the cut's lane over its window, and holes beside it beyond what may stay, go) and adds
the cut's cause at its end; `LevelGenerator.add_cut()` refuses any cut that breaks GDD §9.9's limits
(one at a time, never a lane with a ramp, a pad or a ceiling's landing zone, the other lanes whole
enough, nothing else going on, a way out). For patterns this means only that a cut never runs where a
pad, a ramp or a ceiling's landing zone is in its lane, and that a pattern's holes, fences and speed pads
may make way for one. See `docs/ARCHITECTURE.md`, The generator, Floor cuts.
