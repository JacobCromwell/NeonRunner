class_name CityTowers
extends RefCounted
## Building facades for the city walls (CitySkin), plus the road far below the track.
## The street side of each wall is split into lots of `lot_length` metres; a building covers 1–3
## lots (a hash of the lot index decides where buildings start, and every third lot always starts
## one, so finding a building never looks back more than two lots). Every building has a podium,
## flush with the wall face from the street far below up past the wall-run band: that plane is
## the wall-run surface. Above it most buildings raise a tower, often stepped back or behind an
## alley; some stay low with a neon billboard on the roof and a far row of towers behind, so the
## city opens up overhead. Windows come from facade.gdshader, so a facade is a handful of quads.

## How far buildings reach back from the street (their end faces show across alleys).
const DEPTH: float = 28.0
const SETBACKS: Array[float] = [0.0, 0.0, 4.0, 8.0, 12.0, 16.0]
## Share of buildings that stay low (podium only).
const LOW_SHARE: float = 0.22

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: CitySkin:
	get:
		return _skin.get_ref() as CitySkin
var _skin: WeakRef


func _init(p_skin: CitySkin) -> void:
	_skin = weakref(p_skin)


## Adds the facades of one wall side between two track distances.
func build(batch: MeshBatch, side: int, face_x: float, start: float, end: float) -> void:
	var facade: MeshLayer = batch.layer(skin.facade_material())
	var solid: MeshLayer = batch.layer(skin.solid_material())
	var glow: MeshLayer = batch.layer(skin.glow_material())
	var lot: float = skin.lot_length
	var span: Vector2i = building_at(side, floori(start / lot))
	while span.x * lot < end:
		_building(facade, solid, glow, side, face_x, span, start, end)
		span = building_at(side, span.y + 1)
	var mark_x: float = face_x - side * 0.02
	for h: float in skin.wall_height_marks:
		solid.box(Vector3(mark_x, h, -(start + end) * 0.5), Vector3(0.03, 0.05, end - start), skin.wall_mark_color, 0.28)
	if side < 0:
		var w: float = absf(face_x)
		batch.layer(skin.road_material()).rect(Vector3(-w, -skin.road_depth, -start), Vector3(w * 2.0, 0, 0),
			Vector3(0, 0, -(end - start)), skin.road_color)


## The first and last lot of the building covering `lot_index` on this side.
func building_at(side: int, lot_index: int) -> Vector2i:
	var first: int = lot_index
	while not _starts_building(side, first):
		first -= 1
	var last: int = lot_index
	while not _starts_building(side, last + 1):
		last += 1
	return Vector2i(first, last)


func _starts_building(side: int, lot_index: int) -> bool:
	return posmod(lot_index, 3) == 0 or MeshKit.hash01(side, lot_index, 1) < 0.45


