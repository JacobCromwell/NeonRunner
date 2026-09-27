extends SkinSuite
## The Gangland skin (GanglandSkin, Zone 2): the Gangland zone uses it and dresses its enemies as
## scavengers; the shared skin checks (SkinSuite) over a Gangland level for 3, 5 and 6 lanes; holes
## keep the orange edge glow right on the collision edge; nothing vent-like is drawn (in Gangland,
## vents and manholes are sewer-screech spawn points); the palette is browns and tans, lit surfaces
## stay desaturated and only hazards glow in hazard colours, so hazards remain the most saturated
## things on screen; nothing sticks out into the wall-run band; the street carries drifting dust and
## speed streaks. Ceilings (GanglandCeiling): both structures cover their collision underside, carry
## the orange end band and lamps on every lane seam, hang nothing below the surface, rise no higher
## than the lines strung across the street, and take their width from the lanes they cover. A whole
## level shows signs of life and hints of corporate and military funding.

const GANGLAND_SKIN_PATH: String = "res://data/skins/gangland_skin.tres"
const GANGLAND_ZONE_PATH: String = "res://data/zones/gangland.tres"
const GANGLAND_LEVEL_PATH: String = "res://data/levels/gangland_2.tres"
## Lit surfaces (street, ruins, ceilings, mounts, props) stay below this chroma (brightest minus darkest
## channel) and HSV saturation. Hazard colours are all above 0.75 chroma.
const MAX_SURFACE_CHROMA: float = 0.2
const MAX_SURFACE_SATURATION: float = 0.65
## Glowing decoration near the play field stays below this chroma (warm white lamps and bulbs), unless
## it is the orange edge language (hole edges, the ceiling's end band).
const MAX_DECOR_GLOW_CHROMA: float = 0.35
## The showcase track's hull (SkinSuite.showcase_track).
const HULL := Vector2(110.0, 150.0)


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
	_palette(skin)
	for lanes: int in [3, 5, 6]:
		await whole_level(skin, "gangland", GANGLAND_LEVEL_PATH, lanes)
	await hazards_and_triggers(skin)
	await _edges_and_surfaces(skin)
	await _ceilings(skin)
	await _life_and_funding(skin)
	await _cult_feed(skin)
	await determinism(skin, GANGLAND_LEVEL_PATH)
	stop_error_count("building gangland levels")


## Browns and tans (the owner's direction): the street, walls, props and ceilings are warm (red over
## green over blue) and desaturated, far from sign yellow and gap-edge orange.
func _palette(skin: GanglandSkin) -> void:
	var browns: Array[Color] = [skin.asphalt_color, skin.gutter_color, skin.sand_color, skin.earth_color,
		skin.board_color, skin.shutter_color, skin.barricade_color, skin.rust_color, skin.rubble_color,
		skin.wreck_color, skin.sandbag_color, skin.fence_pole_color, skin.scrap_metal_color,
		skin.ceiling_concrete_color, skin.ceiling_slab_color, skin.fog_color, skin.sky_horizon_color]
	browns.append_array(Array(skin.facade_colors))
	var off: PackedStringArray = []
	for c: Color in browns:
		var warm: bool = c.r >= c.g - 0.005 and c.g >= c.b - 0.005
		if not warm or _chroma(c) > MAX_SURFACE_CHROMA or c.s > MAX_SURFACE_SATURATION or _chroma(c) < 0.015:
			off.append(str(c))
	check(off.is_empty(), "the street, walls, props and ceilings are browns and tans: %s" % ", ".join(off))
	for hazard: Color in [skin.fence_color, skin.sign_frame_color, skin.gap_edge_color, skin.pad_color, skin.ramp_color]:
		check(_chroma(hazard) > MAX_SURFACE_CHROMA * 3.0, "hazard colour %s stays far more saturated than the zone's colours" %
			hazard)


