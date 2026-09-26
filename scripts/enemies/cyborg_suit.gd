class_name CyborgSuit
extends RefCounted
## The cyborgs' look on the shared HumanoidRig (GDD §9.2 production note: "one shared body and
## skeleton with swappable parts per zone"). One HumanoidParts: the cyborg skeleton, the base pieces
## every cyborg shares (face plate, LED screen, the arm cannon's emitter ring and charge orb) and one
## attachment set per zone look, switched on with HumanoidRig.set_attachments():
##   &"city"       the sleek citizen: steel-blue armour, pale panels, amber trim lines;
##   &"scavenger"  patched together: mismatched rusty, olive and steel plates, bolts, a bulky welded
##                 cannon, an antenna, dimmer trim.
## Hands and feet ride on the forearms and shins, and the neck on the chest, so a whole cyborg is 11
## segment meshes; the screen, ring and orb are marked pieces in the same meshes that
## cyborg_body.gdshader draws with the body. One material per cyborg, 11 draw calls.
##
## Rig convention (HumanoidPiece): metres, +y up, -z forward (where the cyborg faces), +x its right.
## Limb pieces are authored for the right limb; RIGHT-only pieces are the arm cannon's, LEFT-only ones
## the scavenger's mismatched left limbs. Hazard colours stay the same in both looks: the cannon's
## charge is enemy-fire red, the LED faces amber.

const Kit = preload("res://scripts/enemies/cyborg_kit.gd")
const SHADER: Shader = preload("res://scripts/enemies/cyborg_body.gdshader")
const CACHE_KEY: String = "cyborg_v1"
const VARIANTS: Array[StringName] = [&"city", &"scavenger"]
const WALK_TUNING_PATH: String = "res://data/tuning/cyborg_walk_animation.tres"
const RUN_TUNING_PATH: String = "res://data/tuning/cyborg_run_animation.tres"

## Glow values marking the pieces cyborg_body.gdshader draws specially.
const SCREEN: float = 10.0
const RING: float = 20.0
const ORB: float = 30.0

## The head is drawn a little large so the LED face reads from a distance.
const HEAD_SCALE: float = 1.15
## The LED screen on the head, and the charge orb on the cannon forearm (segment spaces).
const SCREEN_CENTER := Vector3(0.0, 0.1265, -0.1592)
const SCREEN_SIZE := Vector3(0.2185, 0.1196, 0.0092)
const MUZZLE := Vector3(0.0, -0.43, 0.0)

const BOX := HumanoidPiece.Shape.BOX
const PRISM := HumanoidPiece.Shape.PRISM
const LATHE := HumanoidPiece.Shape.LATHE
const MIRRORED := HumanoidPiece.Placement.MIRRORED
const RIGHT := HumanoidPiece.Placement.RIGHT
const LEFT := HumanoidPiece.Placement.LEFT

static var _parts: HumanoidParts
static var _walk: HumanoidAnimTuning
static var _run: HumanoidAnimTuning


static func parts() -> HumanoidParts:
	if _parts == null:
		_parts = _build_parts()
	return _parts


## A new material for one cyborg (its face, charge, flash and death are its own).
static func new_material(variant: StringName, host: bool, visual_seed: int) -> ShaderMaterial:
	var scav: bool = variant == &"scavenger"
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter(&"led_color", Kit.LED_SCAVENGER if scav else Kit.LED_COLOR)
	m.set_shader_parameter(&"glitch_color", Kit.GLITCH_COLOR)
	m.set_shader_parameter(&"glitch", 1.0 if host else 0.0)
	m.set_shader_parameter(&"flicker", 0.8 if scav else 0.0)
	m.set_shader_parameter(&"crack", 1.0 if scav else 0.0)
	m.set_shader_parameter(&"seed", float(visual_seed % 997))
	m.set_shader_parameter(&"charge_color", Kit.CHARGE_COLOR)
	m.set_shader_parameter(&"orb_center", MUZZLE)
	var half := Vector2(SCREEN_SIZE.x, SCREEN_SIZE.y) * 0.5
	m.set_shader_parameter(&"screen_rect", Vector4(SCREEN_CENTER.x - half.x, SCREEN_CENTER.y - half.y,
		SCREEN_CENTER.x + half.x, SCREEN_CENTER.y + half.y))
	m.set_shader_parameter(&"face", Kit.face_texture(Kit.Face.NEUTRAL))
	return m


