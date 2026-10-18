extends TestSuite
## The Beach Master outfit (GDD §8, "Cosmetics"; brief docs/art/BRIEF_OUTFIT_BEACH_MASTER.md; task M2): it keeps Echo's
## head and carries no weapon, its one glow is the skull and palm fronds printed across the shirt's back (green, as the
## sheet draws it: outfits are free of the colour rule), large enough to read from behind, soft, with the eye sockets, nose
## and teeth cut out of it as dark holes, powering down on death and taking the invulnerability tint like Echo's conduits;
## the shirt is dark teal with coral hibiscus, the lower legs are bare, the cyber-arm is corroded and wrapped, and the short
## shirt's hem and open front are four small panels that move a little with the stride without going through a knee. That
## it builds within the avatar's budgets, keeps Echo's size and poses and carries the power-ups is test_outfits's, over
## every outfit; the decals it is printed with are test_outfit_decals's.

const AvatarSuite = preload("res://tests/suites/test_avatar.gd")
const BeachLook = preload("res://scripts/player/outfits/beach_master.gd")
const DT: float = 1.0 / 60.0
const RUN_SPEED: float = 18.0
## The brightest a glowing line gets while dashing (the same cap as Rex's: soft enough that bloom keeps the skull's shape).
const MAX_OUTFIT_EMISSION: float = 1.4
const MAX_PIECE_LENGTH: float = 0.36
## The print is at least this wide and tall on the back, and the skull's crown at least this wide (the shirt is 0.3 m
## across), so it reads from the gameplay camera.
const MIN_PRINT_SIZE := Vector2(0.14, 0.14)
const MIN_CROWN: float = 0.13

var _worn_before: StringName = &""


func run() -> void:
	_worn_before = PlayerOutfits.worn
	_test_pieces()
	_test_back_print()
	_test_look()
	_test_hem()
	_test_suit_effects()
	PlayerOutfits.worn = _worn_before


func _avatar_in(id: StringName) -> PlayerAvatar:
	PlayerOutfits.worn = id
	var avatar := PlayerAvatar.new()
	PlayerOutfits.worn = _worn_before
	return avatar


static func _length(piece: HumanoidPiece) -> float:
	var top: float = piece.size.y
	if piece.shape == HumanoidPiece.Shape.BAND or piece.shape == HumanoidPiece.Shape.LATHE:
		top = 0.0
		for ring: Vector4 in piece.profile:
			top = maxf(top, absf(ring.x - piece.profile[0].x))
	return maxf(top, maxf(piece.size.x, piece.size.z))


func _test_pieces() -> void:
	var beach: PlayerOutfit = PlayerOutfits.outfit(&"beach_master")
	check(beach != null and PlayerOutfits.is_built(&"beach_master"), "Beach Master's file builds, so the shop's LOOK IN PROGRESS caption goes")
	if beach == null:
		return
	var echo_head: Array[HumanoidPiece] = PlayerSuit.head_pieces()
	var head: Array[HumanoidPiece] = beach.head_pieces()
	var same_head: bool = echo_head.size() == head.size()
	for i: int in mini(echo_head.size(), head.size()):
		same_head = same_head and echo_head[i].color == head[i].color and echo_head[i].offset == head[i].offset \
			and echo_head[i].glow == head[i].glow
	check(same_head, "Beach Master keeps Echo's head: his face, scars, hair and copper implant (%d pieces)" % head.size())
	check(beach.attachment_overrides().is_empty(), "Echo's power-up sets fit it as they are")
	var longest: float = 0.0
	var longest_at: String = ""
	for piece: HumanoidPiece in beach.body_pieces():
		var length: float = _length(piece)
		if length > longest:
			longest = length
			longest_at = "%s %s" % [piece.segment, piece.shape]
	check(longest <= MAX_PIECE_LENGTH, "no piece is a blade: the longest is %.2f m (%s; limit %.2f m)" % [longest, longest_at, MAX_PIECE_LENGTH])
	# The carrier's pouches, in front and on the belt.
	var pouches: int = 0
	for piece: HumanoidPiece in beach.body_pieces():
		if piece.color == BeachLook.CARRIER_DARK and piece.shape == HumanoidPiece.Shape.BOX:
			pouches += 1
	check(pouches >= 2, "the plate carrier and the belt carry pouches (%d)" % pouches)


