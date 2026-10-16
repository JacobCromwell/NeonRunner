class_name CityIntroStreet
extends Node3D
## The City intro's street at ground level (CityIntro; GDD §6, Cinematics, the owner's October 16, 2026 beats: the runner
## and the cyborgs are on the street itself, not on the truck roofs the levels run on). The stage is the City's own
## stretch of towers with no floor (every lane a gap, so the road far below shows) lifted so that road is y = 0; this
## lays what a street has over it: asphalt with lane paint, a crosswalk or two, kerbs and paved sidewalks, shopfronts
## along both walls (lit windows and neon signs), street lamps with their pools of light. Visual only: no collision and
## no gameplay, built in the City's own kit (the skin's solid and glow materials, its palette), two draw calls for the
## lot.
##
## World space, y = 0 the road, x = 0 the street's middle (the walls' faces at x = +-half_width), a track distance z is
## world z = -z. Every look is hashed from a position (MeshKit.hash01), so it builds the same every time. Safe things
## look safe (GDD §11): nothing here glows in a hazard's colour (no orange, yellow, pink, red, cyan or green), and the
## lamps' warm light is kept apart from the Floating Head's cold white.

const ASPHALT := Color(0.075, 0.075, 0.105)
const PAVING := Color(0.2, 0.2, 0.27)
const CURB := Color(0.34, 0.35, 0.43)
const MARKING := Color(0.78, 0.8, 0.88)
const POLE := Color(0.11, 0.11, 0.15)
const LAMP_LIGHT := Color(1.0, 0.86, 0.62)
const SHOP_DARK := Color(0.045, 0.045, 0.065)
## The shop windows' light: warm, cool, the City's violet and a pale white (never a hazard's colour).
const SHOP_LIGHTS: Array[Color] = [Color(1.0, 0.82, 0.58), Color(0.62, 0.8, 1.0), Color(0.62, 0.45, 1.0),
	Color(0.86, 0.9, 1.0)]
## The sidewalk's width from the kerb to the wall, the kerb's height.
const SIDEWALK: float = 2.4
const KERB: float = 0.16
## Lane paint: the dashes' length and gap (metres), the paint's glow (it shows in the dark).
const DASH: float = 3.0
const DASH_GAP: float = 5.0
const PAINT_GLOW: float = 0.1
## The pole's height and the lamp arm's reach over the road.
const POLE_HEIGHT: float = 6.2
const ARM_REACH: float = 1.5

## Where the lamps' heads are (world space), for tests.
var lamp_heads: Array[Vector3] = []
## The road's half width (the kerbs), and the street's (the walls).
var road_half: float = 0.0
var wall_half: float = 0.0
var skin: CitySkin
var draw_calls: int = 0


## Builds the street for track distances `z0` to `z1` on a street `geo` wide, in `p_skin`'s look.
func build(p_skin: CitySkin, geo: TrackGeometry, z0: float, z1: float) -> void:
	skin = p_skin
	wall_half = geo.wall_x()
	road_half = wall_half - SIDEWALK
	var batch := MeshBatch.new()
	var solid: MeshLayer = batch.layer(skin.solid_material())
	var glow: MeshLayer = batch.layer(skin.glow_material())
	_road(solid, z0, z1)
	_paint(solid, z0, z1)
	for side: int in [-1, 1]:
		_sidewalk(solid, side, z0, z1)
		_shops(solid, glow, side, z0, z1)
		_lamps(solid, glow, side, z0, z1)
	var mesh: MeshInstance3D = batch.commit(self, "Street")
	draw_calls = mesh.mesh.get_surface_count() if mesh != null else 0


## Asphalt between the kerbs, over the road far below that the City's stretch draws (its own traffic streaks, which
## were made to be seen from above the trucks).
func _road(solid: MeshLayer, z0: float, z1: float) -> void:
	solid.rect(Vector3(-road_half, 0.02, -z0), Vector3(road_half * 2.0, 0.0, 0.0), Vector3(0.0, 0.0, -(z1 - z0)), ASPHALT,
		0.0, MeshKit.PAT_ASPHALT)


## Lane paint: a solid double line down the middle, dashed lines between the lanes, solid edge lines, and crosswalks.
func _paint(solid: MeshLayer, z0: float, z1: float) -> void:
	var y: float = 0.03
	var len: float = z1 - z0
	for x: float in [-0.14, 0.14]:
		_strip(solid, x, 0.1, z0, z1, y)
	for x: float in [-road_half * 0.5, road_half * 0.5]:
		var z: float = z0 - fposmod(z0, DASH + DASH_GAP)
		while z < z1:
			_strip(solid, x, 0.12, maxf(z, z0), minf(z + DASH, z1), y)
			z += DASH + DASH_GAP
	for x: float in [-road_half + 0.25, road_half - 0.25]:
		_strip(solid, x, 0.1, z0, z1, y)
	# Crosswalks: zebra bars across the road, with the sidewalks' kerbs dropped to meet them.
	for at: float in crosswalks(z0, z1):
		var bar: float = 0.5
		var x: float = -road_half + 0.5
		while x < road_half - 0.4:
			solid.rect(Vector3(x, y, -(at - 2.0)), Vector3(bar, 0.0, 0.0), Vector3(0.0, 0.0, -4.0), MARKING, PAINT_GLOW)
			x += bar * 2.0
	len = len


