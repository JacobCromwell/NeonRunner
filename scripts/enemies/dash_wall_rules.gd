extends RefCounted
## Generator rules for dash walls (task H7a; GDD §9.14, owner, October 8, 2026): buildings standing across
## every floor lane, like a building in the middle of the street, which the runner dashes through. They
## leave the side walls open ("a wall runner passes it") and no ceiling shares their stretch. They have no
## patterns, and they stand in two stages:
## - a level that introduces them (a feature start) stands its first with the rules, after every other
##   feature's (apply(), RUN_AFTER), on the level's final enemies, ceilings, pads, ramps and floor cuts, so the
##   player meets it right after its hint and every pass after the rules keeps off it;
## - the rest stand after the danger density pass's obstacles and the zone doodads (after_doodads(), from
##   LevelGenerator._after_doodad_rules), in the room the passes before them left: the fill pass, the danger
##   density pass and the doodads fill the level as they would without them, so the share of danger the
##   owner asked for holds (tests/suites/test_danger_density.gd; a wall standing earlier took the room those
##   passes add enemies and rows in, most on 3 lanes) and a crowded level keeps its few doodads; a wall takes
##   out plain pieces where it must rather than the level losing what it would have had.
## Numbers: DashWallTuning (data/tuning/dash_walls.tres), seconds at the level's run speed or at the dash's speed
## (the run's plus PowerupTuning.dash_speed_bonus), so a faster zone keeps them; the wall's size is
## MovementTuning's.
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
##   it burst out of the building (HoverTruck._burst_dash_walls). The Enforcer Truck's attacks need nothing: it
##   drives behind the runner, and a wall always breaks as the runner reaches it (a dash, a crash or a pass on a
##   side wall: Player._check_dash_walls), so it only ever meets a broken one and drives on through; its volleys
##   never start with a wall in the escape (as with a doodad). When it shows itself (task C6b) it pulls up beside
##   the runner, its front ahead of them: the walls keep off its planned showing windows (the calm stretches its
##   rules keep, enforcer_truck_rules.gd, counted with the rules' keep-outs below), and in play it never shows itself
##   where its view would reach a wall (EnforcerTruckRoom: a wall is solid in every lane).
## - The flyers ahead of the runner (the heli drone, which stays until it's downed, the Resonator pulling away
##   or between its pulses, a Tithe Collector fleeing) rise over a standing wall in their way
##   (Enemy.dash_wall_lift); the drone and the truck's cannon hold their fire near one, and the Resonator's
##   waves never meet one (they read LevelLayout.doodad_between, which counts the walls in every lane), so the
##   heli drone keeps nothing (NO_KEEP_TYPES).
## - Spacing (GDD §9.14, proposed): faces at least spacing_for() apart, the dash's longest cooldown and
##   cooldown_margin_seconds of run plus the ground the dash itself covers, so the dash spent on one wall is
##   back before the next. With keep_dash_baits, nothing else that invites a dash comes within that spacing
##   before a face: a Buzz Overdrive's charge meeting the runner (a panic dash smashes it, GDD §9.9), a fence
##   generator (its hint says to dash through it) and the end of a Tithe Collector's stay (its hint says to catch
##   it by dashing through it, among others; bait_of). A zone doodad isn't one: it never needs the dash (it only
##   pushes the runner aside, and no hint sends the dash at it), so it keeps off the footprint only.
## - The wall route (GDD §9.14: "a player running on a side wall passes it"): from wall_route_seconds before
##   its face to its back, at least one side wall holds no sign (a sign blocks the entry and hurts); the side
##   wall gaps and wall fences, placed after, keep off both walls there (WallGapPlacement.keep_outs,
##   wall_keep_outs; a wall fence's drop window keeps off the footprint, doodad_keep_outs).
## - The level: the footprint between the run-up and the end-clear stretch, the face past the feature's start.
## - A wider gap (task G7) from its take-off margin to its landing margin (WideGapPlacement.keep_outs), as it
##   keeps off a wall: each stays the only demand at its take-off and landing. A cyborg planted in a charge's
##   path (task G7) keeps its encounter (ChargePathPlacement.encounter_span: from its charger's claim to past its
##   strike) as every big attack does. And a zone doodad keeps its push's lead before it and the level's spacing
##   past it (doodad_span), as it keeps them from a wall placed before it.
## - A level's quiet stretches (The Hush, GDD §5: "long silent stretches"; LevelGenerator.quiet_stretches), as the
##   fill and danger density passes keep them, unless that leaves the level with no wall: then one stands in one.
## Plain holes and fences (never a pulsing fence or one a fence generator powers; in the second stage the fill
## pass's and the danger density pass's as well) in a footprint, and the signs on one side wall where both
## block the route, are taken out to make room (clear_plain_pieces: taking content out never makes a level
## unfair); a spot that needs nothing taken out is preferred.
##
## How many, and where: up to LevelConfig.dash_walls. A level that gives the feature a start
## (LevelConfig.feature_starts: Corporate 1, after the Buzz Overdrive's introduction) introduces it with the
## rules (apply()), at the first fair spot from its start, whatever plain pieces it takes out there, so the
## player meets it right after its first-encounter hint; where none comes within
## DashWallTuning.intro_window_seconds it makes room there (_make_room: a few enemies of MAKE_ROOM_TYPES go,
## never the last of a feature nor any feature's first). The rest (after_doodads()) spread through the level
## past it (the stretch from the first possible face to the last cut into as many parts, a seeded spot aimed
## for in each, the best fair spot in that part taken: nothing to take out first, then the nearest), then the
## best of the rest wherever a part had none, then, where the level is crowded and that leaves it short, the
## most that fit, as far apart as they can be. A level left with no wall at all makes room for one as an
## introduction does (_make_room, over the whole level; never a planted cyborg or its charger, nor a Buzz
## Overdrive an Enforcer Truck counts among its baits), then, the last resort, with the zone doodads in the way
## going too (scenery: DESIGN-TBD, docs/OPEN_QUESTIONS.md item 677), and one with no fair spot even then gets a
## warning (the campaign tests fail on any): every feature appears (GDD §5). Its own random stream (LevelGenerator.rng_for),
## so the passes before it place exactly what they did; a level without the feature (or with a count of 0) draws
## nothing and is built byte for byte as before.
##
## What keeps off them: the passes between the two stages keep off an introduction (the fill pass,
## LevelGenerator.fill_keep_outs, every footprint in every lane; the danger density pass, the wider gaps, the
## cyborgs planted in charge paths and the zone doodads, the rules' keep-outs in every lane, doodad_keep_outs);
## after the second stage the wall fences' drop windows (doodad_keep_outs), the side wall gaps and wall fences
## beside them (wall_keep_outs), and the credits (none inside a wall: LevelLayout.doodad_between).
## problems() re-checks every wall for the tests.
## DESIGN-TBD (docs/OPEN_QUESTIONS.md items 644–659): every number, how many a level, the baits, the route.

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
const ENFORCER: String = "enforcer_truck"
const CyborgRules = preload("res://scripts/enemies/cyborg_rules.gd")
const HoverTruckRules = preload("res://scripts/enemies/hover_truck_rules.gd")
## Enemy types whose attacks a wall's footprint needn't keep off (enemy_spans), as a wider gap needn't
## (WideGapPlacement.NO_KEEP_TYPES): the heli drone (no barrage starts near a wall, and it rises over one:
## Drone._doodad_in_reach, Enemy.dash_wall_lift) and the Enforcer Truck (it drives behind the runner, and no
## volley starts with a wall in the escape: LevelLayout.doodad_between counts the walls in every lane; its
## showing windows are its rules' calm stretches, kept off with the rules' keep-outs, _counts).
const NO_KEEP_TYPES: PackedStringArray = ["drone", "enforcer_truck"]
## Seconds a hover truck's entrance keeps the walls off past the time it needs to drop behind the runner
## (truck_entrance): its first moments of pacing.
const TRUCK_SETTLE_SECONDS: float = 1.0
## Enemy types the introduction may take out to make room for itself (_make_room): ones that leave nothing
## behind but a Buzz Overdrive's own floor cut, which goes with it (never a host: its chase is planned on it).
const MAKE_ROOM_TYPES: PackedStringArray = ["buzz_overdrive", "generator", "cyborg", "window_cyborg", "screech"]


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

	## The first face in [a, b] where a wall fits (`fits`), whatever it takes out; NAN if none does.
	func first(a: float, b: float, faces: Array[float]) -> float:
		var lo_i: int = maxi(ceili((a - lo) / step - 0.0001), 0)
		var hi_i: int = mini(floori((b - lo) / step + 0.0001), size() - 1)
		for i: int in range(lo_i, hi_i + 1):
			if fits(i, faces):
				return face_at(i)
		return NAN

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
	return tt.footprint(w, dash_speed(gen))


