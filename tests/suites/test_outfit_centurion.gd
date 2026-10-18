extends TestSuite
## The Centurion outfit (GDD §8, "Cosmetics"; brief docs/art/BRIEF_OUTFIT_CENTURION.md; task M3): it keeps Echo's head, wears
## polished gold and crimson as drawn (nothing on it glows: the gold stays a metal, not a light), a long charcoal and crimson coat
## with four skirt panels and two swinging strips of pteruges, lion-head pauldrons, a gold cuirass, the gold skull in its laurel
## across the back, a gold cyber-arm with crimson joints, gold greaves and boots, and no weapon. Its armor power-up is refitted
## in a cool bright silver-blue, so whether armor is up reads against all the gold. That it builds within the avatar's budgets,
## keeps Echo's size and poses and carries the power-ups is test_outfits's, over every outfit.

const AvatarSuite = preload("res://tests/suites/test_avatar.gd")
const Look = preload("res://scripts/player/outfits/centurion.gd")
const DT: float = 1.0 / 60.0
const BAND_SHAPE := HumanoidPiece.Shape.BAND
const LATHE_SHAPE := HumanoidPiece.Shape.LATHE
const BOX_SHAPE := HumanoidPiece.Shape.BOX

var _worn_before: StringName = &""


func run() -> void:
	_worn_before = PlayerOutfits.worn
	_test_centurion()
	_test_cuirass()
	_test_back()
	_test_armor()
	_test_swing()
	PlayerOutfits.worn = _worn_before


func _avatar_in(id: StringName) -> PlayerAvatar:
	PlayerOutfits.worn = id
	var avatar := PlayerAvatar.new()
	PlayerOutfits.worn = _worn_before
	return avatar


## Every piece the outfit draws: its body, its head and its panels'.
func _all_pieces(outfit: PlayerOutfit) -> Array[HumanoidPiece]:
	var out: Array[HumanoidPiece] = []
	out.append_array(outfit.body_pieces())
	out.append_array(outfit.head_pieces())
	for panel: HumanoidPanel in outfit.panels():
		out.append_array(panel.pieces)
	return out


## How many triangles one piece builds (an empty piece, say a band whose arc holds no face, builds none).
func _triangles(p: HumanoidPiece) -> int:
	var builder := HumanoidMeshBuilder.new()
	builder.add_piece(p, false)
	return builder.triangle_count()


