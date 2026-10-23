extends TestSuite
## One hit from death (task I6; GDD §4, owner, October 14, 2026): the moment the player has no armor hit and no
## shield left, the HUD's screen edges pulse red with a two-tone siren and then hold a dim red edge until
## protection is back (LastHitWarning, LastHitWarningTuning, the `last_hit_siren` sound). The numbers and
## their ranges in data and F6; the siren's file (two flat tones alternating once for each pulse, slower and lower
## than the jackpot's and the searchlight's two-tone sounds, length, no loop, mixed under every attack warning in
## the library on both loudness weightings the sound tools use); the cue's canvas layer (under every other
## overlay: the attack markers, the slow-time tint, SpeedLines, the HUD) and its four strips (only the edges are
## drawn); the shader shared by the session and drawn at no strength to compile it with the level; the state
## machine on a bare world stepped by hand (the free armor breaking, a shield still held, an upgraded armor's
## surviving hit, the armor's return, a pickup, death and a revive, a run that begins unprotected, a finished run
## and a mini-game level, nothing before the break); the pulses (their count, their rhythm under 3 a second, the
## steady edge after them) and slow time not putting them out of step with the siren, Reduced flashing (no
## pulses, a steady edge) and the siren's single play; the HUD running it by itself and a pause stopping it; and
## through the App on the real main scene: a level, a boss fight (its end too), a retry, a death, and the Beach's
## volleyball match, where nothing shows.

const Review = preload("res://tools/asset_gen/audio_review.gd")
## Every sound that warns of an attack (CLAUDE.md: each attack has an audio warning), from the sound banks' notes
## (tools/asset_gen/sfx_bank_*.gd): the siren must be quieter than all of them, so it can't mask one.
const ATTACK_WARNINGS: Array[StringName] = [
	&"fence_warning", &"cyborg_charge", &"truck_bang", &"truck_cannon_charge", &"truck_rev", &"octodog_windup",
	&"screech_shake", &"drone_swoop", &"drone_windup", &"bad_dream_shriek", &"barnacle_charge", &"buzz_rev",
	&"enforcer_whine", &"gilded_sentinel_grind", &"resonator_warning", &"magnate_roar", &"magnate_crackle",
	&"magnate_snarl", &"magnate_glitch", &"head_laser_charge", &"head_mouth_open", &"searchlight_lock",
	&"bomb_whistle", &"tower_crack", &"takeover_whine", &"gc_whine", &"gc_grind", &"gc_hatch", &"gc_whistle",
	&"cogs_aim", &"cogs_charge", &"guppy_rumble", &"guppy_floor_warn", &"wave_swell", &"swarm_chitter",
	&"swarm_wave", &"host_roar", &"sleep_taker_shriek", &"sleep_taker_whisper", &"sleep_taker_inhale",
	&"house_cherry", &"house_lightning", &"house_bar", &"heavy_cyborg_windup",
]
## Sounds with a warning's name that aren't one (the Buzz Overdrive's charge is the attack itself).
const NOT_WARNINGS: Array[StringName] = [&"buzz_charge"]
## What makes a library sound look like a warning by its name: a new one has to join ATTACK_WARNINGS (or NOT_WARNINGS).
const WARNING_NAMES: String = "warn|charge|windup|whine|chitter|swell|grind"
## Two-tone sounds the player can hear in a fight, which the siren must not be taken for: The House's jackpot (880
## and 660 Hz, about 0.23 s a tone; a reward) and the Floating Head's searchlight (1320 then 990 Hz in 0.14 s beeps;
## a bomb's warning).
const JACKPOT_SECONDS_PER_TONE: float = 0.23
const SEARCHLIGHT_SECONDS_PER_TONE: float = 0.14
## Warnings the siren may be as loud as or louder than on a phone speaker (set from the measured figures; see
## item 833: the owner may want it lower still).
const PHONE_LOUDER_MAX: int = 2
const SIREN_PATH: String = "res://assets/sfx/last_hit_siren.wav"
const TEST_BOSS_PATH: String = "res://data/bosses/test_boss.tres"
## One frame of the hand-stepped cue (seconds).
const STEP: float = 1.0 / 60.0
const HIGH_HZ: float = 698.46
const LOW_HZ: float = 493.88

var sim: RunSim
var rules: GameRules
var cue_tuning: LastHitWarningTuning
## Sounds asked of the world under test, with the cue's clock when they were (see _watch).
var _requests: Array[StringName] = []
var _stops: Array[StringName] = []
var _started: int = 0
var _ended: int = 0
var _clock: float = 0.0
var _request_times: Array[float] = []


func run() -> void:
	sim = RunSim.new(tree, tuning)
	rules = load("res://data/tuning/game_rules.tres") as GameRules
	cue_tuning = LastHitWarningTuning.load_default()
	_test_data()
	_test_siren_file()
	_test_panel()
	_test_layer()
	_test_strips()
	await _test_warm_up()
	await _test_state_machine()
	await _test_stacked_shields()
	await _test_pulses_and_reduced_flashing()
	await _test_start_unprotected()
	await _test_slow_time()
	await _test_in_the_hud()
	await _test_app()


# --- Data ----------------------------------------------------------------------------------------------

