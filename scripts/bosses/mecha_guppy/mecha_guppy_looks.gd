class_name MechaGuppyLooks
extends RefCounted
## The climb's look (GDD §10, Mecha Guppy and Captain Cogs: tiki huts as the ceilings, tiki bar roofs as the floors
## the runner climbs onto, a few neon signs as scenery only; task E5e-b1), in the Beach's materials and colours
## (BeachSkin: the kit's solid and glow shaders and their Beach patterns). Visual only: MechaGuppyStairs owns every
## collision shape, and each look follows the collision it dresses exactly where a runner can meet it.
## The climb has to read as climbing high (the owner's idea): every roof tops a tower that stands all the way down to
## the water, and Mecha Guppy has eaten a chasm between one tower and the next, so from the pads, the hut and the
## roof ahead the runner looks down a long drop.
## - A tower (a roof): a tiki bar's flat roof deck of weathered boardwalk planks over its lanes (the seams between
##   lanes, a bamboo kerb out to the edge on the outer lanes), the orange edge language of every zone where it ends
##   (the front a rider drops onto faces them with a halo; the edge Mecha Guppy has eaten it from), thatch eaves and
##   warm lantern posts on its kerbs, outside the lanes; below the deck, storey after storey of tiki bar down to the
##   water: bamboo and plank faces (the Beach's wall pattern), a ledge and a row of lit windows on each storey, the
##   storeys darkening the deeper they are (DEEP_COLOR over DEEP_FADE metres), so the drop reads at any height;
##   drawn no deeper than TOWER_DEPTH under the deck (the haze hides anything deeper), so a long climb's meshes stop
##   growing.
## - A pier (REACH_BACK: the roof's lanes that lead up reach back under the hut's end): those lanes' deck out in front
##   of the tower, its front a lantern-lit landing stage with the orange lip and the open framework of a pier below,
##   posts and braces on tall stilts down to the water, so it reads as a place to land, not a wall; its sides over
##   the gap beside it carry the orange lip too.
## - The chasm between towers (the floor Mecha Guppy has eaten; the shark, MechaGuppyShark, rises in it and bites the
##   roofs' ends into it): nothing but the drop to the water far below, the street's own (MechaGuppySkin), where a
##   fall ends.
## - The bait's notch (task E5e-b3: an outer lane Mecha Guppy has eaten near a roof's end, MechaGuppyClimb.Roof.
##   notch_lane): that lane's deck ends with the orange edge language of an eaten edge; past it the tower's corner is
##   gone down to the water, its eaten face dark broken timber along the notch's inner side and across its start, the
##   orange lip along the deck's edge over the drop (as a pier's open sides), no eave or lantern posts on that side.
## - Mecha Guppy's floor bite, once eaten (task E5e-f; MechaGuppyCrescent): the deck clipped along the bite's edge, exactly
##   its polyline (the collision's: MechaGuppyStairs), the planks running on unbroken past it; the eaten edge's orange
##   lip and steel coping along the scalloped edge on the deck, the glowing strip on its face and the dark broken face
##   down to the water; no tower wall, eave or lantern posts along the bitten side over it (nor the far side where a
##   full-width bite cuts through).
## - A hut: a plank platform hovering on four violet-blue lift pods outside the lanes, its underside one surface
##   across its lanes with flush joists, a dark seam and a warm lamp row along each lane seam (and along each run of
##   lanes' edge, so the lanes that lead up visibly run on, lit, past the others: RUN_ON), the orange band of every
##   zone at each lane's end (where a rider drops), long enough to read from the hut's start; on its full-width part a
##   row of tiki huts (bamboo walls with a lamp-lit bar opening at each end, corner posts, a steep thatched hip roof)
##   between bamboo rails, and over the lanes that run further an annex of its own: a lower bamboo walkway under a
##   thatch canopy.
## - The pads: each lane's strip a row of anti-grav pad tiles end to end in the zone's pad cyan, as long as its
##   trigger, with short light columns (a full one would stand like a wall along the lane).
## - A few neon signs (wordless silhouettes in the Beach's violet, blue and warm white: GDD §5's colour rule) on
##   some fronts and huts, facing the runner, never in a lane above a floor.
## DESIGN-TBD: the towers, the pier, the chasm and the huts' look (docs/questions/e5e.md).
## Variety comes from hashing the step's index, so a step looks the same on every attempt.

## The edge language (BeachSand's): an orange lip on the floor's last metres, a steel coping, a strip on the wall.
const EDGE_LIP: float = 0.18
const LIP_GLOW: float = 0.42
const COPING: float = 0.28
const STRIP_HEIGHT: float = 0.1
const STRIP_GLOW: float = 0.6
const EDGE_HALO: float = 0.35
## A tower's storeys below its deck: this tall, a ledge this tall standing this far out (well inside the plan's
## fall_margin: a falling runner never meets it), a lit window this wide and tall about every WINDOW_SPACING.
const STOREY: float = 3.0
const LEDGE: float = 0.18
const LEDGE_OUT: float = 0.12
const WINDOW_W: float = 0.8
const WINDOW_H: float = 1.0
const WINDOW_SPACING: float = 3.2
const WINDOW_GLOW: float = 0.12
## The deeper a storey, the darker: toward this colour, all but DEEP_MOST of the way DEEP_FADE metres down.
const DEEP_COLOR := Color(0.045, 0.05, 0.075)
const DEEP_FADE: float = 42.0
const DEEP_MOST: float = 0.88
## A floor bite's broken face fades the other way, into the sea haze, BITE_HAZE_MOST of the way by BITE_HAZE metres down
## (_bite_deep): a trench seen from over it reads as a drop, not a slab.
const BITE_HAZE: float = 18.0
const BITE_HAZE_MOST: float = 0.8
## A tower (its walls, an eaten face, a pier's stilts) is drawn at most this far below its deck (metres): deeper,
## the arena's haze hides it from every view the climb has (MechaGuppySkin: fully fogged 200 m from the camera; the
## run camera rides at most about 5 m over a deck and sees at most half its widest fov, 42°, off its axis, so a
## point 270 m under it is past that), and the climb's meshes stop growing once it is this high (below, the towers
## reach the water).
const TOWER_DEPTH: float = 300.0
## The pier: its deck's front fascia this deep, stilts about this far apart, braces every PIER_BRACE metres down.
const PIER_FASCIA: float = 0.7
const PIER_STILT: float = 2.4
const PIER_BRACE: float = 6.0
const PIER_LAMP_SPACING: float = 2.2
## The hut: its floor (the collision box's thickness, TrackBuilder.HULL_THICKNESS), walls and roof over it, how far
## its body reaches past the lanes on each side, its lift pods.
const HUT_FLOOR: float = 0.8
const HUT_WALL: float = 2.3
const HUT_ROOF: float = 2.8
## Each tiki hut on the platform is about this long, this far from the next.
const HUT_LENGTH: float = 8.0
const HUT_GAP: float = 3.5
const HUT_OVERHANG: float = 0.7
const ANNEX_WALL: float = 1.2
const ANNEX_ROOF: float = 0.8
const POD_RADIUS: float = 0.35
## The orange band at each lane's end on a hut's underside (the end band every ceiling has, MeshKit.ceiling_end's
## look): long and bright, so it reads from the hut's start (task E5e-b1's review: at 1.2 m it was a sliver until
## about 0.8 s before the end; seen from below at a grazing angle, its length is what shows). Its brightness is a glow
## card over it (END_BAND_CARD) that fades out as the camera comes within END_BAND_NEAR (MeshKit.near_fade), the band
## itself barely glowing (END_BAND_GLOW): the chase camera passes just under it as a rider drops, and the band glowing
## solid filled up to a quarter of the screen with bright orange (task E5e-f's review).
const END_BAND: float = 4.0
const END_BAND_GLOW: float = 0.06
const END_BAND_CARD: float = 0.55
const END_BAND_NEAR: float = 10.0
## The band hangs this far under the hut's underside: below a rider's blob shadow there (Player._update_shadow lays it
## 0.02 m under a ceiling), so it hides the shadow rather than being darkened by it.
const SHADOW_UNDER: float = 0.03
const LAMP_SPACING: float = 6.0
## The pad tiles: about this long each, with light columns this tall.
const PAD_TILE: float = 2.6
const PAD_BEAM: float = 2.2
## A roof's thatch eave reaches this far out past its edge, this far down.
const EAVE_REACH: float = 1.7
const EAVE_DROP: float = 1.3
## Lantern posts along a roof's outer edges: this far apart, this tall.
const LANTERN_SPACING: float = 7.0
const LANTERN_HEIGHT: float = 1.5
## A neon board's size.
const SIGN_W: float = 2.6
const SIGN_H: float = 1.8

## Weak: the skin owns its materials (as BeachSand does).
var skin: BeachSkin:
	get:
		return _skin.get_ref() as BeachSkin
var geo: TrackGeometry
var movement: MovementTuning
var _skin: WeakRef
var _tiles: Dictionary = {}


func _init(p_skin: BeachSkin, p_geo: TrackGeometry, p_movement: MovementTuning) -> void:
	_skin = weakref(p_skin)
	geo = p_geo
	movement = p_movement


