class_name FloatingHeadVoice
extends Node3D
## The Floating Head's propaganda (GDD §10): "a heavily distorted announcement voice that isn't meant
## to be understood, plus a few short slogans shown as text on its face screen (so only those slogans
## need translating)". From the reveal on it shouts a phrase every so often (head_voice_1-4: made-up
## syllables through a blown loudhailer, tools/asset_gen/sfx_bank_bosses.gd), each with the next
## slogan on its face screen's caption band (FloatingHeadBody.show_slogan; the slogans are data,
## FloatingHeadTuning.slogans). The phrases come in a seeded order with seeded pauses, from its own
## random stream, so every attempt sounds the same and the fight's own picks don't change.
## It never masks an attack's warning: while one is on (FloatingHead.warning_active), the voice ducks
## voice_duck_db under its level at once and the slogan fades out; no new phrase starts until the
## warnings have been over for voice_clear_seconds. The defeat cuts it off mid-shout (cut()).
## The voice comes from the face screen (a positional player on the SFX bus, like the fight's other
## sounds); in headless runs nothing plays, but the timing, the ducking and the caption run the same
## (tests read them).

## The phrases, in the sound library.
const PHRASES: Array[StringName] = [&"head_voice_1", &"head_voice_2", &"head_voice_3", &"head_voice_4"]
const CUT_SOUND: StringName = &"head_voice_cut"
## A phrase whose length the library can't tell (no file) counts as this long.
const FALLBACK_SECONDS: float = 2.0
## The slogan fades in and out over these.
const CAPTION_IN: float = 0.25
const CAPTION_OUT: float = 0.4
## ...and out this fast when a warning comes.
const CAPTION_AWAY: float = 0.12
const LIBRARY_PATH: String = "res://data/audio/sfx_library.tres"

var head: FloatingHead
var tuning: FloatingHeadTuning
## Shouting its propaganda (from the reveal on, until the defeat cuts it off).
var speaking: bool = false
## Cut off (the defeat): it never speaks again.
var cut_off: bool = false
## How far it's ducked: 0 (its full level) to 1 (voice_duck_db under it).
var duck: float = 0.0
## The phrase playing (an index into PHRASES), or -1; seconds of it left; phrases begun so far.
var phrase: int = -1
var phrase_left: float = 0.0
var phrases: int = 0
## The slogan showing (an index into tuning.slogans), or -1.
var slogan: int = -1

var _player: AudioStreamPlayer3D
var _library: SfxLibrary
var _rng := RandomNumberGenerator.new()
## Seconds until the next phrase may start, and since the warnings were last on.
var _wait: float = 0.0
var _clear: float = 0.0
var _last: int = -1
var _caption_left: float = 0.0


func setup(p_head: FloatingHead) -> void:
	head = p_head
	tuning = head.tuning
	name = "Voice"
	_rng.seed = hash([String(head.def.id) if head.def != null else "", "voice"])
	_library = head.world.sfx_library
	if _library == null and ResourceLoader.exists(LIBRARY_PATH):
		_library = load(LIBRARY_PATH) as SfxLibrary
	_player = AudioStreamPlayer3D.new()
	_player.name = "Loudhailer"
	if _library != null:
		_player.unit_size = _library.warning_full_volume_distance
		_player.max_distance = _library.warning_max_distance
	if AudioServer.get_bus_index(SfxLibrary.BUS) >= 0:
		_player.bus = SfxLibrary.BUS
	add_child(_player)
	_wait = _pause()


## Starts shouting (the reveal: its face is on).
func start() -> void:
	if cut_off:
		return
	speaking = true


## The defeat (GDD §10: "the propaganda cuts out mid-shout"): the phrase stops dead, the cut-off shout
## plays, and the slogan goes with the face. It never speaks again.
func cut() -> void:
	if cut_off:
		return
	cut_off = true
	speaking = false
	phrase = -1
	phrase_left = 0.0
	duck = 0.0
	_caption_left = 0.0
	if _player.playing:
		_player.stop()
	_play(CUT_SOUND)
	head.log_event(&"voice_cut")


## Its level now, in dB over its sound's own mix level (0, or down to voice_duck_db while ducked).
func level_db() -> float:
	return tuning.voice_duck_db * duck


## Seconds of `sound` (the library's file), or FALLBACK_SECONDS.
func seconds_of(sound: StringName) -> float:
	var stream: AudioStream = _library.stream(sound) if _library != null else null
	if stream is AudioStreamRandomizer:
		stream = (stream as AudioStreamRandomizer).get_stream(0)
	return stream.get_length() if stream != null else FALLBACK_SECONDS


func tick(delta: float) -> void:
	if head == null or head.body == null or not is_instance_valid(head.body):
		return
	global_position = head.body.screen_world()
	var warned: bool = head.warning_active()
	# Ducks at once under a warning, and comes back up slowly once it's over.
	if warned:
		duck = move_toward(duck, 1.0, delta / maxf(tuning.voice_duck_seconds, 0.001))
		_clear = 0.0
	else:
		duck = move_toward(duck, 0.0, delta / maxf(tuning.voice_recover_seconds, 0.001))
		_clear += delta
	if phrase >= 0:
		phrase_left -= delta
		if phrase_left <= 0.0:
			phrase = -1
	_wait -= delta
	if speaking and phrase < 0 and _wait <= 0.0 and not warned and _clear >= tuning.voice_clear_seconds \
			and head.body.screen_power >= 1.0:
		_shout()
	_update_player()
	_update_caption(delta, warned)


## The next phrase (never the same one twice running) with the next slogan.
func _shout() -> void:
	var pick: int = _rng.randi_range(0, PHRASES.size() - 2)
	if pick >= _last and _last >= 0:
		pick += 1
	_last = pick
	phrase = pick
	phrase_left = seconds_of(PHRASES[pick])
	phrases += 1
	_wait = phrase_left + _pause()
	_play(PHRASES[pick])
	if not tuning.slogans.is_empty():
		slogan = (slogan + 1) % tuning.slogans.size()
		head.body.show_slogan(tuning.slogans[slogan])
		_caption_left = phrase_left + tuning.slogan_hold_seconds
	head.log_event(&"voice", {"phrase": pick, "slogan": slogan})


func _pause() -> float:
	return _rng.randf_range(tuning.voice_gap_min, maxf(tuning.voice_gap_max, tuning.voice_gap_min))


func _play(sound: StringName) -> void:
	if _library == null or not SfxLibrary.audible():
		return
	var stream: AudioStream = _library.stream(sound)
	if stream == null:
		return
	_player.stream = stream
	_player.volume_db = _library.volume(sound) + level_db()
	_player.play()


## The playing phrase follows the duck (the cut-off shout plays at its own level).
func _update_player() -> void:
	if _library == null or not _player.playing or phrase < 0:
		return
	_player.volume_db = _library.volume(PHRASES[phrase]) + level_db()


## The slogan fades in with its phrase, stays slogan_hold_seconds after it, and fades out; under a
## warning it gives way at once (and doesn't come back: the next phrase brings the next slogan).
func _update_caption(delta: float, warned: bool) -> void:
	var body: FloatingHeadBody = head.body
	if warned:
		_caption_left = 0.0
		body.caption = move_toward(body.caption, 0.0, delta / CAPTION_AWAY)
		return
	_caption_left -= delta
	if _caption_left > 0.0:
		body.caption = move_toward(body.caption, 1.0, delta / CAPTION_IN)
	else:
		body.caption = move_toward(body.caption, 0.0, delta / CAPTION_OUT)
