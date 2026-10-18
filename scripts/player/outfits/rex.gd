extends PlayerOutfit
## Rex, the first cosmetic (GDD §8, "Cosmetics"; 3,000 credits; brief docs/art/BRIEF_OUTFIT_REX.md, after the
## owner's concept sheet docs/art/reference/outfit_rex.webp): a magenta leather biker jacket, a dark tank top,
## a gunmetal and copper cybernetic left arm, a utility belt with pouches, dark cargo pants with knee straps
## and buckled combat boots trimmed in magenta, on Razor Echo's rig and head (his face, scars, spiky hair and
## copper ocular implant stay his own).
##
## Glows (free of the colour rule, owner, October 18, 2026: they stay as drawn): the jacket's circuit lines
## over the sleeve and shoulders glow pink, the spine line down the back cyan, the cyber-arm's shoulder joint
## orange. All are thin lines on unlit leather and metal, so bloom doesn't turn them into blobs, and they power
## down on death with the rest of the suit's glow (humanoid_body.gdshader's glow_boost).
##
## Left out on purpose: the rifle slung across the back (no outfit carries a weapon: nothing on the runner may
## look like a power-up) and the words on the back patches (too small to read: the patches are plain shapes).
## The thigh holsters are empty leather holsters with no grip in them.
##
## Seen from the gameplay camera (behind and above): the jacket's magenta with the cyan spine and the two patches,
## the pink lines over the shoulders and down the right sleeve, and on the left the gunmetal and copper arm with
## its orange joint, then the dark pants and the magenta-trimmed boots. The hand and the fingerless glove are
## Echo's own shapes, so the cinematics' hand poses (two raised fingers) still work.
## DESIGN-TBD (docs/questions/m1.md): the circuit patterns, simplified from the sheet, and how worn the leather is.

const JACKET := Color(0.74, 0.09, 0.5)
const JACKET_DARK := Color(0.58, 0.06, 0.4)
const TANK := Color(0.08, 0.08, 0.09)
## The glows, as drawn: pink circuit lines, the cyan spine, the orange shoulder joint.
const CIRCUIT := Color(1.0, 0.38, 0.82)
const SPINE := Color(0.3, 0.95, 1.0)
const JOINT := Color(1.0, 0.45, 0.08)
const CIRCUIT_GLOW: float = 0.38
const SPINE_GLOW: float = 0.39
const JOINT_GLOW: float = 0.39
const LEATHER_SHINE: float = 0.35

const GUNMETAL := Color(0.44, 0.45, 0.48)
const GUNMETAL_DARK := Color(0.21, 0.22, 0.24)
const COPPER := Color(0.8, 0.46, 0.22)
const STEEL := Color(0.62, 0.63, 0.66)
const METAL_SHINE: float = 0.6
const PANTS := Color(0.2, 0.2, 0.21)
const PANTS_DARK := Color(0.12, 0.12, 0.13)
const STRAP := Color(0.09, 0.08, 0.08)
const BOOT := Color(0.1, 0.1, 0.11)
const SOLE := Color(0.06, 0.06, 0.06)
const PATCH := Color(0.06, 0.06, 0.07)
const GLOVE := Color(0.12, 0.11, 0.11)

## The jacket's back and front surfaces (chest joint space), what the lines and patches sit on.
const BACK_Z: float = 0.108
const FRONT_Z: float = -0.092


func body_pieces() -> Array[HumanoidPiece]:
	var list: Array[HumanoidPiece] = []
	_belt(list)
	_jacket(list)
	_back(list)
	_right_arm(list)
	_cyber_arm(list)
	_legs(list)
	return list


