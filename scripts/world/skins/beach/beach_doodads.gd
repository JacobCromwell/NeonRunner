class_name BeachDoodads
extends RefCounted
## The Beach's zone doodads (BeachSkin.doodad; GDD §3, owner's playtest September 30, 2026; task G6's rules; the
## Beach's own three, task D10): a surfboard rack (small: boards standing upright in a bamboo frame), a beach
## cabana (bamboo walls under a thatch roof) or a palm in a big timber planter (medium, picked by look_seed),
## and a tiki bar kiosk (large: a counter, bamboo corner poles and a flat thatch canopy).
## Every doodad is one mesh on MeshKit.solid() alone (never a zone's own tuned material), fills most of its box
## and stays inside it, in muted colours, never glowing, with no faces (no tiki masks) and nothing that reads
## as a sign, a fence or a barrier (test_doodads' _test_skins, test_beach_skin's doodads_ok). Meshes are cached by
## size, side and seed and shared by every instance.
## DESIGN-TBD (docs/OPEN_QUESTIONS.md, item 548): the three looks are a proposal, built from the owner's brief.

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: BeachSkin:
	get:
		return _skin.get_ref() as BeachSkin
var _skin: WeakRef
var _meshes: Dictionary = {}


func _init(p_skin: BeachSkin) -> void:
	_skin = weakref(p_skin)


func build(body: Node3D, size: Vector3, size_class: StringName, side: int, look_seed: int) -> void:
	var mesh: ArrayMesh = _mesh_for(size, size_class, side, look_seed)
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = MeshKit.solid()
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(inst)


func _mesh_for(size: Vector3, size_class: StringName, side: int, look_seed: int) -> ArrayMesh:
	var id: String = "beach_doodad_%s_%s_%d_%d" % [size, size_class, side, look_seed]
	if _meshes.has(id):
		return _meshes[id]
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(null)
	match size_class:
		&"small":
			_rack(s, size, look_seed)
		&"medium":
			if MeshKit.hash_i(look_seed, 4) % 2 == 0:
				_cabana(s, size, look_seed)
			else:
				_palm(s, size, look_seed)
		_:
			_kiosk(s, size, look_seed)
	var mesh: ArrayMesh = batch.to_mesh()
	_meshes[id] = mesh
	return mesh


## A paint colour of the skin, picked by hash.
func _paint(look_seed: int, i: int) -> Color:
	return skin.paint_colors[MeshKit.hash_i(look_seed, i, 6) % skin.paint_colors.size()]


## A surfboard rack: a timber base, two bamboo end frames with a top rail, and four boards standing upright in
## it in muted paints with a pale stripe, filling the box's height.
func _rack(s: MeshLayer, size: Vector3, look_seed: int) -> void:
	var hx: float = size.x * 0.5
	var hz: float = size.z * 0.5
	var floor_y: float = -size.y * 0.5
	var base_h: float = 0.22
	s.box(Vector3(0, floor_y + base_h * 0.5, 0), Vector3(size.x * 0.92, base_h, size.z * 0.92), skin.timber_color, 0.0,
		MeshKit.PAT_BEACH_TIMBER, MeshKit.NO_BOTTOM, MeshKit.beach_timber_param(2, 1, look_seed))
	var top_y: float = floor_y + size.y - 0.06
	var post: Color = skin.post_color
	for x: float in [-hx * 0.8, hx * 0.8]:
		for z: float in [-hz * 0.82, hz * 0.82]:
			s.box(Vector3(x, (floor_y + base_h + top_y) * 0.5, z), Vector3(0.1, top_y - floor_y - base_h, 0.1), post, 0.0,
				MeshKit.PAT_BEACH_TIMBER, MeshKit.NO_BOTTOM, MeshKit.beach_timber_param(0, 0, look_seed))
	for z: float in [-hz * 0.82, hz * 0.82]:
		s.box(Vector3(0, top_y - 0.04, z), Vector3(hx * 1.6 + 0.1, 0.09, 0.09), post, 0.0, MeshKit.PAT_BEACH_TIMBER,
			MeshKit.ALL_FACES, MeshKit.beach_timber_param(1, 0, look_seed + 2))
		s.box(Vector3(0, floor_y + base_h + 0.7, z), Vector3(hx * 1.6 + 0.1, 0.07, 0.07), post, 0.0, MeshKit.PAT_BEACH_TIMBER,
			MeshKit.ALL_FACES, MeshKit.beach_timber_param(1, 0, look_seed + 4))
	var boards: int = 4
	var len: float = top_y - floor_y - base_h - 0.12
	for i: int in boards:
		var z: float = -hz * 0.55 + float(i) * hz * 1.1 / float(boards - 1)
		var col: Color = _paint(look_seed, i)
		var shape := Basis(Vector3(hx * 0.62, 0, 0), Vector3(0, 0, 0.05), Vector3(0, len * 0.5, 0))
		var cy: float = floor_y + base_h + len * 0.5 + 0.02
		s.prism_xform(Transform3D(shape, Vector3(0, cy, z)), 6, col, 0.0, MeshKit.PAT_PLAIN, true)
		s.box(Vector3(0, cy, z + 0.052), Vector3(0.1, len * 0.86, 0.012), skin.cream_color)


