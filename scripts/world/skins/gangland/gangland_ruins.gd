class_name GanglandRuins
extends RefCounted
## Bombed-out building faces for the Gangland walls (GanglandSkin). A wall side is split into lots
## of `lot_length` metres (MeshKit.lot_run); a building covers 1–3 lots. Its face is flush with the
## wall face from the bottom of the holes up past the wall-run band: that plane is the wall-run
## surface, and facade.gdshader's ruin mode keeps it solid-looking there (shutters, boards, bricked-up
## windows, all of it tagged with graffiti). Above the band the ruins break up: crumbled tops with
## bites blown out of them, floor slabs and rebar sticking out, broken, lit (curtained) and burning
## windows. Burnt-out stumps let a far row of ruins show through.
## Signs of life: makeshift balconies hung with laundry, water tanks, antennas and dishes on the roofs,
## bulbs strung over the side streets, and washing lines across the street high above the play space
## (across()). Hints of who funds the gangs: side streets barricaded with stacked military supply
## crates or corporate containers (their stencils and logos facing the street) instead of rusty
## sheets, corporate ads pasted on the sheets, and military notice boards above the band.
## Nothing vent-like sits at the foot of the walls (in Gangland those are sewer-screech spawn
## points), no window opens in the wall-run band (window cyborgs lean out of lit openings), and every
## prop on a facade stays above the band or flush with the wall face.
## The top edge follows a profile on a fixed grid of track distances, so chunk cuts never change it;
## props belong to the chunk holding their anchor distance.

## How far the buildings reach back from the street (their near ends show across side streets).
const DEPTH: float = 24.0
const STEP: float = 2.0
const LOW_SHARE: float = 0.25
## Every face stays at least this far above the boarded-up band.
const BAND_MARGIN: float = 1.5
## Storey heights and window cell widths of the facade styles (facade.gdshader).
const STOREYS: Array[float] = [3.3, 3.0, 3.3, 3.3]
const CELL_WIDTHS: Array[float] = [1.3, 2.2, 4.0, 1.6]
const STYLES: Array[int] = [1, 3, 1, 2]
## Washing lines across the street are strung at least this high and sag CROSS_LINE_SAG, so their
## laundry (under a metre) hangs above every ceiling (GanglandCeiling.ABOVE_LIMIT over the ceiling
## height); at most one per CROSS_LINE_SLOT metres.
const CROSS_LINE_MIN: float = 15.4
const CROSS_LINE_SAG: float = 0.5
const CROSS_LINE_SLOT: float = 30.0
## Container doors, and military crates as seen from the front.
const CONTAINER := Vector2(2.44, 2.59)
const CRATE := Vector2(1.2, 0.9)


## One building's shape: its broken top edge along the track.
class Ruin:
	var side: int
	var t0: float
	var b1: float
	var height: float
	var floor_top: float
	var low: bool
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


## The building covering lots span.x to span.y on this side.
func ruin_for(side: int, span: Vector2i) -> Ruin:
	var lot: float = skin.lot_length
	var id: int = span.x
	var alley: float = 0.0 if MeshKit.hash01(side, id, 4) < 0.55 else 3.0 + 3.0 * MeshKit.hash01(side, id, 5)
	var r := Ruin.new()
	r.side = side
	r.t0 = span.x * lot + alley
	r.b1 = (span.y + 1) * lot
	r.floor_top = skin.boarded_below + BAND_MARGIN
	r.low = MeshKit.hash01(side, id, 20) < LOW_SHARE
	if r.low:
		r.height = r.floor_top + 0.6 + 1.8 * MeshKit.hash01(side, id, 2)
	else:
		r.height = lerpf(skin.building_min_height, skin.building_max_height, pow(MeshKit.hash01(side, id, 2), 1.2))
		var bites: int = MeshKit.hash_i(side, id, 30) % 3
		for i: int in bites:
			var half: float = 2.5 + 3.0 * MeshKit.hash01(side, id, 31 + i)
			var c: float = lerpf(r.t0 + half * 0.5, r.b1 - half * 0.5, MeshKit.hash01(side, id, 34 + i))
			var depth: float = (r.height - r.floor_top) * (0.35 + 0.6 * MeshKit.hash01(side, id, 37 + i))
			r.bites.append(Vector3(c, half, depth))
	return r


