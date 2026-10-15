class_name CeilingScenarios
extends RefCounted
## The ceiling scenarios (task I4; GDD §3, "Ceiling scenarios", owner, October 14, 2026: never in zones 1-2,
## sprinkled into later zones), shared by their generator rules, the checks and the tests:
## - Pick the right pad (the `fenced_ceiling` feature, fenced_ceiling_rules.gd): a ceiling carries electric fences
##   (GDD §9.1) that hit a player who takes its first anti-grav pad; a later pad lands its rider past them.
## - The treasure stash (the `treasure_stash` feature, treasure_stash_rules.gd): a return pad partway along a
##   ceiling drops its rider into a stretch of floor walled off by zone doodads, the only way in, where two or
##   three of the highest-denomination credits lie.
## Both take one of the level's own ceilings (candidates()) once every other rule has placed its ceilings and pads
## (their RUN_AFTER), so the drone's pad schedule, a Bad Dream chase's pads and every other rule's plan stand as
## they were; a scenario adds pads only where no drone wave is about (drone_windows), keeps off what every other
## rule keeps (busy_spans), runs the ceiling on where it needs more of it (can_extend) and clears only the plain
## holes and fences in its way (clear_floor), as a ceiling a rule adds does (PadPlacement). The ceiling it takes is
## marked with its feature (KEY), so no Barnacle Turret hangs from it (one new thing at a time) and no other
## scenario takes it.
## The physics it times them by is the Player's (rise_seconds, drop_seconds, jump_low_seconds), at the level's run
## speed; test_ceiling_scenarios replays them on real physics. Numbers: CeilingScenarioTuning
## (data/tuning/ceiling_scenarios.tres). DESIGN-TBD throughout (docs/questions/i4.md).

const STASH: String = "treasure_stash"
const FENCED: String = "fenced_ceiling"
## A ceiling a scenario took (LevelLayout.hulls) carries the scenario's feature under this key.
const KEY: String = "scenario"
const TUNING_PATH: String = "res://data/tuning/ceiling_scenarios.tres"
const DashWallRules = preload("res://scripts/enemies/dash_wall_rules.gd")
const GeneratorRules = preload("res://scripts/enemies/generator_rules.gd")


static func tuning() -> CeilingScenarioTuning:
	var res: Resource = load(TUNING_PATH) if ResourceLoader.exists(TUNING_PATH) else null
	return res as CeilingScenarioTuning if res is CeilingScenarioTuning else CeilingScenarioTuning.new()


# --- The Player's physics ---------------------------------------------------------------------------

## One physics frame (seconds): a pad flips the runner on the frame its trigger meets their feet's sensor,
## and the rise or the fall starts the frame after.
static func frame_seconds() -> float:
	return 1.0 / float(maxi(Engine.physics_ticks_per_second, 1))


## The track distance where a pad (or a return pad) starting at `at` flips a runner at the earliest: as the front
## of their feet's sensor (Player.SENSOR_SIZE) reaches it.
static func flip_early(at: float) -> float:
	return at - Player.SENSOR_SIZE.z * 0.5


## The same at the latest, for a runner at `speed`: a frame's run later (the sensor is swept back over a frame's
## motion), and a frame more before the rise or the fall starts.
static func flip_late(at: float, speed: float) -> float:
	return flip_early(at) + 2.0 * speed * frame_seconds()


## Seconds from an anti-grav pad's flip until the rider's feet are within `depth` of the ceiling's underside
## (0: until they land on it, CeilingZones.lift_seconds): they leave at antigrav_launch_velocity and fall toward
## the underside at the descending gravity (Player._flip, _update_vertical).
static func rise_seconds(t: MovementTuning, depth: float) -> float:
	var v0: float = t.antigrav_launch_velocity
	var a: float = maxf(t.gravity() * t.fall_gravity_multiplier, 0.01)
	var dist: float = maxf(t.ceiling_height - maxf(depth, 0.0), 0.0)
	return (-v0 + sqrt(v0 * v0 + 2.0 * a * dist)) / a


