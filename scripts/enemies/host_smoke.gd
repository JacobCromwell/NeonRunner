class_name HostSmoke
extends MeshInstance3D
## A host cyborg's smoke (GDD §9.7, task S1): soft columns of pale lilac smoke rising off its shoulders, a
## faint beacon over the host that helps the player pick it out of a crowd of cyborgs at running distance.
## The host's body also glows purple (cyborg_body.gdshader's `host_rim`), which carries most of the "this one
## is a host" read: the smoke can only be thin (see below).
##
## One mesh of three quads (a wide middle column and a thinner one to each side) drawn with one shader
## (host_smoke.gdshader, which turns each quad into a camera-facing column and animates its billows):
## ONE draw call per host, no particles, and no per-frame work in GDScript, so a screenful of hosts
## costs next to nothing on a phone or the Compatibility renderer (web, low-end Android). The mesh is
## shared by every host; each host has its own material (its own offset into the noise and its own
## fade when it is defeated). It hangs off the host's chest joint, so it follows its pose (crouched,
## lying, leaning) while the shader keeps it rising straight up.
##
## **The trade-off** (found in review, task S1): the run camera shows everything further down a host's
## lane (a cyborg charging its cannon, a fence) inside the host's column on screen, so the smoke is a veil
## over exactly the things the player must read. A saturated violet veil turns the red charge-up pink, the
## fences' colour, from an opacity of about 0.1 up (and a fence purple, the host's). So the smoke is pale
## lilac (SMOKE_COLOR: the host purple lightened towards white, which keeps the veiled red and the veiled
## fence apart on the hue and saturation wheel) at no more than MAX_STRENGTH opacity, fades out within a
## stomp's reach of the camera (CyborgTuning.host_smoke_near_gone / near_full), and thins above the head.
## test_cyborg_body blends the red charge, the Bad Dream's red telegraph and the fence pink under it
## at every opacity up to MAX_STRENGTH on both renderers' blending (the Compatibility lift included).
## It never flickers (it only drifts: at the fastest climb allowed no billow passes a point more than about
## 1.3 times a second, a little slower with Settings > Reduced flashing). Visual only: it has no body, no
## hitbox and no part in any gameplay rule. Its numbers are CyborgTuning's "Host smoke" group
## (data/enemies/cyborg.tres).

const SHADER: Shader = preload("res://scripts/enemies/host_smoke.gdshader")

## The smoke's colour at its brightest (the shader darkens it to 78% in the thick of it, never more
## saturated): pale lilac, hsv about (270 degrees, 0.24, 1.0). DESIGN-TBD (docs/OPEN_QUESTIONS_DEFERRED.md item 1214): which purple.
const SMOKE_COLOR := Color(0.88, 0.76, 1.0)
## The most opaque the smoke may ever be, whatever the resource says (test_cyborg_body checks the
## veiled warnings at this opacity). The Compatibility renderer, blending in sRGB, lifts a thin veil
## to alpha ^ COMPAT_LIFT (host_smoke.gdshader).
const MAX_STRENGTH: float = 0.4
const COMPAT_LIFT: float = 0.85
## How long a defeated host's smoke takes to clear (s): the Bad Dream bursts out at that moment.
const CLEAR_TIME: float = 0.3
## The fastest the billows may climb (m/s): at this the finest pass a point about 1.3 times a second.
const MAX_RISE_SPEED: float = 1.0

## The columns, each [base in the chest joint's space (the rig faces -z, so +z is behind the host),
## width and height as a share of the tuned size, phase 0-1, opacity share]. The chest joint sits at
## the waist (0.79 m up, before a zone draws its cyborgs bigger); the middle column starts just above
## it at the spine (0.89 m), 1.8 m tall by default: thickest from the shoulders to just over the head
## (top of the head 1.5 m) and thinning toward its top, about 3 m up.
const COLUMNS: Array = [
	[Vector3(0.0, 0.1, 0.14), Vector2(1.0, 1.0), 0.0, 1.0],
	[Vector3(0.17, 0.12, 0.1), Vector2(0.62, 0.78), 0.37, 0.8],
	[Vector3(-0.17, 0.1, 0.1), Vector2(0.55, 0.68), 0.71, 0.7],
]
## How much wider a column gets at its top than at its base (host_smoke.gdshader's `spread`), and the room
## beyond the tuned size the culling box leaves for the columns' offsets and sway (m).
const SPREAD: float = 1.4
const CULL_MARGIN: float = 0.6

static var _mesh: ArrayMesh

## This host's own material (shared shader, own uniforms).
var material: ShaderMaterial

var _clear_tween: Tween


## A host's smoke for the visual seed `visual_seed` (so no two hosts' smoke moves together), with the
## numbers of `tuning` (default: CyborgTuning's own).
func build(visual_seed: int, tuning: CyborgTuning = null) -> void:
	name = "HostSmoke"
	mesh = shared_mesh()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material = ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter(&"smoke_color", SMOKE_COLOR)
	material.set_shader_parameter(&"seed", float(visual_seed % 997))
	material.set_shader_parameter(&"fade", 0.0)
	material_override = material
	configure(tuning if tuning != null else CyborgTuning.new())


## Takes the numbers of `tuning` (CyborgTuning's "Host smoke" group), within the limits the veil needs (see the
## header): an opacity above MAX_STRENGTH counts as MAX_STRENGTH, a climb above MAX_RISE_SPEED as that. An opacity
## of 0 draws nothing. The culling box is sized from the tuned size, so a tall column is not culled early.
func configure(tuning: CyborgTuning) -> void:
	var strength: float = clampf(tuning.host_smoke_strength, 0.0, MAX_STRENGTH)
	material.set_shader_parameter(&"strength", strength)
	material.set_shader_parameter(&"density", tuning.host_smoke_density)
	material.set_shader_parameter(&"rise_speed", clampf(tuning.host_smoke_rise_speed, 0.0, MAX_RISE_SPEED))
	material.set_shader_parameter(&"size", Vector2(tuning.host_smoke_width, tuning.host_smoke_height))
	material.set_shader_parameter(&"spread", SPREAD)
	var near_full: float = maxf(tuning.host_smoke_near_full, tuning.host_smoke_near_gone + 0.1)
	material.set_shader_parameter(&"near_fade", Vector2(tuning.host_smoke_near_gone, near_full))
	var reach: float = maxf(tuning.host_smoke_height, tuning.host_smoke_width * SPREAD) + CULL_MARGIN
	custom_aabb = AABB(Vector3.ONE * -reach, Vector3.ONE * (2.0 * reach))
	visible = strength > 0.0 and not _cleared()


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
	_mesh.custom_aabb = AABB(Vector3(-1.0, -1.0, -1.0), Vector3(2.0, 2.0, 2.0))  # each host's own box (configure) wins
	return _mesh


func _fade_now() -> float:
	return float(material.get_shader_parameter(&"fade"))


func _cleared() -> bool:
	return material != null and _fade_now() >= 1.0


func _set_fade(value: float) -> void:
	material.set_shader_parameter(&"fade", value)
