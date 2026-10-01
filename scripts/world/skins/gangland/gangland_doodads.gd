class_name GanglandDoodads
extends RefCounted
## Gangland's zone doodads (GanglandSkin.doodad; GDD §3, owner's playtest September 30, 2026; task
## G6): burned-out car wrecks (small and medium) and a broken-down shop (large), in the zone's rusty
## browns and tans. A car is lower than the doodad's full height (GDD §3, docs/ARCHITECTURE.md Zone
## doodads' looks: "stack it, tip it on its side or pile its wreck high"): here it is crushed and
## piled with salvage up to the box's top, so it still reads as too tall to jump. Variety comes from
## hashing `look_seed` (MeshKit.hash_i), so a doodad looks the same wherever and whenever it is built.
## Every doodad is one mesh on MeshKit.solid() alone (never a zone's own tuned material), and never
## glows (test_doodads' _test_skins, test_gangland_skin's doodads_ok). Meshes are cached by size, side
## and seed and shared by every instance.

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: GanglandSkin:
	get:
		return _skin.get_ref() as GanglandSkin
var _skin: WeakRef
var _meshes: Dictionary = {}


func _init(p_skin: GanglandSkin) -> void:
	_skin = weakref(p_skin)


func build(body: Node3D, size: Vector3, size_class: StringName, side: int, look_seed: int) -> void:
	var mesh: ArrayMesh = _mesh_for(size, size_class, side, look_seed)
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = MeshKit.solid()
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(inst)


func _mesh_for(size: Vector3, size_class: StringName, side: int, look_seed: int) -> ArrayMesh:
	var id: String = "gangland_doodad_%s_%s_%d_%d" % [size, size_class, side, look_seed]
	if _meshes.has(id):
		return _meshes[id]
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(null)
	match size_class:
		&"small":
			_car(s, size, look_seed, 1)
		&"medium":
			_car(s, size, look_seed, 2)
		_:
			_shop(s, size, look_seed)
	var mesh: ArrayMesh = batch.to_mesh()
	_meshes[id] = mesh
	return mesh


## One or two burned-out cars nose to tail (`count`), crushed low, with scavenged salvage piled on and
## between them up to the box's top: it reads as solid wreckage the whole way up, never as a car alone.
func _car(s: MeshLayer, size: Vector3, look_seed: int, count: int) -> void:
	var sk: GanglandSkin = skin
	var hy: float = size.y * 0.5
	var hz: float = size.z * 0.5
	var car_h: float = minf(0.95, size.y * 0.42)
	var cab_h: float = minf(0.55, size.y * 0.22)
	var each_z: float = size.z / float(count)
	for i: int in count:
		var z0: float = -hz + (float(i) + 0.5) * each_z
		var body_len: float = each_z * 0.88
		var body_w: float = size.x * 0.82
		var tone: Color = sk.wreck_color.darkened(0.06 * float(MeshKit.hash_i(look_seed, i, 1) % 4))
		s.box(Vector3(0, -hy + car_h * 0.5, z0), Vector3(body_w, car_h, body_len), tone, 0.0, MeshKit.PAT_RUST,
			MeshKit.NO_BOTTOM)
		var cab_len: float = body_len * 0.5
		var shift: float = (MeshKit.hash01(look_seed, i, 2) - 0.5) * (each_z - cab_len) * 0.4
		s.box(Vector3(0, -hy + car_h + cab_h * 0.5, z0 + shift), Vector3(body_w * 0.86, cab_h, cab_len),
			tone.darkened(0.3), 0.0, MeshKit.PAT_RUST, MeshKit.NO_BOTTOM)
	# Salvage piled on top, filling the rest of the box so the wreck reads too tall to jump the whole
	# way across: a few stacked, axis-aligned chunks (sized to fit with room to spare) in the zone's
	# rust and rubble tones, each inset so it always stays inside the box whatever the seed picks.
	var pile_y0: float = -hy + car_h + cab_h
	var pile_h: float = hy - pile_y0 - 0.05
	if pile_h > 0.12:
		var pieces: int = 2 + count
		for i: int in pieces:
			var h: float = pile_h / float(pieces) * lerpf(0.75, 1.0, MeshKit.hash01(look_seed, i, 13))
			var y0: float = pile_y0 + pile_h * float(i) / float(pieces)
			var w: float = size.x * lerpf(0.4, 0.75, MeshKit.hash01(look_seed, i, 17))
			var d: float = size.z * lerpf(0.3, 0.55, MeshKit.hash01(look_seed, i, 19))
			var x: float = (MeshKit.hash01(look_seed, i, 11) - 0.5) * (size.x - w)
			var z: float = (MeshKit.hash01(look_seed, i, 12) - 0.5) * (size.z - d)
			var color: Color = (sk.rubble_color if i % 2 == 0 else sk.rust_color).darkened(0.1 * float(i))
			s.box(Vector3(x, y0 + h * 0.5, z), Vector3(w, h, d), color, 0.0, MeshKit.PAT_PLAIN, MeshKit.NO_BOTTOM)


