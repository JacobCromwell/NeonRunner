class_name IceLabProps
extends RefCounted
## Ice Lab visuals for electric fences and signs (IceLabSkin). Hazards keep the cross-zone language from MeshKit: the same pink
## crackling field and glowing bars for electric fences, here strung between frost-crusted steel posts standing in a drift of packed
## snow, on a bolted steel base plate or beside a few ice crystals, and the yellow/black striped frame for signs, here around a
## frosted dead panel (dark steel under rime: nothing in the frame glows but the frame). Against the hall's cold blues the pink, the
## yellow and black and the insulator caps are by far the brightest, most saturated things around them. Mounts sit on the lane edges and
## reach at most a few decimetres into the neighbouring lane. Meshes are cached and shared by every instance.

const SNOW: int = 0
const PLATE: int = 1
const CRYSTALS: int = 2

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: IceLabSkin:
	get:
		return _skin.get_ref() as IceLabSkin
var _skin: WeakRef
var _parts: IceLabParts
var _meshes: Dictionary = {}


func _init(p_skin: IceLabSkin) -> void:
	_skin = weakref(p_skin)
	_parts = IceLabParts.new(p_skin)


# --- Electric fence --------------------------------------------------------------------

func fence(hazard: Hazard, size: Vector3, ground_y: float, gapped: bool) -> void:
	var a: int = MeshKit.key(hazard.position.x)
	var b: int = MeshKit.key(hazard.position.z)
	var mounts: ArrayMesh = _mounts(size, ground_y, gapped, MeshKit.hash_i(a, b, 3) % 3, MeshKit.hash_i(a, b, 4) % 3)
	MeshKit.dress_fence(hazard, size, mounts, skin.fence_field_materials(), skin.fence_part_materials())


## Frost-crusted steel posts with glowing insulator caps on both ends of the field, each standing in a drift of snow, on a base plate or
## among crystals, plus the shared bars and emitters.
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
			0.0, MeshKit.PAT_IL_STEEL, MeshKit.NO_BOTTOM, 2.0)
		hot.box(Vector3(x, pole_top + 0.04, 0), Vector3(0.17, 0.08, 0.17), skin.fence_color, 0.9)
		match left if side < 0.0 else right:
			SNOW:
				_drift(solid, Vector3(x, ground_y, 0), side)
			PLATE:
				_plate(solid, Vector3(x, ground_y, 0))
			_:
				_ice(solid, Vector3(x, ground_y, 0), side)
	MeshKit.fence_bars(hot, size, ground_y, gapped, post_x, skin.fence_color)
	var mesh: ArrayMesh = batch.to_mesh()
	_meshes[id] = mesh
	return mesh


## A drift of packed snow piled round a post's foot, within 0.3 m of it.
func _drift(s: MeshLayer, foot: Vector3, side: float) -> void:
	var lumps: Array[Vector3] = [Vector3(-0.14, 0.08, 0.12), Vector3(0.13, 0.06, -0.1), Vector3(0.02, 0.12, 0.0), Vector3(-0.08, 0.05, -0.15)]
	var sizes: Array[Vector3] = [Vector3(0.3, 0.16, 0.26), Vector3(0.28, 0.12, 0.3), Vector3(0.24, 0.22, 0.22), Vector3(0.22, 0.1, 0.2)]
	for i: int in lumps.size():
		var turn := Basis.from_euler(Vector3(0.0, 0.8 * i, 0.12 * (float(i) - 1.5)))
		s.box_xform(Transform3D(turn.scaled_local(sizes[i]), foot + lumps[i] * Vector3(side, 1.0, 1.0)), skin.snow_color.darkened(0.04 * i),
			0.0, MeshKit.PAT_IL_SNOW, MeshKit.NO_BOTTOM, 0.0)


## A bolted steel base plate the post stands on: a low plate, four bolts, a rime of snow on it.
func _plate(s: MeshLayer, foot: Vector3) -> void:
	s.box(foot + Vector3(0, 0.04, 0), Vector3(0.4, 0.08, 0.4), skin.frame_color, 0.0, MeshKit.PAT_IL_STEEL, MeshKit.NO_BOTTOM, 0.0)
	for dx: float in [-0.14, 0.14]:
		for dz: float in [-0.14, 0.14]:
			s.box(foot + Vector3(dx, 0.1, dz), Vector3(0.06, 0.04, 0.06), skin.frame_color.lightened(0.15), 0.0, MeshKit.PAT_IL_STEEL,
				MeshKit.NO_BOTTOM, 2.0)
	s.box(foot + Vector3(0, 0.095, 0), Vector3(0.34, 0.03, 0.34), skin.snow_color, 0.0, MeshKit.PAT_IL_SNOW, MeshKit.FACE_PY, 0.0)


## A few ice crystals growing at a post's foot, within 0.3 m of it.
func _ice(s: MeshLayer, foot: Vector3, side: float) -> void:
	_parts.crystals(s, foot + Vector3(side * 0.12, 0.0, 0.0), Vector3(0.1 * side, 1.0, 0.0), 4, 0.42, 0.55, MeshKit.key(foot.x) + 3, 4, 0.05)


# --- Sign -----------------------------------------------------------------------------
# A frosted dead panel on the wall: a solid box in the yellow/black hazard frame around dark steel under rime (wordless). The frame reads
# as solid and dangerous from the approach and above; nothing in it glows but the frame.

func wall_sign(hazard: Hazard, size: Vector3) -> void:
	var side: int = 1 if hazard.position.x > 0.0 else -1
	var k: int = MeshKit.hash_i(MeshKit.key(hazard.position.z), MeshKit.key(hazard.position.y), 21)
	var content: Color = skin.sign_content_colors[k % skin.sign_content_colors.size()]
	MeshBatch.add_instance(hazard, MeshKit.hazard_sign(size, side, skin.sign_frame_color, content, 0.0,
		MeshKit.PAT_IL_STEEL, 0.0, 0.0, skin.solid_material(), skin.glow_material()))
