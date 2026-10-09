extends Enemy
## The heli drone (GDD §9.6): a futuristic drone with a rotor on each side and a gatling gun
## underneath.
## - Entrance: swoops in from the distance (drone_swoop) when the player reaches its layout spot.
## - Movement: hovers ahead of the player over their lane and follows them between lanes (over a
##   wall when they run on one). It keeps pace with the player, so its position is kept relative to
##   the player: `rel_x` (world x), `rel_y` (height) and `rel_ahead` (metres ahead).
## - Attack: it stops and winds up (drone_windup; the gatling spins up and glows, and a red aim
##   line tracks the player), then locks the player's position and fires a barrage down that line
##   (drone_fire), stationary, and moves again. A player who switches lanes once it starts firing
##   is safe; bullets are spaced so they can zigzag back through the stream, and the whole barrage
##   lands within the hit invulnerability window, so armor or a shield protects through all of it.
##   At a player on a wall it keeps firing (it leads the wall-run descent); while the player is on
##   the ceiling it waits.
## - Dash walls (task H7a; GDD §9.14): it rises over a standing one in its way and comes back down past it
##   (Enemy.dash_wall_lift, `lift`), and no wind-up starts while a wall is near enough that it would climb
##   before its barrage and cooldown are over (_doodad_in_reach), so it never fires on the climb. The barrage is a big attack (GDD §9): while another type's is on, the
##   drone keeps following and winds up once its turn comes (EnemyDirector.major_attack_blocked).
## - Kill: stepping on any anti-grav pad hurls every drone on screen up into the ship's hull
##   (drone_crash), over the lanes that ceiling covers (a narrow ceiling, GDD §3: it veers into the
##   ceiling's lanes as it rises); weapons take 17 laser tier 1 shots (health 15, stretched by
##   PowerupTuning.tier1_extra_shots), 5 missile tier 4 shots. Claws don't work, and it has no
##   contact hitbox: it only hurts through its bullets.
## - Persistence: stays until destroyed or the level ends (never retired).
## Spawn params: {"slot": 0 | 1}: slot 1 is the second drone of a wave, hovering further ahead and
## higher. Numbers: data/enemies/drone.tres (DroneTuning). Generator rules: drone_rules.gd.

const MeshBatch := preload("res://scripts/enemies/mesh_batch.gd")

enum State { WAITING, SWOOP, FOLLOW, WINDUP, FIRE, COOLDOWN, DOWN }

const SHOT_NAME: String = "drone gatling"
## A hurled drone crashes this far inside the edge of a narrow ceiling (about its half width).
const HURL_INSET: float = 0.8
## How fast a hurled drone speeds up toward the hull (m/s²), and how long it takes at most.
const HURL_ACCEL: float = 45.0
const HURL_MAX_TIME: float = 0.8
const EYE_COLOR := Color(1.0, 0.12, 0.08)
const HOT_COLOR := Color(1.0, 0.38, 0.1)
## Its fireballs (RunEffects.fireball, radius in metres): a small one when it's hit and starts to spin down,
## a big one where it crashes (GDD §11: every explosion is a yellow-and-red fireball).
const FIRE_HIT_SIZE: float = 1.0
const FIRE_CRASH_SIZE: float = 2.4

## Models per zone variant, built once: {body, rotor, barrels} ArrayMeshes.
static var _models: Dictionary = {}

var state: State = State.WAITING
var tune: DroneTuning
var slot: int = 0
var rel_x: float = 0.0
var rel_y: float = 0.0
var rel_ahead: float = 0.0
## Barrages started and bullets fired (tests and the debug HUD read these).
var barrages: int = 0
var bullets_fired: int = 0

