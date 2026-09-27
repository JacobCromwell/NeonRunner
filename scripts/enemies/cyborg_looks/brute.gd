extends RefCounted
## Gangland's cyborg (GDD §9.2, "Zone variants"; brief docs/art/BRIEF_CYBORG_GANGSTER.md; the owner's
## sheet docs/art/reference/cyborg_viewing_devices.jpg, Variant 3): the "Broadcast Brute" Enforcer, a
## gang's heavy, in the zone's browns and tans. The same unit as the base, never bigger than it: the
## same skeleton, poses and hitboxes, and the same TV screen (the face in the same place).
## - The head: the base's TV in a heavy, dark steel casing inside a cage of dull brass bars, two small
##   side monitors bolted to the cage (the sheet's orange X screens: here a dim X in the face's cold
##   white over faint static, well below the face's brightness, cyborg_body.gdshader's glow 50), and a
##   short antenna raked back off the tube, which moves with the head.
## - The body: a brown work jumpsuit (a sturdy torso, a turned-up collar, a belt, baggy legs with
##   cargo pockets) under heavy, scavenged armour of dull, scuffed brass: a chest plate and a belly
##   plate with rivets, pauldrons on both shoulders, knee pads. Both arms are heavy steel prosthetics
##   (the sheet's) ending in big fists. Heavy work boots with steel toe caps. A radio pack on the back
##   with the cables up into the TV.
## - The weapon: the sheet's pipe becomes a crude pipe gun held in the right fist, its barrel running
##   out along the arm to the shared emitter ring and charge orb at the muzzle (the red charge-up is
##   every look's), with a valve, a gas canister and tape.
## Brass here is dull, scuffed armour, never polished, never glowing (brief: gold and brass only as
## unlit ornament; nothing glows copper).
## DESIGN-TBD (docs/questions/p3.md 1): the Brute's details read off the sheet.

const BOX := HumanoidPiece.Shape.BOX
const PRISM := HumanoidPiece.Shape.PRISM
const LATHE := HumanoidPiece.Shape.LATHE
const BAND := HumanoidPiece.Shape.BAND
const MIRRORED := HumanoidPiece.Placement.MIRRORED
const RIGHT := HumanoidPiece.Placement.RIGHT
const LEFT := HumanoidPiece.Placement.LEFT

## The side monitors' screens (head segment space): centre (|x|, y) and half size, for the shader's
## glass_rect.
const MONITOR_CENTER := Vector3(0.268, 0.19, -0.1)
const MONITOR_SIZE := Vector3(0.07, 0.07, 0.07)
const MONITOR_SCREEN := Vector2(0.05, 0.044)

## The torso: a sturdier section than the base's gaunt one (half sizes, a 10-sided ring) through these
## rings (height in the chest joint's space, x scale, z scale, z shift), inside the base's outline.
const TORSO_HALF := Vector2(0.124, 0.088)
const TORSO_RINGS: Array[Vector4] = [
	Vector4(-0.1, 1.0, 1.0, 0.0),
	Vector4(0.12, 1.02, 1.03, 0.0),
	Vector4(0.29, 1.1, 1.04, -0.006),
	Vector4(0.365, 1.45, 0.96, -0.01),
	Vector4(0.415, 0.92, 0.74, -0.004),
]

## The jumpsuit (brown work cloth), leather, and the boots.
const SUIT := Color(0.38, 0.31, 0.22)
const SUIT_SHADE := Color(0.3, 0.245, 0.175)
const SUIT_WORN := Color(0.45, 0.39, 0.3)
const LEATHER := Color(0.22, 0.16, 0.11)
const BOOT := Color(0.22, 0.17, 0.13)
## The armour: dull, scuffed brass (unlit ornament), darker at its edges and rivets.
const BRASS := Color(0.5, 0.41, 0.26)
const BRASS_DARK := Color(0.34, 0.28, 0.18)
const BRASS_SHINE: float = 0.4
## The steel: the prosthetic arms, the pipe gun, the toe caps; the casing's dark, heavy steel.
const STEEL := CyborgSuit.STEEL
const STEEL_DARK := Color(0.29, 0.29, 0.29)
const GUNMETAL := CyborgSuit.GUNMETAL
const RUST := CyborgSuit.RUST
const CASING := Color(0.3, 0.31, 0.28)
const CASING_DARK := Color(0.22, 0.23, 0.21)
const PACK := Color(0.33, 0.34, 0.29)
const RUBBER := CyborgSuit.RUBBER
const TAPE := Color(0.24, 0.23, 0.2)
const METAL_SHINE: float = CyborgSuit.METAL_SHINE


