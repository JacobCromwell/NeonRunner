extends RefCounted
## Generator rules for falling gantryways (task Q3; GDD §5, Zone 9, the owner, October 21, 2026): "a gantryway is an upper
## walkway over one lane only, looking like a ceiling section, moderate in length: a little shorter than ceiling sections
## usually are. Pillars stand in the floor lanes holding them up. Dashing through a pillar knocks down its long section of
## gantryway. It takes about a second to fall. When it lands, it destroys any enemy in its path. A runner under it when it
## lands is hit"; proposed: the pillar stands in the gantryway's own lane under its near end, so a runner who dashes
## through it is heading under it; knocking one down is never required. Not an enemy: a set piece of the track with no
## patterns, placed with the rules (as the dash walls and the debris maze are) so the level makes room for it before it
## fills up. Its look and its fall are the track's (Gantryway, scripts/world/gantryway.gd); its numbers are
## GantrywayTuning's (data/tuning/gantryways.tres); how many a level asks for is LevelConfig.gantryways.
##
## A gantryway in lane L, its pillar's front at F (Plan; every window as seconds at the level's run speed, or at the
## fastest a runner comes through a pillar, `fastest`: the run speed, the dash's bonus and the most a speed pad's or a
## ramp's fading boost adds, so a faster zone keeps every one of them):
## - L is an inner lane (never by a side wall: no wall runner meets its pillar or stands beside its walkway, and a
##   runner under it has a lane to step into on either side). DESIGN-TBD (docs/questions/q3.md).
## - Its pillar is a zone doodad's small box (PILLAR_SIZE) in L from F, pushing into the lane on its `side` like any
##   doodad (Player._check_doodads), and kept like one (LevelGenerator._doodad_lane_fits' rules): L holds nothing from its
##   push's lead and a lane switch's room before it; the lane beside it on the other side holds nothing until a push's
##   landing and a reaction past it (a caught corner pushes back the way the runner came: `corner`). (GDD §5's proposals:
##   one pillar under the near end, pushing like a doodad; DESIGN-TBD, docs/questions/q3.md 3.)
## - Its walkway hangs at the ceilings' height over L from NEAR_OVERHANG before F, length_seconds of run long. L holds
##   nothing under it (no hole, fence, pad, speed pad, floor cut's lane window, doodad, or floor enemy but the one planted
##   under it, below) from the pillar's lead to a lane switch's room past its far end: it lands flat on whole floor.
## - Its calm stretch, from the pillar's lead to `calm` past F (the fall at the fastest, then escape_after_seconds more:
##   calm_length): the lane on the pillar's side (the step out's) holds nothing (as L's pieces above, an anti-grav pad's
##   zone too), and every lane holds no floor cut's window, dash wall, wider gap's zone, quiet stretch or what the rules
##   keep in every lane (a Bad Dream's chase, a wall-run gap's clear stretch, a treasure stash's floor, an Enforcer Truck's
##   showing window), and no Octodog's planned charge (its window waits for a clear stretch, Octodog.window_clear, which
##   counts the calm stretch: LevelLayout.doodad_between). Every enemy that holds an attack by a doodad holds it by the
##   calm stretch too (doodad_between: a cyborg's bolts, CyborgGun.path_clear; an Octodog's lunge; a heli drone's
##   barrage, Drone._doodad_in_reach), so a runner who dashed the pillar steps out under no fire, on every attempt. Its
##   introduction (the level's first where the level gives the feature a start: Frost Foundry) keeps both lanes beside
##   it clear for the whole calm stretch (intro_both_sides: an easy first one, task Q3's brief, DESIGN-TBD
##   docs/questions/q3.md). No cyborg stands within its obstacle margin of the pillar, in any lane (CyborgRules: a pillar
##   is a doodad).
## - No ceiling over L or the lanes beside it, nor its landing zone, from the pillar's lead to past the walkway's far end
##   (the walkway hangs at a ceiling's height and looks like a ceiling section, but is never walked on: nobody rides a
##   ceiling beside it, nor drops off one into its step out). A ceiling over lanes further out may stand meanwhile, its
##   pads in its own lanes.
## - No wall-run gap's stretch (WallRunGapPlacement.keep_out: its clear run-in to its landing floor, with its margins) from
##   the pillar's lead to past the walkway's far end and the calm stretch's end, in any lane: a wall-run gap keeps every
##   rule's keep-outs off it whatever lane they name (WallRunGapPlacement.problem), and these come after it. Nor within
##   the planted cyborg's obstacle margin.
## - Within the level: the pillar's lead past the run-up (and past the feature's start), the walkway's end before the
##   end-clear stretch; pillars spacing_seconds apart.
## Plain holes and fences in those windows (never a pulsing fence, one a fence generator powers, or a wall-run gap's hole)
## are taken out to make room where clear_plain_pieces allows (taking content out never makes a level unfair); a spot
## that needs nothing taken out is preferred.
## The enemy beneath (plant_cyborg; GDD §5, Zone 9: "it destroys any enemy in its path", and its level schedule row:
## "dash a pillar to drop a one-lane walkway on the enemies below"; one under every gantryway is task Q3's proposal,
## DESIGN-TBD docs/questions/q3.md): a plain floor cyborg (never a host or the panic variant) planted in L under the
## walkway, standing where it is put (params `stand`), past where the fastest runner who stays in L is as it lands by
## crush_margin_seconds and as much before the walkway's far end (so a runner who stays in the lane is hit, or the armor
## takes it, before they could reach it), keeping a cyborg's obstacle margin (CyborgRules) and every ceiling's safe floor
## (CeilingZones), holding its fire from hold_before_seconds before the pillar until the calm stretch is over
## (`hold_fire`, CyborgGun.hold). Its params name its gantryway (PARAM): LevelGenerator.feature_positions counts it out of
## the level's own `cyborg` encounters, as it counts a cyborg planted in a charge's path. A spot where none fits is taken
## only where no other is.
##
## How many, and where: up to LevelConfig.gantryways. A level that gives the feature a start introduces it at the best
## fair spot (both lanes beside it clear) within intro_window_seconds from there, taking the fewest plain pieces out, then
## the earliest; the rest spread through the level past it (a part each, a seeded spot aimed for in the part, the best
## fair spot there), then the best of the rest. Its own random stream (LevelGenerator.rng_for), after every other
## feature's rules (RUN_AFTER), so the passes before it place exactly what they did; a level without the feature draws
## nothing and is built byte for byte as before.
##
## What keeps off them after the rules (doodad_keep_outs, fill_keep_outs, after_fill): the calm stretch in every lane (the
## danger density pass, the wider gaps, the cyborgs planted in charge paths, the fill pass, the zone doodads), and L from
## there to past the walkway's end (the zone doodads and the danger density pass keep the lane; the fill pass's pieces in
## it are taken out after it, after_fill, as a hover truck's lane is cleared of them); the credits keep out of L over the
## calm stretch (LevelLayout.doodad_between). problems() re-checks a finished layout (LayoutChecks.check_gantryways).
## DESIGN-TBD (docs/questions/q3.md): every number, inner lanes only, the planted cyborg.

const FEATURE: String = "gantryway"
## Every feature whose rules place, move or drop enemies, plan charges or cuts, or add ceilings, pads, ramps or set
## pieces: the gantryways are planned on the level's final rules track.
const RUN_AFTER: Array[String] = ["ramps", "ceilings", "pulsing", "speed_pads", "cyborg", "window_cyborg", "host",
	"hover_truck", "octodog", "screech", "screech_vents", "drone", "generator", "wall_fences", "wall_fences_partial",
	"buzz_overdrive", "barnacle_turret", "tithe_collector", "resonator", "gilded_sentinel", "enforcer_truck",
	"floor_cutter", "treasure_stash", "fenced_ceiling", "dash_wall", "wall_run_gaps", "debris_maze", "centipede"]
const GeneratorRules = preload("res://scripts/enemies/generator_rules.gd")
const CyborgRules = preload("res://scripts/enemies/cyborg_rules.gd")
const POWERUPS_PATH: String = "res://data/tuning/powerups.tres"
const CYBORG: String = "cyborg"
const OCTODOG: String = "octodog"
## The planted cyborg's params key: its gantryway's id (as ChargePathPlacement.PARAM marks one in a charge's path).
const PARAM: String = "gantryway"
## The walkway's near end reaches this far before its pillar's front (metres): the pillar stands under it.
const NEAR_OVERHANG: float = 0.3
## The pillar's box: a small zone doodad's (LevelLayout.DOODAD_SIZES; MovementTuning.doodad_size), whose push it is.
const PILLAR_SIZE: StringName = Gantryway.PILLAR_SIZE
## Half a cyborg's body along the track (Cyborg.BODY_SIZE.z with room): where it starts, for the crush margins.
const CYBORG_HALF: float = 0.3
## Metres past the walkway's far end that no ceiling over its lane or beside it starts (nor its landing zone reaches
## back to): the walkway never runs on into a ceiling section.
const OVER_MARGIN: float = 1.0
## Spots tried for a planted cyborg, metres apart, from the nearest the pillar it may stand.
const PLANT_STEP: float = 1.0
## Fitting spots tried, best first, for one where a cyborg can be planted (a spot with none is taken only if no other is);
## for an introduction, which wants its enemy beneath (task Q3's brief: an easy first one with an enemy beneath,
## DESIGN-TBD docs/questions/q3.md), more.
const PLANT_TRIES: int = 60
const INTRO_TRIES: int = 600

