extends TestSuite
## The Party Wolf outfit (GDD §8, "Cosmetics"; brief docs/art/BRIEF_OUTFIT_PARTY_WOLF.md; task M3): a wolf mask over Echo's
## face with his hair behind it (the one outfit that covers his head), a long purple coat with graffiti and fur, "PARTY WOLF" in
## words on the back and a neon wolf above it, a rave cyber-arm, a tail that swings, glows in the brief's colours as drawn and
## kept thin and soft (outfits are free of the colour rule), all of it built of cheap flat quads (no extra draw call), and its
## glows power down on death and take the invulnerability tint like Echo's conduits. That it builds within the avatar's budgets,
## keeps Echo's size and poses and carries the power-ups is test_outfits's, over every outfit.

const AvatarSuite = preload("res://tests/suites/test_avatar.gd")
const Look = preload("res://scripts/player/outfits/party_wolf.gd")
## The brightest a glow line gets while dashing, as a multiple of its colour (as test_outfit_rex measures; test_avatar's limit
## for the base look is 1.25).
const MAX_OUTFIT_EMISSION: float = 1.4
const DT: float = 1.0 / 60.0
const BOX_SHAPE := HumanoidPiece.Shape.BOX
const PRISM_SHAPE := HumanoidPiece.Shape.PRISM
## The sign's letters, as the owner reads them: five rows of cells (W is five wide, the others three).
const LETTERS := {
	"P": ["###", "#.#", "###", "#..", "#.."],
	"A": ["###", "#.#", "###", "#.#", "#.#"],
	"R": ["###", "#.#", "##.", "#.#", "#.#"],
	"T": ["###", ".#.", ".#.", ".#.", ".#."],
	"Y": ["#.#", "#.#", ".#.", ".#.", ".#."],
	"W": ["#...#", "#...#", "#.#.#", "#.#.#", ".#.#."],
	"O": ["###", "#.#", "#.#", "#.#", "###"],
	"L": ["#..", "#..", "#..", "#..", "###"],
	"F": ["###", "#..", "##.", "#..", "#.."],
}

var _worn_before: StringName = &""


func run() -> void:
	_worn_before = PlayerOutfits.worn
	_test_mask()
	_test_look()
	_test_sign()
	_test_graffiti_and_wolf()
	_test_glows()
	_test_cost()
	_test_tail_and_armor()
	_test_glow_effects()
	PlayerOutfits.worn = _worn_before


func _avatar_in(id: StringName) -> PlayerAvatar:
	PlayerOutfits.worn = id
	var avatar := PlayerAvatar.new()
	PlayerOutfits.worn = _worn_before
	return avatar


## Every piece the outfit draws: its body, its head and its panels'.
func _all_pieces(wolf: PlayerOutfit) -> Array[HumanoidPiece]:
	var out: Array[HumanoidPiece] = []
	out.append_array(wolf.body_pieces())
	out.append_array(wolf.head_pieces())
	for panel: HumanoidPanel in wolf.panels():
		out.append_array(panel.pieces)
	return out


## The highest vertex of the head-segment pieces in `pieces`, as the rig places them (the head joint's space).
func _top(pieces: Array[HumanoidPiece]) -> float:
	var builder := HumanoidMeshBuilder.new()
	for p: HumanoidPiece in pieces:
		if p.segment == &"head":
			builder.add_piece(p, false)
	var top: float = -INF
	for v: Vector3 in builder.vertices:
		top = maxf(top, v.y)
	return top


## How many triangles one piece builds (an empty piece, say a band whose arc holds no face, builds none).
func _triangles(p: HumanoidPiece) -> int:
	var builder := HumanoidMeshBuilder.new()
	builder.add_piece(p, false)
	return builder.triangle_count()


func _count(pieces: Array[HumanoidPiece], segment: StringName, color: Color) -> int:
	var n: int = 0
	for p: HumanoidPiece in pieces:
		if p.segment == segment and p.color == color:
			n += 1
	return n


# --- The mask -------------------------------------------------------------------------

