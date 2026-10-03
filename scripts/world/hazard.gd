class_name Hazard
extends Area3D
## Anything that can hurt the player on contact: obstacles (fences, signs), enemy hitboxes and
## enemy projectiles. Hazards declare properties; DamageRules decides what a contact does, so
## hazards never apply damage themselves. Visuals and sounds follow `state_changed` and never
## change gameplay. After the Player resolves a contact it emits `contacted` with the outcome
## (a DamageRules.Outcome), so projectiles can despawn and enemies can react.

signal state_changed(new_state: State)
signal contacted(outcome: int)

enum State { ON, WARNING, OFF }

var hazard_name: String = "hazard"
## Blocked by armor (GDD §8). Fences are electrical.
var is_electrical: bool = false
## An enemy attack (shots, lunges, swipes, slashes). Blocked by armor (GDD §8).
var is_enemy_attack: bool = false
## A solid collision (signs, trucks, walls, enemy bodies). Armor does not block these.
var is_solid: bool = false
## The juggernaut dash passes through every hazard except falls unless this is false (FB 17).
var dash_passes: bool = true
## A thief's touch (GDD §9.12, the Tithe Collector): touching this robs instead of hurting
## (DamageRules.Outcome.ROBBED): it takes this share of the run's credits (ScoreKeeper.rob), held by its
## enemy. 0 for every other hazard. A thief sets it on its hitboxes from its data (ThiefTuning).
var steals_share: float = 0.0
## The enemy this hitbox belongs to, or null for obstacles and projectiles.
var enemy: Enemy = null
## Which part of an enemy this is: &"body", &"top" (stomp zone), &"weak_point", &"attack".
var part: StringName = &""
## The hitbox size (box shape), used for stomp checks and debug drawing.
var size: Vector3 = Vector3.ONE
## Hangs from a ceiling (a Barnacle Turret, GDD §9.8): its top, the part a stomp lands on, faces down,
## toward a rider on the ceiling, who stomps it by dropping back onto its underside
## (Player._is_stomping, bottom_y()).
var upside_down: bool = false
var state: State = State.ON

var _pulse_on: float = 0.0
var _pulse_off: float = 0.0
var _pulse_warning: float = 0.0
var _pulse_time: float = 0.0


func _ready() -> void:
	set_physics_process(_pulse_on > 0.0)


## Hurts only while ON. WARNING is the telegraph before switching on, and is still safe.
func is_active() -> bool:
	return state == State.ON


## Switches the hazard on or off for good (e.g. fences disabled by an EMP, a defeated enemy).
func set_enabled(on: bool) -> void:
	_pulse_on = 0.0
	set_physics_process(false)
	var next: State = State.ON if on else State.OFF
	if next != state:
		state = next
		state_changed.emit(state)


## World-space height of the top of the hitbox.
func top_y() -> float:
	return global_position.y + size.y * 0.5


## World-space height of the bottom of the hitbox (an upside_down hitbox's top, as a ceiling rider
## sees it).
func bottom_y() -> float:
	return global_position.y - size.y * 0.5


## Makes the hazard switch on and off, driven by the level clock so every attempt
## at the same seed sees the same timing. `phase` (0–1) offsets it within one cycle.
func setup_pulsing(on_time: float, off_time: float, warning: float, phase: float, level_time: float) -> void:
	_pulse_on = on_time
	_pulse_off = off_time
	_pulse_warning = minf(warning, off_time)
	_pulse_time = phase * (on_time + off_time) + level_time
	_update_pulse()
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	_pulse_time += delta
	_update_pulse()


func _update_pulse() -> void:
	var cycle: float = _pulse_on + _pulse_off
	var t: float = fmod(_pulse_time, cycle)
	var next: State = State.ON
	if t >= _pulse_on:
		next = State.WARNING if cycle - t <= _pulse_warning else State.OFF
	if next != state:
		state = next
		state_changed.emit(state)