## The enemy types an introduction may take out to make room for itself (_make_room): ones that leave nothing behind
## (never a host: its chase is planned on it).
const MAKE_ROOM_TYPES: PackedStringArray = ["cyborg", "window_cyborg", "generator", "octodog", "screech"]

## Review aid (tools/measure/gantryways.gd --why): print why an introduction found no spot.
static var debug: bool = false
## Review aid (tools/measure/gantryways.gd): microseconds apply() has taken, summed over every call since it was zeroed.
static var spent_usec: int = 0


## One level's gantryways, at its run speed: what each keeps (metres), and where on its track a pillar's front may stand,
## lane by lane. Fronts are tried on a grid (GantrywayTuning.search_step) from `lo` to `hi`. For each lane, the grid spots
## a piece in that lane blocks (`*_hard`) or costs a plain piece to take out (`*_cost`) as the gantryway's own lane
## (`own`), as the lane its pillar pushes into and a runner steps into (`esc`), as the lane on its pillar's other side
## (`corner`), and whether a ceiling over it reaches the walkway (`over`); `every` what blocks a spot in every lane.
class Plan:
	extends RefCounted
	var gen: LevelGenerator
	var t: GantrywayTuning
	var lanes: int = 3
	var lo: float = 0.0
	var hi: float = -1.0
	var step: float = 1.0
	## Before the pillar's front: its push's lead and a lane switch's room (LevelGenerator.doodad_lead_for,
	## doodad_lane_room).
	var before: float = 0.0
	var pillar: float = 1.4
	## The walkway's length, how far past the pillar's front its lane is kept (its far end and a lane switch's room), and
	## how far no ceiling over it or beside it reaches (its far end and OVER_MARGIN).
	var walkway: float = 0.0
	var lane_after: float = 0.0
	var over_after: float = 0.0
	## The calm stretch past the pillar's front (calm_length) and the corner's keep (the lane on the other side).
	var calm: float = 0.0
	var corner: float = 0.0
	var fastest: float = 0.0
	var clearing: bool = true
	## The fences a fence generator powers (powered_fences): never taken out.
	var powered: Array[Dictionary] = []
	var own_hard: Array[PackedInt32Array] = []
	var own_cost: Array[PackedInt32Array] = []
	var esc_hard: Array[PackedInt32Array] = []
	var esc_cost: Array[PackedInt32Array] = []
	var corner_hard: Array[PackedInt32Array] = []
	var corner_cost: Array[PackedInt32Array] = []
	var over_hard: Array[PackedInt32Array] = []
	var every := PackedInt32Array()
	## blocked()'s sums, by lane, side and both.
	var _blocked: Dictionary = {}

	## Grid spots from lo to hi.
	func size() -> int:
		return maxi(floori((hi - lo) / step) + 1, 0)

	func front_at(i: int) -> float:
		return lo + i * step

	func index_of(front: float) -> int:
		return clampi(roundi((front - lo) / step), 0, maxi(size() - 1, 0))

	## Marks in `marks` the grid spots whose window [F + a, F + b] reaches `span`.
	func mark(marks: PackedInt32Array, span: Vector2, a: float, b: float) -> void:
		var n: int = size()
		if n <= 0 or span.y < span.x:
			return
		var first: int = maxi(ceili((span.x - b - lo) / step - 0.0001), 0)
		var last: int = mini(floori((span.y - a - lo) / step + 0.0001), n - 1)
		for i: int in range(first, last + 1):
			marks[i] += 1

	## True if a gantryway in `lane` with its pillar's front at grid spot `i`, pushing (and its runner stepping out) to
	## `side`, fits (both lanes beside it clear over the calm stretch with `both`), `spacing` metres from every front of
	## `fronts`.
	func fits(lane: int, side: int, i: int, both: bool, fronts: Array[float], spacing: float) -> bool:
		var into: int = lane + side
		if lane < 1 or lane > lanes - 2 or into < 0 or into >= lanes or i < 0 or i >= size():
			return false
		if blocked(lane, side, both)[i] > 0:
			return false
		var f: float = front_at(i)
		for other_front: float in fronts:
			if absf(f - other_front) < spacing - 0.001:
				return false
		return true

	## What blocks a gantryway in `lane` pushing to `side` at each grid spot (fits, but for the spacing): every lane's,
	## its lane's, the step out's, the other side's (the corner's, or with `both` the calm stretch's), the ceilings over
	## it and beside it, and without `clearing` the plain pieces too, summed once a plan and kept.
	func blocked(lane: int, side: int, both: bool) -> PackedInt32Array:
		var key: int = (lane * 4 + (side + 1)) * 2 + (1 if both else 0)
		if _blocked.has(key):
			return _blocked[key]
		var out: PackedInt32Array = every.duplicate()
		var n: int = out.size()
		var parts: Array[PackedInt32Array] = [own_hard[lane], esc_hard[lane + side]]
		var other: int = lane - side
		if other >= 0 and other < lanes:
			parts.append(esc_hard[other] if both else corner_hard[other])
		for l: int in [lane - 1, lane, lane + 1]:
			if l >= 0 and l < lanes:
				parts.append(over_hard[l])
		if not clearing:
			parts.append(own_cost[lane])
			parts.append(esc_cost[lane + side])
			if other >= 0 and other < lanes:
				parts.append(esc_cost[other] if both else corner_cost[other])
		for part: PackedInt32Array in parts:
			for i: int in n:
				out[i] += part[i]
		_blocked[key] = out
		return out

	## Forgets what blocked() kept (the arrays it sums changed).
	func changed() -> void:
		_blocked.clear()

	## The plain pieces standing a gantryway at that spot takes out (fits).
	func cost(lane: int, side: int, i: int, both: bool) -> int:
		var other: int = lane - side
		var out: int = own_cost[lane][i] + esc_cost[lane + side][i]
		if other >= 0 and other < lanes:
			out += esc_cost[other][i] if both else corner_cost[other][i]
		return out


static func tuning() -> GantrywayTuning:
	return GantrywayTuning.load_default()


static func powerups() -> PowerupTuning:
	var res: Resource = load(POWERUPS_PATH) if ResourceLoader.exists(POWERUPS_PATH) else null
	return res as PowerupTuning if res is PowerupTuning else PowerupTuning.new()


## The fastest a runner comes through a pillar at `gen`'s level (metres a second): the run speed, the dash's bonus
## (PowerupTuning.dash_speed_bonus), and the most a speed pad's or a ramp's fading boost adds (MovementTuning).
static func fastest(gen: LevelGenerator, pt: PowerupTuning = null) -> float:
	var p: PowerupTuning = pt if pt != null else powerups()
	return gen.speed + p.dash_speed_bonus + maxf(gen.tuning.speed_pad_boost, gen.tuning.ramp_speed_boost)


## How far past its pillar's front a gantryway's calm stretch reaches (metres, at `gen`'s level): its fall and then
## escape_after_seconds more, at the fastest a runner comes through the pillar (fastest()).
static func calm_length(gen: LevelGenerator, t: GantrywayTuning = null, pt: PowerupTuning = null) -> float:
	var tt: GantrywayTuning = t if t != null else tuning()
	return (tt.fall_seconds + tt.escape_after_seconds) * fastest(gen, pt)


## A gantryway's walkway's length at `gen`'s level (metres): length_seconds of run.
static func walkway_length(gen: LevelGenerator, t: GantrywayTuning = null) -> float:
	var tt: GantrywayTuning = t if t != null else tuning()
	return tt.length_seconds * gen.speed


## Where the planted cyborg of a gantryway whose pillar's front is at `front` and walkway ends at `end` may stand
## (Vector2(nearest, furthest), track distances; empty when x > y): past where the fastest runner who stays in the lane is
## as the walkway lands, by crush_margin_seconds at that speed, and as much (at run speed) before the walkway's far end.
static func plant_range(gen: LevelGenerator, front: float, end: float, t: GantrywayTuning = null,
		pt: PowerupTuning = null) -> Vector2:
	var tt: GantrywayTuning = t if t != null else tuning()
	var v: float = fastest(gen, pt)
	return Vector2(front + (tt.fall_seconds + tt.crush_margin_seconds) * v + CYBORG_HALF,
		end - tt.crush_margin_seconds * gen.speed - CYBORG_HALF)