## The height of the wall's top at track distance u on this side (0 across a side street).
func top_at(side: int, u: float) -> float:
	var r: Ruin = ruin_for(side, MeshKit.lot_run(side, floori(u / skin.lot_length), 0.4, 3, 2))
	return r.top(u) if u >= r.t0 else 0.0


func _building(facade: MeshLayer, solid: MeshLayer, glow: MeshLayer, side: int, face_x: float, span: Vector2i,
		start: float, end: float) -> void:
	var lot: float = skin.lot_length
	var b0: float = span.x * lot
	var id: int = span.x
	var r: Ruin = ruin_for(side, span)
	var style: int = STYLES[MeshKit.hash_i(side, id, 7) % STYLES.size()]
	var lit: float = lerpf(skin.ruin_lit_min, skin.ruin_lit_max, MeshKit.hash01(side, id, 8))
	var wall: Color = skin.facade_colors[MeshKit.hash_i(side, id, 9) % skin.facade_colors.size()]
	# Whole numbers: the facade shader rounds the seed before hashing it.
	var seed: float = float(MeshKit.hash_i(side, id, 11) % 997)
	var bottom: float = -skin.crater_depth

	if r.t0 > b0:
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
	if r.low:
		_far_row(facade, side, face_x, b0, r.b1, start, end, id, seed)
		_rooftop(solid, r, side, face_x, start, end, id)
	else:
		_balconies(solid, r, side, face_x, style, start, end, id)
		_notice_board(solid, r, side, face_x, start, end, id)
		if MeshKit.hash01(side, id, 90) < skin.rooftop_share * 0.5:
			var u: float = lerpf(r.t0 + 2.0, r.b1 - 2.0, MeshKit.hash01(side, id, 91))
			if u >= start and u < end:
				GanglandClutter.antenna(solid, Vector3(face_x + side * 3.0, r.top(u) - 0.4, -u), 3.0 + 3.0 *
					MeshKit.hash01(side, id, 92), skin.scrap_metal_color, id)


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


# --- Side streets -------------------------------------------------------------------------

## A side street barricaded flush with the wall face (part of the wall-run surface) up to the height
## the wall-run band needs: rusty sheet metal with corporate ads pasted on, or stacked military supply
## crates or corporate containers under a few sheets. Below the street it's rubble, seen in holes.
## Bulbs are strung across the opening above it, and a fire glows far down the street behind it.
func _barricade(solid: MeshLayer, glow: MeshLayer, side: int, face_x: float, a0: float, a1: float,
		start: float, end: float, id: int) -> void:
	var bottom: float = -skin.crater_depth
	var p0: float = maxf(a0, start)
	var p1: float = minf(a1, end)
	var pick: float = MeshKit.hash01(side, id, 65)
	var stacked: float = 0.0
	if p1 > p0 + 0.001:
		if pick < skin.crate_barricade_share + skin.container_barricade_share:
			if pick < skin.crate_barricade_share:
				stacked = _crate_wall(solid, side, face_x, a0, a1, start, end, id)
			else:
				stacked = _container_wall(solid, side, face_x, a0, a1, start, end, id)
			MeshKit.facade_quad(solid, side, face_x, p0, p1, bottom, 0.0, 0.0, skin.earth_color, 0.0,
				MeshKit.PAT_STRATA, 0.0)
			# A dark backing shows in the joints between the crates or containers.
			MeshKit.facade_quad(solid, side, face_x + side * 0.03, p0, p1, 0.0, stacked, stacked,
				Color(0.05, 0.045, 0.04), 0.0, MeshKit.PAT_PLAIN, 0.0)
		_sheets(solid, side, face_x, a0, a1, start, end, stacked, bottom if stacked == 0.0 else stacked)
	var mid: float = (a0 + a1) * 0.5
	if mid >= start and mid < end:
		if MeshKit.hash01(side, id, 63) < 0.6:
			var fx: float = face_x + side * (7.0 + 5.0 * MeshKit.hash01(side, id, 64))
			glow.rect(Vector3(fx, 3.5, -mid + 3.0), Vector3(0, 0, -6.0), Vector3(0, 7.0, 0), skin.fire_color, 0.22,
				MeshKit.SHAPE_RADIAL)
		if MeshKit.hash01(side, id, 66) < skin.bulb_share:
			_bulbs(solid, glow, side, face_x, a0, a1, id)


