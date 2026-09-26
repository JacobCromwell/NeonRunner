class_name Player
extends Node3D
## Kinematic runner controller covering the floor, both side walls and the ceiling.
## Lanes are movement targets only. Support comes from physics rays against floor and hull
## bodies. Hazard and trigger contact comes from shape queries on the current frame, swept
## over the distance run this frame so nothing is skipped at speed. DamageRules resolves hits.
## Input arrives only as named actions (keyboard via the InputMap, touch via TouchInput).
## Every contact goes through receive_hit(), which asks DamageRules what happens; the player's
## protection (armor, shield, grapple, claws, the invulnerability window, the dash) lives here.

signal died(cause: String)
## Something happened that feedback (sound, HUD) may react to: jump, land, slide, wall_enter,
## wall_jump, wall_exit, wall_blocked, ramp, pad, hull_end, died, stomp, lane_blocked, speed_pad,
## grapple, armor_break, shield_break, revive, dash, dash_end.
signal movement_event(kind: StringName)
## A protective item was used up: &"armor", &"shield" or &"grapple".
signal item_used(item: StringName)
## The player's contact defeated an enemy (cause: &"stomp", &"claws" or &"dash").
signal enemy_contact(enemy: Enemy, cause: StringName)
signal revived

enum Surface { FLOOR, CEILING, WALL }

const ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"jump", &"slide"]
const SENSOR_SIZE := Vector3(0.4, 0.3, 0.4)

var tuning: MovementTuning
var geo: TrackGeometry
## Game-wide rules (stomp bounce, invulnerability windows, ...). A default copy if none is set.
var rules: GameRules
var god_mode: bool = false
var running: bool = false

# Protection, set from the run's loadout (GDD §8). Breakable items are single charges.
var armor: int = 0
var shield: int = 0
var grapples: int = 0
var claws: bool = false
## Wall-run time multiplier (claws give longer wall runs, GDD §8).
var wall_time_multiplier: float = 1.0
## Seconds of invulnerability left (after a block or a revive; the character flashes).
var invulnerable_left: float = 0.0
var dashing: bool = false
## Accessibility (reduced flashing): the invulnerability tint holds steady instead of flickering.
var steady_flash: bool = false

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
var _bumping: bool = false
var _dash_left: float = 0.0
var _dash_bonus: float = 0.0
var _last_speed_pad: int = 0
var _death_cause: String = ""
var _blocker_shape := BoxShape3D.new()
var _blocker_query := PhysicsShapeQueryParameters3D.new()

var _pivot: Node3D
var _avatar: PlayerAvatar  # Avatar
var _avatar_landed: bool = false  # Avatar: a "land" event since the last avatar update
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
	_blocker_query.shape = _blocker_shape
	_blocker_query.collide_with_areas = true
	_blocker_query.collide_with_bodies = false
	_blocker_query.collision_mask = TrackBuilder.LAYER_LANE_BLOCKER


func setup(p_tuning: MovementTuning, p_geo: TrackGeometry, start_lane: int) -> void:
	tuning = p_tuning
	geo = p_geo
	if rules == null:
		rules = GameRules.new()
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
	_bumping = false
	invulnerable_left = 0.0
	dashing = false
	_dash_left = 0.0
	_dash_bonus = 0.0
	_last_speed_pad = 0
	_death_cause = ""
	last_event = ""
	_avatar.reset()  # Avatar
	_apply_transform(1.0)


## Protection for this run (GDD §8): breakable items are single charges that break when used.
func apply_loadout(p_armor: int, p_shield: int, p_grapples: int, p_claws: bool, p_wall_time_multiplier: float = 1.0) -> void:
	armor = p_armor
	shield = p_shield
	grapples = p_grapples
	claws = p_claws
	wall_time_multiplier = p_wall_time_multiplier
	_avatar.set_equipment({"armor": armor > 0, "shield": shield > 0, "claws": claws})


func is_invulnerable() -> bool:
	return invulnerable_left > 0.0


## What protects the player right now, for DamageRules.
func defense() -> DamageRules.Defense:
	var d := DamageRules.Defense.new()
	d.armor = armor > 0
	d.shield = shield > 0
	d.invulnerable = invulnerable_left > 0.0
	d.claws = claws
	d.dashing = dashing
	d.god_mode = god_mode
	return d


