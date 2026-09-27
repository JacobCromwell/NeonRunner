extends RefCounted
## The Corporate zone's cyborg (GDD §9.2, "Zone variants"; brief docs/art/BRIEF_CYBORG_GANGSTER.md; the
## owner's sheet docs/art/reference/cyborg_viewing_devices.jpg, Variant 2): the "Wide-Aspect VR"
## Runner, a sleek corporate courier. The same unit as the base, never bigger than it: the same
## skeleton, poses and hitboxes.
## - The head: a wide VR headset whose visor is the screen, the face (its own screen_rect, and the
##   faces redrawn for its wide shape, cyborg_kit.gd's VISOR_FACES, the same expressions): a dark
##   housing with a rim round the visor and pods at its ends, strapped round a head in a dark mask;
##   the lower face is covered by the jacket's high collar (brief). Two cables run from the back of the
##   head down into a slim module on the back. The sheet's cyan visor glow is the face's cold white
##   here, and flatter than a CRT (a visor, not a tube).
## - The body: a sleek, dark bomber jacket (a ribbed waistband and cuffs, a zip, unlit pale piping
##   where the sheet has cyan trim, a few worn patches) with a chest harness; dark tactical trousers
##   with knee pads and a thigh strap; dark trainers with pale midsoles. Chrome hands (brief).
## - The weapon: a sleek chrome arm cannon on the right forearm, ending in the shared emitter ring and
##   charge orb (the red charge-up is every look's); in the other hand, an unlit tablet (dark glass,
##   not the sheet's cyan).
## Chrome is polished, unlit metal; nothing on it glows but the face, the charge-up and a host's
## purple.
## DESIGN-TBD (docs/questions/p3.md 4): the VR Runner's details read off the sheet, and its visor.

const BOX := HumanoidPiece.Shape.BOX
const PRISM := HumanoidPiece.Shape.PRISM
const LATHE := HumanoidPiece.Shape.LATHE
const BAND := HumanoidPiece.Shape.BAND
const CENTER := HumanoidPiece.Placement.CENTER
const MIRRORED := HumanoidPiece.Placement.MIRRORED
const RIGHT := HumanoidPiece.Placement.RIGHT
const LEFT := HumanoidPiece.Placement.LEFT

## The visor, the face (head segment space): the screen's centre and size (19 × 7 square LEDs,
## Kit.VISOR_GRID) and the housing round it.
const SCREEN_CENTER := Vector3(0.0, 0.15, -0.148)
const SCREEN_SIZE := Vector3(0.38, 0.14, 0.01)
const HOUSING_SIZE := Vector3(0.42, 0.176, 0.1)
const HOUSING_CENTER := Vector3(0.0, 0.15, -0.095)

## The cables from the back module up behind the neck into the back of the head, ending inside it
## within about 0.06 m of the head joint (chest joint space; the head joint is at y 0.48), so they stay
## plugged in however the head turns.
const HEAD_CABLES: Array = [
	[Vector3(-0.03, 0.37, 0.14), Vector3(-0.036, 0.45, 0.14), Vector3(-0.03, 0.52, 0.1), Vector3(-0.022, 0.53, 0.04)],
	[Vector3(0.03, 0.37, 0.14), Vector3(0.036, 0.45, 0.14), Vector3(0.03, 0.52, 0.1), Vector3(0.022, 0.53, 0.04)],
]

## The torso: a sleek section (half sizes, a 10-sided ring) through these rings (height in the chest
## joint's space, x scale, z scale, z shift), the bomber jacket's shape, inside the base's outline.
const TORSO_HALF := Vector2(0.124, 0.088)
const TORSO_RINGS: Array[Vector4] = [
	Vector4(-0.1, 0.94, 0.98, 0.0),
	Vector4(-0.06, 0.98, 1.02, 0.0),
	Vector4(0.14, 1.04, 1.06, 0.0),
	Vector4(0.29, 1.12, 1.06, -0.006),
	Vector4(0.365, 1.44, 0.96, -0.01),
	Vector4(0.415, 0.92, 0.74, -0.004),
]