static func pieces() -> Array[HumanoidPiece]:
	var list: Array[HumanoidPiece] = []
	_head(list)
	_torso(list)
	_armour(list)
	_backpack(list)
	_arms(list)
	_pipe_gun(list)
	_legs(list)
	return list


## A host Brute's veins: up the jumpsuit's chest above the plate, over the collar onto the neck, and
## down the front of both steel arms (the side the player sees).
static func veins() -> Array[HumanoidPiece]:
	var list: Array[HumanoidPiece] = []
	var w: float = 0.012
	for path: Array in [[Vector3(0.03, 0.352, -0.097), Vector3(0.026, 0.41, -0.08), Vector3(0.02, 0.47, -0.047)],
			[Vector3(-0.034, 0.355, -0.097), Vector3(-0.03, 0.41, -0.08), Vector3(-0.018, 0.47, -0.047)]]:
		for k: int in path.size() - 1:
			CyborgSuit.vein(list, &"chest", path[k], path[k + 1], w, HumanoidPiece.Placement.CENTER)
	for side: HumanoidPiece.Placement in [RIGHT, LEFT]:
		CyborgSuit.vein(list, &"upper_arm", Vector3(0.018, -0.1, -0.048), Vector3(0.012, -0.235, -0.048), w, side)
		CyborgSuit.vein(list, &"upper_arm", Vector3(0.012, -0.15, -0.048), Vector3(0.03, -0.2, -0.04), w, side)
		CyborgSuit.vein(list, &"forearm", Vector3(0.016, -0.03, -0.064), Vector3(0.016, -0.2, -0.064), w, side)
		CyborgSuit.vein(list, &"forearm", Vector3(0.016, -0.1, -0.064), Vector3(0.036, -0.16, -0.052), w, side)
	return list


## The side monitors (glass), and dull brass with a little metal to it.
static func material_params() -> Dictionary:
	return {&"glass_rect": Vector4(MONITOR_CENTER.x, MONITOR_CENTER.y, MONITOR_SCREEN.x * 0.5, MONITOR_SCREEN.y * 0.5),
		&"glass_energy": 0.55, &"polish_metallic": 0.3}


