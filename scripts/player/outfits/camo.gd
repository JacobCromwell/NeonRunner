extends PlayerOutfit
## Camo, the second cosmetic (GDD §8, "Cosmetics"; 3,000 credits; brief docs/art/BRIEF_OUTFIT_CAMO.md, after the
## owner's concept sheet docs/art/reference/outfit_camo.webp): an aged olive military trench coat with a high
## collar, epaulettes, camo patches, a worn and stained hem and dark tubing across the upper back, over a camo
## plate carrier with pouches and harness straps; an armoured, dull brass cyber-arm with exposed joints in place
## of Echo's gold one; a fingerless glove, dark camo cargo pants with knee pads and tall laced combat boots, on
## Razor Echo's rig and head (his face, scars, spiky hair and copper ocular implant stay his own).
##
## Nothing glows (the brief: the coat, the carrier and the arm are unlit; the arm's brass is dull and worn so it
## never reads as gold treasure or as a power-up). The only light on the runner is Echo's own copper implant, so
## the suit-glow effects (the invulnerability tint, the dash trail, the death power-down) work on the body's
## colours as they do on Echo's own look.
##
## Left out on purpose: the katana and its sheath and the holstered pistol (no outfit carries a weapon), the
## grenades and the knife on the carrier (weapons too) and the skull on the coat's lower back (too small to
## read, as on Echo's own coat).
##
## Seen from the gameplay camera (behind and above): the long olive coat, its camo patches and the dark tubing
## across the shoulder blades, the epaulettes, the belt's two pouches, the brass arm on the left, then the coat's
## swinging skirt over the boots. The coat is four stiff panels hinged at the waist like Echo's (HumanoidPanel).
## DESIGN-TBD (docs/questions/m2.md): the camo pattern (rectangular patches, not the sheet's exact blotches), how
## stained the hem is, the shape of the tubing.

## The coat and its camo patches: aged olive with darker green, brown and khaki patches, and a stained hem.
const OLIVE := Color(0.32, 0.34, 0.18)
const OLIVE_DARK := Color(0.23, 0.25, 0.13)
const OLIVE_LIGHT := Color(0.4, 0.41, 0.23)
const PATCH_GREEN := Color(0.15, 0.21, 0.09)
const PATCH_BROWN := Color(0.43, 0.3, 0.15)
const PATCH_TAN := Color(0.55, 0.5, 0.31)
const PATCH_BLACK := Color(0.1, 0.11, 0.07)
const STAIN := Color(0.24, 0.18, 0.1)
const DUST := Color(0.38, 0.33, 0.21)
## The dark tubing across the upper back, and the straps and belts.
const TUBE := Color(0.07, 0.07, 0.08)
const TUBE_SHINE: float = 0.55
const STRAP := Color(0.1, 0.09, 0.08)
const STEEL := Color(0.52, 0.53, 0.56)
const SHIRT := Color(0.09, 0.09, 0.1)
## The plate carrier: a lighter camo with its pouches.
const CARRIER := Color(0.34, 0.37, 0.24)
const CARRIER_DARK := Color(0.2, 0.23, 0.14)
const CARRIER_PATCH := Color(0.46, 0.45, 0.3)
## The cyber-arm: worn, dull brass (never Echo's polished gold), dark steel joints, a red and a black cable.
const BRASS := Color(0.5, 0.43, 0.21)
const BRASS_DARK := Color(0.28, 0.23, 0.12)
const BRASS_EDGE := Color(0.62, 0.54, 0.31)
const JOINT_STEEL := Color(0.18, 0.18, 0.2)
const CABLE_RED := Color(0.5, 0.12, 0.1)
const BRASS_SHINE: float = 0.25
## Cargo pants, knee pads, boots and gloves.
const PANTS := Color(0.15, 0.16, 0.17)
const PANTS_DARK := Color(0.09, 0.1, 0.11)
const PANTS_PATCH := Color(0.22, 0.23, 0.2)
const PAD := Color(0.1, 0.1, 0.11)
const BOOT := Color(0.27, 0.21, 0.14)
const BOOT_DARK := Color(0.12, 0.1, 0.08)
const LACE := Color(0.5, 0.46, 0.34)
const SOLE := Color(0.06, 0.06, 0.06)
const GLOVE := Color(0.12, 0.11, 0.1)