func _distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func _test_centurion() -> void:
	var cent: PlayerOutfit = PlayerOutfits.outfit(&"centurion")
	check(cent != null, "the Centurion's file builds")
	if cent == null:
		return
	# Echo's head, face, scars, hair and copper implant stay his own.
	var echo_head: Array[HumanoidPiece] = PlayerSuit.head_pieces()
	var head: Array[HumanoidPiece] = cent.head_pieces()
	var same: bool = echo_head.size() == head.size()
	for i: int in mini(echo_head.size(), head.size()):
		same = same and echo_head[i].color == head[i].color and echo_head[i].offset == head[i].offset and echo_head[i].glow == head[i].glow
	check(same, "the Centurion keeps Echo's head: his face, scars, hair and copper implant (%d pieces)" % head.size())
	var all: Array[HumanoidPiece] = _all_pieces(cent)
	# The palette as drawn: polished gold, crimson, charcoal and black.
	var gold: Color = Look.GOLD
	var crimson: Color = Look.CRIMSON
	check(gold.r > 0.9 and gold.g > 0.7 and gold.b < 0.35, "the gold is gold")
	check(crimson.r > 0.55 and crimson.g < 0.12 and crimson.b < 0.15, "…and the crimson is crimson")
	var gold_pieces: int = 0
	var polished: int = 0
	var crimson_pieces: int = 0
	for p: HumanoidPiece in all:
		if p.color == gold:
			gold_pieces += 1
			if p.shine >= 0.7:
				polished += 1
		if p.color == crimson or p.color == Look.CRIMSON_DARK:
			crimson_pieces += 1
	check(gold_pieces >= 40 and polished == gold_pieces, "plenty of gold, every piece of it polished metal (%d pieces, %d polished)" % [gold_pieces, polished])
	check(crimson_pieces >= 15, "…and crimson (%d pieces)" % crimson_pieces)
	# Nothing glows: the gold is a metal, so bloom can't wash the armour's shapes out.
	var lit: int = 0
	for p: HumanoidPiece in all:
		if p.glow > 0.0 and p.segment != &"head" and p.segment != &"neck":
			lit += 1
	check(lit == 0, "nothing on the Centurion glows (%d glowing pieces besides Echo's own implant)" % lit)
	# Pauldrons on both shoulders, with layered scale plates; the gold arm in place of Echo's with crimson at its joints.
	var domes: int = 0
	var plates: int = 0
	var left_gold: int = 0
	var left_crimson: int = 0
	for p: HumanoidPiece in cent.body_pieces():
		if p.segment == &"upper_arm" and p.side == HumanoidPiece.Placement.MIRRORED:
			if p.shape == LATHE_SHAPE and p.color == gold:
				domes += 1
			if p.shape == BOX_SHAPE and (p.color == gold or p.color == Look.GOLD_DARK):
				plates += 1
		if p.side == HumanoidPiece.Placement.LEFT and p.segment in [&"upper_arm", &"forearm", &"hand"]:
			if p.color == gold:
				left_gold += 1
			if p.color == Look.CRIMSON or p.color == Look.CRIMSON_DARK:
				left_crimson += 1
	check(domes == 1 and plates == 3, "a gold pauldron on each shoulder (one mirrored piece) with three layered scale plates (%d, %d)" % [domes, plates])
	check(left_gold >= 3 and left_crimson >= 3, "a sleek gold cyber-arm on the left with crimson accents at the joints (%d gold, %d crimson)" % [left_gold, left_crimson])
	# The coat: four skirt panels and two strips of pteruges that swing on their own.
	var panels: Array[HumanoidPanel] = cent.panels()
	var coat: int = 0
	var strips: int = 0
	for panel: HumanoidPanel in panels:
		if panel.length >= 0.4:
			coat += 1
		elif panel.hinge.z < 0.0 and not panel.behind:
			strips += 1
	check(coat == 4 and strips == 2 and panels.size() <= HumanoidRig.MAX_PANELS,
		"a coat of four stiff skirt panels hinged at the waist and two strips of pteruges (%d and %d of %d panels)" % [coat, strips, panels.size()])
	# No weapon: nothing steel-blue or laser-coloured, nothing that glows, and no blade-like prisms on the hands.
	var blades: int = 0
	for p: HumanoidPiece in all:
		if p.color == PlayerSuit.CLAW or p.color == PlayerSuit.LASER_1 or p.color == PlayerSuit.GUNMETAL:
			blades += 1
	check(blades == 0, "no katana, pistol or dagger: none of the power-ups' blade, laser or gunmetal colours (%d)" % blades)
	# Cost: nothing has a material of its own, so the whole look is Echo's draw calls.
	var own: int = 0
	for p: HumanoidPiece in all:
		if p.material != null:
			own += 1
	var empty: int = 0
	for p: HumanoidPiece in all:
		if _triangles(p) == 0:
			empty += 1
	check(empty == 0, "every piece builds at least one triangle (%d empty)" % empty)
	var avatar: PlayerAvatar = _avatar_in(&"centurion")
	avatar.fit_to(tuning.visual_size)
	var echo: PlayerAvatar = _avatar_in(PlayerOutfits.ECHO)
	check(own == 0 and avatar.draw_call_count() == echo.draw_call_count(), "no extra draw call: %d, Echo's own %d" % [avatar.draw_call_count(), echo.draw_call_count()])
	var tris: int = avatar.triangle_count()
	avatar.set_equipment({"claws": true, "armor": true, "shield": true, "weapon_tier": 4, "magnet": true})
	check(tris <= AvatarSuite.TRIANGLE_BUDGET - 452 and avatar.triangle_count() <= AvatarSuite.TRIANGLE_BUDGET,
		"%d triangles bare, %d with every power-up (budget %d)" % [tris, avatar.triangle_count(), AvatarSuite.TRIANGLE_BUDGET])
	avatar.free()
	echo.free()


