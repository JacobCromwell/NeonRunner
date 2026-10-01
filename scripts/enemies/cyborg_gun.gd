class_name CyborgGun
extends RefCounted
## The cyborgs' arm cannon (GDD §9.2), shared by floor and window cyborgs. A burst is:
## 1. a visible charge-up (the arm cannon glows up, CyborgBody.set_charge) with the cyborg_charge
##    sound: the telegraph, which always comes first (CLAUDE.md readability rules);
## 2. 2–3 laser bolts through ProjectilePool.fire_enemy (the pool's red enemy look). The aim locks
##    when the charge-up ends: each bolt flies to where a player keeping that line would be when it
##    arrives, give or take a little (loosely aimed), so switching lanes after the charge-up dodges
##    the whole burst. The panic variant fires wildly instead: every bolt at a random spot around
##    the player;
## 3. a reload pause.
##
## Fairness (GDD §9 shared rules): a burst only starts, and a bolt only fires, if
## - the shooter is ahead of the player and within engage_distance (never from behind or out of
##   sight), and the enemy's own may_attack() agrees (e.g. not at a player on the ceiling);
## - each bolt needs at least min_warning_time to arrive;
## - the player's path around every bolt's arrival is free of fences and gaps in all lanes, so a
##   burst is never timed onto a jump or a full-lane fence;
## - no other cyborg's burst is in the air (one attacker at a time, via RunWorld metadata).
## Everything runs in the physics step from the enemy's seeded random stream, so every attempt at a
## seed plays out the same way.

enum State { READY, CHARGING, FIRING, RELOADING }

## RunWorld metadata: the level time until which a cyborg's burst owns the air.
const AIRSPACE_META: StringName = &"cyborg_airspace_until"
const SHOT_NAME: String = "cyborg bolt"
const LOOK: StringName = &"enemy_bolt"
## Pause after a cancelled charge before trying again.
const RETRY_PAUSE: float = 0.35

var shooter: Enemy
var world: RunWorld
var tuning: CyborgGunTuning
var rng: RandomNumberGenerator
## The shooter's model, which shows the telegraph: a CyborgBody, or another enemy's (GunModel).
var body: GunModel
## Wild fire (the panic variant): each bolt goes to a random spot around the player, up to
## wild_spread sideways.
var wild: bool = false
var wild_spread: float = 2.0
var enabled: bool = true
## The charge-up's and each bolt's sounds, and the bolts' name (a death's cause): the cyborgs' own
## unless the shooter has its own (the Barnacle Turret, GDD §9.8).
var charge_sound: StringName = &"cyborg_charge"
var shot_sound: StringName = &"cyborg_shot"
var shot_name: String = SHOT_NAME
## The shooter's own rule for the player's path around a bolt's arrival, in place of the floor's
## (path_clear): Callable(from_d: float, to_d: float) -> bool. Unset for the cyborgs; the Barnacle
## Turret, which fires only at a ceiling rider, sets one for the ceiling (GDD §9.8).
var path_rule: Callable
## Where bolts leave the cannon, from the enemy's origin (gameplay: the visual cannon animates, the
## shots never depend on it). Bolts start muzzle_reach further along their line.
var muzzle_offset: Vector3 = Vector3(0.0, 1.12, 0.0)
var muzzle_reach: float = 0.45
## The shooter's own speed along the track (m/s, + = forward, away from the player), for predictions.
var track_velocity: float = 0.0
## Returns whether the shooter may attack right now (the enemy's own rules).
var may_attack: Callable
var state: State = State.READY
## Every charge, shot and cancelled burst (for tests and debugging): {"t" (level time),
## "event": &"charge" | &"shot" | &"cancel", "player_d" and "shooter_d" (track distances); charges
## add "shots"; shots add "impact" (track distance), "arrive" (level time), "from", "velocity"}.
var events: Array[Dictionary] = []

var _timer: float = 0.0
var _shots_left: int = 0
var _burst: int = 0
var _lock := Vector2.ZERO


func _init(p_shooter: Enemy, p_world: RunWorld, p_tuning: CyborgGunTuning, p_rng: RandomNumberGenerator,
		p_body: GunModel) -> void:
	shooter = p_shooter
	world = p_world
	tuning = p_tuning
	rng = p_rng
	body = p_body


