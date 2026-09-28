class_name GoldenCeilings
extends RefCounted
## Ceiling sections in the Golden Zone (GoldenSkin, GDD §5: "undersides of golden bridges, golden
## archways and other decadent structures"), picked per ceiling by hashing its position (weights in
## the skin):
## - a golden bridge between the palaces: a gilded coffered underside, a marble face toward the
##   approach with the cult's emblem in relief at its middle and a gold rail on top; on some, water
##   pours off the face on either side of the emblem into a gilded trough (GDD §5: water flows off the
##   ceilings, scenery only, sparse); over fewer lanes it is a suspended gallery carried by gold beams;
## - a gallery of golden arches: parabolic gold ribs springing from the walls over a flat marble
##   deck hung from them, the emblem on the first arch's keystone;
## - a hover-yacht of the elite: a cream hull with a gold line and a deep red boot stripe, portholes, a
##   sleek cabin of tinted glass, a pointed prow, engines glowing pale blue at its stern.
## Every kind is built from the ceiling it's given: its width and position come from the collision box
## and the lane seams (center, size, lane_edges_x), so a ceiling over fewer lanes (narrow ceilings,
## task B3) just builds narrower; only bridges and archways across every lane reach from wall to wall.
## Every underside is one flat surface across its lanes (no gaps between lanes, GDD §3) with a darker
## seam and flush warm lamps along each lane seam, nothing hanging below it but those, and the far end
## carries the orange edge band of every zone (MeshKit.ceiling_end), so the drop back to the floor
## reads like a gap edge. The water stays above the underside, never over the floor or the walls'
## wall-run band, so it never hides a hazard.
## Above the underside every structure keeps under what the walls hold out over the street (the statue
## ledges, the statues, the gilded frames, the banners: headroom(), from GoldenFacades'
## clearance_profile()), so on a narrow street the arches are flatter, the bridges' rails stop short of
## the statues and a yacht near a wall has a lower cabin and no mast.
## Ceiling space: origin at the centre of the underside (the ceiling surface), z = -distance.

enum Kind { BRIDGE, ARCHWAY, YACHT }

const END_BAND: float = 1.2
const LAMP_SPACING: float = 7.5
## How far every structure keeps below what the walls hold out (headroom()).
const CLEARANCE: float = 0.1
## A bridge's face: its greatest height above the underside (bridge_fascia() fits it under the statue
## ledges), the cornice on top of it, and (over fewer lanes) the suspended gallery's.
const FASCIA: float = 2.4
const CORNICE: float = 0.2
const GALLERY_FASCIA: float = 1.2
## The crest at the middle of a bridge's face (the emblem in relief, rising over the rail so it reads
## from far down the street), how high its foot is, and the archways' keystone relief.
const CREST: float = 3.0
const CREST_FOOT: float = 0.3
const KEYSTONE: float = 2.2
## An archway's arches: spacing along the track, their greatest rise over the deck at the middle
## (arch_rise() fits it to the street), the deck, a rib's depth.
const ARCH_SPACING: float = 6.0
const ARCH_RISE: float = 4.6
const ARCH_DECK: float = 0.5
const ARCH_THICK: float = 0.5
const ARCH_SEGMENTS: int = 12
## Water off a bridge's face: the trough's height and reach, where the curtains start below the top.
const TROUGH_H: float = 0.42
const TROUGH_OUT: float = 0.55
const CURTAIN_OUT: float = 0.3

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: GoldenSkin:
	get:
		return _skin.get_ref() as GoldenSkin
var _skin: WeakRef
var _meshes: Dictionary = {}


func _init(p_skin: GoldenSkin) -> void:
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


## Which kind of structure forms this ceiling (bridges and archways need every lane; over fewer lanes a
## bridge becomes a suspended gallery, and an archway's share goes to it).
func kind_of(center: Vector3, size: Vector3, wall_x: float) -> int:
	var full: bool = absf(center.x) < 0.01 and size.x * 0.5 > wall_x - 0.6
	var weights: Array[float] = [skin.bridge_weight + (0.0 if full else skin.archway_weight),
		skin.archway_weight if full else 0.0, skin.yacht_weight]
	var total: float = 0.0
	for w: float in weights:
		total += w
	if total <= 0.0:
		return Kind.BRIDGE
	var r: float = MeshKit.hash01(MeshKit.key(center.z), MeshKit.key(size.z), 90) * total
	for k: int in weights.size():
		r -= weights[k]
		if r < 0.0:
			return k
	return Kind.BRIDGE


