extends TestSuite
## Audio: the buses, the music files (they load, loop seamlessly, have the expected length and fit the
## size budget), the Music autoload's API, and every sound effect the game calls by name. Headless, so
## nothing is heard: the checks use the players' state and mix the streams directly.
## (tests/suites/test_units.gd checks every library sound's length.)

const MUSIC_LIBRARY_PATH: String = "res://data/audio/music_library.tres"
const SFX_LIBRARY_PATH: String = "res://data/audio/sfx_library.tres"
const TRACKS: Array[StringName] = [&"menu", &"city", &"gangland"]
## All music together must stay under this in the repo (task budget).
const MUSIC_BUDGET_BYTES: int = 9 * 1024 * 1024
## Sounds other code plays by name: UI, credits, protection, power-ups and weapons, enemies.
const SOUNDS: Array[StringName] = [
	&"ui_move", &"ui_select", &"ui_back", &"ui_buy", &"ui_error", &"ui_equip", &"ui_unlock", &"star", &"countdown", &"go",
	&"credit_1", &"credit_5", &"credit_25", &"credit_100", &"bonus",
	&"armor_break", &"shield_break", &"grapple", &"revive",
	&"dash", &"dash_ready", &"slow_time_on", &"slow_time_off", &"laser_fire", &"missile_fire", &"missile_explode",
	&"enemy_hit", &"stomp",
	&"enemy_death", &"cyborg_charge", &"cyborg_shot", &"truck_bang", &"truck_burst", &"truck_cannon_charge",
	&"truck_cannon", &"truck_explode", &"octodog_windup", &"octodog_lunge", &"screech_shake", &"screech_burst",
	&"screech_swipe", &"drone_swoop", &"drone_windup", &"drone_fire", &"drone_crash", &"emp", &"bad_dream_emerge",
	&"bad_dream_shriek", &"bad_dream_slash", &"bad_dream_dissolve",
]
## Attack warnings (CLAUDE.md readability rules): each must sound exactly the same every time.
const WARNINGS: Array[StringName] = [&"fence_warning", &"cyborg_charge", &"truck_bang", &"truck_cannon_charge",
	&"octodog_windup", &"screech_shake", &"drone_swoop", &"drone_windup", &"bad_dream_shriek"]


func run() -> void:
	_test_buses()
	_test_music_files()
	await _test_music_api()
	_test_sound_effects()


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
	for track: StringName in TRACKS:
		check(library.has(track), "music library has '%s'" % track)
		var path: String = library.path(track)
		# A fresh copy as imported, so looping can't come from MusicLibrary.loop_whole().
		var stream := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as AudioStreamWAV
		check(stream != null, "'%s' loads as a WAV stream (%s)" % [track, path])
		if stream == null:
			continue
		total_bytes += FileAccess.get_file_as_bytes(path).size()
		var frames: int = roundi(stream.get_length() * stream.mix_rate)
		check(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and stream.loop_begin == 0 and stream.loop_end >= frames - 1,
			"'%s' is imported as a forward loop over the whole file (%d..%d of %d)" % [track, stream.loop_begin, stream.loop_end, frames])
		check(stream.format == AudioStreamWAV.FORMAT_QOA, "'%s' is imported QOA-compressed" % track)
		var loop_seconds: float = float(stream.loop_end - stream.loop_begin) / stream.mix_rate
		var bar_seconds: float = 240.0 / maxf(float(library.bpm.get(String(track), 0.0)), 1.0)
		var bars: float = loop_seconds / bar_seconds
		check(loop_seconds >= 30.0 and loop_seconds <= 45.0, "'%s' loops every 30–45 s (%.2f s)" % [track, loop_seconds])
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
	check(total_bytes <= MUSIC_BUDGET_BYTES, "all music fits in %d MB (%.2f MB)" % [MUSIC_BUDGET_BYTES / 1048576, total_bytes / 1048576.0])


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