var _at: float = 0.0
var _scaling: float = 0.0
var _state_time: float = 0.0
var _follow_left: float = 0.0
var _lat_v: float = 0.0
var _swoop_from := Vector3.ZERO
## The locked target: world x and height. `_lock_wall` is the wall side for a wall target, else 0.
var _lock := Vector2.ZERO
var _lock_wall: int = 0
var _shots_left: int = 0
var _shot_timer: float = 0.0
var _pending_shots: int = 0
var _bullet_speed: float = 16.0
var _interval: float = 0.18
var _ground_h: float = 0.0
var _prev_h: float = 0.0
var _prev_surface: int = -1
var _player_vh: float = 0.0
## Seconds the player has been on their current wall (-1 = not seen entering it).
var _wall_time: float = -1.0
var _spin_speed: float = 0.0
var _bob_t: float = 0.0
var _down_cause: StringName = &""
var _down_v: float = 0.0
## Hurled by a pad: the world x it veers to as it rises, inside the lanes of the ceiling the player is
## going up to, from the x it started at, over the time its rise takes (_hurl_time).
var _hurl_x: float = 0.0
var _hurl_from: float = 0.0
var _hurl_time: float = 0.0
var _flash_left: float = 0.0
## Metres it has risen over its hover height to clear a dash wall in its way (task H7a; Enemy.dash_wall_lift),
## and back to 0 past it. Its hurl or its fall starts from where it is, lift and all.
var lift: float = 0.0

var _pivot: Node3D
var _rotors: Array[MeshInstance3D] = []
var _gun: Node3D
var _barrels: MeshInstance3D
var _barrel_hot: Material
var _muzzle: Node3D
var _flash: MeshInstance3D
var _aim_line: MeshInstance3D


func _build() -> void:
	tune = tuning_res as DroneTuning if tuning_res is DroneTuning else DroneTuning.new()
	display_name = "heli drone"
	claw_immune = true  # GDD §9.6: claws don't work.
	# No contact hitbox (it flies out of reach; GDD §9.6 names only its bullets), so touching,
	# stomping or dashing into it does nothing (FB 86).
	if not (tuning_res is EnemyTuning):
		max_health = tune.health_early
		score_value = tune.score_value
	var params: Dictionary = spawn.get("params", {})
	slot = int(params.get("slot", 0))
	_at = float(spawn.get("at", 0.0))
	_scaling = world.config.enemy_scaling if world.config != null else 0.0
	_bob_t = rng.randf() * TAU
	_build_model()
	# Not in play until it swoops in.
	visible = false
	immune_to_weapons = true
	position = Vector3(0.0, -40.0, TrackGeometry.world_z(_at))
	world.player.movement_event.connect(_on_player_event)


func _physics_process(delta: float) -> void:
	if state == State.DOWN:
		_update_down(delta)
	else:
		super(delta)


func _tick(delta: float) -> void:
	var p: Player = world.player
	_state_time += delta
	_bob_t += delta
	_track_player(p, delta)
	match state:
		State.WAITING:
			if p.distance < _at:
				return
			_start_swoop(p)
		State.SWOOP:
			_update_swoop(p, delta)
		State.FOLLOW:
			_update_follow(p, delta)
		State.WINDUP:
			_update_windup(p, delta)
		State.FIRE:
			_update_fire(p, delta)
		State.COOLDOWN:
			_lat_v = move_toward(_lat_v, 0.0, 30.0 * delta)
			if _state_time >= tune.cooldown:
				_enter_follow(tune.follow_time_at(_scaling) + rng.randf_range(-0.25, 0.25))
	_update_lift(p, delta)
	_place(p, delta)
	while _pending_shots > 0:
		_pending_shots -= 1
		_fire_bullet(p)


## GDD §9.6: stays until destroyed or the level ends.
func should_retire() -> bool:
	return false


func targetable() -> bool:
	return super() and state != State.WAITING


func aim_point() -> Vector3:
	return global_position


func hit_radius() -> float:
	return 0.85 * tune.model_scale


## In play and within sight of the player: an anti-grav pad hurls it into the hull.
func on_screen() -> bool:
	# "On screen" = swooped in, from 12 m behind the player to 120 m ahead (FB 88).
	return alive and state != State.WAITING and rel_ahead > -12.0 and rel_ahead < 120.0


# --- Behaviour ---------------------------------------------------------------------------------

func _track_player(p: Player, delta: float) -> void:
	if p.surface == Player.Surface.FLOOR and p.grounded:
		_ground_h = p.h
	if p.surface == Player.Surface.WALL and _prev_surface == Player.Surface.WALL:
		_player_vh = (p.h - _prev_h) / maxf(delta, 0.0001)
		if _wall_time >= 0.0:
			_wall_time += delta
	elif p.surface == Player.Surface.WALL:
		_player_vh = 0.0
		_wall_time = delta if _prev_surface != -1 else -1.0
	else:
		_player_vh = 0.0
		_wall_time = -1.0
	_prev_h = p.h
	_prev_surface = p.surface


func _hover_ahead() -> float:
	return tune.hover_ahead + slot * tune.wave_spacing


