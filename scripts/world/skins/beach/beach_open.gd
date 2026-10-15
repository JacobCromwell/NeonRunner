class_name BeachOpen
extends RefCounted
## What the Beach shows where a side wall has a gap (BeachSkin.wall_gap; the owner, October 9, 2026: "much
## longer sections where there aren't sidewalls, and the player can see the surrounding area a little bit
## better"; the levels leave about half of each wall open, in stretches of 100 m and more). The street is a
## promenade standing `beach_drop` above the open beach beside it: past the wall line the floor's edge drops to
## sand, then a shoreline (damp sand, a line of foam, turquoise shallows, deeper water) with palms, beach
## umbrellas and loungers, surfboards stuck in the sand and a low beach hut or two scattered over it. The
## standard gap marks stay (ZoneSkin.standard_wall_gap: the orange stripes at the cut wall's ends and the lip
## along the floor's edge across the gap: the cross-zone language), and a shack the gap cuts is closed with its
## end (BeachShacks.gap_end_cap) where the wall starts again.
## Everything is built chunk by chunk over any length, from absolute track distances only (the shoreline is a
## smooth function of the distance; scenery is hashed from 12 m cells and belongs to the chunk holding its
## middle), so a chunk looks the same whenever it is built and neighbours join exactly. It is all one solid
## layer (no extra surface), unlit muted colours, nothing glowing but the standard marks, and:
## - nothing nearer the wall line than `open_near` metres, nothing hung across the opening (no nets or ropes: that
##   reads as a fence), nothing a runner could mistake for a wall to run on, nothing reaching into the street;
## - scenery stays `open_margin` metres from the gap's ends, so it never meets a neighbouring shack.
## Behind the shacks (BeachOpen.ground with `from_lat`) the same beach and sea run on past a wall's solid
## stretches, so a gap never shows an edge of the world and a view over the roofs is of the shore too.
## Chunk space: x across (the wall line at ±wall), y up (the street at 0), z = -distance.
## DESIGN-TBD (docs/OPEN_QUESTIONS.md, items 555–556): the shore's shape, the scenery's looks and amounts, and the drop.

## The beach and the sea are built in segments this long (absolute track distance, so chunks line up).
const SEG: float = 8.0
## Scenery cells along the track.
const CELL: float = 12.0
## The beach's bands, as lateral distances from the shoreline (negative: toward the street): the damp sand, the
## foam, the shallows, the middle water, and how far the sea reaches.
const WET: float = 3.0
const FOAM_IN: float = 0.4
const FOAM_OUT: float = 0.5
const SHALLOWS: float = 7.0
const MID: float = 26.0
const FAR: float = 260.0
## Template keys (a kind's base plus its variant).
const KEY_UMBRELLA: int = 100
const KEY_LOUNGER: int = 200
const KEY_BOARD: int = 300
const KEY_HUT: int = 400

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: BeachSkin:
	get:
		return _skin.get_ref() as BeachSkin
var _skin: WeakRef
var _templates: Dictionary = {}


func _init(p_skin: BeachSkin) -> void:
	_skin = weakref(p_skin)


## The shoreline's lateral distance from the wall line at track distance `d` on `side` (16 to 64 m: a slow
## swell, a shorter one and a ripple, a different phase on each side, so the sea is near on one side or the
## other and far from both now and then).
static func shore(side: int, d: float) -> float:
	return 40.0 + 18.0 * sin(d * 0.011 + 2.1 * float(side)) + 4.0 * sin(d * 0.09 + float(side)) + 2.0 * sin(d * 0.27 + 1.3)


# --- The beach and the sea --------------------------------------------------------------------------

## The beach's ground and the sea between track distances [start, end], from `from_lat` metres past the wall
## line outward (0 across a wall gap, END_DEPTH behind a solid wall).
func ground(batch: MeshBatch, side: int, face_x: float, start: float, end: float, from_lat: float) -> void:
	var s: MeshLayer = batch.layer(skin.solid_material())
	var wall: float = absf(face_x)
	var y: float = -skin.beach_drop
	var d0: float = start
	while d0 < end - 0.001:
		var d1: float = minf(end, (floorf(d0 / SEG + 0.0001) + 1.0) * SEG)
		var a: float = shore(side, d0)
		var b: float = shore(side, d1)
		# Band edges as lateral distances at the near and far end of the segment.
		var n: Array[float] = [from_lat, a - WET, a - FOAM_IN, a + FOAM_OUT, a + SHALLOWS, a + MID, FAR]
		var f: Array[float] = [from_lat, b - WET, b - FOAM_IN, b + FOAM_OUT, b + SHALLOWS, b + MID, FAR]
		var colors: Array[Color] = [skin.sand_color, skin.wet_sand_color, skin.foam_color, skin.sea_shallow_color,
			skin.sea_mid_color, skin.sea_deep_color]
		for i: int in 6:
			var pattern: int = MeshKit.PAT_BEACH_SAND if i == 0 else MeshKit.PAT_PLAIN
			_flat(s, side, wall, y, d0, d1, n[i], f[i], n[i + 1], f[i + 1], colors[i], pattern)
		d0 = d1


