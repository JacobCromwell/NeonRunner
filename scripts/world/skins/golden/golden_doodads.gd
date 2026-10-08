class_name GoldenDoodads
extends RefCounted
## The Golden Zone's zone doodads (GoldenSkin.doodad; GDD §3, owner's playtest September 30, 2026;
## task G6: "gilded planters, fountains, statues on plinths, never at wall-run height (the Gilded
## Sentinels' language)"): a gilded planter (small), a fountain (medium) and a robed statue on a
## plinth (large). The statue is deliberately its own figure, not the Gilded Sentinels' armoured
## guard with a halberd (GoldenStatue, task C4): a plain draped, faceless figure with its hands
## clasped and nothing raised, so it never reads as the zone's wall-run enemy even standing in a lane.
## Variety comes from hashing `look_seed` (MeshKit.hash_i), so a doodad looks the same wherever and
## whenever it is built.
## Every doodad is one mesh on MeshKit.solid() alone (never a zone's own tuned material), and never
## glows (test_doodads' _test_skins, test_golden_skin's doodads_ok): gold stays reflective metal, lit
## like everywhere else in the zone, never neon. Meshes are cached by size, side and seed and shared
## by every instance.

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: GoldenSkin:
	get:
		return _skin.get_ref() as GoldenSkin
var _skin: WeakRef
var _meshes: Dictionary = {}


func _init(p_skin: GoldenSkin) -> void:
	_skin = weakref(p_skin)


func build(body: Node3D, size: Vector3, size_class: StringName, side: int, look_seed: int) -> void:
	var mesh: ArrayMesh = _mesh_for(size, size_class, side, look_seed)
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = MeshKit.solid()
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(inst)


func _mesh_for(size: Vector3, size_class: StringName, side: int, look_seed: int) -> ArrayMesh:
	var id: String = "golden_doodad_%s_%s_%d_%d" % [size, size_class, side, look_seed]
	if _meshes.has(id):
		return _meshes[id]
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(null)
	match size_class:
		&"small":
			_planter(s, size, look_seed)
		&"medium":
			_fountain(s, size, look_seed)
		_:
			_statue(s, size, look_seed)
	# Its main colours, which its pieces fly off in when the dash smashes it (ZoneSkin.doodad_debris_colors).
	var mesh: ArrayMesh = ZoneSkin.tag_debris_colors(batch.to_mesh(), batch)
	_meshes[id] = mesh
	return mesh


## A gilded planter: a marble urn with a gold rim, stylized gold reed fronds rising to the box's top.
func _planter(s: MeshLayer, size: Vector3, look_seed: int) -> void:
	var sk: GoldenSkin = skin
	var hy: float = size.y * 0.5
	var urn_h: float = minf(0.6, size.y * 0.26)
	var r: float = minf(size.x, size.z) * 0.5 * 0.8
	var stone: Color = sk.stone_colors[posmod(MeshKit.hash_i(look_seed, 1), sk.stone_colors.size())]
	s.prism(Vector3(0, -hy, 0), r, urn_h, 8, stone, 0.0, MeshKit.PAT_MARBLE, false)
	s.prism(Vector3(0, -hy + urn_h - 0.04, 0), r * 1.06, 0.06, 8, sk.gold_color, 0.0, MeshKit.PAT_GOLD, true, 0.85)
	var reeds: int = 5
	var top_margin: float = 0.15
	var reed_h: float = size.y - urn_h - top_margin
	for i: int in reeds:
		var a: float = TAU * float(i) / float(reeds) + MeshKit.hash01(look_seed, i, 2) * 0.3
		var rx: float = cos(a) * r * 0.4
		var rz: float = sin(a) * r * 0.4
		var h: float = reed_h * lerpf(0.6, 1.0, MeshKit.hash01(look_seed, i, 3))
		s.prism(Vector3(rx, -hy + urn_h, rz), 0.035, h, 5, sk.gold_color.darkened(0.05 * float(i)), 0.0, MeshKit.PAT_GOLD,
			true, 0.7)


