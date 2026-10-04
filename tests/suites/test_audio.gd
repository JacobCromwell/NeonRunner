extends TestSuite
## Audio: the buses, seamless generated loops, supplied MP3s (matching, looping and size budgets),
## the Music autoload's API, the death dip and how it combines with the pause duck, the
## level-complete riff in each zone's key, and every sound effect the game calls by name; then the
## run's hooks through the App on the real main scene (the dip on a death, lifted by a revive or a
## restart; the riff for the music playing). Headless, so nothing is heard: the checks use the
## players' state and mix the streams directly. (tests/suites/test_units.gd checks every library
## sound's length.)

const MUSIC_LIBRARY_PATH: String = "res://data/audio/music_library.tres"
const SFX_LIBRARY_PATH: String = "res://data/audio/sfx_library.tres"
## The menus' track and one per zone (GDD §11), with the tempo each loop is built on.
const TRACKS: Dictionary = {
	&"menu": 100.0, &"city": 160.0, &"gangland": 120.0, &"marketplace": 144.0, &"corporate": 112.0,
	&"dead_zone": 84.0, &"golden": 132.0,
}
const SONGS: Dictionary = {
	&"zone_1": "Zone_1_Under_The_Iron_Sky.mp3",
	&"zone_2": "Zone_2_Alleyway_Ambush.mp3",
	&"zone_3": "Zone_3_Jackpot_Plaza.mp3",
	&"zone_4": "Zone_4_Concrete_Fever.mp3",
	&"zone_5": "Zone_5_Beneath_the_Cracks.mp3",
	&"zone_6": "Zone_6_View_from_the_Zenith.mp3",
	&"boss_1": "Boss_1_Apex_Combat_Maneuver.mp3",
}
const SONG_BUDGET_BYTES: int = 30 * 1024 * 1024
## Generated defaults must stay under this in the repo (about 3 MB per 40–60 s loop of 32 kHz PCM).
const MUSIC_BUDGET_BYTES: int = 21 * 1024 * 1024
## And in an exported build, where the loops are QOA-compressed.
const MUSIC_EXPORT_BUDGET_BYTES: int = 5 * 1024 * 1024
## The cyborg bolt is intentionally 1.3x the previous amplitude, while its charge warning and the
## player's laser remain at their existing levels.
const CYBORG_SHOT_BASELINE_DB: float = -5.5
const CYBORG_SHOT_AMPLITUDE_GAIN: float = 1.3
## Sounds other code plays by name: UI, credits, protection, power-ups and weapons, enemies.
const SOUNDS: Array[StringName] = [
	&"ui_move", &"ui_select", &"ui_back", &"ui_buy", &"ui_error", &"ui_equip", &"ui_unlock", &"star", &"countdown", &"go",
	&"credit_1", &"credit_5", &"credit_25", &"credit_100", &"bonus",
	&"armor_break", &"armor_hit", &"armor_back", &"shield_break", &"grapple", &"revive",
	&"dash", &"dash_ready", &"slow_time_on", &"slow_time_off", &"laser_fire", &"missile_fire", &"missile_explode",
	&"enemy_hit", &"stomp",
	&"enemy_death", &"cyborg_charge", &"cyborg_shot", &"truck_bang", &"truck_burst", &"truck_cannon_charge",
	&"truck_cannon", &"truck_rev", &"truck_explode", &"octodog_windup", &"octodog_lunge", &"screech_shake", &"screech_burst",
	&"screech_swipe", &"drone_swoop", &"drone_windup", &"drone_fire", &"drone_crash", &"emp", &"bad_dream_emerge",
	&"bad_dream_shriek", &"bad_dream_slash", &"bad_dream_dissolve",
]
## Attack warnings (CLAUDE.md readability rules): each must sound exactly the same every time.
const WARNINGS: Array[StringName] = [&"fence_warning", &"cyborg_charge", &"truck_bang", &"truck_cannon_charge", &"truck_rev",
	&"octodog_windup", &"screech_shake", &"drone_swoop", &"drone_windup", &"bad_dream_shriek"]


func run() -> void:
	_test_buses()
	_test_music_files()
	_test_supplied_songs()
	await _test_music_api()
	await _test_death_dip()
	_test_level_complete_riffs()
	_test_sound_effects()
	await _test_run_hooks()


