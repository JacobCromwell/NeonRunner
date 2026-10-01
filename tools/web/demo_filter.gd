extends RefCounted
## The web demo's export filter (task E2), worked out from the data: what the "Web (demo)" preset in
## export_presets.cfg leaves out, and Godot's own filter matching to test a path against it.
##   const DemoFilter = preload("res://tools/web/demo_filter.gd")
##   DemoFilter.expected()            the exclude filter the data asks for
##   DemoFilter.preset_filter()       the preset's exclude filter as it stands
##   DemoFilter.excluded(path, text)  whether an export with that filter leaves `path` out
##   DemoFilter.write_preset(text)    sets the preset's exclude filter (tools/godot.sh web does it)
##
## The demo is the zones marked in_demo (GDD §2: the Neon City and its boss). What it leaves out:
## - the tests, the tools and scratch files, as every preset does;
## - the test boss (outside the campaign; debug builds play it with --boss=test_boss), and the stand-in
##   thief (outside the campaign; debug builds' quick play sends it with --thief);
## - music it never plays: every audio file in the music library's folders that no track it plays
##   uses, and the files of the tracks it never plays, wherever they are;
## - the level-complete riffs of the tracks it never plays (a level ends on the riff of the music
##   playing, MusicDirector.level_complete_sound: level_complete_<track>).
## The tracks it plays are named in the data (demo_tracks): so when the owner's songs replace the
## generated tracks (GDD §11), under the same file names or new ones named in
## data/audio/music_library.tres, `tools/godot.sh web` works the filter out again, and
## test_web_demo.gd fails until the preset matches the data.

const PRESET_NAME: String = "Web (demo)"
const PRESETS_PATH: String = "res://export_presets.cfg"
const CAMPAIGN_PATH: String = "res://data/campaign/campaign.tres"
const MUSIC_PATH: String = "res://data/audio/music_library.tres"
const SFX_PATH: String = "res://data/audio/sfx_library.tres"
## Left out of every export, as in the other presets: the tests, the tools and scratch files.
const SHARED: PackedStringArray = ["tests/*", "tools/*", "build/*"]
## Left out of the demo: the test boss and the stand-in thief, which are outside the campaign (debug
## builds only).
const DEBUG_ONLY: PackedStringArray = ["data/bosses/test_boss*", "scenes/bosses/test_boss*", "scripts/bosses/test_boss*",
	"data/enemies/stand_in_thief*", "scripts/enemies/stand_in_thief*"]
## The files counted as music in the music library's folders.
const AUDIO_EXTENSIONS: PackedStringArray = ["wav", "ogg", "mp3"]
## The menus' track (App plays it by name) and the City's (quick play's and a boss fight's default).
const ALWAYS_PLAYED: PackedStringArray = ["menu", "city"]


## The music tracks the web demo can play: the menus', the City's, each demo zone's and its boss's.
## Music only starts through App._play_music, with these names.
static func demo_tracks(campaign: Campaign) -> PackedStringArray:
	var out := PackedStringArray(ALWAYS_PLAYED)
	for zone: ZoneDef in campaign.zones:
		if not zone.in_demo:
			continue
		for track: StringName in [zone.music, zone.boss.music if zone.boss != null else &""]:
			if track != &"" and not out.has(String(track)):
				out.append(String(track))
	return out