func _test_mask() -> void:
	var wolf: PlayerOutfit = PlayerOutfits.outfit(&"party_wolf")
	check(wolf != null, "Party Wolf's file builds")
	if wolf == null:
		return
	var head: Array[HumanoidPiece] = wolf.head_pieces()
	var echo_head: Array[HumanoidPiece] = PlayerSuit.head_pieces()
	# His hair stays behind the mask: every hair piece of Echo's (the boxes of his face are what the mask covers).
	var echo_hair: int = 0
	for p: HumanoidPiece in echo_head:
		if p.color == PlayerSuit.HAIR and p.shape != BOX_SHAPE:
			echo_hair += 1
	check(echo_hair >= 18 and _count(head, &"head", PlayerSuit.HAIR) == echo_hair,
		"his spiky black hair is kept behind the mask (%d pieces, Echo's %d)" % [_count(head, &"head", PlayerSuit.HAIR), echo_hair])
	check(_count(head, &"neck", PlayerSuit.SKIN) == 1 and _count(head, &"head", PlayerSuit.SKIN) >= 1, "…with his neck and skull")
	# His face is covered: nothing of his implant, eye or scar is drawn.
	var face: int = 0
	for color: Color in [PlayerSuit.GOLD, PlayerSuit.GOLD_DARK, PlayerSuit.GLOW, PlayerSuit.EYE, PlayerSuit.SCAR]:
		face += _count(head, &"head", color)
	check(face == 0, "his face (the copper implant, the eye and the scar) is under the mask: %d of his face pieces are drawn" % face)
	# Pointed ears, bared teeth, the pink eyepiece over the left eye (-x) and a cyan eye on the right.
	var ears: int = 0
	var ear_pieces: Array[HumanoidPiece] = []
	var teeth: int = 0
	var pink_left: bool = false
	var cyan_right: bool = false
	for p: HumanoidPiece in head:
		if p.segment != &"head":
			continue
		if p.shape == PRISM_SHAPE and p.color == Look.FUR and p.offset.y > 0.15:
			ears += 2 if p.side == HumanoidPiece.Placement.MIRRORED else 1
			ear_pieces.append(p)
		if p.color == Look.TEETH:
			teeth += 1
		if p.shape == BOX_SHAPE and p.color == Look.PINK and p.glow > 0.0 and p.offset.x < 0.0:
			pink_left = true
		if p.shape == BOX_SHAPE and p.color == Look.CYAN and p.glow > 0.0 and p.offset.x > 0.0:
			cyan_right = true
	check(ears == 2, "pointed ears: two grey cones (%d)" % ears)
	var hair: Array[HumanoidPiece] = []
	for p: HumanoidPiece in echo_head:
		if p.color == PlayerSuit.HAIR:
			hair.append(p)
	var ear_top: float = _top(ear_pieces)
	var hair_top: float = _top(hair)
	check(ear_top <= hair_top, "…no higher than his hair tips (the ears' top vertex is %.4f m above the head joint, the hair's %.4f)" % [ear_top, hair_top])
	check(teeth >= 4, "bared teeth (%d fangs)" % teeth)
	check(pink_left, "a glowing pink eyepiece over his left eye (the wearer's, so -x)")
	check(cyan_right, "…and a cyan wolf eye on the other")
	var markings: int = _count(head, &"head", Look.VIOLET) + _count(head, &"head", Look.CYAN)
	check(markings >= 4, "neon purple and cyan markings on the mask (%d)" % markings)
	check(_count(head, &"head", Look.FUR) >= 3, "grey fur: the brow, the snout and the ears")


# --- The look ----------------------------------------------------------------------------