## The level's gantryways (see the header), with the rules: the introduction first where the level gives the feature a
## start, then the rest spread through the level.
static func apply(gen: LevelGenerator) -> void:
	var count: int = gen.config.gantryways
	if count <= 0 or not gen.config.has_feature(FEATURE):
		return
	var t0: int = Time.get_ticks_usec()
	_apply(gen, count)
	spent_usec += Time.get_ticks_usec() - t0


static func _apply(gen: LevelGenerator, count: int) -> void:
	var t: GantrywayTuning = tuning()
	var pt: PowerupTuning = powerups()
	var rng: RandomNumberGenerator = gen.rng_for(FEATURE)
	var plan: Plan = plan_for(gen, t, pt)
	var spacing: float = t.spacing_seconds * gen.speed
	var fronts: Array[float] = []
	var from: float = plan.lo
	if gen.config.feature_starts.has(FEATURE):
		var window: float = minf(plan.lo + t.intro_window_seconds * gen.speed, plan.hi)
		# The best spot in its window with a cyborg under it; else the room made there for one (a few pattern ceilings or
		# plain enemies go); else one with no cyborg there rather than later.
		var spot: Dictionary = _intro_spot(plan, window, fronts, spacing, true)
		if spot.is_empty() and _make_room(gen, t, pt, plan.lo, window, fronts, spacing):
			plan = plan_for(gen, t, pt)
			spot = _intro_spot(plan, window, fronts, spacing, true)
		if spot.is_empty():
			spot = _intro_spot(plan, window, fronts, spacing, false)
		if spot.is_empty() and debug:
			print("gantryways: no introduction within %.0f-%.0f m: %s" % [plan.lo, window, _why_not(plan, plan.lo, window)])
			var near: PackedStringArray = []
			for h: Dictionary in gen.layout.hulls:
				if float(h["start"]) < window + plan.calm and gen.zones.landing_zone(h).y > plan.lo - plan.before:
					near.append("ceiling %.0f-%.0f lanes %s" % [float(h["start"]), float(h["end"]), gen.layout.hull_lanes(h)])
			for e: Dictionary in gen.layout.enemies:
				var at: float = float(e["at"])
				if at > plan.lo - 150.0 and at < window + plan.calm + 50.0:
					near.append("%s %.0f lane %d run %s" % [e["type"], at, int(e.get("lane", -1)),
						LevelGenerator.enemy_floor_span(e, gen.pace)])
			for k: Dictionary in gen.rules_doodad_keep_outs():
				if float(k["from"]) < window + plan.calm and float(k["to"]) > plan.lo - plan.before:
					near.append("rule %s %.0f-%.0f%s" % [k.get("type", "?"), float(k["from"]), float(k["to"]),
						" lane %d" % int(k["lane"]) if k.has("lane") else ""])
			print("  near: %s" % ", ".join(near))
		if spot.is_empty():
			spot = _first(plan, plan.lo, plan.hi, fronts, spacing)
		if not spot.is_empty():
			spot["intro"] = true
			_place(gen, plan, spot, fronts)
			# Nothing of it before its introduction: the rest stand past it.
			from = float(spot["front"]) + spacing
	# Task S2: where another feature's rules want a gantryway (wanted(): the Hunter's introduction, which comes only where
	# one falls in its chase), the best fair spot in that stretch, nearest its middle, both lanes beside it clear if it
	# can (else the one its pillar pushes into), unless one hangs there already: first of the rest. A level whose features
	# want none is built as before.
	for want: Vector2 in wanted(gen):
		var a: float = maxf(want.x, from)
		var b: float = minf(want.y, plan.hi)
		if fronts.size() >= count or b < a or _any_between(fronts, a, b):
			continue
		var wanted_spot: Dictionary = _best(plan, a, b, (a + b) * 0.5, fronts, spacing, true, false)
		if wanted_spot.is_empty():
			wanted_spot = _best(plan, a, b, (a + b) * 0.5, fronts, spacing, false, false)
		if not wanted_spot.is_empty():
			_place(gen, plan, wanted_spot, fronts)
	var left: int = count - fronts.size()
	if left > 0 and from <= plan.hi:
		var part: float = (plan.hi - from) / float(left)
		var wanted: Array[float] = []
		for k: int in left:
			var a: float = from + k * part
			wanted.append(a + rng.randf_range(0.25, 0.75) * part)
		for k: int in left:
			var a: float = from + k * part
			var spot: Dictionary = _best(plan, a, a + part, wanted[k], fronts, spacing, false, false)
			if not spot.is_empty():
				_place(gen, plan, spot, fronts)
	# Where a part had no room: the best of the rest, along the level past the introduction.
	while fronts.size() < count:
		var spot: Dictionary = _best(plan, from, plan.hi, from, fronts, spacing, false, false)
		if spot.is_empty():
			break
		_place(gen, plan, spot, fronts)
	if fronts.is_empty():
		gen.warnings.append("gantryways: no fair spot for one in the level (GDD §5: a feature a level has appears in it)")
	_number(gen.layout)


## The stretches the level's other features' rules want a falling gantryway in (task S2: `static func
## gantryway_wanted(gen: LevelGenerator) -> Array[Vector2]` on a feature's rules script; the Hunter's introduction,
## hunter_rules.gd), in the order of the features: apply() hangs one in each where it can.
static func wanted(gen: LevelGenerator) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for feature: String in gen.config.features:
		var path: String = LevelGenerator.RULES_DIR.path_join("%s_rules.gd" % feature)
		if feature == FEATURE or not ResourceLoader.exists(path):
			continue
		var script := load(path) as GDScript
		if script != null and script.has_method("gantryway_wanted"):
			for w: Vector2 in script.call("gantryway_wanted", gen):
				out.append(w)
	return out


## True if a front of `fronts` lies in [a, b].
static func _any_between(fronts: Array[float], a: float, b: float) -> bool:
	for f: float in fronts:
		if f >= a - 0.001 and f <= b + 0.001:
			return true
	return false


## The best spot in fronts [a, b] (the grid's), as {lane, side, front, cost, both}: one that fits (Plan.fits; both lanes
## beside it clear over the calm stretch with `both`), taking out the fewest plain pieces, then nearest `want` (the
## earliest with `earliest`); among the best PLANT_TRIES of those, the first where a cyborg can be planted under its
## walkway (plant_for). {} if none fits.
static func _best(plan: Plan, a: float, b: float, want: float, fronts: Array[float], spacing: float, both: bool,
		earliest: bool, first_come: bool = false, need_plant: bool = false, tries: int = PLANT_TRIES) -> Dictionary:
	var n: int = plan.size()
	var first: int = maxi(ceili((a - plan.lo) / plan.step - 0.0001), 0)
	var last: int = mini(floori((b - plan.lo) / plan.step + 0.0001), n - 1)
	# The best PLANT_TRIES spots so far, best first: [cost, off, tie, i, lane, side] (with `first_come`, the nearest a
	# first and its cost second: [off, cost, ...]).
	var best: Array[Array] = []
	for lane: int in range(1, plan.lanes - 1):
		for side: int in [-1, 1]:
			var hard: PackedInt32Array = plan.blocked(lane, side, both)
			for i: int in range(first, last + 1):
				if hard[i] > 0 or not plan.fits(lane, side, i, both, fronts, spacing):
					continue
				var f: float = plan.front_at(i)
				var c: int = plan.cost(lane, side, i, both)
				var off: float = f - a if earliest else absf(f - want)
				var item: Array = [c, off, _tie(plan, lane, side, i), i, lane, side]
				if first_come:
					item = [roundi(off * 100.0), float(c), _tie(plan, lane, side, i), i, lane, side]
				if best.size() >= tries and not _better(item, best[best.size() - 1]):
					continue
				var at: int = best.size()
				while at > 0 and _better(item, best[at - 1]):
					at -= 1
				best.insert(at, item)
				if best.size() > tries:
					best.pop_back()
	if best.is_empty():
		return {}
	var spots: Array[Dictionary] = []
	for item: Array in best:
		var i: int = int(item[3])
		spots.append({"lane": int(item[4]), "side": int(item[5]), "front": plan.front_at(i),
			"cost": plan.cost(int(item[4]), int(item[5]), i, both), "both": both})
	for spot: Dictionary in spots:
		var plant: Dictionary = plant_for(plan.gen, plan, spot)
		if not plant.is_empty() or not plan.t.plant_cyborg:
			spot["plant"] = plant
			return spot
	if need_plant and plan.t.plant_cyborg:
		return {}
	spots[0]["plant"] = {}
	return spots[0]


