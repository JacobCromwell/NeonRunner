class_name MarketDoodads
extends RefCounted
## The Marketplace's zone doodads (MarketplaceSkin.doodad; GDD §3, owner's playtest September 30,
## 2026; task G6): a potted plant (small), a bank of casino machines (medium) and a planted hedge row
## (large), the owner's "plenty of nice plants, casino machines". Variety comes from hashing
## `look_seed` (MeshKit.hash_i), so a doodad looks the same wherever and whenever it is built.
## Every doodad is one mesh on MeshKit.solid() alone (never a zone's own tuned material), and never
## glows (test_doodads' _test_skins, test_marketplace_skin's doodads_ok): the casino screens read as
## dim, dark glass, not a lit hazard sign or an ad. Meshes are cached by size, side and seed and
## shared by every instance.

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: MarketplaceSkin:
	get:
		return _skin.get_ref() as MarketplaceSkin
var _skin: WeakRef
var _meshes: Dictionary = {}


func _init(p_skin: MarketplaceSkin) -> void:
	_skin = weakref(p_skin)


func build(body: Node3D, size: Vector3, size_class: StringName, side: int, look_seed: int) -> void:
	var mesh: ArrayMesh = _mesh_for(size, size_class, side, look_seed)
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = MeshKit.solid()
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(inst)


func _mesh_for(size: Vector3, size_class: StringName, side: int, look_seed: int) -> ArrayMesh:
	var id: String = "market_doodad_%s_%s_%d_%d" % [size, size_class, side, look_seed]
	if _meshes.has(id):
		return _meshes[id]
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(null)
	match size_class:
		&"small":
			_plant(s, size, look_seed)
		&"medium":
			_casino(s, size, look_seed)
		_:
			_hedge(s, size, look_seed)
	# Its main colours, which its pieces fly off in when the dash smashes it (ZoneSkin.doodad_debris_colors).
	var mesh: ArrayMesh = ZoneSkin.tag_debris_colors(batch.to_mesh(), batch)
	_meshes[id] = mesh
	return mesh


## A tall potted plant: a stout pot, three tapering tiers of foliage stacked to the box's top.
func _plant(s: MeshLayer, size: Vector3, look_seed: int) -> void:
	var sk: MarketplaceSkin = skin
	var hy: float = size.y * 0.5
	var pot_h: float = minf(0.5, size.y * 0.22)
	var pot_r: float = minf(size.x, size.z) * 0.5 * 0.85
	s.prism(Vector3(0, -hy, 0), pot_r, pot_h, 8, sk.doodad_pot_color, 0.0, MeshKit.PAT_PLAIN, false)
	s.prism(Vector3(0, -hy + pot_h, 0), pot_r * 1.05, 0.05, 8, sk.doodad_pot_color.darkened(0.2))
	var colors: PackedColorArray = sk.doodad_plant_colors
	var tiers: int = 3
	var top_margin: float = 0.12
	var foliage_h: float = size.y - pot_h - top_margin
	var tier_h: float = foliage_h / float(tiers)
	var base_r: float = pot_r * 0.92
	for i: int in tiers:
		var r: float = base_r * (1.0 - 0.24 * float(i))
		var y0: float = -hy + pot_h + tier_h * float(i)
		var color: Color = colors[posmod(MeshKit.hash_i(look_seed, i, 1), colors.size())]
		s.prism(Vector3(0, y0, 0), r, tier_h * 0.92, 8, color)


## A bank of casino machines along the box's length: a cabinet in each half, a dim screen face toward
## the player, a marquee hump on top (never as bright as a hazard sign or a real ad).
func _casino(s: MeshLayer, size: Vector3, look_seed: int) -> void:
	var sk: MarketplaceSkin = skin
	var hy: float = size.y * 0.5
	var hz: float = size.z * 0.5
	var slots: int = 2
	var slot_d: float = size.z / float(slots)
	var colors: PackedColorArray = sk.doodad_cabinet_colors
	for i: int in slots:
		var cz: float = -hz + (float(i) + 0.5) * slot_d
		var cabinet_d: float = slot_d * 0.76
		var cabinet_w: float = size.x * 0.84
		var body_h: float = minf(size.y * 0.72, 2.0)
		var color: Color = colors[posmod(MeshKit.hash_i(look_seed, i, 1), colors.size())]
		s.box(Vector3(0, -hy + body_h * 0.5, cz), Vector3(cabinet_w, body_h, cabinet_d), color, 0.0, MeshKit.PAT_TECH,
			MeshKit.NO_BOTTOM, 2.0)
		var top_h: float = minf(size.y - body_h - 0.15, 0.4)
		if top_h > 0.05:
			s.box(Vector3(0, -hy + body_h + top_h * 0.5, cz), Vector3(cabinet_w * 0.9, top_h, cabinet_d * 0.9),
				sk.doodad_cabinet_trim_color, 0.0, MeshKit.PAT_PLAIN, MeshKit.NO_BOTTOM)
		s.box(Vector3(0, -hy + body_h * 0.55, cz + cabinet_d * 0.48), Vector3(cabinet_w * 0.68, body_h * 0.5, 0.04),
			sk.doodad_screen_color, 0.0, MeshKit.PAT_PLAIN, MeshKit.FACE_PZ)


## A planted hedge row: a long trough along the box's length with three stems of foliage of varying
## height, the tallest well short of the top.
func _hedge(s: MeshLayer, size: Vector3, look_seed: int) -> void:
	var sk: MarketplaceSkin = skin
	var hy: float = size.y * 0.5
	var hx: float = size.x * 0.5
	var hz: float = size.z * 0.5
	var trough_h: float = minf(0.5, size.y * 0.2)
	s.box(Vector3(0, -hy + trough_h * 0.5, 0), Vector3(size.x * 0.9, trough_h, size.z * 0.94), sk.doodad_pot_color, 0.0,
		MeshKit.PAT_PLAIN, MeshKit.NO_BOTTOM)
	var colors: PackedColorArray = sk.doodad_plant_colors
	var clusters: int = 3
	var slot: float = size.z / float(clusters)
	for i: int in clusters:
		var cz: float = -hz + (float(i) + 0.5) * slot
		var r: float = minf(hx * 0.8, slot * 0.42)
		var top_h: float = clampf(size.y * lerpf(0.5, 0.88, MeshKit.hash01(look_seed, i, 3)) - trough_h, 0.4,
			size.y - trough_h - 0.12)
		var color: Color = colors[posmod(MeshKit.hash_i(look_seed, i, 1), colors.size())]
		var tiers: int = 2
		var tier_h: float = top_h / float(tiers)
		for t: int in tiers:
			var rr: float = r * (1.0 - 0.26 * float(t))
			var y0: float = -hy + trough_h + tier_h * float(t)
			s.prism(Vector3(0, y0, cz), rr, tier_h * 0.92, 8, color.darkened(0.06 * float(t)))
