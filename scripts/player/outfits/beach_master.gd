extends PlayerOutfit
## Beach Master, the third cosmetic (GDD §8, "Cosmetics"; 5,000 credits until the way of winning it is designed;
## brief docs/art/BRIEF_OUTFIT_BEACH_MASTER.md, after the owner's concept sheet docs/art/reference/outfit_beach_master.webp):
## an open, short-sleeved tropical shirt in dark teal with coral hibiscus and palm-leaf prints and its sleeves rolled,
## over a camo plate carrier with pouches and harness straps; a sea-salt corroded cyber-arm (rusty, patchy brass with
## green corrosion, bound in worn cloth wraps) in place of Echo's gold one; a fingerless glove and a bead bracelet;
## dark cargo shorts with knee pads, bare lower legs and strapped tactical sandals, on Razor Echo's rig and head (his
## face, scars, spiky hair and copper ocular implant stay his own).
##
## The signature, seen from the gameplay camera: a skull and palm fronds printed across the shirt's back, glowing
## green as the sheet draws it (outfits are free of the colour rule, owner, October 18, 2026). It is soft (the glow
## is Rex's), flat decals whose eye sockets, nose and teeth are dark holes in the light, so bloom doesn't blur the
## skull's shape, and it powers down on death and takes the invulnerability tint like Echo's conduits (it rides in
## the body mesh's glow like every other glowing piece). Nothing else on the outfit glows except Echo's implant.
##
## Left out on purpose: the katana and its sheath and the pistol at the hip (no outfit carries a weapon), the grenades
## and the knife on the carrier (weapons too).
##
## The shirt is short: no coat skirt, but four small panels (HumanoidPanel) for its hem and open front, which swing a
## little with the stride, so the shirt's tails and flaps move as the brief asks.
## DESIGN-TBD (`docs/OPEN_QUESTIONS*.md` items 997-1001), each marked where it lives below: 997 the skull and fronds
## (simplified from the sheet), 998 the hibiscus and leaves (flat coral blooms, only on the back, a sleeve and the hem), 999
## how much of the arm the wraps and corrosion cover, 1000 the four small hem panels, 1001 the sheet's details left out.

## The shirt: dark teal with coral hibiscus and palm-leaf prints.
const SHIRT := Color(0.09, 0.31, 0.34)
const SHIRT_DARK := Color(0.04, 0.19, 0.22)
const SHIRT_LIGHT := Color(0.13, 0.37, 0.38)
const CORAL := Color(0.94, 0.42, 0.34)
const CORAL_DARK := Color(0.72, 0.24, 0.22)
const STAMEN := Color(0.97, 0.8, 0.32)
const LEAF := Color(0.14, 0.56, 0.3)
## The back print: the skull's glowing green, the fronds a shade lighter, and the dark holes cut in it.
const SKULL := Color(0.3, 0.95, 0.45)
const FROND := Color(0.5, 1.0, 0.5)
const SOCKET := Color(0.02, 0.07, 0.07)
## How bright the print is (DESIGN-TBD, `docs/OPEN_QUESTIONS*.md` item 997: the skull's exact shape and glow): Rex's circuit lines (test_outfit_beach_master pins it under the outfits' bloom cap).
const PRINT_GLOW: float = 0.38
## The plate carrier (the same lighter camo as Camo's) and the straps.
const CARRIER := Color(0.34, 0.37, 0.24)
const CARRIER_DARK := Color(0.2, 0.23, 0.14)
const CARRIER_PATCH := Color(0.46, 0.45, 0.3)
const STRAP := Color(0.1, 0.09, 0.08)
const STEEL := Color(0.52, 0.53, 0.56)
## The corroded cyber-arm: rusty, patchy brass with green verdigris, tan cloth wraps and dark steel joints.
const RUST := Color(0.42, 0.28, 0.15)
const BRASS := Color(0.5, 0.4, 0.2)
const VERDIGRIS := Color(0.22, 0.58, 0.48)
const WRAP := Color(0.62, 0.55, 0.4)
const WRAP_DARK := Color(0.44, 0.38, 0.26)
const JOINT_STEEL := Color(0.18, 0.18, 0.2)
const CABLE_RED := Color(0.5, 0.12, 0.1)
const CORROSION_SHINE: float = 0.15
## Cargo shorts, pads, sandals, the glove and the bracelet's beads.
const SHORTS := Color(0.13, 0.14, 0.15)
const SHORTS_DARK := Color(0.08, 0.09, 0.1)
const SHORTS_PATCH := Color(0.2, 0.21, 0.18)
const PAD := Color(0.1, 0.1, 0.11)
const SOLE := Color(0.07, 0.07, 0.07)
## The sun-tanned skin of the arms and legs (Echo's face stays his own).
const TAN := Color(0.65, 0.44, 0.31)
const GLOVE := Color(0.12, 0.11, 0.1)
const BEAD_TEAL := Color(0.15, 0.68, 0.66)
const BEAD_CREAM := Color(0.9, 0.85, 0.7)

