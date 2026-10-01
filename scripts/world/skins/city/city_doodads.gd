class_name CityDoodads
extends RefCounted
## The Neon City's zone doodads (CitySkin.doodad; GDD §3, owner's playtest September 30, 2026; task
## G6): a pillar (small), a tiny market stall (medium) and a small storefront (large), in the City's
## own dark facade metal and roof tones. Variety comes from hashing `look_seed` (MeshKit.hash_i), so a
## doodad looks the same wherever and whenever it is built (never a random number generator).
## Every doodad is one mesh on MeshKit.solid() alone (never a zone's own tuned material), and never
## glows (test_doodads' _test_skins, test_city_skin's doodads_ok): matte metal and glass, no hazard
## stripes, signs or faces. Meshes are cached by size, side and seed and shared by every instance.

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: CitySkin:
	get:
		return _skin.get_ref() as CitySkin
var _skin: WeakRef
var _meshes: Dictionary = {}


func _init(p_skin: CitySkin) -> void:
	_skin = weakref(p_skin)


func build(body: Node3D, size: Vector3, size_class: StringName, side: int, look_seed: int) -> void:
	var mesh: ArrayMesh = _mesh_for(size, size_class, side, look_seed)
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = MeshKit.solid()
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(inst)


func _mesh_for(size: Vector3, size_class: StringName, side: int, look_seed: int) -> ArrayMesh:
	var id: String = "city_doodad_%s_%s_%d_%d" % [size, size_class, side, look_seed]
	if _meshes.has(id):
		return _meshes[id]
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(null)
	match size_class:
		&"small":
			_pillar(s, size, look_seed)
		&"medium":
			_stall(s, size, side, look_seed)
		_:
			_storefront(s, size, look_seed)
	var mesh: ArrayMesh = batch.to_mesh()
	_meshes[id] = mesh
	return mesh


## A support pillar reaching the doodad's full height: a square or round shaft (half by seed) between
## a wide foot and a capital, in the City's facade metal, with a dim reflective band near the top (the
## City's cool window glass, lit, never glowing).
func _pillar(s: MeshLayer, size: Vector3, look_seed: int) -> void:
	var sk: CitySkin = skin
	var colors: PackedColorArray = sk.facade_colors
	var body_color: Color = colors[posmod(MeshKit.hash_i(look_seed, 1), colors.size())]
	var cap_color: Color = sk.roof_color
	var hy: float = size.y * 0.5
	var base_h: float = minf(0.3, size.y * 0.15)
	var cap_h: float = minf(0.3, size.y * 0.15)
	var round_shaft: bool = MeshKit.hash_i(look_seed, 2) % 2 == 0
	if round_shaft:
		var r: float = minf(size.x, size.z) * 0.5 * 0.82
		s.prism(Vector3(0, -hy, 0), r * 1.1, base_h, 8, cap_color.darkened(0.2), 0.0, MeshKit.PAT_PLAIN, false)
		s.prism(Vector3(0, -hy + base_h, 0), r, size.y - base_h - cap_h, 8, body_color, 0.0, MeshKit.PAT_HULL, false)
		s.prism(Vector3(0, hy - cap_h, 0), r * 1.15, cap_h, 8, cap_color, 0.0, MeshKit.PAT_PLAIN)
	else:
		s.box(Vector3(0, -hy + base_h * 0.5, 0), Vector3(size.x * 0.94, base_h, size.z * 0.94), cap_color.darkened(0.2),
			0.0, MeshKit.PAT_PLAIN, MeshKit.NO_BOTTOM)
		s.box(Vector3.ZERO, Vector3(size.x * 0.8, size.y - base_h - cap_h, size.z * 0.8), body_color, 0.0, MeshKit.PAT_HULL)
		s.box(Vector3(0, hy - cap_h * 0.5, 0), Vector3(size.x * 0.9, cap_h, size.z * 0.9), cap_color)
	var band_y: float = hy - cap_h - 0.22
	if band_y > -hy + base_h + 0.1:
		s.box(Vector3(0, band_y, 0), Vector3(size.x * 0.84, 0.1, size.z * 0.84), sk.window_cool_color.darkened(0.4), 0.0,
			MeshKit.PAT_GLASS, MeshKit.NO_BOTTOM)


