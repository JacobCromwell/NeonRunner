class_name WallRunGapPlacement
extends RefCounted
## Wall-run gaps (task J2; the owner, October 15, 2026, docs/USER_REQUESTS.md: "I would like some sections, especially
## in later zones and levels, where there is a gap over the ENTIRE floor (every lane), and the only way to cross is a
## wall run ... consider a wall an acceptable/safe path"): a stretch where every floor lane is a hole, too long to jump
## (or to jump and dash), with one side wall lit as the way across. LevelLayout.wall_run_gaps holds each, its holes are
## ordinary entries of LevelLayout.gaps marked LevelLayout.WALL_RUN_HOLE, and the skin lights its wall
## (ZoneSkin.wall_run_guide). A wall run is the accepted safe path here: the one place a level asks for the wall.
##
## Its shape (shape_for), at the level's run speed, from the standard wall run (MovementTuning.wall_entry_time +
## wall_slide_time: no claws, no wall hop):
## - the clear run-in: approach_seconds of floor with nothing in any lane, to see the gap and its lit wall and get
##   across to the wall's side (up to five lane switches on 6 lanes);
## - the lit stretch (entry_window_seconds): a step onto the wall anywhere along it carries the runner across, so the
##   gap is a standard wall run less the lit stretch and exit_margin_seconds: the wall run from the lit stretch's first
##   metre leaves the wall exit_margin_seconds past the gap's far edge, one from its last (with the jump grace) drops
##   them back onto the landing floor. A step onto the wall before the lit stretch drops the runner into the gap (unless
##   they wall hop, GDD §3: never asked for). Claws, the dash and a wall hop only carry them further.
## - the gap, in every lane;
## - the safe landing floor (landing_seconds, never shorter than where the latest standard wall run drops the runner
##   back, LANDING_SLACK_SECONDS more), with nothing in any lane.
## Every number is WallRunGapTuning's (data/tuning/wall_run_gaps.tres). With the shipped numbers the gap is about 1.3 s
## of run (30 m at the Marketplace's 22.6 m/s, 33 m at the Golden Zone's 25), against about 0.75 s of run and the
## dash's 4.8 m for the longest jump (a full jump, its jump grace, the dash all the way): no jump or dash crosses it.
##
## Where (place), from the generator after every pass that puts things on the floor (the doodads and the dash walls,
## LevelGenerator._build) and before the wall fences, the side wall gaps and the credits, from a stream of its own
## (rng_for(FEATURE)), so a level is built as before up to it:
## - only in a level with the `wall_run_gaps` feature (from Marketplace 1; never in the first zone), never in a boss
##   arena (WallGapPlacement.is_boss_arena), never before the feature's start, between the run-up and the end-clear
##   stretch;
## - its whole clear stretch, from the run-in to the end of the landing floor, off everything that may not go: every
##   enemy's attack (DangerDensity.attack_window: what it keeps and the floor it uses), every attack the rules keep the
##   floor off (LevelGenerator.rules_doodad_keep_outs: a Bad Dream's chase, a Gilded Sentinel's strike, a hover truck's
##   stay, an Enforcer Truck's showing window, a dash wall's footprint, a treasure stash), an Enforcer Truck's chase
##   before its showing (EnforcerRules.wide_gap_keep_outs, as a wider gap keeps off it: it would wreck the truck before
##   it has shown itself; past it, a truck following the runner into the gap is wrecked there, as in a wider gap), every
##   ceiling to the end of its landing zone and every pad's zone, every ramp to the end of the longest wall run it
##   launches, speed pads, floor cuts' windows, the wider gaps' zones, and fences that may not go (pulsing ones, ones a
##   fence generator powers) and a treasure stash's doodads;
## - its lit wall whole and clear (wall_keep_outs) from wall_clear_seconds before the lit stretch to past the longest
##   wall run a runner may take over the gap (claws, the dash and a save onto the wall at its far edge, wall_clear_seconds
##   more): no sign (it blocks the entry and hurts), no wall enemy (a window cyborg, a vent's screech, a Gilded Sentinel's
##   wall section); the wall fences and side wall gaps after it keep off that stretch (WallFencePlacement.keep_outs,
##   WallGapPlacement.keep_outs), and the other wall stays whole (no side wall gap) from other_wall_clear_seconds before
##   the gap to as far past it;
## - plain pieces in its way go (holes, fences that may go, zone doodads that aren't a stash's: taking content out never
##   makes a level unfair), and of the spots that fit near where one is due, the one with the fewest in its way.
## How many: about one every spacing_seconds_easy to _hard (by the difficulty where the last one stood), from the
## feature's start in the level that brings it in (its introduction, as soon as one fits), else first_spacing_share of a
## spacing after the run-up. A level with the feature gets at least one (anywhere past its start), or a warning.
##
## Never in a boss arena, quick play's prototype level or a level without the feature: those draw nothing and are built
## exactly as before. DESIGN-TBD (docs/questions/j2.md): every number, the lit wall's look, where the feature starts,
## a grapple's or a revive's save onto the lit wall (grapple_save).