## The first stage (with the rules, after every other feature's: RUN_AFTER): a level that gives the feature a
## start introduces it there (see the header), at the first fair spot from its start (the player meets it right
## after its hint), making room for one near the start where none is (_make_room). Any other level waits for
## the second stage (after_doodads).
static func apply(gen: LevelGenerator) -> void:
	if gen.config.dash_walls <= 0 or not gen.config.feature_starts.has(FEATURE):
		return
	var t: DashWallTuning = tuning()
	var plan: Plan = plan_for(gen, t)
	var faces: Array[float] = []
	var window: float = minf(plan.lo + t.intro_window_seconds * gen.speed, plan.hi)
	var intro: float = plan.first(plan.lo, window, faces)
	if is_nan(intro) and _make_room(gen, plan, plan.lo, window):
		plan = plan_for(gen, t)
		intro = plan.first(plan.lo, window, faces)
	if is_nan(intro):
		intro = plan.first(plan.lo, plan.hi, faces)
	if not is_nan(intro):
		_place(gen, plan, intro, faces)


## The second stage (LevelGenerator._after_doodad_rules: after the danger density pass's obstacles and the zone
## doodads, before the wall fences): the rest of LevelConfig.dash_walls, past an introduction, in the room the
## passes before left (see the header), spread through the level: a part each, a seeded spot aimed for in it
## (every draw is made, so a part without room never reshuffles the next), then the best of the rest; where
## that leaves the level short of its count (a crowded level, its fair spots few and close), the most that fit,
## as far apart as they can be (_most_apart); and a level left with none at all makes room for one
## (_make_room, over the whole level).
static func after_doodads(gen: LevelGenerator) -> void:
	var count: int = gen.config.dash_walls
	if count <= 0:
		return
	var t: DashWallTuning = tuning()
	var rng: RandomNumberGenerator = gen.rng_for(FEATURE)
	var plan: Plan = plan_for(gen, t)
	var faces: Array[float] = positions(gen.layout)
	var from: float = plan.lo
	for f: float in faces:
		from = maxf(from, f + plan.spacing)
	var left: int = count - faces.size()
	var chosen: Array[float] = []
	var taken: Array[float] = faces.duplicate()
	if left > 0 and from <= plan.hi:
		var part: float = (plan.hi - from) / float(left)
		for k: int in left:
			var a: float = from + k * part
			var want: float = a + rng.randf_range(0.25, 0.75) * part
			var at: float = plan.best(a, a + part, want, taken)
			if not is_nan(at):
				taken.append(at)
				chosen.append(at)
	# Where a part had no room: the best of the rest, along the level.
	while faces.size() + chosen.size() < count:
		var at: float = plan.best(plan.lo, plan.hi, plan.lo, taken)
		if is_nan(at):
			break
		taken.append(at)
		chosen.append(at)
	if left > 0 and faces.size() + chosen.size() < count:
		var most: Array[float] = _most_apart(plan, faces, left)
		if most.size() > chosen.size():
			chosen = most
	for at: float in chosen:
		_place(gen, plan, at, faces)
	# Kept out of the quiet stretches, a level paced in bursts may have no room left: one stands in a quiet
	# stretch rather than none at all.
	if faces.is_empty() and not gen.quiet_stretches().is_empty():
		plan = plan_for(gen, t, false, false)
		var at: float = plan.best(plan.lo, plan.hi, (plan.lo + plan.hi) * 0.5, faces)
		if not is_nan(at):
			_place(gen, plan, at, faces)
	if faces.is_empty() and _make_room(gen, plan, plan.lo, plan.hi):
		# Nothing fit outside the quiet stretches either: the room made may lie in one.
		plan = plan_for(gen, t, false, false)
		var at: float = plan.best(plan.lo, plan.hi, (plan.lo + plan.hi) * 0.5, faces)
		if not is_nan(at):
			_place(gen, plan, at, faces)
	# The last resort, where even that leaves the level no wall: the zone doodads in the way may go too (the H merge,
	# with task K4's denser curve: Corporate 2 at 3 lanes on seed 7101 had none). DESIGN-TBD (docs/OPEN_QUESTIONS.md
	# item 677).
	if faces.is_empty() and _make_room(gen, plan, plan.lo, plan.hi, true):
		plan = plan_for(gen, t, false, false)
		var at: float = plan.best(plan.lo, plan.hi, (plan.lo + plan.hi) * 0.5, faces)
		if not is_nan(at):
			_place(gen, plan, at, faces)
	if faces.is_empty():
		gen.warnings.append("dash walls: no fair spot for one in the level (GDD §5: a feature a level has appears in it)")
	gen.layout.dash_walls.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["start"]) < float(b["start"]))


