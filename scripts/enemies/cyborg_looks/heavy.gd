extends RefCounted
## The Heavy Cyborg's armour (GDD §9.16, proposed: "the zone's cyborg variant ... with heavy armour plates over
## them"): an attachment set worn on top of its zone's look (CyborgSuit.heavy_set), merged into the same segment
## meshes, so a Heavy Cyborg costs a cyborg's draw calls plus its gatling's (HeavyCyborgBody). A breastplate with a
## ridge and two belly bands, a tasset over the hips, pauldrons and plates down the outside of the upper arms,
## bracers on the forearms, plates on the thighs and knee and shin guards; and a coupling over the cyber arm's
## cannon, where it plugs into the gatling's back (the cannon's emitter ring stays inside it: on a Heavy Cyborg
## only the face and the gatling glow). HeavyCyborgBody bulks the segments out under it (their meshes scaled), so
## the plates sit a little outside every look's clothes at design scale.
## Colours (GDD §9.2's rules: dull, unlit metal; gold only as unlit ornament on the looks that wear it): each look's
## plates in its own metal (PALETTES), the Dead Zone's and the Ice Lab's sooted as the rest of that look.
## DESIGN-TBD (docs/questions/s1.md): the plates' shapes and colours.

const BurnedLook = preload("res://scripts/enemies/cyborg_looks/burned.gd")
const BOX := HumanoidPiece.Shape.BOX
const PRISM := HumanoidPiece.Shape.PRISM
const MIRRORED := HumanoidPiece.Placement.MIRRORED
const RIGHT := HumanoidPiece.Placement.RIGHT
const CENTER := HumanoidPiece.Placement.CENTER

## Each look's armour: its plates, their darker bands, the rims and ridges (unlit), and how polished the rims are.
const PALETTES: Dictionary = {
	&"base": {"plate": Color(0.27, 0.28, 0.29), "dark": Color(0.19, 0.2, 0.21), "rim": Color(0.44, 0.44, 0.43),
		"rust": Color(0.37, 0.25, 0.18), "shine": 0.25},
	&"brute": {"plate": Color(0.3, 0.31, 0.28), "dark": Color(0.22, 0.23, 0.21), "rim": Color(0.38, 0.3, 0.18),
		"rust": Color(0.37, 0.25, 0.18), "shine": 0.3},
	&"casino": {"plate": Color(0.14, 0.145, 0.15), "dark": Color(0.08, 0.08, 0.09), "rim": Color(0.7, 0.56, 0.32),
		"rust": Color(0.45, 0.36, 0.2), "shine": 0.6},
	&"vr_runner": {"plate": Color(0.16, 0.17, 0.19), "dark": Color(0.1, 0.105, 0.12), "rim": Color(0.6, 0.62, 0.66),
		"rust": Color(0.3, 0.31, 0.33), "shine": 0.6},
	&"golden": {"plate": Color(0.74, 0.71, 0.65), "dark": Color(0.6, 0.57, 0.51), "rim": Color(0.74, 0.6, 0.35),
		"rust": Color(0.52, 0.42, 0.24), "shine": 0.55},
}