## Rusty sheets from y0 up to an uneven top, as high as the wall-run band needs, some with an ad or a
## poster pasted on.
func _sheets(solid: MeshLayer, side: int, face_x: float, a0: float, a1: float, start: float, end: float,
		stacked: float, y0: float) -> void:
	var sheet: float = 1.6
	var u: float = maxf(a0, start)
	var u1: float = minf(a1, end)
	while u < u1 - 0.001:
		var cell: int = floori(u / sheet + 0.001)
		var next: float = minf(float(cell + 1) * sheet, u1)
		var h: float = skin.boarded_below - 0.4 + 1.3 * MeshKit.hash01(side, cell, 61)
		var tone: float = 0.85 + 0.3 * MeshKit.hash01(side, cell, 62)
		MeshKit.facade_quad(solid, side, face_x, u, next, y0, h, h, skin.barricade_color * Color(tone, tone, tone),
			0.0, MeshKit.PAT_RUST, 0.22)
		# A poster (or an ad) pasted on a whole sheet at eye height.
		if stacked == 0.0 and MeshKit.hash01(side, cell, 67) < 0.35 and next - u > sheet - 0.01:
			var content: Color = skin.sign_content_colors[MeshKit.hash_i(side, cell, 68) % skin.sign_content_colors.size()]
			_wall_rect(solid, side, face_x - side * 0.012, u + 0.2, next - 0.2, 1.3, 3.0, content, MeshKit.PAT_POSTER,
				u + 0.2, float(MeshKit.hash_i(side, cell, 69) % 97), false)
		u = next


## Stacked military supply crates filling the opening up to about half the band. Returns their top.
func _crate_wall(solid: MeshLayer, side: int, face_x: float, a0: float, a1: float, start: float, end: float,
		id: int) -> float:
	var rows: int = 3 + MeshKit.hash_i(side, id, 70) % 2
	for row: int in rows:
		# Alternate rows shift half a crate, like stacked boxes.
		var shift: float = CRATE.x * 0.5 * float(row % 2)
		var c: int = floori((a0 - shift) / CRATE.x)
		while float(c) * CRATE.x + shift < a1:
			var c0: float = maxf(float(c) * CRATE.x + shift + 0.03, maxf(a0, start))
			var c1: float = minf(float(c + 1) * CRATE.x + shift - 0.03, minf(a1, end))
			if c1 > c0 + 0.05:
				var k: int = MeshKit.hash_i(side, c, 71 + row)
				var color: Color = skin.military_crate_colors[k % skin.military_crate_colors.size()]
				var kind: int = MeshKit.STENCIL_LOGO if MeshKit.hash01(side, c, 80 + row) < 0.2 else MeshKit.STENCIL_CODE
				var cult: bool = MeshKit.hash01(side, c, 90 + row) < skin.cult_emblem_share * 0.5
				_wall_rect(solid, side, face_x - side * 0.004, c0, c1, float(row) * CRATE.y + 0.03,
					float(row + 1) * CRATE.y - 0.03, color, MeshKit.PAT_STENCIL, (float(c) + 0.5) * CRATE.x + shift,
					MeshKit.stencil_param(kind, 0, k, cult), true)
			c += 1
	return float(rows) * CRATE.y


