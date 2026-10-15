class_name CasinoCeilings
extends RefCounted
## Ceiling sections in the Casino (CasinoSkin; task K1; GDD §3, §5; the owner's reference image): pieces
## of the covered street at the ceiling's usual height, never the glass roof (that stays far overhead as
## background, CasinoVault): an iron footbridge between the balconies, a gantry carrying a bundle of
## thick brass pipes, and a sign gantry with a big lit sign (or the cult's feed) on an iron frame. Picked
## per ceiling by hashing its position (weights in the skin).
## Every kind is built from the ceiling it's given (B3, GDD §3: "ceilings don't have to cover every
## lane"): its width and position come from the collision box and the lane seams (center, size,
## lane_edges_x), so a ceiling over fewer lanes just builds narrower. Only a footbridge needs the whole
## street (it runs from balcony to balcony, wall to wall); over fewer lanes it becomes a gantry.
## Every underside is one flat iron surface across its lanes (no gaps between lanes) with faint seams
## and warm lamps flush with it along them, nothing hangs below it, and the far end carries the orange
## edge band of every zone (MeshKit.ceiling_end), so the drop back to the floor reads like a gap edge.
## Nothing rises more than TOP_LIMIT above the underside (the structure stays under the camera's flyover,
## the arrival flyover rule), and every sign on one is at or above decor_min_height and unframed.
## Ceiling space: origin at the centre of the underside (the ceiling surface), z = -distance.

enum Kind { FOOTBRIDGE, GANTRY, SIGN }

const END_BAND: float = 1.2
## The most any structure rises above the underside (the arrival flyover's camera flies under 9.5 m, the
## ceilings are 6 m up).
const TOP_LIMIT: float = 6.2

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: CasinoSkin:
	get:
		return _skin.get_ref() as CasinoSkin
var _skin: WeakRef
var _meshes: Dictionary = {}


func _init(p_skin: CasinoSkin) -> void:
	_skin = weakref(p_skin)


## Dresses the ceiling with collision box center/size and seams lane_edges_x (world x). wall_x is the
## wall faces' distance from the track's centre.
func build(parent: Node3D, center: Vector3, size: Vector3, lane_edges_x: Array[float], wall_x: float) -> void:
	var kind: int = kind_of(center, size, wall_x)
	var variant: int = MeshKit.hash_i(MeshKit.key(center.z), MeshKit.key(size.z), 91) % 4
	var id: String = "%d_%d_%s_%s_%s_%s_%s" % [kind, variant, size, lane_edges_x, center.x, wall_x, center.y]
	var mesh: ArrayMesh = _meshes.get(id)
	if mesh == null:
		if _meshes.size() > 256:
			_meshes.clear()
		mesh = mesh_for(kind, variant, size, lane_edges_x, center.x, wall_x, center.y - size.y * 0.5)
		_meshes[id] = mesh
	MeshBatch.add_instance(parent, mesh, "", Vector3(center.x, center.y - size.y * 0.5, center.z))


## Which kind of structure forms this ceiling.
func kind_of(center: Vector3, size: Vector3, wall_x: float) -> int:
	var full: bool = absf(center.x) < 0.01 and size.x * 0.5 > wall_x - 0.6
	var weights: Array[float] = [skin.footbridge_weight if full else 0.0,
		skin.gantry_weight + (0.0 if full else skin.footbridge_weight), skin.sign_weight]
	var total: float = 0.0
	for w: float in weights:
		total += w
	if total <= 0.0:
		return Kind.GANTRY
	var r: float = MeshKit.hash01(MeshKit.key(center.z), MeshKit.key(size.z), 90) * total
	for k: int in weights.size():
		r -= weights[k]
		if r < 0.0:
			return k
	return Kind.GANTRY


## The mesh of a ceiling of `kind` (variant 0-3) with collision size `size` centred on offset_x, seams at
## lane_edges_x (world x), its underside at world height surface_y. In ceiling space (see above); build()
## places it.
func mesh_for(kind: int, variant: int, size: Vector3, lane_edges_x: Array[float], offset_x: float, wall_x: float,
		surface_y: float) -> ArrayMesh:
	var batch := MeshBatch.new()
	var hw: float = size.x * 0.5 + 0.15
	var edges: Array[float] = []
	for x: float in lane_edges_x:
		edges.append(x - offset_x)
	match kind:
		Kind.FOOTBRIDGE:
			_footbridge(batch, size, edges, wall_x, variant, surface_y)
		Kind.SIGN:
			_sign_gantry(batch, size, edges, hw, variant, surface_y)
		_:
			_gantry(batch, size, edges, hw, variant)
	return batch.to_mesh()


