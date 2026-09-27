class_name CorporateCeilings
extends RefCounted
## Ceiling sections in the Corporate zone (CorporateSkin), GDD §5: the undersides of buildings,
## bridges and similar, and occasionally a military ship. Picked per ceiling by hashing its position
## (weights in the skin):
## - a SKYWAY: a glass skyway running along the street, its corridor lit cold white, carried into the
##   towers by cross beams at both ends;
## - a GATE: a tower bridging the street from wall to wall on its upper floors, a curtain wall toward
##   the oncoming runner with the brand's glowing sign on it (only a ceiling across every lane);
## - a VIADUCT: a precast concrete viaduct running along the street, with a military checkpoint on its
##   deck (olive barriers and a guard booth);
## - a SHIP: a military gunship flying low toward the runner, its armoured bow rising over the near end,
##   its engines at the far end, the corporation's mark stencilled on its flanks.
## Every kind is built from the ceiling it's given: its width and position come from the collision box
## and the lane seams (center, size, lane_edges_x), so a ceiling over fewer lanes (narrow ceilings, task
## B3) just builds narrower, and a gate becomes a viaduct. Every underside is one flat plated surface
## across its lanes (no gaps between lanes, GDD §3) with a dark seam and flush cold-white lamps along
## each lane boundary, nothing hanging below it but those lamps, and the far end carries the orange
## edge band of every zone (MeshKit.ceiling_end), so the drop back to the floor reads like a gap edge.
## Everything above the surface stays below TOP_LIMIT, so what hangs out over the street from the walls
## (CorporateTowers.OVER_STREET_MIN) never cuts through a ceiling.
## Ceiling space: origin at the centre of the underside (the ceiling surface), z = -distance.

enum Kind { SKYWAY, GATE, VIADUCT, SHIP }

const END_BAND: float = 1.2
## Nothing of a ceiling rises higher than this above its underside.
const TOP_LIMIT: float = 7.4
## Flush lamps along each lane seam, this far apart.
const LAMP_SPACING: float = 7.5

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: CorporateSkin:
	get:
		return _skin.get_ref() as CorporateSkin
var _skin: WeakRef
var _meshes: Dictionary = {}


func _init(p_skin: CorporateSkin) -> void:
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
	var weights: Array[float] = [skin.skyway_weight, skin.gate_weight if full else 0.0,
		skin.viaduct_weight + (0.0 if full else skin.gate_weight), skin.ship_weight]
	var total: float = 0.0
	for w: float in weights:
		total += w
	if total <= 0.0:
		return Kind.VIADUCT
	var r: float = MeshKit.hash01(MeshKit.key(center.z), MeshKit.key(size.z), 90) * total
	for k: int in weights.size():
		r -= weights[k]
		if r < 0.0:
			return k
	return Kind.VIADUCT


## The mesh of a ceiling of `kind` (variant 0-3) with collision size `size` centred on offset_x, seams
## at lane_edges_x (world x), its underside at world height surface_y. In ceiling space (see above);
## build() places it.
func mesh_for(kind: int, variant: int, size: Vector3, lane_edges_x: Array[float], offset_x: float, wall_x: float,
		surface_y: float) -> ArrayMesh:
	var batch := MeshBatch.new()
	var hw: float = size.x * 0.5 + 0.15
	var edges: Array[float] = []
	for x: float in lane_edges_x:
		edges.append(x - offset_x)
	match kind:
		Kind.GATE:
			_gate(batch, size, edges, wall_x, variant, surface_y)
		Kind.SKYWAY:
			_skyway(batch, size, edges, hw, wall_x, offset_x, variant)
		Kind.SHIP:
			_ship(batch, size, edges, hw, variant)
		_:
			_viaduct(batch, size, edges, hw, wall_x, offset_x, variant)
	return batch.to_mesh()


