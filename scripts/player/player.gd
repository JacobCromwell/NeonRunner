class_name Player
extends Node3D
## Kinematic runner controller covering the floor, both side walls and the ceiling.
## Lanes are movement targets only. Support comes from physics rays against floor and hull
## bodies. Hazard and trigger contact comes from shape queries on the current frame, swept
## over the distance run this frame so nothing is skipped at speed. DamageRules resolves hits.
## Input arrives only as named actions (keyboard via the InputMap, touch via TouchInput).

signal died(cause: String)
## Something happened that feedback (sound, HUD) may react to: jump, land, slide, wall_enter,
## wall_jump, wall_exit, wall_blocked, ramp, pad, hull_end, died.
signal movement_event(kind: StringName)

enum Surface { FLOOR, CEILING, WALL }

const ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"jump", &"slide"]
const SENSOR_SIZE := Vector3(0.4, 0.3, 0.4)

var tuning: MovementTuning
var geo: TrackGeometry
var god_mode: bool = false
var running: bool = false

var distance: float = 0.0
var speed: float = 0.0
var lane: int = 0
var surface: Surface = Surface.FLOOR
## Distance from the current surface: height above the floor, depth below the hull, or height on a wall.
var h: float = 0.0
## Velocity away from the current surface.
var vh: float = 0.0
var grounded: bool = true
var in_pit: bool = false
var alive: bool = true
## The level clock: seconds since the run started.
var elapsed: float = 0.0
var wall_side: int = 0
var last_event: String = ""

var _x: float = 0.0
var _switch_from: float = 0.0
var _switch_to: float = 0.0
var _switch_t: float = 1.0
var _boost: float = 0.0
var _jump_buffer: float = 0.0
var _coyote: float = 0.0
var _slide_left: float = 0.0
var _slide_on_land: bool = false
var _wall_t: float = 0.0
var _wall_h0: float = 0.0
var _wall_entry_x: float = 0.0
var _wall_entry_h: float = 0.0
var _roll: float = 0.0
var _queued: Array[StringName] = []

var _pivot: Node3D
var _body: MeshInstance3D
var _visor: MeshInstance3D
var _hurt_debug: MeshInstance3D
var _shadow: MeshInstance3D
var _hazard_shape := BoxShape3D.new()
var _hazard_query := PhysicsShapeQueryParameters3D.new()
var _trigger_shape := BoxShape3D.new()
var _trigger_query := PhysicsShapeQueryParameters3D.new()
var _ray := PhysicsRayQueryParameters3D.new()


func _ready() -> void:
	_build_nodes()
	_hazard_query.shape = _hazard_shape
	_hazard_query.collide_with_areas = true
	_hazard_query.collide_with_bodies = false
	_hazard_query.collision_mask = TrackBuilder.LAYER_HAZARD
	_trigger_query.shape = _trigger_shape
	_trigger_query.collide_with_areas = true
	_trigger_query.collide_with_bodies = false
	_trigger_query.collision_mask = TrackBuilder.LAYER_TRIGGER


func setup(p_tuning: MovementTuning, p_geo: TrackGeometry, start_lane: int) -> void:
	tuning = p_tuning
	geo = p_geo
	distance = 0.0
	elapsed = 0.0
	speed = tuning.run_speed
	lane = start_lane
	_x = geo.lane_x(lane)
	_switch_t = 1.0
	surface = Surface.FLOOR
	h = 0.0
	vh = 0.0
	grounded = true
	in_pit = false
	alive = true
	wall_side = 0
	_boost = 0.0
	_jump_buffer = 0.0
	_coyote = 0.0
	_slide_left = 0.0
	_slide_on_land = false
	_roll = 0.0
	_queued.clear()
	last_event = ""
	_body.material_override = GreyboxMaterials.flat(GreyboxMaterials.PLAYER)
	_apply_transform(1.0)


func is_sliding() -> bool:
	return _slide_left > 0.0


## Feeds one named action. Used by _unhandled_input and by tests.
func press(action: StringName) -> void:
	if alive and running:
		_queued.append(action)


func surface_name() -> String:
	return ["floor", "ceiling", "wall"][surface]


func set_hitbox_visible(on: bool) -> void:
	_hurt_debug.visible = on


func _unhandled_input(event: InputEvent) -> void:
	for action: StringName in ACTIONS:
		if event.is_action_pressed(action):
			press(action)


