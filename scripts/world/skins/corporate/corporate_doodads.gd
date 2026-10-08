class_name CorporateDoodads
extends RefCounted
## Corporate's zone doodads (CorporateSkin.doodad; GDD §3, owner's playtest September 30, 2026; task
## G6: "security barriers, kiosks, planters and sculpture plinths in steel and the brand colour"): a
## steel planter (small), a security barrier or a glass kiosk (medium, by look_seed) and a sculpture
## plinth (large). Variety comes from hashing `look_seed` (MeshKit.hash_i), so a doodad looks the same
## wherever and whenever it is built.
## Every doodad is one mesh on MeshKit.solid() alone (never a zone's own tuned material), and never
## glows (test_doodads' _test_skins, test_corporate_skin's doodads_ok): the brand's colour appears only
## as flat paint, never the glowing screens and banners the walls carry. Meshes are cached by size,
## side and seed and shared by every instance.

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: CorporateSkin:
	get:
		return _skin.get_ref() as CorporateSkin
var _skin: WeakRef
var _meshes: Dictionary = {}


func _init(p_skin: CorporateSkin) -> void:
	_skin = weakref(p_skin)


func build(body: Node3D, size: Vector3, size_class: StringName, side: int, look_seed: int) -> void:
	var mesh: ArrayMesh = _mesh_for(size, size_class, side, look_seed)
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = MeshKit.solid()
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(inst)


func _mesh_for(size: Vector3, size_class: StringName, side: int, look_seed: int) -> ArrayMesh:
	var id: String = "corp_doodad_%s_%s_%d_%d" % [size, size_class, side, look_seed]
	if _meshes.has(id):
		return _meshes[id]
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(null)
	match size_class:
		&"small":
			_planter(s, size, look_seed)
		&"medium":
			if MeshKit.hash01(look_seed, 0) < skin.doodad_barrier_share:
				_barrier(s, size, look_seed)
			else:
				_kiosk(s, size, look_seed)
		_:
			_plinth(s, size, look_seed)
	# Its main colours, which its pieces fly off in when the dash smashes it (ZoneSkin.doodad_debris_colors).
	var mesh: ArrayMesh = ZoneSkin.tag_debris_colors(batch.to_mesh(), batch)
	_meshes[id] = mesh
	return mesh


## A steel planter: a brushed-steel trough with a thin brand-paint trim, trimmed topiary stacked to
## the box's top.
func _planter(s: MeshLayer, size: Vector3, look_seed: int) -> void:
	var sk: CorporateSkin = skin
	var hy: float = size.y * 0.5
	var trough_h: float = minf(0.55, size.y * 0.24)
	s.box(Vector3(0, -hy + trough_h * 0.5, 0), Vector3(size.x * 0.88, trough_h, size.z * 0.88), sk.gunmetal_color, 0.0,
		MeshKit.PAT_CORP_PLATE, MeshKit.NO_BOTTOM, 2.0)
	s.box(Vector3(0, -hy + trough_h - 0.03, 0), Vector3(size.x * 0.9, 0.05, size.z * 0.9), sk.brand_paint_color)
	var r: float = minf(size.x, size.z) * 0.5 * 0.8
	var tiers: int = 3
	var foliage_h: float = size.y - trough_h - 0.1
	var tier_h: float = foliage_h / float(tiers)
	for i: int in tiers:
		var rr: float = r * (1.0 - 0.22 * float(i))
		var y0: float = -hy + trough_h + tier_h * float(i)
		s.prism(Vector3(0, y0, 0), rr, tier_h * 0.92, 8, sk.doodad_topiary_color.darkened(0.05 * float(i)))


