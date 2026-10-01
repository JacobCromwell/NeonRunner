class_name CitizenRig
extends RefCounted
## The Marketplace citizens' body and poses (GDD §5, "Citizens"; task D3), on the shared
## HumanoidRig (scripts/characters/): plain, unarmed, ordinary people, built the same way the player
## and the cyborgs are (CLAUDE.md: "one shared body and skeleton with swappable parts"), but simpler
## (no equipment, no weapon) since they are never seen in 3D at runtime. `tools/asset_gen/
## citizen_sheet_gen.gd` is the only thing that builds this rig: it poses it through pose_at() and
## bakes the frames into a flipbook (MarketCitizen plays the baked sheet back as a cheap textured
## card, never the rig itself).
##
## Colour rule (GDD §5: "they must never read as a threat", kept apart from window cyborgs, GDD
## §9.2): skin tones and plain, lit clothing only, never a hazard colour, never glowing (glow is
## always 0.0 here) and never the cold white or screen-head look of a cyborg. A few archetypes
## (ARCHETYPES) vary height, build and palette; the same poses fit all of them.

enum Clip { IDLE, STARTLED, CHEER }

const BOX := HumanoidPiece.Shape.BOX
const PRISM := HumanoidPiece.Shape.PRISM
const MIRRORED := HumanoidPiece.Placement.MIRRORED

## One archetype: a cache key, the box it's modelled to fill (design_size) and its palette.
class Archetype:
	var name: String
	var design_size: Vector3
	var skin_color: Color
	var hair_color: Color
	var shirt_color: Color
	var pants_color: Color

## A handful of different people (GDD §5, task plan: "a few different citizens"), never a hazard
## hue and never glowing. Heights and builds vary a little; the poses below fit all of them.
static var ARCHETYPES: Array[Archetype] = _build_archetypes()


static func archetype_count() -> int:
	return ARCHETYPES.size()


## The HumanoidParts for one archetype (cached by its name, like PlayerSuit's and CyborgSuit's).
static func parts(index: int) -> HumanoidParts:
	var a: Archetype = ARCHETYPES[index % ARCHETYPES.size()]
	var key: String = "citizen_%s" % a.name
	if _parts_cache.has(key):
		return _parts_cache[key]
	var p := HumanoidParts.new()
	p.cache_key = key
	p.design_size = a.design_size
	var list: Array[HumanoidPiece] = []
	_body(list, a)
	_head(list, a)
	_arms(list, a)
	_legs(list, a)
	p.pieces = list
	_parts_cache[key] = p
	return p


## A plain, unshaded-friendly body material: matte only (glow always 0), so nothing here can be
## mistaken for a cyborg's screen or a hazard's glow.
static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = preload("res://scripts/characters/humanoid_body.gdshader")
	return _material


## The pose at `t` (0–1) through a clip: IDLE loops a gentle weight shift; STARTLED and CHEER play
## once (anticipation, the reaction, a settle back toward idle). MarketCitizen drives `t` at runtime
## from its own baked frame index; the offline tool samples it at each frame's `t` directly.
static func pose_at(clip: Clip, t: float) -> HumanoidPose:
	var out := HumanoidPose.new()
	match clip:
		Clip.IDLE:
			var b: float = 0.5 - 0.5 * cos(TAU * t)
			_blend(out, _idle_a(), _idle_b(), b)
		Clip.STARTLED:
			_schedule(out, _idle_a(), _startle_peak(), _startle_settle(), t)
		Clip.CHEER:
			_schedule(out, _idle_a(), _cheer_peak(), _cheer_settle(), t)
	return out


# --- Keyframes -----------------------------------------------------------------------------

static func _idle_a() -> HumanoidPose:
	var p := HumanoidPose.new()
	for side: int in [-1, 1]:
		p.set_limb(HumanoidPose.UPPER_ARM_R, side, Vector3(6.0, 0.0, 8.0))
		p.set_limb(HumanoidPose.FOREARM_R, side, Vector3(18.0, 0.0, 0.0))
	return p


