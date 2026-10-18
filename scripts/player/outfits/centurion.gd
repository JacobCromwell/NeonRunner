extends PlayerOutfit
## The Centurion, the fourth cosmetic (GDD §8, "Cosmetics"; sold for 5,000 credits until the weekly seed that is to
## win it exists; brief docs/art/BRIEF_OUTFIT_CENTURION.md, after the owner's concept sheet
## docs/art/reference/outfit_centurion.webp): a gold-and-crimson Roman-style outfit on Razor Echo's rig and head (his
## face, scars, spiky hair and copper ocular implant stay his own). A long charcoal and crimson trench coat trimmed in
## gold (a high collar, crimson lapels, four stiff skirt panels hinged at the waist and, one a side, two panels of
## swinging leather strips, the pteruges, hanging from the sash over the hips), a sculpted gold cuirass with an emblem on the chest, lion-head
## gold pauldrons with layered scale plates, a crimson sash and a black belt with a gold buckle, a sleek gold cyber-arm
## on the left with crimson accents at its joints (it replaces Echo's plain gold one), gold bracers and fingerless
## gloves, black pants with gold knee plates and greaves, and gold-plated boots. On the back, large enough to read from
## the gameplay camera: the gold skull inside its laurel wreath across the charcoal coat, between the pauldrons.
##
## The gold is polished metal (HumanoidPiece.shine) and never emissive, so bloom can't wash the armour's shapes out;
## nothing on the Centurion glows (outfits are free of the colour rule, owner, October 18, 2026: the gold and crimson
## stay as drawn, close to the Golden Zone's and the cult's gold or not).
##
## Left out on purpose: the ceremonial katana and its sheath, the heavy pistol and the dagger at the hip (no outfit
## carries a weapon: nothing on the runner may look like a power-up).
##
## The armor power-up: this outfit already wears gold plates on the shoulders and chest, where Echo's steel ones go, so
## the Centurion refits the set (attachment_overrides) to be sure it reads at a glance: bright silver-blue plates (lighter
## than Echo's steel, which is legible against the gold but dark and thin beside it) standing proud of the pauldrons, over
## the cuirass and across the upper back, each with the pale glowing edge the base set has. The shards the armor bursts
## into are still Echo's steel colour. The other power-ups are Echo's sets, unchanged.
## DESIGN-TBD (docs/questions/m3.md): the skull and laurel, simplified from the sheet; the lion heads on the pauldrons;
## the cuirass's relief; how worn the coat is.

## Polished gold and its shade, crimson and its shade, the charcoal of the coat, black leather and pants.
const GOLD := Color(0.99, 0.79, 0.27)
const GOLD_DARK := Color(0.55, 0.38, 0.12)
const CRIMSON := Color(0.64, 0.06, 0.1)
const CRIMSON_DARK := Color(0.42, 0.035, 0.07)
const COAT := Color(0.17, 0.17, 0.19)
const LEATHER := Color(0.1, 0.08, 0.075)
const PANTS := Color(0.09, 0.09, 0.1)
const SKULL_EYE := Color(0.05, 0.04, 0.045)
## The armor power-up's plates on this outfit: a bright cool silver-blue, lighter than Echo's steel so it stands out from
## the gold and the charcoal (its edge glow is Echo's, PlayerSuit.ARMOR_EDGE).
const ARMOR_PLATE := Color(0.74, 0.82, 0.93)
## How polished the gold is (HumanoidPiece.shine), and the lesser shine of its darker parts.
const GOLD_SHINE: float = 0.75
const GOLD_DULL: float = 0.4

## The coat's back surface at chest height `y` (chest joint space): the upper torso leans in a little. What the
## emblem sits on.
const BACK_LEAN: float = 0.067

## The skirt, as Echo's: the waist ring the panels hang from (pelvis joint space), its size and flare.
const SKIRT_HINGE_Y: float = 0.03
const SKIRT_HALF := Vector2(0.152, 0.118)
const SKIRT_LENGTH: float = 0.46
const SKIRT_FLARE: float = 1.3

const GOLD_PIECE := {"shine": GOLD_SHINE}


func body_pieces() -> Array[HumanoidPiece]:
	var list: Array[HumanoidPiece] = []
	_belt(list)
	_torso(list)
	_cuirass(list)
	_emblem(list)
	_pauldrons(list)
	_right_arm(list)
	_left_arm(list)
	_legs(list)
	return list