## Charging or firing a burst (the enemy shows its aiming pose and face).
func is_attacking() -> bool:
	return state == State.CHARGING or state == State.FIRING


## Runs the cannon for one physics frame.
func update(delta: float) -> void:
	if not enabled or world == null or world.player == null:
		return
	var player: Player = world.player
	match state:
		State.READY:
			_timer -= delta
			if _timer <= 0.0 and _allowed() and _airspace_free() and _burst_fair(tuning.charge_time, tuning.burst_max):
				_start_charge()
		State.CHARGING:
			_timer += delta
			body.set_charge(_timer / tuning.charge_time)
			_aim_body(player)
			if not _allowed():
				_cancel()
			elif _timer >= tuning.charge_time:
				if _burst_fair(0.0, _burst):
					_lock_aim(player)
					state = State.FIRING
					_timer = 0.0
					_fire_step(delta)
				else:
					_cancel()
		State.FIRING:
			_aim_body(player)
			_fire_step(delta)
		State.RELOADING:
			_timer -= delta
			if _timer <= 0.0:
				state = State.READY
				_timer = 0.0


## Stops everything at once (the enemy was defeated or left play).
func stop() -> void:
	if state == State.CHARGING or state == State.FIRING:
		_release_airspace()
	state = State.READY
	enabled = false
	body.set_charge(0.0)
	body.clear_aim()


## Seconds until a bolt fired from `from` at `speed` meets a target at `target` that runs toward -z at
## `v` (the player). -1 if it never does.
static func intercept_time(from: Vector3, target: Vector3, v: float, speed: float) -> float:
	var d: Vector3 = target - from
	var a: float = v * v - speed * speed
	var b: float = -2.0 * v * d.z
	var c: float = d.length_squared()
	if absf(a) < 1e-6:
		return c / -b if b < 0.0 else -1.0
	var disc: float = b * b - 4.0 * a * c
	if disc < 0.0:
		return -1.0
	var root: float = sqrt(disc)
	var best: float = -1.0
	for t: float in [(-b - root) / (2.0 * a), (-b + root) / (2.0 * a)]:
		if t > 0.0 and (best < 0.0 or t < best):
			best = t
	return best


func _allowed() -> bool:
	return shooter.alive and (not may_attack.is_valid() or bool(may_attack.call()))


func _airspace_free() -> bool:
	return world.level_time() >= float(world.get_meta(AIRSPACE_META, -1.0e9))


func _release_airspace() -> void:
	world.set_meta(AIRSPACE_META, world.level_time())


func _start_charge() -> void:
	state = State.CHARGING
	_timer = 0.0
	_burst = rng.randi_range(tuning.burst_min, maxi(tuning.burst_min, tuning.burst_max))
	_shots_left = _burst
	world.set_meta(AIRSPACE_META, world.level_time() + tuning.charge_time
		+ (_burst - 1) * tuning.shot_interval + tuning.burst_gap)
	var at: Vector3 = _muzzle_base()
	world.play_sfx_at(charge_sound, at)
	events.append({"t": world.level_time(), "event": &"charge", "shots": _burst,
		"player_d": world.player.distance, "shooter_d": shooter.track_distance(), "from": at})


func _cancel() -> void:
	state = State.READY
	_timer = RETRY_PAUSE
	_release_airspace()
	body.set_charge(0.0)
	body.clear_aim()
	events.append({"t": world.level_time(), "event": &"cancel", "player_d": world.player.distance,
		"shooter_d": shooter.track_distance()})


