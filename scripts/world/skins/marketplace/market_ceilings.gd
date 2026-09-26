class_name MarketCeilings
extends RefCounted
## Ceiling sections in the Marketplace (MarketplaceSkin), GDD §5: the undersides of buildings
## bridging the street, overpasses running along it, a few merchant ships and floating
## advertisements, picked per ceiling by hashing its position (weights in the skin).
## Every kind is built from the ceiling it's given: its width and position come from the collision
## box and the lane seams (center, size, lane_edges_x), so a ceiling over fewer lanes (narrow
## ceilings, task B3) just builds narrower. Only a building bridging the street needs the whole
## width (it reaches from wall to wall); over fewer lanes it becomes an overpass.
## Every underside is one flat, plated surface across its lanes (no gaps between lanes, GDD §3) with
## faint seams and warm lamps along them, nothing hanging below it but those flush lamps, and the far
## end carries the orange edge band of every zone (MeshKit.ceiling_end), so the drop back to the
## floor reads like a gap edge. Brand marks on ads come from market_logo() (the cult-symbol hook).
## Ceiling space: origin at the centre of the underside (the ceiling surface), z = -distance.

enum Kind { BRIDGE, OVERPASS, SHIP, AD }

const END_BAND: float = 1.2

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: MarketplaceSkin:
	get:
		return _skin.get_ref() as MarketplaceSkin
var _skin: WeakRef
var _meshes: Dictionary = {}


func _init(p_skin: MarketplaceSkin) -> void:
	_skin = weakref(p_skin)


## Dresses the ceiling with collision box center/size and seams lane_edges_x (world x). wall_x is
## the wall faces' distance from the track's centre.
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
	var weights: Array[float] = [skin.bridge_weight if full else 0.0,
		skin.overpass_weight + (0.0 if full else skin.bridge_weight), skin.ship_weight, skin.ad_weight]
	var total: float = 0.0
	for w: float in weights:
		total += w
	if total <= 0.0:
		return Kind.OVERPASS
	var r: float = MeshKit.hash01(MeshKit.key(center.z), MeshKit.key(size.z), 90) * total
	for k: int in weights.size():
		r -= weights[k]
		if r < 0.0:
			return k
	return Kind.OVERPASS


## The mesh of a ceiling of `kind` (colour variant 0-3) with collision size `size` centred on
## offset_x, seams at lane_edges_x (world x), its underside at world height surface_y. In ceiling
## space (see above); build() places it.
func mesh_for(kind: int, variant: int, size: Vector3, lane_edges_x: Array[float], offset_x: float, wall_x: float,
		surface_y: float) -> ArrayMesh:
	var batch := MeshBatch.new()
	var hw: float = size.x * 0.5 + 0.15
	var edges: Array[float] = []
	for x: float in lane_edges_x:
		edges.append(x - offset_x)
	match kind:
		Kind.BRIDGE:
			_bridge(batch, size, edges, wall_x, variant, surface_y)
		Kind.SHIP:
			_ship(batch, size, edges, hw, variant)
		Kind.AD:
			_ad(batch, size, edges, hw, variant, surface_y)
		_:
			_overpass(batch, size, edges, hw, wall_x, offset_x, variant)
	return batch.to_mesh()


## The underside across [-hw, hw] from the far end's band to the near end: one plated surface, a
## faint seam between each pair of lanes with warm lamps along it, and the orange band at the end.
func _underside(s: MeshLayer, g: MeshLayer, hw: float, zn: float, zf: float, edges: Array[float], color: Color,
		pattern: int, param: float) -> void:
	var z0: float = zf + END_BAND
	s.rect(Vector3(-hw, 0, z0), Vector3(hw * 2.0, 0, 0), Vector3(0, 0, zn - z0), color, 0.0, pattern, Vector2.ZERO,
		Vector2.ONE, param)
	var seam := Color(color.darkened(0.35), 1.0)
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


# --- A building bridging the street ------------------------------------------------------