func _test_supplied_songs() -> void:
	var library := load(MUSIC_LIBRARY_PATH) as MusicLibrary
	var total_bytes: int = 0
	for track: StringName in SONGS:
		check(library.path(track) == "res://assets/music/" + String(SONGS[track]),
			"'%s' uses the matching supplied file" % track)
		var stream := library.stream(track) as AudioStreamMP3
		check(stream != null, "'%s' loads as an MP3" % track)
		if stream == null:
			continue
		total_bytes += FileAccess.get_file_as_bytes(library.path(track)).size()
		check(stream.loop and is_zero_approx(stream.loop_offset) and stream.get_length() > 1.0,
			"'%s' loops the complete supplied song (%.2f s)" % [track, stream.get_length()])
		check(library.volume_db.has(String(track)) and library.volume(track) < -6.0,
			"'%s' keeps a mix level under the sound effects" % track)
		var playback: AudioStreamPlayback = stream.instantiate_playback()
		playback.start(stream.get_length() - 0.5)
		playback.mix_audio(1.0, int(AudioServer.get_mix_rate()))
		check(playback.is_playing() and absf(playback.get_playback_position() - 0.5) < 0.1,
			"'%s' keeps playing across the end of the song" % track)
		playback.stop()
	check(total_bytes <= SONG_BUDGET_BYTES, "supplied MP3s fit in 30 MB (%.2f MB)" % (total_bytes / 1048576.0))
	check(library.zone_tracks.size() == App.campaign.zones.size(), "one supplied song per campaign zone")
	for index: int in App.campaign.zones.size():
		var zone: ZoneDef = App.campaign.zones[index]
		var expected := StringName("zone_%d" % (index + 1))
		check(library.run_track(zone.music) == expected, "zone %d (%s) uses its matching song" % [index + 1, zone.id])
		check(library.riff_track(expected) == zone.music, "zone %d retains its original completion sound" % (index + 1))
		check(library.stream(zone.music) is AudioStreamWAV, "%s cinematics keep the generated default" % zone.id)
		if zone.boss != null:
			var default_track: StringName = zone.boss.music if zone.boss.music != &"" else zone.music
			var boss_track: StringName = library.run_track(default_track, zone.boss.id)
			check(boss_track == (&"boss_1" if index == 0 else default_track),
				"%s gets a supplied song only when one matches" % zone.boss.id)
	check(library.boss_tracks.size() == 1 and library.riff_track(&"boss_1") == &"city",
		"only Boss 1 is replaced, retaining its original completion sound")
	check(library.run_track(&"city", &"test_boss") == &"city", "the test boss keeps its default song")
	check(library.path(&"menu") == "res://assets/music/menu.wav", "menus keep their original song")
	check(not library.files.values().has("res://assets/music/Horizon_Of_Glass.mp3"), "Horizon of Glass remains unused")


func _test_buses() -> void:
	check(AudioServer.get_bus_name(0) == "Master", "bus 0 is Master")
	var limited: bool = false
	for i: int in AudioServer.get_bus_effect_count(0):
		limited = limited or AudioServer.get_bus_effect(0, i) is AudioEffectHardLimiter
	check(limited, "Master keeps its limiter")
	for bus: StringName in [MusicLibrary.BUS, SfxLibrary.BUS]:
		var index: int = AudioServer.get_bus_index(bus)
		check(index > 0, "bus '%s' exists" % bus)
		check(index > 0 and AudioServer.get_bus_send(index) == &"Master", "bus '%s' feeds Master" % bus)
	check(MusicLibrary.BUS == &"Music" and SfxLibrary.BUS == &"SFX", "bus names stay Music and SFX (settings use them)")

	var library := load(SFX_LIBRARY_PATH) as SfxLibrary
	var sfx := PlayerSfx.new()
	sfx.setup(library)
	var on_sfx: bool = sfx.get_child_count() > 0
	for child: Node in sfx.get_children():
		on_sfx = on_sfx and (child as AudioStreamPlayer).bus == SfxLibrary.BUS
	check(on_sfx, "every PlayerSfx player uses the SFX bus")
	sfx.free()
	var hazard := Hazard.new()
	var telegraph := HazardTelegraph.new()
	hazard.add_child(telegraph)
	telegraph.bind(hazard, library.stream(&"fence_warning"), 0.0, 20.0, 90.0)
	check(telegraph.bus == SfxLibrary.BUS, "hazard warnings use the SFX bus")
	hazard.free()


