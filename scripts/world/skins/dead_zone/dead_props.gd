class_name DeadProps
extends RefCounted
## Dead Zone visuals for electric fences and signs (DeadZoneSkin). Hazards keep the cross-zone language
## from MeshKit: the same pink crackling field and glowing bars for electric fences, here strung between
## charred steel posts set in heaps of rubble, in scorched concrete barrier blocks or in twisted
## wreckage, and the yellow/black striped frame for signs, here around a dead billboard (a scorched
## poster board or a dead, cracked screen: nothing in the frame glows but the frame). On the zone's
## near-black palette the pink, the yellow and black and the insulator caps are by far the brightest,
## most saturated things around them. Mounts sit on the lane edges and reach at most a few decimetres
## into the neighbouring lane. Meshes are cached and shared by every instance.
## DESIGN-TBD: the edge bars and the OFF look are proposals (as in every zone); the GDD fixes only the
## pink crackle.

const RUBBLE: int = 0
const BARRIER: int = 1
const WRECKAGE: int = 2

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: DeadZoneSkin:
	get:
		return _skin.get_ref() as DeadZoneSkin
var _skin: WeakRef
var _meshes: Dictionary = {}


func _init(p_skin: DeadZoneSkin) -> void:
	_skin = weakref(p_skin)


# --- Electric fence --------------------------------------------------------------------

func fence(hazard: Hazard, size: Vector3, ground_y: float, gapped: bool) -> void:
	var a: int = MeshKit.key(hazard.position.x)
	var b: int = MeshKit.key(hazard.position.z)
	var mounts: ArrayMesh = _mounts(size, ground_y, gapped, MeshKit.hash_i(a, b, 3) % 3, MeshKit.hash_i(a, b, 4) % 3)
	MeshKit.dress_fence(hazard, size, mounts, skin.fence_field_materials(), skin.fence_part_materials())


## Charred steel posts with glowing insulator caps on both ends of the field, each set in a heap of
## rubble, a scorched barrier block or a piece of twisted wreckage, plus the shared bars and emitters.
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
		solid.box(Vector3(x, (ground_y + pole_top) * 0.5, 0), Vector3(0.1, pole_top - ground_y, 0.12), skin.post_color,
			0.0, MeshKit.PAT_DZ_STEEL, MeshKit.NO_BOTTOM)
		hot.box(Vector3(x, pole_top + 0.04, 0), Vector3(0.17, 0.08, 0.17), skin.fence_color, 0.9)
		match left if side < 0.0 else right:
			RUBBLE:
				_rubble(solid, Vector3(x, ground_y, 0), side)
			BARRIER:
				_barrier(solid, Vector3(x + side * 0.05, ground_y, 0))
			_:
				_wreckage(solid, Vector3(x, ground_y, 0), side)
	MeshKit.fence_bars(hot, size, ground_y, gapped, post_x, skin.fence_color)
	var mesh: ArrayMesh = batch.to_mesh()
	_meshes[id] = mesh
	return mesh


## Chunks of broken, ash-covered concrete piled around a post's foot, within 0.3 m of it, with a bent
## rebar rod sticking out.
func _rubble(s: MeshLayer, foot: Vector3, side: float) -> void:
	var chunks: Array[Vector3] = [Vector3(-0.15, 0.09, 0.13), Vector3(0.14, 0.07, -0.11), Vector3(0.03, 0.17, 0.0),
		Vector3(-0.09, 0.06, -0.17), Vector3(0.12, 0.05, 0.16)]
	var sizes: Array[Vector3] = [Vector3(0.26, 0.2, 0.24), Vector3(0.26, 0.16, 0.28), Vector3(0.22, 0.16, 0.2),
		Vector3(0.2, 0.13, 0.18), Vector3(0.18, 0.11, 0.16)]
	for i: int in chunks.size():
		var turn := Basis.from_euler(Vector3(0.25 * float(i % 2) - 0.12, 0.8 * i, 0.18 * (float(i) - 2.0)))
		var offset: Vector3 = chunks[i] * Vector3(side, 1.0, 1.0)
		s.box_xform(Transform3D(turn.scaled_local(sizes[i]), foot + offset), skin.rubble_color.darkened(0.08 * i), 0.0,
			MeshKit.PAT_DZ_CONCRETE, MeshKit.NO_BOTTOM)
	var rod := Basis.from_euler(Vector3(0.5, 0.0, side * 0.7)).scaled_local(Vector3(0.025, 0.5, 0.025))
	s.box_xform(Transform3D(rod, foot + Vector3(-side * 0.05, 0.3, -0.12)), skin.steel_color, 0.0, MeshKit.PAT_DZ_STEEL)


## A scorched concrete barrier block the post stands in: a low, tapered block along the track.
func _barrier(s: MeshLayer, foot: Vector3) -> void:
	var concrete: Color = skin.slab_color
	s.box(foot + Vector3(0, 0.15, 0), Vector3(0.36, 0.3, 0.7), concrete, 0.0, MeshKit.PAT_DZ_CONCRETE, MeshKit.NO_BOTTOM)
	s.box(foot + Vector3(0, 0.45, 0), Vector3(0.2, 0.3, 0.66), concrete.darkened(0.1), 0.0, MeshKit.PAT_DZ_CONCRETE,
		MeshKit.NO_BOTTOM)


## A piece of burnt-out wreckage lashed to the post: a buckled panel leaning against it and a bent strut.
func _wreckage(s: MeshLayer, foot: Vector3, side: float) -> void:
	var lean := Basis.from_euler(Vector3(-0.35, 0.2 * side, side * 0.15)).scaled_local(Vector3(0.06, 0.7, 0.5))
	s.box_xform(Transform3D(lean, foot + Vector3(side * 0.08, 0.3, 0.12)), skin.wreck_color, 0.0, MeshKit.PAT_DZ_STEEL)
	var strut := Basis.from_euler(Vector3(0.9, 0.0, -side * 0.3)).scaled_local(Vector3(0.05, 0.6, 0.05))
	s.box_xform(Transform3D(strut, foot + Vector3(side * 0.02, 0.2, -0.18)), skin.steel_color, 0.0, MeshKit.PAT_DZ_STEEL)


# --- Sign -----------------------------------------------------------------------------
# A dead billboard bolted to the ruins: a solid box in the yellow/black hazard frame around a scorched
# poster board or a dead, cracked screen. The frame reads as solid and dangerous from the approach and
# above; nothing in it glows but the frame.

func wall_sign(hazard: Hazard, size: Vector3) -> void:
	var side: int = 1 if hazard.position.x > 0.0 else -1
	var k: int = MeshKit.hash_i(MeshKit.key(hazard.position.z), MeshKit.key(hazard.position.y), 21)
	var content: Color = skin.sign_content_colors[k % skin.sign_content_colors.size()]
	var kind: int = MeshKit.DZ_BOARD_SCREEN if (k >> 8) % 3 == 0 else MeshKit.DZ_BOARD_POSTER
	MeshBatch.add_instance(hazard, MeshKit.hazard_sign(size, side, skin.sign_frame_color, content, 0.0,
		MeshKit.PAT_DZ_BOARD, float((k >> 10) % 100 + 100 * kind), 0.0, skin.solid_material(), skin.glow_material()))
