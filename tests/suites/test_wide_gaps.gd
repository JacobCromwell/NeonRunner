extends TestSuite
## Wider gaps (task G7; owner, October 7, 2026, answering open question 352; GDD §9.13 "Holes": "every level has
## a couple of wider gaps. They're uncommon, still jumpable by the player, and wide enough that an Enforcer
## following the player into one is wrecked"; WideGapPlacement, data/tuning/wide_gaps.tres):
## - Every campaign level at 3, 5 and 6 lanes has its LevelConfig.wide_gaps (2) wider gaps, each longer than an
##   Enforcer Truck hops and no longer than a level's longest jump, nothing else at its take-off or landing
##   (LayoutChecks.check_wide_gaps), and a floor route across it from the clear floor before it (FloorRoute: a
##   full jump with margins at both edges); its counts are printed per level.
## - Never in a boss arena, even one that asks for them; a level that asks for none (quick play, the prototype
##   level) draws nothing; a level builds the same on every attempt.
## - Every filler keeps the fill pass's spacing from every wider gap: on seeds where one of the level's own rows
##   made longer after the fill pass would come nearer a filler than that, the filler goes.
## - Jumpable on real physics with a normal jump (no dash, no pad): at quick play's 18 m/s and at every campaign
##   level's speed, at 3, 5 and 6 lanes, a runner who jumps early, midway or late in its take-off window clears
##   one; one who runs on falls in.
## - An Enforcer Truck following a runner who jumps one is wrecked in it (the player's kill), at 3, 5 and 6
##   lanes, at quick play's speed and at Corporate 2's; it hops a level's ordinary row.
## - Every campaign level with Enforcer Trucks at 3, 5 and 6 lanes: a first Enforcer chase without a wider gap has
##   no clear stretch for a new row of one (prefer_enforcer_chases: preferred, not guaranteed, open question 357;
##   _chase_spot says what that check covers and what it doesn't).
## - Corporate 2 (the Enforcer's first level) at 3, 5 and 6 lanes: the first Enforcer's chase leaves room past its
##   showing window (task C6e: no wider gap before it) at two lane counts at least, and holds a wider gap there at
##   CORPORATE_2_CHASE_LANES (prefer_enforcer_chases), checked both ways: a lane count with room left out of it holds
##   none and has no clear stretch for a new row there. Each one that holds one is played from the level's start by
##   a scripted runner (god mode, grapples) that lines up in one of its hole lanes and jumps it: the truck following
##   is wrecked in it.
## - Task C6e: no wider gap comes in an Enforcer Truck's chase before its showing (from its arrival to its window's
##   end: it would wreck the truck before it has shown itself), and every level keeps its wider gaps.
## - The pass's last way (task K5: WideGapPlacement._add_clearing, for a level the other ways give none): on
##   LAST_RESORT_CASES it places the level's one wider gap, a fair one (as every other), and the Enforcer Trucks'
##   showing windows still hold; on a plain stretch, plain fences in its way go for it, and a pulsing one keeps it
##   from coming.

const EnforcerRules = preload("res://scripts/enemies/enforcer_truck_rules.gd")
const LANES: Array[int] = [3, 5, 6]
## The lane counts at which Corporate 2's first Enforcer chase holds a wider gap past its showing window
## (_test_corporate_2), checked both ways: each listed one holds one and plays it, and every other lane count whose
## chase leaves room past its window holds none and has no clear stretch for a new row there (_chase_spot). 3 lanes
## since task K5 merged task C6e's windows into K4's curve: at 5 lanes the chase past its window is full, and at 6
## its window comes after its bait, at its chase's end, leaving no room. (All three on K4's curve before C6e; 3 and
## 5 on the 15-level curve C6e was built on; K2's 17-level linear curve left 5 lanes out.)
const CORPORATE_2_CHASE_LANES: Array[int] = [3]
## Builds, as {id, lanes, seed}, where the pass's first three ways give the level no wider gap and its last way
## (WideGapPlacement._add_clearing, task K5) places its one: a new row, the holes and plain fences in its way taken
## out. Dead Zone 1 at 5 lanes on seed 9004 (in tests/suites/test_campaign.gd's seed sweep: its only room was an
## Enforcer Truck's chase before its showing, which task C6e keeps every wider gap off) and the Golden Palace at 3
## lanes on seed 9010 (no room anywhere, before C6e too). Each must still need the last way, else re-pin the case.
const LAST_RESORT_CASES: Array[Dictionary] = [{"id": "dead_zone/1", "lanes": 5, "seed": 9004},
	{"id": "golden/3", "lanes": 3, "seed": 9010}]
## Metres between the fences of the plain stretch _test_last_resort_fences lays: less than a wider gap's zone, so
## every spot has one in its way.
const FENCE_STEP: float = 15.0
## The check on a first Enforcer chase without a wider gap (_chase_spot): tag, chase start and end, what it found.
const NO_CLEAR_STRETCH: String = "%s: its first Enforcer's chase (%.0f-%.0f m) holds no wider gap and has no clear stretch for a new row (%s)"