func _test_music_files() -> void:
	var library := load(MUSIC_LIBRARY_PATH) as MusicLibrary
	check(library != null, "music library loads")
	if library == null:
		return
	var total_bytes: int = 0
	var export_bytes: int = 0
	check(library.names().size() == TRACKS.size() + SONGS.size(),
		"the library lists seven defaults and seven supplied songs (%s)" % ", ".join(library.names()))
	for track: StringName in TRACKS:
		check(library.has(track), "music library has '%s'" % track)
		check(is_equal_approx(float(library.bpm.get(String(track), 0.0)), TRACKS[track]),
			"'%s' is listed at %d BPM (%s)" % [track, TRACKS[track], library.bpm.get(String(track))])
		check(library.volume_db.has(String(track)) and library.volume(track) < -6.0,
			"'%s' has a mix level under the sound effects (%.1f dB)" % [track, library.volume(track)])
		var path: String = library.path(track)
		# A fresh copy as imported, so looping can't come from MusicLibrary.loop_whole().
		var stream := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as AudioStreamWAV
		check(stream != null, "'%s' loads as a WAV stream (%s)" % [track, path])
		if stream == null:
			continue
		total_bytes += FileAccess.get_file_as_bytes(path).size()
		export_bytes += stream.data.size()
		var frames: int = roundi(stream.get_length() * stream.mix_rate)
		check(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and stream.loop_begin == 0 and stream.loop_end >= frames - 1,
			"'%s' is imported as a forward loop over the whole file (%d..%d of %d)" % [track, stream.loop_begin, stream.loop_end, frames])
		check(stream.format == AudioStreamWAV.FORMAT_QOA, "'%s' is imported QOA-compressed" % track)
		var loop_seconds: float = float(stream.loop_end - stream.loop_begin) / stream.mix_rate
		var bar_seconds: float = 240.0 / maxf(float(library.bpm.get(String(track), 0.0)), 1.0)
		var bars: float = loop_seconds / bar_seconds
		check(loop_seconds >= 30.0 and loop_seconds <= 60.0, "'%s' loops every 30–60 s (%.2f s)" % [track, loop_seconds])
		check(absf(bars - roundf(bars)) * bar_seconds * stream.mix_rate < 1.0,
			"'%s' loop is a whole number of bars at its tempo (%.4f bars)" % [track, bars])

		# Real playback runs across the loop point and keeps going.
		var playback: AudioStreamPlayback = stream.instantiate_playback()
		playback.start(loop_seconds - 0.5)
		var mixed: PackedVector2Array = playback.mix_audio(1.0, int(AudioServer.get_mix_rate()))
		check(playback.is_playing() and absf(playback.get_playback_position() - 0.5) < 0.05,
			"'%s' plays on through the loop point (at %.2f s after 1 s from 0.5 s before the end)" % [track, playback.get_playback_position()])
		var after: float = 0.0
		for i: int in range(mixed.size() / 2, mixed.size()):
			after += mixed[i].x * mixed[i].x
		check(linear_to_db(sqrt(after / (mixed.size() / 2))) > -40.0, "'%s' has music, not silence, after the loop point" % track)

		# The seam in the source file: the loop's last sample leads into its first (the guard sample
		# after the loop is a copy of the first), with no fade or silence at either edge.
		var raw := AudioStreamWAV.load_from_file(path, {"compress/mode": 0})
		check(raw.format == AudioStreamWAV.FORMAT_16_BITS and not raw.stereo, "'%s' is 16-bit mono PCM" % track)
		var pcm: PackedByteArray = raw.data
		var n: int = pcm.size() / 2
		check(pcm.decode_s16((n - 1) * 2) == pcm.decode_s16(0), "'%s' ends with a guard sample equal to the loop's first" % track)
		var whole: float = _rms(pcm, 0, n - 1)
		var window: int = roundi(raw.mix_rate * 0.02)
		var head: float = _rms(pcm, 0, window)
		var tail: float = _rms(pcm, n - 1 - window, n - 1)
		check(head > whole * 0.25 and tail > whole * 0.25,
			"'%s' has no fade or gap at the loop point (edges %.0f / %.0f dB vs %.0f dB)" % [track,
				linear_to_db(head), linear_to_db(tail), linear_to_db(whole)])
		var seam: float = absf(float(pcm.decode_s16(0) - pcm.decode_s16((n - 2) * 2))) / 32768.0
		check(seam < _step_percentile(pcm, 0.999), "'%s' has no click at the loop point (step %.3f)" % [track, seam])
	check(total_bytes <= MUSIC_BUDGET_BYTES, "generated defaults fit in %d MB (%.2f MB)" % [MUSIC_BUDGET_BYTES / 1048576, total_bytes / 1048576.0])
	check(export_bytes <= MUSIC_EXPORT_BUDGET_BYTES, "generated defaults fit in %d MB in an exported build (%.2f MB)" % [
		MUSIC_EXPORT_BUDGET_BYTES / 1048576, export_bytes / 1048576.0])


