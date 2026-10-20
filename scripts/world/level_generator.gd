class_name LevelGenerator
extends RefCounted
## Rule-based level generator: data-driven patterns + a difficulty value + a seed.
## Works for any lane count. Never refers to zone skins (trucks, streets, ...).
## Pattern format is documented in data/patterns/README.md.
##
## Passes, each with its own random stream so adding one never reshuffles the others:
## 1. Patterns (obstacles and enemies) from the pattern files, filtered by the level's features.
##    A feature that starts partway into the level (LevelConfig.feature_starts) is left out before
##    its start, and the first pattern picked from there uses it (its introduction).
## 2. Enemy rules: for every feature with a script at res://scripts/enemies/<feature>_rules.gd,
##    its static `apply(gen: LevelGenerator)` runs (e.g. drone anti-grav pad schedules). Rules that
##    add a feature's enemies or pieces keep them after its start (feature_active, feature_share_at).
##    Last of them, a dash wall's introduction (the `dash_wall` feature, task H7a; dash_wall_rules.gd: a
##    building across every floor lane the runner dashes through) where the level gives the feature a start,
##    which every pass after the rules keeps off (fill_keep_outs, doodad_keep_outs, the rules' keep-outs). The
##    walls in turn keep off the rules' calm stretches (an Enforcer Truck's showing windows, task C6c). And
##    after them the wall-run gaps (the `wall_run_gaps` feature, from Marketplace 1; task J2, the owner, October
##    15, 2026; wall_run_gaps_rules.gd, WallRunGapPlacement): a stretch where every floor lane is a hole too long
##    to jump, one side wall lit as the way across, where nothing the rules planned is in the way (plain pieces of
##    the patterns and a few small enemies go), its clear run-in and landing floor kept by every pass after the
##    rules as a dash wall's footprint is, its lit wall by the wall fences and the side wall gaps.
## 3. The fill pass (LevelConfig.fill_empty_seconds): more plain obstacle patterns in long empty
##    stretches. Around it, danger density (LevelConfig.danger_density_increase; DangerDensity,
##    scripts/world/danger_density.gd): before it a share more enemies (twins and single encounters
##    of the level's own patterns), after it a share more floor pieces (rows take another lane, new
##    filler rows), each with an open lane and the level's spacing around it. Off (0) it draws nothing.
##    Between the danger density pass's enemy half and the fill pass: cyborgs in charge paths
##    (LevelConfig.charge_path_cyborgs; ChargePathPlacement, task G7): a plain cyborg planted in the path of
##    an Octodog's lunge or a Buzz Overdrive's charge now and then, so the player sees a charge flatten it.
##    Then, before the fill pass: wider gaps (LevelConfig.wide_gaps; WideGapPlacement, task G7): a couple of
##    the level's rows longer along the run (or new rows where too few fit), too wide for an Enforcer Truck
##    to hop; the fill pass and the danger density pass then keep their spacing from them.
##    After the danger density pass's floor pieces: company for the Buzz Overdrives (LevelConfig.buzz_company;
##    BuzzCompanyPlacement, task L2): a tank no Enforcer Truck chases (bar the level's introduction of it) gets
##    cyborgs and rows of holes or fences in its stretch, which every pass before it keeps clear, out of its own
##    lane and, over its attack, out of the neighbouring lane its runner escapes into; the passes after it keep
##    off them as off anything.
## 4. Zone doodads (LevelConfig.doodad_share): scenery standing in lanes, where they're fair lane by lane
##    (_place_doodads; task L6). After them, the rules' `static func after_doodads(gen:
##    LevelGenerator)` (_after_doodad_rules): the rest of the level's dash walls, in the room the passes
##    before them left, so those passes measure and fill the level as they would without them.
## 5. Wall fences (the `wall_fences` and `wall_fences_partial` features; WallFencePlacement): electric
##    fences across the wall-run path, only where they're fair (_place_wall_fences).
## 6. Side wall gaps (the `wall_gaps` feature, Zone 2 on; WallGapPlacement): stretches of a side wall
##    with no wall-running surface, rare, clear of every wall piece, ramp run and ceiling on that wall. In the
##    Terminal (task O1, its own WallGapTuning's Arches group) the open space between its narrow arches instead, with a
##    broken stump where one side's arch is missing.
## 7. Additive gaps (GapDensity, enabled only in City 1): more rows and a higher mean row width,
##    without replacing obstacles. Independent round-up targets and explicit fairness shortfalls.
## 8. Credits (GDD §7): trails in the clear stretches, rich credits in risky spots (none on a wall
##    where a wall gap leaves no wall), and from Gangland 1 on a line of wall-hop credits a level
##    (LevelConfig.wall_hop_lines; WallHopPlacement, task N1): along a long, clear stretch of a side wall,
##    its high-value ones further along than one wall run reaches, for a runner who wall hops.
## Fairness rules (longest gap, hull lead-in and landing) come from LevelConfig, so they are data.
## A level whose walls are a boundary (LevelConfig.wall_running off: the Terminal, task O1) has its layout say so
## (LevelLayout.wall_running), and a build that put anything on a wall there warns (_check_walls_unused).
##
## Ceilings (GDD §3, changed September 26, 2026): the floor under a ceiling may be dangerous, since the
## ceiling is the way to escape it: a pattern may put gaps, fences and enemies under its own ceiling
## (a gauntlet), and a ceiling a rule adds (add_hull_with_pad, PadPlacement) lies over whatever the
## floor holds there. Two stretches stay safe around every ceiling (CeilingZones, `zones`): its
## landing zone, and the spot of each of its pads. The ceiling is never required: the floor under it
## holds only what patterns put there, with their usual fairness and spacing, and the pad can always
## be passed by.
##
## Narrow ceilings (GDD §3, decided September 26, 2026: ceilings don't have to cover every lane): a
## ceiling covers a contiguous range of lanes (LevelLayout.hull_lanes), with its pads inside it and its
## landing zone over its lanes. A level's narrow_ceiling_share of its ceilings (LevelConfig, from
## narrow_ceiling_start on) cover fewer lanes than the track has, pattern ceilings and rules' alike
## (ceiling_lanes, from a random stream of its own, so full-width ceilings and everything else come out
## exactly as before); a one-lane ceiling is very short (one_lane_ceiling_seconds) and only where its
## pattern puts nothing under it.
##
## Every feature appears (LevelConfig.guarantee_features; GDD §5: anything introduced earlier keeps
## appearing later): after the passes, the generator checks that each feature a pattern can place
## in the level is in the finished layout (feature_positions). Rules may have dropped what didn't
## fit or cleared it for a guarantee of their own, so for each one missing it builds the level again
## with picks of that feature forced somewhere else (GUARANTEE_SHARES; more of them each time it's
## missed, GUARANTEE_MAX_PICKS), until none is missing. Each build runs every pass and rule
## unchanged, so the guarantee never bends a fairness rule. Rules that hold the room for their
## feature themselves may add one where it fits when none is left (the host and Octodog rules),
## which saves a build. A feature with no pattern of its own, placed by its rules only around other
## features' entries (the Enforcer Truck around Octodog and Buzz Overdrive charges: its rules'
## GUARANTEED_BY), counts too: a build without one forces picks of those features elsewhere, so their
## entries move until one leaves its rules room (dependent_features; task K4, which met a build whose
## only baits left a truck nowhere to arrive).
##
## Beyond that guarantee, a campaign level's newest things get the most picks (GDD §5, owner's review
## P2 13): with the campaign's recency curve (LevelConfig.feature_recency and feature_ages), each
## pattern's pick weight follows how recently the campaign introduced its newest feature, the curve
## only moves picks between the level's features of the same kind (FeatureRecency.keep_feature_share,
## keep_share_by_kind), and never boosts a feature whose rules would drop its extra enemies
## (FeatureRecency.max_factor): no level gets easier.
##
## A level may alternate long quiet stretches with short, dense bursts (LevelConfig.quiet_seconds;
## GDD §5, The Hush): quiet stretches pick sparse patterns without enemies (bar quiet_features), bursts
## pick threats, densely. Every rule, fairness check and the guarantee apply to it unchanged, and a
## burst takes at most one introduction, so it never stacks two new things.
##
## Pace and busier levels (GDD §3, owner's playtest September 30, 2026): a level runs at its own speed
## (LevelConfig.run_speed, its zone's in the campaign), and everything the patterns and rules measure
## in metres for MovementTuning.REFERENCE_SPEED is stretched by the level's pace (metres()), so every
## reaction window keeps its seconds. After the rules, a fill pass (LevelConfig.fill_empty_seconds)
## puts more of the level's plain obstacle patterns into its long empty stretches, off everything the
## rules and ceilings keep (fill_keep_outs), spaced like the pattern pass: busier, never tighter.
##
## Zone doodads (GDD §3, same playtest): scenery pieces standing in lanes that never hurt; running into
## one pushes the player into a neighbouring lane. After the fill pass, a level's doodad_share of the spots
## along it (LevelConfig.doodad_spot_seconds apart) get one where it's fair lane by lane (task L6: its own lane
## and the lanes beside it clear around it, nothing kept in every lane near it: doodad_keep_outs,
## doodad_lane_busy), in an inner lane or by a side wall that's open there (task L3: wall_lane_keep_outs), now
## and then the first of a row of its kind (task L3): they add to what the patterns, the rules and the fill pass
## put there (nothing moves or goes for them, and nothing comes after them to undo or crowd them), so a level
## looks busier without needing a reaction or narrowing one.
##
## Floor cuts (task B4; GDD §9.9, the Buzz Overdrive's): floors that turn into gaps during play are
## planned in advance as data (LevelLayout.cuts; FloorCutPlan: lane, start, end, and when it runs,
## keyed to the player's distance), so a level stays fair and the same on every attempt. A rules
## script plans them (add_cut; CutPlacement clears the way), only where GDD §9.9's limits allow
## (cut_problem): one at a time, never through a ramp, a pad or the safe landing zone after a ceiling,
## its lane free of everything else from its warning to past its cause, the other lanes whole enough
## (on 3 lanes two stay whole; LevelConfig.cut_holes_beside on more), nothing else going on meanwhile,
## and room to leave its lane after the warning (cut_escape_clear). Everything planned after a cut
## keeps off it: the fill pass and zone doodads (fill_keep_outs, doodad_keep_outs), floor_clear,
## ceilings added later (CeilingZones) and floor credits in its lane; only a Buzz Overdrive's company
## (task L2, BuzzCompanyPlacement) comes into its window, keeping all of the above, and wall fences run by a
## cut with company. A level without cuts is built exactly as before.
##
## Wall fences (task B5; GDD §9.1: electric fences that span a side wall and switch off and on, to make
## the walls less safe; full-height ones from Marketplace 2, partial ones over the low or the high part
## of the wall from the Corporate zone): after the doodads, from a random stream of their own, they're
## added to the walls only where they're fair (WallFencePlacement: never on a wall section with a sign
## or a window cyborg, never where a ramp launches the player along their wall, the outer lane beside
## them clear to drop off into, no floor cut or big attack meanwhile), so everything else in a level is
## built exactly as without them. A level that brings them in meets its first one soon after the
## feature's start, alone, with a long off time.
##
## Ceiling scenarios (task I4; GDD §3, "Ceiling scenarios", owner, October 14, 2026: never in zones 1-2): last of
## the rules, the `treasure_stash` and `fenced_ceiling` rules (CeilingScenarios) turn a few of the level's own
## ceilings into a treasure stash's (a return pad over a stretch of floor walled off by doodads, holding the
## highest-denomination credits) or a fenced one's (rows of fences after its first pads, a later pad past them),
## so every rule before them plans as it would without them; what they add keeps every ceiling's rules, and every
## pass after them keeps off a stash's floor (their rules' keep-outs). The credit pass keeps other credits out of a
## stash and off the fences (_drop_unsafe_credits).

const DENOMINATIONS: Array[int] = [1, 5, 25, 100]
## The danger density pass (LevelConfig.danger_density_increase); no class_name, so loaded here.
const DangerDensity := preload("res://scripts/world/danger_density.gd")
## The dash walls' rules (task H7a), whose footprints the fill pass and the doodads keep off.
const DashWallRules := preload("res://scripts/enemies/dash_wall_rules.gd")
## A hover truck's stay and a cyborg's margin, for what a pattern reaches (_pattern_reach).
const HoverTruckRules := preload("res://scripts/enemies/hover_truck_rules.gd")
const CyborgRules := preload("res://scripts/enemies/cyborg_rules.gd")
## Seconds of run the pattern pass moves on past a pattern it takes back for an extended wall run's stretch
## (extended_wall_run_reserve) before it picks again.
const EXTENDED_SKIP_SECONDS: float = 1.0
## Seconds of run past its own end a pattern may reach once an extended wall run's stretch is due (a cyborg's margin, a
## host's): the stretch waits that long for it rather than lose the pattern.
const EXTENDED_WAIT_SECONDS: float = 2.0
const RULES_DIR: String = "res://scripts/enemies"
## The most builds generate() makes to have every feature appear (guarantee_features). Past it the
## level keeps the build that missed the fewest, with a warning. Most levels take one to three; The
## Hush, whose bursts leave its many features little room, took up to 17 on a few seeds (task B3's
## sweeps: 16 left one seed at 3 lanes and one at 6 without a feature, with and without narrow
## ceilings), so there's room to spare. A level found within fewer builds is built exactly the same.
const GUARANTEE_ATTEMPTS: int = 24
## Where a new build forces a pick of a feature the last one missed: a share of the stretch where
## the feature is active (from its start to the level's end), a new one each time it's missed. The
## early shares come before most drone waves, whose pad schedule clears the floor after them; none
## is so late that a long pattern couldn't fit before the end.
const GUARANTEE_SHARES: Array[float] = [0.3, 0.0, 0.55, 0.12, 0.4, 0.05, 0.7, 0.2, 0.02, 0.48, 0.08,
	0.62, 0.25, 0.15, 0.35, 0.78]
## A feature missed again gets more forced picks in the next build (one per miss, up to this many),
## spread over its stretch, so one that rarely survives (a floor enemy where the drone's pads clear
## the floor) gets several chances in a build.
const GUARANTEE_MAX_PICKS: int = 3
## The fill pass keeps this much more than the level's spacing from everything already there, for a
## pattern's tail (the pattern pass spaces patterns from the end of the last one's `length`, which
## runs a little past its last piece).
const FILL_TAIL_SECONDS: float = 0.25
## Seconds before its spot an enemy counts as busy for the fill pass (fill_keep_outs), unless its
## rules script says otherwise (`keep_out`): it winds up, fires or springs out as the player closes in.
const FILL_ENEMY_LEAD_SECONDS: float = 2.0
## Under a ceiling the fill pass times its fillers as the gauntlet patterns time their pieces
## (data/patterns/README.md): from this long after the pad ...
const FILL_CEILING_AFTER_PAD_SECONDS: float = 1.0
## ... until this long before the ceiling's end (its landing zone follows).
const FILL_CEILING_BEFORE_END_SECONDS: float = 0.6
## A floor credit this close to a zone doodad in its lane (or inside it) is dropped (metres).
const DOODAD_CREDIT_MARGIN: float = 1.0
## The space between two doodads of a row standing one right after the other (task L3; metres): a sliver, so the
## box faces of the two never lie in one plane (their pictures would flicker through each other), far too
## narrow for a body (MovementTuning.visual_size.z, 0.52 m) to stand in. DESIGN-TBD (item 942 in docs/OPEN_QUESTIONS*.md).
const DOODAD_ROW_TOUCH: float = 0.05
## The room a zone doodad keeps in the lanes beside it (task L6; metres), beyond a lane switch at run speed
## (doodad_lane_room): a runner beside it switches into its lane right after it with this to spare, and one in its
## lane out of it right before its push (FloorRoute keeps 1.5 m off a doodad's lane either side of it, 0.6 m off a
## hole's edge, and a switch's length rounded up to its 0.5 m steps). DESIGN-TBD (item 969 in docs/OPEN_QUESTIONS*.md).
const DOODAD_LANE_MARGIN: float = 3.0
## How far inside a free stretch's ends a zone doodad keeps its push's lead and its reach (_place_doodads; metres):
## the stretches are Vector2s (single precision, about 0.25 mm apart 3 km in), so one drawn at the very edge of its
## stretch could reach a hair into what's beyond it (task L6's review: Golden 2 at 3 lanes on seed 9006, a pad's
## zone).
const DOODAD_SPAN_SLACK: float = 0.01
## A wall credit this close to a zone doodad by its wall (task L3), beyond the doodad's ends, is dropped (metres):
## nothing lures a wall run past one. DESIGN-TBD (item 944 in docs/OPEN_QUESTIONS*.md).
const DOODAD_WALL_CREDIT_MARGIN: float = 3.0
## A ceiling credit this close to a ceiling fence in its lane (task I4), beyond the fence's own half depth, is
## dropped (metres): a credit never lures a rider into a fence.
const CEILING_FENCE_CREDIT_MARGIN: float = 1.5
## A player leaving a floor cut's lane is out of it by the time the cut's front is this many metres
## ahead of them (cut_escape_clear): the cause's reach, the body's and a frame of closing in.
const CUT_CONTACT_METRES: float = 4.0
## Clear floor around a switch into a neighbouring lane that a floor cut's escape needs, beyond the
## switch itself (cut_escape_clear), and the most a piece's edge may come near (metres).
const CUT_SWITCH_MARGIN: float = 1.0

var layout: LevelLayout
var config: LevelConfig
## The level's movement tuning (LevelConfig.movement_for: at its own run speed, its zone's in the
## campaign).
var tuning: MovementTuning
## Run speed the level is built for, and a full jump's length at that speed.
var speed: float
var jump_distance: float
## How much faster than MovementTuning.REFERENCE_SPEED the level runs (MovementTuning.pace; 1 at
## 18 m/s). The patterns' metres (an element's `at`, a pattern's `length`, a sign's length, credit
## spacing) and the rules' margins in metres were written for the reference speed: they're stretched
## by it (metres()), so every pattern keeps its timing in seconds and a faster zone is never secretly
## tighter (GDD §3, "Pace and busier levels"). Seconds (`at_seconds`, spacing, ceilings' lengths) and
## jumps (a gap's jump_frac) follow the run speed already.
var pace: float = 1.0
## Problems found in the pattern data during the last generate(), one line per pattern.
var warnings: PackedStringArray = []
## How many builds the last generate() made: 1, unless guarantee_features had to force a missing
## feature somewhere.
var attempts: int = 0
## The floor every ceiling keeps safe (GDD §3): its landing zone and its pads' spots, for this level's
## pacing and run speed. Rules that add ceilings or floor enemies keep to it.
var zones: CeilingZones
## The patterns the pattern pass of the last build placed, in order: {id, requires, at, used, due}
## (`used`: the track it took; `due`: an introduction or one of the guarantee's forced picks). For
## tests and the level report.
var picks: Array[Dictionary] = []
## The patterns the fill pass of the last build placed (LevelConfig.fill_empty_seconds), in order:
## {id, at, used}. For tests and tools/measure/level_pace.gd.
var fills: Array[Dictionary] = []
## Additive gap pass's actual/target counts and any fairness shortfalls; empty when disabled.
var gap_density_result: Dictionary = {}
## The wider gaps of the last build (WideGapPlacement.place: target, rows, widened, added, constraints);
## empty when the level asks for none (LevelConfig.wide_gaps 0).
var wide_gap_result: Dictionary = {}
## The cyborgs planted in charge paths in the last build (ChargePathPlacement.place: target, planted,
## constraints); empty when the level asks for none (LevelConfig.charge_path_cyborgs 0).
var charge_path_result: Dictionary = {}
## The Enforcer Trucks' showing windows in the last build (task C6c; enforcer_truck_rules.gd: planned, for each
## chase its arrival, its preferred one, its bait, its window or why none, and for each bait its own chase's window,
## task C6d); empty in a level without the truck.
var show_window_result: Dictionary = {}
## The danger density pass's report for the last build (DangerDensity.apply_enemies, apply_obstacles,
## then apply_wall_fences: counts, targets, what each lever added, shortfalls); empty when the level's
## danger_density_increase is 0.
var danger_density_result: Dictionary = {}
## The wall-run gaps of the last build (WallRunGapPlacement.place, task J2: how many were due and placed, the plain
## pieces and enemies taken out of their way, constraints); empty in a level without the `wall_run_gaps` feature.
var wall_run_gap_result: Dictionary = {}
## The Buzz Overdrives' company in the last build (BuzzCompanyPlacement.place, task L2: each tank's escape lane, rows,
## pieces and cyborgs, and why the others got none); empty in a level that asks for none (LevelConfig.buzz_company).
var buzz_company_result: Dictionary = {}
## Stretches of track (Vector2) no wall-run gap's clear stretch may reach in the build being made (task J2; set only
## for the wider gaps' rebuild, _make_wide_gap_room; WallRunGapPlacement.place keeps off them). Empty otherwise.
var wall_run_gap_reserve: Array[Vector2] = []
## The clear stretches the pattern pass keeps for the level's extended wall runs in the build being made
## (LevelConfig.extended_wall_runs; WallRunGapPlacement.extended_plan: the owner, October 19, 2026), each
## Vector2(from, to), in the level's order; WallRunGapPlacement places each where it was kept. Empty in every level
## without them, which is built exactly as before.
var extended_wall_run_reserve: Array[Vector2] = []
## Each kept stretch's clear stretch (the run-in to the end of the landing floor, WallRunGapPlacement.keep_out of the
## wall-run gap placed there), in the same order: what ceilings, pads and their landing zones keep off
## (clear_for_extended), and what the anti-grav pad schedules skip (WallRunGapPlacement.pad_skip).
var extended_wall_run_clear: Array[Vector2] = []
## The floor pieces the danger density pass added in the last build that the credit pass gives no
## risky credit (DangerDensity, its tuning's credit_added_pieces off): more danger, not more pay.
var uncredited: Dictionary = {}
## The danger density pass's obstacle-half plan (DangerDensity.apply_obstacles), which the zone doodads
## after it ask (DangerDensity.doodad_ok), during a build only; null when the pass didn't run.
var danger_density_plan: RefCounted = null