## The walk cycle's pose numbers (data/tuning/cyborg_walk_animation.tres; also the idle breathing).
static func walk_tuning() -> HumanoidAnimTuning:
	if _walk == null:
		_walk = _load_tuning(WALK_TUNING_PATH)
	return _walk


## The panic variant's sprint (data/tuning/cyborg_run_animation.tres).
static func run_tuning() -> HumanoidAnimTuning:
	if _run == null:
		_run = _load_tuning(RUN_TUNING_PATH)
	return _run


static func _load_tuning(path: String) -> HumanoidAnimTuning:
	var t: HumanoidAnimTuning = load(path) as HumanoidAnimTuning if ResourceLoader.exists(path) else null
	return t if t != null else HumanoidAnimTuning.new()


static func _build_parts() -> HumanoidParts:
	var p := HumanoidParts.new()
	p.cache_key = CACHE_KEY
	p.design_size = Vector3(0.62, 1.52, 0.4)
	# The cyborg skeleton: hips at 0.7 m, shoulders at 1.16 m, the head joint at 1.24 m.
	p.hip_offset = Vector3(0.085, -0.05, 0.0)
	p.thigh_length = 0.33
	p.shin_length = 0.26
	p.ankle_height = 0.06
	p.chest_offset = Vector3(0.0, 0.06, 0.0)
	p.neck_offset = Vector3(0.0, 0.45, 0.0)
	p.head_offset = Vector3(0.0, 0.03, 0.0)
	p.shoulder_offset = Vector3(0.23, 0.4, 0.0)
	p.upper_arm_length = 0.28
	p.forearm_length = 0.25
	p.pieces = _base()
	p.attachments = {&"city": _city(), &"scavenger": _scavenger()}
	return p


## Shared by every look: the dark face plate, the LED screen, the cannon's ring and charge orb, and the
## boots. The boots must be here: HumanoidRig puts a body on the ground by the lowest points of its
## bare segments (no attachment sets), so the soles have to be part of the bare shins.
static func _base() -> Array[HumanoidPiece]:
	var list: Array[HumanoidPiece] = []
	var plate := Color(0.07, 0.07, 0.085)
	_add(list, &"shin", BOX, Vector3(0.105, 0.06, 0.205), Vector3(0.0, -0.31, -0.03), Color(0.1, 0.095, 0.1), 0.0,
		{"top_scale": Vector2(0.9, 0.85)})
	_add(list, &"head", BOX, Vector3(0.247, 0.155, 0.023), Vector3(0.0, 0.1265, -0.1426), plate)
	_add(list, &"head", BOX, SCREEN_SIZE, SCREEN_CENTER, Color.BLACK, SCREEN)
	_add(list, &"forearm", PRISM, Vector3(0.136, 0.03, 0.136), Vector3(0.0, -0.405, 0.0), Color.WHITE, RING,
		{"side": RIGHT, "sides": 8})
	var rings := PackedVector4Array()
	for k: int in 7:
		var a: float = PI * k / 6.0
		rings.append(Vector4(-cos(a) * 0.075, sin(a), sin(a), 0.0))
	_add(list, &"forearm", LATHE, Vector3(0.15, 0.0, 0.15), MUZZLE, Color.WHITE, ORB,
		{"side": RIGHT, "sides": 8, "profile": rings})
	return list