## The coat's skirt: the waist ring its panels hang from (pelvis joint space), their length and flare.
const SKIRT_HINGE_Y: float = 0.03
const SKIRT_HALF := Vector2(0.154, 0.12)
const SKIRT_LENGTH: float = 0.47
const SKIRT_FLARE: float = 1.28
## The stained hem's height.
const HEM_BAND: float = 0.075

const FRONT := OutfitDecals.Face.FRONT
const BACK := OutfitDecals.Face.BACK

## The coat's back surface (chest joint space) at height y: the lower tier is a hair deeper than the upper one,
## which leans in a little.
static func _back_z(y: float) -> float:
	return 0.1105 if y <= 0.115 else 0.108 - 0.067 * clampf(y - 0.115, 0.0, 0.15)


func body_pieces() -> Array[HumanoidPiece]:
	var list: Array[HumanoidPiece] = []
	_belt(list)
	_coat(list)
	_carrier(list)
	_back(list)
	_right_arm(list)
	_brass_arm(list)
	_legs(list)
	return list


## The coat's skirt, four stiff panels hinged under the belt: two behind the legs, split by the back vent, and
## two at the front edges of the open coat.
func panels() -> Array[HumanoidPanel]:
	var out: Array[HumanoidPanel] = []
	for side: int in [1, -1]:
		out.append(_skirt_panel(side, true))
		out.append(_skirt_panel(side, false))
	return out


# --- The body -----------------------------------------------------------------------------

## Cargo pants over the hips, the belt with its buckle and a pouch each side of the small of the back.
func _belt(list: Array[HumanoidPiece]) -> void:
	add(list, &"pelvis", BOX, Vector3(0.245, 0.15, 0.175), Vector3(0.0, -0.045, 0.005), PANTS, 0.0,
		{"top_scale": Vector2(1.04, 1.04)})
	add(list, &"pelvis", LATHE, Vector3(0.325, 0.0, 0.25), Vector3(0.0, SKIRT_HINGE_Y, 0.005), STRAP, 0.0,
		{"sides": 8, "shine": 0.2, "profile": PackedVector4Array([Vector4(-0.035, 1.0, 1.0, 0.0), Vector4(0.03, 1.0, 1.0, 0.0)])})
	add(list, &"pelvis", BOX, Vector3(0.05, 0.04, 0.014), Vector3(0.0, SKIRT_HINGE_Y, -0.127), STEEL, 0.0, {"shine": 0.5})
	# The pouches hang over the coat's skirt from the belt, turned to follow its curve.
	add(list, &"pelvis", BOX, Vector3(0.052, 0.07, 0.042), Vector3(0.106, 0.0, 0.105), CARRIER_DARK, 0.0,
		{"side": MIRRORED, "rotation_degrees": Vector3(0.0, 33.0, 0.0)})
	OutfitDecals.quad(list, &"pelvis", Vector3(0.1135, 0.012, 0.1255), 0.04, 0.032, OLIVE_LIGHT, BACK,
		Vector3(0.0, 33.0, 0.0), 0.0, 1.0, MIRRORED)


## The coat's body in two tiers (waist to chest, chest to shoulders), the high collar, the turned-back lapels, and
## the dark shirt at the open neck.
func _coat(list: Array[HumanoidPiece]) -> void:
	add(list, &"chest", BOX, Vector3(0.285, 0.19, 0.205), Vector3(0.0, 0.02, 0.008), OLIVE, 0.0,
		{"chamfer": 0.4, "top_scale": Vector2(1.07, 1.0)})
	add(list, &"chest", BOX, Vector3(0.3, 0.15, 0.2), Vector3(0.0, 0.19, 0.008), OLIVE, 0.0,
		{"chamfer": 0.45, "top_scale": Vector2(0.97, 0.9)})
	add(list, &"chest", BOX, Vector3(0.09, 0.07, 0.02), Vector3(0.0, 0.247, -0.07), SHIRT)
	# The lapels, wider at the top, flanking the carrier.
	add(list, &"chest", BOX, Vector3(0.06, 0.17, 0.014), Vector3(0.105, 0.185, -0.105), OLIVE_DARK, 0.0,
		{"side": MIRRORED, "top_scale": Vector2(1.35, 1.0), "rotation_degrees": Vector3(0.0, 0.0, -9.0)})
	# The high collar, all round the neck.
	add(list, &"chest", SHELL, Vector3(0.2, 0.0, 0.18), Vector3(0.0, 0.245, 0.012), OLIVE_DARK, 0.0,
		{"sides": 6, "arc": Vector2(-180.0, 180.0), "thickness": 0.014,
			"profile": PackedVector4Array([Vector4(0.0, 1.0, 1.0, 0.0), Vector4(0.105, 1.12, 1.15, 0.012)])})


