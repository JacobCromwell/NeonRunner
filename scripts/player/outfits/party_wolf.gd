extends PlayerOutfit
## Party Wolf, the fifth cosmetic (GDD §8, "Cosmetics"; sold for 5,000 credits until promoting the game, which is to
## win it, exists; brief docs/art/BRIEF_OUTFIT_PARTY_WOLF.md, after the owner's concept sheet
## docs/art/reference/outfit_party_wolf.webp): a neon rave outfit with a wolf mask on Razor Echo's rig. The mask covers
## his face (this is the one outfit that covers his head): grey fur with neon purple and cyan markings, pointed ears,
## bared teeth and a glowing pink eyepiece over the left eye, his spiky black hair showing behind it. A long purple
## coat covered in neon graffiti (cyan, pink, green and yellow tags) with a grey faux-fur collar and cuffs, a dark
## T-shirt with a glowing howling-wolf-and-moon print under a pink chest rig, a glowing purple and cyan rave cyber-arm on
## the left (it replaces Echo's gold one), a studded belt with hanging glow sticks and a grey wolf tail, rave bracelets
## and fingerless gloves, dark pants with glowing knee pads and pink straps, and neon-laced combat boots.
## On the back, what the gameplay camera sees: the neon wolf in shades across the shoulders, "PARTY WOLF" in words
## (two lines of block letters, PARTY in pink and WOLF in cyan, built of flat quads: two triangles a stroke, so the
## whole sign is about 60 triangles and no texture or extra draw call), the fur collar, the tail and the rave arm.
##
## Cheap by design (the brief's budget): the graffiti, the sign and the neon wolf are flat one-sided quads in vertex
## colour (`flat`, two triangles each), not separate meshes, so the outfit is the same draw calls as Echo's.
##
## Glows (free of the colour rule, owner, October 18, 2026: they stay as drawn): thin and soft, so bloom doesn't merge
## the back into one blur. Every glow rides in the mesh, so they power down on death like Echo's conduits, take the dash
## brightening and sit under the invulnerability tint.
##
## Left out on purpose: the neon katana and its sheath and the pistol at the hip (no outfit carries a weapon: nothing on
## the runner may look like a power-up).
## The armor power-up is refitted too (`attachment_overrides`): bright silver-blue plates over the fur, so whether armor is
## up reads against it. The other power-ups are Echo's sets.
## DESIGN-TBD (docs/questions/m3.md, 1): the armor refit, whether it stays.
## DESIGN-TBD (docs/questions/m3.md, 2): "PARTY WOLF" kept in words (the brief's proposal, followed).
## DESIGN-TBD (docs/questions/m3.md, 5): the graffiti, the markings and the shirt print are simplified from the sheet.
## DESIGN-TBD (docs/questions/m3.md, 6): the sign's colours and size (about a pixel a cell from the game camera).
## DESIGN-TBD (docs/questions/m3.md, 7): the tail's carabiner and banding. (8): the mask's expression.

## The purple coat and its shade, the dark clothes, and the grey fur.
const PURPLE := Color(0.36, 0.13, 0.66)
const PURPLE_DARK := Color(0.23, 0.08, 0.44)
const SHIRT := Color(0.07, 0.07, 0.1)
const PANTS := Color(0.11, 0.09, 0.16)
const BOOT := Color(0.08, 0.08, 0.1)
const SOLE := Color(0.05, 0.04, 0.07)
const FUR := Color(0.44, 0.44, 0.51)
const FUR_DARK := Color(0.28, 0.28, 0.35)
const FUR_LIGHT := Color(0.6, 0.6, 0.68)
## The armor power-up's plates on this outfit: a bright cool silver-blue, lighter than the fur (its edge glow is Echo's,
## PlayerSuit.ARMOR_EDGE).
## DESIGN-TBD (docs/questions/m3.md, 1): the refit itself.
const ARMOR_PLATE := Color(0.76, 0.84, 0.95)
const TEETH := Color(0.95, 0.95, 0.98)
const NOSE := Color(0.06, 0.05, 0.08)
const STRAP := Color(0.95, 0.22, 0.62)
## The neon, as drawn: cyan, pink, green, yellow and a purple for the markings.
const CYAN := Color(0.2, 0.95, 1.0)
const PINK := Color(1.0, 0.28, 0.72)
const GREEN := Color(0.45, 1.0, 0.28)
const YELLOW := Color(1.0, 0.92, 0.22)
const VIOLET := Color(0.7, 0.35, 1.0)
## Glow amounts (HumanoidPiece.glow): thin lines, small lamps and the eyepiece. With the body material's glow albedo the
## trim shines by its own light at about the bloom threshold: soft, and the same lit or in the dark. The brightest
## (a bright cyan while dashing) stays under test_outfit_party_wolf's cap.
const LINE_GLOW: float = 0.36
const SOFT_GLOW: float = 0.26
const LAMP_GLOW: float = 0.39
const EYE_GLOW: float = 0.39