func panels() -> Array[HumanoidPanel]:
	var out: Array[HumanoidPanel] = []
	for side: int in [1, -1]:
		out.append(_skirt_panel(side, true))
		out.append(_skirt_panel(side, false))
		out.append(_pteruges(side))
	return out


## The armor power-up refitted to the gold outfit (see the header): silver-blue plates over the gold pauldrons, the
## cuirass and the upper back, each with its pale glowing edge.
func attachment_overrides() -> Dictionary:
	var list: Array[HumanoidPiece] = []
	var plate := {"shine": 0.5}
	# A cap over each shoulder, standing proud of the pauldron, with a glowing rim along its outer edge.
	add(list, &"upper_arm", BOX, Vector3(0.17, 0.034, 0.185), Vector3(0.02, 0.066, 0.0), ARMOR_PLATE, 0.0,
		merged(plate, {"top_scale": Vector2(0.7, 0.8)}))
	add(list, &"upper_arm", BOX, Vector3(0.016, 0.014, 0.17), Vector3(0.099, 0.052, 0.0), PlayerSuit.ARMOR_EDGE, 0.6)
	# A plate over the cuirass, a glowing line along its top, and a yoke across the upper back.
	add(list, &"chest", BOX, Vector3(0.19, 0.14, 0.024), Vector3(0.0, 0.14, -0.14), ARMOR_PLATE, 0.0,
		merged(plate, {"top_scale": Vector2(1.08, 1.0)}))
	add(list, &"chest", BOX, Vector3(0.17, 0.012, 0.01), Vector3(0.0, 0.212, -0.153), PlayerSuit.ARMOR_EDGE, 0.6)
	add(list, &"chest", BOX, Vector3(0.3, 0.05, 0.026), Vector3(0.0, 0.25, 0.108), ARMOR_PLATE, 0.0, plate)
	add(list, &"chest", BOX, Vector3(0.28, 0.01, 0.01), Vector3(0.0, 0.278, 0.112), PlayerSuit.ARMOR_EDGE, 0.6)
	return {&"armor": list}


# --- Pelvis, torso ----------------------------------------------------------------------

## Black pants over the hips, the crimson sash, the black belt over it and the gold buckle.
func _belt(list: Array[HumanoidPiece]) -> void:
	add(list, &"pelvis", BOX, Vector3(0.245, 0.15, 0.175), Vector3(0.0, -0.045, 0.005), PANTS, 0.0,
		{"top_scale": Vector2(1.04, 1.04)})
	add(list, &"pelvis", LATHE, Vector3(0.33, 0.0, 0.255), Vector3(0.0, SKIRT_HINGE_Y, 0.005), CRIMSON, 0.0,
		{"sides": 8, "profile": PackedVector4Array([Vector4(-0.042, 1.0, 1.0, 0.0), Vector4(0.034, 1.0, 1.0, 0.0)])})
	add(list, &"pelvis", BAND, Vector3(0.338, 0.0, 0.263), Vector3(0.0, SKIRT_HINGE_Y - 0.01, 0.005), LEATHER, 0.0,
		{"sides": 8, "profile": PackedVector4Array([Vector4(-0.012, 1.0, 1.0, 0.0), Vector4(0.012, 1.0, 1.0, 0.0)])})
	add(list, &"pelvis", BOX, Vector3(0.052, 0.04, 0.014), Vector3(0.0, SKIRT_HINGE_Y - 0.01, -0.135), GOLD, 0.0, GOLD_PIECE)


