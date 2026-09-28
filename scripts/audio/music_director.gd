class_name MusicDirector
extends Node
## The music player (autoload "Music"): one looping track at a time on the Music bus, crossfading
## between tracks. The game calls Music.play(&"city") when a zone starts, Music.play(&"menu") in the
## menus, Music.set_ducked(true) while a pause menu is open, and Music.set_dipped(true) while the
## player lies dead (the death dip, GDD §11). Track names, files, levels and both dips' numbers are
## in data/audio/music_library.tres. Fades run on real time, so they carry on while the game is
## paused or slowed down.
## Headless runs (tests, smoke runs) go through the same states but never start a player: the dummy
## audio driver never finishes a playback, and Godot would report it as leaked at exit.

const LIBRARY_PATH: String = "res://data/audio/music_library.tres"
## The level of a voice faded all the way out, in dB.
const SILENT_DB: float = -80.0
## The death dip's low-pass fully open: above anything the 32 kHz music files hold.
const OPEN_HZ: float = 20000.0
## The sound that ends a level or a boss fight when the music playing has no riff of its own: the
## riff in E, the City's key.
const LEVEL_COMPLETE: StringName = &"level_complete"

var library: MusicLibrary
## The low-pass the death dip closes on the Music bus (null if the bus doesn't exist). It is
## switched off whenever the dip is fully open, so it costs nothing the rest of the time.
var dip_filter: AudioEffectLowPassFilter

var _current: StringName = &""
var _voices: Array[Voice] = []
var _ducked: bool = false
## The ducking dip right now, in dB: moves towards library.duck_db (ducked) or 0.
var _duck_db: float = 0.0
var _dipped: bool = false
## How far the low-pass is closed: 0 = open, 1 = at library.dip_lowpass_hz. It follows the playing
## track's dip, and opens gradually when a new track takes over from a dipped one.
var _filter_amount: float = 0.0


## One track's player and how far through its fade it is.
class Voice:
	extends RefCounted
	var track: StringName
	var player: AudioStreamPlayer
	## 0 = silent, 1 = full volume. Played as an equal-power curve, so crossfades keep their loudness.
	var level: float = 0.0
	var target: float = 0.0
	## Level change per second.
	var speed: float = 0.0
	var volume_db: float = 0.0
	## How far into the death dip this track is: 0 = not at all, 1 = fully (library.dip_db lower).
	## Only the playing track moves; one fading out keeps the dip it had, so leaving a dipped track
	## never swells it on its way out.
	var dip: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	library = load(LIBRARY_PATH) as MusicLibrary
	if library == null:
		push_error("MusicDirector: could not load %s" % LIBRARY_PATH)
		library = MusicLibrary.new()
	_add_dip_filter()


## The Music autoload, or null where it isn't running (a scene played on its own).
static func instance() -> MusicDirector:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null(^"Music") as MusicDirector if tree != null and tree.root != null else null


## Crossfades to `track` over `fade` seconds (0 = cut). Does nothing if that track is already playing
## or fading in. A track that is still fading out fades back in from where it is. A track the
## library doesn't list yet (a zone's music before it's made: zones name their track after their
## id) is skipped quietly, and whatever is playing carries on. A new track ends the death dip: it
## comes in at its full level, while the dipped one fades out as it was.
func play(track: StringName, fade: float = 1.0) -> void:
	if track == _current:
		return
	var voice: Voice = _voice(track)
	var started: bool = false
	if voice == null:
		if not library.has(track):
			return
		var stream: AudioStream = library.stream(track)
		if stream == null:
			return
		voice = Voice.new()
		voice.track = track
		voice.volume_db = library.volume(track)
		voice.player = AudioStreamPlayer.new()
		voice.player.name = "Track_%s" % track
		voice.player.stream = stream
		voice.player.bus = MusicLibrary.BUS
		add_child(voice.player)
		_voices.append(voice)
		started = true
	for v: Voice in _voices:
		_fade(v, 1.0 if v == voice else 0.0, fade)
	_current = track
	_dipped = false
	_update(0.0)
	if started and SfxLibrary.audible():
		voice.player.play()


## Fades all music out over `fade` seconds (0 = cut). Also ends the death dip.
func stop(fade: float = 1.0) -> void:
	for v: Voice in _voices:
		_fade(v, 0.0, fade)
	_current = &""
	_dipped = false
	_update(0.0)


## The track playing or fading in, or &"" when the music is stopped.
func current() -> StringName:
	return _current


## While `on`, the music sits library.duck_db lower (for pause menus). The dip is smooth.
func set_ducked(on: bool) -> void:
	_ducked = on


func is_ducked() -> bool:
	return _ducked


## The death dip (GDD §11): while `on`, the playing track sinks library.dip_db lower and loses its
## highs (a low-pass on the Music bus closing to library.dip_lowpass_hz) over library.dip_time; off,
## it comes back over library.dip_recover_time. The game dips it when the player dies and lifts it on
## a revive or a restart; playing another track (leaving to the menus) ends it too.
## With the pause duck, the deeper of the two applies, never both added: pausing on the death
## screen leaves the dip as it is, and either one ending leaves the other in place.
func set_dipped(on: bool) -> void:
	_dipped = on