## Whether the bridge with this variant (0-3) and length has water pouring off its face (water_share).
func has_water(variant: int, length: float) -> bool:
	return MeshKit.hash01(variant, MeshKit.key(length), 95) < skin.water_share


## How high a ceiling's structure may rise above its underside (at world height base_y) `from_wall`
## metres out from the nearest wall face: CLEARANCE under everything the walls hold out there
## (GoldenFacades.clearance_profile(); OVER_STREET beyond it).
func headroom(from_wall: float, base_y: float) -> float:
	var top: float = GoldenFacades.OVER_STREET
	for tier: Vector2 in skin.facades().clearance_profile():
		if from_wall <= tier.x:
			top = minf(top, tier.y)
	return top - CLEARANCE - base_y


## The arches' rise over the deck at the middle of a street whose walls stand at ±w, the underside at
## world height base_y: ARCH_RISE, or as much as fits under headroom() everywhere (a rib is highest
## where it is furthest from the walls, so each tier of the walls' profile bounds it at its edge).
func arch_rise(w: float, base_y: float) -> float:
	var rise: float = minf(ARCH_RISE, headroom(w, base_y) - ARCH_DECK - ARCH_THICK)
	for tier: Vector2 in skin.facades().clearance_profile():
		var t: float = maxf(w - tier.x, 0.0) / maxf(w, 0.01)
		rise = minf(rise, (headroom(tier.x, base_y) - ARCH_DECK - ARCH_THICK) / maxf(1.0 - t * t, 0.05))
	return maxf(rise, 0.4)


## A golden bridge's face height (under its cornice) with the underside at world height base_y: FASCIA,
## or lower so the cornice stays under the statue ledges where the bridge meets the walls.
func bridge_fascia(base_y: float) -> float:
	return clampf(headroom(0.0, base_y) - CORNICE, 1.0, FASCIA)


## How far from a wall there is headroom (above an underside at world height base_y) for something
## `height` tall; w if nowhere across a street whose walls stand at ±w.
func clear_from(height: float, w: float, base_y: float) -> float:
	var reach: float = 0.0
	while reach < w and headroom(reach, base_y) < height:
		reach += 0.05
	return reach


## The mesh of a ceiling of `kind` (colour variant 0-3) with collision size `size` centred on
## offset_x, seams at lane_edges_x (world x), its underside at world height base_y, walls at ±wall_x.
## In ceiling space (see above); build() places it.
func mesh_for(kind: int, variant: int, size: Vector3, lane_edges_x: Array[float], offset_x: float, wall_x: float,
		base_y: float = 6.0) -> ArrayMesh:
	var batch := MeshBatch.new()
	var full: bool = absf(offset_x) < 0.01 and size.x * 0.5 > wall_x - 0.6
	var hw: float = size.x * 0.5 + 0.15
	var edges: Array[float] = []
	for x: float in lane_edges_x:
		edges.append(x - offset_x)
	match kind:
		Kind.ARCHWAY:
			if full:
				_archway(batch, size, edges, wall_x, base_y)
			else:
				_gallery(batch, size, edges, hw, wall_x, offset_x, variant, base_y)
		Kind.YACHT:
			_yacht(batch, size, edges, hw, variant, wall_x, offset_x, base_y)
		_:
			if full:
				_bridge(batch, size, edges, wall_x, variant, base_y)
			else:
				_gallery(batch, size, edges, hw, wall_x, offset_x, variant, base_y)
	return batch.to_mesh()