## The skull and the palm fronds: the only glow, on the back, big enough, soft, with dark holes cut in it.
func _test_back_print() -> void:
	var beach: PlayerOutfit = PlayerOutfits.outfit(&"beach_master")
	var energy: float = PlayerSuit.body_material().get_shader_parameter(&"glow_energy")
	var colours: Dictionary = {}
	var lit: Array[HumanoidPiece] = []
	var brightest: float = 0.0
	var everywhere: Array[HumanoidPiece] = beach.body_pieces()
	for panel: HumanoidPanel in beach.panels():
		everywhere.append_array(panel.pieces)
	var all_lit := HumanoidMeshBuilder.new()
	var crown: float = 0.0
	var holes: int = 0
	for piece: HumanoidPiece in everywhere:
		if piece.color == BeachLook.SOCKET:
			check(piece.glow == 0.0, "a dark hole in the skull is unlit")
			holes += 1
		if piece.glow <= 0.0:
			continue
		lit.append(piece)
		colours[piece.color] = int(colours.get(piece.color, 0)) + 1
		brightest = maxf(brightest, piece.glow * energy * PlayerAvatar.DASH_GLOW * maxf(piece.color.r, maxf(piece.color.g, piece.color.b)))
		all_lit.add_piece(piece, false)
		if piece.color == BeachLook.SKULL:
			var one := HumanoidMeshBuilder.new()
			one.add_piece(piece, false)
			crown = maxf(crown, _extent(one.vertices).x)
	var on_back: bool = true
	for piece: HumanoidPiece in lit:
		on_back = on_back and piece.segment == &"chest" and piece.offset.z > 0.09
	check(on_back and lit.size() >= 6, "the only glow is the print on the shirt's back (%d glowing pieces)" % lit.size())
	check(colours.size() == 2 and colours.has(BeachLook.SKULL) and colours.has(BeachLook.FROND),
		"it glows green, as drawn: the skull and its fronds (%d colours)" % colours.size())
	check(BeachLook.SKULL.g > 0.8 and BeachLook.SKULL.r < 0.5 and BeachLook.SKULL.b < 0.6, "…a lime green")
	check(brightest <= MAX_OUTFIT_EMISSION, "…and soft: the brightest piece while dashing is %.2f× its colour (limit %.2f)" % [brightest, MAX_OUTFIT_EMISSION])
	# Its size on the back: the crown is the skull's widest part, the print as a whole covers a patch of the shirt.
	var box: Vector2 = _extent(all_lit.vertices)
	check(crown >= MIN_CROWN, "the skull's crown is %.3f m wide (at least %.2f m)" % [crown, MIN_CROWN])
	check(box.x >= MIN_PRINT_SIZE.x and box.y >= MIN_PRINT_SIZE.y, "the print covers %.2f × %.2f m of the back (at least %.2f × %.2f)"
		% [box.x, box.y, MIN_PRINT_SIZE.x, MIN_PRINT_SIZE.y])
	check(holes >= 6, "the eye sockets, the nose and the teeth are dark holes in it (%d)" % holes)


## The width and height of a set of vertices.
static func _extent(points: PackedVector3Array) -> Vector2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for v: Vector3 in points:
		lo = Vector2(minf(lo.x, v.x), minf(lo.y, v.y))
		hi = Vector2(maxf(hi.x, v.x), maxf(hi.y, v.y))
	return hi - lo


## The look: dark teal with coral hibiscus, bare lower legs, a corroded wrapped arm.
func _test_look() -> void:
	var beach: PlayerOutfit = PlayerOutfits.outfit(&"beach_master")
	var shirt: Color = BeachLook.SHIRT
	check(shirt.h > 0.45 and shirt.h < 0.56 and shirt.v < 0.5, "the shirt is dark teal (hue %.2f, value %.2f)" % [shirt.h, shirt.v])
	var coral: Color = BeachLook.CORAL
	check(coral.r > 0.8 and coral.g < 0.55 and coral.b < 0.45, "…printed with coral hibiscus")
	var blooms: int = 0
	var leaves: int = 0
	var skin: float = 0.0
	var wraps: int = 0
	var patches: int = 0
	for piece: HumanoidPiece in beach.body_pieces():
		if piece.color == BeachLook.CORAL and piece.shape == HumanoidPiece.Shape.BAND:
			blooms += 1
		if piece.color == BeachLook.LEAF:
			leaves += 1
		if piece.segment == &"shin" and piece.color == BeachLook.TAN and piece.size.y > 0.2:
			skin = maxf(skin, piece.size.y)
		if piece.side == HumanoidPiece.Placement.LEFT and (piece.color == BeachLook.WRAP or piece.color == BeachLook.WRAP_DARK):
			wraps += 1
		if piece.side == HumanoidPiece.Placement.LEFT and piece.color == BeachLook.VERDIGRIS:
			patches += 1
	check(blooms >= 4 and leaves >= 6, "coral blooms and palm leaves are printed on the shirt (%d blooms, %d leaves)" % [blooms, leaves])
	check(skin >= 0.2, "the lower legs are bare: a %.2f m tanned shin under the shorts" % skin)
	check(wraps >= 4 and patches >= 4, "the cyber-arm is bound in cloth wraps (%d) and patched with green corrosion (%d)" % [wraps, patches])
	check(BeachLook.RUST.r > BeachLook.RUST.b * 2.0 and BeachLook.CORROSION_SHINE < PlayerSuit.GOLD_SHINE * 0.4,
		"…over rusty, unpolished brass")