## A broken-down shop frontage: a boarded facade with a shuttered doorway and a sagging, dented roof
## lip, rubble heaped along its foot. Never a hazard sign: no striped frame, no glow.
func _shop(s: MeshLayer, size: Vector3, look_seed: int) -> void:
	var sk: GanglandSkin = skin
	var hy: float = size.y * 0.5
	var hz: float = size.z * 0.5
	var colors: PackedColorArray = sk.facade_colors
	var wall: Color = colors[posmod(MeshKit.hash_i(look_seed, 1), colors.size())]
	s.box(Vector3.ZERO, size * Vector3(0.98, 0.98, 0.98), wall, 0.0, MeshKit.PAT_CONCRETE, MeshKit.NO_BOTTOM, 0.0)
	# The boarded shopfront on the track-facing side.
	var boards: int = 5
	var span: float = size.x * 0.94
	var board_w: float = span / float(boards) - 0.04
	var board_h: float = minf(1.8, size.y * 0.65)
	for i: int in boards:
		var x: float = -span * 0.5 + (float(i) + 0.5) * (span / float(boards))
		var tone: Color = sk.board_color.darkened(0.08 * float((i + MeshKit.hash_i(look_seed, i, 3)) % 3))
		s.box(Vector3(x, -hy + board_h * 0.5 + 0.1, hz * 0.96), Vector3(board_w, board_h, 0.06), tone, 0.0, MeshKit.PAT_PLAIN,
			MeshKit.FACE_PZ)
	# A corrugated shutter pulled down over the doorway, off-centre.
	var shutter_x: float = size.x * (0.1 if MeshKit.hash_i(look_seed, 4) % 2 == 0 else -0.1)
	s.box(Vector3(shutter_x, -hy + board_h * 0.5 + 0.1, hz * 0.96), Vector3(size.x * 0.3, board_h, 0.1), sk.shutter_color,
		0.0, MeshKit.PAT_RIBS, MeshKit.FACE_PZ)
	# A dented, sagging roof lip near the top.
	var lip_y: float = board_h - hy + 0.2
	s.box(Vector3(0, lip_y, hz * 0.85), Vector3(size.x * 0.96, 0.2, 0.5), wall.darkened(0.35), 0.0, MeshKit.PAT_RUST,
		MeshKit.ALL_FACES & ~MeshKit.FACE_NY)
	s.box(Vector3(0, hy - 0.08, 0), Vector3(size.x * 0.9, 0.16, size.z * 0.9), sk.soot_color, 0.0, MeshKit.PAT_PLAIN,
		MeshKit.FACE_PY)
	# Rubble heaped at the foot, axis-aligned and inset so it always fits inside the box.
	for i: int in 3:
		var rs := Vector3(0.3 + 0.2 * MeshKit.hash01(look_seed, i, 24), 0.22 + 0.1 * MeshKit.hash01(look_seed, i, 25),
			0.3 + 0.2 * MeshKit.hash01(look_seed, i, 26))
		var rx: float = (MeshKit.hash01(look_seed, i, 21) - 0.5) * (size.x - rs.x)
		var rz: float = lerpf(hz * 0.35, hz - rs.z * 0.5, MeshKit.hash01(look_seed, i, 22))
		s.box(Vector3(rx, -hy + rs.y * 0.5, rz), rs, sk.rubble_color.darkened(0.1 * float(i)), 0.0, MeshKit.PAT_PLAIN,
			MeshKit.NO_BOTTOM)