## The coat's body in two tiers, the crimson lapels with their gold edges, the high collar and its gold rim.
func _torso(list: Array[HumanoidPiece]) -> void:
	add(list, &"chest", BOX, Vector3(0.28, 0.19, 0.2), Vector3(0.0, 0.02, 0.008), COAT, 0.0,
		{"chamfer": 0.4, "top_scale": Vector2(1.07, 1.0)})
	add(list, &"chest", BOX, Vector3(0.3, 0.15, 0.2), Vector3(0.0, 0.19, 0.008), COAT, 0.0,
		{"chamfer": 0.45, "top_scale": Vector2(0.97, 0.9)})
	add(list, &"chest", BOX, Vector3(0.055, 0.17, 0.014), Vector3(0.07, 0.19, -0.106), CRIMSON, 0.0,
		{"side": MIRRORED, "top_scale": Vector2(1.3, 1.0), "rotation_degrees": Vector3(0.0, 0.0, -12.0)})
	# The gold edge down the outside of each lapel.
	flat(list, &"chest", 0.007, 0.17, Vector3(0.1, 0.19, -0.1135), GOLD, 0.0, -12.0, true,
		{"side": MIRRORED, "shine": GOLD_SHINE})
	add(list, &"chest", SHELL, Vector3(0.2, 0.0, 0.18), Vector3(0.0, 0.245, 0.012), COAT, 0.0,
		{"sides": 6, "arc": Vector2(-150.0, 150.0), "thickness": 0.014,
			"profile": PackedVector4Array([Vector4(0.0, 1.0, 1.0, 0.0), Vector4(0.1, 1.12, 1.15, 0.012)])})
	add(list, &"chest", BAND, Vector3(0.226, 0.0, 0.207), Vector3(0.0, 0.245, 0.012), GOLD, 0.0,
		{"sides": 6, "arc": Vector2(-150.0, 150.0), "shine": GOLD_SHINE,
			"profile": PackedVector4Array([Vector4(0.092, 1.0, 1.0, 0.0), Vector4(0.104, 1.01, 1.01, 0.0)])})


## The sculpted gold cuirass in the open front: the chest plate over the abdomen plate, the muscles' lines and the
## emblem (a crimson diamond with a gold square).
func _cuirass(list: Array[HumanoidPiece]) -> void:
	add(list, &"chest", BOX, Vector3(0.17, 0.2, 0.05), Vector3(0.0, 0.115, -0.1), GOLD, 0.0,
		{"chamfer": 0.3, "top_scale": Vector2(1.12, 0.85), "shine": GOLD_SHINE})
	add(list, &"chest", BOX, Vector3(0.135, 0.095, 0.04), Vector3(0.0, -0.02, -0.098), GOLD, 0.0, GOLD_PIECE)
	for y: float in [0.0, -0.03, -0.055]:
		flat(list, &"chest", 0.12, 0.007, Vector3(0.0, y, -0.1195), GOLD_DARK, 0.0, 0.0, true)
	flat(list, &"chest", 0.007, 0.15, Vector3(0.0, 0.1, -0.1275), GOLD_DARK, 0.0, 0.0, true)
	flat(list, &"chest", 0.07, 0.007, Vector3(0.0, 0.065, -0.1275), GOLD_DARK, 0.0, 0.0, true)
	flat(list, &"chest", 0.05, 0.05, Vector3(0.0, 0.155, -0.1285), CRIMSON, 0.0, 45.0, true)
	flat(list, &"chest", 0.026, 0.026, Vector3(0.0, 0.155, -0.1295), GOLD, 0.0, 0.0, true, {"shine": GOLD_SHINE})


## The back: the gold skull inside its laurel wreath, across the charcoal coat between the pauldrons.
func _emblem(list: Array[HumanoidPiece]) -> void:
	var centre := Vector2(0.0, 0.115)
	# The wreath: a ring of leaves rising each side of the skull from the bottom, tilted along the ring.
	var radius: float = 0.098
	for k: int in 8:
		var theta: float = deg_to_rad(18.0 + 17.0 * k)
		for side: float in [-1.0, 1.0]:
			var p := Vector2(centre.x + side * sin(theta) * radius, centre.y - cos(theta) * radius)
			var roll: float = side * rad_to_deg(theta) + side * 55.0
			back_flat(list, 0.03, 0.014, p, GOLD, roll, GOLD_SHINE)
	# The skull: cranium, cheeks and jaw, the eye sockets, nose and teeth.
	back_flat(list, 0.074, 0.044, Vector2(0.0, 0.14), GOLD, 0.0, GOLD_SHINE)
	back_flat(list, 0.056, 0.03, Vector2(0.0, 0.108), GOLD, 0.0, GOLD_SHINE)
	back_flat(list, 0.04, 0.022, Vector2(0.0, 0.082), GOLD, 0.0, GOLD_SHINE)
	for x: float in [-0.017, 0.017]:
		back_flat(list, 0.02, 0.02, Vector2(x, 0.122), SKULL_EYE, 0.0, 0.0, 1)
	back_flat(list, 0.008, 0.014, Vector2(0.0, 0.1), SKULL_EYE, 0.0, 0.0, 1)
	for x: float in [-0.012, -0.004, 0.004, 0.012]:
		back_flat(list, 0.006, 0.014, Vector2(x, 0.078), SKULL_EYE, 0.0, 0.0, 1)
	# Crimson borders down the back of the coat's sides.
	for x: float in [-0.134, 0.134]:
		back_flat(list, 0.012, 0.2, Vector2(x, 0.03), CRIMSON, 0.0, 0.0)