## Its body's half length along the track (metres), for the dash walls it rises over.
func _half_length() -> float:
	return 1.0 * tune.model_scale


## Rises over a standing dash wall in its way, and back down past it (task H7a; Enemy.dash_wall_lift), in
## every state: the wind-up never starts where it would climb (_doodad_in_reach).
func _update_lift(p: Player, delta: float) -> void:
	if state == State.WAITING:
		return
	var need: float = dash_wall_lift(p.distance + rel_ahead, _half_length(), rel_y, maxf(p.speed, 1.0))
	lift = move_toward(lift, maxf(need - rel_y, 0.0), DASH_WALL_CLIMB_SPEED * delta)


func _hover_height() -> float:
	return tune.hover_height + slot * tune.wave_rise


## The x it follows: the player's lane, or just inside the wall they run on.
func _follow_x(p: Player) -> float:
	if p.surface == Player.Surface.WALL:
		return p.wall_side * (world.geo.wall_x() - tune.wall_inset)
	return world.geo.lane_x(p.lane)


func _start_swoop(p: Player) -> void:
	state = State.SWOOP
	_state_time = 0.0
	visible = true
	immune_to_weapons = false
	var from_side: float = -1.0 if rng.randf() < 0.5 else 1.0
	_swoop_from = Vector3(_follow_x(p) + from_side * tune.swoop_side, tune.swoop_height,
		_hover_ahead() + tune.swoop_distance)
	rel_x = _swoop_from.x
	rel_y = _swoop_from.y
	rel_ahead = _swoop_from.z
	# The warning plays from where the swoop is heading, so it's heard at full volume.
	world.play_sfx_at(&"drone_swoop", _world_point(p, _follow_x(p), _hover_height(), _hover_ahead() + 8.0))


func _update_swoop(p: Player, delta: float) -> void:
	var k: float = clampf(_state_time / tune.swoop_time, 0.0, 1.0)
	var e: float = 1.0 - pow(1.0 - k, 2.2)
	var end := Vector3(_follow_x(p), _hover_height(), _hover_ahead())
	var ctrl := Vector3(lerpf(_swoop_from.x, end.x, 0.85), end.y - 0.9, lerpf(_swoop_from.z, end.z, 0.4))
	var a: Vector3 = _swoop_from.lerp(ctrl, e)
	var b: Vector3 = ctrl.lerp(end, e)
	var pos: Vector3 = a.lerp(b, e)
	_lat_v = (pos.x - rel_x) / maxf(delta, 0.0001)
	rel_x = pos.x
	rel_y = pos.y
	rel_ahead = pos.z
	if k >= 1.0:
		_enter_follow(tune.first_follow_time + slot * 1.2)


func _enter_follow(seconds: float) -> void:
	state = State.FOLLOW
	_state_time = 0.0
	_follow_left = seconds
	_aim_line.visible = false


func _update_follow(p: Player, delta: float) -> void:
	var tx: float = _follow_x(p)
	var want_v: float = clampf((tx - rel_x) * 5.0, -tune.follow_speed, tune.follow_speed)
	_lat_v = move_toward(_lat_v, want_v, 40.0 * delta)
	rel_x += _lat_v * delta
	rel_ahead = move_toward(rel_ahead, _hover_ahead(), 8.0 * delta)
	rel_y = move_toward(rel_y, _hover_height(), 3.0 * delta)
	_follow_left -= delta
	if _follow_left > 0.0 or not _can_attack(p) or _barrage_busy():
		return
	# Settle over the lane first (it waits no more than 1.5 s for a player who keeps moving).
	if absf(rel_x - tx) >= 0.35 and _follow_left >= -1.5:
		return
	# GDD §3: never at a player a zone doodad hems in (asked before its turn, so it never holds one).
	if _doodad_in_reach(p):
		return
	# GDD §9.7: no barrage starts while the Cyborg's Bad Dream chases; GDD §9: nor while another
	# type's big attack is on (it keeps following and waits for its turn).
	if world.director.major_attack_blocked(self):
		return
	_start_windup(p)


func _can_attack(p: Player) -> bool:
	return p.alive and p.running and p.surface != Player.Surface.CEILING


