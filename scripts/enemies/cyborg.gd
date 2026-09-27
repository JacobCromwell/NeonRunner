class_name Cyborg
extends Enemy
## The cyborg (GDD §9.2): a humanoid standing on the floor lanes (the truck roofs), a ragged gangster
## whose whole head is a screen showing its LED face (CyborgBody, CyborgSuit), with an arm cannon
## (CyborgGun: a visible charge-up with a sound, bursts of 2–3 loosely aimed laser bolts, a reload
## pause).
## - Normal: walks slowly toward the player, stopping to shoot, and drops behind quickly once passed.
## - Panic variant (about 1 in 3, rolled by the generator: params.panic): freezes with a shocked "O"
##   face when the player comes near, then runs away ahead of them, firing wildly over its shoulder,
##   and cowers once it runs out of room.
## - Host (params.host, feature `host`, GDD §9.7): its screen glitches purple and purple veins glow
##   along its neck and arms. Auto-fire never targets it and missile splash never hurts it; killing
##   it earns a big bonus and releases the Bad Dream.
## Killed by a stomp on the head, weapons, claws or the dash: a stompable top over the head and a
## solid body (both slightly smaller than the visuals, and the body stops below the stomp line, so a
## player dropping onto the head only ever touches the head).
## Movement never takes it within obstacle_margin of a gap, fence, ramp, pad, speed pad or a
## ceiling's landing zone (CyborgRules.obstacle_spans). It may stand under a ceiling (GDD §3: the
## floor there may be dangerous) and holds fire while the player rides the ceiling (_may_attack).
## Scaling (GDD §6): health, reload time and bolt speed come from early/late values in
## data/enemies/cyborg.tres and the level's enemy_scaling.
##
## Spawn params: panic (bool), host (bool), fires (bool, default true; tests), health (float).

enum Mode { WAIT, WALK, STARTLED, FLEE, COWER, PASSED }

const Kit = preload("res://scripts/enemies/cyborg_kit.gd")
const CyborgRules = preload("res://scripts/enemies/cyborg_rules.gd")
const BAD_DREAM_SCRIPT: String = "res://scripts/enemies/bad_dream.gd"
## The solid body: slimmer than the visual torso and legs (arms included), and ending at 1.0 m, below
## the stomp line (the head's top minus GameRules.stomp_tolerance).
const BODY_SIZE := Vector3(0.4, 1.0, 0.28)
## The stompable head and shoulders (1.12–1.5 m). It starts above a standing player's hurtbox
## (1.09 m), so only a jumping player can touch it: wider than the head for a forgiving stomp.
const HEAD_SIZE := Vector3(0.7, 0.38, 0.6)
const HEAD_Y: float = 1.31

var tuning: CyborgTuning
var body: CyborgBody
var gun: CyborgGun
var lane: int = 0
var is_panic: bool = false
var mode: Mode = Mode.WAIT
## Where the generator placed it (track distance).
var home: float = 0.0
## The closest it may walk toward the player, and the furthest a panic run may take it.
var walk_limit: float = 0.0
var run_limit: float = 0.0

## Speed along the track: + = forward (away from the player).
var _speed: float = 0.0
var _startle: float = 0.0
var _yaw: float = 0.0


func _build() -> void:
	tuning = tuning_res as CyborgTuning
	if tuning == null:
		tuning = CyborgTuning.new()
	var p: Dictionary = spawn.get("params", {})
	is_host = bool(p.get("host", false))
	display_name = "host cyborg" if is_host else "cyborg"
	if p.has("health"):
		max_health = float(p["health"])
	lane = clampi(int(spawn.get("lane", 0)), 0, world.geo.lane_count - 1)
	home = float(spawn.get("at", 0.0))
	position = world.lane_point(lane, home)
	if p.has("panic"):
		is_panic = bool(p["panic"])
	else:
		is_panic = not is_host and rng.randf() < tuning.panic_chance
	add_hitbox(&"body", BODY_SIZE, Vector3(0.0, BODY_SIZE.y * 0.5, 0.0))
	add_hitbox(&"top", HEAD_SIZE, Vector3(0.0, HEAD_Y, 0.0))
	body = CyborgBody.new()
	body.name = "Body"
	add_child(body)
	body.build(world.skin.enemy_variant, is_host, false, int(spawn.get("seed", 0)))
	gun = CyborgGun.new(self, world, tuning, rng, body)
	gun.wild = is_panic
	gun.wild_spread = tuning.panic_spread
	gun.enabled = bool(p.get("fires", true))
	gun.may_attack = _may_attack
	_compute_limits()
	health_changed.connect(func(_e: Enemy) -> void: body.flash())