# --- Arms -------------------------------------------------------------------------------

## The lion-head pauldrons, one on each shoulder (the left over the cyber-arm's shoulder): a gold dome, three layered
## scale plates hanging over the upper arm and the lion's head on the outer face.
func _pauldrons(list: Array[HumanoidPiece]) -> void:
	add(list, &"upper_arm", LATHE, Vector3(0.15, 0.0, 0.15), Vector3(0.014, 0.0, 0.0), GOLD, 0.0, {"side": MIRRORED,
		"sides": 6, "shine": GOLD_SHINE, "profile": PackedVector4Array([Vector4(-0.045, 1.0, 1.0, 0.0),
			Vector4(0.012, 0.96, 0.96, 0.0), Vector4(0.05, 0.5, 0.5, 0.0)])})
	for k: int in 3:
		add(list, &"upper_arm", BOX, Vector3(0.128 - 0.014 * k, 0.03, 0.126 - 0.012 * k),
			Vector3(0.016 + 0.004 * k, -0.04 - 0.036 * k, 0.0), GOLD if k % 2 == 0 else GOLD_DARK, 0.0,
			{"side": MIRRORED, "shine": GOLD_SHINE if k % 2 == 0 else GOLD_DULL, "top_scale": Vector2(0.9, 0.92),
				"rotation_degrees": Vector3(0.0, 0.0, -9.0)})
	# The lion's head on the outer face: a dark gold mane (a diamond) with a bright face. A flat quad turned to face
	# outward (+x, mirrored for the left arm), its face 3.5 mm out from `x`.
	for pair: Array in [[0.05, GOLD_DARK, 0.0], [0.028, GOLD, 0.004]]:
		add(list, &"upper_arm", BAND, Vector3(pair[0] * 1.41421, 0.0, 0.01), Vector3(0.087 + pair[2], 0.012, 0.0), pair[1], 0.0,
			{"side": MIRRORED, "sides": 4, "arc": Vector2(170.0, 190.0), "shine": GOLD_SHINE if pair[1] == GOLD else GOLD_DULL,
				"rotation_degrees": Vector3(0.0, 90.0, 45.0), "profile": PackedVector4Array([
					Vector4(-pair[0] * 0.5, 1.0, 1.0, 0.0), Vector4(pair[0] * 0.5, 1.0, 1.0, 0.0)])})


## The right arm: the crimson sleeve, a gold bracer with a crimson cuff and the fingerless glove with a gold knuckle plate.
func _right_arm(list: Array[HumanoidPiece]) -> void:
	add(list, &"upper_arm", PRISM, Vector3(0.1, 0.22, 0.095), Vector3(0.0, -0.095, 0.0), CRIMSON, 0.0,
		{"side": RIGHT, "top_scale": Vector2(1.15, 1.15)})
	add(list, &"forearm", PRISM, Vector3(0.085, 0.09, 0.08), Vector3(0.0, -0.045, 0.0), CRIMSON, 0.0,
		{"side": RIGHT, "top_scale": Vector2(1.1, 1.1)})
	add(list, &"forearm", PRISM, Vector3(0.094, 0.09, 0.09), Vector3(0.0, -0.128, 0.0), GOLD, 0.0,
		{"side": RIGHT, "shine": GOLD_SHINE, "top_scale": Vector2(1.06, 1.06)})
	add(list, &"forearm", PRISM, Vector3(0.1, 0.018, 0.096), Vector3(0.0, -0.088, 0.0), CRIMSON_DARK, 0.0, {"side": RIGHT})
	add(list, &"hand", BOX, Vector3(0.06, 0.066, 0.072), Vector3(0.0, -0.035, -0.004), LEATHER, 0.0, {"side": RIGHT})
	add(list, &"hand", BOX, Vector3(0.062, 0.014, 0.074), Vector3(0.0, -0.012, -0.004), GOLD, 0.0,
		{"side": RIGHT, "shine": GOLD_SHINE})
	add(list, &"hand", BOX, Vector3(0.054, 0.032, 0.056), Vector3(0.0, -0.082, -0.01), PlayerSuit.SKIN, 0.0, {"side": RIGHT})