var sim: RunSim
var et: EnforcerTruckTuning
var wt: WideGapTuning
var frame: float = 1.0 / 60.0


func run() -> void:
	sim = RunSim.new(tree, tuning)
	et = EnforcerRules.tuning()
	wt = WideGapPlacement.tuning()
	frame = 1.0 / float(Engine.physics_ticks_per_second)
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	_test_tuning()
	_test_campaign(campaign)
	_test_before_showings(campaign)
	_test_last_resort(campaign)
	_test_last_resort_fences()
	_test_off(campaign)
	_test_fillers(campaign)
	await _test_jumps(campaign)
	await _test_enforcer_wrecked(campaign)
	await _test_corporate_2(campaign)


func _test_tuning() -> void:
	check(wt.jump_fraction > et.max_hop_jump_fraction and wt.jump_fraction <= 0.8,
		"a wider gap is more of a jump than an Enforcer Truck hops (%.2f > %.2f) and no more than a level's longest (0.8)"
		% [wt.jump_fraction, et.max_hop_jump_fraction])
	check(wt.spacing_seconds >= 10.0, "wider gaps are uncommon: %.0f s apart at least" % wt.spacing_seconds)


# --- Campaign --------------------------------------------------------------------------------------

func _test_campaign(campaign: Campaign) -> void:
	var truck_builds: int = 0
	var chases_held: int = 0
	for s: CampaignStep in campaign.steps():
		if not s.is_level():
			continue
		var line: PackedStringArray = []
		for lanes: int in LANES:
			var config: LevelConfig = campaign.configure(s, lanes)
			var tag: String = "%s at %d lanes" % [s.id, lanes]
			var gen: LevelGenerator = LayoutCache.generator(config, tuning, LevelGenerator.load_for(config))
			var layout: LevelLayout = gen.layout
			var movement: MovementTuning = config.movement_for(tuning)
			var jump: float = movement.jump_distance(movement.run_speed)
			var rows: Array[Dictionary] = WideGapPlacement.wide_rows(layout, jump, et.max_hop_jump_fraction)
			var result: Dictionary = gen.wide_gap_result
			check(config.wide_gaps == 2 and rows.size() == config.wide_gaps,
				"%s has its %d wider gaps (%d)" % [tag, config.wide_gaps, rows.size()])
			check((result.get("constraints", ["no report"]) as Array).is_empty() and (result.get("rows", []) as Array).size() == rows.size(),
				"%s: the pass placed them all, as it reports (%s)" % [tag, result.get("constraints", "no report")])
			LayoutChecks.check_wide_gaps(self, layout, config, tag)
			_check_fillers(gen, rows, tag)
			# A first Enforcer chase without one has no clear stretch for a new row of one (prefer_enforcer_chases; open
			# question 357; _chase_spot's limits: its doc comment).
			var chases: Array[Vector2] = WideGapPlacement._chases(gen)
			if not chases.is_empty():
				truck_builds += 1
				var held: bool = false
				for row: Dictionary in rows:
					held = held or (float(row["start"]) >= chases[0].x - 0.01 and float(row["end"]) <= chases[0].y + 0.01)
				if held:
					chases_held += 1
				else:
					var spot: String = _chase_spot(gen, chases[0])
					check(spot == "", NO_CLEAR_STRETCH % [tag, chases[0].x, chases[0].y, spot])
			# Task C6e: none comes in an Enforcer Truck's chase before its showing (from its arrival to its window's end).
			var before: PackedStringArray = []
			for keep: Vector2 in EnforcerRules.wide_gap_keep_outs(layout):
				for row: Dictionary in rows:
					if float(row["start"]) < keep.y and float(row["end"]) > keep.x:
						before.append("%.0f m in %.0f-%.0f m" % [float(row["start"]), keep.x, keep.y])
			check(before.is_empty(), "%s: no wider gap in an Enforcer Truck's chase before its showing (%s)" % [tag, ", ".join(before)])
			var grid := FloorRoute.new(layout, movement)
			var lanes_txt: PackedStringArray = []
			for row: Dictionary in rows:
				var span := Vector2(float(row["start"]), float(row["end"]))
				var zone: Vector2 = WideGapPlacement.zone_of(gen, wt, span)
				var from: float = grid.clear_start(zone.x)
				var route: Dictionary = grid.find(from, zone.y)
				check(bool(route["ok"]), "%s: a floor route crosses the wider gap at %.1f (from %.1f: %s)" % [tag, span.x, from,
					route["reason"]])
				lanes_txt.append("%.0f m %d/%d lanes" % [span.x, (row["lanes"] as Array).size(), lanes])
			line.append("%d lanes: %d rows, %d holes; wider %s (widened %d, added %d, cleared %d taking out %d)" % [lanes,
				GapDensity.rows(layout).size(), layout.gaps.size(), ", ".join(lanes_txt), int(result.get("widened", 0)),
				int(result.get("added", 0)), int(result.get("cleared", 0)), int(result.get("taken_out", 0))])
		print("  %s: %s" % [s.id, "; ".join(line)])
	print("  the first Enforcer chase holds a wider gap in %d of the %d level and lane builds with trucks" % [chases_held,
		truck_builds])
	check(chases_held > 0, "some Enforcer chases hold a wider gap (%d of %d builds)" % [chases_held, truck_builds])