## The shirt's tails and flaps: the waist ring its four small panels hang from (pelvis joint space).
## DESIGN-TBD (`docs/OPEN_QUESTIONS*.md` item 1000): what moves on the short shirt, built as four small panels (9 and 13 cm long, following
## the thighs at 35 and 45%).
const HEM_HINGE_Y: float = 0.08
const HEM_HALF := Vector2(0.15, 0.116)
const BACK_TAIL: float = 0.09
const FRONT_FLAP: float = 0.13

const FRONT := OutfitDecals.Face.FRONT
const BACK := OutfitDecals.Face.BACK

## The shirt's back surface (chest joint space) at height y: the lower tier is a hair deeper than the upper one,
## which leans in a little.
static func _back_z(y: float) -> float:
	return 0.1105 if y <= 0.115 else 0.108 - 0.067 * clampf(y - 0.115, 0.0, 0.15)


func body_pieces() -> Array[HumanoidPiece]:
	var list: Array[HumanoidPiece] = []
	_belt(list)
	_shirt(list)
	_carrier(list)
	_back_print(list)
	_prints(list)
	_right_arm(list)
	_corroded_arm(list)
	_legs(list)
	return list


## The shirt's hem and open front: two short tails behind, two flaps at the front edges.
func panels() -> Array[HumanoidPanel]:
	var out: Array[HumanoidPanel] = []
	for side: int in [1, -1]:
		out.append(_hem_panel(side, true))
		out.append(_hem_panel(side, false))
	return out


# --- The body -----------------------------------------------------------------------------

## Cargo shorts over the hips, the belt with its buckle and a camo pouch each side of the small of the back.
## DESIGN-TBD (`docs/OPEN_QUESTIONS*.md` item 1001): the sheet's carabiner on the back belt and thigh harness loops are left out.
func _belt(list: Array[HumanoidPiece]) -> void:
	add(list, &"pelvis", BOX, Vector3(0.25, 0.15, 0.18), Vector3(0.0, -0.05, 0.005), SHORTS, 0.0,
		{"top_scale": Vector2(1.04, 1.04)})
	add(list, &"pelvis", LATHE, Vector3(0.325, 0.0, 0.25), Vector3(0.0, -0.03, 0.005), STRAP, 0.0,
		{"sides": 8, "shine": 0.2, "profile": PackedVector4Array([Vector4(-0.03, 1.0, 1.0, 0.0), Vector4(0.03, 1.0, 1.0, 0.0)])})
	add(list, &"pelvis", BOX, Vector3(0.05, 0.04, 0.014), Vector3(0.0, -0.03, -0.127), STEEL, 0.0, {"shine": 0.5})
	add(list, &"pelvis", BOX, Vector3(0.056, 0.07, 0.042), Vector3(0.078, -0.085, 0.112), CARRIER_DARK, 0.0,
		{"side": MIRRORED, "rotation_degrees": Vector3(0.0, 24.0, 0.0)})
	OutfitDecals.quad(list, &"pelvis", Vector3(0.0846, -0.075, 0.1335), 0.044, 0.04, CARRIER_PATCH, BACK,
		Vector3(0.0, 24.0, 0.0), 0.0, 1.0, MIRRORED)


