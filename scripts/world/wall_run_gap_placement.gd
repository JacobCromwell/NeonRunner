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
## Every number is WallRunGapTuning's (data/tuning/wall_run_gaps.tres). With the shipped numbers the gap is 1.41 s of
## run (31.9 m at the Marketplace's 22.6 m/s, 35.2 m at the Golden Zone's 25), against about 1 s of run for the longest
## jump (a full jump, its jump grace, the dash all the way; 1.2 s with a speed pad's whole boost): no jump crosses it.
##
## When (place): from the rules (wall_run_gaps_rules.gd, which runs after every other feature's rules) and before the
## danger density pass, the planted cyborgs, the wider gaps, the fill pass, the zone doodads, the dash walls after them,
## the wall fences, the side wall gaps and the credits, from a stream of its own (rng_for(FEATURE)): every enemy, ceiling,
## pad, ramp, floor cut and wall piece the rules plan is there to keep off, and every pass after it keeps off it (the
## rules' doodad_keep_outs and fill_keep_outs, CyborgRules.obstacle_spans, on_wall_section, WallFencePlacement.keep_outs,
## WallGapPlacement.keep_outs). Where:
## - only in a level with the `wall_run_gaps` feature (from Marketplace 1; never in the first zones), never in a boss
##   arena (WallGapPlacement.is_boss_arena), never before the feature's start, between the run-up and the end-clear
##   stretch;
## - its whole clear stretch, from the run-in to the end of the landing floor, off everything that may not go
##   (floor_keep_outs, keep_outs_by_part): everything a wider gap's zone keeps off (WideGapPlacement.keeps_of: every
##   enemy's attack and the floor it uses, a floor cyborg's obstacle margin, each planned Resonator pulse, the rules'
##   keep-outs: a Gilded Sentinel's strike, a hover truck's stay, an Enforcer Truck's showing window and its chase
##   before it, a dash wall's footprint, a treasure stash; not a host's Bad Dream chase nor a heli drone's wave until
##   its first pad, whose slash and barrages hold off at run time while a crossing is in reach), every pad and its
##   lift, every ramp to the end
##   of the longest wall run it launches, speed pads, floor cuts' windows, the wider gaps' zones, fences that may not go
##   (pulsing ones, ones a fence generator powers), every ceiling and its landing zone (no ceiling overlaps it, nor a
##   ceiling's safe landing zone), and no pad's run-up over its gap;
## - its lit wall whole and clear (wall_keep_outs) from wall_clear_seconds before the lit stretch to past the longest
##   wall run a runner may take over the gap (claws, the dash and a save onto the wall at its far edge, wall_clear_seconds
##   more): no sign (it blocks the entry and hurts), no wall enemy (a window cyborg, a vent's screech, a Gilded Sentinel's
##   wall section), no wall fence or side wall gap; the other wall stays whole (no side wall gap) from
##   other_wall_clear_seconds before the gap to as far past it;
## - what is in its way goes (_removable): plain pieces (holes, fences that may go, zone doodads that aren't a stash's:
##   taking content out never makes a level unfair) and small enemies (_small_enemies: a plain floor cyborg, a manhole
##   screech, never the level's first of its kind), the danger density pass counting the level's enemies after it; of
##   the spots that fit near where one is due, the one that takes the least out (_cost), the nearest of those.
## How many: about one per spacing_seconds_easy to _hard of run (by the difficulty halfway through the stretch), each
## due at a seeded spot of its share and placed within search_seconds of it, min_spacing_seconds apart; in the level
## that brings them in the first as soon as one fits past the feature's start. A level with the feature gets at least
## one (anywhere past its start; as a last resort with one big encounter taken out of its way, _make_room, and then
## with the signs on its lit wall's stretch taken off, _signs_go), or a warning.
##
## Never in a boss arena, quick play's prototype level or a level without the feature: those draw nothing and are built
## exactly as before. DESIGN-TBD (docs/questions/j2.md): every number, the lit wall's look, where the feature starts,
## what may make way, a grapple's or a revive's save onto the lit wall (grapple_save).

