class_name GoldenPalaceCeilings
extends RefCounted
## Ceiling sections in the Golden Palace (GoldenPalaceSkin, GDD §5: "the ceiling pieces are a
## palace's own spans: bridges between galleries, hanging chandeliers on gilded frames, archways,
## balconies"), reusing the Golden Zone's gold and marble (golden_metal(), golden_marble(), PAT_GOLD,
## PAT_MARBLE, PAT_COFFER), picked per ceiling by hashing its position (weights in the skin):
## - a bridge between two galleries, across every lane: a gilded, coffered underside, a marble face
##   toward the approach with the cult's emblem in relief at its middle and a gold rail on top; over
##   fewer lanes, the narrower BALCONY: the same deck and rail, scaled down, overlooking the hall;
## - a hanging chandelier: a denser, more ornate coffered underside with a gilded rosette and a ring
##   of warm lamps at its middle, over any width -- always flush with the underside (nothing may hang
##   below it, the rule every ceiling keeps);
## - a gallery of archways, across every lane: parabolic gold ribs over a flat marble deck, the
##   emblem on the first arch's keystone.
## Every kind is built from the ceiling it's given: its width and position come from the collision
## box and the lane seams, so a ceiling over fewer lanes just builds narrower; only a bridge or an
## archway across every lane reaches from wall to wall. Every underside is one flat surface across
## its lanes with a darker seam and flush warm lamps along each lane seam, nothing hanging below it
## but those, and the far end carries the orange edge band of every zone. Structures keep
## hall_clear_height above their underside: the vast hall's ceiling stays far above (GDD §5), with no
## wall decoration to duck under (the colonnade stands well clear, to the sides).
## Ceiling space: origin at the centre of the underside, z = -distance.

enum Kind { BRIDGE, ARCHWAY, CHANDELIER, BALCONY }

const END_BAND: float = 1.2
const LAMP_SPACING: float = 7.5
const FASCIA: float = 2.0
const CORNICE: float = 0.2
const BALCONY_FASCIA: float = 1.0
const CREST: float = 2.4
const CREST_FOOT: float = 0.3
const KEYSTONE: float = 1.9
const ARCH_SPACING: float = 6.0
const ARCH_RISE: float = 3.8
const ARCH_DECK: float = 0.5
const ARCH_THICK: float = 0.45
const ARCH_SEGMENTS: int = 12
## A chandelier's rosette and its ring of lamps (both flush, never below the underside).
const ROSETTE_SPACING: float = 11.0
const ROSETTE_RADIUS: float = 1.4
const LAMP_RING_RADIUS: float = 2.0
const LAMP_RING_COUNT: int = 6
const RIM_DEPTH: float = 0.1
const RELIEF_STANDOFF: float = 0.05

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: GoldenPalaceSkin:
	get:
		return _skin.get_ref() as GoldenPalaceSkin
var _skin: WeakRef
var _meshes: Dictionary = {}


func _init(p_skin: GoldenPalaceSkin) -> void:
	_skin = weakref(p_skin)


## Dresses the ceiling with collision box center/size and seams lane_edges_x (world x). wall_x is the
## wall faces' distance from the track's centre.
func build(parent: Node3D, center: Vector3, size: Vector3, lane_edges_x: Array[float], wall_x: float) -> void:
	var kind: int = kind_of(center, size, wall_x)
	var variant: int = MeshKit.hash_i(MeshKit.key(center.z), MeshKit.key(size.z), 191) % 4
	var id: String = "%d_%d_%s_%s_%s_%s" % [kind, variant, size, lane_edges_x, center.x, wall_x]
	var mesh: ArrayMesh = _meshes.get(id)
	if mesh == null:
		if _meshes.size() > 256:
			_meshes.clear()
		mesh = mesh_for(kind, variant, size, lane_edges_x, center.x, wall_x)
		_meshes[id] = mesh
	MeshBatch.add_instance(parent, mesh, "", Vector3(center.x, center.y - size.y * 0.5, center.z))