func _test_look() -> void:
	var wolf: PlayerOutfit = PlayerOutfits.outfit(&"party_wolf")
	var body: Array[HumanoidPiece] = wolf.body_pieces()
	var c: Color = Look.PURPLE
	check(c.b > 0.5 and c.r < 0.45 and c.g < 0.25, "the coat is purple")
	check(_count(body, &"chest", Look.PURPLE) >= 2 and _count(wolf.panels()[0].pieces, &"pelvis", Look.PURPLE) == 1,
		"a long coat: a purple body and a purple skirt")
	check(_count(body, &"chest", Look.FUR) >= 1 and _count(body, &"chest", Look.FUR_LIGHT) >= 1 and _count(body, &"forearm", Look.FUR) >= 1,
		"grey faux-fur: a mantle and a collar on the coat, and cuffs on the right sleeve")
	check(wolf.panels().size() == 5 and wolf.panels().size() <= HumanoidRig.MAX_PANELS,
		"the coat's four skirt panels and the tail (%d panels)" % wolf.panels().size())
	# The pink chest rig, the howling-wolf print and the studded belt with glow sticks.
	check(_count(body, &"chest", Look.STRAP) >= 2, "a pink chest rig")
	var sticks: int = 0
	var on_right: int = 0
	for p: HumanoidPiece in body:
		if p.segment == &"pelvis" and p.glow > 0.0 and p.size.y > 0.1:
			sticks += 1
			if p.offset.x > 0.0 and p.offset.z < 0.0:
				on_right += 1
	check(sticks == 4 and on_right == 4, "four glow sticks hang from the front of the belt on his right (%d, %d on +x)" % [sticks, on_right])
	# The rave arm on the left: purple with cyan glow, in place of Echo's gold (no gold on the whole outfit).
	var cyan_arm: int = 0
	var left_purple: int = 0
	for p: HumanoidPiece in body:
		if p.segment in [&"upper_arm", &"forearm", &"hand"] and (p.side == HumanoidPiece.Placement.LEFT or p.side == HumanoidPiece.Placement.CENTER):
			if p.color == Look.CYAN and p.glow > 0.0:
				cyan_arm += 1
			if p.color == Look.PURPLE:
				left_purple += 1
	check(cyan_arm >= 4 and left_purple >= 3, "a purple rave cyber-arm with glowing cyan lines (%d lines)" % cyan_arm)
	var gold: int = 0
	for p: HumanoidPiece in _all_pieces(wolf):
		if p.color == PlayerSuit.GOLD or p.color == PlayerSuit.GOLD_DARK:
			gold += 1
	check(gold == 0, "no gold: Echo's gold arm is replaced")
	# Glowing knee pads, pink straps and neon-laced boots.
	var laces: int = 0
	var knee: int = 0
	for p: HumanoidPiece in body:
		if p.segment == &"shin" and p.color == Look.PINK and p.glow > 0.0:
			laces += 1
		if p.segment == &"shin" and p.color == Look.VIOLET and p.glow > 0.0:
			knee += 1
	check(laces >= 3 and knee >= 1 and _count(body, &"thigh", Look.STRAP) >= 1, "pink laces on the boots, glowing knee pads, pink straps")


# --- "PARTY WOLF" ---------------------------------------------------------------------------

## The cells the pieces of `color` cover on the coat's back inside the given box, as rows of '#' and '.': what the camera
## behind the runner sees of the sign.
func _sign_rows(pieces: Array[HumanoidPiece], color: Color, x_limit: float, y_range: Vector2) -> PackedStringArray:
	var quads: Array[Rect2] = []
	for p: HumanoidPiece in pieces:
		if p.segment != &"chest" or p.color != color or p.offset.z < 0.09 or p.shape != HumanoidPiece.Shape.BAND:
			continue
		if absf(p.offset.x) > x_limit or p.offset.y < y_range.x or p.offset.y > y_range.y:
			continue
		var w: float = p.size.x / 1.41421
		var h: float = absf(p.profile[1].x - p.profile[0].x)
		quads.append(Rect2(p.offset.x - w * 0.5, p.offset.y - h * 0.5, w, h))
	var rows := PackedStringArray()
	if quads.is_empty():
		return rows
	var box: Rect2 = quads[0]
	for q: Rect2 in quads:
		box = box.merge(q)
	var cols: int = roundi(box.size.x / Look.CELL)
	for r: int in roundi(box.size.y / Look.CELL):
		var row: String = ""
		for col: int in cols:
			var at := Vector2(box.position.x + (col + 0.5) * Look.CELL, box.end.y - (r + 0.5) * Look.CELL)
			var lit: bool = false
			for q: Rect2 in quads:
				lit = lit or q.has_point(at)
			row += "#" if lit else "."
		rows.append(row)
	return rows