## The cuirass reads as sculpted muscle under a round emblem, not a cross: the gold plate carries a ring of dark gold round a
## crimson disc with a gold boss, a line right across the plate under the pecs and a slanting stroke under each, and no
## vertical stroke at all.
func _test_cuirass() -> void:
	var cent: PlayerOutfit = PlayerOutfits.outfit(&"centurion")
	var ring: int = 0
	var disc: int = 0
	var boss: int = 0
	var across: int = 0
	var slants: int = 0
	var vertical: int = 0
	for p: HumanoidPiece in cent.body_pieces():
		if p.segment != &"chest":
			continue
		if p.shape != BAND_SHAPE or p.offset.z > -0.1:
			continue
		var w: float = p.size.x / 1.41421
		var h: float = absf(p.profile[1].x - p.profile[0].x)
		var turned: float = absf(p.rotation_degrees.z)
		if p.color == Look.GOLD_DARK and absf(w - h) < 0.001 and w > 0.05 and p.offset.y > 0.12:
			ring += 1
		elif p.color == Look.CRIMSON and absf(w - h) < 0.001 and p.offset.y > 0.12:
			disc += 1
		elif p.color == Look.GOLD and w < 0.02 and absf(p.offset.x) < 0.001:
			boss += 1
		elif p.color == Look.GOLD_DARK and h < 0.01 and w > 0.15 and turned < 1.0:
			across += 1
		elif p.color == Look.GOLD_DARK and h < 0.01 and turned > 10.0 and turned < 25.0:
			slants += 1
		if p.color == Look.GOLD_DARK and h > w * 2.0 and w < 0.02 and turned < 1.0:
			vertical += 1
	check(ring == 2 and disc == 2 and boss == 1, "a round emblem: a dark-gold ring of two squares (an octagon) round a crimson disc and a gold boss (%d, %d, %d)" % [ring, disc, boss])
	check(across == 1 and slants == 2, "the muscles' lines: one across the whole plate and a slanting stroke under each pec (%d, %d)" % [across, slants])
	check(vertical == 0, "no vertical stroke under the emblem (it read as a cross): %d" % vertical)


## The back, what the gameplay camera sees: the gold skull in its laurel wreath between the pauldrons, crimson borders.
func _test_back() -> void:
	var cent: PlayerOutfit = PlayerOutfits.outfit(&"centurion")
	var skull: int = 0
	var leaves: int = 0
	var sockets: int = 0
	var borders: int = 0
	var inside: bool = true
	for p: HumanoidPiece in cent.body_pieces():
		if p.segment != &"chest" or p.shape != BAND_SHAPE or p.offset.z < 0.09:
			continue
		if p.color == Look.GOLD:
			inside = inside and absf(p.offset.x) <= 0.13 and p.offset.y >= 0.0 and p.offset.y <= 0.22
			if absf(p.offset.x) < 0.001 or p.size.x > 0.07:
				skull += 1
			else:
				leaves += 1
		elif p.color == Look.SKULL_EYE:
			sockets += 1
		elif p.color == Look.CRIMSON:
			borders += 1
	check(leaves >= 14 and skull >= 3 and sockets >= 3, "the gold skull (%d plates, %d eye, nose and teeth marks) inside a wreath of %d leaves" % [skull, sockets, leaves])
	check(inside, "…between the pauldrons: inside the coat's width and between the waist and the collar")
	check(borders == 2, "crimson borders down the back of the coat's sides")