## The coat's back surface at chest height `y` leans in above the waist (as Echo's coat): what the neon wolf and the sign
## sit on (chest joint space).
const BACK_Z: float = 0.108
const BACK_LEAN: float = 0.067

## The skirt, as Echo's: the waist ring the panels hang from (pelvis joint space), its size and flare.
const SKIRT_HINGE_Y: float = 0.03
const SKIRT_HALF := Vector2(0.152, 0.118)
const SKIRT_LENGTH: float = 0.46
const SKIRT_FLARE: float = 1.3

## The sign's block letters: one cell is this big, and each letter is five cells high and three wide (the W five).
const CELL: float = 0.0092
## Strokes of each letter in cells (x, y from the top left, width, height).
const GLYPHS := {
	"P": [Rect2(0, 0, 3, 1), Rect2(0, 1, 1, 4), Rect2(2, 1, 1, 1), Rect2(1, 2, 2, 1)],
	"A": [Rect2(0, 0, 3, 1), Rect2(0, 1, 1, 4), Rect2(2, 1, 1, 4), Rect2(1, 2, 1, 1)],
	"R": [Rect2(0, 0, 3, 1), Rect2(0, 1, 1, 4), Rect2(2, 1, 1, 1), Rect2(1, 2, 1, 1), Rect2(2, 3, 1, 2)],
	"T": [Rect2(0, 0, 3, 1), Rect2(1, 1, 1, 4)],
	"Y": [Rect2(0, 0, 1, 2), Rect2(2, 0, 1, 2), Rect2(1, 2, 1, 3)],
	"W": [Rect2(0, 0, 1, 4), Rect2(4, 0, 1, 4), Rect2(2, 2, 1, 2), Rect2(1, 4, 1, 1), Rect2(3, 4, 1, 1)],
	"O": [Rect2(0, 0, 3, 1), Rect2(0, 1, 1, 3), Rect2(2, 1, 1, 3), Rect2(0, 4, 3, 1)],
	"L": [Rect2(0, 0, 1, 5), Rect2(1, 4, 2, 1)],
	"F": [Rect2(0, 0, 3, 1), Rect2(0, 1, 1, 4), Rect2(1, 2, 1, 1)],
}


func body_pieces() -> Array[HumanoidPiece]:
	var list: Array[HumanoidPiece] = []
	_belt(list)
	_torso(list)
	_front(list)
	_back(list)
	_fur(list)
	_right_arm(list)
	_cyber_arm(list)
	_legs(list)
	return list


## Echo's hair behind the mask: his neck, skull and spiky hair (the face's details are boxes on the head, and the mask
## covers them), and the wolf mask over his face.
func head_pieces() -> Array[HumanoidPiece]:
	var list: Array[HumanoidPiece] = []
	for kept: HumanoidPiece in super():
		if not (kept.segment == &"head" and kept.shape == BOX):
			list.append(kept)
	_mask(list)
	return list


func panels() -> Array[HumanoidPanel]:
	var out: Array[HumanoidPanel] = []
	for side: int in [1, -1]:
		out.append(_skirt_panel(side, true))
		out.append(_skirt_panel(side, false))
	out.append(_tail())
	return out


## The armor power-up refitted to the grey fur: Echo's plates in a bright silver-blue, lighter than his steel (which is
## close to the fur's grey, so it reads less against the mantle) and with their pale glowing edge, standing proud of the
## mantle over the shoulders, over the pink rig in front, and across the back below the mantle (the mantle covers the
## spot Echo's yoke sits at).
## DESIGN-TBD (docs/questions/m3.md, 1): whether the armor is refitted on the outfits at all.
func attachment_overrides() -> Dictionary:
	var list: Array[HumanoidPiece] = []
	var plate := {"shine": 0.5}
	add(list, &"upper_arm", BOX, Vector3(0.17, 0.038, 0.19), Vector3(0.03, 0.062, 0.0), ARMOR_PLATE, 0.0,
		merged(plate, {"top_scale": Vector2(0.7, 0.8)}))
	add(list, &"upper_arm", BOX, Vector3(0.016, 0.014, 0.17), Vector3(0.108, 0.048, 0.0), PlayerSuit.ARMOR_EDGE, 0.6)
	add(list, &"chest", BOX, Vector3(0.17, 0.13, 0.024), Vector3(0.0, 0.15, -0.14), ARMOR_PLATE, 0.0,
		merged(plate, {"top_scale": Vector2(1.08, 1.0)}))
	add(list, &"chest", BOX, Vector3(0.15, 0.012, 0.01), Vector3(0.0, 0.214, -0.153), PlayerSuit.ARMOR_EDGE, 0.6)
	add(list, &"chest", BOX, Vector3(0.29, 0.044, 0.026), Vector3(0.0, 0.2, 0.113), ARMOR_PLATE, 0.0, plate)
	add(list, &"chest", BOX, Vector3(0.27, 0.01, 0.01), Vector3(0.0, 0.176, 0.118), PlayerSuit.ARMOR_EDGE, 0.6)
	return {&"armor": list}