## The base's TV (the screen and its face in the same place) in a heavy, dark steel casing, caged in
## dull brass, with the two side monitors and the raked antenna.
static func _head(list: Array[HumanoidPiece]) -> void:
	var tv: Vector3 = CyborgSuit.TV_SIZE
	var at: Vector3 = CyborgSuit.TV_CENTER
	var s: Vector3 = CyborgSuit.SCREEN_SIZE
	var c: Vector3 = CyborgSuit.SCREEN_CENTER
	var front: float = at.z - tv.z * 0.5
	var bezel_z: float = front - 0.007
	var top: float = at.y + tv.y * 0.5
	var bottom: float = at.y - tv.y * 0.5
	CyborgSuit.add(list, &"head", BOX, tv, at, CASING, 0.0, {"chamfer": 0.12, "shine": METAL_SHINE})
	CyborgSuit.add(list, &"head", BOX, Vector3(0.34, 0.15, 0.25), Vector3(0.0, 0.14, 0.055), CASING_DARK, 0.0,
		{"rotation_degrees": Vector3(90.0, 0.0, 0.0), "top_scale": Vector2(0.72, 0.7)})
	CyborgSuit.add(list, &"head", BOX, Vector3(0.21, 0.15, 0.022), Vector3(0.0, 0.14, 0.135), GUNMETAL)
	# A thick steel bezel round the recessed screen.
	CyborgSuit.add(list, &"head", BOX, Vector3(tv.x, 0.03, 0.02), Vector3(0.0, c.y + s.y * 0.5 + 0.015, bezel_z), STEEL_DARK)
	CyborgSuit.add(list, &"head", BOX, Vector3(tv.x, 0.052, 0.02), Vector3(0.0, c.y - s.y * 0.5 - 0.026, bezel_z), STEEL_DARK)
	CyborgSuit.add(list, &"head", BOX, Vector3(0.035, s.y + 0.01, 0.02), Vector3(c.x + s.x * 0.5 + 0.0175, c.y, bezel_z),
		STEEL_DARK, 0.0, {"side": MIRRORED})
	CyborgSuit.add(list, &"head", BOX, s, c, Color.BLACK, CyborgSuit.SCREEN)
	# Bolts on the bezel's chin.
	for x: float in [-0.15, 0.15]:
		CyborgSuit.patch(list, &"head", Vector3(x, c.y - s.y * 0.5 - 0.026, bezel_z - 0.0105), Vector2(0.016, 0.016), BRASS_DARK)
	# The cage: a frame of brass bars round the front (clear of the screen), bars running back over the
	# top and along the bottom corners, and a crossbar over the back of the box.
	var bar := Vector2(0.018, 0.018)
	var cz: float = front - 0.022
	var cx: float = tv.x * 0.5 + 0.02
	var cy_top: float = top + 0.018
	var cy_bottom: float = bottom - 0.014
	var brass := {"shine": BRASS_SHINE}
	CyborgSuit.add(list, &"head", BOX, Vector3(cx * 2.0 + bar.x, bar.y, bar.x), Vector3(0.0, cy_top, cz), BRASS, 0.0, brass)
	CyborgSuit.add(list, &"head", BOX, Vector3(cx * 2.0 + bar.x, bar.y, bar.x), Vector3(0.0, cy_bottom, cz), BRASS, 0.0, brass)
	CyborgSuit.add(list, &"head", BOX, Vector3(bar.x, cy_top - cy_bottom, bar.x), Vector3(cx, (cy_top + cy_bottom) * 0.5, cz),
		BRASS, 0.0, CyborgSuit.merged(brass, {"side": MIRRORED}))
	var back_z: float = at.z + tv.z * 0.5 + 0.01
	for y: float in [cy_top, cy_bottom]:
		CyborgSuit.add(list, &"head", BOX, Vector3(bar.x, bar.y, back_z - cz), Vector3(cx, y, (cz + back_z) * 0.5), BRASS_DARK,
			0.0, CyborgSuit.merged(brass, {"side": MIRRORED}))
	CyborgSuit.add(list, &"head", BOX, Vector3(cx * 2.0 + bar.x, bar.y, bar.x), Vector3(0.0, cy_top, back_z), BRASS_DARK, 0.0, brass)
	CyborgSuit.add(list, &"head", BOX, Vector3(bar.x, bar.y, back_z - cz), Vector3(0.0, cy_top, (cz + back_z) * 0.5), BRASS, 0.0, brass)
	# The side monitors, bolted to the cage and turned a little outward, each with its dim glass.
	var m: Vector3 = MONITOR_CENTER
	var turned := {"side": MIRRORED, "rotation_degrees": Vector3(0.0, -10.0, 0.0)}
	CyborgSuit.add(list, &"head", BOX, Vector3(0.03, 0.035, 0.035), Vector3(cx + 0.02, m.y, m.z), GUNMETAL, 0.0, {"side": MIRRORED})
	CyborgSuit.add(list, &"head", BOX, MONITOR_SIZE, m, CASING, 0.0, CyborgSuit.merged(turned, {"chamfer": 0.15}))
	CyborgSuit.add(list, &"head", BOX, Vector3(MONITOR_SCREEN.x, MONITOR_SCREEN.y, 0.006),
		Vector3(m.x, m.y, m.z - MONITOR_SIZE.z * 0.5 - 0.001), Color.BLACK, CyborgSuit.GLASS, turned)
	# The antenna, raked back off the tube's top (it turns with the head): a mast and two crossbars.
	var foot := Vector3(0.085, 0.235, 0.1)
	var tip := Vector3(0.13, 0.33, 0.25)
	CyborgSuit.add(list, &"head", BOX, Vector3(0.04, 0.02, 0.04), foot, GUNMETAL)
	CyborgSuit.pipe(list, &"head", foot, tip, 0.012, STEEL, 4)
	for k: int in 2:
		var p: Vector3 = foot.lerp(tip, 0.72 + 0.2 * k)
		var half: float = 0.045 - 0.012 * k
		CyborgSuit.pipe(list, &"head", p - Vector3(half, 0.0, 0.0), p + Vector3(half, 0.0, 0.0), 0.008, STEEL, 4)


