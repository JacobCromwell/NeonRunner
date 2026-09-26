class_name MusicLibrary
extends Resource
## Which file plays for each music track, and how loud. The current files are seamless loops made by
## tools/asset_gen/music_gen.gd (tools/godot.sh music). To replace a track, point its entry in
## `files` at the new file (WAV, Ogg Vorbis or MP3) and set its level: a file that isn't marked as a
## loop is looped as a whole. The Music autoload (MusicDirector) plays these on the Music bus.

## The bus every music player uses. Settings set its volume by this name.
const BUS: StringName = &"Music"

## Music file per track name. Also the list of tracks the game knows about.
@export var files: Dictionary = {}
## Mix level per track in dB, so every track sits at the same loudness under the sound effects.
@export var volume_db: Dictionary = {}
## Tempo per track in beats per minute (4/4). Each loop is a whole number of bars at this tempo.
@export var bpm: Dictionary = {}
## How far Music.set_ducked(true) lowers the music (pause menus), and how long the dip takes.
@export_range(-24.0, 0.0, 0.5, "suffix:dB") var duck_db: float = -8.0
@export_range(0.0, 2.0, 0.05, "suffix:s") var duck_time: float = 0.3

var _cache: Dictionary = {}


func names() -> PackedStringArray:
	var out := PackedStringArray()
	for key: Variant in files:
		out.append(String(key))
	return out


func has(track: StringName) -> bool:
	return files.has(String(track))


func volume(track: StringName) -> float:
	return float(volume_db.get(String(track), 0.0))


func path(track: StringName) -> String:
	return String(files.get(String(track), ""))


## The looping stream for a track, or null (with a warning) if the track or its file is missing.
func stream(track: StringName) -> AudioStream:
	var key: String = String(track)
	if _cache.has(key):
		return _cache[key]
	var file: String = path(track)
	var out: AudioStream = null
	if file == "":
		push_warning("MusicLibrary: no track named '%s'" % key)
	elif not ResourceLoader.exists(file):
		push_warning("MusicLibrary: no music file at %s" % file)
	else:
		out = load(file) as AudioStream
		loop_whole(out)
	_cache[key] = out
	return out


## Makes a stream loop if its file or import settings don't already: WAV files loop over the whole
## file, Ogg Vorbis and MP3 from the start.
static func loop_whole(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		if wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = roundi(wav.get_length() * wav.mix_rate)
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