# --- The mask -------------------------------------------------------------------------

## The cyber wolf mask (head joint space; -z is the way he faces): a fur brow over the eyes, the snout and nose, the lower
## jaw with its bared teeth, cheek ruffs, two pointed ears, the pink eyepiece over his left eye (-x), a cyan right eye and
## the neon markings.
## DESIGN-TBD (docs/questions/m3.md, 8): the mask's expression, blocky at this budget; (5): its markings.
func _mask(list: Array[HumanoidPiece]) -> void:
	# The brow: a fur plate over the eyes, a little wider than his face.
	add(list, &"head", BOX, Vector3(0.18, 0.095, 0.085), Vector3(0.0, 0.09, -0.066), FUR, 0.0,
		{"chamfer": 0.3, "top_scale": Vector2(1.0, 0.9)})
	# The snout, tapering to the black nose, and the shorter jaw under it.
	add(list, &"head", BOX, Vector3(0.092, 0.07, 0.13), Vector3(0.0, 0.046, -0.158), FUR, 0.0, {"top_scale": Vector2(0.74, 0.8)})
	add(list, &"head", BOX, Vector3(0.042, 0.03, 0.03), Vector3(0.0, 0.076, -0.228), NOSE)
	add(list, &"head", BOX, Vector3(0.062, 0.02, 0.08), Vector3(0.0, 0.004, -0.15), NOSE)
	add(list, &"head", BOX, Vector3(0.076, 0.026, 0.09), Vector3(0.0, -0.016, -0.14), FUR_DARK)
	# Bared teeth: two fangs hanging in front of the jaw and two small ones rising from it.
	for x: float in [-0.03, 0.03]:
		add(list, &"head", PRISM, Vector3(0.018, 0.038, 0.018), Vector3(x, -0.004, -0.212), TEETH, 0.0,
			{"sides": 3, "top_scale": Vector2.ZERO, "rotation_degrees": Vector3(180.0, 0.0, 0.0)})
		add(list, &"head", PRISM, Vector3(0.014, 0.03, 0.014), Vector3(x * 0.8, 0.0, -0.19), TEETH, 0.0,
			{"sides": 3, "top_scale": Vector2.ZERO})
	# Cheek tufts and the ears, each ear with a violet lining.
	add(list, &"head", BOX, Vector3(0.04, 0.06, 0.07), Vector3(0.088, 0.03, -0.05), FUR_LIGHT, 0.0,
		{"side": MIRRORED, "top_scale": Vector2(1.0, 0.3), "rotation_degrees": Vector3(0.0, 0.0, -12.0)})
	add(list, &"head", PRISM, Vector3(0.062, 0.105, 0.05), Vector3(0.066, 0.195, 0.005), FUR, 0.0,
		{"side": MIRRORED, "sides": 4, "top_scale": Vector2.ZERO, "rotation_degrees": Vector3(-8.0, 0.0, -10.0)})
	add(list, &"head", PRISM, Vector3(0.03, 0.07, 0.026), Vector3(0.064, 0.19, -0.016), VIOLET, SOFT_GLOW,
		{"side": MIRRORED, "sides": 3, "top_scale": Vector2.ZERO, "rotation_degrees": Vector3(-8.0, 0.0, -10.0)})
	# The eyes: the pink eyepiece over the left (the wearer's, so -x) and a cyan wolf eye on the right.
	add(list, &"head", BOX, Vector3(0.06, 0.038, 0.016), Vector3(-0.04, 0.092, -0.112), PINK, EYE_GLOW)
	add(list, &"head", BOX, Vector3(0.026, 0.016, 0.012), Vector3(0.042, 0.092, -0.11), CYAN, EYE_GLOW)
	# Neon markings on the brow: a cyan line across it and a violet stripe slanting down each side.
	flat(list, &"head", 0.1, 0.008, Vector3(0.0, 0.132, -0.1105), CYAN, SOFT_GLOW, 0.0, true)
	for side: float in [-1.0, 1.0]:
		flat(list, &"head", 0.012, 0.05, Vector3(side * 0.07, 0.085, -0.1105), VIOLET, SOFT_GLOW, side * 18.0, true)


# --- Pelvis, torso ----------------------------------------------------------------------

