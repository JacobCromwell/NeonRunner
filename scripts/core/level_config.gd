class_name LevelConfig
extends Resource
## One level: generator settings plus what the campaign shows. Campaign levels use fixed seeds.
## The campaign (Campaign/ZoneDef) sets difficulty and enemy_scaling from the level's position, unless the
## level is off its curve (off_curve); standalone use (quick play, tests) takes the values stored here.

## Features the campaign schedule (GDD §5) already lists for enemies and mechanics that aren't built
## yet. Each does nothing until its code and patterns exist: its patterns `require` the name, its
## generator rules go in scripts/enemies/<name>_rules.gd, and an enemy type of that name is found by
## EnemyDirector. So those tasks add their own files and never edit level data.
## - barnacle_turret: the Barnacle Turret, a ceiling hazard (GDD §9.8), from Marketplace 1
## - resonator: the Resonator (GDD §9.10), from Golden 1
## tithe_collector (GDD §9.12, Corporate 2, then the Golden Zone) is built (task C5): its own script,
## tuning and pattern (data/patterns/tithe_collector.json) place it, so it's out of this list. So are the
## wall fences, `wall_fences` and `wall_fences_partial` (task B5: the generator places them,
## WallFencePlacement), buzz_overdrive (GDD §9.9, from Corporate 1 through the Golden Zone; task C2:
## its pattern, data/patterns/buzz_overdrive.json, and its rules, buzz_overdrive_rules.gd, place it),
## gilded_sentinel (GDD §9.11, Golden 2 and the Golden Palace; task C4: data/patterns/gilded_sentinel.json
## and its rules, gilded_sentinel_rules.gd), debris_maze (GDD §5, Zone 8, the Terminal's; task O2: its rules,
## debris_maze_rules.gd, build it, DebrisMaze), and centipede (GDD §9.15, the Terminal's only enemy, from Terminal 1;
## task O3: its rules, centipede_rules.gd, place it in the maze's cells; no pattern).
const PLANNED_FEATURES: PackedStringArray = ["barnacle_turret", "resonator"]

