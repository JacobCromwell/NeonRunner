extends TestSuite
## The Camo outfit (GDD §8, "Cosmetics"; brief docs/art/BRIEF_OUTFIT_CAMO.md; task M2): it keeps Echo's head, carries no
## weapon (the sword, pistol, grenades and knife of the concept sheet are left out) and glows nowhere, its coat is an
## olive that reads on dark tracks, its cyber-arm is dull brass rather than Echo's polished gold, dark tubing runs across
## the upper back, and the long coat's skirt is four panels that swing with the stride, never go through a knee, never
## sink into the ground and trail behind in a slide, while the suit-glow effects (the invulnerability tint, the death
## power-down) still work on an outfit with no glow lines. That it builds within the avatar's budgets, keeps Echo's size
## and poses and carries the power-ups is test_outfits's, over every outfit; the decals it is printed with are
## test_outfit_decals's.

const AvatarSuite = preload("res://tests/suites/test_avatar.gd")
const CamoLook = preload("res://scripts/player/outfits/camo.gd")
const DT: float = 1.0 / 60.0
const RUN_SPEED: float = 18.0
## No piece of an outfit's body is longer than this (a katana would be a metre): a guard for "no weapons".
const MAX_PIECE_LENGTH: float = 0.36

var _worn_before: StringName = &""


func run() -> void:
	_worn_before = PlayerOutfits.worn
	_test_pieces()
	_test_colours()
	_test_skirt()
	_test_suit_effects()
	PlayerOutfits.worn = _worn_before


func _avatar_in(id: StringName) -> PlayerAvatar:
	PlayerOutfits.worn = id
	var avatar := PlayerAvatar.new()
	PlayerOutfits.worn = _worn_before
	return avatar


