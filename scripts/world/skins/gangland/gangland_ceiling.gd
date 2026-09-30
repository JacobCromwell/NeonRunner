class_name GanglandCeiling
extends RefCounted
## Ceiling sections in Gangland (GanglandSkin, GDD §3, §5): the undersides of overpasses and of
## bombed-out buildings bridging the street. Either way the surface is a flat slab of cast concrete
## (PAT_CONCRETE) across the lanes it covers, one precast beam per lane with a dark joint and small
## caged work lamps along each lane seam, so a runner hanging from it reads the lanes. Nothing hangs
## below it but those flush lamps (it's a surface to run on), and its far end carries the orange
## edge (MeshKit.ceiling_end: the drop back to the floor, as in every zone).
## Seen on the approach, a ceiling across the street is one of two structures, picked by hashing the
## ceiling's start:
## - an overpass: a tagged concrete fascia under a crash barrier and railing, with a sign gantry
##   (salvaged billboards and corporate ads, and salvaged screens playing the cult's feed), dead lamp
##   posts, a wreck and military supply crates behind a sandbag nest up on the deck;
## - a building: the upper storeys of a bombed-out block bridging the street (facade.gdshader's ruin
##   mode, lit windows with curtains) with a broken top, laundry and rooftop clutter.
## A ceiling over fewer lanes (a narrow ceiling, GDD §3) is a slab broken off a building (the owner's
## review, P2 18): a thick floor slab with broken edges, rebar sticking out of them, rubble, broken
## column stubs and a piece of the wall above still standing on it. A side that reaches the street's
## edge is still lodged in the building face there; a slab that reaches neither hangs from the steel
## beams of its building's frame, torn and bent, running up to the building faces on both sides high
## above the lanes.
## Width comes from the lanes the ceiling covers (its collision box), never from the track: each
## side either runs into the building faces (anchored) or ends in a free edge with a side fascia.
## Everything above the slab stays below ABOVE_LIMIT, so lines strung across the street higher up
## (GanglandRuins.CROSS_LINE_MIN) never cut through a ceiling.
## DESIGN-TBD: GDD §5 names the structures, not their looks: the two kinds, the lamps marking the
## lane seams and the broken slab's details (docs/questions/b3.md) are proposals.
## Ceiling space: origin at the centre of the underside (the ceiling surface), z = -distance.

enum Kind { OVERPASS, BUILDING, SLAB }

## The orange end band's depth.
const STERN_BAND: float = 1.2
## How far an anchored side runs past its outer lane into the building face.
const WALL_EMBED: float = 1.6
## How far the slab overhangs a free side.
const FREE_LIP: float = 0.15
## Lamps along each seam, this far apart.
const LAMP_SPACING: float = 9.0
## Nothing of a ceiling rises higher than this above its underside.
const ABOVE_LIMIT: float = 7.9
## A gantry screen playing the cult's feed sits this far inside its board, which frames it.
const FEED_INSET: float = 0.06
## A slab broken off a building: its thickness above the underside, how far the rebar sticks out of its
## broken edges, and how high its frame's beams rise to the building faces above its top.
const SLAB_DEPTH: float = 0.6
const REBAR_OUT: float = 0.5
const BEAM_RISE: float = 2.4

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: GanglandSkin:
	get:
		return _skin.get_ref() as GanglandSkin
var _skin: WeakRef
var _meshes: Dictionary = {}


func _init(p_skin: GanglandSkin) -> void:
	_skin = weakref(p_skin)