func _fire_step(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	var player: Player = world.player
	if _shots_left > 0 and _allowed() and _time_to_player(player) >= tuning.min_warning_time * 0.5:
		_fire(player)
		_shots_left -= 1
		_timer = tuning.shot_interval
		body.set_charge(float(_shots_left) / float(maxi(_burst, 1)))
	else:
		_shots_left = 0
	if _shots_left <= 0:
		state = State.RELOADING
		_timer = tuning.reload_at(_scaling())
		body.set_charge(0.0)
		body.clear_aim()


func _lock_aim(player: Player) -> void:
	var c: Vector3 = player.hurtbox_aabb().get_center()
	_lock = Vector2(c.x + rng.randf_range(-tuning.aim_error, tuning.aim_error), c.y)


## One bolt: aimed where the player will be when it arrives (on the locked line, or wild).
func _fire(player: Player) -> void:
	var c: Vector3 = player.hurtbox_aabb().get_center()
	var target := Vector3(_lock.x, _lock.y, c.z)
	if wild:
		target.x = c.x + rng.randf_range(-wild_spread, wild_spread)
		target.y = maxf(0.25, c.y + rng.randf_range(-0.45, 0.7))
	else:
		target.x += rng.randf_range(-tuning.shot_jitter, tuning.shot_jitter)
		target.y += rng.randf_range(-tuning.shot_jitter, tuning.shot_jitter) * 0.5
	var speed: float = tuning.bolt_speed_at(_scaling())
	var v: float = player.speed
	var base: Vector3 = _muzzle_base()
	var t: float = intercept_time(base, target, v, speed)
	if t <= 0.0:
		return
	var aim: Vector3 = target + Vector3(0.0, 0.0, -v * t)
	var from: Vector3 = base + (aim - base).normalized() * muzzle_reach
	t = intercept_time(from, target, v, speed)
	if t <= 0.0:
		return
	aim = target + Vector3(0.0, 0.0, -v * t)
	var velocity: Vector3 = (aim - from).normalized() * speed
	world.projectiles.fire_enemy(from, velocity, LOOK, shot_name, tuning.bolt_life)
	world.play_sfx_at(shot_sound, from)
	events.append({"t": world.level_time(), "event": &"shot", "impact": player.distance + v * t,
		"arrive": world.level_time() + t, "from": from, "velocity": velocity,
		"player_d": player.distance, "shooter_d": shooter.track_distance()})


## Whether a burst of `shots` bolts, the first fired `lead` seconds from now, would be fair: the first
## bolt gives at least min_warning_time and no bolt arrives near a fence or gap.
func _burst_fair(lead: float, shots: int) -> bool:
	var player: Player = world.player
	var v: float = player.speed
	var speed: float = tuning.bolt_speed_at(_scaling())
	var c: Vector3 = player.hurtbox_aabb().get_center()
	for k: int in maxi(shots, 1):
		var tau: float = lead + k * tuning.shot_interval
		var from: Vector3 = _muzzle_base() + Vector3(0.0, 0.0, -track_velocity * tau)
		var target: Vector3 = c + Vector3(0.0, 0.0, -v * tau)
		var t: float = intercept_time(from, target, v, speed)
		if t <= 0.0:
			return false
		if k == 0 and t < tuning.min_warning_time:
			return false
		var impact: float = player.distance + v * (tau + t)
		if not path_clear(impact - tuning.clear_before_impact, impact + tuning.clear_after_impact):
			return false
	return true


## True if the player's path between two track distances has no live fence and no gap in any lane
## (and, for a player on a wall, no sign on that wall). A shooter's own path_rule decides instead.
func path_clear(from_d: float, to_d: float) -> bool:
	if path_rule.is_valid():
		return bool(path_rule.call(from_d, to_d))
	var layout: LevelLayout = world.layout
	for f: Dictionary in layout.fences:
		var at: float = f["at"]
		if at >= from_d and at <= to_d and not f.get("disabled", false):
			return false
	for g: Dictionary in layout.gaps:
		if g["start"] <= to_d and g["end"] >= from_d:
			return false
	var player: Player = world.player
	if player.surface == Player.Surface.WALL:
		for s: Dictionary in layout.signs:
			if int(s["side"]) == player.wall_side and s["start"] <= to_d and s["end"] >= from_d:
				return false
	return true


## Seconds a bolt fired now would need to reach the player (-1 if it can't).
func _time_to_player(player: Player) -> float:
	return intercept_time(_muzzle_base(), player.hurtbox_aabb().get_center(), player.speed,
		tuning.bolt_speed_at(_scaling()))


## Points the body's cannon at the player while charging, then along the locked line while firing.
func _aim_body(player: Player) -> void:
	var c: Vector3 = player.hurtbox_aabb().get_center()
	var t: float = maxf(_time_to_player(player), 0.0)
	var aim := Vector3(c.x, c.y, c.z - player.speed * t)
	if state == State.FIRING and not wild:
		aim.x = _lock.x
		aim.y = _lock.y
	body.aim_at(aim)


func _muzzle_base() -> Vector3:
	return shooter.global_position + muzzle_offset


func _scaling() -> float:
	return world.config.enemy_scaling if world.config != null else 0.0