## The jacket and trousers (near black), the pale unlit piping, worn patches, the mask and collar.
const JACKET := Color(0.1, 0.105, 0.115)
const JACKET_SHADE := Color(0.07, 0.072, 0.08)
const RIB := Color(0.16, 0.165, 0.17)
const PIPING := Color(0.52, 0.54, 0.56)
const WORN := Color(0.27, 0.25, 0.23)
const TROUSERS := Color(0.12, 0.125, 0.13)
const MASK := Color(0.08, 0.08, 0.085)
const HARNESS := Color(0.23, 0.24, 0.2)
## The headset and the gear: dark gunmetal, and polished chrome (unlit).
const HEADSET := Color(0.14, 0.145, 0.155)
const HEADSET_RIM := Color(0.26, 0.27, 0.285)
const CHROME := Color(0.66, 0.68, 0.71)
const CHROME_DARK := Color(0.44, 0.45, 0.48)
const CHROME_SHINE: float = 0.9
const GUNMETAL := CyborgSuit.GUNMETAL
const GLASS := Color(0.06, 0.065, 0.075)
const TRAINER := Color(0.16, 0.165, 0.17)
const MIDSOLE := Color(0.54, 0.55, 0.56)


static func pieces() -> Array[HumanoidPiece]:
	var list: Array[HumanoidPiece] = []
	_head(list)
	_torso(list)
	_arms(list)
	_cannon(list)
	_tablet(list)
	_legs(list)
	return list


## A host runner's veins: up the front of the high collar, and down the front of both sleeves, the
## left hand's back and the chrome cannon (the side the player sees).
static func veins() -> Array[HumanoidPiece]:
	var list: Array[HumanoidPiece] = []
	var w: float = 0.012
	for x: float in [-0.026, 0.0, 0.026]:
		CyborgSuit.vein(list, &"chest", Vector3(x, 0.4, -0.077), Vector3(x * 0.85, 0.5, -0.066), w, CENTER)
	for side: HumanoidPiece.Placement in [RIGHT, LEFT]:
		CyborgSuit.vein(list, &"upper_arm", Vector3(0.014, -0.04, -0.05), Vector3(0.01, -0.25, -0.05), w, side)
		CyborgSuit.vein(list, &"upper_arm", Vector3(0.012, -0.14, -0.05), Vector3(0.036, -0.2, -0.036), w, side)
	CyborgSuit.vein(list, &"forearm", Vector3(0.012, -0.02, -0.046), Vector3(0.01, -0.2, -0.044), w, LEFT)
	CyborgSuit.vein(list, &"forearm", Vector3(0.01, -0.25, -0.036), Vector3(0.01, -0.3, -0.036), w, LEFT)
	CyborgSuit.vein(list, &"forearm", Vector3(0.018, -0.04, -0.056), Vector3(0.016, -0.34, -0.052), w, RIGHT)
	return list


## The visor: its own rectangle (the face grid's square LEDs on it), a flat panel's even brightness
## rather than a tube's dark corners, a little less static; polished chrome.
static func material_params() -> Dictionary:
	var half := Vector2(SCREEN_SIZE.x, SCREEN_SIZE.y) * 0.5
	return {&"screen_rect": Vector4(SCREEN_CENTER.x - half.x, SCREEN_CENTER.y - half.y, SCREEN_CENTER.x + half.x,
		SCREEN_CENTER.y + half.y), &"vignette": 0.1, &"static_amount": 0.12, &"polish_metallic": 0.7}