## The underside across [-hw, hw] from the far end's band to the near end: one iron surface (beams
## across it every 3 m), a faint seam between each pair of lanes with warm lamps flush with it along
## it, and the orange band at the end.
func _underside(s: MeshLayer, g: MeshLayer, hw: float, zn: float, zf: float, edges: Array[float]) -> void:
	var z0: float = zf + END_BAND
	s.rect(Vector3(-hw, 0, z0), Vector3(hw * 2.0, 0, 0), Vector3(0, 0, zn - z0), skin.soffit_color, 0.0,
		MeshKit.PAT_CASINO_IRON, Vector2.ZERO, Vector2.ONE, 1.0)
	var seam := Color(skin.soffit_color.darkened(0.4), 1.0)
	var lamp: Color = skin.ceiling_lamp_color
	for x: float in edges:
		s.box(Vector3(x, -0.006, (zn + z0) * 0.5), Vector3(0.06, 0.012, zn - z0), seam, 0.0, MeshKit.PAT_PLAIN,
			MeshKit.ALL_FACES & ~MeshKit.FACE_PY)
		var z: float = z0 + 4.0
		while z < zn - 2.0:
			s.box(Vector3(x, -0.02, z), Vector3(0.24, 0.04, 0.24), lamp, 0.75, MeshKit.PAT_PLAIN,
				MeshKit.ALL_FACES & ~MeshKit.FACE_PY)
			g.rect(Vector3(x - 0.8, -0.06, z + 0.8), Vector3(1.6, 0, 0), Vector3(0, 0, -1.6), lamp, 0.28, MeshKit.SHAPE_RADIAL)
			z += 7.5
	MeshKit.ceiling_end(s, g, hw, zf, END_BAND, skin.gap_edge_color)


# --- An iron footbridge between the balconies ---------------------------------------------------

## A footbridge across the street from balcony to balcony: an iron underside over every lane, riveted
## girder faces at both ends, lattice sides with brass rails, and over the approach a big lit sign in a
## brass edge on two posts (above decor_min_height, like every decorative sign).
func _footbridge(batch: MeshBatch, size: Vector3, edges: Array[float], wall_x: float, variant: int, surface_y: float) -> void:
	var s: MeshLayer = batch.layer(skin.solid_material())
	var g: MeshLayer = batch.layer(skin.glow_material())
	var zn: float = size.z * 0.5
	var zf: float = -size.z * 0.5
	var w: float = wall_x
	var iron: Color = skin.iron_color
	var brass: Color = skin.brass_color
	_underside(s, g, w, zn, zf, edges)
	var deck: float = size.y
	# The girder face at the near end, and the deck's top, brass-edged.
	s.rect(Vector3(-w, 0, zn), Vector3(w * 2.0, 0, 0), Vector3(0, deck + 0.5, 0), skin.girder_color, 0.0, MeshKit.PAT_CASINO_IRON,
		Vector2.ZERO, Vector2.ONE, 0.0)
	s.box(Vector3(0, deck + 0.52, zn - 0.02), Vector3(w * 2.0, 0.06, 0.14), brass, 0.0, MeshKit.PAT_CASINO_BRASS,
		MeshKit.ALL_FACES, 0.5)
	s.rect(Vector3(-w, deck, zn), Vector3(w * 2.0, 0, 0), Vector3(0, 0, zf - zn), iron, 0.0, MeshKit.PAT_CASINO_IRON,
		Vector2.ZERO, Vector2.ONE, 0.0)
	s.rect(Vector3(w, 0, zf), Vector3(-w * 2.0, 0, 0), Vector3(0, deck + 0.5, 0), iron.darkened(0.2))
	# Lattice sides along the bridge's length at the street's edges (a rail on posts and a brace between).
	for side: float in [-1.0, 1.0]:
		var x: float = side * (w - 0.15)
		s.box(Vector3(x, deck + 1.3, (zn + zf) * 0.5), Vector3(0.1, 0.1, zn - zf), brass, 0.0, MeshKit.PAT_CASINO_BRASS,
			MeshKit.ALL_FACES, 0.5)
		var z: float = zf + 0.8
		while z < zn:
			s.box(Vector3(x, deck + 0.9, z), Vector3(0.07, 0.8, 0.07), iron, 0.0, MeshKit.PAT_PLAIN,
				MeshKit.ALL_FACES & ~(MeshKit.FACE_PY | MeshKit.FACE_NY))
			z += 1.4
	# The sign over the approach on two posts, set back from the near end.
	var sign_w: float = minf(w * 1.2, 9.0)
	var sign_h: float = 2.2
	var sy: float = maxf(skin.decor_min_height - surface_y + 0.1, deck + 1.2)
	var sz: float = zn - 2.2
	_lit_sign(batch, s, g, Vector3(0, sy, sz), sign_w, sign_h, variant, true)
	for post: float in [-sign_w * 0.4, sign_w * 0.4]:
		s.box(Vector3(post, (deck + sy) * 0.5, sz - 0.12), Vector3(0.2, sy - deck, 0.2), iron, 0.0, MeshKit.PAT_CASINO_IRON,
			MeshKit.ALL_FACES, 2.0)