## A squat security barrier: a wide olive block, a slim steel watch mast rising to the box's top
## capped with a dark warning-light box (never lit: the box itself reads as the warning, not a glow).
func _barrier(s: MeshLayer, size: Vector3, look_seed: int) -> void:
	var sk: CorporateSkin = skin
	var hy: float = size.y * 0.5
	var hx: float = size.x * 0.5
	var hz: float = size.z * 0.5
	var block_h: float = minf(0.9, size.y * 0.36)
	s.box(Vector3(0, -hy + block_h * 0.5, 0), Vector3(size.x * 0.92, block_h, size.z * 0.86), sk.olive_color, 0.0,
		MeshKit.PAT_CORP_PLATE, MeshKit.NO_BOTTOM, 1.0)
	s.box(Vector3(0, -hy + block_h - 0.06, 0), Vector3(size.x * 0.94, 0.1, size.z * 0.9), sk.gunmetal_color.lightened(0.05))
	var mast_h: float = size.y - block_h - 0.3
	var mast_w: float = minf(hx, hz) * 0.5
	s.box(Vector3(0, -hy + block_h + mast_h * 0.5, 0), Vector3(mast_w, mast_h, mast_w), sk.pylon_color, 0.0,
		MeshKit.PAT_CORP_PLATE, MeshKit.NO_BOTTOM, 2.0)
	var cap_h: float = minf(0.28, size.y - block_h - mast_h - 0.02)
	s.box(Vector3(0, hy - cap_h * 0.5, 0), Vector3(mast_w * 2.2, cap_h, mast_w * 1.6), sk.gunmetal_color)
	s.box(Vector3(0, hy - cap_h * 0.5, hz * 0.95), Vector3(mast_w * 1.6, cap_h * 0.55, 0.04), sk.brand_paint_color, 0.0,
		MeshKit.PAT_PLAIN, MeshKit.FACE_PZ)


## A glass-walled kiosk: a steel-framed box most of the way up, a flat roof cap, a brand-paint
## signage strip facing the player (lit, never glowing).
func _kiosk(s: MeshLayer, size: Vector3, look_seed: int) -> void:
	var sk: CorporateSkin = skin
	var hy: float = size.y * 0.5
	var hz: float = size.z * 0.5
	var body_h: float = minf(size.y * 0.8, 2.1)
	s.box(Vector3(0, -hy + body_h * 0.5, 0), Vector3(size.x * 0.9, body_h, size.z * 0.86), sk.doodad_kiosk_color, 0.0,
		MeshKit.PAT_CORP_GLASS, MeshKit.NO_BOTTOM, float(roundi(body_h * 10.0)))
	var roof_h: float = minf(0.2, size.y - body_h - 0.05)
	s.box(Vector3(0, -hy + body_h + roof_h * 0.5, 0), Vector3(size.x * 0.98, roof_h, size.z * 0.94), sk.gunmetal_color)
	s.box(Vector3(0, -hy + body_h * 0.78, hz * 0.94), Vector3(size.x * 0.7, body_h * 0.22, 0.04), sk.brand_paint_color,
		0.0, MeshKit.PAT_PLAIN, MeshKit.FACE_PZ)


## A sculpture plinth: a steel-and-marble-toned plinth, an abstract angular steel form built from
## offset slabs stacked up toward the top, a brand-paint accent.
func _plinth(s: MeshLayer, size: Vector3, look_seed: int) -> void:
	var sk: CorporateSkin = skin
	var hy: float = size.y * 0.5
	var colors: PackedColorArray = sk.podium_colors
	var plinth_h: float = minf(0.5, size.y * 0.2)
	s.box(Vector3(0, -hy + plinth_h * 0.5, 0), Vector3(size.x * 0.94, plinth_h, size.z * 0.9), colors[posmod(
		MeshKit.hash_i(look_seed, 1), colors.size())], 0.0, MeshKit.PAT_CORP_PLATE, MeshKit.NO_BOTTOM, 3.0)
	var form_y0: float = -hy + plinth_h
	var form_h: float = hy - form_y0 - 0.08
	var slabs: int = 3
	for i: int in slabs:
		var sh: float = form_h / float(slabs) * lerpf(0.85, 1.0, MeshKit.hash01(look_seed, i, 11))
		var y0: float = form_y0 + form_h * float(i) / float(slabs)
		var w: float = size.x * lerpf(0.35, 0.8, MeshKit.hash01(look_seed, i, 12))
		var d: float = size.z * lerpf(0.3, 0.7, MeshKit.hash01(look_seed, i, 13))
		var x: float = (MeshKit.hash01(look_seed, i, 14) - 0.5) * (size.x - w)
		var z: float = (MeshKit.hash01(look_seed, i, 15) - 0.5) * (size.z - d)
		s.box(Vector3(x, y0 + sh * 0.5, z), Vector3(w, sh, d), sk.pylon_color.lightened(0.05 * float(i)), 0.0,
			MeshKit.PAT_CORP_PLATE, MeshKit.NO_BOTTOM, 2.0)
	s.box(Vector3(0, hy - 0.05, 0), Vector3(size.x * 0.3, 0.1, size.z * 0.18), sk.brand_paint_color, 0.0, MeshKit.PAT_PLAIN,
		MeshKit.FACE_PY)
