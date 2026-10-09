extends RefCounted
## Generator rules for dash walls (task H7a; GDD §9.14, owner, October 8, 2026): buildings standing across
## every floor lane, like a building in the middle of the street, which the runner dashes through. They
## leave the side walls open ("a wall runner passes it") and no ceiling shares their stretch. They have no
## patterns: LevelGenerator runs apply() for a level with the `dash_wall` feature after the rules of every
## other feature (RUN_AFTER), so they're planned on the level's final enemies, ceilings, pads, ramps and
## floor cuts, and every pass after the rules keeps off them (below). Numbers: DashWallTuning
## (data/tuning/dash_walls.tres), seconds at the level's run speed or at the dash's speed (the run's plus
## PowerupTuning.dash_speed_bonus), so a faster zone keeps them; the wall's size is MovementTuning's.
##
## Where one may stand (Plan; a wall's face, the side toward the runner, at track distance F):
## - Its footprint, [F - approach, back + after] (approach_seconds and after_seconds at the dash's speed), in
##   every lane, holds nothing else: the approach clear enough to dash into the wall after whatever comes
##   before it, and the stretch past it clear for a reaction and a lane switch, since what the wall hid shows
##   only as it breaks (GDD §9.14 with task H5's measure for doodads). No hole or floor cut, fence, sign's
##   wall route (below), pad's zone, ramp or the wall run it launches, speed pad, ceiling from its start to the
##   end of its landing zone (GDD §9.14: no ceiling overlaps a dash wall; nor the safe landing zone), floor
##   cut's window (a Buzz Overdrive's cut), and no enemy's keep-out or floor (what the fill pass keeps for it,
##   LevelGenerator.enemy_keep_out: its attack never lands at the wall) nor what the rules keep doodads off in
##   every lane (a Bad Dream's chase, a Gilded Sentinel's turn), as a wider gap keeps off them
##   (WideGapPlacement.keeps_of): a floor cyborg's obstacle margin only and a planned Resonator's pulses only
##   (enemy_spans). A rule's keep-out of one lane (the hover truck's lane for its whole stay) is about what
##   stands in that lane; the truck has a rule of its own (below).
## - The Tithe Collector's whole stay: it flies ahead of the runner, low in the lanes, and would reach a
##   standing wall before them.
## - The trucks (GDD §9.3, §9.13; the simplest fair rules, DESIGN-TBD): the hover truck gives way to a wall
##   (HoverTruck._wall_ahead: from pacing or alongside it drops behind the runner, holds back without revving
##   until they've broken the wall, and follows them through; its cannon holds fire near one), so only its
##   entrance keeps the walls off (truck_entrance: it bangs on the wall, bursts out and settles); where it
##   can't drop back (the runner in its lane behind it, ridden, leaving ahead) it bursts through the wall as
##   it burst out of the building (HoverTruck._burst_dash_walls). The Enforcer Truck needs nothing: it drives
##   behind the runner, and a wall always breaks as the runner reaches it (a dash, a crash or a pass on a side
##   wall: Player._check_dash_walls), so it only ever meets a broken one and drives on through; its volleys
##   never start with a wall in the escape (as with a doodad).
## - The flyers ahead of the runner (the heli drone, which stays until it's downed, the Resonator pulling away
##   or between its pulses, a Tithe Collector fleeing) rise over a standing wall in their way
##   (Enemy.dash_wall_lift); the drone and the truck's cannon hold their fire near one, and the Resonator's
##   waves never meet one (they read LevelLayout.doodad_between, which counts the walls in every lane), so the
##   heli drone keeps nothing (NO_KEEP_TYPES).
## - Spacing (GDD §9.14, proposed): faces at least spacing_for() apart, the dash's longest cooldown and
##   cooldown_margin_seconds of run plus the ground the dash itself covers, so the dash spent on one wall is
##   back before the next. With keep_dash_baits, nothing else that invites a dash comes within that spacing
##   before a face: a Buzz Overdrive's charge meeting the runner (a panic dash smashes it, GDD §9.9), a fence
##   generator (its hint says to dash through it) and, as the doodads come after the walls, a zone doodad
##   (LevelGenerator.doodad_keep_outs, bait_keep_outs).
## - The wall route (GDD §9.14: "a player running on a side wall passes it"): from wall_route_seconds before
##   its face to its back, at least one side wall holds no sign (a sign blocks the entry and hurts); the side
##   wall gaps and wall fences, placed after, keep off both walls there (WallGapPlacement.keep_outs,
##   wall_keep_outs; a wall fence's drop window keeps off the footprint, doodad_keep_outs).
## - The level: the footprint between the run-up and the end-clear stretch, the face past the feature's start.
## Plain holes and fences (never a pulsing fence or one a fence generator powers) in a footprint, and the
## signs on one side wall where both block the route, are taken out to make room (clear_plain_pieces: taking
## content out never makes a level unfair); a spot that needs nothing taken out is preferred.
##
## How many, and where: up to LevelConfig.dash_walls, spread through the level (the stretch from the first
## possible face to the last cut into as many parts, a seeded spot aimed for in each, the best fair spot in
## that part taken: nothing to take out first, then the nearest), then the best of the rest wherever a part
## had none. A level that gives the feature a start (LevelConfig.feature_starts: Corporate 1, after the Buzz
## Overdrive's introduction) introduces it first, at the first fair spot from its start (within intro_seconds
## where one fits). A level with the feature and no fair spot at all gets a warning (the campaign tests fail
## on any): every feature appears (GDD §5). Its own random stream (LevelGenerator.rng_for), so the rules
## before it place exactly what they did; a level without the feature draws nothing and is built byte for
## byte as before.
##
## What keeps off them after the rules: the fill pass (LevelGenerator.fill_keep_outs, every footprint in
## every lane), the danger density pass, the wider gaps, the cyborgs planted in charge paths, the zone doodads
## and the wall fences' drop windows (doodad_keep_outs, the rules' keep-outs in every lane), the zone doodads
## again over the dash baits' spacing (bait_keep_outs), the side wall gaps (wall_keep_outs), and the credits
## (none inside a wall: LevelLayout.doodad_between). problems() re-checks every wall for the tests.
## DESIGN-TBD (docs/questions/h7a.md): every number, how many a level, the baits, the route.