## The camo plate carrier in the coat's open front: pouches, a harness strap over each shoulder and a patch pattern.
func _carrier(list: Array[HumanoidPiece]) -> void:
	add(list, &"chest", BOX, Vector3(0.17, 0.26, 0.036), Vector3(0.0, 0.1, -0.098), CARRIER, 0.0,
		{"top_scale": Vector2(1.06, 1.0)})
	add(list, &"chest", BOX, Vector3(0.15, 0.062, 0.024), Vector3(0.0, 0.03, -0.134), CARRIER_DARK)
	for x: float in [-0.025, 0.025]:
		OutfitDecals.quad(list, &"chest", Vector3(x, 0.03, -0.1465), 0.004, 0.06, CARRIER, FRONT)
	OutfitDecals.quad(list, &"chest", Vector3(0.0, 0.1, -0.1175), 0.12, 0.012, CARRIER_DARK, FRONT)
	# The patch pattern across the front.
	for patch: Array in [[-0.055, 0.19, 0.05, 0.04, PATCH_GREEN], [0.04, 0.175, 0.07, 0.035, PATCH_BROWN],
			[0.062, 0.115, 0.036, 0.05, PATCH_GREEN], [-0.06, 0.12, 0.04, 0.04, CARRIER_PATCH],
			[0.0, 0.215, 0.05, 0.03, CARRIER_PATCH], [-0.02, 0.063, 0.04, 0.02, PATCH_BROWN]]:
		OutfitDecals.quad(list, &"chest", Vector3(patch[0], patch[1], -0.1175), patch[2], patch[3], patch[4], FRONT)
	# The harness: a strap down each side of the carrier, from the shoulders.
	for side: float in [-1.0, 1.0]:
		pipe(list, &"chest", Vector3(side * 0.075, 0.262, -0.116), Vector3(side * 0.07, 0.05, -0.118), 0.016, Vector3.FORWARD, STRAP)


## The back, which the player sees all game: the camo patches and the dark tubing across the shoulder blades.
func _back(list: Array[HumanoidPiece]) -> void:
	# The patches (x, y, width, height, colour), tilted to the leaning upper back.
	for patch: Array in [[-0.085, 0.225, 0.075, 0.05, PATCH_GREEN], [0.07, 0.24, 0.085, 0.04, PATCH_BROWN],
			[0.098, 0.17, 0.05, 0.075, PATCH_GREEN], [-0.1, 0.155, 0.045, 0.06, PATCH_TAN],
			[0.005, 0.17, 0.06, 0.04, PATCH_BROWN], [-0.075, 0.062, 0.075, 0.05, PATCH_BROWN],
			[0.078, 0.035, 0.085, 0.06, PATCH_GREEN], [0.0, -0.025, 0.075, 0.04, PATCH_TAN],
			[-0.1, -0.03, 0.04, 0.05, PATCH_BLACK], [0.1, 0.095, 0.04, 0.045, PATCH_TAN], [-0.02, 0.1, 0.05, 0.03, PATCH_GREEN]]:
		var y: float = patch[1]
		var tilt: float = -3.8 if y > 0.115 else 0.0
		OutfitDecals.quad(list, &"chest", Vector3(patch[0], y, _back_z(y) + 0.004), patch[2], patch[3], patch[4], BACK,
			Vector3(tilt, 0.0, 0.0))
	# The dark tubing: two pipes from the shoulder blades that bend in toward the spine and run down to the belt, tied
	# together by two rungs.
	var at := func(x: float, y: float) -> Vector3: return Vector3(x, y, _back_z(y) + 0.013)
	var tube := func(a: Vector3, b: Vector3) -> void:
		pipe(list, &"chest", a, b, 0.02, Vector3.BACK, TUBE).shine = TUBE_SHINE
	tube.call(at.call(-0.082, 0.255), at.call(-0.082, 0.13))
	tube.call(at.call(-0.082, 0.13), at.call(-0.03, 0.07))
	tube.call(at.call(-0.03, 0.07), at.call(-0.03, -0.05))
	tube.call(at.call(0.07, 0.255), at.call(0.07, 0.15))
	tube.call(at.call(0.07, 0.15), at.call(0.03, 0.095))
	tube.call(at.call(0.03, 0.095), at.call(0.03, -0.05))
	tube.call(at.call(-0.082, 0.2), at.call(0.07, 0.2))
	tube.call(at.call(-0.03, 0.03), at.call(0.03, 0.03))