## The expected rows of a word: the letters' rows side by side with one empty cell between.
static func _word_rows(word: String) -> PackedStringArray:
	var rows := PackedStringArray()
	for r: int in 5:
		var row: String = ""
		for i: int in word.length():
			row += ("." if i > 0 else "") + String(LETTERS[word[i]][r])
		rows.append(row)
	return rows


func _test_sign() -> void:
	var wolf: PlayerOutfit = PlayerOutfits.outfit(&"party_wolf")
	var body: Array[HumanoidPiece] = wolf.body_pieces()
	# The sign is the lower back between the belt and the neon wolf: |x| inside the coat, y above the belt.
	var party: PackedStringArray = _sign_rows(body, Look.PINK, 0.1, Vector2(0.04, 0.1))
	var wolf_word: PackedStringArray = _sign_rows(body, Look.CYAN, 0.1, Vector2(-0.02, 0.045))
	check(party == _word_rows("PARTY"), "the back reads PARTY in pink:\n%s" % "\n".join(party))
	check(wolf_word == _word_rows("WOLF"), "…and WOLF in cyan below it:\n%s" % "\n".join(wolf_word))
	# Above the belt (the sash's top is at chest y -0.021), inside the coat's width, big enough to read.
	var lowest: float = 1.0
	var widest: float = 0.0
	var strokes: int = 0
	for p: HumanoidPiece in body:
		if p.segment == &"chest" and p.shape == HumanoidPiece.Shape.BAND and p.offset.z > 0.09 and absf(p.offset.x) <= 0.1 \
				and p.offset.y >= -0.02 and p.offset.y <= 0.1 and (p.color == Look.PINK or p.color == Look.CYAN):
			strokes += 1
			lowest = minf(lowest, p.offset.y - absf(p.profile[1].x - p.profile[0].x) * 0.5)
			widest = maxf(widest, absf(p.offset.x) + p.size.x / 1.41421 * 0.5)
	check(lowest >= -0.021 and widest <= 0.14, "the sign sits above the belt (lowest edge %.3f) inside the coat's width (%.3f)" % [lowest, widest])
	check(strokes == 32, "built of 32 strokes, two triangles each, not separate meshes (%d)" % strokes)


# --- Graffiti and the neon wolf ------------------------------------------------------------------

func _test_graffiti_and_wolf() -> void:
	var wolf: PlayerOutfit = PlayerOutfits.outfit(&"party_wolf")
	var body: Array[HumanoidPiece] = wolf.body_pieces()
	# Tags down both sides of the back, in the sheet's four colours.
	var tags: Dictionary = {}
	for p: HumanoidPiece in body:
		if p.segment == &"chest" and p.shape == HumanoidPiece.Shape.BAND and p.offset.z > 0.09 and absf(p.offset.x) > 0.105 and p.glow > 0.0:
			tags[p.color] = int(tags.get(p.color, 0)) + 1
	check(tags.size() == 4 and tags.has(Look.CYAN) and tags.has(Look.PINK) and tags.has(Look.GREEN) and tags.has(Look.YELLOW),
		"graffiti tags in cyan, pink, green and yellow down both sides of the back (%s)" % [tags])
	# The neon wolf in shades across the shoulders, above the sign: a cyan outline, pink lenses, a yellow bridge.
	var outline: int = 0
	var lenses: int = 0
	var bridge: int = 0
	var lowest: float = 1.0
	for p: HumanoidPiece in body:
		if p.segment != &"chest" or p.shape != HumanoidPiece.Shape.BAND or p.offset.z < 0.09 or absf(p.offset.x) > 0.11 or p.offset.y < 0.1:
			continue
		if p.color == Look.CYAN:
			outline += 1
			lowest = minf(lowest, p.offset.y)
		elif p.color == Look.PINK:
			lenses += 1
		elif p.color == Look.YELLOW:
			bridge += 1
	check(outline >= 10 and lenses == 2 and bridge == 1, "the neon wolf in shades: %d cyan lines, %d lenses, %d bridge" % [outline, lenses, bridge])
	check(lowest >= 0.1, "…across the shoulders, above the sign (its chin at %.3f)" % lowest)


# --- Glows ------------------------------------------------------------------------------------

