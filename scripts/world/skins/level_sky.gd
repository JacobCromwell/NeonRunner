class_name LevelSky
extends Resource
## A level's own sky over its zone's (LevelConfig.sky; owner, October 8, 2026): most levels keep their
## zone's sky, and a zone's last level may show the time of day or the weather turning, for a sense of
## progression (the Neon City's dawn, Gangland's blood-red overcast, the Marketplace's sunset). Only the
## sky and the distance fog change, so far scenery fades into this sky: the ambient light and the sun
## that light the runner and the enemies, every glow and every hazard colour stay the zone's, so
## hazards read as well as in the zone's other levels. ZoneSkin.level_environment() applies it, before
## the level's darkness. Visuals only.

## night_sky.gdshader uniforms set over the zone's own, by name; the rest stay the zone's. Colours are
## sRGB and reach the shader as sRGB Vector3s (srgb()), converted to linear once there, so they look
## the same on every renderer (docs/ARCHITECTURE.md, Colours in a skin's own uniforms).
@export var sky: Dictionary[String, Variant] = {}
## The distance fog's colour in this level (sRGB), when use_fog_color is on: far scenery fades into it,
## so it matches this sky's horizon.
@export var use_fog_color: bool = true
@export var fog_color: Color = Color(0.2, 0.15, 0.2)


## Sets this sky over `env`'s (a skin's make_environment()): its uniforms on the sky's shader and its
## fog colour. An environment without a shader sky keeps its own sky and takes the fog colour only.
func apply(env: Environment) -> void:
	var material: ShaderMaterial = env.sky.sky_material as ShaderMaterial if env.sky != null else null
	if material != null:
		for uniform: String in sky:
			material.set_shader_parameter(uniform, shader_value(sky[uniform]))
	if use_fog_color:
		env.fog_light_color = fog_color


## A value as the sky shader takes it: a colour as its sRGB Vector3 (srgb()), anything else as it is.
static func shader_value(value: Variant) -> Variant:
	return srgb(value) if value is Color else value


static func srgb(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)