## Adds a ceiling section. center/size describe its collision box (the underside is the surface);
## lane_edges_x are the world x of the seams between its lanes. anchored_left/right: whether that side
## reaches the street's edge and runs into a building face, or is a free edge (CeilingSection.
## reaches_wall). A ceiling anchored on both sides spans the street (an overpass or a building); any
## other is a slab broken off a building (kind_of). wall_x: the wall faces' distance from the track's
## centre (a slab's beams run up to them; 0 puts them just past its sides).
func build(parent: Node3D, center: Vector3, size: Vector3, lane_edges_x: Array[float], anchored_left: bool = true,
		anchored_right: bool = true, wall_x: float = 0.0) -> void:
	var start: float = -(center.z + size.z * 0.5)
	var kind: Kind = kind_of(start, anchored_left, anchored_right)
	var deco: int = MeshKit.hash_i(MeshKit.key(start), 7, 5) % 4
	var id: String = "%s_%s_%s_%d_%d_%s_%s_%s" % [size, lane_edges_x, center.x, kind, deco, anchored_left, anchored_right,
		wall_x]
	var mesh: ArrayMesh = _meshes.get(id)
	if mesh == null:
		if _meshes.size() > 256:
			_meshes.clear()
		var seams: Array[float] = []
		for x: float in lane_edges_x:
			seams.append(x - center.x)
		var walls := Vector2(-wall_x - center.x, wall_x - center.x) if wall_x > 0.0 \
			else Vector2(-size.x * 0.5 - 1.0, size.x * 0.5 + 1.0)
		mesh = _mesh(size, seams, kind, deco, anchored_left, anchored_right, center.y - size.y * 0.5, walls)
		_meshes[id] = mesh
	MeshBatch.add_instance(parent, mesh, "", Vector3(center.x, center.y - size.y * 0.5, center.z))


## Which structure forms the ceiling that starts at track distance `start` and reaches the building
## faces on both sides (kind_at) or not (a slab broken off a building, the owner's review P2 18).
func kind_of(start: float, anchored_left: bool, anchored_right: bool) -> Kind:
	return kind_at(start) if anchored_left and anchored_right else Kind.SLAB


## Which structure forms a ceiling across the street that starts at track distance `start`.
func kind_at(start: float) -> Kind:
	return Kind.BUILDING if MeshKit.hash01(MeshKit.key(start), 7, 3) < skin.ceiling_building_share else Kind.OVERPASS


## `walls`: the wall faces' x on the left and on the right, in ceiling space.
func _mesh(size: Vector3, seams: Array[float], kind: Kind, deco: int, anchored_left: bool, anchored_right: bool,
		base_y: float, walls: Vector2) -> ArrayMesh:
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(skin.solid_material())
	var g: MeshLayer = batch.layer(skin.glow_material())
	var xa: float = -size.x * 0.5 - (WALL_EMBED if anchored_left else FREE_LIP)
	var xb: float = size.x * 0.5 + (WALL_EMBED if anchored_right else FREE_LIP)
	var zn: float = size.z * 0.5
	var zf: float = -size.z * 0.5
	_underside(s, g, xa, xb, zn, zf, seams, kind)
	MeshKit.ceiling_end(s, g, (xb - xa) * 0.5, zf, STERN_BAND, skin.gap_edge_color, (xa + xb) * 0.5)
	match kind:
		Kind.OVERPASS:
			_overpass(s, g, batch.layer(skin.feed_material()), xa, xb, zn, zf, size.x, deco, anchored_left, anchored_right)
		Kind.BUILDING:
			_building(batch.layer(skin.facade_material()), s, xa, xb, zn, zf, size.x, deco, anchored_left, anchored_right,
				base_y)
		_:
			_slab(s, xa, xb, zn, zf, deco, anchored_left, anchored_right, walls)
	return batch.to_mesh()


# --- The surface --------------------------------------------------------------------------

## The slab's underside: one precast beam per lane in its own tone (lightly tagged on overpasses),
## dark joints and caged lamps along the lane seams.
func _underside(s: MeshLayer, g: MeshLayer, xa: float, xb: float, zn: float, zf: float, seams: Array[float],
		kind: Kind) -> void:
	var edges: Array[float] = [xa]
	edges.append_array(seams)
	edges.append(xb)
	var concrete: Color = skin.ceiling_concrete_color if kind == Kind.OVERPASS else skin.ceiling_slab_color
	var z0: float = zf + STERN_BAND
	var tags: float = skin.ceiling_graffiti if kind == Kind.OVERPASS else 0.0
	var lamp: Color = skin.ceiling_lamp_color
	for i: int in edges.size() - 1:
		var tone: float = 0.92 + 0.16 * MeshKit.hash01(i, 5, 19)
		# Faces down (u across, v toward the near end): the surface a runner hangs from.
		s.rect(Vector3(edges[i], 0, z0), Vector3(edges[i + 1] - edges[i], 0, 0), Vector3(0, 0, zn - z0),
			concrete * Color(tone, tone, tone), 0.0, MeshKit.PAT_CONCRETE, Vector2.ZERO, Vector2.ONE, tags)
	for x: float in seams:
		s.rect(Vector3(x - 0.06, -0.004, z0), Vector3(0.12, 0, 0), Vector3(0, 0, zn - z0), concrete.darkened(0.6))
		var z: float = zf + 6.0
		while z < zn - 2.0:
			# Caged work lamps: flush boxes (0.06 m deep) with a soft pool of light around them.
			s.box(Vector3(x, -0.03, z), Vector3(0.2, 0.06, 0.2), lamp, 0.75, MeshKit.PAT_PLAIN,
				MeshKit.ALL_FACES & ~MeshKit.FACE_PY)
			s.box(Vector3(x, -0.035, z), Vector3(0.26, 0.02, 0.05), concrete.darkened(0.5), 0.0, MeshKit.PAT_PLAIN,
				MeshKit.ALL_FACES & ~MeshKit.FACE_PY)
			g.rect(Vector3(x - 0.8, -0.07, z + 0.8), Vector3(1.6, 0, 0), Vector3(0, 0, -1.6), lamp, 0.28, MeshKit.SHAPE_RADIAL)
			z += LAMP_SPACING


