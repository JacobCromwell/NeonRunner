class_name HostSmoke
extends MeshInstance3D
## A host cyborg's purple smoke (GDD §9.7, task S1): soft columns of smoke rising off its shoulders, so
## the player can pick the host out of a crowd of cyborgs at a glance at running distance.
##
## One mesh of three quads (a wide middle column and a thinner one to each side) drawn with one shader
## (host_smoke.gdshader, which turns each quad into a camera-facing column and animates its billows):
## ONE draw call per host, no particles, and no per-frame work in GDScript, so a screenful of hosts
## costs next to nothing on a phone or the Compatibility renderer (web, low-end Android). The mesh is
## shared by every host; each host has its own material (its own offset into the noise and its own
## fade when it is defeated). It hangs off the host's chest joint, so it follows its pose (crouched,
## lying, leaning) while the shader keeps it rising straight up.
##
## The Bad Dream's own violet (BadDreamModel.PURPLE, leaning blue: pink is the fences' colour), a
## shade off the glitching screen's and the veins' purple: on a cyborg, purple always and only means
## "host". It is a soft veil, never a hazard colour, and it never flickers (so there is
## nothing for Settings > Reduced flashing to turn off). Visual only: it has no body, no hitbox and
## no part in any gameplay rule. Its numbers (opacity, density, rise speed, size) are CyborgTuning's
## "Host smoke" group (data/enemies/cyborg.tres).

const SHADER: Shader = preload("res://scripts/enemies/host_smoke.gdshader")

## How long a defeated host's smoke takes to clear (s): the Bad Dream bursts out at that moment.
const CLEAR_TIME: float = 0.3
## The fastest the billows may climb (m/s): at this the finest pass a point about 2.3 times a second.
const MAX_RISE_SPEED: float = 1.0

## The columns, each [base in the chest joint's space (the rig faces -z, so +z is behind the host),
## width and height as a share of the tuned size, phase 0-1, opacity share]. The chest joint sits at
## the waist (0.79 m up, before a zone draws its cyborgs bigger); the middle column starts just above
## it at the spine (0.89 m), 2.2 m tall by default: thickest from the shoulders to just over the head
## (top of the head 1.5 m) and thinning toward its top, about 3 m up.
const COLUMNS: Array = [
	[Vector3(0.0, 0.1, 0.14), Vector2(1.0, 1.0), 0.0, 1.0],
	[Vector3(0.17, 0.12, 0.1), Vector2(0.62, 0.78), 0.37, 0.8],
	[Vector3(-0.17, 0.1, 0.1), Vector2(0.55, 0.68), 0.71, 0.7],
]
## The mesh's bounds (its vertices all sit at the columns' bases; the shader spreads them): a generous
## box about the chest, in the joint's space, which turns with the pose.
const BOUNDS := AABB(Vector3(-2.6, -2.6, -2.6), Vector3(5.2, 5.2, 5.2))

static var _mesh: ArrayMesh

## This host's own material (shared shader, own uniforms).
var material: ShaderMaterial

var _clear_tween: Tween


## A host's smoke for the visual seed `visual_seed` (so no two hosts' smoke moves together), with the
## numbers of `tuning` (default: CyborgTuning's own).
func build(visual_seed: int, tuning: CyborgTuning = null) -> void:
	name = "HostSmoke"
	mesh = shared_mesh()
	custom_aabb = BOUNDS
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material = ShaderMaterial.new()
	material.shader = SHADER
	# DESIGN-TBD (docs/questions/s1.md 2): the violet and its flat veil (no glowing core).
	material.set_shader_parameter(&"smoke_color", BadDreamModel.PURPLE)
	material.set_shader_parameter(&"seed", float(visual_seed % 997))
	material.set_shader_parameter(&"fade", 0.0)
	material_override = material
	configure(tuning if tuning != null else CyborgTuning.new())


## Takes the numbers of `tuning` (CyborgTuning's "Host smoke" group). An opacity of 0 draws nothing.
func configure(tuning: CyborgTuning) -> void:
	material.set_shader_parameter(&"strength", tuning.host_smoke_strength)
	material.set_shader_parameter(&"density", tuning.host_smoke_density)
	# Never faster than MAX_RISE_SPEED, whatever the resource says: past it the billows would flicker.
	material.set_shader_parameter(&"rise_speed", minf(tuning.host_smoke_rise_speed, MAX_RISE_SPEED))
	material.set_shader_parameter(&"size", Vector2(tuning.host_smoke_width, tuning.host_smoke_height))
	visible = tuning.host_smoke_strength > 0.0 and not _cleared()


## A defeated host's smoke clears over CLEAR_TIME, then it is hidden (no draw call at all).
func clear() -> void:
	if not is_inside_tree():
		visible = false
		return
	if _clear_tween != null and _clear_tween.is_valid():
		_clear_tween.kill()
	_clear_tween = create_tween()
	_clear_tween.tween_method(_set_fade, _fade_now(), 1.0, CLEAR_TIME)
	_clear_tween.tween_callback(func() -> void: visible = false)


## Draw calls of the smoke: one while it shows, none once it is hidden or cleared.
func draw_call_count() -> int:
	return mesh.get_surface_count() if mesh != null and is_visible_in_tree() else 0


## The mesh every host shares: a quad per column with all six vertices at the column's base.
static func shared_mesh() -> ArrayMesh:
	if _mesh != null:
		return _mesh
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var corners: Array[Vector2] = [Vector2(-1, -1), Vector2(-1, 1), Vector2(1, 1), Vector2(-1, -1), Vector2(1, 1),
		Vector2(1, -1)]
	for column: Array in COLUMNS:
		var base: Vector3 = column[0]
		var share: Vector2 = column[1]
		var tint := Color(float(column[2]), 0.0, 0.0, float(column[3]))
		for corner: Vector2 in corners:
			verts.append(base)
			colors.append(tint)
			uvs.append(corner)
			uv2s.append(share)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	_mesh = ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh.custom_aabb = BOUNDS
	return _mesh


func _fade_now() -> float:
	return float(material.get_shader_parameter(&"fade"))


func _cleared() -> bool:
	return material != null and _fade_now() >= 1.0


func _set_fade(value: float) -> void:
	material.set_shader_parameter(&"fade", value)