## The introduction's spot in fronts [plan.lo, window] (apply()): the best with both lanes beside it clear
## (intro_both_sides), else with the one its pillar pushes into; with `need_plant`, only one where a cyborg can be planted
## under its walkway, from every fitting spot there (INTRO_TRIES). {} if none.
static func _intro_spot(plan: Plan, window: float, fronts: Array[float], spacing: float, need_plant: bool) -> Dictionary:
	var spot: Dictionary = {}
	if plan.t.intro_both_sides:
		spot = _best(plan, plan.lo, window, plan.lo, fronts, spacing, true, true, false, need_plant, INTRO_TRIES)
	if spot.is_empty():
		spot = _best(plan, plan.lo, window, plan.lo, fronts, spacing, false, true, false, need_plant, INTRO_TRIES)
	return spot


## True if candidate spot `x` ([cost, off, tie, ...]: _best) is better than `y`: fewer pieces out, then nearer, then the
## seeded tie.
static func _better(x: Array, y: Array) -> bool:
	if int(x[0]) != int(y[0]):
		return int(x[0]) < int(y[0])
	if not is_equal_approx(float(x[1]), float(y[1])):
		return float(x[1]) < float(y[1])
	return int(x[2]) < int(y[2])


## Makes room for the introduction in fronts [a, b] (apply()), where none fits: of what a spot there needs gone, the
## fewest (then the earliest spot) go from the layout, among what may go: a ceiling the patterns put there (with its
## pads and the credits on it), never a heli drone's (from a level's first drone on, every pad is its schedule's), a
## ceiling scenario's or one a Barnacle Turret hangs from; and enemies of MAKE_ROOM_TYPES (a plain cyborg, a window
## cyborg, a fence generator, an Octodog), never a host. Never the last of a feature, nor the introduction of one the
## level gives a start (the first of it from there): every feature and introduction stays. Taking content out never
## makes a level unfair (as the dash walls' introduction makes its room), and the introduction gets the calm stretch it
## should have (GDD §5, Level schedule: each level introduces about one new thing; an easy first one, task Q3's brief,
## DESIGN-TBD docs/questions/q3.md). True if anything went.
static func _make_room(gen: LevelGenerator, t: GantrywayTuning, pt: PowerupTuning, a: float, b: float,
		fronts: Array[float], spacing: float) -> bool:
	var lay: LevelLayout = gen.layout
	var first_drone: float = INF
	for e: Dictionary in lay.enemies:
		if String(e.get("type", "")) == "drone":
			first_drone = minf(first_drone, float(e["at"]))
	# What may go: the pattern ceilings (with their pads) and the plain enemies.
	var hulls: Array[Dictionary] = []
	var pads_of: Array[Array] = []
	for h: Dictionary in lay.hulls:
		if h.has(CeilingScenarios.KEY):
			continue
		var mine: Array[Dictionary] = []
		var keep: bool = false
		for p: Dictionary in lay.pads:
			var at: float = float(p["at"])
			if at >= float(h["start"]) - 0.01 and at <= float(h["end"]) + 0.01:
				mine.append(p)
				keep = keep or at >= first_drone
		for e: Dictionary in lay.enemies:
			if String(e.get("type", "")) == "barnacle_turret" and absf(float((e.get("params", {}) as Dictionary).get(
					"hull_start", -INF)) - float(h["start"])) < 0.01:
				keep = true
		if not keep:
			hulls.append(h)
			pads_of.append(mine)
	var enemies: Array[Dictionary] = []
	for e: Dictionary in lay.enemies:
		if MAKE_ROOM_TYPES.has(String(e.get("type", ""))) and not bool((e.get("params", {}) as Dictionary).get("host", false)):
			enemies.append(e)
	if hulls.is_empty() and enemies.is_empty():
		return false
	# The spots that fit with all of it out of the way.
	var saved_hulls: Array[Dictionary] = lay.hulls.duplicate()
	var saved_pads: Array[Dictionary] = lay.pads.duplicate()
	var saved_enemies: Array[Dictionary] = lay.enemies.duplicate()
	var going_pads: Array[Dictionary] = []
	for list: Array in pads_of:
		for p: Dictionary in list:
			going_pads.append(p)
	_keep(lay.hulls, func(h: Dictionary) -> bool: return not _holds(hulls, h))
	_keep(lay.pads, func(p: Dictionary) -> bool: return not _holds(going_pads, p))
	_keep(lay.enemies, func(e: Dictionary) -> bool: return not _holds(enemies, e))
	var relaxed: Plan = plan_for(gen, t, pt)
	var options: Array[Dictionary] = []
	for both: bool in [true, false]:
		var n: int = relaxed.size()
		var first: int = maxi(ceili((a - relaxed.lo) / relaxed.step - 0.0001), 0)
		var last: int = mini(floori((b - relaxed.lo) / relaxed.step + 0.0001), n - 1)
		for i: int in range(first, last + 1):
			for lane: int in range(1, relaxed.lanes - 1):
				for side: int in [-1, 1]:
					if relaxed.fits(lane, side, i, both, fronts, spacing):
						options.append({"lane": lane, "side": side, "front": relaxed.front_at(i), "both": both})
		if not options.is_empty():
			break
	lay.hulls.assign(saved_hulls)
	lay.pads.assign(saved_pads)
	lay.enemies.assign(saved_enemies)
	if options.is_empty():
		return false
	# What each spot needs gone; the fewest first, then the earliest.
	var ranked: Array[Array] = []
	for o: Dictionary in options:
		var going: Array[Dictionary] = _in_way(gen, relaxed, o, hulls, pads_of, enemies)
		ranked.append([going.size(), float(o["front"]), going])
	ranked.sort_custom(func(x: Array, y: Array) -> bool:
		return int(x[0]) < int(y[0]) or (int(x[0]) == int(y[0]) and float(x[1]) < float(y[1])))
	var before: Dictionary = _feature_firsts(gen)
	for r: Array in ranked:
		if int(r[0]) > 0 and _take_out(gen, r[2], before):
			return true
	return false


## The ceilings (with their pads) and enemies of `hulls`, `pads_of` and `enemies` (_make_room's) that stand where
## spot `o` ({lane, side, front, both}) of `plan` keeps clear.
static func _in_way(gen: LevelGenerator, plan: Plan, o: Dictionary, hulls: Array[Dictionary], pads_of: Array[Array],
		enemies: Array[Dictionary]) -> Array[Dictionary]:
	var lay: LevelLayout = gen.layout
	var lane: int = int(o["lane"])
	var side: int = int(o["side"])
	var front: float = float(o["front"])
	var both: bool = bool(o["both"])
	var from: float = front - plan.before
	var windows: Array[Array] = [[lane, Vector2(from, front + plan.lane_after)], [lane + side, Vector2(from, front + plan.calm)]]
	if lane - side >= 0 and lane - side < plan.lanes:
		windows.append([lane - side, Vector2(from, front + plan.calm if both else front + plan.corner)])
	var out: Array[Dictionary] = []
	for k: int in hulls.size():
		var h: Dictionary = hulls[k]
		var lanes: Vector2i = lay.hull_lanes(h)
		var hit: bool = lanes.x <= lane + 1 and lanes.y >= lane - 1 and float(h["start"]) <= front + plan.over_after \
			and gen.zones.landing_zone(h).y >= from
		for p: Dictionary in pads_of[k]:
			hit = hit or _in_windows(windows, int(p["lane"]), gen.zones.pad_zone(float(p["at"])))
		if hit:
			out.append(h)
	var ct := EnemyDirector.tuning_for(CYBORG) as CyborgTuning
	var margin: float = CyborgRules.obstacle_margin_at(ct, gen.pace) if ct != null else gen.metres(10.0)
	var ot := EnemyDirector.tuning_for(OCTODOG) as OctodogTuning
	var dog_window: float = ot.window_length(gen.speed, gen.config.enemy_scaling, gen.pace) if ot != null else 0.0
	var calm := Vector2(from, front + plan.calm)
	for e: Dictionary in enemies:
		var type: String = String(e.get("type", ""))
		var hit: bool = false
		if LevelGenerator.enemy_uses_floor(e):
			var l: int = int(e.get("lane", -1))
			if (l < 0 or l >= lay.lane_count) and int(e.get("side", 0)) != 0:
				l = lay.outer_lane(int(e["side"]))
			hit = _in_windows(windows, l, LevelGenerator.enemy_floor_span(e, gen.pace))
		if type == CYBORG:
			var at: float = float(e["at"])
			hit = hit or (at + margin >= front and at - margin <= front + plan.pillar)
		elif type == OCTODOG:
			for c: Variant in (e.get("params", {}) as Dictionary).get("charge_at", []):
				hit = hit or _hits(calm, Vector2(float(c) - 1.0, float(c) + dog_window))
		if hit:
			out.append(e)
	return out


## True if `list` holds `item` itself (not an equal copy).
static func _holds(list: Array[Dictionary], item: Dictionary) -> bool:
	for x: Dictionary in list:
		if is_same(x, item):
			return true
	return false


