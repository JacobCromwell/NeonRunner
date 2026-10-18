extends TestSuite
## The runner's outfits (GDD §8, "Cosmetics"; task M1): the catalog lists the five in the owner's order at the owner's
## prices, PlayerOutfits finds an outfit's file by its id and composes it over Razor Echo's skeleton, head and power-up
## sets (an id with no file yet wears a tinted placeholder), the avatar wears the outfit that is worn and can change
## it, every outfit in the catalog builds within test_avatar's triangle and draw-call budgets and keeps Echo's size
## and poses, the owned power-ups still go on top of every one, and the outfit shows wherever the runner is built: the
## gameplay model and a cinematic's runner. Each outfit's own looks have a suite of theirs (test_outfit_rex: Rex's
## glows and jacket); the cosmetics' shop, wallet and save are test_cosmetics.

const AvatarSuite = preload("res://tests/suites/test_avatar.gd")
const DT: float = 1.0 / 60.0
const RUN_SPEED: float = 18.0
const BODY_SEGMENTS: Array[StringName] = [&"pelvis", &"chest", &"upper_arm", &"forearm", &"hand", &"thigh", &"shin", &"foot"]
const HEAD_SEGMENTS: Array[StringName] = [&"neck", &"head"]
const OWNER_ORDER: Array[StringName] = [&"rex", &"camo", &"beach_master", &"centurion", &"party_wolf"]
const OWNER_PRICES: Array[int] = [3000, 3000, 5000, 5000, 5000]

var catalog: ShopCatalog
var _worn_before: StringName = &""


## A stand-in outfit that covers Echo's head: a block over it, and nothing of his own.
class HeadOutfit:
	extends PlayerOutfit

	func body_pieces() -> Array[HumanoidPiece]:
		var list: Array[HumanoidPiece] = []
		PlayerOutfit.add(list, &"chest", BOX, Vector3(0.28, 0.3, 0.2), Vector3(0.0, 0.1, 0.0), Color.WHITE)
		return list

	func head_pieces() -> Array[HumanoidPiece]:
		var list: Array[HumanoidPiece] = []
		PlayerOutfit.add(list, &"head", BOX, Vector3(0.2, 0.2, 0.2), Vector3(0.0, 0.08, 0.0), Color.GRAY)
		return list


## A stand-in outfit that adds to Echo's head (a hat) and refits his armor.
class HatOutfit:
	extends PlayerOutfit

	func body_pieces() -> Array[HumanoidPiece]:
		var list: Array[HumanoidPiece] = []
		PlayerOutfit.add(list, &"chest", BOX, Vector3(0.28, 0.3, 0.2), Vector3(0.0, 0.1, 0.0), Color.WHITE)
		return list

	func head_pieces() -> Array[HumanoidPiece]:
		var list: Array[HumanoidPiece] = super()
		PlayerOutfit.add(list, &"head", BOX, Vector3(0.18, 0.05, 0.18), Vector3(0.0, 0.2, 0.0), Color.BLACK)
		return list

	func attachment_overrides() -> Dictionary:
		var list: Array[HumanoidPiece] = []
		PlayerOutfit.add(list, &"chest", BOX, Vector3(0.1, 0.1, 0.02), Vector3(0.0, 0.15, -0.13), Color.RED)
		return {&"armor": list}


func run() -> void:
	catalog = ShopCatalog.load_from()
	_worn_before = PlayerOutfits.worn
	_test_catalog()
	_test_registry()
	_test_composition()
	_test_head_and_overrides()
	_test_budgets_and_fit()
	_test_poses_and_equipment()
	_test_avatar_changes_outfit()
	await _test_worn_everywhere()
	_test_base_look_is_untouched()
	PlayerOutfits.worn = _worn_before
	PlayerOutfits.clear_cache()


## Every outfit the shop lists, Razor Echo's own look first.
func _ids() -> Array[StringName]:
	var out: Array[StringName] = [PlayerOutfits.ECHO]
	for c: ShopCosmetic in catalog.cosmetics:
		out.append(c.id)
	return out


# --- The catalog --------------------------------------------------------------------