## Dark pants over the hips, the studded belt with its buckle, and the glow sticks hanging from it.
func _belt(list: Array[HumanoidPiece]) -> void:
	add(list, &"pelvis", BOX, Vector3(0.245, 0.15, 0.175), Vector3(0.0, -0.045, 0.005), PANTS, 0.0,
		{"top_scale": Vector2(1.04, 1.04)})
	add(list, &"pelvis", LATHE, Vector3(0.325, 0.0, 0.25), Vector3(0.0, SKIRT_HINGE_Y, 0.005), SHIRT, 0.0,
		{"sides": 8, "profile": PackedVector4Array([Vector4(-0.035, 1.0, 1.0, 0.0), Vector4(0.03, 1.0, 1.0, 0.0)])})
	add(list, &"pelvis", BOX, Vector3(0.05, 0.04, 0.014), Vector3(0.0, SKIRT_HINGE_Y, -0.127), CYAN, LAMP_GLOW)
	# The glow sticks: four thin lamps hanging from the belt at the front right (+x, the wearer's right, as the sheet draws
	# them; the tail is on his left).
	var colors: Array[Color] = [GREEN, PINK, YELLOW, CYAN]
	for k: int in 4:
		pipe(list, &"pelvis", Vector3(0.05 + 0.018 * k, SKIRT_HINGE_Y - 0.03, -0.135),
			Vector3(0.05 + 0.018 * k + 0.004 * k, SKIRT_HINGE_Y - 0.15 - 0.012 * (k % 2), -0.138), 0.012, Vector3.FORWARD,
			colors[k], LAMP_GLOW)


## The coat's body in two tiers, the dark lapels, and the dark collar under the fur.
func _torso(list: Array[HumanoidPiece]) -> void:
	add(list, &"chest", BOX, Vector3(0.28, 0.19, 0.2), Vector3(0.0, 0.02, 0.008), PURPLE, 0.0,
		{"chamfer": 0.4, "top_scale": Vector2(1.07, 1.0)})
	add(list, &"chest", BOX, Vector3(0.3, 0.15, 0.2), Vector3(0.0, 0.19, 0.008), PURPLE, 0.0,
		{"chamfer": 0.45, "top_scale": Vector2(0.97, 0.9)})
	add(list, &"chest", BOX, Vector3(0.055, 0.17, 0.014), Vector3(0.07, 0.19, -0.106), PURPLE_DARK, 0.0,
		{"side": MIRRORED, "top_scale": Vector2(1.3, 1.0), "rotation_degrees": Vector3(0.0, 0.0, -12.0)})


## The front, in the open coat: the dark T-shirt with the glowing howling-wolf-and-moon print, under the pink chest rig
## with its straps and a cyan buckle.
## DESIGN-TBD (docs/questions/m3.md, 5): the print is a cyan octagon with a small dark wolf, simplified from the sheet.
func _front(list: Array[HumanoidPiece]) -> void:
	add(list, &"chest", BOX, Vector3(0.15, 0.25, 0.03), Vector3(0.0, 0.1, -0.097), SHIRT, 0.0, {"top_scale": Vector2(1.06, 1.0)})
	# The print: a cyan moon (two squares, one turned) with the wolf standing on it, howling.
	flat(list, &"chest", 0.06, 0.06, Vector3(0.0, 0.17, -0.1145), CYAN, SOFT_GLOW, 0.0, true)
	flat(list, &"chest", 0.06, 0.06, Vector3(0.0, 0.17, -0.115), CYAN, SOFT_GLOW, 45.0, true)
	flat(list, &"chest", 0.026, 0.026, Vector3(0.0, 0.154, -0.1165), SHIRT, 0.0, 0.0, true)
	flat(list, &"chest", 0.012, 0.03, Vector3(0.004, 0.18, -0.1165), SHIRT, 0.0, 0.0, true)
	# The pink chest rig: a plate over the belly with a cyan buckle, and the straps over the shoulders.
	add(list, &"chest", BOX, Vector3(0.13, 0.1, 0.02), Vector3(0.0, 0.04, -0.116), STRAP, 0.0, {"top_scale": Vector2(1.0, 0.95)})
	add(list, &"chest", BOX, Vector3(0.03, 0.026, 0.01), Vector3(0.0, 0.04, -0.13), CYAN, LAMP_GLOW)
	for side: float in [-1.0, 1.0]:
		flat(list, &"chest", 0.016, 0.1, Vector3(side * 0.05, 0.145, -0.1145), STRAP, 0.0, side * -12.0, true)
	for y: float in [0.015, 0.065]:
		flat(list, &"chest", 0.11, 0.006, Vector3(0.0, y, -0.1275), SHIRT, 0.0, 0.0, true)