## Resolves one contact with a hazard (obstacle, enemy hitbox or projectile) and applies the
## outcome. `stomping`: the player is dropping onto it from above. Returns the outcome.
func receive_hit(hazard: Hazard, stomping: bool = false) -> DamageRules.Outcome:
	if not alive:
		return DamageRules.Outcome.IGNORE
	var d: DamageRules.Defense = defense()
	var outcome: DamageRules.Outcome = DamageRules.resolve(hazard, d, stomping)
	match outcome:
		DamageRules.Outcome.BLOCKED_ARMOR:
			armor -= 1
			invulnerable_left = rules.hit_invulnerability
			_avatar.set_equipment({"armor": armor > 0})
			item_used.emit(&"armor")
			_event(&"armor_break")
		DamageRules.Outcome.BLOCKED_SHIELD:
			shield -= 1
			invulnerable_left = rules.hit_invulnerability
			_avatar.set_equipment({"shield": shield > 0})
			item_used.emit(&"shield")
			_event(&"shield_break")
		DamageRules.Outcome.STOMP, DamageRules.Outcome.DEFEAT_ENEMY:
			var cause: StringName = DamageRules.defeat_cause(outcome, d)
			if outcome == DamageRules.Outcome.STOMP:
				vh = rules.stomp_bounce_velocity
				grounded = false
				_slide_left = 0.0
				_event(&"stomp")
			hazard.enemy.defeat(cause)
			enemy_contact.emit(hazard.enemy, cause)
		DamageRules.Outcome.KILL:
			_die(hazard.hazard_name)
	if outcome != DamageRules.Outcome.IGNORE:
		hazard.contacted.emit(outcome)
	return outcome


## Brings the player back where they died (GDD §4: revive item or rewarded ad), invulnerable for
## a moment. A player who fell is pulled back up like the grapple hook.
func revive() -> void:
	if alive:
		return
	alive = true
	_show_dead(false)
	invulnerable_left = rules.revive_invulnerability
	if _death_cause == "fell" or in_pit:
		in_pit = false
		h = maxf(h, -tuning.pit_depth)
		vh = rules.grapple_pull_velocity
		grounded = false
	_event(&"revive")
	revived.emit()


## The juggernaut dash (GDD §8): passes through hazards for `duration` seconds, `speed_bonus` faster.
## Cooldowns belong to the power-up that calls this.
func start_dash(duration: float, speed_bonus: float) -> void:
	if not alive:
		return
	dashing = true
	_dash_left = duration
	_dash_bonus = speed_bonus
	_event(&"dash")


## The damage hitbox in world space, as it is now (projectiles test against it).
func hurtbox_aabb() -> AABB:
	var height: float = _hurtbox_height()
	var hx: float = tuning.hurtbox_size.x * 0.5
	var hz: float = tuning.hurtbox_size.z * 0.5
	match surface:
		Surface.CEILING:
			return AABB(position + Vector3(-hx, -height, -hz), Vector3(hx * 2.0, height, hz * 2.0))
		Surface.WALL:
			var x0: float = position.x - height if wall_side > 0 else position.x
			return AABB(Vector3(x0, position.y - hx, position.z - hz), Vector3(height, hx * 2.0, hz * 2.0))
	return AABB(position + Vector3(-hx, 0.0, -hz), Vector3(hx * 2.0, height, hz * 2.0))


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
	invulnerable_left = maxf(invulnerable_left - delta, 0.0)
	if dashing:
		_dash_left -= delta
		if _dash_left <= 0.0:
			dashing = false
			_dash_bonus = 0.0
			_event(&"dash_end")
	_boost = move_toward(_boost, 0.0, tuning.ramp_boost_decay_per_second * delta)
	speed = tuning.run_speed + tuning.speed_gain_per_minute * elapsed / 60.0 + _boost + _dash_bonus
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
	if target != lane and _lane_blocked(target):
		# GDD §9.3: a solid side (the hover truck's) bumps the player back.
		_bumping = true
		_switch_from = geo.lane_x(lane)
		_switch_to = geo.lane_x(target)
		_switch_t = 0.0
		_event(&"lane_blocked")
		return
	_bumping = false
	lane = target
	_switch_from = _x
	_switch_to = geo.lane_x(target)
	_switch_t = 0.0