@export var id: StringName = &"prototype"
## DESIGN-TBD: campaign level names are placeholders (GDD §5 names only the Golden Palace).
@export var display_name: String = "Prototype"
@export var level_seed: int = 1
## Lane count on floor and ceiling used by the generator. The game sets it from the device when a
## run starts (GameRules.lanes_pc / lanes_mobile); tests and the F1 debug key set it directly.
@export_range(3, 8) var lane_count: int = 3
## GDD §4: levels last 90–150 seconds. DESIGN-TBD: each campaign level's length (together they make
## GDD §5's "a flawless run through every level takes about 40 minutes").
@export_range(30.0, 150.0, 1.0, "suffix:s") var duration_seconds: float = 120.0
## The run speed this level is built and played at (GDD §3, owner's playtest September 30, 2026: it
## rises zone by zone). 0: its zone's (ZoneDef.run_speed) in the campaign, else the movement tuning's
## base run speed (quick play, tests). Campaign.configure writes the level's own speed, its zone's or
## 0 into its copy, times the difficulty tier's speed multiplier. The generator, the run's world and
## the enemies all take their movement tuning from movement_for(), so they agree on it; the level
## keeps its duration in seconds and gets longer in metres.
@export_range(0.0, 40.0, 0.1, "suffix:m/s") var run_speed: float = 0.0
## 0 = easiest, 1 = hardest. In the campaign this is the campaign curve plus difficulty_bias.
@export_range(0.0, 1.0, 0.05) var difficulty: float = 0.3
## Added to the campaign's automatic difficulty curve for this level (GDD §6: each level can be
## tuned individually on top of the curve). DESIGN-TBD: City 1 −0.05; Golden 2 +0.05, the peak
## (GDD §5, proposed); Golden 3 −0.05.
@export_range(-0.5, 0.5, 0.05) var difficulty_bias: float = 0.0
## DESIGN-TBD: how difficulty rises within one level. Added linearly from start to end.
@export_range(0.0, 1.0, 0.05) var difficulty_ramp: float = 0.25
## 0 = first campaign level, 1 = last: enemies scale fire rate, speed and health with it (GDD §6).
@export_range(0.0, 1.0, 0.05) var enemy_scaling: float = 0.0
## Off the campaign's difficulty curve (task D10c; the owner, October 9, 2026: the Beach goes between Corporate and
## the Dead Zone, after the playtests every other level was tuned in): the campaign plays this level at its own
## difficulty (plus the difficulty tier's bonus; difficulty_bias doesn't apply) and enemy_scaling instead of at a
## place on its curve, and leaves it out of the curve's count and of the other levels' feature ages, so every
## level on the curve keeps exactly the difficulty, enemy scaling, ages and recency it had (Campaign.configure).
## Its own feature ages count every level before it. Off: the level is on the curve, as every level was before.
## DESIGN-TBD (docs/OPEN_QUESTIONS.md, items 569–572): the Beach's two levels; whether the curve is later re-spread over every
## level, the Beach's included.
@export var off_curve: bool = false
## A mini-game this level plays instead of a generated layout (MiniGame; the owner, October 10, 2026: the Beach's
## second level, a beach volleyball match, data/minigames/volleyball.tres): LevelRun asks the game for the level's
## track and the game runs on it, so the generator, the features and the pacing below don't apply. Such a level
## sits off the curve (off_curve) and counts for no other level's feature ages (Campaign.feature_ages). Null: a
## generated level, as every other level is.
@export var minigame: MiniGameDef
## Mechanics and enemies this level may use. A pattern is only picked when every entry of its
## `requires` list is here (GDD §6: introduce one new mechanic at a time). Core movement pieces
## (gaps, fences, signs, walls) need no feature. Known features:
## - mechanics: ramps, ceilings (anti-grav pads and ceiling sections), pulsing (pulsing fences),
##   speed_pads
## - one per enemy type: cyborg, window_cyborg, host (cyborgs carrying a Bad Dream), hover_truck,
##   octodog, screech (from manholes and wall vents), drone, generator (fence generators)
## - screech_vents: sewer screeches from wall vents only (rare), for zones whose floor has no
##   manholes (GDD §9.5)
## - wall_fences: full-height wall fences (GDD §9.1), from Marketplace 2; wall_fences_partial: wall
##   fences over the low or the high part of the wall only, from Corporate 1 (task B5; no patterns: the
##   generator places them, WallFencePlacement)
## - wall_gaps: side wall gaps, stretches of a side wall with no wall-running surface (owner's
##   answers, docs/USER_REQUESTS.md), from Gangland 1 (Zone 2) on, never in a boss arena unless the
##   arena opts in with wall_gap_tuning (no patterns: the generator places them, WallGapPlacement;
##   tuning in data/tuning/wall_gaps.tres, or the level's own, wall_gap_tuning)
## - enforcer_truck: the Enforcer Truck (GDD §9.13; task C6), from Corporate 2 (no patterns: its rules,
##   enforcer_truck_rules.gd, bring it in around the level's Octodog and Buzz Overdrive charges, its baits,
##   so a level needs octodog or buzz_overdrive for it to appear)
## - dash_wall: dash walls, buildings across every floor lane the runner dashes through (GDD §9.14; task
##   H7a), from Corporate 1 (no patterns: their rules, dash_wall_rules.gd, stand up to dash_walls of them
##   where they're fair)
## - treasure_stash and fenced_ceiling: the ceiling scenarios (task I4; GDD §3, "Ceiling scenarios", never in
##   zones 1-2): a return pad partway along a ceiling that drops the rider into a stretch of floor walled off by
##   doodads, from Casino 1; a ceiling whose first pad lifts the rider into rows of fences and whose later pad
##   lands them past them, from Casino 2 (no patterns: their rules, treasure_stash_rules.gd and
##   fenced_ceiling_rules.gd, turn up to treasure_stashes and fenced_ceilings of the level's ceilings into them)
## - wall_run_gaps: wall-run gaps (task J2; the owner, October 15, 2026, docs/USER_REQUESTS.md), a hole over
##   every floor lane crossed by a wall run on its lit side wall, from Marketplace 1 (halfway in) on, never in
##   zone 1 or a boss arena (no patterns: their rules, wall_run_gaps_rules.gd, place them, WallRunGapPlacement;
##   tuning in data/tuning/wall_run_gaps.tres)
## - debris_maze: the Terminal's debris maze (task O2; GDD §5, Zone 8, owner, October 20, 2026), from Terminal 1:
##   stretches of the track where doodads stand so thickly that the open floor between them is a maze the runner
##   breaks through with the dash (no patterns: its rules, debris_maze_rules.gd, build it, DebrisMaze; numbers in
##   debris_maze_tuning). Its doodads stop the runner where the level says so (doodads_stop).
## - centipede: the Cybernetic Centipede (task O3; GDD §9.15), the Terminal's only enemy, from Terminal 1: it waits in
##   the debris maze's open cells and chases the runner along its open paths (no patterns: its rules,
##   centipede_rules.gd, place it where the maze stays escapable, CentipedeEscape; it needs the debris_maze feature)
## - gantryway: the Ice Lab's falling gantryways (task Q3; GDD §5, Zone 9, owner, October 21, 2026), from Frost Foundry:
##   one-lane walkways hanging over an inner lane, each held by a pillar in that lane that pushes like a doodad, which
##   the dash knocks down: the walkway falls on the lane over about a second, crushing the enemies under it and hitting
##   a runner still under it (no patterns: its rules, gantryway_rules.gd, place up to `gantryways` of them where a
##   runner who dashes the pillar always has a lane to step into; numbers in data/tuning/gantryways.tres)
## - teleporter: the Ice Lab's teleporters (task Q4; GDD §5, Zone 9, owner, October 21, 2026), from Relay Station: a square
##   pad in an inner lane with a green antenna, which sends a runner who runs onto it to an output pad further down the
##   track, one or a left and a right one, the antenna's light (fixed) choosing (no patterns: its rules,
##   teleporter_rules.gd, stand up to `teleporters` of them where the way around and every landing are fair; numbers in
##   data/tuning/teleporters.tres)
## - teleporter_blinking: blinking antennas (task Q4; GDD §5), from Specimen Vault, with `teleporter`: `blinking_teleporters`
##   of the level's teleporters have two output pads and a light that changes side about once a second, the side lit at
##   the touch deciding (no rules of its own but teleporter_blinking_rules.gd's positions(): teleporter_rules.gd places
##   them)
## - octodog_jar: the Ice Lab's Octodog jars that break open (task Q5; GDD §5, Zone 9, owner, October 21, 2026: "sometimes
##   smashing an Octodog jar doodad releases its Octodog into the world"), from Frost Foundry: a small zone doodad holding
##   an Octodog (LevelLayout.HOLDS), dressed as the zone's jar with one curled up inside; breaking it (the dash, or a wall
##   runner by its side wall) lets the dog out, and it runs ahead and attacks like any Octodog, its charges planned from
##   there (no patterns: its rules, octodog_jar_rules.gd, stand up to `octodog_jars` of them where the release and every
##   charge are fair, taking plain content out of the way where that's the only room; the dog's numbers in
##   data/enemies/octodog.tres, Jars). The zone's other Octodog jars are its skin's look only and hold nothing
##   (IceLabDoodads).
## - the planned ones in PLANNED_FEATURES
## Rules scripts run in this list's order (see LevelGenerator), so the campaign keeps the order in
## which the schedule introduces features.
@export var features: PackedStringArray = PackedStringArray(["ramps", "ceilings", "pulsing"])
## The `wall_gaps` feature's numbers for this config (WallGapPlacement.tuning_for): null for every
## level's, data/tuning/wall_gaps.tres, and the level is built exactly as before. A boss arena gets wall gaps
## only with numbers of its own here (and the feature listed): the opt-in (BossArena.base_config keeps the
## feature only then). The Sleep Taker's arena opts in (owner, October 8, 2026: "the walls aren't safe": many
## gaps). A level may take its own too (task D10b; the owner, October 9, 2026, on the Beach: "I want this zone to
## feel more open ... have them appear about 50% of the time that they are now currently appearing"): the Beach's
## levels take data/tuning/beach_wall_gaps.tres, whose open walls stand about half of each wall's length, and the
## Terminal's data/tuning/terminal_wall_gaps.tres, whose walls are a row of narrow arches with open space between them
## (task O1; GDD §5, Zone 8: WallGapTuning's Arches group).
@export var wall_gap_tuning: WallGapTuning
## Whether a runner can step onto the side walls and run along them (GDD §3, Side walls). Off: the walls are a boundary
## everywhere (task O1; the owner, October 20, 2026, GDD §3 and §5 Zone 8: "the Terminal has no wall running", its
## narrow arches and the tunnel wall behind them stand between the track and the rest of the subway): a move past the
## outer lane bumps the runner back with a blocked wall entry's clank and no damage, as a sign's does
## (Player.wall_running), the track builder draws the walls as standing sections with open space between them
## (TrackBuilder, ZoneSkin.wall_opening: without a wall gap's orange marks, which tell a wall runner the wall stops),
## the wall gap hint never shows, and nothing may need a wall run: the generator warns if the level's patterns or
## rules still put a ramp, a sign, a wall fence, a wall-run gap, a wall enemy or a wall credit there
## (LevelGenerator._check_walls_unused). The level's own rule (the Terminal's levels), never its skin's.
@export var wall_running: bool = true
## Features that start partway into the level (GDD §5: City 1 meets its cyborgs late in the level):
## feature name → share of the level (0–1). Nothing of that feature is placed before its start,
## by patterns or by rules scripts, and the first pattern picked from there uses it (as soon as one
## of its patterns fits), so the player meets it right after its first-encounter hint. Features not
## listed are there from the start.
## The campaign introduces each new feature this way (DESIGN-TBD: where in each level).
## (duplicate() shares this dictionary with the original: give a copy a new one, never edit it.)
@export var feature_starts: Dictionary[String, float] = {}
## Every feature appears at least once (GDD §5: anything introduced earlier keeps appearing
## later): each feature some pattern can place in the level is in the finished layout, whatever
## the seed. When a build misses one (chance never picked it, or a rule dropped it or cleared it
## away), the generator builds the level again with a pick of it forced elsewhere, and every rule
## still applies (LevelGenerator.GUARANTEE_SHARES). Campaign levels set it; endless mode turns it
## off on its copy (a 20-minute level brings every feature anyway), and quick play and tests that
## build their own levels leave it off, so they generate as before.
@export var guarantee_features: bool = false
## DESIGN-TBD: how often this level picks a feature's patterns, as a factor on their pick weight
## (feature name → factor; 1 when not listed, 0 leaves them out), e.g. Corporate 2's heavier
## military presence (GDD §5, proposed) and The Hush's hosts. A pattern requiring several listed
## features takes the product. It applies on top of the campaign's recency curve (feature_recency):
## the curve moves picks between the level's features, and these factors still scale them.
@export var feature_weights: Dictionary[String, float] = {}
## Levels since the campaign introduced each of this level's features (feature name → 0 in the
## level that introduces it, 1 in the next level, ...). Campaign.configure fills it in, with
## feature_recency, on its copy of a campaign level; level files, quick play, tests and boss arenas
## leave both empty, so their levels generate as before.
@export_storage var feature_ages: Dictionary[String, int] = {}
## The campaign's recency curve (GDD §5, owner's review P2 13: beyond the guarantee, a level's newest
## things get the most picks): with feature_ages, it scales each feature's pick weight by how
## recently the campaign introduced it (LevelGenerator, FeatureRecency). Null: every feature on equal
## terms (plus feature_weights).
@export_storage var feature_recency: FeatureRecency
## The core pattern file. Every other .json file in its folder is loaded too (LevelGenerator.load_for). A level with
## a set of its own names a file in another folder, and picks only that folder's patterns: the Terminal's
## (data/patterns/terminal/, task O1; GDD §5, Zone 8: none of the usual enemies, a couple of holes, a few one-lane
## ceilings), which never get the core patterns' holes, fences, signs and enemies.
@export_file("*.json") var patterns_path: String = "res://data/patterns/prototype_patterns.json"
## The zone's visuals. Gameplay never depends on it. Loaded from skin_path the first time it's read, unless set.
@export var skin: ZoneSkin:
	get:
		if _skin == null and skin_path != "":
			_skin = load(skin_path) as ZoneSkin
		return _skin
	set(value):
		# Setting it replaces the path too (null: no skin of its own), as a plain property would.
		_skin = value
		skin_path = value.resource_path if value != null else ""