## The jumpsuit's torso: a sturdy section, a zip down the front, a turned-up collar round a thick
## ribbed neck, and a belt with a buckle.
static func _torso(list: Array[HumanoidPiece]) -> void:
	CyborgSuit.add(list, &"chest", LATHE, Vector3(TORSO_HALF.x * 2.0, 0.0, TORSO_HALF.y * 2.0), Vector3.ZERO, SUIT, 0.0,
		{"sides": 10, "profile": PackedVector4Array(TORSO_RINGS)})
	CyborgSuit.patch(list, &"chest", Vector3(0.0, 0.03, -0.0845), Vector2(0.012, 0.14), SUIT_SHADE)
	CyborgSuit.add(list, &"chest", PRISM, Vector3(0.08, 0.12, 0.08), Vector3(0.0, 0.45, 0.0), RUBBER, 0.0, {"sides": 6})
	CyborgSuit.add(list, &"chest", PRISM, Vector3(0.094, 0.018, 0.094), Vector3(0.0, 0.46, 0.0), CyborgSuit.RUBBER_RIB, 0.0,
		{"sides": 6})
	CyborgSuit.add(list, &"chest", LATHE, Vector3(0.17, 0.0, 0.15), Vector3(0.0, 0.0, 0.01), SUIT_SHADE, 0.0, {"sides": 8,
		"profile": PackedVector4Array([Vector4(0.38, 0.96, 0.96, 0.0), Vector4(0.415, 1.02, 1.04, 0.004),
			Vector4(0.45, 0.86, 0.88, 0.006)])})
	CyborgSuit.add(list, &"chest", BAND, Vector3(TORSO_HALF.x * 2.0 + 0.016, 0.0, TORSO_HALF.y * 2.0 + 0.016), Vector3.ZERO,
		LEATHER, 0.0, {"sides": 10, "profile": PackedVector4Array([Vector4(-0.08, 1.0, 1.0, 0.0), Vector4(-0.04, 1.0, 1.0, 0.0)])})
	CyborgSuit.add(list, &"chest", BOX, Vector3(0.05, 0.036, 0.012), Vector3(0.0, -0.06, -0.097), BRASS_DARK, 0.0,
		{"shine": BRASS_SHINE})
	# Pelvis: the jumpsuit's seat.
	CyborgSuit.add(list, &"pelvis", BOX, Vector3(0.235, 0.15, 0.175), Vector3(0.0, -0.045, 0.005), SUIT, 0.0,
		{"chamfer": 0.3, "top_scale": Vector2(0.94, 0.92)})


