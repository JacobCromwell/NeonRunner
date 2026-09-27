extends SceneTree
## Generates every game sound effect into assets/sfx/<name>.wav: crunchy 16-bit synth tones,
## heavy-metal guitar and drums, engines, machines and monsters, all built from code so any of them
## can be regenerated and tweaked. The sounds live in banks, one function each:
##   sfx_bank_player.gd   movement, the fence warning, death and level complete
##   sfx_bank_ui.gd       menus, results, countdown, credits and bonuses
##   sfx_bank_power.gd    power-ups, weapons and protective items
##   sfx_bank_enemies.gd  enemies: every attack's warning, the attacks, hits and deaths
##   sfx_bank_bosses.gd   bosses: their entrances, warnings and attacks
## Run: tools/godot.sh sfx   (--only=jump,land renders just those; --review also writes
## build/sfx_review/<name>.png: waveform on top, spectrogram (40 Hz–16 kHz, time left to right) below).
## Each line of the report ends with the sound's loudest 400 ms as heard on headphones (K-weighted) and
## on a phone speaker, for matching levels in data/audio/sfx_library.tres.
## Sounds are deterministic: every random source has a fixed seed.

const DSP = preload("res://tools/asset_gen/sfx_dsp.gd")
const Review = preload("res://tools/asset_gen/audio_review.gd")
const BANKS: Array = [
	preload("res://tools/asset_gen/sfx_bank_player.gd"),
	preload("res://tools/asset_gen/sfx_bank_ui.gd"),
	preload("res://tools/asset_gen/sfx_bank_power.gd"),
	preload("res://tools/asset_gen/sfx_bank_enemies.gd"),
	preload("res://tools/asset_gen/sfx_bank_bosses.gd"),
]
const OUT_DIR: String = "res://assets/sfx"
const REVIEW_DIR: String = "res://build/sfx_review"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var review: bool = args.has("--review")
	var only := PackedStringArray()
	for arg: String in args:
		if arg.begins_with("--only="):
			only = arg.get_slice("=", 1).split(",", false)
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	if review:
		DirAccess.make_dir_recursive_absolute(REVIEW_DIR)
		# Keep Godot from importing the review images as game assets.
		FileAccess.open("res://build/.gdignore", FileAccess.WRITE).store_string("")
	for bank_script: GDScript in BANKS:
		var bank: RefCounted = bank_script.new()  # keeps the bank alive while its Callables run
		var sounds: Dictionary = bank.sounds()
		for sound: String in sounds:
			if not only.is_empty() and not only.has(sound):
				continue
			var b: PackedFloat32Array = (sounds[sound] as Callable).call()
			DSP.finish(b)
			var err: Error = DSP.to_wav(b).save_to_wav(OUT_DIR.path_join(sound + ".wav"))
			print("%-19s %s  %s  loudest %5.1f dB (K), %5.1f dB (phone)" % [sound, "ok " if err == OK else error_string(err),
				Review.stats(b), Review.weighted_loudness_db(b, &"k"), Review.weighted_loudness_db(b, &"phone")])
			if review:
				var png_err: Error = Review.spectrogram(b).save_png(REVIEW_DIR.path_join(sound + ".png"))
				if png_err != OK:
					push_error("Could not write the review image for %s: %s" % [sound, error_string(png_err)])
	quit()
