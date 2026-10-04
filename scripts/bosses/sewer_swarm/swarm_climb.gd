class_name SwarmClimb
extends RefCounted
## The Sewer Swarm's wall climb (GDD §10, phase 2: "The swarm also climbs the walls, taking them away as an
## escape route, but only temporarily, and the phase must stay engaging: one wall at a time for a few
## seconds, alternating sides, so one wall is always free"). SewerSwarm ticks it in phases 2 and 3.
##
## In turn: both walls free for climb_gap_seconds, then the swarm climbs one wall for climb_seconds (its crowd,
## climb_creatures screeches, a SwarmCrowd of kind CLIMB, rising up the wall over climb_rise_seconds from
## climb_behind behind the runner to climb_ahead ahead, streaming back past them, its claws heard:
## swarm_climb; then sinking back into the gutter), sides alternating, the first seeded. It never climbs the
## wall the runner is on or has just jumped off (it waits for them to get clear of it), nor one whose ramp is
## about to carry them up it, and never both: one wall is always free.
##
## The screeches on the wall are an enemy attack (owner's request, docs/USER_REQUESTS.md): wherever they're
## shown they have a hitbox (BOXES pooled hazards along the wall, wall_hit_depth deep and a little under the
## screeches' tops, following how far they've risen), so touching them hurts as any attack does (armor, the
## shield, grace and the dash as DamageRules has it), and a runner on that wall touching them is knocked off
## it (Player.repel_from_wall), protected or not. They keep their own colours: nothing here is painted red.
##
## Phase 3 (owner's request): before each of the Host's ramps (SewerSwarm.host_spots_between), route_climb_lead
## before it, the climb goes to that ramp's wall and stays up there, and route_open_lead before it the
## screeches part (`open`, at the rise's pace) over the ramp's whole way: from route_hole_before before the
## ramp to route_hole_after past where its wall run drops back, and on past a runner still on the wall there.
## The parting is drawn and hit alike (a hole in the crowd, SwarmCrowd.set_climb_hole, and in the hitboxes,
## FEATHER metres of its edges thinned). Once the runner is past it (or ran by the ramp), it closes again;
## the rest of the wall stays covered. A hole can be longer than the climb's usual reach (a wall run at 21.8
## m/s), so in phase 3 it reaches `ahead` = route_reach() instead of climb_ahead, drawing more of its pooled
## creatures (made for the longer reach, before the fight) to keep its density: route_cover_ahead of live
## screeches always stand on that wall ahead of the runner, before the hole or past it.

enum State { GAP, CLIMB }

## Metres over which a route's hole thins back to full cover at its ends (the shader's feather).
const FEATHER: float = 1.0
## Hitboxes along the wall: the whole cover in one, or with a hole in it the cover either side of the hole,
## its two thinned edges and the hole itself.
const BOXES: int = 5
## Below this rise (in a hole, what's left of it) the screeches are only beginning to show: no hitbox.
const MIN_RISE: float = 0.12
## The hitboxes start this far in from the ends of the crowd (metres), whose screeches wrap around there.
const END_INSET: float = 0.5
## The hitboxes' foot and how far under the screeches' tops they stop (metres).
const BOX_BOTTOM: float = 0.15
const BOX_TOP_INSET: float = 0.1
## It won't start climbing a wall with a ramp onto it this many seconds ahead of the runner, nor while the
## runner is within NEAR_WALL metres of the wall across (just off it).
const RAMP_NOTICE: float = 0.8
const NEAR_WALL: float = 1.2
## Where a hitbox goes while it's off (out of every query's way).
const PARKED := Vector3(0.0, -50.0, 0.0)

var boss: SewerSwarm
var crowd: SwarmCrowd
var state: State = State.GAP
## The wall it climbs next (or climbs now): -1 left, +1 right.
var side: int = -1
## Seconds in the current state, and how far the climb has risen (0-1).
var t: float = 0.0
var rise: float = 0.0
## Climbs so far, routes opened (phase 3), and runners knocked off the wall.
var count: int = 0
var routes: int = 0
var repels: int = 0
## The host spot whose route it keeps ({} none): {at, side, drop, key, taken}; the hole's stretch (track
## distances, from and to) and how far it has parted (0-1). The hole stays while it closes.
var route: Dictionary = {}
var hole := Vector2.ZERO
var open: float = 0.0
## Its hitboxes (pooled; off ones parked).
var boxes: Array[Hazard] = []
## How far ahead of the runner it reaches now (metres): climb_ahead, or route_reach() in phase 3.
var ahead: float = 0.0

