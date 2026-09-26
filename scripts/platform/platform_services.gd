extends Node
## Autoload "Platform": the one interface to everything platform-specific (CLAUDE.md principle 5):
## rewarded ads, purchases, leaderboards, achievements, store links and cloud save. Gameplay and
## UI call this, never a platform plugin. Each platform provides a PlatformBackend; until the real
## plugins are chosen (risk test R3), every build uses StubBackend, set up by build flavor:
## - full_mobile: simulated ads and purchases, so the mobile flows can be played on a desktop.
## - full_pc: simulated leaderboards (Steam comes later).
## - web_demo: nothing (GDD §2: no ads, purchases or leaderboards), only store links.
## Coroutines (`await Platform.show_rewarded_ad(&"revive")`) resolve when the platform answers.

const STORE_LINKS_PATH: String = "res://data/platform/store_links.json"

var backend: PlatformBackend
var _store_links: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STORE_LINKS_PATH))
	_store_links = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	configure_for(BuildFlavor.current())


## Picks the backend for a build flavor (also used by tests to switch flavors).
func configure_for(flavor: BuildFlavor.Kind) -> void:
	var stub := StubBackend.new()
	stub.tree = get_tree()
	stub.simulate_ads = flavor == BuildFlavor.Kind.FULL_MOBILE
	stub.simulate_purchases = flavor == BuildFlavor.Kind.FULL_MOBILE
	stub.simulate_leaderboards = flavor != BuildFlavor.Kind.WEB_DEMO
	backend = stub


func ads_available() -> bool:
	return backend.ads_available()


## Shows a rewarded ad (player-chosen, GDD §2). True if the reward was earned.
func show_rewarded_ad(placement: StringName) -> bool:
	return await backend.show_rewarded_ad(placement)


func purchases_available() -> bool:
	return backend.purchases_available()


func products() -> Array[Dictionary]:
	return backend.products()


func purchase(product_id: StringName) -> bool:
	return await backend.purchase(product_id)


func leaderboards_available() -> bool:
	return backend.leaderboards_available()


## GDD §6: leaderboards per level and per difficulty tier, plus net worth.
func submit_score(board: String, score: int) -> void:
	if backend.leaderboards_available():
		backend.submit_score(board, score)


func show_leaderboard(board: String) -> void:
	backend.show_leaderboard(board)


func unlock_achievement(id: String) -> void:
	backend.unlock_achievement(id)


## Store names: &"steam", &"app_store", &"google_play".
func store_link(store: StringName) -> String:
	return String(_store_links.get(String(store), ""))


func store_names() -> PackedStringArray:
	var out := PackedStringArray()
	for k: Variant in _store_links:
		if not String(k).begins_with("_"):
			out.append(String(k))
	return out


## Opens a store page (the demo's "get the full game" screen, GDD §2).
func open_store(store: StringName) -> void:
	var url: String = store_link(store)
	if url != "":
		OS.shell_open(url)


func cloud_save_available() -> bool:
	return backend.cloud_save_available()


func cloud_save(data: String) -> void:
	backend.cloud_save(data)


func cloud_load() -> String:
	return await backend.cloud_load()