## The sleek gold cyber-arm on the left, from the shoulder down (the pauldron is over its shoulder): the upper arm,
## the crimson elbow joint and accent rings, the forearm with its cable, a crimson wrist and the articulated hand.
## (Authored on the right, placed on the left.)
func _left_arm(list: Array[HumanoidPiece]) -> void:
	var gold := {"side": LEFT, "shine": GOLD_SHINE}
	add(list, &"upper_arm", PRISM, Vector3(0.076, 0.19, 0.072), Vector3(0.0, -0.1, 0.0), GOLD, 0.0,
		merged(gold, {"top_scale": Vector2(1.1, 1.1)}))
	add(list, &"upper_arm", BAND, Vector3(0.088, 0.0, 0.084), Vector3(0.0, -0.075, 0.0), CRIMSON, 0.0, {"side": LEFT,
		"profile": PackedVector4Array([Vector4(-0.008, 1.0, 1.0, 0.0), Vector4(0.008, 1.0, 1.0, 0.0)])})
	add(list, &"upper_arm", PRISM, Vector3(0.07, 0.05, 0.07), Vector3(0.0, -0.2, 0.0), CRIMSON_DARK, 0.0,
		{"side": LEFT, "sides": 4, "shine": GOLD_DULL, "rotation_degrees": Vector3(0.0, 0.0, 90.0)})
	pipe(list, &"upper_arm", Vector3(0.0, -0.03, 0.04), Vector3(0.0, -0.18, 0.038), 0.014, Vector3.BACK, GOLD_DARK, 0.0,
		LEFT).shine = GOLD_DULL
	add(list, &"forearm", PRISM, Vector3(0.07, 0.16, 0.066), Vector3(0.0, -0.085, 0.0), GOLD, 0.0,
		merged(gold, {"top_scale": Vector2(1.15, 1.12)}))
	add(list, &"forearm", BAND, Vector3(0.082, 0.0, 0.078), Vector3(0.0, -0.075, 0.0), CRIMSON, 0.0, {"side": LEFT,
		"profile": PackedVector4Array([Vector4(-0.007, 1.0, 1.0, 0.0), Vector4(0.007, 1.0, 1.0, 0.0)])})
	add(list, &"forearm", PRISM, Vector3(0.07, 0.02, 0.066), Vector3(0.0, -0.165, 0.0), CRIMSON_DARK, 0.0,
		{"side": LEFT, "shine": GOLD_DULL})
	add(list, &"hand", BOX, Vector3(0.062, 0.066, 0.074), Vector3(0.0, -0.035, -0.004), GOLD, 0.0,
		merged(gold, {"chamfer": 0.35}))
	for x: float in [-0.015, 0.015]:
		add(list, &"hand", BOX, Vector3(0.024, 0.05, 0.018), Vector3(x, -0.088, -0.012), GOLD_DARK, 0.0,
			{"side": LEFT, "shine": GOLD_DULL})


# --- Legs ------------------------------------------------------------------------------

