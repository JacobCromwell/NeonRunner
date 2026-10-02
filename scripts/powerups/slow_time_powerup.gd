class_name SlowTimePowerup
extends PowerupModule
## Slow time (GDD §3, §8): PC only (the controller never creates it on mobile), on the `slow_time`
## action (E), cooldown-based. It slows the whole world, player included, through
## Engine.time_scale for slow_time_duration real seconds, then cools down for slow_time_cooldown.
## Strength, duration and cooldown: FB 25.
##
## Engine.time_scale is global, so this module must never leave the game slowed:
## - the player dies or the run ends (the player stops running): slow time ends at once;
## - the game pauses (pause menu, death screen, tuning panel): normal speed while paused, and the
##   slow-down resumes with the time it had left when the game unpauses;
## - the module leaves the tree or is freed (run over, quit, restart): normal speed.
## While slowed, a cool tint (a CanvasLayer shader, fine on the Compatibility renderer) edges the
## screen, below the HUD.

const TINT_LAYER: int = 4
const TINT_COLOR := Color(0.35, 0.6, 1.0)

const TINT_SHADER: String = """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.35, 0.6, 1.0, 1.0);
uniform float amount = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float edge = smoothstep(0.45, 1.5, length(p));
	float ripple = 0.85 + 0.15 * sin(length(p) * 18.0 - TIME * 3.0);
	COLOR = vec4(tint.rgb, amount * (0.07 + 0.6 * edge * ripple));
}
"""

## Slowed right now.
var active: bool = false
## Real seconds of slow-down left while active.
var time_left: float = 0.0
## Seconds until it can be used again (0 = ready).
var cooldown_left: float = 0.0

## True while this module has changed Engine.time_scale.
var _applied: bool = false
var _layer: CanvasLayer
var _material: ShaderMaterial
var _tint: float = 0.0


func _build() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "SlowTimeTint"
	_layer.layer = TINT_LAYER
	_layer.visible = false
	add_child(_layer)
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = shader_material(TINT_SHADER)
	_material.set_shader_parameter(&"tint", TINT_COLOR)
	rect.material = _material
	_layer.add_child(rect)


## Slows the world if the player can and it's off cooldown. True if it started.
func trigger() -> bool:
	var p: Player = world.player
	if active or cooldown_left > 0.0 or not p.alive or not p.running:
		return false
	active = true
	time_left = world.powerup_tuning.slow_time_duration
	_apply()
	world.play_sfx(&"slow_time_on")
	world.effects.burst(p.global_position + Vector3(0.0, 0.8, 0.0), TINT_COLOR, 24, 0.8)
	controller.slow_time_changed.emit(true)
	return true


## Ends the slow-down now (duration over, death, end of run) and starts the cooldown.
func end() -> void:
	if not active:
		return
	active = false
	time_left = 0.0
	_restore()
	cooldown_left = world.powerup_tuning.slow_time_cooldown
	world.play_sfx(&"slow_time_off")
	controller.slow_time_changed.emit(false)


func physics_tick(delta: float) -> void:
	if active:
		var p: Player = world.player
		if not p.alive or not p.running:
			end()
			return
		# Physics ticks come at a fixed real-time rate whatever the time scale, so each one is
		# 1 / ticks_per_second real seconds.
		time_left -= 1.0 / Engine.physics_ticks_per_second
		if time_left <= 0.0:
			end()
	elif cooldown_left > 0.0:
		cooldown_left = maxf(cooldown_left - delta, 0.0)


func stop() -> void:
	end()


func hud_entry() -> Dictionary:
	var ready: float = 0.0 if active else 1.0 - cooldown_left / maxf(world.powerup_tuning.slow_time_cooldown, 0.001)
	return controller.make_hud_entry(id, tier, ready, active, -1)


func visual_tick(delta: float) -> void:
	var real_delta: float = delta / maxf(Engine.time_scale, 0.01)
	_tint = move_toward(_tint, 1.0 if active else 0.0, real_delta * (5.0 if active else 3.0))
	_layer.visible = _tint > 0.001
	if _layer.visible:
		_material.set_shader_parameter(&"amount", _tint)


func _apply() -> void:
	Engine.time_scale = world.powerup_tuning.slow_time_scale
	_applied = true


func _restore() -> void:
	if _applied:
		Engine.time_scale = 1.0
		_applied = false


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_PAUSED:
			_restore()
		NOTIFICATION_UNPAUSED:
			if active:
				_apply()
		NOTIFICATION_EXIT_TREE, NOTIFICATION_PREDELETE:
			active = false
			_restore()