## Where a new wider row would fit inside `chase` (an Enforcer chase, Vector2(from, to)) in `gen`'s finished layout,
## as WideGapPlacement._add_one looks for one; "" if nowhere found. The passes after it only add to what it saw (the
## fill pass, the danger density pass's rows, doodads), so a spot that fits now fitted then, and the pass, preferring a
## chase (its first, before any other wider gap), would have put one there. A check that the pass missed no clear
## stretch, not proof that the chase has no room: it tries only that one of the pass's three ways (not making one of
## the level's own rows longer, nor clearing pieces out of a row's way), on the finished layout rather than the one
## the pass saw, and it counts a spot only in a run of fitting starts 2 m long (3 starts 1 m apart, as _add_one
## steps 1 m from starting points of its own), so a fitting stretch of one or two starts goes unseen.
func _chase_spot(gen: LevelGenerator, chase: Vector2) -> String:
	var length: float = WideGapPlacement.length_for(gen, wt)
	var keeps: Array[Dictionary] = WideGapPlacement.keeps_of(gen)
	var to: float = minf(chase.y, gen.layout.length - gen.config.end_clear_distance)
	var run: int = 0
	var start: float = maxf(chase.x, gen.config.start_clear_distance)
	while start <= to - length:
		var span := Vector2(start, start + length)
		var kept: Array[int] = WideGapPlacement._kept_lanes(gen, wt, span, keeps)
		var lanes: Array[int] = []
		for lane: int in gen.layout.lane_count:
			if kept.is_empty() or lane != kept[0]:
				lanes.append(lane)
		var ok: bool = kept.size() <= 1 and WideGapPlacement.fits(gen, wt, span, {"start": span.x, "end": span.y,
			"lanes": lanes}, keeps)
		run = run + 1 if ok else 0
		if run >= 3:
			return "a new row fits at %.0f m" % (start - 2.0)
		start += 1.0
	return ""


## Task C6e (approved with C6d's follow-up): on every level with the Enforcer Truck at 3, 5 and 6 lanes, on another
## seed, no wider gap comes in a truck's chase before its showing (from its arrival to its window's end), and the level
## keeps its wider gaps (one fewer allowed off its own seed, as LayoutChecks.check_wide_gaps; the builds with one fewer
## are printed); how many sit in a chase past its window is printed.
func _test_before_showings(campaign: Campaign) -> void:
	var lines: PackedStringArray = []
	var fewer: PackedStringArray = []
	for id: String in ["corporate/2", "dead_zone/1", "dead_zone/2", "golden/1", "golden/2", "golden/3"]:
		var in_chase: int = 0
		var builds: int = 0
		for lanes: int in LANES:
			var config: LevelConfig = campaign.configure(campaign.step(id), lanes)
			config.level_seed = 9101
			var gen: LevelGenerator = LayoutCache.generator(config, tuning, LevelGenerator.load_for(config))
			var movement: MovementTuning = config.movement_for(tuning)
			var rows: Array[Dictionary] = WideGapPlacement.wide_rows(gen.layout, movement.jump_distance(movement.run_speed),
				et.max_hop_jump_fraction)
			var tag: String = "%s at %d lanes, seed %d" % [id, lanes, config.level_seed]
			var before: PackedStringArray = []
			for keep: Vector2 in EnforcerRules.wide_gap_keep_outs(gen.layout):
				for row: Dictionary in rows:
					if float(row["start"]) < keep.y and float(row["end"]) > keep.x:
						before.append("%.0f m in %.0f-%.0f m" % [float(row["start"]), keep.x, keep.y])
			# On a seed not the level's own one fewer may fit, never none (LayoutChecks.check_wide_gaps): Dead Zone 1 at 6
			# lanes fits one on this seed, as it did before task C6e.
			check(rows.size() >= maxi(config.wide_gaps - 1, 1) and before.is_empty(),
				"%s keeps its %d wider gaps (%d; one fewer allowed off its own seed), none in a truck's chase before its showing (%s)"
				% [tag, config.wide_gaps, rows.size(), ", ".join(before)])
			if rows.size() < config.wide_gaps:
				fewer.append("%s at %d lanes" % [id, lanes])
			builds += 1
			for chase: Vector2 in WideGapPlacement._chases(gen):
				for row: Dictionary in rows:
					if float(row["start"]) >= chase.x and float(row["end"]) <= chase.y:
						in_chase += 1
		lines.append("%s %d of %d builds" % [id, in_chase, builds])
	print("  wider gaps in a chase past its showing window (seed 9101): %s; one fewer: %s" % [", ".join(lines),
		", ".join(fewer) if not fewer.is_empty() else "none"])


