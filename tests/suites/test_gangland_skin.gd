extends SkinSuite
## The Gangland skin (GanglandSkin, Zone 2): the Gangland zone uses it and dresses its enemies as
## scavengers; the shared skin checks (SkinSuite) over a Gangland level for 3, 5 and 6 lanes; holes
## keep the orange edge glow right on the collision edge; nothing vent-like is drawn (in Gangland,
## vents and manholes are sewer-screech spawn points); street, ruin and barge surfaces stay
## desaturated so hazards remain the most saturated things on screen; the street carries drifting
## ash and speed streaks.

const GANGLAND_SKIN_PATH: String = "res://data/skins/gangland_skin.tres"
const GANGLAND_ZONE_PATH: String = "res://data/zones/gangland.tres"
const GANGLAND_LEVEL_PATH: String = "res://data/levels/gangland_2.tres"
## Lit surfaces (street, ruins, barge, mounts) stay below this chroma (brightest minus darkest channel).
const MAX_SURFACE_CHROMA: float = 0.2


func run() -> void:
	var skin := load(GANGLAND_SKIN_PATH) as GanglandSkin
	check(skin != null, "the gangland skin loads")
	if skin == null:
		return
	var zone := load(GANGLAND_ZONE_PATH) as ZoneDef
	check(zone != null and zone.skin is GanglandSkin, "the Gangland zone uses the gangland skin")
	check(skin.enemy_variant == &"scavenger" and GanglandSkin.new().enemy_variant == &"scavenger",
		"gangland enemies wear the scavenger look")
	start_error_count()
	var env: Environment = skin.make_environment()
	check(env != null and env.sky != null and env.glow_enabled and env.fog_enabled,
		"the gangland environment has a sky, glow and fog")
	for lanes: int in [3, 5, 6]:
		await whole_level(skin, "gangland", GANGLAND_LEVEL_PATH, lanes)
	await hazards_and_triggers(skin)
	await _edges_and_surfaces(skin)
	await determinism(skin, GANGLAND_LEVEL_PATH)
	stop_error_count("building gangland levels")


## Over the showcase track (every kind of piece): the hole in lane 3 (50-57 m) has the orange edge
## glow on both edges, no surface uses the grille (vent) pattern, lit surfaces stay desaturated, and
## the drifting particles are there.
func _edges_and_surfaces(skin: GanglandSkin) -> void:
	var track: TrackBuilder = showcase_track(skin)
	var lane := Vector2(1.2, 3.6)
	var edges: Dictionary = {}
	var grilles: int = 0
	var loud: PackedStringArray = []
	var drift_vertices: int = 0
	var solid: Material = skin.solid_material()
	var facade: Material = skin.facade_material()
	for node: Node in nodes_of(track, func(n: Node) -> bool: return n is MeshInstance3D):
		var m := node as MeshInstance3D
		if m.mesh == null or m.is_in_group(&"debug_hitbox"):
			continue
		for s: int in m.mesh.get_surface_count():
			var material: Material = m.mesh.surface_get_material(s)
			var arrays: Array = m.mesh.surface_get_arrays(s)
			if material == skin.drift_material():
				drift_vertices += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			if material != solid and material != facade:
				continue
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
			for i: int in verts.size():
				var c: Color = colors[i]
				if material == solid and roundi(uv2[i].x) == MeshKit.PAT_GRILLE:
					grilles += 1
				var lit: bool = material == facade or c.a == 0.0
				var chroma: float = maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))
				if lit and chroma > MAX_SURFACE_CHROMA and loud.size() < 5:
					loud.append("%s at %s" % [c, m.global_transform * verts[i]])
				var p: Vector3 = m.global_transform * verts[i]
				if material == solid and c.a > 0.2 and _same_rgb(c, skin.gap_edge_color) and absf(p.y) < 0.01 \
						and p.x > lane.x - 0.01 and p.x < lane.y + 0.01:
					for edge: float in [50.0, 57.0]:
						if absf(-p.z - edge) < 0.25:
							edges[edge] = true
	check(edges.has(50.0) and edges.has(57.0), "a hole keeps the orange edge glow on both of its edges (%s)" % [edges.keys()])
	check(grilles == 0, "nothing vent-like: no surface uses the grille pattern (%d vertices)" % grilles)
	check(loud.is_empty(), "lit street, ruin and barge surfaces stay desaturated: %s" % ", ".join(loud))
	check(drift_vertices > 0, "the street carries drifting ash and speed streaks (%d vertices)" % drift_vertices)
	await free_track(track)


static func _same_rgb(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01