## The sleek city citizen.
static func _city() -> Array[HumanoidPiece]:
	var list: Array[HumanoidPiece] = []
	var armor := Color(0.4, 0.45, 0.56)
	var panel := Color(0.86, 0.88, 0.93)
	var joint := Color(0.09, 0.09, 0.11)
	var trim := Kit.LED_COLOR
	var s: float = HEAD_SCALE
	# Pelvis and belt.
	_add(list, &"pelvis", BOX, Vector3(0.3, 0.15, 0.19), Vector3.ZERO, armor, 0.0, {"top_scale": Vector2(1.08, 1.0)})
	_add(list, &"pelvis", BOX, Vector3(0.26, 0.022, 0.006), Vector3(0.0, 0.055, -0.097), trim, 1.0)
	# Torso: abdomen, armoured chest with a pale plate and a trim line, back plate, neck.
	_add(list, &"chest", BOX, Vector3(0.22, 0.2, 0.15), Vector3(0.0, 0.1, 0.0), joint, 0.0, {"top_scale": Vector2(1.2, 1.1)})
	_add(list, &"chest", BOX, Vector3(0.3, 0.26, 0.21), Vector3(0.0, 0.31, 0.0), armor, 0.0, {"top_scale": Vector2(1.35, 1.0)})
	_add(list, &"chest", BOX, Vector3(0.24, 0.17, 0.02), Vector3(0.0, 0.33, -0.105), panel, 0.0, {"top_scale": Vector2(1.25, 1.0)})
	_add(list, &"chest", BOX, Vector3(0.28, 0.016, 0.01), Vector3(0.0, 0.225, -0.113), trim, 1.0)
	_add(list, &"chest", BOX, Vector3(0.18, 0.2, 0.03), Vector3(0.0, 0.3, 0.11), armor)
	_add(list, &"chest", BOX, Vector3(0.08, 0.06, 0.08), Vector3(0.0, 0.47, 0.0), joint)
	# Helmet with a glowing crest and pale ear pieces.
	_add(list, &"head", BOX, Vector3(0.24, 0.24, 0.26) * s, Vector3(0.0, 0.12, 0.0) * s, armor, 0.0,
		{"top_scale": Vector2(0.82, 0.86)})
	_add(list, &"head", BOX, Vector3(0.035, 0.035, 0.2) * s, Vector3(0.0, 0.245, 0.01) * s, trim, 0.9)
	_add(list, &"head", BOX, Vector3(0.02, 0.09, 0.11) * s, Vector3(0.123, 0.11, 0.0) * s, panel, 0.0, {"side": MIRRORED})
	# Arms: shoulder pad, upper arm with a trim tick, elbow.
	_add(list, &"upper_arm", BOX, Vector3(0.15, 0.1, 0.17), Vector3(0.02, -0.02, 0.0), panel, 0.0, {"top_scale": Vector2(0.7, 0.8)})
	_add(list, &"upper_arm", BOX, Vector3(0.09, 0.22, 0.09), Vector3(0.0, -0.14, 0.0), armor, 0.0, {"top_scale": Vector2(1.1, 1.1)})
	_add(list, &"upper_arm", BOX, Vector3(0.006, 0.05, 0.12), Vector3(0.078, -0.02, 0.0), trim, 1.0)
	_add(list, &"upper_arm", BOX, Vector3(0.07, 0.05, 0.07), Vector3(0.0, -0.27, 0.0), joint)
	# Left forearm and hand; the right forearm is the arm cannon.
	_add(list, &"forearm", BOX, Vector3(0.075, 0.22, 0.075), Vector3(0.0, -0.12, 0.0), armor, 0.0,
		{"side": LEFT, "top_scale": Vector2(1.2, 1.2)})
	_add(list, &"forearm", BOX, Vector3(0.07, 0.07, 0.06), Vector3(0.0, -0.265, 0.0), joint, 0.0, {"side": LEFT})
	_add(list, &"forearm", BOX, Vector3(0.085, 0.18, 0.085), Vector3(0.0, -0.1, 0.0), armor, 0.0,
		{"side": RIGHT, "top_scale": Vector2(1.2, 1.2)})
	_add(list, &"forearm", PRISM, Vector3(0.124, 0.3, 0.124), Vector3(0.0, -0.25, 0.0), panel, 0.0,
		{"side": RIGHT, "sides": 8, "top_scale": Vector2(0.85, 0.85)})
	_add(list, &"forearm", PRISM, Vector3(0.1, 0.06, 0.1), Vector3(0.0, -0.375, 0.0), joint, 0.0, {"side": RIGHT, "sides": 8})
	for x: float in [-0.058, 0.058]:
		_add(list, &"forearm", BOX, Vector3(0.006, 0.2, 0.025), Vector3(x, -0.25, 0.0), trim, 1.0, {"side": RIGHT})
	# Legs: thigh with a knee plate, shin with a guard and a trim tick, the foot.
	_add(list, &"thigh", BOX, Vector3(0.125, 0.3, 0.135), Vector3(0.0, -0.16, 0.0), armor, 0.0, {"top_scale": Vector2(1.25, 1.2)})
	_add(list, &"thigh", BOX, Vector3(0.09, 0.06, 0.1), Vector3(0.0, -0.325, -0.012), panel)
	_add(list, &"shin", BOX, Vector3(0.09, 0.28, 0.1), Vector3(0.0, -0.15, 0.0), armor, 0.0, {"top_scale": Vector2(1.2, 1.15)})
	_add(list, &"shin", BOX, Vector3(0.07, 0.19, 0.02), Vector3(0.0, -0.13, -0.055), panel, 0.0, {"top_scale": Vector2(1.15, 1.0)})
	_add(list, &"shin", BOX, Vector3(0.05, 0.014, 0.006), Vector3(0.0, -0.06, -0.068), trim, 1.0)
	return list