## The underside across [-hw, hw] from the far end's band to the near end: one plated surface, a dark
## seam along each lane boundary with flush cold-white lamps on it, and the orange band at the end.
func _underside(s: MeshLayer, g: MeshLayer, hw: float, zn: float, zf: float, edges: Array[float], color: Color,
		plate: float) -> void:
	var z0: float = zf + END_BAND
	s.rect(Vector3(-hw, 0, z0), Vector3(hw * 2.0, 0, 0), Vector3(0, 0, zn - z0), color, 0.0, MeshKit.PAT_CORP_PLATE,
		Vector2.ZERO, Vector2.ONE, plate)
	var seam := Color(color.darkened(0.45), 1.0)
	var lamp: Color = skin.ceiling_lamp_color
	for x: float in edges:
		s.box(Vector3(x, -0.006, (zn + z0) * 0.5), Vector3(0.07, 0.012, zn - z0), seam, 0.0, MeshKit.PAT_PLAIN,
			MeshKit.ALL_FACES & ~MeshKit.FACE_PY)
		var z: float = z0 + 4.0
		while z < zn - 2.0:
			s.box(Vector3(x, -0.02, z), Vector3(0.22, 0.04, 0.5), lamp, 0.75, MeshKit.PAT_PLAIN, MeshKit.ALL_FACES & ~MeshKit.FACE_PY)
			g.rect(Vector3(x - 0.8, -0.06, z + 0.9), Vector3(1.6, 0, 0), Vector3(0, 0, -1.8), lamp, 0.26, MeshKit.SHAPE_RADIAL)
			z += LAMP_SPACING
	MeshKit.ceiling_end(s, g, hw, zf, END_BAND, skin.gap_edge_color)


# --- A glass skyway running along the street -------------------------------------------------

