class_name DeadDoodads
extends RefCounted
## The Dead Zone's zone doodads (DeadZoneSkin.doodad; GDD §3, owner's playtest September 30, 2026;
## task G6: "wrecks, rubble heaps, fallen masonry"): a crushed, ash-dusted wreck (small), a rubble
## heap (medium) and a fallen slab of masonry leaning across the lane (large). Variety comes from
## hashing `look_seed` (MeshKit.hash_i), so a doodad looks the same wherever and whenever it is built.
## Every doodad is one mesh on MeshKit.solid() alone (never a zone's own tuned material), and never
## glows (test_doodads' _test_skins, test_dead_zone_skin's doodads_ok): on the zone's near-black
## palette nothing here competes with the fence's pink or a sign's yellow and black. Meshes are cached
## by size, side and seed and shared by every instance.

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: DeadZoneSkin:
	get:
		return _skin.get_ref() as DeadZoneSkin
var _skin: WeakRef
var _meshes: Dictionary = {}


func _init(p_skin: DeadZoneSkin) -> void:
	_skin = weakref(p_skin)


func build(body: Node3D, size: Vector3, size_class: StringName, side: int, look_seed: int) -> void:
	var mesh: ArrayMesh = _mesh_for(size, size_class, side, look_seed)
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = MeshKit.solid()
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(inst)


func _mesh_for(size: Vector3, size_class: StringName, side: int, look_seed: int) -> ArrayMesh:
	var id: String = "dead_doodad_%s_%s_%d_%d" % [size, size_class, side, look_seed]
	if _meshes.has(id):
		return _meshes[id]
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(null)
	match size_class:
		&"small":
			_wreck(s, size, look_seed)
		&"medium":
			_rubble_heap(s, size, look_seed)
		_:
			_masonry(s, size, look_seed)
	# Its main colours, which its pieces fly off in when the dash smashes it (ZoneSkin.doodad_debris_colors).
	var mesh: ArrayMesh = ZoneSkin.tag_debris_colors(batch.to_mesh(), batch)
	_meshes[id] = mesh
	return mesh


## A crushed, burnt-out wreck: a low hulk with rubble piled on it up to the box's top, so it reads too
## tall to jump the whole way across, never as a car alone.
func _wreck(s: MeshLayer, size: Vector3, look_seed: int) -> void:
	var sk: DeadZoneSkin = skin
	var hy: float = size.y * 0.5
	var hull_h: float = minf(0.85, size.y * 0.38)
	s.box(Vector3(0, -hy + hull_h * 0.5, 0), Vector3(size.x * 0.84, hull_h, size.z * 0.86), sk.wreck_color, 0.0,
		MeshKit.PAT_DZ_STEEL, MeshKit.NO_BOTTOM, 1.0)
	var cab_h: float = minf(0.4, size.y * 0.18)
	s.box(Vector3(0, -hy + hull_h + cab_h * 0.5, 0), Vector3(size.x * 0.62, cab_h, size.z * 0.5), sk.wreck_color.darkened(0.25),
		0.0, MeshKit.PAT_DZ_STEEL, MeshKit.NO_BOTTOM)
	var pile_y0: float = -hy + hull_h + cab_h
	var pile_h: float = hy - pile_y0 - 0.05
	if pile_h > 0.12:
		var pieces: int = 3
		for i: int in pieces:
			var h: float = pile_h / float(pieces) * lerpf(0.75, 1.0, MeshKit.hash01(look_seed, i, 13))
			var y0: float = pile_y0 + pile_h * float(i) / float(pieces)
			var w: float = size.x * lerpf(0.4, 0.74, MeshKit.hash01(look_seed, i, 17))
			var d: float = size.z * lerpf(0.3, 0.55, MeshKit.hash01(look_seed, i, 19))
			var x: float = (MeshKit.hash01(look_seed, i, 11) - 0.5) * (size.x - w)
			var z: float = (MeshKit.hash01(look_seed, i, 12) - 0.5) * (size.z - d)
			var color: Color = (sk.rubble_color if i % 2 == 0 else sk.steel_color).darkened(0.08 * float(i))
			s.box(Vector3(x, y0 + h * 0.5, z), Vector3(w, h, d), color, 0.0, MeshKit.PAT_DZ_CONCRETE, MeshKit.NO_BOTTOM)