## The pass's last way at LAST_RESORT_CASES: each build's one wider gap is the row it placed (its report's
## added_clearing: the only row, pieces taken out of its way), keeping every rule a wider gap keeps
## (LayoutChecks.check_wide_gaps), with a floor route across it from the clear floor before it, not in an Enforcer
## Truck's chase before its showing; every truck's showing window still holds in the finished level
## (ShowPlanner.problem_of).
func _test_last_resort(campaign: Campaign) -> void:
	for c: Dictionary in LAST_RESORT_CASES:
		var config: LevelConfig = campaign.configure(campaign.step(String(c["id"])), int(c["lanes"]))
		config.level_seed = int(c["seed"])
		var tag: String = "%s at %d lanes, seed %d" % [c["id"], c["lanes"], c["seed"]]
		var gen: LevelGenerator = LayoutCache.generator(config, tuning, LevelGenerator.load_for(config))
		var layout: LevelLayout = gen.layout
		var result: Dictionary = gen.wide_gap_result
		var movement: MovementTuning = config.movement_for(tuning)
		var rows: Array[Dictionary] = WideGapPlacement.wide_rows(layout, movement.jump_distance(movement.run_speed),
			et.max_hop_jump_fraction)
		var placed: Array = result.get("rows", [])
		var same: bool = placed.size() == 1 and rows.size() == 1 \
			and absf(float(rows[0]["start"]) - (placed[0] as Vector2).x) < 0.01
		check(same and int(result.get("added_clearing", 0)) == 1 and int(result.get("taken_out", 0)) > 0,
			("%s still gets its one wider gap from the last way, pieces taken out of its way (%d rows placed, %d wider rows, "
			+ "%d by the last way, %d pieces out), else re-pin LAST_RESORT_CASES") % [tag, placed.size(), rows.size(),
			int(result.get("added_clearing", 0)), int(result.get("taken_out", 0))])
		LayoutChecks.check_wide_gaps(self, layout, config, tag)
		var grid := FloorRoute.new(layout, movement)
		var keeps: Array[Vector2] = EnforcerRules.wide_gap_keep_outs(layout)
		for row: Dictionary in rows:
			var span := Vector2(float(row["start"]), float(row["end"]))
			var zone: Vector2 = WideGapPlacement.zone_of(gen, wt, span)
			var from: float = grid.clear_start(zone.x)
			var route: Dictionary = grid.find(from, zone.y)
			check(bool(route["ok"]), "%s: a floor route crosses the wider gap at %.1f (from %.1f: %s)" % [tag, span.x, from,
				route["reason"]])
			for keep: Vector2 in keeps:
				check(span.x >= keep.y or span.y <= keep.x,
					"%s: the wider gap at %.0f m isn't in an Enforcer Truck's chase before its showing (%.0f-%.0f m)" % [tag,
					span.x, keep.x, keep.y])
		var planner: EnforcerRules.ShowPlanner = EnforcerRules.ShowPlanner.make(gen, et)
		var trucks: Array[Dictionary] = EnforcerRules.trucks_in(layout)
		var windows: int = 0
		for e: Dictionary in trucks:
			var w: Vector2 = EnforcerRules.window_of(e)
			windows += 1 if w.y > w.x else 0
			var why: String = planner.problem_of(e)
			check(why == "", "%s: the truck at %.0f m: its showing window holds in the finished level (%s)" % [tag,
				float(e["at"]), why])
		var at: PackedStringArray = []
		for row: Dictionary in rows:
			at.append("%.0f m (%d of %d lanes)" % [float(row["start"]), (row["lanes"] as Array).size(), int(c["lanes"])])
		print("  %s: the last way's wider gap at %s, %d pieces taken out of its way; %d trucks, %d with a window" % [tag,
			", ".join(at), int(result.get("taken_out", 0)), trucks.size(), windows])