## The shirt's body in two tiers, its low collar and the harness straps over the shoulders, with bare skin in the open
## neck.
func _shirt(list: Array[HumanoidPiece]) -> void:
	add(list, &"chest", BOX, Vector3(0.285, 0.12, 0.205), Vector3(0.0, 0.055, 0.008), SHIRT, 0.0,
		{"chamfer": 0.4, "top_scale": Vector2(1.07, 1.0)})
	add(list, &"chest", BOX, Vector3(0.3, 0.15, 0.2), Vector3(0.0, 0.19, 0.008), SHIRT, 0.0,
		{"chamfer": 0.45, "top_scale": Vector2(0.97, 0.9)})
	add(list, &"chest", BOX, Vector3(0.09, 0.07, 0.02), Vector3(0.0, 0.247, -0.07), TAN)
	# The open collar, lying flat round the neck.
	add(list, &"chest", SHELL, Vector3(0.2, 0.0, 0.18), Vector3(0.0, 0.25, 0.012), SHIRT_LIGHT, 0.0,
		{"sides": 6, "arc": Vector2(-180.0, 180.0), "thickness": 0.014,
			"profile": PackedVector4Array([Vector4(0.0, 1.0, 1.0, 0.0), Vector4(0.05, 1.1, 1.12, 0.01)])})
	# The carrier's shoulder straps over the shirt, front to back.
	add(list, &"chest", BOX, Vector3(0.04, 0.012, 0.13), Vector3(0.118, 0.27, -0.004), STRAP, 0.0, {"side": MIRRORED})


## The camo plate carrier in the open front, over bare skin: the same pouches, patches and straps as Camo's.
func _carrier(list: Array[HumanoidPiece]) -> void:
	add(list, &"chest", BOX, Vector3(0.17, 0.26, 0.036), Vector3(0.0, 0.1, -0.098), CARRIER, 0.0,
		{"top_scale": Vector2(1.06, 1.0)})
	add(list, &"chest", BOX, Vector3(0.15, 0.062, 0.024), Vector3(0.0, 0.03, -0.134), CARRIER_DARK)
	for x: float in [-0.025, 0.025]:
		OutfitDecals.quad(list, &"chest", Vector3(x, 0.03, -0.1465), 0.004, 0.06, CARRIER, FRONT)
	OutfitDecals.quad(list, &"chest", Vector3(0.0, 0.1, -0.1185), 0.12, 0.012, CARRIER_DARK, FRONT)
	for patch: Array in [[-0.055, 0.19, 0.05, 0.04, CARRIER_DARK], [0.04, 0.175, 0.07, 0.035, CARRIER_PATCH],
			[0.062, 0.115, 0.036, 0.05, CARRIER_DARK], [-0.06, 0.12, 0.04, 0.04, CARRIER_PATCH],
			[0.0, 0.215, 0.05, 0.03, CARRIER_PATCH]]:
		OutfitDecals.quad(list, &"chest", Vector3(patch[0], patch[1], -0.1175), patch[2], patch[3], patch[4], FRONT)
	for side: float in [-1.0, 1.0]:
		pipe(list, &"chest", Vector3(side * 0.075, 0.262, -0.116), Vector3(side * 0.07, 0.05, -0.118), 0.016, Vector3.FORWARD, STRAP)