const FEATURE: String = "wall_run_gaps"
## Claws lengthen wall runs (PowerupTuning.claws_wall_time_multiplier) and the dash carries a wall runner further.
const POWERUPS_PATH: String = "res://data/tuning/powerups.tres"
const EnforcerRules = preload("res://scripts/enemies/enforcer_truck_rules.gd")
const GeneratorRules = preload("res://scripts/enemies/generator_rules.gd")
## Metres between the spots a wall-run gap is tried at along a free stretch (_fit).
const STEP: float = 1.0
## Seconds of run the safe landing floor reaches past where the latest standard wall run drops the runner back onto it
## (landing_seconds): the feet come down a frame or two later than the model says, and a moment to stand.
const LANDING_SLACK_SECONDS: float = 0.3
## Metres either side of a wall-run gap's holes where a runner pulled up out of a fall is saved onto its lit wall
## (grapple_save): one falling in at its far edge has run on under the floor by the time the grapple catches them.
const SAVE_MARGIN: float = 6.0
## Two track distances closer than this are the same spot.
const EPSILON: float = 0.001
## Metres two stretches may overlap and still count as touching (problem): float rounding at a shared end.
const TOUCH: float = 0.01
## Metres the passes after the rules keep off either end of a wall-run gap's clear stretch beyond it (keep_out): a
## piece placed right at its end, a fence's half depth say, stays outside it.
const KEEP_MARGIN: float = 0.5


## A wall-run gap's sizes at one run speed (shape_for), in metres along the track.
class Shape:
	extends RefCounted
	## The run speed (m/s) they're for.
	var speed: float = 0.0
	## Seconds a standard wall run lasts on the wall (MovementTuning.wall_entry_time + wall_slide_time), and the
	## longest (claws' wall_time multiplier).
	var wall_run_seconds: float = 0.0
	var longest_seconds: float = 0.0
	## The clear run-in before the lit stretch, the lit stretch, the gap, the safe landing floor after it.
	var approach: float = 0.0
	var window: float = 0.0
	var gap: float = 0.0
	var landing: float = 0.0
	## How far past the gap the shortest standard wall run still runs on the wall (exit_margin_seconds).
	var exit_margin: float = 0.0
	## How far the lit wall stays whole and clear before the lit stretch, and past the gap's far edge.
	var wall_before: float = 0.0
	var wall_after: float = 0.0
	## How far either side of the gap the other wall stays whole.
	var other_clear: float = 0.0

	## The whole clear stretch, from the start of the run-in to the end of the landing floor.
	func zone() -> float:
		return approach + window + gap + landing

	## The parts of a wall-run gap whose clear stretch starts at 0, as Vector2(from, to) offsets along the track (see
	## keep_outs_by_part): what `whole`, `ceilings`, `run_ups` and `landings` keep off; and its lit wall's stretch
	## (`wall`, wall_path).
	func part(name: String) -> Vector2:
		match name:
			"ceilings":
				return Vector2(0.0, approach + window + gap + exit_margin)
			"run_ups":
				return Vector2(approach + window, approach + window + gap)
			"landings":
				return Vector2(approach, approach + window + gap)
			"wall":
				return Vector2(approach - wall_before, approach + window + gap + wall_after)
		return Vector2(0.0, zone())


## One pass's state (place).
class _Pass:
	extends RefCounted
	var gen: LevelGenerator
	var t: WallRunGapTuning
	var shape: Shape
	## What each part keeps off (keep_outs_by_part), each list sorted and merged, by part name ("whole", "ceilings",
	## "run_ups", "landings"); each side wall's (wall_keep_outs), [left, right].
	var parts: Dictionary = {}
	var walls: Array = []
	## The plain pieces that may go (_removable): {span, list, piece}, by where they start; their starts, and the
	## longest one's length (_cost looks them up by start).
	var pieces: Array[Dictionary] = []
	var starts := PackedFloat64Array()
	var longest: float = 0.0
	var taken_out: int = 0
	var costs: Array[int] = []

	## Sets the plain pieces that may go (_removable's), sorted by where they start.
	func set_pieces(list: Array[Dictionary]) -> void:
		pieces = list
		pieces.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a["span"] as Vector2).x < (b["span"] as Vector2).x)
		starts.resize(pieces.size())
		longest = 0.0
		for i: int in pieces.size():
			var s: Vector2 = pieces[i]["span"]
			starts[i] = s.x
			longest = maxf(longest, s.y - s.x)


