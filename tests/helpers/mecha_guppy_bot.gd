class_name MechaGuppyBot
extends RefCounted
## A runner who climbs Mecha Guppy and Captain Cogs' climb (GDD §10; task E5e-b1) like a good player, for tests and
## the showcase. Call step() every physics frame. It presses only the player's named actions, and it reads which
## lanes lead up from what the climb shows, the hut and the roofs themselves (physics rays on their collision, never
## the plan): `reaction` seconds after settling on a hut, it follows each lane of the hut to its end and looks
## where a drop from there comes down; a lane leads up if the higher roof is under it there. Then it switches,
## one lane at a time at the lane-switch time, to the nearest lane that leads up (or, with `wrong`, to the nearest
## that doesn't, to show a wrong drop falls), and records how much time it had to spare (`min_slack`: from its last
## switch's press, when the lane is committed (Player._start_switch), to the lane's end, the plan's deadline). It's a
## slow player: it waits a frame past each switch's end before the next.
## With `worst_case` (the fairness suites), before each step's pads it first moves to the lane farthest from that
## step's lanes that lead up (the one place it uses the plan: to pick the worst case on purpose) and jumps right
## before the pads (with `dash_flip`, dashing as it jumps: the run's dash power-up), so it flips up as late as any
## runner can and reads as late as the plan allows. `wrong_at` limits `wrong` to one step; `wrong_far` drops in the
## lane farthest from the lanes that lead up; `dash_drop` dashes as its lane ends, so the dash carries the whole fall.
## Phase 3's top (E5e-c) has no huts: it just runs. Bombs are E5e-b2's (this bot doesn't dodge them yet).

var boss: MechaGuppy
## Seconds after settling on a hut before it reads the lanes that lead up.
var reaction: float = 0.2
## Drops in the nearest lane that doesn't lead up (and stays there) instead.
var wrong: bool = false
## Worst case: the farthest lane before each step's pads, and a jump right before them.
var worst_case: bool = false
## What it did: {t (fight time), action, why}.
var log: Array[Dictionary] = []
## Roofs it landed on higher than the one before.
var steps_climbed: int = 0
## The least time it had to spare, over every step it read: seconds between pressing its last switch (or reading,
## with none to make) and its lane's end on the hut (its step's deadline). INF before it reads one.
var min_slack: float = INF
## Lanes it read as leading up, step by step: {step, lanes: Array[int]}.
var reads: Array[Dictionary] = []
## Dashes with the late jump before the pads (worst_case).
var dash_flip: bool = false
## `wrong` only at this step (-1: every step).
var wrong_at: int = -1
## A wrong drop in the lane farthest from the lanes that lead up (else the nearest that doesn't).
var wrong_far: bool = false
## Dashes as a wrong lane ends.
var dash_drop: bool = false
## Dashes it started.
var dashes: int = 0

var _read_step: int = -1
var _settled_at: float = -1.0
var _target: int = -1
var _next_press: float = 0.0
var _prepared: int = -1
var _jumped: int = -1
var _measured: int = -1
var _floor: float = 0.0
var _drop_dashed: int = -1


func _init(p_boss: MechaGuppy) -> void:
	boss = p_boss


func step() -> void:
	var world: RunWorld = boss.world
	var p: Player = world.player
	if not p.alive or not p.running:
		return
	var now: float = p.elapsed
	if p.surface == Player.Surface.FLOOR and p.grounded:
		if p.floor_y > _floor + 0.5:
			steps_climbed += 1
			log.append({"t": boss.fight_time(), "action": &"landed", "why": "on the roof %.1f m up, lane %d" % [p.floor_y, p.lane]})
		_floor = p.floor_y
	var next: MechaGuppyClimb.Step = _next_step(p)
	if next == null or next.top:
		return
	if p.surface == Player.Surface.FLOOR:
		_settled_at = -1.0
		if worst_case:
			_prepare(p, next, now)
	elif p.surface == Player.Surface.CEILING:
		if p.grounded and _settled_at < 0.0:
			_settled_at = now
		if _settled_at >= 0.0 and _read_step != next.index and now - _settled_at >= reaction:
			_read(p, next, now)
		if dash_drop and _goes_wrong(next) and _drop_dashed != next.index and p.lane >= 0 and p.lane < next.ends.size() \
				and p.distance >= next.ends[p.lane] - p.speed * 0.05:
			_drop_dashed = next.index
			_dash("as its lane ends: the dash carries the whole fall")
	_walk(p, next, now)