## The masked head, the headset round it with the visor, its pods and straps.
static func _head(list: Array[HumanoidPiece]) -> void:
	CyborgSuit.add(list, &"head", LATHE, Vector3(0.17, 0.0, 0.2), Vector3(0.0, 0.0, 0.01), MASK, 0.0, {"sides": 8,
		"profile": PackedVector4Array([Vector4(-0.02, 0.5, 0.5, -0.01), Vector4(0.05, 0.82, 0.86, -0.012),
			Vector4(0.13, 1.0, 1.0, 0.0), Vector4(0.22, 0.93, 0.96, 0.006), Vector4(0.275, 0.52, 0.6, 0.008)])})
	var shine := {"shine": 0.5}
	CyborgSuit.add(list, &"head", BOX, HOUSING_SIZE, HOUSING_CENTER, HEADSET, 0.0, CyborgSuit.merged(shine, {"chamfer": 0.3,
		"top_scale": Vector2(0.97, 0.9)}))
	var s: Vector3 = SCREEN_SIZE
	var c: Vector3 = SCREEN_CENTER
	var rim_z: float = c.z - 0.004
	CyborgSuit.add(list, &"head", BOX, Vector3(HOUSING_SIZE.x, 0.018, 0.012), Vector3(0.0, c.y + s.y * 0.5 + 0.009, rim_z),
		HEADSET_RIM, 0.0, shine)
	CyborgSuit.add(list, &"head", BOX, Vector3(HOUSING_SIZE.x, 0.018, 0.012), Vector3(0.0, c.y - s.y * 0.5 - 0.009, rim_z),
		HEADSET_RIM, 0.0, shine)
	CyborgSuit.add(list, &"head", BOX, Vector3(0.02, s.y, 0.012), Vector3(s.x * 0.5 + 0.01, c.y, rim_z), HEADSET_RIM, 0.0,
		CyborgSuit.merged(shine, {"side": MIRRORED}))
	CyborgSuit.add(list, &"head", BOX, s, c, Color.BLACK, CyborgSuit.SCREEN)
	# The pods at the visor's ends, and the straps: round the back of the head and over its top.
	CyborgSuit.add(list, &"head", BOX, Vector3(0.03, 0.08, 0.07), Vector3(HOUSING_SIZE.x * 0.5 + 0.008, c.y, -0.085),
		HEADSET_RIM, 0.0, CyborgSuit.merged(shine, {"side": MIRRORED, "chamfer": 0.3}))
	CyborgSuit.add(list, &"head", BAND, Vector3(0.186, 0.0, 0.214), Vector3(0.0, 0.0, 0.012), HEADSET, 0.0, {"sides": 8,
		"arc": Vector2(60.0, 300.0), "profile": PackedVector4Array([Vector4(0.12, 1.0, 1.0, 0.0), Vector4(0.17, 1.0, 1.0, 0.0)])})
	CyborgSuit.bar(list, &"head", Vector3(0.082, 0.2, -0.03), Vector3(0.0, 0.284, 0.0), Vector2(0.03, 0.01), HEADSET,
		Vector3.UP)
	CyborgSuit.bar(list, &"head", Vector3(0.0, 0.284, 0.0), Vector3(-0.082, 0.2, -0.03), Vector2(0.03, 0.01), HEADSET,
		Vector3.UP)