## The cargo pants over the hips, the utility belt with its buckle and the pouches hanging from it.
func _belt(list: Array[HumanoidPiece]) -> void:
	add(list, &"pelvis", BOX, Vector3(0.245, 0.15, 0.175), Vector3(0.0, -0.045, 0.005), PANTS, 0.0,
		{"top_scale": Vector2(1.04, 1.04)})
	add(list, &"pelvis", LATHE, Vector3(0.32, 0.0, 0.245), Vector3(0.0, -0.01, 0.005), STRAP, 0.0,
		{"sides": 8, "profile": PackedVector4Array([Vector4(-0.035, 1.0, 1.0, 0.0), Vector4(0.035, 1.0, 1.0, 0.0)])})
	add(list, &"pelvis", BOX, Vector3(0.045, 0.034, 0.012), Vector3(0.0, -0.01, -0.127), STEEL, 0.0, {"shine": METAL_SHINE})
	# A pouch on each hip, and a pair on the small of the back (the view the player sees).
	add(list, &"pelvis", BOX, Vector3(0.05, 0.065, 0.06), Vector3(0.12, -0.06, -0.03), PANTS_DARK, 0.0, {"side": MIRRORED})
	add(list, &"pelvis", BOX, Vector3(0.07, 0.055, 0.04), Vector3(0.068, -0.045, 0.12), PANTS_DARK, 0.0, {"side": MIRRORED})


## The jacket: the body in three tiers (hem to waist, chest, shoulders), the dark tank top and its chain between
## the wide lapels, a collar, the belted waist and the asymmetric zip.
func _jacket(list: Array[HumanoidPiece]) -> void:
	add(list, &"chest", BOX, Vector3(0.3, 0.1, 0.2), Vector3(0.0, -0.03, 0.008), JACKET, 0.0,
		{"chamfer": 0.35, "top_scale": Vector2(0.94, 0.96), "shine": LEATHER_SHINE})
	add(list, &"chest", BOX, Vector3(0.282, 0.19, 0.2), Vector3(0.0, 0.115, 0.008), JACKET, 0.0,
		{"chamfer": 0.4, "top_scale": Vector2(1.1, 1.0), "shine": LEATHER_SHINE})
	add(list, &"chest", BOX, Vector3(0.31, 0.07, 0.2), Vector3(0.0, 0.245, 0.008), JACKET, 0.0,
		{"chamfer": 0.45, "top_scale": Vector2(0.9, 0.85), "shine": LEATHER_SHINE})
	# The tank top in the open front, between wide lapels turned back, with the chain over it.
	add(list, &"chest", BOX, Vector3(0.085, 0.16, 0.014), Vector3(0.0, 0.17, FRONT_Z - 0.003), TANK, 0.0,
		{"top_scale": Vector2(1.3, 1.0)})
	add(list, &"chest", BOX, Vector3(0.058, 0.17, 0.016), Vector3(0.07, 0.16, FRONT_Z - 0.006), JACKET_DARK, 0.0,
		{"side": MIRRORED, "top_scale": Vector2(1.45, 1.0), "rotation_degrees": Vector3(0.0, 0.0, -13.0),
			"shine": LEATHER_SHINE})
	add(list, &"chest", BAND, Vector3(0.075, 0.0, 0.07), Vector3(0.0, 0.2, -0.066), STEEL, 0.0, {"sides": 6,
		"arc": Vector2(-60.0, 60.0), "shine": METAL_SHINE,
		"profile": PackedVector4Array([Vector4(-0.005, 1.0, 1.0, 0.0), Vector4(0.005, 1.0, 1.0, 0.0)])})
	# The collar, standing round the neck.
	add(list, &"chest", SHELL, Vector3(0.2, 0.0, 0.18), Vector3(0.0, 0.262, 0.012), JACKET_DARK, 0.0,
		{"sides": 6, "arc": Vector2(-150.0, 150.0), "thickness": 0.014, "shine": LEATHER_SHINE,
			"profile": PackedVector4Array([Vector4(0.0, 1.0, 1.0, 0.0), Vector4(0.075, 1.1, 1.12, 0.012)])})
	# The belted waist: the strap, its buckle and the loose end.
	add(list, &"chest", BOX, Vector3(0.292, 0.026, 0.206), Vector3(0.0, -0.035, 0.008), JACKET_DARK, 0.0,
		{"chamfer": 0.35, "shine": LEATHER_SHINE})
	add(list, &"chest", BOX, Vector3(0.03, 0.026, 0.01), Vector3(0.0, -0.035, FRONT_Z - 0.012), STEEL, 0.0,
		{"shine": METAL_SHINE})
	# The zip, running up from the waist to the collar on a slant.
	pipe(list, &"chest", Vector3(-0.02, -0.01, FRONT_Z - 0.004), Vector3(0.075, 0.24, FRONT_Z - 0.006), 0.008,
		Vector3.FORWARD, STEEL)


