class_name MarketCitizens
extends RefCounted
## Builds the Marketplace citizens (GDD §5, "Citizens"; task D3) into the shop windows
## MarketplaceSkin.shop_windows() lists: funny, uplifting scenery seen inside the shops, a warm
## contrast to the cult's feed. Picked and placed purely from the window's track position (seeded,
## like every other piece of this skin: MeshKit.hash_i), so a chunk builds the same citizens every
## time; only the runner-triggered reaction (MarketCitizen) depends on the run.
##
## Keeps windows to one use each: never a feed window (shop_windows()'s `screen`), and never a
## window a window cyborg stands in (MarketplaceSkin.note_wall_enemies(); GDD §9.2 says they must
## read apart, see docs/questions/d3.md). Switched off entirely when Settings.citizens_enabled is
## false (a low-end device, or the player's own choice): CLAUDE.md, "added only if they don't
## noticeably cost performance... and don't add much code complexity."

## Share of eligible windows that get a citizen (DESIGN-TBD, docs/questions/d3.md: kept low so a
## chunk never builds more cards than its performance budget allows; see test_marketplace_citizens).
const CITIZEN_SHARE: float = 0.16
## How far past a window cyborg's own position (its track distance) a citizen still keeps clear,
## wider than its drawn window (WindowCyborgTuning.window_length / 2) so the two are never close
## enough to read as the same thing (DESIGN-TBD, docs/questions/d3.md).
const CYBORG_MARGIN: float = 2.2
## The card's share of the window's full height, standing on the window's own floor.
const CARD_HEIGHT_SHARE: float = 0.86

## Weak: the skin owns this builder (MarketStalls and friends do the same).
var skin: MarketplaceSkin:
	get:
		return _skin.get_ref() as MarketplaceSkin
var _skin: WeakRef


func _init(p_skin: MarketplaceSkin) -> void:
	_skin = weakref(p_skin)


## Adds a MarketCitizen under `parent` for every eligible window on `side` whose centre lies in
## [start, end) and is chosen (CITIZEN_SHARE of them).
func build(parent: Node3D, side: int, face_x: float, start: float, end: float) -> void:
	if not Settings.citizens_enabled:
		return
	for w: Dictionary in skin.shop_windows(side, face_x, start, end):
		if bool(w["screen"]):
			continue
		var at: float = float(w["at"])
		if skin.reserved_near(side, at, CYBORG_MARGIN):
			continue
		var key: int = MeshKit.key(at)
		if MeshKit.hash01(side, key, 211) >= CITIZEN_SHARE:
			continue
		_build_one(parent, w, side, key)


func _build_one(parent: Node3D, w: Dictionary, side: int, key: int) -> void:
	var count: int = CitizenRig.archetype_count()
	var archetype: int = MeshKit.hash_i(side, key, 223) % count
	var tex: Texture2D = load(CitizenSheet.texture_path(CitizenRig.ARCHETYPES[archetype].name))
	if tex == null:
		return  # The sheet hasn't been baked yet (tools/godot.sh citizens): skip rather than crash.
	var bottom: float = float(w["bottom"])
	var top: float = float(w["top"])
	var height: float = (top - bottom) * CARD_HEIGHT_SHARE
	var design: Vector3 = CitizenRig.ARCHETYPES[archetype].design_size
	var width: float = height * (design.x / design.y)
	width = minf(width, float(w["width"]) * 0.6)
	var depth: float = float(w["depth"])
	var center: Vector3 = w["center"]
	var x: float = center.x + side * (depth * 0.5)
	var citizen := MarketCitizen.new()
	citizen.position = Vector3(x, bottom + height * 0.5, center.z)
	var phase: float = MeshKit.hash01(side, key, 229)
	var reaction: StringName = &"startled" if MeshKit.hash01(side, key, 233) < 0.5 else &"cheer"
	citizen.setup(tex, Vector2(width, height), float(w["at"]), phase, reaction)
	parent.add_child(citizen)