## Each of the level's features that it gives a start to (LevelConfig.feature_starts: its introduction), with its
## first position (LevelGenerator.feature_positions), INF where it has none; and every feature's count of positions
## (`counts`): _take_out keeps every feature and every introduction where it was.
static func _feature_firsts(gen: LevelGenerator) -> Dictionary:
	var firsts: Dictionary = {}
	var counts: Dictionary = {}
	for f: String in gen.config.features:
		if f == FEATURE:
			continue
		var at: Array[float] = LevelGenerator.feature_positions(gen.layout, f)
		counts[f] = at.size()
		if gen.config.feature_starts.has(f):
			firsts[f] = at[0] if not at.is_empty() else INF
	return {"firsts": firsts, "counts": counts}


## Takes `going` out of the layout (_make_room: ceilings with their pads and the credits on them, and enemies), unless
## that leaves a feature that had something with nothing, or moves the first of one the level introduces (`before`:
## _feature_firsts); then nothing goes. True if they went.
static func _take_out(gen: LevelGenerator, going: Array[Dictionary], before: Dictionary) -> bool:
	var lay: LevelLayout = gen.layout
	var hulls: Array[Dictionary] = lay.hulls.duplicate()
	var pads: Array[Dictionary] = lay.pads.duplicate()
	var enemies: Array[Dictionary] = lay.enemies.duplicate()
	var credits: Array[Dictionary] = lay.credits.duplicate()
	for x: Dictionary in going:
		if _holds(lay.hulls, x):
			var h: Dictionary = x
			var lanes: Vector2i = lay.hull_lanes(h)
			_keep(lay.hulls, func(o: Dictionary) -> bool: return not is_same(o, h))
			_keep(lay.pads, func(p: Dictionary) -> bool:
				return not (float(p["at"]) >= float(h["start"]) - 0.01 and float(p["at"]) <= float(h["end"]) + 0.01
					and int(p["lane"]) >= lanes.x and int(p["lane"]) <= lanes.y))
			_keep(lay.credits, func(c: Dictionary) -> bool:
				return not (String(c.get("surface", "")) == "ceiling" and float(c["at"]) >= float(h["start"])
					and float(c["at"]) <= float(h["end"]) and int(c.get("lane", -1)) >= lanes.x
					and int(c.get("lane", -1)) <= lanes.y))
		else:
			var e: Dictionary = x
			_keep(lay.enemies, func(o: Dictionary) -> bool: return not is_same(o, e))
	var after: Dictionary = _feature_firsts(gen)
	var ok: bool = true
	for f: String in (before["counts"] as Dictionary):
		if int(before["counts"][f]) > 0 and int((after["counts"] as Dictionary).get(f, 0)) == 0:
			ok = false
	for f: String in (before["firsts"] as Dictionary):
		var was: float = float(before["firsts"][f])
		var now: float = float((after["firsts"] as Dictionary).get(f, INF))
		if not is_equal_approx(now, was) and not (is_inf(was) and is_inf(now)):
			ok = false
	if not ok:
		lay.hulls.assign(hulls)
		lay.pads.assign(pads)
		lay.enemies.assign(enemies)
		lay.credits.assign(credits)
	return ok


## Why no spot of fronts [a, b] fits (debug): how many grid spots each rule turns down, over every inner lane and side.
static func _why_not(plan: Plan, a: float, b: float) -> String:
	var n: int = plan.size()
	var first: int = maxi(ceili((a - plan.lo) / plan.step - 0.0001), 0)
	var last: int = mini(floori((b - plan.lo) / plan.step + 0.0001), n - 1)
	var counts: Dictionary = {}
	for i: int in range(first, last + 1):
		var why: PackedStringArray = []
		if plan.every[i] > 0:
			why.append("every lane")
		for lane: int in range(1, plan.lanes - 1):
			if plan.own_hard[lane][i] > 0:
				why.append("lane %d" % lane)
			for l: int in [lane - 1, lane + 1]:
				if plan.esc_hard[l][i] > 0:
					why.append("beside %d (%d)" % [lane, l])
				if plan.over_hard[l][i] > 0:
					why.append("ceiling over %d" % l)
		var key: String = ", ".join(why)
		counts[key] = int(counts.get(key, 0)) + 1
	return str(counts)


## A seeded order between spots equally good otherwise (lane and side), so a level's lanes take turns.
static func _tie(plan: Plan, lane: int, side: int, i: int) -> int:
	return hash([plan.gen.config.level_seed, FEATURE, i, lane, side]) & 0xffff


## The first spot in fronts [a, b] where one fits (Plan.fits), whatever it takes out: {} if none.
static func _first(plan: Plan, a: float, b: float, fronts: Array[float], spacing: float) -> Dictionary:
	return _best(plan, a, b, a, fronts, spacing, false, true, true)


## Where a gantryway of `plan` at `spot` ({lane, side, front}) plants its cyborg: {at, cost} (cost: the plain pieces
## within a cyborg's obstacle margin of it, in any lane, which go: CyborgRules), the nearest the pillar of the fewest; {}
## where none can stand under its walkway (something it keeps its margin from that can't go, or a ceiling's safe floor).
static func plant_for(gen: LevelGenerator, plan: Plan, spot: Dictionary) -> Dictionary:
	if not plan.t.plant_cyborg:
		return {}
	var ct := EnemyDirector.tuning_for(CYBORG) as CyborgTuning
	var margin: float = CyborgRules.obstacle_margin_at(ct, gen.pace) if ct != null else gen.metres(10.0)
	var front: float = float(spot["front"])
	var lane: int = int(spot["lane"])
	var end: float = front - NEAR_OVERHANG + plan.walkway
	var range_c: Vector2 = plant_range(gen, front, end, plan.t)
	if range_c.x > range_c.y:
		return {}
	# What a cyborg there keeps its margin from (CyborgRules.obstacle_spans), near enough to matter: the plain holes and
	# fences (which may go) apart from the rest (which stay), the pillar among those.
	var near := Vector2(range_c.x - margin, range_c.y + margin)
	var plain: Array[Vector2] = []
	var fixed: Array[Vector2] = []
	if _hits(near, Vector2(front, front + plan.pillar)):
		fixed.append(Vector2(front, front + plan.pillar))
	var lay: LevelLayout = gen.layout
	var depth: float = gen.tuning.fence_depth
	var powered: Array[Dictionary] = plan.powered
	for g: Dictionary in lay.gaps:
		var span := Vector2(float(g["start"]), float(g["end"]))
		if not _hits(near, span):
			continue
		if plan.clearing and not LevelLayout.is_wall_run_hole(g):
			plain.append(span)
		else:
			fixed.append(span)
	for f: Dictionary in lay.fences:
		var span := Vector2(float(f["at"]) - depth, float(f["at"]) + depth)
		if not _hits(near, span):
			continue
		if plan.clearing and not bool(f.get("pulsing", false)) and not powered.has(f):
			plain.append(span)
		else:
			fixed.append(span)
	var bare := LevelLayout.new()
	bare.lane_count = lay.lane_count
	bare.length = lay.length
	bare.doodads = lay.doodads
	bare.dash_walls = lay.dash_walls
	bare.ramps = lay.ramps
	bare.pads = lay.pads
	bare.speed_pads = lay.speed_pads
	bare.hulls = lay.hulls
	bare.wall_run_gaps = lay.wall_run_gaps
	for span: Vector2 in CyborgRules.obstacle_spans(bare, gen.tuning, gen.zones):
		if _hits(near, span):
			fixed.append(span)
	# A wall-run gap's stretch with its margins (keep_out): its own re-check keeps a cyborg's margin and that off its clear
	# stretch (WallRunGapPlacement.problem), and this cyborg comes after it.
	for w: Dictionary in lay.wall_run_gaps:
		var k: Vector2 = WallRunGapPlacement.keep_out(w)
		if _hits(near, k):
			fixed.append(k)
	var c: float = range_c.x
	while c <= range_c.y + 0.001:
		var entry: Dictionary = _cyborg(gen, plan.t, c, lane, front, 0)
		if not CyborgRules.near_any(fixed, c, margin) and gen.zones.enemy_clear(lay, entry):
			var cost: int = 0
			for s: Vector2 in plain:
				if s.x - margin <= c and s.y + margin >= c:
					cost += 1
			if cost == 0 or plan.clearing:
				return {"at": c, "cost": cost}
		c += PLANT_STEP
	return {}


## A planted cyborg's layout entry: at `at` in `lane`, under the gantryway `id` whose pillar's front is at `front`
## (see the header: plain, standing, holding its fire through the calm stretch).
static func _cyborg(gen: LevelGenerator, t: GantrywayTuning, at: float, lane: int, front: float, id: int) -> Dictionary:
	var hold := Vector2(front - t.hold_before_seconds * gen.speed, front + calm_length(gen, t))
	return {"type": CYBORG, "at": at, "lane": lane, "side": 0, "seed": hash([gen.config.level_seed, PARAM, id]),
		"params": {"panic": false, "host": false, "stand": true, "hold_fire": hold, PARAM: id}}