## The fur collar standing round the neck, and the mantle of fur over the shoulders.
func _fur(list: Array[HumanoidPiece]) -> void:
	add(list, &"chest", LATHE, Vector3(0.4, 0.0, 0.25), Vector3(0.0, 0.235, 0.005), FUR, 0.0, {"sides": 6,
		"profile": PackedVector4Array([Vector4(-0.025, 0.72, 0.8, 0.0), Vector4(0.005, 1.0, 1.0, 0.0),
			Vector4(0.04, 0.5, 0.62, 0.0)])})
	add(list, &"chest", LATHE, Vector3(0.15, 0.0, 0.14), Vector3(0.0, 0.272, 0.012), FUR_LIGHT, 0.0, {"sides": 6,
		"profile": PackedVector4Array([Vector4(-0.03, 1.0, 1.0, 0.0), Vector4(0.04, 1.15, 1.15, 0.0)])})


## The back, what the gameplay camera sees: the neon wolf in shades, the sign and the graffiti.
func _back(list: Array[HumanoidPiece]) -> void:
	_neon_wolf(list)
	_sign(list)
	_tags(list)


## The neon wolf with its shades across the shoulders: a cyan outline (two ears, the head, the muzzle), a pair of pink
## lenses and a yellow bridge across them.
func _neon_wolf(list: Array[HumanoidPiece]) -> void:
	# (The fur mantle covers the coat's back above y = 0.21, so the ears' tips peek out from under it.)
	var outline: Array[Vector2] = [Vector2(-0.092, 0.226), Vector2(-0.044, 0.19), Vector2(0.0, 0.18), Vector2(0.044, 0.19),
		Vector2(0.092, 0.226), Vector2(0.104, 0.16), Vector2(0.06, 0.126), Vector2(0.0, 0.106), Vector2(-0.06, 0.126),
		Vector2(-0.104, 0.16)]
	for k: int in outline.size():
		back_line(list, outline[k], outline[(k + 1) % outline.size()], 0.009, CYAN, LINE_GLOW)
	for x: float in [-0.04, 0.04]:
		back_flat(list, 0.054, 0.03, Vector2(x, 0.158), PINK, SOFT_GLOW, -x * 140.0)
	back_line(list, Vector2(-0.016, 0.16), Vector2(0.016, 0.16), 0.008, YELLOW, SOFT_GLOW)
	back_flat(list, 0.024, 0.014, Vector2(0.0, 0.114), CYAN, LINE_GLOW)


## "PARTY WOLF" across the lower back: PARTY in pink above WOLF in cyan, each line centred, as block letters of flat quads.
## DESIGN-TBD (docs/questions/m3.md, 6): its colours and size; from the game camera it is about a pixel a cell.
func _sign(list: Array[HumanoidPiece]) -> void:
	_word(list, "PARTY", 0.094, PINK)
	_word(list, "WOLF", 0.0385, CYAN)


## One line of the sign: `word`'s letters one cell apart, centred on x = 0 with their top edge at chest height `top`.
func _word(list: Array[HumanoidPiece], word: String, top: float, color: Color) -> void:
	var cells: float = word.length() - 1.0
	for letter: String in word:
		cells += glyph_width(letter)
	var x: float = -cells * 0.5
	for letter: String in word:
		for r: Rect2 in GLYPHS[letter]:
			var cx: float = (x + r.position.x + r.size.x * 0.5) * CELL
			var cy: float = top - (r.position.y + r.size.y * 0.5) * CELL
			back_flat(list, r.size.x * CELL, r.size.y * CELL, Vector2(cx, cy), color, LINE_GLOW * 0.9)
		x += glyph_width(letter) + 1.0


## How many cells wide a letter of the sign is.
static func glyph_width(letter: String) -> float:
	var width: float = 0.0
	for r: Rect2 in GLYPHS[letter]:
		width = maxf(width, r.position.x + r.size.x)
	return width


## The graffiti on the coat's back: tags in cyan, pink, green and yellow down the sides, a few strokes each.
## DESIGN-TBD (docs/questions/m3.md, 5): simplified from the sheet.
func _tags(list: Array[HumanoidPiece]) -> void:
	var tags: Array = [
		[Vector2(-0.12, 0.2), 0.034, 0.008, 30.0, GREEN], [Vector2(-0.122, 0.17), 0.024, 0.008, -20.0, GREEN],
		[Vector2(-0.118, 0.12), 0.03, 0.008, 60.0, YELLOW], [Vector2(-0.12, 0.065), 0.034, 0.008, -35.0, PINK],
		[Vector2(-0.115, 0.01), 0.03, 0.008, 25.0, CYAN],
		[Vector2(0.12, 0.2), 0.03, 0.008, -35.0, YELLOW], [Vector2(0.12, 0.15), 0.034, 0.008, 40.0, PINK],
		[Vector2(0.118, 0.1), 0.024, 0.008, -60.0, GREEN], [Vector2(0.12, 0.05), 0.034, 0.008, 20.0, CYAN],
		[Vector2(0.116, -0.005), 0.028, 0.008, -30.0, YELLOW],
	]
	for t: Array in tags:
		back_flat(list, t[1], t[2], t[0], t[4], SOFT_GLOW * 0.8, t[3])