## A beach cabana: a bamboo hut with a dark doorway under a hipped thatch roof, filling the box.
func _cabana(s: MeshLayer, size: Vector3, look_seed: int) -> void:
	var hx: float = size.x * 0.5
	var hz: float = size.z * 0.5
	var floor_y: float = -size.y * 0.5
	var wall_h: float = size.y * 0.62
	var bamboo: Color = skin.bamboo_colors[look_seed % skin.bamboo_colors.size()]
	var wx: float = hx * 0.86
	var wz: float = hz * 0.92
	var t: float = 0.12
	# The walls: four slabs of bamboo (flush faces), the front (+z) with a dark doorway.
	s.box(Vector3(0, floor_y + 0.06, 0), Vector3(size.x * 0.96, 0.12, size.z * 0.98), skin.timber_color * 0.8, 0.0,
		MeshKit.PAT_BEACH_TIMBER, MeshKit.NO_BOTTOM, MeshKit.beach_timber_param(2, 1, look_seed))
	for x: float in [-wx, wx]:
		s.box(Vector3(x, floor_y + 0.12 + wall_h * 0.5, 0), Vector3(t, wall_h, wz * 2.0), bamboo, 0.0, MeshKit.PAT_BEACH_WALL,
			MeshKit.ALL_FACES & ~MeshKit.FACE_NY, float(look_seed % 97 * 8))
	s.box(Vector3(0, floor_y + 0.12 + wall_h * 0.5, -wz), Vector3(wx * 2.0, wall_h, t), bamboo, 0.0, MeshKit.PAT_BEACH_WALL,
		MeshKit.ALL_FACES & ~MeshKit.FACE_NY, float(look_seed % 97 * 8))
	var door_w: float = 0.9
	var door_h: float = wall_h * 0.75
	var jamb: float = wx - door_w * 0.5
	for x: float in [-(wx + door_w * 0.5) * 0.5, (wx + door_w * 0.5) * 0.5]:
		s.box(Vector3(x, floor_y + 0.12 + wall_h * 0.5, wz), Vector3(jamb, wall_h, t), bamboo, 0.0,
			MeshKit.PAT_BEACH_WALL, MeshKit.ALL_FACES & ~MeshKit.FACE_NY, float(look_seed % 97 * 8))
	s.box(Vector3(0, floor_y + 0.12 + door_h + (wall_h - door_h) * 0.5, wz), Vector3(door_w, wall_h - door_h, t), bamboo, 0.0,
		MeshKit.PAT_BEACH_WALL, MeshKit.ALL_FACES & ~MeshKit.FACE_NY, float(look_seed % 97 * 8))
	s.box(Vector3(0, floor_y + 0.12 + door_h * 0.5, wz - t * 0.35), Vector3(door_w, door_h, 0.02), skin.bamboo_dark_color * 0.5)
	# The hipped roof: eaves just inside the box, up to a ridge along the track.
	var eave_y: float = floor_y + 0.12 + wall_h
	var ridge_y: float = size.y * 0.5 - 0.02
	var ex: float = hx * 0.98
	var ez: float = hz * 0.99
	var rz: float = maxf(ez - ex * 1.2, 0.2)
	var thatch: Color = skin.thatch_color
	var pa := Vector3(-ex, eave_y, -ez)
	var pb := Vector3(-ex, eave_y, ez)
	var pc := Vector3(ex, eave_y, ez)
	var pd := Vector3(ex, eave_y, -ez)
	var r0 := Vector3(0, ridge_y, -rz)
	var r1 := Vector3(0, ridge_y, rz)
	_face(s, pa, pb, r1, r0, Vector3(-1, 1, 0), thatch)
	_face(s, pd, pc, r1, r0, Vector3(1, 1, 0), thatch)
	_face(s, pb, pc, r1, r1, Vector3(0, 1, 1), thatch * 0.95)
	_face(s, pa, pd, r0, r0, Vector3(0, 1, -1), thatch * 0.9)
	# The eaves' underside.
	s.rect(Vector3(-ex, eave_y - 0.01, ez), Vector3(ex * 2.0, 0, 0), Vector3(0, 0, -ez * 2.0), skin.thatch_dark_color, 0.0,
		MeshKit.PAT_PLAIN)