## Up to `want` faces where a wall fits (Plan.fits: its spacing from each of `fixed` and from each other), the
## most there are room for, as far apart as they can be: the widest gap between neighbours at which that many
## still fit (a bisection), each then at the first fitting spot that far past the one before.
static func _most_apart(plan: Plan, fixed: Array[float], want: int) -> Array[float]:
	var spots: Array[float] = []
	for i: int in plan.size():
		if plan.fits(i, fixed):
			spots.append(plan.face_at(i))
	var out: Array[float] = _first_apart(spots, plan.spacing, want)
	if out.size() < want:
		return out
	var lo_gap: float = plan.spacing
	var hi_gap: float = maxf(plan.hi - plan.lo, plan.spacing)
	for _k: int in 24:
		var gap: float = (lo_gap + hi_gap) * 0.5
		var tried: Array[float] = _first_apart(spots, gap, want)
		if tried.size() >= want:
			lo_gap = gap
			out = tried
		else:
			hi_gap = gap
	return out


## Up to `want` of `spots` (along the track), each the first at least `gap` past the one before.
static func _first_apart(spots: Array[float], gap: float, want: int) -> Array[float]:
	var out: Array[float] = []
	for f: float in spots:
		if out.size() >= want:
			break
		if out.is_empty() or f - out[out.size() - 1] >= gap - 0.001:
			out.append(f)
	return out


