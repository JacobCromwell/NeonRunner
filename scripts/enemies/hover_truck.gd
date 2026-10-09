extends Enemy
## The hover truck (GDD §9.3), a mini-boss that holds the outer lane on the side it enters from.
## - Entrance: from inside a building it bangs on the wall (truck_bang; the facade bulges, cracks
##   and sparks), then bursts through in fire and rubble (truck_burst). Only the burst hurts, and
##   only a player on that wall section (an attack hitbox on the wall for a moment).
## - Movement: it hovers with a subtle bob over trucks and gaps alike and paces the player: its
##   position is kept relative to theirs (`offset`, its centre in metres ahead of the player). It
##   paces ahead, lurches backward to behind the player, revs, lurches forward to alongside, and
##   drifts ahead again; after 20–30 s it falls behind and leaves.
## - Attack: while pacing ahead its rear cannon fires slow shells back at the player, each
##   telegraphed (truck_cannon_charge and a growing glow). Later levels add 1–2 window shooters
##   whose bolts follow the cannon in the same volley. A cyborg drives it, visible in the cab.
##   The forward lurch and a cannon shot are big attacks (GDD §9): they take turns with other types'
##   (is_major_attack_active; the rev and the charge wait for their turn, never the attack after
##   them).
## - Contact: its sides and rear are safe but solid: its lane blocker bumps lane switches back, and
##   it never backs or drifts into a player in its lane. The one deadly part looks deadly: the
##   glowing front spikes (a sleek nose in the city, a spiked plow with barbed wire for
##   scavengers) are live only during the forward lurch, which comes after its warning (the rev:
##   truck_rev, flashing spikes, glowing thrusters, a light thrown ahead) and only when a player in
##   its lane could still get out. The spikes' hitbox is narrower than the lane, so a player beside
##   it or on the wall next to it is never caught.
## - Dash walls (task H7a; GDD §9.14; DESIGN-TBD, docs/questions/h7a.md): it gives way to one. A standing
##   wall coming within the time it needs to drop behind the runner (_wall_ahead: HoverTruckTuning
##   .give_way_seconds, WALL_GIVE_WAY_MARGIN more) sends it into its lurch back from pacing or from alongside,
##   and it holds back, revving for no forward lurch, until the runner has broken the wall: the runner meets
##   every wall first, and the truck follows them through. Its cannon holds fire near one (_doodad_in_reach).
##   Where it can't drop back (the runner is in its lane behind it, ridden, leaving ahead) its nose bursts
##   through a standing wall it reaches, as it burst out of the building (_burst_dash_walls). The generator
##   keeps the walls off its entrance only (dash_wall_rules.gd, truck_entrance).
## - Kill: land on its roof (a moving floor surface; routes: a ramp onto the wall then a wall jump,
##   or get ahead of it during a backward lurch, run on the wall and jump on as it lurches forward)
##   and stomp the glowing red weak point on the lower cab roof. While ridden it eases back so the
##   rider moves toward the cab and drops onto the weak point. Weapons: 17 laser tier 1 shots, 5
##   missile tier 4 shots. Either way it spins out and explodes (truck_explode).
## Spawn params (tests and set pieces): {"skip_entrance": bool, "offset": m, "phase": "pace" |
## "hold_back" | "alongside", "guns": bool, "stay": s}. Numbers: data/enemies/hover_truck.tres
## (HoverTruckTuning). Generator rules: hover_truck_rules.gd.

const MeshBatch := preload("res://scripts/enemies/mesh_batch.gd")

enum State { HIDDEN, BANGING, EMERGE, PACE, LURCH_BACK, HOLD_BACK, REV, LURCH_FWD, ALONGSIDE, RIDDEN, LEAVING, WRECKED }

const SPIKES_NAME: String = "hover truck spikes"
const BURST_NAME: String = "hover truck bursting through the wall"
const CANNON_NAME: String = "hover truck cannon"
const BOLT_NAME: String = "hover truck gunner"
## Leaving play: this far behind or ahead of the player.
const RETIRE_BEHIND: float = 40.0
const RETIRE_AHEAD: float = 90.0
const HOT := Color(1.0, 0.42, 0.08)
const FLASH := Color(1.0, 0.9, 0.55)
const WEAK := Color(1.0, 0.08, 0.1)
const SAFE := Color(0.25, 0.85, 1.0)
const HOVER := Color(0.3, 0.6, 1.0)
const AMBER := Color(1.0, 0.6, 0.12)
const FACADE := Color(0.24, 0.2, 0.3)
## Its fireballs (RunEffects.fireball, radius in metres; GDD §11): where it blows up (a truck is about 7 m
## long), and where it bursts through the wall (a quick one, no smoke: the burst hazard is only for a moment).
const FIRE_EXPLODE_SIZE: float = 3.8
const FIRE_BURST_SIZE: float = 2.6
const FIRE_OFF_WALL: float = 2.2
## How long the wreck's node outlasts its explosion.
const BOOM_SECONDS: float = 0.45
## Task H7a (DESIGN-TBD): seconds of run past the time it needs to drop behind the runner at which a standing
## dash wall ahead makes it give way (_wall_ahead).
const WALL_GIVE_WAY_MARGIN: float = 0.6

## Models per zone variant and shape, built once.
static var _models: Dictionary = {}

var state: State = State.HIDDEN
var tune: HoverTruckTuning
## The wall it bursts from (-1 left, +1 right) and the outer lane it holds.
var side: int = 1
var lane: int = 0
var offset: float = 0.0
var offset_speed: float = 0.0
var shooters: int = 0
## What happened so far (tests and the debug HUD read these; times are level times, -1 = not yet).
var bangs: int = 0
## Dash walls it burst through (task H7a).
var walls_burst: int = 0
var first_bang_time: float = -1.0
var burst_time: float = -1.0
var leave_time: float = -1.0
var cannon_shots: int = 0
var forward_lurches: int = 0

var _at: float = 0.0
var _scaling: float = 0.0
var _state_time: float = 0.0
var _active_time: float = 0.0
var _stay: float = 25.0
var _pace_time: float = 3.5
var _pace_clock: float = 0.0
var _lane_x: float = 0.0
var _x: float = 0.0
var _x_from: float = 0.0
var _yaw: float = 0.0
var _target: float = 0.0
var _max_speed: float = 0.0
var _accel: float = 10.0
var _prev_speed: float = 0.0
var _pitch: float = 0.0
var _guns: bool = true
var _cannon_timer: float = 0.0
var _charge_left: float = -1.0
var _volley: Array[float] = []
var _next_bang: float = 0.0
var _burst_left: float = 0.0
var _bulge_push: float = 0.0
var _rear_prev: float = 0.0
var _tip_prev: float = 0.0
var _blocked_time: float = 0.0
var _leave_ahead: bool = false
var _ground_h: float = 0.0
var _bob_t: float = 0.0
var _wreck_spin: float = 0.0
var _smoke_left: float = 0.0
var _rubble: Array[MeshInstance3D] = []
var _rubble_v: Array[Vector3] = []
var _rubble_left: float = 0.0
## Seconds since it blew up, or -1 before: the wreck's node stays this long after its fireball goes off
## (RunEffects.fireball is pooled and not the truck's, so nothing of it is freed with the truck).
var _boom_t: float = -1.0

var _model: Node3D
var _spikes_mesh: MeshInstance3D
var _weak_mesh: MeshInstance3D
var _thrust: MeshInstance3D
var _brake: MeshInstance3D
var _cannon: Node3D
var _cannon_muzzle: Node3D
var _charge: MeshInstance3D
var _shooter_guns: Array[MeshInstance3D] = []
var _shooter_muzzles: Array[Node3D] = []
var _nose_light: OmniLight3D
var _roofs: Array[StaticBody3D] = []
var _blocker: Area3D
var _spikes: Hazard
var _weak: Hazard
var _wall_fx: Node3D
var _bulge: Node3D
var _bang_frame: MeshInstance3D
var _frame_flash: float = 0.0
var _cracks: Array[MeshInstance3D] = []
var _hole: Node3D
var _hole_fire: MeshInstance3D
var _burst_hazard: Hazard
var _mats: Dictionary = {}


