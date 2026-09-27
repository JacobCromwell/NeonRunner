extends RefCounted
## The Marketplace's cyborg (GDD §9.2, "Zone variants"; brief docs/art/BRIEF_CYBORG_GANGSTER.md; the
## owner's sheet docs/art/reference/cyborg_casino_enforcer.jpg): the "Casino Mob Enforcer", the
## casinos' muscle. The same unit as the base, never bigger than it: the same skeleton, poses and
## hitboxes, and the same TV screen (the face in the same place).
## - The head: the base's TV gilded (unlit, polished gold) with a black lacquer bezel, card suits
##   engraved on its sides and top, and a dark tube behind; braided gold cables run into it from the
##   backpack.
## - The body: a black pinstripe suit (gold pinstripes, cyborg_body.gdshader's glow 70) open over a
##   black shirt and a gold breastplate with a diamond engraved on it, black satin lapels trimmed in
##   gold, a bandolier across the chest; gold armour plates on the shoulders and knees; gunmetal
##   mechanical forearms and hands with gold rings (the sheet's); pinstripe trousers, gunmetal shin
##   guards and black shoes with gold toe caps. The backpack: black with gold side panels and lid.
## - The weapon: the sheet's drum-fed gun, compact, held in the right hand and along the forearm (its
##   stock under the forearm, the drum below the receiver, a perforated barrel shroud), its muzzle
##   at the shared emitter ring and charge orb (the red charge-up is every look's). The sheet's
##   separate "SPADE" arm cannon is left out, so only one thing shoots (brief).
## - The screen's LEDs are small diamonds instead of round dots (a card suit, in the face's cold
##   white; the same light far away), the one zone-flavoured glyph on the screen.
## Gold is unlit ornament, polished (never glowing, nothing copper; brief). The Golden Zone's
## ceremonial enforcer (golden.gd) is built from this look with its own palette (build()).
## DESIGN-TBD (docs/questions/p3.md 2): the Casino Mob Enforcer's details read off the sheet.

const BOX := HumanoidPiece.Shape.BOX
const PRISM := HumanoidPiece.Shape.PRISM
const LATHE := HumanoidPiece.Shape.LATHE
const BAND := HumanoidPiece.Shape.BAND
const CENTER := HumanoidPiece.Placement.CENTER
const MIRRORED := HumanoidPiece.Placement.MIRRORED
const RIGHT := HumanoidPiece.Placement.RIGHT
const LEFT := HumanoidPiece.Placement.LEFT

## Card suits (suit_mark).
enum Suit { SPADE, HEART, DIAMOND, CLUB }

## The torso: the shirt's section (half sizes, a 10-sided ring) through these rings (height in the
## chest joint's space, x scale, z scale, z shift), inside the base's outline; the jacket is the same
## shape JACKET_GAP larger, open at the front, and hangs to JACKET_HEM.
const TORSO_HALF := Vector2(0.122, 0.086)
const TORSO_RINGS: Array[Vector4] = [
	Vector4(-0.1, 0.98, 1.0, 0.0),
	Vector4(0.12, 1.0, 1.02, 0.0),
	Vector4(0.29, 1.1, 1.04, -0.006),
	Vector4(0.365, 1.44, 0.96, -0.01),
	Vector4(0.415, 0.92, 0.74, -0.004),
]
const JACKET_GAP: float = 0.014
const JACKET_HEM: float = -0.15

## The Marketplace's palette (keys as build() reads them): a black suit with gold pinstripes (the
## stripes' colour is the material's, material_params), black shirt and lapels, polished gold, black
## lacquer, gunmetal mechanics and braided gold cables.
const PALETTE: Dictionary = {
	"suit": Color(0.13, 0.13, 0.15),
	"suit_shade": Color(0.09, 0.09, 0.1),
	"shirt": Color(0.07, 0.07, 0.08),
	"lapel": Color(0.06, 0.06, 0.07),
	"gold": Color(0.66, 0.53, 0.31),
	"gold_dark": Color(0.42, 0.33, 0.19),
	"gold_shine": 0.7,
	"lacquer": Color(0.07, 0.07, 0.08),
	"lacquer_shine": 0.55,
	"metal": Color(0.22, 0.23, 0.24),
	"metal_dark": Color(0.14, 0.145, 0.15),
	"metal_shine": 0.45,
	"strap": Color(0.1, 0.09, 0.08),
	"cable": Color(0.4, 0.32, 0.19),
	"tube": Color(0.17, 0.175, 0.18),
	"cartridge": Color(0.5, 0.4, 0.24),
	"stock": Color(0.1, 0.1, 0.11),
	"drum": Color(0.07, 0.07, 0.08),
	"suits": true,
	"bandolier": true,
}
## The pinstripes (unlit gold) and their spacing, for the material.
const STRIPE_COLOR := Color(0.5, 0.41, 0.26)
const STRIPE_SPACING: float = 0.026