## The bomber jacket: the torso with a ribbed waistband, a zip, pale piping either side of it, worn
## patches; a high collar up over the lower face; the chest harness and the slim module on the back
## with the cables into the head; the trousers' seat.
static func _torso(list: Array[HumanoidPiece]) -> void:
	CyborgSuit.add(list, &"chest", LATHE, Vector3(TORSO_HALF.x * 2.0, 0.0, TORSO_HALF.y * 2.0), Vector3.ZERO, JACKET, 0.0,
		{"sides": 10, "profile": PackedVector4Array(TORSO_RINGS)})
	CyborgSuit.add(list, &"chest", BAND, Vector3(TORSO_HALF.x * 2.0 + 0.01, 0.0, TORSO_HALF.y * 2.0 + 0.01), Vector3.ZERO,
		RIB, 0.0, {"sides": 10, "profile": PackedVector4Array([Vector4(-0.1, 0.94, 0.98, 0.0), Vector4(-0.065, 0.98, 1.02, 0.0)])})
	# The zip and the piping (unlit, where the sheet's trim glows cyan).
	var front: float = -TORSO_HALF.y * 1.06 * 0.951 - 0.0012
	CyborgSuit.patch(list, &"chest", Vector3(0.0, 0.14, front), Vector2(0.01, 0.4), JACKET_SHADE)
	for x: float in [-0.036, 0.036]:
		CyborgSuit.patch(list, &"chest", Vector3(x, 0.13, front + 0.0004), Vector2(0.006, 0.36), PIPING)
	CyborgSuit.patch(list, &"chest", Vector3(-0.07, 0.22, front + 0.004), Vector2(0.05, 0.04), WORN,
		CyborgSuit.facing(Vector3(-0.3, 0.0, -0.95)) + Vector3(0.0, 0.0, 12.0))
	CyborgSuit.patch(list, &"chest", Vector3(0.075, 0.03, front + 0.004), Vector2(0.04, 0.05), WORN,
		CyborgSuit.facing(Vector3(0.3, 0.0, -0.95)) + Vector3(0.0, 0.0, -8.0))
	# The high collar: a turtleneck up over the chin, inside the jacket's stand-up collar.
	CyborgSuit.add(list, &"chest", LATHE, Vector3(0.15, 0.0, 0.15), Vector3(0.0, 0.0, 0.004), MASK, 0.0, {"sides": 8,
		"profile": PackedVector4Array([Vector4(0.38, 1.0, 1.0, 0.0), Vector4(0.46, 0.9, 0.9, -0.006),
			Vector4(0.515, 0.78, 0.8, -0.01)])})
	CyborgSuit.add(list, &"chest", BAND, Vector3(0.18, 0.0, 0.17), Vector3(0.0, 0.0, 0.012), JACKET, 0.0, {"sides": 8,
		"arc": Vector2(35.0, 325.0), "profile": PackedVector4Array([Vector4(0.39, 1.0, 1.0, 0.0), Vector4(0.46, 0.95, 0.95, 0.0)])})
	# The harness: straps over the shoulders to a clasp on the chest, and the module on the back.
	for side: float in [-1.0, 1.0]:
		CyborgSuit.bar(list, &"chest", Vector3(side * 0.085, 0.34, 0.13), Vector3(side * 0.112, 0.425, 0.015),
			Vector2(0.03, 0.008), HARNESS, Vector3.UP)
		CyborgSuit.bar(list, &"chest", Vector3(side * 0.112, 0.425, 0.015), Vector3(side * 0.04, 0.2, -0.1),
			Vector2(0.03, 0.008), HARNESS, Vector3.FORWARD)
	CyborgSuit.add(list, &"chest", BOX, Vector3(0.05, 0.04, 0.014), Vector3(0.0, 0.2, -0.104), GUNMETAL, 0.0,
		{"shine": 0.5})
	CyborgSuit.add(list, &"chest", BOX, Vector3(0.13, 0.26, 0.07), Vector3(0.0, 0.23, 0.12), HEADSET, 0.0,
		{"chamfer": 0.3, "shine": 0.5})
	CyborgSuit.patch(list, &"chest", Vector3(0.0, 0.25, 0.1553), Vector2(0.004, 0.2), PIPING, CyborgSuit.facing(Vector3.BACK))
	for cable: Array in HEAD_CABLES:
		CyborgSuit.cable(list, cable, 0.02, CyborgSuit.CABLE)
	CyborgSuit.add(list, &"pelvis", BOX, Vector3(0.22, 0.15, 0.165), Vector3(0.0, -0.045, 0.005), TROUSERS, 0.0,
		{"chamfer": 0.3, "top_scale": Vector2(0.94, 0.92)})