## Where the level's own skin is, loaded on first use (ZoneDef.skin_path says why the data names a skin by its path).
@export_file("*.tres") var skin_path: String = ""
var _skin: ZoneSkin
## How much darker than its zone's normal light the level's scenery is (GDD §5: The Hush's darker
## lighting): 0 = the zone's own light, 1 = the darkest the skin allows (never pitch black,
## ZoneSkin.MIN_SCENERY_LIGHT). Only the scenery darkens: the sky, the distance fog and the skin's lit
## surfaces; hazards, triggers, enemies, the player, credits and the HUD keep their glow and their
## light (ZoneSkin.apply_darkness). DESIGN-TBD: The Hush's value.
@export_range(0.0, 1.0, 0.05) var darkness: float = 0.0
## The level's own sky over its zone's (owner, October 8, 2026: a few levels show the time of day or the
## weather turning; GDD §5, "Skies show progression"): the sky, the distance fog and the street's light
## under it change (LevelSky, ZoneSkin.level_environment); the boss fight after the level keeps it
## (Campaign.configure_boss), and so does its boss's intro (CineStage.sky_for). The owner asked for the
## Marketplace's sunset on its third level; the zone has two, so Marketplace 2 has it (confirmed October
## 9, 2026). Null: the zone's own sky. Gameplay never depends on it.
@export var sky: LevelSky