func _build() -> void:
	tune = tuning_res as HoverTruckTuning if tuning_res is HoverTruckTuning else HoverTruckTuning.new()
	display_name = "hover truck"
	if not (tuning_res is EnemyTuning):
		max_health = tune.health_early
		score_value = tune.score_value
	var params: Dictionary = spawn.get("params", {})
	side = int(spawn.get("side", 0))
	if side == 0:
		side = 1 if rng.randf() < 0.5 else -1
	# It holds the outer lane on the side it burst from and never changes lanes (FB 91; both
	# roof routes of GDD §9.3 go through the wall beside it).
	lane = world.layout.outer_lane(side)
	_lane_x = world.geo.lane_x(lane)
	_at = float(spawn.get("at", 0.0))
	_scaling = world.config.enemy_scaling if world.config != null else 0.0
	_stay = float(params.get("stay", rng.randf_range(tune.stay_min_seconds, tune.stay_max_seconds)))
	_guns = bool(params.get("guns", true))
	shooters = tune.shooters_at(_scaling) if _guns else 0
	_bob_t = rng.randf() * TAU
	_mats = {
		"hot": GreyboxMaterials.glow(HOT, 3.2),
		"flash": GreyboxMaterials.glow(FLASH, 6.0),
		"flash_soft": GreyboxMaterials.glow(FLASH, 2.4),
		"brake_on": GreyboxMaterials.glow(AMBER, 5.0),
	}
	_build_body()
	_build_hitboxes()
	_build_wall_fx()
	# Inside the building until it bursts out.
	_x = side * (world.geo.wall_x() + tune.width * 0.5 + 0.4)
	_set_solid(false)
	immune_to_weapons = true
	_model.visible = false
	position = Vector3(_x, 0.0, TrackGeometry.world_z(_at))
	if bool(params.get("skip_entrance", false)):
		_bulge.visible = false
		_emerged(float(params.get("offset", tune.pace_offset)))
		match String(params.get("phase", "pace")):
			"hold_back":
				_enter(State.HOLD_BACK)
			"alongside":
				_enter(State.ALONGSIDE)
			_:
				_enter(State.PACE)


func _physics_process(delta: float) -> void:
	if state == State.WRECKED:
		_update_wreck(delta)
	else:
		super(delta)


func _tick(delta: float) -> void:
	var p: Player = world.player
	_state_time += delta
	_bob_t += delta
	if p.surface == Player.Surface.FLOOR and p.grounded:
		_ground_h = p.h
	match state:
		State.HIDDEN:
			if p.distance >= _at - tune.burst_lead - tune.bang_seconds * maxf(p.speed, 1.0):
				_start_banging()
		State.BANGING:
			_update_banging(delta)
		State.EMERGE:
			_update_emerge()
		_:
			if p.alive and p.running:
				_update_cycle(delta)
	if state != State.HIDDEN and state != State.BANGING:
		_place()
		_burst_dash_walls()
	_animate(delta)


## GDD §9.3: it falls behind (or, if the player blocks its lane behind it, speeds off ahead).
func should_retire() -> bool:
	return state == State.LEAVING and (offset < -RETIRE_BEHIND or offset > RETIRE_AHEAD)


func targetable() -> bool:
	return super() and state != State.HIDDEN and state != State.BANGING


## The point of its centreline nearest the player, so shots from behind hit its tail.
func aim_point() -> Vector3:
	var along: float = clampf(-offset, -tune.length * 0.5, tune.length * 0.5)
	return global_position + global_basis * Vector3(0.0, tune.roof_height * 0.6, -along)


func hit_radius() -> float:
	return tune.width * 0.6


## True while the cannon is charging (its telegraph).
func charging() -> bool:
	return _charge_left >= 0.0


## Its big attacks (GDD §9: the lurch and the cannon shot): the forward lurch, from the rev (its
## warning) until the lurch is over, and a cannon shot, from the charge until the window shooters'
## bolts have followed it (the shots' flight holds the turn too, EnemyDirector.note_attack_shot).
## While another type's big attack is on, it keeps pacing or holding back and revs or charges once
## its turn comes (EnemyDirector.major_attack_blocked). DESIGN-TBD (docs/questions/r3.md): its
## entrance (the banging, then the burst that hurts a player on that wall section) isn't one: the
## generator plans where it bursts out, so it couldn't wait for a turn.
func is_major_attack_active() -> bool:
	return alive and (state == State.REV or state == State.LURCH_FWD or _charge_left >= 0.0 or not _volley.is_empty())


## Seconds it stays before leaving (GDD §9.3: 20–30 s), counted from the burst.
func stay_seconds() -> float:
	return _stay


## True while the player stands on (or is above) its roof.
func player_riding() -> bool:
	var p: Player = world.player
	if p.surface != Player.Surface.FLOOR or absf(p.position.x - _x) > tune.width * 0.5 + 0.1:
		return false
	var along: float = -offset
	if along < -tune.length * 0.5 - 0.3 or along > tune.length * 0.5 + 0.2:
		return false
	return p.h >= tune.cab_roof_height - 0.35


## True while the player is in its lane on the floor (not up on its roof).
func player_in_lane() -> bool:
	var p: Player = world.player
	return p.surface == Player.Surface.FLOOR and not p.in_pit and p.h < tune.roof_height - 0.3 \
		and absf(p.position.x - _x) < tune.width * 0.5 + world.tuning.hurtbox_size.x * 0.5


# --- Entrance ------------------------------------------------------------------------------------

func _start_banging() -> void:
	state = State.BANGING
	_state_time = 0.0
	_next_bang = 0.0
	first_bang_time = world.level_time()


func _update_banging(delta: float) -> void:
	_next_bang -= delta
	if _next_bang <= 0.0:
		_bang()
		_next_bang = tune.bang_interval
	if world.player.distance >= _at - tune.burst_lead and _state_time >= tune.min_warning_seconds:
		_burst()


func _bang() -> void:
	bangs += 1
	_bulge_push = 1.0
	_frame_flash = 0.18
	var pt: Vector3 = _wall_point(rng.randf_range(-tune.length * 0.4, tune.length * 0.4), rng.randf_range(0.6, 2.2))
	world.play_sfx_at(&"truck_bang", pt)
	world.effects.burst(pt, Color(1.0, 0.62, 0.2), 24, 0.8)
	world.effects.shake(0.06, 0.12)
	if bangs <= _cracks.size():
		_cracks[bangs - 1].visible = true


func _burst() -> void:
	state = State.EMERGE
	_state_time = 0.0
	burst_time = world.level_time()
	_active_time = 0.0
	offset = _at - world.player.distance
	offset_speed = 0.0
	_x_from = _x
	_yaw = side * 0.45
	_model.visible = true
	immune_to_weapons = false
	_set_solid(true)
	_bulge.visible = false
	_hole.visible = true
	_burst_hazard.set_enabled(true)
	_burst_left = tune.burst_hazard_seconds
	world.play_sfx_at(&"truck_burst", _wall_point(0.0, 1.5))
	world.effects.fireball(_wall_point(0.0, 1.5), FIRE_BURST_SIZE, false, 1.2)
	world.effects.burst(_wall_point(0.0, 1.2), Color(0.5, 0.47, 0.44), 30, 1.0)
	world.effects.shake(0.4, 0.45)
	_launch_rubble()


func _update_emerge() -> void:
	var k: float = clampf(_state_time / tune.emerge_seconds, 0.0, 1.0)
	var e: float = 1.0 - pow(1.0 - k, 3.0)
	_x = lerpf(_x_from, _lane_x, e)
	_yaw = lerpf(side * 0.45, 0.0, e)
	if k >= 1.0:
		_emerged(offset)
		_enter(State.PACE)