## A glass skyway over the lanes: the steel soffit (the surface), the slab's fascia with a strip of cold
## light, the corridor's glass walls lit from inside (PAT_CORP_GLASS) at its sides and its near end, a
## steel roof with the brand's mark over the near end, and cross beams into the towers at both ends.
func _skyway(batch: MeshBatch, size: Vector3, edges: Array[float], hw: float, wall_x: float, offset_x: float,
		variant: int) -> void:
	var s: MeshLayer = batch.layer(skin.solid_material())
	var g: MeshLayer = batch.layer(skin.glow_material())
	var zn: float = size.z * 0.5
	var zf: float = -size.z * 0.5
	var slab: float = size.y
	var corridor: float = 3.1
	var steel: Color = skin.soffit_color.lerp(skin.gunmetal_color, 0.25 * float(variant % 2))
	_underside(s, g, hw, zn, zf, edges, skin.soffit_color, 0.0)
	var lamp: Color = skin.ceiling_lamp_color
	# The slab's fascia along both sides and across the near end, a strip of cold light along it.
	for side: float in [-1.0, 1.0]:
		var x: float = side * hw
		if side > 0.0:
			s.rect(Vector3(x, 0, zn), Vector3(0, 0, zf - zn), Vector3(0, slab, 0), steel, 0.0, MeshKit.PAT_CORP_PLATE,
				Vector2.ZERO, Vector2.ONE, 2.0)
		else:
			s.rect(Vector3(x, 0, zf), Vector3(0, 0, zn - zf), Vector3(0, slab, 0), steel, 0.0, MeshKit.PAT_CORP_PLATE,
				Vector2.ZERO, Vector2.ONE, 2.0)
		s.box(Vector3(x + side * 0.01, 0.2, (zn + zf) * 0.5), Vector3(0.02, 0.05, zn - zf - 0.4), lamp, 0.4, MeshKit.PAT_PLAIN,
			MeshKit.FACE_PX if side > 0.0 else MeshKit.FACE_NX)
	s.rect(Vector3(-hw, 0, zn), Vector3(hw * 2.0, 0, 0), Vector3(0, slab, 0), steel, 0.0, MeshKit.PAT_CORP_PLATE,
		Vector2.ZERO, Vector2.ONE, 2.0)
	s.box(Vector3(0, 0.2, zn + 0.01), Vector3(hw * 2.0 - 0.2, 0.05, 0.02), lamp, 0.45, MeshKit.PAT_PLAIN, MeshKit.FACE_PZ)
	# The corridor: glass sides and the near end, a steel roof, mullions standing on the slab.
	var y0: float = slab
	var y1: float = slab + corridor
	var inset: float = 0.25
	var gx: float = hw - inset
	var gp: float = corridor * 10.0
	s.rect(Vector3(gx, y0, zn - inset), Vector3(0, 0, zf - zn + inset * 2.0), Vector3(0, corridor, 0), skin.window_color, 0.5,
		MeshKit.PAT_CORP_GLASS, Vector2(zn, 0.0), Vector2(zf, corridor), gp)
	s.rect(Vector3(-gx, y0, zf + inset), Vector3(0, 0, zn - zf - inset * 2.0), Vector3(0, corridor, 0), skin.window_color, 0.5,
		MeshKit.PAT_CORP_GLASS, Vector2(zf, 0.0), Vector2(zn, corridor), gp)
	s.rect(Vector3(-gx, y0, zn - inset), Vector3(gx * 2.0, 0, 0), Vector3(0, corridor, 0), skin.window_color, 0.5,
		MeshKit.PAT_CORP_GLASS, Vector2(-gx, 0.0), Vector2(gx, corridor), gp)
	s.box(Vector3(0, y1 + 0.3, (zn + zf) * 0.5), Vector3(hw * 2.0, 0.6, zn - zf), steel.darkened(0.2), 0.0,
		MeshKit.PAT_CORP_PLATE, MeshKit.ALL_FACES & ~MeshKit.FACE_NY, 2.0)
	# The brand's mark on the roof's fascia over the near end, glowing.
	var mw: float = minf(hw * 2.0 - 0.6, 2.4)
	var m: float = 0.95
	s.rect(Vector3(-mw * 0.5, y1 + 0.02, zn + 0.01), Vector3(mw, 0, 0), Vector3(0, 0.56, 0), skin.brand_color, skin.brand_glow,
		MeshKit.PAT_CORP_LOGO, Vector2(-m * mw / 0.56, -m), Vector2(m * mw / 0.56, m), 0.0)
	# Cross beams into the towers at both ends, level with the roof.
	for z: float in [zn - 1.2, zf + 1.2]:
		var x0: float = -wall_x - offset_x
		var x1: float = wall_x - offset_x
		s.box(Vector3((x0 + x1) * 0.5, y1 + 0.3, z), Vector3(x1 - x0, 0.5, 0.45), skin.gunmetal_color, 0.0, MeshKit.PAT_CORP_PLATE,
			MeshKit.ALL_FACES, 2.0)


# --- A tower bridging the street -----------------------------------------------------------