func _test_music_api() -> void:
	var music := tree.root.get_node_or_null(^"Music") as MusicDirector
	check(music != null, "the Music autoload exists")
	if music == null:
		return
	music.stop(0.0)
	check(music.current() == &"" and _players(music).is_empty(), "no music plays by default")

	music.play(&"city", 0.0)
	var players: Array[AudioStreamPlayer] = _players(music)
	check(music.current() == &"city" and is_equal_approx(music.fade_level(&"city"), 1.0), "play() with no fade starts at full level")
	check(players.size() == 1 and players[0].bus == MusicLibrary.BUS and players[0].stream != null, "music plays on the Music bus")
	check(players.size() == 1 and not players[0].playing, "headless runs never start a player")
	music.play(&"city")
	check(_players(music).size() == 1 and is_equal_approx(music.fade_level(&"city"), 1.0), "play() of the playing track does nothing")

	music.play(&"menu", 0.25)
	check(music.current() == &"menu" and _players(music).size() == 2, "play() crossfades: the old track fades out as the new one fades in")
	await _frames(8)
	var out_level: float = music.fade_level(&"city")
	var in_level: float = music.fade_level(&"menu")
	check(out_level > 0.2 and out_level < 0.8 and in_level > 0.2 and in_level < 0.8, "mid-crossfade both tracks are partly up (%.2f / %.2f)" % [out_level, in_level])
	await _frames(12)
	check(_players(music).size() == 1 and is_equal_approx(music.fade_level(&"menu"), 1.0), "after the fade only the new track is left, at full level")

	music.play(&"gangland", 1.0)
	await _frames(15)
	var menu_player: AudioStreamPlayer = _player(music, &"menu")
	music.play(&"menu", 1.0)
	check(_player(music, &"menu") == menu_player and music.fade_level(&"menu") > 0.6,
		"a track still fading out fades back in where it is (%.2f)" % music.fade_level(&"menu"))
	await _frames(70)
	check(_players(music).size() == 1 and music.current() == &"menu", "switching back finishes on the one track")

	var full_db: float = _player(music, &"menu").volume_db
	music.set_ducked(true)
	await _frames(30)
	check(music.is_ducked() and _player(music, &"menu").volume_db < full_db - 3.0, "set_ducked(true) lowers the music")
	music.set_ducked(false)
	await _frames(30)
	check(absf(_player(music, &"menu").volume_db - full_db) < 0.1, "set_ducked(false) brings it back")

	music.stop(0.25)
	check(music.current() == &"", "stop() clears the current track")
	await _frames(20)
	check(_players(music).is_empty(), "stop() fades out and frees the players")
	music.play(&"city", 0.0)
	music.stop(0.0)
	check(_players(music).is_empty(), "stop(0) cuts at once")

	# Zones name their track after their id; a track the library doesn't have (a new zone's, before its
	# music is made) is skipped quietly (no warning) and whatever plays carries on.
	var warnings := WarningCounter.new()
	OS.add_logger(warnings)
	music.play(&"menu", 0.0)
	music.play(&"no_such_zone", 0.0)
	OS.remove_logger(warnings)
	check(music.current() == &"menu" and _players(music).size() == 1 and warnings.count == 0,
		"a track the library doesn't have yet is skipped quietly; the music carries on (%d warnings)" % warnings.count)
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	var library := load(MUSIC_LIBRARY_PATH) as MusicLibrary
	for zone: ZoneDef in campaign.zones:
		check(library.has(zone.music) and library.stream(zone.music) != null,
			"zone %s plays its own track (%s)" % [zone.id, zone.music])
	music.stop(0.0)


