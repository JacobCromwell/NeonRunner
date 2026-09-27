class_name GanglandCeiling
extends RefCounted
## Ceiling sections in Gangland (GanglandSkin, GDD §3, §5): the undersides of overpasses and of
## bombed-out buildings bridging the street. Either way the surface is a flat slab of cast concrete
## (PAT_CONCRETE) across the lanes it covers, one precast beam per lane with a dark joint and small
## caged work lamps along each lane seam, so a runner hanging from it reads the lanes. Nothing hangs
## below it but those flush lamps (it's a surface to run on), and its far end carries the orange
## edge (MeshKit.ceiling_end: the drop back to the floor, as in every zone).
## Seen on the approach, one of two structures, picked by hashing the ceiling's start:
## - an overpass: a tagged concrete fascia under a crash barrier and railing, with a sign gantry
##   (salvaged billboards and corporate ads, and salvaged screens playing the cult's feed), dead lamp
##   posts, a wreck and military supply crates behind a sandbag nest up on the deck;
## - a building: the upper storeys of a bombed-out block bridging the street (facade.gdshader's ruin
##   mode, lit windows with curtains) with a broken top, laundry and rooftop clutter.
## Width comes from the lanes the ceiling covers (its collision box), never from the track: each
## side either runs into the building faces (anchored) or ends in a free edge with a side fascia, so
## narrow ceilings (task B3) only have to say which sides reach a wall.
## Everything above the slab stays below ABOVE_LIMIT, so lines strung across the street higher up
## (GanglandRuins.CROSS_LINE_MIN) never cut through a ceiling.
## DESIGN-TBD: GDD §5 names the structures, not their looks: the two kinds, the lamps marking the
## lane seams and a free side's plain edge face (for narrow ceilings, B3) are proposals.
## Ceiling space: origin at the centre of the underside (the ceiling surface), z = -distance.

enum Kind { OVERPASS, BUILDING }

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
## runs into a building face (a full-width ceiling today) or is a free edge.
func build(parent: Node3D, center: Vector3, size: Vector3, lane_edges_x: Array[float], anchored_left: bool = true,
		anchored_right: bool = true) -> void:
	var start: float = -(center.z + size.z * 0.5)
	var kind: Kind = kind_at(start)
	var deco: int = MeshKit.hash_i(MeshKit.key(start), 7, 5) % 4
	var id: String = "%s_%s_%s_%d_%d_%s_%s" % [size, lane_edges_x, center.x, kind, deco, anchored_left, anchored_right]
	var mesh: ArrayMesh = _meshes.get(id)
	if mesh == null:
		var seams: Array[float] = []
		for x: float in lane_edges_x:
			seams.append(x - center.x)
		mesh = _mesh(size, seams, kind, deco, anchored_left, anchored_right, center.y - size.y * 0.5)
		_meshes[id] = mesh
	MeshBatch.add_instance(parent, mesh, "", Vector3(center.x, center.y - size.y * 0.5, center.z))


## Which structure forms the ceiling that starts at track distance `start`.
func kind_at(start: float) -> Kind:
	return Kind.BUILDING if MeshKit.hash01(MeshKit.key(start), 7, 3) < skin.ceiling_building_share else Kind.OVERPASS


func _mesh(size: Vector3, seams: Array[float], kind: Kind, deco: int, anchored_left: bool, anchored_right: bool,
		base_y: float) -> ArrayMesh:
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(skin.solid_material())
	var g: MeshLayer = batch.layer(skin.glow_material())
	var xa: float = -size.x * 0.5 - (WALL_EMBED if anchored_left else FREE_LIP)
	var xb: float = size.x * 0.5 + (WALL_EMBED if anchored_right else FREE_LIP)
	var zn: float = size.z * 0.5
	var zf: float = -size.z * 0.5
	_underside(s, g, xa, xb, zn, zf, seams, kind)
	MeshKit.ceiling_end(s, g, (xb - xa) * 0.5, zf, STERN_BAND, skin.gap_edge_color, (xa + xb) * 0.5)
	if kind == Kind.OVERPASS:
		_overpass(s, g, batch.layer(skin.feed_material()), xa, xb, zn, zf, size.x, deco, anchored_left, anchored_right)
	else:
		_building(batch.layer(skin.facade_material()), s, xa, xb, zn, zf, size.x, deco, anchored_left, anchored_right,
			base_y)
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
