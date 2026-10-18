class_name OutfitDecals
extends RefCounted
## Printed patches for the runner's outfits (task M2): a camo blotch, a flower on a shirt, a lace across a boot,
## a skull on a back. A decal is a one-sided sheet a few millimetres off the surface it sits on, so a patch costs
## two to eight triangles where a thin box costs twelve, and it is a HumanoidPiece like any other (it merges into
## its segment's mesh: no extra draw call, and `glow` makes it a glowing print). Decals are seen from one side only
## (the face they look toward); on a limb or a coat they follow the piece they are laid on.
##
## Every builder takes the segment's joint space like PlayerOutfit.add(): `at` is the patch's centre (metres at
## design scale), `rot` an Euler turn in degrees as HumanoidPiece.rotation_degrees has it (a roll about the
## patch's own normal is its z, a tilt to follow a slope is its x), `face` the way it looks.

enum Face {
	## Toward the camera behind the runner (+z).
	BACK,
	## The way the runner faces (-z).
	FRONT,
	## Toward the runner's right (+x).
	RIGHT,
	## Toward the runner's left (-x).
	LEFT,
}

## The face of a 4-sided section each side looks toward, as the arc BAND keeps (degrees, 0 = front, 90 = right).
const _ARCS: Array[Vector2] = [Vector2(150.0, 210.0), Vector2(-30.0, 30.0), Vector2(60.0, 120.0), Vector2(-120.0, -60.0)]
## A 4-sided section's face is this much narrower than its diameter (corners at 45 degrees).
const _SIDE: float = 1.4142
## The sheet's depth, so thin that the face is on the offset plane.
const _FLAT: float = 0.001


## A rectangle `width` wide and `height` tall (a patch of camo, a lace, a stripe). `taper` is the width of its
## top relative to its bottom (a trapezoid: a jaw, a pocket flap).
static func quad(list: Array[HumanoidPiece], segment: StringName, at: Vector3, width: float, height: float, color: Color,
		face: Face = Face.BACK, rot: Vector3 = Vector3.ZERO, glow: float = 0.0, taper: float = 1.0,
		side: HumanoidPiece.Placement = HumanoidPiece.Placement.CENTER) -> HumanoidPiece:
	var rings := PackedVector4Array([Vector4(-height * 0.5, 1.0, 1.0, 0.0), Vector4(height * 0.5, taper, 1.0, 0.0)])
	return _sheet(list, segment, at, width, rings, color, face, rot, glow, side)


## A diamond (a leaf, a feather, a lozenge): `width` across its widest point, which is `widest` of the way up
## its `height`.
static func diamond(list: Array[HumanoidPiece], segment: StringName, at: Vector3, width: float, height: float,
		color: Color, face: Face = Face.BACK, rot: Vector3 = Vector3.ZERO, glow: float = 0.0, widest: float = 0.5,
		side: HumanoidPiece.Placement = HumanoidPiece.Placement.CENTER) -> HumanoidPiece:
	var rings := PackedVector4Array([Vector4(-height * 0.5, 0.0, 1.0, 0.0),
		Vector4(-height * 0.5 + height * widest, 1.0, 1.0, 0.0), Vector4(height * 0.5, 0.0, 1.0, 0.0)])
	return _sheet(list, segment, at, width, rings, color, face, rot, glow, side)


## A regular polygon of `sides` sides (a flower, an eye, a skull's crown), `width` by `height`; one triangle per side.
static func disc(list: Array[HumanoidPiece], segment: StringName, at: Vector3, width: float, height: float,
		color: Color, sides: int = 8, face: Face = Face.BACK, rot: Vector3 = Vector3.ZERO, glow: float = 0.0,
		side: HumanoidPiece.Placement = HumanoidPiece.Placement.CENTER) -> HumanoidPiece:
	# A flat cone: its section lies in the segment's x/z plane and its tip is up, so turn it to look toward
	# `face` first, then by `rot`.
	var turn: Vector3 = Vector3(90.0, 0.0, 0.0)
	match face:
		Face.FRONT:
			turn = Vector3(-90.0, 0.0, 0.0)
		Face.RIGHT:
			turn = Vector3(0.0, 0.0, -90.0)
		Face.LEFT:
			turn = Vector3(0.0, 0.0, 90.0)
	var basis: Basis = Basis.from_euler(rot * (PI / 180.0)) * Basis.from_euler(turn * (PI / 180.0))
	var depth_axis: Vector3 = Vector3(width, 0.0, height)
	if face == Face.RIGHT or face == Face.LEFT:
		depth_axis = Vector3(height, 0.0, width)
	var p: HumanoidPiece = PlayerOutfit.piece(segment, PlayerOutfit.BAND, depth_axis, at, color, glow,
		{"sides": sides, "arc": Vector2(-180.0, 180.0), "side": side,
			"profile": PackedVector4Array([Vector4(0.0, 1.0, 1.0, 0.0), Vector4(_FLAT, 0.0, 0.0, 0.0)]),
			"rotation_degrees": basis.get_euler() * (180.0 / PI)})
	list.append(p)
	return p


## A band over part of a PRISM piece (a sleeve, a trouser leg, a boot's shaft): the same section and taper,
## `from` to `to` of the way up it (0 = its bottom, 1 = its top), kept to the faces in `arc` (degrees, 0 = the
## front, 90 = the right, 180 = the back) and laid `inflate` (a fraction of its width) off its surface.
static func on_prism(list: Array[HumanoidPiece], host: HumanoidPiece, arc: Vector2, from: float, to: float,
		color: Color, inflate: float = 0.07, glow: float = 0.0) -> HumanoidPiece:
	var h: float = host.size.y
	var rings := PackedVector4Array()
	for t: float in [from, to]:
		rings.append(Vector4(-h * 0.5 + h * t, lerpf(1.0, host.top_scale.x, t) + inflate,
			lerpf(1.0, host.top_scale.y, t) + inflate, host.top_shift * t))
	var p: HumanoidPiece = PlayerOutfit.piece(host.segment, PlayerOutfit.BAND, host.size, host.offset, color, glow,
		{"sides": host.sides, "section_phase": host.section_phase, "arc": arc, "profile": rings,
			"rotation_degrees": host.rotation_degrees, "side": host.side, "shine": host.shine})
	list.append(p)
	return p


static func _sheet(list: Array[HumanoidPiece], segment: StringName, at: Vector3, width: float, rings: PackedVector4Array,
		color: Color, face: Face, rot: Vector3, glow: float, side: HumanoidPiece.Placement) -> HumanoidPiece:
	var size := Vector3(width * _SIDE, 0.0, _FLAT)
	var sideways: bool = face == Face.RIGHT or face == Face.LEFT
	if sideways:
		# The sheet's width runs along z: swap the rings' width scale onto that axis.
		size = Vector3(_FLAT, 0.0, width * _SIDE)
		var swapped := PackedVector4Array()
		for r: Vector4 in rings:
			swapped.append(Vector4(r.x, r.z, r.y, r.w))
		rings = swapped
	var p: HumanoidPiece = PlayerOutfit.piece(segment, PlayerOutfit.BAND, size, at, color, glow,
		{"sides": 4, "arc": _ARCS[face], "profile": rings, "rotation_degrees": rot, "side": side})
	list.append(p)
	return p
