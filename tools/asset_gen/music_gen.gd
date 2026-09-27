extends SceneTree
## Generates the music into assets/music/<name>.wav: placeholder loops in the crunchy 16-bit /
## heavy-metal style of the sound effects (GDD §11), one per zone plus the menus. Each track is
## composed in its own script (track_<name>.gd) with music_song.gd and music_instruments.gd.
## Run: tools/godot.sh music   (--only=city renders one track; --review also writes
## build/music_review/<name>.png: waveform, loudness with bar lines, spectrogram, and a zoom on
## the loop seam). Tracks are deterministic: every random source has a fixed seed.
##
## Every file is one seamless loop: 32 kHz mono 16-bit PCM, a "smpl" chunk marking the loop, and
## import settings (written next to the file) that loop it forward and compress it with QOA in
## exported builds. Any track can be replaced by another file: see scripts/audio/music_library.gd.

const Review = preload("res://tools/asset_gen/audio_review.gd")
const DSP = preload("res://tools/asset_gen/sfx_dsp.gd")
const OUT_DIR: String = "res://assets/music"
const REVIEW_DIR: String = "res://build/music_review"
# DESIGN-TBD: the music style per zone is still open (OPEN_QUESTIONS §6, Audio). These placeholders
# follow the build brief: moody neon synthwave for the menus, driving synth-metal for the City,
# heavier industrial metal for Gangland.
const TRACKS: Dictionary = {
	"menu": preload("res://tools/asset_gen/track_menu.gd"),
	"city": preload("res://tools/asset_gen/track_city.gd"),
	"gangland": preload("res://tools/asset_gen/track_gangland.gd"),
	"marketplace": preload("res://tools/asset_gen/track_marketplace.gd"),
	"corporate": preload("res://tools/asset_gen/track_corporate.gd"),
	"dead_zone": preload("res://tools/asset_gen/track_dead_zone.gd"),
	"golden": preload("res://tools/asset_gen/track_golden.gd"),
}
## Import settings for each music file: loop forward from the first sample to the guard sample at
## the end (-1), and compress with QOA.
const IMPORT_PARAMS: Dictionary = {
	"edit/loop_mode": 2,
	"edit/loop_begin": 0,
	"edit/loop_end": -1,
	"compress/mode": 2,
}


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var review: bool = args.has("--review")
	var only: String = ""
	for arg: String in args:
		if arg.begins_with("--only="):
			only = arg.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	if review:
		DirAccess.make_dir_recursive_absolute(REVIEW_DIR)
		# Keep Godot from importing the review images as game assets.
		FileAccess.open("res://build/.gdignore", FileAccess.WRITE).store_string("")
	for track: String in TRACKS:
		if only != "" and track != only:
			continue
		var started: int = Time.get_ticks_msec()
		var song: RefCounted = TRACKS[track].compose()
		var b: PackedFloat32Array = song.master
		var path: String = OUT_DIR.path_join(track + ".wav")
		var err: Error = write_loop_wav(path, b)
		_write_import_settings(path)
		var seam: Array[float] = Review.seam_step(b)
		print("%-9s %s  %d bars at %d BPM  %s  seam step %.3f (p99 %.3f)  rendered in %.0f s" % [track,
			"ok " if err == OK else error_string(err), song.bars, roundi(song.bpm), Review.stats(b),
			seam[0], seam[1], (Time.get_ticks_msec() - started) / 1000.0])
		if review:
			print("          " + Review.band_balance(b))
			for stem_name: String in song.stems:
				print("          stem %-6s %s" % [stem_name, Review.band_balance(song.stems[stem_name])])
			_print_stem_shares(song)
			var png_err: Error = Review.music_sheet(b, song.step, song.sections).save_png(REVIEW_DIR.path_join(track + ".png"))
			if png_err != OK:
				push_error("Could not write the review image for %s: %s" % [track, error_string(png_err)])
	var total: int = 0
	for file: String in DirAccess.get_files_at(OUT_DIR):
		if file.ends_with(".wav"):
			total += FileAccess.get_file_as_bytes(OUT_DIR.path_join(file)).size()
	print("assets/music: %.2f MB of WAV files" % (total / 1048576.0))
	quit()