static func tuning() -> WallRunGapTuning:
	return WallRunGapTuning.load_default()


static func powerups() -> PowerupTuning:
	var res: Resource = load(POWERUPS_PATH) if ResourceLoader.exists(POWERUPS_PATH) else null
	return res as PowerupTuning if res is PowerupTuning else PowerupTuning.new()


## Seconds of a fall from the height a wall run ends at (MovementTuning.wall_exit_height) to the floor.
static func drop_seconds(t: MovementTuning) -> float:
	return sqrt(2.0 * maxf(t.wall_exit_height, 0.0) / maxf(t.gravity() * t.fall_gravity_multiplier, 0.01))


## Seconds of run past a wall-run gap's far edge where the latest standard wall run drops the runner back onto the floor:
## a step onto the wall at the gap's near edge with the whole jump grace (MovementTuning.coyote_time) leaves the wall
## entry_window_seconds + exit_margin_seconds + the grace past the far edge (the gap is a wall run less the first two),
## and falls drop_seconds from there.
static func latest_drop_seconds(m: MovementTuning, t: WallRunGapTuning) -> float:
	return t.entry_window_seconds + t.exit_margin_seconds + m.coyote_time + drop_seconds(m)


## The safe landing floor's length in seconds of run: the tuning's, never shorter than where the latest standard wall
## run drops the runner back (latest_drop_seconds) plus LANDING_SLACK_SECONDS.
static func landing_seconds(m: MovementTuning, t: WallRunGapTuning) -> float:
	return maxf(t.landing_seconds, latest_drop_seconds(m, t) + LANDING_SLACK_SECONDS)


## A wall-run gap's sizes (Shape) for movement tuning `m` at run speed `speed` (m/s), from `t` (the shared numbers by
## default) and `pt` (the power-ups': claws and the dash).
static func shape_for(m: MovementTuning, speed: float, t: WallRunGapTuning = null, pt: PowerupTuning = null) -> Shape:
	var tt: WallRunGapTuning = t if t != null else tuning()
	var p: PowerupTuning = pt if pt != null else powerups()
	var s := Shape.new()
	s.speed = speed
	s.wall_run_seconds = m.wall_entry_time + m.wall_slide_time
	s.longest_seconds = m.wall_entry_time + m.wall_slide_time * maxf(p.claws_wall_time_multiplier, 1.0)
	s.approach = tt.approach_seconds * speed
	s.window = tt.entry_window_seconds * speed
	s.gap = maxf(s.wall_run_seconds - tt.entry_window_seconds - tt.exit_margin_seconds, 0.0) * speed
	s.landing = landing_seconds(m, tt) * speed
	s.exit_margin = tt.exit_margin_seconds * speed
	s.wall_before = tt.wall_clear_seconds * speed
	s.wall_after = s.longest_seconds * speed + p.dash_duration * p.dash_speed_bonus + tt.wall_clear_seconds * speed
	s.other_clear = tt.other_wall_clear_seconds * speed
	return s


## The shape at `gen`'s level (its movement tuning and run speed).
static func shape_of(gen: LevelGenerator, t: WallRunGapTuning = null) -> Shape:
	return shape_for(gen.tuning, gen.speed, t)


## The LevelLayout.wall_run_gaps entry of a wall-run gap shaped `shape` whose clear run-in starts at `approach`, its
## lit wall on `side` (-1 left, 1 right).
static func make(shape: Shape, approach: float, side: int) -> Dictionary:
	var entry_at: float = approach + shape.approach
	var start: float = entry_at + shape.window
	var end: float = start + shape.gap
	return {"side": side, "start": start, "end": end, "entry": entry_at, "approach": approach,
		"landing": end + shape.landing, "wall_to": end + shape.wall_after}


## What the passes after the rules keep off around wall-run gap `w` in every lane (wall_run_gaps_rules.gd): its clear
## stretch, from its clear run-in to the end of its landing floor, KEEP_MARGIN more at both ends (Vector2).
static func keep_out(w: Dictionary) -> Vector2:
	return Vector2(float(w["approach"]) - KEEP_MARGIN, float(w["landing"]) + KEEP_MARGIN)


## The stretch of its lit wall wall-run gap `w` keeps whole and clear, at run speed `speed`: from wall_clear_seconds
## before its lit stretch to its `wall_to` (Vector2).
static func wall_path(w: Dictionary, speed: float, t: WallRunGapTuning = null) -> Vector2:
	var tt: WallRunGapTuning = t if t != null else tuning()
	return Vector2(float(w["entry"]) - tt.wall_clear_seconds * speed, float(w["wall_to"]))


