extends RefCounted
## The Dead Zone's cyborg (GDD §9.2, "Zone variants": "the base, burned out"; brief
## docs/art/BRIEF_CYBORG_GANGSTER.md): the Neon City's ragged gangster and its TV head
## (CyborgSuit.base_look()), caught in the fires that blackened the city (GDD §5, Zone 5). Every
## piece is the base's, darkened by soot and faded; ash has settled on the TV's top, its shoulders,
## the backpack and the boots; scorch marks blacken the casing, the vest and the pants; it is torn
## further (the hoodie's hem shredded into long strips, the left sleeve ripped open, a burn hole in
## the vest, a torn knee); and its screen flickers and is cracked. Nothing on it glows but what glows
## on every cyborg (the face, the charge-up, a host's purple): no embers (GDD §5 keeps the zone's
## fires minimal and in the background). Its hosts wear the base's veins (CyborgSuit.HOST_SET).
## The ash is the lightest thing on it, so its silhouette still reads on the zone's dark ground.
## The damage is flat patches (CyborgSuit.patch, two triangles each), so it costs few triangles.
## DESIGN-TBD (docs/questions/p3.md 6): how burned, and the screen's flicker and crack.

const MIRRORED := HumanoidPiece.Placement.MIRRORED
const RIGHT := HumanoidPiece.Placement.RIGHT
const LEFT := HumanoidPiece.Placement.LEFT

## Soot over the base's colours: each keeps SOOT_VALUE of its brightness and SOOT_SATURATION of its
## colour, then leans toward SOOT (a warm black) by SOOT_MIX.
const SOOT := Color(0.1, 0.095, 0.09)
const SOOT_VALUE: float = 0.62
const SOOT_SATURATION: float = 0.45
const SOOT_MIX: float = 0.12
## The TV's casing keeps more of its grey (charred, not black), so the head still reads.
const CASING_VALUE: float = 0.8
## Ash (pale grey, the lightest colour on it), fresh scorch (near black) and charred cloth.
const ASH := Color(0.56, 0.55, 0.53)
const ASH_DARK := Color(0.44, 0.43, 0.41)
const SCORCH := Color(0.07, 0.065, 0.06)
const CHAR := Color(0.14, 0.13, 0.12)


static func pieces() -> Array[HumanoidPiece]:
	var list: Array[HumanoidPiece] = []
	for piece: HumanoidPiece in CyborgSuit.base_look():
		var burned := piece.duplicate() as HumanoidPiece
		if burned.glow == 0.0:
			burned.color = sooted(burned.color, piece.segment == &"head")
		list.append(burned)
	_ash(list)
	_scorch(list)
	_tears(list)
	return list


## Its hosts wear the base's veins (the body is the base's).
static func veins() -> Array[HumanoidPiece]:
	return []


## A flickering, cracked screen with a little more static (Reduced flashing turns the flicker into a
## steady dimming, cyborg_body.gdshader).
static func material_params() -> Dictionary:
	return {&"flicker": 1.0, &"crack": 1.0, &"static_amount": 0.22}


## A base colour under soot: darker, faded, a little warmer.
static func sooted(c: Color, casing: bool = false) -> Color:
	var faded := Color.from_hsv(c.h, c.s * SOOT_SATURATION, c.v * (CASING_VALUE if casing else SOOT_VALUE))
	return faded.lerp(SOOT, SOOT_MIX)


## Ash on what faces up: the TV's top and the tube behind it, the shoulders, the backpack's lid, the
## top of the cyber arm's shoulder cap and the boots' toes.
static func _ash(list: Array[HumanoidPiece]) -> void:
	var top: float = CyborgSuit.TV_CENTER.y + CyborgSuit.TV_SIZE.y * 0.5
	var up := CyborgSuit.facing(Vector3.UP)
	CyborgSuit.patch(list, &"head", Vector3(0.015, top + 0.002, -0.082), Vector2(0.36, 0.11), ASH,
		CyborgSuit.facing(Vector3.UP, Vector3(1.0, 0.0, 0.1)))
	CyborgSuit.patch(list, &"head", Vector3(0.0, 0.249, 0.05), Vector2(0.24, 0.13), ASH_DARK,
		CyborgSuit.facing(Vector3(0.0, 0.97, 0.24)))
	# The shoulders of the vest (sloping down and out) and the backpack's lid.
	CyborgSuit.patch(list, &"chest", Vector3(0.165, 0.394, -0.01), Vector2(0.1, 0.1), ASH,
		CyborgSuit.facing(Vector3(0.5, 0.86, 0.0), Vector3(0.0, 0.0, 1.0)), 1.0, MIRRORED)
	CyborgSuit.patch(list, &"chest", Vector3(0.0, 0.389, 0.165), Vector2(0.22, 0.11), ASH, up)
	CyborgSuit.patch(list, &"upper_arm", Vector3(0.012, 0.052, 0.0), Vector2(0.09, 0.09), ASH_DARK, up, 1.0, RIGHT)
	# The boots' toes.
	CyborgSuit.patch(list, &"shin", Vector3(0.0, -0.232, -0.1), Vector2(0.08, 0.07), ASH_DARK,
		CyborgSuit.facing(Vector3(0.0, 0.9, -0.43)))