@export_group("Pacing")
## Empty run-up before the first pattern.
@export_range(0.0, 200.0, 1.0, "suffix:m") var start_clear_distance: float = 60.0
## Clear track kept before the finish line.
@export_range(0.0, 200.0, 1.0, "suffix:m") var end_clear_distance: float = 40.0
## Seconds of clear track between patterns at difficulty 0 and 1. DESIGN-TBD (docs/questions/g1.md):
## campaign levels set their own, closer than these defaults, for busier levels (GDD §3, owner's
## playtest September 30, 2026); the hard spacing stays the fairness floor (a switch across every lane
## between two patterns, at 6 lanes).
@export_range(0.2, 4.0, 0.05, "suffix:s") var spacing_seconds_easy: float = 1.8
@export_range(0.2, 4.0, 0.05, "suffix:s") var spacing_seconds_hard: float = 0.9
## Busier levels (GDD §3, owner's playtest September 30, 2026: "more gaps, obstacles and enemies ... so
## there is always something going on"): after the patterns and the rules, every stretch where nothing
## is going on or kept (LevelGenerator.fill_keep_outs) longer than this many seconds at run speed gets
## more of the level's plain obstacle patterns (holes and fences), spaced like the pattern pass places
## them (LevelGenerator._fill_empty_stretches): more patterns, never harder ones. 0 turns it off: the
## level is built exactly as before (quick play, the tests, boss arenas). DESIGN-TBD
## (docs/questions/g1.md): each campaign level's value.
@export_range(0.0, 10.0, 0.1, "suffix:s") var fill_empty_seconds: float = 0.0
## Additive floor-gap pass, after all obstacles: increases encounter count and mean missing lanes
## against this build's original gaps. Both targets round up; fairness can limit either. Zero keeps
## the original layout and random streams. City 1 alone enables these (approved USER_REQUESTS).
@export_range(0.0, 1.0, 0.05) var gap_encounter_increase: float = 0.0
@export_range(0.0, 1.0, 0.05) var gap_lane_increase: float = 0.0
## Danger density (owner's request, docs/USER_REQUESTS.md: "the algorithm that is used to make sure
## that there is always a free open lane is too forgiving"; about 15% more enemies and obstacles in the
## first levels, about 35% in the final ones): the danger density pass (scripts/world/danger_density.gd)
## adds this share more enemies (twins and single encounters of the level's own patterns, before the
## fill pass) and more floor pieces (rows take another lane, new filler rows, after it) to what the
## build places, where it's fair: an open lane and the level's spacing around everything it adds.
## 0 turns it off: the level is built exactly as before (quick play, the tests, boss arenas).
@export_range(0.0, 1.0, 0.01) var danger_density_increase: float = 0.0
## Wider gaps (owner, October 7, 2026, GDD §9.13 "Holes"; task G7): this many of the level's gap rows
## come out longer along the run (WideGapTuning.jump_fraction of a jump, data/tuning/wide_gaps.tres):
## still jumpable, too wide for an Enforcer Truck to hop, so one that follows the runner into one is
## wrecked. Uncommon: "a couple of times each level" (WideGapPlacement). 0 turns it off: the level is
## built exactly as before (quick play, the tests, boss arenas). DESIGN-TBD: 2 in every campaign level.
@export_range(0, 6) var wide_gaps: int = 0
## Extended wall runs (the owner, October 19, 2026, for The Hush: "three sections where the extended wall run is
## required ... double and triple wide sections"; WallRunGapPlacement): wall-run gaps, one per entry and in this order
## along the level, that take `runs` standard wall runs (2 or 3) to cross, with a small platform in the outer lane by
## the wall between two of their holes to land on and step back onto the wall from (a wall hop skips it). `walls`:
## "one" stands only the lit wall, on a seeded side, with its platforms on that side and the other wall open over the
## crossing, so the runner reads ahead which side to take; "both" stands both walls with platforms on both sides. They
## need the `wall_run_gaps` feature and come with the level's ordinary ones. Empty: none, and the level is built
## exactly as before. The Hush's three: a double with both walls, then a double and a triple with one wall each (items
## 1042-1049 in docs/OPEN_QUESTIONS*.md, approved as built).
@export var extended_wall_runs: Array[Dictionary] = []
## Features of its zone a level leaves out to make room for its own set pieces (the owner, October 20, 2026: The Hush
## may drop the heli drone, or the Enforcer Truck and the Buzz Overdrive, for its extended wall runs; it drops the
## drone, whose anti-grav pad every 8 to 10 s left them no room). Endless mode, which plays the zone rather than the
## level, puts them back (App.start_endless). Empty in every other level.
@export var features_left_out: PackedStringArray = []
## Cyborgs in charge paths (owner, October 7, 2026, GDD §9.13 "Teaching"; task G7): up to this many of the
## level's Octodog lunges and Buzz Overdrive charges get a plain cyborg standing in their path, so the
## player sees a charge flatten another enemy (ChargePathPlacement; numbers in data/tuning/charge_paths.tres).
## 0 turns it off: the level is built exactly as before. DESIGN-TBD: 1 in every campaign level with Octodogs
## or Buzz Overdrives (Gangland 2 on), so the player meets it several times before the Enforcer Truck.
@export_range(0, 4) var charge_path_cyborgs: int = 0
## Company for the Buzz Overdrive (the owner, October 17, 2026; task L2): with the `buzz_overdrive` feature, a tank
## no Enforcer Truck chases (bar the level's introduction of it) gets cyborgs and rows of holes or fences in its
## stretch, and wall fences may run by it, out of its lane and of the lane its runner escapes into
## (BuzzCompanyPlacement; numbers in data/tuning/buzz_company.tres). Off: the level is built exactly as before (quick
## play, the tests, boss arenas). On in every campaign level with the Buzz Overdrive.
@export var buzz_company: bool = false
## Dash walls (owner, October 8, 2026, GDD §9.14; task H7a): with the `dash_wall` feature, the generator
## stands up to this many buildings across the level's floor lanes for the runner to dash through
## (dash_wall_rules.gd), spread through the level where they're fair, spaced so the dash's longest cooldown
## is over before the next (data/tuning/dash_walls.tres); fewer where the level leaves no room, never none.
## 0 turns them off. Without the feature it does nothing. DESIGN-TBD (docs/OPEN_QUESTIONS.md item 644): 1 to 4 by level
## (2 in Corporate 1, up to 3 in Golden 2; a level asks for no more than its track holds on every lane count:
## Corporate 2, The Hush and Golden 1 hold one, Golden 1 since the walls keep off an Enforcer Truck's showing windows,
## task C6c, and Dead Zone 1 two since its ceiling scenarios came, task I4: at 3 lanes its fenced ceiling's build
## leaves room for no third); quick play's prototype level takes this default.
@export_range(0, 8) var dash_walls: int = 3
## Falling gantryways (task Q3; GDD §5, Zone 9, the owner, October 21, 2026): with the `gantryway` feature, the
## generator hangs up to this many one-lane walkways over the level's inner lanes, each held by a pillar the dash knocks
## down (gantryway_rules.gd), spread through the level where they're fair (data/tuning/gantryways.tres); fewer where the
## level leaves no room, never none. 0 turns them off. Without the feature it does nothing. DESIGN-TBD
## (docs/questions/q3.md 1 and 14): 3 in each of the Ice Lab's levels; quick play's prototype level takes this default,
## endless mode its level's (3 over its 20 minutes from the Ice Lab) and a weekly challenge's week Sentinel Row's.
@export_range(0, 8) var gantryways: int = 3
## Teleporters (task Q4; GDD §5, Zone 9, the owner, October 21, 2026: "introduced in level 2, with blinking antennas
## added in level 3"): with the `teleporter` feature, the generator stands up to this many teleporters' pads in the
## level's inner lanes, each leading to one output pad or a left and a right one further down the track
## (teleporter_rules.gd), spread through the level where they're fair (data/tuning/teleporters.tres); fewer where the
## level leaves no room, never none. 0 turns them off. Without the feature it does nothing. DESIGN-TBD
## (docs/questions/q4.md 1 and 14): 3 in Relay Station, 4 in Specimen Vault; quick play's prototype level takes this
## default, endless mode its level's (Specimen Vault's 4 over its 20 minutes from the Ice Lab) and a weekly challenge's
## week Sentinel Row's.
@export_range(0, 8) var teleporters: int = 3
## With the `teleporter_blinking` feature as well (Specimen Vault, GDD §5: "level 3 adds blinking ones"), this many of
## the level's teleporters have a blinking antenna: two output pads, the light changing side about once a second, the
## side lit at the touch deciding where the runner lands (the rest keep a fixed light). Without the feature it does
## nothing. DESIGN-TBD (docs/questions/q4.md 1): 2 of Specimen Vault's 4.
@export_range(0, 8) var blinking_teleporters: int = 1
## Octodog jars that break open (task Q5; GDD §5, Zone 9, the owner, October 21, 2026: "some jars hold a curled-up
## Octodog ... sometimes smashing an Octodog jar doodad releases its Octodog into the world, and the runner has to fight
## it"): with the `octodog_jar` feature, the generator stands up to this many jars holding an Octodog
## (octodog_jar_rules.gd), each where its push is a doodad's and the dog it lets out has room for its usual attack (its
## run and every charge clear, plain content taken out of its way where that's the only room); fewer where the level
## leaves no room, never none. The rest of a zone's Octodog jars are its skin's look and hold nothing (GDD §5, proposed:
## "a jar that will release its Octodog looks the same as one that won't"). 0 turns them off. Without the feature it does
## nothing. DESIGN-TBD (docs/questions/q5.md 1): 1 in each of the Ice Lab's levels (a heli drone's pad schedule leaves a
## freed dog's attack room before its first pad only); quick play's prototype level takes this default, endless mode its
## level's and a weekly challenge's week Sentinel Row's.
@export_range(0, 8) var octodog_jars: int = 1
## Ceiling scenarios (task I4; GDD §3, "Ceiling scenarios", owner, October 14, 2026: "sprinkle them in during
## later zones"): with the `treasure_stash` feature, the generator turns up to this many of the level's ceilings
## into a treasure stash's (treasure_stash_rules.gd), where one fits (an inner lane with inner lanes beside it:
## none on fewer than 5 lanes). DESIGN-TBD (items 836–845 (docs/OPEN_QUESTIONS*.md)): 1 a level from Casino 1.
@export_range(0, 4) var treasure_stashes: int = 1
## With the `fenced_ceiling` feature, up to this many ceilings carry fences that catch the rider of their first
## pads, with a later pad that lands its rider past them (fenced_ceiling_rules.gd). DESIGN-TBD
## (items 836–845 (docs/OPEN_QUESTIONS*.md)): 1 a level from Casino 2.
@export_range(0, 4) var fenced_ceilings: int = 1
## How many anti-grav pads a fenced ceiling has: 2 is the simple first version (one pad into the fences, one past
## them); more is the later version (GDD §3: "several pads, some leading to safe parts of the ceiling and some to
## dangerous parts"), half of them (rounded up) before the fences, in different lanes; never as many as the lanes
## (fenced_ceiling_rules.gd pad_count: on 3 lanes, 2). DESIGN-TBD (items 836–845 (docs/OPEN_QUESTIONS*.md)): 3 from Corporate 1.
@export_range(2, 6) var fenced_ceiling_pads: int = 2
## Quiet stretches and bursts (GDD §5, The Hush: long silent stretches broken by sudden threats).
## With quiet_seconds above 0, the level after its run-up alternates a quiet stretch of that many
## seconds at run speed with a burst of burst_seconds, quiet first. In a quiet stretch patterns are
## quiet_spacing_seconds apart, and one that places enemies is picked only if every feature it
## requires is in quiet_features (so it stays sparse obstacles, safe mechanics such as plain
## ceilings, and those enemies); a burst picks the level's other threats (patterns with a hole, a
## fence, a sign or an enemy, whose enemies stand in the burst), burst_spacing_seconds apart. The
## generator's rules still apply afterwards to all of it, and a burst takes at most one feature's
## introduction (feature_starts).
## 0 turns it off: the level is paced evenly (spacing_seconds_easy/hard), as every other level is.
## DESIGN-TBD: The Hush's numbers.
@export_range(0.0, 60.0, 0.5, "suffix:s") var quiet_seconds: float = 0.0
@export_range(1.0, 30.0, 0.5, "suffix:s") var burst_seconds: float = 8.0
@export_range(0.2, 10.0, 0.05, "suffix:s") var quiet_spacing_seconds: float = 4.0
@export_range(0.2, 4.0, 0.05, "suffix:s") var burst_spacing_seconds: float = 0.9
## Features whose enemy patterns belong to the quiet stretches: picked there, with their enemies
## inside the stretch, and not in bursts (The Hush: its hosts, standing alone in the silence; a chase
## starts only if the player kills one).
@export var quiet_features: PackedStringArray = PackedStringArray()