## The armour for `look` (a CyborgSuit look name).
static func pieces(look: StringName) -> Array[HumanoidPiece]:
	var burned: bool = look == CyborgSuit.BURNED
	var palette: Dictionary = PALETTES.get(CyborgSuit.BASE if burned else look, PALETTES[CyborgSuit.BASE])
	var plate: Color = palette["plate"]
	var dark: Color = palette["dark"]
	var rim: Color = palette["rim"]
	var rust: Color = palette["rust"]
	if burned:
		plate = BurnedLook.sooted(plate)
		dark = BurnedLook.sooted(dark)
		rim = BurnedLook.sooted(rim)
		rust = BurnedLook.sooted(rust)
	var shine: float = palette["shine"]
	var dull := {"shine": 0.2}
	var polished := {"shine": shine}
	var list: Array[HumanoidPiece] = []
	# The breastplate over the vest (chest joint space: the torso runs from its hem at -0.1 to the neck at 0.42), a
	# ridge down its middle, two bands over the belly below it.
	CyborgSuit.add(list, &"chest", BOX, Vector3(0.3, 0.25, 0.05), Vector3(0.0, 0.25, -0.118), plate, 0.0,
		CyborgSuit.merged(dull, {"side": CENTER, "chamfer": 0.3, "top_scale": Vector2(1.18, 1.0), "top_shift": 0.01}))
	CyborgSuit.add(list, &"chest", BOX, Vector3(0.05, 0.22, 0.02), Vector3(0.0, 0.25, -0.147), rim, 0.0,
		CyborgSuit.merged(polished, {"side": CENTER, "chamfer": 0.3}))
	for k: int in 2:
		CyborgSuit.add(list, &"chest", BOX, Vector3(0.25 - 0.02 * k, 0.055, 0.04), Vector3(0.0, 0.085 - 0.066 * k, -0.108 + 0.004 * k),
			dark, 0.0, CyborgSuit.merged(dull, {"side": CENTER, "chamfer": 0.3}))
	CyborgSuit.add(list, &"chest", BOX, Vector3(0.06, 0.04, 0.012), Vector3(0.09, 0.3, -0.146), rust, 0.0,
		{"side": CENTER, "rotation_degrees": Vector3(0.0, 0.0, 12.0)})
	# The tasset over the hips: a front plate and one down each side.
	CyborgSuit.add(list, &"pelvis", BOX, Vector3(0.26, 0.13, 0.04), Vector3(0.0, -0.085, -0.106), plate, 0.0,
		CyborgSuit.merged(dull, {"side": CENTER, "chamfer": 0.25, "top_scale": Vector2(0.92, 1.0)}))
	CyborgSuit.add(list, &"pelvis", BOX, Vector3(0.035, 0.14, 0.13), Vector3(0.13, -0.09, 0.0), dark, 0.0,
		CyborgSuit.merged(dull, {"side": MIRRORED, "chamfer": 0.2}))
	# The pauldrons over the shoulders, a rim along their edge, and a plate down the outside of the upper arm.
	CyborgSuit.add(list, &"upper_arm", BOX, Vector3(0.145, 0.09, 0.155), Vector3(0.03, -0.035, 0.0), plate, 0.0,
		CyborgSuit.merged(dull, {"side": MIRRORED, "chamfer": 0.3, "top_scale": Vector2(0.72, 0.8)}))
	CyborgSuit.add(list, &"upper_arm", BOX, Vector3(0.15, 0.02, 0.16), Vector3(0.03, -0.078, 0.0), rim, 0.0,
		CyborgSuit.merged(polished, {"side": MIRRORED, "chamfer": 0.3}))
	CyborgSuit.add(list, &"upper_arm", BOX, Vector3(0.03, 0.13, 0.09), Vector3(0.07, -0.16, 0.0), dark, 0.0,
		CyborgSuit.merged(dull, {"side": MIRRORED, "chamfer": 0.2}))
	# Bracers on both forearms, and the coupling over the cyber arm's cannon (its ring, at -0.405, inside it).
	CyborgSuit.add(list, &"forearm", PRISM, Vector3(0.15, 0.13, 0.15), Vector3(0.0, -0.15, 0.0), plate, 0.0,
		CyborgSuit.merged(dull, {"side": MIRRORED, "sides": 8, "top_scale": Vector2(1.1, 1.1)}))
	CyborgSuit.add(list, &"forearm", PRISM, Vector3(0.17, 0.085, 0.17), Vector3(0.0, -0.4, 0.0), dark, 0.0,
		CyborgSuit.merged(dull, {"side": RIGHT, "sides": 8}))
	CyborgSuit.add(list, &"forearm", PRISM, Vector3(0.175, 0.016, 0.175), Vector3(0.0, -0.36, 0.0), rim, 0.0,
		CyborgSuit.merged(polished, {"side": RIGHT, "sides": 8}))
	# Plates down the front of the thighs, knee caps and shin guards.
	CyborgSuit.add(list, &"thigh", BOX, Vector3(0.13, 0.17, 0.03), Vector3(0.0, -0.13, -0.076), plate, 0.0,
		CyborgSuit.merged(dull, {"side": MIRRORED, "chamfer": 0.25, "top_scale": Vector2(1.08, 1.0)}))
	CyborgSuit.add(list, &"shin", BOX, Vector3(0.11, 0.075, 0.045), Vector3(0.0, -0.005, -0.075), rim, 0.0,
		CyborgSuit.merged(polished, {"side": MIRRORED, "chamfer": 0.3}))
	CyborgSuit.add(list, &"shin", BOX, Vector3(0.1, 0.13, 0.03), Vector3(0.0, -0.105, -0.072), plate, 0.0,
		CyborgSuit.merged(dull, {"side": MIRRORED, "chamfer": 0.25, "top_scale": Vector2(1.06, 1.0)}))
	return list