## Counts warnings (push_warning and engine warnings) while it's registered with OS.add_logger().
class WarningCounter extends Logger:
	var count: int = 0

	func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			count += 1

	func _log_message(_message: String, _error: bool) -> void:
		pass


## The death dip (GDD §11): the playing track sinks by dip_db and loses its highs over dip_time,
## holds, and comes back over dip_recover_time; with the pause duck the deeper of the two applies and
## either ending leaves the other; another track ends it without swelling the dipped one.
func _test_death_dip() -> void:
	var music := tree.root.get_node_or_null(^"Music") as MusicDirector
	if music == null:
		return
	var library: MusicLibrary = music.library
	check(library.dip_db < library.duck_db and library.dip_lowpass_hz < 8000.0,
		"the death dip goes deeper than the pause duck and loses the highs (%.1f vs %.1f dB, %.0f Hz)" % [
			library.dip_db, library.duck_db, library.dip_lowpass_hz])
	for prop: String in ["duck_db", "duck_time", "dip_db", "dip_lowpass_hz", "dip_time", "dip_recover_time"]:
		check(_is_ranged(library, prop), "MusicLibrary.%s is a ranged export, tunable in F6" % prop)
	check(music.dip_filter != null and _filter_index(music) >= 0, "the Music bus carries the death dip's low-pass")
	music.stop(0.0)
	await _frames(roundi(library.dip_recover_time * 60.0) + 5)
	music.play(&"gangland", 0.0)
	await _frames(2)
	var full_db: float = _player(music, &"gangland").volume_db
	check(not _filter_on(music) and is_equal_approx(music.dip_cutoff_hz(), MusicDirector.OPEN_HZ),
		"the low-pass is switched off until the music dips")

	music.set_dipped(true)
	await _frames(roundi(library.dip_time * 30.0))
	var halfway: float = music.dip_level(&"gangland")
	check(halfway > 0.3 and halfway < 0.7, "the dip goes down gradually (%.2f of the way at half dip_time)" % halfway)
	await _frames(roundi(library.dip_time * 30.0) + 5)
	var dipped_db: float = _player(music, &"gangland").volume_db
	check(music.is_dipped() and absf(dipped_db - (full_db + library.dip_db)) < 0.05,
		"set_dipped(true) sinks the track by dip_db (%.1f to %.1f dB)" % [full_db, dipped_db])
	check(_filter_on(music) and absf(music.dip_cutoff_hz() - library.dip_lowpass_hz) < 1.0,
		"and closes the low-pass to dip_lowpass_hz (%.0f Hz)" % music.dip_cutoff_hz())
	await _frames(60)
	check(absf(_player(music, &"gangland").volume_db - dipped_db) < 0.01, "the dip holds (under the death screen)")

	# Pausing on the death screen: the deeper of the two applies, never both added.
	music.set_ducked(true)
	await _frames(roundi(library.duck_time * 60.0) + 5)
	var both_db: float = _player(music, &"gangland").volume_db
	check(absf(both_db - dipped_db) < 0.05, "ducked while dipped, the music stays at the dip (%.1f dB, not %.1f)" % [
		both_db, full_db + library.dip_db + library.duck_db])
	music.set_ducked(false)
	await _frames(roundi(library.duck_time * 60.0) + 5)
	check(music.is_dipped() and absf(_player(music, &"gangland").volume_db - dipped_db) < 0.05, "the duck ending leaves the dip")
	music.set_ducked(true)
	music.set_dipped(false)
	await _frames(roundi(library.dip_recover_time * 60.0) + 5)
	var paused_db: float = _player(music, &"gangland").volume_db
	check(absf(paused_db - (full_db + library.duck_db)) < 0.05 and not _filter_on(music),
		"the dip ending while paused leaves the duck, and the low-pass opens (%.1f dB)" % paused_db)
	music.set_ducked(false)
	await _frames(roundi(library.duck_time * 60.0) + 5)
	check(absf(_player(music, &"gangland").volume_db - full_db) < 0.05, "with neither, the track is back at its full level")

	# Another track (leaving to the menus) ends the dip: it comes in at its full level, and the dipped
	# one fades out without swelling back up.
	music.set_dipped(true)
	await _frames(roundi(library.dip_time * 60.0) + 5)
	var leaving_db: float = _player(music, &"gangland").volume_db
	music.play(&"menu", 0.5)
	check(not music.is_dipped() and music.dip_level(&"menu") == 0.0, "playing another track ends the dip")
	var swelled: bool = false
	for i: int in 40:
		await tree.process_frame
		var leaving: AudioStreamPlayer = _player(music, &"gangland")
		swelled = swelled or (leaving != null and leaving.volume_db > leaving_db + 0.01)
	check(not swelled, "the dipped track fades out without coming back up")
	check(absf(_player(music, &"menu").volume_db - library.volume(&"menu")) < 0.05, "the new track plays at its full level")
	await _frames(roundi(library.dip_recover_time * 60.0) + 5)
	check(not _filter_on(music), "and the low-pass opens")
	music.set_dipped(true)
	music.stop(0.0)
	check(not music.is_dipped() and _players(music).is_empty(), "stop() ends the dip too")
	await _frames(roundi(library.dip_recover_time * 60.0) + 5)
	check(not _filter_on(music), "and the low-pass opens with nothing playing")