## A free side: the slab's edge face from the underside up to `height`, facing out.
func _free_side(s: MeshLayer, x: float, side: float, zn: float, zf: float, height: float, color: Color) -> void:
	if side < 0.0:
		s.rect(Vector3(x, 0, zf), Vector3(0, 0, zn - zf), Vector3(0, height, 0), color, 0.0, MeshKit.PAT_CONCRETE,
			Vector2.ZERO, Vector2.ONE, skin.ceiling_graffiti)
	else:
		s.rect(Vector3(x, 0, zn), Vector3(0, 0, zf - zn), Vector3(0, height, 0), color, 0.0, MeshKit.PAT_CONCRETE,
			Vector2.ZERO, Vector2.ONE, skin.ceiling_graffiti)


# --- Overpass -----------------------------------------------------------------------------

func _overpass(s: MeshLayer, g: MeshLayer, feed: MeshLayer, xa: float, xb: float, zn: float, zf: float,
		lanes_width: float, deco: int, anchored_left: bool, anchored_right: bool) -> void:
	var t: float = skin.overpass_depth
	var concrete: Color = skin.ceiling_concrete_color
	var fascia: Color = concrete.lightened(0.08)
	var metal: Color = skin.scrap_metal_color
	var k: int = deco * 101 + MeshKit.key(zn - zf)
	# The fascia facing the approach, tagged all over, with a cornice along its top.
	s.rect(Vector3(xa, 0, zn), Vector3(xb - xa, 0, 0), Vector3(0, t, 0), fascia, 0.0, MeshKit.PAT_CONCRETE,
		Vector2.ZERO, Vector2.ONE, skin.fascia_graffiti)
	s.box(Vector3((xa + xb) * 0.5, t + 0.06, zn - 0.05), Vector3(xb - xa, 0.16, 0.3), fascia.darkened(0.15), 0.0,
		MeshKit.PAT_CONCRETE, MeshKit.NO_BOTTOM)
	if not anchored_left:
		_free_side(s, xa, -1.0, zn, zf, t, fascia)
	if not anchored_right:
		_free_side(s, xb, 1.0, zn, zf, t, fascia)
	# Crash barrier and a railing along the near edge, broken open where a gang built a lookout of
	# sandbags and military supply crates (their stencils face the street).
	var x0: float = -lanes_width * 0.5
	var x1: float = lanes_width * 0.5
	var bz: float = zn - 0.45
	var nest_w: float = 3.0
	var nest_x: float = lerpf(x0 + 0.6, x1 - 0.6 - nest_w, MeshKit.hash01(k, 7))
	var rail_y: float = t + 0.94
	for run: Vector2 in [Vector2(xa, nest_x), Vector2(nest_x + nest_w, xb)]:
		var w: float = run.y - run.x
		if w < 0.2:
			continue
		var mx: float = (run.x + run.y) * 0.5
		s.box(Vector3(mx, t + 0.14 + 0.4, bz), Vector3(w, 0.8, 0.45), concrete, 0.0, MeshKit.PAT_CONCRETE,
			MeshKit.NO_BOTTOM, skin.fascia_graffiti * 0.6)
		s.box(Vector3(mx, rail_y + 0.62, bz), Vector3(w, 0.06, 0.06), metal)
		s.box(Vector3(mx, rail_y + 0.3, bz), Vector3(w, 0.04, 0.04), metal)
		var px: float = run.x + 0.3
		while px < run.y - 0.2:
			s.box(Vector3(px, rail_y + 0.33, bz), Vector3(0.05, 0.66, 0.05), metal)
			px += 1.6
	GanglandClutter.sandbag_wall(s, Vector3(nest_x, t + 0.14, zn - 0.35), nest_w, 5, skin.sandbag_color)
	for i: int in 2:
		var cx: float = nest_x + 0.8 + 1.4 * float(i)
		GanglandClutter.crate_stack(s, Vector3(cx, t + 0.14, zn - 1.2), Vector3(0, 0, 1), skin.military_crate_colors,
			k + i * 13, skin.cult_emblem_share)
	# A sign gantry over the deck, its boards salvaged billboards and corporate ads, and some of them
	# salvaged screens playing the cult's feed (its backing board the bezel), facing the approach.
	var gz: float = zn - 5.0 - 3.0 * MeshKit.hash01(k, 1)
	var top: float = t + 5.4
	for x: float in [x0 + 0.5, x1 - 0.5]:
		s.box(Vector3(x, (t + top) * 0.5, gz), Vector3(0.3, top - t, 0.3), metal, 0.0, MeshKit.PAT_RUST, MeshKit.NO_BOTTOM)
	s.box(Vector3(0, top, gz), Vector3(x1 - x0, 0.45, 0.4), metal.darkened(0.2), 0.0, MeshKit.PAT_RUST)
	var boards: int = clampi(floori((x1 - x0) / 4.2), 1, 3)
	var bw: float = (x1 - x0 - 1.4) / float(boards)
	for i: int in boards:
		var bx: float = x0 + 0.7 + (float(i) + 0.5) * bw
		var w: float = bw - 0.35
		var h: float = 1.5 + 0.4 * MeshKit.hash01(k, i, 2)
		var poster: Color = skin.sign_content_colors[MeshKit.hash_i(k, i, 3) % skin.sign_content_colors.size()]
		s.box(Vector3(bx, top - 0.3 - h * 0.5, gz - 0.06), Vector3(w + 0.16, h + 0.16, 0.1), metal.darkened(0.3))
		if skin.shows_feed(k, i):
			CultFeed.screen(feed, Vector3(bx - w * 0.5 + FEED_INSET, top - 0.3 - h + FEED_INSET, gz),
				Vector3(w - FEED_INSET * 2.0, 0, 0), Vector3(0, h - FEED_INSET * 2.0, 0), skin.feed_board_brightness, k + i)
			continue
		s.rect(Vector3(bx - w * 0.5, top - 0.3 - h, gz), Vector3(w, 0, 0), Vector3(0, h, 0), poster, 0.0,
			MeshKit.PAT_POSTER, Vector2(0, 0), Vector2(w, h), float(MeshKit.hash_i(k, i, 4) % 97))
	# A dead lamp post on one side, its arm over the deck.
	var lamp_side: float = -1.0 if MeshKit.hash01(k, 5) < 0.5 else 1.0
	var lx: float = (x0 + 0.35) if lamp_side < 0.0 else (x1 - 0.35)
	var lz: float = zn - 1.2 - 8.0 * MeshKit.hash01(k, 6)
	s.box(Vector3(lx, t + 2.6, lz), Vector3(0.14, 5.2, 0.14), metal)
	s.box(Vector3(lx - lamp_side * 0.9, t + 5.15, lz), Vector3(1.8, 0.1, 0.12), metal)
	s.box(Vector3(lx - lamp_side * 1.7, t + 5.0, lz), Vector3(0.5, 0.18, 0.24), metal.darkened(0.3))
	# A burnt-out wreck pushed against the barrier, its roof showing over it.
	if MeshKit.hash01(k, 8) < 0.6:
		var wx: float = lerpf(x0 + 2.5, x1 - 2.5, MeshKit.hash01(k, 9))
		if absf(wx - (nest_x + nest_w * 0.5)) > 3.6:
			GanglandClutter.wreck(s, Vector3(wx, t + 0.14, zn - 1.8), true, skin.wreck_color, k)