## What side wall gaps and wall fences keep off on wall `side` of `lay` at run speed `speed` (WallGapPlacement.keep_outs,
## WallFencePlacement.keep_outs): each wall-run gap's lit wall from before its lit stretch to past the longest wall run
## over it (wall_path), and, with `other`, on the other wall the gap with other_wall_clear_seconds either side (the wall
## gaps'). Vector2 stretches.
static func wall_keep_outs_for(lay: LevelLayout, speed: float, side: int, other: bool = true) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if lay.wall_run_gaps.is_empty():
		return out
	var t: WallRunGapTuning = tuning()
	for w: Dictionary in lay.wall_run_gaps:
		if int(w["side"]) == side:
			out.append(wall_path(w, speed, t))
		elif other:
			var clear: float = t.other_wall_clear_seconds * speed
			out.append(Vector2(float(w["start"]) - clear, float(w["end"]) + clear))
	return out


## Places the level's wall-run gaps (see the header). Returns its report (LevelGenerator.wall_run_gap_result): {} when
## the level has no `wall_run_gaps` (or is a boss arena); else {placed (how many), taken_out (plain pieces that went),
## costs (each one's pieces taken out), constraints (why none, if so)}.
static func place(gen: LevelGenerator) -> Dictionary:
	var lay: LevelLayout = gen.layout
	lay.wall_run_gaps.clear()
	if not gen.config.has_feature(FEATURE) or WallGapPlacement.is_boss_arena(gen.config):
		return {}
	var p := _Pass.new()
	p.gen = gen
	p.t = tuning()
	p.shape = shape_of(gen, p.t)
	var constraints: PackedStringArray = []
	if p.shape.gap <= EPSILON:
		constraints.append("no gap: the lit stretch and the exit margin take the whole wall run")
		return {"placed": 0, "taken_out": 0, "costs": [], "constraints": constraints}
	var rng: RandomNumberGenerator = gen.rng_for(FEATURE)
	var by_part: Dictionary = keep_outs_by_part(gen)
	for name: String in by_part:
		p.parts[name] = WallFencePlacement.merged(by_part[name])
	p.walls = [WallFencePlacement.merged(wall_keep_outs(gen, -1, p.t)), WallFencePlacement.merged(wall_keep_outs(gen, 1, p.t))]
	p.set_pieces(_removable(gen))
	var v: float = gen.speed
	var from: float = maxf(gen.feature_start(FEATURE), gen.config.start_clear_distance)
	# The latest a clear stretch may start: its landing floor ends before the end-clear stretch.
	var last: float = lay.length - gen.config.end_clear_distance - p.shape.zone()
	var count: int = planned_count(gen, p.t, from, last)
	var introduces: bool = gen.config.feature_starts.has(FEATURE)
	var search: float = p.t.search_seconds * v
	for k: int in count:
		# Every draw happens whether or not one fits, so one blocked spot never reshuffles the rest.
		var due: float = lerpf(from, last, (float(k) + rng.randf_range(0.25, 0.75)) / float(count))
		var side: int = -1 if rng.randf() < 0.5 else 1
		# The level that brings them in meets its first as soon as one fits past the feature's start.
		var lo: float = from if introduces and k == 0 else maxf(due - search, from)
		var hi: float = minf((from if introduces and k == 0 else due) + search, last)
		var fit: Dictionary = _fit(p, lo, hi, side, lo if introduces and k == 0 else due)
		if not fit.is_empty():
			_add(p, fit)
	if lay.wall_run_gaps.is_empty() and last >= from:
		# GDD §5: a feature a level has appears in it. Anywhere past its start, the earliest that needs the fewest pieces
		# taken out.
		var fit: Dictionary = _fit(p, from, last, -1 if rng.randf() < 0.5 else 1, from)
		if not fit.is_empty():
			_add(p, fit)
	if lay.wall_run_gaps.is_empty():
		constraints.append("no room anywhere past its start (%.0f m)" % from)
		gen.warnings.append("wall-run gaps: no fair room anywhere for one (every feature should appear, GDD §5)")
	elif lay.wall_run_gaps.size() < count:
		constraints.append("only %d of %d fit: no room near the others' spots" % [lay.wall_run_gaps.size(), count])
	if p.taken_out > 0:
		GeneratorRules.keep_powered(gen)
	lay.wall_run_gaps.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["start"]) < float(b["start"]))
	return {"target": count, "placed": lay.wall_run_gaps.size(), "taken_out": p.taken_out, "costs": p.costs,
		"constraints": constraints}


## How many wall-run gaps a level is due (see the header): one per spacing_seconds_easy to _hard (by the level's
## difficulty halfway between `from` and `last`) over that stretch, rounded, at least one.
static func planned_count(gen: LevelGenerator, t: WallRunGapTuning, from: float, last: float) -> int:
	var mid: float = (from + last) * 0.5
	var difficulty: float = gen.difficulty_at(clampf(mid / maxf(gen.layout.length, 1.0), 0.0, 1.0))
	var spacing: float = WallRunGapTuning.by_difficulty(t.spacing_seconds_easy, t.spacing_seconds_hard, difficulty)
	return maxi(1, roundi((last - from) / maxf(spacing * gen.speed, 1.0)))