## GDD §3 (zone doodads): a barrage is never fired at a player a doodad hems in (its side blocks the
## dodge, its push moves them into the stream). True while a doodad stands, in any lane, along the
## stretch the player runs from now until a barrage started now would have passed them: its wind-up,
## its bullets and their flight. The generator keeps doodads off a wave until its first pad, so this
## holds back only a drone that outlived its pads. DESIGN-TBD (docs/questions/g5.md 5).
## A dash wall counts as a doodad does (LevelLayout.doodad_between, in every lane), and further for the drone's
## own way (task H7a): none whose face it would start climbing to (Enemy.dash_wall_lift) before its wind-up,
## barrage and cooldown are over, so it never fires on the climb. Broken walls count too, as doodads do, so
## it holds the same on every attempt.
func _doodad_in_reach(p: Player) -> bool:
	if world.layout.doodads.is_empty() and world.layout.dash_walls.is_empty():
		return false
	var window: float = world.rules.hit_invulnerability if world.rules != null else 1.0
	var flight: float = _hover_ahead() / maxf(tune.bullet_speed_at(_scaling), 1.0) + tune.bullet_overshoot
	var seconds: float = tune.windup_at(_scaling) + tune.barrage_count(_scaling, window) * tune.bullet_interval_at(_scaling) \
		+ flight
	var run: float = maxf(p.speed, 1.0)
	if world.layout.doodad_between(p.distance - 1.0, p.distance + run * seconds):
		return true
	if world.layout.dash_walls.is_empty():
		return false
	var top: float = world.tuning.dash_wall_height + DASH_WALL_CLEARANCE
	var climb: float = maxf(top - _hover_height(), 0.0) / DASH_WALL_CLIMB_SPEED * run + _half_length()
	return world.layout.dash_wall_between(p.distance - 1.0,
		p.distance + _hover_ahead() + run * (seconds + tune.cooldown) + climb)


## A wind-up and its barrage are a big attack (GDD §9, §9.7): the Cyborg's Bad Dream never slashes
## during one, and while big attacks take turns another type's doesn't start until its bullets have
## passed the player (EnemyDirector.major_attack_blocked, note_attack_shot).
func is_major_attack_active() -> bool:
	return alive and (state == State.WINDUP or state == State.FIRE)


## Only one drone winds up or fires at a time, so two barrages never cross.
func _barrage_busy() -> bool:
	# DESIGN-TBD: one barrage at a time when several drones are in play.
	for e: Enemy in world.director.active:
		if e == self or not is_instance_valid(e) or not e.alive or e.get_script() != get_script():
			continue
		var s: int = int(e.get(&"state"))
		if s == State.WINDUP or s == State.FIRE:
			return true
	return false


func _start_windup(p: Player) -> void:
	state = State.WINDUP
	_state_time = 0.0
	_lat_v = 0.0
	world.play_sfx_at(&"drone_windup", global_position)
	_aim_line.visible = true


## Where the barrage would go now: the player's spot at running height (a jump doesn't move the
## aim), or their spot on a wall.
func _live_target(p: Player) -> Vector3:
	var half: float = world.tuning.hurtbox_size.y * 0.5
	if p.surface == Player.Surface.WALL:
		return Vector3(p.wall_side * (world.geo.wall_x() - half), p.h, p.position.z)
	return Vector3(p.position.x, _ground_h + half, p.position.z)


## Locks the barrage onto the player's position as firing starts; the stream stays there.
func _lock_target(p: Player) -> void:
	# DESIGN-TBD: the aim tracks the player through the wind-up and locks when firing starts, so a
	# lane switch once it fires dodges the whole barrage (GDD §9.6 only asks for zigzag spacing).
	var target: Vector3 = _live_target(p)
	_lock = Vector2(target.x, target.y)
	_lock_wall = p.wall_side if p.surface == Player.Surface.WALL else 0


func _update_windup(p: Player, _delta: float) -> void:
	if not _can_attack(p):
		_abort()
		return
	var windup: float = tune.windup_at(_scaling)
	var k: float = clampf(_state_time / windup, 0.0, 1.0)
	_spin_speed = lerpf(3.0, 40.0, k * k)
	_barrels.material_override = _barrel_hot if k > 0.45 else null
	if _state_time >= windup:
		_start_fire(p)


func _start_fire(p: Player) -> void:
	state = State.FIRE
	_state_time = 0.0
	_lock_target(p)
	_interval = tune.bullet_interval_at(_scaling)
	_bullet_speed = tune.bullet_speed_at(_scaling)
	var window: float = world.rules.hit_invulnerability if world.rules != null else 1.0
	_shots_left = tune.barrage_count(_scaling, window)
	_shot_timer = 0.0
	barrages += 1
	world.play_sfx_at(&"drone_fire", global_position)


