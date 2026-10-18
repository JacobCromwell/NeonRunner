class_name PlayerOutfits
extends RefCounted
## The runner's outfits (GDD §8, "Cosmetics"): which one is worn, and the HumanoidParts of each. An outfit
## is a PlayerOutfit file named after its id in data/shop/catalog.json (`scripts/player/outfits/<id>.gd`);
## this finds it by that name, so adding an outfit never edits this file or any other shared one.
##
## - `worn` is the outfit every PlayerAvatar built from now on wears: the player's gameplay model, the
##   cinematics' runner, the review tools'. App keeps it current from the profile (like
##   Settings.flashing_reduced), and `--outfit=<id>` sets it for a review session. A live avatar changes
##   with PlayerAvatar.set_outfit.
## - `parts_for(id)` is what the avatar's rig is built from (cached): Razor Echo's own PlayerSuit, an
##   outfit composed over his skeleton (`compose`), or, for an id in the catalog whose file isn't written
##   yet, a placeholder (`placeholder_parts`). Any other id is Echo.

## Razor Echo's own look: the free default, always owned.
const ECHO: StringName = &"echo"
## Where the outfit files are.
const DIR: String = "res://scripts/player/outfits/"
## How far a placeholder's body colours move toward the catalog's colour for the outfit.
const PLACEHOLDER_MIX: float = 0.55

## The outfit new avatars wear (an id from the catalog, or ECHO).
static var worn: StringName = ECHO

static var _parts: Dictionary = {}
static var _catalog: ShopCatalog


## The path of an outfit's file ("" for an id that couldn't name one: ids are plain identifiers).
static func script_path(id: StringName) -> String:
	if not String(id).is_valid_ascii_identifier():
		return ""
	return "%s%s.gd" % [DIR, id]


## True for Razor Echo and for an outfit whose file exists.
static func is_built(id: StringName) -> bool:
	if id == ECHO:
		return true
	var path: String = script_path(id)
	return path != "" and ResourceLoader.exists(path)


## True for Razor Echo and for an outfit the shop's catalog lists.
static func is_known(id: StringName) -> bool:
	return id == ECHO or _cosmetic(id) != null


## `id` if it names an outfit (Razor Echo's own look or a catalog cosmetic), otherwise Razor Echo's own look.
static func resolve(id: StringName) -> StringName:
	return id if is_known(id) else ECHO


## The outfit file's instance, or null when there is none (or the file isn't a PlayerOutfit).
static func outfit(id: StringName) -> PlayerOutfit:
	if id == ECHO or not is_built(id):
		return null
	var script := load(script_path(id)) as GDScript
	var made: PlayerOutfit = script.new() as PlayerOutfit if script != null and script.can_instantiate() else null
	if made == null:
		push_warning("PlayerOutfits: %s is not a PlayerOutfit" % script_path(id))
	return made


## What a rig wears for `id` (cached; every avatar with the same outfit shares the meshes).
static func parts_for(id: StringName) -> HumanoidParts:
	if id == ECHO:
		return PlayerSuit.parts()
	if not _parts.has(id):
		var made: PlayerOutfit = outfit(id)
		if made != null:
			_parts[id] = compose(made, id)
		elif _cosmetic(id) != null:
			_parts[id] = placeholder_parts(id)
		else:
			push_warning("PlayerOutfits: no outfit '%s'; wearing Razor Echo's own look" % id)
			_parts[id] = PlayerSuit.parts()
	return _parts[id]


## An outfit over Echo's skeleton and size: its body and head pieces (Echo's head when it keeps it), its
## skirt, and Echo's power-up sets with the outfit's own refits laid over them.
static func compose(made: PlayerOutfit, id: StringName) -> HumanoidParts:
	var base: HumanoidParts = PlayerSuit.parts()
	var parts := base.duplicate() as HumanoidParts
	parts.cache_key = "player_outfit_%s" % id
	var list: Array[HumanoidPiece] = []
	list.append_array(made.body_pieces())
	list.append_array(made.head_pieces())
	parts.pieces = list
	var panels: Array[HumanoidPanel] = []
	panels.append_array(made.panels())
	parts.panels = panels
	var sets: Dictionary = base.attachments.duplicate()
	sets.merge(made.attachment_overrides(), true)
	parts.attachments = sets
	return parts


## DESIGN-TBD: the look of an outfit that is sold before its file is written (Camo, Beach Master,
## Centurion and Party Wolf until M2 and M3 build them): Echo's own look with the coat, arms and boots
## washed toward the outfit's catalog colour, so buying and wearing it works end to end and the change
## shows. His head, glows and power-ups are untouched. Gone as each outfit's file arrives.
static func placeholder_parts(id: StringName) -> HumanoidParts:
	var base: HumanoidParts = PlayerSuit.parts()
	var cosmetic: ShopCosmetic = _cosmetic(id)
	var tint: Color = cosmetic.color if cosmetic != null else Color(0.6, 0.6, 0.65)
	var parts := base.duplicate() as HumanoidParts
	parts.cache_key = "player_outfit_placeholder_%s" % id
	var list: Array[HumanoidPiece] = []
	for source: HumanoidPiece in base.pieces:
		list.append(_washed(source, tint))
	parts.pieces = list
	var panels: Array[HumanoidPanel] = []
	for source: HumanoidPanel in base.panels:
		var panel := source.duplicate() as HumanoidPanel
		var pieces: Array[HumanoidPiece] = []
		for p: HumanoidPiece in source.pieces:
			pieces.append(_washed(p, tint))
		panel.pieces = pieces
		panels.append(panel)
	parts.panels = panels
	return parts


## Forgets the composed parts (a tool that edits an outfit's pieces at runtime), and the catalog read.
static func clear_cache() -> void:
	_parts.clear()
	_catalog = null
	HumanoidParts.clear_cache()


static func _washed(source: HumanoidPiece, tint: Color) -> HumanoidPiece:
	if source.glow > 0.0 or source.segment == &"head" or source.segment == &"neck":
		return source
	var washed := source.duplicate() as HumanoidPiece
	washed.color = source.color.lerp(tint, PLACEHOLDER_MIX)
	return washed


static func _cosmetic(id: StringName) -> ShopCosmetic:
	if _catalog == null:
		_catalog = ShopCatalog.load_from()
	return _catalog.cosmetic(id) if id != ECHO else null