## Which kind of structure forms this ceiling (a bridge or an archway needs every lane; over fewer
## lanes a bridge becomes the narrower BALCONY, and an archway's share folds into it too; a
## chandelier hangs over any width).
func kind_of(center: Vector3, size: Vector3, wall_x: float) -> int:
	var full: bool = absf(center.x) < 0.01 and size.x * 0.5 > wall_x - 0.6
	var weights: Array[float] = [skin.bridge_weight if full else 0.0, skin.archway_weight if full else 0.0,
		skin.yacht_weight, 0.0 if full else skin.bridge_weight + skin.archway_weight]
	var total: float = 0.0
	for w: float in weights:
		total += w
	if total <= 0.0:
		return Kind.BRIDGE if full else Kind.BALCONY
	var r: float = MeshKit.hash01(MeshKit.key(center.z), MeshKit.key(size.z), 190) * total
	for k: int in weights.size():
		r -= weights[k]
		if r < 0.0:
			return k
	return Kind.BRIDGE if full else Kind.BALCONY


## How high a ceiling's structure may rise above its underside: the skin's hall_clear_height. The
## vast hall stays far above (GDD §5); nothing of the colonnade reaches over the lanes to duck under.
func headroom() -> float:
	return skin.hall_clear_height


## The mesh of a ceiling of `kind` (colour variant 0-3) with collision size `size` centred on
## offset_x, seams at lane_edges_x (world x), walls at ±wall_x. In ceiling space; build() places it.
func mesh_for(kind: int, variant: int, size: Vector3, lane_edges_x: Array[float], offset_x: float, wall_x: float) -> ArrayMesh:
	var batch := MeshBatch.new()
	var full: bool = absf(offset_x) < 0.01 and size.x * 0.5 > wall_x - 0.6
	var hw: float = size.x * 0.5 + 0.15
	var edges: Array[float] = []
	for x: float in lane_edges_x:
		edges.append(x - offset_x)
	match kind:
		Kind.ARCHWAY:
			_archway(batch, size, edges, wall_x)
		Kind.CHANDELIER:
			_chandelier(batch, size, edges, hw, variant)
		Kind.BALCONY:
			_balcony(batch, size, edges, hw, variant)
		_:
			if full:
				_bridge(batch, size, edges, wall_x, variant)
			else:
				_balcony(batch, size, edges, hw, variant)
	return batch.to_mesh()


## The underside across [-hw, hw] from the far end's band to the near end: one surface in `pattern`,
## a darker seam and flush warm lamps along each lane seam, and the orange band at the far end.
func _underside(s: MeshLayer, g: MeshLayer, hw: float, zn: float, zf: float, edges: Array[float], color: Color,
		pattern: int, param: float) -> void:
	var z0: float = zf + END_BAND
	s.rect(Vector3(-hw, 0, z0), Vector3(hw * 2.0, 0, 0), Vector3(0, 0, zn - z0), color, 0.0, pattern, Vector2.ZERO,
		Vector2.ONE, param)
	var seam := Color(skin.vein_color, 1.0)
	var lamp: Color = skin.ceiling_lamp_color
	for x: float in edges:
		s.box(Vector3(x, -0.006, (zn + z0) * 0.5), Vector3(0.06, 0.012, zn - z0), seam, 0.0, MeshKit.PAT_PLAIN,
			MeshKit.ALL_FACES & ~MeshKit.FACE_PY)
		var z: float = z0 + 4.0
		while z < zn - 2.0:
			s.box(Vector3(x, -0.02, z), Vector3(0.24, 0.04, 0.24), lamp, 0.75, MeshKit.PAT_PLAIN,
				MeshKit.ALL_FACES & ~MeshKit.FACE_PY)
			g.rect(Vector3(x - 0.8, -0.06, z + 0.8), Vector3(1.6, 0, 0), Vector3(0, 0, -1.6), lamp, 0.28, MeshKit.SHAPE_RADIAL)
			z += LAMP_SPACING
	MeshKit.ceiling_end(s, g, hw, zf, END_BAND, skin.gap_edge_color)


## The cult's emblem in relief (GDD §5: shown openly) on a gold-rimmed marble panel `panel` metres
## square facing +z, its middle at `c`.
func _relief(s: MeshLayer, c: Vector3, panel: float) -> void:
	s.box(c + Vector3(0.0, 0.0, RIM_DEPTH * 0.5), Vector3(panel + 0.22, panel + 0.22, RIM_DEPTH), skin.gold_color, 0.0,
		MeshKit.PAT_GOLD, MeshKit.ALL_FACES & ~MeshKit.FACE_NZ, 0.95)
	GoldenSkin.emblem_panel(s, c + Vector3(-panel * 0.5, -panel * 0.5, RIM_DEPTH + RELIEF_STANDOFF), Vector3(panel, 0, 0),
		Vector3(0, panel, 0), panel * 0.78, skin.stone_colors[0], 1)


# --- A bridge between galleries ---------------------------------------------------------------

