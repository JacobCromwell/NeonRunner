class_name GanglandRuins
extends RefCounted
## Bombed-out building faces for the Gangland walls (GanglandSkin). A wall side is split into lots
## of `lot_length` metres (MeshKit.lot_run); a building covers 1–3 lots. Its face is flush with the
## wall face from the bottom of the holes up past the wall-run band: that plane is the wall-run
## surface, and facade.gdshader's ruin mode keeps it solid-looking there (shutters, boards, bricked-up
## windows). Above the band the ruins break up: crumbled tops with bites blown out of them, floor slabs
## and rebar sticking out, broken, lit and burning windows. Some side streets are barricaded with
## rusty sheet metal as high as the wall-run band needs, with a fire glowing far behind; burnt-out
## stumps let a far row of ruins show through. Nothing vent-like sits at the foot of the walls: in
## Gangland those are sewer-screech spawn points.
## The top edge follows a profile on a fixed grid of track distances, so chunk cuts never change it.

## How far the buildings reach back from the street (their near ends show across side streets).
const DEPTH: float = 24.0
const STEP: float = 2.0
const LOW_SHARE: float = 0.25
## Every face stays at least this far above the boarded-up band.
const BAND_MARGIN: float = 1.5
## Storey heights of the facade styles (facade.gdshader).
const STOREYS: Array[float] = [3.3, 3.0, 3.3, 3.3]
const STYLES: Array[int] = [1, 3, 1, 2]


## One building's shape: its broken top edge along the track.
class Ruin:
	var side: int
	var t0: float
	var b1: float
	var height: float
	var floor_top: float
	## Bites blown out of the top: (centre distance, half width, depth).
	var bites: Array[Vector3] = []

	## The top edge at distance u (linear between profile points).
	func top(u: float) -> float:
		var g: float = u / STEP
		var i: int = floori(g)
		var f: float = g - float(i)
		if f < 0.0001:
			return point(i)
		return lerpf(point(i), point(i + 1), f)

	## Piece edges from u0 to u1 (every profile point between them) and the top edge at each.
	func outline(u0: float, u1: float, us: PackedFloat32Array, tops: PackedFloat32Array) -> void:
		var u: float = u0
		us.append(u)
		tops.append(top(u))
		while u < u1 - 0.001:
			u = minf((floorf(u / STEP + 0.001) + 1.0) * STEP, u1)
			us.append(u)
			tops.append(top(u))

	func point(i: int) -> float:
		var u: float = float(i) * STEP
		var h: float = height - 0.9 * MeshKit.hash01(side, i, 41)
		for bite: Vector3 in bites:
			h -= bite.z * maxf(0.0, 1.0 - absf(u - bite.x) / bite.y)
		return maxf(h, floor_top)


## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: GanglandSkin:
	get:
		return _skin.get_ref() as GanglandSkin
var _skin: WeakRef


func _init(p_skin: GanglandSkin) -> void:
	_skin = weakref(p_skin)


## Adds the ruins of one wall side between two track distances.
func build(batch: MeshBatch, side: int, face_x: float, start: float, end: float) -> void:
	var facade: MeshLayer = batch.layer(skin.facade_material())
	var solid: MeshLayer = batch.layer(skin.solid_material())
	var glow: MeshLayer = batch.layer(skin.glow_material())
	var lot: float = skin.lot_length
	var span: Vector2i = MeshKit.lot_run(side, floori(start / lot), 0.4, 3, 2)
	while span.x * lot < end:
		_building(facade, solid, glow, side, face_x, span, start, end)
		span = MeshKit.lot_run(side, span.y + 1, 0.4, 3, 2)
	var mark_x: float = face_x - side * 0.02
	for h: float in skin.wall_height_marks:
		solid.box(Vector3(mark_x, h, -(start + end) * 0.5), Vector3(0.03, 0.05, end - start), skin.wall_mark_color, 0.12)


func _building(facade: MeshLayer, solid: MeshLayer, glow: MeshLayer, side: int, face_x: float, span: Vector2i,
		start: float, end: float) -> void:
	var lot: float = skin.lot_length
	var b0: float = span.x * lot
	var id: int = span.x
	var alley: float = 0.0 if MeshKit.hash01(side, id, 4) < 0.55 else 3.0 + 3.0 * MeshKit.hash01(side, id, 5)
	var r := Ruin.new()
	r.side = side
	r.t0 = b0 + alley
	r.b1 = (span.y + 1) * lot
	r.floor_top = skin.boarded_below + BAND_MARGIN
	var low: bool = MeshKit.hash01(side, id, 20) < LOW_SHARE
	if low:
		r.height = r.floor_top + 0.6 + 1.8 * MeshKit.hash01(side, id, 2)
	else:
		r.height = lerpf(skin.building_min_height, skin.building_max_height, pow(MeshKit.hash01(side, id, 2), 1.2))
		var bites: int = MeshKit.hash_i(side, id, 30) % 3
		for i: int in bites:
			var half: float = 2.5 + 3.0 * MeshKit.hash01(side, id, 31 + i)
			var c: float = lerpf(r.t0 + half * 0.5, r.b1 - half * 0.5, MeshKit.hash01(side, id, 34 + i))
			var depth: float = (r.height - r.floor_top) * (0.35 + 0.6 * MeshKit.hash01(side, id, 37 + i))
			r.bites.append(Vector3(c, half, depth))
	var style: int = STYLES[MeshKit.hash_i(side, id, 7) % STYLES.size()]
	var lit: float = 0.04 + 0.1 * MeshKit.hash01(side, id, 8)
	var wall: Color = skin.facade_colors[MeshKit.hash_i(side, id, 9) % skin.facade_colors.size()]
	# Whole numbers: the facade shader rounds the seed before hashing it.
	var seed: float = float(MeshKit.hash_i(side, id, 11) % 997)
	var bottom: float = -skin.crater_depth

	if alley > 0.0:
		_barricade(solid, glow, side, face_x, b0, r.t0, start, end, id)
	# The face, in pieces between profile points.
	var u0: float = maxf(r.t0, start)
	var u1: float = minf(r.b1, end)
	if u1 > u0 + 0.001:
		var us := PackedFloat32Array()
		var tops := PackedFloat32Array()
		r.outline(u0, u1, us, tops)
		MeshKit.facade_strip(facade, side, face_x, us, tops, bottom, wall, lit, style, seed)
	# The near end, seen across side streets and above lower neighbours.
	if r.t0 >= start and r.t0 < end:
		var x_min: float = minf(face_x, face_x + side * DEPTH)
		var end_top: float = r.top(r.t0)
		facade.rect(Vector3(x_min, bottom, -r.t0), Vector3(DEPTH, 0, 0), Vector3(0, end_top - bottom, 0), wall, lit,
			style, Vector2(x_min, bottom), Vector2(x_min + DEPTH, end_top), seed + 3.0)
	for bite: Vector3 in r.bites:
		_broken_floors(solid, r, bite, side, face_x, STOREYS[style], wall, start, end)
	if low:
		_far_row(facade, side, face_x, b0, r.b1, start, end, id, seed)