const FEATURE: String = "dash_wall"
## Every feature whose rules place, move or drop enemies, plan charges or cuts, or add ceilings, pads and
## ramps: the walls are planned on the level's final track.
const RUN_AFTER: Array[String] = ["ramps", "ceilings", "pulsing", "speed_pads", "cyborg", "window_cyborg", "host",
	"hover_truck", "octodog", "screech", "screech_vents", "drone", "generator", "wall_fences", "wall_fences_partial",
	"buzz_overdrive", "barnacle_turret", "tithe_collector", "resonator", "gilded_sentinel", "enforcer_truck",
	"floor_cutter"]
const BuzzRules = preload("res://scripts/enemies/buzz_overdrive_rules.gd")
const GeneratorRules = preload("res://scripts/enemies/generator_rules.gd")
const POWERUPS_PATH: String = "res://data/tuning/powerups.tres"
const TITHE: String = "tithe_collector"
const GENERATOR: String = "generator"
const BUZZ: String = "buzz_overdrive"
## Metres before a Tithe Collector's spot its stay is kept from (it appears ahead of the runner there).
const TITHE_LEAD: float = 5.0
const CYBORG: String = "cyborg"
const TRUCK: String = "hover_truck"
const CyborgRules = preload("res://scripts/enemies/cyborg_rules.gd")
const HoverTruckRules = preload("res://scripts/enemies/hover_truck_rules.gd")
## Enemy types whose attacks a wall's footprint needn't keep off (enemy_spans), as a wider gap needn't
## (WideGapPlacement.NO_KEEP_TYPES): the heli drone (no barrage starts near a wall, and it rises over one:
## Drone._doodad_in_reach, Enemy.dash_wall_lift) and the Enforcer Truck (it drives behind the runner, and no
## volley starts with a wall in the escape: LevelLayout.doodad_between counts the walls in every lane).
const NO_KEEP_TYPES: PackedStringArray = ["drone", "enforcer_truck"]
## Seconds a hover truck's entrance keeps the walls off past the time it needs to drop behind the runner
## (truck_entrance): its first moments of pacing.
const TRUCK_SETTLE_SECONDS: float = 1.0