## The level-complete riff (GDD §11: in each zone's key): each zone's music has its riff (the City's is
## the E riff), anything else falls back to the E riff, and every riff is over before the results.
func _test_level_complete_riffs() -> void:
	var sfx := load(SFX_LIBRARY_PATH) as SfxLibrary
	var library := load(MUSIC_LIBRARY_PATH) as MusicLibrary
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	for zone: ZoneDef in campaign.zones:
		var riff: StringName = MusicDirector.level_complete_sound(zone.music, sfx)
		var expected: StringName = MusicDirector.LEVEL_COMPLETE if zone.id == &"city" \
			else StringName("%s_%s" % [MusicDirector.LEVEL_COMPLETE, zone.music])
		check(riff == expected, "%s's levels and boss end on %s (%s)" % [zone.id, expected, riff])
		check(sfx.stream(riff) != null, "%s's riff loads (%s)" % [zone.id, riff])
	check(MusicDirector.level_complete_sound(&"menu", sfx) == MusicDirector.LEVEL_COMPLETE,
		"a track without a riff of its own falls back to the E riff")
	check(MusicDirector.level_complete_sound(&"no_such_track", sfx) == MusicDirector.LEVEL_COMPLETE, "so does an unknown track")
	check(MusicDirector.level_complete_sound(&"", sfx) == MusicDirector.LEVEL_COMPLETE, "and no music at all")
	check(MusicDirector.level_complete_sound(&"gangland", null) == MusicDirector.LEVEL_COMPLETE, "and a missing sound library")
	var riffs: int = 0
	var prefix: String = String(MusicDirector.LEVEL_COMPLETE)
	for sound: String in sfx.names():
		if not sound.begins_with(prefix):
			continue
		riffs += 1
		var raw := AudioStreamWAV.load_from_file(sfx.folder.path_join(sound + ".wav"), {"compress/mode": 0})
		var seconds: float = raw.data.size() / 2.0 / raw.mix_rate if raw != null else 99.0
		check(seconds < LevelRun.COMPLETE_PAUSE,
			"'%s' is over before the results replace the run and its sounds (%.2f s)" % [sound, seconds])
		check(float(sfx.pitch_variation.get(sound, 0.0)) == 0.0, "'%s' always plays in its key (no pitch variation)" % sound)
		check(sound == prefix or library.has(StringName(sound.trim_prefix(prefix + "_"))), "'%s' belongs to a music track" % sound)
	check(riffs == campaign.zones.size(), "one riff per zone: the E riff and five more (%d)" % riffs)