# --- Arms -------------------------------------------------------------------------------

## The right arm: the purple sleeve with its tags, the grey fur cuff, two rave bracelets and the fingerless glove.
func _right_arm(list: Array[HumanoidPiece]) -> void:
	add(list, &"upper_arm", PRISM, Vector3(0.1, 0.22, 0.095), Vector3(0.0, -0.095, 0.0), PURPLE, 0.0,
		{"side": RIGHT, "top_scale": Vector2(1.15, 1.15)})
	add(list, &"forearm", PRISM, Vector3(0.085, 0.1, 0.08), Vector3(0.0, -0.05, 0.0), PURPLE, 0.0,
		{"side": RIGHT, "top_scale": Vector2(1.1, 1.1)})
	# Tags on the back of the sleeve (the face of its six-sided prism is 0.044 m from the axis).
	for tag: Array in [[-0.05, 0.03, 30.0, PINK], [-0.092, 0.026, -40.0, GREEN], [-0.135, 0.03, 20.0, YELLOW]]:
		flat(list, &"upper_arm", tag[1], 0.008, Vector3(0.0, tag[0], 0.0455), tag[3], SOFT_GLOW * 0.8, tag[2], false,
			{"side": RIGHT})
	flat(list, &"forearm", 0.03, 0.008, Vector3(0.0, -0.05, 0.0415), CYAN, SOFT_GLOW * 0.8, -25.0, false, {"side": RIGHT})
	add(list, &"forearm", PRISM, Vector3(0.108, 0.1, 0.104), Vector3(0.0, -0.13, 0.0), FUR, 0.0, {"side": RIGHT, "sides": 8})
	for ring: Array in [[-0.014, CYAN], [-0.027, GREEN]]:
		add(list, &"hand", BAND, Vector3(0.074, 0.0, 0.084), Vector3(0.0, ring[0], -0.004), ring[1], SOFT_GLOW,
			{"side": RIGHT, "profile": PackedVector4Array([Vector4(-0.005, 1.0, 1.0, 0.0), Vector4(0.005, 1.0, 1.0, 0.0)])})
	add(list, &"hand", BOX, Vector3(0.06, 0.066, 0.072), Vector3(0.0, -0.035, -0.004), SHIRT, 0.0, {"side": RIGHT})
	add(list, &"hand", BOX, Vector3(0.054, 0.032, 0.056), Vector3(0.0, -0.082, -0.01), PlayerSuit.SKIN, 0.0, {"side": RIGHT})


## The rave cyber-arm on the left, from the shoulder down: a purple dome with a glowing cyan sigil, the upper arm with
## two glowing cyan rings, a dark elbow with its lamp, the forearm with a glowing line down it, and an articulated
## hand. (Authored on the right, placed on the left.)
func _cyber_arm(list: Array[HumanoidPiece]) -> void:
	var shell := {"side": LEFT, "shine": 0.55}
	add(list, &"upper_arm", LATHE, Vector3(0.13, 0.0, 0.13), Vector3(0.012, 0.0, 0.0), PURPLE, 0.0, merged(shell, {"sides": 6,
		"profile": PackedVector4Array([Vector4(-0.045, 1.0, 1.0, 0.0), Vector4(0.012, 0.96, 0.96, 0.0),
			Vector4(0.05, 0.55, 0.55, 0.0)])}))
	add(list, &"upper_arm", PRISM, Vector3(0.076, 0.19, 0.072), Vector3(0.0, -0.1, 0.0), PURPLE, 0.0,
		merged(shell, {"top_scale": Vector2(1.1, 1.1)}))
	for y: float in [-0.06, -0.14]:
		add(list, &"upper_arm", BAND, Vector3(0.088, 0.0, 0.084), Vector3(0.0, y, 0.0), CYAN, LINE_GLOW, {"side": LEFT,
			"profile": PackedVector4Array([Vector4(-0.005, 1.0, 1.0, 0.0), Vector4(0.005, 1.0, 1.0, 0.0)])})
	add(list, &"upper_arm", PRISM, Vector3(0.07, 0.05, 0.07), Vector3(0.0, -0.2, 0.0), PURPLE_DARK, 0.0,
		{"side": LEFT, "sides": 4, "rotation_degrees": Vector3(0.0, 0.0, 90.0)})
	add(list, &"forearm", PRISM, Vector3(0.07, 0.16, 0.066), Vector3(0.0, -0.085, 0.0), PURPLE, 0.0,
		merged(shell, {"top_scale": Vector2(1.15, 1.12)}))
	pipe(list, &"forearm", Vector3(-0.022, -0.02, -0.03), Vector3(-0.02, -0.14, -0.028), 0.012, Vector3.FORWARD, CYAN,
		LINE_GLOW, LEFT)
	pipe(list, &"forearm", Vector3(0.022, -0.02, 0.03), Vector3(0.02, -0.14, 0.028), 0.012, Vector3.BACK, CYAN,
		LINE_GLOW, LEFT)
	add(list, &"hand", BOX, Vector3(0.062, 0.066, 0.074), Vector3(0.0, -0.035, -0.004), PURPLE_DARK, 0.0,
		merged(shell, {"chamfer": 0.35}))
	for x: float in [-0.015, 0.015]:
		add(list, &"hand", BOX, Vector3(0.024, 0.05, 0.018), Vector3(x, -0.088, -0.012), CYAN, SOFT_GLOW, {"side": LEFT})