static func _idle_b() -> HumanoidPose:
	var p := HumanoidPose.new()
	p.set_deg(HumanoidPose.CHEST, Vector3(2.0, 3.0, 1.0))
	p.set_deg(HumanoidPose.HEAD, Vector3(-2.0, -3.0, 0.0))
	for side: int in [-1, 1]:
		p.set_limb(HumanoidPose.UPPER_ARM_R, side, Vector3(8.0, 0.0, 10.0))
		p.set_limb(HumanoidPose.FOREARM_R, side, Vector3(18.0, 0.0, 0.0))
	p.pelvis_offset = Vector3(0.0, 0.006, 0.0)
	return p


## Startled (GDD §5: funny/uplifting, never threatening): both hands fly up near the face and it
## leans back a touch -- a reads-from-the-front jump-scare flinch, not a cower.
static func _startle_peak() -> HumanoidPose:
	var p := HumanoidPose.new()
	p.set_deg(HumanoidPose.CHEST, Vector3(-10.0, 0.0, 0.0))
	p.set_deg(HumanoidPose.HEAD, Vector3(-8.0, 6.0, 0.0))
	for side: int in [-1, 1]:
		p.set_limb(HumanoidPose.UPPER_ARM_R, side, Vector3(-120.0, 0.0, 30.0))
		p.set_limb(HumanoidPose.FOREARM_R, side, Vector3(90.0, 0.0, 0.0))
	p.pelvis_offset = Vector3(0.0, 0.01, 0.0)
	return p


static func _startle_settle() -> HumanoidPose:
	var p := HumanoidPose.new()
	p.set_deg(HumanoidPose.CHEST, Vector3(-3.0, 0.0, 0.0))
	p.set_deg(HumanoidPose.HEAD, Vector3(-2.0, 2.0, 0.0))
	for side: int in [-1, 1]:
		p.set_limb(HumanoidPose.UPPER_ARM_R, side, Vector3(-55.0, 0.0, 20.0))
		p.set_limb(HumanoidPose.FOREARM_R, side, Vector3(55.0, 0.0, 0.0))
	return p


## Cheering: both arms thrown up and out, a small hop (lift, not root_offset, so the rig's own
## grounding never cancels it).
static func _cheer_peak() -> HumanoidPose:
	var p := HumanoidPose.new()
	p.set_deg(HumanoidPose.CHEST, Vector3(3.0, 0.0, 0.0))
	p.set_deg(HumanoidPose.HEAD, Vector3(4.0, 0.0, 0.0))
	for side: int in [-1, 1]:
		p.set_limb(HumanoidPose.UPPER_ARM_R, side, Vector3(-10.0, 0.0, 150.0))
		p.set_limb(HumanoidPose.FOREARM_R, side, Vector3(10.0, 0.0, 0.0))
	p.lift = 0.045
	return p


static func _cheer_settle() -> HumanoidPose:
	var p := HumanoidPose.new()
	p.set_deg(HumanoidPose.CHEST, Vector3(1.0, 0.0, 0.0))
	for side: int in [-1, 1]:
		p.set_limb(HumanoidPose.UPPER_ARM_R, side, Vector3(-5.0, 0.0, 95.0))
		p.set_limb(HumanoidPose.FOREARM_R, side, Vector3(14.0, 0.0, 0.0))
	p.lift = 0.012
	return p


static func _blend(out: HumanoidPose, a: HumanoidPose, b: HumanoidPose, t: float) -> void:
	out.clear_sum()
	out.accumulate(a, 1.0 - t)
	out.accumulate(b, t)
	out.finish(1.0)


## Anticipation (k0) into the reaction's peak (k1) over the first 45% of the clip, then a settle
## (k2) over the rest, so the onset eases in rather than cutting straight to the extreme pose.
static func _schedule(out: HumanoidPose, k0: HumanoidPose, k1: HumanoidPose, k2: HumanoidPose, t: float) -> void:
	if t < 0.45:
		_blend(out, k0, k1, smoothstep(0.0, 0.45, t))
	else:
		_blend(out, k1, k2, smoothstep(0.45, 1.0, t))


# --- Body (simple boxes and prisms: cheap to bake, never seen in 3D at runtime) -------------