static func _luminance(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


## The longest side of a piece as authored (a pipe's length is its height, a sheet's its width or height).
static func _length(piece: HumanoidPiece) -> float:
	var top: float = piece.size.y
	if piece.shape == HumanoidPiece.Shape.BAND or piece.shape == HumanoidPiece.Shape.LATHE:
		top = 0.0
		for ring: Vector4 in piece.profile:
			top = maxf(top, absf(ring.x - piece.profile[0].x))
	return maxf(top, maxf(piece.size.x, piece.size.z))


func _test_pieces() -> void:
	var camo: PlayerOutfit = PlayerOutfits.outfit(&"camo")
	check(camo != null and PlayerOutfits.is_built(&"camo"), "Camo's file builds, so the shop's LOOK IN PROGRESS caption goes")
	if camo == null:
		return
	var echo_head: Array[HumanoidPiece] = PlayerSuit.head_pieces()
	var camo_head: Array[HumanoidPiece] = camo.head_pieces()
	var same_head: bool = echo_head.size() == camo_head.size()
	for i: int in mini(echo_head.size(), camo_head.size()):
		same_head = same_head and echo_head[i].color == camo_head[i].color and echo_head[i].offset == camo_head[i].offset \
			and echo_head[i].glow == camo_head[i].glow
	check(same_head, "Camo keeps Echo's head: his face, scars, hair and copper implant (%d pieces)" % camo_head.size())
	check(camo.attachment_overrides().is_empty(), "Echo's power-up sets fit it as they are")
	# Nothing glows: the coat, the carrier and the arm are unlit.
	var lit: int = 0
	var longest: float = 0.0
	var longest_at: String = ""
	var all: Array[HumanoidPiece] = camo.body_pieces()
	for panel: HumanoidPanel in camo.panels():
		for piece: HumanoidPiece in panel.pieces:
			lit += 1 if piece.glow > 0.0 else 0
	for piece: HumanoidPiece in all:
		lit += 1 if piece.glow > 0.0 else 0
		var length: float = _length(piece)
		if length > longest:
			longest = length
			longest_at = "%s %s" % [piece.segment, piece.shape]
	check(lit == 0, "nothing on Camo glows but Echo's own implant (%d lit pieces)" % lit)
	check(longest <= MAX_PIECE_LENGTH, "no piece is a blade: the longest is %.2f m (%s; limit %.2f m)" % [longest, longest_at, MAX_PIECE_LENGTH])
	# The dark tubing across the upper back: dark pipes on the chest's back.
	var tubes: int = 0
	for piece: HumanoidPiece in all:
		if piece.segment == &"chest" and piece.color == CamoLook.TUBE and piece.offset.z > 0.08:
			tubes += 1
	check(tubes >= 6, "dark tubing runs across the upper back (%d pipes)" % tubes)
	# The plate carrier's pouches in front, and the belt's pouches behind.
	var pouches: int = 0
	for piece: HumanoidPiece in all:
		if (piece.color == CamoLook.CARRIER_DARK) and piece.shape == HumanoidPiece.Shape.BOX:
			pouches += 1
	check(pouches >= 2, "the plate carrier and the belt carry pouches (%d)" % pouches)
	# The left arm is the brass one, on the arm's three segments, and the right arm has no cyber parts.
	var left: Dictionary = {}
	for piece: HumanoidPiece in all:
		if piece.side == HumanoidPiece.Placement.LEFT and piece.segment in [&"upper_arm", &"forearm", &"hand"]:
			left[piece.segment] = int(left.get(piece.segment, 0)) + 1
	check(left.size() == 3 and int(left[&"upper_arm"]) >= 6 and int(left[&"forearm"]) >= 4 and int(left[&"hand"]) >= 3,
		"an armoured cyber-arm with plates, exposed joints and a hand replaces Echo's gold one (%s)" % [left])


func _test_colours() -> void:
	# An olive coat, lighter than Echo's dark blue one so it reads on a night road, with the shared rim light on.
	var olive: Color = CamoLook.OLIVE
	check(olive.h > 0.15 and olive.h < 0.3 and olive.s > 0.3, "the coat is olive (hue %.2f, saturation %.2f)" % [olive.h, olive.s])
	check(_luminance(olive) >= _luminance(PlayerSuit.COAT) * 1.2,
		"…and lighter than Echo's coat, so it keeps its outline on dark tracks (%.2f against %.2f)" % [_luminance(olive), _luminance(PlayerSuit.COAT)])
	var avatar: PlayerAvatar = _avatar_in(&"camo")
	var rim: float = float(avatar.rig.material.get_shader_parameter(&"rim_strength"))
	check(rim > 0.0, "the body's rim light, which edges a dark coat on dark ground, is on (%.2f)" % rim)
	avatar.free()
	# The arm's brass is a dull worn metal: darker and less polished than Echo's gold, so it isn't treasure or a power-up.
	var brass: Color = CamoLook.BRASS
	check(brass.v < PlayerSuit.GOLD.v - 0.25 and CamoLook.BRASS_SHINE < PlayerSuit.GOLD_SHINE * 0.5,
		"the brass is dull (value %.2f against the gold's %.2f, shine %.2f against %.2f)" % [brass.v, PlayerSuit.GOLD.v, CamoLook.BRASS_SHINE, PlayerSuit.GOLD_SHINE])
	var camo: PlayerOutfit = PlayerOutfits.outfit(&"camo")
	var plates: int = 0
	for piece: HumanoidPiece in camo.body_pieces():
		if piece.color == CamoLook.BRASS and piece.side == HumanoidPiece.Placement.LEFT:
			plates += 1
			check(piece.shine < PlayerSuit.GOLD_SHINE, "a brass plate is never as polished as Echo's gold")
	check(plates >= 6, "the arm is brass in %d plates" % plates)
	# The coat's camo: patches in at least four colours across the back and the skirt.
	var colours: Dictionary = {}
	for piece: HumanoidPiece in camo.body_pieces():
		if piece.segment == &"chest" and piece.offset.z > 0.08 and piece.shape == HumanoidPiece.Shape.BAND:
			colours[piece.color] = true
	for panel: HumanoidPanel in camo.panels():
		for piece: HumanoidPiece in panel.pieces:
			if piece.shape == HumanoidPiece.Shape.BAND:
				colours[piece.color] = true
	check(colours.size() >= 4, "the coat's back and skirt are patched in %d camo colours" % colours.size())
	# The skirt's patches and stained hems really draw (an oval ring's faces sit at no tidy angle: M2's first build aimed
	# at tidy ones and built none): nine patches and a hem band on each of the four panels.
	var patches: int = 0
	var hems: int = 0
	for panel: HumanoidPanel in camo.panels():
		for piece: HumanoidPiece in panel.pieces:
			if piece.shape == HumanoidPiece.Shape.BAND:
				var builder := HumanoidMeshBuilder.new()
				builder.add_piece(piece, panel.side < 0)
				patches += 1 if builder.triangle_count() == 2 else 0
				hems += 1 if builder.triangle_count() >= 4 else 0
	check(patches == 9 and hems == 4, "the skirt's 9 camo patches draw two triangles each and its 4 hem bands several (%d, %d)" % [patches, hems])


## The long coat's skirt: four panels (two behind the legs, two at the open front) in one mesh, hanging from the belt to
## below the knee, swinging with the stride without passing through a knee, never below the ground, trailing in a slide.
func _test_skirt() -> void:
	var avatar: PlayerAvatar = _avatar_in(&"camo")
	avatar.fit_to(tuning.visual_size)
	tree.root.add_child(avatar)
	var rig: HumanoidRig = avatar.rig
	var back: Array[int] = []
	for i: int in rig.panel_count():
		if rig.parts.panels[i].behind:
			back.append(i)
	check(rig.panel_count() == 4 and back.size() == 2 and rig.panel_instance().mesh.get_surface_count() == 1,
		"the coat is four panels, two behind the legs and two in front, in one mesh (%d)" % rig.panel_count())
	# Standing: the hem is below the knee and above the boot's ankle.
	avatar.reset()
	var s: Dictionary = AvatarSuite._state({"speed": 0.0})
	for i: int in 90:
		avatar.animate(s, DT)
	var knee: float = rig.joint(&"shin_r").global_position.y - avatar.global_position.y
	var low: float = INF
	for i: int in rig.panel_count():
		low = minf(low, rig.panel_hem(i).y)
	check(low < knee - 0.05 and low > 0.12, "standing, the coat hangs from the belt to below the knee: hem %.2f m, knee %.2f m" % [low, knee])
	# Running: the panels swing, a knee never goes through a back panel, no hem goes below the ground.
	avatar.reset()
	s = AvatarSuite._state({"distance": 30.0})
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
			var pitch: float = rig.panel_angles(i).x
			lowest[i] = minf(lowest[i], pitch)
			highest[i] = maxf(highest[i], pitch)
			ground = minf(ground, rig.panel_hem(i).y)
		for i: int in back:
			through = maxf(through, AvatarSuite._knee_angle(rig, i) - rig.panel_angles(i).x)
	var swing: float = INF
	for i: int in rig.panel_count():
		swing = minf(swing, rad_to_deg(highest[i] - lowest[i]))
	check(swing > 12.0, "running, every panel swings with the stride (at least %.0f°)" % swing)
	check(through < 0.01, "running, a knee never passes through a back panel (%.3f rad at worst)" % through)
	check(ground > -0.01, "running, no hem goes below the ground (lowest %.3f m)" % ground)
	# Sliding feet first: the back panels trail behind along the ground.
	avatar.reset()
	s = AvatarSuite._state({"sliding": true})
	for i: int in 40:
		avatar.animate(s, DT)
	var trail: bool = true
	var pelvis_z: float = AvatarSuite._joint_z(avatar, &"pelvis")
	ground = INF
	for i: int in rig.panel_count():
		ground = minf(ground, rig.panel_hem(i).y)
	for i: int in back:
		trail = trail and rig.panel_angles(i).x > deg_to_rad(60.0) and rig.panel_hem(i).z > pelvis_z + 0.15
	check(trail and ground > -0.01, "sliding, the back panels trail behind and stay above the ground (%.3f m)" % ground)
	avatar.free()


## The suit-glow effects work on an outfit with no glow lines: the glow power-down on death is Echo's implant's, and the
## invulnerability tint covers the whole coat.
func _test_suit_effects() -> void:
	var avatar: PlayerAvatar = _avatar_in(&"camo")
	avatar.fit_to(tuning.visual_size)
	avatar.reset()
	var s: Dictionary = AvatarSuite._state({"alive": false})
	for i: int in 120:
		avatar.animate(s, DT)
	var material: ShaderMaterial = avatar.rig.material as ShaderMaterial
	check(float(material.get_shader_parameter(&"glow_boost")) < 0.15, "the implant powers down on death (%.2f)" % float(material.get_shader_parameter(&"glow_boost")))
	avatar.set_flash(true)
	var tint: Color = material.get_shader_parameter(&"tint")
	check(tint.a > 0.3, "the invulnerability tint covers the coat too")
	avatar.free()