static func pieces() -> Array[HumanoidPiece]:
	var list: Array[HumanoidPiece] = []
	build(list, PALETTE)
	return list


## A host enforcer's veins: up the front of the neck above the shirt's collar, and down the front of
## both arms (the sleeves and the gauntlets; the side the player sees).
static func veins() -> Array[HumanoidPiece]:
	return host_veins()


## Gold pinstripes, diamond LEDs, and polished gold that is properly metal.
static func material_params() -> Dictionary:
	return {&"stripe_color": STRIPE_COLOR, &"stripe_spacing": STRIPE_SPACING, &"led_shape": 1.0,
		&"polish_metallic": 0.85, &"polished_roughness": 0.24}


## The whole enforcer in palette `p` (PALETTE's keys): the Marketplace's, or the Golden Zone's.
static func build(list: Array[HumanoidPiece], p: Dictionary) -> void:
	_head(list, p)
	_torso(list, p)
	_backpack(list, p)
	_arms(list, p)
	_drum_gun(list, p)
	_legs(list, p)


## The veins every enforcer's host wears (the body is the same in both palettes).
static func host_veins() -> Array[HumanoidPiece]:
	var list: Array[HumanoidPiece] = []
	var w: float = 0.012
	for x: float in [-0.024, 0.0, 0.024]:
		CyborgSuit.vein(list, &"chest", Vector3(x * 1.1, 0.418, -0.047), Vector3(x * 0.8, 0.48, -0.045), w, CENTER)
	for side: HumanoidPiece.Placement in [RIGHT, LEFT]:
		CyborgSuit.vein(list, &"upper_arm", Vector3(0.016, -0.11, -0.05), Vector3(0.01, -0.26, -0.047), w, side)
		CyborgSuit.vein(list, &"upper_arm", Vector3(0.012, -0.18, -0.049), Vector3(0.036, -0.23, -0.035), w, side)
		CyborgSuit.vein(list, &"forearm", Vector3(0.012, -0.03, -0.044), Vector3(0.012, -0.21, -0.049), w, side)
		CyborgSuit.vein(list, &"forearm", Vector3(0.012, -0.11, -0.047), Vector3(0.032, -0.17, -0.036), w, side)
	return list


## A card suit engraved on a surface: `size` tall, centred at `at`, lying on the surface facing
## `normal` with its top toward `up`, in flat patches (2-4 of them).
static func suit_mark(list: Array[HumanoidPiece], segment: StringName, suit: Suit, at: Vector3, size: float,
		normal: Vector3, up: Vector3, color: Color, side: HumanoidPiece.Placement = CENTER) -> void:
	var right: Vector3 = up.cross(-normal).normalized()
	var turn: Vector3 = CyborgSuit.facing(normal, right)
	var true_up: Vector3 = (-normal.normalized()).cross(right)
	var lift: Vector3 = normal.normalized() * 0.0012
	# Each part: (dx, dy, width, height) in units of `size`, and its kind: 0 a square turned 45° (a
	# lobe), 1 a triangle pointing up, 2 a triangle pointing down.
	var parts: Array = []
	match suit:
		Suit.SPADE:
			parts = [[0.0, 0.14, 0.72, 0.56, 1], [-0.17, -0.07, 0.36, 0.36, 0], [0.17, -0.07, 0.36, 0.36, 0],
				[0.0, -0.33, 0.3, 0.3, 1]]
		Suit.HEART:
			parts = [[-0.16, 0.13, 0.4, 0.4, 0], [0.16, 0.13, 0.4, 0.4, 0], [0.0, -0.1, 0.78, 0.62, 2]]
		Suit.DIAMOND:
			parts = [[0.0, 0.24, 0.62, 0.5, 1], [0.0, -0.24, 0.62, 0.5, 2]]
		Suit.CLUB:
			parts = [[0.0, 0.2, 0.34, 0.34, 0], [-0.19, -0.05, 0.34, 0.34, 0], [0.19, -0.05, 0.34, 0.34, 0],
				[0.0, -0.31, 0.3, 0.34, 1]]
	for part: Array in parts:
		var c: Vector3 = at + lift + right * (part[0] * size) + true_up * (part[1] * size)
		var sz := Vector2(part[2], part[3]) * size
		match int(part[4]):
			0:
				CyborgSuit.patch(list, segment, c, sz * 0.72, color, turn + Vector3(0.0, 0.0, 45.0), 1.0, side)
			1:
				CyborgSuit.patch(list, segment, c, sz, color, turn + Vector3(0.0, 0.0, 180.0), 0.0, side)
			_:
				CyborgSuit.patch(list, segment, c, sz, color, turn, 0.0, side)


