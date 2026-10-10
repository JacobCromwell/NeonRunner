extends SceneTree
## Generates every game sound effect into assets/sfx/<name>.wav: crunchy 16-bit synth tones,
## heavy-metal guitar and drums, engines, machines and monsters, all built from code so any of them
## can be regenerated and tweaked. The sounds live in banks, one function each:
##   sfx_bank_player.gd   movement, the fence warning and death
##   sfx_bank_riffs.gd    the level-complete riff, one per music track in its key
##   sfx_bank_ui.gd       menus, results, countdown, credits and bonuses
##   sfx_bank_power.gd    power-ups, weapons and protective items
##   sfx_bank_enemies.gd  enemies: every attack's warning, the attacks, hits and deaths
##   sfx_bank_bosses.gd   bosses: their entrances, warnings and attacks
##   sfx_bank_resonator.gd  the Resonator: its warning (a crackling fire breaking into a wave crash), its
##                        pulse and its death
##   sfx_bank_barnacle.gd   the Barnacle Turret: popping out, its charge-up (the warning), its bolts, its death
##   sfx_bank_sleep_taker.gd  the Sleep Taker: its rise, its attacks' warnings (the shriek, the
##                        whispering, the inhale) and the attacks
##   sfx_bank_buzz_overdrive.gd  the Buzz Overdrive: its rev (the warning: the blade spinning up) and its
##                        charge
##   sfx_bank_tithe_collector.gd  the Tithe Collector: its approach cue (a smug chuckle and a cash-register ding)
##   sfx_bank_the_house.gd  The House: its entrance, the spin (the lever, the reels, the dings), the 7
##                        buttons, its attacks' warnings, the jackpot and the hopper's stomp
##   sfx_bank_sentinel.gd  the Gilded Sentinels: the stone grind (the warning), the swing and the break
##   sfx_bank_hostile_takeover.gd  Hostile Takeover: the gunship's entrance, the couplings going live, a
##                        coupling stomped and the carriages breaking away
##   sfx_bank_sewer_swarm.gd  the Sewer Swarm: the Rising, a surge's rising chitter (the warning) and its
##                        rush, a cluster shocked by a fence, falling into a hole, scattering
##   sfx_bank_magnate.gd  The Magnate (the Golden Convergence's second stage): his roar (a Pounce's warning), growls
##                        and breathing, the leap and crash, the slam into the gate, the stun and the stomp, the
##                        cable's crackle (a Cable Lash's warning) and whip, the transition's burst and the suit's
##                        fall, his defeat (the cables tearing, the screens dying, his death and collapse)
##   sfx_bank_enforcer.gd  the Enforcer Truck: its siren (its arrival), a volley's rising whine (the warning)
##                        and its laser shots, a rider climbing aboard, its crash into a hole
##   sfx_bank_golden_convergence.gd  the Golden Convergence: its rise and the cult's chime rung huge and slow,
##                        the Helidrone Strafe (the squadron out of the cape and back, a pass's whine (the
##                        warning), its rake and sweep, ricochets, a drone hurled by a pad), the Flying
##                        Buttress rising and crumbling; the Fist Slam (the grinding wind-up (the warning),
##                        the slam, the floor breaking, the tower toppling) and the Missile Barrage (the
##                        hatches (the warning), the launch, the dive's whistle, the fire)
##   sfx_bank_cinematics.gd  the cinematics' own moments, where the game's sounds don't fit (the Dead Zone's
##                        intro: the smoking crater, rubble shifting, a hand grabbing an edge, a host turning to
##                        look and its corrupted screen up close)
##   sfx_bank_gangland_outro.gd  the Gangland outro's: the screeches sniffing, the golden key's glint, the
##                        sports car's unlock, scissor door, engine starting and drive-off
##   sfx_bank_minigames.gd  the mini-games' own sounds (the Beach's volleyball match: the ball's hit, its bounce in the
##                        sand, the referee's whistle)
## Run: tools/godot.sh sfx   (--only=jump,land renders just those; --review also writes
## build/sfx_review/<name>.png: waveform on top, spectrogram (40 Hz–16 kHz, time left to right) below).
## Each line of the report ends with the sound's loudest 400 ms as heard on headphones (K-weighted) and
## on a phone speaker, for matching levels in data/audio/sfx_library.tres.
## Sounds are deterministic: every random source has a fixed seed.

const DSP = preload("res://tools/asset_gen/sfx_dsp.gd")
const Review = preload("res://tools/asset_gen/audio_review.gd")
const BANKS: Array = [
	preload("res://tools/asset_gen/sfx_bank_player.gd"),
	preload("res://tools/asset_gen/sfx_bank_riffs.gd"),
	preload("res://tools/asset_gen/sfx_bank_ui.gd"),
	preload("res://tools/asset_gen/sfx_bank_power.gd"),
	preload("res://tools/asset_gen/sfx_bank_enemies.gd"),
	preload("res://tools/asset_gen/sfx_bank_bosses.gd"),
	preload("res://tools/asset_gen/sfx_bank_resonator.gd"),
	preload("res://tools/asset_gen/sfx_bank_barnacle.gd"),
	preload("res://tools/asset_gen/sfx_bank_sleep_taker.gd"),
	preload("res://tools/asset_gen/sfx_bank_buzz_overdrive.gd"),
	preload("res://tools/asset_gen/sfx_bank_tithe_collector.gd"),
	preload("res://tools/asset_gen/sfx_bank_the_house.gd"),
	preload("res://tools/asset_gen/sfx_bank_sentinel.gd"),
	preload("res://tools/asset_gen/sfx_bank_hostile_takeover.gd"),
	preload("res://tools/asset_gen/sfx_bank_sewer_swarm.gd"),
	preload("res://tools/asset_gen/sfx_bank_magnate.gd"),
	preload("res://tools/asset_gen/sfx_bank_enforcer.gd"),
	preload("res://tools/asset_gen/sfx_bank_golden_convergence.gd"),
	preload("res://tools/asset_gen/sfx_bank_cinematics.gd"),
	preload("res://tools/asset_gen/sfx_bank_gangland_outro.gd"),
	preload("res://tools/asset_gen/sfx_bank_minigames.gd"),
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