## True if it drops wrong at step `next`.
func _goes_wrong(next: MechaGuppyClimb.Step) -> bool:
	return wrong and (wrong_at < 0 or wrong_at == next.index)


func _dash(why: String) -> void:
	var controller := boss.world.powerups as PowerupController
	if controller != null and controller.try_dash():
		dashes += 1
		log.append({"t": boss.fight_time(), "action": &"dash", "why": why})


## The step whose pads are ahead of a runner on the floor, or whose hut a rider is on.
func _next_step(p: Player) -> MechaGuppyClimb.Step:
	var climb: MechaGuppyClimb = boss.climb
	if p.surface == Player.Surface.CEILING:
		return climb.step_at(p.distance)
	for k: int in range(maxi(climb.step_index_at(p.distance), 0), climb.steps.size()):
		var s: MechaGuppyClimb.Step = climb.steps[k]
		if s.top or s.pad_end > p.distance:
			return s
	return null


## Worst case: into the lane farthest from the step's lanes that lead up while there's room on the roof, then a jump
## right before its pads.
func _prepare(p: Player, next: MechaGuppyClimb.Step, now: float) -> void:
	var lanes: int = boss.lane_count()
	# Only where the roof is full width: beside its lanes that reach back there's the gap (a fall).
	var roof: MechaGuppyClimb.Roof = boss.climb.roofs[next.index]
	if _prepared != next.index and p.distance > roof.full_from() + 1.0 and next.pad - p.distance > p.speed * 0.9:
		var far: int = 0 if next.switches_from(0) >= next.switches_from(lanes - 1) else lanes - 1
		_prepared = next.index
		_set_target(far, "the worst case: the lane farthest from the lanes that lead up", now)
	if _jumped != next.index and p.grounded and next.pad - p.distance > 0.0 \
			and next.pad - p.distance <= p.speed / Engine.physics_ticks_per_second * 1.5:
		_jumped = next.index
		p.press(&"jump")
		log.append({"t": boss.fight_time(), "action": &"jump", "why": "right before the pads (the latest flip)"})
		if dash_flip:
			_dash("with the jump: the longest jump before the flip")


## Reads the lanes that lead up from the hut and the roofs (read_up_lanes) and heads for the nearest (or, `wrong`,
## the nearest that doesn't).
func _read(p: Player, next: MechaGuppyClimb.Step, now: float) -> void:
	_read_step = next.index
	var up: Array[int] = read_up_lanes(boss.world, boss.climb, p)
	reads.append({"step": next.index, "lanes": up})
	var go_wrong: bool = _goes_wrong(next)
	var pick: int = -1
	for lane: int in boss.lane_count():
		var leads: bool = up.has(lane)
		if leads == go_wrong:
			continue
		var better: bool = pick < 0 or absi(lane - p.lane) < absi(pick - p.lane)
		if go_wrong and wrong_far and not up.is_empty():
			# The farthest from the lanes that lead up.
			better = pick < 0 or _gap(lane, up) > _gap(pick, up)
		if better:
			pick = lane
	if pick < 0:
		pick = p.lane
	_set_target(pick, "reads lanes %s leading up; %s" % [up, "drops in another" if go_wrong else "heads for the nearest"], now)
	_measured = -1