func _test_catalog() -> void:
	var ids: Array[StringName] = []
	var prices: Array[int] = []
	for c: ShopCosmetic in catalog.cosmetics:
		ids.append(c.id)
		prices.append(c.price)
	check(ids == OWNER_ORDER, "the catalog lists the five outfits in the owner's order (%s)" % [ids])
	check(prices == OWNER_PRICES, "Rex and Camo are 3,000 credits and the other three 5,000 for now (%s)" % [prices])
	check(catalog.default_cosmetic.id == PlayerOutfits.ECHO and catalog.default_cosmetic.price == 0
		and catalog.default_cosmetic.display_name == "Razor Echo", "Razor Echo's own look is the free default")
	check(catalog.cosmetic(PlayerOutfits.ECHO) == catalog.default_cosmetic and catalog.cosmetic(&"rex") == catalog.cosmetics[0]
		and catalog.cosmetic(&"nope") == null, "cosmetic() finds the default and the outfits by id")
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ShopCatalog.PATH))
	var tbd: PackedStringArray = []
	var names_ok: bool = true
	for d: Dictionary in raw["cosmetics"]:
		if String(d.get("_note", "")).begins_with("DESIGN-TBD"):
			tbd.append(String(d["id"]))
		names_ok = names_ok and String(d.get("name", "")) != "" and String(d.get("description", "")) != "" \
			and String(d.get("color", "")).begins_with("#")
	check(tbd == PackedStringArray(["beach_master", "centurion", "party_wolf"]),
		"the three outfits meant to be won mark their 5,000 DESIGN-TBD in the data (%s)" % [tbd])
	check(String(raw["_cosmetics_note"]).contains("DESIGN-TBD") and names_ok, "the data note says so, and every entry has a name, text and colour")
	var clash: bool = false
	for c: ShopCosmetic in catalog.cosmetics:
		clash = clash or catalog.item(c.id) != null or not String(c.id).is_valid_ascii_identifier()
	check(not clash, "cosmetics are not items (no tiers, stock or loadout) and their ids are plain identifiers")


# --- The registry -------------------------------------------------------------------

func _test_registry() -> void:
	check(PlayerOutfits.is_built(PlayerOutfits.ECHO) and PlayerOutfits.is_built(&"rex") and not PlayerOutfits.is_built(&"nope"),
		"Echo and Rex have their looks, an id with no file has none")
	check(PlayerOutfits.script_path(&"rex") == "res://scripts/player/outfits/rex.gd"
		and PlayerOutfits.script_path(&"../player") == "" and PlayerOutfits.script_path(&"a b") == ""
		and not PlayerOutfits.is_built(&"../player_suit"), "an outfit's file is named by its id, and an id can't name another path")
	check(PlayerOutfits.is_known(&"rex") and PlayerOutfits.is_known(&"party_wolf") and PlayerOutfits.is_known(PlayerOutfits.ECHO)
		and not PlayerOutfits.is_known(&"nope"), "every catalog id is known, others aren't")
	check(PlayerOutfits.resolve(&"rex") == &"rex" and PlayerOutfits.resolve(&"nope") == PlayerOutfits.ECHO,
		"an unknown id is Razor Echo's own look")
	check(PlayerOutfits.outfit(&"rex") is PlayerOutfit and PlayerOutfits.outfit(PlayerOutfits.ECHO) == null
		and PlayerOutfits.outfit(&"nope") == null, "a built outfit is a PlayerOutfit, Echo's own look and an unknown id are not")
	check(PlayerOutfits.parts_for(PlayerOutfits.ECHO) == PlayerSuit.parts() and PlayerOutfits.parts_for(&"rex") == PlayerOutfits.parts_for(&"rex"),
		"Echo's parts are the PlayerSuit's, an outfit's are built once")
	check(PlayerOutfits.parts_for(&"rex") != PlayerSuit.parts(), "Rex has parts of his own")


# --- Composing an outfit --------------------------------------------------------------