func _update_lane_switch(delta: float) -> void:
	if _switch_t >= 1.0:
		return
	_switch_t = minf(1.0, _switch_t + delta / tuning.lane_switch_time)
	if _bumping:
		# Out toward the blocked lane and back again.
		var reach: float = rules.lane_bump_fraction * (1.0 - absf(2.0 * _switch_t - 1.0))
		_x = lerpf(_switch_from, _switch_to, reach)
		if _switch_t >= 1.0:
			_bumping = false
			_x = _switch_from
		return
	var k: float = 1.0 - (1.0 - _switch_t) * (1.0 - _switch_t)
	_x = lerpf(_switch_from, _switch_to, k)


## True if a solid side (a lane blocker) fills `target` lane beside the player right now.
func _lane_blocked(target: int) -> bool:
	if target < 0 or target >= geo.lane_count:
		return false
	var height: float = _hurtbox_height()
	var y: float = position.y + height * 0.5 if surface != Surface.CEILING else position.y - height * 0.5
	_blocker_shape.size = Vector3(geo.lane_width * 0.5, height, tuning.hurtbox_size.z + 0.6)
	_blocker_query.transform = Transform3D(Basis.IDENTITY, Vector3(geo.lane_x(target), y, TrackGeometry.world_z(distance)))
	return not get_world_3d().direct_space_state.intersect_shape(_blocker_query, 1).is_empty()


# --- Floor & ceiling -------------------------------------------------------

func _update_vertical(delta: float) -> void:
	if grounded:
		var ground: float = _support_top()
		if is_nan(ground):
			grounded = false
			_coyote = tuning.coyote_time
		else:
			h = ground  # Follows moving platforms (a hover truck's roof).

	if _jump_buffer > 0.0 and (grounded or _coyote > 0.0) and not in_pit:
		vh = tuning.jump_velocity()
		grounded = false
		_coyote = 0.0
		_jump_buffer = 0.0
		_slide_left = 0.0
		_event(&"jump")

	if grounded:
		vh = 0.0
		return

	var gravity: float = tuning.gravity() * (tuning.fall_gravity_multiplier if vh < 0.0 else 1.0)
	vh -= gravity * delta
	h += vh * delta
	if vh > 0.0:
		return
	# Land on whatever surface is under the feet (the track, or a raised one like a truck roof), but
	# never climb back out of a pit.
	var top: float = _support_top()
	if not in_pit and not is_nan(top) and h <= top and h > top - tuning.pit_depth:
		_land(top)
		return
	if h > 0.0:
		return
	if surface == Surface.CEILING:
		_flip(Surface.FLOOR, 0.0)
		_event(&"hull_end")
	else:
		if h < -tuning.pit_depth and not in_pit:
			if grapples > 0:
				_use_grapple()
				return
			in_pit = true
		if h < -tuning.fall_death_depth:
			_die("fell")


## GDD §8: the grapple hook saves the player from one fall, then breaks.
func _use_grapple() -> void:
	grapples -= 1
	h = -tuning.pit_depth
	vh = rules.grapple_pull_velocity
	grounded = false
	item_used.emit(&"grapple")
	_event(&"grapple")


func _land(top: float = 0.0) -> void:
	h = top
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


## The height (away from the current surface, like `h`) of the highest supporting surface under the
## player's footprint, from 0.6 m above the feet to 0.3 m below; NAN if there is none. On the floor
## that's the track (0) or a raised surface such as a hover truck's roof; on the ceiling, the hull.
func _support_top() -> float:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var on_floor: bool = surface == Surface.FLOOR
	_ray.collision_mask = TrackBuilder.LAYER_FLOOR if on_floor else TrackBuilder.LAYER_HULL
	var z: float = TrackGeometry.world_z(distance)
	var best: float = NAN
	for ox: float in [-tuning.foot_half_width, tuning.foot_half_width]:
		for oz: float in [-tuning.foot_half_depth, tuning.foot_half_depth]:
			_ray.from = Vector3(_x + ox, _surface_y(h + 0.6), z + oz)
			_ray.to = Vector3(_x + ox, _surface_y(h - 0.3), z + oz)
			var hit: Dictionary = space.intersect_ray(_ray)
			if not hit.is_empty():
				var top: float = (hit["position"] as Vector3).y if on_floor else tuning.ceiling_height - (hit["position"] as Vector3).y
				best = top if is_nan(best) else maxf(best, top)
	return best