## A palm in a big timber planter: a long bamboo-banded timber box with soil, a leaning ringed palm at its middle
## and a clump of low fronds at each end, the crown's drooping fronds staying inside the box, filling its height.
func _palm(s: MeshLayer, size: Vector3, look_seed: int) -> void:
	var hx: float = size.x * 0.5
	var floor_y: float = -size.y * 0.5
	var px: float = hx * 0.84
	var pz: float = size.z * 0.5 * 0.94
	var ph: float = 0.72
	s.box(Vector3(0, floor_y + ph * 0.5, 0), Vector3(px * 2.0, ph, pz * 2.0), skin.timber_color, 0.0, MeshKit.PAT_BEACH_TIMBER,
		MeshKit.NO_BOTTOM, MeshKit.beach_timber_param(2, 1, look_seed))
	for y: float in [0.16, 0.5]:
		s.box(Vector3(0, floor_y + y, 0), Vector3(px * 2.0 + 0.06, 0.07, pz * 2.0 + 0.06), skin.post_color, 0.0, MeshKit.PAT_BEACH_TIMBER,
			MeshKit.ALL_FACES, MeshKit.beach_timber_param(2, 0, look_seed))
	s.rect(Vector3(-px + 0.06, floor_y + ph + 0.002, pz - 0.06), Vector3(px * 2.0 - 0.12, 0, 0), Vector3(0, 0, -(pz * 2.0 - 0.12)),
		skin.timber_color * 0.35, 0.0, MeshKit.PAT_PLAIN)
	# The palm: a leaning, ringed trunk to a crown near the top of the box.
	var crown_y: float = size.y * 0.5 - 0.3
	var lean: float = (MeshKit.hash01(look_seed, 8) - 0.5) * 0.4
	var segs: int = 4
	var base_y: float = floor_y + ph
	for i: int in segs:
		var f0: float = float(i) / float(segs)
		var f1: float = float(i + 1) / float(segs)
		var a := Vector3(lean * f0 * f0, lerpf(base_y, crown_y, f0), 0.0)
		var axis := Vector3(lean * f1 * f1, lerpf(base_y, crown_y, f1), 0.0) - a
		var r0: float = lerpf(0.13, 0.08, f0)
		s.prism_xform(Transform3D(Basis(Vector3(r0, 0, 0), axis, Vector3(0, 0, r0)), a), 6, skin.trunk_color, 0.0,
			MeshKit.PAT_BEACH_TIMBER, false, MeshKit.beach_timber_param(0, 2, look_seed))
	_crown(s, Vector3(lean, crown_y, 0.0), minf(hx * 0.9 - absf(lean), 0.82), 8, look_seed, 1.0)
	# A clump of low fronds in the planter at each end, along its length.
	for z: float in [-pz * 0.62, pz * 0.62]:
		_crown(s, Vector3(0.0, floor_y + ph + 0.35, z), minf(hx * 0.85, 0.7), 6, look_seed + 3, 0.7)


## A crown of `count` drooping fronds around `crown` reaching `reach` out, `scale` sizing the blades.
func _crown(s: MeshLayer, crown: Vector3, reach: float, count: int, look_seed: int, scale: float) -> void:
	for i: int in count:
		var ang: float = TAU * (float(i) + 0.3) / float(count)
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		var sd := Vector3(-dir.z, 0.0, dir.x)
		var col: Color = skin.frond_colors[(i + look_seed) % skin.frond_colors.size()]
		var pts: Array[Vector3] = [crown, crown + dir * reach * 0.4 + Vector3(0, 0.22 * scale, 0), crown + dir * reach * 0.75 + Vector3(0, 0.12 * scale, 0),
			crown + dir * reach + Vector3(0, -0.28 * scale, 0)]
		var widths: Array[float] = [0.08 * scale, 0.2 * scale, 0.17 * scale, 0.03 * scale]
		for k: int in 3:
			var a0: Vector3 = pts[k] - sd * widths[k]
			var a1: Vector3 = pts[k] + sd * widths[k]
			var b0: Vector3 = pts[k + 1] - sd * widths[k + 1]
			var b1: Vector3 = pts[k + 1] + sd * widths[k + 1]
			s.quad(a0, b0, b1, a1, col, 0.0)
			s.quad(a0, a1, b1, b0, col * 0.8, 0.0)


