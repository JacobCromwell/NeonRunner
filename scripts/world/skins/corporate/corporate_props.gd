class_name CorporateProps
extends RefCounted
## Corporate visuals for electric fences and signs (CorporateSkin). Hazards keep the cross-zone
## language from MeshKit: the same pink crackling field and glowing bars for electric fences, here
## strung between the corporation's slim steel security pylons on round base plates or the military's
## pylons set in olive barrier blocks, and the yellow/black striped frame for signs, here around a
## corporate screen (PAT_CORP_AD: the brand's mark and wordless slogans in its blue and cold white).
## Mounts sit on the lane edges and reach at most a quarter metre into the neighbouring lane. Meshes
## are cached and shared by every instance.
## DESIGN-TBD: the edge bars and the OFF look are proposals (as in the other zones); the GDD fixes only
## the pink crackle. The pylons and blocks are the zone's version of the City's exhaust stacks.

const PYLON: int = 0
const BLOCK: int = 1

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: CorporateSkin:
	get:
		return _skin.get_ref() as CorporateSkin
var _skin: WeakRef
var _meshes: Dictionary = {}


func _init(p_skin: CorporateSkin) -> void:
	_skin = weakref(p_skin)


# --- Electric fence --------------------------------------------------------------------

func fence(hazard: Hazard, size: Vector3, ground_y: float, gapped: bool) -> void:
	var a: int = MeshKit.key(hazard.position.x)
	var b: int = MeshKit.key(hazard.position.z)
	var mounts: ArrayMesh = _mounts(size, ground_y, gapped, MeshKit.hash_i(a, b, 3) % 2, MeshKit.hash_i(a, b, 4) % 2)
	MeshKit.dress_fence(hazard, size, mounts, skin.fence_field_materials(), skin.fence_part_materials())


## Security pylons with glowing emitter caps at both ends of the field: a slim steel pylon on a round
## base plate, or a pylon standing in an olive barrier block; plus the shared bars and emitters.
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
		if (left if side < 0.0 else right) == BLOCK:
			# An olive barrier block: a wide foot tapering to a narrow top, the pylon standing in it.
			var foot := Vector3(x, ground_y, 0)
			solid.box(foot + Vector3(0, 0.12, 0), Vector3(0.44, 0.24, 0.5), skin.olive_color, 0.0, MeshKit.PAT_CORP_PLATE,
				MeshKit.NO_BOTTOM, 3.0)
			solid.box(foot + Vector3(0, 0.42, 0), Vector3(0.26, 0.36, 0.44), skin.olive_color.lightened(0.05), 0.0,
				MeshKit.PAT_CORP_PLATE, MeshKit.NO_BOTTOM, 3.0)
			solid.box(Vector3(x, (ground_y + 0.6 + pole_top) * 0.5, 0), Vector3(0.1, pole_top - ground_y - 0.6, 0.1),
				skin.pylon_color, 0.0, MeshKit.PAT_CORP_PLATE, MeshKit.NO_BOTTOM, 2.0)
		else:
			solid.prism(Vector3(x, ground_y, 0), 0.2, 0.05, 10, skin.gunmetal_color)
			solid.box(Vector3(x, (ground_y + pole_top) * 0.5, 0), Vector3(0.12, pole_top - ground_y, 0.12), skin.pylon_color, 0.0,
				MeshKit.PAT_CORP_PLATE, MeshKit.NO_BOTTOM, 2.0)
			# The brand's blue paint ring on the pylon (lit, never glowing).
			solid.box(Vector3(x, ground_y + 0.32, 0), Vector3(0.13, 0.1, 0.13), skin.brand_paint_color, 0.0, MeshKit.PAT_PLAIN,
				MeshKit.ALL_FACES & ~(MeshKit.FACE_PY | MeshKit.FACE_NY))
		hot.box(Vector3(x, pole_top + 0.04, 0), Vector3(0.17, 0.08, 0.17), skin.fence_color, 0.9)
	MeshKit.fence_bars(hot, size, ground_y, gapped, post_x, skin.fence_color)
	var mesh: ArrayMesh = batch.to_mesh()
	_meshes[id] = mesh
	return mesh


# --- Sign -----------------------------------------------------------------------------
# A corporate screen bolted to the wall: a solid box in the yellow/black hazard frame around a
# glowing corporate ad (the brand's mark and slogans). The frame reads as solid and dangerous from the
# approach and above; decorative screens never wear it and stay above the wall-run band.

func wall_sign(hazard: Hazard, size: Vector3) -> void:
	var side: int = 1 if hazard.position.x > 0.0 else -1
	var k: int = MeshKit.hash_i(MeshKit.key(hazard.position.z), MeshKit.key(hazard.position.y), 21)
	# The ad's face's height, as MeshKit.hazard_sign lays it out (inside the frame's rails): the ad is
	# drawn to it (PAT_CORP_AD's param carries it).
	var vis_y: float = size.y + 0.1
	var inner_y: float = vis_y - clampf(vis_y * 0.14, 0.12, 0.26) * 2.0
	var param: float = float((k >> 8) % 97 + 100 * roundi(inner_y * 10.0))
	MeshBatch.add_instance(hazard, MeshKit.hazard_sign(size, side, skin.sign_frame_color, skin.brand_color, 0.3,
		MeshKit.PAT_CORP_AD, param, 0.0, skin.solid_material(), skin.glow_material()))
