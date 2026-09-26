class_name TestBoss
extends BossEncounter
## The test boss (data/bosses/test_boss.tres; not in the campaign): a hovering core that exercises the
## whole boss framework for the tests and for reviews (`./play.sh --boss=test_boss`, debug builds).
## Its pattern, the same in every cycle of a phase (only the phase's pace speeds it up):
## 1. It hovers ahead of the player, drifting toward their lane.
## 2. Lane blast, a telegraphed attack: the eye glows up with the charge sound and the lane it will
##    strike lights up red; then a burst of bolts flies down that lane (leave it to dodge). A blast only
##    starts where every lane is free of holes and fences around the bolts' arrival.
## 3. After a few blasts, the stomp window: it drops into the player's lane ahead, dazed, with its red
##    weak point up. A stomp takes the phase (BossEncounter.hit_damage); running past it, it rises and
##    the cycle starts again. Weapons chip at it throughout, up to the boss's weapon cap.
## Phases: the second is a checkpoint; the third is faster and the lights go down (set_light_level).
## Numbers: TestBossTuning (data/bosses/test_boss_tuning.tres).

enum Step { HOVER, CHARGE, FIRE, COOLDOWN, DROP, DAZED, RISE }

const BODY_SCRIPT: Script = preload("res://scripts/bosses/test_boss_body.gd")
## The bolts fly at the height of a running player's chest.
const BOLT_HEIGHT: float = 0.75
const BOLT_NAME: String = "Test Core bolt"
## The lights in the last phase.
const FINAL_LIGHT: float = 0.65

var body: TestBossBody
var tuning: TestBossTuning
var step: Step = Step.HOVER
var step_time: float = 0.0
## Blasts in the current cycle.
var blasts: int = 0
var target_lane: int = 0
## Where the core lies dazed (track distance) during a stomp window.
var drop_spot: float = 0.0

var _warning: MeshInstance3D
var _bolts_left: int = 0
var _bolt_timer: float = 0.0
var _from: Vector3 = Vector3.ZERO
var _to: Vector3 = Vector3.ZERO
var _bob: float = 0.0


func _build_boss() -> void:
	tuning = def.tuning as TestBossTuning
	if tuning == null:
		tuning = TestBossTuning.new()
	body = add_part(BODY_SCRIPT) as TestBossBody
	body.position = _hover_point(world.geo.lane_x(lane_count() / 2))


# --- Phases ----------------------------------------------------------------------------

func _on_phase_started(index: int) -> void:
	_set_step(Step.HOVER)
	blasts = 0
	_clear_warning()
	body.set_charge(0.0)
	body.set_dazed(false)
	if index == 0 and carried_time <= 0.0:
		# The entrance: it swoops in from far ahead.
		_from = Vector3(0.0, 10.0, TrackGeometry.world_z(player_distance() + 140.0))
		world.play_sfx_at(&"drone_swoop", _from)
	else:
		# A phase change: it shakes free and rises back to its place.
		_from = body.position
		body.flash()
		world.play_sfx_at(&"truck_bang", body.global_position)
		world.effects.shake(0.25, 0.3)
	if is_final_phase():
		set_light_level(FINAL_LIGHT, 1.5)


func _intro_tick(delta: float) -> void:
	_bob += delta
	var k: float = smoothstep(0.0, 1.0, clampf(state_time / maxf(phase().intro_seconds, 0.05), 0.0, 1.0))
	var shake := Vector3.ZERO
	if phase_index > 0 and k < 0.6:
		shake = Vector3(sin(state_time * 53.0), cos(state_time * 47.0), 0.0) * 0.12 * (1.0 - k)
	body.position = _from.lerp(_hover_point(world.player.position.x), k) + shake


func _on_weak_point_hit(_part: BossPart, hazard: Hazard) -> void:
	body.flash()
	world.effects.burst(hazard.global_position, TestBossBody.WEAK_COLOR, 36, 1.0)
	world.effects.shake(0.3, 0.3)


func _on_defeated() -> void:
	_clear_warning()
	set_light_level(1.0, 1.0)


# --- The pattern -------------------------------------------------------------------------

