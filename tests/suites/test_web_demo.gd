extends TestSuite
## The web demo (GDD §2; task E2): the Neon City including its boss, then a "get the full game" screen
## with store links; no ads, no purchases, no leaderboards.
## - the "Web (demo)" preset: the web_demo feature tag, no thread support (so no cross-origin isolation
##   headers are needed, as portals serve it), a canvas that follows the window, and an exclude filter
##   that matches the data (tools/web/demo_filter.gd; `tools/godot.sh web` updates it);
## - the filter from the data: it leaves out the tracks and riffs the demo never plays and never one it
##   plays, and follows a replaced track (the owner's songs, GDD §11: a new file for a demo track or
##   another track, a track reusing another's file);
## - the resource check: everything the demo's scenes, scripts and data reference is kept by the filter
##   and loads (tools/web/check_pack.gd checks the exported pack itself);
## - the flow as a player goes (tools/web/demo_walk.gd), from the title to the end screen, with the sound
##   library as the export has it: the City's intro, three levels, the boss intro, the Floating Head,
##   the outro, then the store links; nothing the filter leaves out is loaded on the way;
## - no ads, purchases or leaderboards on any screen, at desktop and touch sizes, none offered by the
##   platform and nothing submitted; no endless mode; Reduced flashing in the settings;
## - the store links: from data/platform/store_links.json through the Platform layer to its backend.

const DemoFilter = preload("res://tools/web/demo_filter.gd")
const DemoWalk = preload("res://tools/web/demo_walk.gd")
const STORE_LINKS_PATH: String = "res://data/platform/store_links.json"
## GDD §2: the end screen links to Steam, the App Store and Google Play.
const STORES: Array[String] = ["steam", "app_store", "google_play"]
## The demo's steps in order, from a fresh profile.
const DEMO_STEPS: Array[String] = ["city/intro", "city/1", "city/2", "city/3", "city/boss_intro", "city/boss", "city/outro"]

var main: Node
var music: MusicLibrary
var sfx: SfxLibrary


## The sound library as the web export has it: the sounds its filter leaves out have no file.
class ExportedSfx:
	extends SfxLibrary

	var left_out: PackedStringArray = []

	func has_file(sound: StringName) -> bool:
		return not left_out.has(folder.path_join(String(sound) + ".wav")) and super(sound)


func run() -> void:
	music = load(MusicDirector.LIBRARY_PATH) as MusicLibrary
	sfx = load(App.SFX_PATH) as SfxLibrary
	_test_preset()
	_test_filter_from_data()
	_test_replaced_tracks()
	_test_resources()
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	var saved: Profile = App.profile
	BuildFlavor.set_override(BuildFlavor.Kind.WEB_DEMO)
	Platform.configure_for(BuildFlavor.Kind.WEB_DEMO)
	var stub := Platform.backend as StubBackend
	stub.open_links = false
	await _test_walk()
	await _test_screens()
	await _test_store_links()
	BuildFlavor.set_override(-1)
	Platform.configure_for(BuildFlavor.current())
	UiTheme.touch_override = -1
	App.mobile = DeviceProfile.is_mobile()
	App.show_title()
	await tree.process_frame
	App.profile = saved
	main.queue_free()
	App.main = null
	await tree.process_frame


# --- The preset ------------------------------------------------------------------------------