## The back print the player sees all game: a glowing green skull (a crown, a jaw with its teeth, dark eye sockets and
## nose) with palm fronds fanning from behind its left side, flat on the shirt.
func _back_print(list: Array[HumanoidPiece]) -> void:
	var z := func(y: float) -> float: return _back_z(y) + 0.004
	var tilt := Vector3(-3.8, 0.0, 0.0)
	# The crown and the jaw, glowing.
	OutfitDecals.disc(list, &"chest", Vector3(0.0, 0.172, z.call(0.172)), 0.15, 0.105, SKULL, 8, BACK, tilt, PRINT_GLOW)
	OutfitDecals.quad(list, &"chest", Vector3(0.0, 0.103, z.call(0.103)), 0.068, 0.058, SKULL, BACK, tilt, PRINT_GLOW, 1.5)
	# The dark holes in it: slanted eye sockets, the nose, three teeth.
	for side: float in [-1.0, 1.0]:
		OutfitDecals.quad(list, &"chest", Vector3(side * 0.034, 0.168, z.call(0.168) + 0.002), 0.04, 0.03, SOCKET, BACK,
			Vector3(-3.8, 0.0, side * 16.0))
	OutfitDecals.diamond(list, &"chest", Vector3(0.0, 0.134, z.call(0.134) + 0.002), 0.026, 0.034, SOCKET, BACK, tilt, 0.0, 0.25)
	for x: float in [-0.022, 0.0, 0.022]:
		OutfitDecals.quad(list, &"chest", Vector3(x, 0.098, z.call(0.098) + 0.002), 0.006, 0.04, SOCKET, BACK, tilt)
	# The palm fronds: a tuft fanning up and out from the crown's upper left, a few lower down.
	for frond: Array in [[-0.05, 0.2, 104.0, 0.06], [-0.056, 0.2, 128.0, 0.07], [-0.062, 0.19, 156.0, 0.07],
			[-0.066, 0.172, 184.0, 0.06]]:
		var angle: float = deg_to_rad(float(frond[2]))
		var dir := Vector2(cos(angle), sin(angle))
		var base := Vector2(float(frond[0]), float(frond[1]))
		var centre: Vector2 = base + dir * float(frond[3]) * 0.5
		OutfitDecals.diamond(list, &"chest", Vector3(centre.x, centre.y, z.call(centre.y) + 0.001), 0.026, float(frond[3]), FROND, BACK,
			Vector3(-3.8, 0.0, float(frond[2]) - 90.0), PRINT_GLOW, 0.4)


## DESIGN-TBD (`docs/OPEN_QUESTIONS*.md` item 998): the hibiscus and leaves are flat blooms, five on the back, three patches on the right
## sleeve and a print on each hem panel; the sheet prints the whole shirt.
## The tropical print on the rest of the shirt's back: coral hibiscus (a five-petalled bloom with a yellow heart) and
## dark palm leaves along the lower back under the skull and in its upper right corner. (The front flaps and the
## sleeves are printed in patches: see _right_arm and _hem_panel.)
func _prints(list: Array[HumanoidPiece]) -> void:
	# (x, y, size, roll): a bloom each, with two leaves.
	for flower: Array in [[-0.075, 0.036, 0.056, 10.0], [0.0, 0.018, 0.04, 40.0], [0.07, 0.04, 0.056, -25.0],
			[0.08, 0.215, 0.046, 20.0], [0.086, 0.13, 0.04, -30.0]]:
		_bloom(list, Vector3(flower[0], flower[1], _back_z(flower[1]) + 0.0055), float(flower[2]), float(flower[3]))


## A hibiscus bloom `size` across with two leaves beside it, flat on the back of the shirt.
func _bloom(list: Array[HumanoidPiece], at: Vector3, size: float, roll: float) -> void:
	var tilt := Vector3(-3.8 if at.y > 0.115 else 0.0, 0.0, roll)
	OutfitDecals.disc(list, &"chest", at, size, size, CORAL, 5, BACK, tilt)
	OutfitDecals.quad(list, &"chest", at + Vector3(0.0, 0.0, 0.002), size * 0.32, size * 0.32, STAMEN, BACK, tilt)
	for k: int in 2:
		var a: float = deg_to_rad(roll + 90.0 + (155.0 if k == 0 else -155.0))
		var p: Vector3 = at + Vector3(cos(a) * size * 0.9, sin(a) * size * 0.9, -0.0005)
		OutfitDecals.diamond(list, &"chest", p, size * 0.42, size * 0.95, LEAF, BACK,
			Vector3(tilt.x, 0.0, rad_to_deg(a) - 90.0), 0.0, 0.45)