## The sleeves (piping down their outer side, a ribbed cuff on the left), and the left chrome hand.
static func _arms(list: Array[HumanoidPiece]) -> void:
	CyborgSuit.add(list, &"upper_arm", PRISM, Vector3(0.1, 0.07, 0.096), Vector3(0.004, -0.02, 0.0), JACKET, 0.0,
		{"side": MIRRORED, "sides": 6, "top_scale": Vector2(0.72, 0.74)})
	CyborgSuit.add(list, &"upper_arm", PRISM, Vector3(0.09, 0.24, 0.09), Vector3(0.0, -0.15, 0.0), JACKET, 0.0,
		{"side": MIRRORED, "sides": 6, "top_scale": Vector2(1.1, 1.1)})
	CyborgSuit.patch(list, &"upper_arm", Vector3(0.0457, -0.14, 0.0), Vector2(0.006, 0.24), PIPING,
		CyborgSuit.facing(Vector3.RIGHT, Vector3.BACK), 1.0, MIRRORED)
	CyborgSuit.patch(list, &"upper_arm", Vector3(0.0, -0.1, 0.0393), Vector2(0.04, 0.05), WORN,
		CyborgSuit.facing(Vector3.BACK), 1.0, LEFT)
	CyborgSuit.add(list, &"forearm", PRISM, Vector3(0.082, 0.2, 0.082), Vector3(0.0, -0.1, 0.0), JACKET, 0.0,
		{"side": LEFT, "sides": 6, "top_scale": Vector2(1.06, 1.06)})
	CyborgSuit.add(list, &"forearm", PRISM, Vector3(0.078, 0.04, 0.078), Vector3(0.0, -0.215, 0.0), RIB, 0.0,
		{"side": LEFT, "sides": 6})
	var chrome := {"side": LEFT, "shine": CHROME_SHINE}
	CyborgSuit.add(list, &"forearm", PRISM, Vector3(0.034, 0.03, 0.038), Vector3(0.0, -0.245, 0.0), CHROME_DARK, 0.0,
		CyborgSuit.merged(chrome, {"sides": 6}))
	CyborgSuit.add(list, &"forearm", BOX, Vector3(0.028, 0.06, 0.058), Vector3(0.0, -0.285, -0.006), CHROME, 0.0, chrome)
	CyborgSuit.add(list, &"forearm", BOX, Vector3(0.024, 0.05, 0.05), Vector3(0.002, -0.338, -0.014), CHROME, 0.0,
		CyborgSuit.merged(chrome, {"top_scale": Vector2(1.0, 1.1), "rotation_degrees": Vector3(-14.0, 0.0, 0.0)}))
	CyborgSuit.add(list, &"forearm", BOX, Vector3(0.016, 0.044, 0.018), Vector3(-0.008, -0.29, -0.04), CHROME_DARK, 0.0,
		CyborgSuit.merged(chrome, {"rotation_degrees": Vector3(-24.0, 0.0, 0.0)}))


## The sleek chrome arm cannon: the right sleeve to the elbow's cuff, then the forearm is the cannon,
## a smooth chrome barrel tapering to a dark collar at the muzzle, where the shared emitter ring and
## charge orb sit (CyborgSuit.MUZZLE), with a seam and a vent line down it.
static func _cannon(list: Array[HumanoidPiece]) -> void:
	var chrome := {"side": RIGHT, "shine": CHROME_SHINE}
	CyborgSuit.add(list, &"forearm", PRISM, Vector3(0.086, 0.06, 0.086), Vector3(0.0, -0.02, 0.0), JACKET, 0.0,
		{"side": RIGHT, "sides": 6})
	CyborgSuit.add(list, &"forearm", LATHE, Vector3(0.11, 0.0, 0.11), Vector3.ZERO, CHROME, 0.0, CyborgSuit.merged(chrome, {
		"sides": 10, "profile": PackedVector4Array([Vector4(-0.04, 0.72, 0.72, 0.0), Vector4(-0.1, 1.0, 1.0, 0.0),
			Vector4(-0.28, 0.96, 0.96, 0.0), Vector4(-0.37, 0.8, 0.8, 0.0)])}))
	CyborgSuit.add(list, &"forearm", PRISM, Vector3(0.094, 0.03, 0.094), Vector3(0.0, -0.382, 0.0), GUNMETAL, 0.0,
		{"side": RIGHT, "sides": 10, "shine": 0.5})
	CyborgSuit.patch(list, &"forearm", Vector3(0.0, -0.2, -0.0551), Vector2(0.004, 0.2), CHROME_DARK, Vector3.ZERO, 1.0, RIGHT)
	CyborgSuit.patch(list, &"forearm", Vector3(0.0525, -0.19, 0.0), Vector2(0.012, 0.12), GUNMETAL,
		CyborgSuit.facing(Vector3.RIGHT, Vector3.BACK), 1.0, RIGHT)