## A tiki bar kiosk: a bamboo back wall behind a counter with a painted front and a timber top, bottles on a
## shelf, four bamboo corner poles and a flat thatch canopy with a fringe, filling the box.
func _kiosk(s: MeshLayer, size: Vector3, look_seed: int) -> void:
	var hx: float = size.x * 0.5
	var hz: float = size.z * 0.5
	var floor_y: float = -size.y * 0.5
	var top_y: float = size.y * 0.5
	var bamboo: Color = skin.bamboo_colors[look_seed % skin.bamboo_colors.size()]
	s.box(Vector3(0, floor_y + 0.06, 0), Vector3(size.x * 0.98, 0.12, size.z * 0.98), skin.timber_color * 0.8, 0.0,
		MeshKit.PAT_BEACH_TIMBER, MeshKit.NO_BOTTOM, MeshKit.beach_timber_param(2, 1, look_seed))
	# The back wall (along the track, at -x) and the counter in front of it (+x).
	var wall_t: float = 0.14
	var wall_top: float = top_y - 0.5
	s.box(Vector3(-hx + wall_t * 0.5 + 0.06, (floor_y + 0.12 + wall_top) * 0.5, 0), Vector3(wall_t, wall_top - floor_y - 0.12, size.z - 0.5),
		bamboo, 0.0, MeshKit.PAT_BEACH_WALL, MeshKit.ALL_FACES & ~MeshKit.FACE_NY, float(look_seed % 97 * 8))
	var counter_h: float = 1.05
	var counter_x: float = hx - 0.42
	s.box(Vector3(counter_x, floor_y + 0.12 + counter_h * 0.5, 0), Vector3(0.6, counter_h, size.z - 1.0), _paint(look_seed, 1) * 0.9,
		0.0, MeshKit.PAT_BEACH_TIMBER, MeshKit.ALL_FACES & ~MeshKit.FACE_NY, MeshKit.beach_timber_param(2, 1, look_seed + 1))
	s.box(Vector3(counter_x, floor_y + 0.12 + counter_h + 0.04, 0), Vector3(0.7, 0.08, size.z - 0.9), skin.timber_color * 0.75)
	# A shelf of bottles on the back wall.
	s.box(Vector3(-hx + wall_t + 0.2, floor_y + 1.6, 0), Vector3(0.3, 0.06, size.z - 1.2), skin.timber_color * 0.7)
	var bottles: int = 10
	for i: int in bottles:
		var z: float = -(size.z - 1.8) * 0.5 + (size.z - 1.8) * (float(i) + 0.5) / float(bottles)
		s.box(Vector3(-hx + wall_t + 0.2, floor_y + 1.78, z), Vector3(0.09, 0.28, 0.09), _paint(look_seed, i + 3) * 0.85)
	# Four bamboo corner poles and the canopy.
	for x: float in [-hx + 0.1, hx - 0.1]:
		for z: float in [-hz + 0.1, hz - 0.1]:
			s.box(Vector3(x, (floor_y + 0.12 + top_y - 0.3) * 0.5, z), Vector3(0.12, top_y - 0.3 - floor_y - 0.12, 0.12), skin.post_color,
				0.0, MeshKit.PAT_BEACH_TIMBER, MeshKit.NO_BOTTOM, MeshKit.beach_timber_param(0, 0, look_seed))
	s.box(Vector3(0, top_y - 0.15, 0), Vector3(size.x * 0.99, 0.3, size.z * 0.99), skin.thatch_color, 0.0, MeshKit.PAT_BEACH_THATCH,
		MeshKit.ALL_FACES & ~MeshKit.FACE_NY)
	s.rect(Vector3(-hx * 0.99, top_y - 0.3 - 0.002, hz * 0.99), Vector3(size.x * 0.99, 0, 0), Vector3(0, 0, -size.z * 0.99),
		skin.thatch_dark_color, 0.0, MeshKit.PAT_PLAIN)
	s.box(Vector3(hx * 0.5, top_y - 0.38, 0), Vector3(hx, 0.14, size.z * 0.99), skin.thatch_color * 0.8, 0.0, MeshKit.PAT_BEACH_THATCH,
		MeshKit.ALL_FACES & ~MeshKit.FACE_PY)


## A four-cornered thatch face wound to face `outward`.
func _face(s: MeshLayer, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3, color: Color) -> void:
	if (b - a).cross(c - a).dot(outward) > 0.0:
		s.quad(a, d, c, b, color, 0.0, MeshKit.PAT_BEACH_THATCH)
	else:
		s.quad(a, b, c, d, color, 0.0, MeshKit.PAT_BEACH_THATCH)