func _test_composition() -> void:
	var base: HumanoidParts = PlayerSuit.parts()
	var keys: Dictionary = {}
	for id: StringName in _ids():
		var parts: HumanoidParts = PlayerOutfits.parts_for(id)
		check(not keys.has(parts.cache_key), "%s: its meshes are cached under a key of its own (%s)" % [id, parts.cache_key])
		keys[parts.cache_key] = true
		check(parts.design_size == PlayerSuit.DESIGN_SIZE and parts.hip_offset == base.hip_offset
			and is_equal_approx(parts.thigh_length, base.thigh_length) and is_equal_approx(parts.shin_length, base.shin_length)
			and is_equal_approx(parts.ankle_height, base.ankle_height) and parts.chest_offset == base.chest_offset
			and parts.neck_offset == base.neck_offset and parts.head_offset == base.head_offset
			and parts.shoulder_offset == base.shoulder_offset and is_equal_approx(parts.upper_arm_length, base.upper_arm_length)
			and is_equal_approx(parts.forearm_length, base.forearm_length),
			"%s: Echo's skeleton and size, so every pose and the hitbox are the same" % id)
		check(parts.panels.size() <= HumanoidRig.MAX_PANELS, "%s: no more panels than the rig swings" % id)
		var off: PackedStringArray = []
		var head_pieces: int = 0
		for piece: HumanoidPiece in parts.pieces:
			if piece.segment in HEAD_SEGMENTS:
				head_pieces += 1
			elif not piece.segment in BODY_SEGMENTS:
				off.append(String(piece.segment))
		check(off.is_empty() and head_pieces > 0 and parts.pieces.size() > head_pieces,
			"%s: a body and a head on the rig's segments (%s)" % [id, ", ".join(off)])
		for set_name: StringName in base.attachments:
			check(parts.attachments.has(set_name), "%s: it carries the %s set" % [id, set_name])
	# A built outfit's two lists keep to their segments.
	for id: StringName in _ids():
		var made: PlayerOutfit = PlayerOutfits.outfit(id)
		if made == null:
			continue
		var wrong: PackedStringArray = []
		for piece: HumanoidPiece in made.body_pieces():
			if not piece.segment in BODY_SEGMENTS:
				wrong.append("body piece on %s" % piece.segment)
		for piece: HumanoidPiece in made.head_pieces():
			if not piece.segment in HEAD_SEGMENTS:
				wrong.append("head piece on %s" % piece.segment)
		check(wrong.is_empty(), "%s: body_pieces() is the body and head_pieces() the neck and head (%s)" % [id, ", ".join(wrong)])
	# A placeholder: Echo's look with the body washed toward the catalog's colour, his head and glows untouched.
	for c: ShopCosmetic in catalog.cosmetics:
		if PlayerOutfits.is_built(c.id):
			continue
		var parts: HumanoidParts = PlayerOutfits.parts_for(c.id)
		var changed: int = 0
		var untouched: bool = parts.pieces.size() == base.pieces.size()
		for i: int in mini(parts.pieces.size(), base.pieces.size()):
			var piece: HumanoidPiece = parts.pieces[i]
			var source: HumanoidPiece = base.pieces[i]
			if piece.color != source.color:
				changed += 1
			if piece.glow > 0.0 or piece.segment in HEAD_SEGMENTS:
				untouched = untouched and piece.color == source.color
		check(changed > 20 and untouched and parts.panels.size() == base.panels.size(),
			"%s: not built yet, it wears Echo's look washed toward its colour (%d pieces), his head and glows as they are" % [c.id, changed])