## In its lane, level and solid, `at` metres ahead of the player.
func _emerged(at_offset: float) -> void:
	offset = at_offset
	offset_speed = 0.0
	_x = _lane_x
	_yaw = 0.0
	_model.visible = true
	immune_to_weapons = false
	_set_solid(true)
	if burst_time < 0.0:
		burst_time = world.level_time()
	_rear_prev = offset - tune.length * 0.5
	_tip_prev = offset + tune.length * 0.5 + tune.nose_length


# --- Pacing and lurches ----------------------------------------------------------------------------
# The pacing cycle (GDD §9.3 only says it paces the player and lurches backward and forward; FB 91):
# pace ahead (cannon) -> lurch back -> hold behind -> rev -> lurch forward -> alongside.

func _update_cycle(delta: float) -> void:
	_active_time += delta
	_cannon_timer -= delta
	if player_riding() and state != State.RIDDEN:
		_enter(State.RIDDEN)
	elif state != State.RIDDEN and state != State.LURCH_FWD and state != State.LURCH_BACK and _player_inside():
		# Someone dropped into its footprint below the roof (from the wall): it backs off them.
		_enter(State.LURCH_BACK)
	var due: bool = _active_time >= _stay
	match state:
		State.PACE:
			_aim_for(tune.pace_offset, tune.drift_speed, tune.drift_accel)
			if absf(offset - tune.pace_offset) < 1.0:
				_pace_clock += delta
			_update_guns(delta)
			if player_in_lane() and offset + tune.length * 0.5 < 0.0 and _charge_left < 0.0:
				# The player is in its lane ahead of it (it can't pace past them): the threat there is
				# the forward lurch, after its warning.
				_enter(State.LEAVING if due else State.HOLD_BACK)
			elif _giving_way():
				# Task H7a: a dash wall ahead: it drops behind the runner and lets them break it first.
				_enter(State.LEAVING if due else State.LURCH_BACK)
			elif (_pace_clock >= _pace_time or due) and _charge_left < 0.0 and _volley.is_empty():
				_enter(State.LEAVING if due else State.LURCH_BACK)
		State.LURCH_BACK:
			_aim_for(tune.back_offset, tune.lurch_back_speed, tune.lurch_accel)
			if due:
				_enter(State.LEAVING)
			elif absf(offset - tune.back_offset) < 0.4:
				_enter(State.HOLD_BACK)
			elif _state_time > tune.lurch_back_timeout:
				_enter(State.PACE)
		State.HOLD_BACK:
			_aim_for(tune.back_offset, tune.drift_speed, tune.drift_accel)
			if due:
				_enter(State.LEAVING)
			elif _state_time >= tune.hold_back_seconds and _escape_ok() and not _wall_ahead(_attack_seconds()) \
					and not world.director.major_attack_blocked(self):
				# GDD §9: it holds back until no other type's big attack is on, then revs; task H7a: nor
				# while a dash wall comes before its forward lurch and its stay alongside are over.
				_enter(State.REV)
		State.REV:
			_aim_for(offset, tune.drift_speed, tune.drift_accel)
			if _state_time >= tune.rev_seconds:
				_enter(State.LURCH_FWD)
		State.LURCH_FWD:
			_aim_for(tune.alongside_offset, tune.lurch_forward_speed, tune.lurch_accel)
			if offset >= tune.alongside_offset - 0.3 or _state_time > 2.0:
				_enter(State.ALONGSIDE)
		State.ALONGSIDE:
			_aim_for(tune.alongside_offset, tune.drift_speed, tune.drift_accel)
			if due or _state_time >= tune.alongside_seconds:
				_enter(State.LEAVING if due else State.PACE)
			elif _giving_way():
				_enter(State.LURCH_BACK)
		State.RIDDEN:
			if not player_riding():
				_enter(State.LEAVING if due else State.HOLD_BACK)
			else:
				_aim_for(offset - 10.0, tune.roof_drift_speed, tune.drift_accel)
		State.LEAVING:
			_update_leaving(delta)
	_move_offset(delta)
	_apply_clamps()


func _enter(next: State) -> void:
	# GDD §9: it asks for its turn only while pacing (the cannon) or holding back (the lurch), so a
	# change of state means it either started that attack or gave it up (a cannon shot whose turn
	# didn't come before its pacing ended is skipped): either way it isn't waiting any more.
	world.director.give_up_turn(self)
	state = next
	_state_time = 0.0
	_spikes.set_enabled(next == State.LURCH_FWD)
	match next:
		State.PACE:
			_pace_time = tune.pace_seconds_at(_scaling) * rng.randf_range(0.85, 1.15)
			_pace_clock = 0.0
			_cannon_timer = maxf(_cannon_timer, tune.first_shot_delay)
		State.REV:
			# The forward lurch's audio warning (DESIGN-TBD: the sound itself is a placeholder).
			world.play_sfx_at(&"truck_rev", _front_point())
		State.LURCH_FWD:
			forward_lurches += 1
		State.LEAVING:
			leave_time = world.level_time()
			_blocked_time = 0.0
	if next != State.PACE:
		_charge_left = -1.0
		_volley.clear()


func _aim_for(target: float, max_speed: float, accel: float) -> void:
	_target = target
	_max_speed = max_speed
	_accel = accel


## Moves the offset toward the target: accelerate, cruise, brake to a stop on it.
func _move_offset(delta: float) -> void:
	var diff: float = _target - offset
	var want: float = 0.0
	if absf(diff) > 0.01:
		want = signf(diff) * minf(_max_speed, sqrt(1.6 * _accel * absf(diff)))
	offset_speed = move_toward(offset_speed, want, _accel * delta)
	offset += offset_speed * delta


## Only the telegraphed forward lurch may drive it into a player in its lane: otherwise its rear
## never backs into a player behind it and its spikes never creep up on a player ahead of it.
func _apply_clamps() -> void:
	var rear: float = offset - tune.length * 0.5
	var tip: float = offset + tune.length * 0.5 + tune.nose_length
	if state != State.RIDDEN and player_in_lane():
		var half: float = world.tuning.hurtbox_size.z * 0.5
		if _rear_prev >= half and rear < half + tune.rear_gap:
			offset = half + tune.rear_gap + tune.length * 0.5
			offset_speed = maxf(offset_speed, 0.0)
		elif state != State.LURCH_FWD and _tip_prev <= -half and tip > -half - tune.front_gap:
			offset = -half - tune.front_gap - tune.length * 0.5 - tune.nose_length
			offset_speed = minf(offset_speed, 0.0)
	_rear_prev = offset - tune.length * 0.5
	_tip_prev = offset + tune.length * 0.5 + tune.nose_length


## Standing on the floor inside its footprint, under the roof (e.g. dropped off the wall too low).
## A player in the air there may be on their way up onto the roof.
func _player_inside() -> bool:
	if not player_in_lane() or not world.player.grounded:
		return false
	var along: float = -offset
	return along > -tune.length * 0.5 - 0.1 and along < tune.length * 0.5 + tune.nose_length


## A player in its lane ahead of it must be able to get out before the forward lurch arrives:
## onto the wall beside it (no sign in the way) or into the next lane (no gap, fence or zone doodad
## there: a doodad's side would block the switch).
func _escape_ok() -> bool:
	var p: Player = world.player
	if not player_in_lane() or offset + tune.length * 0.5 > 0.0:
		return true
	var d: float = p.distance
	var reach: float = d + (tune.rev_seconds + tune.escape_margin) * maxf(p.speed, 1.0)
	var layout: LevelLayout = world.layout
	var wall_ok: bool = true
	for s: Dictionary in layout.signs:
		if int(s["side"]) == side and float(s["start"]) <= reach and float(s["end"]) >= d - 1.0:
			wall_ok = false
			break
	var inward: int = lane - side
	var lane_ok: bool = inward >= 0 and inward < layout.lane_count \
		and not layout.gapped_between(inward, d - 1.0, reach + 3.0) and not layout.doodad_between(d - 1.0, reach + 3.0, inward)
	if lane_ok:
		for f: Dictionary in layout.fences:
			if int(f["lane"]) == inward and float(f["at"]) >= d - 1.0 and float(f["at"]) <= reach + 3.0:
				lane_ok = false
				break
	return wall_ok or lane_ok