## The last way on a plain stretch (quick play's level at 5 lanes with no features, its own pieces cleared, then a
## fence in lane 0 every FENCE_STEP metres, so no spot is clear): with plain fences, the pass's one wider gap comes
## from it, those in its zone taken out, and the row then fits (nothing left in its way); with pulsing ones (the
## `pulsing` feature's, never taken out) none comes, and every fence stays.
func _test_last_resort_fences() -> void:
	for pulsing: bool in [false, true]:
		var config := LevelConfig.new()
		config.lane_count = 5
		config.duration_seconds = 60.0
		config.features = PackedStringArray()
		var gen := LevelGenerator.new()
		var layout: LevelLayout = gen.generate(config, tuning, LevelGenerator.load_for(config))
		for list: Array in [layout.gaps, layout.fences, layout.signs, layout.hulls, layout.pads, layout.ramps,
				layout.speed_pads, layout.enemies, layout.doodads, layout.cuts]:
			list.clear()
		var d: float = config.start_clear_distance
		while d < layout.length - config.end_clear_distance:
			layout.fences.append({"lane": 0, "at": d, "variant": "full", "pulsing": pulsing, "pulse_on": 1.2,
				"pulse_off": 1.0, "phase": 0.0})
			d += FENCE_STEP
		var fences: int = layout.fences.size()
		config.wide_gaps = 1
		var result: Dictionary = WideGapPlacement.place(gen)
		var placed: Array = result.get("rows", [])
		var tag: String = "a plain stretch with a %s fence every %.0f m" % ["pulsing" if pulsing else "plain", FENCE_STEP]
		if pulsing:
			check(placed.is_empty() and int(result.get("added_clearing", -1)) == 0 and int(result.get("taken_out", -1)) == 0
				and layout.gaps.is_empty() and layout.fences.size() == fences and not (result.get("constraints", []) as Array).is_empty(),
				"%s gets no wider gap, and keeps its %d fences (%d rows, %d holes, %d fences)" % [tag, fences, placed.size(),
				layout.gaps.size(), layout.fences.size()])
			print("  %s: %d wider gaps, %d of its %d fences kept" % [tag, placed.size(), layout.fences.size(), fences])
			continue
		check(placed.size() == 1 and int(result.get("added_clearing", 0)) == 1 and int(result.get("taken_out", 0)) > 0
			and layout.fences.size() == fences - int(result.get("taken_out", 0)) and layout.gaps.size() == config.lane_count - 1,
			"%s gets its wider gap from the last way, the fences in its way taken out (%d rows, %d by the last way, %d of %d fences out, %d holes)"
			% [tag, placed.size(), int(result.get("added_clearing", 0)), int(result.get("taken_out", 0)), fences, layout.gaps.size()])
		if placed.size() != 1:
			continue
		var span: Vector2 = placed[0]
		var lanes: Array[int] = []
		for g: Dictionary in layout.gaps:
			lanes.append(int(g["lane"]))
		var what: String = WideGapPlacement.blocker(gen, wt, span, {"start": span.x, "end": span.y, "lanes": lanes},
			WideGapPlacement.keeps_of(gen))
		check(what == "", "%s: the new row at %.0f m then fits, nothing in its way (%s)" % [tag, span.x, what])
		print("  %s: the last way's wider gap at %.0f m, %d of its %d fences taken out" % [tag, span.x,
			int(result.get("taken_out", 0)), fences])


## A boss arena never gets them, even asked; quick play and the prototype level ask for none and draw nothing;
## a level builds the same on every attempt.
func _test_off(campaign: Campaign) -> void:
	for s: CampaignStep in campaign.steps():
		if s.boss == null or s.boss.arena == null:
			continue
		var config: LevelConfig = BossArena.base_config(s.boss)
		config.lane_count = 5
		config.wide_gaps = 2
		var gen := LevelGenerator.new()
		var layout: LevelLayout = gen.generate(config, tuning, LevelGenerator.load_for(config))
		var jump: float = config.movement_for(tuning).jump_distance(config.movement_for(tuning).run_speed)
		check(gen.wide_gap_result.is_empty() and WideGapPlacement.wide_rows(layout, jump, et.max_hop_jump_fraction).is_empty(),
			"%s: no wider gaps in a boss arena, even asked" % config.id)
	var quick := LevelConfig.new()
	var prototype := load("res://data/levels/prototype_level.tres") as LevelConfig
	for config: LevelConfig in [quick, prototype]:
		var gen := LevelGenerator.new()
		var layout: LevelLayout = gen.generate(config, tuning, LevelGenerator.load_for(config))
		var jump: float = config.movement_for(tuning).jump_distance(config.movement_for(tuning).run_speed)
		check(config.wide_gaps == 0 and gen.wide_gap_result.is_empty()
			and WideGapPlacement.wide_rows(layout, jump, et.max_hop_jump_fraction).is_empty(),
			"%s asks for none and draws nothing" % ("quick play" if config == quick else "the prototype level"))
	var c2: LevelConfig = campaign.configure(campaign.step("corporate/2"), 5)
	var a := LevelGenerator.new()
	var first: LevelLayout = a.generate(c2, tuning, LevelGenerator.load_for(c2))
	var b := LevelGenerator.new()
	var again: LevelLayout = b.generate(c2, tuning, LevelGenerator.load_for(c2))
	check(first.to_dict() == again.to_dict() and a.wide_gap_result == b.wide_gap_result,
		"Corporate 2 builds the same wider gaps on every attempt")