## Over the showcase track (every kind of piece): the hole in lane 3 (50-57 m) has the orange edge
## glow on both edges, no surface uses the grille (vent) pattern, lit surfaces stay desaturated, only
## hazards glow in hazard colours near the play field, nothing sticks out into the wall-run band, and
## the drifting particles are there.
func _edges_and_surfaces(skin: GanglandSkin) -> void:
	var track: TrackBuilder = showcase_track(skin)
	var lane := Vector2(1.2, 3.6)
	var half_width: float = track.geo.half_width()
	var wall_x: float = track.geo.wall_x()
	var edges: Dictionary = {}
	var grilles: int = 0
	var loud: PackedStringArray = []
	var glowing: PackedStringArray = []
	var in_band: PackedStringArray = []
	var drift_vertices: int = 0
	var solid: Material = skin.solid_material()
	var facade: Material = skin.facade_material()
	var glow: Material = skin.glow_material()
	var band_top: float = minf(skin.boarded_below, tuning.ceiling_height - 0.1)
	for node: Node in nodes_of(track, func(n: Node) -> bool: return n is MeshInstance3D):
		var m := node as MeshInstance3D
		if m.mesh == null or m.is_in_group(&"debug_hitbox"):
			continue
		var decoration: bool = not _under_hazard_or_trigger(m, track)
		for s: int in m.mesh.get_surface_count():
			var material: Material = m.mesh.surface_get_material(s)
			var arrays: Array = m.mesh.surface_get_arrays(s)
			if material == skin.drift_material():
				drift_vertices += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			if material != solid and material != facade and material != glow:
				continue
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
			for i: int in verts.size():
				var c: Color = colors[i]
				var p: Vector3 = m.global_transform * verts[i]
				if material == solid and roundi(uv2[i].x) == MeshKit.PAT_GRILLE:
					grilles += 1
				var lit: bool = material == facade or (material == solid and c.a == 0.0)
				if lit and (_chroma(c) > MAX_SURFACE_CHROMA or c.s > MAX_SURFACE_SATURATION) and loud.size() < 5:
					loud.append("%s at %s" % [c, p])
				var glows: bool = material == glow or (material == solid and c.a > 0.0)
				if decoration and glows and _chroma(c) > MAX_DECOR_GLOW_CHROMA and not _same_rgb(c, skin.gap_edge_color) \
						and absf(p.x) < wall_x + 3.0 and glowing.size() < 5:
					glowing.append("%s at %s" % [c, p])
				if decoration and material != glow and p.y > 0.05 and p.y < band_top and absf(p.x) > half_width \
						and absf(p.x) < wall_x - 0.1 and in_band.size() < 5:
					in_band.append("%s" % p)
				if material == solid and c.a > 0.2 and _same_rgb(c, skin.gap_edge_color) and absf(p.y) < 0.01 \
						and p.x > lane.x - 0.01 and p.x < lane.y + 0.01:
					for edge: float in [50.0, 57.0]:
						if absf(-p.z - edge) < 0.25:
							edges[edge] = true
	check(edges.has(50.0) and edges.has(57.0), "a hole keeps the orange edge glow on both of its edges (%s)" % [edges.keys()])
	check(grilles == 0, "nothing vent-like: no surface uses the grille pattern (%d vertices)" % grilles)
	check(loud.is_empty(), "lit street, ruin, ceiling and prop surfaces stay desaturated: %s" % ", ".join(loud))
	check(glowing.is_empty(), "only hazards glow in hazard colours near the play field (decoration glows warm white): %s" %
		", ".join(glowing))
	check(in_band.is_empty(), "nothing sticks out of the walls into the wall-run band: %s" % ", ".join(in_band))
	check(drift_vertices > 0, "the street carries drifting dust and speed streaks (%d vertices)" % drift_vertices)
	await free_track(track)


# --- Ceilings -------------------------------------------------------------------------------