## A fountain: a marble basin with a still water surface, a slim gold spire rising most of the way to
## the box's top, and a thin jet of falling water (scenery only, GDD §5; never glowing) from the
## spire into the basin.
func _fountain(s: MeshLayer, size: Vector3, look_seed: int) -> void:
	var sk: GoldenSkin = skin
	var hy: float = size.y * 0.5
	var basin_h: float = minf(0.4, size.y * 0.18)
	var basin_r: float = minf(size.x, size.z) * 0.5 * 0.85
	var stone: Color = sk.stone_colors[posmod(MeshKit.hash_i(look_seed, 1), sk.stone_colors.size())]
	s.prism(Vector3(0, -hy, 0), basin_r, basin_h, 10, stone, 0.0, MeshKit.PAT_MARBLE, false)
	s.prism(Vector3(0, -hy + basin_h - 0.03, 0), basin_r * 1.03, 0.03, 10, sk.gold_color, 0.0, MeshKit.PAT_GOLD, true, 0.8)
	var ws: float = basin_r * 0.78
	s.rect(Vector3(-ws, -hy + basin_h - 0.01, -ws), Vector3(ws * 2.0, 0, 0), Vector3(0, 0, ws * 2.0), sk.water_color, 0.0,
		MeshKit.PAT_WATER, Vector2(0.0, 0.9), Vector2(ws * 2.0, 1.0), 0.0)
	var col_h: float = size.y - basin_h - 0.2
	var col_r: float = 0.05
	s.prism(Vector3(0, -hy + basin_h, 0), col_r, col_h * 0.15, 8, sk.gold_color, 0.0, MeshKit.PAT_GOLD, false, 0.85)
	s.prism(Vector3(0, -hy + basin_h + col_h * 0.15, 0), col_r * 0.6, col_h * 0.85, 8, sk.gold_color, 0.0, MeshKit.PAT_GOLD,
		true, 0.9)
	var jet_h: float = col_h * 0.9
	s.rect(Vector3(-0.04, -hy + basin_h, 0.0), Vector3(0.08, 0, 0), Vector3(0, jet_h, 0), sk.water_color, 0.0,
		MeshKit.PAT_WATER, Vector2(0.0, 1.0), Vector2(0.08, 0.0), 1.0)


## A robed statue on a plinth: a tapered gold figure with a rounded cowl, hands clasped at the chest
## and a red sash, deliberately not the Gilded Sentinels' armoured guard with a raised halberd (see
## the header): nothing here is held or raised.
## DESIGN-TBD (docs/questions/g6.md): this shape is a proposal; the alternative is a scaled-down
## GoldenStatue pose (the same kit the ledges use), closer to "a statue" at the cost of standing
## closer to the Sentinel's own silhouette.
func _statue(s: MeshLayer, size: Vector3, look_seed: int) -> void:
	var sk: GoldenSkin = skin
	var hy: float = size.y * 0.5
	var plinth_h: float = minf(0.45, size.y * 0.18)
	var stone: Color = sk.stone_colors[posmod(MeshKit.hash_i(look_seed, 1), sk.stone_colors.size())]
	s.box(Vector3(0, -hy + plinth_h * 0.5, 0), Vector3(size.x * 0.9, plinth_h, size.z * 0.7), stone, 0.0, MeshKit.PAT_MARBLE,
		MeshKit.NO_BOTTOM, 0.0)
	var base_r: float = minf(size.x, size.z) * 0.5 * 0.6
	var head_h: float = 0.2
	var top_margin: float = head_h + 0.1
	var robe_h: float = size.y - plinth_h - top_margin
	var tiers: int = 4
	var tier_h: float = robe_h / float(tiers)
	var mid_r: float = base_r
	for i: int in tiers:
		var t: float = float(i) / float(tiers)
		var r: float = lerpf(base_r, base_r * 0.42, t)
		if i == 1:
			mid_r = r
		var y0: float = -hy + plinth_h + tier_h * float(i)
		s.prism(Vector3(0, y0, 0), r, tier_h * 1.02, 10, sk.gold_color.darkened(0.03 * float(i)), 0.0, MeshKit.PAT_GOLD,
			false, 0.8)
	var head_y: float = -hy + plinth_h + robe_h
	var head_r: float = base_r * 0.42 * 1.05
	s.prism(Vector3(0, head_y, 0), head_r, head_h, 8, sk.gold_color.lightened(0.04), 0.0, MeshKit.PAT_GOLD, true, 0.85)
	# Hands clasped at the chest: a small flat shape, never a weapon's silhouette.
	s.box(Vector3(0, -hy + plinth_h + robe_h * 0.55, size.z * 0.1), Vector3(0.16, 0.12, 0.1), sk.gold_color.darkened(0.1),
		0.0, MeshKit.PAT_GOLD, MeshKit.ALL_FACES, 0.6)
	# A thin red sash: unlit deep crimson, a touch of the zone's decadence.
	s.prism(Vector3(0, -hy + plinth_h + tier_h * 0.9, 0), mid_r * 1.05, 0.07, 10, sk.red_color, 0.0, MeshKit.PAT_PLAIN, false)