const FEATURE: String = "wall_run_gaps"
## Claws lengthen wall runs (PowerupTuning.claws_wall_time_multiplier) and the dash carries a wall runner further.
const POWERUPS_PATH: String = "res://data/tuning/powerups.tres"
const CyborgRules = preload("res://scripts/enemies/cyborg_rules.gd")
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
## What taking one small enemy out of a wall-run gap's way costs (_cost), against 1 for a plain piece: a spot that
## takes out a few holes, fences or doodads wins over one that takes out an enemy.
const ENEMY_WEIGHT: int = 4
## The big encounters the last resort may take out, one, to fit a level's only wall-run gap (_make_room): each leaves
## nothing behind (a Resonator's visit, a Gilded Sentinel, a hover truck, whose ramp stays as any ramp).
const MAKE_ROOM_TYPES: PackedStringArray = ["resonator", "gilded_sentinel", "hover_truck"]
## In the level that brings them in, its first comes as soon as one fits: each unit of what a spot takes out of its way
## (_cost) weighs as this many seconds of run later (_fit).
const INTRO_COST_SECONDS: float = 1.0


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
	## keep_outs_by_part): what `run_ups` keep off (the gap), what the rest keep off (`whole`, `ceilings`, `landings`:
	## the whole clear stretch); and its lit wall's stretch (`wall`, wall_path).
	func part(name: String) -> Vector2:
		match name:
			"run_ups":
				return Vector2(approach + window, approach + window + gap)
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
	## What may go (_removable): {span, list, piece, weight}, by where they start; their starts, and the longest one's
	## length (_cost looks them up by start).
	var pieces: Array[Dictionary] = []
	var starts := PackedFloat64Array()
	var longest: float = 0.0
	## Plain pieces and enemies taken out, and each wall-run gap's cost (_cost) as placed.
	var taken_out: int = 0
	var enemies_out: int = 0
	var costs: Array[int] = []
	## What the last resort took out (_make_room): "type at distance", or "".
	var made_room: String = ""
	## The last resort's last step (_signs_go): the lit wall's signs may go too (wall_keep_outs leaves them out), and
	## how many went.
	var signs_go: bool = false
	var signs_out: int = 0

	## Sets what may go (_removable's), sorted by where it starts.
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
## the level has no `wall_run_gaps` (or is a boss arena); else {target (how many were due), placed (how many),
## taken_out (plain pieces that went), enemies_taken_out, costs (each one's _cost as placed), constraints (why fewer,
## or none, if so), ms (how long the pass took, for the review tools)}.
static func place(gen: LevelGenerator) -> Dictionary:
	var lay: LevelLayout = gen.layout
	lay.wall_run_gaps.clear()
	if not gen.config.has_feature(FEATURE) or WallGapPlacement.is_boss_arena(gen.config):
		return {}
	var t0: int = Time.get_ticks_usec()
	var p := _Pass.new()
	p.gen = gen
	p.t = tuning()
	p.shape = shape_of(gen, p.t)
	var constraints: PackedStringArray = []
	if p.shape.gap <= EPSILON:
		constraints.append("no gap: the lit stretch and the exit margin take the whole wall run")
		return {"placed": 0, "taken_out": 0, "costs": [], "constraints": constraints}
	var rng: RandomNumberGenerator = gen.rng_for(FEATURE)
	_survey(p)
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
		var fit: Dictionary = {}
		if introduces and k == 0:
			# The level that brings them in meets its first as soon as one fits past the feature's start, each unit of
			# what it takes out of its way weighing as INTRO_COST_SECONDS of run later.
			fit = _fit(p, from, minf(from + search, last), side, from, INTRO_COST_SECONDS * v)
		else:
			fit = _fit(p, maxf(due - search, from), minf(due + search, last), side, due)
		if not fit.is_empty():
			_add(p, fit)
	if lay.wall_run_gaps.is_empty() and last >= from:
		# GDD §5: a feature a level has appears in it. Anywhere past its start, the earliest that needs the least taken
		# out; as a last resort, with one big encounter taken out of its way (_make_room).
		var side: int = -1 if rng.randf() < 0.5 else 1
		var fit: Dictionary = _fit(p, from, last, side, from)
		if fit.is_empty():
			fit = _make_room(p, from, last, side)
		if fit.is_empty():
			fit = _signs_go(p, from, last, side)
		if not fit.is_empty():
			_add(p, fit)
	if lay.wall_run_gaps.is_empty():
		constraints.append("no room anywhere past its start (%.0f m); most room without: %s" % [from, _blockers(p, from, last)])
		gen.warnings.append("wall-run gaps: no fair room anywhere for one (every feature should appear, GDD §5)")
	elif lay.wall_run_gaps.size() < count:
		constraints.append("only %d of %d fit: no room near the others' spots" % [lay.wall_run_gaps.size(), count])
	if p.made_room != "":
		constraints.append("the last resort took out %s to make room for one" % p.made_room)
	if p.signs_out > 0:
		constraints.append("the last resort took %d sign(s) off its lit wall to make room for one" % p.signs_out)
	if p.taken_out > 0:
		GeneratorRules.keep_powered(gen)
	lay.wall_run_gaps.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["start"]) < float(b["start"]))
	return {"target": count, "placed": lay.wall_run_gaps.size(), "taken_out": p.taken_out,
		"enemies_taken_out": p.enemies_out, "signs_taken_out": p.signs_out, "costs": p.costs, "constraints": constraints,
		"ms": (Time.get_ticks_usec() - t0) / 1000}