## Seconds from a drop off a ceiling (a return pad's, or past its end) until the falling runner's feet are
## `height` above the floor: from rest at the underside, at the descending gravity (a hair sooner than the
## Player's first frame, which falls at the plain one: what passes over something by this passes over it).
static func drop_seconds(t: MovementTuning, height: float) -> float:
	var a: float = maxf(t.gravity() * t.fall_gravity_multiplier, 0.01)
	return sqrt(2.0 * maxf(t.ceiling_height - height, 0.0) / a)


## A jump's time in the air, from the surface jumped from back to it (on the ceiling as on the floor).
static func jump_seconds(t: MovementTuning) -> float:
	var g: float = t.gravity()
	return t.jump_velocity() / g + sqrt(2.0 * t.jump_height / (g * t.fall_gravity_multiplier))


## Seconds of a jump during which the feet are within `depth` of the surface jumped from: rising through it at
## the start and coming back down through it at the end. A whole jump if it never gets that far.
static func jump_low_seconds(t: MovementTuning, depth: float) -> float:
	if depth >= t.jump_height:
		return jump_seconds(t)
	var v: float = t.jump_velocity()
	var g: float = t.gravity()
	var g_down: float = g * t.fall_gravity_multiplier
	var rising: float = (v - sqrt(maxf(v * v - 2.0 * g * depth, 0.0))) / g
	var falling: float = sqrt(2.0 * t.jump_height / g_down) - sqrt(2.0 * (t.jump_height - depth) / g_down)
	return rising + falling


## The rows of fences a fenced ceiling hangs past its unsafe pads' arrival (GDD §3: they "hit a player who takes
## the first anti-grav pad"): {spacing, count, extent} (metres). A rider on the underside is in a row's reach
## (MovementTuning.ceiling_fence_depth below it), and one jumping clears a row only while their feet are further
## from the underside than that: near it for jump_low_seconds of every jump. Rows spaced by no more than the
## ground a rider covers that near the underside at the run speed `v_min`, plus a row's depth and a body's (the
## reach of a contact), can't all fall in one jump's high stretch; over more than a whole jump at `v_max` (the run
## speed and a boost), no rhythm of jumps clears them all. And they cross every lane, so switching lanes doesn't
## help. `margin` (metres) comes off the spacing for the physics' frame steps.
static func row_plan(t: MovementTuning, v_min: float, v_max: float, margin: float) -> Dictionary:
	var contact: float = t.fence_depth + t.hurtbox_size.z
	var spacing: float = maxf(jump_low_seconds(t, t.ceiling_fence_depth) * v_min + contact - margin, 0.5)
	var extent: float = jump_seconds(t) * v_max + margin
	var count: int = ceili(extent / spacing) + 1
	return {"spacing": spacing, "count": count, "extent": spacing * (count - 1)}


# --- Where a scenario may go -----------------------------------------------------------------------

## The stretches a scenario keeps off in every lane, as the level stands when its rules run (after every other
## rule's): every enemy's (what the fill pass keeps for it, LevelGenerator.enemy_keep_out: a cyborg's margin, a
## hover truck's window, a drone wave until its first pad, ...), every floor cut's window, every dash wall's
## footprint, what the rules keep in every lane (LevelGenerator.rules_doodad_keep_outs without a lane: a Bad
## Dream's chase, a Gilded Sentinel's strike, an Enforcer Truck's showing window, a treasure stash's floor;
## rules_fill_keep_outs) and a level's quiet stretches (GDD §5, The Hush).
static func busy_spans(gen: LevelGenerator) -> Array[Vector2]:
	var layout: LevelLayout = gen.layout
	var out: Array[Vector2] = []
	var hooks: Dictionary = {}
	for e: Dictionary in layout.enemies:
		var k: Vector2 = gen.enemy_keep_out(e, hooks)
		if k.y >= k.x:
			out.append(k)
	for c: Dictionary in layout.cuts:
		out.append(FloorCutPlan.window(c, gen.speed))
	for w: Dictionary in layout.dash_walls:
		out.append(DashWallRules.footprint(gen, w))
	for k: Dictionary in gen.rules_doodad_keep_outs():
		if not k.has("lane"):
			out.append(Vector2(float(k["from"]), float(k["to"])))
	out.append_array(gen.rules_fill_keep_outs())
	out.append_array(gen.quiet_stretches())
	return out