# --- A gantry carrying a bundle of brass pipes ------------------------------------------------------

## An iron gantry carrying a bundle of thick brass pipes along the street: the iron underside, the
## deck, three to five pipes lying on saddles along its length with a flange at each end, and a valve
## wheel or two between; narrower over fewer lanes (fewer pipes).
func _gantry(batch: MeshBatch, size: Vector3, edges: Array[float], hw: float, variant: int) -> void:
	var s: MeshLayer = batch.layer(skin.solid_material())
	var g: MeshLayer = batch.layer(skin.glow_material())
	var zn: float = size.z * 0.5
	var zf: float = -size.z * 0.5
	var deck: float = size.y
	var iron: Color = skin.iron_color
	_underside(s, g, hw, zn, zf, edges)
	# Fascias along both sides and across the near end, brass-edged, and the deck's top.
	for side: float in [-1.0, 1.0]:
		var x: float = side * hw
		if side > 0.0:
			s.rect(Vector3(x, 0, zn), Vector3(0, 0, zf - zn), Vector3(0, deck, 0), skin.girder_color, 0.0, MeshKit.PAT_CASINO_IRON,
				Vector2.ZERO, Vector2.ONE, 0.0)
		else:
			s.rect(Vector3(x, 0, zf), Vector3(0, 0, zn - zf), Vector3(0, deck, 0), skin.girder_color, 0.0, MeshKit.PAT_CASINO_IRON,
				Vector2.ZERO, Vector2.ONE, 0.0)
		s.box(Vector3(x + side * 0.01, deck - 0.04, (zn + zf) * 0.5), Vector3(0.04, 0.07, zn - zf - 0.3), skin.brass_color, 0.0,
			MeshKit.PAT_CASINO_BRASS, MeshKit.FACE_PX if side > 0.0 else MeshKit.FACE_NX, 0.5)
	s.rect(Vector3(-hw, 0, zn), Vector3(hw * 2.0, 0, 0), Vector3(0, deck, 0), skin.girder_color, 0.0, MeshKit.PAT_CASINO_IRON,
		Vector2.ZERO, Vector2.ONE, 0.0)
	s.rect(Vector3(hw, 0, zf), Vector3(-hw * 2.0, 0, 0), Vector3(0, deck, 0), iron.darkened(0.2))
	s.rect(Vector3(-hw, deck, zn), Vector3(hw * 2.0, 0, 0), Vector3(0, 0, zf - zn), iron, 0.0, MeshKit.PAT_CASINO_IRON,
		Vector2.ZERO, Vector2.ONE, 0.0)
	# The pipes: as many as fit across, of different bores, on saddles every 3.5 m.
	var count: int = clampi(floori(hw * 2.0 / 1.0), 1, 5)
	var gap: float = hw * 2.0 / float(count)
	for i: int in count:
		var x: float = -hw + (float(i) + 0.5) * gap
		var radius: float = minf(gap * 0.42, 0.28 + 0.12 * MeshKit.hash01(variant, i, 3))
		var color: Color = skin.brass_color if (i + variant) % 2 == 0 else skin.brass_dim_color
		var y: float = deck + radius
		CasinoFacades._pipe_z(s, x, y, -(zn - 0.2), -(zf + 0.2), radius, color)
		for z: float in [zn - 0.2, zf + 0.2]:
			s.box(Vector3(x, y, z), Vector3(radius * 2.0 + 0.14, radius * 2.0 + 0.14, 0.1), skin.brass_dim_color, 0.0,
				MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 0.4)
		var z: float = zf + 2.0
		while z < zn - 1.0:
			s.box(Vector3(x, deck + radius * 0.4, z), Vector3(radius * 2.2, radius * 0.8, 0.14), iron, 0.0, MeshKit.PAT_CASINO_IRON,
				MeshKit.ALL_FACES, 2.0)
			z += 3.5
	# A valve wheel on a stem between two of them, once or twice along the run.
	var valves: int = 1 + (variant % 2)
	for v: int in valves:
		var z: float = lerpf(zf + 4.0, zn - 4.0, (float(v) + 0.5) / valves)
		var vx: float = -hw + gap * (0.5 + float((variant + v) % maxi(count, 1)))
		var top: float = deck + 0.8 + 0.3 * MeshKit.hash01(variant, v, 7)
		s.box(Vector3(vx, (deck + top) * 0.5, z), Vector3(0.06, top - deck, 0.06), skin.brass_dim_color, 0.0, MeshKit.PAT_CASINO_BRASS,
			MeshKit.ALL_FACES, 0.4)
		s.box(Vector3(vx, top, z), Vector3(0.5, 0.05, 0.05), skin.brass_color, 0.0, MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 0.5)
		s.box(Vector3(vx, top, z), Vector3(0.05, 0.05, 0.5), skin.brass_color, 0.0, MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 0.5)