func _update_leaving(delta: float) -> void:
	if _leave_ahead:
		_aim_for(RETIRE_AHEAD + 20.0, tune.leave_speed * 1.5, tune.drift_accel)
		return
	_aim_for(-RETIRE_BEHIND - 20.0, tune.leave_speed, tune.drift_accel)
	if player_in_lane() and offset - tune.length * 0.5 > 0.0:
		# With the player in its lane behind it, it speeds off ahead instead of backing
		# into them (FB 91).
		_blocked_time += delta
		if _blocked_time > 1.5:
			_leave_ahead = true


# --- Guns ----------------------------------------------------------------------------------------

func _update_guns(delta: float) -> void:
	if not _guns:
		return
	_update_volley(delta)
	if _charge_left >= 0.0:
		_charge_left -= delta
		if _charge_left < 0.0:
			_fire_cannon()
		return
	if _cannon_timer <= 0.0 and _volley.is_empty() and _can_fire() and not _doodad_in_reach() \
			and not world.director.major_attack_blocked(self):
		# GDD §9: the charge (the shot's warning) waits until no other type's big attack is on; GDD §3:
		# nor is it fired at a player a zone doodad hems in (asked first, so it never holds a turn).
		_charge_left = tune.cannon_charge_seconds
		world.play_sfx_at(&"truck_cannon_charge", _cannon_muzzle.global_position)


## Only while pacing ahead of the player, with a clear shot back at them (not at a rider or a
## player up on the ceiling).
func _can_fire() -> bool:
	# When it fires, and that it holds fire at a ceiling runner or a rider (FB 92).
	var p: Player = world.player
	return p.alive and p.running and p.surface != Player.Surface.CEILING and state == State.PACE \
		and offset - tune.length * 0.5 > 2.0 and absf(offset - tune.pace_offset) < 2.5 and not player_riding()


## GDD §3 (zone doodads): the cannon never fires at a player a doodad hems in (its side blocks the
## dodge, its push moves them into the shot). True while a doodad stands, in any lane, along the
## stretch the player runs from now until a shot charged now, and its gunners' bolts, have passed
## them. The generator keeps doodads off every lane while a truck is surely there (its shortest stay)
## and out of its lane until it has left, so this holds back only a truck that stays longer.
## DESIGN-TBD (docs/questions/g5.md 5).
func _doodad_in_reach() -> bool:
	if world.layout.doodads.is_empty() and world.layout.dash_walls.is_empty():
		return false
	var p: Player = world.player
	var seconds: float = tune.cannon_charge_seconds + maxf(offset, 0.0) / maxf(tune.shell_speed_at(_scaling), 1.0) \
		+ shooters * tune.shooter_delay + 0.5
	return world.layout.doodad_between(p.distance - 1.0, p.distance + maxf(p.speed, 1.0) * seconds)


func _fire_cannon() -> void:
	_cannon_timer = tune.cannon_interval_at(_scaling)
	if not _can_fire():
		return  # The charge fizzles: the shot was no longer on.
	var from: Vector3 = _cannon_muzzle.global_position
	_shoot(from, _aim_at_player(), tune.shell_speed_at(_scaling), &"enemy_shell", CANNON_NAME)
	cannon_shots += 1
	world.play_sfx_at(&"truck_cannon", from)
	world.effects.burst(from, HOT, 12, 0.4)
	_volley.clear()
	for i: int in shooters:
		_volley.append(tune.shooter_delay * (i + 1))


# The window shooters fire bolts just after the cannon, in its telegraphed volley (FB 92).
func _update_volley(delta: float) -> void:
	for i: int in _volley.size():
		_volley[i] -= delta
	while not _volley.is_empty() and _volley[0] <= 0.0:
		_volley.pop_front()
		var gunner: int = shooters - _volley.size() - 1
		if _can_fire() and gunner >= 0 and gunner < _shooter_muzzles.size():
			_shoot(_shooter_muzzles[gunner].global_position, _aim_at_player(), tune.bolt_speed_at(_scaling), &"enemy_bolt", BOLT_NAME)


## Where to shoot: the player's spot at running height (a jump doesn't move the aim), or their spot
## on a wall.
func _aim_at_player() -> Vector3:
	var p: Player = world.player
	var half: float = world.tuning.hurtbox_size.y * 0.5
	match p.surface:
		Player.Surface.WALL:
			return Vector3(p.wall_side * (world.geo.wall_x() - half), p.h, p.position.z)
		Player.Surface.FLOOR:
			return Vector3(p.position.x, _ground_h + half, p.position.z)
	return p.hurtbox_aabb().get_center()


## A shot that flies straight at `target` in the player's frame (it moves with the player).
func _shoot(from: Vector3, target: Vector3, speed: float, look: StringName, shot_name: String) -> void:
	var to: Vector3 = target - from
	var dist: float = to.length()
	if dist < 0.5:
		return
	var velocity: Vector3 = to / dist * speed + Vector3(0.0, 0.0, -world.player.speed)
	var shot: Projectile = world.projectiles.fire_enemy(from, velocity, look, shot_name, dist / speed + 0.8)
	# The cannon shot's turn lasts until the shell and the gunners' bolts have passed the player (GDD §9).
	world.director.note_attack_shot(self, shot)


# --- Destroyed -----------------------------------------------------------------------------------

## Stomped or shot down: it loses its roof and spins out, skidding ahead into its wall (clear of the
## player's lane and in view), then explodes.
func _on_defeated(_cause: StringName) -> void:
	state = State.WRECKED
	_state_time = 0.0
	_set_solid(false)
	_spikes.set_enabled(false)
	_burst_hazard.set_enabled(false)
	_charge_left = -1.0
	_volley.clear()
	_wreck_spin = -side * rng.randf_range(0.5, 0.8)
	_nose_light.light_energy = 0.0
	world.effects.burst(_weak_mesh.global_position + Vector3(0.0, 0.3, 0.0), WEAK, 28, 0.9)
	world.effects.shake(0.25, 0.3)


func _update_wreck(delta: float) -> void:
	_state_time += delta
	offset += tune.wreck_skid_speed * (1.0 - clampf(_state_time / tune.wreck_seconds, 0.0, 1.0)) * delta
	if _boom_t >= 0.0:
		_update_boom(delta)
		return
	_x = move_toward(_x, side * (world.geo.wall_x() - tune.width * 0.5 - 0.1), 3.0 * delta)
	_yaw += _wreck_spin * delta
	_model.rotation.z = move_toward(_model.rotation.z, -side * 0.3, delta)
	_smoke_left -= delta
	if _smoke_left <= 0.0:
		_smoke_left = 0.15
		world.effects.burst(global_position + Vector3(0.0, tune.roof_height, 0.0), HOT, 8, 0.35)
	_place()
	_animate(delta)
	if _state_time >= tune.wreck_seconds:
		_explode()


func _explode() -> void:
	var at: Vector3 = global_position + Vector3(0.0, 1.2, 0.0)
	world.play_sfx_at(&"truck_explode", at)
	# It skids into its wall: the fireball is set a little out into the street, so the wall doesn't cut it off.
	world.effects.fireball(at - Vector3(side * FIRE_OFF_WALL, 0.0, 0.0), FIRE_EXPLODE_SIZE)
	world.effects.burst(at, Color(0.45, 0.42, 0.4), 24, 1.0)
	world.effects.shake(0.5, 0.5)
	# The truck is gone in the fireball (a pooled effect, RunEffects.fireball); its node waits out BOOM_SECONDS.
	_model.visible = false
	_boom_t = 0.0