## A bridge across every lane: the coffered underside from wall to wall, a marble face toward the
## approach with a gold band along its bottom edge, a gold cornice on top, a rail of marble posts
## under a gold rail between two newels, and the crest at its middle rising over the rail: the
## emblem in relief.
func _bridge(batch: MeshBatch, size: Vector3, edges: Array[float], wall_x: float, variant: int) -> void:
	var s: MeshLayer = batch.layer(skin.solid_material())
	var g: MeshLayer = batch.layer(skin.glow_material())
	var zn: float = size.z * 0.5
	var zf: float = -size.z * 0.5
	var w: float = wall_x
	var fascia: float = clampf(headroom() - CORNICE, 1.0, FASCIA)
	_underside(s, g, w, zn, zf, edges, skin.coffer_color, MeshKit.PAT_COFFER, 1.5)
	var marble: Color = skin.stone_colors[(variant + 1) % skin.stone_colors.size()]
	s.rect(Vector3(-w, 0, zn), Vector3(w * 2.0, 0, 0), Vector3(0, fascia, 0), marble, 0.0, MeshKit.PAT_MARBLE)
	s.box(Vector3(0, 0.1, zn + 0.05), Vector3(w * 2.0, 0.2, 0.1), skin.gold_color, 0.0, MeshKit.PAT_GOLD,
		MeshKit.FACE_PZ | MeshKit.FACE_NY | MeshKit.FACE_PY, 0.9)
	s.box(Vector3(0, fascia + CORNICE * 0.5, zn + 0.06), Vector3(w * 2.0, CORNICE, 0.2), skin.gold_color, 0.0,
		MeshKit.PAT_GOLD, MeshKit.FACE_PZ | MeshKit.FACE_NY | MeshKit.FACE_PY, 0.9)
	var rail_top: float = fascia + CORNICE + 0.9
	var rail_x: float = w - 0.3
	if rail_x > 0.8:
		var posts: int = maxi(roundi(rail_x * 2.0 / 1.3), 1)
		for i: int in range(1, posts):
			s.box(Vector3(-rail_x + rail_x * 2.0 * float(i) / float(posts), fascia + CORNICE + 0.4, zn - 0.15),
				Vector3(0.14, 0.8, 0.14), marble, 0.0, MeshKit.PAT_MARBLE, MeshKit.ALL_FACES & ~(MeshKit.FACE_NY | MeshKit.FACE_NZ))
		s.box(Vector3(0, rail_top - 0.05, zn - 0.15), Vector3(rail_x * 2.0, 0.1, 0.18), skin.gold_color, 0.0, MeshKit.PAT_GOLD,
			MeshKit.ALL_FACES & ~MeshKit.FACE_NZ, 0.95)
	var crest: float = CREST
	while crest > 1.0 and CREST_FOOT + crest + 0.1 > headroom():
		crest -= 0.1
	_relief(s, Vector3(0.0, CREST_FOOT + crest * 0.5, zn + 0.01), crest)