func _pattern_tick(delta: float) -> void:
	_bob += delta
	step_time += delta
	var p: float = pace()
	match step:
		Step.HOVER:
			_hover(delta, world.player.position.x)
			if step_time >= tuning.hover_seconds / p:
				if blasts >= tuning.attacks_per_cycle:
					_try_drop()
				else:
					_try_blast()
		Step.CHARGE:
			_hover(delta, world.geo.lane_x(target_lane))
			body.set_charge(step_time * p / tuning.charge_seconds)
			if step_time >= tuning.charge_seconds / p:
				body.set_charge(0.0)
				_bolts_left = tuning.bolts
				_bolt_timer = 0.0
				_set_step(Step.FIRE)
		Step.FIRE:
			_hover(delta, world.geo.lane_x(target_lane))
			_bolt_timer -= delta
			while _bolts_left > 0 and _bolt_timer <= 0.0:
				_fire_bolt()
				_bolts_left -= 1
				_bolt_timer += tuning.bolt_interval / p
			if _bolts_left <= 0:
				_set_step(Step.COOLDOWN)
		Step.COOLDOWN:
			_hover(delta, world.player.position.x)
			if step_time >= tuning.cooldown_seconds / p:
				_clear_warning()
				blasts += 1
				_set_step(Step.HOVER)
		Step.DROP:
			var k: float = smoothstep(0.0, 1.0, clampf(step_time * p / tuning.drop_seconds, 0.0, 1.0))
			body.position = _from.lerp(_to, k)
			if k >= 1.0:
				body.set_dazed(true)
				world.play_sfx_at(&"truck_bang", body.global_position)
				world.effects.burst(body.global_position, TestBossBody.TRIM_COLOR, 20, 0.7)
				log_event(&"dazed", {"at": drop_spot, "lane": target_lane})
				_set_step(Step.DAZED)
		Step.DAZED:
			if player_distance() > drop_spot + 3.0:
				# Missed: up again, and the cycle starts over (GDD §10: no escalation).
				body.set_dazed(false)
				_from = body.position
				log_event(&"rise")
				_set_step(Step.RISE)
		Step.RISE:
			var k: float = smoothstep(0.0, 1.0, clampf(step_time * p / tuning.rise_seconds, 0.0, 1.0))
			body.position = _from.lerp(_hover_point(world.player.position.x), k)
			if k >= 1.0:
				blasts = 0
				_set_step(Step.HOVER)


## A blast at the player's lane, if the bolts would arrive where every lane is free of holes and
## fences (so the dodge never has to happen during a jump or into a blocked lane). Otherwise it waits.
func _try_blast() -> void:
	var p: float = pace()
	var v: float = world.player.speed
	var flight: float = tuning.hover_ahead / (tuning.bolt_speed + v)
	var impact: float = player_distance() + v * (tuning.charge_seconds / p + flight)
	if arena != null and not arena.floor_clear(impact - tuning.clear_before_impact, impact + tuning.clear_after_impact):
		return
	target_lane = _player_lane()
	_warning = props.lane_warning(target_lane, player_distance() + 4.0, impact + tuning.clear_after_impact)
	world.play_sfx_at(&"truck_cannon_charge", body.global_position)
	log_event(&"blast", {"lane": target_lane})
	_set_step(Step.CHARGE)


func _fire_bolt() -> void:
	var from: Vector3 = body.global_position + Vector3(0.0, -0.3, 0.7)
	var target := Vector3(world.geo.lane_x(target_lane), BOLT_HEIGHT, world.player.position.z)
	var t: float = CyborgGun.intercept_time(from, target, world.player.speed, tuning.bolt_speed)
	if t <= 0.0:
		return
	var aim: Vector3 = target + Vector3(0.0, 0.0, -world.player.speed * t)
	world.projectiles.fire_enemy(from, (aim - from).normalized() * tuning.bolt_speed, &"enemy_bolt", BOLT_NAME, t + 1.5)
	world.play_sfx_at(&"truck_cannon", from)
	log_event(&"bolt", {"lane": target_lane, "impact": player_distance() + world.player.speed * t})


## The stomp window, in the player's lane ahead, if the player can run up to it on the floor: no hole
## or fence in that lane before it, and no ceiling over the way in. Otherwise it waits.
func _try_drop() -> void:
	var lane: int = _player_lane()
	var spot: float = player_distance() + tuning.drop_lead
	if arena != null and (not arena.floor_clear(spot - tuning.clear_before_drop, spot + tuning.clear_after_drop, lane)
			or arena.ceiling_between(spot - tuning.clear_before_drop - 10.0, spot + tuning.clear_after_drop)):
		return
	target_lane = lane
	drop_spot = spot
	_from = body.position
	_to = Vector3(world.geo.lane_x(lane), tuning.dazed_height, TrackGeometry.world_z(spot))
	log_event(&"drop", {"at": spot, "lane": lane})
	_set_step(Step.DROP)


func _hover(delta: float, x: float) -> void:
	var target: Vector3 = _hover_point(body.position.x)
	target.x = move_toward(body.position.x, x, tuning.drift_speed * delta)
	body.position = target


func _hover_point(x: float) -> Vector3:
	return Vector3(x, tuning.hover_height + 0.25 * sin(_bob * 2.2), TrackGeometry.world_z(player_distance() + tuning.hover_ahead))


## The lane the player is in or over (a wall runner counts as the outer lane on that side).
func _player_lane() -> int:
	var p: Player = world.player
	if p.surface == Player.Surface.WALL:
		return 0 if p.wall_side < 0 else lane_count() - 1
	return clampi(p.lane, 0, lane_count() - 1)


func _set_step(next: Step) -> void:
	step = next
	step_time = 0.0


func _clear_warning() -> void:
	if _warning != null:
		props.remove(_warning)
		_warning = null