## The right arm: the short sleeve, rolled, a bare tanned arm below it, a bead bracelet and the fingerless glove
## (Echo's own shapes).
func _right_arm(list: Array[HumanoidPiece]) -> void:
	var sleeve := piece(&"upper_arm", PRISM, Vector3(0.108, 0.1, 0.1), Vector3(0.0, -0.03, 0.0), SHIRT, 0.0,
		{"side": RIGHT, "top_scale": Vector2(1.15, 1.15)})
	list.append(sleeve)
	OutfitDecals.on_prism(list, sleeve, Vector2(150.0, 210.0), 0.2, 0.6, CORAL)
	OutfitDecals.on_prism(list, sleeve, Vector2(100.0, 140.0), 0.45, 0.85, LEAF)
	OutfitDecals.on_prism(list, sleeve, Vector2(60.0, 100.0), 0.1, 0.4, CORAL_DARK)
	add(list, &"upper_arm", PRISM, Vector3(0.115, 0.07, 0.125), Vector3(0.012, 0.012, 0.0), SHIRT, 0.0,
		{"side": RIGHT, "top_scale": Vector2(0.78, 0.82)})
	# The rolled cuff, then the bare arm.
	add(list, &"upper_arm", PRISM, Vector3(0.12, 0.034, 0.112), Vector3(0.0, -0.1, 0.0), SHIRT_LIGHT, 0.0, {"side": RIGHT})
	add(list, &"upper_arm", PRISM, Vector3(0.084, 0.1, 0.08), Vector3(0.0, -0.155, 0.0), TAN, 0.0,
		{"side": RIGHT, "top_scale": Vector2(0.9, 0.9)})
	add(list, &"forearm", PRISM, Vector3(0.076, 0.16, 0.072), Vector3(0.0, -0.08, 0.0), TAN, 0.0,
		{"side": RIGHT, "top_scale": Vector2(1.12, 1.12)})
	# The bead bracelet: a teal strand with a coral bead on it.
	add(list, &"forearm", BAND, Vector3(0.082, 0.0, 0.078), Vector3(0.0, -0.155, 0.0), BEAD_TEAL, 0.0, {"side": RIGHT,
		"profile": PackedVector4Array([Vector4(-0.01, 1.0, 1.0, 0.0), Vector4(0.01, 1.0, 1.0, 0.0)])})
	add(list, &"forearm", BAND, Vector3(0.084, 0.0, 0.08), Vector3(0.0, -0.137, 0.0), BEAD_CREAM, 0.0, {"side": RIGHT,
		"profile": PackedVector4Array([Vector4(-0.005, 1.0, 1.0, 0.0), Vector4(0.005, 1.0, 1.0, 0.0)])})
	add(list, &"hand", BOX, Vector3(0.06, 0.066, 0.072), Vector3(0.0, -0.035, -0.004), GLOVE, 0.0,
		{"side": RIGHT, "chamfer": 0.35})
	add(list, &"hand", BOX, Vector3(0.054, 0.032, 0.056), Vector3(0.0, -0.082, -0.01), TAN, 0.0, {"side": RIGHT})