## The showcase hull as built in a track, then each structure built directly: full width (both sides
## run into the walls) and narrow (free sides), as narrow ceilings (task B3) will need.
func _ceilings(skin: GanglandSkin) -> void:
	var track: TrackBuilder = showcase_track(skin)
	# The ceiling's mesh sits at the underside's height; wall and floor batches sit at the origin.
	var meshes: Array[MeshInstance3D] = []
	for node: Node in nodes_of(track, func(n: Node) -> bool: return n is MeshInstance3D):
		if not _under_hazard_or_trigger(node, track) and absf((node as Node3D).position.y - tuning.ceiling_height) < 0.01:
			meshes.append(node as MeshInstance3D)
	check(meshes.size() == 1, "the showcase ceiling is one mesh (%d)" % meshes.size())
	var hw: float = track.geo.half_width()
	var seams: Array[float] = []
	for l: int in range(1, 5):
		seams.append(track.geo.lane_x(l) - track.geo.lane_width * 0.5)
	_check_ceiling(skin, meshes, -hw, hw, seams, HULL, "the showcase ceiling")
	await free_track(track)

	var builder: GanglandCeiling = skin.ceiling()
	var starts: Dictionary = {}
	var buildings: int = 0
	for i: int in 400:
		var start: float = 60.0 + float(i) * 7.3
		var kind: GanglandCeiling.Kind = builder.kind_at(start)
		buildings += int(kind == GanglandCeiling.Kind.BUILDING)
		if not starts.has(kind):
			starts[kind] = start
	check(starts.size() == 2 and absf(float(buildings) / 400.0 - skin.ceiling_building_share) < 0.1,
		"ceilings are overpasses and bombed-out buildings, %d of 400 buildings (share %.2f)" % [buildings,
			skin.ceiling_building_share])
	var ceiling_y: float = tuning.ceiling_height
	var lane_width: float = tuning.lane_width
	# Lane edges over 5 lanes (lane_width 2.4): full width -6..6, lanes 1-2 from -3.6 to 1.2.
	var full_seams: Array[float] = [-3.6, -1.2, 1.2, 3.6]
	var narrow_seams: Array[float] = [-1.2]
	for kind: int in starts:
		var name: String = "the overpass" if kind == GanglandCeiling.Kind.OVERPASS else "the bombed-out building"
		var start: float = starts[kind]
		var length: float = 48.0
		# Full width over 5 lanes, both sides into the walls.
		var full: Array[MeshInstance3D] = _build_ceiling(builder, 0.0, 5.0 * lane_width, start, length, ceiling_y,
			full_seams, true, true)
		var span: Vector2 = _underside_x_extent(full, ceiling_y)
		check(span.x < -6.0 - GanglandCeiling.WALL_EMBED + 0.2 and span.y > 6.0 + GanglandCeiling.WALL_EMBED - 0.2,
			"%s runs into the building faces on both sides (underside from %.2f to %.2f m)" % [name, span.x, span.y])
		_check_ceiling(skin, full, -6.0, 6.0, full_seams, Vector2(start, start + length), name)
		# Two lanes in the middle (lanes 1-2 of 5), both sides free: the width follows the lanes.
		var narrow: Array[MeshInstance3D] = _build_ceiling(builder, -1.2, 2.0 * lane_width, start, length, ceiling_y,
			narrow_seams, false, false)
		span = _underside_x_extent(narrow, ceiling_y)
		check(absf(span.x - (-3.6 - GanglandCeiling.FREE_LIP)) < 0.05 and absf(span.y - (1.2 + GanglandCeiling.FREE_LIP)) < 0.05,
			"%s over two lanes takes its width from them (underside from %.2f to %.2f m)" % [name, span.x, span.y])
		_check_ceiling(skin, narrow, -3.6, 1.2, narrow_seams, Vector2(start, start + length), name + " (narrow)")
		check(_free_side_faces(narrow, -3.6 - GanglandCeiling.FREE_LIP, 1.2 + GanglandCeiling.FREE_LIP, ceiling_y),
			"%s over two lanes closes its free sides with an edge face" % name)
		for list: Array[MeshInstance3D] in [full, narrow]:
			list[0].get_parent().queue_free()
	await tree.process_frame