## The gilded TV: the base's box and screen, polished gold, with a lacquer bezel, card suits engraved
## on its sides and top with a border of engraved lines, the tube behind and a gold plate on its back.
static func _head(list: Array[HumanoidPiece], p: Dictionary) -> void:
	var tv: Vector3 = CyborgSuit.TV_SIZE
	var at: Vector3 = CyborgSuit.TV_CENTER
	var s: Vector3 = CyborgSuit.SCREEN_SIZE
	var c: Vector3 = CyborgSuit.SCREEN_CENTER
	var front: float = at.z - tv.z * 0.5
	var bezel_z: float = front - 0.007
	var top: float = at.y + tv.y * 0.5
	var gold := {"shine": p["gold_shine"]}
	var lacquer := {"shine": p["lacquer_shine"]}
	CyborgSuit.add(list, &"head", BOX, tv, at, p["gold"], 0.0, CyborgSuit.merged(gold, {"chamfer": 0.12}))
	CyborgSuit.add(list, &"head", BOX, Vector3(0.34, 0.15, 0.25), Vector3(0.0, 0.14, 0.055), p["tube"], 0.0,
		CyborgSuit.merged(lacquer, {"rotation_degrees": Vector3(90.0, 0.0, 0.0), "top_scale": Vector2(0.72, 0.7)}))
	CyborgSuit.add(list, &"head", BOX, Vector3(0.21, 0.15, 0.022), Vector3(0.0, 0.14, 0.135), p["gold"], 0.0, gold)
	# The gold bezel, with a thin lacquer lip round the recessed screen and an engraved line along its
	# chin.
	CyborgSuit.add(list, &"head", BOX, Vector3(tv.x, 0.03, 0.02), Vector3(0.0, c.y + s.y * 0.5 + 0.015, bezel_z), p["gold"],
		0.0, gold)
	CyborgSuit.add(list, &"head", BOX, Vector3(tv.x, 0.052, 0.02), Vector3(0.0, c.y - s.y * 0.5 - 0.026, bezel_z), p["gold"],
		0.0, gold)
	CyborgSuit.add(list, &"head", BOX, Vector3(0.035, s.y + 0.01, 0.02), Vector3(c.x + s.x * 0.5 + 0.0175, c.y, bezel_z),
		p["gold"], 0.0, CyborgSuit.merged(gold, {"side": MIRRORED}))
	var lip_z: float = bezel_z - 0.0102
	CyborgSuit.patch(list, &"head", Vector3(0.0, c.y + s.y * 0.5 + 0.004, lip_z), Vector2(s.x + 0.016, 0.008), p["lacquer"])
	CyborgSuit.patch(list, &"head", Vector3(0.0, c.y - s.y * 0.5 - 0.004, lip_z), Vector2(s.x + 0.016, 0.008), p["lacquer"])
	CyborgSuit.patch(list, &"head", Vector3(c.x + s.x * 0.5 + 0.004, c.y, lip_z), Vector2(0.008, s.y), p["lacquer"],
		Vector3.ZERO, 1.0, MIRRORED)
	CyborgSuit.add(list, &"head", BOX, s, c, Color.BLACK, CyborgSuit.SCREEN)
	CyborgSuit.patch(list, &"head", Vector3(0.0, c.y - s.y * 0.5 - 0.034, lip_z), Vector2(tv.x - 0.06, 0.006), p["gold_dark"])
	var side_x: float = tv.x * 0.5 + 0.0012
	# The side panels' engraved border (lines along their edges) and a suit in the middle of each.
	for edge: Vector4 in [Vector4(0.0, top - 0.018, 0.1, 0.006), Vector4(0.0, at.y - tv.y * 0.5 + 0.018, 0.1, 0.006)]:
		CyborgSuit.patch(list, &"head", Vector3(side_x, edge.y, at.z), Vector2(edge.z, edge.w), p["gold_dark"],
			CyborgSuit.facing(Vector3.RIGHT, Vector3.BACK), 1.0, MIRRORED)
	if p["suits"]:
		suit_mark(list, &"head", Suit.SPADE, Vector3(side_x, at.y, at.z), 0.07, Vector3.RIGHT, Vector3.UP, p["gold_dark"])
		suit_mark(list, &"head", Suit.HEART, Vector3(-side_x, at.y, at.z), 0.07, Vector3.LEFT, Vector3.UP, p["gold_dark"])
		suit_mark(list, &"head", Suit.DIAMOND, Vector3(-0.09, top + 0.0012, at.z), 0.06, Vector3.UP, Vector3.FORWARD,
			p["gold_dark"])
		suit_mark(list, &"head", Suit.CLUB, Vector3(0.09, top + 0.0012, at.z), 0.06, Vector3.UP, Vector3.FORWARD, p["gold_dark"])