## The wall-run gap (make) whose clear run-in starts in [lo, hi] that fits (_starts) and needs the fewest plain pieces
## taken out (_cost), the nearest `target` of those; its lit wall on `side` if one fits there, else on the other. {} if
## none fits. The entry carries its cost under "cost" (taken off when it's added).
static func _fit(p: _Pass, lo: float, hi: float, side: int, target: float) -> Dictionary:
	for s: int in [side, -side]:
		var best: Dictionary = {}
		var best_cost: int = 1 << 30
		var best_off: float = INF
		for free: Vector2 in _starts(p, s, lo, hi):
			var a: float = free.x
			while a <= free.y + EPSILON:
				var at: float = minf(a, free.y)
				var cost: int = _cost(p, at)
				var off: float = absf(at - target)
				if cost < best_cost or (cost == best_cost and off < best_off - EPSILON):
					best_cost = cost
					best_off = off
					best = make(p.shape, at, s)
				a += STEP
		if not best.is_empty():
			best["cost"] = best_cost
			return best
	return {}


## Where a wall-run gap with its lit wall on `side` may start its clear run-in, within [lo, hi]: each of its parts
## (Shape.part) off what that part keeps off (p.parts), and its lit wall's stretch off that wall's (p.walls). Sorted
## Vector2 ranges of starts.
static func _starts(p: _Pass, side: int, lo: float, hi: float) -> Array[Vector2]:
	# A part may touch what it keeps off (a start at a blocked range's end), never overlap it: a part over [a + o.x,
	# a + o.y] overlaps a blocked [b.x, b.y] for a in (b.x - o.y, b.y - o.x).
	var blocked: Array = []
	for name: String in p.parts:
		var o: Vector2 = p.shape.part(name)
		for b: Vector2 in p.parts[name]:
			blocked.append(Vector2(b.x - o.y, b.y - o.x))
	var w: Vector2 = p.shape.part("wall")
	for b: Vector2 in p.walls[0 if side < 0 else 1]:
		blocked.append(Vector2(b.x - w.y, b.y - w.x))
	var out: Array[Vector2] = []
	var cursor: float = lo
	for b: Vector2 in WallFencePlacement.merged(blocked):
		if b.y < cursor:
			continue
		if b.x > hi:
			break
		if b.x > cursor:
			out.append(Vector2(cursor, minf(b.x, hi)))
		cursor = maxf(cursor, b.y)
	if cursor <= hi:
		out.append(Vector2(cursor, hi))
	return out


## How many plain pieces (_removable) a wall-run gap whose clear run-in starts at `a` takes out.
static func _cost(p: _Pass, a: float) -> int:
	var to: float = a + p.shape.zone()
	var n: int = 0
	# Only a piece starting within its longest length before `a` can reach in.
	var i: int = p.starts.bsearch(a - p.longest - EPSILON)
	while i < p.pieces.size() and p.starts[i] < to:
		if (p.pieces[i]["span"] as Vector2).y > a:
			n += 1
		i += 1
	return n


## Adds wall-run gap `w` (_fit): takes out the plain pieces in its clear stretch, cuts every lane from its start to its
## end (holes marked LevelLayout.WALL_RUN_HOLE: the credit pass gives them no risky credit), and keeps the next ones off
## it. The danger density pass's report forgets the rows it touched that went (they no longer stand).
static func _add(p: _Pass, w: Dictionary) -> void:
	var gen: LevelGenerator = p.gen
	var lay: LevelLayout = gen.layout
	var zone := Vector2(float(w["approach"]), float(w["landing"]))
	var cost: int = int(w.get("cost", 0))
	w.erase("cost")
	var gone: int = 0
	for k: Dictionary in p.pieces:
		var s: Vector2 = k["span"]
		if s.x >= zone.y or s.y <= zone.x:
			continue
		match String(k["list"]):
			"gaps":
				gone += _erase(lay.gaps, k["piece"])
			"fences":
				gone += _erase(lay.fences, k["piece"])
			"doodads":
				gone += _erase(lay.doodads, k["piece"])
	p.taken_out += gone
	p.costs.append(cost)
	for lane: int in lay.lane_count:
		lay.gaps.append({"lane": lane, "start": float(w["start"]), "end": float(w["end"]), LevelLayout.WALL_RUN_HOLE: true})
	lay.wall_run_gaps.append(w)
	var touched: Variant = gen.danger_density_result.get("rows_touched")
	if touched is Array:
		var kept: Array = []
		for row: Dictionary in touched:
			if float(row["start"]) >= zone.y or float(row["end"]) <= zone.x:
				kept.append(row)
		gen.danger_density_result["rows_touched"] = kept
	# The next ones keep min_spacing_seconds from it.
	var room: float = p.t.min_spacing_seconds * gen.speed
	p.parts["whole"] = WallFencePlacement.merged(p.parts["whole"] + [Vector2(zone.x - room, zone.y + room)])
	p.set_pieces(_removable(gen))