## The scavenged armour, dull brass: a chest plate and a belly plate (rivets at their corners), a
## scuff of bare metal, and a patch of rust.
static func _armour(list: Array[HumanoidPiece]) -> void:
	var brass := {"chamfer": 0.25, "shine": BRASS_SHINE}
	# The chest plate: wider at the top, its front face at z -0.116 (bottom) to -0.112 (top).
	CyborgSuit.add(list, &"chest", BOX, Vector3(0.25, 0.19, 0.036), Vector3(0.0, 0.255, -0.098), BRASS, 0.0,
		CyborgSuit.merged(brass, {"top_scale": Vector2(1.12, 0.8)}))
	CyborgSuit.add(list, &"chest", BOX, Vector3(0.19, 0.09, 0.028), Vector3(0.0, 0.07, -0.094), BRASS_DARK, 0.0, brass)
	for rivet: Vector3 in [Vector3(0.095, 0.19, -0.1175), Vector3(0.12, 0.325, -0.1135)]:
		for sx: float in [-1.0, 1.0]:
			CyborgSuit.patch(list, &"chest", Vector3(rivet.x * sx, rivet.y, rivet.z), Vector2(0.014, 0.014), BRASS_DARK,
				Vector3(0.0, 0.0, 45.0))
	CyborgSuit.patch(list, &"chest", Vector3(-0.05, 0.28, -0.1155), Vector2(0.07, 0.012), SUIT_WORN, Vector3(0.0, 0.0, 20.0))
	CyborgSuit.patch(list, &"chest", Vector3(0.07, 0.22, -0.1165), Vector2(0.04, 0.05), RUST, Vector3(0.0, 0.0, -10.0))


## The radio pack on the back: a steel box with a lid, vents and a dial, a battery on its side, the
## straps over the shoulders, and the base's two cables up into the TV (which stays the base's size,
## so they end inside it the same way).
static func _backpack(list: Array[HumanoidPiece]) -> void:
	CyborgSuit.add(list, &"chest", BOX, Vector3(0.24, 0.27, 0.12), Vector3(0.0, 0.22, 0.163), PACK, 0.0,
		{"chamfer": 0.2, "shine": METAL_SHINE})
	CyborgSuit.add(list, &"chest", BOX, Vector3(0.25, 0.034, 0.126), Vector3(0.0, 0.37, 0.163), GUNMETAL, 0.0,
		{"shine": METAL_SHINE})
	for k: int in 3:
		CyborgSuit.patch(list, &"chest", Vector3(-0.03, 0.29 - k * 0.032, 0.2235), Vector2(0.14, 0.012), RUBBER,
			CyborgSuit.facing(Vector3.BACK))
	CyborgSuit.patch(list, &"chest", Vector3(0.075, 0.16, 0.2235), Vector2(0.04, 0.04), BRASS_DARK,
		CyborgSuit.facing(Vector3.BACK) + Vector3(0.0, 0.0, 45.0))
	CyborgSuit.add(list, &"chest", BOX, Vector3(0.045, 0.14, 0.09), Vector3(-0.14, 0.19, 0.17), GUNMETAL)
	for side: float in [-1.0, 1.0]:
		var a := Vector3(side * 0.085, 0.355, 0.11)
		var b := Vector3(side * 0.118, 0.428, 0.012)
		var c := Vector3(side * 0.112, 0.3, -0.1)
		CyborgSuit.bar(list, &"chest", a, b, Vector2(0.036, 0.01), LEATHER, Vector3.UP)
		CyborgSuit.bar(list, &"chest", b, c, Vector2(0.036, 0.01), LEATHER, Vector3.FORWARD)
	for k: int in CyborgSuit.HEAD_CABLES.size():
		CyborgSuit.cable(list, CyborgSuit.HEAD_CABLES[k], CyborgSuit.HEAD_CABLE_WIDTHS[k], CyborgSuit.CABLE)