## Reads what the pass keeps off from the level as it stands (keep_outs_by_part, wall_keep_outs) and what may go
## (_removable), into `p`.
static func _survey(p: _Pass) -> void:
	var by_part: Dictionary = keep_outs_by_part(p.gen)
	# A stretch the build keeps for the wider gaps (LevelGenerator.wall_run_gap_reserve, wide_gap_reserve) too.
	by_part["whole"].append_array(p.gen.wall_run_gap_reserve)
	for name: String in by_part:
		p.parts[name] = WallFencePlacement.merged(by_part[name])
	p.walls = [WallFencePlacement.merged(wall_keep_outs(p.gen, -1, p.t, p.signs_go)),
		WallFencePlacement.merged(wall_keep_outs(p.gen, 1, p.t, p.signs_go))]
	p.set_pieces(_removable(p.gen))


## The last resort for a level's only wall-run gap (place), where none fits anywhere past its start even with what may
## go taken out: one big encounter that leaves nothing behind (MAKE_ROOM_TYPES: a Resonator's visit, a Gilded Sentinel,
## a hover truck; never the level's first of its kind, so every feature keeps its introduction, and never the last of
## one) is taken out of the level, each in turn from the level's start, and a spot looked for without it (_fit, from
## `from` to `last`, its lit wall on `side` first); the first that leaves room stays out. Taking content out never
## makes a level unfair, and the danger density pass counts the level's enemies after it. {} if none does (the level
## is as it was).
static func _make_room(p: _Pass, from: float, last: float, side: int) -> Dictionary:
	var lay: LevelLayout = p.gen.layout
	for e: Dictionary in _room_candidates(p.gen):
		var i: int = -1
		for k: int in lay.enemies.size():
			if is_same(lay.enemies[k], e):
				i = k
				break
		if i < 0:
			continue
		lay.enemies.remove_at(i)
		_survey(p)
		var fit: Dictionary = _fit(p, from, last, side, from)
		if not fit.is_empty():
			p.enemies_out += 1
			p.made_room = "a %s at %.0f m" % [String(e["type"]), float(e["at"])]
			return fit
		lay.enemies.insert(i, e)
	_survey(p)
	return {}


## The last resort's last step (place), where even a big encounter taken out leaves no room (_make_room): the signs on
## its lit wall's stretch (wall_path) go too, so a level with the feature still has one. A sign blocks the step onto the
## wall and hurts a wall runner (GDD §3); it is the patterns' wall content, and taking content out never makes a level
## unfair. The spot is found as by _fit with the lit walls' signs left out of the way (p.signs_go), from `from` to
## `last`, its lit wall on `side` first; _add takes the signs off (each counted in p.signs_out, the report's
## constraints say so). {} if none fits even so (the pass is as it was). DESIGN-TBD (docs/questions/j2.md item 8).
static func _signs_go(p: _Pass, from: float, last: float, side: int) -> Dictionary:
	p.signs_go = true
	_survey(p)
	var fit: Dictionary = _fit(p, from, last, side, from)
	p.signs_go = false
	if fit.is_empty():
		_survey(p)
		return {}
	fit["signs_go"] = true
	return fit


## The big encounters _make_room may take out (MAKE_ROOM_TYPES), in the level's order: every one but the level's first
## of its kind (LevelGenerator.feature_positions).
static func _room_candidates(gen: LevelGenerator) -> Array[Dictionary]:
	var firsts: Dictionary = {}
	for type: String in MAKE_ROOM_TYPES:
		var at: Array[float] = LevelGenerator.feature_positions(gen.layout, type)
		firsts[type] = at[0] if not at.is_empty() else INF
	var out: Array[Dictionary] = []
	for e: Dictionary in gen.layout.enemies:
		var type: String = String(e.get("type", ""))
		if MAKE_ROOM_TYPES.has(type) and absf(float(e["at"]) - float(firsts[type])) > EPSILON:
			out.append(e)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["at"]) < float(b["at"]))
	return out


## How many wall-run gaps a level is due (see the header): one per spacing_seconds_easy to _hard (by the level's
## difficulty halfway between `from` and `last`) over that stretch, rounded, at least one.
static func planned_count(gen: LevelGenerator, t: WallRunGapTuning, from: float, last: float) -> int:
	var mid: float = (from + last) * 0.5
	var difficulty: float = gen.difficulty_at(clampf(mid / maxf(gen.layout.length, 1.0), 0.0, 1.0))
	var spacing: float = WallRunGapTuning.by_difficulty(t.spacing_seconds_easy, t.spacing_seconds_hard, difficulty)
	return maxi(1, roundi((last - from) / maxf(spacing * gen.speed, 1.0)))


