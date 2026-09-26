class_name CityProps
extends RefCounted
## City visuals for hazards, triggers and the finish (CitySkin). Hazards keep the cross-zone
## language from MeshKit: the pink crackling field for electric fences, the yellow/black striped
## frame for signs. Meshes are cached by size and shared by every instance.

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

func fence(hazard: Hazard, size: Vector3, ground_y: float, gapped: bool) -> void:
	# The visible field is a little larger than the hitbox (GDD §3: hitboxes err in the player's favour).
	var field_size: Vector3 = size + Vector3(0.06, 0.08, 0.0)
	var field: MeshInstance3D = MeshBatch.add_instance(hazard, MeshKit.energy_field_mesh(field_size))
	var stacks: MeshInstance3D = MeshBatch.add_instance(hazard, _stack_mesh(size, ground_y, gapped))
	var visual := HazardStateVisual.new()
	hazard.add_child(visual)
	visual.add_target(field, -1, skin.fence_field_materials())
	visual.add_target(stacks, 1, skin.fence_part_materials())
	visual.bind(hazard)


func _stack_mesh(size: Vector3, ground_y: float, gapped: bool) -> ArrayMesh:
	var id: String = "stacks_%s_%s_%s" % [size, ground_y, gapped]
	if _meshes.has(id):
		return _meshes[id]
	var batch := MeshBatch.new()
	var metal: MeshLayer = batch.layer(skin.solid_material())
	var hot: MeshLayer = batch.layer(skin.fence_part_materials()[0])
	var top: float = size.y * 0.5
	var bottom: float = -size.y * 0.5
	var stack_top: float = top + 0.3
	var r: float = 0.075
	var pink: Color = skin.fence_color
	for side: float in [-1.0, 1.0]:
		var x: float = side * (size.x * 0.5 + 0.06)
		metal.box(Vector3(x, ground_y + 0.06, 0), Vector3(0.3, 0.12, 0.34), Color(0.1, 0.1, 0.13), 0.0, MeshKit.PAT_PLAIN,
			MeshKit.NO_BOTTOM)
		metal.prism(Vector3(x, ground_y + 0.12, 0), r, stack_top - ground_y - 0.12, 6, skin.fence_stack_color, 0.0,
			MeshKit.PAT_PLAIN, false)
		# Flared nozzle at the top, glowing pink.
		hot.prism(Vector3(x, stack_top, 0), r * 1.6, 0.14, 6, pink, 0.9)
		# Emitters where the field meets the stack.
		for y: float in [top, bottom]:
			if y > ground_y + 0.05:
				hot.box(Vector3(x - side * 0.02, y, 0), Vector3(0.12, 0.06, 0.12), pink, 1.0)
	# The bar you jump over (full) or slide under (gapped).
	var bar_y: float = bottom if gapped else top
	hot.box(Vector3(0, bar_y, 0), Vector3(size.x + 0.1, 0.045, 0.045), pink, 0.9)
	if gapped:
		hot.box(Vector3(0, top, 0), Vector3(size.x + 0.1, 0.035, 0.035), pink, 0.7)
	var mesh: ArrayMesh = batch.to_mesh()
	_meshes[id] = mesh
	return mesh


# --- Sign -----------------------------------------------------------------------------
# A neon billboard jutting out of the facade: a solid box in a yellow/black hazard frame around
# glowing glyph content. The frame reads as solid and dangerous from the approach and above.
# DESIGN-TBD: the yellow/black hazard frame is the proposed sign language for every zone.

func wall_sign(hazard: Hazard, size: Vector3) -> void:
	var side: int = 1 if hazard.position.x > 0.0 else -1
	var color_index: int = MeshKit.hash_i(MeshKit.key(hazard.position.z), MeshKit.key(hazard.position.y), 21) \
		% skin.sign_content_colors.size()
	MeshBatch.add_instance(hazard, _sign_mesh(size, side, color_index))