## DESIGN-TBD (`docs/OPEN_QUESTIONS*.md` item 999): five wraps and seven verdigris patches; the sheet binds nearly all of the arm.
## The sea-salt corroded cyber-arm on the left, from the shoulder down: rusty brass plates with green corrosion
## patches round exposed joints, bound in tan cloth wraps, and an articulated hand. (Authored on the right, placed
## on the left.)
func _corroded_arm(list: Array[HumanoidPiece]) -> void:
	var worn := {"side": LEFT, "shine": CORROSION_SHINE}
	# The shoulder: Echo's dome (the weapon's mount folds out over it) with a verdigris stain, wrapped below.
	add(list, &"upper_arm", LATHE, Vector3(0.13, 0.0, 0.13), Vector3(0.012, 0.0, 0.0), RUST, 0.0,
		merged(worn, {"sides": 6, "profile": PackedVector4Array([Vector4(-0.045, 1.0, 1.0, 0.0),
			Vector4(0.012, 0.96, 0.96, 0.0), Vector4(0.05, 0.55, 0.55, 0.0)])}))
	add(list, &"upper_arm", BAND, Vector3(0.13, 0.0, 0.13), Vector3(0.012, 0.0, 0.0), VERDIGRIS, 0.0,
		merged(worn, {"sides": 6, "arc": Vector2(-30.0, 120.0),
			"profile": PackedVector4Array([Vector4(0.012, 1.0, 1.0, 0.0), Vector4(0.05, 0.6, 0.6, 0.0)])}))
	var plate_a := piece(&"upper_arm", PRISM, Vector3(0.078, 0.085, 0.074), Vector3(0.0, -0.06, 0.0), BRASS, 0.0,
		merged(worn, {"top_scale": Vector2(1.08, 1.08)}))
	list.append(plate_a)
	OutfitDecals.on_prism(list, plate_a, Vector2(100.0, 230.0), 0.1, 0.55, VERDIGRIS, 0.08).shine = 0.0
	OutfitDecals.on_prism(list, plate_a, Vector2(-60.0, 60.0), 0.45, 0.95, VERDIGRIS, 0.08).shine = 0.0
	add(list, &"upper_arm", PRISM, Vector3(0.05, 0.034, 0.048), Vector3(0.0, -0.119, 0.0), JOINT_STEEL, 0.0, {"side": LEFT, "sides": 4})
	pipe(list, &"upper_arm", Vector3(-0.02, -0.098, -0.032), Vector3(-0.012, -0.142, -0.034), 0.014, Vector3.FORWARD, CABLE_RED, 0.0, LEFT)
	var plate_b := piece(&"upper_arm", PRISM, Vector3(0.082, 0.07, 0.078), Vector3(0.0, -0.17, 0.0), RUST, 0.0,
		merged(worn, {"top_scale": Vector2(0.96, 0.96)}))
	list.append(plate_b)
	OutfitDecals.on_prism(list, plate_b, Vector2(-60.0, 70.0), 0.3, 0.85, VERDIGRIS, 0.08).shine = 0.0
	OutfitDecals.on_prism(list, plate_b, Vector2(150.0, 210.0), 0.05, 0.45, VERDIGRIS, 0.08).shine = 0.0
	add(list, &"upper_arm", PRISM, Vector3(0.068, 0.04, 0.068), Vector3(0.0, -0.205, 0.0), JOINT_STEEL, 0.0,
		{"side": LEFT, "sides": 4, "rotation_degrees": Vector3(0.0, 0.0, 90.0)})
	# The cloth wraps: tilted rings of tan cloth round the plates.
	_wrap(list, &"upper_arm", 0.09, -0.03, 0.026, 12.0)
	_wrap(list, &"upper_arm", 0.092, -0.145, 0.03, -14.0)
	_wrap(list, &"forearm", 0.086, -0.03, 0.03, 10.0)
	_wrap(list, &"forearm", 0.082, -0.075, 0.026, -12.0)
	_wrap(list, &"forearm", 0.08, -0.155, 0.03, 14.0)
	# The forearm plates and the wrist ring.
	var plate_c := piece(&"forearm", PRISM, Vector3(0.074, 0.08, 0.07), Vector3(0.0, -0.05, 0.0), BRASS, 0.0,
		merged(worn, {"top_scale": Vector2(1.14, 1.1)}))
	list.append(plate_c)
	OutfitDecals.on_prism(list, plate_c, Vector2(150.0, 210.0), 0.2, 0.75, VERDIGRIS, 0.08).shine = 0.0
	add(list, &"forearm", PRISM, Vector3(0.05, 0.026, 0.048), Vector3(0.0, -0.103, 0.0), JOINT_STEEL, 0.0, {"side": LEFT, "sides": 4})
	var plate_d := piece(&"forearm", PRISM, Vector3(0.072, 0.07, 0.068), Vector3(0.0, -0.148, 0.0), RUST, 0.0,
		merged(worn, {"top_scale": Vector2(0.92, 0.92)}))
	list.append(plate_d)
	OutfitDecals.on_prism(list, plate_d, Vector2(-70.0, 70.0), 0.4, 0.9, VERDIGRIS, 0.08).shine = 0.0
	# The hand: a corroded palm, three fingers and a dark knuckle joint.
	add(list, &"hand", BOX, Vector3(0.062, 0.066, 0.074), Vector3(0.0, -0.035, -0.004), BRASS, 0.0,
		merged(worn, {"chamfer": 0.35}))
	for x: float in [-0.021, 0.0, 0.021]:
		add(list, &"hand", PRISM, Vector3(0.018, 0.05, 0.02), Vector3(x, -0.09, -0.012), RUST, 0.0, {"side": LEFT, "sides": 4})
	OutfitDecals.quad(list, &"hand", Vector3(0.0, -0.066, -0.0415), 0.062, 0.012, JOINT_STEEL, FRONT, Vector3.ZERO, 0.0, 1.0, LEFT)