## The back: the glowing cyan spine with its vertebrae, the pink circuit lines across the shoulders, and the
## two patches (plain shapes: the sheet's words are too small to read).
func _back(list: Array[HumanoidPiece]) -> void:
	var z := func(y: float) -> float: return BACK_Z + 0.004 if y < 0.21 else BACK_Z - 0.015 * (y - 0.21) / 0.07 + 0.004
	var at := func(x: float, y: float) -> Vector3: return Vector3(x, y, z.call(y))
	pipe(list, &"chest", at.call(0.0, 0.272), at.call(0.0, 0.215), 0.014, Vector3.BACK, SPINE, SPINE_GLOW)
	pipe(list, &"chest", at.call(0.0, 0.215), at.call(0.0, -0.05), 0.014, Vector3.BACK, SPINE, SPINE_GLOW)
	for y: float in [0.17, 0.115, 0.06]:
		pipe(list, &"chest", at.call(-0.03, y), at.call(0.03, y), 0.01, Vector3.BACK, SPINE, SPINE_GLOW)
	# The pink circuit across the shoulders: a line each side of the neck, turning down over the blade.
	for side: float in [-1.0, 1.0]:
		pipe(list, &"chest", at.call(side * 0.035, 0.238), at.call(side * 0.125, 0.238), 0.01, Vector3.BACK, CIRCUIT,
			CIRCUIT_GLOW)
		pipe(list, &"chest", at.call(side * 0.125, 0.238), at.call(side * 0.13, 0.17), 0.01, Vector3.BACK, CIRCUIT,
			CIRCUIT_GLOW)
	# The patches: a round one on the left shoulder blade (the runner's left), a small square lower on the right.
	add(list, &"chest", PRISM, Vector3(0.064, 0.008, 0.064), Vector3(-0.07, 0.155, BACK_Z + 0.002), PATCH, 0.0,
		{"sides": 8, "rotation_degrees": Vector3(90.0, 0.0, 0.0)})
	add(list, &"chest", BOX, Vector3(0.056, 0.034, 0.008), Vector3(0.068, 0.08, BACK_Z + 0.002), PATCH)


## The right arm: the jacket's sleeve to mid-forearm with its pink circuit, the rolled cuff, the bare forearm and
## the fingerless glove (Echo's own hand).
func _right_arm(list: Array[HumanoidPiece]) -> void:
	var sleeve := {"side": RIGHT, "shine": LEATHER_SHINE}
	add(list, &"upper_arm", PRISM, Vector3(0.1, 0.22, 0.095), Vector3(0.0, -0.095, 0.0), JACKET, 0.0,
		merged(sleeve, {"top_scale": Vector2(1.15, 1.15)}))
	add(list, &"upper_arm", PRISM, Vector3(0.115, 0.07, 0.125), Vector3(0.012, 0.012, 0.0), JACKET, 0.0,
		merged(sleeve, {"top_scale": Vector2(0.78, 0.82)}))
	# The pink circuit: down the back of the sleeve with two branches across it, and over the shoulder's top.
	pipe(list, &"upper_arm", Vector3(0.012, 0.03, 0.058), Vector3(0.014, -0.19, 0.051), 0.012, Vector3.BACK, CIRCUIT,
		CIRCUIT_GLOW, RIGHT)
	pipe(list, &"upper_arm", Vector3(0.035, 0.05, -0.05), Vector3(0.035, 0.05, 0.056), 0.012, Vector3.UP, CIRCUIT,
		CIRCUIT_GLOW, RIGHT)
	pipe(list, &"upper_arm", Vector3(-0.012, -0.065, 0.054), Vector3(0.05, -0.065, 0.054), 0.01, Vector3.BACK, CIRCUIT,
		CIRCUIT_GLOW, RIGHT)
	pipe(list, &"upper_arm", Vector3(-0.012, -0.125, 0.052), Vector3(0.05, -0.125, 0.052), 0.01, Vector3.BACK, CIRCUIT,
		CIRCUIT_GLOW, RIGHT)
	add(list, &"forearm", PRISM, Vector3(0.085, 0.1, 0.08), Vector3(0.0, -0.05, 0.0), JACKET, 0.0,
		merged(sleeve, {"top_scale": Vector2(1.1, 1.1)}))
	add(list, &"forearm", PRISM, Vector3(0.1, 0.03, 0.095), Vector3(0.0, -0.108, 0.0), JACKET_DARK, 0.0, sleeve)
	add(list, &"forearm", PRISM, Vector3(0.064, 0.075, 0.06), Vector3(0.0, -0.14, 0.0), PlayerSuit.SKIN, 0.0, {"side": RIGHT})
	add(list, &"hand", BOX, Vector3(0.06, 0.066, 0.072), Vector3(0.0, -0.035, -0.004), GLOVE, 0.0,
		{"side": RIGHT, "chamfer": 0.35})
	add(list, &"hand", BOX, Vector3(0.054, 0.032, 0.056), Vector3(0.0, -0.082, -0.01), PlayerSuit.SKIN, 0.0, {"side": RIGHT})