## A building spanning the street from wall to wall on its upper floors: a coffered soffit over
## the lanes, and its front, a facade with windows and a lit sign, rising over the approach.
func _bridge(batch: MeshBatch, size: Vector3, edges: Array[float], wall_x: float, variant: int, surface_y: float) -> void:
	var s: MeshLayer = batch.layer(skin.solid_material())
	var g: MeshLayer = batch.layer(skin.glow_material())
	var f: MeshLayer = batch.layer(skin.facade_material())
	var zn: float = size.z * 0.5
	var zf: float = -size.z * 0.5
	var w: float = wall_x
	_underside(s, g, w, zn, zf, edges, skin.soffit_color, MeshKit.PAT_TILES, 1.0)
	var wall: Color = skin.stucco_colors[(variant * 2 + 1) % skin.stucco_colors.size()]
	var height: float = 7.0 + 2.0 * float(variant % 2)
	# The front: storeys of windows (the facade shader's grid in world heights), a cornice on top and
	# a trim band along the bottom edge, so the edge of the ceiling reads from the floor.
	f.quad_uv(Vector3(-w, 0, zn), Vector3(-w, height, zn), Vector3(w, height, zn), Vector3(w, 0, zn),
		Vector2(-w, surface_y), Vector2(-w, surface_y + height), Vector2(w, surface_y + height), Vector2(w, surface_y),
		wall, 0.35, MarketFacades.STYLE_UPPER, float(variant * 7 + 5))
	s.box(Vector3(0, 0.15, zn + 0.1), Vector3(w * 2.0, 0.3, 0.2), skin.trim_color, 0.0, MeshKit.PAT_STUCCO,
		MeshKit.ALL_FACES & ~MeshKit.FACE_PY)
	s.box(Vector3(0, height, zn + 0.12), Vector3(w * 2.0, 0.28, 0.24), skin.trim_color, 0.0, MeshKit.PAT_STUCCO,
		MeshKit.ALL_FACES & ~MeshKit.FACE_NY)
	# A lit sign over the middle, above the wall-run band like every decorative sign.
	var sign_w: float = minf(w * 1.2, 9.0)
	var sy: float = maxf(skin.decor_min_height - surface_y, 0.0) + 0.9
	var sh: float = minf(2.2, height - sy - 0.6)
	if sh > 1.0:
		s.box(Vector3(0, sy + sh * 0.5, zn + 0.05), Vector3(sign_w + 0.3, sh + 0.3, 0.1), Color(0.1, 0.09, 0.09))
		s.rect(Vector3(-sign_w * 0.5, sy, zn + 0.105), Vector3(sign_w, 0, 0), Vector3(0, sh, 0),
			skin.ad_colors[variant % skin.ad_colors.size()], 0.5, MeshKit.PAT_AD, Vector2.ZERO, Vector2(sign_w / sh, 1.0),
			float(variant * 13 + 3))


# --- An overpass running along the street -------------------------------------------------