@export_group("Fairness rules")
## Longest gap the generator will place, as a fraction of a full jump's distance.
@export_range(0.3, 1.0, 0.05) var max_gap_jump_fraction: float = 0.8
## A ceiling section starts this far before its anti-grav pad so there is always a hull above.
@export_range(0.0, 10.0, 0.5, "suffix:m") var hull_lead_in: float = 3.0
## DESIGN-TBD: seconds of gap-free floor after a ceiling section ends, so the drop never lands in a hole.
@export_range(0.0, 3.0, 0.1, "suffix:s") var hull_landing_seconds: float = 1.2

@export_group("Floor cuts")
## GDD §9.9 (the Buzz Overdrive's cuts, task B4): "on 3 lanes, two lanes always stay whole": along a
## cut's stretch no other lane holds a hole. On more lanes, at most this many lanes besides the cut's
## own may hold holes there (LevelGenerator.whole_lanes_for_cut: 3 of 5 lanes and 4 of 6 stay whole
## with 1). DESIGN-TBD (docs/questions/b4.md): the limit at 5 and 6 lanes.
@export_range(0, 4) var cut_holes_beside: int = 1
## A player in a cut's lane when its warning starts can always leave it: from this long after the
## warning starts, a neighbouring lane has room to switch into before the cut meets the player
## (LevelGenerator.cut_escape_clear). DESIGN-TBD (docs/questions/b4.md).
@export_range(0.0, 2.0, 0.05, "suffix:s") var cut_reaction_seconds: float = 0.5