func _physics_process(delta: float) -> void:
	if not alive or not running or tuning == null:
		return
	elapsed += delta
	_jump_buffer -= delta
	_coyote -= delta
	_slide_left -= delta
	_boost = move_toward(_boost, 0.0, tuning.ramp_boost_decay_per_second * delta)
	speed = tuning.run_speed + tuning.speed_gain_per_minute * elapsed / 60.0 + _boost
	var motion: float = speed * delta
	distance += motion

	_consume_input()
	if surface == Surface.WALL:
		_update_wall(delta)
	else:
		_update_lane_switch(delta)
		_update_vertical(delta)
	if not alive:
		return
	_apply_transform(delta)
	_check_triggers(motion)
	_check_hazards(motion)


# --- Input -----------------------------------------------------------------

func _consume_input() -> void:
	for action: StringName in _queued:
		match action:
			&"move_left":
				_on_move(-1)
			&"move_right":
				_on_move(1)
			&"jump":
				_jump_buffer = tuning.jump_buffer_time
			&"slide":
				_on_slide()
	_queued.clear()


func _on_move(dir: int) -> void:
	match surface:
		Surface.WALL:
			# DESIGN-TBD: moving back toward the lanes while on a wall acts as a wall jump.
			if dir == -wall_side:
				_leave_wall(tuning.wall_jump_velocity, &"wall_jump")
		Surface.FLOOR:
			if in_pit:
				return
			var target: int = lane + dir
			if target < 0 or target >= geo.lane_count:
				_try_enter_wall(dir, false)
			else:
				_start_switch(target)
		Surface.CEILING:
			# DESIGN-TBD: no way from the ceiling onto a wall; the move is ignored at the edge.
			var target: int = clampi(lane + dir, 0, geo.lane_count - 1)
			if target != lane:
				_start_switch(target)


func _on_slide() -> void:
	if surface == Surface.WALL:
		return  # DESIGN-TBD: the slide action on a wall does nothing yet.
	if grounded:
		_slide_left = tuning.slide_duration
		_event(&"slide")
	elif tuning.air_slide_fast_fall and not in_pit:
		vh = minf(vh, -tuning.fast_fall_speed)
		_slide_on_land = true
		_event(&"slide")


func _event(kind: StringName) -> void:
	last_event = String(kind)
	movement_event.emit(kind)


# --- Lanes -----------------------------------------------------------------

func _start_switch(target: int) -> void:
	lane = target
	_switch_from = _x
	_switch_to = geo.lane_x(target)
	_switch_t = 0.0


func _update_lane_switch(delta: float) -> void:
	if _switch_t >= 1.0:
		return
	_switch_t = minf(1.0, _switch_t + delta / tuning.lane_switch_time)
	var k: float = 1.0 - (1.0 - _switch_t) * (1.0 - _switch_t)
	_x = lerpf(_switch_from, _switch_to, k)


# --- Floor & ceiling -------------------------------------------------------

func _update_vertical(delta: float) -> void:
	if grounded and not _has_support():
		grounded = false
		_coyote = tuning.coyote_time

	if _jump_buffer > 0.0 and (grounded or _coyote > 0.0) and not in_pit:
		vh = tuning.jump_velocity()
		grounded = false
		_coyote = 0.0
		_jump_buffer = 0.0
		_slide_left = 0.0
		_event(&"jump")

	if grounded:
		h = 0.0
		vh = 0.0
		return

	var gravity: float = tuning.gravity() * (tuning.fall_gravity_multiplier if vh < 0.0 else 1.0)
	vh -= gravity * delta
	h += vh * delta
	if vh > 0.0 or h > 0.0:
		return
	if not in_pit and h > -tuning.pit_depth and _has_support():
		_land()
	elif surface == Surface.CEILING:
		_flip(Surface.FLOOR, 0.0)
		_event(&"hull_end")
	else:
		if h < -tuning.pit_depth:
			in_pit = true
		if h < -tuning.fall_death_depth:
			_die("fell")


func _land() -> void:
	h = 0.0
	vh = 0.0
	grounded = true
	_event(&"land")
	if _slide_on_land:
		_slide_on_land = false
		_slide_left = tuning.slide_duration


## Swaps between floor and ceiling while keeping the player's world height and velocity.
func _flip(to: Surface, extra_velocity: float) -> void:
	h = tuning.ceiling_height - h
	vh = -vh - extra_velocity
	surface = to
	grounded = false
	_slide_left = 0.0
	_slide_on_land = false