## A ring of cloth round the arm, `width` across and `height` tall at `y`, tilted `roll` degrees.
func _wrap(list: Array[HumanoidPiece], segment: StringName, width: float, y: float, height: float, roll: float) -> void:
	add(list, segment, BAND, Vector3(width, 0.0, width * 0.95), Vector3(0.0, y, 0.0), WRAP if roll > 0.0 else WRAP_DARK, 0.0,
		{"side": LEFT, "sides": 5, "rotation_degrees": Vector3(roll * 0.4, 0.0, roll),
			"profile": PackedVector4Array([Vector4(-height * 0.5, 1.0, 1.0, 0.0), Vector4(height * 0.5, 1.0, 1.0, 0.0)])})


## Dark cargo shorts with a pocket on each thigh and knee pads over bare, tanned lower legs, and
## strapped tactical sandals.
func _legs(list: Array[HumanoidPiece]) -> void:
	var thigh := piece(&"thigh", PRISM, Vector3(0.118, 0.32, 0.118), Vector3(0.0, -0.145, 0.0), SHORTS, 0.0,
		{"top_scale": Vector2(1.2, 1.2)})
	list.append(thigh)
	OutfitDecals.on_prism(list, thigh, Vector2(150.0, 210.0), 0.2, 0.62, SHORTS_PATCH)
	OutfitDecals.on_prism(list, thigh, Vector2(60.0, 130.0), 0.5, 0.82, SHORTS_DARK)
	add(list, &"thigh", BOX, Vector3(0.036, 0.1, 0.07), Vector3(0.068, -0.17, 0.0), SHORTS_DARK)
	# The bare lower leg, the knee pad strapped on, and the sandal's ankle strap.
	add(list, &"shin", PRISM, Vector3(0.085, 0.24, 0.085), Vector3(0.0, -0.155, 0.0), TAN, 0.0,
		{"top_scale": Vector2(1.12, 1.12)})
	add(list, &"shin", BOX, Vector3(0.09, 0.09, 0.04), Vector3(0.0, -0.035, -0.058), PAD, 0.0, {"top_scale": Vector2(0.9, 0.8)})
	add(list, &"shin", BAND, Vector3(0.1, 0.0, 0.1), Vector3(0.0, -0.09, 0.0), STRAP, 0.0,
		{"profile": PackedVector4Array([Vector4(-0.012, 1.0, 1.0, 0.0), Vector4(0.012, 1.0, 1.0, 0.0)])})
	add(list, &"shin", BAND, Vector3(0.098, 0.0, 0.098), Vector3(0.0, -0.268, 0.0), STRAP, 0.0,
		{"profile": PackedVector4Array([Vector4(-0.016, 1.0, 1.0, 0.0), Vector4(0.016, 1.0, 1.0, 0.0)])})
	# The sandal: a thick sole, the bare foot on it, an instep strap and a heel strap.
	add(list, &"foot", BOX, Vector3(0.09, 0.04, 0.19), Vector3(0.0, -0.03, -0.05), TAN, 0.0,
		{"top_scale": Vector2(0.9, 0.8), "top_shift": 0.01})
	add(list, &"foot", BOX, Vector3(0.102, 0.03, 0.21), Vector3(0.0, -0.06, -0.045), SOLE)
	add(list, &"foot", BOX, Vector3(0.098, 0.022, 0.034), Vector3(0.0, -0.008, -0.068), STRAP)
	add(list, &"foot", BOX, Vector3(0.09, 0.044, 0.016), Vector3(0.0, -0.035, 0.058), STRAP)