## Takes `piece` (the very entry) out of `list`; 1 if it was there, else 0.
static func _erase(list: Array[Dictionary], piece: Dictionary) -> int:
	for i: int in list.size():
		if is_same(list[i], piece):
			list.remove_at(i)
			return 1
	return 0


## The level's wider gaps (task G7), each Vector2(start, end): the build's report (WideGapPlacement.rows_of), or, for a
## generator over a finished layout without one (LevelGenerator.for_layout), the layout's rows longer than an Enforcer
## Truck hops (WideGapPlacement.wide_rows).
static func _wide_rows(gen: LevelGenerator) -> Array[Vector2]:
	var out: Array[Vector2] = WideGapPlacement.rows_of(gen)
	if not out.is_empty() or gen.config.wide_gaps <= 0:
		return out
	var et: EnforcerTruckTuning = EnforcerRules.tuning()
	for row: Dictionary in WideGapPlacement.wide_rows(gen.layout, gen.jump_distance, et.max_hop_jump_fraction):
		out.append(Vector2(float(row["start"]), float(row["end"])))
	return out


## The plain pieces a wall-run gap may take out of its way: holes (but a wider gap's or another wall-run gap's), fences
## (but pulsing ones and ones a fence generator powers) and zone doodads (but a treasure stash's). Each {span (along the
## track), list (its LevelLayout list's name), piece}.
static func _removable(gen: LevelGenerator) -> Array[Dictionary]:
	var lay: LevelLayout = gen.layout
	var out: Array[Dictionary] = []
	var wide: Array[Vector2] = _wide_rows(gen)
	for g: Dictionary in lay.gaps:
		if LevelLayout.is_wall_run_hole(g) or _in_rows(g, wide):
			continue
		out.append({"span": Vector2(float(g["start"]), float(g["end"])), "list": "gaps", "piece": g})
	var half: float = gen.tuning.fence_depth * 0.5
	for f: Dictionary in lay.fences:
		if not _fence_stays(gen, f):
			out.append({"span": Vector2(float(f["at"]) - half, float(f["at"]) + half), "list": "fences", "piece": f})
	for d: Dictionary in lay.doodads:
		if not d.has("stash"):
			out.append({"span": Vector2(float(d["start"]), float(d["end"])), "list": "doodads", "piece": d})
	return out


## True if hole `g` belongs to one of `rows` (the wider gaps, Vector2(start, end)).
static func _in_rows(g: Dictionary, rows: Array[Vector2]) -> bool:
	for r: Vector2 in rows:
		if absf(float(g["start"]) - r.x) < 0.01 and absf(float(g["end"]) - r.y) < 0.01:
			return true
	return false


## True if fence `f` may not go: a pulsing one (the `pulsing` feature counts them) or one a fence generator powers.
static func _fence_stays(gen: LevelGenerator, f: Dictionary) -> bool:
	return bool(f.get("pulsing", false)) or WideGapPlacement._powered(gen, f)


## What each part of a wall-run gap keeps off (see the header), at `gen`'s level, as Vector2 stretches of track in no
## particular order: {whole (no wall-run gap's clear stretch reaches one, in any lane), ceilings (each ceiling section,
## which the clear run-in, the lit stretch, the gap and the exit margin keep off: a ceiling ending before the run-in
## drops its riders onto clear floor with the whole run-in ahead, and one may start over the landing floor), run_ups
## (each pad's run-up, clear floor in its lane a full jump long: kept off the gap only), landings (each ceiling's landing
## zone, clear floor: kept off the lit stretch and the gap only)}. `whole` is floor_keep_outs.
static func keep_outs_by_part(gen: LevelGenerator) -> Dictionary:
	var ceilings: Array[Vector2] = []
	var run_ups: Array[Vector2] = []
	var landings: Array[Vector2] = []
	for h: Dictionary in gen.layout.hulls:
		ceilings.append(Vector2(float(h["start"]), float(h["end"])))
		landings.append(gen.zones.landing_zone(h))
	for pad: Dictionary in gen.layout.pads:
		var at: float = float(pad["at"])
		run_ups.append(Vector2(gen.zones.pad_zone(at).x, at))
	return {"whole": floor_keep_outs(gen), "ceilings": ceilings, "run_ups": run_ups, "landings": landings}