func _update_boom(delta: float) -> void:
	_boom_t += delta
	_place()
	if _boom_t >= BOOM_SECONDS:
		queue_free()


# --- Presentation --------------------------------------------------------------------------------

func _place() -> void:
	var bob: float = sin(_bob_t * 2.0) * tune.bob_height
	position = Vector3(_x, bob, TrackGeometry.world_z(world.player.distance + offset))
	rotation = Vector3(0.0, _yaw, 0.0)


func _front_point() -> Vector3:
	return global_position + global_basis * Vector3(0.0, 1.0, -tune.length * 0.5 - tune.nose_length)


## The face (track distance) of the nearest standing dash wall the runner hasn't reached yet, or INF.
func _next_wall() -> float:
	var p: Player = world.player
	var best: float = INF
	for w: Dictionary in world.layout.dash_walls:
		var face: float = float(w["start"])
		if not bool(w.get("smashed", false)) and face >= p.distance - 1.0 and face < best:
			best = face
	return best


## True if the runner comes to a standing dash wall within the time the truck needs to drop behind them from
## where it is now (HoverTruckTuning.give_way_seconds) with WALL_GIVE_WAY_MARGIN and `extra_seconds` more
## (task H7a).
func _wall_ahead(extra_seconds: float = 0.0) -> bool:
	if world.layout.dash_walls.is_empty():
		return false
	var face: float = _next_wall()
	if is_inf(face):
		return false
	var p: Player = world.player
	var seconds: float = tune.give_way_seconds(offset) + WALL_GIVE_WAY_MARGIN + extra_seconds
	return face - p.distance <= seconds * maxf(p.speed, 1.0)


## True if it gives way to a dash wall now (_wall_ahead; task H7a): one is coming, and it can drop back (the
## runner isn't in its lane behind it: it never backs into them).
func _giving_way() -> bool:
	return _wall_ahead() and not (player_in_lane() and offset - tune.length * 0.5 > 0.0)


## Seconds from the rev's start until its forward lurch and its stay alongside are over, and it could give way
## again (task H7a: no rev while a dash wall comes within them).
func _attack_seconds() -> float:
	return tune.rev_seconds + 2.0 + tune.alongside_seconds + tune.give_way_seconds(tune.alongside_offset)


## GDD §9.14 (task H7a): a standing dash wall its nose reaches (anywhere along its body, so one it emerged
## beside goes too) is burst through as it burst out of the building: it breaks (DashBreakable.smash, broken
## by &"hover_truck"; one whose chunk isn't built yet is marked broken in the layout, so it's never built)
## and crumbles with its crash, flung along the truck's way (RunEffects.crumble, dash_wall_smash). The
## runner then finds it broken: it costs them nothing.
func _burst_dash_walls() -> void:
	var walls: Array[Dictionary] = world.layout.dash_walls
	if walls.is_empty() or state == State.WRECKED:
		return
	var centre: float = world.player.distance + offset
	var tip: float = centre + tune.length * 0.5 + tune.nose_length
	var rear: float = centre - tune.length * 0.5
	for w: Dictionary in walls:
		if bool(w.get("smashed", false)) or float(w["start"]) > tip or float(w["end"]) < rear:
			continue
		var b: DashBreakable = world.track.dash_wall_for(w) if world.track != null else null
		if b == null:
			w["smashed"] = true
			w["broken_by"] = "hover_truck"
			walls_burst += 1
			continue
		if not b.smash(&"hover_truck"):
			continue
		walls_burst += 1
		var push := Vector3(0.0, 0.0, -maxf(world.player.speed + offset_speed, 0.0))
		if world.effects != null:
			world.effects.crumble(b, push)
		world.play_sfx_at(&"dash_wall_smash", _front_point())


## A point on the wall face it bursts through: `along` metres from its burst point, `height` up.
func _wall_point(along: float, height: float) -> Vector3:
	return Vector3(side * (world.geo.wall_x() - 0.08), height, TrackGeometry.world_z(_at + along))


func _set_solid(on: bool) -> void:
	for body: StaticBody3D in _roofs:
		body.collision_layer = TrackBuilder.LAYER_FLOOR if on else 0
	_blocker.collision_layer = TrackBuilder.LAYER_LANE_BLOCKER if on else 0
	_weak.set_enabled(on)


func _animate(delta: float) -> void:
	# The hull pitches with its lurches.
	var accel: float = (offset_speed - _prev_speed) / maxf(delta, 0.0001)
	_prev_speed = offset_speed
	_pitch = lerpf(_pitch, clampf(accel * 0.003, -0.09, 0.09), 1.0 - exp(-6.0 * delta))
	_model.rotation.x = _pitch
	# The weak point pulses; the spikes flash through the rev and blaze during the forward lurch
	# (with Reduced flashing they glow steadily through the rev instead of flashing).
	var pulse: float = 1.0 + 0.1 * sin(_bob_t * 7.0)
	_weak_mesh.scale = Vector3(pulse, 1.0 + 0.2 * (pulse - 1.0), pulse)
	var revving: bool = state == State.REV
	var lurching: bool = state == State.LURCH_FWD
	var flash_on: bool = lurching or (revving and (Settings.flashing_reduced or int(_state_time * 10.0) % 2 == 0))
	_spikes_mesh.material_override = _mats["flash"] if flash_on else null
	_nose_light.light_energy = (4.0 if flash_on else 1.0) if (revving or lurching) else 0.0
	_thrust.material_override = _mats["hot"] if revving or lurching else null
	var boost: float = 1.0 + (1.8 if lurching else (0.9 if revving else 0.0))
	_thrust.scale = Vector3(1.0, 1.0, boost)
	_brake.material_override = _mats["brake_on"] if state == State.LURCH_BACK or (state == State.WRECKED) else null
	# The cannon's charge glow grows until it fires; the gunners' weapons glow with it.
	var charging: bool = _charge_left >= 0.0
	var k: float = 1.0 - clampf(_charge_left / tune.cannon_charge_seconds, 0.0, 1.0) if charging else 0.0
	_charge.visible = charging
	_charge.scale = Vector3.ONE * (0.15 + 0.5 * k) * (1.0 + 0.15 * sin(_state_time * 40.0))
	for g: MeshInstance3D in _shooter_guns:
		g.material_override = _mats["hot"] if charging or not _volley.is_empty() else null
	if state == State.PACE or charging:
		var aim: Vector3 = _aim_at_player()
		if aim.distance_squared_to(_cannon.global_position) > 1.0:
			_cannon.look_at(aim, Vector3.UP)
	# The wall: bulging with each bang, then the burst's hazard window and debris.
	_bulge_push = move_toward(_bulge_push, 0.0, 4.0 * delta)
	_bulge.position.x = -side * (0.1 + 0.45 * _bulge_push)
	_frame_flash -= delta
	_bang_frame.visible = state == State.BANGING
	# The frame flashes with each bang; with Reduced flashing it glows steadily and softly all through the banging.
	if Settings.flashing_reduced:
		_bang_frame.material_override = _mats["flash_soft"]
	else:
		_bang_frame.material_override = _mats["flash"] if _frame_flash > 0.0 else null
	if _burst_left > 0.0:
		_burst_left -= delta
		if _burst_left <= 0.0:
			_burst_hazard.set_enabled(false)
	if _hole.visible:
		_hole_fire.visible = Settings.flashing_reduced or int(_bob_t * 12.0) % 3 != 0
	if _rubble_left > 0.0:
		_rubble_left -= delta
		for i: int in _rubble.size():
			_rubble_v[i].y -= 18.0 * delta
			_rubble[i].position += _rubble_v[i] * delta
			_rubble[i].rotate_x(6.0 * delta)
			if _rubble[i].position.y < 0.15:
				_rubble[i].position.y = 0.15
				_rubble_v[i] = _rubble_v[i] * 0.4
			if _rubble_left < 0.5:
				_rubble[i].scale = _rubble[i].scale * maxf(0.0, 1.0 - 6.0 * delta)
		if _rubble_left <= 0.0:
			for r: MeshInstance3D in _rubble:
				r.visible = false