## The tablet in the left hand: a thin gunmetal slab held by its edge, its screen dark glass (unlit).
## When the aiming pose raises the forearm, the tablet lies face up in front of the chest.
static func _tablet(list: Array[HumanoidPiece]) -> void:
	CyborgSuit.add(list, &"forearm", BOX, Vector3(0.11, 0.17, 0.012), Vector3(0.0, -0.33, -0.032), GUNMETAL, 0.0,
		{"side": LEFT, "chamfer": 0.3, "shine": 0.5})
	CyborgSuit.patch(list, &"forearm", Vector3(0.0, -0.335, -0.0385), Vector2(0.094, 0.145), GLASS, Vector3.ZERO, 1.0, LEFT)


## Dark tactical trousers (knee pads, a strap round the right thigh), and dark trainers with pale
## midsoles.
static func _legs(list: Array[HumanoidPiece]) -> void:
	CyborgSuit.add(list, &"thigh", PRISM, Vector3(0.122, 0.34, 0.124), Vector3(0.0, -0.16, 0.0), TROUSERS, 0.0,
		{"sides": 8, "top_scale": Vector2(1.1, 1.08)})
	CyborgSuit.add(list, &"thigh", BAND, Vector3(0.136, 0.0, 0.136), Vector3(0.0, -0.1, 0.0), HARNESS, 0.0, {"side": RIGHT,
		"sides": 8, "profile": PackedVector4Array([Vector4(-0.012, 1.0, 1.0, 0.0), Vector4(0.012, 1.0, 1.0, 0.0)])})
	CyborgSuit.add(list, &"thigh", BOX, Vector3(0.03, 0.08, 0.06), Vector3(0.07, -0.13, 0.0), JACKET_SHADE, 0.0,
		{"side": RIGHT})
	CyborgSuit.add(list, &"shin", BOX, Vector3(0.084, 0.09, 0.03), Vector3(0.0, -0.02, -0.06), RIB, 0.0,
		{"chamfer": 0.35, "shine": 0.3, "top_scale": Vector2(0.9, 0.8)})
	CyborgSuit.add(list, &"shin", PRISM, Vector3(0.114, 0.2, 0.114), Vector3(0.0, -0.09, 0.0), TROUSERS, 0.0,
		{"sides": 8, "top_scale": Vector2(0.98, 0.98)})
	CyborgSuit.add(list, &"shin", PRISM, Vector3(0.094, 0.07, 0.094), Vector3(0.0, -0.225, 0.0), TRAINER, 0.0, {"sides": 8})
	CyborgSuit.add(list, &"shin", BOX, Vector3(0.1, 0.06, 0.2), Vector3(0.0, -0.268, -0.042), TRAINER, 0.0,
		{"chamfer": 0.4, "top_scale": Vector2(0.88, 0.7), "top_shift": 0.02})
	CyborgSuit.add(list, &"shin", BOX, Vector3(0.106, 0.02, 0.21), Vector3(0.0, -0.29, -0.036), MIDSOLE, 0.0,
		{"chamfer": 0.4})
