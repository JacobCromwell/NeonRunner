class_name SwarmHostPerson
extends RefCounted
## The person at the heart of the Sewer Swarm (GDD §10: "a poor person with electronic components fused to
## their sickly body, mostly hidden under the screeches latched onto them. An unconnected monster, not one of
## the villain's"), on the shared HumanoidRig (CLAUDE.md: one shared body and skeleton with swappable parts),
## built like the Marketplace citizens (simple boxes and prisms) but sickly: grey-green skin, rags, and dark
## implants fused along the spine, the neck and an arm, their sockets glowing red (GDD §10: "its fused
## implants, glowing red"). SwarmHost holds it up inside the swarm's bulk, and its implants show through as
## each hit knocks screeches off; beaten, it slumps free (poses below). Never a cyborg's look: no screen
## head, no white LEDs.
## DESIGN-TBD (docs/questions/e4.md): the look.

const BOX := HumanoidPiece.Shape.BOX
const PRISM := HumanoidPiece.Shape.PRISM
const MIRRORED := HumanoidPiece.Placement.MIRRORED

const SKIN := Color(0.56, 0.6, 0.5)
const SKIN_DARK := Color(0.42, 0.45, 0.36)
const RAGS := Color(0.26, 0.23, 0.2)
const RAGS_DARK := Color(0.17, 0.15, 0.13)
const HAIR := Color(0.12, 0.11, 0.1)
const METAL := Color(0.22, 0.23, 0.25)
## The implants' sockets: the weak points' red (BossProps.WARNING_COLOR), glowing.
const IMPLANT := Color(1.0, 0.16, 0.08)

static var _parts: HumanoidParts
static var _material: ShaderMaterial


## The person's look (cached).
static func parts() -> HumanoidParts:
	if _parts != null:
		return _parts
	var p := HumanoidParts.new()
	p.cache_key = "swarm_host_person"
	p.design_size = Vector3(0.58, 1.3, 0.5)
	var list: Array[HumanoidPiece] = []
	_add(list, &"pelvis", BOX, Vector3(0.22, 0.16, 0.15), Vector3.ZERO, RAGS, {"chamfer": 0.3})
	# A torn shirt over a thin, sickly chest; the spine's implants in a row down the back.
	_add(list, &"chest", BOX, Vector3(0.25, 0.33, 0.16), Vector3(0.0, 0.165, 0.0), SKIN, {"chamfer": 0.3,
		"top_scale": Vector2(0.9, 0.95)})
	_add(list, &"chest", BOX, Vector3(0.262, 0.2, 0.17), Vector3(0.0, 0.08, 0.0), RAGS_DARK, {"chamfer": 0.25})
	for i: int in 3:
		var y: float = 0.06 + 0.1 * i
		_add(list, &"chest", BOX, Vector3(0.09, 0.07, 0.05), Vector3(0.0, y, 0.095), METAL, {"chamfer": 0.2})
		_add(list, &"chest", BOX, Vector3(0.04, 0.03, 0.02), Vector3(0.0, y, 0.12), IMPLANT, {"glow": 1.6})
	# Cables from the spine to the shoulders.
	for side: float in [-1.0, 1.0]:
		_add(list, &"chest", BOX, Vector3(0.11, 0.025, 0.025), Vector3(side * 0.07, 0.27, 0.085), METAL,
			{"rotation_degrees": Vector3(0.0, 0.0, side * 25.0)})
	_add(list, &"neck", PRISM, Vector3(0.065, 0.07, 0.065), Vector3.ZERO, SKIN_DARK, {"sides": 8})
	_add(list, &"neck", BOX, Vector3(0.05, 0.05, 0.03), Vector3(0.0, 0.03, 0.04), METAL, {"chamfer": 0.2})
	_add(list, &"head", BOX, Vector3(0.14, 0.17, 0.15), Vector3.ZERO, SKIN, {"chamfer": 0.35,
		"top_scale": Vector2(0.9, 0.92)})
	_add(list, &"head", PRISM, Vector3(0.15, 0.06, 0.15), Vector3(0.0, 0.11, 0.01), HAIR,
		{"sides": 8, "top_scale": Vector2(0.7, 0.7)})
	# A plate fused over one temple, its socket glowing.
	_add(list, &"head", BOX, Vector3(0.03, 0.07, 0.08), Vector3(0.075, 0.03, -0.01), METAL, {"chamfer": 0.2})
	_add(list, &"head", BOX, Vector3(0.012, 0.025, 0.025), Vector3(0.093, 0.035, -0.02), IMPLANT, {"glow": 1.6})
	_add(list, &"upper_arm", PRISM, Vector3(0.07, 0.2, 0.07), Vector3.ZERO, SKIN_DARK, {"sides": 8,
		"top_scale": Vector2(0.9, 0.9), "side": MIRRORED})
	_add(list, &"forearm", PRISM, Vector3(0.06, 0.18, 0.06), Vector3.ZERO, SKIN, {"sides": 8,
		"top_scale": Vector2(0.88, 0.88), "side": MIRRORED})
	_add(list, &"forearm", BOX, Vector3(0.075, 0.08, 0.075), Vector3(0.0, 0.06, 0.0), METAL, {"chamfer": 0.2,
		"side": MIRRORED})
	_add(list, &"hand", BOX, Vector3(0.055, 0.075, 0.045), Vector3.ZERO, SKIN, {"chamfer": 0.3, "side": MIRRORED})
	_add(list, &"thigh", PRISM, Vector3(0.105, 0.3, 0.105), Vector3.ZERO, RAGS, {"sides": 8,
		"top_scale": Vector2(1.06, 1.06), "side": MIRRORED})
	_add(list, &"shin", PRISM, Vector3(0.08, 0.3, 0.08), Vector3.ZERO, RAGS_DARK, {"sides": 8,
		"top_scale": Vector2(1.05, 1.05), "side": MIRRORED})
	_add(list, &"foot", BOX, Vector3(0.085, 0.075, 0.17), Vector3(0.0, -0.01, -0.03), SKIN_DARK,
		{"chamfer": 0.25, "top_scale": Vector2(0.9, 0.8), "side": MIRRORED})
	p.pieces = list
	_parts = p
	return p