## Corporate containers stacked two high, doors to the street with the logo on them. Returns their top.
func _container_wall(solid: MeshLayer, side: int, face_x: float, a0: float, a1: float, start: float, end: float,
		id: int) -> float:
	var rows: int = 2
	var shift: float = CONTAINER.x * MeshKit.hash01(side, id, 72)
	for row: int in rows:
		var c: int = floori((a0 - shift) / CONTAINER.x)
		while float(c) * CONTAINER.x + shift < a1:
			var c0: float = maxf(float(c) * CONTAINER.x + shift + 0.05, maxf(a0, start))
			var c1: float = minf(float(c + 1) * CONTAINER.x + shift - 0.05, minf(a1, end))
			if c1 > c0 + 0.05:
				var k: int = MeshKit.hash_i(side, c, 73 + row)
				var color: Color = skin.container_colors[k % skin.container_colors.size()]
				var cult: bool = MeshKit.hash01(side, c, 95 + row) < skin.cult_emblem_share
				_wall_rect(solid, side, face_x - side * 0.004, c0, c1, float(row) * CONTAINER.y + 0.04,
					float(row + 1) * CONTAINER.y - 0.04, color, MeshKit.PAT_STENCIL,
					(float(c) + 0.5) * CONTAINER.x + shift,
					MeshKit.stencil_param(MeshKit.STENCIL_LOGO_CORRUGATED, 2, k, cult), true)
			c += 1
	return float(rows) * CONTAINER.y


## Bulbs strung across a side street's opening above its barricade, sagging a little.
func _bulbs(solid: MeshLayer, glow: MeshLayer, side: int, face_x: float, a0: float, a1: float, id: int) -> void:
	var y: float = skin.boarded_below + 1.2 + 0.8 * MeshKit.hash01(side, id, 67)
	var x: float = face_x + side * 0.5
	var a := Vector3(x, y, -a0)
	var b := Vector3(x, y, -a1)
	GanglandClutter.laundry_line(solid, a, b, 0.3, PackedColorArray(), id, skin.line_color)
	var count: int = maxi(2, floori((a1 - a0) / 0.8))
	for i: int in count:
		var t: float = (float(i) + 0.5) / float(count)
		var at: Vector3 = a.lerp(b, t) - Vector3(0, 0.3 * (1.0 - pow(2.0 * t - 1.0, 2.0)) + 0.1, 0)
		solid.box(at, Vector3(0.09, 0.12, 0.09), skin.bulb_color, 0.9)
		glow.rect(at + Vector3(0, -0.45, 0.45), Vector3(0, 0, -0.9), Vector3(0, 0.9, 0), skin.bulb_color, 0.22,
			MeshKit.SHAPE_RADIAL)


## A rectangle in the wall plane at x facing the street, from distance u0 to u1 and height y0 to y1.
## UV is in metres, reading left to right from the street: centred on distance `uc` (and the
## rectangle's middle height) when `centred`, else starting at uc.
func _wall_rect(solid: MeshLayer, side: int, x: float, u0: float, u1: float, y0: float, y1: float, color: Color,
		pattern: int, uc: float, param: float, centred: bool) -> void:
	var h: float = y1 - y0
	var vy0: float = -h * 0.5 if centred else 0.0
	if side < 0:
		solid.rect(Vector3(x, y0, -u0), Vector3(0, 0, -(u1 - u0)), Vector3(0, h, 0), color, 0.0, pattern,
			Vector2(u0 - uc, vy0), Vector2(u1 - uc, vy0 + h), param)
	else:
		solid.rect(Vector3(x, y0, -u1), Vector3(0, 0, u1 - u0), Vector3(0, h, 0), color, 0.0, pattern,
			Vector2(uc - u1, vy0) if centred else Vector2(0.0, vy0), Vector2(uc - u0, vy0 + h) if centred
			else Vector2(u1 - u0, vy0 + h), param)