## A narrower balcony over some of the lanes (a bridge over fewer lanes, GDD §5: "balconies"): a deck
## with the coffered underside, marble faces with gold bands, a gold rail on top, the emblem at the
## middle of its face if it's wide enough, and gold beams carrying it into the colonnade at both ends.
func _balcony(batch: MeshBatch, size: Vector3, edges: Array[float], hw: float, variant: int) -> void:
	var s: MeshLayer = batch.layer(skin.solid_material())
	var g: MeshLayer = batch.layer(skin.glow_material())
	var zn: float = size.z * 0.5
	var zf: float = -size.z * 0.5
	var h: float = minf(BALCONY_FASCIA, headroom() - 0.9)
	_underside(s, g, hw, zn, zf, edges, skin.coffer_color, MeshKit.PAT_COFFER, 1.5)
	var marble: Color = skin.stone_colors[(variant + 2) % skin.stone_colors.size()]
	for side: float in [-1.0, 1.0]:
		var x: float = side * hw
		if side > 0.0:
			s.rect(Vector3(x, 0, zn), Vector3(0, 0, zf - zn), Vector3(0, h, 0), marble, 0.0, MeshKit.PAT_MARBLE)
		else:
			s.rect(Vector3(x, 0, zf), Vector3(0, 0, zn - zf), Vector3(0, h, 0), marble, 0.0, MeshKit.PAT_MARBLE)
		s.box(Vector3(x + side * 0.008, 0.09, (zn + zf) * 0.5), Vector3(0.016, 0.18, zn - zf), skin.gold_color, 0.0,
			MeshKit.PAT_GOLD, MeshKit.FACE_PX if side > 0.0 else MeshKit.FACE_NX, 0.9)
	s.rect(Vector3(-hw, 0, zn), Vector3(hw * 2.0, 0, 0), Vector3(0, h, 0), marble, 0.0, MeshKit.PAT_MARBLE)
	s.box(Vector3(0, 0.09, zn + 0.02), Vector3(hw * 2.0, 0.18, 0.04), skin.gold_color, 0.0, MeshKit.PAT_GOLD,
		MeshKit.FACE_PZ | MeshKit.FACE_NY, 0.9)
	s.box(Vector3(0, h + 0.85, zn - 0.1), Vector3(hw * 2.0, 0.08, 0.08), skin.gold_color, 0.0, MeshKit.PAT_GOLD,
		MeshKit.ALL_FACES, 0.95)
	var px: float = -hw + 0.2
	while px < hw:
		s.box(Vector3(px, h + 0.42, zn - 0.1), Vector3(0.06, 0.85, 0.06), skin.gold_color, 0.0, MeshKit.PAT_GOLD,
			MeshKit.ALL_FACES & ~MeshKit.FACE_NY, 0.95)
		px += 1.2
	if hw * 2.0 >= 4.0:
		_relief(s, Vector3(0.0, h * 0.5, zn + 0.01), h - 0.2)
	for z: float in [zn - 0.8, zf + 0.8]:
		s.box(Vector3(0, h + 0.3, z), Vector3(hw * 2.0 + 1.0, 0.35, 0.35), skin.gold_color, 0.0, MeshKit.PAT_GOLD,
			MeshKit.ALL_FACES & ~MeshKit.FACE_NZ, 0.8)


# --- A gallery of archways ---------------------------------------------------------------------

## Parabolic gold arches springing from the walls, every ARCH_SPACING metres, over a flat marble deck:
## the first arch in marble with the emblem on its keystone.
func _archway(batch: MeshBatch, size: Vector3, edges: Array[float], wall_x: float) -> void:
	var s: MeshLayer = batch.layer(skin.solid_material())
	var g: MeshLayer = batch.layer(skin.glow_material())
	var zn: float = size.z * 0.5
	var zf: float = -size.z * 0.5
	var w: float = wall_x
	var rise: float = minf(ARCH_RISE, headroom() - ARCH_DECK - ARCH_THICK)
	_underside(s, g, w, zn, zf, edges, skin.stone_colors[2], MeshKit.PAT_MARBLE, 0.0)
	var z: float = zn - 1.5
	while z > zf + END_BAND + 0.5:
		s.box(Vector3(0, -0.004, z), Vector3(w * 2.0, 0.008, 0.16), skin.gold_color, 0.0, MeshKit.PAT_GOLD,
			MeshKit.FACE_NY, 0.9)
		z -= 3.0
	s.rect(Vector3(-w, 0, zn), Vector3(w * 2.0, 0, 0), Vector3(0, ARCH_DECK, 0), skin.stone_colors[2], 0.0, MeshKit.PAT_MARBLE)
	s.box(Vector3(0, 0.08, zn + 0.03), Vector3(w * 2.0, 0.16, 0.06), skin.gold_color, 0.0, MeshKit.PAT_GOLD,
		MeshKit.FACE_PZ | MeshKit.FACE_NY | MeshKit.FACE_PY, 0.9)
	var count: int = maxi(1, floori((zn - zf - END_BAND - 1.0) / ARCH_SPACING))
	for i: int in count + 1:
		var az: float = zn - 0.4 - float(i) * ARCH_SPACING
		if az < zf + END_BAND:
			break
		var first: bool = i == 0
		_arch(s, w, rise, az, skin.stone_colors[0] if first else skin.gold_color, first)
		for sx: float in [-1.0, 1.0]:
			var rx: float = sx * w * 0.5
			var top: float = _arch_y(rx, w, rise)
			s.box(Vector3(rx, (ARCH_DECK + top) * 0.5, az), Vector3(0.07, top - ARCH_DECK, 0.07), skin.gold_color, 0.0,
				MeshKit.PAT_GOLD, MeshKit.ALL_FACES & ~(MeshKit.FACE_NY | MeshKit.FACE_PY), 0.95)
		if first:
			var panel: float = minf(KEYSTONE, rise + 0.4)
			var top: float = minf(ARCH_DECK + rise + ARCH_THICK - 0.1, headroom() - 0.05)
			panel = minf(panel, top - 0.4)
			_relief(s, Vector3(0.0, top - 0.1 - panel * 0.5, az + 0.22), panel)