## The sounds the web demo keeps: every sound in the library but the level-complete riffs of the
## music library's tracks it never plays.
static func demo_sounds(sfx: SfxLibrary, music: MusicLibrary, tracks: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for sound: String in sfx.names():
		if not _riff_of_other_track(sound, music, tracks):
			out.append(sound)
	return out


## The res:// files the demo's music and sounds use.
static func demo_audio_files(music: MusicLibrary, sfx: SfxLibrary, tracks: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for track: String in tracks:
		if music.has(StringName(track)) and music.path(StringName(track)) != "":
			out.append(music.path(StringName(track)))
	for sound: String in demo_sounds(sfx, music, tracks):
		out.append(sfx.folder.path_join(sound + ".wav"))
	return out


## The audio files the demo leaves out (res:// paths, sorted), never one it uses.
static func left_out_audio(campaign: Campaign, music: MusicLibrary, sfx: SfxLibrary) -> PackedStringArray:
	var tracks: PackedStringArray = demo_tracks(campaign)
	var keep: PackedStringArray = demo_audio_files(music, sfx, tracks)
	var out := PackedStringArray()
	var folders := PackedStringArray()
	for track: String in music.names():
		var file: String = music.path(StringName(track))
		if file != "" and not folders.has(file.get_base_dir()):
			folders.append(file.get_base_dir())
		if not tracks.has(track) and file != "":
			_add(out, file, keep)
	for folder: String in folders:
		if not DirAccess.dir_exists_absolute(folder):
			continue
		for file_name: String in DirAccess.get_files_at(folder):
			if AUDIO_EXTENSIONS.has(file_name.get_extension().to_lower()):
				_add(out, folder.path_join(file_name), keep)
	for sound: String in sfx.names():
		if _riff_of_other_track(sound, music, tracks):
			_add(out, sfx.folder.path_join(sound + ".wav"), keep)
	out.sort()
	return out


## The exclude filter the data asks for, in the preset's form ("tests/*, tools/*, ...").
static func expected() -> String:
	var patterns := PackedStringArray(SHARED)
	patterns.append_array(DEBUG_ONLY)
	for path: String in left_out_audio(load(CAMPAIGN_PATH) as Campaign, load(MUSIC_PATH) as MusicLibrary,
			load(SFX_PATH) as SfxLibrary):
		patterns.append(path.trim_prefix("res://"))
	return ", ".join(patterns)


## The patterns of a filter text, as Godot's export reads them (comma-separated, trimmed).
static func patterns_of(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	for part: String in text.split(","):
		if part.strip_edges() != "":
			out.append(part.strip_edges())
	return out


## True if an export with this exclude filter leaves `path` out: Godot's export tests every pattern
## against the res:// path and the path without it (EditorExportPlatform::_edit_files_with_filter).
static func excluded(path: String, filter_text: String) -> bool:
	var bare: String = path.trim_prefix("res://")
	for pattern: String in patterns_of(filter_text):
		if path.matchn(pattern) or bare.matchn(pattern):
			return true
	return false


## The web demo preset's section in export_presets.cfg ("preset.3"), or "" if there's none.
static func preset_section(presets: ConfigFile) -> String:
	for section: String in presets.get_sections():
		if section.begins_with("preset.") and section.count(".") == 1 \
				and String(presets.get_value(section, "name", "")) == PRESET_NAME:
			return section
	return ""


static func load_presets() -> ConfigFile:
	var presets := ConfigFile.new()
	return presets if presets.load(PRESETS_PATH) == OK else null


## The preset's exclude filter as it stands ("" if there's no such preset).
static func preset_filter() -> String:
	var presets: ConfigFile = load_presets()
	if presets == null or preset_section(presets) == "":
		return ""
	return String(presets.get_value(preset_section(presets), "exclude_filter", ""))


## Sets the preset's exclude filter, changing only that line of export_presets.cfg (the editor's own
## format stays as it is).
static func write_preset(filter_text: String) -> Error:
	var file := FileAccess.open(PRESETS_PATH, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	var lines: PackedStringArray = file.get_as_text().split("\n")
	file.close()
	var section: String = ""
	var in_demo: bool = false
	var done: bool = false
	for i: int in lines.size():
		var line: String = lines[i]
		if line.begins_with("["):
			section = line.trim_prefix("[").trim_suffix("]")
			in_demo = false
		elif line == "name=\"%s\"" % PRESET_NAME and section.count(".") == 1:
			in_demo = true
		elif in_demo and line.begins_with("exclude_filter="):
			lines[i] = "exclude_filter=\"%s\"" % filter_text.c_escape()
			done = true
	if not done:
		return ERR_DOES_NOT_EXIST
	file = FileAccess.open(PRESETS_PATH, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string("\n".join(lines))
	file.close()
	return OK


## True for level_complete_<track> where the music library lists <track> and the demo never plays it.
static func _riff_of_other_track(sound: String, music: MusicLibrary, tracks: PackedStringArray) -> bool:
	var prefix: String = String(MusicDirector.LEVEL_COMPLETE) + "_"
	var track: String = sound.trim_prefix(prefix)
	return sound.begins_with(prefix) and music.has(StringName(track)) and not tracks.has(track)


static func _add(out: PackedStringArray, path: String, keep: PackedStringArray) -> void:
	if not keep.has(path) and not out.has(path):
		out.append(path)
