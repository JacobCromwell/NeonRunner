extends TestSuite
## The Rex outfit (GDD §8, "Cosmetics"; brief docs/art/BRIEF_OUTFIT_REX.md; task M1): it keeps Echo's head, has no
## skirt and no rifle, glows in the brief's three colours as drawn (pink circuit lines, a cyan spine, an orange shoulder
## joint: outfits are free of the colour rule) and keeps them soft, its jacket is magenta leather, and its glow lines
## power down on death and take the invulnerability tint like Echo's conduits. That it builds within the avatar's
## budgets, keeps Echo's size and poses and carries the power-ups is test_outfits's, over every outfit.

const AvatarSuite = preload("res://tests/suites/test_avatar.gd")
const RexLook = preload("res://scripts/player/outfits/rex.gd")
## Outfits are free of the colour rule (GDD §8, Cosmetics), so what they glow in isn't checked against the hazard
## colours. Their glows are kept soft all the same: the brightest a line gets while dashing, as test_avatar measures
## the base look's (its limit is 1.25), a little more for the outfit's own brighter colours.
const MAX_OUTFIT_EMISSION: float = 1.4
const DT: float = 1.0 / 60.0

var _worn_before: StringName = &""


func run() -> void:
	_worn_before = PlayerOutfits.worn
	_test_rex()
	PlayerOutfits.worn = _worn_before


func _avatar_in(id: StringName) -> PlayerAvatar:
	PlayerOutfits.worn = id
	var avatar := PlayerAvatar.new()
	PlayerOutfits.worn = _worn_before
	return avatar


func _test_rex() -> void:
	var rex: PlayerOutfit = PlayerOutfits.outfit(&"rex")
	check(rex != null, "Rex's file builds")
	if rex == null:
		return
	var echo_head: Array[HumanoidPiece] = PlayerSuit.head_pieces()
	var rex_head: Array[HumanoidPiece] = rex.head_pieces()
	var same_head: bool = echo_head.size() == rex_head.size()
	for i: int in mini(echo_head.size(), rex_head.size()):
		same_head = same_head and echo_head[i].color == rex_head[i].color and echo_head[i].offset == rex_head[i].offset \
			and echo_head[i].glow == rex_head[i].glow
	check(same_head, "Rex keeps Echo's head: his face, scars, hair and copper implant (%d pieces)" % rex_head.size())
	check(rex.panels().is_empty() and rex.attachment_overrides().is_empty(),
		"Rex is a waist-length jacket: no skirt panels, and Echo's power-up sets fit it as they are")
	# The glows are the brief's three, as drawn, and soft.
	var glows: Dictionary = {}
	var energy: float = PlayerSuit.body_material().get_shader_parameter(&"glow_energy")
	var brightest: float = 0.0
	for piece: HumanoidPiece in rex.body_pieces():
		if piece.glow > 0.0:
			glows[piece.color] = int(glows.get(piece.color, 0)) + 1
			brightest = maxf(brightest, piece.glow * energy * PlayerAvatar.DASH_GLOW * maxf(piece.color.r, maxf(piece.color.g, piece.color.b)))
	var expected: Array = [RexLook.CIRCUIT, RexLook.SPINE, RexLook.JOINT]
	check(glows.size() == 3 and glows.has(expected[0]) and glows.has(expected[1]) and glows.has(expected[2]),
		"it glows pink (circuit lines), cyan (the spine) and orange (the shoulder joint), as drawn: %d colours" % glows.size())
	check(int(glows.get(expected[0], 0)) >= 8 and int(glows.get(expected[1], 0)) >= 4 and int(glows.get(expected[2], 0)) == 1,
		"…many thin pink lines, a spine of several, one joint (%s)" % [glows.values()])
	check(brightest <= MAX_OUTFIT_EMISSION, "…and soft: the brightest line while dashing is %.2f× its colour (limit %.2f)" % [brightest, MAX_OUTFIT_EMISSION])
	check(RexLook.JACKET.r > 0.6 and RexLook.JACKET.g < 0.2 and RexLook.JACKET.b > 0.3 and RexLook.JACKET.b < 0.7,
		"the jacket is magenta leather")
	# The glow lines go dark on death like Echo's conduits.
	var avatar: PlayerAvatar = _avatar_in(&"rex")
	avatar.fit_to(tuning.visual_size)
	avatar.reset()
	var s: Dictionary = AvatarSuite._state({"alive": false})
	for i: int in 120:
		avatar.animate(s, DT)
	var material: ShaderMaterial = avatar._material
	check(float(material.get_shader_parameter(&"glow_boost")) < 0.15, "its glow lines power down on death (%.2f)" % float(material.get_shader_parameter(&"glow_boost")))
	avatar.set_flash(true)
	var tint: Color = material.get_shader_parameter(&"tint")
	check(tint.a > 0.3, "the invulnerability tint covers the outfit too")
	avatar.free()