## The right arm: the coat's sleeve with its camo patches and epaulette, a strapped cuff, the fingerless glove
## (Echo's own shapes).
func _right_arm(list: Array[HumanoidPiece]) -> void:
	var sleeve := _sleeve(list, &"upper_arm", Vector3(0.1, 0.22, 0.095), Vector3(0.0, -0.095, 0.0), Vector2(1.15, 1.15))
	OutfitDecals.on_prism(list, sleeve, Vector2(150.0, 210.0), 0.5, 0.88, PATCH_GREEN)
	OutfitDecals.on_prism(list, sleeve, Vector2(90.0, 150.0), 0.1, 0.46, PATCH_BROWN)
	OutfitDecals.on_prism(list, sleeve, Vector2(150.0, 210.0), 0.08, 0.3, PATCH_TAN)
	add(list, &"upper_arm", PRISM, Vector3(0.115, 0.07, 0.125), Vector3(0.012, 0.012, 0.0), OLIVE, 0.0,
		{"side": RIGHT, "top_scale": Vector2(0.78, 0.82)})
	# The epaulette: a flat strap over the shoulder with a khaki end.
	add(list, &"upper_arm", BOX, Vector3(0.05, 0.012, 0.105), Vector3(0.03, 0.054, 0.0), OLIVE_DARK, 0.0,
		{"side": RIGHT, "rotation_degrees": Vector3(0.0, 0.0, -16.0)})
	add(list, &"upper_arm", BOX, Vector3(0.052, 0.014, 0.024), Vector3(0.028, 0.056, -0.046), PATCH_TAN, 0.0,
		{"side": RIGHT, "rotation_degrees": Vector3(0.0, 0.0, -16.0)})
	var forearm := _sleeve(list, &"forearm", Vector3(0.085, 0.16, 0.08), Vector3(0.0, -0.075, 0.0), Vector2(1.1, 1.1))
	OutfitDecals.on_prism(list, forearm, Vector2(150.0, 210.0), 0.15, 0.6, PATCH_BROWN)
	add(list, &"forearm", PRISM, Vector3(0.1, 0.045, 0.095), Vector3(0.0, -0.15, 0.0), OLIVE_DARK, 0.0, {"side": RIGHT})
	add(list, &"forearm", BAND, Vector3(0.108, 0.0, 0.103), Vector3(0.0, -0.14, 0.0), STRAP, 0.0, {"side": RIGHT,
		"profile": PackedVector4Array([Vector4(-0.008, 1.0, 1.0, 0.0), Vector4(0.008, 1.0, 1.0, 0.0)])})
	add(list, &"hand", BOX, Vector3(0.06, 0.066, 0.072), Vector3(0.0, -0.035, -0.004), GLOVE, 0.0,
		{"side": RIGHT, "chamfer": 0.35})
	add(list, &"hand", BOX, Vector3(0.054, 0.032, 0.056), Vector3(0.0, -0.082, -0.01), PlayerSuit.SKIN, 0.0, {"side": RIGHT})


## A coat-sleeve prism on the right arm, returned so patches can be laid over it.
func _sleeve(list: Array[HumanoidPiece], segment: StringName, size: Vector3, at: Vector3, top: Vector2) -> HumanoidPiece:
	var p: HumanoidPiece = piece(segment, PRISM, size, at, OLIVE, 0.0, {"side": RIGHT, "top_scale": top})
	list.append(p)
	return p


