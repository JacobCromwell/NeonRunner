class_name MagnetPowerup
extends PowerupModule
## The magnet (GDD §8): pulls in nearby credits. It only sets the credit field's pull radius (from
## the tier) and speed; CreditField enforces the GDD cap (the player's lane plus the adjacent
## lanes, same surface only). Tier count and radii: FB 23.
##
## The look: a faint field in the credits' gold on the player's surface, covering roughly what the
## magnet reaches, with rings flowing in toward the player; it brightens for a moment on a pickup.

## The pull's colour: the credits' azure (never the signs' yellow: hazard colours are reserved).
const COLOR := Color(0.3, 0.68, 1.0)
## Metres behind the player the field reaches (the credit field pulls from 1 m behind).
const BEHIND: float = 1.0

const FIELD_SHADER: String = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0, 0.8, 0.32, 1.0);
uniform float strength = 0.11;
uniform float pulse = 0.0;
// Where the player stands along the field (UV.y: 0 = far end, 1 = near end).
uniform float player_v = 0.8;
// Field length / width, so the rings are round in metres.
uniform float aspect = 2.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float mask = 1.0 - smoothstep(0.45, 1.0, length(p));
	float r = length(vec2(UV.x - 0.5, (UV.y - player_v) * aspect));
	float rings = pow(0.5 + 0.5 * sin(r * 22.0 + TIME * 7.0), 8.0);
	ALBEDO = color.rgb;
	ALPHA = clamp(mask * (0.3 + rings) * (strength + pulse * 0.3), 0.0, 1.0);
}
"""

var _field: MeshInstance3D
var _material: ShaderMaterial
var _pulse: float = 0.0
var _ground_y: float = 0.0


func _build() -> void:
	_apply()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_material = shader_material(FIELD_SHADER)
	_material.set_shader_parameter(&"color", COLOR)
	_field = MeshInstance3D.new()
	_field.mesh = quad
	_field.material_override = _material
	_field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_field)
	world.credits.collected.connect(_on_collected)


## The pull radius for this tier (m).
func radius() -> float:
	return PowerupTuning.at_tier(world.powerup_tuning.magnet_radius, tier)


func physics_tick(_delta: float) -> void:
	_apply()


func visual_tick(delta: float) -> void:
	var p: Player = world.player
	_field.visible = p.alive
	if not _field.visible:
		return
	_pulse = move_toward(_pulse, 0.0, delta * 3.0)
	var r: float = radius()
	var lateral: float = minf(r, world.geo.lane_width * 1.25)
	var ahead: float = r * 2.5
	var length: float = ahead + BEHIND
	var basis: Basis = surface_basis(p)
	var base: Vector3 = p.global_position
	match p.surface:
		Player.Surface.FLOOR:
			# Stay on the ground under a jump.
			if p.grounded:
				_ground_y = base.y
			base.y = minf(base.y, _ground_y)
		Player.Surface.CEILING:
			# On the ceiling's underside, wherever it is (Player.ceiling_y: a boss's may be high up).
			base.y = p.ceiling_y
	var flat := Basis(Vector3.RIGHT, -PI * 0.5)  # the quad lies on the surface, its +y pointing forward
	_field.global_transform = Transform3D(basis * flat * Basis.from_scale(Vector3(lateral * 2.0, length, 1.0)),
		base + basis * Vector3(0.0, 0.04, -(ahead - BEHIND) * 0.5))
	_material.set_shader_parameter(&"player_v", ahead / length)
	_material.set_shader_parameter(&"aspect", length / (lateral * 2.0))
	_material.set_shader_parameter(&"pulse", _pulse)


func _apply() -> void:
	world.credits.magnet_radius = radius()
	world.credits.magnet_pull_speed = world.powerup_tuning.magnet_pull_speed


func _on_collected(_value: int, _position: Vector3) -> void:
	_pulse = 1.0


func _notification(what: int) -> void:
	# Leaving play (the controller or the run is going away): the credit field stops pulling.
	if what == NOTIFICATION_EXIT_TREE and world != null and is_instance_valid(world.credits):
		world.credits.magnet_radius = 0.0