## Black pants with a crimson strap on each thigh, gold knee plates and greaves, and gold-plated armoured boots.
func _legs(list: Array[HumanoidPiece]) -> void:
	add(list, &"thigh", PRISM, Vector3(0.115, 0.32, 0.115), Vector3(0.0, -0.145, 0.0), PANTS, 0.0,
		{"top_scale": Vector2(1.2, 1.2)})
	add(list, &"thigh", BAND, Vector3(0.144, 0.0, 0.144), Vector3(0.0, -0.075, 0.0), CRIMSON, 0.0,
		{"sides": 6, "profile": PackedVector4Array([Vector4(-0.011, 1.0, 1.0, 0.0), Vector4(0.011, 1.0, 1.0, 0.0)])})
	add(list, &"shin", PRISM, Vector3(0.095, 0.18, 0.095), Vector3(0.0, -0.08, 0.0), PANTS, 0.0,
		{"top_scale": Vector2(1.1, 1.1)})
	# The knee plate and the greave down the shin.
	add(list, &"shin", BOX, Vector3(0.088, 0.08, 0.04), Vector3(0.0, -0.008, -0.06), GOLD, 0.0,
		{"shine": GOLD_SHINE, "top_scale": Vector2(0.9, 0.8)})
	add(list, &"shin", BOX, Vector3(0.07, 0.13, 0.026), Vector3(0.0, -0.13, -0.058), GOLD, 0.0,
		{"shine": GOLD_SHINE, "top_scale": Vector2(0.85, 1.0)})
	# The boot: a gold shaft with its crimson strap, the gold-plated foot and its dark sole.
	add(list, &"shin", PRISM, Vector3(0.1, 0.15, 0.1), Vector3(0.0, -0.235, 0.0), GOLD, 0.0,
		{"shine": GOLD_SHINE, "top_scale": Vector2(1.05, 1.05)})
	add(list, &"shin", BAND, Vector3(0.108, 0.0, 0.108), Vector3(0.0, -0.2, 0.0), CRIMSON, 0.0,
		{"profile": PackedVector4Array([Vector4(-0.011, 1.0, 1.0, 0.0), Vector4(0.011, 1.0, 1.0, 0.0)])})
	add(list, &"foot", BOX, Vector3(0.098, 0.09, 0.2), Vector3(0.0, -0.025, -0.045), GOLD, 0.0,
		{"chamfer": 0.3, "top_scale": Vector2(0.85, 0.7), "top_shift": 0.02, "shine": GOLD_SHINE})
	add(list, &"foot", BOX, Vector3(0.102, 0.022, 0.21), Vector3(0.0, -0.064, -0.045), LEATHER)


# --- The coat's skirt and the pteruges ---------------------------------------------------

## One of the coat's four skirt panels, knee to mid-calf (as Echo's): charcoal behind the legs (split by the back vent,
## its two outer faces crimson, with a crimson band above the hem) and crimson at the open coat's front edges, all with a
## gold line along the hem.
func _skirt_panel(side: int, behind: bool) -> HumanoidPanel:
	var panel := HumanoidPanel.new()
	panel.side = side
	panel.behind = behind
	panel.length = SKIRT_LENGTH
	panel.hinge = Vector3(0.1, SKIRT_HINGE_Y, 0.064) if behind else Vector3(0.13, SKIRT_HINGE_Y, -0.046)
	panel.follow = 0.5 if behind else 0.6
	var pieces: Array[HumanoidPiece] = []
	var at := Vector3(0.0, SKIRT_HINGE_Y, 0.005)
	var arc := Vector2(91.0, 179.0) if behind else Vector2(31.0, 89.0)
	var hem: float = -SKIRT_LENGTH
	var size := Vector3(SKIRT_HALF.x * 2.0, 0.0, SKIRT_HALF.y * 2.0)
	pieces.append(piece(&"pelvis", SHELL, size, at, COAT if behind else CRIMSON, 0.0,
		{"sides": 12, "section_phase": 15.0, "arc": arc, "thickness": 0.012,
			"profile": PackedVector4Array([Vector4(0.03, 1.0, 1.0, 0.0), Vector4(hem, SKIRT_FLARE, SKIRT_FLARE, 0.012)])}))
	if behind:
		# The two outer faces of a back panel are crimson, so the charcoal runs down the middle of the back.
		pieces.append(_skirt_band(Vector2(91.0, 149.0), 0.0, SKIRT_LENGTH - 0.045, CRIMSON, 0.0))
		pieces.append(_skirt_band(arc, SKIRT_LENGTH - 0.085, SKIRT_LENGTH - 0.045, CRIMSON, 0.0))
	# The hem: a gold line along it.
	pieces.append(_skirt_band(arc, SKIRT_LENGTH - 0.045, SKIRT_LENGTH - 0.012, GOLD, GOLD_SHINE))
	panel.pieces = pieces
	return panel


## A band of the skirt's outside over the faces within `arc`, from `top` to `bottom` metres below the hinge, 3 mm proud
## of the sheet: a colour on the panel for two triangles a face.
func _skirt_band(arc: Vector2, top: float, bottom: float, color: Color, shine: float) -> HumanoidPiece:
	var rings := PackedVector4Array()
	for d: float in [top, bottom]:
		var t: float = d / SKIRT_LENGTH
		var scale: float = 1.0 + (SKIRT_FLARE - 1.0) * t + 0.02
		rings.append(Vector4(-d, scale, scale, 0.012 * t))
	return piece(&"pelvis", BAND, Vector3(SKIRT_HALF.x * 2.0, 0.0, SKIRT_HALF.y * 2.0), Vector3(0.0, SKIRT_HINGE_Y, 0.005),
		color, 0.0, {"sides": 12, "section_phase": 15.0, "arc": arc, "shine": shine, "profile": rings})