func _launch_rubble() -> void:
	_rubble_left = 1.3
	for i: int in _rubble.size():
		var r: MeshInstance3D = _rubble[i]
		r.visible = true
		r.position = Vector3(-side * 0.3, rng.randf_range(0.6, 2.4), rng.randf_range(-tune.length * 0.45, tune.length * 0.45))
		# Rubble stays by the wall: harmless debris must not look like an obstacle in the lanes.
		_rubble_v[i] = Vector3(-side * rng.randf_range(1.0, 2.5), rng.randf_range(2.0, 5.0), rng.randf_range(-2.0, 2.0))


func _build_hitboxes() -> void:
	var t: HoverTruckTuning = tune
	var cab_z: float = -t.length * 0.5 + t.cab_length * 0.5
	# Roofs: moving floor surfaces the player lands on and rides (Player._support_top).
	_roofs.append(_roof(Vector3(t.width - 0.1, 0.3, t.length - t.cab_length),
		Vector3(0.0, t.roof_height - 0.15, t.cab_length * 0.5)))
	_roofs.append(_roof(Vector3(t.width - 0.1, 0.3, t.cab_length), Vector3(0.0, t.cab_roof_height - 0.15, cab_z)))
	# The weak point: stomping it defeats the truck; touching it any other way is harmless.
	# It sits on a cab roof lower than the cargo roof, so a rider carried forward drops
	# onto it (FB 93).
	_weak = add_hitbox(&"weak_point", Vector3(t.width * 0.7, 0.4, t.cab_length - 0.4),
		Vector3(0.0, t.cab_roof_height + 0.2, cab_z))
	_weak.hazard_name = "hover truck weak point"
	# The spikes: solid (armor doesn't stop them), live only during the forward lurch. Narrow enough
	# that a wall-runner beside the truck is never caught (their body reaches in from the wall face).
	var half_w: float = clampf(world.geo.lane_width * 0.5 + world.tuning.wall_margin
		- world.tuning.hurtbox_size.y - 0.1, 0.15, 0.35)
	var top: float = t.roof_height - 0.2
	_spikes = add_hitbox(&"body", Vector3(half_w * 2.0, top - 0.3, t.nose_length + 0.15),
		Vector3(0.0, (top + 0.3) * 0.5, -t.length * 0.5 - t.nose_length * 0.5 + 0.075))
	_spikes.hazard_name = SPIKES_NAME
	_spikes.set_enabled(false)
	# claw_immune and dash_kills keep the shared rules, so claws or the dash defeat it on
	# contact with its (live) spikes (FB 93); GDD §9.3 names only the weak point and weapons.
	# Solid sides: switching lanes into it bumps the player back (GDD §9.3).
	_blocker = add_lane_blocker(Vector3(world.geo.lane_width * 0.9, t.roof_height, t.length + t.nose_length),
		Vector3(0.0, t.roof_height * 0.5, -t.nose_length * 0.5))