## The underside across [-hw, hw] from the far end's band to the near end: one surface in `pattern`,
## a darker seam and flush warm lamps along each lane seam, and the orange band at the far end.
func _underside(s: MeshLayer, g: MeshLayer, hw: float, zn: float, zf: float, edges: Array[float], color: Color,
		pattern: int, param: float) -> void:
	var z0: float = zf + END_BAND
	s.rect(Vector3(-hw, 0, z0), Vector3(hw * 2.0, 0, 0), Vector3(0, 0, zn - z0), color, 0.0, pattern, Vector2.ZERO,
		Vector2.ONE, param)
	var seam := Color(skin.joint_color, 1.0)
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
## square facing +z, its middle at `c` on the face it stands on: the rim, then the panel standing off
## it (GoldenFacades.RIM_DEPTH, RELIEF_STANDOFF: no flicker from afar).
func _relief(s: MeshLayer, c: Vector3, panel: float) -> void:
	s.box(c + Vector3(0.0, 0.0, GoldenFacades.RIM_DEPTH * 0.5), Vector3(panel + 0.24, panel + 0.24, GoldenFacades.RIM_DEPTH),
		skin.gold_color, 0.0, MeshKit.PAT_GOLD, MeshKit.ALL_FACES & ~MeshKit.FACE_NZ, 0.95)
	GoldenSkin.emblem_panel(s, c + Vector3(-panel * 0.5, -panel * 0.5, GoldenFacades.RIM_DEPTH + GoldenFacades.RELIEF_STANDOFF),
		Vector3(panel, 0, 0), Vector3(0, panel, 0), relief_emblem(panel), skin.stone_colors[0], 1)


## The emblem's size on a relief panel `panel` metres square.
static func relief_emblem(panel: float) -> float:
	return panel * 0.78


# --- A golden bridge ------------------------------------------------------------------------

## A bridge between the palaces across every lane: the coffered underside from wall to wall, its
## marble face toward the approach with a gold band along its bottom edge (so the ceiling's edge reads
## from the floor), a gold cornice on top (under the statue ledges where it meets the walls), a rail of
## marble posts under a gold rail between two newels (short of the statues), and the crest at its
## middle rising over the rail: the emblem in relief; on some, water pouring off the face into a
## gilded trough on either side of the crest.
func _bridge(batch: MeshBatch, size: Vector3, edges: Array[float], wall_x: float, variant: int, base_y: float) -> void:
	var s: MeshLayer = batch.layer(skin.solid_material())
	var g: MeshLayer = batch.layer(skin.glow_material())
	var zn: float = size.z * 0.5
	var zf: float = -size.z * 0.5
	var w: float = wall_x
	var fascia: float = bridge_fascia(base_y)
	_underside(s, g, w, zn, zf, edges, skin.coffer_color, MeshKit.PAT_COFFER, 1.5)
	var marble: Color = skin.stone_colors[(variant + 1) % skin.stone_colors.size()]
	s.rect(Vector3(-w, 0, zn), Vector3(w * 2.0, 0, 0), Vector3(0, fascia, 0), marble, 0.0, MeshKit.PAT_MARBLE)
	s.box(Vector3(0, 0.1, zn + 0.05), Vector3(w * 2.0, 0.2, 0.1), skin.gold_color, 0.0, MeshKit.PAT_GOLD,
		MeshKit.FACE_PZ | MeshKit.FACE_NY | MeshKit.FACE_PY, 0.9)
	s.box(Vector3(0, fascia + CORNICE * 0.5, zn + 0.06), Vector3(w * 2.0, CORNICE, 0.2), skin.gold_color, 0.0,
		MeshKit.PAT_GOLD, MeshKit.FACE_PZ | MeshKit.FACE_NY | MeshKit.FACE_PY, 0.9)
	var rail_top: float = fascia + CORNICE + 0.96
	var rail_x: float = w - clear_from(rail_top, w, base_y) - 0.15
	if rail_x > 0.8:
		var posts: int = maxi(roundi(rail_x * 2.0 / 1.3), 1)
		for i: int in range(1, posts):
			s.box(Vector3(-rail_x + rail_x * 2.0 * float(i) / float(posts), fascia + CORNICE + 0.4, zn - 0.15),
				Vector3(0.14, 0.8, 0.14), marble, 0.0, MeshKit.PAT_MARBLE, MeshKit.ALL_FACES & ~(MeshKit.FACE_NY | MeshKit.FACE_NZ))
		for side: float in [-1.0, 1.0]:
			s.box(Vector3(side * rail_x, fascia + CORNICE + 0.45, zn - 0.15), Vector3(0.26, 0.9, 0.26), marble, 0.0,
				MeshKit.PAT_MARBLE, MeshKit.ALL_FACES & ~(MeshKit.FACE_NY | MeshKit.FACE_NZ))
		s.box(Vector3(0, rail_top - 0.05, zn - 0.15), Vector3(rail_x * 2.0, 0.1, 0.18), skin.gold_color, 0.0, MeshKit.PAT_GOLD,
			MeshKit.ALL_FACES & ~MeshKit.FACE_NZ, 0.95)
	# The crest, as big as fits under the headroom at its corners.
	var crest: float = CREST
	while crest > 1.0 and CREST_FOOT + crest + 0.12 > headroom(w - crest * 0.5 - 0.12, base_y):
		crest -= 0.1
	_relief(s, Vector3(0.0, CREST_FOOT + crest * 0.5, zn + 0.01), crest)
	if has_water(variant, size.z):
		var inner: float = crest * 0.5 + 0.7
		var cw: float = minf(3.2, w - inner - 1.2)
		if cw > 0.8:
			for side: float in [-1.0, 1.0]:
				var x0: float = side * inner if side > 0.0 else -(inner + cw)
				_curtain(s, x0, cw, zn, fascia)