## Both arms heavy steel prosthetics under brass pauldrons: a gunmetal core with a steel plate and a
## piston, the elbow joint, a steel forearm housing with a plate, and a big fist.
static func _arms(list: Array[HumanoidPiece]) -> void:
	var metal := {"side": MIRRORED, "shine": METAL_SHINE}
	# The pauldrons: a brass dome over each shoulder with a second plate below its rim.
	CyborgSuit.add(list, &"upper_arm", LATHE, Vector3(0.14, 0.0, 0.14), Vector3(0.008, 0.0, 0.0), BRASS, 0.0, {"side": MIRRORED,
		"sides": 8, "shine": BRASS_SHINE, "profile": PackedVector4Array([Vector4(-0.07, 0.9, 0.9, 0.0),
			Vector4(-0.025, 1.0, 1.0, 0.0), Vector4(0.03, 0.78, 0.78, 0.0), Vector4(0.058, 0.32, 0.32, 0.0)])})
	CyborgSuit.add(list, &"upper_arm", BAND, Vector3(0.13, 0.0, 0.13), Vector3(0.012, 0.0, 0.0), BRASS_DARK, 0.0,
		{"side": MIRRORED, "sides": 8, "profile": PackedVector4Array([Vector4(-0.1, 0.96, 0.96, 0.0),
			Vector4(-0.068, 1.0, 1.0, 0.0)])})
	CyborgSuit.add(list, &"upper_arm", PRISM, Vector3(0.056, 0.22, 0.056), Vector3(0.0, -0.15, 0.0), GUNMETAL, 0.0,
		{"side": MIRRORED, "sides": 6})
	CyborgSuit.add(list, &"upper_arm", BOX, Vector3(0.07, 0.15, 0.018), Vector3(0.0, -0.16, -0.036), STEEL, 0.0, metal)
	CyborgSuit.pipe(list, &"upper_arm", Vector3(-0.03, -0.1, 0.03), Vector3(-0.03, -0.25, 0.03), 0.018, STEEL, 4, MIRRORED)
	CyborgSuit.add(list, &"upper_arm", PRISM, Vector3(0.08, 0.082, 0.08), Vector3(0.0, -0.28, 0.0), GUNMETAL, 0.0,
		CyborgSuit.merged(metal, {"sides": 6, "rotation_degrees": Vector3(0.0, 0.0, 90.0)}))
	# The forearms: a steel housing, a plate, a rusty patch, and the fist.
	CyborgSuit.add(list, &"forearm", PRISM, Vector3(0.1, 0.2, 0.1), Vector3(0.0, -0.12, 0.0), STEEL_DARK, 0.0,
		CyborgSuit.merged(metal, {"sides": 8, "top_scale": Vector2(0.84, 0.84)}))
	CyborgSuit.add(list, &"forearm", BOX, Vector3(0.075, 0.13, 0.016), Vector3(0.0, -0.13, -0.052), STEEL, 0.0, metal)
	CyborgSuit.patch(list, &"forearm", Vector3(0.049, -0.1, 0.0), Vector2(0.05, 0.06), RUST, CyborgSuit.facing(Vector3.RIGHT),
		1.0, MIRRORED)
	CyborgSuit.add(list, &"forearm", BAND, Vector3(0.1, 0.0, 0.1), Vector3.ZERO, GUNMETAL, 0.0, {"side": MIRRORED,
		"sides": 8, "profile": PackedVector4Array([Vector4(-0.225, 1.0, 1.0, 0.0), Vector4(-0.245, 0.96, 0.96, 0.0)])})
	CyborgSuit.add(list, &"forearm", BOX, Vector3(0.088, 0.095, 0.096), Vector3(0.0, -0.29, -0.004), STEEL_DARK, 0.0,
		CyborgSuit.merged(metal, {"chamfer": 0.3}))
	CyborgSuit.add(list, &"forearm", BOX, Vector3(0.092, 0.024, 0.026), Vector3(0.0, -0.315, -0.05), STEEL, 0.0, metal)


