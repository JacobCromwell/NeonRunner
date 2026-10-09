class_name GoldenConvergenceShipModel
extends RefCounted
## The Refill Ship's meshes (GDD §10: "The ship is a ceiling, like most ships in the game"; proposed: "a gilded
## cult cargo ship, its flat plated belly across every lane at ceiling height, racks of missiles along its
## flanks"; task E5d-c), built once in code per width and shared, low-poly and flat-shaded through the mesh kit
## (the court's solid material: gold that reflects, never glows). Its local space: the origin at the middle of
## its belly's underside (the ceiling's surface, y = 0), +y up, -z its bow (it flies the runner's way), x across.
## - hull: the belly, a flat plated underside from wall to wall with a darker seam and flush warm lamps along
##   each lane seam and the orange end band of every zone's ceilings at its far end (its bow, MeshKit.ceiling_end:
##   where a rider would drop, read like a gap's edge), nothing hanging below it; its skirts; a long gilded cargo
##   hull over it with gold bands and the cult's emblem in relief on its flanks and stern; the racks' decks out
##   past the belly's edges along both flanks, their rails and cradles; a pointed prow; the bridge at the stern
##   with its dark windows; the feed boom amidships (a gold mast and arm whose nozzle the feed line leaves from:
##   BOOM_TIP, high on the ship so the line runs up across the sky to the shoulder); the engines at the stern,
##   glowing a pale blue (the Golden Zone's yachts'), their halos above the
##   underside and fading near the camera (MeshKit.stern_halo), as every ship's;
## - rack_missile: one of the missiles lying in its racks (bronze with a gold nose, never glowing: the barrage's
##   look, smaller), RACK_ROWS rows along each flank (rack_slots);
## - line_segment: a piece of the feed line (a gilded hose with bronze bands: it reads against the cape's dark cloud
##   and the sky alike), a unit along +y;
## - line_missile: a missile riding up the line, smaller still.
## Nothing on it glows but its lamps (warm white), its engines (pale blue) and the end band (the ceilings'
## orange): never a hazard colour on a safe thing (CLAUDE.md readability rules).
## DESIGN-TBD (docs/OPEN_QUESTIONS.md, item 469): its look and size (LENGTH, the racks, the boom).

## Its belly's length, and where a runner riding it (or running under it) is: RIDER metres behind its middle.
const LENGTH: float = 34.0
const RIDER: float = 4.0
## Its belly reaches this far past the walls' line on each side (the collision box covers every lane, wall to
## wall: GoldenConvergenceShip).
const OVERHANG: float = 0.35
## The belly's skirts, from the underside up to the racks' decks.
const SKIRT: float = 0.9
## The racks: their decks out past the belly's edges this far, this thick; missiles in RACK_ROWS rows on each,
## one every RACK_SPACING along it, from RACK_FROM behind the bow's end to RACK_TO before the stern's.
const RACK_OUT: float = 3.0
const RACK_DECK: float = 0.22
const RACK_ROWS: int = 2
const RACK_SPACING: float = 2.9
const RACK_FROM: float = 4.5
const RACK_TO: float = 3.0
## The cargo hull over the belly: its top, its ends inset from the belly's.
const HULL_TOP: float = 3.9
const HULL_BOW_INSET: float = 2.0
const HULL_STERN_INSET: float = 1.0
## The end band's depth (the ceilings' own: GoldenCeilings.END_BAND) and the lamps' spacing.
const END_BAND: float = 1.2
const LAMP_SPACING: float = 7.5
## The prow's tip ahead of the belly's bow end, and its height.
const PROW: float = 4.0
## The feed boom's nozzle (where the line leaves the ship), local.
const BOOM_TIP := Vector3(0.0, 7.3, -3.4)
## A rack missile's size, a riding missile's size, and the line's radius.
const MISSILE_LENGTH: float = 2.3
const MISSILE_RADIUS: float = 0.27
const RIDE_LENGTH: float = 1.6
const RIDE_RADIUS: float = 0.2
const LINE_RADIUS: float = 0.5
## Colours (sRGB, never emissive on the solid surfaces): the plated belly's pale gold, the hull's cream and
## gold, a deep bronze for joints, the missiles' bronze, the windows' dark glass.
const BELLY := Color(0.8, 0.69, 0.48)
const SEAM := Color(0.24, 0.18, 0.1)
const CREAM := Color(0.88, 0.84, 0.75)
const GOLD := Color(0.85, 0.67, 0.42)
const BRONZE := Color(0.42, 0.3, 0.17)
const MISSILE := Color(0.42, 0.3, 0.18)
const NOSE := Color(0.72, 0.56, 0.32)
const LINE := Color(0.88, 0.72, 0.46)
const GLASS := Color(0.1, 0.11, 0.13)