## Writes 16-bit mono PCM with a "smpl" chunk that marks the whole buffer as a forward loop. One guard
## sample, a copy of the first, follows the loop: a player interpolating past the loop's last sample
## then reads the loop's start. The import settings end the loop at that guard sample.
static func write_loop_wav(path: String, b: PackedFloat32Array) -> Error:
	var n: int = b.size()
	var data := PackedByteArray()
	data.resize((n + 1) * 2)
	for i: int in n:
		data.encode_s16(i * 2, _to_s16(b[i]))
	data.encode_s16(n * 2, _to_s16(b[0]))
	var fmt := PackedByteArray()
	fmt.resize(16)
	fmt.encode_u16(0, 1)  # PCM
	fmt.encode_u16(2, 1)  # mono
	fmt.encode_u32(4, Review.RATE)
	fmt.encode_u32(8, Review.RATE * 2)
	fmt.encode_u16(12, 2)
	fmt.encode_u16(14, 16)
	var smpl := PackedByteArray()
	smpl.resize(60)
	smpl.encode_u32(8, 1000000000 / Review.RATE)  # sample period, ns
	smpl.encode_u32(12, 60)  # MIDI unity note
	smpl.encode_u32(28, 1)  # one loop
	smpl.encode_u32(40, 0)  # forward
	smpl.encode_u32(44, 0)  # first sample
	smpl.encode_u32(48, n - 1)  # last sample (inclusive)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(4 + 8 + fmt.size() + 8 + data.size() + 8 + smpl.size())
	f.store_buffer("WAVE".to_ascii_buffer())
	for chunk: Array in [["fmt ", fmt], ["data", data], ["smpl", smpl]]:
		f.store_buffer(String(chunk[0]).to_ascii_buffer())
		f.store_32((chunk[1] as PackedByteArray).size())
		f.store_buffer(chunk[1])
	return OK


## How loud each part is in the mix, per section, in dB against the whole mix: over the full band, and
## in the 1–4 kHz presence band where a melody has to cut through (and where the sound effects' cues
## sit). "  -" means the part is silent there.
static func _print_stem_shares(song: RefCounted) -> void:
	var mix := PackedFloat32Array()
	mix.resize(song.length)
	var scaled: Dictionary = {}
	for stem_name: String in song.stem_gains:
		var s: PackedFloat32Array = (song.stems[stem_name] as PackedFloat32Array).duplicate()
		var gain: float = song.stem_gains[stem_name]
		for i: int in s.size():
			s[i] *= gain
			mix[i] += s[i]
		scaled[stem_name] = s
	var presence: Dictionary = {}
	for stem_name: String in scaled:
		presence[stem_name] = _band(scaled[stem_name])
	var mix_presence := _band(mix)
	var header: String = "          %-16s" % "share (dB)"
	for stem_name: String in scaled:
		header += " %9s" % stem_name
	print(header + "   (full band / 1-4 kHz)")
	for k: int in song.sections.size():
		var first: int = song.at(int(song.sections[k][0]))
		var last: int = song.at(int(song.sections[k + 1][0])) if k + 1 < song.sections.size() else song.length
		var line: String = "          %-16s" % song.sections[k][1]
		var mix_rms: float = _rms(mix, first, last)
		var mix_presence_rms: float = _rms(mix_presence, first, last)
		for stem_name: String in scaled:
			var full: float = _rms(scaled[stem_name], first, last) / mix_rms
			var band: float = _rms(presence[stem_name], first, last) / mix_presence_rms
			line += " %9s" % ("  -" if full < 0.003 else "%3.0f/%3.0f" % [linear_to_db(full), linear_to_db(band)])
		print(line)


static func _band(b: PackedFloat32Array) -> PackedFloat32Array:
	var out := b.duplicate()
	DSP.filter(out, &"highpass", 1000.0, 0.7)
	DSP.filter(out, &"lowpass", 4000.0, 0.7)
	return out


static func _rms(b: PackedFloat32Array, first: int, last: int) -> float:
	var sum: float = 0.0
	for i: int in range(first, last):
		sum += b[i] * b[i]
	return sqrt(sum / maxi(last - first, 1))


static func _to_s16(v: float) -> int:
	return roundi(clampf(v, -1.0, 1.0) * 32767.0)


## Sets the loop and compression import settings, keeping anything else Godot wrote (uid, paths).
func _write_import_settings(path: String) -> void:
	var import_path: String = path + ".import"
	var cfg := ConfigFile.new()
	if FileAccess.file_exists(import_path) and cfg.load(import_path) == OK:
		var unchanged: bool = true
		for key: String in IMPORT_PARAMS:
			if cfg.get_value("params", key, null) != IMPORT_PARAMS[key]:
				unchanged = false
		if unchanged:
			return
	else:
		cfg.set_value("remap", "importer", "wav")
		cfg.set_value("remap", "type", "AudioStreamWAV")
	for key: String in IMPORT_PARAMS:
		cfg.set_value("params", key, IMPORT_PARAMS[key])
	cfg.save(import_path)
