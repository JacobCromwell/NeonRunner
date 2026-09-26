class_name SfxLibrary
extends Resource
## Which sound plays for each game event, and how loud. Each sound is `folder/<name>.wav`, so any
## of them can be replaced by dropping in a file with the same name. The current files are made
## by tools/asset_gen/sfx_gen.gd. Hazard warning sounds are shared by every zone (hazard language).
## Every sound effect plays on the SFX bus (default_bus_layout.tres), which feeds Master.

## The bus every sound effect player uses. Settings set its volume by this name.
const BUS: StringName = &"SFX"

@export_dir var folder: String = "res://assets/sfx"
## Mix level per sound in dB. Also the list of sounds the game knows about.
@export var volume_db: Dictionary = {}
## Random pitch spread per sound (0.05 = up to ±5%) so frequent sounds don't machine-gun.
@export var pitch_variation: Dictionary = {}
## Hazard warnings come from the hazard's position. Within this distance they play at full volume,
## then fade with distance, going silent at warning_max_distance.
@export_range(1.0, 60.0, 1.0, "suffix:m") var warning_full_volume_distance: float = 20.0
@export_range(20.0, 200.0, 5.0, "suffix:m") var warning_max_distance: float = 90.0

var _cache: Dictionary = {}


## False in headless runs: the dummy audio driver never finishes a playback, so Godot would
## report every played sound as an object leaked at exit.
static func audible() -> bool:
	return DisplayServer.get_name() != "headless"


func names() -> PackedStringArray:
	var out := PackedStringArray()
	for key: Variant in volume_db:
		out.append(String(key))
	return out


func volume(sound: StringName) -> float:
	return float(volume_db.get(String(sound), 0.0))


## The stream for a sound (with pitch variation applied), or null if its file is missing.
func stream(sound: StringName) -> AudioStream:
	var key: String = String(sound)
	if _cache.has(key):
		return _cache[key]
	var path: String = folder.path_join(key + ".wav")
	var wav: AudioStream = load(path) as AudioStream if ResourceLoader.exists(path) else null
	if wav == null:
		push_warning("SfxLibrary: no sound file at %s" % path)
	var variation: float = float(pitch_variation.get(key, 0.0))
	var out: AudioStream = wav
	if wav != null and variation > 0.0:
		var randomizer := AudioStreamRandomizer.new()
		randomizer.add_stream(0, wav)
		randomizer.random_pitch = 1.0 + variation
		out = randomizer
	_cache[key] = out
	return out