## Builds one ceiling of `width` centred on x = center_x under a fresh node; returns its meshes.
func _build_ceiling(builder: GanglandCeiling, center_x: float, width: float, start: float, length: float,
		ceiling_y: float, seams: Array, left: bool, right: bool) -> Array[MeshInstance3D]:
	var root := Node3D.new()
	tree.root.add_child(root)
	var typed: Array[float] = []
	typed.assign(seams)
	var thickness: float = TrackBuilder.HULL_THICKNESS
	builder.build(root, Vector3(center_x, ceiling_y + thickness * 0.5, -(start + length * 0.5)),
		Vector3(width, thickness, length), typed, left, right)
	var out: Array[MeshInstance3D] = []
	for child: Node in root.get_children():
		if child is MeshInstance3D:
			out.append(child as MeshInstance3D)
	return out


## A ceiling reads as a surface to run on: its underside covers the collision footprint from x0 to
## x1 over `span` (distances), the orange end band crosses its far end, every lane seam carries lamps,
## nothing solid hangs below it, and nothing rises past GanglandCeiling.ABOVE_LIMIT.
func _check_ceiling(skin: GanglandSkin, meshes: Array[MeshInstance3D], x0: float, x1: float, seams: Array[float],
		span: Vector2, name: String) -> void:
	var ceiling_y: float = tuning.ceiling_height
	var plane: Array[PackedVector3Array] = []
	var band_x := Vector2(INF, -INF)
	var lamps: Dictionary = {}
	var hanging: PackedStringArray = []
	var top: float = -INF
	for m: MeshInstance3D in meshes:
		if m.mesh == null:
			continue
		for s: int in m.mesh.get_surface_count():
			var material: Material = m.mesh.surface_get_material(s)
			if material != skin.solid_material() and material != skin.facade_material():
				continue
			var arrays: Array = m.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			for t: int in range(0, verts.size(), 3):
				var tri := PackedVector3Array([m.global_transform * verts[t], m.global_transform * verts[t + 1],
					m.global_transform * verts[t + 2]])
				var on_plane: bool = true
				for p: Vector3 in tri:
					on_plane = on_plane and absf(p.y - ceiling_y) < 0.006
					top = maxf(top, p.y)
					var inside: bool = p.x > x0 + 0.01 and p.x < x1 - 0.01 and -p.z > span.x + 0.01 and -p.z < span.y - 0.01
					if inside and p.y < ceiling_y - 0.08 and p.y > 0.5 and hanging.size() < 4:
						hanging.append("%s" % p)
				if on_plane:
					plane.append(tri)
				var c: Color = colors[t]
				if _same_rgb(c, skin.gap_edge_color) and c.a > 0.2 and on_plane and -tri[0].z > span.y - 1.3:
					for p: Vector3 in tri:
						band_x = Vector2(minf(band_x.x, p.x), maxf(band_x.y, p.x))
				if _same_rgb(c, skin.ceiling_lamp_color) and c.a > 0.5:
					for x: float in seams:
						if absf(tri[0].x - x) < 0.2:
							lamps[x] = int(lamps.get(x, 0)) + 1
	var holes: int = 0
	var samples: int = 0
	var x: float = x0 + 0.05
	while x < x1:
		var d: float = span.x + 0.3
		while d < span.y:
			samples += 1
			if not _covered(plane, Vector2(x, -d)):
				holes += 1
			d += 1.7
		x += 0.55
	check(holes == 0, "%s: the underside covers the whole collision footprint (%d of %d points bare)" % [name, holes, samples])
	check(band_x.x <= x0 + 0.05 and band_x.y >= x1 - 0.05,
		"%s: the orange end band crosses the far end (from %.2f to %.2f m)" % [name, band_x.x, band_x.y])
	var dark_seams: int = 0
	for s: float in seams:
		dark_seams += int(int(lamps.get(s, 0)) > 0)
	check(dark_seams == seams.size(), "%s: every lane seam carries work lamps (%d of %d)" % [name, dark_seams, seams.size()])
	check(hanging.is_empty(), "%s: nothing hangs below the running surface: %s" % [name, ", ".join(hanging)])
	check(top <= ceiling_y + GanglandCeiling.ABOVE_LIMIT + 0.01, "%s rises no higher than %.1f m above its underside (%.2f m)" % [
		name, GanglandCeiling.ABOVE_LIMIT, top - ceiling_y])