## Its body material (vertex colours and glow; the rig's own shader).
static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = preload("res://scripts/characters/humanoid_body.gdshader")
		_material.set_shader_parameter(&"glow_energy", 2.2)
	return _material


## Held up inside the swarm: limp, arms dragged out to the sides, head hanging (`t` 0-1 sways it).
static func held(t: float) -> HumanoidPose:
	var p := HumanoidPose.new()
	var sway: float = sin(TAU * t)
	p.set_deg(HumanoidPose.CHEST, Vector3(-6.0, 4.0 * sway, 3.0 * sway))
	p.set_deg(HumanoidPose.HEAD, Vector3(28.0, -6.0 * sway, 4.0))
	for side: int in [-1, 1]:
		p.set_limb(HumanoidPose.UPPER_ARM_R, side, Vector3(-10.0 + 6.0 * sway * side, 0.0, 62.0))
		p.set_limb(HumanoidPose.FOREARM_R, side, Vector3(24.0, 0.0, 0.0))
		p.set_limb(HumanoidPose.THIGH_R, side, Vector3(8.0, 0.0, 6.0))
		p.set_limb(HumanoidPose.SHIN_R, side, Vector3(-18.0, 0.0, 0.0))
	p.ground = 0.0
	return p


## Lying face down along the Host's crouch, arms reaching ahead.
static func prone() -> HumanoidPose:
	var p := HumanoidPose.new()
	p.root_rot = Vector3(deg_to_rad(-82.0), 0.0, 0.0)
	p.set_deg(HumanoidPose.HEAD, Vector3(-30.0, 0.0, 0.0))
	for side: int in [-1, 1]:
		p.set_limb(HumanoidPose.UPPER_ARM_R, side, Vector3(-150.0, 0.0, 14.0))
		p.set_limb(HumanoidPose.FOREARM_R, side, Vector3(10.0, 0.0, 0.0))
		p.set_limb(HumanoidPose.THIGH_R, side, Vector3(-4.0, 0.0, 5.0))
	p.ground = 0.0
	return p


## Freed (GDD §10: "the person slumps free"): sitting slumped on the street, head down, arms in the lap.
static func freed() -> HumanoidPose:
	var p := HumanoidPose.new()
	p.set_deg(HumanoidPose.CHEST, Vector3(26.0, 0.0, 0.0))
	p.set_deg(HumanoidPose.HEAD, Vector3(32.0, 8.0, 0.0))
	for side: int in [-1, 1]:
		p.set_limb(HumanoidPose.UPPER_ARM_R, side, Vector3(20.0, 0.0, 8.0))
		p.set_limb(HumanoidPose.FOREARM_R, side, Vector3(70.0, 0.0, 0.0))
		p.set_limb(HumanoidPose.THIGH_R, side, Vector3(84.0, 0.0, 12.0))
		p.set_limb(HumanoidPose.SHIN_R, side, Vector3(-70.0, 0.0, 0.0))
	return p


static func _add(list: Array[HumanoidPiece], segment: StringName, shape: HumanoidPiece.Shape, size: Vector3,
		at: Vector3, color: Color, extra: Dictionary = {}) -> void:
	var piece := HumanoidPiece.new()
	piece.segment = segment
	piece.shape = shape
	piece.size = size
	piece.offset = at
	piece.color = color
	for key: String in extra:
		piece.set(key, extra[key])
	list.append(piece)