var _rng := RandomNumberGenerator.new()
## Which ceilings are narrow, and their lanes (ceiling_lanes): a stream of its own, drawn from only
## where a ceiling may be narrow, so a level without narrow ceilings generates exactly as before.
var _ceiling_rng := RandomNumberGenerator.new()
## Clear stretches between patterns [start, end], filled with credit trails later.
var _clear_stretches: Array[Vector2] = []
var _enemy_count: int = 0
## Picks that must use a feature once the cursor reaches their spot, earliest first: {feature, at,
## intro}. A feature's introduction at its start (LevelConfig.feature_starts; `intro`), and the
## guarantee's forced picks (_pick_due).
var _due: Array[Dictionary] = []
## In a level paced in bursts, the burst (burst_index) that has had its introduction; -1 for none.
var _intro_burst: int = -1


static func load_patterns(path: String) -> Array:
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("patterns"):
		push_error("LevelGenerator: could not read patterns from %s" % path)
		return []
	return parsed["patterns"]


## Every pattern the level can draw from: its main file, then every other .json file in the same
## folder in name order. Patterns declare what they need (`requires`), so a level only ever picks
## the ones its features allow, and adding a pattern file (e.g. one per enemy type) never changes
## levels that don't use it.
static func load_for(p_config: LevelConfig) -> Array:
	var out: Array = load_patterns(p_config.patterns_path)
	var dir: String = p_config.patterns_path.get_base_dir()
	var files: PackedStringArray = DirAccess.get_files_at(dir)
	files.sort()
	for file: String in files:
		var path: String = dir.path_join(file)
		if file.ends_with(".json") and path != p_config.patterns_path:
			out.append_array(load_patterns(path))
	return out


func generate(p_config: LevelConfig, p_tuning: MovementTuning, patterns: Array) -> LevelLayout:
	config = p_config
	tuning = p_config.movement_for(p_tuning)
	speed = tuning.run_speed
	pace = tuning.pace()
	jump_distance = tuning.jump_distance(speed)
	zones = CeilingZones.make(config, tuning, speed)
	attempts = 1
	wall_run_gap_reserve.clear()
	if not config.guarantee_features:
		return _build(patterns, {})
	# Each feature missing from a build gets a pick forced at a new spot in the next one
	# (GUARANTEE_SHARES); a feature that appeared keeps the spot that worked.
	var needed: PackedStringArray = []
	var forced: Dictionary = {}
	var best: Dictionary = {}
	var best_missing: PackedStringArray = []
	for attempt: int in GUARANTEE_ATTEMPTS:
		attempts = attempt + 1
		_build(patterns, forced)
		if attempt == 0:
			needed = placeable_features(patterns)
			needed.append_array(dependent_features(needed))
		var missing: PackedStringArray = missing_features(needed)
		if missing.is_empty():
			return _make_wide_gap_room(patterns, forced, needed)
		if attempt == 0 or missing.size() < best_missing.size():
			best = forced.duplicate()
			best_missing = missing
		# One more forced pick of each feature a missed one asks for, once a build however many ask for it
		# (a truck missed with the bait it rides on).
		var picks_for: Dictionary = {}
		for feature: String in missing:
			for f: String in _guarantee_picks_for(feature, needed):
				picks_for[f] = true
		for f: String in picks_for:
			forced[f] = int(forced.get(f, 0)) + 1
	_build(patterns, best)
	warnings.append("guarantee: after %d builds the level still has no %s (every feature should appear, GDD §5)"
		% [GUARANTEE_ATTEMPTS, ", ".join(best_missing)])
	return layout


## Task J2: a crowded level's wider gaps may fall short where its first wall-run gap took the only room left for one
## (its later ones give way in the wider gaps' own pass, WallRunGapPlacement.set_aside; the first never does, so the
## level keeps one). Built once more (`forced` as the build that stands) with that wall-run gap's clear stretch kept
## for the wider gaps (wall_run_gap_reserve, WallRunGapPlacement.wide_gap_reserve), the wall-run gap goes elsewhere
## (its own last resort making room as ever). That build stands if it has every wider gap, a wall-run gap, every
## feature (`needed`) and no warning; else the level is built as it was. Not a build of the guarantee: `attempts`
## stays as it was. A level that needs no such room is built exactly as before. DESIGN-TBD (docs/questions/j2.md): which
## of the two gives way where a level has room for only one.
func _make_wide_gap_room(patterns: Array, forced: Dictionary, needed: PackedStringArray) -> LevelLayout:
	var reserve: Array[Vector2] = WallRunGapPlacement.wide_gap_reserve(self)
	if reserve.is_empty():
		return layout
	wall_run_gap_reserve = reserve
	_build(patterns, forced)
	wall_run_gap_reserve = []
	if WideGapPlacement.rows_of(self).size() >= config.wide_gaps and not layout.wall_run_gaps.is_empty() \
			and warnings.is_empty() and missing_features(needed).is_empty():
		return layout
	return _build(patterns, forced)


## A generator over a layout that already exists, for the checks its helpers make during a run (a boss
## arena's track, BossArena.cut_problem; endless mode's next stretch): `p_config`'s level at
## `p_tuning`'s speed (LevelConfig.movement_for), with `p_layout` as its layout. Nothing is generated.
static func for_layout(p_config: LevelConfig, p_tuning: MovementTuning, p_layout: LevelLayout) -> LevelGenerator:
	var gen := LevelGenerator.new()
	gen.config = p_config
	gen.tuning = p_config.movement_for(p_tuning)
	gen.speed = gen.tuning.run_speed
	gen.pace = gen.tuning.pace()
	gen.jump_distance = gen.tuning.jump_distance(gen.speed)
	gen.zones = CeilingZones.make(p_config, gen.tuning, gen.speed)
	gen.layout = p_layout
	return gen


## One build of the level: the pattern pass (with the introductions and the guarantee's forced
## picks, `forced`: feature → how many builds missed it), the rules, the credits.
func _build(patterns: Array, forced: Dictionary) -> LevelLayout:
	_rng.seed = config.level_seed
	_ceiling_rng.seed = hash([config.level_seed, "narrow_ceilings"])
	layout = LevelLayout.new()
	layout.lane_count = config.lane_count
	# Task O1: a level whose walls are a boundary (the Terminal's) says so in its layout, for the player and the track.
	layout.wall_running = config.wall_running
	_clear_stretches.clear()
	_enemy_count = 0
	warnings.clear()
	picks.clear()
	fills.clear()
	uncredited.clear()
	# Passes before them ask them (the danger density pass keeps off the wider gaps): never last build's.
	wide_gap_result = {}
	charge_path_result = {}
	show_window_result = {}
	wall_run_gap_result = {}
	buzz_company_result = {}
	danger_density_plan = null
	_intro_burst = -1
	var accel: float = tuning.speed_gain_per_minute / 60.0
	layout.length = speed * config.duration_seconds + 0.5 * accel * config.duration_seconds * config.duration_seconds
	_due = _due_picks(forced)
	# The level's extended wall runs (WallRunGapPlacement.extended_plan): each one's stretch is kept as the cursor
	# reaches its due spot and what the patterns before it reach has ended (extended_wall_run_reserve).
	extended_wall_run_reserve.clear()
	extended_wall_run_clear.clear()
	var extended: Array[Dictionary] = WallRunGapPlacement.extended_plan(self)
	var reach_end: float = -INF

	_clear_stretches.append(Vector2(20.0, config.start_clear_distance))
	var cursor: float = config.start_clear_distance
	while cursor < layout.length - config.end_clear_distance:
		var next_kept: int = extended_wall_run_reserve.size()
		if next_kept < extended.size() and cursor >= float(extended[next_kept]["due"]) and cursor >= reach_end \
				and (next_kept == 0 or cursor >= extended_wall_run_reserve[-1].y + float(extended[next_kept]["spacing"])):
			var kept_to: float = cursor + float(extended[next_kept]["length"])
			if kept_to <= layout.length - config.end_clear_distance:
				extended_wall_run_reserve.append(Vector2(cursor, kept_to))
				extended_wall_run_clear.append(Vector2(cursor + float(extended[next_kept]["clear_from"]),
					cursor + float(extended[next_kept]["clear_to"])))
				_clear_stretches.append(Vector2(cursor, kept_to))
				cursor = kept_to
				continue
		var progress: float = cursor / layout.length
		var difficulty: float = difficulty_at(progress)
		var pattern: Dictionary = _pick_due(patterns, difficulty, cursor)
		var due: bool = not pattern.is_empty()
		if pattern.is_empty():
			pattern = _pick_pattern(patterns, difficulty, cursor)
		if pattern.is_empty():
			break
		var pattern_start_counts: Dictionary = _counts()
		var used: float = _place_pattern(pattern, cursor)
		if cursor + used > layout.length - config.end_clear_distance:
			_rollback(pattern_start_counts)
			break
		if not extended.is_empty():
			# What the pattern's pieces and enemies reach (an enemy's attack, a hover truck's stay) may not reach an
			# extended wall run's stretch, nor, once one is due, more than EXTENDED_WAIT_SECONDS past the pattern's own
			# end (so the stretch can be kept soon): the pattern goes and the cursor moves on a little.
			var reach: Vector2 = _pattern_reach(pattern_start_counts, cursor, cursor + used)
			var pending: int = extended_wall_run_reserve.size()
			var due_now: bool = pending < extended.size() and cursor >= float(extended[pending]["due"])
			var kept: Vector2 = kept_for_extended(reach.x, reach.y)
			# Nor past where the next one must start for it and the rest to fit before the end-clear stretch.
			var latest: float = INF
			if pending < extended.size():
				latest = layout.length - config.end_clear_distance
				for j: int in range(pending, extended.size()):
					latest -= float(extended[j]["length"]) + (float(extended[j]["spacing"]) if j > pending else 0.0)
			if kept.y > kept.x or reach.y > latest \
					or (due_now and reach.y > maxf(cursor + used + EXTENDED_WAIT_SECONDS * speed, reach_end)):
				_rollback(pattern_start_counts)
				var on: float = cursor + EXTENDED_SKIP_SECONDS * speed
				_clear_stretches.append(Vector2(cursor, on))
				cursor = on
				continue
			reach_end = maxf(reach_end, reach.y)
		if layout.hulls.size() > int(pattern_start_counts["hulls"]):
			_secure_ceilings(pattern, pattern_start_counts)
		_settle_due(pattern, cursor)
		picks.append({"id": String(pattern.get("id", "?")), "requires": pattern.get("requires", []), "at": cursor,
			"used": used, "due": due})
		var end: float = cursor + used
		var clear_end: float = end + _spacing_seconds(end, difficulty) * speed
		if config.paced_in_bursts() and quiet_at(end):
			# A quiet stretch's long spacing never carries the cursor far past the next burst's start: the
			# burst begins on time, after the burst spacing at least.
			clear_end = maxf(minf(clear_end, stretch_end(end)), end + config.burst_spacing_seconds * speed)
		_clear_stretches.append(Vector2(end, minf(clear_end, layout.length - config.end_clear_distance)))
		cursor = clear_end

	_apply_enemy_rules()
	danger_density_result = DangerDensity.apply_enemies(self, patterns)
	charge_path_result = ChargePathPlacement.place(self)
	wide_gap_result = WideGapPlacement.place(self)
	_fill_empty_stretches(patterns)
	WideGapPlacement.widen_deferred(self)
	danger_density_result = DangerDensity.apply_obstacles(self, patterns, danger_density_result)
	buzz_company_result = BuzzCompanyPlacement.place(self, patterns)
	_place_doodads(patterns)
	# Only the doodads ask it, and it holds this generator: let it go.
	danger_density_plan = null
	_after_doodad_rules()
	_place_wall_fences()
	WallGapPlacement.place(self)
	gap_density_result = GapDensity.apply(self)
	_place_credits()
	layout.enemies.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["at"] < b["at"])
	_check_walls_unused()
	return layout


## Task O1 (GDD §3 and §5 Zone 8: "the Terminal has no wall running", and nothing there may need a wall run): in a level
## whose walls are a boundary (LevelConfig.wall_running off) a warning for each kind of piece that stands on a wall or
## asks the runner onto one, which its patterns and rules shouldn't have placed: a ramp, a sign, a wall fence, a
## wall-run gap, a line of wall-hop credits, a wall enemy or a credit on a wall. A level with wall running is never
## checked.
func _check_walls_unused() -> void:
	if config.wall_running:
		return
	var found: PackedStringArray = []
	var wall_enemies: int = 0
	for e: Dictionary in layout.enemies:
		wall_enemies += 1 if int(e.get("side", 0)) != 0 else 0
	var wall_credits: int = 0
	for c: Dictionary in layout.credits:
		wall_credits += 1 if String(c.get("surface", "")) == "wall" else 0
	for item: Array in [["ramps", layout.ramps.size()], ["signs", layout.signs.size()], ["wall fences",
			layout.wall_fences.size()], ["wall-run gaps", layout.wall_run_gaps.size()], ["wall-hop lines",
			layout.wall_hops.size()], ["wall enemies", wall_enemies], ["wall credits", wall_credits]]:
		if int(item[1]) > 0:
			found.append("%d %s" % [item[1], item[0]])
	if not found.is_empty():
		warnings.append("no wall running here (LevelConfig.wall_running), but the level has %s (GDD §5, Zone 8)"
			% ", ".join(found))


## `reference_metres` (a distance written for MovementTuning.REFERENCE_SPEED: a pattern's, a rule's
## margin) at this level's run speed: stretched by `pace`, so it takes as long to run.
func metres(reference_metres: float) -> float:
	return reference_metres * pace


## The difficulty at a point of the level (0–1 progress): the level's base plus its ramp.
func difficulty_at(progress: float) -> float:
	return clampf(config.difficulty + config.difficulty_ramp * progress, 0.0, 1.0)


# --- Quiet stretches and bursts (LevelConfig.quiet_seconds; GDD §5, The Hush) --------------------

## True if track distance `at` lies in one of the level's quiet stretches: from the level's first
## pattern (start_clear_distance) on, quiet_seconds at run speed, then burst_seconds of burst, and
## again. The run-up counts as quiet. Always false in a level paced evenly.
func quiet_at(at: float) -> bool:
	if not config.paced_in_bursts():
		return false
	if at < config.start_clear_distance:
		return true
	# The same sums as stretch_end(), so a quiet stretch ends exactly where it says (a cursor it moves
	# to the next burst's start is in that burst).
	var from: float = config.start_clear_distance
	var cycle: float = _pacing_cycle()
	return at < from + floorf((at - from) / cycle) * cycle + config.quiet_seconds * speed


## The track distance where the quiet stretch or the burst holding `at` ends (INF in a level paced
## evenly).
func stretch_end(at: float) -> float:
	if not config.paced_in_bursts():
		return INF
	var from: float = config.start_clear_distance
	var cycle: float = _pacing_cycle()
	var start: float = from + floorf(maxf(at - from, 0.0) / cycle) * cycle
	var quiet_end: float = start + config.quiet_seconds * speed
	return quiet_end if at < quiet_end else start + cycle


## Which burst track distance `at` is in (0 = the level's first); -1 in a quiet stretch or a level
## paced evenly.
func burst_index(at: float) -> int:
	if not config.paced_in_bursts() or quiet_at(at):
		return -1
	return floori((at - config.start_clear_distance) / _pacing_cycle())


## The level's quiet stretches [start, end] up to its end-clear stretch, in order (none in a level
## paced evenly). Bursts are what lies between them.
func quiet_stretches() -> Array[Vector2]:
	var out: Array[Vector2] = []
	if not config.paced_in_bursts():
		return out
	var last: float = layout.length - config.end_clear_distance
	var at: float = config.start_clear_distance
	while at < last:
		out.append(Vector2(at, minf(at + config.quiet_seconds * speed, last)))
		at += _pacing_cycle()
	return out


func _pacing_cycle() -> float:
	return maxf((config.quiet_seconds + config.burst_seconds) * speed, 1.0)


## Seconds of clear track after a pattern that ends at `at`: the level's spacing for its difficulty,
## or in a level paced in bursts the quiet or the burst spacing there.
func _spacing_seconds(at: float, difficulty: float) -> float:
	if config.paced_in_bursts():
		return config.quiet_spacing_seconds if quiet_at(at) else config.burst_spacing_seconds
	return lerpf(config.spacing_seconds_easy, config.spacing_seconds_hard, difficulty)