static func _arch_y(x: float, w: float, rise: float) -> float:
	var t: float = clampf(x / w, -1.0, 1.0)
	return ARCH_DECK + rise * (1.0 - t * t)


func _arch(s: MeshLayer, w: float, rise: float, az: float, color: Color, marble: bool) -> void:
	var thick: float = ARCH_THICK
	var zf: float = az - 0.2
	var zn: float = az + 0.2
	var pattern: int = MeshKit.PAT_MARBLE if marble else MeshKit.PAT_GOLD
	var param: float = 0.0 if marble else 0.9
	for i: int in ARCH_SEGMENTS:
		var x0: float = lerpf(-w, w, float(i) / ARCH_SEGMENTS)
		var x1: float = lerpf(-w, w, float(i + 1) / ARCH_SEGMENTS)
		var y0: float = _arch_y(x0, w, rise)
		var y1: float = _arch_y(x1, w, rise)
		s.quad(Vector3(x0, y0, zn), Vector3(x0, y0 + thick, zn), Vector3(x1, y1 + thick, zn), Vector3(x1, y1, zn), color, 0.0,
			pattern, param)
		s.quad(Vector3(x0, y0, zf), Vector3(x0, y0, zn), Vector3(x1, y1, zn), Vector3(x1, y1, zf), color, 0.0, pattern, param)
		s.quad(Vector3(x0, y0 + thick, zn), Vector3(x0, y0 + thick, zf), Vector3(x1, y1 + thick, zf), Vector3(x1, y1 + thick, zn),
			color, 0.0, pattern, param)
		if marble:
			s.quad(Vector3(x0, y0, zn + 0.01), Vector3(x0, y0 + 0.07, zn + 0.01), Vector3(x1, y1 + 0.07, zn + 0.01),
				Vector3(x1, y1, zn + 0.01), skin.gold_color, 0.0, MeshKit.PAT_GOLD, 0.95)


# --- A hanging chandelier ------------------------------------------------------------------------

## A denser, more ornate coffered underside with a gilded rosette and a ring of warm lamps every
## ROSETTE_SPACING metres: a hanging chandelier on a gilded frame (GDD §5), flush with the underside
## so nothing of it ever hangs below the running surface (the same rule every ceiling keeps).
func _chandelier(batch: MeshBatch, size: Vector3, edges: Array[float], hw: float, variant: int) -> void:
	var s: MeshLayer = batch.layer(skin.solid_material())
	var g: MeshLayer = batch.layer(skin.glow_material())
	var zn: float = size.z * 0.5
	var zf: float = -size.z * 0.5
	_underside(s, g, hw, zn, zf, edges, skin.coffer_color, MeshKit.PAT_COFFER, 0.9)
	var r: float = minf(ROSETTE_RADIUS, hw - 0.3)
	var ring: float = minf(LAMP_RING_RADIUS, hw - 0.2)
	if r <= 0.2:
		return
	var z: float = zf + END_BAND + ROSETTE_SPACING * 0.5
	while z < zn - END_BAND * 0.5:
		s.prism(Vector3(0, -0.01, z), r, 0.02, 10, skin.gold_color, 0.0, MeshKit.PAT_GOLD, false, 0.95)
		# u (+x) x v (+z) = -y: faces down, like the coffered underside around it.
		GoldenSkin.emblem_panel(s, Vector3(-r * 0.6, -0.015, z - r * 0.6), Vector3(r * 1.2, 0, 0), Vector3(0, 0, r * 1.2),
			r * 1.1, skin.stone_colors[0], 1)
		if ring > r + 0.3:
			for i: int in LAMP_RING_COUNT:
				var a: float = TAU * float(i) / LAMP_RING_COUNT
				var lx: float = cos(a) * ring
				var lz: float = z + sin(a) * ring
				s.box(Vector3(lx, -0.02, lz), Vector3(0.14, 0.03, 0.14), skin.lamp_color, 0.75, MeshKit.PAT_PLAIN,
					MeshKit.ALL_FACES & ~MeshKit.FACE_PY)
				g.rect(Vector3(lx - 0.5, -0.05, lz + 0.5), Vector3(1.0, 0, 0), Vector3(0, 0, -1.0), skin.lamp_color, 0.3,
					MeshKit.SHAPE_RADIAL)
		z += ROSETTE_SPACING