## Stands a gantryway at `spot` (_best): takes out the plain pieces in its windows (and within its planted cyborg's
## obstacle margin), adds its pillar (a doodad entry marked LevelLayout.GANTRY_PILLAR), its walkway's entry and its
## planted cyborg. Its id is set by _number once every one stands.
static func _place(gen: LevelGenerator, plan: Plan, spot: Dictionary, fronts: Array[float]) -> void:
	var lay: LevelLayout = gen.layout
	var lane: int = int(spot["lane"])
	var side: int = int(spot["side"])
	var front: float = float(spot["front"])
	var both: bool = bool(spot.get("both", false))
	var start: float = front - NEAR_OVERHANG
	var end: float = start + plan.walkway
	var calm_end: float = front + plan.calm
	var from: float = front - plan.before
	# The windows' plain pieces, lane by lane: its own lane, the step out's, the other side's (the corner's, or the calm
	# stretch's for an introduction with both sides kept).
	var windows: Array[Array] = [[lane, Vector2(from, front + plan.lane_after)], [lane + side, Vector2(from, calm_end)]]
	if lane - side >= 0 and lane - side < plan.lanes:
		windows.append([lane - side, Vector2(from, calm_end if both else front + plan.corner)])
	var plant: Dictionary = spot.get("plant", {})
	var ct := EnemyDirector.tuning_for(CYBORG) as CyborgTuning
	var margin: float = CyborgRules.obstacle_margin_at(ct, gen.pace) if ct != null else gen.metres(10.0)
	var near_plant := Vector2(INF, -INF)
	if not plant.is_empty():
		near_plant = Vector2(float(plant["at"]) - margin, float(plant["at"]) + margin)
	var half: float = gen.tuning.fence_depth * 0.5
	var powered: Array[Dictionary] = powered_fences(gen)
	_keep(lay.gaps, func(g: Dictionary) -> bool:
		if LevelLayout.is_wall_run_hole(g):
			return true
		var span := Vector2(float(g["start"]), float(g["end"]))
		return not _in_windows(windows, int(g["lane"]), span) and not _hits(near_plant, span))
	_keep(lay.fences, func(f: Dictionary) -> bool:
		if bool(f.get("pulsing", false)) or powered.has(f):
			return true
		var span := Vector2(float(f["at"]) - half, float(f["at"]) + half)
		# The cyborg keeps a fence's full depth either side (CyborgRules.obstacle_spans).
		var wide := Vector2(float(f["at"]) - half * 2.0, float(f["at"]) + half * 2.0)
		return not _in_windows(windows, int(f["lane"]), span) and not _hits(near_plant, wide))
	var pillar_size: Vector3 = gen.tuning.doodad_size(PILLAR_SIZE)
	var index: int = lay.gantryways.size()
	var seed: int = hash([gen.config.level_seed, FEATURE, index])
	var g := {"id": index, "lane": lane, "start": start, "end": end, "pillar": front, "side": side,
		"calm": [front, calm_end], "seed": seed}
	if bool(spot.get("intro", false)):
		g["intro"] = true
	if both:
		g["both"] = true
	lay.gantryways.append(g)
	lay.doodads.append({"lane": lane, "start": front, "end": front + pillar_size.z, "size": PILLAR_SIZE, "side": side,
		"seed": seed, LevelLayout.GANTRY_PILLAR: index})
	var b: float = -plan.before
	# The plan learns what now stands (the pillar, its cyborg), rather than being made again: a later gantryway is
	# spacing_seconds away, past every window of this one's, so what it took out never matters to another.
	var pillar_span := Vector2(front, front + pillar_size.z)
	plan.mark(plan.own_hard[lane], pillar_span, b, plan.lane_after)
	plan.mark(plan.esc_hard[lane], pillar_span, b, plan.calm)
	plan.mark(plan.corner_hard[lane], pillar_span, b, plan.corner)
	if not plant.is_empty():
		var cyborg: Dictionary = _cyborg(gen, plan.t, float(plant["at"]), lane, front, index)
		lay.enemies.append(cyborg)
		var run: Vector2 = LevelGenerator.enemy_floor_span(cyborg, gen.pace)
		plan.mark(plan.own_hard[lane], run, b, plan.lane_after)
		plan.mark(plan.esc_hard[lane], run, b, plan.calm)
		plan.mark(plan.corner_hard[lane], run, b, plan.corner)
		var c: float = float(plant["at"])
		plan.mark(plan.every, Vector2(c - margin, c + margin), 0.0, plan.pillar)
	plan.changed()
	fronts.append(front)


## Gives the level's gantryways their ids in track order, and their pillars (LevelLayout.GANTRY_PILLAR) and planted
## cyborgs (PARAM) the same.
static func _number(lay: LevelLayout) -> void:
	lay.gantryways.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["start"]) < float(b["start"]))
	var remap: Dictionary = {}
	for i: int in lay.gantryways.size():
		remap[int(lay.gantryways[i]["id"])] = i
		lay.gantryways[i]["id"] = i
	for d: Dictionary in lay.doodads:
		if d.has(LevelLayout.GANTRY_PILLAR):
			d[LevelLayout.GANTRY_PILLAR] = int(remap.get(int(d[LevelLayout.GANTRY_PILLAR]), int(d[LevelLayout.GANTRY_PILLAR])))
	for e: Dictionary in lay.enemies:
		var params: Dictionary = e.get("params", {})
		if String(e.get("type", "")) == CYBORG and params.has(PARAM):
			params[PARAM] = int(remap.get(int(params[PARAM]), int(params[PARAM])))


## True if `span` in `lane` reaches one of `windows` ([lane, Vector2]).
static func _in_windows(windows: Array[Array], lane: int, span: Vector2) -> bool:
	for w: Array in windows:
		var win: Vector2 = w[1]
		if int(w[0]) == lane and span.x <= win.y and span.y >= win.x:
			return true
	return false


static func _hits(a: Vector2, b: Vector2) -> bool:
	return a.x <= b.y and a.y >= b.x


## What the level's gantryways keep, and where on its track a pillar's front may stand (see the header): with
## `checking`, for a finished layout (problems()), everything there counts against a spot, plain pieces too, and a
## gantryway's own pillar, planted cyborg and calm stretch don't count against itself (the caller looks at its own spot
## only); while placing, plain pieces only cost what taking them out costs.
static func plan_for(gen: LevelGenerator, t: GantrywayTuning = null, pt: PowerupTuning = null,
		checking: bool = false) -> Plan:
	var p := Plan.new()
	p.gen = gen
	p.t = t if t != null else tuning()
	var mt: MovementTuning = gen.tuning
	var lay: LevelLayout = gen.layout
	p.lanes = lay.lane_count
	p.fastest = fastest(gen, pt)
	p.before = LevelGenerator.doodad_lead_for(mt) + gen.doodad_lane_room()
	p.pillar = mt.doodad_size(PILLAR_SIZE).z
	p.walkway = walkway_length(gen, p.t)
	p.lane_after = p.walkway - NEAR_OVERHANG + gen.doodad_lane_room()
	p.over_after = p.walkway - NEAR_OVERHANG + OVER_MARGIN
	p.calm = calm_length(gen, p.t, pt)
	p.corner = maxf(p.pillar + gen.doodad_lane_room(), gen.doodad_landing(0.0))
	p.step = maxf(p.t.search_step, 0.05)
	p.clearing = p.t.clear_plain_pieces and not checking
	p.lo = maxf(gen.config.start_clear_distance + p.before, gen.feature_start(FEATURE))
	p.hi = lay.length - gen.config.end_clear_distance - maxf(p.lane_after, p.calm)
	var n: int = p.size()
	for lane: int in p.lanes:
		for arr: Array[PackedInt32Array] in [p.own_hard, p.own_cost, p.esc_hard, p.esc_cost, p.corner_hard, p.corner_cost,
				p.over_hard]:
			var marks := PackedInt32Array()
			marks.resize(n)
			marks.fill(0)
			arr.append(marks)
	p.every.resize(n)
	p.every.fill(0)
	if n <= 0:
		return p
	var b: float = -p.before
	p.powered = powered_fences(gen)
	# What stands in a lane: [lane, span, plain]. A plain piece costs, anything else blocks.
	var pieces: Array[Array] = lane_pieces(gen, p.clearing, p.powered)
	for piece: Array in pieces:
		var lane: int = piece[0]
		var span: Vector2 = piece[1]
		if lane < 0 or lane >= p.lanes:
			continue
		var plain: bool = piece[2]
		p.mark(p.own_cost[lane] if plain else p.own_hard[lane], span, b, p.lane_after)
		p.mark(p.esc_cost[lane] if plain else p.esc_hard[lane], span, b, p.calm)
		p.mark(p.corner_cost[lane] if plain else p.corner_hard[lane], span, b, p.corner)
	# What every lane keeps over the calm stretch.
	for span: Vector2 in every_keeps(gen):
		p.mark(p.every, span, b, p.calm)
	# A wall-run gap (its rules run before these) keeps every rule's keep-outs off its stretch in every lane, whatever
	# lane they name (WallRunGapPlacement.problem, floor_keeps): so the whole of a gantryway's (doodad_keep_outs: its lane
	# to past the walkway's far end, and its calm stretch) keeps off it, with its margins (keep_out).
	var reach: float = maxf(p.lane_after, p.calm)
	for w: Dictionary in lay.wall_run_gaps:
		p.mark(p.every, WallRunGapPlacement.keep_out(w), b, reach)
	# A cyborg in any lane keeps its obstacle margin from the pillar (CyborgRules: a pillar is a doodad).
	var ct := EnemyDirector.tuning_for(CYBORG) as CyborgTuning
	var margin: float = CyborgRules.obstacle_margin_at(ct, gen.pace) if ct != null else gen.metres(10.0)
	for e: Dictionary in lay.enemies:
		if String(e.get("type", "")) != CYBORG:
			continue
		if checking and (e.get("params", {}) as Dictionary).has(PARAM):
			continue
		var at: float = float(e["at"])
		p.mark(p.every, Vector2(at - margin, at + margin), 0.0, p.pillar)
	# No ceiling (to the end of its landing zone) over the walkway's lane or the lanes beside it from the pillar's lead to
	# past the walkway's far end.
	for h: Dictionary in lay.hulls:
		var lanes: Vector2i = lay.hull_lanes(h)
		var span := Vector2(float(h["start"]), gen.zones.landing_zone(h).y)
		for lane: int in range(lanes.x, lanes.y + 1):
			p.mark(p.over_hard[lane], span, b, p.over_after)
	return p