## The armor power-up refitted: cool bright plates, lighter than Echo's steel and nothing like the gold.
func _test_armor() -> void:
	var cent: PlayerOutfit = PlayerOutfits.outfit(&"centurion")
	var sets: Dictionary = cent.attachment_overrides()
	check(sets.keys() == [&"armor"], "only the armor set is refitted; the other power-ups are Echo's (%s)" % [sets.keys()])
	var armor: Array = sets[&"armor"]
	var plate: Color = Look.ARMOR_PLATE
	check(plate.b > plate.r + 0.1, "the plates are a cool silver-blue")
	for other: Color in [Look.GOLD, Look.GOLD_DARK, Look.CRIMSON, Look.COAT]:
		check(_distance(plate, other) >= 0.5, "…far from %s in colour (%.2f)" % [other, _distance(plate, other)])
	check(plate.r + plate.g + plate.b > PlayerSuit.ARMOR.r + PlayerSuit.ARMOR.g + PlayerSuit.ARMOR.b, "…lighter than Echo's steel plates")
	var caps: int = 0
	var rims: int = 0
	var on_chest: int = 0
	var cap_top: float = 0.0
	for p: HumanoidPiece in armor:
		if p.color == plate and p.segment == &"upper_arm":
			caps += 1
			cap_top = p.offset.y + p.size.y * 0.5
		if p.color == plate and p.segment == &"chest":
			on_chest += 1
		if p.color == PlayerSuit.ARMOR_EDGE and p.glow > 0.0:
			rims += 1
	check(caps == 1 and on_chest == 2 and rims >= 3, "a cap on each shoulder (one mirrored piece), a plate over the cuirass and a yoke across the back, edged with a pale glow (%d, %d, %d)" % [caps, on_chest, rims])
	# The shoulder caps stand proud of the gold pauldron, so they show from behind.
	var dome_top: float = 0.0
	for p: HumanoidPiece in cent.body_pieces():
		if p.segment == &"upper_arm" and p.shape == LATHE_SHAPE and p.color == Look.GOLD:
			dome_top = p.offset.y + p.profile[p.profile.size() - 1].x
	check(cap_top > dome_top + 0.02, "…standing above the pauldron (the cap's top %.3f, the dome's %.3f)" % [cap_top, dome_top])
	# On the avatar: the set goes on, and takes the same pieces off when the armor breaks.
	var avatar: PlayerAvatar = _avatar_in(&"centurion")
	avatar.fit_to(tuning.visual_size)
	var bare: int = avatar.triangle_count()
	avatar.set_equipment({"armor": true})
	check(avatar.triangle_count() - bare >= 60 and avatar.triangle_count() - bare <= 110, "the armor adds its plates on top (%d triangles)" % (avatar.triangle_count() - bare))
	avatar.set_equipment({"armor": false})
	check(avatar.triangle_count() == bare, "…and breaking takes them off again")
	avatar.free()


## The pteruges swing a little on their own through a run, and the coat's panels with the legs.
func _test_swing() -> void:
	var cent: PlayerOutfit = PlayerOutfits.outfit(&"centurion")
	var panels: Array[HumanoidPanel] = cent.panels()
	var avatar: PlayerAvatar = _avatar_in(&"centurion")
	tree.root.add_child(avatar)
	avatar.fit_to(tuning.visual_size)
	var s: Dictionary = AvatarSuite._state({"distance": 20.0})
	var low: Array[float] = []
	var high: Array[float] = []
	for i: int in panels.size():
		low.append(10.0)
		high.append(-10.0)
	for i: int in 150:
		s["distance"] = float(s["distance"]) + 18.0 * DT
		avatar.animate(s, DT)
		if i > 30:
			for k: int in panels.size():
				var pitch: float = avatar.rig.panel_angles(k).x
				low[k] = minf(low[k], pitch)
				high[k] = maxf(high[k], pitch)
	var moving: int = 0
	for k: int in panels.size():
		if high[k] - low[k] > 0.05:
			moving += 1
	check(moving == panels.size(), "all %d panels (the skirt and the pteruges) swing through a run (%d do)" % [panels.size(), moving])
	tree.root.remove_child(avatar)
	avatar.free()