## The lanes other rules keep in stretches, {lane, from, to} (LevelGenerator.rules_doodad_keep_outs with a lane: a
## hover truck's for its stay): no pad a scenario adds lies in one.
static func lane_keeps(gen: LevelGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for k: Dictionary in gen.rules_doodad_keep_outs():
		if k.has("lane"):
			out.append(k)
	return out


## Where a scenario adds no pad: from `margin_seconds` of run before each drone wave arrives until its first pad
## (GDD §9.6: a pad hurls every drone on screen, and from a wave's arrival to its first pad no pad may come).
static func drone_windows(gen: LevelGenerator, margin_seconds: float) -> Array[Vector2]:
	var layout: LevelLayout = gen.layout
	var dt := EnemyDirector.tuning_for("drone") as DroneTuning
	var wait: float = (dt.first_pad_seconds if dt != null else 10.0) * gen.speed
	var out: Array[Vector2] = []
	for e: Dictionary in layout.enemies:
		if String(e.get("type", "")) != "drone":
			continue
		var at: float = float(e["at"])
		var first: float = at + wait
		for p: Dictionary in layout.pads:
			if float(p["at"]) > at + 0.01:
				first = minf(first, float(p["at"]))
		out.append(Vector2(at - margin_seconds * gen.speed, first))
	return out


## True if a span of `spans` reaches into [from, to].
static func hits(spans: Array[Vector2], from: float, to: float) -> bool:
	for s: Vector2 in spans:
		if s.x <= to and s.y >= from:
			return true
	return false


## True if one of `keeps` ({lane, from, to}) keeps `lane` anywhere in [from, to].
static func lane_kept(keeps: Array[Dictionary], lane: int, from: float, to: float) -> bool:
	for k: Dictionary in keeps:
		if int(k["lane"]) == lane and float(k["from"]) <= to and float(k["to"]) >= from:
			return true
	return false


## The level's ceilings a scenario may take, in track order: none another scenario took, none with a Barnacle
## Turret hanging from it (one new thing at a time), at least `min_width` lanes wide, with a pad under it.
static func candidates(gen: LevelGenerator, min_width: int) -> Array[Dictionary]:
	var layout: LevelLayout = gen.layout
	var out: Array[Dictionary] = []
	for h: Dictionary in layout.hulls:
		if h.has(KEY) or layout.hull_width(h) < min_width or pads_under(layout, h).is_empty() or turret_on(layout, h):
			continue
		out.append(h)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["start"]) < float(b["start"]))
	return out


## The anti-grav pads under ceiling `h` (between its start and its end), in track order.
static func pads_under(layout: LevelLayout, h: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Dictionary in layout.pads:
		if float(p["at"]) >= float(h["start"]) and float(p["at"]) <= float(h["end"]):
			out.append(p)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["at"]) < float(b["at"]))
	return out


## True if a Barnacle Turret hangs from ceiling `h` (its params name the ceiling's start).
static func turret_on(layout: LevelLayout, h: Dictionary) -> bool:
	for e: Dictionary in layout.enemies:
		if String(e.get("type", "")) == "barnacle_turret" \
				and absf(float((e.get("params", {}) as Dictionary).get("hull_start", -INF)) - float(h["start"])) < 0.01:
			return true
	return false


## The ceiling scenario ceiling `h` belongs to (STASH, FENCED), or "" for an ordinary ceiling.
static func scenario_of(h: Dictionary) -> String:
	return String(h.get(KEY, ""))


## Every scenario's stretch in `gen`'s level: each ceiling a scenario took, from its start to its landing zone's
## end (a scenario keeps min_gap_seconds from another's).
static func taken_spans(gen: LevelGenerator) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for h: Dictionary in gen.layout.hulls:
		if h.has(KEY):
			out.append(Vector2(float(h["start"]), gen.zones.landing_zone(h).y))
	return out