## One flat patch between lateral distances (inner at the near end, inner at the far end, outer near, outer far),
## seen from above.
func _flat(s: MeshLayer, side: int, wall: float, y: float, d0: float, d1: float, in0: float, in1: float, out0: float,
		out1: float, color: Color, pattern: int) -> void:
	var sd: float = float(side)
	var inner_near := Vector3(sd * (wall + in0), y, -d0)
	var inner_far := Vector3(sd * (wall + in1), y, -d1)
	var outer_far := Vector3(sd * (wall + out1), y, -d1)
	var outer_near := Vector3(sd * (wall + out0), y, -d0)
	if side > 0:
		s.quad(inner_near, inner_far, outer_far, outer_near, color, 0.0, pattern)
	else:
		s.quad(inner_near, outer_near, outer_far, inner_far, color, 0.0, pattern)


# --- A wall gap -------------------------------------------------------------------------------------

## The part [start, end] of the wall gap `gap` on `side`: the standard marks, the street's edge dropping to the
## beach, the beach, the sea and the scenery on it, and the closed end of the shack the gap cuts.
func build(batch: MeshBatch, side: int, face_x: float, start: float, end: float, gap: Vector2) -> void:
	var s: MeshLayer = batch.layer(skin.solid_material())
	ZoneSkin.standard_wall_gap(s, side, face_x, start, end, gap, skin.gap_edge_color, skin.gap_inside_color)
	shore_side(batch, side, face_x, start, end, gap)
	if gap.y >= start - 0.001 and gap.y <= end + 0.001:
		skin.shacks().gap_end_cap(batch, side, face_x, gap.y, -skin.beach_drop)


## The open shore beside the street on `side` over [start, end] within the opening `gap` (build's look without the
## standard gap marks and the cut shack's end): the street's edge dropping to the beach (a weathered timber seawall
## facing the beach, seen only from outside it), the beach, the sea and the scenery on it. MechaGuppySkin draws the
## Beach's boss arena, which has no walls at all, with it alone.
func shore_side(batch: MeshBatch, side: int, face_x: float, start: float, end: float, gap: Vector2) -> void:
	var s: MeshLayer = batch.layer(skin.solid_material())
	ground(batch, side, face_x, start, end, 0.0)
	var drop: float = skin.beach_drop
	var timber: Color = skin.timber_color * 0.7
	var param: float = MeshKit.beach_timber_param(2, 1, 5)
	if side < 0:
		s.rect(Vector3(face_x, -drop, -end), Vector3(0, 0, end - start), Vector3(0, drop, 0), timber, 0.0, MeshKit.PAT_BEACH_TIMBER,
			Vector2.ZERO, Vector2.ONE, param)
	else:
		s.rect(Vector3(face_x, -drop, -start), Vector3(0, 0, -(end - start)), Vector3(0, drop, 0), timber, 0.0, MeshKit.PAT_BEACH_TIMBER,
			Vector2.ZERO, Vector2.ONE, param)
	var wall: float = absf(face_x)
	for item: Dictionary in placed(side, start, end, gap):
		_place(s, side, wall, item)


