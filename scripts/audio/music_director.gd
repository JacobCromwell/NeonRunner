class_name MusicDirector
extends Node
## The music player (autoload "Music"): one looping track at a time on the Music bus, crossfading
## between tracks. The game calls Music.play(&"city") when a zone starts, Music.play(&"menu") in the
## menus, and Music.set_ducked(true) while a pause menu is open. Track names, files and levels are in
## data/audio/music_library.tres. Fades run on real time, so they carry on while the game is paused
## or slowed down.
## Headless runs (tests, smoke runs) go through the same states but never start a player: the dummy
## audio driver never finishes a playback, and Godot would report it as leaked at exit.

const LIBRARY_PATH: String = "res://data/audio/music_library.tres"
## The level of a voice faded all the way out, in dB.
const SILENT_DB: float = -80.0

var library: MusicLibrary

var _current: StringName = &""
var _voices: Array[Voice] = []
var _ducked: bool = false
## The ducking dip right now, in dB: moves towards library.duck_db (ducked) or 0.
var _duck_db: float = 0.0


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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	library = load(LIBRARY_PATH) as MusicLibrary
	if library == null:
		push_error("MusicDirector: could not load %s" % LIBRARY_PATH)
		library = MusicLibrary.new()


## Crossfades to `track` over `fade` seconds (0 = cut). Does nothing if that track is already playing
## or fading in. A track that is still fading out fades back in from where it is. A track the
## library doesn't list yet (a zone's music before it's made: zones name their track after their
## id) is skipped quietly, and whatever is playing carries on.
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
	_update(0.0)
	if started and SfxLibrary.audible():
		voice.player.play()


## Fades all music out over `fade` seconds (0 = cut).
func stop(fade: float = 1.0) -> void:
	for v: Voice in _voices:
		_fade(v, 0.0, fade)
	_current = &""
	_update(0.0)


## The track playing or fading in, or &"" when the music is stopped.
func current() -> StringName:
	return _current


## While `on`, the music sits library.duck_db lower (for pause menus). The dip is smooth.
func set_ducked(on: bool) -> void:
	_ducked = on


func is_ducked() -> bool:
	return _ducked


## How far a track is faded in: 0 = silent or not playing, 1 = full volume.
func fade_level(track: StringName) -> float:
	var voice: Voice = _voice(track)
	return voice.level if voice != null else 0.0


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
	for i: int in range(_voices.size() - 1, -1, -1):
		var v: Voice = _voices[i]
		v.level = move_toward(v.level, v.target, v.speed * delta)
		if v.level <= 0.0 and v.target <= 0.0:
			v.player.stop()
			v.player.free()
			_voices.remove_at(i)
			continue
		var gain: float = sin(v.level * PI * 0.5)
		v.player.volume_db = v.volume_db + _duck_db + maxf(linear_to_db(maxf(gain, 1e-6)), SILENT_DB)