func _has_support() -> bool:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var on_floor: bool = surface == Surface.FLOOR
	var plane_y: float = 0.0 if on_floor else tuning.ceiling_height
	var toward: float = -1.0 if on_floor else 1.0
	_ray.collision_mask = TrackBuilder.LAYER_FLOOR if on_floor else TrackBuilder.LAYER_HULL
	var z: float = TrackGeometry.world_z(distance)
	for ox: float in [-tuning.foot_half_width, tuning.foot_half_width]:
		for oz: float in [-tuning.foot_half_depth, tuning.foot_half_depth]:
			_ray.from = Vector3(_x + ox, plane_y - toward * 0.6, z + oz)
			_ray.to = Vector3(_x + ox, plane_y + toward * 0.3, z + oz)
			if not space.intersect_ray(_ray).is_empty():
				return true
	return false


# --- Walls -----------------------------------------------------------------

func _try_enter_wall(side: int, from_ramp: bool) -> bool:
	if surface != Surface.FLOOR or in_pit:
		return false
	if not grounded and h < 0.0 and _coyote <= 0.0:
		return false  # Already dropping into a gap; like a jump, the wall is out of reach.
	if _wall_blocked(side):
		# DESIGN-TBD: blocked-entry feedback (only a sound for now).
		_event(&"wall_blocked")
		return false
	surface = Surface.WALL
	wall_side = side
	_wall_t = 0.0
	_wall_entry_x = _x
	_wall_entry_h = maxf(h, 0.0)
	var target: float = tuning.ramp_entry_height if from_ramp \
		else tuning.wall_entry_height + _wall_entry_h * tuning.wall_air_entry_factor
	_wall_h0 = minf(target, tuning.wall_max_height)
	vh = 0.0
	grounded = false
	_jump_buffer = 0.0
	_slide_left = 0.0
	_slide_on_land = false
	_switch_t = 1.0
	if from_ramp:
		_boost += tuning.ramp_speed_boost
	_event(&"ramp" if from_ramp else &"wall_enter")
	return true


func _wall_blocked(side: int) -> bool:
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.5, 20.0, tuning.hurtbox_size.z + 0.4)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = TrackBuilder.LAYER_WALL_BLOCKER
	query.transform = Transform3D(Basis.IDENTITY, Vector3(side * (geo.wall_x() - 0.3), 5.0, TrackGeometry.world_z(distance)))
	return not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _update_wall(delta: float) -> void:
	_wall_t += delta
	var wall_x: float = wall_side * geo.wall_x()
	if _wall_t < tuning.wall_entry_time:
		var k: float = 1.0 - pow(1.0 - _wall_t / tuning.wall_entry_time, 2.0)
		_x = lerpf(_wall_entry_x, wall_x, k)
		h = lerpf(_wall_entry_h, _wall_h0, k)
	else:
		_x = wall_x
		var s: float = clampf((_wall_t - tuning.wall_entry_time) / tuning.wall_slide_time, 0.0, 1.0)
		h = tuning.wall_exit_height + (_wall_h0 - tuning.wall_exit_height) * (1.0 - pow(s, tuning.wall_descent_exponent))
		if s >= 1.0:
			_leave_wall(0.0, &"wall_exit")
			return
	if _jump_buffer > 0.0:
		_jump_buffer = 0.0
		_leave_wall(tuning.wall_jump_velocity, &"wall_jump")


func _leave_wall(velocity: float, kind: StringName) -> void:
	surface = Surface.FLOOR
	_start_switch(geo.lane_count - 1 if wall_side > 0 else 0)
	vh = velocity
	grounded = false
	_event(kind)


# --- Triggers & hazards ----------------------------------------------------

## Pads and ramps under the feet, swept back over this frame's motion.
func _check_triggers(motion: float) -> void:
	if surface != Surface.FLOOR or not grounded:
		return
	_trigger_shape.size = SENSOR_SIZE + Vector3(0.0, 0.0, motion)
	_trigger_query.transform = Transform3D(Basis.IDENTITY, position + Vector3(0.0, SENSOR_SIZE.y * 0.5, motion * 0.5))
	for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(_trigger_query, 4):
		var area := hit["collider"] as Area3D
		match area.get_meta(&"kind", &""):
			&"pad":
				_flip(Surface.CEILING, tuning.antigrav_launch_velocity)
				_event(&"pad")
				return
			&"ramp":
				if _try_enter_wall(int(area.get_meta(&"side")), true):
					return


