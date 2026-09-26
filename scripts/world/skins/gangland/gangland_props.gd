class_name GanglandProps
extends RefCounted
## Gangland visuals for electric fences and signs (GanglandSkin). Hazards keep the cross-zone
## language from MeshKit: the same pink crackling field and glowing bars for electric fences, here
## strung between scrap poles set in rubble or lashed to oil drums, and the yellow/black striped
## frame for signs, here around grimy salvaged billboards. Mounts sit on the lane edges and reach at
## most a few decimetres into the neighbouring lane. Meshes are cached and shared by every instance.
## DESIGN-TBD: the edge bars and the OFF look are proposals (as in the city); the GDD fixes only the
## pink crackle.

const RUBBLE: int = 0
const DRUM: int = 1

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: GanglandSkin:
	get:
		return _skin.get_ref() as GanglandSkin
var _skin: WeakRef
var _meshes: Dictionary = {}


func _init(p_skin: GanglandSkin) -> void:
	_skin = weakref(p_skin)


# --- Electric fence --------------------------------------------------------------------

func fence(hazard: Hazard, size: Vector3, ground_y: float, gapped: bool) -> void:
	var a: int = MeshKit.key(hazard.position.x)
	var b: int = MeshKit.key(hazard.position.z)
	var mounts: ArrayMesh = _mounts(size, ground_y, gapped, MeshKit.hash_i(a, b, 3) % 2, MeshKit.hash_i(a, b, 4) % 2)
	MeshKit.dress_fence(hazard, size, mounts, skin.fence_field_materials(), skin.fence_part_materials())


## Scrap poles with glowing insulator caps on both ends of the field, each set in a rubble mound or
## lashed inside an oil drum, plus the shared bars and emitters.
func _mounts(size: Vector3, ground_y: float, gapped: bool, left: int, right: int) -> ArrayMesh:
	var id: String = "mounts_%s_%s_%s_%d_%d" % [size, ground_y, gapped, left, right]
	if _meshes.has(id):
		return _meshes[id]
	var batch := MeshBatch.new()
	var solid: MeshLayer = batch.layer(skin.solid_material())
	var hot: MeshLayer = batch.layer(skin.fence_part_materials()[0])
	var post_x: float = size.x * 0.5 + 0.06
	var pole_top: float = size.y * 0.5 + 0.2
	for side: float in [-1.0, 1.0]:
		var x: float = side * post_x
		solid.box(Vector3(x, (ground_y + pole_top) * 0.5, 0), Vector3(0.1, pole_top - ground_y, 0.1), skin.fence_pole_color,
			0.0, MeshKit.PAT_RUST, MeshKit.NO_BOTTOM)
		hot.box(Vector3(x, pole_top + 0.04, 0), Vector3(0.17, 0.08, 0.17), skin.fence_color, 0.9)
		if (left if side < 0.0 else right) == RUBBLE:
			_rubble(solid, Vector3(x, ground_y, 0), side)
		else:
			_drum(solid, Vector3(x + side * 0.08, ground_y, 0))
	MeshKit.fence_bars(hot, size, ground_y, gapped, post_x, skin.fence_color)
	var mesh: ArrayMesh = batch.to_mesh()
	_meshes[id] = mesh
	return mesh


## Chunks of broken concrete piled around a pole's foot, within 0.3 m of it.
func _rubble(s: MeshLayer, foot: Vector3, side: float) -> void:
	var chunks: Array[Vector3] = [Vector3(-0.15, 0.09, 0.13), Vector3(0.14, 0.07, -0.11), Vector3(0.03, 0.17, 0.0),
		Vector3(-0.09, 0.06, -0.17), Vector3(0.12, 0.05, 0.16)]
	var sizes: Array[Vector3] = [Vector3(0.26, 0.2, 0.24), Vector3(0.26, 0.16, 0.28), Vector3(0.22, 0.16, 0.2),
		Vector3(0.2, 0.13, 0.18), Vector3(0.18, 0.11, 0.16)]
	for i: int in chunks.size():
		var turn := Basis.from_euler(Vector3(0.25 * float(i % 2) - 0.12, 0.8 * i, 0.18 * (float(i) - 2.0)))
		var offset: Vector3 = chunks[i] * Vector3(side, 1.0, 1.0)
		s.box_xform(Transform3D(turn.scaled_local(sizes[i]), foot + offset), skin.rubble_color.darkened(0.07 * i), 0.0,
			MeshKit.PAT_PLAIN, MeshKit.NO_BOTTOM)
	# A bent rebar rod sticking out of the pile.
	var rod := Basis.from_euler(Vector3(0.5, 0.0, side * 0.7)).scaled_local(Vector3(0.025, 0.5, 0.025))
	s.box_xform(Transform3D(rod, foot + Vector3(-side * 0.05, 0.3, -0.12)), skin.rust_color.darkened(0.3))


## A rusty oil drum filled with rubble, the pole standing in it.
func _drum(s: MeshLayer, foot: Vector3) -> void:
	s.prism(foot, 0.22, 0.82, 8, skin.wreck_color, 0.0, MeshKit.PAT_RUST, false)
	s.prism(foot + Vector3(0, 0.8, 0), 0.2, 0.02, 8, skin.rubble_color.darkened(0.3))
	for y: float in [0.26, 0.56]:
		s.prism(foot + Vector3(0, y, 0), 0.23, 0.04, 8, skin.wreck_color.darkened(0.25), 0.0, MeshKit.PAT_PLAIN, false)


# --- Sign -----------------------------------------------------------------------------
# A salvaged billboard bolted over the ruins: a solid box in the yellow/black hazard frame around
# faded, torn posters and graffiti. The frame reads as solid and dangerous from the approach and above.

func wall_sign(hazard: Hazard, size: Vector3) -> void:
	var side: int = 1 if hazard.position.x > 0.0 else -1
	var k: int = MeshKit.hash_i(MeshKit.key(hazard.position.z), MeshKit.key(hazard.position.y), 21)
	var content: Color = skin.sign_content_colors[k % skin.sign_content_colors.size()]
	MeshBatch.add_instance(hazard, MeshKit.hazard_sign(size, side, skin.sign_frame_color, content, 0.0,
		MeshKit.PAT_POSTER, float((k >> 8) % 97), 0.0, skin.solid_material(), skin.glow_material()))