static func _covered(tris: Array[PackedVector3Array], p: Vector2) -> bool:
	for tri: PackedVector3Array in tris:
		var a := Vector2(tri[0].x, tri[0].z)
		var b := Vector2(tri[1].x, tri[1].z)
		var c := Vector2(tri[2].x, tri[2].z)
		var d1: float = (p - b).cross(a - b)
		var d2: float = (p - c).cross(b - c)
		var d3: float = (p - a).cross(c - a)
		var has_neg: bool = d1 < 0.0 or d2 < 0.0 or d3 < 0.0
		var has_pos: bool = d1 > 0.0 or d2 > 0.0 or d3 > 0.0
		if not (has_neg and has_pos):
			return true
	return false


## The x extent of the triangles lying in the ceiling plane.
func _underside_x_extent(meshes: Array[MeshInstance3D], ceiling_y: float) -> Vector2:
	var out := Vector2(INF, -INF)
	for m: MeshInstance3D in meshes:
		for s: int in m.mesh.get_surface_count():
			var verts: PackedVector3Array = m.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			for t: int in range(0, verts.size(), 3):
				var tri: Array[Vector3] = [m.global_transform * verts[t], m.global_transform * verts[t + 1],
					m.global_transform * verts[t + 2]]
				if absf(tri[0].y - ceiling_y) < 0.006 and absf(tri[1].y - ceiling_y) < 0.006 and absf(tri[2].y - ceiling_y) < 0.006:
					for p: Vector3 in tri:
						out = Vector2(minf(out.x, p.x), maxf(out.y, p.x))
	return out


## Both free sides have an upright face at their edge, from the underside up.
func _free_side_faces(meshes: Array[MeshInstance3D], left_x: float, right_x: float, ceiling_y: float) -> bool:
	var found: Dictionary = {}
	for m: MeshInstance3D in meshes:
		for s: int in m.mesh.get_surface_count():
			var verts: PackedVector3Array = m.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			for t: int in range(0, verts.size(), 3):
				for x: float in [left_x, right_x]:
					var upright: bool = true
					var rises: bool = false
					for k: int in 3:
						var p: Vector3 = m.global_transform * verts[t + k]
						upright = upright and absf(p.x - x) < 0.01
						rises = rises or p.y > ceiling_y + 0.5
					if upright and rises:
						found[x] = true
	return found.size() == 2


# --- Life and funding -------------------------------------------------------------------------