func _test_preset() -> void:
	var presets: ConfigFile = DemoFilter.load_presets()
	check(presets != null, "export_presets.cfg loads")
	if presets == null:
		return
	var section: String = DemoFilter.preset_section(presets)
	check(section != "", "there is a \"%s\" preset" % DemoFilter.PRESET_NAME)
	if section == "":
		return
	var options: String = section + ".options"
	check(String(presets.get_value(section, "platform", "")) == "Web", "it exports for the web")
	check(DemoFilter.patterns_of(String(presets.get_value(section, "custom_features", ""))).has("web_demo"),
		"with the web_demo feature tag, so the build is the demo flavor (CLAUDE.md principle 6)")
	check(String(presets.get_value(section, "export_filter", "")) == "all_resources", "exporting every resource but those it leaves out")
	check(not bool(presets.get_value(options, "variant/thread_support", true)),
		"without thread support: no cross-origin isolation headers needed, as itch.io and the portals serve it")
	check(not bool(presets.get_value(options, "variant/extensions_support", true)), "without GDExtension support (the lighter engine)")
	check(int(presets.get_value(options, "html/canvas_resize_policy", -1)) == 2,
		"its canvas follows the window (adaptive), in a page or a portal's frame")
	check(bool(presets.get_value(options, "html/focus_canvas_on_start", false)), "the keyboard works at once")
	check(not bool(presets.get_value(options, "progressive_web_app/enabled", true)), "no installable web app (a service worker) for the demo")
	var head: String = String(presets.get_value(options, "html/head_include", ""))
	check(head.contains("orientation: portrait") and head.contains("pointer: coarse") and head.contains("sideways")
		and head.contains("DESIGN-TBD"), "a phone held upright is asked to turn sideways (the game is landscape, GDD §2)")
	var includes: PackedStringArray = DemoFilter.patterns_of(String(presets.get_value(section, "include_filter", "")))
	check(includes.has("*.json") and includes.has("assets/fonts/*/OFL.txt"), "it takes the data read as text and the font licenses")
	# The filter matches the data.
	var have: PackedStringArray = DemoFilter.patterns_of(DemoFilter.preset_filter())
	var want: PackedStringArray = DemoFilter.patterns_of(DemoFilter.expected())
	var missing := PackedStringArray()
	var extra := PackedStringArray()
	for p: String in want:
		if not have.has(p):
			missing.append(p)
	for p: String in have:
		if not want.has(p):
			extra.append(p)
	check(missing.is_empty() and extra.is_empty(),
		"the preset's exclude filter matches the data; run tools/godot.sh web to update it (missing: %s; not wanted: %s)" % [
		", ".join(missing), ", ".join(extra)])
	# The full game's presets keep every track.
	for other: String in presets.get_sections():
		if other == section or not other.begins_with("preset.") or other.count(".") != 1:
			continue
		var excludes: String = String(presets.get_value(other, "exclude_filter", ""))
		for track: String in music.names():
			check(not DemoFilter.excluded(music.path(StringName(track)), excludes),
				"%s keeps the %s track" % [presets.get_value(other, "name", other), track])


# --- The filter from the data ------------------------------------------------------------------

func _test_filter_from_data() -> void:
	var tracks: PackedStringArray = DemoFilter.demo_tracks(App.campaign)
	check(tracks.has("menu") and tracks.has("city") and tracks.has("zone_1") and tracks.has("boss_1") and tracks.size() == 4,
		"the demo keeps menu/cinematic defaults and the supplied Zone 1 and Boss 1 songs (%s)" % ", ".join(tracks))
	var left_out: PackedStringArray = DemoFilter.left_out_audio(App.campaign, music, sfx)
	var filter: String = DemoFilter.expected()
	for track: String in music.names():
		var file: String = music.path(StringName(track))
		var riff: String = sfx.folder.path_join("%s_%s.wav" % [MusicDirector.LEVEL_COMPLETE, track])
		var has_riff: bool = sfx.names().has("%s_%s" % [MusicDirector.LEVEL_COMPLETE, track])
		if tracks.has(track):
			check(not left_out.has(file) and not DemoFilter.excluded(file, filter), "the demo keeps the %s track" % track)
			check(not has_riff or not DemoFilter.excluded(riff, filter), "and its riff")
		else:
			check(left_out.has(file) and DemoFilter.excluded(file, filter), "the demo leaves out the %s track (%s)" % [track, file])
			check(not has_riff or (left_out.has(riff) and DemoFilter.excluded(riff, filter)), "and its riff")
	# The City's riff is the E riff, the fallback of every level-complete riff.
	var city_riff: StringName = MusicDirector.level_complete_sound(&"city", sfx)
	check(not DemoFilter.excluded(sfx.folder.path_join(String(city_riff) + ".wav"), filter),
		"the demo keeps the City's level-complete riff (%s)" % city_riff)
	check(not DemoFilter.excluded(sfx.folder.path_join(String(MusicDirector.LEVEL_COMPLETE) + ".wav"), filter),
		"and the E riff every other riff falls back on")
	var only_audio: bool = true
	for path: String in left_out:
		only_audio = only_audio and DemoFilter.AUDIO_EXTENSIONS.has(path.get_extension())
	check(only_audio, "it leaves out nothing but music and riffs (%d files)" % left_out.size())
	check(DemoFilter.excluded("res://tests/suites/test_web_demo.gd", filter) and DemoFilter.excluded("res://tools/web/demo_walk.gd", filter)
		and DemoFilter.excluded("res://scripts/bosses/test_boss.gd", filter) and DemoFilter.excluded("res://data/bosses/test_boss.tres", filter),
		"and the tests, the tools and the test boss")
	check(not DemoFilter.excluded("res://scripts/bosses/boss_encounter.gd", filter) and not DemoFilter.excluded("res://data/bosses/city_boss.tres", filter)
		and not DemoFilter.excluded("res://scenes/bosses/floating_head.tscn", filter), "but never the Floating Head or the boss framework")