# --- Bombed-out building ----------------------------------------------------------------------

## The upper storeys of a bombed-out block bridging the street: a ruined facade toward the approach,
## storey slabs broken off at the top, laundry strung between its windows and clutter on its roof.
func _building(facade: MeshLayer, s: MeshLayer, xa: float, xb: float, zn: float, zf: float, lanes_width: float,
		deco: int, anchored_left: bool, anchored_right: bool, base_y: float) -> void:
	var k: int = deco * 211 + MeshKit.key(zn - zf)
	var style: int = [1, 2, 3][MeshKit.hash_i(k, 6) % 3]
	# Storey lines where the facade shader's window rows break (multiples of its storey height in
	# world height), so slab edges never cut through a window.
	var storey: float = GanglandRuins.STOREYS[style]
	var first_line: float = ceilf(base_y / storey + 0.05) * storey - base_y
	var storeys: int = 1 + MeshKit.hash_i(k, 1) % 2
	var height: float = minf(first_line + float(storeys) * storey + 0.5 + 0.7 * MeshKit.hash01(k, 2), ABOVE_LIMIT - 2.6)
	var wall: Color = skin.facade_colors[MeshKit.hash_i(k, 3) % skin.facade_colors.size()]
	var lit: float = skin.ruin_lit_min + (skin.ruin_lit_max - skin.ruin_lit_min) * MeshKit.hash01(k, 4)
	var seed: float = float(MeshKit.hash_i(k, 5) % 997)
	# The broken top: a profile across the street, lower where a blast bit into it.
	var xs := PackedFloat32Array()
	var tops := PackedFloat32Array()
	var bite_x: float = lerpf(xa + 2.0, xb - 2.0, MeshKit.hash01(k, 7))
	var bite_w: float = 2.0 + 2.5 * MeshKit.hash01(k, 8)
	var x: float = xa
	while true:
		xs.append(x)
		var h: float = height - 0.6 * MeshKit.hash01(k, MeshKit.key(x), 9)
		h -= 1.8 * maxf(0.0, 1.0 - absf(x - bite_x) / bite_w)
		tops.append(maxf(h, 1.4))
		if x >= xb - 0.001:
			break
		x = minf(x + 1.5, xb)
	# The facade: UV in metres across the face and in world height, so its windows sit in storeys
	# like the walls' and the lowest ones clear the wall-run band.
	for i: int in xs.size() - 1:
		var a := Vector3(xs[i], 0, zn)
		var b := Vector3(xs[i], tops[i], zn)
		var c := Vector3(xs[i + 1], tops[i + 1], zn)
		var d := Vector3(xs[i + 1], 0, zn)
		facade.quad_uv(a, b, c, d, Vector2(xs[i], base_y), Vector2(xs[i], base_y + tops[i]),
			Vector2(xs[i + 1], base_y + tops[i + 1]), Vector2(xs[i + 1], base_y), wall, lit, style, seed)
	# Free sides get a plain ruined end wall.
	for side: float in [-1.0, 1.0]:
		if (side < 0.0 and anchored_left) or (side > 0.0 and anchored_right):
			continue
		var sx: float = xa if side < 0.0 else xb
		var sh: float = tops[0] if side < 0.0 else tops[tops.size() - 1]
		_free_side(s, sx, side, zn, zf, sh, wall.darkened(0.1))
	# A slab edge along the bottom and at each storey, with rebar where the blast tore it.
	var slab: Color = wall.lightened(0.1)
	s.box(Vector3((xa + xb) * 0.5, 0.12, zn + 0.1), Vector3(xb - xa, 0.24, 0.2), slab, 0.0, MeshKit.PAT_CONCRETE,
		MeshKit.NO_BOTTOM)
	for j: int in storeys:
		var y: float = first_line + float(j) * storey
		if y < 0.4:
			continue
		var i: int = 0
		while i < xs.size() - 1:
			if minf(tops[i], tops[i + 1]) > y + 0.3:
				s.box(Vector3((xs[i] + xs[i + 1]) * 0.5, y, zn + 0.12), Vector3(xs[i + 1] - xs[i], 0.2, 0.24), slab)
			elif maxf(tops[i], tops[i + 1]) > y - 0.2 and MeshKit.hash01(k, i, 12 + j) < 0.6:
				s.box(Vector3(xs[i] + 0.4, y + 0.1, zn + 0.3), Vector3(0.03, 0.03, 0.6), skin.rust_color.darkened(0.3))
			i += 1
	# Laundry strung between windows across the face.
	var x0: float = -lanes_width * 0.5
	var x1: float = lanes_width * 0.5
	var ly: float = first_line + storey * 0.3
	if ly > height - 1.0:
		ly = first_line - storey * 0.55
	if ly > 1.3 and ly < height - 0.8:
		GanglandClutter.laundry_line(s, Vector3(x0 + 0.5, ly, zn + 0.35), Vector3(x1 - 0.5, ly, zn + 0.35), 0.35,
			skin.cloth_colors, k, skin.line_color)
	# Rooftop clutter behind the broken top, seen as silhouettes against the sky.
	var roof_y: float = height - 0.7
	var rz: float = zn - 4.0 - 6.0 * MeshKit.hash01(k, 14)
	match deco:
		0:
			GanglandClutter.water_tank(s, Vector3(lerpf(x0 + 1.5, x1 - 1.5, MeshKit.hash01(k, 15)), roof_y, rz), 0.9, 1.4,
				skin.wreck_color)
		1:
			GanglandClutter.antenna(s, Vector3(lerpf(x0 + 1.0, x1 - 1.0, MeshKit.hash01(k, 15)), roof_y, rz), 2.6,
				skin.scrap_metal_color, k)
		2:
			GanglandClutter.dish(s, Vector3(lerpf(x0 + 1.0, x1 - 1.0, MeshKit.hash01(k, 15)), roof_y, rz), 0.8,
				Vector3(0, 0, 1), skin.scrap_metal_color.lightened(0.2))
		_:
			GanglandClutter.crate_stack(s, Vector3(lerpf(x0 + 1.0, x1 - 1.0, MeshKit.hash01(k, 15)), roof_y, zn - 1.5),
				Vector3(0, 0, 1), skin.military_crate_colors, k, skin.cult_emblem_share)