## What a level's walls keep, and where on its track a face may stand (see the header): with `checking`,
## for a finished layout (problems()), everything already there counts against a footprint, the zone doodads
## and every hole and fence too, and the wall gaps and wall fences against the route; while placing, plain
## pieces only cost what taking them out costs, and with `quiet` a level's quiet stretches stay clear too (The
## Hush's long silent stretches, LevelGenerator.quiet_stretches, as the fill and danger density passes keep them).
static func plan_for(gen: LevelGenerator, t: DashWallTuning = null, checking: bool = false, quiet: bool = true) -> Plan:
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
	# A wider gap (task G7: the second stage comes after them) from its take-off margin to its landing margin.
	for zone: Vector2 in WideGapPlacement.keep_outs(gen):
		p.mark_span(p.blocked, zone)
	if quiet and not checking:
		for q: Vector2 in gen.quiet_stretches():
			p.mark_span(p.blocked, q)
	for d: Dictionary in lay.doodads:
		p.mark_span(p.blocked, doodad_span(gen, d) if not checking else Vector2(float(d["start"]), float(d["end"])))
	var hooks: Dictionary = {}
	for e: Dictionary in lay.enemies:
		for span: Vector2 in enemy_spans(gen, e, hooks):
			p.mark_span(p.blocked, span)
	for c: Dictionary in ChargePathPlacement.planted_in(lay):
		p.mark_span(p.blocked, ChargePathPlacement.encounter_span(gen, c))
	for k: Dictionary in gen.rules_doodad_keep_outs():
		if _counts(k):
			p.mark_span(p.blocked, Vector2(float(k["from"]), float(k["to"])))
	if p.t.keep_dash_baits:
		for b: float in bait_points(gen):
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