## GDD §11: the owner's songs will replace the generated tracks, under the same names or new files named
## in the music library. The filter follows the data either way.
func _test_replaced_tracks() -> void:
	var left_out: PackedStringArray
	# The City's song as a new file: it's kept, and the old file left in the folder isn't.
	left_out = DemoFilter.left_out_audio(App.campaign, _music_with(&"city", "res://assets/music/songs/neon_city.ogg"), sfx)
	check(not left_out.has("res://assets/music/songs/neon_city.ogg") and left_out.has(music.path(&"city")),
		"a new City song is kept, and the old file left in the folder is left out")
	# Gangland's song as a new file elsewhere: left out, like the old one.
	left_out = DemoFilter.left_out_audio(App.campaign, _music_with(&"gangland", "res://assets/music/songs/gangland.ogg"), sfx)
	check(left_out.has("res://assets/music/songs/gangland.ogg") and left_out.has(music.path(&"gangland")),
		"a new Gangland song is left out, and so is the old file")
	# The same file name in another format: the old one goes.
	var menu_song: String = music.path(&"menu").get_basename() + ".ogg"
	left_out = DemoFilter.left_out_audio(App.campaign, _music_with(&"menu", menu_song), sfx)
	check(not left_out.has(menu_song) and left_out.has(music.path(&"menu")), "a menu song in another format is kept, the old file goes")
	# A track that reuses the City's file never takes it out of the demo.
	left_out = DemoFilter.left_out_audio(App.campaign, _music_with(&"golden", music.path(&"city")), sfx)
	check(not left_out.has(music.path(&"city")), "a file the demo plays is kept even when another track uses it too")
	check(music.path(&"city") == "res://assets/music/city.wav" and music.path(&"menu") == "res://assets/music/menu.wav",
		"(the real music library is untouched)")


## A copy of the music library with one track's file changed (its own dictionaries: a resource's
## duplicate shares them).
func _music_with(track: StringName, file: String) -> MusicLibrary:
	var out := music.duplicate() as MusicLibrary
	out.files = music.files.duplicate()
	out.volume_db = music.volume_db.duplicate()
	out.bpm = music.bpm.duplicate()
	out.files[String(track)] = file
	return out


# --- The resource check ------------------------------------------------------------------------

## Everything the demo's scenes, scripts and data reference is kept by the preset's filter and loads.
func _test_resources() -> void:
	var filter: String = DemoFilter.preset_filter()
	var refs: Dictionary = _demo_references(filter)
	var left_out := PackedStringArray()
	var missing := PackedStringArray()
	var broken := PackedStringArray()
	for path: String in refs:
		if DemoFilter.excluded(path, filter):
			left_out.append("%s (from %s)" % [path, refs[path]])
		elif not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
			missing.append("%s (from %s)" % [path, refs[path]])
		elif path.get_extension() in ["json", "txt"]:
			if FileAccess.get_file_as_string(path) == "":
				broken.append(path)
		elif load(path) == null:
			broken.append(path)
	check(refs.size() > 300, "the demo's references are found (%d files)" % refs.size())
	check(left_out.is_empty(), "the web demo's filter keeps everything the demo references: %s" % ", ".join(left_out.slice(0, 8)))
	check(missing.is_empty(), "everything the demo references exists: %s" % ", ".join(missing.slice(0, 8)))
	check(broken.is_empty(), "and loads: %s" % ", ".join(broken.slice(0, 8)))
	for path: String in DemoFilter.left_out_audio(App.campaign, music, sfx):
		check(not refs.has(path), "nothing the demo keeps references %s (from %s)" % [path, refs.get(path, "")])