## The wall-run gap (make) whose clear run-in starts in [lo, hi] that fits (_starts) and needs the least taken out of
## its way (_cost), the nearest `target` of those; or, with `per_cost` (metres), the one nearest `target` counting each
## unit of cost as that many metres further (an introduction: as soon as one fits, INTRO_COST_SECONDS). Its lit wall on
## `side` if one fits there, else on the other. {} if none fits. The entry carries its cost under "cost" (taken off
## when it's added).
static func _fit(p: _Pass, lo: float, hi: float, side: int, target: float, per_cost: float = 0.0) -> Dictionary:
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
				var better: bool = cost < best_cost or (cost == best_cost and off < best_off - EPSILON)
				if per_cost > 0.0:
					var score: float = off + cost * per_cost
					var best_score: float = best_off + best_cost * per_cost
					better = score < best_score - EPSILON or (absf(score - best_score) <= EPSILON and cost < best_cost)
				if better:
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


## What a wall-run gap whose clear run-in starts at `a` takes out of its way (_removable): 1 for each plain piece,
## ENEMY_WEIGHT for each small enemy.
static func _cost(p: _Pass, a: float) -> int:
	var to: float = a + p.shape.zone()
	var n: int = 0
	# Only a piece starting within its longest length before `a` can reach in.
	var i: int = p.starts.bsearch(a - p.longest - EPSILON)
	while i < p.pieces.size() and p.starts[i] < to:
		if (p.pieces[i]["span"] as Vector2).y > a:
			n += int(p.pieces[i]["weight"])
		i += 1
	return n


## Adds wall-run gap `w` (_fit): takes out what is in its way (_removable: the plain pieces in its clear stretch, the
## small enemies whose keep-out reaches it), cuts every lane from its start to its end (holes marked
## LevelLayout.WALL_RUN_HOLE: the credit pass gives them no risky credit), and keeps the next ones off it. It runs
## before the danger density pass, which counts the level's enemies after it.
static func _add(p: _Pass, w: Dictionary) -> void:
	var gen: LevelGenerator = p.gen
	var lay: LevelLayout = gen.layout
	var zone := Vector2(float(w["approach"]), float(w["landing"]))
	var cost: int = int(w.get("cost", 0))
	w.erase("cost")
	if bool(w.get("signs_go", false)):
		# The last resort's last step (_signs_go): the signs on its lit wall's stretch go.
		w.erase("signs_go")
		var path: Vector2 = wall_path(w, gen.speed, p.t)
		var kept: Array[Dictionary] = []
		for s: Dictionary in lay.signs:
			if int(s["side"]) == int(w["side"]) and float(s["start"]) < path.y and float(s["end"]) > path.x:
				p.signs_out += 1
				continue
			kept.append(s)
		lay.signs.assign(kept)
	for k: Dictionary in p.pieces:
		var s: Vector2 = k["span"]
		if s.x >= zone.y or s.y <= zone.x:
			continue
		match String(k["list"]):
			"gaps":
				p.taken_out += _erase(lay.gaps, k["piece"])
			"fences":
				p.taken_out += _erase(lay.fences, k["piece"])
			"doodads":
				p.taken_out += _erase(lay.doodads, k["piece"])
			"enemies":
				p.enemies_out += _erase(lay.enemies, k["piece"])
	p.costs.append(cost)
	_set_holes(lay, w, true)
	lay.wall_run_gaps.append(w)
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


## What a wall-run gap may take out of its way: the plain pieces, holes (but a wider gap's or another wall-run gap's),
## fences (but pulsing ones and ones a fence generator powers) and zone doodads (but a treasure stash's), and the small
## enemies (_small_enemies) whose keep-out (_enemy_span) reaches it. Each {span (along the track), list (its
## LevelLayout list's name), piece, weight (_cost's: 1, ENEMY_WEIGHT for a small enemy)}.
static func _removable(gen: LevelGenerator) -> Array[Dictionary]:
	var lay: LevelLayout = gen.layout
	var out: Array[Dictionary] = []
	var wide: Array[Vector2] = _wide_rows(gen)
	for g: Dictionary in lay.gaps:
		if LevelLayout.is_wall_run_hole(g) or _in_rows(g, wide):
			continue
		out.append({"span": Vector2(float(g["start"]), float(g["end"])), "list": "gaps", "piece": g, "weight": 1})
	var half: float = gen.tuning.fence_depth * 0.5
	for f: Dictionary in lay.fences:
		if not _fence_stays(gen, f):
			out.append({"span": Vector2(float(f["at"]) - half, float(f["at"]) + half), "list": "fences", "piece": f,
				"weight": 1})
	for d: Dictionary in lay.doodads:
		if not d.has("stash"):
			out.append({"span": Vector2(float(d["start"]), float(d["end"])), "list": "doodads", "piece": d, "weight": 1})
	var hooks: Dictionary = {}
	for e: Dictionary in _small_enemies(gen):
		out.append({"span": _enemy_span(gen, e, hooks), "list": "enemies", "piece": e, "weight": ENEMY_WEIGHT})
	return out