## An outfit may cover the head or add to it, and refit a power-up's set.
func _test_head_and_overrides() -> void:
	var base: HumanoidParts = PlayerSuit.parts()
	var cover := PlayerOutfits.compose(HeadOutfit.new(), &"test_cover")
	var head_colours: Array[Color] = []
	for piece: HumanoidPiece in cover.pieces:
		if piece.segment in HEAD_SEGMENTS:
			head_colours.append(piece.color)
	check(head_colours == [Color.GRAY], "an outfit that covers the head replaces Echo's (no neck, face or hair: %d pieces)" % head_colours.size())
	var hat := PlayerOutfits.compose(HatOutfit.new(), &"test_hat")
	var echo_head: Array[HumanoidPiece] = PlayerSuit.head_pieces()
	var hat_head: int = 0
	for piece: HumanoidPiece in hat.pieces:
		if piece.segment in HEAD_SEGMENTS:
			hat_head += 1
	check(hat_head == echo_head.size() + 1, "an outfit that adds to the head (super() and a hat) keeps all of his: %d pieces" % hat_head)
	check(hat.attachments[&"armor"] != base.attachments[&"armor"] and (hat.attachments[&"armor"] as Array).size() == 1
		and hat.attachments[&"weapon_2"] == base.attachments[&"weapon_2"] and hat.attachments[&"claws"] == base.attachments[&"claws"],
		"an outfit's refit replaces the one set (here the armor, a single plate) and leaves the others Echo's")
	HumanoidParts.clear_cache()


# --- Budgets, size and poses ------------------------------------------------------------

func _avatar_in(id: StringName) -> PlayerAvatar:
	PlayerOutfits.worn = id
	var avatar := PlayerAvatar.new()
	PlayerOutfits.worn = _worn_before
	return avatar


func _test_budgets_and_fit() -> void:
	var vis: Vector3 = tuning.visual_size
	var echo_scale: Vector3 = Vector3.ZERO
	for id: StringName in _ids():
		var avatar: PlayerAvatar = _avatar_in(id)
		avatar.fit_to(vis)
		check(avatar.outfit() == id, "%s: the avatar wears it" % id)
		var tris: int = avatar.triangle_count()
		var calls: int = avatar.draw_call_count()
		check(tris <= AvatarSuite.TRIANGLE_BUDGET and calls <= AvatarSuite.DRAW_CALL_BUDGET,
			"%s: %d triangles and %d draw calls (budgets %d and %d)" % [id, tris, calls, AvatarSuite.TRIANGLE_BUDGET, AvatarSuite.DRAW_CALL_BUDGET])
		avatar.set_equipment({"claws": true, "armor": true, "shield": true, "weapon_tier": 4, "magnet": true})
		tris = avatar.triangle_count()
		calls = avatar.draw_call_count()
		check(tris <= AvatarSuite.TRIANGLE_BUDGET and calls <= AvatarSuite.DRAW_CALL_BUDGET,
			"%s with every power-up: %d triangles and %d draw calls" % [id, tris, calls])
		avatar.set_equipment({"claws": false, "armor": false, "shield": false, "weapon_tier": 0, "magnet": false})
		if id == PlayerOutfits.ECHO:
			echo_scale = avatar.rig.scale
		check(avatar.rig.scale.is_equal_approx(echo_scale), "%s: fitted to the same size as Echo (%s)" % [id, avatar.rig.scale])
		# The run pose, as test_avatar measures it: the hair tips average the design height, nothing is taller,
		# the feet reach the ground, and the width stays inside the hitbox's visual.
		var s: Dictionary = AvatarSuite._state({"distance": 50.0})
		for i: int in 30:
			s["distance"] = float(s["distance"]) + RUN_SPEED * DT
			avatar.animate(s, DT)
		var mean: float = 0.0
		var box := AABB()
		for i: int in 120:
			s["distance"] = float(s["distance"]) + RUN_SPEED * DT
			avatar.animate(s, DT)
			var b: AABB = avatar.rig.bounds()
			mean += b.end.y / 120.0
			box = b if i == 0 else box.merge(b)
		check(absf(mean - vis.y) <= vis.y * 0.03, "%s: the hair tips average %.3f m in the run (visual_size.y %.2f ±3%%)" % [id, mean, vis.y])
		check(box.end.y <= vis.y * 1.04 and box.position.y > -0.01 and box.position.y < 0.01,
			"%s: never taller than visual_size.y + 4%% (%.3f m), and the feet reach the ground (%.3f m)" % [id, box.end.y, box.position.y])
		check(box.size.x <= vis.x * 1.02 and box.size.x >= vis.x * 0.75, "%s: %.3f m wide in the run (visual_size.x %.2f)" % [id, box.size.x, vis.x])
		avatar.free()