## An elevated walkway along the street: a concrete deck with a coffered underside, a lamp-lit
## fascia and railings, carried by cross beams into the buildings on both sides at its ends (high
## above the wall-run band).
func _overpass(batch: MeshBatch, size: Vector3, edges: Array[float], hw: float, wall_x: float, offset_x: float,
		variant: int) -> void:
	var s: MeshLayer = batch.layer(skin.solid_material())
	var g: MeshLayer = batch.layer(skin.glow_material())
	var zn: float = size.z * 0.5
	var zf: float = -size.z * 0.5
	var deck: float = 0.9
	var concrete: Color = skin.concrete_color * Color(0.95 + 0.05 * variant, 0.95 + 0.05 * variant, 0.95 + 0.05 * variant)
	_underside(s, g, hw, zn, zf, edges, concrete, MeshKit.PAT_TILES, 1.0)
	# Fascias along the sides and across the near end, with a strip of lamps.
	var lamp: Color = skin.ceiling_lamp_color
	for side: float in [-1.0, 1.0]:
		var x: float = side * hw
		if side > 0.0:
			s.rect(Vector3(x, 0, zn), Vector3(0, 0, zf - zn), Vector3(0, deck, 0), concrete, 0.0, MeshKit.PAT_STUCCO)
		else:
			s.rect(Vector3(x, 0, zf), Vector3(0, 0, zn - zf), Vector3(0, deck, 0), concrete, 0.0, MeshKit.PAT_STUCCO)
		s.box(Vector3(x + side * 0.01, 0.12, (zn + zf) * 0.5), Vector3(0.02, 0.06, zn - zf - 0.4), lamp, 0.35,
			MeshKit.PAT_PLAIN, MeshKit.FACE_PX if side > 0.0 else MeshKit.FACE_NX)
		# Railing: posts and a top rail, a silhouette against the sky.
		var rail := Color(0.24, 0.24, 0.26)
		s.box(Vector3(x - side * 0.1, deck + 1.0, (zn + zf) * 0.5), Vector3(0.06, 0.06, zn - zf), rail)
		var z: float = zf + 0.6
		while z < zn:
			s.box(Vector3(x - side * 0.1, deck + 0.5, z), Vector3(0.05, 1.0, 0.05), rail, 0.0, MeshKit.PAT_PLAIN,
				MeshKit.ALL_FACES & ~(MeshKit.FACE_PY | MeshKit.FACE_NY))
			z += 1.5
	s.rect(Vector3(-hw, 0, zn), Vector3(hw * 2.0, 0, 0), Vector3(0, deck, 0), concrete, 0.0, MeshKit.PAT_STUCCO)
	s.box(Vector3(0, 0.12, zn + 0.01), Vector3(hw * 2.0 - 0.2, 0.06, 0.02), lamp, 0.4, MeshKit.PAT_PLAIN, MeshKit.FACE_PZ)
	s.rect(Vector3(hw, 0, zf), Vector3(-hw * 2.0, 0, 0), Vector3(0, deck, 0), concrete.darkened(0.2))
	# A walkway surface on top, seen past the railings from the walls.
	s.rect(Vector3(-hw, deck, zn), Vector3(hw * 2.0, 0, 0), Vector3(0, 0, zf - zn), concrete.darkened(0.1), 0.0,
		MeshKit.PAT_TILES)
	# Cross beams into the buildings at both ends, just above the deck.
	var beam := skin.girder_color
	for z: float in [zn - 0.8, zf + 0.8]:
		var x0: float = -wall_x - offset_x
		var x1: float = wall_x - offset_x
		s.box(Vector3((x0 + x1) * 0.5, deck + 0.35, z), Vector3(x1 - x0, 0.5, 0.45), beam, 0.0, MeshKit.PAT_RIBS)


# --- A merchant ship ----------------------------------------------------------------------