func is_dipped() -> bool:
	return _dipped


## How far a track is faded in: 0 = silent or not playing, 1 = full volume.
func fade_level(track: StringName) -> float:
	var voice: Voice = _voice(track)
	return voice.level if voice != null else 0.0


## How far into the death dip a track is: 0 = not dipped (or not playing), 1 = fully dipped.
func dip_level(track: StringName) -> float:
	var voice: Voice = _voice(track)
	return voice.dip if voice != null else 0.0


## The low-pass's cutoff right now, in Hz: OPEN_HZ while it's switched off.
func dip_cutoff_hz() -> float:
	if dip_filter == null or _filter_amount <= 0.0:
		return OPEN_HZ
	return dip_filter.cutoff_hz


## The sound effect that ends a level or a boss fight while `track` plays (GDD §11: the riff in the
## zone's key): level_complete_<track> when the sound library lists one, otherwise the E riff. A
## track replaced by a file in another key needs its riff remade to match, or removed.
static func level_complete_sound(track: StringName, sfx: SfxLibrary) -> StringName:
	if track == &"" or sfx == null:
		return LEVEL_COMPLETE
	var riff: String = "%s_%s" % [LEVEL_COMPLETE, track]
	return StringName(riff) if sfx.volume_db.has(riff) else LEVEL_COMPLETE


func _process(delta: float) -> void:
	# Real time: slow-motion shouldn't stretch a fade.
	_update(delta / Engine.time_scale if Engine.time_scale > 0.0 else delta)


func _voice(track: StringName) -> Voice:
	for v: Voice in _voices:
		if v.track == track:
			return v
	return null


func _fade(v: Voice, target: float, seconds: float) -> void:
	v.target = target
	if seconds <= 0.0:
		v.level = target
		v.speed = 0.0
	else:
		v.speed = 1.0 / seconds


func _update(delta: float) -> void:
	var duck_target: float = library.duck_db if _ducked else 0.0
	_duck_db = move_toward(_duck_db, duck_target, absf(library.duck_db) / maxf(library.duck_time, 0.01) * delta)
	var current_dip: float = 0.0
	for i: int in range(_voices.size() - 1, -1, -1):
		var v: Voice = _voices[i]
		v.level = move_toward(v.level, v.target, v.speed * delta)
		if v.track == _current:
			var dip_target: float = 1.0 if _dipped else 0.0
			var dip_seconds: float = library.dip_time if dip_target > v.dip else library.dip_recover_time
			v.dip = move_toward(v.dip, dip_target, delta / maxf(dip_seconds, 0.01))
			current_dip = v.dip
		if v.level <= 0.0 and v.target <= 0.0:
			v.player.stop()
			v.player.free()
			_voices.remove_at(i)
			continue
		var gain: float = sin(v.level * PI * 0.5)
		var lowered_db: float = minf(_duck_db, library.dip_db * v.dip)
		v.player.volume_db = v.volume_db + lowered_db + maxf(linear_to_db(maxf(gain, 1e-6)), SILENT_DB)
	# The low-pass closes with the playing track's dip and opens as it recovers, at the same pace; when
	# another track takes over from a dipped one, it opens at the recovery's pace.
	var filter_seconds: float = library.dip_time if current_dip > _filter_amount else library.dip_recover_time
	_filter_amount = move_toward(_filter_amount, current_dip, delta / maxf(filter_seconds, 0.01))
	_update_dip_filter()


## Adds the death dip's low-pass to the Music bus, switched off until the music dips.
func _add_dip_filter() -> void:
	var bus: int = AudioServer.get_bus_index(MusicLibrary.BUS)
	if bus < 0:
		return
	dip_filter = AudioEffectLowPassFilter.new()
	dip_filter.resource_name = "DeathDip"
	dip_filter.cutoff_hz = OPEN_HZ
	dip_filter.db = AudioEffectFilter.FILTER_12DB
	AudioServer.add_bus_effect(bus, dip_filter)
	AudioServer.set_bus_effect_enabled(bus, AudioServer.get_bus_effect_count(bus) - 1, false)


## Sets the low-pass's cutoff from how far it's closed (an exponential sweep, so it moves evenly by
## ear), switching it on only while it's closed at all.
func _update_dip_filter() -> void:
	if dip_filter == null:
		return
	var bus: int = AudioServer.get_bus_index(MusicLibrary.BUS)
	var index: int = _dip_filter_index(bus)
	if index < 0:
		return
	var on: bool = _filter_amount > 0.0
	if on:
		var closed_hz: float = clampf(library.dip_lowpass_hz, 20.0, OPEN_HZ)
		dip_filter.cutoff_hz = OPEN_HZ * pow(closed_hz / OPEN_HZ, _filter_amount)
	if AudioServer.is_bus_effect_enabled(bus, index) != on:
		AudioServer.set_bus_effect_enabled(bus, index, on)


## Where the low-pass sits in the bus's effects (-1 if it's gone: the bus layout was replaced).
func _dip_filter_index(bus: int) -> int:
	if bus < 0:
		return -1
	for i: int in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus, i) == dip_filter:
			return i
	return -1