func _tick(delta: float) -> void:
	var player: Player = world.player
	var d: float = track_distance()
	var ahead: float = d - player.distance
	if mode != Mode.PASSED and ahead < -0.5:
		_enter(Mode.PASSED)
	match mode:
		Mode.WAIT:
			_speed = 0.0
			if is_panic:
				if ahead <= tuning.panic_trigger_distance and player.alive:
					_enter(Mode.STARTLED)
			elif ahead <= tuning.walk_start_distance:
				_enter(Mode.WALK)
		Mode.WALK:
			_speed = 0.0 if gun.is_attacking() or d <= walk_limit + 0.01 else -tuning.walk_speed
		Mode.STARTLED:
			_speed = 0.0
			_startle -= delta
			if _startle <= 0.0:
				_enter(Mode.FLEE if run_limit > d + 0.5 else Mode.COWER)
		Mode.FLEE:
			_speed = tuning.panic_speed
			if d >= run_limit - 0.01:
				_enter(Mode.COWER)
		Mode.COWER:
			_speed = 0.0
		Mode.PASSED:
			_speed = -tuning.drop_back_speed
	var next: float = d + _speed * delta
	if mode != Mode.PASSED:
		next = clampf(next, minf(walk_limit, d), maxf(run_limit, d))
	position.z = TrackGeometry.world_z(next)
	gun.track_velocity = _speed
	if mode != Mode.PASSED:
		gun.update(delta)
	_update_body(delta)


func aim_point() -> Vector3:
	return global_position + Vector3(0.0, 0.85, 0.0)


func hit_radius() -> float:
	return 0.55


func _on_defeated(cause: StringName) -> void:
	gun.stop()
	world.play_sfx_at(&"enemy_death", global_position)
	# The screen head blowing out: sparks in the face's cold white (never the player's copper).
	world.effects.burst(aim_point(), Kit.LED_COLOR, 20, 0.7)
	if is_host:
		_release_bad_dream()
	body.death_finished.connect(queue_free)
	body.die(cause)


## GDD §9.7: killing a host is a deliberate choice that earns a big bonus, then the Bad Dream bursts
## out of it. The Bad Dream is spawned only once its script exists.
func _release_bad_dream() -> void:
	world.score.add_bonus(&"host", tuning.host_bonus, "Host")
	world.play_sfx_at(&"bad_dream_emerge", aim_point())
	world.effects.burst(aim_point(), Kit.GLITCH_COLOR, 36, 1.2)
	if ResourceLoader.exists(BAD_DREAM_SCRIPT):
		var entry := {"type": "bad_dream", "at": track_distance(), "lane": lane, "side": 0,
			"seed": hash([spawn.get("seed", 0), "bad_dream"]), "params": {"from_host": true}}
		# Deferred: this can run inside a loop over the director's enemies (a weapon hit).
		world.director.spawn.call_deferred(entry)


func _may_attack() -> bool:
	var player: Player = world.player
	if not player.alive or not player.running or player.surface == Player.Surface.CEILING:
		return false
	if mode == Mode.PASSED or mode == Mode.STARTLED or (is_panic and mode == Mode.WAIT):
		return false
	var ahead: float = track_distance() - player.distance
	return ahead > 0.0 and ahead <= tuning.engage_distance


func _enter(next: Mode) -> void:
	mode = next
	match next:
		Mode.STARTLED:
			_startle = tuning.panic_startle_time
		Mode.PASSED:
			gun.stop()


## Keeps the walk and the panic run clear of every obstacle (GDD §9 fairness) and of every ceiling's
## landing zone (GDD §3: the floor there is safe to land on).
func _compute_limits() -> void:
	var margin: float = tuning.obstacle_margin
	walk_limit = home - tuning.walk_max
	run_limit = minf(home + tuning.panic_run_max, world.layout.length - margin)
	var zones := CeilingZones.make(world.config, world.tuning)
	for s: Vector2 in CyborgRules.obstacle_spans(world.layout, world.tuning, zones):
		if s.y <= home:
			walk_limit = maxf(walk_limit, s.y + margin)
		elif s.x >= home:
			run_limit = minf(run_limit, s.x - margin)
		else:
			walk_limit = home
			run_limit = home
	walk_limit = minf(walk_limit, home)
	run_limit = maxf(run_limit, home)


func _update_body(delta: float) -> void:
	var attacking: bool = gun.is_attacking()
	var yaw: float = PI if mode == Mode.FLEE else 0.0
	_yaw = lerp_angle(_yaw, yaw, 1.0 - exp(-10.0 * delta))
	body.rotation.y = _yaw
	match mode:
		Mode.FLEE:
			body.set_pose(CyborgBody.Pose.RUN_AWAY)
			body.set_move_speed(tuning.panic_speed)
		Mode.COWER:
			body.set_pose(CyborgBody.Pose.AIM if attacking else CyborgBody.Pose.COWER)
		Mode.WALK, Mode.WAIT:
			if attacking:
				body.set_pose(CyborgBody.Pose.AIM)
			else:
				body.set_pose(CyborgBody.Pose.WALK if absf(_speed) > 0.01 else CyborgBody.Pose.IDLE)
			body.set_move_speed(absf(_speed))
		_:
			body.set_pose(CyborgBody.Pose.IDLE)
	var face: Kit.Face = Kit.Face.NEUTRAL
	if is_panic and mode != Mode.WAIT:
		face = Kit.Face.SHOCKED
	elif attacking:
		face = Kit.Face.AIMING
	if face != body.face:
		body.set_expression(face)
