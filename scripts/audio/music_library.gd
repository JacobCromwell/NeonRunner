class_name MusicLibrary
extends Resource
## Which file plays for each music track, and how loud. Generated defaults are seamless loops made by
## tools/asset_gen/music_gen.gd (tools/godot.sh music); owner-supplied songs override gameplay only.
## To replace a track, point its entry in
## `files` at the new file (WAV, Ogg Vorbis or MP3) and set its level: a file that isn't marked as a
## loop is looped as a whole. A level ends on a riff in the key of the track playing
## (MusicDirector.level_complete_sound(): the sound effect level_complete_<track>, or the E riff, the
## City's, for a track without one), so a replacement in another key needs its riff remade to match.
## The Music autoload (MusicDirector) plays these on the Music bus.

## The bus every music player uses. Settings set its volume by this name.
const BUS: StringName = &"Music"

## Music file per track name. Also the list of tracks the game knows about.
@export var files: Dictionary = {}
## Mix level per track in dB, so every track sits at the same loudness under the sound effects.
@export var volume_db: Dictionary = {}
## Tempo of generated loops in beats per minute (4/4). Owner-supplied songs need not list a tempo.
@export var bpm: Dictionary = {}
## Default zone track -> replacement for levels, quick play and endless; cinematics keep the generated default.
@export var zone_tracks: Dictionary = {}
## Boss id -> replacement for that fight only. Unmatched bosses keep their default track.
@export var boss_tracks: Dictionary = {}
## Replacement track -> original track whose level-complete sound should be retained.
@export var riff_tracks: Dictionary = {}

@export_group("Pause duck")
## How far Music.set_ducked(true) lowers the music (pause menus), and how long it takes to go down
## or come back.
@export_range(-24.0, 0.0, 0.5, "suffix:dB") var duck_db: float = -8.0
@export_range(0.0, 2.0, 0.05, "suffix:s") var duck_time: float = 0.3

@export_group("Death dip")
## The death dip (GDD §11: the music dips when the player dies, holds under the death screen, and
## comes back when they continue or retry; Music.set_dipped()): how far the playing track sinks.
## With the pause duck, the deeper of the two applies.
## DESIGN-TBD: the dip's amount, low-pass and timings are placeholders until the owner's playtest
## (OPEN_QUESTIONS §D, FB 52: the mix balance is tuned after playtesting).
@export_range(-30.0, 0.0, 0.5, "suffix:dB") var dip_db: float = -10.0
## The low-pass the Music bus closes to during the dip, so the track loses its highs and sounds far
## away (8000 Hz barely touches it).
@export_range(200.0, 8000.0, 10.0, "suffix:Hz") var dip_lowpass_hz: float = 800.0
## How long the dip takes to go all the way down (it starts as the player dies, under the death's
## dive-bomb sound), and to come back up on a revive or a restart.
@export_range(0.0, 3.0, 0.05, "suffix:s") var dip_time: float = 0.5
@export_range(0.0, 3.0, 0.05, "suffix:s") var dip_recover_time: float = 1.0

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


func run_track(default_track: StringName, boss_id: StringName = &"") -> StringName:
	var overrides: Dictionary = zone_tracks if boss_id == &"" else boss_tracks
	var key: String = String(default_track if boss_id == &"" else boss_id)
	var track := StringName(overrides.get(key, default_track))
	if not has(track):
		push_error("MusicLibrary: run track '%s' for '%s' is not in the library" % [track, key])
	return track


func riff_track(track: StringName) -> StringName:
	return StringName(riff_tracks.get(String(track), track))


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