## A heap of broken, ash-covered concrete filling the box: irregular stacked chunks, smaller toward
## the top, a bent rebar rod standing out of the pile.
func _rubble_heap(s: MeshLayer, size: Vector3, look_seed: int) -> void:
	var sk: DeadZoneSkin = skin
	var hy: float = size.y * 0.5
	var layers: int = 5
	var top_margin: float = 0.08
	var h0: float = -hy
	for i: int in layers:
		var t: float = float(i) / float(layers)
		var shrink: float = lerpf(0.92, 0.42, t)
		var w: float = size.x * shrink
		var d: float = size.z * lerpf(0.88, 0.38, t)
		var h: float = (size.y - top_margin) / float(layers) * lerpf(0.8, 1.05, MeshKit.hash01(look_seed, i, 21))
		var x: float = (MeshKit.hash01(look_seed, i, 22) - 0.5) * (size.x - w)
		var z: float = (MeshKit.hash01(look_seed, i, 23) - 0.5) * (size.z - d)
		var y1: float = minf(h0 + h, hy - top_margin)
		var color: Color = sk.rubble_color.darkened(0.06 * float(i) + 0.08 * MeshKit.hash01(look_seed, i, 24))
		s.box(Vector3(x, (h0 + y1) * 0.5, z), Vector3(w, y1 - h0, d), color, 0.0, MeshKit.PAT_DZ_CONCRETE, MeshKit.NO_BOTTOM)
		h0 = y1
	var rod_h: float = minf(0.6, hy - h0 - 0.04)
	if rod_h > 0.08:
		s.box(Vector3(0, h0 + rod_h * 0.5, 0), Vector3(0.04, rod_h, 0.04), sk.steel_color.darkened(0.3))


## A slab of fallen masonry leaning across the lane at a shallow angle from vertical: nearly as tall
## as the box, its long axis tilted a little so it reads as fallen rather than built (the tilt kept
## small, and the slab's own half-length budgeted against the box's height, so it never crosses the
## box whatever the seed picks). A broken, crumbled edge, rebar sticking out, a couple of chunks of
## rubble fallen at its foot.
func _masonry(s: MeshLayer, size: Vector3, look_seed: int) -> void:
	var sk: DeadZoneSkin = skin
	var hy: float = size.y * 0.5
	var hz: float = size.z * 0.5
	var angle: float = lerpf(0.2, 0.34, MeshKit.hash01(look_seed, 1)) * (1.0 if MeshKit.hash_i(look_seed, 2) % 2 == 0 else -1.0)
	var thickness: float = 0.24
	var length: float = size.y * 0.9
	var half_len: float = length * 0.5
	# The slab's own bounding half-extent once tilted (its long axis starts near vertical, so its
	# sideways reach stays small next to `hz` and never needs budgeting against it).
	var half_y_eff: float = half_len * cos(angle) + thickness * 0.5 * sin(absf(angle))
	var basis := Basis(Vector3.RIGHT, angle)
	# Its low end rests near the floor; the lean leaves clear margin at the top.
	var center_y: float = -hy + 0.06 + half_y_eff
	s.box_xform(Transform3D(basis.scaled_local(Vector3(size.x * 0.8, length, thickness)), Vector3(0, center_y, 0)),
		sk.slab_color, 0.0, MeshKit.PAT_DZ_CONCRETE, MeshKit.ALL_FACES, 1.0)
	# A broken, crumbled edge at the slab's low end, nudged a little inward so it never dips below the box.
	var low_end: Vector3 = Vector3(0, center_y, 0) + basis * Vector3(0, -half_len + 0.08, 0)
	s.box_xform(Transform3D(basis.scaled_local(Vector3(size.x * 0.68, 0.12, thickness * 1.4)), low_end), sk.rubble_color,
		0.0, MeshKit.PAT_DZ_CONCRETE, MeshKit.ALL_FACES, 0.0)
	# A short bent rebar rod by the broken edge, tilted with the same lean (never a steeper one, so it
	# never reaches further than the edge box already budgeted for).
	var rod_len: float = half_len * 0.3
	s.box_xform(Transform3D(basis.scaled_local(Vector3(0.03, rod_len, 0.03)), low_end + Vector3(size.x * 0.16, rod_len * 0.5, 0.0)),
		sk.steel_color.darkened(0.3), 0.0, MeshKit.PAT_DZ_STEEL)
	# Rubble fallen at its foot, axis-aligned and inset so it always fits inside the box.
	for i: int in 2:
		var rs := Vector3(0.3 + 0.18 * MeshKit.hash01(look_seed, i, 31), 0.2 + 0.1 * MeshKit.hash01(look_seed, i, 32),
			0.3 + 0.18 * MeshKit.hash01(look_seed, i, 33))
		var rx: float = (MeshKit.hash01(look_seed, i, 34) - 0.5) * (size.x - rs.x)
		var rz: float = lerpf(-hz + rs.z * 0.5, -hz * 0.2, MeshKit.hash01(look_seed, i, 35))
		s.box(Vector3(rx, -hy + rs.y * 0.5, rz), rs, sk.rubble_color.darkened(0.1 * float(i)), 0.0, MeshKit.PAT_DZ_CONCRETE,
			MeshKit.NO_BOTTOM)