# --- A sign gantry ---------------------------------------------------------------------------

## A hovering-iron sign gantry: the iron underside and deck with a big lit sign (or the cult's feed)
## standing on an iron frame over its near end, facing the approaching player, lit lanterns on its
## corners. The sign is never lower than decor_min_height and never framed in a hazard's stripes.
func _sign_gantry(batch: MeshBatch, size: Vector3, edges: Array[float], hw: float, variant: int, surface_y: float) -> void:
	var s: MeshLayer = batch.layer(skin.solid_material())
	var g: MeshLayer = batch.layer(skin.glow_material())
	var zn: float = size.z * 0.5
	var zf: float = -size.z * 0.5
	var deck: float = size.y
	var iron: Color = skin.iron_color
	_underside(s, g, hw, zn, zf, edges)
	for side: float in [-1.0, 1.0]:
		var x: float = side * hw
		if side > 0.0:
			s.rect(Vector3(x, 0, zn), Vector3(0, 0, zf - zn), Vector3(0, deck, 0), skin.girder_color, 0.0, MeshKit.PAT_CASINO_IRON,
				Vector2.ZERO, Vector2.ONE, 0.0)
		else:
			s.rect(Vector3(x, 0, zf), Vector3(0, 0, zn - zf), Vector3(0, deck, 0), skin.girder_color, 0.0, MeshKit.PAT_CASINO_IRON,
				Vector2.ZERO, Vector2.ONE, 0.0)
		s.box(Vector3(x + side * 0.01, deck * 0.5, (zn + zf) * 0.5), Vector3(0.02, 0.05, zn - zf - 0.6), skin.ceiling_lamp_color, 0.5,
			MeshKit.PAT_PLAIN, MeshKit.FACE_PX if side > 0.0 else MeshKit.FACE_NX)
	s.rect(Vector3(-hw, 0, zn), Vector3(hw * 2.0, 0, 0), Vector3(0, deck, 0), skin.girder_color, 0.0, MeshKit.PAT_CASINO_IRON,
		Vector2.ZERO, Vector2.ONE, 0.0)
	s.rect(Vector3(hw, 0, zf), Vector3(-hw * 2.0, 0, 0), Vector3(0, deck, 0), iron.darkened(0.2))
	s.rect(Vector3(-hw, deck, zn), Vector3(hw * 2.0, 0, 0), Vector3(0, 0, zf - zn), iron, 0.0, MeshKit.PAT_CASINO_IRON,
		Vector2.ZERO, Vector2.ONE, 0.0)
	# The sign on its frame, set back from the near end; never lower than decor_min_height.
	var sw: float = minf(hw * 2.0 - 0.6, 12.0)
	var sh: float = clampf(sw * 0.34, 1.6, 3.4)
	var sy: float = maxf(deck + 0.9, skin.decor_min_height - surface_y + 0.1)
	var sz: float = zn - 2.5
	_lit_sign(batch, s, g, Vector3(0, sy, sz), sw, sh, variant, true)
	for leg: float in [-sw * 0.38, sw * 0.38]:
		s.box(Vector3(leg, (deck + sy) * 0.5, sz - 0.14), Vector3(0.22, sy - deck, 0.22), iron, 0.0, MeshKit.PAT_CASINO_IRON,
			MeshKit.ALL_FACES, 2.0)
	# Lanterns on the near corners, warm and dim.
	for side: float in [-1.0, 1.0]:
		s.box(Vector3(side * (hw - 0.3), deck + 0.45, zn - 0.4), Vector3(0.3, 0.5, 0.3), skin.lamp_color, 0.7)
		s.box(Vector3(side * (hw - 0.3), deck + 0.15, zn - 0.4), Vector3(0.36, 0.1, 0.36), skin.brass_dim_color, 0.0,
			MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 0.4)