static func _body(list: Array[HumanoidPiece], a: Archetype) -> void:
	_add(list, &"pelvis", BOX, Vector3(0.23, 0.16, 0.16), Vector3.ZERO, a.pants_color, {"chamfer": 0.3})
	_add(list, &"chest", BOX, Vector3(0.27, 0.34, 0.18), Vector3(0.0, 0.17, 0.0), a.shirt_color, {"chamfer": 0.3,
		"top_scale": Vector2(0.92, 0.95)})


static func _head(list: Array[HumanoidPiece], a: Archetype) -> void:
	_add(list, &"neck", PRISM, Vector3(0.07, 0.07, 0.07), Vector3.ZERO, a.skin_color, {"sides": 8})
	_add(list, &"head", BOX, Vector3(0.15, 0.17, 0.15), Vector3.ZERO, a.skin_color, {"chamfer": 0.35,
		"top_scale": Vector2(0.9, 0.92)})
	_add(list, &"head", PRISM, Vector3(0.158, 0.085, 0.158), Vector3(0.0, 0.1, 0.004), a.hair_color,
		{"sides": 8, "top_scale": Vector2(0.75, 0.75)})


static func _arms(list: Array[HumanoidPiece], a: Archetype) -> void:
	_add(list, &"upper_arm", PRISM, Vector3(0.08, 0.2, 0.08), Vector3.ZERO, a.shirt_color, {"sides": 8,
		"top_scale": Vector2(0.9, 0.9), "side": MIRRORED})
	_add(list, &"forearm", PRISM, Vector3(0.068, 0.18, 0.068), Vector3.ZERO, a.skin_color, {"sides": 8,
		"top_scale": Vector2(0.88, 0.88), "side": MIRRORED})
	_add(list, &"hand", BOX, Vector3(0.06, 0.08, 0.05), Vector3.ZERO, a.skin_color, {"chamfer": 0.3, "side": MIRRORED})


static func _legs(list: Array[HumanoidPiece], a: Archetype) -> void:
	_add(list, &"thigh", PRISM, Vector3(0.115, 0.3, 0.115), Vector3.ZERO, a.pants_color, {"sides": 8,
		"top_scale": Vector2(1.08, 1.08), "side": MIRRORED})
	_add(list, &"shin", PRISM, Vector3(0.09, 0.3, 0.09), Vector3.ZERO, a.pants_color, {"sides": 8,
		"top_scale": Vector2(1.05, 1.05), "side": MIRRORED})
	_add(list, &"foot", BOX, Vector3(0.09, 0.08, 0.18), Vector3(0.0, -0.01, -0.03), a.hair_color,
		{"chamfer": 0.25, "top_scale": Vector2(0.9, 0.8), "side": MIRRORED})


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


static func _build_archetypes() -> Array[Archetype]:
	var out: Array[Archetype] = []
	var defs: Array = [
		# name, design_size, skin, hair, shirt, pants -- plain, lit colours only; never a hazard hue.
		["vendor", Vector3(0.62, 1.3, 0.54), Color(0.62, 0.45, 0.34), Color(0.14, 0.11, 0.09),
			Color(0.24, 0.4, 0.5), Color(0.34, 0.3, 0.24)],
		["shopper", Vector3(0.56, 1.42, 0.48), Color(0.74, 0.56, 0.44), Color(0.3, 0.22, 0.16),
			Color(0.5, 0.36, 0.3), Color(0.26, 0.28, 0.33)],
		["regular", Vector3(0.68, 1.2, 0.58), Color(0.5, 0.35, 0.26), Color(0.08, 0.08, 0.09),
			Color(0.3, 0.46, 0.34), Color(0.4, 0.33, 0.24)],
	]
	for d: Array in defs:
		var a := Archetype.new()
		a.name = d[0]
		a.design_size = d[1]
		a.skin_color = d[2]
		a.hair_color = d[3]
		a.shirt_color = d[4]
		a.pants_color = d[5]
		out.append(a)
	return out


static var _parts_cache: Dictionary = {}
static var _material: ShaderMaterial