## The small enemies a wall-run gap may take out of its way, as a dash wall's introduction may (DashWallRules
## ._make_room; it runs before the danger density pass counts the level's enemies): floor cyborgs (never a host, whose
## chase is planned on it, nor one planted in a charge's path) and manhole screeches (never a wall vent's), never the
## first of its kind in the level (its feature's first, LevelGenerator.feature_positions: every feature keeps its
## introduction where it was, and never loses its last).
static func _small_enemies(gen: LevelGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var firsts: Dictionary = {}
	for feature: String in ["cyborg", "screech"]:
		var at: Array[float] = LevelGenerator.feature_positions(gen.layout, feature)
		firsts[feature] = at[0] if not at.is_empty() else INF
	for e: Dictionary in gen.layout.enemies:
		var type: String = String(e.get("type", ""))
		var params: Dictionary = e.get("params", {})
		var at: float = float(e["at"])
		match type:
			"cyborg":
				if bool(params.get("host", false)) or params.has(ChargePathPlacement.PARAM):
					continue
			"screech":
				if int(e.get("side", 0)) != 0 or String(params.get("source", "manhole")) == "vent":
					continue
			_:
				continue
		if absf(at - float(firsts[type])) > EPSILON:
			out.append(e)
	return out


## What a cyborg or a screech (the small enemies, _small_enemies, and the ones that stay) keeps a wall-run gap's clear
## stretch off, as a wider gap's zone keeps (WideGapPlacement.keeps_of): a floor cyborg its obstacle margin either side
## (CyborgRules.obstacle_margin_at; its walk and panic run keep it too) and KEEP_MARGIN more (the clear stretch is one
## of its obstacle spans once placed, CyborgRules.obstacle_spans, and the rules count a cyborg right at its margin as
## too near), any other its keep-out (LevelGenerator.enemy_keep_out) with the floor it uses
## (LevelGenerator.enemy_floor_span). `hooks` caches each type's rules script.
static func _enemy_span(gen: LevelGenerator, e: Dictionary, hooks: Dictionary) -> Vector2:
	var at: float = float(e["at"])
	if String(e.get("type", "")) == "cyborg":
		var ct := EnemyDirector.tuning_for("cyborg") as CyborgTuning
		var margin: float = (CyborgRules.obstacle_margin_at(ct, gen.pace) if ct != null else gen.metres(10.0)) + KEEP_MARGIN
		return Vector2(at - margin, at + margin)
	var span := Vector2(at, at)
	for k: Vector2 in [gen.enemy_keep_out(e, hooks), LevelGenerator.enemy_floor_span(e, gen.pace)]:
		if k.y >= k.x:
			span = Vector2(minf(span.x, k.x), maxf(span.y, k.y))
	return span


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
## particular order: {whole (no wall-run gap's clear stretch reaches one, in any lane), ceilings (each ceiling section:
## none overlaps the clear stretch), run_ups (each pad's run-up, clear floor in its lane a full jump long: kept off the
## gap only, as the pad and its lift keep off the whole), landings (each ceiling's landing zone: none overlaps the clear
## stretch, so no ceiling's rider comes down in it)}. `whole` is floor_keep_outs.
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
## keeps off the parts that need it, nor a heli drone's wave until its first pad, whose barrages hold off at run time
## while a crossing is in their reach, Drone._wall_run_in_reach), whole here (a wall-run gap is its own landing and
## take-off); and more:
## - each anti-grav pad and its lift (CeilingZones.pad_zone from the pad on): none lifts a runner off the clear stretch;
##   (a floor cyborg keeps its obstacle margin, the wider gaps' keep; its walk back and panic run stop that margin short
##   of the clear stretch, which is one of its obstacle spans once placed, CyborgRules.obstacle_spans;)
## - each ramp's longest wall run (claws, a speed pad's boost: WallFencePlacement.ramp_run_end): a runner it launches
##   never comes down into the clear stretch, or onto the lit wall, still on its run;
## - the wider gaps' zones, fences that may not go (pulsing ones, ones a fence generator powers) and a treasure stash's
##   doodads.
static func floor_keep_outs(gen: LevelGenerator) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for k: Dictionary in floor_keeps(gen):
		out.append(k["span"])
	return out


## floor_keep_outs with what each is, {span (Vector2), what (for the report: WideGapPlacement.keeps_of's, or "a pad's
## lift", "a ramp's wall run", "a treasure stash", "a wider gap", "a fence that stays", or an enemy's type)}.
static func floor_keeps(gen: LevelGenerator) -> Array[Dictionary]:
	var lay: LevelLayout = gen.layout
	var out: Array[Dictionary] = []
	for k: Dictionary in WideGapPlacement.keeps_of(gen):
		var what: String = String(k["what"])
		# The wall-run gaps' own clear stretches (wall_run_gaps_rules.gd) are kept apart by the pass itself; the cyborgs
		# and screeches come below. A heli drone's wave until its first pad (drone_rules.gd keep_out) needn't keep off:
		# its barrages hold off at run time while a crossing is in their reach (Drone._wall_run_in_reach), as a Bad
		# Dream's slash does over a host's chase, which the keeps leave out.
		if what in ["a fence", "a doodad", "a ceiling", "a ceiling's landing zone", "a pad", FEATURE, "a cyborg", "screech",
				"drone"]:
			continue
		out.append({"span": k["span"], "what": what})
	# Every cyborg and screech but the small enemies that may go (_removable), with the keep-out a wider gap's zone
	# keeps.
	var small: Array[Dictionary] = _small_enemies(gen)
	var hooks: Dictionary = {}
	for e: Dictionary in lay.enemies:
		var type: String = String(e.get("type", ""))
		if (type == "cyborg" or type == "screech") and not small.has(e):
			out.append({"span": _enemy_span(gen, e, hooks), "what": type})
	for pad: Dictionary in lay.pads:
		var at: float = float(pad["at"])
		out.append({"span": Vector2(at, gen.zones.pad_zone(at).y), "what": "a pad's lift"})
	for r: Dictionary in lay.ramps:
		var at: float = float(r["at"])
		out.append({"span": Vector2(at, maxf(WallFencePlacement.ramp_run_end(gen, r), at + gen.tuning.ramp_length)),
			"what": "a ramp's wall run"})
	for d: Dictionary in lay.doodads:
		if d.has("stash"):
			out.append({"span": Vector2(float(d["start"]), float(d["end"])), "what": "a treasure stash"})
	var wt: WideGapTuning = WideGapPlacement.tuning()
	for span: Vector2 in _wide_rows(gen):
		out.append({"span": WideGapPlacement.zone_of(gen, wt, span), "what": "a wider gap"})
	var half: float = gen.tuning.fence_depth * 0.5
	for f: Dictionary in lay.fences:
		if _fence_stays(gen, f):
			out.append({"span": Vector2(float(f["at"]) - half, float(f["at"]) + half), "what": "a fence that stays"})
	return out


## The stretches of wall `side` a wall-run gap's lit wall may not reach over its wall path (see the header): its signs,
## its wall fences (a fence deep: the path carries the margins, wall_clear_seconds either side), its side wall gaps, and
## its wall enemies (a window cyborg's window, a vent's screech, any other) with WallGapTuning.wall_enemy_seconds either
## side, a Gilded Sentinel's whole wall section (WallFencePlacement.sentinel_wall_section). Vector2, in no particular
## order. With `without_signs`, its signs are left out (the last resort's last step, _signs_go).
static func wall_keep_outs(gen: LevelGenerator, side: int, t: WallRunGapTuning = null,
		without_signs: bool = false) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for k: Dictionary in wall_keeps(gen, side, t, without_signs):
		out.append(k["span"])
	return out


## wall_keep_outs with what each is, {span (Vector2), what ("a sign", "a wall fence", "a wall gap", or the wall enemy's
## type)}; without its signs with `without_signs`.
static func wall_keeps(gen: LevelGenerator, side: int, t: WallRunGapTuning = null,
		without_signs: bool = false) -> Array[Dictionary]:
	var tt: WallRunGapTuning = t if t != null else tuning()
	var lay: LevelLayout = gen.layout
	var v: float = gen.speed
	var clear: float = tt.wall_clear_seconds * v
	var enemy: float = WallGapPlacement.tuning().wall_enemy_seconds * v
	var half: float = gen.tuning.fence_depth * 0.5
	var out: Array[Dictionary] = []
	for s: Dictionary in lay.signs:
		if int(s["side"]) == side and not without_signs:
			out.append({"span": Vector2(float(s["start"]), float(s["end"])), "what": "a sign"})
	for wf: Dictionary in lay.wall_fences:
		if int(wf["side"]) == side:
			out.append({"span": Vector2(float(wf["at"]) - half, float(wf["at"]) + half), "what": "a wall fence"})
	for g: Dictionary in lay.wall_gaps:
		if int(g["side"]) == side:
			out.append({"span": Vector2(float(g["start"]), float(g["end"])), "what": "a wall gap"})
	for e: Dictionary in lay.enemies:
		if int(e.get("side", 0)) != side:
			continue
		var at: float = float(e["at"])
		var type: String = String(e.get("type", ""))
		out.append({"span": Vector2(at - enemy, at + enemy), "what": type})
		if type == "gilded_sentinel":
			var section: Vector2 = WallFencePlacement.sentinel_wall_section(gen, e)
			out.append({"span": Vector2(section.x - clear, section.y + clear), "what": type})
	return out


## What keeps any wall-run gap from fitting with its clear run-in starting in [from, last] (place's constraints, when
## none does): the kinds of keep-out (floor_keeps', a part's, wall_keeps') that, left out, would leave the most room
## for one, as "what (metres of starts it would free)", the three that would free any, most first.
static func _blockers(p: _Pass, from: float, last: float) -> String:
	var ground: Array[Dictionary] = []
	var o: Vector2 = p.shape.part("whole")
	for k: Dictionary in floor_keeps(p.gen):
		var s: Vector2 = k["span"]
		ground.append({"range": Vector2(s.x - o.y, s.y - o.x), "what": k["what"]})
	var by_part: Dictionary = keep_outs_by_part(p.gen)
	for name: String in ["ceilings", "run_ups", "landings"]:
		var po: Vector2 = p.shape.part(name)
		for s: Vector2 in by_part[name]:
			ground.append({"range": Vector2(s.x - po.y, s.y - po.x), "what": name})
	var w: Vector2 = p.shape.part("wall")
	var walls: Array = []
	for side: int in [-1, 1]:
		var list: Array[Dictionary] = []
		for k: Dictionary in wall_keeps(p.gen, side, p.t):
			var s: Vector2 = k["span"]
			list.append({"range": Vector2(s.x - w.y, s.y - w.x), "what": "%s (wall)" % k["what"]})
		walls.append(list)
	var whats: Dictionary = {}
	for k: Dictionary in ground + walls[0] + walls[1]:
		whats[String(k["what"])] = true
	var room: Array = []
	for what: String in whats:
		var free_floor: Array[Vector2] = _free_without(ground, what, from, last)
		var free_sides: Array[Vector2] = _free_without(walls[0], what, from, last)
		free_sides.append_array(_free_without(walls[1], what, from, last))
		var metres: float = 0.0
		for a: Vector2 in free_floor:
			for b: Vector2 in WallFencePlacement.merged(free_sides):
				metres += maxf(minf(a.y, b.y) - maxf(a.x, b.x), 0.0)
		if metres > EPSILON:
			room.append([metres, what])
	room.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	var out: PackedStringArray = []
	for r: Array in room.slice(0, 3):
		out.append("%s (%.0f m)" % [r[1], r[0]])
	return ", ".join(out) if not out.is_empty() else "no one kind of keep-out alone"


## The stretches of [from, to] no range of `keeps` ({range, what}) but those of `what` covers.
static func _free_without(keeps: Array, what: String, from: float, to: float) -> Array[Vector2]:
	var blocked: Array[Vector2] = []
	for k: Dictionary in keeps:
		if String(k["what"]) != what:
			blocked.append(k["range"])
	return LevelGenerator.free_stretches(WallFencePlacement.merged(blocked), from, to)


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
	var hooks: Dictionary = {}
	for e: Dictionary in _small_enemies(gen):
		var s: Vector2 = _enemy_span(gen, e, hooks)
		if s.x < zone.y and s.y > zone.x:
			return "a %s (at %.1f m) keeps off its clear stretch (%.1f-%.1f m)" % [String(e["type"]), float(e["at"]), s.x, s.y]
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


## What a finished build of `gen` keeps for its wider gaps in the one more build that may make them room
## (LevelGenerator._make_wide_gap_room, LevelGenerator.wall_run_gap_reserve): where the build's wider gaps fall short of
## the level's count (WideGapPlacement.rows_of) and it has wall-run gaps, its first one's clear stretch (keep_out),
## which never gives way to them in their own pass (set_aside), so its wall-run gap goes elsewhere. [] otherwise, and
## in the level that brings the feature in (its first stays where it is introduced).
static func wide_gap_reserve(gen: LevelGenerator) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var lay: LevelLayout = gen.layout
	if gen.config.wide_gaps <= 0 or lay.wall_run_gaps.is_empty() or gen.config.feature_starts.has(FEATURE) \
			or WideGapPlacement.rows_of(gen).size() >= gen.config.wide_gaps:
		return out
	var first: Dictionary = lay.wall_run_gaps[0]
	for w: Dictionary in lay.wall_run_gaps:
		if float(w["start"]) < float(first["start"]):
			first = w
	out.append(keep_out(first))
	return out


## For a later pass that falls short of its own count (the wider gaps, WideGapPlacement.place; the dash walls,
## DashWallRules.after_doodads): takes every wall-run gap but the level's first out of `gen`'s layout (its entry and its
## holes; the first never gives way, so a level with the feature keeps one) and returns them, so the pass can look again
## with them out of its way. put_back puts back each one that still fits. [] where the level has fewer than two.
## DESIGN-TBD (docs/questions/j2.md): which gives way where a level has room for only one.
static func set_aside(gen: LevelGenerator) -> Array[Dictionary]:
	var lay: LevelLayout = gen.layout
	var out: Array[Dictionary] = []
	if lay.wall_run_gaps.size() < 2:
		return out
	lay.wall_run_gaps.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["start"]) < float(b["start"]))
	out.assign(lay.wall_run_gaps.slice(1))
	lay.wall_run_gaps.resize(1)
	for w: Dictionary in out:
		_set_holes(lay, w, false)
	return out