## Track distances [from, to] within `lo`–`hi` that lie in bursts, in order: where a rule that
## guarantees an enemy at a spot of its choosing puts it in a level paced in bursts (the threats come
## in the bursts; GDD §5, The Hush). Empty in a level paced evenly.
func burst_spans(lo: float, hi: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if not config.paced_in_bursts():
		return out
	var from: float = config.start_clear_distance + config.quiet_seconds * speed
	while from <= hi:
		var span := Vector2(maxf(from, lo), minf(from + config.burst_seconds * speed, hi))
		if span.y >= span.x:
			out.append(span)
		from += _pacing_cycle()
	return out


## True if a rule that guarantees one of `feature`'s enemies should put it in a burst: in a level
## paced in bursts, for every feature but its quiet_features.
func prefers_bursts(feature: String) -> bool:
	return config.paced_in_bursts() and not config.quiet_features.has(feature)


## For a rule guaranteeing one of `feature`'s enemies at one of `spots`: the spots to try first and
## the rest, in that order. In a level paced in bursts, those in a burst come first (prefers_bursts),
## or for one of its quiet_features those in a quiet stretch; in a level paced evenly, just `spots`.
func pacing_pools(spots: Array[float], feature: String) -> Array[Array]:
	if not config.paced_in_bursts():
		return [spots]
	var first: Array[float] = []
	var rest: Array[float] = []
	var quiet_feature: bool = config.quiet_features.has(feature)
	for s: float in spots:
		if quiet_at(s) == quiet_feature:
			first.append(s)
		else:
			rest.append(s)
	return [first, rest]


## For a rule guaranteeing one of `feature`'s enemies (prefers_bursts): a spot drawn with `rng` from
## the bursts within `lo`–`hi` (each metre of burst equally likely). NAN, drawing nothing, when the
## feature needn't be in a burst or no burst lies there: the rule then picks its spot as usual.
func burst_spot(rng: RandomNumberGenerator, lo: float, hi: float, feature: String) -> float:
	if not prefers_bursts(feature):
		return NAN
	var spans: Array[Vector2] = burst_spans(lo, hi)
	var total: float = 0.0
	for s: Vector2 in spans:
		total += s.y - s.x
	if spans.is_empty():
		return NAN
	var r: float = rng.randf() * total
	for s: Vector2 in spans:
		if r <= s.y - s.x:
			return s.x + r
		r -= s.y - s.x
	return spans[-1].y


## True if `pattern` may be picked at `at` in a level paced in bursts (GDD §5, The Hush: long silent
## stretches broken by sudden threats):
## - a pattern that places enemies and requires only quiet_features belongs to the quiet stretches:
##   it must start in one and place its enemies before it ends (The Hush's hosts stand alone in the
##   silence); any other that places enemies must start in a burst and place its enemies before that
##   burst ends, so a burst's threats appear in the burst (an Octodog's charges or a hover truck's
##   stay may still run on after it);
## - a burst takes only threats: patterns with a hole, a fence, a sign or an enemy. Safe mechanics
##   alone (a plain ceiling, a ramp, a speed pad) go in the quiet stretches, with sparse obstacles.
func _pacing_allows(pattern: Dictionary, at: float) -> bool:
	var last_enemy: float = -1.0
	var threat: bool = false
	for element: Dictionary in pattern.get("elements", []):
		var kind: String = String(element.get("kind", ""))
		if kind == "enemy":
			last_enemy = maxf(last_enemy, metres(float(element.get("at", 0.0))) + float(element.get("at_seconds", 0.0)) * speed)
		threat = threat or kind in ["gap", "fence", "sign", "enemy"]
	var quiet: bool = quiet_at(at)
	if not quiet and not threat:
		return false
	if last_enemy < 0.0:
		return true
	var requires: Array = pattern.get("requires", [])
	var quiet_ok: bool = not requires.is_empty()
	for need: Variant in requires:
		if not config.quiet_features.has(String(need)):
			quiet_ok = false
			break
	return quiet == quiet_ok and at + last_enemy < stretch_end(at)


## Track distance from which `feature` may place anything: its share of the level from
## LevelConfig.feature_starts, or 0 for features that are there from the start.
func feature_start(feature: String) -> float:
	return config.feature_start(feature) * layout.length


## True if track distance `at` is at or past `feature`'s start (always, for a feature that starts
## with the level), whether or not the level has the feature.
func feature_started(feature: String, at: float) -> bool:
	return at >= feature_start(feature) - 0.001


## True if the level has `feature` and it has started by track distance `at`. Patterns are picked,
## and rules scripts add a feature's enemies or pieces (a drone's anti-grav pads are the `ceilings`
## feature's, a hover truck's ramp the `ramps` feature's), only where this holds.
func feature_active(feature: String, at: float) -> bool:
	return config.has_feature(feature) and feature_started(feature, at)


## Track distance `share` (0–1) of the way through the stretch where `feature` is active, from its
## start to the level's end: for rules that pick a spot as a share of the level (a guaranteed drone
## wave or hover truck), so a late feature's spot still falls after its start. Without a start it's
## simply `share` of the level.
func feature_share_at(feature: String, share: float) -> float:
	var from: float = feature_start(feature)
	return from + (layout.length - from) * share


## A random stream for one rule set, independent of the others (enemy rules use this).
func rng_for(rule_name: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([config.level_seed, rule_name])
	return rng


## Adds an enemy entry with a deterministic per-enemy seed. Returns the entry.
func add_enemy(type: String, at: float, lane: int, side: int = 0, params: Dictionary = {}) -> Dictionary:
	var entry := {"type": type, "at": at, "lane": lane, "side": side,
		"seed": hash([config.level_seed, type, _enemy_count]), "params": params}
	_enemy_count += 1
	layout.enemies.append(entry)
	return entry


## Adds a ceiling section with an anti-grav pad at `at` in `lane` (hull lead-in before it), lasting
## `length_seconds` at run speed, over whatever the floor holds there (GDD §3: the floor under a
## ceiling may be dangerous), covering `lanes` (Vector2i(first, last); every lane by default, and a
## narrow ceiling's range from ceiling_lanes, which must hold the pad's lane: a pad sits under its
## ceiling). Returns false (adding nothing) if the pad can't be stepped on or its landing zone isn't
## safe to land on (CeilingZones: pad_clear, landing_clear over its lanes, which include floor
## enemies' stretches), it would touch another ceiling, its landing doesn't end before the level's
## end-clear stretch, or the level's ceilings haven't started by `at` (a late `ceilings` feature,
## feature_started). PadPlacement clears the way first.
func add_hull_with_pad(lane: int, at: float, length_seconds: float, lanes: Vector2i = Vector2i(-1, -1)) -> bool:
	if not feature_started("ceilings", at):
		return false
	var span: Vector2i = lanes if lanes.x >= 0 else Vector2i(0, layout.lane_count - 1)
	if lane < span.x or lane > span.y:
		return false
	var hull: Dictionary = LevelLayout.make_hull(at - config.hull_lead_in, at + length_seconds * speed, span,
		layout.lane_count)
	var landing: Vector2 = zones.landing_zone(hull)
	if landing.y > layout.length - config.end_clear_distance:
		return false
	# No ceiling, pad or landing zone over an extended wall run's clear stretch (extended_wall_run_clear).
	var kept: Vector2 = clear_for_extended(minf(float(hull["start"]), zones.pad_zone(at).x), landing.y)
	if kept.y > kept.x:
		return false
	if not zones.pad_clear(layout, lane, at) or not zones.landing_clear(layout, landing, span):
		return false
	for h: Dictionary in layout.hulls:
		if float(hull["start"]) <= float(h["end"]) + 1.0 and float(hull["end"]) >= float(h["start"]) - 1.0:
			return false
	layout.pads.append({"lane": lane, "at": at})
	layout.hulls.append(hull)
	return true


## The lanes a new ceiling with its pads in `pads` covers, starting its lead-in before a pad at `at`
## (GDD §3: ceilings don't have to cover every lane; its pads always lie under it): Vector2i(first,
## last). Every lane, drawing nothing, unless the level makes a share of its ceilings narrow
## (LevelConfig.narrow_ceiling_share) and `at` is past narrow_ceiling_start. Then, from the level's own
## ceiling stream (so full-width ceilings and every other pick stay as they were): whether this one
## is narrow; if so, one lane (one_lane_ceiling_share of them, where `one_lane_ok` and the pads share a
## lane: a pattern that puts nothing under its ceiling, or a rule's ceiling), or from two lanes to
## narrow_ceiling_max_lanes (all but one by default), each as likely, and every lane if its pads lie
## further apart; and where the range lies, anywhere that holds every pad. A one-lane ceiling lasts
## one_lane_ceiling_seconds at most (one_lane_seconds). DESIGN-TBD (docs/questions/b3.md).
func ceiling_lanes(pads: Array[int], at: float, one_lane_ok: bool) -> Vector2i:
	var n: int = layout.lane_count
	var full := Vector2i(0, n - 1)
	if config.narrow_ceiling_share <= 0.0 or n < 2 or pads.is_empty() \
			or at < config.narrow_ceiling_start * layout.length:
		return full
	# A share of 1 (the Terminal's, task O1: every ceiling one lane wide, GDD §5 Zone 8) draws nothing for it, so
	# randf()'s inclusive top end never leaves one out; a share below 1 draws exactly as before.
	if config.narrow_ceiling_share < 1.0 and _ceiling_rng.randf() >= config.narrow_ceiling_share:
		return full
	var lo_pad: int = pads.min()
	var hi_pad: int = pads.max()
	var width: int = 1
	if not (one_lane_ok and lo_pad == hi_pad
			and (config.one_lane_ceiling_share >= 1.0 or _ceiling_rng.randf() < config.one_lane_ceiling_share)):
		var widest: int = n - 1
		if config.narrow_ceiling_max_lanes > 0:
			widest = clampi(config.narrow_ceiling_max_lanes, 1, n - 1)
		var least: int = maxi(2, hi_pad - lo_pad + 1)
		if least > widest:
			return full
		width = _ceiling_rng.randi_range(least, widest)
	var first: int = _ceiling_rng.randi_range(maxi(0, hi_pad - width + 1), mini(lo_pad, n - width))
	return Vector2i(first, first + width - 1)


## How long a ceiling over `lanes` lasts past its pad, at most `seconds`: a one-lane ceiling is very
## short (GDD §3; LevelConfig.one_lane_ceiling_seconds).
func one_lane_seconds(lanes: Vector2i, seconds: float) -> float:
	if lanes.x == lanes.y and layout.lane_count > 1:
		return minf(seconds, config.one_lane_ceiling_seconds)
	return seconds


## True if nothing on the floor touches any lane between two track distances: no gap, no fence, no
## floor cut (its lane's window, FloorCutPlan.lane_window) and no floor enemy's stretch
## (enemy_floor_span).
func floor_clear(from: float, to: float) -> bool:
	for g: Dictionary in layout.gaps:
		if g["start"] <= to and g["end"] >= from:
			return false
	for f: Dictionary in layout.fences:
		if f["at"] >= from and f["at"] <= to:
			return false
	if layout.cut_between(from, to):
		return false
	for e: Dictionary in layout.enemies:
		var span: Vector2 = enemy_floor_span(e, pace)
		if span.x <= to and span.y >= from:
			return false
	return true


## The stretch of floor [start, end] an enemy entry uses, which a ceiling's landing zone and the
## spots of its pads keep off (CeilingZones): its params.floor_span if its rules planned one, else
## its tuning's reach around its position, stretched by the level's `pace` (MovementTuning.pace: in a
## faster zone the enemies move and reach further in the same time). Vector2(INF, -INF) (overlapping
## nothing) for types whose tuning says they don't use the floor.
static func enemy_floor_span(entry: Dictionary, pace: float = 1.0) -> Vector2:
	var params: Dictionary = entry.get("params", {})
	if params.get("floor_span") is Vector2:
		return params["floor_span"]
	var at: float = float(entry["at"])
	var t := EnemyDirector.tuning_for(String(entry.get("type", ""))) as EnemyTuning
	if t == null:
		return Vector2(at - 10.0 * pace, at + 10.0 * pace)
	if not t.uses_floor:
		return Vector2(INF, -INF)
	return Vector2(at - t.floor_reach_before * pace, at + t.floor_reach_after * pace)


## False for enemy types whose tuning says they never come down to the floor lanes (fliers such as
## drones and hover trucks, wall-only enemies such as window cyborgs). Unknown types use the floor.
## A hover truck keeps its lane free of the others (HoverTruckRules).
static func enemy_uses_floor(entry: Dictionary) -> bool:
	var t := EnemyDirector.tuning_for(String(entry.get("type", ""))) as EnemyTuning
	return t == null or t.uses_floor


## The wall run that ramp `r` (a layout.ramps entry) launches the player into at this level's run
## speed: where they are on the wall, how high and how fast, with the ramp's fading speed boost
## (RampLaunch, GDD §3). Every rule that predicts a ramp's wall run asks it: the credits along it
## (wall_run_credits), and a rule that must keep a wall hazard out of a ramp's launch (task B5: never a
## live wall fence where a ramp launches the player into it).
func ramp_launch(r: Dictionary) -> RampLaunch:
	return RampLaunch.of(r, tuning, speed)


## A weighted random pick among the patterns that fit at track distance `at` (pick_weights). Returns
## {} (without drawing a random number) when none fits.
func _pick_pattern(patterns: Array, difficulty: float, at: float, only: String = "") -> Dictionary:
	var pool: Dictionary = pick_weights(patterns, difficulty, at, only)
	var candidates: Array = pool["patterns"]
	var weights: Array[float] = pool["weights"]
	if candidates.is_empty():
		return {}
	var total: float = 0.0
	for w: float in weights:
		total += w
	var roll: float = _rng.randf() * total
	for i: int in candidates.size():
		roll -= weights[i]
		if roll <= 0.0:
			return candidates[i]
	return candidates[-1]


## The patterns that fit at track distance `at`, in their order in `patterns`, and their pick weights:
## {"patterns": Array, "weights": Array[float]}. A pattern fits in its difficulty range and lane
## count, with every required feature active there (feature_active); with `only`, just the patterns
## that require that feature.
## A pattern's weight is its own times the level's feature_weights for what it requires, and with
## the campaign's recency curve (LevelConfig.recency_on) times its newest feature's factor (no more
## than a capped feature's cap, FeatureRecency.max_factor); with keep_feature_share the features'
## patterns, capped ones apart, are then scaled back so that together they weigh what they weighed
## without the curve. With keep_share_by_kind that holds kind by kind (pattern_kind), and patterns
## with enemies weigh by the enemies they place (enemy_count): the curve only moves picks between
## features of the same kind, and the level places as many enemies, obstacles and safe mechanics as
## before. In a level paced in bursts, only the patterns _pacing_allows are taken (threats in bursts,
## enemies only there bar quiet_features), and a burst that has had its introduction leaves out the
## features still waiting for theirs (_intro_held). With `fill`, just the patterns the fill pass may
## place (is_filler).
func pick_weights(patterns: Array, difficulty: float, at: float, only: String = "", fill: bool = false) -> Dictionary:
	var candidates: Array = []
	var weights: Array[float] = []
	var recency: bool = config.recency_on()
	var by_kind: bool = recency and config.feature_recency.keep_share_by_kind
	var paced: bool = config.paced_in_bursts()
	var held: PackedStringArray = _intros_waiting(at) if _intro_held(at) else PackedStringArray()
	# Per kind of pattern (all in one without by_kind), what the features' patterns weigh without the
	# recency curve, and with it: the capped ones, and the rest (keep_feature_share). Patterns with
	# enemies count their enemies too (by_kind), so the curve keeps how many a level places.
	var plain: Array[float] = [0.0, 0.0, 0.0]
	var capped: Array[float] = [0.0, 0.0, 0.0]
	var curved: Array[float] = [0.0, 0.0, 0.0]
	# Each candidate's kind if keep_feature_share scales it back, else -1.
	var scaled_kind: Array[int] = []
	for p: Dictionary in patterns:
		if difficulty < float(p.get("min_difficulty", 0.0)) or difficulty > float(p.get("max_difficulty", 1.0)):
			continue
		if config.lane_count < int(p.get("min_lanes", 1)):
			continue
		if fill and not is_filler(p):
			continue
		var requires: Array = p.get("requires", [])
		if only != "" and not requires.has(only):
			continue
		if paced and not _pacing_allows(p, at):
			continue
		var weight: float = float(p.get("weight", 1.0))
		var ok: bool = true
		for need: Variant in requires:
			if not feature_active(String(need), at) or held.has(String(need)):
				ok = false
				break
			weight *= config.feature_weight(String(need))
		if not ok or weight <= 0.0:
			continue
		var kind: int = -1
		if recency and not requires.is_empty():
			kind = pattern_kind(p) if by_kind else 0
			var measure: float = float(enemy_count(p, config.lane_count)) if by_kind and kind == 0 else 1.0
			plain[kind] += weight * measure
			weight *= config.recency_factor(requires)
			if config.recency_capped(requires):
				capped[kind] += weight * measure
				kind = -1
			else:
				curved[kind] += weight * measure
		candidates.append(p)
		weights.append(weight)
		scaled_kind.append(kind)
	if recency and config.feature_recency.keep_feature_share:
		var scale: Array[float] = [1.0, 1.0, 1.0]
		for k: int in 3:
			if curved[k] > 0.0:
				scale[k] = maxf(plain[k] - capped[k], 0.0) / curved[k]
		for i: int in candidates.size():
			if scaled_kind[i] >= 0:
				weights[i] *= scale[scaled_kind[i]]
	return {"patterns": candidates, "weights": weights}


## A pattern's kind, for the recency curve's shares (FeatureRecency.keep_share_by_kind): 0 if it
## places enemies, 1 if it places obstacles only (holes, fences, signs), 2 if neither (a plain
## ceiling, a ramp, a speed pad: safe mechanics).
static func pattern_kind(pattern: Dictionary) -> int:
	var kind: int = 2
	for element: Dictionary in pattern.get("elements", []):
		var element_kind: String = String(element.get("kind", ""))
		if element_kind == "enemy":
			return 0
		if element_kind in ["gap", "fence", "sign"]:
			kind = 1
	return kind


## How many enemies `pattern` places at `lanes` lanes: one for each wall enemy, and one for each lane
## a floor enemy's selector picks (as _pick_lanes counts them, before any rule drops one).
static func enemy_count(pattern: Dictionary, lanes: int) -> int:
	var count: int = 0
	var prev: int = 0
	for element: Dictionary in pattern.get("elements", []):
		var element_kind: String = String(element.get("kind", ""))
		if element_kind == "enemy" and element.has("side"):
			count += 1
		elif element_kind in ["gap", "fence", "hull", "speed_pad", "enemy"]:
			var fallback: Dictionary = {} if element_kind in ["gap", "fence"] else {"mode": "random", "count": 1}
			var picked: int = _selector_count(element.get("lanes", fallback), lanes, prev)
			if element_kind == "enemy":
				count += picked
			prev = picked
	return count


## How many lanes a lane selector picks at `lanes` lanes, `prev` being how many the element before
## picked (_pick_lanes).
static func _selector_count(selector: Dictionary, lanes: int, prev: int) -> int:
	var n: int = int(selector.get("count", 1))
	if selector.has("frac"):
		n = maxi(1, roundi(float(selector["frac"]) * lanes))
	match String(selector.get("mode", "random")):
		"all":
			return lanes
		"same":
			return prev
		"others":
			return lanes - prev
		"edge", "center":
			return 1
		"all_but":
			return lanes - clampi(n, 1, lanes - 1)
	return clampi(n, 1, lanes)


## The picks this build must give a feature, earliest first: each feature's introduction at its
## start (LevelConfig.feature_starts), and forced picks for each feature an earlier build missed
## (`forced`: feature → how many builds missed it; that many picks, up to GUARANTEE_MAX_PICKS, at
## spots from GUARANTEE_SHARES, the first one moving on with each miss).
func _due_picks(forced: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for key: Variant in config.feature_starts:
		var feature: String = String(key)
		if config.has_feature(feature):
			out.append({"feature": feature, "at": feature_start(feature), "intro": true})
	var n: int = GUARANTEE_SHARES.size()
	for key: Variant in forced:
		var feature: String = String(key)
		var misses: int = int(forced[key])
		for k: int in mini(misses, GUARANTEE_MAX_PICKS):
			var share: float = GUARANTEE_SHARES[(misses - 1 + k * 5) % n]
			out.append({"feature": feature, "at": feature_share_at(feature, share), "intro": false})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["at"]) < float(b["at"]) or (float(a["at"]) == float(b["at"]) and String(a["feature"]) < String(b["feature"])))
	return out


## A due pick: once the cursor reaches a due pick's spot, the next pattern picked is one that uses its
## feature. That's how a feature is introduced right after its start and its first-encounter hint
## (GDD §6: one new thing at a time) rather than whenever chance brings it, and how the guarantee
## places a feature a build missed. {} if nothing is due, or no due feature has a pattern that fits
## here (it's then tried again at the next pick, so a feature with no patterns yet changes nothing).
## In a level paced in bursts, a due pick of a feature a quiet stretch leaves out waits for the next
## burst, and a burst that has had one introduction holds the next for the burst after (_intro_held).
func _pick_due(patterns: Array, difficulty: float, at: float) -> Dictionary:
	var held: bool = _intro_held(at)
	for due: Dictionary in _due:
		if float(due["at"]) > at + 0.001:
			break
		if held and bool(due.get("intro", false)):
			continue
		var pattern: Dictionary = _pick_pattern(patterns, difficulty, at, String(due["feature"]))
		if not pattern.is_empty():
			return pattern
	return {}


## A pattern placed at `at` settles the due pick of each feature it uses whose spot the cursor has
## reached (the earliest one, if a feature has several). An introduction settled in a burst makes it
## that burst's one introduction.
func _settle_due(pattern: Dictionary, at: float) -> void:
	for need: Variant in pattern.get("requires", []):
		for i: int in _due.size():
			if float(_due[i]["at"]) > at + 0.001:
				break
			if String(_due[i]["feature"]) == String(need):
				if bool(_due[i].get("intro", false)) and burst_index(at) >= 0:
					_intro_burst = burst_index(at)
				_due.remove_at(i)
				break


## True if a level paced in bursts is in a burst at `at` that has had its introduction already: the
## features still waiting for theirs wait for the next burst (a burst never stacks two new things).
func _intro_held(at: float) -> bool:
	return config.paced_in_bursts() and _intro_burst >= 0 and burst_index(at) == _intro_burst


## The features whose introduction is due by `at` and not placed yet.
func _intros_waiting(at: float) -> PackedStringArray:
	var out: PackedStringArray = []
	for due: Dictionary in _due:
		if float(due["at"]) > at + 0.001:
			break
		if bool(due.get("intro", false)) and not out.has(String(due["feature"])):
			out.append(String(due["feature"]))
	return out


## The level's features that some pattern can place: a pattern that requires the feature, needs
## only the level's features, fits its lane count, has pick weight (feature_weights) and a
## difficulty range the level reaches between the pattern's features' starts and the end-clear
## stretch. The guarantee (guarantee_features) covers these; a feature with no such pattern (one
## still to be built) can't appear. Needs the layout's length (generate() has set it).
func placeable_features(patterns: Array) -> PackedStringArray:
	var out: PackedStringArray = []
	var last: float = layout.length - config.end_clear_distance
	for feature: String in config.features:
		for p: Dictionary in patterns:
			var requires: Array = p.get("requires", [])
			if not requires.has(feature) or config.lane_count < int(p.get("min_lanes", 1)):
				continue
			var weight: float = float(p.get("weight", 1.0))
			var first: float = config.start_clear_distance
			var ok: bool = true
			for need: Variant in requires:
				ok = ok and config.has_feature(String(need))
				weight *= config.feature_weight(String(need))
				first = maxf(first, feature_start(String(need)))
			if not ok or weight <= 0.0 or first >= last:
				continue
			if float(p.get("min_difficulty", 0.0)) <= difficulty_at(last / layout.length) \
					and float(p.get("max_difficulty", 1.0)) >= difficulty_at(first / layout.length):
				out.append(feature)
				break
	return out


## The level's features with no pattern of their own whose rules place them only around other features'
## entries (their rules script's GUARANTEED_BY), when one of those is in `placeable`: the guarantee covers
## them too (the Enforcer Truck, around the Octodogs' and Buzz Overdrives' charges), unless their rules place
## none (guaranteed_by).
func dependent_features(placeable: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = []
	for feature: String in config.features:
		if placeable.has(feature):
			continue
		for f: String in guaranteed_by(feature):
			if placeable.has(f):
				out.append(feature)
				break
	return out


## What a build that missed `feature` forces picks of in the next one: the feature itself, or, for one its
## rules place around other features' entries (guaranteed_by), those of them in `needed`, moved elsewhere.
func _guarantee_picks_for(feature: String, needed: PackedStringArray) -> PackedStringArray:
	var by: PackedStringArray = guaranteed_by(feature)
	if by.is_empty():
		return PackedStringArray([feature])
	var out: PackedStringArray = []
	for f: String in by:
		if needed.has(f):
			out.append(f)
	return out


## The features whose entries `feature`'s rules place it around (its rules script's GUARANTEED_BY), or []:
## a feature with patterns of its own has none, and so has one whose rules place none of it (their `static
## func places_any() -> bool` false: the Enforcer Truck's tuning at per_level_max 0), which no build
## could then show.
static func guaranteed_by(feature: String) -> PackedStringArray:
	var path: String = RULES_DIR.path_join("%s_rules.gd" % feature)
	var script: GDScript = load(path) as GDScript if ResourceLoader.exists(path) else null
	if script == null:
		return PackedStringArray()
	if script.has_method("places_any") and not bool(script.call("places_any")):
		return PackedStringArray()
	return PackedStringArray(script.get_script_constant_map().get("GUARANTEED_BY", []))


## The features of `needed` that the current layout has nothing of (feature_positions).
func missing_features(needed: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = []
	for feature: String in needed:
		if feature_positions(layout, feature).is_empty():
			out.append(feature)
	return out


## Track distances of everything `feature` placed in `layout`, in order: ramps (ramps), anti-grav
## pads (ceilings), speed pads (speed_pads), pulsing fences (pulsing), full-height wall fences
## (wall_fences) and partial ones (wall_fences_partial), host cyborgs (host), cyborgs that aren't hosts
## (cyborg; nor planted in a charge's path, task G7: an extra the charge flattens, never the level's own
## cyborg encounter; nor a Buzz Overdrive's company, task L2, an extra too), screeches from wall vents
## (screech_vents), and otherwise the enemies of that type, which
## covers every enemy type. A feature whose rules script declares
## `static func positions(layout: LevelLayout) -> Array[float]` answers for itself (a new kind of
## piece).
static func feature_positions(p_layout: LevelLayout, feature: String) -> Array[float]:
	var out: Array[float] = []
	var path: String = RULES_DIR.path_join("%s_rules.gd" % feature)
	if ResourceLoader.exists(path):
		var script := load(path) as GDScript
		if script != null and script.has_method("positions"):
			out.assign(script.call("positions", p_layout))
			out.sort()
			return out
	match feature:
		"ramps":
			for r: Dictionary in p_layout.ramps:
				out.append(float(r["at"]))
		"ceilings":
			for p: Dictionary in p_layout.pads:
				out.append(float(p["at"]))
		"speed_pads":
			for p: Dictionary in p_layout.speed_pads:
				out.append(float(p["at"]))
		"pulsing":
			for f: Dictionary in p_layout.fences:
				if bool(f["pulsing"]):
					out.append(float(f["at"]))
		"wall_fences", "wall_fences_partial":
			# Full-height wall fences, or the partial ones (task B5, WallFencePlacement).
			for w: Dictionary in p_layout.wall_fences:
				if WallFencePlan.is_partial(w) == (feature == "wall_fences_partial"):
					out.append(float(w["at"]))
		"wall_gaps":
			for g: Dictionary in p_layout.wall_gaps:
				out.append(float(g["start"]))
		_:
			for e: Dictionary in p_layout.enemies:
				var type: String = String(e.get("type", ""))
				var params: Dictionary = e.get("params", {})
				var host: bool = type == "cyborg" and bool(params.get("host", false))
				var hit: bool = false
				match feature:
					"cyborg":
						hit = type == "cyborg" and not host and not params.has(ChargePathPlacement.PARAM) \
							and not params.has(BuzzCompanyPlacement.PARAM)
					"host":
						hit = host
					"screech_vents":
						hit = type == "screech" and String(params.get("source", "")) == "vent"
					_:
						hit = type == feature
				if hit:
					out.append(float(e["at"]))
	out.sort()
	return out


## Places every element of a pattern starting at `origin`. Returns the track length it used (a
## ceiling's includes its landing zone, so the next pattern starts past it). GDD §3: floor pieces
## and floor enemies may lie under a ceiling (the pattern's own: a gauntlet the ceiling escapes);
## _secure_ceilings keeps its landing zone and pads' spots safe afterwards. The pattern's metres are
## stretched by the level's pace (metres()), so it keeps its timing at any run speed.
func _place_pattern(pattern: Dictionary, origin: float) -> float:
	var used: float = metres(float(pattern.get("length", 8.0)))
	var prev_lanes: Array[int] = []
	var prev_side: int = 1
	for element: Dictionary in pattern.get("elements", []):
		# "at" is in metres at the reference speed (stretched by the pace); "at_seconds" scales with run
		# speed (for pieces timed against a hull).
		var at: float = origin + metres(float(element.get("at", 0.0))) + float(element.get("at_seconds", 0.0)) * speed
		match String(element.get("kind", "")):
			"gap":
				var lanes: Array[int] = _pick_lanes(element.get("lanes", {}), prev_lanes)
				var frac: float = minf(float(element.get("jump_frac", 0.5)), config.max_gap_jump_fraction)
				var gap_len: float = frac * jump_distance
				for lane: int in lanes:
					layout.gaps.append({"lane": lane, "start": at, "end": at + gap_len})
				used = maxf(used, at - origin + gap_len)
				prev_lanes = lanes
			"fence":
				var lanes: Array[int] = _pick_lanes(element.get("lanes", {}), prev_lanes)
				var pulsing: bool = _rng.randf() < float(element.get("pulse_chance", 0.0))
				for lane: int in lanes:
					layout.fences.append({
						"lane": lane,
						"at": at,
						"variant": String(element.get("variant", "full")),
						"pulsing": pulsing,
						"pulse_on": float(element.get("pulse_on", 1.2)),
						"pulse_off": float(element.get("pulse_off", 1.0)),
						"phase": _rng.randf(),
					})
				prev_lanes = lanes
			"sign":
				var side: int = _pick_side(String(element.get("side", "random")), prev_side)
				var sides: Array[int] = [side]
				if String(element.get("side", "")) == "both":
					sides = [-1, 1]
				var sign_len: float = metres(float(element.get("length", 8.0)))
				for s: int in sides:
					layout.signs.append({
						"side": s,
						"start": at,
						"end": at + sign_len,
						"bottom": float(element.get("bottom", 0.0)),
						"top": float(element.get("top", 3.0)),
					})
				used = maxf(used, at - origin + sign_len)
				prev_side = side
			"ramp":
				var side: int = _pick_side(String(element.get("side", "random")), prev_side)
				layout.ramps.append({"side": side, "at": at})
				prev_side = side
			"hull":
				var lanes: Array[int] = _pick_lanes(element.get("lanes", {"mode": "random", "count": 1}), prev_lanes)
				# Its lanes: every lane, or a narrow ceiling's range over its pads (one lane only if the
				# pattern puts nothing under it; ceiling_lanes).
				var span: Vector2i = ceiling_lanes(lanes, at, plain_ceiling(pattern))
				var hull_len: float = one_lane_seconds(span, float(element.get("length_seconds", 4.0))) * speed
				for lane: int in lanes:
					layout.pads.append({"lane": lane, "at": at})
				layout.hulls.append(LevelLayout.make_hull(at - config.hull_lead_in, at + hull_len, span, layout.lane_count))
				used = maxf(used, at - origin + hull_len + zones.landing)
				prev_lanes = lanes
			"speed_pad":
				var lanes: Array[int] = _pick_lanes(element.get("lanes", {"mode": "random", "count": 1}), prev_lanes)
				for lane: int in lanes:
					layout.speed_pads.append({"lane": lane, "at": at})
				prev_lanes = lanes
			"enemy":
				var type: String = String(element.get("type", ""))
				var params: Dictionary = element.get("params", {})
				if element.has("side"):
					var side: int = _pick_side(String(element.get("side", "random")), prev_side)
					add_enemy(type, at, layout.outer_lane(side), side, params.duplicate(true))
					prev_side = side
				else:
					var lanes: Array[int] = _pick_lanes(element.get("lanes", {"mode": "random", "count": 1}), prev_lanes)
					for lane: int in lanes:
						add_enemy(type, at, lane, 0, params.duplicate(true))
					prev_lanes = lanes
			"credits":
				_place_credit_element(element, at, prev_lanes, prev_side)
			_:
				push_warning("LevelGenerator: unknown element kind in pattern %s" % pattern.get("id", "?"))
	return used


## True if `pattern` puts nothing but its ceiling (and credits) on the track: nothing under the
## ceiling, so a one-lane ceiling may come of it (GDD §3: a one-lane ceiling is simply ridden out,
## short and relatively safe; a gauntlet's ceiling stays long enough to escape it).
static func plain_ceiling(pattern: Dictionary) -> bool:
	for element: Dictionary in pattern.get("elements", []):
		if not (String(element.get("kind", "")) in ["hull", "credits"]):
			return false
	return true


## GDD §3: the ceilings a pattern just placed (the pieces after `counts`) keep their landing zone
## (over their lanes) and their pads' spots safe (CeilingZones). A piece of the pattern's own there
## is a mistake in the pattern data: it's dropped, with a warning. Anything an earlier pattern left
## there (possible only with pacing tighter than a pad's run-up) is taken out quietly, which never
## makes a level unfair.
func _secure_ceilings(pattern: Dictionary, counts: Dictionary) -> void:
	var own: Array[Dictionary] = []
	var lists: Dictionary = layout.to_dict()
	for key: String in ["gaps", "fences", "ramps", "enemies"]:
		own.append_array((lists[key] as Array).slice(int(counts[key])))
	for i: int in range(int(counts["hulls"]), layout.hulls.size()):
		var h: Dictionary = layout.hulls[i]
		zones.clear_landing(layout, zones.landing_zone(h), layout.hull_lanes(h))
	for i: int in range(int(counts["pads"]), layout.pads.size()):
		zones.clear_pad(layout, int(layout.pads[i]["lane"]), float(layout.pads[i]["at"]))
	lists = layout.to_dict()
	for item: Dictionary in own:
		var kept: bool = false
		for key: String in ["gaps", "fences", "ramps", "enemies"]:
			for other: Dictionary in lists[key]:
				if is_same(other, item):
					kept = true
					break
			if kept:
				break
		if not kept:
			var line: String = "pattern '%s' puts a floor piece in a ceiling's landing zone or at its pad (GDD §3); skipped" \
				% pattern.get("id", "?")
			if not warnings.has(line):
				warnings.append(line)
			return


## What the pattern just placed (its pieces and enemies since `counts`, _counts, from `from` to `to`) reaches along the
## track: its own stretch, each enemy's keep-out and the floor it uses (enemy_keep_out, enemy_floor_span), a hover
## truck's whole stay with the ramp its rules give it (HoverTruckRules.window_start, window_end), a cyborg's obstacle
## margin, each ceiling's landing zone, each ramp's longest wall run. For the extended wall runs' stretches
## (extended_wall_run_reserve).
func _pattern_reach(counts: Dictionary, from: float, to: float) -> Vector2:
	var out := Vector2(from, to)
	var hooks: Dictionary = {}
	for i: int in range(int(counts["enemies"]), layout.enemies.size()):
		var e: Dictionary = layout.enemies[i]
		var at: float = float(e["at"])
		var spans: Array[Vector2] = [enemy_keep_out(e, hooks), enemy_floor_span(e, pace), Vector2(at, at)]
		match String(e.get("type", "")):
			"hover_truck":
				var ht: HoverTruckTuning = HoverTruckRules.tuning()
				spans.append(Vector2(HoverTruckRules.window_start(ht, at, pace),
					maxf(HoverTruckRules.window_end(ht, at, speed), at + ht.ramp_after_seconds * speed + tuning.ramp_length
					+ (tuning.wall_entry_time + tuning.wall_slide_time) * speed)))
			"cyborg":
				var ct := EnemyDirector.tuning_for("cyborg") as CyborgTuning
				var margin: float = CyborgRules.obstacle_margin_at(ct, pace) if ct != null else metres(10.0)
				spans.append(Vector2(at - margin, at + margin))
		for k: Vector2 in spans:
			if k.y >= k.x:
				out = Vector2(minf(out.x, k.x), maxf(out.y, k.y))
	for i: int in range(int(counts["hulls"]), layout.hulls.size()):
		var landing: Vector2 = zones.landing_zone(layout.hulls[i])
		out = Vector2(minf(out.x, float(layout.hulls[i]["start"])), maxf(out.y, landing.y))
	for i: int in range(int(counts["ramps"]), layout.ramps.size()):
		out.y = maxf(out.y, WallFencePlacement.ramp_run_end(self, layout.ramps[i]))
	return out


## The stretch the pattern pass keeps for an extended wall run (extended_wall_run_reserve) that [from, to] reaches,
## or Vector2.ZERO if none. Rules whose pieces reach far from their entry (a drone's pads, a hover truck's stay) ask it
## too, so the stretch stays clear for the wall-run gaps' pass.
func kept_for_extended(from: float, to: float) -> Vector2:
	for r: Vector2 in extended_wall_run_reserve:
		if r.x < to and r.y > from:
			return r
	return Vector2.ZERO


## The clear stretch of an extended wall run (extended_wall_run_clear) that [from, to] reaches, or Vector2.ZERO if none.
func clear_for_extended(from: float, to: float) -> Vector2:
	for r: Vector2 in extended_wall_run_clear:
		if r.x < to and r.y > from:
			return r
	return Vector2.ZERO


## Size of every piece list, so a pattern that doesn't fit can be taken back out.
func _counts() -> Dictionary:
	return {"gaps": layout.gaps.size(), "fences": layout.fences.size(), "signs": layout.signs.size(),
		"hulls": layout.hulls.size(), "pads": layout.pads.size(), "ramps": layout.ramps.size(),
		"speed_pads": layout.speed_pads.size(), "enemies": layout.enemies.size(),
		"credits": layout.credits.size()}


func _rollback(counts: Dictionary) -> void:
	layout.gaps.resize(counts["gaps"])
	layout.fences.resize(counts["fences"])
	layout.signs.resize(counts["signs"])
	layout.hulls.resize(counts["hulls"])
	layout.pads.resize(counts["pads"])
	layout.ramps.resize(counts["ramps"])
	layout.speed_pads.resize(counts["speed_pads"])
	layout.enemies.resize(counts["enemies"])
	layout.credits.resize(counts["credits"])


## Lane selector modes: all, all_but (count|frac), random (count|frac), edge, center, same, others.
## "same" reuses the previous element's lanes; "others" is every lane the previous element didn't use.
func _pick_lanes(selector: Dictionary, prev_lanes: Array[int]) -> Array[int]:
	var n: int = layout.lane_count
	var all: Array[int] = []
	for i: int in n:
		all.append(i)
	var mode: String = String(selector.get("mode", "random"))
	match mode:
		"all":
			return all
		"same":
			return prev_lanes.duplicate()
		"others":
			var rest: Array[int] = []
			for i: int in all:
				if not prev_lanes.has(i):
					rest.append(i)
			return rest
		"edge":
			var edge: Array[int] = [0 if _rng.randf() < 0.5 else n - 1]
			return edge
		"center":
			var center: Array[int] = [n / 2]
			return center
		"all_but":
			var keep_free: int = clampi(_count(selector, n), 1, n - 1)
			var picked: Array[int] = _shuffled(all)
			return _sorted(picked.slice(keep_free))
		_:
			var count: int = clampi(_count(selector, n), 1, n)
			var picked: Array[int] = _shuffled(all)
			return _sorted(picked.slice(0, count))


func _count(selector: Dictionary, n: int) -> int:
	if selector.has("frac"):
		return maxi(1, roundi(float(selector["frac"]) * n))
	return int(selector.get("count", 1))


func _pick_side(spec: String, prev_side: int) -> int:
	match spec:
		"left":
			return -1
		"right":
			return 1
		"same":
			return prev_side
		_:
			return -1 if _rng.randf() < 0.5 else 1


func _shuffled(values: Array[int]) -> Array[int]:
	var out: Array[int] = values.duplicate()
	for i: int in range(out.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp: int = out[i]
		out[i] = out[j]
		out[j] = tmp
	return out


func _sorted(values: Array[int]) -> Array[int]:
	var out: Array[int] = values.duplicate()
	out.sort()
	return out


# --- Busier levels: the fill pass (GDD §3, owner's playtest September 30, 2026) ------------------

## Fills the level's long empty stretches with more of its plain obstacle patterns: where nothing goes
## on for longer than LevelConfig.fill_empty_seconds at run speed (no piece and no enemy: fill_keep_outs'
## "activity"), fillers (is_filler: holes and fences, picked by difficulty and weight as the pattern
## pass picks) go wherever nothing is kept either (its "keep"), as far from everything already there as
## the pattern pass spaces its patterns (the level's spacing there, plus FILL_TAIL_SECONDS) and as far
## from each other. It runs after the
## pattern pass and every rule, so track a rule kept for an enemy that then didn't come (a hover truck
## too near the end, an Octodog whose charges didn't fit) doesn't stay bare, and it never touches what
## a rule keeps. More of the same patterns, never harder ones (GDD §3: busier levels, "so there is
## always something going on"). Its own random stream: with fill_empty_seconds 0 (quick play, tests,
## boss arenas) a level is built exactly as it was before.
func _fill_empty_stretches(patterns: Array) -> void:
	if config.fill_empty_seconds <= 0.0:
		return
	var from: float = config.start_clear_distance
	var to: float = layout.length - config.end_clear_distance
	var outs: Dictionary = fill_keep_outs(patterns)
	var blocked: Array[Vector2] = []
	for k: Vector4 in outs["keep"]:
		blocked.append(Vector2(k.x - k.z, k.y + k.w))
	var empties: Array[Vector2] = free_stretches(outs["activity"], from, to)
	var saved: RandomNumberGenerator = _rng
	_rng = rng_for("fill")
	for region: Vector2 in free_stretches(blocked, from, to):
		# Only where nothing goes on for longer than fill_empty_seconds (every activity is kept, so the
		# region lies inside one such stretch).
		var empty := Vector2.ZERO
		for e: Vector2 in empties:
			if e.x <= region.x + 0.001 and e.y >= region.y - 0.001:
				empty = e
				break
		if (empty.y - empty.x) / speed <= config.fill_empty_seconds:
			continue
		var cursor: float = region.x
		var last: float = region.y
		while cursor < last:
			var difficulty: float = difficulty_at(cursor / layout.length)
			var pattern: Dictionary = _pick_filler(patterns, difficulty, cursor, last - cursor)
			if pattern.is_empty():
				break
			var used: float = _place_pattern(pattern, cursor)
			fills.append({"id": String(pattern.get("id", "?")), "at": cursor, "used": used})
			_trim_clear_stretches(Vector2(cursor, cursor + used))
			cursor += used + _spacing_seconds(cursor + used, difficulty) * speed
	_rng = saved
	if not fills.is_empty():
		_after_fill_rules()


## Runs the `static func after_fill(gen: LevelGenerator)` of every feature's rules script that has one,
## in the order of the level's features: a rule that keeps floor pieces out of somewhere the fill pass
## doesn't keep off whole (a hover truck's lane) keeps the fillers out too.
func _after_fill_rules() -> void:
	for feature: String in config.features:
		var path: String = RULES_DIR.path_join("%s_rules.gd" % feature)
		if not ResourceLoader.exists(path):
			continue
		var script := load(path) as GDScript
		if script != null and script.has_method("after_fill"):
			script.call("after_fill", self)


## Runs the `static func after_doodads(gen: LevelGenerator)` of every feature's rules script that has one, in the
## order of the level's features, after the danger density pass's obstacles and the zone doodads, before the wall
## fences: a rule that places what the passes before it shouldn't make room for (the dash walls past their
## introduction, task H7a: the fill pass, the danger density pass and the doodads fill the level as they would
## without them, and they stand in the room left, taking out plain pieces where they must).
func _after_doodad_rules() -> void:
	for feature: String in config.features:
		var path: String = RULES_DIR.path_join("%s_rules.gd" % feature)
		if not ResourceLoader.exists(path):
			continue
		var script := load(path) as GDScript
		if script != null and script.has_method("after_doodads"):
			script.call("after_doodads", self)


## True if the fill pass may place `pattern`: plain obstacles, holes and fences only, that need no
## feature (so nothing new ever comes before its introduction) and put nothing on a wall.
static func is_filler(pattern: Dictionary) -> bool:
	if not (pattern.get("requires", []) as Array).is_empty():
		return false
	var elements: Array = pattern.get("elements", [])
	if elements.is_empty():
		return false
	for element: Dictionary in elements:
		if not (String(element.get("kind", "")) in ["gap", "fence"]):
			return false
	return true


## What the fill pass keeps off: {"keep": Array[Vector4], "activity": Array[Vector2]}. "keep": stretches
## of track [from, to] where something is going on or kept, as Vector4(from, to, margin before, margin
## after), with how far a filler stays from each end (_fill_margin: the level's spacing there and a
## pattern's tail; none where a gauntlet's timing already holds). "activity": what of it is going on
## (every piece and enemy; not a landing zone, a pad's run-up or a quiet stretch). Kept off:
## every floor piece (holes, fences, signs, speed pads), each ramp to where its wall run drops the player
## back (RampLaunch), each pad's zone and each ceiling's landing zone (CeilingZones) and the floor under a
## ceiling, but where the level already picks gauntlets (a pattern with a ceiling and holes or fences
## under it, from its min_difficulty) over two lanes or more: there fillers may go under it, timed like
## a gauntlet's pieces (FILL_CEILING_AFTER_PAD_SECONDS after its pads, FILL_CEILING_BEFORE_END_SECONDS
## before its end); every enemy from FILL_ENEMY_LEAD_SECONDS before it to the end of the floor it uses
## (LevelGenerator.enemy_floor_span), or what its rules script keeps for it (`static func keep_out(gen:
## LevelGenerator, entry: Dictionary) -> Vector2`: a cyborg's margin, a hover truck's lane window, a
## Resonator's visit, a drone wave until its first pad); a level's quiet stretches; every floor cut, in
## every lane, from its warning to its end (FloorCutPlan.window); every dash wall's footprint, in every lane
## (task H7a, DashWallRules.footprint: its clear approach, the wall and the clear stretch past it); and with
## `with_rules`, the calm stretches the rules keep (rules_fill_keep_outs: an Enforcer Truck's showing window, task
## C6c). (Zone doodads come after the fill pass, into what it leaves: _place_doodads.) With `except_cut`, without that
## floor cut's window and its cause's keep-out (task L2: what a Buzz Overdrive's company keeps off,
## BuzzCompanyPlacement).
func fill_keep_outs(patterns: Array, with_rules: bool = true, except_cut: Dictionary = {}) -> Dictionary:
	var out: Array[Vector4] = []
	var half: float = tuning.fence_depth * 0.5
	for g: Dictionary in layout.gaps:
		out.append(_keep(g["start"], g["end"]))
	for f: Dictionary in layout.fences:
		out.append(_keep(float(f["at"]) - half, float(f["at"]) + half))
	for s: Dictionary in layout.signs:
		out.append(_keep(s["start"], s["end"]))
	for r: Dictionary in layout.ramps:
		out.append(_keep(float(r["at"]), maxf(ramp_launch(r).end(), float(r["at"]) + tuning.ramp_length)))
	for p: Dictionary in layout.speed_pads:
		out.append(_keep(p["at"], float(p["at"]) + tuning.speed_pad_length))
	for p: Dictionary in layout.pads:
		out.append(Vector4(float(p["at"]), float(p["at"]) + tuning.pad_length, 0.0, 0.0))
	var hooks: Dictionary = {}
	for e: Dictionary in layout.enemies:
		if not except_cut.is_empty() and int(e.get("lane", -1)) == int(except_cut["lane"]) \
				and absf(float(e["at"]) - float(except_cut["end"])) < 0.01:
			continue
		var k: Vector2 = _enemy_keep_out(e, hooks)
		out.append(_keep(k.x, k.y))
	# A floor cut, in every lane, from its warning to its end or past its cause, whichever is later
	# (GDD §9.9: nothing else in its lane, its neighbours kept whole, nothing else going on).
	for c: Dictionary in layout.cuts:
		if is_same(c, except_cut):
			continue
		var w: Vector2 = FloorCutPlan.window(c, speed)
		out.append(_keep(w.x, w.y))
	# A dash wall (task H7a), in every lane: its clear approach, the wall and the clear stretch past it.
	for dw: Dictionary in layout.dash_walls:
		var fp: Vector2 = DashWallRules.footprint(self, dw)
		out.append(_keep(fp.x, fp.y))
	var activity: Array[Vector2] = []
	for k: Vector4 in out:
		activity.append(Vector2(k.x, k.y))
	var gauntlets: float = gauntlet_difficulty(patterns)
	var open_hulls: Array[Dictionary] = []
	for h: Dictionary in layout.hulls:
		var landing: Vector2 = zones.landing_zone(h)
		if layout.hull_width(h) >= 2 and difficulty_at(float(h["start"]) / layout.length) >= gauntlets:
			open_hulls.append(h)
			out.append(Vector4(float(h["end"]) - FILL_CEILING_BEFORE_END_SECONDS * speed, landing.y, 0.0,
				_fill_margin(landing.y)))
		else:
			out.append(_keep(float(h["start"]), landing.y))
	for p: Dictionary in layout.pads:
		var at: float = float(p["at"])
		var zone: Vector2 = zones.pad_zone(at)
		var under_open: bool = false
		for h: Dictionary in open_hulls:
			under_open = under_open or (at >= float(h["start"]) and at <= float(h["end"]))
		if under_open:
			out.append(Vector4(zone.x, maxf(zone.y, at + FILL_CEILING_AFTER_PAD_SECONDS * speed), _fill_margin(zone.x), 0.0))
		else:
			out.append(_keep(zone.x, zone.y))
	for q: Vector2 in quiet_stretches():
		out.append(_keep(q.x, q.y))
	if with_rules:
		for w: Vector2 in rules_fill_keep_outs():
			out.append(Vector4(w.x, w.y, 0.0, 0.0))
	return {"keep": out, "activity": activity}


## What the level's features' rules keep the fill pass off besides their enemies' stretches (`static func
## fill_keep_outs(gen: LevelGenerator) -> Array[Vector2]` on a feature's rules script), in every lane and kept as
## they are, without the fill pass's margin (they hold nothing to keep a distance from): an Enforcer Truck's showing
## window (task C6c, enforcer_truck_rules.gd), a calm stretch the zone doodads and every other later pass keep off
## too (its doodad_keep_outs).
func rules_fill_keep_outs() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for feature: String in config.features:
		var path: String = RULES_DIR.path_join("%s_rules.gd" % feature)
		if not ResourceLoader.exists(path):
			continue
		var script := load(path) as GDScript
		if script != null and script.has_method("fill_keep_outs"):
			for k: Vector2 in script.call("fill_keep_outs", self):
				out.append(k)
	return out


## A keep-out [from, to] with the fill pass's usual margin at both ends (_fill_margin).
func _keep(from: float, to: float) -> Vector4:
	return Vector4(from, to, _fill_margin(from), _fill_margin(to))


## The lowest difficulty at which the level picks a gauntlet: a pattern with a ceiling and holes or
## fences under it whose features the level has, with pick weight. INF without one.
func gauntlet_difficulty(patterns: Array) -> float:
	var out: float = INF
	for p: Dictionary in patterns:
		var hull: bool = false
		var floor_piece: bool = false
		for element: Dictionary in p.get("elements", []):
			var kind: String = String(element.get("kind", ""))
			hull = hull or kind == "hull"
			floor_piece = floor_piece or kind in ["gap", "fence"]
		if not (hull and floor_piece) or config.lane_count < int(p.get("min_lanes", 1)):
			continue
		var weight: float = float(p.get("weight", 1.0))
		var ok: bool = true
		for need: Variant in p.get("requires", []):
			ok = ok and config.has_feature(String(need))
			weight *= config.feature_weight(String(need))
		if ok and weight > 0.0:
			out = minf(out, float(p.get("min_difficulty", 0.0)))
	return out


## What the fill pass keeps off around enemy entry `e` (fill_keep_outs). `hooks` caches each type's
## rules script's keep_out, if it has one.
func _enemy_keep_out(e: Dictionary, hooks: Dictionary) -> Vector2:
	var type: String = String(e.get("type", ""))
	if not hooks.has(type):
		var path: String = RULES_DIR.path_join("%s_rules.gd" % type)
		var script: GDScript = load(path) as GDScript if ResourceLoader.exists(path) else null
		hooks[type] = script if script != null and script.has_method("keep_out") else null
	if hooks[type] != null:
		return (hooks[type] as GDScript).call("keep_out", self, e)
	var at: float = float(e["at"])
	var out := Vector2(at - FILL_ENEMY_LEAD_SECONDS * speed, at)
	var span: Vector2 = enemy_floor_span(e, pace)
	if span.y >= span.x:
		out = Vector2(minf(out.x, span.x), maxf(out.y, span.y))
	return out


## The stretches of [from, to] that none of `busy` covers, in order.
static func free_stretches(busy: Array[Vector2], from: float, to: float) -> Array[Vector2]:
	var sorted: Array[Vector2] = busy.duplicate()
	sorted.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var out: Array[Vector2] = []
	var cursor: float = from
	for b: Vector2 in sorted:
		if b.y <= cursor:
			continue
		if b.x > cursor:
			out.append(Vector2(cursor, minf(b.x, to)))
		cursor = maxf(cursor, b.y)
		if cursor >= to:
			return out
	if cursor < to:
		out.append(Vector2(cursor, to))
	return out


## How far the fill pass keeps a filler from what's around track distance `at`: the level's spacing
## there plus FILL_TAIL_SECONDS, at run speed.
func _fill_margin(at: float) -> float:
	var difficulty: float = difficulty_at(clampf(at / layout.length, 0.0, 1.0))
	return (_spacing_seconds(at, difficulty) + FILL_TAIL_SECONDS) * speed


## A weighted pick among the fillers that fit in `room` metres from `at` (is_filler, pattern_extent).
## {} (drawing nothing) when none fits.
func _pick_filler(patterns: Array, difficulty: float, at: float, room: float) -> Dictionary:
	var pool: Dictionary = pick_weights(patterns, difficulty, at, "", true)
	var candidates: Array = []
	var weights: Array[float] = []
	var total: float = 0.0
	for i: int in (pool["patterns"] as Array).size():
		var p: Dictionary = pool["patterns"][i]
		if pattern_extent(p) <= room:
			candidates.append(p)
			weights.append(float(pool["weights"][i]))
			total += weights[-1]
	if candidates.is_empty() or total <= 0.0:
		return {}
	var roll: float = _rng.randf() * total
	for i: int in candidates.size():
		roll -= weights[i]
		if roll <= 0.0:
			return candidates[i]
	return candidates[-1]


## The track a pattern of holes and fences takes at this level's speed: its length, or its last hole's
## end (what _place_pattern returns for it).
func pattern_extent(pattern: Dictionary) -> float:
	var extent: float = metres(float(pattern.get("length", 8.0)))
	for element: Dictionary in pattern.get("elements", []):
		var at: float = metres(float(element.get("at", 0.0))) + float(element.get("at_seconds", 0.0)) * speed
		if String(element.get("kind", "")) == "gap":
			at += minf(float(element.get("jump_frac", 0.5)), config.max_gap_jump_fraction) * jump_distance
		extent = maxf(extent, at)
	return extent


## Takes `span` out of the clear stretches the credit trails go in (a filler now stands there).
func _trim_clear_stretches(span: Vector2) -> void:
	var out: Array[Vector2] = []
	for s: Vector2 in _clear_stretches:
		if s.y <= span.x or s.x >= span.y:
			out.append(s)
			continue
		if s.x < span.x:
			out.append(Vector2(s.x, span.x))
		if s.y > span.y:
			out.append(Vector2(span.y, s.y))
	_clear_stretches = out


# --- Zone doodads (GDD §3, owner's playtest September 30, 2026) -----------------------------------

## What the zone doodads keep off, worked out once a build (_place_doodads; task L6): what every lane keeps, and
## what each lane holds.
class DoodadRoom:
	## The stretches of the track, in order, that nothing kept in every lane reaches (doodad_keep_outs): where a
	## doodad, its push's lead and the room around it may lie.
	var regions: Array[Vector2] = []
	## The rules' calm stretches (an Enforcer Truck's showing window): no doodad nor its push's lead in one.
	var calm: Array[Vector2] = []
	## {lane, from, to}: a lane no doodad stands in or pushes into there (doodad_keep_outs: a hover truck's for its
	## whole stay, a floor cut's over its lane window).
	var keeps: Array[Dictionary] = []
	## Per lane, an Array[Vector2] of what it holds (doodad_lane_busy).
	var lanes: Array = []
	## What each side wall keeps a doodad by it off ([left, right]: wall_lane_keep_outs).
	var walls: Array = []


## Puts the level's zone doodads (LevelConfig.doodad_share; LevelLayout.doodads) where they're fair lane by lane
## (task L6, the owner's playtest, October 17, 2026: "the doodads are too rare ... they do not add much extra
## difficulty, if any at all, so we shouldn't have a rule there for fairness' sake"), after the rules and the fill
## pass: they add to the level, and nothing after them can undo or crowd them (only the credits come later, and
## keep out of them). A doodad never hurts: a player who runs into its front is pushed into the neighbouring lane on
## its side (Player; one who catches its front corner mid-switch, back the way they came), and its sides block a
## lane switch like a solid side. What fairness needs of one (or of a row, as one from its first front to its last
## end), at any lane count (LayoutChecks.check_doodads, at 3, 5 and 6 lanes), its push's lead before its front
## (doodad_lead_for) and doodad_lane_room() (a lane switch at run speed with DOODAD_LANE_MARGIN to spare) around it:
## - its own lane holds nothing from that room before its push to the level's spacing past its end (doodad_after:
##   what it hides behind it from the chase camera, which a runner the dash brings through it sees only at the
##   smash, comes no sooner than between two patterns), another doodad included;
## - the lanes beside it hold nothing (no hole, fence, pad, speed pad, ramp or the wall run it launches, floor cut,
##   floor enemy: doodad_lane_busy) from that room before its push until its landing's reaction (doodad_landing:
##   past a row's last front, a push on the floor or a jump pushed in the air, then
##   LevelConfig.doodad_reaction_seconds), or that room past its end if later: every push lands on clear floor with
##   time to react, into the lane on its side or, for a caught corner, back the way the runner came (task L6's
##   review), a runner beside it never has to dodge into its lane, and a runner further out keeps a free lane on
##   their side of it, so it never takes away the only way past a row of holes or fences. Lanes further out may hold
##   anything (task L6: a hole in a far lane);
## - nothing the rules keep in every lane reaches it (doodad_keep_outs: an enemy's attack as the fill pass keeps
##   it, which the enemies' own checks hold back while a doodad stands anywhere along it, a floor cut's window, a
##   ceiling to the end of its landing zone, a pad's zone, a quiet stretch, a dash wall's footprint, a wider gap's
##   zone, a wall-run gap's clear stretch, a treasure stash's floor, a Bad Dream's chase, a Gilded Sentinel's
##   strike), from its push's lead before its front to that room past its end (doodad_reach); nor does a calm
##   stretch reach it or its push's lead (an Enforcer Truck's showing window);
## - neither its lane nor the lane it pushes into is one a rule keeps (doodad_keep_outs' lane keeps: a hover
##   truck's for its whole stay, a floor cut's lane over its lane window); it pushes into a side with room, a
##   seeded choice when both have it;
## - in an inner lane, or in an outermost one by an open side wall (task L3, the owner, October 9, 2026:
##   "doodads prefer the lane next to the side wall when it's open, without costing gameplay"; with
##   LevelConfig.doodad_wall_lane_share of them where one may): nothing stands on that wall beside it or the
##   level needs it open there (wall_lane_keep_outs: no sign, wall enemy or ramp's longest wall run, no
##   wall-run gap's lit wall, doodad_wall_clear_seconds of wall clear around each; no dash wall's wall route, no
##   wall fence whose drop-off lands by it, no wall gap beside it or dropping a wall runner onto it, not where
##   the level brings in wall fences), and the wall fences and side wall gaps placed after keep off it too
##   (WallFencePlacement, WallGapPlacement). Such a doodad pushes inward; a runner on that wall low enough to meet
##   it breaks it as they reach it instead (Player._check_wall_doodads), so the wall stays theirs;
## - doodad_gap_seconds from one's end (a row's last one's) to the next one's front: the next clears the last
##   one's push; and closer than the level's spacing they stand two lanes apart at least (never in the lane beside,
##   where its push lands: no slalom; nor in its lane, which it hides);
## - where the danger density pass ran, never in the only lane its pieces leave a player to come to it
##   in (DangerDensity.doodad_ok: a doodad is neither jumped nor stood beside in its lane).
## The level's doodads are drawn spot by spot (LevelConfig.doodad_spot_seconds apart, from doodad_start): each spot
## with room for one gets one with the level's doodad_share, its front at a seeded place in the spot, in a size class
## (doodad_*_weight) that fits there. With LevelConfig.doodad_row_chance it's the first of a row (task L3, the owner,
## October 17, 2026: "occasionally ... rows of similar doodads"; _row_shape): doodad_row_min to doodad_row_max of
## them (task L6: from two), of its size class and look, in its lane, pushing to its side, one right after the other
## (DOODAD_ROW_TOUCH apart) or with a doodad's length between each two (by size class, LevelConfig.doodad_row_spaced:
## small ones touch, medium and large ones stand apart), the whole row kept by every rule above as one doodad from
## its first front to its last end (LevelLayout.doodad_extent), as long as fits there (never shorter than
## doodad_row_min). Its own random stream (rng_for("doodads")), and the rows' and the wall lane's another
## (rng_for("doodad_rows")): with doodad_share 0 nothing is drawn and the level is built exactly as before.
## DESIGN-TBD (docs/questions/g5.md 1 and 4; items 942-947 in docs/OPEN_QUESTIONS*.md; items 969-976 in docs/OPEN_QUESTIONS*.md): where
## doodads stand, how many, the rows.
func _place_doodads(patterns: Array) -> void:
	if config.doodad_share <= 0.0 or layout.lane_count < 3:
		return
	var weights: Array[float] = [config.doodad_small_weight, config.doodad_medium_weight, config.doodad_large_weight]
	var smallest: float = INF
	for i: int in weights.size():
		if weights[i] > 0.0:
			smallest = minf(smallest, tuning.doodad_size(LevelLayout.DOODAD_SIZES[i]).z)
	if smallest == INF:
		return
	var rng: RandomNumberGenerator = rng_for("doodads")
	# Task L3: the rows and the lane by a side wall draw from a stream of their own.
	var row_rng: RandomNumberGenerator = rng_for("doodad_rows")
	var room := DoodadRoom.new()
	room.regions = free_stretches(doodad_keep_outs(patterns, room.keeps, room.calm), 0.0, layout.length)
	room.lanes = doodad_lane_busy()
	# What each side wall keeps a doodad by it off ([left, right]), worked out once: nothing the doodads add changes it.
	var no_keeps: Array[Vector2] = []
	room.walls = [no_keeps, no_keeps]
	if config.doodad_wall_lane_share > 0.0:
		room.walls = [wall_lane_keep_outs(-1), wall_lane_keep_outs(1)]
	var lead: float = doodad_lead_for(tuning)
	var spot: float = maxf(config.doodad_spot_seconds * speed, 1.0)
	var gap: float = config.doodad_gap_seconds * speed
	var from: float = maxf(config.start_clear_distance, config.doodad_start * layout.length)
	var to: float = layout.length - config.end_clear_distance
	var last_end: float = -INF
	var r: int = 0
	var a: float = from
	while a < to:
		var b: float = minf(a + spot, to)
		var lo: float = maxf(a, last_end + gap)
		a += spot
		# Where this spot's doodad may have its front: in the first stretch every lane leaves free that holds the
		# smallest one with its push's lead before it and its reach past its front (doodad_reach), from `lo` on, a
		# sliver inside the stretch's ends (DOODAD_SPAN_SLACK).
		var window := Vector2(INF, -INF)
		while r < room.regions.size():
			var region: Vector2 = room.regions[r]
			var first: float = region.x + lead + DOODAD_SPAN_SLACK
			var latest: float = minf(region.y - doodad_reach(smallest) - DOODAD_SPAN_SLACK, to - smallest)
			if latest < lo or latest < first:
				# No front here from this spot on, nor for any later spot: the next stretch.
				r += 1
				continue
			if first < b:
				window = Vector2(maxf(lo, first), minf(b, latest))
			break
		if window.y < window.x or rng.randf() >= config.doodad_share:
			continue
		var start: float = window.x + rng.randf() * (window.y - window.x)
		# The longest a doodad (or a row) from `start` may be: what every lane keeps stays clear of its reach.
		var fits: float = minf(room.regions[r].y - start - doodad_lane_room() - DOODAD_SPAN_SLACK, to - start)
		var size: StringName = _pick_doodad_size(rng, weights, fits)
		var length: float = tuning.doodad_size(size).z
		# A row (task L3): how many, and from one's front to the next one's; Vector2(1, 0) for one doodad.
		var row: Vector2 = _row_shape(row_rng, size, length, fits)
		var extent: float = (row.x - 1.0) * row.y + length
		# A calm stretch (an Enforcer Truck's showing window, task C6c) takes no doodad, nor its push's lead.
		if _hits_any(room.calm, start - lead, start + extent):
			continue
		var placed: Array[Dictionary] = _add_doodads(rng, row_rng, size, start, int(row.x), row.y, room)
		# A row with no lane to stand in along its whole stretch gives way to one doodad where it would start.
		if placed.is_empty() and row.x > 1.0:
			placed = _add_doodads(rng, row_rng, size, start, 1, 0.0, room)
		if not placed.is_empty():
			last_end = float(placed[-1]["end"])


## A doodad's size class, drawn by `weights` (LevelConfig.doodad_*_weight, smallest first) among the
## classes no longer than `room` metres. One at least fits (the caller checks the smallest).
func _pick_doodad_size(rng: RandomNumberGenerator, weights: Array[float], room: float) -> StringName:
	var total: float = 0.0
	var fits: Array[float] = []
	for i: int in weights.size():
		var ok: bool = weights[i] > 0.0 and tuning.doodad_size(LevelLayout.DOODAD_SIZES[i]).z <= room
		fits.append(weights[i] if ok else 0.0)
		total += fits[i]
	var roll: float = rng.randf() * total
	for i: int in fits.size():
		roll -= fits[i]
		if fits[i] > 0.0 and roll <= 0.0:
			return LevelLayout.DOODAD_SIZES[i]
	for i: int in range(fits.size() - 1, -1, -1):
		if fits[i] > 0.0:
			return LevelLayout.DOODAD_SIZES[i]
	return LevelLayout.DOODAD_SIZES[0]


## What a doodad of size class `size`, `length` metres long, with `room` metres for it, becomes (task L3:
## LevelConfig's doodad_row_*): Vector2(how many in its row, metres from one's front to the next one's), Vector2(1, 0)
## for one doodad. The first of a row with doodad_row_chance; doodad_row_min to doodad_row_max of them (each count as
## likely), with a doodad's length between each two (the size class's share, LevelConfig.doodad_row_spaced: the
## owner's stalls) or DOODAD_ROW_TOUCH (the owner's plants); fewer where `room` holds fewer, down to doodad_row_min,
## and one doodad where it holds no row that long. Draws from `row_rng` only, and nothing with the chance 0.
func _row_shape(row_rng: RandomNumberGenerator, size: StringName, length: float, room: float) -> Vector2:
	if config.doodad_row_chance <= 0.0 or row_rng.randf() >= config.doodad_row_chance:
		return Vector2(1.0, 0.0)
	var least: int = maxi(mini(config.doodad_row_min, config.doodad_row_max), 2)
	var count: int = row_rng.randi_range(least, maxi(config.doodad_row_min, config.doodad_row_max))
	var step: float = length + (length if row_rng.randf() < config.doodad_row_spaced(size) else DOODAD_ROW_TOUCH)
	# A sliver of play left over: a row that filled its room to the centimetre would meet what's either side of it
	# (a filler the fill pass spaced from a landing zone leaves room for exactly two small ones touching).
	while count > least and (count - 1) * step + length > room - DOODAD_ROW_TOUCH:
		count -= 1
	if (count - 1) * step + length > room - DOODAD_ROW_TOUCH:
		return Vector2(1.0, 0.0)
	return Vector2(count, step)


## Adds `count` doodads of `size` (one, or a row: task L3), the first from `start`, each `step` metres on from the
## one before, in one lane, pushing to one side, where `room` (_place_doodads) says the whole row fits lane by lane
## (_doodad_lane_fits, _doodad_push_fits): an inner lane (a seeded pick among those it fits in) pushing into a side
## with room (seeded when both have it), or, with LevelConfig.doodad_wall_lane_share (`row_rng`), the outermost lane
## by an open side wall (room.walls: each wall's wall_lane_keep_outs; a seeded one when both are open; the only choice
## when no inner lane fits), pushing inward. Returns the entries in order, or [] (adding nothing) when no lane fits.
## Each doodad's seed counts the zone doodads before it; a row's share its first one's as their look (`look`), and
## its stretch (`row`: LevelLayout.doodad_extent).
func _add_doodads(rng: RandomNumberGenerator, row_rng: RandomNumberGenerator, size: StringName, start: float,
		count: int, step: float, room: DoodadRoom) -> Array[Dictionary]:
	var none: Array[Dictionary] = []
	var length: float = tuning.doodad_size(size).z
	# Its last one's front: a runner the dash leaves short of it, or one in a space of a spaced row, meets it.
	var last: float = start + (count - 1) * step
	var end: float = last + length
	var lanes: Array[int] = []
	var sides: Array[Array] = []
	for lane: int in range(1, layout.lane_count - 1):
		if not _doodad_lane_fits(room, lane, start, end, last):
			continue
		var room_sides: Array[int] = []
		for side: int in [-1, 1]:
			if _doodad_push_fits(room, lane, side, start, end, last):
				room_sides.append(side)
		if not room_sides.is_empty():
			lanes.append(lane)
			sides.append(room_sides)
	# Task L3: the outermost lanes by an open side wall, pushing inward.
	var open: Array[int] = []
	if config.doodad_wall_lane_share > 0.0:
		for wall: int in [-1, 1]:
			var lane: int = layout.outer_lane(wall)
			if _hits_any(room.walls[0 if wall < 0 else 1], start, end):
				continue
			if _doodad_lane_fits(room, lane, start, end, last) and _doodad_push_fits(room, lane, -wall, start, end, last):
				open.append(wall)
	var lane_at: int = -1
	var push: int = 0
	if not open.is_empty() and (lanes.is_empty() or row_rng.randf() < config.doodad_wall_lane_share):
		var wall: int = open[0] if open.size() == 1 else open[row_rng.randi_range(0, open.size() - 1)]
		lane_at = layout.outer_lane(wall)
		push = -wall
	elif not lanes.is_empty():
		var pick: int = rng.randi_range(0, lanes.size() - 1)
		var room_sides: Array = sides[pick]
		lane_at = lanes[pick]
		push = room_sides[rng.randi_range(0, room_sides.size() - 1)]
	else:
		return none
	# Its look's seed counts the zone doodads before it, not a treasure stash's (task I4), whose look seeds are its own.
	var before: int = 0
	for d: Dictionary in layout.doodads:
		before += 0 if d.has("stash") else 1
	var out: Array[Dictionary] = []
	for i: int in count:
		var at: float = start + i * step
		var entry := {"lane": lane_at, "start": at, "end": at + length, "size": size, "side": push,
			"seed": hash([config.level_seed, "doodad", before + i])}
		if count > 1:
			entry["row"] = [start, end]
			entry["look"] = hash([config.level_seed, "doodad", before])
		layout.doodads.append(entry)
		out.append(entry)
	return out


## True if a doodad (or a row) from `start` to `end`, its last one's front at `last` (`start` for one), may stand in
## `lane` whichever way it pushes (task L6; _place_doodads' rules, `room` its keep-outs): its own lane holds nothing
## from doodad_lane_room() before its push to the level's spacing past its end (doodad_after: what it hides), no
## other doodad either, nor is it one a rule keeps; both lanes beside it hold nothing from that room before its push
## until the reaction after a push from its last front (doodad_landing: a caught corner pushes back the way the
## runner came, task L6's review), or that room past its end if later; no doodad that ends closer than the level's
## spacing before it stands in its lane or a lane beside it (no slalom); and, where the danger density pass ran, it
## keeps the ground route that pass's pieces left (DangerDensity.doodad_ok).
func _doodad_lane_fits(room: DoodadRoom, lane: int, start: float, end: float, last: float) -> bool:
	var lead: float = doodad_lead_for(tuning)
	var from: float = start - lead - doodad_lane_room()
	var hidden: float = end + doodad_after(end)
	if _hits_any(room.lanes[lane], from, hidden) or _lane_kept(room.keeps, lane, Vector2(start - lead, hidden)):
		return false
	var beside: float = maxf(end + doodad_lane_room(), doodad_landing(last))
	for other: int in [lane - 1, lane + 1]:
		if other >= 0 and other < layout.lane_count and _hits_any(room.lanes[other], from, beside):
			return false
	for d: Dictionary in layout.doodads:
		# A treasure stash's doodads stand under its ceiling, which every doodad keeps off in every lane.
		if d.has("stash") or absi(int(d["lane"]) - lane) > 1:
			continue
		var span: Vector2 = LevelLayout.doodad_extent(d)
		if (span.y <= start and start - span.y < doodad_after(span.y)) \
				or (span.x >= end and span.x - end < doodad_after(end)) or (span.x < end and span.y > start):
			return false
	return danger_density_plan == null or DangerDensity.doodad_ok(self, lane, start, end)


## True if a doodad (or a row) from `start` to `end` in `lane`, its last one's front at `last`, may push into the lane
## on `side` (task L6): a lane of the track that holds nothing from doodad_lane_room() before its push until the
## reaction after a push from its last front (doodad_landing), or that room past its end if later, and that no rule
## keeps there (a hover truck's, a floor cut's).
func _doodad_push_fits(room: DoodadRoom, lane: int, side: int, start: float, end: float, last: float) -> bool:
	var into: int = lane + side
	if into < 0 or into >= layout.lane_count:
		return false
	var lead: float = doodad_lead_for(tuning)
	var landed: float = maxf(end + doodad_lane_room(), doodad_landing(last))
	if _hits_any(room.lanes[into], start - lead - doodad_lane_room(), landed):
		return false
	return not _lane_kept(room.keeps, into, Vector2(start - lead, landed))


## True if one of `lane_keeps` ({lane, from, to}) keeps `lane` anywhere in `span`.
static func _lane_kept(lane_keeps: Array[Dictionary], lane: int, span: Vector2) -> bool:
	for k: Dictionary in lane_keeps:
		if int(k["lane"]) == lane and float(k["from"]) <= span.y and float(k["to"]) >= span.x:
			return true
	return false


## What zone doodads keep off in every lane (task L6: what the enemies' and the level's own rules keep there; the
## rest they keep lane by lane, doodad_lane_busy), as stretches of the track: every enemy's stretch as the fill pass
## keeps it (_enemy_keep_out: its attack as the runner closes in, which its own fairness checks hold back while a
## doodad stands anywhere along it, CyborgGun.path_clear, Octodog.window_clear, Resonator.pulse_clear, the drone's
## barrage, the hover truck's cannon; or what its rules keep for it: a drone wave until its first pad, a hover
## truck's shortest stay, a Resonator's visit, a Gilded Sentinel's window; or what its rules keep doodads off,
## doodad_enemy_keep_out: a Resonator's visit and the waits its rules leave it after), every floor cut's window
## (FloorCutPlan.window: GDD §9.9, nothing else goes on meanwhile), every dash wall's footprint (DashWallRules
## .footprint), every ceiling from its start to the end of its landing zone (the chase camera rides below a
## ceiling, lower than a doodad's top) and every pad's zone, the level's quiet stretches, each wider gap's zone
## (WideGapPlacement.keep_outs: from its take-off margin to its landing margin, the only demand there), and what
## the rules keep from doodads in every lane: `static func doodad_keep_outs(gen: LevelGenerator) ->
## Array[Dictionary]` on a feature's rules script, entries {from, to} (a Bad Dream's chase, a Gilded Sentinel's
## strike, a dash wall's footprint, a wall-run gap's clear stretch, a treasure stash's floor). Entries that also
## name a lane ({lane, from, to}: a hover truck's, for its whole stay) go into `lane_keeps`, with each floor cut's
## lane over its lane window (FloorCutPlan.lane_window): no doodad stands in that lane there, nor pushes into it.
## The rules' calm stretches ({from, to, calm: true}: an Enforcer Truck's showing window, task C6c) go into `calm`
## instead: no doodad nor its push's lead stands in one, but they keep no room around them.
func doodad_keep_outs(_patterns: Array = [], lane_keeps: Array[Dictionary] = [], calm: Array[Vector2] = []) \
		-> Array[Vector2]:
	var out: Array[Vector2] = []
	var hooks: Dictionary = {}
	for e: Dictionary in layout.enemies:
		var k: Vector2 = doodad_enemy_keep_out(e, hooks)
		if k.y >= k.x:
			out.append(k)
	for c: Dictionary in layout.cuts:
		out.append(FloorCutPlan.window(c, speed))
		var span: Vector2 = FloorCutPlan.lane_window(c)
		lane_keeps.append({"lane": int(c["lane"]), "from": span.x, "to": span.y})
	for dw: Dictionary in layout.dash_walls:
		out.append(DashWallRules.footprint(self, dw))
	for h: Dictionary in layout.hulls:
		out.append(Vector2(float(h["start"]), zones.landing_zone(h).y))
	for p: Dictionary in layout.pads:
		out.append(zones.pad_zone(float(p["at"])))
	out.append_array(quiet_stretches())
	out.append_array(WideGapPlacement.keep_outs(self))
	for k: Dictionary in rules_doodad_keep_outs():
		if k.has("lane"):
			lane_keeps.append(k)
		elif bool(k.get("calm", false)):
			calm.append(Vector2(float(k["from"]), float(k["to"])))
		else:
			out.append(Vector2(float(k["from"]), float(k["to"])))
	return out


## What each lane holds that a zone doodad keeps off in that lane (task L6; _place_doodads), one Array[Vector2] of
## stretches a lane, in lane order: its holes and fences, its speed pads and anti-grav pads, a ramp in the outermost
## lane on its side from its foot to where the wall run it launches drops the runner back (RampLaunch), a floor
## cut's lane window (FloorCutPlan.lane_window), and the floor its enemies use (enemy_floor_span: a floor enemy's in
## its lane, a wall enemy's that uses the floor in the outermost lane by its wall).
func doodad_lane_busy() -> Array:
	var out: Array = []
	for lane: int in layout.lane_count:
		var spans: Array[Vector2] = []
		out.append(spans)
	var add := func(lane: int, span: Vector2) -> void:
		if lane >= 0 and lane < layout.lane_count and span.y >= span.x:
			var spans: Array[Vector2] = out[lane]
			spans.append(span)
	var half: float = tuning.fence_depth * 0.5
	for g: Dictionary in layout.gaps:
		add.call(int(g["lane"]), Vector2(float(g["start"]), float(g["end"])))
	for f: Dictionary in layout.fences:
		add.call(int(f["lane"]), Vector2(float(f["at"]) - half, float(f["at"]) + half))
	for p: Dictionary in layout.speed_pads:
		add.call(int(p["lane"]), Vector2(float(p["at"]), float(p["at"]) + tuning.speed_pad_length))
	for p: Dictionary in layout.pads:
		add.call(int(p["lane"]), Vector2(float(p["at"]), float(p["at"]) + tuning.pad_length))
	for r: Dictionary in layout.ramps:
		add.call(layout.outer_lane(int(r["side"])), Vector2(float(r["at"]),
			maxf(ramp_launch(r).end(), float(r["at"]) + tuning.ramp_length)))
	for c: Dictionary in layout.cuts:
		add.call(int(c["lane"]), FloorCutPlan.lane_window(c))
	for e: Dictionary in layout.enemies:
		if not enemy_uses_floor(e):
			continue
		var lane: int = int(e.get("lane", -1))
		if (lane < 0 or lane >= layout.lane_count) and int(e.get("side", 0)) != 0:
			lane = layout.outer_lane(int(e["side"]))
		add.call(lane, enemy_floor_span(e, pace))
	return out


## The room a zone doodad keeps in the lanes beside it before its push's lead and past its end, and in its own
## lane before its push's lead (metres, at run speed; task L6): a lane switch (MovementTuning.lane_switch_time) and
## DOODAD_LANE_MARGIN, so a runner beside it can switch into its lane right after it, or a runner in its lane out of
## it right before its push, with clear floor on both lanes.
func doodad_lane_room() -> float:
	return tuning.lane_switch_time * speed + DOODAD_LANE_MARGIN


## Where the reaction ends that a runner a zone doodad with its front at `front` pushes gets after landing in a lane
## beside it (task L6, and its review: a jump at one is pushed in the air): past its front, the push on the floor
## (MovementTuning.doodad_push_time at run speed) or a full jump (`jump_distance`, MovementTuning.jump_distance at the
## level's speed: a runner who jumped at it, as late as at its front, comes down that far on), whichever is longer,
## and LevelConfig.doodad_reaction_seconds at run speed after that. Both lanes beside it stay clear until then (a
## caught corner pushes back the way the runner came; _doodad_lane_fits, _doodad_push_fits), a row's until the
## reaction after its last one's.
func doodad_landing(front: float) -> float:
	return front + maxf(tuning.doodad_push_time * speed, jump_distance) + config.doodad_reaction_seconds * speed


## How far past its front a zone doodad (or a row) `extent` metres long keeps what the rules keep in every lane off
## (task L6; doodad_keep_outs): doodad_lane_room() past its end, so a runner beside it can switch into its lane before
## any of it; an attack beginning there comes with its own warning, and the enemies' own checks hold it back while
## the doodad is in its reach.
func doodad_reach(extent: float) -> float:
	return extent + doodad_lane_room()


## Where a zone doodad by side wall `side` (in its outermost lane; task L3, the owner, October 9, 2026: "doodads
## prefer the lane next to the side wall when it's open, without costing gameplay: not where the generator already
## has something on that part of the wall or needs it open") may not stand: stretches its own [start, end] (a
## row's whole stretch) never reaches. Around everything on that wall, LevelConfig.doodad_wall_clear_seconds at
## run speed either side: a sign, a wall enemy (whatever the fill pass keeps for it, a window cyborg's window, a
## Gilded Sentinel's wall section: WallFencePlacement.sentinel_wall_section), a ramp on that wall from its foot to
## the end of the longest wall run it launches (WallFencePlacement.ramp_run_end: claws, a speed pad's boost), a
## wall-run gap's lit wall (WallRunGapPlacement.wall_keep_outs_for: the way across), a wall fence's drop window
## (WallFencePlacement.drop_window: a wall runner who drops off before it lands there), and a side wall gap from its
## start to doodad_wall_drop() past it or its end, whichever is later (a wall runner drops off at its start into
## the outer lane: never onto a doodad, and no doodad stands by a missing wall); where a level brings in wall
## fences (its feature_starts give `wall_fences` or `wall_fences_partial` a start), from that start to
## WallFenceTuning.intro_seconds past it with the drop windows there, on both walls (the introduction comes there,
## on either wall: WallFencePlacement._introduce); and, with no margin of its own, a dash wall's wall route on
## either wall (DashWallRules.wall_keep_outs: a runner on a side wall passes it; it lies in the wall's footprint,
## which every doodad keeps off in every lane, doodad_keep_outs). The rest of the doodad's rules keep its own lane
## and the lane beside it clear around it (task L6: _doodad_lane_fits, _doodad_push_fits; no ramp in its lane, the
## lane beside it free), so no wall run is launched by it and none is needed there: free entry from its lane only
## waits until it's past. A level's wall fences and side wall gaps come after the doodads and keep off it in turn
## (WallFencePlacement.keep_outs, WallGapPlacement.keep_outs).
func wall_lane_keep_outs(side: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var clear: float = config.doodad_wall_clear_seconds * speed
	for s: Dictionary in layout.signs:
		if int(s["side"]) == side:
			out.append(Vector2(float(s["start"]) - clear, float(s["end"]) + clear))
	var hooks: Dictionary = {}
	var wt := EnemyDirector.tuning_for("window_cyborg") as WindowCyborgTuning
	var window: float = (wt.window_length if wt != null else 1.5) * 0.5
	for e: Dictionary in layout.enemies:
		if int(e.get("side", 0)) != side:
			continue
		var at: float = float(e["at"])
		var k: Vector2 = _enemy_keep_out(e, hooks)
		out.append(Vector2(minf(k.x, at - window) - clear, maxf(k.y, at + window) + clear))
		if String(e.get("type", "")) == "gilded_sentinel":
			var section: Vector2 = WallFencePlacement.sentinel_wall_section(self, e)
			out.append(Vector2(section.x - clear, section.y + clear))
	for r: Dictionary in layout.ramps:
		if int(r["side"]) == side:
			out.append(Vector2(float(r["at"]) - clear, WallFencePlacement.ramp_run_end(self, r) + clear))
	for k: Vector2 in WallRunGapPlacement.wall_keep_outs_for(layout, speed, side, false):
		out.append(Vector2(k.x - clear, k.y + clear))
	# A dash wall's wall route lies in its footprint, which every doodad keeps its push's lead and the level's spacing
	# from already (doodad_keep_outs; the walls after the doodads keep off them so, DashWallRules.doodad_span).
	for k: Vector2 in DashWallRules.wall_keep_outs(self):
		out.append(k)
	for w: Dictionary in layout.wall_fences:
		if int(w["side"]) == side:
			var drop: Vector2 = WallFencePlacement.drop_window(self, float(w["at"]))
			out.append(Vector2(drop.x - clear, drop.y + clear))
	var fences: WallFenceTuning = WallFencePlacement.tuning()
	for feature: String in [WallFencePlacement.FEATURE, WallFencePlacement.PARTIAL]:
		if config.has_feature(feature) and config.feature_starts.has(feature):
			var from: float = feature_start(feature)
			var by: float = from + fences.intro_seconds * speed
			out.append(Vector2(WallFencePlacement.drop_window(self, from, fences).x - clear,
				WallFencePlacement.drop_window(self, by, fences).y + clear))
	var reach: float = doodad_wall_drop()
	for g: Dictionary in layout.wall_gaps:
		if int(g["side"]) == side:
			out.append(Vector2(float(g["start"]) - clear, maxf(float(g["end"]), float(g["start"]) + reach) + clear))
	return out


## How far past where a wall runner drops off a side wall (a wall gap's start) they may come down in the outer lane
## and still meet a doodad there head-on, its push's lead before it (metres, at run speed; task L3): the fall from
## the highest wall run (MovementTuning.wall_max_height, at the descent's heavier gravity) plus doodad_lead_for.
func doodad_wall_drop() -> float:
	var fall: float = sqrt(2.0 * tuning.wall_max_height / maxf(tuning.gravity() * tuning.fall_gravity_multiplier, 0.01))
	return fall * speed + doodad_lead_for(tuning)


## True if a stretch of `spans` (Vector2(from, to)) reaches into [from, to].
static func _hits_any(spans: Array[Vector2], from: float, to: float) -> bool:
	for k: Vector2 in spans:
		if k.x <= to and k.y >= from:
			return true
	return false


## What the level's features' rules keep zone doodads off (`static func doodad_keep_outs(gen:
## LevelGenerator) -> Array[Dictionary]` on a feature's rules script), in the order of the features:
## the lane-bound attacks while they run, {from, to} in every lane (a Bad Dream's chase; a dash wall's
## footprint, task H7a) or {lane, from, to} in one (a hover truck's lane for its whole stay), and calm stretches, {from, to, calm: true} in
## every lane (an Enforcer Truck's showing window, task C6c): nothing a later pass adds stands or attacks
## in one, but nothing keeps a spacing from it. Floor cuts keep off them too (cut_problem).
func rules_doodad_keep_outs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for feature: String in config.features:
		var path: String = RULES_DIR.path_join("%s_rules.gd" % feature)
		if not ResourceLoader.exists(path):
			continue
		var script := load(path) as GDScript
		if script == null or not script.has_method("doodad_keep_outs"):
			continue
		for k: Dictionary in script.call("doodad_keep_outs", self):
			out.append(k)
	return out


## The level's features' rules scripts that keep wall enemies off stretches of their wall (`static func
## on_wall_section(gen: LevelGenerator, type: String, side: int, at: float, params: Dictionary) -> bool` on
## a feature's rules script: a Gilded Sentinel's wall section), in the order of the features. A pass that
## adds wall enemies after the rules asks them (DangerDensity._type_rules_ok, task K4).
func wall_section_rules() -> Array[GDScript]:
	var out: Array[GDScript] = []
	for feature: String in config.features:
		var path: String = RULES_DIR.path_join("%s_rules.gd" % feature)
		if not ResourceLoader.exists(path):
			continue
		var script := load(path) as GDScript
		if script != null and script.has_method("on_wall_section"):
			out.append(script)
	return out


## How far before a doodad's front its push begins (_place_doodads): the stretch its push crosses into the
## neighbouring lane, the doodad_push_time at the level's run speed (`t`'s).
static func doodad_lead_for(t: MovementTuning) -> float:
	return t.doodad_push_time * t.run_speed


## The level's spacing between two patterns at `at` (metres, at run speed). After a doodad that ends at `at`
## its own lane holds nothing for this long (_place_doodads, task L6: what it hides behind it comes no sooner than
## between two patterns), and the next doodad that close stands two lanes away at least. The danger density pass
## and a treasure stash take their spacing from it too.
func doodad_after(at: float) -> float:
	return _spacing_seconds(at, difficulty_at(clampf(at / layout.length, 0.0, 1.0))) * speed


# --- Floor cuts (task B4; GDD §9.9, the Buzz Overdrive's) -----------------------------------------

## Adds floor cut `cut` (a LevelLayout.cuts entry, FloorCutPlan.make) where GDD §9.9's limits allow it
## (cut_problem). Returns true if it was added. A rules script that plans cuts clears the way first
## (CutPlacement, scripts/enemies/cut_placement.gd) and adds the cut's cause as an entry at the cut's
## `end`, in its lane (the stand-in's floor_cutter_rules.gd; task C2's saw).
func add_cut(cut: Dictionary) -> bool:
	if cut_problem(cut) != "":
		return false
	layout.cuts.append(cut)
	return true


## Why floor cut `cut` can't go where it lies in `p_layout` (the level's by default), or "" if it can.
## GDD §9.9's limits and the readability rules:
## - it lies in a real lane, between the level's run-up and its end-clear stretch, its warning before
##   its charge and both before its cause's spot, its stretch around where it meets the player;
## - one at a time: no other cut's window (FloorCutPlan.window: from its warning, or where its cause
##   sets off, to its end) reaches this one's;
## - never a lane holding a ramp, a pad or the safe landing zone after a ceiling (CeilingZones.cut_clear:
##   no landing zone over its lane and no pad's zone in its lane reaches its lane window; no ramp in
##   its lane, nor the wall run it launches, until it drops the player back);
## - nothing else in its lane over its lane window (FloorCutPlan.lane_window: from the warning to past
##   its cause's spot): no hole, fence, speed pad or zone doodad, and no other cut;
## - the other lanes stay whole enough along its stretch: holes (and other cuts) in at most
##   lane_count - 1 - whole_lanes_for_cut() of them (GDD §9.9: on 3 lanes two lanes always stay whole);
## - nothing else goes on meanwhile: no enemy's keep-out (what the fill pass keeps for it,
##   _enemy_keep_out) reaches its attack window (FloorCutPlan.attack_window: from its warning; a cause
##   on its way before it, a Buzz Overdrive rolling ahead, attacks nobody yet), bar its own cause (an
##   entry at its `end` in its lane) and, on a cut with company (task L2), its own company cyborgs, which
##   keep the company's rules instead (BuzzCompanyPlacement: beside its escape lane, holding their fire),
##   nor does a lane-bound attack the rules keep doodads off
##   (rules_doodad_keep_outs, read from the level's own enemies: a Bad Dream's chase in any lane, a
##   hover truck's stay in its lane), nor a wall fence's drop window over its whole window (task B5: a
##   boss arena's wall fences; a level's come after its cuts and keep off them, WallFencePlacement);
## - a player in its lane when the warning starts can leave it (cut_escape_clear).
## Wall runners and ceiling riders are safe without a rule: the cut is a hole in its own lane only.
## DESIGN-TBD (docs/questions/b4.md): keeping everything else off a cut's whole window, and letting
## cuts run in the outer lanes (beside a wall runner).
func cut_problem(cut: Dictionary, p_layout: LevelLayout = null) -> String:
	var lay: LevelLayout = p_layout if p_layout != null else layout
	var n: int = lay.lane_count
	var lane: int = int(cut.get("lane", -1))
	if lane < 0 or lane >= n:
		return "lane %d out of range" % lane
	var start: float = float(cut["start"])
	var end: float = float(cut["end"])
	var meet: float = FloorCutPlan.meet(cut, speed)
	var charge_at: float = FloorCutPlan.charge_at(cut)
	var lane_span: Vector2 = FloorCutPlan.lane_window(cut)
	var span: Vector2 = FloorCutPlan.window(cut, speed)
	var attack: Vector2 = FloorCutPlan.attack_window(cut, speed)
	if float(cut["speed"]) <= 0.0 or float(cut["charge"]) <= 0.0 or float(cut["warn"]) < float(cut["charge"]) \
			or not (start < meet and meet < end and charge_at < meet):
		return "its warning, charge, stretch and meeting point don't line up"
	if lane_span.x < config.start_clear_distance or span.y > lay.length - config.end_clear_distance:
		return "it doesn't fit between the run-up and the end-clear stretch"
	var kept: Vector2 = kept_for_extended(minf(span.x, attack.x), maxf(span.y, attack.y))
	if kept.y > kept.x:
		return "an extended wall run's stretch is kept there"
	for other: Dictionary in lay.cuts:
		if is_same(other, cut):
			continue
		var w: Vector2 = FloorCutPlan.window(other, speed)
		if w.x <= span.y and w.y >= span.x:
			return "another cut is on meanwhile (one at a time)"
	if not zones.cut_clear(lay, cut):
		return "a ceiling's landing zone or a pad's zone is in its lane"
	for r: Dictionary in lay.ramps:
		if lay.outer_lane(int(r["side"])) == lane and float(r["at"]) <= lane_span.y \
				and maxf(ramp_launch(r).end(), float(r["at"]) + tuning.ramp_length) >= lane_span.x:
			return "a ramp (or the wall run it launches) is in its lane"
	var half: float = tuning.fence_depth * 0.5
	for g: Dictionary in lay.gaps:
		if int(g["lane"]) == lane and float(g["start"]) <= lane_span.y and float(g["end"]) >= lane_span.x:
			return "a hole is in its lane"
	for f: Dictionary in lay.fences:
		if int(f["lane"]) == lane and float(f["at"]) - half <= lane_span.y and float(f["at"]) + half >= lane_span.x:
			return "a fence is in its lane"
	for p: Dictionary in lay.speed_pads:
		if int(p["lane"]) == lane and float(p["at"]) <= lane_span.y and float(p["at"]) + tuning.speed_pad_length >= lane_span.x:
			return "a speed pad is in its lane"
	if lay.doodad_between(lane_span.x, lane_span.y, lane):
		return "a zone doodad is in its lane"
	var holed: Dictionary = {}
	for g: Dictionary in lay.gaps:
		if int(g["lane"]) != lane and float(g["start"]) <= end and float(g["end"]) >= start:
			holed[int(g["lane"])] = true
	for other: Dictionary in lay.cuts:
		if not is_same(other, cut) and float(other["start"]) <= end and float(other["end"]) >= start:
			if int(other["lane"]) == lane:
				return "another cut's stretch is in its lane"
			holed[int(other["lane"])] = true
	if holed.size() > n - 1 - whole_lanes_for_cut(n):
		return "%d other lanes hold holes along it (%d must stay whole)" % [holed.size(), whole_lanes_for_cut(n)]
	var hooks: Dictionary = {}
	for e: Dictionary in lay.enemies:
		if int(e.get("lane", -1)) == lane and absf(float(e["at"]) - end) < 0.01:
			continue  # Its own cause, waiting at its end.
		if cut.has(BuzzCompanyPlacement.CUT_KEY) and BuzzCompanyPlacement.is_company(e) \
				and absf(float((e["params"] as Dictionary)[BuzzCompanyPlacement.PARAM]) - end) < 0.01:
			continue  # Task L2: its own company, which keeps the company's rules (BuzzCompanyPlacement).
		var k: Vector2 = _enemy_keep_out(e, hooks)
		if k.x <= attack.y and k.y >= attack.x:
			return "an enemy (%s at %.0f) is about meanwhile" % [e.get("type", "?"), float(e["at"])]
	for k: Dictionary in rules_doodad_keep_outs():
		if (not k.has("lane") or int(k["lane"]) == lane) and float(k["from"]) <= attack.y and float(k["to"]) >= attack.x:
			return "an attack runs meanwhile (%.0f-%.0f)" % [float(k["from"]), float(k["to"])]
	var wall_fence: String = _wall_fence_in(lay, span)
	if wall_fence != "":
		return wall_fence
	if not cut_escape_clear(cut, lay):
		return "no room to leave its lane after the warning"
	return ""


## How many lanes besides a floor cut's own stay whole along its stretch at `lanes` lanes (GDD §9.9: on
## 3 lanes two lanes always stay whole, every lane but the cut's; on more, all but
## LevelConfig.cut_holes_beside of them, and never fewer than two).
func whole_lanes_for_cut(lanes: int) -> int:
	if lanes <= 3:
		return lanes - 1
	return maxi(lanes - 1 - config.cut_holes_beside, mini(2, lanes - 1))


## True if a player in floor cut `cut`'s lane when its warning starts can leave it in time (GDD §9.9:
## "leave its lane before it arrives"): from LevelConfig.cut_reaction_seconds after the warning starts
## until the cut is CUT_CONTACT_METRES from them, a neighbouring lane has a stretch clear of holes,
## fences, pads, speed pads, ramps, zone doodads and other cuts long enough to switch into it (a lane
## switch at run speed, CUT_SWITCH_MARGIN either side). Its own lane is clear over all of it
## (cut_problem). In `p_layout` (the level's by default).
func cut_escape_clear(cut: Dictionary, p_layout: LevelLayout = null) -> bool:
	var lay: LevelLayout = p_layout if p_layout != null else layout
	var lane: int = int(cut["lane"])
	var r: float = FloorCutPlan.ratio(cut, speed)
	var from: float = FloorCutPlan.warn_at(cut) + config.cut_reaction_seconds * speed
	# The last spot from which the player is out of the lane before the cut's front is CUT_CONTACT_METRES
	# away: the front is at end - (p - charge_at) * r.
	var to: float = (float(cut["end"]) + r * FloorCutPlan.charge_at(cut) - CUT_CONTACT_METRES) / (1.0 + r)
	var need: float = tuning.lane_switch_time * speed + 2.0 * CUT_SWITCH_MARGIN
	for side: int in [-1, 1]:
		var other: int = lane + side
		if other < 0 or other >= lay.lane_count:
			continue
		var busy: Array[Vector2] = _lane_busy(lay, other)
		for free: Vector2 in free_stretches(busy, from, to):
			if free.y - free.x >= need:
				return true
	return false


## The stretches of `lane` in `lay` where a player can't switch in: holes, fences, pads, speed pads,
## ramps, zone doodads (a row whole, the spaces between its doodads too: task L3, LevelLayout.doodad_extent) and
## floor cuts' lane windows, each with CUT_SWITCH_MARGIN around it.
func _lane_busy(lay: LevelLayout, lane: int) -> Array[Vector2]:
	var m: float = CUT_SWITCH_MARGIN
	var half: float = tuning.fence_depth * 0.5
	var out: Array[Vector2] = []
	for g: Dictionary in lay.gaps:
		if int(g["lane"]) == lane:
			out.append(Vector2(float(g["start"]) - m, float(g["end"]) + m))
	for f: Dictionary in lay.fences:
		if int(f["lane"]) == lane:
			out.append(Vector2(float(f["at"]) - half - m, float(f["at"]) + half + m))
	for p: Dictionary in lay.pads:
		if int(p["lane"]) == lane:
			out.append(Vector2(float(p["at"]) - m, float(p["at"]) + tuning.pad_length + m))
	for p: Dictionary in lay.speed_pads:
		if int(p["lane"]) == lane:
			out.append(Vector2(float(p["at"]) - m, float(p["at"]) + tuning.speed_pad_length + m))
	for rp: Dictionary in lay.ramps:
		if lay.outer_lane(int(rp["side"])) == lane:
			out.append(Vector2(float(rp["at"]) - m, float(rp["at"]) + tuning.ramp_length + m))
	for d: Dictionary in lay.doodads:
		if int(d["lane"]) == lane:
			var span: Vector2 = LevelLayout.doodad_extent(d)
			out.append(Vector2(span.x - m, span.y + m))
	for c: Dictionary in lay.cuts:
		if int(c["lane"]) == lane:
			var w: Vector2 = FloorCutPlan.lane_window(c)
			out.append(Vector2(w.x - m, w.y + m))
	return out


# --- Wall fences (task B5; GDD §9.1) --------------------------------------------------------------

## Places the level's wall fences (LevelLayout.wall_fences; GDD §9.1: full-height ones from Marketplace
## 2, partial ones over the low or the high part of the wall from the Corporate zone), after the zone
## doodads and before the credits, from a random stream of their own (WallFencePlacement has the rules):
## they only add to the walls, so the rest of a level comes out exactly as it does without them, and a
## level without the `wall_fences` and `wall_fences_partial` features draws nothing and is built byte
## for byte as before. Then the danger density pass's wall half adds its share more by the same rules
## (DangerDensity.apply_wall_fences; nothing with the level's danger_density_increase at 0).
func _place_wall_fences() -> void:
	if config.has_feature(WallFencePlacement.FEATURE) or config.has_feature(WallFencePlacement.PARTIAL):
		WallFencePlacement.place(self)
		danger_density_result = DangerDensity.apply_wall_fences(self, danger_density_result)


## Why wall fence `entry` (WallFencePlan.make) can't stand where it lies in `p_layout` (the level's by
## default), or "" if it can (WallFencePlacement.problem: its wall's signs, window cyborgs, wall vents
## and ramps, the outer lane beside it, floor cuts and big attacks meanwhile, other wall fences).
func wall_fence_problem(entry: Dictionary, p_layout: LevelLayout = null) -> String:
	return WallFencePlacement.problem(self, entry, p_layout)


## What the fill pass keeps off around enemy entry `e` (fill_keep_outs: its rules script's keep_out, or
## from FILL_ENEMY_LEAD_SECONDS before it to the end of the floor it uses), for rules that keep off
## enemies the same way (WallFencePlacement: big attacks). `hooks` caches each type's rules script.
func enemy_keep_out(e: Dictionary, hooks: Dictionary = {}) -> Vector2:
	return _enemy_keep_out(e, hooks)


## What zone doodads keep off around enemy entry `e` in every lane (doodad_keep_outs; task L6): its rules script's
## `static func doodad_keep_out(gen: LevelGenerator, e: Dictionary) -> Vector2` where it has one (a Resonator's: its
## visit and the waits its rules leave it after, ResonatorRules.doodad_keep_out), else what the fill pass keeps
## (enemy_keep_out). Only the doodads ask it: every other pass keeps what the fill pass keeps. `hooks` caches each
## type's rules script.
func doodad_enemy_keep_out(e: Dictionary, hooks: Dictionary = {}) -> Vector2:
	var type: String = String(e.get("type", ""))
	var key: String = "doodad:" + type
	if not hooks.has(key):
		var path: String = RULES_DIR.path_join("%s_rules.gd" % type)
		var script: GDScript = load(path) as GDScript if ResourceLoader.exists(path) else null
		hooks[key] = script if script != null and script.has_method("doodad_keep_out") else null
	if hooks[key] != null:
		return (hooks[key] as GDScript).call("doodad_keep_out", self, e)
	return _enemy_keep_out(e, hooks)


## Why a floor cut whose window is `span` can't run in `lay` because of a wall fence there: "" if no wall
## fence's drop window (WallFencePlacement.drop_window) reaches it (cut_problem).
func _wall_fence_in(lay: LevelLayout, span: Vector2) -> String:
	if lay.wall_fences.is_empty():
		return ""
	var t: WallFenceTuning = WallFencePlacement.tuning()
	for w: Dictionary in lay.wall_fences:
		var drop: Vector2 = WallFencePlacement.drop_window(self, float(w["at"]), t)
		if drop.x <= span.y and drop.y >= span.x:
			return "a wall fence stands meanwhile (at %.0f)" % float(w["at"])
	return ""


# --- Enemy rules ---------------------------------------------------------------

## Runs the rules scripts in the order of the level's features. A script may declare
## `const RUN_AFTER: Array[String] = [...]`: it then runs after the rules of those features whenever
## the level has them, whatever their order in the list (the host rules plan the Bad Dream's pads
## around the drones' pad schedule).
func _apply_enemy_rules() -> void:
	var pending: Array[Array] = []
	for feature: String in config.features:
		var path: String = RULES_DIR.path_join("%s_rules.gd" % feature)
		if not ResourceLoader.exists(path):
			continue
		var script := load(path) as GDScript
		if script != null and script.has_method("apply"):
			pending.append([feature, script])
	while not pending.is_empty():
		var next: int = 0
		for i: int in pending.size():
			if not _waits_for_others(pending, i):
				next = i
				break
		var item: Array = pending.pop_at(next)
		(item[1] as GDScript).call("apply", self)


## True if the rules at `index` must wait: its RUN_AFTER names a feature whose rules are still to run.
static func _waits_for_others(pending: Array[Array], index: int) -> bool:
	var after: Variant = (pending[index][1] as GDScript).get_script_constant_map().get("RUN_AFTER", [])
	if not (after is Array):
		return false
	for j: int in pending.size():
		if j != index and (after as Array).has(pending[j][0]):
			return true
	return false


# --- Credits (GDD §7) ------------------------------------------------------------

## Credits a pattern places explicitly: {kind: "credits", surface: "floor" | "ceiling" | "wall",
## lanes | side, count, spacing, value, height}.
func _place_credit_element(element: Dictionary, at: float, prev_lanes: Array[int], prev_side: int) -> void:
	var surface: String = String(element.get("surface", "floor"))
	var count: int = int(element.get("count", 5))
	var spacing: float = metres(float(element.get("spacing", config.credit_trail_spacing)))
	var value: int = int(element.get("value", 1))
	var height: float = float(element.get("height", 0.7 if surface != "wall" else 2.0))
	if surface == "wall":
		var side: int = _pick_side(String(element.get("side", "same")), prev_side)
		for i: int in count:
			_add_credit(at + i * spacing, "wall", layout.outer_lane(side), side, height, value)
		return
	var lanes: Array[int] = _pick_lanes(element.get("lanes", {"mode": "same"}), prev_lanes)
	if lanes.is_empty():
		lanes = _pick_lanes({"mode": "random", "count": 1}, prev_lanes)
	for lane: int in lanes:
		for i: int in count:
			_add_credit(at + i * spacing, surface, lane, 0, height, value)


func _add_credit(at: float, surface: String, lane: int, side: int, height: float, value: int,
		risky: bool = false) -> void:
	layout.credits.append({"at": at, "surface": surface, "lane": lane, "side": side,
		"height": height, "value": value, "risky": risky})


func _place_credits() -> void:
	var rng: RandomNumberGenerator = rng_for("credits")
	_place_trails(rng)
	_place_gap_credits(rng)
	_place_fence_credits(rng)
	if config.credit_wall_runs:
		_place_wall_run_credits()
	# Task N1 (GDD §7, "Wall-hop credits"): from a random stream of its own, so every other credit comes out as before.
	WallHopPlacement.place(self)
	if config.credit_ceilings:
		_place_ceiling_credits(rng)
	_drop_unsafe_credits()
	layout.credits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["at"] < b["at"])


## Trails of small credits along one lane in the clear stretches between patterns, sometimes
## shifting one lane halfway so the player has to move. Their spacing is stretched by the pace, like
## the patterns', so a trail takes as long to run at any speed. A stretch too short for a full trail
## gets a shorter one, down to LevelConfig.credit_trail_min credits (0: none).
func _place_trails(rng: RandomNumberGenerator) -> void:
	var n: int = layout.lane_count
	var spacing: float = metres(config.credit_trail_spacing)
	var trail_len: float = (config.credit_trail_count - 1) * spacing
	for stretch: Vector2 in _clear_stretches:
		var count: int = config.credit_trail_count
		if stretch.y - stretch.x < trail_len + metres(6.0):
			count = mini(count, floori((stretch.y - stretch.x - metres(6.0)) / spacing) + 1)
			if config.credit_trail_min <= 0 or count < config.credit_trail_min:
				continue
		if rng.randf() >= config.credit_trail_chance:
			continue
		if config.credit_trail_count <= 0:
			continue
		var lane: int = rng.randi_range(0, n - 1)
		var shift: int = 0
		if rng.randf() < 0.35:
			shift = -1 if lane == n - 1 else (1 if lane == 0 else (-1 if rng.randf() < 0.5 else 1))
		var start: float = (stretch.x + stretch.y) * 0.5 - (count - 1) * spacing * 0.5
		for i: int in count:
			var l: int = lane + (shift if i >= count / 2 else 0)
			var d: float = start + i * spacing
			if layout.under_hull(d, l):
				continue
			_add_credit(d, "floor", l, 0, 0.7, 1)


## A richer credit right at a gap's edge and an arc of credits along the jump over it. None for a wall-run gap's
## holes (task J2): no jump crosses one, and an arc over it would lure the runner off the edge.
func _place_gap_credits(rng: RandomNumberGenerator) -> void:
	var done: Dictionary = {}
	for g: Dictionary in layout.gaps:
		if LevelLayout.is_wall_run_hole(g):
			continue
		var key: String = "%.1f" % float(g["start"])
		if uncredited.has(g) or done.has(key) or rng.randf() >= config.credit_gap_chance:
			continue
		done[key] = true
		var lane: int = g["lane"]
		var gap_len: float = g["end"] - g["start"]
		_add_credit(g["start"] - 0.8, "floor", lane, 0, 0.6, 5, true)
		# A jump centred on the gap: takeoff before it, landing after it.
		var takeoff: float = g["start"] - (jump_distance - gap_len) * 0.5
		for i: int in 5:
			var f: float = 0.2 + 0.15 * i
			_add_credit(takeoff + f * jump_distance, "floor", lane, 0, _jump_height_at(f) + 0.5, 1, true)


## A richer credit in a fence's risky spot: above a full fence (reached by jumping it), under a
## gapped one (reached by sliding).
func _place_fence_credits(rng: RandomNumberGenerator) -> void:
	for f: Dictionary in layout.fences:
		if uncredited.has(f) or rng.randf() >= config.credit_fence_chance:
			continue
		var gapped: bool = f["variant"] == "gapped"
		var height: float = 0.25 if gapped else tuning.fence_full_top + 0.6
		_add_credit(f["at"], "floor", f["lane"], 0, height, 5, true)


## Credits along the wall-run path after each ramp (wall_run_credits).
func _place_wall_run_credits() -> void:
	for r: Dictionary in layout.ramps:
		layout.credits.append_array(wall_run_credits(layout, r, tuning, speed))


## The credits along ramp `r`'s wall run in `p_layout`, richer the further along (GDD §7): each where
## the launched player is at that moment (RampLaunch, with the ramp's fading speed boost), 0.3 s apart
## once they're on the wall. The line stops before a sign on that wall. Entries as in
## LevelLayout.credits; `p_speed` is the level's run speed.
static func wall_run_credits(p_layout: LevelLayout, r: Dictionary, p_tuning: MovementTuning,
		p_speed: float) -> Array[Dictionary]:
	var values: Array[int] = [1, 1, 5, 5, 5, 25]
	var side: int = int(r["side"])
	var launch := RampLaunch.of(r, p_tuning, p_speed)
	var out: Array[Dictionary] = []
	for i: int in values.size():
		var t: float = p_tuning.wall_entry_time + 0.3 * (i + 1)
		var d: float = launch.distance_at(t)
		if _sign_near(p_layout, side, d, 1.5):
			break
		out.append({"at": d, "surface": "wall", "lane": p_layout.outer_lane(side), "side": side,
			"height": launch.height_at(t), "value": values[i], "risky": true})
	return out


## A line of credits along the pad's lane on the ceiling and a rich one in its far lane: the lane of
## the ceiling furthest from the pad's (a ceiling over one lane has none; GDD §3, the rider moves only
## within its lanes).
func _place_ceiling_credits(rng: RandomNumberGenerator) -> void:
	for p: Dictionary in layout.pads:
		var hull: Dictionary = {}
		for h: Dictionary in layout.hulls:
			if h["start"] <= p["at"] and h["end"] >= p["at"]:
				hull = h
		if hull.is_empty():
			continue
		var lane: int = p["lane"]
		var d: float = float(p["at"]) + metres(10.0)
		var placed: int = 0
		while d < float(hull["end"]) - metres(8.0) and placed < 10:
			_add_credit(d, "ceiling", lane, 0, 0.6, 1)
			d += metres(4.0)
			placed += 1
		var lanes: Vector2i = layout.hull_lanes(hull)
		if lanes.y > lanes.x:
			var far_lane: int = lanes.x if 2 * lane >= lanes.x + lanes.y else lanes.y
			var far_d: float = lerpf(float(p["at"]), float(hull["end"]), 0.7)
			_add_credit(far_d, "ceiling", far_lane, 0, 0.6, 25 if rng.randf() < 0.7 else 5, true)


## Drops credits that would sit inside a hazard, a zone doodad or a dash wall (task H7a), over a hole the
## player can't reach, or in a floor cut's lane while it's on (they'd lure the player into its way, then
## hang over the gap it leaves). A treasure stash (task I4) holds only its own credits: no other floor credit
## lies in its lane or its walls' between its start and its open end; and no credit hangs on a ceiling by one of
## its fences (in its lane, within CEILING_FENCE_CREDIT_MARGIN).
func _drop_unsafe_credits() -> void:
	var kept: Array[Dictionary] = []
	for c: Dictionary in layout.credits:
		if c["surface"] == "floor":
			var d: float = c["at"]
			var lane: int = c["lane"]
			if lane < 0 or lane >= layout.lane_count:
				continue
			if not bool(c.get("stash", false)) and _in_stash(lane, d):
				continue
			if not c["risky"] and layout.gapped_between(lane, d - 0.5, d + 0.5):
				continue
			if not c["risky"] and _fence_near(lane, d, 1.5):
				continue
			# Inside a zone doodad or a dash wall (or just at its ends; LevelLayout.doodad_between counts a wall
			# in every lane): a trail that runs into one stops there.
			if layout.doodad_between(d - DOODAD_CREDIT_MARGIN, d + DOODAD_CREDIT_MARGIN, lane):
				continue
			if layout.cut_between(d - 0.5, d + 0.5, lane):
				continue
			if d > layout.length - 5.0:
				continue
		elif c["surface"] == "wall":
			if _sign_near(layout, c["side"], c["at"], 1.0):
				continue
			# No wall there to run along (a wall gap): nothing to collect it from.
			if layout.wall_gap_between(float(c["at"]) - 1.0, float(c["at"]) + 1.0, int(c["side"])):
				continue
			# Task L3: none by a zone doodad by its wall (no wall run is lured past one: wall_lane_keep_outs).
			if _doodad_by_wall(int(c["side"]), float(c["at"]), DOODAD_WALL_CREDIT_MARGIN):
				continue
		elif c["surface"] == "ceiling":
			if _ceiling_fence_near(int(c["lane"]), float(c["at"]), tuning.fence_depth * 0.5 + CEILING_FENCE_CREDIT_MARGIN):
				continue
		kept.append(c)
	layout.credits = kept


## True if track distance `d` in `lane` lies in a treasure stash (LevelLayout.stashes; task I4): in its lane or
## either wall's, from its start to its open end (a credit's reach, DOODAD_CREDIT_MARGIN, either side).
func _in_stash(lane: int, d: float) -> bool:
	for s: Dictionary in layout.stashes:
		if absi(lane - int(s["lane"])) <= 1 and d >= float(s["start"]) - DOODAD_CREDIT_MARGIN \
				and d <= float(s["end"]) + DOODAD_CREDIT_MARGIN:
			return true
	return false


## True if a zone doodad stands in the outermost lane by side wall `side` (task L3) within `margin` of track distance
## `d` (beyond its row's ends: LevelLayout.doodad_extent).
func _doodad_by_wall(side: int, d: float, margin: float) -> bool:
	var lane: int = layout.outer_lane(side)
	for dd: Dictionary in layout.doodads:
		if int(dd["lane"]) != lane or dd.has("stash"):
			continue
		var span: Vector2 = LevelLayout.doodad_extent(dd)
		if d >= span.x - margin and d <= span.y + margin:
			return true
	return false


## True if a ceiling fence (LevelLayout.ceiling_fences; task I4) stands in `lane` within `margin` of `d`.
func _ceiling_fence_near(lane: int, d: float, margin: float) -> bool:
	for f: Dictionary in layout.ceiling_fences:
		if int(f["lane"]) == lane and absf(float(f["at"]) - d) < margin:
			return true
	return false


func _fence_near(lane: int, d: float, margin: float) -> bool:
	for f: Dictionary in layout.fences:
		if f["lane"] == lane and absf(f["at"] - d) < margin:
			return true
	return false


static func _sign_near(p_layout: LevelLayout, side: int, d: float, margin: float) -> bool:
	for s: Dictionary in p_layout.signs:
		if s["side"] == side and d >= s["start"] - margin and d <= s["end"] + margin:
			return true
	return false


## Height of a jump from flat ground at fraction `f` (0–1) of its horizontal length.
func _jump_height_at(f: float) -> float:
	var g_up: float = tuning.gravity()
	var g_down: float = g_up * tuning.fall_gravity_multiplier
	var t_up: float = tuning.jump_velocity() / g_up
	var t_down: float = sqrt(2.0 * tuning.jump_height / g_down)
	var t: float = f * (t_up + t_down)
	if t <= t_up:
		return tuning.jump_velocity() * t - 0.5 * g_up * t * t
	var td: float = t - t_up
	return maxf(tuning.jump_height - 0.5 * g_down * td * td, 0.0)