## The short shirt's hem and open front: four small panels, not a coat's skirt.
func _test_hem() -> void:
	var avatar: PlayerAvatar = _avatar_in(&"beach_master")
	avatar.fit_to(tuning.visual_size)
	tree.root.add_child(avatar)
	var rig: HumanoidRig = avatar.rig
	var back: Array[int] = []
	var short: bool = true
	for i: int in rig.panel_count():
		short = short and rig.parts.panels[i].length <= 0.15
		if rig.parts.panels[i].behind:
			back.append(i)
	check(rig.panel_count() == 4 and back.size() == 2 and short, "the hem and open front are four short panels (%d), none a coat's skirt" % rig.panel_count())
	avatar.reset()
	var s: Dictionary = AvatarSuite._state({"distance": 30.0})
	for i: int in 60:
		s["distance"] = float(s["distance"]) + RUN_SPEED * DT
		avatar.animate(s, DT)
	var lowest: PackedFloat32Array = [INF, INF, INF, INF]
	var highest: PackedFloat32Array = [-INF, -INF, -INF, -INF]
	var through: float = 0.0
	var ground: float = INF
	for f: int in 120:
		s["distance"] = float(s["distance"]) + RUN_SPEED * DT
		avatar.animate(s, DT)
		for i: int in rig.panel_count():
			lowest[i] = minf(lowest[i], rig.panel_angles(i).x)
			highest[i] = maxf(highest[i], rig.panel_angles(i).x)
			ground = minf(ground, rig.panel_hem(i).y)
		for i: int in back:
			through = maxf(through, AvatarSuite._knee_angle(rig, i) - rig.panel_angles(i).x)
	var swing: float = INF
	for i: int in rig.panel_count():
		swing = minf(swing, rad_to_deg(highest[i] - lowest[i]))
	var prints: int = 0
	var bands: int = 0
	for panel: HumanoidPanel in rig.parts.panels:
		for piece: HumanoidPiece in panel.pieces:
			if piece.shape == HumanoidPiece.Shape.BAND:
				var builder := HumanoidMeshBuilder.new()
				builder.add_piece(piece, panel.side < 0)
				prints += 1 if builder.triangle_count() == 2 else 0
				bands += 1 if builder.triangle_count() >= 4 else 0
	check(prints == 6 and bands == 4, "the hem panels' 6 prints draw two triangles each and their 4 light bands several (%d, %d)" % [prints, bands])
	check(swing > 5.0, "running, the tails and flaps move with the stride (at least %.0f°)" % swing)
	check(through < 0.01 and ground > 0.2, "…a knee never goes through a tail (%.3f rad) and the hems stay well above the ground (%.2f m)" % [through, ground])
	avatar.free()


## The print powers down on death and the tint covers the shirt, like Echo's conduits.
func _test_suit_effects() -> void:
	var avatar: PlayerAvatar = _avatar_in(&"beach_master")
	avatar.fit_to(tuning.visual_size)
	avatar.reset()
	var s: Dictionary = AvatarSuite._state({"alive": false})
	for i: int in 120:
		avatar.animate(s, DT)
	var material: ShaderMaterial = avatar.rig.material as ShaderMaterial
	check(float(material.get_shader_parameter(&"glow_boost")) < 0.15, "the back print goes dark on death (%.2f)" % float(material.get_shader_parameter(&"glow_boost")))
	avatar.reset()
	var dash: Dictionary = AvatarSuite._state({"dashing": true})
	for i: int in 30:
		avatar.animate(dash, DT)
	check(float(material.get_shader_parameter(&"glow_boost")) > 1.2, "…and brightens in a dash like the other glow (%.2f)" % float(material.get_shader_parameter(&"glow_boost")))
	avatar.set_flash(true)
	var tint: Color = material.get_shader_parameter(&"tint")
	check(tint.a > 0.3, "the invulnerability tint covers the shirt too")
	avatar.free()