## Puts back each wall-run gap of `aside` (set_aside's) where the pass that set it aside left its way as it was (problem
## finds nothing: its clear stretch, its lit wall, the other wall) and its clear stretch reaches none of `keep_off`
## (what that pass plans that isn't in the layout yet: the wider gaps' zones, whose own rows they make longer only after
## the fill pass, WideGapPlacement.widen_deferred); the rest stay out, given way to `by` (for the report:
## LevelGenerator.wall_run_gap_result's `placed`, `gave_way` and constraints). Returns how many stayed out.
static func put_back(gen: LevelGenerator, aside: Array[Dictionary], by: String, keep_off: Array[Vector2] = []) -> int:
	var lay: LevelLayout = gen.layout
	var out: int = 0
	for w: Dictionary in aside:
		lay.wall_run_gaps.append(w)
		_set_holes(lay, w, true)
		var reaches: bool = false
		for k: Vector2 in keep_off:
			reaches = reaches or (k.x < float(w["landing"]) - TOUCH and k.y > float(w["approach"]) + TOUCH)
		if reaches or problem(gen, w) != "":
			lay.wall_run_gaps.erase(w)
			_set_holes(lay, w, false)
			out += 1
	lay.wall_run_gaps.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["start"]) < float(b["start"]))
	var report: Dictionary = gen.wall_run_gap_result
	if out > 0 and not report.is_empty():
		report["placed"] = lay.wall_run_gaps.size()
		report["gave_way"] = int(report.get("gave_way", 0)) + out
		var constraints: PackedStringArray = report.get("constraints", PackedStringArray())
		constraints.append("%d gave way to %s" % [out, by])
		report["constraints"] = constraints
	return out


