class_name CasinoProps
extends MarketProps
## Casino visuals for electric fences and signs (CasinoSkin; task K1). Hazards keep the cross-zone
## language from MeshKit: the same pink crackling field and glowing bars for electric fences, here
## strung between brass stanchion posts on iron plinths (the velvet-rope posts of a casino queue, the
## pink field in place of the rope), and the yellow/black striped frame for signs, here around a lit
## casino sign's face. Mounts sit on the lane edges and reach at most a quarter metre into the
## neighbouring lane. Meshes are cached and shared by every instance. It builds on the Marketplace's
## (MarketProps): the fence and sign hooks and the cache are the same, only the posts and the sign's
## face differ.
## DESIGN-TBD (docs/OPEN_QUESTIONS.md §D, item 424): the stanchion posts, the edge bars and the OFF look are proposals, as
## in every zone; the GDD fixes only the pink crackle.


## The casino's version of the Marketplace's crates under the fence's poles: a brass stanchion post
## with a glowing cap standing on a stepped iron plinth at each end of the field, plus the shared bars
## and emitters. `left` and `right` pick a tall or a short plinth.
func _mounts(size: Vector3, ground_y: float, gapped: bool, left: int, right: int) -> ArrayMesh:
	var csk: CasinoSkin = skin as CasinoSkin
	var id: String = "casino_mounts_%s_%s_%s_%d_%d" % [size, ground_y, gapped, left, right]
	if _meshes.has(id):
		return _meshes[id]
	var batch := MeshBatch.new()
	var solid: MeshLayer = batch.layer(csk.solid_material())
	var hot: MeshLayer = batch.layer(csk.fence_part_materials()[0])
	var post_x: float = size.x * 0.5 + 0.06
	var pole_top: float = size.y * 0.5 + 0.2
	for side: float in [-1.0, 1.0]:
		var x: float = side * post_x
		solid.prism(Vector3(x, ground_y, 0), 0.06, pole_top - ground_y, 6, csk.brass_color, 0.0, MeshKit.PAT_CASINO_BRASS, false, 0.6)
		hot.box(Vector3(x, pole_top + 0.04, 0), Vector3(0.16, 0.08, 0.16), csk.fence_color, 0.9)
		var tall: bool = (left if side < 0.0 else right) == TWO_CRATES
		var step_h: float = 0.14 if tall else 0.1
		solid.box(Vector3(x, ground_y + step_h * 0.5, 0), Vector3(0.46, step_h, 0.46), csk.iron_color, 0.0, MeshKit.PAT_CASINO_IRON,
			MeshKit.NO_BOTTOM, 0.0)
		solid.box(Vector3(x, ground_y + step_h + 0.05, 0), Vector3(0.32, 0.1, 0.32), csk.brass_dim_color, 0.0,
			MeshKit.PAT_CASINO_BRASS, MeshKit.NO_BOTTOM, 0.4)
		# A brass collar partway up the post.
		solid.box(Vector3(x, ground_y + (pole_top - ground_y) * 0.55, 0), Vector3(0.16, 0.06, 0.16), csk.brass_color, 0.0,
			MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 0.6)
	MeshKit.fence_bars(hot, size, ground_y, gapped, post_x, csk.fence_color)
	var mesh: ArrayMesh = batch.to_mesh()
	_meshes[id] = mesh
	return mesh


## A casino sign bolted to the wall: a solid box in the yellow/black hazard frame around a lit casino
## sign's face (PAT_CASINO_SIGN: a brand mark and lettering). The frame reads as solid and dangerous from
## the approach and above; decorative signs never wear it and stay above the wall-run band.
func wall_sign(hazard: Hazard, size: Vector3) -> void:
	var csk: CasinoSkin = skin as CasinoSkin
	var side: int = 1 if hazard.position.x > 0.0 else -1
	var k: int = MeshKit.hash_i(MeshKit.key(hazard.position.z), MeshKit.key(hazard.position.y), 21)
	var content: Color = csk.sign_content_colors[k % csk.sign_content_colors.size()]
	# The sign face's height, as MeshKit.hazard_sign lays it out (inside the frame's rails).
	var vis_y: float = size.y + 0.1
	var inner_y: float = vis_y - clampf(vis_y * 0.14, 0.12, 0.26) * 2.0
	var param: float = float((k >> 8) % 100 + 100 * roundi(inner_y * 10.0))
	MeshBatch.add_instance(hazard, MeshKit.hazard_sign(size, side, csk.sign_frame_color, content, 0.2,
		MeshKit.PAT_CASINO_SIGN, param, 0.0, csk.solid_material(), csk.glow_material()))