# --- The shirt's tails and flaps -----------------------------------------------------------------

## One small panel of the shirt's hem: a tail behind the legs or a flap at the open front, with its prints.
func _hem_panel(side: int, behind: bool) -> HumanoidPanel:
	var panel := HumanoidPanel.new()
	panel.side = side
	panel.behind = behind
	panel.length = BACK_TAIL if behind else FRONT_FLAP
	panel.hinge = Vector3(0.1, HEM_HINGE_Y, 0.064) if behind else Vector3(0.13, HEM_HINGE_Y, -0.046)
	panel.follow = 0.35 if behind else 0.45
	var arc := Vector2(91.0, 179.0) if behind else Vector2(31.0, 89.0)
	var length: float = panel.length
	var pieces: Array[HumanoidPiece] = []
	pieces.append(piece(&"pelvis", SHELL, Vector3(HEM_HALF.x * 2.0, 0.0, HEM_HALF.y * 2.0), Vector3(0.0, HEM_HINGE_Y, 0.008),
		SHIRT, 0.0, {"sides": 12, "section_phase": 15.0, "arc": arc, "thickness": 0.01,
			"profile": PackedVector4Array([Vector4(0.03, 1.0, 1.0, 0.0), Vector4(-length, 1.14, 1.14, 0.008)])}))
	# A light band at the hem and a print on the faces.
	pieces.append(_hem_patch(arc, -length + 0.02, -length, SHIRT_LIGHT, length))
	# The ring is an oval, so its faces sit at no tidy angle: they come from the shape, counted from the one nearest the front.
	var directions: PackedFloat32Array = OutfitDecals.faces_in(OutfitDecals.face_directions(HEM_HALF * 2.0, 12, 15.0), arc)
	for face: int in ([0, 2] if behind else [0]):
		pieces.append(_hem_patch(OutfitDecals.face_arc(directions[face]), -length * 0.2, -length * 0.65,
			CORAL if (not behind and side > 0) else LEAF, length))
	panel.pieces = pieces
	return panel


func _hem_patch(arc: Vector2, from: float, to: float, color: Color, length: float) -> HumanoidPiece:
	var rings := PackedVector4Array()
	for h: float in [from, to]:
		var t: float = (0.03 - h) / (0.03 + length)
		var s: float = 1.0 + 0.14 * t + 0.03
		rings.append(Vector4(h, s, s, 0.008 * t))
	return piece(&"pelvis", BAND, Vector3(HEM_HALF.x * 2.0, 0.0, HEM_HALF.y * 2.0), Vector3(0.0, HEM_HINGE_Y, 0.008),
		color, 0.0, {"sides": 12, "section_phase": 15.0, "arc": arc, "profile": rings})