## Adds wall-run gap `w`'s holes, one in every lane over its gap, to `lay`'s (or, with `present` false, takes them out).
static func _set_holes(lay: LevelLayout, w: Dictionary, present: bool) -> void:
	if present:
		for lane: int in lay.lane_count:
			lay.gaps.append({"lane": lane, "start": float(w["start"]), "end": float(w["end"]), LevelLayout.WALL_RUN_HOLE: true})
		return
	var kept: Array[Dictionary] = []
	for g: Dictionary in lay.gaps:
		if LevelLayout.is_wall_run_hole(g) and absf(float(g["start"]) - float(w["start"])) < 0.01 \
				and absf(float(g["end"]) - float(w["end"])) < 0.01:
			continue
		kept.append(g)
	lay.gaps.assign(kept)


## Player.grapple_save for a level with wall-run gaps (RunWorld sets it, `layout` bound): a runner pulled up out of a
## fall into a wall-run gap's holes (the grapple hook's save, GDD §8, or a revive's, GDD §4) is put on its lit wall
## (Player._pull_up: {"wall": side}), whose wall run carries them across; the gap is longer than the pull's leap, which
## would drop them back in. {} anywhere else: the save as it always was. DESIGN-TBD (docs/questions/j2.md).
static func grapple_save(player: Player, _cause: StringName, layout: LevelLayout) -> Dictionary:
	var w: Dictionary = layout.wall_run_gap_at(player.distance, SAVE_MARGIN)
	if w.is_empty():
		return {}
	return {"wall": int(w["side"])}