## Where the scenery stands on `side` over the part [start, end) of the gap `gap`, as {kind, d, lat, variant, yaw}
## (a kind: &"palm", &"umbrella", &"lounger", &"board", &"hut"; d the track distance of its middle, lat its
## distance past the wall line): scenery hashed from 12 m cells, kept `open_margin` from the gap's ends and
## `open_near` from the wall line, on the dry sand.
func placed(side: int, start: float, end: float, gap: Vector2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var lo: float = maxf(start, gap.x + skin.open_margin)
	var hi: float = minf(end, gap.y - skin.open_margin)
	if hi <= lo:
		return out
	var near: float = skin.open_near
	for k: int in range(floori(lo / CELL) - 1, floori(hi / CELL) + 2):
		var base: float = (float(k) + 0.5) * CELL
		if MeshKit.hash01(side, k, 901) < skin.open_palm_share:
			_add(out, side, lo, hi, &"palm", base + (MeshKit.hash01(side, k, 902) - 0.5) * 6.0, near + 1.0 + 17.0 * MeshKit.hash01(side, k, 903),
				MeshKit.hash_i(side, k, 904) % 3, MeshKit.hash01(side, k, 905) * TAU, 5.0)
		if MeshKit.hash01(side, k, 906) < skin.open_palm_share * 0.4:
			_add(out, side, lo, hi, &"palm", base + (MeshKit.hash01(side, k, 907) - 0.5) * 6.0, 22.0 + 18.0 * MeshKit.hash01(side, k, 908),
				MeshKit.hash_i(side, k, 909) % 3, MeshKit.hash01(side, k, 910) * TAU, 5.0)
		if MeshKit.hash01(side, k, 911) < skin.open_umbrella_share:
			var d: float = base + (MeshKit.hash01(side, k, 912) - 0.5) * 4.0
			var lat: float = near + 1.0 + 9.0 * MeshKit.hash01(side, k, 913)
			var variant: int = MeshKit.hash_i(side, k, 914) % 4
			var yaw: float = MeshKit.hash01(side, k, 915) * TAU
			_add(out, side, lo, hi, &"umbrella", d, lat, variant, yaw, 5.0)
			# Loungers beside it, facing the sea.
			for j: int in 1 + MeshKit.hash_i(side, k, 916) % 2:
				var off: float = (-1.0 if j == 0 else 1.0) * 1.7
				_add(out, side, lo, hi, &"lounger", d + off, lat + 0.3 * float(j), (variant + j) % 3, PI * 0.5 + (MeshKit.hash01(side, k, 917) - 0.5) * 0.3, 5.0)
		if MeshKit.hash01(side, k, 918) < skin.open_board_share:
			var d: float = base + (MeshKit.hash01(side, k, 919) - 0.5) * 6.0
			var lat: float = near + 0.5 + 6.0 * MeshKit.hash01(side, k, 920)
			for j: int in 1 + MeshKit.hash_i(side, k, 921) % 3:
				_add(out, side, lo, hi, &"board", d + 0.65 * float(j), lat, (MeshKit.hash_i(side, k, 922) + j) % 4,
					(MeshKit.hash01(side, k, 923) - 0.5) * 0.6, 5.0)
		if k % 4 == 0 and MeshKit.hash01(side, k, 924) < skin.open_hut_share:
			var side_in: float = PI if side > 0 else 0.0
			_add(out, side, lo, hi, &"hut", base + (MeshKit.hash01(side, k, 925) - 0.5) * 4.0, 24.0 + 9.0 * MeshKit.hash01(side, k, 926),
				MeshKit.hash_i(side, k, 927) % 3, side_in + (MeshKit.hash01(side, k, 928) - 0.5) * 0.5, 10.0)
	return out


## Adds an item if its middle lies in [lo, hi) and it stands on the dry sand (`dry` metres from the shoreline).
func _add(out: Array[Dictionary], side: int, lo: float, hi: float, kind: StringName, d: float, lat: float, variant: int,
		yaw: float, dry: float) -> void:
	if d < lo or d >= hi or lat < skin.open_near or lat > shore(side, d) - WET - dry:
		return
	out.append({"kind": kind, "d": d, "lat": lat, "variant": variant, "yaw": yaw})


func _place(s: MeshLayer, side: int, wall: float, item: Dictionary) -> void:
	var at := Vector3(float(side) * (wall + float(item["lat"])), -skin.beach_drop, -float(item["d"]))
	var xform := Transform3D(Basis(Vector3.UP, float(item["yaw"])), at)
	var variant: int = int(item["variant"])
	match StringName(item["kind"]):
		&"palm":
			s.append(skin.shacks().palm_template(variant, side), xform)
		&"umbrella":
			s.append(_template(KEY_UMBRELLA + variant), xform)
		&"lounger":
			s.append(_template(KEY_LOUNGER + variant), xform)
		&"board":
			s.append(_template(KEY_BOARD + variant), xform)
		&"hut":
			s.append(_template(KEY_HUT + variant), xform)


# --- Cached templates (their foot at the origin; built once) ----------------------------------------

func _template(key: int) -> MeshLayer:
	var found: MeshLayer = _templates.get(key)
	if found != null:
		return found
	var t: MeshLayer
	if key >= KEY_HUT:
		t = _build_hut(key - KEY_HUT)
	elif key >= KEY_BOARD:
		t = _build_board(key - KEY_BOARD)
	elif key >= KEY_LOUNGER:
		t = _build_lounger(key - KEY_LOUNGER)
	else:
		t = _build_umbrella(key - KEY_UMBRELLA)
	_templates[key] = t
	return t


func _paint(i: int) -> Color:
	return skin.paint_colors[posmod(i, skin.paint_colors.size())]


## A four-cornered face wound to face `outward` (Godot's front faces wind clockwise).
func _face(t: MeshLayer, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3, color: Color, pattern: int = 0,
		param: float = 0.0) -> void:
	if (b - a).cross(c - a).dot(outward) > 0.0:
		t.quad(a, d, c, b, color, 0.0, pattern, param)
	else:
		t.quad(a, b, c, d, color, 0.0, pattern, param)


## A beach umbrella (variant 0-3: its paint): a timber pole, a slightly tilted eight-sided canopy in strips of
## a muted paint and cream, unlit.
func _build_umbrella(variant: int) -> MeshLayer:
	var t := MeshLayer.new()
	t.prism(Vector3.ZERO, 0.035, 2.6, 5, skin.timber_color * 0.8, 0.0, MeshKit.PAT_PLAIN, true)
	var paint: Color = _paint(variant)
	var cream: Color = skin.cream_color * 0.95
	var apex := Vector3(0, 2.9, 0)
	for i: int in 8:
		var a0: float = TAU * float(i) / 8.0
		var a1: float = TAU * float(i + 1) / 8.0
		var r0 := Vector3(cos(a0) * 1.4, 2.35, sin(a0) * 1.4)
		var r1 := Vector3(cos(a1) * 1.4, 2.35, sin(a1) * 1.4)
		_face(t, apex, r0, r1, r1, Vector3(0, 1, 0), paint if i % 2 == 0 else cream)
	# Tilted a little, as the sun and wind leave them.
	var tilted := MeshLayer.new()
	tilted.append(t, Transform3D(Basis(Vector3(1, 0, 0.3).normalized(), 0.12), Vector3.ZERO))
	return tilted


## A sun lounger (variant 0-2: its paint), 1.9 m long along z: a seat cushion on a frame, a raised back.
func _build_lounger(variant: int) -> MeshLayer:
	var t := MeshLayer.new()
	var frame: Color = skin.timber_color * 0.85
	var cushion: Color = _paint(variant + 1) * 0.9
	t.box(Vector3(0, 0.3, 0.2), Vector3(0.62, 0.07, 1.3), cushion, 0.0, MeshKit.PAT_PLAIN, MeshKit.NO_BOTTOM)
	t.box_xform(Transform3D(Basis(Vector3(1, 0, 0), -0.95) * Basis.from_scale(Vector3(0.62, 0.07, 0.75)), Vector3(0, 0.55, -0.82)),
		cushion * 1.05, 0.0, MeshKit.PAT_PLAIN, MeshKit.NO_BOTTOM)
	for z: float in [-0.35, 0.8]:
		t.box(Vector3(0, 0.14, z), Vector3(0.7, 0.06, 0.06), frame, 0.0, MeshKit.PAT_PLAIN, MeshKit.NO_BOTTOM)
		for x: float in [-0.3, 0.3]:
			t.box(Vector3(x, 0.13, z), Vector3(0.05, 0.26, 0.05), frame, 0.0, MeshKit.PAT_PLAIN, MeshKit.NO_BOTTOM)
	return t


## A surfboard stuck in the sand (variant 0-3: its paint), leaning a little: a flat hexagonal slab, its lower fifth
## buried.
func _build_board(variant: int) -> MeshLayer:
	var t := MeshLayer.new()
	var lean := Basis(Vector3(0, 0, 1), 0.1 * (1.0 if variant % 2 == 0 else -1.0)) * Basis(Vector3(1, 0, 0), 0.12)
	var board := lean * Basis(Vector3(0.24, 0, 0), Vector3(0, 0, 0.05), Vector3(0, 1.0, 0))
	t.prism_xform(Transform3D(board, Vector3(0, 0.8, 0)), 6, _paint(variant * 2 + 1), 0.0, MeshKit.PAT_PLAIN, true)
	return t


## A low beach hut (variant 0-2: its bamboo), its door on its +x face: bamboo walls, a thatched pyramid roof, a
## dark door.
func _build_hut(variant: int) -> MeshLayer:
	var t := MeshLayer.new()
	var bamboo: Color = skin.bamboo_colors[posmod(variant * 2 + 1, skin.bamboo_colors.size())]
	t.box(Vector3(0, 1.1, 0), Vector3(3.6, 2.2, 3.0), bamboo, 0.0, MeshKit.PAT_BEACH_WALL, MeshKit.ALL_FACES & ~MeshKit.FACE_NY,
		float((variant * 37 + 11) * 8))
	var thatch: Color = skin.thatch_color
	var apex := Vector3(0, 3.7, 0)
	var corners: Array[Vector3] = [Vector3(-2.2, 2.2, -1.8), Vector3(-2.2, 2.2, 1.8), Vector3(2.2, 2.2, 1.8), Vector3(2.2, 2.2, -1.8)]
	for i: int in 4:
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		var outward: Vector3 = ((a + b) * 0.5 + Vector3(0, 0.5, 0)).normalized()
		_face(t, apex, a, b, b, outward, thatch, MeshKit.PAT_BEACH_THATCH, 0.0)
	# The door, on the +x face.
	t.rect(Vector3(1.805, 0, 0.45), Vector3(0, 0, -0.9), Vector3(0, 1.7, 0), skin.timber_color * 0.45)
	return t