## A tiny market stall: a low counter with a slatted front, thin corner poles and a flat canopy flush
## with the doodad's top in one of the City's canopy colours (doodad_stall_colors), a crate on the
## counter for character.
func _stall(s: MeshLayer, size: Vector3, side: int, look_seed: int) -> void:
	var sk: CitySkin = skin
	var hy: float = size.y * 0.5
	var hx: float = size.x * 0.5
	var hz: float = size.z * 0.5
	var colors: PackedColorArray = sk.doodad_stall_colors
	var canopy: Color = colors[posmod(MeshKit.hash_i(look_seed, 3), colors.size())]
	var counter_h: float = minf(1.1, size.y * 0.42)
	s.box(Vector3(0, -hy + counter_h * 0.5, 0), Vector3(size.x * 0.92, counter_h, size.z * 0.88), sk.roof_color, 0.0,
		MeshKit.PAT_GRILLE, MeshKit.NO_BOTTOM)
	s.box(Vector3(0, -hy + counter_h + 0.03, 0), Vector3(size.x * 0.98, 0.06, size.z * 0.94), sk.roof_color.darkened(0.3))
	var pole_h: float = size.y - counter_h - 0.3
	var pole_y: float = -hy + counter_h + pole_h * 0.5
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			s.box(Vector3(sx * (hx - 0.08), pole_y, sz * (hz - 0.12)), Vector3(0.07, pole_h, 0.07), sk.roof_color.darkened(0.35))
	s.box(Vector3(0, hy - 0.15, 0), Vector3(size.x, 0.3, size.z), canopy, 0.0, MeshKit.PAT_ROOF, MeshKit.ALL_FACES & ~MeshKit.FACE_NY)
	var crate_x: float = float(side) * hx * 0.38
	var crate_turn := Basis(Vector3.UP, 0.3 * float(side if side != 0 else 1))
	s.box_xform(Transform3D(crate_turn.scaled_local(Vector3(0.3, 0.3, 0.3)),
		Vector3(crate_x, -hy + counter_h + 0.18, hz * 0.25)), sk.roof_color.lightened(0.12), 0.0, MeshKit.PAT_RIBS,
		MeshKit.NO_BOTTOM)


## A small storefront frontage: a facade slab with a base trim, a row of dim window slits and a flat
## signboard lip near the top (never a hazard sign: no striped frame, no glow).
func _storefront(s: MeshLayer, size: Vector3, look_seed: int) -> void:
	var sk: CitySkin = skin
	var hy: float = size.y * 0.5
	var hz: float = size.z * 0.5
	var colors: PackedColorArray = sk.facade_colors
	var wall: Color = colors[posmod(MeshKit.hash_i(look_seed, 4), colors.size())]
	s.box(Vector3.ZERO, size * Vector3(0.98, 0.98, 0.98), wall, 0.0, MeshKit.PAT_HULL, MeshKit.NO_BOTTOM)
	s.box(Vector3(0, -hy + 0.18, hz * 0.97), Vector3(size.x * 0.96, 0.36, 0.05), wall.darkened(0.3), 0.0, MeshKit.PAT_PLAIN,
		MeshKit.FACE_PZ)
	var count: int = 4
	var span: float = size.x * 0.96
	var window_w: float = span / float(count) - 0.1
	for i: int in count:
		var x: float = -span * 0.5 + (float(i) + 0.5) * (span / float(count))
		s.box(Vector3(x, 0.15, hz * 0.97), Vector3(window_w, 0.9, 0.04), sk.window_cool_color.darkened(0.4), 0.0,
			MeshKit.PAT_GLASS, MeshKit.FACE_PZ)
	s.box(Vector3(0, hy - 0.22, hz * 0.95), Vector3(size.x * 0.9, 0.3, 0.1), wall.darkened(0.45), 0.0, MeshKit.PAT_PLAIN,
		MeshKit.ALL_FACES & ~MeshKit.FACE_NY)