## Where the crosswalks are (track distances) in [z0, z1]: every so often, off the stretch the cyborgs march.
static func crosswalks(z0: float, z1: float) -> Array[float]:
	var out: Array[float] = []
	var at: float = ceilf(z0 / 70.0) * 70.0 + 24.0
	while at < z1:
		out.append(at)
		at += 70.0
	return out


func _strip(solid: MeshLayer, x: float, width: float, a: float, b: float, y: float) -> void:
	if b - a < 0.05:
		return
	solid.rect(Vector3(x - width * 0.5, y, -a), Vector3(width, 0.0, 0.0), Vector3(0.0, 0.0, -(b - a)), MARKING, PAINT_GLOW)


## A sidewalk's raised paving from the kerb to the wall.
func _sidewalk(solid: MeshLayer, side: int, z0: float, z1: float) -> void:
	var inner: float = side * road_half
	var outer: float = side * wall_half
	var faces: int = MeshKit.FACE_PY | (MeshKit.FACE_NX if side > 0 else MeshKit.FACE_PX)
	solid.box(Vector3((inner + outer) * 0.5, KERB * 0.5, -(z0 + z1) * 0.5), Vector3(SIDEWALK, KERB, z1 - z0), PAVING, 0.0,
		MeshKit.PAT_TILES, faces, 0.0)
	# The kerb's top edge, a lighter line along it.
	solid.box(Vector3(inner + side * 0.07, KERB - 0.01, -(z0 + z1) * 0.5), Vector3(0.14, 0.03, z1 - z0), CURB)


## Shopfronts along a wall: a lit window with its shelves, a door beside it, a neon sign above; one every few metres,
## their spacing, widths and lights hashed from their place, so no two neighbours match.
func _shops(solid: MeshLayer, glow: MeshLayer, side: int, z0: float, z1: float) -> void:
	var x: float = side * (wall_half - 0.03)
	var at: float = z0 - fposmod(z0, 40.0)
	var index: int = int(floorf(at / 40.0)) * 8
	while at < z1:
		var key: int = MeshKit.hash_i(side + 3, index, 41)
		var width: float = 3.4 + 3.2 * MeshKit.hash01(side + 3, index, 42)
		var gap: float = 0.7 + 1.8 * MeshKit.hash01(side + 3, index, 43)
		var a: float = at
		var b: float = a + width
		if b > z0 and a < z1:
			_shop(solid, glow, side, x, maxf(a, z0), minf(b, z1), key, a, b)
		at = b + gap
		index += 1


func _shop(solid: MeshLayer, glow: MeshLayer, side: int, x: float, a: float, b: float, key: int, full_a: float,
		full_b: float) -> void:
	var light: Color = SHOP_LIGHTS[key % SHOP_LIGHTS.size()]
	var door_w: float = 1.1
	var door_first: bool = (key >> 3) % 2 == 0
	var win_a: float = a + (door_w + 0.35 if door_first else 0.25)
	var win_b: float = b - (0.25 if door_first else door_w + 0.35)
	var in_x: float = x - side * 0.01
	if win_b - win_a > 0.8:
		# The window: its light, a darker lower panel under it, shelves of dark goods across it.
		_wall_rect(glow, side, in_x - side * 0.01, win_a, win_b, 0.55, 2.7, light, 0.5, MeshKit.SHAPE_FLAT)
		_wall_rect(solid, side, in_x - side * 0.012, win_a, win_b, 0.5, 2.7, light.darkened(0.55), 0.45)
		for shelf: int in 3:
			var sy: float = 0.9 + shelf * 0.6
			_wall_rect(solid, side, in_x - side * 0.02, win_a + 0.12, win_b - 0.12, sy, sy + 0.05, SHOP_DARK)
			var goods: float = (win_b - win_a - 0.4) * (0.3 + 0.5 * MeshKit.hash01(key, shelf, 44))
			_wall_rect(solid, side, in_x - side * 0.02, win_a + 0.25, win_a + 0.25 + goods, sy + 0.05, sy + 0.32,
				SHOP_DARK.lightened(0.04))
		# The frame.
		_wall_rect(solid, side, in_x - side * 0.03, win_a - 0.08, win_b + 0.08, 0.42, 0.55, POLE)
		_wall_rect(solid, side, in_x - side * 0.03, win_a - 0.08, win_b + 0.08, 2.7, 2.8, POLE)
		_wall_rect(solid, side, in_x - side * 0.03, win_a - 0.08, win_a, 0.42, 2.8, POLE)
		_wall_rect(solid, side, in_x - side * 0.03, win_b, win_b + 0.08, 0.42, 2.8, POLE)
	# The door, a dark panel with a light behind its glass, and a pool of the shop's light on the pavement.
	var d0: float = a + 0.18 if door_first else b - 0.18 - door_w
	_wall_rect(solid, side, in_x - side * 0.01, d0, d0 + door_w, 0.0, 2.4, SHOP_DARK.lightened(0.02))
	_wall_rect(glow, side, in_x - side * 0.03, d0 + 0.2, d0 + door_w - 0.2, 0.9, 2.1, light, 0.22, MeshKit.SHAPE_FLAT)
	# A neon sign over both: the City's accent colours, glyph rows on a dark board.
	var accent: Color = skin.neon_colors[(key >> 5) % skin.neon_colors.size()]
	var board_a: float = a + 0.15
	var board_b: float = b - 0.15
	var sign_seed: float = float((key >> 2) % 90)
	_wall_rect(solid, side, in_x - side * 0.04, board_a, board_b, 2.95, 3.5, accent, 0.5, MeshKit.PAT_GLYPHS, 0.0, true)
	_wall_rect(solid, side, in_x - side * 0.045, board_a - 0.05, board_b + 0.05, 2.92, 2.95, accent, 0.5)
	_wall_rect(solid, side, in_x - side * 0.045, board_a - 0.05, board_b + 0.05, 3.5, 3.53, accent, 0.5)
	sign_seed = sign_seed
	# The light on the pavement in front of the window.
	var spill_w: float = 2.2
	var sx0: float = x - side * 0.05
	var sx1: float = x - side * (SIDEWALK - 0.15)
	glow.rect(Vector3(minf(sx0, sx1), KERB + 0.015, -b), Vector3(absf(sx1 - sx0), 0.0, 0.0), Vector3(0.0, 0.0, b - a),
		light, 0.06, MeshKit.SHAPE_FLAT)
	spill_w = spill_w