var _root: Node3D
var _routed: Dictionary = {}


func _init(p_boss: SewerSwarm, p_crowd: SwarmCrowd) -> void:
	boss = p_boss
	crowd = p_crowd
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([String(boss.def.id), "climb"])
	side = -1 if rng.randi_range(0, 1) == 0 else 1
	ahead = boss.tuning.climb_ahead
	_root = Node3D.new()
	_root.name = "ClimbHits"
	_root.top_level = true
	boss.add_child(_root)
	for i: int in BOXES:
		boxes.append(_make_box())
	_send()


## The creatures its crowd needs for the longest reach of the fight (its pool, made before the fight), as
## dense as `base` over climb_ahead.
static func pool_size(base: int, tuning: SewerSwarmTuning, longest: float) -> int:
	var usual: float = tuning.climb_ahead + tuning.climb_behind
	return ceili(base * (maxf(longest, tuning.climb_ahead) + tuning.climb_behind) / maxf(usual, 1.0))


## Phase 3's reach ahead (metres) for holes up to `longest_hole` long at pace `k`: past the whole hole, its
## thinned edges and the hitboxes' inset, route_cover_ahead more; never less than climb_ahead.
static func route_reach(tuning: SewerSwarmTuning, longest_hole: float, k: float) -> float:
	if longest_hole <= 0.0:
		return tuning.climb_ahead
	return maxf(tuning.climb_ahead, longest_hole + 2.0 * FEATHER + END_INSET + tuning.route_cover_ahead * k)


## Sets how far ahead it reaches (while it's down: a phase's start) and draws as many of its creatures as
## keep its density (`base` over climb_ahead).
func set_reach(p_ahead: float, base: int) -> void:
	var tuning: SewerSwarmTuning = boss.tuning
	ahead = p_ahead
	if crowd == null:
		return
	var n: int = mini(ceili(base * (ahead + tuning.climb_behind) / maxf(tuning.climb_ahead + tuning.climb_behind, 1.0)),
		crowd.count)
	crowd.multimesh.visible_instance_count = n if n < crowd.count else -1



## The wall its screeches cover now (they hurt there): -1 left, +1 right, 0 none.
func blocked_side() -> int:
	for box: Hazard in boxes:
		if box.is_active():
			return side
	return 0


## True if a hitbox of its covers wall `wall_side` at track distance `d`.
func covered_at(wall_side: int, d: float) -> bool:
	if wall_side != side:
		return false
	for box: Hazard in boxes:
		if box.is_active() and absf(-box.global_position.z - d) <= box.size.z * 0.5:
			return true
	return false


## Its live hitboxes' boxes in world space.
func hit_boxes() -> Array[AABB]:
	var out: Array[AABB] = []
	for box: Hazard in boxes:
		if box.is_active():
			out.append(AABB(box.global_position - box.size * 0.5, box.size))
	return out


## The top (world y) of the screeches where the climb has risen `r` (0-1): the highest still shown (the
## shader's kind 3).
func top_at(r: float) -> float:
	return 0.12 + minf(1.04 * r, 1.0) * boss.tuning.climb_height * (0.25 + 0.75 * r)


## Steps the climb on by one physics frame (phases 2 and 3).
func tick(delta: float) -> void:
	var tuning: SewerSwarmTuning = boss.tuning
	var pace: float = delta / maxf(tuning.climb_rise_seconds, 0.05)
	t += delta
	_update_route()
	var routed_side: int = int(route.get("side", 0))
	match state:
		State.GAP:
			rise = move_toward(rise, 0.0, pace)
			if rise <= 0.0:
				if routed_side != 0:
					side = routed_side
				var due: float = 0.0 if routed_side != 0 else tuning.climb_gap_seconds
				if t >= due and _can_start(side):
					_start()
		State.CLIMB:
			var sink_at: float = tuning.climb_seconds - tuning.climb_rise_seconds
			# Held up on a route's wall, and once it's over up a little longer while its hole closes.
			if routed_side == side:
				t = minf(t, maxf(sink_at - tuning.climb_rise_seconds, 0.0))
			if routed_side == -side:
				rise = move_toward(rise, 0.0, pace)
				if rise <= 0.0:
					_finish()
			else:
				rise = move_toward(rise, 1.0 if t < sink_at else 0.0, pace)
				if t >= tuning.climb_seconds:
					_finish()
	var opening: bool = not route.is_empty() and boss.player_distance() >= float(route["at"]) \
		- tuning.route_open_lead * boss.run_pace()
	open = move_toward(open, 1.0 if opening else 0.0, pace)
	if route.is_empty() and open <= 0.0:
		hole = Vector2.ZERO
	_send()
	_repel_touching()