## One level's walls, at its run speed: what they keep (metres) and where on its track a face may stand.
## Faces are tried on a grid (DashWallTuning.search_step) from `lo` to `hi`; each grid spot carries whether
## something it must keep off is in its footprint (`blocked`), how many plain pieces stand there (`cost`), and
## how many signs block its wall route on each side (`signs_left`, `signs_right`).
class Plan:
	extends RefCounted
	var gen: LevelGenerator
	var t: DashWallTuning
	## The wall's depth, its clear approach before the face and clear stretch past the back, the wall route's
	## stretch before the face, and the least distance between two faces (spacing_for).
	var depth: float = 2.5
	var approach: float = 0.0
	var after: float = 0.0
	var route: float = 0.0
	var spacing: float = 0.0
	## The first and last face a wall may have.
	var lo: float = 0.0
	var hi: float = -1.0
	var step: float = 1.0
	## Taking plain pieces out may make room (DashWallTuning.clear_plain_pieces).
	var clearing: bool = true
	var blocked := PackedInt32Array()
	var cost := PackedInt32Array()
	var signs_left := PackedInt32Array()
	var signs_right := PackedInt32Array()

	## The footprint of a wall whose face is at `face`: [face - approach, back + after].
	func footprint(face: float) -> Vector2:
		return Vector2(face - approach, face + depth + after)

	## Grid spots from lo to hi.
	func size() -> int:
		return maxi(floori((hi - lo) / step) + 1, 0)

	func face_at(i: int) -> float:
		return lo + i * step

	## True if a wall may stand with its face at grid spot `i`, `spacing` from every face in `faces`.
	func fits(i: int, faces: Array[float]) -> bool:
		if i < 0 or i >= size() or blocked[i] > 0:
			return false
		if not clearing and spot_cost(i) > 0:
			return false
		var f: float = face_at(i)
		for other: float in faces:
			if absf(f - other) < spacing - 0.001:
				return false
		return true

	## What standing a wall at grid spot `i` takes out: its footprint's plain pieces, and the signs on the
	## side wall with fewer where neither leaves the wall route open.
	func spot_cost(i: int) -> int:
		var signs: int = 0
		if signs_left[i] > 0 and signs_right[i] > 0:
			signs = mini(signs_left[i], signs_right[i])
		return cost[i] + signs

	## The best face in [a, b] for a wall (`fits`): the one taking out the fewest pieces, then the nearest
	## `want`; NAN if none fits.
	func best(a: float, b: float, want: float, faces: Array[float]) -> float:
		var first: int = maxi(ceili((a - lo) / step - 0.0001), 0)
		var last: int = mini(floori((b - lo) / step + 0.0001), size() - 1)
		var pick: int = -1
		var pick_cost: int = 0
		var pick_off: float = INF
		for i: int in range(first, last + 1):
			if not fits(i, faces):
				continue
			var c: int = spot_cost(i)
			var off: float = absf(face_at(i) - want)
			if pick < 0 or c < pick_cost or (c == pick_cost and off < pick_off):
				pick = i
				pick_cost = c
				pick_off = off
		return face_at(pick) if pick >= 0 else NAN

	## Marks the grid spots whose footprint reaches `span` in `marks` (a hard keep-out's in `blocked`, a
	## plain piece's in `cost`).
	func mark_span(marks: PackedInt32Array, span: Vector2) -> void:
		# A face f reaches it when f - approach <= span.y and f + depth + after >= span.x.
		mark_faces(marks, Vector2(span.x - depth - after, span.y + approach))

	## Marks the grid spots whose face lies in `faces` (inclusive).
	func mark_faces(marks: PackedInt32Array, faces: Vector2) -> void:
		var n: int = size()
		if n <= 0 or faces.y < lo or faces.x > hi:
			return
		var first: int = maxi(ceili((faces.x - lo) / step - 0.0001), 0)
		var last: int = mini(floori((faces.y - lo) / step + 0.0001), n - 1)
		for i: int in range(first, last + 1):
			marks[i] += 1


static func tuning() -> DashWallTuning:
	return DashWallTuning.load_default()


static func powerups() -> PowerupTuning:
	var res: Resource = load(POWERUPS_PATH) if ResourceLoader.exists(POWERUPS_PATH) else null
	return res as PowerupTuning if res is PowerupTuning else PowerupTuning.new()


## The run speed plus the dash's bonus at `gen`'s level: the fastest a runner comes at or through a wall.
static func dash_speed(gen: LevelGenerator, pt: PowerupTuning = null) -> float:
	var p: PowerupTuning = pt if pt != null else powerups()
	return gen.speed + p.dash_speed_bonus