# --- Legs ------------------------------------------------------------------------------

## Dark pants with a pink strap on each thigh, glowing knee pads, and neon-laced combat boots with glowing soles.
func _legs(list: Array[HumanoidPiece]) -> void:
	add(list, &"thigh", PRISM, Vector3(0.115, 0.32, 0.115), Vector3(0.0, -0.145, 0.0), PANTS, 0.0,
		{"top_scale": Vector2(1.2, 1.2)})
	add(list, &"thigh", BAND, Vector3(0.144, 0.0, 0.144), Vector3(0.0, -0.075, 0.0), STRAP, 0.0,
		{"sides": 6, "profile": PackedVector4Array([Vector4(-0.011, 1.0, 1.0, 0.0), Vector4(0.011, 1.0, 1.0, 0.0)])})
	add(list, &"shin", PRISM, Vector3(0.095, 0.18, 0.095), Vector3(0.0, -0.08, 0.0), PANTS, 0.0,
		{"top_scale": Vector2(1.1, 1.1)})
	# The knee pad: a dark shell with a glowing violet frame on its face.
	add(list, &"shin", BOX, Vector3(0.088, 0.08, 0.04), Vector3(0.0, -0.008, -0.06), PURPLE_DARK, 0.0, {"top_scale": Vector2(0.9, 0.8)})
	flat(list, &"shin", 0.06, 0.05, Vector3(0.0, -0.008, -0.0815), VIOLET, SOFT_GLOW, 0.0, true)
	flat(list, &"shin", 0.04, 0.03, Vector3(0.0, -0.008, -0.0828), PURPLE_DARK, 0.0, 0.0, true)
	add(list, &"shin", BAND, Vector3(0.108, 0.0, 0.108), Vector3(0.0, -0.1, 0.0), STRAP, 0.0,
		{"profile": PackedVector4Array([Vector4(-0.011, 1.0, 1.0, 0.0), Vector4(0.011, 1.0, 1.0, 0.0)])})
	# The boot: a black shaft with its laces criss-crossed in pink, the toe and a glowing sole.
	add(list, &"shin", PRISM, Vector3(0.1, 0.15, 0.1), Vector3(0.0, -0.235, 0.0), BOOT, 0.0, {"top_scale": Vector2(1.05, 1.05)})
	for y: float in [-0.19, -0.225, -0.26]:
		flat(list, &"shin", 0.044, 0.007, Vector3(0.0, y, -0.047), PINK, SOFT_GLOW, 0.0, true)
	add(list, &"foot", BOX, Vector3(0.098, 0.09, 0.2), Vector3(0.0, -0.025, -0.045), BOOT, 0.0,
		{"chamfer": 0.3, "top_scale": Vector2(0.85, 0.7), "top_shift": 0.02})
	add(list, &"foot", BOX, Vector3(0.102, 0.022, 0.21), Vector3(0.0, -0.064, -0.045), SOLE)
	flat(list, &"foot", 0.1, 0.01, Vector3(0.0, -0.064, -0.1515), VIOLET, SOFT_GLOW, 0.0, true)


# --- The coat's skirt and the tail -------------------------------------------------------

## One of the coat's four skirt panels, knee to mid-calf (as Echo's): purple with a glowing cyan line along the hem and
## a few tags on the back panels.
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
	pieces.append(piece(&"pelvis", SHELL, Vector3(SKIRT_HALF.x * 2.0, 0.0, SKIRT_HALF.y * 2.0), at, PURPLE, 0.0,
		{"sides": 12, "section_phase": 15.0, "arc": arc, "thickness": 0.012,
			"profile": PackedVector4Array([Vector4(0.03, 1.0, 1.0, 0.0), Vector4(hem, SKIRT_FLARE, SKIRT_FLARE, 0.012)])}))
	# A glowing line along the hem, and (behind) a pink band above it.
	pieces.append(_skirt_band(arc, SKIRT_LENGTH - 0.03, SKIRT_LENGTH - 0.012, CYAN, LINE_GLOW))
	if behind:
		pieces.append(_skirt_band(arc, SKIRT_LENGTH - 0.12, SKIRT_LENGTH - 0.1, PINK, SOFT_GLOW))
	panel.pieces = pieces
	return panel