func _update_fire(p: Player, delta: float) -> void:
	if not _can_attack(p):
		_end_barrage()  # The player went up to the ceiling (it waits) or died.
		return
	_shot_timer -= delta
	while _shot_timer <= 0.0 and _shots_left > 0:
		_pending_shots += 1
		_shots_left -= 1
		_shot_timer += _interval
	if _shots_left <= 0:
		_end_barrage()


func _end_barrage() -> void:
	state = State.COOLDOWN
	_state_time = 0.0
	_aim_line.visible = false


func _abort() -> void:
	_enter_follow(0.6)


## One bullet from the muzzle to the locked target, moving with the player: in the player's frame
## every bullet of a barrage flies the same line, so the stream stays in the locked lane.
func _fire_bullet(p: Player) -> void:
	var from: Vector3 = _muzzle.global_position
	var target: Vector3 = _target_point(p, from)
	var to: Vector3 = target - from
	var dist: float = to.length()
	if dist < 0.5:
		return
	var velocity: Vector3 = to / dist * _bullet_speed + Vector3(0.0, 0.0, -p.speed)
	var shot: Projectile = world.projectiles.fire_enemy(from, velocity, &"enemy_bullet", SHOT_NAME,
		dist / _bullet_speed + tune.bullet_overshoot)
	# The barrage's turn lasts until its bullets have passed the player (GDD §9).
	world.director.note_attack_shot(self, shot)
	bullets_fired += 1
	_flash_left = 0.05


func _target_point(p: Player, from: Vector3) -> Vector3:
	var y: float = _lock.y
	if _lock_wall != 0 and p.surface == Player.Surface.WALL and p.wall_side == _lock_wall:
		# DESIGN-TBD: it leads the wall-run descent so a player who stays on the wall is still hit
		# (GDD §9.6: it keeps firing at a player on a wall).
		var travel: float = from.distance_to(Vector3(_lock.x, p.h, p.position.z)) / _bullet_speed
		y = clampf(_predict_wall_height(p, travel), world.tuning.wall_exit_height, world.tuning.wall_max_height)
	return Vector3(_lock.x, y, p.position.z)


## The wall-runner's height `ahead` seconds from now. The descent follows MovementTuning's curve
## (Player._update_wall), so once the entry is over it can be extrapolated exactly from the time on
## the wall; otherwise the current vertical speed is used.
func _predict_wall_height(p: Player, ahead: float) -> float:
	var mt: MovementTuning = world.tuning
	var slide: float = mt.wall_slide_time * p.wall_time_multiplier
	var s: float = (_wall_time - mt.wall_entry_time) / maxf(slide, 0.001)
	if _wall_time < 0.0 or s <= 0.0 or s >= 1.0:
		return p.h + _player_vh * ahead
	var n: float = mt.wall_descent_exponent
	var drop: float = (p.h - mt.wall_exit_height) / maxf(1.0 - pow(s, n), 0.001)
	return mt.wall_exit_height + drop * (1.0 - pow(minf(s + ahead / slide, 1.0), n))


func _on_player_event(kind: StringName) -> void:
	if kind == &"pad" and on_screen():
		defeat(&"pad")


# --- Destroyed ---------------------------------------------------------------------------------

## A pad hurls it up into the hull; anything else (weapons) sends it spinning down. Either way it
## crashes with drone_crash a moment later.
func _on_defeated(cause: StringName) -> void:
	state = State.DOWN
	_state_time = 0.0
	_down_cause = cause
	_down_v = tune.hurl_speed if cause == &"pad" else 1.5
	rel_y += lift
	lift = 0.0
	if cause == &"pad":
		_hurl_from = rel_x
		_hurl_x = hurl_x(world, world.player, rel_x)
		var rise: float = maxf(world.tuning.ceiling_height - 0.35 - rel_y, 0.0)
		_hurl_time = clampf((-_down_v + sqrt(_down_v * _down_v + 2.0 * HURL_ACCEL * rise)) / HURL_ACCEL, 0.05, HURL_MAX_TIME)
	_aim_line.visible = false
	_flash.visible = false
	_pending_shots = 0
	# Hit: it bursts into flames and spins down (the crash is the big one).
	world.effects.fireball(global_position, FIRE_HIT_SIZE, false)