## The armoured cyber-arm on the left, from the shoulder down, in dull worn brass: a domed pauldron with a plate
## over the outer shoulder, an upper arm in two plates round an exposed joint with its cables, an elbow disc, a
## forearm in two plates and a wrist ring, and an articulated hand. (Authored on the right, placed on the left.)
func _brass_arm(list: Array[HumanoidPiece]) -> void:
	var brass := {"side": LEFT, "shine": BRASS_SHINE}
	# The pauldron: Echo's dome (the weapon's mount folds out over it), a rim, and a flared plate over the outside.
	add(list, &"upper_arm", LATHE, Vector3(0.13, 0.0, 0.13), Vector3(0.012, 0.0, 0.0), BRASS, 0.0,
		merged(brass, {"sides": 6, "profile": PackedVector4Array([Vector4(-0.045, 1.0, 1.0, 0.0),
			Vector4(0.012, 0.96, 0.96, 0.0), Vector4(0.05, 0.55, 0.55, 0.0)])}))
	add(list, &"upper_arm", BAND, Vector3(0.136, 0.0, 0.136), Vector3(0.012, -0.03, 0.0), BRASS_DARK, 0.0, {"side": LEFT, "sides": 6,
		"profile": PackedVector4Array([Vector4(-0.008, 1.0, 1.0, 0.0), Vector4(0.008, 1.0, 1.0, 0.0)])})
	add(list, &"upper_arm", BOX, Vector3(0.03, 0.07, 0.115), Vector3(0.074, -0.01, 0.0), BRASS_EDGE, 0.0,
		merged(brass, {"top_scale": Vector2(0.8, 0.9), "rotation_degrees": Vector3(0.0, 0.0, -22.0)}))
	# The upper arm: a plate, the exposed joint with its cables, a second plate, the elbow disc.
	add(list, &"upper_arm", PRISM, Vector3(0.078, 0.085, 0.074), Vector3(0.0, -0.06, 0.0), BRASS, 0.0,
		merged(brass, {"top_scale": Vector2(1.08, 1.08)}))
	add(list, &"upper_arm", PRISM, Vector3(0.05, 0.034, 0.048), Vector3(0.0, -0.119, 0.0), JOINT_STEEL, 0.0, {"side": LEFT, "sides": 4})
	pipe(list, &"upper_arm", Vector3(-0.02, -0.098, -0.032), Vector3(-0.012, -0.142, -0.034), 0.014, Vector3.FORWARD, CABLE_RED, 0.0, LEFT)
	pipe(list, &"upper_arm", Vector3(0.018, -0.098, 0.032), Vector3(0.012, -0.142, 0.034), 0.014, Vector3.BACK, TUBE, 0.0, LEFT)
	add(list, &"upper_arm", PRISM, Vector3(0.082, 0.07, 0.078), Vector3(0.0, -0.17, 0.0), BRASS, 0.0,
		merged(brass, {"top_scale": Vector2(0.96, 0.96)}))
	add(list, &"upper_arm", PRISM, Vector3(0.068, 0.04, 0.068), Vector3(0.0, -0.205, 0.0), JOINT_STEEL, 0.0,
		{"side": LEFT, "sides": 4, "rotation_degrees": Vector3(0.0, 0.0, 90.0)})
	# The forearm: an upper plate, a joint with a cable, a lower plate, the wrist ring.
	add(list, &"forearm", PRISM, Vector3(0.074, 0.08, 0.07), Vector3(0.0, -0.05, 0.0), BRASS, 0.0,
		merged(brass, {"top_scale": Vector2(1.14, 1.1)}))
	add(list, &"forearm", PRISM, Vector3(0.05, 0.026, 0.048), Vector3(0.0, -0.1, 0.0), JOINT_STEEL, 0.0, {"side": LEFT, "sides": 4})
	pipe(list, &"forearm", Vector3(-0.02, -0.088, -0.03), Vector3(-0.016, -0.114, -0.03), 0.012, Vector3.FORWARD, CABLE_RED, 0.0, LEFT)
	add(list, &"forearm", PRISM, Vector3(0.072, 0.07, 0.068), Vector3(0.0, -0.148, 0.0), BRASS, 0.0,
		merged(brass, {"top_scale": Vector2(0.92, 0.92)}))
	add(list, &"forearm", BOX, Vector3(0.012, 0.09, 0.05), Vector3(0.04, -0.06, 0.0), BRASS_EDGE, 0.0, brass)
	add(list, &"forearm", PRISM, Vector3(0.078, 0.016, 0.074), Vector3(0.0, -0.178, 0.0), BRASS_DARK, 0.0, {"side": LEFT, "sides": 4})
	# The hand: a plated palm and three fingers with a dark knuckle joint across them.
	add(list, &"hand", BOX, Vector3(0.062, 0.066, 0.074), Vector3(0.0, -0.035, -0.004), BRASS, 0.0,
		merged(brass, {"chamfer": 0.35}))
	for x: float in [-0.021, 0.0, 0.021]:
		add(list, &"hand", PRISM, Vector3(0.018, 0.05, 0.02), Vector3(x, -0.09, -0.012), BRASS_DARK, 0.0, {"side": LEFT, "sides": 4})
	OutfitDecals.quad(list, &"hand", Vector3(0.0, -0.066, -0.0415), 0.062, 0.012, JOINT_STEEL, FRONT, Vector3.ZERO, 0.0, 1.0, LEFT)


