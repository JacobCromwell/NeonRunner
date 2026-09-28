class_name GoldenProps
extends RefCounted
## Golden Zone visuals for electric fences and signs (GoldenSkin). Hazards keep the cross-zone
## language from MeshKit: the same pink crackling field and glowing bars for electric fences, here
## strung between polished gold stanchions on marble bases (the elite's velvet-rope posts, electric),
## and the yellow/black striped frame for signs, here around a luxury boutique's board. Mounts sit on
## the lane edges and reach at most a quarter metre into the neighbouring lane. Meshes are cached and
## shared by every instance.
## DESIGN-TBD: the edge bars and the OFF look are proposals (as in the other zones); the GDD fixes only
## the pink crackle. The stanchions are the Golden Zone's version of the City's exhaust stacks.

## The stanchions' polish (MeshKit.PAT_GOLD's parameter).
const POLISH: float = 0.85

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: GoldenSkin:
	get:
		return _skin.get_ref() as GoldenSkin
var _skin: WeakRef
var _meshes: Dictionary = {}


func _init(p_skin: GoldenSkin) -> void:
	_skin = weakref(p_skin)


# --- Electric fence --------------------------------------------------------------------

func fence(hazard: Hazard, size: Vector3, ground_y: float, gapped: bool) -> void:
	var mounts: ArrayMesh = _mounts(size, ground_y, gapped)
	MeshKit.dress_fence(hazard, size, mounts, skin.fence_field_materials(), skin.fence_part_materials())


## A polished gold stanchion at each end of the field: an octagonal marble base, a slim post a little
## taller than the field, a gold collar under a pink emitter cap; plus the shared bars and emitters.
func _mounts(size: Vector3, ground_y: float, gapped: bool) -> ArrayMesh:
	var id: String = "mounts_%s_%s_%s" % [size, ground_y, gapped]
	if _meshes.has(id):
		return _meshes[id]
	var batch := MeshBatch.new()
	var solid: MeshLayer = batch.layer(skin.solid_material())
	var hot: MeshLayer = batch.layer(skin.fence_part_materials()[0])
	var post_x: float = size.x * 0.5 + 0.06
	var top: float = size.y * 0.5 + 0.12
	var stone: Color = skin.stone_colors[0]
	var gold: Color = skin.gold_color
	for side: float in [-1.0, 1.0]:
		var x: float = side * post_x
		solid.prism(Vector3(x, ground_y, 0), 0.2, 0.12, 8, stone, 0.0, MeshKit.PAT_MARBLE)
		solid.prism(Vector3(x, ground_y + 0.12, 0), 0.13, 0.08, 8, gold, 0.0, MeshKit.PAT_GOLD, true, POLISH)
		solid.prism(Vector3(x, ground_y + 0.2, 0), 0.045, top - ground_y - 0.2, 8, gold, 0.0, MeshKit.PAT_GOLD, false,
			POLISH)
		solid.prism(Vector3(x, top - 0.02, 0), 0.08, 0.06, 8, gold, 0.0, MeshKit.PAT_GOLD, true, POLISH)
		hot.prism(Vector3(x, top + 0.04, 0), 0.07, 0.1, 8, skin.fence_color, 0.9)
	MeshKit.fence_bars(hot, size, ground_y, gapped, post_x, skin.fence_color)
	var mesh: ArrayMesh = batch.to_mesh()
	_meshes[id] = mesh
	return mesh


# --- Sign -----------------------------------------------------------------------------
# A boutique's board bolted to the wall: a solid box in the yellow/black hazard frame around its
# board (a monogram and slim gold lettering). The frame reads as solid and dangerous from the approach
# and above; nothing decorative in the zone wears it, and the board never carries the cult's emblem.

func wall_sign(hazard: Hazard, size: Vector3) -> void:
	var side: int = 1 if hazard.position.x > 0.0 else -1
	var k: int = MeshKit.hash_i(MeshKit.key(hazard.position.z), MeshKit.key(hazard.position.y), 21)
	var content: Color = skin.sign_content_colors[k % skin.sign_content_colors.size()]
	# The board's height, as MeshKit.hazard_sign lays it out (inside the frame's rails).
	var vis_y: float = size.y + 0.1
	var inner_y: float = vis_y - clampf(vis_y * 0.14, 0.12, 0.26) * 2.0
	var param: float = float((k >> 8) % 100 + 100 * roundi(inner_y * 10.0))
	MeshBatch.add_instance(hazard, MeshKit.hazard_sign(size, side, skin.sign_frame_color, content, 0.1,
		MeshKit.PAT_BOUTIQUE, param, 0.0, skin.solid_material(), skin.glow_material()))