## Ends the climb at once (a phase change, the win): the wall comes back and the swarm drops away.
func clear() -> void:
	if state == State.CLIMB:
		_finish()
	rise = 0.0
	open = 0.0
	route = {}
	hole = Vector2.ZERO
	_send()


func _can_start(wall_side: int) -> bool:
	var p: Player = boss.world.player
	if p.surface == Player.Surface.WALL and p.wall_side == wall_side:
		return false
	if wall_side * p.position.x > boss.world.geo.wall_x() - NEAR_WALL:
		return false
	return not _ramp_due(wall_side)


## True if a ramp onto wall `wall_side` (other than the route's) is about to carry the runner up it.
func _ramp_due(wall_side: int) -> bool:
	if boss.arena == null:
		return false
	var d: float = boss.player_distance()
	var reach: float = d + (boss.run_speed() + boss.world.tuning.ramp_speed_boost) * RAMP_NOTICE
	for r: Dictionary in boss.arena.layout.ramps:
		var at: float = float(r["at"])
		if int(r["side"]) == wall_side and at >= d - 2.0 and at <= reach \
				and not (not route.is_empty() and is_equal_approx(at, float(route["at"]))):
			return true
	return false


func _start() -> void:
	var d: float = boss.player_distance()
	state = State.CLIMB
	t = 0.0
	count += 1
	boss.sound(&"swarm_climb", Vector3(side * (boss.world.geo.wall_x() - 0.3), 2.0, TrackGeometry.world_z(d + 12.0)))
	boss.log_event(&"climb", {"side": side, "d": snappedf(d, 0.01)})


func _finish() -> void:
	boss.log_event(&"climb_end", {"side": side})
	state = State.GAP
	t = 0.0
	side = -side


## Phase 3: the next ramp's route (the climb goes to its wall, then parts over it), kept until the runner is
## past it or ran by the ramp.
func _update_route() -> void:
	if boss.phase_index < SewerSwarm.HOST_PHASE:
		return
	var tuning: SewerSwarmTuning = boss.tuning
	var k: float = boss.run_pace()
	var d: float = boss.player_distance()
	var p: Player = boss.world.player
	if route.is_empty():
		if open > 0.0:
			return
		for h: Dictionary in boss.host_spots_between(d, d + tuning.route_climb_lead * k):
			if _routed.has(h["key"]):
				continue
			_routed[h["key"]] = true
			route = {"at": float(h["at"]), "side": int(h["side"]), "drop": float(h["drop"]), "key": h["key"],
				"taken": false}
			hole = Vector2(float(h["at"]) - tuning.route_hole_before * k, float(h["drop"]) + tuning.route_hole_after * k)
			routes += 1
			boss.log_event(&"route", {"at": snappedf(float(h["at"]), 0.01), "side": int(h["side"]),
				"from": snappedf(hole.x, 0.01), "to": snappedf(hole.y, 0.01), "d": snappedf(d, 0.01)})
			break
		return
	var on_it: bool = p.surface == Player.Surface.WALL and p.wall_side == int(route["side"]) \
		and d >= hole.x and d <= hole.y
	if on_it:
		route["taken"] = true
		hole.y = maxf(hole.y, d + tuning.route_hole_after * k)
	var taken: bool = bool(route["taken"])
	if (taken and not on_it and d > hole.y) or (not taken and d > float(route["at"]) + 2.0 * k):
		boss.log_event(&"route_end", {"at": snappedf(float(route["at"]), 0.01), "taken": taken,
			"d": snappedf(d, 0.01)})
		route = {}