# --- A slab broken off a building (narrow ceilings) ----------------------------------------------

## A slab broken off a building (a ceiling over fewer lanes than the street has; the owner's review, P2
## 18): a thick floor slab over its lanes, its top strewn with rubble, a broken column stub or two with
## rebar sticking out and a piece of the storey's wall still standing near its front with a window hole
## in it; its free sides and both ends broken, with chunks of concrete standing proud along the break
## and rebar sticking out of it. A side at the street's edge runs into the building face (anchored);
## with neither side there, torn steel beams of its building's frame carry it, rising from its sides to
## both building faces (`walls`: their x in ceiling space), high above the lanes. Nothing of it hangs
## below the underside, and nothing past its far end either.
func _slab(s: MeshLayer, xa: float, xb: float, zn: float, zf: float, deco: int, anchored_left: bool,
		anchored_right: bool, walls: Vector2) -> void:
	var k: int = deco * 307 + MeshKit.key(zn - zf)
	var concrete: Color = skin.ceiling_slab_color
	var broken: Color = concrete.darkened(0.18)
	var rebar: Color = skin.rust_color.darkened(0.2)
	var t: float = SLAB_DEPTH
	var up := Vector3.UP
	# The slab: its top, its broken ends (the near end faces the approach) and its free sides.
	s.rect(Vector3(xa, t, zn), Vector3(xb - xa, 0, 0), Vector3(0, 0, zf - zn), concrete.darkened(0.08), 0.0,
		MeshKit.PAT_CONCRETE)
	s.rect(Vector3(xa, 0, zn), Vector3(xb - xa, 0, 0), Vector3(0, t, 0), broken, 0.0, MeshKit.PAT_CONCRETE)
	s.rect(Vector3(xb, 0, zf), Vector3(xa - xb, 0, 0), Vector3(0, t, 0), broken, 0.0, MeshKit.PAT_CONCRETE)
	if not anchored_left:
		_free_side(s, xa, -1.0, zn, zf, t, broken)
	if not anchored_right:
		_free_side(s, xb, 1.0, zn, zf, t, broken)
	# The breaks: chunks standing proud along every broken edge, rebar sticking out of it. An anchored
	# side's edge runs into the building face (no break there).
	var x0: float = xa + (0.0 if not anchored_left else WALL_EMBED - 0.3)
	var x1: float = xb - (0.0 if not anchored_right else WALL_EMBED - 0.3)
	_broken_edge(s, Vector3(x0, t, zn), Vector3(x1, t, zn), Vector3(0, 0, 1), k + 1, broken, rebar)
	_broken_edge(s, Vector3(x1, t, zf), Vector3(x0, t, zf), Vector3(0, 0, -1), k + 2, broken, rebar)
	if not anchored_left:
		_broken_edge(s, Vector3(xa, t, zf), Vector3(xa, t, zn), Vector3(-1, 0, 0), k + 3, broken, rebar)
	if not anchored_right:
		_broken_edge(s, Vector3(xb, t, zn), Vector3(xb, t, zf), Vector3(1, 0, 0), k + 4, broken, rebar)
	# A piece of the storey's wall still standing near the front, with a window hole, and a broken
	# column stub or two with rebar out of their tops.
	var width: float = x1 - x0
	var wall: Color = skin.facade_colors[MeshKit.hash_i(k, 3) % skin.facade_colors.size()]
	var wz: float = zn - 0.9
	var wx0: float = x0 + 0.25
	var wx1: float = x1 - 0.25 - width * 0.3 * MeshKit.hash01(k, 4)
	var wh: float = 1.5 + 0.8 * MeshKit.hash01(k, 5)
	if wx1 - wx0 > 1.6:
		var hole0: float = lerpf(wx0 + 0.3, wx1 - 1.3, MeshKit.hash01(k, 6))
		s.box(Vector3((wx0 + hole0) * 0.5, t + wh * 0.5, wz), Vector3(hole0 - wx0, wh, 0.25), wall, 0.0, MeshKit.PAT_CONCRETE,
			MeshKit.NO_BOTTOM)
		var right_h: float = wh * (0.55 + 0.35 * MeshKit.hash01(k, 7))
		s.box(Vector3((hole0 + 1.0 + wx1) * 0.5, t + right_h * 0.5, wz), Vector3(wx1 - hole0 - 1.0, right_h, 0.25), wall, 0.0,
			MeshKit.PAT_CONCRETE, MeshKit.NO_BOTTOM)
		s.box(Vector3(hole0 + 0.5, t + 0.3, wz), Vector3(1.0, 0.6, 0.25), wall, 0.0, MeshKit.PAT_CONCRETE, MeshKit.NO_BOTTOM)
		if right_h > 1.7:
			s.box(Vector3(hole0 + 0.5, t + right_h - 0.2, wz), Vector3(1.0, 0.4, 0.25), wall, 0.0, MeshKit.PAT_CONCRETE)
	var stubs: int = 1 + MeshKit.hash_i(k, 8) % 2
	for i: int in stubs:
		var sx: float = lerpf(x0 + 0.5, x1 - 0.5, MeshKit.hash01(k, i, 9)) if width > 1.2 else (x0 + x1) * 0.5
		var sz: float = lerpf(zf + 3.0, wz - 2.5, (float(i) + 0.5) / stubs)
		if sz < zf + 2.0:
			continue
		var sh: float = 0.8 + 1.0 * MeshKit.hash01(k, i, 10)
		s.box(Vector3(sx, t + sh * 0.5, sz), Vector3(0.45, sh, 0.45), broken.lightened(0.05), 0.0, MeshKit.PAT_CONCRETE,
			MeshKit.NO_BOTTOM)
		for b: int in 3:
			var lean := Vector3(MeshKit.hash01(k, i * 7 + b, 11) - 0.5, 1.0, MeshKit.hash01(k, i * 7 + b, 12) - 0.5)
			_bar(s, Vector3(sx + (float(b) - 1.0) * 0.14, t + sh - 0.05, sz), lean.normalized(), 0.3 + 0.2 * MeshKit.hash01(k, b, 13),
				rebar)
	# Rubble on the top.
	for i: int in 3 + MeshKit.hash_i(k, 14) % 4:
		var rx: float = lerpf(x0 + 0.3, x1 - 0.3, MeshKit.hash01(k, i, 15))
		var rz: float = lerpf(zf + 2.0, zn - 1.8, MeshKit.hash01(k, i, 16))
		var r: float = 0.18 + 0.25 * MeshKit.hash01(k, i, 17)
		s.box_xform(Transform3D(Basis(up, MeshKit.hash01(k, i, 18) * TAU).scaled(Vector3(r * 1.6, r, r * 1.2)),
			Vector3(rx, t + r * 0.45, rz)), broken.lightened(0.04), 0.0, MeshKit.PAT_CONCRETE, MeshKit.NO_BOTTOM)
	# Free on both sides: its frame's torn beams carry it from the building faces.
	if anchored_left or anchored_right:
		return
	var metal: Color = skin.scrap_metal_color
	for side: float in [-1.0, 1.0]:
		var edge: float = xa if side < 0.0 else xb
		var face: float = walls.x if side < 0.0 else walls.y
		if side * (face - edge) < 0.3:
			continue
		for z: float in [zn - 2.2, zf + 3.2]:
			var j: int = MeshKit.key(z) + (7 if side > 0.0 else 3)
			var from := Vector3(edge - side * 0.4, t - 0.05, z)
			var to := Vector3(face + side * 0.3, t + BEAM_RISE * (0.8 + 0.2 * MeshKit.hash01(k, j, 19)),
				z + (MeshKit.hash01(k, j, 20) - 0.5) * 2.0)
			_beam(s, from, to, metal)