## The shirt, the suit jacket (pinstriped, open over the gold breastplate), satin lapels trimmed in
## gold, the bandolier, a gunmetal neck with a collar round it, and the trousers' seat.
static func _torso(list: Array[HumanoidPiece], p: Dictionary) -> void:
	var stripes: float = CyborgSuit.STRIPES
	CyborgSuit.add(list, &"chest", LATHE, Vector3(TORSO_HALF.x * 2.0, 0.0, TORSO_HALF.y * 2.0), Vector3.ZERO, p["shirt"], 0.0,
		{"sides": 10, "profile": PackedVector4Array(TORSO_RINGS)})
	var rings := PackedVector4Array([Vector4(JACKET_HEM, 1.02, 1.04, 0.0)])
	for ring: Vector4 in TORSO_RINGS:
		if ring.x > JACKET_HEM + 0.1:
			rings.append(ring)
	var half := TORSO_HALF + Vector2.ONE * JACKET_GAP
	CyborgSuit.add(list, &"chest", BAND, Vector3(half.x * 2.0, 0.0, half.y * 2.0), Vector3.ZERO, p["suit"], stripes,
		{"sides": 10, "arc": Vector2(26.0, 334.0), "profile": rings})
	# The gold breastplate between the jacket's fronts, a diamond engraved on it.
	CyborgSuit.add(list, &"chest", BOX, Vector3(0.17, 0.21, 0.028), Vector3(0.0, 0.225, -0.089), p["gold"], 0.0,
		{"chamfer": 0.3, "shine": p["gold_shine"], "top_scale": Vector2(1.08, 0.8)})
	suit_mark(list, &"chest", Suit.DIAMOND, Vector3(0.0, 0.2, -0.1031), 0.05, Vector3.FORWARD, Vector3.UP, p["gold_dark"])
	# The lapels, turned back at the top of the open front, with a gold edge.
	var lapel_rot := Vector3(-8.0, -18.0, -14.0)
	var lapel_at := Vector3(0.078, 0.315, -0.107)
	CyborgSuit.add(list, &"chest", BOX, Vector3(0.05, 0.15, 0.012), lapel_at, p["lapel"], 0.0,
		{"side": MIRRORED, "shine": p["lacquer_shine"], "top_scale": Vector2(1.45, 1.0), "rotation_degrees": lapel_rot})
	var basis := Basis.from_euler(lapel_rot * (PI / 180.0))
	CyborgSuit.patch(list, &"chest", lapel_at + basis * Vector3(0.024, 0.01, -0.0068), Vector2(0.008, 0.13), p["gold"],
		lapel_rot + Vector3(0.0, 0.0, -9.0), 1.0, MIRRORED)
	# The neck: gunmetal, ribbed, a shirt collar round its base.
	CyborgSuit.add(list, &"chest", PRISM, Vector3(0.072, 0.11, 0.072), Vector3(0.0, 0.455, 0.0), p["metal_dark"], 0.0,
		{"sides": 6})
	CyborgSuit.add(list, &"chest", PRISM, Vector3(0.086, 0.016, 0.086), Vector3(0.0, 0.47, 0.0), p["metal"], 0.0, {"sides": 6})
	CyborgSuit.add(list, &"chest", LATHE, Vector3(0.15, 0.0, 0.13), Vector3(0.0, 0.0, 0.008), p["shirt"], 0.0, {"sides": 8,
		"profile": PackedVector4Array([Vector4(0.39, 0.95, 0.95, 0.0), Vector4(0.43, 0.9, 0.92, 0.004)])})
	if p["bandolier"]:
		var a := Vector3(0.13, 0.39, -0.078)
		var b := Vector3(-0.115, 0.0, -0.106)
		CyborgSuit.bar(list, &"chest", a, b, Vector2(0.03, 0.008), p["strap"], Vector3.FORWARD)
		for k: int in 4:
			var q: Vector3 = a.lerp(b, 0.36 + k * 0.1) + Vector3(0.0, 0.0, -0.006)
			CyborgSuit.patch(list, &"chest", q, Vector2(0.012, 0.03), p["cartridge"], Vector3(0.0, 0.0, -33.0))
	CyborgSuit.add(list, &"pelvis", BOX, Vector3(0.23, 0.15, 0.17), Vector3(0.0, -0.045, 0.005), p["suit"], stripes,
		{"chamfer": 0.3, "top_scale": Vector2(0.94, 0.92)})