## The dash's longest cooldown, over every tier (PowerupTuning: 8 s at tier 1).
static func longest_cooldown(pt: PowerupTuning) -> float:
	var out: float = pt.dash_cooldown
	for c: float in pt.dash_upgrade_cooldowns:
		out = maxf(out, c)
	return out


## The least distance between two walls' faces at `gen`'s level (GDD §9.14, proposed: the dash's longest
## cooldown is over before the next wall): that cooldown and DashWallTuning.cooldown_margin_seconds of run,
## plus the ground a dash adds (its duration times its speed bonus). The same keeps a dash bait from a face.
static func spacing_for(gen: LevelGenerator, t: DashWallTuning = null, pt: PowerupTuning = null) -> float:
	var tt: DashWallTuning = t if t != null else tuning()
	var p: PowerupTuning = pt if pt != null else powerups()
	return (longest_cooldown(p) + tt.cooldown_margin_seconds) * gen.speed + p.dash_duration * p.dash_speed_bonus


## The stretch wall entry `w` (LevelLayout.dash_walls) keeps clear in every lane at `gen`'s level: its clear
## approach before its face, itself, and the clear stretch past its back (Plan.footprint).
static func footprint(gen: LevelGenerator, w: Dictionary, t: DashWallTuning = null) -> Vector2:
	var tt: DashWallTuning = t if t != null else tuning()
	var v: float = dash_speed(gen)
	return Vector2(float(w["start"]) - tt.approach_seconds * v, float(w["end"]) + tt.after_seconds * v)


static func apply(gen: LevelGenerator) -> void:
	var count: int = gen.config.dash_walls
	if count <= 0:
		return
	var t: DashWallTuning = tuning()
	var rng: RandomNumberGenerator = gen.rng_for(FEATURE)
	var plan: Plan = plan_for(gen, t)
	var faces: Array[float] = []
	var from: float = plan.lo
	if gen.config.feature_starts.has(FEATURE):
		# Its introduction: the first fair spot from its start, within intro_seconds where one fits.
		var intro: float = plan.best(plan.lo, minf(plan.lo + t.intro_seconds * gen.speed, plan.hi), plan.lo, faces)
		if is_nan(intro):
			intro = plan.best(plan.lo, plan.hi, plan.lo, faces)
		if not is_nan(intro):
			_place(gen, plan, intro, faces)
			from = intro + plan.spacing
	# The rest spread through the level: a part each, a seeded spot aimed for in it (every draw is made, so a
	# part without room never reshuffles the next).
	var left: int = count - faces.size()
	if left > 0 and from <= plan.hi:
		var part: float = (plan.hi - from) / float(left)
		for k: int in left:
			var a: float = from + k * part
			var want: float = a + rng.randf_range(0.25, 0.75) * part
			var at: float = plan.best(a, a + part, want, faces)
			if not is_nan(at):
				_place(gen, plan, at, faces)
	# Where a part had no room: the best of the rest, along the level.
	while faces.size() < count:
		var at: float = plan.best(plan.lo, plan.hi, plan.lo, faces)
		if is_nan(at):
			break
		_place(gen, plan, at, faces)
	if faces.is_empty():
		gen.warnings.append("dash walls: no fair spot for one in the level (GDD §5: a feature a level has appears in it)")
	gen.layout.dash_walls.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["start"]) < float(b["start"]))