## Makes room for the introduction in faces [a, b] (apply()), where no wall fits: the face there that the
## fewest enemies keep a wall from, all of them of MAKE_ROOM_TYPES (whatever else keeps it, a ceiling, a pad,
## a ramp, another kind of enemy, rules them out), is cleared of them: each goes from the layout, a Buzz
## Overdrive with its floor cut. Never the last of a feature, nor any feature's introduction in the level (the
## first of it from its start): what each feature has first stays where it was. Taking content out never makes a
## level unfair (as PadPlacement and WideGapPlacement do for their guarantees), and the introduction gets the
## calm stretch it should have (GDD §6: one new thing at a time). With `doodads_go` (after_doodads' last resort,
## where a level would otherwise have no wall at all) the zone doodads in the way may go too: scenery, never a
## feature, so taking one out moves nothing a feature has. True if anything went.
static func _make_room(gen: LevelGenerator, plan: Plan, a: float, b: float, doodads_go: bool = false) -> bool:
	var lay: LevelLayout = gen.layout
	var n: int = plan.size()
	var first_i: int = maxi(ceili((a - plan.lo) / plan.step - 0.0001), 0)
	var last_i: int = mini(floori((b - plan.lo) / plan.step + 0.0001), n - 1)
	if first_i > last_i:
		return false
	# What keeps each face clear of a wall: `fixed` counts what can't go, `by` the removable enemies.
	var fixed := PackedInt32Array()
	fixed.resize(n)
	fixed.fill(0)
	var by: Dictionary = {}
	var mark_fixed := func(span: Vector2, faces_direct: bool) -> void:
		if faces_direct:
			plan.mark_faces(fixed, span)
		else:
			plan.mark_span(fixed, span)
	var mark_enemy := func(e: Dictionary, span: Vector2, faces_direct: bool) -> void:
		var lo_f: float = span.x if faces_direct else span.x - plan.depth - plan.after
		var hi_f: float = span.y if faces_direct else span.y + plan.approach
		var i0: int = maxi(ceili((lo_f - plan.lo) / plan.step - 0.0001), first_i)
		var i1: int = mini(floori((hi_f - plan.lo) / plan.step + 0.0001), last_i)
		for i: int in range(i0, i1 + 1):
			if not by.has(i):
				by[i] = []
			if not (by[i] as Array).has(e):
				(by[i] as Array).append(e)
	var mt: MovementTuning = gen.tuning
	for s: Dictionary in lay.speed_pads:
		mark_fixed.call(Vector2(float(s["at"]), float(s["at"]) + mt.speed_pad_length), false)
	for pad: Dictionary in lay.pads:
		mark_fixed.call(gen.zones.pad_zone(float(pad["at"])), false)
	for r: Dictionary in lay.ramps:
		var at: float = float(r["at"])
		mark_fixed.call(Vector2(at, maxf(gen.ramp_launch(r).end(), at + mt.ramp_length)), false)
	for h: Dictionary in lay.hulls:
		mark_fixed.call(Vector2(float(h["start"]), gen.zones.landing_zone(h).y), false)
	for d: Dictionary in lay.doodads:
		if doodads_go:
			mark_enemy.call(d, doodad_span(gen, d), false)
		else:
			mark_fixed.call(doodad_span(gen, d), false)
	for zone: Vector2 in WideGapPlacement.keep_outs(gen):
		mark_fixed.call(zone, false)
	var planted: Array[Dictionary] = ChargePathPlacement.planted_in(lay)
	var chargers: Array[Dictionary] = []
	for c: Dictionary in planted:
		mark_fixed.call(ChargePathPlacement.encounter_span(gen, c), false)
		chargers.append(ChargePathPlacement.charger_of(lay, c))
	var enforcer_baits: Array[float] = _enforcer_baits(lay)
	for k: Dictionary in gen.rules_doodad_keep_outs():
		if _counts(k):
			mark_fixed.call(Vector2(float(k["from"]), float(k["to"])), false)
	var removable: Array[Dictionary] = []
	var hooks: Dictionary = {}
	for e: Dictionary in lay.enemies:
		var type: String = String(e.get("type", ""))
		# Never a host (its chase is planned on it), a cyborg planted in a charge's path or its charger (task G7: the
		# encounter goes whole or not at all, and it keeps its own count), nor a Buzz Overdrive an Enforcer Truck
		# counts among its baits (GDD §9.13: each truck has one, EnforcerTruckRules).
		var mine: bool = MAKE_ROOM_TYPES.has(type) and not bool((e.get("params", {}) as Dictionary).get("host", false)) \
			and not planted.has(e) and not chargers.has(e) and not _is_enforcer_bait(gen, e, enforcer_baits)
		if mine:
			removable.append(e)
		for span: Vector2 in enemy_spans(gen, e, hooks):
			if mine:
				mark_enemy.call(e, span, false)
			else:
				mark_fixed.call(span, false)
	# Cuts go with their Buzz Overdrive; any other's stays.
	for c: Dictionary in lay.cuts:
		var owner: Dictionary = {}
		for e: Dictionary in removable:
			if String(e.get("type", "")) == BUZZ and is_same(BuzzRules.cut_of(lay, e), c):
				owner = e
				break
		if owner.is_empty():
			mark_fixed.call(FloorCutPlan.window(c, gen.speed), false)
		else:
			mark_enemy.call(owner, FloorCutPlan.window(c, gen.speed), false)
	# Fences: a pulsing one stays; one a generator powers goes with its generators' power (plain, it's cleared).
	var half: float = mt.fence_depth * 0.5
	var geo := TrackGeometry.new(lay.lane_count, mt)
	var gt: FenceGeneratorTuning = GeneratorRules.tuning()
	for f: Dictionary in lay.fences:
		var span := Vector2(float(f["at"]) - half, float(f["at"]) + half)
		if bool(f.get("pulsing", false)):
			mark_fixed.call(span, false)
	for e: Dictionary in removable:
		if String(e.get("type", "")) == GENERATOR:
			for f: Dictionary in FenceGenerator.fences_in_reach(lay, geo, float(e["at"]), int(e["lane"]), gt.emp_radius):
				if not bool(f.get("pulsing", false)):
					mark_enemy.call(e, Vector2(float(f["at"]) - half, float(f["at"]) + half), false)
	# The baits' spacing: a removable enemy's goes with it, any other's stays.
	if plan.t.keep_dash_baits:
		for e: Dictionary in lay.enemies:
			var bait: float = bait_of(gen, e)
			if is_nan(bait):
				continue
			if removable.has(e):
				mark_enemy.call(e, Vector2(bait, bait + plan.spacing), true)
			else:
				mark_fixed.call(Vector2(bait, bait + plan.spacing), true)
	# The faces only removable enemies keep, fewest first, then earliest.
	var candidates: Array[int] = []
	for i: int in range(first_i, last_i + 1):
		if fixed[i] == 0 and by.has(i):
			candidates.append(i)
	candidates.sort_custom(func(x: int, y: int) -> bool:
		var nx: int = (by[x] as Array).size()
		var ny: int = (by[y] as Array).size()
		return nx < ny or (nx == ny and x < y))
	var before: Dictionary = _feature_firsts(gen)
	for i: int in candidates:
		var going: Array = by[i]
		if _take_out(gen, going, before):
			return true
	return false