## The backpack: a lacquered box between gold side panels under a gold lid, vents, the straps, and
## the base's two cables into the TV, braided gold here.
static func _backpack(list: Array[HumanoidPiece], p: Dictionary) -> void:
	var gold := {"shine": p["gold_shine"]}
	CyborgSuit.add(list, &"chest", BOX, Vector3(0.18, 0.25, 0.11), Vector3(0.0, 0.215, 0.158), p["lacquer"], 0.0,
		{"shine": p["lacquer_shine"]})
	CyborgSuit.add(list, &"chest", BOX, Vector3(0.045, 0.25, 0.114), Vector3(0.11, 0.215, 0.158), p["gold"], 0.0,
		CyborgSuit.merged(gold, {"side": MIRRORED, "chamfer": 0.2}))
	CyborgSuit.add(list, &"chest", BOX, Vector3(0.26, 0.03, 0.12), Vector3(0.0, 0.352, 0.158), p["gold"], 0.0, gold)
	for k: int in 3:
		CyborgSuit.patch(list, &"chest", Vector3(0.0, 0.27 - k * 0.03, 0.2138), Vector2(0.1, 0.01), p["gold_dark"],
			CyborgSuit.facing(Vector3.BACK))
	for side: float in [-1.0, 1.0]:
		var a := Vector3(side * 0.085, 0.355, 0.11)
		var b := Vector3(side * 0.118, 0.428, 0.012)
		var c := Vector3(side * 0.11, 0.3, -0.1)
		CyborgSuit.bar(list, &"chest", a, b, Vector2(0.032, 0.01), p["strap"], Vector3.UP)
		CyborgSuit.bar(list, &"chest", b, c, Vector2(0.032, 0.01), p["strap"], Vector3.FORWARD)
	for k: int in CyborgSuit.HEAD_CABLES.size():
		CyborgSuit.cable(list, CyborgSuit.HEAD_CABLES[k], CyborgSuit.HEAD_CABLE_WIDTHS[k], p["cable"])