# --- Life on the facades --------------------------------------------------------------------

## Makeshift balconies on some window bays above the band: a slab, a rail with laundry on it.
func _balconies(solid: MeshLayer, r: Ruin, side: int, face_x: float, style: int, start: float, end: float,
		id: int) -> void:
	if MeshKit.hash01(side, id, 93) >= skin.balcony_share:
		return
	var storey: float = STOREYS[style]
	var cell: float = CELL_WIDTHS[style]
	var count: int = 1 + MeshKit.hash_i(side, id, 94) % 3
	for i: int in count:
		var level: int = ceili((skin.boarded_below + 1.4) / storey) + MeshKit.hash_i(side, id, 95 + i) % 3
		var y: float = float(level) * storey
		var u: float = (floorf(lerpf(r.t0 + 1.5, r.b1 - 1.5, MeshKit.hash01(side, id, 98 + i)) / cell) + 0.5) * cell
		var w: float = clampf(cell * 0.95, 1.5, 3.6)
		if u < start or u >= end or u - w * 0.5 < r.t0 or u + w * 0.5 > r.b1 or y + 2.6 > r.top(u) - 0.5:
			continue
		var d: float = 0.95
		var fx: float = face_x - side * d * 0.5
		var rust: Color = skin.scrap_metal_color
		solid.box(Vector3(fx, y + 0.06, -u), Vector3(d, 0.12, w), skin.rubble_color.darkened(0.1), 0.0, MeshKit.PAT_PLAIN)
		var rail_x: float = face_x - side * (d - 0.04)
		solid.box(Vector3(rail_x, y + 1.0, -u), Vector3(0.05, 0.05, w), rust)
		for end_z: float in [-w * 0.5 + 0.03, w * 0.5 - 0.03]:
			solid.box(Vector3(rail_x, y + 0.53, -u + end_z), Vector3(0.05, 0.94, 0.05), rust)
		var k: int = MeshKit.hash_i(side, id, 101 + i)
		if k % 3 == 0:
			# Half of it screened with a sheet of scrap.
			_wall_rect(solid, side, rail_x - side * 0.03, u - w * 0.5 + 0.05, u + w * 0.5 - 0.05, y + 0.12, y + 0.95,
				skin.barricade_color, MeshKit.PAT_RUST, u, 0.0, false)
		else:
			for j: int in 2 + k % 2:
				var cz: float = -u - w * 0.5 + (float(j) + 0.6) * w / (2.0 + float(k % 2))
				GanglandClutter.cloth(solid, Vector3(rail_x - side * 0.03, y + 1.02, cz), 0.4 + 0.3 * MeshKit.hash01(k, j, 1),
					0.5 + 0.3 * MeshKit.hash01(k, j, 2), skin.cloth_colors[MeshKit.hash_i(k, j, 3) % skin.cloth_colors.size()],
					false)


## A military notice board bolted to the facade above the band: an olive panel with a stencilled code.
func _notice_board(solid: MeshLayer, r: Ruin, side: int, face_x: float, start: float, end: float, id: int) -> void:
	if MeshKit.hash01(side, id, 110) >= skin.notice_share:
		return
	var u: float = lerpf(r.t0 + 1.5, r.b1 - 1.5, MeshKit.hash01(side, id, 111))
	var y: float = skin.boarded_below + 1.2 + 1.2 * MeshKit.hash01(side, id, 112)
	var w: float = 2.2
	var h: float = 1.1
	if u < start or u >= end or u - w * 0.5 < r.t0 or u + w * 0.5 > r.b1 or y + h > r.top(u) - 0.5:
		return
	var color: Color = skin.military_crate_colors[MeshKit.hash_i(side, id, 113) % skin.military_crate_colors.size()]
	var cult: bool = MeshKit.hash01(side, id, 115) < skin.cult_emblem_share
	solid.box(Vector3(face_x - side * 0.04, y + h * 0.5, -u), Vector3(0.08, h + 0.1, w + 0.1), color.darkened(0.3))
	_wall_rect(solid, side, face_x - side * 0.082, u - w * 0.5, u + w * 0.5, y, y + h, color, MeshKit.PAT_STENCIL, u,
		MeshKit.stencil_param(MeshKit.STENCIL_CODE, 1, MeshKit.hash_i(side, id, 114), cult), true)