## The stretches of track no wall-run gap's clear stretch may reach, in any lane (see the header), as Vector2, in no
## particular order: everything a wider gap's zone keeps off (WideGapPlacement.keeps_of: every enemy's attack and the
## floor it uses, a floor cyborg's obstacle margin, each of a planned Resonator's pulses, the rules' keep-outs, every
## ramp and its wall run, speed pad and floor cut's window, an Enforcer Truck's chase before its showing; not the plain
## fences and doodads, which may go, nor the ceilings, their landing zones and their pads' run-ups, which keep_outs_by_part
## keeps off the parts that need it), whole here (a wall-run gap is its own landing and take-off); and more:
## - each anti-grav pad and its lift (CeilingZones.pad_zone from the pad on): none lifts a runner off the clear stretch;
##   (a floor cyborg keeps its obstacle margin, the wider gaps' keep; its walk back and panic run stop that margin short
##   of the clear stretch, which is one of its obstacle spans once placed, CyborgRules.obstacle_spans;)
## - each ramp's longest wall run (claws, a speed pad's boost: WallFencePlacement.ramp_run_end): a runner it launches
##   never comes down into the clear stretch, or onto the lit wall, still on its run;
## - the wider gaps' zones, fences that may not go (pulsing ones, ones a fence generator powers) and a treasure stash's
##   doodads.
static func floor_keep_outs(gen: LevelGenerator) -> Array[Vector2]:
	var lay: LevelLayout = gen.layout
	var out: Array[Vector2] = []
	for k: Dictionary in WideGapPlacement.keeps_of(gen):
		var what: String = String(k["what"])
		# The wall-run gaps' own clear stretches (wall_run_gaps_rules.gd) are kept apart by the pass itself.
		if what in ["a fence", "a doodad", "a ceiling", "a ceiling's landing zone", "a pad", FEATURE]:
			continue
		out.append(k["span"])
	for pad: Dictionary in lay.pads:
		var at: float = float(pad["at"])
		out.append(Vector2(at, gen.zones.pad_zone(at).y))
	for r: Dictionary in lay.ramps:
		var at: float = float(r["at"])
		out.append(Vector2(at, maxf(WallFencePlacement.ramp_run_end(gen, r), at + gen.tuning.ramp_length)))
	for d: Dictionary in lay.doodads:
		if d.has("stash"):
			out.append(Vector2(float(d["start"]), float(d["end"])))
	var wt: WideGapTuning = WideGapPlacement.tuning()
	for span: Vector2 in _wide_rows(gen):
		out.append(WideGapPlacement.zone_of(gen, wt, span))
	var half: float = gen.tuning.fence_depth * 0.5
	for f: Dictionary in lay.fences:
		if _fence_stays(gen, f):
			out.append(Vector2(float(f["at"]) - half, float(f["at"]) + half))
	return out


## The stretches of wall `side` a wall-run gap's lit wall may not reach over its wall path (see the header): its signs,
## its wall fences (a fence deep: the path carries the margins, wall_clear_seconds either side), its side wall gaps, and
## its wall enemies (a window cyborg's window, a vent's screech, any other) with WallGapTuning.wall_enemy_seconds either
## side, a Gilded Sentinel's whole wall section (WallFencePlacement.sentinel_wall_section). Vector2, in no particular
## order.
static func wall_keep_outs(gen: LevelGenerator, side: int, t: WallRunGapTuning = null) -> Array[Vector2]:
	var tt: WallRunGapTuning = t if t != null else tuning()
	var lay: LevelLayout = gen.layout
	var v: float = gen.speed
	var clear: float = tt.wall_clear_seconds * v
	var enemy: float = WallGapPlacement.tuning().wall_enemy_seconds * v
	var half: float = gen.tuning.fence_depth * 0.5
	var out: Array[Vector2] = []
	for s: Dictionary in lay.signs:
		if int(s["side"]) == side:
			out.append(Vector2(float(s["start"]), float(s["end"])))
	for wf: Dictionary in lay.wall_fences:
		if int(wf["side"]) == side:
			out.append(Vector2(float(wf["at"]) - half, float(wf["at"]) + half))
	for g: Dictionary in lay.wall_gaps:
		if int(g["side"]) == side:
			out.append(Vector2(float(g["start"]), float(g["end"])))
	for e: Dictionary in lay.enemies:
		if int(e.get("side", 0)) != side:
			continue
		var at: float = float(e["at"])
		out.append(Vector2(at - enemy, at + enemy))
		if String(e.get("type", "")) == "gilded_sentinel":
			var section: Vector2 = WallFencePlacement.sentinel_wall_section(gen, e)
			out.append(Vector2(section.x - clear, section.y + clear))
	return out