func _roof(size: Vector3, center: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = TrackBuilder.LAYER_FLOOR
	body.collision_mask = 0
	body.position = center
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	return body


func _build_body() -> void:
	var t: HoverTruckTuning = tune
	var meshes: Dictionary = _meshes(world.skin.enemy_variant if world.skin != null else &"city", t)
	_model = Node3D.new()
	add_child(_model)
	_mesh_node(_model, meshes["body"], Vector3.ZERO)
	_spikes_mesh = _mesh_node(_model, meshes["spikes"], Vector3.ZERO)
	var cab_z: float = -t.length * 0.5 + t.cab_length * 0.5
	_weak_mesh = _mesh_node(_model, meshes["weak"], Vector3(0.0, t.cab_roof_height, cab_z))
	_thrust = _mesh_node(_model, meshes["thrust"], Vector3(0.0, t.hover_clearance + 0.38, t.length * 0.5 + 0.18))
	_brake = _mesh_node(_model, meshes["brake"], Vector3.ZERO)
	# The cannon on the tail, aimed back at the player (-z points at the target).
	_cannon = Node3D.new()
	_cannon.position = Vector3(0.0, t.roof_height - 0.42, t.length * 0.5 + 0.22)
	_model.add_child(_cannon)
	_cannon.rotation.y = PI
	_mesh_node(_cannon, meshes["barrel"], Vector3.ZERO)
	_cannon_muzzle = Node3D.new()
	_cannon_muzzle.position = Vector3(0.0, 0.0, -1.0)
	_cannon.add_child(_cannon_muzzle)
	_charge = _mesh_node(_cannon, meshes["charge"], Vector3(0.0, 0.0, -1.0))
	_charge.visible = false
	# Window shooters in the tail windows beside the cannon (0 early, 1–2 late).
	for i: int in shooters:
		var sx: float = (1.0 if i == 0 else -1.0) * t.width * 0.31
		var at := Vector3(sx, t.roof_height - 0.5, t.length * 0.5)
		_mesh_node(_model, meshes["gunner"], at)
		_shooter_guns.append(_mesh_node(_model, meshes["gunner_gun"], at))
		var muzzle := Node3D.new()
		muzzle.position = at + Vector3(0.14, -0.12, 0.5)
		_model.add_child(muzzle)
		_shooter_muzzles.append(muzzle)
	_nose_light = OmniLight3D.new()
	_nose_light.light_color = HOT
	_nose_light.omni_range = 7.0
	_nose_light.light_energy = 0.0
	_nose_light.position = Vector3(0.0, 1.0, -t.length * 0.5 - t.nose_length - 0.6)
	_model.add_child(_nose_light)


func _build_wall_fx() -> void:
	var t: HoverTruckTuning = tune
	var meshes: Dictionary = _meshes(world.skin.enemy_variant if world.skin != null else &"city", t)
	# Stays on the facade while the truck moves on.
	_wall_fx = Node3D.new()
	_wall_fx.top_level = true
	add_child(_wall_fx)
	_wall_fx.global_position = Vector3(side * world.geo.wall_x(), 0.0, TrackGeometry.world_z(_at))
	# The facade panel it bangs on, framed in warning glow: bulges toward the track with each bang
	# (the frame flashes) and cracks open.
	_bulge = Node3D.new()
	_wall_fx.add_child(_bulge)
	GreyboxMaterials.add_box(_bulge, Vector3(0.0, 1.45, 0.0), Vector3(0.3, 2.7, t.length + 0.4), GreyboxMaterials.flat(FACADE))
	_bang_frame = _mesh_node(_bulge, meshes["bang_frame"], Vector3(-side * 0.17, 0.0, 0.0))
	for i: int in 5:
		var crack := GreyboxMaterials.add_box(_bulge, Vector3(-side * 0.17, rng.randf_range(0.6, 2.3),
			rng.randf_range(-t.length * 0.42, t.length * 0.42)), Vector3(0.03, 0.07, rng.randf_range(1.0, 2.0)),
			GreyboxMaterials.glow(HOT, 4.5))
		crack.rotation.x = rng.randf_range(-1.0, 1.0)
		crack.visible = false
		_cracks.append(crack)
	_hole = Node3D.new()
	_hole.visible = false
	_wall_fx.add_child(_hole)
	_mesh_node(_hole, meshes["hole"], Vector3(-side * 0.04, 0.0, 0.0))
	_hole_fire = _mesh_node(_hole, meshes["hole_fire"], Vector3(-side * 0.06, 0.0, 0.0))
	var chunk: Material = GreyboxMaterials.flat(Color(0.3, 0.28, 0.3))
	for i: int in 7:
		var r := GreyboxMaterials.add_box(_wall_fx, Vector3.ZERO, Vector3.ONE * rng.randf_range(0.18, 0.4), chunk)
		r.visible = false
		_rubble.append(r)
		_rubble_v.append(Vector3.ZERO)
	# The burst: an attack on the wall face over the truck's length and a little beyond, live for a
	# moment. A player on the floor beside it is out of its reach.
	# The burst is an enemy attack, so armor blocks it, not a solid collision (FB 93).
	var section: float = t.length + t.burst_section_before + t.burst_section_after
	_burst_hazard = add_hitbox(&"attack", Vector3(0.9, 5.6, section),
		Vector3(-side * 0.45, 2.8, (t.burst_section_before - t.burst_section_after) * 0.5), true, _wall_fx)
	_burst_hazard.hazard_name = BURST_NAME
	_burst_hazard.set_enabled(false)


func _mesh_node(parent: Node3D, mesh: Mesh, at: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.position = at
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	return m


## Low-poly model in local space: it faces -z (its direction of travel), origin on the floor under
## its centre. Safe parts in cool colours (roof edge, side strips, hover glow); the deadly front and
## the red weak point glow hot. City: sleek panels and a pointed nose. Scavenger: rusted, bolted
## plates, a spiked plow and barbed wire.
static func _meshes(variant: StringName, t: HoverTruckTuning) -> Dictionary:
	var key: String = "%s|%s" % [variant, [t.length, t.width, t.roof_height, t.cab_roof_height, t.cab_length,
		t.nose_length, t.hover_clearance]]
	if _models.has(key):
		return _models[key]
	var scav: bool = variant == &"scavenger"
	var L: float = t.length
	var W: float = t.width
	var R: float = t.roof_height
	var C: float = t.cab_roof_height
	var CL: float = t.cab_length
	var N: float = t.nose_length
	var B: float = t.hover_clearance
	var deck: float = B + 0.24
	var cab_z: float = -L * 0.5 + CL * 0.5
	var cargo_z: float = CL * 0.5
	var cargo_len: float = L - CL
	var body_m: Material = GreyboxMaterials.flat(Color(0.38, 0.22, 0.12) if scav else Color(0.22, 0.25, 0.34))
	var panel_m: Material = GreyboxMaterials.flat(Color(0.28, 0.17, 0.1) if scav else Color(0.32, 0.36, 0.47))
	var dark_m: Material = GreyboxMaterials.flat(Color(0.08, 0.08, 0.1))
	var metal_m: Material = GreyboxMaterials.flat(Color(0.5, 0.47, 0.44) if scav else Color(0.74, 0.78, 0.86))
	var safe_m: Material = GreyboxMaterials.glow(SAFE, 2.2)
	var hover_m: Material = GreyboxMaterials.glow(HOVER, 2.5)
	var glass_m: Material = GreyboxMaterials.glow(Color(0.08, 0.3, 0.36), 0.6, 0.35)
	var visor_m: Material = GreyboxMaterials.glow(Color(1.0, 0.2, 0.15), 3.0)
	var hot_m: Material = GreyboxMaterials.glow(HOT, 3.2)

	var b := MeshBatch.new()
	# Hover chassis and pods, and the soft glow they throw on the floor of the lane it holds.
	b.box(dark_m, Vector3(0.0, B + 0.12, 0.0), Vector3(W + 0.08, 0.24, L - 0.1))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			b.box(hover_m, Vector3(sx * W * 0.3, B - 0.04, sz * L * 0.3), Vector3(0.55, 0.08, 1.3))
	b.box(GreyboxMaterials.glow(HOVER, 1.0, 0.16), Vector3(0.0, 0.03, 0.0), Vector3(W * 0.9, 0.02, L * 0.9))
	# Cargo box, its roof deck and the cool glowing edge around the walkable roof.
	b.box(body_m, Vector3(0.0, (deck + R) * 0.5, cargo_z), Vector3(W, R - deck, cargo_len))
	b.box(panel_m, Vector3(0.0, R - 0.01, cargo_z), Vector3(W - 0.18, 0.04, cargo_len - 0.18))
	for sx: float in [-1.0, 1.0]:
		b.box(safe_m, Vector3(sx * (W * 0.5 - 0.035), R + 0.02, cargo_z), Vector3(0.07, 0.05, cargo_len))
	b.box(safe_m, Vector3(0.0, R + 0.02, L * 0.5 - 0.035), Vector3(W, 0.05, 0.07))
	b.box(safe_m, Vector3(0.0, R + 0.02, -L * 0.5 + CL + 0.035), Vector3(W, 0.05, 0.07))
	# Cab: lower body, a glass band with the cyborg driver behind it, roof slab and pillars.
	var glass_bottom: float = C - 0.42
	b.box(body_m, Vector3(0.0, (deck + glass_bottom) * 0.5, cab_z), Vector3(W, glass_bottom - deck, CL))
	b.box(glass_m, Vector3(0.0, (glass_bottom + C - 0.08) * 0.5, cab_z), Vector3(W - 0.04, C - 0.08 - glass_bottom, CL - 0.04))
	b.box(panel_m, Vector3(0.0, C - 0.04, cab_z), Vector3(W, 0.08, CL))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			b.box(panel_m, Vector3(sx * (W * 0.5 - 0.05), (glass_bottom + C) * 0.5, cab_z + sz * (CL * 0.5 - 0.05)),
				Vector3(0.1, C - glass_bottom, 0.1))
	var head := Vector3(0.0, glass_bottom + 0.2, cab_z + 0.3)
	b.box(dark_m, head + Vector3(0.0, -0.3, 0.05), Vector3(0.6, 0.3, 0.36))
	b.box(GreyboxMaterials.flat(Color(0.62, 0.64, 0.7)), head, Vector3(0.3, 0.32, 0.3))
	b.box(visor_m, head + Vector3(0.0, 0.03, -0.155), Vector3(0.26, 0.1, 0.02))
	for sx: float in [-1.0, 1.0]:
		b.box(visor_m, head + Vector3(sx * 0.155, 0.03, 0.0), Vector3(0.02, 0.1, 0.24))
	# Tail: cannon mount, thruster nozzles, and the gunners' windows.
	b.box(dark_m, Vector3(0.0, R - 0.42, L * 0.5 + 0.08), Vector3(0.78, 0.46, 0.18))
	for sx: float in [-1.0, 1.0]:
		b.cylinder(dark_m, Vector3(sx * W * 0.26, B + 0.38, L * 0.5 + 0.06), Vector3(0.38, 0.22, 0.38), Vector3(PI * 0.5, 0.0, 0.0))
		b.box(dark_m, Vector3(sx * W * 0.31, R - 0.5, L * 0.5 + 0.01), Vector3(0.5, 0.46, 0.03))
	if scav:
		# Rusted, bolted plates and a spiked plow on struts.
		var rust_m: Material = GreyboxMaterials.flat(Color(0.55, 0.3, 0.12))
		var bolt_m: Material = GreyboxMaterials.flat(Color(0.62, 0.6, 0.56))
		for sx: float in [-1.0, 1.0]:
			for i: int in 3:
				var z: float = -L * 0.5 + CL + 0.9 + i * (cargo_len - 1.6) / 2.0
				b.box(rust_m if i % 2 == 0 else panel_m, Vector3(sx * (W * 0.5 + 0.015), deck + 0.65 + 0.12 * (i % 2), z),
					Vector3(0.03, 0.7, 1.2), Vector3(0.05 * (i - 1), 0.0, 0.0))
				for c: int in 4:
					b.box(bolt_m, Vector3(sx * (W * 0.5 + 0.035), deck + 0.4 + (0.5 if c >= 2 else 0.0), z + (c % 2 - 0.5) * 1.0),
						Vector3(0.03, 0.06, 0.06))
		var plow_h: float = C - deck + 0.1
		b.box(rust_m, Vector3(0.0, deck + plow_h * 0.45, -L * 0.5 - N * 0.55), Vector3(W + 0.25, plow_h, 0.12), Vector3(0.45, 0.0, 0.0))
		for sx: float in [-1.0, 1.0]:
			b.box(dark_m, Vector3(sx * W * 0.3, deck + 0.3, -L * 0.5 - N * 0.3), Vector3(0.12, 0.12, N * 0.6))
		for row: int in 2:
			var wy: float = deck + 0.25 + row * plow_h * 0.45
			var wz: float = -L * 0.5 - N * 0.55 - 0.1 + row * 0.18
			b.box(bolt_m, Vector3(0.0, wy, wz), Vector3(W + 0.3, 0.025, 0.025))
			for k: int in 9:
				b.box(bolt_m, Vector3(-W * 0.55 + k * W * 0.1375, wy, wz), Vector3(0.09, 0.02, 0.02), Vector3(0.0, 0.0, 0.8))
	else:
		# Sleek panels with cool accent strips, and a pointed silver nose.
		for sx: float in [-1.0, 1.0]:
			b.box(safe_m, Vector3(sx * (W * 0.5 + 0.012), deck + (R - deck) * 0.62, cargo_z), Vector3(0.02, 0.06, cargo_len - 0.5))
			b.box(panel_m, Vector3(sx * (W * 0.5 + 0.01), deck + (R - deck) * 0.3, cargo_z), Vector3(0.02, 0.4, cargo_len - 0.3))
		var nose_h: float = C - deck - 0.12
		b.wedge(metal_m, Vector3(0.0, deck + nose_h * 0.5, -L * 0.5 - N * 0.5 + 0.02), Vector3(W * 0.94, N, nose_h), Vector3(-PI * 0.5, 0.0, 0.0))
	var body: ArrayMesh = b.commit()

	# The deadly front, glowing hot in every zone (swapped to a flash during the rev).
	var s := MeshBatch.new()
	if scav:
		var plow_h2: float = C - deck + 0.1
		for row: int in 2:
			for k: int in 3 - row:
				var x: float = (k - (2 - row) * 0.5) * W * (0.36 if row == 0 else 0.44)
				var y: float = deck + 0.18 + row * plow_h2 * 0.42
				s.spike(hot_m, Vector3(x, y, -L * 0.5 - N * 0.55 - 0.05 + row * 0.2), N * 0.8, 0.26, Vector3(-PI * 0.5, 0.0, 0.0))
	else:
		# A hot blade over the silver nose, a spike past its point, and two at its sides.
		var nose_h2: float = C - deck - 0.12
		var tip_z: float = -L * 0.5 - N + 0.02
		s.wedge(hot_m, Vector3(0.0, deck + nose_h2 + 0.02, tip_z + N * 0.375), Vector3(W * 0.7, N * 0.75, 0.05), Vector3(-PI * 0.5, 0.0, 0.0))
		s.spike(hot_m, Vector3(0.0, deck + nose_h2 * 0.5, tip_z + 0.12), 0.6, 0.26, Vector3(-PI * 0.5, 0.0, 0.0))
		for sx: float in [-1.0, 1.0]:
			s.spike(hot_m, Vector3(sx * W * 0.38, deck + 0.14, -L * 0.5), N * 0.85, 0.22, Vector3(-PI * 0.5, 0.0, 0.0))
	var spikes: ArrayMesh = s.commit()

	var w := MeshBatch.new()
	w.cylinder(dark_m, Vector3(0.0, 0.02, 0.0), Vector3(1.25, 0.05, 1.25))
	w.dome(GreyboxMaterials.glow(WEAK, 4.0), Vector3(0.0, 0.03, 0.0), Vector3(0.95, 0.36, 0.95))
	var weak: ArrayMesh = w.commit()

	var th := MeshBatch.new()
	for sx: float in [-1.0, 1.0]:
		th.cylinder(hover_m, Vector3(sx * W * 0.26, 0.0, 0.0), Vector3(0.28, 0.05, 0.28), Vector3(PI * 0.5, 0.0, 0.0))
	var thrust: ArrayMesh = th.commit()

	var br := MeshBatch.new()
	for sx: float in [-1.0, 1.0]:
		br.box(GreyboxMaterials.glow(AMBER, 1.2), Vector3(sx * W * 0.38, deck + 0.3, L * 0.5 + 0.02), Vector3(0.32, 0.1, 0.04))
	var brake: ArrayMesh = br.commit()

	var ba := MeshBatch.new()
	ba.cylinder(dark_m, Vector3(0.0, 0.0, -0.45), Vector3(0.24, 0.9, 0.24), Vector3(PI * 0.5, 0.0, 0.0))
	ba.box(dark_m, Vector3(0.0, 0.0, -0.9), Vector3(0.34, 0.2, 0.14))
	ba.box(dark_m, Vector3(0.0, 0.0, 0.0), Vector3(0.44, 0.3, 0.3))
	var barrel: ArrayMesh = ba.commit()

	var ch := SphereMesh.new()
	ch.radius = 0.5
	ch.height = 1.0
	ch.radial_segments = 10
	ch.rings = 5
	ch.material = GreyboxMaterials.glow(HOT, 5.0)

	# A gunner leaning out of a tail window: head and shoulders, red LED visor toward the player.
	var gn := MeshBatch.new()
	gn.box(GreyboxMaterials.flat(Color(0.4, 0.41, 0.46)), Vector3(0.0, 0.08, 0.12), Vector3(0.24, 0.26, 0.22))
	gn.box(visor_m, Vector3(0.0, 0.1, 0.235), Vector3(0.2, 0.06, 0.02))
	gn.box(dark_m, Vector3(0.0, -0.16, 0.06), Vector3(0.42, 0.2, 0.2))
	var gunner: ArrayMesh = gn.commit()
	var gg := MeshBatch.new()
	gg.box(GreyboxMaterials.flat(Color(0.12, 0.12, 0.14)), Vector3(0.14, -0.12, 0.26), Vector3(0.09, 0.09, 0.42))
	var gunner_gun: ArrayMesh = gg.commit()

	# The hole it leaves in the facade: dark, with a burning rim.
	var h := MeshBatch.new()
	var hole_h: float = R + 0.3
	h.box(dark_m, Vector3(0.0, hole_h * 0.5 + 0.1, 0.0), Vector3(0.06, hole_h, L + 0.2))
	var rim_m: Material = GreyboxMaterials.glow(HOT, 2.6)
	h.box(rim_m, Vector3(0.0, hole_h + 0.12, 0.0), Vector3(0.08, 0.12, L + 0.4))
	for sz: float in [-1.0, 1.0]:
		h.box(rim_m, Vector3(0.0, hole_h * 0.5 + 0.1, sz * (L * 0.5 + 0.16)), Vector3(0.08, hole_h, 0.12))
	var hole: ArrayMesh = h.commit()
	# The warning frame around the panel it bangs on (drawn only while banging).
	var fr := MeshBatch.new()
	var frame_m: Material = GreyboxMaterials.glow(HOT, 2.2)
	for y: float in [0.16, 2.74]:
		fr.box(frame_m, Vector3(0.0, y, 0.0), Vector3(0.05, 0.14, L + 0.4))
	for sz: float in [-1.0, 1.0]:
		fr.box(frame_m, Vector3(0.0, 1.45, sz * (L * 0.5 + 0.13)), Vector3(0.05, 2.72, 0.14))
	var bang_frame: ArrayMesh = fr.commit()
	var hf := MeshBatch.new()
	hf.box(GreyboxMaterials.glow(Color(1.0, 0.55, 0.15), 3.5, 0.7), Vector3(0.0, 0.45, 0.0), Vector3(0.05, 0.5, L * 0.8))
	var hole_fire: ArrayMesh = hf.commit()

	var out := {"body": body, "spikes": spikes, "weak": weak, "thrust": thrust, "brake": brake, "barrel": barrel,
		"charge": ch, "gunner": gunner, "gunner_gun": gunner_gun, "hole": hole, "hole_fire": hole_fire,
		"bang_frame": bang_frame}
	_models[key] = out
	return out