## Each of the level's features' positions' first (LevelGenerator.feature_positions), or INF for one with none.
static func _feature_firsts(gen: LevelGenerator) -> Dictionary:
	var out: Dictionary = {}
	for f: String in gen.config.features:
		if f == FEATURE:
			continue
		var at: Array[float] = LevelGenerator.feature_positions(gen.layout, f)
		out[f] = at[0] if not at.is_empty() else INF
	return out


## Takes enemies `going` out of the layout (a Buzz Overdrive with its floor cut; zone doodads among them go from
## the doodads, _make_room's `doodads_go`), unless that leaves a feature with nothing or moves its first (`before`:
## _feature_firsts), which keeps every feature and introduction where it was; then nothing goes. True if they went.
static func _take_out(gen: LevelGenerator, going: Array, before: Dictionary) -> bool:
	var lay: LevelLayout = gen.layout
	var enemies: Array[Dictionary] = lay.enemies.duplicate()
	var cuts: Array[Dictionary] = lay.cuts.duplicate()
	var doodads: Array[Dictionary] = lay.doodads.duplicate()
	for e: Dictionary in going:
		if lay.doodads.has(e):
			lay.doodads.erase(e)
			continue
		if String(e.get("type", "")) == BUZZ:
			var cut: Dictionary = BuzzRules.cut_of(lay, e)
			if not cut.is_empty():
				lay.cuts.erase(cut)
		lay.enemies.erase(e)
	var after: Dictionary = _feature_firsts(gen)
	for f: String in before:
		var was: float = float(before[f])
		var now: float = float(after.get(f, INF))
		if not is_equal_approx(now, was) and not (is_inf(was) and is_inf(now)):
			lay.enemies.assign(enemies)
			lay.cuts.assign(cuts)
			lay.doodads.assign(doodads)
			return false
	return true