## The arms: pinstriped sleeves under layered gold pauldrons, and gunmetal mechanical forearms with a
## gold ring at the elbow and wrist, ending in mechanical hands (the right one grips the gun).
static func _arms(list: Array[HumanoidPiece], p: Dictionary) -> void:
	var metal := {"side": MIRRORED, "shine": p["metal_shine"]}
	CyborgSuit.add(list, &"upper_arm", LATHE, Vector3(0.135, 0.0, 0.135), Vector3(0.008, 0.0, 0.0), p["gold"], 0.0,
		{"side": MIRRORED, "sides": 8, "shine": p["gold_shine"], "profile": PackedVector4Array([
			Vector4(-0.075, 0.92, 0.92, 0.0), Vector4(-0.03, 1.0, 1.0, 0.0), Vector4(0.028, 0.78, 0.78, 0.0),
			Vector4(0.056, 0.32, 0.32, 0.0)])})
	CyborgSuit.add(list, &"upper_arm", BAND, Vector3(0.126, 0.0, 0.126), Vector3(0.012, 0.0, 0.0), p["gold_dark"], 0.0,
		{"side": MIRRORED, "sides": 8, "shine": p["gold_shine"], "profile": PackedVector4Array([
			Vector4(-0.105, 0.95, 0.95, 0.0), Vector4(-0.072, 1.0, 1.0, 0.0)])})
	CyborgSuit.add(list, &"upper_arm", PRISM, Vector3(0.096, 0.25, 0.096), Vector3(0.0, -0.14, 0.0), p["suit"],
		CyborgSuit.STRIPES, {"side": MIRRORED, "sides": 6, "top_scale": Vector2(1.08, 1.08)})
	CyborgSuit.add(list, &"upper_arm", PRISM, Vector3(0.09, 0.03, 0.09), Vector3(0.0, -0.268, 0.0), p["suit_shade"], 0.0,
		{"side": MIRRORED, "sides": 6})
	CyborgSuit.add(list, &"forearm", PRISM, Vector3(0.086, 0.21, 0.086), Vector3(0.0, -0.115, 0.0), p["metal"], 0.0,
		CyborgSuit.merged(metal, {"sides": 8, "top_scale": Vector2(0.86, 0.86)}))
	CyborgSuit.add(list, &"forearm", BOX, Vector3(0.06, 0.12, 0.014), Vector3(0.0, -0.12, -0.044), p["gold"], 0.0,
		{"side": MIRRORED, "shine": p["gold_shine"]})
	for y: float in [-0.02, -0.215]:
		CyborgSuit.add(list, &"forearm", BAND, Vector3(0.094, 0.0, 0.094), Vector3.ZERO, p["gold_dark"], 0.0,
			{"side": MIRRORED, "sides": 8, "shine": p["gold_shine"], "profile": PackedVector4Array([
				Vector4(y - 0.01, 1.0, 1.0, 0.0), Vector4(y + 0.01, 1.0, 1.0, 0.0)])})
	# The left hand: a mechanical fist, its thumb along the front.
	CyborgSuit.add(list, &"forearm", BOX, Vector3(0.07, 0.08, 0.082), Vector3(0.0, -0.275, -0.004), p["metal_dark"], 0.0,
		CyborgSuit.merged(metal, {"side": LEFT, "chamfer": 0.3}))
	CyborgSuit.add(list, &"forearm", BOX, Vector3(0.022, 0.05, 0.022), Vector3(0.022, -0.27, -0.045), p["metal"], 0.0,
		CyborgSuit.merged(metal, {"side": LEFT}))