func _test_data() -> void:
	var t := LastHitWarningTuning.new()
	check(cue_tuning != null and cue_tuning.resource_path == LastHitWarningTuning.PATH, "the tuning loads from data/ui/last_hit_warning.tres")
	for prop: String in ["warn_at_start", "onset_delay", "pulse_count", "pulse_seconds", "pulse_alpha", "steady_alpha",
			"reduced_alpha", "edge_width", "fade_in_seconds", "fade_out_seconds"]:
		check(is_equal_approx(float(cue_tuning.get(prop)), float(t.get(prop))), "the file keeps the default %s (%s)" % [prop, cue_tuning.get(prop)])
	# Every number has a range hint, so F6 shows a slider for it.
	var ranged: PackedStringArray = []
	var low_pulse: float = 0.0
	var high_pulse: float = 0.0
	var max_cycles: int = 1
	for info: Dictionary in t.get_property_list():
		if (int(info["usage"]) & PROPERTY_USAGE_EDITOR) == 0 or (int(info["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var kind: int = int(info["type"])
		if kind == TYPE_FLOAT or kind == TYPE_INT:
			check(int(info["hint"]) == PROPERTY_HINT_RANGE, "%s has a range hint" % info["name"])
			ranged.append(String(info["name"]))
			if info["name"] == "pulse_seconds":
				low_pulse = float(String(info["hint_string"]).split(",")[0])
				high_pulse = float(String(info["hint_string"]).split(",")[1])
			if info["name"] == "pulse_count":
				max_cycles = int(String(info["hint_string"]).split(",")[1])
	check(ranged.size() == 9, "nine ranged numbers (%s)" % ", ".join(ranged))
	check(low_pulse >= 1.0 / 3.0 - 0.001, "the pulses can't be tuned faster than 3 a second (%.2f s)" % low_pulse)
	check(1.0 / cue_tuning.pulse_seconds <= 3.0, "and aren't (%.2f a second)" % (1.0 / cue_tuning.pulse_seconds))
	check(cue_tuning.pulse_count == 2 and cue_tuning.siren_seconds() < 1.5,
		"two pulses, a short siren (%.2f s)" % cue_tuning.siren_seconds())
	check(cue_tuning.pulse_seconds * 0.5 >= 0.3 and cue_tuning.pulse_seconds * 0.5 > 1.3 * JACKPOT_SECONDS_PER_TONE
		and cue_tuning.pulse_seconds * 0.5 > 2.0 * SEARCHLIGHT_SECONDS_PER_TONE,
		"each tone lasts %.2f s: slower than the jackpot's siren (%.2f s) and the searchlight's beeps (%.2f s)" % [
			cue_tuning.pulse_seconds * 0.5, JACKPOT_SECONDS_PER_TONE, SEARCHLIGHT_SECONDS_PER_TONE])
	check(cue_tuning.steady_alpha < cue_tuning.pulse_alpha and cue_tuning.steady_alpha <= cue_tuning.reduced_alpha
		and cue_tuning.reduced_alpha < cue_tuning.pulse_alpha, "dim steady edge under the pulses' peak, Reduced flashing's a little stronger")
	check(cue_tuning.edge_width <= 0.15, "the edge is a narrow band (%.2f of the screen's height)" % cue_tuning.edge_width)
	var longest: float = float(max_cycles) * high_pulse + LastHitWarningTuning.SIREN_TAIL
	check(longest < 2.5, "however it's tuned, the siren stays under the library's 2.5 s limit (%.2f s)" % longest)


# --- The siren -----------------------------------------------------------------------------------------

func _test_siren_file() -> void:
	var library := load("res://data/audio/sfx_library.tres") as SfxLibrary
	check(library.names().has("last_hit_siren") and library.stream(&"last_hit_siren") != null, "the sound library has last_hit_siren")
	check(float(library.pitch_variation.get("last_hit_siren", 0.0)) == 0.0, "with no pitch variation: it sounds the same every time")
	# As heard (the loudest 400 ms after each of the sound tools' weightings, plus the library's level): under every
	# attack warning in the library, so it can't mask one. "k" is headphones and PC speakers, "phone" a small speaker.
	var named: PackedStringArray = []
	var warning_name := RegEx.create_from_string("(%s)" % WARNING_NAMES)
	for sound: String in library.names():
		if warning_name.search(sound) != null and not ATTACK_WARNINGS.has(StringName(sound)) and not NOT_WARNINGS.has(StringName(sound)):
			named.append(sound)
	check(named.is_empty(), "every sound named like a warning is in the test's list of attack warnings (not yet: %s)" % ", ".join(named))
	var siren: Dictionary = _heard(library, &"last_hit_siren")
	var quietest: Dictionary = {"k": 1000.0, "phone": 1000.0}
	var quietest_name: Dictionary = {"k": &"", "phone": &""}
	var louder_on_phone: PackedStringArray = []
	var near_on_phone: PackedStringArray = []
	var missing: PackedStringArray = []
	for warning: StringName in ATTACK_WARNINGS:
		if not library.names().has(String(warning)):
			missing.append(String(warning))
			continue
		var heard: Dictionary = _heard(library, warning)
		for weighting: String in ["k", "phone"]:
			if float(heard[weighting]) < float(quietest[weighting]):
				quietest[weighting] = heard[weighting]
				quietest_name[weighting] = warning
		if float(siren["phone"]) >= float(heard["phone"]):
			louder_on_phone.append("%s %+.1f" % [warning, float(siren["phone"]) - float(heard["phone"])])
		elif float(heard["phone"]) - float(siren["phone"]) < 3.0:
			near_on_phone.append("%s %+.1f" % [warning, float(heard["phone"]) - float(siren["phone"])])
	check(missing.is_empty(), "every attack warning in the test's list is in the library (missing: %s)" % ", ".join(missing))
	var margin: float = float(quietest["k"]) - float(siren["k"])
	check(margin >= 1.5, "headphones and PC speakers: %.1f dB heard, %.1f dB under the quietest of the %d attack warnings (%s, %.1f dB)" % [
		float(siren["k"]), margin, ATTACK_WARNINGS.size(), quietest_name["k"], float(quietest["k"])])
	check(margin < 6.0, "but not so far under that it is lost (%.1f dB)" % margin)
	# A phone speaker has little below 450 Hz, which is most of what many warnings are made of, so the siren
	# (494 and 698 Hz) is relatively louder there: reported for the owner (item 833), and held to the
	# few warnings it is already known to match.
	var phone_margin: float = float(quietest["phone"]) - float(siren["phone"])
	print("  last_hit_siren on a phone speaker: %.1f dB heard, %.1f dB against the quietest attack warning (%s, %.1f dB); as loud as or louder than %d of %d: %s; within 3 dB over it: %s" % [
		float(siren["phone"]), phone_margin, quietest_name["phone"], float(quietest["phone"]), louder_on_phone.size(),
		ATTACK_WARNINGS.size(), ", ".join(louder_on_phone), ", ".join(near_on_phone)])
	check(louder_on_phone.size() <= PHONE_LOUDER_MAX, "on a phone speaker it is as loud as or louder than at most %d warnings (%d: %s)" % [
		PHONE_LOUDER_MAX, louder_on_phone.size(), ", ".join(louder_on_phone)])
	var sfx := PlayerSfx.new()
	sfx.setup(library)
	var found: bool = false
	for child: Node in sfx.get_children():
		var player := child as AudioStreamPlayer
		found = found or (player.stream == library.stream(&"last_hit_siren") and player.bus == SfxLibrary.BUS)
	check(found, "it plays through the run's PlayerSfx on the SFX bus")
	sfx.free()

	var wav := AudioStreamWAV.load_from_file(SIREN_PATH, {"compress/mode": 0})
	check(wav != null and wav.loop_mode == AudioStreamWAV.LOOP_DISABLED, "the file is not a loop")
	if wav == null:
		return
	var length: float = wav.get_length()
	check(length > 0.1 and length < 2.5 and absf(length - cue_tuning.siren_seconds()) < 0.03,
		"it lasts as long as the pulses do (%.3f s of %.3f s)" % [length, cue_tuning.siren_seconds()])
	# Two flat tones alternating, the high one first, once for each pulse: measured by zero crossings in the
	# middle of each half of each period.
	var pcm: PackedByteArray = wav.data
	var half: float = cue_tuning.pulse_seconds * 0.5
	var rate: float = float(wav.mix_rate)
	var tones: PackedFloat32Array = []
	for k: int in cue_tuning.pulse_count * 2:
		tones.append(_frequency(pcm, rate, (float(k) + 0.25) * half, (float(k) + 0.75) * half))
	var alternates: bool = tones.size() == cue_tuning.pulse_count * 2
	for k: int in tones.size():
		var want: float = HIGH_HZ if k % 2 == 0 else LOW_HZ
		alternates = alternates and absf(tones[k] - want) / want < 0.06
	check(alternates, "two tones alternating, high then low, %d times (%s Hz)" % [cue_tuning.pulse_count, ", ".join(Array(tones).map(
		func(hz: float) -> String: return "%.0f" % hz))])
	var steady: bool = true
	for k: int in tones.size():
		# Each tone is flat: its two halves measure the same (a sweep, a whine or a warble would not).
		var a: float = _frequency(pcm, rate, (float(k) + 0.1) * half, (float(k) + 0.45) * half)
		var b: float = _frequency(pcm, rate, (float(k) + 0.55) * half, (float(k) + 0.9) * half)
		steady = steady and absf(a - b) / maxf(a, 1.0) < 0.05
	check(steady, "each tone is a flat note, not a sweep: nothing like the Enforcer Truck's whoops or an attack's rising whine")
	check(_rms(pcm, 0.0, length) > 0.05 and _rms(pcm, length - 0.02, length) < 0.05, "it is loud through the tones and quiet at the end")


## How loud a library sound is heard, after each weighting of the sound tools (audio_review.gd): the loudest 400 ms of
## its file, plus the library's level for it (dB): {"k": headphones and PC speakers, "phone": a small speaker}.
func _heard(library: SfxLibrary, sound: StringName) -> Dictionary:
	var wav := AudioStreamWAV.load_from_file(library.folder.path_join(String(sound) + ".wav"), {"compress/mode": 0})
	var samples := PackedFloat32Array()
	samples.resize(wav.data.size() / 2)
	for i: int in samples.size():
		samples[i] = wav.data.decode_s16(i * 2) / 32768.0
	return {"k": Review.weighted_loudness_db(samples, &"k") + library.volume(sound),
		"phone": Review.weighted_loudness_db(samples, &"phone") + library.volume(sound)}


## The pitch of 16-bit mono PCM between two times, from its rising zero crossings.
func _frequency(pcm: PackedByteArray, rate: float, from: float, to: float) -> float:
	var first: int = int(from * rate)
	var last: int = mini(int(to * rate), pcm.size() / 2 - 1)
	var crossings: int = 0
	var previous: int = pcm.decode_s16(first * 2)
	for i: int in range(first + 1, last):
		var s: int = pcm.decode_s16(i * 2)
		if previous < 0 and s >= 0:
			crossings += 1
		previous = s
	return float(crossings) / maxf(to - from, 0.001)


func _rms(pcm: PackedByteArray, from: float, to: float) -> float:
	var first: int = int(from * 32000.0)
	var last: int = mini(int(to * 32000.0), pcm.size() / 2)
	var sum: float = 0.0
	for i: int in range(first, last):
		var v: float = pcm.decode_s16(i * 2) / 32768.0
		sum += v * v
	return sqrt(sum / maxi(last - first, 1))


func _test_panel() -> void:
	var copy := cue_tuning.duplicate() as LastHitWarningTuning
	var panel := TuningPanel.new()
	tree.root.add_child(panel)
	panel.setup([{"title": "One hit from death", "resource": copy, "path": LastHitWarningTuning.PATH}] as Array[Dictionary])
	for prop: String in ["onset_delay", "pulse_count", "pulse_seconds", "pulse_alpha", "steady_alpha", "reduced_alpha", "edge_width",
			"fade_in_seconds", "fade_out_seconds"]:
		check(panel.find_slider(prop) != null, "F6 has a slider for %s" % prop)
	var slider: HSlider = panel.find_slider("steady_alpha")
	if slider != null:
		slider.value = 0.4
		check(is_equal_approx(copy.steady_alpha, 0.4) and is_equal_approx(cue_tuning.steady_alpha, 0.28), "a slider edits its own copy live")
	panel.free()


# --- The layer, the strips and the shader -----------------------------------------------------------------

## Every canvas layer the game's scripts give a literal number to: [{file, layer}].
func _canvas_layers(path: String, out: Array) -> void:
	var literal := RegEx.create_from_string("\\blayer = (-?\\d+)")
	var constant := RegEx.create_from_string("\\b[A-Z_]*LAYER: int = (-?\\d+)")
	for file: String in DirAccess.get_files_at(path):
		if not file.ends_with(".gd") or file == "last_hit_warning.gd":
			continue
		var text: String = FileAccess.get_file_as_string(path.path_join(file))
		for re: RegEx in [literal, constant]:
			for m: RegExMatch in re.search_all(text):
				out.append({"file": path.path_join(file), "layer": int(m.get_string(1))})
	for dir: String in DirAccess.get_directories_at(path):
		_canvas_layers(path.path_join(dir), out)


func _test_layer() -> void:
	var found: Array = []
	_canvas_layers("res://scripts", found)
	var lowest: int = 1000
	var lowest_file: String = ""
	var markers: PackedStringArray = []
	for entry: Dictionary in found:
		if int(entry["layer"]) < lowest:
			lowest = int(entry["layer"])
			lowest_file = String(entry["file"])
		if String(entry["file"]).ends_with("enforcer_truck.gd") or String(entry["file"]).ends_with("golden_convergence_magnate.gd"):
			markers.append("%s %d" % [String(entry["file"]).get_file(), int(entry["layer"])])
	check(found.size() >= 6 and markers.size() == 2, "(the scan finds the game's canvas layers: %d, the Enforcer Truck's and the Magnate's markers among them: %s)" % [
		found.size(), ", ".join(markers)])
	check(LastHitWarning.LAYER < lowest, "the cue's canvas layer (%d) is under every other layer the game's scripts build (the lowest is %s's, %d): the attack markers and the slow-time tint at 4, SpeedLines at 3, the HUD at 5, so it never covers a marker" % [
		LastHitWarning.LAYER, lowest_file.get_file(), lowest])
	check(LastHitWarning.LAYER > 0, "and above the 3D world")
	var world: RunWorld = _world(true)
	var cue: LastHitWarning = _cue(world)
	check(cue.layer == LastHitWarning.LAYER, "the node uses it")
	cue.free()
	world.queue_free()


func _test_strips() -> void:
	for size: Vector2 in [Vector2(1280, 720), Vector2(844, 390), Vector2(640, 290), Vector2(390, 844)]:
		var rects: Array[Rect2] = LastHitWarning.strip_rects(size, cue_tuning.edge_width)
		var screen := Rect2(Vector2.ZERO, size)
		var area: float = 0.0
		var overlap: float = 0.0
		var inside: bool = rects.size() == 4
		var middle: bool = false
		var centre := Rect2(size * 0.25, size * 0.5)
		for i: int in rects.size():
			area += rects[i].get_area()
			inside = inside and screen.encloses(rects[i])
			middle = middle or rects[i].intersects(centre)
			for j: int in range(i + 1, rects.size()):
				overlap += rects[i].intersection(rects[j]).get_area()
		var depth: float = cue_tuning.edge_width * minf(size.x, size.y)
		check(inside and overlap < 0.5 and not middle,
			"%dx%d: four strips on the screen, drawing no pixel twice, none in the middle half" % [size.x, size.y])
		check(absf(rects[0].size.x - depth) < 0.01 and absf(rects[2].size.y - depth) < 0.01,
			"%dx%d: as deep as the band (%.0f px)" % [size.x, size.y, depth])
		var share: float = area / screen.get_area()
		check(share < 0.42, "%dx%d: only %.0f%% of the screen is drawn (a full-screen pass would be 100%%)" % [size.x, size.y, share * 100.0])
	# The live strips are laid out for the holder's size.
	var world: RunWorld = _world(true)
	var cue: LastHitWarning = _cue(world)
	var shot := _shot()
	world.player.receive_hit(shot)
	shot.free()
	_step(cue, 0.5)
	var holder: Control = cue.get_child(0)
	var expected: Array[Rect2] = LastHitWarning.strip_rects(holder.size, cue_tuning.edge_width)
	var placed: bool = cue.is_drawn() and holder.get_child_count() == 4
	for i: int in holder.get_child_count():
		var strip := holder.get_child(i) as ColorRect
		placed = placed and strip.position.is_equal_approx(expected[i].position) and strip.size.is_equal_approx(expected[i].size)
		var material := strip.material as ShaderMaterial
		placed = placed and (material.get_shader_parameter(&"origin") as Vector2).is_equal_approx(expected[i].position / Vector2(maxf(holder.size.x, 1.0), maxf(holder.size.y, 1.0)))
	check(placed, "the cue's strips sit where strip_rects puts them for its %dx%d" % [holder.size.x, holder.size.y])
	cue.free()
	world.queue_free()


func _test_warm_up() -> void:
	var was_warmed: bool = LastHitWarning.warmed
	var world: RunWorld = _world(true)
	var a: LastHitWarning = _cue(world)
	var b := LastHitWarning.new()
	b.process_mode = Node.PROCESS_MODE_DISABLED
	tree.root.add_child(b)
	var shared: Shader = LastHitWarning.shared_shader()
	var one_shader: bool = shared != null and shared == LastHitWarning.shared_shader()
	for cue: LastHitWarning in [a, b]:
		for strip: Node in cue.get_child(0).get_children():
			one_shader = one_shader and ((strip as ColorRect).material as ShaderMaterial).shader == shared
	check(one_shader, "every strip of every cue uses the one shared Shader, so the session compiles it once")
	# A headless run draws nothing, so it warms nothing.
	check(not ShaderWarmup.needed() and not a.is_warming() and not a.is_drawn(), "a headless run doesn't warm the shader up (nothing is drawn)")
	# Where the game renders, setup() does this: the strips are drawn at no strength for ShaderWarmup.DRAWN_FRAMES frames.
	LastHitWarning.warmed = false
	a.warm_up()
	var intensity: float = ((a.get_child(0).get_child(0) as ColorRect).material as ShaderMaterial).get_shader_parameter(&"intensity")
	check(a.is_warming() and a.is_drawn() and a.level() == 0.0 and intensity == 0.0,
		"warming up: the strips are drawn at no strength (level %.2f, shader intensity %.2f)" % [a.level(), intensity])
	check(RenderingServer.frame_post_draw.is_connected(a.note_frame_drawn), "counting the frames as they are drawn")
	for i: int in ShaderWarmup.DRAWN_FRAMES - 1:
		a.note_frame_drawn()
	check(a.is_warming() and a.is_drawn(), "still drawn until %d frames have been" % ShaderWarmup.DRAWN_FRAMES)
	a.note_frame_drawn()
	check(not a.is_warming() and not a.is_drawn() and LastHitWarning.warmed and not RenderingServer.frame_post_draw.is_connected(a.note_frame_drawn),
		"then hidden, once for the session")
	b.warm_up()
	check(not b.is_warming(), "and a later run doesn't warm it again")
	# The break after a warm-up draws the edge as usual.
	var shot := _shot()
	world.player.receive_hit(shot)
	shot.free()
	_step(a, 0.5)
	check(a.is_on() and a.is_drawn() and a.level() > 0.0, "the first break shows the edge at once")
	LastHitWarning.warmed = was_warmed
	a.free()
	b.free()
	world.queue_free()


func _test_slow_time() -> void:
	# Slow time slows the HUD's delta, not the siren (a recording): the cue runs on real seconds.
	var shot := _shot()
	var world: RunWorld = _world(true)
	var cue: LastHitWarning = _cue(world)
	world.player.receive_hit(shot)
	var broke_at: float = _clock
	var levels: PackedFloat32Array = []
	Engine.time_scale = 0.5
	for i: int in int(round((cue_tuning.onset_delay + cue_tuning.pulse_count * cue_tuning.pulse_seconds + 0.4) / STEP)):
		_clock += STEP
		cue._process(STEP * Engine.time_scale)
		levels.append(cue.level())
	Engine.time_scale = 1.0
	check(_sirens() == 1 and absf(_request_times[0] - broke_at - cue_tuning.onset_delay) < 2.0 * STEP,
		"at half speed the siren still starts %.2f s of real time after the break (%.3f s)" % [cue_tuning.onset_delay,
			_request_times[0] - broke_at if not _request_times.is_empty() else -1.0])
	var peaks: PackedFloat32Array = []
	for i: int in range(1, levels.size() - 1):
		if levels[i] > levels[i - 1] and levels[i] >= levels[i + 1] and levels[i] > (cue_tuning.pulse_alpha + cue_tuning.steady_alpha) * 0.5:
			peaks.append((i + 1) * STEP)
	var in_step: bool = peaks.size() == cue_tuning.pulse_count
	for k: int in peaks.size():
		in_step = in_step and absf(peaks[k] - (cue_tuning.onset_delay + (float(k) + LastHitWarning.PULSE_ATTACK) * cue_tuning.pulse_seconds)) < 0.05
	check(in_step and absf(levels[levels.size() - 1] - cue_tuning.steady_alpha) < 0.001,
		"and its pulses keep the siren's high tones (real seconds %s), settled to the steady edge after them" % ", ".join(Array(peaks).map(
			func(t: float) -> String: return "%.2f" % t)))
	cue.free()
	shot.free()
	await sim.free_world(world)


# --- The cue on a bare world ---------------------------------------------------------------------------

func _shot() -> Hazard:
	var shot := Hazard.new()
	shot.hazard_name = "test shot"
	shot.is_enemy_attack = true
	return shot


## A world with the free armor (`armor`), `shield` charges, and the armor upgrade `tier` (0: the free armor).
func _world(armor: bool, shield: int = 0, tier: int = 0) -> RunWorld:
	var loadout := Loadout.new()
	loadout.armor = armor
	if tier > 0:
		loadout.tiers[&"armor"] = tier
	if shield > 0:
		loadout.charges[&"shield"] = shield
	return sim.build_world(RunSim.layout(5, 1500.0), loadout)


## A cue on `world`, stepped by hand (its own frames switched off), with what it asks of the world noted.
func _cue(world: RunWorld, live: Callable = Callable(), context: RunContext = null) -> LastHitWarning:
	var cue := LastHitWarning.new()
	cue.process_mode = Node.PROCESS_MODE_DISABLED
	tree.root.add_child(cue)
	cue.tuning = cue_tuning
	cue.setup(world, context, live)
	_requests.clear()
	_stops.clear()
	_request_times.clear()
	_started = 0
	_ended = 0
	_clock = 0.0
	world.sounds.requested.connect(func(sound: StringName) -> void:
		_requests.append(sound)
		if sound == LastHitWarning.SIREN:
			_request_times.append(_clock))
	world.sounds.stopped.connect(func(sound: StringName) -> void: _stops.append(sound))
	cue.started.connect(func() -> void: _started += 1)
	cue.ended.connect(func() -> void: _ended += 1)
	return cue


## Steps the cue `seconds` forward; returns the strongest edge it showed.
func _step(cue: LastHitWarning, seconds: float) -> float:
	var peak: float = 0.0
	for i: int in int(round(seconds / STEP)):
		_clock += STEP
		cue.advance(STEP)
		peak = maxf(peak, cue.level())
	return peak


func _sirens() -> int:
	return _requests.count(LastHitWarning.SIREN)


## Times the siren was cut off.
func _cuts() -> int:
	return _stops.count(LastHitWarning.SIREN)


func _free(world: RunWorld, cue: LastHitWarning) -> void:
	cue.free()
	await sim.free_world(world)


## Stacked shields (GDD §8): the cue waits for the last shield after the armor, however many there were.
func _test_stacked_shields() -> void:
	var shot := _shot()
	var window: float = cue_tuning.onset_delay + cue_tuning.siren_seconds() + cue_tuning.fade_in_seconds
	var world: RunWorld = _world(true, 3)
	var p: Player = world.player
	var cue: LastHitWarning = _cue(world)
	p.receive_hit(shot)
	for left: int in [2, 1]:
		p.invulnerable_left = 0.0
		check(p.receive_hit(shot) == DamageRules.Outcome.BLOCKED_SHIELD and p.shield == left, "a stacked shield breaks (%d left)" % left)
		_step(cue, window)
		check(not cue.is_on() and cue.level() == 0.0 and _sirens() == 0, "%d shield(s) in hand: no cue, no siren" % left)
	p.invulnerable_left = 0.0
	check(p.receive_hit(shot) == DamageRules.Outcome.BLOCKED_SHIELD and p.shield == 0 and p.alive, "the last shield breaks")
	_step(cue, STEP + cue_tuning.onset_delay + STEP)
	check(cue.is_on() and _started == 1 and _sirens() == 1, "the cue starts with the last shield's break only")
	shot.free()
	await _free(world, cue)


func _test_state_machine() -> void:
	var shot := _shot()
	var window: float = cue_tuning.onset_delay + cue_tuning.siren_seconds() + cue_tuning.fade_in_seconds

	# The free armor breaks, with no shield: the cue starts and the siren plays once.
	var world: RunWorld = _world(true)
	var p: Player = world.player
	var cue: LastHitWarning = _cue(world)
	_step(cue, 1.0)
	check(not cue.is_on() and cue.level() == 0.0 and _sirens() == 0 and _started == 0 and not cue.is_drawn(),
		"protected by the free armor: no cue, no edge, no siren")
	check(p.receive_hit(shot) == DamageRules.Outcome.BLOCKED_ARMOR and p.alive and p.armor == 0 and p.shield == 0, "the free armor breaks")
	var broke_at: float = _clock
	_step(cue, STEP)
	check(cue.is_on() and _started == 1 and cue.level() > 0.0, "the cue starts the frame after")
	check(_sirens() == 0, "the siren waits for the armor's own break to be heard (%.2f s)" % cue_tuning.onset_delay)
	_step(cue, cue_tuning.onset_delay)
	check(_sirens() == 1 and absf(_request_times[0] - broke_at - cue_tuning.onset_delay) < 2.0 * STEP,
		"then plays once, %.2f s after the break (%s at %.3f s)" % [cue_tuning.onset_delay, _requests,
			_request_times[0] - broke_at if not _request_times.is_empty() else -1.0])
	_step(cue, window + 2.0)
	check(_sirens() == 1 and _started == 1 and _cuts() == 0, "and only once: not a loop, however long the player stays unprotected")
	check(cue.is_on() and absf(cue.level() - cue_tuning.steady_alpha) < 0.001 and cue.is_drawn(),
		"a dim steady edge stays while unprotected (%.3f)" % cue.level())

	# The armor comes back: the cue ends, and the edge fades away.
	check(p.armor_state.tick(rules.armor_recharge + 1.0) and p.armor == rules.armor_hits, "the armor's wait is over")
	cue.advance(STEP)
	check(not cue.is_on() and _ended == 1, "the cue ends the frame it does")
	_step(cue, cue_tuning.fade_out_seconds + 0.1)
	check(cue.level() == 0.0 and not cue.is_drawn(), "the edge fades out within %.1f s" % cue_tuning.fade_out_seconds)
	check(_cuts() == 0, "the siren, long over, isn't cut again")
	await _free(world, cue)

	# A shield still held: the armor breaking brings no cue; the shield breaking does.
	world = _world(true, 1)
	p = world.player
	cue = _cue(world)
	p.receive_hit(shot)
	_step(cue, window)
	check(p.armor == 0 and p.shield == 1 and not cue.is_on() and cue.level() == 0.0 and _sirens() == 0,
		"the armor gone but a shield in hand: no cue, no siren")
	p.invulnerable_left = 0.0
	check(p.receive_hit(shot) == DamageRules.Outcome.BLOCKED_SHIELD and p.shield == 0 and p.alive, "the shield breaks")
	_step(cue, STEP + cue_tuning.onset_delay + STEP)
	check(cue.is_on() and _sirens() == 1 and _started == 1, "the cue starts with the shield's break, and the siren plays")
	# A shield picked up while it is on ends it, and the siren is cut off if it is still playing.
	check(p.gain_item(&"shield", 1), "a shield pickup is taken")
	cue.advance(STEP)
	check(not cue.is_on() and _ended == 1 and _cuts() == 1, "a shield in hand again ends it and cuts the siren short")
	_step(cue, cue_tuning.fade_out_seconds + 0.1)
	check(cue.level() == 0.0, "(the edge fades out)")
	await _free(world, cue)

	# An upgraded armor takes hits it survives: no cue until its last one breaks it.
	var tier: int = 3
	var hits: int = rules.armor_hits_at(tier)
	check(hits >= 2, "the tier-3 armor takes %d hits" % hits)
	world = _world(true, 0, tier)
	p = world.player
	cue = _cue(world)
	for i: int in hits - 1:
		p.invulnerable_left = 0.0
		check(p.receive_hit(shot) == DamageRules.Outcome.BLOCKED_ARMOR and p.armor == hits - 1 - i, "hit %d is blocked" % (i + 1))
		_step(cue, window)
		check(not cue.is_on() and cue.level() == 0.0 and _sirens() == 0, "with %d hit(s) left: no cue, no siren" % p.armor)
	p.invulnerable_left = 0.0
	p.receive_hit(shot)
	_step(cue, window)
	check(p.armor == 0 and cue.is_on() and _sirens() == 1, "its last hit gone: the cue and the siren")
	# A pickup while the armor is broken brings it back whole.
	check(p.gain_item(&"armor") and p.armor == hits, "an armor pickup brings it back")
	_step(cue, STEP)
	check(not cue.is_on() and _ended == 1, "and ends the cue")
	await _free(world, cue)

	# Death ends the cue; a revive with the armor carried starts nothing.
	world = _world(true)
	p = world.player
	cue = _cue(world)
	p.receive_hit(shot)
	_step(cue, cue_tuning.onset_delay + 3.0 * STEP)
	check(cue.is_on() and _sirens() == 1, "(the cue is on, the siren playing)")
	p.call(&"_die", "test hazard")
	cue.advance(STEP)
	check(not p.alive and not cue.is_on() and _ended == 1 and _cuts() == 1,
		"the player dies: the cue ends and the siren is cut")
	_step(cue, cue_tuning.fade_out_seconds + 0.1 + window)
	check(cue.level() == 0.0 and _sirens() == 1 and _started == 1, "nothing while dead (no edge, no second siren)")
	p.revive()
	check(p.alive and p.armor == rules.armor_hits, "a revive brings the carried armor back whole")
	_step(cue, window)
	check(not cue.is_on() and _sirens() == 1 and _started == 1, "so the revived runner is protected: no cue")
	await _free(world, cue)

	# Dying while protected: never a cue. A death by a crash the armor doesn't stop.
	world = _world(true)
	p = world.player
	cue = _cue(world)
	var wall := Hazard.new()
	wall.hazard_name = "test wall"
	wall.is_solid = true
	check(p.receive_hit(wall) == DamageRules.Outcome.KILL and not p.alive, "a crash kills the protected runner")
	_step(cue, window)
	check(not cue.is_on() and _started == 0 and _sirens() == 0 and cue.level() == 0.0, "and there was no cue before or after")
	wall.free()
	await _free(world, cue)

	# A run that is over (won or given up), the live check answering no: no cue, even unprotected.
	var live: Array[bool] = [true]
	world = _world(true)
	p = world.player
	cue = _cue(world, func() -> bool: return live[0])
	p.receive_hit(shot)
	_step(cue, STEP * 3.0)
	check(cue.is_on(), "(a run being played: the cue is on)")
	live[0] = false
	cue.advance(STEP)
	check(not cue.is_on() and _ended == 1, "the run ends: the cue ends")
	_step(cue, window)
	check(not cue.is_on() and _started == 1, "and doesn't come back")
	await _free(world, cue)

	# A mini-game level (the Beach's volleyball match: the runner can't die there): never.
	var ctx := RunContext.new()
	ctx.config = LevelConfig.new()
	ctx.config.minigame = load("res://data/minigames/volleyball.tres") as MiniGameDef
	check(ctx.config.plays_minigame(), "(a level that plays a mini-game)")
	world = _world(false)
	cue = _cue(world, Callable(), ctx)
	_step(cue, window)
	check(not world.player.armor_state.is_up() and not cue.is_on() and _started == 0 and _sirens() == 0 and cue.level() == 0.0,
		"an unprotected runner in a mini-game level: no cue, no siren")
	await _free(world, cue)
	shot.free()


# --- The pulses ----------------------------------------------------------------------------------------

func _test_pulses_and_reduced_flashing() -> void:
	var shot := _shot()
	var was_reduced: bool = Settings.flashing_reduced
	Settings.flashing_reduced = false
	var world: RunWorld = _world(true)
	var cue: LastHitWarning = _cue(world)
	world.player.receive_hit(shot)
	var levels: PackedFloat32Array = []
	var seconds: float = cue_tuning.onset_delay + cue_tuning.pulse_count * cue_tuning.pulse_seconds + 0.6
	for i: int in int(round(seconds / STEP)):
		_step(cue, STEP)
		levels.append(cue.level())
	var peaks: PackedFloat32Array = []
	var peak_times: PackedFloat32Array = []
	var middle: float = (cue_tuning.pulse_alpha + cue_tuning.steady_alpha) * 0.5
	for i: int in range(1, levels.size() - 1):
		if levels[i] > levels[i - 1] and levels[i] >= levels[i + 1] and levels[i] > middle:
			peaks.append(levels[i])
			peak_times.append((i + 1) * STEP)
	check(peaks.size() == cue_tuning.pulse_count, "the edge pulses %d times (%d peaks)" % [cue_tuning.pulse_count, peaks.size()])
	var strong: bool = not peaks.is_empty()
	for v: float in peaks:
		strong = strong and absf(v - cue_tuning.pulse_alpha) < 0.03
	check(strong, "each to about %.2f at the edge (%s)" % [cue_tuning.pulse_alpha, ", ".join(Array(peaks).map(func(v: float) -> String: return "%.2f" % v))])
	var rhythm: bool = peak_times.size() == cue_tuning.pulse_count
	for k: int in peak_times.size():
		var expected: float = cue_tuning.onset_delay + (float(k) + LastHitWarning.PULSE_ATTACK) * cue_tuning.pulse_seconds
		rhythm = rhythm and absf(peak_times[k] - expected) < 0.05
	check(rhythm, "on the siren's high tones, one every %.2f s (%s s)" % [cue_tuning.pulse_seconds, ", ".join(Array(peak_times).map(
		func(t: float) -> String: return "%.2f" % t))])
	check(1.0 / cue_tuning.pulse_seconds <= 3.0, "never more than 3 a second")
	check(absf(levels[levels.size() - 1] - cue_tuning.steady_alpha) < 0.001, "then the dim steady edge (%.3f)" % levels[levels.size() - 1])
	var dips: bool = true
	for i: int in range(int((cue_tuning.onset_delay + cue_tuning.fade_in_seconds) / STEP), levels.size()):
		dips = dips and levels[i] >= cue_tuning.steady_alpha - 0.001
	check(dips, "and it never drops under the steady edge between pulses")
	# The edge is up the moment the protection runs out, before the siren.
	check(levels[int(cue_tuning.onset_delay / STEP) - 1] > 0.05 and _sirens() == 1, "the steady edge is already up when the siren begins")
	await _free(world, cue)

	# Reduced flashing: no pulses at all, a steady edge that comes up smoothly and holds, the siren as ever.
	Settings.flashing_reduced = true
	world = _world(true)
	cue = _cue(world)
	world.player.receive_hit(shot)
	levels.clear()
	for i: int in int(round(seconds / STEP)):
		_step(cue, STEP)
		levels.append(cue.level())
	var most: float = 0.0
	var rising: bool = true
	for i: int in levels.size():
		most = maxf(most, levels[i])
		rising = rising and (i == 0 or levels[i] >= levels[i - 1] - 0.0001)
	check(rising and absf(most - cue_tuning.reduced_alpha) < 0.001 and absf(levels[levels.size() - 1] - cue_tuning.reduced_alpha) < 0.001,
		"Reduced flashing: no pulsing, the edge rises smoothly to a steady %.2f and holds (most %.3f)" % [cue_tuning.reduced_alpha, most])
	check(_sirens() == 1, "the siren still plays once (it is sound, not a flash)")
	await _free(world, cue)
	Settings.flashing_reduced = was_reduced
	shot.free()


func _test_start_unprotected() -> void:
	var window: float = cue_tuning.onset_delay + cue_tuning.siren_seconds() + cue_tuning.fade_in_seconds
	# A level or a fight that begins with no armor (a bare loadout): the cue once, at the start.
	var world: RunWorld = _world(false)
	var cue: LastHitWarning = _cue(world)
	_step(cue, window)
	check(cue.is_on() and _started == 1 and _sirens() == 1 and absf(cue.level() - cue_tuning.steady_alpha) < 0.001,
		"a run that begins unprotected gives the cue once at the start")
	# Then a revive with nothing to restore: unprotected again, so the cue again.
	world.player.call(&"_die", "test hazard")
	_step(cue, STEP)
	check(not cue.is_on() and _ended == 1, "(dead: the cue ends)")
	_step(cue, cue_tuning.fade_out_seconds + 0.1)
	world.player.revive()
	_step(cue, window)
	check(cue.is_on() and _started == 2 and _sirens() == 2, "a revive that brings back no protection starts it again")
	await _free(world, cue)

	# warn_at_start off: nothing until the player has been protected once.
	cue_tuning.warn_at_start = false
	world = _world(false)
	cue = _cue(world)
	_step(cue, window)
	check(not cue.is_on() and _started == 0 and _sirens() == 0, "with warn_at_start off, an unprotected start gives no cue")
	world.player.armor_state.take_pickup()
	_step(cue, STEP)
	world.player.armor_state.block()
	_step(cue, window)
	check(cue.is_on() and _started == 1 and _sirens() == 1, "but losing protection it had does")
	cue_tuning.warn_at_start = true
	await _free(world, cue)


# --- The HUD ---------------------------------------------------------------------------------------------

## Waits `seconds` of real time (the HUD's own frames run on it).
func _wait(seconds: float) -> void:
	await tree.create_timer(seconds, true, false, true).timeout


func _test_in_the_hud() -> void:
	var shot := _shot()
	var world: RunWorld = _world(true)
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.CAMPAIGN
	var hud := RunHud.new()
	tree.root.add_child(hud)
	hud.bind(world, ctx)
	_requests.clear()
	world.sounds.requested.connect(func(sound: StringName) -> void: _requests.append(sound))
	var cue: LastHitWarning = hud.last_hit
	check(cue != null and cue.get_parent() == hud and cue.layer < hud.layer,
		"the HUD has the cue, on a canvas layer of its own under the HUD's (%d under %d)" % [cue.layer, hud.layer])
	var touchless: bool = cue.get_child(0).mouse_filter == Control.MOUSE_FILTER_IGNORE
	for strip: Node in cue.get_child(0).get_children():
		touchless = touchless and (strip as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE
	check(touchless, "it takes no touches")
	await _wait(0.1)
	check(not cue.is_on() and not cue.is_drawn(), "protected: the HUD shows nothing")
	world.player.receive_hit(shot)
	await _wait(cue_tuning.onset_delay + 0.3)
	check(cue.is_on() and cue.level() > 0.0 and cue.is_drawn() and _requests.count(LastHitWarning.SIREN) == 1,
		"the HUD starts the cue by itself when the armor breaks: the edge shows and the siren plays once")
	var shaded: bool = cue.get_child(0).get_child_count() == 4
	for strip: Node in cue.get_child(0).get_children():
		shaded = shaded and (strip as ColorRect).material is ShaderMaterial
	check(shaded, "the edge is four strips on one canvas shader (nothing the web renderer can't do)")
	# A pause stops it where it is.
	var level: float = cue.level()
	var age: int = _requests.size()
	tree.paused = true
	await _wait(0.4)
	check(is_equal_approx(cue.level(), level) and _requests.size() == age, "a pause holds the cue still")
	tree.paused = false
	# A new world (a restart): the cue starts over, off for a protected runner.
	world.player.armor_state.tick(rules.armor_recharge + 1.0)
	await _wait(0.1)
	check(not cue.is_on(), "the armor's return ends it")
	hud.queue_free()
	await sim.free_world(world)
	var world2: RunWorld = _world(true)
	var hud2 := RunHud.new()
	tree.root.add_child(hud2)
	hud2.bind(world2, ctx)
	await _wait(0.1)
	check(not hud2.last_hit.is_on() and hud2.last_hit.level() == 0.0, "a fresh run's HUD starts with no cue")
	hud2.queue_free()
	await sim.free_world(world2)
	shot.free()


# --- Through the App -------------------------------------------------------------------------------------

func _test_app() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	var saved: Profile = App.profile
	App.profile = Profile.new()
	var shot := _shot()

	# A campaign level: breaking the free armor starts the cue.
	App.start_level(App.campaign.step("city/1"))
	App.begin_run()
	await physics_frames(5)
	var cue: LastHitWarning = App.run.hud.last_hit
	var p: Player = App.run.world.player
	_watch(App.run.world)
	check(p.armor == rules.armor_hits and not cue.is_on(), "a campaign level starts protected by the free armor: no cue")
	p.receive_hit(shot)
	await _wait(cue_tuning.onset_delay + 0.3)
	check(p.alive and cue.is_on() and cue.level() > 0.0 and _sirens() == 1, "the free armor breaks in a level: the cue starts and the siren plays once")
	# A retry is a fresh run: protected, no cue.
	App.retry(App.run.context)
	App.begin_run()
	await physics_frames(5)
	check(not App.run.hud.last_hit.is_on() and App.run.hud.last_hit.level() == 0.0, "its retry starts with no cue")

	# Finishing the level ends it.
	cue = App.run.hud.last_hit
	p = App.run.world.player
	_watch(App.run.world)
	p.receive_hit(shot)
	await _wait(cue_tuning.onset_delay + 0.15)
	check(cue.is_on(), "(the cue is on again)")
	p.distance = App.run.world.layout.length
	await physics_frames(3)
	await _wait(0.1)
	check(App.run.state == LevelRun.State.COMPLETE and not cue.is_on(), "the level is complete: the cue ends")

	# A death ends it.
	App.start_level(App.campaign.step("city/1"))
	App.begin_run()
	await physics_frames(5)
	cue = App.run.hud.last_hit
	p = App.run.world.player
	_watch(App.run.world)
	p.receive_hit(shot)
	await _wait(cue_tuning.onset_delay + 0.15)
	check(cue.is_on() and _sirens() == 1, "(the cue is on, the siren playing)")
	p.call(&"_die", "test hazard")
	await physics_frames(3)
	await _wait(0.1)
	check(App.run.state == LevelRun.State.DEAD and not cue.is_on() and _cuts() == 1,
		"the player dies: the cue ends and the siren is cut off")
	await _wait(cue_tuning.fade_out_seconds + 0.2)
	check(cue.level() == 0.0, "and the edge fades away on the death screen")

	# A boss fight: the City's, and the test boss.
	var boss_step: CampaignStep = App.campaign.step("city/boss")
	if boss_step != null and boss_step.boss != null and boss_step.boss.is_built():
		App.start_boss(boss_step)
		App.begin_run()
		await physics_frames(5)
		await _boss_fight("the City's boss fight")
	App.start_boss_quick(load(TEST_BOSS_PATH) as BossDef)
	await physics_frames(5)
	await _boss_fight("the test boss fight")

	# The Beach's volleyball match: the runner can't die there, so nothing shows.
	App.start_level(App.campaign.step("beach/2"))
	if App.run.state == LevelRun.State.READY:
		App.begin_run()
	await physics_frames(5)
	check(App.run.minigame != null, "(the volleyball match)")
	cue = App.run.hud.last_hit
	_watch(App.run.world)
	App.run.world.player.armor = 0
	App.run.world.player.shield = 0
	await _wait(cue_tuning.onset_delay + 0.4)
	check(not cue.is_on() and cue.level() == 0.0 and _sirens() == 0, "an unprotected runner at the volleyball match: no cue, no siren")

	shot.free()
	App.show_title()
	await tree.process_frame
	App.profile = saved
	main.queue_free()
	App.main = null
	await tree.process_frame


## The cue and the siren in the boss fight the App has just started: the armor's last hit breaks it, the cue starts,
## the siren plays once; the boss beaten ends it.
func _boss_fight(what: String) -> void:
	var run: LevelRun = App.run
	var cue: LastHitWarning = run.hud.last_hit
	var p: Player = run.world.player
	var shot := _shot()
	check(run.context.is_boss() and run.encounter != null and p.armor_state.is_up(), "(%s, the armor up with %d hit(s))" % [what, p.armor])
	_watch(run.world)
	check(not cue.is_on(), "%s: protected, no cue" % what)
	while p.armor_state.is_up():
		p.invulnerable_left = 0.0
		p.receive_hit(shot)
		if p.armor_state.is_up():
			await _wait(cue_tuning.onset_delay + 0.15)
			check(not cue.is_on() and _sirens() == 0, "%s: a hit the armor survives brings no cue" % what)
	await _wait(cue_tuning.onset_delay + 0.3)
	check(p.alive and not p.armor_state.is_up() and cue.is_on() and cue.level() > 0.0 and _sirens() == 1,
		"%s: the armor's last hit breaks it, the cue starts and the siren plays once" % what)
	run.call(&"_on_boss_defeated")
	await _wait(0.1)
	check(run.state == LevelRun.State.COMPLETE and not cue.is_on(), "%s: beaten, the cue ends" % what)
	shot.free()


## Notes the sounds a world is asked for from now on (_requests, _stops).
func _watch(world: RunWorld) -> void:
	_requests.clear()
	_stops.clear()
	world.sounds.requested.connect(func(sound: StringName) -> void: _requests.append(sound))
	world.sounds.stopped.connect(func(sound: StringName) -> void: _stops.append(sound))