## Builds where the fill pass put a filler at its spacing from one of the level's own rows that's made longer
## after it (WideGapPlacement.widen_deferred): the filler goes, and every filler keeps the fill pass's spacing
## from every wider row; the level keeps its wider gaps. The seeds are ones where that happens on task K4's
## curve (city/3 3 lanes 7001, gangland/1 3 lanes 9103 and gangland/3 5 lanes 9101 before the Casino; city/3 3
## lanes 7037, gangland/1 6 lanes 9110 and gangland/3 5 lanes 9103 on K2's 17-level linear curve).
func _test_fillers(campaign: Campaign) -> void:
	for c: Array in [["city/3", 3, 7040], ["gangland/1", 6, 9101], ["gangland/3", 5, 9101]]:
		var config: LevelConfig = campaign.configure(campaign.step(String(c[0])), int(c[1]))
		config.level_seed = int(c[2])
		var tag: String = "%s at %d lanes, seed %d" % c
		var gen := LevelGenerator.new()
		var layout: LevelLayout = gen.generate(config, tuning, LevelGenerator.load_for(config))
		var movement: MovementTuning = config.movement_for(tuning)
		var rows: Array[Dictionary] = WideGapPlacement.wide_rows(layout, movement.jump_distance(movement.run_speed),
			et.max_hop_jump_fraction)
		check(rows.size() == config.wide_gaps, "%s has its %d wider gaps (%d)" % [tag, config.wide_gaps, rows.size()])
		_check_fillers(gen, rows, tag)
		check(int(gen.wide_gap_result.get("fillers_out", 0)) > 0, "%s: the filler too near a longer row went" % tag)


## Every filler of `gen`'s last build keeps the fill pass's spacing (LevelGenerator._fill_margin) from each of
## `rows` (the wider ones), as from any piece.
func _check_fillers(gen: LevelGenerator, rows: Array[Dictionary], tag: String) -> void:
	for row: Dictionary in rows:
		var before: float = float(row["start"]) - gen._fill_margin(float(row["start"]))
		var after: float = float(row["end"]) + gen._fill_margin(float(row["end"]))
		for f: Dictionary in gen.fills:
			var at: float = float(f["at"])
			check(at + float(f["used"]) <= before + 0.01 or at >= after - 0.01,
				"%s: the filler at %.1f keeps the fill pass's spacing from the wider gap at %.1f" % [tag, at,
					float(row["start"])])


# --- Physics ---------------------------------------------------------------------------------------

## Quick play's speed and every campaign level's (each once), at 3, 5 and 6 lanes: a row of the wider length in
## every lane but the last, the runner in the middle lane.
func _test_jumps(campaign: Campaign) -> void:
	var speeds: Array[MovementTuning] = [tuning]
	var seen: Array[float] = [snappedf(tuning.run_speed, 0.01)]
	var configs: Array[LevelConfig] = [LevelConfig.new()]
	for s: CampaignStep in campaign.steps():
		if not s.is_level():
			continue
		var config: LevelConfig = campaign.configure(s, 5)
		var movement: MovementTuning = config.movement_for(tuning)
		if seen.has(snappedf(movement.run_speed, 0.01)):
			continue
		seen.append(snappedf(movement.run_speed, 0.01))
		speeds.append(movement)
		configs.append(config)
	for i: int in speeds.size():
		var movement: MovementTuning = speeds[i]
		var v: float = movement.run_speed
		var jump: float = movement.jump_distance(v)
		var length: float = minf(wt.jump_fraction, configs[i].max_gap_jump_fraction) * jump
		for lanes: int in LANES:
			var start: float = 3.0 * v + 20.0
			var end: float = start + length
			var layout := RunSim.layout(lanes, end + 6.0 * v)
			for lane: int in lanes - 1:
				layout.gaps.append({"lane": lane, "start": start, "end": end})
			var tag: String = "(%d lanes, %.1f m/s, %.1f m: %.2f of a jump)" % [lanes, v, length, length / jump]
			var seconds: float = (end + 2.0 * v) / v
			var early: float = end - jump + FloorRoute.LANDING_MARGIN
			var late: float = start - FloorRoute.GAP_MARGIN
			for take_off: float in [early, (early + late) * 0.5, late]:
				var r: Dictionary = await sim.run(layout, lanes / 2, seconds, [[take_off, &"jump"]], [], movement)
				check(bool(r["alive"]) and float(r["distance"]) > end + v,
					"%s a jump %.2f m before its edge clears a wider gap (%s at %.1f m)" % [tag, start - take_off,
					r["cause"], float(r["distance"])])
			var on: Dictionary = await sim.run(layout, lanes / 2, seconds, [], [], movement)
			check(not bool(on["alive"]) and String(on["cause"]) == "fell", "%s running on falls in (%s)" % [tag, on["cause"]])


# --- The Enforcer Truck ------------------------------------------------------------------------------