## The drum-fed gun in the right hand, compact, lying along the forearm: the stock under the forearm,
## the hand round its grip, the receiver in line with the arm, the drum below it with a suit on each
## face, and the perforated barrel shroud out to a compensator at the muzzle, where the shared
## emitter ring and charge orb sit (CyborgSuit.MUZZLE).
static func _drum_gun(list: Array[HumanoidPiece], p: Dictionary) -> void:
	var gold := {"side": RIGHT, "shine": p["gold_shine"]}
	var metal := {"side": RIGHT, "shine": p["metal_shine"]}
	CyborgSuit.add(list, &"forearm", BOX, Vector3(0.032, 0.17, 0.034), Vector3(0.0, -0.16, 0.058), p["stock"], 0.0,
		{"side": RIGHT, "shine": p["lacquer_shine"], "top_scale": Vector2(0.8, 0.8)})
	CyborgSuit.add(list, &"forearm", BOX, Vector3(0.07, 0.07, 0.08), Vector3(0.0, -0.265, 0.016), p["metal_dark"], 0.0,
		CyborgSuit.merged(metal, {"chamfer": 0.3}))
	CyborgSuit.add(list, &"forearm", BOX, Vector3(0.044, 0.12, 0.05), Vector3(0.0, -0.31, -0.01), p["gold"], 0.0,
		CyborgSuit.merged(gold, {"chamfer": 0.2}))
	CyborgSuit.add(list, &"forearm", PRISM, Vector3(0.084, 0.034, 0.084), Vector3(0.0, -0.325, 0.05), p["drum"], 0.0,
		{"side": RIGHT, "sides": 12, "shine": p["lacquer_shine"], "rotation_degrees": Vector3(0.0, 0.0, 90.0)})
	CyborgSuit.add(list, &"forearm", PRISM, Vector3(0.05, 0.038, 0.05), Vector3(0.0, -0.325, 0.05), p["gold"], 0.0,
		CyborgSuit.merged(gold, {"sides": 8, "rotation_degrees": Vector3(0.0, 0.0, 90.0)}))
	if p["suits"]:
		suit_mark(list, &"forearm", Suit.SPADE, Vector3(0.0171, -0.325, 0.05), 0.034, Vector3.RIGHT, Vector3.DOWN,
			p["gold_dark"], RIGHT)
		suit_mark(list, &"forearm", Suit.HEART, Vector3(-0.0171, -0.325, 0.05), 0.034, Vector3.LEFT, Vector3.DOWN,
			p["gold_dark"], RIGHT)
	CyborgSuit.add(list, &"forearm", PRISM, Vector3(0.042, 0.06, 0.042), Vector3(0.0, -0.36, 0.0), p["gold"], 0.0,
		CyborgSuit.merged(gold, {"sides": 8}))
	for k: int in 3:
		CyborgSuit.patch(list, &"forearm", Vector3(0.0, -0.345 - k * 0.014, -0.0205), Vector2(0.01, 0.007), p["lacquer"])
	CyborgSuit.add(list, &"forearm", PRISM, Vector3(0.05, 0.02, 0.05), Vector3(0.0, -0.39, 0.0), p["gold_dark"], 0.0,
		CyborgSuit.merged(gold, {"sides": 8}))


## Pinstriped trousers, gold knee plates, gunmetal shin guards, and lacquered shoes with gold toe caps
## and a gold band round the ankle.
static func _legs(list: Array[HumanoidPiece], p: Dictionary) -> void:
	var stripes: float = CyborgSuit.STRIPES
	CyborgSuit.add(list, &"thigh", PRISM, Vector3(0.126, 0.34, 0.126), Vector3(0.0, -0.16, 0.0), p["suit"], stripes,
		{"sides": 8, "top_scale": Vector2(1.08, 1.06)})
	CyborgSuit.add(list, &"shin", BOX, Vector3(0.086, 0.08, 0.034), Vector3(0.0, -0.015, -0.062), p["gold"], 0.0,
		{"chamfer": 0.3, "shine": p["gold_shine"], "top_scale": Vector2(0.9, 0.8)})
	CyborgSuit.add(list, &"shin", PRISM, Vector3(0.12, 0.2, 0.12), Vector3(0.0, -0.09, 0.0), p["suit"], stripes,
		{"sides": 8, "top_scale": Vector2(0.98, 0.98)})
	CyborgSuit.add(list, &"shin", BOX, Vector3(0.07, 0.11, 0.018), Vector3(0.0, -0.12, -0.058), p["metal"], 0.0,
		{"shine": p["metal_shine"], "top_scale": Vector2(0.9, 1.0)})
	CyborgSuit.add(list, &"shin", BAND, Vector3(0.106, 0.0, 0.106), Vector3.ZERO, p["gold_dark"], 0.0,
		{"sides": 8, "shine": p["gold_shine"], "profile": PackedVector4Array([Vector4(-0.215, 1.0, 1.0, 0.0),
			Vector4(-0.195, 1.0, 1.0, 0.0)])})
	CyborgSuit.add(list, &"shin", PRISM, Vector3(0.094, 0.08, 0.094), Vector3(0.0, -0.225, 0.0), p["lacquer"], 0.0,
		{"sides": 8, "shine": p["lacquer_shine"]})
	CyborgSuit.add(list, &"shin", BOX, Vector3(0.096, 0.065, 0.19), Vector3(0.0, -0.275, -0.04), p["lacquer"], 0.0,
		{"chamfer": 0.35, "shine": p["lacquer_shine"], "top_scale": Vector2(0.88, 0.7), "top_shift": 0.02})
	CyborgSuit.add(list, &"shin", BOX, Vector3(0.09, 0.04, 0.05), Vector3(0.0, -0.285, -0.112), p["gold"], 0.0,
		{"chamfer": 0.3, "shine": p["gold_shine"], "top_scale": Vector2(0.9, 0.7)})