## What a level's walls keep, and where on its track a face may stand (see the header): with `checking`,
## for a finished layout (problems()), everything already there counts against a footprint, the zone doodads
## and every hole and fence too, and the wall gaps and wall fences against the route; while placing, plain
## pieces only cost what taking them out costs.
static func plan_for(gen: LevelGenerator, t: DashWallTuning = null, checking: bool = false) -> Plan:
	var p := Plan.new()
	p.gen = gen
	p.t = t if t != null else tuning()
	var pt: PowerupTuning = powerups()
	var mt: MovementTuning = gen.tuning
	var lay: LevelLayout = gen.layout
	var v: float = dash_speed(gen, pt)
	p.depth = mt.dash_wall_depth
	p.approach = p.t.approach_seconds * v
	p.after = p.t.after_seconds * v
	p.route = p.t.wall_route_seconds * gen.speed
	p.spacing = spacing_for(gen, p.t, pt)
	p.step = maxf(p.t.search_step, 0.05)
	p.clearing = p.t.clear_plain_pieces and not checking
	p.lo = maxf(gen.config.start_clear_distance + p.approach, gen.feature_start(FEATURE))
	p.hi = lay.length - gen.config.end_clear_distance - p.depth - p.after
	var n: int = p.size()
	p.blocked.resize(n)
	p.cost.resize(n)
	p.signs_left.resize(n)
	p.signs_right.resize(n)
	p.blocked.fill(0)
	p.cost.fill(0)
	p.signs_left.fill(0)
	p.signs_right.fill(0)
	if n <= 0:
		return p
	var soft: PackedInt32Array = p.cost if p.clearing else p.blocked
	var half: float = mt.fence_depth * 0.5
	for g: Dictionary in lay.gaps:
		p.mark_span(soft, Vector2(float(g["start"]), float(g["end"])))
	var powered: Array[Dictionary] = powered_fences(gen)
	for f: Dictionary in lay.fences:
		var span := Vector2(float(f["at"]) - half, float(f["at"]) + half)
		var fixed: bool = bool(f.get("pulsing", false)) or powered.has(f)
		p.mark_span(p.blocked if fixed else soft, span)
	for s: Dictionary in lay.speed_pads:
		p.mark_span(p.blocked, Vector2(float(s["at"]), float(s["at"]) + mt.speed_pad_length))
	for pad: Dictionary in lay.pads:
		p.mark_span(p.blocked, gen.zones.pad_zone(float(pad["at"])))
	for r: Dictionary in lay.ramps:
		var at: float = float(r["at"])
		p.mark_span(p.blocked, Vector2(at, maxf(gen.ramp_launch(r).end(), at + mt.ramp_length)))
	for h: Dictionary in lay.hulls:
		p.mark_span(p.blocked, Vector2(float(h["start"]), gen.zones.landing_zone(h).y))
	for c: Dictionary in lay.cuts:
		p.mark_span(p.blocked, FloorCutPlan.window(c, gen.speed))
	for d: Dictionary in lay.doodads:
		p.mark_span(p.blocked, Vector2(float(d["start"]), float(d["end"])))
	var hooks: Dictionary = {}
	for e: Dictionary in lay.enemies:
		for span: Vector2 in enemy_spans(gen, e, hooks):
			p.mark_span(p.blocked, span)
	for k: Dictionary in gen.rules_doodad_keep_outs():
		if _counts(k):
			p.mark_span(p.blocked, Vector2(float(k["from"]), float(k["to"])))
	if p.t.keep_dash_baits:
		for b: float in bait_points(gen, checking):
			p.mark_faces(p.blocked, Vector2(b, b + p.spacing))
	# The wall route: a face whose route window [face - route, back] reaches a sign (with `checking`, a wall gap
	# or a wall fence too) on a side has that side closed.
	var routes: Array = [_route_blockers(gen, -1, checking), _route_blockers(gen, 1, checking)]
	for k: int in 2:
		var marks: PackedInt32Array = p.signs_left if k == 0 else p.signs_right
		for span: Vector2 in routes[k]:
			p.mark_faces(marks, Vector2(span.x - p.depth, span.y + p.route))
	if not p.clearing:
		for i: int in n:
			if p.signs_left[i] > 0 and p.signs_right[i] > 0:
				p.blocked[i] += 1
	return p


## True if rules keep-out `k` (LevelGenerator.rules_doodad_keep_outs) keeps the walls off: one of every lane
## (a Bad Dream's chase, a Gilded Sentinel's turn), never the walls' own, and never one of a single lane (the
## hover truck's: the truck bursts through a wall in its way, see the header).
static func _counts(k: Dictionary) -> bool:
	return String(k.get("type", "")) != FEATURE and not k.has("lane")