## A tower spanning the street from wall to wall on its upper floors: a precast soffit over the lanes
## and, toward the oncoming runner, a curtain wall with the brand's glowing sign, a steel band along
## the bottom edge so the edge of the ceiling reads from the floor, and a cornice on top.
func _gate(batch: MeshBatch, size: Vector3, edges: Array[float], wall_x: float, variant: int, surface_y: float) -> void:
	var s: MeshLayer = batch.layer(skin.solid_material())
	var g: MeshLayer = batch.layer(skin.glow_material())
	var f: MeshLayer = batch.layer(skin.facade_material())
	var zn: float = size.z * 0.5
	var zf: float = -size.z * 0.5
	var w: float = wall_x
	_underside(s, g, w, zn, zf, edges, skin.concrete_color, 3.0)
	var wall: Color = skin.facade_colors[(variant * 2 + 1) % skin.facade_colors.size()]
	var height: float = TOP_LIMIT - 0.4 - 0.6 * float(variant % 2)
	f.quad_uv(Vector3(-w, 0, zn), Vector3(-w, height, zn), Vector3(w, height, zn), Vector3(w, 0, zn),
		Vector2(-w, surface_y), Vector2(-w, surface_y + height), Vector2(w, surface_y + height), Vector2(w, surface_y),
		wall, 0.45, CorporateTowers.STYLE_CURTAIN, float(variant * 7 + 5))
	var trim: Color = skin.gunmetal_color.lightened(0.12)
	s.box(Vector3(0, 0.4, zn + 0.1), Vector3(w * 2.0, 0.8, 0.2), trim, 0.0, MeshKit.PAT_CORP_PLATE,
		MeshKit.ALL_FACES & ~MeshKit.FACE_PY, 2.0)
	s.box(Vector3(0, 0.82, zn + 0.13), Vector3(w * 2.0 - 0.2, 0.04, 0.02), skin.ceiling_lamp_color, 0.45, MeshKit.PAT_PLAIN,
		MeshKit.FACE_PZ)
	s.box(Vector3(0, height, zn + 0.12), Vector3(w * 2.0, 0.3, 0.24), trim, 0.0, MeshKit.PAT_CORP_PLATE,
		MeshKit.ALL_FACES & ~MeshKit.FACE_NY, 2.0)
	# The brand's sign over the middle, above the wall-run band like every decorative sign.
	var sh: float = minf(2.8, height - 2.6)
	var sy: float = maxf(skin.decor_min_height - surface_y, 0.0) + 0.6
	if sh > 1.2 and sy + sh < height - 0.3:
		var sw: float = minf(w * 1.3, sh * 3.2)
		var m: float = 0.95
		s.box(Vector3(0, sy + sh * 0.5, zn + 0.05), Vector3(sw + 0.3, sh + 0.3, 0.1), Color(0.04, 0.045, 0.05))
		s.rect(Vector3(-sw * 0.5, sy, zn + 0.105), Vector3(sw, 0, 0), Vector3(0, sh, 0), skin.brand_color, skin.brand_glow,
			MeshKit.PAT_CORP_LOGO, Vector2(-m * sw / sh, -m), Vector2(m * sw / sh, m), 1.0)
		g.rect(Vector3(-sw * 0.5 - 1.0, sy - 1.0, zn + 0.4), Vector3(sw + 2.0, 0, 0), Vector3(0, sh + 2.0, 0), skin.brand_color,
			0.08, MeshKit.SHAPE_FLAT)


# --- A concrete viaduct running along the street ------------------------------------------