## Dark camo cargo pants with a patch and a pocket on each thigh and knee pads, and tall laced combat boots.
func _legs(list: Array[HumanoidPiece]) -> void:
	var thigh := piece(&"thigh", PRISM, Vector3(0.115, 0.32, 0.115), Vector3(0.0, -0.145, 0.0), PANTS, 0.0,
		{"top_scale": Vector2(1.2, 1.2)})
	list.append(thigh)
	OutfitDecals.on_prism(list, thigh, Vector2(150.0, 210.0), 0.25, 0.7, PANTS_PATCH)
	OutfitDecals.on_prism(list, thigh, Vector2(60.0, 130.0), 0.55, 0.85, PANTS_DARK)
	add(list, &"thigh", BOX, Vector3(0.032, 0.09, 0.066), Vector3(0.064, -0.19, 0.0), PANTS_DARK)
	add(list, &"shin", PRISM, Vector3(0.095, 0.18, 0.095), Vector3(0.0, -0.08, 0.0), PANTS, 0.0,
		{"top_scale": Vector2(1.1, 1.1)})
	add(list, &"shin", BOX, Vector3(0.088, 0.095, 0.04), Vector3(0.0, -0.012, -0.056), PAD, 0.0,
		{"top_scale": Vector2(0.9, 0.8)})
	# The boot: a tall shaft with a cuff, laces across its front, then the toe and a thick sole.
	var shaft := piece(&"shin", PRISM, Vector3(0.105, 0.2, 0.105), Vector3(0.0, -0.205, 0.0), BOOT, 0.0,
		{"top_scale": Vector2(1.05, 1.05), "shine": 0.2})
	list.append(shaft)
	add(list, &"shin", BAND, Vector3(0.114, 0.0, 0.114), Vector3(0.0, -0.11, 0.0), BOOT_DARK, 0.0,
		{"profile": PackedVector4Array([Vector4(-0.014, 1.0, 1.0, 0.0), Vector4(0.014, 1.0, 1.0, 0.0)])})
	for t: float in [0.2, 0.4, 0.6, 0.8]:
		OutfitDecals.on_prism(list, shaft, Vector2(-30.0, 30.0), t, t + 0.07, LACE, 0.1)
	add(list, &"foot", BOX, Vector3(0.098, 0.09, 0.2), Vector3(0.0, -0.025, -0.045), BOOT, 0.0,
		{"chamfer": 0.3, "top_scale": Vector2(0.85, 0.7), "top_shift": 0.02, "shine": 0.2})
	add(list, &"foot", BOX, Vector3(0.102, 0.022, 0.21), Vector3(0.0, -0.064, -0.045), SOLE)


# --- The skirt ----------------------------------------------------------------------------------