## Along a broken edge from `a` to `b` (on the slab's top, ceiling space) whose outside is `out`: chunks
## of concrete standing proud of the top, tilted, every metre or so, and rebar sticking out of the
## break between them, rising a little, never below the underside.
func _broken_edge(s: MeshLayer, a: Vector3, b: Vector3, out: Vector3, k: int, color: Color, rebar: Color) -> void:
	var length: float = a.distance_to(b)
	if length < 0.3:
		return
	var along: Vector3 = (b - a) / length
	var n: int = maxi(1, floori(length / 1.1))
	for i: int in n:
		var f: float = (float(i) + 0.25 + 0.5 * MeshKit.hash01(k, i, 1)) / n
		var p: Vector3 = a.lerp(b, f)
		var h: float = 0.1 + 0.26 * MeshKit.hash01(k, i, 2)
		var w: float = 0.3 + 0.5 * MeshKit.hash01(k, i, 3)
		var d: float = 0.35 + 0.3 * MeshKit.hash01(k, i, 4)
		var tilt: float = (MeshKit.hash01(k, i, 5) - 0.5) * 0.5
		var basis := Basis(along, tilt) * Basis(along * w, Vector3.UP * h, out * d)
		s.box_xform(Transform3D(basis, p + Vector3(0, h * 0.5 - 0.04, 0) - out * (d * 0.35)), color, 0.0, MeshKit.PAT_CONCRETE,
			MeshKit.NO_BOTTOM)
	var bars: int = maxi(1, floori(length / 0.7))
	for i: int in bars:
		if MeshKit.hash01(k, i, 6) < 0.3:
			continue
		var p: Vector3 = a.lerp(b, (float(i) + 0.5) / bars)
		var y: float = 0.18 + (SLAB_DEPTH - 0.3) * MeshKit.hash01(k, i, 7)
		var dir: Vector3 = (out + Vector3.UP * (0.1 + 0.4 * MeshKit.hash01(k, i, 8)) + along * (MeshKit.hash01(k, i, 9) - 0.5) * 0.5)
		_bar(s, Vector3(p.x, y, p.z) - out * 0.1, dir.normalized(), REBAR_OUT * (0.4 + 0.6 * MeshKit.hash01(k, i, 10)), rebar)