func _test_glows() -> void:
	var wolf: PlayerOutfit = PlayerOutfits.outfit(&"party_wolf")
	var glows: Dictionary = {}
	var energy: float = PlayerSuit.body_material().get_shader_parameter(&"glow_energy")
	var brightest: float = 0.0
	var lit: int = 0
	for p: HumanoidPiece in _all_pieces(wolf):
		if p.glow > 0.0:
			lit += 1
			glows[p.color] = int(glows.get(p.color, 0)) + 1
			brightest = maxf(brightest, p.glow * energy * PlayerAvatar.DASH_GLOW * maxf(p.color.r, maxf(p.color.g, p.color.b)))
	for color: Color in [Look.CYAN, Look.PINK, Look.GREEN, Look.YELLOW, Look.VIOLET]:
		check(glows.has(color), "it glows %s as drawn" % color)
	check(lit >= 80, "the most glowing outfit: %d glowing pieces, all thin strokes and small lamps" % lit)
	check(brightest <= MAX_OUTFIT_EMISSION, "…and soft: the brightest line while dashing is %.2f× its colour (limit %.2f)" % [brightest, MAX_OUTFIT_EMISSION])


# --- Cost ------------------------------------------------------------------------------------------

func _test_cost() -> void:
	var wolf: PlayerOutfit = PlayerOutfits.outfit(&"party_wolf")
	var own_material: int = 0
	for p: HumanoidPiece in _all_pieces(wolf):
		if p.material != null:
			own_material += 1
	var empty: int = 0
	for p: HumanoidPiece in _all_pieces(wolf):
		if _triangles(p) == 0:
			empty += 1
	check(empty == 0, "every piece builds at least one triangle (%d empty)" % empty)
	check(own_material == 0, "no piece has a material of its own, so the graffiti, the sign and the neon wolf cost no draw call (%d)" % own_material)
	# A flat is two triangles.
	var builder := HumanoidMeshBuilder.new()
	builder.add_piece(Look.flat_piece(&"chest", 0.05, 0.02, Vector3.ZERO, Look.PINK, 0.3), false)
	var front := HumanoidMeshBuilder.new()
	front.add_piece(Look.flat_piece(&"chest", 0.05, 0.02, Vector3.ZERO, Look.PINK, 0.3, 30.0, true), false)
	check(builder.triangle_count() == 2 and front.triangle_count() == 2, "a flat quad is two triangles (%d, %d)" % [builder.triangle_count(), front.triangle_count()])
	var avatar: PlayerAvatar = _avatar_in(&"party_wolf")
	avatar.fit_to(tuning.visual_size)
	var calls: int = avatar.draw_call_count()
	var echo: PlayerAvatar = _avatar_in(PlayerOutfits.ECHO)
	var echo_calls: int = echo.draw_call_count()
	var tris: int = avatar.triangle_count()
	check(calls == echo_calls, "%d draw calls, Echo's own %d (a coat's panels are one)" % [calls, echo_calls])
	check(tris <= AvatarSuite.TRIANGLE_BUDGET - 452, "%d triangles bare (the budget leaves %d before the power-ups' 452)" % [tris, AvatarSuite.TRIANGLE_BUDGET - 452])
	avatar.free()
	echo.free()


# --- The tail and the armor ------------------------------------------------------------------------------

