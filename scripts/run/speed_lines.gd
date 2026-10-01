class_name SpeedLines
extends CanvasLayer
## Screen-space speed lines (GDD §3, the owner's playtest, September 30, 2026): pale streaks that
## grow with Player.speed (the zone's base and any ramp, speed-pad or dash boost, same as the
## camera's field-of-view kick) and fade at low speed, cheap and static so they work on the
## Compatibility renderer and honour Reduced flashing on their own (nothing about them strobes: only
## their overall strength eases with speed). SpeedFxTuning's numbers keep a safe band around the
## screen's centre clear (lines_safe_width), so a lane's centre - where a hazard's telegraph is read
## - is never touched, however fast the run gets.
##
## One fullscreen ColorRect on a canvas_item shader: a fixed, angle-free comb of vertical streaks
## (a stable hash per screen column, never re-randomised, so there is nothing to flicker), masked to
## the two edges and faded in and out by distance from lines_min_speed to lines_full_speed.

const LAYER: int = 3
const COLOR := Color(0.92, 0.95, 1.0)

const SHADER: String = """
shader_type canvas_item;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float safe_width : hint_range(0.0, 1.0) = 0.44;

float comb(float x) {
	float cell = floor(x);
	return fract(sin(cell * 12.9898) * 43758.5453);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float side = smoothstep(safe_width, 1.0, abs(p.x));
	float streak = step(0.74, comb(p.x * 50.0));
	float taper = 1.0 - smoothstep(0.75, 1.05, abs(p.y));
	float a = side * streak * taper * intensity * color.a;
	COLOR = vec4(color.rgb, a);
}
"""

var world: RunWorld
var tuning: SpeedFxTuning

var _rect: ColorRect
var _material: ShaderMaterial
var _strength: float = 0.0


## Rebinds to `p_world` (a level restart builds a fresh RunWorld); builds the overlay once.
func setup(p_world: RunWorld, p_tuning: SpeedFxTuning) -> void:
	world = p_world
	tuning = p_tuning
	if _rect != null:
		_material.set_shader_parameter(&"safe_width", tuning.lines_safe_width)
		return
	layer = LAYER
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = Shader.new()
	_material.shader.code = SHADER
	_material.set_shader_parameter(&"color", COLOR)
	_material.set_shader_parameter(&"safe_width", tuning.lines_safe_width)
	_rect.material = _material
	add_child(_rect)


func _process(delta: float) -> void:
	if world == null or world.player == null:
		return
	var speed: float = world.player.speed
	var span: float = maxf(tuning.lines_full_speed - tuning.lines_min_speed, 0.01)
	var target: float = clampf((speed - tuning.lines_min_speed) / span, 0.0, 1.0)
	var k: float = 1.0 - exp(-tuning.lines_ease_rate * delta)
	_strength = lerpf(_strength, target, k)
	_material.set_shader_parameter(&"intensity", _strength * tuning.lines_max_alpha)