## Water pouring off a bridge's face (`fascia` tall) from a gold lip near its top into a gilded trough
## along its foot: a sheet `width` wide from x0, in front of the face at zn. The trough's bottom is the
## underside's plane, so nothing hangs below the ceiling.
func _curtain(s: MeshLayer, x0: float, width: float, zn: float, fascia: float) -> void:
	var lip: float = fascia - 0.16
	var z: float = zn + CURTAIN_OUT
	s.box(Vector3(x0 + width * 0.5, lip + 0.05, zn + CURTAIN_OUT * 0.5 + 0.02), Vector3(width + 0.2, 0.1, CURTAIN_OUT + 0.08),
		skin.gold_color, 0.0, MeshKit.PAT_GOLD, MeshKit.ALL_FACES & ~MeshKit.FACE_NZ, 0.95)
	s.rect(Vector3(x0, TROUGH_H - 0.05, z), Vector3(width, 0, 0), Vector3(0, lip - TROUGH_H + 0.05, 0), skin.water_color, 0.0,
		MeshKit.PAT_WATER, Vector2(0.0, 1.0), Vector2(width, 0.0), 0.0)
	s.box(Vector3(x0 + width * 0.5, TROUGH_H * 0.5, zn + TROUGH_OUT * 0.5 + 0.01), Vector3(width + 0.4, TROUGH_H, TROUGH_OUT),
		skin.gold_color, 0.0, MeshKit.PAT_GOLD, MeshKit.ALL_FACES & ~MeshKit.FACE_NZ, 0.9)
	# The water's surface in the trough.
	s.rect(Vector3(x0 - 0.15, TROUGH_H + 0.005, zn + TROUGH_OUT - 0.04), Vector3(width + 0.3, 0, 0),
		Vector3(0, 0, -(TROUGH_OUT - 0.08)), skin.water_color, 0.0, MeshKit.PAT_WATER, Vector2(0.0, 0.9), Vector2(width, 1.0), 0.0)


## A suspended gallery over some of the lanes (a bridge or an archway over fewer lanes): a deck with
## the coffered underside, marble faces with gold bands, a gold rail on top, the emblem at the middle
## of its face if it's wide enough, and gold beams carrying it into the buildings at both ends, above
## the deck; all of it low enough to pass under the statue ledges.
func _gallery(batch: MeshBatch, size: Vector3, edges: Array[float], hw: float, wall_x: float, offset_x: float,
		variant: int, base_y: float) -> void:
	var s: MeshLayer = batch.layer(skin.solid_material())
	var g: MeshLayer = batch.layer(skin.glow_material())
	var zn: float = size.z * 0.5
	var zf: float = -size.z * 0.5
	var h: float = minf(GALLERY_FASCIA, headroom(0.0, base_y) - 0.96)
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
	s.box(Vector3(0, h + 0.9, zn - 0.1), Vector3(hw * 2.0, 0.08, 0.08), skin.gold_color, 0.0, MeshKit.PAT_GOLD,
		MeshKit.ALL_FACES, 0.95)
	var px: float = -hw + 0.2
	while px < hw:
		s.box(Vector3(px, h + 0.45, zn - 0.1), Vector3(0.06, 0.9, 0.06), skin.gold_color, 0.0, MeshKit.PAT_GOLD,
			MeshKit.ALL_FACES & ~MeshKit.FACE_NY, 0.95)
		px += 1.2
	if hw * 2.0 >= 4.0:
		_relief(s, Vector3(0.0, h * 0.5, zn + 0.01), h - 0.2)
	# Beams into the buildings at both ends, above the deck.
	for z: float in [zn - 0.8, zf + 0.8]:
		var x0: float = -wall_x - 0.5 - offset_x
		var x1: float = wall_x + 0.5 - offset_x
		s.box(Vector3((x0 + x1) * 0.5, h + 0.3, z), Vector3(x1 - x0, 0.4, 0.4), skin.gold_color, 0.0, MeshKit.PAT_GOLD,
			MeshKit.ALL_FACES & ~MeshKit.FACE_NZ, 0.8)