## One panel of the coat's skirt: the olive sheet, its camo patches and the stained, dusty hem.
func _skirt_panel(side: int, behind: bool) -> HumanoidPanel:
	var panel := HumanoidPanel.new()
	panel.side = side
	panel.behind = behind
	panel.length = SKIRT_LENGTH
	# The hinge sits halfway through the panel's depth, so its top edge stays under the belt.
	panel.hinge = Vector3(0.1, SKIRT_HINGE_Y, 0.064) if behind else Vector3(0.13, SKIRT_HINGE_Y, -0.046)
	panel.follow = 0.5 if behind else 0.6
	var pieces: Array[HumanoidPiece] = []
	var arc := Vector2(91.0, 179.0) if behind else Vector2(31.0, 89.0)
	pieces.append(piece(&"pelvis", SHELL, Vector3(SKIRT_HALF.x * 2.0, 0.0, SKIRT_HALF.y * 2.0), Vector3(0.0, SKIRT_HINGE_Y, 0.005),
		OLIVE, 0.0, {"sides": 12, "section_phase": 15.0, "arc": arc, "thickness": 0.012,
			"profile": PackedVector4Array([Vector4(0.03, 1.0, 1.0, 0.0), Vector4(-SKIRT_LENGTH, SKIRT_FLARE, SKIRT_FLARE, 0.012)])}))
	# The camo patches, one 30-degree face wide each: (face angle, from, to, colour), heights below the hinge.
	var patches: Array = _patches(side, behind)
	for patch: Array in patches:
		pieces.append(_ring_patch(float(patch[0]), float(patch[1]), float(patch[2]), patch[3]))
	# The stained hem and a ragged dusty band above it, on every face.
	pieces.append(_ring_patch_arc(arc, -SKIRT_LENGTH + HEM_BAND, -SKIRT_LENGTH, STAIN, 0.02))
	var dust: float = -SKIRT_LENGTH + HEM_BAND
	for face: float in (PackedFloat32Array([105.0, 165.0]) if behind else PackedFloat32Array([45.0])):
		pieces.append(_ring_patch(face, dust + 0.05, dust - 0.001, DUST))
	panel.pieces = pieces
	return panel


## The camo patches of one panel (the right and left ones differ, so the coat isn't a mirror image).
func _patches(side: int, behind: bool) -> Array:
	if behind and side > 0:
		return [[105.0, -0.02, -0.11, PATCH_GREEN], [105.0, -0.19, -0.28, PATCH_BROWN], [135.0, -0.07, -0.16, PATCH_TAN],
			[135.0, -0.24, -0.32, PATCH_GREEN], [165.0, -0.0, -0.08, PATCH_BROWN], [165.0, -0.15, -0.24, PATCH_GREEN],
			[165.0, -0.3, -0.38, PATCH_TAN]]
	if behind:
		return [[105.0, -0.06, -0.15, PATCH_BROWN], [105.0, -0.24, -0.33, PATCH_TAN], [135.0, -0.0, -0.09, PATCH_GREEN],
			[135.0, -0.14, -0.23, PATCH_BROWN], [165.0, -0.08, -0.17, PATCH_TAN], [165.0, -0.22, -0.31, PATCH_GREEN],
			[135.0, -0.3, -0.37, PATCH_BLACK]]
	if side > 0:
		return [[45.0, -0.04, -0.13, PATCH_GREEN], [75.0, -0.12, -0.22, PATCH_BROWN], [45.0, -0.2, -0.29, PATCH_TAN]]
	return [[75.0, -0.03, -0.12, PATCH_BROWN], [45.0, -0.1, -0.2, PATCH_GREEN], [75.0, -0.26, -0.34, PATCH_TAN]]


## A patch over one face of the skirt ring (its centre `face` degrees round from the front), `from` to `to`
## metres below the hinge, a little off the sheet's surface.
func _ring_patch(face: float, from: float, to: float, color: Color) -> HumanoidPiece:
	return _ring_patch_arc(Vector2(face - 1.0, face + 1.0), from, to, color, 0.025)


func _ring_patch_arc(arc: Vector2, from: float, to: float, color: Color, inflate: float) -> HumanoidPiece:
	var rings := PackedVector4Array()
	for h: float in [from, to]:
		var t: float = (0.03 - h) / (0.03 + SKIRT_LENGTH)
		var s: float = 1.0 + (SKIRT_FLARE - 1.0) * t + inflate
		rings.append(Vector4(h, s, s, 0.012 * t))
	return piece(&"pelvis", BAND, Vector3(SKIRT_HALF.x * 2.0, 0.0, SKIRT_HALF.y * 2.0), Vector3(0.0, SKIRT_HINGE_Y, 0.005),
		color, 0.0, {"sides": 12, "section_phase": 15.0, "arc": arc, "profile": rings})
