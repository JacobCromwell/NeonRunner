class_name CityProps
extends RefCounted
## City visuals for hazards, triggers and the finish (CitySkin). Hazards and triggers keep the
## cross-zone language from MeshKit: the pink crackling field for electric fences, the yellow/black
## striped frame for signs, cyan pads, green ramps and speed pads. Meshes are cached by size and
## shared by every instance.

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: CitySkin:
	get:
		return _skin.get_ref() as CitySkin
var _skin: WeakRef
var _meshes: Dictionary = {}


func _init(p_skin: CitySkin) -> void:
	_skin = weakref(p_skin)


# --- Electric fence --------------------------------------------------------------------
# GDD §9.1: a pink energy barrier built into the truck, powered from futuristic exhaust stacks.
# Full fences: a glowing bar along the field's top (jump over it). Gapped fences: the field hangs
# between tall stacks with a bar along its bottom edge and open roof below (slide under it).
# Pulsing fences: ON crackles, WARNING sputters (with HazardTelegraph's sound), OFF shows no field
# and only dim bars and nozzles.
# DESIGN-TBD: the edge bars and the OFF look are proposals; the GDD fixes only the pink crackle.

func fence(hazard: Hazard, size: Vector3, ground_y: float, gapped: bool) -> void:
	MeshKit.dress_fence(hazard, size, _stack_mesh(size, ground_y, gapped), skin.fence_field_materials(),
		skin.fence_part_materials())


func _stack_mesh(size: Vector3, ground_y: float, gapped: bool) -> ArrayMesh:
	var id: String = "stacks_%s_%s_%s" % [size, ground_y, gapped]
	if _meshes.has(id):
		return _meshes[id]
	var batch := MeshBatch.new()
	var metal: MeshLayer = batch.layer(skin.solid_material())
	var hot: MeshLayer = batch.layer(skin.fence_part_materials()[0])
	var stack_top: float = size.y * 0.5 + 0.3
	var r: float = 0.075
	var post_x: float = size.x * 0.5 + 0.06
	for side: float in [-1.0, 1.0]:
		var x: float = side * post_x
		metal.box(Vector3(x, ground_y + 0.06, 0), Vector3(0.3, 0.12, 0.34), Color(0.1, 0.1, 0.13), 0.0, MeshKit.PAT_PLAIN,
			MeshKit.NO_BOTTOM)
		metal.prism(Vector3(x, ground_y + 0.12, 0), r, stack_top - ground_y - 0.12, 6, skin.fence_stack_color, 0.0,
			MeshKit.PAT_PLAIN, false)
		# Flared nozzle at the top, glowing pink.
		hot.prism(Vector3(x, stack_top, 0), r * 1.6, 0.14, 6, skin.fence_color, 0.9)
	MeshKit.fence_bars(hot, size, ground_y, gapped, post_x, skin.fence_color)
	var mesh: ArrayMesh = batch.to_mesh()
	_meshes[id] = mesh
	return mesh


# --- Sign -----------------------------------------------------------------------------
# A neon billboard jutting out of the facade: a solid box in a yellow/black hazard frame around
# glowing glyph content. The frame reads as solid and dangerous from the approach and above.

func wall_sign(hazard: Hazard, size: Vector3) -> void:
	var side: int = 1 if hazard.position.x > 0.0 else -1
	var color_index: int = MeshKit.hash_i(MeshKit.key(hazard.position.z), MeshKit.key(hazard.position.y), 21) \
		% skin.sign_content_colors.size()
	MeshBatch.add_instance(hazard, MeshKit.hazard_sign(size, side, skin.sign_frame_color,
		skin.sign_content_colors[color_index], 0.55, MeshKit.PAT_GLYPHS, 0.6, 0.1, skin.solid_material(),
		skin.glow_material()))


# --- Triggers and finish (shared looks, city metal) --------------------------------------

func pad(trigger: Area3D, size: Vector3) -> void:
	MeshBatch.add_instance(trigger, MeshKit.lift_pad(size, skin.pad_color, Color(0.1, 0.11, 0.14), skin.pad_beam_height,
		skin.solid_material(), skin.glow_material()))


func ramp(trigger: Area3D, size: Vector3, side: int) -> void:
	MeshBatch.add_instance(trigger, MeshKit.kicker_ramp(size, side, skin.ramp_color, Color(0.12, 0.13, 0.16),
		skin.solid_material(), skin.glow_material()))


func speed_pad(trigger: Area3D, size: Vector3) -> void:
	MeshBatch.add_instance(trigger, MeshKit.speed_strip(size, skin.speed_pad_color, Color(0.1, 0.11, 0.14),
		skin.solid_material(), skin.glow_material()))


func finish_line(parent: Node3D, width: float, distance: float) -> void:
	var batch := MeshBatch.new()
	MeshKit.finish_gate(batch, skin.solid_material(), skin.glow_material(), width, distance, skin.finish_color,
		Color(0.1, 0.1, 0.13))
	batch.commit(parent)
