class_name MarketProps
extends RefCounted
## Marketplace visuals for electric fences and signs (MarketplaceSkin). Hazards keep the cross-zone
## language from MeshKit: the same pink crackling field and glowing bars for electric fences, here
## strung between steel poles standing in market crates, and the yellow/black striped frame for
## signs, here around a painted shop sign. Mounts sit on the lane edges and reach at most a quarter
## metre into the neighbouring lane. Meshes are cached and shared by every instance.
## DESIGN-TBD: the edge bars and the OFF look are proposals (as in the other zones); the GDD fixes only
## the pink crackle. The crates are the Marketplace's version of the City's exhaust stacks.

const ONE_CRATE: int = 0
const TWO_CRATES: int = 1

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: MarketplaceSkin:
	get:
		return _skin.get_ref() as MarketplaceSkin
var _skin: WeakRef
var _meshes: Dictionary = {}


func _init(p_skin: MarketplaceSkin) -> void:
	_skin = weakref(p_skin)


# --- Electric fence --------------------------------------------------------------------

func fence(hazard: Hazard, size: Vector3, ground_y: float, gapped: bool) -> void:
	var a: int = MeshKit.key(hazard.position.x)
	var b: int = MeshKit.key(hazard.position.z)
	var mounts: ArrayMesh = _mounts(size, ground_y, gapped, MeshKit.hash_i(a, b, 3) % 2, MeshKit.hash_i(a, b, 4) % 2)
	MeshKit.dress_fence(hazard, size, mounts, skin.fence_field_materials(), skin.fence_part_materials())


## Steel poles with glowing insulator caps at both ends of the field, each standing in one or two
## stacked wooden crates, plus the shared bars and emitters.
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
		solid.prism(Vector3(x, ground_y, 0), 0.06, pole_top - ground_y, 6, skin.fence_pole_color, 0.0, MeshKit.PAT_PLAIN,
			false)
		hot.box(Vector3(x, pole_top + 0.04, 0), Vector3(0.16, 0.08, 0.16), skin.fence_color, 0.9)
		var crates: int = 2 if (left if side < 0.0 else right) == TWO_CRATES else 1
		for i: int in crates:
			var cs: float = 0.44 - 0.06 * i
			var turn := Basis(Vector3.UP, 0.12 * side + 0.2 * i)
			_crate(solid, Transform3D(turn.scaled_local(Vector3(cs, cs * 0.8, cs)),
				Vector3(x, ground_y + 0.44 * 0.8 * i + cs * 0.4, 0)))
	MeshKit.fence_bars(hot, size, ground_y, gapped, post_x, skin.fence_color)
	var mesh: ArrayMesh = batch.to_mesh()
	_meshes[id] = mesh
	return mesh


## A wooden crate (a unit box placed by xform): slatted sides, a darker rim.
func _crate(s: MeshLayer, xform: Transform3D) -> void:
	s.box_xform(xform, skin.crate_color, 0.0, MeshKit.PAT_RIBS, MeshKit.NO_BOTTOM)
	var rim := Transform3D(xform.basis.scaled_local(Vector3(1.04, 0.14, 1.04)), xform.origin + xform.basis.y * 0.43)
	s.box_xform(rim, skin.crate_color.darkened(0.3), 0.0, MeshKit.PAT_PLAIN, MeshKit.NO_BOTTOM)


# --- Sign -----------------------------------------------------------------------------
# A shop sign bolted to the wall: a solid box in the yellow/black hazard frame around a painted
# face (a brand mark and lettering). The frame reads as solid and dangerous from the approach and
# above; decorative signs never wear it and stay above the wall-run band.

func wall_sign(hazard: Hazard, size: Vector3) -> void:
	var side: int = 1 if hazard.position.x > 0.0 else -1
	var k: int = MeshKit.hash_i(MeshKit.key(hazard.position.z), MeshKit.key(hazard.position.y), 21)
	var content: Color = skin.sign_content_colors[k % skin.sign_content_colors.size()]
	# The painted face's height, as MeshKit.hazard_sign lays it out (inside the frame's rails).
	var vis_y: float = size.y + 0.1
	var inner_y: float = vis_y - clampf(vis_y * 0.14, 0.12, 0.26) * 2.0
	var param: float = float((k >> 8) % 100 + 100 * roundi(inner_y * 10.0))
	MeshBatch.add_instance(hazard, MeshKit.hazard_sign(size, side, skin.sign_frame_color, content, 0.12,
		MeshKit.PAT_SHOPSIGN, param, 0.0, skin.solid_material(), skin.glow_material()))