func _building(facade: MeshLayer, solid: MeshLayer, glow: MeshLayer, side: int, face_x: float,
		span: Vector2i, start: float, end: float) -> void:
	var lot: float = skin.lot_length
	var b0: float = span.x * lot
	var b1: float = (span.y + 1) * lot
	var u0: float = maxf(b0, start)
	var u1: float = minf(b1, end)
	if u1 <= u0:
		return
	var id: int = span.x
	var low: bool = MeshKit.hash01(side, id, 20) < LOW_SHARE
	var podium_top: float = 7.5 + 5.0 * MeshKit.hash01(side, id, 6)
	var height: float = lerpf(skin.building_min_height, skin.building_max_height, pow(MeshKit.hash01(side, id, 2), 1.4))
	var setback: float = SETBACKS[MeshKit.hash_i(side, id, 3) % SETBACKS.size()]
	var alley: float = 0.0 if MeshKit.hash01(side, id, 4) < 0.4 else 2.0 + 5.0 * MeshKit.hash01(side, id, 5)
	var style: int = MeshKit.hash_i(side, id, 7) % 4
	var lit: float = 0.3 + 0.4 * MeshKit.hash01(side, id, 8)
	var wall: Color = _pick(skin.facade_colors, side, id, 9)
	var accent: Color = _pick(skin.neon_colors, side, id, 10)
	# Whole numbers: the facade shader rounds the seed before hashing it.
	var seed: float = float(MeshKit.hash_i(side, id, 11) % 997)
	var road_y: float = -skin.road_depth
	var split: bool = low or setback > 0.0 or alley > 0.0
	var zc: float = -(u0 + u1) * 0.5

	# Podium, flush with the wall face; shop signs glowing deep below; a neon line along its top.
	_facade(facade, side, face_x, u0, u1, road_y, podium_top if split else height, wall, lit, style, seed)
	if u1 - u0 > 1.5:
		solid.box(Vector3(face_x - side * 0.04, road_y + 3.2, zc), Vector3(0.05, 0.35, u1 - u0 - 1.0), accent, 0.35)
	solid.box(Vector3(face_x - side * 0.03, podium_top - 0.1, zc), Vector3(0.06, 0.12, u1 - u0), accent, 0.45)

	if low:
		_low_building(facade, solid, glow, side, face_x, b0, b1, start, end, podium_top, id, seed)
		return

	var tower_x: float = face_x + side * setback
	var t0: float = b0 + alley
	var base_y: float = podium_top if split else road_y
	if split and u1 > maxf(t0, start):
		_facade(facade, side, tower_x, maxf(t0, start), u1, podium_top, height, wall, lit, style, seed)
	# The tower's near side, seen across alleys, setbacks and lower neighbours.
	if t0 >= start and t0 < end:
		var x_min: float = minf(tower_x, tower_x + side * DEPTH)
		facade.rect(Vector3(x_min, base_y, -t0), Vector3(DEPTH, 0, 0), Vector3(0, height - base_y, 0),
			wall, lit, style, Vector2(x_min, base_y), Vector2(x_min + DEPTH, height), seed + 3.0)

	# Neon on the tower: corner strips, bands up the height, a crown.
	var c0: float = maxf(t0, start)
	var strip_y: float = podium_top if split else 0.0
	if MeshKit.hash01(side, id, 12) < 0.75:
		for edge: float in [t0, b1 - 0.2]:
			if edge >= start and edge < end:
				solid.box(Vector3(tower_x - side * 0.05, (strip_y + height) * 0.5, -edge - 0.1),
					Vector3(0.1, height - strip_y, 0.2), accent, 0.6)
	if u1 > c0:
		var tz: float = -(c0 + u1) * 0.5
		if MeshKit.hash01(side, id, 13) < 0.7:
			solid.box(Vector3(tower_x - side * 0.04, height - 0.25, tz), Vector3(0.08, 0.16, u1 - c0), accent, 0.55)
		if MeshKit.hash01(side, id, 18) < 0.5:
			var step: float = 14.0 + 12.0 * MeshKit.hash01(side, id, 19)
			var band: float = podium_top + step
			while band < height - 6.0:
				solid.box(Vector3(tower_x - side * 0.04, band, tz), Vector3(0.06, 0.1, u1 - c0), accent, 0.4)
				band += step

	# A tall decorative neon banner on many towers, above the play space. Flush and unframed,
	# so it never reads as a hazard sign.
	var banner_d: float = t0 + 2.0 + 4.0 * MeshKit.hash01(side, id, 14)
	var banner_y: float = podium_top + 2.0
	if MeshKit.hash01(side, id, 15) < 0.6 and banner_d >= start and banner_d < end and banner_d + 2.4 < b1 \
			and height > banner_y + 14.0:
		_banner(solid, glow, side, tower_x, banner_d, banner_y, accent)

	# Antenna with a red aircraft beacon.
	var mid: float = (t0 + b1) * 0.5
	if MeshKit.hash01(side, id, 16) < 0.45 and mid >= start and mid < end:
		var ax: float = tower_x + side * 6.0
		var ah: float = 6.0 + 10.0 * MeshKit.hash01(side, id, 17)
		solid.box(Vector3(ax, height + ah * 0.5, -mid), Vector3(0.25, ah, 0.25), Color(0.08, 0.08, 0.1))
		solid.box(Vector3(ax, height + ah + 0.2, -mid), Vector3(0.4, 0.4, 0.4), skin.beacon_color, 1.0)
		glow.rect(Vector3(ax - 2.0, height + ah - 1.8, -mid), Vector3(4.0, 0, 0), Vector3(0, 4.0, 0), skin.beacon_color,
			0.45, MeshKit.SHAPE_RADIAL)