## True if rules keep-out `k` (LevelGenerator.rules_doodad_keep_outs) keeps the walls off: one of every lane
## (a Bad Dream's chase, a Gilded Sentinel's turn, an Enforcer Truck's showing window: a calm stretch, task C6c),
## never the walls' own, and never one of a single lane (the hover truck's: the truck bursts through a wall in its
## way, see the header).
static func _counts(k: Dictionary) -> bool:
	return String(k.get("type", "")) != FEATURE and not k.has("lane")


## Where the level's Enforcer Trucks' baits charge (their params' "baits": EnforcerTruckRules.baits_in).
static func _enforcer_baits(lay: LevelLayout) -> Array[float]:
	var out: Array[float] = []
	for e: Dictionary in lay.enemies:
		if String(e.get("type", "")) == ENFORCER:
			for b: Variant in (e.get("params", {}) as Dictionary).get("baits", []):
				out.append(float(b))
	return out


## True if enemy entry `e` is a Buzz Overdrive whose charge an Enforcer Truck counts among its baits (`baits`:
## _enforcer_baits; EnforcerTruckRules.bait_points puts a tank's at its cut's charge_at).
static func _is_enforcer_bait(gen: LevelGenerator, e: Dictionary, baits: Array[float]) -> bool:
	if baits.is_empty() or String(e.get("type", "")) != BUZZ:
		return false
	var cut: Dictionary = BuzzRules.cut_of(gen.layout, e)
	if cut.is_empty():
		return false
	var at: float = FloorCutPlan.charge_at(cut)
	for b: float in baits:
		if absf(b - at) < 0.01:
			return true
	return false


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
		var at: float = float(e["at"])
		out.append(Vector2(at - TITHE_LEAD, at + tithe_stay_seconds() * gen.speed))
	return out