## How many lanes `lane` is from the nearest of `up`.
static func _gap(lane: int, up: Array[int]) -> int:
	var out: int = 1 << 20
	for u: int in up:
		out = mini(out, absi(lane - u))
	return out


## A switch a lane at a time toward the target, each a frame after the last has finished. On a hut, the time it had
## to spare is measured at its last switch's press (or at its reading, with none to make), when its lane is
## committed, to the lane's end (its step's deadline).
func _walk(p: Player, next: MechaGuppyClimb.Step, now: float) -> void:
	if _target < 0:
		return
	var on_hut: bool = p.surface == Player.Surface.CEILING and _read_step == next.index and _measured != next.index
	if p.lane == _target:
		if on_hut:
			_slack(p, next, 0.0)
		_target = -1
		return
	if now < _next_press:
		return
	var dir: int = signi(_target - p.lane)
	if on_hut and absi(_target - p.lane) == 1:
		_slack(p, next, 0.0)
	p.press(&"move_right" if dir > 0 else &"move_left")
	_next_press = now + boss.world.tuning.lane_switch_time + 1.0 / Engine.physics_ticks_per_second


## Records the time to spare at step `next`'s deadline for a rider in their lane `switching` seconds from now.
func _slack(p: Player, next: MechaGuppyClimb.Step, switching: float) -> void:
	_measured = next.index
	var slack: float = (next.deadline - p.distance) / maxf(p.speed, 0.001) - switching
	min_slack = minf(min_slack, slack)
	log.append({"t": boss.fight_time(), "action": &"in_lane", "why": "lane %d, %.2f s to spare" % [_target, slack]})


func _set_target(lane: int, why: String, now: float) -> void:
	_target = lane
	_next_press = minf(_next_press, now)
	log.append({"t": boss.fight_time(), "action": &"target", "why": "lane %d: %s" % [lane, why]})


## The lanes that lead up from the hut a rider `p` is on, as the hut and the roofs show them (physics rays on their
## collision): each lane of the hut followed to its end (the hull layer at the rider's ceiling height), and a drop
## from there followed down to the first roof top under it (the floor layer), checked where the drop really reaches
## that height (the climb's drop timing at the run's speed). A lane leads up if a roof higher than the floor the
## rider came from is under it there.
static func read_up_lanes(world: RunWorld, climb: MechaGuppyClimb, p: Player) -> Array[int]:
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.new()
	var hut_y: float = p.ceiling_y
	var floor_y: float = p.floor_y
	var out: Array[int] = []
	for lane: int in world.geo.lane_count:
		var x: float = world.geo.lane_x(lane)
		var end: float = p.distance
		ray.collision_mask = TrackBuilder.LAYER_HULL
		while end < p.distance + 200.0:
			ray.from = Vector3(x, hut_y - 0.6, -end)
			ray.to = Vector3(x, hut_y + 0.3, -end)
			if space.intersect_ray(ray).is_empty():
				break
			end += 0.25
		# Where the first roof under the drop lies, then whether the drop comes down onto it.
		ray.collision_mask = TrackBuilder.LAYER_FLOOR
		var top: float = NAN
		var probe: float = end
		while probe < end + climb.speed * 0.8:
			ray.from = Vector3(x, hut_y - 0.5, -probe)
			ray.to = Vector3(x, floor_y - 1.0, -probe)
			var hit: Dictionary = space.intersect_ray(ray)
			if not hit.is_empty() and (hit["position"] as Vector3).y > floor_y + 0.5:
				top = (hit["position"] as Vector3).y
				break
			probe += 0.5
		if is_nan(top):
			continue
		var reach: float = end + world.tuning.foot_half_depth + climb.drop_seconds(hut_y - top) * climb.speed
		ray.from = Vector3(x, top + 0.3, -reach)
		ray.to = Vector3(x, top - 0.3, -reach)
		if not space.intersect_ray(ray).is_empty():
			out.append(lane)
	return out