## A rectangle on a wall's face, between track distances a and b and heights y0 and y1, facing the street (side -1 the
## left wall). `glyph_uv`: its UV in metres, running up the track (for patterns drawn in metres).
func _wall_rect(layer: MeshLayer, side: int, x: float, a: float, b: float, y0: float, y1: float, color: Color,
		glow: float = 0.0, pattern: int = 0, param: float = 0.0, metres: bool = false) -> void:
	var uv0 := Vector2.ZERO
	var uv1 := Vector2.ONE
	if metres:
		uv0 = Vector2(a, y0)
		uv1 = Vector2(b, y1)
	if side < 0:
		layer.rect(Vector3(x, y0, -a), Vector3(0.0, 0.0, -(b - a)), Vector3(0.0, y1 - y0, 0.0), color, glow, pattern, uv0,
			uv1, param)
	else:
		layer.rect(Vector3(x, y0, -b), Vector3(0.0, 0.0, b - a), Vector3(0.0, y1 - y0, 0.0), color, glow, pattern,
			Vector2(uv1.x, uv0.y), Vector2(uv0.x, uv1.y), param)


## Street lamps on both sidewalks, staggered, every lamp_spacing metres: a pole, an arm over the road, a warm head, a
## halo round it and a pool of light on the road under it.
func _lamps(solid: MeshLayer, glow: MeshLayer, side: int, z0: float, z1: float) -> void:
	var spacing: float = 16.0
	var at: float = ceilf(z0 / spacing) * spacing + (spacing * 0.5 if side > 0 else 0.0)
	var px: float = side * (road_half + 0.55)
	while at < z1:
		var base := Vector3(px, KERB, -at)
		solid.prism(base, 0.07, POLE_HEIGHT, 6, POLE)
		solid.prism(base, 0.13, 0.35, 6, POLE)
		var arm_end: float = px - side * ARM_REACH
		solid.box(Vector3((px + arm_end) * 0.5, KERB + POLE_HEIGHT, -at), Vector3(ARM_REACH, 0.09, 0.09), POLE)
		var head := Vector3(arm_end, KERB + POLE_HEIGHT - 0.1, -at)
		solid.box(head, Vector3(0.62, 0.14, 0.3), POLE)
		solid.box(head - Vector3(0.0, 0.09, 0.0), Vector3(0.5, 0.05, 0.22), LAMP_LIGHT, 1.0)
		lamp_heads.append(head)
		glow.rect(head + Vector3(-1.4, -1.1, 0.0), Vector3(2.8, 0.0, 0.0), Vector3(0.0, 2.2, 0.0), LAMP_LIGHT, 0.34,
			MeshKit.SHAPE_RADIAL)
		glow.rect(Vector3(arm_end - 3.2, 0.05, -at + 3.4), Vector3(6.4, 0.0, 0.0), Vector3(0.0, 0.0, -6.8), LAMP_LIGHT, 0.1,
			MeshKit.SHAPE_RADIAL)
		at += spacing