## A precast viaduct over the lanes: its underside (the surface), fascias along its sides and across
## its near end with a strip of cold light, a parapet with a rail, a military checkpoint on its deck
## (olive barrier blocks, a guard booth, a floodlight), and girders into the towers at both ends.
func _viaduct(batch: MeshBatch, size: Vector3, edges: Array[float], hw: float, wall_x: float, offset_x: float,
		variant: int) -> void:
	var s: MeshLayer = batch.layer(skin.solid_material())
	var g: MeshLayer = batch.layer(skin.glow_material())
	var zn: float = size.z * 0.5
	var zf: float = -size.z * 0.5
	var deck: float = 1.1
	var concrete: Color = skin.concrete_color * Color(0.95 + 0.05 * variant, 0.95 + 0.05 * variant, 0.95 + 0.05 * variant)
	_underside(s, g, hw, zn, zf, edges, concrete, 3.0)
	var lamp: Color = skin.ceiling_lamp_color
	for side: float in [-1.0, 1.0]:
		var x: float = side * hw
		if side > 0.0:
			s.rect(Vector3(x, 0, zn), Vector3(0, 0, zf - zn), Vector3(0, deck, 0), concrete, 0.0, MeshKit.PAT_CORP_PLATE,
				Vector2.ZERO, Vector2.ONE, 3.0)
		else:
			s.rect(Vector3(x, 0, zf), Vector3(0, 0, zn - zf), Vector3(0, deck, 0), concrete, 0.0, MeshKit.PAT_CORP_PLATE,
				Vector2.ZERO, Vector2.ONE, 3.0)
		s.box(Vector3(x + side * 0.01, 0.16, (zn + zf) * 0.5), Vector3(0.02, 0.05, zn - zf - 0.4), lamp, 0.35, MeshKit.PAT_PLAIN,
			MeshKit.FACE_PX if side > 0.0 else MeshKit.FACE_NX)
		# The parapet and its rail.
		s.box(Vector3(x - side * 0.12, deck + 0.45, (zn + zf) * 0.5), Vector3(0.24, 0.9, zn - zf), concrete.darkened(0.08), 0.0,
			MeshKit.PAT_CORP_PLATE, MeshKit.NO_BOTTOM, 3.0)
		s.box(Vector3(x - side * 0.12, deck + 1.05, (zn + zf) * 0.5), Vector3(0.06, 0.06, zn - zf), skin.gunmetal_color)
	s.rect(Vector3(-hw, 0, zn), Vector3(hw * 2.0, 0, 0), Vector3(0, deck, 0), concrete, 0.0, MeshKit.PAT_CORP_PLATE,
		Vector2.ZERO, Vector2.ONE, 3.0)
	s.box(Vector3(0, 0.16, zn + 0.01), Vector3(hw * 2.0 - 0.2, 0.05, 0.02), lamp, 0.4, MeshKit.PAT_PLAIN, MeshKit.FACE_PZ)
	s.rect(Vector3(hw, 0, zf), Vector3(-hw * 2.0, 0, 0), Vector3(0, deck, 0), concrete.darkened(0.2))
	s.rect(Vector3(-hw, deck, zn), Vector3(hw * 2.0, 0, 0), Vector3(0, 0, zf - zn), concrete.darkened(0.1), 0.0,
		MeshKit.PAT_CORP_PLATE, Vector2.ZERO, Vector2.ONE, 3.0)
	# The checkpoint: a line of olive barrier blocks, a guard booth, a floodlight on a pole.
	var olive: Color = skin.olive_color
	var bx: float = (hw - 1.0) * (-1.0 if variant % 2 == 0 else 1.0)
	var z: float = zn - 2.0
	while z > zf + 3.0:
		s.box(Vector3(bx, deck + 0.4, z), Vector3(0.6, 0.8, 1.8), olive, 0.0, MeshKit.PAT_CORP_PLATE, MeshKit.NO_BOTTOM, 3.0)
		z -= 2.3
	var booth := Vector3(-bx * 0.5, deck, zn - 3.5)
	s.box(booth + Vector3(0, 1.2, 0), Vector3(1.8, 2.4, 1.8), olive.darkened(0.05), 0.0, MeshKit.PAT_CORP_PLATE,
		MeshKit.NO_BOTTOM, 1.0)
	s.box(booth + Vector3(0, 1.6, 0.91), Vector3(1.3, 0.5, 0.02), Color(0.03, 0.035, 0.045), 0.0, MeshKit.PAT_GLASS, MeshKit.FACE_PZ)
	s.box(booth + Vector3(0, 2.5, 0), Vector3(2.0, 0.12, 2.0), skin.gunmetal_color)
	s.box(booth + Vector3(0.7, 3.4, -0.7), Vector3(0.1, 1.8, 0.1), skin.gunmetal_color)
	s.box(booth + Vector3(0.7, 4.35, -0.55), Vector3(0.3, 0.2, 0.3), skin.flood_color, 0.85)
	# Girders into the towers at both ends, just above the deck.
	for gz: float in [zn - 0.8, zf + 0.8]:
		var x0: float = -wall_x - offset_x
		var x1: float = wall_x - offset_x
		s.box(Vector3((x0 + x1) * 0.5, deck + 0.35, gz), Vector3(x1 - x0, 0.5, 0.45), skin.gunmetal_color, 0.0,
			MeshKit.PAT_RIBS)


# --- A military gunship flying low ---------------------------------------------------------