## The damage hitbox as it is now, stretched back over this frame's motion: any hazard
## the body passed through since the last frame counts as a real contact.
func _check_hazards(motion: float) -> void:
	var height: float = _hurtbox_height()
	_hazard_shape.size = Vector3(tuning.hurtbox_size.x, height, tuning.hurtbox_size.z + motion)
	var basis := Basis(Vector3.BACK, _roll)
	_hazard_query.transform = Transform3D(basis, position + basis * Vector3(0.0, height * 0.5, motion * 0.5))
	for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(_hazard_query, 8):
		var hazard := hit["collider"] as Hazard
		if hazard != null and DamageRules.resolve(hazard, god_mode) == DamageRules.Outcome.KILL:
			_die(hazard.hazard_name)
			return


func _hurtbox_height() -> float:
	return tuning.hurtbox_slide_height if is_sliding() else tuning.hurtbox_size.y


func _die(cause: String) -> void:
	alive = false
	_body.material_override = GreyboxMaterials.flat(GreyboxMaterials.PLAYER_DEAD)
	_event(&"died")
	last_event = "died: " + cause
	died.emit(cause)


# --- Presentation ----------------------------------------------------------

func _apply_transform(delta: float) -> void:
	var y: float = h
	var roll_target: float = 0.0
	match surface:
		Surface.CEILING:
			y = tuning.ceiling_height - h
			roll_target = PI
		Surface.WALL:
			roll_target = wall_side * PI * 0.5
	position = Vector3(_x, y, TrackGeometry.world_z(distance))
	_roll = lerp_angle(_roll, roll_target, 1.0 - exp(-22.0 * delta))
	_pivot.rotation.z = _roll

	var height: float = _hurtbox_height()
	_hurt_debug.scale = Vector3(tuning.hurtbox_size.x, height, tuning.hurtbox_size.z)
	_hurt_debug.position.y = height * 0.5
	var vis: Vector3 = tuning.visual_size
	var vis_h: float = vis.y * (height / tuning.hurtbox_size.y)
	_body.scale = Vector3(vis.x, vis_h, vis.z)
	_body.position.y = vis_h * 0.5
	_visor.position = Vector3(0.0, vis_h * 0.8, -vis.z * 0.5)
	_update_shadow()


## A blob shadow on the surface below (or above, on the ceiling) to read height and gaps.
## Over a gap there's no surface, so no shadow, which is itself a cue.
func _update_shadow() -> void:
	if surface == Surface.WALL or not is_inside_tree():
		_shadow.visible = false
		return
	var on_floor: bool = surface == Surface.FLOOR
	var plane_y: float = 0.0 if on_floor else tuning.ceiling_height
	_ray.collision_mask = TrackBuilder.LAYER_FLOOR if on_floor else TrackBuilder.LAYER_HULL
	var away: float = 1.0 if on_floor else -1.0
	_ray.from = position + Vector3(0.0, away * 0.1, 0.0)
	_ray.to = Vector3(position.x, plane_y - away * 0.5, position.z)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(_ray)
	_shadow.visible = not hit.is_empty()
	if hit.is_empty():
		return
	var gap: float = absf(position.y - plane_y)
	var s: float = clampf(1.0 - gap / 6.0, 0.35, 1.0)
	_shadow.global_position = Vector3(position.x, plane_y + (0.02 if on_floor else -0.02), position.z)
	_shadow.scale = Vector3(s, 1.0, s)


func _build_nodes() -> void:
	_pivot = Node3D.new()
	add_child(_pivot)

	_body = MeshInstance3D.new()
	_body.mesh = GreyboxMaterials.unit_box()
	_body.material_override = GreyboxMaterials.flat(GreyboxMaterials.PLAYER)
	_pivot.add_child(_body)

	_visor = GreyboxMaterials.add_box(_pivot, Vector3.ZERO, Vector3(0.6, 0.15, 0.05), GreyboxMaterials.glow(GreyboxMaterials.VISOR, 3.0))

	_hurt_debug = MeshInstance3D.new()
	_hurt_debug.mesh = GreyboxMaterials.unit_box()
	_hurt_debug.material_override = GreyboxMaterials.debug_hitbox()
	_hurt_debug.visible = false
	_pivot.add_child(_hurt_debug)

	var disc := CylinderMesh.new()
	disc.top_radius = 0.45
	disc.bottom_radius = 0.45
	disc.height = 0.01
	disc.radial_segments = 16
	_shadow = MeshInstance3D.new()
	_shadow.mesh = disc
	_shadow.material_override = GreyboxMaterials.overlay(GreyboxMaterials.SHADOW, false)
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shadow.top_level = true
	add_child(_shadow)