@export_group("Narrow ceilings")
## GDD §3 (decided September 26, 2026): ceilings don't have to cover every lane, and on one the player
## switches lanes only within its lanes. The share of this level's ceilings that cover a range of its
## lanes rather than all of them: pattern ceilings and those the rules add (a drone's pads, a Bad
## Dream chase's) alike (LevelGenerator.ceiling_lanes). 0: every ceiling covers every lane, and the
## level generates exactly as it did before narrow ceilings. DESIGN-TBD (docs/questions/b3.md): how
## often, and where they first appear.
@export_range(0.0, 1.0, 0.05) var narrow_ceiling_share: float = 0.0
## Share of the level (0–1) from which ceilings may be narrow; every ceiling before it covers every
## lane (City 2 shows its first ceilings full width). DESIGN-TBD (docs/questions/b3.md).
@export_range(0.0, 1.0, 0.05) var narrow_ceiling_start: float = 0.0
## Of the narrow ceilings, the share that cover a single lane; the others cover from two lanes to
## narrow_ceiling_max_lanes, each width as likely. A one-lane ceiling is simply ridden out (GDD §3),
## so it's very short (one_lane_ceiling_seconds) and only where its pattern puts nothing under it.
## DESIGN-TBD (docs/questions/b3.md).
@export_range(0.0, 1.0, 0.05) var one_lane_ceiling_share: float = 0.35
## The most lanes a narrow ceiling covers; 0 (or anything from the lane count less one up): all but one
## lane. A narrow ceiling whose pads lie further apart than this covers every lane instead.
## DESIGN-TBD (docs/questions/b3.md).
@export_range(0, 6, 1) var narrow_ceiling_max_lanes: int = 0
## How long a one-lane ceiling lasts from its pad to its end, at run speed (GDD §3: very short; a plain
## ceiling lasts 4 s). DESIGN-TBD (docs/questions/b3.md).
@export_range(0.5, 4.0, 0.1, "suffix:s") var one_lane_ceiling_seconds: float = 1.6