## A low building: a neon billboard on the roof and a far row of towers behind it.
func _low_building(facade: MeshLayer, solid: MeshLayer, glow: MeshLayer, side: int, face_x: float,
		b0: float, b1: float, start: float, end: float, roof_y: float, id: int, seed: float) -> void:
	var u0: float = maxf(b0 - 2.0, start)
	var u1: float = minf(b1 + 2.0, end)
	var far_x: float = face_x + side * (24.0 + 22.0 * MeshKit.hash01(side, id, 21))
	var far_h: float = lerpf(60.0, skin.building_max_height + 30.0, MeshKit.hash01(side, id, 22))
	_facade(facade, side, far_x, u0, u1, roof_y - 1.0, far_h, _pick(skin.facade_colors, side, id, 23), 0.45,
		MeshKit.hash_i(side, id, 24) % 4, seed + 11.0)
	var len: float = minf(b1 - b0 - 4.0, 12.0)
	var d0: float = (b0 + b1 - len) * 0.5
	if len < 4.0 or d0 < start or d0 >= end:
		return
	var color: Color = _pick(skin.neon_colors, side, id, 25).lightened(0.15)
	var bx: float = face_x + side * 1.6
	var y0: float = roof_y + 1.4
	var h: float = 5.0
	var dark := Color(0.05, 0.05, 0.07)
	solid.box(Vector3(bx + side * 0.2, y0 + h * 0.5, -d0 - len * 0.5), Vector3(0.3, h + 0.4, len + 0.4), dark)
	for leg: float in [d0 + 1.0, d0 + len - 1.0]:
		solid.box(Vector3(bx + side * 0.2, roof_y + 0.7, -leg), Vector3(0.2, 1.4, 0.2), dark)
	var px: float = bx - side * 0.03
	if side < 0:
		solid.rect(Vector3(px, y0, -d0), Vector3(0, 0, -len), Vector3(0, h, 0), color, 0.65, MeshKit.PAT_GLYPHS,
			Vector2(0, 0), Vector2(len, h), 1.5)
	else:
		solid.rect(Vector3(px, y0, -d0 - len), Vector3(0, 0, len), Vector3(0, h, 0), color, 0.65, MeshKit.PAT_GLYPHS,
			Vector2(0, 0), Vector2(len, h), 1.5)
	glow.rect(Vector3(px - side * 0.4, y0 - 1.5, -d0 + 1.5), Vector3(0, 0, -(len + 3.0)), Vector3(0, h + 3.0, 0), color,
		0.14, MeshKit.SHAPE_FLAT)


## A facade quad on the wall plane at x, facing the track, from distance u0 to u1 and height y0 to y1.
func _facade(facade: MeshLayer, side: int, x: float, u0: float, u1: float, y0: float, y1: float,
		wall: Color, lit: float, style: int, seed: float) -> void:
	if side < 0:
		facade.rect(Vector3(x, y0, -u0), Vector3(0, 0, -(u1 - u0)), Vector3(0, y1 - y0, 0), wall, lit, style,
			Vector2(u0, y0), Vector2(u1, y1), seed)
	else:
		facade.rect(Vector3(x, y0, -u1), Vector3(0, 0, u1 - u0), Vector3(0, y1 - y0, 0), wall, lit, style,
			Vector2(u1, y0), Vector2(u0, y1), seed)


func _banner(solid: MeshLayer, glow: MeshLayer, side: int, x: float, d: float, y: float, color: Color) -> void:
	var w: float = 2.4
	var h: float = 12.0
	var px: float = x - side * 0.1
	solid.box(Vector3(x - side * 0.05, y + h * 0.5, -d - w * 0.5), Vector3(0.1, h + 0.3, w + 0.3), Color(0.04, 0.04, 0.06))
	if side < 0:
		solid.rect(Vector3(px, y, -d), Vector3(0, 0, -w), Vector3(0, h, 0), color, 0.6, MeshKit.PAT_GLYPHS,
			Vector2(0, 0), Vector2(w, h), 0.0)
	else:
		solid.rect(Vector3(px, y, -d - w), Vector3(0, 0, w), Vector3(0, h, 0), color, 0.6, MeshKit.PAT_GLYPHS,
			Vector2(w, 0), Vector2(0, h), 0.0)
	glow.rect(Vector3(px - side * 0.3, y - 1.0, -d + 1.0), Vector3(0, 0, -(w + 2.0)), Vector3(0, h + 2.0, 0), color,
		0.12, MeshKit.SHAPE_FLAT)


static func _pick(values: PackedColorArray, a: int, b: int, c: int) -> Color:
	return values[MeshKit.hash_i(a, b, c) % values.size()]