func _sign_mesh(size: Vector3, side: int, color_index: int) -> ArrayMesh:
	var id: String = "sign_%s_%d_%d" % [size, side, color_index]
	if _meshes.has(id):
		return _meshes[id]
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(skin.solid_material())
	var g: MeshLayer = batch.layer(skin.glow_material())
	# Grow toward the track and along its length, never into the wall.
	var grow := Vector3(0.08, 0.1, 0.12)
	var vis: Vector3 = size + grow
	var center := Vector3(-side * grow.x * 0.5, 0, 0)
	var rail: float = clampf(vis.y * 0.14, 0.12, 0.26)
	MeshKit.hazard_frame(s, center, vis, rail, skin.sign_frame_color, 0.35)
	var inner := Vector3(vis.x - 0.12, vis.y - rail * 2.0, vis.z - rail * 2.0)
	var content: Color = skin.sign_content_colors[color_index]
	if inner.y > 0.05 and inner.z > 0.05:
		s.box(center + Vector3(side * 0.06, 0, 0), inner, Color(0.03, 0.03, 0.05), 0.0, MeshKit.PAT_PLAIN,
			MeshKit.FACE_PX if side < 0 else MeshKit.FACE_NX)
		var face_x: float = center.x - side * (vis.x * 0.5 - 0.06)
		var y0: float = -inner.y * 0.5
		var zh: float = inner.z * 0.5
		# The panel faces the track; its glyphs read (and scroll) left to right as seen from the lanes.
		if side > 0:
			s.rect(Vector3(face_x, y0, -zh), Vector3(0, 0, inner.z), Vector3(0, inner.y, 0), content, 0.55,
				MeshKit.PAT_GLYPHS, Vector2(0, 0), Vector2(inner.z, inner.y), 0.6)
		else:
			s.rect(Vector3(face_x, y0, zh), Vector3(0, 0, -inner.z), Vector3(0, inner.y, 0), content, 0.55,
				MeshKit.PAT_GLYPHS, Vector2(0, 0), Vector2(inner.z, inner.y), 0.6)
		g.rect(Vector3(face_x - side * 0.25, y0 - 0.3, -zh - 0.3), Vector3(0, 0, inner.z + 0.6), Vector3(0, inner.y + 0.6, 0),
			content, 0.1, MeshKit.SHAPE_FLAT)
	var mesh: ArrayMesh = batch.to_mesh()
	_meshes[id] = mesh
	return mesh


# --- Anti-grav pad ----------------------------------------------------------------------
# Cyan: a flush lift plate on the truck roof with a light column rising toward the ship above.

func pad(trigger: Area3D, size: Vector3) -> void:
	var id: String = "pad_%s" % size
	if not _meshes.has(id):
		var batch := MeshBatch.new()
		var s: MeshLayer = batch.layer(skin.solid_material())
		var g: MeshLayer = batch.layer(skin.glow_material())
		var y0: float = -size.y * 0.5
		var c: Color = skin.pad_color
		s.box(Vector3(0, y0 + 0.02, 0), Vector3(size.x + 0.2, 0.04, size.z + 0.2), Color(0.1, 0.11, 0.14), 0.0,
			MeshKit.PAT_PLAIN, MeshKit.NO_BOTTOM)
		for inset: float in [0.0, 0.28, 0.52]:
			_ring(s, Vector3(0, y0 + 0.045, 0), size.x - inset * 2.0, size.z - inset * 2.0, 0.07, c, 0.9 - inset)
		s.box(Vector3(0, y0 + 0.05, 0), Vector3(0.3, 0.02, 0.3), c, 1.0)
		g.rect(Vector3(-size.x * 0.9, y0 + 0.06, size.z * 0.9), Vector3(size.x * 1.8, 0, 0), Vector3(0, 0, -size.z * 1.8),
			c, 0.5, MeshKit.SHAPE_RADIAL)
		var h: float = skin.pad_beam_height
		var bx: float = size.x * 0.42
		var bz: float = size.z * 0.42
		g.rect(Vector3(-bx, y0, bz), Vector3(bx * 2.0, 0, 0), Vector3(0, h, 0), c, 0.45, MeshKit.SHAPE_RISE)
		g.rect(Vector3(-bx, y0, -bz), Vector3(bx * 2.0, 0, 0), Vector3(0, h, 0), c, 0.45, MeshKit.SHAPE_RISE)
		g.rect(Vector3(-bx, y0, -bz), Vector3(0, 0, bz * 2.0), Vector3(0, h, 0), c, 0.45, MeshKit.SHAPE_RISE)
		g.rect(Vector3(bx, y0, -bz), Vector3(0, 0, bz * 2.0), Vector3(0, h, 0), c, 0.45, MeshKit.SHAPE_RISE)
		_meshes[id] = batch.to_mesh()
	MeshBatch.add_instance(trigger, _meshes[id])


# --- Ramp -------------------------------------------------------------------------------
# Green: a kicker plate banked up toward the wall, with arrows streaming toward the wall.