## The patched-together scavenger: mismatched plates on each side, bolts, a vent stack, an antenna.
static func _scavenger() -> Array[HumanoidPiece]:
	var list: Array[HumanoidPiece] = []
	var rust := Color(0.66, 0.36, 0.17)
	var olive := Color(0.5, 0.53, 0.31)
	var steel := Color(0.55, 0.57, 0.6)
	var frame := Color(0.12, 0.11, 0.1)
	var bolt := Color(0.82, 0.78, 0.7)
	var trim := Kit.LED_SCAVENGER
	var s: float = HEAD_SCALE
	# Pelvis: a bare frame with a tilted plate and a pouch.
	_add(list, &"pelvis", BOX, Vector3(0.3, 0.14, 0.19), Vector3.ZERO, frame)
	_add(list, &"pelvis", BOX, Vector3(0.12, 0.12, 0.03), Vector3(-0.07, -0.01, -0.1), olive, 0.0,
		{"rotation_degrees": Vector3(0.0, 0.0, -11.0)})
	_add(list, &"pelvis", BOX, Vector3(0.09, 0.1, 0.1), Vector3(0.1, -0.05, -0.06), rust)
	# Torso: rust and steel halves, a patch plate with bolts, a vent stack on the back.
	_add(list, &"chest", BOX, Vector3(0.2, 0.2, 0.14), Vector3(0.0, 0.1, 0.0), frame, 0.0, {"top_scale": Vector2(1.3, 1.1)})
	_add(list, &"chest", BOX, Vector3(0.2, 0.27, 0.22), Vector3(-0.055, 0.31, 0.0), rust, 0.0, {"top_scale": Vector2(1.15, 1.0)})
	_add(list, &"chest", BOX, Vector3(0.17, 0.24, 0.2), Vector3(0.1, 0.3, 0.0), steel, 0.0,
		{"top_scale": Vector2(1.15, 1.0), "rotation_degrees": Vector3(0.0, 0.0, 4.6)})
	_add(list, &"chest", BOX, Vector3(0.14, 0.1, 0.02), Vector3(-0.02, 0.35, -0.112), olive, 0.0,
		{"rotation_degrees": Vector3(0.0, 0.0, -14.3)})
	for b: Vector2 in [Vector2(0.04, 0.39), Vector2(-0.08, 0.31), Vector2(0.04, 0.31), Vector2(-0.08, 0.39)]:
		_add(list, &"chest", BOX, Vector3(0.018, 0.018, 0.012), Vector3(b.x, b.y, -0.124), bolt)
	_add(list, &"chest", BOX, Vector3(0.12, 0.014, 0.01), Vector3(0.02, 0.215, -0.11), trim, 0.7)
	_add(list, &"chest", PRISM, Vector3(0.07, 0.24, 0.07), Vector3(-0.08, 0.38, 0.13), frame, 0.0, {"sides": 6})
	_add(list, &"chest", BOX, Vector3(0.05, 0.02, 0.05), Vector3(-0.08, 0.5, 0.13), trim, 0.5)
	_add(list, &"chest", BOX, Vector3(0.09, 0.06, 0.09), Vector3(0.0, 0.47, 0.0), frame)
	# Boxy helmet with a riveted strap, an antenna and a side plate.
	_add(list, &"head", BOX, Vector3(0.25, 0.23, 0.25) * s, Vector3(0.0, 0.12, 0.0) * s, steel, 0.0,
		{"top_scale": Vector2(0.95, 0.9)})
	_add(list, &"head", BOX, Vector3(0.27, 0.035, 0.27) * s, Vector3(0.0, 0.2, 0.0) * s, rust)
	_add(list, &"head", BOX, Vector3(0.012, 0.18, 0.012) * s, Vector3(-0.1, 0.3, 0.05) * s, frame)
	_add(list, &"head", BOX, Vector3(0.025, 0.025, 0.025) * s, Vector3(-0.1, 0.39, 0.05) * s, trim, 0.8)
	_add(list, &"head", BOX, Vector3(0.03, 0.1, 0.12) * s, Vector3(0.13, 0.12, 0.0) * s, olive)
	# Mismatched arms: a thin olive left arm, a heavy rust-and-steel cannon arm.
	_add(list, &"upper_arm", BOX, Vector3(0.08, 0.24, 0.08), Vector3(0.0, -0.13, 0.0), olive, 0.0, {"side": LEFT})
	_add(list, &"upper_arm", BOX, Vector3(0.07, 0.05, 0.07), Vector3(0.0, -0.27, 0.0), frame, 0.0, {"side": LEFT})
	_add(list, &"upper_arm", BOX, Vector3(0.18, 0.12, 0.19), Vector3(0.03, -0.03, 0.0), rust, 0.0,
		{"side": RIGHT, "top_scale": Vector2(0.75, 0.85)})
	_add(list, &"upper_arm", BOX, Vector3(0.02, 0.02, 0.02), Vector3(0.1, 0.02, -0.07), bolt, 0.0, {"side": RIGHT})
	_add(list, &"upper_arm", BOX, Vector3(0.1, 0.22, 0.1), Vector3(0.0, -0.15, 0.0), steel, 0.0, {"side": RIGHT})
	_add(list, &"upper_arm", BOX, Vector3(0.08, 0.05, 0.08), Vector3(0.0, -0.27, 0.0), frame, 0.0, {"side": RIGHT})
	_add(list, &"forearm", BOX, Vector3(0.075, 0.22, 0.075), Vector3(0.0, -0.12, 0.0), steel, 0.0, {"side": LEFT})
	_add(list, &"forearm", BOX, Vector3(0.085, 0.05, 0.085), Vector3(0.0, -0.1, 0.0), rust, 0.0, {"side": LEFT})
	_add(list, &"forearm", BOX, Vector3(0.07, 0.07, 0.06), Vector3(0.0, -0.265, 0.0), frame, 0.0, {"side": LEFT})
	_add(list, &"forearm", BOX, Vector3(0.1, 0.18, 0.1), Vector3(0.0, -0.09, 0.0), frame, 0.0, {"side": RIGHT})
	_add(list, &"forearm", PRISM, Vector3(0.15, 0.32, 0.15), Vector3(0.0, -0.25, 0.0), steel, 0.0, {"side": RIGHT, "sides": 6})
	_add(list, &"forearm", PRISM, Vector3(0.06, 0.26, 0.06), Vector3(-0.05, -0.2, -0.05), rust, 0.0, {"side": RIGHT, "sides": 5})
	_add(list, &"forearm", BOX, Vector3(0.17, 0.03, 0.17), Vector3(0.0, -0.2, 0.0), rust, 0.0, {"side": RIGHT})
	_add(list, &"forearm", PRISM, Vector3(0.11, 0.05, 0.11), Vector3(0.0, -0.39, 0.0), frame, 0.0, {"side": RIGHT, "sides": 6})
	_add(list, &"forearm", BOX, Vector3(0.008, 0.12, 0.02), Vector3(0.07, -0.3, 0.0), trim, 0.6, {"side": RIGHT})
	# Mismatched legs: steel and olive on the left, rust with a knee brace on the right.
	_add(list, &"thigh", BOX, Vector3(0.125, 0.3, 0.13), Vector3(0.0, -0.16, 0.0), steel, 0.0,
		{"side": LEFT, "top_scale": Vector2(1.2, 1.15)})
	_add(list, &"thigh", BOX, Vector3(0.09, 0.06, 0.1), Vector3(0.0, -0.325, -0.015), frame, 0.0, {"side": LEFT})
	_add(list, &"thigh", BOX, Vector3(0.13, 0.3, 0.14), Vector3(0.0, -0.16, 0.0), rust, 0.0,
		{"side": RIGHT, "top_scale": Vector2(1.2, 1.1)})
	_add(list, &"thigh", BOX, Vector3(0.11, 0.08, 0.11), Vector3(0.0, -0.325, -0.02), olive, 0.0, {"side": RIGHT})
	for side: HumanoidPiece.Placement in [LEFT, RIGHT]:
		var c: Color = olive if side == LEFT else steel
		_add(list, &"shin", BOX, Vector3(0.09, 0.28, 0.1), Vector3(0.0, -0.15, 0.0), c, 0.0,
			{"side": side, "top_scale": Vector2(1.2, 1.15)})
	_add(list, &"shin", BOX, Vector3(0.06, 0.12, 0.02), Vector3(0.0, -0.12, -0.056), frame)
	return list


static func _add(list: Array[HumanoidPiece], segment: StringName, shape: HumanoidPiece.Shape, size: Vector3,
		at: Vector3, color: Color, glow: float = 0.0, extra: Dictionary = {}) -> void:
	var piece := HumanoidPiece.new()
	piece.segment = segment
	piece.shape = shape
	piece.size = size
	piece.offset = at
	piece.color = color
	piece.glow = glow
	for key: String in extra:
		piece.set(key, extra[key])
	list.append(piece)