## What stands in each lane that a gantryway keeps its windows clear of (plan_for), [lane, span, plain]: its holes and
## fences (plain: one that may be taken out, never a wall-run gap's hole, a pulsing fence or one a fence generator
## powers; none with `plain_ok` off), speed pads, anti-grav pads' zones (CeilingZones.pad_zone: the run-up and the
## lift), a ramp in the outermost lane on its side to where its
## wall run drops the runner back, floor cuts' lane windows, the doodads (a row as one; another gantryway's pillar), the
## floor its enemies use (LevelGenerator.enemy_floor_span; a wall enemy's that uses the floor in the outermost lane by its
## wall), and the lanes the rules keep ({lane, from, to}: a hover truck's).
static func lane_pieces(gen: LevelGenerator, plain_ok: bool, powered: Array[Dictionary] = []) -> Array[Array]:
	var lay: LevelLayout = gen.layout
	var mt: MovementTuning = gen.tuning
	var out: Array[Array] = []
	var half: float = mt.fence_depth * 0.5
	if plain_ok and powered.is_empty():
		powered = powered_fences(gen)
	for g: Dictionary in lay.gaps:
		out.append([int(g["lane"]), Vector2(float(g["start"]), float(g["end"])), plain_ok and not LevelLayout.is_wall_run_hole(g)])
	for f: Dictionary in lay.fences:
		out.append([int(f["lane"]), Vector2(float(f["at"]) - half, float(f["at"]) + half),
			plain_ok and not bool(f.get("pulsing", false)) and not powered.has(f)])
	for s: Dictionary in lay.speed_pads:
		out.append([int(s["lane"]), Vector2(float(s["at"]), float(s["at"]) + mt.speed_pad_length), false])
	for pad: Dictionary in lay.pads:
		out.append([int(pad["lane"]), gen.zones.pad_zone(float(pad["at"])), false])
	for r: Dictionary in lay.ramps:
		var at: float = float(r["at"])
		out.append([lay.outer_lane(int(r["side"])), Vector2(at, maxf(gen.ramp_launch(r).end(), at + mt.ramp_length)), false])
	for c: Dictionary in lay.cuts:
		out.append([int(c["lane"]), FloorCutPlan.lane_window(c), false])
	for d: Dictionary in lay.doodads:
		out.append([int(d["lane"]), LevelLayout.doodad_extent(d), false])
	for e: Dictionary in lay.enemies:
		if not LevelGenerator.enemy_uses_floor(e):
			continue
		var lane: int = int(e.get("lane", -1))
		if (lane < 0 or lane >= lay.lane_count) and int(e.get("side", 0)) != 0:
			lane = lay.outer_lane(int(e["side"]))
		out.append([lane, LevelGenerator.enemy_floor_span(e, gen.pace), false])
	for k: Dictionary in gen.rules_doodad_keep_outs():
		if k.has("lane") and String(k.get("type", "")) != FEATURE:
			out.append([int(k["lane"]), Vector2(float(k["from"]), float(k["to"])), false])
	return out


## What every lane keeps clear of a gantryway's calm stretch (plan_for): every floor cut's window, every dash wall's
## footprint, every wider gap's zone, the level's quiet stretches, what the rules keep in every lane (their calm stretches
## too; never a gantryway's own), and every Octodog's planned charge (its window from a metre before its anchor,
## Octodog.window_clear, which counts the calm stretch: LevelLayout.doodad_between). A ceiling counts only over the
## gantryway's lane and the lanes beside it (plan_for's `over`), a pad's zone only in its lane (lane_pieces).
static func every_keeps(gen: LevelGenerator) -> Array[Vector2]:
	var lay: LevelLayout = gen.layout
	var out: Array[Vector2] = []
	for c: Dictionary in lay.cuts:
		out.append(FloorCutPlan.window(c, gen.speed))
	for w: Dictionary in lay.dash_walls:
		out.append(LevelGenerator.DashWallRules.footprint(gen, w))
	out.append_array(WideGapPlacement.keep_outs(gen))
	out.append_array(gen.quiet_stretches())
	for k: Dictionary in gen.rules_doodad_keep_outs():
		if not k.has("lane") and String(k.get("type", "")) != FEATURE:
			out.append(Vector2(float(k["from"]), float(k["to"])))
	var ot := EnemyDirector.tuning_for(OCTODOG) as OctodogTuning
	if ot != null:
		var window: float = ot.window_length(gen.speed, gen.config.enemy_scaling, gen.pace)
		for e: Dictionary in lay.enemies:
			if String(e.get("type", "")) == OCTODOG:
				for a: Variant in (e.get("params", {}) as Dictionary).get("charge_at", []):
					out.append(Vector2(float(a) - 1.0, float(a) + window))
	return out