## A rebar from `from` along the unit direction `dir`, `length` long: a thin square bar.
static func _bar(s: MeshLayer, from: Vector3, dir: Vector3, length: float, color: Color) -> void:
	var side: Vector3 = dir.cross(Vector3.UP)
	if side.length() < 0.01:
		side = dir.cross(Vector3.BACK)
	side = side.normalized()
	var other: Vector3 = side.cross(dir).normalized()
	s.box_xform(Transform3D(Basis(dir * length, other * 0.035, side * 0.035), from + dir * length * 0.5), color)


## A steel I-beam of the slab's building frame from `from` to `to` (ceiling space): a web between two
## flanges, rusted.
static func _beam(s: MeshLayer, from: Vector3, to: Vector3, color: Color) -> void:
	var length: float = from.distance_to(to)
	var dir: Vector3 = (to - from) / length
	var across: Vector3 = dir.cross(Vector3.UP).normalized()
	var up: Vector3 = across.cross(dir).normalized()
	var mid: Vector3 = (from + to) * 0.5
	s.box_xform(Transform3D(Basis(dir * length, up * 0.34, across * 0.05), mid), color, 0.0, MeshKit.PAT_RUST)
	for f: float in [-0.16, 0.16]:
		s.box_xform(Transform3D(Basis(dir * length, up * 0.04, across * 0.22), mid + up * f), color.darkened(0.1), 0.0,
			MeshKit.PAT_RUST)