## Which of `plans` (each {span: Vector2(from, to)}, in track order) a level takes, up to `count`: in a level that
## gives `feature` a start (LevelConfig.feature_starts), the first from its start (its introduction, right after its
## hint); then seeded picks (`rng`) among the rest, each at least min_gap_seconds of run from every other scenario
## (`taken`, the level's already) and from each other. In track order.
static func choose(gen: LevelGenerator, feature: String, plans: Array[Dictionary], count: int, rng: RandomNumberGenerator,
		taken: Array[Vector2]) -> Array[Dictionary]:
	var gap: float = tuning().min_gap_seconds * gen.speed
	var spans: Array[Vector2] = taken.duplicate()
	var pool: Array[Dictionary] = plans.duplicate()
	var out: Array[Dictionary] = []
	if count <= 0:
		return out
	if gen.config.feature_starts.has(feature):
		for i: int in pool.size():
			if _apart(spans, pool[i]["span"], gap):
				out.append(pool[i])
				spans.append(pool[i]["span"])
				pool.remove_at(i)
				break
	for i: int in range(pool.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Dictionary = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	for p: Dictionary in pool:
		if out.size() >= count:
			break
		if _apart(spans, p["span"], gap):
			out.append(p)
			spans.append(p["span"])
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a["span"] as Vector2).x < (b["span"] as Vector2).x)
	return out


## True if `span` keeps `gap` from every one of `spans`.
static func _apart(spans: Array[Vector2], span: Vector2, gap: float) -> bool:
	for s: Vector2 in spans:
		if span.x < s.y + gap and span.y > s.x - gap:
			return false
	return true


## True if ceiling `h` may run on to `end` (later than its own end): its new landing zone ends before the level's
## end-clear stretch, holds no floor cut's lane window and no floor enemy (CeilingZones: its holes and fences are
## cleared when it's run on, extend()), lies off `busy`, and the ceiling touches no other one, nor reaches with its
## landing zone the next.
static func can_extend(gen: LevelGenerator, h: Dictionary, end: float, busy: Array[Vector2]) -> bool:
	var layout: LevelLayout = gen.layout
	var zone := Vector2(end, end + gen.zones.landing)
	if zone.y > layout.length - gen.config.end_clear_distance:
		return false
	if hits(busy, float(h["end"]), zone.y):
		return false
	for other: Dictionary in layout.hulls:
		if not is_same(other, h) and float(other["start"]) <= zone.y + 1.0 and float(other["end"]) >= float(h["start"]) - 1.0:
			return false
	var lanes: Vector2i = layout.hull_lanes(h)
	for c: Dictionary in layout.cuts:
		if CeilingZones.in_lanes(int(c["lane"]), lanes) and FloorCutPlan.lane_window_in(c, zone.x, zone.y):
			return false
	for e: Dictionary in layout.enemies:
		if gen.zones.enemy_in(e, zone):
			return false
	return true


## Runs ceiling `h` on to `end` (can_extend), taking out the holes and fences on its new landing zone over its
## lanes.
static func extend(gen: LevelGenerator, h: Dictionary, end: float) -> void:
	h["end"] = end
	clear_floor(gen, end, end + gen.zones.landing, gen.layout.hull_lanes(h))


## Takes out every hole and fence in `lanes` (Vector2i(first, last)) over [from, to]: plain pieces a scenario makes
## room for, as a ceiling a rule adds does for its pad and landing (PadPlacement), and a fence generator left
## powering nothing (GeneratorRules.keep_powered). Returns how many pieces went.
static func clear_floor(gen: LevelGenerator, from: float, to: float, lanes: Vector2i) -> int:
	var layout: LevelLayout = gen.layout
	var half: float = gen.tuning.fence_depth * 0.5
	var before: int = layout.gaps.size() + layout.fences.size()
	var gaps: Array[Dictionary] = []
	for g: Dictionary in layout.gaps:
		if not (CeilingZones.in_lanes(int(g["lane"]), lanes) and float(g["start"]) <= to and float(g["end"]) >= from):
			gaps.append(g)
	layout.gaps.assign(gaps)
	var fences: Array[Dictionary] = []
	for f: Dictionary in layout.fences:
		if not (CeilingZones.in_lanes(int(f["lane"]), lanes) and float(f["at"]) + half >= from and float(f["at"]) - half <= to):
			fences.append(f)
	layout.fences.assign(fences)
	var gone: int = before - layout.gaps.size() - layout.fences.size()
	if gone > 0:
		GeneratorRules.keep_powered(gen)
	return gone