## The climb's cover along the wall, as stretches of track (from, to) and how far it has risen there:
## the whole of it, or the cover either side of a hole, the hole's thinned edges and the hole.
func segments() -> Array[Vector3]:
	var tuning: SewerSwarmTuning = boss.tuning
	var d: float = boss.player_distance()
	var lo: float = d - tuning.climb_behind + END_INSET
	var hi: float = d + ahead - END_INSET
	var r: float = SwarmCrowd._q(rise)
	var o: float = SwarmCrowd._q(open)
	var cuts: Array[Vector3] = []
	if o <= 0.0:
		cuts.append(Vector3(lo, hi, r))
	else:
		var f: float = FEATHER
		cuts.append(Vector3(lo, hole.x - f, r))
		cuts.append(Vector3(hole.x - f, hole.x - f * 0.5, r * (1.0 - 0.5 * o)))
		cuts.append(Vector3(hole.x - f * 0.5, hole.y + f * 0.5, r * (1.0 - o)))
		cuts.append(Vector3(hole.y + f * 0.5, hole.y + f, r * (1.0 - 0.5 * o)))
		cuts.append(Vector3(hole.y + f, hi, r))
	var out: Array[Vector3] = []
	for c: Vector3 in cuts:
		out.append(Vector3(maxf(c.x, lo), minf(c.y, hi), c.z))
	return out


func _send() -> void:
	if crowd == null:
		return
	var tuning: SewerSwarmTuning = boss.tuning
	var d: float = boss.player_distance()
	crowd.visible = rise > 0.0
	crowd.global_position = Vector3(0.0, 0.0, TrackGeometry.world_z(d))
	crowd.set_climb(side * boss.world.geo.wall_x(), side, ahead, tuning.climb_behind, tuning.climb_drift,
		tuning.climb_height, rise)
	crowd.set_climb_hole(Vector4(d - hole.y, d - hole.x, open, FEATHER) if open > 0.0 else Vector4(0.0, 0.0, 0.0, FEATHER))
	_place_boxes()


func _place_boxes() -> void:
	var segs: Array[Vector3] = segments()
	var wall_x: float = boss.world.geo.wall_x()
	var depth: float = boss.tuning.wall_hit_depth
	for i: int in boxes.size():
		var box: Hazard = boxes[i]
		var seg := Vector3.ZERO
		if i < segs.size():
			seg = segs[i]
		var top: float = top_at(seg.z) - BOX_TOP_INSET
		if seg.y - seg.x < 0.2 or seg.z < MIN_RISE or top <= BOX_BOTTOM:
			if box.is_active():
				box.set_enabled(false)
			box.position = PARKED
			continue
		var size := Vector3(depth, top - BOX_BOTTOM, seg.y - seg.x)
		if not box.size.is_equal_approx(size):
			box.size = size
			((box.get_child(0) as CollisionShape3D).shape as BoxShape3D).size = size
		box.position = Vector3(side * (wall_x - depth * 0.5), (BOX_BOTTOM + top) * 0.5,
			TrackGeometry.world_z((seg.x + seg.y) * 0.5))
		if not box.is_active():
			box.set_enabled(true)


## A runner on the covered wall touching its screeches is hurt by them first (the touch resolved now, so being
## knocked off can't dodge it), then knocked off it, even one nothing can hurt now (grace, god mode, the
## dash): the wall is taken.
func _repel_touching() -> void:
	var p: Player = boss.world.player
	if not p.alive or p.surface != Player.Surface.WALL or p.wall_side != side:
		return
	var body: AABB = p.hurtbox_aabb()
	for box: Hazard in boxes:
		if box.is_active() and AABB(box.global_position - box.size * 0.5, box.size).intersects(body):
			p.receive_hit(box)
			_repel("climb")
			return


func _on_contact(_outcome: int) -> void:
	_repel("climb")


func _repel(what: String) -> void:
	if boss.repel_wall_runner(side, what):
		repels += 1


func _make_box() -> Hazard:
	var hazard := Hazard.new()
	hazard.hazard_name = "the Sewer Swarm"
	hazard.is_enemy_attack = true
	hazard.part = &"attack"
	hazard.size = Vector3.ONE
	hazard.collision_layer = TrackBuilder.LAYER_HAZARD
	hazard.collision_mask = 0
	hazard.monitoring = false
	hazard.position = PARKED
	_root.add_child(hazard)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3.ONE
	shape.shape = box
	hazard.add_child(shape)
	hazard.set_enabled(false)
	hazard.contacted.connect(_on_contact)
	return hazard