## Where a tower whose deck is at `top` ends below: the water under the street (the chasms' floor, MechaGuppySkin),
## or TOWER_DEPTH under its deck, where the haze has long hidden it.
## DESIGN-TBD: the chasm, open down to the street's own water, is the floor Mecha Guppy has eaten; its bites
## (MechaGuppyShark) eat each roof's end into it (docs/questions/e5e.md).
func bottom(top: float) -> float:
	return maxf(-skin.pool_depth, top - TOWER_DEPTH)


# --- Roofs -----------------------------------------------------------------------------------------

## Roof `r`'s front pieces (built once): the pier under each run of its lanes that reaches back (REACH_BACK), from its
## start to where the roof is full width (`r.full_from()`), and the tower's facade where the other lanes start, down
## to the water storey by storey, a neon sign on some. `into` is the step that led onto it (null for the street).
func roof_front(r: MechaGuppyClimb.Roof, into: MechaGuppyClimb.Step) -> Node3D:
	var node := Node3D.new()
	node.name = "RoofFront%d" % r.index
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(skin.solid_material())
	var g: MeshLayer = batch.layer(skin.glow_material())
	var seed: int = MeshKit.hash_i(r.index, 41)
	var bamboo: Color = skin.bamboo_colors[seed % skin.bamboo_colors.size()]
	var full: float = r.full_from()
	var widest: Dictionary = {}
	for run: Dictionary in MechaGuppyStairs.runs(r.starts):
		var lanes: Vector2i = run["lanes"]
		var start: float = float(run["start"])
		var x0: float = geo.lane_floor_span(lanes.x).x
		var x1: float = geo.lane_floor_span(lanes.y).y
		if start < full - 0.01:
			_pier(s, g, r, lanes, start, full, seed)
		else:
			_tower_face(s, g, x0, x1, start, r.top, bamboo, seed)
			if widest.is_empty() or lanes.y - lanes.x > int(widest["count"]):
				widest = {"count": lanes.y - lanes.x, "lanes": lanes, "start": start}
	if not widest.is_empty() and MeshKit.hash01(r.index, 7, 3) < 0.4:
		var wl: Vector2i = widest["lanes"]
		_sign(s, g, (geo.lane_x(wl.x) + geo.lane_x(wl.y)) * 0.5, float(widest["start"]), r.top - 1.5, r.index)
	batch.commit(node)
	return node


## A full-width piece of roof `r` from track distance `from` to `to`: its deck across every lane (the orange lip at
## the front of the lanes that start here, and at the end where Mecha Guppy has eaten it: `ended`), the tower's outer
## walls down to the water with thatch eaves and lantern posts on its kerbs, its broken face over the chasm where
## it ends; roof 0, the street the fight starts on: the Beach's own street (BeachSand), its pool edge where it's
## eaten.
func roof_segment(r: MechaGuppyClimb.Roof, from: float, to: float, ended: bool) -> Node3D:
	var node := Node3D.new()
	node.name = "Roof%dPiece" % r.index
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(skin.solid_material())
	var g: MeshLayer = batch.layer(skin.glow_material())
	if r.index == 0:
		for lane: int in geo.lane_count:
			var fs: Vector2 = geo.lane_floor_span(lane)
			skin.sand().build(batch, Vector3((fs.x + fs.y) * 0.5, -0.5, -(from + to) * 0.5),
				Vector3(fs.y - fs.x, 1.0, to - from), geo.lane_x(lane), false, ended)
		batch.commit(node)
		return node
	var seed: int = MeshKit.hash_i(r.index, 41)
	var bamboo: Color = skin.bamboo_colors[seed % skin.bamboo_colors.size()]
	var full: float = r.full_from()
	# Past its notch's start (MechaGuppyStairs builds a piece wholly before it or wholly past it), the notch's lane is gone.
	var notched: bool = r.notched() and from >= r.notch_from - 0.01
	var notch_side: int = r.notch_side()
	var starts := PackedFloat32Array()
	starts.resize(geo.lane_count)
	starts.fill(minf(from, full) - 1.0)
	if notched:
		starts[r.notch_lane] = MechaGuppyClimb.FAR
	# Its floor bite, once eaten, where it crosses this piece (never past the notch's start: it comes before it).
	var bite: MechaGuppyCrescent = r.bite
	if bite == null or not bite.eaten or bite.skipped or notched or bite.to <= from + 0.01 or bite.from >= to - 0.01:
		bite = null
	for lane: int in geo.lane_count:
		if notched and lane == r.notch_lane:
			continue
		var front: bool = from <= full + 0.01 and r.start_in(lane) >= full - 0.01
		# The notch's lane ends where it was eaten, with the eaten edge's orange.
		var back: bool = ended or (lane == r.notch_lane and absf(to - r.notch_from) < 0.01)
		if bite != null:
			_deck_bitten(s, g, lane, from, to, r.top, front, back, starts, bite)
		else:
			_deck(s, g, lane, from, to, r.top, front, back, starts)
	var x0: float = -geo.wall_x()
	var x1: float = geo.wall_x()
	for side: int in [-1, 1]:
		if notched and side == notch_side:
			var inner: float = notch_inner(r)
			_broken_side(s, inner, side, from, to, r.top)
			_side_lip(s, inner, side, from, to, r.top)
			if side < 0:
				x0 = inner
			else:
				x1 = inner
			continue
		# The tower's side, its eave and its lanterns, but where the floor bite took them.
		var spans: Array[Vector2] = [Vector2(from, to)]
		if bite != null and side == bite.side:
			spans = _without(from, to, bite.from, bite.to)
		elif bite != null and bite.cut_from < bite.cut_to:
			spans = _without(from, to, bite.cut_from, bite.cut_to)
		for span: Vector2 in spans:
			_tower_side(s, side * geo.wall_x(), side, span.x, span.y, r.top, bamboo, seed)
			_eave(s, side, span.x, span.y, r.top)
			_lanterns(s, g, side, span.x, span.y, r.top, seed)
	# Across the notch's start: the eaten face, facing on into the notch.
	if notched and absf(from - r.notch_from) < 0.01:
		var inner_x: float = notch_inner(r)
		_broken_face(s, from, r.top, minf(inner_x, notch_side * geo.wall_x()), maxf(inner_x, notch_side * geo.wall_x()))
	if bite != null:
		_bite_edge(s, bite, from, to, r.top)
	if ended:
		_broken_face(s, to, r.top, x0, x1)
	batch.commit(node)
	return node


## The floor held over a floor bite's gap under a runner who blocked its snap (task E5e-f, MechaGuppyFloorBite; FloorCut's
## held floor's rule), over world x [x0, x1] from track distance `from` to `to`, its top at `top`: the deck's planks with the
## eaten edge's orange lip round it and a dark slab under it, until it goes all at once. DESIGN-TBD (docs/questions/e5e.md).
func held_floor(x0: float, x1: float, from: float, to: float, top: float) -> Node3D:
	var node := Node3D.new()
	node.name = "HeldFloor"
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(skin.solid_material())
	var length: float = to - from
	s.rect(Vector3(x0, top, -from), Vector3(x1 - x0, 0, 0), Vector3(0, 0, -length), skin.boardwalk_color, 0.0,
		MeshKit.PAT_BEACH_BOARDWALK, Vector2(-1.0, 0.0), Vector2(1.0, length), MeshKit.sand_param(0, length, 3))
	var edge: Color = skin.gap_edge_color
	for x: float in [x0, x1 - EDGE_LIP]:
		s.rect(Vector3(x, top + 0.004, -from), Vector3(EDGE_LIP, 0, 0), Vector3(0, 0, -length), edge, LIP_GLOW)
	for d: float in [from, to - EDGE_LIP]:
		s.rect(Vector3(x0, top + 0.004, -d), Vector3(x1 - x0, 0, 0), Vector3(0, 0, -EDGE_LIP), edge, LIP_GLOW)
	s.box(Vector3((x0 + x1) * 0.5, top - 0.26, -(from + to) * 0.5), Vector3(x1 - x0, 0.5, length), skin.timber_color * 0.5, 0.0,
		MeshKit.PAT_BEACH_TIMBER, MeshKit.ALL_FACES & ~MeshKit.FACE_PY, MeshKit.beach_timber_param(2, 1, 3))
	batch.commit(node)
	return node