## A band of the skirt's outside over the faces within `arc`, from `top` to `bottom` metres below the hinge, 3 mm proud
## of the sheet: a colour on the panel for two triangles a face.
func _skirt_band(arc: Vector2, top: float, bottom: float, color: Color, glow: float) -> HumanoidPiece:
	var rings := PackedVector4Array()
	for d: float in [top, bottom]:
		var t: float = d / SKIRT_LENGTH
		var scale: float = 1.0 + (SKIRT_FLARE - 1.0) * t + 0.02
		rings.append(Vector4(-d, scale, scale, 0.012 * t))
	return piece(&"pelvis", BAND, Vector3(SKIRT_HALF.x * 2.0, 0.0, SKIRT_HALF.y * 2.0), Vector3(0.0, SKIRT_HINGE_Y, 0.005),
		color, glow, {"sides": 12, "section_phase": 15.0, "arc": arc, "profile": rings})


## The grey wolf tail, as the sheet draws it: hanging from a carabiner at the front of the belt on his left, in front of
## the thigh (authored on the right, hinged at +x, and placed on the left as the mirrored copy, `side = -1`). A stiff panel
## that follows the left thigh a little and swings on its own: three tapering fur sections, thin at the root, full in the
## middle, ending in a dark tip. (The back of the belt is free for the magnet power-up's coil.)
## DESIGN-TBD (docs/questions/m3.md, 7): the carabiner is left out and the tail's banding is ours.
func _tail() -> HumanoidPanel:
	var panel := HumanoidPanel.new()
	panel.side = -1
	panel.behind = false
	panel.length = 0.31
	panel.hinge = Vector3(0.075, SKIRT_HINGE_Y - 0.03, -0.128)
	panel.follow = 0.35
	var pieces: Array[HumanoidPiece] = []
	# [centre y, length, bottom width, top width / bottom width, colour]
	var sections: Array = [[-0.05, 0.1, 0.08, 0.5, FUR], [-0.16, 0.12, 0.075, 1.07, FUR_LIGHT], [-0.265, 0.09, 0.02, 3.4, FUR_DARK]]
	for section: Array in sections:
		pieces.append(piece(&"pelvis", PRISM, Vector3(section[2], section[1], section[2] * 0.85),
			Vector3(0.075, section[0], -0.14), section[4], 0.0, {"sides": 5, "top_scale": Vector2(section[3], section[3])}))
	panel.pieces = pieces
	return panel


# --- Builders -------------------------------------------------------------------------

## A flat one-sided quad (two triangles): `w` x `h` metres, centred on `at` (the segment's joint space) and turned
## `roll` degrees about its normal, facing back (+z) or, with `front`, forward (-z). The cheapest way to put a patch of
## colour (a line, a tag, a letter's stroke) on a surface. `extra` sets any other HumanoidPiece property.
static func flat_piece(segment: StringName, w: float, h: float, at: Vector3, color: Color, glow: float = 0.0,
		roll: float = 0.0, front: bool = false, extra: Dictionary = {}) -> HumanoidPiece:
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


## A flat on the coat's back (chest joint space) at (x, y) of `p`, 2 mm off the surface (`lift`: millimetres more,
## for a patch over another), leaning with the surface above the waist.
static func back_flat(list: Array[HumanoidPiece], w: float, h: float, p: Vector2, color: Color, glow: float = 0.0,
		roll: float = 0.0, lift: int = 0) -> HumanoidPiece:
	var lean: float = clampf(p.y - 0.115, 0.0, 0.15)
	var z: float = BACK_Z - BACK_LEAN * lean + 0.002 + 0.001 * lift
	var tilt: float = rad_to_deg(-atan(BACK_LEAN)) if lean > 0.0 else 0.0
	return flat(list, &"chest", w, h, Vector3(p.x, p.y, z), color, glow, roll, false,
		{"rotation_degrees": Vector3(tilt, 0.0, roll)})


## A back flat as a line of `width` from `a` to `b`.
static func back_line(list: Array[HumanoidPiece], a: Vector2, b: Vector2, width: float, color: Color, glow: float) -> HumanoidPiece:
	var d: Vector2 = b - a
	return back_flat(list, d.length() + width * 0.6, width, (a + b) * 0.5, color, glow, rad_to_deg(atan2(d.y, d.x)))