## The res:// files the demo references, each with what referenced it: the main scene, the autoloads,
## the icon and the bus layout; every path written in a script or shader it keeps; the demo zones'
## boss fights and cinematics (named by path); the files the game finds in its folders by name (enemy
## scripts, rules and tunings, the kit's shaders, the patterns); its music and sounds; the data it
## reads as text; and all of their dependencies.
func _demo_references(filter: String) -> Dictionary:
	var refs: Dictionary = {}
	var todo: Array[PackedStringArray] = []
	todo.append(PackedStringArray([String(ProjectSettings.get_setting("application/run/main_scene")), "project.godot"]))
	todo.append(PackedStringArray([String(ProjectSettings.get_setting("application/config/icon")), "project.godot"]))
	todo.append(PackedStringArray([String(ProjectSettings.get_setting("audio/buses/default_bus_layout", "res://default_bus_layout.tres")),
		"project.godot"]))
	for property: Dictionary in ProjectSettings.get_property_list():
		var key: String = property["name"]
		if key.begins_with("autoload/"):
			todo.append(PackedStringArray([String(ProjectSettings.get_setting(key)).trim_prefix("*"), "project.godot"]))
	var literal := RegEx.create_from_string("\"(res://[^\"%]+\\.[a-zA-Z0-9]+)\"")
	for path: String in _files("res://scripts", ["gd", "gdshader", "gdshaderinc"]) + _files("res://scenes", ["tscn"]):
		if DemoFilter.excluded(path, filter):
			continue
		todo.append(PackedStringArray([path, "the scripts"]))
		if path.get_extension() == "tscn":
			continue
		for m: RegExMatch in literal.search_all(FileAccess.get_file_as_string(path)):
			todo.append(PackedStringArray([m.get_string(1), path]))
	for zone: ZoneDef in App.campaign.zones:
		if not zone.in_demo:
			continue
		if zone.boss != null:
			for scene: String in [zone.boss.scene, zone.boss.preview_scene]:
				todo.append(PackedStringArray([scene, "%s's boss" % zone.id]))
		for cinematic: CinematicDef in [zone.intro, zone.boss_intro, zone.outro]:
			if cinematic != null:
				todo.append(PackedStringArray([cinematic.scene, "%s's cinematics" % zone.id]))
	for folder: String in [EnemyDirector.SCRIPTS_DIR, EnemyDirector.TUNING_DIR, MeshKit.SHADER_DIR.trim_suffix("/"), "res://data/patterns"]:
		for path: String in _files(folder, ["gd", "tres", "gdshader", "gdshaderinc", "json"]):
			todo.append(PackedStringArray([path, folder]))
	var tracks: PackedStringArray = DemoFilter.demo_tracks(App.campaign)
	for path: String in DemoFilter.demo_audio_files(music, sfx, tracks):
		todo.append(PackedStringArray([path, "the demo's music and sounds"]))
	for path: String in ["res://data/shop/catalog.json", "res://data/hints/hints.json", Platform.STORE_LINKS_PATH]:
		todo.append(PackedStringArray([path, "data read as text"]))
	for font: Array in SettingsScreen.FONT_LICENSES:
		todo.append(PackedStringArray([String(font[1]), "the settings' font licenses"]))
	while not todo.is_empty():
		var item: PackedStringArray = todo.pop_back()
		var path: String = item[0]
		if path == "" or refs.has(path):
			continue
		refs[path] = item[1]
		if not ResourceLoader.exists(path):
			continue
		for dep: String in ResourceLoader.get_dependencies(path):
			var dep_path: String = dep.get_slice("::", dep.get_slice_count("::") - 1) if dep.contains("::") else dep
			if dep_path.begins_with("uid://"):
				dep_path = ResourceUID.get_id_path(ResourceUID.text_to_id(dep_path))
			todo.append(PackedStringArray([dep_path, path]))
	return refs