## Why wall-run gap `w` (an entry of `gen`'s layout's wall_run_gaps) breaks a rule of the header in the finished layout,
## or "" if it keeps them all: its shape at the level's speed, between the run-up (and the feature's start) and the
## end-clear stretch, a hole in every lane over its gap and nothing else in its clear stretch, no floor keep-out reaching
## it, its lit wall clear over its wall path (signs, wall enemies, wall fences, side wall gaps), the other wall whole
## beside its gap.
static func problem(gen: LevelGenerator, w: Dictionary) -> String:
	var lay: LevelLayout = gen.layout
	var t: WallRunGapTuning = tuning()
	var shape: Shape = shape_of(gen, t)
	var side: int = int(w.get("side", 0))
	if side != -1 and side != 1:
		return "its lit wall is on side %d" % side
	var approach: float = float(w["approach"])
	var want: Dictionary = make(shape, approach, side)
	for key: String in ["entry", "start", "end", "landing", "wall_to"]:
		if absf(float(w[key]) - float(want[key])) > 0.01:
			return "its %s is at %.2f m, not %.2f m (its shape at %.1f m/s)" % [key, float(w[key]), float(want[key]), gen.speed]
	if approach < maxf(gen.config.start_clear_distance, gen.feature_start(FEATURE)) - 0.01:
		return "its clear run-in starts in the run-up or before the feature's start"
	if float(w["landing"]) > lay.length - gen.config.end_clear_distance + 0.01:
		return "its landing floor reaches the end-clear stretch"
	# What only touches an end of the clear stretch (a pass that kept exactly its margin) isn't in its way.
	var zone := Vector2(approach + TOUCH, float(w["landing"]) - TOUCH)
	var lanes: Dictionary = {}
	for g: Dictionary in lay.gaps:
		if float(g["start"]) >= zone.y or float(g["end"]) <= zone.x:
			continue
		if LevelLayout.is_wall_run_hole(g) and absf(float(g["start"]) - float(w["start"])) < 0.01 \
				and absf(float(g["end"]) - float(w["end"])) < 0.01:
			lanes[int(g["lane"])] = true
			continue
		return "another hole (lane %d, %.1f-%.1f m) in its clear stretch" % [int(g["lane"]), float(g["start"]), float(g["end"])]
	if lanes.size() != lay.lane_count:
		return "its gap cuts %d of the %d lanes" % [lanes.size(), lay.lane_count]
	var half: float = gen.tuning.fence_depth * 0.5
	for f: Dictionary in lay.fences:
		if float(f["at"]) + half > zone.x and float(f["at"]) - half < zone.y:
			return "a fence (lane %d at %.1f m) in its clear stretch" % [int(f["lane"]), float(f["at"])]
	for d: Dictionary in lay.doodads:
		if float(d["start"]) < zone.y and float(d["end"]) > zone.x:
			return "a zone doodad (lane %d at %.1f m) in its clear stretch" % [int(d["lane"]), float(d["start"])]
	var by_part: Dictionary = keep_outs_by_part(gen)
	for name: String in by_part:
		var o: Vector2 = shape.part(name)
		var at := Vector2(approach + o.x + TOUCH, approach + o.y - TOUCH)
		for k: Vector2 in by_part[name]:
			if k.x < at.y and k.y > at.x:
				return "something it keeps off (%s: %.1f-%.1f m) reaches it (%.1f-%.1f m)" % [name, k.x, k.y, at.x, at.y]
	var path: Vector2 = wall_path(w, gen.speed, t)
	for k: Vector2 in wall_keep_outs(gen, side, t):
		if k.x < path.y - TOUCH and k.y > path.x + TOUCH:
			return "its lit wall isn't clear over its wall run (%.1f-%.1f m)" % [k.x, k.y]
	var clear: float = t.other_wall_clear_seconds * gen.speed
	if lay.wall_gap_between(float(w["start"]) - clear + TOUCH, float(w["end"]) + clear - TOUCH, -side):
		return "the other wall has a gap beside it"
	return ""


## Player.grapple_save for a level with wall-run gaps (RunWorld sets it, `layout` bound): a runner pulled up out of a
## fall into a wall-run gap's holes (the grapple hook's save, GDD §8, or a revive's, GDD §4) is put on its lit wall
## (Player._pull_up: {"wall": side}), whose wall run carries them across; the gap is longer than the pull's leap, which
## would drop them back in. {} anywhere else: the save as it always was. DESIGN-TBD (docs/questions/j2.md).
static func grapple_save(player: Player, _cause: StringName, layout: LevelLayout) -> Dictionary:
	var w: Dictionary = layout.wall_run_gap_at(player.distance, SAVE_MARGIN)
	if w.is_empty():
		return {}
	return {"wall": int(w["side"])}