## The fences a fence generator powers (FenceGenerator.fences_in_reach): with the pulsing ones, the fences a gantryway
## never takes out to make room (the `pulsing` feature counts those; a generator powering nothing goes).
static func powered_fences(gen: LevelGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var has_generators: bool = false
	for e: Dictionary in gen.layout.enemies:
		has_generators = has_generators or String(e.get("type", "")) == "generator"
	if not has_generators:
		return out
	var gt: FenceGeneratorTuning = GeneratorRules.tuning()
	var geo := TrackGeometry.new(gen.layout.lane_count, gen.tuning)
	for e: Dictionary in gen.layout.enemies:
		if String(e.get("type", "")) == "generator":
			out.append_array(FenceGenerator.fences_in_reach(gen.layout, geo, float(e["at"]), int(e["lane"]), gt.emp_radius))
	return out


## Keeps the items of `list` for which `keep` returns true (in place, so typed arrays stay typed).
static func _keep(list: Array[Dictionary], keep: Callable) -> void:
	var kept: Array[Dictionary] = []
	for item: Dictionary in list:
		if keep.call(item):
			kept.append(item)
	list.assign(kept)


## Every gantryway in `layout`: its pillar's front (LevelGenerator.feature_positions: the every-feature check and the
## introduction's).
static func positions(layout: LevelLayout) -> Array[float]:
	var out: Array[float] = []
	for g: Dictionary in layout.gantryways:
		out.append(float(g["pillar"]))
	return out


## What the passes after the rules keep off (LevelGenerator.rules_doodad_keep_outs: the danger density pass, the wider
## gaps, the cyborgs planted in charge paths, the zone doodads): every gantryway's calm stretch from its pillar's lead,
## in every lane, and its lane from there to a lane switch's room past its walkway's far end ({lane, from, to}).
static func doodad_keep_outs(gen: LevelGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if gen.layout.gantryways.is_empty():
		return out
	var before: float = LevelGenerator.doodad_lead_for(gen.tuning) + gen.doodad_lane_room()
	for g: Dictionary in gen.layout.gantryways:
		var calm: Array = g["calm"]
		var from: float = float(calm[0]) - before
		out.append({"from": from, "to": float(calm[1]), "type": FEATURE})
		out.append({"lane": int(g["lane"]), "from": from, "to": float(g["end"]) + gen.doodad_lane_room(), "type": FEATURE})
	return out


## What the fill pass keeps off (LevelGenerator.rules_fill_keep_outs, every lane): every gantryway's calm stretch from
## its pillar's lead. Its lane past that, the fill pass may cross: after_fill takes its pieces there out.
static func fill_keep_outs(gen: LevelGenerator) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var before: float = LevelGenerator.doodad_lead_for(gen.tuning) + gen.doodad_lane_room()
	for g: Dictionary in gen.layout.gantryways:
		var calm: Array = g["calm"]
		out.append(Vector2(float(calm[0]) - before, float(calm[1])))
	return out


## After the fill pass (LevelGenerator._fill_empty_stretches): every gantryway's lane is kept free of the fillers' holes
## and fences under its walkway, as of the patterns' (apply). Taking pieces out of a row never makes it unfair.
static func after_fill(gen: LevelGenerator) -> void:
	var lay: LevelLayout = gen.layout
	if lay.gantryways.is_empty():
		return
	var half: float = gen.tuning.fence_depth * 0.5
	var room: float = gen.doodad_lane_room()
	for g: Dictionary in lay.gantryways:
		var lane: int = int(g["lane"])
		var span := Vector2(float(g["pillar"]) - LevelGenerator.doodad_lead_for(gen.tuning) - room, float(g["end"]) + room)
		_keep(lay.gaps, func(h: Dictionary) -> bool:
			return int(h["lane"]) != lane or float(h["start"]) > span.y or float(h["end"]) < span.x)
		_keep(lay.fences, func(f: Dictionary) -> bool:
			return int(f["lane"]) != lane or float(f["at"]) - half > span.y or float(f["at"]) + half < span.x)


## Every placement rule a finished level's gantryways break (see the header), for the tests: [] if none. Run on the
## finished layout, so it also catches a pass after the rules that put something where a gantryway keeps.
static func problems(gen: LevelGenerator) -> PackedStringArray:
	var out: PackedStringArray = []
	var lay: LevelLayout = gen.layout
	if lay.gantryways.is_empty():
		return out
	var t: GantrywayTuning = tuning()
	var pt: PowerupTuning = powerups()
	var walkway: float = walkway_length(gen, t)
	var calm: float = calm_length(gen, t, pt)
	var spacing: float = t.spacing_seconds * gen.speed
	var before: float = LevelGenerator.doodad_lead_for(gen.tuning) + gen.doodad_lane_room()
	var room: float = gen.doodad_lane_room()
	var corner: float = maxf(gen.tuning.doodad_size(PILLAR_SIZE).z + room, gen.doodad_landing(0.0))
	var pieces: Array[Array] = lane_pieces(gen, false)
	var every: Array[Vector2] = every_keeps(gen)
	var ct := EnemyDirector.tuning_for(CYBORG) as CyborgTuning
	var margin: float = CyborgRules.obstacle_margin_at(ct, gen.pace) if ct != null else gen.metres(10.0)
	var wall_runs: Array[Vector2] = []
	for w: Dictionary in lay.wall_run_gaps:
		wall_runs.append(WallRunGapPlacement.keep_out(w))
	var prev: float = -INF
	for g: Dictionary in lay.gantryways:
		var id: int = int(g["id"])
		var lane: int = int(g["lane"])
		var side: int = int(g["side"])
		var front: float = float(g["pillar"])
		var start: float = float(g["start"])
		var end: float = float(g["end"])
		var tag: String = "the gantryway at %.1f m (lane %d)" % [front, lane]
		var pillar: Dictionary = lay.pillar_of(g)
		if lane < 1 or lane > lay.lane_count - 2:
			out.append("%s: not over an inner lane" % tag)
		if absi(side) != 1:
			out.append("%s: its pillar pushes to no side" % tag)
		if pillar.is_empty() or int(pillar["lane"]) != lane or absf(float(pillar["start"]) - front) > 0.01 \
				or int(pillar["side"]) != side or StringName(pillar["size"]) != PILLAR_SIZE:
			out.append("%s: no pillar of its own under its near end" % tag)
		if absf(start - (front - NEAR_OVERHANG)) > 0.01 or absf(end - start - walkway) > 0.05:
			out.append("%s: its walkway isn't %.1f m from just before its pillar" % [tag, walkway])
		var c: Array = g["calm"]
		if absf(float(c[0]) - front) > 0.01 or absf(float(c[1]) - front - calm) > 0.05:
			out.append("%s: its calm stretch isn't its fall and the step out" % tag)
		if front - before < gen.config.start_clear_distance - 0.01 or front < gen.feature_start(FEATURE) - 0.01 \
				or maxf(end + room, front + calm) > lay.length - gen.config.end_clear_distance + 0.01:
			out.append("%s: not between the run-up (or the feature's start) and the end-clear stretch" % tag)
		if front - prev < spacing - 0.01:
			out.append("%s: %.1f m after the one before (at least %.1f m)" % [tag, front - prev, spacing])
		prev = front
		var from: float = front - before
		var both: bool = bool(g.get("both", false))
		var windows: Array[Array] = [[lane, Vector2(from, end + room)], [lane + side, Vector2(from, front + calm)]]
		if lane - side >= 0 and lane - side < lay.lane_count:
			windows.append([lane - side, Vector2(from, front + calm if both else front + corner)])
		for piece: Array in pieces:
			var span: Vector2 = piece[1]
			if not _in_windows(windows, int(piece[0]), span):
				continue
			if pillar.has(LevelLayout.GANTRY_PILLAR) and int(piece[0]) == lane and absf(span.x - front) < 0.01:
				continue
			if _planted_span(gen, lay, id, int(piece[0]), span):
				continue
			out.append("%s: something stands in lane %d at %.1f-%.1f m, where it keeps clear" % [tag, int(piece[0]), span.x,
				span.y])
		for span: Vector2 in every:
			if span.x <= front + calm and span.y >= from:
				out.append("%s: something every lane keeps clear of is at %.1f-%.1f m, in its calm stretch" % [tag, span.x,
					span.y])
		for h: Dictionary in lay.hulls:
			var lanes: Vector2i = lay.hull_lanes(h)
			if lanes.x <= lane + 1 and lanes.y >= lane - 1 and float(h["start"]) <= end + OVER_MARGIN \
					and gen.zones.landing_zone(h).y >= from:
				out.append("%s: a ceiling over its lane or beside it from %.1f m" % [tag, float(h["start"])])
		for k: Vector2 in wall_runs:
			if k.x <= maxf(end + room, front + calm) and k.y >= from:
				out.append("%s: a wall-run gap's stretch (%.1f-%.1f m) within what it keeps" % [tag, k.x, k.y])
		for e: Dictionary in lay.enemies:
			if String(e.get("type", "")) == CYBORG and not (e.get("params", {}) as Dictionary).has(PARAM):
				var at: float = float(e["at"])
				if at + margin >= front and at - margin <= front + gen.tuning.doodad_size(PILLAR_SIZE).z:
					out.append("%s: a cyborg at %.1f m within its obstacle margin of the pillar" % [tag, at])
		var planted: Dictionary = planted_under(lay, g)
		if t.plant_cyborg and not planted.is_empty():
			var range_c: Vector2 = plant_range(gen, front, end, t, pt)
			var at: float = float(planted["at"])
			var params: Dictionary = planted.get("params", {})
			var hold: Variant = params.get("hold_fire")
			if int(planted.get("lane", -1)) != lane or at < range_c.x - 0.01 or at > range_c.y + 0.01:
				out.append("%s: its cyborg at %.1f m isn't under it where the walkway lands first" % [tag, at])
			if CyborgRules.near_any(wall_runs, at, margin):
				out.append("%s: its cyborg at %.1f m within its obstacle margin of a wall-run gap" % [tag, at])
			if not bool(params.get("stand", false)) or bool(params.get("panic", true)) or bool(params.get("host", true)) \
					or not (hold is Vector2) or (hold as Vector2).x > front - t.hold_before_seconds * gen.speed + 0.01 \
					or (hold as Vector2).y < front + calm - 0.01:
				out.append("%s: its cyborg isn't a plain one standing and holding its fire" % tag)
	return out


## True if `span` in `lane` is the floor gantryway `id`'s own planted cyborg uses (which stands under its walkway).
static func _planted_span(gen: LevelGenerator, lay: LevelLayout, id: int, lane: int, span: Vector2) -> bool:
	for e: Dictionary in lay.enemies:
		var params: Dictionary = e.get("params", {})
		if params.has(PARAM) and int(params[PARAM]) == id and int(e.get("lane", -1)) == lane:
			var own: Vector2 = LevelGenerator.enemy_floor_span(e, gen.pace)
			if absf(own.x - span.x) < 0.01 and absf(own.y - span.y) < 0.01:
				return true
	return false


## The cyborg planted under gantryway `g` (its PARAM is g's id), or {}.
static func planted_under(layout: LevelLayout, g: Dictionary) -> Dictionary:
	var id: int = int(g.get("id", -1))
	for e: Dictionary in layout.enemies:
		var params: Dictionary = e.get("params", {})
		if String(e.get("type", "")) == CYBORG and params.has(PARAM) and int(params[PARAM]) == id:
			return e
	return {}