# --- A gallery of golden arches ---------------------------------------------------------------

## Parabolic gold arches springing from the walls, every ARCH_SPACING metres, over a flat marble deck
## hung from them on gold rods: the deck's underside (the running surface) cream with the lane seams
## and lamps, a gold band along its near edge; the first arch in marble with the emblem on its keystone.
## The arches rise as high as the street's width lets them (arch_rise()).
func _archway(batch: MeshBatch, size: Vector3, edges: Array[float], wall_x: float, base_y: float) -> void:
	var s: MeshLayer = batch.layer(skin.solid_material())
	var g: MeshLayer = batch.layer(skin.glow_material())
	var zn: float = size.z * 0.5
	var zf: float = -size.z * 0.5
	var w: float = wall_x
	var rise: float = arch_rise(w, base_y)
	_underside(s, g, w, zn, zf, edges, skin.stone_colors[2], MeshKit.PAT_MARBLE, 0.0)
	# Gold ribs across the underside every 3 m (flush: they stream past a rider).
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
		# Rods from the arch down to the deck, at a third of the way out on each side.
		for sx: float in [-1.0, 1.0]:
			var rx: float = sx * w * 0.5
			var top: float = _arch_y(rx, w, rise)
			s.box(Vector3(rx, (ARCH_DECK + top) * 0.5, az), Vector3(0.07, top - ARCH_DECK, 0.07), skin.gold_color, 0.0,
				MeshKit.PAT_GOLD, MeshKit.ALL_FACES & ~(MeshKit.FACE_NY | MeshKit.FACE_PY), 0.95)
		if first:
			# The keystone's relief: its top just under the crown's and under the headroom at its corners,
			# its foot over the underside (smaller over a low arch).
			var panel: float = minf(KEYSTONE, rise + 0.4)
			var top: float = minf(ARCH_DECK + rise + ARCH_THICK - 0.13, headroom(w - panel * 0.5 - 0.12, base_y))
			panel = minf(panel, top - 0.44)
			_relief(s, Vector3(0.0, top - 0.12 - panel * 0.5, az + 0.24), panel)


## The height of an arch's inner edge (over the underside) at x, for walls at ±w: a parabola from the
## deck's top at the walls to `rise` over it at the middle.
static func _arch_y(x: float, w: float, rise: float) -> float:
	var t: float = clampf(x / w, -1.0, 1.0)
	return ARCH_DECK + rise * (1.0 - t * t)


## One arch rib across the street at az (its near face at az + 0.22), rising `rise` over the deck:
## segments along the parabola, a face toward the approach, its underside and its top, in `color`
## (polished gold, or marble with gold edges for the first).
func _arch(s: MeshLayer, w: float, rise: float, az: float, color: Color, marble: bool) -> void:
	var thick: float = ARCH_THICK
	var zf: float = az - 0.22
	var zn: float = az + 0.22
	var pattern: int = MeshKit.PAT_MARBLE if marble else MeshKit.PAT_GOLD
	var param: float = 0.0 if marble else 0.9
	for i: int in ARCH_SEGMENTS:
		var x0: float = lerpf(-w, w, float(i) / ARCH_SEGMENTS)
		var x1: float = lerpf(-w, w, float(i + 1) / ARCH_SEGMENTS)
		var y0: float = _arch_y(x0, w, rise)
		var y1: float = _arch_y(x1, w, rise)
		# Front (+z), then underside and top.
		s.quad(Vector3(x0, y0, zn), Vector3(x0, y0 + thick, zn), Vector3(x1, y1 + thick, zn), Vector3(x1, y1, zn), color, 0.0,
			pattern, param)
		s.quad(Vector3(x0, y0, zf), Vector3(x0, y0, zn), Vector3(x1, y1, zn), Vector3(x1, y1, zf), color, 0.0, pattern, param)
		s.quad(Vector3(x0, y0 + thick, zn), Vector3(x0, y0 + thick, zf), Vector3(x1, y1 + thick, zf), Vector3(x1, y1 + thick, zn),
			color, 0.0, pattern, param)
		if marble:
			# Gold edges along the marble arch's face.
			s.quad(Vector3(x0, y0, zn + 0.01), Vector3(x0, y0 + 0.07, zn + 0.01), Vector3(x1, y1 + 0.07, zn + 0.01),
				Vector3(x1, y1, zn + 0.01), skin.gold_color, 0.0, MeshKit.PAT_GOLD, 0.95)
			s.quad(Vector3(x0, y0 + thick - 0.07, zn + 0.01), Vector3(x0, y0 + thick, zn + 0.01),
				Vector3(x1, y1 + thick, zn + 0.01), Vector3(x1, y1 + thick - 0.07, zn + 0.01), skin.gold_color, 0.0,
				MeshKit.PAT_GOLD, 0.95)