## Every file under `folder` with one of the extensions (res:// paths).
func _files(folder: String, extensions: Array) -> PackedStringArray:
	var out := PackedStringArray()
	if not DirAccess.dir_exists_absolute(folder):
		return out
	for file_name: String in DirAccess.get_files_at(folder):
		if extensions.has(file_name.get_extension()):
			out.append(folder.path_join(file_name))
	for dir_name: String in DirAccess.get_directories_at(folder):
		out.append_array(_files(folder.path_join(dir_name), extensions))
	return out


# --- The flow ----------------------------------------------------------------------------------

## A new player's demo, from the title to the end screen, with the sound library as the export has it.
func _test_walk() -> void:
	App.profile = SampleProfiles.fresh()
	var left_out: PackedStringArray = DemoFilter.left_out_audio(App.campaign, music, sfx)
	var exported := ExportedSfx.new()
	exported.folder = sfx.folder
	exported.volume_db = sfx.volume_db
	exported.pitch_variation = sfx.pitch_variation
	exported.left_out = left_out
	var real_sfx: SfxLibrary = App.sfx_library
	App.sfx_library = exported
	# Start clean: earlier suites loaded every track and sound into the libraries' caches.
	(sfx.get(&"_cache") as Dictionary).clear()
	(music.get(&"_cache") as Dictionary).clear()
	App.show_title()
	await physics_frames(90)
	var walk := DemoWalk.new(tree)
	walk.watch = left_out
	walk.probe()
	var held: PackedStringArray = PackedStringArray(walk.loaded.keys())
	walk.loaded.clear()
	check(held.is_empty(), "nothing the filter leaves out is loaded before the walk (%s)" % ", ".join(held))
	var stub := Platform.backend as StubBackend
	stub.scores.clear()
	var reached: bool = await walk.walk()
	check(reached, "the demo plays from the title to its end screen: %s" % "; ".join(walk.problems))
	check(", ".join(walk.steps) == ", ".join(DEMO_STEPS),
		"through the City's intro, its three levels, the boss intro, the Floating Head and the outro (%s)" % ", ".join(walk.steps))
	check(walk.screens.size() > 0 and walk.screens[-1] == "DemoEndScreen", "and ends on the \"get the full game\" screen")
	print("  web demo walk: %s" % "; ".join(walk.runs))
	var boss_run: String = ""
	for r: String in walk.runs:
		if r.begins_with("city/boss:"):
			boss_run = r
	check(boss_run.contains("Floating Head"), "the demo's boss is the Floating Head (%s)" % boss_run)
	check(App.profile.is_completed("city/boss") and App.profile.is_completed("city/3"), "its steps count as done")
	check(walk.offers.is_empty(), "no screen on the way offers ads, purchases or leaderboards: %s" % "; ".join(walk.offers))
	check(stub.scores.is_empty(), "nothing goes to a leaderboard (%s)" % ", ".join(stub.scores.keys()))
	check(walk.loaded.is_empty(), "nothing the filter leaves out is loaded on the way: %s" % ", ".join(walk.loaded.keys()))
	App.sfx_library = real_sfx


# --- Screens: no ads, purchases or leaderboards -----------------------------------------------