## The cybernetic left arm from the shoulder down: a gunmetal dome with the glowing orange joint, plated upper
## arm and forearm with exposed copper pistons, and an articulated hand. (Authored on the right, placed on the
## left.)
func _cyber_arm(list: Array[HumanoidPiece]) -> void:
	var metal := {"side": LEFT, "shine": METAL_SHINE}
	add(list, &"upper_arm", LATHE, Vector3(0.13, 0.0, 0.13), Vector3(0.012, 0.0, 0.0), GUNMETAL, 0.0,
		merged(metal, {"sides": 6, "profile": PackedVector4Array([Vector4(-0.045, 1.0, 1.0, 0.0),
			Vector4(0.012, 0.96, 0.96, 0.0), Vector4(0.05, 0.55, 0.55, 0.0)])}))
	add(list, &"upper_arm", PRISM, Vector3(0.062, 0.014, 0.062), Vector3(0.078, -0.005, 0.0), GUNMETAL_DARK, 0.0,
		{"side": LEFT, "sides": 6, "rotation_degrees": Vector3(0.0, 0.0, 90.0)})
	add(list, &"upper_arm", PRISM, Vector3(0.042, 0.014, 0.042), Vector3(0.086, -0.005, 0.0), JOINT, JOINT_GLOW,
		{"side": LEFT, "sides": 6, "rotation_degrees": Vector3(0.0, 0.0, 90.0)})
	add(list, &"upper_arm", PRISM, Vector3(0.076, 0.19, 0.072), Vector3(0.0, -0.1, 0.0), GUNMETAL, 0.0,
		merged(metal, {"top_scale": Vector2(1.1, 1.1)}))
	add(list, &"upper_arm", BAND, Vector3(0.088, 0.0, 0.084), Vector3(0.0, -0.075, 0.0), GUNMETAL_DARK, 0.0, {"side": LEFT,
		"profile": PackedVector4Array([Vector4(-0.008, 1.0, 1.0, 0.0), Vector4(0.008, 1.0, 1.0, 0.0)])})
	# The exposed copper pistons, one down the front of the arm and one down the back.
	pipe(list, &"upper_arm", Vector3(0.0, -0.03, -0.04), Vector3(0.0, -0.18, -0.038), 0.014, Vector3.FORWARD, COPPER,
		0.0, LEFT).shine = 0.7
	pipe(list, &"upper_arm", Vector3(0.02, -0.03, 0.04), Vector3(0.02, -0.18, 0.038), 0.014, Vector3.BACK, COPPER, 0.0,
		LEFT).shine = 0.7
	add(list, &"upper_arm", PRISM, Vector3(0.07, 0.05, 0.07), Vector3(0.0, -0.2, 0.0), GUNMETAL_DARK, 0.0,
		{"side": LEFT, "shine": 0.4, "rotation_degrees": Vector3(0.0, 0.0, 90.0)})
	add(list, &"forearm", PRISM, Vector3(0.07, 0.16, 0.066), Vector3(0.0, -0.085, 0.0), GUNMETAL, 0.0,
		merged(metal, {"top_scale": Vector2(1.15, 1.12)}))
	pipe(list, &"forearm", Vector3(-0.022, -0.02, -0.03), Vector3(-0.02, -0.14, -0.028), 0.012, Vector3.FORWARD, COPPER,
		0.0, LEFT).shine = 0.7
	pipe(list, &"forearm", Vector3(0.022, -0.02, 0.03), Vector3(0.02, -0.14, 0.028), 0.012, Vector3.BACK, COPPER,
		0.0, LEFT).shine = 0.7
	add(list, &"forearm", PRISM, Vector3(0.07, 0.02, 0.066), Vector3(0.0, -0.165, 0.0), GUNMETAL_DARK, 0.0,
		{"side": LEFT, "shine": 0.4})
	add(list, &"hand", BOX, Vector3(0.062, 0.066, 0.074), Vector3(0.0, -0.035, -0.004), GUNMETAL, 0.0,
		merged(metal, {"chamfer": 0.35}))
	for x: float in [-0.021, 0.0, 0.021]:
		add(list, &"hand", BOX, Vector3(0.016, 0.05, 0.018), Vector3(x, -0.088, -0.012), COPPER, 0.0,
			{"side": LEFT, "shine": 0.7})