## Every pose runs, the slide stays under a gapped fence, and each power-up changes the avatar's meshes.
func _test_poses_and_equipment() -> void:
	var states: Dictionary = {
		"idle": {"speed": 0.0}, "run": {}, "jump": {"grounded": false, "vh": 7.0}, "fall": {"grounded": false, "vh": -7.0},
		"slide": {"sliding": true}, "dash": {"dashing": true}, "stomp": {"grounded": false, "vh": -22.0, "stomping": true},
		"wall": {"surface": "wall", "grounded": false, "wall_side": 1}, "ceiling": {"surface": "ceiling"},
		"lane switch": {"switch_dir": 1}, "dead": {"alive": false},
	}
	var echo_muzzle: Vector3 = _muzzle_in(PlayerOutfits.ECHO)
	for id: StringName in _ids():
		var avatar: PlayerAvatar = _avatar_in(id)
		tree.root.add_child(avatar)
		avatar.fit_to(tuning.visual_size)
		var finite: bool = true
		for pose: String in states:
			avatar.reset()
			var s: Dictionary = AvatarSuite._state(states[pose])
			for i: int in 90:
				s["distance"] = float(s["distance"]) + float(s["speed"]) * DT
				avatar.animate(s, DT)
			var b: AABB = avatar.rig.bounds()
			finite = finite and b.position.is_finite() and b.size.is_finite() and b.size.y > 0.2 and AvatarSuite._joints_finite(avatar.rig)
			if pose == "slide":
				check(b.end.y < tuning.fence_gapped_bottom - 0.1, "%s: sliding, %.2f m high, under a gapped fence" % [id, b.end.y])
			if pose == "dead":
				check(b.end.y < tuning.visual_size.y * 0.45, "%s: dead, it has collapsed (%.2f m)" % [id, b.end.y])
		check(finite, "%s: every pose gives a finite pose" % id)
		# The owned power-ups go on top: each adds its pieces to the meshes and keeps its place.
		avatar.reset()
		var bare: int = avatar.triangle_count()
		for look: Dictionary in [{"claws": true}, {"armor": true}, {"weapon_tier": 1}, {"weapon_tier": 4}, {"magnet": true}]:
			avatar.set_equipment({"claws": false, "armor": false, "weapon_tier": 0, "magnet": false})
			avatar.set_equipment(look)
			check(avatar.triangle_count() > bare and not avatar.rig.attachments().is_empty(),
				"%s: %s goes on top of the outfit (%d more triangles)" % [id, look, avatar.triangle_count() - bare])
		avatar.queue_free()
		var muzzle: Vector3 = _muzzle_in(id)
		check(muzzle.is_equal_approx(echo_muzzle), "%s: the weapon fires from where Echo's does (%s)" % [id, muzzle])


## Where the tier 2 weapon's muzzle is, in the avatar's own frame, for a runner in `id` standing idle.
func _muzzle_in(id: StringName) -> Vector3:
	var avatar: PlayerAvatar = _avatar_in(id)
	tree.root.add_child(avatar)
	avatar.fit_to(tuning.visual_size)
	avatar.set_equipment({"weapon_tier": 2})
	avatar.animate(AvatarSuite._state({"speed": 0.0}), DT)
	var muzzle: Vector3 = avatar.to_local(avatar.weapon_muzzle())
	avatar.queue_free()
	return muzzle


# --- The avatar and the worn outfit ------------------------------------------------------------