## A military gunship heading toward the runner: an armoured underside (the surface), sloped flanks
## with the corporation's mark stencilled on them and a row of running lights, an armoured bow rising
## over the near end with a dark cockpit band, a superstructure with a radar dome and masts, and its
## engines at the far end over the orange band, their cold glow dropping below the hull. No guns.
func _ship(batch: MeshBatch, size: Vector3, edges: Array[float], hw: float, variant: int) -> void:
	var s: MeshLayer = batch.layer(skin.solid_material())
	var g: MeshLayer = batch.layer(skin.glow_material())
	var zn: float = size.z * 0.5
	var zf: float = -size.z * 0.5
	var hull: Color = skin.olive_color if variant % 2 == 0 else skin.gunmetal_color.lightened(0.2)
	var trim: Color = skin.gunmetal_color if variant % 2 == 0 else skin.olive_color
	var rise: float = 2.6
	var slope: float = minf(0.9, hw * 0.3)
	var lamp: Color = skin.flood_color
	_underside(s, g, hw, zn, zf, edges, hull, 1.0)
	# Sloped flanks: armour, a row of running lights, the corporation's mark in pale paint.
	for side: float in [-1.0, 1.0]:
		var x: float = side * hw
		var top := Vector3(-side * slope, rise, 0)
		var z0: float = zn if side > 0.0 else zf
		var u := Vector3(0, 0, zf - zn if side > 0.0 else zn - zf)
		s.rect(Vector3(x, 0, z0), u, top, hull.lightened(0.06), 0.0, MeshKit.PAT_CORP_PLATE, Vector2.ZERO, Vector2.ONE, 1.0)
		var lz: float = zf + 3.0
		while lz < zn - 1.5:
			s.box(Vector3(x - side * slope * 0.2, rise * 0.2, lz), Vector3(0.16, 0.12, 0.16), lamp, 0.6)
			lz += 4.0
		# The mark near the bow, on the flank's plane (seen from the walls and from under the bow).
		var mz: float = zn - 4.5
		if mz - 1.6 > zf + 3.0:
			var p0 := Vector3(x, 0.0, mz) + top * 0.28 + Vector3(side * 0.02, 0, 0)
			var up: Vector3 = top.normalized() * 1.6
			var m: float = 1.0
			if side > 0.0:
				s.quad_uv(p0 + Vector3(0, 0, 1.6), p0 + Vector3(0, 0, 1.6) + up, p0 + up, p0, Vector2(-m, -m), Vector2(-m, m),
					Vector2(m, m), Vector2(m, -m), hull, 0.0, MeshKit.PAT_CORP_LOGO, 3.0)
			else:
				s.quad_uv(p0, p0 + up, p0 + Vector3(0, 0, 1.6) + up, p0 + Vector3(0, 0, 1.6), Vector2(-m, -m), Vector2(-m, m),
					Vector2(m, m), Vector2(m, -m), hull, 0.0, MeshKit.PAT_CORP_LOGO, 3.0)
	# The bow: rising from the near end toward the runner, narrowing to a blunt armoured nose.
	var tip_hw: float = hw * 0.5
	var tip_z: float = zn + 4.5
	var bl := Vector3(-hw, 0, zn)
	var br := Vector3(hw, 0, zn)
	var tl := Vector3(-tip_hw, rise, tip_z)
	var tr := Vector3(tip_hw, rise, tip_z)
	s.quad(bl, tl, tr, br, hull, 0.0, MeshKit.PAT_CORP_PLATE, 1.0)
	s.quad(br, tr, br + Vector3(-slope, rise, 0), br + Vector3(-slope, rise, 0), hull.lightened(0.06))
	s.quad(bl, bl + Vector3(slope, rise, 0), tl, tl, hull.lightened(0.06))
	s.box(Vector3(0, rise - 0.35, tip_z - 0.3), Vector3(tip_hw * 1.6, 0.4, 0.6), Color(0.03, 0.035, 0.045), 0.0, MeshKit.PAT_GLASS,
		MeshKit.FACE_PZ | MeshKit.FACE_PY)
	for side: float in [-1.0, 1.0]:
		s.box(Vector3(side * tip_hw * 0.8, rise - 0.85, tip_z - 0.1), Vector3(0.36, 0.16, 0.2), lamp, 0.9)
		g.rect(Vector3(side * tip_hw * 0.8 - 1.0, rise - 1.85, tip_z + 0.05), Vector3(2.0, 0, 0), Vector3(0, 2.0, 0), lamp, 0.3,
			MeshKit.SHAPE_RADIAL)
	# The deck and a superstructure: an armoured bridge with dark slits, a radar dome, two masts.
	var deck_hw: float = hw - slope
	s.rect(Vector3(-deck_hw, rise, zn), Vector3(deck_hw * 2.0, 0, 0), Vector3(0, 0, zf - zn), trim, 0.0, MeshKit.PAT_CORP_PLATE,
		Vector2.ZERO, Vector2.ONE, 1.0)
	var bz: float = zn - 3.5
	var bw: float = minf(deck_hw * 1.2, 4.0)
	s.box(Vector3(0, rise + 1.1, bz), Vector3(bw, 2.2, 3.2), hull.lightened(0.1), 0.0, MeshKit.PAT_CORP_PLATE, MeshKit.NO_BOTTOM, 1.0)
	s.box(Vector3(0, rise + 1.6, bz + 1.61), Vector3(bw - 0.6, 0.35, 0.02), Color(0.03, 0.035, 0.045), 0.0, MeshKit.PAT_GLASS,
		MeshKit.FACE_PZ)
	s.prism(Vector3(0, rise + 2.2, bz - 0.4), 0.8, 0.5, 10, trim)
	s.prism_xform(Transform3D(Basis.from_scale(Vector3(0.95, 0.8, 0.95)), Vector3(0, rise + 2.7, bz - 0.4)), 10,
		Color(0.62, 0.64, 0.66))
	for mx: float in [-bw * 0.35, bw * 0.35]:
		s.box(Vector3(mx, rise + 3.4, bz + 0.8), Vector3(0.1, 2.4, 0.1), trim)
	s.box(Vector3(bw * 0.35, rise + 4.65, bz + 0.8), Vector3(0.2, 0.2, 0.2), lamp, 0.9)
	# Stern: engines above the orange band, their glow dropping below the hull so it reads from underneath.
	s.rect(Vector3(-hw, 0, zf), Vector3(0, rise, 0), Vector3(hw * 2.0, 0, 0), trim.darkened(0.3))
	var engines: int = clampi(roundi(hw * 2.0 / 4.0), 1, 4)
	for i: int in engines:
		var ex: float = -hw + (float(i) + 0.5) * hw * 2.0 / engines
		var r: float = minf(0.95, hw / engines * 0.8)
		var nozzle := Transform3D(Basis(Vector3(r, 0, 0), Vector3(0, 0, -1.2), Vector3(0, r, 0)), Vector3(ex, 1.2, zf))
		s.prism_xform(nozzle, 8, Color(0.1, 0.1, 0.12), 0.0, MeshKit.PAT_PLAIN, false)
		var core := Transform3D(Basis(Vector3(r * 0.72, 0, 0), Vector3(0, 0, -0.05), Vector3(0, r * 0.72, 0)),
			Vector3(ex, 1.2, zf - 1.1))
		s.prism_xform(core, 8, skin.engine_color, 0.9)
		g.rect(Vector3(ex - r * 2.4, 1.2 - r * 2.4, zf - 1.3), Vector3(r * 4.8, 0, 0), Vector3(0, r * 4.8, 0), skin.engine_color,
			0.4, MeshKit.SHAPE_RADIAL)
	g.rect(Vector3(-hw, -2.2, zf - 0.3), Vector3(hw * 2.0, 0, 0), Vector3(0, 3.2, 0), skin.engine_color, 0.4, MeshKit.SHAPE_RADIAL)