## Over a whole 5-lane level: laundry (the cloth colours), stencilled crates, containers and notice
## boards (PAT_STENCIL, with military codes and the corporate logo), corporate ads (the kit shader's
## poster_ads), graffiti (graffiti_amount on the facades, graffiti_pieces on the sheets), and bulbs
## over the side streets, all present; lines across the street hang above every ceiling.
func _life_and_funding(skin: GanglandSkin) -> void:
	var layout: LevelLayout = level(GANGLAND_LEVEL_PATH, 5, 0.6)
	var world := Node3D.new()
	tree.root.add_child(world)
	var track := TrackBuilder.new()
	world.add_child(track)
	track.set_layout(layout, tuning, skin)
	var counts := {"cloth": 0, "code": 0, "logo": 0, "bulb": 0, "cult": 0}
	var lowest_line: float = INF
	var d: float = 0.0
	var solid: Material = skin.solid_material()
	var seen: Dictionary = {}
	while d <= layout.length:
		track.update(d, d / tuning.run_speed)
		for chunk: Node in track.get_children():
			if seen.has(chunk):
				continue
			seen[chunk] = true
			for node: Node in nodes_of(chunk, func(n: Node) -> bool: return n is MeshInstance3D):
				var m := node as MeshInstance3D
				if m.mesh == null:
					continue
				for s: int in m.mesh.get_surface_count():
					if m.mesh.surface_get_material(s) != solid:
						continue
					var arrays: Array = m.mesh.surface_get_arrays(s)
					var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
					var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
					var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
					for i: int in range(0, verts.size(), 6):
						var c: Color = colors[i]
						if roundi(uv2[i].x) == MeshKit.PAT_STENCIL:
							counts["logo" if roundi(uv2[i].y) % 2 == 1 else "code"] += 1
							counts["cult"] += int(roundi(uv2[i].y) >= 256)
						elif c.a == 0.0 and _in_palette(c, skin.cloth_colors):
							counts["cloth"] += 1
							# Over the street, from a wall batch (ceilings sit at their own height).
							var p: Vector3 = m.global_transform * verts[i]
							if absf(p.x) < track.geo.half_width() - 1.0 and m.position == Vector3.ZERO:
								lowest_line = minf(lowest_line, p.y)
						elif c.a > 0.5 and _same_rgb(c, skin.bulb_color):
							counts["bulb"] += 1
		d += TrackBuilder.CHUNK_LENGTH
	world.queue_free()
	await tree.process_frame
	print("  gangland life (5 lanes): %d laundry pieces, %d bulbs, %d stencilled faces (%d logos, %d with the cult emblem)" % [
		counts["cloth"], counts["bulb"], counts["code"] + counts["logo"], counts["logo"], counts["cult"]])
	check(counts["cloth"] > 20 and counts["bulb"] > 10,
		"the street is lived in: laundry (%d pieces) and bulbs over the side streets (%d)" % [counts["cloth"], counts["bulb"]])
	check(counts["code"] > 10 and counts["logo"] > 5,
		"hints of who funds the gangs: stencilled military codes (%d faces) and corporate logos (%d)" % [counts["code"],
			counts["logo"]])
	check(skin.graffiti_amount > 0.3 and skin.poster_ads > 0.0 and float(skin.solid_material().get_shader_parameter(
		"graffiti_pieces")) > 0.3 and float(skin.facade_material().get_shader_parameter("graffiti_amount")) > 0.3,
		"graffiti covers the lower storeys and barricades, and corporate ads are pasted among the posters")
	check(lowest_line > tuning.ceiling_height + GanglandCeiling.ABOVE_LIMIT,
		"laundry across the street hangs above every ceiling (lowest at %.2f m)" % lowest_line)
	_cult_emblem(skin, counts["cult"], counts["code"] + counts["logo"])