## Through the App on the real main scene: a death dips the zone's music at once, a pause before the
## revive offer doesn't push it further, the offer holds it and a revive lifts it; the level would end
## on the zone's riff; the summary crossfades to the menu music at its full level; quick play's
## restart lifts the dip.
func _test_run_hooks() -> void:
	var music := tree.root.get_node_or_null(^"Music") as MusicDirector
	if music == null:
		return
	var library: MusicLibrary = music.library
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	var saved: Profile = App.profile
	App.profile = Profile.new()
	for zone: ZoneDef in App.campaign.zones:
		var expected: StringName = library.run_track(zone.music)
		for index: int in zone.levels.size():
			App.start_level(App.campaign.step("%s/%d" % [zone.id, index + 1]))
			App.begin_run()
			App.run.world.player.god_mode = true
			App.run.world.player.grapples = 1_000_000
			await physics_frames(2)
			check(music.current() == expected, "%s level %d shares its zone's supplied song" % [zone.id, index + 1])
	App.start_boss(App.campaign.step("city/boss"))
	App.begin_run()
	await physics_frames(2)
	check(music.current() == &"boss_1", "the Floating Head fight plays the supplied Boss 1 song")
	App.profile.add_stock(&"revive", 1)
	App.start_level(App.campaign.step("gangland/1"))
	App.begin_run()
	App.run.world.player.god_mode = true
	App.run.world.player.grapples = 1_000_000
	await _frames(70)
	var full_db: float = library.volume(&"zone_2")
	var track: AudioStreamPlayer = _player(music, &"zone_2")
	check(music.current() == &"zone_2" and track != null and absf(track.volume_db - full_db) < 0.05,
		"a Gangland level plays the Gangland track at its level")
	check(App.run.call(&"_complete_riff") == &"level_complete_gangland", "and would end on Gangland's riff")
	if App.run.tuning_panel != null:
		App.run.tuning_panel.open()
		var sliders: int = 0
		for prop: String in ["duck_db", "duck_time", "dip_db", "dip_lowpass_hz", "dip_time", "dip_recover_time"]:
			var slider: HSlider = App.run.tuning_panel.find_slider(prop)
			if slider != null and is_equal_approx(slider.value, float(library.get(prop))):
				sliders += 1
		App.run.tuning_panel.close()
		check(sliders == 6, "F6 shows the music's duck and dip, on the library the Music autoload plays by (%d of 6)" % sliders)
	App.run.world.player._die("test hazard")
	check(music.is_dipped(), "the music dips the moment the player dies")
	# The HUD's pause button still works in the moment before the revive offer.
	App.pause_game()
	await _frames(roundi(maxf(library.dip_time, library.duck_time) * 60.0) + 5)
	var paused_db: float = _player(music, &"zone_2").volume_db
	check(App.overlay is PauseScreen and absf(paused_db - (full_db + library.dip_db)) < 0.05,
		"paused while dead, the music sits at the dip, not the dip and the duck (%.1f dB)" % paused_db)
	App.resume_game()
	await physics_frames(roundi((App.rules.death_screen_delay + 0.3) * 60.0))
	await tree.process_frame
	check(App.overlay is DeathScreen and music.is_dipped() and _filter_on(music), "the dip holds under the revive offer")
	App.revive_with_item()
	await physics_frames(3)
	check(App.run != null and App.run.world.player.alive and not music.is_dipped(), "a revive lifts the dip")
	await _frames(roundi(library.dip_recover_time * 60.0) + 5)
	check(absf(_player(music, &"zone_2").volume_db - full_db) < 0.05 and not _filter_on(music),
		"and the track comes back in full")
	App.run.world.player._die("again")
	await physics_frames(roundi((App.rules.death_screen_delay + 0.3) * 60.0))
	await tree.process_frame
	check(App.screen is ResultsScreen and music.current() == &"menu" and not music.is_dipped(),
		"with no revive left, the summary crossfades to the menu music, not dipped")
	await _frames(70)
	var menu: AudioStreamPlayer = _player(music, &"menu")
	check(menu != null and absf(menu.volume_db - library.volume(&"menu")) < 0.05 and not _filter_on(music),
		"the menu music plays at its full level, highs and all")
	# Quick play restarts in place on the same track: the restart lifts the dip.
	App.start_quick(PackedStringArray(["--seed=5"]))
	await physics_frames(5)
	App.run.world.player._die("quick")
	check(music.is_dipped(), "quick play dips on a death too")
	await physics_frames(roundi(LevelRun.QUICK_DEATH_PAUSE * 60.0) + 10)
	check(not music.is_dipped() and App.run.world.player.alive, "and lifts it when the level restarts")
	App.show_title()
	await tree.process_frame
	App.profile = saved
	main.queue_free()
	App.main = null
	await tree.process_frame
	music.stop(0.0)