## Floor slabs sticking out on both sides of a bite, one per storey, with rebar at their broken ends.
func _broken_floors(solid: MeshLayer, r: Ruin, bite: Vector3, side: int, face_x: float, storey: float, wall: Color,
		start: float, end: float) -> void:
	var slab: Color = wall.lightened(0.12)
	var k: int = ceili((r.height - bite.z + 0.4) / storey)
	while float(k) * storey < r.height - 0.6:
		var y: float = float(k) * storey
		# Where the bite's V is below this floor.
		var open: float = bite.y * (1.0 - (r.height - y) / bite.z)
		if open > 0.4:
			for dir: float in [-1.0, 1.0]:
				var stub: float = open * (0.25 + 0.4 * MeshKit.hash01(k, MeshKit.key(bite.x), 50 + int(dir)))
				var edge: float = bite.x + dir * open
				var a: float = maxf(minf(edge, edge - dir * stub), maxf(start, r.t0))
				var b: float = minf(maxf(edge, edge - dir * stub), minf(end, r.b1))
				if b - a > 0.05:
					solid.box(Vector3(face_x + side * 0.9, y - 0.12, -(a + b) * 0.5), Vector3(1.8, 0.24, b - a), slab)
					var tip: float = edge - dir * stub
					if tip >= start and tip < end:
						solid.box(Vector3(face_x + side * 0.3, y - 0.1, -tip + dir * 0.25), Vector3(0.03, 0.03, 0.5),
							skin.rust_color.darkened(0.3))
		k += 1


## Rusty sheet metal barricading a side street, flush with the wall face (part of the wall-run surface)
## and topped with sheets of uneven height. A fire glows far down the street behind it.
func _barricade(solid: MeshLayer, glow: MeshLayer, side: int, face_x: float, a0: float, a1: float,
		start: float, end: float, id: int) -> void:
	var bottom: float = -skin.crater_depth
	var sheet: float = 1.6
	var u: float = maxf(a0, start)
	var u1: float = minf(a1, end)
	while u < u1 - 0.001:
		var cell: int = floori(u / sheet + 0.001)
		var next: float = minf(float(cell + 1) * sheet, u1)
		var h: float = skin.boarded_below - 0.4 + 1.3 * MeshKit.hash01(side, cell, 61)
		var tone: float = 0.85 + 0.3 * MeshKit.hash01(side, cell, 62)
		MeshKit.facade_quad(solid, side, face_x, u, next, bottom, h, h, skin.barricade_color * Color(tone, tone, tone),
			0.0, MeshKit.PAT_RUST, 0.22)
		u = next
	var mid: float = (a0 + a1) * 0.5
	if mid >= start and mid < end and MeshKit.hash01(side, id, 63) < 0.6:
		var fx: float = face_x + side * (7.0 + 5.0 * MeshKit.hash01(side, id, 64))
		glow.rect(Vector3(fx, 3.5, -mid + 3.0), Vector3(0, 0, -6.0), Vector3(0, 7.0, 0), skin.fire_color, 0.22,
			MeshKit.SHAPE_RADIAL)


## Behind a burnt-out stump: a far row of taller ruins with crumbled tops.
func _far_row(facade: MeshLayer, side: int, face_x: float, b0: float, b1: float, start: float, end: float, id: int,
		seed: float) -> void:
	var r := Ruin.new()
	r.side = side * 3
	r.height = 26.0 + 34.0 * MeshKit.hash01(side, id, 21)
	r.floor_top = r.height * 0.6
	var x: float = face_x + side * (22.0 + 20.0 * MeshKit.hash01(side, id, 22))
	var wall: Color = skin.facade_colors[MeshKit.hash_i(side, id, 23) % skin.facade_colors.size()].darkened(0.2)
	var style: int = STYLES[MeshKit.hash_i(side, id, 24) % STYLES.size()]
	var u0: float = maxf(b0 - 2.0, start)
	var u1: float = minf(b1 + 2.0, end)
	if u1 > u0 + 0.001:
		var us := PackedFloat32Array()
		var tops := PackedFloat32Array()
		r.outline(u0, u1, us, tops)
		MeshKit.facade_strip(facade, side, x, us, tops, 8.0, wall, 0.06, style, seed + 11.0)