static var _cache: Dictionary = {}


## The meshes for a ship whose belly is `half_width` to each side of its middle (the walls' line plus
## OVERHANG), seams under `lane_edges` (local x), in `skin`'s materials (a GoldenSkin: the court's gold): {hull,
## rack_missile, line_segment, line_missile}. Cached per width.
static func meshes(half_width: float, lane_edges: Array[float], skin: GoldenSkin) -> Dictionary:
	var key: String = "%.3f_%s_%d" % [half_width, lane_edges, skin.get_instance_id()]
	if _cache.has(key):
		return _cache[key]
	var out := {"hull": _hull(half_width, lane_edges, skin), "rack_missile": _missile(skin, MISSILE_LENGTH, MISSILE_RADIUS),
		"line_segment": _segment(skin), "line_missile": _missile(skin, RIDE_LENGTH, RIDE_RADIUS)}
	_cache[key] = out
	return out


## Where its rack missiles lie (local; each along -z, nose to the bow): row by row along each flank.
static func rack_slots(half_width: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var zf: float = -LENGTH * 0.5
	var zn: float = LENGTH * 0.5
	for side: int in [-1, 1]:
		for row: int in RACK_ROWS:
			var x: float = side * (half_width + RACK_OUT * (float(row) + 0.5) / float(RACK_ROWS))
			var z: float = zf + RACK_FROM
			while z <= zn - RACK_TO + 0.01:
				out.append(Vector3(x, SKIRT + RACK_DECK + MISSILE_RADIUS + 0.05, z))
				z += RACK_SPACING
	return out


## The underside of a rack's deck (local y): where a hurled drone hits it.
static func rack_bottom() -> float:
	return SKIRT


## The middle of the racks along `side` (local x).
static func rack_x(half_width: float, side: int) -> float:
	return side * (half_width + RACK_OUT * 0.5)


static func _hull(hw: float, edges: Array[float], skin: GoldenSkin) -> ArrayMesh:
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(skin.solid_material())
	var g: MeshLayer = batch.layer(skin.glow_material())
	var zf: float = -LENGTH * 0.5
	var zn: float = LENGTH * 0.5
	# The belly: one flat plated surface across every lane, the seams and lamps flush under it, the end band.
	var z0: float = zf + END_BAND
	s.rect(Vector3(-hw, 0, z0), Vector3(hw * 2.0, 0, 0), Vector3(0, 0, zn - z0), BELLY, 0.0, MeshKit.PAT_HULL)
	var lamp: Color = skin.ceiling_lamp_color
	for x: float in edges:
		s.box(Vector3(x, -0.006, (zn + z0) * 0.5), Vector3(0.07, 0.012, zn - z0), SEAM, 0.0, MeshKit.PAT_PLAIN,
			MeshKit.ALL_FACES & ~MeshKit.FACE_PY)
		var z: float = z0 + 3.2
		while z < zn - 2.0:
			s.box(Vector3(x, -0.02, z), Vector3(0.26, 0.04, 0.26), lamp, 0.75, MeshKit.PAT_PLAIN, MeshKit.ALL_FACES & ~MeshKit.FACE_PY)
			g.rect(Vector3(x - 0.8, -0.06, z + 0.8), Vector3(1.6, 0, 0), Vector3(0, 0, -1.6), lamp, 0.28, MeshKit.SHAPE_RADIAL)
			z += LAMP_SPACING
	MeshKit.ceiling_end(s, g, hw, zf, END_BAND, skin.gap_edge_color)
	# The skirts along its sides and ends, up to the racks' decks (gold, a bronze band at their foot).
	for side: float in [-1.0, 1.0]:
		s.box(Vector3(side * (hw - 0.06), SKIRT * 0.5, 0.0), Vector3(0.12, SKIRT, LENGTH), GOLD, 0.0, MeshKit.PAT_GOLD,
			MeshKit.ALL_FACES & ~MeshKit.FACE_NY, 0.7)
		s.box(Vector3(side * (hw + 0.01), 0.12, 0.0), Vector3(0.04, 0.16, LENGTH - 0.2), BRONZE, 0.0, MeshKit.PAT_PLAIN,
			MeshKit.FACE_PX if side > 0.0 else MeshKit.FACE_NX)
	for z: float in [zn - 0.06, zf + 0.06]:
		s.box(Vector3(0.0, SKIRT * 0.5, z), Vector3(hw * 2.0, SKIRT, 0.12), GOLD, 0.0, MeshKit.PAT_GOLD,
			MeshKit.ALL_FACES & ~MeshKit.FACE_NY, 0.7)
	_racks(s, hw)
	_cargo_hull(s, hw, skin)
	_prow(s, hw)
	_bridge(s, hw)
	_boom(s)
	_engines(s, g, hw, skin)
	return batch.to_mesh()


## The racks' decks along both flanks, past the belly's edges: their gold rails and cradles (the missiles lie
## in them: rack_slots, a MultiMesh of their own so each can blow up on its own).
static func _racks(s: MeshLayer, hw: float) -> void:
	var zf: float = -LENGTH * 0.5
	var zn: float = LENGTH * 0.5
	var from: float = zf + RACK_FROM - 1.4
	var to: float = zn - RACK_TO + 1.4
	for side: float in [-1.0, 1.0]:
		var mid: float = side * (hw + RACK_OUT * 0.5)
		# The deck, its underside a darker bronze (the drones hit it there).
		s.box(Vector3(mid, SKIRT + RACK_DECK * 0.5, (from + to) * 0.5), Vector3(RACK_OUT, RACK_DECK, to - from), BRONZE, 0.0,
			MeshKit.PAT_HULL)
		# Its outer rail on posts, a gold rail along the hull's side.
		var rail_x: float = side * (hw + RACK_OUT - 0.08)
		s.box(Vector3(rail_x, SKIRT + RACK_DECK + 0.75, (from + to) * 0.5), Vector3(0.12, 0.12, to - from), GOLD, 0.0,
			MeshKit.PAT_GOLD, MeshKit.ALL_FACES, 0.85)
		var z: float = from + 0.3
		while z <= to:
			s.box(Vector3(rail_x, SKIRT + RACK_DECK + 0.38, z), Vector3(0.1, 0.72, 0.1), GOLD, 0.0, MeshKit.PAT_GOLD,
				MeshKit.ALL_FACES, 0.85)
			z += 2.4
		# A cradle across the deck under each missile's middle (bronze).
		var cz: float = zf + RACK_FROM
		while cz <= zn - RACK_TO + 0.01:
			s.box(Vector3(mid, SKIRT + RACK_DECK + 0.08, cz + 0.4), Vector3(RACK_OUT - 0.2, 0.16, 0.18), BRONZE)
			cz += RACK_SPACING
		# Braces from the skirt's foot out to the deck's underside (so it reads held, not floating).
		for k: int in 4:
			var sz: float = lerpf(from + 1.0, to - 1.0, float(k) / 3.0)
			s.prism_xform(_along(Vector3(side * (hw - 0.05), 0.15, sz), Vector3(side * (hw + RACK_OUT * 0.6), SKIRT, sz), 0.09),
				6, BRONZE)


## The cargo hull over the belly: chamfered cream sides under a gold top, gold bands along it, the cult's emblem
## in relief on each flank and on the stern.
static func _cargo_hull(s: MeshLayer, hw: float, skin: GoldenSkin) -> void:
	var zf: float = -LENGTH * 0.5 + HULL_BOW_INSET
	var zn: float = LENGTH * 0.5 - HULL_STERN_INSET
	var w: float = hw - 0.25
	var top_w: float = w - 1.1
	var length: float = zn - zf
	var mid_z: float = (zf + zn) * 0.5
	var shoulder: float = HULL_TOP - 0.9
	# Its sides (vertical from the skirt to the shoulder), the chamfers to the top, the top.
	for side: float in [-1.0, 1.0]:
		s.box(Vector3(side * (w - 0.1), (SKIRT + shoulder) * 0.5, mid_z), Vector3(0.2, shoulder - SKIRT, length), CREAM, 0.0,
			MeshKit.PAT_HULL, MeshKit.FACE_PX if side > 0.0 else MeshKit.FACE_NX)
		var a := Vector3(side * w, shoulder, zn)
		var b := Vector3(side * top_w, HULL_TOP, zn)
		var c := Vector3(side * top_w, HULL_TOP, zf)
		var d := Vector3(side * w, shoulder, zf)
		if side > 0.0:
			s.quad(a, b, c, d, GOLD, 0.0, MeshKit.PAT_GOLD, 0.8)
		else:
			s.quad(d, c, b, a, GOLD, 0.0, MeshKit.PAT_GOLD, 0.8)
		# Gold bands along the side.
		s.box(Vector3(side * w, SKIRT + 0.35, mid_z), Vector3(0.06, 0.18, length), GOLD, 0.0, MeshKit.PAT_GOLD,
			MeshKit.FACE_PX if side > 0.0 else MeshKit.FACE_NX, 0.9)
		s.box(Vector3(side * w, shoulder - 0.12, mid_z), Vector3(0.06, 0.14, length), GOLD, 0.0, MeshKit.PAT_GOLD,
			MeshKit.FACE_PX if side > 0.0 else MeshKit.FACE_NX, 0.9)
		# The emblem in relief at the flank's middle, facing out.
		var panel: float = minf(shoulder - SKIRT - 0.35, 2.2)
		var face_x: float = side * (w + 0.02)
		s.box(Vector3(face_x + side * 0.03, (SKIRT + shoulder) * 0.5, mid_z), Vector3(0.06, panel + 0.2, panel + 0.2), GOLD, 0.0,
			MeshKit.PAT_GOLD, MeshKit.FACE_PX if side > 0.0 else MeshKit.FACE_NX, 0.95)
		var y0: float = (SKIRT + shoulder) * 0.5 - panel * 0.5
		if side > 0.0:
			GoldenSkin.emblem_panel(s, Vector3(face_x + 0.07, y0, mid_z + panel * 0.5), Vector3(0, 0, -panel), Vector3(0, panel, 0),
				panel * 0.78, skin.stone_colors[0], 1)
		else:
			GoldenSkin.emblem_panel(s, Vector3(face_x - 0.07, y0, mid_z - panel * 0.5), Vector3(0, 0, panel), Vector3(0, panel, 0),
				panel * 0.78, skin.stone_colors[0], 1)
	s.rect(Vector3(-top_w, HULL_TOP, zn), Vector3(top_w * 2.0, 0, 0), Vector3(0, 0, zf - zn), GOLD, 0.0, MeshKit.PAT_GOLD,
		Vector2.ZERO, Vector2.ONE, 0.75)
	# A raised spine along the top, gold.
	s.box(Vector3(0.0, HULL_TOP + 0.2, mid_z + 2.0), Vector3(1.2, 0.4, length - 9.0), GOLD, 0.0, MeshKit.PAT_GOLD,
		MeshKit.NO_BOTTOM, 0.9)
	# The ends: the stern's face (toward the runner) cream with the emblem, the bow's under the prow.
	for end: int in [-1, 1]:
		var z: float = zn if end > 0 else zf
		var a := Vector3(-w, SKIRT, z)
		var b := Vector3(-w, shoulder, z)
		var c := Vector3(-top_w, HULL_TOP, z)
		var d := Vector3(top_w, HULL_TOP, z)
		var e := Vector3(w, shoulder, z)
		var f := Vector3(w, SKIRT, z)
		if end > 0:
			s.quad(a, b, e, f, CREAM, 0.0, MeshKit.PAT_HULL)
			s.quad(b, c, d, e, CREAM, 0.0, MeshKit.PAT_HULL)
		else:
			s.quad(f, e, b, a, CREAM, 0.0, MeshKit.PAT_HULL)
			s.quad(e, d, c, b, CREAM, 0.0, MeshKit.PAT_HULL)
	var stern_panel: float = minf(shoulder - SKIRT - 0.2, 2.4)
	var sy: float = (SKIRT + shoulder) * 0.5
	s.box(Vector3(0.0, sy, zn + 0.03), Vector3(stern_panel + 0.2, stern_panel + 0.2, 0.06), GOLD, 0.0, MeshKit.PAT_GOLD,
		MeshKit.FACE_PZ, 0.95)
	GoldenSkin.emblem_panel(s, Vector3(-stern_panel * 0.5, sy - stern_panel * 0.5, zn + 0.07), Vector3(stern_panel, 0, 0),
		Vector3(0, stern_panel, 0), stern_panel * 0.78, skin.stone_colors[0], 1)


## The prow: a pointed wedge over the belly's bow end (its underside never below the belly's: the ceiling stays
## flush), a gold edge along its keel.
static func _prow(s: MeshLayer, hw: float) -> void:
	var zf: float = -LENGTH * 0.5
	var base_z: float = zf + HULL_BOW_INSET
	var tip := Vector3(0.0, 1.6, zf - PROW)
	var top_tip := Vector3(0.0, 3.0, zf - PROW + 0.6)
	var w: float = hw - 0.25
	var bl := Vector3(-w, 0.05, base_z)
	var br := Vector3(w, 0.05, base_z)
	var tl := Vector3(-w + 1.1, HULL_TOP, base_z)
	var tr := Vector3(w - 1.1, HULL_TOP, base_z)
	# Under it (facing down, from the belly's bow up to the tip), its two sides, its top.
	s.quad(br, tip, tip, bl, GOLD, 0.0, MeshKit.PAT_GOLD, 0.7)
	s.quad(bl, tip, top_tip, tl, CREAM, 0.0, MeshKit.PAT_HULL)
	s.quad(tr, top_tip, tip, br, CREAM, 0.0, MeshKit.PAT_HULL)
	s.quad(tl, top_tip, top_tip, tr, GOLD, 0.0, MeshKit.PAT_GOLD, 0.8)
	# A gold keel line along the prow's edges.
	s.box_between(Vector3(-0.08, 1.5, zf - PROW + 0.1), Vector3(0.08, 3.05, zf - PROW + 0.7), GOLD, 0.0, MeshKit.PAT_GOLD,
		MeshKit.ALL_FACES, 0.9)


## The bridge at the stern: a cream deckhouse with dark windows on its back and sides, a gold roof trim.
static func _bridge(s: MeshLayer, hw: float) -> void:
	var zn: float = LENGTH * 0.5 - HULL_STERN_INSET
	var w: float = minf(hw * 0.45, 3.0)
	var z0: float = zn - 7.0
	var z1: float = zn - 1.6
	var y0: float = HULL_TOP
	var y1: float = HULL_TOP + 1.7
	s.box(Vector3(0.0, (y0 + y1) * 0.5, (z0 + z1) * 0.5), Vector3(w * 2.0, y1 - y0, z1 - z0), CREAM, 0.0, MeshKit.PAT_HULL,
		MeshKit.NO_BOTTOM)
	s.box(Vector3(0.0, y1 + 0.05, (z0 + z1) * 0.5), Vector3(w * 2.0 + 0.2, 0.1, z1 - z0 + 0.2), GOLD, 0.0, MeshKit.PAT_GOLD,
		MeshKit.NO_BOTTOM, 0.9)
	s.box(Vector3(0.0, (y0 + y1) * 0.5 + 0.15, z1 + 0.01), Vector3(w * 2.0 - 0.5, 0.7, 0.02), GLASS, 0.0, MeshKit.PAT_GLASS,
		MeshKit.FACE_PZ)
	for side: float in [-1.0, 1.0]:
		s.box(Vector3(side * (w + 0.01), (y0 + y1) * 0.5 + 0.15, (z0 + z1) * 0.5), Vector3(0.02, 0.7, z1 - z0 - 1.0), GLASS, 0.0,
			MeshKit.PAT_GLASS, MeshKit.FACE_PX if side > 0.0 else MeshKit.FACE_NX)


## The feed boom amidships: a gold mast rising from the hull's spine, an arm reaching forward and up to the
## nozzle the line leaves from (BOOM_TIP).
static func _boom(s: MeshLayer) -> void:
	var foot := Vector3(0.0, HULL_TOP + 0.35, BOOM_TIP.z + 2.4)
	var knee := Vector3(0.0, BOOM_TIP.y - 0.6, BOOM_TIP.z + 1.6)
	s.prism_xform(_along(foot, knee, 0.42), 8, GOLD, 0.0, MeshKit.PAT_GOLD, true, 0.85)
	s.prism_xform(_along(knee, BOOM_TIP, 0.3), 8, GOLD, 0.0, MeshKit.PAT_GOLD, true, 0.85)
	s.prism_xform(_along(BOOM_TIP + Vector3(0.0, 0.0, 0.45), BOOM_TIP - Vector3(0.0, 0.0, 0.3), 0.5), 8, BRONZE)
	s.box(foot + Vector3(0.0, 0.15, 0.0), Vector3(1.4, 0.3, 1.4), GOLD, 0.0, MeshKit.PAT_GOLD, MeshKit.NO_BOTTOM, 0.85)


## The engines at the stern: nozzles in gold with pale blue cores glowing, their halos (above the underside,
## fading near the camera as every ship's: MeshKit.stern_halo).
static func _engines(s: MeshLayer, g: MeshLayer, hw: float, skin: GoldenSkin) -> void:
	var zn: float = LENGTH * 0.5
	var count: int = clampi(roundi(hw * 2.0 / 4.0), 2, 4)
	var y: float = SKIRT + 1.25
	for i: int in count:
		var ex: float = -hw + 0.8 + (float(i) + 0.5) * (hw * 2.0 - 1.6) / count
		var r: float = minf(0.85, (hw * 2.0 - 1.6) / count * 0.38)
		var nozzle := Transform3D(Basis(Vector3(r, 0, 0), Vector3(0, 0, 1.2), Vector3(0, r, 0)), Vector3(ex, y, zn - 0.4))
		s.prism_xform(nozzle, 8, GOLD.darkened(0.3), 0.0, MeshKit.PAT_GOLD, false, 0.8)
		var core := Transform3D(Basis(Vector3(r * 0.72, 0, 0), Vector3(0, 0, 0.05), Vector3(0, r * 0.72, 0)), Vector3(ex, y, zn + 0.5))
		s.prism_xform(core, 8, skin.engine_color, 0.9)
		MeshKit.stern_halo(g, Vector3(ex, y, zn + 0.9), r * 2.2, skin.engine_color, 0.35)


## A missile along -z (its nose forward): bronze with a gold nose and fins, as the barrage's, `length` long.
static func _missile(skin: GoldenSkin, length: float, radius: float) -> ArrayMesh:
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(skin.solid_material())
	s.prism_xform(Transform3D(Basis(Vector3.RIGHT, -PI * 0.5) * Basis.from_scale(Vector3(radius, length * 0.75, radius)),
		Vector3(0.0, 0.0, length * 0.5)), 6, MISSILE, 0.0, MeshKit.PAT_GOLD, true, 0.5)
	s.prism_xform(Transform3D(Basis(Vector3.RIGHT, -PI * 0.5) * Basis.from_scale(Vector3(radius * 0.9, length * 0.25, radius * 0.9)),
		Vector3(0.0, 0.0, -length * 0.25)), 6, NOSE, 0.0, MeshKit.PAT_GOLD, true, 0.85)
	for k: int in 4:
		var a: float = TAU * float(k) / 4.0 + PI * 0.25
		s.box_xform(Transform3D(Basis(Vector3.BACK, a) * Basis.from_scale(Vector3(radius * 2.6, 0.05, length * 0.2)),
			Vector3(0.0, 0.0, length * 0.42)), NOSE, 0.0, MeshKit.PAT_GOLD, MeshKit.ALL_FACES, 0.85)
	return batch.to_mesh()


## A piece of the feed line, a unit along +y (scaled to each piece): a dark bronze hose with a gold band at its
## foot.
static func _segment(skin: GoldenSkin) -> ArrayMesh:
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(skin.solid_material())
	s.prism(Vector3.ZERO, 1.0, 1.0, 8, LINE, 0.0, MeshKit.PAT_GOLD, false, 0.6)
	s.prism(Vector3.ZERO, 1.14, 0.14, 8, BRONZE, 0.0, MeshKit.PAT_PLAIN, true)
	return batch.to_mesh()


## A transform that maps the unit prism (radius 1, y from 0 to 1) to a rod from `a` to `b` of `radius`.
static func _along(a: Vector3, b: Vector3, radius: float) -> Transform3D:
	var axis: Vector3 = b - a
	var y: Vector3 = axis
	var x: Vector3 = axis.cross(Vector3.FORWARD if absf(axis.normalized().dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized() * radius
	var z: Vector3 = x.cross(axis).normalized() * radius
	return Transform3D(Basis(x, y, z), a)