func _filter_index(music: MusicDirector) -> int:
	var bus: int = AudioServer.get_bus_index(MusicLibrary.BUS)
	for i: int in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus, i) == music.dip_filter:
			return i
	return -1


func _filter_on(music: MusicDirector) -> bool:
	var index: int = _filter_index(music)
	return index >= 0 and AudioServer.is_bus_effect_enabled(AudioServer.get_bus_index(MusicLibrary.BUS), index)


static func _is_ranged(resource: Resource, prop: String) -> bool:
	for p: Dictionary in resource.get_property_list():
		if p["name"] == prop:
			return p["hint"] == PROPERTY_HINT_RANGE and (int(p["usage"]) & PROPERTY_USAGE_EDITOR) != 0
	return false


func _test_sound_effects() -> void:
	var library := load(SFX_LIBRARY_PATH) as SfxLibrary
	var names: PackedStringArray = library.names()
	for sound: StringName in SOUNDS:
		check(names.has(String(sound)), "sound library has '%s'" % sound)
		check(library.stream(sound) != null, "'%s' loads" % sound)
	var same_format: bool = true
	for sound: String in names:
		var raw := AudioStreamWAV.load_from_file(library.folder.path_join(sound + ".wav"), {"compress/mode": 0})
		if raw == null or raw.mix_rate != 32000 or raw.stereo or raw.format != AudioStreamWAV.FORMAT_16_BITS:
			same_format = false
			failures.append("'%s' is not 32 kHz mono 16-bit" % sound)
	check(same_format, "every sound file is 32 kHz mono 16-bit")
	for sound: StringName in WARNINGS:
		check(names.has(String(sound)) and float(library.pitch_variation.get(String(sound), 0.0)) == 0.0,
			"warning '%s' is in the library with no pitch variation" % sound)
	var shot_gain: float = db_to_linear(library.volume(&"cyborg_shot") - CYBORG_SHOT_BASELINE_DB)
	check(absf(shot_gain - CYBORG_SHOT_AMPLITUDE_GAIN) < 0.01,
		"cyborg laser firing is 1.3x its previous amplitude (%.2f dB)" % library.volume(&"cyborg_shot"))
	check(is_equal_approx(library.volume(&"cyborg_charge"), -3.0),
		"cyborg charge warning is not boosted with the laser")
	check(is_equal_approx(library.volume(&"laser_fire"), -12.5),
		"player laser is not boosted with the cyborg laser")


func _players(music: MusicDirector) -> Array[AudioStreamPlayer]:
	var out: Array[AudioStreamPlayer] = []
	for child: Node in music.get_children():
		if child is AudioStreamPlayer:
			out.append(child)
	return out


func _player(music: MusicDirector, track: StringName) -> AudioStreamPlayer:
	return music.get_node_or_null(NodePath("Track_%s" % track)) as AudioStreamPlayer


func _frames(count: int) -> void:
	for i: int in count:
		await tree.process_frame


func _rms(pcm: PackedByteArray, from: int, to: int) -> float:
	var sum: float = 0.0
	for i: int in range(from, to):
		var v: float = pcm.decode_s16(i * 2) / 32768.0
		sum += v * v
	return sqrt(sum / maxi(to - from, 1))


func _step_percentile(pcm: PackedByteArray, fraction: float) -> float:
	var steps: Array[float] = []
	for i: int in range(1, pcm.size() / 2 - 1, 3):
		steps.append(absf(float(pcm.decode_s16(i * 2) - pcm.decode_s16((i - 1) * 2))) / 32768.0)
	steps.sort()
	return steps[int(steps.size() * fraction)]