## Scorch marks: the TV's casing (its left side and the chin), the vest's front, the backpack, the
## left shin and the right thigh's back.
static func _scorch(list: Array[HumanoidPiece]) -> void:
	var half_w: float = CyborgSuit.TV_SIZE.x * 0.5
	CyborgSuit.patch(list, &"head", Vector3(-half_w - 0.002, 0.11, -0.075), Vector2(0.11, 0.16), SCORCH,
		CyborgSuit.facing(Vector3.LEFT, Vector3.BACK) + Vector3(0.0, 0.0, 14.0))
	CyborgSuit.patch(list, &"head", Vector3(-0.09, 0.015, -0.1585), Vector2(0.14, 0.035), SCORCH)
	CyborgSuit.patch(list, &"chest", Vector3(0.07, 0.13, -0.088), Vector2(0.06, 0.11), SCORCH,
		CyborgSuit.facing(Vector3(0.376, 0.0, -0.926), Vector3(0.926, 0.0, 0.376)))
	CyborgSuit.patch(list, &"chest", Vector3(-0.035, 0.28, 0.2265), Vector2(0.1, 0.09), SCORCH,
		CyborgSuit.facing(Vector3.BACK, Vector3(-1.0, 0.5, 0.0)))
	CyborgSuit.patch(list, &"shin", Vector3(0.008, -0.07, -0.0595), Vector2(0.055, 0.09), CHAR,
		Vector3.ZERO, 1.0, LEFT)
	CyborgSuit.patch(list, &"thigh", Vector3(0.0, -0.2, 0.0625), Vector2(0.06, 0.12), CHAR,
		CyborgSuit.facing(Vector3.BACK), 1.0, RIGHT)


## Torn further: long shredded strips round the hoodie's hem, the left sleeve ripped open over the
## elbow, a burn hole in the vest's back, and the right knee torn through.
static func _tears(list: Array[HumanoidPiece]) -> void:
	var hem: Vector4 = CyborgSuit.TORSO_RINGS[0]
	var r := Vector2(CyborgSuit.TORSO_HALF.x * hem.y, CyborgSuit.TORSO_HALF.y * hem.z)
	var hoodie: Color = sooted(CyborgSuit.HOODIE_FRAYED)
	for strip: Vector3 in [Vector3(-140.0, 0.05, 0.12), Vector3(-80.0, 0.045, 0.09), Vector3(-35.0, 0.05, 0.11),
			Vector3(15.0, 0.035, 0.08), Vector3(55.0, 0.045, 0.13), Vector3(125.0, 0.05, 0.1),
			Vector3(175.0, 0.05, 0.14)]:
		# A long strip hanging to a point from the hem, lying on the hoodie (angle 0 = the front).
		var a: float = deg_to_rad(strip.x)
		var out := Vector3(sin(a), 0.0, -cos(a))
		var at := Vector3(out.x * (r.x + 0.004), hem.x - strip.z * 0.5 + 0.01, out.z * (r.y + 0.004))
		CyborgSuit.patch(list, &"chest", at, Vector2(strip.y, strip.z), hoodie,
			CyborgSuit.facing(out, Vector3(cos(a), 0.0, sin(a))), 0.0)
	# The left sleeve, ripped open over the elbow on its outer side: a dark hole and a flap hanging
	# from its edge.
	var outer_back := Vector3(0.866, 0.0, 0.5)
	CyborgSuit.patch(list, &"forearm", Vector3(0.03, -0.035, 0.018), Vector2(0.035, 0.06), CHAR,
		CyborgSuit.facing(outer_back, Vector3(-0.5, 0.0, 0.866)), 1.0, LEFT)
	CyborgSuit.patch(list, &"forearm", Vector3(0.033, -0.085, 0.02), Vector2(0.03, 0.06), hoodie,
		CyborgSuit.facing(outer_back, Vector3(-0.5, 0.0, 0.866)), 0.2, LEFT)
	# A burn hole in the vest's back (below the backpack) inside a charred rim.
	CyborgSuit.patch(list, &"chest", Vector3(0.055, 0.02, 0.1), Vector2(0.09, 0.07), CHAR, CyborgSuit.facing(Vector3.BACK))
	CyborgSuit.patch(list, &"chest", Vector3(0.055, 0.02, 0.1015), Vector2(0.06, 0.045), SCORCH,
		CyborgSuit.facing(Vector3.BACK) + Vector3(0.0, 0.0, 15.0))
	# The right knee torn through, with a frayed edge above the hole.
	CyborgSuit.patch(list, &"thigh", Vector3(0.0, -0.305, -0.0625), Vector2(0.055, 0.05), SCORCH, Vector3.ZERO, 1.0, RIGHT)
	CyborgSuit.patch(list, &"thigh", Vector3(0.0, -0.278, -0.0635), Vector2(0.065, 0.014), hoodie, Vector3.ZERO, 0.6, RIGHT)