## A merchant freighter heading toward the player: a sun-bleached hull with a pointed prow, a painted
## band and portholes along its sloped sides, a wheelhouse with lit windows and a mast up front,
## cargo under tarps on deck, and its engines at the far end over the orange band.
func _ship(batch: MeshBatch, size: Vector3, edges: Array[float], hw: float, variant: int) -> void:
	var s: MeshLayer = batch.layer(skin.solid_material())
	var g: MeshLayer = batch.layer(skin.glow_material())
	var zn: float = size.z * 0.5
	var zf: float = -size.z * 0.5
	var hull: Color = skin.ship_hull_color
	var rise: float = 2.4
	var slope: float = minf(0.8, hw * 0.3)
	_underside(s, g, hw, zn, zf, edges, hull, MeshKit.PAT_HULL, 0.0)
	var lamp: Color = skin.ceiling_lamp_color
	# Sloped sides with a band of colour and portholes.
	var band: Color = skin.cargo_colors[variant % skin.cargo_colors.size()]
	for side: float in [-1.0, 1.0]:
		var x: float = side * hw
		var top := Vector3(-side * slope, rise, 0)
		var z0: float = zn if side > 0.0 else zf
		var u := Vector3(0, 0, zf - zn if side > 0.0 else zn - zf)
		s.rect(Vector3(x, 0, z0), u, top, hull.lightened(0.06), 0.0, MeshKit.PAT_HULL)
		s.rect(Vector3(x, 0, z0) + top * 0.18 + Vector3(side * 0.01, 0, 0), u, top * 0.14, band)
		var pz: float = zf + 2.5
		while pz < zn - 1.5:
			s.box(Vector3(x - side * slope * 0.55, rise * 0.55, pz), Vector3(0.26, 0.26, 0.26), lamp, 0.35)
			pz += 2.8
	# A pointed prow rising over the near end, a band of colour along its edges, a light at its tip.
	var bow_z: float = zn + 5.5
	var tip: float = maxf(hw * 0.3, 0.45)
	var bl := Vector3(-hw, 0, zn)
	var br := Vector3(hw, 0, zn)
	var tl := Vector3(-tip, rise, bow_z)
	var tr := Vector3(tip, rise, bow_z)
	s.quad(bl, tl, tr, br, hull, 0.0, MeshKit.PAT_HULL)
	s.quad(br, tr, br + Vector3(-slope, rise, 0), br + Vector3(-slope, rise, 0), hull.lightened(0.06))
	s.quad(bl, bl + Vector3(slope, rise, 0), tl, tl, hull.lightened(0.06))
	# The band sits just proud of the prow (along its normal), so the two never fight for depth.
	var lift: Vector3 = (br - bl).cross(tl - bl).normalized() * 0.02
	for side: float in [-1.0, 1.0]:
		var foot := Vector3(side * hw, 0, zn) + lift
		var head := Vector3(side * tip, rise, bow_z) + lift
		var along: Vector3 = (head - foot).normalized()
		var across := Vector3(-side * 0.35, 0.0, 0.0)
		if side > 0.0:
			s.quad(foot + across, head + across * 0.5, head, foot, band)
		else:
			s.quad(foot, head, head + across * 0.5, foot + across, band)
		var at := Vector3(side * (tip + 0.2), rise - 0.3, bow_z - 0.35) - along * 0.2
		s.box(at, Vector3(0.3, 0.2, 0.2), lamp, 0.8)
		g.rect(at + Vector3(-0.8, -0.8, 0.12), Vector3(1.6, 0, 0), Vector3(0, 1.6, 0), lamp, 0.2, MeshKit.SHAPE_RADIAL)
	# Deck: a wheelhouse with lit windows and a mast up front, cargo under tarps behind it.
	var deck_hw: float = hw - slope
	var cab_w: float = minf(deck_hw * 1.1, 5.0)
	var cab_z: float = zn - 2.2
	s.box(Vector3(0, rise + 1.3, cab_z), Vector3(cab_w, 2.6, 3.4), hull.lightened(0.12), 0.0, MeshKit.PAT_HULL,
		MeshKit.NO_BOTTOM)
	s.box(Vector3(0, rise + 1.9, cab_z + 1.71), Vector3(cab_w - 0.5, 0.55, 0.02), lamp, 0.45, MeshKit.PAT_PLAIN,
		MeshKit.FACE_PZ)
	s.box(Vector3(0, rise + 2.7 + 1.9, cab_z - 0.8), Vector3(0.12, 3.8, 0.12), Color(0.24, 0.23, 0.22))
	s.box(Vector3(0, rise + 2.7 + 3.85, cab_z - 0.8), Vector3(0.22, 0.22, 0.22), lamp, 0.9)
	s.quad(Vector3(0, rise + 6.2, cab_z - 0.86), Vector3(0, rise + 6.2, cab_z - 0.86), Vector3(0, rise + 5.6, cab_z - 0.86),
		Vector3(0.06, rise + 5.9, cab_z - 2.2), band)
	s.quad(Vector3(0, rise + 6.2, cab_z - 0.74), Vector3(0, rise + 6.2, cab_z - 0.74), Vector3(0.06, rise + 5.9, cab_z - 2.2),
		Vector3(0, rise + 5.6, cab_z - 0.74), band)
	var crates: int = clampi(floori((zn - zf - 9.0) / 5.0), 1, 6)
	for i: int in crates:
		var cz: float = lerpf(cab_z - 3.5, zf + 3.0, (float(i) + 0.5) / crates)
		var k: int = MeshKit.hash_i(i, variant, 5)
		var ch: float = 1.0 + 0.9 * MeshKit.hash01(k, 1)
		var cw: float = deck_hw * (0.55 + 0.35 * MeshKit.hash01(k, 2))
		s.box(Vector3((MeshKit.hash01(k, 3) - 0.5) * deck_hw * 0.4, rise + ch * 0.5, cz), Vector3(cw * 2.0, ch, 3.4),
			skin.cargo_colors[k % skin.cargo_colors.size()], 0.0, MeshKit.PAT_CANVAS, MeshKit.NO_BOTTOM, 0.0)
	# Stern: engines above the orange band, their glow dropping below the hull.
	s.rect(Vector3(-hw, 0, zf), Vector3(0, rise, 0), Vector3(hw * 2.0, 0, 0), hull.darkened(0.3))
	var engines: int = clampi(roundi(hw * 2.0 / 4.0), 1, 4)
	for i: int in engines:
		var ex: float = -hw + (float(i) + 0.5) * hw * 2.0 / engines
		var r: float = minf(0.9, hw / engines * 0.8)
		var nozzle := Transform3D(Basis(Vector3(r, 0, 0), Vector3(0, 0, -1.2), Vector3(0, r, 0)), Vector3(ex, 1.1, zf))
		s.prism_xform(nozzle, 8, Color(0.12, 0.12, 0.14), 0.0, MeshKit.PAT_PLAIN, false)
		var core := Transform3D(Basis(Vector3(r * 0.72, 0, 0), Vector3(0, 0, -0.05), Vector3(0, r * 0.72, 0)),
			Vector3(ex, 1.1, zf - 1.1))
		s.prism_xform(core, 8, skin.engine_color, 0.9)
		g.rect(Vector3(ex - r * 2.4, 1.1 - r * 2.4, zf - 1.3), Vector3(r * 4.8, 0, 0), Vector3(0, r * 4.8, 0),
			skin.engine_color, 0.4, MeshKit.SHAPE_RADIAL)


