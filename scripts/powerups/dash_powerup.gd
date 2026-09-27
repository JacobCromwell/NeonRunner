class_name DashPowerup
extends PowerupModule
## The juggernaut dash (GDD §8): the `dash` action (a tap on mobile via TouchInput) barrels through
## enemies and obstacles, then recharges. The Player does the dash itself (start_dash: faster, and
## DamageRules lets it pass hazards and smash enemies); this module owns the cooldown and the look.
## DESIGN-TBD (OPEN_QUESTIONS §4): duration, cooldown and speed are placeholders in PowerupTuning,
## and the cooldown runs from the moment the dash starts. It works on any surface.
##
## The look, while dashing: an energy shell around the player and speed lines streaming past; a
## camera kick when it starts and a bigger hit when it smashes an enemy. (No afterimages: seen from
## the chase camera they all line up behind the player and add up to a glare.)
## DESIGN-TBD (docs/questions/p1.md 6): they follow the runner's own glow, Razor Echo's soft copper,
## thinned toward white (PlayerSuit.GLOW_PALE) so the additive shell and the smash burst never read as
## a hazard's orange.

const COLOR := PlayerSuit.GLOW_PALE

const SHELL_SHADER: String = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0, 0.8, 0.66, 1.0);
uniform float strength = 1.0;
void fragment() {
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float bands = 0.75 + 0.25 * sin(UV.y * 40.0 - TIME * 30.0);
	ALBEDO = color.rgb * 1.3;
	ALPHA = clamp((0.1 + pow(rim, 2.0) * 1.1) * bands * strength, 0.0, 1.0);
}
"""

## Seconds until the dash can be used again (0 = ready).
var cooldown_left: float = 0.0

## Visual strength 0–1 (eases in when a dash starts and out after it ends).
var _fx: float = 0.0
var _shell: MeshInstance3D
var _shell_material: ShaderMaterial
var _speed_lines: CPUParticles3D


func _build() -> void:
	_build_visuals()
	world.player.enemy_contact.connect(_on_enemy_contact)


## Starts a dash if the player can and it's off cooldown. True if it started.
func trigger() -> bool:
	var p: Player = world.player
	if not p.alive or not p.running or p.dashing or cooldown_left > 0.0:
		return false
	var t: PowerupTuning = world.powerup_tuning
	p.start_dash(t.dash_duration, t.dash_speed_bonus)
	cooldown_left = t.dash_cooldown
	world.effects.shake(0.16, 0.2)
	controller.dash_started.emit()
	return true


func physics_tick(delta: float) -> void:
	if cooldown_left <= 0.0:
		return
	cooldown_left -= delta
	if cooldown_left <= 0.0:
		cooldown_left = 0.0
		if world.player.alive:
			world.play_sfx(&"dash_ready")
		controller.dash_ready.emit()


func hud_entry() -> Dictionary:
	var ready: float = 1.0 - cooldown_left / maxf(world.powerup_tuning.dash_cooldown, 0.001)
	return controller.make_hud_entry(id, tier, ready, world.player.dashing, -1)


func visual_tick(delta: float) -> void:
	var p: Player = world.player
	var on: bool = p.dashing and p.alive
	_fx = move_toward(_fx, 1.0 if on else 0.0, delta * (14.0 if on else 5.0))
	var basis: Basis = surface_basis(p)
	var height: float = body_height(p)
	var center: Vector3 = p.global_position + basis * Vector3(0.0, height * 0.5, 0.0)
	_shell.visible = _fx > 0.01
	if _shell.visible:
		var v: Vector3 = p.tuning.visual_size
		var grow: float = 1.0 + 0.25 * (1.0 - _fx)
		_shell.global_transform = Transform3D(basis * Basis.from_scale(Vector3(v.x * 1.9, height * 1.25, v.z * 2.6) * grow), center)
		_shell_material.set_shader_parameter(&"strength", _fx)
	_speed_lines.global_transform = Transform3D(Basis.IDENTITY, center)
	if _speed_lines.emitting != on:
		_speed_lines.emitting = on


func _on_enemy_contact(enemy: Enemy, cause: StringName) -> void:
	if cause == &"dash" and is_instance_valid(enemy):
		world.effects.burst(enemy.aim_point(), COLOR, 32, 1.1)
		world.effects.shake(0.32, 0.25)


func _build_visuals() -> void:
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.5
	capsule.height = 1.0
	capsule.radial_segments = 16
	capsule.rings = 6
	_shell_material = shader_material(SHELL_SHADER)
	_shell_material.set_shader_parameter(&"color", COLOR)
	_shell = MeshInstance3D.new()
	_shell.mesh = capsule
	_shell.material_override = _shell_material
	_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shell.visible = false
	add_child(_shell)

	# Speed lines: thin streaks around the player that stay behind in the world, so they stream past.
	var streak := BoxMesh.new()
	streak.size = Vector3(0.025, 0.025, 2.2)
	_speed_lines = _particles(streak, 48, 0.2, _fade_ramp(Color(COLOR.lerp(Color.WHITE, 0.4), 0.8)))
	_speed_lines.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_speed_lines.emission_ring_axis = Vector3.BACK
	_speed_lines.emission_ring_radius = 1.9
	_speed_lines.emission_ring_inner_radius = 0.8
	_speed_lines.emission_ring_height = 3.0
	add_child(_speed_lines)


func _particles(mesh: Mesh, amount: int, lifetime: float, ramp: Gradient) -> CPUParticles3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var p := CPUParticles3D.new()
	p.mesh = mesh
	p.material_override = mat
	p.amount = amount
	p.lifetime = lifetime
	p.emitting = false
	p.local_coords = false
	p.gravity = Vector3.ZERO
	p.direction = Vector3.BACK
	p.spread = 0.0
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.0
	p.color_ramp = ramp
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


static func _fade_ramp(color: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, color)
	g.set_color(1, Color(color, 0.0))
	return g