## The truck (no volleys) chasing a runner who jumps a wider row in its lane is wrecked in it; it hops an
## ordinary row.
func _test_enforcer_wrecked(campaign: Campaign) -> void:
	var c2: LevelConfig = campaign.configure(campaign.step("corporate/2"), 5)
	var paces: Array = [[tuning, 0.0], [c2.movement_for(tuning), c2.enemy_scaling]]
	for lanes: int in LANES:
		for pace: Array in paces:
			var movement: MovementTuning = pace[0]
			var v: float = movement.run_speed
			var jump: float = movement.jump_distance(v)
			var tag: String = "(%d lanes, %.1f m/s)" % [lanes, v]
			for fraction: float in [minf(wt.jump_fraction, c2.max_gap_jump_fraction), 0.5]:
				var start: float = 6.0 * v
				var end: float = start + fraction * jump
				var layout := RunSim.layout(lanes, 1400.0)
				layout.enemies.append({"type": "enforcer_truck", "at": 1.0, "lane": lanes / 2, "side": 0, "seed": 7,
					"params": {}})
				for lane: int in lanes - 1:
					layout.gaps.append({"lane": lane, "start": start, "end": end})
				var r: Dictionary = await _truck_run(layout, pace, start - (1.0 - fraction) * 0.5 * jump, end + 2.0 * v)
				if fraction > et.max_hop_jump_fraction:
					check(String(r["down"]) == "gap" and bool(r["alive"]) and int(r["kill"]) == et.score_value,
						"%s following a runner who jumps a wider gap (%.2f of a jump), it's wrecked in it, the player's kill (%s, %d)"
						% [tag, fraction, r["down"], int(r["kill"])])
				else:
					check(String(r["down"]) == "" and bool(r["alive"]) and int(r["hops"]) == 1,
						"%s it hops an ordinary row (%.2f of a jump) the runner jumps (%s, %d hops)" % [tag, fraction, r["down"],
						int(r["hops"])])


## The truck (no volleys) chasing the runner over `layout`, who keeps to the middle lane and jumps at `jump_at`,
## until they're at `until`. {down (its wreck's cause, "" if none), kill (points for it), alive, hops}.
func _truck_run(layout: LevelLayout, pace: Array, jump_at: float, until: float) -> Dictionary:
	var config := LevelConfig.new()
	config.enemy_scaling = float(pace[1])
	var movement: MovementTuning = pace[0]
	var w: RunWorld = sim.build_world(layout, Loadout.new(), movement, config)
	w.player.armor = 0
	w.director.enemy_spawned.connect(func(e: Enemy) -> void:
		if e is EnforcerTruck:
			var truck := e as EnforcerTruck
			truck.tuning = truck.tuning.duplicate() as EnforcerTruckTuning
			truck.tuning.first_volley_seconds = 999.0)
	await tree.physics_frame
	w.player.running = true
	var out := {"down": "", "kill": 0, "alive": true, "hops": 0}
	var truck: EnforcerTruck = null
	var jumped: bool = false
	for i: int in int(30.0 / frame):
		if truck == null:
			truck = _truck(w)
		if not jumped and w.player.distance >= jump_at:
			jumped = true
			w.player.press(&"jump")
		var kills_before: int = int(w.score.bonuses.get(&"kill", 0))
		await tree.physics_frame
		if truck == null:
			continue
		if not is_instance_valid(truck):
			break
		if not truck.alive and String(out["down"]) == "":
			out["down"] = String(truck.history.back()[0]).trim_prefix("wreck:")
			out["kill"] = int(w.score.bonuses.get(&"kill", 0)) - kills_before
			break
		if not w.player.alive or w.player.distance > until:
			break
	out["alive"] = w.player.alive
	if truck != null and is_instance_valid(truck):
		for h: Array in truck.history:
			if String(h[0]) == "hop":
				out["hops"] = int(out["hops"]) + 1
	await sim.free_world(w)
	return out


func _truck(w: RunWorld) -> EnforcerTruck:
	for e: Variant in w.director.active:
		if is_instance_valid(e) and e is EnforcerTruck:
			return e as EnforcerTruck
	return null