## What zone doodad `d` keeps a wall's footprint off, placed after it (the second stage), as a doodad placed after a
## wall keeps them from its footprint (LevelGenerator._place_doodads): its push's lead before it
## (LevelGenerator.doodad_lead_for), so its push never comes in a wall's clear stretch, and the level's spacing
## past it (doodad_after), so a runner who dashes through it has time to see what it hid (task H5).
static func doodad_span(gen: LevelGenerator, d: Dictionary) -> Vector2:
	var end: float = float(d["end"])
	return Vector2(float(d["start"]) - LevelGenerator.doodad_lead_for(gen.tuning), end + gen.doodad_after(end))


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
## fence generator, and the end of each Tithe Collector's stay (a zone doodad never needs the dash: see the header).
static func bait_points(gen: LevelGenerator) -> Array[float]:
	var out: Array[float] = []
	for e: Dictionary in gen.layout.enemies:
		var b: float = bait_of(gen, e)
		if not is_nan(b):
			out.append(b)
	return out


## Where enemy entry `e` invites the dash (bait_points), or NAN if it doesn't: a Buzz Overdrive's charge where it
## meets the runner (a panic dash smashes it, GDD §9.9), a fence generator's spot (its hint says to dash through
## it), and a Tithe Collector's at the end of its stay (its hint says to catch it by stomping, shooting or dashing
## through it, GDD §9.12: the last moment of its stay is the latest a dash can catch it; as enemy_spans keeps it).
static func bait_of(gen: LevelGenerator, e: Dictionary) -> float:
	match String(e.get("type", "")):
		BUZZ:
			var cut: Dictionary = BuzzRules.cut_of(gen.layout, e)
			if not cut.is_empty():
				return FloorCutPlan.meet(cut, gen.speed)
		GENERATOR:
			return float(e["at"])
		TITHE:
			return float(e["at"]) + tithe_stay_seconds() * gen.speed
	return NAN


## A Tithe Collector's stay (TitheCollectorTuning.stay_seconds; 12 s without its tuning).
static func tithe_stay_seconds() -> float:
	var tt := EnemyDirector.tuning_for(TITHE) as TitheCollectorTuning
	return tt.stay_seconds() if tt != null else 12.0


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


## What the passes after a wall keep off (LevelGenerator.rules_doodad_keep_outs: the zone doodads and the wall
## fences' drop windows after the second stage; the danger density pass, the wider gaps and the cyborgs planted
## in charge paths after an introduction): every wall's footprint (footprint()), in every lane.
static func doodad_keep_outs(gen: LevelGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if gen.layout.dash_walls.is_empty():
		return out
	var t: DashWallTuning = tuning()
	for w: Dictionary in gen.layout.dash_walls:
		var fp: Vector2 = footprint(gen, w, t)
		out.append({"from": fp.x, "to": fp.y, "type": FEATURE})
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
		for b: float in bait_points(gen):
			if face >= b and face <= b + plan.spacing:
				found.append("a dash bait at %.1f m" % b)
	var i: int = clampi(roundi((face - plan.lo) / plan.step), 0, maxi(plan.size() - 1, 0))
	if plan.signs_left[i] > 0 and plan.signs_right[i] > 0:
		found.append("no side wall open to run past it")
	if found.is_empty():
		found.append("something it keeps off is there (a pad, ramp, speed pad or floor cut)")
	return ", ".join(found)