## A big lit sign `width` by `height` with its bottom centre at `at` (ceiling space), facing +z, in a slim
## brass edge: its lit face (PAT_CASINO_SIGN) in warm white, violet or blue by variant, or the cult's
## feed (CultFeed) on some, and the cult's emblem small in a corner of the others (GDD §5: hidden in
## plain sight), with a soft halo behind it.
func _lit_sign(batch: MeshBatch, s: MeshLayer, g: MeshLayer, at: Vector3, width: float, height: float, variant: int,
		with_halo: bool) -> void:
	var edge: float = 0.1
	s.box(Vector3(at.x, at.y + height * 0.5, at.z - 0.12), Vector3(width + edge * 2.0, height + edge * 2.0, 0.2),
		skin.sign_panel_color, 0.0, MeshKit.PAT_PLAIN, MeshKit.ALL_FACES & ~MeshKit.FACE_NY)
	s.box(Vector3(at.x, at.y - edge * 0.5, at.z - 0.12), Vector3(width + edge * 2.0, edge, 0.24), skin.brass_color, 0.0,
		MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 0.5)
	s.box(Vector3(at.x, at.y + height + edge * 0.5, at.z - 0.12), Vector3(width + edge * 2.0, edge, 0.24), skin.brass_color, 0.0,
		MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 0.5)
	var color: Color = skin.neon_colors[variant % skin.neon_colors.size()]
	var origin := Vector3(at.x - width * 0.5, at.y, at.z + 0.001)
	if skin.shows_feed(variant, 63):
		CultFeed.screen(batch.layer(skin.feed_material()), origin, Vector3(width, 0, 0), Vector3(0, height, 0),
			skin.feed_board_brightness, variant)
		color = CultFeed.FEED_COLOR
	else:
		s.rect(origin, Vector3(width, 0, 0), Vector3(0, height, 0), color, 0.6, MeshKit.PAT_CASINO_SIGN, Vector2.ZERO,
			Vector2(width, height), float(variant * 17 + 7 + 100 * roundi(height * 10.0)))
		var e: float = maxf(height * 0.28, skin.emblem_min_size)
		if skin.carries_emblem(variant, 25) and e <= height * 0.36:
			skin.add_cult_emblem(s, Vector3(at.x + width * 0.5 - e * 0.75, at.y + e * 0.72, at.z + 0.012), Vector3.BACK, e, true)
	if with_halo:
		g.rect(Vector3(at.x - width * 0.5 - 1.0, at.y - 1.0, at.z + 0.3), Vector3(width + 2.0, 0, 0), Vector3(0, height + 2.0, 0),
			color, 0.1, MeshKit.SHAPE_FLAT)