## Life on a low building's roof: water tanks, antennas, dishes, crates, a washing line.
func _rooftop(solid: MeshLayer, r: Ruin, side: int, face_x: float, start: float, end: float, id: int) -> void:
	if MeshKit.hash01(side, id, 120) >= skin.rooftop_share:
		return
	var count: int = 1 + MeshKit.hash_i(side, id, 121) % 3
	for i: int in count:
		var u: float = lerpf(r.t0 + 1.5, r.b1 - 1.5, MeshKit.hash01(side, id, 122 + i))
		if u < start or u >= end:
			continue
		var y: float = r.top(u) - 0.15
		var foot := Vector3(face_x + side * (2.0 + 4.0 * MeshKit.hash01(side, id, 125 + i)), y, -u)
		var k: int = MeshKit.hash_i(side, id, 128 + i)
		match k % 5:
			0:
				GanglandClutter.water_tank(solid, foot, 0.8 + 0.3 * MeshKit.hash01(k, 1), 1.3, skin.wreck_color)
			1:
				GanglandClutter.antenna(solid, foot, 3.0 + 3.0 * MeshKit.hash01(k, 2), skin.scrap_metal_color, k)
			2:
				GanglandClutter.dish(solid, foot, 0.7 + 0.3 * MeshKit.hash01(k, 3), Vector3(-side, 0, 0),
					skin.scrap_metal_color.lightened(0.25))
			3:
				GanglandClutter.crate_stack(solid, foot, Vector3(-side, 0, 0), skin.military_crate_colors, k,
					skin.cult_emblem_share)
			_:
				var a: Vector3 = foot + Vector3(0, 1.6, 1.6)
				var b: Vector3 = foot + Vector3(0, 1.6, -1.6)
				for p: Vector3 in [a, b]:
					solid.box(p - Vector3(0, 0.8, 0), Vector3(0.06, 1.6, 0.06), skin.scrap_metal_color)
				GanglandClutter.laundry_line(solid, a, b, 0.2, skin.cloth_colors, k, skin.line_color)


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


# --- Across the street ----------------------------------------------------------------------

## Washing lines strung across the street between facades tall enough to hold them, high above the
## play space and every ceiling, for one chunk (both sides: the skin adds them to the left wall).
func across(batch: MeshBatch, half_width: float, start: float, end: float) -> void:
	var solid: MeshLayer = batch.layer(skin.solid_material())
	var slot: int = floori(start / CROSS_LINE_SLOT)
	while float(slot) * CROSS_LINE_SLOT < end:
		if MeshKit.hash01(slot, 132) < skin.cross_line_share:
			# Two tries per slot for a spot where both facades stand tall enough.
			for attempt: int in 2:
				var u: float = (float(slot) + 0.1 + 0.8 * MeshKit.hash01(slot, 131 + attempt * 10)) * CROSS_LINE_SLOT
				var y: float = CROSS_LINE_MIN + 2.0 * MeshKit.hash01(slot, 133 + attempt * 10)
				var skew: float = (MeshKit.hash01(slot, 134 + attempt * 10) - 0.5) * 4.0
				if top_at(-1, u) > y + 0.3 and top_at(1, u + skew) > y + 0.3:
					if u >= start and u < end:
						GanglandClutter.laundry_line(solid, Vector3(-half_width + 0.05, y, -u), Vector3(half_width - 0.05,
							y, -u - skew), CROSS_LINE_SAG, skin.cloth_colors, slot, skin.line_color)
					break
		slot += 1