## The pteruges: leather strips with gold tips hanging from the sash at each hip, one stiff panel a side that swings a
## little on its own with the thigh.
func _pteruges(side: int) -> HumanoidPanel:
	var panel := HumanoidPanel.new()
	panel.side = side
	panel.behind = false
	panel.length = 0.17
	panel.hinge = Vector3(0.07, SKIRT_HINGE_Y - 0.01, -0.125)
	panel.follow = 0.45
	var pieces: Array[HumanoidPiece] = []
	for k: int in 2:
		var x: float = 0.045 + 0.055 * k
		var z: float = -0.133 + 0.008 * k
		var turn := Vector3(0.0, -10.0 * k, 0.0)
		pieces.append(piece(&"pelvis", BOX, Vector3(0.04, 0.15, 0.012), Vector3(x, SKIRT_HINGE_Y - 0.09, z), LEATHER, 0.0,
			{"top_scale": Vector2(0.9, 1.0), "rotation_degrees": turn}))
		# The gold tip: a flat quad on the strip's front.
		pieces.append(flat_piece(&"pelvis", 0.04, 0.034, Vector3(x, SKIRT_HINGE_Y - 0.146, z - 0.007), GOLD, 0.0, 0.0, true,
			{"shine": GOLD_SHINE, "rotation_degrees": turn}))
	panel.pieces = pieces
	return panel


# --- Builders -------------------------------------------------------------------------

## A flat one-sided quad (two triangles): `w` x `h` metres, centred on `at` (the segment's joint space) and turned
## `roll` degrees about its normal, facing back (+z) or, with `front`, forward (-z). The cheapest way to put a patch of
## colour (a line, a tag, a leaf) on a surface. `extra` sets any other HumanoidPiece property.
static func flat_piece(segment: StringName, w: float, h: float, at: Vector3, color: Color,
		glow: float = 0.0, roll: float = 0.0, front: bool = false, extra: Dictionary = {}) -> HumanoidPiece:
	# A square section's face sits 0.3536 of the section's depth from the centre: 0.01 deep puts it 3.5 mm out.
	var depth: float = 0.01
	var face: float = depth * 0.35355
	var options := {"sides": 4, "arc": Vector2(-10.0, 10.0) if front else Vector2(170.0, 190.0),
		"rotation_degrees": Vector3(0.0, 0.0, roll),
		"profile": PackedVector4Array([Vector4(-h * 0.5, 1.0, 1.0, 0.0), Vector4(h * 0.5, 1.0, 1.0, 0.0)])}
	options.merge(extra, true)
	return piece(segment, BAND, Vector3(w * 1.41421, 0.0, depth), at + Vector3(0.0, 0.0, face if front else -face),
		color, glow, options)


## `flat_piece`, added to `list`.
static func flat(list: Array[HumanoidPiece], segment: StringName, w: float, h: float, at: Vector3, color: Color,
		glow: float = 0.0, roll: float = 0.0, front: bool = false, extra: Dictionary = {}) -> HumanoidPiece:
	var made: HumanoidPiece = flat_piece(segment, w, h, at, color, glow, roll, front, extra)
	list.append(made)
	return made


## A flat on the coat's back (chest joint space) at (x, y) of `p`, 2 mm off the surface (`lift` more mm for a patch over
## another), leaning with the surface above the waist.
static func back_flat(list: Array[HumanoidPiece], w: float, h: float, p: Vector2, color: Color, roll: float = 0.0,
		shine: float = 0.0, lift: int = 0) -> HumanoidPiece:
	var lean: float = clampf(p.y - 0.115, 0.0, 0.15)
	var z: float = 0.108 - BACK_LEAN * lean + 0.002 + 0.001 * lift
	var tilt: float = rad_to_deg(-atan(BACK_LEAN)) if lean > 0.0 else 0.0
	return flat(list, &"chest", w, h, Vector3(p.x, p.y, z), color, 0.0, roll, false,
		{"shine": shine, "rotation_degrees": Vector3(tilt, 0.0, roll)})