## Corporate 2's own build, played from its start (god mode, grapples: the runner keeps to the middle lane and
## takes whatever comes) until the first Enforcer's chase reaches its wider gap: the runner lines up in a hole
## lane of it (the nearest the middle) a few seconds before and jumps it midway through its take-off window; the
## truck following is wrecked in it. The chase leaves room past the truck's showing window (task C6e: no wider gap
## before it) at two lane counts at least, and holds a wider gap there at CORPORATE_2_CHASE_LANES only: a lane count
## with room left out of it shows no clear stretch for a new row there (_chase_spot, whose limits its doc comment
## gives: preferred, not guaranteed, open question 357), and one lane count at least plays it.
func _test_corporate_2(campaign: Campaign) -> void:
	var ran: int = 0
	var played: int = 0
	for lanes: int in LANES:
		var config: LevelConfig = campaign.configure(campaign.step("corporate/2"), lanes)
		config.skin = null  # the grey box: skins never change gameplay
		var gen: LevelGenerator = LayoutCache.generator(config, tuning, LevelGenerator.load_for(config))
		var layout: LevelLayout = gen.layout
		var movement: MovementTuning = config.movement_for(tuning)
		var v: float = movement.run_speed
		var jump: float = movement.jump_distance(v)
		var tag: String = "Corporate 2 at %d lanes" % lanes
		var trucks: Array[Dictionary] = EnforcerRules.trucks_in(layout)
		check(not trucks.is_empty(), "%s has an Enforcer Truck" % tag)
		if trucks.is_empty():
			continue
		var at: float = float(trucks[0]["at"])
		# Settled behind the runner, past its showing window (task C6e), before it may drop back.
		var chase := Vector2(at + et.bait_after_seconds * v, at + (et.chase_seconds - WideGapPlacement.CHASE_END_SECONDS) * v)
		var window: Vector2 = EnforcerRules.window_of(trucks[0])
		if window.y > window.x:
			chase.x = maxf(chase.x, window.y + EnforcerRules.WINDOW_EDGE)
		var row: Dictionary = {}
		for r: Dictionary in WideGapPlacement.wide_rows(layout, jump, et.max_hop_jump_fraction):
			if float(r["start"]) >= chase.x and float(r["end"]) <= chase.y:
				row = r
				break
		var listed: bool = CORPORATE_2_CHASE_LANES.has(lanes)
		if chase.y - chase.x < 3.0 * v:
			# Its window ends with its chase (after its bait): no room for one past it there.
			check(not listed, "%s: listed in CORPORATE_2_CHASE_LANES, but its first Enforcer's chase leaves no room past its window (%.0f-%.0f m)"
				% [tag, window.x, window.y])
			print("  %s: its first Enforcer's chase leaves no room past its window (%.0f-%.0f m)" % [tag, window.x, window.y])
			continue
		ran += 1
		var holds: bool = not row.is_empty()
		check(holds == listed, ("%s: its first Enforcer's chase past its showing window (%.0f-%.0f m) holds a wider gap if "
			+ "and only if CORPORATE_2_CHASE_LANES lists it (holds one: %s; listed: %s), else re-pin it") % [tag, chase.x,
			chase.y, holds, listed])
		if row.is_empty():
			var spot: String = _chase_spot(gen, chase)
			check(spot == "", NO_CLEAR_STRETCH % [tag, chase.x, chase.y, spot])
			print("  %s: no wider gap in its first Enforcer's chase past its showing window (%.0f-%.0f m), and no clear stretch there"
				% [tag, chase.x, chase.y])
			continue
		played += 1
		var middle: int = lanes / 2
		var hole: int = -1
		for lane: int in row["lanes"]:
			if hole < 0 or absi(lane - middle) < absi(hole - middle):
				hole = lane
		var start: float = float(row["start"])
		var end: float = float(row["end"])
		var take_off: float = start - (jump - (end - start)) * 0.5
		var w: RunWorld = sim.build_world(layout, null, null, config)
		w.player.god_mode = true
		w.player.grapples = 1_000_000
		await tree.physics_frame
		w.player.running = true
		var truck: EnforcerTruck = null
		var down: String = ""
		var jumped: bool = false
		var next_step: float = -INF
		var frames_left: int = int((end + 3.0 * v) / v * 2.0 / frame)
		while frames_left > 0 and w.player.distance < end + 3.0 * v:
			frames_left -= 1
			var p: Player = w.player
			var want: int = hole if p.distance >= start - 4.0 * v else middle
			if p.alive and p.running and p.surface == Player.Surface.FLOOR and p.grounded and p.lane != want \
					and w.level_time() >= next_step and p.distance < take_off - 0.25 * v:
				next_step = w.level_time() + 0.3
				p.press(&"move_right" if want > p.lane else &"move_left")
			if not jumped and p.distance >= take_off and p.lane == hole:
				jumped = true
				p.press(&"jump")
			await tree.physics_frame
			if truck == null:
				truck = _truck(w)
			if truck != null and is_instance_valid(truck) and not truck.alive and down == "":
				down = String(truck.history.back()[0]).trim_prefix("wreck:")
				break
		check(jumped and down == "gap",
			"%s: following the runner over the wider gap at %.0f m (lane %d, %.2f of a jump), the truck is wrecked in it (%s)"
			% [tag, start, hole, (end - start) / jump, down if down != "" else ("still chasing" if truck != null else "never came")])
		print("  %s: wider gap at %.0f m in the chase %.0f-%.0f m: the truck %s" % [tag, start, chase.x, chase.y,
			("wrecked: " + down) if down != "" else "not wrecked"])
		await sim.free_world(w)
	check(ran >= 2, "Corporate 2's first Enforcer chase leaves room past its showing window at %d of the 3 lane counts" % ran)
	check(played >= 1, "Corporate 2 leads its first truck into a wider gap at %d of the 3 lane counts" % played)