## The fences a fence generator powers (FenceGenerator.fences_in_reach): with the pulsing ones, the fences a
## wall never takes out to make room (the `pulsing` feature counts those; a generator powering nothing goes).
static func powered_fences(gen: LevelGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var gt: FenceGeneratorTuning = GeneratorRules.tuning()
	var geo := TrackGeometry.new(gen.layout.lane_count, gen.tuning)
	for e: Dictionary in gen.layout.enemies:
		if String(e.get("type", "")) == GENERATOR:
			out.append_array(FenceGenerator.fences_in_reach(gen.layout, geo, float(e["at"]), int(e["lane"]), gt.emp_radius))
	return out


## The stretches enemy entry `e` keeps a wall's footprint off (see the header), as a wider gap's are kept
## (WideGapPlacement.keeps_of): what the fill pass keeps for it (LevelGenerator.enemy_keep_out) and the floor
## it uses; for a floor cyborg its obstacle margin either side (CyborgRules.obstacle_margin_at: its bolts never
## land near a wall, CyborgGun.path_clear); for a planned Resonator each pulse, from its warning until its wave
## has passed (DangerDensity.resonator_pulse_windows: between them it only hovers, rising over a wall, and
## every pulse waits for floor clear of walls, Resonator.pulse_clear); for a Tithe Collector its whole stay;
## nothing for NO_KEEP_TYPES.
static func enemy_spans(gen: LevelGenerator, e: Dictionary, hooks: Dictionary) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var type: String = String(e.get("type", ""))
	if NO_KEEP_TYPES.has(type):
		return out
	if type == CYBORG:
		var ct := EnemyDirector.tuning_for(CYBORG) as CyborgTuning
		var margin: float = CyborgRules.obstacle_margin_at(ct, gen.pace) if ct != null else gen.metres(10.0)
		out.append(Vector2(float(e["at"]) - margin, float(e["at"]) + margin))
		return out
	if type == TRUCK:
		out.append(truck_entrance(gen, float(e["at"])))
		return out
	var pulses: Array[Vector2] = LevelGenerator.DangerDensity.resonator_pulse_windows(gen, e)
	if not pulses.is_empty():
		return pulses
	var k: Vector2 = gen.enemy_keep_out(e, hooks)
	if k.y >= k.x:
		out.append(k)
	var floor_span: Vector2 = LevelGenerator.enemy_floor_span(e, gen.pace)
	if floor_span.y >= floor_span.x:
		out.append(floor_span)
	if type == TITHE:
		var tt := EnemyDirector.tuning_for(TITHE) as TitheCollectorTuning
		var stay: float = tt.stay_seconds() if tt != null else 12.0
		var at: float = float(e["at"])
		out.append(Vector2(at - TITHE_LEAD, at + stay * gen.speed))
	return out


## A hover truck at `at`: its entrance, the stretch a wall's footprint keeps off (enemy_spans), from the start of
## its lane's window (it bangs on the wall, then bursts out: HoverTruckRules.window_start) until it has
## emerged and had the time it needs to drop behind the runner (HoverTruckTuning.give_way_seconds, with
## TRUCK_SETTLE_SECONDS more): from then on it gives way to a wall ahead (HoverTruck: it drops behind the
## runner and holds back until they've broken it), so the rest of its stay needn't keep the walls off.
static func truck_entrance(gen: LevelGenerator, at: float) -> Vector2:
	var t: HoverTruckTuning = HoverTruckRules.tuning()
	var give_way: float = t.emerge_seconds + t.give_way_seconds(t.pace_offset) + TRUCK_SETTLE_SECONDS
	return Vector2(HoverTruckRules.window_start(t, at, gen.pace), at + give_way * gen.speed)


## Where the runner may spend the dash on something else (DashWallTuning.keep_dash_baits; GDD §9.14: nothing
## that needs the dash comes just before a wall): each Buzz Overdrive's charge where it meets the runner, each
## fence generator, and with `doodads` each zone doodad's front (the doodads come after the walls and keep off
## them themselves, bait_keep_outs).
static func bait_points(gen: LevelGenerator, doodads: bool = false) -> Array[float]:
	var out: Array[float] = []
	for e: Dictionary in gen.layout.enemies:
		match String(e.get("type", "")):
			BUZZ:
				var cut: Dictionary = BuzzRules.cut_of(gen.layout, e)
				if not cut.is_empty():
					out.append(FloorCutPlan.meet(cut, gen.speed))
			GENERATOR:
				out.append(float(e["at"]))
	if doodads:
		for d: Dictionary in gen.layout.doodads:
			out.append(float(d["start"]))
	return out


## What closes the wall route on wall `side` (-1 left, 1 right): its signs, and with `checking` its wall gaps
## and wall fences (a fence's depth either side of it).
static func _route_blockers(gen: LevelGenerator, side: int, checking: bool) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var lay: LevelLayout = gen.layout
	for s: Dictionary in lay.signs:
		if int(s["side"]) == side:
			out.append(Vector2(float(s["start"]), float(s["end"])))
	if checking:
		var half: float = gen.tuning.fence_depth * 0.5
		for g: Dictionary in lay.wall_gaps:
			if int(g["side"]) == side:
				out.append(Vector2(float(g["start"]), float(g["end"])))
		for w: Dictionary in lay.wall_fences:
			if int(w["side"]) == side:
				out.append(Vector2(float(w["at"]) - half, float(w["at"]) + half))
	return out


## Stands a wall with its face at `face` (a spot plan.best found): takes out the plain pieces in its footprint
## and, where both side walls' routes are closed, the signs on the side with fewer there (the left on a tie).
static func _place(gen: LevelGenerator, plan: Plan, face: float, faces: Array[float]) -> void:
	var lay: LevelLayout = gen.layout
	var fp: Vector2 = plan.footprint(face)
	var half: float = gen.tuning.fence_depth * 0.5
	_keep(lay.gaps, func(g: Dictionary) -> bool: return not (float(g["start"]) <= fp.y and float(g["end"]) >= fp.x))
	_keep(lay.fences, func(f: Dictionary) -> bool:
		return not (float(f["at"]) - half <= fp.y and float(f["at"]) + half >= fp.x))
	var window := Vector2(face - plan.route, face + plan.depth)
	var closed: Array[int] = []
	for side: int in [-1, 1]:
		var n: int = 0
		for s: Dictionary in lay.signs:
			if int(s["side"]) == side and float(s["start"]) <= window.y and float(s["end"]) >= window.x:
				n += 1
		closed.append(n)
	if closed[0] > 0 and closed[1] > 0:
		var side: int = -1 if closed[0] <= closed[1] else 1
		_keep(lay.signs, func(s: Dictionary) -> bool:
			return not (int(s["side"]) == side and float(s["start"]) <= window.y and float(s["end"]) >= window.x))
	lay.dash_walls.append({"start": face, "end": face + plan.depth,
		"seed": hash([gen.config.level_seed, FEATURE, lay.dash_walls.size()])})
	faces.append(face)


## Keeps the items of `list` for which `keep` returns true (in place, so typed arrays stay typed).
static func _keep(list: Array[Dictionary], keep: Callable) -> void:
	var kept: Array[Dictionary] = []
	for item: Dictionary in list:
		if keep.call(item):
			kept.append(item)
	list.assign(kept)


## Every wall in `layout`: where its face stands (LevelGenerator.feature_positions, the every-feature check).
static func positions(layout: LevelLayout) -> Array[float]:
	var out: Array[float] = []
	for w: Dictionary in layout.dash_walls:
		out.append(float(w["start"]))
	return out


## What the passes after the rules keep off (LevelGenerator.rules_doodad_keep_outs: the zone doodads, the
## danger density pass, the wider gaps, the cyborgs planted in charge paths, the wall fences' drop windows,
## City 1's extra gaps): every wall's footprint (footprint()), in every lane.
static func doodad_keep_outs(gen: LevelGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if gen.layout.dash_walls.is_empty():
		return out
	var t: DashWallTuning = tuning()
	for w: Dictionary in gen.layout.dash_walls:
		var fp: Vector2 = footprint(gen, w, t)
		out.append({"from": fp.x, "to": fp.y, "type": FEATURE})
	return out


## Where no zone doodad stands (LevelGenerator.doodad_keep_outs; DashWallTuning.keep_dash_baits): the spacing
## before every wall's face (spacing_for), so a doodad the runner might dash through never leaves the dash
## spent at a wall. Empty without keep_dash_baits.
static func bait_keep_outs(gen: LevelGenerator) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if gen.layout.dash_walls.is_empty():
		return out
	var t: DashWallTuning = tuning()
	if not t.keep_dash_baits:
		return out
	var spacing: float = spacing_for(gen, t)
	for w: Dictionary in gen.layout.dash_walls:
		out.append(Vector2(float(w["start"]) - spacing, float(w["start"])))
	return out


## What both side walls keep whole beside every wall (WallGapPlacement.keep_outs): its wall route, from
## wall_route_seconds of run before its face to its back.
static func wall_keep_outs(gen: LevelGenerator) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if gen.layout.dash_walls.is_empty():
		return out
	var t: DashWallTuning = tuning()
	for w: Dictionary in gen.layout.dash_walls:
		out.append(Vector2(float(w["start"]) - t.wall_route_seconds * gen.speed, float(w["end"])))
	return out


## Every placement rule a finished level's walls break (see the header), for the tests: [] if none. Run on
## the finished layout, so it also catches a pass after the rules that put something where a wall keeps.
static func problems(gen: LevelGenerator) -> PackedStringArray:
	var out: PackedStringArray = []
	var walls: Array[Dictionary] = gen.layout.dash_walls
	if walls.is_empty():
		return out
	var t: DashWallTuning = tuning()
	var plan: Plan = plan_for(gen, t, true)
	var faces: Array[float] = []
	for w: Dictionary in walls:
		var face: float = float(w["start"])
		if absf(float(w["end"]) - face - plan.depth) > 0.01:
			out.append("the wall at %.1f m is %.2f m deep, not %.2f m" % [face, float(w["end"]) - face, plan.depth])
		if face < plan.lo - 0.01 or face > plan.hi + 0.01:
			out.append("the wall at %.1f m isn't between the run-up (or the feature's start) and the end-clear stretch" % face)
		for other: float in faces:
			if absf(face - other) < plan.spacing - 0.01:
				out.append("the wall at %.1f m is %.1f m after the one at %.1f m (at least %.1f m)" % [face, face - other,
					other, plan.spacing])
		faces.append(face)
		# The grid spot at its face, or the nearest (a face placed on the grid lies on it).
		var i: int = clampi(roundi((face - plan.lo) / plan.step), 0, maxi(plan.size() - 1, 0))
		if plan.size() <= 0:
			continue
		if plan.blocked[i] > 0:
			out.append("the wall at %.1f m: %s" % [face, _why(gen, plan, face)])
	return out


## Why the wall with its face at `face` breaks a rule (problems()): what stands in its footprint, its baits or
## its route.
static func _why(gen: LevelGenerator, plan: Plan, face: float) -> String:
	var lay: LevelLayout = gen.layout
	var fp: Vector2 = plan.footprint(face)
	var half: float = gen.tuning.fence_depth * 0.5
	var found: PackedStringArray = []
	for g: Dictionary in lay.gaps:
		if float(g["start"]) <= fp.y and float(g["end"]) >= fp.x:
			found.append("a hole at %.1f m" % float(g["start"]))
	for f: Dictionary in lay.fences:
		if float(f["at"]) - half <= fp.y and float(f["at"]) + half >= fp.x:
			found.append("a fence at %.1f m" % float(f["at"]))
	for d: Dictionary in lay.doodads:
		if float(d["start"]) <= fp.y and float(d["end"]) >= fp.x:
			found.append("a doodad at %.1f m" % float(d["start"]))
	for h: Dictionary in lay.hulls:
		if float(h["start"]) <= fp.y and gen.zones.landing_zone(h).y >= fp.x:
			found.append("a ceiling from %.1f m" % float(h["start"]))
	var hooks: Dictionary = {}
	for e: Dictionary in lay.enemies:
		for span: Vector2 in enemy_spans(gen, e, hooks):
			if span.x <= fp.y and span.y >= fp.x:
				found.append("%s at %.1f m" % [e.get("type", "?"), float(e["at"])])
				break
	for k: Dictionary in gen.rules_doodad_keep_outs():
		if _counts(k) and float(k["from"]) <= fp.y and float(k["to"]) >= fp.x:
			found.append("a rule's keep-out %.1f-%.1f m" % [float(k["from"]), float(k["to"])])
	if plan.t.keep_dash_baits:
		for b: float in bait_points(gen, true):
			if face >= b and face <= b + plan.spacing:
				found.append("a dash bait at %.1f m" % b)
	var i: int = clampi(roundi((face - plan.lo) / plan.step), 0, maxi(plan.size() - 1, 0))
	if plan.signs_left[i] > 0 and plan.signs_right[i] > 0:
		found.append("no side wall open to run past it")
	if found.is_empty():
		found.append("something it keeps off is there (a pad, ramp, speed pad or floor cut)")
	return ", ".join(found)