func _update_down(delta: float) -> void:
	var p: Player = world.player
	_state_time += delta
	if _down_cause == &"pad":
		_down_v += HURL_ACCEL * delta
		rel_y += _down_v * delta
		# Into the ceiling's lanes by the time it reaches the hull.
		var k: float = clampf(_state_time / _hurl_time, 0.0, 1.0)
		rel_x = lerpf(_hurl_from, _hurl_x, 1.0 - (1.0 - k) * (1.0 - k))
		_pivot.rotate_y(16.0 * delta)
		_pivot.rotation.x = minf(_pivot.rotation.x + 3.0 * delta, 0.9)
		if rel_y >= world.tuning.ceiling_height - 0.35 or _state_time > HURL_MAX_TIME:
			_crash()
			return
	else:
		_down_v -= 16.0 * delta
		rel_y += _down_v * delta
		rel_ahead -= 4.0 * delta
		_pivot.rotate_y(10.0 * delta)
		_pivot.rotation.z = minf(_pivot.rotation.z + 2.5 * delta, 1.2)
		if rel_y <= 0.45 or _state_time > 1.6:
			_crash()
			return
	for r: MeshInstance3D in _rotors:
		r.rotate_y(12.0 * delta)
	global_position = _world_point(p, rel_x, rel_y, rel_ahead)


## Where a drone at world x `x` crashes into the ceiling `player` is going up to (a pad hurls it,
## GDD §9.6): inside the lanes that ceiling covers (a narrow one, GDD §3), HURL_INSET from its edges;
## `x` itself under a ceiling over every lane, or with no ceiling of the track over the player (a
## boss's).
static func hurl_x(p_world: RunWorld, player: Player, x: float) -> float:
	var h: Dictionary = p_world.layout.hull_at(player.distance, player.lane)
	if h.is_empty():
		return x
	var lanes: Vector2i = p_world.layout.hull_lanes(h)
	var half: float = p_world.geo.lane_width * 0.5
	var lo: float = p_world.geo.lane_x(lanes.x) - half + HURL_INSET
	var hi: float = p_world.geo.lane_x(lanes.y) + half - HURL_INSET
	if lanes == Vector2i(0, p_world.layout.lane_count - 1):
		return x
	return clampf(x, lo, hi)


func _crash() -> void:
	var at: Vector3 = global_position
	world.play_sfx_at(&"drone_crash", at)
	world.effects.fireball(at, FIRE_CRASH_SIZE)
	world.effects.burst(at, Color(0.7, 0.75, 0.85), 16, 0.7)
	world.effects.shake(0.2, 0.25)
	queue_free()


# --- Presentation ------------------------------------------------------------------------------

func _world_point(p: Player, x: float, y: float, ahead: float) -> Vector3:
	return Vector3(x, y, TrackGeometry.world_z(p.distance + ahead))


func _place(p: Player, delta: float) -> void:
	var bob: float = sin(_bob_t * 2.3) * 0.07
	global_position = _world_point(p, rel_x, rel_y + lift + bob, rel_ahead)
	_pivot.rotation = Vector3(0.0, 0.0, clampf(-_lat_v * 0.05, -0.45, 0.45))
	_rotors[0].rotate_y(30.0 * delta)
	_rotors[1].rotate_y(-30.0 * delta)
	if state != State.WINDUP and state != State.FIRE:
		_spin_speed = move_toward(_spin_speed, 0.0, 30.0 * delta)
		if _spin_speed < 12.0:
			_barrels.material_override = null
	_barrels.rotate_z(_spin_speed * delta)
	var aim: Vector3 = _aim_target(p)
	if aim.distance_squared_to(_gun.global_position) > 0.25:
		_gun.look_at(aim, Vector3.UP)
	if _aim_line.visible:
		_update_aim_line(aim)
	_flash_left -= delta
	_flash.visible = _flash_left > 0.0


func _aim_target(p: Player) -> Vector3:
	if state == State.FIRE:
		return _target_point(p, _muzzle.global_position)
	if state == State.WINDUP:
		return _live_target(p)
	return p.hurtbox_aabb().get_center()