## The pipe gun in the right fist: a steel pipe running out along the arm through the fist, taped,
## with a valve and a gas canister beside it and a welded collar at the muzzle, where the shared
## emitter ring and charge orb sit (CyborgSuit.MUZZLE).
static func _pipe_gun(list: Array[HumanoidPiece]) -> void:
	var metal := {"side": RIGHT, "shine": METAL_SHINE}
	CyborgSuit.add(list, &"forearm", PRISM, Vector3(0.05, 0.16, 0.05), Vector3(0.0, -0.31, 0.0), STEEL, 0.0,
		CyborgSuit.merged(metal, {"sides": 8}))
	CyborgSuit.add(list, &"forearm", PRISM, Vector3(0.075, 0.03, 0.075), Vector3(0.0, -0.382, 0.0), GUNMETAL, 0.0,
		CyborgSuit.merged(metal, {"sides": 8}))
	CyborgSuit.add(list, &"forearm", BAND, Vector3(0.056, 0.0, 0.056), Vector3.ZERO, TAPE, 0.0, {"side": RIGHT, "sides": 8,
		"profile": PackedVector4Array([Vector4(-0.36, 1.0, 1.0, 0.0), Vector4(-0.345, 1.0, 1.0, 0.0)])})
	# The canister strapped along its outer side, and the valve on top of the pipe past the fist.
	CyborgSuit.add(list, &"forearm", PRISM, Vector3(0.036, 0.1, 0.036), Vector3(0.045, -0.35, 0.012), GUNMETAL, 0.0,
		CyborgSuit.merged(metal, {"sides": 6}))
	CyborgSuit.pipe(list, &"forearm", Vector3(0.0, -0.345, -0.024), Vector3(0.0, -0.345, -0.05), 0.012, STEEL, 4, RIGHT)
	CyborgSuit.add(list, &"forearm", PRISM, Vector3(0.04, 0.008, 0.04), Vector3(0.0, -0.345, -0.052), RUST, 0.0,
		{"side": RIGHT, "sides": 6, "rotation_degrees": Vector3(90.0, 0.0, 0.0)})


## Baggy jumpsuit legs with cargo pockets, brass knee pads, and heavy work boots with steel toe caps.
static func _legs(list: Array[HumanoidPiece]) -> void:
	CyborgSuit.add(list, &"thigh", PRISM, Vector3(0.134, 0.34, 0.134), Vector3(0.0, -0.16, 0.0), SUIT, 0.0,
		{"sides": 8, "top_scale": Vector2(1.08, 1.06)})
	CyborgSuit.add(list, &"thigh", BOX, Vector3(0.026, 0.09, 0.08), Vector3(0.07, -0.18, 0.0), SUIT_SHADE)
	CyborgSuit.patch(list, &"thigh", Vector3(-0.02, -0.12, -0.063), Vector2(0.05, 0.05), SUIT_WORN, Vector3(0.0, 0.0, 6.0),
		1.0, LEFT)
	CyborgSuit.add(list, &"shin", BOX, Vector3(0.09, 0.085, 0.036), Vector3(0.0, -0.015, -0.064), BRASS, 0.0,
		{"chamfer": 0.3, "shine": BRASS_SHINE, "top_scale": Vector2(0.9, 0.8)})
	CyborgSuit.add(list, &"shin", PRISM, Vector3(0.128, 0.18, 0.128), Vector3(0.0, -0.085, 0.0), SUIT, 0.0,
		{"sides": 8, "top_scale": Vector2(0.98, 0.98)})
	CyborgSuit.add(list, &"shin", PRISM, Vector3(0.106, 0.11, 0.106), Vector3(0.0, -0.215, 0.0), BOOT, 0.0, {"sides": 8})
	CyborgSuit.add(list, &"shin", BOX, Vector3(0.106, 0.075, 0.2), Vector3(0.0, -0.27, -0.042), BOOT, 0.0,
		{"chamfer": 0.3, "top_scale": Vector2(0.9, 0.72), "top_shift": 0.02})
	CyborgSuit.add(list, &"shin", BOX, Vector3(0.1, 0.046, 0.055), Vector3(0.0, -0.283, -0.118), STEEL, 0.0,
		{"chamfer": 0.3, "shine": METAL_SHINE, "top_scale": Vector2(0.92, 0.8)})