## Dark worn cargo pants with a pocket and an empty holster on each thigh and straps at the knees, and buckled
## combat boots trimmed in magenta.
func _legs(list: Array[HumanoidPiece]) -> void:
	add(list, &"thigh", PRISM, Vector3(0.115, 0.32, 0.115), Vector3(0.0, -0.145, 0.0), PANTS, 0.0,
		{"top_scale": Vector2(1.2, 1.2)})
	add(list, &"thigh", BOX, Vector3(0.032, 0.09, 0.066), Vector3(0.064, -0.19, 0.0), PANTS_DARK)
	add(list, &"thigh", BOX, Vector3(0.03, 0.12, 0.05), Vector3(0.068, -0.075, -0.015), STRAP, 0.0, {"shine": 0.2})
	add(list, &"shin", PRISM, Vector3(0.095, 0.18, 0.095), Vector3(0.0, -0.08, 0.0), PANTS, 0.0,
		{"top_scale": Vector2(1.1, 1.1)})
	add(list, &"shin", BAND, Vector3(0.108, 0.0, 0.108), Vector3(0.0, -0.045, 0.0), STRAP, 0.0,
		{"profile": PackedVector4Array([Vector4(-0.012, 1.0, 1.0, 0.0), Vector4(0.012, 1.0, 1.0, 0.0)])})
	add(list, &"shin", BOX, Vector3(0.012, 0.026, 0.026), Vector3(0.055, -0.045, -0.02), STEEL, 0.0, {"shine": METAL_SHINE})
	# The boot: a black shaft with its magenta trim and a buckled strap, the toe and the sole.
	add(list, &"shin", PRISM, Vector3(0.1, 0.15, 0.1), Vector3(0.0, -0.235, 0.0), BOOT, 0.0,
		{"top_scale": Vector2(1.05, 1.05), "shine": 0.25})
	add(list, &"shin", BAND, Vector3(0.108, 0.0, 0.108), Vector3(0.0, -0.17, 0.0), JACKET, 0.0,
		{"profile": PackedVector4Array([Vector4(-0.01, 1.0, 1.0, 0.0), Vector4(0.01, 1.0, 1.0, 0.0)])})
	add(list, &"shin", BOX, Vector3(0.012, 0.022, 0.024), Vector3(0.056, -0.215, -0.018), STEEL, 0.0, {"shine": METAL_SHINE})
	add(list, &"foot", BOX, Vector3(0.098, 0.09, 0.2), Vector3(0.0, -0.025, -0.045), BOOT, 0.0,
		{"chamfer": 0.3, "top_scale": Vector2(0.85, 0.7), "top_shift": 0.02, "shine": 0.25})
	add(list, &"foot", BOX, Vector3(0.102, 0.022, 0.21), Vector3(0.0, -0.064, -0.045), SOLE)