# --- A floating advertisement ------------------------------------------------------------

## A hovering ad platform: a plated base (the ceiling), a big screen standing on it and facing the
## approaching player, lights along its edges and hover pods glowing at its sides. The screen's
## brand mark comes from market_logo() (kit_market.gdshaderinc), the hook for the cult symbol.
func _ad(batch: MeshBatch, size: Vector3, edges: Array[float], hw: float, variant: int, surface_y: float) -> void:
	var s: MeshLayer = batch.layer(skin.solid_material())
	var g: MeshLayer = batch.layer(skin.glow_material())
	var zn: float = size.z * 0.5
	var zf: float = -size.z * 0.5
	var base_h: float = 0.7
	var frame: Color = skin.ad_frame_color
	_underside(s, g, hw, zn, zf, edges, frame.lightened(0.35), MeshKit.PAT_HULL, 0.0)
	var lamp: Color = skin.ceiling_lamp_color
	for side: float in [-1.0, 1.0]:
		var x: float = side * hw
		if side > 0.0:
			s.rect(Vector3(x, 0, zn), Vector3(0, 0, zf - zn), Vector3(0, base_h, 0), frame, 0.0, MeshKit.PAT_HULL)
		else:
			s.rect(Vector3(x, 0, zf), Vector3(0, 0, zn - zf), Vector3(0, base_h, 0), frame, 0.0, MeshKit.PAT_HULL)
		s.box(Vector3(x + side * 0.01, base_h * 0.5, (zn + zf) * 0.5), Vector3(0.02, 0.05, zn - zf - 0.6), lamp, 0.5,
			MeshKit.PAT_PLAIN, MeshKit.FACE_PX if side > 0.0 else MeshKit.FACE_NX)
		# Hover pods on the platform's edges, glowing out sideways (never below the running surface).
		for z: float in [zn - 1.2, zf + 2.2]:
			var pod := Vector3(x - side * 0.3, base_h + 0.25, z)
			s.box(pod, Vector3(0.5, 0.5, 1.4), frame.lightened(0.15), 0.0, MeshKit.PAT_PLAIN, MeshKit.NO_BOTTOM)
			s.box(pod + Vector3(side * 0.26, 0, 0), Vector3(0.02, 0.3, 1.0), skin.engine_color, 0.8, MeshKit.PAT_PLAIN,
				MeshKit.FACE_PX if side > 0.0 else MeshKit.FACE_NX)
			g.rect(pod + Vector3(side * 0.3, -0.9, 1.0), Vector3(0, 0, -2.0), Vector3(0, 1.8, 0), skin.engine_color, 0.25,
				MeshKit.SHAPE_RADIAL)
	s.rect(Vector3(-hw, 0, zn), Vector3(hw * 2.0, 0, 0), Vector3(0, base_h, 0), frame, 0.0, MeshKit.PAT_HULL)
	s.rect(Vector3(hw, 0, zf), Vector3(-hw * 2.0, 0, 0), Vector3(0, base_h, 0), frame.darkened(0.2))
	s.rect(Vector3(-hw, base_h, zn), Vector3(hw * 2.0, 0, 0), Vector3(0, 0, zf - zn), frame)
	# The screen, set back a little from the near end, in a dark frame on two legs, and like every
	# decorative sign never lower than decor_min_height.
	var sw: float = minf(hw * 2.0 - 0.6, 12.0)
	var sh: float = clampf(sw * 0.42, 1.8, 5.0)
	var sz: float = zn - 2.5
	var y0: float = maxf(base_h + 0.8, skin.decor_min_height - surface_y + 0.3)
	s.box(Vector3(0, y0 + sh * 0.5, sz - 0.12), Vector3(sw + 0.4, sh + 0.4, 0.2), frame, 0.0, MeshKit.PAT_PLAIN,
		MeshKit.ALL_FACES & ~MeshKit.FACE_NY)
	for leg: float in [-sw * 0.3, sw * 0.3]:
		s.box(Vector3(leg, (base_h + y0) * 0.5, sz - 0.12), Vector3(0.25, y0 - base_h, 0.25), frame)
	var color: Color = skin.ad_colors[variant % skin.ad_colors.size()]
	s.rect(Vector3(-sw * 0.5, y0, sz + 0.001), Vector3(sw, 0, 0), Vector3(0, sh, 0), color, 0.55, MeshKit.PAT_AD,
		Vector2.ZERO, Vector2(sw / sh, 1.0), float(variant * 17 + 7))
	# The cult's emblem in a corner, like a sponsor's badge: small next to the ad's own mark, and only
	# on screens big enough to keep it that way (GDD §5: hidden in plain sight).
	var e: float = maxf(sh * 0.28, skin.emblem_min_size)
	if skin.carries_emblem(variant, 25) and e <= sh * 0.36:
		skin.add_cult_emblem(s, Vector3(sw * 0.5 - e * 0.75, y0 + e * 0.72, sz + 0.012), Vector3.BACK, e, true)
	g.rect(Vector3(-sw * 0.5 - 1.0, y0 - 1.0, sz + 0.3), Vector3(sw + 2.0, 0, 0), Vector3(0, sh + 2.0, 0), color, 0.1,
		MeshKit.SHAPE_FLAT)