func _test_tail_and_armor() -> void:
	var wolf: PlayerOutfit = PlayerOutfits.outfit(&"party_wolf")
	var panels: Array[HumanoidPanel] = wolf.panels()
	var tail: HumanoidPanel = panels[panels.size() - 1]
	check(not tail.behind and tail.side == -1 and tail.hinge.x > 0.04 and tail.hinge.z < -0.1 and tail.length >= 0.2 and tail.follow <= 0.5,
		"a tail hanging from the front of the belt on his left, as the sheet draws it (side %d, hinge %s, follow %.2f, %.2f m)" % [tail.side, tail.hinge, tail.follow, tail.length])
	# The back of the belt is free for the magnet power-up's coil: none of the tail is inside it.
	var magnet := HumanoidMeshBuilder.new()
	for p: HumanoidPiece in PlayerSuit.attachments()[&"magnet"]:
		magnet.add_piece(p, false)
	var coil := AABB(magnet.vertices[0], Vector3.ZERO)
	for v: Vector3 in magnet.vertices:
		coil = coil.expand(v)
	var tail_mesh := HumanoidMeshBuilder.new()
	for p: HumanoidPiece in tail.pieces:
		tail_mesh.add_piece(p, true)
	var covered: int = 0
	for v: Vector3 in tail_mesh.vertices:
		if coil.has_point(v):
			covered += 1
	var rearmost: float = -INF
	for v: Vector3 in tail_mesh.vertices:
		rearmost = maxf(rearmost, v.z)
	check(covered == 0 and rearmost < 0.0, "…so it never covers the magnet's coil on the back (%d vertices inside it, the tail's rearmost point z %.3f)" % [covered, rearmost])
	var grey: bool = true
	for p: HumanoidPiece in tail.pieces:
		grey = grey and absf(p.color.r - p.color.g) < 0.02 and p.color.b >= p.color.r
	check(grey and not tail.pieces.is_empty(), "…grey fur")
	# It swings: the panel's pitch moves through a run.
	var avatar: PlayerAvatar = _avatar_in(&"party_wolf")
	tree.root.add_child(avatar)
	avatar.fit_to(tuning.visual_size)
	var s: Dictionary = AvatarSuite._state({"distance": 20.0})
	var low: float = 10.0
	var high: float = -10.0
	for i: int in 150:
		s["distance"] = float(s["distance"]) + 18.0 * DT
		avatar.animate(s, DT)
		if i > 30:
			var pitch: float = avatar.rig.panel_angles(panels.size() - 1).x
			low = minf(low, pitch)
			high = maxf(high, pitch)
	check(high - low > 0.05, "the tail swings through a run (pitch %.2f to %.2f rad)" % [low, high])
	tree.root.remove_child(avatar)
	avatar.free()
	# The armor power-up is refitted: plates lighter than the fur, so whether armor is up reads against it.
	var sets: Dictionary = wolf.attachment_overrides()
	check(sets.keys() == [&"armor"], "only the armor set is refitted (%s)" % [sets.keys()])
	var armor: Array = sets[&"armor"]
	var plate_color: Color = Look.ARMOR_PLATE
	var luma := func(col: Color) -> float: return col.r * 0.3 + col.g * 0.59 + col.b * 0.11
	check(luma.call(plate_color) >= luma.call(Look.FUR_LIGHT) + 0.15 and luma.call(plate_color) >= luma.call(Look.PURPLE) + 0.4,
		"its plates are brighter than the fur and the coat (%.2f against %.2f and %.2f)" % [luma.call(plate_color), luma.call(Look.FUR_LIGHT), luma.call(Look.PURPLE)])
	var segments: Dictionary = {}
	var rims: int = 0
	for p: HumanoidPiece in armor:
		segments[p.segment] = true
		if p.color == PlayerSuit.ARMOR_EDGE and p.glow > 0.0:
			rims += 1
	check(segments.has(&"upper_arm") and segments.has(&"chest") and rims >= 3, "…over the shoulders, the chest and the back, each edged with a pale glow (%d)" % rims)


# --- The glow effects ----------------------------------------------------------------------------------

func _test_glow_effects() -> void:
	var avatar: PlayerAvatar = _avatar_in(&"party_wolf")
	avatar.fit_to(tuning.visual_size)
	avatar.reset()
	var s: Dictionary = AvatarSuite._state({"alive": false})
	for i: int in 120:
		avatar.animate(s, DT)
	var material: ShaderMaterial = avatar._material
	check(float(material.get_shader_parameter(&"glow_boost")) < 0.15,
		"its glows power down on death (%.2f)" % float(material.get_shader_parameter(&"glow_boost")))
	avatar.reset()
	var dash: Dictionary = AvatarSuite._state({"dashing": true})
	for i: int in 60:
		avatar.animate(dash, DT)
	check(float(material.get_shader_parameter(&"glow_boost")) > 1.2, "…and brighten with the dash (%.2f)" % float(material.get_shader_parameter(&"glow_boost")))
	avatar.set_flash(true)
	var tint: Color = material.get_shader_parameter(&"tint")
	check(tint.a > 0.3, "the invulnerability tint covers the outfit too")
	avatar.free()
