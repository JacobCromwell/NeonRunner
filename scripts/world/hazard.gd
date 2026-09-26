class_name Hazard
extends Area3D
## Anything that can hurt the player on contact. Hazards declare properties; DamageRules
## decides what a contact does, so hazards never apply damage themselves. Visuals and
## sounds follow `state_changed` and never change gameplay.

signal state_changed(new_state: State)

enum State { ON, WARNING, OFF }

var hazard_name: String = "hazard"
## Blocked by armor (GDD §8). Fences are electrical.
var is_electrical: bool = false
## A solid collision (signs, trucks, walls). Armor does not block these.
var is_solid: bool = false
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