func ramp(trigger: Area3D, size: Vector3, side: int) -> void:
	var id: String = "ramp_%s_%d" % [size, side]
	if not _meshes.has(id):
		var batch := MeshBatch.new()
		var s: MeshLayer = batch.layer(skin.solid_material())
		var g: MeshLayer = batch.layer(skin.glow_material())
		var y0: float = -size.y * 0.5
		var hx: float = size.x * 0.5
		var hz: float = size.z * 0.5
		var low: float = y0 + 0.05
		var high: float = y0 + 0.45
		var c: Color = skin.ramp_color
		var metal := Color(0.12, 0.13, 0.16)
		var sd: float = float(side)
		# Corners: inner edge low, wall-side edge high.
		var in_n := Vector3(-sd * hx, low, hz)
		var in_f := Vector3(-sd * hx, low, -hz)
		var out_n := Vector3(sd * hx, high, hz)
		var out_f := Vector3(sd * hx, high, -hz)
		var base_n := Vector3(sd * hx, y0, hz)
		var base_f := Vector3(sd * hx, y0, -hz)
		var in_bn := Vector3(-sd * hx, y0, hz)
		var in_bf := Vector3(-sd * hx, y0, -hz)
		# The top's UV.x runs from its first corner across; the chevron direction (param) points at the wall.
		if side > 0:
			s.quad(in_n, in_f, out_f, out_n, c, 0.8, MeshKit.PAT_CHEVRON, 1.0)
			s.quad(in_bn, in_n, out_n, base_n, metal)
			s.quad(base_n, out_n, out_f, base_f, metal)
			s.quad(in_bf, in_f, in_n, in_bn, metal)
		else:
			s.quad(out_n, out_f, in_f, in_n, c, 0.8, MeshKit.PAT_CHEVRON, -1.0)
			s.quad(base_n, out_n, in_n, in_bn, metal)
			s.quad(base_f, out_f, out_n, base_n, metal)
			s.quad(in_bn, in_n, in_f, in_bf, metal)
		# Glowing rails along the high edge and the sloped front edge.
		s.box((out_n + out_f) * 0.5 + Vector3(0, 0.02, 0), Vector3(0.06, 0.05, size.z), c, 1.0)
		var rise: float = high - low
		var front := Basis(Vector3.BACK, sd * atan2(rise, size.x)).scaled_local(
			Vector3(sqrt(size.x * size.x + rise * rise), 0.05, 0.05))
		s.box_xform(Transform3D(front, (in_n + out_n) * 0.5 + Vector3(0, 0.02, 0.02)), c, 0.8)
		g.rect(Vector3(-hx * 1.4, y0 + 0.08, hz * 1.3), Vector3(hx * 2.8, 0, 0), Vector3(0, 0, -hz * 2.6), c, 0.35,
			MeshKit.SHAPE_RADIAL)
		_meshes[id] = batch.to_mesh()
	MeshBatch.add_instance(trigger, _meshes[id])


# --- Finish line ------------------------------------------------------------------------

func finish_line(parent: Node3D, width: float, distance: float) -> void:
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(skin.solid_material())
	var g: MeshLayer = batch.layer(skin.glow_material())
	var z: float = -distance
	var c: Color = skin.finish_color
	var metal := Color(0.1, 0.1, 0.13)
	s.box(Vector3(0, 0.03, z), Vector3(width, 0.04, 1.2), c, 0.6, MeshKit.PAT_CHECKER, MeshKit.NO_BOTTOM)
	var px: float = width * 0.5 + 0.2
	for side: float in [-1.0, 1.0]:
		s.box(Vector3(side * px, 4.5, z), Vector3(0.5, 13.0, 0.5), metal)
		s.box(Vector3(side * (px - 0.26), 4.5, z + 0.1), Vector3(0.04, 12.5, 0.08), c, 0.7)
	s.box(Vector3(0, 10.4, z), Vector3(width + 0.9, 1.3, 0.6), metal)
	s.box(Vector3(0, 10.4, z + 0.32), Vector3(width, 0.9, 0.04), c, 0.8, MeshKit.PAT_CHECKER)
	g.rect(Vector3(-width * 0.6, 8.8, z + 0.4), Vector3(width * 1.2, 0, 0), Vector3(0, 3.2, 0), c, 0.18, MeshKit.SHAPE_FLAT)
	g.rect(Vector3(-width * 0.5, 0.06, z + 1.5), Vector3(width, 0, 0), Vector3(0, 0, -3.0), c, 0.2, MeshKit.SHAPE_STREAK)
	batch.commit(parent)


static func _ring(s: MeshLayer, center: Vector3, w: float, d: float, t: float, color: Color, glow: float) -> void:
	s.box(center + Vector3(0, 0, d * 0.5 - t * 0.5), Vector3(w, 0.02, t), color, glow, MeshKit.PAT_PLAIN, MeshKit.FACE_PY)
	s.box(center - Vector3(0, 0, d * 0.5 - t * 0.5), Vector3(w, 0.02, t), color, glow, MeshKit.PAT_PLAIN, MeshKit.FACE_PY)
	s.box(center + Vector3(w * 0.5 - t * 0.5, 0, 0), Vector3(t, 0.02, d - t * 2.0), color, glow, MeshKit.PAT_PLAIN, MeshKit.FACE_PY)
	s.box(center - Vector3(w * 0.5 - t * 0.5, 0, 0), Vector3(t, 0.02, d - t * 2.0), color, glow, MeshKit.PAT_PLAIN, MeshKit.FACE_PY)