@export_group("Doodads")
## Zone doodads (GDD §3, owner's playtest September 30, 2026: "levels felt barren"): scenery pieces
## standing in lanes that never hurt; running into one pushes the player into a neighbouring lane.
## They take a lane rather than needing a reaction, so they make a level look busier without
## tightening its reaction windows. The generator puts them where they're fair lane by lane (task L6,
## the owner's playtest, October 17, 2026: "too rare"; LevelGenerator: doodads), a spot every
## doodad_spot_seconds along the level: this is the chance that each spot with room for one gets one.
## 0: none, and the level is built exactly as before (quick play, the tests, boss arenas).
## DESIGN-TBD (docs/questions/g5.md, items 969-976 in docs/OPEN_QUESTIONS*.md): each level's value.
@export_range(0.0, 1.0, 0.05) var doodad_share: float = 0.0
## How far apart the spots lie that may each get a zone doodad (or a row), at run speed (task L6): with
## doodad_share, how often doodads come where the level has room for them, the doodad's front at a seeded
## place in its spot. DESIGN-TBD (item 970 in docs/OPEN_QUESTIONS*.md).
@export_range(0.5, 10.0, 0.1, "suffix:s") var doodad_spot_seconds: float = 1.0
## Share of the level (0–1) from which doodads stand (City 1 introduces them a little way in).
@export_range(0.0, 1.0, 0.05) var doodad_start: float = 0.0
## How often each size class is picked (LevelLayout.DOODAD_SIZES; MovementTuning has their sizes); 0
## leaves a class out (City 1 starts with the smaller ones).
@export_range(0.0, 1.0, 0.05) var doodad_small_weight: float = 1.0
@export_range(0.0, 1.0, 0.05) var doodad_medium_weight: float = 1.0
@export_range(0.0, 1.0, 0.05) var doodad_large_weight: float = 1.0
## The least time between one doodad's end and the next one's front, at run speed: the next one clears the
## last one's push (task L6; 2.5 s before it). Closer than the level's spacing between two patterns
## (LevelGenerator.doodad_after) the next one stands two lanes away at least, never in the lane beside the last
## one, where its push lands (no slalom), nor in its lane, which it hides behind it. A row of doodads
## (doodad_row_chance) counts as one: from its last one's end to the next doodad's front. DESIGN-TBD
## (item 971 in docs/OPEN_QUESTIONS*.md).
@export_range(0.2, 10.0, 0.1, "suffix:s") var doodad_gap_seconds: float = 0.6
## The reaction a runner gets after a zone doodad's push lands them in a lane beside it (task L6, and its review):
## both lanes beside it stay clear this long, at run speed, past where a push from its last front (a row's last
## one's) comes down: a push's time past that front on the floor, or a full jump past it for a runner who jumped at
## it, pushed in the air (LevelGenerator.doodad_landing). DESIGN-TBD (item 969 in docs/OPEN_QUESTIONS*.md).
@export_range(0.1, 2.0, 0.05, "suffix:s") var doodad_reaction_seconds: float = 0.5
## Doodads in rows (the owner, October 17, 2026, task L3: "occasionally ... rows of similar doodads: three plant
## doodads one right after the other, or three market stalls, one followed by a space ..."): the chance that a
## doodad is the first of a row, the rest of the same size class and look, in its lane, pushing to its side, all
## kept by the doodads' rules as one (LevelGenerator._place_doodads). A row that doesn't fit where it's drawn is
## shorter, down to doodad_row_min, else one doodad (so rows come where a level leaves long stretches free). 0: no
## rows, and the doodads are exactly as before. DESIGN-TBD (item 942 in docs/OPEN_QUESTIONS*.md).
@export_range(0.0, 1.0, 0.05) var doodad_row_chance: float = 0.5
## How many doodads a row has (each count as likely; the owner's examples are three long, and task L6, the owner,
## October 17, 2026: "could it be two in a row so it doesn't take up as much room?"). DESIGN-TBD (items 942 and
## 973 in docs/OPEN_QUESTIONS*.md).
@export_range(2, 4) var doodad_row_min: int = 2
@export_range(2, 4) var doodad_row_max: int = 4
## Of the rows of small doodads, the share with a doodad's length of space between each two; the others stand one
## right after the other (LevelGenerator.DOODAD_ROW_TOUCH, a sliver apart). The owner's examples by size class:
## "three plant doodads one right after the other" (small ones touch) and "three market stalls, one followed by a
## space, followed by another stall" (medium and large ones spaced). DESIGN-TBD (item 942 in docs/OPEN_QUESTIONS*.md).
@export_range(0.0, 1.0, 0.05) var doodad_row_spaced_small: float = 0.0
## The same for rows of medium doodads.
@export_range(0.0, 1.0, 0.05) var doodad_row_spaced_medium: float = 1.0
## The same for rows of large doodads.
@export_range(0.0, 1.0, 0.05) var doodad_row_spaced_large: float = 1.0
## Doodads prefer the lane by a side wall when it's open (the owner, October 9, 2026, held until task L3: "without
## costing gameplay: not where the generator already has something on that part of the wall or needs it open";
## LevelGenerator.wall_lane_keep_outs): the chance a doodad (or a row) that may stand in an outermost lane does,
## by an open wall (either, seeded, when both are). 0: inner lanes only, as before. DESIGN-TBD (items 942-947 in docs/OPEN_QUESTIONS*.md
## 3).
@export_range(0.0, 1.0, 0.05) var doodad_wall_lane_share: float = 0.6
## How much wall either side of a doodad by a side wall stays clear of what stands on that wall (a sign, a window
## cyborg's window, a wall vent, a Gilded Sentinel's niche, a ramp's longest wall run), at run speed.
## DESIGN-TBD (item 944 in docs/OPEN_QUESTIONS*.md).
@export_range(0.0, 3.0, 0.1, "suffix:s") var doodad_wall_clear_seconds: float = 1.0
## Zone doodads that stop the runner instead of pushing (task O2; the owner, October 20, 2026, GDD §3 and §5 Zone 8: in
## the Terminal "a doodad stops the runner here instead of pushing them aside (with doodads on both sides, a push would
## usually land in another one)"): running into one's front brings the runner to a complete stop facing it, with no
## damage; they set off again by switching into a lane open beside them or by dashing through it, and a stop costs only
## time (Player.doodads_stop, which RunWorld sets from LevelLayout.doodads_stop). Every doodad of the level stops, the
## debris maze's (debris_maze) and the scattered ones alike. The level's own rule (the Terminal's), never its skin's.
## Off: every doodad pushes, as before. DESIGN-TBD (docs/questions/o2.md, question 13): whether the scattered ones in the
## normal track between the maze's blocks should stop the runner too, or push as elsewhere.
@export var doodads_stop: bool = false
## How tall this level's zone doodads stand (task O2; GDD §5 Zone 8: the Terminal's are "lower than standard doodads, so
## the player can see the maze's open paths over them", (proposed) still too tall to jump, and they read so; the owner,
## October 20, 2026: lower still, so the player can plan further ahead): 0 takes the movement tuning's
## (MovementTuning.doodad_height). It reaches the generator, the track, the runner and the camera through movement_for(),
## and the zone's doodad pictures are painted to it (DoodadArtSet.zone_tuning). Keep it above a jump's reach: the feet
## peak at MovementTuning.jump_height (1.6 m) in theory and about 1.53 m on the game's 60 Hz physics, and a doodad stops a
## body whose feet are less than Player.DOODAD_FEET_CLEARANCE below its top. The Terminal's 1.7 m is the lowest with a
## margin over both (test_debris_maze runs jumps at it). DESIGN-TBD (docs/questions/o2.md).
@export_range(0.0, 3.0, 0.05, "suffix:m") var doodad_height: float = 0.0
## The `debris_maze` feature's numbers (task O2; DebrisMaze): null takes data/tuning/debris_maze.tres. The Terminal's
## levels take their own: Rubble Line's maze over most of the level (data/tuning/terminal_maze_1.tres), Last Stop's
## stretches of maze (terminal_maze_2.tres). Without the feature it does nothing.
@export var debris_maze_tuning: DebrisMazeTuning

