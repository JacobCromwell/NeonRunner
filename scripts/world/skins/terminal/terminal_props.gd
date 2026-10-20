class_name TerminalProps
extends RefCounted
## Terminal visuals for electric fences and signs (TerminalSkin). Hazards keep the cross-zone language from MeshKit: the same
## pink crackling field and glowing bars for electric fences, here strung between rusted steel posts set in concrete blocks or
## heaps of rubble, and the yellow/black striped frame for signs, here around a dead departure board (dark glass, a worn
## frame, wordless: nothing in the frame glows but the frame). Against the hall's dark rust and stone the pink, the yellow and
## black and the insulator caps are by far the brightest, most saturated things around them. Mounts sit on the lane edges and
## reach at most a few decimetres into the neighbouring lane. Meshes are cached and shared by every instance.

const RUBBLE: int = 0
const BLOCK: int = 1
const DRUM: int = 2

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: TerminalSkin:
	get:
		return _skin.get_ref() as TerminalSkin
var _skin: WeakRef
var _meshes: Dictionary = {}


func _init(p_skin: TerminalSkin) -> void:
	_skin = weakref(p_skin)


# --- Electric fence --------------------------------------------------------------------

func fence(hazard: Hazard, size: Vector3, ground_y: float, gapped: bool) -> void:
	var a: int = MeshKit.key(hazard.position.x)
	var b: int = MeshKit.key(hazard.position.z)
	var mounts: ArrayMesh = _mounts(size, ground_y, gapped, MeshKit.hash_i(a, b, 3) % 3, MeshKit.hash_i(a, b, 4) % 3)
	MeshKit.dress_fence(hazard, size, mounts, skin.fence_field_materials(), skin.fence_part_materials())


## Rusted steel posts with glowing insulator caps on both ends of the field, each set in a heap of rubble, a concrete block or
## a rusted drum, plus the shared bars and emitters.
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
			0.0, MeshKit.PAT_TERMINAL_STEEL, MeshKit.NO_BOTTOM, 2.0)
		hot.box(Vector3(x, pole_top + 0.04, 0), Vector3(0.17, 0.08, 0.17), skin.fence_color, 0.9)
		match left if side < 0.0 else right:
			RUBBLE:
				_rubble(solid, Vector3(x, ground_y, 0), side)
			BLOCK:
				_block(solid, Vector3(x + side * 0.05, ground_y, 0))
			_:
				_drum(solid, Vector3(x, ground_y, 0), side)
	MeshKit.fence_bars(hot, size, ground_y, gapped, post_x, skin.fence_color)
	var mesh: ArrayMesh = batch.to_mesh()
	_meshes[id] = mesh
	return mesh


## Chunks of broken concrete piled around a post's foot, within 0.3 m of it, with a bent rebar rod sticking out.
func _rubble(s: MeshLayer, foot: Vector3, side: float) -> void:
	var chunks: Array[Vector3] = [Vector3(-0.15, 0.09, 0.13), Vector3(0.14, 0.07, -0.11), Vector3(0.03, 0.17, 0.0),
		Vector3(-0.09, 0.06, -0.17), Vector3(0.12, 0.05, 0.16)]
	var sizes: Array[Vector3] = [Vector3(0.26, 0.2, 0.24), Vector3(0.26, 0.16, 0.28), Vector3(0.22, 0.16, 0.2),
		Vector3(0.2, 0.13, 0.18), Vector3(0.18, 0.11, 0.16)]
	for i: int in chunks.size():
		var turn := Basis.from_euler(Vector3(0.25 * float(i % 2) - 0.12, 0.8 * i, 0.18 * (float(i) - 2.0)))
		var offset: Vector3 = chunks[i] * Vector3(side, 1.0, 1.0)
		s.box_xform(Transform3D(turn.scaled_local(sizes[i]), foot + offset), skin.concrete_color.darkened(0.08 * i), 0.0,
			MeshKit.PAT_TERMINAL_WALL, MeshKit.NO_BOTTOM, 2.0)
	var rod := Basis.from_euler(Vector3(0.5, 0.0, side * 0.7)).scaled_local(Vector3(0.025, 0.5, 0.025))
	s.box_xform(Transform3D(rod, foot + Vector3(-side * 0.05, 0.3, -0.12)), skin.rust_color, 0.0, MeshKit.PAT_TERMINAL_STEEL,
		MeshKit.ALL_FACES, 2.0)


## A concrete block the post stands in: a low, tapered block along the track.
func _block(s: MeshLayer, foot: Vector3) -> void:
	var concrete: Color = skin.concrete_color
	s.box(foot + Vector3(0, 0.15, 0), Vector3(0.36, 0.3, 0.7), concrete, 0.0, MeshKit.PAT_TERMINAL_WALL, MeshKit.NO_BOTTOM, 2.0)
	s.box(foot + Vector3(0, 0.45, 0), Vector3(0.2, 0.3, 0.66), concrete.darkened(0.1), 0.0, MeshKit.PAT_TERMINAL_WALL,
		MeshKit.NO_BOTTOM, 2.0)


## A rusted drum the post is lashed to: a squat prism with a lid ring.
func _drum(s: MeshLayer, foot: Vector3, side: float) -> void:
	var rust: Color = skin.steel_color.lerp(skin.rust_color, 0.6)
	s.prism(foot + Vector3(side * 0.04, 0.0, 0.0), 0.2, 0.46, 8, rust, 0.0, MeshKit.PAT_TERMINAL_STEEL, true, 0.0)
	s.prism(foot + Vector3(side * 0.04, 0.4, 0.0), 0.21, 0.06, 8, rust.darkened(0.3), 0.0, MeshKit.PAT_TERMINAL_STEEL, true, 0.0)


# --- Sign -----------------------------------------------------------------------------
# A dead departure board bolted to a pier: a solid box in the yellow/black hazard frame around dark glass in a worn frame
# (wordless). The frame reads as solid and dangerous from the approach and above; nothing in it glows but the frame.

func wall_sign(hazard: Hazard, size: Vector3) -> void:
	var side: int = 1 if hazard.position.x > 0.0 else -1
	var k: int = MeshKit.hash_i(MeshKit.key(hazard.position.z), MeshKit.key(hazard.position.y), 21)
	var content: Color = skin.sign_content_colors[k % skin.sign_content_colors.size()]
	MeshBatch.add_instance(hazard, MeshKit.hazard_sign(size, side, skin.sign_frame_color, content, 0.0,
		MeshKit.PAT_TERMINAL_BOARD, float((k >> 10) % 100), 0.0, skin.solid_material(), skin.glow_material()))