## [from, to] less [cut0, cut1]: the spans left (none, one or two).
static func _without(from: float, to: float, cut0: float, cut1: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if cut0 > from + 0.01:
		out.append(Vector2(from, minf(cut0, to)))
	if cut1 < to - 0.01:
		out.append(Vector2(maxf(cut1, from), to))
	return out


## World x of the inner edge of roof `r`'s notch (its lane's side toward the track's middle), or 0 with none.
func notch_inner(r: MechaGuppyClimb.Roof) -> float:
	if not r.notched():
		return 0.0
	return geo.lane_x(r.notch_lane) - float(r.notch_side()) * geo.lane_width * 0.5


## One lane's deck from `start` to `end` at height `top`: boardwalk planks, a seam where a neighbouring lane's deck
## runs beside it (`starts`: the roof's lane starts), the kerb out to the edge on an outer lane, and the orange
## edge language at its front (`front`: a drop onto it, with the halo facing the runner) and its eaten edge (`back`).
func _deck(s: MeshLayer, g: MeshLayer, lane: int, start: float, end: float, top: float, front: bool, back: bool,
		starts: PackedFloat32Array) -> void:
	var span: Vector2 = geo.lane_floor_span(lane)
	var l0: float = geo.lane_x(lane) - geo.lane_width * 0.5
	var l1: float = geo.lane_x(lane) + geo.lane_width * 0.5
	var lip_n: float = EDGE_LIP if front else 0.0
	var cope_n: float = COPING if front else 0.0
	var lip_f: float = EDGE_LIP if back else 0.0
	var cope_f: float = COPING if back else 0.0
	var a: float = start + lip_n + cope_n
	var b: float = end - lip_f - cope_f
	var key: int = MeshKit.key(geo.lane_x(lane))
	var lane_hash: int = MeshKit.hash_i(key, 9)
	var flags: int = 0
	if lane > 0 and starts[lane - 1] <= start + 0.01:
		flags |= MeshKit.BEACH_SEAM_LEFT
	if lane < geo.lane_count - 1 and starts[lane + 1] <= start + 0.01:
		flags |= MeshKit.BEACH_SEAM_RIGHT
	if lane_hash & 64:
		flags |= MeshKit.BEACH_ALT_TONE
	if b > a:
		s.rect(Vector3(l0, top, -a), Vector3(l1 - l0, 0, 0), Vector3(0, 0, -(b - a)), skin.boardwalk_color, 0.0,
			MeshKit.PAT_BEACH_BOARDWALK, Vector2(-1.0, 0.0), Vector2(1.0, b - a), MeshKit.sand_param(flags, b - a, lane_hash))
		# The bamboo kerb out to the edge on an outer lane.
		if span.x < l0 - 0.01:
			s.rect(Vector3(span.x, top, -a), Vector3(l0 - span.x, 0, 0), Vector3(0, 0, -(b - a)), skin.kerb_color, 0.0,
				MeshKit.PAT_BEACH_TIMBER, Vector2.ZERO, Vector2.ONE, MeshKit.beach_timber_param(2, 0, 7))
		if span.y > l1 + 0.01:
			s.rect(Vector3(l1, top, -a), Vector3(span.y - l1, 0, 0), Vector3(0, 0, -(b - a)), skin.kerb_color, 0.0,
				MeshKit.PAT_BEACH_TIMBER, Vector2.ZERO, Vector2.ONE, MeshKit.beach_timber_param(2, 0, 7))
	var w: float = span.y - span.x
	var edge: Color = skin.gap_edge_color
	if front:
		s.rect(Vector3(span.x, top, -start), Vector3(w, 0, 0), Vector3(0, 0, -lip_n), edge, LIP_GLOW)
		s.rect(Vector3(span.x, top, -start - lip_n), Vector3(w, 0, 0), Vector3(0, 0, -cope_n), skin.coping_color)
		s.rect(Vector3(span.x, top - 0.02 - STRIP_HEIGHT, -start + 0.004), Vector3(w, 0, 0), Vector3(0, STRIP_HEIGHT, 0), edge,
			STRIP_GLOW)
		g.rect(Vector3(span.x - 0.15, top - 0.37, -start + 0.05), Vector3(w + 0.3, 0, 0), Vector3(0, 0.6, 0), edge, EDGE_HALO,
			MeshKit.SHAPE_STREAK)
	if back:
		s.rect(Vector3(span.x, top, -end + lip_f), Vector3(w, 0, 0), Vector3(0, 0, -lip_f), edge, LIP_GLOW)
		s.rect(Vector3(span.x, top, -end + lip_f + cope_f), Vector3(w, 0, 0), Vector3(0, 0, -cope_f), skin.coping_color)
		s.rect(Vector3(span.y, top - 0.02 - STRIP_HEIGHT, -end - 0.004), Vector3(-w, 0, 0), Vector3(0, STRIP_HEIGHT, 0), edge,
			STRIP_GLOW)


## One lane's deck from `start` to `end` as _deck draws it, with floor bite `bite` (eaten) bitten out of it: the planks and
## the kerb run on with the same pattern either side of the bite, and over it each stretch of the bite's edge clips them
## (the floor on the edge's far side from the bitten wall: exactly the collision's pieces, MechaGuppyStairs._bitten_floor).
func _deck_bitten(s: MeshLayer, g: MeshLayer, lane: int, start: float, end: float, top: float, front: bool, back: bool,
		starts: PackedFloat32Array, bite: MechaGuppyCrescent) -> void:
	var span: Vector2 = geo.lane_floor_span(lane)
	var l0: float = geo.lane_x(lane) - geo.lane_width * 0.5
	var l1: float = geo.lane_x(lane) + geo.lane_width * 0.5
	var a: float = start + ((EDGE_LIP + COPING) if front else 0.0)
	var b: float = end - ((EDGE_LIP + COPING) if back else 0.0)
	if b <= a:
		return
	var key: int = MeshKit.key(geo.lane_x(lane))
	var lane_hash: int = MeshKit.hash_i(key, 9)
	var flags: int = 0
	if lane > 0 and starts[lane - 1] <= start + 0.01:
		flags |= MeshKit.BEACH_SEAM_LEFT
	if lane < geo.lane_count - 1 and starts[lane + 1] <= start + 0.01:
		flags |= MeshKit.BEACH_SEAM_RIGHT
	if lane_hash & 64:
		flags |= MeshKit.BEACH_ALT_TONE
	var plank_param: float = MeshKit.sand_param(flags, b - a, lane_hash)
	var kerb_param: float = MeshKit.beach_timber_param(2, 0, 7)
	# The strips: the planks over the lane, the kerb out to the edge on an outer lane: [x0, x1, kerb?].
	var strips: Array[Vector3] = [Vector3(l0, l1, 0.0)]
	if span.x < l0 - 0.01:
		strips.append(Vector3(span.x, l0, 1.0))
	if span.y > l1 + 0.01:
		strips.append(Vector3(l1, span.y, 1.0))
	var pts: PackedVector2Array = bite.edge(a, b)
	for strip: Vector3 in strips:
		var kerb: bool = strip.z > 0.5
		var color: Color = skin.kerb_color if kerb else skin.boardwalk_color
		var pattern: int = MeshKit.PAT_BEACH_TIMBER if kerb else MeshKit.PAT_BEACH_BOARDWALK
		var param: float = kerb_param if kerb else plank_param
		var uv: Callable = func(p: Vector2) -> Vector2:
			if kerb:
				return Vector2((p.x - strip.x) / maxf(strip.y - strip.x, 0.001), (p.y - a) / (b - a))
			return Vector2(lerpf(-1.0, 1.0, (p.x - strip.x) / maxf(strip.y - strip.x, 0.001)), p.y - a)
		# Before the bite and past it, whole; over it, clipped stretch by stretch of its edge.
		for part: Vector2 in [Vector2(a, minf(b, bite.from)), Vector2(maxf(a, bite.to), b)]:
			if part.y - part.x > 0.001:
				_floor_poly(s, PackedVector2Array([Vector2(strip.x, part.x), Vector2(strip.x, part.y), Vector2(strip.y, part.y),
					Vector2(strip.y, part.x)]), top, color, pattern, param, uv)
		for i: int in pts.size() - 1:
			if pts[i + 1].y - pts[i].y < 0.0005:
				continue
			_floor_poly(s, _clip_floor(strip.x, strip.y, pts[i].y, pts[i + 1].y, pts[i], pts[i + 1], bite.side), top, color,
				pattern, param, uv)
	# The orange edge language at its front and its eaten end, as _deck draws it.
	var w: float = span.y - span.x
	var edge: Color = skin.gap_edge_color
	if front:
		s.rect(Vector3(span.x, top, -start), Vector3(w, 0, 0), Vector3(0, 0, -EDGE_LIP), edge, LIP_GLOW)
		s.rect(Vector3(span.x, top, -start - EDGE_LIP), Vector3(w, 0, 0), Vector3(0, 0, -COPING), skin.coping_color)
		s.rect(Vector3(span.x, top - 0.02 - STRIP_HEIGHT, -start + 0.004), Vector3(w, 0, 0), Vector3(0, STRIP_HEIGHT, 0), edge,
			STRIP_GLOW)
		g.rect(Vector3(span.x - 0.15, top - 0.37, -start + 0.05), Vector3(w + 0.3, 0, 0), Vector3(0, 0.6, 0), edge, EDGE_HALO,
			MeshKit.SHAPE_STREAK)
	if back:
		s.rect(Vector3(span.x, top, -end + EDGE_LIP), Vector3(w, 0, 0), Vector3(0, 0, -EDGE_LIP), edge, LIP_GLOW)
		s.rect(Vector3(span.x, top, -end + EDGE_LIP + COPING), Vector3(w, 0, 0), Vector3(0, 0, -COPING), skin.coping_color)
		s.rect(Vector3(span.y, top - 0.02 - STRIP_HEIGHT, -end - 0.004), Vector3(-w, 0, 0), Vector3(0, STRIP_HEIGHT, 0), edge,
			STRIP_GLOW)


## The part of the rectangle [x0, x1] × [d0, d1] (world x, track distance) on the floor's side of a floor bite's edge from
## `p` to `q` (Vector2(x, d), d rising) for a bite from `side`: a convex polygon wound as rect() winds a floor, or fewer
## than three points where it's all in the gap.
static func _clip_floor(x0: float, x1: float, d0: float, d1: float, p: Vector2, q: Vector2, side: int) -> PackedVector2Array:
	var poly := PackedVector2Array([Vector2(x0, d0), Vector2(x0, d1), Vector2(x1, d1), Vector2(x1, d0)])
	var out := PackedVector2Array()
	for i: int in poly.size():
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		var fa: float = _floor_side(a, p, q, side)
		var fb: float = _floor_side(b, p, q, side)
		if fa >= 0.0:
			out.append(a)
		if (fa >= 0.0) != (fb >= 0.0):
			out.append(a.lerp(b, fa / (fa - fb)))
	return out


## How far point `v` (Vector2(x, d)) is past a floor bite's edge from `p` to `q` on the floor's side (the far side from
## the bitten wall `side`), across the track: negative in the gap.
static func _floor_side(v: Vector2, p: Vector2, q: Vector2, side: int) -> float:
	var k: float = (v.y - p.y) / (q.y - p.y) if q.y - p.y > 0.0001 else 0.0
	return -float(side) * (v.x - lerpf(p.x, q.x, k))


## A convex polygon of floor at height `top` (Vector2(x, d) corners, wound as rect() winds a floor), UV from `uv`.
func _floor_poly(s: MeshLayer, pts: PackedVector2Array, top: float, color: Color, pattern: int, param: float,
		uv: Callable) -> void:
	if pts.size() < 3:
		return
	var v: Array[Vector3] = []
	var t: Array[Vector2] = []
	for p: Vector2 in pts:
		v.append(Vector3(p.x, top, -p.y))
		t.append(uv.call(p))
	var i: int = 1
	while i < pts.size() - 1:
		var last: int = mini(i + 2, pts.size() - 1)
		s.quad_uv(v[0], v[i], v[i + 1], v[last], t[0], t[i], t[i + 1], t[last], color, 0.0, pattern, param)
		i += 2


## Floor bite `bite`'s eaten edge over track distances [from, to], on a deck at `top`: the orange lip and the steel coping
## on the deck along its scalloped edge (into the floor from it), the glowing strip on its face just under the deck, and
## the broken face of the eaten tower down to the water, its dark timber fading into the sea haze the deeper it goes
## (_bite_deep: task E5e-f's review, seen from over a full-width trench a face darkening with depth read as a dark slab;
## the haze reads as the drop). None along the far wall where a full-width bite cuts the whole floor.
func _bite_edge(s: MeshLayer, bite: MechaGuppyCrescent, from: float, to: float, top: float) -> void:
	var pts: PackedVector2Array = bite.edge(maxf(from, bite.from), minf(to, bite.to))
	var n: int = pts.size()
	if n < 2:
		return
	var far: float = -float(bite.side) * bite.wall
	# Each point's normal into the floor (across the track and along it), averaged between its two stretches.
	var normals := PackedVector2Array()
	normals.resize(n)
	for i: int in n:
		var acc := Vector2.ZERO
		for j: int in [i - 1, i]:
			if j < 0 or j >= n - 1:
				continue
			var t: Vector2 = pts[j + 1] - pts[j]
			if t.length() > 0.0001:
				acc += Vector2(-float(bite.side) * t.y, float(bite.side) * t.x).normalized()
		normals[i] = acc.normalized() if acc.length() > 0.0001 else Vector2(-float(bite.side), 0.0)
	var y_low: float = bottom(top)
	var y_strip: float = top - 0.02 - STRIP_HEIGHT
	var layers: Array[float] = [y_strip, top - 1.5, top - 3.5, top - 6.0, top - 9.0, top - 13.0, top - 18.0, top - 30.0,
		top - 48.0, y_low]
	var param: float = MeshKit.beach_timber_param(2, 1, 3)
	for i: int in n - 1:
		var p: Vector2 = pts[i]
		var q: Vector2 = pts[i + 1]
		if q.y - p.y < 0.0005 or (absf(p.x - far) < 0.001 and absf(q.x - far) < 0.001):
			continue
		var np: Vector2 = normals[i]
		var nq: Vector2 = normals[i + 1]
		var gap := Vector3(-(np.x + nq.x), 0.0, np.y + nq.y)
		_band(s, p, q, np, nq, 0.0, EDGE_LIP, top + 0.004, skin.gap_edge_color, LIP_GLOW)
		_band(s, p, q, np, nq, EDGE_LIP, EDGE_LIP + COPING, top + 0.004, skin.coping_color, 0.0)
		_wall_quad(s, p, q, y_strip, top - 0.02, gap, skin.gap_edge_color, STRIP_GLOW, MeshKit.PAT_PLAIN, 0.0)
		for k: int in layers.size() - 1:
			var y1: float = layers[k]
			var y0: float = maxf(layers[k + 1], y_low)
			if y1 <= y0 + 0.01:
				continue
			_wall_quad(s, p, q, y0, y1, gap, _bite_deep(top - (y0 + y1) * 0.5), 0.0, MeshKit.PAT_BEACH_TIMBER,
				param)


## A band on the deck at height `y` along the edge from `p` to `q` (Vector2(x, d)), from `w0` to `w1` in along their
## normals `np`, `nq` (into the floor), facing up.
func _band(s: MeshLayer, p: Vector2, q: Vector2, np: Vector2, nq: Vector2, w0: float, w1: float, y: float, color: Color,
		glow: float) -> void:
	var a := Vector3(p.x + np.x * w0, y, -(p.y + np.y * w0))
	var b := Vector3(q.x + nq.x * w0, y, -(q.y + nq.y * w0))
	var c := Vector3(q.x + nq.x * w1, y, -(q.y + nq.y * w1))
	var d := Vector3(p.x + np.x * w1, y, -(p.y + np.y * w1))
	_quad_out(s, a, b, c, d, Vector3.UP, color, glow, MeshKit.PAT_PLAIN, 0.0)


## An upright face along the edge from `p` to `q` (Vector2(x, d)) from height `y0` to `y1`, facing `outward`.
func _wall_quad(s: MeshLayer, p: Vector2, q: Vector2, y0: float, y1: float, outward: Vector3, color: Color, glow: float,
		pattern: int, param: float) -> void:
	_quad_out(s, Vector3(p.x, y1, -p.y), Vector3(q.x, y1, -q.y), Vector3(q.x, y0, -q.y), Vector3(p.x, y0, -p.y), outward, color,
		glow, pattern, param)


## A four-cornered patch (corners in order round it) wound to face `outward`.
static func _quad_out(layer: MeshLayer, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3, color: Color,
		glow: float, pattern: int, param: float) -> void:
	if (b - a).cross(c - a).dot(outward) > 0.0:
		layer.quad(a, d, c, b, color, glow, pattern, param)
	else:
		layer.quad(a, b, c, d, color, glow, pattern, param)


## A floor bite's broken face `depth` metres under the deck (see _bite_edge): the tower's dark timber, fading toward the sea
## haze, BITE_HAZE_MOST of the way BITE_HAZE metres down.
func _bite_deep(depth: float) -> Color:
	return (skin.timber_color * 0.45).lerp(skin.fog_color, clampf(depth / BITE_HAZE, 0.0, 1.0) * BITE_HAZE_MOST)


## The colour `base` takes `depth` metres under a deck: darker the deeper it is, as light fails down a chasm.
static func deep(base: Color, depth: float) -> Color:
	return base.lerp(DEEP_COLOR, clampf(depth / DEEP_FADE, 0.0, 1.0) * DEEP_MOST)


## A tower's facade across the track over [x0, x1] at track distance `d`, facing the runner (+z), from its deck at
## `top` down to the water: the tiki bar's own bamboo front under the deck, then storey after storey (a ledge, a
## plank or bamboo face, a row of warm windows), darker the deeper.
func _tower_face(s: MeshLayer, g: MeshLayer, x0: float, x1: float, d: float, top: float, bamboo: Color, seed: int) -> void:
	var z: float = -d
	var y_low: float = bottom(top)
	var y: float = top
	var n: int = 0
	while y > y_low + 0.01:
		var y0: float = maxf(y - STOREY, y_low)
		var depth: float = top - (y + y0) * 0.5
		var tone: Color = deep(bamboo if n % 2 == 0 else bamboo * 0.86, depth)
		var pattern: int = MeshKit.PAT_BEACH_WALL if n % 3 != 2 else MeshKit.PAT_BEACH_TIMBER
		var param: float = float(((seed + n * 7) % 1000) * 8) if pattern == MeshKit.PAT_BEACH_WALL \
			else MeshKit.beach_timber_param(1, n % 2, seed + n)
		s.rect(Vector3(x0, y0, z), Vector3(x1 - x0, 0, 0), Vector3(0, y - y0, 0), tone, 0.0, pattern, Vector2.ZERO, Vector2.ONE,
			param)
		if n > 0:
			# The ledge at the storey's top, and its windows (fewer lit the deeper it is).
			s.box(Vector3((x0 + x1) * 0.5, y - LEDGE * 0.5, z + LEDGE_OUT * 0.5), Vector3(x1 - x0, LEDGE, LEDGE_OUT),
				deep(skin.timber_color * 0.7, depth), 0.0, MeshKit.PAT_PLAIN, MeshKit.ALL_FACES & ~MeshKit.FACE_NZ)
			_windows(s, g, x0, x1, z + 0.01, y - 0.55 - WINDOW_H, depth, seed + n * 13, 1.0)
		y = y0
		n += 1


## A row of windows across [x0, x1] on a face at world z `z` facing +z (`facing` 1) or -z (-1), their bottoms at
## `y`: dark openings, most of them lit warm (fewer, and dimmer, the deeper they are).
func _windows(s: MeshLayer, g: MeshLayer, x0: float, x1: float, z: float, y: float, depth: float, seed: int,
		facing: float) -> void:
	var count: int = floori((x1 - x0) / WINDOW_SPACING)
	if count <= 0:
		return
	var pitch: float = (x1 - x0) / float(count)
	var fade: float = clampf(depth / DEEP_FADE, 0.0, 1.0)
	for i: int in count:
		var cx: float = x0 + pitch * (float(i) + 0.5)
		var lit: bool = MeshKit.hash01(seed, i, 5) < 0.6 - 0.25 * fade
		var frame := Vector3(cx - (WINDOW_W * 0.5 + 0.12) * facing, y - 0.12, z)
		s.rect(frame, Vector3((WINDOW_W + 0.24) * facing, 0, 0), Vector3(0, WINDOW_H + 0.24, 0), deep(skin.post_color * 0.55, depth))
		var color: Color = (skin.lamp_color * 0.8).lerp(DEEP_COLOR, 0.4 * fade) if lit else deep(skin.thatch_dark_color * 0.4, depth)
		var a := Vector3(cx - WINDOW_W * 0.5 * facing, y, z + 0.004 * facing)
		s.rect(a, Vector3(WINDOW_W * facing, 0, 0), Vector3(0, WINDOW_H, 0), color, WINDOW_GLOW * (1.0 - 0.5 * fade) if lit else 0.0)


## A tower's outer wall at world x `x`, facing `side` (-1 left, +1 right, outward), from track distance `from` to
## `to`, from its deck at `top` down to the water: storey after storey, darker the deeper (seen from beside the
## climb; from the runner's lanes the deck hides it).
func _tower_side(s: MeshLayer, x: float, side: int, from: float, to: float, top: float, bamboo: Color, seed: int) -> void:
	var y_low: float = bottom(top)
	var y: float = top
	var n: int = 0
	while y > y_low + 0.01 and to > from:
		var y0: float = maxf(y - STOREY, y_low)
		var tone: Color = deep(bamboo * (0.9 if n % 2 == 0 else 0.78), top - (y + y0) * 0.5)
		var param: float = float(((seed + 3 + n * 5) % 1000) * 8)
		if side < 0:
			s.rect(Vector3(x, y0, -to), Vector3(0, 0, to - from), Vector3(0, y - y0, 0), tone, 0.0, MeshKit.PAT_BEACH_WALL,
				Vector2.ZERO, Vector2.ONE, param)
		else:
			s.rect(Vector3(x, y0, -from), Vector3(0, 0, -(to - from)), Vector3(0, y - y0, 0), tone, 0.0, MeshKit.PAT_BEACH_WALL,
				Vector2.ZERO, Vector2.ONE, param)
		y = y0
		n += 1


## Where Mecha Guppy has eaten a tower (track distance `d`, facing on into the chasm, -z), over world x [x0, x1] (its
## whole width by default): its broken face down to the water, dark.
func _broken_face(s: MeshLayer, d: float, top: float, x0: float = NAN, x1: float = NAN) -> void:
	if is_nan(x0):
		x0 = -geo.wall_x()
	if is_nan(x1):
		x1 = geo.wall_x()
	var y_low: float = bottom(top)
	var y: float = top
	while y > y_low + 0.01:
		var y0: float = maxf(y - STOREY * 2.0, y_low)
		s.rect(Vector3(x1, y0, -d), Vector3(x0 - x1, 0, 0), Vector3(0, y - y0, 0), deep(skin.timber_color * 0.45, top - y0), 0.0,
			MeshKit.PAT_BEACH_TIMBER, Vector2.ZERO, Vector2.ONE, MeshKit.beach_timber_param(2, 1, 3))
		y = y0


## Where Mecha Guppy has eaten a tower's corner (the bait's notch) along the track at world x `x`, facing `side` (-1
## left, +1 right: into the notch), from track distance `from` to `to`: its broken face down to the water, dark.
func _broken_side(s: MeshLayer, x: float, side: int, from: float, to: float, top: float) -> void:
	var y_low: float = bottom(top)
	var y: float = top
	while y > y_low + 0.01 and to > from:
		var y0: float = maxf(y - STOREY * 2.0, y_low)
		var tone: Color = deep(skin.timber_color * 0.45, top - y0)
		var param: float = MeshKit.beach_timber_param(2, 1, 3)
		if side < 0:
			s.rect(Vector3(x, y0, -to), Vector3(0, 0, to - from), Vector3(0, y - y0, 0), tone, 0.0, MeshKit.PAT_BEACH_TIMBER,
				Vector2.ZERO, Vector2.ONE, param)
		else:
			s.rect(Vector3(x, y0, -from), Vector3(0, 0, -(to - from)), Vector3(0, y - y0, 0), tone, 0.0, MeshKit.PAT_BEACH_TIMBER,
				Vector2.ZERO, Vector2.ONE, param)
		y = y0


## The orange lip along a deck's edge at world x `x` over a drop on its `side` (the bait's notch), from track distance
## `from` to `to` (the edge language a pier's open sides carry).
func _side_lip(s: MeshLayer, x: float, side: int, from: float, to: float, top: float) -> void:
	var inner: float = x - side * EDGE_LIP
	s.rect(Vector3(minf(x, inner), top + 0.005, -from), Vector3(EDGE_LIP, 0, 0), Vector3(0, 0, -(to - from)), skin.gap_edge_color,
		LIP_GLOW)


## Roof `r`'s pier: its lanes `lanes` that reach back from `start` to `full` (where the tower starts): their deck
## with the orange lip at its front and along its sides over the gap beside it, a lantern-lit front fascia, and below
## it the open framework of a pier on tall stilts down to the water, at its front and along its open sides.
func _pier(s: MeshLayer, g: MeshLayer, r: MechaGuppyClimb.Roof, lanes: Vector2i, start: float, full: float, seed: int) -> void:
	var top: float = r.top
	var x0: float = geo.lane_floor_span(lanes.x).x
	var x1: float = geo.lane_floor_span(lanes.y).y
	for lane: int in range(lanes.x, lanes.y + 1):
		_deck(s, g, lane, start, full, top, true, false, r.starts)
	var edge: Color = skin.gap_edge_color
	# The orange lip along each side open to a gap (a neighbour lane starting later), and the pier's framework under
	# each side (an outer side too: open to the beach far below).
	for side: int in [-1, 1]:
		var neighbour: int = (lanes.x - 1) if side < 0 else (lanes.y + 1)
		var outer: bool = neighbour < 0 or neighbour >= geo.lane_count
		var until: float = full if outer else minf(r.start_in(neighbour), full)
		if until <= start:
			continue
		var x: float = x0 if side < 0 else x1
		if not outer:
			var inner: float = x - side * EDGE_LIP
			s.rect(Vector3(minf(x, inner), top + 0.005, -start), Vector3(EDGE_LIP, 0, 0), Vector3(0, 0, -(until - start)), edge,
				LIP_GLOW)
		_pier_frame_x(s, g, x, side, start, until, top, seed + side)
	_pier_frame_z(s, g, x0, x1, start, top, seed)


## A pier's front at track distance `d` over [x0, x1] facing the runner: its fascia under the deck with warm lamps
## along it, and below, the dark framework: stilts about PIER_STILT apart, cross braces every PIER_BRACE, down to the
## water, darker the deeper.
func _pier_frame_z(s: MeshLayer, g: MeshLayer, x0: float, x1: float, d: float, top: float, seed: int) -> void:
	var z: float = -d
	var y_low: float = bottom(top)
	var fascia: Color = skin.timber_color * 0.85
	s.rect(Vector3(x0, top - 0.02 - STRIP_HEIGHT - PIER_FASCIA, z + 0.002), Vector3(x1 - x0, 0, 0), Vector3(0, PIER_FASCIA, 0),
		fascia, 0.0, MeshKit.PAT_BEACH_TIMBER, Vector2.ZERO, Vector2.ONE, MeshKit.beach_timber_param(1, 0, seed))
	var lx: float = x0 + 0.6
	while lx < x1 - 0.4:
		s.box(Vector3(lx, top - 0.5, z + 0.08), Vector3(0.22, 0.22, 0.12), skin.lamp_color, skin.lamp_glow)
		g.rect(Vector3(lx - 0.55, top - 1.05, z + 0.14), Vector3(1.1, 0, 0), Vector3(0, 1.1, 0), skin.lamp_color, 0.2,
			MeshKit.SHAPE_RADIAL)
		lx += PIER_LAMP_SPACING
	# The dark under the pier, then its stilts and braces over it.
	var under: float = top - 0.02 - STRIP_HEIGHT - PIER_FASCIA
	var y: float = under
	while y > y_low + 0.01:
		var y0: float = maxf(y - PIER_BRACE, y_low)
		var depth: float = top - (y + y0) * 0.5
		s.rect(Vector3(x0, y0, z - 0.6), Vector3(x1 - x0, 0, 0), Vector3(0, y - y0, 0), deep(DEEP_COLOR * 2.2, depth))
		var count: int = maxi(roundi((x1 - x0) / PIER_STILT), 1)
		for i: int in count + 1:
			var x: float = lerpf(x0 + 0.15, x1 - 0.15, float(i) / float(count))
			s.box(Vector3(x, (y + y0) * 0.5, z - 0.12), Vector3(0.24, y - y0, 0.24), deep(skin.post_color * 0.8, depth), 0.0,
				MeshKit.PAT_BEACH_TIMBER, MeshKit.ALL_FACES, MeshKit.beach_timber_param(0, 0, seed + i))
		var brace := deep(skin.post_color * 0.62, depth)
		for i: int in count:
			var xa: float = lerpf(x0 + 0.15, x1 - 0.15, float(i) / float(count))
			var xb: float = lerpf(x0 + 0.15, x1 - 0.15, float(i + 1) / float(count))
			_beam(s, Vector3(xa, y - 0.2, z - 0.06), Vector3(xb, y0 + 0.2, z - 0.06), brace)
		y = y0


## A pier's open side at world x `x` (its outer face looks toward `side`), from track distance `from` to `to`, under
## its deck at `top`: the dark under the pier, and its stilts and braces along the side, down to the water.
func _pier_frame_x(s: MeshLayer, g: MeshLayer, x: float, side: int, from: float, to: float, top: float, seed: int) -> void:
	var y_low: float = bottom(top)
	var under: float = top - 0.02 - STRIP_HEIGHT - PIER_FASCIA
	var fascia: Color = skin.timber_color * 0.8
	if side < 0:
		s.rect(Vector3(x - 0.002, under, -to), Vector3(0, 0, to - from), Vector3(0, PIER_FASCIA, 0), fascia, 0.0,
			MeshKit.PAT_BEACH_TIMBER, Vector2.ZERO, Vector2.ONE, MeshKit.beach_timber_param(1, 0, seed))
	else:
		s.rect(Vector3(x + 0.002, under, -from), Vector3(0, 0, -(to - from)), Vector3(0, PIER_FASCIA, 0), fascia, 0.0,
			MeshKit.PAT_BEACH_TIMBER, Vector2.ZERO, Vector2.ONE, MeshKit.beach_timber_param(1, 0, seed))
	var count: int = maxi(roundi((to - from) / (PIER_STILT * 1.6)), 1)
	var y: float = under
	var inset: float = x - side * 0.6
	while y > y_low + 0.01:
		var y0: float = maxf(y - PIER_BRACE, y_low)
		var depth: float = top - (y + y0) * 0.5
		if side < 0:
			s.rect(Vector3(inset, y0, -to), Vector3(0, 0, to - from), Vector3(0, y - y0, 0), deep(DEEP_COLOR * 2.2, depth))
		else:
			s.rect(Vector3(inset, y0, -from), Vector3(0, 0, -(to - from)), Vector3(0, y - y0, 0), deep(DEEP_COLOR * 2.2, depth))
		for i: int in count + 1:
			var d: float = lerpf(from + 0.15, to - 0.15, float(i) / float(count))
			s.box(Vector3(x - side * 0.12, (y + y0) * 0.5, -d), Vector3(0.24, y - y0, 0.24), deep(skin.post_color * 0.8, depth), 0.0,
				MeshKit.PAT_BEACH_TIMBER, MeshKit.ALL_FACES, MeshKit.beach_timber_param(0, 0, seed + i))
		var brace := deep(skin.post_color * 0.62, depth)
		for i: int in count:
			var da: float = lerpf(from + 0.15, to - 0.15, float(i) / float(count))
			var db: float = lerpf(from + 0.15, to - 0.15, float(i + 1) / float(count))
			_beam(s, Vector3(x - side * 0.06, y - 0.2, -da), Vector3(x - side * 0.06, y0 + 0.2, -db), brace)
		y = y0


## A square timber beam from `a` to `b` (a pier's brace).
func _beam(s: MeshLayer, a: Vector3, b: Vector3, color: Color) -> void:
	var length: float = a.distance_to(b)
	if length < 0.05:
		return
	var dir: Vector3 = (b - a) / length
	var up: Vector3 = Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var basis := Basis.looking_at(dir, up)
	var t := Transform3D(basis, (a + b) * 0.5)
	var beam := MeshLayer.new()
	beam.box(Vector3.ZERO, Vector3(0.16, 0.16, length), color, 0.0, MeshKit.PAT_PLAIN)
	s.append(beam, t)


## A tiki bar roof's thatch eave along its outer edge on `side`, from track distance `from` to `to`: sloping out and
## down from just under the deck's edge, outside the lanes (nothing on the deck, nothing a runner meets).
func _eave(s: MeshLayer, side: int, from: float, to: float, top: float) -> void:
	var x0: float = side * (geo.wall_x() + 0.02)
	var x1: float = side * (geo.wall_x() + EAVE_REACH)
	var a := Vector3(x0, top - 0.06, -from)
	var b := Vector3(x0, top - 0.06, -to)
	var c := Vector3(x1, top - EAVE_DROP, -to)
	var d := Vector3(x1, top - EAVE_DROP, -from)
	_quad(s, a, b, c, d, Vector3(side, 1.0, 0.0), skin.thatch_dark_color * 1.7)
	_quad(s, a, b, c, d, Vector3(-side, -1.0, 0.0), skin.thatch_dark_color)


## Bamboo posts with warm-white lanterns along a roof deck's outer edge on `side` (on its kerb, outside the lanes:
## never in a runner's way), every LANTERN_SPACING from `from` to `to`.
func _lanterns(s: MeshLayer, g: MeshLayer, side: int, from: float, to: float, top: float, seed: int) -> void:
	var x: float = side * (geo.half_width() + (geo.wall_x() - geo.half_width()) * 0.5)
	var d: float = ceilf((from - 1.5) / LANTERN_SPACING) * LANTERN_SPACING + 1.5
	while d < to - 0.001:
		s.box(Vector3(x, top + LANTERN_HEIGHT * 0.5, -d), Vector3(0.08, LANTERN_HEIGHT, 0.08), skin.post_color, 0.0,
			MeshKit.PAT_BEACH_TIMBER, MeshKit.NO_BOTTOM, MeshKit.beach_timber_param(0, 0, seed))
		s.box(Vector3(x, top + LANTERN_HEIGHT + 0.12, -d), Vector3(0.22, 0.3, 0.22), skin.lamp_color, skin.lamp_glow)
		g.rect(Vector3(x - 0.6, top + LANTERN_HEIGHT - 0.48, -d + 0.02), Vector3(1.2, 0, 0), Vector3(0, 1.2, 0), skin.lamp_color, 0.2,
			MeshKit.SHAPE_RADIAL)
		d += LANTERN_SPACING


# --- Huts ------------------------------------------------------------------------------------------

## Step `step`'s tiki hut: the underside of each run of lanes ending together (one surface across its lanes, lamp rows
## along the seams, the orange band at its end), the hut's body over the full-width part, an annex over the lanes
## that run further (RUN_ON), lift pods at its corners outside the lanes, a neon sign on its front on some.
func hut(step: MechaGuppyClimb.Step) -> Node3D:
	var node := Node3D.new()
	node.name = "HutLook%d" % step.index
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(skin.solid_material())
	var g: MeshLayer = batch.layer(skin.glow_material())
	var y: float = step.hut_y
	var zn: float = -step.hut_start
	var short: float = step.deadline
	var half: float = geo.half_width() + HUT_OVERHANG
	var variant: int = MeshKit.hash_i(step.index, 17)
	var plank: Color = skin.plank_color
	# The underside: each run of lanes ending together, from the hut's start to its end.
	for run: Dictionary in MechaGuppyStairs.runs(step.ends):
		var lanes: Vector2i = run["lanes"]
		var x0: float = geo.lane_x(lanes.x) - geo.lane_width * 0.5
		var x1: float = geo.lane_x(lanes.y) + geo.lane_width * 0.5
		if lanes.x == 0:
			x0 -= HUT_OVERHANG
		if lanes.y == geo.lane_count - 1:
			x1 += HUT_OVERHANG
		var zf: float = -float(run["start"])
		_underside(s, g, x0, x1, zn, zf, lanes, y)
	# The platform over the full-width part (its plank deck's edge), and on it a row of tiki huts: bamboo walls with a
	# dark bar opening facing each way, corner posts and a steep thatched hip roof, a bamboo railing between them.
	var zs: float = -short
	var floor_top: float = y + HUT_FLOOR
	s.box(Vector3(0.0, y + HUT_FLOOR * 0.5, (zn + zs) * 0.5), Vector3(half * 2.0, HUT_FLOOR, zn - zs), plank * 0.8, 0.0,
		MeshKit.PAT_BEACH_TIMBER, MeshKit.ALL_FACES & ~MeshKit.FACE_NY, MeshKit.beach_timber_param(1, 1, variant))
	var length: float = zn - zs
	var count: int = maxi(floori((length - 2.0 + HUT_GAP) / (HUT_LENGTH + HUT_GAP)), 1)
	var hut_len: float = minf(HUT_LENGTH, length - 2.0)
	var pitch: float = (length - 2.0 - hut_len) / maxf(float(count - 1), 1.0) if count > 1 else 0.0
	for i: int in count:
		var cz: float = zn - 1.0 - hut_len * 0.5 - pitch * float(i)
		if count == 1:
			cz = (zn + zs) * 0.5
		_tiki_hut(s, g, 0.0, cz, half - 0.9, hut_len * 0.5, floor_top, MeshKit.hash_i(step.index, i, 31))
	for side: int in [-1, 1]:
		_rail(s, Vector3(side * (half - 0.12), floor_top, zn - 0.2), Vector3(side * (half - 0.12), floor_top, zs + 0.2), variant)
	# A neon sign on the first hut's front beside its bar opening, facing the runner, on some.
	if MeshKit.hash01(step.index, 23) < 0.5:
		var hx: float = half - 0.9
		var wing: float = hx - minf(hx * 1.2, 4.0) * 0.5
		var side: float = -1.0 if MeshKit.hash01(step.index, 29) < 0.5 else 1.0
		_sign(s, g, side * (hx - wing * 0.5), step.hut_start + 1.0, floor_top + HUT_WALL * 0.5, step.index + 101)
	# The annex over the lanes that run further (RUN_ON): a walkway with a low thatch canopy.
	if step.cue == MechaGuppyClimb.Cue.RUN_ON and step.hut_end() > short + 0.5:
		var ax0: float = geo.lane_x(step.up.x) - geo.lane_width * 0.5
		var ax1: float = geo.lane_x(step.up.y) + geo.lane_width * 0.5
		if step.up.x == 0:
			ax0 -= HUT_OVERHANG
		if step.up.y == geo.lane_count - 1:
			ax1 += HUT_OVERHANG
		var zf: float = -step.hut_end()
		var ax: float = (ax0 + ax1) * 0.5
		s.box(Vector3(ax, y + HUT_FLOOR * 0.5, (zs + zf) * 0.5), Vector3(ax1 - ax0, HUT_FLOOR, zs - zf), plank * 0.85, 0.0,
			MeshKit.PAT_BEACH_TIMBER, MeshKit.ALL_FACES & ~MeshKit.FACE_NY, MeshKit.beach_timber_param(2, 1, variant + 3))
		for x: float in [ax0 + 0.15, ax1 - 0.15]:
			var z: float = zs
			while z > zf + 0.6:
				s.box(Vector3(x, floor_top + ANNEX_WALL * 0.5, z - 0.3), Vector3(0.1, ANNEX_WALL, 0.1), skin.post_color, 0.0,
					MeshKit.PAT_BEACH_TIMBER, MeshKit.NO_BOTTOM, MeshKit.beach_timber_param(0, 0, variant))
				z -= 2.2
		_hip_roof(s, ax, (zs + zf) * 0.5, (ax1 - ax0) * 0.5 + 0.25, (zs - zf) * 0.5 + 0.2, floor_top + ANNEX_WALL, ANNEX_ROOF)
	# The lift pods at its corners, outside the lanes: a pale violet-blue, far from the pads' cyan.
	for side: int in [-1, 1]:
		for z: float in [zn - 1.2, zs + 1.2]:
			var c := Vector3(side * (half - 0.2), y - POD_RADIUS * 0.6, z)
			s.box(c, Vector3(POD_RADIUS * 2.0, POD_RADIUS * 1.2, POD_RADIUS * 2.0), skin.hull_color, 0.0)
			s.box(c - Vector3(0, POD_RADIUS * 0.62, 0), Vector3(POD_RADIUS * 1.4, 0.04, POD_RADIUS * 1.4), skin.engine_color, 0.9)
	batch.commit(node)
	return node


## One tiki hut on a platform, centred (cx, cz), half sizes (hx, hz), its floor at `y0`: bamboo walls (the Beach's wall
## pattern) with a dark bar opening and a warm lamp facing each way along the track, corner posts, and a steep
## thatched hip roof overhanging them.
func _tiki_hut(s: MeshLayer, g: MeshLayer, cx: float, cz: float, hx: float, hz: float, y0: float, seed: int) -> void:
	var bamboo: Color = skin.bamboo_colors[seed % skin.bamboo_colors.size()]
	var param: float = float((seed % 1000) * 8)
	var top: float = y0 + HUT_WALL
	for side: int in [-1, 1]:
		s.box(Vector3(cx + side * hx, y0 + HUT_WALL * 0.5, cz), Vector3(0.14, HUT_WALL, hz * 2.0), bamboo, 0.0,
			MeshKit.PAT_BEACH_WALL, MeshKit.ALL_FACES, param)
	var opening: float = minf(hx * 1.2, 4.0)
	for end: int in [-1, 1]:
		var z: float = cz + end * hz
		# The wall either side of the bar opening, the counter under it and the lintel over it.
		var wing: float = hx - opening * 0.5
		for side: int in [-1, 1]:
			s.box(Vector3(cx + side * (hx - wing * 0.5), y0 + HUT_WALL * 0.5, z), Vector3(wing, HUT_WALL, 0.14), bamboo, 0.0,
				MeshKit.PAT_BEACH_WALL, MeshKit.ALL_FACES, param)
		s.box(Vector3(cx, y0 + 0.5, z), Vector3(opening, 1.0, 0.18), skin.timber_color, 0.0, MeshKit.PAT_BEACH_TIMBER, MeshKit.ALL_FACES,
			MeshKit.beach_timber_param(1, 1, seed))
		s.box(Vector3(cx, top - 0.3, z), Vector3(opening, 0.6, 0.14), bamboo, 0.0, MeshKit.PAT_BEACH_WALL, MeshKit.ALL_FACES, param)
		# The dark inside seen through the opening, and a warm lamp hanging in it.
		s.rect(Vector3(cx - opening * 0.5, y0 + 1.0, z - end * 0.3), Vector3(opening, 0, 0), Vector3(0, HUT_WALL - 1.6, 0),
			skin.thatch_dark_color * 0.5, 0.0)
		s.box(Vector3(cx, top - 0.75, z - end * 0.25), Vector3(0.22, 0.28, 0.22), skin.lamp_color, skin.lamp_glow)
		g.rect(Vector3(cx - 0.7, top - 1.45, z + end * 0.02), Vector3(1.4, 0, 0), Vector3(0, 1.4, 0), skin.lamp_color, 0.18,
			MeshKit.SHAPE_RADIAL)
	for sx: int in [-1, 1]:
		for sz: int in [-1, 1]:
			s.box(Vector3(cx + sx * hx, y0 + HUT_WALL * 0.5, cz + sz * hz), Vector3(0.22, HUT_WALL + 0.1, 0.22), skin.post_color, 0.0,
				MeshKit.PAT_BEACH_TIMBER, MeshKit.NO_BOTTOM, MeshKit.beach_timber_param(0, 0, seed + sx + sz))
	_hip_roof(s, cx, cz, hx + 0.7, hz + 0.7, top, HUT_ROOF)


## A bamboo railing from `a` to `b` along a platform's edge: posts every ~1.6 m and two rails.
func _rail(s: MeshLayer, a: Vector3, b: Vector3, seed: int) -> void:
	var length: float = a.distance_to(b)
	var posts: int = maxi(roundi(length / 1.6), 1)
	for i: int in posts + 1:
		var p: Vector3 = a.lerp(b, float(i) / float(posts))
		s.box(p + Vector3(0, 0.5, 0), Vector3(0.07, 1.0, 0.07), skin.post_color, 0.0, MeshKit.PAT_BEACH_TIMBER, MeshKit.NO_BOTTOM,
			MeshKit.beach_timber_param(0, 0, seed + i))
	for f: float in [0.95, 0.5]:
		s.box((a + b) * 0.5 + Vector3(0, f, 0), Vector3(maxf(absf(b.x - a.x), 0.06), 0.06, maxf(absf(b.z - a.z), 0.06)), skin.post_color,
			0.0, MeshKit.PAT_BEACH_TIMBER, MeshKit.ALL_FACES, MeshKit.beach_timber_param(2, 0, seed + 7))


## The underside of a run of lanes `lanes` over [x0, x1] from zn (its near end) to zf (its far end) at height `y`: one
## plank surface, a dark seam and warm lamps along each lane seam, a lamp row just inside each edge it shares with
## another run (so where the other lanes end, the lamps of the lanes that lead up run on: RUN_ON's cue, lit), and the
## orange band at its far end.
func _underside(s: MeshLayer, g: MeshLayer, x0: float, x1: float, zn: float, zf: float, lanes: Vector2i, y: float) -> void:
	var z0: float = zf + END_BAND
	s.rect(Vector3(x0, y, z0), Vector3(x1 - x0, 0, 0), Vector3(0, 0, zn - z0), skin.plank_color, 0.0, MeshKit.PAT_BEACH_TIMBER,
		Vector2.ZERO, Vector2.ONE, MeshKit.beach_timber_param(1, 1, lanes.x))
	# Flush joists across the planks: they stream past a rider.
	var jz: float = zn - 1.5
	while jz > z0 + 0.5:
		s.box(Vector3((x0 + x1) * 0.5, y - 0.004, jz), Vector3(x1 - x0, 0.008, 0.16), skin.timber_color * 0.55, 0.0, MeshKit.PAT_PLAIN,
			MeshKit.FACE_NY)
		jz -= 2.4
	var seam := Color(skin.seam_color, 1.0)
	var lamp: Color = skin.ceiling_lamp_color
	var rows: Array[float] = []
	for lane: int in range(lanes.x + 1, lanes.y + 1):
		var x: float = geo.lane_x(lane) - geo.lane_width * 0.5
		s.box(Vector3(x, y - 0.006, (zn + z0) * 0.5), Vector3(0.06, 0.012, zn - z0), seam, 0.0, MeshKit.PAT_PLAIN,
			MeshKit.ALL_FACES & ~MeshKit.FACE_PY)
		rows.append(x)
	if lanes.x > 0:
		rows.append(geo.lane_x(lanes.x) - geo.lane_width * 0.5 + 0.45)
	if lanes.y < geo.lane_count - 1:
		rows.append(geo.lane_x(lanes.y) + geo.lane_width * 0.5 - 0.45)
	for x: float in rows:
		var z: float = z0 + 3.0
		while z < zn - 2.0:
			s.box(Vector3(x, y - 0.02, z), Vector3(0.24, 0.04, 0.24), lamp, 0.75, MeshKit.PAT_PLAIN, MeshKit.ALL_FACES & ~MeshKit.FACE_PY)
			g.rect(Vector3(x - 0.8, y - 0.06, z + 0.8), Vector3(1.6, 0, 0), Vector3(0, 0, -1.6), lamp, 0.28, MeshKit.SHAPE_RADIAL)
			z += LAMP_SPACING
	# The orange band where the run ends: a rider drops here (MeshKit.ceiling_end's look, longer and brighter; its
	# glow stays above the underside, where the chase camera passes as the rider drops). It hangs SHADOW_UNDER under the
	# underside, below a rider's blob shadow (Player._update_shadow), so a glowing band takes no shadow (task E5e-b2's
	# review: over the band the shadow read as a red-orange disc, a hazard's colour).
	var edge: Color = skin.gap_edge_color
	s.rect(Vector3(x0, y - SHADOW_UNDER, zf), Vector3(x1 - x0, 0, 0), Vector3(0, 0, END_BAND), edge, END_BAND_GLOW)
	var lx: float = x0 + 0.6
	while lx < x1 - 0.3:
		for along: float in [0.25, END_BAND * 0.5]:
			s.box(Vector3(lx, y - 0.025, zf + along), Vector3(0.35, 0.05, 0.2), edge, 0.7, MeshKit.PAT_PLAIN,
				MeshKit.ALL_FACES & ~MeshKit.FACE_PY)
		lx += 1.2
	# Its brightness from afar, gone as the camera comes near (see END_BAND).
	g.rect(Vector3(x0, y - SHADOW_UNDER - 0.01, zf + END_BAND), Vector3(x1 - x0, 0, 0), Vector3(0, 0, -END_BAND), edge,
		END_BAND_CARD, MeshKit.SHAPE_FLAT, Vector2.ZERO, Vector2.ONE, MeshKit.near_fade(END_BAND_NEAR))
	g.rect(Vector3(x0, y - 0.05, zf + END_BAND + MeshKit.CEILING_END_GLOW), Vector3(x1 - x0, 0, 0),
		Vector3(0, 0, -(END_BAND + MeshKit.CEILING_END_GLOW)), edge, 0.4, MeshKit.SHAPE_RADIAL, Vector2.ZERO, Vector2.ONE,
		MeshKit.near_fade(END_BAND_NEAR))


## A thatched hip roof over the rectangle centred (cx, cz), half sizes (hx, hz), eaves at height y0, rising `rise`.
func _hip_roof(s: MeshLayer, cx: float, cz: float, hx: float, hz: float, y0: float, rise: float) -> void:
	var color: Color = skin.thatch_color
	var inset: float = minf(hx, hz) * 0.9
	var pa := Vector3(cx - hx, y0, cz - hz)
	var pb := Vector3(cx - hx, y0, cz + hz)
	var pc := Vector3(cx + hx, y0, cz + hz)
	var pd := Vector3(cx + hx, y0, cz - hz)
	var r0: Vector3
	var r1: Vector3
	if hx >= hz:
		r0 = Vector3(cx - hx + inset, y0 + rise, cz)
		r1 = Vector3(cx + hx - inset, y0 + rise, cz)
		_quad(s, pa, pb, r0, r0, Vector3(-1, 1, 0), color * 0.92)
		_quad(s, pd, pc, r1, r1, Vector3(1, 1, 0), color * 0.92)
		_quad(s, pb, pc, r1, r0, Vector3(0, 1, 1), color)
		_quad(s, pa, pd, r1, r0, Vector3(0, 1, -1), color * 0.9)
	else:
		r0 = Vector3(cx, y0 + rise, cz - hz + inset)
		r1 = Vector3(cx, y0 + rise, cz + hz - inset)
		_quad(s, pa, pd, r0, r0, Vector3(0, 1, -1), color * 0.9)
		_quad(s, pb, pc, r1, r1, Vector3(0, 1, 1), color)
		_quad(s, pa, pb, r1, r0, Vector3(-1, 1, 0), color * 0.92)
		_quad(s, pd, pc, r1, r0, Vector3(1, 1, 0), color * 0.92)
	s.rect(Vector3(cx - hx, y0 - 0.005, cz + hz), Vector3(hx * 2.0, 0, 0), Vector3(0, 0, -hz * 2.0), skin.thatch_dark_color, 0.0,
		MeshKit.PAT_PLAIN)


func _quad(layer: MeshLayer, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3, color: Color) -> void:
	if (b - a).cross(c - a).dot(outward) > 0.0:
		layer.quad(a, d, c, b, color, 0.0, MeshKit.PAT_BEACH_THATCH)
	else:
		layer.quad(a, b, c, d, color, 0.0, MeshKit.PAT_BEACH_THATCH)


# --- Pads and signs --------------------------------------------------------------------------------

## A pad strip's look on its trigger `area` (`size`: the trigger's box): pad tiles end to end over its whole length.
func strip(area: Area3D, size: Vector3) -> void:
	var count: int = maxi(roundi(size.z / PAD_TILE), 1)
	var tile_len: float = size.z / float(count)
	var tile := Vector3(size.x, size.y, tile_len)
	var mesh: Mesh = _tile(tile)
	for i: int in count:
		var z: float = size.z * 0.5 - tile_len * (float(i) + 0.5)
		MeshBatch.add_instance(area, mesh, "", Vector3(0.0, 0.0, z))


func _tile(size: Vector3) -> Mesh:
	var key: String = "%s" % size
	if not _tiles.has(key):
		_tiles[key] = MeshKit.lift_pad(size, skin.pad_color, skin.trigger_metal_color, PAD_BEAM, skin.solid_material(),
			skin.glow_material())
	return _tiles[key]


## A wordless neon silhouette sign facing the runner, centred at world x `cx` on the face at track distance `d`, its
## middle at height `cy`: a dark board with a glyph and a frame glowing in the Beach's violet, blue or warm white,
## and a soft halo behind (BeachShacks' signs).
func _sign(s: MeshLayer, g: MeshLayer, cx: float, d: float, cy: float, seed: int) -> void:
	var tubes: Array[Color] = [skin.neon_violet, skin.neon_blue, skin.neon_white]
	var tube: Color = tubes[MeshKit.hash_i(seed, 5) % tubes.size()]
	var glyph: int = MeshKit.hash_i(seed, 9) % MeshKit.GLYPH_COUNT
	var x0: float = cx - SIGN_W * 0.5
	var y0: float = cy - SIGN_H * 0.5
	var z: float = -d + 0.06
	s.box(Vector3(cx, cy, z + 0.03), Vector3(SIGN_W + 0.16, SIGN_H + 0.16, 0.06), skin.steel_color, 0.0)
	s.rect(Vector3(x0, y0, z + 0.07), Vector3(SIGN_W, 0, 0), Vector3(0, SIGN_H, 0), tube, skin.neon_glow, MeshKit.PAT_BEACH_NEON,
		Vector2.ZERO, Vector2(SIGN_W, SIGN_H), MeshKit.beach_neon_param(glyph, SIGN_W, SIGN_H))
	g.rect(Vector3(x0 - 0.5, y0 - 0.5, z + 0.12), Vector3(SIGN_W + 1.0, 0, 0), Vector3(0, SIGN_H + 1.0, 0), tube, 0.16,
		MeshKit.SHAPE_RADIAL)
