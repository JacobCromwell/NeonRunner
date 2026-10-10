class_name BeachProps
extends RefCounted
## Beach visuals for electric fences and signs (BeachSkin). Hazards keep the cross-zone language from MeshKit:
## the same pink crackling field and glowing bars for electric fences, here strung between bamboo-wrapped
## steel posts standing in sand-filled steel drums, and the yellow/black striped frame for signs, here around
## a painted surf or bar sign (wordless: a sun, waves, a palm, a board, a flamingo or a cocktail glass in
## muted paints, never glowing: the frame is the hazard). Mounts sit on the lane edges and reach at most a
## quarter metre into the neighbouring lane. Meshes are cached and shared by every instance.
## DESIGN-TBD (docs/OPEN_QUESTIONS.md, item 553): the drums and the bamboo wrap are the Beach's version of the City's
## exhaust stacks; the GDD fixes only the pink crackle.

## A drum's radius and height, and how far a post's bamboo wrap is from its steel core.
const DRUM_RADIUS: float = 0.2
const DRUM_HEIGHT: float = 0.5

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: BeachSkin:
	get:
		return _skin.get_ref() as BeachSkin
var _skin: WeakRef
var _meshes: Dictionary = {}


func _init(p_skin: BeachSkin) -> void:
	_skin = weakref(p_skin)


# --- Electric fence --------------------------------------------------------------------

func fence(hazard: Hazard, size: Vector3, ground_y: float, gapped: bool) -> void:
	var mounts: ArrayMesh = _mounts(size, ground_y, gapped)
	MeshKit.dress_fence(hazard, size, mounts, skin.fence_field_materials(), skin.fence_part_materials())


## A steel drum full of sand at each end of the field, a bamboo-wrapped post standing in it a little taller than
## the field with two steel bands, and a glowing emitter cap; plus the shared bars and emitters.
func _mounts(size: Vector3, ground_y: float, gapped: bool) -> ArrayMesh:
	var id: String = "mounts_%s_%s_%s" % [size, ground_y, gapped]
	if _meshes.has(id):
		return _meshes[id]
	var batch := MeshBatch.new()
	var solid: MeshLayer = batch.layer(skin.solid_material())
	var hot: MeshLayer = batch.layer(skin.fence_part_materials()[0])
	var post_x: float = size.x * 0.5 + 0.06
	var top: float = size.y * 0.5 + 0.12
	for side: float in [-1.0, 1.0]:
		var x: float = side * post_x
		# The drum: a steel barrel with a rim, and the sand filling it.
		solid.prism(Vector3(x, ground_y, 0), DRUM_RADIUS, DRUM_HEIGHT, 10, skin.drum_color, 0.0, MeshKit.PAT_BEACH_STEEL, false, 0.0)
		solid.prism(Vector3(x, ground_y + DRUM_HEIGHT - 0.05, 0), DRUM_RADIUS * 1.06, 0.06, 10, skin.drum_color * 1.5, 0.0,
			MeshKit.PAT_BEACH_STEEL, true, 0.0)
		solid.prism(Vector3(x, ground_y + DRUM_HEIGHT - 0.02, 0), DRUM_RADIUS * 0.9, 0.03, 10, skin.sand_color, 0.0, MeshKit.PAT_PLAIN,
			true)
		# The post: bamboo over steel, banded.
		solid.prism(Vector3(x, ground_y + DRUM_HEIGHT, 0), 0.055, top - ground_y - DRUM_HEIGHT, 6, skin.post_color, 0.0,
			MeshKit.PAT_BEACH_TIMBER, false, MeshKit.beach_timber_param(0, 0, 3))
		for f: float in [0.35, 0.7]:
			solid.prism(Vector3(x, ground_y + DRUM_HEIGHT + (top - ground_y - DRUM_HEIGHT) * f, 0), 0.065, 0.05, 6,
				skin.drum_color * 1.2, 0.0, MeshKit.PAT_BEACH_STEEL, true, 0.0)
		solid.prism(Vector3(x, top - 0.02, 0), 0.075, 0.05, 6, skin.drum_color * 1.2, 0.0, MeshKit.PAT_BEACH_STEEL, true, 0.0)
		hot.prism(Vector3(x, top + 0.04, 0), 0.07, 0.1, 8, skin.fence_color, 0.9)
	MeshKit.fence_bars(hot, size, ground_y, gapped, post_x, skin.fence_color)
	var mesh: ArrayMesh = batch.to_mesh()
	_meshes[id] = mesh
	return mesh


# --- Sign -----------------------------------------------------------------------------
# A surf or bar sign bolted to the wall: a solid box in the yellow/black hazard frame around a painted board
# (a wordless poster). The frame reads as solid and dangerous from the approach and above; nothing decorative
# in the zone wears it, and the board never glows.

func wall_sign(hazard: Hazard, size: Vector3) -> void:
	var side: int = 1 if hazard.position.x > 0.0 else -1
	var k: int = MeshKit.hash_i(MeshKit.key(hazard.position.z), MeshKit.key(hazard.position.y), 21)
	var content: Color = skin.sign_content_colors[k % skin.sign_content_colors.size()]
	# The painted board's size, as MeshKit.hazard_sign lays it out (inside the frame's rails).
	var vis_y: float = size.y + 0.1
	var vis_z: float = size.z + 0.12
	var rail: float = clampf(vis_y * 0.14, 0.12, 0.26)
	var param: float = MeshKit.beach_art_param(k % 6, vis_z - rail * 2.0, vis_y - rail * 2.0, (k >> 8) % 100)
	MeshBatch.add_instance(hazard, MeshKit.hazard_sign(size, side, skin.sign_frame_color, content, 0.0,
		MeshKit.PAT_BEACH_PAINT, param, 0.0, skin.solid_material(), skin.glow_material()))