func _test_avatar_changes_outfit() -> void:
	PlayerOutfits.worn = &"rex"
	var avatar := PlayerAvatar.new()
	check(avatar.outfit() == &"rex" and avatar.rig.parts == PlayerOutfits.parts_for(&"rex"), "a new avatar wears the outfit that is worn")
	PlayerOutfits.worn = &"nope"
	var unknown := PlayerAvatar.new()
	check(unknown.outfit() == PlayerOutfits.ECHO and unknown.rig.parts == PlayerSuit.parts(), "a worn id nobody knows is Echo's own look")
	PlayerOutfits.worn = PlayerOutfits.ECHO
	avatar.fit_to(tuning.visual_size)
	avatar.set_equipment({"claws": true, "armor": true, "weapon_tier": 3})
	var s: Dictionary = AvatarSuite._state()
	for i: int in 40:
		s["distance"] = float(s["distance"]) + RUN_SPEED * DT
		avatar.animate(s, DT)
	var scale_before: Vector3 = avatar.rig.scale
	var rex_tris: int = avatar.triangle_count()
	avatar.set_outfit(&"echo")
	var fresh := PlayerAvatar.new()
	fresh.fit_to(tuning.visual_size)
	fresh.set_equipment({"claws": true, "armor": true, "weapon_tier": 3})
	check(avatar.outfit() == PlayerOutfits.ECHO and avatar.rig.parts == PlayerSuit.parts() and avatar.triangle_count() == fresh.triangle_count()
		and avatar.triangle_count() != rex_tris, "set_outfit puts Echo's own look back on")
	check(avatar.get_equipment() == fresh.get_equipment() and avatar.rig.attachments() == fresh.rig.attachments()
		and avatar.rig.scale.is_equal_approx(scale_before), "…keeping the equipment and the size fit")
	var b: AABB = avatar.rig.bounds()
	check(b.size.is_finite() and b.end.y > tuning.visual_size.y * 0.8 and b.position.y > -0.05 and b.position.y < 0.05,
		"…and the pose, standing on the ground at once (%s)" % b)
	avatar.set_outfit(&"rex")
	check(avatar.outfit() == &"rex" and avatar.triangle_count() == rex_tris, "and Rex again")
	avatar.set_outfit(&"nope")
	check(avatar.outfit() == PlayerOutfits.ECHO, "set_outfit with an unknown id is Echo's own look")
	# Avatars in the same outfit share the built meshes.
	var a := _avatar_in(&"rex")
	var c := _avatar_in(&"rex")
	check(a.rig.part_instances()[1].mesh == c.rig.part_instances()[1].mesh, "avatars in one outfit share its meshes")
	for node: PlayerAvatar in [avatar, unknown, fresh, a, c]:
		node.free()


## The outfit shows wherever the runner is built: the gameplay model and a cinematic's runner.
func _test_worn_everywhere() -> void:
	PlayerOutfits.worn = &"rex"
	var world := Node3D.new()
	tree.root.add_child(world)
	var player := Player.new()
	world.add_child(player)
	var geo := TrackGeometry.new(3, tuning)
	player.setup(tuning, geo, 1)
	var avatar: PlayerAvatar = AvatarSuite._find_avatar(player)
	check(avatar != null and avatar.outfit() == &"rex", "the Player's model wears the outfit that is worn")
	var stages := Node3D.new()
	world.add_child(stages)
	var actor := CineActor.new()
	actor.kind = CineActor.Kind.RUNNER
	var node := CineActorNode.new()
	stages.add_child(node)
	node.setup(actor, null, tuning, &"", 0)
	check(node.avatar != null and node.avatar.outfit() == &"rex", "a cinematic's runner wears it too")
	PlayerOutfits.worn = PlayerOutfits.ECHO
	var plain := CineActorNode.new()
	stages.add_child(plain)
	plain.setup(actor, null, tuning, &"", 0)
	check(plain.avatar != null and plain.avatar.outfit() == PlayerOutfits.ECHO, "and Echo's own look again once that is worn")
	world.queue_free()
	await tree.process_frame


## The base look is what it was: wearing an outfit never edits it (the colour rule's checks in test_avatar are on it).
func _test_base_look_is_untouched() -> void:
	PlayerOutfits.worn = &"rex"
	var base: HumanoidParts = PlayerSuit.parts()
	var copper: int = 0
	for piece: HumanoidPiece in base.pieces:
		if piece.glow > 0.0 and piece.color == PlayerSuit.GLOW:
			copper += 1
	check(copper >= 10 and PlayerOutfits.parts_for(PlayerOutfits.ECHO) == base,
		"Echo's own look keeps its copper glow (the colour rule) while an outfit is worn; the outfits are free of it (GDD §8, Cosmetics)")
	PlayerOutfits.worn = PlayerOutfits.ECHO