## The cult's emblem hides in plain sight (GDD §5): the owner's pick from its data file (never a
## hardcoded option), rasterised by CultEmblem in its unlit colours, on the solid material for ads,
## and on a minority of the stencilled crates, containers and boards.
func _cult_emblem(skin: GanglandSkin, marked: int, stencils: int) -> void:
	var choice := load(GanglandSkin.CULT_EMBLEM_CHOICE_PATH) as CultEmblemChoice
	check(choice != null and GanglandSkin.cult_emblem_option() == choice.option,
		"the skin draws the cult emblem the owner picked (option %s)" % (CultEmblem.option_letter(choice.option)
			if choice != null else "?"))
	var texture: ImageTexture = GanglandSkin.cult_emblem_texture()
	var material: ShaderMaterial = skin.solid_material()
	check(texture != null and material.get_shader_parameter("cult_emblem") == texture
		and float(material.get_shader_parameter("cult_emblem_share")) > 0.0,
		"the kit material carries the emblem for the corporate ads")
	if texture == null or choice == null:
		return
	var scheme: Dictionary = CultEmblem.default_scheme(choice.option)
	var expected: Image = CultEmblem.build_image(choice.option, GanglandSkin.CULT_EMBLEM_PIXELS, scheme["metal"],
		scheme["metal_accent"], Color(scheme["metal"], 0.0))
	var got: Image = texture.get_image()
	var same: bool = got.get_width() == expected.get_width()
	var opaque: int = 0
	for y: int in range(0, expected.get_height(), 3):
		for x: int in range(0, expected.get_width(), 3):
			var e: Color = expected.get_pixel(x, y)
			same = same and got.get_pixel(x, y).is_equal_approx(e)
			opaque += int(e.a > 0.99)
	check(same and opaque > 20, "the emblem is CultEmblem's own drawing of that option, in its unlit colours (%d opaque samples)" %
		opaque)
	check(marked > 0 and marked * 3 < stencils,
		"the emblem hides on a minority of stencilled crates, containers and boards (%d of %d faces)" % [marked, stencils])


# --- The cult's feed --------------------------------------------------------------------------