## Every screen the demo can show, at desktop and touch sizes and on a phone: nothing offers ads,
## purchases or leaderboards, the platform offers none, there's no endless mode, and the settings have
## Reduced flashing.
func _test_screens() -> void:
	check(not Platform.ads_available() and not Platform.purchases_available() and not Platform.leaderboards_available()
		and Platform.products().is_empty(), "the demo's platform offers no ads, purchases or leaderboards (GDD §2)")
	var walk := DemoWalk.new(tree)
	for touch: int in [0, 1]:
		UiTheme.touch_override = touch
		App.mobile = touch == 1
		var tag: String = "touch" if touch == 1 else "desktop"
		App.profile = SampleProfiles.rich()
		App.profile.add_stock(&"revive", 1)
		var screens: Array = [
			["title", func() -> void: App.show_title()],
			["level select", func() -> void: App.show_level_select()],
			["shop", func() -> void: App.show_shop()],
			["settings", func() -> void: App.show_settings()],
			["demo end", func() -> void: App.show_demo_end()],
		]
		for entry: Array in screens:
			(entry[1] as Callable).call()
			await tree.process_frame
			await tree.process_frame
			var found: PackedStringArray = walk.find_offers(App.screen)
			check(found.is_empty(), "the %s offers no ads, purchases or leaderboards (%s): %s" % [entry[0], tag, ", ".join(found)])
			if App.screen is TitleScreen:
				check(not (App.screen as TitleScreen).buttons.has("endless"), "the title has no endless mode (%s)" % tag)
			if App.screen is ShopScreen:
				check((App.screen as ShopScreen).pack_buttons.is_empty(), "the shop sells no credit packs (%s)" % tag)
			if App.screen is SettingsScreen:
				check((App.screen as SettingsScreen).toggles.has("reduced_flashing"), "the settings have Reduced flashing (%s)" % tag)
		# In a level: the pause menu, and a death's revive offer.
		App.play_step(App.campaign.step("city/1"))
		App.begin_run()
		await physics_frames(5)
		App.pause_game()
		await tree.process_frame
		var paused: PackedStringArray = walk.find_offers(App.overlay)
		check(App.overlay is PauseScreen and paused.is_empty(), "the pause menu offers none (%s): %s" % [tag, ", ".join(paused)])
		App.resume_game()
		await physics_frames(2)
		App.run.world.player._die("test hazard")
		await physics_frames(int((App.rules.death_screen_delay + 0.3) * 60.0))
		await tree.process_frame
		var death := App.overlay as DeathScreen
		check(death != null and not death.buttons.has("ad") and death.buttons.has("item"),
			"a death offers the revive item, never an ad (%s)" % tag)
		var at_death: PackedStringArray = walk.find_offers(App.overlay)
		check(at_death.is_empty(), "the revive offer mentions no ads (%s): %s" % [tag, ", ".join(at_death)])
		App.decline_revive()
		await tree.process_frame
		await tree.process_frame
		var summary: PackedStringArray = walk.find_offers(App.screen)
		check(App.screen is ResultsScreen and summary.is_empty(), "the run summary offers none (%s): %s" % [tag, ", ".join(summary)])
	UiTheme.touch_override = -1
	App.mobile = DeviceProfile.is_mobile()
	App.show_title()
	await tree.process_frame


# --- The store links ---------------------------------------------------------------------------

## GDD §2: the end screen links to Steam, the App Store and Google Play; the links are data
## (placeholders until the store pages exist) and open through the Platform layer.
func _test_store_links() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(STORE_LINKS_PATH))
	check(data is Dictionary, "the store links are data (%s)" % STORE_LINKS_PATH)
	if not data is Dictionary:
		return
	var links: Dictionary = data
	var stores: PackedStringArray = Platform.store_names()
	check(", ".join(stores) == ", ".join(STORES), "for Steam, the App Store and Google Play, in that order (%s)" % ", ".join(stores))
	check(String(links.get("_note", "")).contains("DESIGN-TBD"), "marked as placeholders until the store pages exist")
	App.show_demo_end()
	await tree.process_frame
	var end := App.screen as DemoEndScreen
	check(end != null, "the demo's end screen opens")
	if end == null:
		return
	check(", ".join(PackedStringArray(end.store_buttons.keys())) == ", ".join(STORES), "with a tile for each store")
	var stub := Platform.backend as StubBackend
	for store: String in STORES:
		var url: String = String(links.get(store, ""))
		check(url.begins_with("https://") and Platform.store_link(StringName(store)) == url,
			"%s's link comes from the data (%s)" % [store, url])
		var tile := end.store_buttons.get(store) as TileButton
		if tile == null:
			continue
		check(tile.tooltip_text == url, "its tile shows where it leads")
		stub.opened_urls.clear()
		tile.pressed.emit()
		check(stub.opened_urls.size() == 1 and stub.opened_urls[0] == url,
			"and opens it through the Platform layer's backend (%s)" % ", ".join(stub.opened_urls))
	check(App.screen == end, "opening a store leaves the end screen up")
	end.menu_button.pressed.emit()
	await tree.process_frame
	check(App.screen is TitleScreen, "and the end screen leads back to the menu")