## The red aim line from the muzzle to the locked target, flickering faster as the wind-up ends
## (with Reduced flashing it thickens steadily instead).
func _update_aim_line(aim: Vector3) -> void:
	var from: Vector3 = _muzzle.global_position
	var d: Vector3 = aim - from
	var length: float = d.length()
	if length < 0.1:
		return
	var flicker: float = 1.0
	if state == State.WINDUP:
		var progress: float = clampf(_state_time / tune.windup_at(_scaling), 0.0, 1.0)
		if Settings.flashing_reduced:
			flicker = lerpf(0.55, 1.0, progress)
		else:
			flicker = 0.55 + 0.45 * absf(sin(_state_time * lerpf(6.0, 22.0, progress)))
	var up: Vector3 = Vector3.UP if absf(d.normalized().dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	_aim_line.global_transform = Transform3D(
		Basis.looking_at(d / length, up).scaled_local(Vector3(0.06 * flicker, 0.06 * flicker, length)),
		from + d * 0.5)


func _build_model() -> void:
	var parts: Dictionary = add_model(self, world.skin.enemy_variant if world.skin != null else &"city", tune.model_scale)
	_pivot = parts["pivot"]
	_rotors.assign(parts["rotors"])
	_gun = parts["gun"]
	_barrels = parts["barrels"]
	_barrel_hot = GreyboxMaterials.glow(HOT_COLOR, 3.5)
	_muzzle = Node3D.new()
	_muzzle.position = Vector3(0.0, 0.0, -0.7)
	_gun.add_child(_muzzle)
	_flash = GreyboxMaterials.add_box(_gun, Vector3(0.0, 0.0, -0.78), Vector3(0.24, 0.24, 0.34),
		GreyboxMaterials.glow(Color(1.0, 0.8, 0.4), 5.0))
	_flash.visible = false
	_aim_line = MeshInstance3D.new()
	_aim_line.mesh = GreyboxMaterials.unit_box()
	_aim_line.material_override = GreyboxMaterials.glow(EYE_COLOR, 3.0, 0.6)
	_aim_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_aim_line.top_level = true
	_aim_line.visible = false
	add_child(_aim_line)


## Its look alone, visual only, under `parent` (the drone itself, or a cinematic's prop): the body on a
## pivot scaled by `model_scale` (DroneTuning.model_scale), its two rotors and the gatling's mount and
## barrels. Returns {pivot, rotors: [left, right], gun, barrels}. `hostile` off draws it without its red
## (the eye and the band in a cold white and gold, no amber): the Golden Convergence's squadron, the heli
## drone's model "never coloured red" (GDD §10), the visuals of an attack rather than an enemy.
static func add_model(parent: Node3D, variant: StringName, model_scale: float, hostile: bool = true) -> Dictionary:
	var model: Dictionary = _model(variant, hostile)
	var pivot := Node3D.new()
	pivot.scale = Vector3.ONE * model_scale
	parent.add_child(pivot)
	var body := MeshInstance3D.new()
	body.mesh = model["body"]
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(body)
	var rotors: Array[MeshInstance3D] = []
	for sx: float in [-1.0, 1.0]:
		var r := MeshInstance3D.new()
		r.mesh = model["rotor"]
		r.position = Vector3(sx * 1.02, 0.32, -0.02)
		r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(r)
		rotors.append(r)
	var gun := Node3D.new()
	gun.position = Vector3(0.0, -0.36, 0.18)
	pivot.add_child(gun)
	var barrels := MeshInstance3D.new()
	barrels.mesh = model["barrels"]
	barrels.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gun.add_child(barrels)
	return {"pivot": pivot, "rotors": rotors, "gun": gun, "barrels": barrels}


## Low-poly model in local space: the drone faces +z (toward the player it hovers ahead of).
## Hostile read in every zone: red eye and a red-hot gatling when it winds up (enemy fire is red). Not
## `hostile` (add_model): the eye in a cold white and the band in unlit gold instead, no amber.
static func _model(variant: StringName, hostile: bool = true) -> Dictionary:
	var model_key: String = "%s|%s" % [variant, hostile]
	if _models.has(model_key):
		return _models[model_key]
	var scav: bool = variant == &"scavenger"
	var hull: Material = GreyboxMaterials.flat(Color(0.55, 0.36, 0.22) if scav else Color(0.46, 0.5, 0.62))
	var dark: Material = GreyboxMaterials.flat(Color(0.11, 0.11, 0.14))
	var trim: Material = GreyboxMaterials.flat(Color(0.3, 0.26, 0.22) if scav else Color(0.55, 0.6, 0.7))
	var eye: Material = GreyboxMaterials.glow(EYE_COLOR, 4.0) if hostile else GreyboxMaterials.glow(Color(0.82, 0.88, 1.0), 1.6)
	var band: Material = eye if hostile else GreyboxMaterials.flat(Color(0.78, 0.66, 0.42))
	var amber: Material = GreyboxMaterials.glow(Color(1.0, 0.62, 0.15), 3.0) if hostile \
		else GreyboxMaterials.glow(Color(1.0, 0.94, 0.84), 1.4)
	var thrust: Material = GreyboxMaterials.glow(Color(0.45, 0.75, 1.0), 2.5)

	var b := MeshBatch.new()
	b.box(hull, Vector3(0.0, 0.0, 0.0), Vector3(1.0, 0.4, 0.9))
	b.wedge(hull, Vector3(0.0, -0.03, 0.6), Vector3(0.9, 0.32, 0.34), Vector3(PI * 0.5, 0.0, 0.0))
	b.box(eye, Vector3(0.0, 0.12, 0.455), Vector3(0.6, 0.08, 0.03))
	# A red band around the hull: the hostile read from any side.
	b.box(band, Vector3(0.0, -0.1, 0.0), Vector3(1.02, 0.05, 0.92))
	b.box(dark, Vector3(0.0, 0.26, -0.06), Vector3(0.62, 0.14, 0.58))
	b.box(trim, Vector3(0.0, 0.35, -0.4), Vector3(0.08, 0.26, 0.26))
	for sx: float in [-1.0, 1.0]:
		b.box(dark, Vector3(sx * 0.73, 0.1, -0.02), Vector3(0.5, 0.08, 0.14))
		b.cylinder(hull, Vector3(sx * 1.02, 0.14, -0.02), Vector3(0.28, 0.34, 0.28))
		b.box(thrust, Vector3(sx * 1.02, -0.04, -0.02), Vector3(0.18, 0.04, 0.18))
		b.box(amber, Vector3(sx * 0.505, 0.02, 0.26), Vector3(0.03, 0.08, 0.2))
	b.box(dark, Vector3(0.0, -0.27, 0.1), Vector3(0.36, 0.16, 0.44))
	if scav:
		# Patched-together plates.
		b.box(trim, Vector3(0.24, 0.205, 0.16), Vector3(0.34, 0.02, 0.3), Vector3(0.0, 0.3, 0.0))
		b.box(trim, Vector3(-0.3, -0.12, 0.36), Vector3(0.3, 0.22, 0.04))
	var body: ArrayMesh = b.commit()

	var r := MeshBatch.new()
	var blade: Material = GreyboxMaterials.flat(Color(0.78, 0.8, 0.86))
	r.box(blade, Vector3.ZERO, Vector3(1.3, 0.025, 0.1))
	r.box(blade, Vector3.ZERO, Vector3(0.1, 0.025, 1.3))
	r.cylinder(dark, Vector3(0.0, 0.02, 0.0), Vector3(0.14, 0.07, 0.14))
	r.cylinder(GreyboxMaterials.glow(Color(0.85, 0.9, 1.0), 1.0, 0.22), Vector3(0.0, -0.005, 0.0), Vector3(1.36, 0.01, 1.36))
	var rotor: ArrayMesh = r.commit()

	# The gatling points along -z (look_at aims -z at the target) and spins about z.
	var g := MeshBatch.new()
	var metal: Material = GreyboxMaterials.flat(Color(0.22, 0.22, 0.26))
	for i: int in 4:
		var a: float = i * PI * 0.5 + PI * 0.25
		g.cylinder(metal, Vector3(cos(a) * 0.075, sin(a) * 0.075, -0.34), Vector3(0.065, 0.62, 0.065), Vector3(PI * 0.5, 0.0, 0.0))
	g.cylinder(metal, Vector3(0.0, 0.0, -0.6), Vector3(0.25, 0.05, 0.25), Vector3(PI * 0.5, 0.0, 0.0))
	g.cylinder(metal, Vector3(0.0, 0.0, -0.02), Vector3(0.24, 0.18, 0.24), Vector3(PI * 0.5, 0.0, 0.0))
	var barrels: ArrayMesh = g.commit()

	var out := {"body": body, "rotor": rotor, "barrels": barrels}
	_models[model_key] = out
	return out