## The feed (CultFeed, GDD §5 "Cyborg Viewing Devices") plays on the shared material: on salvaged
## screens among the posters on the overpasses' gantries (about feed_share of the boards, facing the
## approach, up on the deck) and on TVs in upper windows of the ruins (inside their window, above the
## boarded-up band, the TV in its window). Over a whole level every screen built is one of those,
## untinted, never in the wall-run band nor on a hazard, and every TV is one feed_windows() lists.
func _cult_feed(skin: GanglandSkin) -> void:
	check(skin.feed_material() == CultFeed.material(), "gangland plays the shared feed")
	# The gantries, over many overpasses (their boards are picked by the overpass's look and length).
	var builder: GanglandCeiling = skin.ceiling()
	var ceiling_y: float = tuning.ceiling_height
	var deck: float = ceiling_y + skin.overpass_depth
	var screens: int = 0
	var posters: int = 0
	var gantry_bad: PackedStringArray = []
	for i: int in 240:
		var start: float = 60.0 + float(i) * 7.3
		if builder.kind_at(start) != GanglandCeiling.Kind.OVERPASS:
			continue
		var meshes: Array[MeshInstance3D] = _build_ceiling(builder, 0.0, 5.0 * tuning.lane_width, start,
			30.0 + float(i) * 0.37, ceiling_y, [-3.6, -1.2, 1.2, 3.6], true, true)
		for m: MeshInstance3D in meshes:
			for s: int in m.mesh.get_surface_count():
				var material: Material = m.mesh.surface_get_material(s)
				for r: Dictionary in rects_of(m, m.mesh.surface_get_arrays(s)):
					if material == skin.solid_material() and r["pattern"] == MeshKit.PAT_POSTER and r["center"].y > deck:
						posters += 1
					elif material == skin.feed_material():
						screens += 1
						var lowest: float = minf(r["o"].y, minf(r["ov"].y, r["ou"].y))
						if (not (r["normal"] as Vector3).is_equal_approx(Vector3.BACK) or lowest < deck + 1.0
								or absf(r["center"].x) > 6.0) and gantry_bad.size() < 4:
							gantry_bad.append("%s facing %s" % [r["center"], r["normal"]])
		meshes[0].get_parent().queue_free()
	await tree.process_frame
	var share: float = float(screens) / float(maxi(screens + posters, 1))
	print("  gangland feed (5 lanes): %d of %d gantry billboards are screens playing it (share %.2f)" % [screens,
		screens + posters, share])
	check(screens > 0 and posters > 0 and absf(share - skin.feed_share) < 0.15 and gantry_bad.is_empty(),
		"about %.2f of the gantry billboards are screens playing the feed (%.2f), facing the approach up on the deck: %s" % [
			skin.feed_share, share, ", ".join(gantry_bad)])
	# The TV windows, over 3 km of both walls.
	var geo := TrackGeometry.new(5, tuning)
	var wall: float = geo.wall_x()
	var tvs: Array[Dictionary] = []
	var window_bad: PackedStringArray = []
	for side: int in [-1, 1]:
		for w: Dictionary in skin.feed_windows(side, side * wall, -100.0, 3000.0):
			tvs.append(w)
			var c: Vector3 = w["center"]
			var sc: Vector3 = w["screen_center"]
			var inside: bool = absf(sc.z - c.z) + float(w["screen_width"]) * 0.5 < float(w["width"]) * 0.5 \
				and sc.y - float(w["screen_height"]) * 0.5 > float(w["bottom"]) and sc.y + float(w["screen_height"]) * 0.5 < float(w["top"])
			if (float(w["bottom"]) < skin.boarded_below + GanglandRuins.BAND_MARGIN - 0.01 or not inside) and window_bad.size() < 4:
				window_bad.append(str(w["center"]))
	print("  gangland feed (5 lanes): %d TV windows over 3 km of walls" % tvs.size())
	check(not tvs.is_empty() and window_bad.is_empty(),
		"over 3 km, %d ruins have a TV playing the feed in an upper window, above the boarded-up band, inside its window: %s" % [
			tvs.size(), ", ".join(window_bad)])
	# Everything built over a whole level.
	var built: Array[Dictionary] = []
	var bad: PackedStringArray = []
	await visit_level(level(GANGLAND_LEVEL_PATH, 5, 0.6), skin, func(m: MeshInstance3D, arrays: Array, material: Material) -> void:
		if material != skin.feed_material():
			return
		for r: Dictionary in rects_of(m, arrays):
			built.append(r)
			var lowest: float = minf(r["o"].y, minf(r["ov"].y, r["ou"].y))
			var n: Vector3 = r["normal"]
			var facing: bool = n.is_equal_approx(Vector3.BACK) or n.is_equal_approx(Vector3(-signf(r["center"].x), 0, 0))
			if (lowest < skin.boarded_below + GanglandRuins.BAND_MARGIN or not _same_rgb(r["color"], Color.WHITE)
					or not facing or under_hazard(m)) and bad.size() < 4:
				bad.append("%s facing %s" % [r["center"], n]))
	var unlisted: int = 0
	var on_walls: int = 0
	for r: Dictionary in built:
		if not (r["normal"] as Vector3).is_equal_approx(Vector3.BACK):
			on_walls += 1
			var found: bool = false
			for w: Dictionary in tvs:
				found = found or (w["screen_center"] as Vector3).distance_to(r["center"]) < 0.05
			unlisted += int(not found)
	check(on_walls > 0 and bad.is_empty(),
		"over a whole level the feed's %d screens (%d TVs, the rest on gantries) are untinted, face the street or the approach, above the band: %s" % [
			built.size(), on_walls, ", ".join(bad)])
	check(unlisted == 0, "every TV built is one feed_windows() lists (%d unlisted)" % unlisted)


# --- Helpers ----------------------------------------------------------------------------------

func _under_hazard_or_trigger(node: Node, stop: Node) -> bool:
	var parent: Node = node.get_parent()
	while parent != null and parent != stop:
		if parent is Hazard or (parent is Area3D and parent.has_meta(&"kind")):
			return true
		parent = parent.get_parent()
	return false


static func _chroma(c: Color) -> float:
	return maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))


static func _in_palette(c: Color, palette: PackedColorArray) -> bool:
	for p: Color in palette:
		if _same_rgb(c, p) or _same_rgb(c, p.darkened(0.15)):
			return true
	return false


static func _same_rgb(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01