@export_group("Credits")
## Credit placement (GDD §7; FB 9): trails of small credits fill the clear stretches between
## patterns; high-value credits sit in risky spots (gap edges, by fences, far along wall runs).
@export_range(1.0, 10.0, 0.25, "suffix:m") var credit_trail_spacing: float = 3.0
@export_range(0, 20) var credit_trail_count: int = 6
## A clear stretch too short for a full trail gets a shorter one, down to this many credits (0: only
## full trails, as before). Busier levels leave fewer long clear stretches (GDD §3, owner's playtest
## September 30, 2026), so campaign levels take shorter trails to keep their credits about where they
## were (the economy is task R7's). DESIGN-TBD (docs/questions/g1.md).
@export_range(0, 20) var credit_trail_min: int = 0
## Chance that a clear stretch gets a trail.
@export_range(0.0, 1.0, 0.05) var credit_trail_chance: float = 0.8
## Chance that a gap gets an arc of credits over it and a richer credit right at its edge.
@export_range(0.0, 1.0, 0.05) var credit_gap_chance: float = 0.6
## Chance that a fence gets a richer credit in its risky spot (over a full fence, under a gapped one).
@export_range(0.0, 1.0, 0.05) var credit_fence_chance: float = 0.5
## Credits along the wall run after a ramp and along the ceiling after an anti-grav pad.
@export var credit_wall_runs: bool = true
@export var credit_ceilings: bool = true
## Wall-hop credits (task N1; GDD §7, "Wall-hop credits", owner, October 9, 2026: a gentle nudge toward the wall hop,
## GDD §3): up to this many lines a level of credits along a long, clear stretch of a side wall with no wall gap,
## whose high-value ones lie further along than one wall run reaches and higher than a step onto the wall from the
## floor carries a pickup, so a runner who wall hops collects them; so does one who jumps onto the wall from the floor
## at the right spot, and the magnet leaves them alone (WallHopPlacement; numbers in data/tuning/wall_hops.tres).
## Sprinkled where one fits, never guaranteed. 0: none, and the level is built exactly as before (the City's levels,
## quick play, the tests' own levels). DESIGN-TBD (items 1017-1024): 1 a level from Gangland 1 on.
@export_range(0, 4) var wall_hop_lines: int = 0


func has_feature(feature: String) -> bool:
	return features.has(feature)


## True if the level plays a mini-game (minigame) rather than a generated layout.
func plays_minigame() -> bool:
	return minigame != null


## The movement tuning this level runs on: `base` itself unless the level has a run speed of its own
## (run_speed above 0, and not base's already) or a doodad height of its own (doodad_height above 0, and not base's
## already: the Terminal's lower debris, task O2), else a copy of `base` with them. The generator, RunWorld and App all
## ask this, so a level is built and played at the same speed, with doodads of the same size.
func movement_for(base: MovementTuning) -> MovementTuning:
	if base == null:
		return base
	var own_speed: bool = run_speed > 0.0 and not is_equal_approx(base.run_speed, run_speed)
	var own_height: bool = doodad_height > 0.0 and not is_equal_approx(base.doodad_height, doodad_height)
	if not own_speed and not own_height:
		return base
	var out: MovementTuning = base.duplicate() as MovementTuning
	if own_speed:
		out.run_speed = run_speed
	if own_height:
		out.doodad_height = doodad_height
	return out


## Share of the level (0–1) where `feature` starts: 0 unless feature_starts lists it.
func feature_start(feature: String) -> float:
	return clampf(float(feature_starts.get(feature, 0.0)), 0.0, 1.0)


## Factor on the pick weight of `feature`'s patterns: 1 unless feature_weights lists it.
func feature_weight(feature: String) -> float:
	return maxf(float(feature_weights.get(feature, 1.0)), 0.0)


## The share of the rows of doodads of size class `size` (LevelLayout.DOODAD_SIZES) with a doodad's length between
## each two (task L3): doodad_row_spaced_small, doodad_row_spaced_medium or doodad_row_spaced_large.
func doodad_row_spaced(size: StringName) -> float:
	match size:
		&"small":
			return doodad_row_spaced_small
		&"medium":
			return doodad_row_spaced_medium
	return doodad_row_spaced_large


## True if the campaign's recency curve shapes this level's pick weights (feature_recency, switched
## on, and the ages Campaign.configure gave the level's features).
func recency_on() -> bool:
	return feature_recency != null and feature_recency.enabled and not feature_ages.is_empty()


## The recency curve's factor for a pattern that requires `requires` (LevelGenerator): its newest
## feature's (the smallest age, so a pattern that shows off a new feature counts as one of its
## picks), no more than the cap of any capped feature it requires (FeatureRecency.max_factor); 1
## for a pattern that requires nothing, without the curve, or when no feature is dated.
func recency_factor(requires: Array) -> float:
	if not recency_on() or requires.is_empty():
		return 1.0
	var newest: int = -1
	var cap: float = INF
	for need: Variant in requires:
		var feature: String = String(need)
		var age: int = int(feature_ages.get(feature, -1))
		if age >= 0 and (newest < 0 or age < newest):
			newest = age
		if feature_recency.max_factor.has(feature):
			cap = minf(cap, float(feature_recency.max_factor[feature]))
	return minf(feature_recency.factor(newest), cap)


## True if the recency curve holds a pattern that requires `requires` at a capped factor (it
## requires a feature FeatureRecency.max_factor lists): the curve never scales it back with the rest.
func recency_capped(requires: Array) -> bool:
	if not recency_on():
		return false
	for need: Variant in requires:
		if feature_recency.max_factor.has(String(need)):
			return true
	return false


## True if the level alternates quiet stretches and bursts (quiet_seconds above 0).
func paced_in_bursts() -> bool:
	return quiet_seconds > 0.0