# --- A hover-yacht ---------------------------------------------------------------------------

## A hover-yacht of the elite heading toward the player: a cream hull whose flat underside is the
## ceiling, sloped sides with a gold line and a deep red boot stripe (unlit) and portholes, a pointed
## prow rising over the near end, a sleek cabin of tinted glass with a gold trim, a mast light, and its
## engines at the stern over the orange band, glowing a pale blue-white. Its hull, cabin and mast keep
## under the headroom where they are (walls at ±wall_x, the yacht's middle at offset_x, the underside at
## world height base_y): next to a wall a narrow yacht has a lower cabin and no mast.
func _yacht(batch: MeshBatch, size: Vector3, edges: Array[float], hw: float, _variant: int, wall_x: float,
		offset_x: float, base_y: float) -> void:
	var s: MeshLayer = batch.layer(skin.solid_material())
	var g: MeshLayer = batch.layer(skin.glow_material())
	var zn: float = size.z * 0.5
	var zf: float = -size.z * 0.5
	var hull: Color = skin.yacht_hull_color
	var middle: float = wall_x - absf(offset_x)
	var rise: float = minf(1.8, headroom(maxf(middle - hw, 0.0), base_y) - 0.1)
	var slope: float = minf(0.7, hw * 0.3)
	_underside(s, g, hw, zn, zf, edges, hull, MeshKit.PAT_HULL, 0.0)
	var lamp: Color = skin.lamp_color
	for side: float in [-1.0, 1.0]:
		var x: float = side * hw
		var top := Vector3(-side * slope, rise, 0)
		var z0: float = zn if side > 0.0 else zf
		var u := Vector3(0, 0, zf - zn if side > 0.0 else zn - zf)
		s.rect(Vector3(x, 0, z0), u, top, hull, 0.0, MeshKit.PAT_HULL)
		var out := Vector3(side * 0.01, 0, 0)
		s.rect(Vector3(x, 0, z0) + top * 0.1 + out, u, top * 0.12, skin.red_color)
		s.rect(Vector3(x, 0, z0) + top * 0.3 + out, u, top * 0.05, skin.gold_color, 0.0, MeshKit.PAT_GOLD, Vector2.ZERO,
			Vector2.ONE, 0.95)
		var pz: float = zf + 2.5
		while pz < zn - 1.5:
			s.box(Vector3(x - side * slope * 0.62, rise * 0.62, pz), Vector3(0.22, 0.22, 0.22), lamp, 0.35)
			pz += 2.4
	# The prow: a pointed bow rising over the near end, the gold line and red stripe along its edges.
	var bow_z: float = zn + 4.5
	var tip: float = maxf(hw * 0.2, 0.3)
	var bl := Vector3(-hw, 0, zn)
	var br := Vector3(hw, 0, zn)
	var tl := Vector3(-tip, rise, bow_z)
	var tr := Vector3(tip, rise, bow_z)
	s.quad(bl, tl, tr, br, hull, 0.0, MeshKit.PAT_HULL)
	s.quad(br, tr, br + Vector3(-slope, rise, 0), br + Vector3(-slope, rise, 0), hull)
	s.quad(bl, bl + Vector3(slope, rise, 0), tl, tl, hull)
	var lift: Vector3 = (br - bl).cross(tl - bl).normalized() * 0.02
	for side: float in [-1.0, 1.0]:
		var foot := Vector3(side * hw, 0, zn) + lift
		var head := Vector3(side * tip, rise, bow_z) + lift
		var across := Vector3(-side * 0.22, 0.0, 0.0)
		var color: Color = skin.red_color
		if side > 0.0:
			s.quad(foot + across, head + across * 0.5, head, foot, color)
		else:
			s.quad(foot, head, head + across * 0.5, foot + across, color)
	s.box(Vector3(0, rise + 0.04, bow_z - 0.3), Vector3(tip * 2.0 + 0.1, 0.08, 0.6), skin.gold_color, 0.0, MeshKit.PAT_GOLD,
		MeshKit.NO_BOTTOM, 0.95)
	# The deck and the cabin: tinted glass under a cream roof, a gold trim line.
	var deck_hw: float = hw - slope
	s.rect(Vector3(-deck_hw, rise, zn), Vector3(deck_hw * 2.0, 0, 0), Vector3(0, 0, zf - zn), hull.darkened(0.08), 0.0,
		MeshKit.PAT_HULL)
	var cab_w: float = minf(deck_hw * 1.2, 5.6)
	var cab_len: float = minf(size.z * 0.5, 14.0)
	var cab_z: float = zn - 3.0 - cab_len * 0.5
	var cab_h: float = minf(1.6, headroom(maxf(middle - cab_w * 0.5 - 0.05, 0.0), base_y) - rise - 0.07)
	if cab_h >= 0.5:
		s.box(Vector3(0, rise + cab_h * 0.5, cab_z), Vector3(cab_w, cab_h, cab_len), hull, 0.0, MeshKit.PAT_HULL,
			MeshKit.NO_BOTTOM)
		for sx: float in [-1.0, 1.0]:
			s.box(Vector3(sx * (cab_w * 0.5 + 0.005), rise + cab_h * 0.55, cab_z), Vector3(0.01, cab_h * 0.5, cab_len - 1.0),
				skin.glass_color, 0.0, MeshKit.PAT_GLASS, MeshKit.FACE_PX if sx > 0.0 else MeshKit.FACE_NX)
		s.box(Vector3(0, rise + cab_h * 0.55, cab_z + cab_len * 0.5 + 0.005), Vector3(cab_w - 0.4, cab_h * 0.5, 0.01),
			skin.glass_color, 0.0, MeshKit.PAT_GLASS, MeshKit.FACE_PZ)
		s.box(Vector3(0, rise + cab_h + 0.03, cab_z), Vector3(cab_w + 0.1, 0.06, cab_len + 0.1), skin.gold_color, 0.0,
			MeshKit.PAT_GOLD, MeshKit.NO_BOTTOM, 0.95)
		# A mast light, a small warm-white beacon, where there is room over the cabin.
		var mast: float = minf(2.2, headroom(middle, base_y) - rise - cab_h - 0.3)
		if mast >= 0.6:
			s.box(Vector3(0, rise + cab_h + 0.1 + mast * 0.5, cab_z - cab_len * 0.3), Vector3(0.08, mast, 0.08), skin.gold_color,
				0.0, MeshKit.PAT_GOLD, MeshKit.ALL_FACES, 0.9)
			s.box(Vector3(0, rise + cab_h + mast + 0.15, cab_z - cab_len * 0.3), Vector3(0.18, 0.18, 0.18), lamp, 0.8)
	# The stern's engines over the orange band.
	var engines: int = clampi(roundi(hw * 2.0 / 4.0), 1, 4)
	for i: int in engines:
		var ex: float = -hw + (float(i) + 0.5) * hw * 2.0 / engines
		var r: float = minf(0.8, hw / engines * 0.75)
		var nozzle := Transform3D(Basis(Vector3(r, 0, 0), Vector3(0, 0, -1.0), Vector3(0, r, 0)), Vector3(ex, 0.95, zf))
		s.prism_xform(nozzle, 8, skin.gold_color.darkened(0.3), 0.0, MeshKit.PAT_GOLD, false, 0.8)
		var core := Transform3D(Basis(Vector3(r * 0.7, 0, 0), Vector3(0, 0, -0.05), Vector3(0, r * 0.7, 0)),
			Vector3(ex, 0.95, zf - 0.9))
		s.prism_xform(core, 8, skin.engine_color, 0.9)
		# Its halo stops at the underside: past the far end nothing glows below it, where the chase
		# camera passes as the player drops (MeshKit.stern_halo, task B3).
		MeshKit.stern_halo(g, Vector3(ex, 0.95, zf - 1.1), r * 2.2, skin.engine_color, 0.35)