## World y of a point `height` away from the current surface (floor or ceiling).
func _surface_y(height: float) -> float:
	return height if surface != Surface.CEILING else tuning.ceiling_height - height


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
		var s: float = clampf((_wall_t - tuning.wall_entry_time) / (tuning.wall_slide_time * wall_time_multiplier), 0.0, 1.0)
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
			&"speed_pad":
				if area.get_instance_id() != _last_speed_pad:
					_last_speed_pad = area.get_instance_id()
					_boost += tuning.speed_pad_boost
					_event(&"speed_pad")


## The damage hitbox as it is now, stretched back over this frame's motion: any hazard
## the body passed through since the last frame counts as a real contact.
func _check_hazards(motion: float) -> void:
	var height: float = _hurtbox_height()
	_hazard_shape.size = Vector3(tuning.hurtbox_size.x, height, tuning.hurtbox_size.z + motion)
	var basis := Basis(Vector3.BACK, _roll)
	_hazard_query.transform = Transform3D(basis, position + basis * Vector3(0.0, height * 0.5, motion * 0.5))
	for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(_hazard_query, 8):
		var hazard := hit["collider"] as Hazard
		if hazard == null:
			continue
		receive_hit(hazard, _is_stomping(hazard))
		if not alive:
			return


## Dropping onto the hazard from above: on the floor, descending, feet near its top.
func _is_stomping(hazard: Hazard) -> bool:
	return surface == Surface.FLOOR and not grounded and vh <= 0.0 \
		and position.y >= hazard.top_y() - rules.stomp_tolerance


func _hurtbox_height() -> float:
	return tuning.hurtbox_slide_height if is_sliding() else tuning.hurtbox_size.y


func _die(cause: String) -> void:
	alive = false
	dashing = false
	_dash_bonus = 0.0
	_death_cause = cause
	_update_avatar(0.0)  # Avatar: starts the collapse (the avatar finishes it on its own).
	_event(&"died")
	last_event = "died: " + cause
	died.emit(cause)


## Revive: the model stands back up (the avatar plays the collapse itself on death).
func _show_dead(on: bool) -> void:
	if not on:
		_avatar.reset()


## The invulnerability window flicker (GDD §4: the character flashes): a bright tint on the suit,
## flickering, or held steady with the reduced-flashing setting.
func _update_flash() -> void:
	var on: bool = invulnerable_left > 0.0 and (steady_flash or int(invulnerable_left * 16.0) % 2 == 1)
	_avatar.set_flash(on)


## What the player model shows the player carrying (PlayerAvatar.set_equipment): claws, armor,
## shield, weapon_tier, magnet. RunWorld sets it from the loadout; broken items update it.
func set_equipment_look(eq: Dictionary) -> void:
	_avatar.set_equipment(eq)


## World position the shoulder weapon fires from (the model's emitter).
func weapon_muzzle() -> Vector3:
	return _avatar.weapon_muzzle()


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
	_update_flash()

	var height: float = _hurtbox_height()
	_hurt_debug.scale = Vector3(tuning.hurtbox_size.x, height, tuning.hurtbox_size.z)
	_hurt_debug.position.y = height * 0.5
	_update_avatar(delta)  # Avatar: sliding is a pose now, not a squashed box.
	_update_shadow()


## Avatar: hands the runner model this frame's movement state (see PlayerAvatar.animate).
func _update_avatar(delta: float) -> void:
	var switch_dir: int = int(signf(_switch_to - _switch_from)) if _switch_t < 1.0 else 0
	_avatar.fit_to(tuning.visual_size)
	_avatar.animate({
		"surface": surface_name(),
		"grounded": grounded,
		"vh": vh,
		"sliding": is_sliding(),
		"distance": distance,
		"speed": speed,
		"wall_side": wall_side,
		"switch_dir": switch_dir,
		"alive": alive,
		"dashing": dashing,
		"just_landed": _avatar_landed,
		"stomping": _slide_on_land and not grounded,  # DESIGN-TBD: the air-slide fast fall shows the stomp.
	}, delta)
	_avatar_landed = false


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

	# Avatar: the runner model replaces the grey-box body and visor.
	_avatar = PlayerAvatar.new()
	_pivot.add_child(_avatar)
	movement_event.connect(func(kind: StringName) -> void: _avatar_landed = _avatar_landed or kind == &"land")

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
